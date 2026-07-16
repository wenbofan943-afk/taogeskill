Set-StrictMode -Version 2.0
if(-not(Get-Command Write-TaogeUtf8NoBomJson -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')}
if(-not(Get-Command Read-YamlFile -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'YamlHelper.ps1')}

function Read-R7VisualJson {param([string]$Path);if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "visual_contract_file_missing:$Path"};Get-Content -LiteralPath $Path -Raw -Encoding UTF8|ConvertFrom-Json}
function Test-R7VisualProperty {param([object]$Object,[string]$Name);return $null-ne$Object-and$null-ne$Object.PSObject.Properties[$Name]}
function Test-R7VisualDigest {param([string]$Value);return $Value-match '^sha256:[a-f0-9]{64}$'}
function Get-R7VisualTextHash {param([string]$Text);$sha=[Security.Cryptography.SHA256]::Create();try{$bytes=[Text.Encoding]::UTF8.GetBytes($Text);return 'sha256:'+([BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant())}finally{$sha.Dispose()}}
function Get-R7VisualFileHash {param([string]$Path);return 'sha256:'+(Get-TaogeFileSha256 $Path)}
function Test-R7VisualDateTime {param([string]$Value);$parsed=[datetimeoffset]::MinValue;return -not[string]::IsNullOrWhiteSpace($Value)-and$Value-match '^\d{4}-\d{2}-\d{2}T.+(Z|[+-]\d{2}:\d{2})$'-and[datetimeoffset]::TryParse($Value,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$parsed)}
function ConvertTo-R7VisualCompactJson {param([object]$Value);return $Value|ConvertTo-Json -Depth 30 -Compress}

function Get-R7VisualOperationRegistry {
  param([string]$ProjectRoot,[string]$RegistryPath)
  $registry=Read-YamlFile $RegistryPath;if([string]$registry.schema_id-ne'taoge://registries/r7/visual-operations/v0.1'-or[string]$registry.schema_version-ne'0.1'){throw 'visual_operation_registry_version_invalid'}
  $ids=@{};foreach($operation in @($registry.operations)){$id=[string]$operation.operation_id;if([string]::IsNullOrWhiteSpace($id)-or$ids.ContainsKey($id)){throw "visual_operation_invalid_or_duplicate:$id"};$ids[$id]=$operation;if($operation.kind-ne'external_provider'){ $entry=[IO.Path]::GetFullPath((Join-Path $ProjectRoot ([string]$operation.entry)));$root=[IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\');if(-not$entry.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)-or-not(Test-Path -LiteralPath $entry -PathType Leaf)){throw "visual_operation_entry_invalid:$id"} };if($operation.reconcile_first-ne$true){throw "visual_operation_reconcile_required:$id"}}
  return [pscustomobject]@{Registry=$registry;ById=$ids;Digest=Get-R7VisualFileHash $RegistryPath}
}

function Test-R7VisualIntentDecision {
  param([object]$Document)
  $errors=[Collections.Generic.List[string]]::new();if([string]$Document.schema_id-ne'taoge://schemas/r3/visual-intent-decision/v0.1'){$errors.Add('intent_schema_invalid')};if([string]$Document.role-ne'visual_director'){$errors.Add('intent_role_invalid')};if(-not(Test-R7VisualDigest ([string]$Document.input_binding_digest))){$errors.Add('intent_input_digest_invalid')};if(-not(Test-R7VisualDateTime ([string]$Document.decided_at))){$errors.Add('intent_decided_at_invalid')}
  $jobs=@($Document.value_jobs);if([string]$Document.decision-eq'required'-and$jobs.Count-lt1){$errors.Add('intent_required_value_job_missing')};if([string]$Document.decision-eq'no_visual' -and ([string]::IsNullOrWhiteSpace([string]$Document.no_visual_reason)-or[string]$Document.no_visual_reason-match'(?i)cost|test|quick|not thought|没想到|成本|先跑通|测试方便')){$errors.Add('intent_no_visual_reason_invalid')};if([string]$Document.decision-ne'no_visual'-and-not[string]::IsNullOrWhiteSpace([string]$Document.no_visual_reason)){$errors.Add('intent_no_visual_reason_forbidden')};return [object[]]$errors.ToArray()
}

function Test-R7VisualSourceRouteDecision {
  param([object]$Document,[object]$Intent)
  $errors=[Collections.Generic.List[string]]::new();if([string]$Document.schema_id-ne'taoge://schemas/r3/visual-source-route-decision/v0.1'){$errors.Add('route_schema_invalid')};if([string]$Document.visual_task_id-ne[string]$Intent.visual_task_id){$errors.Add('route_intent_task_mismatch')};$source=[string]$Document.source_class
  if([string]$Intent.decision-eq'no_visual'){if($null-ne$Document.source_class-or[string]$Document.production_path-ne'not_applicable'-or[string]$Document.route_status-ne'not_applicable_no_visual'){$errors.Add('route_no_visual_not_applicable_required')}}elseif($source-notin@('source_bound_evidence','explicit_existing_asset','generated_context')){$errors.Add('route_source_class_invalid')}
  if($source-eq'source_bound_evidence' -and ($null-eq$Document.claim_ref-or$null-eq$Document.evidence_requirement_ref-or[string]$Document.production_path-ne'news_evidence_pip')){$errors.Add('route_source_evidence_binding_invalid')}
  if($source-eq'explicit_existing_asset' -and ($null-eq$Document.asset_reuse_authorization_ref-or[string]$Document.production_path-ne'authorized_existing_asset')){$errors.Add('route_existing_authorization_missing')}
  if($source-eq'generated_context' -and ([string]$Document.production_path-ne'codex_builtin_image2'-or$null-ne$Document.asset_reuse_authorization_ref)){$errors.Add('route_generated_context_invalid')};return [object[]]$errors.ToArray()
}

function Test-R7VisualPromptBrief {
  param([object]$Document,[object]$Route)
  $errors=[Collections.Generic.List[string]]::new();if([string]$Document.schema_id-ne'taoge://schemas/r3/visual-prompt-brief/v0.1'){$errors.Add('prompt_brief_schema_invalid')};if([string]$Route.source_class-ne'generated_context'){$errors.Add('prompt_brief_generated_context_only')};if([string]$Document.visual_task_ref.visual_task_id-ne[string]$Route.visual_task_id){$errors.Add('prompt_brief_task_mismatch')};if(@($Document.value_jobs).Count-lt1-or@($Document.forbidden_misrepresentation).Count-lt1){$errors.Add('prompt_brief_semantic_constraints_missing')};if(-not(Test-R7VisualDateTime ([string]$Document.created_at))){$errors.Add('prompt_brief_created_at_invalid')};return [object[]]$errors.ToArray()
}

function Invoke-R7DeterministicPromptCompile {
  param([string]$ProjectRoot,[string]$RegistryPath,[string]$BriefPath,[string]$RoutePath,[string]$CompiledAt,[string]$PromptOutputPath,[string]$PostprocessOutputPath)
  if(-not(Test-R7VisualDateTime $CompiledAt)){throw 'prompt_compiled_at_invalid'};$brief=Read-R7VisualJson $BriefPath;$route=Read-R7VisualJson $RoutePath
  $errors=@(Test-R7VisualPromptBrief $brief $route);if($errors.Count){throw 'visual_prompt_brief_invalid:'+([string]::Join('|',$errors))};$registry=Get-R7VisualOperationRegistry $ProjectRoot $RegistryPath
  $required=[Collections.Generic.List[string]]::new();foreach($id in @('image2_base_generation')+@($brief.required_postprocess_operations)+@('asset_finalize')){if(-not$required.Contains([string]$id)){$required.Add([string]$id)}};$missing=@($required|Where-Object{-not$registry.ById.ContainsKey($_)})
  $status=if($missing.Count){'waiting_capability'}else{'compiled'};$prompt='';$negative='';$promptHash='';$payload=[ordered]@{}
  if($status-eq'compiled'){
    $prompt=[string]::Join("`n",@('Create one static talking-head support image.','Audience problem: '+[string]$brief.audience_problem,'Value jobs: '+[string]::Join(', ',@($brief.value_jobs)),'Scene and subject: '+(ConvertTo-R7VisualCompactJson $brief.scene_and_subject),'Composition and attention path: '+(ConvertTo-R7VisualCompactJson $brief.composition_and_attention_path),'Target canvas and slot: '+(ConvertTo-R7VisualCompactJson $brief.target_canvas_and_slot),'Brand constraints: '+[string]::Join(' | ',@($brief.brand_visual_constraints)),'Truthfulness constraints: '+[string]::Join(' | ',@($brief.truthfulness_constraints)),'Text layer plan: '+(ConvertTo-R7VisualCompactJson $brief.text_layer_plan),'Reference bindings: '+(ConvertTo-R7VisualCompactJson $brief.reference_asset_bindings)))
    $negative=[string]::Join(' | ',@($brief.forbidden_misrepresentation));$promptHash=Get-R7VisualTextHash $prompt;$payload=[ordered]@{provider='codex_builtin_image2';prompt=$prompt;negative_prompt=$negative;target_canvas=$brief.target_canvas_and_slot;reference_assets=[object[]]@($brief.reference_asset_bindings)}
  }
  $postprocess=[pscustomobject][ordered]@{schema_id='taoge://schemas/r3/visual-postprocess-plan/v0.1';schema_version='0.1';postprocess_plan_id="POST-$($brief.prompt_brief_id)-R$($brief.brief_revision)";plan_revision=[int]$brief.brief_revision;session_id=[string]$brief.session_id;visual_task_id=[string]$route.visual_task_id;prompt_package_ref=[pscustomobject]@{prompt_package_id="PROMPT-$($brief.prompt_brief_id)-R$($brief.brief_revision)";package_revision=[int]$brief.brief_revision};operations=[object[]]@($required|ForEach-Object{[pscustomobject][ordered]@{sequence=1+[array]::IndexOf($required.ToArray(),$_);operation_id=$_;operation_version=$(if($registry.ById.ContainsKey($_)){[string]$registry.ById[$_].version}else{'not_registered'});status=$(if($registry.ById.ContainsKey($_)){'pending'}else{'waiting_capability'})}});required_operation_count=$required.Count;plan_status=$(if($missing.Count){'waiting_capability'}else{'pending_base_generation'});compiled_at=$CompiledAt;next_stage=$(if($missing.Count){'waiting_capability'}else{'image-asset-producer'})}
  Write-TaogeUtf8NoBomJson -Path $PostprocessOutputPath -Value $postprocess -Depth 30
  $package=[pscustomobject][ordered]@{schema_id='taoge://schemas/r3/visual-prompt-package/v0.1';schema_version='0.1';prompt_package_id="PROMPT-$($brief.prompt_brief_id)-R$($brief.brief_revision)";package_revision=[int]$brief.brief_revision;session_id=[string]$brief.session_id;visual_task_id=[string]$route.visual_task_id;brief_ref=[pscustomobject]@{prompt_brief_id=[string]$brief.prompt_brief_id;brief_revision=[int]$brief.brief_revision;sha256=Get-R7VisualFileHash $BriefPath};route_ref=[pscustomobject]@{route_decision_id=[string]$route.route_decision_id;route_revision=[int]$route.route_revision;sha256=Get-R7VisualFileHash $RoutePath};operation_registry_ref='routes/r7-visual-operation-registry.yaml';operation_registry_digest=[string]$registry.Digest;compile_status=$status;missing_operation_ids=[object[]]$missing;provider='codex_builtin_image2';full_prompt=$prompt;negative_constraint_block=$negative;provider_payload=[pscustomobject]$payload;prompt_sha256=$promptHash;compiled_by='deterministic_prompt_compiler';compiled_at=$CompiledAt;postprocess_plan_ref=[pscustomobject]@{postprocess_plan_id=[string]$postprocess.postprocess_plan_id;path=[IO.Path]::GetFullPath($PostprocessOutputPath);sha256=Get-R7VisualFileHash $PostprocessOutputPath};next_stage=$(if($missing.Count){'waiting_capability'}else{'image2_base_generation'})}
  Write-TaogeUtf8NoBomJson -Path $PromptOutputPath -Value $package -Depth 30;return $package
}

function Get-R7ReviewDerivation {
  param([object[]]$Dimensions,[string[]]$ExpectedIds)
  $ids=@($Dimensions|ForEach-Object{[string]$_.dimension_id});if($ids.Count-ne$ExpectedIds.Count-or@($ids|Sort-Object -Unique).Count-ne$ExpectedIds.Count-or@($ExpectedIds|Where-Object{$_-notin$ids}).Count){throw 'review_dimension_set_invalid'}
  foreach($dimension in $Dimensions){if([string]$dimension.verdict-notin@('pass','revise','reject','not_applicable')){throw "review_dimension_verdict_invalid:$($dimension.dimension_id)"};if([string]::IsNullOrWhiteSpace([string]$dimension.finding)){throw "review_dimension_finding_missing:$($dimension.dimension_id)"}}
  if(@($Dimensions|Where-Object{$_.verdict-eq'reject'}).Count){return 'reject'};if(@($Dimensions|Where-Object{$_.verdict-eq'revise'}).Count){return 'revise'};if(@($Dimensions|Where-Object{$_.verdict-ne'not_applicable'}).Count-eq0){return 'not_applicable'};return 'pass'
}

function Complete-R7VisualAssetReview {
  param([string]$InputPath,[string]$OutputPath,[string]$CurrentAssetSha256)
  $review=Read-R7VisualJson $InputPath;if([string]$review.schema_id-ne'taoge://schemas/r3/visual-asset-review/v0.1'){throw 'visual_asset_review_schema_invalid'};if($review.actual_image_viewed-isnot[bool]-or$review.reviewer_mutation_declared-isnot[bool]){throw 'visual_asset_review_boolean_type_invalid'};if([string]$review.role-ne'visual_quality_reviewer'-or$review.actual_image_viewed-ne$true-or[string]$review.observation_mode-ne'raster_inspection'){throw 'visual_asset_review_observation_invalid'};if($review.reviewer_mutation_declared-eq$true){throw 'reviewer_mutation_forbidden'}
  if([string]$review.reviewer_task_envelope_ref.task_envelope_id-eq[string]$review.producer_task_envelope_ref.task_envelope_id){throw 'reviewer_producer_role_conflict'};if(-not(Test-R7VisualDigest ([string]$review.asset_ref.sha256))){throw 'visual_asset_review_digest_invalid'};if(-not[string]::IsNullOrWhiteSpace($CurrentAssetSha256)-and[string]$review.asset_ref.sha256-ne$CurrentAssetSha256){throw 'visual_asset_review_stale'}
  $expected=@('task_alignment','attention_composition','truthfulness','text_number_accuracy','crop_safe_area','small_screen_readability','brand_fit','artifact_integrity');$derived=Get-R7ReviewDerivation @($review.dimensions) $expected
  if($derived-eq'revise' -and ($null-eq$review.revision_request-or[string]::IsNullOrWhiteSpace([string]$review.revision_request.minimal_revision_target)-or[string]::IsNullOrWhiteSpace([string]$review.revision_request.owning_producer)-or@($review.revision_request.stale_scope).Count-lt1)){throw 'visual_asset_revision_request_incomplete'};if($derived-in@('pass','not_applicable')-and$null-ne$review.revision_request){throw 'visual_asset_revision_request_forbidden'}
  $review.review_status=$derived;$review.freshness_status='current';$review.next_stage=switch($derived){'pass'{'visual-asset-finalizer'}'revise'{'owning_producer'}'reject'{'blocked'}default{'not_applicable'}};Write-TaogeUtf8NoBomJson -Path $OutputPath -Value $review -Depth 30;return $review
}

function Complete-R7DeliveryVisualReview {
  param([string]$InputPath,[string]$OutputPath,[string]$CurrentHtmlSha256)
  $review=Read-R7VisualJson $InputPath;if([string]$review.schema_id-ne'taoge://schemas/r3/delivery-visual-review/v0.1'){throw 'delivery_visual_review_schema_invalid'};foreach($booleanField in @('actual_delivery_assets_viewed','actual_screenshots_viewed','base_asset_view_only','reviewer_mutation_declared')){if($review.$booleanField-isnot[bool]){throw "delivery_visual_review_boolean_type_invalid:$booleanField"}};if([string]$review.role-ne'delivery_reviewer'-or$review.actual_delivery_assets_viewed-ne$true-or$review.actual_screenshots_viewed-ne$true-or$review.base_asset_view_only-ne$false){throw 'delivery_visual_review_observation_invalid'};if($review.reviewer_mutation_declared-eq$true){throw 'reviewer_mutation_forbidden'};foreach($producer in @($review.producer_task_envelope_refs)){if([string]$producer.task_envelope_id-eq[string]$review.reviewer_task_envelope_ref.task_envelope_id){throw 'delivery_reviewer_producer_role_conflict'}};if([string]$review.html_ref.sha256-ne$CurrentHtmlSha256){throw 'delivery_visual_review_stale'}
  foreach($ref in @($review.delivery_asset_refs)+@($review.html_ref,$review.desktop_screenshot_ref,$review.mobile_screenshot_ref)){if(-not(Test-R7VisualDigest ([string]$ref.sha256))){throw 'delivery_visual_review_digest_invalid'}}
  $expected=@('final_text_accuracy','crop_and_safe_area','insertion_context','platform_card_and_cover','duplicate_display','page_hierarchy');$derived=Get-R7ReviewDerivation @($review.dimensions) $expected
  if($derived-eq'revise' -and ($null-eq$review.revision_request-or[string]::IsNullOrWhiteSpace([string]$review.revision_request.minimal_revision_target)-or[string]::IsNullOrWhiteSpace([string]$review.revision_request.owning_producer)-or@($review.revision_request.stale_scope).Count-lt1)){throw 'delivery_visual_revision_request_incomplete'};if($derived-in@('pass','not_applicable')-and$null-ne$review.revision_request){throw 'delivery_visual_revision_request_forbidden'}
  $digestSource=[string]::Join('|',@($review.delivery_asset_refs|ForEach-Object{[string]$_.sha256})+@([string]$review.html_ref.sha256,[string]$review.desktop_screenshot_ref.sha256,[string]$review.mobile_screenshot_ref.sha256));$review.input_bundle_digest=Get-R7VisualTextHash $digestSource;$review.review_status=$derived;$review.freshness_status='current';$review.next_stage=switch($derived){'pass'{'business-delivery-acceptance'}'revise'{'owning_producer'}'reject'{'blocked'}default{'not_applicable'}};Write-TaogeUtf8NoBomJson -Path $OutputPath -Value $review -Depth 30;return $review
}

function Test-R7VisualStageSet {
  param([object]$Document,[string]$ExpectedStage)
  $errors=[Collections.Generic.List[string]]::new()
  if([string]$Document.schema_id-ne'taoge://schemas/r3/visual-stage-set/v0.1'){$errors.Add('visual_stage_set_schema_invalid')}
  if([string]$Document.stage-ne$ExpectedStage){$errors.Add('visual_stage_set_stage_invalid')}
  $records=@($Document.records)
  if([int]$Document.record_count-ne$records.Count){$errors.Add('visual_stage_set_count_mismatch')}
  if([string]$Document.set_status-eq'complete_no_visual'-and$ExpectedStage-in@('visual_prompt_brief','visual_asset_review')-and$records.Count-ne0){$errors.Add('visual_stage_set_no_visual_records_forbidden')}
  if([string]$Document.set_status-eq'complete'-and$ExpectedStage-ne'visual_prompt_brief'-and$records.Count-lt1){$errors.Add('visual_stage_set_complete_records_missing')}
  $taskIds=[Collections.Generic.List[string]]::new()
  foreach($record in $records){
    $taskId=''
    switch($ExpectedStage){
      'visual_intent_decision'{$taskId=[string]$record.visual_task_id;foreach($errorItem in @(Test-R7VisualIntentDecision $record)){$errors.Add([string]$errorItem)}}
      'visual_source_route_decision'{
        $taskId=[string]$record.visual_task_id
        if([string]$record.schema_id-ne'taoge://schemas/r3/visual-source-route-decision/v0.1'){$errors.Add('route_schema_invalid')}
        if([string]$record.role-ne'visual_director'){$errors.Add('route_role_invalid')}
        if([string]$record.source_class-eq'generated_context'-and[string]$record.production_path-ne'codex_builtin_image2'){$errors.Add('route_generated_context_invalid')}
        if([string]$record.source_class-eq'explicit_existing_asset'-and$null-eq$record.asset_reuse_authorization_ref){$errors.Add('route_existing_authorization_missing')}
        if([string]$record.source_class-eq'source_bound_evidence'-and($null-eq$record.claim_ref-or$null-eq$record.evidence_requirement_ref)){$errors.Add('route_source_evidence_binding_invalid')}
      }
      'visual_prompt_brief'{$taskId=[string]$record.visual_task_ref.visual_task_id;foreach($errorItem in @(Test-R7VisualPromptBrief $record ([pscustomobject]@{source_class='generated_context';visual_task_id=$taskId}))){$errors.Add([string]$errorItem)}}
      'visual_asset_review'{
        $taskId=[string]$record.visual_task_id
        if([string]$record.schema_id-ne'taoge://schemas/r3/visual-asset-review/v0.1'){$errors.Add('visual_asset_review_schema_invalid')}
        if([string]$record.role-ne'visual_quality_reviewer'-or$record.reviewer_mutation_declared-ne$false){$errors.Add('visual_asset_review_role_or_mutation_invalid')}
        if(@($record.dimensions).Count-ne8){$errors.Add('visual_asset_review_dimension_count_invalid')}
        if([string]$record.review_status-notin@('pass','revise','reject','not_applicable')){$errors.Add('visual_asset_review_status_invalid')}
      }
    }
    if([string]::IsNullOrWhiteSpace($taskId)){$errors.Add('visual_stage_set_task_id_missing')}elseif($taskIds.Contains($taskId)){$errors.Add("visual_stage_set_task_duplicate:$taskId")}else{$taskIds.Add($taskId)}
  }
  if([string]$Document.set_status-eq'complete_no_visual'-and$ExpectedStage-eq'visual_intent_decision'-and@($records|Where-Object{[string]$_.decision-ne'no_visual'}).Count){$errors.Add('visual_stage_set_no_visual_intent_mismatch')}
  if([string]$Document.set_status-eq'complete_no_visual'-and$ExpectedStage-eq'visual_source_route_decision'-and@($records|Where-Object{[string]$_.route_status-ne'not_applicable_no_visual'}).Count){$errors.Add('visual_stage_set_no_visual_route_mismatch')}
  return [object[]]$errors.ToArray()
}

function Test-R7DeliveryVisualReviewDocument {
  param([object]$Review)
  $errors=[Collections.Generic.List[string]]::new()
  if([string]$Review.schema_id-ne'taoge://schemas/r3/delivery-visual-review/v0.1'){$errors.Add('delivery_visual_review_schema_invalid')}
  if([string]$Review.role-ne'delivery_reviewer'-or$Review.reviewer_mutation_declared-ne$false){$errors.Add('delivery_visual_review_role_or_mutation_invalid')}
  if($Review.actual_delivery_assets_viewed-ne$true-or$Review.actual_screenshots_viewed-ne$true-or$Review.base_asset_view_only-ne$false){$errors.Add('delivery_visual_review_observation_invalid')}
  if(@($Review.dimensions).Count-ne6){$errors.Add('delivery_visual_review_dimension_count_invalid')}
  if(-not(Test-R7VisualDigest ([string]$Review.input_bundle_digest))){$errors.Add('delivery_visual_review_digest_invalid')}
  if([string]$Review.review_status-notin@('pass','revise','reject','not_applicable')){$errors.Add('delivery_visual_review_status_invalid')}
  return [object[]]$errors.ToArray()
}

function Test-R7ExternalVisualOperationEvidence {
  param([object]$Evidence)
  if([string]$Evidence.status-ne'succeeded'){return 'not_success'};$attempts=@($Evidence.attempt_refs).Count;$hasOutput=-not[string]::IsNullOrWhiteSpace([string]$Evidence.output_ref);$hasOutcome=-not[string]::IsNullOrWhiteSpace([string]$Evidence.outcome_ref)
  if($attempts-ge1-and$hasOutput-and$hasOutcome){return 'complete'};if($attempts-eq0-and$hasOutput-and$hasOutcome-and[string]$Evidence.reconcile_status-eq'reused_existing_output'){return 'reconciled_reuse'};return 'external_evidence_parity_missing'
}

function Test-R7VisualSemanticWorkPackage {
  param([object]$Package,[string]$ExpectedRegistryDigest)
  $errors=[Collections.Generic.List[string]]::new();$expected=@('visual_intent_decision','visual_source_route_decision','visual_prompt_brief','visual_asset_review','delivery_visual_review');if([string]$Package.schema_id-ne'taoge://schemas/r3/visual-semantic-work-package/v0.1'){$errors.Add('work_package_schema_invalid')};if([string]$Package.operation_registry_digest-ne$ExpectedRegistryDigest){$errors.Add('work_package_registry_stale')};if([string]::Join('|',@($Package.stage_order))-ne[string]::Join('|',$expected)){$errors.Add('work_package_stage_order_invalid')};if(@($Package.stages).Count-ne5-or@($Package.stages|ForEach-Object{$_.stage_id}|Sort-Object -Unique).Count-ne5){$errors.Add('work_package_stage_cardinality_invalid')};$roles=$Package.role_separation;if([string]$roles.visual_producer_role-eq[string]$roles.asset_reviewer_role-or[string]$roles.asset_reviewer_role-eq[string]$roles.delivery_reviewer_role-or[bool]$roles.unregistered_helper_detected){$errors.Add('work_package_role_separation_invalid')};return [object[]]$errors.ToArray()
}
