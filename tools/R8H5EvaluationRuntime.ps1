. (Join-Path $PSScriptRoot 'R8H5InputRuntime.ps1')
. (Join-Path $PSScriptRoot 'R8H5SchemaRuntime.ps1')

function Initialize-R8H5EvaluationRuntime {
  param([string]$ProjectRoot)
  $script:R8H5EvaluationProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
  $script:R8H5ProjectRoot = $script:R8H5EvaluationProjectRoot
}

function Read-R8H5EvaluationJson {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "evaluation_file_missing:$Path" }
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Resolve-R8H5EvaluationPath {
  param([string]$EvaluationRoot,[string]$RelativePath)
  if ([string]::IsNullOrWhiteSpace($RelativePath) -or [System.IO.Path]::IsPathRooted($RelativePath)) {
    throw 'evaluation_relative_path_invalid'
  }
  $root = [System.IO.Path]::GetFullPath($EvaluationRoot).TrimEnd('\','/')
  $full = [System.IO.Path]::GetFullPath((Join-Path $root ($RelativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)))
  if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar,[System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'evaluation_path_escape'
  }
  return $full
}

function Get-R8H5EvaluationPolicy {
  param([string]$SkillId,[string]$ArmRole)
  $registry = Read-YamlFile -Path (Join-Path $script:R8H5EvaluationProjectRoot 'routes/r8-h5-machine-evaluation.yaml')
  $matches = @($registry.policies | Where-Object { $_.skill_id -eq $SkillId -and $_.arm_role -eq $ArmRole })
  if ($matches.Count -ne 1) { throw "machine_policy_not_registered_or_duplicate:${SkillId}:${ArmRole}:$($matches.Count)" }
  return $matches[0]
}

function Get-R8H5ArmResultContractCheck {
  param([string]$EvaluationRoot,[object]$SemanticCase,[object]$ArmResult)
  $failed = [System.Collections.Generic.List[string]]::new()
  $schemaPath = Join-Path $script:R8H5EvaluationProjectRoot 'templates/schema/r8/h5/h5-arm-result.v0.2.schema.json'
  foreach ($item in @(Test-R8H5JsonSchemaValue $schemaPath $ArmResult)) { $failed.Add("arm_result_schema:$item") }
  if ($ArmResult.evaluation_id -ne $SemanticCase.evaluation_id -or
      $ArmResult.attempt_id -ne $SemanticCase.attempt_id -or
      $ArmResult.semantic_case_id -ne $SemanticCase.semantic_case_id -or
      $ArmResult.skill_id -ne $SemanticCase.skill_id) {
    $failed.Add('arm_result_identity_mismatch')
  }

  $armInput = $null
  $snapshot = $null
  try {
    $armInputPath = Resolve-R8H5EvaluationPath $EvaluationRoot ([string]$ArmResult.arm_input_ref)
    $armInput = Read-R8H5EvaluationJson $armInputPath
    $snapshotPath = Resolve-R8H5EvaluationPath $EvaluationRoot ([string]$ArmResult.dependency_snapshot_ref)
    $snapshot = Read-R8H5EvaluationJson $snapshotPath
    foreach ($item in @(Test-R8H5JsonSchemaValue (Join-Path $script:R8H5EvaluationProjectRoot 'templates/schema/r8/h5/h5-arm-input.v0.2.schema.json') $armInput)) {
      $failed.Add("arm_input_schema:$item")
    }
    foreach ($item in @(Test-R8H5JsonSchemaValue (Join-Path $script:R8H5EvaluationProjectRoot 'templates/schema/r8/h5/h5-dependency-snapshot.v0.2.schema.json') $snapshot)) {
      $failed.Add("dependency_snapshot_schema:$item")
    }
    $typedInputPath = Resolve-R8H5EvaluationPath $EvaluationRoot ([string]$armInput.typed_input_relative_path)
    $typedInput = Read-R8H5EvaluationJson $typedInputPath
    if ((Get-R8H5ObjectDigest $typedInput) -ne $armInput.input_digest) { $failed.Add('typed_input_current_digest_mismatch') }
    $closureLines = @($snapshot.files | Sort-Object relative_path | ForEach-Object { "$($_.relative_path)|$($_.role)|$($_.sha256)" })
    if ((Get-R8H5TextDigest ([string]::Join("`n",$closureLines))) -ne $snapshot.closure_digest) {
      $failed.Add('dependency_snapshot_current_digest_mismatch')
    }
    if ($armInput.input_digest -ne $ArmResult.input_digest) { $failed.Add('arm_input_digest_mismatch') }
    if ($snapshot.closure_digest -ne $ArmResult.snapshot_digest) { $failed.Add('arm_snapshot_digest_mismatch') }
    if ($armInput.semantic_case_digest -ne $SemanticCase.semantic_case_digest) { $failed.Add('arm_semantic_case_digest_mismatch') }
    if ($armInput.arm_role -ne $ArmResult.arm_role -or $snapshot.arm_role -ne $ArmResult.arm_role) { $failed.Add('arm_role_binding_mismatch') }
  } catch {
    $failed.Add("arm_input_or_snapshot_unreadable:$($_.Exception.Message)")
  }

  if ($ArmResult.manual_assist_observation -eq 'not_observable' -and $null -ne $ArmResult.manual_assist_count) {
    $failed.Add('manual_assist_false_observation')
  }
  if ($ArmResult.manual_assist_observation -eq 'observed' -and $null -eq $ArmResult.manual_assist_count) {
    $failed.Add('manual_assist_count_missing')
  }
  if ($ArmResult.token_observation -eq 'not_observable' -and $null -ne $ArmResult.input_tokens) {
    $failed.Add('token_false_observation')
  }
  if ($ArmResult.token_observation -eq 'observed' -and $null -eq $ArmResult.input_tokens) {
    $failed.Add('token_count_missing')
  }

  $policy = Get-R8H5EvaluationPolicy $ArmResult.skill_id $ArmResult.arm_role
  $produced = $ArmResult.result_status -eq 'produced_business_artifact'
  if ($produced) {
    if ($null -eq $ArmResult.business_artifact_ref) {
      $failed.Add('produced_business_artifact_ref_missing')
    } else {
      if ($ArmResult.business_artifact_ref.artifact_type -ne $policy.primary_output_artifact_type) {
        $failed.Add('primary_output_type_mismatch')
      }
      try {
        $artifactPath = Resolve-R8H5EvaluationPath $EvaluationRoot ([string]$ArmResult.business_artifact_ref.relative_path)
        if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
          $failed.Add('business_artifact_missing')
        } else {
          $actualDigest = 'sha256:' + (Get-TaogeFileSha256 $artifactPath)
          if ($actualDigest -ne $ArmResult.business_artifact_ref.sha256 -or $actualDigest -ne $ArmResult.output_digest) {
            $failed.Add('business_artifact_digest_mismatch')
          }
          $payload = Read-R8H5EvaluationJson $artifactPath
          $outputSchemaPath = Join-Path $script:R8H5EvaluationProjectRoot ($policy.output_schema_ref -replace '/', [System.IO.Path]::DirectorySeparatorChar)
          if (@(Test-R8H5JsonSchemaValue $outputSchemaPath $payload).Count -gt 0) { $failed.Add('business_output_schema_fail') }
          $artifactIdField = [string]$policy.artifact_id_field
          if ([string]$payload.$artifactIdField -ne [string]$ArmResult.business_artifact_ref.artifact_id) {
            $failed.Add('business_artifact_id_mismatch')
          }
        }
      } catch {
        $failed.Add("business_artifact_unreadable:$($_.Exception.Message)")
      }
    }
    if ($ArmResult.business_output_schema_gate -ne 'pass') { $failed.Add('produced_schema_gate_not_pass') }
    if ($ArmResult.contract_selection_result -ne 'pass') { $failed.Add('produced_contract_selection_not_pass') }
  } else {
    if ($null -ne $ArmResult.business_artifact_ref) { $failed.Add('nonproduced_business_artifact_ref_present') }
    if ($ArmResult.result_status -in @('waiting_valid','blocked_valid')) {
      if ($ArmResult.business_output_schema_gate -ne 'not_applicable') { $failed.Add('valid_nonproduced_schema_gate_invalid') }
      if ($ArmResult.contract_selection_result -ne 'pass') { $failed.Add('valid_nonproduced_contract_selection_invalid') }
    }
  }

  $status = if ($failed.Count -gt 0 -or $ArmResult.result_status -eq 'invalid_output') {
    'fail'
  } elseif ($ArmResult.result_status -in @('invalid_input','execution_error') -or $ArmResult.contract_selection_result -eq 'invalid') {
    'invalid'
  } else {
    'pass'
  }
  return [pscustomobject][ordered]@{
    status = $status
    failed_check_ids = @($failed)
    arm_input = $armInput
    snapshot = $snapshot
  }
}

function Test-R8H5HotspotSharedSemantics {
  param([object]$SemanticCase,[object]$Payload)
  $errors = [System.Collections.Generic.List[string]]::new()
  $request = $SemanticCase.semantic_input.request_context
  foreach ($binding in @(
    @('account_identity_ref','account_identity_ref'),
    @('account_snapshot_ref','account_snapshot_ref'),
    @('radar_policy_ref','radar_policy_ref')
  )) {
    $expected = $request.($binding[0])
    $actual = $Payload.($binding[1])
    if ((ConvertTo-R8H5CanonicalJson $expected) -ne (ConvertTo-R8H5CanonicalJson $actual)) {
      $errors.Add("hotspot_binding_mismatch:$($binding[0])")
    }
  }
  if ($Payload.research_request_ref.artifact_id -ne $request.research_request_id) { $errors.Add('hotspot_request_id_mismatch') }
  if ($Payload.research_set_status -eq 'ready_for_panel' -and @($Payload.topic_options).Count -lt 1) {
    $errors.Add('hotspot_ready_for_panel_without_topic')
  }
  if ($Payload.research_set_status -eq 'ready_no_recommendation' -and @($Payload.topic_options).Count -ne 0) {
    $errors.Add('hotspot_no_recommendation_with_topic')
  }
  foreach ($topic in @($Payload.topic_options)) {
    if ($null -eq $topic.PSObject.Properties['used_vehicle_direct_relevance'] -or $topic.used_vehicle_direct_relevance -ne $true) {
      $errors.Add('hotspot_used_vehicle_direct_relevance_missing')
    }
  }
  return @($errors)
}

function Test-R8H5RouterSharedSemantics {
  param([object]$SemanticCase,[object]$Payload,[object]$ArmResult)
  $errors = [System.Collections.Generic.List[string]]::new()
  if ($Payload.intent -ne $SemanticCase.semantic_input.entry_router_request.intent) { $errors.Add('router_intent_mismatch') }
  if ($null -ne $Payload.executed_node_id -or $null -ne $ArmResult.executed_node_id) { $errors.Add('router_executed_node_forbidden') }
  if ($Payload.selected_node_id -ne $ArmResult.selected_node_id) { $errors.Add('router_selected_node_binding_mismatch') }
  if ($Payload.decision_status -eq 'selected') {
    if ([string]::IsNullOrWhiteSpace([string]$Payload.selected_node_id) -or
        $Payload.selected_node_id -notin @($SemanticCase.semantic_input.active_workflow_plan.allowed_next_nodes)) {
      $errors.Add('router_selected_node_not_allowed')
    }
  } elseif ($null -ne $Payload.selected_node_id) {
    $errors.Add('router_nonselected_status_has_node')
  }
  return @($errors)
}

function Test-R8H5PlatformSharedSemantics {
  param([object]$SemanticCase,[object]$Payload)
  $errors = [System.Collections.Generic.List[string]]::new()
  $expected = @($SemanticCase.semantic_input.target_platforms | Sort-Object)
  $actual = @($Payload.packages.platform | Sort-Object)
  if ($actual.Count -ne @($actual | Select-Object -Unique).Count -or
      [string]::Join('|',$actual) -ne [string]::Join('|',$expected)) {
    $errors.Add('platform_target_set_mismatch')
  }
  if ($Payload.primary_platform -notin $expected) { $errors.Add('platform_primary_not_selected') }
  foreach ($package in @($Payload.packages)) {
    if ($package.body_text -ne $SemanticCase.semantic_input.draft.body_text) { $errors.Add('platform_approved_body_changed') }
  }
  return @($errors)
}

function Get-R8H5SharedInvariantCheck {
  param([string]$EvaluationRoot,[object]$SemanticCase,[object]$BaselineResult,[object]$CandidateResult,[object]$BaselineContract,[object]$CandidateContract)
  $failed = [System.Collections.Generic.List[string]]::new()
  foreach ($item in @(Test-R8H5JsonSchemaValue (Join-Path $script:R8H5EvaluationProjectRoot 'templates/schema/r8/h5/h5-semantic-case.v0.2.schema.json') $SemanticCase)) {
    $failed.Add("semantic_case_schema:$item")
  }
  $semanticDigestBody = [pscustomobject][ordered]@{
    skill_id = $SemanticCase.skill_id
    case_class = $SemanticCase.case_class
    prompt_text = $SemanticCase.prompt_text
    semantic_input = $SemanticCase.semantic_input
    shared_outcome_invariants = @($SemanticCase.shared_outcome_invariants)
    expected_primary_output_type = $SemanticCase.expected_primary_output_type
  }
  if ((Get-R8H5ObjectDigest $semanticDigestBody) -ne $SemanticCase.semantic_case_digest) {
    $failed.Add('semantic_case_current_digest_mismatch')
  }
  if ($BaselineContract.arm_input.semantic_case_digest -ne $CandidateContract.arm_input.semantic_case_digest -or
      $BaselineContract.arm_input.semantic_case_digest -ne $SemanticCase.semantic_case_digest) {
    $failed.Add('cross_arm_semantic_digest_mismatch')
  }
  if ($SemanticCase.case_class -eq 'rejection') {
    foreach ($result in @($BaselineResult,$CandidateResult)) {
      if ($result.result_status -eq 'produced_business_artifact' -or $null -ne $result.business_artifact_ref) {
        $failed.Add('rejection_produced_business_artifact')
      }
      if ($null -ne $result.selected_node_id -or $null -ne $result.executed_node_id) {
        $failed.Add('rejection_has_selected_or_executed_node')
      }
    }
  }
  foreach ($result in @($BaselineResult,$CandidateResult)) {
    if ($result.result_status -ne 'produced_business_artifact') { continue }
    if ($result.business_artifact_ref.artifact_type -ne $SemanticCase.expected_primary_output_type) {
      $failed.Add("$($result.arm_role)_expected_primary_output_type_mismatch")
      continue
    }
    $payloadPath = Resolve-R8H5EvaluationPath $EvaluationRoot ([string]$result.business_artifact_ref.relative_path)
    $payload = Read-R8H5EvaluationJson $payloadPath
    $semanticErrors = switch ($SemanticCase.skill_id) {
      'hotspot-topic-research' { @(Test-R8H5HotspotSharedSemantics $SemanticCase $payload) }
      'propagation-router' { @(Test-R8H5RouterSharedSemantics $SemanticCase $payload $result) }
      'platform-packaging-adapter' { @(Test-R8H5PlatformSharedSemantics $SemanticCase $payload) }
      default { @('shared_semantic_validator_missing') }
    }
    foreach ($item in $semanticErrors) { $failed.Add("$($result.arm_role):$item") }
  }
  return [pscustomobject][ordered]@{
    status = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
    failed_check_ids = @($failed)
  }
}

function New-R8H5ArmResult {
  param([string]$EvaluationRoot,[object]$Request)
  $requestSchemaPath = Join-Path $script:R8H5EvaluationProjectRoot 'templates/schema/r8/h5/requests/h5-arm-result-record-request.v0.1.schema.json'
  $requestErrors = @(Test-R8H5JsonSchemaValue $requestSchemaPath $Request)
  if ($requestErrors.Count -gt 0) { throw "arm_result_record_request_invalid:$($requestErrors -join ',')" }
  Assert-R8H5Timestamp 'result_recorded_at' ([string]$Request.result_recorded_at)
  if ($Request.manual_assist_observation -eq 'not_observable' -and $null -ne $Request.manual_assist_count) {
    throw 'arm_result_request_manual_assist_false_observation'
  }
  if ($Request.manual_assist_observation -eq 'observed' -and $null -eq $Request.manual_assist_count) {
    throw 'arm_result_request_manual_assist_count_missing'
  }
  if ($Request.token_observation -eq 'not_observable' -and $null -ne $Request.input_tokens) {
    throw 'arm_result_request_token_false_observation'
  }
  if ($Request.token_observation -eq 'observed' -and $null -eq $Request.input_tokens) {
    throw 'arm_result_request_token_count_missing'
  }
  $armInputPath = Resolve-R8H5EvaluationPath $EvaluationRoot ([string]$Request.arm_input_ref)
  $armInput = Read-R8H5EvaluationJson $armInputPath
  if ($armInput.semantic_case_id -ne $Request.semantic_case_id -or $armInput.arm_role -ne $Request.arm_role -or
      $armInput.skill_id -ne $Request.skill_id -or $armInput.input_status -ne 'ready') {
    throw 'arm_result_request_arm_input_binding_invalid'
  }
  $snapshotPath = Resolve-R8H5EvaluationPath $EvaluationRoot ([string]$armInput.dependency_snapshot_ref)
  $snapshot = Read-R8H5EvaluationJson $snapshotPath
  $policy = Get-R8H5EvaluationPolicy $Request.skill_id $Request.arm_role
  $reportedStatus = [string]$Request.reported_result_status
  $finalStatus = $reportedStatus
  $schemaGate = 'not_applicable'
  $contractResult = if ($reportedStatus -in @('waiting_valid','blocked_valid')) { 'pass' } else { 'invalid' }
  $outputDigest = $null
  $artifactRef = $null
  $hasOutputPath = -not [string]::IsNullOrWhiteSpace([string]$Request.business_output_relative_path)
  if ($reportedStatus -eq 'produced_business_artifact') {
    if (-not $hasOutputPath) {
      $finalStatus = 'invalid_output'
      $schemaGate = 'fail'
      $contractResult = 'fail'
    } else {
      $outputPath = Resolve-R8H5EvaluationPath $EvaluationRoot ([string]$Request.business_output_relative_path)
      if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        $finalStatus = 'invalid_output'
        $schemaGate = 'fail'
        $contractResult = 'fail'
      } else {
        $outputDigest = 'sha256:' + (Get-TaogeFileSha256 $outputPath)
        $payload = Read-R8H5EvaluationJson $outputPath
        $schemaPath = Join-Path $script:R8H5EvaluationProjectRoot ($policy.output_schema_ref -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        $schemaErrors = @(Test-R8H5JsonSchemaValue $schemaPath $payload)
        $idField = [string]$policy.artifact_id_field
        if ($schemaErrors.Count -gt 0 -or [string]::IsNullOrWhiteSpace([string]$payload.$idField)) {
          $finalStatus = 'invalid_output'
          $schemaGate = 'fail'
          $contractResult = 'fail'
        } else {
          $schemaGate = 'pass'
          $contractResult = 'pass'
          $artifactRef = [pscustomobject][ordered]@{
            artifact_type = [string]$policy.primary_output_artifact_type
            artifact_id = [string]$payload.$idField
            relative_path = [string]$Request.business_output_relative_path
            sha256 = $outputDigest
          }
        }
      }
    }
  } elseif ($hasOutputPath) {
    $outputPath = Resolve-R8H5EvaluationPath $EvaluationRoot ([string]$Request.business_output_relative_path)
    if (Test-Path -LiteralPath $outputPath -PathType Leaf) { $outputDigest = 'sha256:' + (Get-TaogeFileSha256 $outputPath) }
    $finalStatus = 'invalid_output'
    $schemaGate = 'fail'
    $contractResult = 'fail'
  } elseif ($reportedStatus -eq 'invalid_output') {
    $schemaGate = 'fail'
    $contractResult = 'fail'
  }
  return [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r8/h5/h5-arm-result/v0.2'
    schema_version = '0.2'
    arm_result_id = "ARM-RESULT-$($Request.semantic_case_id)-$($Request.arm_role)"
    evaluation_id = $armInput.evaluation_id
    attempt_id = $armInput.attempt_id
    semantic_case_id = $Request.semantic_case_id
    arm_role = $Request.arm_role
    skill_id = $Request.skill_id
    arm_input_ref = $Request.arm_input_ref
    dependency_snapshot_ref = $armInput.dependency_snapshot_ref
    prompt_digest = $Request.prompt_digest
    input_digest = $armInput.input_digest
    snapshot_digest = $snapshot.closure_digest
    output_digest = $outputDigest
    result_status = $finalStatus
    requested_node_id = $Request.requested_node_id
    selected_node_id = $Request.selected_node_id
    executed_node_id = $Request.executed_node_id
    reference_load_observation = $Request.reference_load_observation
    loaded_reference_ids = @($Request.loaded_reference_ids)
    manual_assist_observation = $Request.manual_assist_observation
    manual_assist_count = $Request.manual_assist_count
    duration_ms = $Request.duration_ms
    token_observation = $Request.token_observation
    input_tokens = $Request.input_tokens
    business_artifact_ref = $artifactRef
    business_output_schema_gate = $schemaGate
    contract_selection_result = $contractResult
    result_recorded_at = $Request.result_recorded_at
    supersedes = $Request.supersedes
  }
}

function New-R8H5MachineVerdict {
  param([string]$EvaluationRoot,[object]$SemanticCase,[object]$BaselineResult,[object]$CandidateResult,[string]$EvaluatedAt)
  Assert-R8H5Timestamp 'evaluated_at' $EvaluatedAt
  $baseline = Get-R8H5ArmResultContractCheck $EvaluationRoot $SemanticCase $BaselineResult
  $candidate = Get-R8H5ArmResultContractCheck $EvaluationRoot $SemanticCase $CandidateResult
  $shared = Get-R8H5SharedInvariantCheck $EvaluationRoot $SemanticCase $BaselineResult $CandidateResult $baseline $candidate
  $verdictStatus = if ($baseline.status -eq 'invalid' -or $candidate.status -eq 'invalid') {
    'invalid'
  } elseif ($baseline.status -eq 'pass' -and $candidate.status -eq 'pass' -and $shared.status -eq 'pass') {
    'pass'
  } else {
    'fail'
  }
  return [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r8/h5/h5-machine-verdict/v0.2'
    schema_version = '0.2'
    machine_verdict_id = "MACHINE-VERDICT-$($SemanticCase.semantic_case_id)"
    evaluation_id = $SemanticCase.evaluation_id
    attempt_id = $SemanticCase.attempt_id
    semantic_case_id = $SemanticCase.semantic_case_id
    baseline_arm_result_ref = "cases/$($SemanticCase.semantic_case_id)/baseline/arm-result.json"
    candidate_arm_result_ref = "cases/$($SemanticCase.semantic_case_id)/candidate/arm-result.json"
    baseline_contract_result = $baseline.status
    candidate_contract_result = $candidate.status
    shared_invariant_result = $shared.status
    baseline_failed_check_ids = @($baseline.failed_check_ids)
    candidate_failed_check_ids = @($candidate.failed_check_ids)
    shared_failed_check_ids = @($shared.failed_check_ids)
    verdict_status = $verdictStatus
    evaluated_at = $EvaluatedAt
    supersedes = $null
  }
}

function New-R8H5ComparabilityVerdict {
  param(
    [object]$SemanticCase,[object]$BaselineResult,[object]$CandidateResult,
    [object]$MachineVerdict,[int]$ComparablePairCountForSkill,[string]$DecidedAt
  )
  Assert-R8H5Timestamp 'decided_at' $DecidedAt
  $baselineType = if ($null -eq $BaselineResult.business_artifact_ref) { $null } else { [string]$BaselineResult.business_artifact_ref.artifact_type }
  $candidateType = if ($null -eq $CandidateResult.business_artifact_ref) { $null } else { [string]$CandidateResult.business_artifact_ref.artifact_type }
  $baselineProduced = $BaselineResult.result_status -eq 'produced_business_artifact'
  $candidateProduced = $CandidateResult.result_status -eq 'produced_business_artifact'
  if ($MachineVerdict.verdict_status -ne 'pass') {
    $status = 'invalid'
    $reasons = @('machine_verdict_not_pass')
    $blindAllowed = $false
  } elseif ($SemanticCase.case_class -eq 'rejection') {
    $status = 'behavior_only'
    $reasons = @('rejection_case_machine_behavior_only')
    $blindAllowed = $false
  } elseif ($baselineProduced -and $candidateProduced -and
      -not [string]::IsNullOrWhiteSpace($baselineType) -and $baselineType -eq $candidateType -and
      $baselineType -eq $SemanticCase.expected_primary_output_type) {
    $status = 'comparable'
    $reasons = @('both_schema_valid_same_primary_output_type')
    $blindAllowed = $true
  } elseif ($baselineProduced -xor $candidateProduced) {
    $status = 'regression_disposition'
    $reasons = @('one_arm_produced_one_arm_nonproduced')
    $blindAllowed = $false
  } elseif ($ComparablePairCountForSkill -lt 1 -and $SemanticCase.case_class -eq 'normal') {
    $status = 'insufficient_comparable_samples'
    $reasons = @('skill_has_no_comparable_normal_pair')
    $blindAllowed = $false
  } else {
    $status = 'behavior_only'
    $reasons = @('valid_nonproduced_or_waiting_behavior')
    $blindAllowed = $false
  }
  return [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r8/h5/h5-comparability-verdict/v0.2'
    schema_version = '0.2'
    comparability_verdict_id = "COMPARABILITY-$($SemanticCase.semantic_case_id)"
    evaluation_id = $SemanticCase.evaluation_id
    attempt_id = $SemanticCase.attempt_id
    semantic_case_id = $SemanticCase.semantic_case_id
    machine_verdict_ref = "cases/$($SemanticCase.semantic_case_id)/machine-verdict.json"
    baseline_arm_result_ref = "cases/$($SemanticCase.semantic_case_id)/baseline/arm-result.json"
    candidate_arm_result_ref = "cases/$($SemanticCase.semantic_case_id)/candidate/arm-result.json"
    comparability_status = $status
    baseline_primary_output_type = $baselineType
    candidate_primary_output_type = $candidateType
    reason_codes = @($reasons)
    blind_pair_allowed = $blindAllowed
    decided_at = $DecidedAt
    supersedes = $null
  }
}
