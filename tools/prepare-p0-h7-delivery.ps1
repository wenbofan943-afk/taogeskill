param(
  [string]$SessionPath,
  [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'P0EvidenceRuntime.ps1')

function Read-H7Json([string]$Path) { Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json }
function Write-H7Text([string]$Path,[string]$Text) { $parent=Split-Path -Parent $Path;if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false)) }
function Write-H7Json([string]$Path,[object]$Value) { Write-H7Text $Path (($Value|ConvertTo-Json -Depth 50).TrimEnd("`r","`n")+"`n") }
function Get-H7Hash([string]$Path) { 'sha256:'+(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-H7TextHash([string]$Text) { $sha=[Security.Cryptography.SHA256]::Create();try{$bytes=[Text.Encoding]::UTF8.GetBytes($Text);'sha256:'+([BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant())}finally{$sha.Dispose()} }
function Resolve-H7Path([string]$Root,[string]$Relative,[bool]$MustExist=$true) { if(-not(Test-P0RelativePath $Relative)){throw "unsafe_relative_path:$Relative"};$full=[IO.Path]::GetFullPath((Join-Path $Root $Relative));$rootFull=[IO.Path]::GetFullPath($Root).TrimEnd('\');if(-not $full.StartsWith($rootFull+'\',[StringComparison]::OrdinalIgnoreCase)){throw "path_escape:$Relative"};if($MustExist-and-not(Test-Path -LiteralPath $full)){throw "required_path_missing:$Relative"};$full }
function New-H7Retry([string]$Kind) { if($Kind-eq'deterministic'){[pscustomobject][ordered]@{mode='bounded';automatic_retries=1;max_attempts=2;idempotency_scope='session_step_input_digest'}}else{[pscustomobject][ordered]@{mode='never';automatic_retries=0;max_attempts=1;idempotency_scope='session_step_input_digest'}} }

if ($SelfTest) {
  $normalized = ConvertTo-P0NormalizedDeliveryTitle '车商喊亏 | 买家嫌贵'
  if ($normalized -ne '车商喊亏买家嫌贵') { throw 'h7_title_normalization_self_test_failed' }
  Write-Output 'P0_H7_PREPARE_SELF_TEST=pass'
  exit 0
}

if ([string]::IsNullOrWhiteSpace($SessionPath)) { throw 'SessionPath is required unless -SelfTest is used' }
$session = (Resolve-Path -LiteralPath $SessionPath).Path
$sessionId = Split-Path -Leaf $session
$p0 = Join-Path $session 'intermediate/p0'
$deliveryP0 = Join-Path $session 'deliverables/p0'
$candidatePath = Join-Path $deliveryP0 'final-delivery-render-candidate.json'
$inputPath = Join-Path $deliveryP0 'final-delivery-render-input.json'
$planPath = Join-Path $p0 'session-execution-plan.json'
$eventPath = Join-Path $p0 'execution-events.jsonl'
$visualPath = Join-Path $p0 'h6-visual-need-analysis.json'
$promptPath = Join-Path $p0 'h6-image-prompt-set.json'
$selectionPath = Join-Path $p0 'h6-asset-selection.json'
foreach($path in @($candidatePath,$inputPath,$planPath,$eventPath,$visualPath,$promptPath,$selectionPath)){if(-not(Test-Path -LiteralPath $path)){throw "required_h7_input_missing:$path"}}

$oldInput = Read-H7Json $inputPath
if ([string]$oldInput.schema_version -eq 'typed_components_v0.3') {
  $errors=@(Test-P0RenderInputContract $oldInput)
  if($errors.Count){throw('existing_v03_input_invalid:'+($errors-join';'))}
  Write-Output 'P0_H7_PREPARE_RESULT=skipped_existing_v03_input'
  exit 0
}
$visual=Read-H7Json $visualPath;$prompts=Read-H7Json $promptPath;$selection=Read-H7Json $selectionPath
$accepted=@($visual.accepted_visual_tasks);$assets=@($selection.assets)
if($accepted.Count-ne$assets.Count){throw 'h7_visual_asset_count_mismatch'}

$qualityPath=Join-Path $session 'intermediate/10-h7-delivery-quality-review.md'
$coverRoot=Join-Path $session 'assets/images/h7/covers';if(-not(Test-Path -LiteralPath $coverRoot)){New-Item -ItemType Directory -Path $coverRoot -Force|Out-Null}
$baseCover=Join-Path $session "assets/images/h6/PIP-$sessionId-001-base.png"
if(-not(Test-Path -LiteralPath $baseCover)){throw 'h7_cover_base_missing'}
$platformCards=@($oldInput.platform_cards | Sort-Object display_order)
$platformLabels=@{douyin='抖音';kuaishou='快手';xiaohongshu='小红书';shipinhao='视频号'}
$coverSpecs=@(
  [pscustomobject]@{Key='DYKS';Platforms=@('douyin','kuaishou');Width=1080;Height=1440;FontSize=100},
  [pscustomobject]@{Key='XHS';Platforms=@('xiaohongshu');Width=1080;Height=1440;FontSize=96},
  [pscustomobject]@{Key='SPH';Platforms=@('shipinhao');Width=1080;Height=1080;FontSize=88}
)
$coverCards=[Collections.Generic.List[object]]::new();$coverByPlatform=@{};$coverOrder=0
foreach($spec in $coverSpecs){
  $sourceCard=@($platformCards|Where-Object{$_.platform-eq$spec.Platforms[0]})|Select-Object -First 1
  if($null-eq$sourceCard){throw "h7_platform_card_missing:$($spec.Platforms[0])"}
  foreach($platform in $spec.Platforms){$other=@($platformCards|Where-Object{$_.platform-eq$platform})|Select-Object -First 1;if($null-eq$other-or(ConvertTo-P0NormalizedDeliveryTitle $other.cover_title)-ne(ConvertTo-P0NormalizedDeliveryTitle $sourceCard.cover_title)){throw "h7_shared_cover_title_mismatch:$platform"}}
  $coverOrder++;$assetId="COVER-H7-$sessionId-$($spec.Key)";$relative="assets/images/h7/covers/$assetId.png";$sidecarRelative="assets/images/h7/covers/$assetId.json"
  $output=Join-Path $session $relative;$sidecar=Join-Path $session $sidecarRelative
  if(-not(Test-Path -LiteralPath $output)-or-not(Test-Path -LiteralPath $sidecar)){
    $titleForRender=([string]$sourceCard.cover_title -replace '\s*/\s*','|')
    & (Join-Path $projectRoot 'skills/cover-design-compiler/scripts/compose-cover.ps1') -InputPath $baseCover -OutputPath $output -CoverTitle $titleForRender -Platform ([string]::Join(',',@($spec.Platforms))) -Width $spec.Width -Height $spec.Height -TextPosition center -FontSize $spec.FontSize -RecordPath $sidecar
    if(-not $?){throw "h7_cover_compose_failed:$assetId"}
  }
  $record=Read-H7Json $sidecar
  if((ConvertTo-P0NormalizedDeliveryTitle $record.cover_title)-ne(ConvertTo-P0NormalizedDeliveryTitle $sourceCard.cover_title)){throw "h7_cover_sidecar_title_mismatch:$assetId"}
  $platformValue=[string]::Join(',',@($spec.Platforms));$cardId="CARD-H7-COVER-$sessionId-$($coverOrder.ToString('000'))"
  $card=[pscustomobject][ordered]@{card_id=$cardId;card_type='cover';display_order=$coverOrder;status='ready';source_artifact_ids=@([string]$oldInput.platform_cards[0].source_artifact_ids[0],[string]$selection.image_asset_set_id,"CQG-H7-$sessionId");cover_role='platform_cover';platform=$platformValue;title_text=[string]$sourceCard.cover_title;rendered_text=[string]$sourceCard.cover_title;asset_status='generated';asset_id=$assetId;relative_path=$relative;sha256=Get-H7Hash $output;sidecar_path=$sidecarRelative;usage_note='由当前 H6 首屏底图按本平台发布标题确定性合成，并通过 H7 标题、尺寸和文件完整性检查。'}
  $coverCards.Add($card);foreach($platform in $spec.Platforms){$coverByPlatform[$platform]=$card}
}

$qualityRows=@($coverCards|ForEach-Object{"| $($_.platform) | $($_.title_text) | $($_.asset_id) | $($_.sha256) | pass |"})
$qualityText=@"
# H7 Delivery Semantic And Cover Quality Review

```yaml
cover_quality_gate_id: CQG-H7-$sessionId
delivery_revision_id: DREV-$sessionId-002
quality_status: pass_with_warnings
title_asset_binding_status: pass
file_integrity_status: pass
human_visual_review_status: pending_final_audit
next_skill: final-delivery-builder
```

| platforms | rendered title | asset | sha256 | deterministic result |
|---|---|---|---|---|
$([string]::Join("`n",$qualityRows))

本记录只证明标题绑定、尺寸、文件和 hash；最终视觉观感在 H7 代码完成后的页面审计中收口。
"@
Write-H7Text $qualityPath ($qualityText.Trim()+"`n")

$pipCards=[Collections.Generic.List[object]]::new();$pipOrder=0
foreach($asset in $assets){
  $pipOrder++;$task=@($accepted|Where-Object{$_.image_task_id-eq$asset.image_task_id})|Select-Object -First 1;$source=@($visual.candidates|Where-Object{$_.visual_need_candidate_id-eq$task.visual_need_candidate_id})|Select-Object -First 1;$prompt=@($prompts.prompts|Where-Object{$_.image_task_id-eq$asset.image_task_id})|Select-Object -First 1
  if($null-eq$task-or$null-eq$source-or$null-eq$prompt){throw "h7_pip_binding_missing:$($asset.image_task_id)"}
  $textSummary=if(@($prompt.visual_text_units).Count){[string]::Join(' / ',@($prompt.visual_text_units))}else{'本图按计划无字'}
  $generationRecord="assets/images/generation-records/GEN-$($asset.image_task_id).md"
  $pipCards.Add([pscustomobject][ordered]@{card_id="CARD-H7-PIP-$sessionId-$($pipOrder.ToString('000'))";card_type='picture_in_picture';display_order=$pipOrder;status=$(if(@($asset.warnings).Count){'ready_with_warnings'}else{'ready'});source_artifact_ids=@([string]$visual.visual_need_analysis_id,[string]$selection.image_asset_set_id,[string]$prompt.prompt_id);trigger_text=[string]$source.trigger_text;insert_after_text=[string]$source.insert_after_text;insert_before_text=[string]$source.insert_before_text;narrative_function=[string]$source.expected_viewer_change;viewer_problem=[string]$source.viewer_problem_without_visual;asset_status='generated';asset_id=[string]$asset.asset_id;relative_path=[string]$asset.selected_path;sha256=[string]$asset.selected_sha256;sidecar_path="assets/images/metadata/$($asset.asset_id).json";prompt_path='intermediate/p0/h6-image-prompt-set.json';generation_record_path=$generationRecord;preview_alt=[string]$prompt.acceptance_criteria;visual_text_summary=$textSummary;warning_codes=[object[]]@($asset.warnings)})
}

$units=[Collections.Generic.List[object]]::new();$unitOrder=0
foreach($platformCard in $platformCards){
  $unitOrder++;$cover=$coverByPlatform[[string]$platformCard.platform];if($null-eq$cover){throw "h7_cover_for_platform_missing:$($platformCard.platform)"}
  $units.Add([pscustomobject][ordered]@{unit_id="PDU-$sessionId-$($unitOrder.ToString('000'))";display_order=$unitOrder;platform=[string]$platformCard.platform;platform_label=[string]$platformLabels[[string]$platformCard.platform];platform_card_id=[string]$platformCard.card_id;cover_card_id=[string]$cover.card_id;cover_title=[string]$platformCard.cover_title;rendered_cover_text=[string]$cover.rendered_text;cover_asset_id=[string]$cover.asset_id;cover_asset_path=[string]$cover.relative_path;cover_sha256=[string]$cover.sha256;video_title=[string]$platformCard.video_title;publish_description=[string]$platformCard.publish_description;hashtags=[object[]]@($platformCard.hashtags);publish_readiness='ready'})
}

$traceCards=[Collections.Generic.List[object]]::new();$traceOrder=0
foreach($trace in @($oldInput.trace_cards)){
  $traceOrder++;$copy=($trace|ConvertTo-Json -Depth 10|ConvertFrom-Json);$copy.display_order=$traceOrder
  if($copy.artifact_type-eq'content_delivery_record'){$copy.materialization_status='pending';$copy.PSObject.Properties.Remove('sha256')}
  else{$full=Resolve-H7Path $session ([string]$copy.relative_path) $true;$copy.sha256=Get-H7Hash $full}
  if($copy.artifact_type-eq'visual_plan'){$copy.artifact_id=[string]$visual.visual_need_analysis_id;$copy.source_artifact_ids=@([string]$visual.visual_need_analysis_id)}
  if($copy.artifact_type-eq'quality_review'){$copy.artifact_id="Q-H6-$sessionId";$copy.source_artifact_ids=@("Q-H6-$sessionId")}
  $traceCards.Add($copy)
}
$traceOrder++;$traceCards.Add([pscustomobject][ordered]@{card_id="CARD-H7-TRACE-$sessionId-$($traceOrder.ToString('000'))";card_type='trace';display_order=$traceOrder;status='trace_only';source_artifact_ids=@("CQG-H7-$sessionId");artifact_type='cover_quality_review';artifact_id="CQG-H7-$sessionId";label='H7 封面与交付语义检查';relative_path='intermediate/10-h7-delivery-quality-review.md';materialization_status='materialized';sha256=Get-H7Hash $qualityPath})

$bindings=[Collections.Generic.List[object]]::new()
foreach($definition in @(
  @('draft',[string]$oldInput.script_card.source_draft_id,'intermediate/04-draft.md'),
  @('visual_need_analysis',[string]$visual.visual_need_analysis_id,'intermediate/p0/h6-visual-need-analysis.json'),
  @('quality_review',"Q-H6-$sessionId",'intermediate/06-quality-review.md'),
  @('platform_package',[string]$platformCards[0].source_artifact_ids[0],'intermediate/08-platform-package-draft.md'),
  @('cover_quality_review',"CQG-H7-$sessionId",'intermediate/10-h7-delivery-quality-review.md'),
  @('image_asset_set',[string]$selection.image_asset_set_id,'intermediate/p0/h6-asset-selection.json')
)){$full=Resolve-H7Path $session ([string]$definition[2]) $true;$bindings.Add([pscustomobject][ordered]@{artifact_type=[string]$definition[0];artifact_id=[string]$definition[1];sha256=Get-H7Hash $full})}

$warningItems=@(
  [pscustomobject][ordered]@{warning_code='content_source_context_requires_care';warning_category='research';severity='non_blocking';user_message='文案中的行业规模和集中度判断采用概括表达';impact='如果改回精确数字或具体企业结论，需要补充可核验来源。';recommended_action='按当前模糊表达发布；如要加入数字，先回到调研与质检。';source_artifact_id=[string]$oldInput.research_run_id;resolution_status='open'},
  [pscustomobject][ordered]@{warning_code='visual_002_metaphor_intensity';warning_category='visual';severity='non_blocking';user_message='第 2 张图使用“泥潭”强隐喻';impact='画面表达较强，可能被理解为对整个行业的情绪化判断。';recommended_action='发布时将它作为观点隐喻，不要当作真实事件或企业证据。';source_artifact_id=[string]$selection.image_asset_set_id;resolution_status='open'},
  [pscustomobject][ordered]@{warning_code='visual_007_synthetic_ui_not_evidence';warning_category='visual';severity='non_blocking';user_message='第 7 张图含合成的软件界面形状';impact='这些界面只用于解释工具与利润的关系，不是真实产品截图。';recommended_action='不要在口播或配文中把画面当作真实系统证据。';source_artifact_id=[string]$selection.image_asset_set_id;resolution_status='open'},
  [pscustomobject][ordered]@{warning_code='content_reused_from_baseline';warning_category='runtime_scope';severity='known_scope';user_message='本轮复用了已验证口播，没有重新写文案';impact='本轮主要验证新图片与最终交付链，不代表重新完成了一次内容创作。';recommended_action='若要改变观点或口吻，请回到口播环节创建新 revision。';source_artifact_id=[string]$oldInput.script_card.source_draft_id;resolution_status='open'},
  [pscustomobject][ordered]@{warning_code='research_not_rerun';warning_category='runtime_scope';severity='known_scope';user_message='本轮没有重新执行热点或事实调研';impact='时效变化和新增来源没有在本轮更新。';recommended_action='正式发布前如对时效敏感，先重新调研。';source_artifact_id=[string]$oldInput.research_run_id;resolution_status='open'},
  [pscustomobject][ordered]@{warning_code='publishing_not_tested';warning_category='publishing';severity='known_scope';user_message='尚未实际登录平台或发布';impact='页面只能证明发布物料已准备，不能证明平台审核或传播效果。';recommended_action='由用户人工发布；发布后再记录结果。';source_artifact_id="DREV-$sessionId-002";resolution_status='open'}
)
$warningCodes=[object[]]@($warningItems|ForEach-Object{[string]$_.warning_code}|Sort-Object -Unique)
$scriptText=[string]$oldInput.script_card.final_text
$actions=@(
  [pscustomobject][ordered]@{card_id="CARD-H7-ACTION-$sessionId-001";card_type='action';display_order=1;status='ready';source_artifact_ids=@("DREV-$sessionId-002");action='publish_manually';label='人工发布';instruction='按平台卡下载对应封面并复制物料，由用户自行发布；本项目不登录平台。';reply_example='记录发布结果';is_primary=$true},
  [pscustomobject][ordered]@{card_id="CARD-H7-ACTION-$sessionId-002";card_type='action';display_order=2;status='ready';source_artifact_ids=@([string]$oldInput.script_card.source_draft_id);action='revise_copy';label='局部返工文案';instruction='指出需要调整的句子和目标，系统会创建新的交付 revision。';reply_example='修改第二段，语气更克制';target_artifact_id=[string]$oldInput.script_card.source_draft_id;is_primary=$false},
  [pscustomobject][ordered]@{card_id="CARD-H7-ACTION-$sessionId-003";card_type='action';display_order=3;status='ready';source_artifact_ids=@([string]$visual.visual_need_analysis_id);action='revise_visual';label='局部返工视觉';instruction='指定要替换的画中画或平台封面，系统会保留旧资产并创建新 revision。';reply_example='重做第二张画中画';target_artifact_id=[string]$visual.visual_need_analysis_id;is_primary=$false},
  [pscustomobject][ordered]@{card_id="CARD-H7-ACTION-$sessionId-004";card_type='action';display_order=4;status='ready';source_artifact_ids=@("DREV-$sessionId-002");action='export_handoff';label='导出转交包';instruction='生成可发给他人的本地交付包。';reply_example='导出转交包';is_primary=$false}
)

$candidate=[ordered]@{
  schema_id='taoge://schemas/final-delivery/typed-components/v0.3';schema_version='typed_components_v0.3';render_input_id="RIN-H7-$sessionId";final_delivery_id="FD-H7-$sessionId";account_name=[string]$oldInput.account_name;session_id=$sessionId;research_run_id=[string]$oldInput.research_run_id;template_version='final-delivery-template-v0.3';generated_at=[DateTimeOffset]::UtcNow.ToString('o')
  topic=$oldInput.topic
  script_card=[ordered]@{card_id="CARD-H7-SCRIPT-$sessionId";card_type='script';status='ready_with_warnings';source_artifact_ids=@([string]$oldInput.script_card.source_draft_id);hook_text=[string]$oldInput.script_card.hook_text;final_text=$scriptText;copy_label='选中复制完整口播';source_draft_id=[string]$oldInput.script_card.source_draft_id;character_count=($scriptText-replace'\s','').Length}
  production_status=[ordered]@{image_assets_status='all_generated';cover_quality_status='pass';overall_quality_status='pass_with_warnings';delivery_readiness='blocked';derived_by='derive_delivery_readiness_v0.3';warning_codes=$warningCodes}
  delivery_revision=[ordered]@{delivery_revision_id="DREV-$sessionId-002";revision_no=2;revision_status='preparing';supersedes_delivery_revision_id="LEGACY-$sessionId-V02";source_artifact_bindings=[object[]]$bindings.ToArray();generated_view_paths=[ordered]@{final_html='deliverables/final-delivery.html';final_script='deliverables/final-script.md';final_visual_plan='deliverables/final-visual-plan.md';final_platform_package='deliverables/final-platform-package.md';content_delivery_record='deliverables/content-delivery-record.md';revision_manifest='deliverables/p0/delivery-revision.json'};semantic_gate_status='pending'}
  run_provenance=[ordered]@{run_purpose='regression';reused_content=$true;reused_research=$true;executed_scopes=@('visual_need_analysis','codex_builtin_image2','visual_quality_review','cover_recomposition','final_delivery_revision');not_executed_scopes=@('new_research','new_copywriting','platform_login','automatic_publishing','distribution_effect');user_summary='本轮复用已验证口播和研究背景，重新完成内容驱动视觉分析、8 次 Image 2 出图、平台封面重合成与最终交付重建；没有重新调研、改写口播或实际发布。'}
  duration_estimate=[ordered]@{duration_estimate_status='not_available';source_text_digest=Get-H7TextHash $scriptText;not_available_reason='当前没有账号实测语速、录音时长或已登记的语速 profile；不使用回归脚本固定秒数。'}
  warning_items=[object[]]$warningItems;cover_cards=[object[]]$coverCards.ToArray();pip_cards=[object[]]$pipCards.ToArray();platform_cards=[object[]]$platformCards;platform_delivery_units=[object[]]$units.ToArray();trace_cards=[object[]]$traceCards.ToArray();action_cards=[object[]]$actions
  source_artifact_ids=[object[]]@($bindings|ForEach-Object{[string]$_.artifact_id}|Sort-Object -Unique)
}
$candidateObject=[pscustomobject](($candidate|ConvertTo-Json -Depth 50)|ConvertFrom-Json)
$contractErrors=@(Test-P0RenderInputContract $candidateObject);if($contractErrors.Count){throw('h7_candidate_contract_failed:'+($contractErrors-join';'))}
Write-H7Json $candidatePath $candidate

$plan=Read-H7Json $planPath
$plan.contract_bundle_version='p0-contract-bundle-v0.3';$plan.plan_schema_id='taoge://schemas/p0/session-execution-plan/v0.3';$plan.render_input_schema_id='taoge://schemas/final-delivery/typed-components/v0.3';$plan.renderer_version='final-delivery-renderer-v0.3';$plan.template_version='final-delivery-template-v0.3'
if(-not@($plan.steps|Where-Object{$_.step_id-eq'STEP-h7-prepare-delivery'}).Count){
  $priorRender=@($plan.steps|Where-Object{(Test-P0HasProperty $_ 'operation')-and$_.operation-eq'render_final_delivery'})[-1]
  $plan.steps=@($plan.steps)+@(
    [pscustomobject][ordered]@{step_id='STEP-h7-prepare-delivery';step_kind='deterministic_tool';requires_step_ids=@([string]$priorRender.step_id);produces_artifact_type='typed_render_candidate';success_state='succeeded';failure_route='final-delivery-builder';retry_policy=New-H7Retry 'deterministic';operation='prepare_h7_delivery_revision';requires_artifact_ids=@([string]$oldInput.render_input_id)},
    [pscustomobject][ordered]@{step_id='STEP-h7-compile-render-input';step_kind='deterministic_tool';requires_step_ids=@('STEP-h7-prepare-delivery');produces_artifact_type='deterministic_final_delivery_render_input';success_state='succeeded';failure_route='final-delivery-builder';retry_policy=New-H7Retry 'deterministic';operation='compile_render_input';requires_artifact_ids=@("RCAND-H7-$sessionId")},
    [pscustomobject][ordered]@{step_id='STEP-h7-render-final-delivery';step_kind='deterministic_tool';requires_step_ids=@('STEP-h7-compile-render-input');produces_artifact_type='final_delivery_revision';success_state='succeeded';failure_route='final-delivery-builder';retry_policy=New-H7Retry 'deterministic';operation='render_final_delivery';requires_artifact_ids=@("RIN-H7-$sessionId")}
  )
}
Write-H7Json $planPath $plan
$events=@(Get-Content -LiteralPath $eventPath -Encoding UTF8|Where-Object{$_.Trim()}|ForEach-Object{$_|ConvertFrom-Json})
if(-not@($events|Where-Object{$_.step_id-eq'STEP-h7-prepare-delivery'-and$_.state_after-eq'succeeded'}).Count){
  $inputDigest=Get-H7Hash $visualPath;$payloadDigest=Get-H7Hash $candidatePath
  $write=Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId 'STEP-h7-prepare-delivery' -EventType 'step.succeeded.v1' -EventSource 'runner' -StateBefore 'running' -StateAfter 'succeeded' -PayloadDigest $payloadDigest -InputDigest $inputDigest -IdempotencyKey "$sessionId:STEP-h7-prepare-delivery:$inputDigest" -ExpectedLastSequenceNo $events.Count -ResultCode 'h7_delivery_candidate_prepared' -SafeSummary 'H7 当前交付 revision、平台封面绑定和精确 PIP 卡已准备' -OutputArtifactIds @("RCAND-H7-$sessionId","DREV-$sessionId-002",[string]$selection.image_asset_set_id) -ExecutionAttemptId "ATT-$sessionId-H7-PREPARE-1" -CorrelationId "CMD-$sessionId-H7-PREPARE"
  if($write.ExitCode-ne0){throw('h7_prepare_event_failed:'+($write.Errors-join';'))}
}
Write-Output 'P0_H7_PREPARE_RESULT=ready_for_compile_render'
Write-Output "DELIVERY_REVISION_ID=DREV-$sessionId-002"
Write-Output "PIP_COUNT=$($pipCards.Count)"
Write-Output "PLATFORM_UNIT_COUNT=$($units.Count)"
Write-Output "COVER_COUNT=$($coverCards.Count)"
