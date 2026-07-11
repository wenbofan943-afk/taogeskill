param(
  [string]$FixturePath = 'examples/p0-h4-evidence-fixture/P0H4FIXTURE-001',
  [string]$ReportPath = 'state/checks/p0-h4-evidence-report.json'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'P0EvidenceRuntime.ps1')

function Resolve-H4Path {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
  return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

function Invoke-H4Command {
  param([string]$Session, [string]$Mode, [string]$InputPath = '')
  $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $PSScriptRoot 'invoke-p0-evidence.ps1'),'-Session',$Session,'-Mode',$Mode)
  if (-not [string]::IsNullOrWhiteSpace($InputPath)) { $arguments += @('-CommandInputPath',$InputPath) }
  $output = & powershell @arguments 2>&1
  $exitCode = $LASTEXITCODE
  return [pscustomobject]@{ ExitCode=$exitCode; Text=[string]::Join("`n", @($output | ForEach-Object { [string]$_ })); Lines=[object[]]@($output) }
}

function Add-H4Check {
  param([System.Collections.Generic.List[object]]$Checks, [string]$CheckId, [bool]$Passed, [string]$Evidence)
  $Checks.Add([ordered]@{ check_id=$CheckId; status=$(if($Passed){'pass'}else{'fail'}); evidence=$Evidence })
}

try {
  $source = Resolve-H4Path $FixturePath
  $workParent = Join-Path $projectRoot 'state/checks/p0-h4-evidence-work'
  $work = Join-Path $workParent 'P0H4FIXTURE-001'
  $expectedPath = Join-Path (Split-Path -Parent $source) 'expected-results.json'
  if (-not (Test-Path -LiteralPath $source) -or -not (Test-Path -LiteralPath $expectedPath)) { throw 'h4_fixture_missing' }
  $resolvedWorkParent = [System.IO.Path]::GetFullPath($workParent)
  $stateChecksRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot 'state/checks'))
  if (-not $resolvedWorkParent.StartsWith($stateChecksRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) { throw 'h4_work_path_outside_state_checks' }
  if (Test-Path -LiteralPath $workParent) { Remove-Item -LiteralPath $workParent -Recurse -Force }
  New-Item -ItemType Directory -Path $workParent -Force | Out-Null
  Copy-Item -LiteralPath $source -Destination $work -Recurse -Force
  $expected = Read-P0JsonFile $expectedPath
  $inputs = Join-Path $work 'command-inputs'
  $reconcileInputPath = Join-Path $inputs 'reconcile-orphan.json'
  $reconcileInput = Read-P0JsonFile $reconcileInputPath
  $reconcileInput.expected_sha256 = Get-P0EvidenceHash (Join-Path $work 'intermediate/p0/orphan-render-input.json')
  [System.IO.File]::WriteAllText($reconcileInputPath, (($reconcileInput | ConvertTo-Json -Depth 20) + "`n"), [System.Text.UTF8Encoding]::new($false))
  $checks = [System.Collections.Generic.List[object]]::new()

  $create = Invoke-H4Command $work 'create_session_plan' (Join-Path $inputs 'create-session-plan.json')
  Add-H4Check $checks 'H4-EVD-001-create-session-plan' ($create.ExitCode -eq 0 -and $create.Text.Contains("P0_EVIDENCE_RESULT=$($expected.expected.create_session_plan)")) $create.Text
  $eventPath = Join-Path $work 'intermediate/p0/execution-events.jsonl'
  $planPath = Join-Path $work 'intermediate/p0/session-execution-plan.json'
  $plan = Read-P0JsonFile $planPath
  Add-H4Check $checks 'H4-EVD-002-plan-contract' (@(Test-P0PlanContract $plan).Count -eq 0) ([string]::Join(';', @(Test-P0PlanContract $plan)))

  $agent = Invoke-H4Command $work 'record_agent_result' (Join-Path $inputs 'record-agent-result.json')
  Add-H4Check $checks 'H4-EVD-003-record-agent-result' ($agent.ExitCode -eq 0 -and $agent.Text.Contains("P0_EVIDENCE_RESULT=$($expected.expected.record_agent_result)")) $agent.Text
  $afterAgentCount = @(Get-P0EvidenceEvents $eventPath).Count
  $agentRepeat = Invoke-H4Command $work 'record_agent_result' (Join-Path $inputs 'record-agent-result.json')
  $afterRepeatCount = @(Get-P0EvidenceEvents $eventPath).Count
  Add-H4Check $checks 'H4-EVD-004-agent-idempotent-reuse' ($agentRepeat.ExitCode -eq 0 -and $agentRepeat.Text.Contains("P0_EVIDENCE_RESULT=$($expected.expected.record_agent_result_repeat)") -and $afterAgentCount -eq $afterRepeatCount) "before=$afterAgentCount;after=$afterRepeatCount;$($agentRepeat.Text)"

  $conflictInputPath = Join-Path $inputs 'record-agent-conflict.json'
  $conflictInput = Read-P0JsonFile (Join-Path $inputs 'record-agent-result.json')
  $conflictInput.safe_summary = '同一幂等 key 的冲突摘要'
  [System.IO.File]::WriteAllText($conflictInputPath, (($conflictInput | ConvertTo-Json -Depth 20) + "`n"), [System.Text.UTF8Encoding]::new($false))
  $agentConflict = Invoke-H4Command $work 'record_agent_result' $conflictInputPath
  Add-H4Check $checks 'H4-EVD-005-agent-idempotency-conflict' ($agentConflict.ExitCode -eq 1 -and $agentConflict.Text.Contains('P0_EVIDENCE_RESULT=idempotency_conflict') -and @(Get-P0EvidenceEvents $eventPath).Count -eq $afterRepeatCount) $agentConflict.Text

  $human = Invoke-H4Command $work 'record_human_choice' (Join-Path $inputs 'record-human-choice.json')
  Add-H4Check $checks 'H4-EVD-006-record-human-choice' ($human.ExitCode -eq 0 -and $human.Text.Contains("P0_EVIDENCE_RESULT=$($expected.expected.record_human_choice)")) $human.Text
  $prefixBeforeReconciliation = Get-Content -LiteralPath $eventPath -Raw -Encoding UTF8

  $reconcile = Invoke-H4Command $work 'reconcile_orphan_artifact' $reconcileInputPath
  Add-H4Check $checks 'H4-EVD-007-reconcile-orphan' ($reconcile.ExitCode -eq 0 -and $reconcile.Text.Contains("P0_EVIDENCE_RESULT=$($expected.expected.reconcile_orphan_artifact)")) $reconcile.Text
  $orphanLineage = Join-Path $work 'deliverables/p0/lineage/RIN-P0H4-001.json'
  $lineageErrors = @()
  if (Test-Path -LiteralPath $orphanLineage) { $lineageErrors = @(Test-P0LineageContract (Read-P0JsonFile $orphanLineage)) } else { $lineageErrors = @('lineage_missing') }
  Add-H4Check $checks 'H4-EVD-008-reconciliation-lineage' ($lineageErrors.Count -eq 0) ([string]::Join(';',$lineageErrors))
  $prefixAfterReconciliation = Get-Content -LiteralPath $eventPath -Raw -Encoding UTF8
  Add-H4Check $checks 'H4-EVD-009-append-only-prefix-preserved' $prefixAfterReconciliation.StartsWith($prefixBeforeReconciliation) "before_length=$($prefixBeforeReconciliation.Length);after_length=$($prefixAfterReconciliation.Length)"

  $externalNotInvoked = Invoke-H4Command $work 'record_external_result' (Join-Path $inputs 'record-external-not-invoked.json')
  Add-H4Check $checks 'H4-EVD-010-external-not-invoked' ($externalNotInvoked.ExitCode -eq 0 -and $externalNotInvoked.Text.Contains("P0_EVIDENCE_RESULT=$($expected.expected.record_external_not_invoked)") -and $externalNotInvoked.Text.Contains('EXTERNAL_NETWORK_INVOKED_BY_TOOL=false')) $externalNotInvoked.Text

  $resumeBefore = Invoke-H4Command $work 'build_resume_summary'
  $resumeBeforeDoc = Read-P0JsonFile (Join-Path $work 'intermediate/p0/resume-summary.json')
  Add-H4Check $checks 'H4-EVD-011-resume-not-invoked' ($resumeBefore.ExitCode -eq 0 -and $resumeBeforeDoc.current_state -eq 'not_invoked') $resumeBefore.Text

  $externalUnknown = Invoke-H4Command $work 'record_external_result' (Join-Path $inputs 'record-external-outcome-unknown.json')
  Add-H4Check $checks 'H4-EVD-012-external-outcome-unknown' ($externalUnknown.ExitCode -eq 0 -and $externalUnknown.Text.Contains("P0_EVIDENCE_RESULT=$($expected.expected.record_external_outcome_unknown)")) $externalUnknown.Text
  $externalSuccess = Invoke-H4Command $work 'record_external_result' (Join-Path $inputs 'record-external-success.json')
  Add-H4Check $checks 'H4-EVD-013-external-success-record-only' ($externalSuccess.ExitCode -eq 0 -and $externalSuccess.Text.Contains("P0_EVIDENCE_RESULT=$($expected.expected.record_external_success)") -and $externalSuccess.Text.Contains('EXTERNAL_NETWORK_INVOKED_BY_TOOL=false')) $externalSuccess.Text

  $events = @(Get-P0EvidenceEvents $eventPath)
  $eventErrors = @(Test-P0EventLogContract $events)
  Add-H4Check $checks 'H4-EVD-014-unified-event-contract' ($eventErrors.Count -eq 0 -and $events.Count -eq [int]$expected.expected.event_count) "count=$($events.Count);errors=$([string]::Join(';',$eventErrors))"
  $stale = Invoke-H4Command $work 'record_external_result' (Join-Path $inputs 'record-stale-append.json')
  Add-H4Check $checks 'H4-EVD-015-expected-tail-conflict' ($stale.ExitCode -eq 1 -and $stale.Text.Contains("P0_EVIDENCE_RESULT=$($expected.expected.stale_append)") -and @(Get-P0EvidenceEvents $eventPath).Count -eq $events.Count) $stale.Text

  $resume = Invoke-H4Command $work 'build_resume_summary'
  $projectionPath = Join-Path $work 'intermediate/p0/state-projection.json'
  $resumePath = Join-Path $work 'intermediate/p0/resume-summary.json'
  $projection = Read-P0JsonFile $projectionPath
  $resumeDoc = Read-P0JsonFile $resumePath
  $projectionFields = @('schema_id','schema_version','projection_version','session_id','plan_id','projected_through_sequence_no','source_event_digest','source_last_recorded_at','current_state','completed_step_ids','waiting_step_id','next_step_id','non_repeatable_step_ids','step_states')
  $resumeFields = @('schema_id','schema_version','summary_id','session_id','plan_id','projection_version','projected_through_sequence_no','source_event_digest','current_state','completed_step_ids','waiting_for','next_step_id','non_repeatable_step_ids','recovery_action','human_message')
  $projectionErrors = @(Test-P0RequiredProperties $projection $projectionFields 'state_projection') + @(Test-P0AllowedProperties $projection $projectionFields 'state_projection')
  $resumeErrors = @(Test-P0RequiredProperties $resumeDoc $resumeFields 'resume_summary') + @(Test-P0AllowedProperties $resumeDoc $resumeFields 'resume_summary')
  Add-H4Check $checks 'H4-EVD-016-projection-and-resume-contract' ($projectionErrors.Count -eq 0 -and $resumeErrors.Count -eq 0 -and $resumeDoc.current_state -eq [string]$expected.expected.resume_state -and @($resumeDoc.non_repeatable_step_ids).Count -eq 2) "state=$($resumeDoc.current_state);projection=$([string]::Join(';',$projectionErrors));resume=$([string]::Join(';',$resumeErrors))"
  Add-H4Check $checks 'H4-EVD-017-projection-rebuilt-from-lag' ($resume.Text.Contains('P0_EVIDENCE_RESULT=resume_summary_built') -and [int]$projection.projected_through_sequence_no -eq $events.Count) $resume.Text

  $projection.source_event_digest = 'sha256:' + ('0' * 64)
  [System.IO.File]::WriteAllText($projectionPath, (($projection | ConvertTo-Json -Depth 30) + "`n"), [System.Text.UTF8Encoding]::new($false))
  $projectionConflict = Invoke-H4Command $work 'build_resume_summary'
  Add-H4Check $checks 'H4-EVD-018-projection-conflict-blocks-resume' ($projectionConflict.ExitCode -eq 1 -and $projectionConflict.Text.Contains("P0_EVIDENCE_RESULT=$($expected.expected.projection_conflict)")) $projectionConflict.Text
  $forceRebuild = Invoke-H4Command $work 'rebuild_projection'
  Add-H4Check $checks 'H4-EVD-019-explicit-projection-rebuild' ($forceRebuild.ExitCode -eq 0 -and $forceRebuild.Text.Contains("P0_EVIDENCE_RESULT=$($expected.expected.projection_force_rebuild)") -and @(Get-ChildItem -LiteralPath (Join-Path $work 'intermediate/p0/quarantine') -Filter 'state-projection-*.json').Count -eq 1) $forceRebuild.Text

  $h2Source = Get-Content -LiteralPath (Join-Path $projectRoot 'tools/P0RuntimeV02.ps1') -Raw -Encoding UTF8
  Add-H4Check $checks 'H4-EVD-020-h2-uses-unified-writer' ($h2Source.Contains('Write-P0EvidenceEvent') -and -not $h2Source.Contains('[System.IO.File]::AppendAllText($EventPath')) 'P0RuntimeV02 routes success events through Write-P0EvidenceEvent'

  $concurrencySession = Join-Path $workParent 'P0H4CONCURRENCY-001'
  $concurrencyInputs = Join-Path $concurrencySession 'command-inputs'
  New-Item -ItemType Directory -Path $concurrencyInputs -Force | Out-Null
  $createConcurrency = [ordered]@{
    schema_id='taoge://commands/p0/evidence-command/v0.2'; schema_version='0.2'; command='create_session_plan';
    plan_id='PLAN-P0H4CONCURRENCY-001'; session_id='P0H4CONCURRENCY-001'; confirmed_single_content=$true;
    steps=@([ordered]@{ step_id='STEP-external'; step_kind='external_side_effect'; produces_artifact_type='external_result'; failure_route='fixture_recovery' });
    idempotency_key='P0H4CONCURRENCY-001:create'; expected_last_sequence_no=0; safe_summary='创建并发写入脱敏测试计划'
  }
  $createConcurrencyPath = Join-Path $concurrencyInputs 'create.json'
  [System.IO.File]::WriteAllText($createConcurrencyPath, (($createConcurrency | ConvertTo-Json -Depth 20) + "`n"), [System.Text.UTF8Encoding]::new($false))
  $createConcurrencyResult = Invoke-H4Command $concurrencySession 'create_session_plan' $createConcurrencyPath
  $writers = @()
  foreach ($suffix in @('a','b')) {
    $request = [ordered]@{
      schema_id='taoge://commands/p0/evidence-command/v0.2'; schema_version='0.2'; command='record_external_result';
      session_id='P0H4CONCURRENCY-001'; step_id='STEP-external'; authorization_status='not_authorized'; invocation_status='not_invoked';
      idempotency_key="P0H4CONCURRENCY-001:writer-$suffix"; expected_last_sequence_no=1; safe_summary="并发 writer $suffix 未执行外部动作"
    }
    $requestPath = Join-Path $concurrencyInputs "writer-$suffix.json"
    [System.IO.File]::WriteAllText($requestPath, (($request | ConvertTo-Json -Depth 20) + "`n"), [System.Text.UTF8Encoding]::new($false))
    $stdout = Join-Path $concurrencySession "writer-$suffix.out.txt"
    $stderr = Join-Path $concurrencySession "writer-$suffix.err.txt"
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $PSScriptRoot 'invoke-p0-evidence.ps1'),'-Session',$concurrencySession,'-Mode','record_external_result','-CommandInputPath',$requestPath)
    $process = Start-Process -FilePath 'powershell' -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $writers += [pscustomobject]@{ Process=$process; Stdout=$stdout; Stderr=$stderr }
  }
  foreach ($writer in $writers) { $writer.Process.WaitForExit() }
  $writerResults = @($writers | ForEach-Object { (Get-Content -LiteralPath $_.Stdout -Raw -Encoding UTF8) + (Get-Content -LiteralPath $_.Stderr -Raw -Encoding UTF8) })
  $successCount = @($writerResults | Where-Object { $_ -match 'P0_EVIDENCE_RESULT=external_not_invoked_recorded' }).Count
  $conflictCount = @($writerResults | Where-Object { $_ -match 'P0_EVIDENCE_RESULT=concurrent_append_conflict' }).Count
  $concurrencyEventCount = @(Get-P0EvidenceEvents (Join-Path $concurrencySession 'intermediate/p0/execution-events.jsonl')).Count
  Add-H4Check $checks 'H4-EVD-021-real-concurrent-append' ($createConcurrencyResult.ExitCode -eq 0 -and $successCount -eq 1 -and $conflictCount -eq 1 -and $concurrencyEventCount -eq 2) "success=$successCount;conflict=$conflictCount;events=$concurrencyEventCount;$([string]::Join('|',$writerResults))"

  $failed = @($checks | Where-Object { $_.status -eq 'fail' })
  $report = [ordered]@{
    schema_id='taoge://reports/p0-h4-evidence/v0.2'
    schema_version='0.2'
    checker_version='validate-p0-h4-evidence-v0.2'
    generated_at=[DateTimeOffset]::UtcNow.ToString('o')
    result=$(if($failed.Count){'fail'}else{'pass'})
    check_count=$checks.Count
    pass_count=@($checks | Where-Object { $_.status -eq 'pass' }).Count
    fail_count=$failed.Count
    checks=[object[]]$checks.ToArray()
    not_tested_scope=@('real_accounts','real_images','external_network','publishing','multi_content_parallel')
  }
  $reportFile = Resolve-H4Path $ReportPath
  $reportParent = Split-Path -Parent $reportFile
  if (-not (Test-Path -LiteralPath $reportParent)) { New-Item -ItemType Directory -Path $reportParent -Force | Out-Null }
  [System.IO.File]::WriteAllText($reportFile, (($report | ConvertTo-Json -Depth 20) + "`n"), [System.Text.UTF8Encoding]::new($false))
  foreach ($check in $checks) { Write-Output "$($check.check_id) $($check.status) $($check.evidence)" }
  Write-Output "P0_H4_EVIDENCE_CHECK=$($report.result)"
  Write-Output "P0_H4_CHECK_COUNT=$($report.check_count)"
  Write-Output "P0_H4_REPORT=$ReportPath"
  if ($failed.Count) { exit 1 }
  exit 0
} catch {
  Write-Error ("P0_H4_CHECKER_ERROR=" + $_.Exception.Message)
  exit 3
}
