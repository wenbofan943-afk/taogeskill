function Get-TaogeExistingAncestor {
  param([Parameter(Mandatory=$true)][string]$Path)
  $candidate = [System.IO.Path]::GetFullPath($Path)
  while (-not (Test-Path -LiteralPath $candidate)) {
    $parent = Split-Path -Parent $candidate
    if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $candidate) { return $null }
    $candidate = $parent
  }
  return (Resolve-Path -LiteralPath $candidate).Path
}

function Test-TaogeWindowsPathSegment {
  param([AllowEmptyString()][string]$Segment)
  $errors = [System.Collections.Generic.List[string]]::new()
  if ([string]::IsNullOrEmpty($Segment)) { $errors.Add('empty_segment') }
  if ($Segment -in @('.', '..')) { $errors.Add('relative_navigation_segment') }
  if ($Segment.EndsWith(' ')) { $errors.Add('trailing_space') }
  if ($Segment.EndsWith('.')) { $errors.Add('trailing_period') }
  if ($Segment.IndexOfAny([char[]]@('<','>',':','"','/','\','|','?','*')) -ge 0) { $errors.Add('reserved_character') }
  if (@($Segment.ToCharArray() | Where-Object { [int]$_ -lt 32 }).Count -gt 0) { $errors.Add('control_character') }
  $baseName = ($Segment -split '\.', 2)[0]
  if ($baseName -match '^(?i:CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])$') { $errors.Add('reserved_device_name') }
  return [pscustomobject]@{ segment=$Segment; status=$(if($errors.Count){'fail'}else{'pass'}); errors=[object[]]$errors.ToArray() }
}

function Resolve-TaogeContainedPath {
  param(
    [Parameter(Mandatory=$true)][string]$AllowedRoot,
    [Parameter(Mandatory=$true)][string]$CandidatePath,
    [switch]$AllowRoot,
    [switch]$RejectReparsePoints
  )
  $errors = [System.Collections.Generic.List[string]]::new()
  $rootFull = [System.IO.Path]::GetFullPath($AllowedRoot).TrimEnd('\','/')
  $candidateFull = if ([System.IO.Path]::IsPathRooted($CandidatePath)) {
    [System.IO.Path]::GetFullPath($CandidatePath)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $rootFull $CandidatePath))
  }
  $prefix = $rootFull + [System.IO.Path]::DirectorySeparatorChar
  $isRoot = $candidateFull.TrimEnd('\','/') -eq $rootFull
  if (($isRoot -and -not $AllowRoot) -or (-not $isRoot -and -not $candidateFull.StartsWith($prefix,[System.StringComparison]::OrdinalIgnoreCase))) {
    $errors.Add('root_escape')
  }

  if ($errors.Count -eq 0) {
    $relative = if ($isRoot) { '' } else { $candidateFull.Substring($prefix.Length) }
    foreach ($segment in @($relative -split '[\\/]' | Where-Object { $_ -ne '' })) {
      $segmentResult = Test-TaogeWindowsPathSegment $segment
      foreach ($errorCode in @($segmentResult.errors)) { $errors.Add("path_segment:${segment}:$errorCode") }
    }
  }

  if ($RejectReparsePoints -and $errors.Count -eq 0) {
    $current = $rootFull
    $relative = if ($isRoot) { '' } else { $candidateFull.Substring($prefix.Length) }
    $parts = @($relative -split '[\\/]' | Where-Object { $_ -ne '' })
    foreach ($part in @('') + $parts) {
      if ($part -ne '') { $current = Join-Path $current $part }
      if (-not (Test-Path -LiteralPath $current)) { break }
      $item = Get-Item -LiteralPath $current -Force
      if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        $errors.Add("reparse_point_not_allowed:$current")
        break
      }
    }
  }

  return [pscustomobject]@{
    status=$(if($errors.Count){'fail'}else{'pass'})
    allowed_root=$rootFull
    resolved_path=$candidateFull
    is_root=$isRoot
    errors=[object[]]$errors.ToArray()
  }
}

function Test-TaogePathBudget {
  param(
    [Parameter(Mandatory=$true)][string]$InstallationRoot,
    [Parameter(Mandatory=$true)][string]$TargetRoot,
    [AllowEmptyCollection()][string[]]$RelativePaths = @(),
    [int]$RecommendedInstallationRootMaxChars = 90,
    [int]$ClassicPathMaxChars = 259
  )
  $installationFull = [System.IO.Path]::GetFullPath($InstallationRoot).TrimEnd('\','/')
  $targetFull = [System.IO.Path]::GetFullPath($TargetRoot).TrimEnd('\','/')
  $items = [System.Collections.Generic.List[object]]::new()
  foreach ($relativePath in @($RelativePaths)) {
    $relative = ([string]$relativePath).TrimStart('\','/')
    $full = [System.IO.Path]::GetFullPath((Join-Path $targetFull $relative))
    $items.Add([ordered]@{ relative_path=$relative; full_path_length=$full.Length; over_classic_limit=$full.Length -gt $ClassicPathMaxChars })
  }
  $longest = @($items | Sort-Object full_path_length -Descending | Select-Object -First 1)
  $overLimit = @($items | Where-Object { $_.over_classic_limit })
  $rootWithinRecommendation = $installationFull.Length -le $RecommendedInstallationRootMaxChars
  return [pscustomobject]@{
    status=$(if($rootWithinRecommendation -and $overLimit.Count -eq 0){'pass'}else{'fail'})
    installation_root_length=$installationFull.Length
    recommended_installation_root_max_chars=$RecommendedInstallationRootMaxChars
    installation_root_within_recommendation=$rootWithinRecommendation
    target_root_length=$targetFull.Length
    classic_path_max_chars=$ClassicPathMaxChars
    relative_path_count=@($RelativePaths).Count
    longest_relative_path=$(if($longest.Count){[string]$longest[0].relative_path}else{''})
    longest_target_path_length=$(if($longest.Count){[int]$longest[0].full_path_length}else{$targetFull.Length})
    over_limit_count=$overLimit.Count
    over_limit_paths=[object[]]$overLimit
  }
}

function Get-TaogeVolumeInfo {
  param([Parameter(Mandatory=$true)][string]$Path)
  $ancestor = Get-TaogeExistingAncestor $Path
  if ([string]::IsNullOrWhiteSpace($ancestor)) { return [pscustomobject]@{status='fail';error='existing_ancestor_missing'} }
  $root = [System.IO.Path]::GetPathRoot($ancestor)
  try {
    $drive = [System.IO.DriveInfo]::new($root)
    return [pscustomobject]@{
      status='pass'
      existing_ancestor=$ancestor
      volume_root=$root
      drive_format=$drive.DriveFormat
      available_free_bytes=[long]$drive.AvailableFreeSpace
      total_bytes=[long]$drive.TotalSize
    }
  } catch {
    return [pscustomobject]@{status='fail';existing_ancestor=$ancestor;volume_root=$root;error=$_.Exception.Message}
  }
}

function Test-TaogeWritableTempSpace {
  param(
    [Parameter(Mandatory=$true)][string]$TargetRoot,
    [long]$RequiredFreeBytes = 0,
    [switch]$ProbeWrite
  )
  $volume = Get-TaogeVolumeInfo $TargetRoot
  $errors = [System.Collections.Generic.List[string]]::new()
  if ($volume.status -ne 'pass') { $errors.Add('volume_info_unavailable') }
  if ($volume.status -eq 'pass' -and [long]$volume.available_free_bytes -lt $RequiredFreeBytes) { $errors.Add('insufficient_free_space') }
  $probeDirectory = if ($volume.status -eq 'pass') { [string]$volume.existing_ancestor } else { '' }
  $probeCreated = $false
  $renameSucceeded = $false
  $cleanupSucceeded = $true
  $probePath = ''
  $renamedPath = ''
  if ($ProbeWrite -and $errors.Count -eq 0) {
    $token = [guid]::NewGuid().ToString('N')
    $probePath = Join-Path $probeDirectory ".taoge-preflight-$token.tmp"
    $renamedPath = Join-Path $probeDirectory ".taoge-preflight-$token.renamed.tmp"
    try {
      [System.IO.File]::WriteAllText($probePath,'preflight',[System.Text.UTF8Encoding]::new($false))
      $probeCreated = Test-Path -LiteralPath $probePath
      Move-Item -LiteralPath $probePath -Destination $renamedPath
      $renameSucceeded = Test-Path -LiteralPath $renamedPath
    } catch {
      $errors.Add('write_or_atomic_rename_failed')
    } finally {
      foreach ($candidate in @($probePath,$renamedPath)) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
          try { Remove-Item -LiteralPath $candidate -Force } catch { $cleanupSucceeded = $false }
        }
      }
      if (-not $cleanupSucceeded) { $errors.Add('probe_cleanup_failed') }
    }
  }
  return [pscustomobject]@{
    status=$(if($errors.Count){'fail'}else{'pass'})
    target_root=[System.IO.Path]::GetFullPath($TargetRoot)
    probe_directory=$probeDirectory
    required_free_bytes=$RequiredFreeBytes
    available_free_bytes=$(if($volume.status-eq'pass'){[long]$volume.available_free_bytes}else{-1})
    volume_root=$(if($volume.status-eq'pass'){[string]$volume.volume_root}else{''})
    drive_format=$(if($volume.status-eq'pass'){[string]$volume.drive_format}else{''})
    probe_write_requested=[bool]$ProbeWrite
    probe_created=$probeCreated
    atomic_rename_succeeded=$renameSucceeded
    cleanup_succeeded=$cleanupSucceeded
    errors=[object[]]$errors.ToArray()
  }
}

function Get-TaogeEnvironmentFacts {
  param([Parameter(Mandatory=$true)][string]$ProjectRoot,[Parameter(Mandatory=$true)][string]$TargetRoot)
  $longPathsEnabled = $null
  try { $longPathsEnabled = [int](Get-ItemPropertyValue -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -ErrorAction Stop) } catch {}
  $windowsProductName = ''
  $windowsEdition = ''
  try {
    $windowsInfo = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    $windowsProductName = [string]$windowsInfo.ProductName
    $windowsEdition = [string]$windowsInfo.EditionID
  } catch {}
  $executionPolicies = @()
  try { $executionPolicies = @(Get-ExecutionPolicy -List | ForEach-Object { [ordered]@{scope=[string]$_.Scope;policy=[string]$_.ExecutionPolicy} }) } catch {}
  $volume = Get-TaogeVolumeInfo $TargetRoot
  return [pscustomobject]@{
    os_description=[string][System.Environment]::OSVersion.VersionString
    windows_product_name=$windowsProductName
    windows_edition=$windowsEdition
    os_build=[string][System.Environment]::OSVersion.Version
    process_architecture=[string]$env:PROCESSOR_ARCHITECTURE
    powershell_edition=[string]$PSVersionTable.PSEdition
    powershell_version=[string]$PSVersionTable.PSVersion
    filesystem=$(if($volume.status-eq'pass'){[string]$volume.drive_format}else{'unknown'})
    long_paths_enabled=$longPathsEnabled
    execution_policies=[object[]]$executionPolicies
    current_directory=[string][System.Environment]::CurrentDirectory
    project_root=[System.IO.Path]::GetFullPath($ProjectRoot)
    target_root=[System.IO.Path]::GetFullPath($TargetRoot)
  }
}

function Invoke-TaogeEnvironmentPreflight {
  param(
    [Parameter(Mandatory=$true)][string]$ProjectRoot,
    [Parameter(Mandatory=$true)][string]$AllowedRoot,
    [Parameter(Mandatory=$true)][string]$TargetRoot,
    [AllowEmptyCollection()][string[]]$RelativePaths = @(),
    [long]$RequiredFreeBytes = 0,
    [int]$RecommendedInstallationRootMaxChars = 90,
    [int]$ClassicPathMaxChars = 259,
    [switch]$ProbeWrite
  )
  $containment = Resolve-TaogeContainedPath -AllowedRoot $AllowedRoot -CandidatePath $TargetRoot -AllowRoot -RejectReparsePoints
  $budget = Test-TaogePathBudget -InstallationRoot $ProjectRoot -TargetRoot $TargetRoot -RelativePaths $RelativePaths -RecommendedInstallationRootMaxChars $RecommendedInstallationRootMaxChars -ClassicPathMaxChars $ClassicPathMaxChars
  $storage = Test-TaogeWritableTempSpace -TargetRoot $TargetRoot -RequiredFreeBytes $RequiredFreeBytes -ProbeWrite:$ProbeWrite
  $facts = Get-TaogeEnvironmentFacts -ProjectRoot $ProjectRoot -TargetRoot $TargetRoot
  $failures = [System.Collections.Generic.List[string]]::new()
  if ($containment.status -ne 'pass') { $failures.Add('root_containment') }
  if ($budget.status -ne 'pass') { $failures.Add('path_budget') }
  if ($storage.status -ne 'pass') { $failures.Add('writable_temp_space') }
  return [pscustomobject]@{
    schema_id='taoge://environment/preflight/v0.1'
    checked_at=[DateTimeOffset]::UtcNow.ToString('o')
    status=$(if($failures.Count){'fail'}else{'pass'})
    failure_categories=[object[]]$failures.ToArray()
    facts=$facts
    root_containment=$containment
    path_budget=$budget
    writable_temp_space=$storage
    system_configuration_mutated=$false
    network_called=$false
  }
}
