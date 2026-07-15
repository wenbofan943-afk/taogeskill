param(
  [string]$ProjectRoot = "",
  [string]$RoutesPath = "routes\workflow-routes.yaml",
  [string]$RunControlProfilesPath = "routes\run-control-profiles.yaml",
  [string]$BuildProfilesPath = "routes\build-profiles.yaml",
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

    $buildProfilesFullPath = Join-Path $root $BuildProfilesPath
    $buildProfileText = ""
    $buildProfileBlocks = [ordered]@{}
    if (Test-Path -LiteralPath $buildProfilesFullPath) {
      $buildProfileLines = Get-Content -LiteralPath $buildProfilesFullPath -Encoding UTF8
      $buildProfileText = [string]::Join("`n", $buildProfileLines)
      $buildProfileBlocks = Get-RouteBlocks $buildProfileLines
    }

    $profilesFullPath = Join-Path $root $RunControlProfilesPath
    $profileNames = @()
    $profileBlocks = [ordered]@{}
    if (Test-Path -LiteralPath $profilesFullPath) {
      $profileLines = Get-Content -LiteralPath $profilesFullPath -Encoding UTF8
      $allProfileBlocks = Get-RouteBlocks $profileLines
      $insideProfiles = $false
      foreach ($line in $profileLines) {
        if ($line -match '^profiles:\s*$') {
          $insideProfiles = $true
          continue
        }
        if ($insideProfiles -and $line -match '^\S') {
          $insideProfiles = $false
        }
        if ($insideProfiles -and $line -match '^  ([a-z][a-z0-9_]*):\s*$') {
          $profileNames += $Matches[1]
        }
      }
      foreach ($profileName in $profileNames) {
        if ($allProfileBlocks.Contains($profileName)) {
          $profileBlocks[$profileName] = $allProfileBlocks[$profileName]
        }
      }
    }

    $items.Add((New-RouteCheckItem "ROUTE-001" "route_file" "blocker" "pass" "workflow route file exists." @($RoutesPath) @()))

    $routeCountStatus = if ($routeNames.Count -gt 0) { "pass" } else { "fail" }
    $items.Add((New-RouteCheckItem "ROUTE-002" "route_index" "blocker" $routeCountStatus ("route_count=" + $routeNames.Count) @($routeNames) @("Define at least one route under routes:.")))

    $missingAfter = New-Object System.Collections.Generic.List[string]
    $missingFields = New-Object System.Collections.Generic.List[string]
    $badAutoContinue = New-Object System.Collections.Generic.List[string]
    $missingReplies = New-Object System.Collections.Generic.List[string]
    $missingRunControl = New-Object System.Collections.Generic.List[string]
    $missingRunControlFields = New-Object System.Collections.Generic.List[string]
    $unknownBudgetProfiles = New-Object System.Collections.Generic.List[string]
    $badRunControlValues = New-Object System.Collections.Generic.List[string]
    $unboundedAutoContinue = New-Object System.Collections.Generic.List[string]
    $unknownBuildProfiles = New-Object System.Collections.Generic.List[string]

    $requiredAfterFields = @(
      "auto_continue_allowed",
      "on_success",
      "on_waiting_human",
      "on_blocked",
      "suggested_user_replies"
    )
    $requiredRunControlFields = @(
      "budget_profile",
      "auto_continue_scope",
      "business_checkpoint",
      "task_transition_authorization",
      "profile_escalation_authorization",
      "repair_scope"
    )

    foreach ($routeName in $routeNames) {
      $blockLines = $routeBlocks[$routeName]
      $blockText = [string]::Join("`n", $blockLines)

      if ($blockText -match '(?m)^    build_profile:\s*([a-z][a-z0-9_]*)\s*$') {
        $routeBuildProfile = $Matches[1]
        if (@('dev', 'test', 'public') -notcontains $routeBuildProfile) {
          $unknownBuildProfiles.Add($routeName + "=" + $routeBuildProfile)
        }
      } else {
        $unknownBuildProfiles.Add($routeName + "=missing")
      }

      if ($blockText -notmatch '(?m)^    run_control:\s*$') {
        $missingRunControl.Add($routeName)
      } else {
        foreach ($field in $requiredRunControlFields) {
          if ($blockText -notmatch ("(?m)^      " + [regex]::Escape($field) + "\s*:")) {
            $missingRunControlFields.Add($routeName + "." + $field)
          }
        }

        $budgetProfile = ""
        if ($blockText -match '(?m)^      budget_profile:\s*([a-z][a-z0-9_]*)\s*$') {
          $budgetProfile = $Matches[1]
          if ($profileNames -notcontains $budgetProfile) {
            $unknownBudgetProfiles.Add($routeName + "=" + $budgetProfile)
          }
        }

        $autoScope = ""
        if ($blockText -match '(?m)^      auto_continue_scope:\s*([a-z][a-z0-9_]*)\s*$') {
          $autoScope = $Matches[1]
        }
        foreach ($expected in @(
          @{ field = "business_checkpoint"; value = "required_before_followup" },
          @{ field = "task_transition_authorization"; value = "explicit_single_use" },
          @{ field = "profile_escalation_authorization"; value = "explicit" },
          @{ field = "repair_scope"; value = "current_task_type_only" }
        )) {
          $pattern = '(?m)^      ' + [regex]::Escape($expected.field) + ':\s*' + [regex]::Escape($expected.value) + '\s*$'
          if ($blockText -notmatch $pattern) {
            $badRunControlValues.Add($routeName + "." + $expected.field)
          }
        }
        if (($blockText -match '(?m)^      auto_continue_allowed:\s*true\s*$') -and $autoScope -eq "none") {
          $unboundedAutoContinue.Add($routeName)
        }
      }

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

    $profilesStatus = if (Test-Path -LiteralPath $profilesFullPath) { "pass" } else { "fail" }
    $items.Add((New-RouteCheckItem "ROUTE-009" "run_control" "blocker" $profilesStatus "Run-control profiles file must exist." @($RunControlProfilesPath) @("Restore routes/run-control-profiles.yaml.")))

    $badProfileFields = New-Object System.Collections.Generic.List[string]
    $requiredProfileFields = @(
      "max_continuous_elapsed_minutes",
      "max_tool_calls_when_observable",
      "max_same_failure_occurrences",
      "max_repair_rounds_per_issue",
      "max_context_compactions_when_observable"
    )
    foreach ($profileName in $profileNames) {
      $profileText = [string]::Join("`n", $profileBlocks[$profileName])
      foreach ($field in $requiredProfileFields) {
        if ($profileText -notmatch ("(?m)^    " + [regex]::Escape($field) + ":\s*[1-9][0-9]*\s*$")) {
          $badProfileFields.Add($profileName + "." + $field)
        }
      }
    }
    $items.Add((New-RouteCheckItem "ROUTE-010" "run_control" "blocker" ($(if ($profileNames.Count -gt 0 -and $badProfileFields.Count -eq 0) { "pass" } else { "fail" })) ("run_control_profile_count=" + $profileNames.Count) @($badProfileFields) @("Define positive integer budgets for every run-control profile.")))
    $items.Add((New-RouteCheckItem "ROUTE-011" "run_control" "blocker" ($(if ($missingRunControl.Count) { "fail" } else { "pass" })) "Each route must define run_control." @($missingRunControl) @("Add a run_control block to every route.")))
    $items.Add((New-RouteCheckItem "ROUTE-012" "run_control" "blocker" ($(if ($missingRunControlFields.Count) { "fail" } else { "pass" })) "run_control must include all required fields." @($missingRunControlFields) @("Add budget, scope, checkpoint, transition, profile escalation, and repair fields.")))
    $items.Add((New-RouteCheckItem "ROUTE-013" "run_control" "blocker" ($(if ($unknownBudgetProfiles.Count) { "fail" } else { "pass" })) "Each route budget_profile must resolve." @($unknownBudgetProfiles) @("Reference a profile declared in routes/run-control-profiles.yaml.")))
    $items.Add((New-RouteCheckItem "ROUTE-014" "run_control" "blocker" ($(if ($badRunControlValues.Count) { "fail" } else { "pass" })) "Transition, profile escalation, checkpoint, and repair policies must use the project baseline." @($badRunControlValues) @("Restore explicit_single_use / explicit / required_before_followup / current_task_type_only.")))
    $items.Add((New-RouteCheckItem "ROUTE-015" "run_control" "blocker" ($(if ($unboundedAutoContinue.Count) { "fail" } else { "pass" })) "Routes with auto-continue enabled must declare a non-none scope." @($unboundedAutoContinue) @("Set a bounded auto_continue_scope or disable auto_continue_allowed.")))

    $buildProfilesStatus = if (Test-Path -LiteralPath $buildProfilesFullPath) { "pass" } else { "fail" }
    $items.Add((New-RouteCheckItem "ROUTE-016" "build_profile" "blocker" $buildProfilesStatus "Build profiles file must exist." @($BuildProfilesPath) @("Restore routes/build-profiles.yaml.")))
    $items.Add((New-RouteCheckItem "ROUTE-017" "build_profile" "blocker" ($(if ($unknownBuildProfiles.Count) { "fail" } else { "pass" })) "Every route must select dev, test, or public." @($unknownBuildProfiles) @("Set a registered build_profile on every route.")))

    $badBuildProfilePolicy = New-Object System.Collections.Generic.List[string]
    foreach ($policy in @(
      @{ pattern = '(?m)^  authorization:\s*explicit_single_use\s*$'; name = 'profile_transition.authorization' },
      @{ pattern = '(?m)^  implicit_escalation_to_public:\s*forbidden\s*$'; name = 'profile_transition.implicit_escalation_to_public' },
      @{ pattern = '(?m)^  on_transition:\s*rerun_target_profile_gates\s*$'; name = 'profile_transition.on_transition' }
    )) {
      if ($buildProfileText -notmatch $policy.pattern) {
        $badBuildProfilePolicy.Add($policy.name)
      }
    }
    foreach ($profilePolicy in @(
      @{ profile = 'dev'; gate_mode = 'affected_focused'; public_required = 'false' },
      @{ profile = 'test'; gate_mode = 'current_test_matrix'; public_required = 'false' },
      @{ profile = 'public'; gate_mode = 'full_public'; public_required = 'true' }
    )) {
      if (-not $buildProfileBlocks.Contains($profilePolicy.profile)) {
        $badBuildProfilePolicy.Add($profilePolicy.profile + '.missing')
        continue
      }
      $profilePolicyText = [string]::Join("`n", $buildProfileBlocks[$profilePolicy.profile])
      if ($profilePolicyText -notmatch ('(?m)^    gate_mode:\s*' + [regex]::Escape($profilePolicy.gate_mode) + '\s*$')) {
        $badBuildProfilePolicy.Add($profilePolicy.profile + '.gate_mode')
      }
      if ($profilePolicyText -notmatch ('(?m)^    public_full_validation_required:\s*' + $profilePolicy.public_required + '\s*$')) {
        $badBuildProfilePolicy.Add($profilePolicy.profile + '.public_full_validation_required')
      }
    }
    $items.Add((New-RouteCheckItem "ROUTE-018" "build_profile" "blocker" ($(if ($badBuildProfilePolicy.Count) { "fail" } else { "pass" })) "Build-profile transitions and gate modes must prevent implicit public escalation." @($badBuildProfilePolicy) @("Restore explicit single-use transition authorization and dev/test/public gate modes.")))

    $docsNeeded = @(
      "docs/governance/agent-orchestration/after-task-guidance.md",
      "docs/governance/agent-orchestration/run-control.md",
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
    $indexNeedles = @("after-task-guidance.md", "after_completion", "run-control.md", "run-control-profiles.yaml")
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
      checker_version = "0.3.0"
      routes_path = $RoutesPath
      run_control_profiles_path = $RunControlProfilesPath
      build_profiles_path = $BuildProfilesPath
      overall_result = $overall
      failure_count = $failed.Count
      warning_count = $warnings.Count
      checks = [object[]]$items.ToArray()
    }
  }
  Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 8

  $lines = @("# Route Schema Check Report", "", '```yaml')
  $lines += "checker_version: 0.3.0"
  $lines += "routes_path: " + $RoutesPath
  $lines += "run_control_profiles_path: " + $RunControlProfilesPath
  $lines += "build_profiles_path: " + $BuildProfilesPath
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
