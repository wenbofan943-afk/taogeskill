param([string]$ProjectRoot='',[string]$ReportPath='')
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($ProjectRoot)){$ProjectRoot=Split-Path -Parent $PSScriptRoot}
$ProjectRoot=[IO.Path]::GetFullPath($ProjectRoot)
if([string]::IsNullOrWhiteSpace($ReportPath)){$ReportPath=Join-Path $ProjectRoot 'state/checks/r7-l3-h2-visual-semantic.json'}
. (Join-Path $ProjectRoot 'tools/WindowsRuntimeHelper.ps1')
. (Join-Path $ProjectRoot 'tools/R7VisualSemanticRuntime.ps1')
. (Join-Path $ProjectRoot 'tools/R7MaturityEvidence.ps1')

$work=[IO.Path]::GetFullPath((Join-Path $ProjectRoot 'state/checks/r7-l3-h2-fixture-work'))
if(-not $work.StartsWith($ProjectRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'fixture_work_root_escape'}
if(Test-Path -LiteralPath $work){Remove-Item -LiteralPath $work -Recurse -Force}
[IO.Directory]::CreateDirectory($work)|Out-Null
$cases=[Collections.Generic.List[object]]::new()
function Add-Case([string]$Id,[bool]$Pass,[string]$Evidence){$script:cases.Add([pscustomobject][ordered]@{case_id=$Id;status=$(if($Pass){'pass'}else{'fail'});evidence=$Evidence})}
function Assert-Throws([scriptblock]$Action,[string]$Needle){try{&$Action|Out-Null;return $false}catch{return $_.Exception.Message-like"*$Needle*"}}
function Clone-Object([object]$Value){return $Value|ConvertTo-Json -Depth 30|ConvertFrom-Json}
function Write-Json([string]$Name,[object]$Value){$path=Join-Path $work $Name;Write-TaogeUtf8NoBomJson -Path $path -Value $Value -Depth 30;return $path}

$digest='sha256:'+('a'*64);$digestB='sha256:'+('b'*64);$at='2026-07-16T10:00:00+08:00'
$registryPath=Join-Path $ProjectRoot 'routes/r7-visual-operation-registry.yaml'
$registry=Get-R7VisualOperationRegistry $ProjectRoot $registryPath
$cliOutput=@(& (Join-Path $ProjectRoot 'tools/invoke-r7-visual-semantic.ps1') -Mode validate_operation_registry -ProjectRoot $ProjectRoot -RegistryPath $registryPath 2>&1);$cliSucceeded=$?
Add-Case 'operation_registry_valid' ($registry.ById.Count-ge10-and$cliSucceeded-and([string]::Join(';',$cliOutput)).Contains('"result_code":"pass"')) ("operations="+$registry.ById.Count+';cli='+[string]::Join(';',$cliOutput))

$intent=[pscustomobject][ordered]@{schema_id='taoge://schemas/r3/visual-intent-decision/v0.1';schema_version='0.1';decision_id='INTENT-001';decision_revision=1;session_id='S-H2';visual_task_id='VT-001';beat_ref=[pscustomobject]@{beat_id='B-01'};role='visual_director';account_snapshot_ref=[pscustomobject]@{snapshot_id='AS-01'};viewer_problem='comprehension_gap';value_jobs=@('understanding');counterfactual_loss='The mechanism remains abstract without a concrete scene.';decision='required';no_visual_reason='';evidence_requirement_ref=$null;producer_task_envelope_ref=[pscustomobject]@{task_envelope_id='TE-DIRECTOR-1'};input_binding_digest=$digest;decided_at=$at;next_stage='visual_source_route_decision'}
Add-Case 'intent_valid' (@(Test-R7VisualIntentDecision $intent).Count-eq0) 'required intent accepted'
$zero=Clone-Object $intent;$zero.decision_id='INTENT-000';$zero.visual_task_id='VT-000';$zero.viewer_problem='none';$zero.value_jobs=@();$zero.counterfactual_loss='The spoken explanation is already concrete and the uninterrupted face shot carries trust.';$zero.decision='no_visual';$zero.no_visual_reason='The beat is intentionally talking-head because facial delivery is the information.';$zero.next_stage='complete_no_visual'
$zeroRoute=[pscustomobject][ordered]@{schema_id='taoge://schemas/r3/visual-source-route-decision/v0.1';schema_version='0.1';route_decision_id='ROUTE-000';route_revision=1;session_id='S-H2';visual_task_id='VT-000';intent_ref=[pscustomobject]@{decision_id='INTENT-000'};role='visual_director';source_class=$null;classification_basis='No asset task exists.';claim_ref=$null;evidence_requirement_ref=$null;asset_reuse_authorization_ref=$null;account_snapshot_ref=[pscustomobject]@{snapshot_id='AS-01'};excluded_source_class_reasons=@();production_path='not_applicable';test_profile='no_provider';route_status='not_applicable_no_visual';producer_task_envelope_ref=[pscustomobject]@{task_envelope_id='TE-DIRECTOR-1'};input_binding_digest=$digest;decided_at=$at;next_stage='complete_no_visual'}
Add-Case 'zero_visual_complete' (@(Test-R7VisualIntentDecision $zero).Count-eq0-and@(Test-R7VisualSourceRouteDecision $zeroRoute $zero).Count-eq0) 'no visual has explicit product reason and terminal route'

function New-Route([string]$Class){
  $r=[pscustomobject][ordered]@{schema_id='taoge://schemas/r3/visual-source-route-decision/v0.1';schema_version='0.1';route_decision_id="ROUTE-$Class";route_revision=1;session_id='S-H2';visual_task_id='VT-001';intent_ref=[pscustomobject]@{decision_id='INTENT-001'};role='visual_director';source_class=$Class;classification_basis='Exclusive source classification fixture.';claim_ref=$null;evidence_requirement_ref=$null;asset_reuse_authorization_ref=$null;account_snapshot_ref=[pscustomobject]@{snapshot_id='AS-01'};excluded_source_class_reasons=@();production_path='codex_builtin_image2';test_profile='no_provider';route_status='ready';producer_task_envelope_ref=[pscustomobject]@{task_envelope_id='TE-DIRECTOR-1'};input_binding_digest=$digest;decided_at=$at;next_stage='visual_prompt_brief'}
  if($Class-eq'source_bound_evidence'){$r.claim_ref=[pscustomobject]@{claim_id='CL-1'};$r.evidence_requirement_ref=[pscustomobject]@{requirement_id='ER-1'};$r.production_path='news_evidence_pip';$r.next_stage='visual_asset_review'}
  if($Class-eq'explicit_existing_asset'){$r.asset_reuse_authorization_ref=[pscustomobject]@{authorization_id='AUTH-1';asset_sha256=$digest};$r.production_path='authorized_existing_asset';$r.next_stage='visual_asset_review'}
  return $r
}
$evidenceRoute=New-Route 'source_bound_evidence';$existingRoute=New-Route 'explicit_existing_asset';$generatedRoute=New-Route 'generated_context'
Add-Case 'source_bound_evidence_route' (@(Test-R7VisualSourceRouteDecision $evidenceRoute $intent).Count-eq0) 'claim and evidence binding retained'
$multiClaimRoute=Clone-Object $evidenceRoute;$multiClaimRoute.claim_ref=[pscustomobject]@{claim_ids=@('CL-1','CL-2')}
Add-Case 'source_bound_evidence_multi_claim_rejected' (@(Test-R7VisualSourceRouteDecision $multiClaimRoute $intent)-contains'route_source_evidence_requires_single_claim') 'one evidence PIP task must bind exactly one claim'
Add-Case 'explicit_existing_asset_route' (@(Test-R7VisualSourceRouteDecision $existingRoute $intent).Count-eq0) 'exact reuse authorization retained'
Add-Case 'generated_context_route' (@(Test-R7VisualSourceRouteDecision $generatedRoute $intent).Count-eq0) 'Image 2 is generated-context base only'

$brief=[pscustomobject][ordered]@{schema_id='taoge://schemas/r3/visual-prompt-brief/v0.1';schema_version='0.1';prompt_brief_id='BRIEF-001';brief_revision=1;session_id='S-H2';visual_task_ref=[pscustomobject]@{visual_task_id='VT-001'};route_ref=[pscustomobject]@{route_decision_id=$generatedRoute.route_decision_id;route_revision=1};role='visual_director';audience_problem='The supply-demand mechanism is abstract.';value_jobs=@('understanding','memory');scene_and_subject=[pscustomobject]@{scene='used-car lot';subject='inventory rows and one buyer'};composition_and_attention_path=[pscustomobject]@{entry='buyer';path='buyer to inventory rows'};target_canvas_and_slot=[pscustomobject]@{width_px=1080;height_px=1920;ratio_width=9;ratio_height=16;orientation='portrait';placement_slot='fullscreen'};brand_visual_constraints=@('observational documentary tone');truthfulness_constraints=@('metaphorical scene, not statistical evidence');forbidden_misrepresentation=@('no fabricated charts','no readable invented numbers');text_layer_plan=[pscustomobject]@{mode='deterministic_overlay';units=@('供需失衡')};reference_asset_bindings=@();required_postprocess_operations=@('crop_fit_pad','text_overlay');revision_reason='initial semantic brief';producer_task_envelope_ref=[pscustomobject]@{task_envelope_id='TE-DIRECTOR-1'};input_binding_digest=$digest;brief_status='ready_for_deterministic_compile';created_at=$at;next_stage='image-prompt-compiler'}
$briefPath=Write-Json 'brief-r1.json' $brief;$routePath=Write-Json 'route.json' $generatedRoute;$promptPath=Join-Path $work 'prompt-r1.json';$postPath=Join-Path $work 'post-r1.json'
$package=Invoke-R7DeterministicPromptCompile $ProjectRoot $registryPath $briefPath $routePath $at $promptPath $postPath
Add-Case 'prompt_deterministic_compile' ($package.compile_status-eq'compiled'-and(Test-R7VisualDigest $package.prompt_sha256)-and(Test-Path $postPath)) 'typed brief compiled with registry and postprocess plan'
$brief2=Clone-Object $brief;$brief2.brief_revision=2;$brief2.revision_reason='clarify attention path';$brief2.composition_and_attention_path=[pscustomobject]@{entry='single buyer';path='buyer to four dense inventory rows'};$brief2Path=Write-Json 'brief-r2.json' $brief2;$package2=Invoke-R7DeterministicPromptCompile $ProjectRoot $registryPath $brief2Path $routePath $at (Join-Path $work 'prompt-r2.json') (Join-Path $work 'post-r2.json')
Add-Case 'prompt_revision_changes_digest' ($package2.prompt_sha256-ne$package.prompt_sha256-and$package2.package_revision-eq2) 'semantic revision yields a new immutable prompt digest'
$missingBrief=Clone-Object $brief;$missingBrief.prompt_brief_id='BRIEF-MISSING';$missingBrief.required_postprocess_operations=@('unregistered_helper')
$missing=Invoke-R7DeterministicPromptCompile $ProjectRoot $registryPath (Write-Json 'brief-missing.json' $missingBrief) $routePath $at (Join-Path $work 'prompt-missing.json') (Join-Path $work 'post-missing.json')
Add-Case 'unregistered_operation_waits' ($missing.compile_status-eq'waiting_capability'-and$missing.next_stage-eq'waiting_capability'-and$missing.missing_operation_ids[0]-eq'unregistered_helper') 'no one-off helper is invented'

Add-Case 'provider_attempt_outcome_output_complete' ((Test-R7ExternalVisualOperationEvidence ([pscustomobject]@{status='succeeded';attempt_refs=@('A1');outcome_ref='O1';output_ref='OUT1';reconcile_status='not_needed'}))-eq'complete') 'attempt/outcome/output parity'
Add-Case 'provider_reconciled_reuse_complete' ((Test-R7ExternalVisualOperationEvidence ([pscustomobject]@{status='succeeded';attempt_refs=@();outcome_ref='O1';output_ref='OUT1';reconcile_status='reused_existing_output'}))-eq'reconciled_reuse') 'interrupted output reconciled without provider recall'
Add-Case 'provider_missing_evidence_rejected' ((Test-R7ExternalVisualOperationEvidence ([pscustomobject]@{status='succeeded';attempt_refs=@('A1');outcome_ref='';output_ref='OUT1';reconcile_status='not_needed'}))-eq'external_evidence_parity_missing') 'false provider success rejected'

$assetDims=@('task_alignment','attention_composition','truthfulness','text_number_accuracy','crop_safe_area','small_screen_readability','brand_fit','artifact_integrity')|ForEach-Object{[pscustomobject]@{dimension_id=$_;verdict='pass';finding="$_ inspected on raster"}}
$assetReview=[pscustomobject][ordered]@{schema_id='taoge://schemas/r3/visual-asset-review/v0.1';schema_version='0.1';visual_asset_review_id='VAR-1';review_revision=1;session_id='S-H2';visual_task_id='VT-001';role='visual_quality_reviewer';reviewer_task_envelope_ref=[pscustomobject]@{task_envelope_id='TE-REVIEW-1'};producer_task_envelope_ref=[pscustomobject]@{task_envelope_id='TE-PRODUCER-1'};asset_ref=[pscustomobject]@{asset_id='ASSET-1';sha256=$digest};contract_refs=[pscustomobject]@{intent_id='INTENT-001';route_id=$generatedRoute.route_decision_id};actual_image_viewed=$true;observation_mode='raster_inspection';dimensions=@($assetDims);review_status='reject';freshness_status='stale';blocking_issue_codes=@();revision_request=$null;reviewer_mutation_declared=$false;reviewed_at=$at;next_stage='blocked'}
$assetResult=Complete-R7VisualAssetReview (Write-Json 'asset-review-in.json' $assetReview) (Join-Path $work 'asset-review-out.json') $digest
Add-Case 'asset_eight_dimension_review' ($assetResult.review_status-eq'pass'-and$assetResult.next_stage-eq'visual-asset-finalizer') 'eight dimensions derive pass'
$assetRevise=Clone-Object $assetReview;$assetRevise.dimensions[0].verdict='revise'
Add-Case 'asset_revision_request_required' (Assert-Throws {Complete-R7VisualAssetReview (Write-Json 'asset-revise.json' $assetRevise) (Join-Path $work 'asset-revise-out.json') $digest} 'visual_asset_revision_request_incomplete') 'revise cannot omit owner and stale scope'
$overreach=Clone-Object $assetReview;$overreach.reviewer_mutation_declared=$true
Add-Case 'asset_reviewer_overreach_rejected' (Assert-Throws {Complete-R7VisualAssetReview (Write-Json 'asset-overreach.json' $overreach) (Join-Path $work 'asset-overreach-out.json') $digest} 'reviewer_mutation_forbidden') 'reviewer cannot mutate producer output'
Add-Case 'asset_hash_stale_rejected' (Assert-Throws {Complete-R7VisualAssetReview (Write-Json 'asset-stale.json' $assetReview) (Join-Path $work 'asset-stale-out.json') $digestB} 'visual_asset_review_stale') 'review binds current raster hash'

$deliveryDims=@('final_text_accuracy','crop_and_safe_area','insertion_context','platform_card_and_cover','duplicate_display','page_hierarchy')|ForEach-Object{[pscustomobject]@{dimension_id=$_;verdict='pass';finding="$_ inspected in final evidence"}}
$delivery=[pscustomobject][ordered]@{schema_id='taoge://schemas/r3/delivery-visual-review/v0.1';schema_version='0.1';delivery_visual_review_id='DVR-1';review_revision=1;session_id='S-H2';role='delivery_reviewer';reviewer_task_envelope_ref=[pscustomobject]@{task_envelope_id='TE-DELIVERY-REVIEW'};producer_task_envelope_refs=@([pscustomobject]@{task_envelope_id='TE-RENDERER'});delivery_asset_refs=@([pscustomobject]@{asset_id='FINAL-1';sha256=$digest});html_ref=[pscustomobject]@{path='final-delivery.html';sha256=$digest};desktop_screenshot_ref=[pscustomobject]@{path='desktop.png';sha256=$digest};mobile_screenshot_ref=[pscustomobject]@{path='mobile.png';sha256=$digest};actual_delivery_assets_viewed=$true;actual_screenshots_viewed=$true;base_asset_view_only=$false;dimensions=@($deliveryDims);review_status='reject';freshness_status='stale';blocking_issue_codes=@();revision_request=$null;reviewer_mutation_declared=$false;input_bundle_digest=$digest;reviewed_at=$at;next_stage='blocked'}
$deliveryResult=Complete-R7DeliveryVisualReview (Write-Json 'delivery-in.json' $delivery) (Join-Path $work 'delivery-out.json') $digest
Add-Case 'delivery_final_view_review' ($deliveryResult.review_status-eq'pass'-and$deliveryResult.next_stage-eq'business-delivery-acceptance') 'final assets and desktop/mobile evidence inspected'
$baseOnly=Clone-Object $delivery;$baseOnly.base_asset_view_only=$true
Add-Case 'delivery_base_only_rejected' (Assert-Throws {Complete-R7DeliveryVisualReview (Write-Json 'delivery-base-only.json' $baseOnly) (Join-Path $work 'delivery-base-only-out.json') $digest} 'delivery_visual_review_observation_invalid') 'base asset review cannot approve delivery'
Add-Case 'delivery_html_hash_stale_rejected' (Assert-Throws {Complete-R7DeliveryVisualReview (Write-Json 'delivery-stale.json' $delivery) (Join-Path $work 'delivery-stale-out.json') $digestB} 'delivery_visual_review_stale') 'final HTML review is revision scoped'

$stageOrder=@('visual_intent_decision','visual_source_route_decision','visual_prompt_brief','visual_asset_review','delivery_visual_review')
$stages=@($stageOrder|ForEach-Object{[pscustomobject]@{stage_id=$_;status='pending';artifact_ref=$null}})
$workPackage=[pscustomobject][ordered]@{schema_id='taoge://schemas/r3/visual-semantic-work-package/v0.1';schema_version='0.1';work_package_id='VSWP-1';package_revision=1;session_id='S-H2';visual_task_id='VT-001';stage_order=$stageOrder;stages=$stages;role_separation=[pscustomobject]@{visual_producer_role='visual_director';asset_reviewer_role='visual_quality_reviewer';delivery_reviewer_role='delivery_reviewer';unregistered_helper_detected=$false};operation_registry_ref='routes/r7-visual-operation-registry.yaml';operation_registry_digest=$registry.Digest;package_status='ready_for_production';current_stage='visual_intent_decision';created_at=$at;next_stage='visual_intent_decision'}
Add-Case 'five_stage_work_package' (@(Test-R7VisualSemanticWorkPackage $workPackage $registry.Digest).Count-eq0) 'ordered semantic package and role separation close'
$helper=Clone-Object $workPackage;$helper.role_separation.unregistered_helper_detected=$true
Add-Case 'unregistered_helper_rejected' (@(Test-R7VisualSemanticWorkPackage $helper $registry.Digest)-contains'work_package_role_separation_invalid') 'operation registry is mandatory'

$schemaPairs=@(
  @('visual-intent-decision.v0.1.schema.json',(Write-Json 'intent.json' $intent)),
  @('visual-source-route-decision.v0.1.schema.json',$routePath),
  @('visual-prompt-brief.v0.1.schema.json',$briefPath),
  @('visual-prompt-package.v0.1.schema.json',$promptPath),
  @('visual-postprocess-plan.v0.1.schema.json',$postPath),
  @('visual-asset-review.v0.1.schema.json',(Join-Path $work 'asset-review-out.json')),
  @('delivery-visual-review.v0.1.schema.json',(Join-Path $work 'delivery-out.json')),
  @('visual-semantic-work-package.v0.1.schema.json',(Write-Json 'work-package.json' $workPackage))
)
foreach($pair in $schemaPairs){$schemaErrors=@(Test-R7MaturitySchemaInstance (Join-Path $ProjectRoot "templates/schema/r3/$($pair[0])") $pair[1]);if($schemaErrors.Count){throw "h2_schema_instance_invalid:$($pair[0]):$([string]::Join('|',$schemaErrors))"}}

$failed=@($cases|Where-Object{$_.status-ne'pass'})
$catalog=Get-Content -LiteralPath (Join-Path $ProjectRoot 'examples/r7-l3-h2-visual-semantic-fixtures/fixture-catalog.json') -Raw -Encoding UTF8|ConvertFrom-Json
$catalogIds=@($catalog.cases);$caseIds=@($cases.case_id);$catalogParity=($catalogIds.Count-eq$caseIds.Count-and@($catalogIds|Where-Object{$_-notin$caseIds}).Count-eq0)
if(-not$catalogParity){$failed+=@([pscustomobject]@{case_id='fixture_catalog_parity';status='fail';evidence='catalog and checker differ'})}
$report=[pscustomobject][ordered]@{schema_id='taoge://reports/r7/l3-h2-visual-semantic/v0.1';generated_at=$at;profile='offline_no_provider';result=$(if($failed.Count){'fail'}else{'pass'});operation_registry_digest=$registry.Digest;case_count=$cases.Count;cases=[object[]]$cases}
Write-TaogeUtf8NoBomJson -Path $ReportPath -Value $report -Depth 30
if($failed.Count){$failed|ForEach-Object{[Console]::Error.WriteLine("FAIL $($_.case_id): $($_.evidence)")};exit 1}
Write-Output "PASS R7-L3-H2 visual semantic: $($cases.Count) cases"
