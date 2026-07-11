param(
  [string]$FixtureRoot = "examples/p0-h1-contract-fixtures",
  [string]$SchemaRoot = "templates/schema/p0",
  [string]$LegacyPlanSchemaPath = "templates/schema/p0-runtime.v0.1.json",
  [string]$CompatibilityMatrixPath = "templates/schema/p0/compatibility-matrix.v0.2.json",
  [string]$HumanReportPath = "state/checks/p0-h1-contract-check-report.md",
  [string]$MachineReportPath = "state/checks/p0-h1-contract-check-report.json"
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')

function Resolve-P0ProjectPath {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
  return Join-Path (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path $Path
}

function Read-P0EventLog {
  param([string]$Path)
  $events = [System.Collections.Generic.List[object]]::new()
  foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $events.Add(($line | ConvertFrom-Json))
  }
  return [object[]]$events.ToArray()
}

try {
  $fixturePath = Resolve-P0ProjectPath $FixtureRoot
  $schemaPath = Resolve-P0ProjectPath $SchemaRoot
  $legacySchemaPath = Resolve-P0ProjectPath $LegacyPlanSchemaPath
  $matrixPath = Resolve-P0ProjectPath $CompatibilityMatrixPath
  $humanPath = Resolve-P0ProjectPath $HumanReportPath
  $machinePath = Resolve-P0ProjectPath $MachineReportPath
  foreach ($requiredPath in @($fixturePath, $schemaPath, $legacySchemaPath, $matrixPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) { Write-Error "P0 H1 preflight path missing: $requiredPath"; exit 4 }
  }
  foreach ($reportPath in @($humanPath, $machinePath)) {
    $parent = Split-Path -Parent $reportPath
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  }

  $results = [System.Collections.Generic.List[object]]::new()
  $expectedSchemaIds = @(
    'taoge://schemas/p0/session-execution-plan/v0.2',
    'taoge://schemas/p0/execution-event/v0.2',
    'taoge://schemas/p0/artifact-lineage/v0.2',
    'taoge://schemas/p0/artifact-check-set/v0.2',
    'taoge://schemas/final-delivery/typed-components/v0.2'
  )
  $seenSchemaIds = @{}
  foreach ($file in @(Get-ChildItem -LiteralPath $schemaPath -File -Filter '*.schema.json' | Sort-Object Name)) {
    $schemaErrors = [System.Collections.Generic.List[string]]::new()
    try {
      $schema = Read-P0JsonFile $file.FullName
      if ($schema.'$schema' -ne 'https://json-schema.org/draft/2020-12/schema') { $schemaErrors.Add('schema_dialect_invalid') }
      if ([string]::IsNullOrWhiteSpace([string]$schema.'$id')) { $schemaErrors.Add('schema_id_missing') } else { $seenSchemaIds[[string]$schema.'$id'] = $true }
      if (-not (Test-P0HasProperty $schema 'additionalProperties') -or $schema.additionalProperties -ne $false) { $schemaErrors.Add('schema_root_additional_properties_not_closed') }
    } catch { $schemaErrors.Add('schema_json_parse_error:' + $_.Exception.Message) }
    $results.Add([pscustomobject]@{
      fixture_id = 'H1-SCHEMA-' + $file.BaseName
      contract_type = 'json_schema'
      expected_result = 'pass'
      actual_result = $(if ($schemaErrors.Count) { 'fail' } else { 'pass' })
      expectation_met = ($schemaErrors.Count -eq 0)
      errors = [object[]]$schemaErrors.ToArray()
      path = $file.FullName
    })
  }
  foreach ($id in $expectedSchemaIds) {
    if (-not $seenSchemaIds.ContainsKey($id)) {
      $results.Add([pscustomobject]@{
        fixture_id = 'H1-SCHEMA-ID-' + ($id -replace '[^a-zA-Z0-9]+','-')
        contract_type = 'json_schema'
        expected_result = 'pass'
        actual_result = 'fail'
        expectation_met = $false
        errors = @('schema_expected_id_missing:' + $id)
        path = $schemaPath
      })
    }
  }

  $legacyErrors = [System.Collections.Generic.List[string]]::new()
  try {
    $legacySchema = Read-P0JsonFile $legacySchemaPath
    if ($legacySchema.'$id' -ne 'taoge://schemas/p0/session-execution-plan/v0.1') { $legacyErrors.Add('legacy_schema_id_invalid') }
    if ($legacySchema.properties.workflow_version.const -ne 'p0-runtime-v0.1') { $legacyErrors.Add('legacy_workflow_version_invalid') }
  } catch { $legacyErrors.Add('legacy_schema_parse_error:' + $_.Exception.Message) }
  $results.Add([pscustomobject]@{
    fixture_id = 'H1-LEGACY-V0.1-SCHEMA'
    contract_type = 'legacy_json_schema'
    expected_result = 'pass'
    actual_result = $(if ($legacyErrors.Count) { 'fail' } else { 'pass' })
    expectation_met = ($legacyErrors.Count -eq 0)
    errors = [object[]]$legacyErrors.ToArray()
    path = $legacySchemaPath
  })

  $matrixErrors = [System.Collections.Generic.List[string]]::new()
  try {
    foreach ($error in (Test-P0CompatibilityMatrixContract (Read-P0JsonFile $matrixPath))) { $matrixErrors.Add($error) }
  } catch { $matrixErrors.Add('compatibility_matrix_parse_error:' + $_.Exception.Message) }
  $results.Add([pscustomobject]@{
    fixture_id = 'H1-COMPATIBILITY-MATRIX'
    contract_type = 'compatibility_matrix'
    expected_result = 'pass'
    actual_result = $(if ($matrixErrors.Count) { 'fail' } else { 'pass' })
    expectation_met = ($matrixErrors.Count -eq 0)
    errors = [object[]]$matrixErrors.ToArray()
    path = $matrixPath
  })

  $manifestPath = Join-Path $fixturePath 'fixtures.json'
  if (-not (Test-Path -LiteralPath $manifestPath)) { Write-Error "Fixture manifest missing: $manifestPath"; exit 4 }
  $manifest = Read-P0JsonFile $manifestPath
  foreach ($case in @($manifest.cases)) {
    $casePath = Join-Path $fixturePath ([string]$case.path)
    $caseErrors = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $casePath)) {
      $caseErrors.Add('fixture_path_missing')
    } else {
      try {
        switch ([string]$case.contract_type) {
          'plan' { foreach ($error in (Test-P0PlanContract (Read-P0JsonFile $casePath))) { $caseErrors.Add($error) } }
          'event_log' { foreach ($error in (Test-P0EventLogContract (Read-P0EventLog $casePath))) { $caseErrors.Add($error) } }
          'lineage' { foreach ($error in (Test-P0LineageContract (Read-P0JsonFile $casePath))) { $caseErrors.Add($error) } }
          'artifact_check_set' { foreach ($error in (Test-P0ArtifactCheckSetContract (Read-P0JsonFile $casePath))) { $caseErrors.Add($error) } }
          'render_input' { foreach ($error in (Test-P0RenderInputContract (Read-P0JsonFile $casePath))) { $caseErrors.Add($error) } }
          default { $caseErrors.Add('fixture_contract_type_unknown:' + $case.contract_type) }
        }
      } catch { $caseErrors.Add('fixture_validation_exception:' + $_.Exception.Message) }
    }
    $actual = if ($caseErrors.Count) { 'fail' } else { 'pass' }
    $expectationMet = $actual -eq [string]$case.expected_result
    if ($expectationMet -and [string]$case.expected_result -eq 'fail' -and (Test-P0HasProperty $case 'expected_error')) {
      $prefix = [string]$case.expected_error
      $expectationMet = @($caseErrors | Where-Object { $_ -like "$prefix*" }).Count -gt 0
    }
    $results.Add([pscustomobject]@{
      fixture_id = [string]$case.fixture_id
      contract_type = [string]$case.contract_type
      expected_result = [string]$case.expected_result
      actual_result = $actual
      expectation_met = $expectationMet
      errors = [object[]]$caseErrors.ToArray()
      path = $casePath
    })
  }

  $mismatches = @($results | Where-Object { -not $_.expectation_met })
  $invalidCases = @($results | Where-Object { $_.expected_result -eq 'fail' })
  $report = [ordered]@{
    p0_h1_contract_check_report = [ordered]@{
      check_run_id = 'P0-H1-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
      suite_id = [string]$manifest.fixture_suite_id
      schema_version = '0.2'
      overall_result = $(if ($mismatches.Count) { 'fail' } else { 'pass' })
      exit_code = $(if ($mismatches.Count) { 1 } else { 0 })
      schema_count = $seenSchemaIds.Count
      fixture_count = @($manifest.cases).Count
      negative_fixture_count = $invalidCases.Count
      mismatch_count = $mismatches.Count
      not_tested_scope = @('runtime_v0.2_execution','typed_renderer_v0.2','real_account','image_provider','publishing')
      checks = [object[]]$results.ToArray()
    }
  }
  $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $machinePath -Encoding UTF8

  $lines = @('# P0-H1 Contract Check Report', '', '```yaml')
  $lines += "check_run_id: $($report.p0_h1_contract_check_report.check_run_id)"
  $lines += "overall_result: $($report.p0_h1_contract_check_report.overall_result)"
  $lines += "exit_code: $($report.p0_h1_contract_check_report.exit_code)"
  $lines += "schema_count: $($report.p0_h1_contract_check_report.schema_count)"
  $lines += "fixture_count: $($report.p0_h1_contract_check_report.fixture_count)"
  $lines += "negative_fixture_count: $($report.p0_h1_contract_check_report.negative_fixture_count)"
  $lines += "mismatch_count: $($report.p0_h1_contract_check_report.mismatch_count)"
  $lines += '```'
  $lines += ''
  $lines += '| Fixture | Contract | Expected | Actual | Matched | Errors |'
  $lines += '|---|---|---|---|---:|---|'
  foreach ($result in $results) {
    $errorText = if (@($result.errors).Count) { [string]::Join('; ', @($result.errors)) } else { 'none' }
    $lines += "| $($result.fixture_id) | $($result.contract_type) | $($result.expected_result) | $($result.actual_result) | $($result.expectation_met) | $errorText |"
  }
  $lines | Set-Content -LiteralPath $humanPath -Encoding UTF8

  if ($mismatches.Count) {
    Write-Output 'P0_H1_CONTRACT_CHECK_RESULT=fail'
    foreach ($mismatch in $mismatches) { Write-Output "P0_H1_CONTRACT_ERROR=$($mismatch.fixture_id):expectation_mismatch" }
    exit 1
  }
  Write-Output 'P0_H1_CONTRACT_CHECK_RESULT=pass'
  Write-Output "P0_H1_SCHEMA_COUNT=$($seenSchemaIds.Count)"
  Write-Output "P0_H1_FIXTURE_COUNT=$(@($manifest.cases).Count)"
  Write-Output "P0_H1_NEGATIVE_FIXTURE_COUNT=$($invalidCases.Count)"
  exit 0
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
