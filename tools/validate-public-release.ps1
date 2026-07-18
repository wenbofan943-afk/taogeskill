param(
  [string]$TargetPath = "",
  [string]$HumanReportPath = "",
  [string]$MachineReportPath = "",
  [string]$ZipPath = "",
  [string]$Sha256Path = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'ArchiveIntegrity.ps1')

$validationSandbox = ''
$inputTarget = ''
$payloadIntegrity = $null

function New-CheckItem {
  param(
    [string]$Id,
    [string]$Group,
    [string]$Severity,
    [string]$Status,
    [string[]]$EvidencePaths = @(),
    [string]$Summary = "",
    [string[]]$Remediation = @(),
    [string]$OwnerArea = ""
  )
  [pscustomobject]@{
    check_item_id = $Id
    group = $Group
    severity = $Severity
    status = $Status
    evidence_paths = $EvidencePaths
    evidence_summary = $Summary
    remediation_items = $Remediation
    owner_area = $OwnerArea
  }
}

function Get-RelativePathSafe {
  param([string]$BasePath, [string]$Path)
  $base = (Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\') + '\'
  $full = (Resolve-Path -LiteralPath $Path).Path
  if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $full.Substring($base.Length)
  }
  return $full
}

function Get-PublicCandidateFiles {
  param([string]$RootPath)
  $files = New-Object System.Collections.Generic.List[object]
  Get-ChildItem -LiteralPath $RootPath -Force -File -ErrorAction Stop | ForEach-Object { $files.Add($_) }
  foreach ($directoryName in @('docs', 'routes', 'compatibility', 'skills', 'templates', 'examples', 'tools', '.github')) {
    $directoryPath = Join-Path $RootPath $directoryName
    if (Test-Path -LiteralPath $directoryPath -PathType Container) {
      Get-ChildItem -LiteralPath $directoryPath -Recurse -File -ErrorAction Stop | ForEach-Object { $files.Add($_) }
    }
  }
  return @($files.ToArray())
}

function Test-MarkdownLinks {
  param([string]$RootPath)
  $broken = New-Object System.Collections.Generic.List[string]
  Get-PublicCandidateFiles $RootPath | Where-Object { $_.Extension -ieq '.md' } | ForEach-Object {
    $file = $_
    $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    $matches = [regex]::Matches($text, '\[[^\]]+\]\(([^)]+)\)')
    foreach ($match in $matches) {
      $target = $match.Groups[1].Value.Trim()
      if ($target -match '^(https?:|mailto:|#)') { continue }
      if ($target.StartsWith('<') -and $target.EndsWith('>')) {
        $target = $target.Substring(1, $target.Length - 2)
      }
      $target = ($target -split '#')[0]
      if ([string]::IsNullOrWhiteSpace($target)) { continue }
      if ($target -match '^[a-zA-Z]+:') { continue }
      $decoded = [uri]::UnescapeDataString($target)
      $full = Join-Path (Split-Path -Parent $file.FullName) $decoded
      if (-not (Test-Path -LiteralPath $full)) {
        $broken.Add(("{0} -> {1}" -f (Get-RelativePathSafe $RootPath $file.FullName), $target))
      }
    }
  }
  return $broken
}

function Get-CandidateMetadataField {
  param(
    [string]$Text,
    [string]$FieldName
  )
  $match = [regex]::Match($Text, ('(?m)^[ \t]*' + [regex]::Escape($FieldName) + '[ \t]*:[ \t]*([^\r\n]*?)[ \t]*\r?$'))
  if (-not $match.Success) { return '' }
  $value = $match.Groups[1].Value.Trim()
  if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
    return $value.Substring(1, $value.Length - 2)
  }
  return $value
}

try {
  if ([string]::IsNullOrWhiteSpace($TargetPath)) {
    $currentVersion = (Get-Content -LiteralPath 'VERSION' -Raw -Encoding UTF8).Trim()
    $versionedPublicReleasePath = "releases\v$currentVersion\public_release"
    if (Test-Path -LiteralPath $versionedPublicReleasePath) {
      $TargetPath = $versionedPublicReleasePath
    } elseif (Test-Path -LiteralPath "public_release") {
      $TargetPath = "public_release"
    } else {
      $TargetPath = "."
    }
  }
  if (-not (Test-Path -LiteralPath $TargetPath)) {
    Write-Error "TargetPath not found: $TargetPath"
    exit 2
  }

  $inputTarget = (Resolve-Path -LiteralPath $TargetPath).Path
  $target = $inputTarget
  $defaultReportRoot = $target
  if ((Split-Path -Leaf $target) -eq 'public_release') {
    $defaultReportRoot = Split-Path -Parent $target
  } elseif (Test-Path -LiteralPath (Join-Path $target 'state\checks') -PathType Container) {
    $defaultReportRoot = Join-Path $target 'state\checks'
  }
  if ([string]::IsNullOrWhiteSpace($HumanReportPath)) {
    $HumanReportPath = Join-Path $defaultReportRoot "release-check-report.md"
  }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
    $MachineReportPath = Join-Path $defaultReportRoot "release-check-report.json"
  }
  # Nested validators must never write reports into the checked public payload.
  # Keep their dynamic evidence beside the parent report instead.
  $checkerReportRoot = Join-Path $defaultReportRoot 'checker-reports'
  $HumanReportPath = [System.IO.Path]::GetFullPath($HumanReportPath)
  $MachineReportPath = [System.IO.Path]::GetFullPath($MachineReportPath)
  foreach ($reportPath in @($HumanReportPath, $MachineReportPath)) {
    $reportParent = Split-Path -Parent $reportPath
    if (-not (Test-Path -LiteralPath $reportParent)) { New-Item -ItemType Directory -Force -Path $reportParent | Out-Null }
  }

  $archiveManifestPath = Join-Path $inputTarget 'archive-manifest.json'
  if (Test-Path -LiteralPath $archiveManifestPath -PathType Leaf) {
    $payloadIntegrity = Test-TaogeArchivePayload -PayloadRoot $inputTarget -ManifestPath $archiveManifestPath
    $sandboxBase = if ((Split-Path -Leaf $inputTarget) -eq 'public_release') { Split-Path -Parent $inputTarget } else { [System.IO.Path]::GetTempPath() }
    $validationSandbox = Join-Path $sandboxBase ('.v' + [guid]::NewGuid().ToString('N').Substring(0,4))
    New-Item -ItemType Directory -Force -Path $validationSandbox | Out-Null
    Get-ChildItem -LiteralPath $inputTarget -Force | Copy-Item -Destination $validationSandbox -Recurse -Force
    $target = (Resolve-Path -LiteralPath $validationSandbox).Path
  }

  $checkRunId = "CHECKRUN-" + (Get-Date -Format "yyyyMMdd-HHmmss")
  $items = New-Object System.Collections.Generic.List[object]

  if ($null -ne $payloadIntegrity) {
    $payloadStatus = if ($payloadIntegrity.status -eq 'pass') { 'pass' } else { 'fail' }
    $payloadEvidence = @($payloadIntegrity.errors)
    $items.Add((New-CheckItem "P3REL-030" "release_package" "blocker" $payloadStatus $payloadEvidence "The unpacked candidate must exactly match archive-manifest.json before checkers run." @("Rebuild the candidate; never write checker reports or fixture outputs into public_release/.") "release"))
  }

  $required = @(
    "README.md", "AGENTS.md", "PROJECT_MAP.md", "public-manifest.yaml", "VERSION",
    "LICENSE", "CONTRIBUTING.md", "CHANGELOG.md", "SECURITY.md", "CODE_OF_CONDUCT.md",
    "INSTALL.md", "UPDATE.md", "RELEASE_NOTES.md", "NOTICE.md", "release-checklist.md", "release-record.json"
  )
  $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $target $_)) })
  $items.Add((New-CheckItem "P3REL-001" "release_package" "blocker" ($(if ($missing.Count) { "fail" } else { "pass" })) @($missing) "Required public release entry files." @("Add missing required public release files.") "release"))

  $closureEvidence = New-Object System.Collections.Generic.List[string]
  $currentRuntimeClosure = @()
  $publicBuildClosurePath = Join-Path $target 'routes\public-build-closure.json'
  if (Test-Path -LiteralPath $publicBuildClosurePath -PathType Leaf) {
    try {
      $publicBuildClosure = Get-Content -LiteralPath $publicBuildClosurePath -Raw -Encoding UTF8 | ConvertFrom-Json
      if (
        [string]$publicBuildClosure.schema_id -ne 'taoge://public-build/closure/v0.1' -or
        [string]$publicBuildClosure.schema_version -ne '0.1' -or
        [string]$publicBuildClosure.status -ne 'current' -or
        [string]$publicBuildClosure.path_format -ne 'project_relative_forward_slash'
      ) {
        $closureEvidence.Add('public_build_closure_contract_invalid')
      }
      $currentRuntimeClosure = @($publicBuildClosure.required_paths | ForEach-Object { [string]$_ })
      $invalidClosurePaths = @($currentRuntimeClosure | Where-Object {
        [string]::IsNullOrWhiteSpace($_) -or
        [System.IO.Path]::IsPathRooted($_) -or
        $_.Contains('\') -or
        $_ -match '(^|/)\.\.(/|$)'
      })
      $duplicateClosurePaths = @($currentRuntimeClosure | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
      foreach ($invalidClosurePath in $invalidClosurePaths) { $closureEvidence.Add('closure_path_invalid:' + $invalidClosurePath) }
      foreach ($duplicateClosurePath in $duplicateClosurePaths) { $closureEvidence.Add('closure_path_duplicate:' + $duplicateClosurePath) }
      foreach ($requiredClosureSentinel in @(
        'routes/public-build-closure.json',
        'routes/compatibility-catalog.json',
        'compatibility/legacy-r7/templates/schema/p0/session-execution-plan.v0.2.schema.json',
        'tools/WorkflowKernelSessionEntry.ps1'
      )) {
        if ($currentRuntimeClosure -notcontains $requiredClosureSentinel) { $closureEvidence.Add('closure_required_entry_missing:' + $requiredClosureSentinel) }
      }
    } catch {
      $closureEvidence.Add('public_build_closure_invalid_json:' + $_.Exception.Message)
    }
  } else {
    $closureEvidence.Add('routes/public-build-closure.json')
  }
  $missingCurrentRuntime = @($currentRuntimeClosure | Where-Object { -not (Test-Path -LiteralPath (Join-Path $target ($_ -replace '/', '\')) -PathType Leaf) })
  foreach ($missingCurrentRuntimePath in $missingCurrentRuntime) { $closureEvidence.Add('closure_file_missing:' + $missingCurrentRuntimePath) }
  $items.Add((New-CheckItem "P3REL-042" "current_runtime_dependency_closure" "blocker" ($(if ($closureEvidence.Count) { "fail" } else { "pass" })) @($closureEvidence) "The public package must contain the single machine-readable runtime, checker, and compatibility closure consumed by both builder and validator." @("Repair routes/public-build-closure.json or the candidate copy; do not maintain a second validator-only list.") "release"))

  $accountsPath = Join-Path $target "accounts"
  $items.Add((New-CheckItem "P3REL-002" "privacy_security" "blocker" ($(if (Test-Path -LiteralPath $accountsPath) { "fail" } else { "pass" })) @("accounts") "Public package must not contain real accounts directory." @("Remove accounts/ from public_release and use examples/sample-account instead.") "privacy"))

  $textFiles = Get-PublicCandidateFiles $target | Where-Object {
    (@(".md", ".txt", ".yaml", ".yml", ".json", ".html", ".css", ".js", ".csv") -contains $_.Extension.ToLowerInvariant()) -and
    ($_.Name -notin @("release-check-report.md", "release-check-report.json"))
  }
  $textJoined = ""
  foreach ($file in $textFiles) {
    $textJoined += "`n" + (Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8)
  }

  $taogePrefix = ([string][char]28059) + ([string][char]21733)
  $privateSessionPrefix = 'S' + '20260706' + '-00'
  $privateSessionOne = 'S' + '20260707' + '-001'
  $privatePromptSourceSession = 'S' + '20260711' + '-001'
  $privateRegressionSession = 'S' + '20260711' + '-002'
  $privateH6Session = 'PRIVATE-' + 'H6-H7-REGRESSION'
  $privateH7Revision = 'DREV-' + 'PRIVATE-H6-H7-002'
  $localDrive = 'D:' + '\OpenClaw'
  $localDriveSlash = 'D:' + '/OpenClaw'
  $userHome = 'C:' + '\Users'
  $fileUrl = 'file' + '://'
  $privatePatterns = @(
    $taogePrefix + "行业观察", $taogePrefix + "帮提车", $taogePrefix + "本地经营者自媒", $taogePrefix + "说真话",
    $privateSessionPrefix, $privateSessionOne, $privatePromptSourceSession, $privateRegressionSession, $privateH6Session, $privateH7Revision, $localDrive, $localDriveSlash, $userHome, $fileUrl
  )
  $realSessionShapePattern = '(?<![A-Za-z0-9])S20\d{6}-\d{3}(?![A-Za-z0-9])'
  $realSessionShapeHits = New-Object System.Collections.Generic.List[string]
  foreach ($file in $textFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    $matches = @([regex]::Matches($content, $realSessionShapePattern) | ForEach-Object { $_.Value } | Select-Object -Unique)
    foreach ($match in $matches) {
      $realSessionShapeHits.Add(('{0}::{1}' -f (Get-RelativePathSafe $target $file.FullName), $match))
    }
  }
  $privateHits = @($privatePatterns | Where-Object { $textJoined.Contains($_) }) + @($realSessionShapeHits.ToArray())
  $items.Add((New-CheckItem "P3REL-003" "privacy_security" "blocker" ($(if ($privateHits.Count) { "fail" } else { "pass" })) $privateHits "No real account names, original session ids, local paths, or file URLs." @("Sanitize public_release text and replace real data with sample placeholders.") "privacy"))

  $privateShapeProbe = 'S' + '20260714' + '-004'
  $sessionShapeSelfTest = ($privateShapeProbe -match $realSessionShapePattern) -and (('EVT-' + $privateShapeProbe + '-002') -match $realSessionShapePattern) -and ('SAMPLE-R7-H5A-001' -notmatch $realSessionShapePattern) -and ('SR1R4DR-001' -notmatch $realSessionShapePattern)
  $items.Add((New-CheckItem "P3REL-057" "privacy_security" "blocker" ($(if ($sessionShapeSelfTest) { "pass" } else { "fail" })) @('date-shaped private session id negative fixture') "The privacy gate must reject real date-shaped session identifiers even when embedded in plan, event, or operation IDs." @("Restore the generic real-session identifier regex and keep public examples on SAMPLE-prefixed identifiers.") "privacy"))

  $secretRegex = @'
(?i)(api[_-]?key|secret|token|cookie|password)\s*[:=]\s*["']?[A-Za-z0-9_\-]{12,}|BEGIN (RSA|OPENSSH|PRIVATE) KEY|(^|[\\/])\.env($|[\\/])
'@
  $secretHits = New-Object System.Collections.Generic.List[string]
  foreach ($file in $textFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    if ($content -match $secretRegex) {
      $secretHits.Add((Get-RelativePathSafe $target $file.FullName))
    }
  }
  $items.Add((New-CheckItem "P3REL-004" "privacy_security" "blocker" ($(if ($secretHits.Count) { "fail" } else { "pass" })) @($secretHits) "No credential-looking assignments or private keys." @("Remove secrets or move examples to placeholder text.") "security"))

  $brokenLinks = @(Test-MarkdownLinks $target)
  $items.Add((New-CheckItem "P3REL-005" "link_check" "blocker" ($(if ($brokenLinks.Count) { "fail" } else { "pass" })) $brokenLinks "Markdown relative links must resolve inside public package." @("Fix broken relative links or remove links to excluded local-only files.") "docs"))

  $fieldNeedles = @("entry_router_request", "safe_start_mode", "release_check_report", "sample_check_report", "workflow_replay_report", "regression_suite_report", "exit_code", "machine_readable_report_path")
  $missingFields = @($fieldNeedles | Where-Object { -not $textJoined.Contains($_) })
  $items.Add((New-CheckItem "P3REL-006" "field_gate" "blocker" ($(if ($missingFields.Count) { "fail" } else { "pass" })) $missingFields "P2/P3 public fields must be visible in public package." @("Sync field dictionary, router contract, checker templates, and README into public_release.") "fields"))

  $schemaScriptPath = Join-Path $target "tools\validate-field-schema.ps1"
  $schemaPath = Join-Path $target "templates\schema\field-schema.v0.1.json"
  $schemaEvidence = @()
  $schemaStatus = "pass"
  if ((Test-Path -LiteralPath $schemaScriptPath) -and (Test-Path -LiteralPath $schemaPath)) {
    & $schemaScriptPath -TargetPath $target -SchemaPath $schemaPath -HumanReportPath (Join-Path $checkerReportRoot "field-schema-check-report.md") -MachineReportPath (Join-Path $checkerReportRoot "field-schema-check-report.json") | Out-Null
    if (-not $?) {
      $schemaStatus = "fail"
      $schemaEvidence = @("field-schema-check-report.md")
    }
  } else {
    $schemaStatus = "fail"
    $schemaEvidence = @("tools\validate-field-schema.ps1", "templates\schema\field-schema.v0.1.json")
  }
  $items.Add((New-CheckItem "P3REL-008" "field_gate" "blocker" $schemaStatus $schemaEvidence "P1-P5 minimal field schema must pass." @("Run tools/validate-field-schema.ps1 and fix schema blockers.") "fields"))

  $regressionScriptPath = Join-Path $target "tools\validate-regression-suite.ps1"
  $regressionSuitePath = Join-Path $target "examples\regression-suite.yaml"
  $regressionEvidence = @()
  $regressionStatus = "pass"
  if ((Test-Path -LiteralPath $regressionScriptPath) -and (Test-Path -LiteralPath $regressionSuitePath)) {
    & $regressionScriptPath -SuitePath "examples\regression-suite.yaml" -HumanReportPath (Join-Path $checkerReportRoot "regression-suite-report.md") -MachineReportPath (Join-Path $checkerReportRoot "regression-suite-report.json") | Out-Null
    if (-not $?) {
      $regressionStatus = "fail"
      $regressionEvidence = @("examples\regression-suite-report.md")
    }
  } else {
    $regressionStatus = "fail"
    $regressionEvidence = @("tools\validate-regression-suite.ps1", "examples\regression-suite.yaml")
  }
  $items.Add((New-CheckItem "P3REL-009" "regression_suite" "blocker" $regressionStatus $regressionEvidence "Sample regression suite must pass before public release candidate is trusted." @("Run tools/validate-regression-suite.ps1 and fix blockers.") "examples"))

  $ciScriptPath = Join-Path $target "tools\validate-ci-workflow.ps1"
  $ciWorkflowPath = Join-Path $target ".github\workflows\public-release-candidate-check.yml"
  $ciEvidence = @()
  $ciStatus = "pass"
  if ((Test-Path -LiteralPath $ciScriptPath) -and (Test-Path -LiteralPath $ciWorkflowPath)) {
    & $ciScriptPath -WorkflowPath ".github\workflows\public-release-candidate-check.yml" -HumanReportPath (Join-Path $checkerReportRoot "ci-workflow-check-report.md") -MachineReportPath (Join-Path $checkerReportRoot "ci-workflow-check-report.json") | Out-Null
    if (-not $?) {
      $ciStatus = "fail"
      $ciEvidence = @("ci-workflow-check-report.md")
    }
  } else {
    $ciStatus = "fail"
    $ciEvidence = @("tools\validate-ci-workflow.ps1", ".github\workflows\public-release-candidate-check.yml")
  }
  $items.Add((New-CheckItem "P3REL-010" "ci_workflow" "blocker" $ciStatus $ciEvidence "CI workflow must be validation-only and locally checkable." @("Run tools/validate-ci-workflow.ps1 and remove publish/tag/push behavior.") "ci"))

  $alphaScriptPath = Join-Path $target "tools\validate-alpha-expression.ps1"
  $alphaEvidence = @()
  $alphaStatus = "pass"
  if (Test-Path -LiteralPath $alphaScriptPath) {
    & $alphaScriptPath -TargetPath $target -HumanReportPath (Join-Path $checkerReportRoot "alpha-expression-check-report.md") -MachineReportPath (Join-Path $checkerReportRoot "alpha-expression-check-report.json") | Out-Null
    if (-not $?) {
      $alphaStatus = "fail"
      $alphaEvidence = @("alpha-expression-check-report.md")
    }
  } else {
    $alphaStatus = "fail"
    $alphaEvidence = @("tools\validate-alpha-expression.ps1")
  }
  $items.Add((New-CheckItem "P3REL-011" "alpha_expression" "blocker" $alphaStatus $alphaEvidence "Alpha candidate boundaries must be visible before public release." @("Run tools/validate-alpha-expression.ps1 and add first-screen alpha wording.") "docs"))

  $routeScriptPath = Join-Path $target "tools\validate-route-schema.ps1"
  $routeEvidence = @()
  $routeStatus = "pass"
  if (Test-Path -LiteralPath $routeScriptPath) {
    & $routeScriptPath -ProjectRoot $target -HumanReportPath (Join-Path $checkerReportRoot "route-schema-check-report.md") -MachineReportPath (Join-Path $checkerReportRoot "route-schema-check-report.json") | Out-Null
    if (-not $?) {
      $routeStatus = "fail"
      $routeEvidence = @("state\checks\route-schema-check-report.md")
    }
  } else {
    $routeStatus = "fail"
    $routeEvidence = @("tools\validate-route-schema.ps1")
  }
  $items.Add((New-CheckItem "P3REL-012" "route_schema" "blocker" $routeStatus $routeEvidence "Workflow routes must include after_completion guidance before public release." @("Run tools/validate-route-schema.ps1 and fix route after_completion blockers.") "orchestration"))

  $coverScriptPath = Join-Path $target "tools\validate-cover-composition.ps1"
  $coverSamplePath = Join-Path $target "docs\tutorials\r3-dry-run-sample\accounts\sample-account\runs\SR3DR-001"
  $coverEvidence = @()
  $coverStatus = "pass"
  if ((Test-Path -LiteralPath $coverScriptPath) -and (Test-Path -LiteralPath $coverSamplePath)) {
    & $coverScriptPath -TargetPath $coverSamplePath | Out-Null
    if (-not $?) {
      $coverStatus = "fail"
      $coverEvidence = @("docs\tutorials\r3-dry-run-sample\accounts\sample-account\runs\SR3DR-001")
    }
  } else {
    $coverStatus = "fail"
    $coverEvidence = @("tools\validate-cover-composition.ps1", "docs\tutorials\r3-dry-run-sample")
  }
  $items.Add((New-CheckItem "P3REL-013" "cover_composition" "blocker" $coverStatus $coverEvidence "Cover composition sample must preserve asset roles, cover review, and prompt-only honesty." @("Run tools/validate-cover-composition.ps1 and fix R3 cover blockers.") "r3"))

  $visualTextScriptPath = Join-Path $target "tools\validate-r3-visual-text.ps1"
  $visualTextFixturePath = Join-Path $target "examples\r3-visual-text-fixtures\fixtures.json"
  $visualTextEvidence = @()
  $visualTextStatus = "pass"
  if ((Test-Path -LiteralPath $visualTextScriptPath) -and (Test-Path -LiteralPath $visualTextFixturePath)) {
    & $visualTextScriptPath -FixturePath $visualTextFixturePath -HumanReportPath (Join-Path $checkerReportRoot "r3-visual-text-check-report.md") -MachineReportPath (Join-Path $checkerReportRoot "r3-visual-text-check-report.json") | Out-Null
    if (-not $?) {
      $visualTextStatus = "fail"
      $visualTextEvidence = @("state\checks\r3-visual-text-check-report.md")
    }
  } else {
    $visualTextStatus = "fail"
    $visualTextEvidence = @("tools\validate-r3-visual-text.ps1", "examples\r3-visual-text-fixtures\fixtures.json")
  }
  $items.Add((New-CheckItem "P3REL-014" "r3_visual_text" "blocker" $visualTextStatus $visualTextEvidence "R3 visual text decisions, source binding, fallback, and title-only cover semantics must pass redacted fixtures." @("Run tools/validate-r3-visual-text.ps1 and fix R3 visual-text blockers.") "r3"))

  $p0H1ScriptPath = Join-Path $target "tools\validate-p0-h1-contracts.ps1"
  $p0H1HelperPath = Join-Path $target "tools\P0ContractHelper.ps1"
  $p0H1FixturePath = Join-Path $target "examples\p0-h1-contract-fixtures\fixtures.json"
  $p0H1SchemaPath = Join-Path $target "templates\schema\p0"
  $p0H1Evidence = @()
  $p0H1Status = "pass"
  if ((Test-Path -LiteralPath $p0H1ScriptPath) -and (Test-Path -LiteralPath $p0H1HelperPath) -and (Test-Path -LiteralPath $p0H1FixturePath) -and (Test-Path -LiteralPath $p0H1SchemaPath)) {
    & $p0H1ScriptPath -FixtureRoot $p0H1FixturePath.Replace('fixtures.json','') -SchemaRoot $p0H1SchemaPath -LegacyPlanSchemaPath (Join-Path $target 'templates\schema\p0-runtime.v0.1.json') -CompatibilityMatrixPath (Join-Path $p0H1SchemaPath 'compatibility-matrix.v0.5.json') -HumanReportPath (Join-Path $checkerReportRoot 'p0-h1-contract-check-report.md') -MachineReportPath (Join-Path $checkerReportRoot 'p0-h1-contract-check-report.json') | Out-Null
    if (-not $?) {
      $p0H1Status = "fail"
      $p0H1Evidence = @("state\checks\p0-h1-contract-check-report.md")
    }
  } else {
    $p0H1Status = "fail"
    $p0H1Evidence = @("tools\validate-p0-h1-contracts.ps1", "tools\P0ContractHelper.ps1", "templates\schema\p0", "examples\p0-h1-contract-fixtures\fixtures.json")
  }
  $items.Add((New-CheckItem "P3REL-015" "p0_h1_contracts" "blocker" $p0H1Status $p0H1Evidence "P0-H1 versioned contracts and positive/negative fixtures must pass in the public package." @("Run tools/validate-p0-h1-contracts.ps1 and fix P0-H1 contract blockers.") "p0"))

  $p0H2ScriptPath = Join-Path $target "tools\validate-p0-h2-runtime.ps1"
  $p0H2RuntimePath = Join-Path $target "tools\P0RuntimeV02.ps1"
  $p0H2FixturePath = Join-Path $target "examples\p0-runtime-v0.2-fixture"
  $p0H2ReceiptSchemaPath = Join-Path $target "templates\schema\p0-h2\render-receipt.v0.2.schema.json"
  $p0H2Evidence = @()
  $p0H2Status = "pass"
  if ((Test-Path -LiteralPath $p0H2ScriptPath) -and (Test-Path -LiteralPath $p0H2RuntimePath) -and (Test-Path -LiteralPath $p0H2FixturePath) -and (Test-Path -LiteralPath $p0H2ReceiptSchemaPath)) {
    & $p0H2ScriptPath -ReportPath (Join-Path $checkerReportRoot 'p0-h2-runtime-report.json') | Out-Null
    if (-not $?) {
      $p0H2Status = "fail"
      $p0H2Evidence = @("state\checks\p0-h2-runtime-report.json")
    }
  } else {
    $p0H2Status = "fail"
    $p0H2Evidence = @("tools\validate-p0-h2-runtime.ps1", "tools\P0RuntimeV02.ps1", "examples\p0-runtime-v0.2-fixture", "templates\schema\p0-h2\render-receipt.v0.2.schema.json")
  }
  $items.Add((New-CheckItem "P3REL-016" "p0_h2_runtime" "blocker" $p0H2Status $p0H2Evidence "P0-H2 typed compiler, deterministic renderer, receipt, idempotency, and legacy compatibility must pass in the public package." @("Run tools/validate-p0-h2-runtime.ps1 and fix P0-H2 runtime blockers.") "p0"))

  $p0H3ScriptPath = Join-Path $target "tools\validate-p0-h3-fixtures.ps1"
  $p0H3FixturePath = Join-Path $target "examples\p0-h3-recovery-fixtures"
  $p0H3SchemaPath = Join-Path $target "templates\schema\p0-h3\fixture-result.v0.2.schema.json"
  $p0H3Evidence = @()
  $p0H3Status = "pass"
  if ((Test-Path -LiteralPath $p0H3ScriptPath) -and (Test-Path -LiteralPath (Join-Path $p0H3FixturePath 'fixtures.json')) -and (Test-Path -LiteralPath $p0H3SchemaPath)) {
    & $p0H3ScriptPath -FixtureRoot $p0H3FixturePath -ReportPath (Join-Path $checkerReportRoot 'p0-h3-fixture-report.json') | Out-Null
    if (-not $?) {
      $p0H3Status = "fail"
      $p0H3Evidence = @("state\checks\p0-h3-fixture-report.json")
    }
  } else {
    $p0H3Status = "fail"
    $p0H3Evidence = @("tools\validate-p0-h3-fixtures.ps1", "examples\p0-h3-recovery-fixtures\fixtures.json", "templates\schema\p0-h3\fixture-result.v0.2.schema.json")
  }
  $items.Add((New-CheckItem "P3REL-017" "p0_h3_failure_recovery" "blocker" $p0H3Status $p0H3Evidence "P0-H3 F03-F19 independent failure and recovery fixtures must pass with the unified result contract." @("Run tools/validate-p0-h3-fixtures.ps1 and fix P0-H3 fixture blockers.") "p0"))

  $p0H4ScriptPath = Join-Path $target "tools\validate-p0-h4-evidence.ps1"
  $p0H4RuntimePath = Join-Path $target "tools\P0EvidenceRuntime.ps1"
  $p0H4CommandPath = Join-Path $target "tools\invoke-p0-evidence.ps1"
  $p0H4FixturePath = Join-Path $target "examples\p0-h4-evidence-fixture\P0H4FIXTURE-001"
  $p0H4SchemaPath = Join-Path $target "templates\schema\p0-h4\evidence-command.v0.2.schema.json"
  $p0H4Evidence = @()
  $p0H4Status = "pass"
  if ((Test-Path -LiteralPath $p0H4ScriptPath) -and (Test-Path -LiteralPath $p0H4RuntimePath) -and (Test-Path -LiteralPath $p0H4CommandPath) -and (Test-Path -LiteralPath $p0H4FixturePath) -and (Test-Path -LiteralPath $p0H4SchemaPath)) {
    & $p0H4ScriptPath -FixturePath $p0H4FixturePath -ReportPath (Join-Path $checkerReportRoot 'p0-h4-evidence-report.json') | Out-Null
    if (-not $?) {
      $p0H4Status = "fail"
      $p0H4Evidence = @("state\checks\p0-h4-evidence-report.json")
    }
  } else {
    $p0H4Status = "fail"
    $p0H4Evidence = @("tools\P0EvidenceRuntime.ps1", "tools\invoke-p0-evidence.ps1", "tools\validate-p0-h4-evidence.ps1", "examples\p0-h4-evidence-fixture", "templates\schema\p0-h4")
  }
  $items.Add((New-CheckItem "P3REL-018" "p0_h4_evidence_runtime" "blocker" $p0H4Status $p0H4Evidence "P0-H4 unified event writer, evidence commands, projection rebuild, and orphan reconciliation must pass in the public package." @("Run tools/validate-p0-h4-evidence.ps1 and fix P0-H4 evidence runtime blockers.") "p0"))

  $windowsRuntimeHelperPath = Join-Path $target 'tools\WindowsRuntimeHelper.ps1'
  $windowsRuntimeValidatorPath = Join-Path $target 'tools\validate-windows-runtime-helper.ps1'
  $windowsRuntimeFixturePath = Join-Path $target 'examples\windows-runtime-helper-fixture\fixture.json'
  $windowsRuntimeStatus = 'pass'
  $windowsRuntimeEvidence = @()
  if ((Test-Path -LiteralPath $windowsRuntimeHelperPath) -and (Test-Path -LiteralPath $windowsRuntimeValidatorPath) -and (Test-Path -LiteralPath $windowsRuntimeFixturePath)) {
    & $windowsRuntimeValidatorPath -FixturePath $windowsRuntimeFixturePath -ReportPath (Join-Path $checkerReportRoot 'windows-runtime-helper-report.json') | Out-Null
    if (-not $?) {
      $windowsRuntimeStatus = 'fail'
      $windowsRuntimeEvidence = @('state\checks\windows-runtime-helper-report.json')
    }
  } else {
    $windowsRuntimeStatus = 'fail'
    $windowsRuntimeEvidence = @('tools\WindowsRuntimeHelper.ps1','tools\validate-windows-runtime-helper.ps1','examples\windows-runtime-helper-fixture')
  }
  $items.Add((New-CheckItem 'P3REL-026' 'windows_runtime_helper' 'blocker' $windowsRuntimeStatus $windowsRuntimeEvidence 'UTF-8 no-BOM writes, shared argv serialization, offline YAML fallback, and hidden-dependency checks must pass on the Windows PowerShell 5.1 baseline.' @('Run tools/validate-windows-runtime-helper.ps1 under Windows PowerShell 5.1, then fix the reported host-default or dependency leak.') 'environment'))

  $environmentPreflightHelperPath = Join-Path $target 'tools\EnvironmentPreflight.ps1'
  $environmentDoctorPath = Join-Path $target 'tools\invoke-environment-doctor.ps1'
  $environmentPreflightValidatorPath = Join-Path $target 'tools\validate-environment-preflight.ps1'
  $environmentPreflightFixturePath = Join-Path $target 'examples\windows-environment-preflight-fixture\fixtures.json'
  $environmentPreflightStatus = 'pass'
  $environmentPreflightEvidence = @()
  if ((Test-Path -LiteralPath $environmentPreflightHelperPath) -and (Test-Path -LiteralPath $environmentDoctorPath) -and (Test-Path -LiteralPath $environmentPreflightValidatorPath) -and (Test-Path -LiteralPath $environmentPreflightFixturePath)) {
    & $environmentPreflightValidatorPath -FixturePath $environmentPreflightFixturePath -ReportPath (Join-Path $checkerReportRoot 'environment-preflight-fixture-report.json') | Out-Null
    if (-not $?) {
      $environmentPreflightStatus = 'fail'
      $environmentPreflightEvidence = @('state\checks\environment-preflight-fixture-report.json')
    }
  } else {
    $environmentPreflightStatus = 'fail'
    $environmentPreflightEvidence = @('tools\EnvironmentPreflight.ps1','tools\invoke-environment-doctor.ps1','tools\validate-environment-preflight.ps1','examples\windows-environment-preflight-fixture')
  }
  $items.Add((New-CheckItem 'P3REL-027' 'windows_environment_preflight' 'blocker' $environmentPreflightStatus $environmentPreflightEvidence 'Path budget, reserved names, root containment, cwd independence, writable temp, and free-space preflight must pass before public build.' @('Run tools\validate-environment-preflight.ps1 and fix the deterministic preflight blocker before packaging.') 'environment'))

  $archiveHelperPath = Join-Path $target 'tools\ArchiveIntegrity.ps1'
  $archiveValidatorPath = Join-Path $target 'tools\validate-archive-integrity.ps1'
  $archiveFixturePath = Join-Path $target 'examples\windows-archive-integrity-fixture\fixtures.json'
  $archiveManifestPath = Join-Path $target 'archive-manifest.json'
  $archiveIntegrityStatus = 'pass'
  $archiveIntegrityEvidence = @()
  if ((Test-Path -LiteralPath $archiveHelperPath) -and (Test-Path -LiteralPath $archiveValidatorPath) -and (Test-Path -LiteralPath $archiveFixturePath) -and (Test-Path -LiteralPath $archiveManifestPath)) {
    & $archiveValidatorPath -FixturePath $archiveFixturePath -ReportPath (Join-Path $checkerReportRoot 'archive-integrity-fixture-report.json') | Out-Null
    if (-not $?) {
      $archiveIntegrityStatus = 'fail'
      $archiveIntegrityEvidence += 'state\checks\archive-integrity-fixture-report.json'
    }
    if (-not [string]::IsNullOrWhiteSpace($ZipPath)) {
      $zipIntegrity = Test-TaogeArchiveFile -ArchivePath $ZipPath -VerificationRoot (Join-Path $target '.v-h4')
      if ($zipIntegrity.status -ne 'pass') {
        $archiveIntegrityStatus = 'fail'
        $archiveIntegrityEvidence += @($zipIntegrity.errors | ForEach-Object { "zip:$_" })
      }
    }
  } else {
    $archiveIntegrityStatus = 'fail'
    $archiveIntegrityEvidence = @('tools\ArchiveIntegrity.ps1','tools\validate-archive-integrity.ps1','examples\windows-archive-integrity-fixture','archive-manifest.json')
  }
  $items.Add((New-CheckItem 'P3REL-028' 'archive_integrity_and_false_success' 'blocker' $archiveIntegrityStatus $archiveIntegrityEvidence 'Public and support archives require an internal manifest, secure extraction, exact count/size/SHA256 parity, required files, and verified-candidate replacement.' @('Run tools\validate-archive-integrity.ps1; rebuild the archive and do not publish an exit-code-only ZIP.') 'release'))

  $cleanRoomMatrixPath = Join-Path $target 'examples\windows-clean-room-matrix\matrix.json'
  $cleanRoomRunnerPath = Join-Path $target 'tools\invoke-windows-clean-room-matrix.ps1'
  $cleanRoomCasePath = Join-Path $target 'tools\invoke-windows-clean-room-case.ps1'
  $cleanRoomStatus = 'pass'
  $cleanRoomEvidence = @()
  if ((Test-Path -LiteralPath $cleanRoomMatrixPath) -and (Test-Path -LiteralPath $cleanRoomRunnerPath) -and (Test-Path -LiteralPath $cleanRoomCasePath)) {
    & $cleanRoomRunnerPath -ProjectRoot $target -MatrixPath $cleanRoomMatrixPath -Mode definition -HumanReportPath (Join-Path $checkerReportRoot 'windows-clean-room-definition-report.md') -MachineReportPath (Join-Path $checkerReportRoot 'windows-clean-room-definition-report.json') | Out-Null
    if (-not $?) {
      $cleanRoomStatus = 'fail'
      $cleanRoomEvidence = @('state\checks\windows-clean-room-definition-report.json')
    }
  } else {
    $cleanRoomStatus = 'fail'
    $cleanRoomEvidence = @('examples\windows-clean-room-matrix\matrix.json','tools\invoke-windows-clean-room-matrix.ps1','tools\invoke-windows-clean-room-case.ps1')
  }
  $items.Add((New-CheckItem 'P3REL-029' 'windows_clean_room_matrix_definition' 'blocker' $cleanRoomStatus $cleanRoomEvidence 'The public package must include the complete Windows PowerShell 5.1 x 3 path shapes x 2 source kinds matrix; full execution belongs to local/CI evidence.' @('Run tools\invoke-windows-clean-room-matrix.ps1 in full mode and keep unsupported environments outside the current public claim.') 'environment'))

  $certificationHelperPath = Join-Path $target 'tools\WindowsEnvironmentCertification.ps1'
  $certificationProbePath = Join-Path $target 'tools\invoke-windows-certification-probe.ps1'
  $certificationValidatorPath = Join-Path $target 'tools\validate-windows-certification.ps1'
  $certificationFixturePath = Join-Path $target 'examples\windows-certification-fixture\fixtures.json'
  $certificationMatrixPath = Join-Path $target 'examples\windows-certification-matrix\matrix.json'
  $certificationStatus = 'pass'
  $certificationEvidence = @()
  if ((Test-Path -LiteralPath $certificationHelperPath) -and (Test-Path -LiteralPath $certificationProbePath) -and (Test-Path -LiteralPath $certificationValidatorPath) -and (Test-Path -LiteralPath $certificationFixturePath) -and (Test-Path -LiteralPath $certificationMatrixPath)) {
    & $certificationValidatorPath -FixturePath $certificationFixturePath -ReportPath (Join-Path $checkerReportRoot 'windows-certification-fixture-report.json') | Out-Null
    if (-not $?) {
      $certificationStatus = 'fail'
      $certificationEvidence = @('state\checks\windows-certification-fixture-report.json')
    }
  } else {
    $certificationStatus = 'fail'
    $certificationEvidence = @('tools\WindowsEnvironmentCertification.ps1','tools\invoke-windows-certification-probe.ps1','tools\validate-windows-certification.ps1','examples\windows-certification-fixture','examples\windows-certification-matrix')
  }
  $items.Add((New-CheckItem 'P3REL-031' 'windows_extended_certification' 'blocker' $certificationStatus $certificationEvidence 'Every extended Windows axis needs environment observation plus full workflow evidence on the same host/root/commit; probe-only results never count as certification.' @('Run the matching hosted or self-hosted certification job and keep missing infrastructure as not_certified.') 'environment'))

  $p0H5RunnerPath = Join-Path $target "tools\invoke-p0-h5-regression.ps1"
  $p0H5ValidatorPath = Join-Path $target "tools\validate-p0-h5-regression.ps1"
  $p0H5Status = "pass"
  $p0H5Evidence = @()
  if (-not (Test-Path -LiteralPath $p0H5RunnerPath) -or -not (Test-Path -LiteralPath $p0H5ValidatorPath)) {
    $p0H5Status = "fail"
    $p0H5Evidence = @("tools\invoke-p0-h5-regression.ps1", "tools\validate-p0-h5-regression.ps1")
  } else {
    $p0H5RunnerText = Get-Content -LiteralPath $p0H5RunnerPath -Raw -Encoding UTF8
    $p0H5ValidatorText = Get-Content -LiteralPath $p0H5ValidatorPath -Raw -Encoding UTF8
    $p0H5RequiredRunnerSignals = @('target_session_already_exists','provider_invocation_count=0','external_provider_invoked=$false','pass_with_warnings')
    $p0H5RequiredValidatorSignals = @('content_reused_from_baseline','verified_images_reused','external_image_generation_not_tested','publishing_not_tested')
    $missingRunnerSignals = @($p0H5RequiredRunnerSignals | Where-Object { $p0H5RunnerText -notmatch [regex]::Escape($_) })
    $missingValidatorSignals = @($p0H5RequiredValidatorSignals | Where-Object { $p0H5ValidatorText -notmatch [regex]::Escape($_) })
    if ($missingRunnerSignals.Count -or $missingValidatorSignals.Count) {
      $p0H5Status = "fail"
      $p0H5Evidence = @($missingRunnerSignals | ForEach-Object { "runner_missing:$_" }) + @($missingValidatorSignals | ForEach-Object { "validator_missing:$_" })
    }
  }
  $items.Add((New-CheckItem "P3REL-019" "p0_h5_private_regression_boundary" "blocker" $p0H5Status $p0H5Evidence "P0-H5 public source must preserve new-session isolation, zero-provider Phase 1, required warnings, and a private-only real-run validator without bundling real accounts." @("Restore the H5 runner/validator boundary signals; do not add accounts or real run data to the public package.") "p0"))

  $r3BudgetScriptPath = Join-Path $target "tools\validate-r3-visual-budget.ps1"
  $r3BudgetFixturePath = Join-Path $target "examples\r3-visual-budget-fixtures\fixtures.json"
  $r3BudgetSchemaPath = Join-Path $target "templates\schema\r3\visual-budget.v0.1.schema.json"
  $r3BudgetStatus = 'pass'; $r3BudgetEvidence = @()
  if ((Test-Path -LiteralPath $r3BudgetScriptPath) -and (Test-Path -LiteralPath $r3BudgetFixturePath) -and (Test-Path -LiteralPath $r3BudgetSchemaPath)) {
    & $r3BudgetScriptPath -FixturePath $r3BudgetFixturePath -ReportPath (Join-Path $checkerReportRoot 'r3-visual-budget-report.json') | Out-Null
    if (-not $?) { $r3BudgetStatus='fail'; $r3BudgetEvidence=@('state\checks\r3-visual-budget-report.json') }
  } else { $r3BudgetStatus='fail'; $r3BudgetEvidence=@('tools\validate-r3-visual-budget.ps1','templates\schema\r3\visual-budget.v0.1.schema.json','examples\r3-visual-budget-fixtures\fixtures.json') }
  $items.Add((New-CheckItem "P3REL-020" "r3_visual_budget_legacy_compatibility" "blocker" $r3BudgetStatus $r3BudgetEvidence "The superseded visual-budget schema and fixtures remain readable for history-only compatibility." @("Run tools/validate-r3-visual-budget.ps1 and repair legacy compatibility without restoring it as the current product gate.") "r3"))

  $r3NeedScriptPath = Join-Path $target "tools\validate-r3-visual-need.ps1"
  $r3NeedFixturePath = Join-Path $target "examples\r3-visual-need-fixtures\fixtures.json"
  $r3NeedSchemaPath = Join-Path $target "templates\schema\r3\visual-need-analysis.v0.1.schema.json"
  $r3NeedStatus = 'pass'; $r3NeedEvidence = @()
  if ((Test-Path -LiteralPath $r3NeedScriptPath) -and (Test-Path -LiteralPath $r3NeedFixturePath) -and (Test-Path -LiteralPath $r3NeedSchemaPath)) {
    & $r3NeedScriptPath -FixturePath $r3NeedFixturePath -ReportPath (Join-Path $checkerReportRoot 'r3-visual-need-report.json') | Out-Null
    if (-not $?) { $r3NeedStatus='fail'; $r3NeedEvidence=@('state\checks\r3-visual-need-report.json') }
  } else { $r3NeedStatus='fail'; $r3NeedEvidence=@('tools\validate-r3-visual-need.ps1','templates\schema\r3\visual-need-analysis.v0.1.schema.json','examples\r3-visual-need-fixtures\fixtures.json') }
  $items.Add((New-CheckItem "P3REL-021" "r3_visual_need_contract" "blocker" $r3NeedStatus $r3NeedEvidence "R3-C71 to C80 content-derived 0-to-N visual need analysis, generate/reject mapping, and unbounded Image 2 policy must pass." @("Run tools/validate-r3-visual-need.ps1 and repair any product-to-code sink mismatch.") "r3"))

  $r5H1ScriptPath = Join-Path $target 'tools\validate-r5-h1-account-visual-identity.ps1'
  $r5H1FixturePath = Join-Path $target 'examples\r5-h1-account-visual-identity-fixtures\fixtures.json'
  $r5H1SchemaPath = Join-Path $target 'templates\schema\r5\account-visual-identity.v0.1.schema.json'
  $r5H1Status = 'pass'; $r5H1Evidence = @()
  if ((Test-Path -LiteralPath $r5H1ScriptPath) -and (Test-Path -LiteralPath $r5H1FixturePath) -and (Test-Path -LiteralPath $r5H1SchemaPath)) {
    & $r5H1ScriptPath -FixturePath $r5H1FixturePath -ReportPath (Join-Path $checkerReportRoot 'r5-h1-account-visual-identity-report.json') | Out-Null
    if (-not $?) { $r5H1Status='fail'; $r5H1Evidence=@('checker-reports\r5-h1-account-visual-identity-report.json') }
  } else { $r5H1Status='fail'; $r5H1Evidence=@('tools\validate-r5-h1-account-visual-identity.ps1','templates\schema\r5\account-visual-identity.v0.1.schema.json','examples\r5-h1-account-visual-identity-fixtures\fixtures.json') }
  $items.Add((New-CheckItem "P3REL-032" "r5_account_visual_identity_contract" "blocker" $r5H1Status $r5H1Evidence "R5-H1 account visual identity must constrain expression, remain account-scoped, and never compile fixed image cardinality or provider-call limits." @("Run tools/validate-r5-h1-account-visual-identity.ps1 and repair field, template, contract, fixture or checker drift.") "r5"))

  $r5H2ScriptPath = Join-Path $target 'tools\validate-r5-h2-account-radar.ps1'
  $r5H2FixturePath = Join-Path $target 'examples\r5-h2-account-radar-fixtures\fixtures.json'
  $r5H2SchemaPath = Join-Path $target 'templates\schema\r5\account-radar-policy.v0.1.schema.json'
  $r5H2Status = 'pass'; $r5H2Evidence = @()
  if ((Test-Path -LiteralPath $r5H2ScriptPath) -and (Test-Path -LiteralPath $r5H2FixturePath) -and (Test-Path -LiteralPath $r5H2SchemaPath)) {
    & $r5H2ScriptPath -FixturePath $r5H2FixturePath -ReportPath (Join-Path $checkerReportRoot 'r5-h2-account-radar-report.json') | Out-Null
    if (-not $?) { $r5H2Status='fail'; $r5H2Evidence=@('checker-reports\r5-h2-account-radar-report.json') }
  } else { $r5H2Status='fail'; $r5H2Evidence=@('tools\validate-r5-h2-account-radar.ps1','templates\schema\r5\account-radar-policy.v0.1.schema.json','examples\r5-h2-account-radar-fixtures\fixtures.json') }
  $items.Add((New-CheckItem "P3REL-033" "r5_account_radar_contract" "blocker" $r5H2Status $r5H2Evidence "R5-H2 must preserve account-scoped used-car-first policy, thresholded spillover and exploratory selection feedback." @("Run tools/validate-r5-h2-account-radar.ps1 and repair contract drift.") "r5"))

  $r5H3ScriptPath = Join-Path $target 'tools\validate-r5-h3-radar-objects.ps1'
  $r5H3FixturePath = Join-Path $target 'examples\r5-h3-radar-object-fixtures\fixtures.json'
  $r5H3SchemaPath = Join-Path $target 'templates\schema\r5\radar-objects.v0.1.schema.json'
  $r5H3Status = 'pass'; $r5H3Evidence = @()
  if ((Test-Path -LiteralPath $r5H3ScriptPath) -and (Test-Path -LiteralPath $r5H3FixturePath) -and (Test-Path -LiteralPath $r5H3SchemaPath)) {
    & $r5H3ScriptPath -FixturePath $r5H3FixturePath -ReportPath (Join-Path $checkerReportRoot 'r5-h3-radar-objects-report.json') | Out-Null
    if (-not $?) { $r5H3Status='fail'; $r5H3Evidence=@('checker-reports\r5-h3-radar-objects-report.json') }
  } else { $r5H3Status='fail'; $r5H3Evidence=@('tools\validate-r5-h3-radar-objects.ps1','templates\schema\r5\radar-objects.v0.1.schema.json','examples\r5-h3-radar-object-fixtures\fixtures.json') }
  $items.Add((New-CheckItem "P3REL-034" "r5_radar_object_contract" "blocker" $r5H3Status $r5H3Evidence "R5-H3 signal-to-event-to-candidate-to-topic, comparable snapshots, fact and propagation layers must remain executable in the public package." @("Run tools/validate-r5-h3-radar-objects.ps1 and repair the missing contract source.") "r5"))

  $r5H4ScriptPath = Join-Path $target 'tools\validate-r5-h4-feedback-ledger.ps1'
  $r5H4FixturePath = Join-Path $target 'examples\r5-h4-feedback-fixtures\fixtures.json'
  $r5H4Status = 'pass'; $r5H4Evidence = @()
  if ((Test-Path -LiteralPath $r5H4ScriptPath) -and (Test-Path -LiteralPath $r5H4FixturePath)) {
    & $r5H4ScriptPath -FixturePath $r5H4FixturePath -ReportPath (Join-Path $checkerReportRoot 'r5-h4-feedback-ledger-report.json') | Out-Null
    if (-not $?) { $r5H4Status='fail'; $r5H4Evidence=@('checker-reports\r5-h4-feedback-ledger-report.json') }
  } else { $r5H4Status='fail'; $r5H4Evidence=@('tools\validate-r5-h4-feedback-ledger.ps1','examples\r5-h4-feedback-fixtures\fixtures.json') }
  $items.Add((New-CheckItem "P3REL-035" "r5_lexicon_feedback_contract" "blocker" $r5H4Status $r5H4Evidence "R5-H4 exploratory expansion and selection-feedback weighting must remain testable without a private account or automatic collection." @("Run tools/validate-r5-h4-feedback-ledger.ps1 and repair the public fixture or checker.") "r5"))

  $r5H5ScriptPath = Join-Path $target 'tools\validate-r5-h5-account-startup.ps1'
  $r5H5FixturePath = Join-Path $target 'examples\r5-h5-account-startup-fixtures\fixtures.json'
  $r5H5RuntimePaths = @('tools\AccountStartupCheck.ps1','tools\invoke-account-startup-check.ps1','templates\schema\r5\account-session-snapshot.v0.1.schema.json','templates\schema\r5\account-startup-check.v0.1.schema.json') | ForEach-Object { Join-Path $target $_ }
  $r5H5Status = 'pass'; $r5H5Evidence = @()
  if ((Test-Path -LiteralPath $r5H5ScriptPath) -and (Test-Path -LiteralPath $r5H5FixturePath) -and -not @($r5H5RuntimePaths | Where-Object { -not (Test-Path -LiteralPath $_) })) {
    & $r5H5ScriptPath -FixturePath $r5H5FixturePath -ReportPath (Join-Path $checkerReportRoot 'r5-h5-account-startup-report.json') | Out-Null
    if (-not $?) { $r5H5Status='fail'; $r5H5Evidence=@('checker-reports\r5-h5-account-startup-report.json') }
  } else { $r5H5Status='fail'; $r5H5Evidence=@('tools\validate-r5-h5-account-startup.ps1','examples\r5-h5-account-startup-fixtures\fixtures.json','tools\AccountStartupCheck.ps1','tools\invoke-account-startup-check.ps1') }
  $items.Add((New-CheckItem "P3REL-036" "r5_account_startup_compatibility" "blocker" $r5H5Status $r5H5Evidence "R5-H5 historical startup and session-snapshot compatibility must stay executable while H6 is the current identity gate." @("Run tools/validate-r5-h5-account-startup.ps1 and restore its declared public runtime dependencies.") "r5"))

  $r5H6ScriptPath = Join-Path $target 'tools\validate-r5-h6-account-identity.ps1'
  $r5H6FixturePath = Join-Path $target 'examples\r5-h6-account-identity-fixtures\fixtures.json'
  $r5H6RuntimePaths = @('tools\AccountIdentityBinding.ps1','tools\AccountStartupCheckV02.ps1','tools\invoke-account-startup-check-v0.2.ps1','tools\new-account-identity-binding.ps1','templates\schema\r5\account-identity-binding.v0.1.schema.json','templates\schema\r5\account-session-snapshot.v0.2.schema.json','templates\schema\r5\account-startup-check.v0.2.schema.json') | ForEach-Object { Join-Path $target $_ }
  $r5H6Status = 'pass'; $r5H6Evidence = @()
  if ((Test-Path -LiteralPath $r5H6ScriptPath) -and (Test-Path -LiteralPath $r5H6FixturePath) -and -not @($r5H6RuntimePaths | Where-Object { -not (Test-Path -LiteralPath $_) })) {
    & $r5H6ScriptPath -FixturePath $r5H6FixturePath -ReportPath (Join-Path $checkerReportRoot 'r5-h6-account-identity-report.json') | Out-Null
    if (-not $?) { $r5H6Status='fail'; $r5H6Evidence=@('checker-reports\r5-h6-account-identity-report.json') }
  } else { $r5H6Status='fail'; $r5H6Evidence=@('tools\validate-r5-h6-account-identity.ps1','examples\r5-h6-account-identity-fixtures\fixtures.json','tools\AccountIdentityBinding.ps1','tools\AccountStartupCheckV02.ps1','tools\invoke-account-startup-check-v0.2.ps1','tools\new-account-identity-binding.ps1') }
  $items.Add((New-CheckItem "P3REL-037" "r5_account_identity_binding_contract" "blocker" $r5H6Status $r5H6Evidence "R5-H6 current cross-account identity binding, root containment and snapshot-digest gate must ship with all declared public runtime dependencies." @("Run tools/validate-r5-h6-account-identity.ps1 and restore the missing public tool or schema.") "r5"))

  $r6ScriptPath = Join-Path $target 'tools\validate-r6-content-evidence.ps1'
  $r6FixturePath = Join-Path $target 'examples\r6-content-evidence-fixtures\fixtures.json'
  $r6RuntimePaths = @('tools\R6ContentEvidenceRuntime.ps1','tools\invoke-r6-content-evidence.ps1','tools\invoke-r6-source-capture.ps1','tools\R3VisualNeed.ps1','templates\schema\r6\direct-content-intake.v0.1.schema.json','templates\schema\r6\source-capture-record.v0.1.schema.json','templates\schema\r6\news-evidence-pip.v0.1.schema.json','templates\schema\r3\visual-need-analysis.v0.2.schema.json') | ForEach-Object { Join-Path $target $_ }
  $r6Status = 'pass'; $r6Evidence = @()
  if ((Test-Path -LiteralPath $r6ScriptPath) -and (Test-Path -LiteralPath $r6FixturePath) -and -not @($r6RuntimePaths | Where-Object { -not (Test-Path -LiteralPath $_) })) {
    & $r6ScriptPath -FixturePath $r6FixturePath -ReportPath (Join-Path $checkerReportRoot 'r6-content-evidence-report.json') -WorkRoot (Join-Path $defaultReportRoot '.r6e') | Out-Null
    if (-not $?) { $r6Status='fail'; $r6Evidence=@('checker-reports\r6-content-evidence-report.json') }
  } else { $r6Status='fail'; $r6Evidence=@('tools\validate-r6-content-evidence.ps1','tools\R6ContentEvidenceRuntime.ps1','tools\invoke-r6-content-evidence.ps1','tools\invoke-r6-source-capture.ps1','examples\r6-content-evidence-fixtures','templates\schema\r6','templates\schema\r3\visual-need-analysis.v0.2.schema.json') }
  $items.Add((New-CheckItem "P3REL-039" "r6_direct_content_and_source_evidence" "blocker" $r6Status $r6Evidence "R6 direct content lineage, R3 producer dispatch, source-capture recovery, evidence-state separation, and deterministic evidence PIP rendering must pass without real accounts or network access." @("Run tools/validate-r6-content-evidence.ps1 and repair the failing field, contract, fixture, capture, or renderer layer.") "r6"))

  $p0H6CompletePath = Join-Path $target 'tools\complete-p0-h6-regression.ps1'
  $p0H6ValidatorPath = Join-Path $target 'tools\validate-p0-h6-regression.ps1'
  $p0H6Status = 'pass'; $p0H6Evidence = @()
  if (-not (Test-Path -LiteralPath $p0H6CompletePath) -or -not (Test-Path -LiteralPath $p0H6ValidatorPath)) {
    $p0H6Status='fail'; $p0H6Evidence=@('tools\complete-p0-h6-regression.ps1','tools\validate-p0-h6-regression.ps1')
  } else {
    $completeText=Get-Content -LiteralPath $p0H6CompletePath -Raw -Encoding UTF8
    $validatorText=Get-Content -LiteralPath $p0H6ValidatorPath -Raw -Encoding UTF8
    $requiredComplete=@('codex_builtin_image2','actual_provider_execution_count','runtime_model_profile: not_observable','pending_h6_validation','reconcile_existing_output_before_retry','skipped_completed')
    $requiredValidator=@('provider_execution_matches_accepted','render_uses_h6_revision','trace_hashes_current','runtime_validate_completed','candidate_render_input_digest_match')
    $missing=@($requiredComplete|Where-Object{$completeText-notmatch[regex]::Escape($_)})+@($requiredValidator|Where-Object{$validatorText-notmatch[regex]::Escape($_)})
    $magic=@([regex]::Matches($validatorText,'-eq\s*(?:8|3|11)\b')|ForEach-Object{$_.Value})
    $validatorMutations=@(@('WriteAllText($manifestPath','Write-H6Text $manifestPath')|Where-Object{$validatorText.Contains($_)})
    $selfTestOutput=@(& $p0H6CompletePath -Mode self_test 2>&1);$selfTestExit=if($?){0}else{1}
    if($missing.Count-or$magic.Count-or$validatorMutations.Count-or$selfTestExit-ne0-or$selfTestOutput-notcontains'P0_H6_SELF_TEST_RESULT=pass'){$p0H6Status='fail';$p0H6Evidence=@($missing|ForEach-Object{"missing_signal:$_"})+@($magic|ForEach-Object{"fixed_cardinality:$_"})+@($validatorMutations|ForEach-Object{"checker_mutates_manifest:$_"})+@("self_test_exit:$selfTestExit")+@($selfTestOutput)}
  }
  $items.Add((New-CheckItem "P3REL-022" "p0_h6_real_image_regression_boundary" "blocker" $p0H6Status $p0H6Evidence "P0-H6 source must bind accepted tasks to actual Image 2 executions, select the H6 render revision, refresh trace hashes, and avoid claiming an unobservable runtime model profile." @("Restore H6 completion and validation signals without bundling private accounts or generated assets.") "p0"))

  $p0H6ReliabilityPath=Join-Path $target 'tools\validate-p0-h6-reliability.ps1';$p0H6ReliabilityFixture=Join-Path $target 'examples\p0-h6-reliability-fixtures\fixtures.json';$p0H6ReliabilityStatus='pass';$p0H6ReliabilityEvidence=@()
  if((Test-Path -LiteralPath $p0H6ReliabilityPath)-and(Test-Path -LiteralPath $p0H6ReliabilityFixture)){& $p0H6ReliabilityPath -FixturePath $p0H6ReliabilityFixture -ReportPath (Join-Path $checkerReportRoot 'p0-h6-reliability-report.json')|Out-Null;if(-not $?){$p0H6ReliabilityStatus='fail';$p0H6ReliabilityEvidence=@('state\checks\p0-h6-reliability-report.json')}}else{$p0H6ReliabilityStatus='fail';$p0H6ReliabilityEvidence=@('tools\validate-p0-h6-reliability.ps1','examples\p0-h6-reliability-fixtures\fixtures.json')}
  $items.Add((New-CheckItem "P3REL-023" "p0_h6_reliability_fixtures" "blocker" $p0H6ReliabilityStatus $p0H6ReliabilityEvidence "R3-C81 to C90 interruption recovery, monotonic state, checker purity, dynamic cardinality, digest, layout, and executable smoke fixtures must pass." @("Run tools/validate-p0-h6-reliability.ps1 and repair the failing reliability contract.") "p0"))

  $docGovernancePath=Join-Path $target 'tools\validate-doc-governance.ps1';$docGovernanceStatus='pass';$docGovernanceEvidence=@()
  if(Test-Path -LiteralPath $docGovernancePath){& $docGovernancePath -ProjectRoot $target -ReportPath (Join-Path $checkerReportRoot 'doc-governance-report.json')|Out-Null;if(-not $?){$docGovernanceStatus='fail';$docGovernanceEvidence=@('checker-reports\doc-governance-report.json')}}else{$docGovernanceStatus='fail';$docGovernanceEvidence=@('tools\validate-doc-governance.ps1')}
  $items.Add((New-CheckItem "P3REL-024" "document_graph_governance" "blocker" $docGovernanceStatus $docGovernanceEvidence "Section indexes, root fast paths, knowledge-document coverage, links, AI navigation anchors, and current product scope must remain coherent in the public package." @("Run tools/validate-doc-governance.ps1 and repair document graph blockers.") "docs"))

  $publicEntryDocumentPath=Join-Path $target 'tools\validate-public-entry-doc-review.ps1';$publicEntryDocumentStatus='pass';$publicEntryDocumentEvidence=@()
  if(Test-Path -LiteralPath $publicEntryDocumentPath){& $publicEntryDocumentPath -ProjectRoot $target -SelfTest -ReportPath (Join-Path $checkerReportRoot 'public-entry-doc-review-report.json')|Out-Null;if(-not $?){$publicEntryDocumentStatus='fail';$publicEntryDocumentEvidence=@('checker-reports\public-entry-doc-review-report.json')}}else{$publicEntryDocumentStatus='fail';$publicEntryDocumentEvidence=@('tools\validate-public-entry-doc-review.ps1','docs\governance\public-entry-document-review.yaml')}
  $items.Add((New-CheckItem "P3REL-038" "public_entry_document_review" "blocker" $publicEntryDocumentStatus $publicEntryDocumentEvidence "Every public entry document must be explicitly reviewed for the candidate version; README must remain a current landing page and reject known stale claims." @("Run tools/validate-public-entry-doc-review.ps1 -SelfTest and update the review contract or stale public copy.") "docs"))

  $p0H7Path=Join-Path $target 'tools\validate-p0-h7-fixtures.ps1';$p0H7Fixture=Join-Path $target 'examples\p0-runtime-v0.3-fixture';$p0H7Status='pass';$p0H7Evidence=@()
  if((Test-Path -LiteralPath $p0H7Path)-and(Test-Path -LiteralPath $p0H7Fixture)){& $p0H7Path -FixturePath $p0H7Fixture -ReportPath (Join-Path $checkerReportRoot 'p0-h7-fixture-report.json')|Out-Null;if(-not $?){$p0H7Status='fail';$p0H7Evidence=@('state\checks\p0-h7-fixture-report.json')}}else{$p0H7Status='fail';$p0H7Evidence=@('tools\validate-p0-h7-fixtures.ps1','examples\p0-runtime-v0.3-fixture')}
  $items.Add((New-CheckItem "P3REL-025" "p0_h7_delivery_revision" "blocker" $p0H7Status $p0H7Evidence "P0-H7 v0.3 delivery revision, platform-cover binding, exact PIP placement, warning union, honest duration, deterministic views, and idempotency fixtures must pass." @("Run tools/validate-p0-h7-fixtures.ps1 and repair the failing delivery-revision contract.") "p0"))

  $r3VisualPresentationPath=Join-Path $target 'tools\validate-r3-visual-presentation.ps1';$r3VisualPresentationFixture=Join-Path $target 'examples\r3-visual-presentation-fixtures\fixtures.json';$r3VisualPresentationStatus='pass';$r3VisualPresentationEvidence=@()
  if((Test-Path -LiteralPath $r3VisualPresentationPath)-and(Test-Path -LiteralPath $r3VisualPresentationFixture)){& $r3VisualPresentationPath -FixturePath $r3VisualPresentationFixture -ReportPath (Join-Path $checkerReportRoot 'r3-visual-presentation-report.json')|Out-Null;if(-not $?){$r3VisualPresentationStatus='fail';$r3VisualPresentationEvidence=@('checker-reports\r3-visual-presentation-report.json')}}else{$r3VisualPresentationStatus='fail';$r3VisualPresentationEvidence=@('tools\validate-r3-visual-presentation.ps1','examples\r3-visual-presentation-fixtures\fixtures.json')}
  $items.Add((New-CheckItem "P3REL-040" "r3_visual_presentation_contract" "blocker" $r3VisualPresentationStatus $r3VisualPresentationEvidence "R3-C91 to C124 canvas, slot, adaptation, protected-region, explicit raster review, and monotonic readiness contracts must pass." @("Run tools/validate-r3-visual-presentation.ps1 and repair the failing product-to-code sink.") "r3"))

  $p0H7V04Path=Join-Path $target 'tools\validate-p0-h7-v04-fixtures.ps1';$p0H7V04Fixture=Join-Path $target 'examples\p0-runtime-v0.4-fixture';$p0H7V04Status='pass';$p0H7V04Evidence=@()
  if((Test-Path -LiteralPath $p0H7V04Path)-and(Test-Path -LiteralPath $p0H7V04Fixture)){& $p0H7V04Path -FixturePath $p0H7V04Fixture -ReportPath (Join-Path $checkerReportRoot 'p0-h7-v04-fixture-report.json')|Out-Null;if(-not $?){$p0H7V04Status='fail';$p0H7V04Evidence=@('checker-reports\p0-h7-v04-fixture-report.json')}}else{$p0H7V04Status='fail';$p0H7V04Evidence=@('tools\validate-p0-h7-v04-fixtures.ps1','examples\p0-runtime-v0.4-fixture')}
  $items.Add((New-CheckItem "P3REL-041" "p0_h7_v04_delivery_contract" "blocker" $p0H7V04Status $p0H7V04Evidence "P0-H7 v0.4 historical typed delivery, visual insert, cover review, preview materialization, readiness, negative cases, and idempotency fixtures must stay replayable." @("Run tools/validate-p0-h7-v04-fixtures.ps1 and repair historical compatibility without treating it as the current contract.") "p0"))

  $r6ScriptVisualPath=Join-Path $target 'tools\validate-r6-script-visual-contract.ps1';$r6ScriptVisualStatus='pass';$r6ScriptVisualEvidence=@()
  if(Test-Path -LiteralPath $r6ScriptVisualPath){& $r6ScriptVisualPath -ReportPath (Join-Path $checkerReportRoot 'r6-script-visual-contract-report.json')|Out-Null;if(-not $?){$r6ScriptVisualStatus='fail';$r6ScriptVisualEvidence=@('checker-reports\r6-script-visual-contract-report.json')}}else{$r6ScriptVisualStatus='fail';$r6ScriptVisualEvidence=@('tools\validate-r6-script-visual-contract.ps1','examples\r6-script-visual-fixtures\base-direct.json')}
  $items.Add((New-CheckItem "P3REL-043" "r6_script_structure_and_visual_coverage" "blocker" $r6ScriptVisualStatus $r6ScriptVisualEvidence "R6 source-aware draft, structure, beat, script-review, visual-coverage and current-pointer contracts must pass without network or provider side effects." @("Run tools/validate-r6-script-visual-contract.ps1 and repair the failing contract, runtime or fixture layer.") "r6"))

  $p0R6V05Path=Join-Path $target 'tools\validate-p0-r6-v05-fixtures.ps1';$p0R6V05Status='pass';$p0R6V05Evidence=@()
  if(Test-Path -LiteralPath $p0R6V05Path){& $p0R6V05Path -ReportPath (Join-Path $checkerReportRoot 'p0-r6-v05-fixture-report.json')|Out-Null;if(-not $?){$p0R6V05Status='fail';$p0R6V05Evidence=@('checker-reports\p0-r6-v05-fixture-report.json')}}else{$p0R6V05Status='fail';$p0R6V05Evidence=@('tools\validate-p0-r6-v05-fixtures.ps1','examples\p0-runtime-v0.5-fixture')}
  $items.Add((New-CheckItem "P3REL-044" "p0_r6_v05_current_delivery_contract" "blocker" $p0R6V05Status $p0R6V05Evidence "The current v0.5 typed delivery, deterministic renderer, revision marker, idempotency and negative fixtures must pass." @("Run tools/validate-p0-r6-v05-fixtures.ps1 and repair the current delivery contract.") "p0"))

  $r7H1Path=Join-Path $target 'tools\validate-r7-h1-contracts.ps1';$r7H1Status='pass';$r7H1Evidence=@()
  if(Test-Path -LiteralPath $r7H1Path){
    & $r7H1Path -FixtureRoot (Join-Path $target 'examples\r7-h1-contract-fixtures') -SchemaRoot (Join-Path $target 'templates\schema\r7') -BlueprintPath (Join-Path $target 'compatibility\legacy-r7\routes\r7-workflow-blueprints.yaml') -NodeRegistryPath (Join-Path $target 'compatibility\legacy-r7\routes\r7-node-registry.yaml') -ContractRegistryPath (Join-Path $target 'routes\r7-contract-status-registry.yaml') -ActionRegistryPath (Join-Path $target 'compatibility\legacy-r7\routes\r7-action-registry.v0.3.yaml') -CompatibilityMatrixPath (Join-Path $target 'templates\schema\r7\compatibility-matrix.v0.1.json') -HumanReportPath (Join-Path $checkerReportRoot 'r7-h1-contract-report.md') -MachineReportPath (Join-Path $checkerReportRoot 'r7-h1-contract-report.json') | Out-Null
    if(-not $?){$r7H1Status='fail';$r7H1Evidence=@('checker-reports\r7-h1-contract-report.json')}
  }else{$r7H1Status='fail';$r7H1Evidence=@('tools\validate-r7-h1-contracts.ps1','tools\R7ContractHelper.ps1','examples\r7-h1-contract-fixtures','templates\schema\r7','compatibility\legacy-r7\routes\r7-workflow-blueprints.yaml')}
  $items.Add((New-CheckItem "P3REL-045" "r7_h1_semantic_workflow_contracts" "blocker" $r7H1Status $r7H1Evidence "R7-H1 blueprint, node, contract status, action registry, typed task/submission, legacy compatibility, and negative fixtures must pass without activating H2/H4 runtimes." @("Run tools/validate-r7-h1-contracts.ps1 and repair the failing contract layer without claiming runtime activation.") "r7"))

  $r7H2Path=Join-Path $target 'tools\validate-r7-h2-runtime.ps1';$r7H2Status='pass';$r7H2Evidence=@()
  if(Test-Path -LiteralPath $r7H2Path){
    & $r7H2Path -FixtureRoot (Join-Path $target 'examples\r7-h2-runtime-fixtures') -WorkRoot (Join-Path $checkerReportRoot 'r7-h2-runtime-work') -HumanReportPath (Join-Path $checkerReportRoot 'r7-h2-runtime-report.md') -MachineReportPath (Join-Path $checkerReportRoot 'r7-h2-runtime-report.json') | Out-Null
    if(-not $?){$r7H2Status='fail';$r7H2Evidence=@('checker-reports\r7-h2-runtime-report.json')}
  }else{$r7H2Status='fail';$r7H2Evidence=@('tools\validate-r7-h2-runtime.ps1','tools\R7SemanticRuntime.ps1','examples\r7-h2-runtime-fixtures','compatibility\legacy-r7\routes\r7-input-selector-registry.yaml')}
  $items.Add((New-CheckItem "P3REL-046" "r7_h2_semantic_runtime" "blocker" $r7H2Status $r7H2Evidence "R7-H2 must prepare one typed task and commit revision, lineage, pointer-last, event and projection with duplicate and interruption recovery." @("Run tools\validate-r7-h2-runtime.ps1 and repair the deterministic coordinator/submitter runtime.") "r7"))

  $r7H3Path=Join-Path $target 'tools\validate-r7-h3-producer-adapters.ps1';$r7H3Status='pass';$r7H3Evidence=@()
  if(Test-Path -LiteralPath $r7H3Path){& $r7H3Path -FixtureRoot (Join-Path $target 'examples\r7-h3-producer-fixtures') -WorkRoot (Join-Path $checkerReportRoot 'r7-h3-producer-work') -HumanReportPath (Join-Path $checkerReportRoot 'r7-h3-producer-report.md') -MachineReportPath (Join-Path $checkerReportRoot 'r7-h3-producer-report.json')|Out-Null;if(-not $?){$r7H3Status='fail';$r7H3Evidence=@('checker-reports\r7-h3-producer-report.json')}}else{$r7H3Status='fail';$r7H3Evidence=@('tools\validate-r7-h3-producer-adapters.ps1','tools\new-r7-semantic-submission.ps1','compatibility\legacy-r7\routes\r7-producer-adapter-registry.yaml','examples\r7-h3-producer-fixtures')}
  $items.Add((New-CheckItem "P3REL-047" "r7_h3_direct_producer_adapters" "blocker" $r7H3Status $r7H3Evidence "R7-H3 must bind all direct semantic producers to payload schemas, deterministically build submissions, translate statuses explicitly, and preserve waiting cursors." @("Run tools\validate-r7-h3-producer-adapters.ps1 and repair producer adapter or wait-state drift.") "r7"))

  $r7H4Path=Join-Path $target 'tools\validate-r7-h4-candidate-runtime.ps1';$r7H4Status='pass';$r7H4Evidence=@()
  if(Test-Path -LiteralPath $r7H4Path){& $r7H4Path -WorkRoot (Join-Path $defaultReportRoot '.r7h4') -HumanReportPath (Join-Path $checkerReportRoot 'r7-h4-candidate-report.md') -MachineReportPath (Join-Path $checkerReportRoot 'r7-h4-candidate-report.json')|Out-Null;if(-not $?){$r7H4Status='fail';$r7H4Evidence=@('checker-reports\r7-h4-candidate-report.json')}}else{$r7H4Status='fail';$r7H4Evidence=@('tools\validate-r7-h4-candidate-runtime.ps1','tools\R7CandidateRuntime.ps1','routes\r7-delivery-presentation-registry.yaml','templates\schema\final-delivery\typed-components.v0.6.schema.json')}
  $items.Add((New-CheckItem "P3REL-048" "r7_h4_candidate_renderer" "blocker" $r7H4Status $r7H4Evidence "R7-H4 must compile the candidate from current pointers, bind every cover rendition review by output/preview hash, render synchronized v0.6 views, and reject agent-authored machine artifacts." @("Run tools\validate-r7-h4-candidate-runtime.ps1 and repair candidate, review-binding, renderer, or packaging drift.") "r7"))

  $r7H5Path=Join-Path $target 'tools\validate-r7-h5-viewport-autonomy.ps1';$r7H5Status='pass';$r7H5Evidence=@()
  if(Test-Path -LiteralPath $r7H5Path){& $r7H5Path -WorkRoot (Join-Path $defaultReportRoot '.r7h5') -HumanReportPath (Join-Path $checkerReportRoot 'r7-h5-viewport-report.md') -MachineReportPath (Join-Path $checkerReportRoot 'r7-h5-viewport-report.json')|Out-Null;if(-not $?){$r7H5Status='fail';$r7H5Evidence=@('checker-reports\r7-h5-viewport-report.json')}}else{$r7H5Status='fail';$r7H5Evidence=@('tools\validate-r7-h5-viewport-autonomy.ps1','tools\R7ViewportRuntime.ps1','tools\r7-viewport-measure.js','tools\new-r7-final-human-decision.ps1','templates\schema\r7\viewport-acceptance.v0.1.schema.json','templates\schema\r7\workflow-session-record.v0.1.schema.json')}
  $items.Add((New-CheckItem "P3REL-049" "r7_h5_viewport_autonomy_final_gate" "blocker" $r7H5Status $r7H5Evidence "R7-H5 must run real desktop/mobile viewport measurements, reject false passes, measure autonomous completion without counting deterministic tools as Skills, and bind final human decisions to registered actions and scoped targets." @("Run tools\validate-r7-h5-viewport-autonomy.ps1 and repair viewport, evidence, autonomy, or final-human-gate drift.") "r7"))

  $r7H5APath=Join-Path $target 'tools\validate-r7-h5a-direct-sequence.ps1';$r7H5AStatus='pass';$r7H5AEvidence=@()
  if(Test-Path -LiteralPath $r7H5APath){& $r7H5APath -WorkRoot (Join-Path $defaultReportRoot '.r7h5a') -HumanReportPath (Join-Path $checkerReportRoot 'r7-h5a-direct-sequence-report.md') -MachineReportPath (Join-Path $checkerReportRoot 'r7-h5a-direct-sequence-report.json')|Out-Null;if(-not $?){$r7H5AStatus='fail';$r7H5AEvidence=@('checker-reports\r7-h5a-direct-sequence-report.json')}}else{$r7H5AStatus='fail';$r7H5AEvidence=@('tools\validate-r7-h5a-direct-sequence.ps1','templates\schema\p0\session-execution-plan.v0.7.schema.json','templates\schema\r7\semantic-task-envelope.v0.2.schema.json','compatibility\legacy-r7\routes\r7-workflow-blueprints.yaml')}
  $items.Add((New-CheckItem "P3REL-050" "r7_h5a_direct_sequence_revision_guard" "blocker" $r7H5AStatus $r7H5AEvidence "R7-H5A must keep direct blueprint v0.1 historical, run v0.2 as baseline draft to semantic beat to structure to structure-bound beat, reject future references, and derive monotonic revisions from payload contracts." @("Run tools\validate-r7-h5a-direct-sequence.ps1 and repair direct sequence, phase, lineage, or revision drift.") "r7"))

  $r7H6APath=Join-Path $target 'tools\validate-r7-h6a-hotspot-front-chain.ps1';$r7H6AStatus='pass';$r7H6AEvidence=@()
  if(Test-Path -LiteralPath $r7H6APath){& $r7H6APath -WorkRoot (Join-Path $defaultReportRoot '.r7h6a') -HumanReportPath (Join-Path $checkerReportRoot 'r7-h6a-hotspot-report.md') -MachineReportPath (Join-Path $checkerReportRoot 'r7-h6a-hotspot-report.json')|Out-Null;if(-not $?){$r7H6AStatus='fail';$r7H6AEvidence=@('checker-reports\r7-h6a-hotspot-report.json')}}else{$r7H6AStatus='fail';$r7H6AEvidence=@('tools\validate-r7-h6a-hotspot-front-chain.ps1','tools\R7HotspotContractHelper.ps1','tools\R7HotspotRuntime.ps1','examples\r7-h6a-hotspot-fixtures','templates\schema\p0\session-execution-plan.v0.8.schema.json')}
  $items.Add((New-CheckItem "P3REL-051" "r7_h6a_hotspot_front_chain" "blocker" $r7H6AStatus $r7H6AEvidence "R7-H6A must execute the offline request-to-draft hotspot front chain, preserve one artifact per node, keep topic evidence immutable, and reject request, panel, decision, source, Brief, structure, draft, digest and risk contract violations." @("Run tools\validate-r7-h6a-hotspot-front-chain.ps1 and repair the versioned hotspot front-chain contract without claiming H6B/H6C delivery or real regression.") "r7"))

  $r7H6BPath=Join-Path $target 'tools\validate-r7-h6b-freshness-delivery.ps1';$r7H6BStatus='pass';$r7H6BEvidence=@()
  if(Test-Path -LiteralPath $r7H6BPath){& $r7H6BPath -WorkRoot (Join-Path $defaultReportRoot '.r7h6b') -HumanReportPath (Join-Path $checkerReportRoot 'r7-h6b-freshness-report.md') -MachineReportPath (Join-Path $checkerReportRoot 'r7-h6b-freshness-report.json')|Out-Null;if(-not $?){$r7H6BStatus='fail';$r7H6BEvidence=@('checker-reports\r7-h6b-freshness-report.json')}}else{$r7H6BStatus='fail';$r7H6BEvidence=@('tools\validate-r7-h6b-freshness-delivery.ps1','tools\R7HotspotFreshnessRuntime.ps1','templates\schema\r7\topic-freshness-review.v0.1.schema.json','templates\schema\final-delivery\typed-components.v0.7.schema.json')}
  $items.Add((New-CheckItem "P3REL-052" "r7_h6b_freshness_replan_delivery_v07" "blocker" $r7H6BStatus $r7H6BEvidence "R7-H6B must keep freshness review and apply separate, preserve unassessed waits, version selected-source revisions, replan from the correct semantic boundary, and compile hotspot delivery v0.7 without changing direct v0.6 replay." @("Run tools\validate-r7-h6b-freshness-delivery.ps1 and repair freshness, replan, source binding, tagged-union, renderer, or recovery drift.") "r7"))

  $jointVisualRevisionPath=Join-Path $target 'tools\validate-joint-visual-revision-contract.ps1';$jointVisualRevisionFixture=Join-Path $target 'examples\joint-visual-revision-fixtures\fixtures.json';$jointVisualRevisionStatus='pass';$jointVisualRevisionEvidence=@()
  if((Test-Path -LiteralPath $jointVisualRevisionPath)-and(Test-Path -LiteralPath $jointVisualRevisionFixture)){& $jointVisualRevisionPath -FixturePath $jointVisualRevisionFixture -ReportPath (Join-Path $checkerReportRoot 'joint-visual-revision-contract-report.json') -WorkRoot (Join-Path $checkerReportRoot 'joint-visual-revision-work')|Out-Null;if(-not $?){$jointVisualRevisionStatus='fail';$jointVisualRevisionEvidence=@('checker-reports\joint-visual-revision-contract-report.json')}}else{$jointVisualRevisionStatus='fail';$jointVisualRevisionEvidence=@('tools\validate-joint-visual-revision-contract.ps1','examples\joint-visual-revision-fixtures\fixtures.json')}
  $items.Add((New-CheckItem "P3REL-053" "joint_evidence_visual_source_and_human_revision_contract" "blocker" $jointVisualRevisionStatus $jointVisualRevisionEvidence "R6 v0.2 evidence parity, R3 exclusive source routing, and R7 v0.9 human-scoped nonterminal revision must remain executable in the public package." @("Run tools\validate-joint-visual-revision-contract.ps1 and repair the failing contract, runtime, fixture, or renderer layer.") "r6-r3-r7"))

  $r7H7Path=Join-Path $target 'tools\validate-r7-h7-delivery-contract.ps1';$r7H7Status='pass';$r7H7Evidence=@()
  if(Test-Path -LiteralPath $r7H7Path){& $r7H7Path -ProjectRoot $target|Out-Null;$r7H7Succeeded=$?;if(-not$r7H7Succeeded){$r7H7Status='fail';$r7H7Evidence=@('state\checks\r7-h7-delivery-contract-report.json')}}else{$r7H7Status='fail';$r7H7Evidence=@('tools\validate-r7-h7-delivery-contract.ps1','tools\R7H7DeliveryContract.ps1','templates\schema\r7\business-delivery-acceptance.v0.1.schema.json')}
  $items.Add((New-CheckItem "P3REL-054" "r7_h7_final_asset_and_business_delivery_contract" "blocker" $r7H7Status $r7H7Evidence "R7-H7 must finalize one immutable delivery asset set, render the current v0.9 business-first HTML, preserve separate technical viewport evidence, and require an explicit business acceptance decision." @("Run tools\validate-r7-h7-delivery-contract.ps1 and repair finalization, rendering, viewport, or business-acceptance drift.") "r7"))

  $r7CliExitPath=Join-Path $target 'tools\validate-r7-cli-exit-contract.ps1';$r7CliExitStatus='pass';$r7CliExitEvidence=@()
  if(Test-Path -LiteralPath $r7CliExitPath){& $r7CliExitPath -ReportRoot 'state/checks/public-r7-cli-exit-contract'|Out-Null;$r7CliExitSucceeded=$?;if(-not$r7CliExitSucceeded){$r7CliExitStatus='fail';$r7CliExitEvidence=@('state\checks\public-r7-cli-exit-contract')}}else{$r7CliExitStatus='fail';$r7CliExitEvidence=@('tools\validate-r7-cli-exit-contract.ps1')}
  $items.Add((New-CheckItem "P3REL-055" "r7_cli_exit_code_contract" "blocker" $r7CliExitStatus $r7CliExitEvidence "R7 child-process wrappers must preserve real nonzero exit codes so a failed checker cannot be reported as successful." @("Run tools\validate-r7-cli-exit-contract.ps1 and repair child-process exit propagation.") "r7"))

  $r7BodyRenditionPath=Join-Path $target 'tools\validate-r7-body-rendition.ps1';$r7BodyRenditionStatus='pass';$r7BodyRenditionEvidence=@()
  if(Test-Path -LiteralPath $r7BodyRenditionPath){
    try {
      & $r7BodyRenditionPath -ProjectRoot $target -ReportPath (Join-Path $checkerReportRoot 'r7-body-rendition-report.json')|Out-Null
      if(-not $?){$r7BodyRenditionStatus='fail';$r7BodyRenditionEvidence=@('checker-reports\r7-body-rendition-report.json')}
    } catch {
      $r7BodyRenditionStatus='fail';$r7BodyRenditionEvidence=@('checker-reports\r7-body-rendition-report.json',$_.Exception.Message)
    }
  }else{$r7BodyRenditionStatus='fail';$r7BodyRenditionEvidence=@('tools\invoke-r7-body-rendition.ps1','tools\validate-r7-body-rendition.ps1')}
  $items.Add((New-CheckItem "P3REL-056" "r7_body_image_rendition" "blocker" $r7BodyRenditionStatus $r7BodyRenditionEvidence "The public package must execute the registered deterministic body-image rendition and prove target-canvas output plus idempotent reconcile." @("Run tools\validate-r7-body-rendition.ps1 and repair the public runtime closure or rendition fixture.") "r7"))

  $versionEvidence = New-Object System.Collections.Generic.List[string]
  $releaseStateEvidence = New-Object System.Collections.Generic.List[string]
  $versionStatus = "pass"
  $releaseStateStatus = "pass"
  $versionPath = Join-Path $target "VERSION"
  $manifestPath = Join-Path $target "public-manifest.yaml"
  $checklistPath = Join-Path $target "release-checklist.md"
  $releaseRecordPath = Join-Path $target "release-record.json"
  $releaseNotesPath = Join-Path $target "RELEASE_NOTES.md"
  $changelogPath = Join-Path $target "CHANGELOG.md"
  $candidateReleaseStateResult = 'unknown'
  $candidateSourceCommit = ''
  $expectedVersion = ""
  if (Test-Path -LiteralPath $versionPath) {
    $expectedVersion = (Get-Content -LiteralPath $versionPath -Raw -Encoding UTF8).Trim()
  }
  if ([string]::IsNullOrWhiteSpace($expectedVersion)) {
    $versionStatus = "fail"
    $versionEvidence.Add("VERSION empty")
  }
  foreach ($path in @($manifestPath, $releaseNotesPath, $changelogPath)) {
    if (Test-Path -LiteralPath $path) {
      $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8
      if (-not [string]::IsNullOrWhiteSpace($expectedVersion) -and -not $content.Contains($expectedVersion)) {
        $versionStatus = "fail"
        $versionEvidence.Add((Get-RelativePathSafe $target $path))
      }
    }
  }
  $manifestTextForCommit = ''
  $checklistText = ''
  if (Test-Path -LiteralPath $manifestPath) {
    $manifestTextForCommit = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
  } else {
    $versionStatus = 'fail'
    $versionEvidence.Add('public-manifest.yaml missing')
  }
  if (Test-Path -LiteralPath $checklistPath) {
    $checklistText = Get-Content -LiteralPath $checklistPath -Raw -Encoding UTF8
  } else {
    $versionStatus = 'fail'
    $versionEvidence.Add('release-checklist.md missing')
  }
  if (Test-Path -LiteralPath $releaseRecordPath) {
    try {
      $releaseRecord = Get-Content -LiteralPath $releaseRecordPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $record = $releaseRecord.release_record
      $candidateReleaseStateResult = [string]$record.release_state
      $candidateSourceCommit = [string]$record.commit_hash
      if ($record.version -ne $expectedVersion) {
        $versionStatus = "fail"
        $versionEvidence.Add("release-record.json version")
      }
      $manifestVersion = Get-CandidateMetadataField $manifestTextForCommit 'version'
      $checklistVersion = Get-CandidateMetadataField $checklistText 'version'
      if ($manifestVersion -ne $expectedVersion) {
        $versionStatus = 'fail'
        $versionEvidence.Add('public-manifest/VERSION mismatch')
      }
      if ($checklistVersion -ne $expectedVersion) {
        $versionStatus = 'fail'
        $versionEvidence.Add('release-checklist/VERSION mismatch')
      }
      $manifestSourceCommit = Get-CandidateMetadataField $manifestTextForCommit 'source_commit'
      $checklistSourceCommit = Get-CandidateMetadataField $checklistText 'source_commit'
      if (
        [string]::IsNullOrWhiteSpace($manifestSourceCommit) -or
        [string]::IsNullOrWhiteSpace($checklistSourceCommit) -or
        [string]$record.commit_hash -ne $manifestSourceCommit -or
        [string]$record.commit_hash -ne $checklistSourceCommit
      ) {
        $versionStatus = 'fail'
        $versionEvidence.Add('release-record/manifest/checklist source_commit mismatch')
      }
      $manifestTagName = Get-CandidateMetadataField $manifestTextForCommit 'tag_name_when_published'
      $checklistTagName = Get-CandidateMetadataField $checklistText 'tag_name_when_published'
      if ([string]$record.tag_name -ne $manifestTagName -or [string]$record.tag_name -ne $checklistTagName) {
        $versionStatus = 'fail'
        $versionEvidence.Add('release-record/manifest/checklist tag mismatch')
      }

      $manifestReleaseState = Get-CandidateMetadataField $manifestTextForCommit 'release_state'
      $manifestPublishStatus = Get-CandidateMetadataField $manifestTextForCommit 'publish_status'
      $manifestHumanApproval = (Get-CandidateMetadataField $manifestTextForCommit 'human_approval_required').ToLowerInvariant()
      $manifestRemoteConfirmed = (Get-CandidateMetadataField $manifestTextForCommit 'github_remote_confirmed').ToLowerInvariant()
      $manifestTagConfirmed = (Get-CandidateMetadataField $manifestTextForCommit 'tag_confirmed').ToLowerInvariant()
      $manifestPushed = (Get-CandidateMetadataField $manifestTextForCommit 'pushed_to_github').ToLowerInvariant()
      $checklistReleaseState = Get-CandidateMetadataField $checklistText 'release_state'
      $checklistPublishStatus = Get-CandidateMetadataField $checklistText 'publish_status'
      $checklistHumanApproval = (Get-CandidateMetadataField $checklistText 'human_approval_required').ToLowerInvariant()
      $checklistValidatorStatus = Get-CandidateMetadataField $checklistText 'validator_status'
      $checklistValidatorCount = Get-CandidateMetadataField $checklistText 'validator_check_count'
      if (
        [string]$record.release_state -ne 'release_candidate_built' -or
        [string]$record.publish_status -ne 'not_published' -or
        [bool]$record.human_approval_required -ne $true -or
        -not [string]::IsNullOrWhiteSpace([string]$record.remote_url) -or
        [string]$record.next_skill -ne 'human_confirm'
      ) {
        $releaseStateStatus = 'fail'
        $releaseStateEvidence.Add('release-record candidate tuple invalid')
      }
      if (
        $manifestReleaseState -ne 'release_candidate_built' -or
        $manifestPublishStatus -ne 'not_published' -or
        $manifestHumanApproval -ne 'true' -or
        $manifestRemoteConfirmed -ne 'false' -or
        $manifestTagConfirmed -ne 'false' -or
        $manifestPushed -ne 'false'
      ) {
        $releaseStateStatus = 'fail'
        $releaseStateEvidence.Add('public-manifest candidate tuple invalid')
      }
      if (
        $checklistReleaseState -ne 'release_candidate_built' -or
        $checklistPublishStatus -ne 'not_published' -or
        $checklistHumanApproval -ne 'true' -or
        $checklistValidatorStatus -ne 'not_run' -or
        $checklistValidatorCount -ne 'not_run'
      ) {
        $releaseStateStatus = 'fail'
        $releaseStateEvidence.Add('release-checklist candidate tuple invalid')
      }
      if ($checklistText -match '(?i)github_release_published|published_to_github|\d+\s+public checks passed|completed success') {
        $releaseStateStatus = 'fail'
        $releaseStateEvidence.Add('release-checklist contains historical publication or validator success claim')
      }
      $recordText = Get-Content -LiteralPath $releaseRecordPath -Raw -Encoding UTF8
      if ($recordText -match '(?i)[A-Z]:[\\/](?:OpenClaw|Users)(?:[\\/]|$)' -or $recordText.Contains("file://")) {
        $releaseStateStatus = "fail"
        $releaseStateEvidence.Add("release-record.json contains local path")
      }
    } catch {
      $releaseStateStatus = "fail"
      $releaseStateEvidence.Add("release-record.json parse failed: " + $_.Exception.Message)
    }
  } else {
    $versionStatus = "fail"
    $versionEvidence.Add("release-record.json missing")
  }
  $items.Add((New-CheckItem "P5REL-001" "release_state_check" "blocker" $versionStatus @($versionEvidence) "VERSION, manifest, checklist, changelog, release notes, and release record must agree on candidate identity." @("Regenerate manifest and checklist from candidate-safe templates on the clean source HEAD.") "release"))
  $items.Add((New-CheckItem "P5REL-002" "release_state_check" "blocker" $releaseStateStatus @($releaseStateEvidence) "Manifest, checklist, and release record must all remain release_candidate_built/not_published and must not inherit historical publication evidence." @("Regenerate candidate metadata; never copy a published checklist into a new candidate.") "release"))

  $duplicateCheckItemIds = @($items | Group-Object check_item_id | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
  $items.Add((New-CheckItem "P3REL-058" "validator_index_integrity" "blocker" ($(if ($duplicateCheckItemIds.Count) { "fail" } else { "pass" })) @($duplicateCheckItemIds) "Every public validator check item id must be unique before the report is finalized." @("Assign a new stable check id; never hide a duplicate by relying on report order.") "release"))

  $zipStatus = "not_applicable"
  $zipEvidence = @()
  if (-not [string]::IsNullOrWhiteSpace($ZipPath) -or -not [string]::IsNullOrWhiteSpace($Sha256Path)) {
    if ((-not (Test-Path -LiteralPath $ZipPath)) -or (-not (Test-Path -LiteralPath $Sha256Path))) {
      $zipStatus = "fail"
      $zipEvidence = @($ZipPath, $Sha256Path)
    } else {
      $actual = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
      $record = (Get-Content -LiteralPath $Sha256Path -Raw -Encoding ASCII).ToLowerInvariant()
      $zipStatus = $(if ($record.Contains($actual)) { "pass" } else { "fail" })
      $zipEvidence = @($ZipPath, $Sha256Path)
    }
  }
  $items.Add((New-CheckItem "P3REL-007" "release_package" "blocker" $zipStatus $zipEvidence "Zip sha256 must match when provided." @("Regenerate zip and sha256 together.") "release"))

  $blockers = @($items | Where-Object { $_.severity -eq "blocker" -and $_.status -eq "fail" })
  $warnings = @($items | Where-Object { $_.severity -eq "warn" -and $_.status -eq "fail" })
  $overall = if ($blockers.Count -gt 0) { "fail" } elseif ($warnings.Count -gt 0) { "pass_with_warnings" } else { "pass" }
  $exitCode = if ($blockers.Count -gt 0) { 1 } else { 0 }
  $privacyResult = if (($privateHits.Count + $secretHits.Count) -eq 0) { "pass" } else { "fail" }
  $linkResult = if ($brokenLinks.Count -eq 0) { "pass" } else { "fail" }
  $fieldResult = if ($missingFields.Count -eq 0 -and $schemaStatus -eq "pass") { "pass" } else { "fail" }
  $nextAction = if ($overall -eq "pass") { "human_review_or_release_decision" } else { "fix_blockers_and_rerun" }
  $artifactManifestPath = Join-Path $target "public-manifest.yaml"
  $machineReportDisplayPath = Split-Path -Leaf $MachineReportPath
  $humanReportDisplayPath = Split-Path -Leaf $HumanReportPath
  $blockerIds = [object[]]@($blockers | ForEach-Object { $_.check_item_id })
  $warningIds = [object[]]@($warnings | ForEach-Object { $_.check_item_id })
  $allEvidencePaths = @()
  $allRemediationItems = @()
  foreach ($item in $items) {
    $allEvidencePaths += @($item.evidence_paths)
    $allRemediationItems += @($item.remediation_items)
  }
  $filteredEvidencePaths = [object[]]@($allEvidencePaths | Where-Object { $_ })
  $filteredRemediationItems = [object[]]@($allRemediationItems | Where-Object { $_ })

  $checkItems = [object[]]$items.ToArray()
  $report = [ordered]@{
    release_check_report = [ordered]@{
      check_report_id = "RELEASE-CHECK-" + (Get-Date -Format "yyyyMMdd-HHmmss")
      check_scope = "public_release"
      check_run_id = $checkRunId
      command_name = "validate-public-release"
      command_version = "p3-validator-v0.1"
      exit_code = $exitCode
      severity_policy = "blocker_fails"
      checked_at = (Get-Date).ToString("s")
      checked_by = "tools/validate-public-release.ps1"
      input_path = $inputTarget
      overall_result = $overall
      blocker_count = $blockers.Count
      warning_count = $warnings.Count
      check_count = $checkItems.Count
      blockers = $blockerIds
      warnings = $warningIds
      info_items = @()
      evidence_paths = $filteredEvidencePaths
      remediation_items = $filteredRemediationItems
      machine_readable_report_path = $machineReportDisplayPath
      human_readable_report_path = $humanReportDisplayPath
      artifact_manifest_path = (Join-Path $inputTarget "public-manifest.yaml")
      reproducibility_status = "reproducible"
      privacy_scan_result = $privacyResult
      link_check_result = $linkResult
      field_gate_result = $fieldResult
      contract_sync_result = $fieldResult
      image_asset_check_result = "not_run"
      release_state_result = $candidateReleaseStateResult
      source_commit = $candidateSourceCommit
      zip_path = $ZipPath
      sha256_path = $Sha256Path
      artifact_path = $HumanReportPath
      next_action = $nextAction
      checks = $checkItems
    }
  }

  Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 8

  $lines = @()
  $lines += "# Release Check Report"
  $lines += ""
  $lines += '```yaml'
  $lines += "check_run_id: $checkRunId"
  $lines += "command_name: validate-public-release"
  $lines += "command_version: p3-validator-v0.1"
  $lines += "exit_code: $exitCode"
  $lines += "overall_result: $overall"
  $lines += "blocker_count: $($blockers.Count)"
  $lines += "warning_count: $($warnings.Count)"
  $lines += "machine_readable_report_path: $machineReportDisplayPath"
  $lines += "human_readable_report_path: $humanReportDisplayPath"
  $lines += '```'
  $lines += ""
  $lines += "| Check ID | Group | Severity | Status | Evidence | Remediation |"
  $lines += "|---|---|---|---|---|---|"
  foreach ($item in $items) {
    $evidenceText = [string]::Join('; ', @($item.evidence_paths))
    $remediationText = [string]::Join('; ', @($item.remediation_items))
    $row = '| {0} | {1} | {2} | {3} | {4} | {5} |' -f $item.check_item_id, $item.group, $item.severity, $item.status, $evidenceText, $remediationText
    $lines += $row
  }
  $lines += ""
  $lines += "## Result"
  $lines += ""
  $lines += $(if ($overall -eq "pass") { "No blocker found. This is still a release candidate, not a GitHub release." } else { "Blockers found. Fix them and rerun validate-public-release." })
  Write-TaogeUtf8NoBomLines -Path $HumanReportPath -Lines $lines

  if (-not [string]::IsNullOrWhiteSpace($validationSandbox) -and (Test-Path -LiteralPath $validationSandbox)) {
    Remove-Item -LiteralPath $validationSandbox -Recurse -Force
  }
  exit $exitCode
} catch {
  if (-not [string]::IsNullOrWhiteSpace($validationSandbox) -and (Test-Path -LiteralPath $validationSandbox)) {
    Remove-Item -LiteralPath $validationSandbox -Recurse -Force -ErrorAction SilentlyContinue
  }
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}



