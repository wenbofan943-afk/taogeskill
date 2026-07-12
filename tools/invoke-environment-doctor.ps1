param(
  [string]$ProjectRoot = '',
  [string]$AllowedRoot = '',
  [string]$TargetRoot = '',
  [string[]]$RelativePaths = @(),
  [long]$RequiredFreeBytes = 67108864,
  [int]$RecommendedInstallationRootMaxChars = 90,
  [int]$ClassicPathMaxChars = 259,
  [string]$ReportPath = 'state/checks/environment-doctor-report.json',
  [switch]$SkipWriteProbe
)

$ErrorActionPreference = 'Stop'
$scriptProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'EnvironmentPreflight.ps1')

try {
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = $scriptProjectRoot }
  $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
  if ([string]::IsNullOrWhiteSpace($AllowedRoot)) { $AllowedRoot = $ProjectRoot }
  if ([string]::IsNullOrWhiteSpace($TargetRoot)) { $TargetRoot = $ProjectRoot }
  $AllowedRoot = [System.IO.Path]::GetFullPath($AllowedRoot)
  $TargetRoot = [System.IO.Path]::GetFullPath($TargetRoot)

  if (@($RelativePaths).Count -eq 0) {
    $gitOutput = @(& git -C $ProjectRoot -c core.quotepath=false ls-files --cached 2>$null | ForEach-Object { [string]$_ })
    if ($LASTEXITCODE -eq 0 -and $gitOutput.Count -gt 0) { $RelativePaths = [string[]]$gitOutput }
  }

  $result = Invoke-TaogeEnvironmentPreflight -ProjectRoot $ProjectRoot -AllowedRoot $AllowedRoot -TargetRoot $TargetRoot -RelativePaths $RelativePaths -RequiredFreeBytes $RequiredFreeBytes -RecommendedInstallationRootMaxChars $RecommendedInstallationRootMaxChars -ClassicPathMaxChars $ClassicPathMaxChars -ProbeWrite:(-not $SkipWriteProbe)
  $reportFull = if ([System.IO.Path]::IsPathRooted($ReportPath)) { [System.IO.Path]::GetFullPath($ReportPath) } else { [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $ReportPath)) }
  $reportContainment = Resolve-TaogeContainedPath -AllowedRoot $ProjectRoot -CandidatePath $reportFull -RejectReparsePoints
  if ($reportContainment.status -ne 'pass') { throw 'environment_doctor_report_path_outside_project_root' }
  Write-TaogeUtf8NoBomJson -Path $reportFull -Value $result -Depth 30
  Write-Output "ENVIRONMENT_DOCTOR_RESULT=$($result.status)"
  Write-Output "PROJECT_ROOT_LENGTH=$($result.path_budget.installation_root_length)"
  Write-Output "LONGEST_TARGET_PATH_LENGTH=$($result.path_budget.longest_target_path_length)"
  Write-Output "FILESYSTEM=$($result.facts.filesystem)"
  Write-Output "AVAILABLE_FREE_BYTES=$($result.writable_temp_space.available_free_bytes)"
  Write-Output "REPORT=$ReportPath"
  if ($result.status -ne 'pass') { exit 2 }
  exit 0
} catch {
  Write-Error ("ENVIRONMENT_DOCTOR_ERROR=" + $_.Exception.Message)
  exit 3
}
