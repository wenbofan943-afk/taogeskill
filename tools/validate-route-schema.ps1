param(
  [string]$ProjectRoot = "",
  [string]$RoutesPath = "routes\workflow-routes.yaml",
  [string]$HumanReportPath = "",
  [string]$MachineReportPath = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')

function New-RouteCheckItem {
  param(
    [string]$Id,
    [string]$Group,
    [string]$Severity,
    [string]$Status,
    [string]$Summary,
    [string[]]$Evidence = @(),
    [string[]]$Remediation = @()
  )
  [pscustomobject]@{
    check_item_id = $Id
    group = $Group
    severity = $Severity
    status = $Status
    evidence = $Evidence
    evidence_summary = $Summary
    remediation_items = $Remediation
  }
}

function Get-RouteBlocks {
  param([string[]]$Lines)

  $blocks = [ordered]@{}
  $currentName = $null
  $currentLines = New-Object System.Collections.Generic.List[string]

  foreach ($line in $Lines) {
    if ($line -match '^  ([a-z][a-z0-9_]*):\s*$') {
      if ($null -ne $currentName) {
        $blocks[$currentName] = [string[]]$currentLines.ToArray()
        $currentLines.Clear()
      }
      $currentName = $Matches[1]
      $currentLines.Add($line)
      continue
    }

    if ($null -ne $currentName) {
      if ($line -match '^\S') {
        $blocks[$currentName] = [string[]]$currentLines.ToArray()
        $currentName = $null
        $currentLines.Clear()
      } else {
        $currentLines.Add($line)
      }
    }
  }

  if ($null -ne $currentName) {
    $blocks[$currentName] = [string[]]$currentLines.ToArray()
  }

  return $blocks
}

try {
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
  }
  $root = (Resolve-Path -LiteralPath $ProjectRoot).Path

  if ([string]::IsNullOrWhiteSpace($HumanReportPath)) {
    $HumanReportPath = Join-Path $root "state\checks\route-schema-check-report.md"
  }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
    $MachineReportPath = Join-Path $root "state\checks\route-schema-check-report.json"
  }

  $reportDir = Split-Path -Parent $HumanReportPath
  if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
  }

  $routesFullPath = Join-Path $root $RoutesPath
  $items = New-Object System.Collections.Generic.List[object]

  if (-not (Test-Path -LiteralPath $routesFullPath)) {
    $items.Add((New-RouteCheckItem "ROUTE-001" "route_file" "blocker" "fail" "workflow route file is missing." @($RoutesPath) @("Restore routes/workflow-routes.yaml.")))
  } else {
    $lines = Get-Content -LiteralPath $routesFullPath -Encoding UTF8
    $text = [string]::Join("`n", $lines)
    $routeBlocks = Get-RouteBlocks $lines
    $routeNames = @($routeBlocks.Keys)

    $items.Add((New-RouteCheckItem "ROUTE-001" "route_file" "blocker" "pass" "workflow route file exists." @($RoutesPath) @()))

    $routeCountStatus = if ($routeNames.Count -gt 0) { "pass" } else { "fail" }
    $items.Add((New-RouteCheckItem "ROUTE-002" "route_index" "blocker" $routeCountStatus ("route_count=" + $routeNames.Count) @($routeNames) @("Define at least one route under routes:.")))

    $missingAfter = New-Object System.Collections.Generic.List[string]
    $missingFields = New-Object System.Collections.Generic.List[string]
    $badAutoContinue = New-Object System.Collections.Generic.List[string]
    $missingReplies = New-Object System.Collections.Generic.List[string]

    $requiredAfterFields = @(
      "auto_continue_allowed",
      "on_success",
      "on_waiting_human",
      "on_blocked",
      "suggested_user_replies"
    )

    foreach ($routeName in $routeNames) {
      $blockLines = $routeBlocks[$routeName]
      $blockText = [string]::Join("`n", $blockLines)

      if ($blockText -notmatch '(?m)^    after_completion:\s*$') {
        $missingAfter.Add($routeName)
        continue
      }

      foreach ($field in $requiredAfterFields) {
        if ($blockText -notmatch ("(?m)^      " + [regex]::Escape($field) + "(\s*:|:)")) {
          $missingFields.Add($routeName + "." + $field)
        }
      }

      if ($blockText -notmatch '(?m)^      auto_continue_allowed:\s*(true|false)\s*$') {
        $badAutoContinue.Add($routeName)
      }

      $replyCount = 0
      $insideReplies = $false
      foreach ($line in $blockLines) {
        if ($line -match '^      suggested_user_replies:\s*$') {
          $insideReplies = $true
          continue
        }
        if ($insideReplies -and $line -match '^      [a-z_]+:') {
          $insideReplies = $false
        }
        if ($insideReplies -and $line -match '^        -\s+".+"') {
          $replyCount += 1
        }
      }
      if ($replyCount -lt 2) {
        $missingReplies.Add($routeName + "(reply_count=" + $replyCount + ")")
      }
    }

    $items.Add((New-RouteCheckItem "ROUTE-003" "after_completion" "blocker" ($(if ($missingAfter.Count) { "fail" } else { "pass" })) "Each route must define after_completion." @($missingAfter) @("Add after_completion to every route.")))
    $items.Add((New-RouteCheckItem "ROUTE-004" "after_completion" "blocker" ($(if ($missingFields.Count) { "fail" } else { "pass" })) "after_completion must include required fields." @($missingFields) @("Add auto_continue_allowed, on_success, on_waiting_human, on_blocked, suggested_user_replies.")))
    $items.Add((New-RouteCheckItem "ROUTE-005" "after_completion" "blocker" ($(if ($badAutoContinue.Count) { "fail" } else { "pass" })) "auto_continue_allowed must be explicit boolean true / false." @($badAutoContinue) @("Set auto_continue_allowed to true or false.")))
    $items.Add((New-RouteCheckItem "ROUTE-006" "human_guidance" "warning" ($(if ($missingReplies.Count) { "warn" } else { "pass" })) "Each route should provide at least two suggested user replies." @($missingReplies) @("Add 2-5 practical suggested_user_replies for the route.")))

    $docsNeeded = @(
      "docs/governance/agent-orchestration/after-task-guidance.md",
      "docs/governance/agent-orchestration/state-and-gates.md",
      "docs/governance/agent-orchestration/task-routing.md"
    )
    $missingDocs = @($docsNeeded | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_)) })
    $items.Add((New-RouteCheckItem "ROUTE-007" "docs_sync" "blocker" ($(if ($missingDocs.Count) { "fail" } else { "pass" })) "Orchestration guidance docs must exist." @($missingDocs) @("Restore missing governance docs.")))

    $indexText = ""
    foreach ($rel in @("AGENTS.md", "PROJECT_MAP.md", "docs/governance/agent-orchestration/README.md", "routes/README.md")) {
      $full = Join-Path $root $rel
      if (Test-Path -LiteralPath $full) {
        $indexText += "`n" + (Get-Content -LiteralPath $full -Raw -Encoding UTF8)
      }
    }
    $indexNeedles = @("after-task-guidance.md", "after_completion")
    $missingIndex = @($indexNeedles | Where-Object { -not $indexText.Contains($_) })
    $items.Add((New-RouteCheckItem "ROUTE-008" "docs_sync" "warning" ($(if ($missingIndex.Count) { "warn" } else { "pass" })) "Entry docs should mention after-task guidance and after_completion." @($missingIndex) @("Update AGENTS, PROJECT_MAP, orchestration README, or routes README.")))
  }

  $failed = @($items | Where-Object { $_.status -eq "fail" })
  $warnings = @($items | Where-Object { $_.status -eq "warn" })
  $overall = if ($failed.Count -gt 0) { "fail" } elseif ($warnings.Count -gt 0) { "pass_with_warnings" } else { "pass" }
  $exitCode = if ($failed.Count -gt 0) { 1 } else { 0 }

  $report = [ordered]@{
    route_schema_check_report = [ordered]@{
      route_schema_check_report_id = "ROUTECHK-" + (Get-Date -Format "yyyyMMdd-HHmmss")
      checker_version = "0.1.0"
      routes_path = $RoutesPath
      overall_result = $overall
      failure_count = $failed.Count
      warning_count = $warnings.Count
      checks = [object[]]$items.ToArray()
    }
  }
  Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 8

  $lines = @("# Route Schema Check Report", "", '```yaml')
  $lines += "checker_version: 0.1.0"
  $lines += "routes_path: " + $RoutesPath
  $lines += "overall_result: " + $overall
  $lines += "exit_code: " + $exitCode
  $lines += "failure_count: " + $failed.Count
  $lines += "warning_count: " + $warnings.Count
  $lines += '```'
  $lines += ""
  $lines += "| Check ID | Status | Summary | Evidence |"
  $lines += "|---|---|---|---|"
  foreach ($item in $items) {
    $evidenceText = if ($item.evidence.Count) { [string]::Join("<br>", @($item.evidence)) } else { "" }
    $lines += ("| {0} | {1} | {2} | {3} |" -f $item.check_item_id, $item.status, $item.evidence_summary, $evidenceText)
  }
  $lines += ""
  $lines += "## Boundary"
  $lines += ""
  $lines += "This checker only reads route and governance files. It does not commit, push, tag, publish, generate content, or call external services."
  Write-TaogeUtf8NoBomLines -Path $HumanReportPath -Lines $lines

  Write-Output ("ROUTE_SCHEMA_CHECK_RESULT=" + $overall)
  exit $exitCode
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
