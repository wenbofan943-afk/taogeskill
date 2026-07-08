param(
  [string]$ProjectRoot = "",
  [string]$PublicReleasePath = "",
  [string]$ZipPath = "",
  [string]$Sha256Path = ""
)

$ErrorActionPreference = "Stop"

try {
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
  }
  $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
  if ([string]::IsNullOrWhiteSpace($PublicReleasePath)) {
    $PublicReleasePath = Join-Path $ProjectRoot "releases\v0.1.0-alpha.2\public_release"
  }
  if ([string]::IsNullOrWhiteSpace($ZipPath)) {
    $ZipPath = Join-Path $ProjectRoot "releases\v0.1.0-alpha.2\taoge-creative-workflow-0.1.0-alpha.2-public-release.zip"
  }
  if ([string]::IsNullOrWhiteSpace($Sha256Path)) {
    $Sha256Path = "$ZipPath.sha256"
  }

  if (-not (Test-Path -LiteralPath $PublicReleasePath)) {
    New-Item -ItemType Directory -Force -Path $PublicReleasePath | Out-Null
  }
  $publicRoot = (Resolve-Path -LiteralPath $PublicReleasePath).Path
  if (-not $publicRoot.StartsWith($ProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "PublicReleasePath must stay inside ProjectRoot."
    exit 4
  }
  Get-ChildItem -LiteralPath $publicRoot -Force | Remove-Item -Recurse -Force

  $copyItems = @(
    "README.md", "AGENTS.md", "STATUS.md", "PROJECT_MAP.md", "CONTACT.md", "public-manifest.yaml", "VERSION", "LICENSE",
    "CONTRIBUTING.md", "SECURITY.md", "CODE_OF_CONDUCT.md", "release-checklist.md", "INSTALL.md", "UPDATE.md",
    "CHANGELOG.md", "NOTICE.md", "RELEASE_NOTES.md", "交接物字段词典.md",
    "tools\README.md", "tools\validate-public-release.ps1", "tools\validate-sample-run.ps1", "tools\build-public-release.ps1",
    "tools\validate-final-delivery-template.ps1", "tools\validate-field-schema.ps1", "tools\validate-workflow-replay.ps1",
    "tools\validate-regression-suite.ps1", "tools\validate-ci-workflow.ps1", "tools\validate-alpha-expression.ps1",
    "tools\validate-release-gate.ps1", "tools\export-support-log.ps1"
  )
  $copyDirs = @("docs", "skills", "templates", "examples", ".github")

  $replacements = [ordered]@{
    "D:\OpenClaw\workspace\涛哥创作工作流" = "PROJECT_ROOT"
    "D:/OpenClaw/workspace/涛哥创作工作流" = "PROJECT_ROOT"
    "D:\OpenClaw\workspace\AI工程驾驭系统" = "GLOBAL_AI_ENGINEERING_SYSTEM"
    "D:\OpenClaw\tools\PortableGit-2.55.0.2\cmd\git.exe" = "git"
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
    "D:\OpenClaw\" = "PROJECT_DRIVE/"
    "D:/OpenClaw/" = "PROJECT_DRIVE/"
    "C:\Users\" = "USER_HOME/"
    "file://" = "local-file-url-disabled://"
  }

  $textExt = @(".md", ".yaml", ".yml", ".json", ".txt", ".html", ".css", ".js", ".csv", ".ps1")
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
      Set-Content -LiteralPath $DestinationPath -Value $content -Encoding UTF8
    } else {
      Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
    }
  }

  foreach ($item in $copyItems) {
    $src = Join-Path $ProjectRoot $item
    if (Test-Path -LiteralPath $src) {
      Copy-SanitizedFile $src (Join-Path $publicRoot $item)
    }
  }

  foreach ($dir in $copyDirs) {
    $srcDir = Join-Path $ProjectRoot $dir
    if (Test-Path -LiteralPath $srcDir) {
      Get-ChildItem -LiteralPath $srcDir -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($srcDir.Length).TrimStart('\')
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
- 公开使用者只需要阅读本包内的 `README.md`、`AGENTS.md`、`PROJECT_MAP.md`、`skills/`、`docs/`、`templates/`、`tools/` 和 `examples/`。

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
    Set-Content -LiteralPath $publicReadme -Value $readme -Encoding UTF8
  }

  $publicState = Join-Path $publicRoot "工作流状态记录.md"
  @(
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
  ) | Set-Content -LiteralPath $publicState -Encoding UTF8

  $releaseRecord = [ordered]@{
    release_record = [ordered]@{
      release_id = "REL-" + (Get-Date -Format "yyyyMMdd-HHmmss")
      release_state = "github_release_published"
      version = "0.1.0-alpha.2"
      tag_name = "v0.1.0-alpha.2"
      release_channel = "alpha"
      release_candidate_path = "public_release"
      zip_path = Split-Path -Leaf $ZipPath
      sha256_path = Split-Path -Leaf $Sha256Path
      release_notes_path = "RELEASE_NOTES.md"
      public_manifest_path = "public-manifest.yaml"
      release_checklist_path = "release-checklist.md"
      remote_url = ""
      commit_hash = ""
      publish_status = "published_to_github"
      human_approval_required = $false
      artifact_path = "release-record.json"
      next_skill = "human_confirm"
    }
  }
  $releaseRecord | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $publicRoot "release-record.json") -Encoding UTF8

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
