Set-StrictMode -Version 2.0

function Test-R8HumanReply {
  param([object]$Document,[string]$ExpectedSessionId,[string]$ExpectedGateNodeId)
  $errors=[Collections.Generic.List[string]]::new()
  $required=@('schema_id','schema_version','reply_id','session_id','gate_node_id','reply_text','reply_digest','recorded_at')
  foreach($name in $required){if(-not(Test-R7HasProperty $Document $name)){$errors.Add("human_reply_required_field_missing:$name")}}
  foreach($name in @(Get-R7PropertyNames $Document)){if($name-notin$required){$errors.Add("human_reply_unknown_field:$name")}}
  if($errors.Count){return [object[]]$errors.ToArray()}
  if([string]$Document.schema_id-ne'taoge://schemas/r7/human-reply/v0.1'-or[string]$Document.schema_version-ne'0.1'){$errors.Add('human_reply_version_invalid')}
  if([string]$Document.session_id-ne$ExpectedSessionId){$errors.Add('human_reply_session_mismatch')}
  if([string]$Document.gate_node_id-ne$ExpectedGateNodeId){$errors.Add('human_reply_gate_mismatch')}
  if([string]::IsNullOrWhiteSpace([string]$Document.reply_text)){$errors.Add('human_reply_text_empty')}
  elseif(([string]$Document.reply_digest) -ne (Get-R7RuntimeTextDigest ([string]$Document.reply_text))){$errors.Add('human_reply_digest_mismatch')}
  return [object[]]$errors.ToArray()
}

function Test-R8FinalDeliveryHumanDecision {
  param([object]$Document)
  $errors=[Collections.Generic.List[string]]::new()
  $required=@('schema_id','schema_version','decision_id','decision_revision','session_id','delivery_ref','viewport_acceptance_ref','delivery_visual_review_ref','business_delivery_acceptance_ref','action_code','user_reply_digest','requested_at','delivery_revision_request_ref','export_mode','decision_status')
  foreach($name in $required){if(-not(Test-R7HasProperty $Document $name)){$errors.Add("final_decision_required_field_missing:$name")}}
  foreach($name in @(Get-R7PropertyNames $Document)){if($name-notin$required){$errors.Add("final_decision_unknown_field:$name")}}
  if($errors.Count){return [object[]]$errors.ToArray()}
  if([string]$Document.schema_id-ne'taoge://schemas/r7/final-delivery-human-decision/v0.1'-or[string]$Document.schema_version-ne'0.1'){$errors.Add('final_decision_version_invalid')}
  if([string]$Document.decision_status-ne'decision_recorded'){$errors.Add('final_decision_status_invalid')}
  if([string]$Document.user_reply_digest-notmatch'^sha256:[0-9a-f]{64}$'){$errors.Add('final_decision_reply_digest_invalid')}
  $action=[string]$Document.action_code
  if($action-notin@('adopt_delivery','request_revision','request_export','archive_session')){$errors.Add('final_decision_action_invalid')}
  if($action-eq'request_revision'){
    if($null-eq$Document.delivery_revision_request_ref){$errors.Add('final_decision_revision_ref_required')}
    if($null-ne$Document.export_mode){$errors.Add('final_decision_export_mode_forbidden')}
  }elseif($action-eq'request_export'){
    if([string]::IsNullOrWhiteSpace([string]$Document.export_mode)){$errors.Add('final_decision_export_mode_required')}
    if($null-ne$Document.delivery_revision_request_ref){$errors.Add('final_decision_revision_ref_forbidden')}
  }elseif($null-ne$Document.delivery_revision_request_ref-or$null-ne$Document.export_mode){$errors.Add('final_decision_conditional_fields_forbidden')}
  return [object[]]$errors.ToArray()
}

function Invoke-R8FinalDeliveryDecisionApply {
  param([string]$ProjectRoot,[string]$SessionRoot)
  try{
    $plan=Read-P0JsonFile (Join-Path $SessionRoot 'intermediate/p0/session-execution-plan.json')
    $projection=Read-P0JsonFile (Join-Path $SessionRoot 'intermediate/p0/state-projection.json')
    if([string]$projection.session_id-ne[string]$plan.session_id-or[string]$projection.plan_id-ne[string]$plan.plan_id){return New-R7RuntimeResult 'final_decision_state_binding_error' 1 $projection @('projection_plan_mismatch')}
    $currentStep=@($plan.steps|Where-Object{[string]$_.step_id-eq[string]$projection.next_step_id})|Select-Object -First 1
    if($null-eq$currentStep-or[string]$currentStep.node_id-ne'final_delivery_decision_apply'){return New-R7RuntimeResult 'final_decision_state_binding_error' 2 $projection @('apply_node_not_current')}
    $item=Get-R7CandidateCurrentArtifact $SessionRoot 'final_delivery_human_decision'
    $decision=$item.Payload
    $errors=@(Test-R8FinalDeliveryHumanDecision $decision)
    if($errors.Count){return New-R7RuntimeResult 'final_decision_contract_error' 1 $decision $errors}
    if([string]$decision.session_id-ne[string]$projection.session_id){return New-R7RuntimeResult 'final_decision_state_binding_error' 1 $decision @('decision_session_mismatch')}
    $map=@{
      adopt_delivery=@('delivery_adopted','done')
      request_revision=@('revision_requested','semantic-workflow-coordinator')
      request_export=@('export_requested','handoff-exporter')
      archive_session=@('archived','archive-session')
    }
    $selected=$map[[string]$decision.action_code]
    $record=[ordered]@{
      schema_id='taoge://schemas/r7/workflow-session-record/v0.4'
      schema_version='0.4'
      session_record_id="SESSION-RECORD-$($decision.session_id)-$($decision.decision_revision)"
      session_record_revision=[int]$decision.decision_revision
      session_id=[string]$decision.session_id
      decision_ref=[ordered]@{artifact_id=[string]$item.Pointer.artifact_id;revision=[int]$item.Pointer.revision;sha256=[string]$item.Pointer.sha256}
      applied_action=[string]$decision.action_code
      session_status=[string]$selected[0]
      next_skill=[string]$selected[1]
      applied_at=[DateTimeOffset]::UtcNow.ToString('o')
    }
    return Commit-R7DeterministicArtifact $ProjectRoot $SessionRoot 'final_delivery_decision_apply' 'workflow_session_record' ([string]$record.session_record_id) ([pscustomobject]$record) 'session_record_updated' @([string]$decision.decision_id,[string]$projection.plan_id) @('R8-C19','R8-C26','R8-C28')
  }catch{return New-R7RuntimeResult 'final_decision_apply_error' 1 $null @($_.Exception.Message)}
}
