[CmdletBinding()]
param(
  [string]$ProjectRoot = '',
  [ValidateSet('CompileSmoke','Certification')][string]$Mode = 'CompileSmoke',
  [string]$SourceRevision = '',
  [string]$EvaluatorReportPath = '',
  [string]$RuntimeReportPath = '',
  [string]$WorkRoot = '',
  [string]$ReportPath = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
} else {
  $ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
}
. (Join-Path $PSScriptRoot 'M6CertificationRuntime.ps1')
. (Join-Path $PSScriptRoot 'M6DirectCertificationRuntime.ps1')
Initialize-M6CertificationRuntime -ProjectRoot $ProjectRoot
Initialize-M6DirectCertificationRuntime -ProjectRoot $ProjectRoot

$checksRoot = [IO.Path]::GetFullPath((Join-Path $ProjectRoot 'state/checks')).TrimEnd('\','/')
$checksPrefix = $checksRoot + [IO.Path]::DirectorySeparatorChar
if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
  $WorkRoot = Join-Path $checksRoot 'm6/dc-work'
}
$WorkRoot = [IO.Path]::GetFullPath($WorkRoot).TrimEnd('\','/')
if ($WorkRoot -eq $checksRoot -or -not $WorkRoot.StartsWith($checksPrefix,[StringComparison]::OrdinalIgnoreCase)) {
  throw 'm6_direct_certification_work_root_invalid'
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = Join-Path $checksRoot 'm6/direct-certification-report.json'
}
$ReportPath = Assert-M6CheckOutputPath $ReportPath

$modeValue = if ($Mode -eq 'Certification') { 'certification' } else { 'compile_smoke' }
if ($Mode -eq 'Certification') {
  if ($SourceRevision -notmatch '^[0-9a-f]{40}$') { throw 'm6_direct_certification_requires_full_source_revision' }
  $headResult = Invoke-TaogeProcessCapture -FilePath 'git' -Arguments @('rev-parse','HEAD') -WorkingDirectory $ProjectRoot
  if ($headResult.exit_code -ne 0 -or $headResult.stdout.Trim().ToLowerInvariant() -ne $SourceRevision.ToLowerInvariant()) {
    throw 'm6_direct_certification_source_revision_not_head'
  }
  $statusResult = Invoke-TaogeProcessCapture -FilePath 'git' -Arguments @('status','--porcelain','--untracked-files=no') -WorkingDirectory $ProjectRoot
  if ($statusResult.exit_code -ne 0 -or -not [string]::IsNullOrWhiteSpace($statusResult.stdout)) {
    throw 'm6_direct_certification_requires_clean_tracked_worktree'
  }
  if ([string]::IsNullOrWhiteSpace($EvaluatorReportPath) -or [string]::IsNullOrWhiteSpace($RuntimeReportPath)) {
    throw 'm6_direct_certification_requires_prerequisite_reports'
  }
} elseif ([string]::IsNullOrWhiteSpace($SourceRevision)) {
  $SourceRevision = 'git_worktree_pending_commit'
}

if (Test-Path -LiteralPath $WorkRoot) {
  $resolved = [IO.Path]::GetFullPath($WorkRoot)
  if (-not $resolved.StartsWith($checksPrefix,[StringComparison]::OrdinalIgnoreCase)) {
    throw 'm6_direct_certification_cleanup_root_escape'
  }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null

function Add-M6DirectAssertion {
  param([Collections.Generic.List[object]]$List,[string]$Id,[bool]$Passed,[string]$Detail)
  $List.Add([pscustomobject][ordered]@{check_id=$Id;passed=$Passed;detail=$Detail})
}

function Get-M6DirectFailureCode {
  param([scriptblock]$Action)
  try { & $Action | Out-Null; return 'no_failure' } catch { return [string]$_.Exception.Message }
}

function Test-M6DirectPrerequisiteObjects {
  param([object]$Evaluator,[object]$Runtime,[string]$ExpectedSourceRevision,[string]$ExpectedFreeze)
  if ([string]$Evaluator.result -ne 'pass' -or [string]$Evaluator.certification_status -ne 'certified' -or
      [string]$Runtime.result -ne 'pass' -or [string]$Runtime.certification_status -ne 'certified') {
    return [pscustomobject]@{result='fail';fingerprint='direct_prerequisite_not_certified'}
  }
  if ([string]$Evaluator.source_revision -ne $ExpectedSourceRevision -or [string]$Runtime.source_revision -ne $ExpectedSourceRevision) {
    return [pscustomobject]@{result='fail';fingerprint='direct_prerequisite_source_revision_mismatch'}
  }
  if ([string]$Evaluator.freeze_before_sha256 -ne $ExpectedFreeze -or
      [string]$Evaluator.freeze_after_sha256 -ne $ExpectedFreeze -or
      [string]$Runtime.freeze_before_sha256 -ne $ExpectedFreeze -or
      [string]$Runtime.freeze_after_sha256 -ne $ExpectedFreeze) {
    return [pscustomobject]@{result='fail';fingerprint='direct_prerequisite_digest_mismatch'}
  }
  [pscustomobject]@{result='pass';fingerprint=''}
}

$freezeBefore = New-M6CertificationFreeze -SourceRevision $SourceRevision -GeneratedAt '2026-07-18T16:00:00+08:00' -FreezeId 'M6-FREEZE-DIRECT-001'
$freezeBeforePath = Write-M6CertificationFreeze -Path (Join-Path $WorkRoot 'freeze-before.json') -Manifest $freezeBefore
$fixtureRoot = Join-Path $ProjectRoot 'examples/m6-direct-certification-fixtures'
$requestPath = Join-Path $WorkRoot 'fixture/direct-certification-request.json'
$requestBundle = New-M6DirectCertificationRequest -SourceRevision $SourceRevision -SessionId 'M6-DIRECT-CERT-SESSION-001' -OutputPath $requestPath
$request = $requestBundle.request
$sessionRoot = Join-Path (Join-Path $WorkRoot 'sessions') ([string]$request.session_id)
New-Item -ItemType Directory -Path $sessionRoot -Force | Out-Null

$entryPath = Join-Path $PSScriptRoot 'invoke-workflow-session-entry.ps1'
$powershellPath = (Get-Command powershell.exe -ErrorAction Stop).Source
$entryResult = Invoke-TaogeProcessCapture -FilePath $powershellPath -Arguments @(
  '-NoProfile','-ExecutionPolicy','Bypass','-File',$entryPath,
  '-Mode','start',
  '-SessionRoot',$sessionRoot,
  '-SessionId',[string]$request.session_id,
  '-RouteId','direct',
  '-RequestedAt',[string]$request.initialized_at,
  '-ProjectRoot',$ProjectRoot,
  '-FixtureMode'
) -WorkingDirectory $ProjectRoot
if ($entryResult.exit_code -ne 0) { throw "m6_direct_session_entry_failed:$($entryResult.stderr.Trim())" }
$entry = $entryResult.stdout | ConvertFrom-Json
if (-not [bool]$entry.success) { throw 'm6_direct_session_entry_not_success' }
$binding = Test-M6DirectSessionBinding -SessionRoot $sessionRoot -SessionId ([string]$request.session_id)

$assertions = [Collections.Generic.List[object]]::new()
Add-M6DirectAssertion $assertions 'M6-DIRECT-A01' ([string]$entry.code -eq 'session_generation_bound') ([string]$entry.code)
Add-M6DirectAssertion $assertions 'M6-DIRECT-A02' ([string]$binding.runtime_generation -eq 'kernel_v1_current') ([string]$binding.runtime_generation)
Add-M6DirectAssertion $assertions 'M6-DIRECT-A03' (@($request.component_results).Count -eq 25) ('component_count=' + @($request.component_results).Count)
$kinds = @($request.component_results | ForEach-Object { [string]$_.component_kind } | Sort-Object -Unique)
$requiredKinds = @($requestBundle.expected.required_component_kinds)
Add-M6DirectAssertion $assertions 'M6-DIRECT-A04' (@($requiredKinds | Where-Object { $kinds -notcontains $_ }).Count -eq 0) ('kinds=' + ($kinds -join ','))

$advance = Invoke-M6DirectAdvance -SessionRoot $sessionRoot -RequestPath $requestPath -FixtureRoot $fixtureRoot
Add-M6DirectAssertion $assertions 'M6-DIRECT-A05' ([string]$advance.status -eq 'waiting_human') ([string]$advance.status)
Add-M6DirectAssertion $assertions 'M6-DIRECT-A06' ([int]$advance.event_count -eq [int]$requestBundle.expected.event_count_after_advance) ('event_count=' + $advance.event_count)
Add-M6DirectAssertion $assertions 'M6-DIRECT-A07' ([int]$advance.artifact_count -eq 23) ('artifact_count=' + $advance.artifact_count)
$writerAfterAdvance = Test-M6DirectRegisteredWriters $advance.execution_root
Add-M6DirectAssertion $assertions 'M6-DIRECT-A08' ([string]$writerAfterAdvance.result -eq 'pass') ([string]$writerAfterAdvance.fingerprint)

$resume = Invoke-M6DirectResume -SessionRoot $sessionRoot -RequestPath $requestPath -FixtureRoot $fixtureRoot
Add-M6DirectAssertion $assertions 'M6-DIRECT-A09' ([string]$resume.status -eq 'completed') ([string]$resume.status)
Add-M6DirectAssertion $assertions 'M6-DIRECT-A10' ([int]$resume.event_count -eq [int]$requestBundle.expected.event_count_after_resume) ('event_count=' + $resume.event_count)
Add-M6DirectAssertion $assertions 'M6-DIRECT-A11' ([int]$resume.artifact_count -eq [int]$requestBundle.expected.artifact_count) ('artifact_count=' + $resume.artifact_count)
$finalProjection = Read-M6DirectJson (Join-Path $advance.execution_root 'artifact-projection.json')
$finalArtifact = @($finalProjection | Where-Object { [string]$_.producer_component_id -eq 'final_delivery_render_h7' })
$finalHtmlExists = $finalArtifact.Count -eq 1 -and (Test-Path -LiteralPath (Join-Path $advance.execution_root (($finalArtifact[0].relative_path) -replace '/','\')) -PathType Leaf)
Add-M6DirectAssertion $assertions 'M6-DIRECT-A12' $finalHtmlExists ('final_html_count=' + $finalArtifact.Count)

$rebuild = Invoke-M6DirectRebuild -SessionRoot $sessionRoot
Add-M6DirectAssertion $assertions 'M6-DIRECT-A13' ([string]$rebuild.result -eq 'pass_byte_stable') ([string]$rebuild.result)
$eventPath = Join-Path $advance.execution_root 'events.jsonl'
$eventHashBeforeReplay = Get-M6DirectSha256 $eventPath
$replay = Invoke-M6DirectResume -SessionRoot $sessionRoot -RequestPath $requestPath -FixtureRoot $fixtureRoot
$eventHashAfterReplay = Get-M6DirectSha256 $eventPath
Add-M6DirectAssertion $assertions 'M6-DIRECT-A14' ([string]$replay.result -eq 'reused' -and $eventHashBeforeReplay -eq $eventHashAfterReplay) ([string]$replay.result)
$writerFinal = Test-M6DirectRegisteredWriters $advance.execution_root
Add-M6DirectAssertion $assertions 'M6-DIRECT-A15' ([string]$writerFinal.result -eq 'pass') ([string]$writerFinal.fingerprint)

$negativeResults = [Collections.Generic.List[object]]::new()
$mutatedStatus = $request | ConvertTo-Json -Depth 50 -Compress | ConvertFrom-Json
$mutatedStatus.component_results[0].result_status = 'not_allowed'
$code = Get-M6DirectFailureCode { Test-M6DirectCertificationRequest -Request $mutatedStatus -FixtureRoot $fixtureRoot }
$negativeResults.Add([pscustomobject]@{case_id='M6-DIRECT-N01';passed=($code -eq 'direct_result_status_not_allowed');actual=$code})
$mutatedSequence = $request | ConvertTo-Json -Depth 50 -Compress | ConvertFrom-Json
$first = $mutatedSequence.component_results[0]
$mutatedSequence.component_results[0] = $mutatedSequence.component_results[1]
$mutatedSequence.component_results[1] = $first
$code = Get-M6DirectFailureCode { Test-M6DirectCertificationRequest -Request $mutatedSequence -FixtureRoot $fixtureRoot }
$negativeResults.Add([pscustomobject]@{case_id='M6-DIRECT-N02';passed=($code -eq 'direct_component_sequence_mismatch');actual=$code})

$bindingNegativeRoot = Join-Path $WorkRoot 'negative-binding-session'
Copy-Item -LiteralPath $sessionRoot -Destination $bindingNegativeRoot -Recurse
$bindingMarker = Join-Path $bindingNegativeRoot 'intermediate/workflow-kernel/session-runtime-binding.sha256'
Write-TaogeUtf8NoBomText -Path $bindingMarker -Text ('0' * 64) -EnsureFinalNewline
$code = Get-M6DirectFailureCode { Test-M6DirectSessionBinding -SessionRoot $bindingNegativeRoot -SessionId ([string]$request.session_id) }
$negativeResults.Add([pscustomobject]@{case_id='M6-DIRECT-N03';passed=($code -eq 'direct_session_binding_invalid');actual=$code})

$eventNegativeRoot = Join-Path $WorkRoot 'negative-event-session'
Copy-Item -LiteralPath $sessionRoot -Destination $eventNegativeRoot -Recurse
$negativeEventPath = Join-Path $eventNegativeRoot 'intermediate/workflow-kernel/direct-certification/events.jsonl'
$negativeEvents = @(Get-Content -LiteralPath $negativeEventPath -Encoding UTF8)
$firstEvent = $negativeEvents[0] | ConvertFrom-Json
$firstEvent.sequence = 9
$negativeEvents[0] = $firstEvent | ConvertTo-Json -Depth 20 -Compress
Write-TaogeUtf8NoBomLines -Path $negativeEventPath -Lines $negativeEvents
$code = Get-M6DirectFailureCode { Invoke-M6DirectRebuild -SessionRoot $eventNegativeRoot }
$negativeResults.Add([pscustomobject]@{case_id='M6-DIRECT-N04';passed=($code -eq 'direct_event_sequence_invalid');actual=$code})

$writerNegativeRoot = Join-Path $WorkRoot 'negative-writer-session'
Copy-Item -LiteralPath $sessionRoot -Destination $writerNegativeRoot -Recurse
$writerExecutionRoot = Join-Path $writerNegativeRoot 'intermediate/workflow-kernel/direct-certification'
Write-TaogeUtf8NoBomText -Path (Join-Path $writerExecutionRoot 'manual-patch.tmp') -Text 'forbidden'
$writerNegative = Test-M6DirectRegisteredWriters $writerExecutionRoot
$negativeResults.Add([pscustomobject]@{case_id='M6-DIRECT-N05';passed=([string]$writerNegative.fingerprint -eq 'direct_unregistered_writer_detected');actual=[string]$writerNegative.fingerprint})

$syntheticEvaluator = [pscustomobject]@{result='pass';certification_status='certified';source_revision=$SourceRevision;freeze_before_sha256=[string]$freezeBefore.aggregate_sha256;freeze_after_sha256=[string]$freezeBefore.aggregate_sha256}
$syntheticRuntime = [pscustomobject]@{result='pass';certification_status='certified';source_revision=$SourceRevision;freeze_before_sha256=[string]$freezeBefore.aggregate_sha256;freeze_after_sha256=[string]$freezeBefore.aggregate_sha256}
$prerequisiteNegative = Test-M6DirectPrerequisiteObjects $syntheticEvaluator $syntheticRuntime $SourceRevision ('sha256:' + ('0' * 64))
$negativeResults.Add([pscustomobject]@{case_id='M6-DIRECT-N06';passed=([string]$prerequisiteNegative.fingerprint -eq 'direct_prerequisite_digest_mismatch');actual=[string]$prerequisiteNegative.fingerprint})

$freezeAfter = New-M6CertificationFreeze -SourceRevision $SourceRevision -GeneratedAt '2026-07-18T16:35:00+08:00' -FreezeId 'M6-FREEZE-DIRECT-001'
$freezeAfterPath = Write-M6CertificationFreeze -Path (Join-Path $WorkRoot 'freeze-after.json') -Manifest $freezeAfter
$freezeBeforeCheck = Test-M6CertificationFreeze -Manifest $freezeBefore -ExpectedSourceRevision $SourceRevision
$freezeAfterCheck = Test-M6CertificationFreeze -Manifest $freezeAfter -ExpectedSourceRevision $SourceRevision
$freezeStable = $freezeBeforeCheck.result -eq 'pass' -and $freezeAfterCheck.result -eq 'pass' -and [string]$freezeBefore.aggregate_sha256 -eq [string]$freezeAfter.aggregate_sha256
Add-M6DirectAssertion $assertions 'M6-DIRECT-A16' $freezeStable ('freeze=' + [string]$freezeBefore.aggregate_sha256)

$prerequisiteStatus = 'not_checked_compile_smoke_only'
$prerequisiteEvaluatorRelative = ''
$prerequisiteRuntimeRelative = ''
$prerequisiteSourceRevision = ''
$prerequisiteFreeze = ''
$errors = [Collections.Generic.List[string]]::new()
if ($Mode -eq 'Certification') {
  $evaluatorFull = [IO.Path]::GetFullPath($EvaluatorReportPath)
  $runtimeFull = [IO.Path]::GetFullPath($RuntimeReportPath)
  $evaluator = Read-M6DirectJson $evaluatorFull
  $runtime = Read-M6DirectJson $runtimeFull
  $evaluatorSchema = Join-Path $ProjectRoot 'templates/schema/m6/evaluator-conformance-report.v0.1.schema.json'
  $runtimeSchema = Join-Path $ProjectRoot 'templates/schema/m6/runtime-conformance-report.v0.1.schema.json'
  foreach ($schemaError in @(Test-R8H5JsonSchemaValue $evaluatorSchema $evaluator)) { $errors.Add("evaluator_schema:$schemaError") }
  foreach ($schemaError in @(Test-R8H5JsonSchemaValue $runtimeSchema $runtime)) { $errors.Add("runtime_schema:$schemaError") }
  $prerequisite = Test-M6DirectPrerequisiteObjects $evaluator $runtime $SourceRevision ([string]$freezeBefore.aggregate_sha256)
  if ([string]$prerequisite.result -eq 'pass') {
    $prerequisiteStatus = 'certified_same_digest'
  } else {
    $prerequisiteStatus = 'failed'
    $errors.Add([string]$prerequisite.fingerprint)
  }
  $prerequisiteEvaluatorRelative = $evaluatorFull.Substring($ProjectRoot.Length).TrimStart('\').Replace('\','/')
  $prerequisiteRuntimeRelative = $runtimeFull.Substring($ProjectRoot.Length).TrimStart('\').Replace('\','/')
  $prerequisiteSourceRevision = $SourceRevision
  $prerequisiteFreeze = [string]$freezeBefore.aggregate_sha256
}

$assertionPass = @($assertions | Where-Object { [bool]$_.passed }).Count
$negativePass = @($negativeResults | Where-Object { [bool]$_.passed }).Count
foreach ($failed in @($assertions | Where-Object { -not [bool]$_.passed })) { $errors.Add("assertion_failed:$($failed.check_id)") }
foreach ($failed in @($negativeResults | Where-Object { -not [bool]$_.passed })) { $errors.Add("negative_failed:$($failed.case_id):$($failed.actual)") }
if (-not $freezeStable) { $errors.Add('direct_freeze_not_stable') }
$result = if ($errors.Count -eq 0) { 'pass' } else { 'fail' }
$certificationStatus = if ($result -ne 'pass') { 'failed' } elseif ($Mode -eq 'Certification') { 'certified' } else { 'not_run_compile_smoke_only' }

$report = [pscustomobject][ordered]@{
  schema_id = 'taoge://schemas/m6/direct-certification-report/v0.1'
  schema_version = '0.1'
  suite_id = 'M6-DIRECT-CERTIFICATION-0.1'
  mode = $modeValue
  source_revision = $SourceRevision
  result = $result
  certification_status = $certificationStatus
  freeze_before_sha256 = [string]$freezeBefore.aggregate_sha256
  freeze_after_sha256 = [string]$freezeAfter.aggregate_sha256
  freeze_stable = $freezeStable
  prerequisite_evidence = [pscustomobject][ordered]@{
    status = $prerequisiteStatus
    evaluator_report = $prerequisiteEvaluatorRelative
    runtime_report = $prerequisiteRuntimeRelative
    source_revision = $prerequisiteSourceRevision
    freeze_sha256 = $prerequisiteFreeze
  }
  direct_route = [pscustomobject][ordered]@{
    route_id = 'direct'
    runtime_generation = 'kernel_v1_current'
    session_binding_status = 'created_and_verified'
    component_count = @($request.component_results).Count
    artifact_count = [int]$resume.artifact_count
    event_count = [int]$resume.event_count
    wait_status = [string]$advance.status
    resume_status = [string]$resume.status
    rebuild_status = [string]$rebuild.result
    replay_status = if ([string]$replay.result -eq 'reused' -and $eventHashBeforeReplay -eq $eventHashAfterReplay) { 'reused_no_new_event' } else { 'failed' }
    unexpected_writer_count = @($writerFinal.unexpected).Count
  }
  assertion_count = $assertions.Count
  assertion_pass_count = $assertionPass
  negative_count = $negativeResults.Count
  negative_pass_count = $negativePass
  certified_scope = @(
    'kernel_v1_current direct session binding',
    'current direct component order and typed result contract intake',
    'final human gate wait and typed fixture resume',
    'immutable artifact and append-only event projections',
    'projection rebuild byte stability',
    'completed replay idempotence',
    'registered writer enforcement'
  )
  excluded_scope = @(
    'real account content',
    'semantic worker output quality',
    'network and provider execution',
    'real human decision',
    'visual quality and platform performance',
    'hotspot route',
    'project L3 certification'
  )
  boundaries = [pscustomobject][ordered]@{
    network_called = $false
    provider_called = $false
    private_account_used = $false
    real_human_decision_used = $false
    semantic_quality_certified = $false
    manual_patch_used = $false
  }
  underlying_evidence = [pscustomobject][ordered]@{
    request = $requestPath.Substring($ProjectRoot.Length).TrimStart('\').Replace('\','/')
    session_binding = (Join-Path $sessionRoot 'intermediate/workflow-kernel/session-runtime-binding.json').Substring($ProjectRoot.Length).TrimStart('\').Replace('\','/')
    event_log = $eventPath.Substring($ProjectRoot.Length).TrimStart('\').Replace('\','/')
    run_state = (Join-Path $advance.execution_root 'run-state.json').Substring($ProjectRoot.Length).TrimStart('\').Replace('\','/')
    writer_ledger = (Join-Path $advance.execution_root 'writer-ledger.json').Substring($ProjectRoot.Length).TrimStart('\').Replace('\','/')
    freeze_before = $freezeBeforePath.Substring($ProjectRoot.Length).TrimStart('\').Replace('\','/')
    freeze_after = $freezeAfterPath.Substring($ProjectRoot.Length).TrimStart('\').Replace('\','/')
    assertions = @($assertions)
    negative_cases = @($negativeResults)
  }
  errors = @($errors)
}
$reportSchema = Join-Path $ProjectRoot 'templates/schema/m6/direct-certification-report.v0.1.schema.json'
$reportSchemaErrors = @(Test-R8H5JsonSchemaValue $reportSchema $report)
if ($reportSchemaErrors.Count -gt 0) {
  throw "m6_direct_report_schema_invalid:$([string]::Join(',',@($reportSchemaErrors)))"
}
Write-TaogeUtf8NoBomJson -Path $ReportPath -Value $report -Depth 60
Write-Output "result=$result"
Write-Output "certification_status=$certificationStatus"
Write-Output "assertion_pass_count=$assertionPass"
Write-Output "negative_pass_count=$negativePass"
Write-Output "freeze_stable=$freezeStable"
Write-Output "report=$ReportPath"
if ($result -ne 'pass') { exit 1 }
