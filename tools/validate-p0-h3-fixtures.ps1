param(
  [string]$FixtureRoot = 'examples/p0-h3-recovery-fixtures',
  [string]$ReportPath = 'state/checks/p0-h3-fixture-report.json'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'P0RuntimeV02.ps1')

function Resolve-P0H3ProjectPath {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
  return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

function Read-P0H3Events {
  param([string]$Path)
  $items = [System.Collections.Generic.List[object]]::new()
  foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $items.Add(($line | ConvertFrom-Json))
  }
  return [object[]]$items.ToArray()
}

function Add-P0H3Assertion {
  param(
    [System.Collections.Generic.List[object]]$Assertions,
    [System.Collections.Generic.List[string]]$Errors,
    [string]$AssertionId,
    [bool]$Passed,
    [string]$Evidence
  )
  $Assertions.Add([ordered]@{ assertion_id=$AssertionId; passed=$Passed; evidence=$Evidence })
  if (-not $Passed) { $Errors.Add("assertion_failed:$AssertionId") }
}

function Test-P0H3BaseDocument {
  param([object]$Document, [string]$FixtureId, [string]$Kind)
  $errors = [System.Collections.Generic.List[string]]::new()
  $required = switch ($Kind) {
    'case' { @('schema_id','schema_version','fixture_id','scenario','plan_path','events_path','state_path','expected_result_path','checker_entry') }
    'state' { @('schema_id','schema_version','fixture_id') }
    'expected' { @('schema_id','schema_version','fixture_id','expected_state','failure_category','resume_advice') }
  }
  foreach ($error in (Test-P0RequiredProperties $Document $required "h3_$Kind")) { $errors.Add($error) }
  if ($Document.fixture_id -ne $FixtureId) { $errors.Add("h3_${Kind}_fixture_id_mismatch") }
  if ($Document.schema_version -ne '0.2') { $errors.Add("h3_${Kind}_version_invalid") }
  return [object[]]$errors.ToArray()
}

function Get-P0H3CompatibilityEntry {
  param([string]$FromVersion)
  $matrix = Read-P0JsonFile (Join-Path $projectRoot 'templates/schema/p0/compatibility-matrix.v0.2.json')
  return @($matrix.entries | Where-Object { $_.from_version -eq $FromVersion -and $_.to_version -eq 'p0-single-runtime-v0.2' }) | Select-Object -First 1
}

function Invoke-P0H3Case {
  param([string]$CasePath)
  $caseDirectory = Split-Path -Parent $CasePath
  $fixture = Read-P0JsonFile $CasePath
  $fixtureId = [string]$fixture.fixture_id
  $assertions = [System.Collections.Generic.List[object]]::new()
  $errors = [System.Collections.Generic.List[string]]::new()

  foreach ($error in (Test-P0H3BaseDocument $fixture $fixtureId 'case')) { $errors.Add($error) }
  foreach ($property in @('plan_path','events_path','state_path','expected_result_path')) {
    $relative = [string]$fixture.$property
    $safe = Test-P0RelativePath $relative
    Add-P0H3Assertion $assertions $errors "independent_$property" $safe $relative
    if (-not $safe) { continue }
    $resolved = [System.IO.Path]::GetFullPath((Join-Path $caseDirectory $relative))
    $inside = $resolved.StartsWith(([System.IO.Path]::GetFullPath($caseDirectory).TrimEnd('\') + '\'), [System.StringComparison]::OrdinalIgnoreCase)
    Add-P0H3Assertion $assertions $errors "contained_$property" $inside $resolved
    Add-P0H3Assertion $assertions $errors "exists_$property" (Test-Path -LiteralPath $resolved) $resolved
  }

  $planPath = Join-Path $caseDirectory ([string]$fixture.plan_path)
  $eventsPath = Join-Path $caseDirectory ([string]$fixture.events_path)
  $statePath = Join-Path $caseDirectory ([string]$fixture.state_path)
  $expectedPath = Join-Path $caseDirectory ([string]$fixture.expected_result_path)
  $plan = Read-P0JsonFile $planPath
  $events = @(Read-P0H3Events $eventsPath)
  $state = Read-P0JsonFile $statePath
  $expected = Read-P0JsonFile $expectedPath
  foreach ($error in (Test-P0H3BaseDocument $state $fixtureId 'state')) { $errors.Add($error) }
  foreach ($error in (Test-P0H3BaseDocument $expected $fixtureId 'expected')) { $errors.Add($error) }

  $isLegacy = (Test-P0HasProperty $plan 'workflow_version') -and $plan.workflow_version -eq 'p0-runtime-v0.1'
  if ($isLegacy) {
    $planValid = $plan.session_id -eq "$fixtureId-FIXTURE" -and @($plan.steps).Count -gt 0
    Add-P0H3Assertion $assertions $errors 'legacy_plan_minimum_contract' $planValid ([string]$plan.workflow_version)
  } else {
    $planErrors = @(Test-P0PlanContract $plan)
    Add-P0H3Assertion $assertions $errors 'v0_2_plan_contract' ($planErrors.Count -eq 0) ([string]::Join(';', $planErrors))
    Add-P0H3Assertion $assertions $errors 'plan_session_matches_fixture' ($plan.session_id -eq "$fixtureId-FIXTURE") ([string]$plan.session_id)
  }

  $eventErrors = @(Test-P0EventLogContract $events)
  if ($fixtureId -eq 'P0-F11') {
    Add-P0H3Assertion $assertions $errors 'invalid_event_history_detected' (@($eventErrors | Where-Object { $_ -like 'event_sequence_conflict:*' -or $_ -like 'event_previous_invalid:*' }).Count -gt 0) ([string]::Join(';', $eventErrors))
  } else {
    Add-P0H3Assertion $assertions $errors 'event_log_contract' ($eventErrors.Count -eq 0) ([string]::Join(';', $eventErrors))
    if (-not $isLegacy) {
      $planEventErrors = @(Test-P0V2PlanEvents $plan $events)
      Add-P0H3Assertion $assertions $errors 'plan_event_contract' ($planEventErrors.Count -eq 0) ([string]::Join(';', $planEventErrors))
    }
  }

  $actualState = 'undetermined'
  $failureCategory = 'checker_defect'
  $resumeAdvice = 'inspect_fixture'
  switch ($fixtureId) {
    'P0-F03' {
      $waiting = @($events | Where-Object { $_.step_id -eq 'STEP-draft' -and $_.state_after -eq 'waiting_agent' }).Count -eq 1
      $completed = @($events | Where-Object { $_.step_id -eq 'STEP-draft' -and $_.state_after -eq 'succeeded' }).Count -gt 0
      Add-P0H3Assertion $assertions $errors 'agent_waiting_without_success' ($waiting -and -not $completed) "waiting=$waiting;completed=$completed"
      Add-P0H3Assertion $assertions $errors 'no_false_final_delivery' ($state.final_delivery_status -eq 'absent') ([string]$state.final_delivery_status)
      $actualState='waiting_agent'; $failureCategory='not_failure'; $resumeAdvice='record_agent_result'
    }
    'P0-F04' {
      $waiting = @($events | Where-Object { $_.step_id -eq 'STEP-topic-gate' -and $_.state_after -eq 'waiting_human' }).Count -eq 1
      Add-P0H3Assertion $assertions $errors 'human_gate_not_skipped' ($waiting -and -not [bool]$state.human_choice_recorded) "waiting=$waiting;recorded=$($state.human_choice_recorded)"
      Add-P0H3Assertion $assertions $errors 'resume_cursor_stays_at_gate' ($state.expected_resume_step_id -eq 'STEP-topic-gate') ([string]$state.expected_resume_step_id)
      $actualState='waiting_human'; $failureCategory='not_failure'; $resumeAdvice='record_human_choice'
    }
    'P0-F05' {
      $notInvoked = @($events | Where-Object { $_.step_id -eq 'STEP-image-provider' -and $_.state_after -eq 'not_invoked' }).Count -eq 1
      Add-P0H3Assertion $assertions $errors 'external_not_invoked_without_authorization' ($notInvoked -and -not [bool]$state.external_authorized -and -not [bool]$state.provider_request_sent) "event=$notInvoked"
      Add-P0H3Assertion $assertions $errors 'honest_html_degradation' ($state.html_asset_representation -eq 'honest_degraded') ([string]$state.html_asset_representation)
      $actualState='not_invoked'; $failureCategory='not_failure'; $resumeAdvice='request_external_authorization_or_keep_degraded'
    }
    'P0-F06' {
      $htmlPath = Join-Path $caseDirectory 'deliverables/final-delivery.html'
      $missingPath = Join-Path (Split-Path -Parent $htmlPath) ([string]$state.broken_reference)
      $failedEvent = @($events | Where-Object { $_.step_id -eq 'STEP-render' -and $_.state_after -eq 'failed' }).Count -eq 1
      Add-P0H3Assertion $assertions $errors 'broken_reference_reproduced' ((Test-Path -LiteralPath $htmlPath) -and -not (Test-Path -LiteralPath $missingPath)) ([string]$state.broken_reference)
      Add-P0H3Assertion $assertions $errors 'render_failed_manifest_blocked' ($failedEvent -and $state.manifest_final_delivery_status -eq 'blocked') "failed=$failedEvent;manifest=$($state.manifest_final_delivery_status)"
      $actualState='failed'; $failureCategory='deterministic_tool_defect'; $resumeAdvice='repair_local_resource_then_render'
    }
    'P0-F07' {
      $compat = Get-P0H3CompatibilityEntry 'p0-runtime-v0.1'
      Add-P0H3Assertion $assertions $errors 'legacy_replay_only' ($null -ne $compat -and $compat.replay_readable -and -not $compat.resume_executable -and -not [bool]$state.history_mutation_allowed) "assist=$($state.agent_assist_level)"
      Add-P0H3Assertion $assertions $errors 'legacy_assist_level_preserved' ($state.agent_assist_level -eq 'high') ([string]$state.agent_assist_level)
      $actualState='legacy_evidence_replay'; $failureCategory='compatibility_boundary'; $resumeAdvice='start_new_v0_2_session_for_resume'
    }
    'P0-F08' {
      $conflict = $state.checkpoint.next_step_id -ne $state.derived_next_step_id
      Add-P0H3Assertion $assertions $errors 'checkpoint_event_cursor_conflict' $conflict "checkpoint=$($state.checkpoint.next_step_id);derived=$($state.derived_next_step_id)"
      Add-P0H3Assertion $assertions $errors 'resume_rejected' (-not [bool]$state.resume_allowed) ([string]$state.resume_allowed)
      $actualState='workflow_contract_defect'; $failureCategory='workflow_contract_defect'; $resumeAdvice='repair_checkpoint_projection_before_resume'
    }
    'P0-F09' {
      $attempts=@($state.submission_attempts); $same=$attempts.Count -eq 2 -and $attempts[0].idempotency_key -eq $attempts[1].idempotency_key -and $attempts[0].payload_digest -eq $attempts[1].payload_digest
      Add-P0H3Assertion $assertions $errors 'duplicate_payload_identical' $same "attempts=$($attempts.Count)"
      Add-P0H3Assertion $assertions $errors 'single_terminal_and_side_effect' ([int]$state.terminal_event_count -eq 1 -and [int]$state.side_effect_count -eq 1) "terminal=$($state.terminal_event_count);side_effect=$($state.side_effect_count)"
      $actualState='duplicate_reused'; $failureCategory='not_failure'; $resumeAdvice='reuse_existing_terminal_result'
    }
    'P0-F10' {
      $attempts=@($state.submission_attempts); $conflict=$attempts.Count -eq 2 -and $attempts[0].idempotency_key -eq $attempts[1].idempotency_key -and $attempts[0].payload_digest -ne $attempts[1].payload_digest
      Add-P0H3Assertion $assertions $errors 'idempotency_payload_conflict' $conflict "attempts=$($attempts.Count)"
      Add-P0H3Assertion $assertions $errors 'conflicting_attempt_not_appended' (-not [bool]$state.second_attempt_appended) ([string]$state.second_attempt_appended)
      $actualState='idempotency_conflict'; $failureCategory='workflow_contract_defect'; $resumeAdvice='issue_new_key_only_after_input_decision'
    }
    'P0-F11' {
      $sequenceConflict=@($eventErrors | Where-Object { $_ -like 'event_sequence_conflict:*' }).Count -gt 0
      Add-P0H3Assertion $assertions $errors 'sequence_conflict_blocks_projection' ($sequenceConflict -and -not [bool]$state.projection_allowed -and -not [bool]$state.resume_allowed) ([string]::Join(';',$eventErrors))
      $actualState='event_sequence_conflict'; $failureCategory='workflow_contract_defect'; $resumeAdvice='repair_event_history_before_projection_or_resume'
    }
    'P0-F12' {
      $artifact=$state.artifacts[0]; $artifactPath=Join-Path $caseDirectory ([string]$artifact.relative_path)
      $hasMaterialization=@($events | Where-Object { $_.event_type -like 'artifact.materialized.*' -and @($_.output_artifact_ids) -contains $artifact.artifact_id }).Count -gt 0
      Add-P0H3Assertion $assertions $errors 'orphan_file_exists_without_event' ((Test-Path -LiteralPath $artifactPath) -and -not $hasMaterialization -and $null -eq $artifact.materialization_event_id) $artifactPath
      Add-P0H3Assertion $assertions $errors 'orphan_requires_reconciliation' ([bool]$state.reconciliation_required) ([string]$state.reconciliation_required)
      $actualState='orphan_artifact_detected'; $failureCategory='artifact_contract_defect'; $resumeAdvice='reconcile_or_quarantine_orphan_artifact'
    }
    'P0-F13' {
      $artifact=$state.artifacts[0]; $artifactPath=Join-Path $caseDirectory ([string]$artifact.relative_path)
      $success=@($events | Where-Object { $_.state_after -eq 'succeeded' -and @($_.output_artifact_ids) -contains $artifact.artifact_id }).Count -eq 1
      Add-P0H3Assertion $assertions $errors 'succeeded_artifact_missing' ($success -and -not (Test-Path -LiteralPath $artifactPath)) $artifactPath
      Add-P0H3Assertion $assertions $errors 'integrity_failure_blocks_downstream' (-not [bool]$state.downstream_allowed) ([string]$state.downstream_allowed)
      $actualState='artifact_integrity_failed'; $failureCategory='artifact_contract_defect'; $resumeAdvice='restore_or_rebuild_artifact_before_downstream'
    }
    'P0-F14' {
      $unknown=@($events | Where-Object { $_.state_after -eq 'outcome_unknown' -and $_.failure.retryability -eq 'reconcile_first' }).Count -eq 1
      Add-P0H3Assertion $assertions $errors 'unknown_outcome_requires_reconciliation' ($unknown -and [bool]$state.reconciliation_required) "event=$unknown"
      Add-P0H3Assertion $assertions $errors 'unknown_outcome_not_blindly_retried' ([bool]$state.external_request.sent -and -not [bool]$state.external_request.response_received -and -not [bool]$state.external_request.retry_sent) ([string]$state.external_request.request_id)
      $actualState='outcome_unknown'; $failureCategory='external_provider_uncertain'; $resumeAdvice='reconcile_external_request_before_retry'
    }
    'P0-F15' {
      $compat=Get-P0H3CompatibilityEntry ([string]$state.from_version)
      $matches=$null -ne $compat -and $compat.replay_readable -eq $state.compatibility_expectation.replay_readable -and $compat.resume_executable -eq $state.compatibility_expectation.resume_executable -and $compat.migration_required -eq $state.compatibility_expectation.migration_required
      Add-P0H3Assertion $assertions $errors 'compatibility_matrix_applied' $matches "from=$($state.from_version);to=$($state.to_version)"
      $actualState='legacy_evidence_replay'; $failureCategory='compatibility_boundary'; $resumeAdvice='start_new_v0_2_session_for_resume'
    }
    'P0-F16' {
      $asset=$state.asset; $assetPath=Join-Path $caseDirectory ([string]$asset.relative_path)
      $digestMismatch=$asset.source_content_digest -ne $asset.current_content_digest -or $asset.source_beat_digest -ne $asset.current_beat_digest
      Add-P0H3Assertion $assertions $errors 'reuse_digest_mismatch_detected' ((Test-Path -LiteralPath $assetPath) -and $asset.asset_status_claim -eq 'reused_verified' -and $digestMismatch) $assetPath
      Add-P0H3Assertion $assertions $errors 'ineligible_reuse_blocks_delivery' (-not [bool]$state.delivery_allowed) ([string]$state.delivery_allowed)
      $actualState='reused_asset_ineligible'; $failureCategory='artifact_contract_defect'; $resumeAdvice='back_to_image_preparation'
    }
    'P0-F17' {
      $attempts=@($state.append_attempts); $winner=@($attempts | Where-Object { $_.result -eq 'appended' }).Count; $loser=@($attempts | Where-Object { $_.result -eq 'concurrent_append_conflict' }).Count
      Add-P0H3Assertion $assertions $errors 'single_writer_wins' ($winner -eq 1 -and $loser -eq 1 -and [int]$state.lost_event_count -eq 0) "winner=$winner;conflict=$loser"
      Add-P0H3Assertion $assertions $errors 'event_tail_preserved' (@($events).Count -eq 2 -and [int]$events[-1].sequence_no -eq [int]$state.event_tail_sequence_no) ([string]$state.event_tail_sequence_no)
      $actualState='concurrent_append_conflict'; $failureCategory='workflow_contract_defect'; $resumeAdvice='reload_event_tail_before_append'
    }
    'P0-F18' {
      $attempt=$state.execution_attempt; $started=@($events | Where-Object { $_.event_type -eq 'step.started.v1' -and $_.state_after -eq 'running' }).Count -eq 1
      $interrupted=$started -and -not [bool]$attempt.active_run_lock -and -not [bool]$attempt.terminal_event_present -and -not [bool]$attempt.official_artifact_present -and -not [bool]$attempt.temporary_artifact_present
      Add-P0H3Assertion $assertions $errors 'interrupted_attempt_detected' $interrupted ([string]$attempt.execution_attempt_id)
      Add-P0H3Assertion $assertions $errors 'resume_not_stuck_running' ([bool]$state.resume_must_not_remain_running) ([string]$state.resume_must_not_remain_running)
      $actualState='attempt_interrupted'; $failureCategory='transient_environment'; $resumeAdvice='start_new_attempt_under_retry_policy'
    }
    'P0-F19' {
      $pending=@($events | Where-Object { $_.state_after -eq 'cancel_pending_external' }).Count -eq 1
      Add-P0H3Assertion $assertions $errors 'cancel_waits_for_external_reconciliation' ($pending -and [bool]$state.external_request.sent -and $state.external_request.outcome -eq 'pending') ([string]$state.external_request.request_id)
      Add-P0H3Assertion $assertions $errors 'cancel_preserves_cost_and_history' ([bool]$state.external_request.cost_may_have_occurred -and [bool]$state.cancel.history_preserved -and $state.cancel.artifact_policy -eq 'preserve_trace') ([string]$state.cancel.artifact_policy)
      $actualState='cancel_pending_external'; $failureCategory='not_failure'; $resumeAdvice='reconcile_external_then_supersede_or_preserve'
    }
    default { $errors.Add("unknown_fixture_id:$fixtureId") }
  }

  Add-P0H3Assertion $assertions $errors 'expected_state_matches' ($actualState -eq $expected.expected_state) "expected=$($expected.expected_state);actual=$actualState"
  Add-P0H3Assertion $assertions $errors 'failure_category_matches' ($failureCategory -eq $expected.failure_category) "expected=$($expected.failure_category);actual=$failureCategory"
  Add-P0H3Assertion $assertions $errors 'resume_advice_matches' ($resumeAdvice -eq $expected.resume_advice) "expected=$($expected.resume_advice);actual=$resumeAdvice"
  return [ordered]@{
    schema_id='taoge://schemas/p0/h3-fixture-result/v0.2'
    schema_version='0.2'
    fixture_id=$fixtureId
    expected_state=[string]$expected.expected_state
    actual_state=$actualState
    failure_category=$failureCategory
    resume_advice=$resumeAdvice
    fixture_result=$(if ($errors.Count -eq 0) { 'pass' } else { 'fail' })
    assertion_results=[object[]]$assertions.ToArray()
    errors=[object[]]$errors.ToArray()
  }
}

try {
  $fixtureRootPath = Resolve-P0H3ProjectPath $FixtureRoot
  $indexPath = Join-Path $fixtureRootPath 'fixtures.json'
  if (-not (Test-Path -LiteralPath $indexPath)) { throw "fixture_index_missing:$indexPath" }
  $index = Read-P0JsonFile $indexPath
  $expectedIds = 3..19 | ForEach-Object { 'P0-F' + $_.ToString('00') }
  $actualIds = @($index.cases | ForEach-Object { [string]$_.fixture_id })
  if (@($actualIds | Sort-Object -Unique).Count -ne 17 -or @($expectedIds | Where-Object { $_ -notin $actualIds }).Count -gt 0) { throw 'fixture_index_must_cover_p0_f03_to_f19_once' }

  $results = [System.Collections.Generic.List[object]]::new()
  foreach ($entry in @($index.cases | Sort-Object fixture_id)) {
    $casePath = [System.IO.Path]::GetFullPath((Join-Path $fixtureRootPath ([string]$entry.path)))
    if (-not $casePath.StartsWith($fixtureRootPath.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) { throw "fixture_case_path_escape:$($entry.fixture_id)" }
    $results.Add((Invoke-P0H3Case $casePath))
  }
  $failed = @($results | Where-Object { $_.fixture_result -ne 'pass' })
  $report = [ordered]@{
    schema_id='taoge://reports/p0-h3-fixture-suite/v0.2'
    schema_version='0.2'
    fixture_suite_id=[string]$index.fixture_suite_id
    checker_version='validate-p0-h3-fixtures-v0.2'
    generated_at=[DateTimeOffset]::UtcNow.ToString('o')
    result=$(if ($failed.Count -eq 0) { 'pass' } else { 'fail' })
    fixture_count=$results.Count
    pass_count=@($results | Where-Object { $_.fixture_result -eq 'pass' }).Count
    fail_count=$failed.Count
    fixture_results=[object[]]$results.ToArray()
    not_tested_scope=@('real_accounts','real_images','external_api','multi_content_parallel','publishing','p0_h4_commands')
  }
  $reportFile = Resolve-P0H3ProjectPath $ReportPath
  $reportParent = Split-Path -Parent $reportFile
  if (-not (Test-Path -LiteralPath $reportParent)) { New-Item -ItemType Directory -Path $reportParent -Force | Out-Null }
  [System.IO.File]::WriteAllText($reportFile, (($report | ConvertTo-Json -Depth 20) + "`n"), [System.Text.UTF8Encoding]::new($false))
  foreach ($item in $results) { Write-Output ("{0} {1} expected={2} actual={3} category={4} resume={5}" -f $item.fixture_id,$item.fixture_result,$item.expected_state,$item.actual_state,$item.failure_category,$item.resume_advice) }
  Write-Output ("P0_H3_FIXTURE_CHECK={0}" -f $report.result)
  Write-Output ("P0_H3_FIXTURE_COUNT={0}" -f $report.fixture_count)
  Write-Output ("P0_H3_FIXTURE_REPORT={0}" -f $ReportPath)
  if ($failed.Count -gt 0) { exit 1 }
  exit 0
} catch {
  Write-Error ("P0_H3_CHECKER_ERROR=" + $_.Exception.Message)
  exit 3
}
