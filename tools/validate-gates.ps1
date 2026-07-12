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

  $allGates = @('state_consistency_gate', 'branch_lock_gate', 'field_gate', 'product_contract_compilation_gate', 'runtime_smoke_gate', 'document_graph_gate', 'sample_only_gate', 'public_privacy_gate')
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
          if ($LASTEXITCODE -eq 0) { Add-GateCheck $checks 'PRODUCT-CONTRACT-001' 'pass' 'R3 visual need product contract is compiled across layers' 'Product contract compilation gate passed.' }
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
        $reliabilityChecker=Join-Path $root 'tools/validate-p0-h6-reliability.ps1';$reliabilityOutput=@(& $reliabilityChecker 2>&1);$reliabilityExit=$LASTEXITCODE
        Add-GateCheck $checks 'PRODUCT-CONTRACT-003' $(if($reliabilityExit-eq0-and$reliabilityOutput-contains'P0_H6_RELIABILITY_CHECK=pass'){'pass'}else{'fail'}) ([string]::Join(';',@($reliabilityOutput))) 'Repair P0-H6 reliability fixtures and executable checks.'
        $h7Sources=@(
          @{path='交接物字段词典.md';tokens=@('delivery_revision_id','platform_delivery_unit','insert_after_text','warning_item','duration_estimate_status','commit marker')},
          @{path='skills/final-delivery-builder/CONTRACT.md';tokens=@('P0-H7 v0.3','p0-contract-bundle-v0.3','delivery-revision.json')},
          @{path='templates/schema/p0/typed-render-input.v0.3.schema.json';tokens=@('platform_delivery_units','warning_items','duration_estimate')},
          @{path='tools/validate-p0-h7-fixtures.ps1';tokens=@('cover-title-mismatch','warning-union-derived','duration-unproven','idempotent-commit')}
        );$missingH7=New-Object System.Collections.Generic.List[string];foreach($source in $h7Sources){$sourcePath=Join-Path $root $source.path;if(-not(Test-Path $sourcePath)){$missingH7.Add("missing_file:$($source.path)");continue};$text=Get-Content $sourcePath -Raw -Encoding UTF8;foreach($token in $source.tokens){if(-not$text.Contains($token)){$missingH7.Add("$($source.path):$token")}}}
        Add-GateCheck $checks 'PRODUCT-CONTRACT-004' $(if($missingH7.Count-eq0){'pass'}else{'fail'}) "p0_h7_missing=$($missingH7.Count);$([string]::Join('|',@($missingH7)))" 'Compile P0-H7 across field dictionary, Skill, schema, fixture, and checker.'
      }

      'runtime_smoke_gate' {
        $parseErrors=New-Object System.Collections.Generic.List[string]
        $scriptPaths=@(Get-ChildItem -LiteralPath (Join-Path $root 'tools') -Filter '*.ps1' -File)+@(Get-ChildItem -LiteralPath (Join-Path $root 'skills') -Filter '*.ps1' -File -Recurse)
        foreach($scriptPath in $scriptPaths){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($scriptPath.FullName,[ref]$tokens,[ref]$errors);foreach($error in @($errors)){$parseErrors.Add("$($scriptPath.FullName):$($error.Extent.StartLineNumber):$($error.Message)")}}
        Add-GateCheck $checks 'SMOKE-001' $(if($parseErrors.Count-eq0){'pass'}else{'fail'}) "parsed_scripts=$($scriptPaths.Count);errors=$($parseErrors.Count)" 'Fix PowerShell parser errors before commit.'
        $h6Tool=Join-Path $root 'tools/complete-p0-h6-regression.ps1';$h6Output=@(& $h6Tool -Mode self_test 2>&1);$h6Exit=$LASTEXITCODE
        Add-GateCheck $checks 'SMOKE-002' $(if($h6Exit-eq0-and$h6Output-contains'P0_H6_SELF_TEST_RESULT=pass'){'pass'}else{'fail'}) ([string]::Join(';',@($h6Output))) 'Run the H6 executable self-test and fix runtime command/function errors.'
        $visualTextChecker=Join-Path $root 'tools/validate-r3-visual-text.ps1';$visualTextOutput=@(& $visualTextChecker 2>&1);$visualTextExit=$LASTEXITCODE
        Add-GateCheck $checks 'SMOKE-003' $(if($visualTextExit-eq0-and$visualTextOutput-contains'R3_VISUAL_TEXT_CHECK=pass'){'pass'}else{'fail'}) ([string]::Join(';',@($visualTextOutput))) 'Run the deterministic overlay layout smoke and repair execution failures.'
        $h7Checker=Join-Path $root 'tools/validate-p0-h7-fixtures.ps1';$h7Output=@(& $h7Checker 2>&1);$h7Exit=$LASTEXITCODE
        Add-GateCheck $checks 'SMOKE-004' $(if($h7Exit-eq0-and$h7Output-contains'P0_H7_FIXTURES=pass'){'pass'}else{'fail'}) ([string]::Join(';',@($h7Output))) 'Run the H7 compile, render, idempotency, semantic, and negative fixtures.'
      }

      'link_check_gate' {
        $docChecker=Join-Path $root 'tools/validate-doc-governance.ps1';& $docChecker -ProjectRoot $root -ReportPath (Join-Path $root 'state/checks/doc-governance-report.json')|Out-Null;$docExit=$LASTEXITCODE;$docReport=Get-Content -LiteralPath (Join-Path $root 'state/checks/doc-governance-report.json') -Raw -Encoding UTF8|ConvertFrom-Json
        Add-GateCheck $checks 'DOC-LINK-001' $(if($docExit-eq0-and[int]$docReport.broken_link_count-eq0){'pass'}else{'fail'}) "broken_links=$($docReport.broken_link_count)" 'Fix relative links and AI navigation anchors.'
      }

      'root_cleanliness_gate' {
        $docChecker=Join-Path $root 'tools/validate-doc-governance.ps1';& $docChecker -ProjectRoot $root -ReportPath (Join-Path $root 'state/checks/doc-governance-report.json')|Out-Null;$docExit=$LASTEXITCODE;$docReport=Get-Content -LiteralPath (Join-Path $root 'state/checks/doc-governance-report.json') -Raw -Encoding UTF8|ConvertFrom-Json
        Add-GateCheck $checks 'DOC-ROOT-001' $(if($docExit-eq0-and[int]$docReport.root_unexpected_count-eq0){'pass'}else{'fail'}) "root_unexpected=$($docReport.root_unexpected_count)" 'Move non-entry Markdown out of the project root.'
      }

      'document_graph_gate' {
        $docChecker=Join-Path $root 'tools/validate-doc-governance.ps1';$docOutput=@(& $docChecker -ProjectRoot $root -ReportPath (Join-Path $root 'state/checks/doc-governance-report.json') 2>&1);$docExit=$LASTEXITCODE
        Add-GateCheck $checks 'DOC-GRAPH-001' $(if($docExit-eq0-and$docOutput-contains'DOC_GOVERNANCE_CHECK=pass'){'pass'}else{'fail'}) ([string]::Join(';',@($docOutput))) 'Repair section indexes, document coverage, links, anchors, current scope, or root placement.'
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
