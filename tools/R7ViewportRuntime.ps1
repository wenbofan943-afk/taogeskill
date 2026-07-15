Set-StrictMode -Version 2.0

if(-not(Get-Command Read-R7JsonFile -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'R7ContractHelper.ps1')}
if(-not(Get-Command Invoke-R7DeterministicNode -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'R7CandidateRuntime.ps1')}
if(-not(Get-Command Start-TaogeProcess -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')}

function Get-R7PublicNodePath {
  $parts=[Collections.Generic.List[string]]::new()
  foreach($entry in @([string]$env:NODE_PATH -split ';')){
    if([string]::IsNullOrWhiteSpace($entry)){continue}
    if($entry -match '(?i)[\\/]codex-runtimes[\\/]'){continue}
    $parts.Add($entry)
  }
  return [string]::Join(';',@($parts|Select-Object -Unique))
}

function Invoke-R7PlaywrightCapabilityProbe {
  param([string]$Node,[string]$ProjectRoot,[string]$NodePath,[string]$Browser='')
  $probe=@'
const { chromium } = require("playwright");
const pkg = require("playwright/package.json");
(async () => {
  const requested = process.argv[2] || "";
  const launch = { headless: true };
  if (requested) launch.executablePath = requested;
  const browser = await chromium.launch(launch);
  await browser.close();
  process.stdout.write(JSON.stringify({
    status: "PASS",
    version: pkg.version,
    resolved: require.resolve("playwright"),
    browser: requested || chromium.executablePath()
  }));
})().catch(error => {
  console.error(error && (error.stack || error.message) || String(error));
  process.exit(1);
});
'@
  $encoded=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($probe))
  $runner='eval(Buffer.from(process.argv[1],String.fromCharCode(98,97,115,101,54,52)).toString())'
  $oldNodePath=$env:NODE_PATH;$oldPreference=$ErrorActionPreference;$pushed=$false
  try{
    $env:NODE_PATH=$NodePath
    Push-Location -LiteralPath $ProjectRoot;$pushed=$true
    $ErrorActionPreference='SilentlyContinue'
    $output=@(& $Node -e $runner $encoded $Browser 2>&1);$exitCode=$LASTEXITCODE
    if($exitCode-ne0){return [pscustomobject]@{Available=$false;ProbeStatus='browser_launch_failed';Version='';Resolved='';Browser=''}}
    $payload=([string]::Join("`n",@($output)))|ConvertFrom-Json
    if($payload.status-ne'PASS'-or[string]::IsNullOrWhiteSpace([string]$payload.resolved)){return [pscustomobject]@{Available=$false;ProbeStatus='probe_output_invalid';Version='';Resolved='';Browser=''}}
    return [pscustomobject]@{Available=$true;ProbeStatus='node_resolve_and_browser_launch_pass';Version=[string]$payload.version;Resolved=[string]$payload.resolved;Browser=[string]$payload.browser}
  }catch{return [pscustomobject]@{Available=$false;ProbeStatus='probe_invocation_error';Version='';Resolved='';Browser=''}}
  finally{if($pushed){Pop-Location};$env:NODE_PATH=$oldNodePath;$ErrorActionPreference=$oldPreference}
}

function Get-R7ViewportHost {
  param([string]$ProjectRoot=(Split-Path -Parent $PSScriptRoot))
  $nodeCandidates=[Collections.Generic.List[string]]::new()
  if(-not[string]::IsNullOrWhiteSpace($env:TAOGE_NODE_EXE)){$nodeCandidates.Add($env:TAOGE_NODE_EXE)}
  $nodeCommand=Get-Command node -ErrorAction SilentlyContinue;if($null-ne$nodeCommand){$nodeCandidates.Add([string]$nodeCommand.Source)}
  $node=@($nodeCandidates|Where-Object{Test-Path -LiteralPath $_ -PathType Leaf}|Select-Object -First 1)
  $nodePath=Get-R7PublicNodePath
  if(@($node).Count-ne1){return [pscustomobject]@{Available=$false;Node='';ModuleRoot='';NodePath=$nodePath;Browser='';BrowserMode='';PlaywrightVersion='';ResolvedPlaywright='';ProbeStatus='node_not_available'}}
  $browserCandidates=[Collections.Generic.List[object]]::new()
  $browserCandidates.Add([pscustomobject]@{Path='';Mode='playwright_managed'})
  foreach($candidate in @((Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),(Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'))){if(Test-Path -LiteralPath $candidate -PathType Leaf){$browserCandidates.Add([pscustomobject]@{Path=$candidate;Mode='system_browser_fallback'})}}
  $lastStatus='playwright_not_resolved_or_browser_not_launchable'
  foreach($candidate in $browserCandidates){
    $probe=Invoke-R7PlaywrightCapabilityProbe -Node ([string]$node[0]) -ProjectRoot $ProjectRoot -NodePath $nodePath -Browser ([string]$candidate.Path)
    $lastStatus=[string]$probe.ProbeStatus
    if(-not$probe.Available){continue}
    $packageRoot=Split-Path -Parent ([string]$probe.Resolved);$moduleRoot=Split-Path -Parent $packageRoot
    return [pscustomobject]@{Available=$true;Node=[string]$node[0];ModuleRoot=$moduleRoot;NodePath=$nodePath;Browser=[string]$candidate.Path;BrowserMode=[string]$candidate.Mode;PlaywrightVersion=[string]$probe.Version;ResolvedPlaywright=[string]$probe.Resolved;ProbeStatus=[string]$probe.ProbeStatus}
  }
  return [pscustomobject]@{Available=$false;Node=[string]$node[0];ModuleRoot='';NodePath=$nodePath;Browser='';BrowserMode='';PlaywrightVersion='';ResolvedPlaywright='';ProbeStatus=$lastStatus}
}

function Invoke-R7ViewportProfile {
  param([string]$ProjectRoot,[string]$SessionRoot,[string]$HtmlPath,[string]$ProfileId,[int]$Width,[int]$Height,[object]$HostInfo,[switch]$OmitScreenshot)
  $evidenceRoot=Join-Path $SessionRoot 'intermediate/visual-review/r7';if(-not(Test-Path $evidenceRoot)){New-Item -ItemType Directory -Path $evidenceRoot -Force|Out-Null}
  $measurementPath=Join-Path $evidenceRoot "$ProfileId.measurement.json";$screenshotPath=Join-Path $evidenceRoot "$ProfileId.png";$stdoutPath=Join-Path $evidenceRoot "$ProfileId.stdout.log";$stderrPath=Join-Path $evidenceRoot "$ProfileId.stderr.log"
  foreach($path in @($measurementPath,$screenshotPath,$stdoutPath,$stderrPath)){if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path -Force}}
  $oldNodePath=$env:NODE_PATH;$env:NODE_PATH=[string]$HostInfo.NodePath
  try{
    $args=@((Join-Path $ProjectRoot 'tools/r7-viewport-measure.js'),'--html',$HtmlPath,'--output',$measurementPath,'--screenshot',$screenshotPath,'--width',[string]$Width,'--height',[string]$Height,'--browser',[string]$HostInfo.Browser,'--omitScreenshot',$(if($OmitScreenshot){'true'}else{'false'}))
    $process=Start-TaogeProcess -FilePath ([string]$HostInfo.Node) -Arguments $args -StandardOutputPath $stdoutPath -StandardErrorPath $stderrPath -WorkingDirectory $ProjectRoot -Wait -Hidden
  }finally{$env:NODE_PATH=$oldNodePath}
  if($process.ExitCode-ne0){$tail=if(Test-Path $stderrPath){[string]::Join(' | ',@((Get-Content -Encoding UTF8 $stderrPath|Select-Object -Last 10)))}else{'no_stderr'};return [pscustomobject]@{ResultCode='browser_invocation_error';Errors=@("browser_process_exit:$($process.ExitCode):$tail");Profile=$null}}
  if(-not(Test-Path -LiteralPath $measurementPath)){return [pscustomobject]@{ResultCode='browser_invocation_error';Errors=@('measurement_file_missing');Profile=$null}}
  $measurement=Read-R7JsonFile $measurementPath
  if(-not(Test-Path -LiteralPath $screenshotPath)){return [pscustomobject]@{ResultCode='evidence_pending';Errors=@('screenshot_file_pending');Profile=[pscustomobject]@{profile_id=$ProfileId;viewport_css_px=[pscustomobject]@{width=$Width;height=$Height};measurement_path=$measurementPath.Substring($SessionRoot.Length+1).Replace('\','/');measurement=$measurement}}}
  $screenshotRelative=$screenshotPath.Substring($SessionRoot.Length+1).Replace('\','/');$measurementRelative=$measurementPath.Substring($SessionRoot.Length+1).Replace('\','/')
  $profile=[ordered]@{profile_id=$ProfileId;viewport_css_px=[ordered]@{width=$Width;height=$Height};document_client_width=[int]$measurement.document_client_width;document_scroll_width=[int]$measurement.document_scroll_width;body_scroll_width=[int]$measurement.body_scroll_width;overflow_offender_count=[int]$measurement.overflow_offender_count;overflow_offenders=[object[]]@($measurement.overflow_offenders);failed_image_count=[int]$measurement.failed_image_count;failed_request_count=[int]$measurement.failed_request_count;font_wait_status=[string]$measurement.font_wait_status;measurement_path=$measurementRelative;screenshot_path=$screenshotRelative;screenshot_sha256=Get-R7RuntimeHash $screenshotPath}
  $failed=[int]$profile.overflow_offender_count-gt0 -or [int]$profile.failed_image_count-gt0 -or [int]$profile.document_scroll_width-gt[int]$profile.document_client_width -or [int]$profile.body_scroll_width-gt[int]$profile.document_client_width
  return [pscustomobject]@{ResultCode=$(if($failed){'visual_acceptance_fail'}else{'pass'});Errors=@();Profile=[pscustomobject]$profile}
}

function Get-R7AutonomyEvidence {
  param([string]$SessionRoot,[string]$ViewportResult)
  $plan=Read-P0JsonFile (Join-Path $SessionRoot 'intermediate/p0/session-execution-plan.json');$events=@(Get-P0EvidenceEvents (Join-Path $SessionRoot 'intermediate/p0/execution-events.jsonl'));$manual=$false;$reasons=[Collections.Generic.List[string]]::new()
  $semanticSteps=@($plan.steps|Where-Object{$_.step_kind-eq'agent_required'});$semanticEvents=@($events|Where-Object{$_.event_type-eq'semantic.result_committed.v1'-and$_.event_source-eq'agent_recorder' -and $_.state_after-eq'succeeded'})
  $externalSteps=@($plan.steps|Where-Object{$_.step_kind-eq'external_side_effect'});$externalEvents=@($events|Where-Object{$_.event_type-eq'semantic.result_committed.v1'-and$_.event_source-eq'reconciler' -and $_.state_after-eq'succeeded'})
  $deterministicEvents=@($events|Where-Object{$_.event_type-eq'deterministic.result_committed.v1'-and$_.event_source-eq'runner' -and $_.state_after-eq'succeeded'})
  foreach($type in @('final_delivery_render_candidate','final_delivery')){
    try{$item=Get-R7CandidateCurrentArtifact $SessionRoot $type;$event=@($events|Where-Object{$_.event_id-eq$item.Pointer.producer_event_id})|Select-Object -First 1;if($null-eq$event-or[string]$event.payload_digest-ne[string]$item.Pointer.sha256){$manual=$true;$reasons.Add("producer_event_digest_mismatch:$type")}}
    catch{$manual=$true;$reasons.Add($_.Exception.Message)}
  }
  $candidate=try{(Get-R7CandidateCurrentArtifact $SessionRoot 'final_delivery_render_candidate').Payload}catch{$null}
  if($null-eq$candidate-or$candidate.compiler_provenance.producer-ne'deterministic_compiler'-or$candidate.artifact_execution_contribution.manual_patch_detected){$manual=$true;$reasons.Add('candidate_producer_or_patch_invalid')}
  $agentOrchestrated=@($events|Where-Object{$_.event_source -notin @('runner','agent_recorder','human_recorder','reconciler')}).Count
  $semanticComplete=$semanticEvents.Count-eq$semanticSteps.Count;$externalComplete=$externalEvents.Count-eq$externalSteps.Count
  if(-not$semanticComplete){$reasons.Add("semantic_step_count:$($semanticEvents.Count)/$($semanticSteps.Count)")};if(-not$externalComplete){$reasons.Add("external_step_count:$($externalEvents.Count)/$($externalSteps.Count)")}
  $eligible=$semanticComplete-and$externalComplete-and-not$manual-and$agentOrchestrated-eq0-and$ViewportResult-eq'pass'
  return [pscustomobject]@{Contribution=[pscustomobject]@{candidate_producer='deterministic_compiler';manual_patch_detected=$manual;semantic_skill_step_completed_count=$semanticEvents.Count;deterministic_tool_step_completed_count=$deterministicEvents.Count;human_gate_completed_count=@($events|Where-Object{$_.event_source-eq'human_recorder'-and$_.state_after-eq'succeeded'}).Count;external_side_effect_step_completed_count=$externalEvents.Count;agent_orchestrated_node_count=$agentOrchestrated;contract_coverage=$(if($eligible){'complete'}else{'partial'});intervention_reasons=[object[]]$reasons.ToArray()};AutonomyEligible=$eligible;WorkflowAutonomousCompletionCount=$(if($eligible){1}else{0})}
}

function Test-R7ViewportReportContract {
  param([object]$Report)
  $errors=[Collections.Generic.List[string]]::new();$required=@('schema_id','schema_version','viewport_report_id','session_id','final_delivery_ref','html_path','html_sha256','browser_invocation_status','layout_measurement_status','visual_acceptance_status','overall_result','profiles','artifact_execution_contribution','workflow_autonomous_completion_count','autonomy_eligible','warning_codes','created_at','next_skill')
  foreach($e in (Test-P0RequiredProperties $Report $required 'viewport_report')){$errors.Add($e)};foreach($e in (Test-P0AllowedProperties $Report $required 'viewport_report')){$errors.Add($e)}
  if($errors.Count){return [object[]]$errors.ToArray()};if($Report.schema_id-ne'taoge://schemas/r7/viewport-acceptance/v0.1'-or[string]$Report.schema_version-ne'0.1'){$errors.Add('viewport_report_version_invalid')};if(-not(Test-P0Digest $Report.html_sha256)){$errors.Add('viewport_html_digest_invalid')}
  if($Report.overall_result-eq'pass' -and (@($Report.profiles).Count-ne2 -or @($Report.profiles|Where-Object{$_.overflow_offender_count-ne0-or$_.failed_image_count-ne0}).Count)){$errors.Add('viewport_false_pass')}
  if([int]$Report.workflow_autonomous_completion_count-eq1 -and (-not[bool]$Report.autonomy_eligible-or[bool]$Report.artifact_execution_contribution.manual_patch_detected)){$errors.Add('autonomy_false_positive')}
  return [object[]]$errors.ToArray()
}

function Test-R7ViewportGatePolicy {
  param([ValidateSet('content','template','renderer','release')][string]$Mode,[string]$ViewportResult)
  if($ViewportResult-eq'pass'){return 'pass'}
  if($Mode-eq'content'-and$ViewportResult-eq'not_tested'){return 'ready_with_warnings'}
  return 'blocker'
}

function Test-R7DocumentationDriftText {
  param([string]$ContractLifecycle,[string]$SkillText)
  if($ContractLifecycle-eq'active_compiled' -and $SkillText -match '(?i)pending[_ -]compile|尚待编译|未编译'){return 'documentation_drift'}
  return 'pass'
}

function Invoke-R7ViewportAcceptance {
  param([string]$ProjectRoot,[string]$Session,[switch]$ForceBrowserUnavailable)
  $sessionRoot=[IO.Path]::GetFullPath($Session)
  try{$deliveryCurrent=Get-R7CandidateCurrentArtifact $sessionRoot 'final_delivery';$delivery=$deliveryCurrent.Payload;$plan=Read-P0JsonFile (Join-Path $sessionRoot 'intermediate/p0/session-execution-plan.json');$viewportRevision=$(if([string]$plan.plan_schema_id-eq'taoge://schemas/p0/session-execution-plan/v0.9'){[int]$plan.plan_revision}else{1});$htmlPath=Resolve-R7RuntimePath $sessionRoot ([string]$delivery.html_path);if(-not(Test-Path -LiteralPath $htmlPath)){throw 'final_html_missing'};$htmlDigest=Get-R7RuntimeHash $htmlPath;if($htmlDigest-ne[string]$delivery.html_sha256){throw 'final_html_digest_mismatch'}
    $hostInfo=Get-R7ViewportHost;$profiles=[Collections.Generic.List[object]]::new();$warnings=[Collections.Generic.List[string]]::new();$browserStatus='succeeded';$layoutStatus='measured';$visualStatus='pass';$overall='pass'
    if($ForceBrowserUnavailable-or-not$hostInfo.Available){$browserStatus='not_available';$layoutStatus='not_tested';$visualStatus='not_tested';$overall='not_tested';$warnings.Add('viewport_browser_not_available')}
    else{$runtimeErrors=[Collections.Generic.List[string]]::new();foreach($definition in @([pscustomobject]@{Id='desktop-1440x1000';Width=1440;Height=1000},[pscustomobject]@{Id='mobile-390x844';Width=390;Height=844})){$result=Invoke-R7ViewportProfile $ProjectRoot $sessionRoot $htmlPath $definition.Id $definition.Width $definition.Height $hostInfo;if($result.ResultCode-ne'pass'){$overall=[string]$result.ResultCode;$visualStatus=if($result.ResultCode-eq'visual_acceptance_fail'){'visual_acceptance_fail'}else{'not_tested'};foreach($error in @($result.Errors)){$runtimeErrors.Add([string]$error)};if($result.ResultCode-eq'evidence_pending'){$browserStatus='evidence_pending'}elseif($result.ResultCode-eq'browser_invocation_error'){$browserStatus='error';$layoutStatus='error'};break};$profiles.Add($result.Profile)}}
    if($overall-in@('visual_acceptance_fail','browser_invocation_error','evidence_pending')){if($runtimeErrors.Count-eq0){$runtimeErrors.Add($overall)};return New-R7RuntimeResult $(if($overall-eq'evidence_pending'){'browser_invocation_error'}else{$overall}) 2 ([pscustomobject]@{Profiles=[object[]]$profiles.ToArray();BrowserStatus=$browserStatus}) $runtimeErrors.ToArray()}
    $autonomy=Get-R7AutonomyEvidence $sessionRoot $overall;$report=[ordered]@{schema_id='taoge://schemas/r7/viewport-acceptance/v0.1';schema_version='0.1';viewport_report_id="VIEWPORT-$(Split-Path -Leaf $sessionRoot)-$('{0:000}'-f$viewportRevision)";session_id=Split-Path -Leaf $sessionRoot;final_delivery_ref=[ordered]@{artifact_id=[string]$delivery.final_delivery_id;sha256=[string]$deliveryCurrent.Sha256};html_path=[string]$delivery.html_path;html_sha256=$htmlDigest;browser_invocation_status=$browserStatus;layout_measurement_status=$layoutStatus;visual_acceptance_status=$visualStatus;overall_result=$overall;profiles=[object[]]$profiles.ToArray();artifact_execution_contribution=$autonomy.Contribution;workflow_autonomous_completion_count=[int]$autonomy.WorkflowAutonomousCompletionCount;autonomy_eligible=[bool]$autonomy.AutonomyEligible;warning_codes=[object[]]$warnings.ToArray();created_at=[DateTimeOffset]::UtcNow.ToString('o');next_skill='propagation-router'}
    $reportObject=[pscustomobject](($report|ConvertTo-Json -Depth 40)|ConvertFrom-Json);$errors=@(Test-R7ViewportReportContract $reportObject);if($errors.Count){return New-R7RuntimeResult 'viewport_report_contract_error' 1 $reportObject $errors}
  }catch{return New-R7RuntimeResult 'browser_invocation_error' 2 $null @($_.Exception.Message)}
  $commit=Commit-R7DeterministicArtifact $ProjectRoot $sessionRoot 'viewport_acceptance' 'viewport_acceptance_report' ([string]$reportObject.viewport_report_id) $reportObject ([string]$reportObject.overall_result) @([string]$delivery.final_delivery_id) @('R7-F14','R7-F17','R7-F19','R7-F20')
  if($commit.ExitCode-eq0-and[string]$plan.plan_schema_id-eq'taoge://schemas/p0/session-execution-plan/v0.9'-and[int]$plan.plan_revision-gt1){if(-not(Get-Command Complete-R7ActiveRevisionRequest -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'R7HumanRevisionRuntime.ps1')};$closed=Complete-R7ActiveRevisionRequest $sessionRoot $plan;if($closed.ExitCode-ne0){return $closed}}
  return $commit
}

function Get-R7FinalDecisionAllowedActions {
  param([string]$DecisionStatus)
  switch($DecisionStatus){
    human_confirm{return @('publish_all_manually')}
    revision_requested{return @('revise_copy','revise_visual')}
    export_requested{return @('export_handoff')}
    archive_requested{return @('archive_session')}
    default{return @()}
  }
}

function Get-R7FinalTargetType {
  param([string]$ArtifactType)
  switch($ArtifactType){
    visual_coverage_ledger{return 'visual_need_analysis'}
    image_asset_set{return 'visual_asset'}
    cover_composition{return 'cover_rendition'}
    default{return $ArtifactType}
  }
}

function Test-R7WorkflowSessionRecordContract {
  param([object]$Payload)
  $errors=[Collections.Generic.List[string]]::new();$required=@('schema_id','schema_version','session_record_id','session_id','final_delivery_ref','viewport_report_ref','decision_status','requested_action','target_artifact_ref','decided_by','decided_at','next_skill');$isV02=[string]$Payload.schema_id-eq'taoge://schemas/r7/workflow-session-record/v0.2';if($isV02){$required+=@('delivery_revision_request_ref')}
  foreach($error in (Test-P0RequiredProperties $Payload $required 'workflow_session_record')){$errors.Add($error)};foreach($error in (Test-P0AllowedProperties $Payload $required 'workflow_session_record')){$errors.Add($error)}
  if($errors.Count){return [object[]]$errors.ToArray()}
  if(-not(($Payload.schema_id-eq'taoge://schemas/r7/workflow-session-record/v0.1'-and[string]$Payload.schema_version-eq'0.1')-or($isV02-and[string]$Payload.schema_version-eq'0.2'))){$errors.Add('workflow_session_record_version_invalid')}
  if(-not($isV02-and$Payload.decision_status-eq'revision_requested')-and[string]$Payload.requested_action -notin @(Get-R7FinalDecisionAllowedActions ([string]$Payload.decision_status))){$errors.Add('decision_action_mismatch')}
  if($isV02-and$Payload.decision_status-eq'revision_requested'-and($Payload.requested_action-ne'revise_delivery'-or$null-eq$Payload.delivery_revision_request_ref)){$errors.Add('delivery_revision_request_ref_required')}
  $targetRequired=[string]$Payload.requested_action -in @('revise_copy','revise_visual','export_handoff')
  if($targetRequired-and$null-eq$Payload.target_artifact_ref){$errors.Add('action_target_required')}
  if(-not$targetRequired-and$null-ne$Payload.target_artifact_ref){$errors.Add('action_target_not_allowed')}
  if($null-ne$Payload.target_artifact_ref){foreach($field in @('artifact_id','artifact_type')){if(-not(Test-P0HasProperty $Payload.target_artifact_ref $field)-or[string]::IsNullOrWhiteSpace([string]$Payload.target_artifact_ref.$field)){$errors.Add("action_target_field_missing:$field")}}}
  return [object[]]$errors.ToArray()
}

function New-R7FinalHumanSubmission {
  param([string]$ProjectRoot,[string]$Session,[string]$TaskEnvelopeId,[ValidateSet('human_confirm','revision_requested','export_requested','archive_requested')][string]$DecisionStatus,[ValidateSet('publish_primary_manually','publish_all_manually','revise_copy','revise_visual','export_handoff','archive_session')][string]$RequestedAction,[string]$TargetArtifactId='')
  $sessionRoot=[IO.Path]::GetFullPath($Session);$task=Read-R7JsonFile (Resolve-R7RuntimePath $sessionRoot "intermediate/r7/tasks/$TaskEnvelopeId.json");if($task.node_id-ne'final_human_gate'){return New-R7RuntimeResult 'final_human_task_invalid' 1 $task @()}
  if([string]$task.blueprint_version-eq'0.3'-and$DecisionStatus-eq'revision_requested'){return New-R7RuntimeResult 'delivery_revision_request_required' 1 $task @('use Invoke-R7HumanRevisionRequest with change_items')}
  if($DecisionStatus -notin @($task.allowed_statuses)-or$RequestedAction -notin @($task.allowed_actions)){return New-R7RuntimeResult 'enum_registry_error' 1 $task @($DecisionStatus,$RequestedAction)}
  if($RequestedAction -notin @(Get-R7FinalDecisionAllowedActions $DecisionStatus)){return New-R7RuntimeResult 'decision_action_mismatch' 1 $task @("${DecisionStatus}:$RequestedAction")}
  $registries=Get-R7RuntimeRegistries $ProjectRoot;$action=@($registries.Actions.actions|Where-Object{$_.action_code-eq$RequestedAction})|Select-Object -First 1;if($null-eq$action){return New-R7RuntimeResult 'enum_registry_error' 1 $task @($RequestedAction)}
  $delivery=Get-R7CandidateCurrentArtifact $sessionRoot 'final_delivery';$viewport=Get-R7CandidateCurrentArtifact $sessionRoot 'viewport_acceptance_report';$targetRef=$null
  if([bool]$action.requires_target_artifact){
    if([string]::IsNullOrWhiteSpace($TargetArtifactId)){return New-R7RuntimeResult 'action_target_required' 1 $task @($RequestedAction)}
    if($TargetArtifactId-eq[string]$delivery.Pointer.artifact_id){$targetType='final_delivery'}
    else{$candidate=(Get-R7CandidateCurrentArtifact $sessionRoot 'final_delivery_render_candidate').Payload;$source=@($candidate.source_map|Where-Object{$_.artifact_id-eq$TargetArtifactId})|Select-Object -First 1;if($null-eq$source){return New-R7RuntimeResult 'action_target_unknown' 1 $task @($TargetArtifactId)};$targetType=Get-R7FinalTargetType ([string]$source.artifact_type)}
    if($targetType -notin @($action.allowed_target_types)){return New-R7RuntimeResult 'action_target_type_mismatch' 1 $task @("${TargetArtifactId}:$targetType")}
    $targetRef=[ordered]@{artifact_id=$TargetArtifactId;artifact_type=$targetType}
  }elseif(-not[string]::IsNullOrWhiteSpace($TargetArtifactId)){return New-R7RuntimeResult 'action_target_not_allowed' 1 $task @($TargetArtifactId)}
  $sessionId=Split-Path -Leaf $sessionRoot;$isV02=[string]$task.blueprint_version-eq'0.3';$plan=Read-P0JsonFile (Join-Path $sessionRoot 'intermediate/p0/session-execution-plan.json');$recordRevision=$(if($isV02){[int]$plan.plan_revision}else{1});$payload=[ordered]@{schema_id=$(if($isV02){'taoge://schemas/r7/workflow-session-record/v0.2'}else{'taoge://schemas/r7/workflow-session-record/v0.1'});schema_version=$(if($isV02){'0.2'}else{'0.1'});session_record_id="SESSIONREC-$sessionId-$('{0:000}'-f$recordRevision)";session_id=$sessionId;final_delivery_ref=[ordered]@{artifact_id=[string]$delivery.Pointer.artifact_id;sha256=[string]$delivery.Sha256};viewport_report_ref=[ordered]@{artifact_id=[string]$viewport.Pointer.artifact_id;sha256=[string]$viewport.Sha256};decision_status=$DecisionStatus;requested_action=$RequestedAction;target_artifact_ref=$targetRef;decided_by='human';decided_at=[DateTimeOffset]::UtcNow.ToString('o');next_skill=$(switch($DecisionStatus){human_confirm{'done'}revision_requested{'semantic-workflow-coordinator'}export_requested{'handoff-exporter'}archive_requested{'archive-session'}})}
  if($isV02){$payload.delivery_revision_request_ref=$null}
  $payloadObject=[pscustomobject](($payload|ConvertTo-Json -Depth 20)|ConvertFrom-Json);$payloadErrors=@(Test-R7WorkflowSessionRecordContract $payloadObject);if($payloadErrors.Count){return New-R7RuntimeResult 'workflow_session_record_contract_error' 1 $payloadObject $payloadErrors}
  $submissionId="SUB-$sessionId-final_human_gate-$DecisionStatus";$submission=[ordered]@{schema_id='taoge://schemas/r7/semantic-artifact-submission/v0.2';schema_version='0.2';submission_id=$submissionId;task_envelope_id=[string]$task.task_envelope_id;session_id=$sessionId;plan_id=[string]$task.plan_id;node_id='final_human_gate';skill_ref=[string]$task.skill_ref;attempt_no=1;submitted_at=[DateTimeOffset]::UtcNow.ToString('o');input_binding_digest=[string]$task.input_binding_digest;output_artifact_type='workflow_session_record';output_contract_version=[string]$task.task_contract_version;output_artifact_id=[string]$payloadObject.session_record_id;output_revision=1;result_status=$DecisionStatus;requested_action=$RequestedAction;source_artifact_ids=@($task.input_artifact_bindings|ForEach-Object{[string]$_.artifact_id});quality_status='pass';delivery_eligibility='trace_only';check_ids=@('R7-H5-FINAL-HUMAN-GATE');payload=$payloadObject;evidence_refs=@();idempotency_key=[string]$task.idempotency_key;write_intent='submit_for_deterministic_commit';requested_machine_writes=@()}
  $path=Resolve-R7RuntimePath $sessionRoot "intermediate/r7/submissions/$submissionId.json";Write-P0EvidenceAtomicText $path (ConvertTo-P0EvidenceJsonText $submission);return New-R7RuntimeResult 'submission_built' 0 ([pscustomobject]@{SubmissionPath=$path.Substring($sessionRoot.Length+1).Replace('\','/');SubmissionId=$submissionId}) @()
}
