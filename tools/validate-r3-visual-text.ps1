param(
  [string]$FixturePath = "examples/r3-visual-text-fixtures/fixtures.json",
  [string]$SampleRunPath = "docs/tutorials/r3-dry-run-sample/accounts/sample-account/runs/SR3DR-001",
  [string]$HumanReportPath = "state/checks/r3-visual-text-check-report.md",
  [string]$MachineReportPath = "state/checks/r3-visual-text-check-report.json"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')

function Add-Check {
  param([System.Collections.Generic.List[object]]$List, [string]$Id, [string]$Status, [string]$Evidence)
  $List.Add([pscustomobject]@{ check_item_id = $Id; status = $Status; evidence = $Evidence })
}

try {
  if (-not (Test-Path -LiteralPath $FixturePath -PathType Leaf)) { throw "Fixture file not found: $FixturePath" }
  $fixtureFile = Get-Content -LiteralPath $FixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
  $fixtureRoot = Split-Path -Parent (Resolve-Path -LiteralPath $FixturePath).Path
  $fixtures = @($fixtureFile.fixtures)
  $checks = New-Object System.Collections.Generic.List[object]
  $expectedIds = 1..9 | ForEach-Object { "VTF-{0:D3}" -f $_ }
  $actualIds = @($fixtures | ForEach-Object { $_.fixture_id })
  Add-Check $checks "R3VT-001" $(if (@($expectedIds | Where-Object { $actualIds -notcontains $_ }).Count -eq 0) { "pass" } else { "fail" }) "nine required fixture IDs"

  foreach ($fixture in $fixtures) {
    $id = [string]$fixture.fixture_id
    if ($fixture.case_type -eq "cover_title_only") {
      $ok = $fixture.cover_variant_difference_type -eq "title_only" -and [int]$fixture.materially_distinct_variant_count -eq 0
      Add-Check $checks "$id-COVER" $(if ($ok) { "pass" } else { "fail" }) "title_only does not count as materially distinct"
      continue
    }

    $decision = [string]$fixture.visual_text_decision
    $units = @($fixture.visual_text_units)
    Add-Check $checks "$id-DECISION" $(if (@("forbidden", "optional", "required") -contains $decision) { "pass" } else { "fail" }) "decision=$decision"
    Add-Check $checks "$id-MAPPING" $(if (-not [string]::IsNullOrWhiteSpace([string]$fixture.image_task_id)) { "pass" } else { "fail" }) "image_task_id present"

    $cardinalityOk = if ($decision -eq "forbidden") { $units.Count -eq 0 } elseif ($decision -eq "required") { $units.Count -gt 0 } else { $units.Count -le 4 }
    Add-Check $checks "$id-CARDINALITY" $(if ($cardinalityOk) { "pass" } else { "fail" }) "units=$($units.Count)"

    if ($fixture.subtitle_source_status -eq "not_available") {
      Add-Check $checks "$id-SUBTITLE" $(if ($fixture.draft_redundancy_check -eq "pass") { "pass" } else { "fail" }) "draft redundancy checked without subtitles"
    }

    foreach ($unit in $units) {
      $unitId = [string]$unit.visual_text_unit_id
      $basic = -not [string]::IsNullOrWhiteSpace([string]$unit.content) -and -not [string]::IsNullOrWhiteSpace([string]$unit.information_delta)
      Add-Check $checks "$id-$unitId-BASIC" $(if ($basic) { "pass" } else { "fail" }) "content and information_delta"
      if ($null -ne $unit.max_chars -and ([string]$unit.content).Length -gt [int]$unit.max_chars) {
        Add-Check $checks "$id-$unitId-BUDGET" "fail" "content exceeds max_chars"
      } else {
        Add-Check $checks "$id-$unitId-BUDGET" "pass" "content within max_chars"
      }
      if ([bool]$unit.is_source_required) {
        $sourceOk = $unit.evidence_source_type -ne "not_applicable" -and
          -not [string]::IsNullOrWhiteSpace([string]$unit.evidence_source_id) -and
          -not [string]::IsNullOrWhiteSpace([string]$unit.evidence_source_path) -and
          (Test-Path -LiteralPath (Join-Path $fixtureRoot ([string]$unit.evidence_source_path)) -PathType Leaf) -and
          $unit.source_binding_status -eq "source_bound"
        if ($fixture.expected_result -eq "blocked") { $sourceOk = -not $sourceOk }
        Add-Check $checks "$id-$unitId-SOURCE" $(if ($sourceOk) { "pass" } else { "fail" }) "source binding matches expected outcome"
      }
    }

    if ($fixture.generated_scene -eq $true -and $fixture.visual_role -eq "evidence_support") {
      $blocked = $fixture.expected_result -eq "blocked" -and $fixture.expected_recovery -eq "downgrade_visual_role"
      Add-Check $checks "$id-PSEUDO-EVIDENCE" $(if ($blocked) { "pass" } else { "fail" }) "generated evidence is blocked"
    }
    if ($fixture.case_type -eq "model_text_fallback") {
      $fallbackOk = $fixture.model_text_accuracy_status -eq "needs_fix" -and $fixture.fallback_render_strategy -eq "deterministic_overlay" -and $fixture.expected_recovery -eq "rerender_deterministic_overlay"
      Add-Check $checks "$id-FALLBACK" $(if ($fallbackOk) { "pass" } else { "fail" }) "model text falls back deterministically"
    }
  }

  $projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
  $layoutSmokeRoot=Join-Path $projectRoot 'state/checks/r3-visual-text-layout-smoke';if(-not(Test-Path -LiteralPath $layoutSmokeRoot)){New-Item -ItemType Directory -Path $layoutSmokeRoot -Force|Out-Null}
  $layoutInput=Join-Path $layoutSmokeRoot 'input.png';$layoutOutput=Join-Path $layoutSmokeRoot 'three-columns.png';Add-Type -AssemblyName System.Drawing
  $bitmap=[Drawing.Bitmap]::new(900,600);$graphics=[Drawing.Graphics]::FromImage($bitmap);try{$graphics.Clear([Drawing.Color]::FromArgb(38,45,58));$bitmap.Save($layoutInput,[Drawing.Imaging.ImageFormat]::Png)}finally{$graphics.Dispose();$bitmap.Dispose()}
  $layoutUnits=@(
    [ordered]@{content='利润';placement='left_third'},
    [ordered]@{content='信任';placement='center_third'},
    [ordered]@{content='周转';placement='right_third'}
  )|ConvertTo-Json -Compress
  $layoutOutputLines=@(& (Join-Path $projectRoot 'skills/image-asset-producer/scripts/compose-visual-text.ps1') -InputPath $layoutInput -OutputPath $layoutOutput -TextUnitsJson $layoutUnits -FontSize 36 -Force 2>&1);$layoutExit=if($?){0}else{1};$layoutReportPath=$layoutOutput+'.layout.json'
  $layoutPass=$layoutExit-eq0-and(Test-Path -LiteralPath $layoutOutput)-and(Test-Path -LiteralPath $layoutReportPath)
  if($layoutPass){$layoutReport=Get-Content -LiteralPath $layoutReportPath -Raw -Encoding UTF8|ConvertFrom-Json;$layoutRows=@($layoutReport.units|Sort-Object index);$sameY=@($layoutRows.y|Select-Object -Unique).Count-eq1;$orderedX=$layoutRows.Count-eq3-and$layoutRows[0].x-lt$layoutRows[1].x-and$layoutRows[1].x-lt$layoutRows[2].x;$nonOverlap=($layoutRows[0].x+$layoutRows[0].width)-le$layoutRows[1].x-and($layoutRows[1].x+$layoutRows[1].width)-le$layoutRows[2].x;$layoutPass=$sameY-and$orderedX-and$nonOverlap}
  Add-Check $checks 'R3VT-LAYOUT-THIRDS-SMOKE' $(if($layoutPass){'pass'}else{'fail'}) $(if($layoutPass){'left/center/right share Y and do not overlap'}else{"exit=$layoutExit;$([string]::Join(';',@($layoutOutputLines)))"})

  $sourceContracts = @(
    @{ id = "SRC-DIRECTOR"; path = "skills/static-visual-director/SKILL.md"; needles = @("visual_text_tasks", "is_source_required", "evidence_source_path", "Dispatch through", "talking-head-image-pip", "image-prompt-compiler") },
    @{ id = "SRC-PROMPT"; path = "skills/image-prompt-compiler/SKILL.md"; needles = @("visual_text_task_id", "visual_text_decision", "allow_text_in_image=false", "next_skill: image-asset-producer") },
    @{ id = "SRC-ASSET"; path = "skills/image-asset-producer/SKILL.md"; needles = @("compose-visual-text.ps1", "deterministic_overlay", "visual_text_unit_ids", "layout sidecar", "reconcile", "next_skill: visual-asset-finalizer") },
    @{ id = "SRC-ORCHESTRATOR"; path = "skills/talking-head-image-pip/SKILL.md"; needles = @("static-visual-director", "image-prompt-compiler", "image-asset-producer", "structure-bound beat map", "full beat coverage") },
    @{ id = "SRC-REVIEW"; path = "skills/copywriting-quality-review/SKILL.md"; needles = @("visual_text_quality_gate_status", "information_delta_status", "source_binding_status", "recovery_action") },
    @{ id = "SRC-COVER"; path = "skills/cover-design-compiler/SKILL.md"; needles = @("cover_visual_entry_type", "cover_variant_difference_type", "cover_contract_render_alignment_status", "platform_preview_status") },
    @{ id = "SRC-FINAL"; path = "templates/final-delivery/final-delivery.template.html"; needles = @("visual_text_plan_id", "visual_text_delivery_summary", "evidence_source_path", "本图按计划无字") },
    @{ id = "SRC-SCHEMA"; path = "templates/schema/field-schema.v0.1.json"; needles = @("visual_text_decision", "visual_text_role", "source_binding_status", "cover_variant_difference_type") }
  )
  foreach ($contract in $sourceContracts) {
    $fullPath = Join-Path $projectRoot $contract.path
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
      Add-Check $checks $contract.id "fail" "missing $($contract.path)"
      continue
    }
    $text = Get-Content -LiteralPath $fullPath -Raw -Encoding UTF8
    $missing = @($contract.needles | Where-Object { -not $text.Contains($_) })
    Add-Check $checks $contract.id $(if ($missing.Count -eq 0) { "pass" } else { "fail" }) $(if ($missing.Count -eq 0) { $contract.path } else { "missing: $([string]::Join(', ', $missing))" })
  }

  foreach ($skillPath in @("skills/talking-head-image-pip/SKILL.md", "skills/static-visual-director/SKILL.md", "skills/image-prompt-compiler/SKILL.md", "skills/image-asset-producer/SKILL.md")) {
    $fullPath = Join-Path $projectRoot $skillPath
    $lineCount = @(Get-Content -LiteralPath $fullPath -Encoding UTF8).Count
    Add-Check $checks ("LINES-" + ($skillPath -replace '[^A-Za-z0-9]', '-')) $(if ($lineCount -le 500) { "pass" } else { "fail" }) "$skillPath lines=$lineCount"
  }

  $activeFieldFiles = @(
    "skills/platform-packaging-adapter/SKILL.md",
    "skills/cover-design-compiler/SKILL.md",
    "examples/r3-visual-text-fixtures/fixtures.json"
  )
  $legacyWrites = @()
  foreach ($relativePath in $activeFieldFiles) {
    $matches = @(Select-String -LiteralPath (Join-Path $projectRoot $relativePath) -Pattern 'variant_role\s*:' -AllMatches)
    if ($matches.Count -gt 0) { $legacyWrites += $relativePath }
  }
  Add-Check $checks "SRC-LEGACY-VARIANT" $(if ($legacyWrites.Count -eq 0) { "pass" } else { "fail" }) $(if ($legacyWrites.Count -eq 0) { "no active variant_role writes" } else { [string]::Join(', ', $legacyWrites) })

  $finalContractPath = Join-Path $projectRoot "skills/final-delivery-builder/CONTRACT.md"
  $finalContractText = Get-Content -LiteralPath $finalContractPath -Raw -Encoding UTF8
  if ($finalContractText.Contains('render_input_schema_id: taoge://schemas/final-delivery/typed-components/v0.9') -or $finalContractText.Contains('render_input_schema_id: taoge://schemas/final-delivery/typed-components/v0.8')) {
    $currentSchemaVersion = if ($finalContractText.Contains('typed-components/v0.9')) { 'v0.9' } else { 'v0.8' }
    $currentSchemaText = Get-Content -LiteralPath (Join-Path $projectRoot "templates/schema/final-delivery/typed-components.$currentSchemaVersion.schema.json") -Raw -Encoding UTF8
    $currentRendererText = Get-Content -LiteralPath (Join-Path $projectRoot 'tools/R7CandidateRuntime.ps1') -Raw -Encoding UTF8
    $summaryOwnershipOk = $currentSchemaText.Contains('visual_route_summary') -and $currentRendererText.Contains('visual_coverage_summary') -and $currentRendererText.Contains('Get-R7VisualRouteHtml')
    $summaryEvidence = "$currentSchemaVersion compiler derives visual coverage and source-route transparency from current artifacts; prose does not inject HTML summaries"
  } elseif ($finalContractText.Contains('render_input_schema_id: taoge://schemas/final-delivery/typed-components/v0.6')) {
    $currentSchemaText = Get-Content -LiteralPath (Join-Path $projectRoot 'templates/schema/p0/typed-render-input.v0.5.schema.json') -Raw -Encoding UTF8
    $currentRendererText = Get-Content -LiteralPath (Join-Path $projectRoot 'tools/P0FinalDeliveryV05.ps1') -Raw -Encoding UTF8
    $summaryOwnershipOk = $currentSchemaText.Contains('visual_coverage_summary') -and $currentRendererText.Contains('ConvertTo-P0V5CoverageSummaryHtml') -and $currentRendererText.Contains('visual_coverage_summary=')
    $summaryEvidence = 'v0.5 compatibility renderer derives the business-visible visual coverage summary inside the v0.6 compiler-owned delivery path'
  } else {
    $finalInputBlock = [regex]::Match($finalContractText, '(?s)## 4\. 输入合同(.*?)## 5\. 输出合同').Groups[1].Value
    $finalOutputBlock = [regex]::Match($finalContractText, '(?s)## 5\. 输出合同(.*?)## 6\. 路径合同').Groups[1].Value
    $summaryOwnershipOk = -not $finalInputBlock.Contains('visual_text_delivery_summary') -and $finalOutputBlock.Contains('visual_text_delivery_summary')
    $summaryEvidence = 'legacy final-delivery-builder computes visual_text_delivery_summary'
  }
  Add-Check $checks "FLOW-FINAL-SUMMARY-OWNERSHIP" $(if ($summaryOwnershipOk) { "pass" } else { "fail" }) $summaryEvidence

  $coverContractText = Get-Content -LiteralPath (Join-Path $projectRoot "skills/cover-design-compiler/CONTRACT.md") -Raw -Encoding UTF8
  $coverConditionalOk = $coverContractText.Contains('generated_background_required_fields') -and
    $coverContractText.Contains('composition_ready_required_fields') -and
    $coverContractText.Contains('prompt_only_required_fields') -and
    $coverContractText.Contains('preview_evidence_required_when')
  Add-Check $checks "FLOW-COVER-CONDITIONAL-FIELDS" $(if ($coverConditionalOk) { "pass" } else { "fail" }) "generated and prompt_only contracts are conditional"

  $packageContractText = Get-Content -LiteralPath (Join-Path $projectRoot "skills/platform-packaging-adapter/CONTRACT.md") -Raw -Encoding UTF8
  $legacyPackagePath = Join-Path $projectRoot 'skills/platform-packaging-adapter/references/legacy-r1-r7-platform-contract.md'
  $legacyPackageText = if (Test-Path -LiteralPath $legacyPackagePath -PathType Leaf) { Get-Content -LiteralPath $legacyPackagePath -Raw -Encoding UTF8 } else { '' }
  $packageGateFields = @('visual_text_plan_id', 'image_asset_set_id', 'visual_text_quality_gate_status', 'image_asset_trace_status', 'asset_trace_quality_gate_status', 'html_embed_readiness_status')
  $packageMissing = @($packageGateFields | Where-Object { -not $legacyPackageText.Contains($_) })
  $packageIsolationOk = $packageContractText.Contains('Skill contract version: `0.6.0`') -and $legacyPackageText.Contains('applicability: historical_only')
  Add-Check $checks "FLOW-PACKAGE-GATES" $(if ($packageMissing.Count -eq 0 -and $packageIsolationOk) { "pass" } else { "fail" }) $(if ($packageMissing.Count -eq 0 -and $packageIsolationOk) { "historical visual/trace gates remain replayable while current v0.6 contract stays isolated" } else { "missing: $([string]::Join(', ', $packageMissing));isolation=$packageIsolationOk" })

  $sampleRoot = Join-Path $projectRoot $SampleRunPath
  $sampleFiles = [ordered]@{
    manifest = 'manifest.yaml'
    trace = 'intermediate/00-execution-trace.md'
    plan = 'intermediate/05-visual-plan.md'
    review = 'intermediate/06-quality-review.md'
    package_input = 'intermediate/07-platform-package-input.md'
    package = 'intermediate/08-platform-package-draft.md'
    cover_review = 'intermediate/09-cover-quality-review.md'
    delivery = 'deliverables/content-delivery-record.md'
    embed = 'deliverables/html-embed-manifest.md'
    final = 'deliverables/final-delivery.html'
  }
  $sampleText = @{}
  foreach ($key in $sampleFiles.Keys) {
    $path = Join-Path $sampleRoot $sampleFiles[$key]
    $exists = Test-Path -LiteralPath $path -PathType Leaf
    Add-Check $checks "FLOW-SAMPLE-FILE-$key" $(if ($exists) { "pass" } else { "fail" }) $sampleFiles[$key]
    if ($exists) { $sampleText[$key] = Get-Content -LiteralPath $path -Raw -Encoding UTF8 }
  }

  if ($sampleText.Count -eq $sampleFiles.Count) {
    $manifestOk = $sampleText.manifest.Contains('contract_set_version: r3-asset-runtime-v0.3') -and
      $sampleText.manifest.Contains('static_visual_director_plan: intermediate/05-visual-plan.md') -and
      $sampleText.manifest.Contains('visual_need_analysis: intermediate/05-visual-plan.md') -and
      $sampleText.manifest.Contains('platform_package_input: intermediate/07-platform-package-input.md')
    Add-Check $checks "FLOW-SAMPLE-MANIFEST" $(if ($manifestOk) { "pass" } else { "fail" }) "runtime v0.2 and canonical artifact paths"

    $legacyPlanExists = Test-Path -LiteralPath (Join-Path $sampleRoot 'intermediate/04-static-visual-director-plan.md') -PathType Leaf
    Add-Check $checks "FLOW-SAMPLE-SINGLE-PLAN-SOURCE" $(if (-not $legacyPlanExists) { "pass" } else { "fail" }) "05-visual-plan.md is the only planning source"

    $lineageTokens = @('R-SR3DR-001', 'VP-SR3DR-001', 'VTP-SR3DR-001', 'IMGSET-SR3DR-001')
    foreach ($token in $lineageTokens) {
      $missingStages = @('plan', 'review', 'package_input', 'package', 'delivery' | Where-Object { -not $sampleText[$_].Contains($token) })
      Add-Check $checks "FLOW-LINEAGE-$token" $(if ($missingStages.Count -eq 0) { "pass" } else { "fail" }) $(if ($missingStages.Count -eq 0) { "preserved across plan/review/package/delivery" } else { "missing in: $([string]::Join(', ', $missingStages))" })
    }

    $routeChecks = @(
      @{ id = 'PLAN-TO-PROMPT'; key = 'plan'; token = 'next_skill: image-prompt-compiler' },
      @{ id = 'REVIEW-TO-PACKAGE'; key = 'review'; token = 'next_skill: platform-packaging-adapter' },
      @{ id = 'PACKAGE-TO-COVER'; key = 'package'; token = 'next_skill: cover-design-compiler' },
      @{ id = 'COVER-TO-FINAL'; key = 'cover_review'; token = 'next_skill: final-delivery-builder' },
      @{ id = 'DELIVERY-TO-FINAL'; key = 'delivery'; token = 'next_skill: final-delivery-builder' }
    )
    foreach ($route in $routeChecks) {
      Add-Check $checks ("FLOW-" + $route.id) $(if ($sampleText[$route.key].Contains($route.token)) { "pass" } else { "fail" }) $route.token
    }

    $traceSkills = @('static-visual-director', 'image-prompt-compiler', 'image-asset-producer', 'copywriting-quality-review', 'platform-packaging-adapter', 'cover-design-compiler', 'final-delivery-builder')
    $traceMissing = @($traceSkills | Where-Object { -not $sampleText.trace.Contains($_) })
    $traceOk = $traceMissing.Count -eq 0 -and -not $sampleText.trace.Contains('intermediate/04-static-visual-director-plan.md')
    Add-Check $checks "FLOW-TRACE-STAGES" $(if ($traceOk) { "pass" } else { "fail" }) $(if ($traceOk) { "all compiled stages are traceable" } else { "missing/legacy: $([string]::Join(', ', $traceMissing))" })

    $finalTokens = @('data-visual-text-plan-id="VTP-SR3DR-001"', 'visual_text_quality_gate_status', '本图按计划无字', '发布描述', '话题标签')
    $finalMissing = @($finalTokens | Where-Object { -not $sampleText.final.Contains($_) })
    Add-Check $checks "FLOW-FINAL-DELIVERY" $(if ($finalMissing.Count -eq 0) { "pass" } else { "fail" }) $(if ($finalMissing.Count -eq 0) { "final HTML consumes visual text and platform materials" } else { "missing: $([string]::Join(', ', $finalMissing))" })

    $embedTokens = @('visual_text_plan_id: VTP-SR3DR-001', 'visual_text_task_id', 'visual_text_decision', 'visual_text_unit_ids', 'visual_text_render_strategy', 'visual_text_quality_gate_status')
    $embedMissing = @($embedTokens | Where-Object { -not $sampleText.embed.Contains($_) })
    Add-Check $checks "FLOW-HTML-EMBED-MANIFEST" $(if ($embedMissing.Count -eq 0) { "pass" } else { "fail" }) $(if ($embedMissing.Count -eq 0) { "embed manifest carries visual-text handoff" } else { "missing: $([string]::Join(', ', $embedMissing))" })
  }

  $failed = @($checks | Where-Object { $_.status -eq "fail" })
  $overall = if ($failed.Count -eq 0) { "pass" } else { "fail" }
  $report = [ordered]@{ r3_visual_text_check_report = [ordered]@{ fixture_set_id = $fixtureFile.fixture_set_id; overall_result = $overall; blocker_count = $failed.Count; checks = [object[]]$checks } }
  foreach ($path in @($HumanReportPath, $MachineReportPath)) {
    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  }
  Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 8
  $lines = @("# R3 Visual Text Check Report", "", "overall_result: $overall", "blocker_count: $($failed.Count)", "", "| Check | Status | Evidence |", "|---|---|---|")
  foreach ($check in $checks) { $lines += "| $($check.check_item_id) | $($check.status) | $($check.evidence) |" }
  Write-TaogeUtf8NoBomLines -Path $HumanReportPath -Lines $lines
  Write-Output "R3_VISUAL_TEXT_CHECK=$overall"
  Write-Output "BLOCKER_COUNT=$($failed.Count)"
  exit $(if ($failed.Count -eq 0) { 0 } else { 1 })
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
