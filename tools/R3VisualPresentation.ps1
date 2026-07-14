Set-StrictMode -Version 2.0

function Test-R3VPHasProperty {
  param([object]$Value, [string]$Name)
  return $null -ne $Value -and $Value.PSObject.Properties.Name -contains $Name
}

function Test-R3VPText {
  param([object]$Value)
  return -not [string]::IsNullOrWhiteSpace([string]$Value)
}

function Test-R3VPNormalizedRect {
  param([object]$Rect, [string]$Prefix)
  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($field in @('x','y','width','height')) {
    if (-not (Test-R3VPHasProperty $Rect $field)) { $errors.Add("${Prefix}_field_missing:$field") }
  }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  $x = [double]$Rect.x; $y = [double]$Rect.y; $width = [double]$Rect.width; $height = [double]$Rect.height
  if ($x -lt 0 -or $y -lt 0 -or $width -le 0 -or $height -le 0 -or ($x + $width) -gt 1.0000001 -or ($y + $height) -gt 1.0000001) {
    $errors.Add("${Prefix}_out_of_bounds")
  }
  return [object[]]$errors.ToArray()
}

function Get-R3VPGreatestCommonDivisor {
  param([int]$A, [int]$B)
  $left = [Math]::Abs($A); $right = [Math]::Abs($B)
  while ($right -ne 0) { $next = $left % $right; $left = $right; $right = $next }
  return $left
}

function Test-R3VPRatio {
  param([object]$Ratio, [string]$Prefix)
  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($field in @('ratio_width','ratio_height','orientation')) {
    if (-not (Test-R3VPHasProperty $Ratio $field)) { $errors.Add("${Prefix}_field_missing:$field") }
  }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  $width = [int]$Ratio.ratio_width; $height = [int]$Ratio.ratio_height
  if ($width -lt 1 -or $height -lt 1) { $errors.Add("${Prefix}_value_invalid"); return [object[]]$errors.ToArray() }
  if ((Get-R3VPGreatestCommonDivisor $width $height) -ne 1) { $errors.Add("${Prefix}_not_reduced") }
  $expected = if ($width -gt $height) { 'landscape' } elseif ($width -lt $height) { 'portrait' } else { 'square' }
  if ([string]$Ratio.orientation -ne $expected) { $errors.Add("${Prefix}_orientation_mismatch") }
  return [object[]]$errors.ToArray()
}

function Test-R3VPCanvas {
  param([object]$Canvas, [string]$Prefix)
  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($field in @('width_px','height_px','aspect_ratio')) {
    if (-not (Test-R3VPHasProperty $Canvas $field)) { $errors.Add("${Prefix}_field_missing:$field") }
  }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ([int]$Canvas.width_px -lt 1 -or [int]$Canvas.height_px -lt 1) { $errors.Add("${Prefix}_dimensions_invalid") }
  foreach ($error in (Test-R3VPRatio $Canvas.aspect_ratio "${Prefix}_ratio")) { $errors.Add($error) }
  if ($errors.Count -eq 0) {
    $ratio = $Canvas.aspect_ratio
    $cross = [Math]::Abs(([long]$Canvas.width_px * [long]$ratio.ratio_height) - ([long]$Canvas.height_px * [long]$ratio.ratio_width))
    $roundingTolerance = [Math]::Max([int]$ratio.ratio_width, [int]$ratio.ratio_height)
    if ($cross -gt $roundingTolerance) { $errors.Add("${Prefix}_ratio_dimensions_mismatch") }
  }
  return [object[]]$errors.ToArray()
}

function Test-R3VisualInsertTask {
  param([object]$Task)
  $errors = [System.Collections.Generic.List[string]]::new()
  $required = @('visual_insert_task_id','image_task_id','presentation_mode','video_canvas','visual_asset_canvas','placement_slot','aspect_ratio_verification_status')
  foreach ($field in $required) { if (-not (Test-R3VPHasProperty $Task $field)) { $errors.Add("visual_insert_field_missing:$field") } }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  $modes = @('full_frame_replace','speaker_plus_visual','split_screen','floating_card','source_evidence_card','background_plate')
  if ($Task.presentation_mode -notin $modes) { $errors.Add('visual_insert_presentation_mode_invalid') }
  foreach ($error in (Test-R3VPCanvas $Task.video_canvas 'visual_insert_video_canvas')) { $errors.Add($error) }
  foreach ($error in (Test-R3VPCanvas $Task.visual_asset_canvas 'visual_insert_asset_canvas')) { $errors.Add($error) }
  foreach ($error in (Test-R3VPNormalizedRect $Task.placement_slot 'visual_insert_slot')) { $errors.Add($error) }
  if ($Task.presentation_mode -eq 'full_frame_replace') {
    foreach ($field in @('x','y')) { if ([double]$Task.placement_slot.$field -ne 0) { $errors.Add('full_frame_slot_must_start_at_origin') } }
    foreach ($field in @('width','height')) { if ([double]$Task.placement_slot.$field -ne 1) { $errors.Add('full_frame_slot_must_fill_canvas') } }
  }
  if ($Task.aspect_ratio_verification_status -notin @('planned','pass','fail')) { $errors.Add('visual_insert_aspect_ratio_status_invalid') }
  return [object[]]$errors.ToArray()
}

function Test-R3CoverRenderPlan {
  param([object]$Plan)
  $errors = [System.Collections.Generic.List[string]]::new()
  $required = @(
    'schema_id','schema_version','cover_job_id','cover_rendition_id','rendition_revision','platform','platform_priority',
    'surface_profile_id','surface_profile_version','surface_role','profile_evidence_status','source_asset_id','source_path',
    'source_canvas','target_canvas','adaptation_strategy','focal_point','protected_regions','required_visual_element_ids',
    'crop_loss_justification','background_fill_spec','cover_title','title_safe_area','output_path','composition_record_path',
    'preview_path','preview_evidence_type','visual_review_record_path','rendition_status','next_skill'
  )
  foreach ($field in $required) { if (-not (Test-R3VPHasProperty $Plan $field)) { $errors.Add("cover_render_plan_field_missing:$field") } }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Plan.schema_id -ne 'taoge://schemas/r3/cover-render-plan/v0.1' -or $Plan.schema_version -ne '0.1') { $errors.Add('cover_render_plan_version_invalid') }
  if ([int]$Plan.rendition_revision -lt 1) { $errors.Add('cover_rendition_revision_invalid') }
  if ($Plan.platform_priority -notin @('primary','secondary')) { $errors.Add('cover_platform_priority_invalid') }
  if ($Plan.surface_role -notin @('feed_cover','profile_grid_cover','share_cover')) { $errors.Add('cover_surface_role_invalid') }
  if ($Plan.profile_evidence_status -notin @('official_verified','observed_verified','provisional_not_verified')) { $errors.Add('cover_profile_evidence_status_invalid') }
  foreach ($error in (Test-R3VPCanvas $Plan.source_canvas 'cover_source_canvas')) { $errors.Add($error) }
  foreach ($error in (Test-R3VPCanvas $Plan.target_canvas 'cover_target_canvas')) { $errors.Add($error) }
  foreach ($error in (Test-R3VPNormalizedRect $Plan.title_safe_area 'cover_title_safe_area')) { $errors.Add($error) }
  foreach ($field in @('x','y')) {
    if (-not (Test-R3VPHasProperty $Plan.focal_point $field) -or [double]$Plan.focal_point.$field -lt 0 -or [double]$Plan.focal_point.$field -gt 1) { $errors.Add("cover_focal_point_invalid:$field") }
  }
  $strategies = @('reuse_native','focal_crop','fit_pad','outpaint_extend','independent_generation','manual_required')
  if ($Plan.adaptation_strategy -notin $strategies) { $errors.Add('cover_adaptation_strategy_invalid') }
  if ($Plan.preview_evidence_type -ne 'deterministic_surface_mock') { $errors.Add('cover_plan_preview_must_be_deterministic_surface_mock') }
  if ($Plan.rendition_status -ne 'planned') { $errors.Add('cover_plan_initial_status_invalid') }
  if ($Plan.next_skill -ne 'cover-design-compiler') { $errors.Add('cover_plan_next_skill_invalid') }
  foreach ($field in @('source_path','output_path','composition_record_path','preview_path','visual_review_record_path')) {
    $value = [string]$Plan.$field
    if (-not (Test-R3VPText $value) -or [IO.Path]::IsPathRooted($value) -or $value -match '(^|[\\/])\.\.([\\/]|$)') { $errors.Add("cover_plan_relative_path_invalid:$field") }
  }
  if (-not (Test-R3VPText $Plan.cover_title)) { $errors.Add('cover_title_missing') }
  $protectedById = @{}
  foreach ($region in @($Plan.protected_regions)) {
    if (-not (Test-R3VPHasProperty $region 'visual_element_id') -or -not (Test-R3VPText $region.visual_element_id)) { $errors.Add('protected_region_id_missing'); continue }
    $id = [string]$region.visual_element_id
    if ($protectedById.ContainsKey($id)) { $errors.Add("protected_region_duplicate:$id") } else { $protectedById[$id] = $region }
    foreach ($error in (Test-R3VPNormalizedRect $region "protected_region:$id")) { $errors.Add($error) }
  }
  foreach ($id in @($Plan.required_visual_element_ids)) { if (-not $protectedById.ContainsKey([string]$id)) { $errors.Add("required_visual_element_region_missing:$id") } }
  if ($Plan.adaptation_strategy -eq 'focal_crop' -and @($Plan.required_visual_element_ids).Count -eq 0) { $errors.Add('focal_crop_required_visual_elements_missing') }
  if ($Plan.adaptation_strategy -eq 'reuse_native') {
    $sourceRatio = $Plan.source_canvas.aspect_ratio; $targetRatio = $Plan.target_canvas.aspect_ratio
    if ([int]$sourceRatio.ratio_width -ne [int]$targetRatio.ratio_width -or [int]$sourceRatio.ratio_height -ne [int]$targetRatio.ratio_height) { $errors.Add('reuse_native_ratio_incompatible') }
  }
  if ($Plan.adaptation_strategy -eq 'fit_pad') {
    if (-not (Test-R3VPHasProperty $Plan.background_fill_spec 'type') -or $Plan.background_fill_spec.type -ne 'solid_color' -or -not (Test-R3VPHasProperty $Plan.background_fill_spec 'color') -or [string]$Plan.background_fill_spec.color -notmatch '^#[0-9A-Fa-f]{6}$') { $errors.Add('fit_pad_background_fill_invalid') }
  }
  if ($Plan.adaptation_strategy -in @('outpaint_extend','independent_generation') -and -not (Test-R3VPHasProperty $Plan 'provider_task_id')) { $errors.Add('provider_strategy_task_id_missing') }
  if ($Plan.adaptation_strategy -ne 'fit_pad' -and (Test-R3VPHasProperty $Plan.background_fill_spec 'type') -and $Plan.background_fill_spec.type -notin @('not_applicable','solid_color')) { $errors.Add('background_fill_type_invalid') }
  return [object[]]$errors.ToArray()
}

function Test-R3CoverCompositionRecord {
  param([object]$Record, [object]$Plan)
  $errors = [System.Collections.Generic.List[string]]::new()
  $required = @('schema_id','schema_version','cover_rendition_id','rendition_revision','surface_profile_id','adaptation_strategy','source_canvas','target_canvas','crop_contract','output_path','output_sha256','preview_path','preview_sha256','preview_evidence_type','structural_gate_status','visual_review_status','cover_delivery_status')
  foreach ($field in $required) { if (-not (Test-R3VPHasProperty $Record $field)) { $errors.Add("cover_composition_record_field_missing:$field") } }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Record.schema_id -ne 'taoge://schemas/r3/cover-composition-record/v0.2' -or $Record.schema_version -ne '0.2') { $errors.Add('cover_composition_record_version_invalid') }
  foreach ($field in @('cover_rendition_id','rendition_revision','surface_profile_id','adaptation_strategy','output_path','preview_path','preview_evidence_type')) {
    $planField = switch ($field) { 'surface_profile_id' { 'surface_profile_id' } default { $field } }
    if ([string]$Record.$field -ne [string]$Plan.$planField) { $errors.Add("cover_composition_plan_mismatch:$field") }
  }
  if ($Record.structural_gate_status -ne 'pass' -or $Record.visual_review_status -ne 'not_reviewed' -or $Record.cover_delivery_status -ne 'waiting_visual_review') { $errors.Add('cover_composition_status_invalid') }
  if ($Record.preview_evidence_type -ne 'deterministic_surface_mock') { $errors.Add('cover_composition_preview_type_invalid') }
  return [object[]]$errors.ToArray()
}

function Test-R3CoverVisualReviewRecord {
  param([object]$Review, [object]$Composition)
  $errors = [System.Collections.Generic.List[string]]::new()
  $required = @('schema_id','schema_version','cover_visual_review_id','cover_rendition_id','rendition_revision','surface_profile_id','reviewer_type','observation_mode','review_scope','output_sha256','preview_sha256','visual_review_status','findings','review_statement','reviewed_at')
  foreach ($field in $required) { if (-not (Test-R3VPHasProperty $Review $field)) { $errors.Add("cover_visual_review_field_missing:$field") } }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Review.schema_id -ne 'taoge://schemas/r3/cover-visual-review/v0.1' -or $Review.schema_version -ne '0.1') { $errors.Add('cover_visual_review_version_invalid') }
  if ($Review.reviewer_type -notin @('codex_visual_review','human_visual_review')) { $errors.Add('cover_visual_reviewer_invalid') }
  if ($Review.observation_mode -ne 'raster_inspection') { $errors.Add('cover_visual_observation_mode_invalid') }
  if ($Review.review_scope -notin @('real_delivery','fixture_only')) { $errors.Add('cover_visual_review_scope_invalid') }
  if ($Review.visual_review_status -notin @('pass','fail')) { $errors.Add('cover_visual_review_status_invalid') }
  if (-not (Test-R3VPText $Review.review_statement)) { $errors.Add('cover_visual_review_statement_missing') }
  if ($Review.visual_review_status -eq 'fail' -and @($Review.findings).Count -eq 0) { $errors.Add('cover_visual_fail_findings_missing') }
  foreach ($pair in @(@('cover_rendition_id','cover_rendition_id'),@('rendition_revision','rendition_revision'),@('surface_profile_id','surface_profile_id'),@('output_sha256','output_sha256'),@('preview_sha256','preview_sha256'))) {
    if ([string]$Review.($pair[0]) -ne [string]$Composition.($pair[1])) { $errors.Add("cover_visual_review_binding_mismatch:$($pair[0])") }
  }
  return [object[]]$errors.ToArray()
}

function Get-R3PlatformDeliveryScopeStatus {
  param([object[]]$PlatformUnits)
  $primary = @($PlatformUnits | Where-Object { $_.platform_priority -eq 'primary' })
  if ($primary.Count -ne 1 -or @($primary | Where-Object { $_.cover_delivery_status -ne 'visual_pass' }).Count -gt 0) { return 'not_publish_ready' }
  $pendingSecondary = @($PlatformUnits | Where-Object { $_.platform_priority -eq 'secondary' -and $_.cover_delivery_status -ne 'visual_pass' })
  if ($pendingSecondary.Count) { return 'primary_ready_secondary_pending' }
  return 'ready_all_target_platforms'
}
