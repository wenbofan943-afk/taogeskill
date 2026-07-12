param(
  [string]$ProjectRoot = "",
  [string]$SessionId = "",
  [string]$RunPath = "",
  [string]$Account = "",
  [string]$Topic = "",
  [string]$OutputRoot = "",
  [switch]$IncludeContent
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')

function Copy-IfExists {
  param(
    [string]$Source,
    [string]$DestinationRoot,
    [string]$RelativeBase
  )
  if (-not (Test-Path -LiteralPath $Source)) { return @() }
  $copied = New-Object System.Collections.Generic.List[string]
  $sourceItem = Get-Item -LiteralPath $Source -Force
  if ($sourceItem.PSIsContainer) {
    Get-ChildItem -LiteralPath $Source -Recurse -File | ForEach-Object {
      $rel = $_.FullName.Substring($RelativeBase.Length).TrimStart('\')
      $dest = Join-Path $DestinationRoot $rel
      $dir = Split-Path -Parent $dest
      if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
      }
      Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
      $copied.Add($rel)
    }
  } else {
    $rel = $sourceItem.FullName.Substring($RelativeBase.Length).TrimStart('\')
    $dest = Join-Path $DestinationRoot $rel
    $dir = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $dir)) {
      New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    Copy-Item -LiteralPath $sourceItem.FullName -Destination $dest -Force
    $copied.Add($rel)
  }
  return $copied.ToArray()
}

function Get-ManifestValue {
  param([string]$Path, [string]$Key)
  if (-not (Test-Path -LiteralPath $Path)) { return "" }
  $pattern = "^\s*" + [regex]::Escape($Key) + "\s*:\s*(.*)\s*$"
  foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
    if ($line -match $pattern) {
      return $matches[1].Trim().Trim("'").Trim('"')
    }
  }
  return ""
}

function Get-RunCandidates {
  param([string]$AccountsRoot)
  if (-not (Test-Path -LiteralPath $AccountsRoot)) { return @() }
  return @(Get-ChildItem -LiteralPath $AccountsRoot -Recurse -Filter "manifest.yaml" -File -ErrorAction SilentlyContinue | ForEach-Object {
    $runRoot = Split-Path -Parent $_.FullName
    [pscustomobject]@{
      RunPath = $runRoot
      ManifestPath = $_.FullName
      SessionId = Get-ManifestValue -Path $_.FullName -Key "session_id"
      Account = Get-ManifestValue -Path $_.FullName -Key "account"
      TopicId = Get-ManifestValue -Path $_.FullName -Key "topic_id"
      CurrentStage = Get-ManifestValue -Path $_.FullName -Key "current_stage"
      CurrentArtifact = Get-ManifestValue -Path $_.FullName -Key "current_artifact"
      LastWriteTime = $_.LastWriteTime
    }
  })
}

try {
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
  }
  $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path

  if ([string]::IsNullOrWhiteSpace($RunPath)) {
    $candidates = Get-RunCandidates -AccountsRoot (Join-Path $ProjectRoot "accounts")
    if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
      $candidates = @($candidates | Where-Object { $_.SessionId -eq $SessionId -or (Split-Path -Leaf $_.RunPath) -eq $SessionId })
    }
    if (-not [string]::IsNullOrWhiteSpace($Account)) {
      $candidates = @($candidates | Where-Object { $_.Account -like "*$Account*" -or $_.RunPath -like "*$Account*" })
    }
    if (-not [string]::IsNullOrWhiteSpace($Topic)) {
      $candidates = @($candidates | Where-Object {
        $_.TopicId -like "*$Topic*" -or
        $_.CurrentArtifact -like "*$Topic*" -or
        ((Get-Content -LiteralPath $_.ManifestPath -Raw -Encoding UTF8) -like "*$Topic*")
      })
    }
    $candidates = @($candidates | Sort-Object LastWriteTime -Descending)
    if ($candidates.Count -eq 0) {
      Write-Error "No workflow run found. Tell the agent the account name or topic title, or pass -RunPath."
      exit 2
    }
    if ($candidates.Count -gt 1 -and [string]::IsNullOrWhiteSpace($SessionId) -and -not [string]::IsNullOrWhiteSpace($Topic) -and [string]::IsNullOrWhiteSpace($Account)) {
      Write-Output "SUPPORT_LOG_EXPORT=needs_selection"
      Write-Output "Multiple runs matched. Ask the user which one they mean:"
      $candidates | Select-Object -First 5 | ForEach-Object {
        Write-Output ("- account={0}; session_id={1}; topic_id={2}; stage={3}; run_path={4}" -f $_.Account, $_.SessionId, $_.TopicId, $_.CurrentStage, $_.RunPath)
      }
      exit 2
    }
    $RunPath = $candidates[0].RunPath
    if ([string]::IsNullOrWhiteSpace($SessionId)) {
      $SessionId = $candidates[0].SessionId
    }
  }

  $runRoot = (Resolve-Path -LiteralPath $RunPath).Path
  if (-not $runRoot.StartsWith($ProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "RunPath must stay inside ProjectRoot."
    exit 4
  }
  if ([string]::IsNullOrWhiteSpace($SessionId)) {
    $SessionId = Split-Path -Leaf $runRoot
  }

  if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $ProjectRoot "support-logs"
  }
  if (-not (Test-Path -LiteralPath $OutputRoot)) {
    New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
  }
  $OutputRoot = (Resolve-Path -LiteralPath $OutputRoot).Path
  if (-not $OutputRoot.StartsWith($ProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "OutputRoot must stay inside ProjectRoot."
    exit 4
  }

  $stamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
  $bundleName = "SUPPORT-$SessionId-$stamp"
  $bundleRoot = Join-Path $OutputRoot $bundleName
  New-Item -ItemType Directory -Force -Path $bundleRoot | Out-Null

  $copied = New-Object System.Collections.Generic.List[string]
  $safeItems = @(
    "manifest.yaml",
    "README.md",
    "intermediate\00-execution-trace.md",
    "intermediate\checkpoints",
    "intermediate\checks",
    "workflow-replay-report.md",
    "workflow-replay-report.json",
    "check-report.md",
    "sample-check-report.json"
  )
  foreach ($item in $safeItems) {
    $newFiles = @(Copy-IfExists -Source (Join-Path $runRoot $item) -DestinationRoot $bundleRoot -RelativeBase $runRoot)
    foreach ($file in $newFiles) {
      $copied.Add($file)
    }
  }

  if ($IncludeContent) {
    $contentItems = @(
      "inputs",
      "intermediate\01-research-run.md",
      "intermediate\02-topic-card.md",
      "intermediate\03-content-brief.md",
      "intermediate\04-draft.md",
      "intermediate\05-visual-plan.md",
      "intermediate\06-quality-review.md",
      "intermediate\07-platform-package-input.md",
      "intermediate\08-platform-package-draft.md",
      "deliverables\content-delivery-record.md",
      "deliverables\final-script.md",
      "deliverables\final-visual-plan.md",
      "deliverables\final-platform-package.md",
      "assets\images\image-assets.md",
      "assets\images\generation-records",
      "assets\images\metadata"
    )
    foreach ($item in $contentItems) {
      $newFiles = @(Copy-IfExists -Source (Join-Path $runRoot $item) -DestinationRoot $bundleRoot -RelativeBase $runRoot)
      foreach ($file in $newFiles) {
        $copied.Add($file)
      }
    }
  }

  $summaryPath = Join-Path $bundleRoot "support-log-summary.md"
  $includeMode = if ($IncludeContent) { "include_content" } else { "logs_only" }
  $fileList = ($copied.ToArray() | Sort-Object | ForEach-Object { "- $_" }) -join [Environment]::NewLine
  $summary = @"
# Support Log Summary

support_log_id: $bundleName
session_id: $SessionId
created_at: $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
mode: $includeMode
source_run_path: $runRoot

## How To Use

Send this zip to the maintainer when reporting a workflow problem. Describe:

- what you asked the agent to do
- where it felt confusing or broken
- what you expected instead
- whether this log bundle can include content details

## Privacy Note

Default mode is `logs_only`. It includes manifest, execution trace, checkpoints, and checker reports. It does not include full scripts, final HTML, generated images, or account snapshots unless `-IncludeContent` is used.

Before sharing, remove private account data, customer records, platform cookies, API keys, tokens, phone numbers, private WeChat IDs, or unpublished content you do not want reviewed.

## Included Files

$fileList
"@
  Write-TaogeUtf8NoBomText -Path $summaryPath -Text $summary -EnsureFinalNewline

  $zipPath = Join-Path $OutputRoot "$bundleName.zip"
  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
  }
  Compress-Archive -Path (Join-Path $bundleRoot "*") -DestinationPath $zipPath -Force
  $hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Set-Content -LiteralPath "$zipPath.sha256" -Value "$hash  $(Split-Path -Leaf $zipPath)" -Encoding ASCII

  Write-Output "SUPPORT_LOG_EXPORT=pass"
  Write-Output "MODE=$includeMode"
  Write-Output "BUNDLE=$bundleRoot"
  Write-Output "ZIP=$zipPath"
  Write-Output "SHA256=$hash"
  exit 0
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
