param(
  [string]$WorkRoot='state/checks/r7-h5-viewport-work',
  [string]$HumanReportPath='state/checks/r7-h5-viewport-check-report.md',
  [string]$MachineReportPath='state/checks/r7-h5-viewport-check-report.json',
  [switch]$H4SeedPathBudgetSelfTest
)

$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'R7ViewportRuntime.ps1')

function Resolve-R7H5Path([string]$Path){if([IO.Path]::IsPathRooted($Path)){return [IO.Path]::GetFullPath($Path)};return [IO.Path]::GetFullPath((Join-Path $script:ProjectRoot $Path))}
function New-R7H5Result([string]$Id,[string]$Expected,[string]$Actual,[string[]]$Errors=@()){[pscustomobject]@{fixture_id=$Id;expected_result=$Expected;actual_result=$Actual;expectation_met=($Expected-eq$Actual);errors=[object[]]@($Errors)}}
function Copy-R7H5Session([string]$Source,[string]$Parent){if(Test-Path -LiteralPath $Parent){Remove-Item -LiteralPath $Parent -Recurse -Force};New-Item -ItemType Directory -Path $Parent -Force|Out-Null;$target=Join-Path $Parent (Split-Path -Leaf $Source);Copy-Item -LiteralPath $Source -Destination $target -Recurse -Force;return $target}
function Set-R7H5FixtureEventsAsRuntime([string]$Session){$plan=Read-P0JsonFile (Join-Path $Session 'intermediate/p0/session-execution-plan.json');$events=@(Get-P0EvidenceEvents (Join-Path $Session 'intermediate/p0/execution-events.jsonl'));foreach($event in $events){$step=@($plan.steps|Where-Object{$_.step_id-eq$event.step_id})|Select-Object -First 1;if($null-ne$step-and$event.event_type-eq'fixture.completed.v1'-and$step.step_kind-in@('agent_required','external_side_effect')){$event.event_type='semantic.result_committed.v1'}};Write-TaogeUtf8NoBomLines (Join-Path $Session 'intermediate/p0/execution-events.jsonl') @($events|ForEach-Object{$_|ConvertTo-Json -Compress -Depth 50})}
function Get-R7H5H4SeedWork([string]$H5WorkRoot,[string]$SeedId){$seedParent=Split-Path -Parent $H5WorkRoot;if([string]::IsNullOrWhiteSpace($seedParent)){throw 'checker_invocation_error:h4_seed_parent_missing'};return Join-Path ([IO.Path]::GetFullPath($seedParent)) ('.r7h4-'+$SeedId)}
function Get-R7H5H4PathProbe([string]$H4WorkRoot){return Join-Path $H4WorkRoot 'RUN-20260717-123456-123456/R7-L3-E2E-CURRENT/intermediate/r7/revisions/final_delivery_render_candidate/FD-R7-L3-E2E-CURRENT-001.json.tmp-12345678901234567890123456789012'}
function Test-R7H5H4SeedPathBudgetRegression(){
  $seedId='12345678'
  $ciCandidateSandbox='D:\a\taogeskill\taogeskill\releases\v0.1.0-alpha.8\public_release\.v0000'
  $ciH5WorkRoot='D:\a\taogeskill\taogeskill\releases\v0.1.0-alpha.8\.r7h5'
  $legacyProbe=Get-R7H5H4PathProbe (Join-Path $ciCandidateSandbox ('state\checks\h4s\'+$seedId))
  $currentProbe=Get-R7H5H4PathProbe (Get-R7H5H4SeedWork $ciH5WorkRoot $seedId)
  [pscustomobject]@{legacy_length=$legacyProbe.Length;current_length=$currentProbe.Length;pass=($legacyProbe.Length-gt245-and$currentProbe.Length-le245)}
}

try{
  $script:ProjectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
  $h4SeedPathBudgetRegression=Test-R7H5H4SeedPathBudgetRegression
  if(-not$h4SeedPathBudgetRegression.pass){throw "h4_seed_path_budget_regression_failed:legacy=$($h4SeedPathBudgetRegression.legacy_length);current=$($h4SeedPathBudgetRegression.current_length)"}
  if($H4SeedPathBudgetSelfTest){
    Write-Output 'R7_H5_H4_SEED_PATH_BUDGET_SELFTEST=pass'
    Write-Output "R7_H5_H4_SEED_PATH_BUDGET_LEGACY_LENGTH=$($h4SeedPathBudgetRegression.legacy_length)"
    Write-Output "R7_H5_H4_SEED_PATH_BUDGET_CURRENT_LENGTH=$($h4SeedPathBudgetRegression.current_length)"
    exit 0
  }
  $work=Resolve-R7H5Path $WorkRoot;$human=Resolve-R7H5Path $HumanReportPath;$machine=Resolve-R7H5Path $MachineReportPath
  foreach($path in @($work,(Split-Path -Parent $human),(Split-Path -Parent $machine))){if(-not(Test-Path -LiteralPath $path)){New-Item -ItemType Directory -Path $path -Force|Out-Null}}
  $run=Join-Path $work ('RUN-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6));New-Item -ItemType Directory -Path $run|Out-Null
  # H4 creates revision and atomic-temp paths below its work root. Nesting that
  # tree inside the H5 run can exceed the classic Windows 259-character budget.
  # Keep the seed in a short, unique sibling root of the caller-selected work
  # directory.  The public validator places that root outside its copied
  # payload, preventing an extra public_release/state/checks nesting level.
  $h4SeedId=[guid]::NewGuid().ToString('N').Substring(0,8);$h4Work=Get-R7H5H4SeedWork $work $h4SeedId;$h4Human=Join-Path $h4Work 'report.md';$h4Machine=Join-Path $h4Work 'report.json'
  $h4PathProbe=Get-R7H5H4PathProbe $h4Work
  if($h4PathProbe.Length-gt245){throw "checker_invocation_error:h4_seed_path_budget_exceeded:$($h4PathProbe.Length)"}
  $h4Output=@(& (Join-Path $PSScriptRoot 'validate-r7-h4-candidate-runtime.ps1') -WorkRoot $h4Work -HumanReportPath $h4Human -MachineReportPath $h4Machine 2>&1);if(-not$?){throw "h4_fixture_seed_failed:$([string]::Join(';',@($h4Output)))"}
  $h4Run=Get-ChildItem -LiteralPath $h4Work -Directory|Sort-Object LastWriteTime -Descending|Select-Object -First 1;$source=Join-Path $h4Run.FullName 'R7-F09-F13';$sourceH7=Join-Path $h4Run.FullName 'R7-H7-F20';if(-not(Test-Path -LiteralPath $source)){throw 'h4_valid_session_missing'};if(-not(Test-Path -LiteralPath $sourceH7)){throw 'h7_valid_session_missing'}
  $partialModuleRoot=Join-Path $run 'partial-node-modules';New-Item -ItemType Directory -Path (Join-Path $partialModuleRoot 'playwright') -Force|Out-Null
  $oldNodePath=$env:NODE_PATH;$nodePathParts=@($partialModuleRoot);if(-not[string]::IsNullOrWhiteSpace($oldNodePath)){$nodePathParts+=$oldNodePath};$env:NODE_PATH=[string]::Join(';',$nodePathParts);try{$hostInfo=Get-R7ViewportHost -ProjectRoot $script:ProjectRoot}finally{$env:NODE_PATH=$oldNodePath}
  if(-not$hostInfo.Available){throw 'playwright_actual_capability_probe_failed_after_incomplete_node_path_entry'}
  if([string]$hostInfo.ModuleRoot-eq$partialModuleRoot){throw 'incomplete_playwright_directory_false_positive'}
  if([string]$hostInfo.ResolvedPlaywright-match'(?i)[\\/]codex-runtimes[\\/]'){throw 'codex_private_runtime_selected_as_project_dependency'}
  if([string]$hostInfo.ProbeStatus-ne'node_resolve_and_browser_launch_pass'){throw "playwright_probe_status_invalid:$($hostInfo.ProbeStatus)"}
  $results=[Collections.Generic.List[object]]::new()

  $f14=Copy-R7H5Session $source (Join-Path $run 'f14');$r14=Invoke-R7ViewportAcceptance $script:ProjectRoot $f14;$errors14=[Collections.Generic.List[string]]::new();if($r14.ExitCode-ne0){$errors14.Add("viewport_exit:$($r14.ResultCode)");foreach($runtimeError in @($r14.Errors)){$errors14.Add([string]$runtimeError)}};if($r14.ExitCode-eq0){$report14=(Get-R7CandidateCurrentArtifact $f14 'viewport_acceptance_report').Payload;if($report14.overall_result-ne'pass'){$errors14.Add('viewport_result_not_pass')};if(@($report14.profiles).Count-ne2){$errors14.Add('viewport_profile_count_invalid')};foreach($profile in @($report14.profiles)){if([string]$profile.screenshot_path-notlike'intermediate/visual-review/r7/r1/*'){$errors14.Add("screenshot_revision_scope_missing:$($profile.profile_id)")}elseif(-not(Test-Path -LiteralPath (Join-Path $f14 $profile.screenshot_path))){$errors14.Add("screenshot_missing:$($profile.profile_id)")}elseif((Get-R7RuntimeHash (Join-Path $f14 $profile.screenshot_path))-ne$profile.screenshot_sha256){$errors14.Add("screenshot_digest_mismatch:$($profile.profile_id)")}}};$results.Add((New-R7H5Result 'R7-F14' viewport_pass_with_bound_evidence $(if($errors14.Count){'fail'}else{'viewport_pass_with_bound_evidence'}) $errors14.ToArray()))
  $fH7=Copy-R7H5Session $sourceH7 (Join-Path $run 'h7-viewport');$rH7=Invoke-R7ViewportAcceptance $script:ProjectRoot $fH7;$errorsH7=[Collections.Generic.List[string]]::new();if($rH7.ExitCode-ne0){$errorsH7.Add("viewport_exit:$($rH7.ResultCode)");foreach($runtimeError in @($rH7.Errors)){$errorsH7.Add([string]$runtimeError)}}else{
    $reportH7=(Get-R7CandidateCurrentArtifact $fH7 'viewport_acceptance_report').Payload
    if([string]$reportH7.schema_id-ne'taoge://schemas/r7/viewport-acceptance/v0.2'-or[string]$reportH7.technical_viewport_status-ne'pass'){$errorsH7.Add('h7_technical_viewport_status_invalid')}
    if('visual_acceptance_status'-in@($reportH7.PSObject.Properties.Name)){$errorsH7.Add('h7_visual_acceptance_leaked_into_technical_report')}
    if([string]$reportH7.next_skill-ne'business-delivery-acceptance'){$errorsH7.Add('h7_business_acceptance_route_missing')}
    if(@($reportH7.profiles).Count-ne2){$errorsH7.Add('h7_viewport_profile_count_invalid')}
  }
  $results.Add((New-R7H5Result 'R7-H7-F21' technical_viewport_routes_to_business_acceptance $(if($errorsH7.Count){'fail'}else{'technical_viewport_routes_to_business_acceptance'}) $errorsH7.ToArray()))
  $businessErrors=[Collections.Generic.List[string]]::new()
  if($errorsH7.Count-eq0){
    $taskH7=Prepare-R7RuntimeTask -ProjectRoot $script:ProjectRoot -Session $fH7
    if($taskH7.ExitCode-ne0-or[string]$taskH7.Data.Task.node_id-ne'business_delivery_acceptance'){$businessErrors.Add("h7_business_task_prepare_failed:$($taskH7.ResultCode)")}
    else{
      $deliveryH7=Get-R7CandidateCurrentArtifact $fH7 'final_delivery';$viewportH7=Get-R7CandidateCurrentArtifact $fH7 'viewport_acceptance_report'
      $dimensionsH7=@('information_hierarchy','delivery_title_quality','final_asset_binding','readiness_truthfulness','visual_human_review','action_usability')|ForEach-Object{[ordered]@{dimension_id=$_;status='pass';finding='fixture reviewed'}}
      $payloadH7=[ordered]@{schema_id='taoge://schemas/r7/business-delivery-acceptance/v0.1';schema_version='0.1';business_acceptance_id='BDA-R7-H7-F22-001';session_id='R7-H7-F20';final_delivery_ref=[ordered]@{artifact_id=[string]$deliveryH7.Pointer.artifact_id;sha256=[string]$deliveryH7.Sha256};viewport_report_ref=[ordered]@{artifact_id=[string]$viewportH7.Pointer.artifact_id;sha256=[string]$viewportH7.Sha256};html_sha256=[string]$viewportH7.Payload.html_sha256;reviewer_type='codex_visual_review';review_evidence=[ordered]@{desktop_screenshot_ref=[ordered]@{sha256=[string]$viewportH7.Payload.profiles[0].screenshot_sha256};mobile_screenshot_ref=[ordered]@{sha256=[string]$viewportH7.Payload.profiles[1].screenshot_sha256};actual_images_viewed=$true};dimensions=[object[]]$dimensionsH7;business_delivery_status='pass';blocking_issue_codes=@();warning_codes=@();reviewed_at='2026-07-16T08:30:00+08:00';next_skill='propagation-router'}
      $payloadPath='intermediate/r7/payloads/h7-business-pass.json';Write-P0EvidenceAtomicText (Join-Path $fH7 $payloadPath) (ConvertTo-P0EvidenceJsonText $payloadH7)
      $badPayload=($payloadH7|ConvertTo-Json -Depth 30|ConvertFrom-Json);$badPayload.viewport_report_ref.sha256='sha256:'+('0'*64);$badPath='intermediate/r7/payloads/h7-business-bad-ref.json';Write-P0EvidenceAtomicText (Join-Path $fH7 $badPath) (ConvertTo-P0EvidenceJsonText $badPayload)
      $badBuild=New-R7RuntimeSubmissionFromPayload $script:ProjectRoot $fH7 ([string]$taskH7.Data.Task.task_envelope_id) $badPath pass 2
      if($badBuild.ResultCode-ne'producer_payload_mapping_error'-or'h7_business_viewport_ref_mismatch'-notin@($badBuild.Errors)){$businessErrors.Add("h7_business_bad_ref_false_accept:$($badBuild.ResultCode)")}
      $cliOutput=@(& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'new-r7-semantic-submission.ps1') -Session $fH7 -TaskEnvelopeId ([string]$taskH7.Data.Task.task_envelope_id) -PayloadPath $payloadPath -ResultStatus pass -AttemptNo 1 2>&1)
      $cliExitCode=$LASTEXITCODE
      $cliDataLine=@($cliOutput|ForEach-Object{[string]$_}|Where-Object{$_-like'R7_SUBMISSION_BUILD_DATA=*'}|Select-Object -Last 1)
      if($cliExitCode-ne0-or$cliDataLine.Count-ne1){$businessErrors.Add("h7_business_cli_valid_rejected:exit=${cliExitCode}:$([string]::Join(',',@($cliOutput)))")}
      else{$goodBuildData=$cliDataLine[0].Substring('R7_SUBMISSION_BUILD_DATA='.Length)|ConvertFrom-Json;$goodCommit=Submit-R7RuntimeArtifact $script:ProjectRoot $fH7 ([string]$goodBuildData.SubmissionPath);if($goodCommit.ResultCode-ne'semantic_artifact_committed'-or[string]$goodCommit.Data.NextStepId-notlike'*-final_human_gate_h7'){$businessErrors.Add("h7_business_commit_failed:$($goodCommit.ResultCode)")}}
    }
  }else{$businessErrors.Add('h7_business_fixture_skipped_after_viewport_failure')}
  $results.Add((New-R7H5Result 'R7-H7-F22' business_acceptance_bound_submission $(if($businessErrors.Count){'fail'}else{'business_acceptance_bound_submission'}) $businessErrors.ToArray()))
  $revisionRootsDistinct=(Get-R7ViewportEvidenceRelativeRoot 1)-ne(Get-R7ViewportEvidenceRelativeRoot 2)
  $results.Add((New-R7H5Result 'R7-F37' revision_scoped_viewport_evidence $(if($revisionRootsDistinct){'revision_scoped_viewport_evidence'}else{'fail'}) @()))
  $revisionHumanIdentity=Get-R7FinalHumanSubmissionIdentity 'S-REVISION' 'human_confirm' $true 2
  $results.Add((New-R7H5Result 'R7-F38' final_human_submission_revision_monotonic $(if($revisionHumanIdentity.OutputRevision-eq2-and$revisionHumanIdentity.SubmissionId-like'*-r2'){'final_human_submission_revision_monotonic'}else{'fail'}) @()))

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
