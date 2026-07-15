Set-StrictMode -Version 2.0

function Test-R3VNHasProperty {
  param([object]$Value,[string]$Name)
  return $null -ne $Value -and $Value.PSObject.Properties.Name -contains $Name
}

function Test-R3VNText {
  param([object]$Value)
  return -not [string]::IsNullOrWhiteSpace([string]$Value)
}

function Test-R3VisualNeedAnalysis {
  param([object]$Document)
  $errors=[System.Collections.Generic.List[string]]::new()
  if (-not (Get-Command Test-R3VisualInsertTask -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'R3VisualPresentation.ps1')
  }
  $isV5=$Document.schema_id -eq 'taoge://schemas/r3/visual-need-analysis/v0.5' -and $Document.schema_version -eq '0.5.0'
  $isV3=$Document.schema_id -eq 'taoge://schemas/r3/visual-need-analysis/v0.3' -and $Document.schema_version -eq '0.3'
  $isV2=$Document.schema_id -eq 'taoge://schemas/r3/visual-need-analysis/v0.2' -and $Document.schema_version -eq '0.2'
  $required=@('schema_id','schema_version','visual_need_analysis_id','static_visual_director_plan_id','draft_id','account','audience_profile_ref','audience_prior_knowledge','platform_viewing_context','visual_count_policy','generation_policy','codex_provider','cost_gate','provider_call_limit','accepted_task_dispatch_policy','human_confirmation_required','generation_dispatch_status','next_skill','cover_count_excluded','semantic_beats','candidates','accepted_visual_tasks','rejected_visual_candidate_ids','derived_visual_count','zero_visual_reason','visual_need_analysis_status')
  if($isV5){$required+=@('content_source_id','content_origin','analysis_revision','session_id','account_snapshot_id','test_profile')}
  elseif($isV2-or$isV3){$required+=@('content_source_id','content_origin')}else{$required+=@('source_research_run_id')}
  foreach($field in $required){if(-not(Test-R3VNHasProperty $Document $field)){$errors.Add("visual_need_field_missing:$field")}}
  if($errors.Count){return [object[]]$errors.ToArray()}

  $isV1=$Document.schema_id -eq 'taoge://schemas/r3/visual-need-analysis/v0.1' -and $Document.schema_version -eq '0.1'
  if(-not$isV1-and-not$isV2-and-not$isV3-and-not$isV5){$errors.Add('visual_need_version_invalid')}
  if($isV2-or$isV3-or$isV5){
    if($Document.content_origin -notin @('hotspot_selected_topic','user_supplied_draft')){$errors.Add('content_origin_invalid')}
    if($Document.content_origin -eq 'hotspot_selected_topic' -and (-not(Test-R3VNHasProperty $Document 'source_research_run_id') -or -not(Test-R3VNText $Document.source_research_run_id))){$errors.Add('hotspot_source_research_run_id_required')}
    if($Document.content_origin -eq 'user_supplied_draft'){
      if(-not(Test-R3VNHasProperty $Document 'original_draft_artifact_id') -or -not(Test-R3VNText $Document.original_draft_artifact_id)){$errors.Add('direct_original_draft_artifact_id_required')}
      if(-not(Test-R3VNHasProperty $Document 'original_draft_digest') -or [string]$Document.original_draft_digest -notmatch '^[A-Fa-f0-9]{64}$'){$errors.Add('direct_original_draft_digest_required')}
      if(Test-R3VNHasProperty $Document 'source_research_run_id'){$errors.Add('direct_fake_source_research_run_id_forbidden')}
    }
  }
  if($Document.visual_count_policy -ne 'content_derived_unbounded'){$errors.Add('visual_count_policy_invalid')}
  if($Document.generation_policy -ne 'generate_all_accepted'){$errors.Add('generation_policy_invalid')}
  if($Document.codex_provider -ne 'codex_builtin_image2'){$errors.Add('codex_provider_invalid')}
  if($Document.cost_gate -ne 'not_applicable'){$errors.Add('cost_gate_must_be_not_applicable')}
  if($null -ne $Document.provider_call_limit){$errors.Add('provider_call_limit_must_be_null')}
  if($Document.accepted_task_dispatch_policy -ne 'auto_continue_all_accepted_without_human_confirmation'){$errors.Add('accepted_task_dispatch_policy_invalid')}
  if($Document.human_confirmation_required -isnot [bool] -or $Document.human_confirmation_required -ne $false){$errors.Add('accepted_tasks_must_not_wait_for_human_confirmation')}
  if(-not[bool]$Document.cover_count_excluded){$errors.Add('cover_must_be_excluded')}
  if($Document.audience_prior_knowledge -notin @('novice','mixed','expert','unknown')){$errors.Add('audience_prior_knowledge_invalid')}
  if($Document.platform_viewing_context -notin @('mobile_feed','known_audience','other')){$errors.Add('platform_viewing_context_invalid')}
  if($Document.visual_need_analysis_status -notin @('pass','needs_fix','blocked')){$errors.Add('visual_need_analysis_status_invalid')}
  if($Document.visual_need_analysis_status -eq 'pass'){
    if($isV5){
      if($Document.generation_dispatch_status -ne 'ready_for_routed_production'){$errors.Add('pass_must_be_ready_for_routed_production')}
      if($Document.next_skill -ne 'talking-head-image-pip'){$errors.Add('pass_must_continue_to_visual_router')}
    }else{
      if($Document.generation_dispatch_status -ne 'ready_for_prompt_compile'){$errors.Add('pass_must_be_ready_for_prompt_compile')}
      if($Document.next_skill -ne 'image-prompt-compiler'){$errors.Add('pass_must_auto_continue_to_image_prompt_compiler')}
    }
  }else{
    if($Document.generation_dispatch_status -ne 'not_ready'){$errors.Add('non_pass_dispatch_status_invalid')}
    if($Document.next_skill -ne 'static-visual-director'){$errors.Add('non_pass_must_recover_locally')}
  }

  $deprecated=@('visual_budget','required_visuals','optional_visuals','default_required_min','default_required_max','default_optional_min','default_optional_max','final_required_count','final_optional_count','selected_optional_count','reduction_reason','expansion_reason','expected_provider_call_count')
  foreach($field in $deprecated){if(Test-R3VNHasProperty $Document $field){$errors.Add("deprecated_visual_budget_field_forbidden:$field")}}

  $jobs=@('attention_reset','hook_amplification','concept_explanation','evidence_support','process_demonstration','emotion_amplification','memory_anchor')
  $beatIds=@{};$candidateIds=@{};$taskIds=@{};$generated=@{};$rejected=@{}
  foreach($beat in @($Document.semantic_beats)){
    foreach($field in @('beat_id','script_range','beat_purpose','viewer_state_before','viewer_state_after')){if(-not(Test-R3VNHasProperty $beat $field)-or-not(Test-R3VNText $beat.$field)){$errors.Add("semantic_beat_field_missing:$field")}}
    $id=[string]$beat.beat_id;if(Test-R3VNText $id){if($beatIds.ContainsKey($id)){$errors.Add("semantic_beat_id_duplicate:$id")}else{$beatIds[$id]=$true}}
  }

  foreach($candidate in @($Document.candidates)){
    $candidateRequired=@('visual_need_candidate_id','beat_id','covered_beat_ids','trigger_text','insert_after_text','insert_before_text','viewer_problem_without_visual','attention_risk_without_visual','comprehension_risk_without_visual','primary_visual_job','supporting_visual_jobs','expected_viewer_change','information_added','why_image_is_better_than_talking_head','attention_trigger_basis','emotion_congruence_status','evidence_requirement','evidence_source_type','evidence_source_id','evidence_source_path','redundancy_status','cognitive_load_risk','misleading_risk','visual_need_decision','decision_reason')
    foreach($field in $candidateRequired){if(-not(Test-R3VNHasProperty $candidate $field)){$errors.Add("visual_candidate_field_missing:$field")}}
    if(@($candidateRequired|Where-Object{-not(Test-R3VNHasProperty $candidate $_)}).Count){continue}
    $id=[string]$candidate.visual_need_candidate_id;if($candidateIds.ContainsKey($id)){$errors.Add("visual_candidate_id_duplicate:$id")}else{$candidateIds[$id]=$candidate}
    if(-not$beatIds.ContainsKey([string]$candidate.beat_id)){$errors.Add("visual_candidate_beat_missing:$id")}
    if(@($candidate.covered_beat_ids)-notcontains [string]$candidate.beat_id){$errors.Add("covered_beats_must_include_primary:$id")}
    foreach($covered in @($candidate.covered_beat_ids)){if(-not$beatIds.ContainsKey([string]$covered)){$errors.Add("covered_beat_missing:${id}:$covered")}}
    if($candidate.primary_visual_job -notin $jobs){$errors.Add("primary_visual_job_invalid:$id")}
    $support=@($candidate.supporting_visual_jobs);if(@($support|Where-Object{$_ -notin $jobs}).Count){$errors.Add("supporting_visual_job_invalid:$id")};if($support -contains $candidate.primary_visual_job){$errors.Add("supporting_visual_job_duplicates_primary:$id")};if(@($support|Group-Object|Where-Object{$_.Count-gt1}).Count){$errors.Add("supporting_visual_job_duplicate:$id")}
    if($candidate.visual_need_decision -notin @('generate','reject')){$errors.Add("visual_need_decision_invalid:$id");continue}
    if(-not(Test-R3VNText $candidate.decision_reason)){$errors.Add("visual_need_decision_reason_missing:$id")}
    if($candidate.visual_need_decision -eq 'generate'){
      $generated[$id]=$candidate
      foreach($field in @('trigger_text','insert_after_text','insert_before_text','viewer_problem_without_visual','expected_viewer_change','information_added','why_image_is_better_than_talking_head')){if(-not(Test-R3VNText $candidate.$field)){$errors.Add("generate_candidate_proof_missing:${id}:$field")}}
      if($candidate.redundancy_status -ne 'unique'){$errors.Add("generate_candidate_redundant:$id")}
      if($candidate.cognitive_load_risk -eq 'high'){$errors.Add("generate_candidate_cognitive_load_high:$id")}
      if($candidate.misleading_risk -eq 'high'){$errors.Add("generate_candidate_misleading_high:$id")}
      $allJobs=@([string]$candidate.primary_visual_job)+@($support|ForEach-Object{[string]$_})
      if($allJobs -contains 'attention_reset' -and $candidate.attention_trigger_basis -ne 'specific_content_risk'){$errors.Add("attention_reset_requires_specific_content_risk:$id")}
      if($allJobs -contains 'emotion_amplification' -and $candidate.emotion_congruence_status -ne 'aligned'){$errors.Add("emotion_amplification_must_be_aligned:$id")}
      if($allJobs -contains 'evidence_support'){
        if($candidate.evidence_requirement -ne 'source_bound'){$errors.Add("evidence_support_must_be_source_bound:$id")}
        foreach($field in @('evidence_source_type','evidence_source_id','evidence_source_path')){if(-not(Test-R3VNText $candidate.$field)){$errors.Add("evidence_source_missing:${id}:$field")}}
      }
    }else{$rejected[$id]=$candidate}
  }

  $taskByCandidate=@{}
  foreach($task in @($Document.accepted_visual_tasks)){
    $taskRequired=@('image_task_id','visual_need_candidate_id','beat_id','primary_visual_job','generation_intent','provider_route');if($isV2-or$isV3-or$isV5){$taskRequired+=@('image_production_path')};if($isV3-or$isV5){$taskRequired+=@('visual_insert_task_id','presentation_mode','platform_surface_profile_id','video_canvas','visual_asset_canvas','placement_slot','speaker_region','caption_safe_area','platform_ui_safe_areas','protected_regions','aspect_ratio_verification_status')};if($isV5){$taskRequired+=@('source_class','source_class_reason','excluded_source_classes','disposition','production_path','provider_task_ref','source_capture_ref','existing_asset_ref','asset_reuse_authorization_ref','base_asset_requirement','postprocess_mode','task_status')}
    foreach($field in $taskRequired){if(-not(Test-R3VNHasProperty $task $field)-or-not(Test-R3VNText $task.$field)){$errors.Add("accepted_visual_task_field_missing:$field")}}
    $taskId=[string]$task.image_task_id;if($taskIds.ContainsKey($taskId)){$errors.Add("accepted_visual_task_id_duplicate:$taskId")}else{$taskIds[$taskId]=$true}
    $candidateId=[string]$task.visual_need_candidate_id;if($taskByCandidate.ContainsKey($candidateId)){$errors.Add("accepted_candidate_task_duplicate:$candidateId")}else{$taskByCandidate[$candidateId]=$task}
    if(-not$generated.ContainsKey($candidateId)){$errors.Add("accepted_task_candidate_not_generate:$candidateId")}else{if($task.primary_visual_job -ne $generated[$candidateId].primary_visual_job){$errors.Add("accepted_task_job_mismatch:$candidateId")};if($task.beat_id -ne $generated[$candidateId].beat_id){$errors.Add("accepted_task_beat_mismatch:$candidateId")}}
    if($task.generation_intent -ne 'render_now'){$errors.Add("accepted_task_must_render_now:$candidateId")}
    if($isV5){
      if(-not(Get-Command Test-R3VisualTaskSourceRouteV01 -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'JointVisualRevisionContract.ps1')}
      $routeTask=[pscustomobject]@{visual_task_id=$task.image_task_id;source_class=$task.source_class;source_class_reason=$task.source_class_reason;excluded_source_classes=$task.excluded_source_classes;disposition=$task.disposition;production_path=$task.production_path;provider_task_ref=$task.provider_task_ref;source_capture_ref=$task.source_capture_ref;existing_asset_ref=$task.existing_asset_ref;asset_reuse_authorization_ref=$task.asset_reuse_authorization_ref;base_asset_requirement=$task.base_asset_requirement;postprocess_mode=$task.postprocess_mode;task_status=$task.task_status}
      foreach($routeError in(Test-R3VisualTaskSourceRouteV01 -Task $routeTask -TestProfile ([string]$Document.test_profile) -SessionId ([string]$Document.session_id) -AccountSnapshotId ([string]$Document.account_snapshot_id))){$errors.Add("${candidateId}:$routeError")}
    }elseif($isV2-or$isV3){
      if($task.primary_visual_job -eq 'evidence_support'){
        if($task.provider_route -ne 'news_evidence_pip'){$errors.Add("evidence_task_provider_invalid:$candidateId")}
        if($task.image_production_path -ne 'source_capture'){$errors.Add("evidence_task_production_path_invalid:$candidateId")}
      }else{
        if($task.provider_route -ne 'codex_builtin_image2'){$errors.Add("generated_task_provider_invalid:$candidateId")}
        if($task.image_production_path -ne 'codex_image2_render'){$errors.Add("generated_task_production_path_invalid:$candidateId")}
      }
    }elseif($task.provider_route -ne 'codex_builtin_image2'){$errors.Add("accepted_task_provider_invalid:$candidateId")}
    if($isV3-or$isV5){foreach($presentationError in (Test-R3VisualInsertTask $task)){$errors.Add("${candidateId}:$presentationError")};foreach($field in @('caption_safe_area')){foreach($rectError in (Test-R3VPNormalizedRect $task.$field "${candidateId}:$field")){$errors.Add($rectError)}};foreach($collectionField in @('platform_ui_safe_areas','protected_regions')){foreach($rect in @($task.$collectionField)){foreach($rectError in (Test-R3VPNormalizedRect $rect "${candidateId}:$collectionField")){$errors.Add($rectError)}}}}
  }
  foreach($candidateId in $generated.Keys){if(-not$taskByCandidate.ContainsKey($candidateId)){$errors.Add("generate_candidate_missing_accepted_task:$candidateId")}}
  $rejectedIds=@($Document.rejected_visual_candidate_ids|ForEach-Object{[string]$_});if(@($rejectedIds|Group-Object|Where-Object{$_.Count-gt1}).Count){$errors.Add('rejected_candidate_id_duplicate')}
  foreach($candidateId in $rejected.Keys){if($rejectedIds-notcontains$candidateId){$errors.Add("reject_candidate_missing_rejected_index:$candidateId")}}
  foreach($candidateId in $rejectedIds){if(-not$rejected.ContainsKey($candidateId)){$errors.Add("rejected_index_candidate_not_reject:$candidateId")}}
  if([int]$Document.derived_visual_count-ne @($Document.accepted_visual_tasks).Count){$errors.Add('derived_visual_count_task_mismatch')}
  if([int]$Document.derived_visual_count-ne $generated.Count){$errors.Add('derived_visual_count_candidate_mismatch')}
  if([int]$Document.derived_visual_count-eq 0){if(-not(Test-R3VNText $Document.zero_visual_reason)){$errors.Add('zero_visual_reason_required')}elseif([string]$Document.zero_visual_reason-match'时长|秒数|成本|调用'){$errors.Add('zero_visual_reason_invalid_basis')}}elseif($null-ne$Document.zero_visual_reason-and(Test-R3VNText $Document.zero_visual_reason)){$errors.Add('zero_visual_reason_only_for_zero')}
  return [object[]]$errors.ToArray()
}
