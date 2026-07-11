param(
  [string]$TargetPath = "",
  [string]$HumanReportPath = "",
  [string]$MachineReportPath = "",
  [string]$ZipPath = "",
  [string]$Sha256Path = ""
)

$ErrorActionPreference = "Stop"

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

function Test-MarkdownLinks {
  param([string]$RootPath)
  $broken = New-Object System.Collections.Generic.List[string]
  Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter *.md | ForEach-Object {
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

try {
  if ([string]::IsNullOrWhiteSpace($TargetPath)) {
    $versionedPublicReleasePath = "releases\v0.1.0-alpha.2\public_release"
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

  $target = (Resolve-Path -LiteralPath $TargetPath).Path
  if ([string]::IsNullOrWhiteSpace($HumanReportPath)) {
    $HumanReportPath = Join-Path $target "release-check-report.md"
  }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
    $MachineReportPath = Join-Path $target "release-check-report.json"
  }

  $checkRunId = "CHECKRUN-" + (Get-Date -Format "yyyyMMdd-HHmmss")
  $items = New-Object System.Collections.Generic.List[object]

  $required = @(
    "README.md", "AGENTS.md", "PROJECT_MAP.md", "public-manifest.yaml", "VERSION",
    "LICENSE", "CONTRIBUTING.md", "CHANGELOG.md", "SECURITY.md", "CODE_OF_CONDUCT.md",
    "INSTALL.md", "UPDATE.md", "RELEASE_NOTES.md", "NOTICE.md", "release-checklist.md", "release-record.json"
  )
  $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $target $_)) })
  $items.Add((New-CheckItem "P3REL-001" "release_package" "blocker" ($(if ($missing.Count) { "fail" } else { "pass" })) @($missing) "Required public release entry files." @("Add missing required public release files.") "release"))

  $accountsPath = Join-Path $target "accounts"
  $items.Add((New-CheckItem "P3REL-002" "privacy_security" "blocker" ($(if (Test-Path -LiteralPath $accountsPath) { "fail" } else { "pass" })) @("accounts") "Public package must not contain real accounts directory." @("Remove accounts/ from public_release and use examples/sample-account instead.") "privacy"))

  $textFiles = Get-ChildItem -LiteralPath $target -Recurse -File | Where-Object {
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
  $localDrive = 'D:' + '\OpenClaw'
  $localDriveSlash = 'D:' + '/OpenClaw'
  $userHome = 'C:' + '\Users'
  $fileUrl = 'file' + '://'
  $privatePatterns = @(
    $taogePrefix + "行业观察", $taogePrefix + "帮提车", $taogePrefix + "本地经营者自媒", $taogePrefix + "说真话",
    $privateSessionPrefix, $privateSessionOne, $localDrive, $localDriveSlash, $userHome, $fileUrl
  )
  $privateHits = @($privatePatterns | Where-Object { $textJoined.Contains($_) })
  $items.Add((New-CheckItem "P3REL-003" "privacy_security" "blocker" ($(if ($privateHits.Count) { "fail" } else { "pass" })) $privateHits "No real account names, original session ids, local paths, or file URLs." @("Sanitize public_release text and replace real data with sample placeholders.") "privacy"))

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
    & $schemaScriptPath -TargetPath $target -SchemaPath $schemaPath -HumanReportPath (Join-Path $target "field-schema-check-report.md") -MachineReportPath (Join-Path $target "field-schema-check-report.json") | Out-Null
    if ($LASTEXITCODE -ne 0) {
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
    & $regressionScriptPath -SuitePath "examples\regression-suite.yaml" -HumanReportPath (Join-Path $target "examples\regression-suite-report.md") -MachineReportPath (Join-Path $target "examples\regression-suite-report.json") | Out-Null
    if ($LASTEXITCODE -ne 0) {
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
    & $ciScriptPath -WorkflowPath ".github\workflows\public-release-candidate-check.yml" -HumanReportPath (Join-Path $target "ci-workflow-check-report.md") -MachineReportPath (Join-Path $target "ci-workflow-check-report.json") | Out-Null
    if ($LASTEXITCODE -ne 0) {
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
    & $alphaScriptPath -TargetPath $target -HumanReportPath (Join-Path $target "alpha-expression-check-report.md") -MachineReportPath (Join-Path $target "alpha-expression-check-report.json") | Out-Null
    if ($LASTEXITCODE -ne 0) {
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
    & $routeScriptPath -ProjectRoot $target -HumanReportPath (Join-Path $target "state\checks\route-schema-check-report.md") -MachineReportPath (Join-Path $target "state\checks\route-schema-check-report.json") | Out-Null
    if ($LASTEXITCODE -ne 0) {
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
    if ($LASTEXITCODE -ne 0) {
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
    & $visualTextScriptPath -FixturePath $visualTextFixturePath -HumanReportPath (Join-Path $target "state\checks\r3-visual-text-check-report.md") -MachineReportPath (Join-Path $target "state\checks\r3-visual-text-check-report.json") | Out-Null
    if ($LASTEXITCODE -ne 0) {
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
    & $p0H1ScriptPath -FixtureRoot $p0H1FixturePath.Replace('fixtures.json','') -SchemaRoot $p0H1SchemaPath -LegacyPlanSchemaPath (Join-Path $target 'templates\schema\p0-runtime.v0.1.json') -CompatibilityMatrixPath (Join-Path $p0H1SchemaPath 'compatibility-matrix.v0.2.json') -HumanReportPath (Join-Path $target 'state\checks\p0-h1-contract-check-report.md') -MachineReportPath (Join-Path $target 'state\checks\p0-h1-contract-check-report.json') | Out-Null
    if ($LASTEXITCODE -ne 0) {
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
    & $p0H2ScriptPath -ReportPath 'state/checks/p0-h2-runtime-report.json' | Out-Null
    if ($LASTEXITCODE -ne 0) {
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
    & $p0H3ScriptPath -FixtureRoot $p0H3FixturePath -ReportPath (Join-Path $target 'state\checks\p0-h3-fixture-report.json') | Out-Null
    if ($LASTEXITCODE -ne 0) {
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
    & $p0H4ScriptPath -FixturePath $p0H4FixturePath -ReportPath (Join-Path $target 'state\checks\p0-h4-evidence-report.json') | Out-Null
    if ($LASTEXITCODE -ne 0) {
      $p0H4Status = "fail"
      $p0H4Evidence = @("state\checks\p0-h4-evidence-report.json")
    }
  } else {
    $p0H4Status = "fail"
    $p0H4Evidence = @("tools\P0EvidenceRuntime.ps1", "tools\invoke-p0-evidence.ps1", "tools\validate-p0-h4-evidence.ps1", "examples\p0-h4-evidence-fixture", "templates\schema\p0-h4")
  }
  $items.Add((New-CheckItem "P3REL-018" "p0_h4_evidence_runtime" "blocker" $p0H4Status $p0H4Evidence "P0-H4 unified event writer, evidence commands, projection rebuild, and orphan reconciliation must pass in the public package." @("Run tools/validate-p0-h4-evidence.ps1 and fix P0-H4 evidence runtime blockers.") "p0"))

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
    & $r3BudgetScriptPath -FixturePath $r3BudgetFixturePath -ReportPath (Join-Path $target 'state\checks\r3-visual-budget-report.json') | Out-Null
    if ($LASTEXITCODE -ne 0) { $r3BudgetStatus='fail'; $r3BudgetEvidence=@('state\checks\r3-visual-budget-report.json') }
  } else { $r3BudgetStatus='fail'; $r3BudgetEvidence=@('tools\validate-r3-visual-budget.ps1','templates\schema\r3\visual-budget.v0.1.schema.json','examples\r3-visual-budget-fixtures\fixtures.json') }
  $items.Add((New-CheckItem "P3REL-020" "r3_visual_budget_legacy_compatibility" "blocker" $r3BudgetStatus $r3BudgetEvidence "The superseded visual-budget schema and fixtures remain readable for history-only compatibility." @("Run tools/validate-r3-visual-budget.ps1 and repair legacy compatibility without restoring it as the current product gate.") "r3"))

  $r3NeedScriptPath = Join-Path $target "tools\validate-r3-visual-need.ps1"
  $r3NeedFixturePath = Join-Path $target "examples\r3-visual-need-fixtures\fixtures.json"
  $r3NeedSchemaPath = Join-Path $target "templates\schema\r3\visual-need-analysis.v0.1.schema.json"
  $r3NeedStatus = 'pass'; $r3NeedEvidence = @()
  if ((Test-Path -LiteralPath $r3NeedScriptPath) -and (Test-Path -LiteralPath $r3NeedFixturePath) -and (Test-Path -LiteralPath $r3NeedSchemaPath)) {
    & $r3NeedScriptPath -FixturePath $r3NeedFixturePath -ReportPath (Join-Path $target 'state\checks\r3-visual-need-report.json') | Out-Null
    if ($LASTEXITCODE -ne 0) { $r3NeedStatus='fail'; $r3NeedEvidence=@('state\checks\r3-visual-need-report.json') }
  } else { $r3NeedStatus='fail'; $r3NeedEvidence=@('tools\validate-r3-visual-need.ps1','templates\schema\r3\visual-need-analysis.v0.1.schema.json','examples\r3-visual-need-fixtures\fixtures.json') }
  $items.Add((New-CheckItem "P3REL-021" "r3_visual_need_contract" "blocker" $r3NeedStatus $r3NeedEvidence "R3-C71 to C80 content-derived 0-to-N visual need analysis, generate/reject mapping, and unbounded Image 2 policy must pass." @("Run tools/validate-r3-visual-need.ps1 and repair any product-to-code sink mismatch.") "r3"))

  $p0H6CompletePath = Join-Path $target 'tools\complete-p0-h6-regression.ps1'
  $p0H6ValidatorPath = Join-Path $target 'tools\validate-p0-h6-regression.ps1'
  $p0H6Status = 'pass'; $p0H6Evidence = @()
  if (-not (Test-Path -LiteralPath $p0H6CompletePath) -or -not (Test-Path -LiteralPath $p0H6ValidatorPath)) {
    $p0H6Status='fail'; $p0H6Evidence=@('tools\complete-p0-h6-regression.ps1','tools\validate-p0-h6-regression.ps1')
  } else {
    $completeText=Get-Content -LiteralPath $p0H6CompletePath -Raw -Encoding UTF8
    $validatorText=Get-Content -LiteralPath $p0H6ValidatorPath -Raw -Encoding UTF8
    $requiredComplete=@('codex_builtin_image2','actual_provider_execution_count','runtime_model_profile: not_observable','pending_h6_validation')
    $requiredValidator=@('provider_execution_matches_accepted','render_uses_h6_revision','trace_hashes_current','runtime_validate_completed')
    $missing=@($requiredComplete|Where-Object{$completeText-notmatch[regex]::Escape($_)})+@($requiredValidator|Where-Object{$validatorText-notmatch[regex]::Escape($_)})
    if($missing.Count){$p0H6Status='fail';$p0H6Evidence=@($missing|ForEach-Object{"missing_signal:$_"})}
  }
  $items.Add((New-CheckItem "P3REL-022" "p0_h6_real_image_regression_boundary" "blocker" $p0H6Status $p0H6Evidence "P0-H6 source must bind accepted tasks to actual Image 2 executions, select the H6 render revision, refresh trace hashes, and avoid claiming an unobservable runtime model profile." @("Restore H6 completion and validation signals without bundling private accounts or generated assets.") "p0"))

  $versionEvidence = New-Object System.Collections.Generic.List[string]
  $releaseStateEvidence = New-Object System.Collections.Generic.List[string]
  $versionStatus = "pass"
  $releaseStateStatus = "pass"
  $versionPath = Join-Path $target "VERSION"
  $manifestPath = Join-Path $target "public-manifest.yaml"
  $releaseRecordPath = Join-Path $target "release-record.json"
  $releaseNotesPath = Join-Path $target "RELEASE_NOTES.md"
  $changelogPath = Join-Path $target "CHANGELOG.md"
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
  if (Test-Path -LiteralPath $releaseRecordPath) {
    try {
      $releaseRecord = Get-Content -LiteralPath $releaseRecordPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $record = $releaseRecord.release_record
      if ($record.version -ne $expectedVersion) {
        $versionStatus = "fail"
        $versionEvidence.Add("release-record.json version")
      }
      if ($record.release_state -ne "github_release_published" -and $record.publish_status -eq "published_to_github") {
        $releaseStateStatus = "fail"
        $releaseStateEvidence.Add("release_state/publish_status conflict")
      }
      $recordText = Get-Content -LiteralPath $releaseRecordPath -Raw -Encoding UTF8
      if ($recordText.Contains("D:\OpenClaw") -or $recordText.Contains("D:/OpenClaw") -or $recordText.Contains("C:\Users") -or $recordText.Contains("file://")) {
        $releaseStateStatus = "fail"
        $releaseStateEvidence.Add("release-record.json contains local path")
      }
    } catch {
      $releaseStateStatus = "fail"
      $releaseStateEvidence.Add("release-record.json parse failed")
    }
  } else {
    $versionStatus = "fail"
    $versionEvidence.Add("release-record.json missing")
  }
  $items.Add((New-CheckItem "P5REL-001" "release_state_check" "blocker" $versionStatus @($versionEvidence) "VERSION, manifest, changelog, release notes, and release record must agree." @("Update VERSION, public-manifest.yaml, CHANGELOG.md, RELEASE_NOTES.md, and release-record.json together.") "release"))
  $items.Add((New-CheckItem "P5REL-002" "release_state_check" "blocker" $releaseStateStatus @($releaseStateEvidence) "Release state and publish status must not claim GitHub publication early." @("Keep publish_status=not_published until tag, push, and GitHub release are complete.") "release"))

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
      input_path = $target
      overall_result = $overall
      blocker_count = $blockers.Count
      warning_count = $warnings.Count
      blockers = $blockerIds
      warnings = $warningIds
      info_items = @()
      evidence_paths = $filteredEvidencePaths
      remediation_items = $filteredRemediationItems
      machine_readable_report_path = $machineReportDisplayPath
      human_readable_report_path = $humanReportDisplayPath
      artifact_manifest_path = $artifactManifestPath
      reproducibility_status = "reproducible"
      privacy_scan_result = $privacyResult
      link_check_result = $linkResult
      field_gate_result = $fieldResult
      contract_sync_result = $fieldResult
      image_asset_check_result = "not_run"
      release_state_result = "not_published"
      zip_path = $ZipPath
      sha256_path = $Sha256Path
      artifact_path = $HumanReportPath
      next_action = $nextAction
      checks = $checkItems
    }
  }

  $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $MachineReportPath -Encoding UTF8

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
  $lines | Set-Content -LiteralPath $HumanReportPath -Encoding UTF8

  exit $exitCode
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}



