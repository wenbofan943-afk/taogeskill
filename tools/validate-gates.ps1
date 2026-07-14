param(
  [string]$ProjectRoot = '',
  [string]$GateName = '',
  [string]$HumanReportPath = '',
  [string]$MachineReportPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')

function Add-GateCheck {
  param(
    [System.Collections.Generic.List[object]]$Checks,
    [string]$Id,
    [string]$Status,
    [string]$Evidence,
    [string]$Remediation
  )
  $Checks.Add([pscustomobject]@{
    check_item_id = $Id
    status = $Status
    evidence = $Evidence
    remediation = $Remediation
  })
}

try {
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
  }
  $root = (Resolve-Path -LiteralPath $ProjectRoot).Path
  $defaultReportDir = Join-Path $root "state\checks"

  if ([string]::IsNullOrWhiteSpace($HumanReportPath)) {
    $HumanReportPath = Join-Path $defaultReportDir "gate-check-report.md"
  }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
    $MachineReportPath = Join-Path $defaultReportDir "gate-check-report.json"
  }

  @($HumanReportPath, $MachineReportPath) | ForEach-Object {
    $reportDir = Split-Path -Parent $_
    if (-not [string]::IsNullOrWhiteSpace($reportDir) -and -not (Test-Path -LiteralPath $reportDir)) {
      New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
  }

  $checks = New-Object System.Collections.Generic.List[object]
  $checkRunId = "GATE-" + (Get-Date -Format "yyyyMMdd-HHmmss")

  $allGates = @('state_consistency_gate', 'branch_lock_gate', 'field_gate', 'product_contract_compilation_gate', 'runtime_smoke_gate', 'account_startup_gate', 'environment_compatibility_gate', 'document_graph_gate', 'sample_only_gate', 'public_privacy_gate', 'public_entry_document_gate')
  $targetGates = if ([string]::IsNullOrWhiteSpace($GateName)) { $allGates } else { @($GateName) }

  foreach ($gate in $targetGates) {
    switch ($gate) {
      'state_consistency_gate' {
        $statePath = Join-Path $root 'state/current-state.yaml'
        if (Test-Path -LiteralPath $statePath) {
          $stateContent = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8
          if ($stateContent -match 'latest_main_commit_known:\s*([a-f0-9]+)') {
            $recordedCommit = $matches[1]
            $actualCommit = & git -C $root rev-parse HEAD 2>$null
            if ($LASTEXITCODE -eq 0) {
              & git -C $root merge-base --is-ancestor $recordedCommit $actualCommit 2>$null
              $status = if ($LASTEXITCODE -eq 0) { 'pass' } else { 'fail' }
              Add-GateCheck $checks 'STATE-001' $status "recorded_ancestor=$recordedCommit actual=$actualCommit" "Update state/current-state.yaml if the recorded commit is not an ancestor of HEAD."
            } else {
              Add-GateCheck $checks 'STATE-001' 'fail' 'git rev-parse failed' 'Fix Git availability.'
            }
          } else {
            Add-GateCheck $checks 'STATE-001' 'fail' 'latest_main_commit_known missing' 'Add latest_main_commit_known to state/current-state.yaml.'
          }
        } else {
          Add-GateCheck $checks 'STATE-001' 'fail' 'state/current-state.yaml missing' 'Create state/current-state.yaml.'
        }

        $manifestPath = Join-Path $root '工作流状态记录.md'
        $manifestTemplatePath = Join-Path $root 'templates/state/工作流状态记录.template.md'
        if (Test-Path -LiteralPath $manifestPath) {
          Add-GateCheck $checks 'STATE-002' 'pass' '工作流状态记录.md exists' 'State record available.'
        } elseif (Test-Path -LiteralPath $manifestTemplatePath) {
          Add-GateCheck $checks 'STATE-002' 'pass' 'Local state not initialized; template exists' 'Initialize 工作流状态记录.md from the template before a real content run.'
        } else {
          Add-GateCheck $checks 'STATE-002' 'fail' 'Local state and template are both missing' 'Restore templates/state/工作流状态记录.template.md.'
        }
      }

      'branch_lock_gate' {
        $branchLockPath = Join-Path $root 'state/branch-lock.yaml'
        if (Test-Path -LiteralPath $branchLockPath) {
          $lockContent = Get-Content -LiteralPath $branchLockPath -Raw -Encoding UTF8
          if ($lockContent -match 'locked:\s*(true|false)') {
            $locked = $matches[1] -eq 'true'
            $status = if ($locked) { 'blocked' } else { 'pass' }
            Add-GateCheck $checks 'BRANCH-001' $status "branch_locked=$locked" 'Check branch lock before multi-branch run.'
          } else {
            Add-GateCheck $checks 'BRANCH-001' 'fail' 'locked field missing' 'Add locked field to state/branch-lock.yaml.'
          }
        } else {
          Add-GateCheck $checks 'BRANCH-001' 'pass' 'No branch lock file, proceeding' 'Branch lock is optional.'
        }
      }

      'field_gate' {
        $fieldSchemaPath = Join-Path $root 'templates/schema/field-schema.v0.1.json'
        if (Test-Path -LiteralPath $fieldSchemaPath) {
          Add-GateCheck $checks 'FIELD-001' 'pass' 'field-schema.v0.1.json exists' 'Field schema available.'
        } else {
          Add-GateCheck $checks 'FIELD-001' 'fail' 'field-schema.v0.1.json missing' 'Create templates/schema/field-schema.v0.1.json.'
        }

        $fieldDictPath = Join-Path $root '交接物字段词典.md'
        if (Test-Path -LiteralPath $fieldDictPath) {
          Add-GateCheck $checks 'FIELD-002' 'pass' '交接物字段词典.md exists' 'Field dictionary available.'
        } else {
          Add-GateCheck $checks 'FIELD-002' 'fail' '交接物字段词典.md missing' 'Create 交接物字段词典.md.'
        }
      }

      'product_contract_compilation_gate' {
        $checker = Join-Path $root 'tools/validate-r3-visual-need.ps1'
        if (-not (Test-Path -LiteralPath $checker -PathType Leaf)) {
          Add-GateCheck $checks 'PRODUCT-CONTRACT-001' 'fail' 'visual-need checker missing' 'Compile R3-C71 to C80 into a checker.'
        } else {
          & $checker -ReportPath (Join-Path $root 'state/checks/r3-visual-need-report.json') | Out-Null
          if ($?) { Add-GateCheck $checks 'PRODUCT-CONTRACT-001' 'pass' 'R3 visual need product contract is compiled across layers' 'Product contract compilation gate passed.' }
          else { Add-GateCheck $checks 'PRODUCT-CONTRACT-001' 'fail' 'R3 visual need product contract coverage failed' 'Run tools/validate-r3-visual-need.ps1 and repair missing sinks.' }
        }
        $reliabilitySources=@(
          @{path='交接物字段词典.md';tokens=@('provider_outcome_status','postprocess_status','reconciliation_status','reconcile_existing_output_before_retry')},
          @{path='templates/schema/field-schema.v0.1.json';tokens=@('provider_outcome_status','postprocess_status','reconciliation_status','interruption_recovery_policy')},
          @{path='skills/image-asset-producer/CONTRACT.md';tokens=@('Provider outcome is persisted','Checkers are read-only','Observed regression counts never become product constants')},
          @{path='tools/validate-p0-h6-regression.ps1';tokens=@('content_driven_cardinality','candidate_render_input_digest_match','receipt_contains_all_generated_assets')}
        );$missingReliability=New-Object System.Collections.Generic.List[string]
        foreach($source in $reliabilitySources){$sourcePath=Join-Path $root $source.path;if(-not(Test-Path -LiteralPath $sourcePath)){$missingReliability.Add("missing_file:$($source.path)");continue};$text=Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8;foreach($token in $source.tokens){if(-not$text.Contains($token)){$missingReliability.Add("$($source.path):$token")}}}
        Add-GateCheck $checks 'PRODUCT-CONTRACT-002' $(if($missingReliability.Count-eq0){'pass'}else{'fail'}) "r3_c81_c90_missing=$($missingReliability.Count);$([string]::Join('|',@($missingReliability)))" 'Compile R3-C81 to C90 across field dictionary, schema, contract, runtime, fixture, and checker.'
        $reliabilityChecker=Join-Path $root 'tools/validate-p0-h6-reliability.ps1';$reliabilityOutput=@(& $reliabilityChecker 2>&1);$reliabilitySucceeded=$?
        Add-GateCheck $checks 'PRODUCT-CONTRACT-003' $(if($reliabilitySucceeded-and$reliabilityOutput-contains'P0_H6_RELIABILITY_CHECK=pass'){'pass'}else{'fail'}) ([string]::Join(';',@($reliabilityOutput))) 'Repair P0-H6 reliability fixtures and executable checks.'
        $h7Sources=@(
          @{path='交接物字段词典.md';tokens=@('delivery_revision_id','platform_delivery_unit','insert_after_text','warning_item','duration_estimate_status','commit marker')},
          @{path='templates/schema/p0/typed-render-input.v0.4.schema.json';tokens=@('platform_delivery_units','visual_insert_cards','platform_delivery_scope_status')},
          @{path='tools/P0FinalDeliveryV04.ps1';tokens=@('delivery_revision_id','preview_evidence_type','revision_status')},
          @{path='tools/validate-p0-h7-v04-fixtures.ps1';tokens=@('false-visual-pass','preview-type','slot-bounds','idempotent')}
        );$missingH7=New-Object System.Collections.Generic.List[string];foreach($source in $h7Sources){$sourcePath=Join-Path $root $source.path;if(-not(Test-Path $sourcePath)){$missingH7.Add("missing_file:$($source.path)");continue};$text=Get-Content $sourcePath -Raw -Encoding UTF8;foreach($token in $source.tokens){if(-not$text.Contains($token)){$missingH7.Add("$($source.path):$token")}}}
        Add-GateCheck $checks 'PRODUCT-CONTRACT-004' $(if($missingH7.Count-eq0){'pass'}else{'fail'}) "p0_h7_missing=$($missingH7.Count);$([string]::Join('|',@($missingH7)))" 'Compile P0-H7 across field dictionary, Skill, schema, fixture, and checker.'
        $r6Checker=Join-Path $root 'tools/validate-r6-content-evidence.ps1';$r6Output=@(& $r6Checker -ReportPath (Join-Path $root 'state/checks/r6-content-evidence-report.json') 2>&1);$r6Succeeded=$?;$r6Text=[string]::Join(';',@($r6Output))
        Add-GateCheck $checks 'PRODUCT-CONTRACT-005' $(if($r6Succeeded-and$r6Text.Contains('R6_CONTENT_EVIDENCE_CHECK=pass')-and$r6Text.Contains('CASE_COUNT=17')){'pass'}else{'fail'}) $r6Text 'Compile R6-C01 to C19 across field dictionary, typed schemas, Skills, source-capture runtime, fixtures, final HTML and checker.'
        $visualPresentationChecker=Join-Path $root 'tools/validate-r3-visual-presentation.ps1';$visualPresentationOutput=@(& $visualPresentationChecker 2>&1);$visualPresentationSucceeded=$?;$visualPresentationText=[string]::Join(';',@($visualPresentationOutput))
        Add-GateCheck $checks 'PRODUCT-CONTRACT-006' $(if($visualPresentationSucceeded-and$visualPresentationText.Contains('R3_VISUAL_PRESENTATION_CHECK=pass')){'pass'}else{'fail'}) $visualPresentationText 'Compile R3-C91 to C124 across product fields, schemas, Skills, runtime, fixtures and checker.'
        $h7V04Checker=Join-Path $root 'tools/validate-p0-h7-v04-fixtures.ps1';$h7V04Output=@(& $h7V04Checker 2>&1);$h7V04Succeeded=$?;$h7V04Text=[string]::Join(';',@($h7V04Output))
        Add-GateCheck $checks 'PRODUCT-CONTRACT-007' $(if($h7V04Succeeded-and$h7V04Text.Contains('P0_H7_V04_FIXTURES=pass')){'pass'}else{'fail'}) $h7V04Text 'Keep the v0.4 typed compiler, renderer, visual review binding, delivery scope and fixtures replayable as history.'
        $r6ScriptVisualChecker=Join-Path $root 'tools/validate-r6-script-visual-contract.ps1';$r6ScriptVisualOutput=@(& $r6ScriptVisualChecker -ReportPath (Join-Path $root 'state/checks/r6-script-visual-contract-report.json') 2>&1);$r6ScriptVisualSucceeded=$?;$r6ScriptVisualText=[string]::Join(';',@($r6ScriptVisualOutput))
        Add-GateCheck $checks 'PRODUCT-CONTRACT-008' $(if($r6ScriptVisualSucceeded-and$r6ScriptVisualText.Contains('R6_SCRIPT_VISUAL_FIXTURE_RESULT=pass')-and$r6ScriptVisualText.Contains('R6_SCRIPT_VISUAL_FIXTURE_CASES=34')){'pass'}else{'fail'}) $r6ScriptVisualText 'Compile R6-C20-C50 and R3-C125-C139 across source-aware draft, structure, beat, review/decision, full visual coverage, current pointer and negative fixtures.'
        $p0R6V05Checker=Join-Path $root 'tools/validate-p0-r6-v05-fixtures.ps1';$p0R6V05Output=@(& $p0R6V05Checker -ReportPath (Join-Path $root 'state/checks/p0-r6-v05-fixture-report.json') 2>&1);$p0R6V05Succeeded=$?;$p0R6V05Text=[string]::Join(';',@($p0R6V05Output))
        Add-GateCheck $checks 'PRODUCT-CONTRACT-009' $(if($p0R6V05Succeeded-and$p0R6V05Text.Contains('P0_R6_V05_FIXTURE_RESULT=pass')-and$p0R6V05Text.Contains('P0_R6_V05_FIXTURE_CASES=16')){'pass'}else{'fail'}) $p0R6V05Text 'Compile the current P0 v0.5 typed input, deterministic renderer, synchronized views, physical revision marker and idempotency fixtures.'
        $r7H1Checker=Join-Path $root 'tools/validate-r7-h1-contracts.ps1';$r7H1Output=@(& $r7H1Checker 2>&1);$r7H1Succeeded=$?;$r7H1Text=[string]::Join(';',@($r7H1Output))
        Add-GateCheck $checks 'PRODUCT-CONTRACT-010' $(if($r7H1Succeeded-and$r7H1Text.Contains('R7_H1_CONTRACT_CHECK_RESULT=pass')-and$r7H1Text.Contains('R7_H1_SCHEMA_COUNT=7')-and$r7H1Text.Contains('R7_H1_FIXTURE_COUNT=16')-and$r7H1Text.Contains('R7_H1_NEGATIVE_FIXTURE_COUNT=9')){'pass'}else{'fail'}) $r7H1Text 'Compile R7-H1 blueprint, registries, typed task/submission, compatibility, F12 enum rejection, and positive/negative fixtures without activating H2 or H4.'
        $r7H2Checker=Join-Path $root 'tools/validate-r7-h2-runtime.ps1';$r7H2Output=@(& $r7H2Checker 2>&1);$r7H2Succeeded=$?;$r7H2Text=[string]::Join(';',@($r7H2Output))
        Add-GateCheck $checks 'PRODUCT-CONTRACT-011' $(if($r7H2Succeeded-and$r7H2Text.Contains('R7_H2_RUNTIME_CHECK_RESULT=pass')-and$r7H2Text.Contains('R7_H2_FIXTURE_COUNT=4')){'pass'}else{'fail'}) $r7H2Text 'Compile R7-H2 selector, typed submission v0.2, revision, lineage, pointer-last, event/projection and reconcile across F05-F08.'
        $r7H3Checker=Join-Path $root 'tools/validate-r7-h3-producer-adapters.ps1';$r7H3Output=@(& $r7H3Checker 2>&1);$r7H3Succeeded=$?;$r7H3Text=[string]::Join(';',@($r7H3Output))
        Add-GateCheck $checks 'PRODUCT-CONTRACT-012' $(if($r7H3Succeeded-and$r7H3Text.Contains('R7_H3_PRODUCER_CHECK_RESULT=pass')-and$r7H3Text.Contains('R7_H3_ADAPTER_COUNT=12')-and$r7H3Text.Contains('R7_H3_FIXTURE_COUNT=3')){'pass'}else{'fail'}) $r7H3Text 'Compile R7-H3 producer adapters, deterministic submission building, native status mapping, keep-current and waiting cursor semantics.'
      }

      'runtime_smoke_gate' {
        $parseErrors=New-Object System.Collections.Generic.List[string]
        $scriptPaths=@(Get-ChildItem -LiteralPath (Join-Path $root 'tools') -Filter '*.ps1' -File)+@(Get-ChildItem -LiteralPath (Join-Path $root 'skills') -Filter '*.ps1' -File -Recurse)
        foreach($scriptPath in $scriptPaths){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($scriptPath.FullName,[ref]$tokens,[ref]$errors);foreach($error in @($errors)){$parseErrors.Add("$($scriptPath.FullName):$($error.Extent.StartLineNumber):$($error.Message)")}}
        Add-GateCheck $checks 'SMOKE-001' $(if($parseErrors.Count-eq0){'pass'}else{'fail'}) "parsed_scripts=$($scriptPaths.Count);errors=$($parseErrors.Count)" 'Fix PowerShell parser errors before commit.'
        $h6Tool=Join-Path $root 'tools/complete-p0-h6-regression.ps1';$h6Output=@(& $h6Tool -Mode self_test 2>&1);$h6Succeeded=$?
        Add-GateCheck $checks 'SMOKE-002' $(if($h6Succeeded-and$h6Output-contains'P0_H6_SELF_TEST_RESULT=pass'){'pass'}else{'fail'}) ([string]::Join(';',@($h6Output))) 'Run the H6 executable self-test and fix runtime command/function errors.'
        $visualTextChecker=Join-Path $root 'tools/validate-r3-visual-text.ps1';$visualTextOutput=@(& $visualTextChecker 2>&1);$visualTextSucceeded=$?
        Add-GateCheck $checks 'SMOKE-003' $(if($visualTextSucceeded-and$visualTextOutput-contains'R3_VISUAL_TEXT_CHECK=pass'){'pass'}else{'fail'}) ([string]::Join(';',@($visualTextOutput))) 'Run the deterministic overlay layout smoke and repair execution failures.'
        $h7Checker=Join-Path $root 'tools/validate-p0-h7-fixtures.ps1';$h7Output=@(& $h7Checker 2>&1);$h7Succeeded=$?
        Add-GateCheck $checks 'SMOKE-004' $(if($h7Succeeded-and$h7Output-contains'P0_H7_FIXTURES=pass'){'pass'}else{'fail'}) ([string]::Join(';',@($h7Output))) 'Run the H7 compile, render, idempotency, semantic, and negative fixtures.'
        $startupTool=Join-Path $root 'tools/invoke-account-startup-check.ps1';$startupOutput=@(& $startupTool -SelfTest 2>&1);$startupSucceeded=$?
        Add-GateCheck $checks 'SMOKE-005' $(if($startupSucceeded-and$startupOutput-contains'ACCOUNT_STARTUP_CHECK_SELF_TEST=pass'){'pass'}else{'fail'}) ([string]::Join(';',@($startupOutput))) 'Run the R5-H5 account startup executable self-test.'
        $identityBuilder=Join-Path $root 'tools/new-account-identity-binding.ps1';$identityBuilderOutput=@(& $identityBuilder -SelfTest 2>&1);$identityBuilderSucceeded=$?
        Add-GateCheck $checks 'SMOKE-006' $(if($identityBuilderSucceeded-and$identityBuilderOutput-contains'ACCOUNT_IDENTITY_BINDING_SELF_TEST=pass'){'pass'}else{'fail'}) ([string]::Join(';',@($identityBuilderOutput))) 'Run the R5-H6 identity binding executable self-test.'
        $startupV02=Join-Path $root 'tools/invoke-account-startup-check-v0.2.ps1';$startupV02Output=@(& $startupV02 -SelfTest 2>&1);$startupV02Succeeded=$?
        Add-GateCheck $checks 'SMOKE-007' $(if($startupV02Succeeded-and$startupV02Output-contains'ACCOUNT_STARTUP_CHECK_V02_SELF_TEST=pass'){'pass'}else{'fail'}) ([string]::Join(';',@($startupV02Output))) 'Run the R5-H6 account startup executable self-test.'
        $publicEntryReview=Join-Path $root 'tools/validate-public-entry-doc-review.ps1';$publicEntryReviewOutput=@(& $publicEntryReview -ProjectRoot $root -SelfTest 2>&1);$publicEntryReviewSucceeded=$?;$publicEntryReviewText=[string]::Join(';',@($publicEntryReviewOutput))
        Add-GateCheck $checks 'SMOKE-008' $(if($publicEntryReviewSucceeded-and$publicEntryReviewText.Contains('PUBLIC_ENTRY_DOCUMENT_REVIEW=pass')-and$publicEntryReviewText.Contains('PUBLIC_ENTRY_DOCUMENT_REVIEW_SELF_TEST=pass')){'pass'}else{'fail'}) $publicEntryReviewText 'Run the public-entry document review checker self-test and restore stale-copy negative coverage.'
        $r6Runtime=Join-Path $root 'tools/invoke-r6-content-evidence.ps1';$r6RuntimeOutput=@(& $r6Runtime -Mode self_test 2>&1);$r6RuntimeSucceeded=$?;$r6RuntimeText=[string]::Join(';',@($r6RuntimeOutput))
        Add-GateCheck $checks 'SMOKE-009' $(if($r6RuntimeSucceeded-and$r6RuntimeText.Contains('R6_CONTENT_EVIDENCE_SELF_TEST=pass')){'pass'}else{'fail'}) $r6RuntimeText 'Run the R6 direct-content and source-evidence executable self-test.'
        $r6ScriptVisualChecker=Join-Path $root 'tools/validate-r6-script-visual-contract.ps1';$r6ScriptVisualOutput=@(& $r6ScriptVisualChecker -ReportPath (Join-Path $root 'state/checks/r6-script-visual-contract-report.json') 2>&1);$r6ScriptVisualSucceeded=$?;$r6ScriptVisualText=[string]::Join(';',@($r6ScriptVisualOutput))
        Add-GateCheck $checks 'SMOKE-010' $(if($r6ScriptVisualSucceeded-and$r6ScriptVisualText.Contains('R6_SCRIPT_VISUAL_FIXTURE_RESULT=pass')){'pass'}else{'fail'}) $r6ScriptVisualText 'Run the R6 script/visual executable fixture and pointer commit smoke.'
        $p0R6V05Checker=Join-Path $root 'tools/validate-p0-r6-v05-fixtures.ps1';$p0R6V05Output=@(& $p0R6V05Checker -ReportPath (Join-Path $root 'state/checks/p0-r6-v05-fixture-report.json') 2>&1);$p0R6V05Succeeded=$?;$p0R6V05Text=[string]::Join(';',@($p0R6V05Output))
        Add-GateCheck $checks 'SMOKE-011' $(if($p0R6V05Succeeded-and$p0R6V05Text.Contains('P0_R6_V05_FIXTURE_RESULT=pass')){'pass'}else{'fail'}) $p0R6V05Text 'Run the current v0.5 compile, render, idempotency and revision-marker fixture.'
        $publicReleaseValidatorText=Get-Content -LiteralPath (Join-Path $root 'tools/validate-public-release.ps1') -Raw -Encoding UTF8
        Add-GateCheck $checks 'SMOKE-012' $(if(-not$publicReleaseValidatorText.Contains('$LASTEXITCODE')){'pass'}else{'fail'}) 'public release validator uses same-process success state instead of stale native exit state' 'Do not use $LASTEXITCODE after invoking child PowerShell scripts in the same process; capture $? immediately.'
        $r7H1Checker=Join-Path $root 'tools/validate-r7-h1-contracts.ps1';$r7H1Output=@(& $r7H1Checker 2>&1);$r7H1Succeeded=$?;$r7H1Text=[string]::Join(';',@($r7H1Output))
        Add-GateCheck $checks 'SMOKE-013' $(if($r7H1Succeeded-and$r7H1Text.Contains('R7_H1_CONTRACT_CHECK_RESULT=pass')){'pass'}else{'fail'}) $r7H1Text 'Run the R7-H1 checker as a real Windows PowerShell 5.1 executable fixture.'
        $r7H2Checker=Join-Path $root 'tools/validate-r7-h2-runtime.ps1';$r7H2Output=@(& $r7H2Checker 2>&1);$r7H2Succeeded=$?;$r7H2Text=[string]::Join(';',@($r7H2Output))
        Add-GateCheck $checks 'SMOKE-014' $(if($r7H2Succeeded-and$r7H2Text.Contains('R7_H2_RUNTIME_CHECK_RESULT=pass')){'pass'}else{'fail'}) $r7H2Text 'Run the R7-H2 pointer-last and recovery checker as a real Windows PowerShell 5.1 executable fixture.'
        $r7H3Checker=Join-Path $root 'tools/validate-r7-h3-producer-adapters.ps1';$r7H3Output=@(& $r7H3Checker 2>&1);$r7H3Succeeded=$?;$r7H3Text=[string]::Join(';',@($r7H3Output))
        Add-GateCheck $checks 'SMOKE-015' $(if($r7H3Succeeded-and$r7H3Text.Contains('R7_H3_PRODUCER_CHECK_RESULT=pass')){'pass'}else{'fail'}) $r7H3Text 'Run the R7-H3 adapter, submission builder, keep-current and wait-state fixtures in Windows PowerShell 5.1.'
      }

      'account_startup_gate' {
        $requiredPaths=@('docs/product/R5-产品确认清单.md','skills/propagation-router/SKILL.md','skills/propagation-router/CONTRACT.md','skills/hotspot-topic-research/SKILL.md','skills/hotspot-topic-research/CONTRACT.md','tools/AccountStartupCheck.ps1','tools/AccountIdentityBinding.ps1','tools/AccountStartupCheckV02.ps1','tools/invoke-account-startup-check-v0.2.ps1','tools/new-account-identity-binding.ps1','tools/validate-r5-h6-account-identity.ps1','templates/schema/r5/account-identity-binding.v0.1.schema.json','templates/schema/r5/account-startup-check.v0.2.schema.json','templates/schema/r5/account-session-snapshot.v0.2.schema.json','templates/account/account-identity-binding.template.json','templates/account/account-session-snapshot.v0.2.template.yaml','examples/r5-h6-account-identity-fixtures/fixtures.json','交接物字段词典.md')
        $missing=@($requiredPaths|Where-Object{-not(Test-Path -LiteralPath (Join-Path $root $_))})
        Add-GateCheck $checks 'ACCOUNT-STARTUP-001' $(if($missing.Count-eq0){'pass'}else{'fail'}) "missing=$($missing.Count);$([string]::Join('|',$missing))" 'Restore all R5-H6 account identity and startup contracts.'
        if($missing.Count-eq0){$startupChecker=Join-Path $root 'tools/validate-r5-h6-account-identity.ps1';$startupOutput=@(& $startupChecker 2>&1);$startupSucceeded=$?;$startupText=[string]::Join("`n",@($startupOutput));Add-GateCheck $checks 'ACCOUNT-STARTUP-002' $(if($startupSucceeded-and$startupText.Contains('R5_H6_ACCOUNT_IDENTITY_CHECK=pass')){'pass'}else{'fail'}) $startupText 'Repair R5-H6 identity fixtures or deterministic resolver.'}
      }

      'environment_compatibility_gate' {
        $matrixTool=Join-Path $root 'tools/invoke-windows-clean-room-matrix.ps1'
        if(-not(Test-Path -LiteralPath $matrixTool -PathType Leaf)){
          Add-GateCheck $checks 'ENV-COMPAT-001' 'fail' 'matrix tool missing' 'Restore tools/invoke-windows-clean-room-matrix.ps1.'
        }else{
          $definitionOutput=@(& $matrixTool -Mode definition 2>&1);$definitionSucceeded=$?;$definitionText=[string]::Join(';',@($definitionOutput))
          Add-GateCheck $checks 'ENV-COMPAT-001' $(if($definitionSucceeded-and$definitionText.Contains('WINDOWS_CLEAN_ROOM_MATRIX=pass')){'pass'}else{'fail'}) $definitionText 'Repair the canonical Windows PowerShell 5.1 source/zip path matrix definition.'
          $fullReport=$null;$fullReportPath='';$reportRoot=Join-Path $root 'state/checks'
          if(Test-Path -LiteralPath $reportRoot){
            foreach($reportFile in @(Get-ChildItem -LiteralPath $reportRoot -File -Filter '*windows-clean-room-matrix-report.json' | Sort-Object LastWriteTime -Descending)){
              try{$candidate=Get-Content -LiteralPath $reportFile.FullName -Raw -Encoding UTF8|ConvertFrom-Json;$candidateReport=$candidate.clean_room_matrix_report;if($null-ne$candidateReport-and$candidateReport.mode-eq'full'){$fullReport=$candidateReport;$fullReportPath=$reportFile.FullName;break}}catch{}
            }
          }
          if($null-eq$fullReport){
            Add-GateCheck $checks 'ENV-COMPAT-002' 'blocked' 'full matrix report missing' 'Run tools/invoke-windows-clean-room-matrix.ps1 -Mode full with a unique short WorkRoot.'
          }else{
            $fullPass=$fullReport.overall_result-eq'pass'-and[int]$fullReport.canonical_case_count-eq6-and[int]$fullReport.executed_case_count-eq6-and[int]$fullReport.pass_case_count-eq6-and[int]$fullReport.fail_case_count-eq0-and$fullReport.system_configuration_mutated-eq$false-and$fullReport.network_called-eq$false
            $evidence="report=$fullReportPath;result=$($fullReport.overall_result);cases=$($fullReport.pass_case_count)/$($fullReport.canonical_case_count);archive_sha256=$($fullReport.archive_sha256)"
            Add-GateCheck $checks 'ENV-COMPAT-002' $(if($fullPass){'pass'}else{'fail'}) $evidence 'Run the full PS5.1 matrix on the current source/index candidate and repair failed cases.'
          }
        }
      }

      'link_check_gate' {
        $docChecker=Join-Path $root 'tools/validate-doc-governance.ps1';& $docChecker -ProjectRoot $root -ReportPath (Join-Path $root 'state/checks/doc-governance-report.json')|Out-Null;$docSucceeded=$?;$docReport=Get-Content -LiteralPath (Join-Path $root 'state/checks/doc-governance-report.json') -Raw -Encoding UTF8|ConvertFrom-Json
        Add-GateCheck $checks 'DOC-LINK-001' $(if($docSucceeded-and[int]$docReport.broken_link_count-eq0){'pass'}else{'fail'}) "broken_links=$($docReport.broken_link_count)" 'Fix relative links and AI navigation anchors.'
      }

      'root_cleanliness_gate' {
        $docChecker=Join-Path $root 'tools/validate-doc-governance.ps1';& $docChecker -ProjectRoot $root -ReportPath (Join-Path $root 'state/checks/doc-governance-report.json')|Out-Null;$docSucceeded=$?;$docReport=Get-Content -LiteralPath (Join-Path $root 'state/checks/doc-governance-report.json') -Raw -Encoding UTF8|ConvertFrom-Json
        Add-GateCheck $checks 'DOC-ROOT-001' $(if($docSucceeded-and[int]$docReport.root_unexpected_count-eq0){'pass'}else{'fail'}) "root_unexpected=$($docReport.root_unexpected_count)" 'Move non-entry Markdown out of the project root.'
      }

      'document_graph_gate' {
        $docChecker=Join-Path $root 'tools/validate-doc-governance.ps1';$docOutput=@(& $docChecker -ProjectRoot $root -ReportPath (Join-Path $root 'state/checks/doc-governance-report.json') 2>&1);$docSucceeded=$?
        Add-GateCheck $checks 'DOC-GRAPH-001' $(if($docSucceeded-and$docOutput-contains'DOC_GOVERNANCE_CHECK=pass'){'pass'}else{'fail'}) ([string]::Join(';',@($docOutput))) 'Repair section indexes, document coverage, links, anchors, current scope, or root placement.'
      }

      'sample_only_gate' {
        $examplesDir = Join-Path $root 'examples'
        if (Test-Path -LiteralPath $examplesDir) {
          $sampleDirs = @(Get-ChildItem -LiteralPath $examplesDir -Directory -Filter 'sample-*' -ErrorAction SilentlyContinue)
          if ($sampleDirs.Count -gt 0) {
            Add-GateCheck $checks 'SAMPLE-001' 'pass' "sample_dirs=$($sampleDirs.Count)" 'Sample directories available.'
          } else {
            Add-GateCheck $checks 'SAMPLE-001' 'fail' 'No sample-* directories' 'Create sample directories in examples/.'
          }
        } else {
          Add-GateCheck $checks 'SAMPLE-001' 'fail' 'examples/ directory missing' 'Create examples/ directory.'
        }

        $accountsDir = Join-Path $root 'accounts'
        if (Test-Path -LiteralPath $accountsDir) {
          Add-GateCheck $checks 'SAMPLE-002' 'warning' 'accounts/ exists in test profile' 'Ensure test runs only use examples/, not real accounts.'
        } else {
          Add-GateCheck $checks 'SAMPLE-002' 'pass' 'No accounts/ directory' 'No real account data in test profile.'
        }
      }

      'public_privacy_gate' {
        $gitTracked = @(& git -C $root ls-files 'accounts' 'indexes' 2>$null)
        if ($LASTEXITCODE -eq 0) {
          $status = if ($gitTracked.Count -eq 0) { 'pass' } else { 'fail' }
          $evidence = if ($gitTracked.Count -eq 0) { 'no tracked private paths' } else { "tracked=$($gitTracked.Count)" }
          Add-GateCheck $checks 'PRIVACY-001' $status $evidence 'Remove real accounts/ and indexes/ from Git tracking.'
        } else {
          Add-GateCheck $checks 'PRIVACY-001' 'fail' 'git ls-files failed' 'Fix Git availability.'
        }

        $envVars = @('GITHUB_TOKEN')
        foreach ($var in $envVars) {
          $envValue = [Environment]::GetEnvironmentVariable($var)
          if ([string]::IsNullOrWhiteSpace($envValue)) {
            Add-GateCheck $checks "PRIVACY-002-$var" 'warning' "$var not set" 'Consider setting environment variable.'
          } else {
            Add-GateCheck $checks "PRIVACY-002-$var" 'pass' "$var is set" 'Environment variable available.'
          }
        }
      }

      'public_entry_document_gate' {
        $checker = Join-Path $root 'tools/validate-public-entry-doc-review.ps1'
        $reportPath = Join-Path $root 'state/checks/public-entry-doc-review-report.json'
        if (-not (Test-Path -LiteralPath $checker -PathType Leaf)) {
          Add-GateCheck $checks 'PUBLIC-DOC-001' 'fail' 'validate-public-entry-doc-review.ps1 missing' 'Restore the public-entry document review checker before public build or release.'
        } else {
          $output = @(& $checker -ProjectRoot $root -SelfTest -ReportPath $reportPath 2>&1)
          $succeeded = $?
          $outputText = [string]::Join(';', @($output))
          $status = if ($succeeded -and $outputText.Contains('PUBLIC_ENTRY_DOCUMENT_REVIEW=pass') -and $outputText.Contains('PUBLIC_ENTRY_DOCUMENT_REVIEW_SELF_TEST=pass')) { 'pass' } else { 'fail' }
          Add-GateCheck $checks 'PUBLIC-DOC-001' $status $outputText 'Review every public entry document for the candidate version and remove stale public claims.'
        }
      }

      default {
        Add-GateCheck $checks "GATE-UNKNOWN-$gate" 'fail' "unknown_gate=$gate" 'Implement the gate in tools/validate-gates.ps1 before referencing it as executable.'
      }
    }
  }

  $failed = @($checks | Where-Object { $_.status -eq 'fail' })
  $blocked = @($checks | Where-Object { $_.status -eq 'blocked' })
  $overall = if ($failed.Count -gt 0) { 'fail' } elseif ($blocked.Count -gt 0) { 'blocked' } else { 'pass' }
  $exitCode = if ($failed.Count -gt 0) { 1 } elseif ($blocked.Count -gt 0) { 2 } else { 0 }

  $report = [ordered]@{
    gate_check_report = [ordered]@{
      check_run_id = $checkRunId
      gates_checked = $targetGates
      overall_result = $overall
      exit_code = $exitCode
      fail_count = $failed.Count
      blocked_count = $blocked.Count
      checks = [object[]]$checks.ToArray()
    }
  }
  Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 8

  $lines = @('# Gate Check Report', '', '```yaml')
  $lines += "check_run_id: $checkRunId"
  $lines += "gates_checked: $([string]::Join(', ', $targetGates))"
  $lines += "overall_result: $overall"
  $lines += "exit_code: $exitCode"
  $lines += "fail_count: $($failed.Count)"
  $lines += "blocked_count: $($blocked.Count)"
  $lines += '```'
  $lines += ''
  $lines += '| Check ID | Status | Evidence | Remediation |'
  $lines += '|---|---|---|---|'
  foreach ($check in $checks) {
    $lines += "| $($check.check_item_id) | $($check.status) | $($check.evidence) | $($check.remediation) |"
  }
  Write-TaogeUtf8NoBomLines -Path $HumanReportPath -Lines $lines

  Write-Output "GATE_CHECK_RESULT=$overall"
  exit $exitCode
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
