. (Join-Path $PSScriptRoot 'R8H5EvaluationRuntime.ps1')

function Initialize-R8H5BlindRuntime {
  param([string]$ProjectRoot)
  Initialize-R8H5EvaluationRuntime $ProjectRoot
}

function Write-R8H5ImmutableText {
  param([string]$Path,[string]$Text)
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    $existing = [System.IO.File]::ReadAllText($Path,(Get-TaogeUtf8NoBomEncoding))
    if ($existing -ne $Text) { throw "immutable_conflict:$Path" }
    return 'byte_stable_skip'
  }
  Write-TaogeUtf8NoBomText -Path $Path -Text $Text
  return 'created'
}

function Assert-R8H5Schema {
  param([string]$SchemaRelativePath,[object]$Value,[string]$ErrorPrefix)
  $schemaPath = Join-Path $script:R8H5EvaluationProjectRoot ($SchemaRelativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
  $errors = @(Test-R8H5JsonSchemaValue $schemaPath $Value)
  if ($errors.Count -gt 0) { throw "${ErrorPrefix}:$($errors -join ',')" }
}

function New-R8H5ArmExecutionTask {
  param(
    [string]$EvaluationRoot,[object]$SemanticCase,[string]$ArmRole,
    [string]$PreparedAt
  )
  Assert-R8H5Timestamp 'prepared_at' $PreparedAt
  $caseId = [string]$SemanticCase.semantic_case_id
  $armRootRelative = "cases/$caseId/$ArmRole"
  $armInput = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $EvaluationRoot "$armRootRelative/arm-input.json")
  $typedInput = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $EvaluationRoot "$armRootRelative/typed-input.json")
  $snapshot = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $EvaluationRoot "$armRootRelative/dependency-snapshot.json")
  Assert-R8H5Schema 'templates/schema/r8/h5/h5-semantic-case.v0.2.schema.json' $SemanticCase 'semantic_case_invalid'
  Assert-R8H5Schema 'templates/schema/r8/h5/h5-arm-input.v0.2.schema.json' $armInput 'arm_input_invalid'
  Assert-R8H5Schema 'templates/schema/r8/h5/h5-dependency-snapshot.v0.2.schema.json' $snapshot 'dependency_snapshot_invalid'
  if ($armInput.input_status -ne 'ready' -or $snapshot.snapshot_status -ne 'ready' -or
      $armInput.semantic_case_digest -ne $SemanticCase.semantic_case_digest -or
      $armInput.dependency_snapshot_digest -ne $snapshot.closure_digest -or
      $armInput.input_digest -ne (Get-R8H5ObjectDigest $typedInput)) {
    throw "arm_preflight_binding_invalid:${caseId}:${ArmRole}"
  }

  $sealedRootRelative = "$armRootRelative/sealed-context"
  foreach ($file in @($snapshot.files)) {
    $content = Get-R8H5GitText $script:R8H5EvaluationProjectRoot ([string]$snapshot.source_commit) ([string]$file.relative_path)
    if ((Get-R8H5TextDigest $content) -ne [string]$file.sha256) {
      throw "sealed_context_digest_mismatch:${caseId}:${ArmRole}:$($file.relative_path)"
    }
    $target = Resolve-R8H5EvaluationPath $EvaluationRoot "$sealedRootRelative/$($file.relative_path)"
    [void](Write-R8H5ImmutableText $target $content)
  }

  $policy = Get-R8H5EvaluationPolicy ([string]$SemanticCase.skill_id) $ArmRole
  $businessSchemaSource = Join-Path $script:R8H5EvaluationProjectRoot ([string]$policy.output_schema_ref -replace '/', [System.IO.Path]::DirectorySeparatorChar)
  $businessSchemaText = [System.IO.File]::ReadAllText($businessSchemaSource,(Get-TaogeUtf8NoBomEncoding))
  $businessSchemaRef = "$armRootRelative/evaluation-contract/business-output.schema.json"
  [void](Write-R8H5ImmutableText (Resolve-R8H5EvaluationPath $EvaluationRoot $businessSchemaRef) $businessSchemaText)
  $submissionSchemaSource = Join-Path $script:R8H5EvaluationProjectRoot 'templates/schema/r8/h5/requests/h5-arm-execution-submission.v0.1.schema.json'
  $submissionSchemaText = [System.IO.File]::ReadAllText($submissionSchemaSource,(Get-TaogeUtf8NoBomEncoding))
  $submissionSchemaRef = "$armRootRelative/evaluation-contract/arm-execution-submission.schema.json"
  [void](Write-R8H5ImmutableText (Resolve-R8H5EvaluationPath $EvaluationRoot $submissionSchemaRef) $submissionSchemaText)
  $task = [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r8/h5/requests/h5-arm-execution-task/v0.1'
    schema_version = '0.1'
    evaluation_id = $SemanticCase.evaluation_id
    attempt_id = $SemanticCase.attempt_id
    semantic_case_id = $caseId
    arm_role = $ArmRole
    skill_id = $SemanticCase.skill_id
    prompt_text = $SemanticCase.prompt_text
    prompt_digest = Get-R8H5TextDigest ([string]$SemanticCase.prompt_text)
    arm_input_ref = "$armRootRelative/arm-input.json"
    typed_input_ref = "$armRootRelative/typed-input.json"
    dependency_snapshot_ref = "$armRootRelative/dependency-snapshot.json"
    sealed_context_root = $sealedRootRelative
    business_output_relative_path = "$armRootRelative/business-output.json"
    business_output_schema_ref = $businessSchemaRef
    business_output_schema_digest = Get-R8H5TextDigest $businessSchemaText
    submission_relative_path = "$armRootRelative/arm-execution-submission.json"
    submission_schema_ref = $submissionSchemaRef
    submission_schema_digest = Get-R8H5TextDigest $submissionSchemaText
    allowed_result_statuses = @(
      'produced_business_artifact','waiting_valid','blocked_valid',
      'execution_error','invalid_input','invalid_output'
    )
    isolation_level = 'instruction_isolated'
    prepared_at = $PreparedAt
  }
  Assert-R8H5Schema 'templates/schema/r8/h5/requests/h5-arm-execution-task.v0.1.schema.json' $task 'arm_task_invalid'
  [void](Write-R8H5ImmutableJson (Resolve-R8H5EvaluationPath $EvaluationRoot "$armRootRelative/arm-task.json") $task)
  return $task
}

function ConvertTo-R8H5RecordRequest {
  param(
    [string]$EvaluationRoot,[object]$Task,[object]$Submission,
    [int]$ManualAssistCount
  )
  Assert-R8H5Schema 'templates/schema/r8/h5/requests/h5-arm-execution-task.v0.1.schema.json' $Task 'arm_task_invalid'
  Assert-R8H5Schema 'templates/schema/r8/h5/requests/h5-arm-execution-submission.v0.1.schema.json' $Submission 'arm_submission_invalid'
  foreach ($name in @('evaluation_id','attempt_id','semantic_case_id','arm_role','skill_id','arm_input_ref','prompt_digest')) {
    if ([string]$Task.$name -ne [string]$Submission.$name) { throw "arm_submission_task_binding_mismatch:$name" }
  }
  $businessSchemaPath = Resolve-R8H5EvaluationPath $EvaluationRoot ([string]$Task.business_output_schema_ref)
  $submissionSchemaPath = Resolve-R8H5EvaluationPath $EvaluationRoot ([string]$Task.submission_schema_ref)
  if ((Get-R8H5TextDigest ([System.IO.File]::ReadAllText($businessSchemaPath,(Get-TaogeUtf8NoBomEncoding)))) -ne $Task.business_output_schema_digest) {
    throw 'arm_task_business_schema_digest_mismatch'
  }
  if ((Get-R8H5TextDigest ([System.IO.File]::ReadAllText($submissionSchemaPath,(Get-TaogeUtf8NoBomEncoding)))) -ne $Task.submission_schema_digest) {
    throw 'arm_task_submission_schema_digest_mismatch'
  }
  if ($Submission.reported_result_status -notin @($Task.allowed_result_statuses)) {
    throw 'arm_submission_status_not_allowed'
  }
  if ($Submission.token_observation -eq 'not_observable' -and $null -ne $Submission.input_tokens) {
    throw 'arm_submission_token_false_observation'
  }
  if ($Submission.token_observation -eq 'observed' -and $null -eq $Submission.input_tokens) {
    throw 'arm_submission_token_count_missing'
  }
  $produced = $Submission.reported_result_status -eq 'produced_business_artifact'
  if ($produced -and [string]$Submission.business_output_relative_path -ne [string]$Task.business_output_relative_path) {
    throw 'arm_submission_business_output_path_mismatch'
  }
  if (-not $produced -and $null -ne $Submission.business_output_relative_path) {
    throw 'arm_submission_nonproduced_output_forbidden'
  }
  return [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r8/h5/requests/h5-arm-result-record-request/v0.1'
    schema_version = '0.1'
    semantic_case_id = $Submission.semantic_case_id
    arm_role = $Submission.arm_role
    skill_id = $Submission.skill_id
    arm_input_ref = $Submission.arm_input_ref
    prompt_digest = $Submission.prompt_digest
    reported_result_status = $Submission.reported_result_status
    requested_node_id = $Submission.requested_node_id
    selected_node_id = $Submission.selected_node_id
    executed_node_id = $Submission.executed_node_id
    reference_load_observation = $Submission.reference_load_observation
    loaded_reference_ids = @($Submission.loaded_reference_ids)
    manual_assist_observation = 'observed'
    manual_assist_count = $ManualAssistCount
    duration_ms = $Submission.duration_ms
    token_observation = $Submission.token_observation
    input_tokens = $Submission.input_tokens
    business_output_relative_path = $Submission.business_output_relative_path
    result_recorded_at = $Submission.submitted_at
    supersedes = $Submission.supersedes
  }
}

function ConvertTo-R8H5BlindProjectionValue {
  param([object]$Value)
  if ($null -eq $Value) { return $null }
  # PowerShell may wrap scalar pipeline values in PSObject metadata. Resolve
  # scalar types before the generic PSObject branch so strings remain strings
  # instead of being projected as {"Length": n}.
  if ($Value -is [string] -or
      $Value -is [bool] -or
      $Value -is [byte] -or
      $Value -is [sbyte] -or
      $Value -is [int16] -or
      $Value -is [uint16] -or
      $Value -is [int32] -or
      $Value -is [uint32] -or
      $Value -is [int64] -or
      $Value -is [uint64] -or
      $Value -is [single] -or
      $Value -is [double] -or
      $Value -is [decimal]) {
    return $Value
  }
  if ($Value -is [System.Array]) {
    $converted = [object[]]::new($Value.Count)
    for ($index = 0; $index -lt $Value.Count; $index++) {
      $converted[$index] = ConvertTo-R8H5BlindProjectionValue $Value[$index]
    }
    # The unary comma prevents PowerShell from collapsing empty and one-item
    # arrays when returning through the success pipeline.
    return ,$converted
  }
  if ($Value -is [pscustomobject] -or $Value -is [System.Collections.IDictionary]) {
    $result = [ordered]@{}
    $properties = if ($Value -is [System.Collections.IDictionary]) {
      @($Value.Keys | ForEach-Object { [pscustomobject]@{Name=[string]$_; Value=$Value[$_]} })
    } else {
      @($Value.PSObject.Properties)
    }
    foreach ($property in $properties) {
      $name = [string]$property.Name
      if ($name -match '(^schema_|_id$|_ref$|_refs$|sha256|digest|revision$|^next_skill$)') { continue }
      $result[$name] = ConvertTo-R8H5BlindProjectionValue $property.Value
    }
    return [pscustomobject]$result
  }
  return $Value
}

function Assert-R8H5BlindProjectionTopology {
  param([object]$Source,[object]$Projection,[string]$Path = '$')
  if ($null -eq $Source) {
    if ($null -ne $Projection) { throw "blind_projection_topology_mismatch:${Path}:null" }
    return
  }
  if ($Source -is [System.Array]) {
    if ($Projection -isnot [System.Array]) { throw "blind_projection_topology_mismatch:${Path}:array" }
    if ($Source.Count -ne $Projection.Count) { throw "blind_projection_array_count_mismatch:$Path" }
    for ($index = 0; $index -lt $Source.Count; $index++) {
      Assert-R8H5BlindProjectionTopology $Source[$index] $Projection[$index] "$Path[$index]"
    }
    return
  }
  if ($Source -is [string] -or $Source -is [ValueType]) {
    if ($Source -is [string] -and $Projection -isnot [string]) {
      throw "blind_projection_topology_mismatch:${Path}:string"
    }
    if ($Source -is [ValueType] -and $Projection -isnot [ValueType]) {
      throw "blind_projection_topology_mismatch:${Path}:value"
    }
    return
  }
  if ($Source -is [pscustomobject] -or $Source -is [System.Collections.IDictionary]) {
    if ($Projection -isnot [pscustomobject] -and $Projection -isnot [System.Collections.IDictionary]) {
      throw "blind_projection_topology_mismatch:${Path}:object"
    }
    $sourceProperties = if ($Source -is [System.Collections.IDictionary]) {
      @($Source.Keys | ForEach-Object { [pscustomobject]@{Name=[string]$_; Value=$Source[$_]} })
    } else {
      @($Source.PSObject.Properties)
    }
    foreach ($property in $sourceProperties) {
      $name = [string]$property.Name
      if ($name -match '(^schema_|_id$|_ref$|_refs$|sha256|digest|revision$|^next_skill$)') { continue }
      $projectionProperty = $Projection.PSObject.Properties[$name]
      if ($null -eq $projectionProperty) { throw "blind_projection_property_missing:$Path.$name" }
      Assert-R8H5BlindProjectionTopology $property.Value $projectionProperty.Value "$Path.$name"
    }
  }
}

function Get-R8H5BlindPresentation {
  param([string]$EvaluationRoot,[object]$ArmResult)
  $artifactPath = Resolve-R8H5EvaluationPath $EvaluationRoot ([string]$ArmResult.business_artifact_ref.relative_path)
  $payload = Read-R8H5EvaluationJson $artifactPath
  $projection = ConvertTo-R8H5BlindProjectionValue $payload
  Assert-R8H5BlindProjectionTopology $payload $projection
  $presentation = $projection | ConvertTo-Json -Depth 40
  if ($presentation -match '(?i)"arm_role"\s*:|"source_commit"\s*:|"dependency_snapshot"\s*:|\b(baseline|candidate)\b') {
    throw 'blind_projection_identity_leak'
  }
  return $presentation
}

function New-R8H5BlindPair {
  param(
    [string]$EvaluationRoot,[object]$SemanticCase,[object]$MachineVerdict,
    [object]$Comparability,[object]$BaselineResult,[object]$CandidateResult,
    [string]$GeneratedAt
  )
  Assert-R8H5Timestamp 'generated_at' $GeneratedAt
  Assert-R8H5Schema 'templates/schema/r8/h5/h5-machine-verdict.v0.2.schema.json' $MachineVerdict 'machine_verdict_invalid'
  Assert-R8H5Schema 'templates/schema/r8/h5/h5-comparability-verdict.v0.2.schema.json' $Comparability 'comparability_invalid'
  if ($MachineVerdict.verdict_status -ne 'pass' -or
      $Comparability.comparability_status -ne 'comparable' -or
      $Comparability.blind_pair_allowed -ne $true) {
    throw 'blind_pair_precondition_not_met'
  }
  foreach ($result in @($BaselineResult,$CandidateResult)) {
    $check = Get-R8H5ArmResultContractCheck $EvaluationRoot $SemanticCase $result
    if ($check.status -ne 'pass' -or $result.result_status -ne 'produced_business_artifact') {
      throw "blind_pair_arm_not_current_valid:$($result.arm_role)"
    }
  }

  $caseId = [string]$SemanticCase.semantic_case_id
  $pairRef = "cases/$caseId/blind-pair.json"
  $allocationRef = "private/$caseId/allocation-record.json"
  $allocationPath = Resolve-R8H5EvaluationPath $EvaluationRoot $allocationRef
  if (Test-Path -LiteralPath $allocationPath -PathType Leaf) {
    $allocation = Read-R8H5EvaluationJson $allocationPath
    Assert-R8H5Schema 'templates/schema/r8/h5/h5-blind-allocation-record.v0.1.schema.json' $allocation 'allocation_record_invalid'
    $commitmentBody = [pscustomobject][ordered]@{
      evaluation_id = $allocation.evaluation_id
      attempt_id = $allocation.attempt_id
      semantic_case_id = $allocation.semantic_case_id
      a_arm_role = $allocation.a_arm_role
      b_arm_role = $allocation.b_arm_role
      nonce = $allocation.nonce
    }
    if ($allocation.evaluation_id -ne $SemanticCase.evaluation_id -or
        $allocation.attempt_id -ne $SemanticCase.attempt_id -or
        $allocation.semantic_case_id -ne $caseId -or
        $allocation.blind_pair_ref -ne $pairRef -or
        $allocation.a_arm_role -eq $allocation.b_arm_role -or
        (Get-R8H5ObjectDigest $commitmentBody) -ne $allocation.allocation_commitment_digest) {
      throw 'allocation_record_binding_or_commitment_invalid'
    }
  } else {
    $bytes = New-Object byte[] 16
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    $nonce = ([System.BitConverter]::ToString($bytes) -replace '-','').ToLowerInvariant()
    $aRole = if (($bytes[0] % 2) -eq 0) { 'baseline' } else { 'candidate' }
    $bRole = if ($aRole -eq 'baseline') { 'candidate' } else { 'baseline' }
    $commitmentBody = [pscustomobject][ordered]@{
      evaluation_id = $SemanticCase.evaluation_id
      attempt_id = $SemanticCase.attempt_id
      semantic_case_id = $caseId
      a_arm_role = $aRole
      b_arm_role = $bRole
      nonce = $nonce
    }
    $allocation = [pscustomobject][ordered]@{
      schema_id = 'taoge://schemas/r8/h5/private/h5-blind-allocation-record/v0.1'
      schema_version = '0.1'
      allocation_record_id = "ALLOCATION-$caseId"
      evaluation_id = $SemanticCase.evaluation_id
      attempt_id = $SemanticCase.attempt_id
      semantic_case_id = $caseId
      blind_pair_ref = $pairRef
      a_arm_role = $aRole
      b_arm_role = $bRole
      nonce = $nonce
      allocation_commitment_digest = Get-R8H5ObjectDigest $commitmentBody
      created_at = $GeneratedAt
    }
    Assert-R8H5Schema 'templates/schema/r8/h5/h5-blind-allocation-record.v0.1.schema.json' $allocation 'allocation_record_invalid'
    [void](Write-R8H5ImmutableJson $allocationPath $allocation)
  }
  $byRole = @{ baseline=$BaselineResult; candidate=$CandidateResult }
  $aResult = $byRole[[string]$allocation.a_arm_role]
  $bResult = $byRole[[string]$allocation.b_arm_role]
  $aPresentation = Get-R8H5BlindPresentation $EvaluationRoot $aResult
  $bPresentation = Get-R8H5BlindPresentation $EvaluationRoot $bResult
  $pair = [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r8/h5/h5-blind-pair/v0.2'
    schema_version = '0.2'
    blind_pair_id = "BLIND-PAIR-$caseId"
    evaluation_id = $SemanticCase.evaluation_id
    attempt_id = $SemanticCase.attempt_id
    semantic_case_id = $caseId
    comparability_verdict_ref = "cases/$caseId/comparability-verdict.json"
    pair_status = 'ready'
    a = [pscustomobject][ordered]@{
      artifact_type = $aResult.business_artifact_ref.artifact_type
      presentation = $aPresentation
      content_digest = Get-R8H5TextDigest $aPresentation
    }
    b = [pscustomobject][ordered]@{
      artifact_type = $bResult.business_artifact_ref.artifact_type
      presentation = $bPresentation
      content_digest = Get-R8H5TextDigest $bPresentation
    }
    allocation_commitment_digest = $allocation.allocation_commitment_digest
    allocation_record_ref = $allocationRef
    created_at = $GeneratedAt
    supersedes = $null
  }
  Assert-R8H5Schema 'templates/schema/r8/h5/h5-blind-pair.v0.2.schema.json' $pair 'blind_pair_invalid'
  return $pair
}

function New-R8H5BlindReviewPacket {
  param([string]$EvaluationRoot,[string]$GeneratedAt)
  Assert-R8H5Timestamp 'generated_at' $GeneratedAt
  $compileResult = Read-R8H5EvaluationJson (Join-Path $EvaluationRoot 'input-compile-result.json')
  $pairRefs = @()
  foreach ($caseItem in @($compileResult.cases)) {
    $caseId = [string]$caseItem.semantic_case_id
    $caseRoot = Resolve-R8H5EvaluationPath $EvaluationRoot "cases/$caseId"
    $semantic = Read-R8H5EvaluationJson (Join-Path $caseRoot 'semantic-case.json')
    $machine = Read-R8H5EvaluationJson (Join-Path $caseRoot 'machine-verdict.json')
    $comparability = Read-R8H5EvaluationJson (Join-Path $caseRoot 'comparability-verdict.json')
    $pairPath = Join-Path $caseRoot 'blind-pair.json'
    if ($machine.verdict_status -eq 'pass' -and
        $comparability.comparability_status -eq 'comparable' -and
        $comparability.blind_pair_allowed -eq $true) {
      $baseline = Read-R8H5EvaluationJson (Join-Path $caseRoot 'baseline/arm-result.json')
      $candidate = Read-R8H5EvaluationJson (Join-Path $caseRoot 'candidate/arm-result.json')
      $pair = New-R8H5BlindPair $EvaluationRoot $semantic $machine $comparability $baseline $candidate $GeneratedAt
      [void](Write-R8H5ImmutableJson $pairPath $pair)
      $pairRefs += "cases/$caseId/blind-pair.json"
    } elseif (Test-Path -LiteralPath $pairPath -PathType Leaf) {
      throw "blind_pair_false_success_existing_for_ineligible_case:$caseId"
    }
  }
  $packet = [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r8/h5/h5-blind-review-packet/v0.1'
    schema_version = '0.1'
    evaluation_id = $compileResult.evaluation_id
    attempt_id = $compileResult.attempt_id
    packet_status = if ($pairRefs.Count -gt 0) { 'ready_for_human_review' } else { 'no_comparable_pairs' }
    blind_pair_refs = @($pairRefs)
    blind_pair_count = $pairRefs.Count
    human_review_started = $false
    generated_at = $GeneratedAt
  }
  Assert-R8H5Schema 'templates/schema/r8/h5/h5-blind-review-packet.v0.1.schema.json' $packet 'blind_packet_invalid'
  [void](Write-R8H5ImmutableJson (Join-Path $EvaluationRoot 'blind-review-packet.json') $packet)
  $lines = @('# R8 H5 v0.2 Anonymous A/B Packet','')
  foreach ($pairRef in $pairRefs) {
    $pair = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $EvaluationRoot $pairRef)
    $lines += "## $($pair.semantic_case_id)"
    $lines += ''
    $lines += '### A'
    $lines += '```json'
    $lines += $pair.a.presentation
    $lines += '```'
    $lines += ''
    $lines += '### B'
    $lines += '```json'
    $lines += $pair.b.presentation
    $lines += '```'
    $lines += ''
  }
  [void](Write-R8H5ImmutableText (Join-Path $EvaluationRoot 'blind-review-packet.md') ([string]::Join("`n",$lines) + "`n"))
  return $packet
}
