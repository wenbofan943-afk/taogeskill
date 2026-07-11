param(
  [string]$TargetPath = "docs/tutorials/r3-dry-run-sample/accounts/sample-account/runs/SR3DR-001"
)

$ErrorActionPreference = "Stop"

function Test-RequiredText {
  param(
    [string]$CheckId,
    [string]$FilePath,
    [string[]]$Needles
  )
  if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
    Write-Host "$CheckId fail missing_file $FilePath"
    return 1
  }
  $text = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
  $missing = @($Needles | Where-Object { -not $text.Contains($_) })
  if ($missing.Count -gt 0) {
    Write-Host "$CheckId fail missing_tokens $([string]::Join(', ', $missing))"
    return 1
  }
  Write-Host "$CheckId pass"
  return 0
}

try {
  if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
    Write-Output "COVER-001 fail target_missing $TargetPath"
    $global:LASTEXITCODE = 1
    return
  }

  $root = (Resolve-Path -LiteralPath $TargetPath).Path
  $failures = 0
  $coverPackage = Join-Path $root "intermediate\08-cover-design-package.md"
  $compositions = Join-Path $root "intermediate\09-cover-compositions.md"
  $coverReview = Join-Path $root "intermediate\09-cover-quality-review.md"
  $assetSet = Join-Path $root "assets\images\image-assets.md"
  $embedManifest = Join-Path $root "deliverables\html-embed-manifest.md"
  $finalHtml = Join-Path $root "deliverables\final-delivery.html"

  $failures += Test-RequiredText "COVER-002" $coverPackage @(
    "cover_design_package_id", "cover_text_render_strategy", "cover_background_asset_id",
    "platform_cover_strategy", "cover_visual_entry_type", "cover_variant_difference_type",
    "materially_distinct_variant_count", "cover_design_status", "next_skill: copywriting-quality-review"
  )
  $failures += Test-RequiredText "COVER-003" $compositions @(
    "cover_composition_id", "cover_design_package_id", "platform_cover_strategy",
    "cover_text_render_strategy", "cover_composition_status", "next_skill: copywriting-quality-review"
  )
  $failures += Test-RequiredText "COVER-004" $coverReview @(
    "review_mode: cover_review", "cover_quality_gate_id", "cover_composition_id",
    "text_accuracy_status", "upload_readiness_status", "thumbnail_readability_status",
    "cover_contract_render_alignment_status", "platform_preview_status",
    "quality_gate_status", "next_skill: final-delivery-builder"
  )
  $failures += Test-RequiredText "COVER-005" $assetSet @(
    "cover_asset_role", "cover_background_asset", "source_cover_composition_id", "target_platforms"
  )
  $failures += Test-RequiredText "COVER-006" $embedManifest @(
    "cover_embeds", "platform_cover_strategy", "cover_composition_status", "prompt_path_if_not_generated"
  )
  $failures += Test-RequiredText "COVER-007" $finalHtml @(
    "封面底图", "平台封面策略", "prompt_only", "非成品", "封面专项质检"
  )

  $compositionText = if (Test-Path -LiteralPath $compositions) { Get-Content -LiteralPath $compositions -Raw -Encoding UTF8 } else { "" }
  if ($compositionText.Contains("cover_composition_status: composition_ready")) {
    $missingReady = @("output_asset_id:", "output_path:") | Where-Object { -not $compositionText.Contains($_) }
    if (@($missingReady).Count -gt 0) {
      Write-Output "COVER-008 fail composition_ready_missing_output"
      $failures++
    } else {
      Write-Output "COVER-008 pass"
    }
  } elseif ($compositionText.Contains("cover_composition_status: prompt_only")) {
    $promptTokens = @("complete_prompt:", "layout_spec:", "human_action_required:")
    $missingPrompt = @($promptTokens | Where-Object { -not $compositionText.Contains($_) })
    if ($missingPrompt.Count -gt 0) {
      Write-Output "COVER-008 fail prompt_only_missing_delivery_fields $([string]::Join(', ', $missingPrompt))"
      $failures++
    } else {
      Write-Output "COVER-008 pass"
    }
  } else {
    Write-Output "COVER-008 fail unsupported_composition_status"
    $failures++
  }

  if ($failures -gt 0) {
    Write-Output "COVER_COMPOSITION_CHECK=fail"
    Write-Output "FAILURE_COUNT=$failures"
    $global:LASTEXITCODE = 1
    return
  }
  Write-Output "COVER_COMPOSITION_CHECK=pass"
  Write-Output "FAILURE_COUNT=0"
  $global:LASTEXITCODE = 0
  return
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  $global:LASTEXITCODE = 3
  return
}
