param(
  [string]$ProjectRoot = "",
  [string]$PublicReleasePath = "",
  [string]$ZipPath = "",
  [string]$Sha256Path = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'EnvironmentPreflight.ps1')

try {
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
  }
  $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
  $Version = (Get-Content -LiteralPath (Join-Path $ProjectRoot 'VERSION') -Raw -Encoding UTF8).Trim()
  if ([string]::IsNullOrWhiteSpace($Version)) { throw 'VERSION is empty' }
  $TagName = "v$Version"
  if ([string]::IsNullOrWhiteSpace($PublicReleasePath)) {
    $PublicReleasePath = Join-Path $ProjectRoot "releases\$TagName\public_release"
  }
  if ([string]::IsNullOrWhiteSpace($ZipPath)) {
    $ZipPath = Join-Path $ProjectRoot "releases\$TagName\taoge-creative-workflow-$Version-public-release.zip"
  }
  if ([string]::IsNullOrWhiteSpace($Sha256Path)) {
    $Sha256Path = "$ZipPath.sha256"
  }

  $releaseBase = Join-Path $ProjectRoot "releases"
  if (-not (Test-Path -LiteralPath $releaseBase)) {
    New-Item -ItemType Directory -Force -Path $releaseBase | Out-Null
  }
  $releaseBase = (Resolve-Path -LiteralPath $releaseBase).Path.TrimEnd('\')

  $publicRoot = [System.IO.Path]::GetFullPath($PublicReleasePath)
  $resolvedZipPath = [System.IO.Path]::GetFullPath($ZipPath)
  $resolvedSha256Path = [System.IO.Path]::GetFullPath($Sha256Path)
  $releasePrefix = $releaseBase + '\'
  if (-not $publicRoot.StartsWith($releasePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "PublicReleasePath must stay inside the project releases directory."
    exit 4
  }
  if (-not $resolvedZipPath.StartsWith($releasePrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
      -not $resolvedSha256Path.StartsWith($releasePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "ZipPath and Sha256Path must stay inside the project releases directory."
    exit 4
  }
  $ZipPath = $resolvedZipPath
  $Sha256Path = $resolvedSha256Path
  # In a Git worktree, package only reviewed source already tracked in the index.
  # This prevents local drafts, account data, and unreviewed research from leaking
  # through broad directory copies. Source archives without .git keep legacy mode.
  $trackedSourcePaths = $null
  $gitTopLevel = @(& git -C $ProjectRoot rev-parse --show-toplevel 2>$null | ForEach-Object { [string]$_ })
  $gitRootMatchesProjectRoot = $false
  if ($LASTEXITCODE -eq 0 -and $gitTopLevel.Count -eq 1) {
    try { $gitRootMatchesProjectRoot = [System.IO.Path]::GetFullPath($gitTopLevel[0]).TrimEnd('\','/') -eq $ProjectRoot.TrimEnd('\','/') } catch {}
  }
  if ($gitRootMatchesProjectRoot) {
    $trackedSourcePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    @(git -C $ProjectRoot -c core.quotepath=false ls-files --cached) | ForEach-Object {
      [void]$trackedSourcePaths.Add(($_ -replace '\\', '/'))
    }
  }

  function Test-ReleaseSourceFile {
    param([string]$RelativePath)
    if ($null -eq $trackedSourcePaths) { return $true }
    return $trackedSourcePaths.Contains(($RelativePath -replace '\\', '/'))
  }

  $copyItems = @(
    "README.md", "AGENTS.md", "STATUS.md", "PROJECT_MAP.md", "CONTACT.md", "public-manifest.yaml", "VERSION", "LICENSE",
    "CONTRIBUTING.md", "SECURITY.md", "CODE_OF_CONDUCT.md", "release-checklist.md", "INSTALL.md", "UPDATE.md",
    "CHANGELOG.md", "NOTICE.md", "RELEASE_NOTES.md", "交接物字段词典.md",
    "tools\README.md", "tools\WindowsRuntimeHelper.ps1", "tools\EnvironmentPreflight.ps1", "tools\invoke-environment-doctor.ps1", "tools\validate-environment-preflight.ps1", "tools\validate-windows-runtime-helper.ps1", "tools\validate-public-release.ps1", "tools\validate-sample-run.ps1", "tools\build-public-release.ps1",
    "tools\validate-final-delivery-template.ps1", "tools\validate-field-schema.ps1", "tools\YamlHelper.ps1", "tools\validate-workflow-replay.ps1",
    "tools\validate-regression-suite.ps1", "tools\validate-ci-workflow.ps1", "tools\validate-alpha-expression.ps1",
    "tools\validate-route-schema.ps1", "tools\validate-gates.ps1", "tools\validate-doc-governance.ps1", "tools\validate-cover-composition.ps1", "tools\validate-r3-visual-text.ps1", "tools\R3VisualBudget.ps1", "tools\validate-r3-visual-budget.ps1", "tools\R3VisualNeed.ps1", "tools\validate-r3-visual-need.ps1", "tools\validate-release-gate.ps1", "tools\export-support-log.ps1",
    "tools\invoke-workflow-runtime.ps1", "tools\P0ContractHelper.ps1", "tools\P0RuntimeV02.ps1", "tools\P0FinalDeliveryV03.ps1", "tools\P0EvidenceRuntime.ps1", "tools\invoke-p0-evidence.ps1", "tools\validate-p0-h1-contracts.ps1", "tools\validate-p0-h2-runtime.ps1", "tools\validate-p0-h3-fixtures.ps1", "tools\validate-p0-h4-evidence.ps1", "tools\invoke-p0-h5-regression.ps1", "tools\validate-p0-h5-regression.ps1", "tools\validate-p0-h6-preflight.ps1", "tools\complete-p0-h6-regression.ps1", "tools\validate-p0-h6-regression.ps1", "tools\validate-p0-h6-reliability.ps1", "tools\prepare-p0-h7-delivery.ps1", "tools\complete-p0-h7-delivery.ps1", "tools\validate-p0-h7-delivery.ps1", "tools\validate-p0-h7-fixtures.ps1"
  )
  $copyDirs = @("docs", "routes", "state", "skills", "templates", "examples", ".github")

  $candidateRelativePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($item in $copyItems) {
    if ((Test-ReleaseSourceFile $item) -and (Test-Path -LiteralPath (Join-Path $ProjectRoot $item) -PathType Leaf)) { [void]$candidateRelativePaths.Add(($item -replace '\\','/')) }
  }
  if ($null -ne $trackedSourcePaths) {
    foreach ($trackedPath in $trackedSourcePaths) {
      foreach ($dir in $copyDirs) {
        if ($trackedPath.StartsWith((($dir -replace '\\','/') + '/'), [System.StringComparison]::OrdinalIgnoreCase)) { [void]$candidateRelativePaths.Add($trackedPath); break }
      }
    }
  }
  $estimatedSourceBytes = [long]0
  foreach ($relativePath in $candidateRelativePaths) {
    $sourceFullPath = Join-Path $ProjectRoot ($relativePath -replace '/', '\')
    if (Test-Path -LiteralPath $sourceFullPath -PathType Leaf) { $estimatedSourceBytes += [long](Get-Item -LiteralPath $sourceFullPath).Length }
  }
  $requiredFreeBytes = [long](67108864 + ($estimatedSourceBytes * 3))
  $environmentPreflight = Invoke-TaogeEnvironmentPreflight -ProjectRoot $ProjectRoot -AllowedRoot $releaseBase -TargetRoot $publicRoot -RelativePaths ([string[]]@($candidateRelativePaths)) -RequiredFreeBytes $requiredFreeBytes -ProbeWrite
  $zipContainment = Resolve-TaogeContainedPath -AllowedRoot $releaseBase -CandidatePath $ZipPath -RejectReparsePoints
  $shaContainment = Resolve-TaogeContainedPath -AllowedRoot $releaseBase -CandidatePath $Sha256Path -RejectReparsePoints
  if ($environmentPreflight.status -ne 'pass' -or $zipContainment.status -ne 'pass' -or $shaContainment.status -ne 'pass') {
    $preflightErrors = @($environmentPreflight.failure_categories) + @($zipContainment.errors) + @($shaContainment.errors)
    throw ('environment_preflight_failed:' + [string]::Join(',', @($preflightErrors)))
  }

  if (-not (Test-Path -LiteralPath $publicRoot)) { New-Item -ItemType Directory -Force -Path $publicRoot | Out-Null }
  Get-ChildItem -LiteralPath $publicRoot -Force | Remove-Item -Recurse -Force

  $replacements = [ordered]@{
    $ProjectRoot = "PROJECT_ROOT"
    ($ProjectRoot -replace '\\', '/') = "PROJECT_ROOT"
    "示例行业观察号" = "sample-industry-observation-account"
    "示例服务账号" = "sample-service-account"
    "示例垂类经营号" = "sample-vertical-creator-account"
    "示例观点账号" = "示例观点号"
    "示例评论账号" = "sample-commentary-account"
    "SAMPLE-SESSION-001" = "SAMPLE-SESSION-001"
    "SAMPLE-HISTORICAL-005" = "SAMPLE-HISTORICAL-SESSION"
    "SAMPLE-HISTORICAL-004" = "SAMPLE-HISTORICAL-004"
    "SAMPLE-HISTORICAL-003" = "SAMPLE-HISTORICAL-003"
    "SAMPLE-HISTORICAL-002" = "SAMPLE-HISTORICAL-002"
    "SAMPLE-HISTORICAL-001" = "SAMPLE-HISTORICAL-001"
    "file://" = "local-file-url-disabled://"
  }

  $textExt = @(".md", ".yaml", ".yml", ".toml", ".json", ".txt", ".html", ".css", ".js", ".csv", ".ps1")
  function Copy-SanitizedFile {
    param([string]$SourcePath, [string]$DestinationPath)
    $dir = Split-Path -Parent $DestinationPath
    if (-not (Test-Path -LiteralPath $dir)) {
      New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $ext = [System.IO.Path]::GetExtension($SourcePath).ToLowerInvariant()
    if ($textExt -contains $ext -or $ext -eq "") {
      $content = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8
      foreach ($key in $replacements.Keys) {
        $content = $content.Replace($key, $replacements[$key])
      }
      # Remove common Windows-local roots without embedding a concrete machine path
      # in the tracked source archive itself.
      $content = [regex]::Replace($content, '(?i)[A-Z]:[\\/](?:OpenClaw|Users)(?:[\\/])?', 'LOCAL_ROOT/')
      Write-TaogeUtf8NoBomText -Path $DestinationPath -Text $content -EnsureFinalNewline
    } else {
      Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
    }
  }

  foreach ($item in $copyItems) {
    $src = Join-Path $ProjectRoot $item
    if ((Test-ReleaseSourceFile $item) -and (Test-Path -LiteralPath $src)) {
      Copy-SanitizedFile $src (Join-Path $publicRoot $item)
    }
  }

  foreach ($dir in $copyDirs) {
    $srcDir = Join-Path $ProjectRoot $dir
    if (Test-Path -LiteralPath $srcDir) {
      $sourceFiles = if ($null -ne $trackedSourcePaths) {
        $trackedPrefix = (($dir -replace '\\','/') + '/')
        @($trackedSourcePaths | Where-Object { $_.StartsWith($trackedPrefix, [System.StringComparison]::OrdinalIgnoreCase) } | Sort-Object | ForEach-Object {
          $trackedFullPath = Join-Path $ProjectRoot ($_ -replace '/', '\')
          if (Test-Path -LiteralPath $trackedFullPath -PathType Leaf) { Get-Item -LiteralPath $trackedFullPath }
        })
      } else {
        @(Get-ChildItem -LiteralPath $srcDir -Recurse -File)
      }
      $sourceFiles | ForEach-Object {
        $rel = $_.FullName.Substring($srcDir.Length).TrimStart('\')
        $projectRelativePath = Join-Path $dir $rel
        if (-not (Test-ReleaseSourceFile $projectRelativePath)) {
          return
        }
        if ($dir -eq 'state' -and $rel.StartsWith('checks\', [System.StringComparison]::OrdinalIgnoreCase)) {
          return
        }
        Copy-SanitizedFile $_.FullName (Join-Path (Join-Path $publicRoot $dir) $rel)
      }
    }
  }

  $publicReadme = Join-Path $publicRoot "README.md"
  if (Test-Path -LiteralPath $publicReadme) {
    $readme = Get-Content -LiteralPath $publicReadme -Raw -Encoding UTF8
    $externalReplacement = @'
外部资料说明：

- 公开包不包含外部资料缓存、第三方仓库副本或本机调研目录。
- 外部资料只作为本项目方法论研究来源，不是运行依赖。
- 公开使用者只需要阅读本包内的 `README.md`、`AGENTS.md`、`PROJECT_MAP.md`、`routes/`、`skills/`、`docs/`、`templates/`、`tools/` 和 `examples/`。

项目治理入口：
'@
    $readme = [regex]::Replace($readme, "外部资料位置：[\s\S]*?项目治理入口：", $externalReplacement)
    $accountReplacement = @'
账号档案：

- [sample-account](./examples/sample-account/account_profile.md)：公开包只提供虚构账号档案样例。
- [sample-01-onboarding](./examples/sample-01-onboarding/README.md)：没有账号时如何新建账号。

---

## 三、建议文件结构
'@
    $readme = [regex]::Replace($readme, "账号档案：[\s\S]*?---\s+## 三、建议文件结构", $accountReplacement)
    Write-TaogeUtf8NoBomText -Path $publicReadme -Text $readme -EnsureFinalNewline
  }

  $publicState = Join-Path $publicRoot "工作流状态记录.md"
  $publicStateLines = @(
    "# Workflow State Record",
    "",
    "> 状态：public_sample_template",
    "> 边界：公开包不包含真实账号、真实生产 runs 或真实交付物。",
    "",
    "## governance_id: PUBLIC-SAMPLE-001",
    "",
    "- current_stage：public_sample_ready",
    "- current_artifact：examples/sample-02-single-content-run/README.md",
    "- field_gate_status：pass_with_warnings",
    "- session_status：sample_ready_for_review",
    "",
    "### P3 Checker Contract",
    "",
    "- command_contract：tools/README.md",
    "- current_note：P3 has minimal validator scripts, but no CI runner."
  )
  Write-TaogeUtf8NoBomLines -Path $publicState -Lines $publicStateLines

  $releaseRecord = [ordered]@{
    release_record = [ordered]@{
      release_id = "REL-" + (Get-Date -Format "yyyyMMdd-HHmmss")
      release_state = "release_candidate_built"
      version = $Version
      tag_name = $TagName
      release_channel = "alpha"
      release_candidate_path = "public_release"
      zip_path = Split-Path -Leaf $ZipPath
      sha256_path = Split-Path -Leaf $Sha256Path
      release_notes_path = "RELEASE_NOTES.md"
      public_manifest_path = "public-manifest.yaml"
      release_checklist_path = "release-checklist.md"
      remote_url = ""
      commit_hash = ""
      publish_status = "not_published"
      human_approval_required = $false
      artifact_path = "release-record.json"
      next_skill = "human_confirm"
    }
  }
  Write-TaogeUtf8NoBomJson -Path (Join-Path $publicRoot "release-record.json") -Value $releaseRecord -Depth 5

  if (Test-Path -LiteralPath $ZipPath) {
    Remove-Item -LiteralPath $ZipPath -Force
  }
  Compress-Archive -Path (Join-Path $publicRoot "*") -DestinationPath $ZipPath -Force
  $hash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Set-Content -LiteralPath $Sha256Path -Value "$hash  $(Split-Path -Leaf $ZipPath)" -Encoding ASCII

  Write-Output "BUILD_PUBLIC_RELEASE_DONE"
  Write-Output "ZIP=$ZipPath"
  Write-Output "SHA256=$hash"
  exit 0
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
