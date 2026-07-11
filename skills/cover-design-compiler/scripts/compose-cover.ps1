param(
  [Parameter(Mandatory = $true)][string]$InputPath,
  [Parameter(Mandatory = $true)][string]$OutputPath,
  [Parameter(Mandatory = $true)][string]$CoverTitle,
  [string]$Platform = "generic",
  [ValidateRange(320, 4096)][int]$Width = 1080,
  [ValidateRange(320, 4096)][int]$Height = 1440,
  [ValidateSet("left", "right", "center", "top", "bottom")][string]$TextPosition = "left",
  [ValidateRange(24, 240)][int]$FontSize = 104,
  [ValidateRange(2, 20)][int]$MaxCharsPerLine = 7,
  [string]$FontFamilyName = "Microsoft YaHei",
  [string]$ForegroundColor = "#FFFFFF",
  [string]$StrokeColor = "#111111",
  [ValidateRange(0, 220)][int]$BackgroundOpacity = 92,
  [ValidateRange(20, 240)][int]$Padding = 72,
  [string]$RecordPath = "",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

function Resolve-ExistingPath {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Input image not found: $Path"
  }
  return (Resolve-Path -LiteralPath $Path).Path
}

function Split-CoverTitle {
  param([string]$Text, [int]$Limit)
  $normalized = $Text.Trim() -replace '\|', "`n"
  if ($normalized.Contains("`n")) {
    return (($normalized -split "`r?`n") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n"
  }
  $lines = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $normalized.Length; $i += $Limit) {
    $take = [Math]::Min($Limit, $normalized.Length - $i)
    $lines.Add($normalized.Substring($i, $take))
  }
  return [string]::Join("`n", $lines)
}

function Get-TextBox {
  param([string]$Position, [int]$CanvasWidth, [int]$CanvasHeight, [int]$Inset)
  switch ($Position) {
    "right"  { return [System.Drawing.RectangleF]::new($CanvasWidth * 0.43, $CanvasHeight * 0.18, $CanvasWidth * 0.50 - $Inset, $CanvasHeight * 0.64) }
    "center" { return [System.Drawing.RectangleF]::new($CanvasWidth * 0.12, $CanvasHeight * 0.23, $CanvasWidth * 0.76, $CanvasHeight * 0.54) }
    "top"    { return [System.Drawing.RectangleF]::new($Inset, $Inset, $CanvasWidth - (2 * $Inset), $CanvasHeight * 0.38) }
    "bottom" { return [System.Drawing.RectangleF]::new($Inset, $CanvasHeight * 0.58, $CanvasWidth - (2 * $Inset), $CanvasHeight * 0.34) }
    default   { return [System.Drawing.RectangleF]::new($Inset, $CanvasHeight * 0.18, $CanvasWidth * 0.52, $CanvasHeight * 0.64) }
  }
}

Add-Type -AssemblyName System.Drawing

$resolvedInput = Resolve-ExistingPath $InputPath
$resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
  [System.IO.Path]::GetFullPath($OutputPath)
} else {
  [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
}
if ((Test-Path -LiteralPath $resolvedOutput) -and -not $Force) {
  throw "Output already exists. Create a new image_asset_id or use -Force explicitly: $resolvedOutput"
}
$outputDir = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$source = $null
$canvas = $null
$graphics = $null
$font = $null
$format = $null
$foregroundBrush = $null
$strokeBrush = $null
$panelBrush = $null

try {
  $source = [System.Drawing.Image]::FromFile($resolvedInput)
  $canvas = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($canvas)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

  $scale = [Math]::Max($Width / $source.Width, $Height / $source.Height)
  $drawWidth = [int][Math]::Ceiling($source.Width * $scale)
  $drawHeight = [int][Math]::Ceiling($source.Height * $scale)
  $drawX = [int](($Width - $drawWidth) / 2)
  $drawY = [int](($Height - $drawHeight) / 2)
  $graphics.DrawImage($source, $drawX, $drawY, $drawWidth, $drawHeight)

  $installed = New-Object System.Drawing.Text.InstalledFontCollection
  $available = @($installed.Families | ForEach-Object { $_.Name })
  $fontName = @($FontFamilyName, "Microsoft YaHei", "SimHei", "Arial") | Where-Object { $available -contains $_ } | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($fontName)) { $fontName = [System.Drawing.FontFamily]::GenericSansSerif.Name }

  $text = Split-CoverTitle $CoverTitle $MaxCharsPerLine
  $textBox = Get-TextBox $TextPosition $Width $Height $Padding
  $format = New-Object System.Drawing.StringFormat
  $format.Alignment = if ($TextPosition -eq "center") { [System.Drawing.StringAlignment]::Center } else { [System.Drawing.StringAlignment]::Near }
  $format.LineAlignment = [System.Drawing.StringAlignment]::Center
  $format.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter

  $actualFontSize = [float]$FontSize
  while ($actualFontSize -ge 24) {
    if ($null -ne $font) { $font.Dispose() }
    $font = New-Object System.Drawing.Font($fontName, $actualFontSize, ([System.Drawing.FontStyle]::Bold), [System.Drawing.GraphicsUnit]::Pixel)
    $measured = $graphics.MeasureString($text, $font, [int]$textBox.Width, $format)
    if ($measured.Width -le $textBox.Width -and $measured.Height -le $textBox.Height) { break }
    $actualFontSize -= 4
  }

  $panelColor = [System.Drawing.Color]::FromArgb($BackgroundOpacity, 0, 0, 0)
  $panelBrush = New-Object System.Drawing.SolidBrush($panelColor)
  $graphics.FillRectangle($panelBrush, $textBox)

  $foreground = [System.Drawing.ColorTranslator]::FromHtml($ForegroundColor)
  $stroke = [System.Drawing.ColorTranslator]::FromHtml($StrokeColor)
  $foregroundBrush = New-Object System.Drawing.SolidBrush($foreground)
  $strokeBrush = New-Object System.Drawing.SolidBrush($stroke)
  $strokeOffset = [Math]::Max(2, [int]($actualFontSize / 30))
  foreach ($dx in @(-$strokeOffset, 0, $strokeOffset)) {
    foreach ($dy in @(-$strokeOffset, 0, $strokeOffset)) {
      if ($dx -eq 0 -and $dy -eq 0) { continue }
      $shadowBox = [System.Drawing.RectangleF]::new($textBox.X + $dx, $textBox.Y + $dy, $textBox.Width, $textBox.Height)
      $graphics.DrawString($text, $font, $strokeBrush, $shadowBox, $format)
    }
  }
  $graphics.DrawString($text, $font, $foregroundBrush, $textBox, $format)

  $canvas.Save($resolvedOutput, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
  if ($null -ne $panelBrush) { $panelBrush.Dispose() }
  if ($null -ne $strokeBrush) { $strokeBrush.Dispose() }
  if ($null -ne $foregroundBrush) { $foregroundBrush.Dispose() }
  if ($null -ne $format) { $format.Dispose() }
  if ($null -ne $font) { $font.Dispose() }
  if ($null -ne $graphics) { $graphics.Dispose() }
  if ($null -ne $canvas) { $canvas.Dispose() }
  if ($null -ne $source) { $source.Dispose() }
}

$checksum = (Get-FileHash -LiteralPath $resolvedOutput -Algorithm SHA256).Hash
if (-not [string]::IsNullOrWhiteSpace($RecordPath)) {
  $resolvedRecord = if ([System.IO.Path]::IsPathRooted($RecordPath)) {
    [System.IO.Path]::GetFullPath($RecordPath)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $RecordPath))
  }
  $recordDir = Split-Path -Parent $resolvedRecord
  if (-not (Test-Path -LiteralPath $recordDir)) { New-Item -ItemType Directory -Path $recordDir -Force | Out-Null }
  [ordered]@{
    platform = $Platform
    input_path = $resolvedInput
    output_path = $resolvedOutput
    cover_title = $CoverTitle
    width = $Width
    height = $Height
    text_position = $TextPosition
    font_family = $fontName
    font_size = $actualFontSize
    cover_text_render_strategy = "deterministic_overlay"
    cover_composition_status = "composition_ready"
    checksum_sha256 = $checksum
  } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $resolvedRecord -Encoding UTF8
}

Write-Output "COVER_COMPOSITION_STATUS=composition_ready"
Write-Output "OUTPUT_PATH=$resolvedOutput"
Write-Output "CHECKSUM_SHA256=$checksum"
return
