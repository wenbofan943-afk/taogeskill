param(
  [string]$WorkflowPath = '.github\workflows\public-release-candidate-check.yml',
  [string]$HumanReportPath = '',
  [string]$MachineReportPath = ''
)

$ErrorActionPreference = 'Stop'

function Add-Check {
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
  $projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
  $workflowFullPath = Join-Path $projectRoot $WorkflowPath
  $defaultReportDir = Join-Path $projectRoot 'state\checks'
  if ([string]::IsNullOrWhiteSpace($HumanReportPath)) {
    $HumanReportPath = Join-Path $defaultReportDir 'ci-workflow-check-report.md'
  }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
    $MachineReportPath = Join-Path $defaultReportDir 'ci-workflow-check-report.json'
  }
  @($HumanReportPath, $MachineReportPath) | ForEach-Object {
    $reportDir = Split-Path -Parent $_
    if (-not [string]::IsNullOrWhiteSpace($reportDir) -and -not (Test-Path -LiteralPath $reportDir)) {
      New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
  }

  $checks = New-Object System.Collections.Generic.List[object]
  if (-not (Test-Path -LiteralPath $workflowFullPath)) {
    Add-Check $checks 'CI-001' 'fail' $WorkflowPath 'Add public-release-candidate-check workflow.'
  } else {
    Add-Check $checks 'CI-001' 'pass' $WorkflowPath 'Workflow exists.'
    $text = Get-Content -LiteralPath $workflowFullPath -Raw -Encoding UTF8

    $requiredNeedles = @(
      'permissions:',
      'contents: read',
      'actions/checkout@v4',
      'validate-final-delivery-template.ps1',
      'validate-cover-composition.ps1',
      'validate-regression-suite.ps1',
      'build-public-release.ps1',
      'validate-public-release.ps1',
      'workflow_dispatch',
      'pull_request'
    )
    foreach ($needle in $requiredNeedles) {
      $status = if ($text.Contains($needle)) { 'pass' } else { 'fail' }
      Add-Check $checks ('CI-REQ-' + ($needle -replace '[^A-Za-z0-9]+','_')) $status $needle 'Add required CI validation step or trigger.'
    }

    $forbiddenPatterns = @(
      'softprops/action-gh-release',
      'gh release',
      'git push',
      'git tag',
      'contents: write',
      'packages: write',
      'id-token: write',
      'secrets\.',
      'publish',
      'deploy'
    )
    foreach ($pattern in $forbiddenPatterns) {
      $hit = $text -match $pattern
      $status = if ($hit) { 'fail' } else { 'pass' }
      Add-Check $checks ('CI-FORBID-' + ($pattern -replace '[^A-Za-z0-9]+','_')) $status $pattern 'Keep CI validation-only; do not publish, tag, push, deploy, or use secrets.'
    }
  }

  $failed = @($checks | Where-Object { $_.status -eq 'fail' })
  $overall = if ($failed.Count -gt 0) { 'fail' } else { 'pass' }
  $exitCode = if ($failed.Count -gt 0) { 1 } else { 0 }
  $report = [ordered]@{
    ci_workflow_check_report = [ordered]@{
      check_report_id = 'CI-CHECK-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
      workflow_path = $WorkflowPath
      command_name = 'validate-ci-workflow'
      command_version = '0.1.0'
      exit_code = $exitCode
      overall_result = $overall
      blocker_count = $failed.Count
      checks = [object[]]$checks.ToArray()
    }
  }
  $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $MachineReportPath -Encoding UTF8

  $lines = @('# CI Workflow Check Report', '', '```yaml')
  $lines += 'workflow_path: ' + $WorkflowPath
  $lines += 'exit_code: ' + $exitCode
  $lines += 'overall_result: ' + $overall
  $lines += 'blocker_count: ' + $failed.Count
  $lines += '```'
  $lines += ''
  $lines += '| Check ID | Status | Evidence | Remediation |'
  $lines += '|---|---|---|---|'
  foreach ($check in $checks) {
    $lines += ('| {0} | {1} | {2} | {3} |' -f $check.check_item_id, $check.status, $check.evidence, $check.remediation)
  }
  $lines | Set-Content -LiteralPath $HumanReportPath -Encoding UTF8

  Write-Output ('CI_WORKFLOW_CHECK=' + $overall)
  exit $exitCode
} catch {
  Write-Error ('{0} at line {1}: {2}' -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
