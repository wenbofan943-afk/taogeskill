. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'EnvironmentPreflight.ps1')

$script:TaogeArchiveManifestName = 'archive-manifest.json'

function ConvertTo-TaogeArchiveRelativePath {
  param([Parameter(Mandatory=$true)][string]$Path)
  $value = ($Path -replace '\\','/').Trim('/')
  if ([string]::IsNullOrWhiteSpace($value) -or [System.IO.Path]::IsPathRooted($value) -or $value -match '^[A-Za-z]:') {
    throw "archive_relative_path_invalid:$Path"
  }
  foreach ($segment in @($value -split '/')) {
    $segmentCheck = Test-TaogeWindowsPathSegment -Segment $segment
    if ($segmentCheck.status -ne 'pass') { throw "archive_relative_path_invalid:${Path}:$([string]::Join(',', @($segmentCheck.errors)))" }
  }
  return $value
}

function Get-TaogeArchivePayloadFiles {
  param(
    [Parameter(Mandatory=$true)][string]$SourceRoot,
    [string[]]$ExcludeRelativePaths = @($script:TaogeArchiveManifestName)
  )
  $root = (Resolve-Path -LiteralPath $SourceRoot).Path.TrimEnd('\','/')
  $excluded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($path in @($ExcludeRelativePaths)) {
    if (-not [string]::IsNullOrWhiteSpace($path)) { [void]$excluded.Add((ConvertTo-TaogeArchiveRelativePath -Path $path)) }
  }
  $byPath = @{}
  foreach ($file in @(Get-ChildItem -LiteralPath $root -Recurse -File -Force)) {
    $relative = ConvertTo-TaogeArchiveRelativePath -Path $file.FullName.Substring($root.Length).TrimStart('\','/')
    if ($excluded.Contains($relative)) { continue }
    if ($byPath.ContainsKey($relative)) { throw "archive_case_collision:$relative" }
    $byPath[$relative] = $file
  }
  $paths = [string[]]@($byPath.Keys)
  [Array]::Sort($paths, [System.StringComparer]::Ordinal)
  return @($paths | ForEach-Object {
    $file = $byPath[$_]
    [pscustomobject][ordered]@{
      path = $_
      type = 'file'
      size_bytes = [long]$file.Length
      sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
  })
}

function New-TaogeArchiveManifest {
  param(
    [Parameter(Mandatory=$true)][string]$SourceRoot,
    [string]$ManifestPath = '',
    [Parameter(Mandatory=$true)][string]$ArchiveKind,
    [string[]]$RequiredPaths = @()
  )
  $root = (Resolve-Path -LiteralPath $SourceRoot).Path
  if ([string]::IsNullOrWhiteSpace($ManifestPath)) { $ManifestPath = Join-Path $root $script:TaogeArchiveManifestName }
  $manifestFullPath = [System.IO.Path]::GetFullPath($ManifestPath)
  $manifestContainment = Resolve-TaogeContainedPath -AllowedRoot $root -CandidatePath $manifestFullPath -RejectReparsePoints
  if ($manifestContainment.status -ne 'pass') { throw "archive_manifest_path_invalid:$([string]::Join(',', @($manifestContainment.errors)))" }

  $required = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($path in @($RequiredPaths)) { [void]$required.Add((ConvertTo-TaogeArchiveRelativePath -Path $path)) }
  $files = @(Get-TaogeArchivePayloadFiles -SourceRoot $root -ExcludeRelativePaths @($script:TaogeArchiveManifestName))
  $filePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($file in $files) { [void]$filePaths.Add([string]$file.path) }
  $missingRequired = @($required | Where-Object { -not $filePaths.Contains($_) })
  if ($missingRequired.Count -gt 0) { throw "archive_required_file_missing:$([string]::Join(',', $missingRequired))" }

  $requiredSorted = [string[]]@($required)
  [Array]::Sort($requiredSorted, [System.StringComparer]::Ordinal)
  $totalBytes = [long]0
  foreach ($file in $files) { $totalBytes += [long]$file.size_bytes }
  $document = [ordered]@{
    archive_manifest = [ordered]@{
      schema_version = 'taoge.archive-manifest.v0.1'
      archive_kind = $ArchiveKind
      created_at = [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)
      path_format = 'normalized_forward_slash_relative'
      hash_algorithm = 'sha256'
      manifest_path = $script:TaogeArchiveManifestName
      file_count = $files.Count
      total_bytes = $totalBytes
      required_files = $requiredSorted
      files = $files
    }
  }
  Write-TaogeUtf8NoBomJson -Path $manifestFullPath -Value $document -Depth 10
  return [pscustomobject]@{ path=$manifestFullPath; document=$document }
}

function Test-TaogeArchivePayload {
  param(
    [Parameter(Mandatory=$true)][string]$PayloadRoot,
    [string]$ManifestPath = ''
  )
  $errors = [System.Collections.Generic.List[string]]::new()
  try {
    $root = (Resolve-Path -LiteralPath $PayloadRoot).Path
    if ([string]::IsNullOrWhiteSpace($ManifestPath)) { $ManifestPath = Join-Path $root $script:TaogeArchiveManifestName }
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) { throw 'archive_manifest_missing' }
    $document = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $manifest = $document.archive_manifest
    if ($null -eq $manifest -or $manifest.schema_version -ne 'taoge.archive-manifest.v0.1') { throw 'archive_manifest_schema_invalid' }

    $expected = [System.Collections.Generic.Dictionary[string,object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($record in @($manifest.files)) {
      $relative = ConvertTo-TaogeArchiveRelativePath -Path ([string]$record.path)
      if ($expected.ContainsKey($relative)) { $errors.Add("manifest_duplicate_path:$relative"); continue }
      $expected.Add($relative, $record)
    }
    $actualRecords = @(Get-TaogeArchivePayloadFiles -SourceRoot $root -ExcludeRelativePaths @($script:TaogeArchiveManifestName))
    $actual = [System.Collections.Generic.Dictionary[string,object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($record in $actualRecords) {
      if ($actual.ContainsKey([string]$record.path)) { $errors.Add("payload_duplicate_path:$($record.path)"); continue }
      $actual.Add([string]$record.path, $record)
    }
    if ([int]$manifest.file_count -ne $expected.Count) { $errors.Add("manifest_file_count_mismatch:declared=$($manifest.file_count);listed=$($expected.Count)") }
    if ($actual.Count -ne $expected.Count) { $errors.Add("payload_file_count_mismatch:expected=$($expected.Count);actual=$($actual.Count)") }
    foreach ($path in $expected.Keys) {
      if (-not $actual.ContainsKey($path)) { $errors.Add("payload_file_missing:$path"); continue }
      $expectedRecord = $expected[$path]
      $actualRecord = $actual[$path]
      if ([long]$expectedRecord.size_bytes -ne [long]$actualRecord.size_bytes) { $errors.Add("payload_size_mismatch:$path") }
      if ([string]$expectedRecord.sha256 -ne [string]$actualRecord.sha256) { $errors.Add("payload_hash_mismatch:$path") }
    }
    foreach ($path in $actual.Keys) { if (-not $expected.ContainsKey($path)) { $errors.Add("payload_unexpected_file:$path") } }
    foreach ($pathValue in @($manifest.required_files)) {
      $path = ConvertTo-TaogeArchiveRelativePath -Path ([string]$pathValue)
      if (-not $expected.ContainsKey($path) -or -not $actual.ContainsKey($path)) { $errors.Add("required_file_missing:$path") }
    }
  } catch {
    $errors.Add($_.Exception.Message)
  }
  return [pscustomobject][ordered]@{
    status = if ($errors.Count -eq 0) { 'pass' } else { 'fail' }
    expected_file_count = if ($null -ne $expected) { $expected.Count } else { 0 }
    actual_file_count = if ($null -ne $actual) { $actual.Count } else { 0 }
    errors = $errors.ToArray()
  }
}

function New-TaogeZipCandidate {
  param(
    [Parameter(Mandatory=$true)][string]$SourceRoot,
    [Parameter(Mandatory=$true)][string]$ArchivePath
  )
  Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
  Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
  $root = (Resolve-Path -LiteralPath $SourceRoot).Path.TrimEnd('\','/')
  $archiveFullPath = [System.IO.Path]::GetFullPath($ArchivePath)
  $parent = Split-Path -Parent $archiveFullPath
  if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  if (Test-Path -LiteralPath $archiveFullPath) { Remove-Item -LiteralPath $archiveFullPath -Force }
  $files = @{}
  foreach ($file in @(Get-ChildItem -LiteralPath $root -Recurse -File -Force)) {
    $relative = ConvertTo-TaogeArchiveRelativePath -Path $file.FullName.Substring($root.Length).TrimStart('\','/')
    if ($files.ContainsKey($relative)) { throw "archive_case_collision:$relative" }
    $files[$relative] = $file.FullName
  }
  $paths = [string[]]@($files.Keys)
  [Array]::Sort($paths, [System.StringComparer]::Ordinal)
  $stream = [System.IO.File]::Open($archiveFullPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
  try {
    $zip = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create, $false, [System.Text.Encoding]::UTF8)
    try {
      foreach ($path in $paths) {
        $entry = $zip.CreateEntry($path, [System.IO.Compression.CompressionLevel]::Optimal)
        $entryStream = $entry.Open()
        $sourceStream = [System.IO.File]::OpenRead($files[$path])
        try { $sourceStream.CopyTo($entryStream) } finally { $sourceStream.Dispose(); $entryStream.Dispose() }
      }
    } finally { $zip.Dispose() }
  } finally { $stream.Dispose() }
  return $archiveFullPath
}

function Expand-TaogeArchiveSecure {
  param(
    [Parameter(Mandatory=$true)][string]$ArchivePath,
    [Parameter(Mandatory=$true)][string]$DestinationRoot
  )
  Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
  $archive = (Resolve-Path -LiteralPath $ArchivePath).Path
  $destination = [System.IO.Path]::GetFullPath($DestinationRoot)
  if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
  New-Item -ItemType Directory -Path $destination -Force | Out-Null
  $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $stream = [System.IO.File]::OpenRead($archive)
  try {
    $zip = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Read, $false, [System.Text.Encoding]::UTF8)
    try {
      foreach ($entry in $zip.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) { continue }
        $relative = ConvertTo-TaogeArchiveRelativePath -Path $entry.FullName
        if (-not $seen.Add($relative)) { throw "archive_duplicate_or_case_collision:$relative" }
        $target = Join-Path $destination ($relative -replace '/', '\')
        $containment = Resolve-TaogeContainedPath -AllowedRoot $destination -CandidatePath $target -RejectReparsePoints
        if ($containment.status -ne 'pass') { throw "archive_entry_outside_root:$relative" }
        $parent = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        $entryStream = $entry.Open()
        $targetStream = [System.IO.File]::Open($target, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try { $entryStream.CopyTo($targetStream) } finally { $entryStream.Dispose(); $targetStream.Dispose() }
      }
    } finally { $zip.Dispose() }
  } finally { $stream.Dispose() }
  return [pscustomobject]@{ destination=$destination; extracted_file_count=$seen.Count }
}

function Test-TaogeArchiveFile {
  param(
    [Parameter(Mandatory=$true)][string]$ArchivePath,
    [string]$VerificationRoot = ''
  )
  $errors = [System.Collections.Generic.List[string]]::new()
  $payloadResult = $null
  $archiveHash = ''
  try {
    $archive = (Resolve-Path -LiteralPath $ArchivePath).Path
    if ([string]::IsNullOrWhiteSpace($VerificationRoot)) { $VerificationRoot = Join-Path (Split-Path -Parent $archive) ('.v-' + [guid]::NewGuid().ToString('N').Substring(0,4)) }
    $archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    [void](Expand-TaogeArchiveSecure -ArchivePath $archive -DestinationRoot $VerificationRoot)
    $payloadResult = Test-TaogeArchivePayload -PayloadRoot $VerificationRoot
    foreach ($errorItem in @($payloadResult.errors)) { $errors.Add([string]$errorItem) }
  } catch {
    $errors.Add($_.Exception.Message)
  } finally {
    if (-not [string]::IsNullOrWhiteSpace($VerificationRoot) -and (Test-Path -LiteralPath $VerificationRoot)) { Remove-Item -LiteralPath $VerificationRoot -Recurse -Force -ErrorAction SilentlyContinue }
  }
  return [pscustomobject][ordered]@{
    status = if ($errors.Count -eq 0) { 'pass' } else { 'fail' }
    archive_sha256 = $archiveHash
    expected_file_count = if ($null -ne $payloadResult) { $payloadResult.expected_file_count } else { 0 }
    actual_file_count = if ($null -ne $payloadResult) { $payloadResult.actual_file_count } else { 0 }
    errors = $errors.ToArray()
  }
}

function Publish-TaogeVerifiedArchiveCandidate {
  param(
    [Parameter(Mandatory=$true)][string]$CandidateArchivePath,
    [Parameter(Mandatory=$true)][string]$DestinationArchivePath,
    [string]$VerificationRoot = ''
  )
  $result = Test-TaogeArchiveFile -ArchivePath $CandidateArchivePath -VerificationRoot $VerificationRoot
  if ($result.status -ne 'pass') { throw "archive_candidate_verification_failed:$([string]::Join(',', @($result.errors)))" }
  $destination = [System.IO.Path]::GetFullPath($DestinationArchivePath)
  $parent = Split-Path -Parent $destination
  if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  if (Test-Path -LiteralPath $destination) {
    $backup = $destination + '.' + [guid]::NewGuid().ToString('N') + '.backup'
    try { [System.IO.File]::Replace($CandidateArchivePath,$destination,$backup,$true) } finally { if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue } }
  } else {
    Move-Item -LiteralPath $CandidateArchivePath -Destination $destination
  }
  return [pscustomobject]@{ archive_path=$destination; verification=$result }
}

function New-TaogeVerifiedArchive {
  param(
    [Parameter(Mandatory=$true)][string]$SourceRoot,
    [Parameter(Mandatory=$true)][string]$ArchivePath,
    [Parameter(Mandatory=$true)][string]$ArchiveKind,
    [string[]]$RequiredPaths = @(),
    [string]$VerificationRoot = ''
  )
  $root = (Resolve-Path -LiteralPath $SourceRoot).Path
  [void](New-TaogeArchiveManifest -SourceRoot $root -ArchiveKind $ArchiveKind -RequiredPaths $RequiredPaths)
  $destination = [System.IO.Path]::GetFullPath($ArchivePath)
  $candidate = Join-Path (Split-Path -Parent $destination) ('.' + (Split-Path -Leaf $destination) + '.' + [guid]::NewGuid().ToString('N') + '.partial')
  try {
    [void](New-TaogeZipCandidate -SourceRoot $root -ArchivePath $candidate)
    $published = Publish-TaogeVerifiedArchiveCandidate -CandidateArchivePath $candidate -DestinationArchivePath $destination -VerificationRoot $VerificationRoot
    return [pscustomobject][ordered]@{
      status = 'pass'
      archive_path = $published.archive_path
      archive_sha256 = $published.verification.archive_sha256
      file_count = $published.verification.actual_file_count
      manifest_path = Join-Path $root $script:TaogeArchiveManifestName
    }
  } finally {
    if (Test-Path -LiteralPath $candidate) { Remove-Item -LiteralPath $candidate -Force -ErrorAction SilentlyContinue }
  }
}
