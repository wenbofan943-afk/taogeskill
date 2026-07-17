[CmdletBinding()]
param(
  [string]$ProjectRoot = '',
  [string]$WorkRoot = '',
  [string]$MachineReportPath = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = Split-Path -Parent $PSScriptRoot
}

$root = [System.IO.Path]::GetFullPath($ProjectRoot)
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')

function Copy-WorkflowIrFixtureSource {
  param([string]$Source, [string]$Destination)
  $parent = Split-Path -Parent $Destination
  if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Read-WorkflowIrFixtureJson {
  param([string]$Path)
  return ([System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Add-WorkflowIrFixtureResult {
  param(
    [System.Collections.Generic.List[object]]$Results,
    [string]$FixtureId,
    [string]$Expected,
    [string]$Actual,
    [string]$Fingerprint,
    [string]$Detail
  )
  $Results.Add([pscustomobject][ordered]@{
    fixture_id = $FixtureId
    expected_result = $Expected
    actual_result = $Actual
    expected_fingerprint = $Fingerprint
    fixture_result = $(if ($Expected -eq $Actual) { 'pass' } else { 'fail' })
    detail = $Detail
  })
}

try {
  if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
    $WorkRoot = Join-Path $root 'state/checks/workflow-kernel-m1/fixtures'
  }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
    $MachineReportPath = Join-Path $root 'state/checks/workflow-kernel-m1-fixture-report.json'
  }

  $work = [System.IO.Path]::GetFullPath($WorkRoot)
  $rootPrefix = $root.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  if (-not $work.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'work_root_outside_project'
  }
  if (Test-Path -LiteralPath $work) {
    Remove-Item -LiteralPath $work -Recurse -Force
  }
  New-Item -ItemType Directory -Path $work -Force | Out-Null

  $fixtureCatalogPath = Join-Path $root 'examples/workflow-kernel-m1-fixtures/fixtures.json'
  $fixtureCatalog = Read-WorkflowIrFixtureJson $fixtureCatalogPath
  $compilerPath = Join-Path $root 'tools/compile-workflow-ir.ps1'
  $powershellPath = (Get-Command powershell.exe -ErrorAction Stop).Source
  $results = [System.Collections.Generic.List[object]]::new()

  foreach ($case in @($fixtureCatalog.cases)) {
    $caseRoot = Join-Path $work ([string]$case.fixture_id)
    $sourceRoot = Join-Path $caseRoot 'sources'
    $outputRoot = Join-Path $caseRoot 'output'
    New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null

    $irPath = Join-Path $sourceRoot 'current-workflow-ir.json'
    $componentPath = Join-Path $sourceRoot 'component-catalog.json'
    $compatibilityPath = Join-Path $sourceRoot 'compatibility-catalog.json'
    Copy-WorkflowIrFixtureSource (Join-Path $root 'routes/current-workflow-ir.json') $irPath
    Copy-WorkflowIrFixtureSource (Join-Path $root 'routes/component-catalog.json') $componentPath
    Copy-WorkflowIrFixtureSource (Join-Path $root 'routes/compatibility-catalog.json') $compatibilityPath

    switch ([string]$case.mutation) {
      'none' {}
      'remove_final_stage' {
        $document = Read-WorkflowIrFixtureJson $irPath
        $document.stage_order = [object[]]@($document.stage_order | Where-Object { [string]$_ -ne 'final_decision' })
        $document.stage_definitions = [object[]]@($document.stage_definitions | Where-Object { [string]$_.stage_id -ne 'final_decision' })
        Write-TaogeUtf8NoBomJson -Path $irPath -Value $document -Depth 50
      }
      'remove_component' {
        $document = Read-WorkflowIrFixtureJson $componentPath
        $document.components = [object[]]@($document.components | Where-Object { [string]$_.component_id -ne 'final_delivery_decision_apply' })
        Write-TaogeUtf8NoBomJson -Path $componentPath -Value $document -Depth 50
      }
      'swap_direct_legacy_nodes' {
        $document = Read-WorkflowIrFixtureJson $irPath
        $direct = @($document.routes | Where-Object { [string]$_.route_id -eq 'direct' })[0]
        $script = @($direct.stage_bindings | Where-Object { [string]$_.stage_id -eq 'script_design' })[0]
        $temporary = $script.legacy_node_refs[0]
        $script.legacy_node_refs[0] = $script.legacy_node_refs[1]
        $script.legacy_node_refs[1] = $temporary
        $script.component_refs = [object[]]@($script.legacy_node_refs)
        Write-TaogeUtf8NoBomJson -Path $irPath -Value $document -Depth 50
      }
      'duplicate_compatibility_blueprint' {
        $document = Read-WorkflowIrFixtureJson $compatibilityPath
        $document.historical_blueprints = [object[]]@($document.historical_blueprints) + [object[]]@($document.historical_blueprints[0])
        Write-TaogeUtf8NoBomJson -Path $compatibilityPath -Value $document -Depth 50
      }
      'enable_runtime_switch' {
        $document = Read-WorkflowIrFixtureJson $irPath
        $document.runtime_switch_enabled = $true
        Write-TaogeUtf8NoBomJson -Path $irPath -Value $document -Depth 50
      }
      'allow_legacy_expansion' {
        $document = Read-WorkflowIrFixtureJson $compatibilityPath
        $document.legacy_blueprint_freeze.new_legacy_blueprints_allowed = $true
        Write-TaogeUtf8NoBomJson -Path $compatibilityPath -Value $document -Depth 50
      }
      'change_component_contract' {
        $document = Read-WorkflowIrFixtureJson $componentPath
        $target = @($document.components | Where-Object { [string]$_.component_id -eq 'direct_content_intake' })[0]
        $target.input_selector_refs = [object[]]@('user_supplied_content')
        Write-TaogeUtf8NoBomJson -Path $componentPath -Value $document -Depth 50
      }
      default { throw "fixture_mutation_unknown:$($case.mutation)" }
    }

    $arguments = @(
      '-NoProfile',
      '-ExecutionPolicy', 'Bypass',
      '-File', $compilerPath,
      '-ProjectRoot', $root,
      '-WorkflowIrPath', $irPath,
      '-ComponentCatalogPath', $componentPath,
      '-CompatibilityCatalogPath', $compatibilityPath,
      '-OutputRoot', $outputRoot
    )
    $process = Invoke-TaogeProcessCapture -FilePath $powershellPath -Arguments $arguments -WorkingDirectory $root -AllowNonZeroExit
    $combined = ($process.stdout + "`n" + $process.stderr)
    $actual = if ($process.exit_code -eq 0) { 'pass' } elseif ($process.exit_code -eq 1) { 'fail' } else { 'tool_error' }
    $fingerprintFound = $combined.Contains([string]$case.expected_fingerprint)

    if ([string]$case.expected_result -eq 'pass') {
      $requiredViews = @('current-blueprint-view.json', 'current-stage-view.json', 'current-component-view.json', 'current-compatibility-view.json', 'workflow-ir-parity-report.json')
      $missing = @($requiredViews | Where-Object { -not (Test-Path -LiteralPath (Join-Path $outputRoot $_) -PathType Leaf) })
      if ($missing.Count -gt 0) {
        $actual = 'fail'
        $combined += "`nmissing_views=" + [string]::Join(',', $missing)
      } else {
        $report = Read-WorkflowIrFixtureJson (Join-Path $outputRoot 'workflow-ir-parity-report.json')
        if (
          [string]$report.result -ne 'pass' -or
          [int]$report.route_count -ne 2 -or
          [int]$report.stage_count -ne 7 -or
          [int]$report.current_component_count -ne 35 -or
          [int]$report.historical_blueprint_count -ne 10 -or
          [bool]$report.runtime_switch_enabled
        ) {
          $actual = 'fail'
          $combined += "`npositive_report_contract_invalid"
        }
      }
    } else {
      $unexpectedViews = @('current-blueprint-view.json', 'current-stage-view.json', 'current-component-view.json', 'current-compatibility-view.json') |
        Where-Object { Test-Path -LiteralPath (Join-Path $outputRoot $_) -PathType Leaf }
      if ($unexpectedViews.Count -gt 0) {
        $actual = 'fail'
        $combined += "`nfalse_success_views=" + [string]::Join(',', $unexpectedViews)
      }
      if (-not $fingerprintFound) {
        $actual = 'fail'
        $combined += "`nexpected_fingerprint_missing=$($case.expected_fingerprint)"
      }
    }

    Add-WorkflowIrFixtureResult $results ([string]$case.fixture_id) ([string]$case.expected_result) $actual ([string]$case.expected_fingerprint) $combined.Trim()
  }

  $failed = @($results | Where-Object { [string]$_.fixture_result -ne 'pass' })
  $report = [pscustomobject][ordered]@{
    schema_id = 'taoge://reports/workflow-kernel-m1-fixtures/v0.1'
    schema_version = '0.1'
    fixture_set_id = [string]$fixtureCatalog.fixture_set_id
    result = $(if ($failed.Count -eq 0) { 'pass' } else { 'fail' })
    case_count = $results.Count
    passed_count = $results.Count - $failed.Count
    failed_count = $failed.Count
    windows_powershell_5_1_executed = $true
    network_called = $false
    provider_called = $false
    runtime_switched = $false
    cases = [object[]]$results.ToArray()
  }
  Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 30

  foreach ($result in $results) {
    Write-Output ("$($result.fixture_id) $($result.fixture_result) expected=$($result.expected_result) actual=$($result.actual_result)")
  }
  if ($failed.Count -gt 0) {
    Write-Output ("WORKFLOW_IR_M1_FIXTURE_RESULT=fail failed=$($failed.Count) total=$($results.Count)")
    exit 1
  }
  Write-Output ("WORKFLOW_IR_M1_FIXTURE_RESULT=pass total=$($results.Count)")
  exit 0
} catch {
  Write-Error ('WORKFLOW_IR_M1_FIXTURE_TOOL_ERROR=' + $_.Exception.Message)
  exit 3
}
