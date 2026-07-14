param(
  [string]$ProjectRoot = "",
  [string]$PublicReleasePath = "",
  [string]$ZipPath = "",
  [string]$Sha256Path = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'EnvironmentPreflight.ps1')
. (Join-Path $PSScriptRoot 'ArchiveIntegrity.ps1')

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
  $sourceCommit = 'source_package_without_git_commit'
  $gitTopLevel = Get-TaogeGitTopLevelUtf8 -ProjectRoot $ProjectRoot
  $gitRootMatchesProjectRoot = $false
  if (-not [string]::IsNullOrWhiteSpace($gitTopLevel)) {
    try { $gitRootMatchesProjectRoot = [System.IO.Path]::GetFullPath($gitTopLevel).TrimEnd('\','/') -eq $ProjectRoot.TrimEnd('\','/') } catch {}
  }
  if ($gitRootMatchesProjectRoot) {
    & git -C $ProjectRoot diff --quiet --
    if ($LASTEXITCODE -ne 0) { throw 'git_worktree_has_unstaged_tracked_changes' }
    & git -C $ProjectRoot diff --cached --quiet --
    $indexHasStagedChanges = $LASTEXITCODE -ne 0
    $headCommit = [string](@(& git -C $ProjectRoot rev-parse HEAD)[0])
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($headCommit)) { throw 'git_head_commit_unavailable' }
    $sourceCommit = if ($indexHasStagedChanges) { 'git_index_pending_commit' } else { $headCommit.Trim() }
    $trackedSourcePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    @(Get-TaogeGitTrackedPathsUtf8 -ProjectRoot $ProjectRoot) | ForEach-Object {
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
    "tools\README.md", "tools\WindowsRuntimeHelper.ps1", "tools\EnvironmentPreflight.ps1", "tools\WindowsEnvironmentCertification.ps1", "tools\ArchiveIntegrity.ps1", "tools\invoke-environment-doctor.ps1", "tools\invoke-windows-certification-probe.ps1", "tools\validate-windows-certification.ps1", "tools\validate-environment-preflight.ps1", "tools\validate-archive-integrity.ps1", "tools\invoke-windows-clean-room-case.ps1", "tools\invoke-windows-clean-room-matrix.ps1", "tools\validate-windows-runtime-helper.ps1", "tools\validate-public-release.ps1", "tools\validate-sample-run.ps1", "tools\build-public-release.ps1",
    "tools\validate-final-delivery-template.ps1", "tools\validate-field-schema.ps1", "tools\YamlHelper.ps1", "tools\validate-workflow-replay.ps1",
    "tools\validate-regression-suite.ps1", "tools\validate-ci-workflow.ps1", "tools\validate-alpha-expression.ps1",
    "tools\validate-route-schema.ps1", "tools\validate-gates.ps1", "tools\validate-doc-governance.ps1", "tools\validate-public-entry-doc-review.ps1", "tools\validate-cover-composition.ps1", "tools\validate-r3-visual-text.ps1", "tools\R3VisualBudget.ps1", "tools\validate-r3-visual-budget.ps1", "tools\R3VisualNeed.ps1", "tools\validate-r3-visual-need.ps1", "tools\R6ContentEvidenceRuntime.ps1", "tools\invoke-r6-content-evidence.ps1", "tools\invoke-r6-source-capture.ps1", "tools\validate-r6-content-evidence.ps1", "tools\validate-r5-h1-account-visual-identity.ps1", "tools\validate-r5-h2-account-radar.ps1", "tools\validate-r5-h3-radar-objects.ps1", "tools\validate-r5-h4-feedback-ledger.ps1", "tools\validate-r5-h5-account-startup.ps1", "tools\validate-r5-h6-account-identity.ps1", "tools\AccountIdentityBinding.ps1", "tools\AccountStartupCheck.ps1", "tools\AccountStartupCheckV02.ps1", "tools\invoke-account-startup-check.ps1", "tools\invoke-account-startup-check-v0.2.ps1", "tools\new-account-identity-binding.ps1", "tools\validate-release-gate.ps1", "tools\export-support-log.ps1",
    "tools\invoke-workflow-runtime.ps1", "tools\P0ContractHelper.ps1", "tools\P0ContractV04.ps1", "tools\P0ContractV05.ps1", "tools\P0RuntimeV02.ps1", "tools\P0FinalDeliveryV03.ps1", "tools\P0FinalDeliveryV04.ps1", "tools\P0FinalDeliveryV05.ps1", "tools\P0EvidenceRuntime.ps1", "tools\R3VisualPresentation.ps1", "tools\R6ScriptVisualContract.ps1", "tools\R7ContractHelper.ps1", "tools\invoke-r6-script-visual-contract.ps1", "tools\validate-r6-script-visual-contract.ps1", "tools\validate-r7-h1-contracts.ps1", "tools\invoke-p0-evidence.ps1", "tools\validate-p0-h1-contracts.ps1", "tools\validate-p0-h2-runtime.ps1", "tools\validate-p0-h3-fixtures.ps1", "tools\validate-p0-h4-evidence.ps1", "tools\invoke-p0-h5-regression.ps1", "tools\validate-p0-h5-regression.ps1", "tools\validate-p0-h6-preflight.ps1", "tools\complete-p0-h6-regression.ps1", "tools\validate-p0-h6-regression.ps1", "tools\validate-p0-h6-reliability.ps1", "tools\prepare-p0-h7-delivery.ps1", "tools\complete-p0-h7-delivery.ps1", "tools\validate-p0-h7-delivery.ps1", "tools\validate-p0-h7-fixtures.ps1", "tools\validate-p0-h7-v04-delivery.ps1", "tools\validate-p0-h7-v04-fixtures.ps1", "tools\validate-p0-r6-v05-fixtures.ps1", "tools\validate-r3-visual-presentation.ps1",
    "tools\R7SemanticRuntime.ps1", "tools\R7CandidateRuntime.ps1", "tools\invoke-r7-semantic-workflow.ps1", "tools\validate-r7-h2-runtime.ps1", "tools\new-r7-semantic-submission.ps1", "tools\validate-r7-h3-producer-adapters.ps1", "tools\validate-r7-h4-candidate-runtime.ps1"
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
  } else {
    foreach ($dir in $copyDirs) {
      $sourceDirectory = Join-Path $ProjectRoot $dir
      if (-not (Test-Path -LiteralPath $sourceDirectory -PathType Container)) { continue }
      foreach ($sourceFile in @(Get-ChildItem -LiteralPath $sourceDirectory -Recurse -File -Force)) {
        $relativeWithinDirectory = $sourceFile.FullName.Substring($sourceDirectory.Length).TrimStart('\')
        if ($dir -eq 'state' -and $relativeWithinDirectory.StartsWith('checks\', [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        [void]$candidateRelativePaths.Add(((Join-Path $dir $relativeWithinDirectory) -replace '\\','/'))
      }
    }
  }
  foreach ($generatedPath in @('工作流状态记录.md','release-record.json','archive-manifest.json')) { [void]$candidateRelativePaths.Add($generatedPath) }
  $estimatedSourceBytes = [long]0
  foreach ($relativePath in $candidateRelativePaths) {
    $sourceFullPath = Join-Path $ProjectRoot ($relativePath -replace '/', '\')
    if (Test-Path -LiteralPath $sourceFullPath -PathType Leaf) { $estimatedSourceBytes += [long](Get-Item -LiteralPath $sourceFullPath).Length }
  }
  $requiredFreeBytes = [long](67108864 + ($estimatedSourceBytes * 3))
  $archiveVerificationRoot = Join-Path $releaseBase ('.v-' + [guid]::NewGuid().ToString('N').Substring(0,4))
  $environmentPreflight = Invoke-TaogeEnvironmentPreflight -ProjectRoot $ProjectRoot -AllowedRoot $releaseBase -TargetRoot $publicRoot -RelativePaths ([string[]]@($candidateRelativePaths)) -RequiredFreeBytes $requiredFreeBytes -ProbeWrite
  $archiveVerificationBudget = Test-TaogePathBudget -InstallationRoot $ProjectRoot -TargetRoot $archiveVerificationRoot -RelativePaths ([string[]]@($candidateRelativePaths))
  $zipContainment = Resolve-TaogeContainedPath -AllowedRoot $releaseBase -CandidatePath $ZipPath -RejectReparsePoints
  $shaContainment = Resolve-TaogeContainedPath -AllowedRoot $releaseBase -CandidatePath $Sha256Path -RejectReparsePoints
  $verificationContainment = Resolve-TaogeContainedPath -AllowedRoot $releaseBase -CandidatePath $archiveVerificationRoot -RejectReparsePoints
  if ($environmentPreflight.status -ne 'pass' -or $archiveVerificationBudget.status -ne 'pass' -or $zipContainment.status -ne 'pass' -or $shaContainment.status -ne 'pass' -or $verificationContainment.status -ne 'pass') {
    $preflightErrors = @($environmentPreflight.failure_categories) + @($zipContainment.errors) + @($shaContainment.errors)
    if ($archiveVerificationBudget.status -ne 'pass') { $preflightErrors += 'archive_verification_path_budget' }
    $preflightErrors += @($verificationContainment.errors)
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
      if ($ext -eq '.ps1') {
        Write-TaogeUtf8BomText -Path $DestinationPath -Text $content -EnsureFinalNewline
      } else {
        Write-TaogeUtf8NoBomText -Path $DestinationPath -Text $content -EnsureFinalNewline
      }
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

  $requiredCurrentRuntimeClosure = @(
    'tools\P0ContractV05.ps1',
    'tools\P0FinalDeliveryV05.ps1',
    'tools\R6ScriptVisualContract.ps1',
    'tools\invoke-r6-script-visual-contract.ps1',
    'tools\validate-r6-script-visual-contract.ps1',
    'tools\validate-p0-r6-v05-fixtures.ps1',
    'templates\schema\r6\content-brief.v0.3.schema.json',
    'templates\schema\r6\draft.v0.3.schema.json',
    'templates\schema\p0\session-execution-plan.v0.5.schema.json',
    'templates\schema\p0\typed-render-input.v0.5.schema.json',
    'templates\schema\p0\compatibility-matrix.v0.5.json',
    'templates\final-delivery\final-delivery.v0.5.template.html',
    'examples\r6-script-visual-fixtures\base-direct.json',
    'examples\p0-runtime-v0.5-fixture\deliverables\p0\final-delivery-render-candidate.json'
  )
  $missingRuntimeClosure = @($requiredCurrentRuntimeClosure | Where-Object { -not (Test-Path -LiteralPath (Join-Path $publicRoot $_) -PathType Leaf) })
  if ($missingRuntimeClosure.Count -gt 0) {
    throw ('public_runtime_dependency_closure_missing:' + [string]::Join(',', $missingRuntimeClosure))
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

  $publicManifest = Join-Path $publicRoot 'public-manifest.yaml'
  if (Test-Path -LiteralPath $publicManifest) {
    $manifestText = Get-Content -LiteralPath $publicManifest -Raw -Encoding UTF8
    $manifestText = [regex]::Replace($manifestText,'(?m)^source_commit:\s*.*$',("source_commit: " + $sourceCommit))
    Write-TaogeUtf8NoBomText -Path $publicManifest -Text $manifestText -EnsureFinalNewline
  }
  $publicChecklist = Join-Path $publicRoot 'release-checklist.md'
  if (Test-Path -LiteralPath $publicChecklist) {
    $checklistText = Get-Content -LiteralPath $publicChecklist -Raw -Encoding UTF8
    $checklistText = [regex]::Replace($checklistText,'(?m)^source_commit:\s*.*$',("source_commit: " + $sourceCommit))
    Write-TaogeUtf8NoBomText -Path $publicChecklist -Text $checklistText -EnsureFinalNewline
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
      commit_hash = $sourceCommit
      publish_status = "not_published"
      human_approval_required = $false
      artifact_path = "release-record.json"
      next_skill = "human_confirm"
    }
  }
  Write-TaogeUtf8NoBomJson -Path (Join-Path $publicRoot "release-record.json") -Value $releaseRecord -Depth 5

  $requiredArchivePaths = @(
    'README.md','AGENTS.md','PROJECT_MAP.md','VERSION','LICENSE','public-manifest.yaml',
    'release-checklist.md','release-record.json','tools/ArchiveIntegrity.ps1','tools/validate-archive-integrity.ps1'
  )
  $archiveResult = New-TaogeVerifiedArchive -SourceRoot $publicRoot -ArchivePath $ZipPath -ArchiveKind 'public_release' -RequiredPaths $requiredArchivePaths -VerificationRoot $archiveVerificationRoot
  $hash = $archiveResult.archive_sha256
  Write-TaogeUtf8NoBomText -Path $Sha256Path -Text "$hash  $(Split-Path -Leaf $ZipPath)" -EnsureFinalNewline

  Write-Output "BUILD_PUBLIC_RELEASE_DONE"
  Write-Output "ZIP=$ZipPath"
  Write-Output "SHA256=$hash"
  Write-Output "ARCHIVE_MANIFEST=$(Join-Path $publicRoot 'archive-manifest.json')"
  Write-Output "ARCHIVE_FILE_COUNT=$($archiveResult.file_count)"
  exit 0
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
