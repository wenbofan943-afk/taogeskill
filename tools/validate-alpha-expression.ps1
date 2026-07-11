param(
  [string]$TargetPath = '.',
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
  if (-not (Test-Path -LiteralPath $TargetPath)) {
    Write-Error ('TargetPath not found: ' + $TargetPath)
    exit 4
  }
  $target = (Resolve-Path -LiteralPath $TargetPath).Path
  $projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
  $defaultReportDir = if ($target -eq $projectRoot) { Join-Path $projectRoot 'state\checks' } else { $target }
  if ([string]::IsNullOrWhiteSpace($HumanReportPath)) {
    $HumanReportPath = Join-Path $defaultReportDir 'alpha-expression-check-report.md'
  }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
    $MachineReportPath = Join-Path $defaultReportDir 'alpha-expression-check-report.json'
  }
  @($HumanReportPath, $MachineReportPath) | ForEach-Object {
    $reportDir = Split-Path -Parent $_
    if (-not [string]::IsNullOrWhiteSpace($reportDir) -and -not (Test-Path -LiteralPath $reportDir)) {
      New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
  }

  $checks = New-Object System.Collections.Generic.List[object]
  $requirements = @(
    @{ id = 'ALPHA-README-001'; path = 'README.md'; needles = @('0.1.0-alpha.2', 'Alpha', 'GitHub 预发行版本', '不是生产级自动化 runner', '不能自动发布内容') },
    @{ id = 'ALPHA-INSTALL-001'; path = 'INSTALL.md'; needles = @('Alpha', 'GitHub 预发行版本', '不包含生产 runner', '先跑 `examples/`', 'validate-regression-suite.ps1') },
    @{ id = 'ALPHA-RELEASE-001'; path = 'RELEASE_NOTES.md'; needles = @('published GitHub alpha pre-release', 'not treat it as a production workflow engine', 'Validation-only GitHub Actions workflow exists') },
    @{ id = 'ALPHA-EXAMPLES-001'; path = 'examples/README.md'; needles = @('Alpha', 'sample_only', 'regression fixture', '不证明真实热点质量', '自动发布能力') },
    @{ id = 'ALPHA-SAMPLE01-001'; path = 'examples/sample-01-onboarding/README.md'; needles = @('alpha_note', '不验证真实内容生产', '自动发布') },
    @{ id = 'ALPHA-SAMPLE02-001'; path = 'examples/sample-02-single-content-run/README.md'; needles = @('alpha_note', '不证明真实热点质量', '真实图片质量', '真实发布效果') },
    @{ id = 'ALPHA-SAMPLE03-001'; path = 'examples/sample-03-final-review-revision/README.md'; needles = @('alpha_note', '局部返工路由', '真实生产 runner') }
  )

  foreach ($requirement in $requirements) {
    $filePath = Join-Path $target $requirement.path
    if (-not (Test-Path -LiteralPath $filePath)) {
      Add-Check $checks $requirement.id 'fail' $requirement.path 'Add alpha expression file.'
      continue
    }
    $text = Get-Content -LiteralPath $filePath -Raw -Encoding UTF8
    $missing = @($requirement.needles | Where-Object { -not $text.Contains($_) })
    $status = if ($missing.Count -eq 0) { 'pass' } else { 'fail' }
    $evidence = if ($missing.Count -eq 0) { $requirement.path } else { $requirement.path + ' missing: ' + ([string]::Join(', ', $missing)) }
    Add-Check $checks $requirement.id $status $evidence 'Add first-screen alpha boundary wording.'
  }

  $failed = @($checks | Where-Object { $_.status -eq 'fail' })
  $overall = if ($failed.Count -gt 0) { 'fail' } else { 'pass' }
  $exitCode = if ($failed.Count -gt 0) { 1 } else { 0 }
  $report = [ordered]@{
    alpha_expression_check_report = [ordered]@{
      check_report_id = 'ALPHA-CHECK-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
      command_name = 'validate-alpha-expression'
      command_version = '0.1.0'
      exit_code = $exitCode
      overall_result = $overall
      blocker_count = $failed.Count
      checks = [object[]]$checks.ToArray()
    }
  }
  $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $MachineReportPath -Encoding UTF8

  $lines = @('# Alpha Expression Check Report', '', '```yaml')
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

  Write-Output ('ALPHA_EXPRESSION_CHECK=' + $overall)
  exit $exitCode
} catch {
  Write-Error ('{0} at line {1}: {2}' -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}

