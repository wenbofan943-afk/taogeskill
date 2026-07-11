Set-StrictMode -Version 2.0

function Test-P0HasProperty {
  param([object]$Object, [string]$Name)
  return $null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name
}

function Get-P0PropertyNames {
  param([object]$Object)
  if ($null -eq $Object) { return @() }
  return @($Object.PSObject.Properties.Name)
}

function Test-P0RequiredProperties {
  param([object]$Object, [string[]]$Names, [string]$Prefix)
  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($name in $Names) {
    if (-not (Test-P0HasProperty $Object $name)) { $errors.Add("${Prefix}_required_field_missing:$name") }
  }
  return [object[]]$errors.ToArray()
}

function Test-P0AllowedProperties {
  param([object]$Object, [string[]]$Names, [string]$Prefix)
  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($name in (Get-P0PropertyNames $Object)) {
    if ($name -notin $Names) { $errors.Add("${Prefix}_unknown_field:$name") }
  }
  return [object[]]$errors.ToArray()
}

function Test-P0Digest {
  param([object]$Value)
  return [string]$Value -match '^sha256:[0-9a-f]{64}$'
}

function Test-P0DateTime {
  param([object]$Value)
  $parsed = [DateTimeOffset]::MinValue
  return [DateTimeOffset]::TryParse([string]$Value, [ref]$parsed)
}

function Test-P0RelativePath {
  param([object]$Value)
  $text = [string]$Value
  if ([string]::IsNullOrWhiteSpace($text) -or [System.IO.Path]::IsPathRooted($text)) { return $false }
  if ($text -match '^[a-zA-Z][a-zA-Z0-9+.-]*:' -or $text -match '[?#]' -or $text.IndexOf([char]0) -ge 0) { return $false }
  $segments = @($text.Replace('\','/').Split('/') | Where-Object { $_ -ne '' })
  return -not ($segments -contains '..')
}

function Read-P0JsonFile {
  param([string]$Path)
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Test-P0PlanContract {
  param([object]$Plan)
  $errors = [System.Collections.Generic.List[string]]::new()
  $required = @('plan_id','session_id','workflow_definition_version','contract_bundle_version','plan_schema_id','event_schema_id','artifact_lineage_schema_id','render_input_schema_id','renderer_version','template_version','runtime_mode','topic_count','final_delivery_count','steps')
  $allowed = $required
  foreach ($validationError in (Test-P0RequiredProperties $Plan $required 'plan')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-P0AllowedProperties $Plan $allowed 'plan')) { $errors.Add($validationError) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }

  $expected = [ordered]@{
    workflow_definition_version = 'p0-single-runtime-v0.2'
    contract_bundle_version = 'p0-contract-bundle-v0.2'
    plan_schema_id = 'taoge://schemas/p0/session-execution-plan/v0.2'
    event_schema_id = 'taoge://schemas/p0/execution-event/v0.2'
    artifact_lineage_schema_id = 'taoge://schemas/p0/artifact-lineage/v0.2'
    render_input_schema_id = 'taoge://schemas/final-delivery/typed-components/v0.2'
    renderer_version = 'final-delivery-renderer-v0.2'
    template_version = 'final-delivery-template-v0.2'
    runtime_mode = 'single'
  }
  foreach ($field in $expected.Keys) {
    if ([string]$Plan.$field -ne [string]$expected[$field]) { $errors.Add("plan_version_pin_invalid:$field") }
  }
  if ([int]$Plan.topic_count -ne 1 -or [int]$Plan.final_delivery_count -ne 1) { $errors.Add('plan_single_cardinality_invalid') }
  if (@($Plan.steps).Count -eq 0) { $errors.Add('plan_steps_empty') }

  $stepAllowed = @('step_id','step_kind','operation','requires_step_ids','requires_artifact_ids','produces_artifact_type','success_state','failure_route','retry_policy')
  $stepKinds = @('deterministic_tool','agent_required','human_gate','external_side_effect')
  $seen = @{}
  foreach ($step in @($Plan.steps)) {
    foreach ($validationError in (Test-P0RequiredProperties $step @('step_id','step_kind','failure_route','retry_policy') 'step')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-P0AllowedProperties $step $stepAllowed 'step')) { $errors.Add($validationError) }
    if ([string]::IsNullOrWhiteSpace([string]$step.step_id) -or $seen.ContainsKey([string]$step.step_id)) { $errors.Add('step_id_missing_or_duplicate') } else { $seen[[string]$step.step_id] = $true }
    if ($step.step_kind -notin $stepKinds) { $errors.Add("step_kind_invalid:$($step.step_id)") }
    if ($step.step_kind -eq 'deterministic_tool' -and [string]::IsNullOrWhiteSpace([string]$step.operation)) { $errors.Add("deterministic_operation_missing:$($step.step_id)") }
    if (-not (Test-P0HasProperty $step 'retry_policy')) { continue }
    $policy = $step.retry_policy
    foreach ($validationError in (Test-P0RequiredProperties $policy @('mode','automatic_retries','max_attempts','idempotency_scope') 'retry_policy')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-P0AllowedProperties $policy @('mode','automatic_retries','max_attempts','idempotency_scope') 'retry_policy')) { $errors.Add($validationError) }
    if ($policy.idempotency_scope -ne 'session_step_input_digest') { $errors.Add("retry_idempotency_scope_invalid:$($step.step_id)") }
    $automatic = [int]$policy.automatic_retries
    $maxAttempts = [int]$policy.max_attempts
    if ($step.step_kind -eq 'deterministic_tool') {
      if ($automatic -lt 0 -or $automatic -gt 1 -or $maxAttempts -ne ($automatic + 1) -or $policy.mode -notin @('never','bounded')) { $errors.Add("deterministic_retry_policy_invalid:$($step.step_id)") }
    } else {
      if ($automatic -ne 0 -or $maxAttempts -ne 1) { $errors.Add("nondeterministic_auto_retry_forbidden:$($step.step_id)") }
      if ($step.step_kind -eq 'external_side_effect' -and $policy.mode -notin @('human_decision_required','reconcile_first')) { $errors.Add("external_retry_policy_invalid:$($step.step_id)") }
      if ($step.step_kind -in @('agent_required','human_gate') -and $policy.mode -ne 'never') { $errors.Add("waiting_step_retry_policy_invalid:$($step.step_id)") }
    }
  }
  foreach ($step in @($Plan.steps)) {
    $dependencies = if (Test-P0HasProperty $step 'requires_step_ids') { @($step.requires_step_ids) } else { @() }
    foreach ($dependency in $dependencies) {
      if ([string]::IsNullOrWhiteSpace([string]$dependency)) { continue }
      if (-not $seen.ContainsKey([string]$dependency)) { $errors.Add("required_step_missing:$($step.step_id):$dependency") }
      if ([string]$dependency -eq [string]$step.step_id) { $errors.Add("step_self_dependency:$($step.step_id)") }
    }
  }
  return [object[]]$errors.ToArray()
}

function Test-P0EventLogContract {
  param([object[]]$Events)
  $errors = [System.Collections.Generic.List[string]]::new()
  if (@($Events).Count -eq 0) { return @('event_log_empty') }
  $required = @('event_id','event_type','event_schema_id','event_source','session_id','subject_id','step_id','sequence_no','previous_event_id','occurred_at','recorded_at','causation_event_id','correlation_id','idempotency_key','attempt_no','privacy_class','state_before','state_after','payload_digest')
  $allowed = $required + @('execution_attempt_id','input_digest','output_artifact_ids','result_code','safe_summary','failure')
  $sources = @('runner','agent_recorder','human_recorder','external_recorder','reconciler')
  $privacy = @('local_private','support_safe','public_sample')
  $states = @('ready','running','waiting_agent','waiting_human','waiting_external','succeeded','failed','blocked','skipped','not_invoked','outcome_unknown','attempt_interrupted','cancel_requested','cancelled','cancel_pending_external','superseded_after_cancel')
  $eventIds = @{}
  $idempotency = @{}
  $previous = $null
  $index = 0
  foreach ($event in @($Events)) {
    $index++
    foreach ($validationError in (Test-P0RequiredProperties $event $required 'event')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-P0AllowedProperties $event $allowed 'event')) { $errors.Add($validationError) }
    if (-not (Test-P0HasProperty $event 'event_id')) { continue }
    if ($eventIds.ContainsKey([string]$event.event_id)) { $errors.Add("event_id_duplicate:$($event.event_id)") } else { $eventIds[[string]$event.event_id] = $true }
    if ([int]$event.sequence_no -ne $index) { $errors.Add("event_sequence_conflict:$($event.event_id)") }
    if ($index -eq 1) {
      if ($null -ne $event.previous_event_id -and -not [string]::IsNullOrWhiteSpace([string]$event.previous_event_id)) { $errors.Add("event_previous_invalid:$($event.event_id)") }
    } elseif ([string]$event.previous_event_id -ne [string]$previous) { $errors.Add("event_previous_invalid:$($event.event_id)") }
    $previous = [string]$event.event_id
    if ($event.event_schema_id -ne 'taoge://schemas/p0/execution-event/v0.2') { $errors.Add("event_schema_invalid:$($event.event_id)") }
    if ($event.event_type -notmatch '^[a-z0-9_.-]+\.v[0-9]+$') { $errors.Add("event_type_invalid:$($event.event_id)") }
    if ($event.event_source -notin $sources) { $errors.Add("event_source_invalid:$($event.event_id)") }
    if ($event.privacy_class -notin $privacy) { $errors.Add("event_privacy_class_invalid:$($event.event_id)") }
    if ($event.state_before -notin $states -or $event.state_after -notin $states) { $errors.Add("event_state_invalid:$($event.event_id)") }
    if (-not (Test-P0DateTime $event.occurred_at) -or -not (Test-P0DateTime $event.recorded_at)) { $errors.Add("event_time_invalid:$($event.event_id)") }
    if (-not (Test-P0Digest $event.payload_digest)) { $errors.Add("event_payload_digest_invalid:$($event.event_id)") }
    if ((Test-P0HasProperty $event 'input_digest') -and -not (Test-P0Digest $event.input_digest)) { $errors.Add("event_input_digest_invalid:$($event.event_id)") }
    $idempotencyKey = "$($event.event_type)|$($event.idempotency_key)"
    if ($idempotency.ContainsKey($idempotencyKey) -and $idempotency[$idempotencyKey] -ne [string]$event.payload_digest) { $errors.Add("idempotency_conflict:$($event.event_id)") } else { $idempotency[$idempotencyKey] = [string]$event.payload_digest }
    if ($event.state_after -in @('failed','outcome_unknown') -and -not (Test-P0HasProperty $event 'failure')) { $errors.Add("event_failure_detail_missing:$($event.event_id)") }
    if (Test-P0HasProperty $event 'failure') {
      $failure = $event.failure
      foreach ($validationError in (Test-P0RequiredProperties $failure @('failure_category','retryability','attempt_no','max_attempts','recovery_action') 'failure')) { $errors.Add($validationError) }
      foreach ($validationError in (Test-P0AllowedProperties $failure @('failure_category','retryability','attempt_no','max_attempts','next_retry_not_before','recovery_action') 'failure')) { $errors.Add($validationError) }
      if ($event.state_after -eq 'outcome_unknown' -and $failure.retryability -ne 'reconcile_first') { $errors.Add("outcome_unknown_must_reconcile:$($event.event_id)") }
    }
  }
  return [object[]]$errors.ToArray()
}

function Test-P0LineageContract {
  param([object]$Document)
  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($validationError in (Test-P0RequiredProperties $Document @('schema_id','schema_version','artifact_lineage_manifest') 'lineage_document')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-P0AllowedProperties $Document @('schema_id','schema_version','artifact_lineage_manifest') 'lineage_document')) { $errors.Add($validationError) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Document.schema_id -ne 'taoge://schemas/p0/artifact-lineage/v0.2' -or $Document.schema_version -ne '0.2') { $errors.Add('lineage_schema_invalid') }
  $lineage = $Document.artifact_lineage_manifest
  $required = @('artifact_id','artifact_type','producer_event_id','input_artifact_ids','materialization_status','quality_status','delivery_eligibility','path','sha256','check_ids')
  $allowed = $required + @('source_artifact_id','source_session_id','source_content_digest','source_beat_digest')
  foreach ($validationError in (Test-P0RequiredProperties $lineage $required 'lineage')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-P0AllowedProperties $lineage $allowed 'lineage')) { $errors.Add($validationError) }
  if (-not (Test-P0RelativePath $lineage.path)) { $errors.Add('lineage_path_unsafe') }
  if (-not (Test-P0Digest $lineage.sha256)) { $errors.Add('lineage_sha256_invalid') }
  if ($lineage.materialization_status -notin @('absent','pending','materialized','integrity_failed')) { $errors.Add('lineage_materialization_status_invalid') }
  if ($lineage.quality_status -notin @('not_run','pass','pass_with_warnings','fail','human_review_required')) { $errors.Add('lineage_quality_status_invalid') }
  if ($lineage.delivery_eligibility -notin @('blocked','trace_only','preview_only','ready_for_delivery','ready_for_upload')) { $errors.Add('lineage_delivery_eligibility_invalid') }
  if ($lineage.delivery_eligibility -eq 'ready_for_upload' -and ($lineage.materialization_status -ne 'materialized' -or $lineage.quality_status -ne 'pass' -or @($lineage.check_ids).Count -eq 0)) { $errors.Add('ready_for_upload_gate_invalid') }
  return [object[]]$errors.ToArray()
}

function Test-P0ArtifactCheckSetContract {
  param([object]$Document)
  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($validationError in (Test-P0RequiredProperties $Document @('schema_id','schema_version','check_set_id','checks') 'check_set')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-P0AllowedProperties $Document @('schema_id','schema_version','check_set_id','checks') 'check_set')) { $errors.Add($validationError) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Document.schema_id -ne 'taoge://schemas/p0/artifact-check-set/v0.2' -or $Document.schema_version -ne '0.2') { $errors.Add('check_set_schema_invalid') }
  if (@($Document.checks).Count -eq 0) { $errors.Add('check_set_empty') }
  $ids = @{}
  foreach ($check in @($Document.checks)) {
    $required = @('check_id','check_version','target_artifact_id','status','severity','evidence_path','executed_at','execution_source')
    foreach ($validationError in (Test-P0RequiredProperties $check $required 'artifact_check')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-P0AllowedProperties $check $required 'artifact_check')) { $errors.Add($validationError) }
    if ($ids.ContainsKey([string]$check.check_id)) { $errors.Add("artifact_check_id_duplicate:$($check.check_id)") } else { $ids[[string]$check.check_id] = $true }
    if ($check.status -notin @('pass','pass_with_warnings','fail','not_run')) { $errors.Add("artifact_check_status_invalid:$($check.check_id)") }
    if ($check.severity -notin @('blocker','warning','info')) { $errors.Add("artifact_check_severity_invalid:$($check.check_id)") }
    if ($check.execution_source -notin @('deterministic_tool','agent_review','human_review')) { $errors.Add("artifact_check_source_invalid:$($check.check_id)") }
    if ($check.status -eq 'not_run') {
      if ($null -ne $check.evidence_path -or $null -ne $check.executed_at) { $errors.Add("artifact_check_not_run_has_evidence:$($check.check_id)") }
    } else {
      if (-not (Test-P0RelativePath $check.evidence_path) -or -not (Test-P0DateTime $check.executed_at)) { $errors.Add("artifact_check_evidence_invalid:$($check.check_id)") }
    }
  }
  return [object[]]$errors.ToArray()
}

function Test-P0CardBase {
  param([object]$Card, [string]$ExpectedType)
  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($field in @('card_id','card_type','display_order','status','source_artifact_ids')) {
    if (-not (Test-P0HasProperty $Card $field)) { $errors.Add("card_required_field_missing:${ExpectedType}:$field") }
  }
  if ((Test-P0HasProperty $Card 'card_type') -and $Card.card_type -ne $ExpectedType) { $errors.Add("card_type_invalid:$ExpectedType") }
  if ((Test-P0HasProperty $Card 'display_order') -and [int]$Card.display_order -lt 1) { $errors.Add("card_display_order_invalid:$ExpectedType") }
  if ((Test-P0HasProperty $Card 'source_artifact_ids') -and @($Card.source_artifact_ids).Count -eq 0) { $errors.Add("card_source_artifacts_empty:$ExpectedType") }
  return [object[]]$errors.ToArray()
}

function Test-P0AssetCard {
  param([object]$Card, [string]$ExpectedType)
  $errors = [System.Collections.Generic.List[string]]::new()
  $status = [string]$Card.asset_status
  if ($status -notin @('generated','reused_verified','pending_external','generation_failed','manual_required','rejected')) { $errors.Add("asset_status_invalid:$ExpectedType") }
  if ($status -in @('generated','reused_verified')) {
    foreach ($field in @('asset_id','relative_path','sha256','sidecar_path')) {
      if (-not (Test-P0HasProperty $Card $field) -or [string]::IsNullOrWhiteSpace([string]$Card.$field)) { $errors.Add("asset_materialized_field_missing:${ExpectedType}:$field") }
    }
    if ((Test-P0HasProperty $Card 'relative_path') -and -not (Test-P0RelativePath $Card.relative_path)) { $errors.Add("asset_path_unsafe:$ExpectedType") }
    if ((Test-P0HasProperty $Card 'sidecar_path') -and -not (Test-P0RelativePath $Card.sidecar_path)) { $errors.Add("asset_sidecar_path_unsafe:$ExpectedType") }
    if ((Test-P0HasProperty $Card 'sha256') -and -not (Test-P0Digest $Card.sha256)) { $errors.Add("asset_sha256_invalid:$ExpectedType") }
  }
  if ($status -in @('pending_external','generation_failed') -and (-not (Test-P0HasProperty $Card 'prompt_text') -or [string]::IsNullOrWhiteSpace([string]$Card.prompt_text))) { $errors.Add("asset_prompt_missing:$ExpectedType") }
  return [object[]]$errors.ToArray()
}

function Test-P0RenderInputContract {
  param([object]$Document)
  $errors = [System.Collections.Generic.List[string]]::new()
  $required = @('schema_id','schema_version','render_input_id','final_delivery_id','account_name','session_id','research_run_id','template_version','generated_at','topic','script_card','production_status','cover_cards','pip_cards','platform_cards','trace_cards','action_cards','source_artifact_ids')
  foreach ($validationError in (Test-P0RequiredProperties $Document $required 'render_input')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-P0AllowedProperties $Document ($required + @('cover_empty_reason','pip_empty_reason')) 'render_input')) { $errors.Add($validationError) }
  foreach ($name in (Get-P0PropertyNames $Document)) { if ($name -match '_html$') { $errors.Add("render_input_html_fragment_forbidden:$name") } }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Document.schema_id -ne 'taoge://schemas/final-delivery/typed-components/v0.2' -or $Document.schema_version -ne 'typed_components_v0.2') { $errors.Add('render_input_schema_invalid') }
  if ($Document.template_version -ne 'final-delivery-template-v0.2') { $errors.Add('render_input_template_version_invalid') }
  if (-not (Test-P0DateTime $Document.generated_at)) { $errors.Add('render_input_generated_at_invalid') }
  foreach ($validationError in (Test-P0RequiredProperties $Document.topic @('title','why_now','content_format') 'topic')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-P0AllowedProperties $Document.topic @('title','why_now','content_format') 'topic')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-P0RequiredProperties $Document.script_card @('card_id','card_type','status','source_artifact_ids','final_text','copy_label','source_draft_id') 'script_card')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-P0AllowedProperties $Document.script_card @('card_id','card_type','status','source_artifact_ids','final_text','copy_label','source_draft_id','hook_text','estimated_duration_seconds','revision_note') 'script_card')) { $errors.Add($validationError) }
  if ($Document.script_card.card_type -ne 'script') { $errors.Add('script_card_type_invalid') }
  $productionFields = @('image_assets_status','cover_quality_status','overall_quality_status','delivery_readiness','derived_by','warning_codes')
  foreach ($validationError in (Test-P0RequiredProperties $Document.production_status $productionFields 'production_status')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-P0AllowedProperties $Document.production_status $productionFields 'production_status')) { $errors.Add($validationError) }
  if ($Document.production_status.derived_by -ne 'derive_delivery_readiness') { $errors.Add('delivery_readiness_not_derived') }

  $cardIds = @{}
  $platforms = @{}
  $coverAllowed = @('card_id','card_type','display_order','status','source_artifact_ids','cover_role','platform','title_text','asset_status','asset_id','relative_path','sha256','sidecar_path','prompt_text','usage_note')
  if (@($Document.cover_cards).Count -eq 0 -and (-not (Test-P0HasProperty $Document 'cover_empty_reason') -or [string]::IsNullOrWhiteSpace([string]$Document.cover_empty_reason))) { $errors.Add('cover_cards_empty_reason_missing') }
  foreach ($card in @($Document.cover_cards)) {
    foreach ($validationError in (Test-P0CardBase $card 'cover')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-P0AllowedProperties $card $coverAllowed 'cover_card')) { $errors.Add($validationError) }
    foreach ($field in @('cover_role','platform','asset_status','usage_note')) { if (-not (Test-P0HasProperty $card $field)) { $errors.Add("cover_card_required_field_missing:$field") } }
    foreach ($validationError in (Test-P0AssetCard $card 'cover')) { $errors.Add($validationError) }
    if ($card.cover_role -notin @('platform_cover','background','prompt_only')) { $errors.Add('cover_role_invalid') }
    if ($cardIds.ContainsKey([string]$card.card_id)) { $errors.Add("card_id_duplicate:$($card.card_id)") } else { $cardIds[[string]$card.card_id] = $true }
  }
  $pipAllowed = @('card_id','card_type','display_order','status','source_artifact_ids','placement','narrative_function','asset_status','asset_id','relative_path','sha256','sidecar_path','prompt_text','preview_alt')
  if (@($Document.pip_cards).Count -eq 0 -and (-not (Test-P0HasProperty $Document 'pip_empty_reason') -or [string]::IsNullOrWhiteSpace([string]$Document.pip_empty_reason))) { $errors.Add('pip_cards_empty_reason_missing') }
  foreach ($card in @($Document.pip_cards)) {
    foreach ($validationError in (Test-P0CardBase $card 'picture_in_picture')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-P0AllowedProperties $card $pipAllowed 'pip_card')) { $errors.Add($validationError) }
    foreach ($field in @('placement','narrative_function','asset_status','preview_alt')) { if (-not (Test-P0HasProperty $card $field)) { $errors.Add("pip_card_required_field_missing:$field") } }
    foreach ($validationError in (Test-P0AssetCard $card 'picture_in_picture')) { $errors.Add($validationError) }
    if ($cardIds.ContainsKey([string]$card.card_id)) { $errors.Add("card_id_duplicate:$($card.card_id)") } else { $cardIds[[string]$card.card_id] = $true }
  }
  $platformAllowed = @('card_id','card_type','display_order','status','source_artifact_ids','platform','cover_title','video_title','publish_description','hashtags','publish_readiness')
  if (@($Document.platform_cards).Count -eq 0) { $errors.Add('platform_cards_empty') }
  foreach ($card in @($Document.platform_cards)) {
    foreach ($validationError in (Test-P0CardBase $card 'platform')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-P0RequiredProperties $card @('platform','cover_title','video_title','publish_description','hashtags','publish_readiness') 'platform_card')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-P0AllowedProperties $card $platformAllowed 'platform_card')) { $errors.Add($validationError) }
    if ($platforms.ContainsKey([string]$card.platform)) { $errors.Add("platform_card_duplicate:$($card.platform)") } else { $platforms[[string]$card.platform] = $true }
    if (@($card.hashtags).Count -eq 0) { $errors.Add("platform_hashtags_empty:$($card.platform)") }
    if ($cardIds.ContainsKey([string]$card.card_id)) { $errors.Add("card_id_duplicate:$($card.card_id)") } else { $cardIds[[string]$card.card_id] = $true }
  }
  $traceAllowed = @('card_id','card_type','display_order','status','source_artifact_ids','artifact_type','artifact_id','label','relative_path','materialization_status','sha256')
  if (@($Document.trace_cards).Count -lt 5) { $errors.Add('trace_cards_minimum_not_met') }
  foreach ($card in @($Document.trace_cards)) {
    foreach ($validationError in (Test-P0CardBase $card 'trace')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-P0RequiredProperties $card @('artifact_type','artifact_id','label','relative_path','materialization_status') 'trace_card')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-P0AllowedProperties $card $traceAllowed 'trace_card')) { $errors.Add($validationError) }
    if (-not (Test-P0RelativePath $card.relative_path)) { $errors.Add("trace_path_unsafe:$($card.card_id)") }
    if ($cardIds.ContainsKey([string]$card.card_id)) { $errors.Add("card_id_duplicate:$($card.card_id)") } else { $cardIds[[string]$card.card_id] = $true }
  }
  $actionAllowed = @('card_id','card_type','display_order','status','source_artifact_ids','action','label','instruction','reply_example','target_artifact_id','is_primary')
  if (@($Document.action_cards).Count -eq 0) { $errors.Add('action_cards_empty') }
  foreach ($card in @($Document.action_cards)) {
    foreach ($validationError in (Test-P0CardBase $card 'action')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-P0RequiredProperties $card @('action','label','instruction','reply_example') 'action_card')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-P0AllowedProperties $card $actionAllowed 'action_card')) { $errors.Add($validationError) }
    if ($card.action -notin @('publish_manually','revise_copy','revise_visual','archive_session','export_handoff')) { $errors.Add("action_invalid:$($card.action)") }
    if ($card.action -in @('revise_copy','revise_visual') -and (-not (Test-P0HasProperty $card 'target_artifact_id') -or [string]::IsNullOrWhiteSpace([string]$card.target_artifact_id))) { $errors.Add("action_target_missing:$($card.action)") }
    if ($cardIds.ContainsKey([string]$card.card_id)) { $errors.Add("card_id_duplicate:$($card.card_id)") } else { $cardIds[[string]$card.card_id] = $true }
  }
  return [object[]]$errors.ToArray()
}

function Test-P0CompatibilityMatrixContract {
  param([object]$Document)
  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($validationError in (Test-P0RequiredProperties $Document @('matrix_id','matrix_version','current_workflow_definition_version','entries') 'compatibility_matrix')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-P0AllowedProperties $Document @('matrix_id','matrix_version','current_workflow_definition_version','entries') 'compatibility_matrix')) { $errors.Add($validationError) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Document.current_workflow_definition_version -ne 'p0-single-runtime-v0.2') { $errors.Add('compatibility_current_version_invalid') }
  $requiredPairs = @('p0-runtime-v0.1|p0-single-runtime-v0.2','p0-single-runtime-v0.2|p0-single-runtime-v0.2')
  $seen = @{}
  foreach ($entry in @($Document.entries)) {
    $fields = @('from_version','to_version','replay_readable','resume_executable','renderable','migration_required','reason')
    foreach ($validationError in (Test-P0RequiredProperties $entry $fields 'compatibility_entry')) { $errors.Add($validationError) }
    foreach ($validationError in (Test-P0AllowedProperties $entry $fields 'compatibility_entry')) { $errors.Add($validationError) }
    $seen["$($entry.from_version)|$($entry.to_version)"] = $entry
  }
  foreach ($pair in $requiredPairs) { if (-not $seen.ContainsKey($pair)) { $errors.Add("compatibility_pair_missing:$pair") } }
  if ($seen.ContainsKey($requiredPairs[0])) {
    $legacy = $seen[$requiredPairs[0]]
    if (-not $legacy.replay_readable -or $legacy.resume_executable -or $legacy.renderable -or -not $legacy.migration_required) { $errors.Add('compatibility_legacy_policy_invalid') }
  }
  if ($seen.ContainsKey($requiredPairs[1])) {
    $native = $seen[$requiredPairs[1]]
    if (-not $native.replay_readable -or -not $native.resume_executable -or -not $native.renderable -or $native.migration_required) { $errors.Add('compatibility_native_policy_invalid') }
  }
  return [object[]]$errors.ToArray()
}
