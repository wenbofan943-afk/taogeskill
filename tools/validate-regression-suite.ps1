param(
  [string]$SuitePath = 'examples\regression-suite.yaml',
  [string]$HumanReportPath = '',
  [string]$MachineReportPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')

function Read-SuiteManifest {
  param([string]$Path)
  $suite = [ordered]@{
    regression_suite_id = ''
    suite_version = ''
    runner_id = 'regression_suite_checker'
    runner_version = '0.1.0'
    sample_validator = 'tools/validate-sample-run.ps1'
    replay_validator = 'tools/validate-workflow-replay.ps1'
    allowed_warning_policy = 'explicit_allowlist'
    fixtures = New-Object System.Collections.Generic.List[object]
  }
  $current = $null
  $inAllowed = $false
  $lines = Get-Content -LiteralPath $Path -Encoding UTF8
  foreach ($line in $lines) {
    if ($line -match '^\s*#') { continue }
    if ($line -match '^\s*-\s+fixture_id:\s*(\S+)\s*$') {
      if ($null -ne $current) { $suite.fixtures.Add([pscustomobject]$current) }
      $current = [ordered]@{ fixture_id = $matches[1]; allowed_warning_prefixes = New-Object System.Collections.Generic.List[string] }
      $inAllowed = $false
      continue
    }
    if ($null -ne $current -and $line -match '^\s+([A-Za-z0-9_.-]+):\s*(.*?)\s*$') {
      $key = $matches[1]
      $value = $matches[2].Trim().Trim('"').Trim("'")
      if ($key -eq 'allowed_warning_prefixes') {
        $inAllowed = $true
      } else {
        $current[$key] = $value
        $inAllowed = $false
      }
      continue
    }
    if ($null -ne $current -and $inAllowed -and $line -match '^\s*-\s+(.+?)\s*$') {
      $current.allowed_warning_prefixes.Add($matches[1].Trim())
      continue
    }
    if ($line -match '^\s*([A-Za-z0-9_.-]+):\s*(.*?)\s*$') {
      $key = $matches[1]
      $value = $matches[2].Trim().Trim('"').Trim("'")
      if ($suite.Contains($key) -and $key -ne 'fixtures') { $suite[$key] = $value }
      $inAllowed = $false
    }
  }
  if ($null -ne $current) { $suite.fixtures.Add([pscustomobject]$current) }
  return $suite
}

function Test-WarningAllowed {
  param(
    [string]$Warning,
    [string[]]$AllowedPrefixes
  )
  foreach ($prefix in $AllowedPrefixes) {
    if ($Warning.StartsWith($prefix)) { return $true }
  }
  return $false
}

try {
  $projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
  $suiteFullPath = Join-Path $projectRoot $SuitePath
  if (-not (Test-Path -LiteralPath $suiteFullPath)) {
    Write-Error ('SuitePath not found: ' + $SuitePath)
    exit 2
  }
  $suite = Read-SuiteManifest $suiteFullPath
  $runtimeReportRoot = Join-Path $projectRoot 'state/checks/regression-suite'
  New-Item -ItemType Directory -Path $runtimeReportRoot -Force | Out-Null
  if ([string]::IsNullOrWhiteSpace($HumanReportPath)) {
    $HumanReportPath = Join-Path $runtimeReportRoot 'regression-suite-report.md'
  }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
    $MachineReportPath = Join-Path $runtimeReportRoot 'regression-suite-report.json'
  }

  $sampleValidator = Join-Path $projectRoot $suite.sample_validator
  $replayValidator = Join-Path $projectRoot $suite.replay_validator
  if (-not (Test-Path -LiteralPath $sampleValidator)) {
    Write-Error ('sample_validator not found: ' + $suite.sample_validator)
    exit 2
  }
  if (-not (Test-Path -LiteralPath $replayValidator)) {
    Write-Error ('replay_validator not found: ' + $suite.replay_validator)
    exit 2
  }

  $fixtureResults = New-Object System.Collections.Generic.List[object]
  $blockers = New-Object System.Collections.Generic.List[string]
  $warnings = New-Object System.Collections.Generic.List[string]
  $passed = 0
  $warned = 0
  $failed = 0

  foreach ($fixture in $suite.fixtures) {
    $samplePath = Join-Path $projectRoot $fixture.sample_path
    $fixtureWarnings = New-Object System.Collections.Generic.List[string]
    $fixtureBlockers = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $samplePath)) {
      $fixtureBlockers.Add('sample_path_missing')
    }

    $sampleExit = 99
    $replayExit = 99
    $fixtureReportRoot = Join-Path $runtimeReportRoot $fixture.fixture_id
    New-Item -ItemType Directory -Path $fixtureReportRoot -Force | Out-Null
    $sampleHumanReportPath = Join-Path $fixtureReportRoot 'check-report.md'
    $sampleReportPath = Join-Path $fixtureReportRoot 'sample-check-report.json'
    $replayHumanReportPath = Join-Path $fixtureReportRoot 'workflow-replay-report.md'
    $replayReportPath = Join-Path $fixtureReportRoot 'workflow-replay-report.json'
    if ($fixtureBlockers.Count -eq 0) {
      & $sampleValidator -SamplePath $samplePath -HumanReportPath $sampleHumanReportPath -MachineReportPath $sampleReportPath | Out-Null
      $sampleExit = $LASTEXITCODE
      & $replayValidator -SamplePath $samplePath -HumanReportPath $replayHumanReportPath -MachineReportPath $replayReportPath | Out-Null
      $replayExit = $LASTEXITCODE
    }

    if ($sampleExit -ne 0) { $fixtureBlockers.Add('sample_validator_exit:' + $sampleExit) }
    if ($replayExit -ne 0) { $fixtureBlockers.Add('replay_validator_exit:' + $replayExit) }

    $replayOverall = 'unknown'
    $replayWarningReasons = @()
    if (Test-Path -LiteralPath $replayReportPath) {
      $replayReport = Get-Content -LiteralPath $replayReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $replayOverall = $replayReport.workflow_replay_report.overall_result
      $replayWarningReasons = @($replayReport.workflow_replay_report.warning_reasons)
      if ([int]$replayReport.workflow_replay_report.blocker_count -gt 0) {
        $fixtureBlockers.Add('replay_blocker_count:' + $replayReport.workflow_replay_report.blocker_count)
      }
    } else {
      $fixtureBlockers.Add('workflow_replay_report_missing')
    }
    if (-not (Test-Path -LiteralPath $sampleReportPath)) {
      $fixtureBlockers.Add('sample_check_report_missing')
    }

    $allowedPrefixes = [string[]]@($fixture.allowed_warning_prefixes.ToArray())
    foreach ($warning in $replayWarningReasons) {
      if (Test-WarningAllowed $warning $allowedPrefixes) {
        $fixtureWarnings.Add($warning)
      } else {
        $fixtureBlockers.Add('unregistered_warning:' + $warning)
      }
    }

    $fixtureStatus = 'pass'
    if ($fixtureBlockers.Count -gt 0) {
      $fixtureStatus = 'fail'
      $failed++
      foreach ($item in $fixtureBlockers) { $blockers.Add($fixture.fixture_id + ':' + $item) }
    } elseif ($fixtureWarnings.Count -gt 0) {
      $fixtureStatus = 'pass_with_warnings'
      $warned++
      foreach ($item in $fixtureWarnings) { $warnings.Add($fixture.fixture_id + ':' + $item) }
    } else {
      $passed++
    }

    $fixtureResults.Add([pscustomobject]@{
      fixture_id = $fixture.fixture_id
      sample_id = $fixture.sample_id
      sample_path = $fixture.sample_path
      regression_goal = $fixture.regression_goal
      sample_exit_code = $sampleExit
      replay_exit_code = $replayExit
      replay_result = $replayOverall
      fixture_result = $fixtureStatus
      warning_reasons = [object[]]@($fixtureWarnings)
      blocker_reasons = [object[]]@($fixtureBlockers)
    })
  }

  $overall = 'pass'
  if ($blockers.Count -gt 0) { $overall = 'fail' }
  elseif ($warnings.Count -gt 0) { $overall = 'pass_with_warnings' }
  $exitCode = if ($blockers.Count -gt 0) { 1 } else { 0 }
  $maturityImpact = if ($overall -eq 'pass') { 'regression_fixture_ready' } elseif ($overall -eq 'pass_with_warnings') { 'regression_fixture_ready_with_warnings' } else { 'not_regression_evidence' }
  $nextAction = if ($overall -eq 'fail') { 'fix_regression_fixture_blockers' } elseif ($overall -eq 'pass_with_warnings') { 'review_allowed_warnings_before_ci' } else { 'eligible_for_ci_candidate' }

  $report = [ordered]@{
    regression_suite_report = [ordered]@{
      regression_suite_report_id = 'REG-SUITE-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
      suite_id = $suite.regression_suite_id
      suite_version = $suite.suite_version
      suite_manifest_path = 'examples/regression-suite.yaml'
      runner_id = $suite.runner_id
      runner_version = $suite.runner_version
      fixture_count = $suite.fixtures.Count
      passed_fixture_count = $passed
      warning_fixture_count = $warned
      failed_fixture_count = $failed
      overall_result = $overall
      blocker_count = $blockers.Count
      warning_count = $warnings.Count
      allowed_warning_policy = $suite.allowed_warning_policy
      fixture_results = [object[]]$fixtureResults.ToArray()
      maturity_impact = $maturityImpact
      next_action = $nextAction
      artifact_path = 'state/checks/regression-suite/regression-suite-report.md'
      machine_readable_report_path = 'state/checks/regression-suite/regression-suite-report.json'
    }
  }
  Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 8

  $lines = @('# Regression Suite Report', '', '```yaml')
  $lines += 'suite_id: ' + $suite.regression_suite_id
  $lines += 'suite_version: ' + $suite.suite_version
  $lines += 'runner_id: ' + $suite.runner_id
  $lines += 'exit_code: ' + $exitCode
  $lines += 'overall_result: ' + $overall
  $lines += 'fixture_count: ' + $suite.fixtures.Count
  $lines += 'blocker_count: ' + $blockers.Count
  $lines += 'warning_count: ' + $warnings.Count
  $lines += 'maturity_impact: ' + $maturityImpact
  $lines += '```'
  $lines += ''
  $lines += '| Fixture | Sample | Result | Replay | Warnings | Blockers |'
  $lines += '|---|---|---|---|---|---|'
  foreach ($item in $fixtureResults) {
    $lines += ('| {0} | {1} | {2} | {3} | {4} | {5} |' -f $item.fixture_id, $item.sample_id, $item.fixture_result, $item.replay_result, ([string]::Join('; ', @($item.warning_reasons))), ([string]::Join('; ', @($item.blocker_reasons))))
  }
  $lines += ''
  $lines += '## Result'
  $lines += ''
  $lines += 'This suite is readonly. It runs sample checks and trace replay, but it does not execute AI writing, research, image generation, publishing, or artifact repair.'
  Write-TaogeUtf8NoBomLines -Path $HumanReportPath -Lines $lines

  Write-Output ('REGRESSION_SUITE_RESULT=' + $overall)
  exit $exitCode
} catch {
  Write-Error ('{0} at line {1}: {2}' -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
