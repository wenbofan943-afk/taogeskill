param(
  [ValidateSet('validate_bundle','derive_readiness','commit_pointer')][string]$Mode = 'validate_bundle',
  [string]$BundlePath,
  [string]$SessionRoot,
  [string]$RevisionPath,
  [string]$PointerPath,
  [string]$ObjectType,
  [string]$ArtifactId,
  [int]$Revision = 1,
  [string]$Status = 'ready',
  [string]$SourceDraftDigest
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'EnvironmentPreflight.ps1')
. (Join-Path $PSScriptRoot 'R6ScriptVisualContract.ps1')

try {
  if ($Mode -in @('validate_bundle','derive_readiness')) {
    if ([string]::IsNullOrWhiteSpace($BundlePath) -or -not (Test-Path -LiteralPath $BundlePath -PathType Leaf)) { throw 'bundle_path_missing' }
    $bundle = Get-Content -LiteralPath $BundlePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($Mode -eq 'derive_readiness') { Write-Output ('R6_SCRIPT_READINESS=' + (Get-R6SVReadiness $bundle.script_review $bundle.revision_decision)); exit 0 }
    $errors = @(Test-R6ScriptVisualBundle $bundle)
    if ($errors.Count) { $errors | ForEach-Object { Write-Output "R6_SCRIPT_VISUAL_ERROR=$_" }; exit 1 }
    Write-Output 'R6_SCRIPT_VISUAL_RESULT=pass'
    exit 0
  }

  if ([string]::IsNullOrWhiteSpace($SessionRoot)) { throw 'session_root_missing' }
  $root = [System.IO.Path]::GetFullPath($SessionRoot)
  $revisionCheck = Resolve-TaogeContainedPath -AllowedRoot $root -CandidatePath $RevisionPath -RejectReparsePoints
  $pointerCheck = Resolve-TaogeContainedPath -AllowedRoot $root -CandidatePath $PointerPath -RejectReparsePoints
  if ($revisionCheck.status -ne 'pass') { throw ('revision_path_preflight_failed:' + [string]::Join(',',@($revisionCheck.errors))) }
  if ($pointerCheck.status -ne 'pass') { throw ('pointer_path_preflight_failed:' + [string]::Join(',',@($pointerCheck.errors))) }
  if (-not (Test-Path -LiteralPath $revisionCheck.resolved_path -PathType Leaf)) { throw 'revision_file_missing' }
  if ($ObjectType -notin @('short_video_structure_plan','content_beat_map','script_design_review','content_revision_decision','visual_need_analysis','visual_coverage_ledger','script_visual_alignment_review')) { throw 'object_type_invalid' }
  if (-not (Test-R6SVDigest $SourceDraftDigest)) { throw 'source_draft_digest_invalid' }
  $relativeRevision = [System.IO.Path]::GetFullPath($revisionCheck.resolved_path).Substring($root.TrimEnd('\').Length + 1).Replace('\','/')
  if ($relativeRevision -notmatch '^intermediate/contracts/revisions/[^/]+/[^/]+[.]json$') { throw 'revision_path_contract_invalid' }
  $pointer = [ordered]@{schema_id='taoge://schemas/r6/content-analysis-current-pointer/v0.1';schema_version='0.1.0';object_type=$ObjectType;artifact_id=$ArtifactId;revision=$Revision;revision_path=$relativeRevision;sha256=('sha256:' + (Get-TaogeFileSha256 -Path $revisionCheck.resolved_path));status=$Status;source_draft_digest=$SourceDraftDigest;updated_at=[DateTimeOffset]::UtcNow.ToString('o')}
  Write-TaogeUtf8NoBomJson -Path $pointerCheck.resolved_path -Value $pointer -Depth 10
  Write-Output 'R6_POINTER_RESULT=committed'
  Write-Output ('R6_POINTER_SHA256=' + $pointer.sha256)
} catch {
  Write-Output ('R6_SCRIPT_VISUAL_ERROR=' + $_.Exception.Message)
  exit 1
}
