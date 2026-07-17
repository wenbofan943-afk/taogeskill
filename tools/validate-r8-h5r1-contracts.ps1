param(
  [string]$ProjectRoot = '',
  [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
} else {
  $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = Join-Path $ProjectRoot 'state/checks/r8-h5r1-contract-report.json'
}

. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'YamlHelper.ps1')

function Get-R8Property {
  param([object]$Object, [string]$Name)
  if ($null -eq $Object) { return $null }
  if ($Object -is [System.Collections.IDictionary]) {
    if ($Object.Contains($Name)) {
      Write-Output -NoEnumerate $Object[$Name]
      return
    }
    return $null
  }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  Write-Output -NoEnumerate $property.Value
}

function Test-R8HasProperty {
  param([object]$Object, [string]$Name)
  if ($null -eq $Object) { return $false }
  if ($Object -is [System.Collections.IDictionary]) { return $Object.Contains($Name) }
  return $null -ne $Object.PSObject.Properties[$Name]
}

function Get-R8PropertyNames {
  param([object]$Object)
  if ($null -eq $Object) { return @() }
  if ($Object -is [System.Collections.IDictionary]) { return @($Object.Keys | ForEach-Object { [string]$_ }) }
  return @($Object.PSObject.Properties.Name)
}

function Get-R8Items {
  param([object]$Value)
  if ($null -eq $Value) { return @() }
  if ($Value -is [System.Array]) { return @($Value) }
  return @($Value)
}

function ConvertTo-R8NormalizedJson {
  param([object]$Value)
  if ($null -eq $Value) { return 'null' }
  return ($Value | ConvertTo-Json -Depth 40 -Compress)
}

function Test-R8JsonType {
  param([object]$Value, [string]$TypeName)
  switch ($TypeName) {
    'null' { return $null -eq $Value }
    'string' { return $Value -is [string] }
    'boolean' { return $Value -is [bool] }
    'integer' {
      return $Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or
        $Value -is [int64] -or $Value -is [uint16] -or $Value -is [uint32] -or
        $Value -is [uint64]
    }
    'number' {
      return (Test-R8JsonType $Value 'integer') -or $Value -is [single] -or
        $Value -is [double] -or $Value -is [decimal]
    }
    'array' { return $Value -is [System.Array] }
    'object' {
      return $null -ne $Value -and $Value -isnot [string] -and
        $Value -isnot [System.Array] -and $Value -isnot [bool] -and
        $Value -isnot [ValueType]
    }
    default { return $false }
  }
}

function Test-R8SchemaNode {
  param(
    [object]$Value,
    [object]$Schema,
    [string]$Path,
    [System.Collections.Generic.List[string]]$Errors
  )

  $types = @(Get-R8Items (Get-R8Property $Schema 'type') | ForEach-Object { [string]$_ })
  if ($types.Count -gt 0) {
    $typeMatch = $false
    foreach ($typeName in $types) {
      if (Test-R8JsonType $Value $typeName) { $typeMatch = $true; break }
    }
    if (-not $typeMatch) {
      $Errors.Add("type:$Path expected=$([string]::Join('|', $types))")
      return
    }
  }

  if ($null -eq $Value) { return }

  if (Test-R8HasProperty $Schema 'const') {
    $expected = ConvertTo-R8NormalizedJson (Get-R8Property $Schema 'const')
    $actual = ConvertTo-R8NormalizedJson $Value
    if ($actual -ne $expected) { $Errors.Add("const:$Path expected=$expected actual=$actual") }
  }

  $enumValues = @(Get-R8Items (Get-R8Property $Schema 'enum'))
  if ($enumValues.Count -gt 0) {
    $actual = ConvertTo-R8NormalizedJson $Value
    $allowed = @($enumValues | ForEach-Object { ConvertTo-R8NormalizedJson $_ })
    if ($actual -notin $allowed) { $Errors.Add("enum:$Path actual=$actual") }
  }

  if ($Value -is [string]) {
    $minLength = Get-R8Property $Schema 'minLength'
    if ($null -ne $minLength -and $Value.Length -lt [int]$minLength) {
      $Errors.Add("minLength:$Path")
    }
    $pattern = [string](Get-R8Property $Schema 'pattern')
    if (-not [string]::IsNullOrWhiteSpace($pattern) -and $Value -notmatch $pattern) {
      $Errors.Add("pattern:$Path")
    }
  }

  if (Test-R8JsonType $Value 'number') {
    $minimum = Get-R8Property $Schema 'minimum'
    if ($null -ne $minimum -and [decimal]$Value -lt [decimal]$minimum) {
      $Errors.Add("minimum:$Path")
    }
  }

  if ($Value -is [System.Array]) {
    $items = @($Value)
    $minItems = Get-R8Property $Schema 'minItems'
    if ($null -ne $minItems -and $items.Count -lt [int]$minItems) {
      $Errors.Add("minItems:$Path")
    }
    if ((Get-R8Property $Schema 'uniqueItems') -eq $true) {
      $normalized = @($items | ForEach-Object { ConvertTo-R8NormalizedJson $_ })
      if (@($normalized | Select-Object -Unique).Count -ne $normalized.Count) {
        $Errors.Add("uniqueItems:$Path")
      }
    }
    $itemSchema = Get-R8Property $Schema 'items'
    if ($null -ne $itemSchema) {
      for ($index = 0; $index -lt $items.Count; $index++) {
        Test-R8SchemaNode $items[$index] $itemSchema "$Path[$index]" $Errors
      }
    }
  }

  if (Test-R8JsonType $Value 'object') {
    foreach ($requiredName in @(Get-R8Items (Get-R8Property $Schema 'required'))) {
      if (-not (Test-R8HasProperty $Value ([string]$requiredName))) {
        $Errors.Add("required:$Path.$requiredName")
      }
    }
    $properties = Get-R8Property $Schema 'properties'
    if ($null -ne $properties) {
      $allowedNames = @(Get-R8PropertyNames $properties)
      foreach ($name in @(Get-R8PropertyNames $Value)) {
        $childSchema = Get-R8Property $properties $name
        if ($null -ne $childSchema) {
          Test-R8SchemaNode (Get-R8Property $Value $name) $childSchema "$Path.$name" $Errors
        } elseif ((Get-R8Property $Schema 'additionalProperties') -eq $false) {
          $Errors.Add("additionalProperties:$Path.$name")
        }
      }
      if ((Get-R8Property $Schema 'additionalProperties') -eq $false) {
        foreach ($name in @(Get-R8PropertyNames $Value)) {
          if ($name -notin $allowedNames) { $Errors.Add("additionalProperties:$Path.$name") }
        }
      }
    }
  }
}

function Copy-R8JsonObject {
  param([object]$Value)
  return ($Value | ConvertTo-Json -Depth 40 -Compress | ConvertFrom-Json)
}

function Set-R8Mutation {
  param([object]$RootObject, [object]$Mutation)
  $segments = @(([string](Get-R8Property $Mutation 'path')).Split('.'))
  $target = $RootObject
  for ($index = 0; $index -lt $segments.Count - 1; $index++) {
    if ($target -is [System.Array] -and $segments[$index] -match '^\d+$') {
      $target = $target[[int]$segments[$index]]
    } else {
      $target = Get-R8Property $target $segments[$index]
    }
  }
  $leaf = $segments[$segments.Count - 1]
  $operation = [string](Get-R8Property $Mutation 'operation')
  if ($target -is [System.Array] -and $leaf -match '^\d+$') {
    throw 'array_leaf_mutation_not_supported'
  }
  if ($operation -eq 'remove') {
    [void]$target.PSObject.Properties.Remove($leaf)
  } elseif ($operation -eq 'set_null') {
    $target.$leaf = $null
  } elseif ($operation -eq 'set') {
    $target.$leaf = Get-R8Property $Mutation 'value'
  } else {
    throw "unsupported_mutation:$operation"
  }
}

function Get-R8InvariantErrors {
  param([object]$Payloads)
  $errors = [System.Collections.Generic.List[string]]::new()
  $arm = Get-R8Property $Payloads 'h5_arm_result'
  $machine = Get-R8Property $Payloads 'h5_machine_verdict'
  $comparison = Get-R8Property $Payloads 'h5_comparability_verdict'
  $blind = Get-R8Property $Payloads 'h5_blind_pair'
  $finalization = Get-R8Property $Payloads 'h5_evaluation_finalization'

  $produced = [string](Get-R8Property $arm 'result_status') -eq 'produced_business_artifact'
  $artifact = Get-R8Property $arm 'business_artifact_ref'
  if ($produced) {
    if ($null -eq $artifact -or [string](Get-R8Property $arm 'business_output_schema_gate') -ne 'pass' -or
        [string]::IsNullOrWhiteSpace([string](Get-R8Property $arm 'output_digest'))) {
      $errors.Add('produced_artifact_missing')
    }
  } elseif ($null -ne $artifact) {
    $errors.Add('nonproduced_artifact_present')
  }
  if ([string](Get-R8Property $arm 'manual_assist_observation') -eq 'not_observable' -and
      $null -ne (Get-R8Property $arm 'manual_assist_count')) {
    $errors.Add('manual_assist_not_observable_has_count')
  }
  if ([string](Get-R8Property $arm 'token_observation') -eq 'not_observable' -and
      $null -ne (Get-R8Property $arm 'input_tokens')) {
    $errors.Add('tokens_not_observable_has_count')
  }

  if ([string](Get-R8Property $machine 'verdict_status') -eq 'pass') {
    foreach ($componentName in @('baseline_contract_result','candidate_contract_result','shared_invariant_result')) {
      if ([string](Get-R8Property $machine $componentName) -ne 'pass') {
        $errors.Add('machine_pass_component_failed')
        break
      }
    }
  }

  $comparable = [string](Get-R8Property $comparison 'comparability_status') -eq 'comparable'
  if ($comparable) {
    $baselineType = [string](Get-R8Property $comparison 'baseline_primary_output_type')
    $candidateType = [string](Get-R8Property $comparison 'candidate_primary_output_type')
    if ([string](Get-R8Property $machine 'verdict_status') -ne 'pass') {
      $errors.Add('comparable_without_machine_pass')
    }
    if ([string]::IsNullOrWhiteSpace($baselineType) -or $baselineType -ne $candidateType) {
      $errors.Add('comparable_output_type_mismatch')
    }
  }
  if ([string](Get-R8Property $blind 'pair_status') -eq 'ready' -and
      (-not $comparable -or (Get-R8Property $comparison 'blind_pair_allowed') -ne $true)) {
    $errors.Add('ready_blind_pair_not_allowed')
  }
  if ([string](Get-R8Property $blind 'pair_status') -eq 'ready') {
    $aType = [string](Get-R8Property (Get-R8Property $blind 'a') 'artifact_type')
    $bType = [string](Get-R8Property (Get-R8Property $blind 'b') 'artifact_type')
    $expectedType = [string](Get-R8Property $comparison 'baseline_primary_output_type')
    if ([string]::IsNullOrWhiteSpace($aType) -or $aType -ne $bType -or $aType -ne $expectedType) {
      $errors.Add('blind_pair_type_mismatch')
    }
  }
  if ([string](Get-R8Property $machine 'verdict_status') -ne 'pass' -and
      [string](Get-R8Property $blind 'pair_status') -eq 'ready') {
    $errors.Add('machine_fail_with_ready_blind_pair')
  }

  if ([string](Get-R8Property $finalization 'current_switch_readiness') -eq 'passed') {
    $counts = Get-R8Property $finalization 'per_skill_comparable_counts'
    foreach ($skillId in @('hotspot-topic-research','propagation-router','platform-packaging-adapter')) {
      if ([int](Get-R8Property $counts $skillId) -lt 1) {
        $errors.Add('readiness_pass_insufficient_samples')
        break
      }
    }
    if ((Get-R8Property $finalization 'all_machine_gates_pass') -ne $true -or
        (Get-R8Property $finalization 'all_rejection_cases_fail_closed') -ne $true -or
        (Get-R8Property $finalization 'human_verdicts_complete') -ne $true) {
      $errors.Add('readiness_pass_gate_incomplete')
    }
    foreach ($summary in @(Get-R8Items (Get-R8Property $finalization 'case_summaries'))) {
      if ([string](Get-R8Property $summary 'case_result') -notin @('candidate','tie')) {
        $errors.Add('readiness_pass_case_not_candidate_or_tie')
      }
    }
  }

  foreach ($objectType in @(Get-R8PropertyNames $Payloads)) {
    $payload = Get-R8Property $Payloads $objectType
    $supersedes = [string](Get-R8Property $payload 'supersedes')
    if (-not [string]::IsNullOrWhiteSpace($supersedes)) {
      $identityName = switch ($objectType) {
        'h5_semantic_case' { 'semantic_case_id' }
        'h5_dependency_snapshot' { 'snapshot_id' }
        'h5_arm_input' { 'arm_input_id' }
        'h5_arm_result' { 'arm_result_id' }
        'h5_machine_verdict' { 'machine_verdict_id' }
        'h5_comparability_verdict' { 'comparability_verdict_id' }
        'h5_blind_pair' { 'blind_pair_id' }
        'h5_human_verdict' { 'human_verdict_id' }
        'h5_evaluation_finalization' { 'evaluation_finalization_id' }
        default { '' }
      }
      if (-not [string]::IsNullOrWhiteSpace($identityName) -and
          $supersedes -eq [string](Get-R8Property $payload $identityName)) {
        $errors.Add('self_supersedes')
      }
    }
  }
  return @($errors)
}

$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$schemaPassCount = 0
$schemaNegativePassCount = 0
$invariantNegativePassCount = 0

$registryPath = Join-Path $ProjectRoot 'routes/r8-h5-evaluation-contracts.yaml'
$fixturePath = Join-Path $ProjectRoot 'examples/r8-h5r1-contract-fixtures/fixtures.json'
$compatibilityPath = Join-Path $ProjectRoot 'templates/schema/r8/h5/h5-evaluation-compatibility.v0.2.json'
$compatibilitySchemaPath = Join-Path $ProjectRoot 'templates/schema/r8/h5/h5-evaluation-compatibility.v0.2.schema.json'

foreach ($requiredPath in @($registryPath,$fixturePath,$compatibilityPath,$compatibilitySchemaPath)) {
  if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
    $errors.Add("required_file_missing:$requiredPath")
  }
}

if ($errors.Count -eq 0) {
  $registry = Read-YamlFile -Path $registryPath
  $fixtures = Get-Content -LiteralPath $fixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
  $payloads = Get-R8Property $fixtures 'valid_payloads'
  $objects = @(Get-R8Items (Get-R8Property $registry 'objects'))
  $expectedObjectTypes = @(
    'h5_semantic_case',
    'h5_dependency_snapshot',
    'h5_arm_input',
    'h5_arm_result',
    'h5_machine_verdict',
    'h5_comparability_verdict',
    'h5_blind_pair',
    'h5_human_verdict',
    'h5_evaluation_finalization'
  )

  if ($objects.Count -ne 9) { $errors.Add("registry_object_count:$($objects.Count)") }
  $actualObjectTypes = @($objects | ForEach-Object { [string](Get-R8Property $_ 'object_type') })
  foreach ($objectType in $expectedObjectTypes) {
    if ($objectType -notin $actualObjectTypes) { $errors.Add("registry_object_missing:$objectType") }
  }
  if ([string](Get-R8Property $registry 'legacy_status') -ne 'invalid_evaluation') {
    $errors.Add('legacy_status_not_invalid_evaluation')
  }
  if ([string](Get-R8Property $registry 'current_execution_status') -notin @('adapters_pending','inputs_ready_arm_execution_pending','machine_gates_ready_arm_execution_pending')) {
    $errors.Add('h5r1_scope_drift_current_execution_status')
  }
  if ([string](Get-R8Property $registry 'isolation_claim_ceiling') -ne 'instruction_isolated') {
    $errors.Add('isolation_claim_ceiling_drift')
  }

  $schemaByObject = @{}
  foreach ($entry in $objects) {
    $objectType = [string](Get-R8Property $entry 'object_type')
    $relativeSchemaPath = [string](Get-R8Property $entry 'schema_path')
    $fullSchemaPath = Join-Path $ProjectRoot ($relativeSchemaPath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $fullSchemaPath -PathType Leaf)) {
      $errors.Add("schema_missing:${objectType}:$relativeSchemaPath")
      continue
    }
    $allowedCompileStatuses = if ($objectType -in @('h5_semantic_case','h5_dependency_snapshot','h5_arm_input','h5_arm_result','h5_machine_verdict','h5_comparability_verdict')) {
      @('schema_compiled_producer_pending','producer_compiled')
    } else {
      @('schema_compiled_producer_pending')
    }
    if ([string](Get-R8Property $entry 'compile_status') -notin $allowedCompileStatuses) {
      $errors.Add("compile_status_drift:$objectType")
    }
    $schema = Get-Content -LiteralPath $fullSchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $schemaByObject[$objectType] = $schema
    $payload = Get-R8Property $payloads $objectType
    $validationErrors = [System.Collections.Generic.List[string]]::new()
    Test-R8SchemaNode $payload $schema '$' $validationErrors
    if ($validationErrors.Count -eq 0) {
      $schemaPassCount++
    } else {
      $errors.Add("valid_payload_rejected:${objectType}:$([string]::Join(',', $validationErrors))")
    }
  }

  foreach ($mutation in @(Get-R8Items (Get-R8Property $fixtures 'schema_negative_mutations'))) {
    $objectType = [string](Get-R8Property $mutation 'object_type')
    $mutated = Copy-R8JsonObject (Get-R8Property $payloads $objectType)
    Set-R8Mutation $mutated $mutation
    $validationErrors = [System.Collections.Generic.List[string]]::new()
    Test-R8SchemaNode $mutated $schemaByObject[$objectType] '$' $validationErrors
    if ($validationErrors.Count -gt 0) {
      $schemaNegativePassCount++
    } else {
      $errors.Add("negative_schema_accepted:$([string](Get-R8Property $mutation 'case_id'))")
    }
  }

  $validInvariantErrors = @(Get-R8InvariantErrors $payloads)
  if ($validInvariantErrors.Count -gt 0) {
    $errors.Add("valid_invariants_rejected:$([string]::Join(',', $validInvariantErrors))")
  }
  foreach ($mutation in @(Get-R8Items (Get-R8Property $fixtures 'invariant_negative_mutations'))) {
    $mutatedPayloads = Copy-R8JsonObject $payloads
    $objectType = [string](Get-R8Property $mutation 'object_type')
    Set-R8Mutation (Get-R8Property $mutatedPayloads $objectType) $mutation
    $fingerprints = @(Get-R8InvariantErrors $mutatedPayloads)
    $expected = [string](Get-R8Property $mutation 'expected_fingerprint')
    if ($expected -in $fingerprints) {
      $invariantNegativePassCount++
    } else {
      $errors.Add("negative_invariant_not_detected:$([string](Get-R8Property $mutation 'case_id')):$expected")
    }
  }

  $compatibility = Get-Content -LiteralPath $compatibilityPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $compatibilitySchema = Get-Content -LiteralPath $compatibilitySchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $compatibilityErrors = [System.Collections.Generic.List[string]]::new()
  Test-R8SchemaNode $compatibility $compatibilitySchema '$' $compatibilityErrors
  if ($compatibilityErrors.Count -gt 0) {
    $errors.Add("compatibility_schema_fail:$([string]::Join(',', $compatibilityErrors))")
  } else {
    $v01 = @(Get-R8Items (Get-R8Property $compatibility 'versions') | Where-Object { [string](Get-R8Property $_ 'version') -eq '0.1' })[0]
    $v02 = @(Get-R8Items (Get-R8Property $compatibility 'versions') | Where-Object { [string](Get-R8Property $_ 'version') -eq '0.2' })[0]
    if ([string](Get-R8Property $v01 'status') -ne 'invalid_evaluation' -or
        (Get-R8Property $v01 'blind_review_allowed') -ne $false) {
      $errors.Add('compatibility_v01_not_quarantined')
    }
    if ([string](Get-R8Property $v02 'status') -notin @(
        'schema_compiled_adapters_pending',
        'inputs_and_snapshots_compiled_evaluator_pending',
        'machine_gates_compiled_arm_execution_pending'
      ) -or
        (Get-R8Property $v02 'current_switch_evidence_allowed') -ne $false) {
      $errors.Add('compatibility_v02_overclaimed')
    }
  }

  $productText = ''
  foreach ($candidatePath in @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'docs/product') -Filter 'R8-*.md' -File)) {
    $candidateText = Get-Content -LiteralPath $candidatePath.FullName -Raw -Encoding UTF8
    if ($candidateText.Contains('## 11.5') -and $candidateText.Contains('h5_semantic_case')) {
      $productText = $candidateText
      break
    }
  }
  $fieldText = ''
  foreach ($candidatePath in @(Get-ChildItem -LiteralPath $ProjectRoot -Filter '*.md' -File)) {
    $candidateText = Get-Content -LiteralPath $candidatePath.FullName -Raw -Encoding UTF8
    if ($candidateText.Contains('## 48.') -and $candidateText.Contains('h5_semantic_case')) {
      $fieldText = $candidateText
      break
    }
  }
  if ([string]::IsNullOrWhiteSpace($productText)) { $errors.Add('product_contract_document_not_found') }
  if ([string]::IsNullOrWhiteSpace($fieldText)) { $errors.Add('field_dictionary_document_not_found') }
  foreach ($marker in @('R8-H5R1','h5_evaluation_finalization')) {
    if (-not $productText.Contains($marker)) { $errors.Add("product_marker_missing:$marker") }
  }
  if (-not $productText.Contains('schema_compiled_adapters_pending') -and
      -not $productText.Contains('inputs_and_snapshots_compiled_evaluator_pending') -and
      -not $productText.Contains('machine_gates_compiled_arm_execution_pending')) {
    $errors.Add('product_marker_missing:h5_v02_compile_status')
  }
  foreach ($marker in @('## 48.','h5_semantic_case','h5_evaluation_finalization','requested_node_id')) {
    if (-not $fieldText.Contains($marker)) { $errors.Add("field_dictionary_marker_missing:$marker") }
  }
}

$result = if ($errors.Count -eq 0) { 'pass' } else { 'fail' }
$report = [pscustomobject][ordered]@{
  schema_id = 'taoge://reports/r8/h5r1-contract-validation/v0.1'
  generated_at = [DateTimeOffset]::Now.ToString('o')
  result = $result
  build_profile = 'dev'
  project_root = '<PROJECT_ROOT>'
  schema_object_count = 9
  valid_schema_pass_count = $schemaPassCount
  schema_negative_pass_count = $schemaNegativePassCount
  invariant_negative_pass_count = $invariantNegativePassCount
  legacy_v01_status = 'invalid_evaluation'
  current_v02_status = [string](Get-R8Property $registry 'status')
  adapters_executed = $false
  independent_agents_executed = $false
  human_blind_review_executed = $false
  network_called = $false
  provider_called = $false
  private_account_used = $false
  public_profile_validation = 'not_run_in_current_dev_profile'
  errors = @($errors)
  warnings = @($warnings)
}
Write-TaogeUtf8NoBomJson -Path $ReportPath -Value $report -Depth 20

Write-Output "result=$result"
Write-Output "valid_schema_pass_count=$schemaPassCount"
Write-Output "schema_negative_pass_count=$schemaNegativePassCount"
Write-Output "invariant_negative_pass_count=$invariantNegativePassCount"
Write-Output "report=$ReportPath"
if ($errors.Count -gt 0) {
  foreach ($errorItem in $errors) { Write-Output "error=$errorItem" }
  exit 1
}
exit 0
