[CmdletBinding()]
param(
  [string]$ProjectRoot = '',
  [string]$WorkflowIrPath = '',
  [string]$ComponentCatalogPath = '',
  [string]$CompatibilityCatalogPath = '',
  [string]$OutputRoot = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = Split-Path -Parent $PSScriptRoot
}

$root = [System.IO.Path]::GetFullPath($ProjectRoot)
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'YamlHelper.ps1')
. (Join-Path $PSScriptRoot 'WorkflowCompatibilityLoader.ps1')

function Resolve-WorkflowIrPath {
  param(
    [string]$Value,
    [string]$DefaultRelativePath,
    [switch]$Directory
  )

  $selected = if ([string]::IsNullOrWhiteSpace($Value)) { $DefaultRelativePath } else { $Value }
  $full = if ([System.IO.Path]::IsPathRooted($selected)) {
    [System.IO.Path]::GetFullPath($selected)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $root $selected))
  }

  if (-not $Directory -and -not (Test-Path -LiteralPath $full -PathType Leaf)) {
    throw "input_missing:$DefaultRelativePath"
  }
  return $full
}

function Read-WorkflowIrJson {
  param([string]$Path)
  return ([System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Test-WorkflowIrStringArray {
  param([object[]]$Actual, [object[]]$Expected)
  return ([string]::Join('|', @($Actual | ForEach-Object { [string]$_ })) -eq [string]::Join('|', @($Expected | ForEach-Object { [string]$_ })))
}

function Add-WorkflowIrError {
  param([System.Collections.Generic.List[string]]$Errors, [string]$Fingerprint, [string]$Detail)
  $Errors.Add($Fingerprint + ':' + $Detail)
}

function Add-WorkflowIrCheck {
  param([System.Collections.Generic.List[object]]$Checks, [string]$Id, [bool]$Passed, [string]$Detail)
  $Checks.Add([pscustomobject][ordered]@{
    check_id = $Id
    result = $(if ($Passed) { 'pass' } else { 'fail' })
    detail = $Detail
  })
}

function Get-WorkflowIrDictionary {
  param([object[]]$Items, [string]$KeyProperty, [System.Collections.Generic.List[string]]$Errors, [string]$DuplicateFingerprint)
  $dictionary = @{}
  foreach ($item in @($Items)) {
    $key = [string]$item.$KeyProperty
    if ([string]::IsNullOrWhiteSpace($key)) {
      Add-WorkflowIrError $Errors $DuplicateFingerprint 'empty_key'
      continue
    }
    if ($dictionary.ContainsKey($key)) {
      Add-WorkflowIrError $Errors $DuplicateFingerprint $key
      continue
    }
    $dictionary[$key] = $item
  }
  return $dictionary
}

try {
  $workflowPath = Resolve-WorkflowIrPath $WorkflowIrPath 'routes/current-workflow-ir.json'
  $componentPath = Resolve-WorkflowIrPath $ComponentCatalogPath 'routes/component-catalog.json'
  $compatibilityPath = Resolve-WorkflowIrPath $CompatibilityCatalogPath 'routes/compatibility-catalog.json'
  $outputPath = Resolve-WorkflowIrPath $OutputRoot 'state/checks/workflow-kernel-m1/current' -Directory

  $rootPrefix = $root.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  if (-not $outputPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'output_root_outside_project'
  }

  $outputFiles = @(
    'current-blueprint-view.json',
    'current-stage-view.json',
    'current-component-view.json',
    'current-compatibility-view.json',
    'workflow-ir-parity-report.json'
  )
  foreach ($name in $outputFiles) {
    $candidate = Join-Path $outputPath $name
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      Remove-Item -LiteralPath $candidate -Force
    }
  }

  $ir = Read-WorkflowIrJson $workflowPath
  $components = Read-WorkflowIrJson $componentPath
  $compatibilityBundle = Get-WorkflowCompatibilitySourceBundle -ProjectRoot $root -CallerRuntimeGeneration 'compile_time_compatibility' -CatalogPath $compatibilityPath
  $compatibility = $compatibilityBundle.Catalog
  $legacyBlueprints = $compatibilityBundle.Blueprints
  $legacyNodes = $compatibilityBundle.Nodes
  $blueprintPath = $compatibilityBundle.BlueprintPath
  $nodeRegistryPath = $compatibilityBundle.NodePath

  $errors = [System.Collections.Generic.List[string]]::new()
  $checks = [System.Collections.Generic.List[object]]::new()
  $expectedStages = @('intake', 'research_topic', 'script_design', 'visual_plan', 'asset_production', 'delivery_compile', 'final_decision')

  $sourceSchemaPass = (
    [string]$ir.schema_id -eq 'taoge://workflow-kernel/current-workflow-ir/v0.2' -and
    [string]$components.schema_id -eq 'taoge://workflow-kernel/component-catalog/v0.2' -and
    [string]$compatibility.schema_id -eq 'taoge://workflow-kernel/compatibility-catalog/v0.2' -and
    [string]$ir.architecture_change_id -eq 'ARCH-20260718-002' -and
    [string]$components.architecture_change_id -eq 'ARCH-20260718-002' -and
    [string]$compatibility.architecture_change_id -eq 'ARCH-20260718-002'
  )
  if (-not $sourceSchemaPass) {
    Add-WorkflowIrError $errors 'source_contract_invalid' 'schema_or_architecture_change_id'
  }
  Add-WorkflowIrCheck $checks 'M1-C01-source-contracts' $sourceSchemaPass 'three source contracts bind ARCH-20260718-002'

  $sessionPolicy = $ir.PSObject.Properties['session_generation_policy'].Value
  $runtimeSwitchPass = (
    [string]$ir.runtime_generation -eq 'kernel_v1_current' -and
    [bool]$ir.runtime_switch_enabled -and
    [string]$sessionPolicy.policy_id -eq 'taoge-session-generation-policy-v0.1' -and
    [string]$sessionPolicy.activation_status -eq 'active_new_sessions' -and
    [string]$sessionPolicy.default_new_session_generation -eq 'kernel_v1_current' -and
    [string]$sessionPolicy.rollback_new_session_generation -eq 'legacy_r7' -and
    [string]$sessionPolicy.rollback_state -in @('inactive', 'engaged') -and
    [string]$sessionPolicy.existing_session_migration -eq 'forbidden' -and
    [string]$sessionPolicy.rollback_scope -eq 'future_new_sessions_only' -and
    [string]$sessionPolicy.runtime_certification -eq 'not_run' -and
    [string]$sessionPolicy.binding_schema_ref -eq 'taoge://workflow-kernel/session-runtime-binding/v0.2' -and
    [string]$sessionPolicy.compatibility_loader_ref -eq 'tools/WorkflowCompatibilityLoader.ps1' -and
    [string]$sessionPolicy.current_binding_compatibility_digest -eq 'forbidden' -and
    [string]$sessionPolicy.legacy_asset_load_authority -eq 'compatibility_loader_only' -and
    -not [bool]$compatibility.current_kernel_load_allowed -and
    -not [bool]$compatibility.archive_policy.deletion_authorized
  )
  if (-not $runtimeSwitchPass) {
    Add-WorkflowIrError $errors 'runtime_switch_contract_invalid' 'M5_requires_isolated_current_binding_and_compatibility_loader'
  }
  Add-WorkflowIrCheck $checks 'M5-C02-session-generation-switch' $runtimeSwitchPass 'new current bindings exclude compatibility digests while legacy resolution is loader-only'

  $stageOrderPass = Test-WorkflowIrStringArray @($ir.stage_order) $expectedStages
  $stageDefinitions = @($ir.stage_definitions)
  if ($stageDefinitions.Count -ne 7) { $stageOrderPass = $false }
  for ($index = 0; $index -lt [Math]::Min($stageDefinitions.Count, 7); $index++) {
    if ([string]$stageDefinitions[$index].stage_id -ne $expectedStages[$index] -or [int]$stageDefinitions[$index].order -ne ($index + 1)) {
      $stageOrderPass = $false
    }
  }
  if (-not $stageOrderPass) {
    Add-WorkflowIrError $errors 'stage_order_invalid' 'expected_exactly_seven_ordered_stages'
  }
  Add-WorkflowIrCheck $checks 'M1-C03-seven-stage-topology' $stageOrderPass 'stage order and definitions are exact'

  $legacyBlueprintDictionary = @{}
  foreach ($legacyBlueprint in @($legacyBlueprints.blueprints)) {
    $key = [string]$legacyBlueprint.blueprint_id
    if ($legacyBlueprintDictionary.ContainsKey($key)) {
      Add-WorkflowIrError $errors 'legacy_blueprint_duplicate' $key
    } else {
      $legacyBlueprintDictionary[$key] = $legacyBlueprint
    }
  }

  $routeDictionary = Get-WorkflowIrDictionary @($ir.routes) 'route_id' $errors 'route_duplicate'
  $expectedRouteIds = @('direct', 'hotspot')
  $routeSetPass = (
    $routeDictionary.Count -eq 2 -and
    $routeDictionary.ContainsKey('direct') -and
    $routeDictionary.ContainsKey('hotspot')
  )
  if (-not $routeSetPass) {
    Add-WorkflowIrError $errors 'route_set_invalid' ([string]::Join(',', @($routeDictionary.Keys)))
  }
  Add-WorkflowIrCheck $checks 'M1-C04-route-set' $routeSetPass 'direct and hotspot are the only current routes'

  $currentComponentOrder = [System.Collections.Generic.List[string]]::new()
  $currentComponentSeen = @{}
  $routeViews = [System.Collections.Generic.List[object]]::new()
  foreach ($routeId in $expectedRouteIds) {
    if (-not $routeDictionary.ContainsKey($routeId)) { continue }
    $route = $routeDictionary[$routeId]
    $bindingStages = @($route.stage_bindings | ForEach-Object { [string]$_.stage_id })
    $bindingPass = Test-WorkflowIrStringArray $bindingStages $expectedStages
    $flattenedComponents = [System.Collections.Generic.List[string]]::new()
    $stageViews = [System.Collections.Generic.List[object]]::new()

    foreach ($binding in @($route.stage_bindings)) {
      $componentRefs = @($binding.component_refs | ForEach-Object { [string]$_ })
      $bindingProperties = @($binding.PSObject.Properties.Name)
      if (
        $bindingProperties.Count -ne 3 -or
        @('stage_id', 'mode', 'component_refs' | Where-Object { $bindingProperties -notcontains $_ }).Count -gt 0
      ) {
        $bindingPass = $false
        Add-WorkflowIrError $errors 'current_stage_binding_not_isolated' "$routeId/$($binding.stage_id)"
      }
      if ([string]$binding.mode -notin @('execute', 'skip')) {
        $bindingPass = $false
        Add-WorkflowIrError $errors 'stage_binding_mode_invalid' "$routeId/$($binding.stage_id)"
      }
      if ([string]$binding.mode -eq 'skip' -and $componentRefs.Count -ne 0) {
        $bindingPass = $false
        Add-WorkflowIrError $errors 'stage_skip_not_empty' "$routeId/$($binding.stage_id)"
      }
      foreach ($componentRef in $componentRefs) {
        $flattenedComponents.Add($componentRef)
        if (-not $currentComponentSeen.ContainsKey($componentRef)) {
          $currentComponentSeen[$componentRef] = $true
          $currentComponentOrder.Add($componentRef)
        }
      }
      $stageViews.Add([pscustomobject][ordered]@{
        stage_id = [string]$binding.stage_id
        mode = [string]$binding.mode
        component_refs = [object[]]$componentRefs
      })
    }

    if (-not $bindingPass) {
      Add-WorkflowIrError $errors 'stage_binding_order_invalid' $routeId
    }

    $routeProperties = @($route.PSObject.Properties.Name)
    $routeShapePass = (
      $routeProperties.Count -eq 5 -and
      @('route_id', 'route_version', 'entry_stage_id', 'terminal_stage_id', 'stage_bindings' | Where-Object { $routeProperties -notcontains $_ }).Count -eq 0
    )
    if (-not $routeShapePass) {
      Add-WorkflowIrError $errors 'current_route_not_isolated' $routeId
    }
    $baseline = @($compatibility.current_parity_baselines | Where-Object { [string]$_.route_id -eq $routeId })
    $blueprintId = if ($baseline.Count -eq 1) { [string]$baseline[0].blueprint_id } else { '' }
    $blueprintVersion = if ($baseline.Count -eq 1) { [string]$baseline[0].blueprint_version } else { '' }
    $legacyParityPass = $routeShapePass -and $baseline.Count -eq 1 -and $legacyBlueprintDictionary.ContainsKey($blueprintId)
    if ($legacyParityPass) {
      $legacyBlueprint = $legacyBlueprintDictionary[$blueprintId]
      $legacyParityPass = (
        [string]$legacyBlueprint.blueprint_version -eq $blueprintVersion -and
        [string]$baseline[0].comparison_mode -eq 'compile_time_compatibility_only' -and
        (Test-WorkflowIrStringArray @($legacyBlueprint.node_refs) @($flattenedComponents.ToArray()))
      )
    }
    if (-not $legacyParityPass) {
      Add-WorkflowIrError $errors 'compatibility_baseline_parity' "$routeId/$blueprintId"
    }
    Add-WorkflowIrCheck $checks ("M5-C05-route-parity-" + $routeId) $legacyParityPass ("compatibility baseline component count=" + $flattenedComponents.Count)

    $routeViews.Add([pscustomobject][ordered]@{
      route_id = $routeId
      route_version = [string]$route.route_version
      stage_count = @($route.stage_bindings).Count
      component_count = $flattenedComponents.Count
      stage_bindings = [object[]]$stageViews.ToArray()
    })
  }

  $componentDictionary = Get-WorkflowIrDictionary @($components.components) 'component_id' $errors 'component_duplicate'
  $legacyNodeDictionary = @{}
  foreach ($legacyNode in @($legacyNodes.nodes)) {
    $legacyNodeId = [string]$legacyNode.node_id
    if (-not $legacyNodeDictionary.ContainsKey($legacyNodeId)) {
      $legacyNodeDictionary[$legacyNodeId] = $legacyNode
    }
  }
  $expectedComponentIds = @($currentComponentOrder.ToArray())
  $actualComponentIds = @($components.components | ForEach-Object { [string]$_.component_id })
  $componentCoveragePass = (
    $actualComponentIds.Count -eq $expectedComponentIds.Count -and
    @($expectedComponentIds | Where-Object { -not $componentDictionary.ContainsKey($_) }).Count -eq 0 -and
    @($actualComponentIds | Where-Object { $currentComponentSeen.ContainsKey($_) -eq $false }).Count -eq 0
  )
  if (-not $componentCoveragePass) {
    Add-WorkflowIrError $errors 'component_coverage_missing' ("expected=" + $expectedComponentIds.Count + ";actual=" + $actualComponentIds.Count)
  }

  $kindMap = @{
    semantic_skill = 'semantic_worker'
    deterministic_tool = 'deterministic_operation'
    external_side_effect = 'external_activity'
    human_gate = 'human_gate'
  }
  $componentParityErrors = [System.Collections.Generic.List[string]]::new()
  $allowedComponentProperties = @(
    'component_id',
    'component_kind',
    'skill_ref',
    'implementation_ref',
    'input_selector_refs',
    'allowed_result_statuses',
    'output_artifact_type',
    'output_contract_ref',
    'required_contract_versions',
    'retry_policy'
  )
  foreach ($componentId in $expectedComponentIds) {
    if (-not $componentDictionary.ContainsKey($componentId)) { continue }
    $component = $componentDictionary[$componentId]
    if (-not $legacyNodeDictionary.ContainsKey($componentId)) {
      $componentParityErrors.Add("node_missing:$componentId")
      continue
    }
    $legacyNode = $legacyNodeDictionary[$componentId]
    $implementationPath = Join-Path $root ([string]$component.implementation_ref)
    $componentProperties = @($component.PSObject.Properties.Name)
    $parityPass = (
      $componentProperties.Count -eq $allowedComponentProperties.Count -and
      @($allowedComponentProperties | Where-Object { $componentProperties -notcontains $_ }).Count -eq 0 -and
      [string]$component.component_kind -eq [string]$kindMap[[string]$legacyNode.step_kind] -and
      [string]$component.skill_ref -eq [string]$legacyNode.skill_ref -and
      (Test-WorkflowIrStringArray @($component.input_selector_refs) @($legacyNode.input_selectors)) -and
      (Test-WorkflowIrStringArray @($component.allowed_result_statuses) @($legacyNode.allowed_result_statuses)) -and
      [string]$component.output_artifact_type -eq [string]$legacyNode.output_artifact_type -and
      [string]$component.output_contract_ref -eq [string]$legacyNode.output_schema_ref -and
      (Test-WorkflowIrStringArray @($component.required_contract_versions) @($legacyNode.required_contract_versions)) -and
      [string]$component.retry_policy.mode -eq [string]$legacyNode.retry_policy.mode -and
      [int]$component.retry_policy.max_attempts -eq [int]$legacyNode.retry_policy.max_attempts -and
      [bool]$component.retry_policy.reconcile_first -eq [bool]$legacyNode.retry_policy.reconcile_first -and
      (Test-Path -LiteralPath $implementationPath -PathType Leaf)
    )
    if (-not $parityPass) { $componentParityErrors.Add($componentId) }
  }
  if ($componentParityErrors.Count -gt 0) {
    foreach ($item in $componentParityErrors) {
      Add-WorkflowIrError $errors 'component_registry_parity' $item
    }
  }
  Add-WorkflowIrCheck $checks 'M1-C06-component-coverage' $componentCoveragePass ("current unique components=" + $expectedComponentIds.Count)
  Add-WorkflowIrCheck $checks 'M1-C07-component-registry-parity' ($componentParityErrors.Count -eq 0) ("mismatches=" + $componentParityErrors.Count)

  $compatibilityKeys = @{}
  foreach ($entry in @($compatibility.historical_blueprints)) {
    $key = [string]$entry.blueprint_id + '@' + [string]$entry.blueprint_version
    if ($compatibilityKeys.ContainsKey($key)) {
      Add-WorkflowIrError $errors 'compatibility_blueprint_duplicate' $key
    } else {
      $compatibilityKeys[$key] = $entry
    }
  }

  $expectedHistoricalKeys = [System.Collections.Generic.List[string]]::new()
  $compatibilityParityErrors = [System.Collections.Generic.List[string]]::new()
  foreach ($legacyBlueprint in @($legacyBlueprints.blueprints)) {
    $key = [string]$legacyBlueprint.blueprint_id + '@' + [string]$legacyBlueprint.blueprint_version
    $expectedHistoricalKeys.Add($key)
    if (-not $compatibilityKeys.ContainsKey($key)) {
      $compatibilityParityErrors.Add("missing:$key")
      continue
    }
    $entry = $compatibilityKeys[$key]
    if (
      [string]$entry.legacy_activation_status -ne [string]$legacyBlueprint.activation_status -or
      [string]$entry.compatibility_mode -ne 'legacy_r7_replay_only' -or
      [string]$entry.new_session_policy -ne 'forbidden' -or
      [string]$entry.archive_status -ne 'retained_compatibility_consumer'
    ) {
      $compatibilityParityErrors.Add("mismatch:$key")
    }
  }
  foreach ($key in @($compatibilityKeys.Keys)) {
    if (-not $expectedHistoricalKeys.Contains($key)) {
      $compatibilityParityErrors.Add("unknown:$key")
    }
  }
  $legacyFreezePass = (
    [string]$compatibility.legacy_blueprint_freeze.cardinality_mode -eq 'baseline_fixed_regression' -and
    -not [bool]$compatibility.legacy_blueprint_freeze.new_legacy_blueprints_allowed -and
    @($legacyBlueprints.blueprints).Count -eq [int]$compatibility.legacy_blueprint_freeze.frozen_blueprint_count -and
    @($legacyBlueprints.blueprints | Where-Object {
      [version]([string]$_.blueprint_version) -gt [version]([string]$compatibility.legacy_blueprint_freeze.maximum_blueprint_version)
    }).Count -eq 0
  )
  if (-not $legacyFreezePass) {
    Add-WorkflowIrError $errors 'legacy_blueprint_freeze_violation' 'M0_forbids_new_blueprint_versions_or_cardinality'
  }
  if ($compatibilityParityErrors.Count -gt 0) {
    foreach ($item in $compatibilityParityErrors) {
      Add-WorkflowIrError $errors 'compatibility_blueprint_parity' $item
    }
  }
  Add-WorkflowIrCheck $checks 'M1-C08-compatibility-coverage' ($compatibilityParityErrors.Count -eq 0) ("historical blueprints=" + $expectedHistoricalKeys.Count)
  Add-WorkflowIrCheck $checks 'M1-C08A-legacy-blueprint-freeze' $legacyFreezePass 'baseline cardinality and maximum version come from compatibility catalog'

  $assetErrors = [System.Collections.Generic.List[string]]::new()
  foreach ($asset in @($compatibility.compatibility_assets)) {
    $assetPath = Join-Path $root ([string]$asset.asset_ref)
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
      $assetErrors.Add("asset_missing:$($asset.asset_ref)")
      continue
    }
    if ([string]$asset.archive_status -ne 'relocated_compatibility_consumer') {
      $assetErrors.Add("archive_status_invalid:$($asset.asset_ref)")
    }
    if ([string]$asset.load_authority -ne 'tools/WorkflowCompatibilityLoader.ps1') {
      $assetErrors.Add("load_authority_invalid:$($asset.asset_ref)")
    }
  }
  if ($assetErrors.Count -gt 0) {
    foreach ($item in $assetErrors) {
      Add-WorkflowIrError $errors 'compatibility_asset_consumer_invalid' $item
    }
  }
  Add-WorkflowIrCheck $checks 'M1-C09-compatibility-asset-consumers' ($assetErrors.Count -eq 0) ("cataloged assets=" + @($compatibility.compatibility_assets).Count)

  $sourceDigests = [ordered]@{
    workflow_ir_sha256 = Get-TaogeFileSha256 $workflowPath
    component_catalog_sha256 = Get-TaogeFileSha256 $componentPath
    compatibility_catalog_sha256 = Get-TaogeFileSha256 $compatibilityPath
    legacy_blueprint_sha256 = Get-TaogeFileSha256 $blueprintPath
    legacy_node_registry_sha256 = Get-TaogeFileSha256 $nodeRegistryPath
  }

  $reportPath = Join-Path $outputPath 'workflow-ir-parity-report.json'
  if ($errors.Count -gt 0) {
    $failureReport = [pscustomobject][ordered]@{
      schema_id = 'taoge://reports/workflow-ir-parity/v0.2'
      schema_version = '0.2'
      architecture_change_id = 'ARCH-20260718-002'
      workflow_ir_id = [string]$ir.workflow_ir_id
      result = 'fail'
      source_digests = $sourceDigests
      checks = [object[]]$checks.ToArray()
      errors = [object[]]$errors.ToArray()
      generated_views = [object[]]@()
    }
    Write-TaogeUtf8NoBomJson -Path $reportPath -Value $failureReport -Depth 30
    Write-Output 'WORKFLOW_IR_RESULT=fail'
    foreach ($item in $errors) { Write-Output ('WORKFLOW_IR_ERROR=' + $item) }
    Write-Output ('WORKFLOW_IR_REPORT=' + $reportPath)
    exit 1
  }

  $blueprintView = [pscustomobject][ordered]@{
    schema_id = 'taoge://workflow-kernel/generated/current-blueprint-view/v0.2'
    schema_version = '0.2'
    source_workflow_ir_id = [string]$ir.workflow_ir_id
    runtime_generation = [string]$ir.runtime_generation
    runtime_switch_enabled = [bool]$ir.runtime_switch_enabled
    session_generation_policy = $ir.session_generation_policy
    routes = [object[]]$routeViews.ToArray()
  }
  $stageView = [pscustomobject][ordered]@{
    schema_id = 'taoge://workflow-kernel/generated/current-stage-view/v0.2'
    schema_version = '0.2'
    source_workflow_ir_id = [string]$ir.workflow_ir_id
    stage_order = [object[]]@($ir.stage_order)
    stages = [object[]]@($ir.stage_definitions)
    route_stage_modes = [object[]]@($routeViews | ForEach-Object {
      [pscustomobject][ordered]@{
        route_id = [string]$_.route_id
        stages = [object[]]@($_.stage_bindings | ForEach-Object {
          [pscustomobject][ordered]@{
            stage_id = [string]$_.stage_id
            mode = [string]$_.mode
            component_count = @($_.component_refs).Count
          }
        })
      }
    })
  }
  $componentView = [pscustomobject][ordered]@{
    schema_id = 'taoge://workflow-kernel/generated/current-component-view/v0.2'
    schema_version = '0.2'
    source_catalog_id = [string]$components.catalog_id
    component_count = $expectedComponentIds.Count
    components = [object[]]@($expectedComponentIds | ForEach-Object { $componentDictionary[$_] })
  }
  $compatibilityView = [pscustomobject][ordered]@{
    schema_id = 'taoge://workflow-kernel/generated/current-compatibility-view/v0.2'
    schema_version = '0.2'
    source_catalog_id = [string]$compatibility.catalog_id
    current_kernel_load_allowed = [bool]$compatibility.current_kernel_load_allowed
    historical_blueprint_count = @($compatibility.historical_blueprints).Count
    historical_blueprints = [object[]]@($compatibility.historical_blueprints)
    compatibility_assets = [object[]]@($compatibility.compatibility_assets)
  }

  $generated = [ordered]@{
    'current-blueprint-view.json' = $blueprintView
    'current-stage-view.json' = $stageView
    'current-component-view.json' = $componentView
    'current-compatibility-view.json' = $compatibilityView
  }
  foreach ($entry in $generated.GetEnumerator()) {
    Write-TaogeUtf8NoBomJson -Path (Join-Path $outputPath $entry.Key) -Value $entry.Value -Depth 40
  }

  $generatedViews = [System.Collections.Generic.List[object]]::new()
  foreach ($name in @($generated.Keys)) {
    $viewPath = Join-Path $outputPath $name
    $generatedViews.Add([pscustomobject][ordered]@{
      path = $name
      sha256 = Get-TaogeFileSha256 $viewPath
    })
  }
  Add-WorkflowIrCheck $checks 'M5-C10-generated-view-commit' $true 'four isolated generated views written before parity report'
  $successReport = [pscustomobject][ordered]@{
    schema_id = 'taoge://reports/workflow-ir-parity/v0.2'
    schema_version = '0.2'
    architecture_change_id = 'ARCH-20260718-002'
    workflow_ir_id = [string]$ir.workflow_ir_id
    result = 'pass'
    runtime_switch_enabled = [bool]$ir.runtime_switch_enabled
    route_count = $routeViews.Count
    stage_count = $expectedStages.Count
    current_component_count = $expectedComponentIds.Count
    historical_blueprint_count = $expectedHistoricalKeys.Count
    source_digests = $sourceDigests
    generated_views = [object[]]$generatedViews.ToArray()
    checks = [object[]]$checks.ToArray()
    errors = [object[]]@()
  }
  Write-TaogeUtf8NoBomJson -Path $reportPath -Value $successReport -Depth 30
  Write-Output 'WORKFLOW_IR_RESULT=pass'
  Write-Output ('WORKFLOW_IR_ROUTE_COUNT=' + $routeViews.Count)
  Write-Output ('WORKFLOW_IR_STAGE_COUNT=' + $expectedStages.Count)
  Write-Output ('WORKFLOW_IR_COMPONENT_COUNT=' + $expectedComponentIds.Count)
  Write-Output ('WORKFLOW_IR_HISTORICAL_BLUEPRINT_COUNT=' + $expectedHistoricalKeys.Count)
  Write-Output ('WORKFLOW_IR_REPORT=' + $reportPath)
  exit 0
} catch {
  Write-Error ('WORKFLOW_IR_TOOL_ERROR=' + $_.Exception.Message)
  exit 3
}
