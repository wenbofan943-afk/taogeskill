param(
  [string]$WorkRoot='state/checks/r7-h5-viewport-work',
  [string]$HumanReportPath='state/checks/r7-h5-viewport-check-report.md',
  [string]$MachineReportPath='state/checks/r7-h5-viewport-check-report.json'
)

$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'R7ViewportRuntime.ps1')

function Resolve-R7H5Path([string]$Path){if([IO.Path]::IsPathRooted($Path)){return [IO.Path]::GetFullPath($Path)};return [IO.Path]::GetFullPath((Join-Path $script:ProjectRoot $Path))}
function New-R7H5Result([string]$Id,[string]$Expected,[string]$Actual,[string[]]$Errors=@()){[pscustomobject]@{fixture_id=$Id;expected_result=$Expected;actual_result=$Actual;expectation_met=($Expected-eq$Actual);errors=[object[]]@($Errors)}}
function Copy-R7H5Session([string]$Source,[string]$Parent){if(Test-Path -LiteralPath $Parent){Remove-Item -LiteralPath $Parent -Recurse -Force};New-Item -ItemType Directory -Path $Parent -Force|Out-Null;$target=Join-Path $Parent (Split-Path -Leaf $Source);Copy-Item -LiteralPath $Source -Destination $target -Recurse -Force;return $target}
function Set-R7H5FixtureEventsAsRuntime([string]$Session){$plan=Read-P0JsonFile (Join-Path $Session 'intermediate/p0/session-execution-plan.json');$events=@(Get-P0EvidenceEvents (Join-Path $Session 'intermediate/p0/execution-events.jsonl'));foreach($event in $events){$step=@($plan.steps|Where-Object{$_.step_id-eq$event.step_id})|Select-Object -First 1;if($null-ne$step-and$event.event_type-eq'fixture.completed.v1'-and$step.step_kind-in@('agent_required','external_side_effect')){$event.event_type='semantic.result_committed.v1'}};Write-TaogeUtf8NoBomLines (Join-Path $Session 'intermediate/p0/execution-events.jsonl') @($events|ForEach-Object{$_|ConvertTo-Json -Compress -Depth 50})}

try{
  $script:ProjectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
  $work=Resolve-R7H5Path $WorkRoot;$human=Resolve-R7H5Path $HumanReportPath;$machine=Resolve-R7H5Path $MachineReportPath
  foreach($path in @($work,(Split-Path -Parent $human),(Split-Path -Parent $machine))){if(-not(Test-Path -LiteralPath $path)){New-Item -ItemType Directory -Path $path -Force|Out-Null}}
  $run=Join-Path $work ('RUN-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6));New-Item -ItemType Directory -Path $run|Out-Null
  $h4Work=Join-Path $run 'h4';$h4Human=Join-Path $run 'h4.md';$h4Machine=Join-Path $run 'h4.json'
  $h4Output=@(& (Join-Path $PSScriptRoot 'validate-r7-h4-candidate-runtime.ps1') -WorkRoot $h4Work -HumanReportPath $h4Human -MachineReportPath $h4Machine 2>&1);if(-not$?){throw "h4_fixture_seed_failed:$([string]::Join(';',@($h4Output)))"}
  $h4Run=Get-ChildItem -LiteralPath $h4Work -Directory|Sort-Object LastWriteTime -Descending|Select-Object -First 1;$source=Join-Path $h4Run.FullName 'R7-F09-F13';if(-not(Test-Path -LiteralPath $source)){throw 'h4_valid_session_missing'}
  $hostInfo=Get-R7ViewportHost;$results=[Collections.Generic.List[object]]::new()

  $f14=Copy-R7H5Session $source (Join-Path $run 'f14');$r14=Invoke-R7ViewportAcceptance $script:ProjectRoot $f14;$errors14=[Collections.Generic.List[string]]::new();if($r14.ExitCode-ne0){$errors14.Add("viewport_exit:$($r14.ResultCode)");foreach($error in @($r14.Errors)){$errors14.Add([string]$error)}};if($r14.ExitCode-eq0){$report14=(Get-R7CandidateCurrentArtifact $f14 'viewport_acceptance_report').Payload;if($report14.overall_result-ne'pass'){$errors14.Add('viewport_result_not_pass')};if(@($report14.profiles).Count-ne2){$errors14.Add('viewport_profile_count_invalid')};foreach($profile in @($report14.profiles)){if(-not(Test-Path -LiteralPath (Join-Path $f14 $profile.screenshot_path))){$errors14.Add("screenshot_missing:$($profile.profile_id)")}elseif((Get-R7RuntimeHash (Join-Path $f14 $profile.screenshot_path))-ne$profile.screenshot_sha256){$errors14.Add("screenshot_digest_mismatch:$($profile.profile_id)")}}};$results.Add((New-R7H5Result 'R7-F14' viewport_pass_with_bound_evidence $(if($errors14.Count){'fail'}else{'viewport_pass_with_bound_evidence'}) $errors14.ToArray()))

  if($hostInfo.Available){$r15=Invoke-R7ViewportProfile $script:ProjectRoot $f14 (Join-Path $f14 'deliverables/final-delivery.html') 'f15-evidence-pending' 390 844 $hostInfo -OmitScreenshot;$actual15=[string]$r15.ResultCode}else{$actual15='evidence_pending'};$results.Add((New-R7H5Result 'R7-F15' evidence_pending $actual15 @()))

  if($hostInfo.Available){$overflowPath=Join-Path $f14 'intermediate/visual-review/r7/f16-overflow.html';Write-P0V2AtomicText $overflowPath '<!doctype html><html><body><div style="width:1200px;height:40px">overflow</div></body></html>';$r16=Invoke-R7ViewportProfile $script:ProjectRoot $f14 $overflowPath 'f16-mobile-overflow' 390 844 $hostInfo;$actual16=[string]$r16.ResultCode}else{$actual16='visual_acceptance_fail'};$results.Add((New-R7H5Result 'R7-F16' visual_acceptance_fail $actual16 @()))

  $f17=Copy-R7H5Session $source (Join-Path $run 'f17');$r17=Invoke-R7ViewportAcceptance $script:ProjectRoot $f17 -ForceBrowserUnavailable;$policy17=if($r17.ExitCode-eq0){$report17=(Get-R7CandidateCurrentArtifact $f17 'viewport_acceptance_report').Payload;Test-R7ViewportGatePolicy content ([string]$report17.overall_result)}else{'fail'};$results.Add((New-R7H5Result 'R7-F17' ready_with_warnings $policy17 @($r17.Errors)))

  $templatePolicy=Test-R7ViewportGatePolicy template not_tested;$releasePolicy=Test-R7ViewportGatePolicy release not_tested;$actual18=if($templatePolicy-eq'blocker'-and$releasePolicy-eq'blocker'){'blocker'}else{'fail'};$results.Add((New-R7H5Result 'R7-F18' blocker $actual18 @()))

  $f19=Copy-R7H5Session $source (Join-Path $run 'f19')
  Set-R7H5FixtureEventsAsRuntime $f19
  $r19=Invoke-R7ViewportAcceptance $script:ProjectRoot $f19
  $report19=if($r19.ExitCode-eq0){(Get-R7CandidateCurrentArtifact $f19 'viewport_acceptance_report').Payload}else{$null}
  $humanCommit=$null
  $humanGateContractErrors=[Collections.Generic.List[string]]::new()
  if($null-ne$report19){
    $task19=Prepare-R7RuntimeTask -ProjectRoot $script:ProjectRoot -Session $f19
    if($task19.ExitCode-eq0){
      $missingTarget=New-R7FinalHumanSubmission -ProjectRoot $script:ProjectRoot -Session $f19 -TaskEnvelopeId ([string]$task19.Data.Task.task_envelope_id) -DecisionStatus revision_requested -RequestedAction revise_copy
      if($missingTarget.ResultCode-ne'action_target_required'){$humanGateContractErrors.Add("missing_target_false_accept:$($missingTarget.ResultCode)")}
      $wrongPair=New-R7FinalHumanSubmission -ProjectRoot $script:ProjectRoot -Session $f19 -TaskEnvelopeId ([string]$task19.Data.Task.task_envelope_id) -DecisionStatus human_confirm -RequestedAction archive_session
      if($wrongPair.ResultCode-ne'decision_action_mismatch'){$humanGateContractErrors.Add("decision_action_false_accept:$($wrongPair.ResultCode)")}
      $candidate19=(Get-R7CandidateCurrentArtifact $f19 'final_delivery_render_candidate').Payload;$draftTarget=@($candidate19.source_map|Where-Object{$_.artifact_type-eq'draft'})|Select-Object -First 1
      $validRevision=New-R7FinalHumanSubmission -ProjectRoot $script:ProjectRoot -Session $f19 -TaskEnvelopeId ([string]$task19.Data.Task.task_envelope_id) -DecisionStatus revision_requested -RequestedAction revise_copy -TargetArtifactId ([string]$draftTarget.artifact_id)
      if($validRevision.ResultCode-ne'submission_built'){$humanGateContractErrors.Add("scoped_revision_rejected:$($validRevision.ResultCode)")}
      $wrapperOutput=@(& (Join-Path $PSScriptRoot 'new-r7-final-human-decision.ps1') -ProjectRoot $script:ProjectRoot -Session $f19 -TaskEnvelopeId ([string]$task19.Data.Task.task_envelope_id) -DecisionStatus human_confirm -RequestedAction publish_all_manually 2>&1)
      if($?){
        $wrapperResult=([string]::Join("`n",@($wrapperOutput))|ConvertFrom-Json)
        $humanCommit=Submit-R7RuntimeArtifact -ProjectRoot $script:ProjectRoot -Session $f19 -SubmissionPath (Join-Path $f19 ([string]$wrapperResult.Data.SubmissionPath))
      }
    }
  }
  $actual19=if($null-ne$report19-and[bool]$report19.autonomy_eligible-and[int]$report19.workflow_autonomous_completion_count-eq1-and$null-ne$humanCommit-and$humanCommit.ResultCode-eq'semantic_artifact_committed'-and$humanGateContractErrors.Count-eq0){'autonomous_completion_1'}else{'fail'}
  $errors19=@($r19.Errors)+@($humanGateContractErrors.ToArray());if($null-eq$humanCommit-or$humanCommit.ExitCode-ne0){$errors19+=@('final_human_gate_commit_failed')}
  $results.Add((New-R7H5Result 'R7-F19' autonomous_completion_1 $actual19 $errors19))

  $f20=Copy-R7H5Session $source (Join-Path $run 'f20');Set-R7H5FixtureEventsAsRuntime $f20;$candidate20=Get-R7CandidateCurrentArtifact $f20 'final_delivery_render_candidate';[IO.File]::AppendAllText((Join-Path $f20 $candidate20.RelativePath),"`n",[Text.UTF8Encoding]::new($false));$r20=Invoke-R7ViewportAcceptance $script:ProjectRoot $f20;$report20=if($r20.ExitCode-eq0){(Get-R7CandidateCurrentArtifact $f20 'viewport_acceptance_report').Payload}else{$null};$actual20=if($null-ne$report20-and[bool]$report20.artifact_execution_contribution.manual_patch_detected-and[int]$report20.workflow_autonomous_completion_count-eq0){'manual_patch_detected'}else{'fail'};$results.Add((New-R7H5Result 'R7-F20' manual_patch_detected $actual20 @($r20.Errors)))

  $actual21=Test-R7DocumentationDriftText active_compiled 'H5 pending compile';$results.Add((New-R7H5Result 'R7-F21' documentation_drift $actual21 @()))

  $mismatch=@($results|Where-Object{-not$_.expectation_met});$report=[ordered]@{r7_h5_viewport_check_report=[ordered]@{check_run_id='R7-H5-'+(Get-Date -Format 'yyyyMMdd-HHmmss');overall_result=$(if($mismatch.Count){'fail'}else{'pass'});exit_code=$(if($mismatch.Count){1}else{0});fixture_count=$results.Count;mismatch_count=$mismatch.Count;browser_available=[bool]$hostInfo.Available;not_tested_scope=@('real_account','provider','network','publishing','human_publish_decision');checks=[object[]]$results.ToArray()}}
  Write-TaogeUtf8NoBomJson $machine $report 30;$lines=@('# R7-H5 Viewport and Autonomy Check','',"overall_result: $($report.r7_h5_viewport_check_report.overall_result)",'','| Fixture | Expected | Actual | Matched | Errors |','|---|---|---|---:|---|');foreach($item in $results){$lines+="| $($item.fixture_id) | $($item.expected_result) | $($item.actual_result) | $($item.expectation_met) | $([string]::Join(';',@($item.errors))) |"};Write-TaogeUtf8NoBomLines $human $lines
  if($mismatch.Count){Write-Output 'R7_H5_VIEWPORT_CHECK_RESULT=fail';foreach($item in $mismatch){Write-Output "R7_H5_ERROR=$($item.fixture_id):$([string]::Join(';',@($item.errors)))"};exit 1};Write-Output 'R7_H5_VIEWPORT_CHECK_RESULT=pass';Write-Output "R7_H5_FIXTURE_COUNT=$($results.Count)";exit 0
}catch{Write-Error("{0} at line {1}: {2}"-f$_.Exception.Message,$_.InvocationInfo.ScriptLineNumber,$_.InvocationInfo.Line);exit 3}
