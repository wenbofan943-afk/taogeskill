param(
  [Parameter(Mandatory=$true)][string]$CaseId,
  [Parameter(Mandatory=$true)][string]$HostId,
  [Parameter(Mandatory=$true)][ValidateSet('source','zip')][string]$SourceKind,
  [Parameter(Mandatory=$true)][ValidateSet('short_ascii','space_unicode','over_budget')][string]$PathShape,
  [Parameter(Mandatory=$true)][ValidateSet('pass','blocked_preflight')][string]$ExpectedOutcome,
  [Parameter(Mandatory=$true)][string]$ProjectRoot,
  [Parameter(Mandatory=$true)][string]$WorkRoot,
  [string]$ArchivePath = '',
  [Parameter(Mandatory=$true)][string]$ResultPath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'EnvironmentPreflight.ps1')
. (Join-Path $PSScriptRoot 'ArchiveIntegrity.ps1')

function Get-H5TrackedSourcePaths {
  param([string]$Root)
  $top = @(& git -C $Root rev-parse --show-toplevel 2>$null)
  if ($LASTEXITCODE -ne 0 -or $top.Count -ne 1 -or [System.IO.Path]::GetFullPath($top[0]).TrimEnd('\','/') -ne $Root.TrimEnd('\','/')) { throw 'clean_room_git_root_identity_failed' }
  $paths = @(& git -C $Root -c core.quotepath=false ls-files --cached)
  if ($LASTEXITCODE -ne 0 -or $paths.Count -eq 0) { throw 'clean_room_git_index_empty' }
  return [string[]]$paths
}

function Copy-H5TrackedSource {
  param([string]$Root,[string]$Destination,[string[]]$Paths)
  if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Recurse -Force }
  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  $copied = 0
  foreach ($relativePath in $Paths) {
    $source = Join-Path $Root $relativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "clean_room_index_file_missing:$relativePath" }
    $target = Join-Path $Destination $relativePath
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Copy-Item -LiteralPath $source -Destination $target -Force
    $copied++
  }
  return $copied
}

function Invoke-H5CheckerProcess {
  param([string]$RuntimeHost,[string]$ScriptPath,[string[]]$Arguments,[string]$LogPrefix)
  $stdout = "$LogPrefix.stdout.txt"
  $stderr = "$LogPrefix.stderr.txt"
  $process = Start-TaogeProcess -FilePath $RuntimeHost -Arguments (@('-NoLogo','-NoProfile','-File',$ScriptPath) + @($Arguments)) -StandardOutputPath $stdout -StandardErrorPath $stderr -Wait -Hidden
  return [pscustomobject][ordered]@{
    exit_code = [int]$process.ExitCode
    stdout_path = $stdout
    stderr_path = $stderr
  }
}

try {
  $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).ProviderPath
  $WorkRoot = [System.IO.Path]::GetFullPath($WorkRoot)
  if (-not (Test-Path -LiteralPath $WorkRoot)) { New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null }
  $relativePaths = @()
  if ($SourceKind -eq 'source') {
    $relativePaths = @(Get-H5TrackedSourcePaths -Root $ProjectRoot)
  } else {
    if ([string]::IsNullOrWhiteSpace($ArchivePath) -or -not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) { throw 'clean_room_archive_missing' }
    $archiveManifest = Read-TaogeArchiveManifestFromArchive -ArchivePath $ArchivePath
    $relativePaths = @($archiveManifest.archive_manifest.files | ForEach-Object { [string]$_.path }) + @('archive-manifest.json')
  }

  $targetName = if ($PathShape -eq 'short_ascii') { 'r' } elseif ($PathShape -eq 'space_unicode') { 'clean room 中文' } else { 'over' }
  $targetRoot = Join-Path $WorkRoot $targetName
  if ($PathShape -eq 'over_budget') {
    $longestRelative = @($relativePaths | Sort-Object Length -Descending | Select-Object -First 1)
    $minimumTargetLength = 266 - ([string]$longestRelative[0]).Length
    $paddingLength = [Math]::Max(8,$minimumTargetLength - $WorkRoot.Length - 1)
    $paddingLength = [Math]::Min(180,$paddingLength)
    $targetRoot = Join-Path $WorkRoot ('d' * $paddingLength)
  }

  $sentinel = ''
  if ($PathShape -eq 'over_budget') { $sentinel = Join-Path $WorkRoot 'sentinel.keep'; Write-TaogeUtf8NoBomText -Path $sentinel -Text 'must-survive-preflight' }
  $requiredBytes = if ($SourceKind -eq 'zip') { [long]((Get-Item -LiteralPath $ArchivePath).Length * 3 + 16777216) } else { [long]16777216 }
  $preflight = Invoke-TaogeEnvironmentPreflight -ProjectRoot $ProjectRoot -AllowedRoot $WorkRoot -TargetRoot $targetRoot -RelativePaths ([string[]]$relativePaths) -RequiredFreeBytes $requiredBytes -ProbeWrite
  $runtimeHost = (Get-Process -Id $PID).Path
  $runtimeCheck = $null
  $environmentCheck = $null
  $payloadCheck = $null
  $copiedFileCount = 0
  $actualOutcome = 'fail'
  $failureCategory = ''

  if ($PathShape -eq 'over_budget') {
    $blocked = $preflight.status -eq 'fail' -and @($preflight.failure_categories) -contains 'path_budget' -and -not (Test-Path -LiteralPath $targetRoot) -and (Test-Path -LiteralPath $sentinel)
    $actualOutcome = if ($blocked) { 'blocked_preflight' } else { 'fail' }
    if (-not $blocked) { $failureCategory = 'environment_preflight_expectation_mismatch' }
  } elseif ($preflight.status -ne 'pass') {
    $failureCategory = 'environment_preflight_failed'
  } else {
    if ($SourceKind -eq 'source') {
      $copiedFileCount = Copy-H5TrackedSource -Root $ProjectRoot -Destination $targetRoot -Paths ([string[]]$relativePaths)
      if ($copiedFileCount -ne $relativePaths.Count) { throw "clean_room_copy_count_mismatch:expected=$($relativePaths.Count);actual=$copiedFileCount" }
    } else {
      [void](Expand-TaogeArchiveSecure -ArchivePath $ArchivePath -DestinationRoot $targetRoot)
      $payloadCheck = Test-TaogeArchivePayload -PayloadRoot $targetRoot
      if ($payloadCheck.status -ne 'pass') { throw "clean_room_archive_payload_failed:$([string]::Join(',',@($payloadCheck.errors)))" }
    }
    $caseReportRoot = Join-Path $WorkRoot 'reports'
    if (-not (Test-Path -LiteralPath $caseReportRoot)) { New-Item -ItemType Directory -Path $caseReportRoot -Force | Out-Null }
    $runtimeCheck = Invoke-H5CheckerProcess -RuntimeHost $runtimeHost -ScriptPath (Join-Path $targetRoot 'tools\validate-windows-runtime-helper.ps1') -Arguments @('-ReportPath',(Join-Path $caseReportRoot 'runtime-helper.json')) -LogPrefix (Join-Path $caseReportRoot 'runtime-helper')
    if ($targetRoot.StartsWith('\\')) {
      $environmentCheck = Invoke-H5CheckerProcess -RuntimeHost $runtimeHost -ScriptPath (Join-Path $targetRoot 'tools\invoke-environment-doctor.ps1') -Arguments @('-ProjectRoot',$targetRoot,'-AllowedRoot',$targetRoot,'-TargetRoot',$targetRoot,'-RelativePaths','README.md','-RequiredFreeBytes','0','-ReportPath','state/checks/h5-unc-environment-doctor.json') -LogPrefix (Join-Path $caseReportRoot 'environment-doctor')
    } else {
      $environmentCheck = Invoke-H5CheckerProcess -RuntimeHost $runtimeHost -ScriptPath (Join-Path $targetRoot 'tools\validate-environment-preflight.ps1') -Arguments @('-ReportPath',(Join-Path $caseReportRoot 'environment-preflight.json')) -LogPrefix (Join-Path $caseReportRoot 'environment-preflight')
    }
    if ($runtimeCheck.exit_code -eq 0 -and $environmentCheck.exit_code -eq 0) { $actualOutcome = 'pass' } else { $failureCategory = 'representative_checker_failed' }
  }

  $expectationMet = $actualOutcome -eq $ExpectedOutcome
  $facts = Get-TaogeEnvironmentFacts -ProjectRoot $ProjectRoot -TargetRoot $targetRoot
  $result = [ordered]@{
    case_result = [ordered]@{
      case_id = $CaseId
      host_id = $HostId
      observed_powershell_edition = [string]$PSVersionTable.PSEdition
      observed_powershell_version = [string]$PSVersionTable.PSVersion
      source_kind = $SourceKind
      path_shape = $PathShape
      expected_outcome = $ExpectedOutcome
      actual_outcome = $actualOutcome
      expectation_met = $expectationMet
      failure_category = $failureCategory
      target_root_length = $targetRoot.Length
      source_file_count = $relativePaths.Count
      copied_file_count = $copiedFileCount
      preflight_status = $preflight.status
      preflight_failures = @($preflight.failure_categories)
      runtime_helper_exit_code = if ($null -ne $runtimeCheck) { $runtimeCheck.exit_code } else { $null }
      environment_preflight_exit_code = if ($null -ne $environmentCheck) { $environmentCheck.exit_code } else { $null }
      environment_representative = $(if($targetRoot.StartsWith('\\')){'environment_doctor_unc'}else{'environment_preflight_fixture'})
      archive_payload_status = if ($null -ne $payloadCheck) { $payloadCheck.status } else { 'not_applicable' }
      filesystem = $facts.filesystem
      system_configuration_mutated = $false
      network_called = $targetRoot.StartsWith('\\')
    }
  }
  Write-TaogeUtf8NoBomJson -Path $ResultPath -Value $result -Depth 12
  Write-Output "CLEAN_ROOM_CASE=$CaseId"
  Write-Output "CLEAN_ROOM_ACTUAL=$actualOutcome"
  Write-Output "CLEAN_ROOM_EXPECTATION_MET=$expectationMet"
  if (-not $expectationMet) { exit 1 }
  exit 0
} catch {
  $errorResult = [ordered]@{case_result=[ordered]@{case_id=$CaseId;host_id=$HostId;source_kind=$SourceKind;path_shape=$PathShape;expected_outcome=$ExpectedOutcome;actual_outcome='tool_error';expectation_met=$false;failure_category='checker_or_environment';error=$_.Exception.Message;system_configuration_mutated=$false;network_called=$false}}
  Write-TaogeUtf8NoBomJson -Path $ResultPath -Value $errorResult -Depth 10
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message,$_.InvocationInfo.ScriptLineNumber,$_.InvocationInfo.Line)
  exit 3
}
