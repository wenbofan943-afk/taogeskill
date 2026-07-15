Set-StrictMode -Version 2.0

if(-not(Get-Command Prepare-R7RuntimeTask -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'R7SemanticRuntime.ps1')}
if(-not(Get-Command Get-R7CandidateCurrentArtifact -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'R7CandidateRuntime.ps1')}
if(-not(Get-Command Test-R7DeliveryRevisionRequestV01 -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'JointVisualRevisionContract.ps1')}

function Get-R7RevisionOwnerNode {
  param([string]$ChangeClass,[string]$BlueprintId)
  switch($ChangeClass){
    'copy'{return $(if($BlueprintId-like'hotspot_*'){'hotspot_structure_plan'}else{'direct_structure_plan'})}
    'visual_need'{return 'visual_need_analysis'}
    'visual_route'{return 'visual_need_analysis'}
    'visual_asset'{return 'visual_production'}
    'evidence_annotation'{return 'visual_production'}
    'visual_text'{return 'visual_production'}
    'cover'{return 'cover_design'}
    default{throw "revision_change_class_invalid:$ChangeClass"}
  }
}

function Get-R7RevisionArtifactNode {
  param([string]$ArtifactType,[string]$BlueprintId)
  switch($ArtifactType){
    'direct_content_intake'{return 'direct_content_intake'}
    'hotspot_research_request'{return 'hotspot_research_request_commit'}
    'hotspot_research_set'{return 'hotspot_research'}
    'topic_selection_panel'{return 'topic_panel_projection'}
    'topic_selection_decision'{return 'topic_human_gate'}
    'selected_topic_source'{return 'selected_topic_source_commit'}
    'content_brief'{return $(if($BlueprintId-like'hotspot_*'){'hotspot_content_brief'}else{'content_brief'})}
    'short_video_structure_plan'{return $(if($BlueprintId-like'hotspot_*'){'hotspot_structure_plan'}else{'direct_structure_plan'})}
    'draft'{return $(if($BlueprintId-like'hotspot_*'){'hotspot_draft'}else{'direct_baseline_draft'})}
    'content_beat_map'{return 'content_beat_map'}
    'script_design_review'{return 'script_review'}
    'content_revision_decision'{return 'content_revision_gate'}
    'visual_coverage_ledger'{return 'visual_need_analysis'}
    'image_asset_set'{return 'visual_production'}
    'script_visual_alignment_review'{return 'script_visual_alignment'}
    'platform_package'{return 'platform_package'}
    'cover_composition'{return 'cover_design'}
    'topic_freshness_review'{return 'delivery_topic_freshness_review'}
    default{return $null}
  }
}

function Get-R7RevisionChangeItems {
  param([object]$ChangeDocument)
  if(Test-JVHasProperty $ChangeDocument 'change_items'){return [object[]]@($ChangeDocument.change_items)}
  return [object[]]@($ChangeDocument)
}

function New-R7HumanRevisionPlan {
  param([object]$OldPlan,[object]$Request)
  if([string]$OldPlan.plan_schema_id-ne'taoge://schemas/p0/session-execution-plan/v0.9'){throw 'human_revision_plan_v09_required'}
  $revision=[int]$OldPlan.plan_revision+1
  $oldSteps=@($OldPlan.steps)
  $orderedNodes=@($oldSteps|Where-Object{[string]$_.node_id-ne'session_plan' -and [string]$_.step_id-notmatch '-R[0-9]+$'}|ForEach-Object{[string]$_.node_id})
  $restartIndex=[Array]::IndexOf([string[]]$orderedNodes,[string]$Request.restart_from_node_id)
  if($restartIndex-lt0){throw 'human_revision_restart_node_missing'}
  $result=[Collections.Generic.List[object]]::new();foreach($step in $oldSteps){$result.Add($step)}
  $oldFinal=@($oldSteps|Where-Object{[string]$_.node_id-eq'final_human_gate'}|Select-Object -Last 1)
  if($oldFinal.Count-ne1){throw 'human_revision_final_gate_missing'}
  $previous=[string]$oldFinal[0].step_id
  for($i=$restartIndex;$i-lt$orderedNodes.Count;$i++){
    $nodeId=[string]$orderedNodes[$i]
    $source=@($oldSteps|Where-Object{[string]$_.node_id-eq$nodeId -and [string]$_.step_id-notmatch '-R[0-9]+$'}|Select-Object -First 1)
    if($source.Count-ne1){throw "human_revision_source_step_missing:$nodeId"}
    $clone=[ordered]@{}
    foreach($property in $source[0].PSObject.Properties){$clone[$property.Name]=$property.Value}
    $clone.step_id="STEP-$($OldPlan.session_id)-$nodeId-R$revision"
    $clone.requires_step_ids=@($previous)
    $result.Add([pscustomobject]$clone)
    $previous=[string]$clone.step_id
  }
  $document=[ordered]@{}
  foreach($property in $OldPlan.PSObject.Properties){$document[$property.Name]=$property.Value}
  $document.plan_id="PLAN-$($OldPlan.session_id)-R7-$('{0:000}'-f$revision)"
  $document.plan_revision=$revision
  $document.supersedes_plan_id=[string]$OldPlan.plan_id
  $document.restart_from_node_id=[string]$Request.restart_from_node_id
  $document.replan_reason='human_scoped_revision'
  $document.basis_revision_request_ref=[ordered]@{artifact_id=[string]$Request.revision_request_id;sha256=[string]$Request.request_digest}
  $document.carried_forward_artifact_refs=[object[]]@($Request.carried_forward_artifact_refs)
  $document.invalidated_artifact_refs=[object[]]@($Request.invalidated_artifact_refs)
  $document.steps=[object[]]$result.ToArray()
  return [pscustomobject](($document|ConvertTo-Json -Depth 60)|ConvertFrom-Json)
}

function Complete-R7ActiveRevisionRequest {
  param([string]$SessionRoot,[object]$Plan)
  $pointerPath=Resolve-R7RuntimePath $SessionRoot 'intermediate/r7/current/delivery_revision_request.json'
  if(-not(Test-Path -LiteralPath $pointerPath -PathType Leaf)){return New-R7RuntimeResult 'revision_request_not_present' 0 $null @()}
  $pointer=Read-R7JsonFile $pointerPath
  if([string]$pointer.status-ne'active'){return New-R7RuntimeResult 'revision_request_already_closed' 0 $pointer @()}
  $current=Read-R7JsonFile (Resolve-R7RuntimePath $SessionRoot ([string]$pointer.revision_path))
  if($null-eq$Plan.basis_revision_request_ref-or[string]$Plan.basis_revision_request_ref.artifact_id-ne[string]$current.revision_request_id){return New-R7RuntimeResult 'revision_request_plan_binding_mismatch' 1 $current @()}
  $closed=[ordered]@{};foreach($property in $current.PSObject.Properties){$closed[$property.Name]=$property.Value};$closed.request_revision=[int]$current.request_revision+1;$closed.request_status='completed'
  $closedObject=[pscustomobject](($closed|ConvertTo-Json -Depth 50)|ConvertFrom-Json);$relative="intermediate/r7/revisions/delivery_revision_request/$($closed.revision_request_id).status-$($closed.request_revision).json";$path=Resolve-R7RuntimePath $SessionRoot $relative;Write-P0EvidenceAtomicText $path (ConvertTo-P0EvidenceJsonText $closedObject)
  $newPointer=[ordered]@{};foreach($property in $pointer.PSObject.Properties){$newPointer[$property.Name]=$property.Value};$newPointer.revision=[int]$closed.request_revision;$newPointer.revision_path=$relative;$newPointer.sha256=Get-R7RuntimeHash $path;$newPointer.status='completed';$newPointer.committed_at=[DateTimeOffset]::UtcNow.ToString('o');Write-P0EvidenceAtomicText $pointerPath (ConvertTo-P0EvidenceJsonText $newPointer)
  return New-R7RuntimeResult 'revision_request_completed' 0 ([pscustomobject]@{RevisionRequestId=[string]$closed.revision_request_id;Revision=[int]$closed.request_revision}) @()
}

function Invoke-R7HumanRevisionRequest {
  param([string]$ProjectRoot,[string]$Session,[string]$TaskEnvelopeId,[string]$ChangeItemsPath,[string]$UserInstruction='')
  $sessionRoot=[IO.Path]::GetFullPath($Session)
  try{
    $absoluteChangePath=if([IO.Path]::IsPathRooted($ChangeItemsPath)){[IO.Path]::GetFullPath($ChangeItemsPath)}else{Resolve-R7RuntimePath $sessionRoot $ChangeItemsPath}
    if(-not(Test-Path -LiteralPath $absoluteChangePath -PathType Leaf)){return New-R7RuntimeResult 'revision_change_items_missing' 1 $null @($ChangeItemsPath)}
    $changeDocument=Read-R7JsonFile $absoluteChangePath
    $rawItems=@(Get-R7RevisionChangeItems $changeDocument)
    if($rawItems.Count-lt1){return New-R7RuntimeResult 'revision_change_items_empty' 1 $changeDocument @()}
    if([string]::IsNullOrWhiteSpace($UserInstruction)){$UserInstruction=if(Test-JVHasProperty $changeDocument 'user_instruction'){[string]$changeDocument.user_instruction}else{[string]::Join('; ',@($rawItems|ForEach-Object{[string]$_.instruction}))}}
    if([string]::IsNullOrWhiteSpace($UserInstruction)){return New-R7RuntimeResult 'revision_user_instruction_missing' 1 $changeDocument @()}
    $activePointerPath=Resolve-R7RuntimePath $sessionRoot 'intermediate/r7/current/delivery_revision_request.json'
    if(Test-Path -LiteralPath $activePointerPath){
      $activePointer=Read-R7JsonFile $activePointerPath;$activeRequest=Read-R7JsonFile (Resolve-R7RuntimePath $sessionRoot ([string]$activePointer.revision_path))
      if($activeRequest.request_status-eq'active'){
        $incomingComparable=[ordered]@{user_instruction=$UserInstruction.Trim();items=[object[]]@($rawItems|ForEach-Object{[ordered]@{target_artifact_id=[string]$_.target_artifact_id;change_class=[string]$_.change_class;instruction=([string]$_.instruction).Trim()}})}
        $activeComparable=[ordered]@{user_instruction=([string]$activeRequest.user_instruction).Trim();items=[object[]]@($activeRequest.change_items|ForEach-Object{[ordered]@{target_artifact_id=[string]$_.target_ref.artifact_id;change_class=[string]$_.change_class;instruction=([string]$_.original_instruction).Trim()}})}
        if((Get-R7RuntimeObjectDigest $incomingComparable)-eq(Get-R7RuntimeObjectDigest $activeComparable)){return New-R7RuntimeResult 'duplicate_reused' 0 $activeRequest @()}
        return New-R7RuntimeResult 'active_delivery_revision_request_exists' 1 $activeRequest @()
      }
    }
    $task=Read-R7JsonFile (Resolve-R7RuntimePath $sessionRoot "intermediate/r7/tasks/$TaskEnvelopeId.json")
    $plan=Read-P0JsonFile (Join-Path $sessionRoot 'intermediate/p0/session-execution-plan.json')
    $projection=Read-P0JsonFile (Join-Path $sessionRoot 'intermediate/p0/state-projection.json')
    if($task.node_id-ne'final_human_gate'-or[string]$plan.blueprint_version-ne'0.3'-or[string]$plan.plan_schema_id-ne'taoge://schemas/p0/session-execution-plan/v0.9'){return New-R7RuntimeResult 'human_revision_current_contract_required' 1 $task @()}
    $currentStep=@($plan.steps|Where-Object{[string]$_.step_id-eq[string]$projection.next_step_id}|Select-Object -First 1)
    if($currentStep.Count-ne1-or[string]$currentStep[0].node_id-ne'final_human_gate'){return New-R7RuntimeResult 'final_human_task_not_current' 1 $projection @()}
    $delivery=Get-R7CandidateCurrentArtifact $sessionRoot 'final_delivery'
    $candidateCurrent=Get-R7CandidateCurrentArtifact $sessionRoot 'final_delivery_render_candidate';$candidate=$candidateCurrent.Payload
    $viewport=Get-R7CandidateCurrentArtifact $sessionRoot 'viewport_acceptance_report'
    $sourceMap=@($candidate.source_map);$sourceById=@{};foreach($source in $sourceMap){$sourceById[[string]$source.artifact_id]=$source}
    $sourceMapDigest=Get-R7RuntimeObjectDigest $sourceMap;$sourceMapRef=[ordered]@{artifact_id="$($candidate.final_delivery_id):source-map";sha256=$sourceMapDigest}
    $items=[Collections.Generic.List[object]]::new();$itemNo=0
    foreach($raw in $rawItems){
      $itemNo++;$targetId=[string]$raw.target_artifact_id;$changeClass=[string]$raw.change_class;$instruction=[string]$raw.instruction
      if(-not$sourceById.ContainsKey($targetId)){return New-R7RuntimeResult 'delivery_revision_target_not_current' 1 $raw @($targetId)}
      $source=$sourceById[$targetId];$owner=Get-R7RevisionOwnerNode $changeClass ([string]$plan.blueprint_id)
      $items.Add([ordered]@{change_item_id="CHG-$($plan.session_id)-$('{0:000}'-f$itemNo)";target_ref=[ordered]@{artifact_id=$targetId;artifact_type=[string]$source.artifact_type};target_sha256=[string]$source.sha256;change_class=$changeClass;original_instruction=$instruction;normalized_instruction=$instruction.Trim();owning_producer=$owner;candidate_source_map_ref=$sourceMapRef})
    }
    $nodeOrder=@($plan.steps|Where-Object{[string]$_.node_id-ne'session_plan' -and [string]$_.step_id-notmatch '-R[0-9]+$'}|ForEach-Object{[string]$_.node_id});$restart=Get-R7RevisionRestartNode @($items) ([string[]]$nodeOrder);$restartIndex=[Array]::IndexOf([string[]]$nodeOrder,$restart)
    $invalidated=[Collections.Generic.List[object]]::new();$carried=[Collections.Generic.List[object]]::new()
    foreach($source in $sourceMap){$node=Get-R7RevisionArtifactNode ([string]$source.artifact_type) ([string]$plan.blueprint_id);$index=[Array]::IndexOf([string[]]$nodeOrder,[string]$node);$ref=[ordered]@{artifact_id=[string]$source.artifact_id;sha256=[string]$source.sha256};if($index-ge$restartIndex-and$index-ge0){$invalidated.Add($ref)}else{$carried.Add($ref)}}
    $nextRevision=[int]$plan.plan_revision+1;$requestId="DREQ-$($plan.session_id)-$('{0:000}'-f$nextRevision)"
    $request=[ordered]@{schema_id='taoge://schemas/r7/delivery-revision-request/v0.1';schema_version='0.1.0';revision_request_id=$requestId;request_revision=$nextRevision;session_id=[string]$plan.session_id;current_delivery_ref=[ordered]@{artifact_id=[string]$delivery.Pointer.artifact_id;sha256=[string]$delivery.Sha256};current_candidate_ref=[ordered]@{artifact_id=[string]$candidateCurrent.Pointer.artifact_id;sha256=[string]$candidateCurrent.Sha256};candidate_source_map_ref=$sourceMapRef;source_plan_ref=[ordered]@{artifact_id=[string]$plan.plan_id;sha256=Get-R7RuntimeObjectDigest $plan};user_instruction=$UserInstruction;normalized_action='revise_delivery';change_items=[object[]]$items.ToArray();restart_from_node_id=$restart;invalidated_artifact_refs=[object[]]$invalidated.ToArray();carried_forward_artifact_refs=[object[]]$carried.ToArray();request_digest=$null;request_status='active';created_by='human';created_at=[DateTimeOffset]::UtcNow.ToString('o')}
    $request.request_digest=Get-R7RuntimeObjectDigest ([ordered]@{session_id=$request.session_id;delivery=$request.current_delivery_ref;candidate=$request.current_candidate_ref;source_map=$request.candidate_source_map_ref;plan=$request.source_plan_ref;instruction=$request.user_instruction;items=$request.change_items;restart=$request.restart_from_node_id;invalidated=$request.invalidated_artifact_refs;carried=$request.carried_forward_artifact_refs})
    $requestObject=[pscustomobject](($request|ConvertTo-Json -Depth 50)|ConvertFrom-Json);$requestErrors=@(Test-R7DeliveryRevisionRequestV01 $requestObject $sourceMap ([string[]]$nodeOrder));if($requestErrors.Count){return New-R7RuntimeResult 'delivery_revision_request_contract_error' 1 $requestObject $requestErrors}
    if(Test-Path -LiteralPath $activePointerPath){$activePointer=Read-R7JsonFile $activePointerPath;$activeRequest=Read-R7JsonFile (Resolve-R7RuntimePath $sessionRoot ([string]$activePointer.revision_path));if($activeRequest.request_status-eq'active'){if([string]$activeRequest.request_digest-eq[string]$requestObject.request_digest){return New-R7RuntimeResult 'duplicate_reused' 0 $activeRequest @()};return New-R7RuntimeResult 'active_delivery_revision_request_exists' 1 $activeRequest @()}}
    $newPlan=New-R7HumanRevisionPlan $plan $requestObject;$planErrors=@(Test-P0PlanContract $newPlan);if($planErrors.Count){return New-R7RuntimeResult 'plan_contract_failed' 1 $newPlan $planErrors}
    $requestRelative="intermediate/r7/revisions/delivery_revision_request/$requestId.json";$requestPath=Resolve-R7RuntimePath $sessionRoot $requestRelative;Write-P0EvidenceAtomicText $requestPath (ConvertTo-P0EvidenceJsonText $requestObject)
    $requestPointer=[ordered]@{schema_id='taoge://schemas/r7/semantic-current-pointer/v0.1';schema_version='0.1';artifact_type='delivery_revision_request';artifact_id=$requestId;revision=$nextRevision;revision_path=$requestRelative;sha256=Get-R7RuntimeHash $requestPath;status='active';task_envelope_id=$TaskEnvelopeId;submission_id="HUMAN-$requestId";producer_event_id="PENDING-$requestId";committed_at=[DateTimeOffset]::UtcNow.ToString('o')};Write-P0EvidenceAtomicText $activePointerPath (ConvertTo-P0EvidenceJsonText $requestPointer)
    $record=[ordered]@{schema_id='taoge://schemas/r7/workflow-session-record/v0.2';schema_version='0.2';session_record_id="SESSIONREC-$($plan.session_id)-R$nextRevision";session_id=[string]$plan.session_id;final_delivery_ref=$request.current_delivery_ref;viewport_report_ref=[ordered]@{artifact_id=[string]$viewport.Pointer.artifact_id;sha256=[string]$viewport.Sha256};decision_status='revision_requested';requested_action='revise_delivery';target_artifact_ref=$null;delivery_revision_request_ref=[ordered]@{artifact_id=$requestId;sha256=[string]$request.request_digest};decided_by='human';decided_at=[DateTimeOffset]::UtcNow.ToString('o');next_skill='semantic-workflow-coordinator'}
    $recordRelative="intermediate/r7/revisions/workflow_session_record/$($record.session_record_id).json";Write-P0EvidenceAtomicText (Resolve-R7RuntimePath $sessionRoot $recordRelative) (ConvertTo-P0EvidenceJsonText $record)
    $planRelative="intermediate/p0/plan-revisions/$($newPlan.plan_id).json";$planPath=Resolve-R7RuntimePath $sessionRoot $planRelative;$planText=ConvertTo-P0EvidenceJsonText $newPlan;Write-P0EvidenceAtomicText $planPath $planText
    $planDigest=Get-R7RuntimeHash $planPath;$planCommit=[ordered]@{schema_id='taoge://schemas/p0/plan-commit/v0.1';schema_version='0.1';plan_id=[string]$newPlan.plan_id;plan_revision=[int]$newPlan.plan_revision;plan_sha256=$planDigest;basis_revision_request_ref=$newPlan.basis_revision_request_ref;committed_at=[DateTimeOffset]::UtcNow.ToString('o')};Write-P0EvidenceAtomicText (Resolve-R7RuntimePath $sessionRoot "intermediate/p0/plan-commits/$($newPlan.plan_id).json") (ConvertTo-P0EvidenceJsonText $planCommit)
    Write-P0EvidenceAtomicText (Join-Path $sessionRoot 'intermediate/p0/session-execution-plan.json') $planText
    $eventPath=Join-Path $sessionRoot 'intermediate/p0/execution-events.jsonl';$events=@(Get-P0EvidenceEvents $eventPath);$write=Write-P0EvidenceEvent -EventPath $eventPath -Plan $newPlan -StepId ([string]$currentStep[0].step_id) -EventType 'human.revision.requested.v1' -EventSource 'human_recorder' -StateBefore 'waiting_human' -StateAfter 'succeeded' -PayloadDigest ([string]$request.request_digest) -IdempotencyKey "$($plan.session_id):human-revision:$($request.request_digest)" -ExpectedLastSequenceNo $events.Count -ResultCode 'revision_requested' -SafeSummary 'Scoped delivery revision requested and replanned' -OutputArtifactIds @($requestId,[string]$record.session_record_id) -InputDigest ([string]$candidateCurrent.Sha256) -ExecutionAttemptId "ATT-$($plan.session_id)-human-revision-$nextRevision"
    if($write.ExitCode-ne0){return New-R7RuntimeResult $write.ResultCode $write.ExitCode $requestObject $write.Errors}
    $updated=Update-P0StateProjection $sessionRoot $newPlan $eventPath $false;if($updated.ExitCode-ne0){return New-R7RuntimeResult $updated.ResultCode $updated.ExitCode $requestObject $updated.Errors};[void](Write-P0ResumeSummary $sessionRoot $newPlan $updated.Projection)
    return New-R7RuntimeResult 'delivery_revision_replanned' 0 ([pscustomobject]@{RevisionRequestId=$requestId;RestartFromNodeId=$restart;PlanId=[string]$newPlan.plan_id;PlanRevision=[int]$newPlan.plan_revision;NextStepId=[string]$updated.Projection.next_step_id;InvalidatedCount=$invalidated.Count;CarriedForwardCount=$carried.Count}) @()
  }catch{return New-R7RuntimeResult 'delivery_revision_runtime_error' 1 $null @($_.Exception.Message)}
}
