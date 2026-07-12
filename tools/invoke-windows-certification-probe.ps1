param(
  [string]$TargetRoot = '',
  [ValidateSet('','network_share','onedrive_sync_root','case_sensitive_ntfs','enterprise_group_policy','windows_arm64','windows_server','non_ntfs_filesystem')][string]$RequiredAxis = '',
  [string]$ReportPath = 'state/checks/windows-certification-probe.json',
  [switch]$ProbeWrite
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'WindowsEnvironmentCertification.ps1')

try {
  if ([string]::IsNullOrWhiteSpace($TargetRoot)) { $TargetRoot = $projectRoot }
  $observation = Get-TaogeWindowsCertificationFacts -TargetRoot $TargetRoot -ProbeWrite:$ProbeWrite
  $requiredResult = $null
  if (-not [string]::IsNullOrWhiteSpace($RequiredAxis)) { $requiredResult = @($observation.axes | Where-Object axis -eq $RequiredAxis | Select-Object -First 1) }
  $requiredObserved = [string]::IsNullOrWhiteSpace($RequiredAxis) -or ($requiredResult.Count -eq 1 -and $requiredResult[0].environment_status -eq 'observed')
  $report = [ordered]@{
    certification_probe_report=[ordered]@{
      schema_version='taoge.windows-certification-probe.v0.1'
      checked_at=[DateTimeOffset]::UtcNow.ToString('o')
      required_axis=$RequiredAxis
      required_axis_observed=$requiredObserved
      probe_result=$(if($requiredObserved){'pass'}else{'blocked_environment_mismatch'})
      facts=$observation.facts
      axes=$observation.axes
      certification_rule='environment observation alone never certifies workflow compatibility; run full clean-room matrix and public validator on the same host/root/source commit'
    }
  }
  $reportFull = if([System.IO.Path]::IsPathRooted($ReportPath)){[System.IO.Path]::GetFullPath($ReportPath)}else{[System.IO.Path]::GetFullPath((Join-Path $projectRoot $ReportPath))}
  Write-TaogeUtf8NoBomJson -Path $reportFull -Value $report -Depth 20
  Write-Output "WINDOWS_CERTIFICATION_PROBE=$($report.certification_probe_report.probe_result)"
  Write-Output "REQUIRED_AXIS=$RequiredAxis"
  Write-Output "REPORT=$reportFull"
  if(-not$requiredObserved){exit 2}
  exit 0
} catch {
  Write-Error ("WINDOWS_CERTIFICATION_PROBE_ERROR=" + $_.Exception.Message)
  exit 3
}
