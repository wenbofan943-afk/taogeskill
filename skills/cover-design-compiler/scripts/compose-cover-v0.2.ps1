param(
  [Parameter(Mandatory = $true)][string]$SessionRoot,
  [Parameter(Mandatory = $true)][string]$PlanPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
. (Join-Path $projectRoot 'tools\WindowsRuntimeHelper.ps1')
. (Join-Path $projectRoot 'tools\R3VisualPresentation.ps1')

function Resolve-R3CoverSessionPath {
  param([string]$Root, [string]$RelativePath)
  if ([System.IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') { throw "cover_path_not_relative:$RelativePath" }
  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\','/')
  $full = [System.IO.Path]::GetFullPath((Join-Path $rootFull $RelativePath))
  if ($full -ne $rootFull -and -not $full.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) { throw "cover_path_escapes_session:$RelativePath" }
  return $full
}

function Get-R3CoverColor {
  param([string]$Value)
  if ($Value -notmatch '^#[0-9A-Fa-f]{6}$') { throw 'cover_color_invalid' }
  return [System.Drawing.ColorTranslator]::FromHtml($Value)
}

function Get-R3CoverFontName {
  $installed = New-Object System.Drawing.Text.InstalledFontCollection
  $available = @($installed.Families | ForEach-Object { $_.Name })
  $selected = @('Microsoft YaHei','SimHei','Arial') | Where-Object { $available -contains $_ } | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace([string]$selected)) { return [System.Drawing.FontFamily]::GenericSansSerif.Name }
  return [string]$selected
}

$session = (Resolve-Path -LiteralPath $SessionRoot).Path
$planFull = if ([System.IO.Path]::IsPathRooted($PlanPath)) { [System.IO.Path]::GetFullPath($PlanPath) } else { Resolve-R3CoverSessionPath $session $PlanPath }
if (-not (Test-Path -LiteralPath $planFull -PathType Leaf)) { throw 'cover_render_plan_missing' }
$plan = Get-Content -LiteralPath $planFull -Raw -Encoding UTF8 | ConvertFrom-Json
$planErrors = @(Test-R3CoverRenderPlan $plan)
if ($planErrors.Count) { throw ('cover_render_plan_invalid:' + [string]::Join(';', $planErrors)) }

$sourcePath = Resolve-R3CoverSessionPath $session ([string]$plan.source_path)
$outputPath = Resolve-R3CoverSessionPath $session ([string]$plan.output_path)
$recordPath = Resolve-R3CoverSessionPath $session ([string]$plan.composition_record_path)
$previewPath = Resolve-R3CoverSessionPath $session ([string]$plan.preview_path)
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw 'cover_source_asset_missing' }

if (Test-Path -LiteralPath $recordPath -PathType Leaf) {
  $existing = Get-Content -LiteralPath $recordPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $existingErrors = @(Test-R3CoverCompositionRecord $existing $plan)
  if ($existingErrors.Count -eq 0 -and (Test-Path -LiteralPath $outputPath -PathType Leaf) -and (Test-Path -LiteralPath $previewPath -PathType Leaf) -and ('sha256:' + (Get-TaogeFileSha256 $outputPath)) -eq [string]$existing.output_sha256 -and ('sha256:' + (Get-TaogeFileSha256 $previewPath)) -eq [string]$existing.preview_sha256) {
    Write-Output 'COVER_COMPOSITION_STATUS=skipped_reused'
    Write-Output "COVER_RENDITION_ID=$($plan.cover_rendition_id)"
    Write-Output "OUTPUT_PATH=$outputPath"
    exit 0
  }
  throw 'cover_existing_record_not_reusable'
}
foreach ($path in @($outputPath,$previewPath)) { if (Test-Path -LiteralPath $path) { throw "cover_partial_output_exists:$path" } }
if ($plan.adaptation_strategy -in @('outpaint_extend','independent_generation','manual_required')) { throw "cover_strategy_requires_external_or_manual_action:$($plan.adaptation_strategy)" }

Add-Type -AssemblyName System.Drawing
$source = $null; $canvas = $null; $graphics = $null; $font = $null; $format = $null; $panelBrush = $null; $textBrush = $null; $preview = $null; $previewGraphics = $null
try {
  $source = [System.Drawing.Image]::FromFile($sourcePath)
  if ($source.Width -ne [int]$plan.source_canvas.width_px -or $source.Height -ne [int]$plan.source_canvas.height_px) { throw 'cover_source_dimensions_do_not_match_plan' }
  $targetWidth = [int]$plan.target_canvas.width_px; $targetHeight = [int]$plan.target_canvas.height_px
  $canvas = New-Object System.Drawing.Bitmap($targetWidth, $targetHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($canvas)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

  $cropX = 0.0; $cropY = 0.0; $cropWidth = [double]$source.Width; $cropHeight = [double]$source.Height
  $retainedArea = 1.0; $protectedRetention = 'pass'
  if ($plan.adaptation_strategy -eq 'fit_pad') {
    $graphics.Clear((Get-R3CoverColor ([string]$plan.background_fill_spec.color)))
    $scale = [Math]::Min($targetWidth / $source.Width, $targetHeight / $source.Height)
    $drawWidth = [int][Math]::Round($source.Width * $scale); $drawHeight = [int][Math]::Round($source.Height * $scale)
    $drawX = [int](($targetWidth - $drawWidth) / 2); $drawY = [int](($targetHeight - $drawHeight) / 2)
    $graphics.DrawImage($source, $drawX, $drawY, $drawWidth, $drawHeight)
  } else {
    if ($plan.adaptation_strategy -eq 'focal_crop') {
      $targetRatio = $targetWidth / [double]$targetHeight
      $sourceRatio = $source.Width / [double]$source.Height
      if ($sourceRatio -gt $targetRatio) {
        $cropWidth = $source.Height * $targetRatio
        $cropX = ([double]$plan.focal_point.x * $source.Width) - ($cropWidth / 2)
        $cropX = [Math]::Max(0, [Math]::Min($source.Width - $cropWidth, $cropX))
      } elseif ($sourceRatio -lt $targetRatio) {
        $cropHeight = $source.Width / $targetRatio
        $cropY = ([double]$plan.focal_point.y * $source.Height) - ($cropHeight / 2)
        $cropY = [Math]::Max(0, [Math]::Min($source.Height - $cropHeight, $cropY))
      }
      $retainedArea = ($cropWidth * $cropHeight) / ($source.Width * [double]$source.Height)
      $requiredIds = @($plan.required_visual_element_ids | ForEach-Object { [string]$_ })
      foreach ($region in @($plan.protected_regions | Where-Object { $requiredIds -contains [string]$_.visual_element_id })) {
        $left = [double]$region.x * $source.Width; $top = [double]$region.y * $source.Height
        $right = ([double]$region.x + [double]$region.width) * $source.Width; $bottom = ([double]$region.y + [double]$region.height) * $source.Height
        if ($left -lt ($cropX - 0.01) -or $top -lt ($cropY - 0.01) -or $right -gt ($cropX + $cropWidth + 0.01) -or $bottom -gt ($cropY + $cropHeight + 0.01)) {
          $protectedRetention = 'fail'
          throw "destructive_crop_protected_region:$($region.visual_element_id)"
        }
      }
      if ($retainedArea -lt 0.999999 -and [string]::IsNullOrWhiteSpace([string]$plan.crop_loss_justification)) { throw 'crop_loss_justification_required' }
    }
    $destination = [System.Drawing.Rectangle]::new(0,0,$targetWidth,$targetHeight)
    $sourceX = [int][Math]::Round($cropX); $sourceY = [int][Math]::Round($cropY)
    $sourceWidth = [int][Math]::Round($cropWidth); $sourceHeight = [int][Math]::Round($cropHeight)
    $graphics.DrawImage($source,$destination,$sourceX,$sourceY,$sourceWidth,$sourceHeight,[System.Drawing.GraphicsUnit]::Pixel)
  }

  $titleRect = [System.Drawing.RectangleF]::new(
    [float]([double]$plan.title_safe_area.x * $targetWidth),
    [float]([double]$plan.title_safe_area.y * $targetHeight),
    [float]([double]$plan.title_safe_area.width * $targetWidth),
    [float]([double]$plan.title_safe_area.height * $targetHeight)
  )
  $panelBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(156,0,0,0))
  $graphics.FillRectangle($panelBrush,$titleRect)
  $format = New-Object System.Drawing.StringFormat
  $format.Alignment = [System.Drawing.StringAlignment]::Center; $format.LineAlignment = [System.Drawing.StringAlignment]::Center; $format.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
  $fontSize = [float][Math]::Max(28,[Math]::Min(132,$targetWidth * 0.085)); $fontName = Get-R3CoverFontName
  do {
    if ($null -ne $font) { $font.Dispose() }
    $font = New-Object System.Drawing.Font($fontName,$fontSize,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
    $measurement = $graphics.MeasureString([string]$plan.cover_title,$font,[int]$titleRect.Width,$format)
    if ($measurement.Width -le $titleRect.Width -and $measurement.Height -le $titleRect.Height) { break }
    $fontSize -= 4
  } while ($fontSize -ge 24)
  $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
  $graphics.DrawString([string]$plan.cover_title,$font,$textBrush,$titleRect,$format)

  foreach ($path in @($outputPath,$previewPath,$recordPath)) { $parent = Split-Path -Parent $path; if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null } }
  $canvas.Save($outputPath,[System.Drawing.Imaging.ImageFormat]::Png)
  $previewWidth = [Math]::Min(390,$targetWidth); $previewHeight = [int][Math]::Round($targetHeight * ($previewWidth / [double]$targetWidth))
  $preview = New-Object System.Drawing.Bitmap($previewWidth,$previewHeight,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $previewGraphics = [System.Drawing.Graphics]::FromImage($preview); $previewGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $previewGraphics.DrawImage($canvas,0,0,$previewWidth,$previewHeight)
  $preview.Save($previewPath,[System.Drawing.Imaging.ImageFormat]::Png)

  $record = [ordered]@{
    schema_id='taoge://schemas/r3/cover-composition-record/v0.2'; schema_version='0.2'
    cover_rendition_id=[string]$plan.cover_rendition_id; rendition_revision=[int]$plan.rendition_revision
    surface_profile_id=[string]$plan.surface_profile_id; platform=[string]$plan.platform; platform_priority=[string]$plan.platform_priority
    adaptation_strategy=[string]$plan.adaptation_strategy; source_asset_id=[string]$plan.source_asset_id
    source_canvas=$plan.source_canvas; target_canvas=$plan.target_canvas
    crop_contract=[ordered]@{
      crop_window=[ordered]@{x=$cropX/$source.Width;y=$cropY/$source.Height;width=$cropWidth/$source.Width;height=$cropHeight/$source.Height}
      source_retained_area_ratio=[Math]::Round($retainedArea,6); required_visual_element_ids=[object[]]@($plan.required_visual_element_ids)
      protected_region_retention_status=$protectedRetention; crop_loss_justification=$plan.crop_loss_justification
    }
    output_path=[string]$plan.output_path; output_sha256='sha256:'+(Get-TaogeFileSha256 $outputPath)
    preview_path=[string]$plan.preview_path; preview_sha256='sha256:'+(Get-TaogeFileSha256 $previewPath)
    preview_evidence_type='deterministic_surface_mock'; profile_evidence_status=[string]$plan.profile_evidence_status
    structural_gate_status='pass'; visual_review_status='not_reviewed'; cover_delivery_status='waiting_visual_review'
    plan_sha256='sha256:'+(Get-TaogeFileSha256 $planFull); composed_at=[DateTimeOffset]::UtcNow.ToString('o')
  }
  $recordErrors = @(Test-R3CoverCompositionRecord ([pscustomobject]$record) $plan)
  if ($recordErrors.Count) { throw ('cover_composition_record_invalid:' + [string]::Join(';',$recordErrors)) }
  Write-TaogeUtf8NoBomJson -Path $recordPath -Value $record -Depth 30
  Write-Output 'COVER_COMPOSITION_STATUS=preview_ready_waiting_visual_review'
  Write-Output "COVER_RENDITION_ID=$($plan.cover_rendition_id)"
  Write-Output "OUTPUT_PATH=$outputPath"
  Write-Output "PREVIEW_PATH=$previewPath"
  Write-Output "SOURCE_RETAINED_AREA_RATIO=$([Math]::Round($retainedArea,6))"
} finally {
  foreach ($item in @($previewGraphics,$preview,$textBrush,$panelBrush,$format,$font,$graphics,$canvas,$source)) { if ($null -ne $item) { $item.Dispose() } }
}
