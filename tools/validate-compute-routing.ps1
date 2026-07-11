param(
  [string]$ProjectRoot = ".",
  [string]$HumanReportPath = "state/checks/compute-routing-check-report.md",
  [string]$MachineReportPath = "state/checks/compute-routing-check-report.json"
)

$ErrorActionPreference = "Stop"

function Read-TomlScalar {
  param([string]$Path, [string]$Key)
  $pattern = '^\s*' + [regex]::Escape($Key) + '\s*=\s*"([^"]+)"\s*$'
  $line = Get-Content -LiteralPath $Path -Encoding UTF8 |
    Where-Object { $_ -match $pattern } |
    Select-Object -First 1
  if ($line -and $line -match $pattern) { return $Matches[1] }
  return ""
}

function Add-Check {
  param([System.Collections.Generic.List[object]]$Checks, [string]$Id, [string]$Status, [string]$Evidence)
  $Checks.Add([pscustomobject]@{ check_item_id = $Id; status = $Status; evidence = $Evidence })
}

function Resolve-ReportPath {
  param([string]$Root, [string]$Path)
  if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
  return [IO.Path]::GetFullPath((Join-Path $Root $Path))
}

$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$configPath = Join-Path $root ".codex/config.toml"
$profilePath = Join-Path $root "routes/compute-profiles.yaml"
$workflowPath = Join-Path $root "routes/workflow-routes.yaml"
$checks = New-Object System.Collections.Generic.List[object]

foreach ($path in @($configPath, $profilePath, $workflowPath)) {
  Add-Check $checks "COMPUTE-FILE-$([IO.Path]::GetFileName($path))" $(if (Test-Path -LiteralPath $path -PathType Leaf) { "pass" } else { "fail" }) $path
}

if (@($checks | Where-Object status -eq "fail").Count -eq 0) {
  $defaultModel = Read-TomlScalar $configPath "model"
  $defaultEffort = Read-TomlScalar $configPath "model_reasoning_effort"
  Add-Check $checks "COMPUTE-DEFAULT-MODEL" $(if ($defaultModel -eq "gpt-5.6-terra") { "pass" } else { "fail" }) "model=$defaultModel"
  Add-Check $checks "COMPUTE-DEFAULT-EFFORT" $(if ($defaultEffort -eq "medium") { "pass" } else { "fail" }) "reasoning=$defaultEffort"
  $rootServiceTier = Read-TomlScalar $configPath "service_tier"
  Add-Check $checks "COMPUTE-FAST-DEFAULT-OFF" $(if ($rootServiceTier -ne "fast") { "pass" } else { "fail" }) "service_tier=$rootServiceTier"

  $profiles = [ordered]@{}
  $inProfiles = $false
  $currentProfile = ""
  foreach ($line in Get-Content -LiteralPath $profilePath -Encoding UTF8) {
    if ($line -eq "profiles:") { $inProfiles = $true; continue }
    if ($line -eq "speed_overrides:") { $inProfiles = $false; $currentProfile = ""; continue }
    if ($inProfiles -and $line -match "^  ([a-z][a-z0-9_]+):\s*$") {
      $currentProfile = $Matches[1]
      $profiles[$currentProfile] = [ordered]@{}
      continue
    }
    if ($inProfiles -and $currentProfile -and $line -match "^    ([a-z][a-z0-9_]+):\s*(.+?)\s*$") {
      $profiles[$currentProfile][$Matches[1]] = $Matches[2].Trim('"').Trim("'")
    }
  }
  Add-Check $checks "COMPUTE-PROFILE-COUNT" $(if ($profiles.Count -eq 6) { "pass" } else { "fail" }) "count=$($profiles.Count)"

  $routes = [ordered]@{}
  $inRoutes = $false
  $currentRoute = ""
  foreach ($line in Get-Content -LiteralPath $workflowPath -Encoding UTF8) {
    if ($line -eq "routes:") { $inRoutes = $true; continue }
    if ($inRoutes -and $line -match "^  ([a-z][a-z0-9_]+):\s*$") {
      $currentRoute = $Matches[1]
      $routes[$currentRoute] = ""
      continue
    }
    if ($inRoutes -and $currentRoute -and $line -match "^    compute_profile:\s*([a-z][a-z0-9_]+)\s*$") {
      $routes[$currentRoute] = $Matches[1]
    }
  }
  $missingRouteProfiles = @($routes.GetEnumerator() | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Value) } | ForEach-Object Key)
  $unknownRouteProfiles = @($routes.GetEnumerator() | Where-Object { $_.Value -and -not $profiles.Contains($_.Value) } | ForEach-Object { "$($_.Key)=$($_.Value)" })
  Add-Check $checks "COMPUTE-ROUTE-COVERAGE" $(if ($routes.Count -eq 16 -and $missingRouteProfiles.Count -eq 0) { "pass" } else { "fail" }) "routes=$($routes.Count); missing=$([string]::Join(',', $missingRouteProfiles))"
  Add-Check $checks "COMPUTE-ROUTE-REFERENCES" $(if ($unknownRouteProfiles.Count -eq 0) { "pass" } else { "fail" }) "unknown=$([string]::Join(',', $unknownRouteProfiles))"

  foreach ($entry in $profiles.GetEnumerator()) {
    $profileName = $entry.Key
    $role = [string]$entry.Value.role
    $expectedModel = [string]$entry.Value.model
    $expectedEffort = [string]$entry.Value.reasoning_effort
    $rolePath = Join-Path $root ".codex/agents/$($role.Replace('_','-')).config.toml"
    $exists = Test-Path -LiteralPath $rolePath -PathType Leaf
    Add-Check $checks "COMPUTE-ROLE-$profileName" $(if ($exists) { "pass" } else { "fail" }) "$role -> $rolePath"
    if ($exists) {
      $actualModel = Read-TomlScalar $rolePath "model"
      $actualEffort = Read-TomlScalar $rolePath "model_reasoning_effort"
      Add-Check $checks "COMPUTE-ROLE-MATCH-$profileName" $(if ($actualModel -eq $expectedModel -and $actualEffort -eq $expectedEffort) { "pass" } else { "fail" }) "expected=$expectedModel/$expectedEffort actual=$actualModel/$actualEffort"
    }
  }

  $governancePath = Join-Path $root "docs/governance/agent-orchestration/model-and-compute-routing.md"
  $mapPath = Join-Path $root "PROJECT_MAP.md"
  $agentsPath = Join-Path $root "AGENTS.md"
  Add-Check $checks "COMPUTE-DOC" $(if (Test-Path -LiteralPath $governancePath -PathType Leaf) { "pass" } else { "fail" }) $governancePath
  $mapText = Get-Content -LiteralPath $mapPath -Raw -Encoding UTF8
  $agentsText = Get-Content -LiteralPath $agentsPath -Raw -Encoding UTF8
  Add-Check $checks "COMPUTE-INDEX" $(if ($mapText.Contains('model-and-compute-routing.md') -and $agentsText.Contains('routes/compute-profiles.yaml')) { "pass" } else { "fail" }) "PROJECT_MAP and AGENTS index compute routing"
}

$failures = @($checks | Where-Object status -eq "fail")
$result = if ($failures.Count -eq 0) { "pass" } else { "fail" }
$report = [ordered]@{
  checker_id = "compute_routing_checker"
  checker_version = "0.1.0"
  overall_result = $result
  failure_count = $failures.Count
  checks = $checks.ToArray()
}

$humanFull = Resolve-ReportPath $root $HumanReportPath
$machineFull = Resolve-ReportPath $root $MachineReportPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $humanFull) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $machineFull) | Out-Null
$lines = @("# Compute Routing Check Report", "", '```yaml', "overall_result: $result", "failure_count: $($failures.Count)", '```', "", "| Check | Status | Evidence |", "|---|---|---|")
foreach ($check in $checks) { $lines += "| $($check.check_item_id) | $($check.status) | $($check.evidence -replace '\|','/') |" }
$lines | Set-Content -LiteralPath $humanFull -Encoding UTF8
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $machineFull -Encoding UTF8

Write-Output "COMPUTE_ROUTING_CHECK=$result"
Write-Output "FAILURE_COUNT=$($failures.Count)"
if ($failures.Count -gt 0) { exit 1 }
