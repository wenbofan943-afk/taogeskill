param(
  [string]$WorkRoot='state/checks/r7-h5a-direct-sequence-work',
  [string]$HumanReportPath='state/checks/r7-h5a-direct-sequence-report.md',
  [string]$MachineReportPath='state/checks/r7-h5a-direct-sequence-report.json'
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'R7ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'R7SemanticRuntime.ps1')

function Resolve-R7H5APath([string]$Path){if([IO.Path]::IsPathRooted($Path)){return [IO.Path]::GetFullPath($Path)};return [IO.Path]::GetFullPath((Join-Path $script:ProjectRoot $Path))}
function New-R7H5AResult([string]$Id,[string]$Expected,[string]$Actual,[string[]]$Errors=@()){[pscustomobject]@{fixture_id=$Id;expected_result=$Expected;actual_result=$Actual;expectation_met=($Expected-eq$Actual);errors=[object[]]@($Errors)}}

function Write-R7H5APointer {
  param([string]$Session,[string]$Type,[string]$Id,[object]$Payload,[string]$Status,[int]$Revision=1)
  $revisionRel="intermediate/r7/revisions/$Type/$Id.json";$revisionPath=Join-Path $Session $revisionRel
  Write-P0EvidenceAtomicText $revisionPath (ConvertTo-P0EvidenceJsonText $Payload);$digest=Get-R7RuntimeHash $revisionPath
  $pointer=[ordered]@{schema_id='taoge://schemas/r7/semantic-current-pointer/v0.1';schema_version='0.1';artifact_type=$Type;artifact_id=$Id;revision=$Revision;revision_path=$revisionRel;sha256=$digest;status=$Status;task_envelope_id='FIXTURE-SEED';submission_id='FIXTURE-SEED';producer_event_id='FIXTURE-SEED';committed_at=[DateTimeOffset]::UtcNow.ToString('o')}
  Write-P0EvidenceAtomicText (Join-Path $Session "intermediate/r7/current/$Type.json") (ConvertTo-P0EvidenceJsonText $pointer)
}

function New-R7H5AProjectedSession {
  param([string]$RunRoot,[string]$SessionId,[string]$NextNode)
  $session=Join-Path $RunRoot $SessionId;New-Item -ItemType Directory -Path (Join-Path $session 'intermediate/account-startup') -Force|Out-Null;New-Item -ItemType Directory -Path (Join-Path $session 'inputs') -Force|Out-Null
  [IO.File]::WriteAllText((Join-Path $session 'inputs/user-supplied-draft.md'),'fixture draft',[Text.UTF8Encoding]::new($false))
  $account=[ordered]@{schema_id='taoge://schemas/r5/account-session-snapshot/v0.2';schema_version='0.2';snapshot_id="AS-$SessionId";session_id=$SessionId;account_slug='sample-account';account_display_name='Sample Account';account_profile_ref='examples/sample-account/account-profile.yaml';identity_binding_ref='examples/sample-account/account-identity-binding.json';identity_binding_digest=('sha256:'+'a'*64);account_snapshot_status='snapshot_ready';missing_fields=[object[]]@();human_gate=[ordered]@{required=$false;reason=$null};created_at='2026-07-14T00:00:00Z'}
  Write-P0EvidenceAtomicText (Join-Path $session 'intermediate/account-startup/account-snapshot.v0.2.json') (ConvertTo-P0EvidenceJsonText $account)
  $registries=Get-R7RuntimeRegistries $script:ProjectRoot;$plan=New-R7RuntimePlan $SessionId 'direct_delivery_single_v0.2' $registries;$planPath=Join-Path $session 'intermediate/p0/session-execution-plan.json';Write-P0EvidenceAtomicText $planPath (ConvertTo-P0EvidenceJsonText $plan)
  $eventPath=Join-Path $session 'intermediate/p0/execution-events.jsonl';$planDigest=Get-R7RuntimeHash $planPath
  $create=Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId "STEP-$SessionId-session_plan" -EventType 'plan.created.v1' -EventSource runner -StateBefore ready -StateAfter succeeded -PayloadDigest $planDigest -IdempotencyKey "${SessionId}:fixture-plan" -ExpectedLastSequenceNo 0 -ResultCode fixture_seed -SafeSummary 'Fixture R7 v0.2 plan seeded' -OutputArtifactIds @($plan.plan_id)
  if($create.ExitCode-ne0){throw "fixture_plan_event_failed:$($create.ResultCode)"}
  foreach($step in @($plan.steps|Select-Object -Skip 1)){
    if($step.node_id-eq$NextNode){break}
    $source=switch([string]$step.step_kind){'agent_required'{'agent_recorder'}'human_gate'{'human_recorder'}'external_side_effect'{'reconciler'}default{'runner'}};$events=@(Get-P0EvidenceEvents $eventPath)
    $write=Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId $step.step_id -EventType 'fixture.semantic.completed.v1' -EventSource $source -StateBefore ready -StateAfter succeeded -PayloadDigest (Get-R7RuntimeTextDigest ([string]$step.node_id)) -IdempotencyKey "${SessionId}:fixture:$($step.node_id)" -ExpectedLastSequenceNo $events.Count -ResultCode fixture_seed -SafeSummary 'Fixture prerequisite seeded' -OutputArtifactIds @("SEED-$($step.node_id)")
    if($write.ExitCode-ne0){throw "fixture_prior_event_failed:$($step.node_id):$($write.ResultCode)"}
  }
  $projection=Update-P0StateProjection $session $plan $eventPath $true;if($projection.ExitCode-ne0){throw "fixture_projection_failed:$($projection.ResultCode)"}
  return [pscustomobject]@{Session=$session;Plan=$plan}
}

try{
  $script:ProjectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path;$workBase=Resolve-R7H5APath $WorkRoot;$humanPath=Resolve-R7H5APath $HumanReportPath;$machinePath=Resolve-R7H5APath $MachineReportPath
  foreach($p in @($workBase,(Split-Path -Parent $humanPath),(Split-Path -Parent $machinePath))){if(-not(Test-Path $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}}
  $runRoot=Join-Path $workBase ('RUN-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6));New-Item -ItemType Directory $runRoot|Out-Null
  $results=[Collections.Generic.List[object]]::new();$registries=Get-R7RuntimeRegistries $script:ProjectRoot;$bundle=Read-R7JsonFile (Join-Path $script:ProjectRoot 'examples/r6-script-visual-fixtures/base-direct.json')

  $expectedOrder=@('direct_content_intake','content_brief','direct_baseline_draft','semantic_beat_map','direct_structure_plan','content_beat_map','script_review','content_revision_gate','visual_need_analysis','visual_production','script_visual_alignment','platform_package','cover_design','delivery_candidate_compile','final_delivery_render','viewport_acceptance','final_human_gate')
  $blueprint=Get-R7RuntimeBlueprint $registries 'direct_delivery_single_v0.2';$actualOrder=@($blueprint.node_refs);$orderErrors=[Collections.Generic.List[string]]::new()
  if([string]$blueprint.blueprint_version-ne'0.2'){$orderErrors.Add('blueprint_version_not_0_2')};if([string]::Join('|',$expectedOrder)-ne[string]::Join('|',$actualOrder)){$orderErrors.Add('direct_sequence_mismatch')}
  for($i=0;$i-lt$actualOrder.Count-1;$i++){ $node=Get-R7RuntimeNode $registries ([string]$actualOrder[$i]);if([string]$node.success_route-ne[string]$actualOrder[$i+1]){$orderErrors.Add("success_route_mismatch:$($actualOrder[$i])")}}
  $results.Add((New-R7H5AResult 'R7-F23-DIRECT-V02-ORDER' pass $(if($orderErrors.Count){'fail'}else{'pass'}) $orderErrors.ToArray()))

  $contractErrors=[Collections.Generic.List[string]]::new();foreach($pair in @(@('direct_baseline_draft','draft_mode','materialize_user_baseline'),@('semantic_beat_map','mapping_phase','semantic_only'),@('content_beat_map','mapping_phase','structure_bound'))){$adapter=@($registries.ProducerAdapters.adapters|Where-Object{$_.node_id-eq$pair[0]})|Select-Object -First 1;if($null-eq$adapter-or(Get-R7RuntimeField $adapter.required_field_values @($pair[1]))-ne$pair[2]){$contractErrors.Add("phase_constraint_missing:$($pair[0])")}}
  $beatProfile=@($registries.Commits.profiles|Where-Object{$_.artifact_type-eq'content_beat_map'})|Select-Object -First 1;if([string]$beatProfile.revision_field-ne'beat_map_revision'){$contractErrors.Add('beat_revision_field_missing')}
  $results.Add((New-R7H5AResult 'R7-F24-PHASE-REVISION-CONTRACT' pass $(if($contractErrors.Count){'fail'}else{'pass'}) $contractErrors.ToArray()))

  $semantic=New-R7H5AProjectedSession $runRoot 'R7-F25' 'semantic_beat_map';Write-R7H5APointer $semantic.Session draft 'D-R7-F25' ([ordered]@{draft_id='D-R7-F25';draft_status='baseline_ready'}) draft_preserved
  $prepared=Prepare-R7RuntimeTask $script:ProjectRoot $semantic.Session;$semanticPayload=($bundle.beat_map|ConvertTo-Json -Depth 60|ConvertFrom-Json);$semanticPayload.beat_map_id='BEATMAP-R7-F25-001';$semanticPayload.beat_map_revision=1;$semanticPayload.draft_id='D-R7-F25';$semanticPayload.mapping_phase='semantic_only';$semanticPayload.structure_plan_ref=$null;foreach($beat in @($semanticPayload.beats)){$beat.stage_id=$null}
  $payloadPath=Join-Path $semantic.Session 'intermediate/r7/producer-payloads/semantic.json';Write-P0EvidenceAtomicText $payloadPath (ConvertTo-P0EvidenceJsonText $semanticPayload);$built=New-R7RuntimeSubmissionFromPayload $script:ProjectRoot $semantic.Session $prepared.Data.Task.task_envelope_id $payloadPath beat_map_complete 1
  $actual25=if($built.ResultCode-eq'submission_built'-and[int](Read-R7JsonFile (Join-Path $semantic.Session $built.Data.SubmissionPath)).output_revision-eq1){'submission_revision_1'}else{[string]$built.ResultCode};$results.Add((New-R7H5AResult 'R7-F25-SEMANTIC-BEAT' submission_revision_1 $actual25 @($built.Errors)))

  $wrong=($semanticPayload|ConvertTo-Json -Depth 60|ConvertFrom-Json);$wrong.mapping_phase='structure_bound';$wrong.structure_plan_ref=[ordered]@{structure_plan_id='FUTURE';structure_plan_revision=1;selected_candidate_id='FUTURE'};$wrongPath=Join-Path $semantic.Session 'intermediate/r7/producer-payloads/wrong-phase.json';Write-P0EvidenceAtomicText $wrongPath (ConvertTo-P0EvidenceJsonText $wrong);$wrongResult=New-R7RuntimeSubmissionFromPayload $script:ProjectRoot $semantic.Session $prepared.Data.Task.task_envelope_id $wrongPath beat_map_complete 1
  $actual26=if($wrongResult.ResultCode-eq'producer_payload_contract_error'-and([string]::Join(';',@($wrongResult.Errors))-match'producer_payload_phase_mismatch')){'phase_blocked'}else{[string]$wrongResult.ResultCode};$results.Add((New-R7H5AResult 'R7-F26-SEMANTIC-PHASE-GUARD' phase_blocked $actual26 @($wrongResult.Errors)))

  $missing=New-R7H5AProjectedSession $runRoot 'R7-F27' 'direct_structure_plan';$missingResult=Prepare-R7RuntimeTask $script:ProjectRoot $missing.Session;$missingErrors=@($missingResult.Errors);$missingActual=if($missingResult.ResultCode-eq'task_envelope_error'-and([string]::Join(';',$missingErrors)-match'selector_input_missing:current_content_brief|selector_input_missing:current_draft|selector_input_missing:current_content_beat_map')){'materialized_input_blocked'}else{[string]$missingResult.ResultCode}
  $results.Add((New-R7H5AResult 'R7-F27-FUTURE-INPUT-GUARD' materialized_input_blocked $missingActual $missingErrors))

  $structure=New-R7H5AProjectedSession $runRoot 'R7-F28' 'direct_structure_plan';Write-R7H5APointer $structure.Session content_brief 'B-R7-F28' ([ordered]@{brief_id='B-R7-F28';brief_status='ready'}) brief_pass;Write-R7H5APointer $structure.Session draft 'D-R7-F28' ([ordered]@{draft_id='D-R7-F28';draft_status='baseline_ready'}) draft_preserved;Write-R7H5APointer $structure.Session content_beat_map 'BEATMAP-R7-F28-001' ([ordered]@{beat_map_id='BEATMAP-R7-F28-001';mapping_status='ready'}) beat_map_complete
  $preparedStructure=Prepare-R7RuntimeTask $script:ProjectRoot $structure.Session;$structurePayload=($bundle.structure_plan|ConvertTo-Json -Depth 60|ConvertFrom-Json);$structurePayload.structure_plan_id='STRUCT-R7-F28';$structurePayload.brief_id='B-R7-F28';$draftBinding=@($preparedStructure.Data.Task.input_artifact_bindings|Where-Object{$_.artifact_type-eq'draft'})[0];$beatBinding=@($preparedStructure.Data.Task.input_artifact_bindings|Where-Object{$_.artifact_type-eq'content_beat_map'})[0];$structurePayload.source_draft_ref=[ordered]@{artifact_id=$draftBinding.artifact_id;revision=1;sha256=('sha256:'+$draftBinding.sha256)};$structurePayload.source_beat_map_ref=[ordered]@{artifact_id=$beatBinding.artifact_id;revision=1;sha256=('sha256:'+$beatBinding.sha256)}
  $structurePath=Join-Path $structure.Session 'intermediate/r7/producer-payloads/structure.json';Write-P0EvidenceAtomicText $structurePath (ConvertTo-P0EvidenceJsonText $structurePayload);$builtStructure=New-R7RuntimeSubmissionFromPayload $script:ProjectRoot $structure.Session $preparedStructure.Data.Task.task_envelope_id $structurePath structure_ready 1;$futurePayload=($structurePayload|ConvertTo-Json -Depth 60|ConvertFrom-Json);$futurePayload.source_beat_map_ref.artifact_id='BEATMAP-FUTURE';$futurePath=Join-Path $structure.Session 'intermediate/r7/producer-payloads/future.json';Write-P0EvidenceAtomicText $futurePath (ConvertTo-P0EvidenceJsonText $futurePayload);$future=New-R7RuntimeSubmissionFromPayload $script:ProjectRoot $structure.Session $preparedStructure.Data.Task.task_envelope_id $futurePath structure_ready 1
  $actual28=if($builtStructure.ResultCode-eq'submission_built'-and$future.ResultCode-eq'producer_payload_mapping_error'-and([string]::Join(';',@($future.Errors))-match'future_artifact_reference')){'materialized_only'}else{"valid=$($builtStructure.ResultCode);future=$($future.ResultCode)"};$results.Add((New-R7H5AResult 'R7-F28-STRUCTURE-LINEAGE' materialized_only $actual28 @($builtStructure.Errors+$future.Errors)))

  $bound=New-R7H5AProjectedSession $runRoot 'R7-F29' 'content_beat_map';Write-R7H5APointer $bound.Session draft 'D-R7-F29' ([ordered]@{draft_id='D-R7-F29';draft_status='baseline_ready'}) draft_preserved;Write-R7H5APointer $bound.Session short_video_structure_plan 'STRUCT-R7-F29' ([ordered]@{structure_plan_id='STRUCT-R7-F29';plan_status='ready_with_warnings'}) structure_ready_with_warnings
  $preparedBound=Prepare-R7RuntimeTask $script:ProjectRoot $bound.Session;$boundPayload=($bundle.beat_map|ConvertTo-Json -Depth 60|ConvertFrom-Json);$boundPayload.beat_map_id='BEATMAP-R7-F29-002';$boundPayload.beat_map_revision=2;$boundPayload.draft_id='D-R7-F29';$boundPayload.mapping_phase='structure_bound';$boundPayload.structure_plan_ref.structure_plan_id='STRUCT-R7-F29'
  $boundPath=Join-Path $bound.Session 'intermediate/r7/producer-payloads/bound.json';Write-P0EvidenceAtomicText $boundPath (ConvertTo-P0EvidenceJsonText $boundPayload);$builtBound=New-R7RuntimeSubmissionFromPayload $script:ProjectRoot $bound.Session $preparedBound.Data.Task.task_envelope_id $boundPath beat_map_complete 1;$actual29=if($builtBound.ResultCode-eq'submission_built'-and[int](Read-R7JsonFile (Join-Path $bound.Session $builtBound.Data.SubmissionPath)).output_revision-eq2){'submission_revision_2'}else{[string]$builtBound.ResultCode};$results.Add((New-R7H5AResult 'R7-F29-BOUND-REVISION' submission_revision_2 $actual29 @($builtBound.Errors)))

  $mismatches=@($results|Where-Object{-not$_.expectation_met});$report=[ordered]@{r7_h5a_direct_sequence_report=[ordered]@{check_run_id='R7-H5A-'+(Get-Date -Format 'yyyyMMdd-HHmmss');overall_result=$(if($mismatches.Count){'fail'}else{'pass'});exit_code=$(if($mismatches.Count){1}else{0});fixture_count=$results.Count;mismatch_count=$mismatches.Count;not_tested_scope=[object[]]@('real_account','provider','network','publishing','hotspot_entry');checks=[object[]]$results.ToArray()}}
  Write-TaogeUtf8NoBomJson $machinePath $report 40;$lines=@('# R7-H5A Direct Sequence Check','',"overall_result: $($report.r7_h5a_direct_sequence_report.overall_result)",'','| Fixture | Expected | Actual | Matched | Errors |','|---|---|---|---:|---|');foreach($x in $results){$lines+="| $($x.fixture_id) | $($x.expected_result) | $($x.actual_result) | $($x.expectation_met) | $([string]::Join(';',@($x.errors))) |"};Write-TaogeUtf8NoBomLines $humanPath $lines
  if($mismatches.Count){Write-Output 'R7_H5A_DIRECT_SEQUENCE_RESULT=fail';foreach($x in $mismatches){Write-Output "R7_H5A_ERROR=$($x.fixture_id):$($x.actual_result):$([string]::Join(';',@($x.errors)))"};exit 1};Write-Output 'R7_H5A_DIRECT_SEQUENCE_RESULT=pass';Write-Output "R7_H5A_FIXTURE_COUNT=$($results.Count)";exit 0
}catch{Write-Error("{0} at line {1}: {2}"-f$_.Exception.Message,$_.InvocationInfo.ScriptLineNumber,$_.InvocationInfo.Line);exit 3}
