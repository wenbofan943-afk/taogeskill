[CmdletBinding()]
param(
  [string]$ProjectRoot = '',
  [ValidateSet('CompileSmoke','Certification')][string]$Mode = 'CompileSmoke',
  [string]$SourceRevision = '',
  [string]$EvaluatorReportPath = '',
  [string]$WorkRoot = '',
  [string]$ReportPath = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
} else {
  $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}
. (Join-Path $PSScriptRoot 'M6CertificationRuntime.ps1')
Initialize-M6CertificationRuntime -ProjectRoot $ProjectRoot

$checksRoot = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot 'state/checks')).TrimEnd('\','/')
$checksPrefix = $checksRoot + [System.IO.Path]::DirectorySeparatorChar
if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
  $WorkRoot = Join-Path $checksRoot 'm6/runtime-conformance-work'
}
$WorkRoot = [System.IO.Path]::GetFullPath($WorkRoot).TrimEnd('\','/')
if (-not $WorkRoot.StartsWith($checksPrefix,[System.StringComparison]::OrdinalIgnoreCase) -or
    $WorkRoot -eq $checksRoot) {
  throw 'm6_runtime_conformance_work_root_invalid'
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = Join-Path $checksRoot 'm6/runtime-conformance-report.json'
}
$ReportPath = Assert-M6CheckOutputPath $ReportPath

$modeValue = if ($Mode -eq 'Certification') { 'certification' } else { 'compile_smoke' }
if ($Mode -eq 'Certification') {
  if ($SourceRevision -notmatch '^[0-9a-f]{40}$') {
    throw 'm6_runtime_certification_requires_full_source_revision'
  }
  $headResult = Invoke-TaogeProcessCapture -FilePath 'git' -Arguments @('rev-parse','HEAD') -WorkingDirectory $ProjectRoot
  if ($headResult.exit_code -ne 0 -or $headResult.stdout.Trim().ToLowerInvariant() -ne $SourceRevision.ToLowerInvariant()) {
    throw 'm6_runtime_certification_source_revision_not_head'
  }
  $statusResult = Invoke-TaogeProcessCapture -FilePath 'git' -Arguments @('status','--porcelain','--untracked-files=no') -WorkingDirectory $ProjectRoot
  if ($statusResult.exit_code -ne 0 -or -not [string]::IsNullOrWhiteSpace($statusResult.stdout)) {
    throw 'm6_runtime_certification_requires_clean_tracked_worktree'
  }
  if ([string]::IsNullOrWhiteSpace($EvaluatorReportPath)) {
    throw 'm6_runtime_certification_requires_evaluator_report'
  }
} elseif ([string]::IsNullOrWhiteSpace($SourceRevision)) {
  $SourceRevision = 'git_worktree_pending_commit'
}

if (Test-Path -LiteralPath $WorkRoot) {
  $resolvedWork = [System.IO.Path]::GetFullPath($WorkRoot)
  if (-not $resolvedWork.StartsWith($checksPrefix,[System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'm6_runtime_conformance_cleanup_root_escape'
  }
  Remove-Item -LiteralPath $resolvedWork -Recurse -Force
}
New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null

function Get-M6RuntimeValue {
  param([Parameter(Mandatory=$true)][object]$Value,[Parameter(Mandatory=$true)][string]$Path)
  $current = $Value
  foreach ($segment in $Path.Split('.')) {
    if ($null -eq $current) { return $null }
    $property = $current.PSObject.Properties[$segment]
    if ($null -eq $property) { return $null }
    $current = $property.Value
  }
  return $current
}

function Get-M6RuntimeCase {
  param([Parameter(Mandatory=$true)][object]$Report,[Parameter(Mandatory=$true)][string]$CaseId)
  $collection = if ($null -ne $Report.PSObject.Properties['cases']) {
    @($Report.cases)
  } elseif ($null -ne $Report.PSObject.Properties['results']) {
    @($Report.results)
  } else {
    @()
  }
  $matches = @($collection | Where-Object { [string]$_.fixture_id -eq $CaseId })
  if ($matches.Count -ne 1) { return $null }
  return $matches[0]
}

function Test-M6RuntimeAssertions {
  param(
    [Parameter(Mandatory=$true)][hashtable]$Reports,
    [Parameter(Mandatory=$true)][object]$Catalog
  )
  $errors = [System.Collections.Generic.List[string]]::new()
  $passedIds = [System.Collections.Generic.List[string]]::new()
  foreach ($assertion in @($Catalog.assertions)) {
    $reportId = [string]$assertion.report
    if (-not $Reports.ContainsKey($reportId)) {
      $errors.Add("assertion_report_unknown:$($assertion.check_id)")
      continue
    }
    $target = $Reports[$reportId]
    if ($null -ne $assertion.PSObject.Properties['case_id']) {
      $target = Get-M6RuntimeCase -Report $target -CaseId ([string]$assertion.case_id)
      if ($null -eq $target) {
        $errors.Add("assertion_case_missing:$($assertion.check_id):$($assertion.case_id)")
        continue
      }
    }
    $actual = Get-M6RuntimeValue -Value $target -Path ([string]$assertion.path)
    $actualJson = $actual | ConvertTo-Json -Depth 20 -Compress
    $expectedJson = $assertion.equals | ConvertTo-Json -Depth 20 -Compress
    if ($actualJson -eq $expectedJson) {
      $passedIds.Add([string]$assertion.check_id)
    } else {
      $errors.Add("assertion_mismatch:$($assertion.check_id):expected=$expectedJson:actual=$actualJson")
    }
  }
  return [pscustomobject][ordered]@{
    result = if ($errors.Count -eq 0) { 'pass' } else { 'fail' }
    pass_count = $passedIds.Count
    passed_ids = @($passedIds)
    errors = @($errors)
  }
}

function Test-M6RuntimeEvaluatorEvidence {
  param(
    [Parameter(Mandatory=$true)][object]$Report,
    [Parameter(Mandatory=$true)][string]$ExpectedSourceRevision,
    [Parameter(Mandatory=$true)][string]$ExpectedFreezeSha256
  )
  $errors = [System.Collections.Generic.List[string]]::new()
  $schemaPath = Join-Path $ProjectRoot 'templates/schema/m6/evaluator-conformance-report.v0.1.schema.json'
  foreach ($schemaError in @(Test-R8H5JsonSchemaValue $schemaPath $Report)) {
    $errors.Add("evaluator_report_schema:$schemaError")
  }
  if ([string]$Report.result -ne 'pass' -or
      [string]$Report.certification_status -ne 'certified' -or
      -not [bool]$Report.freeze_stable) {
    $errors.Add('evaluator_not_certified')
  }
  if ([string]$Report.source_revision -ne $ExpectedSourceRevision) {
    $errors.Add('evaluator_source_revision_mismatch')
  }
  if ([string]$Report.freeze_before_sha256 -ne $ExpectedFreezeSha256 -or
      [string]$Report.freeze_after_sha256 -ne $ExpectedFreezeSha256) {
    $errors.Add('evaluator_freeze_digest_mismatch')
  }
  return [pscustomobject][ordered]@{
    result = if ($errors.Count -eq 0) { 'pass' } else { 'fail' }
    errors = @($errors)
  }
}

function Invoke-M6RuntimeUnderlyingSuite {
  param(
    [Parameter(Mandatory=$true)][string]$ScriptName,
    [Parameter(Mandatory=$true)][string]$SuiteWorkRoot,
    [Parameter(Mandatory=$true)][string]$MachineReportPath
  )
  $scriptPath = Join-Path $PSScriptRoot $ScriptName
  $process = Invoke-TaogeProcessCapture -FilePath 'powershell.exe' -Arguments @(
    '-NoProfile',
    '-ExecutionPolicy','Bypass',
    '-File',$scriptPath,
    '-ProjectRoot',$ProjectRoot,
    '-WorkRoot',$SuiteWorkRoot,
    '-MachineReportPath',$MachineReportPath
  ) -WorkingDirectory $ProjectRoot
  if ($process.exit_code -ne 0) {
    $tail = [string]$process.stderr
    if ($tail.Length -gt 600) { $tail = $tail.Substring($tail.Length - 600) }
    throw "m6_underlying_runtime_suite_failed:${ScriptName}:$tail"
  }
}

function Get-M6RuntimeRelativePath {
  param([Parameter(Mandatory=$true)][string]$Path)
  return ([System.IO.Path]::GetFullPath($Path).Substring($ProjectRoot.TrimEnd('\','/').Length + 1) -replace '\\','/')
}

$freezeBefore = New-M6CertificationFreeze `
  -SourceRevision $SourceRevision `
  -GeneratedAt '2026-07-18T16:00:00+08:00' `
  -FreezeId 'M6-FREEZE-RUNTIME-001'
$freezeBeforePath = Write-M6CertificationFreeze `
  -Path (Join-Path $WorkRoot 'freeze-before.json') `
  -Manifest $freezeBefore

$suiteRoot = Join-Path $WorkRoot 'underlying'
$m4ReportPath = Join-Path $suiteRoot 'm4-session-entry-report.json'
$m2ReportPath = Join-Path $suiteRoot 'm2-direct-report.json'
$m3ReportPath = Join-Path $suiteRoot 'm3-hotspot-report.json'
Invoke-M6RuntimeUnderlyingSuite 'validate-workflow-kernel-m4.ps1' (Join-Path $suiteRoot 'm4') $m4ReportPath
Invoke-M6RuntimeUnderlyingSuite 'validate-workflow-kernel-m2.ps1' (Join-Path $suiteRoot 'm2') $m2ReportPath
Invoke-M6RuntimeUnderlyingSuite 'validate-workflow-kernel-m3.ps1' (Join-Path $suiteRoot 'm3') $m3ReportPath

$reports = @{
  m2 = Read-M6Json $m2ReportPath
  m3 = Read-M6Json $m3ReportPath
  m4 = Read-M6Json $m4ReportPath
}
$catalog = Read-M6Json (Join-Path $ProjectRoot 'examples/m6-runtime-conformance-fixtures/catalog.json')
$errors = [System.Collections.Generic.List[string]]::new()
$assertions = Test-M6RuntimeAssertions -Reports $reports -Catalog $catalog
foreach ($item in @($assertions.errors)) { $errors.Add([string]$item) }

$freezeAfter = New-M6CertificationFreeze `
  -SourceRevision $SourceRevision `
  -GeneratedAt '2026-07-18T16:00:00+08:00' `
  -FreezeId 'M6-FREEZE-RUNTIME-001'
$freezeAfterPath = Write-M6CertificationFreeze `
  -Path (Join-Path $WorkRoot 'freeze-after.json') `
  -Manifest $freezeAfter
$beforeVerification = Test-M6CertificationFreeze -Manifest $freezeBefore -ExpectedSourceRevision $SourceRevision
$afterVerification = Test-M6CertificationFreeze -Manifest $freezeAfter -ExpectedSourceRevision $SourceRevision
$freezeStable = $beforeVerification.result -eq 'pass' -and
  $afterVerification.result -eq 'pass' -and
  $freezeBefore.aggregate_sha256 -eq $freezeAfter.aggregate_sha256
if (-not $freezeStable) { $errors.Add('freeze_before_after_not_stable') }

$evaluatorEvidenceStatus = 'not_checked_compile_smoke_only'
$evaluatorReportRelative = $null
$evaluatorReportSha256 = $null
$evaluatorSourceRevision = $null
$evaluatorFreezeSha256 = $null
if ($Mode -eq 'Certification') {
  $evaluatorFullPath = [System.IO.Path]::GetFullPath($EvaluatorReportPath)
  if (-not $evaluatorFullPath.StartsWith($checksPrefix,[System.StringComparison]::OrdinalIgnoreCase) -or
      -not (Test-Path -LiteralPath $evaluatorFullPath -PathType Leaf)) {
    throw 'm6_runtime_evaluator_report_path_invalid'
  }
  $evaluatorReport = Read-M6Json $evaluatorFullPath
  $evaluatorCheck = Test-M6RuntimeEvaluatorEvidence `
    -Report $evaluatorReport `
    -ExpectedSourceRevision $SourceRevision `
    -ExpectedFreezeSha256 ([string]$freezeBefore.aggregate_sha256)
  if ($evaluatorCheck.result -eq 'pass') {
    $evaluatorEvidenceStatus = 'certified_same_digest'
  } else {
    $evaluatorEvidenceStatus = 'failed'
    foreach ($item in @($evaluatorCheck.errors)) { $errors.Add([string]$item) }
  }
  $evaluatorReportRelative = Get-M6RuntimeRelativePath $evaluatorFullPath
  $evaluatorReportSha256 = 'sha256:' + (Get-TaogeFileSha256 $evaluatorFullPath)
  $evaluatorSourceRevision = [string]$evaluatorReport.source_revision
  $evaluatorFreezeSha256 = [string]$evaluatorReport.freeze_before_sha256
}

$negativePass = 0
$tamperedFreeze = $freezeBefore | ConvertTo-Json -Depth 40 -Compress | ConvertFrom-Json
$tamperedFreeze.aggregate_sha256 = 'sha256:' + ('0' * 64)
if ((Test-M6CertificationFreeze -Manifest $tamperedFreeze -ExpectedSourceRevision $SourceRevision).result -eq 'fail') {
  $negativePass++
}
if ((Test-M6CertificationFreeze -Manifest $freezeBefore -ExpectedSourceRevision 'different-source-revision').result -eq 'fail') {
  $negativePass++
}
$tamperedM3 = $reports.m3 | ConvertTo-Json -Depth 100 -Compress | ConvertFrom-Json
$tamperedM3.positive_evidence.external_outcome_reconcile_count = 99
$tamperedReports = @{m2=$reports.m2;m3=$tamperedM3;m4=$reports.m4}
if ((Test-M6RuntimeAssertions -Reports $tamperedReports -Catalog $catalog).result -eq 'fail') {
  $negativePass++
}
$syntheticEvaluator = [pscustomobject][ordered]@{
  schema_id = 'taoge://schemas/m6/evaluator-conformance-report/v0.1'
  schema_version = '0.1'
  suite_id = 'M6-EVALUATOR-CONFORMANCE-0.1'
  suite_version = '0.1'
  mode = 'certification'
  source_revision = $SourceRevision
  result = 'pass'
  certification_status = 'certified'
  freeze_before_sha256 = 'sha256:' + ('0' * 64)
  freeze_after_sha256 = 'sha256:' + ('0' * 64)
  freeze_stable = $true
  assertion_count = 20
  assertion_pass_count = 20
  negative_pass_count = 2
  capabilities = @(
    'object_array_scalar_topology',
    'invalid_and_noncomparable',
    'rejection_fail_closed',
    'blind_allocation_mapping',
    'known_answer_finalizer',
    'false_success_mutations',
    'freeze_before_after_stability'
  )
  underlying_reports = [pscustomobject][ordered]@{machine='fixture';blind='fixture';finalizer='fixture'}
  network_called = $false
  provider_called = $false
  private_account_used = $false
  errors = @()
}
if ((Test-M6RuntimeEvaluatorEvidence -Report $syntheticEvaluator -ExpectedSourceRevision $SourceRevision -ExpectedFreezeSha256 ([string]$freezeBefore.aggregate_sha256)).result -eq 'fail') {
  $negativePass++
}
if ($negativePass -ne @($catalog.negative_cases).Count) {
  $errors.Add("runtime_negative_case_mismatch:$negativePass/$(@($catalog.negative_cases).Count)")
}

$requiredCommands = @($catalog.required_commands)
$commandResults = @()
foreach ($command in $requiredCommands) {
  $ids = @($catalog.assertions | Where-Object { [string]$_.command -eq [string]$command } | ForEach-Object { [string]$_.check_id })
  $passed = @($ids | Where-Object { $_ -in @($assertions.passed_ids) }).Count
  $commandResults += [pscustomobject][ordered]@{
    command = [string]$command
    assertion_count = $ids.Count
    assertion_pass_count = $passed
    result = if ($ids.Count -gt 0 -and $passed -eq $ids.Count) { 'pass' } else { 'fail' }
  }
}

$result = if ($errors.Count -eq 0 -and
  $assertions.pass_count -eq @($catalog.assertions).Count -and
  $negativePass -eq @($catalog.negative_cases).Count -and
  @($commandResults | Where-Object { $_.result -ne 'pass' }).Count -eq 0) { 'pass' } else { 'fail' }
$certificationStatus = if ($result -ne 'pass') {
  'failed'
} elseif ($Mode -eq 'Certification') {
  'certified'
} else {
  'not_run_compile_smoke_only'
}

$report = [pscustomobject][ordered]@{
  schema_id = 'taoge://schemas/m6/runtime-conformance-report/v0.1'
  schema_version = '0.1'
  suite_id = 'M6-RUNTIME-CONFORMANCE-0.1'
  suite_version = '0.1'
  mode = $modeValue
  source_revision = $SourceRevision
  result = $result
  certification_status = $certificationStatus
  freeze_before_sha256 = [string]$freezeBefore.aggregate_sha256
  freeze_after_sha256 = [string]$freezeAfter.aggregate_sha256
  freeze_stable = $freezeStable
  evaluator_evidence = [pscustomobject][ordered]@{
    status = $evaluatorEvidenceStatus
    report_path = $evaluatorReportRelative
    report_sha256 = $evaluatorReportSha256
    source_revision = $evaluatorSourceRevision
    freeze_sha256 = $evaluatorFreezeSha256
  }
  assertion_count = @($catalog.assertions).Count
  assertion_pass_count = [int]$assertions.pass_count
  negative_count = @($catalog.negative_cases).Count
  negative_pass_count = $negativePass
  required_commands = $requiredCommands
  command_results = $commandResults
  underlying_reports = [pscustomobject][ordered]@{
    m2_direct = Get-M6RuntimeRelativePath $m2ReportPath
    m3_hotspot = Get-M6RuntimeRelativePath $m3ReportPath
    m4_session_entry = Get-M6RuntimeRelativePath $m4ReportPath
  }
  certified_scope = [pscustomobject][ordered]@{
    runtime_generation = 'kernel_v1_current_entry_plus_kernel_v1_shadow_execution'
    routes = @('session_entry','direct_shadow','hotspot_shadow')
    branches = @(
      'current_session_start',
      'direct_positive_advance_to_final_wait',
      'hotspot_research_and_freshness_wait',
      'hotspot_resume_after_external_and_human_wait',
      'projection_rebuild_from_immutable_evidence',
      'external_outcome_reconcile_without_blind_retry'
    )
    excluded = @(
      'real_account_content_execution',
      'network_or_provider_side_effects',
      'semantic_worker_quality',
      'digest_bound_direct_and_hotspot_real_route_certification'
    )
  }
  network_called = $false
  provider_called = $false
  private_account_used = $false
  manual_patch_detected = $false
  errors = @($errors)
}
$schemaErrors = @(Test-R8H5JsonSchemaValue `
  (Join-Path $ProjectRoot 'templates/schema/m6/runtime-conformance-report.v0.1.schema.json') `
  $report)
if ($schemaErrors.Count -gt 0) {
  throw "m6_runtime_conformance_report_schema_failed:$([string]::Join(',',@($schemaErrors)))"
}
Write-TaogeUtf8NoBomJson -Path $ReportPath -Value $report -Depth 40
Write-Output "result=$result"
Write-Output "certification_status=$certificationStatus"
Write-Output "assertion_pass_count=$($assertions.pass_count)"
Write-Output "negative_pass_count=$negativePass"
Write-Output "freeze_stable=$freezeStable"
Write-Output "evaluator_evidence_status=$evaluatorEvidenceStatus"
Write-Output "freeze_before=$freezeBeforePath"
Write-Output "freeze_after=$freezeAfterPath"
Write-Output "report=$ReportPath"
if ($result -ne 'pass') {
  foreach ($item in $errors) { Write-Output "error=$item" }
  exit 1
}
exit 0
