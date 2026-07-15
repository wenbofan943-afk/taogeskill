Set-StrictMode -Version 2.0

function Test-JVHasProperty {
  param([object]$Value,[string]$Name)
  if($Value -is [Collections.IDictionary]){return $Value.Contains($Name)}
  return $null -ne $Value -and $Value.PSObject.Properties.Name -contains $Name
}

function Test-JVText {
  param([object]$Value)
  return -not [string]::IsNullOrWhiteSpace([string]$Value)
}

function Test-JVDigest {
  param([object]$Value)
  return [string]$Value -match '^(sha256:)?[a-f0-9]{64}$'
}

function Get-R6SemanticParityResult {
  param([object[]]$FactBindings)
  $results=@($FactBindings|ForEach-Object{[string]$_.comparison_result})
  if($results -contains 'mismatch'){return 'mismatch'}
  if($results -contains 'not_assessed'){return 'not_assessed'}
  return 'match'
}

function Test-R6EvidenceBundleV02 {
  param([object]$Data,[string]$SessionRoot='')
  $errors=[Collections.Generic.List[string]]::new()
  $required=@('schema_id','schema_version','session_id','account','claim','source','capture','binding','evidence_anchor_annotation','semantic_normalization_registry_ref','semantic_fact_bindings','semantic_parity_result','pip','lineage')
  foreach($name in $required){if(-not(Test-JVHasProperty $Data $name)){$errors.Add("evidence_v02_required_missing:$name")}}
  if($errors.Count){return [object[]]$errors.ToArray()}
  if($Data.schema_id-ne'taoge://r6/news-evidence-pip/v0.2'-or[string]$Data.schema_version-ne'0.2.0'){$errors.Add('evidence_v02_version_invalid')}
  if($Data.capture.image_production_path-ne'source_capture'){$errors.Add('evidence_v02_image2_forbidden')}
  if(-not(Test-JVDigest $Data.capture.sha256)){$errors.Add('evidence_v02_capture_digest_invalid')}
  $annotation=$Data.evidence_anchor_annotation
  foreach($name in @('annotation_id','claim_ref','visible_quote','original_capture_ref','normalized_region','emphasis_style','source_fact_layer','creator_commentary_layer','overlay_spec_digest','annotated_asset_ref','attempts','current_outcome')){if(-not(Test-JVHasProperty $annotation $name)){$errors.Add("evidence_annotation_required_missing:$name")}}
  if($errors.Count){return [object[]]$errors.ToArray()}
  if([string]$annotation.claim_ref.artifact_id-ne[string]$Data.claim.claim_id){$errors.Add('evidence_annotation_claim_mismatch')}
  if([string]$annotation.original_capture_ref.artifact_id-ne[string]$Data.capture.capture_id-or[string]$annotation.original_capture_ref.sha256-ne[string]$Data.capture.sha256){$errors.Add('evidence_annotation_parent_capture_mismatch')}
  foreach($axis in @('x','y','width','height')){$value=[double]$annotation.normalized_region.$axis;if($value-lt0-or$value-gt1){$errors.Add("evidence_annotation_region_invalid:$axis")}}
  if(([double]$annotation.normalized_region.width+[double]$annotation.normalized_region.x)-gt1.000001-or([double]$annotation.normalized_region.height+[double]$annotation.normalized_region.y)-gt1.000001){$errors.Add('evidence_annotation_region_outside_capture')}
  if($annotation.emphasis_style-notin@('underline','highlight','box','circle','magnify','table_row','table_column','none_proven_visible')){$errors.Add('evidence_annotation_style_invalid')}
  if($annotation.visible_quote.extraction_method-notin@('dom_text','ocr','visual_verified')){$errors.Add('evidence_visible_quote_method_invalid')}
  if($annotation.visible_quote.extraction_method-eq'visual_verified'){
    if($annotation.visible_quote.verification_actor-notin@('codex_visual_review','human_review')-or-not(Test-JVText $annotation.visible_quote.review_ref)-or-not(Test-JVText $annotation.visible_quote.actual_observation)){$errors.Add('evidence_visual_verification_missing')}
  }
  if(-not(Test-JVDigest $annotation.overlay_spec_digest)-or-not(Test-JVDigest $annotation.annotated_asset_ref.sha256)){$errors.Add('evidence_annotation_output_digest_invalid')}
  if(@($annotation.attempts).Count-lt1){$errors.Add('evidence_annotation_attempt_missing')}
  foreach($attempt in @($annotation.attempts)){foreach($name in @('attempt_id','attempt_no','status','outcome_ref')){if(-not(Test-JVHasProperty $attempt $name)){$errors.Add("evidence_annotation_attempt_field_missing:$name")}};if($attempt.status-notin@('started','succeeded','failed','interrupted','reconciled')){$errors.Add('evidence_annotation_attempt_status_invalid')}}
  if($annotation.current_outcome.status-notin@('succeeded','failed','outcome_unknown','reconciled')){$errors.Add('evidence_annotation_outcome_invalid')}
  if([string]$annotation.source_fact_layer.label-eq[string]$annotation.creator_commentary_layer.label){$errors.Add('evidence_fact_commentary_layer_not_distinct')}
  if(@($Data.semantic_fact_bindings).Count-lt1){$errors.Add('semantic_fact_bindings_empty')}
  foreach($fact in @($Data.semantic_fact_bindings)){
    foreach($name in @('fact_id','fact_type','required','normalized_claim_value','normalized_visible_value','normalized_overlay_value','normalized_summary_value','normalization_basis','comparison_result')){if(-not(Test-JVHasProperty $fact $name)){$errors.Add("semantic_fact_required_missing:$name")}}
    if($fact.fact_type-notin@('entity','date','number','unit','source_identity','quote')){$errors.Add("semantic_fact_type_invalid:$($fact.fact_id)")}
    if($fact.comparison_result-notin@('match','mismatch','not_assessed')){$errors.Add("semantic_fact_result_invalid:$($fact.fact_id)")}
    if($annotation.visible_quote.extraction_method-eq'ocr'-and[bool]$fact.required-and$fact.fact_type-in@('entity','date','number','unit')-and$fact.comparison_result-ne'not_assessed'-and-not(Test-JVText $fact.visual_review_ref)){$errors.Add("semantic_fact_ocr_review_required:$($fact.fact_id)")}
  }
  $derived=Get-R6SemanticParityResult @($Data.semantic_fact_bindings)
  if([string]$Data.semantic_parity_result-ne$derived){$errors.Add('semantic_parity_precedence_mismatch')}
  if($derived-ne'match'-and$Data.pip.render_status-in@('render_ready','rendered')){$errors.Add('semantic_parity_blocker_bypassed')}
  if([string]$Data.pip.annotated_asset_ref.sha256-ne[string]$annotation.annotated_asset_ref.sha256){$errors.Add('evidence_pip_annotation_output_mismatch')}
  if(-not[string]::IsNullOrWhiteSpace($SessionRoot)){
    $assetRefs=@($annotation.original_capture_ref)
    if($Data.pip.render_status-eq'rendered'){$assetRefs+=@($annotation.annotated_asset_ref)}
    foreach($ref in $assetRefs){
      if(-not(Test-JVText $ref.relative_path)){continue};$root=[IO.Path]::GetFullPath($SessionRoot);$full=[IO.Path]::GetFullPath((Join-Path $root ([string]$ref.relative_path)));if(-not$full.StartsWith($root.TrimEnd([char]'\',[char]'/')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){$errors.Add('evidence_asset_root_escape')}elseif(-not(Test-Path -LiteralPath $full -PathType Leaf)){$errors.Add("evidence_asset_missing:$($ref.relative_path)")}
    }
  }
  return [object[]]$errors.ToArray()
}

function Test-R3AssetReuseAuthorizationV01 {
  param([object]$Authorization,[string]$SessionId,[string]$TaskId,[string]$AccountSnapshotId,[object]$AssetRef)
  $errors=[Collections.Generic.List[string]]::new();$required=@('schema_id','schema_version','authorization_id','authorization_mode','session_id','visual_task_id','account_snapshot_id','authorized_asset_refs','created_by','created_at','scope')
  foreach($name in $required){if(-not(Test-JVHasProperty $Authorization $name)){$errors.Add("asset_reuse_authorization_required_missing:$name")}}
  if($errors.Count){return [object[]]$errors.ToArray()}
  if($Authorization.schema_id-ne'taoge://schemas/r3/asset-reuse-authorization/v0.1'-or[string]$Authorization.schema_version-ne'0.1.0'){$errors.Add('asset_reuse_authorization_version_invalid')}
  if($Authorization.authorization_mode-notin@('user_supplied_for_current_run','human_selected_for_current_run','account_preapproved_asset')){$errors.Add('asset_reuse_authorization_mode_invalid')}
  if([string]$Authorization.session_id-ne$SessionId-or[string]$Authorization.visual_task_id-ne$TaskId-or[string]$Authorization.account_snapshot_id-ne$AccountSnapshotId){$errors.Add('asset_reuse_authorization_scope_mismatch')}
  if($Authorization.scope-ne'exact_session_task_asset_hash'){$errors.Add('asset_reuse_authorization_wildcard_forbidden')}
  $matches=@($Authorization.authorized_asset_refs|Where-Object{[string]$_.artifact_id-eq[string]$AssetRef.artifact_id-and[string]$_.sha256-eq[string]$AssetRef.sha256})
  if($matches.Count-ne1){$errors.Add('asset_reuse_authorization_asset_not_exact')}
  return [object[]]$errors.ToArray()
}

function Test-R3VisualTaskSourceRouteV01 {
  param([object]$Task,[string]$TestProfile='production',[object]$ReuseAuthorization=$null,[string]$SessionId='',[string]$AccountSnapshotId='')
  $errors=[Collections.Generic.List[string]]::new();$required=@('visual_task_id','source_class','source_class_reason','excluded_source_classes','disposition','production_path','provider_task_ref','source_capture_ref','existing_asset_ref','asset_reuse_authorization_ref','base_asset_requirement','postprocess_mode','task_status')
  foreach($name in $required){if(-not(Test-JVHasProperty $Task $name)){$errors.Add("visual_source_route_required_missing:$name")}}
  if($errors.Count){return [object[]]$errors.ToArray()}
  $classes=@('source_bound_evidence','explicit_existing_asset','generated_context')
  if($Task.source_class-notin$classes){$errors.Add('visual_source_class_invalid')}
  $excluded=@($Task.excluded_source_classes|ForEach-Object{[string]$_}|Sort-Object -Unique);if($excluded.Count-ne2-or@($classes|Where-Object{$_-ne[string]$Task.source_class-and$_-notin$excluded}).Count){$errors.Add('visual_source_class_not_exclusive')}
  if($Task.disposition-eq'create_deterministic_visual'-or$Task.production_path-eq'deterministic_render'){$errors.Add('deterministic_primary_visual_forbidden')}
  switch([string]$Task.source_class){
    'source_bound_evidence'{if($Task.disposition-ne'use_source_evidence'-or$Task.production_path-ne'source_capture'-or-not(Test-JVText $Task.source_capture_ref)-or$null-ne$Task.provider_task_ref){$errors.Add('source_evidence_route_invalid')}}
    'explicit_existing_asset'{if($Task.disposition-ne'use_existing_asset'-or$Task.production_path-ne'existing_asset'-or$null-eq$Task.existing_asset_ref-or$null-eq$Task.asset_reuse_authorization_ref-or$null-ne$Task.provider_task_ref){$errors.Add('existing_asset_route_invalid')}elseif($null-eq$ReuseAuthorization){$errors.Add('asset_reuse_authorization_missing')}else{foreach($e in(Test-R3AssetReuseAuthorizationV01 $ReuseAuthorization $SessionId ([string]$Task.visual_task_id) $AccountSnapshotId $Task.existing_asset_ref)){$errors.Add($e)}}}
    'generated_context'{if($Task.disposition-ne'generate_visual'-or$Task.production_path-ne'image_generation'-or$Task.base_asset_requirement-ne'codex_builtin_image2'-or$null-ne$Task.asset_reuse_authorization_ref){$errors.Add('generated_context_route_invalid')};if($TestProfile-eq'production'-and-not(Test-JVText $Task.provider_task_ref)){$errors.Add('generated_context_provider_task_missing')};if($TestProfile-in@('no_provider','reuse_only')-and$Task.task_status-ne'waiting_asset'){$errors.Add('test_profile_generated_context_must_wait_assets')}}
  }
  if($Task.postprocess_mode-notin@('none','deterministic_overlay','deterministic_crop','deterministic_overlay_and_crop')){$errors.Add('visual_postprocess_mode_invalid')}
  return [object[]]$errors.ToArray()
}

function Get-R7RevisionRestartNode {
  param([object[]]$ChangeItems,[string[]]$BlueprintNodeOrder)
  $best=$null;$bestIndex=[int]::MaxValue
  foreach($item in $ChangeItems){$index=[Array]::IndexOf($BlueprintNodeOrder,[string]$item.owning_producer);if($index-lt0){throw "revision_owner_not_in_blueprint:$($item.owning_producer)"};if($index-lt$bestIndex){$bestIndex=$index;$best=[string]$item.owning_producer}}
  return $best
}

function Test-R7DeliveryRevisionRequestV01 {
  param([object]$Request,[object[]]$CurrentSourceMap,[string[]]$BlueprintNodeOrder)
  $errors=[Collections.Generic.List[string]]::new();$required=@('schema_id','schema_version','revision_request_id','request_revision','session_id','current_delivery_ref','current_candidate_ref','candidate_source_map_ref','source_plan_ref','user_instruction','normalized_action','change_items','restart_from_node_id','invalidated_artifact_refs','carried_forward_artifact_refs','request_digest','request_status','created_by','created_at')
  foreach($name in $required){if(-not(Test-JVHasProperty $Request $name)){$errors.Add("delivery_revision_request_required_missing:$name")}}
  if($errors.Count){return [object[]]$errors.ToArray()}
  if($Request.schema_id-ne'taoge://schemas/r7/delivery-revision-request/v0.1'-or[string]$Request.schema_version-ne'0.1.0'){$errors.Add('delivery_revision_request_version_invalid')}
  if(@($Request.change_items).Count-lt1){$errors.Add('delivery_revision_request_items_empty')}
  if($Request.request_status-notin@('active','completed','superseded','blocked')){$errors.Add('delivery_revision_request_status_invalid')}
  $seen=@{};$sourceById=@{};foreach($source in $CurrentSourceMap){$sourceById[[string]$source.artifact_id]=$source}
  foreach($item in @($Request.change_items)){
    foreach($name in @('change_item_id','target_ref','target_sha256','change_class','original_instruction','normalized_instruction','owning_producer','candidate_source_map_ref')){if(-not(Test-JVHasProperty $item $name)){$errors.Add("delivery_revision_item_required_missing:$name")}}
    $key="$($item.target_ref.artifact_id)|$($item.change_class)";if($seen.ContainsKey($key)){$errors.Add("delivery_revision_item_duplicate:$key")}else{$seen[$key]=$true}
    $id=[string]$item.target_ref.artifact_id;if(-not$sourceById.ContainsKey($id)){$errors.Add("delivery_revision_target_not_current:$id")}elseif([string]$sourceById[$id].sha256-ne[string]$item.target_sha256){$errors.Add("delivery_revision_target_digest_mismatch:$id")}
    if([Array]::IndexOf($BlueprintNodeOrder,[string]$item.owning_producer)-lt0){$errors.Add("delivery_revision_owner_not_in_blueprint:$($item.owning_producer)")}
    if([string]$item.candidate_source_map_ref.sha256-ne[string]$Request.candidate_source_map_ref.sha256){$errors.Add("delivery_revision_source_map_ref_mismatch:$($item.change_item_id)")}
  }
  if($errors.Count-eq0){$derived=Get-R7RevisionRestartNode @($Request.change_items) $BlueprintNodeOrder;if([string]$Request.restart_from_node_id-ne$derived){$errors.Add('delivery_revision_restart_not_earliest')}}
  if(-not(Test-JVDigest $Request.request_digest)){$errors.Add('delivery_revision_request_digest_invalid')}
  return [object[]]$errors.ToArray()
}
