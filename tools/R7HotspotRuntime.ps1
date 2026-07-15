Set-StrictMode -Version 2.0

if(-not(Get-Command Test-R7HotspotResearchRequest -ErrorAction SilentlyContinue)){
  . (Join-Path $PSScriptRoot 'R7HotspotContractHelper.ps1')
}

function Get-R7HotspotCurrentArtifact {
  param([string]$SessionRoot,[string]$ArtifactType)
  $pointerPath=Resolve-R7RuntimePath $SessionRoot "intermediate/r7/current/$ArtifactType.json"
  if(-not(Test-Path -LiteralPath $pointerPath -PathType Leaf)){throw "hotspot_current_pointer_missing:$ArtifactType"}
  $pointer=Read-R7JsonFile $pointerPath
  if([string]$pointer.artifact_type-ne$ArtifactType){throw "hotspot_current_pointer_type_mismatch:$ArtifactType"}
  $revisionPath=Resolve-R7RuntimePath $SessionRoot ([string]$pointer.revision_path)
  if(-not(Test-Path -LiteralPath $revisionPath -PathType Leaf)){throw "hotspot_current_revision_missing:$ArtifactType"}
  $digest=Get-R7RuntimeHash $revisionPath
  if($digest-ne[string]$pointer.sha256){throw "hotspot_current_digest_mismatch:$ArtifactType"}
  $ref=[ordered]@{artifact_id=[string]$pointer.artifact_id;revision=[int]$pointer.revision;sha256=$digest}
  return [pscustomobject]@{Pointer=$pointer;Payload=(Read-R7JsonFile $revisionPath);Ref=$ref;RelativePath=[string]$pointer.revision_path}
}

function Get-R7HotspotFileRef {
  param([string]$SessionRoot,[string]$RelativePath,[string[]]$IdFields)
  $path=Resolve-R7RuntimePath $SessionRoot $RelativePath
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "hotspot_required_input_missing:$RelativePath"}
  $document=Read-R7JsonFile $path;$id=Get-R7RuntimeField $document $IdFields
  if([string]::IsNullOrWhiteSpace($id)){throw "hotspot_required_input_id_missing:$RelativePath"}
  $revisionText=Get-R7RuntimeField $document @('revision','binding_revision','snapshot_revision','policy_revision')
  $revision=1;if(-not[string]::IsNullOrWhiteSpace($revisionText)){$parsed=0;if([int]::TryParse($revisionText,[ref]$parsed)-and$parsed-gt0){$revision=$parsed}}
  return [pscustomobject]@{Document=$document;Ref=[ordered]@{artifact_id=$id;revision=$revision;sha256=Get-R7RuntimeHash $path};RelativePath=$RelativePath}
}

function Invoke-R7HotspotResearchRequestCommit {
  param([string]$ProjectRoot,[string]$SessionRoot)
  try{
    $identity=Get-R7HotspotFileRef $SessionRoot 'intermediate/account-startup/account-identity-binding.json' @('identity_binding_id','binding_id')
    $snapshot=Get-R7HotspotFileRef $SessionRoot 'intermediate/account-startup/account-snapshot.v0.2.json' @('snapshot_id')
    $policy=Get-R7HotspotFileRef $SessionRoot 'intermediate/r5/radar-policy.json' @('radar_policy_id','policy_id')
    $sessionId=Split-Path -Leaf $SessionRoot;$basis=[ordered]@{account=$identity.Ref;account_snapshot=$snapshot.Ref;radar_policy=$policy.Ref;request_mode='initial'};$suffix=(Get-R7HotspotCanonicalDigest $basis).Substring(7,12)
    $requestedAt=Get-R7RuntimeField $snapshot.Document @('created_at','snapshot_at');if([string]::IsNullOrWhiteSpace($requestedAt)){$requestedAt='1970-01-01T00:00:00Z'}
    $request=[ordered]@{schema_id='taoge://schemas/r7/hotspot-research-request/v0.1';schema_version='0.1.0';research_request_id="HRQ-$sessionId-$suffix";research_request_revision=1;supersedes_request_ref=$null;account_identity_ref=$identity.Ref;account_snapshot_ref=$snapshot.Ref;radar_policy_ref=$policy.Ref;triggering_decision_ref=$null;triggering_freshness_review_ref=$null;prior_research_set_ref=$null;prior_panel_ref=$null;request_mode='initial';scope_delta=$null;manual_source_input_set_ref=$null;requested_at=$requestedAt;request_status='ready'}
    $errors=@(Test-R7HotspotResearchRequest ([pscustomobject](($request|ConvertTo-Json -Depth 40)|ConvertFrom-Json)));if($errors.Count){return New-R7RuntimeResult 'hotspot_research_request_contract_error' 1 $request $errors}
    return Commit-R7DeterministicArtifact $ProjectRoot $SessionRoot 'hotspot_research_request_commit' 'hotspot_research_request' ([string]$request.research_request_id) ([pscustomobject](($request|ConvertTo-Json -Depth 40)|ConvertFrom-Json)) 'request_ready' @([string]$identity.Ref.artifact_id,[string]$snapshot.Ref.artifact_id,[string]$policy.Ref.artifact_id) @('R7-F70','R7-F71')
  }catch{return New-R7RuntimeResult 'hotspot_research_request_input_error' 1 $null @($_.Exception.Message)}
}

function Invoke-R7TopicPanelProjection {
  param([string]$ProjectRoot,[string]$SessionRoot)
  try{
    $setItem=Get-R7HotspotCurrentArtifact $SessionRoot 'hotspot_research_set';$set=$setItem.Payload;$setErrors=@(Test-R7HotspotResearchSet $set);if($setErrors.Count){return New-R7RuntimeResult 'hotspot_research_set_contract_error' 1 $set $setErrors}
    $ordered=[Collections.Generic.List[object]]::new();foreach($local in @($set.panel_model.ordered_topic_option_refs)){$ordered.Add([ordered]@{container_artifact_ref=$setItem.Ref;component_type=[string]$local.component_type;component_id=[string]$local.component_id;component_sha256=[string]$local.component_sha256})};$recommended=$null;if($null-ne$set.panel_model.recommended_topic_ref){$local=$set.panel_model.recommended_topic_ref;$recommended=[ordered]@{container_artifact_ref=$setItem.Ref;component_type=[string]$local.component_type;component_id=[string]$local.component_id;component_sha256=[string]$local.component_sha256}}
    $sessionId=Split-Path -Leaf $SessionRoot;$panel=[ordered]@{schema_id='taoge://schemas/r7/topic-selection-panel/v0.2';schema_version='0.2.0';panel_id="PANEL-$sessionId-$($set.research_set_id)";panel_revision=1;research_set_ref=$setItem.Ref;ordered_topic_option_refs=[object[]]$ordered.ToArray();recommended_topic_ref=$recommended;recommendation_reason=[string]$set.panel_model.recommendation_reason;panel_status=$(if($set.research_set_status-eq'ready_no_recommendation'){'panel_no_recommendation'}else{'panel_ready_waiting_human'});projected_at=[string]$set.researched_at}
    $panelObject=[pscustomobject](($panel|ConvertTo-Json -Depth 60)|ConvertFrom-Json);$errors=@(Test-R7HotspotPanel $panelObject $set $setItem.Ref);if($errors.Count){return New-R7RuntimeResult 'topic_panel_projection_error' 1 $panelObject $errors}
    $lines=[Collections.Generic.List[string]]::new();$lines.Add('# Topic selection panel');$lines.Add('');$lines.Add("panel_id: $($panel.panel_id)");$lines.Add("status: $($panel.panel_status)");$lines.Add("reason: $($panel.recommendation_reason)");$lines.Add('');$index=0;foreach($ref in @($panel.ordered_topic_option_refs)){$index++;$topic=Get-R7HotspotComponent $set 'topic_option' ([string]$ref.component_id);$title=Get-R7RuntimeField $topic @('title','topic_title','summary');$lines.Add("$index. [$($ref.component_id)] $title")}
    Write-TaogeUtf8NoBomLines (Resolve-R7RuntimePath $SessionRoot 'deliverables/hotspot-topic-selection-panel.md') $lines
    return Commit-R7DeterministicArtifact $ProjectRoot $SessionRoot 'topic_panel_projection' 'topic_selection_panel' ([string]$panel.panel_id) $panelObject $(if($panel.panel_status-eq'panel_no_recommendation'){'panel_no_recommendation'}else{'panel_projected'}) @([string]$set.research_set_id) @('R7-F53','R7-F73')
  }catch{return New-R7RuntimeResult 'topic_panel_projection_error' 1 $null @($_.Exception.Message)}
}

function Get-R7HotspotComponentRefFromId {
  param([object]$SetItem,[string]$Type,[string]$Id)
  $digest=Get-R7RuntimeField $SetItem.Payload.component_digest_map @($Id)
  if([string]::IsNullOrWhiteSpace($digest)){throw "hotspot_component_digest_missing:$Id"}
  return [ordered]@{container_artifact_ref=$SetItem.Ref;component_type=$Type;component_id=$Id;component_sha256=$digest}
}

function Invoke-R7SelectedTopicSourceCommit {
  param([string]$ProjectRoot,[string]$SessionRoot)
  try{
    $setItem=Get-R7HotspotCurrentArtifact $SessionRoot 'hotspot_research_set';$panelItem=Get-R7HotspotCurrentArtifact $SessionRoot 'topic_selection_panel';$decisionItem=Get-R7HotspotCurrentArtifact $SessionRoot 'topic_selection_decision'
    $set=$setItem.Payload;$panel=$panelItem.Payload;$decision=$decisionItem.Payload;$decisionErrors=@(Test-R7HotspotDecision $decision $panel $set);if($decisionErrors.Count){return New-R7RuntimeResult 'topic_selection_decision_contract_error' 1 $decision $decisionErrors};if($decision.decision_code-ne'select_one'){return New-R7RuntimeResult 'selected_source_route_not_select_one' 2 $decision @()}
    $topicRef=$decision.selected_topic_refs[0];$topic=Get-R7HotspotComponent $set 'topic_option' ([string]$topicRef.component_id);if($null-eq$topic){throw 'selected_topic_component_missing'}
    $eventId=Get-R7RuntimeField $topic @('event_id');$candidateId=Get-R7RuntimeField $topic @('candidate_id');$packetId=Get-R7RuntimeField $topic @('topic_evidence_packet_id','evidence_packet_id');$missingLink=@($eventId,$candidateId,$packetId|Where-Object{[string]::IsNullOrWhiteSpace([string]$_)});if($missingLink.Count){throw 'selected_topic_component_links_missing'}
    $event=Get-R7HotspotComponent $set 'event' $eventId;$candidate=Get-R7HotspotComponent $set 'candidate' $candidateId;$packet=Get-R7HotspotComponent $set 'topic_evidence_packet' $packetId
    $semanticBasis=[ordered]@{topic_identity=Get-R7RuntimeField $topic @('topic_identity','topic_option_id','topic_id');event=[ordered]@{subject=Get-R7RuntimeField $event @('subject');action=Get-R7RuntimeField $event @('action');time_boundary=Get-R7RuntimeField $event @('time_boundary');event_fact_status=Get-R7RuntimeField $packet @('event_fact_status')};audience=Get-R7RuntimeField $topic @('audience');impact_chain=[object[]]@($topic.impact_chain);claims=[object[]]@($packet.claims|Sort-Object claim_id|ForEach-Object{[ordered]@{claim_id=$_.claim_id;claim_type=$_.claim_type;claim_evidence_status=$_.claim_evidence_status;source_support_basis=$_.source_support_basis;source_independence_status=$_.source_independence_status;allowed_expression=$_.allowed_expression}});risk_level=$packet.risk_level}
    $sourceIds=[Collections.Generic.List[string]]::new();foreach($claim in @($packet.claims)){foreach($id in @($claim.source_record_ids)){if(-not [string]::IsNullOrWhiteSpace([string]$id) -and -not $sourceIds.Contains([string]$id)){$sourceIds.Add([string]$id)}}}
    $sourceRefs=[Collections.Generic.List[object]]::new();foreach($id in @($sourceIds|Sort-Object)){$sourceRefs.Add((Get-R7HotspotComponentRefFromId $setItem 'source_record' $id))}
    $policy=[ordered]@{policy_mode='always_revalidate_before_delivery';max_age_hours=$null;threshold_basis=$null;policy_basis_refs=[object[]]@();event_triggers=[object[]]@();fallback_reason='no_trusted_duration_or_trigger_policy'}
    $monitoringBasis=[ordered]@{freshness_policy=$policy;checked_at=[string]$set.researched_at;sources=[object[]]@($sourceIds|Sort-Object|ForEach-Object{$record=Get-R7HotspotComponent $set 'source_record' $_;[ordered]@{source_record_id=$_;source_identity=Get-R7RuntimeField $record @('source_identity','canonical_url');published_at=Get-R7RuntimeField $record @('published_at');observed_at=Get-R7RuntimeField $record @('observed_at');capture_availability=Get-R7RuntimeField $record @('capture_availability')}})}
    $sessionId=Split-Path -Leaf $SessionRoot;$suffix=(Get-R7HotspotCanonicalDigest $decisionItem.Ref).Substring(7,12)
    $source=[ordered]@{schema_id='taoge://schemas/r7/selected-topic-source/v0.1';schema_version='0.1.0';selected_topic_source_id="STS-$sessionId-$suffix";selected_topic_source_revision=1;content_origin='hotspot_selected_topic';account_snapshot_ref=$set.account_snapshot_ref;radar_policy_ref=$set.radar_policy_ref;research_set_ref=$setItem.Ref;selection_panel_ref=$panelItem.Ref;selection_decision_ref=$decisionItem.Ref;event_ref=Get-R7HotspotComponentRefFromId $setItem 'event' $eventId;candidate_ref=Get-R7HotspotComponentRefFromId $setItem 'candidate' $candidateId;topic_option_ref=$topicRef;topic_evidence_packet_ref=Get-R7HotspotComponentRefFromId $setItem 'topic_evidence_packet' $packetId;monitoring_source_record_refs=[object[]]$sourceRefs.ToArray();latest_freshness_review_ref=$null;freshness_policy=$policy;selection_freshness_status='current';digest_basis_version='selected-topic-source-digest-v0.1';content_semantic_digest=Get-R7HotspotCanonicalDigest $semanticBasis;monitoring_digest=Get-R7HotspotCanonicalDigest $monitoringBasis;selected_source_status='ready_for_brief';selected_at=[string]$decision.decided_at}
    $sourceObject=[pscustomobject](($source|ConvertTo-Json -Depth 80)|ConvertFrom-Json);$errors=@(Test-R7SelectedTopicSource $sourceObject $set $panel $decision);if($errors.Count){return New-R7RuntimeResult 'selected_topic_source_contract_error' 1 $sourceObject $errors}
    return Commit-R7DeterministicArtifact $ProjectRoot $SessionRoot 'selected_topic_source_commit' 'selected_topic_source' ([string]$source.selected_topic_source_id) $sourceObject 'selected_source_ready' @([string]$set.research_set_id,[string]$panel.panel_id,[string]$decision.decision_id) @('R7-F54','R7-F55','R7-F67','R7-F75','R7-F76','R7-F77','R7-F80')
  }catch{return New-R7RuntimeResult 'selected_topic_source_compile_error' 1 $null @($_.Exception.Message)}
}

function Invoke-R7HotspotDeterministicNode {
  param([string]$ProjectRoot,[string]$SessionRoot,[string]$NodeId)
  switch($NodeId){
    'hotspot_research_request_commit'{return Invoke-R7HotspotResearchRequestCommit $ProjectRoot $SessionRoot}
    'topic_panel_projection'{return Invoke-R7TopicPanelProjection $ProjectRoot $SessionRoot}
    'selected_topic_source_commit'{return Invoke-R7SelectedTopicSourceCommit $ProjectRoot $SessionRoot}
    default{return New-R7RuntimeResult 'hotspot_deterministic_node_not_compiled' 2 $null @($NodeId)}
  }
}
