function Get-TaogeUtf8NoBomEncoding {
  return [System.Text.UTF8Encoding]::new($false)
}

function Resolve-TaogeFileSystemPath {
  param([Parameter(Mandatory=$true)][string]$Path)
  $resolved = Resolve-Path -LiteralPath $Path
  return $(if (-not [string]::IsNullOrWhiteSpace([string]$resolved.ProviderPath)) { [string]$resolved.ProviderPath } else { [string]$resolved.Path })
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

function Write-TaogeUtf8BomText {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [AllowEmptyString()][string]$Text = '',
    [switch]$EnsureFinalNewline
  )
  $full = [System.IO.Path]::GetFullPath($Path)
  $parent = [System.IO.Path]::GetDirectoryName($full)
  if (-not [string]::IsNullOrWhiteSpace($parent)) { [System.IO.Directory]::CreateDirectory($parent) | Out-Null }
  $value = if ($EnsureFinalNewline -and -not $Text.EndsWith("`n")) { $Text + [Environment]::NewLine } else { $Text }
  [System.IO.File]::WriteAllText($full,$value,[System.Text.UTF8Encoding]::new($true))
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
  $resolved = Resolve-TaogeFileSystemPath -Path $Path
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

function Get-TaogeGitTrackedPathsUtf8 {
  param(
    [Parameter(Mandatory=$true)][string]$ProjectRoot,
    [string]$GitPath = 'git'
  )
  $root = [System.IO.Path]::GetFullPath($ProjectRoot)
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $GitPath
  $startInfo.Arguments = Join-TaogeWindowsCommandLine @('-C',$root,'-c','core.quotepath=false','ls-files','--cached','-z')
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  $startInfo.StandardOutputEncoding = $utf8
  $startInfo.StandardErrorEncoding = $utf8
  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  try {
    if (-not $process.Start()) { throw 'git_path_list_process_start_failed' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { throw "git_path_list_failed:$($process.ExitCode):$stderr" }
    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($path in $stdout.Split([char]0)) {
      if (-not [string]::IsNullOrEmpty($path)) { $paths.Add($path) }
    }
    return [string[]]$paths.ToArray()
  } finally {
    $process.Dispose()
  }
}

function Get-TaogeGitTopLevelUtf8 {
  param(
    [Parameter(Mandatory=$true)][string]$ProjectRoot,
    [string]$GitPath = 'git'
  )
  $root = [System.IO.Path]::GetFullPath($ProjectRoot)
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $GitPath
  $startInfo.Arguments = Join-TaogeWindowsCommandLine @('-C',$root,'rev-parse','--show-toplevel')
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  $startInfo.StandardOutputEncoding = $utf8
  $startInfo.StandardErrorEncoding = $utf8
  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  try {
    if (-not $process.Start()) { return '' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    [void]$stderrTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { return '' }
    return $stdout.Trim()
  } finally {
    $process.Dispose()
  }
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

function Invoke-TaogeProcessCapture {
  param(
    [Parameter(Mandatory=$true)][string]$FilePath,
    [AllowEmptyCollection()][object[]]$Arguments = @(),
    [string]$WorkingDirectory = '',
    [switch]$AllowNonZeroExit
  )
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $FilePath
  $startInfo.Arguments = Join-TaogeWindowsCommandLine $Arguments
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
    $startInfo.WorkingDirectory = [System.IO.Path]::GetFullPath($WorkingDirectory)
  }
  $utf8 = Get-TaogeUtf8NoBomEncoding
  $startInfo.StandardOutputEncoding = $utf8
  $startInfo.StandardErrorEncoding = $utf8
  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  try {
    if (-not $process.Start()) { throw 'process_start_failed' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $result = [pscustomobject][ordered]@{
      exit_code = $process.ExitCode
      stdout = $stdout
      stderr = $stderr
    }
    if ($process.ExitCode -ne 0 -and -not $AllowNonZeroExit) {
      throw "process_failed:$($process.ExitCode):$stderr"
    }
    return $result
  } finally {
    $process.Dispose()
  }
}
