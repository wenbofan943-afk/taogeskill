Set-StrictMode -Version 2.0

function Test-R6SVHasProperty {
  param([object]$Object,[string]$Name)
  return $null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name
}

function Get-R6SVReadiness {
  param([object]$Review,[object]$Decision)
  if ($null -eq $Review -or $null -eq $Decision) { return 'blocked' }
  if ([string]$Review.script_design_review_id -ne [string]$Decision.script_design_review_ref.artifact_id -or [int]$Review.review_revision -ne [int]$Decision.script_design_review_ref.revision) { return 'stale' }
  $hard = @($Review.issues | Where-Object { $_.issue_gate -eq 'hard_boundary' })
  $authorization = @($Review.issues | Where-Object { $_.issue_gate -eq 'authorization_required' })
  $advisory = @($Review.issues | Where-Object { $_.issue_gate -eq 'advisory' })
  if ($hard.Count -gt 0 -or $Review.review_status -eq 'blocked' -or $Decision.decision -eq 'stop') { return 'blocked' }
  if ($authorization.Count -gt 0 -and $Decision.decision -ne 'revise_script') { return 'waiting_authorization' }
  if ($Decision.decision -eq 'revise_script' -or $Review.review_status -eq 'needs_revision') { return 'needs_revision' }
  if ($Decision.decision -ne 'accept_current') { return 'blocked' }
  $accepted = @($Decision.accepted_advisory_issue_ids)
  foreach ($issue in $advisory) { if ([string]$issue.issue_id -notin $accepted) { return 'needs_revision' } }
  if ($advisory.Count -gt 0 -or $Review.review_status -eq 'pass_with_warnings') { return 'ready_with_warnings' }
  return 'ready'
}

function Test-R6SVDigest {
  param([object]$Value)
  return [string]$Value -match '^sha256:[0-9a-f]{64}$'
}

function Test-R6ScriptVisualBundle {
  param([object]$Bundle)
  $errors = [System.Collections.Generic.List[string]]::new()
  foreach ($name in @('draft','normalized_body_text','normalized_body_digest','structure_plan','beat_map','script_review','revision_decision','visual_need_analysis','coverage_ledger','alignment_review','current_bindings')) {
    if (-not (Test-R6SVHasProperty $Bundle $name)) { $errors.Add("bundle_required_missing:$name") }
  }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if (-not (Test-R6SVDigest $Bundle.normalized_body_digest)) { $errors.Add('draft_digest_invalid') }

  $draft = $Bundle.draft
  if ([string]$draft.normalized_body_digest -ne [string]$Bundle.normalized_body_digest -or [string]$draft.body_text -ne [string]$Bundle.normalized_body_text) { $errors.Add('draft_bundle_binding_mismatch') }
  if ($draft.draft_mode -eq 'materialize_user_baseline') {
    if ([int]$draft.draft_revision -ne 1 -or $draft.content_origin -ne 'user_supplied_draft' -or $draft.draft_status -ne 'baseline_ready') { $errors.Add('direct_baseline_identity_invalid') }
    if (-not (Test-R6SVDigest $draft.original_normalized_body_digest) -or [string]$draft.original_normalized_body_digest -ne [string]$draft.normalized_body_digest) { $errors.Add('direct_baseline_semantic_mutation') }
    if ($null -eq $draft.original_draft_ref -or $null -ne $draft.structure_plan_ref -or $null -ne $draft.review_ref -or $null -ne $draft.revision_decision_ref -or @($draft.authorization_refs).Count -ne 0) { $errors.Add('direct_baseline_lineage_invalid') }
  } elseif ($draft.draft_mode -eq 'generate_from_structure') {
    if ($draft.content_origin -ne 'hotspot_topic' -or $null -eq $draft.structure_plan_ref -or $null -ne $draft.original_draft_ref) { $errors.Add('generated_draft_structure_binding_invalid') }
  } elseif ($draft.draft_mode -eq 'revise_from_decision') {
    if ($null -eq $draft.review_ref -or $null -eq $draft.revision_decision_ref) { $errors.Add('revised_draft_decision_binding_invalid') }
  } else { $errors.Add('draft_mode_invalid') }

  $plan = $Bundle.structure_plan
  if ($draft.draft_mode -eq 'materialize_user_baseline' -and $plan.plan_mode -ne 'diagnose_existing_draft') { $errors.Add('direct_baseline_route_invalid') }
  if ($draft.draft_mode -eq 'generate_from_structure' -and $plan.plan_mode -ne 'design_before_draft') { $errors.Add('generated_draft_route_invalid') }
  if ($plan.plan_mode -eq 'diagnose_existing_draft' -and @($plan.alternatives_considered | Where-Object { $_.transformation_level -eq 'keep_current' }).Count -eq 0) { $errors.Add('direct_keep_current_missing') }
  if ($plan.selection_status -eq 'waiting_human' -and $plan.plan_status -ne 'pending_selection') { $errors.Add('structure_waiting_false_blocked') }
  if ($plan.plan_status -in @('ready','ready_with_warnings')) {
    if ([string]::IsNullOrWhiteSpace([string]$plan.selected_candidate_id) -or [string]::IsNullOrWhiteSpace([string]$plan.selected_strategy_ref)) { $errors.Add('structure_selection_missing') }
    $order = 1; $stageIds = @{}
    foreach ($stage in @($plan.stages | Sort-Object order)) {
      if ([int]$stage.order -ne $order) { $errors.Add("structure_stage_order_gap:$($stage.stage_id)") }; $order++
      if ($stageIds.ContainsKey([string]$stage.stage_id)) { $errors.Add("structure_stage_duplicate:$($stage.stage_id)") } else { $stageIds[[string]$stage.stage_id] = $true }
    }
    if ($stageIds.Count -eq 0) { $errors.Add('structure_stages_empty') }
  }

  $map = $Bundle.beat_map
  if ([string]$map.normalized_body_digest -ne [string]$Bundle.normalized_body_digest) { $errors.Add('beat_map_draft_digest_mismatch') }
  if ($map.mapping_phase -ne 'structure_bound') { $errors.Add('semantic_only_visual_entry_forbidden') }
  if ($map.full_coverage_status -ne 'complete' -or @($map.unresolved_ranges).Count -ne 0 -or $map.mapping_status -ne 'ready') { $errors.Add('beat_map_not_complete') }
  $bytes = [Text.Encoding]::UTF8.GetBytes([string]$Bundle.normalized_body_text)
  $covered = New-Object bool[] $bytes.Length
  $beatIds = @{}; $beatOrder = 1; $stageSet = @{}
  foreach ($stage in @($plan.stages)) { $stageSet[[string]$stage.stage_id] = $true }
  foreach ($beat in @($map.beats | Sort-Object order)) {
    if ([int]$beat.order -ne $beatOrder) { $errors.Add("beat_order_gap:$($beat.beat_id)") }; $beatOrder++
    if ($beatIds.ContainsKey([string]$beat.beat_id)) { $errors.Add("beat_duplicate:$($beat.beat_id)") } else { $beatIds[[string]$beat.beat_id] = $beat }
    $start = [int]$beat.start_byte; $end = [int]$beat.end_byte
    if ($start -lt 0 -or $end -le $start -or $end -gt $bytes.Length) { $errors.Add("beat_anchor_invalid:$($beat.beat_id)"); continue }
    for ($i=$start; $i -lt $end; $i++) { if ($covered[$i]) { $errors.Add("beat_anchor_overlap:$($beat.beat_id)") }; $covered[$i] = $true }
    if (-not $stageSet.ContainsKey([string]$beat.stage_id)) { $errors.Add("beat_stage_missing:$($beat.beat_id)") }
  }
  for ($i=0; $i -lt $bytes.Length; $i++) {
    $isWhitespace = $bytes[$i] -in @(9,10,13,32)
    if (-not $isWhitespace -and -not $covered[$i]) { $errors.Add("beat_nonwhitespace_uncovered:$i") }
    if ($isWhitespace -and $covered[$i]) { $errors.Add("beat_whitespace_covered:$i") }
  }

  $readiness = Get-R6SVReadiness $Bundle.script_review $Bundle.revision_decision
  if ([string]$Bundle.revision_decision.derived_script_readiness -ne $readiness) { $errors.Add("script_readiness_mismatch:$readiness") }
  if ($Bundle.visual_need_analysis.script_readiness -ne $readiness -or $readiness -notin @('ready','ready_with_warnings')) { $errors.Add('visual_started_before_script_ready') }
  if ($Bundle.visual_need_analysis.beat_map_ref.artifact_id -ne $map.beat_map_id -or $Bundle.visual_need_analysis.structure_plan_ref.artifact_id -ne $plan.structure_plan_id) { $errors.Add('visual_analysis_binding_mismatch') }

  $ledger = $Bundle.coverage_ledger
  if ($ledger.beat_map_ref.artifact_id -ne $map.beat_map_id) { $errors.Add('coverage_beat_map_binding_mismatch') }
  $coverageByBeat = @{}
  foreach ($record in @($ledger.coverage_records)) {
    if ($coverageByBeat.ContainsKey([string]$record.beat_id)) { $errors.Add("coverage_duplicate:$($record.beat_id)") } else { $coverageByBeat[[string]$record.beat_id] = $record }
  }
  foreach ($beatId in $beatIds.Keys) { if (-not $coverageByBeat.ContainsKey($beatId)) { $errors.Add("coverage_missing:$beatId") } }
  foreach ($beatId in $coverageByBeat.Keys) { if (-not $beatIds.ContainsKey($beatId)) { $errors.Add("coverage_unknown:$beatId") } }

  $taskById = @{}
  foreach ($task in @($ledger.accepted_visual_tasks)) {
    if ($taskById.ContainsKey([string]$task.visual_task_id)) { $errors.Add("visual_task_duplicate:$($task.visual_task_id)") } else { $taskById[[string]$task.visual_task_id] = $task }
    if ([string]::IsNullOrWhiteSpace([string]$task.value_proof.primary_value) -or [string]::IsNullOrWhiteSpace([string]$task.value_proof.viewer_problem_without_visual) -or [string]::IsNullOrWhiteSpace([string]$task.value_proof.expected_viewer_change)) { $errors.Add("visual_task_value_proof_missing:$($task.visual_task_id)") }
    if ($task.disposition -eq 'generate_visual') {
      if ($task.production_path -ne 'image_generation' -or [string]::IsNullOrWhiteSpace([string]$task.provider_task_ref) -or $task.capture_mode -ne 'not_applicable') { $errors.Add("generate_visual_route_invalid:$($task.visual_task_id)") }
    } elseif (-not [string]::IsNullOrWhiteSpace([string]$task.provider_task_ref)) { $errors.Add("non_generate_provider_task_forbidden:$($task.visual_task_id)") }
    if ($task.disposition -eq 'use_source_evidence') {
      if ($task.production_path -ne 'source_capture' -or $task.capture_mode -notin @('new_capture','reuse_verified_capture') -or $null -eq $task.evidence_binding) { $errors.Add("source_evidence_route_invalid:$($task.visual_task_id)") }
    } elseif ($task.capture_mode -ne 'not_applicable') { $errors.Add("non_evidence_capture_mode_forbidden:$($task.visual_task_id)") }
    if ($task.disposition -eq 'use_existing_asset' -and $null -eq $task.existing_asset_ref) { $errors.Add("existing_asset_ref_missing:$($task.visual_task_id)") }
  }
  foreach ($record in @($ledger.coverage_records)) {
    if ($record.primary_disposition -in @('generate_visual','create_deterministic_visual','use_source_evidence','use_existing_asset','manual_visual_required') -and -not $taskById.ContainsKey([string]$record.primary_visual_task_id)) { $errors.Add("coverage_task_missing:$($record.beat_id)") }
    if ($record.primary_disposition -eq 'reuse_visual_task' -and -not $taskById.ContainsKey([string]$record.reused_visual_task_id)) { $errors.Add("coverage_reuse_task_missing:$($record.beat_id)") }
    if ($record.primary_disposition -eq 'talking_head_intentional' -and [string]::IsNullOrWhiteSpace([string]$record.talking_head_advantage)) { $errors.Add("talking_head_reason_missing:$($record.beat_id)") }
    if ($record.primary_disposition -eq 'evidence_blocked' -and [string]::IsNullOrWhiteSpace([string]$record.evidence_block_reason)) { $errors.Add("evidence_block_reason_missing:$($record.beat_id)") }
  }

  $occurrenceIds = @{}
  foreach ($occurrence in @($ledger.visual_insert_occurrences)) {
    $occurrenceId=[string]$occurrence.occurrence_id;$taskId=[string]$occurrence.visual_task_id
    if ($occurrenceIds.ContainsKey($occurrenceId)) { $errors.Add("occurrence_duplicate:$occurrenceId") } else { $occurrenceIds[$occurrenceId]=$true }
    if (-not $taskById.ContainsKey($taskId)) { $errors.Add("occurrence_task_missing:$occurrenceId"); continue }
    $coveredBeatIds=@($occurrence.covered_beat_ids|ForEach-Object{[string]$_})
    if($coveredBeatIds.Count-eq0){$errors.Add("occurrence_covered_beats_empty:$occurrenceId");continue}
    $seenCovered=@{};$coveredOrders=[System.Collections.Generic.List[int]]::new();$taskCovered=@($taskById[$taskId].covered_beat_ids|ForEach-Object{[string]$_})
    foreach($coveredBeatId in $coveredBeatIds){
      if($seenCovered.ContainsKey($coveredBeatId)){$errors.Add("occurrence_covered_beat_duplicate:${occurrenceId}:$coveredBeatId");continue};$seenCovered[$coveredBeatId]=$true
      if(-not$beatIds.ContainsKey($coveredBeatId)){$errors.Add("occurrence_covered_beat_missing:${occurrenceId}:$coveredBeatId");continue}
      if($coveredBeatId-notin$taskCovered){$errors.Add("occurrence_task_coverage_mismatch:${occurrenceId}:$coveredBeatId")}
      $coveredOrders.Add([int]$beatIds[$coveredBeatId].order)
    }
    $orders=@($coveredOrders|Sort-Object);for($i=1;$i-lt$orders.Count;$i++){if([int]$orders[$i]-ne([int]$orders[$i-1]+1)){$errors.Add("occurrence_covered_beats_non_contiguous:$occurrenceId");break}}
    if([string]::IsNullOrWhiteSpace([string]$occurrence.insert_after_beat_id)-and[string]::IsNullOrWhiteSpace([string]$occurrence.insert_before_beat_id)){$errors.Add("occurrence_anchor_missing:$occurrenceId")}
  }
  $derived = $taskById.Count
  $materialized = @($ledger.accepted_visual_tasks | Where-Object { $_.task_status -eq 'materialized' }).Count
  $providerTasks = @($ledger.accepted_visual_tasks | Where-Object { $_.disposition -eq 'generate_visual' }).Count
  $captureTasks = @($ledger.accepted_visual_tasks | Where-Object { $_.disposition -eq 'use_source_evidence' -and $_.capture_mode -eq 'new_capture' }).Count
  $expectedCounts = [ordered]@{derived_visual_asset_count=$derived;materialized_visual_asset_count=$materialized;provider_generation_task_count=$providerTasks;provider_generation_attempt_count=@($ledger.provider_attempt_refs).Count;source_capture_task_count=$captureTasks;source_capture_attempt_count=@($ledger.source_capture_attempt_refs).Count;visual_insert_occurrence_count=$occurrenceIds.Count}
  foreach ($name in $expectedCounts.Keys) { if ([int]$ledger.counts.$name -ne [int]$expectedCounts[$name]) { $errors.Add("visual_count_mismatch:$name") } }
  if ($derived -eq 0 -and @($ledger.coverage_records | Where-Object { $_.primary_disposition -ne 'talking_head_intentional' -or @($_.supplemental_visual_task_ids).Count -gt 0 }).Count -gt 0) { $errors.Add('zero_visual_result_invalid') }
  if ($ledger.coverage_completeness_status -eq 'complete' -and @($ledger.unresolved_beat_ids).Count -ne 0) { $errors.Add('coverage_false_complete') }

  $alignment = $Bundle.alignment_review
  if ($alignment.beat_map_ref.artifact_id -ne $map.beat_map_id -or $alignment.coverage_ledger_ref.artifact_id -ne $ledger.visual_coverage_ledger_id) { $errors.Add('alignment_binding_mismatch') }
  if ($alignment.alignment_status -in @('pass','pass_with_warnings') -and ($ledger.coverage_completeness_status -ne 'complete' -or $readiness -notin @('ready','ready_with_warnings'))) { $errors.Add('alignment_false_pass') }

  $bindingByType = @{}; foreach ($binding in @($Bundle.current_bindings)) { $bindingByType[[string]$binding.object_type] = $binding; if (-not (Test-R6SVDigest $binding.sha256) -or [string]$binding.source_draft_digest -ne [string]$Bundle.normalized_body_digest) { $errors.Add("current_binding_invalid:$($binding.object_type)") } }
  foreach ($pair in @(@('short_video_structure_plan',$plan,'structure_plan_id','structure_plan_revision'),@('content_beat_map',$map,'beat_map_id','beat_map_revision'),@('script_design_review',$Bundle.script_review,'script_design_review_id','review_revision'),@('content_revision_decision',$Bundle.revision_decision,'content_revision_decision_id','decision_revision'),@('visual_need_analysis',$Bundle.visual_need_analysis,'visual_need_analysis_id','analysis_revision'),@('visual_coverage_ledger',$ledger,'visual_coverage_ledger_id','ledger_revision'),@('script_visual_alignment_review',$alignment,'alignment_review_id','review_revision'))) {
    if (-not $bindingByType.ContainsKey($pair[0])) { $errors.Add("current_binding_missing:$($pair[0])"); continue }
    $binding = $bindingByType[$pair[0]]; if ([string]$binding.artifact_id -ne [string]$pair[1].($pair[2]) -or [int]$binding.revision -ne [int]$pair[1].($pair[3])) { $errors.Add("current_binding_target_mismatch:$($pair[0])") }
  }
  return [object[]]$errors.ToArray()
}
