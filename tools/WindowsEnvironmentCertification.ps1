. (Join-Path $PSScriptRoot 'EnvironmentPreflight.ps1')

function Test-TaogePathWithinRoot {
  param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Root)
  try {
    $pathFull = [System.IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\','/')
    return $pathFull.Equals($rootFull,[System.StringComparison]::OrdinalIgnoreCase) -or $pathFull.StartsWith($rootFull + '\',[System.StringComparison]::OrdinalIgnoreCase)
  } catch { return $false }
}

function Get-TaogeCertificationAxisStatus {
  param([Parameter(Mandatory=$true)][object]$Facts)
  $observed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  if ([string]$Facts.path_kind -eq 'unc') { [void]$observed.Add('network_share') }
  if ([bool]$Facts.target_under_onedrive) { [void]$observed.Add('onedrive_sync_root') }
  if ([string]$Facts.filesystem -eq 'NTFS' -and [bool]$Facts.case_sensitive_observed) { [void]$observed.Add('case_sensitive_ntfs') }
  if ([bool]$Facts.enterprise_policy_observed) { [void]$observed.Add('enterprise_group_policy') }
  if ([string]$Facts.os_architecture -match '^(?i:ARM64|Arm64)$') { [void]$observed.Add('windows_arm64') }
  if ([int]$Facts.windows_product_type -in @(2,3)) { [void]$observed.Add('windows_server') }
  if (-not [string]::IsNullOrWhiteSpace([string]$Facts.filesystem) -and [string]$Facts.filesystem -notin @('NTFS','unknown','remote_or_unknown')) { [void]$observed.Add('non_ntfs_filesystem') }

  $allAxes = @('network_share','onedrive_sync_root','case_sensitive_ntfs','enterprise_group_policy','windows_arm64','windows_server','non_ntfs_filesystem')
  return [object[]]@($allAxes | ForEach-Object {
    [ordered]@{
      axis = $_
      environment_status = $(if($observed.Contains($_)){'observed'}else{'unavailable_on_current_host'})
      workflow_validation_status = 'not_run_by_probe'
      certification_status = 'not_certified_by_probe_alone'
    }
  })
}

function Get-TaogeCaseSensitivityObservation {
  param([Parameter(Mandatory=$true)][string]$TargetRoot,[switch]$ProbeWrite)
  if (-not $ProbeWrite) { return [pscustomobject]@{status='not_tested';case_sensitive=$false;cleanup_succeeded=$true;error=''} }
  $ancestor = Get-TaogeExistingAncestor $TargetRoot
  if ([string]::IsNullOrWhiteSpace($ancestor)) { return [pscustomobject]@{status='fail';case_sensitive=$false;cleanup_succeeded=$true;error='existing_ancestor_missing'} }
  $probeRoot = Join-Path $ancestor ('.taoge-case-' + [guid]::NewGuid().ToString('N').Substring(0,8))
  $lower = Join-Path $probeRoot 'case-probe.txt'
  $upper = Join-Path $probeRoot 'CASE-PROBE.TXT'
  $caseSensitive = $false
  $cleanupSucceeded = $true
  $errorText = ''
  try {
    [void][System.IO.Directory]::CreateDirectory($probeRoot)
    $first = [System.IO.File]::Open($lower,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::Write,[System.IO.FileShare]::None)
    $first.Dispose()
    try {
      $second = [System.IO.File]::Open($upper,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::Write,[System.IO.FileShare]::None)
      $second.Dispose()
      $caseSensitive = $true
    } catch [System.IO.IOException] {
      $caseSensitive = $false
    }
  } catch {
    $errorText = $_.Exception.Message
  } finally {
    if (Test-Path -LiteralPath $probeRoot) {
      try { Remove-Item -LiteralPath $probeRoot -Recurse -Force } catch { $cleanupSucceeded = $false }
    }
  }
  return [pscustomobject]@{
    status=$(if([string]::IsNullOrWhiteSpace($errorText)-and$cleanupSucceeded){'pass'}else{'fail'})
    case_sensitive=$caseSensitive
    cleanup_succeeded=$cleanupSucceeded
    error=$errorText
  }
}

function Get-TaogeWindowsCertificationFacts {
  param([Parameter(Mandatory=$true)][string]$TargetRoot,[switch]$ProbeWrite)
  $targetFull = [System.IO.Path]::GetFullPath($TargetRoot)
  $volume = Get-TaogeVolumeInfo -Path $targetFull
  $caseObservation = Get-TaogeCaseSensitivityObservation -TargetRoot $targetFull -ProbeWrite:$ProbeWrite
  $productType = 0
  $productCaption = ''
  $domainJoined = $false
  try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $productType = [int]$os.ProductType
    $productCaption = [string]$os.Caption
  } catch {}
  try { $domainJoined = [bool](Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).PartOfDomain } catch {}
  $machinePolicy = 'Undefined'
  $userPolicy = 'Undefined'
  try {
    $policies = @(Get-ExecutionPolicy -List)
    $machine = @($policies | Where-Object Scope -eq 'MachinePolicy' | Select-Object -First 1)
    $user = @($policies | Where-Object Scope -eq 'UserPolicy' | Select-Object -First 1)
    if ($machine.Count) { $machinePolicy = [string]$machine[0].ExecutionPolicy }
    if ($user.Count) { $userPolicy = [string]$user[0].ExecutionPolicy }
  } catch {}
  $oneDriveRoots = @($env:OneDrive,$env:OneDriveCommercial,$env:OneDriveConsumer) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
  $underOneDrive = @($oneDriveRoots | Where-Object { Test-TaogePathWithinRoot -Path $targetFull -Root ([string]$_) }).Count -gt 0
  $architecture = [string]$env:PROCESSOR_ARCHITECTURE
  try { $architecture = [string][System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture } catch {}

  $facts = [pscustomobject][ordered]@{
    target_root=$targetFull
    path_kind=$(if($targetFull.StartsWith('\\')){'unc'}else{'local'})
    storage_kind=$(if($volume.status-eq'pass'){[string]$volume.storage_kind}else{'unknown'})
    filesystem=$(if($volume.status-eq'pass'){[string]$volume.drive_format}else{'unknown'})
    volume_status=[string]$volume.status
    windows_product_type=$productType
    windows_product_caption=$productCaption
    windows_server_observed=$productType -in @(2,3)
    os_architecture=$architecture
    domain_joined=$domainJoined
    machine_policy=$machinePolicy
    user_policy=$userPolicy
    enterprise_policy_observed=$domainJoined -or $machinePolicy -ne 'Undefined' -or $userPolicy -ne 'Undefined'
    onedrive_roots=[object[]]$oneDriveRoots
    target_under_onedrive=$underOneDrive
    case_probe_status=[string]$caseObservation.status
    case_sensitive_observed=[bool]$caseObservation.case_sensitive
    case_probe_cleanup_succeeded=[bool]$caseObservation.cleanup_succeeded
    powershell_edition=[string]$PSVersionTable.PSEdition
    powershell_version=[string]$PSVersionTable.PSVersion
    system_configuration_mutated=$false
    network_called=$targetFull.StartsWith('\\')
  }
  return [pscustomobject][ordered]@{facts=$facts;axes=[object[]](Get-TaogeCertificationAxisStatus -Facts $facts)}
}
