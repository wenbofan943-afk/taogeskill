Set-StrictMode -Version 2.0

if (-not (Get-Command Prepare-R7RuntimeTask -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'R7SemanticRuntime.ps1')
}
if (-not (Get-Command Encode-P0V2Html -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'P0RuntimeV02.ps1')
}
if (-not (Get-Command New-P0V5ViewTexts -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'P0FinalDeliveryV05.ps1')
}

function Get-R7CandidateCurrentArtifact {
  param([string]$SessionRoot,[string]$ArtifactType)
  $pointerRelative="intermediate/r7/current/$ArtifactType.json"
  $pointerPath=Resolve-R7RuntimePath $SessionRoot $pointerRelative
  if(-not(Test-Path -LiteralPath $pointerPath -PathType Leaf)){throw "candidate_current_pointer_missing:$ArtifactType"}
  $pointer=Read-R7JsonFile $pointerPath
  if([string]$pointer.artifact_type -ne $ArtifactType){throw "candidate_current_pointer_type_mismatch:$ArtifactType"}
  $revisionPath=Resolve-R7RuntimePath $SessionRoot ([string]$pointer.revision_path)
  if(-not(Test-Path -LiteralPath $revisionPath -PathType Leaf)){throw "candidate_current_revision_missing:$ArtifactType"}
  $digest=Get-R7RuntimeHash $revisionPath
  if($digest -ne [string]$pointer.sha256){throw "candidate_current_digest_mismatch:$ArtifactType"}
  return [pscustomobject]@{Pointer=$pointer;Payload=(Read-R7JsonFile $revisionPath);RelativePath=[string]$pointer.revision_path;Sha256=$digest}
}

function Get-R7CandidateUtf8Slice {
  param([string]$Text,[int]$StartByte,[int]$EndByte)
  $bytes=[Text.Encoding]::UTF8.GetBytes($Text)
  if($StartByte -lt 0 -or $EndByte -le $StartByte -or $EndByte -gt $bytes.Length){throw "candidate_beat_anchor_invalid:$StartByte-$EndByte"}
  return [Text.Encoding]::UTF8.GetString($bytes[$StartByte..($EndByte-1)])
}

function Get-R7CandidateGreatestCommonDivisor {
  param([int]$A,[int]$B)
  $left=[math]::Abs($A);$right=[math]::Abs($B)
  while($right -ne 0){$next=$left%$right;$left=$right;$right=$next}
  if($left -lt 1){return 1};return $left
}

function Get-R7CandidatePlatformProfile {
  param([object]$Registry,[string]$Platform)
  $profile=@($Registry.platforms|Where-Object{$_.platform -eq $Platform})|Select-Object -First 1
  if($null -eq $profile){throw "candidate_platform_profile_missing:$Platform"}
  return $profile
}

function Test-R7CandidateAssetFile {
  param([string]$SessionRoot,[string]$RelativePath,[string]$ExpectedDigest,[string]$ErrorPrefix)
  $path=Resolve-R7RuntimePath $SessionRoot $RelativePath
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "${ErrorPrefix}_missing:$RelativePath"}
  $actual=Get-R7RuntimeHash $path
  if($actual -ne $ExpectedDigest){throw "${ErrorPrefix}_digest_mismatch:$RelativePath"}
  return $path
}

function Get-R7VisualCapabilityDisposition {
  param([int]$ProviderTaskCount,[int]$ProviderAttemptCount,[bool]$ProviderAvailable)
  if($ProviderTaskCount-gt0-and-not$ProviderAvailable-and$ProviderAttemptCount-eq0){return 'waiting_assets'}
  if($ProviderAttemptCount-gt$ProviderTaskCount){return 'provider_attempt_count_invalid'}
  return 'continue'
}

function Test-R7CandidateCoverBinding {
  param([string]$SessionRoot,[object]$Rendition)
  [void](Test-R7CandidateAssetFile $SessionRoot ([string]$Rendition.asset_path) ([string]$Rendition.sha256) 'cover_asset')
  $reviewPath=Resolve-R7RuntimePath $SessionRoot ([string]$Rendition.review_ref)
  if(-not(Test-Path -LiteralPath $reviewPath -PathType Leaf)){throw "asset_review_binding_error:review_missing:$($Rendition.platform)"}
  $review=Read-R7JsonFile $reviewPath
  if([string]$review.schema_id -ne 'taoge://schemas/r3/cover-visual-review/v0.1' -or [string]::IsNullOrWhiteSpace([string]$review.cover_rendition_id)){throw "asset_review_binding_error:per_rendition_review_required:$($Rendition.platform)"}
  if([string]$review.output_sha256 -ne [string]$Rendition.sha256){throw "asset_review_binding_error:output_digest_mismatch:$($Rendition.platform)"}
  if([string]$review.visual_review_status -ne 'pass' -or [string]$Rendition.review_status -ne 'visual_pass'){throw "asset_review_binding_error:review_not_pass:$($Rendition.platform)"}
  $previewPath=Test-R7CandidateAssetFile $SessionRoot ([string]$Rendition.preview_path) ([string]$review.preview_sha256) 'cover_preview'
  if([string]$review.surface_profile_id -notmatch ('^'+[regex]::Escape([string]$Rendition.platform).Replace('wechat_channels','wechat-channels'))){
    # The binding is primarily ID/hash based; platform naming is independently
    # checked by the presentation registry below. Keep this guard intentionally
    # narrow so a review for another rendition cannot be reused silently.
    if([string]$review.cover_rendition_id -notmatch ([string]$Rendition.platform -replace 'wechat_channels','SPH' -replace 'xiaohongshu','XHS' -replace 'douyin','DY')){throw "asset_review_binding_error:rendition_platform_mismatch:$($Rendition.platform)"}
  }
  return [pscustomobject]@{Review=$review;ReviewPath=$reviewPath;PreviewPath=$previewPath}
}

function Get-R7CandidateSourceSet {
  param([string]$SessionRoot)
  $plan=Read-R7JsonFile (Join-Path $SessionRoot 'intermediate/p0/session-execution-plan.json');$isHotspot=[string]$plan.blueprint_id-eq'hotspot_to_delivery_single_v0.2'
  $shared=@('content_brief','short_video_structure_plan','draft','content_beat_map','script_design_review','content_revision_decision','visual_coverage_ledger','image_asset_set','script_visual_alignment_review','platform_package','cover_composition')
  $types=if($isHotspot){@('hotspot_research_request','hotspot_research_set','topic_selection_panel','topic_selection_decision','selected_topic_source','topic_freshness_review')+$shared}else{@('direct_content_intake')+$shared}
  $sources=[ordered]@{};$map=[Collections.Generic.List[object]]::new()
  foreach($type in $types){
    $item=Get-R7CandidateCurrentArtifact $SessionRoot $type
    $sources[$type]=$item
    $map.Add([ordered]@{artifact_type=$type;artifact_id=[string]$item.Pointer.artifact_id;relative_path=[string]$item.RelativePath;sha256=[string]$item.Sha256;producer_event_id=[string]$item.Pointer.producer_event_id})
  }
  return [pscustomobject]@{Origin=$(if($isHotspot){'hotspot_selected_topic'}else{'user_supplied_draft'});Sources=$sources;SourceMap=[object[]]$map.ToArray()}
}

function Get-R7CandidateArtifactRef {
  param([object]$Item)
  return [ordered]@{artifact_id=[string]$Item.Pointer.artifact_id;revision=[int]$Item.Pointer.revision;sha256=[string]$Item.Sha256}
}

function New-R7CandidateWarning {
  param([string]$Code,[string]$Category,[string]$Severity,[string]$Message,[string]$Impact,[string]$Action,[string]$Source,[string]$Resolution)
  return [ordered]@{warning_code=$Code;warning_category=$Category;severity=$Severity;user_message=$Message;impact=$Impact;recommended_action=$Action;source_artifact_id=$Source;resolution_status=$Resolution}
}

function New-R7CandidatePayload {
  param([string]$ProjectRoot,[string]$SessionRoot,[object]$SourceSet)
  $sessionId=Split-Path -Leaf $SessionRoot
  $s=$SourceSet.Sources
  $isHotspot=[string]$SourceSet.Origin-eq'hotspot_selected_topic';$intake=if($isHotspot){$null}else{$s.direct_content_intake.Payload};$brief=$s.content_brief.Payload;$structure=$s.short_video_structure_plan.Payload;$draft=$s.draft.Payload
  $beatMap=$s.content_beat_map.Payload;$review=$s.script_design_review.Payload;$decision=$s.content_revision_decision.Payload
  $visualPackage=$s.visual_coverage_ledger.Payload;$ledger=$visualPackage.coverage_ledger;$assetSet=$s.image_asset_set.Payload
  $alignment=$s.script_visual_alignment_review.Payload;$platformPackage=$s.platform_package.Payload;$coverComposition=$s.cover_composition.Payload
  $presentation=Read-YamlFile (Join-Path $ProjectRoot $(if($isHotspot){'routes/r7-delivery-presentation-registry.yaml'}else{'routes/r7-delivery-presentation-registry.v0.1.yaml'}))
  $actions=Read-YamlFile (Join-Path $ProjectRoot $(if($isHotspot){'routes/r7-action-registry.yaml'}else{'routes/r7-action-registry.v0.1.yaml'}))

  if($isHotspot){
    $selected=$s.selected_topic_source.Payload;$freshness=$s.topic_freshness_review.Payload;$selectedRef=Get-R7CandidateArtifactRef $s.selected_topic_source;$freshnessRef=Get-R7CandidateArtifactRef $s.topic_freshness_review
    if([string]$selected.selected_source_status-ne'ready_for_delivery'){throw 'candidate_hotspot_selected_source_not_ready'}
    foreach($name in @('artifact_id','revision','sha256')){if([string]$selected.latest_freshness_review_ref.$name-ne[string]$freshnessRef.$name){throw "candidate_hotspot_freshness_pointer_mismatch:$name"}}
    if([string]$freshness.review_status-ne'complete'){throw 'candidate_hotspot_freshness_not_complete'}
    if([string]$freshness.selected_topic_source_ref.artifact_id-ne[string]$selectedRef.artifact_id){throw 'candidate_hotspot_review_source_identity_mismatch:artifact_id'}
    if([int]$freshness.selected_topic_source_ref.revision-ne([int]$selectedRef.revision-1)){throw 'candidate_hotspot_review_source_revision_mismatch'}
  }

  if([string]$visualPackage.visual_coverage_ledger_id -ne [string]$ledger.visual_coverage_ledger_id){throw 'candidate_visual_package_id_mismatch'}
  if([string]$assetSet.coverage_ledger_ref.artifact_id -ne [string]$ledger.visual_coverage_ledger_id){throw 'candidate_asset_ledger_binding_mismatch'}
  if([string]$platformPackage.draft_ref.artifact_id -ne [string]$draft.draft_id){throw 'candidate_platform_draft_binding_mismatch'}
  if([string]$coverComposition.platform_package_ref.artifact_id -ne [string]$platformPackage.platform_package_id){throw 'candidate_cover_platform_binding_mismatch'}

  $coverageByBeat=@{};foreach($record in @($ledger.coverage_records)){$coverageByBeat[[string]$record.beat_id]=$record}
  $taskById=@{};foreach($task in @($ledger.accepted_visual_tasks)){$taskById[[string]$task.visual_task_id]=$task}
  $beatById=@{};$beatOrderById=@{};foreach($beat in @($beatMap.beats|Sort-Object order)){$beatId=[string]$beat.beat_id;if($beatById.ContainsKey($beatId)){throw "candidate_occurrence_contract_error:beat_duplicate:$beatId"};$beatById[$beatId]=$beat;$beatOrderById[$beatId]=[int]$beat.order}
  $assetByTask=@{};foreach($asset in @($assetSet.assets)){
    if($assetByTask.ContainsKey([string]$asset.visual_task_id)){throw "candidate_visual_asset_duplicate:$($asset.visual_task_id)"}
    [void](Test-R7CandidateAssetFile $SessionRoot ([string]$asset.relative_path) ([string]$asset.sha256) 'visual_asset')
    foreach($pathField in @('sidecar_path','generation_record_path')){[void](Test-R7CandidateAssetFile $SessionRoot ([string]$asset.$pathField) (Get-R7RuntimeHash (Resolve-R7RuntimePath $SessionRoot ([string]$asset.$pathField))) 'visual_evidence')}
    $assetByTask[[string]$asset.visual_task_id]=$asset
  }
  $assetSetClaimsReady=[string]$assetSet.asset_set_status -in @('materialized','ready_with_warnings')
  foreach($taskId in $taskById.Keys){
    if($assetSetClaimsReady -and -not $assetByTask.ContainsKey($taskId)){throw "candidate_materialized_asset_missing:$taskId"}
  }
  if([int]$assetSet.provider_invocation_count -ne @($assetSet.assets|Where-Object{$_.provider_invoked}).Count){throw 'candidate_provider_invocation_count_mismatch'}
  $visualDeliveryReadiness=switch([string]$assetSet.asset_set_status){
    'materialized'{'ready'}
    'ready_with_warnings'{'ready_with_warnings'}
    'manual_required'{'waiting_authorization'}
    'blocked'{'blocked'}
    default{'waiting_assets'}
  }

  $occurrenceIds=@{};$occurrenceByOwnerBeat=@{};$ownerBeatByOccurrence=@{}
  foreach($occ in @($ledger.visual_insert_occurrences)){
    $occurrenceId=[string]$occ.occurrence_id;$taskId=[string]$occ.visual_task_id
    if([string]::IsNullOrWhiteSpace($occurrenceId)-or$occurrenceIds.ContainsKey($occurrenceId)){throw "candidate_occurrence_contract_error:occurrence_duplicate:$occurrenceId"};$occurrenceIds[$occurrenceId]=$true
    if(-not$taskById.ContainsKey($taskId)){throw "candidate_occurrence_contract_error:task_missing:${occurrenceId}:$taskId"}
    $coveredBeatIds=@($occ.covered_beat_ids|ForEach-Object{[string]$_});if($coveredBeatIds.Count-eq0){throw "candidate_occurrence_contract_error:covered_beats_empty:$occurrenceId"}
    $seenCovered=@{};$orderedCovered=[Collections.Generic.List[object]]::new();$taskCovered=@($taskById[$taskId].covered_beat_ids|ForEach-Object{[string]$_})
    foreach($coveredBeatId in $coveredBeatIds){
      if($seenCovered.ContainsKey($coveredBeatId)){throw "candidate_occurrence_contract_error:covered_beat_duplicate:${occurrenceId}:$coveredBeatId"};$seenCovered[$coveredBeatId]=$true
      if(-not$beatById.ContainsKey($coveredBeatId)){throw "candidate_occurrence_contract_error:covered_beat_missing:${occurrenceId}:$coveredBeatId"}
      if($coveredBeatId-notin$taskCovered){throw "candidate_occurrence_contract_error:task_coverage_mismatch:${occurrenceId}:$coveredBeatId"}
      $orderedCovered.Add([pscustomobject]@{beat_id=$coveredBeatId;order=[int]$beatOrderById[$coveredBeatId]})
    }
    $ordered=@($orderedCovered|Sort-Object order);for($i=1;$i-lt$ordered.Count;$i++){if([int]$ordered[$i].order-ne([int]$ordered[$i-1].order+1)){throw "candidate_occurrence_contract_error:covered_beats_non_contiguous:$occurrenceId"}}
    $ownerBeatId=[string]$ordered[0].beat_id;$ownerBeatByOccurrence[$occurrenceId]=$ownerBeatId
    if(-not$occurrenceByOwnerBeat.ContainsKey($ownerBeatId)){$occurrenceByOwnerBeat[$ownerBeatId]=[Collections.Generic.List[string]]::new()};$occurrenceByOwnerBeat[$ownerBeatId].Add($occurrenceId)
  }
  $beatCards=[Collections.Generic.List[object]]::new()
  foreach($beat in @($beatMap.beats|Sort-Object order)){
    if(-not $coverageByBeat.ContainsKey([string]$beat.beat_id)){throw "cross_artifact_binding_error:coverage_missing:$($beat.beat_id)"}
    $coverage=$coverageByBeat[[string]$beat.beat_id]
    $taskIds=[Collections.Generic.List[string]]::new()
    if((Test-R7HasProperty $coverage 'primary_visual_task_id') -and -not [string]::IsNullOrWhiteSpace([string]$coverage.primary_visual_task_id)){$taskIds.Add([string]$coverage.primary_visual_task_id)}
    if((Test-R7HasProperty $coverage 'reused_visual_task_id') -and -not [string]::IsNullOrWhiteSpace([string]$coverage.reused_visual_task_id)){$taskIds.Add([string]$coverage.reused_visual_task_id)}
    foreach($id in @($coverage.supplemental_visual_task_ids)){if(-not [string]::IsNullOrWhiteSpace([string]$id) -and -not $taskIds.Contains([string]$id)){$taskIds.Add([string]$id)}}
    $occIds=[Collections.Generic.List[string]]::new();if($occurrenceByOwnerBeat.ContainsKey([string]$beat.beat_id)){foreach($occId in $occurrenceByOwnerBeat[[string]$beat.beat_id]){$occIds.Add($occId)}}
    $reason=if($taskIds.Count -and $taskById.ContainsKey($taskIds[0])){[string]$taskById[$taskIds[0]].value_proof.viewer_problem_without_visual}elseif(Test-R7HasProperty $coverage 'talking_head_advantage'){[string]$coverage.talking_head_advantage}elseif(Test-R7HasProperty $coverage 'evidence_block_reason'){[string]$coverage.evidence_block_reason}else{'No supplementary visual is required for this beat.'}
    $beatCards.Add([ordered]@{card_id="CARD-$sessionId-BEAT-$('{0:000}' -f [int]$beat.order)";card_type='content_beat';display_order=[int]$beat.order;status=$(if($coverage.primary_disposition -eq 'evidence_blocked'){'ready_with_warnings'}else{'ready'});source_artifact_ids=@([string]$beatMap.beat_map_id,[string]$ledger.visual_coverage_ledger_id);beat_id=[string]$beat.beat_id;stage_id=[string]$beat.stage_id;source_excerpt=Get-R7CandidateUtf8Slice ([string]$draft.body_text) ([int]$beat.start_byte) ([int]$beat.end_byte);semantic_function=[string]$beat.semantic_function;visual_disposition=[string]$coverage.primary_disposition;visual_reason=$reason;visual_task_ids=[object[]]$taskIds.ToArray();occurrence_ids=[object[]]$occIds.ToArray()})
  }

  $stageCards=[Collections.Generic.List[object]]::new();foreach($stage in @($structure.stages|Sort-Object order)){$stageCards.Add([ordered]@{stage_id=[string]$stage.stage_id;order=[int]$stage.order;purpose=[string]$stage.stage_purpose;implementation_status='aligned';beat_ids=[object[]]@($beatMap.beats|Where-Object{$_.stage_id -eq $stage.stage_id}|Sort-Object order|ForEach-Object{[string]$_.beat_id})})}
  $issueCards=[Collections.Generic.List[object]]::new();$warnings=[Collections.Generic.List[object]]::new()
  foreach($issue in @($review.issues)){
    $resolution=if([string]$issue.issue_id -in @($decision.accepted_advisory_issue_ids)){'accepted_current_revision'}else{'open'}
    $excerpt=if(@($issue.affected_beat_ids).Count){[string](@($beatCards|Where-Object{$_.beat_id -eq $issue.affected_beat_ids[0]}|Select-Object -First 1).source_excerpt)}else{[string]$issue.description}
    $issueCards.Add([ordered]@{issue_id=[string]$issue.issue_id;gate=[string]$issue.issue_gate;source_excerpt=$excerpt;viewer_impact=[string]$issue.description;recommended_action=[string]$issue.recommended_action;resolution_status=$resolution})
    $warnings.Add((New-R7CandidateWarning ([string]$issue.issue_id) 'copy' 'non_blocking' ([string]$issue.description) ([string]$issue.description) ([string]$issue.recommended_action) ([string]$issue.issue_id) $(if($resolution -eq 'accepted_current_revision'){'accepted'}else{'open'})))
  }
  $warnings.Add((New-R7CandidateWarning 'publishing_not_executed' 'publishing' 'known_scope' '本轮没有登录平台或发布' '本地交付闭合不证明平台审核、播放或转化。' '由用户人工验收后发布。' ([string]$platformPackage.platform_package_id) 'open'))
  $warnings.Add((New-R7CandidateWarning 'surface_profiles_provisional' 'visual_runtime' 'known_scope' '平台封面表面规格仍为项目暂定 profile' '真实平台裁切未在本轮登录观察。' '人工发布时如裁切不同，新建 rendition revision。' ([string]$coverComposition.cover_composition_id) 'open'))
  if(@($assetSet.assets|Where-Object{$_.source_mode -eq 'reused_verified'}).Count){$warnings.Add((New-R7CandidateWarning 'reused_verified_assets' 'visual_runtime' 'known_scope' '本轮复用了已验收资产' '证明同内容资产复用链，不证明新 provider 调用。' '需要新风格时另启视觉 revision。' ([string]$assetSet.image_asset_set_id) 'open'))}

  $coverCards=[Collections.Generic.List[object]]::new();$platformCards=[Collections.Generic.List[object]]::new();$units=[Collections.Generic.List[object]]::new();$coverOrder=0
  foreach($package in @($platformPackage.packages)){
    $coverOrder++;$rendition=@($coverComposition.renditions|Where-Object{$_.platform -eq $package.platform})|Select-Object -First 1
    if($null -eq $rendition){throw "candidate_cover_rendition_missing:$($package.platform)"}
    $binding=Test-R7CandidateCoverBinding $SessionRoot $rendition;$profile=Get-R7CandidatePlatformProfile $presentation ([string]$package.platform)
    if([string]$binding.Review.surface_profile_id -ne [string]$profile.surface_profile_id){throw "asset_review_binding_error:surface_profile_mismatch:$($package.platform)"}
    $priority=if([string]$package.platform -eq [string]$platformPackage.primary_platform){'primary'}else{'secondary'}
    $coverCardId="CARD-$sessionId-COVER-$('{0:000}' -f $coverOrder)";$platformCardId="CARD-$sessionId-PLATFORM-$('{0:000}' -f $coverOrder)"
    $coverCards.Add([ordered]@{card_id=$coverCardId;card_type='cover';display_order=$coverOrder;status='ready';source_artifact_ids=@([string]$platformPackage.platform_package_id,[string]$coverComposition.cover_composition_id);cover_role='platform_cover';cover_job_id=[string]$coverComposition.cover_composition_id;cover_rendition_id=[string]$binding.Review.cover_rendition_id;rendition_revision=[int]$binding.Review.rendition_revision;platform=[string]$package.platform;platform_priority=$priority;surface_profile_id=[string]$profile.surface_profile_id;surface_profile_version=[string]$presentation.cover.surface_profile_version;surface_role=[string]$presentation.cover.surface_role;profile_evidence_status=[string]$presentation.cover.profile_evidence_status;adaptation_strategy=[string]$presentation.cover.adaptation_strategy;title_text=[string]$package.cover_title;rendered_text=[string]$package.cover_title;asset_status='reused_verified';asset_id=[string]$rendition.asset_id;relative_path=[string]$rendition.asset_path;sha256=[string]$rendition.sha256;sidecar_path=[string]$rendition.review_ref;preview_evidence_type=[string]$presentation.cover.preview_evidence_type;preview_path=[string]$rendition.preview_path;preview_sha256=[string]$binding.Review.preview_sha256;visual_review_record_path=[string]$rendition.review_ref;reviewer_type=[string]$binding.Review.reviewer_type;visual_review_status=[string]$binding.Review.visual_review_status;cover_delivery_status='visual_pass';usage_note='封面由逐 rendition、逐 hash review 绑定后进入交付。'})
    $platformCards.Add([ordered]@{card_id=$platformCardId;card_type='platform';display_order=$coverOrder;status='ready';source_artifact_ids=@([string]$platformPackage.platform_package_id);platform=[string]$package.platform;platform_priority=$priority;cover_title=[string]$package.cover_title;video_title=[string]$package.title;publish_description=[string]$package.body_text;hashtags=[object[]]@($package.hashtags);publish_readiness='ready'})
    $units.Add([ordered]@{unit_id="PDU-$sessionId-$('{0:000}' -f $coverOrder)";display_order=$coverOrder;platform=[string]$package.platform;platform_label=[string]$profile.label;platform_priority=$priority;platform_card_id=$platformCardId;cover_card_id=$coverCardId;surface_profile_id=[string]$profile.surface_profile_id;cover_rendition_id=[string]$binding.Review.cover_rendition_id;cover_title=[string]$package.cover_title;rendered_cover_text=[string]$package.cover_title;cover_asset_id=[string]$rendition.asset_id;cover_asset_path=[string]$rendition.asset_path;cover_sha256=[string]$rendition.sha256;cover_preview_path=[string]$rendition.preview_path;cover_preview_sha256=[string]$binding.Review.preview_sha256;adaptation_strategy=[string]$presentation.cover.adaptation_strategy;preview_evidence_type=[string]$presentation.cover.preview_evidence_type;visual_review_status='pass';cover_delivery_status='visual_pass';video_title=[string]$package.title;publish_description=[string]$package.body_text;hashtags=[object[]]@($package.hashtags);publish_readiness='ready'})
  }
  if(@($coverComposition.renditions).Count -ne $coverCards.Count){throw 'candidate_cover_platform_cardinality_mismatch'}

  $visualCards=[Collections.Generic.List[object]]::new();$visualOrder=0
  foreach($occurrence in @($ledger.visual_insert_occurrences)){
    $taskId=[string]$occurrence.visual_task_id;if(-not $assetByTask.ContainsKey($taskId)){throw "candidate_occurrence_asset_missing:$taskId"};$asset=$assetByTask[$taskId]
    $ownerBeatId=[string]$ownerBeatByOccurrence[[string]$occurrence.occurrence_id];$coverage=$coverageByBeat[$ownerBeatId];$beat=$beatById[$ownerBeatId]
    $task=$taskById[$taskId];$visualOrder++
    $assetRatio=[double]$asset.width_px/[double]$asset.height_px;$slotHeight=[math]::Round(([double]$presentation.visual_insert.placement.width*1080/$assetRatio/1920),5);$ratioDivisor=Get-R7CandidateGreatestCommonDivisor ([int]$asset.width_px) ([int]$asset.height_px)
    $trigger=if($null -ne $beat){Get-R7CandidateUtf8Slice ([string]$draft.body_text) ([int]$beat.start_byte) ([int]$beat.end_byte)}else{[string]$asset.visual_text_summary}
    $visualCards.Add([ordered]@{card_id="CARD-$sessionId-VISUAL-$('{0:000}' -f $visualOrder)";card_type='visual_insert';display_order=$visualOrder;status='ready';source_artifact_ids=@([string]$ledger.visual_coverage_ledger_id,[string]$assetSet.image_asset_set_id);visual_insert_task_id=$taskId;image_task_id=[string]$asset.asset_id;presentation_mode=[string]$presentation.visual_insert.presentation_mode;platform_surface_profile_id=[string]$presentation.visual_insert.platform_surface_profile_id;video_canvas=[ordered]@{width_px=1080;height_px=1920;aspect_ratio=[ordered]@{ratio_width=9;ratio_height=16;orientation='portrait'}};visual_asset_canvas=[ordered]@{width_px=[int]$asset.width_px;height_px=[int]$asset.height_px;aspect_ratio=[ordered]@{ratio_width=([int]$asset.width_px/$ratioDivisor);ratio_height=([int]$asset.height_px/$ratioDivisor);orientation=$(if([int]$asset.width_px -gt [int]$asset.height_px){'landscape'}elseif([int]$asset.width_px -lt [int]$asset.height_px){'portrait'}else{'square'})}};placement_slot=[ordered]@{x=[double]$presentation.visual_insert.placement.x;y=[double]$presentation.visual_insert.placement.y;width=[double]$presentation.visual_insert.placement.width;height=$slotHeight};aspect_ratio_verification_status='pass';trigger_text=$trigger;insert_after_text=$trigger;insert_before_text='下一个语义节点';narrative_function=[string]$task.value_proof.expected_viewer_change;viewer_problem=[string]$task.value_proof.viewer_problem_without_visual;asset_status=$(if($asset.source_mode -eq 'reused_verified'){'reused_verified'}else{'generated'});asset_id=[string]$asset.asset_id;relative_path=[string]$asset.relative_path;sha256=[string]$asset.sha256;sidecar_path=[string]$asset.sidecar_path;prompt_path=[string]$asset.generation_record_path;generation_record_path=[string]$asset.generation_record_path;preview_alt=[string]$asset.alt_text;visual_text_summary=[string]$asset.visual_text_summary;warning_codes=@()})
  }

  $taskSummaries=[Collections.Generic.List[object]]::new();foreach($task in @($ledger.accepted_visual_tasks)){
    $taskId=[string]$task.visual_task_id
    $derivedAssetStatus=if($assetByTask.ContainsKey($taskId)){'materialized'}elseif($visualDeliveryReadiness-eq'blocked'){'blocked'}elseif($visualDeliveryReadiness-eq'waiting_assets'){'waiting_asset'}else{'planned'}
    $taskSummaries.Add([ordered]@{visual_task_id=$taskId;disposition=[string]$task.disposition;capture_mode=[string]$task.capture_mode;asset_status=$derivedAssetStatus;provider_attempt_count=$(if([string]$task.disposition -eq 'generate_visual'){[int]$assetSet.provider_invocation_count}else{0});source_capture_attempt_count=0})
  }
  $counts=[ordered]@{derived_visual_asset_count=$taskSummaries.Count;materialized_visual_asset_count=@($taskSummaries|Where-Object{$_.asset_status -eq 'materialized'}).Count;provider_generation_task_count=@($taskSummaries|Where-Object{$_.disposition -eq 'generate_visual'}).Count;provider_generation_attempt_count=[int]$assetSet.provider_invocation_count;source_capture_task_count=@($taskSummaries|Where-Object{$_.disposition -eq 'use_source_evidence' -and $_.capture_mode -eq 'new_capture'}).Count;source_capture_attempt_count=0;visual_insert_occurrence_count=@($ledger.visual_insert_occurrences).Count;platform_rendition_count=$units.Count;cover_asset_count=$coverCards.Count}
  $sourceIds=[object[]]@($SourceSet.SourceMap|ForEach-Object{[string]$_.artifact_id})
  $traceCards=[Collections.Generic.List[object]]::new();$traceOrder=0;foreach($source in @($SourceSet.SourceMap)){$traceOrder++;$traceCards.Add([ordered]@{card_id="CARD-$sessionId-TRACE-$('{0:000}' -f $traceOrder)";card_type='trace';display_order=$traceOrder;status='trace_only';source_artifact_ids=@([string]$source.artifact_id);artifact_type=[string]$source.artifact_type;artifact_id=[string]$source.artifact_id;label=[string]$source.artifact_type;relative_path=[string]$source.relative_path;materialization_status='materialized'})}
  $actionCards=[Collections.Generic.List[object]]::new();$primaryPackage=@($platformPackage.packages|Where-Object{$_.platform -eq $platformPackage.primary_platform})|Select-Object -First 1
  foreach($requiredAction in @('publish_primary_manually','revise_copy','revise_visual')){if($null -eq (@($actions.actions|Where-Object{$_.action_code -eq $requiredAction -and $_.lifecycle_status -eq 'active'})|Select-Object -First 1)){throw "enum_registry_error:$requiredAction"}}
  $actionCards.Add([ordered]@{card_id="CARD-$sessionId-ACTION-001";card_type='action';display_order=1;status='ready';source_artifact_ids=@([string]$platformPackage.platform_package_id);action='publish_primary_manually';label=[string]$presentation.actions.publish_primary_manually.label;instruction=[string]$presentation.actions.publish_primary_manually.instruction;reply_example=[string]$presentation.actions.publish_primary_manually.reply_example;target_artifact_id=[string]$platformPackage.platform_package_id;is_primary=$true})
  $actionCards.Add([ordered]@{card_id="CARD-$sessionId-ACTION-002";card_type='action';display_order=2;status='ready';source_artifact_ids=@([string]$draft.draft_id);action='revise_copy';label=[string]$presentation.actions.revise_copy.label;instruction=[string]$presentation.actions.revise_copy.instruction;reply_example=[string]$presentation.actions.revise_copy.reply_example;target_artifact_id=[string]$draft.draft_id;is_primary=$false})
  $actionOrder=2;foreach($task in @($ledger.accepted_visual_tasks)){$actionOrder++;$actionCards.Add([ordered]@{card_id="CARD-$sessionId-ACTION-$('{0:000}' -f $actionOrder)";card_type='action';display_order=$actionOrder;status='ready';source_artifact_ids=@([string]$task.visual_task_id);action='revise_visual';label=[string]$presentation.actions.revise_visual.label;instruction=[string]$presentation.actions.revise_visual.instruction;reply_example=[string]$presentation.actions.revise_visual.reply_example;target_artifact_id=[string]$task.visual_task_id;is_primary=$false})}

  $finalDeliveryId="FD-$sessionId-001";$revisionId="DREV-$sessionId-001"
  $bindings=[object[]]@($SourceSet.SourceMap|ForEach-Object{[ordered]@{artifact_type=[string]$_.artifact_type;artifact_id=[string]$_.artifact_id;sha256=[string]$_.sha256}})
  $inner=[ordered]@{
    schema_id='taoge://schemas/final-delivery/typed-components/v0.5';schema_version='typed_components_v0.5';render_input_id="RIN-$sessionId-001";final_delivery_id=$finalDeliveryId;account_name=$(if($isHotspot){[string]$s.selected_topic_source.Payload.account_snapshot_ref.artifact_id}else{[string]$intake.account.account_display_name});session_id=$sessionId;research_run_id=$(if($isHotspot){[string]$s.hotspot_research_set.Payload.research_set_id}else{[string]$intake.content_source_id});template_version='final-delivery-template-v0.5';generated_at=[DateTimeOffset]::UtcNow.ToString('o');topic=[ordered]@{title=[string]$brief.core_promise;why_now=[string]$brief.content_goal;content_format='short_video_spoken_script'}
    content_structure_card=[ordered]@{card_id="CARD-$sessionId-STRUCTURE-001";card_type='content_structure';status=$(if($structure.plan_status -eq 'ready_with_warnings'){'ready_with_warnings'}else{'ready'});source_artifact_ids=@([string]$structure.structure_plan_id,[string]$beatMap.beat_map_id);structure_plan_id=[string]$structure.structure_plan_id;selected_strategy_ref=[string]$structure.selected_strategy_ref;audience_entry_state=[string]$structure.audience_entry_state;audience_exit_state=[string]$structure.audience_exit_state;core_promise=[string]$structure.core_promise;stages=[object[]]$stageCards.ToArray();warning_items=@()}
    content_beat_cards=[object[]]$beatCards.ToArray();script_review_card=[ordered]@{card_id="CARD-$sessionId-REVIEW-001";card_type='script_review';status=$(if($review.review_status -eq 'pass_with_warnings'){'ready_with_warnings'}else{'ready'});source_artifact_ids=@([string]$review.script_design_review_id,[string]$decision.content_revision_decision_id,[string]$alignment.alignment_review_id);script_design_review_id=[string]$review.script_design_review_id;content_revision_decision_id=[string]$decision.content_revision_decision_id;alignment_review_id=[string]$alignment.alignment_review_id;script_readiness=[string]$decision.derived_script_readiness;alignment_status=[string]$alignment.alignment_status;issue_items=[object[]]$issueCards.ToArray()}
    visual_coverage_summary=[ordered]@{card_id="CARD-$sessionId-COVERAGE-001";card_type='visual_coverage_summary';status=$(if($visualDeliveryReadiness-eq'ready_with_warnings'){'ready_with_warnings'}elseif($visualDeliveryReadiness-eq'ready'){'ready'}elseif($visualDeliveryReadiness-eq'blocked'){'blocked'}else{'waiting_assets'});source_artifact_ids=@([string]$visualPackage.visual_coverage_ledger_id,[string]$assetSet.image_asset_set_id);visual_coverage_ledger_id=[string]$ledger.visual_coverage_ledger_id;coverage_completeness_status=[string]$ledger.coverage_completeness_status;visual_delivery_readiness=$visualDeliveryReadiness;unresolved_beat_ids=[object[]]@($ledger.unresolved_beat_ids);task_summaries=[object[]]$taskSummaries.ToArray();counts=[pscustomobject]$counts}
    script_card=[ordered]@{card_id="CARD-$sessionId-SCRIPT-001";card_type='script';status='ready_with_warnings';source_artifact_ids=@([string]$draft.draft_id);hook_text=[string]$beatCards[0].source_excerpt;final_text=[string]$draft.body_text;copy_label='口播文案';source_draft_id=[string]$draft.draft_id;character_count=[Globalization.StringInfo]::new([string]$draft.body_text).LengthInTextElements;revision_note='保留用户直供稿，结构与视觉建议单独记录。'}
    production_status=[ordered]@{image_assets_status=[string]$assetSet.asset_set_status;cover_quality_status='pass';overall_quality_status=$(if($warnings.Count){'pass_with_warnings'}else{'pass'});script_readiness=[string]$decision.derived_script_readiness;visual_coverage_status=[string]$ledger.coverage_completeness_status;alignment_status=[string]$alignment.alignment_status;delivery_readiness='ready_all_target_platforms';platform_delivery_scope_status='ready_all_target_platforms';derived_by='derive_delivery_readiness_v0.5';warning_codes=[object[]]@($warnings|Where-Object{$_.resolution_status -ne 'resolved'}|ForEach-Object{[string]$_.warning_code}|Sort-Object -Unique)}
    delivery_revision=[ordered]@{delivery_revision_id=$revisionId;revision_no=1;revision_status='preparing';source_artifact_bindings=$bindings;generated_view_paths=[ordered]@{final_html='deliverables/final-delivery.html';final_script='deliverables/final-script.md';final_visual_plan='deliverables/final-visual-plan.md';final_platform_package='deliverables/final-platform-package.md';content_delivery_record='deliverables/content-delivery-record.md';revision_manifest='deliverables/p0/delivery-revision.json'};semantic_gate_status='pending'}
    run_provenance=[ordered]@{run_purpose='regression';reused_content=$false;reused_research=$false;executed_scopes=$(if($isHotspot){@('hotspot_semantic_chain','delivery_topic_freshness_review','deterministic_candidate_compile')}else{@('direct_content_semantic_chain','verified_asset_reuse','deterministic_candidate_compile')});not_executed_scopes=@('new_image_provider','platform_login','publishing');user_summary=$(if($isHotspot){'热点选题经交付前时效复核后，由确定性 compiler 组装为交付候选。'}else{'同一用户直供稿的新 session 回归；语义节点按 R7 task envelope 执行，候选由确定性 compiler 组装。'})}
    duration_estimate=[ordered]@{duration_estimate_status='not_available';source_text_digest=[string]$draft.normalized_body_digest;not_available_reason='没有本账号已校准语速、实录音频或实测时长；不把 fixture 常量带入真实交付。'};warning_items=[object[]]$warnings.ToArray();cover_cards=[object[]]$coverCards.ToArray();visual_insert_cards=[object[]]$visualCards.ToArray();platform_cards=[object[]]$platformCards.ToArray();platform_delivery_units=[object[]]$units.ToArray();trace_cards=[object[]]$traceCards.ToArray();action_cards=[object[]]$actionCards.ToArray();source_artifact_ids=$sourceIds
  }
  $innerObject=[pscustomobject](($inner|ConvertTo-Json -Depth 70)|ConvertFrom-Json)
  $derived=Get-P0V5DeliveryReadiness $innerObject;$innerObject.production_status.delivery_readiness=[string]$derived.delivery_readiness;$innerObject.production_status.platform_delivery_scope_status=[string]$derived.platform_delivery_scope_status;$innerObject.production_status.warning_codes=[object[]]$derived.warning_codes
  $innerErrors=@(Test-P0RenderInputV05Contract $innerObject);if($innerErrors.Count){throw ('candidate_v05_compatibility_contract_error:'+($innerErrors -join ';'))}

  $actionRegistryPath=$(if($isHotspot){'routes/r7-action-registry.yaml'}else{'routes/r7-action-registry.v0.1.yaml'});$presentationRegistryPath=$(if($isHotspot){'routes/r7-delivery-presentation-registry.yaml'}else{'routes/r7-delivery-presentation-registry.v0.1.yaml'})
  $registryMap=@([ordered]@{path=$actionRegistryPath;sha256=Get-R7RuntimeHash (Join-Path $ProjectRoot $actionRegistryPath)},[ordered]@{path=$presentationRegistryPath;sha256=Get-R7RuntimeHash (Join-Path $ProjectRoot $presentationRegistryPath)})
  $bindingDigest=Get-R7RuntimeObjectDigest ([ordered]@{sources=$SourceSet.SourceMap;registries=$registryMap})
  $events=@(Get-P0EvidenceEvents (Join-Path $SessionRoot 'intermediate/p0/execution-events.jsonl'))
  $semanticCount=@($events|Where-Object{$_.event_type -eq 'semantic.result_committed.v1' -and $_.event_source -eq 'agent_recorder'}).Count
  $deterministicCount=@($events|Where-Object{$_.event_source -eq 'runner' -and $_.state_after -eq 'succeeded'}).Count
  $contribution=[ordered]@{candidate_producer='deterministic_compiler';manual_patch_detected=$false;semantic_skill_step_completed_count=$semanticCount;deterministic_tool_step_completed_count=$deterministicCount;human_gate_completed_count=@($events|Where-Object{$_.event_source-eq'human_recorder'-and$_.state_after-eq'succeeded'}).Count;external_side_effect_step_completed_count=@($events|Where-Object{$_.event_source-in@('external_recorder','reconciler')-and$_.state_after-eq'succeeded'}).Count;agent_orchestrated_node_count=0}
  if($isHotspot){
    $researchSet=$s.hotspot_research_set.Payload;$selectedRef=Get-R7CandidateArtifactRef $s.selected_topic_source;$freshnessRef=Get-R7CandidateArtifactRef $s.topic_freshness_review
    $context=[ordered]@{content_origin='hotspot_selected_topic';content_source_ref=$selectedRef;research_set_ref=Get-R7CandidateArtifactRef $s.hotspot_research_set;selection_decision_ref=Get-R7CandidateArtifactRef $s.topic_selection_decision;selected_topic_source_ref=$selectedRef;freshness_review_ref=$freshnessRef}
    $networkReads=Get-R7RuntimeField $researchSet.research_run_record @('network_read_count');$parsedNetwork=0;if(-not[int]::TryParse($networkReads,[ref]$parsedNetwork)){$parsedNetwork=0}
    $captureAttempts=0;foreach($record in @($researchSet.source_records)){$value=Get-R7RuntimeField $record @('source_capture_attempt_count');$parsed=0;if([int]::TryParse($value,[ref]$parsed)){$captureAttempts+=$parsed}}
    $outer=[ordered]@{schema_id='taoge://schemas/final-delivery/typed-components/v0.7';schema_version='typed_components_v0.7';final_delivery_id=$finalDeliveryId;session_id=$sessionId;candidate_status=$(if($warnings.Count){'compiled_with_warnings'}else{'compiled'});action_registry_version='r7-action-registry-v0.2';presentation_registry_version='r7-delivery-presentation-registry-v0.2';compiler_provenance=[ordered]@{producer='deterministic_compiler';compiler_version='p0-deterministic-delivery-candidate-compiler-v0.7';compiled_at=[DateTimeOffset]::UtcNow.ToString('o')};content_source_context=$context;source_map=[object[]]$SourceSet.SourceMap;source_binding_digest=$bindingDigest;artifact_execution_contribution=$contribution;external_activity_counts=[ordered]@{network_read_count=$parsedNetwork;source_capture_attempt_count=$captureAttempts;image_provider_attempt_count=[int]$assetSet.provider_invocation_count;external_side_effect_step_completed_count=[int]$contribution.external_side_effect_step_completed_count};delivery_payload=$innerObject}
  }else{$outer=[ordered]@{schema_id='taoge://schemas/final-delivery/typed-components/v0.6';schema_version='typed_components_v0.6';final_delivery_id=$finalDeliveryId;session_id=$sessionId;candidate_status=$(if($warnings.Count){'compiled_with_warnings'}else{'compiled'});action_registry_version='r7-action-registry-v0.1';presentation_registry_version='r7-delivery-presentation-registry-v0.1';compiler_provenance=[ordered]@{producer='deterministic_compiler';compiler_version='p0-deterministic-delivery-candidate-compiler-v0.6';compiled_at=[DateTimeOffset]::UtcNow.ToString('o')};source_map=[object[]]$SourceSet.SourceMap;source_binding_digest=$bindingDigest;artifact_execution_contribution=$contribution;delivery_payload=$innerObject}}
  return [pscustomobject](($outer|ConvertTo-Json -Depth 80)|ConvertFrom-Json)
}

function Test-R7CandidateV06Contract {
  param([object]$Candidate)
  $errors=[Collections.Generic.List[string]]::new();$required=@('schema_id','schema_version','final_delivery_id','session_id','candidate_status','action_registry_version','presentation_registry_version','compiler_provenance','source_map','source_binding_digest','artifact_execution_contribution','delivery_payload')
  foreach($error in (Test-P0RequiredProperties $Candidate $required 'candidate_v06')){$errors.Add($error)}
  foreach($error in (Test-P0AllowedProperties $Candidate $required 'candidate_v06')){$errors.Add($error)}
  if($errors.Count){return [object[]]$errors.ToArray()}
  if($Candidate.schema_id -ne 'taoge://schemas/final-delivery/typed-components/v0.6' -or $Candidate.schema_version -ne 'typed_components_v0.6'){$errors.Add('candidate_v06_version_invalid')}
  if($Candidate.compiler_provenance.producer -ne 'deterministic_compiler' -or $Candidate.compiler_provenance.compiler_version -ne 'p0-deterministic-delivery-candidate-compiler-v0.6'){$errors.Add('candidate_v06_producer_invalid')}
  if(@($Candidate.source_map).Count -lt 12){$errors.Add('candidate_v06_source_map_incomplete')}
  if(-not(Test-P0Digest $Candidate.source_binding_digest)){$errors.Add('candidate_v06_binding_digest_invalid')}
  foreach($error in (Test-P0RenderInputV05Contract $Candidate.delivery_payload)){$errors.Add("candidate_v06_delivery_payload:$error")}
  return [object[]]$errors.ToArray()
}

function Test-R7ContentSourceContextV07 {
  param([object]$Context)
  $errors=[Collections.Generic.List[string]]::new();$required=@('content_origin','content_source_ref','research_set_ref','selection_decision_ref','selected_topic_source_ref','freshness_review_ref')
  foreach($e in(Test-P0RequiredProperties $Context $required 'content_source_context_v07')){$errors.Add($e)};foreach($e in(Test-P0AllowedProperties $Context $required 'content_source_context_v07')){$errors.Add($e)};if($errors.Count){return [object[]]$errors.ToArray()}
  if([string]$Context.content_origin-eq'user_supplied_draft'){foreach($name in @('research_set_ref','selection_decision_ref','selected_topic_source_ref','freshness_review_ref')){if($null-ne$Context.$name){$errors.Add("content_source_context_direct_ref_forbidden:$name")}}}
  elseif([string]$Context.content_origin-eq'hotspot_selected_topic'){foreach($name in @('research_set_ref','selection_decision_ref','selected_topic_source_ref','freshness_review_ref')){if($null-eq$Context.$name){$errors.Add("content_source_context_hotspot_ref_missing:$name")}}}
  else{$errors.Add('content_source_context_origin_invalid')}
  return [object[]]$errors.ToArray()
}

function Test-R7CandidateFreshnessBinding {
  param([object]$SelectedItem,[object]$FreshnessItem)
  $errors=[Collections.Generic.List[string]]::new();$freshnessRef=Get-R7CandidateArtifactRef $FreshnessItem
  foreach($name in @('artifact_id','revision','sha256')){if([string]$SelectedItem.Payload.latest_freshness_review_ref.$name-ne[string]$freshnessRef.$name){$errors.Add("candidate_v07_freshness_current_mismatch:$name")}}
  if([string]$FreshnessItem.Payload.selected_topic_source_ref.artifact_id-ne[string]$SelectedItem.Pointer.artifact_id){$errors.Add('candidate_v07_review_source_identity_mismatch')}
  if([int]$FreshnessItem.Payload.selected_topic_source_ref.revision-ne([int]$SelectedItem.Pointer.revision-1)){$errors.Add('candidate_v07_review_source_revision_mismatch')}
  foreach($delta in @($FreshnessItem.Payload.source_record_deltas)){$mapped=Get-R7RuntimeField $FreshnessItem.Payload.component_digest_map @([string]$delta.source_record_id);if([string]$mapped-ne[string]$delta.component_digest){$errors.Add("candidate_v07_delta_digest_mismatch:$($delta.source_record_id)")}}
  return [object[]]$errors.ToArray()
}

function Test-R7CandidateV07Contract {
  param([object]$Candidate,[object]$SourceSet=$null)
  $errors=[Collections.Generic.List[string]]::new();$required=@('schema_id','schema_version','final_delivery_id','session_id','candidate_status','action_registry_version','presentation_registry_version','compiler_provenance','content_source_context','source_map','source_binding_digest','artifact_execution_contribution','external_activity_counts','delivery_payload')
  foreach($e in(Test-P0RequiredProperties $Candidate $required 'candidate_v07')){$errors.Add($e)};foreach($e in(Test-P0AllowedProperties $Candidate $required 'candidate_v07')){$errors.Add($e)};if($errors.Count){return [object[]]$errors.ToArray()}
  if($Candidate.schema_id-ne'taoge://schemas/final-delivery/typed-components/v0.7'-or$Candidate.schema_version-ne'typed_components_v0.7'){$errors.Add('candidate_v07_version_invalid')}
  if($Candidate.compiler_provenance.producer-ne'deterministic_compiler'-or$Candidate.compiler_provenance.compiler_version-ne'p0-deterministic-delivery-candidate-compiler-v0.7'){$errors.Add('candidate_v07_producer_invalid')}
  foreach($e in(Test-R7ContentSourceContextV07 $Candidate.content_source_context)){$errors.Add($e)}
  $requiredTypes=if($Candidate.content_source_context.content_origin-eq'hotspot_selected_topic'){@('hotspot_research_request','hotspot_research_set','topic_selection_panel','topic_selection_decision','selected_topic_source','topic_freshness_review','content_brief','short_video_structure_plan','draft','content_beat_map','script_design_review','content_revision_decision','visual_coverage_ledger','image_asset_set','script_visual_alignment_review','platform_package','cover_composition')}else{@('direct_content_intake','content_brief','short_video_structure_plan','draft','content_beat_map','script_design_review','content_revision_decision','visual_coverage_ledger','image_asset_set','script_visual_alignment_review','platform_package','cover_composition')}
  $actualTypes=@($Candidate.source_map|ForEach-Object{[string]$_.artifact_type});foreach($type in $requiredTypes){if($type-notin$actualTypes){$errors.Add("candidate_v07_source_type_missing:$type")}};if($actualTypes.Count-ne$requiredTypes.Count){$errors.Add('candidate_v07_source_map_cardinality_invalid')}
  if(-not(Test-P0Digest $Candidate.source_binding_digest)){$errors.Add('candidate_v07_binding_digest_invalid')}
  foreach($name in @('network_read_count','source_capture_attempt_count','image_provider_attempt_count','external_side_effect_step_completed_count')){if([int]$Candidate.external_activity_counts.$name-lt0){$errors.Add("candidate_v07_activity_count_invalid:$name")}}
  foreach($e in(Test-P0RenderInputV05Contract $Candidate.delivery_payload)){$errors.Add("candidate_v07_delivery_payload:$e")}
  if($null-ne$SourceSet-and$Candidate.content_source_context.content_origin-eq'hotspot_selected_topic'){
    foreach($e in(Test-R7CandidateFreshnessBinding $SourceSet.Sources.selected_topic_source $SourceSet.Sources.topic_freshness_review)){$errors.Add($e)}
  }
  return [object[]]$errors.ToArray()
}

function Commit-R7DeterministicArtifact {
  param([string]$ProjectRoot,[string]$SessionRoot,[string]$NodeId,[string]$ArtifactType,[string]$ArtifactId,[object]$Payload,[string]$Status,[string[]]$SourceArtifactIds,[string[]]$CheckIds)
  $plan=Read-P0JsonFile (Join-Path $SessionRoot 'intermediate/p0/session-execution-plan.json');$projection=Read-P0JsonFile (Join-Path $SessionRoot 'intermediate/p0/state-projection.json')
  $step=@($plan.steps|Where-Object{$_.step_id -eq $projection.next_step_id})|Select-Object -First 1
  if($null -eq $step -or [string]$step.node_id -ne $NodeId -or [string]$step.step_kind -ne 'deterministic_tool'){return New-R7RuntimeResult 'deterministic_node_not_current' 2 $projection @($NodeId)}
  $revisionRelative="intermediate/r7/revisions/$ArtifactType/$ArtifactId.json";$pointerRelative="intermediate/r7/current/$ArtifactType.json"
  $revisionPath=Resolve-R7RuntimePath $SessionRoot $revisionRelative;$pointerPath=Resolve-R7RuntimePath $SessionRoot $pointerRelative;$text=ConvertTo-P0EvidenceJsonText $Payload;$digest=Get-R7RuntimeTextDigest $text
  if(Test-Path -LiteralPath $pointerPath){$existing=Read-R7JsonFile $pointerPath;if([string]$existing.sha256 -eq $digest){return New-R7RuntimeResult 'duplicate_reused' 0 ([pscustomobject]@{ArtifactId=$ArtifactId;PointerPath=$pointerRelative;Sha256=$digest;NextStepId=[string]$projection.next_step_id}) @()};return New-R7RuntimeResult 'deterministic_current_conflict' 1 $existing @()}
  Write-P0EvidenceAtomicText $revisionPath $text
  $eventPath=Join-Path $SessionRoot 'intermediate/p0/execution-events.jsonl';$events=@(Get-P0EvidenceEvents $eventPath);$safeSession=([string]$plan.session_id-replace'[^A-Za-z0-9_-]','-');$predicted='EVT-'+$safeSession+'-'+($events.Count+1).ToString('0000')
  try{$lineagePath=Write-P0EvidenceLineage $SessionRoot $ArtifactId $ArtifactType $predicted $SourceArtifactIds $revisionRelative $digest 'pass_with_warnings' 'trace_only' $CheckIds}catch{return New-R7RuntimeResult 'lineage_commit_error' 1 $Payload @($_.Exception.Message)}
  $pointer=[ordered]@{schema_id='taoge://schemas/r7/semantic-current-pointer/v0.1';schema_version='0.1';artifact_type=$ArtifactType;artifact_id=$ArtifactId;revision=1;revision_path=$revisionRelative;sha256=$digest;status=$Status;task_envelope_id="TASK-$($plan.session_id)-$NodeId-deterministic";submission_id="RUN-$($plan.session_id)-$NodeId-deterministic";producer_event_id=$predicted;committed_at=[DateTimeOffset]::UtcNow.ToString('o')}
  Write-P0EvidenceAtomicText $pointerPath (ConvertTo-P0EvidenceJsonText $pointer)
  $inputDigest=Get-R7RuntimeObjectDigest $SourceArtifactIds;$write=Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId ([string]$step.step_id) -EventType 'deterministic.result_committed.v1' -EventSource 'runner' -StateBefore 'ready' -StateAfter 'succeeded' -PayloadDigest $digest -IdempotencyKey "$($plan.session_id):${NodeId}:$inputDigest" -ExpectedLastSequenceNo $events.Count -ResultCode $Status -SafeSummary 'Deterministic workflow artifact committed' -OutputArtifactIds @($ArtifactId) -InputDigest $inputDigest -ExecutionAttemptId "ATT-$($plan.session_id)-$NodeId-1"
  if($write.ExitCode -ne 0){return New-R7RuntimeResult $write.ResultCode $write.ExitCode $Payload $write.Errors}
  $updated=Update-P0StateProjection $SessionRoot $plan $eventPath $false;if($updated.ExitCode -ne 0){return New-R7RuntimeResult $updated.ResultCode $updated.ExitCode $Payload $updated.Errors};[void](Write-P0ResumeSummary $SessionRoot $plan $updated.Projection)
  return New-R7RuntimeResult 'deterministic_artifact_committed' 0 ([pscustomobject]@{ArtifactId=$ArtifactId;RevisionPath=$revisionRelative;PointerPath=$pointerRelative;LineagePath=$lineagePath.Substring($SessionRoot.Length+1).Replace('\','/');Sha256=$digest;EventId=[string]$write.Event.event_id;NextStepId=[string]$updated.Projection.next_step_id}) @()
}

function Invoke-R7CandidateCompile {
  param([string]$ProjectRoot,[string]$Session)
  $sessionRoot=[IO.Path]::GetFullPath($Session)
  try{$sourceSet=Get-R7CandidateSourceSet $sessionRoot;$candidate=New-R7CandidatePayload $ProjectRoot $sessionRoot $sourceSet;$errors=@($(if($candidate.schema_id-eq'taoge://schemas/final-delivery/typed-components/v0.7'){Test-R7CandidateV07Contract $candidate $sourceSet}else{Test-R7CandidateV06Contract $candidate}));if($errors.Count){return New-R7RuntimeResult 'candidate_integration_error' 1 $candidate $errors}}
  catch{$code=if($_.Exception.Message -like 'asset_review_binding_error*'){'asset_review_binding_error'}elseif($_.Exception.Message -like 'cross_artifact_binding_error*'){'cross_artifact_binding_error'}else{'candidate_integration_error'};return New-R7RuntimeResult $code 1 $null @($_.Exception.Message)}
  return Commit-R7DeterministicArtifact $ProjectRoot $sessionRoot 'delivery_candidate_compile' 'final_delivery_render_candidate' ([string]$candidate.final_delivery_id) $candidate ([string]$candidate.candidate_status) @($sourceSet.SourceMap|ForEach-Object{[string]$_.artifact_id}) $(if($candidate.schema_id-eq'taoge://schemas/final-delivery/typed-components/v0.7'){@('R7-F42','R7-F50','R7-F68','R7-F81')}else{@('R7-F09','R7-F10','R7-F11','R7-F13')})
}

function Get-R7ExecutionContributionHtml {
  param([object]$Contribution)
  $pairs=[ordered]@{'语义 Skill 完成'=$Contribution.semantic_skill_step_completed_count;'确定性工具完成'=$Contribution.deterministic_tool_step_completed_count;'人类门禁'=$Contribution.human_gate_completed_count;'外部副作用'=$Contribution.external_side_effect_step_completed_count;'手工 candidate 补丁'=$(if($Contribution.manual_patch_detected){'是'}else{'否'});'Agent 临场编排节点'=$Contribution.agent_orchestrated_node_count}
  return [string]::Join("`n",@($pairs.GetEnumerator()|ForEach-Object{'<article class="card"><h3>'+[string](Encode-P0V2Html $_.Key)+'</h3><p>'+[string](Encode-P0V2Html ([string]$_.Value))+'</p></article>'}))
}

function Get-R7HotspotSourceHtml {
  param([object]$Candidate,[string]$SessionRoot)
  if(-not(Get-Command Get-R7HotspotComponent -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'R7HotspotContractHelper.ps1')}
  $set=(Get-R7CandidateCurrentArtifact $SessionRoot 'hotspot_research_set').Payload;$decision=(Get-R7CandidateCurrentArtifact $SessionRoot 'topic_selection_decision').Payload;$selected=(Get-R7CandidateCurrentArtifact $SessionRoot 'selected_topic_source').Payload;$review=(Get-R7CandidateCurrentArtifact $SessionRoot 'topic_freshness_review').Payload
  $cards=[Collections.Generic.List[string]]::new();$cards.Add('<article class="card"><h3>研究集合</h3><p>'+[string](Encode-P0V2Html ([string]$set.research_set_id))+'</p><p>状态：'+[string](Encode-P0V2Html ([string]$set.research_set_status))+'</p></article>')
  $cards.Add('<article class="card"><h3>人工选题决定</h3><p>'+[string](Encode-P0V2Html ([string]$decision.decision_code))+'</p><p>'+[string](Encode-P0V2Html ([string]$decision.human_instruction_summary))+'</p></article>')
  $cards.Add('<article class="card"><h3>当前选题来源</h3><p>revision '+[string](Encode-P0V2Html ([string]$selected.selected_topic_source_revision))+'</p><p>状态：'+[string](Encode-P0V2Html ([string]$selected.selected_source_status))+'</p></article>')
  $cards.Add('<article class="card"><h3>交付前时效复核</h3><p>'+[string](Encode-P0V2Html ([string]$review.change_class))+'</p><p>核对时间：'+[string](Encode-P0V2Html ([string]$review.checked_at))+'</p><p>'+[string](Encode-P0V2Html ([string]$review.review_reason))+'</p></article>')
  $packet=Get-R7HotspotComponent $set 'topic_evidence_packet' ([string]$selected.topic_evidence_packet_ref.component_id);if($null-ne$packet){$cards.Add('<article class="card"><h3>事实 / 传播 / 风险</h3><p>事实：'+[string](Encode-P0V2Html ([string]$packet.event_fact_status))+'</p><p>传播：'+[string](Encode-P0V2Html ([string]$packet.propagation_status))+'</p><p>风险：'+[string](Encode-P0V2Html ([string]$packet.risk_level))+'</p></article>')}
  foreach($source in @($set.source_records)){$url=Get-R7RuntimeField $source @('source_url','url');if(-not[string]::IsNullOrWhiteSpace($url)){$cards.Add('<article class="card"><h3>来源记录</h3><p>'+[string](Encode-P0V2Html ([string](Get-R7RuntimeField $source @('source_record_id'))))+'</p><p>'+[string](Encode-P0V2Html $url)+'</p></article>')}}
  return [string]::Join("`n",$cards.ToArray())
}

function Test-R7RenderedHtmlV06 {
  param([string]$Html,[string]$OutputPath,[string]$SessionRoot,[string]$ExpectedVersion='0.6.0')
  $errors=[Collections.Generic.List[string]]::new();if($Html -match '\{\{[^}]+\}\}'){$errors.Add('v06_unresolved_template_token')};if($Html -match '(?is)<\s*script\b|\bon[a-z]+\s*=|javascript\s*:'){$errors.Add('v06_unsafe_html_output')}
  foreach($token in @("data-template-version=`"$ExpectedVersion`"",'id="content-structure"','id="script-review"','id="visual-coverage"','id="execution-transparency"')){if($Html -notmatch [regex]::Escape($token)){$errors.Add("render_business_section_missing:$token")}}
  foreach($error in (Get-P0V2BrokenReferences $Html $OutputPath $SessionRoot)){$errors.Add($error)}
  return [object[]]$errors.ToArray()
}

function Invoke-R7DeliveryRender {
  param([string]$ProjectRoot,[string]$Session)
  $sessionRoot=[IO.Path]::GetFullPath($Session)
  try{$current=Get-R7CandidateCurrentArtifact $sessionRoot 'final_delivery_render_candidate';$candidate=$current.Payload;$isV07=$candidate.schema_id-eq'taoge://schemas/final-delivery/typed-components/v0.7';$errors=@($(if($isV07){Test-R7CandidateV07Contract $candidate}else{Test-R7CandidateV06Contract $candidate}));if($errors.Count){return New-R7RuntimeResult 'candidate_integration_error' 1 $candidate $errors};$inner=$candidate.delivery_payload
    $views=New-P0V5ViewTexts $inner $sessionRoot $ProjectRoot;$fragmentPath=Join-Path $ProjectRoot $(if($isV07){'templates/final-delivery/final-delivery.v0.7.hotspot-fragment.html'}else{'templates/final-delivery/final-delivery.v0.6.execution-fragment.html'});$fragment=Get-Content -Raw -Encoding UTF8 $fragmentPath;$fragment=$fragment.Replace('{{execution_contribution_cards}}',(Get-R7ExecutionContributionHtml $candidate.artifact_execution_contribution));if($isV07){$fragment=$fragment.Replace('{{hotspot_source_cards}}',(Get-R7HotspotSourceHtml $candidate $sessionRoot))}
    $version=$(if($isV07){'0.7.0'}else{'0.6.0'});$html=$views.Html.Replace('data-template-version="0.5.0"',"data-template-version=`"$version`"").Replace('</main>',($fragment+"`n</main>"));$paths=$inner.delivery_revision.generated_view_paths
    $writeMap=[ordered]@{final_script=[pscustomobject]@{Path=[string]$paths.final_script;Text=$views.FinalScript};final_visual_plan=[pscustomobject]@{Path=[string]$paths.final_visual_plan;Text=$views.FinalVisualPlan};final_platform_package=[pscustomobject]@{Path=[string]$paths.final_platform_package;Text=$views.FinalPlatformPackage};content_delivery_record=[pscustomobject]@{Path=[string]$paths.content_delivery_record;Text=$views.ContentDeliveryRecord};final_html=[pscustomobject]@{Path=[string]$paths.final_html;Text=$html}}
    foreach($entry in $writeMap.GetEnumerator()){Write-P0V2AtomicText (Join-Path $sessionRoot ([string]$entry.Value.Path)) ([string]$entry.Value.Text)}
    $htmlPath=Join-Path $sessionRoot ([string]$paths.final_html);$htmlErrors=@(Test-R7RenderedHtmlV06 (Get-Content -Raw -Encoding UTF8 $htmlPath) $htmlPath $sessionRoot $version);if($isV07-and((Get-Content -Raw -Encoding UTF8 $htmlPath)-notmatch'id="source-currentness"')){$htmlErrors+=@('v07_business_section_missing:source-currentness')};if($htmlErrors.Count){throw ('rendered_html_invalid:'+($htmlErrors -join ';'))}
    $baseTemplate=Join-Path $ProjectRoot 'templates/final-delivery/final-delivery.v0.5.template.html';$templateDigest=Get-R7RuntimeObjectDigest @((Get-R7RuntimeHash $baseTemplate),(Get-R7RuntimeHash $fragmentPath));$candidateDigest=[string]$current.Sha256;$payloadDigest=Get-R7RuntimeObjectDigest $inner;$htmlDigest=Get-R7RuntimeHash $htmlPath
    $receiptVersion=$(if($isV07){'0.7'}else{'0.6'});$receipt=[ordered]@{schema_id="taoge://schemas/final-delivery/render-receipt/v$receiptVersion";schema_version=$receiptVersion;receipt_id="RCP-$($candidate.final_delivery_id)";delivery_revision_id=[string]$inner.delivery_revision.delivery_revision_id;candidate_sha256=$candidateDigest;delivery_payload_sha256=$payloadDigest;renderer_version="final-delivery-renderer-v$receiptVersion";template_bundle_sha256=$templateDigest;output_html_sha256=$htmlDigest;rendered_at=[DateTimeOffset]::UtcNow.ToString('o')};Write-P0V2AtomicText (Join-Path $sessionRoot 'deliverables/p0/render-receipt.json') (ConvertTo-P0V2JsonText $receipt)
    $outputs=[Collections.Generic.List[object]]::new();foreach($entry in $writeMap.GetEnumerator()){$full=Join-Path $sessionRoot ([string]$entry.Value.Path);$outputs.Add([ordered]@{artifact_type=[string]$entry.Key;path=[string]$entry.Value.Path;sha256=Get-R7RuntimeHash $full})}
    $manifest=[ordered]@{schema_id="taoge://schemas/p0/delivery-revision/v$receiptVersion";schema_version=$receiptVersion;delivery_revision_id=[string]$inner.delivery_revision.delivery_revision_id;session_id=[string]$candidate.session_id;revision_no=1;revision_status='current';semantic_gate_status='pass';candidate_id=[string]$candidate.final_delivery_id;candidate_sha256=$candidateDigest;output_artifacts=[object[]]$outputs.ToArray();committed_at=[DateTimeOffset]::UtcNow.ToString('o')};Write-P0V2AtomicText (Join-Path $sessionRoot ([string]$paths.revision_manifest)) (ConvertTo-P0V2JsonText $manifest)
    $delivery=[ordered]@{schema_id="taoge://schemas/final-delivery/final-delivery/v$receiptVersion";schema_version=$receiptVersion;final_delivery_id=('DELIVERY-'+[string]$candidate.final_delivery_id);session_id=[string]$candidate.session_id;delivery_status=$(if($candidate.candidate_status -eq 'compiled_with_warnings'){'ready_with_warnings'}else{'delivery_ready'});candidate_ref=[ordered]@{artifact_id=[string]$candidate.final_delivery_id;sha256=$candidateDigest};renderer_version="final-delivery-renderer-v$receiptVersion";template_version="final-delivery-template-v$receiptVersion";html_path=[string]$paths.final_html;html_sha256=$htmlDigest;render_receipt_path='deliverables/p0/render-receipt.json';revision_manifest_path=[string]$paths.revision_manifest}
  }catch{return New-R7RuntimeResult 'render_compile_error' 1 $null @($_.Exception.Message)}
  return Commit-R7DeterministicArtifact $ProjectRoot $sessionRoot 'final_delivery_render' 'final_delivery' ([string]$delivery.final_delivery_id) ([pscustomobject](($delivery|ConvertTo-Json -Depth 20)|ConvertFrom-Json)) ([string]$delivery.delivery_status) @([string]$candidate.final_delivery_id) @('R7-H4-RENDER','R7-H4-LINKS','R7-H4-RECEIPT')
}

function Invoke-R7DeterministicNode {
  param([string]$ProjectRoot,[string]$Session)
  $sessionRoot=[IO.Path]::GetFullPath($Session);$plan=Read-P0JsonFile (Join-Path $sessionRoot 'intermediate/p0/session-execution-plan.json');$projection=Read-P0JsonFile (Join-Path $sessionRoot 'intermediate/p0/state-projection.json');$step=@($plan.steps|Where-Object{$_.step_id -eq $projection.next_step_id})|Select-Object -First 1
  if($null -eq $step -or [string]$step.step_kind -ne 'deterministic_tool'){return New-R7RuntimeResult 'deterministic_node_not_current' 2 $projection @()}
  switch([string]$step.node_id){'delivery_candidate_compile'{return Invoke-R7CandidateCompile $ProjectRoot $sessionRoot}'final_delivery_render'{return Invoke-R7DeliveryRender $ProjectRoot $sessionRoot}'viewport_acceptance'{if(-not(Get-Command Invoke-R7ViewportAcceptance -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'R7ViewportRuntime.ps1')};return Invoke-R7ViewportAcceptance $ProjectRoot $sessionRoot}'hotspot_research_request_commit'{if(-not(Get-Command Invoke-R7HotspotDeterministicNode -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'R7HotspotRuntime.ps1')};return Invoke-R7HotspotDeterministicNode $ProjectRoot $sessionRoot ([string]$step.node_id)}'topic_panel_projection'{if(-not(Get-Command Invoke-R7HotspotDeterministicNode -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'R7HotspotRuntime.ps1')};return Invoke-R7HotspotDeterministicNode $ProjectRoot $sessionRoot ([string]$step.node_id)}'selected_topic_source_commit'{if(-not(Get-Command Invoke-R7HotspotDeterministicNode -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'R7HotspotRuntime.ps1')};return Invoke-R7HotspotDeterministicNode $ProjectRoot $sessionRoot ([string]$step.node_id)}'delivery_topic_freshness_apply'{if(-not(Get-Command Invoke-R7HotspotDeterministicNode -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'R7HotspotRuntime.ps1')};return Invoke-R7HotspotDeterministicNode $ProjectRoot $sessionRoot ([string]$step.node_id)}default{return New-R7RuntimeResult 'deterministic_node_not_compiled' 2 $step @([string]$step.node_id)}}
}
