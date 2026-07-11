param(
  [Parameter(Mandatory=$true)][string]$BaselineSession,
  [Parameter(Mandatory=$true)][string]$TargetSession
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'P0EvidenceRuntime.ps1')
. (Join-Path $PSScriptRoot 'P0RuntimeV02.ps1')

function Resolve-H5Path {
  param([string]$Path, [bool]$MustExist)
  $candidate = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $projectRoot $Path }
  $full = [System.IO.Path]::GetFullPath($candidate)
  if ($MustExist -and -not (Test-Path -LiteralPath $full)) { throw "path_missing:$full" }
  return $full
}

function Write-H5Text {
  param([string]$Path, [string]$Text)
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  [System.IO.File]::WriteAllText($Path, $Text.TrimEnd("`r", "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
}

function Write-H5Json {
  param([string]$Path, [object]$Value)
  Write-H5Text $Path (($Value | ConvertTo-Json -Depth 50).TrimEnd("`r", "`n"))
}

function Get-H5Hash {
  param([string]$Path)
  return 'sha256:' + (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-H5YamlScalar {
  param([string]$Text, [string]$Name)
  $match = [regex]::Match($Text, "(?m)^\s*$([regex]::Escape($Name)):\s*(.+?)\s*$")
  if (-not $match.Success) { throw "yaml_scalar_missing:$Name" }
  return $match.Groups[1].Value.Trim().Trim("'", '"')
}

function Get-H5Section {
  param([string]$Text, [string]$Heading)
  $match = [regex]::Match($Text, "(?ms)^##\s+$([regex]::Escape($Heading))\s*\r?\n(.*?)(?=^##\s+|\z)")
  if (-not $match.Success) { throw "markdown_section_missing:$Heading" }
  return $match.Groups[1].Value.Trim()
}

function Convert-H5Identity {
  param([string]$Text, [string]$BaselineId, [string]$TargetId)
  $baselineToken = $BaselineId.Substring(1)
  $targetToken = $TargetId.Substring(1)
  return $Text.Replace($BaselineId, $TargetId).Replace($baselineToken, $targetToken)
}

function Get-H5PlatformRow {
  param([string]$Text, [string]$Prefix)
  $line = @($Text -split "`r?`n" | Where-Object { $_ -like "| $Prefix*" }) | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($line)) { throw "platform_row_missing:$Prefix" }
  $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
  if ($cells.Count -lt 5) { throw "platform_row_invalid:$Prefix" }
  return $cells
}

function New-H5PlatformCard {
  param([string]$Id, [int]$Order, [string]$Platform, [object[]]$Cells, [string]$PackageId)
  return [ordered]@{
    card_id=$Id; card_type='platform'; display_order=$Order; status='ready'; source_artifact_ids=@($PackageId)
    platform=$Platform; cover_title=[string]$Cells[1]; video_title=[string]$Cells[2]; publish_description=[string]$Cells[3]
    hashtags=[object[]]@(([string]$Cells[4] -split '\s+' | Where-Object { $_ })); publish_readiness='ready'
  }
}

try {
  $baselineRoot = Resolve-H5Path $BaselineSession $true
  $targetRoot = Resolve-H5Path $TargetSession $false
  $accountsRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot 'accounts')).TrimEnd('\')
  if (-not $baselineRoot.StartsWith($accountsRoot + '\', [System.StringComparison]::OrdinalIgnoreCase) -or -not $targetRoot.StartsWith($accountsRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) { throw 'h5_sessions_must_be_under_project_accounts' }
  if ((Split-Path -Parent $baselineRoot) -ne (Split-Path -Parent $targetRoot)) { throw 'target_must_share_baseline_account_runs_directory' }
  $baselineId = Split-Path -Leaf $baselineRoot
  $targetId = Split-Path -Leaf $targetRoot
  if ($baselineId -notmatch '^S\d{8}-\d{3}$' -or $targetId -notmatch '^S\d{8}-\d{3}$') { throw 'session_id_format_invalid' }
  if ($baselineRoot -eq $targetRoot) { throw 'target_must_differ_from_baseline' }
  if (Test-Path -LiteralPath $targetRoot) { throw "target_session_already_exists:$targetRoot" }

  $baselineManifestPath = Join-Path $baselineRoot 'manifest.yaml'
  $baselineManifest = Get-Content -LiteralPath $baselineManifestPath -Raw -Encoding UTF8
  if ((Get-H5YamlScalar $baselineManifest 'session_id') -ne $baselineId) { throw 'baseline_manifest_session_mismatch' }
  if ((Get-H5YamlScalar $baselineManifest 'overall_result') -ne 'pass_with_warnings') { throw 'baseline_not_verified_regression' }
  $accountName = Get-H5YamlScalar $baselineManifest 'account'

  $qualityText = Get-Content -LiteralPath (Join-Path $baselineRoot 'intermediate/06-quality-review.md') -Raw -Encoding UTF8
  $coverQualityText = Get-Content -LiteralPath (Join-Path $baselineRoot 'intermediate/09-cover-quality-review.md') -Raw -Encoding UTF8
  $embedText = Get-Content -LiteralPath (Join-Path $baselineRoot 'deliverables/html-embed-manifest.md') -Raw -Encoding UTF8
  if ($qualityText -notmatch '(?m)^review_status:\s*review_pass\s*$' -or $coverQualityText -notmatch '(?m)^cover_quality_gate_status:\s*pass\s*$') { throw 'baseline_quality_gate_not_passed' }

  New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
  foreach ($directory in @('inputs','intermediate','intermediate/p0/commands','assets/images','assets/images/covers','assets/images/metadata','inputs/baseline-sidecars','deliverables','deliverables/p0')) {
    New-Item -ItemType Directory -Path (Join-Path $targetRoot $directory) -Force | Out-Null
  }

  $textArtifacts = @(
    @{ path='intermediate/01-research-run-record.md'; id=('R' + $targetId.Substring(1)); type='research_run_record' },
    @{ path='intermediate/02-topic-card.md'; id=('T' + $targetId.Substring(1)); type='topic_card' },
    @{ path='intermediate/03-content-brief.md'; id=('B' + $targetId.Substring(1)); type='content_brief' },
    @{ path='intermediate/04-draft.md'; id=('D' + $targetId.Substring(1)); type='draft' },
    @{ path='intermediate/05-visual-plan.md'; id=('V' + $targetId.Substring(1)); type='visual_plan' },
    @{ path='intermediate/06-quality-review.md'; id=('Q' + $targetId.Substring(1)); type='quality_review' },
    @{ path='intermediate/07-platform-package-input.md'; id=('PI' + $targetId.Substring(1)); type='platform_package_input' },
    @{ path='intermediate/08-platform-package-draft.md'; id=('PK' + $targetId.Substring(1)); type='platform_package' },
    @{ path='intermediate/08-cover-design-package.md'; id=('CDP' + $targetId.Substring(1)); type='cover_design_package' },
    @{ path='intermediate/09-cover-compositions.md'; id=('CC' + $targetId.Substring(1)); type='cover_composition' },
    @{ path='intermediate/09-cover-quality-review.md'; id=('CQG' + $targetId.Substring(1)); type='cover_quality_review' },
    @{ path='deliverables/content-delivery-record.md'; id=('DEL' + $targetId.Substring(1)); type='content_delivery_record' },
    @{ path='deliverables/final-script.md'; id=('D' + $targetId.Substring(1)); type='final_script' },
    @{ path='deliverables/final-visual-plan.md'; id=('V' + $targetId.Substring(1)); type='final_visual_plan' },
    @{ path='deliverables/final-platform-package.md'; id=('PK' + $targetId.Substring(1)); type='final_platform_package' }
  )
  foreach ($artifact in $textArtifacts) {
    $source = Join-Path $baselineRoot $artifact.path
    if (-not (Test-Path -LiteralPath $source)) { throw "baseline_artifact_missing:$($artifact.path)" }
    $converted = Convert-H5Identity (Get-Content -LiteralPath $source -Raw -Encoding UTF8) $baselineId $targetId
    Write-H5Text (Join-Path $targetRoot $artifact.path) $converted
  }

  $draftPath = Join-Path $targetRoot 'intermediate/04-draft.md'
  $baselineDraftText = Get-Content -LiteralPath (Join-Path $baselineRoot 'intermediate/04-draft.md') -Raw -Encoding UTF8
  $targetDraftText = Get-Content -LiteralPath $draftPath -Raw -Encoding UTF8
  $baselineScript = Get-H5Section $baselineDraftText '正式口播文案'
  $targetScript = Get-H5Section $targetDraftText '正式口播文案'
  $baselineScriptDigest = Get-P0EvidenceTextDigest $baselineScript
  $targetScriptDigest = Get-P0EvidenceTextDigest $targetScript
  if ($baselineScriptDigest -ne $targetScriptDigest) { throw 'baseline_content_semantic_digest_mismatch' }

  $assetDefinitions = @(
    @{ source=('COVER-' + $baselineId + '-001'); target=('COVER-' + $targetId + '-001'); folder='assets/images'; role='cover_background'; quality='pass'; eligibility='trace_only'; parent=$null; delivery=$true },
    @{ source=('PIP-' + $baselineId + '-001'); target=('PIP-' + $targetId + '-001'); folder='assets/images'; role='hook_conflict'; quality='pass'; eligibility='ready_for_delivery'; parent=$null; delivery=$true },
    @{ source=('PIP-' + $baselineId + '-002'); target=('PIP-' + $targetId + '-002'); folder='assets/images'; role='comparison_base'; quality='pass_with_warnings'; eligibility='trace_only'; parent=$null; delivery=$false },
    @{ source=('PIP-' + $baselineId + '-003'); target=('PIP-' + $targetId + '-003'); folder='assets/images'; role='metaphor_base'; quality='pass_with_warnings'; eligibility='trace_only'; parent=$null; delivery=$false },
    @{ source=('PIP-' + $baselineId + '-102'); target=('PIP-' + $targetId + '-102'); folder='assets/images'; role='comparison'; quality='pass'; eligibility='ready_for_delivery'; parent=('PIP-' + $targetId + '-002'); delivery=$true },
    @{ source=('PIP-' + $baselineId + '-103'); target=('PIP-' + $targetId + '-103'); folder='assets/images'; role='metaphor'; quality='pass'; eligibility='ready_for_delivery'; parent=('PIP-' + $targetId + '-003'); delivery=$true },
    @{ source=('COVER-' + $baselineId + '-301'); target=('COVER-' + $targetId + '-301'); folder='assets/images/covers'; role='douyin_kuaishou_cover'; quality='pass'; eligibility='ready_for_upload'; parent=('COVER-' + $targetId + '-001'); delivery=$true },
    @{ source=('COVER-' + $baselineId + '-102'); target=('COVER-' + $targetId + '-102'); folder='assets/images/covers'; role='xiaohongshu_cover'; quality='pass'; eligibility='ready_for_upload'; parent=('COVER-' + $targetId + '-001'); delivery=$true },
    @{ source=('COVER-' + $baselineId + '-203'); target=('COVER-' + $targetId + '-203'); folder='assets/images/covers'; role='shipinhao_cover'; quality='pass'; eligibility='ready_for_upload'; parent=('COVER-' + $targetId + '-001'); delivery=$true }
  )
  $reuseAssets = [System.Collections.Generic.List[object]]::new()
  foreach ($asset in $assetDefinitions) {
    $sourcePath = Join-Path $baselineRoot ($asset.folder + '/' + $asset.source + '.png')
    $sourceSidecar = Join-Path $baselineRoot ('assets/images/metadata/' + $asset.source + '.md')
    if (-not (Test-Path -LiteralPath $sourcePath) -or -not (Test-Path -LiteralPath $sourceSidecar)) { throw "baseline_asset_or_sidecar_missing:$($asset.source)" }
    $sourceHash = Get-H5Hash $sourcePath
    $sourceMetadata = Get-Content -LiteralPath $sourceSidecar -Raw -Encoding UTF8
    $sourceSidecarHash = Get-H5Hash $sourceSidecar
    if ($sourceMetadata -notmatch [regex]::Escape($sourceHash.Substring(7).ToUpperInvariant())) { throw "baseline_sidecar_digest_mismatch:$($asset.source)" }
    if ([bool]$asset.delivery -and $asset.role -ne 'cover_background' -and $embedText -notmatch [regex]::Escape([string]$asset.source)) { throw "baseline_embed_gate_missing:$($asset.source)" }
    if ($asset.role -like '*_cover' -and $coverQualityText -notmatch "(?m)^\|\s*$([regex]::Escape([string]$asset.source))\s*\|.*\|\s*adopted\s*\|\s*$") { throw "baseline_cover_not_adopted:$($asset.source)" }
    if ($asset.role -in @('hook_conflict','comparison','metaphor') -and $qualityText -notmatch "(?m)^\|.*\|\s*$([regex]::Escape([string]$asset.source))\s*\|.*\|\s*pass\s*\|\s*none\s*\|\s*$") { throw "baseline_pip_not_verified:$($asset.source)" }

    $targetRelative = ($asset.folder + '/' + $asset.target + '.png')
    $targetPath = Join-Path $targetRoot $targetRelative
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath
    if ((Get-H5Hash $targetPath) -ne $sourceHash) { throw "copied_asset_digest_mismatch:$($asset.target)" }
    Copy-Item -LiteralPath $sourceSidecar -Destination (Join-Path $targetRoot ('inputs/baseline-sidecars/' + $asset.source + '.md'))
    $binding = switch ([string]$asset.role) {
      'cover_background' { @{ source=('GEN-' + $baselineId + '-001'); target=('GEN-' + $targetId + '-001'); beat='cover_background' } }
      'hook_conflict' { @{ source=('PROMPT-' + $baselineId + '-001'); target=('PROMPT-' + $targetId + '-001'); beat='hook_after_brand_myth' } }
      'comparison_base' { @{ source=('PROMPT-' + $baselineId + '-002'); target=('PROMPT-' + $targetId + '-002'); beat='scale_diseconomy' } }
      'comparison' { @{ source=('PROMPT-' + $baselineId + '-002'); target=('PROMPT-' + $targetId + '-002'); beat='scale_diseconomy' } }
      'metaphor_base' { @{ source=('PROMPT-' + $baselineId + '-003'); target=('PROMPT-' + $targetId + '-003'); beat='liquidity_eliminates_loyalty' } }
      'metaphor' { @{ source=('PROMPT-' + $baselineId + '-003'); target=('PROMPT-' + $targetId + '-003'); beat='liquidity_eliminates_loyalty' } }
      'douyin_kuaishou_cover' { @{ source=('CC' + $baselineId.Substring(1) + '-A3'); target=('CC' + $targetId.Substring(1) + '-A3'); beat='platform_cover_douyin_kuaishou' } }
      'xiaohongshu_cover' { @{ source=('CC' + $baselineId.Substring(1) + '-B1'); target=('CC' + $targetId.Substring(1) + '-B1'); beat='platform_cover_xiaohongshu' } }
      'shipinhao_cover' { @{ source=('CC' + $baselineId.Substring(1) + '-C2'); target=('CC' + $targetId.Substring(1) + '-C2'); beat='platform_cover_shipinhao' } }
      default { throw "asset_binding_unknown:$($asset.role)" }
    }
    $sidecarRelative = 'assets/images/metadata/' + $asset.target + '.json'
    $sidecar = [ordered]@{
      schema_id='taoge://schemas/p0/reused-asset-sidecar/v0.1'; schema_version='0.1'; asset_id=$asset.target
      asset_status='reused_verified'; source_asset_id=$asset.source; source_session_id=$baselineId; source_sha256=$sourceHash
      sha256=$sourceHash; source_sidecar_path=('inputs/baseline-sidecars/' + $asset.source + '.md'); source_sidecar_sha256=$sourceSidecarHash
      content_semantic_sha256=$targetScriptDigest; baseline_content_semantic_sha256=$baselineScriptDigest
      visual_role=$asset.role; expected_usage=$asset.role; source_binding_id=$binding.source; target_binding_id=$binding.target; beat_binding=$binding.beat
      parent_asset_id=$asset.parent; materialization_status='materialized'
      quality_status=$asset.quality; delivery_eligibility=$asset.eligibility; external_provider_invoked=$false
    }
    Write-H5Json (Join-Path $targetRoot $sidecarRelative) $sidecar
    $reuseAssets.Add([ordered]@{ source_asset_id=$asset.source; asset_id=$asset.target; source_session_id=$baselineId; relative_path=$targetRelative; sidecar_path=$sidecarRelative; sha256=$sourceHash; visual_role=$asset.role; source_binding_id=$binding.source; target_binding_id=$binding.target; beat_binding=$binding.beat; quality_status=$asset.quality; delivery_eligibility=$asset.eligibility; included_in_delivery=[bool]$asset.delivery; parent_asset_id=$asset.parent })
  }

  $reuseManifest = [ordered]@{
    schema_id='taoge://schemas/p0/verified-asset-reuse-manifest/v0.1'; schema_version='0.1'; reuse_manifest_id=('REUSE-' + $targetId)
    baseline_session_id=$baselineId; session_id=$targetId; content_semantic_sha256=$targetScriptDigest
    provider_invocation_count=0; assets=[object[]]$reuseAssets.ToArray()
  }
  Write-H5Json (Join-Path $targetRoot 'assets/images/reuse-manifest.json') $reuseManifest

  $assetTable = @('# Reused Verified Image Assets', '', "- baseline_session_id: $baselineId", "- session_id: $targetId", '- provider_invocation_count: 0', '', '| asset_id | source_asset_id | role | sha256 | eligibility |', '|---|---|---|---|---|')
  foreach ($asset in $reuseAssets) { $assetTable += "| $($asset.asset_id) | $($asset.source_asset_id) | $($asset.visual_role) | $($asset.sha256) | $($asset.delivery_eligibility) |" }
  Write-H5Text (Join-Path $targetRoot 'assets/images/image-assets.md') ([string]::Join("`n", $assetTable))

  $targetToken = $targetId.Substring(1)
  $topicText = Get-Content -LiteralPath (Join-Path $targetRoot 'intermediate/02-topic-card.md') -Raw -Encoding UTF8
  $briefText = Get-Content -LiteralPath (Join-Path $targetRoot 'intermediate/03-content-brief.md') -Raw -Encoding UTF8
  $platformText = Get-Content -LiteralPath (Join-Path $targetRoot 'intermediate/08-platform-package-draft.md') -Raw -Encoding UTF8
  $topicTitle = Get-H5YamlScalar $topicText 'topic_title'
  $whyNow = (Get-H5Section $briefText '核心观点') -replace '\s+', ' '
  $hookText = @($targetScript -split "\r?\n\r?\n" | Where-Object { $_.Trim() })[0].Trim()
  $packageId = 'PK' + $targetToken
  $draftId = 'D' + $targetToken
  $topicId = 'T' + $targetToken
  $briefId = 'B' + $targetToken
  $reviewId = 'Q' + $targetToken
  $deliveryId = 'DEL' + $targetToken
  $visualPlanId = 'V' + $targetToken
  $coverPackageId = 'CDP' + $targetToken
  $coverGateId = 'CQG' + $targetToken
  $researchId = 'R' + $targetToken
  $renderInputId = 'RIN-' + $targetId
  $finalDeliveryId = 'FD' + $targetToken
  $candidateId = 'RCAND-' + $targetId

  $douyinRow = Get-H5PlatformRow $platformText '抖音 / 快手'
  $xiaohongshuRow = Get-H5PlatformRow $platformText '小红书'
  $shipinhaoRow = Get-H5PlatformRow $platformText '视频号'
  $assetById = @{}; foreach ($asset in $reuseAssets) { $assetById[[string]$asset.asset_id] = $asset }
  function New-AssetCardData([string]$AssetId) { return $assetById[$AssetId] }

  $coverCards = @(
    [ordered]@{ card_id=('CARD-COVER-' + $targetToken + '-001'); card_type='cover'; display_order=1; status='trace_only'; source_artifact_ids=@($coverPackageId); cover_role='background'; platform='all'; title_text=''; asset_status='reused_verified'; asset_id=('COVER-' + $targetId + '-001'); relative_path=(New-AssetCardData ('COVER-' + $targetId + '-001')).relative_path; sha256=(New-AssetCardData ('COVER-' + $targetId + '-001')).sha256; sidecar_path=(New-AssetCardData ('COVER-' + $targetId + '-001')).sidecar_path; usage_note='复用已验证封面底图，仅作三张平台封面的来源追溯。' },
    [ordered]@{ card_id=('CARD-COVER-' + $targetToken + '-301'); card_type='cover'; display_order=2; status='ready'; source_artifact_ids=@($coverPackageId,$coverGateId); cover_role='platform_cover'; platform='douyin,kuaishou'; title_text=[string]$douyinRow[1]; asset_status='reused_verified'; asset_id=('COVER-' + $targetId + '-301'); relative_path=(New-AssetCardData ('COVER-' + $targetId + '-301')).relative_path; sha256=(New-AssetCardData ('COVER-' + $targetId + '-301')).sha256; sidecar_path=(New-AssetCardData ('COVER-' + $targetId + '-301')).sidecar_path; usage_note='抖音与快手采用版，已通过基线封面质检。' },
    [ordered]@{ card_id=('CARD-COVER-' + $targetToken + '-102'); card_type='cover'; display_order=3; status='ready'; source_artifact_ids=@($coverPackageId,$coverGateId); cover_role='platform_cover'; platform='xiaohongshu'; title_text=[string]$xiaohongshuRow[1]; asset_status='reused_verified'; asset_id=('COVER-' + $targetId + '-102'); relative_path=(New-AssetCardData ('COVER-' + $targetId + '-102')).relative_path; sha256=(New-AssetCardData ('COVER-' + $targetId + '-102')).sha256; sidecar_path=(New-AssetCardData ('COVER-' + $targetId + '-102')).sidecar_path; usage_note='小红书采用版，已通过基线封面质检。' },
    [ordered]@{ card_id=('CARD-COVER-' + $targetToken + '-203'); card_type='cover'; display_order=4; status='ready'; source_artifact_ids=@($coverPackageId,$coverGateId); cover_role='platform_cover'; platform='shipinhao'; title_text=[string]$shipinhaoRow[1]; asset_status='reused_verified'; asset_id=('COVER-' + $targetId + '-203'); relative_path=(New-AssetCardData ('COVER-' + $targetId + '-203')).relative_path; sha256=(New-AssetCardData ('COVER-' + $targetId + '-203')).sha256; sidecar_path=(New-AssetCardData ('COVER-' + $targetId + '-203')).sidecar_path; usage_note='视频号采用版，已通过基线封面质检。' }
  )
  $pipCards = @(
    [ordered]@{ card_id=('CARD-PIP-' + $targetToken + '-001'); card_type='picture_in_picture'; display_order=1; status='ready'; source_artifact_ids=@($visualPlanId,$reviewId); placement='Hook 后'; narrative_function='用车商与消费者双向压力承接品牌幻觉 Hook'; asset_status='reused_verified'; asset_id=('PIP-' + $targetId + '-001'); relative_path=(New-AssetCardData ('PIP-' + $targetId + '-001')).relative_path; sha256=(New-AssetCardData ('PIP-' + $targetId + '-001')).sha256; sidecar_path=(New-AssetCardData ('PIP-' + $targetId + '-001')).sidecar_path; preview_alt='车商与消费者双向压力画面' },
    [ordered]@{ card_id=('CARD-PIP-' + $targetToken + '-102'); card_type='picture_in_picture'; display_order=2; status='ready'; source_artifact_ids=@($visualPlanId,$reviewId); placement='“规模不经济”之后'; narrative_function='把规模越大、容错越低变成可视比较'; asset_status='reused_verified'; asset_id=('PIP-' + $targetId + '-102'); relative_path=(New-AssetCardData ('PIP-' + $targetId + '-102')).relative_path; sha256=(New-AssetCardData ('PIP-' + $targetId + '-102')).sha256; sidecar_path=(New-AssetCardData ('PIP-' + $targetId + '-102')).sidecar_path; preview_alt='规模与容错对比画面' },
    [ordered]@{ card_id=('CARD-PIP-' + $targetToken + '-103'); card_type='picture_in_picture'; display_order=3; status='ready'; source_artifact_ids=@($visualPlanId,$reviewId); placement='“绝对的流动性”之后'; narrative_function='用角色内心强化高流动性和低忠诚'; asset_status='reused_verified'; asset_id=('PIP-' + $targetId + '-103'); relative_path=(New-AssetCardData ('PIP-' + $targetId + '-103')).relative_path; sha256=(New-AssetCardData ('PIP-' + $targetId + '-103')).sha256; sidecar_path=(New-AssetCardData ('PIP-' + $targetId + '-103')).sidecar_path; preview_alt='流动性与忠诚隐喻画面' }
  )
  $traceDefinitions = @(
    @('topic_card',$topicId,'选题卡','intermediate/02-topic-card.md'),
    @('content_brief',$briefId,'内容 Brief','intermediate/03-content-brief.md'),
    @('draft',$draftId,'口播草案','intermediate/04-draft.md'),
    @('visual_plan',$visualPlanId,'视觉计划','intermediate/05-visual-plan.md'),
    @('quality_review',$reviewId,'联合质检','intermediate/06-quality-review.md'),
    @('platform_package',$packageId,'平台包装','intermediate/08-platform-package-draft.md'),
    @('cover_design_package',$coverPackageId,'封面设计包','intermediate/08-cover-design-package.md'),
    @('cover_quality_review',$coverGateId,'封面质检','intermediate/09-cover-quality-review.md'),
    @('content_delivery_record',$deliveryId,'内容交付记录','deliverables/content-delivery-record.md')
  )
  $traceCards = [System.Collections.Generic.List[object]]::new(); $traceOrder = 0
  foreach ($trace in $traceDefinitions) {
    $traceOrder++; $traceCards.Add([ordered]@{ card_id=('CARD-TRACE-' + $targetToken + '-' + $traceOrder.ToString('000')); card_type='trace'; display_order=$traceOrder; status='trace_only'; source_artifact_ids=@([string]$trace[1]); artifact_type=[string]$trace[0]; artifact_id=[string]$trace[1]; label=[string]$trace[2]; relative_path=[string]$trace[3]; materialization_status='materialized'; sha256=(Get-H5Hash (Join-Path $targetRoot ([string]$trace[3]))) })
  }
  $warnings = @('content_reused_from_baseline','verified_images_reused','external_image_generation_not_tested','publishing_not_tested')
  $candidate = [ordered]@{
    schema_id='taoge://schemas/final-delivery/typed-components/v0.2'; schema_version='typed_components_v0.2'; render_input_id=$renderInputId
    final_delivery_id=$finalDeliveryId; account_name=$accountName; session_id=$targetId; research_run_id=$researchId
    template_version='final-delivery-template-v0.2'; generated_at=[DateTimeOffset]::UtcNow.ToString('o')
    topic=[ordered]@{ title=$topicTitle; why_now=$whyNow; content_format='short_video_talking_head' }
    script_card=[ordered]@{ card_id=('CARD-SCRIPT-' + $targetToken); card_type='script'; status='ready'; source_artifact_ids=@($draftId); hook_text=$hookText; final_text=$targetScript; copy_label='复制完整口播'; source_draft_id=$draftId; estimated_duration_seconds=95 }
    production_status=[ordered]@{ image_assets_status='reused_verified'; cover_quality_status='pass'; overall_quality_status='pass_with_warnings'; delivery_readiness='blocked'; derived_by='derive_delivery_readiness'; warning_codes=$warnings }
    cover_cards=$coverCards; pip_cards=$pipCards
    platform_cards=@(
      (New-H5PlatformCard ('CARD-PLATFORM-' + $targetToken + '-001') 1 'douyin' $douyinRow $packageId),
      (New-H5PlatformCard ('CARD-PLATFORM-' + $targetToken + '-002') 2 'kuaishou' $douyinRow $packageId),
      (New-H5PlatformCard ('CARD-PLATFORM-' + $targetToken + '-003') 3 'xiaohongshu' $xiaohongshuRow $packageId),
      (New-H5PlatformCard ('CARD-PLATFORM-' + $targetToken + '-004') 4 'shipinhao' $shipinhaoRow $packageId)
    )
    trace_cards=[object[]]$traceCards.ToArray()
    action_cards=@(
      [ordered]@{ card_id=('CARD-ACTION-' + $targetToken + '-001'); card_type='action'; display_order=1; status='ready'; source_artifact_ids=@($deliveryId); action='publish_manually'; label='人工发布'; instruction='复制物料后由用户自行发布；H5 不登录平台。'; reply_example='记录发布结果'; is_primary=$true },
      [ordered]@{ card_id=('CARD-ACTION-' + $targetToken + '-002'); card_type='action'; display_order=2; status='ready'; source_artifact_ids=@($draftId); action='revise_copy'; label='局部返工文案'; instruction='指出需要调整的句子和目标。'; reply_example='修改第二段，语气更克制'; target_artifact_id=$draftId; is_primary=$false },
      [ordered]@{ card_id=('CARD-ACTION-' + $targetToken + '-003'); card_type='action'; display_order=3; status='ready'; source_artifact_ids=@($visualPlanId); action='revise_visual'; label='局部返工视觉'; instruction='指定要替换的画中画或封面。'; reply_example='重做第二张画中画'; target_artifact_id=$visualPlanId; is_primary=$false },
      [ordered]@{ card_id=('CARD-ACTION-' + $targetToken + '-004'); card_type='action'; display_order=4; status='ready'; source_artifact_ids=@($deliveryId); action='export_handoff'; label='导出转交包'; instruction='生成可发给他人的本地交付包。'; reply_example='导出转交包'; is_primary=$false }
    )
    source_artifact_ids=@($researchId,$topicId,$briefId,$draftId,$visualPlanId,$reviewId,$packageId,$coverPackageId,$coverGateId,$deliveryId,('IMGSET' + $targetToken))
  }
  $candidateErrors = @(Test-P0RenderInputContract ([pscustomobject](($candidate | ConvertTo-Json -Depth 50) | ConvertFrom-Json)))
  if ($candidateErrors.Count) { throw ('render_candidate_contract_failed:' + [string]::Join(';', $candidateErrors)) }
  $candidateRelative = 'deliverables/p0/final-delivery-render-candidate.json'
  Write-H5Json (Join-Path $targetRoot $candidateRelative) $candidate

  $provenance = [ordered]@{
    schema_id='taoge://schemas/p0/h5-regression-provenance/v0.1'; schema_version='0.1'; session_id=$targetId; baseline_session_id=$baselineId
    baseline_manifest_sha256=Get-H5Hash $baselineManifestPath; baseline_content_semantic_sha256=$baselineScriptDigest; target_content_semantic_sha256=$targetScriptDigest
    content_rewritten=$false; provider_invocation_count=0; publishing_invocation_count=0; copied_asset_count=$reuseAssets.Count
    cardinality_mode='baseline_fixed_regression'; planned_pip_count=$pipCards.Count
    planned_platform_cover_count=@($coverCards | Where-Object { $_.cover_role -eq 'platform_cover' }).Count
    cover_background_count=@($coverCards | Where-Object { $_.cover_role -eq 'background' }).Count
    phase_2_expected_provider_call_count=($pipCards.Count + @($coverCards | Where-Object { $_.cover_role -eq 'background' }).Count)
    delivery_asset_count=@($reuseAssets | Where-Object { $_.included_in_delivery }).Count; warning_codes=$warnings
  }
  Write-H5Json (Join-Path $targetRoot 'inputs/h5-regression-provenance.json') $provenance

  $createCommand = [ordered]@{
    schema_id='taoge://commands/p0/evidence-command/v0.2'; schema_version='0.2'; command='create_session_plan'; plan_id=('PLAN-' + $targetId); session_id=$targetId
    confirmed_single_content=$true
    steps=@(
      [ordered]@{ step_id='STEP-prepare-verified-reuse'; step_kind='deterministic_tool'; operation='prepare_verified_reuse_candidate'; produces_artifact_type='typed_render_candidate'; failure_route='final-delivery-builder' },
      [ordered]@{ step_id='STEP-compile-render-input'; step_kind='deterministic_tool'; operation='compile_render_input'; requires_step_ids=@('STEP-prepare-verified-reuse'); requires_artifact_ids=@($candidateId); produces_artifact_type='deterministic_final_delivery_render_input'; failure_route='final-delivery-builder' },
      [ordered]@{ step_id='STEP-render-final-delivery'; step_kind='deterministic_tool'; operation='render_final_delivery'; requires_step_ids=@('STEP-compile-render-input'); requires_artifact_ids=@($renderInputId); produces_artifact_type='final_delivery'; failure_route='final-delivery-builder' }
    )
    idempotency_key=($targetId + ':create-session-plan:v1'); expected_last_sequence_no=0; safe_summary='H5 单篇真实回归执行计划已创建；仅复用已验证本地图片'
  }
  $commandPath = Join-Path $targetRoot 'intermediate/p0/commands/create-session-plan.json'
  Write-H5Json $commandPath $createCommand
  $engine = Join-Path $PSHOME 'powershell.exe'
  $commandOutput = @(& $engine -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'invoke-p0-evidence.ps1') -Session $targetRoot -Mode create_session_plan -CommandInputPath $commandPath 2>&1)
  if ($LASTEXITCODE -ne 0) { throw ('create_session_plan_failed:' + [string]::Join(';', @($commandOutput))) }

  $planPath = Join-Path $targetRoot 'intermediate/p0/session-execution-plan.json'
  $eventPath = Join-Path $targetRoot 'intermediate/p0/execution-events.jsonl'
  $plan = Read-P0JsonFile $planPath
  $stageInputDigest = Get-H5Hash (Join-Path $targetRoot 'inputs/h5-regression-provenance.json')
  $stagePayloadDigest = Get-H5Hash (Join-Path $targetRoot $candidateRelative)
  $stageOutputs = @($candidateId, ('REUSE-' + $targetId), ('IMGSET' + $targetToken)) + @($reuseAssets | ForEach-Object { [string]$_.asset_id }) + @($traceDefinitions | ForEach-Object { [string]$_[1] })
  $stageWrite = Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId 'STEP-prepare-verified-reuse' -EventType 'step.succeeded.v1' -EventSource 'runner' -StateBefore 'running' -StateAfter 'succeeded' -PayloadDigest $stagePayloadDigest -IdempotencyKey ($targetId + ':prepare-verified-reuse:' + $stageInputDigest) -ExpectedLastSequenceNo 1 -ResultCode 'verified_reuse_candidate_prepared' -SafeSummary '基线内容和已验证图片已复制到新 session；未调用图片 provider' -OutputArtifactIds $stageOutputs -InputDigest $stageInputDigest -ExecutionAttemptId ('ATT-' + $targetId + '-reuse-1')
  if ($stageWrite.ExitCode -ne 0) { throw "stage_event_failed:$($stageWrite.ResultCode)" }
  $producerEventId = [string]$stageWrite.Event.event_id
  [void](Write-P0EvidenceLineage $targetRoot $candidateId 'typed_render_candidate' $producerEventId @($candidate.source_artifact_ids) $candidateRelative (Get-H5Hash (Join-Path $targetRoot $candidateRelative)) 'pass_with_warnings' 'ready_for_delivery' @('CHECK-P0-H5-BASELINE','CHECK-P0-H5-REUSE'))
  foreach ($asset in $reuseAssets) {
    $inputs = if ($null -ne $asset.parent_asset_id -and -not [string]::IsNullOrWhiteSpace([string]$asset.parent_asset_id)) { @([string]$asset.parent_asset_id) } else { @([string]$asset.source_asset_id) }
    [void](Write-P0EvidenceLineage $targetRoot ([string]$asset.asset_id) 'image_asset' $producerEventId $inputs ([string]$asset.relative_path) ([string]$asset.sha256) ([string]$asset.quality_status) ([string]$asset.delivery_eligibility) @('CHECK-P0-H5-DIGEST','CHECK-P0-H5-SIDECAR','CHECK-P0-H5-BASELINE-QUALITY'))
  }
  foreach ($trace in $traceDefinitions) {
    $path = [string]$trace[3]
    [void](Write-P0EvidenceLineage $targetRoot ([string]$trace[1]) ([string]$trace[0]) $producerEventId @('BASELINE-' + [string]$trace[1]) $path (Get-H5Hash (Join-Path $targetRoot $path)) 'pass_with_warnings' 'trace_only' @('CHECK-P0-H5-CONTENT-DIGEST'))
  }

  $compileResult = Invoke-P0RuntimeV02 -Session $targetRoot -Plan $plan -EventPath $eventPath -Mode 'compile_render_input' -ProjectRoot $projectRoot
  if ($compileResult.ExitCode -ne 0) { throw ('compile_render_input_failed:' + [string]::Join(';', @($compileResult.Lines))) }
  $renderResult = Invoke-P0RuntimeV02 -Session $targetRoot -Plan $plan -EventPath $eventPath -Mode 'render_final_delivery' -ProjectRoot $projectRoot
  if ($renderResult.ExitCode -ne 0) { throw ('render_final_delivery_failed:' + [string]::Join(';', @($renderResult.Lines))) }
  $projectionResult = Update-P0StateProjection $targetRoot $plan $eventPath $false
  if ($projectionResult.ExitCode -ne 0) { throw "projection_build_failed:$($projectionResult.ResultCode)" }
  $resume = Write-P0ResumeSummary $targetRoot $plan $projectionResult.Projection

  $manifest = @"
schema_version: 0.5
contract_set_version: p0-contract-bundle-v0.2
session_id: $targetId
content_run_id: CR$targetToken
task_context_type: p0_h5_real_regression_verified_images_reused
account: $accountName
baseline_session_id: $baselineId
source_research_run_id: $researchId
started_at: $([DateTimeOffset]::Now.ToString('yyyy-MM-dd'))
updated_at: $([DateTimeOffset]::Now.ToString('yyyy-MM-dd'))
build_profile: dev
run_mode: phase_1_real_regression_with_verified_images_reused
current_stage: final_delivery
current_artifact: deliverables/final-delivery.html
session_status: session_waiting_human

artifacts:
  execution_plan: intermediate/p0/session-execution-plan.json
  execution_events: intermediate/p0/execution-events.jsonl
  state_projection: intermediate/p0/state-projection.json
  resume_summary: intermediate/p0/resume-summary.json
  reuse_manifest: assets/images/reuse-manifest.json
  render_candidate: deliverables/p0/final-delivery-render-candidate.json
  render_input: deliverables/p0/final-delivery-render-input.json
  render_receipt: deliverables/p0/render-receipt.json
  final_delivery: deliverables/final-delivery.html

statuses:
  baseline_content_status: reused_verified
  image_assets_status: reused_verified
  cover_quality_gate_status: pass
  final_delivery_status: html_ready
  runtime_status: completed

runtime_boundary:
  new_research_executed: false
  copywriting_executed: false
  image_provider_invoked: false
  publishing_invoked: false
  copied_asset_count: $($reuseAssets.Count)
  delivery_asset_count: $(@($reuseAssets | Where-Object { $_.included_in_delivery }).Count)

test_result:
  overall_result: pass_with_warnings
  workflow_result: pass_with_warnings
  artifact_result: pass_with_warnings
  checker_result: pending_h5_validation
  warning_codes: content_reused_from_baseline, verified_images_reused, external_image_generation_not_tested, publishing_not_tested
  not_tested_scope: new content quality / new image provider / automatic publishing / platform login / real distribution effect
"@
  Write-H5Text (Join-Path $targetRoot 'manifest.yaml') $manifest

  Write-Output 'P0_H5_RUN_RESULT=pass_with_warnings'
  Write-Output "SESSION_ID=$targetId"
  Write-Output "BASELINE_SESSION_ID=$baselineId"
  Write-Output "EVENT_COUNT=$(@(Get-P0EvidenceEvents $eventPath).Count)"
  Write-Output "COPIED_ASSET_COUNT=$($reuseAssets.Count)"
  Write-Output 'DELIVERY_ASSET_COUNT=7'
  Write-Output 'IMAGE_PROVIDER_INVOCATION_COUNT=0'
  Write-Output "RESUME_CURRENT_STATE=$($resume.current_state)"
  Write-Output 'FINAL_DELIVERY=deliverables/final-delivery.html'
  exit 0
} catch {
  Write-Error ('P0_H5_RUNNER_ERROR=' + $_.Exception.Message)
  exit 3
}
