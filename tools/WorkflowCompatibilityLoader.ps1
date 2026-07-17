Set-StrictMode -Version 2.0

$compatibilityKernelPath = Join-Path $PSScriptRoot 'WorkflowKernelRuntime.ps1'
if (-not (Get-Command Read-WorkflowKernelJson -ErrorAction SilentlyContinue)) {
    if (-not (Test-Path -LiteralPath $compatibilityKernelPath -PathType Leaf)) {
        throw 'workflow_kernel_runtime_missing'
    }
    . $compatibilityKernelPath
}

$compatibilityYamlPath = Join-Path $PSScriptRoot 'YamlHelper.ps1'
if (-not (Get-Command Read-YamlFile -ErrorAction SilentlyContinue)) {
    if (-not (Test-Path -LiteralPath $compatibilityYamlPath -PathType Leaf)) {
        throw 'yaml_helper_missing'
    }
    . $compatibilityYamlPath
}

function Resolve-WorkflowCompatibilityContainedFile {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$Reference,
        [Parameter(Mandatory = $true)][string]$FailureCode
    )

    if ([System.IO.Path]::IsPathRooted($Reference)) {
        throw $FailureCode
    }
    $root = [System.IO.Path]::GetFullPath($ProjectRoot)
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $root $Reference))
    if (-not (Test-WorkflowKernelPathContained -Root $root -Candidate $candidate)) {
        throw $FailureCode
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw $FailureCode
    }
    return $candidate
}

function Read-WorkflowCompatibilityCatalog {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [string]$CatalogPath = ''
    )

    $root = [System.IO.Path]::GetFullPath($ProjectRoot)
    $path = if ([string]::IsNullOrWhiteSpace($CatalogPath)) {
        Join-Path $root 'routes/compatibility-catalog.json'
    }
    elseif ([System.IO.Path]::IsPathRooted($CatalogPath)) {
        [System.IO.Path]::GetFullPath($CatalogPath)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $root $CatalogPath))
    }
    if (-not (Test-WorkflowKernelPathContained -Root $root -Candidate $path)) {
        throw 'compatibility_catalog_path_invalid'
    }
    $catalog = Read-WorkflowKernelJson -Path $path -FailureCode 'compatibility_catalog_invalid'
    if (
        [string]$catalog.schema_id -ne 'taoge://workflow-kernel/compatibility-catalog/v0.2' -or
        [string]$catalog.schema_version -ne '0.2' -or
        [string]$catalog.architecture_change_id -ne 'ARCH-20260718-002' -or
        [string]$catalog.status -ne 'm5_compatibility_isolated' -or
        [bool]$catalog.current_kernel_load_allowed -or
        [string]$catalog.loader_ref -ne 'tools/WorkflowCompatibilityLoader.ps1' -or
        [string]$catalog.legacy_runtime_entry_ref -ne 'tools/invoke-r7-semantic-workflow.ps1' -or
        [string]$catalog.legacy_runtime_implementation_ref -ne 'compatibility/legacy-r7/tools/invoke-r7-semantic-workflow.impl.ps1' -or
        [string]$catalog.directory_isolation.cardinality_mode -ne 'baseline_fixed_regression' -or
        [string]$catalog.directory_isolation.status -ne 'm5_1_directory_archive_completed' -or
        [string]$catalog.directory_isolation.compatibility_root -ne 'compatibility/legacy-r7' -or
        [int]$catalog.directory_isolation.archived_data_asset_count -ne 15 -or
        [int]$catalog.directory_isolation.archived_implementation_count -ne 2 -or
        [int]$catalog.directory_isolation.stable_shim_count -ne 2 -or
        [string]$catalog.directory_isolation.current_shared_action_snapshot_sha256 -notmatch '^[0-9a-f]{64}$' -or
        -not [bool]$catalog.archive_policy.directory_relocation_allowed_with_active_consumers -or
        [bool]$catalog.archive_policy.deletion_authorized
    ) {
        throw 'compatibility_catalog_invalid'
    }
    return [pscustomobject][ordered]@{
        Path = $path
        Sha256 = Get-WorkflowKernelSha256 -Path $path
        Catalog = $catalog
    }
}

function Get-WorkflowCompatibilitySourceBundle {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$CallerRuntimeGeneration,
        [string]$CatalogPath = ''
    )

    if ($CallerRuntimeGeneration -notin @('legacy_r7', 'compile_time_compatibility')) {
        throw 'current_runtime_compatibility_load_forbidden'
    }
    $loaded = Read-WorkflowCompatibilityCatalog -ProjectRoot $ProjectRoot -CatalogPath $CatalogPath
    $catalog = $loaded.Catalog
    $blueprintPath = Resolve-WorkflowCompatibilityAsset -ProjectRoot $ProjectRoot -AssetReference ([string]$catalog.legacy_source_bundle.blueprint_registry_ref) -CallerRuntimeGeneration $CallerRuntimeGeneration -CatalogPath $CatalogPath
    $nodePath = Resolve-WorkflowCompatibilityAsset -ProjectRoot $ProjectRoot -AssetReference ([string]$catalog.legacy_source_bundle.node_registry_ref) -CallerRuntimeGeneration $CallerRuntimeGeneration -CatalogPath $CatalogPath
    return [pscustomobject][ordered]@{
        CatalogPath = $loaded.Path
        CatalogSha256 = $loaded.Sha256
        Catalog = $catalog
        BlueprintPath = $blueprintPath
        NodePath = $nodePath
        Blueprints = Read-YamlFile $blueprintPath
        Nodes = Read-YamlFile $nodePath
    }
}

function Resolve-WorkflowCompatibilityAsset {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$AssetReference,
        [Parameter(Mandatory = $true)][string]$CallerRuntimeGeneration,
        [string]$CatalogPath = ''
    )

    if ($CallerRuntimeGeneration -notin @('legacy_r7', 'compile_time_compatibility')) {
        throw 'current_runtime_compatibility_load_forbidden'
    }
    $loaded = Read-WorkflowCompatibilityCatalog -ProjectRoot $ProjectRoot -CatalogPath $CatalogPath
    $matches = @($loaded.Catalog.compatibility_assets | Where-Object {
        [string]$_.asset_ref -eq $AssetReference -and
        [string]$_.load_authority -eq 'tools/WorkflowCompatibilityLoader.ps1'
    })
    if ($matches.Count -ne 1) {
        throw 'compatibility_asset_not_cataloged'
    }
    return Resolve-WorkflowCompatibilityContainedFile -ProjectRoot $ProjectRoot -Reference $AssetReference -FailureCode 'compatibility_asset_invalid'
}

function Read-WorkflowCompatibilityYamlAsset {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$AssetReference,
        [Parameter(Mandatory = $true)][string]$CallerRuntimeGeneration,
        [string]$CatalogPath = ''
    )

    $path = Resolve-WorkflowCompatibilityAsset -ProjectRoot $ProjectRoot -AssetReference $AssetReference -CallerRuntimeGeneration $CallerRuntimeGeneration -CatalogPath $CatalogPath
    return Read-YamlFile $path
}

function Resolve-WorkflowCompatibilityPlan {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$PlanPath,
        [Parameter(Mandatory = $true)][ValidateSet('direct', 'hotspot')][string]$ExpectedRouteId,
        [Parameter(Mandatory = $true)][string]$CallerRuntimeGeneration,
        [string]$CatalogPath = ''
    )

    if ($CallerRuntimeGeneration -ne 'legacy_r7') {
        throw 'current_runtime_compatibility_load_forbidden'
    }
    $root = [System.IO.Path]::GetFullPath($ProjectRoot)
    $plan = if ([System.IO.Path]::IsPathRooted($PlanPath)) {
        [System.IO.Path]::GetFullPath($PlanPath)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $root $PlanPath))
    }
    if (-not (Test-WorkflowKernelPathContained -Root $root -Candidate $plan)) {
        throw 'legacy_plan_path_invalid'
    }
    $document = Read-WorkflowKernelJson -Path $plan -FailureCode 'legacy_plan_invalid'
    $blueprintId = [string](Get-WorkflowKernelProperty -Object $document -Name 'blueprint_id' -FailureCode 'legacy_plan_invalid')
    $blueprintVersion = [string](Get-WorkflowKernelProperty -Object $document -Name 'blueprint_version' -FailureCode 'legacy_plan_invalid')
    $loaded = Read-WorkflowCompatibilityCatalog -ProjectRoot $root -CatalogPath $CatalogPath
    $matches = @($loaded.Catalog.historical_blueprints | Where-Object {
        [string]$_.blueprint_id -eq $blueprintId -and
        [string]$_.blueprint_version -eq $blueprintVersion
    })
    if ($matches.Count -ne 1) {
        throw 'legacy_plan_not_cataloged'
    }
    $entry = $matches[0]
    if (
        [string]$entry.route_id -ne $ExpectedRouteId -or
        [string]$entry.compatibility_mode -ne 'legacy_r7_replay_only' -or
        [string]$entry.new_session_policy -ne 'forbidden' -or
        [string]$entry.archive_status -ne 'retained_compatibility_consumer'
    ) {
        throw 'legacy_plan_route_mismatch'
    }
    return [pscustomobject][ordered]@{
        schema_id = 'taoge://workflow-kernel/compatibility-resolution/v0.1'
        schema_version = '0.1'
        architecture_change_id = 'ARCH-20260718-002'
        blueprint_id = $blueprintId
        blueprint_version = $blueprintVersion
        route_id = [string]$entry.route_id
        runtime_generation = 'legacy_r7'
        runtime_entry_ref = [string]$loaded.Catalog.legacy_runtime_entry_ref
        plan_sha256 = Get-WorkflowKernelSha256 -Path $plan
        compatibility_catalog_sha256 = [string]$loaded.Sha256
        resolution_status = 'legacy_resume_only'
        read_only = $true
        migration_allowed = $false
    }
}
