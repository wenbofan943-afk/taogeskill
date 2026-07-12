function Get-TaogeUtf8NoBomEncoding {
  return [System.Text.UTF8Encoding]::new($false)
}

function Write-TaogeUtf8NoBomText {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [AllowEmptyString()][string]$Text = '',
    [switch]$EnsureFinalNewline
  )
  $parent = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  $value = if ($EnsureFinalNewline) { $Text.TrimEnd("`r", "`n") + "`n" } else { $Text }
  [System.IO.File]::WriteAllText($Path, $value, (Get-TaogeUtf8NoBomEncoding))
}

function Write-TaogeUtf8NoBomLines {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [AllowEmptyCollection()][object[]]$Lines = @()
  )
  $text = if ($Lines.Count -eq 0) { '' } else { [string]::Join("`n", @($Lines | ForEach-Object { [string]$_ })) + "`n" }
  Write-TaogeUtf8NoBomText -Path $Path -Text $text
}

function Write-TaogeUtf8NoBomJson {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][object]$Value,
    [int]$Depth = 20,
    [switch]$Compress
  )
  $json = if ($Compress) { $Value | ConvertTo-Json -Depth $Depth -Compress } else { $Value | ConvertTo-Json -Depth $Depth }
  Write-TaogeUtf8NoBomText -Path $Path -Text $json -EnsureFinalNewline
}

function Get-TaogeFileSha256 {
  param([Parameter(Mandatory=$true)][string]$Path)
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  $stream = [System.IO.File]::OpenRead($resolved)
  $algorithm = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = $algorithm.ComputeHash($stream)
    return ([System.BitConverter]::ToString($bytes) -replace '-','').ToLowerInvariant()
  } finally {
    $algorithm.Dispose()
    $stream.Dispose()
  }
}

function Add-TaogeUtf8NoBomLine {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [AllowEmptyString()][string]$Line = ''
  )
  $parent = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  [System.IO.File]::AppendAllText($Path, $Line.TrimEnd("`r", "`n") + "`n", (Get-TaogeUtf8NoBomEncoding))
}

function ConvertTo-TaogeWindowsCommandLineArgument {
  param([AllowEmptyString()][string]$Value)
  if ($null -eq $Value) { $Value = '' }
  if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }

  $builder = [System.Text.StringBuilder]::new()
  [void]$builder.Append([char]34)
  $backslashCount = 0
  foreach ($character in $Value.ToCharArray()) {
    if ($character -eq [char]92) {
      $backslashCount++
      continue
    }
    if ($character -eq [char]34) {
      if ($backslashCount -gt 0) { [void]$builder.Append([char]92, ($backslashCount * 2)) }
      [void]$builder.Append([char]92)
      [void]$builder.Append([char]34)
      $backslashCount = 0
      continue
    }
    if ($backslashCount -gt 0) {
      [void]$builder.Append([char]92, $backslashCount)
      $backslashCount = 0
    }
    [void]$builder.Append($character)
  }
  if ($backslashCount -gt 0) { [void]$builder.Append([char]92, ($backslashCount * 2)) }
  [void]$builder.Append([char]34)
  return $builder.ToString()
}

function Join-TaogeWindowsCommandLine {
  param([AllowEmptyCollection()][object[]]$Arguments)
  return [string]::Join(' ', @($Arguments | ForEach-Object { ConvertTo-TaogeWindowsCommandLineArgument ([string]$_) }))
}

function Start-TaogeProcess {
  param(
    [Parameter(Mandatory=$true)][string]$FilePath,
    [AllowEmptyCollection()][object[]]$Arguments = @(),
    [string]$StandardOutputPath = '',
    [string]$StandardErrorPath = '',
    [string]$WorkingDirectory = '',
    [switch]$Wait,
    [switch]$Hidden
  )
  $startParameters = @{
    FilePath=$FilePath
    ArgumentList=(Join-TaogeWindowsCommandLine $Arguments)
    PassThru=$true
  }
  if (-not [string]::IsNullOrWhiteSpace($StandardOutputPath)) { $startParameters.RedirectStandardOutput = $StandardOutputPath }
  if (-not [string]::IsNullOrWhiteSpace($StandardErrorPath)) { $startParameters.RedirectStandardError = $StandardErrorPath }
  if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) { $startParameters.WorkingDirectory = [System.IO.Path]::GetFullPath($WorkingDirectory) }
  if ($Wait) { $startParameters.Wait = $true }
  if ($Hidden) { $startParameters.WindowStyle = 'Hidden' }
  return Start-Process @startParameters
}
