Set-StrictMode -Version 2.0

if (-not (Get-Command Get-R3PlatformDeliveryScopeStatus -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'R3VisualPresentation.ps1')
}

function Get-P0V4DeliveryReadiness {
  param([object]$Document)
  $warnings = [System.Collections.Generic.List[string]]::new()
  foreach ($warning in @($Document.warning_items | Where-Object { $_.resolution_status -ne 'resolved' })) { $warnings.Add([string]$warning.warning_code) }
  $scope = Get-R3PlatformDeliveryScopeStatus @($Document.platform_delivery_units)
  if ($Document.production_status.overall_quality_status -eq 'fail') { $scope = 'not_publish_ready' }
  return [pscustomobject]@{
    delivery_readiness = $scope
    platform_delivery_scope_status = $scope
    warning_codes = [object[]]@($warnings.ToArray() | Sort-Object -Unique)
  }
}

function Test-P0V4Rect {
  param([object]$Rect,[string]$Prefix)
  return @(Test-R3VPNormalizedRect $Rect $Prefix)
}

function Test-P0RenderInputV04Contract {
  param([object]$Document)
  $errors = [System.Collections.Generic.List[string]]::new()
  $required = @('schema_id','schema_version','render_input_id','final_delivery_id','account_name','session_id','research_run_id','template_version','generated_at','topic','script_card','production_status','delivery_revision','run_provenance','duration_estimate','warning_items','cover_cards','visual_insert_cards','platform_cards','platform_delivery_units','trace_cards','action_cards','source_artifact_ids')
  foreach ($error in (Test-P0RequiredProperties $Document $required 'render_input_v04')) { $errors.Add($error) }
  foreach ($error in (Test-P0AllowedProperties $Document ($required + @('visual_insert_empty_reason')) 'render_input_v04')) { $errors.Add($error) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Document.schema_id -ne 'taoge://schemas/final-delivery/typed-components/v0.4' -or $Document.schema_version -ne 'typed_components_v0.4' -or $Document.template_version -ne 'final-delivery-template-v0.4') { $errors.Add('render_input_v04_version_invalid') }
  if (-not (Test-P0DateTime $Document.generated_at)) { $errors.Add('render_input_v04_generated_at_invalid') }

  $productionFields = @('image_assets_status','cover_quality_status','overall_quality_status','delivery_readiness','platform_delivery_scope_status','derived_by','warning_codes')
  foreach ($error in (Test-P0RequiredProperties $Document.production_status $productionFields 'production_status_v04')) { $errors.Add($error) }
  foreach ($error in (Test-P0AllowedProperties $Document.production_status $productionFields 'production_status_v04')) { $errors.Add($error) }
  if ($Document.production_status.derived_by -ne 'derive_delivery_readiness_v0.4') { $errors.Add('delivery_readiness_v04_not_derived') }
  $scopeValues = @('ready_all_target_platforms','primary_ready_secondary_pending','not_publish_ready')
  if ($Document.production_status.delivery_readiness -notin $scopeValues -or $Document.production_status.platform_delivery_scope_status -notin $scopeValues) { $errors.Add('delivery_scope_status_invalid') }
  if ([string]$Document.production_status.delivery_readiness -ne [string]$Document.production_status.platform_delivery_scope_status) { $errors.Add('delivery_scope_status_mismatch') }

  $revisionFields = @('delivery_revision_id','revision_no','revision_status','source_artifact_bindings','generated_view_paths','semantic_gate_status')
  foreach ($error in (Test-P0RequiredProperties $Document.delivery_revision $revisionFields 'delivery_revision_v04')) { $errors.Add($error) }
  foreach ($error in (Test-P0AllowedProperties $Document.delivery_revision ($revisionFields + @('supersedes_delivery_revision_id')) 'delivery_revision_v04')) { $errors.Add($error) }
  if ($Document.delivery_revision.revision_status -notin @('preparing','compiled','current','superseded','blocked') -or [int]$Document.delivery_revision.revision_no -lt 1) { $errors.Add('delivery_revision_v04_status_invalid') }
  if ($Document.delivery_revision.semantic_gate_status -notin @('pending','pass','blocked')) { $errors.Add('delivery_revision_v04_semantic_status_invalid') }
  foreach ($binding in @($Document.delivery_revision.source_artifact_bindings)) {
    foreach ($error in (Test-P0RequiredProperties $binding @('artifact_type','artifact_id','sha256') 'delivery_binding_v04')) { $errors.Add($error) }
    if (-not (Test-P0Digest $binding.sha256)) { $errors.Add("delivery_binding_v04_digest_invalid:$($binding.artifact_id)") }
  }
  $viewFields = @('final_html','final_script','final_visual_plan','final_platform_package','content_delivery_record','revision_manifest')
  foreach ($field in $viewFields) { if (-not (Test-P0HasProperty $Document.delivery_revision.generated_view_paths $field) -or -not (Test-P0RelativePath $Document.delivery_revision.generated_view_paths.$field)) { $errors.Add("delivery_view_v04_invalid:$field") } }

  $warningKeys = @{}; $activeWarnings = [System.Collections.Generic.List[string]]::new()
  foreach ($warning in @($Document.warning_items)) {
    $fields = @('warning_code','warning_category','severity','user_message','impact','recommended_action','source_artifact_id','resolution_status')
    foreach ($error in (Test-P0RequiredProperties $warning $fields 'warning_v04')) { $errors.Add($error) }
    $key = "$($warning.warning_code)|$($warning.source_artifact_id)"
    if ($warningKeys.ContainsKey($key)) { $errors.Add("warning_v04_duplicate:$key") } else { $warningKeys[$key] = $true }
    if ($warning.resolution_status -ne 'resolved') { $activeWarnings.Add([string]$warning.warning_code) }
  }
  if ((@($Document.production_status.warning_codes | Sort-Object -Unique) -join '|') -ne (@($activeWarnings.ToArray() | Sort-Object -Unique) -join '|')) { $errors.Add('warning_v04_union_mismatch') }

  $cardIds = @{}; $coverById = @{}
  $coverFields = @('card_id','card_type','display_order','status','source_artifact_ids','cover_role','cover_job_id','cover_rendition_id','rendition_revision','platform','platform_priority','surface_profile_id','surface_profile_version','surface_role','profile_evidence_status','adaptation_strategy','title_text','rendered_text','asset_status','asset_id','relative_path','sha256','sidecar_path','preview_evidence_type','preview_path','preview_sha256','visual_review_record_path','reviewer_type','visual_review_status','cover_delivery_status','usage_note')
  if (@($Document.cover_cards).Count -eq 0) { $errors.Add('cover_cards_v04_empty') }
  foreach ($card in @($Document.cover_cards)) {
    foreach ($error in (Test-P0RequiredProperties $card $coverFields 'cover_card_v04')) { $errors.Add($error) }
    foreach ($error in (Test-P0AllowedProperties $card $coverFields 'cover_card_v04')) { $errors.Add($error) }
    if ($card.card_type -ne 'cover' -or $card.cover_role -ne 'platform_cover') { $errors.Add("cover_card_v04_type_invalid:$($card.card_id)") }
    if ($card.platform_priority -notin @('primary','secondary')) { $errors.Add("cover_card_v04_priority_invalid:$($card.card_id)") }
    if ($card.preview_evidence_type -notin @('deterministic_surface_mock','manual_app_observed')) { $errors.Add("cover_card_v04_preview_type_invalid:$($card.card_id)") }
    if ($card.visual_review_status -notin @('pass','fail','not_reviewed') -or $card.cover_delivery_status -notin @('visual_pass','visual_fail','waiting_visual_review')) { $errors.Add("cover_card_v04_visual_status_invalid:$($card.card_id)") }
    $expectedCardStatus = switch ([string]$card.cover_delivery_status) { 'visual_pass' {'ready'} 'visual_fail' {'blocked'} default {'needs_action'} }
    if ([string]$card.status -ne $expectedCardStatus) { $errors.Add("cover_card_v04_status_derivation_invalid:$($card.card_id)") }
    if ($card.cover_delivery_status -eq 'visual_pass' -and ($card.visual_review_status -ne 'pass' -or $card.reviewer_type -notin @('codex_visual_review','human_visual_review'))) { $errors.Add("cover_card_v04_false_visual_pass:$($card.card_id)") }
    foreach ($field in @('sha256','preview_sha256')) { if (-not (Test-P0Digest $card.$field)) { $errors.Add("cover_card_v04_digest_invalid:$($card.card_id):$field") } }
    foreach ($field in @('relative_path','sidecar_path','preview_path','visual_review_record_path')) { if (-not (Test-P0RelativePath $card.$field)) { $errors.Add("cover_card_v04_path_invalid:$($card.card_id):$field") } }
    if ((ConvertTo-P0NormalizedDeliveryTitle $card.title_text) -ne (ConvertTo-P0NormalizedDeliveryTitle $card.rendered_text)) { $errors.Add("cover_card_v04_title_mismatch:$($card.card_id)") }
    if ($cardIds.ContainsKey([string]$card.card_id)) { $errors.Add("card_id_v04_duplicate:$($card.card_id)") } else { $cardIds[[string]$card.card_id] = $true }
    $coverById[[string]$card.card_id] = $card
  }

  $visualInsertFields = @('card_id','card_type','display_order','status','source_artifact_ids','visual_insert_task_id','image_task_id','presentation_mode','platform_surface_profile_id','video_canvas','visual_asset_canvas','placement_slot','aspect_ratio_verification_status','trigger_text','insert_after_text','insert_before_text','narrative_function','viewer_problem','asset_status','asset_id','relative_path','sha256','sidecar_path','prompt_path','generation_record_path','preview_alt','visual_text_summary','warning_codes')
  if (@($Document.visual_insert_cards).Count -eq 0 -and (-not (Test-P0HasProperty $Document 'visual_insert_empty_reason') -or [string]::IsNullOrWhiteSpace([string]$Document.visual_insert_empty_reason))) { $errors.Add('visual_insert_cards_empty_reason_missing') }
  foreach ($card in @($Document.visual_insert_cards)) {
    foreach ($error in (Test-P0RequiredProperties $card $visualInsertFields 'visual_insert_card_v04')) { $errors.Add($error) }
    foreach ($error in (Test-P0AllowedProperties $card $visualInsertFields 'visual_insert_card_v04')) { $errors.Add($error) }
    if ($card.card_type -ne 'visual_insert' -or $card.presentation_mode -notin @('full_frame_replace','speaker_plus_visual','split_screen','floating_card','source_evidence_card','background_plate')) { $errors.Add("visual_insert_card_type_invalid:$($card.card_id)") }
    foreach ($error in (Test-R3VPCanvas $card.video_canvas "visual_insert_card_video_canvas:$($card.card_id)")) { $errors.Add($error) }
    foreach ($error in (Test-R3VPCanvas $card.visual_asset_canvas "visual_insert_card_asset_canvas:$($card.card_id)")) { $errors.Add($error) }
    foreach ($error in (Test-P0V4Rect $card.placement_slot "visual_insert_card_slot:$($card.card_id)")) { $errors.Add($error) }
    if ($card.aspect_ratio_verification_status -ne 'pass') { $errors.Add("visual_insert_card_ratio_not_verified:$($card.card_id)") }
    foreach ($field in @('sha256')) { if (-not (Test-P0Digest $card.$field)) { $errors.Add("visual_insert_card_digest_invalid:$($card.card_id)") } }
    foreach ($field in @('relative_path','sidecar_path','prompt_path','generation_record_path')) { if (-not (Test-P0RelativePath $card.$field)) { $errors.Add("visual_insert_card_path_invalid:$($card.card_id):$field") } }
    if ($cardIds.ContainsKey([string]$card.card_id)) { $errors.Add("card_id_v04_duplicate:$($card.card_id)") } else { $cardIds[[string]$card.card_id] = $true }
  }

  $platformById = @{}
  $platformFields = @('card_id','card_type','display_order','status','source_artifact_ids','platform','platform_priority','cover_title','video_title','publish_description','hashtags','publish_readiness')
  foreach ($card in @($Document.platform_cards)) {
    foreach ($error in (Test-P0RequiredProperties $card $platformFields 'platform_card_v04')) { $errors.Add($error) }
    foreach ($error in (Test-P0AllowedProperties $card $platformFields 'platform_card_v04')) { $errors.Add($error) }
    if ($card.card_type -ne 'platform' -or $card.publish_readiness -notin @('ready','waiting_visual_review','blocked')) { $errors.Add("platform_card_v04_status_invalid:$($card.card_id)") }
    if ($cardIds.ContainsKey([string]$card.card_id)) { $errors.Add("card_id_v04_duplicate:$($card.card_id)") } else { $cardIds[[string]$card.card_id] = $true }
    $platformById[[string]$card.card_id] = $card
  }

  $unitFields = @('unit_id','display_order','platform','platform_label','platform_priority','platform_card_id','cover_card_id','surface_profile_id','cover_rendition_id','cover_title','rendered_cover_text','cover_asset_id','cover_asset_path','cover_sha256','cover_preview_path','cover_preview_sha256','adaptation_strategy','preview_evidence_type','visual_review_status','cover_delivery_status','video_title','publish_description','hashtags','publish_readiness')
  foreach ($unit in @($Document.platform_delivery_units)) {
    foreach ($error in (Test-P0RequiredProperties $unit $unitFields 'platform_unit_v04')) { $errors.Add($error) }
    foreach ($error in (Test-P0AllowedProperties $unit $unitFields 'platform_unit_v04')) { $errors.Add($error) }
    $platformCard = if ($platformById.ContainsKey([string]$unit.platform_card_id)) { $platformById[[string]$unit.platform_card_id] } else { $null }
    $coverCard = if ($coverById.ContainsKey([string]$unit.cover_card_id)) { $coverById[[string]$unit.cover_card_id] } else { $null }
    if ($null -eq $platformCard -or $null -eq $coverCard) { $errors.Add("platform_unit_v04_binding_missing:$($unit.unit_id)"); continue }
    foreach ($field in @('platform','platform_priority','cover_title','video_title','publish_description','publish_readiness')) { if ([string]$unit.$field -ne [string]$platformCard.$field) { $errors.Add("platform_unit_v04_platform_mismatch:$($unit.unit_id):$field") } }
    foreach ($pair in @(@('surface_profile_id','surface_profile_id'),@('cover_rendition_id','cover_rendition_id'),@('cover_asset_id','asset_id'),@('cover_asset_path','relative_path'),@('cover_sha256','sha256'),@('cover_preview_path','preview_path'),@('cover_preview_sha256','preview_sha256'),@('adaptation_strategy','adaptation_strategy'),@('preview_evidence_type','preview_evidence_type'),@('visual_review_status','visual_review_status'),@('cover_delivery_status','cover_delivery_status'))) { if ([string]$unit.($pair[0]) -ne [string]$coverCard.($pair[1])) { $errors.Add("platform_unit_v04_cover_mismatch:$($unit.unit_id):$($pair[0])") } }
    $expectedReadiness = switch ([string]$unit.cover_delivery_status) { 'visual_pass' {'ready'} 'visual_fail' {'blocked'} default {'waiting_visual_review'} }
    if ($unit.publish_readiness -ne $expectedReadiness) { $errors.Add("platform_unit_v04_readiness_false_success:$($unit.unit_id)") }
  }
  if (@($Document.platform_delivery_units).Count -ne @($Document.platform_cards).Count -or @($Document.platform_delivery_units).Count -ne @($Document.cover_cards).Count) { $errors.Add('platform_unit_v04_cardinality_mismatch') }
  if (@($Document.platform_delivery_units | Where-Object { $_.platform_priority -eq 'primary' }).Count -ne 1) { $errors.Add('platform_unit_v04_primary_count_invalid') }
  $expectedScope = Get-R3PlatformDeliveryScopeStatus @($Document.platform_delivery_units)
  if ($Document.production_status.overall_quality_status -eq 'fail') { $expectedScope = 'not_publish_ready' }
  if ($Document.production_status.delivery_readiness -ne $expectedScope) { $errors.Add("delivery_scope_v04_derivation_mismatch:$expectedScope") }

  if (@($Document.trace_cards).Count -lt 5 -or @($Document.action_cards).Count -eq 0) { $errors.Add('trace_or_action_cards_v04_insufficient') }
  foreach ($card in @($Document.trace_cards)) { if (-not (Test-P0RelativePath $card.relative_path)) { $errors.Add("trace_card_v04_path_invalid:$($card.card_id)") } }
  $allowedActions = @('publish_primary_manually','publish_all_manually','review_secondary_covers','revise_copy','revise_visual','archive_session','export_handoff')
  foreach ($card in @($Document.action_cards)) { if ($card.action -notin $allowedActions) { $errors.Add("action_v04_invalid:$($card.action)") } }
  if ($Document.production_status.delivery_readiness -eq 'not_publish_ready' -and @($Document.action_cards | Where-Object { $_.action -in @('publish_primary_manually','publish_all_manually') -and $_.is_primary }).Count -gt 0) { $errors.Add('action_v04_publish_primary_false_success') }
  if ($Document.production_status.delivery_readiness -eq 'primary_ready_secondary_pending' -and @($Document.action_cards | Where-Object { $_.action -eq 'publish_all_manually' }).Count -gt 0) { $errors.Add('action_v04_publish_all_false_success') }
  return [object[]]$errors.ToArray()
}
