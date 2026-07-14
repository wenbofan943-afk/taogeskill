param(
  [string]$FixtureRoot='examples/r7-h3-producer-fixtures',
  [string]$WorkRoot='state/checks/r7-h3-producer-work',
  [string]$HumanReportPath='state/checks/r7-h3-producer-check-report.md',
  [string]$MachineReportPath='state/checks/r7-h3-producer-check-report.json'
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'R7ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'R7SemanticRuntime.ps1')
. (Join-Path $PSScriptRoot 'R6ScriptVisualContract.ps1')

function Resolve-R7H3Path([string]$Path){if([IO.Path]::IsPathRooted($Path)){return [IO.Path]::GetFullPath($Path)};return [IO.Path]::GetFullPath((Join-Path $script:ProjectRoot $Path))}
function New-R7H3Result([string]$Id,[string]$Expected,[string]$Actual,[string[]]$Errors=@()){[pscustomobject]@{fixture_id=$Id;expected_result=$Expected;actual_result=$Actual;expectation_met=($Expected-eq$Actual);errors=[object[]]@($Errors)}}

function Write-R7H3Pointer {
  param([string]$Session,[string]$Type,[string]$Id,[object]$Payload,[string]$Status)
  $revisionRel="intermediate/r7/revisions/$Type/$Id.json";$revisionPath=Join-Path $Session $revisionRel
  Write-P0EvidenceAtomicText $revisionPath (ConvertTo-P0EvidenceJsonText $Payload);$digest=Get-R7RuntimeHash $revisionPath
  $pointer=[ordered]@{schema_id='taoge://schemas/r7/semantic-current-pointer/v0.1';schema_version='0.1';artifact_type=$Type;artifact_id=$Id;revision=1;revision_path=$revisionRel;sha256=$digest;status=$Status;task_envelope_id='FIXTURE-SEED';submission_id='FIXTURE-SEED';producer_event_id='FIXTURE-SEED';committed_at=[DateTimeOffset]::UtcNow.ToString('o')}
  Write-P0EvidenceAtomicText (Join-Path $Session "intermediate/r7/current/$Type.json") (ConvertTo-P0EvidenceJsonText $pointer)
}

function New-R7H3ProjectedSession {
  param([string]$RunRoot,[string]$SessionId,[string]$NextNode)
  $session=Join-Path $RunRoot $SessionId;New-Item -ItemType Directory -Path (Join-Path $session 'intermediate/account-startup') -Force|Out-Null;New-Item -ItemType Directory -Path (Join-Path $session 'inputs') -Force|Out-Null
  [IO.File]::WriteAllText((Join-Path $session 'inputs/user-supplied-draft.md'),'fixture draft',[Text.UTF8Encoding]::new($false))
  $account=[ordered]@{schema_id='taoge://schemas/r5/account-session-snapshot/v0.2';schema_version='0.2';snapshot_id="AS-$SessionId";session_id=$SessionId;account_slug='sample-account';account_display_name='Sample Account';account_profile_ref='examples/sample-account/account-profile.yaml';identity_binding_ref='examples/sample-account/account-identity-binding.json';identity_binding_digest=('sha256:'+'a'*64);account_snapshot_status='snapshot_ready';missing_fields=[object[]]@();human_gate=[ordered]@{required=$false;reason=$null};created_at='2026-07-14T00:00:00Z'}
  Write-P0EvidenceAtomicText (Join-Path $session 'intermediate/account-startup/account-snapshot.v0.2.json') (ConvertTo-P0EvidenceJsonText $account)
  $registries=Get-R7RuntimeRegistries $script:ProjectRoot;$plan=New-R7RuntimePlan $SessionId 'direct_delivery_single_v0.1' $registries;$planPath=Join-Path $session 'intermediate/p0/session-execution-plan.json';Write-P0EvidenceAtomicText $planPath (ConvertTo-P0EvidenceJsonText $plan)
  $eventPath=Join-Path $session 'intermediate/p0/execution-events.jsonl';$planDigest=Get-R7RuntimeHash $planPath
  $create=Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId "STEP-$SessionId-session_plan" -EventType 'plan.created.v1' -EventSource runner -StateBefore ready -StateAfter succeeded -PayloadDigest $planDigest -IdempotencyKey "${SessionId}:fixture-plan" -ExpectedLastSequenceNo 0 -ResultCode fixture_seed -SafeSummary 'Fixture R7 plan seeded' -OutputArtifactIds @($plan.plan_id)
  if($create.ExitCode-ne0){throw "fixture_plan_event_failed:$($create.ResultCode)"}
  foreach($step in @($plan.steps|Select-Object -Skip 1)){
    if($step.node_id-eq$NextNode){break}
    $source=switch([string]$step.step_kind){'agent_required'{'agent_recorder'}'human_gate'{'human_recorder'}'external_side_effect'{'reconciler'}default{'runner'}}
    $digest=Get-R7RuntimeTextDigest ([string]$step.node_id);$events=@(Get-P0EvidenceEvents $eventPath)
    $write=Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId $step.step_id -EventType 'fixture.semantic.completed.v1' -EventSource $source -StateBefore ready -StateAfter succeeded -PayloadDigest $digest -IdempotencyKey "${SessionId}:fixture:$($step.node_id)" -ExpectedLastSequenceNo $events.Count -ResultCode fixture_seed -SafeSummary 'Fixture prerequisite step seeded' -OutputArtifactIds @("SEED-$($step.node_id)")
    if($write.ExitCode-ne0){throw "fixture_prior_event_failed:$($step.node_id):$($write.ResultCode)"}
  }
  $projection=Update-P0StateProjection $session $plan $eventPath $true;if($projection.ExitCode-ne0){throw "fixture_projection_failed:$($projection.ResultCode)"}
  return [pscustomobject]@{Session=$session;Plan=$plan}
}

try{
  $script:ProjectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path;$fixturePath=Resolve-R7H3Path $FixtureRoot;$workBase=Resolve-R7H3Path $WorkRoot;$humanPath=Resolve-R7H3Path $HumanReportPath;$machinePath=Resolve-R7H3Path $MachineReportPath
  foreach($p in @($fixturePath,(Split-Path -Parent $humanPath),(Split-Path -Parent $machinePath),$workBase)){if(-not(Test-Path $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}}
  $runRoot=Join-Path $workBase ('RUN-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6));New-Item -ItemType Directory $runRoot|Out-Null
  $results=[Collections.Generic.List[object]]::new();$registries=Get-R7RuntimeRegistries $script:ProjectRoot

  $requiredNodes=@('direct_content_intake','content_brief','structure_plan','draft','content_beat_map','script_review','content_revision_gate','visual_need_analysis','visual_production','script_visual_alignment','platform_package','cover_design')
  $adapterErrors=[Collections.Generic.List[string]]::new()
  foreach($nodeId in $requiredNodes){$adapter=@($registries.ProducerAdapters.adapters|Where-Object{$_.node_id-eq$nodeId});if($adapter.Count-ne1){$adapterErrors.Add("adapter_count:${nodeId}:$($adapter.Count)");continue};$schema=Join-Path $script:ProjectRoot $adapter[0].payload_schema_path;if(-not(Test-Path $schema)){$adapterErrors.Add("adapter_schema_missing:$nodeId")};$node=Get-R7RuntimeNode $registries $nodeId;if($node.output_artifact_type-ne$adapter[0].artifact_type){$adapterErrors.Add("adapter_output_mismatch:$nodeId")};$profile=@($registries.Commits.profiles|Where-Object{$_.artifact_type-eq$adapter[0].artifact_type})|Select-Object -First 1;foreach($status in @($node.allowed_result_statuses)){if([string]::IsNullOrWhiteSpace((Get-R7RuntimeField $profile.status_value_map @([string]$status)))){$adapterErrors.Add("status_mapping_missing:${nodeId}:$status")}}}
  $results.Add((New-R7H3Result 'R7-H3-ADAPTER-COVERAGE' pass $(if($adapterErrors.Count){'fail'}else{'pass'}) $adapterErrors.ToArray()))

  $bundle=Read-R7JsonFile (Join-Path $script:ProjectRoot 'examples/r6-script-visual-fixtures/base-direct.json');$bundleErrors=@(Test-R6ScriptVisualBundle $bundle)
  $actualF01=if($bundleErrors.Count-eq0-and$adapterErrors.Count-eq0){'pass'}else{'fail'};$results.Add((New-R7H3Result 'R7-F01-PRODUCER-SLICE' pass $actualF01 ($bundleErrors+$adapterErrors.ToArray())))

  $f03=New-R7H3ProjectedSession $runRoot 'R7-F03' 'content_revision_gate'
  $draft=[ordered]@{draft_id='DRAFT-R7-F03';draft_status='baseline_ready'};$review=[ordered]@{script_design_review_id='REVIEW-R7-F03';review_status='pass_with_warnings'}
  Write-R7H3Pointer $f03.Session draft 'DRAFT-R7-F03' $draft baseline_ready;Write-R7H3Pointer $f03.Session script_design_review 'REVIEW-R7-F03' $review pass_with_warnings
  $prepared03=Prepare-R7RuntimeTask $script:ProjectRoot $f03.Session
  $decision=[ordered]@{schema_id='taoge://schemas/r6/content-revision-decision/v0.1';schema_version='0.1.0';content_revision_decision_id='DECISION-R7-F03';decision_revision=1;script_design_review_ref=[ordered]@{artifact_id='REVIEW-R7-F03';revision=1;sha256=('sha256:'+'1'*64)};decision='accept_current';accepted_advisory_issue_ids=[object[]]@('ISSUE-ADVISORY');authorization_refs=[object[]]@('HUMAN-KEEP-CURRENT');decision_reason='The user explicitly accepted the current supplied script';decided_by='human';decided_at='2026-07-14T00:00:00Z';derived_script_readiness='ready_with_warnings';next_skill='static-visual-director'}
  $payload03=Join-Path $f03.Session 'intermediate/r7/producer-payloads/decision.json';Write-P0EvidenceAtomicText $payload03 (ConvertTo-P0EvidenceJsonText $decision)
  $built03=New-R7RuntimeSubmissionFromPayload $script:ProjectRoot $f03.Session $prepared03.Data.Task.task_envelope_id $payload03 keep_current 1;$submitted03=if($built03.ExitCode-eq0){Submit-R7RuntimeArtifact $script:ProjectRoot $f03.Session $built03.Data.SubmissionPath}else{$built03}
  $actual03=if($submitted03.ResultCode-eq'semantic_artifact_committed'-and$submitted03.Data.NextStepId-like'*-visual_need_analysis'){'keep_current_committed'}else{[string]$submitted03.ResultCode};$results.Add((New-R7H3Result 'R7-F03' keep_current_committed $actual03 @($submitted03.Errors)))

  $f04=New-R7H3ProjectedSession $runRoot 'R7-F04' 'structure_plan'
  Write-R7H3Pointer $f04.Session direct_content_intake 'INTAKE-R7-F04' ([ordered]@{intake_id='INTAKE-R7-F04';direct_content_status='direct_content_ready'}) direct_content_ready
  Write-R7H3Pointer $f04.Session content_brief 'BRIEF-R7-F04' ([ordered]@{brief_id='BRIEF-R7-F04';brief_status='ready'}) ready
  $prepared04=Prepare-R7RuntimeTask $script:ProjectRoot $f04.Session
  $planPayload=($bundle.structure_plan|ConvertTo-Json -Depth 40|ConvertFrom-Json);$planPayload.structure_plan_id='STRUCT-R7-F04';$planPayload.plan_status='pending_selection';$planPayload.selection_status='waiting_human';$planPayload.selected_candidate_id=$null;$planPayload.selected_strategy_ref=$null;$planPayload.selection_decision_id=$null;$planPayload.authorization_ref=$null
  $payload04=Join-Path $f04.Session 'intermediate/r7/producer-payloads/structure.json';Write-P0EvidenceAtomicText $payload04 (ConvertTo-P0EvidenceJsonText $planPayload)
  $built04=New-R7RuntimeSubmissionFromPayload $script:ProjectRoot $f04.Session $prepared04.Data.Task.task_envelope_id $payload04 waiting_authorization 1;$submitted04=if($built04.ExitCode-eq0){Submit-R7RuntimeArtifact $script:ProjectRoot $f04.Session $built04.Data.SubmissionPath}else{$built04}
  $pointer04=Test-Path (Join-Path $f04.Session 'intermediate/r7/current/short_video_structure_plan.json');$projection04=Read-P0JsonFile (Join-Path $f04.Session 'intermediate/p0/state-projection.json');$errors04=@();if($pointer04){$errors04+='waiting_pointer_written'};if($projection04.next_step_id-notlike'*-structure_plan'){$errors04+='waiting_cursor_advanced'}
  $actual04=if($submitted04.ResultCode-eq'semantic_waiting'-and@($errors04).Count-eq0){'semantic_waiting'}else{[string]$submitted04.ResultCode};$results.Add((New-R7H3Result 'R7-F04' semantic_waiting $actual04 $errors04))

  $mismatches=@($results|Where-Object{-not$_.expectation_met});$report=[ordered]@{r7_h3_producer_check_report=[ordered]@{check_run_id='R7-H3-'+(Get-Date -Format 'yyyyMMdd-HHmmss');overall_result=$(if($mismatches.Count){'fail'}else{'pass'});exit_code=$(if($mismatches.Count){1}else{0});adapter_count=@($registries.ProducerAdapters.adapters).Count;fixture_count=3;mismatch_count=$mismatches.Count;not_tested_scope=[object[]]@('r7_h4_candidate_compiler','r7_h5_viewport','real_account','provider','network','publishing');checks=[object[]]$results.ToArray()}}
  Write-TaogeUtf8NoBomJson $machinePath $report 30;$lines=@('# R7-H3 Producer Adapter Check','',"overall_result: $($report.r7_h3_producer_check_report.overall_result)",'','| Check | Expected | Actual | Matched | Errors |','|---|---|---|---:|---|');foreach($x in $results){$lines+="| $($x.fixture_id) | $($x.expected_result) | $($x.actual_result) | $($x.expectation_met) | $([string]::Join(';',@($x.errors))) |"};Write-TaogeUtf8NoBomLines $humanPath $lines
  if($mismatches.Count){Write-Output 'R7_H3_PRODUCER_CHECK_RESULT=fail';foreach($x in $mismatches){Write-Output "R7_H3_ERROR=$($x.fixture_id):$([string]::Join(';',@($x.errors)))"};exit 1};Write-Output 'R7_H3_PRODUCER_CHECK_RESULT=pass';Write-Output "R7_H3_ADAPTER_COUNT=$(@($registries.ProducerAdapters.adapters).Count)";Write-Output 'R7_H3_FIXTURE_COUNT=3';exit 0
}catch{Write-Error("{0} at line {1}: {2}"-f$_.Exception.Message,$_.InvocationInfo.ScriptLineNumber,$_.InvocationInfo.Line);exit 3}
