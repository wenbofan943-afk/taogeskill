Set-StrictMode -Version 2.0

function Test-R3VisualHasProperty {
  param([object]$Value, [string]$Name)
  return $null -ne $Value -and $Value.PSObject.Properties.Name -contains $Name
}

function Get-R3VisualTextDigest {
  param([string]$Text)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
  $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  return 'sha256:' + (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Get-R3VisualBudgetPolicy {
  param([int]$DurationSeconds)
  if ($DurationSeconds -le 0) { throw 'duration_seconds_invalid' }
  if ($DurationSeconds -le 30) { return [pscustomobject]@{ bucket='up_to_30s'; required_min=1; required_max=1; optional_min=1; optional_max=1 } }
  if ($DurationSeconds -le 60) { return [pscustomobject]@{ bucket='over_30_to_60s'; required_min=2; required_max=2; optional_min=1; optional_max=2 } }
  if ($DurationSeconds -le 90) { return [pscustomobject]@{ bucket='over_60_to_90s'; required_min=3; required_max=3; optional_min=1; optional_max=2 } }
  return [pscustomobject]@{ bucket='over_90s_or_multi_segment'; required_min=3; required_max=4; optional_min=2; optional_max=2 }
}

function Test-R3VisualTask {
  param([object]$Task, [string]$ExpectedRequirement)
  $errors = [System.Collections.Generic.List[string]]::new()
  $required = @('image_task_id','beat_id','requirement_level','visual_role','retention_task','insert_after_text','insert_before_text','prompt_id','prompt_text','prompt_sha256','generation_intent','selected_for_generation')
  foreach ($field in $required) {
    if (-not (Test-R3VisualHasProperty $Task $field) -or ($field -notin @('selected_for_generation') -and [string]::IsNullOrWhiteSpace([string]$Task.$field))) { $errors.Add("visual_task_field_missing:$field") }
  }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Task.requirement_level -ne $ExpectedRequirement) { $errors.Add('visual_task_requirement_mismatch') }
  if ($Task.generation_intent -notin @('render_now','deliver_prompt_only','manual_required','omit')) { $errors.Add('visual_task_generation_intent_invalid') }
  if ($ExpectedRequirement -eq 'required' -and $Task.generation_intent -eq 'omit') { $errors.Add('required_visual_cannot_be_omitted') }
  if ([bool]$Task.selected_for_generation -and $Task.generation_intent -ne 'render_now') { $errors.Add('selected_visual_must_render_now') }
  if (-not [bool]$Task.selected_for_generation -and $Task.generation_intent -eq 'render_now') { $errors.Add('render_now_visual_must_be_selected') }
  if ([string]$Task.prompt_sha256 -ne (Get-R3VisualTextDigest ([string]$Task.prompt_text))) { $errors.Add('visual_task_prompt_digest_mismatch') }
  return [object[]]$errors.ToArray()
}

function Test-R3VisualBudgetContract {
  param([object]$Document)
  $errors = [System.Collections.Generic.List[string]]::new()
  $required = @('schema_id','schema_version','policy_version','visual_budget_id','session_id','draft_id','duration_seconds','duration_bucket','default_required_min','default_required_max','default_optional_min','default_optional_max','final_required_count','final_optional_count','selected_optional_count','reduction_reason','expansion_reason','cover_count_excluded','required_visuals','optional_visuals','cover_generation_tasks','expected_pip_provider_call_count','expected_cover_provider_call_count','expected_provider_call_count')
  foreach ($field in $required) { if (-not (Test-R3VisualHasProperty $Document $field)) { $errors.Add("visual_budget_field_missing:$field") } }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Document.schema_id -ne 'taoge://schemas/r3/visual-budget/v0.1' -or $Document.schema_version -ne '0.1' -or $Document.policy_version -ne 'r3-visual-budget-policy-v0.1') { $errors.Add('visual_budget_version_invalid') }
  $policy = $null
  try { $policy = Get-R3VisualBudgetPolicy ([int]$Document.duration_seconds) } catch { $errors.Add('duration_seconds_invalid') }
  if ($null -ne $policy) {
    if ($Document.duration_bucket -ne $policy.bucket) { $errors.Add('duration_bucket_policy_mismatch') }
    foreach ($pair in @(@('default_required_min','required_min'),@('default_required_max','required_max'),@('default_optional_min','optional_min'),@('default_optional_max','optional_max'))) {
      if ([int]$Document.($pair[0]) -ne [int]$policy.($pair[1])) { $errors.Add("visual_budget_policy_value_mismatch:$($pair[0])") }
    }
  }
  if (-not [bool]$Document.cover_count_excluded) { $errors.Add('cover_must_be_excluded_from_pip_budget') }
  $requiredTasks = @($Document.required_visuals); $optionalTasks = @($Document.optional_visuals); $coverTasks = @($Document.cover_generation_tasks)
  if ([int]$Document.final_required_count -ne $requiredTasks.Count) { $errors.Add('final_required_count_mismatch') }
  if ([int]$Document.final_optional_count -ne $optionalTasks.Count) { $errors.Add('final_optional_count_mismatch') }
  $selectedOptional = @($optionalTasks | Where-Object { [bool]$_.selected_for_generation })
  if ([int]$Document.selected_optional_count -ne $selectedOptional.Count) { $errors.Add('selected_optional_count_mismatch') }
  if ($null -ne $policy) {
    $isReduced = [int]$Document.final_required_count -lt $policy.required_min -or [int]$Document.final_optional_count -lt $policy.optional_min
    $isExpanded = [int]$Document.final_required_count -gt $policy.required_max -or [int]$Document.final_optional_count -gt $policy.optional_max
    if ($isReduced -and [string]::IsNullOrWhiteSpace([string]$Document.reduction_reason)) { $errors.Add('visual_budget_reduction_reason_required') }
    if ($isExpanded -and [string]::IsNullOrWhiteSpace([string]$Document.expansion_reason)) { $errors.Add('visual_budget_expansion_reason_required') }
  }
  $ids = @{}
  $taskGroups = @(
    [pscustomobject]@{ tasks=[object[]]$requiredTasks; requirement='required' },
    [pscustomobject]@{ tasks=[object[]]$optionalTasks; requirement='optional' },
    [pscustomobject]@{ tasks=[object[]]$coverTasks; requirement='cover' }
  )
  foreach ($group in $taskGroups) {
    $tasks = @($group.tasks); $requirement = [string]$group.requirement
    foreach ($task in $tasks) {
      foreach ($error in (Test-R3VisualTask $task $(if($requirement -eq 'cover'){'required'}else{$requirement}))) { $errors.Add("$($task.image_task_id):$error") }
      if ($ids.ContainsKey([string]$task.image_task_id)) { $errors.Add("visual_task_id_duplicate:$($task.image_task_id)") } else { $ids[[string]$task.image_task_id]=$true }
    }
  }
  $selectedRequired = @($requiredTasks | Where-Object { [bool]$_.selected_for_generation }).Count
  $selectedCover = @($coverTasks | Where-Object { [bool]$_.selected_for_generation }).Count
  if ([int]$Document.expected_pip_provider_call_count -ne ($selectedRequired + $selectedOptional.Count)) { $errors.Add('expected_pip_provider_call_count_mismatch') }
  if ([int]$Document.expected_cover_provider_call_count -ne $selectedCover) { $errors.Add('expected_cover_provider_call_count_mismatch') }
  if ([int]$Document.expected_provider_call_count -ne ([int]$Document.expected_pip_provider_call_count + [int]$Document.expected_cover_provider_call_count)) { $errors.Add('expected_provider_call_count_mismatch') }
  return [object[]]$errors.ToArray()
}
