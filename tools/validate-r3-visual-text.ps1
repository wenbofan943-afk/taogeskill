param(
  [string]$FixturePath = "examples/r3-visual-text-fixtures/fixtures.json",
  [string]$HumanReportPath = "state/checks/r3-visual-text-check-report.md",
  [string]$MachineReportPath = "state/checks/r3-visual-text-check-report.json"
)

$ErrorActionPreference = "Stop"

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
  $sourceContracts = @(
    @{ id = "SRC-DIRECTOR"; path = "skills/static-visual-director/SKILL.md"; needles = @("visual_text_tasks", "is_source_required", "evidence_source_path", "next_skill: image-prompt-compiler") },
    @{ id = "SRC-PROMPT"; path = "skills/image-prompt-compiler/SKILL.md"; needles = @("visual_text_task_id", "visual_text_decision", "allow_text_in_image=false", "next_skill: image-asset-producer") },
    @{ id = "SRC-ASSET"; path = "skills/image-asset-producer/SKILL.md"; needles = @("compose-visual-text.ps1", "deterministic_overlay", "visual_text_unit_ids", "next_skill: copywriting-quality-review") },
    @{ id = "SRC-ORCHESTRATOR"; path = "skills/talking-head-image-pip/SKILL.md"; needles = @("static-visual-director", "image-prompt-compiler", "image-asset-producer", "r3-asset-runtime-v0.2") },
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

  $failed = @($checks | Where-Object { $_.status -eq "fail" })
  $overall = if ($failed.Count -eq 0) { "pass" } else { "fail" }
  $report = [ordered]@{ r3_visual_text_check_report = [ordered]@{ fixture_set_id = $fixtureFile.fixture_set_id; overall_result = $overall; blocker_count = $failed.Count; checks = [object[]]$checks } }
  foreach ($path in @($HumanReportPath, $MachineReportPath)) {
    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  }
  $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $MachineReportPath -Encoding UTF8
  $lines = @("# R3 Visual Text Check Report", "", "overall_result: $overall", "blocker_count: $($failed.Count)", "", "| Check | Status | Evidence |", "|---|---|---|")
  foreach ($check in $checks) { $lines += "| $($check.check_item_id) | $($check.status) | $($check.evidence) |" }
  $lines | Set-Content -LiteralPath $HumanReportPath -Encoding UTF8
  Write-Output "R3_VISUAL_TEXT_CHECK=$overall"
  Write-Output "BLOCKER_COUNT=$($failed.Count)"
  exit $(if ($failed.Count -eq 0) { 0 } else { 1 })
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
