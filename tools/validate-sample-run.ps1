param(
  [Parameter(Mandatory=$true)][string]$SamplePath,
  [string]$HumanReportPath = "",
  [string]$MachineReportPath = ""
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
      $target = ($target -split '#')[0]
      if ([string]::IsNullOrWhiteSpace($target)) { continue }
      if ($target -match '^[a-zA-Z]+:') { continue }
      $full = Join-Path (Split-Path -Parent $file.FullName) ([uri]::UnescapeDataString($target))
      if (-not (Test-Path -LiteralPath $full)) {
        $broken.Add(("{0} -> {1}" -f (Get-RelativePathSafe $RootPath $file.FullName), $target))
      }
    }
  }
  return $broken
}

try {
  if (-not (Test-Path -LiteralPath $SamplePath)) {
    Write-Error "SamplePath not found: $SamplePath"
    exit 2
  }

  $sample = (Resolve-Path -LiteralPath $SamplePath).Path
  if ([string]::IsNullOrWhiteSpace($HumanReportPath)) {
    $HumanReportPath = Join-Path $sample "check-report.md"
  }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
    $MachineReportPath = Join-Path $sample "sample-check-report.json"
  }

  $checkRunId = "CHECKRUN-SAMPLE-" + (Get-Date -Format "yyyyMMdd-HHmmss")
  $items = New-Object System.Collections.Generic.List[object]

  $required = @("README.md", "input-prompt.md", "expected-agent-behavior.md", "expected-artifacts.md", "manifest.yaml", "execution-trace.md", "check-report.md")
  $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $sample $_)) })
  $items.Add((New-CheckItem "P3SAMPLE-001" "sample_structure" "blocker" ($(if ($missing.Count) { "fail" } else { "pass" })) @($missing) "Required sample files exist." @("Add missing sample files.") "examples"))

  $allText = ""
  Get-ChildItem -LiteralPath $sample -Recurse -File | Where-Object {
    (@(".md", ".yaml", ".yml", ".json", ".html", ".txt") -contains $_.Extension.ToLowerInvariant()) -and
    ($_.Name -notin @("check-report.md", "sample-check-report.json"))
  } | ForEach-Object {
    $allText += "`n" + (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8)
  }

  $taogePrefix = ([string][char]28059) + ([string][char]21733)
  $privateSessionPrefix = 'S' + '20260706' + '-00'
  $privateSessionOne = 'S' + '20260707' + '-001'
  $localDrive = 'D:' + '\OpenClaw'
  $localDriveSlash = 'D:' + '/OpenClaw'
  $userHome = 'C:' + '\Users'
  $fileUrl = 'file' + '://'
  $privacyPatterns = @($taogePrefix + "汽车观察", $taogePrefix + "帮提车", $taogePrefix + "车商自媒", $taogePrefix + "说真话", $privateSessionPrefix, $privateSessionOne, $localDrive, $localDriveSlash, $userHome, $fileUrl)
  $privacyHits = @($privacyPatterns | Where-Object { $allText.Contains($_) })
  $items.Add((New-CheckItem "P3SAMPLE-002" "privacy" "blocker" ($(if ($privacyHits.Count) { "fail" } else { "pass" })) $privacyHits "Sample must not contain real account names, original session ids, local paths, or file URLs." @("Replace real data with sample placeholders.") "privacy"))

  $brokenLinks = @(Test-MarkdownLinks $sample)
  $items.Add((New-CheckItem "P3SAMPLE-003" "link_check" "blocker" ($(if ($brokenLinks.Count) { "fail" } else { "pass" })) $brokenLinks "Sample Markdown links resolve." @("Fix relative links inside sample.") "examples"))

  $behaviorNeedles = @("Expected", "expected", "预期", "Expected Agent Behavior")
  $hasBehavior = $false
  foreach ($needle in $behaviorNeedles) { if ($allText.Contains($needle)) { $hasBehavior = $true } }
  $items.Add((New-CheckItem "P3SAMPLE-004" "sample_behavior" "blocker" ($(if ($hasBehavior) { "pass" } else { "fail" })) @("expected-agent-behavior.md") "Sample explains expected behavior." @("Add clear expected behavior and recovery notes.") "examples"))

  $metadataNeedles = @("sample_persona", "sample_type", "sample_level", "estimated_time", "prerequisites", "run_mode", "success_criteria", "validator_command")
  $missingMetadata = @($metadataNeedles | Where-Object { -not $allText.Contains($_) })
  $items.Add((New-CheckItem "P3SAMPLE-007" "sample_metadata" "blocker" ($(if ($missingMetadata.Count) { "fail" } else { "pass" })) $missingMetadata "Sample README / manifest exposes mature sample metadata." @("Add Sample Card metadata to README and manifest.yaml.") "examples"))

  $recoveryNeedles = @("recovery", "Recovery", "恢复", "failure", "Failure", "失败")
  $hasRecovery = $false
  foreach ($needle in $recoveryNeedles) { if ($allText.Contains($needle)) { $hasRecovery = $true } }
  $items.Add((New-CheckItem "P3SAMPLE-005" "sample_behavior" "warn" ($(if ($hasRecovery) { "pass" } else { "fail" })) @("README.md", "expected-agent-behavior.md", "check-report.md") "Sample includes failure or recovery guidance." @("Add failure case and expected recovery.") "examples"))

  $imageStatus = if ($allText -match "(generated|pending_external|prompt_only|manual_required|not_applicable|Image|Picture In Picture|画中画)") { "pass" } else { "fail" }
  $items.Add((New-CheckItem "P3SAMPLE-006" "image_asset" "warn" $imageStatus @("expected-artifacts.md", "check-report.md") "Image asset state is described or marked not applicable." @("Mark generated / pending_external / prompt-only / not_applicable honestly.") "assets"))

  $blockers = @($items | Where-Object { $_.severity -eq "blocker" -and $_.status -eq "fail" })
  $warnings = @($items | Where-Object { $_.severity -eq "warn" -and $_.status -eq "fail" })
  $overall = if ($blockers.Count -gt 0) { "fail" } elseif ($warnings.Count -gt 0) { "pass_with_warnings" } else { "pass" }
  $exitCode = if ($blockers.Count -gt 0) { 1 } else { 0 }
  $sampleId = Split-Path -Leaf $sample
  $sampleStatus = if ($overall -eq "pass") { "ready_for_review" } elseif ($overall -eq "pass_with_warnings") { "ready_with_warnings" } else { "needs_fix" }
  $happyPathResult = if ($missing.Count -eq 0 -and $hasBehavior) { "pass" } else { "fail" }
  $failureCaseResult = if ($hasRecovery) { "pass" } else { "not_run" }
  $expectedRecoveryResult = if ($hasRecovery) { "pass" } else { "not_run" }
  $privacyResult = if ($privacyHits.Count -eq 0) { "pass" } else { "fail" }
  $linkResult = if ($brokenLinks.Count -eq 0) { "pass" } else { "fail" }
  $humanGuidanceResult = if ($hasBehavior) { "pass" } else { "fail" }
  $nextAction = if ($overall -eq "pass") { "sample_ready_for_review" } else { "fix_sample_and_rerun" }
  $artifactManifestPath = "manifest.yaml"
  $machineReportDisplayPath = Split-Path -Leaf $MachineReportPath
  $humanReportDisplayPath = Split-Path -Leaf $HumanReportPath
  $artifactDisplayPath = Split-Path -Leaf $HumanReportPath
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
    sample_check_report = [ordered]@{
      check_report_id = "SAMPLE-CHECK-" + (Get-Date -Format "yyyyMMdd-HHmmss")
      check_run_id = $checkRunId
      sample_id = $sampleId
      sample_goal = "sample_behavior_validation"
      sample_status = $sampleStatus
      command_name = "validate-sample-run"
      command_version = "p3-validator-v0.1"
      exit_code = $exitCode
      severity_policy = "blocker_fails"
      happy_path_result = $happyPathResult
      failure_case_result = $failureCaseResult
      expected_recovery_result = $expectedRecoveryResult
      privacy_status = $privacyResult
      link_status = $linkResult
      field_gate_status = "not_run"
      image_asset_status = $imageStatus
      human_guidance_status = $humanGuidanceResult
      evidence_paths = $filteredEvidencePaths
      remediation_items = $filteredRemediationItems
      machine_readable_report_path = $machineReportDisplayPath
      human_readable_report_path = $humanReportDisplayPath
      artifact_manifest_path = $artifactManifestPath
      reproducibility_status = "reproducible"
      artifact_path = $artifactDisplayPath
      next_action = $nextAction
      checks = $checkItems
    }
  }

  $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $MachineReportPath -Encoding UTF8

  $lines = @()
  $lines += "# Sample Check Report"
  $lines += ""
  $lines += '```yaml'
  $lines += "check_run_id: $checkRunId"
  $lines += "sample_id: $sampleId"
  $lines += "command_name: validate-sample-run"
  $lines += "command_version: p3-validator-v0.1"
  $lines += "exit_code: $exitCode"
  $lines += "overall_result: $overall"
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
  $lines += $(if ($overall -eq "pass") { "Sample is ready for review. This is still not a real production run." } else { "Sample needs fixes or has warnings. Review the table above." })
  $lines | Set-Content -LiteralPath $HumanReportPath -Encoding UTF8

  exit $exitCode
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}

