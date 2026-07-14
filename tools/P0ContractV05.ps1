Set-StrictMode -Version 2.0

if (-not (Get-Command Test-P0RenderInputV04Contract -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'P0ContractV04.ps1')
}

function ConvertTo-P0V04CompatibilityView {
  param([object]$Document)
  $copy = (($Document | ConvertTo-Json -Depth 60) | ConvertFrom-Json)
  foreach ($name in @('content_structure_card','content_beat_cards','script_review_card','visual_coverage_summary')) {
    $copy.PSObject.Properties.Remove($name)
  }
  foreach ($name in @('script_readiness','visual_coverage_status','alignment_status')) {
    $copy.production_status.PSObject.Properties.Remove($name)
  }
  $copy.schema_id = 'taoge://schemas/final-delivery/typed-components/v0.4'
  $copy.schema_version = 'typed_components_v0.4'
  $copy.template_version = 'final-delivery-template-v0.4'
  $copy.production_status.derived_by = 'derive_delivery_readiness_v0.4'
  return $copy
}

function Get-P0V5DeliveryReadiness {
  param([object]$Document)
  $view = ConvertTo-P0V04CompatibilityView $Document
  $base = Get-P0V4DeliveryReadiness $view
  $scope = [string]$base.platform_delivery_scope_status
  if ($Document.content_structure_card.status -notin @('ready','ready_with_warnings')) { $scope = 'not_publish_ready' }
  if ($Document.script_review_card.script_readiness -notin @('ready','ready_with_warnings')) { $scope = 'not_publish_ready' }
  if ($Document.visual_coverage_summary.coverage_completeness_status -ne 'complete') { $scope = 'not_publish_ready' }
  if ($Document.visual_coverage_summary.visual_delivery_readiness -notin @('ready','ready_with_warnings')) { $scope = 'not_publish_ready' }
  if ($Document.script_review_card.alignment_status -notin @('pass','pass_with_warnings')) { $scope = 'not_publish_ready' }
  return [pscustomobject]@{
    delivery_readiness = $scope
    platform_delivery_scope_status = $scope
    warning_codes = [object[]]@($base.warning_codes | Sort-Object -Unique)
  }
}

function Test-P0RenderInputV05Contract {
  param([object]$Document)
  $errors = [System.Collections.Generic.List[string]]::new()
  $required = @('schema_id','schema_version','render_input_id','final_delivery_id','account_name','session_id','research_run_id','template_version','generated_at','topic','content_structure_card','content_beat_cards','script_review_card','visual_coverage_summary','script_card','production_status','delivery_revision','run_provenance','duration_estimate','warning_items','cover_cards','visual_insert_cards','platform_cards','platform_delivery_units','trace_cards','action_cards','source_artifact_ids')
  foreach ($error in (Test-P0RequiredProperties $Document $required 'render_input_v05')) { $errors.Add($error) }
  foreach ($error in (Test-P0AllowedProperties $Document ($required + @('visual_insert_empty_reason')) 'render_input_v05')) { $errors.Add($error) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Document.schema_id -ne 'taoge://schemas/final-delivery/typed-components/v0.5' -or $Document.schema_version -ne 'typed_components_v0.5' -or $Document.template_version -ne 'final-delivery-template-v0.5') { $errors.Add('render_input_v05_version_invalid') }

  $view = ConvertTo-P0V04CompatibilityView $Document
  foreach ($error in (Test-P0RenderInputV04Contract $view)) { $errors.Add("v04_base:$error") }

  $productionFields = @('image_assets_status','cover_quality_status','overall_quality_status','script_readiness','visual_coverage_status','alignment_status','delivery_readiness','platform_delivery_scope_status','derived_by','warning_codes')
  foreach ($error in (Test-P0RequiredProperties $Document.production_status $productionFields 'production_status_v05')) { $errors.Add($error) }
  foreach ($error in (Test-P0AllowedProperties $Document.production_status $productionFields 'production_status_v05')) { $errors.Add($error) }
  if ($Document.production_status.derived_by -ne 'derive_delivery_readiness_v0.5') { $errors.Add('delivery_readiness_v05_not_derived') }

  $structure = $Document.content_structure_card
  $structureFields = @('card_id','card_type','status','source_artifact_ids','structure_plan_id','selected_strategy_ref','audience_entry_state','audience_exit_state','core_promise','stages','warning_items')
  foreach ($error in (Test-P0RequiredProperties $structure $structureFields 'structure_card_v05')) { $errors.Add($error) }
  foreach ($error in (Test-P0AllowedProperties $structure $structureFields 'structure_card_v05')) { $errors.Add($error) }
  if ($structure.card_type -ne 'content_structure' -or $structure.status -notin @('ready','ready_with_warnings')) { $errors.Add('structure_card_v05_not_ready') }
  $stageIds = @{}; $expectedStageOrder = 1
  foreach ($stage in @($structure.stages | Sort-Object order)) {
    foreach ($error in (Test-P0RequiredProperties $stage @('stage_id','order','purpose','implementation_status','beat_ids') 'structure_stage_v05')) { $errors.Add($error) }
    if ([int]$stage.order -ne $expectedStageOrder) { $errors.Add("structure_stage_v05_order_gap:$($stage.stage_id)") }
    $expectedStageOrder++
    if ($stageIds.ContainsKey([string]$stage.stage_id)) { $errors.Add("structure_stage_v05_duplicate:$($stage.stage_id)") } else { $stageIds[[string]$stage.stage_id] = $stage }
  }
  if ($stageIds.Count -eq 0) { $errors.Add('structure_stage_v05_empty') }

  $beatIds = @{}; $occurrenceIds = @{}; $expectedBeatOrder = 1
  $assetDispositions = @('generate_visual','create_deterministic_visual','use_source_evidence','use_existing_asset','manual_visual_required')
  foreach ($beat in @($Document.content_beat_cards | Sort-Object display_order)) {
    $fields = @('card_id','card_type','display_order','status','source_artifact_ids','beat_id','stage_id','source_excerpt','semantic_function','visual_disposition','visual_reason','visual_task_ids','occurrence_ids')
    foreach ($error in (Test-P0RequiredProperties $beat $fields 'beat_card_v05')) { $errors.Add($error) }
    foreach ($error in (Test-P0AllowedProperties $beat $fields 'beat_card_v05')) { $errors.Add($error) }
    if ([int]$beat.display_order -ne $expectedBeatOrder) { $errors.Add("beat_card_v05_order_gap:$($beat.beat_id)") }
    $expectedBeatOrder++
    if ($beatIds.ContainsKey([string]$beat.beat_id)) { $errors.Add("beat_card_v05_duplicate:$($beat.beat_id)") } else { $beatIds[[string]$beat.beat_id] = $beat }
    if (-not $stageIds.ContainsKey([string]$beat.stage_id)) { $errors.Add("beat_card_v05_stage_missing:$($beat.beat_id)") }
    if ($beat.visual_disposition -in $assetDispositions -and @($beat.visual_task_ids).Count -eq 0) { $errors.Add("beat_card_v05_task_missing:$($beat.beat_id)") }
    if ($beat.visual_disposition -eq 'reuse_visual_task' -and @($beat.visual_task_ids).Count -ne 1) { $errors.Add("beat_card_v05_reuse_invalid:$($beat.beat_id)") }
    foreach ($occurrenceId in @($beat.occurrence_ids)) {
      if ($occurrenceIds.ContainsKey([string]$occurrenceId)) { $errors.Add("beat_card_v05_occurrence_duplicate:$occurrenceId") } else { $occurrenceIds[[string]$occurrenceId] = $true }
    }
  }
  if ($beatIds.Count -eq 0) { $errors.Add('beat_card_v05_empty') }
  foreach ($stage in @($structure.stages)) {
    foreach ($beatId in @($stage.beat_ids)) { if (-not $beatIds.ContainsKey([string]$beatId) -or [string]$beatIds[[string]$beatId].stage_id -ne [string]$stage.stage_id) { $errors.Add("structure_stage_v05_beat_binding_invalid:$($stage.stage_id):$beatId") } }
  }

  $review = $Document.script_review_card
  $reviewFields = @('card_id','card_type','status','source_artifact_ids','script_design_review_id','content_revision_decision_id','alignment_review_id','script_readiness','alignment_status','issue_items')
  foreach ($error in (Test-P0RequiredProperties $review $reviewFields 'script_review_card_v05')) { $errors.Add($error) }
  foreach ($error in (Test-P0AllowedProperties $review $reviewFields 'script_review_card_v05')) { $errors.Add($error) }
  if ([string]$review.script_readiness -ne [string]$Document.production_status.script_readiness) { $errors.Add('script_readiness_v05_mismatch') }
  if ([string]$review.alignment_status -ne [string]$Document.production_status.alignment_status) { $errors.Add('alignment_status_v05_mismatch') }

  $coverage = $Document.visual_coverage_summary
  if ([string]$coverage.coverage_completeness_status -ne [string]$Document.production_status.visual_coverage_status) { $errors.Add('visual_coverage_status_v05_mismatch') }
  if ($coverage.coverage_completeness_status -eq 'complete' -and @($coverage.unresolved_beat_ids).Count -ne 0) { $errors.Add('visual_coverage_v05_false_complete') }
  $taskById = @{}
  foreach ($task in @($coverage.task_summaries)) {
    if ($taskById.ContainsKey([string]$task.visual_task_id)) { $errors.Add("visual_task_v05_duplicate:$($task.visual_task_id)") } else { $taskById[[string]$task.visual_task_id] = $task }
    if ($task.disposition -eq 'generate_visual') {
      if ($task.capture_mode -ne 'not_applicable' -or [int]$task.source_capture_attempt_count -ne 0) { $errors.Add("visual_task_v05_generate_route_invalid:$($task.visual_task_id)") }
    } elseif ([int]$task.provider_attempt_count -ne 0) { $errors.Add("visual_task_v05_provider_attempt_invalid:$($task.visual_task_id)") }
    if ($task.disposition -eq 'use_source_evidence') {
      if ($task.capture_mode -eq 'reuse_verified_capture' -and [int]$task.source_capture_attempt_count -ne 0) { $errors.Add("visual_task_v05_reused_capture_attempt_invalid:$($task.visual_task_id)") }
    } elseif ($task.capture_mode -ne 'not_applicable' -or [int]$task.source_capture_attempt_count -ne 0) { $errors.Add("visual_task_v05_capture_route_invalid:$($task.visual_task_id)") }
  }
  foreach ($beat in @($Document.content_beat_cards)) { foreach ($taskId in @($beat.visual_task_ids)) { if (-not $taskById.ContainsKey([string]$taskId)) { $errors.Add("beat_card_v05_task_unknown:$($beat.beat_id):$taskId") } } }
  foreach ($taskId in $taskById.Keys) { if (@($Document.content_beat_cards | Where-Object { @($_.visual_task_ids) -contains $taskId }).Count -eq 0) { $errors.Add("visual_task_v05_unreferenced:$taskId") } }

  $counts = $coverage.counts
  $derived = $taskById.Count
  $materialized = @($coverage.task_summaries | Where-Object { $_.asset_status -eq 'materialized' }).Count
  $providerTasks = @($coverage.task_summaries | Where-Object { $_.disposition -eq 'generate_visual' }).Count
  $providerAttempts = 0; foreach ($task in @($coverage.task_summaries)) { $providerAttempts += [int]$task.provider_attempt_count }
  $captureTasks = @($coverage.task_summaries | Where-Object { $_.disposition -eq 'use_source_evidence' -and $_.capture_mode -eq 'new_capture' }).Count
  $captureAttempts = 0; foreach ($task in @($coverage.task_summaries)) { $captureAttempts += [int]$task.source_capture_attempt_count }
  $expectedCounts = [ordered]@{derived_visual_asset_count=$derived;materialized_visual_asset_count=$materialized;provider_generation_task_count=$providerTasks;provider_generation_attempt_count=$providerAttempts;source_capture_task_count=$captureTasks;source_capture_attempt_count=$captureAttempts;visual_insert_occurrence_count=$occurrenceIds.Count;platform_rendition_count=@($Document.platform_delivery_units).Count;cover_asset_count=@($Document.cover_cards).Count}
  foreach ($name in $expectedCounts.Keys) { if ([int]$counts.$name -ne [int]$expectedCounts[$name]) { $errors.Add("visual_count_v05_mismatch:$name") } }
  if ($derived -eq 0 -and @($Document.content_beat_cards | Where-Object { $_.visual_disposition -ne 'talking_head_intentional' }).Count -ne 0) { $errors.Add('visual_zero_v05_invalid') }

  $expected = Get-P0V5DeliveryReadiness $Document
  if ([string]$Document.production_status.delivery_readiness -ne [string]$expected.delivery_readiness -or [string]$Document.production_status.platform_delivery_scope_status -ne [string]$expected.platform_delivery_scope_status) { $errors.Add("delivery_scope_v05_derivation_mismatch:$($expected.delivery_readiness)") }
  if (@($Document.trace_cards).Count -lt 9) { $errors.Add('trace_cards_v05_insufficient') }
  return [object[]]$errors.ToArray()
}
