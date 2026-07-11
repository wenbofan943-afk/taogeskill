Set-StrictMode -Version 2.0

if (-not (Get-Command Test-P0PlanContract -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
}

function New-P0EvidenceResult {
  param([string]$ResultCode, [int]$ExitCode, [object]$Event, [int]$LastSequenceNo, [string[]]$Errors)
  return [pscustomobject]@{
    ResultCode = $ResultCode
    ExitCode = $ExitCode
    Event = $Event
    LastSequenceNo = $LastSequenceNo
    Errors = [object[]]@($Errors)
  }
}

function ConvertTo-P0EvidenceJsonText {
  param([object]$Value)
  return ($Value | ConvertTo-Json -Depth 50).TrimEnd("`r", "`n") + "`n"
}

function Write-P0EvidenceAtomicText {
  param([string]$Path, [string]$Text)
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  $temporary = "$Path.tmp-$([guid]::NewGuid().ToString('N'))"
  [System.IO.File]::WriteAllText($temporary, $Text, [System.Text.UTF8Encoding]::new($false))
  try {
    if (Test-Path -LiteralPath $Path) {
      try { [System.IO.File]::Replace($temporary, $Path, $null) }
      catch { Move-Item -LiteralPath $temporary -Destination $Path -Force }
    } else {
      [System.IO.File]::Move($temporary, $Path)
    }
  } finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
  }
}

function Get-P0EvidenceHash {
  param([string]$Path)
  return 'sha256:' + (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-P0EvidenceTextDigest {
  param([string]$Text)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return 'sha256:' + ([BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()) }
  finally { $sha.Dispose() }
}

function Get-P0EvidenceObjectDigest {
  param([object]$Value)
  return (Get-P0EvidenceTextDigest ((ConvertTo-P0EvidenceJsonText $Value).TrimEnd("`r", "`n")))
}

function Read-P0EvidenceEventsFromText {
  param([string]$Text)
  $events = [System.Collections.Generic.List[object]]::new()
  foreach ($line in ($Text -split "`r?`n")) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $events.Add(($line | ConvertFrom-Json))
  }
  return [object[]]$events.ToArray()
}

function Get-P0EvidenceEvents {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return @() }
  return (Read-P0EvidenceEventsFromText (Get-Content -LiteralPath $Path -Raw -Encoding UTF8))
}

function Get-P0EvidenceStep {
  param([object]$Plan, [string]$StepId)
  return @($Plan.steps | Where-Object { $_.step_id -eq $StepId }) | Select-Object -First 1
}

function Get-P0EvidencePrivacyClass {
  param([string]$SessionId)
  if ($SessionId -match '(?i)fixture|sample') { return 'public_sample' }
  return 'local_private'
}

function Test-P0EvidenceSourceForStep {
  param([object]$Step, [string]$EventSource, [string]$StateAfter)
  if ($StateAfter -ne 'succeeded') { return $true }
  $allowed = switch ([string]$Step.step_kind) {
    'deterministic_tool' { @('runner','reconciler') }
    'agent_required' { @('agent_recorder') }
    'human_gate' { @('human_recorder') }
    'external_side_effect' { @('external_recorder','reconciler') }
    default { @() }
  }
  return $EventSource -in $allowed
}

function Write-P0EvidenceEvent {
  param(
    [string]$EventPath,
    [object]$Plan,
    [string]$StepId,
    [string]$EventType,
    [string]$EventSource,
    [string]$StateBefore,
    [string]$StateAfter,
    [string]$PayloadDigest,
    [string]$IdempotencyKey,
    [int]$ExpectedLastSequenceNo,
    [string]$ResultCode,
    [string]$SafeSummary,
    [string[]]$OutputArtifactIds = @(),
    [string]$InputDigest = $null,
    [string]$ExecutionAttemptId = $null,
    [int]$AttemptNo = 1,
    [object]$Failure = $null,
    [string]$CausationEventId = $null,
    [string]$CorrelationId = $null,
    [string]$OccurredAt = $null
  )
  $step = Get-P0EvidenceStep $Plan $StepId
  if ($null -eq $step) { return New-P0EvidenceResult 'event_step_unknown' 1 $null -1 @("event_step_unknown:$StepId") }
  if (-not (Test-P0Digest $PayloadDigest)) { return New-P0EvidenceResult 'payload_digest_invalid' 1 $null -1 @('event_payload_digest_invalid') }
  if (-not [string]::IsNullOrWhiteSpace($InputDigest) -and -not (Test-P0Digest $InputDigest)) { return New-P0EvidenceResult 'input_digest_invalid' 1 $null -1 @('event_input_digest_invalid') }
  if ([string]::IsNullOrWhiteSpace($SafeSummary) -or $SafeSummary.Length -gt 240) { return New-P0EvidenceResult 'safe_summary_invalid' 1 $null -1 @('safe_summary_invalid') }
  if (-not (Test-P0EvidenceSourceForStep $step $EventSource $StateAfter)) { return New-P0EvidenceResult 'event_source_step_kind_mismatch' 1 $null -1 @("event_source_step_kind_mismatch:$StepId") }

  $parent = Split-Path -Parent $EventPath
  if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  $stream = $null
  try {
    $lockError = $null
    for ($lockAttempt = 1; $lockAttempt -le 20 -and $null -eq $stream; $lockAttempt++) {
      try { $stream = [System.IO.File]::Open($EventPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) }
      catch [System.IO.IOException] {
        $lockError = $_.Exception.Message
        if ($lockAttempt -lt 20) { Start-Sleep -Milliseconds 10 }
      }
    }
    if ($null -eq $stream) { return (New-P0EvidenceResult 'concurrent_append_conflict' 1 $null -1 @("event_log_locked:$lockError")) }
    $bytes = New-Object byte[] ([int]$stream.Length)
    $stream.Position = 0
    if ($bytes.Length -gt 0) { [void]$stream.Read($bytes, 0, $bytes.Length) }
    $existingText = [System.Text.Encoding]::UTF8.GetString($bytes)
    try { $events = @(Read-P0EvidenceEventsFromText $existingText) }
    catch { return New-P0EvidenceResult 'event_log_parse_failed' 1 $null -1 @('event_log_parse_failed') }
    if ($events.Count -gt 0) {
      $existingErrors = @(Test-P0EventLogContract $events)
      if ($existingErrors.Count) { return New-P0EvidenceResult 'event_sequence_conflict' 1 $null $events.Count $existingErrors }
    }
    $prior = @($events | Where-Object { $_.event_type -eq $EventType -and $_.idempotency_key -eq $IdempotencyKey }) | Select-Object -First 1
    if ($prior) {
      if ($prior.payload_digest -eq $PayloadDigest) { return New-P0EvidenceResult 'duplicate_reused' 0 $prior $events.Count @() }
      return (New-P0EvidenceResult 'idempotency_conflict' 1 $prior $events.Count @("idempotency_conflict:$($prior.event_id)"))
    }
    if ($ExpectedLastSequenceNo -ne $events.Count) { return New-P0EvidenceResult 'concurrent_append_conflict' 1 $null $events.Count @("expected_last_sequence_no:$ExpectedLastSequenceNo;actual:$($events.Count)") }

    $sequence = $events.Count + 1
    $previous = if ($events.Count) { [string]$events[-1].event_id } else { $null }
    $safeSession = ([string]$Plan.session_id -replace '[^A-Za-z0-9_-]','-')
    $timestamp = if ([string]::IsNullOrWhiteSpace($OccurredAt)) { [DateTimeOffset]::UtcNow.ToString('o') } else { $OccurredAt }
    $recorded = [DateTimeOffset]::UtcNow.ToString('o')
    $event = [ordered]@{
      event_id = 'EVT-' + $safeSession + '-' + $sequence.ToString('0000')
      event_type = $EventType
      event_schema_id = 'taoge://schemas/p0/execution-event/v0.2'
      event_source = $EventSource
      session_id = [string]$Plan.session_id
      subject_id = $StepId
      step_id = $StepId
      sequence_no = $sequence
      previous_event_id = $previous
      occurred_at = $timestamp
      recorded_at = $recorded
      causation_event_id = $(if ([string]::IsNullOrWhiteSpace($CausationEventId)) { $previous } else { $CausationEventId })
      correlation_id = $(if ([string]::IsNullOrWhiteSpace($CorrelationId)) { "CMD-$safeSession-$StepId" } else { $CorrelationId })
      idempotency_key = $IdempotencyKey
      execution_attempt_id = $ExecutionAttemptId
      attempt_no = $AttemptNo
      privacy_class = Get-P0EvidencePrivacyClass ([string]$Plan.session_id)
      state_before = $StateBefore
      state_after = $StateAfter
      payload_digest = $PayloadDigest
      output_artifact_ids = [object[]]@($OutputArtifactIds | Sort-Object -Unique)
      result_code = $ResultCode
      safe_summary = $SafeSummary
    }
    if (-not [string]::IsNullOrWhiteSpace($InputDigest)) { $event.input_digest = $InputDigest }
    if ($null -ne $Failure) { $event.failure = [pscustomobject](($Failure | ConvertTo-Json -Depth 10) | ConvertFrom-Json) }
    $candidate = @($events) + @([pscustomobject]$event)
    $candidateErrors = @(Test-P0EventLogContract $candidate)
    if ($candidateErrors.Count) { return New-P0EvidenceResult 'event_contract_failed' 1 $null $events.Count $candidateErrors }
    $line = ($event | ConvertTo-Json -Compress) + "`n"
    if ($existingText.Length -gt 0 -and -not $existingText.EndsWith("`n")) { $line = "`n" + $line }
    $outputBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($line)
    $stream.Position = $stream.Length
    $stream.Write($outputBytes, 0, $outputBytes.Length)
    $stream.Flush($true)
    return (New-P0EvidenceResult 'appended' 0 ([pscustomobject]$event) $sequence @())
  } catch {
    return (New-P0EvidenceResult 'event_writer_error' 3 $null -1 @($_.Exception.Message))
  } finally {
    if ($null -ne $stream) { $stream.Dispose() }
  }
}

function Resolve-P0EvidenceSessionPath {
  param([string]$Session, [string]$RelativePath)
  if (-not (Test-P0RelativePath $RelativePath)) { throw "unsafe_session_path:$RelativePath" }
  $root = [System.IO.Path]::GetFullPath($Session).TrimEnd('\')
  $full = [System.IO.Path]::GetFullPath((Join-Path $root $RelativePath))
  if ($full -ne $root -and -not $full.StartsWith($root + '\', [System.StringComparison]::OrdinalIgnoreCase)) { throw "session_path_escape:$RelativePath" }
  return $full
}

function Write-P0EvidenceLineage {
  param(
    [string]$Session,
    [string]$ArtifactId,
    [string]$ArtifactType,
    [string]$ProducerEventId,
    [string[]]$InputArtifactIds,
    [string]$RelativePath,
    [string]$Sha256,
    [string]$QualityStatus,
    [string]$DeliveryEligibility,
    [string[]]$CheckIds = @()
  )
  $safeId = $ArtifactId -replace '[^A-Za-z0-9_-]','-'
  $lineagePath = Join-Path $Session "deliverables/p0/lineage/$safeId.json"
  $document = [ordered]@{
    schema_id='taoge://schemas/p0/artifact-lineage/v0.2'
    schema_version='0.2'
    artifact_lineage_manifest=[ordered]@{
      artifact_id=$ArtifactId
      artifact_type=$ArtifactType
      producer_event_id=$ProducerEventId
      input_artifact_ids=[object[]]@($InputArtifactIds | Sort-Object -Unique)
      materialization_status='materialized'
      quality_status=$QualityStatus
      delivery_eligibility=$DeliveryEligibility
      path=$RelativePath
      sha256=$Sha256
      check_ids=[object[]]@($CheckIds | Sort-Object -Unique)
    }
  }
  $errors = @(Test-P0LineageContract ([pscustomobject](($document | ConvertTo-Json -Depth 20) | ConvertFrom-Json)))
  if ($errors.Count) { throw ('lineage_contract_failed:' + [string]::Join(';', $errors)) }
  if (Test-Path -LiteralPath $lineagePath) {
    $existing = Read-P0JsonFile $lineagePath
    if ($existing.artifact_lineage_manifest.sha256 -ne $Sha256 -or $existing.artifact_lineage_manifest.path -ne $RelativePath) { throw "lineage_conflict:$ArtifactId" }
  }
  Write-P0EvidenceAtomicText $lineagePath (ConvertTo-P0EvidenceJsonText $document)
  return $lineagePath
}

function Get-P0EvidenceEventLogDigest {
  param([string]$EventPath)
  if (-not (Test-Path -LiteralPath $EventPath)) { return Get-P0EvidenceTextDigest '' }
  return (Get-P0EvidenceHash $EventPath)
}

function New-P0StateProjection {
  param([object]$Plan, [object[]]$Events, [string]$SourceEventDigest)
  if (@($Events).Count -gt 0) {
    $eventErrors = @(Test-P0EventLogContract $Events)
    if ($eventErrors.Count) { throw ('event_sequence_conflict:' + [string]::Join(';', $eventErrors)) }
  }
  $latest = @{}
  $succeeded = @{}
  foreach ($event in @($Events)) {
    $latest[[string]$event.step_id] = $event
    if ($event.state_after -eq 'succeeded') { $succeeded[[string]$event.step_id] = $event }
  }
  $stepStates = [System.Collections.Generic.List[object]]::new()
  foreach ($step in @($Plan.steps)) {
    $event = if ($latest.ContainsKey([string]$step.step_id)) { $latest[[string]$step.step_id] } else { $null }
    $state = if ($null -eq $event) { 'pending' } else { [string]$event.state_after }
    $stepStates.Add([ordered]@{ step_id=[string]$step.step_id; step_kind=[string]$step.step_kind; state=$state; latest_event_id=$(if ($null -eq $event) { $null } else { [string]$event.event_id }) })
  }
  $priorityStates = @('cancel_pending_external','outcome_unknown','waiting_human','waiting_agent','waiting_external','not_invoked','failed','blocked','attempt_interrupted','running','cancel_requested')
  $active = $null
  foreach ($priority in $priorityStates) {
    $active = @($stepStates | Where-Object { $_.state -eq $priority }) | Select-Object -First 1
    if ($null -ne $active) { break }
  }
  $next = $null
  if ($null -ne $active) { $next = [string]$active.step_id }
  else {
    foreach ($step in @($Plan.steps)) {
      if ($succeeded.ContainsKey([string]$step.step_id)) { continue }
      $requirements = if (Test-P0HasProperty $step 'requires_step_ids') { @($step.requires_step_ids) } else { @() }
      if (@($requirements | Where-Object { -not $succeeded.ContainsKey([string]$_) }).Count -eq 0) { $next = [string]$step.step_id; break }
    }
  }
  $currentState = if ($null -ne $active) { [string]$active.state } elseif ($null -eq $next) { 'completed' } else { 'ready' }
  $nonRepeatable = [System.Collections.Generic.List[string]]::new()
  foreach ($step in @($Plan.steps | Where-Object { $_.step_kind -eq 'external_side_effect' })) {
    $externalEvents = @($Events | Where-Object { $_.step_id -eq $step.step_id -and ($_.event_type -match '^external\.(request_sent|result_recorded|outcome_unknown)' -or $_.state_after -in @('succeeded','outcome_unknown','cancel_pending_external')) })
    if ($externalEvents.Count) { $nonRepeatable.Add([string]$step.step_id) }
  }
  $lastRecorded = if (@($Events).Count) { [string]$Events[-1].recorded_at } else { $null }
  return [ordered]@{
    schema_id='taoge://schemas/p0/state-projection/v0.2'
    schema_version='0.2'
    projection_version='p0-state-projection-v0.2'
    session_id=[string]$Plan.session_id
    plan_id=[string]$Plan.plan_id
    projected_through_sequence_no=@($Events).Count
    source_event_digest=$SourceEventDigest
    source_last_recorded_at=$lastRecorded
    current_state=$currentState
    completed_step_ids=[object[]]@($succeeded.Keys | Sort-Object)
    waiting_step_id=$(if ($null -ne $active) { [string]$active.step_id } else { $null })
    next_step_id=$next
    non_repeatable_step_ids=[object[]]$nonRepeatable.ToArray()
    step_states=[object[]]$stepStates.ToArray()
  }
}

function Update-P0StateProjection {
  param([string]$Session, [object]$Plan, [string]$EventPath, [bool]$ForceRebuild = $false)
  $events = @(Get-P0EvidenceEvents $EventPath)
  $digest = Get-P0EvidenceEventLogDigest $EventPath
  $projectionPath = Join-Path $Session 'intermediate/p0/state-projection.json'
  $newProjection = New-P0StateProjection $Plan $events $digest
  $resultCode = 'projection_created'
  if (Test-Path -LiteralPath $projectionPath) {
    $existing = Read-P0JsonFile $projectionPath
    $tail = @($events).Count
    if ([int]$existing.projected_through_sequence_no -gt $tail) {
      if (-not $ForceRebuild) { return [pscustomobject]@{ ResultCode='state_projection_conflict'; ExitCode=1; Projection=$null; Path=$projectionPath; Errors=@('projection_ahead_of_event_log') } }
      $resultCode = 'projection_rebuilt_from_conflict'
    } elseif ([int]$existing.projected_through_sequence_no -eq $tail -and $existing.source_event_digest -ne $digest) {
      if (-not $ForceRebuild) { return [pscustomobject]@{ ResultCode='state_projection_conflict'; ExitCode=1; Projection=$null; Path=$projectionPath; Errors=@('projection_event_digest_mismatch') } }
      $resultCode = 'projection_rebuilt_from_conflict'
    } elseif ([int]$existing.projected_through_sequence_no -eq $tail -and $existing.source_event_digest -eq $digest) {
      return [pscustomobject]@{ ResultCode='projection_current'; ExitCode=0; Projection=$existing; Path=$projectionPath; Errors=@() }
    } else { $resultCode = 'projection_rebuilt_from_lag' }
    if ($ForceRebuild -and $resultCode -eq 'projection_rebuilt_from_conflict') {
      $quarantine = Join-Path $Session 'intermediate/p0/quarantine'
      if (-not (Test-Path -LiteralPath $quarantine)) { New-Item -ItemType Directory -Path $quarantine -Force | Out-Null }
      $oldDigest = (Get-P0EvidenceHash $projectionPath).Substring(7,12)
      Copy-Item -LiteralPath $projectionPath -Destination (Join-Path $quarantine "state-projection-$oldDigest.json") -Force
    }
  }
  Write-P0EvidenceAtomicText $projectionPath (ConvertTo-P0EvidenceJsonText $newProjection)
  return [pscustomobject]@{ ResultCode=$resultCode; ExitCode=0; Projection=[pscustomobject](($newProjection | ConvertTo-Json -Depth 30) | ConvertFrom-Json); Path=$projectionPath; Errors=@() }
}

function Write-P0ResumeSummary {
  param([string]$Session, [object]$Plan, [object]$Projection)
  $state = [string]$Projection.current_state
  $waitingFor = switch ($state) {
    'waiting_agent' { 'agent' }
    'waiting_human' { 'human' }
    'waiting_external' { 'external' }
    'not_invoked' { 'external_authorization_or_degraded_path' }
    'outcome_unknown' { 'external_reconciliation' }
    'cancel_pending_external' { 'external_reconciliation_after_cancel' }
    'failed' { 'repair' }
    'blocked' { 'repair' }
    'attempt_interrupted' { 'retry_policy' }
    default { 'none' }
  }
  $recovery = switch ($state) {
    'completed' { 'none' }
    'waiting_agent' { 'record_agent_result' }
    'waiting_human' { 'record_human_choice' }
    'not_invoked' { 'authorize_external_or_keep_degraded' }
    'outcome_unknown' { 'record_external_reconciliation' }
    'cancel_pending_external' { 'reconcile_external_then_supersede_or_preserve' }
    'attempt_interrupted' { 'start_new_attempt_under_retry_policy' }
    'state_projection_conflict' { 'rebuild_projection' }
    default { 'continue_from_next_step' }
  }
  $message = switch ($state) {
    'completed' { '本 session 已完成；没有待继续步骤。' }
    'waiting_agent' { "已完成前置步骤；正在等待 Agent 完成 $($Projection.next_step_id) 并登记真实产物。" }
    'waiting_human' { "已完成前置步骤；正在等待用户对 $($Projection.next_step_id) 做出明确选择。" }
    'not_invoked' { "外部动作尚未执行；可以授权后继续，或保留诚实降级结果。" }
    'outcome_unknown' { '外部请求结果未知；必须先对账，不能直接重发。' }
    'cancel_pending_external' { '后续步骤已停止，但外部请求已发出；费用和结果需要先对账。' }
    'attempt_interrupted' { '上次确定性执行已中断且没有活动锁；按重试策略创建新 attempt。' }
    default { "可从 $($Projection.next_step_id) 继续。" }
  }
  $summary = [ordered]@{
    schema_id='taoge://schemas/p0/resume-summary/v0.2'
    schema_version='0.2'
    summary_id='RESUME-' + [string]$Plan.session_id
    session_id=[string]$Plan.session_id
    plan_id=[string]$Plan.plan_id
    projection_version=[string]$Projection.projection_version
    projected_through_sequence_no=[int]$Projection.projected_through_sequence_no
    source_event_digest=[string]$Projection.source_event_digest
    current_state=$state
    completed_step_ids=[object[]]@($Projection.completed_step_ids)
    waiting_for=$waitingFor
    next_step_id=$Projection.next_step_id
    non_repeatable_step_ids=[object[]]@($Projection.non_repeatable_step_ids)
    recovery_action=$recovery
    human_message=$message
  }
  $path = Join-Path $Session 'intermediate/p0/resume-summary.json'
  Write-P0EvidenceAtomicText $path (ConvertTo-P0EvidenceJsonText $summary)
  return [pscustomobject](($summary | ConvertTo-Json -Depth 20) | ConvertFrom-Json)
}
