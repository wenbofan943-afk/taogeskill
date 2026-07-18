param(
  [string]$ProjectRoot = '',
  [string]$OutputPath = '',
  [Parameter(Mandatory=$true)][string]$SourceRevision,
  [Parameter(Mandatory=$true)][string]$GeneratedAt,
  [Parameter(Mandatory=$true)][string]$FreezeId
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
} else {
  $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}
$requestedOutputPath = $OutputPath
. (Join-Path $PSScriptRoot 'M6CertificationRuntime.ps1')
if ([string]::IsNullOrWhiteSpace($requestedOutputPath)) {
  $requestedOutputPath = Join-Path $ProjectRoot "state/checks/m6/$FreezeId/certification-freeze.json"
}
Initialize-M6CertificationRuntime -ProjectRoot $ProjectRoot
$manifest = New-M6CertificationFreeze `
  -SourceRevision $SourceRevision `
  -GeneratedAt $GeneratedAt `
  -FreezeId $FreezeId
$verification = Test-M6CertificationFreeze `
  -Manifest $manifest `
  -ExpectedSourceRevision $SourceRevision
if ($verification.result -ne 'pass') {
  throw "m6_freeze_verification_failed:$([string]::Join(',',@($verification.errors)))"
}
$written = Write-M6CertificationFreeze -Path $requestedOutputPath -Manifest $manifest
Write-Output 'result=freeze_written'
Write-Output "aggregate_sha256=$($manifest.aggregate_sha256)"
Write-Output "category_count=$(@($manifest.categories).Count)"
Write-Output "output=$written"
