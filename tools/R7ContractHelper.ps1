Set-StrictMode -Version 2.0

function Read-R7JsonFile {
  param([string]$Path)
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Test-R7HasProperty {
  param([object]$Object, [string]$Name)
  if ($null -eq $Object) { return $false }
  if ($Object -is [System.Collections.IDictionary]) { return $Object.Contains($Name) }
  return @($Object.PSObject.Properties.Name) -contains $Name
}

function Get-R7PropertyNames {
  param([object]$Object)
  if ($null -eq $Object) { return @() }
  if ($Object -is [System.Collections.IDictionary]) { return [object[]]@($Object.Keys) }
  return [object[]]@($Object.PSObject.Properties | ForEach-Object { [string]$_.Name })
}

function Test-R7RequiredProperties {
  param([object]$Object, [string[]]$Names, [string]$Prefix)
  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($name in $Names) {
    if (-not (Test-R7HasProperty $Object $name)) { $errors.Add("${Prefix}_required_missing:$name") }
  }
  return [object[]]$errors.ToArray()
}

function Test-R7AllowedProperties {
  param([object]$Object, [string[]]$Names, [string]$Prefix)
  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($name in (Get-R7PropertyNames $Object)) {
    if ($name -notin $Names) { $errors.Add("${Prefix}_unknown_field:$name") }
  }
  return [object[]]$errors.ToArray()
}

function Test-R7NonemptyArray {
  param([object]$Value)
  return @($Value).Count -gt 0 -and @($Value | Where-Object { [string]::IsNullOrWhiteSpace([string]$_) }).Count -eq 0
}

function Test-R7Digest {
  param([string]$Value)
  return $Value -match '^[a-f0-9]{64}$'
}

function Test-R7WorkflowBlueprintContract {
  param([object]$Document)
  $errors = [System.Collections.Generic.List[string]]::new()
  $root = @('schema_id','schema_version','registry_id','status','blueprints')
  foreach ($validationError in (Test-R7RequiredProperties $Document $root 'blueprint_registry')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-R7AllowedProperties $Document $root 'blueprint_registry')) { $errors.Add($validationError) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  $legacyRegistry=($Document.schema_id -eq 'taoge://registries/r7/workflow-blueprints/v0.1' -and [string]$Document.schema_version -eq '0.1')
  $currentRegistry=($Document.schema_id -eq 'taoge://registries/r7/workflow-blueprints/v0.2' -and [string]$Document.schema_version -eq '0.2')
  $hotspotRegistry=($Document.schema_id -eq 'taoge://registries/r7/workflow-blueprints/v0.3' -and [string]$Document.schema_version -eq '0.3')
  if(-not($legacyRegistry-or$currentRegistry-or$hotspotRegistry)){ $errors.Add('blueprint_registry_version_invalid') }
  $ids = @{}
  $fields = @('blueprint_id','blueprint_version','activation_status','node_registry_ref','entry_node_id','terminal_node_id','node_refs','max_active_next_nodes','single_next_node_required','runtime_state_source','implementation_batch')
  foreach ($blueprint in @($Document.blueprints)) {
    foreach ($validationError in (Test-R7RequiredProperties $blueprint $fields 'blueprint')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-R7AllowedProperties $blueprint $fields 'blueprint')) { $errors.Add($validationError) }
    if (-not (Test-R7HasProperty $blueprint 'blueprint_id')) { continue }
    $id = [string]$blueprint.blueprint_id
    if ($ids.ContainsKey($id)) { $errors.Add("blueprint_duplicate:$id") } else { $ids[$id] = $true }
    if (($legacyRegistry -and [string]$blueprint.blueprint_version -ne '0.1') -or (($currentRegistry-or$hotspotRegistry) -and [string]$blueprint.blueprint_version -notin @('0.1','0.2','0.3','0.4','0.5'))) { $errors.Add("blueprint_version_invalid:$id") }
    if ([int]$blueprint.max_active_next_nodes -ne 1 -or $blueprint.single_next_node_required -ne $true) { $errors.Add("blueprint_multiple_next_nodes_forbidden:$id") }
    if ([string]$blueprint.runtime_state_source -ne 'p0_plan_event_projection') { $errors.Add("blueprint_state_source_invalid:$id") }
    $nodeRefs = @($blueprint.node_refs)
    if (-not (Test-R7NonemptyArray $nodeRefs)) { $errors.Add("blueprint_node_refs_empty:$id") }
    if (@($nodeRefs | Sort-Object -Unique).Count -ne $nodeRefs.Count) { $errors.Add("blueprint_node_ref_duplicate:$id") }
    if ($nodeRefs -notcontains [string]$blueprint.entry_node_id -or $nodeRefs -notcontains [string]$blueprint.terminal_node_id) { $errors.Add("blueprint_endpoint_unregistered:$id") }
  }
  return [object[]]$errors.ToArray()
}

function Test-R7NodeRegistryContract {
  param([object]$Document)
  $errors = [System.Collections.Generic.List[string]]::new()
  $root = @('schema_id','schema_version','registry_id','status','nodes')
  foreach ($validationError in (Test-R7RequiredProperties $Document $root 'node_registry')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-R7AllowedProperties $Document $root 'node_registry')) { $errors.Add($validationError) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  $nodeRegistryCurrent=($Document.schema_id -eq 'taoge://registries/r7/workflow-nodes/v0.1' -and [string]$Document.schema_version -eq '0.1') -or ($Document.schema_id -eq 'taoge://registries/r7/workflow-nodes/v0.2' -and [string]$Document.schema_version -eq '0.2')
  if (-not $nodeRegistryCurrent) { $errors.Add('node_registry_version_invalid') }
  $ids = @{}
  $fields = @('node_id','skill_ref','step_kind','input_selectors','required_contract_versions','output_artifact_type','output_schema_ref','allowed_result_statuses','action_registry_ref','success_route','warning_route','failure_route','stale_scope','retry_policy','implementation_batch','implementation_status')
  $retryFields = @('mode','max_attempts','reconcile_first')
  foreach ($node in @($Document.nodes)) {
    foreach ($validationError in (Test-R7RequiredProperties $node $fields 'node')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-R7AllowedProperties $node $fields 'node')) { $errors.Add($validationError) }
    if (-not (Test-R7HasProperty $node 'node_id')) { continue }
    $id = [string]$node.node_id
    if ($ids.ContainsKey($id)) { $errors.Add("node_duplicate:$id") } else { $ids[$id] = $true }
    if ($node.step_kind -notin @('deterministic_tool','semantic_skill','human_gate','external_side_effect')) { $errors.Add("node_step_kind_invalid:$id") }
    foreach ($name in @('input_selectors','required_contract_versions','allowed_result_statuses')) { if (-not (Test-R7NonemptyArray $node.$name)) { $errors.Add("node_array_empty:${id}:$name") } }
    if ([string]$node.action_registry_ref -notin @('r7-action-registry-v0.1','r7-action-registry-v0.2')) { $errors.Add("node_action_registry_invalid:$id") }
    foreach ($validationError in (Test-R7RequiredProperties $node.retry_policy $retryFields 'node_retry')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-R7AllowedProperties $node.retry_policy $retryFields 'node_retry')) { $errors.Add($validationError) }
    if ($node.retry_policy.mode -notin @('never','bounded','reconcile_first','human_decision_required')) { $errors.Add("node_retry_mode_invalid:$id") }
    if ([int]$node.retry_policy.max_attempts -lt 1 -or [int]$node.retry_policy.max_attempts -gt 2) { $errors.Add("node_retry_attempts_invalid:$id") }
    if ($node.retry_policy.reconcile_first -ne $true) { $errors.Add("node_reconcile_first_required:$id") }
  }
  return [object[]]$errors.ToArray()
}

function Test-R7ContractStatusRegistryContract {
  param([object]$Document)
  $errors = [System.Collections.Generic.List[string]]::new()
  $root = @('schema_id','schema_version','registry_id','status','effective_from','contracts')
  foreach ($validationError in (Test-R7RequiredProperties $Document $root 'contract_registry')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-R7AllowedProperties $Document $root 'contract_registry')) { $errors.Add($validationError) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  $contractRegistryCurrent=($Document.schema_id -eq 'taoge://registries/r7/contract-status/v0.1' -and [string]$Document.schema_version -eq '0.1') -or ($Document.schema_id -eq 'taoge://registries/r7/contract-status/v0.2' -and [string]$Document.schema_version -eq '0.2')
  if (-not $contractRegistryCurrent) { $errors.Add('contract_registry_version_invalid') }
  $ids = @{}
  $fields = @('contract_id','active_version','lifecycle_status','superseded_by','compiled_layers','implementation_batch')
  foreach ($contract in @($Document.contracts)) {
    foreach ($validationError in (Test-R7RequiredProperties $contract $fields 'contract_status')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-R7AllowedProperties $contract $fields 'contract_status')) { $errors.Add($validationError) }
    if (-not (Test-R7HasProperty $contract 'contract_id')) { continue }
    $id = [string]$contract.contract_id
    if ($ids.ContainsKey($id)) { $errors.Add("contract_status_duplicate:$id") } else { $ids[$id] = $true }
    if ($contract.lifecycle_status -notin @('active_compiled','confirmed_pending_compile','superseded_pending_recompile','historical_compatibility','historical_contract_defect')) { $errors.Add("contract_lifecycle_invalid:$id") }
    if ($contract.lifecycle_status -eq 'superseded_pending_recompile' -and ([string]::IsNullOrWhiteSpace([string]$contract.superseded_by) -or [string]$contract.superseded_by -eq 'none')) { $errors.Add("contract_superseded_target_missing:$id") }
    if ($contract.lifecycle_status -eq 'confirmed_pending_compile' -and @($contract.compiled_layers) -contains 'runtime') { $errors.Add("contract_pending_has_runtime_layer:$id") }
  }
  return [object[]]$errors.ToArray()
}

function Test-R7ActionRegistryContract {
  param([object]$Document)
  $errors = [System.Collections.Generic.List[string]]::new()
  $root = @('schema_id','schema_version','registry_id','status','actions')
  foreach ($validationError in (Test-R7RequiredProperties $Document $root 'action_registry')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-R7AllowedProperties $Document $root 'action_registry')) { $errors.Add($validationError) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  $actionRegistryCurrent=($Document.schema_id -eq 'taoge://registries/r7/actions/v0.1' -and [string]$Document.schema_version -eq '0.1') -or ($Document.schema_id -eq 'taoge://registries/r7/actions/v0.2' -and [string]$Document.schema_version -eq '0.2')
  if (-not $actionRegistryCurrent) { $errors.Add('action_registry_version_invalid') }
  $ids = @{}
  $fields = @('action_code','label','allowed_target_types','requires_target_artifact','lifecycle_status','introduced_contract')
  foreach ($action in @($Document.actions)) {
    foreach ($validationError in (Test-R7RequiredProperties $action $fields 'action')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-R7AllowedProperties $action $fields 'action')) { $errors.Add($validationError) }
    if (-not (Test-R7HasProperty $action 'action_code')) { continue }
    $id = [string]$action.action_code
    if ($ids.ContainsKey($id)) { $errors.Add("action_duplicate:$id") } else { $ids[$id] = $true }
    if ($id -notmatch '^[a-z][a-z0-9_]*$') { $errors.Add("action_code_invalid:$id") }
    if (-not (Test-R7NonemptyArray $action.allowed_target_types)) { $errors.Add("action_targets_empty:$id") }
    if ($action.lifecycle_status -notin @('active','historical')) { $errors.Add("action_lifecycle_invalid:$id") }
  }
  return [object[]]$errors.ToArray()
}

function Test-R7TaskEnvelopeContract {
  param([object]$Document, [object]$ActionRegistry = $null)
  $errors = [System.Collections.Generic.List[string]]::new()
  $fields = @('schema_id','schema_version','task_envelope_id','session_id','plan_id','blueprint_id','blueprint_version','node_id','skill_ref','task_contract_version','action_registry_version','created_at','input_artifact_bindings','input_binding_digest','business_objective','decision_boundaries','required_output_schema_ref','allowed_statuses','allowed_actions','output_commit_policy','idempotency_key','resume_context')
  $allowedFields=$fields+@('test_profile')
  $requiredFields=$fields;if([string]$Document.schema_id-in@('taoge://schemas/r7/semantic-task-envelope/v0.3','taoge://schemas/r7/semantic-task-envelope/v0.4','taoge://schemas/r7/semantic-task-envelope/v0.5')){$requiredFields+=@('test_profile')}
  foreach ($validationError in (Test-R7RequiredProperties $Document $requiredFields 'task_envelope')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-R7AllowedProperties $Document $allowedFields 'task_envelope')) { $errors.Add($validationError) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  $legacyTask=($Document.schema_id -eq 'taoge://schemas/r7/semantic-task-envelope/v0.1' -and [string]$Document.schema_version -eq '0.1' -and [string]$Document.blueprint_version -eq '0.1')
  $currentTask=($Document.schema_id -eq 'taoge://schemas/r7/semantic-task-envelope/v0.2' -and [string]$Document.schema_version -eq '0.2' -and [string]$Document.blueprint_version -eq '0.2')
  $revisionTask=($Document.schema_id -eq 'taoge://schemas/r7/semantic-task-envelope/v0.3' -and [string]$Document.schema_version -eq '0.3' -and [string]$Document.blueprint_version -eq '0.3')
  $h7Task=($Document.schema_id -eq 'taoge://schemas/r7/semantic-task-envelope/v0.4' -and [string]$Document.schema_version -eq '0.4' -and [string]$Document.blueprint_version -eq '0.4')
  $l3Task=($Document.schema_id -eq 'taoge://schemas/r7/semantic-task-envelope/v0.5' -and [string]$Document.schema_version -eq '0.5' -and [string]$Document.blueprint_version -eq '0.5')
  if(-not($legacyTask-or$currentTask-or$revisionTask-or$h7Task-or$l3Task)){ $errors.Add('task_envelope_version_invalid') }
  if(($revisionTask-or$h7Task-or$l3Task)-and$Document.test_profile-notin@('production','no_provider','reuse_only')){$errors.Add('task_envelope_test_profile_invalid')}
  if ($Document.output_commit_policy -ne 'deterministic_submitter_pointer_last') { $errors.Add('task_envelope_commit_policy_invalid') }
  if (-not (Test-R7Digest ([string]$Document.input_binding_digest))) { $errors.Add('task_envelope_input_digest_invalid') }
  if (-not (Test-R7NonemptyArray $Document.allowed_statuses)) { $errors.Add('task_envelope_statuses_empty') }
  $bindingFields = @('artifact_id','artifact_type','relative_path','sha256','status','materialization_status','current_ref_status')
  foreach ($binding in @($Document.input_artifact_bindings)) {
    foreach ($validationError in (Test-R7RequiredProperties $binding $bindingFields 'task_input')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-R7AllowedProperties $binding $bindingFields 'task_input')) { $errors.Add($validationError) }
    if (-not (Test-R7HasProperty $binding 'artifact_id')) { continue }
    $id = [string]$binding.artifact_id
    if ($binding.materialization_status -ne 'materialized' -or $binding.current_ref_status -ne 'current') { $errors.Add("task_input_not_current_materialized:$id") }
    if (-not (Test-R7Digest ([string]$binding.sha256))) { $errors.Add("task_input_digest_invalid:$id") }
    $relative = [string]$binding.relative_path
    if ([System.IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)') { $errors.Add("task_input_path_not_relative:$id") }
  }
  if ($Document.resume_context.pending_submission_status -notin @('none','reconciled')) { $errors.Add('task_pending_submission_not_reconciled') }
  if ($null -ne $ActionRegistry) {
    $known = @($ActionRegistry.actions | ForEach-Object { [string]$_.action_code })
    foreach ($action in @($Document.allowed_actions)) { if ([string]$action -notin $known) { $errors.Add("enum_registry_error:$action") } }
  }
  return [object[]]$errors.ToArray()
}

function Test-R7ArtifactSubmissionContract {
  param([object]$Document, [object]$Envelope = $null, [object]$ActionRegistry = $null)
  $errors = [System.Collections.Generic.List[string]]::new()
  $fields = @('schema_id','schema_version','submission_id','task_envelope_id','session_id','plan_id','node_id','skill_ref','attempt_no','submitted_at','input_binding_digest','output_artifact_type','output_contract_version','result_status','requested_action','source_artifact_ids','payload','evidence_refs','idempotency_key','write_intent','requested_machine_writes')
  foreach ($validationError in (Test-R7RequiredProperties $Document $fields 'semantic_submission')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-R7AllowedProperties $Document $fields 'semantic_submission')) { $errors.Add($validationError) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Document.schema_id -ne 'taoge://schemas/r7/semantic-artifact-submission/v0.1' -or [string]$Document.schema_version -ne '0.1') { $errors.Add('semantic_submission_version_invalid') }
  if ($Document.write_intent -ne 'submit_for_deterministic_commit') { $errors.Add('semantic_submission_write_intent_invalid') }
  if (@($Document.requested_machine_writes).Count -ne 0) { $errors.Add('semantic_submission_forbidden_machine_write') }
  foreach ($name in @('current_pointer','event','projection','final_delivery_render_candidate','delivery_revision_marker')) {
    if (Test-R7HasProperty $Document.payload $name) { $errors.Add("semantic_submission_forbidden_payload_field:$name") }
  }
  if ($null -ne $Envelope) {
    foreach ($name in @('task_envelope_id','session_id','plan_id','node_id','skill_ref','input_binding_digest','idempotency_key')) {
      if ([string]$Document.$name -ne [string]$Envelope.$name) { $errors.Add("semantic_submission_envelope_mismatch:$name") }
    }
    if ([string]$Document.result_status -notin @($Envelope.allowed_statuses)) { $errors.Add("semantic_submission_status_not_allowed:$($Document.result_status)") }
    if ($null -ne $Document.requested_action -and [string]$Document.requested_action -notin @($Envelope.allowed_actions)) { $errors.Add("enum_registry_error:$($Document.requested_action)") }
  }
  if ($null -ne $ActionRegistry -and $null -ne $Document.requested_action) {
    $known = @($ActionRegistry.actions | ForEach-Object { [string]$_.action_code })
    if ([string]$Document.requested_action -notin $known) { $errors.Add("enum_registry_error:$($Document.requested_action)") }
  }
  return [object[]]$errors.ToArray()
}

function Test-R7CompatibilityMatrixContract {
  param([object]$Document)
  $errors = [System.Collections.Generic.List[string]]::new()
  $root = @('matrix_id','matrix_version','status','target_contract','target_activation_status','entries')
  foreach ($validationError in (Test-R7RequiredProperties $Document $root 'compatibility_matrix')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-R7AllowedProperties $Document $root 'compatibility_matrix')) { $errors.Add($validationError) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Document.matrix_id -ne 'R7-CONTRACT-COMPATIBILITY-v0.1' -or [string]$Document.matrix_version -ne '0.1' -or $Document.status -ne 'h1_contract_only') { $errors.Add('compatibility_matrix_version_invalid') }
  if ($Document.target_activation_status -ne 'confirmed_pending_compile') { $errors.Add('compatibility_target_activation_invalid') }
  $requiredFrom = @('p0-runtime-v0.1','p0-contract-bundle-v0.2','p0-contract-bundle-v0.3','p0-contract-bundle-v0.4','p0-contract-bundle-v0.5')
  $seen = @{}
  $entryFields = @('from_contract','target_contract','replay_readable','resume_into_target','render_with_original_contract','render_with_target_contract','candidate_recompilation_required','autonomy_backfill_allowed','migration_status','reason')
  foreach ($entry in @($Document.entries)) {
    foreach ($validationError in (Test-R7RequiredProperties $entry $entryFields 'compatibility_entry')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-R7AllowedProperties $entry $entryFields 'compatibility_entry')) { $errors.Add($validationError) }
    if (-not (Test-R7HasProperty $entry 'from_contract')) { continue }
    $from = [string]$entry.from_contract
    if ($seen.ContainsKey($from)) { $errors.Add("compatibility_entry_duplicate:$from") } else { $seen[$from] = $true }
    if ($entry.replay_readable -ne $true -or $entry.resume_into_target -ne $false -or $entry.render_with_original_contract -ne $true -or $entry.render_with_target_contract -ne $false -or $entry.candidate_recompilation_required -ne $true -or $entry.autonomy_backfill_allowed -ne $false -or $entry.migration_status -ne 'legacy_replay_only') { $errors.Add("legacy_resume_into_r7_forbidden:$from") }
  }
  foreach ($from in $requiredFrom) { if (-not $seen.ContainsKey($from)) { $errors.Add("compatibility_entry_missing:$from") } }
  return [object[]]$errors.ToArray()
}
