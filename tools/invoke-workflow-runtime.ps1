param(
  [Parameter(Mandatory=$true)][string]$SessionPath,
  [ValidateSet('validate','render_final_delivery','resume_report')][string]$Mode = 'validate'
)

$ErrorActionPreference = 'Stop'
function Write-Event([string]$Path, [hashtable]$Event) { ($Event | ConvertTo-Json -Compress) | Add-Content -LiteralPath $Path -Encoding UTF8 }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
try {
  $session = (Resolve-Path -LiteralPath $SessionPath).Path
  $runtime = Join-Path $session 'intermediate/p0'
  $planPath = Join-Path $runtime 'session-execution-plan.json'
  $eventPath = Join-Path $runtime 'execution-events.jsonl'
  if (-not (Test-Path -LiteralPath $planPath)) {
    Write-Output 'WORKFLOW_RUNTIME_RESULT=legacy_evidence_replay'
    Write-Output 'WORKFLOW_RUNTIME_WARNING=plan_and_events_absent_no_autonomy_claim'
    exit 0
  }
  $plan = Get-Content -LiteralPath $planPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $errors = [System.Collections.Generic.List[string]]::new()
  if ($plan.workflow_version -ne 'p0-runtime-v0.1') { $errors.Add('workflow_version_invalid') }
  if (-not $plan.plan_id -or -not $plan.session_id -or -not $plan.steps) { $errors.Add('plan_required_field_missing') }
  $allowed = @('deterministic_tool','agent_required','human_gate','external_side_effect')
  $seen = @{}
  foreach ($step in @($plan.steps)) {
    if (-not $step.step_id -or $seen.ContainsKey($step.step_id)) { $errors.Add('step_id_missing_or_duplicate') } else { $seen[$step.step_id] = $true }
    if ($step.step_kind -notin $allowed) { $errors.Add('step_kind_invalid:' + $step.step_id) }
    if (-not $step.failure_route) { $errors.Add('failure_route_missing:' + $step.step_id) }
  }
  if ($errors.Count) { $errors | ForEach-Object { Write-Output "WORKFLOW_RUNTIME_ERROR=$_" }; exit 1 }
  $events = @(); if (Test-Path -LiteralPath $eventPath) { $events = @(Get-Content -LiteralPath $eventPath -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json }) }
  $succeeded = @{}; foreach ($event in $events) { if ($event.state_after -eq 'succeeded') { $succeeded[$event.step_id] = $event } }
  $pending = @($plan.steps | Where-Object { -not $succeeded.ContainsKey($_.step_id) })
  if ($Mode -eq 'resume_report') { Write-Output ('WORKFLOW_RUNTIME_RESULT=' + $(if($pending.Count){'resume_ready'}else{'completed'})); Write-Output ('RESUME_NEXT_STEP=' + $(if($pending.Count){$pending[0].step_id}else{'none'})); exit 0 }
  if ($Mode -eq 'render_final_delivery') {
    $renderStep = @($plan.steps | Where-Object { $_.step_kind -eq 'deterministic_tool' -and $_.operation -eq 'render_final_delivery' }) | Select-Object -First 1
    if (-not $renderStep) { Write-Error 'render_final_delivery step missing from plan'; exit 1 }
    foreach ($requiredStep in @($renderStep.requires_step_ids)) { if (-not $succeeded.ContainsKey($requiredStep)) { Write-Error "render prerequisite not succeeded: $requiredStep"; exit 1 } }
    $inputPath = Join-Path $session 'deliverables/p0/final-delivery-render-input.json'
    if (-not (Test-Path -LiteralPath $inputPath)) { Write-Error 'deterministic render input missing'; exit 1 }
    $input = Get-Content -LiteralPath $inputPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $template = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../templates/final-delivery/final-delivery.template.html') -Raw -Encoding UTF8
    $safeScript = [System.Net.WebUtility]::HtmlEncode([string]$input.final_script)
    $replacements = @{title=$input.title;account=$input.account;session_id=$plan.session_id;source_research_run_id=$input.source_research_run_id;delivery_page_mode='project_local';final_delivery_status='html_ready';image_assets_status=$input.image_assets_status;visual_text_plan_id=$input.visual_text_plan_id;visual_text_quality_gate_status=$input.visual_text_quality_gate_status;cover_design_package_id=$input.cover_design_package_id;upload_ready_cover_count=$input.upload_ready_cover_count;prompt_only_cover_count=$input.prompt_only_cover_count;html_builder_mode='skill_template_rendered';html_template_source='templates/final-delivery/final-delivery.template.html';topic_title=$input.title;topic_rationale=$input.topic_rationale;hook_text=$input.hook_text;final_script=$safeScript;cover_design_summary=$input.cover_design_summary;cover_quality_summary=$input.cover_quality_summary;platform_cover_strategy=$input.platform_cover_strategy_html;cover_ready_assets=$input.cover_ready_assets_html;cover_background_assets=$input.cover_background_assets_html;cover_prompt_only_assets=$input.cover_prompt_only_assets_html;visual_text_delivery_summary=$input.visual_text_delivery_summary;picture_in_picture_assets=$input.picture_in_picture_assets_html;platform_package=$input.platform_package_html;trace_links=$input.trace_links_html;human_prompt=$input.human_prompt}
    foreach ($key in $replacements.Keys) { $template = $template.Replace('{{' + $key + '}}', [string]$replacements[$key]) }
    if ($template -match '\{\{[^}]+\}\}') { Write-Error 'unresolved template token'; exit 1 }
    $output = Join-Path $session 'deliverables/final-delivery.html'; $template | Set-Content -LiteralPath $output -Encoding UTF8
    if (-not (Test-Path -LiteralPath $eventPath)) { New-Item -ItemType File -Path $eventPath -Force | Out-Null }
    Write-Event $eventPath @{event_id=('EVT-'+(Get-Date -Format 'yyyyMMdd-HHmmss'));step_id=$renderStep.step_id;state_before='running';state_after='succeeded';execution_source='deterministic_tool';input_digest=('sha256:'+(Hash $inputPath));output_artifact_ids=@($input.final_delivery_id);exit_code=0}
    Write-Output 'WORKFLOW_RUNTIME_RESULT=rendered'; exit 0
  }
  Write-Output ('WORKFLOW_RUNTIME_RESULT=' + $(if($pending.Count){'plan_valid_waiting_steps'}else{'plan_valid_completed'})); exit 0
} catch { Write-Error $_; exit 3 }
