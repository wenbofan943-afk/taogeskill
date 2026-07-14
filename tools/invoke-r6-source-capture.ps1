param(
  [Parameter(Mandatory=$true)][string]$CaptureId,
  [Parameter(Mandatory=$true)][string]$SourceUrl,
  [Parameter(Mandatory=$true)][string]$SessionRoot,
  [Parameter(Mandatory=$true)][string]$ScreenshotRelativePath,
  [Parameter(Mandatory=$true)][string]$AttemptRelativePath,
  [int]$ViewportWidth = 1280,
  [int]$ViewportHeight = 960,
  [string]$BrowserPath = '',
  [switch]$AllowNetwork,
  [switch]$AllowLocalFixture
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'EnvironmentPreflight.ps1')

function Resolve-R6CaptureBrowser {
  param([string]$RequestedPath)
  if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
    $full = [System.IO.Path]::GetFullPath($RequestedPath)
    if (Test-Path -LiteralPath $full -PathType Leaf) { return $full }
    throw "browser_not_found:$full"
  }
  $candidates = [System.Collections.Generic.List[string]]::new()
  $command = Get-Command 'msedge.exe' -ErrorAction SilentlyContinue
  if ($null -ne $command) { $candidates.Add([string]$command.Source) }
  foreach ($base in @(${env:ProgramFiles(x86)},$env:ProgramFiles,$env:LOCALAPPDATA)) {
    if (-not [string]::IsNullOrWhiteSpace($base)) { $candidates.Add((Join-Path $base 'Microsoft\Edge\Application\msedge.exe')) }
  }
  foreach ($candidate in @($candidates)) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return [System.IO.Path]::GetFullPath($candidate) }
  }
  throw 'browser_not_found:Microsoft_Edge'
}

function Resolve-R6CaptureSource {
  param([string]$Value)
  $uri = $null
  if ([System.Uri]::TryCreate($Value,[System.UriKind]::Absolute,[ref]$uri)) {
    if ($uri.Scheme -in @('http','https')) {
      if (-not $AllowNetwork) { throw 'network_capture_requires_AllowNetwork' }
      return [pscustomobject]@{uri=$uri.AbsoluteUri;fixture_mode=$false}
    }
    if ($uri.Scheme -eq 'file') {
      if (-not $AllowLocalFixture) { throw 'local_capture_requires_AllowLocalFixture' }
      if (-not (Test-Path -LiteralPath $uri.LocalPath -PathType Leaf)) { throw 'local_fixture_source_missing' }
      return [pscustomobject]@{uri=$uri.AbsoluteUri;fixture_mode=$true}
    }
    throw "source_scheme_not_allowed:$($uri.Scheme)"
  }
  if (-not $AllowLocalFixture) { throw 'relative_source_requires_AllowLocalFixture' }
  $localFull = if ([System.IO.Path]::IsPathRooted($Value)) { [System.IO.Path]::GetFullPath($Value) } else { [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Value)) }
  if (-not (Test-Path -LiteralPath $localFull -PathType Leaf)) { throw "local_fixture_source_missing:$localFull" }
  return [pscustomobject]@{uri=([System.Uri]::new($localFull)).AbsoluteUri;fixture_mode=$true}
}

function Write-R6CaptureRecord {
  param([string]$Path, [object]$Record)
  Write-TaogeUtf8NoBomJson -Path $Path -Value $Record -Depth 12
}

try {
  if ($ViewportWidth -lt 320 -or $ViewportHeight -lt 320) { throw 'viewport_too_small' }
  if ($CaptureId -notmatch '^[A-Za-z0-9][A-Za-z0-9._:-]{2,127}$') { throw 'capture_id_invalid' }
  $sessionFull = [System.IO.Path]::GetFullPath($SessionRoot)
  if (-not (Test-Path -LiteralPath $sessionFull -PathType Container)) { throw "session_root_missing:$sessionFull" }
  $source = Resolve-R6CaptureSource -Value $SourceUrl

  $screenshotCheck = Resolve-TaogeContainedPath -AllowedRoot $sessionFull -CandidatePath $ScreenshotRelativePath -RejectReparsePoints
  $attemptCheck = Resolve-TaogeContainedPath -AllowedRoot $sessionFull -CandidatePath $AttemptRelativePath -RejectReparsePoints
  if ($screenshotCheck.status -ne 'pass') { throw "screenshot_path_preflight_failed:$([string]::Join(',',@($screenshotCheck.errors)))" }
  if ($attemptCheck.status -ne 'pass') { throw "attempt_path_preflight_failed:$([string]::Join(',',@($attemptCheck.errors)))" }
  $screenshotFull = [string]$screenshotCheck.resolved_path
  $attemptFull = [string]$attemptCheck.resolved_path
  $pathBudget = Test-TaogePathBudget -InstallationRoot $projectRoot -TargetRoot $sessionFull -RelativePaths @($ScreenshotRelativePath,$AttemptRelativePath)
  if ($pathBudget.status -ne 'pass') { throw 'capture_path_budget_failed' }
  $writable = Test-TaogeWritableTempSpace -TargetRoot $sessionFull -RequiredFreeBytes 10485760 -ProbeWrite
  if ($writable.status -ne 'pass') { throw "capture_target_not_writable:$([string]::Join(',',@($writable.errors)))" }

  $priorAttemptHistory = @()
  $nextAttemptNumber = 1
  $removeUnverifiedOutput = $false
  if (Test-Path -LiteralPath $attemptFull -PathType Leaf) {
    $prior = Get-Content -LiteralPath $attemptFull -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($prior.capture_id -ne $CaptureId -or $prior.source_url -ne $source.uri -or $prior.screenshot_relative_path -ne $ScreenshotRelativePath) {
      throw 'capture_revision_required:attempt_identity_changed'
    }
    if ($prior.capture_status -in @('captured','reconciled_existing_output')) {
      if (-not (Test-Path -LiteralPath $screenshotFull -PathType Leaf)) { throw 'capture_revision_required:completed_output_missing' }
      $actualHash = Get-TaogeFileSha256 -Path $screenshotFull
      if ($actualHash -ne $prior.sha256) { throw 'capture_revision_required:completed_output_hash_mismatch' }
      Write-Output 'R6_SOURCE_CAPTURE=pass'
      Write-Output 'CAPTURE_ACTION=reused_verified'
      Write-Output "SCREENSHOT_SHA256=$actualHash"
      exit 0
    }
    if ($prior.capture_status -eq 'capture_started' -and (Test-Path -LiteralPath $screenshotFull -PathType Leaf)) {
      $reconciledHash = Get-TaogeFileSha256 -Path $screenshotFull
      $reconciled = [ordered]@{}
      foreach ($property in $prior.PSObject.Properties) { $reconciled[$property.Name] = $property.Value }
      $reconciled.capture_status = 'reconciled_existing_output'
      $reconciled.completed_at = [DateTimeOffset]::Now.ToString('o')
      $reconciled.sha256 = $reconciledHash
      $reconciled.file_size = (Get-Item -LiteralPath $screenshotFull).Length
      Write-R6CaptureRecord -Path $attemptFull -Record $reconciled
      Write-Output 'R6_SOURCE_CAPTURE=pass'
      Write-Output 'CAPTURE_ACTION=reconciled_existing_output'
      Write-Output "SCREENSHOT_SHA256=$reconciledHash"
      exit 0
    }
    if (@($prior.PSObject.Properties.Name) -contains 'attempt_history') { $priorAttemptHistory = @($prior.attempt_history) }
    $priorAttemptNumber = if (@($prior.PSObject.Properties.Name) -contains 'attempt_number') { [int]$prior.attempt_number } else { 1 }
    $nextAttemptNumber = $priorAttemptNumber + 1
    $priorAttemptHistory += [ordered]@{
      attempt_number=$priorAttemptNumber
      started_at=$prior.started_at
      completed_at=$prior.completed_at
      capture_status=$(if($prior.capture_status -eq 'capture_started'){'interrupted_no_output'}else{[string]$prior.capture_status})
      process_exit_code=$prior.process_exit_code
      error_category=$prior.error_category
    }
    $removeUnverifiedOutput = Test-Path -LiteralPath $screenshotFull -PathType Leaf
  }

  $browserFull = Resolve-R6CaptureBrowser -RequestedPath $BrowserPath
  $outputParent = Split-Path -Parent $screenshotFull
  if (-not (Test-Path -LiteralPath $outputParent)) { New-Item -ItemType Directory -Path $outputParent -Force | Out-Null }
  $attemptParent = Split-Path -Parent $attemptFull
  if (-not (Test-Path -LiteralPath $attemptParent)) { New-Item -ItemType Directory -Path $attemptParent -Force | Out-Null }
  if ($removeUnverifiedOutput) { Remove-Item -LiteralPath $screenshotFull -Force }

  $profileFull = Join-Path $sessionFull ('.r6-capture-profile-' + $CaptureId)
  $profileCheck = Resolve-TaogeContainedPath -AllowedRoot $sessionFull -CandidatePath $profileFull -RejectReparsePoints
  if ($profileCheck.status -ne 'pass') { throw 'capture_profile_path_invalid' }
  if (Test-Path -LiteralPath $profileFull) {
    $item = Get-Item -LiteralPath $profileFull -Force
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'capture_profile_reparse_point_forbidden' }
    [System.IO.Directory]::Delete($profileFull,$true)
  }

  $startedAt = [DateTimeOffset]::Now.ToString('o')
  $attempt = [ordered]@{
    schema_id='taoge://r6/source-capture-record/v0.1'
    schema_version='0.1.0'
    capture_id=$CaptureId
    source_url=$source.uri
    fixture_mode=[bool]$source.fixture_mode
    screenshot_relative_path=$ScreenshotRelativePath.Replace('\','/')
    viewport=[ordered]@{width=$ViewportWidth;height=$ViewportHeight}
    attempt_number=$nextAttemptNumber
    attempt_history=@($priorAttemptHistory)
    capture_status='capture_started'
    started_at=$startedAt
    completed_at=$null
    browser_path=$browserFull
    process_exit_code=$null
    sha256=$null
    file_size=$null
    error_category=$null
  }
  Write-R6CaptureRecord -Path $attemptFull -Record $attempt

  $stdoutPath = Join-Path $attemptParent ($CaptureId + '.stdout.log')
  $stderrPath = Join-Path $attemptParent ($CaptureId + '.stderr.log')
  $arguments = @(
    '--headless',
    '--disable-gpu',
    '--hide-scrollbars',
    '--run-all-compositor-stages-before-draw',
    '--virtual-time-budget=1500',
    "--window-size=$ViewportWidth,$ViewportHeight",
    "--user-data-dir=$profileFull",
    "--screenshot=$screenshotFull",
    $source.uri
  )
  try {
    $process = Start-TaogeProcess -FilePath $browserFull -Arguments $arguments -StandardOutputPath $stdoutPath -StandardErrorPath $stderrPath -WorkingDirectory $sessionFull -Wait -Hidden
  } catch {
    $failedRecord = [ordered]@{}
    foreach ($entry in $attempt.GetEnumerator()) { $failedRecord[$entry.Key] = $entry.Value }
    $failedRecord.completed_at = [DateTimeOffset]::Now.ToString('o')
    $failedRecord.capture_status = 'capture_failed'
    $failedRecord.error_category = 'browser_process_error'
    $failedRecord.error_message_excerpt = if ([string]::IsNullOrWhiteSpace($_.Exception.Message)) { 'process_start_failed' } else { $_.Exception.Message.Substring(0,[Math]::Min(240,$_.Exception.Message.Length)) }
    Write-R6CaptureRecord -Path $attemptFull -Record $failedRecord
    if (Test-Path -LiteralPath $profileFull) {
      $profileItem = Get-Item -LiteralPath $profileFull -Force
      if (($profileItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) { [System.IO.Directory]::Delete($profileFull,$true) }
    }
    throw
  }
  $exitCode = [int]$process.ExitCode
  $completedAt = [DateTimeOffset]::Now.ToString('o')
  $captureSucceeded = $exitCode -eq 0 -and (Test-Path -LiteralPath $screenshotFull -PathType Leaf) -and (Get-Item -LiteralPath $screenshotFull).Length -gt 0
  $record = [ordered]@{}
  foreach ($entry in $attempt.GetEnumerator()) { $record[$entry.Key] = $entry.Value }
  $record.completed_at = $completedAt
  $record.process_exit_code = $exitCode
  if ($captureSucceeded) {
    $record.capture_status = 'captured'
    $record.sha256 = Get-TaogeFileSha256 -Path $screenshotFull
    $record.file_size = (Get-Item -LiteralPath $screenshotFull).Length
    Write-R6CaptureRecord -Path $attemptFull -Record $record
    if (Test-Path -LiteralPath $stdoutPath) { Remove-Item -LiteralPath $stdoutPath -Force }
    if (Test-Path -LiteralPath $stderrPath) { Remove-Item -LiteralPath $stderrPath -Force }
  } else {
    $record.capture_status = 'capture_failed'
    $record.error_category = if ($exitCode -eq 0) { 'capture_integrity_error' } else { 'browser_process_error' }
    Write-R6CaptureRecord -Path $attemptFull -Record $record
  }
  if (Test-Path -LiteralPath $profileFull) {
    $profileItem = Get-Item -LiteralPath $profileFull -Force
    if (($profileItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) { [System.IO.Directory]::Delete($profileFull,$true) }
  }
  if (-not $captureSucceeded) {
    [Console]::Error.WriteLine("source_capture_failed:$($record.error_category):exit_$exitCode")
    exit 1
  }

  Write-Output 'R6_SOURCE_CAPTURE=pass'
  Write-Output 'CAPTURE_ACTION=captured'
  Write-Output "SCREENSHOT_SHA256=$($record.sha256)"
  exit 0
} catch {
  Write-Error $_
  exit 3
}
