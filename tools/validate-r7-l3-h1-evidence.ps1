param([string]$ProjectRoot='',[string]$ReportPath='')
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($ProjectRoot)){$ProjectRoot=Split-Path -Parent $PSScriptRoot}
if([string]::IsNullOrWhiteSpace($ReportPath)){$ReportPath=Join-Path $ProjectRoot 'state/checks/r7-l3-h1-evidence-report.json'}
. (Join-Path $PSScriptRoot 'R7MaturityEvidence.ps1')

$results=[Collections.Generic.List[object]]::new()
function Add-CaseResult {param([string]$Id,[string]$Expected,[string]$Actual,[string]$Category='workflow_contract');$results.Add([pscustomobject][ordered]@{fixture_id=$Id;expected=$Expected;actual=$Actual;category=$Category;result=$(if($Expected-eq$Actual){'pass'}else{'fail'})})}
function Write-Json {param([string]$Path,[object]$Value);Write-TaogeUtf8NoBomJson -Path $Path -Value $Value -Depth 40}
function New-SnapshotFor {param([string]$SessionId,[string]$StartedAt,[string]$Path);New-R7RunCapabilitySnapshot $ProjectRoot $registryPath $baselinePath "snapshot-$SessionId" $SessionId $StartedAt $Path|Out-Null}
function New-Observation {
  param([string]$SessionId,[string]$StartedAt,[string]$Route='direct_delivery',[string]$BodyKey='body-a',[string]$EventKey='event-a',[string]$SourceKey='sources-a',[string]$DeliveryStatus='delivered',[string[]]$Coverage=@(),[string]$Mutation='none',[string[]]$Blockers=@())
  $identity=if($Route-eq'direct_delivery'){[pscustomobject][ordered]@{account_identity_digest='sha256:'+('a'*64);original_normalized_body_digest='sha256:'+(Get-R7MaturityHashText $BodyKey).Substring(7);intake_mode='user_supplied_draft'}}else{[pscustomobject][ordered]@{account_identity_digest='sha256:'+('a'*64);event_cluster_digest='sha256:'+(Get-R7MaturityHashText $EventKey).Substring(7);selected_source_set_digest='sha256:'+(Get-R7MaturityHashText $SourceKey).Substring(7)}}
  $steps=[Collections.Generic.List[object]]::new();$steps.Add([pscustomobject][ordered]@{step_id='semantic';step_kind='semantic';execution_source='skill_defined';capability_id='semantic_workflow_coordinator';status='succeeded';coverage_categories=[object[]]@()});$steps.Add([pscustomobject][ordered]@{step_id='candidate';step_kind='deterministic';execution_source='deterministic_runtime';capability_id='candidate_renderer_runtime';status='succeeded';coverage_categories=[object[]]$Coverage})
  if($Mutation-eq'unregistered_execution'){$steps.Add([pscustomobject][ordered]@{step_id='helper';step_kind='semantic';execution_source='agent_orchestrated';capability_id='run_specific_helper';status='succeeded';coverage_categories=@()})}
  $external=[Collections.Generic.List[object]]::new();if($Route-eq'hotspot_to_delivery'){$external.Add([pscustomobject][ordered]@{task_id='source-task';capability_id='source_capture_runtime';status='succeeded';attempt_refs=@('attempt-1');outcome_ref='outcome-1';output_ref='capture-1';reconcile_status='completed';coverage_categories=@('source_bound_evidence')})}
  if($Mutation-eq'external_missing'){$external.Add([pscustomobject][ordered]@{task_id='image-task';capability_id='codex_builtin_image2';status='succeeded';attempt_refs=@();outcome_ref='';output_ref='';reconcile_status='completed';coverage_categories=@('generated_context')})}
  $gates=[Collections.Generic.List[object]]::new();if($Route-eq'hotspot_to_delivery'){$gates.Add([pscustomobject][ordered]@{gate_id='topic';capability_id='topic_human_gate';status='completed';typed_decision_ref='topic-decision'})};$gates.Add([pscustomobject][ordered]@{gate_id='final';capability_id='final_human_gate';status='completed';typed_decision_ref=$(if($Mutation-eq'untyped_human'){''}else{'final-decision'})})
  $writes=[Collections.Generic.List[object]]::new();$writes.Add([pscustomobject][ordered]@{relative_path='intermediate/p0/final-candidate.json';writer_capability_id='candidate_renderer_runtime';registered_output=($Mutation-ne'producer_bypass');sha256='sha256:'+('b'*64)});$writes.Add([pscustomobject][ordered]@{relative_path='deliverables/final-delivery.html';writer_capability_id='candidate_renderer_runtime';registered_output=$true;sha256='sha256:'+('c'*64)})
  return [pscustomobject][ordered]@{schema_id='taoge://schemas/r7/autonomy-run-observation/v0.1';schema_version='0.1';observation_id="observation-$SessionId";session_id=$SessionId;entry_route=$Route;maturity_baseline_digest=[string]$baseline.maturity_baseline_digest;run_started_at=$StartedAt;input_identity=$identity;expected_step_ids=@('semantic','candidate');step_executions=[object[]]$steps.ToArray();artifact_commits=@([pscustomobject][ordered]@{artifact_id='candidate';producer_capability_id='candidate_renderer_runtime';receipt_ref='receipt-1';event_ref='event-1';sha256='sha256:'+('b'*64)});external_tasks=[object[]]$external.ToArray();human_gates=[object[]]$gates.ToArray();file_writes=[object[]]$writes.ToArray();final_delivery=[pscustomobject][ordered]@{status=$DeliveryStatus;ref=$(if($DeliveryStatus-eq'delivered'){'deliverables/final-delivery.html'}else{''});waiting_reason=$(if($DeliveryStatus-eq'waiting'){'waiting_capability'}else{''})};manual_intervention_declarations=@();current_contract_blockers=[object[]]$Blockers}
}
function Invoke-Observation {
  param([object]$Observation)
  $id=[string]$Observation.session_id;$snapshot=Join-Path $work "$id.snapshot.json";$input=Join-Path $work "$id.observation.json";$ledger=Join-Path $work "$id.ledger.json";$evidence=Join-Path $work "$id.evidence.json"
  New-SnapshotFor $id ([string]$Observation.run_started_at) $snapshot;Write-Json $input $Observation;Invoke-R7SessionAutonomyEvaluation $input $snapshot $ledger $evidence|Out-Null;return $evidence
}

$work=Join-Path $ProjectRoot 'state/checks/r7-l3-h1-fixture-work';$resolvedRoot=[IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\');$resolvedWork=[IO.Path]::GetFullPath($work)
if(-not$resolvedWork.StartsWith($resolvedRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'fixture_work_outside_project'}
if(Test-Path -LiteralPath $resolvedWork){Remove-Item -LiteralPath $resolvedWork -Recurse -Force};New-Item -ItemType Directory -Path $resolvedWork -Force|Out-Null
$work=$resolvedWork;$registryPath=Join-Path $ProjectRoot 'routes/r7-runtime-capability-registry.json';$baselinePath=Join-Path $work 'baseline.json'

try{
  $catalog=Read-R7MaturityJson (Join-Path $ProjectRoot 'examples/r7-l3-h1-evidence-fixtures/fixture-catalog.json');Add-CaseResult 'catalog_count' '16' ([string]@($catalog.fixtures).Count) 'fixture_contract'
  $schemaIds=@('maturity-baseline','run-capability-snapshot','autonomy-run-observation','intervention-ledger','session-autonomy-evidence','autonomy-certification-cohort','route-autonomy-evidence','project-maturity-evidence')
  $schemaPass=$true;foreach($id in $schemaIds){$schema=Read-R7MaturityJson (Join-Path $ProjectRoot "templates/schema/r7/$id.v0.1.schema.json");if([string]::IsNullOrWhiteSpace([string]$schema.'$id')){$schemaPass=$false}};Add-CaseResult 'schema_bundle' 'pass' $(if($schemaPass){'pass'}else{'fail'}) 'schema_contract'
  $cli=Join-Path $ProjectRoot 'tools/invoke-r7-maturity-evidence.ps1';$cliOutput=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $cli -Mode new_baseline -ProjectRoot $ProjectRoot -RegistryPath $registryPath -BaselineId 'R7L3H1-BASELINE' -Timestamp '2026-07-16T09:00:00+08:00' -OutputPath $baselinePath 2>&1);$cliExit=$LASTEXITCODE
  if($cliExit-ne0){throw "baseline_cli_failed:${cliExit}:$([string]::Join(';',@($cliOutput)))"};$baseline=Read-R7MaturityJson $baselinePath;if(@($baseline.contract_surfaces).Count-ne4){throw 'baseline_contract_surface_count_invalid'};Add-CaseResult 'baseline_capabilities' '14' ([string]@($baseline.capabilities).Count) 'capability_contract'

  $d1=Invoke-Observation (New-Observation 'D-001' '2026-07-16T09:01:00+08:00' -Coverage @('generated_context','deterministic_postprocess','explicit_existing_asset'))
  Add-CaseResult 'R7L3H1-F01' 'autonomous_delivery' ([string](Read-R7MaturityJson $d1).outcome)
  $waiting=Invoke-Observation (New-Observation 'D-WAIT' '2026-07-16T09:02:00+08:00' -BodyKey 'wait' -DeliveryStatus 'waiting')
  Add-CaseResult 'R7L3H1-F02' 'autonomous_waiting' ([string](Read-R7MaturityJson $waiting).outcome)
  $assisted=Invoke-Observation (New-Observation 'D-ASST' '2026-07-16T09:03:00+08:00' -BodyKey 'assist' -Mutation 'unregistered_execution')
  Add-CaseResult 'R7L3H1-F03' 'assisted_delivery' ([string](Read-R7MaturityJson $assisted).outcome)
  $bypass=Invoke-Observation (New-Observation 'D-BYPASS' '2026-07-16T09:04:00+08:00' -BodyKey 'bypass' -Mutation 'producer_bypass')
  Add-CaseResult 'R7L3H1-F04' 'assisted_delivery' ([string](Read-R7MaturityJson $bypass).outcome)
  $external=Invoke-Observation (New-Observation 'D-EXT' '2026-07-16T09:05:00+08:00' -BodyKey 'external' -Mutation 'external_missing')
  Add-CaseResult 'R7L3H1-F05' 'assisted_delivery' ([string](Read-R7MaturityJson $external).outcome)
  $human=Invoke-Observation (New-Observation 'D-HUMAN' '2026-07-16T09:06:00+08:00' -BodyKey 'human' -Mutation 'untyped_human')
  Add-CaseResult 'R7L3H1-F06' 'assisted_delivery' ([string](Read-R7MaturityJson $human).outcome)

  $d2=Invoke-Observation (New-Observation 'D-002' '2026-07-16T09:07:00+08:00' -BodyKey 'body-b' -Coverage @('revision_resume'))
  $h1=Invoke-Observation (New-Observation 'H-001' '2026-07-16T09:08:00+08:00' -Route 'hotspot_to_delivery' -EventKey 'event-a' -SourceKey 'sources-a')
  $h2=Invoke-Observation (New-Observation 'H-002' '2026-07-16T09:09:00+08:00' -Route 'hotspot_to_delivery' -EventKey 'event-b' -SourceKey 'sources-b')
  $cohortPath=Join-Path $work 'cohort.json';New-R7AutonomyCertificationCohort 'COHORT-FULL' ([string]$baseline.maturity_baseline_digest) '2026-07-16T09:00:30+08:00' $cohortPath|Out-Null
  foreach($evidence in @($d1,$waiting,$d2,$h1,$h2)){Add-R7SessionEvidenceToCohort $cohortPath $evidence|Out-Null}
  $directPath=Join-Path $work 'direct.route.json';$hotspotPath=Join-Path $work 'hotspot.route.json';$direct=Get-R7RouteAutonomyEvidence $cohortPath 'direct_delivery' $directPath;$hotspot=Get-R7RouteAutonomyEvidence $cohortPath 'hotspot_to_delivery' $hotspotPath
  Add-CaseResult 'R7L3H1-F07' 'l3' ([string]$direct.route_status);Add-CaseResult 'R7L3H1-F10' 'l3' ([string]$hotspot.route_status)

  $samePath=Join-Path $work 'same.cohort.json';New-R7AutonomyCertificationCohort 'COHORT-SAME' ([string]$baseline.maturity_baseline_digest) '2026-07-16T09:00:30+08:00' $samePath|Out-Null;$same1=Invoke-Observation (New-Observation 'SAME-1' '2026-07-16T09:10:00+08:00' -BodyKey 'same');$same2=Invoke-Observation (New-Observation 'SAME-2' '2026-07-16T09:11:00+08:00' -BodyKey 'same');Add-R7SessionEvidenceToCohort $samePath $same1|Out-Null;Add-R7SessionEvidenceToCohort $samePath $same2|Out-Null;$sameRoute=Get-R7RouteAutonomyEvidence $samePath 'direct_delivery' (Join-Path $work 'same.route.json');Add-CaseResult 'R7L3H1-F08' 'candidate' ([string]$sameRoute.route_status)

  $resetAssist=Invoke-Observation (New-Observation 'RESET-ASST' '2026-07-16T09:12:00+08:00' -BodyKey 'reset-assist' -Mutation 'unregistered_execution');$resetAfter=Invoke-Observation (New-Observation 'RESET-AFTER' '2026-07-16T09:13:00+08:00' -BodyKey 'reset-after')
  $resetPath=Join-Path $work 'reset.cohort.json';New-R7AutonomyCertificationCohort 'COHORT-RESET' ([string]$baseline.maturity_baseline_digest) '2026-07-16T09:00:30+08:00' $resetPath|Out-Null;foreach($evidence in @($d1,$d2,$resetAssist,$resetAfter)){Add-R7SessionEvidenceToCohort $resetPath $evidence|Out-Null};$resetRoute=Get-R7RouteAutonomyEvidence $resetPath 'direct_delivery' (Join-Path $work 'reset.route.json');Add-CaseResult 'R7L3H1-F09' 'candidate' ([string]$resetRoute.route_status)

  $driftRegistry=Read-R7MaturityJson $registryPath;@($driftRegistry.capabilities|Where-Object{$_.capability_id-eq'codex_builtin_image2'})[0].version='provider_identity_changed';$driftRegistryPath=Join-Path $work 'drift-registry.json';Write-Json $driftRegistryPath $driftRegistry;$actual='not_rejected';try{New-R7RunCapabilitySnapshot $ProjectRoot $driftRegistryPath $baselinePath 'snapshot-drift' 'DRIFT' '2026-07-16T09:14:00+08:00' (Join-Path $work 'drift.snapshot.json')|Out-Null}catch{$actual=$_.Exception.Message};Add-CaseResult 'R7L3H1-F11' 'maturity_baseline_changed' $actual
  $badBaseline=Read-R7MaturityJson $d1;$badBaseline.maturity_baseline_digest='sha256:'+('f'*64);$badPath=Join-Path $work 'bad-baseline.evidence.json';Write-Json $badPath $badBaseline;$cohortMismatch='not_rejected';try{Add-R7SessionEvidenceToCohort $cohortPath $badPath|Out-Null}catch{$cohortMismatch=$_.Exception.Message};if($cohortMismatch-ne'cohort_baseline_mismatch'){throw "cohort_baseline_guard_failed:${cohortMismatch}"}
  $duplicate=Add-R7SessionEvidenceToCohort $cohortPath $d1;Add-CaseResult 'R7L3H1-F12' 'duplicate_reused' ([string]$duplicate.result_code)

  $incomplete=Read-R7MaturityJson $cohortPath;$incomplete.capability_coverage=@();$incompletePath=Join-Path $work 'incomplete.cohort.json';Write-Json $incompletePath $incomplete;$incompleteProject=Get-R7ProjectMaturityEvidence $incompletePath $directPath $hotspotPath (Join-Path $work 'incomplete.project.json');Add-CaseResult 'R7L3H1-F13' 'l3_candidate' ([string]$incompleteProject.project_status)
  $project=Get-R7ProjectMaturityEvidence $cohortPath $directPath $hotspotPath (Join-Path $work 'project.json');Add-CaseResult 'R7L3H1-F14' 'l3' ([string]$project.project_status)
  $blocked=Read-R7MaturityJson $cohortPath;$blocked.current_contract_blockers=@('current_contract_blocker');$blockedPath=Join-Path $work 'blocked.cohort.json';Write-Json $blockedPath $blocked;$blockedProject=Get-R7ProjectMaturityEvidence $blockedPath $directPath $hotspotPath (Join-Path $work 'blocked.project.json');Add-CaseResult 'R7L3H1-F15' 'l3_candidate' ([string]$blockedProject.project_status)
  $invalid='not_rejected';try{New-SnapshotFor 'INVALID-TIME' '2026-07-16 09:00:00' (Join-Path $work 'invalid.snapshot.json')}catch{$invalid=$_.Exception.Message};Add-CaseResult 'R7L3H1-F16' 'run_started_at_invalid' $invalid

  $instancePairs=@(
    @('maturity-baseline','baseline.json'),@('run-capability-snapshot','D-001.snapshot.json'),@('autonomy-run-observation','D-001.observation.json'),@('intervention-ledger','D-001.ledger.json'),
    @('session-autonomy-evidence','D-001.evidence.json'),@('autonomy-certification-cohort','cohort.json'),@('route-autonomy-evidence','direct.route.json'),@('project-maturity-evidence','project.json')
  )
  foreach($pair in $instancePairs){$errors=@(Test-R7MaturitySchemaInstance (Join-Path $ProjectRoot "templates/schema/r7/$($pair[0]).v0.1.schema.json") (Join-Path $work $pair[1]));if($errors.Count){throw "schema_instance_invalid:$($pair[1]):$([string]::Join('|',$errors))"}}

  $failed=@($results|Where-Object{$_.result-ne'pass'});$report=[pscustomobject][ordered]@{schema_id='taoge://reports/r7/l3-h1-evidence/v0.1';schema_version='0.1';overall_result=$(if($failed.Count){'fail'}else{'pass'});fixture_count=@($catalog.fixtures).Count;check_count=$results.Count;failed_count=$failed.Count;results=[object[]]$results.ToArray();scope=@('offline','no_provider_call','no_network','no_private_accounts','no_publish')};Write-Json $ReportPath $report
  if($failed.Count){$failed|Format-Table -AutoSize|Out-String|Write-Host;exit 1};"PASS R7-L3-H1 evidence: $($results.Count) checks";exit 0
}catch{[Console]::Error.WriteLine($_.Exception.ToString());exit 3}
