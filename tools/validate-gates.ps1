param(
  [string]$ProjectRoot = '',
  [string]$GateName = '',
  [string]$HumanReportPath = '',
  [string]$MachineReportPath = ''
)

$ErrorActionPreference = 'Stop'

function Add-GateCheck {
  param(
    [System.Collections.Generic.List[object]]$Checks,
    [string]$Id,
    [string]$Status,
    [string]$Evidence,
    [string]$Remediation
  )
  $Checks.Add([pscustomobject]@{
    check_item_id = $Id
    status = $Status
    evidence = $Evidence
    remediation = $Remediation
  })
}

try {
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
  }
  $root = (Resolve-Path -LiteralPath $ProjectRoot).Path
  $defaultReportDir = Join-Path $root "state\checks"

  if ([string]::IsNullOrWhiteSpace($HumanReportPath)) {
    $HumanReportPath = Join-Path $defaultReportDir "gate-check-report.md"
  }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
    $MachineReportPath = Join-Path $defaultReportDir "gate-check-report.json"
  }

  @($HumanReportPath, $MachineReportPath) | ForEach-Object {
    $reportDir = Split-Path -Parent $_
    if (-not [string]::IsNullOrWhiteSpace($reportDir) -and -not (Test-Path -LiteralPath $reportDir)) {
      New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
  }

  $checks = New-Object System.Collections.Generic.List[object]
  $checkRunId = "GATE-" + (Get-Date -Format "yyyyMMdd-HHmmss")

  $allGates = @('state_consistency_gate', 'branch_lock_gate', 'field_gate', 'sample_only_gate', 'public_privacy_gate', 'compute_route_gate')
  $targetGates = if ([string]::IsNullOrWhiteSpace($GateName)) { $allGates } else { @($GateName) }

  foreach ($gate in $targetGates) {
    switch ($gate) {
      'state_consistency_gate' {
        $statePath = Join-Path $root 'state/current-state.yaml'
        if (Test-Path -LiteralPath $statePath) {
          $stateContent = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8
          if ($stateContent -match 'latest_main_commit_known:\s*([a-f0-9]+)') {
            $recordedCommit = $matches[1]
            $actualCommit = & git -C $root rev-parse HEAD 2>$null
            if ($LASTEXITCODE -eq 0) {
              & git -C $root merge-base --is-ancestor $recordedCommit $actualCommit 2>$null
              $status = if ($LASTEXITCODE -eq 0) { 'pass' } else { 'fail' }
              Add-GateCheck $checks 'STATE-001' $status "recorded_ancestor=$recordedCommit actual=$actualCommit" "Update state/current-state.yaml if the recorded commit is not an ancestor of HEAD."
            } else {
              Add-GateCheck $checks 'STATE-001' 'fail' 'git rev-parse failed' 'Fix Git availability.'
            }
          } else {
            Add-GateCheck $checks 'STATE-001' 'fail' 'latest_main_commit_known missing' 'Add latest_main_commit_known to state/current-state.yaml.'
          }
        } else {
          Add-GateCheck $checks 'STATE-001' 'fail' 'state/current-state.yaml missing' 'Create state/current-state.yaml.'
        }

        $manifestPath = Join-Path $root '工作流状态记录.md'
        $manifestTemplatePath = Join-Path $root 'templates/state/工作流状态记录.template.md'
        if (Test-Path -LiteralPath $manifestPath) {
          Add-GateCheck $checks 'STATE-002' 'pass' '工作流状态记录.md exists' 'State record available.'
        } elseif (Test-Path -LiteralPath $manifestTemplatePath) {
          Add-GateCheck $checks 'STATE-002' 'pass' 'Local state not initialized; template exists' 'Initialize 工作流状态记录.md from the template before a real content run.'
        } else {
          Add-GateCheck $checks 'STATE-002' 'fail' 'Local state and template are both missing' 'Restore templates/state/工作流状态记录.template.md.'
        }
      }

      'branch_lock_gate' {
        $branchLockPath = Join-Path $root 'state/branch-lock.yaml'
        if (Test-Path -LiteralPath $branchLockPath) {
          $lockContent = Get-Content -LiteralPath $branchLockPath -Raw -Encoding UTF8
          if ($lockContent -match 'locked:\s*(true|false)') {
            $locked = $matches[1] -eq 'true'
            $status = if ($locked) { 'blocked' } else { 'pass' }
            Add-GateCheck $checks 'BRANCH-001' $status "branch_locked=$locked" 'Check branch lock before multi-branch run.'
          } else {
            Add-GateCheck $checks 'BRANCH-001' 'fail' 'locked field missing' 'Add locked field to state/branch-lock.yaml.'
          }
        } else {
          Add-GateCheck $checks 'BRANCH-001' 'pass' 'No branch lock file, proceeding' 'Branch lock is optional.'
        }
      }

      'field_gate' {
        $fieldSchemaPath = Join-Path $root 'templates/schema/field-schema.v0.1.json'
        if (Test-Path -LiteralPath $fieldSchemaPath) {
          Add-GateCheck $checks 'FIELD-001' 'pass' 'field-schema.v0.1.json exists' 'Field schema available.'
        } else {
          Add-GateCheck $checks 'FIELD-001' 'fail' 'field-schema.v0.1.json missing' 'Create templates/schema/field-schema.v0.1.json.'
        }

        $fieldDictPath = Join-Path $root '交接物字段词典.md'
        if (Test-Path -LiteralPath $fieldDictPath) {
          Add-GateCheck $checks 'FIELD-002' 'pass' '交接物字段词典.md exists' 'Field dictionary available.'
        } else {
          Add-GateCheck $checks 'FIELD-002' 'fail' '交接物字段词典.md missing' 'Create 交接物字段词典.md.'
        }
      }

      'sample_only_gate' {
        $examplesDir = Join-Path $root 'examples'
        if (Test-Path -LiteralPath $examplesDir) {
          $sampleDirs = @(Get-ChildItem -LiteralPath $examplesDir -Directory -Filter 'sample-*' -ErrorAction SilentlyContinue)
          if ($sampleDirs.Count -gt 0) {
            Add-GateCheck $checks 'SAMPLE-001' 'pass' "sample_dirs=$($sampleDirs.Count)" 'Sample directories available.'
          } else {
            Add-GateCheck $checks 'SAMPLE-001' 'fail' 'No sample-* directories' 'Create sample directories in examples/.'
          }
        } else {
          Add-GateCheck $checks 'SAMPLE-001' 'fail' 'examples/ directory missing' 'Create examples/ directory.'
        }

        $accountsDir = Join-Path $root 'accounts'
        if (Test-Path -LiteralPath $accountsDir) {
          Add-GateCheck $checks 'SAMPLE-002' 'warning' 'accounts/ exists in test profile' 'Ensure test runs only use examples/, not real accounts.'
        } else {
          Add-GateCheck $checks 'SAMPLE-002' 'pass' 'No accounts/ directory' 'No real account data in test profile.'
        }
      }

      'public_privacy_gate' {
        $gitTracked = @(& git -C $root ls-files 'accounts' 'indexes' 2>$null)
        if ($LASTEXITCODE -eq 0) {
          $status = if ($gitTracked.Count -eq 0) { 'pass' } else { 'fail' }
          $evidence = if ($gitTracked.Count -eq 0) { 'no tracked private paths' } else { "tracked=$($gitTracked.Count)" }
          Add-GateCheck $checks 'PRIVACY-001' $status $evidence 'Remove real accounts/ and indexes/ from Git tracking.'
        } else {
          Add-GateCheck $checks 'PRIVACY-001' 'fail' 'git ls-files failed' 'Fix Git availability.'
        }

        $envVars = @('GITHUB_TOKEN')
        foreach ($var in $envVars) {
          $envValue = [Environment]::GetEnvironmentVariable($var)
          if ([string]::IsNullOrWhiteSpace($envValue)) {
            Add-GateCheck $checks "PRIVACY-002-$var" 'warning' "$var not set" 'Consider setting environment variable.'
          } else {
            Add-GateCheck $checks "PRIVACY-002-$var" 'pass' "$var is set" 'Environment variable available.'
          }
        }
      }

      'compute_route_gate' {
        $checkerPath = Join-Path $root 'tools/validate-compute-routing.ps1'
        if (-not (Test-Path -LiteralPath $checkerPath -PathType Leaf)) {
          Add-GateCheck $checks 'COMPUTE-GATE-001' 'fail' 'compute routing checker missing' 'Restore tools/validate-compute-routing.ps1.'
          break
        }
        $computeHuman = Join-Path $defaultReportDir 'compute-routing-check-report.md'
        $computeMachine = Join-Path $defaultReportDir 'compute-routing-check-report.json'
        & powershell -NoProfile -ExecutionPolicy Bypass -File $checkerPath -ProjectRoot $root -HumanReportPath $computeHuman -MachineReportPath $computeMachine | Out-Null
        $computeExit = $LASTEXITCODE
        Add-GateCheck $checks 'COMPUTE-GATE-001' $(if ($computeExit -eq 0) { 'pass' } else { 'fail' }) "compute_checker_exit=$computeExit" 'Run tools/validate-compute-routing.ps1 and fix the reported mismatch.'
      }

      default {
        Add-GateCheck $checks "GATE-UNKNOWN-$gate" 'fail' "unknown_gate=$gate" 'Implement the gate in tools/validate-gates.ps1 before referencing it as executable.'
      }
    }
  }

  $failed = @($checks | Where-Object { $_.status -eq 'fail' })
  $blocked = @($checks | Where-Object { $_.status -eq 'blocked' })
  $overall = if ($failed.Count -gt 0) { 'fail' } elseif ($blocked.Count -gt 0) { 'blocked' } else { 'pass' }
  $exitCode = if ($failed.Count -gt 0) { 1 } elseif ($blocked.Count -gt 0) { 2 } else { 0 }

  $report = [ordered]@{
    gate_check_report = [ordered]@{
      check_run_id = $checkRunId
      gates_checked = $targetGates
      overall_result = $overall
      exit_code = $exitCode
      fail_count = $failed.Count
      blocked_count = $blocked.Count
      checks = [object[]]$checks.ToArray()
    }
  }
  $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $MachineReportPath -Encoding UTF8

  $lines = @('# Gate Check Report', '', '```yaml')
  $lines += "check_run_id: $checkRunId"
  $lines += "gates_checked: $([string]::Join(', ', $targetGates))"
  $lines += "overall_result: $overall"
  $lines += "exit_code: $exitCode"
  $lines += "fail_count: $($failed.Count)"
  $lines += "blocked_count: $($blocked.Count)"
  $lines += '```'
  $lines += ''
  $lines += '| Check ID | Status | Evidence | Remediation |'
  $lines += '|---|---|---|---|'
  foreach ($check in $checks) {
    $lines += "| $($check.check_item_id) | $($check.status) | $($check.evidence) | $($check.remediation) |"
  }
  $lines | Set-Content -LiteralPath $HumanReportPath -Encoding UTF8

  Write-Output "GATE_CHECK_RESULT=$overall"
  exit $exitCode
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
