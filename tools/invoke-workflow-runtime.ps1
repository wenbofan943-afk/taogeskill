param(
  [Parameter(Mandatory=$true)][string]$SessionPath,
  [ValidateSet('validate','render_final_delivery','resume_report')][string]$Mode = 'validate'
)

$ErrorActionPreference = 'Stop'
function Write-Event([string]$Path, [hashtable]$Event) { ($Event | ConvertTo-Json -Compress) | Add-Content -LiteralPath $Path -Encoding UTF8 }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function New-EventId { 'EVT-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + ([guid]::NewGuid().ToString('N').Substring(0,8)) }
function Encode([object]$Value) { [System.Net.WebUtility]::HtmlEncode([string]$Value) }
function Test-UnsafeHtml([string]$Value) { $Value -match '(?is)<\s*(?:script|iframe|object|embed|form|meta|link)\b|\bon[a-z]+\s*=|javascript\s*:' }
function Get-BrokenLocalReferences([string]$Html, [string]$OutputPath) {
  $broken = [System.Collections.Generic.List[string]]::new()
  $base = Split-Path -Parent $OutputPath
  foreach ($match in [regex]::Matches($Html, '(?:href|src)=["'']([^"''#]+)["'']', 'IgnoreCase')) {
    $reference = $match.Groups[1].Value
    if ($reference -match '^(?:https?:|mailto:|javascript:|data:)') { continue }
    $clean = ($reference -split '[?#]', 2)[0]
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $base ([System.Net.WebUtility]::HtmlDecode($clean))))
    if (-not (Test-Path -LiteralPath $candidate)) { $broken.Add($reference) }
  }
  return $broken.ToArray()
}
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
  foreach ($step in @($plan.steps)) {
    foreach ($requiredStep in @($step.requires_step_ids)) {
      if ([string]::IsNullOrWhiteSpace([string]$requiredStep)) { continue }
      if (-not $seen.ContainsKey([string]$requiredStep)) { $errors.Add('required_step_missing:' + $step.step_id + ':' + $requiredStep) }
      if ($requiredStep -eq $step.step_id) { $errors.Add('step_self_dependency:' + $step.step_id) }
    }
    if ($step.step_kind -eq 'deterministic_tool' -and [string]::IsNullOrWhiteSpace([string]$step.operation)) { $errors.Add('deterministic_operation_missing:' + $step.step_id) }
  }
  if ($errors.Count) { $errors | ForEach-Object { Write-Output "WORKFLOW_RUNTIME_ERROR=$_" }; exit 1 }
  $events = @(); if (Test-Path -LiteralPath $eventPath) { $events = @(Get-Content -LiteralPath $eventPath -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json }) }
  $eventStates = @('ready','running','waiting_agent','waiting_human','waiting_external','succeeded','failed','blocked','skipped','not_invoked')
  foreach ($event in $events) {
    if (-not $seen.ContainsKey([string]$event.step_id)) { $errors.Add('event_step_unknown:' + $event.step_id) }
    if ($event.state_after -notin $eventStates) { $errors.Add('event_state_invalid:' + $event.step_id) }
    if ($event.state_after -eq 'succeeded') {
      $eventStep = @($plan.steps | Where-Object { $_.step_id -eq $event.step_id }) | Select-Object -First 1
      if ($eventStep -and $event.execution_source -ne $eventStep.step_kind) { $errors.Add('event_execution_source_mismatch:' + $event.step_id) }
    }
  }
  if ($errors.Count) { $errors | ForEach-Object { Write-Output "WORKFLOW_RUNTIME_ERROR=$_" }; exit 1 }
  $succeeded = @{}; foreach ($event in $events) { if ($event.state_after -eq 'succeeded') { $succeeded[$event.step_id] = $event } }
  $renderPlanStep = @($plan.steps | Where-Object { $_.operation -eq 'render_final_delivery' }) | Select-Object -First 1
  if ($renderPlanStep -and $succeeded.ContainsKey($renderPlanStep.step_id)) {
    $lineagePath = Join-Path $session 'deliverables/p0/artifact-lineage-manifest.json'
    if (-not (Test-Path -LiteralPath $lineagePath)) {
      $errors.Add('final_delivery_lineage_missing')
    } else {
      $lineage = (Get-Content -LiteralPath $lineagePath -Raw -Encoding UTF8 | ConvertFrom-Json).artifact_lineage_manifest
      $producer = @($events | Where-Object { $_.event_id -eq $lineage.producer_event_id -and $_.step_id -eq $renderPlanStep.step_id -and $_.state_after -eq 'succeeded' }) | Select-Object -First 1
      if (-not $producer) { $errors.Add('lineage_producer_event_invalid') }
      if ($lineage.materialization_status -ne 'materialized') { $errors.Add('lineage_materialization_status_invalid') }
      $materializedPath = Join-Path $session ([string]$lineage.path)
      if (-not (Test-Path -LiteralPath $materializedPath)) {
        $errors.Add('lineage_artifact_missing')
      } else {
        if ($lineage.sha256 -ne ('sha256:' + (Hash $materializedPath))) { $errors.Add('lineage_sha256_mismatch') }
        $broken = @(Get-BrokenLocalReferences (Get-Content -LiteralPath $materializedPath -Raw -Encoding UTF8) $materializedPath)
        foreach ($reference in $broken) { $errors.Add('final_delivery_broken_reference:' + $reference) }
      }
    }
  }
  if ($errors.Count) { $errors | ForEach-Object { Write-Output "WORKFLOW_RUNTIME_ERROR=$_" }; exit 1 }
  $pending = @($plan.steps | Where-Object { -not $succeeded.ContainsKey($_.step_id) })
  if ($Mode -eq 'resume_report') { Write-Output ('WORKFLOW_RUNTIME_RESULT=' + $(if($pending.Count){'resume_ready'}else{'completed'})); Write-Output ('RESUME_NEXT_STEP=' + $(if($pending.Count){$pending[0].step_id}else{'none'})); exit 0 }
  if ($Mode -eq 'render_final_delivery') {
    $renderStep = @($plan.steps | Where-Object { $_.step_kind -eq 'deterministic_tool' -and $_.operation -eq 'render_final_delivery' }) | Select-Object -First 1
    if (-not $renderStep) { Write-Error 'render_final_delivery step missing from plan'; exit 1 }
    foreach ($requiredStep in @($renderStep.requires_step_ids)) {
      if (-not $succeeded.ContainsKey($requiredStep)) { Write-Output "WORKFLOW_RUNTIME_ERROR=render_prerequisite_not_succeeded:$requiredStep"; exit 1 }
      $requiredPlanStep = @($plan.steps | Where-Object { $_.step_id -eq $requiredStep }) | Select-Object -First 1
      if (-not $requiredPlanStep -or $succeeded[$requiredStep].execution_source -ne $requiredPlanStep.step_kind) { Write-Output "WORKFLOW_RUNTIME_ERROR=prerequisite_execution_source_mismatch:$requiredStep"; exit 1 }
    }
    $inputPath = Join-Path $session 'deliverables/p0/final-delivery-render-input.json'
    if (-not (Test-Path -LiteralPath $inputPath)) { Write-Error 'deterministic render input missing'; exit 1 }
    $input = Get-Content -LiteralPath $inputPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($field in @('render_input_id','final_delivery_id','title','account','source_research_run_id','final_script','image_assets_status')) {
      if ([string]::IsNullOrWhiteSpace([string]$input.$field)) { Write-Output "WORKFLOW_RUNTIME_ERROR=render_input_field_missing:$field"; exit 1 }
    }
    $template = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../templates/final-delivery/final-delivery.template.html') -Raw -Encoding UTF8
    $htmlFields = @('platform_cover_strategy_html','cover_ready_assets_html','cover_background_assets_html','cover_prompt_only_assets_html','picture_in_picture_assets_html','platform_package_html','trace_links_html')
    foreach ($field in $htmlFields) { if (Test-UnsafeHtml ([string]$input.$field)) { Write-Output "WORKFLOW_RUNTIME_ERROR=unsafe_html_fragment:$field"; exit 1 } }
    $replacements = @{title=(Encode $input.title);account=(Encode $input.account);session_id=(Encode $plan.session_id);source_research_run_id=(Encode $input.source_research_run_id);delivery_page_mode='project_local';final_delivery_status='html_ready';image_assets_status=(Encode $input.image_assets_status);visual_text_plan_id=(Encode $input.visual_text_plan_id);visual_text_quality_gate_status=(Encode $input.visual_text_quality_gate_status);cover_design_package_id=(Encode $input.cover_design_package_id);upload_ready_cover_count=(Encode $input.upload_ready_cover_count);prompt_only_cover_count=(Encode $input.prompt_only_cover_count);html_builder_mode='skill_template_rendered';html_template_source='templates/final-delivery/final-delivery.template.html';topic_title=(Encode $input.title);topic_rationale=(Encode $input.topic_rationale);hook_text=(Encode $input.hook_text);final_script=(Encode $input.final_script);cover_design_summary=(Encode $input.cover_design_summary);cover_quality_summary=(Encode $input.cover_quality_summary);platform_cover_strategy=$input.platform_cover_strategy_html;cover_ready_assets=$input.cover_ready_assets_html;cover_background_assets=$input.cover_background_assets_html;cover_prompt_only_assets=$input.cover_prompt_only_assets_html;visual_text_delivery_summary=(Encode $input.visual_text_delivery_summary);picture_in_picture_assets=$input.picture_in_picture_assets_html;platform_package=$input.platform_package_html;trace_links=$input.trace_links_html;human_prompt=(Encode $input.human_prompt)}
    foreach ($key in $replacements.Keys) { $template = $template.Replace('{{' + $key + '}}', [string]$replacements[$key]) }
    if ($template -match '\{\{[^}]+\}\}') { Write-Error 'unresolved template token'; exit 1 }
    $inputDigest = 'sha256:' + (Hash $inputPath)
    $output = Join-Path $session 'deliverables/final-delivery.html'
    $prior = @($events | Where-Object { $_.step_id -eq $renderStep.step_id -and $_.state_after -eq 'succeeded' -and $_.input_digest -eq $inputDigest }) | Select-Object -First 1
    if ($prior -and (Test-Path -LiteralPath $output)) {
      Write-Event $eventPath @{event_id=(New-EventId);step_id=$renderStep.step_id;state_before='ready';state_after='skipped';result='skipped_reused';execution_source='deterministic_tool';input_digest=$inputDigest;output_artifact_ids=@($input.final_delivery_id);exit_code=0}
      Write-Output 'WORKFLOW_RUNTIME_RESULT=skipped_reused'; exit 0
    }
    $brokenReferences = @(Get-BrokenLocalReferences $template $output)
    if ($brokenReferences.Count) {
      if (-not (Test-Path -LiteralPath $eventPath)) { New-Item -ItemType File -Path $eventPath -Force | Out-Null }
      Write-Event $eventPath @{event_id=(New-EventId);step_id=$renderStep.step_id;state_before='running';state_after='failed';result='local_reference_check_failed';execution_source='deterministic_tool';input_digest=$inputDigest;broken_references=$brokenReferences;exit_code=1}
      $brokenReferences | ForEach-Object { Write-Output "WORKFLOW_RUNTIME_ERROR=broken_local_reference:$_" }
      exit 1
    }
    [System.IO.File]::WriteAllText($output, $template.TrimEnd("`r", "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
    if (-not (Test-Path -LiteralPath $eventPath)) { New-Item -ItemType File -Path $eventPath -Force | Out-Null }
    $eventId = New-EventId
    Write-Event $eventPath @{event_id=$eventId;step_id=$renderStep.step_id;state_before='running';state_after='succeeded';execution_source='deterministic_tool';input_digest=$inputDigest;output_artifact_ids=@($input.final_delivery_id);exit_code=0}
    @{ artifact_lineage_manifest = @{ artifact_id=$input.final_delivery_id; artifact_type='final_delivery'; producer_event_id=$eventId; input_artifact_ids=@($input.render_input_id); materialization_status='materialized'; path='deliverables/final-delivery.html'; sha256=('sha256:' + (Hash $output)) } } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $session 'deliverables/p0/artifact-lineage-manifest.json') -Encoding UTF8
    Write-Output 'WORKFLOW_RUNTIME_RESULT=rendered'; exit 0
  }
  Write-Output ('WORKFLOW_RUNTIME_RESULT=' + $(if($pending.Count){'plan_valid_waiting_steps'}else{'plan_valid_completed'})); exit 0
} catch { Write-Error $_; exit 3 }
