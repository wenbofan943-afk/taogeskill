. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'YamlHelper.ps1')

function ConvertTo-R8H5CanonicalValue {
  param([object]$Value)
  if ($null -eq $Value) { return $null }
  if ($Value -is [System.Collections.IDictionary]) {
    $ordered = [ordered]@{}
    foreach ($key in @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object)) {
      $ordered[$key] = ConvertTo-R8H5CanonicalValue $Value[$key]
    }
    return [pscustomobject]$ordered
  }
  if ($Value -is [pscustomobject]) {
    $ordered = [ordered]@{}
    foreach ($property in @($Value.PSObject.Properties | Sort-Object Name)) {
      $ordered[$property.Name] = ConvertTo-R8H5CanonicalValue $property.Value
    }
    return [pscustomobject]$ordered
  }
  if ($Value -is [System.Array]) {
    return @($Value | ForEach-Object { ConvertTo-R8H5CanonicalValue $_ })
  }
  return $Value
}

function ConvertTo-R8H5CanonicalJson {
  param([object]$Value)
  return ((ConvertTo-R8H5CanonicalValue $Value) | ConvertTo-Json -Depth 50 -Compress)
}

function Get-R8H5TextDigest {
  param([AllowEmptyString()][string]$Text)
  $algorithm = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = (Get-TaogeUtf8NoBomEncoding).GetBytes($Text)
    return 'sha256:' + (([System.BitConverter]::ToString($algorithm.ComputeHash($bytes))) -replace '-','').ToLowerInvariant()
  } finally {
    $algorithm.Dispose()
  }
}

function Get-R8H5ObjectDigest {
  param([object]$Value)
  return Get-R8H5TextDigest (ConvertTo-R8H5CanonicalJson $Value)
}

function Assert-R8H5Id {
  param([string]$Name,[string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{2,127}$') {
    throw "invalid_id:$Name"
  }
}

function Assert-R8H5Timestamp {
  param([string]$Name,[string]$Value)
  $parsed = [DateTimeOffset]::MinValue
  if ([string]::IsNullOrWhiteSpace($Value) -or -not [DateTimeOffset]::TryParse($Value,[ref]$parsed) -or
      $Value -notmatch '(Z|[+-]\d{2}:\d{2})$') {
    throw "invalid_timestamp:$Name"
  }
}

function Resolve-R8H5ContainedPath {
  param([string]$ProjectRoot,[string]$Path)
  $root = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\','/')
  $full = [System.IO.Path]::GetFullPath($Path)
  if ($full -ne $root -and -not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar,[System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'output_root_escape'
  }
  return $full
}

function Write-R8H5ImmutableJson {
  param([string]$Path,[object]$Value)
  $json = ($Value | ConvertTo-Json -Depth 50).TrimEnd("`r","`n") + "`n"
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    $existing = [System.IO.File]::ReadAllText($Path,(Get-TaogeUtf8NoBomEncoding))
    if ($existing -ne $json) { throw "immutable_conflict:$Path" }
    return 'byte_stable_skip'
  }
  Write-TaogeUtf8NoBomText -Path $Path -Text $json
  return 'created'
}

function Get-R8H5Adapter {
  param([string]$SkillId,[string]$ArmRole)
  if ([string]::IsNullOrWhiteSpace($script:R8H5ProjectRoot)) { throw 'project_root_not_initialized' }
  $registryPath = Join-Path $script:R8H5ProjectRoot 'routes/r8-h5-arm-adapters.yaml'
  $registry = Read-YamlFile -Path $registryPath
  $matches = @($registry.adapters | Where-Object { $_.skill_id -eq $SkillId -and $_.arm_role -eq $ArmRole })
  if ($matches.Count -ne 1) { throw "adapter_not_registered_or_duplicate:${SkillId}:${ArmRole}:$($matches.Count)" }
  $value = $matches[0]
  return [pscustomobject][ordered]@{
    adapter_id = [string]$value.adapter_id
    source_revision = [string]$value.source_commit
    contract_version = [string]$value.contract_version
    artifact_type = [string]$value.artifact_type
    input_schema_ref = [string]$value.input_schema_ref
  }
}

function Get-R8H5GitText {
  param([string]$ProjectRoot,[string]$Revision,[string]$RelativePath)
  $result = Invoke-TaogeProcessCapture -FilePath 'git' -Arguments @('-C',$ProjectRoot,'show',"$Revision`:$RelativePath")
  return [string]$result.stdout
}

function Get-R8H5GitCommit {
  param([string]$ProjectRoot,[string]$Revision)
  $result = Invoke-TaogeProcessCapture -FilePath 'git' -Arguments @('-C',$ProjectRoot,'rev-parse',"$Revision^{commit}")
  return $result.stdout.Trim()
}

function Get-R8H5GitPaths {
  param([string]$ProjectRoot,[string]$Revision)
  $result = Invoke-TaogeProcessCapture -FilePath 'git' -Arguments @('-C',$ProjectRoot,'-c','core.quotepath=false','ls-tree','-r','--name-only','-z',$Revision)
  return @($result.stdout.Split([char]0) | Where-Object { -not [string]::IsNullOrEmpty($_) })
}

function Get-R8H5DependencyContent {
  param([string]$ProjectRoot,[string]$Revision,[string]$RelativePath)
  return Get-R8H5GitText -ProjectRoot $ProjectRoot -Revision $Revision -RelativePath $RelativePath
}

function New-R8H5SemanticCase {
  param([object]$Case,[string]$EvaluationId,[string]$AttemptId)
  Assert-R8H5Id 'evaluation_id' $EvaluationId
  Assert-R8H5Id 'attempt_id' $AttemptId
  Assert-R8H5Id 'semantic_case_id' ([string]$Case.semantic_case_id)
  Assert-R8H5Timestamp 'created_at' ([string]$Case.created_at)
  $digestBody = [pscustomobject][ordered]@{
    skill_id = $Case.skill_id
    case_class = $Case.case_class
    prompt_text = $Case.prompt_text
    semantic_input = $Case.semantic_input
    shared_outcome_invariants = @($Case.shared_outcome_invariants)
    expected_primary_output_type = $Case.expected_primary_output_type
  }
  return [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r8/h5/h5-semantic-case/v0.2'
    schema_version = '0.2'
    semantic_case_id = $Case.semantic_case_id
    evaluation_id = $EvaluationId
    attempt_id = $AttemptId
    skill_id = $Case.skill_id
    case_class = $Case.case_class
    prompt_text = $Case.prompt_text
    semantic_input = $Case.semantic_input
    shared_outcome_invariants = @($Case.shared_outcome_invariants)
    expected_primary_output_type = $Case.expected_primary_output_type
    created_at = $Case.created_at
    semantic_case_digest = Get-R8H5ObjectDigest $digestBody
    case_status = 'ready'
    supersedes = $null
  }
}

function New-R8H5DependencySnapshot {
  param(
    [string]$ProjectRoot,[object]$SemanticCase,[string]$ArmRole,
    [object]$Adapter,[string]$CompiledAt
  )
  $skillId = [string]$SemanticCase.skill_id
  $revision = [string]$Adapter.source_revision
  $sourceCommit = Get-R8H5GitCommit -ProjectRoot $ProjectRoot -Revision $revision
  $entry = "skills/$skillId/SKILL.md"
  $contract = "skills/$skillId/CONTRACT.md"
  $tracked = @(Get-R8H5GitPaths -ProjectRoot $ProjectRoot -Revision $revision)
  if ($entry -notin $tracked -or $contract -notin $tracked) { throw "snapshot_entry_or_contract_missing:${skillId}:${revision}" }
  $entryText = Get-R8H5DependencyContent $ProjectRoot $revision $entry
  $contractText = Get-R8H5DependencyContent $ProjectRoot $revision $contract
  $selected = [ordered]@{}
  $selected[$entry] = 'skill_entry'
  $selected[$contract] = 'contract'
  foreach ($path in $tracked) {
    if ($path -match "^skills/$([regex]::Escape($skillId))/(references|assets)/[^/]+$") {
      $selected[$path] = if ($Matches[1] -eq 'assets') { 'asset' } else { 'reference' }
    }
  }
  $sourceText = $entryText + "`n" + $contractText
  foreach ($path in $tracked) {
    if (-not $selected.Contains($path) -and $path.Contains('/') -and $sourceText.Contains($path)) {
      $selected[$path] = 'machine_truth'
    }
  }
  $files = @()
  foreach ($path in @($selected.Keys | Sort-Object)) {
    $content = Get-R8H5DependencyContent $ProjectRoot $revision $path
    $files += [pscustomobject][ordered]@{
      relative_path = $path
      role = $selected[$path]
      sha256 = Get-R8H5TextDigest $content
    }
  }
  $closureLines = @($files | ForEach-Object { "$($_.relative_path)|$($_.role)|$($_.sha256)" })
  return [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r8/h5/h5-dependency-snapshot/v0.2'
    schema_version = '0.2'
    snapshot_id = "SNAP-$($SemanticCase.semantic_case_id)-$ArmRole"
    evaluation_id = $SemanticCase.evaluation_id
    attempt_id = $SemanticCase.attempt_id
    semantic_case_id = $SemanticCase.semantic_case_id
    arm_role = $ArmRole
    isolation_level = 'instruction_isolated'
    source_commit = $sourceCommit
    entry_skill_path = $entry
    files = @($files)
    closure_digest = Get-R8H5TextDigest ([string]::Join("`n",$closureLines))
    snapshot_status = 'ready'
    created_at = $CompiledAt
    supersedes = $null
  }
}

function New-R8H5TypedInput {
  param([object]$SemanticCase,[string]$ArmRole,[object]$Adapter)
  $input = $SemanticCase.semantic_input
  $consumer = $null
  if ($SemanticCase.skill_id -eq 'hotspot-topic-research') {
    if ($ArmRole -eq 'baseline') {
      $consumer = [pscustomobject][ordered]@{
        account_profile = $input.account_profile
        product_or_campaign_profile = $input.product_or_campaign_profile
        request_context = $input.request_context
        source_observations = @($input.source_observations)
      }
    } else {
      $request = $input.request_context
      $consumer = [pscustomobject][ordered]@{
        task_envelope = $input.task_context
        hotspot_research_request = [pscustomobject][ordered]@{
          schema_id = 'taoge://schemas/r7/hotspot-research-request/v0.1'
          schema_version = '0.1.0'
          research_request_id = $request.research_request_id
          research_request_revision = 1
          supersedes_request_ref = $null
          account_identity_ref = $request.account_identity_ref
          account_snapshot_ref = $request.account_snapshot_ref
          radar_policy_ref = $request.radar_policy_ref
          triggering_decision_ref = $null
          triggering_freshness_review_ref = $null
          prior_research_set_ref = $null
          prior_panel_ref = $null
          request_mode = $request.request_mode
          scope_delta = $null
          manual_source_input_set_ref = $null
          requested_at = $request.requested_at
          request_status = 'ready'
        }
        source_observations = @($input.source_observations)
      }
    }
  } elseif ($SemanticCase.skill_id -eq 'propagation-router') {
    if ($ArmRole -eq 'baseline') {
      $consumer = [pscustomobject][ordered]@{
        user_intent = $input.user_intent
        workflow_session_record = $input.workflow_session_record
        manifest = $input.manifest
      }
    } else {
      $consumer = [pscustomobject][ordered]@{
        entry_router_request = $input.entry_router_request
        active_workflow_plan = $input.active_workflow_plan
        current_workflow_state = $input.current_workflow_state
        current_artifact = $input.current_artifact
      }
    }
  } elseif ($SemanticCase.skill_id -eq 'platform-packaging-adapter') {
    if ($ArmRole -eq 'baseline') {
      $consumer = [pscustomobject][ordered]@{
        quality_review = $input.quality_review
        draft = $input.draft
        visual_plan = $input.visual_plan
        content_brief = $input.content_brief
        target_platforms = @($input.target_platforms)
      }
    } else {
      $consumer = [pscustomobject][ordered]@{
        task_envelope = $input.task_context
        draft = $input.draft
        script_visual_alignment_review = $input.quality_review
        account_snapshot = $input.account_snapshot
      }
    }
  } else {
    throw "unsupported_skill:$($SemanticCase.skill_id)"
  }
  $schemaId = (Get-Content -LiteralPath (Join-Path $script:R8H5ProjectRoot ($Adapter.input_schema_ref -replace '/', [System.IO.Path]::DirectorySeparatorChar)) -Raw -Encoding UTF8 | ConvertFrom-Json).'$id'
  return [pscustomobject][ordered]@{
    schema_id = $schemaId
    schema_version = '0.1'
    skill_id = $SemanticCase.skill_id
    arm_role = $ArmRole
    semantic_case_id = $SemanticCase.semantic_case_id
    semantic_case_digest = $SemanticCase.semantic_case_digest
    semantic_projection_digest = Get-R8H5ObjectDigest $SemanticCase.semantic_input
    contract_version = $Adapter.contract_version
    artifact_type = $Adapter.artifact_type
    consumer_input = $consumer
    shared_outcome_invariants = @($SemanticCase.shared_outcome_invariants)
  }
}

function Test-R8H5TypedInput {
  param([object]$TypedInput,[object]$Adapter)
  $errors = [System.Collections.Generic.List[string]]::new()
  $schema = Get-Content -LiteralPath (Join-Path $script:R8H5ProjectRoot ($Adapter.input_schema_ref -replace '/', [System.IO.Path]::DirectorySeparatorChar)) -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($name in @($schema.required)) {
    if ($null -eq $TypedInput.PSObject.Properties[$name]) { $errors.Add("required:$name") }
  }
  foreach ($name in @($TypedInput.PSObject.Properties.Name)) {
    if ($null -eq $schema.properties.PSObject.Properties[$name]) { $errors.Add("additional_property:$name") }
  }
  foreach ($name in @($schema.properties.consumer_input.required)) {
    if ($null -eq $TypedInput.consumer_input.PSObject.Properties[$name]) { $errors.Add("required:consumer_input.$name") }
  }
  foreach ($name in @($TypedInput.consumer_input.PSObject.Properties.Name)) {
    if ($null -eq $schema.properties.consumer_input.properties.PSObject.Properties[$name]) { $errors.Add("additional_property:consumer_input.$name") }
  }
  foreach ($property in @($schema.properties.consumer_input.properties.PSObject.Properties)) {
    $valueProperty = $TypedInput.consumer_input.PSObject.Properties[$property.Name]
    if ($null -eq $valueProperty) { continue }
    $expectedTypes = @($property.Value.type)
    $value = $valueProperty.Value
    $typePass = $false
    foreach ($expectedType in $expectedTypes) {
      if (($expectedType -eq 'object' -and $null -ne $value -and $value -isnot [string] -and $value -isnot [System.Array] -and $value -isnot [ValueType]) -or
          ($expectedType -eq 'array' -and $value -is [System.Array]) -or
          ($expectedType -eq 'string' -and $value -is [string] -and -not [string]::IsNullOrWhiteSpace($value)) -or
          ($expectedType -eq 'null' -and $null -eq $value)) {
        $typePass = $true
      }
    }
    if (-not $typePass) { $errors.Add("type:consumer_input.$($property.Name)") }
  }
  if ($TypedInput.schema_id -ne $schema.'$id') { $errors.Add('schema_id_mismatch') }
  if ($TypedInput.arm_role -ne $schema.properties.arm_role.const) { $errors.Add('arm_role_mismatch') }
  if ($TypedInput.skill_id -ne $schema.properties.skill_id.const) { $errors.Add('skill_id_mismatch') }
  if ($TypedInput.contract_version -ne $Adapter.contract_version) { $errors.Add('contract_version_mismatch') }
  if ($TypedInput.artifact_type -ne $Adapter.artifact_type) { $errors.Add('artifact_type_mismatch') }
  if ($TypedInput.skill_id -eq 'hotspot-topic-research' -and $TypedInput.arm_role -eq 'candidate') {
    $request = $TypedInput.consumer_input.hotspot_research_request
    $requestSchema = Get-Content -LiteralPath (Join-Path $script:R8H5ProjectRoot 'templates/schema/r7/hotspot-research-request.v0.1.schema.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($name in @($requestSchema.required)) {
      if ($null -eq $request.PSObject.Properties[$name]) { $errors.Add("required:consumer_input.hotspot_research_request.$name") }
    }
    if ($request.schema_id -ne $requestSchema.properties.schema_id.const) { $errors.Add('hotspot_request_schema_id_mismatch') }
    if ($request.schema_version -ne $requestSchema.properties.schema_version.const) { $errors.Add('hotspot_request_schema_version_mismatch') }
    if ($request.request_mode -notin @($requestSchema.properties.request_mode.enum)) { $errors.Add('hotspot_request_mode_invalid') }
    if ($request.request_status -ne 'ready') { $errors.Add('hotspot_request_status_invalid') }
    try { Assert-R8H5Timestamp 'hotspot_request.requested_at' ([string]$request.requested_at) } catch { $errors.Add('hotspot_request_requested_at_invalid') }
    foreach ($refName in @('account_identity_ref','account_snapshot_ref','radar_policy_ref')) {
      $ref = $request.$refName
      if ($null -eq $ref -or [string]$ref.artifact_id -notmatch '^[A-Za-z0-9][A-Za-z0-9._:-]{2,127}$' -or
          [int]$ref.revision -lt 1 -or [string]$ref.sha256 -notmatch '^sha256:[0-9a-f]{64}$') {
        $errors.Add("hotspot_request_ref_invalid:$refName")
      }
    }
  }
  return @($errors)
}

function New-R8H5ArmInput {
  param([object]$SemanticCase,[string]$ArmRole,[object]$Adapter,[object]$Snapshot,[object]$TypedInput,[string]$CompiledAt)
  $validationErrors = @(Test-R8H5TypedInput $TypedInput $Adapter)
  $caseRef = "cases/$($SemanticCase.semantic_case_id)/semantic-case.json"
  $armRoot = "cases/$($SemanticCase.semantic_case_id)/$ArmRole"
  return [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r8/h5/h5-arm-input/v0.2'
    schema_version = '0.2'
    arm_input_id = "ARM-IN-$($SemanticCase.semantic_case_id)-$ArmRole"
    evaluation_id = $SemanticCase.evaluation_id
    attempt_id = $SemanticCase.attempt_id
    semantic_case_id = $SemanticCase.semantic_case_id
    arm_role = $ArmRole
    skill_id = $SemanticCase.skill_id
    semantic_case_ref = $caseRef
    semantic_case_digest = $SemanticCase.semantic_case_digest
    dependency_snapshot_ref = "$armRoot/dependency-snapshot.json"
    dependency_snapshot_digest = $Snapshot.closure_digest
    adapter_id = $Adapter.adapter_id
    adapter_version = '0.1'
    artifact_type = $Adapter.artifact_type
    contract_version = $Adapter.contract_version
    input_schema_ref = $Adapter.input_schema_ref
    typed_input_relative_path = "$armRoot/typed-input.json"
    input_digest = Get-R8H5ObjectDigest $TypedInput
    input_status = if ($validationErrors.Count -eq 0) { 'ready' } else { 'invalid_input' }
    validation_errors = @($validationErrors)
    compiled_at = $CompiledAt
    supersedes = $null
  }
}

function Invoke-R8H5CaseCompile {
  param(
    [string]$ProjectRoot,[object]$Case,[string]$EvaluationId,[string]$AttemptId,
    [string]$OutputRoot,[string]$CompiledAt
  )
  $script:R8H5ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
  Assert-R8H5Timestamp 'compiled_at' $CompiledAt
  $output = Resolve-R8H5ContainedPath $script:R8H5ProjectRoot $OutputRoot
  $semanticCase = New-R8H5SemanticCase $Case $EvaluationId $AttemptId
  $caseRoot = Join-Path $output (Join-Path 'cases' $semanticCase.semantic_case_id)
  [void](Write-R8H5ImmutableJson (Join-Path $caseRoot 'semantic-case.json') $semanticCase)
  $arms = @()
  foreach ($armRole in @('baseline','candidate')) {
    $adapter = Get-R8H5Adapter $semanticCase.skill_id $armRole
    $snapshot = New-R8H5DependencySnapshot $script:R8H5ProjectRoot $semanticCase $armRole $adapter $CompiledAt
    $typedInput = New-R8H5TypedInput $semanticCase $armRole $adapter
    $armInput = New-R8H5ArmInput $semanticCase $armRole $adapter $snapshot $typedInput $CompiledAt
    if ($armInput.input_status -ne 'ready') { throw "invalid_input:$($armInput.validation_errors -join ',')" }
    $armPath = Join-Path $caseRoot $armRole
    [void](Write-R8H5ImmutableJson (Join-Path $armPath 'dependency-snapshot.json') $snapshot)
    [void](Write-R8H5ImmutableJson (Join-Path $armPath 'typed-input.json') $typedInput)
    [void](Write-R8H5ImmutableJson (Join-Path $armPath 'arm-input.json') $armInput)
    $arms += $armInput
  }
  return [pscustomobject][ordered]@{
    semantic_case_id = $semanticCase.semantic_case_id
    semantic_case_digest = $semanticCase.semantic_case_digest
    semantic_projection_digest = Get-R8H5ObjectDigest $semanticCase.semantic_input
    arm_inputs = @($arms)
  }
}
