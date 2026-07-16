param(
  [string]$ProjectRoot=(Split-Path -Parent $PSScriptRoot),
  [string]$WorkRoot='',
  [string]$ReportPath=''
)
$ErrorActionPreference='Stop'
$ProjectRoot=[IO.Path]::GetFullPath($ProjectRoot)
if([string]::IsNullOrWhiteSpace($WorkRoot)){$WorkRoot=Join-Path $ProjectRoot 'state/checks/r7-l3-h4-hotspot-route-work'}
if([string]::IsNullOrWhiteSpace($ReportPath)){$ReportPath=Join-Path $ProjectRoot 'state/checks/r7-l3-h4-hotspot-route-report.json'}
$WorkRoot=[IO.Path]::GetFullPath($WorkRoot)
if(-not$WorkRoot.StartsWith($ProjectRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'work_root_outside_project'}
if(Test-Path -LiteralPath $WorkRoot){Remove-Item -LiteralPath $WorkRoot -Recurse -Force}
New-Item -ItemType Directory -Path $WorkRoot -Force|Out-Null
. (Join-Path $ProjectRoot 'tools/R7SemanticRuntime.ps1')
. (Join-Path $ProjectRoot 'tools/R7CandidateRuntime.ps1')
. (Join-Path $ProjectRoot 'tools/R7HumanRevisionRuntime.ps1')
. (Join-Path $ProjectRoot 'tools/R7HotspotContractHelper.ps1')
. (Join-Path $ProjectRoot 'tools/R7HotspotRuntime.ps1')
. (Join-Path $ProjectRoot 'tools/R7HotspotFreshnessRuntime.ps1')

$results=[Collections.Generic.List[object]]::new()
function Add-Result([string]$Id,[bool]$Pass,[object[]]$Evidence){$results.Add([pscustomobject]@{case_id=$Id;status=$(if($Pass){'pass'}else{'fail'});evidence=[object[]]$Evidence})}
function Write-Json([string]$Path,[object]$Value){Write-P0EvidenceAtomicText $Path (ConvertTo-P0EvidenceJsonText $Value)}

$digest='sha256:'+('1'*64)
$now='2026-07-16T00:00:00+08:00'
$registries=Get-R7RuntimeRegistries $ProjectRoot
$plan=New-R7RuntimePlan 'R7-L3-H4-REDACTED' 'hotspot_to_delivery_single_v0.5' $registries 'no_provider'
$planErrors=@(Test-P0PlanContract $plan)
$order=@($plan.steps|Where-Object{$_.node_id-ne'session_plan'}|ForEach-Object{[string]$_.node_id})
$visualExpected=@('visual_need_analysis','visual_intent_decision_set','visual_source_route_decision_set','visual_prompt_brief_set','visual_production_l3','visual_asset_review_set','visual_asset_finalize_l3')
$visualActual=@($order[([Array]::IndexOf([string[]]$order,'visual_need_analysis'))..([Array]::IndexOf([string[]]$order,'visual_asset_finalize_l3'))])
$strategyIndex=[Array]::IndexOf([string[]]$order,'hotspot_research_request_commit')
$researchIndex=[Array]::IndexOf([string[]]$order,'hotspot_research')
$freshnessReviewIndex=[Array]::IndexOf([string[]]$order,'delivery_topic_freshness_review')
$freshnessApplyIndex=[Array]::IndexOf([string[]]$order,'delivery_topic_freshness_apply')
$candidateIndex=[Array]::IndexOf([string[]]$order,'delivery_candidate_compile_h7')
Add-Result 'H4-001-current-hotspot-v05-plan' ($planErrors.Count-eq0-and[string]$plan.plan_schema_id-eq'taoge://schemas/p0/session-execution-plan/v1.2'-and$strategyIndex-eq0-and$researchIndex-eq1-and[string]::Join('|',$visualActual)-eq[string]::Join('|',$visualExpected)-and$freshnessReviewIndex-gt[Array]::IndexOf([string[]]$order,'cover_design')-and$freshnessApplyIndex-eq$freshnessReviewIndex+1-and$candidateIndex-eq$freshnessApplyIndex+1) @($planErrors+$visualActual)

$old=@($registries.Blueprints.blueprints|Where-Object{$_.blueprint_id-eq'hotspot_to_delivery_single_v0.4'})|Select-Object -First 1
Add-Result 'H4-002-v04-replay-only' ([string]$old.activation_status-eq'historical_replay_only_superseded_by_hotspot_v05') @([string]$old.activation_status)

$session=Join-Path $WorkRoot 'R7-L3-H4-SESSION'
New-Item -ItemType Directory -Path $session -Force|Out-Null
$identityPath=Resolve-R7RuntimePath $session 'intermediate/account-startup/account-identity-binding.json'
$snapshotPath=Resolve-R7RuntimePath $session 'intermediate/account-startup/account-snapshot.v0.2.json'
$policyPath=Resolve-R7RuntimePath $session 'intermediate/r5/radar-policy.json'
Write-Json $identityPath ([pscustomobject]@{identity_binding_id='IDENTITY-REDACTED';binding_status='bound'})
Write-Json $snapshotPath ([pscustomobject]@{snapshot_id='SNAP-REDACTED';account_snapshot_status='snapshot_ready';snapshot_at=$now})
Write-Json $policyPath ([pscustomobject]@{radar_policy_id='POLICY-REDACTED';policy_status='ready';priority_mode='direct_used_car_first';spillover_rule='verified_direct_candidates_below_three'})
$init=Initialize-R7RuntimeSession $ProjectRoot $session 'hotspot_to_delivery_single_v0.5' 'no_provider'
$requestCommit=Invoke-R7DeterministicNode $ProjectRoot $session
$requestItem=Get-R7HotspotCurrentArtifact $session 'hotspot_research_request'
$researchTaskResult=Prepare-R7RuntimeTask $ProjectRoot $session
$researchTask=$researchTaskResult.Data.Task
$request=$requestItem.Payload
$strategyBound=([string]$request.account_identity_ref.sha256-eq(Get-R7RuntimeHash $identityPath))-and([string]$request.account_snapshot_ref.sha256-eq(Get-R7RuntimeHash $snapshotPath))-and([string]$request.radar_policy_ref.sha256-eq(Get-R7RuntimeHash $policyPath))-and([string]$request.requested_at-eq$now)
$taskBound=([string]$researchTask.schema_id-eq'taoge://schemas/r7/semantic-task-envelope/v0.6')-and([string]$researchTask.node_id-eq'hotspot_research')-and@($researchTask.input_artifact_bindings).Count-eq1-and[string]$researchTask.input_artifact_bindings[0].artifact_id-eq[string]$request.research_request_id
Add-Result 'H4-003-strategy-to-research-request' ($init.ExitCode-eq0-and$requestCommit.ExitCode-eq0-and$strategyBound-and$taskBound) @([string]$init.ResultCode,[string]$requestCommit.ResultCode,[string]$researchTaskResult.ResultCode,[string]$researchTask.schema_id)

$waitingPayload=[pscustomobject]@{schema_id='taoge://schemas/r7/hotspot-research-set/v0.1';schema_version='0.1.0';research_set_id='RESEARCH-WAIT-001';research_set_revision=1;account_identity_ref=$request.account_identity_ref;account_snapshot_ref=$request.account_snapshot_ref;radar_policy_ref=$request.radar_policy_ref;research_request_ref=$requestItem.Ref;research_run_record=[pscustomobject]@{run_status='waiting_external'};signals=@();events=@();candidates=@();topic_options=@();topic_evidence_packets=@();panel_model=[pscustomobject]@{ordered_topic_option_refs=@();recommended_topic_ref=$null;recommendation_reason='External source access is incomplete.'};source_records=@();ledger_write_refs=@();component_digest_map=[pscustomobject]@{};researched_at=$now;research_set_status='waiting_external'}
$waitingPath=Resolve-R7RuntimePath $session 'intermediate/r7/fixture-research-wait.json'
Write-Json $waitingPath $waitingPayload
$waitingBuild=New-R7RuntimeSubmissionFromPayload $ProjectRoot $session ([string]$researchTask.task_envelope_id) $waitingPath 'waiting_external'
$waitingSubmit=if($waitingBuild.ExitCode-eq0){Submit-R7RuntimeArtifact $ProjectRoot $session ([string]$waitingBuild.Data.SubmissionPath)}else{$waitingBuild}
$resume=Prepare-R7RuntimeTask $ProjectRoot $session
$researchPointer=Resolve-R7RuntimePath $session 'intermediate/r7/current/hotspot_research_set.json'
Add-Result 'H4-004-research-wait-resume' ($waitingBuild.ExitCode-eq0-and$waitingSubmit.ResultCode-eq'semantic_waiting'-and$waitingSubmit.ExitCode-eq2-and-not(Test-Path -LiteralPath $researchPointer)-and[string]$resume.Data.Task.task_envelope_id-eq[string]$researchTask.task_envelope_id) @([string]$waitingBuild.ResultCode,[string]$waitingSubmit.ResultCode,[string]$resume.ResultCode)

$previousRequest=[pscustomobject]@{Ref=$requestItem.Ref;Payload=$request}
$selected=[pscustomobject]@{selected_topic_source_id='SOURCE-SELECTED-001';account_snapshot_ref=$request.account_snapshot_ref;radar_policy_ref=$request.radar_policy_ref;research_set_ref=[pscustomobject]@{artifact_id='RESEARCH-001';revision=1;sha256=$digest};selection_panel_ref=[pscustomobject]@{artifact_id='PANEL-001';revision=1;sha256=$digest}}
$freshnessRef=[pscustomobject]@{artifact_id='FRESHNESS-001';revision=1;sha256=$digest}
$reversal=[pscustomobject]@{checked_at='2026-07-16T01:00:00+08:00'}
$revalidation=New-R7HotspotRevalidationRequest $previousRequest $selected $reversal $freshnessRef
$reversalPlan=New-R7HotspotReplanPlan $plan 'hotspot_research' 'topic_revalidation_replan' @([pscustomobject]@{artifact_id=[string]$revalidation.research_request_id;status='carried_forward'}) @([pscustomobject]@{artifact_id='SOURCE-SELECTED-001';status='invalidated'})
$reversalErrors=@(Test-P0PlanContract $reversalPlan)
$reversalBranch=@($reversalPlan.steps|Where-Object{$_.step_id-match'-R2$'})
Add-Result 'H4-005-source-reversal-recovery' ($reversalErrors.Count-eq0-and[string]$revalidation.request_mode-eq'revalidation_after_reversal'-and$null-eq$revalidation.triggering_decision_ref-and[string]$revalidation.triggering_freshness_review_ref.artifact_id-eq'FRESHNESS-001'-and[string]$reversalBranch[0].node_id-eq'hotspot_research'-and[string]$reversalBranch[-1].node_id-eq'final_human_gate_h7') @($reversalErrors+@($reversalBranch|ForEach-Object{[string]$_.node_id}))

$materialPlan=New-R7HotspotReplanPlan $plan 'hotspot_content_brief' 'semantic_update_replan' @([pscustomobject]@{artifact_id='SOURCE-SELECTED-002';status='carried_forward'}) @([pscustomobject]@{artifact_id='BRIEF-OLD';status='invalidated'})
$materialErrors=@(Test-P0PlanContract $materialPlan)
$materialBranch=@($materialPlan.steps|Where-Object{$_.step_id-match'-R2$'})
$materialVisual=@($materialBranch|Where-Object{$_.node_id-in$visualExpected})
Add-Result 'H4-006-material-update-recovery' ($materialErrors.Count-eq0-and[string]$materialBranch[0].node_id-eq'hotspot_content_brief'-and$materialVisual.Count-eq$visualExpected.Count-and[string]$materialBranch[-1].node_id-eq'final_human_gate_h7') @($materialErrors+@($materialBranch|ForEach-Object{[string]$_.node_id}))

$revisionRequest=[pscustomobject]@{revision_request_id='DREQ-H4-001';request_digest=$digest;restart_from_node_id='visual_source_route_decision_set';carried_forward_artifact_refs=@([pscustomobject]@{artifact_id='VIS-INTENT-001';sha256=$digest});invalidated_artifact_refs=@([pscustomobject]@{artifact_id='VIS-ROUTE-001';sha256=$digest})}
$visualReplan=New-R7HumanRevisionPlan $plan $revisionRequest
$visualErrors=@(Test-P0PlanContract $visualReplan)
$visualBranch=@($visualReplan.steps|Where-Object{$_.step_id-match'-R2$'})
$owner=Get-R7RevisionOwnerNode 'visual_route' 'hotspot_to_delivery_single_v0.5'
Add-Result 'H4-007-scoped-visual-revision' ($visualErrors.Count-eq0-and$owner-eq'visual_source_route_decision_set'-and[string]$visualBranch[0].node_id-eq'visual_source_route_decision_set'-and[string]$visualBranch[-1].node_id-eq'final_human_gate_h7') @($visualErrors+@($visualBranch|ForEach-Object{[string]$_.node_id}))

$fixture=Get-Content -LiteralPath (Join-Path $ProjectRoot 'examples/r7-l3-h4-hotspot-route-fixture/cases.json') -Raw -Encoding UTF8|ConvertFrom-Json
$compat=Get-Content -LiteralPath (Join-Path $ProjectRoot 'templates/schema/r7/compatibility-matrix.v0.6.json') -Raw -Encoding UTF8|ConvertFrom-Json
$currentHotspot=@($compat.entries|Where-Object{$_.workflow_contract-eq'hotspot_to_delivery_single_v0.5'})
$oldHotspot=@($compat.entries|Where-Object{$_.workflow_contract-eq'hotspot_to_delivery_single_v0.4'})
Add-Result 'H4-008-redacted-fixture-and-compatibility' ([string]$fixture.privacy_class-eq'public_redacted_synthetic'-and@($fixture.cases).Count-eq7-and$currentHotspot.Count-eq1-and$currentHotspot[0].plan_contract-eq'p0-session-execution-plan-v1.2'-and$oldHotspot.Count-eq1-and$oldHotspot[0].new_session_status-eq'historical_replay_only') @([string]$fixture.privacy_class,[string]$compat.status)

$report=[pscustomobject]@{schema_id='taoge://reports/r7/l3-h4-hotspot-route/v0.1';schema_version='0.1';generated_at=[DateTimeOffset]::UtcNow.ToString('o');fixture_privacy='public_redacted_synthetic';case_count=$results.Count;passed_count=@($results|Where-Object{$_.status-eq'pass'}).Count;failed_count=@($results|Where-Object{$_.status-eq'fail'}).Count;project_maturity='L2.8';real_provider_invocations=0;real_network_calls=0;results=[object[]]$results.ToArray()}
Write-P0EvidenceAtomicText $ReportPath (ConvertTo-P0EvidenceJsonText $report)
$report|ConvertTo-Json -Depth 30
if($report.failed_count){exit 1}
