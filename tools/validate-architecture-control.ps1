[CmdletBinding()]
param(
  [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = Split-Path -Parent $PSScriptRoot
}

$root = [System.IO.Path]::GetFullPath($ProjectRoot)
$checks = New-Object System.Collections.Generic.List[object]
. (Join-Path $PSScriptRoot "YamlHelper.ps1")

function Add-ArchitectureCheck {
  param(
    [string]$Id,
    [bool]$Passed,
    [string]$Detail
  )

  $checks.Add([pscustomobject]@{
    id = $Id
    result = $(if ($Passed) { "pass" } else { "fail" })
    detail = $Detail
  })
}

function Read-ProjectText {
  param([string]$RelativePath)

  $path = Join-Path $root $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    return $null
  }
  return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}

function Require-Token {
  param(
    [string]$Id,
    [string]$RelativePath,
    [string]$Token
  )

  $text = Read-ProjectText $RelativePath
  $passed = ($null -ne $text) -and $text.Contains($Token)
  Add-ArchitectureCheck $Id $passed ($RelativePath + " contains " + $Token)
}

Require-Token "ARCH-001" "docs/governance/agent-orchestration/architecture-control.md" "architecture_planes_contract: product_control_work_data_evaluation"

$architecturePath = Join-Path $root "routes/architecture-control.yaml"
$architecture = Read-YamlFile $architecturePath
Add-ArchitectureCheck "ARCH-002" ($architecture.current_baseline.project_maturity -eq "L2_8") "current maturity remains L2_8"
Add-ArchitectureCheck "ARCH-003" ($architecture.current_baseline.workflow_ir_codegen -eq "not_implemented") "workflow IR codegen is not falsely claimed"
Add-ArchitectureCheck "ARCH-004" ($architecture.runtime_invariants.state_advancer -eq "deterministic_coordinator_only") "single state advancer"
Add-ArchitectureCheck "ARCH-005" ($architecture.certification.evaluator_self_certification_before_business_eval -eq "required") "evaluator self-certification required"
Add-ArchitectureCheck "ARCH-006" ($architecture.rule_promotion.one_machine_source_per_invariant -eq "required") "one machine source per invariant"
Add-ArchitectureCheck "ARCH-007" ($architecture.current_baseline.project_level_hook_enforcement -eq "not_configured") "project hook limitation remains explicit"
Add-ArchitectureCheck "ARCH-008" (
  ($architecture.current_decision.architecture_change_id -eq "ARCH-20260718-002") -and
  ($architecture.current_decision.decision_status -eq "confirmed")
) "current architecture decision is confirmed and versioned"
Add-ArchitectureCheck "ARCH-009" ($architecture.current_decision.runtime_migration_authorized -eq $false) "runtime migration is not implicitly authorized"

$planeNames = if ($architecture.planes -is [System.Collections.IDictionary]) {
  @($architecture.planes.Keys)
} else {
  @($architecture.planes.PSObject.Properties.Name)
}
$expectedPlanes = @("product", "control", "work", "data", "evaluation", "governance")
$missingPlanes = @($expectedPlanes | Where-Object { $planeNames -notcontains $_ })
Add-ArchitectureCheck "ARCH-010" ($missingPlanes.Count -eq 0) ("missing planes=" + ($missingPlanes -join ","))

$expectedRuleSequence = @(
  "incident_evidence",
  "failure_fingerprint",
  "root_cause_class",
  "reusable_invariant",
  "mechanical_gate",
  "scoped_documentation",
  "root_pointer_if_required"
)
$actualRuleSequence = @($architecture.rule_promotion.sequence)
$ruleSequenceMatches = (($actualRuleSequence -join "|") -eq ($expectedRuleSequence -join "|"))
Add-ArchitectureCheck "ARCH-011" $ruleSequenceMatches "rule promotion sequence is exact"
Add-ArchitectureCheck "ARCH-012" (
  $architecture.current_decision.selected_option -eq "lightweight_local_kernel_with_single_workflow_ir"
) "current decision selects the lightweight local kernel"
Require-Token "ARCH-013" "docs/governance/agent-orchestration/workflow-kernel-simplification.md" "ARCH2-D10"

foreach ($routeName in @("architecture_definition", "runtime_certification", "evaluation_certification")) {
  Require-Token ("ARCH-ROUTE-" + $routeName) "routes/workflow-routes.yaml" ("  " + $routeName + ":")
  Require-Token ("ARCH-READ-" + $routeName) "docs/governance/agent-orchestration/required-reads.yaml" ("  " + $routeName + ":")
}

Require-Token "ARCH-INDEX-AGENTS" "AGENTS.md" "docs/governance/agent-orchestration/architecture-control.md"
Require-Token "ARCH-INDEX-PROJECT" "PROJECT_MAP.md" "routes/architecture-control.yaml"
Require-Token "ARCH-INDEX-DOCS" "docs/README.md" "architecture-control.md"
Require-Token "ARCH-INDEX-GOV" "docs/governance/README.md" "architecture-control.md"
Require-Token "ARCH-INDEX-ORCHESTRATION" "docs/governance/agent-orchestration/README.md" "architecture-control.md"
Require-Token "ARCH-INDEX-ROUTES" "routes/README.md" "architecture-control.yaml"
Require-Token "ARCH-INDEX-TOOLS" "tools/README.md" "validate-architecture-control.ps1"

foreach ($check in $checks) {
  Write-Output ($check.id + " " + $check.result + " - " + $check.detail)
}

$failed = @($checks | Where-Object { $_.result -eq "fail" })
if ($failed.Count -gt 0) {
  Write-Output ("ARCHITECTURE_CONTROL_RESULT=fail failed=" + $failed.Count + " total=" + $checks.Count)
  exit 1
}

Write-Output ("ARCHITECTURE_CONTROL_RESULT=pass total=" + $checks.Count)
exit 0
