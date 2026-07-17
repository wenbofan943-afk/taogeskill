Set-StrictMode -Version 2.0

$kernelRuntimePath = Join-Path $PSScriptRoot 'WorkflowKernelRuntime.ps1'
if (-not (Test-Path -LiteralPath $kernelRuntimePath -PathType Leaf)) {
    throw 'workflow_kernel_runtime_missing'
}
. $kernelRuntimePath

$yamlHelperPath = Join-Path $PSScriptRoot 'YamlHelper.ps1'
if (-not (Test-Path -LiteralPath $yamlHelperPath -PathType Leaf)) {
    throw 'yaml_helper_missing'
}
. $yamlHelperPath

function New-WorkflowSessionEntryResult {
    param(
        [bool]$Success,
        [string]$Code,
        [string]$Message,
        [object]$Decision = $null
    )

    return [pscustomobject][ordered]@{
        success = $Success
        code = $Code
        message = $Message
        decision = $Decision
    }
}

function Test-WorkflowSessionEntryId {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return $false
    }
    return [string]$Value -match '^[A-Za-z0-9_-]+$'
}

function Assert-WorkflowSessionEntryObjectShape {
    param(
        [Parameter(Mandatory = $true)][object]$Value,
        [Parameter(Mandatory = $true)][string[]]$Required,
        [Parameter(Mandatory = $true)][string]$FailureCode
    )

    $actual = @($Value.PSObject.Properties.Name)
    foreach ($name in $Required) {
        if ($actual -notcontains $name) {
            throw $FailureCode
        }
    }
    $unknown = @($actual | Where-Object { $Required -notcontains $_ })
    if ($unknown.Count -gt 0) {
        throw $FailureCode
    }
}

function Resolve-WorkflowSessionEntryConfigPath {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$DefaultRelativePath,
        [string]$OverridePath,
        [bool]$FixtureMode
    )

    if ([string]::IsNullOrWhiteSpace($OverridePath)) {
        return [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $DefaultRelativePath))
    }
    if (-not $FixtureMode) {
        throw 'config_override_fixture_only'
    }
    $candidate = [System.IO.Path]::GetFullPath($OverridePath)
    $fixtureRoot = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot 'state/checks'))
    $contained = Resolve-TaogeContainedPath -AllowedRoot $fixtureRoot -CandidatePath $candidate -RejectReparsePoints
    if ([string]$contained.status -ne 'pass') {
        throw 'config_override_outside_fixture_root'
    }
    return $candidate
}

function Get-WorkflowSessionLegacyRoute {
    param([Parameter(Mandatory = $true)][string]$PlanPath)

    $plan = Read-WorkflowKernelJson -Path $PlanPath -FailureCode 'legacy_plan_invalid'
    $blueprint = [string](Get-WorkflowKernelProperty -Object $plan -Name 'blueprint_id' -FailureCode 'legacy_plan_invalid')
    if ($blueprint -like 'direct_delivery_single_*') {
        return 'direct'
    }
    if ($blueprint -like 'hotspot_to_delivery_single_*') {
        return 'hotspot'
    }
    throw 'legacy_plan_route_unknown'
}

function Read-WorkflowSessionCommittedBinding {
    param(
        [Parameter(Mandatory = $true)][string]$BindingPath,
        [Parameter(Mandatory = $true)][string]$MarkerPath
    )

    $bindingExists = Test-Path -LiteralPath $BindingPath -PathType Leaf
    $markerExists = Test-Path -LiteralPath $MarkerPath -PathType Leaf
    if ($bindingExists -xor $markerExists) {
        throw 'session_binding_commit_incomplete'
    }
    if (-not $bindingExists) {
        return $null
    }

    $expected = [System.IO.File]::ReadAllText($MarkerPath, [System.Text.Encoding]::UTF8).Trim().ToLowerInvariant()
    if ($expected -notmatch '^[a-f0-9]{64}$') {
        throw 'session_binding_marker_invalid'
    }
    $actual = Get-WorkflowKernelSha256 -Path $BindingPath
    if ($actual -ne $expected) {
        throw 'session_binding_digest_mismatch'
    }

    $binding = Read-WorkflowKernelJson -Path $BindingPath -FailureCode 'session_binding_invalid'
    $required = @(
        'schema_id',
        'schema_version',
        'architecture_change_id',
        'binding_id',
        'session_id',
        'route_id',
        'runtime_generation',
        'workflow_ir_id',
        'workflow_ir_sha256',
        'component_catalog_sha256',
        'compatibility_catalog_sha256',
        'architecture_control_sha256',
        'switch_policy_id',
        'selection_reason',
        'rollback_state_at_creation',
        'runtime_entry_ref',
        'created_at',
        'immutable',
        'migration_allowed'
    )
    Assert-WorkflowSessionEntryObjectShape -Value $binding -Required $required -FailureCode 'session_binding_invalid'
    if (
        [string]$binding.schema_id -ne 'taoge://workflow-kernel/session-runtime-binding/v0.1' -or
        [string]$binding.schema_version -ne '0.1' -or
        [string]$binding.architecture_change_id -ne 'ARCH-20260718-002' -or
        -not (Test-WorkflowSessionEntryId $binding.binding_id) -or
        -not (Test-WorkflowSessionEntryId $binding.session_id) -or
        [string]$binding.route_id -notin @('direct', 'hotspot') -or
        [string]$binding.runtime_generation -notin @('legacy_r7', 'kernel_v1_current') -or
        -not (Test-WorkflowKernelHash $binding.workflow_ir_sha256) -or
        -not (Test-WorkflowKernelHash $binding.component_catalog_sha256) -or
        -not (Test-WorkflowKernelHash $binding.compatibility_catalog_sha256) -or
        -not (Test-WorkflowKernelHash $binding.architecture_control_sha256) -or
        [string]$binding.switch_policy_id -ne 'taoge-session-generation-policy-v0.1' -or
        [string]$binding.selection_reason -notin @('active_new_session_default', 'rollback_future_new_session') -or
        [string]$binding.rollback_state_at_creation -notin @('inactive', 'engaged') -or
        -not (Test-WorkflowKernelTimestamp $binding.created_at) -or
        -not [bool]$binding.immutable -or
        [bool]$binding.migration_allowed
    ) {
        throw 'session_binding_invalid'
    }
    return $binding
}

function New-WorkflowSessionEntryDecision {
    param(
        [Parameter(Mandatory = $true)][string]$SessionId,
        [Parameter(Mandatory = $true)][string]$Intent,
        [Parameter(Mandatory = $true)][string]$RouteId,
        [Parameter(Mandatory = $true)][string]$RuntimeGeneration,
        [Parameter(Mandatory = $true)][string]$RuntimeEntryRef,
        [Parameter(Mandatory = $true)][string]$BindingStatus,
        [Parameter(Mandatory = $true)][string]$SelectionReason,
        [Parameter(Mandatory = $true)][string]$RequestedAt
    )

    return [pscustomobject][ordered]@{
        schema_id = 'taoge://workflow-kernel/session-entry-decision/v0.1'
        schema_version = '0.1'
        architecture_change_id = 'ARCH-20260718-002'
        session_id = $SessionId
        intent = $Intent
        route_id = $RouteId
        runtime_generation = $RuntimeGeneration
        runtime_entry_ref = $RuntimeEntryRef
        binding_status = $BindingStatus
        selection_reason = $SelectionReason
        requested_at = $RequestedAt
        runtime_certification = 'not_run'
    }
}

function Invoke-WorkflowSessionEntry {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$SessionRoot,
        [Parameter(Mandatory = $true)][ValidateSet('start', 'resume')][string]$Intent,
        [Parameter(Mandatory = $true)][string]$SessionId,
        [Parameter(Mandatory = $true)][ValidateSet('direct', 'hotspot')][string]$RouteId,
        [Parameter(Mandatory = $true)][string]$RequestedAt,
        [bool]$FixtureMode = $false,
        [string]$WorkflowIrPath = '',
        [string]$ArchitectureControlPath = ''
    )

    try {
        $root = [System.IO.Path]::GetFullPath($ProjectRoot)
        $session = [System.IO.Path]::GetFullPath($SessionRoot)
        if (-not (Test-WorkflowSessionEntryId $SessionId) -or (Split-Path -Leaf $session) -ne $SessionId) {
            throw 'session_identity_mismatch'
        }
        if (-not (Test-WorkflowKernelTimestamp $RequestedAt)) {
            throw 'requested_at_invalid'
        }
        if (-not (Test-Path -LiteralPath $session -PathType Container)) {
            throw 'session_root_missing'
        }

        $allowedRoot = if ($FixtureMode) {
            Join-Path $root 'state/checks'
        }
        else {
            Join-Path $root 'accounts'
        }
        $containment = Resolve-TaogeContainedPath -AllowedRoot $allowedRoot -CandidatePath $session -RejectReparsePoints
        if ([string]$containment.status -ne 'pass') {
            throw 'session_root_outside_allowed_root'
        }

        $workflowPath = Resolve-WorkflowSessionEntryConfigPath -ProjectRoot $root -DefaultRelativePath 'routes/current-workflow-ir.json' -OverridePath $WorkflowIrPath -FixtureMode $FixtureMode
        $architecturePath = Resolve-WorkflowSessionEntryConfigPath -ProjectRoot $root -DefaultRelativePath 'routes/architecture-control.yaml' -OverridePath $ArchitectureControlPath -FixtureMode $FixtureMode
        $componentPath = Join-Path $root 'routes/component-catalog.json'
        $compatibilityPath = Join-Path $root 'routes/compatibility-catalog.json'
        $workflow = Read-WorkflowKernelJson -Path $workflowPath -FailureCode 'workflow_ir_invalid'
        $architecture = Read-YamlFile $architecturePath
        $policy = Get-WorkflowKernelProperty -Object $workflow -Name 'session_generation_policy' -FailureCode 'session_generation_policy_missing'

        if (
            [string]$workflow.architecture_change_id -ne 'ARCH-20260718-002' -or
            [string]$workflow.runtime_generation -ne 'kernel_v1_current' -or
            -not [bool]$workflow.runtime_switch_enabled -or
            [string]$policy.policy_id -ne 'taoge-session-generation-policy-v0.1' -or
            [string]$policy.activation_status -ne 'active_new_sessions' -or
            [string]$policy.default_new_session_generation -ne 'kernel_v1_current' -or
            [string]$policy.rollback_new_session_generation -ne 'legacy_r7' -or
            [string]$policy.rollback_state -notin @('inactive', 'engaged') -or
            [string]$policy.existing_session_migration -ne 'forbidden' -or
            [string]$policy.rollback_scope -ne 'future_new_sessions_only' -or
            [string]$policy.runtime_certification -ne 'not_run' -or
            $RouteId -notin @($policy.eligible_routes)
        ) {
            throw 'session_generation_policy_invalid'
        }
        if (
            [string]$architecture.current_decision.architecture_change_id -ne 'ARCH-20260718-002' -or
            -not [bool]$architecture.current_decision.current_runtime_switch_authorized -or
            -not [bool]$architecture.current_decision.m4_new_session_switch_authorized -or
            [string]$architecture.current_decision.m2_status -ne 'completed' -or
            [string]$architecture.current_decision.m3_status -ne 'completed' -or
            [string]$architecture.migration.M4.status -ne 'completed'
        ) {
            throw 'session_switch_activation_gate_failed'
        }

        $bindingPath = Resolve-WorkflowKernelRelativePath -Root $session -RelativePath ([string]$policy.binding_relative_path) -FailureCode 'binding_path_invalid'
        $markerPath = Resolve-WorkflowKernelRelativePath -Root $session -RelativePath ([string]$policy.binding_commit_marker_relative_path) -FailureCode 'binding_marker_path_invalid'
        $planPath = Join-Path $session 'intermediate/p0/session-execution-plan.json'
        $binding = Read-WorkflowSessionCommittedBinding -BindingPath $bindingPath -MarkerPath $markerPath
        $legacyPlanExists = Test-Path -LiteralPath $planPath -PathType Leaf

        if ($Intent -eq 'resume') {
            if ($null -ne $binding) {
                if ([string]$binding.session_id -ne $SessionId -or [string]$binding.route_id -ne $RouteId) {
                    throw 'session_binding_identity_mismatch'
                }
                if ($legacyPlanExists -and [string]$binding.runtime_generation -ne 'legacy_r7') {
                    throw 'session_generation_conflict'
                }
                $decision = New-WorkflowSessionEntryDecision -SessionId $SessionId -Intent $Intent -RouteId $RouteId -RuntimeGeneration ([string]$binding.runtime_generation) -RuntimeEntryRef ([string]$binding.runtime_entry_ref) -BindingStatus 'reused' -SelectionReason 'committed_session_binding' -RequestedAt $RequestedAt
                return New-WorkflowSessionEntryResult -Success $true -Code 'session_resume_routed' -Message 'Existing session generation remains pinned.' -Decision $decision
            }
            if (-not $legacyPlanExists) {
                throw 'session_generation_unresolved'
            }
            $legacyRoute = Get-WorkflowSessionLegacyRoute -PlanPath $planPath
            if ($legacyRoute -ne $RouteId) {
                throw 'legacy_plan_route_mismatch'
            }
            $decision = New-WorkflowSessionEntryDecision -SessionId $SessionId -Intent $Intent -RouteId $RouteId -RuntimeGeneration 'legacy_r7' -RuntimeEntryRef ([string]$policy.legacy_runtime_entry_ref) -BindingStatus 'legacy_inferred_read_only' -SelectionReason 'version_pinned_legacy_plan' -RequestedAt $RequestedAt
            return New-WorkflowSessionEntryResult -Success $true -Code 'legacy_session_resume_routed' -Message 'Version-pinned legacy session remains on legacy R7 without mutation.' -Decision $decision
        }

        if ($legacyPlanExists -and $null -eq $binding) {
            throw 'existing_session_requires_resume'
        }
        if ($null -ne $binding) {
            if ([string]$binding.session_id -ne $SessionId -or [string]$binding.route_id -ne $RouteId) {
                throw 'session_binding_identity_mismatch'
            }
            $decision = New-WorkflowSessionEntryDecision -SessionId $SessionId -Intent $Intent -RouteId $RouteId -RuntimeGeneration ([string]$binding.runtime_generation) -RuntimeEntryRef ([string]$binding.runtime_entry_ref) -BindingStatus 'reused' -SelectionReason ([string]$binding.selection_reason) -RequestedAt $RequestedAt
            return New-WorkflowSessionEntryResult -Success $true -Code 'session_start_reused' -Message 'Committed session binding was reused.' -Decision $decision
        }

        $rollbackEngaged = [string]$policy.rollback_state -eq 'engaged'
        $generation = if ($rollbackEngaged) { [string]$policy.rollback_new_session_generation } else { [string]$policy.default_new_session_generation }
        $entryRef = if ($generation -eq 'legacy_r7') { [string]$policy.legacy_runtime_entry_ref } else { [string]$policy.current_runtime_entry_ref }
        $entryPath = Join-Path $root $entryRef
        if (-not (Test-Path -LiteralPath $entryPath -PathType Leaf)) {
            throw 'runtime_entry_missing'
        }
        $selectionReason = if ($rollbackEngaged) { 'rollback_future_new_session' } else { 'active_new_session_default' }
        $bindingDocument = [pscustomobject][ordered]@{
            schema_id = 'taoge://workflow-kernel/session-runtime-binding/v0.1'
            schema_version = '0.1'
            architecture_change_id = 'ARCH-20260718-002'
            binding_id = 'BIND-' + $SessionId
            session_id = $SessionId
            route_id = $RouteId
            runtime_generation = $generation
            workflow_ir_id = [string]$workflow.workflow_ir_id
            workflow_ir_sha256 = Get-WorkflowKernelSha256 -Path $workflowPath
            component_catalog_sha256 = Get-WorkflowKernelSha256 -Path $componentPath
            compatibility_catalog_sha256 = Get-WorkflowKernelSha256 -Path $compatibilityPath
            architecture_control_sha256 = Get-WorkflowKernelSha256 -Path $architecturePath
            switch_policy_id = [string]$policy.policy_id
            selection_reason = $selectionReason
            rollback_state_at_creation = [string]$policy.rollback_state
            runtime_entry_ref = $entryRef
            created_at = $RequestedAt
            immutable = $true
            migration_allowed = $false
        }
        Write-WorkflowKernelAtomicJson -Path $bindingPath -Value $bindingDocument -Depth 30
        $bindingSha256 = Get-WorkflowKernelSha256 -Path $bindingPath
        Write-WorkflowKernelAtomicText -Path $markerPath -Text ($bindingSha256 + [Environment]::NewLine)
        $committed = Read-WorkflowSessionCommittedBinding -BindingPath $bindingPath -MarkerPath $markerPath
        $decision = New-WorkflowSessionEntryDecision -SessionId $SessionId -Intent $Intent -RouteId $RouteId -RuntimeGeneration ([string]$committed.runtime_generation) -RuntimeEntryRef ([string]$committed.runtime_entry_ref) -BindingStatus 'created' -SelectionReason ([string]$committed.selection_reason) -RequestedAt $RequestedAt
        return New-WorkflowSessionEntryResult -Success $true -Code 'session_generation_bound' -Message 'New session generation was committed before workflow execution.' -Decision $decision
    }
    catch {
        return New-WorkflowSessionEntryResult -Success $false -Code ([string]$_.Exception.Message) -Message 'Session entry was blocked before workflow execution.'
    }
}
