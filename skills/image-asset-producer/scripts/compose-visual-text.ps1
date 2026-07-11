param(
  [Parameter(Mandatory = $true)][string]$InputPath,
  [Parameter(Mandatory = $true)][string]$OutputPath,
  [Parameter(Mandatory = $true)][string]$TextUnitsJson,
  [string]$FontFamilyName = "Microsoft YaHei",
  [ValidateRange(18, 160)][int]$FontSize = 54,
  [string]$ForegroundColor = "#FFFFFF",
  [string]$StrokeColor = "#111111",
  [ValidateRange(0, 220)][int]$BackgroundOpacity = 110,
  [switch]$Force
)

$ErrorActionPreference = "Stop"

function Resolve-OutputPath {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
  return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function Get-UnitRectangle {
  param([string]$Placement, [int]$Width, [int]$Height, [int]$Index)
  $pad = [Math]::Max(24, [int]($Width * 0.035))
  $boxWidth = [int]($Width * 0.62)
  $boxHeight = [int]($Height * 0.16)
  $thirdWidth = [int]($Width * 0.29)
  $thirdY = [int]($Height * 0.34)
  switch ($Placement) {
    "top_safe"            { return [System.Drawing.RectangleF]::new($pad, $pad + ($Index * $boxHeight), $boxWidth, $boxHeight) }
    "left_subject"        { return [System.Drawing.RectangleF]::new($pad, [int]($Height * 0.30) + ($Index * $boxHeight), $boxWidth, $boxHeight) }
    "right_subject"       { return [System.Drawing.RectangleF]::new($Width - $boxWidth - $pad, [int]($Height * 0.30) + ($Index * $boxHeight), $boxWidth, $boxHeight) }
    "bottom_safe"         { return [System.Drawing.RectangleF]::new($pad, $Height - $boxHeight - $pad - ($Index * $boxHeight), $boxWidth, $boxHeight) }
    "attached_to_subject" { return [System.Drawing.RectangleF]::new([int]($Width * 0.24), [int]($Height * 0.38) + ($Index * $boxHeight), $boxWidth, $boxHeight) }
    "node_inline"         { return [System.Drawing.RectangleF]::new([int]($Width * 0.18), [int]($Height * 0.18) + ($Index * $boxHeight), $boxWidth, $boxHeight) }
    "source_footer"       { return [System.Drawing.RectangleF]::new($pad, $Height - [int]($boxHeight * 0.75) - $pad, $Width - (2 * $pad), [int]($boxHeight * 0.75)) }
    "left_third"          { return [System.Drawing.RectangleF]::new($pad, $thirdY, $thirdWidth, $boxHeight) }
    "center_third"        { return [System.Drawing.RectangleF]::new([int](($Width - $thirdWidth) / 2), $thirdY, $thirdWidth, $boxHeight) }
    "right_third"         { return [System.Drawing.RectangleF]::new($Width - $thirdWidth - $pad, $thirdY, $thirdWidth, $boxHeight) }
    default               { throw "Unsupported placement: $Placement" }
  }
}

if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) { throw "Input image not found: $InputPath" }
$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$resolvedOutput = Resolve-OutputPath $OutputPath
if ((Test-Path -LiteralPath $resolvedOutput) -and -not $Force) {
  throw "Output already exists. Create a new image_asset_id or use -Force explicitly: $resolvedOutput"
}

$parsedUnits = ConvertFrom-Json -InputObject $TextUnitsJson
$units = New-Object System.Collections.Generic.List[object]
if ($parsedUnits -is [System.Array]) {
  foreach ($parsedUnit in $parsedUnits) { $units.Add($parsedUnit) }
} else {
  $units.Add($parsedUnits)
}
if ($units.Count -lt 1 -or $units.Count -gt 5) { throw "TextUnitsJson must contain 1-5 units." }
foreach ($unit in $units) {
  if ([string]::IsNullOrWhiteSpace([string]$unit.content)) { throw "Each text unit requires content." }
  if ([string]::IsNullOrWhiteSpace([string]$unit.placement)) { throw "Each text unit requires placement." }
}

$outputDir = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }

Add-Type -AssemblyName System.Drawing
$source = $null; $canvas = $null; $graphics = $null; $font = $null
$foregroundBrush = $null; $strokeBrush = $null; $panelBrush = $null; $format = $null
$sourceWidth = 0; $sourceHeight = 0
$layoutUnits = New-Object System.Collections.Generic.List[object]
try {
  $source = [System.Drawing.Image]::FromFile($resolvedInput)
  $sourceWidth = $source.Width; $sourceHeight = $source.Height
  $canvas = New-Object System.Drawing.Bitmap($source.Width, $source.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($canvas)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $graphics.DrawImage($source, 0, 0, $source.Width, $source.Height)

  $installed = New-Object System.Drawing.Text.InstalledFontCollection
  $available = @($installed.Families | ForEach-Object { $_.Name })
  $fontName = @($FontFamilyName, "Microsoft YaHei", "SimHei", "Arial") | Where-Object { $available -contains $_ } | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($fontName)) { $fontName = [System.Drawing.FontFamily]::GenericSansSerif.Name }
  $font = New-Object System.Drawing.Font($fontName, $FontSize, ([System.Drawing.FontStyle]::Bold), [System.Drawing.GraphicsUnit]::Pixel)
  $foregroundBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($ForegroundColor))
  $strokeBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($StrokeColor))
  $panelBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($BackgroundOpacity, 0, 0, 0))
  $format = New-Object System.Drawing.StringFormat
  $format.Alignment = [System.Drawing.StringAlignment]::Center
  $format.LineAlignment = [System.Drawing.StringAlignment]::Center
  $format.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter

  for ($i = 0; $i -lt $units.Count; $i++) {
    $unit = $units[$i]
    $rect = Get-UnitRectangle -Placement ([string]$unit.placement) -Width $source.Width -Height $source.Height -Index $i
    $layoutUnits.Add([ordered]@{ index=$i; placement=[string]$unit.placement; x=[int]$rect.X; y=[int]$rect.Y; width=[int]$rect.Width; height=[int]$rect.Height })
    $graphics.FillRectangle($panelBrush, $rect)
    foreach ($offset in @(-2, 0, 2)) {
      if ($offset -eq 0) { continue }
      $shadow = [System.Drawing.RectangleF]::new($rect.X + $offset, $rect.Y + $offset, $rect.Width, $rect.Height)
      $graphics.DrawString([string]$unit.content, $font, $strokeBrush, $shadow, $format)
    }
    $graphics.DrawString([string]$unit.content, $font, $foregroundBrush, $rect, $format)
  }
  $canvas.Save($resolvedOutput, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
  foreach ($item in @($format, $panelBrush, $strokeBrush, $foregroundBrush, $font, $graphics, $canvas, $source)) {
    if ($null -ne $item) { $item.Dispose() }
  }
}

$checksum = (Get-FileHash -LiteralPath $resolvedOutput -Algorithm SHA256).Hash
$layoutReportPath = $resolvedOutput + '.layout.json'
$layoutReport = [ordered]@{
  schema_id = 'taoge://reports/r3/visual-text-layout/v0.1'
  input_path = $resolvedInput
  input_sha256 = (Get-FileHash -LiteralPath $resolvedInput -Algorithm SHA256).Hash.ToLowerInvariant()
  output_path = $resolvedOutput
  output_sha256 = $checksum.ToLowerInvariant()
  canvas = [ordered]@{ width=$sourceWidth; height=$sourceHeight }
  units = [object[]]$layoutUnits.ToArray()
}
[System.IO.File]::WriteAllText($layoutReportPath,(($layoutReport|ConvertTo-Json -Depth 10)+"`n"),[System.Text.UTF8Encoding]::new($false))
Write-Output "VISUAL_TEXT_COMPOSITION_STATUS=composition_ready"
Write-Output "OUTPUT_PATH=$resolvedOutput"
Write-Output "CHECKSUM_SHA256=$checksum"
Write-Output "LAYOUT_REPORT_PATH=$layoutReportPath"
