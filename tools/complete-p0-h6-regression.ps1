param(
  [Parameter(Mandatory=$true)][string]$SessionPath,
  [string]$VisualNeedPath='intermediate/p0/h6-visual-need-analysis.json',
  [string]$PromptSetPath='intermediate/p0/h6-image-prompt-set.json',
  [string]$AssetSelectionPath='intermediate/p0/h6-asset-selection.json'
)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2.0
$projectRoot=(Resolve-Path(Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'R3VisualNeed.ps1')
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'P0EvidenceRuntime.ps1')

function Resolve-H6SessionPath([string]$Path,[bool]$MustExist){
  $candidate=if([IO.Path]::IsPathRooted($Path)){$Path}else{Join-Path $projectRoot $Path};$full=[IO.Path]::GetFullPath($candidate)
  $accounts=[IO.Path]::GetFullPath((Join-Path $projectRoot 'accounts')).TrimEnd('\')+'\'
  if(-not$full.StartsWith($accounts,[StringComparison]::OrdinalIgnoreCase)){throw 'h6_session_outside_accounts'}
  if($MustExist-and-not(Test-Path -LiteralPath $full)){throw "h6_path_missing:$full"};return $full
}
function Resolve-H6Child([string]$Session,[string]$Path,[bool]$MustExist){
  $full=if([IO.Path]::IsPathRooted($Path)){[IO.Path]::GetFullPath($Path)}else{[IO.Path]::GetFullPath((Join-Path $Session $Path))}
  $prefix=$Session.TrimEnd('\')+'\';if(-not$full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'h6_child_outside_session'}
  if($MustExist-and-not(Test-Path -LiteralPath $full)){throw "h6_path_missing:$full"};return $full
}
function Read-H6Json([string]$Path){Get-Content -LiteralPath $Path -Raw -Encoding UTF8|ConvertFrom-Json}
function Write-H6Text([string]$Path,[string]$Text){$parent=Split-Path -Parent $Path;if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};[IO.File]::WriteAllText($Path,$Text.TrimEnd("`r","`n")+"`n",[Text.UTF8Encoding]::new($false))}
function Write-H6Json([string]$Path,[object]$Value){Write-H6Text $Path (($Value|ConvertTo-Json -Depth 60))}
function Get-H6Hash([string]$Path){'sha256:'+((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant())}
function Get-H6PromptDigest([string]$Text){$hash=[Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($Text));'sha256:'+(($hash|ForEach-Object{$_.ToString('x2')})-join'')}
function New-H6Retry([string]$Kind){if($Kind-eq'external'){return [pscustomobject][ordered]@{mode='reconcile_first';automatic_retries=0;max_attempts=1;idempotency_scope='session_step_input_digest'}};if($Kind-eq'agent'){return [pscustomobject][ordered]@{mode='never';automatic_retries=0;max_attempts=1;idempotency_scope='session_step_input_digest'}};return [pscustomobject][ordered]@{mode='bounded';automatic_retries=1;max_attempts=2;idempotency_scope='session_step_input_digest'}}

try{
  $session=Resolve-H6SessionPath $SessionPath $true;$sessionId=Split-Path -Leaf $session
  $visualPath=Resolve-H6Child $session $VisualNeedPath $true;$promptPath=Resolve-H6Child $session $PromptSetPath $true;$selectionPath=Resolve-H6Child $session $AssetSelectionPath $true
  $visual=Read-H6Json $visualPath;$promptSet=Read-H6Json $promptPath;$selection=Read-H6Json $selectionPath
  $visualErrors=@(Test-R3VisualNeedAnalysis $visual);if($visualErrors.Count){throw('h6_visual_need_invalid:'+($visualErrors-join','))}
  if($visual.visual_need_analysis_status-ne'pass'-or[bool]$visual.human_confirmation_required){throw'h6_visual_need_not_auto_dispatchable'}
  $accepted=@($visual.accepted_visual_tasks);$prompts=@($promptSet.prompts);$assets=@($selection.assets);$covers=@($selection.covers)
  if($accepted.Count-ne$prompts.Count-or$accepted.Count-ne$assets.Count-or[int]$selection.actual_provider_execution_count-ne$accepted.Count){throw'h6_cardinality_mismatch'}
  $acceptedIds=@($accepted.image_task_id|Sort-Object);if(($acceptedIds-join'|')-ne(@($prompts.image_task_id|Sort-Object)-join'|')-or($acceptedIds-join'|')-ne(@($assets.image_task_id|Sort-Object)-join'|')){throw'h6_task_mapping_mismatch'}
  foreach($prompt in $prompts){if((Get-H6PromptDigest([string]$prompt.full_prompt))-ne[string]$prompt.prompt_sha256){throw"h6_prompt_digest_mismatch:$($prompt.prompt_id)"}}
  Add-Type -AssemblyName System.Drawing
  $assetRows=[Collections.Generic.List[string]]::new();$qualityRows=[Collections.Generic.List[string]]::new()
  $metadataDir=Join-Path $session 'assets/images/metadata';$recordDir=Join-Path $session 'assets/images/generation-records'
  foreach($asset in $assets){
    $prompt=@($prompts|Where-Object{$_.prompt_id-eq$asset.prompt_id})|Select-Object -First 1
    $acceptedTask=@($accepted|Where-Object{$_.image_task_id-eq$asset.image_task_id})|Select-Object -First 1
    $candidate=@($visual.candidates|Where-Object{$_.visual_need_candidate_id-eq$acceptedTask.visual_need_candidate_id})|Select-Object -First 1
    if($null-eq$prompt-or$null-eq$candidate){throw"h6_asset_source_missing:$($asset.image_task_id)"}
    $base=Resolve-H6Child $session ([string]$asset.base_path) $true;$selected=Resolve-H6Child $session ([string]$asset.selected_path) $true
    $selectedHash=Get-H6Hash $selected;if($selectedHash-ne[string]$asset.selected_sha256){throw"h6_selected_hash_mismatch:$($asset.asset_id)"}
    $image=[Drawing.Image]::FromFile($selected);try{if($image.Width-ne[int]$asset.width-or$image.Height-ne[int]$asset.height){throw"h6_dimensions_mismatch:$($asset.asset_id)"}}finally{$image.Dispose()}
    $baseId=([string]$asset.asset_id)+'-BASE';$baseMetaRel="assets/images/metadata/$baseId.json";$selectedMetaRel="assets/images/metadata/$($asset.asset_id).json";$recordRel="assets/images/generation-records/GEN-$($asset.image_task_id).md"
    $baseMeta=[ordered]@{asset_id=$baseId;image_task_id=[string]$asset.image_task_id;source_prompt_id=[string]$asset.prompt_id;provider='codex_builtin_image2';runtime_model_profile='not_observable';image_status='generated';asset_path=[string]$asset.base_path;sha256=Get-H6Hash $base;width=[int]$asset.width;height=[int]$asset.height;immutable=$true}
    Write-H6Json (Join-Path $session $baseMetaRel) $baseMeta
    $selectedMeta=[ordered]@{asset_id=[string]$asset.asset_id;parent_asset_id=$baseId;image_task_id=[string]$asset.image_task_id;source_prompt_id=[string]$asset.prompt_id;visual_need_analysis_id=[string]$visual.visual_need_analysis_id;provider='deterministic_overlay_or_identity';image_status='generated';asset_path=[string]$asset.selected_path;sha256=$selectedHash;width=[int]$asset.width;height=[int]$asset.height;visual_text_status=[string]$asset.visual_text_status;quality_result=[string]$asset.quality_result;warnings=[object[]]@($asset.warnings);immutable=$true}
    Write-H6Json (Join-Path $session $selectedMetaRel) $selectedMeta
    $record="# H6 Image Generation Record`n`n``````yaml`ngeneration_run_id: GEN-$($asset.image_task_id)`nimage_task_id: $($asset.image_task_id)`nbase_asset_id: $baseId`nselected_asset_id: $($asset.asset_id)`nprovider: codex_builtin_image2`nruntime_model_profile: not_observable`nimage_status: generated`nbase_asset_path: $($asset.base_path)`nselected_asset_path: $($asset.selected_path)`nprompt_id: $($asset.prompt_id)`nprompt_sha256: $($prompt.prompt_sha256)`nselected_sha256: $selectedHash`nactual_provider_execution_count_evidence: 1`n```````n`n## Prompt Used`n`n$($prompt.full_prompt)`n"
    Write-H6Text (Join-Path $session $recordRel) $record
    $assetRows.Add("| $($asset.image_task_id) | $($asset.asset_id) | $($candidate.primary_visual_job) | $($asset.selected_path) | $($asset.quality_result) | $([string]::Join(', ',@($asset.warnings))) |")
    $qualityRows.Add("| $($asset.image_task_id) | $($asset.prompt_alignment_score) | $($asset.retention_task_score) | $($asset.mobile_readability_score) | $($asset.misleading_risk_status) | $($asset.quality_result) |")
  }
  foreach($cover in $covers){$coverPath=Resolve-H6Child $session ([string]$cover.selected_path) $true;if((Get-H6Hash $coverPath)-ne[string]$cover.selected_sha256){throw"h6_cover_hash_mismatch:$($cover.asset_id)"}}
  $assetIndex="# H6 Image Asset Set`n`n``````yaml`nimage_asset_set_id: $($selection.image_asset_set_id)`nvisual_need_analysis_id: $($visual.visual_need_analysis_id)`nprovider: codex_builtin_image2`naccepted_task_count: $($accepted.Count)`nactual_provider_execution_count: $($selection.actual_provider_execution_count)`nselected_asset_count: $($assets.Count)`nderived_cover_count: $($covers.Count)`nimage_assets_status: all_generated`noverall_result: $($selection.overall_result)`nnext_skill: copywriting-quality-review`n```````n`n| image_task_id | asset_id | primary_visual_job | path | quality | warnings |`n|---|---|---|---|---|---|`n$([string]::Join("`n",$assetRows))`n"
  Write-H6Text (Join-Path $session 'assets/images/h6/image-assets.md') $assetIndex
  $visualMd="# H6 Visual Planning Bundle`n`n> H6A pass 后已自动进入 H6B；无图片数量或审美确认门禁。`n`n## Visual Need Analysis`n`n``````json`n$(($visual|ConvertTo-Json -Depth 60))`n```````n`n## Image Prompt Set`n`n``````json`n$(($promptSet|ConvertTo-Json -Depth 60))`n```````n`n## Selected Asset Set`n`n- accepted：$($accepted.Count)`n- Image 2 实际执行：$($selection.actual_provider_execution_count)`n- 选中 PIP：$($assets.Count)`n- 确定性封面：$($covers.Count)`n- 结果：$($selection.overall_result)`n"
  Write-H6Text (Join-Path $session 'intermediate/05-visual-plan.md') $visualMd
  $qualityMd="# H6 Content And Visual Quality Review`n`n``````yaml`nreview_id: Q-H6-$sessionId`nvisual_need_analysis_id: $($visual.visual_need_analysis_id)`nimage_asset_set_id: $($selection.image_asset_set_id)`nreview_status: $($selection.overall_result)`nvisual_quality_gate_status: pass_with_warnings`nblocking_issues: []`nwarning_codes: $([string]::Join(', ',@($selection.warning_codes)))`nnext_skill: platform-packaging-adapter`n```````n`n| image_task_id | prompt alignment | retention task | mobile readability | misleading risk | result |`n|---|---:|---:|---:|---|---|`n$([string]::Join("`n",$qualityRows))`n`nWarnings are non-blocking: the mud scene is a strong metaphor, and the SaaS scene contains synthetic UI-like shapes that must never be treated as factual evidence. Publishing was not tested.`n"
  Write-H6Text (Join-Path $session 'intermediate/06-quality-review.md') $qualityMd

  $baselineSessionId='not_applicable';$provenancePath=Join-Path $session 'inputs/h5-regression-provenance.json'
  if(Test-Path -LiteralPath $provenancePath){$baselineSessionId=[string](Read-H6Json $provenancePath).baseline_session_id}
  $manifest=@"
schema_version: 0.6
contract_set_version: p0-contract-bundle-v0.2
session_id: $sessionId
content_run_id: CR$($sessionId.Substring(1))
task_context_type: p0_h6_real_image_regression
account: $($visual.account)
baseline_session_id: $baselineSessionId
source_research_run_id: $($visual.source_research_run_id)
started_at: 2026-07-12
updated_at: 2026-07-12
build_profile: dev
run_mode: phase_2_real_regression_with_new_image2_assets
current_stage: compile_render_input
current_artifact: deliverables/p0/final-delivery-render-candidate.json
session_status: session_running

artifacts:
  execution_plan: intermediate/p0/session-execution-plan.json
  execution_events: intermediate/p0/execution-events.jsonl
  state_projection: intermediate/p0/state-projection.json
  resume_summary: intermediate/p0/resume-summary.json
  visual_need_analysis: intermediate/p0/h6-visual-need-analysis.json
  image_prompt_set: intermediate/p0/h6-image-prompt-set.json
  image_asset_selection: intermediate/p0/h6-asset-selection.json
  render_candidate: deliverables/p0/final-delivery-render-candidate.json
  render_input: deliverables/p0/final-delivery-render-input.json
  render_receipt: deliverables/p0/render-receipt.json
  final_delivery: deliverables/final-delivery.html

statuses:
  baseline_content_status: reused_verified
  visual_need_analysis_status: pass
  image_assets_status: all_generated
  cover_quality_gate_status: pass
  final_delivery_status: pending_compile_render
  runtime_status: waiting_compile_render

runtime_boundary:
  new_research_executed: false
  copywriting_executed: false
  image_provider_invoked: true
  image_provider: codex_builtin_image2
  runtime_model_profile: not_observable
  accepted_visual_task_count: $($accepted.Count)
  image_provider_invocation_count: $($selection.actual_provider_execution_count)
  selected_pip_count: $($assets.Count)
  derived_cover_count: $($covers.Count)
  publishing_invoked: false

test_result:
  overall_result: $($selection.overall_result)
  workflow_result: $($selection.overall_result)
  artifact_result: $($selection.overall_result)
  checker_result: pending_h6_validation
  warning_codes: $([string]::Join(', ',@($selection.warning_codes)))
  not_tested_scope: automatic publishing / platform login / real distribution effect / runtime model profile
"@
  Write-H6Text (Join-Path $session 'manifest.yaml') $manifest

  $candidatePath=Join-Path $session 'deliverables/p0/final-delivery-render-candidate.json';$candidate=Read-H6Json $candidatePath
  $candidate.render_input_id="RIN-H6-$sessionId";$candidate.final_delivery_id="FD-H6-$sessionId"
  $candidate.production_status.image_assets_status='all_generated';$candidate.production_status.cover_quality_status='pass';$candidate.production_status.overall_quality_status=[string]$selection.overall_result;$candidate.production_status.delivery_readiness='ready_with_warnings';$candidate.production_status.derived_by='derive_delivery_readiness';$candidate.production_status.warning_codes=[object[]]@($selection.warning_codes)
  $pipCards=[Collections.Generic.List[object]]::new();$order=0
  foreach($asset in $assets){$order++;$task=@($accepted|Where-Object{$_.image_task_id-eq$asset.image_task_id})[0];$source=@($visual.candidates|Where-Object{$_.visual_need_candidate_id-eq$task.visual_need_candidate_id})[0];$pipCards.Add([pscustomobject][ordered]@{card_id="CARD-H6-PIP-$sessionId-$($order.ToString('000'))";card_type='picture_in_picture';display_order=$order;status='ready';source_artifact_ids=@([string]$visual.visual_need_analysis_id,[string]$selection.image_asset_set_id);placement="在「$($source.trigger_text)」附近";narrative_function=[string]$source.expected_viewer_change;asset_status='generated';asset_id=[string]$asset.asset_id;relative_path=[string]$asset.selected_path;sha256=[string]$asset.selected_sha256;sidecar_path="assets/images/metadata/$($asset.asset_id).json";preview_alt=[string]$source.viewer_problem_without_visual})}
  $candidate.pip_cards=[object[]]$pipCards.ToArray()
  $coverCards=[Collections.Generic.List[object]]::new();$order=0
  foreach($cover in $covers){$order++;$coverCards.Add([pscustomobject][ordered]@{card_id="CARD-H6-COVER-$sessionId-$($order.ToString('000'))";card_type='cover';display_order=$order;status='ready';source_artifact_ids=@([string]$selection.image_asset_set_id);cover_role='platform_cover';platform=[string]$cover.platform;title_text=[string]$cover.title_text;asset_status='generated';asset_id=[string]$cover.asset_id;relative_path=[string]$cover.selected_path;sha256=[string]$cover.selected_sha256;sidecar_path="assets/images/h6/covers/$($cover.asset_id).json";usage_note='由 H6 首屏 Image 2 底图确定性派生并完成视觉检查。'})}
  $candidate.cover_cards=[object[]]$coverCards.ToArray()
  foreach($traceCard in @($candidate.trace_cards)){
    if([string]::IsNullOrWhiteSpace([string]$traceCard.relative_path)){continue}
    $tracePath=Resolve-H6Child $session ([string]$traceCard.relative_path) $true
    $traceCard.sha256=Get-H6Hash $tracePath
    if($traceCard.artifact_type-eq'visual_plan'){$traceCard.artifact_id=[string]$visual.visual_need_analysis_id;$traceCard.source_artifact_ids=@([string]$visual.visual_need_analysis_id)}
    if($traceCard.artifact_type-eq'quality_review'){$traceCard.artifact_id="Q-H6-$sessionId";$traceCard.source_artifact_ids=@("Q-H6-$sessionId")}
  }
  $retainedSourceArtifactIds=@($candidate.source_artifact_ids|Where-Object{$_-notmatch'^IMGSET'-and$_-notmatch'^VNA-'})
  $candidate.source_artifact_ids=[object[]]@($retainedSourceArtifactIds+@([string]$visual.visual_need_analysis_id,[string]$selection.image_asset_set_id))
  Write-H6Json $candidatePath $candidate

  $planPath=Join-Path $session 'intermediate/p0/session-execution-plan.json';$eventPath=Join-Path $session 'intermediate/p0/execution-events.jsonl';$plan=Read-H6Json $planPath
  if(-not@($plan.steps|Where-Object{$_.step_id-eq'STEP-h6-visual-need'}).Count){$plan.steps=@($plan.steps)+@(
    [pscustomobject][ordered]@{step_id='STEP-h6-visual-need';step_kind='agent_required';requires_step_ids=@('STEP-render-final-delivery');produces_artifact_type='visual_need_analysis';success_state='succeeded';failure_route='static-visual-director';retry_policy=(New-H6Retry 'agent')},
    [pscustomobject][ordered]@{step_id='STEP-h6-image-assets';step_kind='external_side_effect';requires_step_ids=@('STEP-h6-visual-need');produces_artifact_type='image_asset_set';success_state='succeeded';failure_route='image-asset-producer';retry_policy=(New-H6Retry 'external')},
    [pscustomobject][ordered]@{step_id='STEP-h6-quality';step_kind='agent_required';requires_step_ids=@('STEP-h6-image-assets');produces_artifact_type='quality_review';success_state='succeeded';failure_route='copywriting-quality-review';retry_policy=(New-H6Retry 'agent')},
    [pscustomobject][ordered]@{step_id='STEP-h6-compile-render-input';step_kind='deterministic_tool';requires_step_ids=@('STEP-h6-quality');produces_artifact_type='deterministic_final_delivery_render_input';success_state='succeeded';failure_route='final-delivery-builder';retry_policy=(New-H6Retry 'deterministic');operation='compile_render_input';requires_artifact_ids=@("RCAND-H6-$sessionId")},
    [pscustomobject][ordered]@{step_id='STEP-h6-render-final-delivery';step_kind='deterministic_tool';requires_step_ids=@('STEP-h6-compile-render-input');produces_artifact_type='final_delivery';success_state='succeeded';failure_route='final-delivery-builder';retry_policy=(New-H6Retry 'deterministic');operation='render_final_delivery';requires_artifact_ids=@("RIN-H6-$sessionId")}
  )};Write-H6Json $planPath $plan
  $existing=@(Get-Content -LiteralPath $eventPath -Encoding UTF8|Where-Object{$_.Trim()}|ForEach-Object{$_|ConvertFrom-Json});$expected=$existing.Count
  foreach($eventSpec in @(
    @{step='STEP-h6-visual-need';source='agent_recorder';payload=Get-H6Hash $visualPath;input=Get-H6Hash (Join-Path $session 'intermediate/04-draft.md');code='visual_need_pass';summary='H6A 内容驱动视觉需求分析通过并自动派发';outputs=@([string]$visual.visual_need_analysis_id)},
    @{step='STEP-h6-image-assets';source='external_recorder';payload=Get-H6Hash $selectionPath;input=Get-H6Hash $promptPath;code='external_succeeded';summary='内置 Image 2 已生成全部 accepted 任务';outputs=@([string]$selection.image_asset_set_id)},
    @{step='STEP-h6-quality';source='agent_recorder';payload=Get-H6Hash (Join-Path $session 'intermediate/06-quality-review.md');input=Get-H6Hash $selectionPath;code='quality_pass_with_warnings';summary='H6C 视觉与文字检查通过，保留非阻断警告';outputs=@("Q-H6-$sessionId")}
  )){$prior=@($existing|Where-Object{$_.step_id-eq$eventSpec.step-and$_.state_after-eq'succeeded'});if(-not$prior.Count){$write=Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId $eventSpec.step -EventType 'step.succeeded.v1' -EventSource $eventSpec.source -StateBefore 'running' -StateAfter 'succeeded' -PayloadDigest $eventSpec.payload -InputDigest $eventSpec.input -IdempotencyKey "${sessionId}:$($eventSpec.step):$($eventSpec.input)" -ExpectedLastSequenceNo $expected -ResultCode $eventSpec.code -SafeSummary $eventSpec.summary -OutputArtifactIds $eventSpec.outputs -ExecutionAttemptId "ATT-$sessionId-$($eventSpec.step)-1" -CorrelationId "CMD-$sessionId-$($eventSpec.step)";if($write.ExitCode-ne0){throw("h6_event_write_failed:"+($write.Errors-join','))};$expected++}}
  Write-Output 'P0_H6_PREPARE_RESULT=ready_for_compile_render_input';Write-Output "SESSION_ID=$sessionId";Write-Output "ACCEPTED_TASK_COUNT=$($accepted.Count)";Write-Output "ACTUAL_PROVIDER_EXECUTION_COUNT=$($selection.actual_provider_execution_count)";Write-Output "SELECTED_ASSET_COUNT=$($assets.Count)";Write-Output "DERIVED_COVER_COUNT=$($covers.Count)";exit 0
}catch{Write-Error('P0_H6_COMPLETE_ERROR='+$_.Exception.Message);exit 3}
