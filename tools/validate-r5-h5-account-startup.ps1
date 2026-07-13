param(
  [string]$FixturePath = 'examples/r5-h5-account-startup-fixtures/fixtures.json',
  [string]$ReportPath = 'state/checks/r5-h5-account-startup-report.json'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'AccountStartupCheck.ps1')

function Test-R5H5Case {
  param($Case)
  $errors = [System.Collections.Generic.List[string]]::new()
  $actual = Resolve-R5AccountStartupCheck -InputObject $Case.request
  $expected = $Case.expected
  foreach ($name in @('startup_result', 'account_snapshot_status', 'next_skill')) {
    if ([string]$actual.$name -ne [string]$expected.$name) { $errors.Add("unexpected_$name") }
  }
  if (@($actual.questions).Count -ne [int]$expected.question_count) { $errors.Add('question_count_mismatch') }
  if (@($actual.questions).Count -gt 3) { $errors.Add('question_count_exceeds_three') }
  foreach ($field in @($expected.required_missing_fields)) {
    if (@($actual.missing_fields) -notcontains $field) { $errors.Add("missing_field_not_reported:$field") }
  }
  foreach ($field in @($expected.required_non_blocking_fields)) {
    if (@($actual.non_blocking_fields) -notcontains $field) { $errors.Add("non_blocking_field_not_reported:$field") }
  }
  if ($null -ne $expected.account_switch_isolated -and [bool]$actual.account_switch_isolated -ne [bool]$expected.account_switch_isolated) {
    $errors.Add('account_switch_isolation_mismatch')
  }
  if (-not $actual.account_snapshot_ref.StartsWith("accounts/$($actual.account_slug)/runs/$($actual.session_id)/")) {
    $errors.Add('snapshot_ref_not_account_scoped')
  }
  $snapshot = New-R5AccountSessionSnapshot -InputObject $Case.request -StartupCheck $actual
  if ($snapshot.schema_id -ne 'taoge://account/session-snapshot/v0.1' -or $snapshot.account_slug -ne $actual.account_slug) {
    $errors.Add('snapshot_contract_invalid')
  }
  return [ordered]@{
    fixture_id = $Case.fixture_id
    expected_result = $Case.expected.startup_result
    actual_result = $actual.startup_result
    expectation_met = ($errors.Count -eq 0)
    errors = @($errors)
  }
}

try {
  $projectRoot = Split-Path -Parent $PSScriptRoot
  $fixtureTarget = if ([IO.Path]::IsPathRooted($FixturePath)) { [IO.Path]::GetFullPath($FixturePath) } else { Join-Path $projectRoot $FixturePath }
  $fixture = Get-Content -LiteralPath $fixtureTarget -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($fixture.schema_id -ne 'taoge://fixtures/r5-h5-account-startup/v0.1') { throw 'fixture_schema_invalid' }
  $rows = [System.Collections.Generic.List[object]]::new()
  foreach ($case in @($fixture.cases)) { $rows.Add((Test-R5H5Case -Case $case)) }
  $failed = @($rows | Where-Object { -not $_.expectation_met })
  $report = [ordered]@{
    schema_id = 'taoge://reports/r5/h5-account-startup/v0.1'
    overall_result = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
    case_count = $rows.Count
    failure_count = $failed.Count
    results = @($rows)
  }
  $reportTarget = if ([IO.Path]::IsPathRooted($ReportPath)) { [IO.Path]::GetFullPath($ReportPath) } else { Join-Path $projectRoot $ReportPath }
  Write-TaogeUtf8NoBomJson -Path $reportTarget -Value $report -Depth 12
  "R5_H5_ACCOUNT_STARTUP_CHECK=$($report.overall_result)"
  "CASE_COUNT=$($report.case_count)"
  "REPORT=$reportTarget"
  if ($failed.Count -gt 0) { exit 1 }
} catch {
  Write-Error $_
  exit 3
}
