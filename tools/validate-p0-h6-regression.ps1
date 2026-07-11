param([Parameter(Mandatory=$true)][string]$SessionPath)

$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'R3VisualNeed.ps1')
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'P0EvidenceRuntime.ps1')
. (Join-Path $PSScriptRoot 'P0RuntimeV02.ps1')

function Resolve-H6CheckPath([string]$Path){$candidate=if([IO.Path]::IsPathRooted($Path)){$Path}else{Join-Path $projectRoot $Path};[IO.Path]::GetFullPath($candidate)}
function Get-H6CheckHash([string]$Path){'sha256:'+((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant())}
function Get-H6CheckPromptDigest([string]$Text){$hash=[Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($Text));'sha256:'+(($hash|ForEach-Object{$_.ToString('x2')})-join'')}
function Add-H6Check([Collections.Generic.List[object]]$Items,[Collections.Generic.List[string]]$Errors,[string]$Id,[bool]$Pass,[string]$Evidence){$Items.Add([ordered]@{assertion_id=$Id;result=$(if($Pass){'pass'}else{'fail'});evidence=$Evidence});if(-not$Pass){$Errors.Add($Id)}}
function Write-H6CheckJson([string]$Path,[object]$Value){[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 60).TrimEnd("`r","`n")+"`n"),[Text.UTF8Encoding]::new($false))}

try{
  $session=Resolve-H6CheckPath $SessionPath;$accounts=[IO.Path]::GetFullPath((Join-Path $projectRoot 'accounts')).TrimEnd('\')+'\'
  if(-not$session.StartsWith($accounts,[StringComparison]::OrdinalIgnoreCase)-or-not(Test-Path -LiteralPath $session)){throw'h6_session_missing_or_outside_accounts'}
  $sessionId=Split-Path -Leaf $session;$assertions=[Collections.Generic.List[object]]::new();$errors=[Collections.Generic.List[string]]::new()
  $visual=Read-P0JsonFile (Join-Path $session 'intermediate/p0/h6-visual-need-analysis.json');$promptSet=Read-P0JsonFile (Join-Path $session 'intermediate/p0/h6-image-prompt-set.json');$selection=Read-P0JsonFile (Join-Path $session 'intermediate/p0/h6-asset-selection.json')
  $accepted=@($visual.accepted_visual_tasks);$rejected=@($visual.rejected_visual_candidate_ids);$prompts=@($promptSet.prompts);$assets=@($selection.assets);$covers=@($selection.covers)
  Add-H6Check $assertions $errors 'visual_need_contract_valid' (@(Test-R3VisualNeedAnalysis $visual).Count-eq0) 'R3VisualNeed.ps1'
  Add-H6Check $assertions $errors 'visual_need_auto_dispatch' ($visual.visual_need_analysis_status-eq'pass'-and-not[bool]$visual.human_confirmation_required-and$visual.accepted_task_dispatch_policy-eq'auto_continue_all_accepted_without_human_confirmation'-and$visual.generation_dispatch_status-eq'ready_for_prompt_compile') ([string]$visual.accepted_task_dispatch_policy)
  Add-H6Check $assertions $errors 'content_driven_cardinality' ($accepted.Count-eq8-and$rejected.Count-eq0-and$accepted.Count-eq$prompts.Count-and$accepted.Count-eq$assets.Count) "accepted=$($accepted.Count);rejected=$($rejected.Count)"
  $acceptedIds=@($accepted.image_task_id|Sort-Object);$mapped=($acceptedIds-join'|')-eq(@($prompts.image_task_id|Sort-Object)-join'|')-and($acceptedIds-join'|')-eq(@($assets.image_task_id|Sort-Object)-join'|')
  Add-H6Check $assertions $errors 'task_mapping_bijective' $mapped ([string]::Join(',',@($acceptedIds)))
  $digestFailures=@($prompts|Where-Object{(Get-H6CheckPromptDigest ([string]$_.full_prompt))-ne[string]$_.prompt_sha256})
  Add-H6Check $assertions $errors 'full_prompt_digest_bound' ($digestFailures.Count-eq0) "prompts=$($prompts.Count)"
  Add-H6Check $assertions $errors 'provider_execution_matches_accepted' ([int]$selection.actual_provider_execution_count-eq$accepted.Count-and$selection.provider-eq'codex_builtin_image2') "provider_exec=$($selection.actual_provider_execution_count)"
  $manifestPath=Join-Path $session 'manifest.yaml';$manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
  Add-H6Check $assertions $errors 'manifest_h6_boundary' ($manifest-match'task_context_type: p0_h6_real_image_regression'-and$manifest-match'run_mode: phase_2_real_regression_with_new_image2_assets'-and$manifest-match'image_provider_invoked: true'-and$manifest-match'image_provider_invocation_count: 8'-and$manifest-match'publishing_invoked: false') $manifestPath

  Add-Type -AssemblyName System.Drawing
  $assetFailures=[Collections.Generic.List[string]]::new();$runtimeProfiles=[Collections.Generic.List[string]]::new();$generationRecords=0
  foreach($asset in $assets){
    $selected=Join-Path $session ([string]$asset.selected_path);$base=Join-Path $session ([string]$asset.base_path);$meta=Join-Path $session "assets/images/metadata/$($asset.asset_id).json";$baseMeta=Join-Path $session "assets/images/metadata/$($asset.asset_id)-BASE.json";$record=Join-Path $session "assets/images/generation-records/GEN-$($asset.image_task_id).md"
    if(-not(Test-Path -LiteralPath $selected)-or-not(Test-Path -LiteralPath $base)-or-not(Test-Path -LiteralPath $meta)-or-not(Test-Path -LiteralPath $baseMeta)-or-not(Test-Path -LiteralPath $record)){$assetFailures.Add("missing:$($asset.asset_id)");continue}
    $generationRecords++;$metadata=Read-P0JsonFile $meta;$baseMetadata=Read-P0JsonFile $baseMeta;$runtimeProfiles.Add([string]$baseMetadata.runtime_model_profile)
    if((Get-H6CheckHash $selected)-ne[string]$asset.selected_sha256-or(Get-H6CheckHash $selected)-ne[string]$metadata.sha256-or$metadata.image_status-ne'generated'){$assetFailures.Add("binding:$($asset.asset_id)")}
    $image=[Drawing.Image]::FromFile($selected);try{if($image.Width-ne[int]$asset.width-or$image.Height-ne[int]$asset.height){$assetFailures.Add("dimensions:$($asset.asset_id)")}}finally{$image.Dispose()}
  }
  Add-H6Check $assertions $errors 'image_assets_hash_metadata_closed' ($assetFailures.Count-eq0) ([string]::Join(',',@($assetFailures)))
  Add-H6Check $assertions $errors 'generation_records_complete' ($generationRecords-eq$accepted.Count) "records=$generationRecords"
  Add-H6Check $assertions $errors 'runtime_profile_not_claimed' ($runtimeProfiles.Count-eq$accepted.Count-and@($runtimeProfiles|Where-Object{$_-ne'not_observable'}).Count-eq0) ([string]::Join(',',@($runtimeProfiles|Select-Object -Unique)))
  $coverFailures=@($covers|Where-Object{-not(Test-Path -LiteralPath (Join-Path $session ([string]$_.selected_path)))-or(Get-H6CheckHash (Join-Path $session ([string]$_.selected_path)))-ne[string]$_.selected_sha256})
  Add-H6Check $assertions $errors 'derived_covers_complete' ($covers.Count-eq3-and$coverFailures.Count-eq0) "covers=$($covers.Count)"
  Add-H6Check $assertions $errors 'quality_is_pass_with_warnings' ($selection.overall_result-eq'pass_with_warnings'-and@($selection.warning_codes)-contains'publishing_not_tested') ([string]::Join(',',@($selection.warning_codes)))

  $plan=Read-P0JsonFile (Join-Path $session 'intermediate/p0/session-execution-plan.json');$events=@(Get-P0EvidenceEvents (Join-Path $session 'intermediate/p0/execution-events.jsonl'))
  Add-H6Check $assertions $errors 'plan_contract_valid' (@(Test-P0PlanContract $plan).Count-eq0) 'session-execution-plan.json'
  Add-H6Check $assertions $errors 'event_contract_valid' (@(Test-P0EventLogContract $events).Count-eq0) "events=$($events.Count)"
  $h6Steps=@($plan.steps|Where-Object{$_.step_id-like'STEP-h6-*'});$h6Events=@($events|Where-Object{$_.step_id-like'STEP-h6-*'-and$_.state_after-eq'succeeded'})
  Add-H6Check $assertions $errors 'h6_runtime_steps_complete' ($h6Steps.Count-eq5-and$h6Events.Count-eq5) "steps=$($h6Steps.Count);events=$($h6Events.Count)"
  Add-H6Check $assertions $errors 'image_step_non_repeatable' (@($h6Steps|Where-Object{$_.step_id-eq'STEP-h6-image-assets'-and$_.step_kind-eq'external_side_effect'-and$_.retry_policy.mode-eq'reconcile_first'}).Count-eq1) 'STEP-h6-image-assets'
  $projection=Read-P0JsonFile (Join-Path $session 'intermediate/p0/state-projection.json');$resume=Read-P0JsonFile (Join-Path $session 'intermediate/p0/resume-summary.json')
  Add-H6Check $assertions $errors 'projection_complete' ($projection.current_state-eq'completed'-and[int]$projection.projected_through_sequence_no-eq$events.Count) "sequence=$($projection.projected_through_sequence_no)"
  Add-H6Check $assertions $errors 'resume_complete' ($resume.current_state-eq'completed'-and$null-eq$resume.next_step_id-and$resume.recovery_action-eq'none') ([string]$resume.current_state)

  $renderInput=Read-P0JsonFile (Join-Path $session 'deliverables/p0/final-delivery-render-input.json');$candidate=Read-P0JsonFile (Join-Path $session 'deliverables/p0/final-delivery-render-candidate.json')
  Add-H6Check $assertions $errors 'candidate_contract_valid' (@(Test-P0RenderInputContract $candidate).Count-eq0) 'final-delivery-render-candidate.json'
  Add-H6Check $assertions $errors 'render_input_contract_valid' (@(Test-P0RenderInputContract $renderInput).Count-eq0) 'final-delivery-render-input.json'
  Add-H6Check $assertions $errors 'render_uses_h6_revision' ($renderInput.render_input_id-eq"RIN-H6-$sessionId"-and$renderInput.final_delivery_id-eq"FD-H6-$sessionId") ([string]$renderInput.render_input_id)
  Add-H6Check $assertions $errors 'render_cards_match_assets' (@($renderInput.pip_cards).Count-eq8-and@($renderInput.cover_cards).Count-eq3-and@($renderInput.pip_cards|Where-Object{$_.asset_status-ne'generated'}).Count-eq0-and@($renderInput.cover_cards|Where-Object{$_.asset_status-ne'generated'}).Count-eq0) "pip=$(@($renderInput.pip_cards).Count);cover=$(@($renderInput.cover_cards).Count)"
  $traceFailures=[Collections.Generic.List[string]]::new();foreach($trace in @($renderInput.trace_cards)){if($trace.materialization_status-eq'materialized'){$path=Join-Path $session ([string]$trace.relative_path);if(-not(Test-Path -LiteralPath $path)-or(Get-H6CheckHash $path)-ne[string]$trace.sha256){$traceFailures.Add([string]$trace.card_id)}}}
  Add-H6Check $assertions $errors 'trace_hashes_current' ($traceFailures.Count-eq0) ([string]::Join(',',@($traceFailures)))
  Add-H6Check $assertions $errors 'delivery_ready_with_warnings' ($renderInput.production_status.delivery_readiness-eq'ready_with_warnings'-and$renderInput.production_status.overall_quality_status-eq'pass_with_warnings') 'ready_with_warnings'

  $receipt=Read-P0JsonFile (Join-Path $session 'deliverables/p0/render-receipt.json');$htmlPath=Join-Path $session 'deliverables/final-delivery.html';$html=Get-Content -LiteralPath $htmlPath -Raw -Encoding UTF8
  Add-H6Check $assertions $errors 'render_receipt_valid' (@(Test-P0V2RenderReceipt $receipt).Count-eq0-and$receipt.output_html_sha256-eq(Get-H6CheckHash $htmlPath)) ([string]$receipt.output_html_sha256)
  Add-H6Check $assertions $errors 'receipt_contains_all_generated_assets' (@($receipt.included_asset_ids).Count-eq11-and@($assets|Where-Object{@($receipt.included_asset_ids)-notcontains$_.asset_id}).Count-eq0-and@($covers|Where-Object{@($receipt.included_asset_ids)-notcontains$_.asset_id}).Count-eq0) "assets=$(@($receipt.included_asset_ids).Count)"
  Add-H6Check $assertions $errors 'final_html_contains_all_h6_cards' (@($renderInput.pip_cards|Where-Object{$html-notmatch[regex]::Escape([string]$_.card_id)}).Count-eq0-and@($renderInput.cover_cards|Where-Object{$html-notmatch[regex]::Escape([string]$_.card_id)}).Count-eq0) $htmlPath
  Add-H6Check $assertions $errors 'final_html_safe' ($html-notmatch'(?is)<\s*script\b|\bon[a-z]+\s*=|javascript\s*:') 'no active content'
  $runtime=Invoke-P0RuntimeV02 -Session $session -Plan $plan -EventPath (Join-Path $session 'intermediate/p0/execution-events.jsonl') -Mode 'validate' -ProjectRoot $projectRoot
  Add-H6Check $assertions $errors 'runtime_validate_completed' ($runtime.ExitCode-eq0-and@($runtime.Lines)-contains'WORKFLOW_RUNTIME_RESULT=plan_valid_completed') ([string]::Join(';',@($runtime.Lines)))

  $result=if($errors.Count){'fail'}else{'pass_with_warnings'};$report=[ordered]@{schema_id='taoge://reports/p0/h6-real-image-regression/v0.1';schema_version='0.1';session_id=$sessionId;generated_at=[DateTimeOffset]::UtcNow.ToString('o');overall_result=$result;failure_category=$(if($errors.Count){'workflow_fixture_or_checker_defect'}else{$null});accepted_visual_task_count=$accepted.Count;actual_provider_execution_count=[int]$selection.actual_provider_execution_count;selected_pip_count=$assets.Count;derived_cover_count=$covers.Count;warning_codes=[object[]]@($selection.warning_codes);not_tested_scope=@('automatic_publishing','platform_login','real_distribution_effect','runtime_model_profile');assertions=[object[]]$assertions.ToArray();errors=[object[]]$errors.ToArray()}
  $reportPath=Join-Path $session 'intermediate/p0/h6-regression-check-report.json';Write-H6CheckJson $reportPath $report
  if(-not$errors.Count){
    $manifest=$manifest.Replace('current_stage: compile_render_input','current_stage: final_delivery').Replace('current_artifact: deliverables/p0/final-delivery-render-candidate.json','current_artifact: deliverables/final-delivery.html').Replace('session_status: session_running','session_status: session_completed_waiting_human').Replace('final_delivery_status: pending_compile_render','final_delivery_status: html_ready').Replace('runtime_status: waiting_compile_render','runtime_status: completed').Replace('checker_result: pending_h6_validation','checker_result: pass_with_warnings')
    [IO.File]::WriteAllText($manifestPath,$manifest,[Text.UTF8Encoding]::new($false))
  }
  Write-Output "P0_H6_CHECK_RESULT=$result";Write-Output "ASSERTION_COUNT=$($assertions.Count)";Write-Output "ERROR_COUNT=$($errors.Count)";Write-Output "REPORT=$reportPath"
  if($errors.Count){$errors|ForEach-Object{Write-Output "ERROR=$_"};exit 1};exit 0
}catch{Write-Error('P0_H6_CHECKER_ERROR='+$_.Exception.Message);exit 3}
