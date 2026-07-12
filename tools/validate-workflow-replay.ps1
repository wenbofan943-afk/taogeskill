param(
  [Parameter(Mandatory=$true)][string]$SamplePath,
  [string]$HumanReportPath = '',
  [string]$MachineReportPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')

function Read-FlatYaml {
  param([string]$Path)
  $map = @{}
  $lines = Get-Content -LiteralPath $Path -Encoding UTF8
  foreach ($line in $lines) {
    if ($line -match '^\s*#') { continue }
    if ($line -match '^\s*([A-Za-z0-9_.-]+):\s*(.*)\s*$') {
      $key = $matches[1]
      $value = $matches[2].Trim()
      if (($value.StartsWith([string][char]34) -and $value.EndsWith([string][char]34)) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        $value = $value.Substring(1, $value.Length - 2)
      }
      $map[$key] = $value
    }
  }
  return $map
}

function Get-ExpectedArtifactLines {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return @() }
  $lines = Get-Content -LiteralPath $Path -Encoding UTF8
  $items = New-Object System.Collections.Generic.List[string]
  foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
    if ($trimmed.StartsWith('#') -or $trimmed.StartsWith('```')) { continue }
    $hasDot = $trimmed.IndexOf('.') -ge 0
    $hasNoSpace = $trimmed -notmatch '\s'
    $isNotKeyValueLine = $trimmed.IndexOf(': ') -lt 0
    $isPathLike = $hasDot -and $hasNoSpace -and $isNotKeyValueLine
    $isLogicalUpdate = $trimmed.StartsWith('updated ') -or $trimmed.StartsWith('create ') -or $trimmed.StartsWith('write ')
    if ($isPathLike -or $isLogicalUpdate) {
      $items.Add($trimmed)
    }
  }
  return $items.ToArray()
}

function Get-TraceRows {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return @() }
  $rows = New-Object System.Collections.Generic.List[object]
  $lines = Get-Content -LiteralPath $Path -Encoding UTF8
  foreach ($line in $lines) {
    if ($line -match '^\|\s*\d+\s*\|') {
      $cells = @($line.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
      if ($cells.Count -ge 12) {
        $row = [pscustomobject]@{ step = $cells[0]; action = $cells[1]; expected_skill = $cells[2]; input_artifact = $cells[3]; output_artifact = $cells[4]; artifact_path = $cells[5]; next_skill = $cells[6]; execution_source = $cells[7]; result = $cells[11] }
        $rows.Add($row)
      }
    }
  }
  if ($rows.Count -eq 0) {
    $expected = @($lines | Where-Object { $_ -match '^\s*-\s+[A-Za-z0-9_-]+' } | ForEach-Object { $_.Trim().TrimStart('-').Trim() })
    $i = 0
    foreach ($item in $expected) {
      $i++
      $row = [pscustomobject]@{ step = [string]$i; action = $item; expected_skill = 'declared_trace'; input_artifact = ''; output_artifact = $item; artifact_path = ''; next_skill = ''; execution_source = 'template'; result = 'declared' }
      $rows.Add($row)
    }
  }
  return $rows.ToArray()
}

function Get-ManifestArtifactPaths {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return @() }
  $items = New-Object System.Collections.Generic.List[string]
  $lines = Get-Content -LiteralPath $Path -Encoding UTF8
  foreach ($line in $lines) {
    if ($line -match '^\s+path:\s*(.+?)\s*$') {
      $value = $matches[1].Trim()
      if (($value.StartsWith([string][char]34) -and $value.EndsWith([string][char]34)) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        $value = $value.Substring(1, $value.Length - 2)
      }
      if (-not [string]::IsNullOrWhiteSpace($value)) {
        $items.Add($value)
      }
    }
  }
  return $items.ToArray()
}

function Get-DisplayPath {
  param(
    [string]$Path,
    [string]$BasePath
  )
  if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
  $fullPath = $Path
  if (Test-Path -LiteralPath $Path) {
    $fullPath = (Resolve-Path -LiteralPath $Path).Path
  }
  if ($fullPath -eq $BasePath) { return '.' }
  $prefix = $BasePath.TrimEnd('\') + '\'
  if ($fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $fullPath.Substring($prefix.Length)
  }
  return $Path
}

function Get-AgentAssistLevel {
  param([string]$TracePath)
  if (-not (Test-Path -LiteralPath $TracePath)) { return 'unknown' }
  $text = Get-Content -LiteralPath $TracePath -Raw -Encoding UTF8
  if ($text -match 'agent_assist_level[:：]\s*([A-Za-z0-9_-]+)') {
    $value = $matches[1]
    if ($value -eq 'low_or_medium') { return 'medium' }
    if ($value -match 'high') { return 'high' }
    if ($value -match 'medium|assisted') { return 'medium' }
    if ($value -match 'low') { return 'low' }
    if ($value -match 'none') { return 'none' }
  }
  if ($text -match 'agent_assist_level_expected[:：]\s*([A-Za-z0-9_-]+)') {
    $value = $matches[1]
    if ($value -eq 'low_or_medium') { return 'medium' }
  }
  return 'unknown'
}

try {
  if (-not (Test-Path -LiteralPath $SamplePath)) {
    Write-Error ('SamplePath not found: ' + $SamplePath)
    exit 4
  }
  $sample = (Resolve-Path -LiteralPath $SamplePath).Path
  if ([string]::IsNullOrWhiteSpace($HumanReportPath)) {
    $HumanReportPath = Join-Path $sample 'workflow-replay-report.md'
  }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
    $MachineReportPath = Join-Path $sample 'workflow-replay-report.json'
  }

  $manifestPath = Join-Path $sample 'manifest.yaml'
  $expectedArtifactsPath = Join-Path $sample 'expected-artifacts.md'
  $tracePath = Join-Path $sample 'execution-trace.md'
  if (-not (Test-Path -LiteralPath $tracePath)) {
    $tracePath = Join-Path $sample 'intermediate\00-execution-trace.md'
  }
  $sampleDisplayPath = Get-DisplayPath $sample $sample
  $manifestDisplayPath = Get-DisplayPath $manifestPath $sample
  $expectedArtifactsDisplayPath = Get-DisplayPath $expectedArtifactsPath $sample
  $traceDisplayPath = Get-DisplayPath $tracePath $sample

  $blockers = New-Object System.Collections.Generic.List[string]
  $warnings = New-Object System.Collections.Generic.List[string]
  $stepResults = New-Object System.Collections.Generic.List[object]

  if (-not (Test-Path -LiteralPath $manifestPath)) { $blockers.Add('manifest_missing') }
  if (-not (Test-Path -LiteralPath $tracePath)) { $blockers.Add('execution_trace_missing') }

  $manifest = @{}
  if (Test-Path -LiteralPath $manifestPath) { $manifest = Read-FlatYaml $manifestPath }
  $sampleId = if ($manifest.ContainsKey('sample_id')) { $manifest['sample_id'] } elseif ($manifest.ContainsKey('session_id')) { $manifest['session_id'] } else { Split-Path -Leaf $sample }
  $runMode = if ($manifest.ContainsKey('run_mode')) { $manifest['run_mode'] } else { 'trace_replay_readonly' }
  $sampleOnly = if ($manifest.ContainsKey('sample_only')) { $manifest['sample_only'] } else { 'unknown' }
  $materializationRequired = -not ($sample -match '\\examples\\sample-\d{2}-')

  $expectedLines = @()
  if (Test-Path -LiteralPath $expectedArtifactsPath) {
    $expectedLines = @(Get-ExpectedArtifactLines $expectedArtifactsPath)
  } elseif (Test-Path -LiteralPath $manifestPath) {
    $expectedLines = @(Get-ManifestArtifactPaths $manifestPath)
    if ($expectedLines.Count -gt 0) {
      $warnings.Add('expected_artifacts_missing_using_manifest_artifacts')
    } else {
      $blockers.Add('expected_artifacts_missing')
    }
  } else {
    $blockers.Add('expected_artifacts_missing')
  }
  $missingArtifacts = New-Object System.Collections.Generic.List[string]
  $declaredOnlyArtifacts = New-Object System.Collections.Generic.List[string]
  foreach ($item in $expectedLines) {
    if ($item -match '^(updated|create|write)\s+(.+)$') {
      $declaredOnlyArtifacts.Add($item)
      continue
    }
    if ($item.Contains('{') -or $item.Contains('}')) {
      $declaredOnlyArtifacts.Add($item)
      continue
    }
    $candidate = Join-Path $sample $item
    if (Test-Path -LiteralPath $candidate) {
      $stepResults.Add([pscustomobject]@{ check = 'artifact_exists'; item = $item; status = 'pass' })
    } elseif ($materializationRequired) {
      $missingArtifacts.Add($item)
    } else {
      $declaredOnlyArtifacts.Add($item)
    }
  }
  if ($missingArtifacts.Count -gt 0) {
    foreach ($item in $missingArtifacts) { $blockers.Add('missing_artifact:' + $item) }
  }
  if ($declaredOnlyArtifacts.Count -gt 0) {
    $warnings.Add('declared_only_artifacts:' + $declaredOnlyArtifacts.Count)
  }

  $traceRows = @(Get-TraceRows $tracePath)
  if ($traceRows.Count -eq 0) {
    $warnings.Add('trace_has_no_step_rows')
  }
  $passedStepCount = 0
  $warningStepCount = 0
  $failedStepCount = 0
  foreach ($row in $traceRows) {
    $status = 'pass'
    if ($row.result -match 'warning|declared|scope') { $status = 'warn' }
    if ($row.result -match 'fail|blocked') { $status = 'fail' }
    if ($status -eq 'pass') { $passedStepCount++ }
    elseif ($status -eq 'warn') { $warningStepCount++ }
    else { $failedStepCount++ }
    $stepResults.Add([pscustomobject]@{ check = 'trace_step'; step = $row.step; action = $row.action; expected_skill = $row.expected_skill; output_artifact = $row.output_artifact; artifact_path = $row.artifact_path; result = $row.result; status = $status })
  }
  if ($failedStepCount -gt 0) { $blockers.Add('trace_step_failed:' + $failedStepCount) }
  if ($warningStepCount -gt 0) { $warnings.Add('trace_step_warnings:' + $warningStepCount) }

  $agentAssist = Get-AgentAssistLevel $tracePath
  if ($agentAssist -in @('medium', 'high', 'unknown')) {
    $warnings.Add('agent_assist_level_observed:' + $agentAssist)
  }

  $overall = 'pass'
  if ($blockers.Count -gt 0) { $overall = 'fail' }
  elseif ($warnings.Count -gt 0) { $overall = 'pass_with_warnings' }

  $evidenceStatus = if ($blockers.Count -gt 0) { 'insufficient' } elseif ($warnings.Count -gt 0) { 'partial' } else { 'sufficient' }
  $maturityImpact = if ($overall -eq 'pass') { 'can_support_l3_candidate' } elseif ($overall -eq 'pass_with_warnings') { 'supports_l2_8_or_l3_candidate_with_warnings' } else { 'not_maturity_evidence' }
  $exitCode = if ($blockers.Count -gt 0) { 1 } else { 0 }

  if ($overall -eq 'fail') {
    $nextAction = 'fix_replay_blockers'
  } elseif ($overall -eq 'pass_with_warnings') {
    $nextAction = 'review_warnings_before_l3_claim'
  } else {
    $nextAction = 'eligible_for_regression_fixture'
  }

  $report = [ordered]@{
    workflow_replay_report = [ordered]@{
      replay_report_id = 'REPLAY-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
      runner_id = 'workflow_runner_lite'
      runner_version = '0.1.0'
      replay_mode = 'trace_replay_readonly'
      sample_id = $sampleId
      sample_path = $sampleDisplayPath
      manifest_path = $manifestDisplayPath
      trace_path = $traceDisplayPath
      expected_artifacts_path = $expectedArtifactsDisplayPath
      overall_result = $overall
      blocker_count = $blockers.Count
      warning_count = $warnings.Count
      step_count = $traceRows.Count
      passed_step_count = $passedStepCount
      warning_step_count = $warningStepCount
      failed_step_count = $failedStepCount
      agent_assist_level_observed = $agentAssist
      replay_evidence_status = $evidenceStatus
      missing_artifacts = [object[]]@($missingArtifacts)
      declared_only_artifacts = [object[]]@($declaredOnlyArtifacts)
      unexpected_artifacts = @()
      blocker_reasons = [object[]]@($blockers)
      warning_reasons = [object[]]@($warnings)
      step_results = [object[]]$stepResults.ToArray()
      maturity_impact = $maturityImpact
      next_action = $nextAction
      artifact_path = (Split-Path -Leaf $HumanReportPath)
      sample_only = $sampleOnly
      run_mode = $runMode
    }
  }
  Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 8

  $lines = @('# Workflow Replay Report', '', '```yaml')
  $lines += 'runner_id: workflow_runner_lite'
  $lines += 'runner_version: 0.1.0'
  $lines += 'replay_mode: trace_replay_readonly'
  $lines += 'sample_id: ' + $sampleId
  $lines += 'exit_code: ' + $exitCode
  $lines += 'overall_result: ' + $overall
  $lines += 'blocker_count: ' + $blockers.Count
  $lines += 'warning_count: ' + $warnings.Count
  $lines += 'agent_assist_level_observed: ' + $agentAssist
  $lines += 'replay_evidence_status: ' + $evidenceStatus
  $lines += '```'
  $lines += ''
  $lines += '## Evidence'
  $lines += ''
  $lines += '- manifest_path: ' + $manifestDisplayPath
  $lines += '- trace_path: ' + $traceDisplayPath
  $lines += '- expected_artifacts_path: ' + $expectedArtifactsDisplayPath
  $lines += '- step_count: ' + $traceRows.Count
  $lines += '- declared_only_artifacts: ' + $declaredOnlyArtifacts.Count
  $lines += '- missing_artifacts: ' + $missingArtifacts.Count
  $lines += ''
  $lines += '## Blockers'
  $lines += ''
  if ($blockers.Count -eq 0) { $lines += 'None' } else { foreach ($item in $blockers) { $lines += '- ' + $item } }
  $lines += ''
  $lines += '## Warnings'
  $lines += ''
  if ($warnings.Count -eq 0) { $lines += 'None' } else { foreach ($item in $warnings) { $lines += '- ' + $item } }
  $lines += ''
  $lines += '## Result'
  $lines += ''
  $lines += 'This is a readonly replay. It does not execute AI writing, research, image generation, publishing, or artifact repair.'
  Write-TaogeUtf8NoBomLines -Path $HumanReportPath -Lines $lines

  Write-Output ('WORKFLOW_REPLAY_RESULT=' + $overall)
  exit $exitCode
} catch {
  Write-Error ('{0} at line {1}: {2}' -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
