Set-StrictMode -Version 2.0

if(-not(Get-Command New-R7AppliedSelectedTopicSource -ErrorAction SilentlyContinue)){
  . (Join-Path $PSScriptRoot 'R7HotspotContractHelper.ps1')
}

function Get-R7FreshnessArtifactRef {
  param([object]$Item)
  return [ordered]@{artifact_id=[string]$Item.Pointer.artifact_id;revision=[int]$Item.Pointer.revision;sha256=[string]$Item.Pointer.sha256}
}

function New-R7HotspotReplanPlan {
  param([object]$OldPlan,[string]$RestartNodeId,[string]$Reason,[object[]]$CarriedForwardRefs,[object[]]$InvalidatedRefs)
  $restartIndex=-1;for($i=0;$i-lt@($OldPlan.steps).Count;$i++){if([string]$OldPlan.steps[$i].node_id-eq$RestartNodeId){$restartIndex=$i;break}}
  if($restartIndex-lt0){throw "replan_restart_node_missing:$RestartNodeId"}
  $applyIndex=-1;for($i=0;$i-lt@($OldPlan.steps).Count;$i++){if([string]$OldPlan.steps[$i].node_id-eq'delivery_topic_freshness_apply'){$applyIndex=$i;break}}
  if($applyIndex-lt0){throw 'replan_apply_node_missing'}
  $revision=[int]$OldPlan.plan_revision+1;$steps=[Collections.Generic.List[object]]::new()
  foreach($step in @($OldPlan.steps)){$steps.Add($step)}
  $previous=[string]$OldPlan.steps[$applyIndex].step_id
  for($i=$restartIndex;$i-lt@($OldPlan.steps).Count;$i++){
    $old=$OldPlan.steps[$i]
    if([string]$old.node_id-in@('session_plan','delivery_topic_freshness_review','delivery_topic_freshness_apply')){continue}
    $copy=[ordered]@{}
    foreach($name in (Get-R7PropertyNames $old)){$copy[$name]=$old.$name}
    $copy.step_id="$([string]$old.step_id)-R$revision";$copy.requires_step_ids=@($previous);$steps.Add($copy);$previous=[string]$copy.step_id
  }
  $plan=[ordered]@{}
  foreach($name in (Get-R7PropertyNames $OldPlan)){$plan[$name]=$OldPlan.$name}
  $plan.plan_id="PLAN-$($OldPlan.session_id)-R7-$('{0:000}'-f$revision)";$plan.plan_revision=$revision;$plan.supersedes_plan_id=[string]$OldPlan.plan_id;$plan.restart_from_node_id=$RestartNodeId;$plan.replan_reason=$Reason;$plan.carried_forward_artifact_refs=[object[]]$CarriedForwardRefs;$plan.invalidated_artifact_refs=[object[]]$InvalidatedRefs;$plan.steps=[object[]]$steps.ToArray()
  $document=[pscustomobject](($plan|ConvertTo-Json -Depth 60)|ConvertFrom-Json);$errors=@(Test-P0PlanContract $document);if($errors.Count){throw ('replan_plan_contract_failed:'+($errors-join';'))}
  return $document
}

function Test-R7HotspotReplanAccounting {
  param([object]$OldPlan,[object]$NewPlan)
  $errors=[Collections.Generic.List[string]]::new()
  if([int]$NewPlan.plan_revision-ne([int]$OldPlan.plan_revision+1)-or[string]$NewPlan.supersedes_plan_id-ne[string]$OldPlan.plan_id){$errors.Add('replan_revision_chain_invalid')}
  if([string]$NewPlan.restart_from_node_id-notin@('hotspot_content_brief','hotspot_research')){$errors.Add('replan_restart_node_invalid')}
  $ids=@{};foreach($step in @($NewPlan.steps)){if($ids.ContainsKey([string]$step.step_id)){$errors.Add("replan_step_duplicate:$($step.step_id)")}else{$ids[[string]$step.step_id]=$true}}
  $branch=@($NewPlan.steps|Where-Object{[string]$_.step_id-match"-R$([int]$NewPlan.plan_revision)$"});if($branch.Count-lt1){$errors.Add('replan_branch_missing')}
  if(@($NewPlan.carried_forward_artifact_refs|Where-Object{[string]$_.status-eq'new_succeeded'}).Count){$errors.Add('replan_carried_forward_misclassified')}
  return [object[]]$errors.ToArray()
}

function Write-R7FreshnessReplanEvent {
  param([string]$EventPath,[object]$Plan,[object]$Step,[string]$EventType,[string]$IdempotencyKey,[string]$PayloadDigest,[string]$ResultCode,[string]$Summary,[string]$StateBefore='succeeded',[string]$StateAfter='succeeded')
  $existing=@(Get-P0EvidenceEvents $EventPath|Where-Object{$_.event_type-eq$EventType-and$_.idempotency_key-eq$IdempotencyKey})|Select-Object -First 1
  if($null-ne$existing){if([string]$existing.payload_digest-ne$PayloadDigest){throw "replan_idempotency_conflict:$EventType"};return $existing}
  $events=@(Get-P0EvidenceEvents $EventPath);$write=Write-P0EvidenceEvent -EventPath $EventPath -Plan $Plan -StepId ([string]$Step.step_id) -EventType $EventType -EventSource 'runner' -StateBefore $StateBefore -StateAfter $StateAfter -PayloadDigest $PayloadDigest -IdempotencyKey $IdempotencyKey -ExpectedLastSequenceNo $events.Count -ResultCode $ResultCode -SafeSummary $Summary -OutputArtifactIds @() -InputDigest $PayloadDigest -ExecutionAttemptId "ATT-$($Plan.session_id)-replan-$($Plan.plan_revision)"
  if($write.ExitCode-ne0){throw "replan_event_write_failed:$($write.ResultCode)"};return $write.Event
}

function Invoke-R7HotspotTwoStageReplan {
  param([string]$SessionRoot,[object]$OldPlan,[object]$SelectedSourceRef,[string]$RestartNodeId,[string]$Reason,[object[]]$AdditionalCarriedRefs=@())
  $eventPath=Join-Path $SessionRoot 'intermediate/p0/execution-events.jsonl';$applyStep=@($OldPlan.steps|Where-Object{$_.node_id-eq'delivery_topic_freshness_apply'})|Select-Object -First 1
  if($null-eq$applyStep){throw 'replan_apply_step_missing'}
  $key="$($OldPlan.plan_id)|$($SelectedSourceRef.artifact_id)|$($SelectedSourceRef.revision)|$RestartNodeId";$digest=Get-R7HotspotCanonicalDigest ([ordered]@{key=$key;source=$SelectedSourceRef;reason=$Reason})
  [void](Write-R7FreshnessReplanEvent $eventPath $OldPlan $applyStep 'workflow.replan.requested.v1' "$key`:requested" $digest 'replan_requested' 'Freshness apply requested a versioned workflow replan')
  $applyIndex=[array]::IndexOf(@($OldPlan.steps|ForEach-Object{[string]$_.node_id}),'delivery_topic_freshness_apply')
  foreach($step in @($OldPlan.steps|Select-Object -Skip ($applyIndex+1))){
    $events=@(Get-P0EvidenceEvents $eventPath);if(@($events|Where-Object{$_.step_id-eq$step.step_id}).Count){continue}
    [void](Write-R7FreshnessReplanEvent $eventPath $OldPlan $step 'workflow.step_stale_replanned.v1' "$key`:stale:$($step.step_id)" $digest 'stale_replanned' 'Old downstream step skipped after freshness replan' 'ready' 'skipped')
  }
  $carried=@([ordered]@{artifact_id=[string]$SelectedSourceRef.artifact_id;revision=[int]$SelectedSourceRef.revision;sha256=[string]$SelectedSourceRef.sha256;status='carried_forward'})+@($AdditionalCarriedRefs)
  $invalidated=@($OldPlan.steps|Select-Object -Skip $([array]::IndexOf(@($OldPlan.steps|ForEach-Object{[string]$_.node_id}),$RestartNodeId))|ForEach-Object{[ordered]@{step_id=[string]$_.step_id;node_id=[string]$_.node_id;reason=$Reason}})
  $newPlan=New-R7HotspotReplanPlan $OldPlan $RestartNodeId $Reason $carried $invalidated;$planText=ConvertTo-P0EvidenceJsonText $newPlan;$planDigest=Get-R7RuntimeTextDigest $planText
  $revisionRelative="intermediate/p0/plan-revisions/$($newPlan.plan_id).json";$commitRelative="intermediate/p0/plan-commits/$($newPlan.plan_id).json";$revisionPath=Resolve-R7RuntimePath $SessionRoot $revisionRelative;$commitPath=Resolve-R7RuntimePath $SessionRoot $commitRelative
  if(Test-Path $revisionPath){if((Get-R7RuntimeHash $revisionPath)-ne$planDigest){throw 'replan_revision_conflict'}}else{Write-P0EvidenceAtomicText $revisionPath $planText}
  $commit=[ordered]@{schema_id='taoge://schemas/r7/plan-commit/v0.1';schema_version='0.1';plan_id=[string]$newPlan.plan_id;plan_revision=[int]$newPlan.plan_revision;supersedes_plan_id=[string]$newPlan.supersedes_plan_id;plan_path=$revisionRelative;plan_sha256=$planDigest;idempotency_key=$key;commit_status='prepared';committed_at=[DateTimeOffset]::UtcNow.ToString('o')};$commitText=ConvertTo-P0EvidenceJsonText $commit
  if(Test-Path $commitPath){$existing=Read-R7JsonFile $commitPath;if([string]$existing.plan_sha256-ne$planDigest){throw 'replan_commit_conflict'}}else{Write-P0EvidenceAtomicText $commitPath $commitText}
  Write-P0EvidenceAtomicText (Join-Path $SessionRoot 'intermediate/p0/session-execution-plan.json') $planText
  $commit.commit_status='activated';Write-P0EvidenceAtomicText $commitPath (ConvertTo-P0EvidenceJsonText $commit)
  [void](Write-R7FreshnessReplanEvent $eventPath $newPlan $applyStep 'workflow.replanned.v1' "$key`:activated" $planDigest 'workflow_replanned' 'Versioned replan activated after selected-source commit')
  $projection=Update-P0StateProjection $SessionRoot $newPlan $eventPath $false;if($projection.ExitCode-ne0){throw "replan_projection_failed:$($projection.ResultCode)"};[void](Write-P0ResumeSummary $SessionRoot $newPlan $projection.Projection)
  return [pscustomobject]@{Plan=$newPlan;Projection=$projection.Projection;PlanPath=$revisionRelative;CommitPath=$commitRelative;IdempotencyKey=$key}
}

function New-R7HotspotRevalidationRequest {
  param([object]$PreviousRequestItem,[object]$SelectedSource,[object]$FreshnessReview,[object]$FreshnessReviewRef)
  $basis=[ordered]@{previous=$PreviousRequestItem.Ref;selected_source_id=[string]$SelectedSource.selected_topic_source_id;freshness=$FreshnessReviewRef};$suffix=(Get-R7HotspotCanonicalDigest $basis).Substring(7,12)
  $request=[ordered]@{schema_id='taoge://schemas/r7/hotspot-research-request/v0.1';schema_version='0.1.0';research_request_id="HRQ-REVALIDATE-$suffix";research_request_revision=1;supersedes_request_ref=$PreviousRequestItem.Ref;account_identity_ref=$PreviousRequestItem.Payload.account_identity_ref;account_snapshot_ref=$SelectedSource.account_snapshot_ref;radar_policy_ref=$SelectedSource.radar_policy_ref;triggering_decision_ref=$null;triggering_freshness_review_ref=$FreshnessReviewRef;prior_research_set_ref=$SelectedSource.research_set_ref;prior_panel_ref=$SelectedSource.selection_panel_ref;request_mode='revalidation_after_reversal';scope_delta=$null;manual_source_input_set_ref=$null;requested_at=[string]$FreshnessReview.checked_at;request_status='ready'}
  $document=[pscustomobject](($request|ConvertTo-Json -Depth 40)|ConvertFrom-Json);$errors=@(Test-R7HotspotResearchRequest $document);if($errors.Count){throw ('revalidation_request_contract_failed:'+($errors-join';'))};return $document
}

function Commit-R7HotspotRevalidationRequest {
  param([string]$SessionRoot,[object]$Plan,[object]$ApplyStep,[object]$Request)
  $artifactId=[string]$Request.research_request_id;$relative="intermediate/r7/revisions/hotspot_research_request/$artifactId.json";$path=Resolve-R7RuntimePath $SessionRoot $relative;$text=ConvertTo-P0EvidenceJsonText $Request;$digest=Get-R7RuntimeTextDigest $text
  if(Test-Path $path){if((Get-R7RuntimeHash $path)-ne$digest){throw 'revalidation_request_revision_conflict'}}else{Write-P0EvidenceAtomicText $path $text}
  $eventPath=Join-Path $SessionRoot 'intermediate/p0/execution-events.jsonl';$events=@(Get-P0EvidenceEvents $eventPath);$key="$($Plan.session_id):revalidation_request:$artifactId";$existing=@($events|Where-Object{$_.event_type-eq'artifact.materialized.v1'-and$_.idempotency_key-eq$key})|Select-Object -First 1;$predicted=if($null-ne$existing){[string]$existing.event_id}else{'EVT-'+(([string]$Plan.session_id-replace'[^A-Za-z0-9_-]','-'))+'-'+($events.Count+1).ToString('0000')}
  [void](Write-P0EvidenceLineage $SessionRoot $artifactId 'hotspot_research_request' $predicted @([string]$Request.triggering_freshness_review_ref.artifact_id) $relative $digest 'pass' 'trace_only' @('R7-F44','R7-F66'))
  $pointer=[ordered]@{schema_id='taoge://schemas/r7/semantic-current-pointer/v0.1';schema_version='0.1';artifact_type='hotspot_research_request';artifact_id=$artifactId;revision=1;revision_path=$relative;sha256=$digest;status='request_ready';task_envelope_id="TASK-$($Plan.session_id)-freshness-revalidation-request";submission_id="RUN-$($Plan.session_id)-freshness-revalidation-request";producer_event_id=$predicted;committed_at=[DateTimeOffset]::UtcNow.ToString('o')};Write-P0EvidenceAtomicText (Join-Path $SessionRoot 'intermediate/r7/current/hotspot_research_request.json') (ConvertTo-P0EvidenceJsonText $pointer)
  if($null-eq$existing){$write=Write-P0EvidenceEvent -EventPath $eventPath -Plan $Plan -StepId ([string]$ApplyStep.step_id) -EventType 'artifact.materialized.v1' -EventSource 'runner' -StateBefore 'succeeded' -StateAfter 'succeeded' -PayloadDigest $digest -IdempotencyKey $key -ExpectedLastSequenceNo $events.Count -ResultCode 'revalidation_request_materialized' -SafeSummary 'Reversal materialized a new freshness-bound research request before replan' -OutputArtifactIds @($artifactId) -InputDigest ([string]$Request.triggering_freshness_review_ref.sha256) -ExecutionAttemptId "ATT-$($Plan.session_id)-revalidation-request-1";if($write.ExitCode-ne0){throw "revalidation_request_event_failed:$($write.ResultCode)"}}
  return [ordered]@{artifact_id=$artifactId;revision=1;sha256=$digest;status='carried_forward'}
}

function Commit-R7SelectedSourceRevision {
  param([string]$SessionRoot,[object]$Plan,[object]$Step,[object]$Payload,[object]$ReviewRef,[string]$ResultStatus)
  $revision=[int]$Payload.selected_topic_source_revision;$artifactId=[string]$Payload.selected_topic_source_id;$relative="intermediate/r7/revisions/selected_topic_source/$artifactId-r$('{0:000}'-f$revision).json";$path=Resolve-R7RuntimePath $SessionRoot $relative;$text=ConvertTo-P0EvidenceJsonText $Payload;$digest=Get-R7RuntimeTextDigest $text
  if(Test-Path $path){if((Get-R7RuntimeHash $path)-ne$digest){throw 'selected_source_revision_conflict'}}else{Write-P0EvidenceAtomicText $path $text}
  $eventPath=Join-Path $SessionRoot 'intermediate/p0/execution-events.jsonl';$events=@(Get-P0EvidenceEvents $eventPath);$predicted='EVT-'+(([string]$Plan.session_id-replace'[^A-Za-z0-9_-]','-'))+'-'+($events.Count+1).ToString('0000')
  [void](Write-P0EvidenceLineage $SessionRoot $artifactId 'selected_topic_source' $predicted @([string]$ReviewRef.artifact_id) $relative $digest 'pass' 'trace_only' @('R7-H6B-freshness-apply') -Revision $revision)
  $pointer=[ordered]@{schema_id='taoge://schemas/r7/semantic-current-pointer/v0.1';schema_version='0.1';artifact_type='selected_topic_source';artifact_id=$artifactId;revision=$revision;revision_path=$relative;sha256=$digest;status=$ResultStatus;task_envelope_id="TASK-$($Plan.session_id)-delivery_topic_freshness_apply-deterministic";submission_id="RUN-$($Plan.session_id)-delivery_topic_freshness_apply-r$revision";producer_event_id=$predicted;committed_at=[DateTimeOffset]::UtcNow.ToString('o')};Write-P0EvidenceAtomicText (Join-Path $SessionRoot 'intermediate/r7/current/selected_topic_source.json') (ConvertTo-P0EvidenceJsonText $pointer)
  $key="$($Plan.session_id):delivery_topic_freshness_apply:$artifactId:r$revision";$existing=@($events|Where-Object{$_.event_type-eq'deterministic.result_committed.v1'-and$_.idempotency_key-eq$key})|Select-Object -First 1
  if($null-eq$existing){$write=Write-P0EvidenceEvent -EventPath $eventPath -Plan $Plan -StepId ([string]$Step.step_id) -EventType 'deterministic.result_committed.v1' -EventSource 'runner' -StateBefore 'ready' -StateAfter 'succeeded' -PayloadDigest $digest -IdempotencyKey $key -ExpectedLastSequenceNo $events.Count -ResultCode $ResultStatus -SafeSummary 'Freshness review applied as an immutable selected-source revision' -OutputArtifactIds @($artifactId) -InputDigest ([string]$ReviewRef.sha256) -ExecutionAttemptId "ATT-$($Plan.session_id)-freshness-apply-1";if($write.ExitCode-ne0){throw "freshness_apply_event_failed:$($write.ResultCode)"}}
  return [pscustomobject]@{Ref=[ordered]@{artifact_id=$artifactId;revision=$revision;sha256=$digest};Pointer=$pointer}
}

function Invoke-R7TopicFreshnessApply {
  param([string]$ProjectRoot,[string]$SessionRoot)
  try{
    $plan=Read-R7JsonFile (Join-Path $SessionRoot 'intermediate/p0/session-execution-plan.json');$projection=Read-R7JsonFile (Join-Path $SessionRoot 'intermediate/p0/state-projection.json');$step=@($plan.steps|Where-Object{$_.step_id-eq$projection.next_step_id})|Select-Object -First 1
    if($null-eq$step-or[string]$step.node_id-ne'delivery_topic_freshness_apply'){return New-R7RuntimeResult 'deterministic_node_not_current' 2 $projection @('delivery_topic_freshness_apply')}
    $sourceItem=Get-R7HotspotCurrentArtifact $SessionRoot 'selected_topic_source';$reviewItem=Get-R7HotspotCurrentArtifact $SessionRoot 'topic_freshness_review';$sourceRef=Get-R7FreshnessArtifactRef $sourceItem;$reviewRef=Get-R7FreshnessArtifactRef $reviewItem
    $applied=New-R7AppliedSelectedTopicSource $sourceItem.Payload $sourceRef $reviewItem.Payload $reviewRef;if($applied.Errors.Count){return New-R7RuntimeResult 'freshness_apply_contract_error' 1 $applied.Payload $applied.Errors}
    $committed=Commit-R7SelectedSourceRevision $SessionRoot $plan $step $applied.Payload $reviewRef $applied.ResultStatus
    if($null-ne$applied.RestartNodeId){
      $additional=@();if($applied.RestartNodeId-eq'hotspot_research'){$previousRequest=Get-R7HotspotCurrentArtifact $SessionRoot 'hotspot_research_request';$request=New-R7HotspotRevalidationRequest $previousRequest $applied.Payload $reviewItem.Payload $reviewRef;$additional=@(Commit-R7HotspotRevalidationRequest $SessionRoot $plan $step $request)}
      $replan=Invoke-R7HotspotTwoStageReplan $SessionRoot $plan $committed.Ref $applied.RestartNodeId $applied.ResultStatus $additional;return New-R7RuntimeResult 'freshness_applied_replanned' 0 ([pscustomobject]@{SelectedSourceRef=$committed.Ref;PlanId=$replan.Plan.plan_id;NextStepId=$replan.Projection.next_step_id;ResultStatus=$applied.ResultStatus}) @()
    }
    $updated=Update-P0StateProjection $SessionRoot $plan (Join-Path $SessionRoot 'intermediate/p0/execution-events.jsonl') $false;[void](Write-P0ResumeSummary $SessionRoot $plan $updated.Projection);return New-R7RuntimeResult 'freshness_applied' 0 ([pscustomobject]@{SelectedSourceRef=$committed.Ref;NextStepId=$updated.Projection.next_step_id;ResultStatus=$applied.ResultStatus}) @()
  }catch{return New-R7RuntimeResult 'freshness_apply_runtime_error' 1 $null @($_.Exception.Message)}
}
