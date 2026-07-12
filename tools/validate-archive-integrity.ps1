param(
  [string]$FixturePath = '',
  [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'ArchiveIntegrity.ps1')

function Add-H4Check {
  param(
    [System.Collections.Generic.List[object]]$Checks,
    [string]$Id,
    [bool]$Passed,
    [string]$Evidence
  )
  $status = if ($Passed) { 'pass' } else { 'fail' }
  $Checks.Add([pscustomobject][ordered]@{ check_id=$Id; status=$status; evidence=$Evidence })
  Write-Output "$Id $status $Evidence"
}

function Copy-H4Tree {
  param([string]$Source,[string]$Destination)
  if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Recurse -Force }
  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  Get-ChildItem -LiteralPath $Source -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force }
}

function New-H4RawZip {
  param([string]$Path,[object[]]$Entries)
  Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
  $stream = [System.IO.File]::Open($Path,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
  try {
    $zip = [System.IO.Compression.ZipArchive]::new($stream,[System.IO.Compression.ZipArchiveMode]::Create,$false,[System.Text.Encoding]::UTF8)
    try {
      foreach ($item in $Entries) {
        $entry = $zip.CreateEntry([string]$item.path)
        $writer = [System.IO.StreamWriter]::new($entry.Open(),[System.Text.UTF8Encoding]::new($false))
        try { $writer.Write([string]$item.content) } finally { $writer.Dispose() }
      }
    } finally { $zip.Dispose() }
  } finally { $stream.Dispose() }
}

try {
  $projectRoot = Split-Path -Parent $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($FixturePath)) { $FixturePath = Join-Path $projectRoot 'examples\windows-archive-integrity-fixture\fixtures.json' }
  if ([string]::IsNullOrWhiteSpace($ReportPath)) { $ReportPath = Join-Path $projectRoot 'state\checks\archive-integrity-fixture-report.json' }
  $fixture = Get-Content -LiteralPath $FixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
  $work = Join-Path $projectRoot 'state\checks\archive-integrity-work'
  if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
  $source = Join-Path $work 'source 空格中文'
  New-Item -ItemType Directory -Path (Join-Path $source 'data') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $source '.github\workflows') -Force | Out-Null
  Write-TaogeUtf8NoBomText -Path (Join-Path $source 'README.md') -Text '# fixture' -EnsureFinalNewline
  Write-TaogeUtf8NoBomText -Path (Join-Path $source 'data\中文 payload.txt') -Text 'payload-v1' -EnsureFinalNewline
  Write-TaogeUtf8NoBomText -Path (Join-Path $source '.github\workflows\fixture.yml') -Text 'name: fixture' -EnsureFinalNewline

  $checks = [System.Collections.Generic.List[object]]::new()
  $validZip = Join-Path $work 'valid fixture.zip'
  $valid = New-TaogeVerifiedArchive -SourceRoot $source -ArchivePath $validZip -ArchiveKind ([string]$fixture.archive_kind) -RequiredPaths @($fixture.required_paths)
  $manifestPath = Join-Path $source 'archive-manifest.json'
  $manifestBytes = [System.IO.File]::ReadAllBytes($manifestPath)
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $listedPaths = @($manifest.archive_manifest.files | ForEach-Object { [string]$_.path })
  $sortedPaths = [string[]]@($listedPaths); [Array]::Sort($sortedPaths,[System.StringComparer]::Ordinal)
  Add-H4Check $checks 'WIN-H4-001-manifest-schema' ($manifest.archive_manifest.schema_version -eq 'taoge.archive-manifest.v0.1') "kind=$($manifest.archive_manifest.archive_kind)"
  Add-H4Check $checks 'WIN-H4-002-normalized-ordinal-paths' (([string]::Join('|',$listedPaths) -eq [string]::Join('|',$sortedPaths)) -and @($listedPaths | Where-Object { $_ -match '\\' }).Count -eq 0) "count=$($listedPaths.Count)"
  Add-H4Check $checks 'WIN-H4-003-required-files-declared' (@($fixture.required_paths | Where-Object { $_ -notin @($manifest.archive_manifest.required_files) }).Count -eq 0) "required=$(@($manifest.archive_manifest.required_files).Count)"
  Add-H4Check $checks 'WIN-H4-004-manifest-utf8-no-bom' (-not ($manifestBytes.Length -ge 3 -and $manifestBytes[0] -eq 239 -and $manifestBytes[1] -eq 187 -and $manifestBytes[2] -eq 191)) "bytes=$($manifestBytes.Length)"
  $validCheck = Test-TaogeArchiveFile -ArchivePath $validZip
  Add-H4Check $checks 'WIN-H4-005-valid-archive-verified' ($valid.status -eq 'pass' -and $validCheck.status -eq 'pass') "sha256=$($valid.archive_sha256)"
  Add-H4Check $checks 'WIN-H4-006-count-parity' ($validCheck.expected_file_count -eq $validCheck.actual_file_count -and $validCheck.actual_file_count -eq $listedPaths.Count) "expected=$($validCheck.expected_file_count);actual=$($validCheck.actual_file_count)"
  Add-H4Check $checks 'WIN-H4-007-hidden-file-included' ($listedPaths -contains '.github/workflows/fixture.yml') '.github/workflows/fixture.yml'

  $missingRoot = Join-Path $work 'missing'; Copy-H4Tree $source $missingRoot
  Remove-Item -LiteralPath (Join-Path $missingRoot 'data\中文 payload.txt') -Force
  $missingZip = Join-Path $work 'missing.zip'; [void](New-TaogeZipCandidate -SourceRoot $missingRoot -ArchivePath $missingZip)
  $missingCheck = Test-TaogeArchiveFile -ArchivePath $missingZip
  Add-H4Check $checks 'WIN-H4-008-missing-payload-blocked' ($missingCheck.status -eq 'fail' -and @($missingCheck.errors | Where-Object { $_ -match 'file_count|file_missing|required_file' }).Count -gt 0) ([string]::Join('|',@($missingCheck.errors)))

  $mutatedRoot = Join-Path $work 'mutated'; Copy-H4Tree $source $mutatedRoot
  Write-TaogeUtf8NoBomText -Path (Join-Path $mutatedRoot 'README.md') -Text 'mutated' -EnsureFinalNewline
  $mutatedZip = Join-Path $work 'mutated.zip'; [void](New-TaogeZipCandidate -SourceRoot $mutatedRoot -ArchivePath $mutatedZip)
  $mutatedCheck = Test-TaogeArchiveFile -ArchivePath $mutatedZip
  Add-H4Check $checks 'WIN-H4-009-hash-mismatch-blocked' ($mutatedCheck.status -eq 'fail' -and @($mutatedCheck.errors | Where-Object { $_ -match 'hash_mismatch|size_mismatch' }).Count -gt 0) ([string]::Join('|',@($mutatedCheck.errors)))

  $noManifestRoot = Join-Path $work 'no-manifest'; Copy-H4Tree $source $noManifestRoot
  Remove-Item -LiteralPath (Join-Path $noManifestRoot 'archive-manifest.json') -Force
  $noManifestZip = Join-Path $work 'no-manifest.zip'; [void](New-TaogeZipCandidate -SourceRoot $noManifestRoot -ArchivePath $noManifestZip)
  $noManifestCheck = Test-TaogeArchiveFile -ArchivePath $noManifestZip
  Add-H4Check $checks 'WIN-H4-010-missing-manifest-blocked' ($noManifestCheck.status -eq 'fail' -and @($noManifestCheck.errors | Where-Object { $_ -match 'manifest_missing' }).Count -gt 0) ([string]::Join('|',@($noManifestCheck.errors)))

  $zipSlip = Join-Path $work 'zip-slip.zip'; New-H4RawZip $zipSlip @([pscustomobject]@{path='../escape.txt';content='escape'})
  $zipSlipCheck = Test-TaogeArchiveFile -ArchivePath $zipSlip
  Add-H4Check $checks 'WIN-H4-011-zip-slip-blocked' ($zipSlipCheck.status -eq 'fail' -and @($zipSlipCheck.errors | Where-Object { $_ -match 'relative_path_invalid|outside_root' }).Count -gt 0) ([string]::Join('|',@($zipSlipCheck.errors)))

  $caseZip = Join-Path $work 'case-collision.zip'; New-H4RawZip $caseZip @([pscustomobject]@{path='A.txt';content='A'},[pscustomobject]@{path='a.txt';content='a'})
  $caseCheck = Test-TaogeArchiveFile -ArchivePath $caseZip
  Add-H4Check $checks 'WIN-H4-012-case-collision-blocked' ($caseCheck.status -eq 'fail' -and @($caseCheck.errors | Where-Object { $_ -match 'duplicate_or_case_collision' }).Count -gt 0) ([string]::Join('|',@($caseCheck.errors)))

  $preservedZip = Join-Path $work 'preserved.zip'; Copy-Item -LiteralPath $validZip -Destination $preservedZip -Force
  $beforeHash = (Get-FileHash -LiteralPath $preservedZip -Algorithm SHA256).Hash
  $publishFailed = $false
  try { [void](Publish-TaogeVerifiedArchiveCandidate -CandidateArchivePath $missingZip -DestinationArchivePath $preservedZip) } catch { $publishFailed = $true }
  $afterHash = (Get-FileHash -LiteralPath $preservedZip -Algorithm SHA256).Hash
  Add-H4Check $checks 'WIN-H4-013-invalid-candidate-preserves-good-archive' ($publishFailed -and $beforeHash -eq $afterHash -and (Test-TaogeArchiveFile -ArchivePath $preservedZip).status -eq 'pass') "preserved=$($beforeHash -eq $afterHash)"

  $supportProject = Join-Path $work 'support project 中文'
  $supportRun = Join-Path $supportProject 'accounts\sample\runs\SAMPLE-H4'
  New-Item -ItemType Directory -Path $supportRun -Force | Out-Null
  Write-TaogeUtf8NoBomText -Path (Join-Path $supportRun 'manifest.yaml') -Text "session_id: SAMPLE-H4`naccount: sample`ncurrent_stage: test" -EnsureFinalNewline
  $supportOutput = Join-Path $supportProject 'support-logs'
  $stdout = Join-Path $work 'support.stdout.txt'; $stderr = Join-Path $work 'support.stderr.txt'
  $runtimeHost = (Get-Process -Id $PID).Path
  $foreignCwd = Join-Path $work 'foreign cwd'; New-Item -ItemType Directory -Path $foreignCwd -Force | Out-Null
  $supportProcess = Start-TaogeProcess -FilePath $runtimeHost -Arguments @('-NoLogo','-NoProfile','-File',(Join-Path $PSScriptRoot 'export-support-log.ps1'),'-ProjectRoot',$supportProject,'-RunPath',$supportRun,'-SessionId','SAMPLE-H4','-OutputRoot',$supportOutput) -StandardOutputPath $stdout -StandardErrorPath $stderr -WorkingDirectory $foreignCwd -Wait -Hidden
  $supportZip = @(Get-ChildItem -LiteralPath $supportOutput -Filter '*.zip' -File -ErrorAction SilentlyContinue | Select-Object -First 1)
  $supportCheck = if ($supportZip.Count -eq 1) { Test-TaogeArchiveFile -ArchivePath $supportZip[0].FullName } else { $null }
  Add-H4Check $checks 'WIN-H4-014-support-log-verified-foreign-cwd' ($supportProcess.ExitCode -eq 0 -and $null -ne $supportCheck -and $supportCheck.status -eq 'pass') "exit=$($supportProcess.ExitCode);zip_count=$($supportZip.Count)"

  $nonGitSource = Join-Path $work 'n'
  $proofLeaf = 'proof.txt'
  $proofBase = Join-Path $nonGitSource 'docs'
  $proofSegmentLength = [Math]::Max(24, 245 - $proofBase.Length - 2 - $proofLeaf.Length)
  $deepProof = Join-Path $proofBase (('x' * $proofSegmentLength) + '\' + $proofLeaf)
  New-Item -ItemType Directory -Path (Split-Path -Parent $deepProof) -Force | Out-Null
  Write-TaogeUtf8NoBomText -Path (Join-Path $nonGitSource 'VERSION') -Text '0.0.0-h4-fixture' -EnsureFinalNewline
  Write-TaogeUtf8NoBomText -Path $deepProof -Text 'must be included in non-git path budget' -EnsureFinalNewline
  $nonGitPublic = Join-Path $nonGitSource 'releases\h4-negative\public_release'
  New-Item -ItemType Directory -Path $nonGitPublic -Force | Out-Null
  $sentinel = Join-Path $nonGitPublic 'sentinel.keep'; Write-TaogeUtf8NoBomText -Path $sentinel -Text 'preserve'
  $nonGitStdout = Join-Path $work 'non-git-build.stdout.txt'; $nonGitStderr = Join-Path $work 'non-git-build.stderr.txt'
  $nonGitProcess = Start-TaogeProcess -FilePath $runtimeHost -Arguments @('-NoLogo','-NoProfile','-File',(Join-Path $PSScriptRoot 'build-public-release.ps1'),'-ProjectRoot',$nonGitSource,'-PublicReleasePath',$nonGitPublic,'-ZipPath',(Join-Path $nonGitSource 'releases\h4-negative\candidate.zip'),'-Sha256Path',(Join-Path $nonGitSource 'releases\h4-negative\candidate.zip.sha256')) -StandardOutputPath $nonGitStdout -StandardErrorPath $nonGitStderr -Wait -Hidden
  $nonGitOutput = (Get-Content -LiteralPath $nonGitStdout -Raw -Encoding UTF8 -ErrorAction SilentlyContinue) + (Get-Content -LiteralPath $nonGitStderr -Raw -Encoding UTF8 -ErrorAction SilentlyContinue)
  Add-H4Check $checks 'WIN-H4-015-non-git-full-path-budget-before-clear' ($nonGitProcess.ExitCode -ne 0 -and $nonGitOutput -match 'environment_preflight_failed' -and (Test-Path -LiteralPath $sentinel)) "exit=$($nonGitProcess.ExitCode);sentinel=$(Test-Path -LiteralPath $sentinel)"

  $buildText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'build-public-release.ps1') -Raw -Encoding UTF8
  $supportText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'export-support-log.ps1') -Raw -Encoding UTF8
  Add-H4Check $checks 'WIN-H4-016-public-build-wired' ($buildText -match 'New-TaogeVerifiedArchive' -and $buildText -match "ArchiveKind 'public_release'") 'public release uses verified temporary candidate'
  Add-H4Check $checks 'WIN-H4-017-support-export-wired' ($supportText -match 'New-TaogeVerifiedArchive' -and $supportText -match "ArchiveKind 'support_log'") 'support log uses shared archive helper'
  Add-H4Check $checks 'WIN-H4-018-no-exit-code-only-archive-path' ($buildText -notmatch 'Compress-Archive' -and $supportText -notmatch 'Compress-Archive') 'legacy archive success shortcut removed'

  $failed = @($checks | Where-Object { $_.status -ne 'pass' })
  $report = [ordered]@{
    fixture_id = $fixture.fixture_id
    status = if ($failed.Count -eq 0 -and $checks.Count -eq [int]$fixture.expected_check_count) { 'pass' } else { 'fail' }
    check_count = $checks.Count
    expected_check_count = [int]$fixture.expected_check_count
    checks = $checks.ToArray()
    network_called = $false
    system_configuration_mutated = $false
    real_account_data_used = $false
  }
  Write-TaogeUtf8NoBomJson -Path $ReportPath -Value $report -Depth 10
  Write-Output "ARCHIVE_INTEGRITY_FIXTURE_CHECK=$($report.status)"
  Write-Output "ARCHIVE_INTEGRITY_CHECK_COUNT=$($checks.Count)"
  Write-Output "ARCHIVE_INTEGRITY_REPORT=$ReportPath"
  if ($report.status -ne 'pass') { exit 1 }
  exit 0
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message,$_.InvocationInfo.ScriptLineNumber,$_.InvocationInfo.Line)
  exit 3
}
