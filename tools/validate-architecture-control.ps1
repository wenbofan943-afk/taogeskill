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
Add-ArchitectureCheck "ARCH-003" ($architecture.current_baseline.workflow_ir_codegen -eq "m4_new_session_generation_switch_compiled") "new session generation switch is compiled without claiming runtime certification"
Add-ArchitectureCheck "ARCH-004" ($architecture.runtime_invariants.state_advancer -eq "deterministic_coordinator_only") "single state advancer"
Add-ArchitectureCheck "ARCH-005" ($architecture.certification.evaluator_self_certification_before_business_eval -eq "required") "evaluator self-certification required"
Add-ArchitectureCheck "ARCH-006" ($architecture.rule_promotion.one_machine_source_per_invariant -eq "required") "one machine source per invariant"
Add-ArchitectureCheck "ARCH-007" ($architecture.current_baseline.project_level_hook_enforcement -eq "not_configured") "project hook limitation remains explicit"
Add-ArchitectureCheck "ARCH-008" (
  ($architecture.current_decision.architecture_change_id -eq "ARCH-20260718-002") -and
  ($architecture.current_decision.decision_status -eq "confirmed")
) "current architecture decision is confirmed and versioned"
Add-ArchitectureCheck "ARCH-009" (
  ($architecture.current_decision.current_runtime_switch_authorized -eq $true) -and
  ($architecture.current_decision.m2_direct_shadow_runtime_authorized -eq $true) -and
  ($architecture.current_decision.m3_hotspot_shadow_runtime_authorized -eq $true) -and
  ($architecture.current_decision.m3_status -eq "completed") -and
  ($architecture.current_decision.m3_runtime_switch -eq "not_performed") -and
  ($architecture.current_decision.m4_new_session_switch_authorized -eq $true) -and
  ($architecture.current_decision.m4_status -eq "completed") -and
  ($architecture.current_decision.m4_existing_session_migration -eq "forbidden") -and
  ($architecture.current_decision.m4_runtime_certification -eq "not_run")
) "M2 and M3 shadow runtimes are complete and M4 switches only future new sessions without certification"
Add-ArchitectureCheck "ARCH-014" (
  ($architecture.current_decision.m1_static_compile_authorized -eq $true) -and
  ($architecture.current_decision.m1_status -eq "completed") -and
  ($architecture.current_decision.m1_runtime_switch -eq "not_performed")
) "M1 is completed as static compile only"
Add-ArchitectureCheck "ARCH-015" (
  ($architecture.migration.M1.status -eq "completed") -and
  ($architecture.migration.M2.status -eq "completed") -and
  ($architecture.migration.M2.comparison_baseline_kind -eq "frozen_legacy_contract_fixture") -and
  ($architecture.migration.M2.real_legacy_runtime_executed -eq $false) -and
  ($architecture.migration.M2.runtime_switch -eq "not_performed") -and
  ($architecture.migration.M3.status -eq "completed") -and
  ($architecture.migration.M3.external_retry_count -eq 0) -and
  ($architecture.migration.M3.real_legacy_runtime_executed -eq $false) -and
  ($architecture.migration.M3.runtime_switch -eq "not_performed") -and
  ($architecture.migration.M4.status -eq "completed") -and
  ($architecture.migration.M4.default_new_session_generation -eq "kernel_v1_current") -and
  ($architecture.migration.M4.existing_session_policy -eq "generation_pinned_no_in_place_migration") -and
  ($architecture.migration.M4.runtime_certification -eq "not_run") -and
  ($architecture.migration.M4.archived_tracked_assets -eq 0) -and
  ($architecture.migration.M4.archive_deferral_reason -eq "legacy_runtime_and_shadow_gate_consumers_still_active")
) "M1-M3 evidence remains intact and M4 pins new/current versus existing/legacy generations"

$workflowIr = Read-ProjectText "routes/current-workflow-ir.json" | ConvertFrom-Json
$componentCatalog = Read-ProjectText "routes/component-catalog.json" | ConvertFrom-Json
$compatibilityCatalog = Read-ProjectText "routes/compatibility-catalog.json" | ConvertFrom-Json
Add-ArchitectureCheck "ARCH-016" (
  (@($workflowIr.stage_order).Count -eq 7) -and
  (@($workflowIr.routes).Count -eq 2) -and
  ($workflowIr.runtime_generation -eq "kernel_v1_current") -and
  ($workflowIr.runtime_switch_enabled -eq $true) -and
  ($workflowIr.session_generation_policy.activation_status -eq "active_new_sessions") -and
  ($workflowIr.session_generation_policy.default_new_session_generation -eq "kernel_v1_current") -and
  ($workflowIr.session_generation_policy.rollback_new_session_generation -eq "legacy_r7") -and
  ($workflowIr.session_generation_policy.existing_session_migration -eq "forbidden") -and
  ($workflowIr.session_generation_policy.rollback_scope -eq "future_new_sessions_only") -and
  ($workflowIr.session_generation_policy.runtime_certification -eq "not_run") -and
  ((@($workflowIr.shadow_execution_policy.authorized_routes) -join "|") -eq "direct|hotspot") -and
  ($workflowIr.shadow_execution_policy.execution_scope -eq "direct_positive_path_to_final_human_wait") -and
  ($workflowIr.shadow_execution_policy.intermediate_non_progress_behavior -eq "block_before_shadow_write") -and
  ($workflowIr.shadow_execution_policy.hotspot_execution_scope -eq "hotspot_positive_wait_resume_freshness_and_reversal") -and
  ($workflowIr.shadow_execution_policy.hotspot_resume_mode -eq "append_command_reconcile_persisted_outcome_before_retry") -and
  ($workflowIr.shadow_execution_policy.runtime_certification -eq $false)
) "current Workflow IR has seven stages, an active new-session generation switch, isolated shadow scopes, and no certification claim"
Add-ArchitectureCheck "ARCH-017" (@($componentCatalog.components).Count -gt 0) "component catalog is populated; exact coverage is owned by the M1 parity checker"
Add-ArchitectureCheck "ARCH-018" (
  (@($compatibilityCatalog.historical_blueprints).Count -gt 0) -and
  ($compatibilityCatalog.current_kernel_load_allowed -eq $false)
) "compatibility catalog is populated outside current kernel; exact coverage is owned by the M1 parity checker"
Require-Token "ARCH-019" "tools/compile-workflow-ir.ps1" "WORKFLOW_IR_RESULT=pass"
Require-Token "ARCH-020" "tools/validate-workflow-ir-m1.ps1" "WORKFLOW_IR_M1_FIXTURE_RESULT=pass"
Require-Token "ARCH-022" "tools/invoke-workflow-kernel-shadow.ps1" "Invoke-WorkflowKernelDirectShadow"
Require-Token "ARCH-023" "tools/validate-workflow-kernel-m2.ps1" "WORKFLOW_KERNEL_M2_RESULT=pass"
Require-Token "ARCH-024" "tools/WorkflowKernelHotspotRuntime.ps1" "Invoke-WorkflowKernelHotspotShadow"
Require-Token "ARCH-025" "tools/validate-workflow-kernel-m3.ps1" "WORKFLOW_KERNEL_M3_RESULT=pass"
Require-Token "ARCH-026" "tools/WorkflowKernelSessionEntry.ps1" "Invoke-WorkflowSessionEntry"
Require-Token "ARCH-027" "tools/invoke-workflow-session-entry.ps1" "Invoke-WorkflowSessionEntry"
Require-Token "ARCH-028" "tools/validate-workflow-kernel-m4.ps1" "WORKFLOW_KERNEL_M4_RESULT=pass"

Add-ArchitectureCheck "ARCH-021" (
  ([string]$compatibilityCatalog.legacy_blueprint_freeze.cardinality_mode -eq "baseline_fixed_regression") -and
  ($compatibilityCatalog.legacy_blueprint_freeze.new_legacy_blueprints_allowed -eq $false)
) "M0 freeze cardinality and version are owned by the compatibility catalog and enforced by the parity checker"

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
