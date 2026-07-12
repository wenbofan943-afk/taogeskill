param(
  [string]$ProjectRoot = '',
  [string]$Profile = 'dev',
  [string]$Task = '',
  [string]$HumanReportPath = '',
  [string]$MachineReportPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')

function Add-BoundaryCheck {
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
    $HumanReportPath = Join-Path $defaultReportDir "build-profile-check-report.md"
  }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
    $MachineReportPath = Join-Path $defaultReportDir "build-profile-check-report.json"
  }

  @($HumanReportPath, $MachineReportPath) | ForEach-Object {
    $reportDir = Split-Path -Parent $_
    if (-not [string]::IsNullOrWhiteSpace($reportDir) -and -not (Test-Path -LiteralPath $reportDir)) {
      New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
  }

  $checks = New-Object System.Collections.Generic.List[object]
  $checkRunId = "BUILD-PROFILE-" + (Get-Date -Format "yyyyMMdd-HHmmss")

  $profileConfig = [ordered]@{
    dev = [ordered]@{
      may_read = @('accounts/', 'indexes/', 'docs/', 'skills/', 'tools/', 'objects/', 'support-logs/')
      may_write = @('accounts/{account_slug}/runs/{session_id}/', 'support-logs/', '工作流状态记录.md')
      must_not_read = @()
      sample_only = $false
    }
    test = [ordered]@{
      may_read = @('examples/', 'docs/tutorials/', 'templates/', 'tools/', 'docs/')
      may_write = @('examples/', 'docs/tutorials/')
      must_not_read = @('accounts/', 'indexes/', 'support-logs/')
      sample_only = $true
    }
    public = [ordered]@{
      may_read = @('README.md', 'AGENTS.md', 'PROJECT_MAP.md', 'STATUS.md', 'VERSION', 'LICENSE', 'CONTACT.md', 'INSTALL.md', 'UPDATE.md', 'CHANGELOG.md', 'RELEASE_NOTES.md', 'NOTICE.md', 'SECURITY.md', 'CONTRIBUTING.md', 'CODE_OF_CONDUCT.md', 'release-checklist.md', 'public-manifest.yaml', '交接物字段词典.md', 'docs/', 'skills/', 'templates/', 'examples/', 'tools/', '.github/')
      may_write = @('releases/v{version}/public_release/', 'releases/v{version}/taoge-creative-workflow-{version}-public-release.zip', 'releases/v{version}/taoge-creative-workflow-{version}-public-release.zip.sha256')
      must_not_read = @('accounts/', 'indexes/', 'support-logs/', 'offline_tester_packages/', '外部资料/', 'releases/')
      sample_only = $true
    }
  }

  if (-not $profileConfig.Contains($Profile)) {
    Add-BoundaryCheck $checks 'PROFILE-001' 'fail' "Unknown profile: $Profile" "Use dev, test, or public."
    $overall = 'fail'
    $exitCode = 1
  } else {
    $config = $profileConfig[$Profile]

    Add-BoundaryCheck $checks 'PROFILE-001' 'pass' "Profile: $Profile" "Valid build profile selected."

    foreach ($path in $config.must_not_read) {
      $fullPath = Join-Path $root $path
      if (Test-Path -LiteralPath $fullPath) {
        Add-BoundaryCheck $checks "BOUNDARY-MUST-NOT-READ-$($path.Replace('/','-').Replace('{','').Replace('}',''))" 'warning' "$path exists and is in must_not_read" "Do not read from $path while running the $Profile profile."
      } else {
        Add-BoundaryCheck $checks "BOUNDARY-MUST-NOT-READ-$($path.Replace('/','-').Replace('{','').Replace('}',''))" 'pass' "$path does not exist" "No violation of must_not_read boundary."
      }
    }

    foreach ($path in $config.may_read) {
      $fullPath = Join-Path $root $path
      if (Test-Path -LiteralPath $fullPath) {
        Add-BoundaryCheck $checks "BOUNDARY-MAY-READ-$($path.Replace('/','-').Replace('{','').Replace('}',''))" 'pass' "$path exists" "Path is allowed to be read in $Profile profile."
      } else {
        Add-BoundaryCheck $checks "BOUNDARY-MAY-READ-$($path.Replace('/','-').Replace('{','').Replace('}',''))" 'warning' "$path does not exist" "Optional path not found."
      }
    }

    if ($config.sample_only) {
      $accountsDir = Join-Path $root 'accounts'
      $indexesDir = Join-Path $root 'indexes'
      if (Test-Path -LiteralPath $accountsDir) {
        Add-BoundaryCheck $checks 'BOUNDARY-SAMPLE-001' 'warning' 'accounts/ exists' "Sample-only profile should not read real account data."
      }
      if (Test-Path -LiteralPath $indexesDir) {
        Add-BoundaryCheck $checks 'BOUNDARY-SAMPLE-002' 'warning' 'indexes/ exists' "Sample-only profile should not read real index data."
      }
    }

    if ($Profile -eq 'public') {
      $requiredFiles = @('README.md', 'AGENTS.md', 'SECURITY.md', 'LICENSE', 'release-checklist.md')
      foreach ($file in $requiredFiles) {
        $fullPath = Join-Path $root $file
        if (Test-Path -LiteralPath $fullPath) {
          Add-BoundaryCheck $checks "BOUNDARY-PUBLIC-REQ-$file" 'pass' "$file exists" "Required public file present."
        } else {
          Add-BoundaryCheck $checks "BOUNDARY-PUBLIC-REQ-$file" 'fail' "$file missing" "Add $file for public release."
        }
      }
    }
  }

  $failed = @($checks | Where-Object { $_.status -eq 'fail' })
  $overall = if ($failed.Count -gt 0) { 'fail' } else { 'pass' }
  $exitCode = if ($failed.Count -gt 0) { 1 } else { 0 }

  $report = [ordered]@{
    build_profile_check_report = [ordered]@{
      check_run_id = $checkRunId
      profile = $Profile
      task = $Task
      overall_result = $overall
      exit_code = $exitCode
      fail_count = $failed.Count
      checks = [object[]]$checks.ToArray()
    }
  }
  Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 8

  $lines = @('# Build Profile Boundary Check Report', '', '```yaml')
  $lines += "check_run_id: $checkRunId"
  $lines += "profile: $Profile"
  $lines += "task: $Task"
  $lines += "overall_result: $overall"
  $lines += "exit_code: $exitCode"
  $lines += "fail_count: $($failed.Count)"
  $lines += '```'
  $lines += ''
  $lines += '| Check ID | Status | Evidence | Remediation |'
  $lines += '|---|---|---|---|'
  foreach ($check in $checks) {
    $lines += "| $($check.check_item_id) | $($check.status) | $($check.evidence) | $($check.remediation) |"
  }
  Write-TaogeUtf8NoBomLines -Path $HumanReportPath -Lines $lines

  Write-Output "BUILD_PROFILE_CHECK=$overall"
  exit $exitCode
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
