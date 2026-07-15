Set-StrictMode -Version 2.0

function Test-R7HotspotDigest {
  param([object]$Value)
  return $null -ne $Value -and [string]$Value -match '^sha256:[0-9a-f]{64}$'
}

function Test-R7HotspotArtifactRef {
  param([object]$Ref,[string]$Prefix,[switch]$AllowNull)
  $errors=[Collections.Generic.List[string]]::new()
  if($null -eq $Ref){if(-not $AllowNull){$errors.Add("${Prefix}_missing")};return [object[]]$errors.ToArray()}
  foreach($name in @('artifact_id','revision','sha256')){if(-not(Test-R7HasProperty $Ref $name)){$errors.Add("${Prefix}_required_missing:$name")}}
  if($errors.Count){return [object[]]$errors.ToArray()}
  if([string]::IsNullOrWhiteSpace([string]$Ref.artifact_id)){$errors.Add("${Prefix}_id_invalid")}
  if([int]$Ref.revision-lt1){$errors.Add("${Prefix}_revision_invalid")}
  if(-not(Test-R7HotspotDigest $Ref.sha256)){$errors.Add("${Prefix}_digest_invalid")}
  return [object[]]$errors.ToArray()
}

function Test-R7HotspotComponentRef {
  param([object]$Ref,[string]$Prefix,[object]$ContainerRef=$null,[object]$DigestMap=$null,[string[]]$AllowedTypes=@())
  $errors=[Collections.Generic.List[string]]::new()
  if($null-eq$Ref){$errors.Add("${Prefix}_missing");return [object[]]$errors.ToArray()}
  foreach($name in @('container_artifact_ref','component_type','component_id','component_sha256')){if(-not(Test-R7HasProperty $Ref $name)){$errors.Add("${Prefix}_required_missing:$name")}}
  if($errors.Count){return [object[]]$errors.ToArray()}
  foreach($errorItem in (Test-R7HotspotArtifactRef $Ref.container_artifact_ref "${Prefix}_container")){$errors.Add($errorItem)}
  if($AllowedTypes.Count-and[string]$Ref.component_type-notin$AllowedTypes){$errors.Add("${Prefix}_type_invalid")}
  if([string]::IsNullOrWhiteSpace([string]$Ref.component_id)){$errors.Add("${Prefix}_id_invalid")}
  if(-not(Test-R7HotspotDigest $Ref.component_sha256)){$errors.Add("${Prefix}_digest_invalid")}
  if($null-ne$ContainerRef){foreach($name in @('artifact_id','revision','sha256')){if([string]$Ref.container_artifact_ref.$name-ne[string]$ContainerRef.$name){$errors.Add("${Prefix}_container_mismatch:$name")}}}
  if($null-ne$DigestMap){$expected=Get-R7RuntimeField $DigestMap @([string]$Ref.component_id);if([string]::IsNullOrWhiteSpace($expected)){$errors.Add("${Prefix}_digest_map_missing")}elseif($expected-ne[string]$Ref.component_sha256){$errors.Add("${Prefix}_digest_map_mismatch")}}
  return [object[]]$errors.ToArray()
}

function Test-R7HotspotLocalComponentRef {
  param([object]$Ref,[string]$Prefix,[object]$DigestMap,[string[]]$AllowedTypes=@())
  $errors=[Collections.Generic.List[string]]::new();if($null-eq$Ref){$errors.Add("${Prefix}_missing");return [object[]]$errors.ToArray()}
  foreach($name in @('component_type','component_id','component_sha256')){if(-not(Test-R7HasProperty $Ref $name)){$errors.Add("${Prefix}_required_missing:$name")}}
  if($errors.Count){return [object[]]$errors.ToArray()};if($AllowedTypes.Count-and[string]$Ref.component_type-notin$AllowedTypes){$errors.Add("${Prefix}_type_invalid")};if(-not(Test-R7HotspotDigest $Ref.component_sha256)){$errors.Add("${Prefix}_digest_invalid")}
  $expected=Get-R7RuntimeField $DigestMap @([string]$Ref.component_id);if([string]::IsNullOrWhiteSpace($expected)){$errors.Add("${Prefix}_digest_map_missing")}elseif($expected-ne[string]$Ref.component_sha256){$errors.Add("${Prefix}_digest_map_mismatch")};return [object[]]$errors.ToArray()
}

function ConvertTo-R7HotspotCanonicalValue {
  param([object]$Value)
  if($null-eq$Value){return $null}
  if($Value-is[string]-or$Value-is[ValueType]){return $Value}
  if($Value-is[Collections.IDictionary]){
    $ordered=[ordered]@{};foreach($key in @($Value.Keys|ForEach-Object{[string]$_}|Sort-Object)){$ordered[$key]=ConvertTo-R7HotspotCanonicalValue $Value[$key]};return $ordered
  }
  if($Value-is[Collections.IEnumerable]){$list=[Collections.Generic.List[object]]::new();foreach($item in $Value){$list.Add((ConvertTo-R7HotspotCanonicalValue $item))};return [object[]]$list.ToArray()}
  $result=[ordered]@{};foreach($name in @($Value.PSObject.Properties.Name|Sort-Object)){$result[$name]=ConvertTo-R7HotspotCanonicalValue $Value.$name};return $result
}

function Get-R7HotspotCanonicalDigest {
  param([object]$Value)
  $canonical=ConvertTo-R7HotspotCanonicalValue $Value
  return Get-R7RuntimeTextDigest ($canonical|ConvertTo-Json -Depth 80 -Compress)
}

function Test-R7HotspotResearchRequest {
  param([object]$Request)
  $errors=[Collections.Generic.List[string]]::new();$required=@('schema_id','schema_version','research_request_id','research_request_revision','supersedes_request_ref','account_identity_ref','account_snapshot_ref','radar_policy_ref','triggering_decision_ref','triggering_freshness_review_ref','prior_research_set_ref','prior_panel_ref','request_mode','scope_delta','manual_source_input_set_ref','requested_at','request_status')
  foreach($e in(Test-R7RequiredProperties $Request $required 'hotspot_request')){$errors.Add($e)};foreach($e in(Test-R7AllowedProperties $Request $required 'hotspot_request')){$errors.Add($e)};if($errors.Count){return [object[]]$errors.ToArray()}
  if($Request.schema_id-ne'taoge://schemas/r7/hotspot-research-request/v0.1'-or[string]$Request.schema_version-ne'0.1.0'){$errors.Add('hotspot_request_version_invalid')}
  if([int]$Request.research_request_revision-lt1-or$Request.request_status-ne'ready'){$errors.Add('hotspot_request_state_invalid')}
  foreach($name in @('account_identity_ref','account_snapshot_ref','radar_policy_ref')){foreach($e in(Test-R7HotspotArtifactRef $Request.$name "hotspot_request_$name")){$errors.Add($e)}}
  $mode=[string]$Request.request_mode;$decision=$null-ne$Request.triggering_decision_ref;$freshness=$null-ne$Request.triggering_freshness_review_ref;$scope=$null-ne$Request.scope_delta;$manual=$null-ne$Request.manual_source_input_set_ref;$priorSet=$null-ne$Request.prior_research_set_ref;$priorPanel=$null-ne$Request.prior_panel_ref;$supersedes=$null-ne$Request.supersedes_request_ref
  switch($mode){
    'initial'{if($decision-or$freshness-or$scope-or$manual-or$priorSet-or$priorPanel-or$supersedes){$errors.Add('hotspot_request_initial_condition_mismatch')}}
    'same_policy_rerun'{if(-not($decision-and$priorSet-and$priorPanel-and$supersedes)-or$freshness-or$scope-or$manual){$errors.Add('hotspot_request_rerun_condition_mismatch')}}
    'broaden_within_account_policy'{if(-not($decision-and$priorSet-and$priorPanel-and$supersedes-and$scope)-or$freshness-or$manual){$errors.Add('hotspot_request_broaden_condition_mismatch')};if($scope-and@(Get-R7PropertyNames $Request.scope_delta).Count-eq0){$errors.Add('hotspot_request_scope_delta_empty')}}
    'manual_source_refresh'{if(-not($decision-and$priorSet-and$priorPanel-and$supersedes-and$manual)-or$freshness-or$scope){$errors.Add('hotspot_request_manual_condition_mismatch')}}
    'revalidation_after_reversal'{if(-not($freshness-and$priorSet-and$priorPanel-and$supersedes)-or$decision-or$scope-or$manual){$errors.Add('hotspot_request_reversal_condition_mismatch')}}
    default{$errors.Add('hotspot_request_mode_invalid')}
  }
  return [object[]]$errors.ToArray()
}

function Get-R7HotspotComponent {
  param([object]$Set,[string]$Type,[string]$Id)
  $collection=switch($Type){'event'{'events'}'candidate'{'candidates'}'topic_option'{'topic_options'}'topic_evidence_packet'{'topic_evidence_packets'}'source_record'{'source_records'}default{''}}
  if([string]::IsNullOrWhiteSpace($collection)){return $null}
  return @($Set.$collection|Where-Object{(Get-R7RuntimeField $_ @("${Type}_id",'topic_id','evidence_packet_id','source_record_id','event_id','candidate_id'))-eq$Id})|Select-Object -First 1
}

function Test-R7HotspotEvidencePacket {
  param([object]$Packet)
  $errors=[Collections.Generic.List[string]]::new();$fact=[string]$Packet.event_fact_status;$risk=[string]$Packet.risk_level
  foreach($claim in @($Packet.claims)){
    $type=[string]$claim.claim_type;$status=[string]$claim.claim_evidence_status;$basis=[string]$claim.source_support_basis;$independence=[string]$claim.source_independence_status;$expression=[string]$claim.allowed_expression
    if($expression-eq'assert_as_fact'){
      if($type-notin@('factual_claim','statistic')-or$fact-ne'verified'-or$status-ne'supported'-or$risk-notin@('low','medium')-or$basis-notin@('authoritative_primary','two_independent_eligible_secondary')){$errors.Add("evidence_assert_as_fact_forbidden:$($claim.claim_id)")}
      if($basis-eq'two_independent_eligible_secondary'-and$independence-ne'independent_sources'){$errors.Add("evidence_independence_invalid:$($claim.claim_id)")}
    }
    if($type-eq'quote'-and$expression-ne'attribute_to_source'){$errors.Add("evidence_quote_expression_invalid:$($claim.claim_id)")}
    if($type-eq'prediction'-and$expression-notin@('state_uncertainty','attribute_to_source')){$errors.Add("evidence_prediction_expression_invalid:$($claim.claim_id)")}
    if($basis-in@('single_eligible_secondary','same_origin_republication')-and$expression-eq'assert_as_fact'){$errors.Add("evidence_secondary_assertion_forbidden:$($claim.claim_id)")}
  }
  return [object[]]$errors.ToArray()
}

function Test-R7HotspotResearchSet {
  param([object]$Set)
  $errors=[Collections.Generic.List[string]]::new();$required=@('schema_id','schema_version','research_set_id','research_set_revision','account_identity_ref','account_snapshot_ref','radar_policy_ref','research_request_ref','research_run_record','signals','events','candidates','topic_options','topic_evidence_packets','panel_model','source_records','ledger_write_refs','component_digest_map','researched_at','research_set_status')
  foreach($e in(Test-R7RequiredProperties $Set $required 'hotspot_set')){$errors.Add($e)};foreach($e in(Test-R7AllowedProperties $Set $required 'hotspot_set')){$errors.Add($e)};if($errors.Count){return [object[]]$errors.ToArray()}
  if($Set.schema_id-ne'taoge://schemas/r7/hotspot-research-set/v0.1'-or[string]$Set.schema_version-ne'0.1.0'){$errors.Add('hotspot_set_version_invalid')}
  $count=@($Set.topic_options).Count;if($Set.research_set_status-eq'ready_for_panel'-and$count-lt1){$errors.Add('hotspot_set_ready_without_topic')};if($Set.research_set_status-eq'ready_no_recommendation'-and$count-ne0){$errors.Add('hotspot_set_no_recommendation_has_topic')}
  $topicIds=@($Set.topic_options|ForEach-Object{Get-R7RuntimeField $_ @('topic_option_id','topic_id')})
  foreach($ref in @($Set.panel_model.ordered_topic_option_refs)){foreach($e in(Test-R7HotspotLocalComponentRef $ref 'hotspot_set_panel_ref' $Set.component_digest_map @('topic_option'))){$errors.Add($e)};if([string]$ref.component_id-notin$topicIds){$errors.Add("hotspot_set_panel_topic_missing:$($ref.component_id)")}}
  if(@($Set.panel_model.ordered_topic_option_refs).Count-ne$count){$errors.Add('hotspot_set_panel_cardinality_mismatch')}
  if($null-ne$Set.panel_model.recommended_topic_ref-and[string]$Set.panel_model.recommended_topic_ref.component_id-notin@($Set.panel_model.ordered_topic_option_refs|ForEach-Object{[string]$_.component_id})){$errors.Add('hotspot_set_recommendation_not_ordered')}
  if([string]::IsNullOrWhiteSpace([string]$Set.panel_model.recommendation_reason)){$errors.Add('hotspot_set_recommendation_reason_missing')}
  foreach($packet in @($Set.topic_evidence_packets)){foreach($e in(Test-R7HotspotEvidencePacket $packet)){$errors.Add($e)}}
  return [object[]]$errors.ToArray()
}

function Test-R7HotspotResearchSetBinding {
  param([object]$Set,[object]$Request,[object]$RequestRef)
  $errors=[Collections.Generic.List[string]]::new();foreach($name in @('artifact_id','revision','sha256')){if([string]$Set.research_request_ref.$name-ne[string]$RequestRef.$name){$errors.Add("hotspot_research_request_binding_mismatch:$name")}}
  foreach($refName in @('account_identity_ref','account_snapshot_ref','radar_policy_ref')){foreach($name in @('artifact_id','revision','sha256')){if([string]$Set.$refName.$name-ne[string]$Request.$refName.$name){$errors.Add("account_identity_inconsistent:${refName}:$name")}}};return [object[]]$errors.ToArray()
}

function Test-R7HotspotPanel {
  param([object]$Panel,[object]$Set,[object]$SetRef)
  $errors=[Collections.Generic.List[string]]::new();$required=@('schema_id','schema_version','panel_id','panel_revision','research_set_ref','ordered_topic_option_refs','recommended_topic_ref','recommendation_reason','panel_status','projected_at')
  foreach($e in(Test-R7RequiredProperties $Panel $required 'topic_panel')){$errors.Add($e)};foreach($e in(Test-R7AllowedProperties $Panel $required 'topic_panel')){$errors.Add($e)};if($errors.Count){return [object[]]$errors.ToArray()}
  if($Panel.schema_id-ne'taoge://schemas/r7/topic-selection-panel/v0.2'-or[string]$Panel.schema_version-ne'0.2.0'){$errors.Add('topic_panel_version_invalid')}
  foreach($name in @('artifact_id','revision','sha256')){if([string]$Panel.research_set_ref.$name-ne[string]$SetRef.$name){$errors.Add("topic_panel_set_ref_mismatch:$name")}}
  $expected=@($Set.panel_model.ordered_topic_option_refs);$actual=@($Panel.ordered_topic_option_refs|ForEach-Object{[ordered]@{component_type=$_.component_type;component_id=$_.component_id;component_sha256=$_.component_sha256}});if((Get-R7HotspotCanonicalDigest $expected)-ne(Get-R7HotspotCanonicalDigest $actual)){$errors.Add('topic_panel_ranking_changed')}
  $actualRecommended=if($null-eq$Panel.recommended_topic_ref){$null}else{[ordered]@{component_type=$Panel.recommended_topic_ref.component_type;component_id=$Panel.recommended_topic_ref.component_id;component_sha256=$Panel.recommended_topic_ref.component_sha256}};if((Get-R7HotspotCanonicalDigest $Set.panel_model.recommended_topic_ref)-ne(Get-R7HotspotCanonicalDigest $actualRecommended)){$errors.Add('topic_panel_recommendation_changed')}
  if([string]$Panel.recommendation_reason-ne[string]$Set.panel_model.recommendation_reason){$errors.Add('topic_panel_reason_changed')}
  if($Set.research_set_status-eq'ready_no_recommendation'){$valid=$Panel.panel_status-eq'panel_no_recommendation'-and$actual.Count-eq0-and$null-eq$Panel.recommended_topic_ref;if(-not$valid){$errors.Add('topic_panel_no_recommendation_invalid')}}else{if($Panel.panel_status-ne'panel_ready_waiting_human'-or$actual.Count-lt1){$errors.Add('topic_panel_ready_invalid')}}
  return [object[]]$errors.ToArray()
}

function Test-R7HotspotDecision {
  param([object]$Decision,[object]$Panel,[object]$Set)
  $errors=[Collections.Generic.List[string]]::new();$required=@('schema_id','schema_version','decision_id','decision_revision','panel_ref','research_set_ref','decision_code','action_code','selected_topic_refs','scope_delta','manual_source_input_set_ref','decided_at','decision_status','human_instruction_summary')
  foreach($e in(Test-R7RequiredProperties $Decision $required 'topic_decision')){$errors.Add($e)};foreach($e in(Test-R7AllowedProperties $Decision $required 'topic_decision')){$errors.Add($e)};if($errors.Count){return [object[]]$errors.ToArray()}
  $map=@{select_one='select_topic';rerun_same_policy='rerun_hotspot_research';broaden_within_account_policy='broaden_hotspot_scope';add_manual_source='attach_manual_hotspot_source';select_multiple='branch_selected_topics';stop='archive_session'};$code=[string]$Decision.decision_code
  if($Decision.schema_id-ne'taoge://schemas/r7/topic-selection-decision/v0.1'-or[string]$Decision.schema_version-ne'0.1.0'-or$Decision.decision_status-ne'committed'){$errors.Add('topic_decision_version_or_state_invalid')}
  if(-not$map.ContainsKey($code)-or[string]$Decision.action_code-ne$map[$code]){$errors.Add('topic_decision_action_mismatch')}
  $selected=@($Decision.selected_topic_refs);$scope=$null-ne$Decision.scope_delta;$manual=$null-ne$Decision.manual_source_input_set_ref
  switch($code){'select_one'{if($selected.Count-ne1-or$scope-or$manual){$errors.Add('topic_decision_select_one_condition_mismatch')}}'select_multiple'{if($selected.Count-lt2-or$scope-or$manual){$errors.Add('topic_decision_select_multiple_condition_mismatch')}}'broaden_within_account_policy'{if($selected.Count-ne0-or-not$scope-or$manual-or@(Get-R7PropertyNames $Decision.scope_delta).Count-eq0){$errors.Add('topic_decision_broaden_condition_mismatch')}}'add_manual_source'{if($selected.Count-ne0-or$scope-or-not$manual){$errors.Add('topic_decision_manual_condition_mismatch')}}default{if($selected.Count-ne0-or$scope-or$manual){$errors.Add('topic_decision_empty_action_condition_mismatch')}}}
  if($Panel.panel_status-eq'panel_no_recommendation'-and$code-in@('select_one','select_multiple')){$errors.Add('topic_decision_selection_forbidden_without_recommendation')}
  $allowedIds=@($Panel.ordered_topic_option_refs|ForEach-Object{[string]$_.component_id});foreach($ref in $selected){foreach($e in (Test-R7HotspotComponentRef $ref 'topic_decision_selected' $Panel.research_set_ref $Set.component_digest_map @('topic_option'))){$errors.Add($e)};if([string]$ref.component_id-notin$allowedIds){$errors.Add("topic_decision_topic_not_in_panel:$($ref.component_id)")}}
  return [object[]]$errors.ToArray()
}

function Test-R7HotspotFreshnessPolicy {
  param([object]$Policy)
  $errors=[Collections.Generic.List[string]]::new();$mode=[string]$Policy.policy_mode;$hours=$Policy.max_age_hours;$basis=[string]$Policy.threshold_basis;$refs=@($Policy.policy_basis_refs);$triggers=@($Policy.event_triggers);$fallback=[string]$Policy.fallback_reason
  switch($mode){'duration_bound'{if($null-eq$hours-or[double]$hours-le0-or[string]::IsNullOrWhiteSpace($basis)-or$refs.Count-lt1-or$triggers.Count-ne0-or-not[string]::IsNullOrWhiteSpace($fallback)){$errors.Add('freshness_policy_duration_invalid')}}'event_triggered'{if($null-ne$hours-or-not[string]::IsNullOrWhiteSpace($basis)-or$refs.Count-lt1-or$triggers.Count-lt1-or-not[string]::IsNullOrWhiteSpace($fallback)){$errors.Add('freshness_policy_trigger_invalid')}}'always_revalidate_before_delivery'{if($null-ne$hours-or-not[string]::IsNullOrWhiteSpace($basis)-or$refs.Count-ne0-or$triggers.Count-ne0-or$fallback-ne'no_trusted_duration_or_trigger_policy'){$errors.Add('freshness_policy_fallback_invalid')}}default{$errors.Add('freshness_policy_mode_invalid')}}
  return [object[]]$errors.ToArray()
}

function Test-R7SelectedTopicSource {
  param([object]$Source,[object]$Set,[object]$Panel,[object]$Decision)
  $errors=[Collections.Generic.List[string]]::new();$required=@('schema_id','schema_version','selected_topic_source_id','selected_topic_source_revision','content_origin','account_snapshot_ref','radar_policy_ref','research_set_ref','selection_panel_ref','selection_decision_ref','event_ref','candidate_ref','topic_option_ref','topic_evidence_packet_ref','monitoring_source_record_refs','latest_freshness_review_ref','freshness_policy','selection_freshness_status','digest_basis_version','content_semantic_digest','monitoring_digest','selected_source_status','selected_at')
  foreach($e in(Test-R7RequiredProperties $Source $required 'selected_source')){$errors.Add($e)};foreach($e in(Test-R7AllowedProperties $Source $required 'selected_source')){$errors.Add($e)};if($errors.Count){return [object[]]$errors.ToArray()}
  if($Source.schema_id-ne'taoge://schemas/r7/selected-topic-source/v0.1'-or[string]$Source.schema_version-ne'0.1.0'-or$Source.content_origin-ne'hotspot_selected_topic'){$errors.Add('selected_source_version_or_origin_invalid')}
  if([int]$Source.selected_topic_source_revision-ne1-or$null-ne$Source.latest_freshness_review_ref-or$Source.selected_source_status-ne'ready_for_brief'-or$Source.selection_freshness_status-ne'current'){$errors.Add('selected_source_initial_state_invalid')}
  if($Decision.decision_code-ne'select_one'-or@($Decision.selected_topic_refs).Count-ne1){$errors.Add('selected_source_decision_invalid')}
  foreach($pair in @(@($Source.research_set_ref,$Panel.research_set_ref,'research'),@($Source.topic_option_ref,$Decision.selected_topic_refs[0],'topic'))){foreach($name in @('artifact_id','revision','sha256','component_id','component_sha256')){if((Test-R7HasProperty $pair[0] $name)-and[string]$pair[0].$name-ne[string]$pair[1].$name){$errors.Add("selected_source_$($pair[2])_mismatch:$name")}}}
  foreach($refName in @('event_ref','candidate_ref','topic_option_ref','topic_evidence_packet_ref')){foreach($e in(Test-R7HotspotComponentRef $Source.$refName "selected_source_$refName" $Source.research_set_ref $Set.component_digest_map @())){$errors.Add($e)}}
  foreach($ref in @($Source.monitoring_source_record_refs)){foreach($e in (Test-R7HotspotComponentRef $ref 'selected_source_monitoring' $Source.research_set_ref $Set.component_digest_map @('source_record'))){$errors.Add($e)}}
  foreach($e in(Test-R7HotspotFreshnessPolicy $Source.freshness_policy)){$errors.Add($e)}
  if(-not(Test-R7HotspotDigest $Source.content_semantic_digest)-or-not(Test-R7HotspotDigest $Source.monitoring_digest)){$errors.Add('selected_source_digest_invalid')}
  return [object[]]$errors.ToArray()
}

function Test-R7HotspotBriefV04 {
  param([object]$Brief,[object]$SourceRef,[object]$Source)
  $errors=[Collections.Generic.List[string]]::new();if($Brief.schema_id-ne'taoge://schemas/r6/content-brief/v0.4'-or[string]$Brief.schema_version-ne'0.4.0'){$errors.Add('hotspot_brief_version_invalid')};if($Brief.content_origin-ne'hotspot_selected_topic'-or$Brief.next_skill-ne'short-video-structure-planner'-or$Brief.revision_policy-ne'generated_content'){$errors.Add('hotspot_brief_route_invalid')};if($null-ne$Brief.original_draft_ref){$errors.Add('hotspot_brief_original_draft_forbidden')};if([string]$Brief.content_source_id-ne[string]$Source.selected_topic_source_id){$errors.Add('hotspot_brief_source_id_mismatch')};if([string]$Brief.selected_topic_content_semantic_digest-ne[string]$Source.content_semantic_digest){$errors.Add('hotspot_brief_semantic_digest_mismatch')};if($Source.selected_source_status-ne'ready_for_brief'){$errors.Add('hotspot_brief_source_status_invalid')};foreach($name in @('artifact_id','revision','sha256')){if([string]$Brief.selected_topic_source_ref.$name-ne[string]$SourceRef.$name){$errors.Add("hotspot_brief_source_ref_mismatch:$name")}};return [object[]]$errors.ToArray()
}

function Test-R7HotspotStructurePlan {
  param([object]$Plan,[object]$BriefBinding,[object]$SourceBinding)
  $errors=[Collections.Generic.List[string]]::new();if($Plan.content_origin-ne'hotspot_selected_topic'-or$Plan.plan_mode-ne'design_before_draft'){$errors.Add('hotspot_structure_phase_invalid')};if($null-ne$Plan.source_draft_ref){$errors.Add('future_artifact_reference:source_draft_ref')};if($null-ne$Plan.source_beat_map_ref){$errors.Add('future_artifact_reference:source_beat_map_ref')};if([string]$Plan.brief_id-ne[string]$BriefBinding.artifact_id){$errors.Add('hotspot_structure_brief_id_mismatch')};if([string]$Plan.content_source_id-ne[string]$SourceBinding.artifact_id){$errors.Add('hotspot_structure_source_id_mismatch')};return [object[]]$errors.ToArray()
}

function Test-R7HotspotDraftV04 {
  param([object]$Draft,[object]$BriefBinding,[object]$StructureBinding)
  $errors=[Collections.Generic.List[string]]::new();if($Draft.schema_id-ne'taoge://schemas/r6/draft/v0.4'-or[string]$Draft.schema_version-ne'0.4.0'){$errors.Add('hotspot_draft_version_invalid')};if($Draft.content_origin-ne'hotspot_selected_topic'-or$Draft.draft_mode-ne'generate_from_structure'-or$Draft.next_skill-ne'content-beat-mapper'){$errors.Add('hotspot_draft_route_invalid')};if($null-ne$Draft.original_draft_ref-or$null-ne$Draft.original_normalized_body_digest){$errors.Add('hotspot_draft_original_forbidden')}
  if($null-eq$Draft.brief_ref){$errors.Add('hotspot_draft_brief_missing')}else{foreach($name in @('artifact_id','revision','sha256')){if([string]$Draft.brief_ref.$name-ne[string]$BriefBinding.$name){$errors.Add("hotspot_draft_brief_mismatch:$name")}}}
  if($null-eq$Draft.structure_plan_ref){$errors.Add('hotspot_draft_structure_missing')}else{foreach($name in @('artifact_id','revision','sha256')){if([string]$Draft.structure_plan_ref.$name-ne[string]$StructureBinding.$name){$errors.Add("hotspot_draft_structure_mismatch:$name")}}};return [object[]]$errors.ToArray()
}
