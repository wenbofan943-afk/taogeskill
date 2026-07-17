param(
  [string]$ProjectRoot = '',
  [string]$WorkRoot = ''
)

$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($ProjectRoot)){$ProjectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path}
if([string]::IsNullOrWhiteSpace($WorkRoot)){$WorkRoot=Join-Path $ProjectRoot 'state/checks/r8-h3-work'}
. (Join-Path $PSScriptRoot 'R7ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'R7SemanticRuntime.ps1')
. (Join-Path $PSScriptRoot 'R7CandidateRuntime.ps1')
. (Join-Path $PSScriptRoot 'R8HumanGateRuntime.ps1')

$results=[Collections.Generic.List[object]]::new()
function Add-H3Result([string]$Id,[bool]$Pass,[object[]]$Evidence){
  $results.Add([pscustomobject][ordered]@{check_id=$Id;status=$(if($Pass){'pass'}else{'fail'});evidence=@($Evidence)})
}
function New-H3Ref([string]$Id){
  return [pscustomobject][ordered]@{artifact_id=$Id;revision=1;sha256='sha256:'+('a'*64)}
}
function New-H3Decision([object]$Case,[string]$SessionId){
  return [pscustomobject][ordered]@{
    schema_id='taoge://schemas/r7/final-delivery-human-decision/v0.1'
    schema_version='0.1'
    decision_id="DEC-$($Case.case_id)"
    decision_revision=1
    session_id=$SessionId
    delivery_ref=New-H3Ref 'DELIVERY-001'
    viewport_acceptance_ref=New-H3Ref 'VIEWPORT-001'
    delivery_visual_review_ref=New-H3Ref 'VISUAL-REVIEW-001'
    business_delivery_acceptance_ref=New-H3Ref 'BUSINESS-REVIEW-001'
    action_code=[string]$Case.action_code
    user_reply_digest='sha256:'+('b'*64)
    requested_at='2026-07-17T10:00:00+08:00'
    delivery_revision_request_ref=$Case.delivery_revision_request_ref
    export_mode=$Case.export_mode
    decision_status='decision_recorded'
  }
}
function Write-H3CurrentArtifact([string]$SessionRoot,[string]$ArtifactType,[string]$ArtifactId,[object]$Payload,[string]$Status){
  $relative="intermediate/r7/revisions/$ArtifactType/$ArtifactId.json"
  $path=Join-Path $SessionRoot $relative
  $text=ConvertTo-P0EvidenceJsonText $Payload
  Write-P0EvidenceAtomicText $path $text
  $digest=Get-R7RuntimeTextDigest $text
  $pointer=[ordered]@{schema_id='taoge://schemas/r7/semantic-current-pointer/v0.1';schema_version='0.1';artifact_type=$ArtifactType;artifact_id=$ArtifactId;revision=1;revision_path=$relative;sha256=$digest;status=$Status;task_envelope_id='TASK-R8-H3-FIXTURE';submission_id='SUB-R8-H3-FIXTURE';producer_event_id='EVT-R8-H3-FIXTURE';committed_at='2026-07-17T10:00:00+08:00'}
  Write-P0EvidenceAtomicText (Join-Path $SessionRoot "intermediate/r7/current/$ArtifactType.json") (ConvertTo-P0EvidenceJsonText $pointer)
  return [pscustomobject]$pointer
}

$routerPath=Join-Path $ProjectRoot 'skills/propagation-router/SKILL.md'
$router=Get-Content -Raw -Encoding UTF8 $routerPath
$routerContract=Get-Content -Raw -Encoding UTF8 (Join-Path $ProjectRoot 'skills/propagation-router/CONTRACT.md')
$routerLines=@(Get-Content -Encoding UTF8 $routerPath).Count
Add-H3Result 'H3-001-router-slim' ($routerLines-le500-and$router-match'next node'-and$routerContract-match'owned_node_ids: \[\]') @("lines=$routerLines")
Add-H3Result 'H3-002-router-references' ((Test-Path (Join-Path $ProjectRoot 'skills/propagation-router/references/resume-and-recovery.md'))-and(Test-Path (Join-Path $ProjectRoot 'skills/propagation-router/references/legacy-r1-r2-routing.md'))) @()

$registries=Get-R7RuntimeRegistries $ProjectRoot
$topicNode=@($registries.Nodes.nodes|Where-Object{$_.node_id-eq'topic_human_gate'})|Select-Object -First 1
$finalNode=@($registries.Nodes.nodes|Where-Object{$_.node_id-eq'final_human_decision_gate'})|Select-Object -First 1
$applyNode=@($registries.Nodes.nodes|Where-Object{$_.node_id-eq'final_delivery_decision_apply'})|Select-Object -First 1
Add-H3Result 'H3-003-node-ownership' ([string]$topicNode.skill_ref-eq'topic-selection-decision-gate'-and[string]$finalNode.skill_ref-eq'final-delivery-decision-gate'-and[string]$applyNode.step_kind-eq'deterministic_tool') @([string]$topicNode.skill_ref,[string]$finalNode.skill_ref,[string]$applyNode.step_kind)
Add-H3Result 'H3-003B-versioned-node-ownership' ([string]$registries.Nodes.registry_id-eq'r7-workflow-node-registry-v0.3'-and[string]$registries.Blueprints.registry_id-eq'r7-workflow-blueprints-v0.4') @([string]$registries.Nodes.registry_id,[string]$registries.Blueprints.registry_id)

$planErrors=[Collections.Generic.List[string]]::new()
foreach($blueprint in @('direct_delivery_single_v0.6','hotspot_to_delivery_single_v0.6')){
  $plan=New-R7RuntimePlan 'R8-H3-PLAN' $blueprint $registries 'no_provider'
  foreach($item in @(Test-P0PlanContract $plan)){$planErrors.Add("${blueprint}:$item")}
  $nodeIds=@($plan.steps|ForEach-Object{[string]$_.node_id})
  if($nodeIds[-2]-ne'final_human_decision_gate'-or$nodeIds[-1]-ne'final_delivery_decision_apply'){$planErrors.Add("$blueprint:terminal_split_missing")}
}
Add-H3Result 'H3-004-current-blueprints' ($planErrors.Count-eq0) @($planErrors)

$fixture=Get-Content -Raw -Encoding UTF8 (Join-Path $ProjectRoot 'examples/r8-skill-context-fixtures/h3-human-gate-cases.json')|ConvertFrom-Json
$caseErrors=[Collections.Generic.List[string]]::new()
foreach($case in @($fixture.cases)){
  $decision=New-H3Decision $case 'R8-H3-FIXTURE'
  $actual=@(Test-R8FinalDeliveryHumanDecision $decision).Count-eq0
  $expected=[string]$case.expected-eq'pass'
  if($actual-ne$expected){$caseErrors.Add([string]$case.case_id)}
}
Add-H3Result 'H3-005-final-decision-contract' ($caseErrors.Count-eq0) @($caseErrors)

$session=Join-Path $WorkRoot ('R8-H3-APPLY-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path (Join-Path $session 'intermediate/p0'),(Join-Path $session 'intermediate/r7/current'),(Join-Path $session 'inputs'),(Join-Path $session 'intermediate/r8') -Force|Out-Null
$plan=New-R7RuntimePlan 'R8-H3-APPLY' 'direct_delivery_single_v0.6' $registries 'no_provider'
$plan.steps=@($plan.steps[0],$plan.steps[-2],$plan.steps[-1])
$plan.steps[1].requires_step_ids=@([string]$plan.steps[0].step_id)
$plan.steps[2].requires_step_ids=@([string]$plan.steps[1].step_id)
Write-P0EvidenceAtomicText (Join-Path $session 'intermediate/p0/session-execution-plan.json') (ConvertTo-P0EvidenceJsonText $plan)
$eventPath=Join-Path $session 'intermediate/p0/execution-events.jsonl'
$planDigest=Get-R7RuntimeObjectDigest $plan
$write=Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId ([string]$plan.steps[0].step_id) -EventType 'plan.created.v1' -EventSource 'runner' -StateBefore 'ready' -StateAfter 'succeeded' -PayloadDigest $planDigest -IdempotencyKey 'R8-H3-APPLY:plan' -ExpectedLastSequenceNo 0 -ResultCode 'r7_session_plan_created' -SafeSummary 'H3 focused plan' -OutputArtifactIds @([string]$plan.plan_id) -InputDigest $planDigest -ExecutionAttemptId 'ATT-R8-H3-PLAN-1'
$deliveryPointer=Write-H3CurrentArtifact $session 'final_delivery' 'DELIVERY-001' ([pscustomobject]@{artifact_id='DELIVERY-001';status='delivery_ready'}) 'delivery_ready'
$viewportPointer=Write-H3CurrentArtifact $session 'viewport_acceptance_report' 'VIEWPORT-001' ([pscustomobject]@{artifact_id='VIEWPORT-001';status='pass'}) 'pass'
$visualPointer=Write-H3CurrentArtifact $session 'delivery_visual_review' 'VISUAL-REVIEW-001' ([pscustomobject]@{artifact_id='VISUAL-REVIEW-001';status='pass'}) 'pass'
$businessPointer=Write-H3CurrentArtifact $session 'business_delivery_acceptance' 'BUSINESS-REVIEW-001' ([pscustomobject]@{artifact_id='BUSINESS-REVIEW-001';status='pass'}) 'pass'
$replyText='adopt current delivery'
$reply=[ordered]@{schema_id='taoge://schemas/r7/human-reply/v0.1';schema_version='0.1';reply_id='REPLY-R8-H3';session_id='R8-H3-APPLY';gate_node_id='final_human_decision_gate';reply_text=$replyText;reply_digest=Get-R7RuntimeTextDigest $replyText;recorded_at='2026-07-17T10:00:00+08:00'}
Write-P0EvidenceAtomicText (Join-Path $session 'inputs/final-human-reply.json') (ConvertTo-P0EvidenceJsonText $reply)
$projection=Update-P0StateProjection $session $plan $eventPath $true
$prepared=Prepare-R7RuntimeTask $ProjectRoot $session
$decision=New-H3Decision $fixture.cases[0] 'R8-H3-APPLY'
$decision.user_reply_digest=[string]$reply.reply_digest
$decision.delivery_ref=[pscustomobject]@{artifact_id=[string]$deliveryPointer.artifact_id;revision=1;sha256=[string]$deliveryPointer.sha256}
$decision.viewport_acceptance_ref=[pscustomobject]@{artifact_id=[string]$viewportPointer.artifact_id;revision=1;sha256=[string]$viewportPointer.sha256}
$decision.delivery_visual_review_ref=[pscustomobject]@{artifact_id=[string]$visualPointer.artifact_id;revision=1;sha256=[string]$visualPointer.sha256}
$decision.business_delivery_acceptance_ref=[pscustomobject]@{artifact_id=[string]$businessPointer.artifact_id;revision=1;sha256=[string]$businessPointer.sha256}
$decisionPath=Join-Path $session 'intermediate/r8/final-delivery-human-decision.json'
Write-P0EvidenceAtomicText $decisionPath (ConvertTo-P0EvidenceJsonText $decision)
$build=New-R7RuntimeSubmissionFromPayload $ProjectRoot $session ([string]$prepared.Data.Task.task_envelope_id) $decisionPath 'decision_recorded' 1
$submission=$null
$submissionActionOk=$false
if($build.ExitCode-eq0){
  $submission=Read-P0JsonFile (Join-Path $session ([string]$build.Data.SubmissionPath))
  $submissionActionOk=[string]$submission.requested_action-eq[string]$decision.action_code
}
$commit=if($build.ExitCode-eq0){Submit-R7RuntimeArtifact $ProjectRoot $session ([string]$build.Data.SubmissionPath)}else{New-R7RuntimeResult 'decision_build_failed' 1 $null $build.Errors}
$apply=Invoke-R8FinalDeliveryDecisionApply $ProjectRoot $session
$recordPath=Join-Path $session 'intermediate/r7/current/workflow_session_record.json'
$recordOk=$apply.ExitCode-eq0-and(Test-Path $recordPath)
if($recordOk){$recordPointer=Read-P0JsonFile $recordPath;$record=Read-P0JsonFile (Join-Path $session ([string]$recordPointer.revision_path));$recordOk=[string]$record.session_status-eq'delivery_adopted'-and[string]$record.next_skill-eq'done'}
Add-H3Result 'H3-006-final-decision-record-and-apply' ($prepared.ExitCode-eq0-and[string]$prepared.Data.Task.action_registry_version-eq'r7-action-registry-v0.3'-and$build.ExitCode-eq0-and$submissionActionOk-and$commit.ExitCode-eq0-and$recordOk) @([string]$prepared.ResultCode,[string]$prepared.Data.Task.action_registry_version,[string]$build.ResultCode,[string]$submission.requested_action,[string]$commit.ResultCode,[string]$apply.ResultCode)
$replyRecorderPath=Join-Path $ProjectRoot 'tools/new-r8-human-reply.ps1'
$replyRecorder=Get-Content -Raw -Encoding UTF8 $replyRecorderPath
Add-H3Result 'H3-007-typed-human-reply-recorder' ((Test-Path $replyRecorderPath)-and$replyRecorder-match'Test-R8HumanReply'-and$replyRecorder-match'current_reply_conflict') @('tools/new-r8-human-reply.ps1')
$repeatApply=Invoke-R8FinalDeliveryDecisionApply $ProjectRoot $session
Add-H3Result 'H3-008-apply-requires-current-state' ($repeatApply.ExitCode-ne0-and[string]$repeatApply.ResultCode-eq'final_decision_state_binding_error') @([string]$repeatApply.ResultCode)

$failed=@($results|Where-Object{$_.status-ne'pass'})
$report=[ordered]@{schema_id='taoge://reports/r8/h3-router-human-gates/v0.1';checked_at=[DateTimeOffset]::UtcNow.ToString('o');result=$(if($failed.Count){'fail'}else{'pass'});checks=@($results)}
$reportPath=Join-Path $ProjectRoot 'state/checks/r8-h3-router-human-gates.json'
Write-P0EvidenceAtomicText $reportPath (ConvertTo-P0EvidenceJsonText $report)
Write-Output "R8_H3_RESULT=$($report.result)"
Write-Output "R8_H3_CHECKS=$($results.Count)"
Write-Output "R8_H3_REPORT=$reportPath"
if($failed.Count){foreach($item in $failed){Write-Output "R8_H3_FAILURE=$($item.check_id):$([string]::Join(',',@($item.evidence)))"};exit 1}
exit 0
