param(
  [string]$WorkflowPath = '.github\workflows\public-release-candidate-check.yml',
  [string]$HumanReportPath = '',
  [string]$MachineReportPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')

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
      'validate-r3-visual-text.ps1',
      'validate-r3-visual-presentation.ps1',
      'validate-p0-h7-v04-fixtures.ps1',
      'validate-regression-suite.ps1',
      'invoke-windows-clean-room-matrix.ps1',
      'invoke-windows-certification-probe.ps1',
      'validate-windows-certification.ps1',
      'actions/upload-artifact@v4',
      'if: always()',
      'windows-clean-room-matrix-report.*',
      '-Mode full',
      '-RequiredAxis',
      'powershell.exe',
      'windows-2022',
      'windows-2025',
      'windows-11-arm',
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
      'deploy',
      'continue-on-error'
    )
    foreach ($pattern in $forbiddenPatterns) {
      $hit = $text -match $pattern
      $status = if ($hit) { 'fail' } else { 'pass' }
      Add-Check $checks ('CI-FORBID-' + ($pattern -replace '[^A-Za-z0-9]+','_')) $status $pattern 'Keep CI validation-only; do not publish, tag, push, deploy, or use secrets.'
    }

    $hardcodedReleasePath = $text -match 'releases[\\/]+v\d+\.\d+\.\d+'
    Add-Check $checks 'CI-FORBID-HARDCODED-RELEASE-PATH' $(if ($hardcodedReleasePath) { 'fail' } else { 'pass' }) 'releases/v{literal-version}' 'Let build and validation scripts resolve VERSION; do not pin CI to an old release directory.'

    $builderText = Get-Content -LiteralPath (Join-Path $projectRoot 'tools\build-public-release.ps1') -Raw -Encoding UTF8
    $runtimeHelperText = Get-Content -LiteralPath (Join-Path $projectRoot 'tools\WindowsRuntimeHelper.ps1') -Raw -Encoding UTF8
    $quotePathSafe = $builderText.Contains('Get-TaogeGitTrackedPathsUtf8') -and $runtimeHelperText.Contains('core.quotepath=false') -and $runtimeHelperText.Contains("'--cached','-z'") -and $runtimeHelperText.Contains('StandardOutputEncoding = $utf8')
    Add-Check $checks 'CI-REQ-GIT-UNICODE-PATHS' $(if ($quotePathSafe) { 'pass' } else { 'fail' }) 'NUL-separated Git paths with explicit UTF-8 stream decoding' 'Keep tracked-file discovery stable for Chinese paths on clean GitHub runners.'
    $matrixDefinitionPath = Join-Path $projectRoot 'examples\windows-clean-room-matrix\matrix.json'
    $matrixDefinitionPresent = Test-Path -LiteralPath $matrixDefinitionPath -PathType Leaf
    Add-Check $checks 'CI-REQ-WINDOWS-CLEAN-ROOM-DEFINITION' $(if ($matrixDefinitionPresent) { 'pass' } else { 'fail' }) '6 Windows PowerShell 5.1 canonical path/source cases' 'Add the versioned Windows clean-room matrix definition.'
    $certificationMatrixPath = Join-Path $projectRoot 'examples\windows-certification-matrix\matrix.json'
    $certificationMatrixPresent = Test-Path -LiteralPath $certificationMatrixPath -PathType Leaf
    Add-Check $checks 'CI-REQ-WINDOWS-CERTIFICATION-DEFINITION' $(if ($certificationMatrixPresent) { 'pass' } else { 'fail' }) '7 evidence-bound environment axes' 'Add the Windows certification matrix and keep unavailable infrastructure honest.'
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
  Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 8

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
  Write-TaogeUtf8NoBomLines -Path $HumanReportPath -Lines $lines

  Write-Output ('CI_WORKFLOW_CHECK=' + $overall)
  exit $exitCode
} catch {
  Write-Error ('{0} at line {1}: {2}' -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
