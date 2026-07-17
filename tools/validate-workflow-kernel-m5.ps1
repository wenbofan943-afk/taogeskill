[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [string]$WorkRoot = '',
    [string]$MachineReportPath = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}
else {
    $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}

. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'WorkflowKernelSessionEntry.ps1')

function Read-M5Json {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ([System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Add-M5Result {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Results,
        [Parameter(Mandatory = $true)][string]$FixtureId,
        [Parameter(Mandatory = $true)][bool]$Passed,
        [Parameter(Mandatory = $true)][string]$Detail
    )
    $Results.Add([pscustomobject][ordered]@{
        fixture_id = $FixtureId
        expected_result = 'pass'
        actual_result = if ($Passed) { 'pass' } else { 'fail' }
        fixture_result = if ($Passed) { 'pass' } else { 'fail' }
        detail = $Detail
    })
}

function Get-M5FailureCode {
    param([Parameter(Mandatory = $true)][scriptblock]$Action)
    try {
        & $Action | Out-Null
        return 'no_error'
    }
    catch {
        return [string]$_.Exception.Message
    }
}

function Write-M5LegacyPlan {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$SessionId,
        [Parameter(Mandatory = $true)][string]$BlueprintId,
        [Parameter(Mandatory = $true)][string]$BlueprintVersion
    )
    Write-TaogeUtf8NoBomJson -Path $Path -Value ([pscustomobject][ordered]@{
        plan_id = 'PLAN-' + $SessionId
        session_id = $SessionId
        blueprint_id = $BlueprintId
        blueprint_version = $BlueprintVersion
    }) -Depth 10
}

try {
    $root = [System.IO.Path]::GetFullPath($ProjectRoot)
    if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
        $WorkRoot = Join-Path $root 'state/checks/workflow-kernel-m5'
    }
    if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
        $MachineReportPath = Join-Path $root 'state/checks/workflow-kernel-m5-fixture-report.json'
    }
    $work = [System.IO.Path]::GetFullPath($WorkRoot)
    $checksRoot = [System.IO.Path]::GetFullPath((Join-Path $root 'state/checks'))
    if (-not (Test-WorkflowKernelPathContained -Root $checksRoot -Candidate $work)) {
        throw 'work_root_outside_state_checks'
    }
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
    New-Item -ItemType Directory -Path $work -Force | Out-Null

    $catalog = Read-M5Json (Join-Path $root 'examples/workflow-kernel-m5-compatibility-fixtures/fixtures.json')
    $results = [System.Collections.Generic.List[object]]::new()
    $irPath = Join-Path $root 'routes/current-workflow-ir.json'
    $componentPath = Join-Path $root 'routes/component-catalog.json'
    $compatibilityPath = Join-Path $root 'routes/compatibility-catalog.json'
    $ir = Read-M5Json $irPath
    $components = Read-M5Json $componentPath
    $compatibility = Read-M5Json $compatibilityPath
    $irText = [System.IO.File]::ReadAllText($irPath, [System.Text.Encoding]::UTF8)
    $componentText = [System.IO.File]::ReadAllText($componentPath, [System.Text.Encoding]::UTF8)

    $irIsolated = (
        [string]$ir.status -eq 'm5_compatibility_isolated' -and
        -not $irText.Contains('"legacy_blueprint_ref"') -and
        -not $irText.Contains('"legacy_node_refs"') -and
        [string]$ir.session_generation_policy.legacy_asset_load_authority -eq 'compatibility_loader_only'
    )
    Add-M5Result $results 'M5-F01' $irIsolated 'Current IR contains only stage/component bindings.'

    $componentIsolated = (
        [string]$components.status -eq 'm5_current_hot_path_isolated' -and
        -not $componentText.Contains('"legacy_step_kind"') -and
        $null -eq $components.PSObject.Properties['source_registry_ref'] -and
        @($components.components).Count -eq 35
    )
    Add-M5Result $results 'M5-F02' $componentIsolated 'Current component catalog contains 35 current-only records.'

    $sourceBundleCallerCode = Get-M5FailureCode {
        Get-WorkflowCompatibilitySourceBundle -ProjectRoot $root -CallerRuntimeGeneration 'kernel_v1_current'
    }
    $catalogIsolated = (
        [string]$compatibility.status -eq 'm5_compatibility_isolated' -and
        -not [bool]$compatibility.current_kernel_load_allowed -and
        [string]$compatibility.loader_ref -eq 'tools/WorkflowCompatibilityLoader.ps1' -and
        @($compatibility.historical_blueprints).Count -eq 12 -and
        @($compatibility.compatibility_assets | Where-Object { [string]$_.load_authority -ne 'tools/WorkflowCompatibilityLoader.ps1' }).Count -eq 0 -and
        [string]$compatibility.directory_isolation.cardinality_mode -eq 'baseline_fixed_regression' -and
        [string]$compatibility.directory_isolation.status -eq 'm5_1_directory_archive_completed' -and
        [string]$compatibility.directory_isolation.compatibility_root -eq 'compatibility/legacy-r7' -and
        [int]$compatibility.directory_isolation.archived_data_asset_count -eq 15 -and
        [int]$compatibility.directory_isolation.archived_implementation_count -eq 2 -and
        [int]$compatibility.directory_isolation.stable_shim_count -eq 2 -and
        $sourceBundleCallerCode -eq 'current_runtime_compatibility_load_forbidden'
    )
    Add-M5Result $results 'M5-F03' $catalogIsolated 'Compatibility catalog is loader-only and current source-bundle callers fail closed.'

    $isolated = Join-Path $work 'isolated-project'
    foreach ($relative in @('routes', 'tools', 'state/checks')) {
        New-Item -ItemType Directory -Path (Join-Path $isolated $relative) -Force | Out-Null
    }
    Copy-Item -LiteralPath $irPath -Destination (Join-Path $isolated 'routes/current-workflow-ir.json')
    Copy-Item -LiteralPath $componentPath -Destination (Join-Path $isolated 'routes/component-catalog.json')
    Copy-Item -LiteralPath (Join-Path $root 'routes/architecture-control.yaml') -Destination (Join-Path $isolated 'routes/architecture-control.yaml')
    Write-TaogeUtf8NoBomText -Path (Join-Path $isolated 'tools/invoke-workflow-session-entry.ps1') -Text "# fixture entry`n"
    Write-TaogeUtf8NoBomText -Path (Join-Path $isolated 'tools/invoke-r7-semantic-workflow.ps1') -Text "# fixture legacy entry`n"

    $currentSessionId = 'M5CURRENT001'
    $currentSession = Join-Path $isolated ('state/checks/' + $currentSessionId)
    New-Item -ItemType Directory -Path $currentSession -Force | Out-Null
    $currentStart = Invoke-WorkflowSessionEntry -ProjectRoot $isolated -SessionRoot $currentSession -Intent start -SessionId $currentSessionId -RouteId direct -RequestedAt '2026-07-18T14:00:00+08:00' -FixtureMode $true
    Add-M5Result $results 'M5-F04' ([bool]$currentStart.success -and [string]$currentStart.code -eq 'session_generation_bound' -and -not (Test-Path -LiteralPath (Join-Path $isolated 'routes/compatibility-catalog.json'))) ([string]$currentStart.code)

    $currentBindingPath = Join-Path $currentSession 'intermediate/workflow-kernel/session-runtime-binding.json'
    $currentBinding = Read-M5Json $currentBindingPath
    $currentBindingPass = (
        [string]$currentBinding.schema_version -eq '0.2' -and
        [string]$currentBinding.runtime_generation -eq 'kernel_v1_current' -and
        $null -eq $currentBinding.PSObject.Properties['compatibility_catalog_sha256']
    )
    Add-M5Result $results 'M5-F05' $currentBindingPass 'Current v0.2 binding omits compatibility digest.'

    $directPlan = Join-Path $work 'legacy-direct-plan.json'
    $hotspotPlan = Join-Path $work 'legacy-hotspot-plan.json'
    Write-M5LegacyPlan $directPlan 'M5LEGACYD' 'direct_delivery_single_v0.6' '0.6'
    Write-M5LegacyPlan $hotspotPlan 'M5LEGACYH' 'hotspot_to_delivery_single_v0.2' '0.2'
    $directResolution = Resolve-WorkflowCompatibilityPlan -ProjectRoot $root -PlanPath $directPlan -ExpectedRouteId direct -CallerRuntimeGeneration legacy_r7
    $hotspotResolution = Resolve-WorkflowCompatibilityPlan -ProjectRoot $root -PlanPath $hotspotPlan -ExpectedRouteId hotspot -CallerRuntimeGeneration legacy_r7
    Add-M5Result $results 'M5-F06' ([string]$directResolution.resolution_status -eq 'legacy_resume_only' -and [bool]$directResolution.read_only -and -not [bool]$directResolution.migration_allowed) ([string]$directResolution.blueprint_id)
    Add-M5Result $results 'M5-F07' ([string]$hotspotResolution.route_id -eq 'hotspot' -and [string]$hotspotResolution.runtime_generation -eq 'legacy_r7') ([string]$hotspotResolution.blueprint_id)

    $currentCallerCode = Get-M5FailureCode { Resolve-WorkflowCompatibilityPlan -ProjectRoot $root -PlanPath $directPlan -ExpectedRouteId direct -CallerRuntimeGeneration kernel_v1_current }
    Add-M5Result $results 'M5-F08' ($currentCallerCode -eq 'current_runtime_compatibility_load_forbidden') $currentCallerCode

    $unknownPlan = Join-Path $work 'legacy-unknown-plan.json'
    Write-M5LegacyPlan $unknownPlan 'M5UNKNOWN' 'direct_delivery_single_v0.7' '0.7'
    $unknownCode = Get-M5FailureCode { Resolve-WorkflowCompatibilityPlan -ProjectRoot $root -PlanPath $unknownPlan -ExpectedRouteId direct -CallerRuntimeGeneration legacy_r7 }
    Add-M5Result $results 'M5-F09' ($unknownCode -eq 'legacy_plan_not_cataloged') $unknownCode

    $routeCode = Get-M5FailureCode { Resolve-WorkflowCompatibilityPlan -ProjectRoot $root -PlanPath $directPlan -ExpectedRouteId hotspot -CallerRuntimeGeneration legacy_r7 }
    Add-M5Result $results 'M5-F10' ($routeCode -eq 'legacy_plan_route_mismatch') $routeCode

    $assetCode = Get-M5FailureCode { Resolve-WorkflowCompatibilityAsset -ProjectRoot $root -AssetReference 'routes/not-cataloged.yaml' -CallerRuntimeGeneration legacy_r7 }
    Add-M5Result $results 'M5-F11' ($assetCode -eq 'compatibility_asset_not_cataloged') $assetCode
    $assetCallerCode = Get-M5FailureCode { Resolve-WorkflowCompatibilityAsset -ProjectRoot $root -AssetReference 'compatibility/legacy-r7/routes/r7-workflow-blueprints.yaml' -CallerRuntimeGeneration kernel_v1_current }
    Add-M5Result $results 'M5-F12' ($assetCallerCode -eq 'current_runtime_compatibility_load_forbidden') $assetCallerCode

    $v01SessionId = 'M5BINDINGV01'
    $v01Session = Join-Path $isolated ('state/checks/' + $v01SessionId)
    $v01BindingPath = Join-Path $v01Session 'intermediate/workflow-kernel/session-runtime-binding.json'
    $v01MarkerPath = Join-Path $v01Session 'intermediate/workflow-kernel/session-runtime-binding.sha256'
    New-Item -ItemType Directory -Path (Split-Path -Parent $v01BindingPath) -Force | Out-Null
    $hash = ('a' * 64)
    $v01 = [pscustomobject][ordered]@{
        schema_id = 'taoge://workflow-kernel/session-runtime-binding/v0.1'
        schema_version = '0.1'
        architecture_change_id = 'ARCH-20260718-002'
        binding_id = 'BIND-' + $v01SessionId
        session_id = $v01SessionId
        route_id = 'direct'
        runtime_generation = 'kernel_v1_current'
        workflow_ir_id = 'taoge-current-workflow-ir-v0.1'
        workflow_ir_sha256 = $hash
        component_catalog_sha256 = $hash
        compatibility_catalog_sha256 = $hash
        architecture_control_sha256 = $hash
        switch_policy_id = 'taoge-session-generation-policy-v0.1'
        selection_reason = 'active_new_session_default'
        rollback_state_at_creation = 'inactive'
        runtime_entry_ref = 'tools/invoke-workflow-session-entry.ps1'
        created_at = '2026-07-18T12:00:00+08:00'
        immutable = $true
        migration_allowed = $false
    }
    Write-TaogeUtf8NoBomJson -Path $v01BindingPath -Value $v01 -Depth 20
    Write-TaogeUtf8NoBomText -Path $v01MarkerPath -Text ((Get-TaogeFileSha256 $v01BindingPath) + [Environment]::NewLine)
    $v01Resume = Invoke-WorkflowSessionEntry -ProjectRoot $isolated -SessionRoot $v01Session -Intent resume -SessionId $v01SessionId -RouteId direct -RequestedAt '2026-07-18T14:05:00+08:00' -FixtureMode $true
    Add-M5Result $results 'M5-F13' ([bool]$v01Resume.success -and [string]$v01Resume.code -eq 'session_resume_routed' -and [string]$v01Resume.decision.runtime_generation -eq 'kernel_v1_current') ([string]$v01Resume.code)

    $badBinding = Read-M5Json $currentBindingPath
    $badBinding | Add-Member -NotePropertyName compatibility_catalog_sha256 -NotePropertyValue $hash
    Write-TaogeUtf8NoBomJson -Path $currentBindingPath -Value $badBinding -Depth 20
    Write-TaogeUtf8NoBomText -Path (Join-Path $currentSession 'intermediate/workflow-kernel/session-runtime-binding.sha256') -Text ((Get-TaogeFileSha256 $currentBindingPath) + [Environment]::NewLine)
    $badResume = Invoke-WorkflowSessionEntry -ProjectRoot $isolated -SessionRoot $currentSession -Intent resume -SessionId $currentSessionId -RouteId direct -RequestedAt '2026-07-18T14:10:00+08:00' -FixtureMode $true
    $badBinding.PSObject.Properties.Remove('compatibility_catalog_sha256')
    $badBinding.runtime_entry_ref = 'tools/invoke-r7-semantic-workflow.ps1'
    Write-TaogeUtf8NoBomJson -Path $currentBindingPath -Value $badBinding -Depth 20
    Write-TaogeUtf8NoBomText -Path (Join-Path $currentSession 'intermediate/workflow-kernel/session-runtime-binding.sha256') -Text ((Get-TaogeFileSha256 $currentBindingPath) + [Environment]::NewLine)
    $badEntryResume = Invoke-WorkflowSessionEntry -ProjectRoot $isolated -SessionRoot $currentSession -Intent resume -SessionId $currentSessionId -RouteId direct -RequestedAt '2026-07-18T14:11:00+08:00' -FixtureMode $true
    $badBindingPass = (
        -not [bool]$badResume.success -and
        [string]$badResume.code -eq 'session_binding_invalid' -and
        -not [bool]$badEntryResume.success -and
        [string]$badEntryResume.code -eq 'session_binding_invalid'
    )
    Add-M5Result $results 'M5-F14' $badBindingPass ("digest=" + [string]$badResume.code + ";entry=" + [string]$badEntryResume.code)

    $planBefore = Get-TaogeFileSha256 $directPlan
    $catalogBefore = Get-TaogeFileSha256 $compatibilityPath
    $repeatResolution = Resolve-WorkflowCompatibilityPlan -ProjectRoot $root -PlanPath $directPlan -ExpectedRouteId direct -CallerRuntimeGeneration legacy_r7
    $stable = (
        $planBefore -eq (Get-TaogeFileSha256 $directPlan) -and
        $catalogBefore -eq (Get-TaogeFileSha256 $compatibilityPath) -and
        (ConvertTo-Json $directResolution -Compress) -eq (ConvertTo-Json $repeatResolution -Compress)
    )
    Add-M5Result $results 'M5-F15' $stable 'Compatibility resolution is byte-stable and writes no source.'

    $oldSourcePaths = @(
        'routes/r7-workflow-blueprints.yaml',
        'routes/r7-node-registry.yaml',
        'routes/r7-input-selector-registry.yaml',
        'routes/r7-artifact-commit-registry.yaml',
        'routes/r7-status-route-registry.yaml',
        'routes/r7-action-registry.v0.1.yaml',
        'routes/r7-action-registry.v0.2.yaml',
        'routes/r7-task-guidance-registry.yaml',
        'routes/r7-producer-adapter-registry.yaml',
        'routes/r7-delivery-presentation-registry.v0.1.yaml',
        'templates/schema/p0/session-execution-plan.v0.2.schema.json',
        'templates/final-delivery/final-delivery.v0.6.execution-fragment.html',
        'templates/final-delivery/final-delivery.v0.7.hotspot-fragment.html',
        'templates/final-delivery/final-delivery.v0.8.fragment.html'
    )
    $allAssetsRelocated = (
        @($compatibility.compatibility_assets).Count -eq 17 -and
        @($compatibility.compatibility_assets | Where-Object {
            [string]$_.archive_status -ne 'relocated_compatibility_consumer' -or
            -not ([string]$_.asset_ref).StartsWith('compatibility/legacy-r7/')
        }).Count -eq 0
    )
    $oldSourcesRemoved = @($oldSourcePaths | Where-Object {
        Test-Path -LiteralPath (Join-Path $root $_)
    }).Count -eq 0
    $shimAndImplementationPass = (
        (Test-Path -LiteralPath (Join-Path $root 'tools/R7SemanticRuntime.ps1') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $root 'tools/invoke-r7-semantic-workflow.ps1') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $root 'compatibility/legacy-r7/tools/R7SemanticRuntime.impl.ps1') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $root 'compatibility/legacy-r7/tools/invoke-r7-semantic-workflow.impl.ps1') -PathType Leaf)
    )
    $runtimeShimText = [System.IO.File]::ReadAllText((Join-Path $root 'tools/R7SemanticRuntime.ps1'))
    $cliShimText = [System.IO.File]::ReadAllText((Join-Path $root 'tools/invoke-r7-semantic-workflow.ps1'))
    $shimBoundaryPass = (
        $runtimeShimText.Contains('Resolve-WorkflowCompatibilityAsset') -and
        $runtimeShimText.Contains('compatibility/legacy-r7/tools/R7SemanticRuntime.impl.ps1') -and
        -not $runtimeShimText.Contains('function Initialize-R7RuntimeSession') -and
        $cliShimText.Contains('Resolve-WorkflowCompatibilityAsset') -and
        $cliShimText.Contains('compatibility/legacy-r7/tools/invoke-r7-semantic-workflow.impl.ps1')
    )
    $buildText = [System.IO.File]::ReadAllText((Join-Path $root 'tools/build-public-release.ps1'))
    $profileText = [System.IO.File]::ReadAllText((Join-Path $root 'routes/build-profiles.yaml'))
    $publicClosurePass = (
        $buildText.Contains('"compatibility"') -and
        $buildText.Contains('compatibility\legacy-r7\tools\R7SemanticRuntime.impl.ps1') -and
        $buildText.Contains('compatibility\legacy-r7\tools\invoke-r7-semantic-workflow.impl.ps1') -and
        $profileText.Contains('      - compatibility/')
    )
    $legacyActionSnapshotPath = Join-Path $root 'compatibility/legacy-r7/routes/r7-action-registry.v0.3.yaml'
    $actionSnapshotPass = (
        (Test-Path -LiteralPath $legacyActionSnapshotPath -PathType Leaf) -and
        (Get-TaogeFileSha256 $legacyActionSnapshotPath).ToLowerInvariant() -eq [string]$compatibility.directory_isolation.current_shared_action_snapshot_sha256
    )
    $directoryArchivePass = $allAssetsRelocated -and $oldSourcesRemoved -and $shimAndImplementationPass -and $shimBoundaryPass -and $actionSnapshotPass -and $publicClosurePass
    Add-M5Result $results 'M5-F16' $directoryArchivePass ("relocated=" + @($compatibility.compatibility_assets).Count + ";old_sources_removed=" + $oldSourcesRemoved + ";shim_boundary=" + $shimBoundaryPass + ";public_closure=" + $publicClosurePass)

    $expectedIds = @($catalog.cases | ForEach-Object { [string]$_.fixture_id })
    $actualIds = @($results | ForEach-Object { [string]$_.fixture_id })
    if ([string]::Join('|', $expectedIds) -ne [string]::Join('|', $actualIds)) {
        throw 'fixture_catalog_execution_order_mismatch'
    }
    $failed = @($results | Where-Object { [string]$_.fixture_result -ne 'pass' })
    $report = [pscustomobject][ordered]@{
        schema_id = 'taoge://checks/workflow-kernel-m5/v0.1'
        schema_version = '0.1'
        architecture_change_id = 'ARCH-20260718-002'
        result = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
        case_count = $results.Count
        passed_count = $results.Count - $failed.Count
        failed_count = $failed.Count
        current_component_count = @($components.components).Count
        historical_blueprint_count = @($compatibility.historical_blueprints).Count
        relocated_compatibility_asset_count = @($compatibility.compatibility_assets).Count
        archived_data_asset_count = [int]$compatibility.directory_isolation.archived_data_asset_count
        archived_implementation_count = [int]$compatibility.directory_isolation.archived_implementation_count
        stable_shim_count = [int]$compatibility.directory_isolation.stable_shim_count
        tracked_assets_directory_archived = @($compatibility.compatibility_assets).Count
        retired_or_deleted_asset_count = @($compatibility.compatibility_assets | Where-Object { [string]$_.archive_status -in @('retired', 'deleted') }).Count
        retirement_deferral_reason = 'active_legacy_resume_and_replay_consumers'
        windows_powershell_5_1_executed = $true
        network_called = $false
        provider_called = $false
        private_account_read = $false
        runtime_certification = 'not_run'
        cases = [object[]]$results.ToArray()
    }
    Write-TaogeUtf8NoBomJson -Path $MachineReportPath -Value $report -Depth 30
    foreach ($result in $results) {
        Write-Output ("$($result.fixture_id) $($result.fixture_result) $($result.detail)")
    }
    if ($failed.Count -gt 0) {
        Write-Output ("WORKFLOW_KERNEL_M5_RESULT=fail failed=$($failed.Count) total=$($results.Count)")
        exit 1
    }
    Write-Output ("WORKFLOW_KERNEL_M5_RESULT=pass total=$($results.Count)")
    exit 0
}
catch {
    Write-Error ('WORKFLOW_KERNEL_M5_TOOL_ERROR=' + $_.Exception.Message)
    exit 3
}
