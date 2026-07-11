param(
  [Parameter(Mandatory=$true)][string]$Session,
  [Parameter(Mandatory=$true)]
  [ValidateSet('create_session_plan','record_agent_result','record_human_choice','record_external_result','build_resume_summary','rebuild_projection','reconcile_orphan_artifact')]
  [string]$Mode,
  [string]$CommandInputPath = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'P0EvidenceRuntime.ps1')

function Resolve-P0CommandPath {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
  return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

function Write-P0CommandResult {
  param([string]$ResultCode, [int]$ExitCode, [string[]]$Extra = @())
  Write-Output "P0_EVIDENCE_RESULT=$ResultCode"
  Write-Output "P0_EVIDENCE_MODE=$Mode"
  foreach ($line in @($Extra)) { Write-Output $line }
  exit $ExitCode
}

function Test-P0CommandFields {
  param([object]$Document, [string[]]$Required, [string[]]$Allowed, [string]$Context)
  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($error in (Test-P0RequiredProperties $Document $Required $Context)) { $errors.Add($error) }
  foreach ($error in (Test-P0AllowedProperties $Document $Allowed $Context)) { $errors.Add($error) }
  return [object[]]$errors.ToArray()
}

function Test-P0CommandEnvelope {
  param([object]$Document, [string]$ExpectedCommand, [string]$ExpectedSessionId)
  $errors = [System.Collections.Generic.List[string]]::new()
  if ($Document.schema_id -ne 'taoge://commands/p0/evidence-command/v0.2') { $errors.Add('command_schema_id_invalid') }
  if ($Document.schema_version -ne '0.2') { $errors.Add('command_schema_version_invalid') }
  if ($Document.command -ne $ExpectedCommand) { $errors.Add('command_mode_mismatch') }
  if ($Document.session_id -ne $ExpectedSessionId) { $errors.Add('command_session_mismatch') }
  return [object[]]$errors.ToArray()
}

function Get-P0CommandInput {
  if ([string]::IsNullOrWhiteSpace($CommandInputPath)) { throw 'command_input_required' }
  $path = Resolve-P0CommandPath $CommandInputPath
  if (-not (Test-Path -LiteralPath $path)) { throw "command_input_missing:$path" }
  return (Read-P0JsonFile $path)
}

function Get-P0SessionPlan {
  param([string]$SessionRoot)
  $path = Join-Path $SessionRoot 'intermediate/p0/session-execution-plan.json'
  if (-not (Test-Path -LiteralPath $path)) { throw 'session_plan_missing' }
  $plan = Read-P0JsonFile $path
  $errors = @(Test-P0PlanContract $plan)
  if ($errors.Count) { throw ('session_plan_invalid:' + [string]::Join(';', $errors)) }
  return $plan
}

function Get-P0SemanticDigest {
  param([object]$Document, [string[]]$Fields)
  $payload = [ordered]@{}
  foreach ($field in $Fields) {
    if (Test-P0HasProperty $Document $field) { $payload[$field] = $Document.$field }
  }
  return (Get-P0EvidenceObjectDigest $payload)
}

function New-P0RetryPolicy {
  param([string]$StepKind)
  if ($StepKind -eq 'external_side_effect') { return [ordered]@{ mode='reconcile_first'; automatic_retries=0; max_attempts=1; idempotency_scope='session_step_input_digest' } }
  if ($StepKind -eq 'deterministic_tool') { return [ordered]@{ mode='bounded'; automatic_retries=1; max_attempts=2; idempotency_scope='session_step_input_digest' } }
  return [ordered]@{ mode='never'; automatic_retries=0; max_attempts=1; idempotency_scope='session_step_input_digest' }
}

try {
  $sessionRoot = Resolve-P0CommandPath $Session
  if ($Mode -eq 'create_session_plan') {
    if (-not (Test-Path -LiteralPath $sessionRoot)) { New-Item -ItemType Directory -Path $sessionRoot -Force | Out-Null }
  } elseif (-not (Test-Path -LiteralPath $sessionRoot)) { Write-P0CommandResult 'session_missing' 2 @("SESSION=$sessionRoot") }
  $planPath = Join-Path $sessionRoot 'intermediate/p0/session-execution-plan.json'
  $eventPath = Join-Path $sessionRoot 'intermediate/p0/execution-events.jsonl'

  if ($Mode -eq 'create_session_plan') {
    $commandData = Get-P0CommandInput
    $required = @('schema_id','schema_version','command','plan_id','session_id','confirmed_single_content','steps','idempotency_key','expected_last_sequence_no','safe_summary')
    $allowed = $required
    $fieldErrors = @(Test-P0CommandFields $commandData $required $allowed 'create_session_plan')
    if ($fieldErrors.Count) { Write-P0CommandResult 'command_contract_failed' 1 @($fieldErrors | ForEach-Object { "ERROR=$_" }) }
    $envelopeErrors = @(Test-P0CommandEnvelope $commandData $Mode (Split-Path -Leaf $sessionRoot))
    if ($envelopeErrors.Count) { Write-P0CommandResult 'command_identity_invalid' 1 @($envelopeErrors | ForEach-Object { "ERROR=$_" }) }
    if (-not [bool]$commandData.confirmed_single_content) { Write-P0CommandResult 'confirmed_single_content_required' 2 }
    if ([string]$commandData.session_id -ne (Split-Path -Leaf $sessionRoot)) { Write-P0CommandResult 'session_id_path_mismatch' 1 }
    $steps = [System.Collections.Generic.List[object]]::new()
    $steps.Add([ordered]@{
      step_id='STEP-session-plan'; step_kind='deterministic_tool'; operation='create_session_plan';
      produces_artifact_type='session_execution_plan'; success_state='succeeded'; failure_route='propagation-router';
      retry_policy=[ordered]@{ mode='never'; automatic_retries=0; max_attempts=1; idempotency_scope='session_step_input_digest' }
    })
    foreach ($sourceStep in @($commandData.steps)) {
      $stepFields = @('step_id','step_kind','operation','requires_step_ids','requires_artifact_ids','produces_artifact_type','failure_route')
      $stepErrors = @(Test-P0CommandFields $sourceStep @('step_id','step_kind','produces_artifact_type','failure_route') $stepFields 'create_plan_step')
      if ($stepErrors.Count) { Write-P0CommandResult 'command_step_contract_failed' 1 @($stepErrors | ForEach-Object { "ERROR=$_" }) }
      $dependencies = if ((Test-P0HasProperty $sourceStep 'requires_step_ids') -and @($sourceStep.requires_step_ids).Count) { @($sourceStep.requires_step_ids) } else { @('STEP-session-plan') }
      $item = [ordered]@{
        step_id=[string]$sourceStep.step_id
        step_kind=[string]$sourceStep.step_kind
        requires_step_ids=[object[]]$dependencies
        produces_artifact_type=[string]$sourceStep.produces_artifact_type
        success_state='succeeded'
        failure_route=[string]$sourceStep.failure_route
        retry_policy=New-P0RetryPolicy ([string]$sourceStep.step_kind)
      }
      if (Test-P0HasProperty $sourceStep 'operation') { $item.operation=[string]$sourceStep.operation }
      if (Test-P0HasProperty $sourceStep 'requires_artifact_ids') { $item.requires_artifact_ids=[object[]]@($sourceStep.requires_artifact_ids) }
      $steps.Add($item)
    }
    $plan = [ordered]@{
      plan_id=[string]$commandData.plan_id
      session_id=[string]$commandData.session_id
      workflow_definition_version='p0-single-runtime-v0.2'
      contract_bundle_version='p0-contract-bundle-v0.2'
      plan_schema_id='taoge://schemas/p0/session-execution-plan/v0.2'
      event_schema_id='taoge://schemas/p0/execution-event/v0.2'
      artifact_lineage_schema_id='taoge://schemas/p0/artifact-lineage/v0.2'
      render_input_schema_id='taoge://schemas/final-delivery/typed-components/v0.2'
      renderer_version='final-delivery-renderer-v0.2'
      template_version='final-delivery-template-v0.2'
      runtime_mode='single'
      topic_count=1
      final_delivery_count=1
      steps=[object[]]$steps.ToArray()
    }
    $planObject = [pscustomobject](($plan | ConvertTo-Json -Depth 30) | ConvertFrom-Json)
    $planErrors = @(Test-P0PlanContract $planObject)
    if ($planErrors.Count) { Write-P0CommandResult 'plan_contract_failed' 1 @($planErrors | ForEach-Object { "ERROR=$_" }) }
    $planText = ConvertTo-P0EvidenceJsonText $plan
    $planDigest = Get-P0EvidenceTextDigest $planText.TrimEnd("`r", "`n")
    if (Test-Path -LiteralPath $planPath) {
      $existingDigest = Get-P0EvidenceTextDigest ((Get-Content -LiteralPath $planPath -Raw -Encoding UTF8).TrimEnd("`r", "`n"))
      if ($existingDigest -ne $planDigest) { Write-P0CommandResult 'session_plan_conflict' 1 }
    } else { Write-P0EvidenceAtomicText $planPath $planText }
    $write = Write-P0EvidenceEvent -EventPath $eventPath -Plan $planObject -StepId 'STEP-session-plan' -EventType 'plan.created.v1' -EventSource 'runner' -StateBefore 'ready' -StateAfter 'succeeded' -PayloadDigest $planDigest -IdempotencyKey ([string]$commandData.idempotency_key) -ExpectedLastSequenceNo ([int]$commandData.expected_last_sequence_no) -ResultCode 'session_plan_created' -SafeSummary ([string]$commandData.safe_summary) -OutputArtifactIds @([string]$commandData.plan_id) -InputDigest $planDigest -ExecutionAttemptId "ATT-$($commandData.session_id)-plan-1"
    $commandResult = if ($write.ResultCode -eq 'appended') { 'session_plan_created' } else { $write.ResultCode }
    Write-P0CommandResult $commandResult $write.ExitCode @("EVENT_WRITE_RESULT=$($write.ResultCode)","PLAN_PATH=intermediate/p0/session-execution-plan.json","EVENT_LAST_SEQUENCE=$($write.LastSequenceNo)")
  }

  $plan = Get-P0SessionPlan $sessionRoot
  if ([string]$plan.session_id -ne (Split-Path -Leaf $sessionRoot)) { Write-P0CommandResult 'session_plan_path_mismatch' 1 }

  if ($Mode -eq 'record_agent_result') {
    $commandData = Get-P0CommandInput
    $required = @('schema_id','schema_version','command','session_id','step_id','artifact_id','artifact_type','relative_path','input_artifact_ids','quality_status','delivery_eligibility','check_ids','idempotency_key','expected_last_sequence_no','safe_summary')
    $allowed = $required + @('supersedes_event_id')
    $fieldErrors = @(Test-P0CommandFields $commandData $required $allowed 'record_agent_result')
    if ($fieldErrors.Count) { Write-P0CommandResult 'command_contract_failed' 1 @($fieldErrors | ForEach-Object { "ERROR=$_" }) }
    $envelopeErrors = @(Test-P0CommandEnvelope $commandData $Mode ([string]$plan.session_id))
    if ($envelopeErrors.Count) { Write-P0CommandResult 'command_identity_invalid' 1 @($envelopeErrors | ForEach-Object { "ERROR=$_" }) }
    $step = Get-P0EvidenceStep $plan ([string]$commandData.step_id)
    if ($null -eq $step -or $step.step_kind -ne 'agent_required') { Write-P0CommandResult 'agent_step_required' 1 }
    $artifactPath = Resolve-P0EvidenceSessionPath $sessionRoot ([string]$commandData.relative_path)
    if (-not (Test-Path -LiteralPath $artifactPath)) { Write-P0CommandResult 'artifact_missing' 1 }
    $artifactDigest = Get-P0EvidenceHash $artifactPath
    $payloadDigest = Get-P0SemanticDigest $commandData @('session_id','step_id','artifact_id','artifact_type','relative_path','input_artifact_ids','quality_status','delivery_eligibility','check_ids','safe_summary','supersedes_event_id')
    $materialized = Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId ([string]$commandData.step_id) -EventType 'artifact.materialized.v1' -EventSource 'agent_recorder' -StateBefore 'running' -StateAfter 'running' -PayloadDigest $payloadDigest -IdempotencyKey (([string]$commandData.idempotency_key) + ':materialized') -ExpectedLastSequenceNo ([int]$commandData.expected_last_sequence_no) -ResultCode 'artifact_materialized' -SafeSummary 'Agent 产物文件与 digest 已登记' -OutputArtifactIds @([string]$commandData.artifact_id) -InputDigest $artifactDigest -ExecutionAttemptId "ATT-$($plan.session_id)-$($commandData.step_id)-1"
    if ($materialized.ExitCode -ne 0) { Write-P0CommandResult $materialized.ResultCode $materialized.ExitCode @("EVENT_LAST_SEQUENCE=$($materialized.LastSequenceNo)") }
    $causation = if (Test-P0HasProperty $commandData 'supersedes_event_id') { [string]$commandData.supersedes_event_id } else { [string]$materialized.Event.event_id }
    $recorded = Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId ([string]$commandData.step_id) -EventType $(if (Test-P0HasProperty $commandData 'supersedes_event_id') { 'agent.result_superseded.v1' } else { 'agent.result_recorded.v1' }) -EventSource 'agent_recorder' -StateBefore 'running' -StateAfter 'succeeded' -PayloadDigest $payloadDigest -IdempotencyKey (([string]$commandData.idempotency_key) + ':result') -ExpectedLastSequenceNo $materialized.LastSequenceNo -ResultCode 'agent_result_recorded' -SafeSummary ([string]$commandData.safe_summary) -OutputArtifactIds @([string]$commandData.artifact_id) -InputDigest $artifactDigest -ExecutionAttemptId "ATT-$($plan.session_id)-$($commandData.step_id)-1" -CausationEventId $causation
    if ($recorded.ExitCode -ne 0) { Write-P0CommandResult $recorded.ResultCode $recorded.ExitCode @("EVENT_LAST_SEQUENCE=$($recorded.LastSequenceNo)") }
    $lineagePath = Write-P0EvidenceLineage $sessionRoot ([string]$commandData.artifact_id) ([string]$commandData.artifact_type) ([string]$recorded.Event.event_id) @($commandData.input_artifact_ids) ([string]$commandData.relative_path) $artifactDigest ([string]$commandData.quality_status) ([string]$commandData.delivery_eligibility) @($commandData.check_ids)
    $resultCode = if ($materialized.ResultCode -eq 'duplicate_reused' -and $recorded.ResultCode -eq 'duplicate_reused') { 'duplicate_reused' } else { 'agent_result_recorded' }
    Write-P0CommandResult $resultCode 0 @("EVENT_LAST_SEQUENCE=$($recorded.LastSequenceNo)","ARTIFACT_SHA256=$artifactDigest","LINEAGE_PATH=$($lineagePath.Substring($sessionRoot.Length + 1).Replace('\','/'))")
  }

  if ($Mode -eq 'record_human_choice') {
    $commandData = Get-P0CommandInput
    $required = @('schema_id','schema_version','command','session_id','step_id','decision_id','decision_code','selected_artifact_ids','idempotency_key','expected_last_sequence_no','safe_summary')
    $allowed = $required + @('supersedes_event_id')
    $fieldErrors = @(Test-P0CommandFields $commandData $required $allowed 'record_human_choice')
    if ($fieldErrors.Count) { Write-P0CommandResult 'command_contract_failed' 1 @($fieldErrors | ForEach-Object { "ERROR=$_" }) }
    $envelopeErrors = @(Test-P0CommandEnvelope $commandData $Mode ([string]$plan.session_id))
    if ($envelopeErrors.Count) { Write-P0CommandResult 'command_identity_invalid' 1 @($envelopeErrors | ForEach-Object { "ERROR=$_" }) }
    $step = Get-P0EvidenceStep $plan ([string]$commandData.step_id)
    if ($null -eq $step -or $step.step_kind -ne 'human_gate') { Write-P0CommandResult 'human_gate_step_required' 1 }
    if ($commandData.decision_code -notin @('topic_selected','final_delivery_approved','revision_requested','archived','cancel_requested')) { Write-P0CommandResult 'human_decision_code_invalid' 1 }
    $payloadDigest = Get-P0SemanticDigest $commandData @('session_id','step_id','decision_id','decision_code','selected_artifact_ids','safe_summary','supersedes_event_id')
    $isCancel = $commandData.decision_code -eq 'cancel_requested'
    $write = Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId ([string]$commandData.step_id) -EventType $(if (Test-P0HasProperty $commandData 'supersedes_event_id') { 'human.choice_superseded.v1' } else { 'human.choice_recorded.v1' }) -EventSource 'human_recorder' -StateBefore 'waiting_human' -StateAfter $(if ($isCancel) { 'cancel_requested' } else { 'succeeded' }) -PayloadDigest $payloadDigest -IdempotencyKey ([string]$commandData.idempotency_key) -ExpectedLastSequenceNo ([int]$commandData.expected_last_sequence_no) -ResultCode ([string]$commandData.decision_code) -SafeSummary ([string]$commandData.safe_summary) -OutputArtifactIds @($commandData.selected_artifact_ids) -CausationEventId $(if (Test-P0HasProperty $commandData 'supersedes_event_id') { [string]$commandData.supersedes_event_id } else { $null })
    $commandResult = if ($write.ResultCode -eq 'appended') { $(if ($isCancel) { 'human_cancel_recorded' } else { 'human_choice_recorded' }) } else { $write.ResultCode }
    Write-P0CommandResult $commandResult $write.ExitCode @("EVENT_WRITE_RESULT=$($write.ResultCode)","EVENT_LAST_SEQUENCE=$($write.LastSequenceNo)","DECISION_CODE=$($commandData.decision_code)")
  }

  if ($Mode -eq 'record_external_result') {
    $commandData = Get-P0CommandInput
    $required = @('schema_id','schema_version','command','session_id','step_id','authorization_status','invocation_status','idempotency_key','expected_last_sequence_no','safe_summary')
    $allowed = $required + @('request_id','artifact_id','artifact_type','relative_path','input_artifact_ids','quality_status','delivery_eligibility','check_ids','failure_category','cost_may_have_occurred','supersedes_event_id')
    $fieldErrors = @(Test-P0CommandFields $commandData $required $allowed 'record_external_result')
    if ($fieldErrors.Count) { Write-P0CommandResult 'command_contract_failed' 1 @($fieldErrors | ForEach-Object { "ERROR=$_" }) }
    $envelopeErrors = @(Test-P0CommandEnvelope $commandData $Mode ([string]$plan.session_id))
    if ($envelopeErrors.Count) { Write-P0CommandResult 'command_identity_invalid' 1 @($envelopeErrors | ForEach-Object { "ERROR=$_" }) }
    $step = Get-P0EvidenceStep $plan ([string]$commandData.step_id)
    if ($null -eq $step -or $step.step_kind -ne 'external_side_effect') { Write-P0CommandResult 'external_step_required' 1 }
    if ($commandData.invocation_status -notin @('not_invoked','succeeded','failed','outcome_unknown')) { Write-P0CommandResult 'external_invocation_status_invalid' 1 }
    if ($commandData.invocation_status -ne 'not_invoked' -and $commandData.authorization_status -ne 'authorized') { Write-P0CommandResult 'external_authorization_required' 2 }
    if ($commandData.invocation_status -in @('succeeded','failed','outcome_unknown') -and (-not (Test-P0HasProperty $commandData 'request_id') -or [string]::IsNullOrWhiteSpace([string]$commandData.request_id))) { Write-P0CommandResult 'external_request_id_required' 1 }
    $payloadDigest = Get-P0SemanticDigest $commandData @('session_id','step_id','authorization_status','invocation_status','request_id','artifact_id','artifact_type','relative_path','input_artifact_ids','quality_status','delivery_eligibility','check_ids','failure_category','cost_may_have_occurred','safe_summary','supersedes_event_id')
    $expectedSequence = [int]$commandData.expected_last_sequence_no
    $artifactDigest = $null
    $materialized = $null
    if ($commandData.invocation_status -eq 'succeeded') {
      foreach ($field in @('artifact_id','artifact_type','relative_path','input_artifact_ids','quality_status','delivery_eligibility','check_ids')) { if (-not (Test-P0HasProperty $commandData $field)) { Write-P0CommandResult "external_success_field_missing:$field" 1 } }
      $artifactPath = Resolve-P0EvidenceSessionPath $sessionRoot ([string]$commandData.relative_path)
      if (-not (Test-Path -LiteralPath $artifactPath)) { Write-P0CommandResult 'external_artifact_missing' 1 }
      $artifactDigest = Get-P0EvidenceHash $artifactPath
      $materialized = Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId ([string]$commandData.step_id) -EventType 'artifact.materialized.v1' -EventSource 'external_recorder' -StateBefore 'waiting_external' -StateAfter 'waiting_external' -PayloadDigest $payloadDigest -IdempotencyKey (([string]$commandData.idempotency_key) + ':materialized') -ExpectedLastSequenceNo $expectedSequence -ResultCode 'external_artifact_materialized' -SafeSummary '已授权外部产物文件与 digest 已登记' -OutputArtifactIds @([string]$commandData.artifact_id) -InputDigest $artifactDigest
      if ($materialized.ExitCode -ne 0) { Write-P0CommandResult $materialized.ResultCode $materialized.ExitCode @("EVENT_LAST_SEQUENCE=$($materialized.LastSequenceNo)") }
      $expectedSequence = $materialized.LastSequenceNo
    }
    $eventType = switch ([string]$commandData.invocation_status) { 'not_invoked' {'external.not_invoked.v1'} 'succeeded' {'external.result_recorded.v1'} 'failed' {'external.result_failed.v1'} 'outcome_unknown' {'external.outcome_unknown.v1'} }
    $stateAfter = switch ([string]$commandData.invocation_status) { 'not_invoked' {'not_invoked'} 'succeeded' {'succeeded'} 'failed' {'failed'} 'outcome_unknown' {'outcome_unknown'} }
    $failure = $null
    if ($stateAfter -in @('failed','outcome_unknown')) {
      $failure = [ordered]@{ failure_category=$(if (Test-P0HasProperty $commandData 'failure_category') { [string]$commandData.failure_category } else { 'external_provider' }); retryability=$(if ($stateAfter -eq 'outcome_unknown') { 'reconcile_first' } else { 'human_decision_required' }); attempt_no=1; max_attempts=1; next_retry_not_before=$null; recovery_action=$(if ($stateAfter -eq 'outcome_unknown') { 'reconcile_external_request' } else { 'ask_human_before_retry' }) }
    }
    $write = Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId ([string]$commandData.step_id) -EventType $eventType -EventSource 'external_recorder' -StateBefore 'waiting_external' -StateAfter $stateAfter -PayloadDigest $payloadDigest -IdempotencyKey (([string]$commandData.idempotency_key) + ':result') -ExpectedLastSequenceNo $expectedSequence -ResultCode ([string]$commandData.invocation_status) -SafeSummary ([string]$commandData.safe_summary) -OutputArtifactIds $(if (Test-P0HasProperty $commandData 'artifact_id') { @([string]$commandData.artifact_id) } else { @() }) -InputDigest $artifactDigest -Failure $failure -CausationEventId $(if ($null -ne $materialized) { [string]$materialized.Event.event_id } elseif (Test-P0HasProperty $commandData 'supersedes_event_id') { [string]$commandData.supersedes_event_id } else { $null })
    if ($write.ExitCode -ne 0) { Write-P0CommandResult $write.ResultCode $write.ExitCode (@("EVENT_LAST_SEQUENCE=$($write.LastSequenceNo)") + @($write.Errors | ForEach-Object { "ERROR=$_" })) }
    if ($commandData.invocation_status -eq 'succeeded') {
      [void](Write-P0EvidenceLineage $sessionRoot ([string]$commandData.artifact_id) ([string]$commandData.artifact_type) ([string]$write.Event.event_id) @($commandData.input_artifact_ids) ([string]$commandData.relative_path) $artifactDigest ([string]$commandData.quality_status) ([string]$commandData.delivery_eligibility) @($commandData.check_ids))
    }
    $resultCode = if ($write.ResultCode -eq 'duplicate_reused') { 'duplicate_reused' } else { "external_$($commandData.invocation_status)_recorded" }
    Write-P0CommandResult $resultCode 0 @("EVENT_LAST_SEQUENCE=$($write.LastSequenceNo)","EXTERNAL_NETWORK_INVOKED_BY_TOOL=false")
  }

  if ($Mode -eq 'reconcile_orphan_artifact') {
    $commandData = Get-P0CommandInput
    $required = @('schema_id','schema_version','command','session_id','step_id','artifact_id','artifact_type','relative_path','input_artifact_ids','expected_sha256','input_digest','tool_version','action','idempotency_key','expected_last_sequence_no','safe_summary')
    $allowed = $required
    $fieldErrors = @(Test-P0CommandFields $commandData $required $allowed 'reconcile_orphan_artifact')
    if ($fieldErrors.Count) { Write-P0CommandResult 'command_contract_failed' 1 @($fieldErrors | ForEach-Object { "ERROR=$_" }) }
    $envelopeErrors = @(Test-P0CommandEnvelope $commandData $Mode ([string]$plan.session_id))
    if ($envelopeErrors.Count) { Write-P0CommandResult 'command_identity_invalid' 1 @($envelopeErrors | ForEach-Object { "ERROR=$_" }) }
    if ($commandData.action -notin @('adopt','quarantine')) { Write-P0CommandResult 'reconciliation_action_invalid' 1 }
    $step = Get-P0EvidenceStep $plan ([string]$commandData.step_id)
    if ($null -eq $step -or $step.step_kind -notin @('deterministic_tool','external_side_effect')) { Write-P0CommandResult 'reconciliation_step_kind_invalid' 1 }
    $artifactPath = Resolve-P0EvidenceSessionPath $sessionRoot ([string]$commandData.relative_path)
    if (-not (Test-Path -LiteralPath $artifactPath)) { Write-P0CommandResult 'orphan_artifact_missing' 1 }
    $actualDigest = Get-P0EvidenceHash $artifactPath
    if ($actualDigest -ne [string]$commandData.expected_sha256) { Write-P0CommandResult 'orphan_artifact_digest_mismatch' 1 @("ACTUAL_SHA256=$actualDigest") }
    $payloadDigest = Get-P0SemanticDigest $commandData @('session_id','step_id','artifact_id','artifact_type','relative_path','input_artifact_ids','expected_sha256','input_digest','tool_version','action','safe_summary')
    $events = @(Get-P0EvidenceEvents $eventPath)
    $prior = @($events | Where-Object { $_.idempotency_key -eq [string]$commandData.idempotency_key }) | Select-Object -First 1
    if ($prior -and $prior.payload_digest -eq $payloadDigest) { Write-P0CommandResult 'duplicate_reused' 0 @("EVENT_LAST_SEQUENCE=$($events.Count)") }
    $hasEvidence = @($events | Where-Object { @($_.output_artifact_ids) -contains [string]$commandData.artifact_id -and $_.state_after -eq 'succeeded' }).Count -gt 0
    if ($hasEvidence) { Write-P0CommandResult 'artifact_not_orphan' 1 }
    $relativeResultPath = [string]$commandData.relative_path
    if ($commandData.action -eq 'quarantine') {
      $quarantineDirectory = Join-Path $sessionRoot 'intermediate/p0/quarantine'
      if (-not (Test-Path -LiteralPath $quarantineDirectory)) { New-Item -ItemType Directory -Path $quarantineDirectory -Force | Out-Null }
      $destination = Join-Path $quarantineDirectory (Split-Path -Leaf $artifactPath)
      Move-Item -LiteralPath $artifactPath -Destination $destination -Force
      $relativeResultPath = $destination.Substring($sessionRoot.Length + 1).Replace('\','/')
    }
    $write = Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId ([string]$commandData.step_id) -EventType $(if ($commandData.action -eq 'adopt') { 'artifact.reconciled.v1' } else { 'artifact.quarantined.v1' }) -EventSource 'reconciler' -StateBefore 'running' -StateAfter $(if ($commandData.action -eq 'adopt') { 'succeeded' } else { 'skipped' }) -PayloadDigest $payloadDigest -IdempotencyKey ([string]$commandData.idempotency_key) -ExpectedLastSequenceNo ([int]$commandData.expected_last_sequence_no) -ResultCode $(if ($commandData.action -eq 'adopt') { 'orphan_reconciled' } else { 'orphan_quarantined' }) -SafeSummary ([string]$commandData.safe_summary) -OutputArtifactIds @([string]$commandData.artifact_id) -InputDigest ([string]$commandData.input_digest)
    if ($write.ExitCode -ne 0) { Write-P0CommandResult $write.ResultCode $write.ExitCode @("EVENT_LAST_SEQUENCE=$($write.LastSequenceNo)") }
    if ($commandData.action -eq 'adopt') { [void](Write-P0EvidenceLineage $sessionRoot ([string]$commandData.artifact_id) ([string]$commandData.artifact_type) ([string]$write.Event.event_id) @($commandData.input_artifact_ids) $relativeResultPath $actualDigest 'not_run' 'trace_only' @()) }
    Write-P0CommandResult $(if ($commandData.action -eq 'adopt') { 'orphan_reconciled' } else { 'orphan_quarantined' }) 0 @("EVENT_LAST_SEQUENCE=$($write.LastSequenceNo)","ARTIFACT_PATH=$relativeResultPath")
  }

  if ($Mode -in @('build_resume_summary','rebuild_projection')) {
    $force = $Mode -eq 'rebuild_projection'
    $projectionResult = Update-P0StateProjection $sessionRoot $plan $eventPath $force
    if ($projectionResult.ExitCode -ne 0) { Write-P0CommandResult $projectionResult.ResultCode $projectionResult.ExitCode @($projectionResult.Errors | ForEach-Object { "ERROR=$_" }) }
    if ($Mode -eq 'rebuild_projection') { Write-P0CommandResult $projectionResult.ResultCode 0 @("PROJECTION_PATH=intermediate/p0/state-projection.json","PROJECTED_THROUGH=$($projectionResult.Projection.projected_through_sequence_no)") }
    $summary = Write-P0ResumeSummary $sessionRoot $plan $projectionResult.Projection
    Write-P0CommandResult 'resume_summary_built' 0 @("RESUME_SUMMARY_PATH=intermediate/p0/resume-summary.json","CURRENT_STATE=$($summary.current_state)","NEXT_STEP=$($summary.next_step_id)","RECOVERY_ACTION=$($summary.recovery_action)")
  }

  Write-P0CommandResult 'unsupported_mode' 4
} catch {
  Write-Error ("P0_EVIDENCE_TOOL_ERROR=" + $_.Exception.Message)
  exit 3
}
