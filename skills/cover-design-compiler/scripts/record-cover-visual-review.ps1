param(
  [Parameter(Mandatory = $true)][string]$SessionRoot,
  [Parameter(Mandatory = $true)][string]$CompositionRecordPath,
  [Parameter(Mandatory = $true)][string]$ReviewRecordPath,
  [Parameter(Mandatory = $true)][ValidateSet('codex_visual_review','human_visual_review')][string]$ReviewerType,
  [Parameter(Mandatory = $true)][ValidateSet('real_delivery','fixture_only')][string]$ReviewScope,
  [Parameter(Mandatory = $true)][ValidateSet('pass','fail')][string]$VisualReviewStatus,
  [Parameter(Mandatory = $true)][string]$ReviewStatement,
  [string[]]$Findings = @()
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
. (Join-Path $projectRoot 'tools\WindowsRuntimeHelper.ps1')
. (Join-Path $projectRoot 'tools\R3VisualPresentation.ps1')

function Resolve-R3ReviewSessionPath {
  param([string]$Root, [string]$Path)
  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\','/')
  $full = if ([System.IO.Path]::IsPathRooted($Path)) { [System.IO.Path]::GetFullPath($Path) } else { [System.IO.Path]::GetFullPath((Join-Path $rootFull $Path)) }
  if ($full -ne $rootFull -and -not $full.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar,[System.StringComparison]::OrdinalIgnoreCase)) { throw 'cover_review_path_escapes_session' }
  return $full
}

$session = (Resolve-Path -LiteralPath $SessionRoot).Path
$compositionFull = Resolve-R3ReviewSessionPath $session $CompositionRecordPath
$reviewFull = Resolve-R3ReviewSessionPath $session $ReviewRecordPath
if (-not (Test-Path -LiteralPath $compositionFull -PathType Leaf)) { throw 'cover_composition_record_missing' }
$composition = Get-Content -LiteralPath $compositionFull -Raw -Encoding UTF8 | ConvertFrom-Json
$outputFull = Resolve-R3ReviewSessionPath $session ([string]$composition.output_path)
$previewFull = Resolve-R3ReviewSessionPath $session ([string]$composition.preview_path)
if (-not (Test-Path -LiteralPath $outputFull -PathType Leaf) -or -not (Test-Path -LiteralPath $previewFull -PathType Leaf)) { throw 'cover_review_raster_missing' }
$outputHash = 'sha256:' + (Get-TaogeFileSha256 $outputFull); $previewHash = 'sha256:' + (Get-TaogeFileSha256 $previewFull)
if ($outputHash -ne [string]$composition.output_sha256 -or $previewHash -ne [string]$composition.preview_sha256) { throw 'cover_review_raster_digest_mismatch' }
if ([string]::IsNullOrWhiteSpace($ReviewStatement)) { throw 'cover_review_statement_missing' }
if ($VisualReviewStatus -eq 'fail' -and @($Findings).Count -eq 0) { throw 'cover_review_fail_findings_missing' }

$review = [ordered]@{
  schema_id='taoge://schemas/r3/cover-visual-review/v0.1'; schema_version='0.1'
  cover_visual_review_id='CVR-' + [string]$composition.cover_rendition_id + '-R' + [string]$composition.rendition_revision
  cover_rendition_id=[string]$composition.cover_rendition_id; rendition_revision=[int]$composition.rendition_revision
  surface_profile_id=[string]$composition.surface_profile_id; reviewer_type=$ReviewerType; observation_mode='raster_inspection'; review_scope=$ReviewScope
  output_sha256=$outputHash; preview_sha256=$previewHash; visual_review_status=$VisualReviewStatus
  findings=[object[]]@($Findings); review_statement=$ReviewStatement; reviewed_at=[DateTimeOffset]::UtcNow.ToString('o')
}
$reviewErrors = @(Test-R3CoverVisualReviewRecord ([pscustomobject]$review) $composition)
if ($reviewErrors.Count) { throw ('cover_visual_review_invalid:' + [string]::Join(';',$reviewErrors)) }
if (Test-Path -LiteralPath $reviewFull -PathType Leaf) {
  $existing = Get-Content -LiteralPath $reviewFull -Raw -Encoding UTF8 | ConvertFrom-Json
  $semanticFields = @('schema_id','schema_version','cover_visual_review_id','cover_rendition_id','rendition_revision','surface_profile_id','reviewer_type','observation_mode','review_scope','output_sha256','preview_sha256','visual_review_status','review_statement')
  $same = $true
  foreach ($field in $semanticFields) { if ([string]$existing.$field -ne [string]$review[$field]) { $same = $false; break } }
  if ($same -and (@($existing.findings) -join "`n") -ne (@($review.findings) -join "`n")) { $same = $false }
  if ($same) { Write-Output 'COVER_VISUAL_REVIEW_STATUS=skipped_reused'; exit 0 }
  throw 'cover_visual_review_record_exists'
}
$parent = Split-Path -Parent $reviewFull; if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
Write-TaogeUtf8NoBomJson -Path $reviewFull -Value $review -Depth 20
Write-Output "COVER_VISUAL_REVIEW_STATUS=$VisualReviewStatus"
Write-Output "COVER_RENDITION_ID=$($composition.cover_rendition_id)"
Write-Output "REVIEW_RECORD=$reviewFull"
