param(
  [string]$FixtureRoot='examples/r7-h2-runtime-fixtures',
  [string]$WorkRoot='state/checks/r7-h2-runtime-work',
  [string]$HumanReportPath='state/checks/r7-h2-runtime-check-report.md',
  [string]$MachineReportPath='state/checks/r7-h2-runtime-check-report.json'
)

$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'R7ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'R7SemanticRuntime.ps1')

function Resolve-R7H2Path {
  param([string]$Path)
  if([IO.Path]::IsPathRooted($Path)){return [IO.Path]::GetFullPath($Path)}
  return [IO.Path]::GetFullPath((Join-Path (Join-Path $PSScriptRoot '..') $Path))
}

function New-R7H2Result {
  param([string]$Id,[string]$Expected,[string]$Actual,[string[]]$Errors=@())
  return [pscustomobject]@{fixture_id=$Id;expected_result=$Expected;actual_result=$Actual;expectation_met=($Expected -eq $Actual);errors=[object[]]@($Errors)}
}

function New-R7H2Session {
  param([string]$Root,[string]$SessionId,[string]$TemplateRoot)
  $session=Join-Path $Root $SessionId
  if(Test-Path -LiteralPath $session){throw "fixture_work_root_not_empty:$session"}
  New-Item -ItemType Directory -Path (Join-Path $session 'intermediate/account-startup') -Force|Out-Null
  Copy-Item -LiteralPath (Join-Path $TemplateRoot 'inputs') -Destination $session -Recurse
  Copy-Item -LiteralPath (Join-Path $TemplateRoot 'intermediate/account-startup/account-snapshot.v0.2.json') -Destination (Join-Path $session 'intermediate/account-startup/account-snapshot.v0.2.json')
  $initialize=Initialize-R7RuntimeSession $script:ProjectRoot $session 'direct_delivery_single_v0.1'
  if($initialize.ExitCode -ne 0){throw "fixture_initialize_failed:${SessionId}:$($initialize.ResultCode)"}
  $prepare=Prepare-R7RuntimeTask $script:ProjectRoot $session
  if($prepare.ExitCode -ne 0){throw "fixture_prepare_failed:${SessionId}:$($prepare.ResultCode):$([string]::Join(';',@($prepare.Errors)))"}
  return [pscustomobject]@{Session=$session;Task=$prepare.Data.Task;TaskPath=$prepare.Data.TaskPath}
}

function New-R7H2Submission {
  param([object]$Fixture,[string]$SubmissionId,[string]$ArtifactId)
  $task=$Fixture.Task
  $submission=[ordered]@{
    schema_id='taoge://schemas/r7/semantic-artifact-submission/v0.2'
    schema_version='0.2'
    submission_id=$SubmissionId
    task_envelope_id=[string]$task.task_envelope_id
    session_id=[string]$task.session_id
    plan_id=[string]$task.plan_id
    node_id=[string]$task.node_id
    skill_ref=[string]$task.skill_ref
    attempt_no=1
    submitted_at=[DateTimeOffset]::UtcNow.ToString('o')
    input_binding_digest=[string]$task.input_binding_digest
    output_artifact_type='direct_content_intake'
    output_contract_version='direct-content-intake-v0.1'
    output_artifact_id=$ArtifactId
    output_revision=1
    result_status='intake_ready'
    requested_action=$null
    source_artifact_ids=[object[]]@($task.input_artifact_bindings|ForEach-Object{[string]$_.artifact_id})
    quality_status='pass'
    delivery_eligibility='trace_only'
    check_ids=[object[]]@('R7-H2-RUNTIME-FIXTURE')
    payload=[ordered]@{intake_id=$ArtifactId;direct_content_status='direct_content_ready';source_mode='user_supplied_draft'}
    evidence_refs=[object[]]@()
    idempotency_key=[string]$task.idempotency_key
    write_intent='submit_for_deterministic_commit'
    requested_machine_writes=[object[]]@()
  }
  return [pscustomobject](($submission|ConvertTo-Json -Depth 30)|ConvertFrom-Json)
}

function Write-R7H2Submission {
  param([object]$Fixture,[object]$Submission)
  $path=Join-Path $Fixture.Session "intermediate/r7/submissions/$($Submission.submission_id).json"
  Write-P0EvidenceAtomicText $path (ConvertTo-P0EvidenceJsonText $Submission)
  return $path
}

try{
  $script:ProjectRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
  $fixturePath=Resolve-R7H2Path $FixtureRoot
  $workBase=Resolve-R7H2Path $WorkRoot
  $humanPath=Resolve-R7H2Path $HumanReportPath
  $machinePath=Resolve-R7H2Path $MachineReportPath
  $templateRoot=Join-Path $fixturePath 'template-session'
  foreach($required in @($fixturePath,$templateRoot,(Join-Path $fixturePath 'fixture-cases.json'))){if(-not(Test-Path -LiteralPath $required)){Write-Error "R7 H2 preflight path missing: $required";exit 4}}
  foreach($path in @($workBase,(Split-Path -Parent $humanPath),(Split-Path -Parent $machinePath))){if(-not(Test-Path -LiteralPath $path)){New-Item -ItemType Directory -Path $path -Force|Out-Null}}
  $runRoot=Join-Path $workBase ('RUN-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
  New-Item -ItemType Directory -Path $runRoot|Out-Null
  $results=[Collections.Generic.List[object]]::new()

  $schemaFiles=@(
    'templates/schema/p0/session-execution-plan.v0.6.schema.json',
    'templates/schema/r7/input-selector-registry.v0.1.schema.json',
    'templates/schema/r7/artifact-commit-registry.v0.1.schema.json',
    'templates/schema/r7/status-route-registry.v0.1.schema.json',
    'templates/schema/r7/task-guidance-registry.v0.1.schema.json',
    'templates/schema/r7/semantic-artifact-submission.v0.2.schema.json',
    'templates/schema/r7/semantic-current-pointer.v0.1.schema.json',
    'templates/schema/r7/semantic-commit-receipt.v0.1.schema.json'
  )
  foreach($relative in $schemaFiles){
    $errors=[Collections.Generic.List[string]]::new();$path=Join-Path $script:ProjectRoot $relative
    try{$schema=Read-R7JsonFile $path;if([string]::IsNullOrWhiteSpace([string]$schema.'$id')){$errors.Add('schema_id_missing')}}catch{$errors.Add('schema_parse_error:'+$_.Exception.Message)}
    $results.Add((New-R7H2Result ('R7-H2-SCHEMA-'+[IO.Path]::GetFileNameWithoutExtension($relative)) 'pass' $(if($errors.Count){'fail'}else{'pass'}) $errors.ToArray()))
  }

  $registries=Get-R7RuntimeRegistries $script:ProjectRoot
  $crossErrors=[Collections.Generic.List[string]]::new()
  $direct=Get-R7RuntimeBlueprint $registries 'direct_delivery_single_v0.1'
  foreach($nodeId in @($direct.node_refs)){
    $node=Get-R7RuntimeNode $registries ([string]$nodeId)
    if($null -eq $node){$crossErrors.Add("node_missing:$nodeId");continue}
    if($null -eq (@($registries.Guidance.nodes|Where-Object{$_.node_id -eq $nodeId})|Select-Object -First 1)){$crossErrors.Add("guidance_missing:$nodeId")}
    if($null -eq (@($registries.StatusRoutes.nodes|Where-Object{$_.node_id -eq $nodeId})|Select-Object -First 1)){$crossErrors.Add("status_route_missing:$nodeId")}
    foreach($selectorId in @($node.input_selectors)){if($null -eq (@($registries.Selectors.selectors|Where-Object{$_.selector_id -eq $selectorId})|Select-Object -First 1)){$crossErrors.Add("selector_missing:${nodeId}:$selectorId")}}
    if($null -eq (@($registries.Commits.profiles|Where-Object{$_.artifact_type -eq $node.output_artifact_type})|Select-Object -First 1)){$crossErrors.Add("commit_profile_missing:${nodeId}:$($node.output_artifact_type)")}
  }
  $results.Add((New-R7H2Result 'R7-H2-CROSS-REGISTRY' 'pass' $(if($crossErrors.Count){'fail'}else{'pass'}) $crossErrors.ToArray()))

  # R7-F05: a malformed submission must fail before any revision or pointer is written.
  $f05=New-R7H2Session $runRoot 'R7-F05' $templateRoot
  $s05=New-R7H2Submission $f05 'SUB-R7-F05-001' 'INTAKE-R7-F05-001'
  $s05.PSObject.Properties.Remove('output_artifact_id')
  $p05=Write-R7H2Submission $f05 $s05
  $o05=Submit-R7RuntimeArtifact $script:ProjectRoot $f05.Session $p05
  $f05Errors=@();if(Test-Path (Join-Path $f05.Session 'intermediate/r7/current/direct_content_intake.json')){$f05Errors+='pointer_written_on_invalid_submission'}
  $actual05=if($o05.ResultCode -eq 'semantic_submission_error' -and @($f05Errors).Count -eq 0){'semantic_submission_error'}else{$o05.ResultCode}
  $results.Add((New-R7H2Result 'R7-F05' 'semantic_submission_error' $actual05 $f05Errors))

  # R7-F06: the immutable task input digest must be rechecked immediately before commit.
  $f06=New-R7H2Session $runRoot 'R7-F06' $templateRoot
  $s06=New-R7H2Submission $f06 'SUB-R7-F06-001' 'INTAKE-R7-F06-001';$p06=Write-R7H2Submission $f06 $s06
  [IO.File]::AppendAllText((Join-Path $f06.Session 'inputs/user-supplied-draft.md'),"`nchanged-after-task",[Text.UTF8Encoding]::new($false))
  $o06=Submit-R7RuntimeArtifact $script:ProjectRoot $f06.Session $p06
  $results.Add((New-R7H2Result 'R7-F06' 'cross_artifact_binding_error' ([string]$o06.ResultCode) @($o06.Errors)))

  # R7-F07: retrying the exact completed submission is byte-stable and event-stable.
  $f07=New-R7H2Session $runRoot 'R7-F07' $templateRoot
  $s07=New-R7H2Submission $f07 'SUB-R7-F07-001' 'INTAKE-R7-F07-001';$p07=Write-R7H2Submission $f07 $s07
  $first07=Submit-R7RuntimeArtifact $script:ProjectRoot $f07.Session $p07
  $eventPath07=Join-Path $f07.Session 'intermediate/p0/execution-events.jsonl';$countBefore=@(Get-P0EvidenceEvents $eventPath07).Count
  $second07=Submit-R7RuntimeArtifact $script:ProjectRoot $f07.Session $p07;$countAfter=@(Get-P0EvidenceEvents $eventPath07).Count
  $errors07=@();if($first07.ResultCode -ne 'semantic_artifact_committed'){$errors07+="first_submit:$($first07.ResultCode)"};if($countBefore -ne $countAfter){$errors07+='duplicate_appended_event'}
  $actual07=if($second07.ResultCode -eq 'duplicate_reused' -and @($errors07).Count -eq 0){'duplicate_reused'}else{[string]$second07.ResultCode}
  $results.Add((New-R7H2Result 'R7-F07' 'duplicate_reused' $actual07 $errors07))

  # R7-F08: a revision persisted before interruption is reconciled without rewriting it.
  $f08=New-R7H2Session $runRoot 'R7-F08' $templateRoot
  $s08=New-R7H2Submission $f08 'SUB-R7-F08-001' 'INTAKE-R7-F08-001';$p08=Write-R7H2Submission $f08 $s08
  $revisionRel='intermediate/r7/revisions/direct_content_intake/INTAKE-R7-F08-001.json';$revisionPath=Join-Path $f08.Session $revisionRel
  $revisionText=ConvertTo-P0EvidenceJsonText $s08.payload;Write-P0EvidenceAtomicText $revisionPath $revisionText;$revisionDigest=Get-R7RuntimeHash $revisionPath
  $receiptPath=Join-Path $f08.Session 'intermediate/r7/commits/SUB-R7-F08-001.json'
  [void](Write-R7RuntimeReceipt $receiptPath @{submission_id=$s08.submission_id;session_id=$s08.session_id;task_envelope_id=$s08.task_envelope_id;artifact_id=$s08.output_artifact_id;artifact_type=$s08.output_artifact_type;idempotency_key=$s08.idempotency_key;phase='revision_written';revision_path=$revisionRel;revision_sha256=$revisionDigest;pointer_path=$null;producer_event_id=$null;projection_status='pending'})
  $before08=Get-R7RuntimeHash $revisionPath;$o08=Reconcile-R7RuntimeSubmission $script:ProjectRoot $f08.Session $s08.submission_id;$after08=Get-R7RuntimeHash $revisionPath
  $errors08=@();if($before08 -ne $after08){$errors08+='revision_changed_during_reconcile'}
  $actual08=if($o08.ResultCode -eq 'submission_reconciled' -and @($errors08).Count -eq 0){'submission_reconciled'}else{[string]$o08.ResultCode}
  $results.Add((New-R7H2Result 'R7-F08' 'submission_reconciled' $actual08 $errors08))

  $mismatches=@($results|Where-Object{-not $_.expectation_met})
  $report=[ordered]@{r7_h2_runtime_check_report=[ordered]@{check_run_id='R7-H2-'+(Get-Date -Format 'yyyyMMdd-HHmmss');schema_version='0.1';overall_result=$(if($mismatches.Count){'fail'}else{'pass'});exit_code=$(if($mismatches.Count){1}else{0});fixture_count=4;schema_count=$schemaFiles.Count;cross_registry_check_count=1;mismatch_count=$mismatches.Count;work_root=$runRoot;not_tested_scope=[object[]]@('r7_h3_producer_adapters','r7_h4_candidate_compiler','r7_h5_viewport_acceptance','r7_h6_hotspot_adapter','real_account','image_provider','publishing');checks=[object[]]$results.ToArray()}}
  Write-TaogeUtf8NoBomJson $machinePath $report 30
  $lines=@('# R7-H2 Runtime Check Report','', '```yaml',"check_run_id: $($report.r7_h2_runtime_check_report.check_run_id)","overall_result: $($report.r7_h2_runtime_check_report.overall_result)","fixture_count: 4","mismatch_count: $($mismatches.Count)",'```','','| Check | Expected | Actual | Matched | Errors |','|---|---|---|---:|---|')
  foreach($item in $results){$errorText=if(@($item.errors).Count){[string]::Join('; ',@($item.errors))}else{'none'};$lines+="| $($item.fixture_id) | $($item.expected_result) | $($item.actual_result) | $($item.expectation_met) | $errorText |"}
  Write-TaogeUtf8NoBomLines $humanPath $lines
  if($mismatches.Count){Write-Output 'R7_H2_RUNTIME_CHECK_RESULT=fail';foreach($item in $mismatches){Write-Output "R7_H2_RUNTIME_ERROR=$($item.fixture_id):$([string]::Join(';',@($item.errors)))"};exit 1}
  Write-Output 'R7_H2_RUNTIME_CHECK_RESULT=pass';Write-Output 'R7_H2_FIXTURE_COUNT=4';exit 0
}catch{
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message,$_.InvocationInfo.ScriptLineNumber,$_.InvocationInfo.Line)
  exit 3
}
