param(
  [string]$FixtureRoot = 'examples/r7-h1-contract-fixtures',
  [string]$SchemaRoot = 'templates/schema/r7',
  [string]$BlueprintPath = 'routes/r7-workflow-blueprints.yaml',
  [string]$NodeRegistryPath = 'routes/r7-node-registry.yaml',
  [string]$ContractRegistryPath = 'routes/r7-contract-status-registry.yaml',
  [string]$ActionRegistryPath = 'routes/r7-action-registry.yaml',
  [string]$CompatibilityMatrixPath = 'templates/schema/r7/compatibility-matrix.v0.1.json',
  [string]$HumanReportPath = 'state/checks/r7-h1-contract-check-report.md',
  [string]$MachineReportPath = 'state/checks/r7-h1-contract-check-report.json'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'YamlHelper.ps1')
. (Join-Path $PSScriptRoot 'R7ContractHelper.ps1')

function Resolve-R7ProjectPath {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
  $projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
  return Join-Path $projectRoot $Path
}

function New-R7CheckResult {
  param(
    [string]$FixtureId,
    [string]$ContractType,
    [string]$ExpectedResult,
    [object[]]$Errors,
    [string]$Path,
    [string]$ExpectedError = ''
  )
  $errorItems = @($Errors | ForEach-Object { $_ })
  $errorCount = ($errorItems | Measure-Object).Count
  $actual = if ($errorCount -gt 0) { 'fail' } else { 'pass' }
  $matched = $actual -eq $ExpectedResult
  if ($matched -and $ExpectedResult -eq 'fail' -and -not [string]::IsNullOrWhiteSpace($ExpectedError)) {
    $matched = (($errorItems | Where-Object { [string]$_ -like "$ExpectedError*" } | Measure-Object).Count -gt 0)
  }
  return [pscustomobject]@{
    fixture_id = $FixtureId
    contract_type = $ContractType
    expected_result = $ExpectedResult
    actual_result = $actual
    expectation_met = $matched
    errors = $errorItems
    path = $Path
  }
}

try {
  $fixturePath = Resolve-R7ProjectPath $FixtureRoot
  $schemaPath = Resolve-R7ProjectPath $SchemaRoot
  $blueprintFile = Resolve-R7ProjectPath $BlueprintPath
  $nodeFile = Resolve-R7ProjectPath $NodeRegistryPath
  $contractFile = Resolve-R7ProjectPath $ContractRegistryPath
  $actionFile = Resolve-R7ProjectPath $ActionRegistryPath
  $matrixFile = Resolve-R7ProjectPath $CompatibilityMatrixPath
  $projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
  foreach ($path in @($fixturePath,$schemaPath,$blueprintFile,$nodeFile,$contractFile,$actionFile,$matrixFile)) {
    if (-not (Test-Path -LiteralPath $path)) { Write-Error "R7 H1 preflight path missing: $path"; exit 4 }
  }
  $humanPath = Resolve-R7ProjectPath $HumanReportPath
  $machinePath = Resolve-R7ProjectPath $MachineReportPath
  foreach ($reportPath in @($humanPath,$machinePath)) {
    $parent = Split-Path -Parent $reportPath
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  }

  $results = [System.Collections.Generic.List[object]]::new()
  $expectedSchemaIds = @(
    'taoge://schemas/r7/workflow-blueprint/v0.1',
    'taoge://schemas/r7/workflow-blueprint/v0.2',
    'taoge://schemas/r7/node-registry/v0.1',
    'taoge://schemas/r7/contract-status-registry/v0.1',
    'taoge://schemas/r7/action-registry/v0.1',
    'taoge://schemas/r7/semantic-task-envelope/v0.1',
    'taoge://schemas/r7/semantic-task-envelope/v0.2',
    'taoge://schemas/r7/semantic-artifact-submission/v0.1',
    'taoge://schemas/r7/compatibility-matrix/v0.1'
  )
  $expectedSchemaFiles = @(
    'workflow-blueprint.v0.1.schema.json',
    'workflow-blueprint.v0.2.schema.json',
    'node-registry.v0.1.schema.json',
    'contract-status-registry.v0.1.schema.json',
    'action-registry.v0.1.schema.json',
    'semantic-task-envelope.v0.1.schema.json',
    'semantic-task-envelope.v0.2.schema.json',
    'semantic-artifact-submission.v0.1.schema.json',
    'compatibility-matrix.v0.1.schema.json'
  )
  $seenSchemaIds = @{}
  foreach ($schemaFileName in $expectedSchemaFiles) {
    $file = Get-Item -LiteralPath (Join-Path $schemaPath $schemaFileName)
    $errors = [System.Collections.Generic.List[string]]::new()
    try {
      $schema = Read-R7JsonFile $file.FullName
      if ($schema.'$schema' -ne 'https://json-schema.org/draft/2020-12/schema') { $errors.Add('schema_dialect_invalid') }
      if ([string]::IsNullOrWhiteSpace([string]$schema.'$id')) { $errors.Add('schema_id_missing') } else { $seenSchemaIds[[string]$schema.'$id'] = $true }
      if (-not (Test-R7HasProperty $schema 'additionalProperties') -or $schema.additionalProperties -ne $false) { $errors.Add('schema_root_additional_properties_not_closed') }
    } catch { $errors.Add('schema_json_parse_error:' + $_.Exception.Message) }
    $results.Add((New-R7CheckResult -FixtureId ('R7-H1-SCHEMA-' + $file.BaseName) -ContractType 'json_schema' -ExpectedResult 'pass' -Errors $errors.ToArray() -Path $file.FullName))
  }
  foreach ($id in $expectedSchemaIds) {
    $errors = if ($seenSchemaIds.ContainsKey($id)) { @() } else { @('schema_expected_id_missing:' + $id) }
    $results.Add((New-R7CheckResult -FixtureId ('R7-H1-SCHEMA-ID-' + ($id -replace '[^a-zA-Z0-9]+','-')) -ContractType 'json_schema' -ExpectedResult 'pass' -Errors $errors -Path $schemaPath))
  }

  $blueprints = Read-YamlFile -Path $blueprintFile
  $nodes = Read-YamlFile -Path $nodeFile
  $contracts = Read-YamlFile -Path $contractFile
  $actions = Read-YamlFile -Path $actionFile
  $matrix = Read-R7JsonFile $matrixFile
  $results.Add((New-R7CheckResult -FixtureId 'R7-H1-ACTUAL-BLUEPRINTS' -ContractType 'workflow_blueprint' -ExpectedResult 'pass' -Errors @(Test-R7WorkflowBlueprintContract $blueprints) -Path $blueprintFile))
  $results.Add((New-R7CheckResult -FixtureId 'R7-H1-ACTUAL-NODES' -ContractType 'node_registry' -ExpectedResult 'pass' -Errors @(Test-R7NodeRegistryContract $nodes) -Path $nodeFile))
  $results.Add((New-R7CheckResult -FixtureId 'R7-H1-ACTUAL-CONTRACT-STATUS' -ContractType 'contract_status_registry' -ExpectedResult 'pass' -Errors @(Test-R7ContractStatusRegistryContract $contracts) -Path $contractFile))
  $results.Add((New-R7CheckResult -FixtureId 'R7-H1-ACTUAL-ACTIONS' -ContractType 'action_registry' -ExpectedResult 'pass' -Errors @(Test-R7ActionRegistryContract $actions) -Path $actionFile))
  $results.Add((New-R7CheckResult -FixtureId 'R7-H1-ACTUAL-COMPATIBILITY' -ContractType 'compatibility_matrix' -ExpectedResult 'pass' -Errors @(Test-R7CompatibilityMatrixContract $matrix) -Path $matrixFile))

  $crossErrors = [System.Collections.Generic.List[string]]::new()
  $nodeIds = @{}; foreach ($node in @($nodes.nodes)) { $nodeIds[[string]$node.node_id] = $node }
  foreach ($blueprint in @($blueprints.blueprints)) {
    foreach ($nodeId in @($blueprint.node_refs)) { if (-not $nodeIds.ContainsKey([string]$nodeId)) { $crossErrors.Add("blueprint_node_unregistered:$($blueprint.blueprint_id):$nodeId") } }
  }
  foreach ($node in @($nodes.nodes)) {
    $skillPath = Join-Path $projectRoot ('skills/' + [string]$node.skill_ref + '/SKILL.md')
    $nodePending=([string]$node.implementation_status -like 'pending_*')
    if (-not $nodePending -and -not (Test-Path -LiteralPath $skillPath)) { $crossErrors.Add("node_skill_missing:$($node.node_id):$($node.skill_ref)") }
    foreach ($routeName in @('success_route','warning_route','failure_route')) {
      $route = [string]$node.$routeName
      if ($route -notin @('done','owning_producer') -and -not $nodeIds.ContainsKey($route)) { $crossErrors.Add("node_route_unregistered:$($node.node_id):${routeName}:$route") }
    }
  }
  $expectedActions = @('archive_session','export_handoff','publish_all_manually','publish_primary_manually','review_secondary_covers','revise_copy','revise_visual')
  $actualActions = @($actions.actions | ForEach-Object { [string]$_.action_code } | Sort-Object)
  $missingBaselineActions=@($expectedActions|Where-Object{$_ -notin $actualActions})
  if($missingBaselineActions.Count){$crossErrors.Add('action_registry_direct_baseline_missing:'+([string]::Join(',',$missingBaselineActions)))}
  if([string]$actions.registry_id -eq 'r7-action-registry-v0.2'){
    $requiredHotspotActions=@('select_topic','rerun_hotspot_research','broaden_hotspot_scope','attach_manual_hotspot_source','branch_selected_topics')
    $missingHotspotActions=@($requiredHotspotActions|Where-Object{$_ -notin $actualActions})
    if($missingHotspotActions.Count){$crossErrors.Add('action_registry_hotspot_v02_missing:'+([string]::Join(',',$missingHotspotActions)))}
  }
  if ($actualActions -contains 'regenerate_visual') { $crossErrors.Add('action_registry_forbidden_regenerate_visual') }
  $candidateV05 = @($contracts.contracts | Where-Object { $_.contract_id -eq 'p0-agent-produced-delivery-candidate-v0.5' })
  if ($candidateV05.Count -ne 1 -or $candidateV05[0].lifecycle_status -ne 'superseded_pending_recompile') { $crossErrors.Add('candidate_v05_superseded_status_missing') }
  $rendererV05 = @($contracts.contracts | Where-Object { $_.contract_id -eq 'p0-delivery-renderer-v0.5' })
  if ($rendererV05.Count -ne 1 -or $rendererV05[0].lifecycle_status -notin @('active_compiled','historical_compatibility') -or $rendererV05[0].superseded_by -ne 'p0-delivery-renderer-v0.6') { $crossErrors.Add('renderer_v05_history_compatibility_broken') }
  $targetV06 = @($contracts.contracts | Where-Object { $_.contract_id -eq 'p0-deterministic-delivery-candidate-compiler-v0.6' })
  $missingV06Layers=if($targetV06.Count -eq 1){@('schema','fixture','checker','runtime')|Where-Object{$_ -notin @($targetV06[0].compiled_layers)}}else{@('contract')}
  $targetV08 = @($contracts.contracts | Where-Object { $_.contract_id -eq 'p0-deterministic-delivery-candidate-compiler-v0.8' })
  $targetV09 = @($contracts.contracts | Where-Object { $_.contract_id -eq 'p0-deterministic-delivery-candidate-compiler-v0.9' })
  $v08HistoricalValid = $targetV08.Count -eq 1 -and $targetV08[0].lifecycle_status -eq 'historical_compatibility' -and $targetV08[0].superseded_by -eq 'p0-deterministic-delivery-candidate-compiler-v0.9' -and $targetV09.Count -eq 1 -and $targetV09[0].lifecycle_status -eq 'active_compiled'
  $v06HistoricalValid = $targetV06.Count -eq 1 -and $targetV06[0].lifecycle_status -eq 'historical_compatibility' -and $targetV06[0].superseded_by -eq 'p0-deterministic-delivery-candidate-compiler-v0.8' -and $v08HistoricalValid
  if ($targetV06.Count -ne 1 -or ($targetV06[0].lifecycle_status -notin @('confirmed_pending_compile','active_compiled') -and -not $v06HistoricalValid)) { $crossErrors.Add('candidate_v06_lifecycle_invalid') }
  elseif($targetV06[0].lifecycle_status -eq 'active_compiled' -and @($missingV06Layers).Count){$crossErrors.Add('candidate_v06_activation_layers_incomplete')}
  $results.Add((New-R7CheckResult -FixtureId 'R7-H1-ACTUAL-CROSS-REGISTRY' -ContractType 'cross_registry' -ExpectedResult 'pass' -Errors $crossErrors.ToArray() -Path $projectRoot))

  $manifestFile = Join-Path $fixturePath 'fixtures.json'
  if (-not (Test-Path -LiteralPath $manifestFile)) { Write-Error "R7 H1 fixture manifest missing: $manifestFile"; exit 4 }
  $manifest = Read-R7JsonFile $manifestFile
  foreach ($case in @($manifest.cases)) {
    $caseFile = Join-Path $fixturePath ([string]$case.path)
    $caseErrors = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $caseFile)) {
      $caseErrors.Add('fixture_path_missing')
    } else {
      try {
        $document = Read-R7JsonFile $caseFile
        switch ([string]$case.contract_type) {
          'workflow_blueprint' { foreach ($validationError in (Test-R7WorkflowBlueprintContract $document)) { $caseErrors.Add($validationError) } }
          'node_registry' { foreach ($validationError in (Test-R7NodeRegistryContract $document)) { $caseErrors.Add($validationError) } }
          'contract_status_registry' { foreach ($validationError in (Test-R7ContractStatusRegistryContract $document)) { $caseErrors.Add($validationError) } }
          'action_registry' { foreach ($validationError in (Test-R7ActionRegistryContract $document)) { $caseErrors.Add($validationError) } }
          'task_envelope' { foreach ($validationError in (Test-R7TaskEnvelopeContract $document $actions)) { $caseErrors.Add($validationError) } }
          'semantic_submission' {
            $envelopeFile = Join-Path $fixturePath ([string]$case.envelope_path)
            $envelope = Read-R7JsonFile $envelopeFile
            foreach ($validationError in (Test-R7ArtifactSubmissionContract $document $envelope $actions)) { $caseErrors.Add($validationError) }
          }
          'compatibility_matrix' { foreach ($validationError in (Test-R7CompatibilityMatrixContract $document)) { $caseErrors.Add($validationError) } }
          default { $caseErrors.Add('fixture_contract_type_unknown:' + $case.contract_type) }
        }
      } catch { $caseErrors.Add('fixture_validation_exception:' + $_.Exception.Message) }
    }
    $expectedError = if (Test-R7HasProperty $case 'expected_error') { [string]$case.expected_error } else { '' }
    $results.Add((New-R7CheckResult -FixtureId ([string]$case.fixture_id) -ContractType ([string]$case.contract_type) -ExpectedResult ([string]$case.expected_result) -Errors $caseErrors.ToArray() -Path $caseFile -ExpectedError $expectedError))
  }

  $mismatches = @($results | Where-Object { -not $_.expectation_met })
  $negative = @($manifest.cases | Where-Object { $_.expected_result -eq 'fail' })
  $report = [ordered]@{
    r7_h1_contract_check_report = [ordered]@{
      check_run_id = 'R7-H1-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
      suite_id = [string]$manifest.fixture_suite_id
      schema_version = '0.1'
      overall_result = $(if ($mismatches.Count) { 'fail' } else { 'pass' })
      exit_code = $(if ($mismatches.Count) { 1 } else { 0 })
      schema_count = $seenSchemaIds.Count
      fixture_count = @($manifest.cases).Count
      negative_fixture_count = $negative.Count
      actual_registry_check_count = 6
      mismatch_count = $mismatches.Count
      not_tested_scope = @('r7_h2_coordinator_runtime','r7_h2_submitter','r7_h3_producer_adapters','r7_h4_candidate_compiler','r7_h5_viewport_acceptance','r7_h6_hotspot_adapter','real_account','image_provider','publishing')
      checks = [object[]]$results.ToArray()
    }
  }
  Write-TaogeUtf8NoBomJson -Path $machinePath -Value $report -Depth 14
  $lines = @('# R7-H1 Contract Check Report','', '```yaml')
  foreach ($name in @('check_run_id','overall_result','exit_code','schema_count','fixture_count','negative_fixture_count','actual_registry_check_count','mismatch_count')) { $lines += "$name`: $($report.r7_h1_contract_check_report[$name])" }
  $lines += '```'
  $lines += ''
  $lines += '| Fixture | Contract | Expected | Actual | Matched | Errors |'
  $lines += '|---|---|---|---|---:|---|'
  foreach ($result in $results) {
    $errorText = if (@($result.errors).Count) { [string]::Join('; ',@($result.errors)) } else { 'none' }
    $lines += "| $($result.fixture_id) | $($result.contract_type) | $($result.expected_result) | $($result.actual_result) | $($result.expectation_met) | $errorText |"
  }
  Write-TaogeUtf8NoBomLines -Path $humanPath -Lines $lines

  if ($mismatches.Count) {
    Write-Output 'R7_H1_CONTRACT_CHECK_RESULT=fail'
    foreach ($mismatch in $mismatches) { Write-Output "R7_H1_CONTRACT_ERROR=$($mismatch.fixture_id):expectation_mismatch" }
    exit 1
  }
  Write-Output 'R7_H1_CONTRACT_CHECK_RESULT=pass'
  Write-Output "R7_H1_SCHEMA_COUNT=$($seenSchemaIds.Count)"
  Write-Output "R7_H1_FIXTURE_COUNT=$(@($manifest.cases).Count)"
  Write-Output "R7_H1_NEGATIVE_FIXTURE_COUNT=$($negative.Count)"
  exit 0
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
