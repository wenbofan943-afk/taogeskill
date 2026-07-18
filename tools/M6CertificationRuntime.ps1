. (Join-Path $PSScriptRoot 'R8H5InputRuntime.ps1')
. (Join-Path $PSScriptRoot 'R8H5SchemaRuntime.ps1')

function Initialize-M6CertificationRuntime {
  param([Parameter(Mandatory=$true)][string]$ProjectRoot)
  $script:M6ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\','/')
  $script:M6ContractPath = Join-Path $script:M6ProjectRoot 'routes/m6-certification-contract.json'
  if (-not (Test-Path -LiteralPath $script:M6ContractPath -PathType Leaf)) {
    throw 'm6_certification_contract_missing'
  }
}

function Read-M6Json {
  param([Parameter(Mandatory=$true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "m6_json_missing:$Path"
  }
  return [System.IO.File]::ReadAllText(
    (Resolve-TaogeFileSystemPath -Path $Path),
    (Get-TaogeUtf8NoBomEncoding)
  ) | ConvertFrom-Json
}

function Get-M6TextSha256 {
  param([AllowEmptyString()][string]$Text = '')
  $algorithm = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = (Get-TaogeUtf8NoBomEncoding).GetBytes($Text)
    $digest = $algorithm.ComputeHash($bytes)
    return 'sha256:' + (([System.BitConverter]::ToString($digest)) -replace '-','').ToLowerInvariant()
  } finally {
    $algorithm.Dispose()
  }
}

function Assert-M6Timestamp {
  param([Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$Value)
  $parsed = [DateTimeOffset]::MinValue
  if ($Value -notmatch '(Z|[+-][0-9]{2}:[0-9]{2})$' -or
      -not [DateTimeOffset]::TryParse(
        $Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None,
        [ref]$parsed
      )) {
    throw "m6_timestamp_invalid:$Name"
  }
}

function Resolve-M6SourcePath {
  param([Parameter(Mandatory=$true)][string]$RelativePath)
  if ([string]::IsNullOrWhiteSpace($RelativePath) -or
      [System.IO.Path]::IsPathRooted($RelativePath) -or
      $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
    throw "m6_relative_path_invalid:$RelativePath"
  }
  $normalized = $RelativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar
  $full = [System.IO.Path]::GetFullPath((Join-Path $script:M6ProjectRoot $normalized))
  $prefix = $script:M6ProjectRoot + [System.IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($prefix,[System.StringComparison]::OrdinalIgnoreCase)) {
    throw "m6_source_path_escape:$RelativePath"
  }
  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
    throw "m6_source_file_missing:$RelativePath"
  }
  return $full
}

function Assert-M6CheckOutputPath {
  param([Parameter(Mandatory=$true)][string]$Path)
  $full = [System.IO.Path]::GetFullPath($Path)
  $allowed = [System.IO.Path]::GetFullPath((Join-Path $script:M6ProjectRoot 'state/checks')).TrimEnd('\','/')
  $prefix = $allowed + [System.IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($prefix,[System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'm6_output_must_be_under_state_checks'
  }
  return $full
}

function New-M6CertificationFreeze {
  param(
    [Parameter(Mandatory=$true)][string]$SourceRevision,
    [Parameter(Mandatory=$true)][string]$GeneratedAt,
    [Parameter(Mandatory=$true)][string]$FreezeId
  )
  if ([string]::IsNullOrWhiteSpace($SourceRevision)) {
    throw 'm6_source_revision_required'
  }
  if ($FreezeId -notmatch '^M6-FREEZE-[A-Za-z0-9._-]+$') {
    throw 'm6_freeze_id_invalid'
  }
  Assert-M6Timestamp 'generated_at' $GeneratedAt
  $contract = Read-M6Json $script:M6ContractPath
  $categories = @()
  $seenCategories = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
  $seenPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

  foreach ($category in @($contract.freeze_categories)) {
    $categoryId = [string]$category.category_id
    if (-not $seenCategories.Add($categoryId)) {
      throw "m6_duplicate_freeze_category:$categoryId"
    }
    $files = @()
    foreach ($relativePath in @($category.paths | Sort-Object)) {
      $relative = ([string]$relativePath) -replace '\\','/'
      if (-not $seenPaths.Add($relative)) {
        throw "m6_duplicate_freeze_path:$relative"
      }
      $full = Resolve-M6SourcePath $relative
      $item = Get-Item -LiteralPath $full
      $files += [pscustomobject][ordered]@{
        relative_path = $relative
        sha256 = 'sha256:' + (Get-TaogeFileSha256 $full)
        length = [int64]$item.Length
      }
    }
    if ($files.Count -lt 1) {
      throw "m6_empty_freeze_category:$categoryId"
    }
    $categoryLines = @($files | ForEach-Object {
      "$($_.relative_path)|$($_.sha256)|$($_.length)"
    })
    $categories += [pscustomobject][ordered]@{
      category_id = $categoryId
      file_count = $files.Count
      aggregate_sha256 = Get-M6TextSha256 ([string]::Join("`n",$categoryLines))
      files = @($files)
    }
  }

  $required = @(
    'product_contract',
    'architecture_decision',
    'runtime_build',
    'evaluator_build',
    'fixture_catalog'
  )
  if ($categories.Count -ne $required.Count -or
      [string]::Join('|',@($categories.category_id | Sort-Object)) -ne
      [string]::Join('|',@($required | Sort-Object))) {
    throw 'm6_freeze_category_set_invalid'
  }
  $aggregateLines = @($categories | Sort-Object category_id | ForEach-Object {
    "$($_.category_id)|$($_.file_count)|$($_.aggregate_sha256)"
  })
  return [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/m6/certification-freeze/v0.1'
    schema_version = '0.1'
    certification_program_id = [string]$contract.certification_program_id
    freeze_id = $FreezeId
    source_revision = $SourceRevision
    generated_at = $GeneratedAt
    build_profile = 'test'
    categories = @($categories)
    aggregate_sha256 = Get-M6TextSha256 ([string]::Join("`n",$aggregateLines))
  }
}

function Test-M6CertificationFreeze {
  param(
    [Parameter(Mandatory=$true)][object]$Manifest,
    [string]$ExpectedSourceRevision = ''
  )
  $errors = [System.Collections.Generic.List[string]]::new()
  $schemaPath = Join-Path $script:M6ProjectRoot 'templates/schema/m6/certification-freeze.v0.1.schema.json'
  foreach ($item in @(Test-R8H5JsonSchemaValue $schemaPath $Manifest)) {
    $errors.Add("freeze_schema:$item")
  }
  if (-not [string]::IsNullOrWhiteSpace($ExpectedSourceRevision) -and
      [string]$Manifest.source_revision -ne $ExpectedSourceRevision) {
    $errors.Add('freeze_source_revision_mismatch')
  }
  try {
    $current = New-M6CertificationFreeze `
      -SourceRevision ([string]$Manifest.source_revision) `
      -GeneratedAt ([string]$Manifest.generated_at) `
      -FreezeId ([string]$Manifest.freeze_id)
    if ([string]$current.aggregate_sha256 -ne [string]$Manifest.aggregate_sha256) {
      $errors.Add('freeze_aggregate_digest_mismatch')
    }
    $expectedCategories = @($current.categories)
    $actualCategories = @($Manifest.categories)
    if ($expectedCategories.Count -ne $actualCategories.Count) {
      $errors.Add('freeze_category_count_mismatch')
    } else {
      for ($index = 0; $index -lt $expectedCategories.Count; $index++) {
        $expected = $expectedCategories[$index]
        $actual = $actualCategories[$index]
        if ($expected.category_id -ne $actual.category_id -or
            $expected.file_count -ne $actual.file_count -or
            $expected.aggregate_sha256 -ne $actual.aggregate_sha256) {
          $errors.Add("freeze_category_mismatch:$($expected.category_id)")
          continue
        }
        $expectedFiles = @($expected.files)
        $actualFiles = @($actual.files)
        if ($expectedFiles.Count -ne $actualFiles.Count) {
          $errors.Add("freeze_file_count_mismatch:$($expected.category_id)")
          continue
        }
        for ($fileIndex = 0; $fileIndex -lt $expectedFiles.Count; $fileIndex++) {
          $expectedFile = $expectedFiles[$fileIndex]
          $actualFile = $actualFiles[$fileIndex]
          if ($expectedFile.relative_path -ne $actualFile.relative_path -or
              $expectedFile.sha256 -ne $actualFile.sha256 -or
              $expectedFile.length -ne $actualFile.length) {
            $errors.Add("freeze_file_mismatch:$($expectedFile.relative_path)")
          }
        }
      }
    }
  } catch {
    $errors.Add("freeze_rebuild_failed:$($_.Exception.Message)")
  }
  return [pscustomobject][ordered]@{
    result = if ($errors.Count -eq 0) { 'pass' } else { 'fail' }
    errors = @($errors)
  }
}

function Write-M6CertificationFreeze {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][object]$Manifest
  )
  $target = Assert-M6CheckOutputPath $Path
  Write-TaogeUtf8NoBomJson -Path $target -Value $Manifest -Depth 20
  return $target
}
