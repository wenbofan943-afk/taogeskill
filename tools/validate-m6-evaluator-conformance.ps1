param(
  [string]$ProjectRoot = '',
  [ValidateSet('CompileSmoke','Certification')][string]$Mode = 'CompileSmoke',
  [string]$SourceRevision = '',
  [string]$WorkRoot = '',
  [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
} else {
  $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}
. (Join-Path $PSScriptRoot 'M6CertificationRuntime.ps1')
Initialize-M6CertificationRuntime -ProjectRoot $ProjectRoot

$checksRoot = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot 'state/checks')).TrimEnd('\','/')
if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
  $WorkRoot = Join-Path $checksRoot 'm6/evaluator-conformance-work'
}
$WorkRoot = [System.IO.Path]::GetFullPath($WorkRoot).TrimEnd('\','/')
$checksPrefix = $checksRoot + [System.IO.Path]::DirectorySeparatorChar
if (-not $WorkRoot.StartsWith($checksPrefix,[System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'm6_conformance_work_root_must_be_under_state_checks'
}
if ($WorkRoot -eq $checksRoot -or $WorkRoot.Length -le $checksPrefix.Length) {
  throw 'm6_conformance_work_root_too_broad'
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = Join-Path $checksRoot 'm6/evaluator-conformance-report.json'
}
$ReportPath = Assert-M6CheckOutputPath $ReportPath

$modeValue = if ($Mode -eq 'Certification') { 'certification' } else { 'compile_smoke' }
$errors = [System.Collections.Generic.List[string]]::new()
if ($Mode -eq 'Certification') {
  if ($SourceRevision -notmatch '^[0-9a-f]{40}$') {
    throw 'm6_certification_requires_full_source_revision'
  }
  $headResult = Invoke-TaogeProcessCapture -FilePath 'git' -Arguments @('rev-parse','HEAD') -WorkingDirectory $ProjectRoot
  $head = $headResult.stdout.Trim().ToLowerInvariant()
  if ($head -ne $SourceRevision.ToLowerInvariant()) {
    throw 'm6_certification_source_revision_not_head'
  }
  $statusResult = Invoke-TaogeProcessCapture -FilePath 'git' -Arguments @('status','--porcelain','--untracked-files=no') -WorkingDirectory $ProjectRoot
  if (-not [string]::IsNullOrWhiteSpace($statusResult.stdout)) {
    throw 'm6_certification_requires_clean_tracked_worktree'
  }
} elseif ([string]::IsNullOrWhiteSpace($SourceRevision)) {
  $SourceRevision = 'git_worktree_pending_commit'
}

if (Test-Path -LiteralPath $WorkRoot) {
  $resolvedWork = [System.IO.Path]::GetFullPath($WorkRoot)
  if (-not $resolvedWork.StartsWith($checksPrefix,[System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'm6_conformance_cleanup_root_escape'
  }
  Remove-Item -LiteralPath $resolvedWork -Recurse -Force
}
New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null

$freezeBefore = New-M6CertificationFreeze `
  -SourceRevision $SourceRevision `
  -GeneratedAt '2026-07-18T15:00:00+08:00' `
  -FreezeId 'M6-FREEZE-EVALUATOR-001'
$freezeBeforePath = Write-M6CertificationFreeze `
  -Path (Join-Path $WorkRoot 'freeze-before.json') `
  -Manifest $freezeBefore

$suiteRoot = Join-Path $WorkRoot 'r8-suite'
$h5r3ReportPath = Join-Path $suiteRoot 'r8-h5r3-evaluation-runtime-report.json'
$h5r4ReportPath = Join-Path $suiteRoot 'r8-h5r4-blind-runtime-report.json'
$h5r5ReportPath = Join-Path $suiteRoot 'r8-h5r5-finalization-runtime-report.json'
& (Join-Path $PSScriptRoot 'validate-r8-h5r5-finalization-runtime.ps1') `
  -ProjectRoot $ProjectRoot `
  -WorkRoot $suiteRoot `
  -ReportPath $h5r5ReportPath
if (-not $?) {
  throw 'm6_underlying_evaluator_suite_failed'
}

$reports = @{
  machine = Read-M6Json $h5r3ReportPath
  blind = Read-M6Json $h5r4ReportPath
  finalizer = Read-M6Json $h5r5ReportPath
}
$catalog = Read-M6Json (Join-Path $ProjectRoot 'examples/m6-evaluator-conformance-fixtures/catalog.json')

function Get-M6ReportValue {
  param([object]$Value,[string]$Path)
  $current = $Value
  foreach ($segment in $Path.Split('.')) {
    if ($null -eq $current) { return $null }
    $property = $current.PSObject.Properties[$segment]
    if ($null -eq $property) { return $null }
    $current = $property.Value
  }
  return $current
}

$assertionPass = 0
foreach ($assertion in @($catalog.assertions)) {
  $reportName = [string]$assertion.report
  if (-not $reports.ContainsKey($reportName)) {
    $errors.Add("assertion_report_unknown:$($assertion.check_id)")
    continue
  }
  $actual = Get-M6ReportValue $reports[$reportName] ([string]$assertion.path)
  $actualJson = $actual | ConvertTo-Json -Depth 10 -Compress
  $expectedJson = $assertion.equals | ConvertTo-Json -Depth 10 -Compress
  if ($actualJson -eq $expectedJson) {
    $assertionPass++
  } else {
    $errors.Add("assertion_mismatch:$($assertion.check_id):expected=$expectedJson:actual=$actualJson")
  }
}

$freezeAfter = New-M6CertificationFreeze `
  -SourceRevision $SourceRevision `
  -GeneratedAt '2026-07-18T15:00:00+08:00' `
  -FreezeId 'M6-FREEZE-EVALUATOR-001'
$freezeAfterPath = Write-M6CertificationFreeze `
  -Path (Join-Path $WorkRoot 'freeze-after.json') `
  -Manifest $freezeAfter
$beforeVerification = Test-M6CertificationFreeze -Manifest $freezeBefore -ExpectedSourceRevision $SourceRevision
$afterVerification = Test-M6CertificationFreeze -Manifest $freezeAfter -ExpectedSourceRevision $SourceRevision
$freezeStable = $beforeVerification.result -eq 'pass' -and
  $afterVerification.result -eq 'pass' -and
  $freezeBefore.aggregate_sha256 -eq $freezeAfter.aggregate_sha256
if (-not $freezeStable) {
  $errors.Add('freeze_before_after_not_stable')
}

$negativePass = 0
$tampered = $freezeBefore | ConvertTo-Json -Depth 40 -Compress | ConvertFrom-Json
$tampered.aggregate_sha256 = 'sha256:' + ('0' * 64)
if ((Test-M6CertificationFreeze -Manifest $tampered -ExpectedSourceRevision $SourceRevision).result -eq 'fail') {
  $negativePass++
} else {
  $errors.Add('tampered_freeze_false_success')
}
if ((Test-M6CertificationFreeze -Manifest $freezeBefore -ExpectedSourceRevision 'different-source-revision').result -eq 'fail') {
  $negativePass++
} else {
  $errors.Add('source_revision_false_success')
}

$requiredCapabilities = @($catalog.required_capabilities)
$observedCapabilities = @($catalog.assertions.capability + @(
  'rejection_fail_closed',
  'freeze_before_after_stability'
) | Select-Object -Unique)
foreach ($capability in $requiredCapabilities) {
  if ($capability -notin $observedCapabilities) {
    $errors.Add("required_capability_unobserved:$capability")
  }
}

$result = if ($errors.Count -eq 0 -and
  $assertionPass -eq @($catalog.assertions).Count -and
  $negativePass -eq @($catalog.negative_cases).Count) { 'pass' } else { 'fail' }
$certificationStatus = if ($result -ne 'pass') {
  'failed'
} elseif ($Mode -eq 'Certification') {
  'certified'
} else {
  'not_run_compile_smoke_only'
}
$relativeReport = {
  param([string]$Path)
  return ([System.IO.Path]::GetFullPath($Path).Substring($ProjectRoot.TrimEnd('\','/').Length + 1) -replace '\\','/')
}
$report = [pscustomobject][ordered]@{
  schema_id = 'taoge://schemas/m6/evaluator-conformance-report/v0.1'
  schema_version = '0.1'
  suite_id = 'M6-EVALUATOR-CONFORMANCE-0.1'
  suite_version = '0.1'
  mode = $modeValue
  source_revision = $SourceRevision
  result = $result
  certification_status = $certificationStatus
  freeze_before_sha256 = $freezeBefore.aggregate_sha256
  freeze_after_sha256 = $freezeAfter.aggregate_sha256
  freeze_stable = $freezeStable
  assertion_count = @($catalog.assertions).Count
  assertion_pass_count = $assertionPass
  negative_pass_count = $negativePass
  capabilities = @($requiredCapabilities)
  underlying_reports = [pscustomobject][ordered]@{
    machine = & $relativeReport $h5r3ReportPath
    blind = & $relativeReport $h5r4ReportPath
    finalizer = & $relativeReport $h5r5ReportPath
  }
  network_called = $false
  provider_called = $false
  private_account_used = $false
  errors = @($errors)
}
$schemaErrors = @(Test-R8H5JsonSchemaValue `
  (Join-Path $ProjectRoot 'templates/schema/m6/evaluator-conformance-report.v0.1.schema.json') `
  $report)
if ($schemaErrors.Count -gt 0) {
  throw "m6_conformance_report_schema_failed:$([string]::Join(',',@($schemaErrors)))"
}
Write-TaogeUtf8NoBomJson -Path $ReportPath -Value $report -Depth 30
Write-Output "result=$result"
Write-Output "certification_status=$certificationStatus"
Write-Output "assertion_pass_count=$assertionPass"
Write-Output "negative_pass_count=$negativePass"
Write-Output "freeze_stable=$freezeStable"
Write-Output "freeze_before=$freezeBeforePath"
Write-Output "freeze_after=$freezeAfterPath"
Write-Output "report=$ReportPath"
if ($result -ne 'pass') {
  foreach ($item in $errors) { Write-Output "error=$item" }
  exit 1
}
