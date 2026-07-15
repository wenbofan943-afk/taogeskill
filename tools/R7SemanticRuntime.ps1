Set-StrictMode -Version 2.0

if (-not (Get-Command Write-P0EvidenceEvent -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
  . (Join-Path $PSScriptRoot 'P0EvidenceRuntime.ps1')
}
if (-not (Get-Command Read-YamlFile -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'YamlHelper.ps1')
}

function New-R7RuntimeResult {
  param([string]$Code,[int]$ExitCode,[object]$Data=$null,[string[]]$Errors=@())
  return [pscustomobject]@{ ResultCode=$Code; ExitCode=$ExitCode; Data=$Data; Errors=[object[]]@($Errors) }
}

function Get-R7RuntimeHash {
  param([string]$Path,[switch]$WithoutPrefix)
  $value=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  if($WithoutPrefix){return $value}
  return 'sha256:'+$value
}

function Get-R7RuntimeTextDigest {
  param([string]$Text,[switch]$WithoutPrefix)
  $sha=[System.Security.Cryptography.SHA256]::Create()
  try{$value=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-','').ToLowerInvariant())}
  finally{$sha.Dispose()}
  if($WithoutPrefix){return $value}
  return 'sha256:'+$value
}

function Get-R7RuntimeObjectDigest {
  param([object]$Value,[switch]$WithoutPrefix)
  $text=($Value|ConvertTo-Json -Depth 60 -Compress)
  return Get-R7RuntimeTextDigest $text -WithoutPrefix:$WithoutPrefix
}

function Resolve-R7RuntimePath {
  param([string]$Root,[string]$RelativePath)
  if(-not(Test-P0RelativePath $RelativePath)){throw "unsafe_relative_path:$RelativePath"}
  $base=[IO.Path]::GetFullPath($Root).TrimEnd('\')
  $full=[IO.Path]::GetFullPath((Join-Path $base $RelativePath))
  if($full -ne $base -and -not $full.StartsWith($base+'\',[StringComparison]::OrdinalIgnoreCase)){throw "path_escape:$RelativePath"}
  return $full
}

function Get-R7RuntimeField {
  param([object]$Object,[string[]]$Names)
  foreach($name in @($Names)){
    if(Test-R7HasProperty $Object $name){
      $value=$Object.$name
      if($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)){return [string]$value}
    }
  }
  return ''
}

function Get-R7RuntimeRegistries {
  param([string]$ProjectRoot)
  return [pscustomobject]@{
    Blueprints=Read-YamlFile (Join-Path $ProjectRoot 'routes/r7-workflow-blueprints.yaml')
    Nodes=Read-YamlFile (Join-Path $ProjectRoot 'routes/r7-node-registry.yaml')
    Actions=Read-YamlFile (Join-Path $ProjectRoot 'routes/r7-action-registry.yaml')
    DirectActions=Read-YamlFile (Join-Path $ProjectRoot 'routes/r7-action-registry.v0.1.yaml')
    Selectors=Read-YamlFile (Join-Path $ProjectRoot 'routes/r7-input-selector-registry.yaml')
    Commits=Read-YamlFile (Join-Path $ProjectRoot 'routes/r7-artifact-commit-registry.yaml')
    StatusRoutes=Read-YamlFile (Join-Path $ProjectRoot 'routes/r7-status-route-registry.yaml')
    Guidance=Read-YamlFile (Join-Path $ProjectRoot 'routes/r7-task-guidance-registry.yaml')
    ProducerAdapters=Read-YamlFile (Join-Path $ProjectRoot 'routes/r7-producer-adapter-registry.yaml')
  }
}

function Test-R7RuntimePayloadRoot {
  param([string]$ProjectRoot,[object]$Payload,[object]$Adapter)
  $errors=[Collections.Generic.List[string]]::new()
  $schemaPath=Resolve-R7RuntimePath $ProjectRoot ([string]$Adapter.payload_schema_path)
  if(-not(Test-Path -LiteralPath $schemaPath -PathType Leaf)){return [object[]]@("producer_payload_schema_missing:$($Adapter.node_id)")}
  $schema=Read-R7JsonFile $schemaPath
  foreach($name in @($schema.required)){if(-not(Test-R7HasProperty $Payload ([string]$name))){$errors.Add("producer_payload_required_missing:$name")}}
  if($schema.additionalProperties -eq $false){
    $allowed=@($schema.properties.PSObject.Properties.Name)
    foreach($property in @($Payload.PSObject.Properties.Name)){if([string]$property -notin $allowed){$errors.Add("producer_payload_property_forbidden:$property")}}
  }
  foreach($name in @('schema_id','schema_version')){
    if(Test-R7HasProperty $schema.properties $name){
      $contract=$schema.properties.$name
      if((Test-R7HasProperty $contract 'const') -and [string]($Payload.$name) -ne [string]($contract.const)){$errors.Add("producer_payload_${name}_invalid")}
    }
  }
  if(Test-R7HasProperty $Adapter 'required_field_values'){
    $constraints=$Adapter.required_field_values
    $names=if($constraints -is [Collections.IDictionary]){@($constraints.Keys)}else{@($constraints.PSObject.Properties.Name)}
    foreach($name in $names){
      $expected=if($constraints -is [Collections.IDictionary]){$constraints[$name]}else{$constraints.$name}
      $actual=Get-R7RuntimeField $Payload @([string]$name)
      if($actual -ne [string]$expected){$errors.Add("producer_payload_phase_mismatch:${name}:expected=$expected;actual=$actual")}
    }
  }
  return [object[]]$errors.ToArray()
}

function New-R7RuntimeSubmissionFromPayload {
  param([string]$ProjectRoot,[string]$Session,[string]$TaskEnvelopeId,[string]$PayloadPath,[string]$ResultStatus,[int]$AttemptNo=1)
  $sessionRoot=[IO.Path]::GetFullPath($Session)
  $taskPath=Resolve-R7RuntimePath $sessionRoot "intermediate/r7/tasks/$TaskEnvelopeId.json"
  if(-not(Test-Path -LiteralPath $taskPath -PathType Leaf)){return New-R7RuntimeResult 'task_envelope_missing' 2 $null @($TaskEnvelopeId)}
  $absolutePayload=if([IO.Path]::IsPathRooted($PayloadPath)){[IO.Path]::GetFullPath($PayloadPath)}else{Resolve-R7RuntimePath $sessionRoot $PayloadPath}
  if(-not(Test-Path -LiteralPath $absolutePayload -PathType Leaf)){return New-R7RuntimeResult 'producer_payload_missing' 2 $null @($PayloadPath)}
  $task=Read-R7JsonFile $taskPath;$payload=Read-R7JsonFile $absolutePayload;$registries=Get-R7RuntimeRegistries $ProjectRoot
  if([string]$task.node_id -in @('hotspot_research','topic_human_gate','hotspot_content_brief','hotspot_structure_plan','hotspot_draft','delivery_topic_freshness_review')){
    if(-not(Get-Command Test-R7HotspotResearchSet -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'R7HotspotContractHelper.ps1')}
    if(-not(Get-Command Get-R7HotspotCurrentArtifact -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'R7HotspotRuntime.ps1')}
  }
  $adapter=@($registries.ProducerAdapters.adapters|Where-Object{$_.node_id -eq $task.node_id})|Select-Object -First 1
  if($null -eq $adapter){return New-R7RuntimeResult 'producer_adapter_missing' 1 $task @([string]$task.node_id)}
  $plan=Read-P0JsonFile (Join-Path $sessionRoot 'intermediate/p0/session-execution-plan.json')
  $projection=Read-P0JsonFile (Join-Path $sessionRoot 'intermediate/p0/state-projection.json')
  $step=@($plan.steps|Where-Object{$_.step_id -eq $projection.next_step_id})|Select-Object -First 1
  if($null -eq $step -or [string]$step.node_id -ne [string]$task.node_id){return New-R7RuntimeResult 'task_not_current' 2 $task @()}
  if([string]$adapter.artifact_type -ne [string]$step.produces_artifact_type){return New-R7RuntimeResult 'producer_adapter_artifact_mismatch' 1 $adapter @()}
  $payloadErrors=@(Test-R7RuntimePayloadRoot $ProjectRoot $payload $adapter)
  if($payloadErrors.Count){return New-R7RuntimeResult 'producer_payload_contract_error' 1 $payload $payloadErrors}
  if($ResultStatus -notin @($task.allowed_statuses)){return New-R7RuntimeResult 'semantic_submission_status_not_allowed' 1 $task @($ResultStatus)}
  $profile=@($registries.Commits.profiles|Where-Object{$_.artifact_type -eq $adapter.artifact_type})|Select-Object -First 1
  if($null -eq $profile){return New-R7RuntimeResult 'artifact_commit_profile_missing' 1 $adapter @()}
  $artifactId=Get-R7RuntimeField $payload @([string]$profile.artifact_id_field)
  $payloadStatus=Get-R7RuntimeField $payload @([string]$profile.status_field)
  $expectedPayloadStatus=Get-R7RuntimeField $profile.status_value_map @($ResultStatus)
  $mappingErrors=[Collections.Generic.List[string]]::new()
  $outputRevision=1
  if(Test-R7HasProperty $profile 'revision_field'){
    $revisionText=Get-R7RuntimeField $payload @([string]$profile.revision_field)
    $parsedRevision=0
    if(-not [int]::TryParse($revisionText,[ref]$parsedRevision) -or $parsedRevision -lt 1){$mappingErrors.Add('producer_payload_revision_invalid')}
    else{$outputRevision=$parsedRevision}
  }
  if([string]::IsNullOrWhiteSpace($artifactId)){$mappingErrors.Add('producer_payload_artifact_id_missing')}
  if([string]::IsNullOrWhiteSpace($expectedPayloadStatus)){$mappingErrors.Add('semantic_submission_status_mapping_missing')}
  elseif($payloadStatus -ne $expectedPayloadStatus){$mappingErrors.Add("semantic_submission_payload_status_mismatch:expected=$expectedPayloadStatus;actual=$payloadStatus")}
  if([string]$task.node_id -eq 'direct_baseline_draft'){
    if($null -ne $payload.structure_plan_ref){$mappingErrors.Add('direct_baseline_future_structure_reference')}
    if([string]$payload.normalized_body_digest -ne [string]$payload.original_normalized_body_digest){$mappingErrors.Add('direct_baseline_normalized_digest_mismatch')}
  }
  if([string]$task.node_id -eq 'semantic_beat_map'){
    if($null -ne $payload.structure_plan_ref){$mappingErrors.Add('semantic_beat_future_structure_reference')}
    if(@($payload.beats|Where-Object{$null -ne $_.stage_id}).Count -gt 0){$mappingErrors.Add('semantic_beat_stage_binding_forbidden')}
  }
  if([string]$task.node_id -eq 'direct_structure_plan'){
    $draftBinding=@($task.input_artifact_bindings|Where-Object{[string]$_.artifact_type -eq 'draft'})|Select-Object -First 1
    $beatBinding=@($task.input_artifact_bindings|Where-Object{[string]$_.artifact_type -eq 'content_beat_map'})|Select-Object -First 1
    if($null -eq $draftBinding -or $null -eq $beatBinding){$mappingErrors.Add('direct_structure_materialized_inputs_missing')}
    else{
      if($null -eq $payload.source_draft_ref -or [string]$payload.source_draft_ref.artifact_id -ne [string]$draftBinding.artifact_id -or (([string]$payload.source_draft_ref.sha256)-replace '^sha256:','') -ne [string]$draftBinding.sha256){$mappingErrors.Add('future_artifact_reference:source_draft_ref')}
      if($null -eq $payload.source_beat_map_ref -or [string]$payload.source_beat_map_ref.artifact_id -ne [string]$beatBinding.artifact_id -or (([string]$payload.source_beat_map_ref.sha256)-replace '^sha256:','') -ne [string]$beatBinding.sha256){$mappingErrors.Add('future_artifact_reference:source_beat_map_ref')}
    }
  }
  if([string]$task.node_id -eq 'content_beat_map'){
    $structureBinding=@($task.input_artifact_bindings|Where-Object{[string]$_.artifact_type -eq 'short_video_structure_plan'})|Select-Object -First 1
    if($null -eq $structureBinding -or $null -eq $payload.structure_plan_ref -or [string]$payload.structure_plan_ref.structure_plan_id -ne [string]$structureBinding.artifact_id){$mappingErrors.Add('structure_bound_beat_structure_binding_mismatch')}
  }
  if([string]$task.node_id -eq 'hotspot_research'){
    foreach($e in(Test-R7HotspotResearchSet $payload)){$mappingErrors.Add($e)}
    $requestBinding=@($task.input_artifact_bindings|Where-Object{[string]$_.artifact_type-eq'hotspot_research_request'})|Select-Object -First 1
    if($null-eq$requestBinding){$mappingErrors.Add('hotspot_research_request_binding_missing')}
    else{
      foreach($name in @('artifact_id','sha256')){$actual=if($name-eq'artifact_id'){[string]$payload.research_request_ref.artifact_id}else{([string]$payload.research_request_ref.sha256)-replace'^sha256:',''};$expected=if($name-eq'artifact_id'){[string]$requestBinding.artifact_id}else{[string]$requestBinding.sha256};if($actual-ne$expected){$mappingErrors.Add("hotspot_research_request_binding_mismatch:$name")}}
      $request=Read-R7JsonFile (Resolve-R7RuntimePath $sessionRoot ([string]$requestBinding.relative_path));$requestRef=[ordered]@{artifact_id=[string]$requestBinding.artifact_id;revision=[int]$request.research_request_revision;sha256='sha256:'+[string]$requestBinding.sha256};foreach($e in(Test-R7HotspotResearchSetBinding $payload $request $requestRef)){$mappingErrors.Add($e)}
    }
  }
  if([string]$task.node_id -eq 'topic_human_gate'){
    $panelBinding=@($task.input_artifact_bindings|Where-Object{[string]$_.artifact_type-eq'topic_selection_panel'})|Select-Object -First 1
    if($null-eq$panelBinding){$mappingErrors.Add('topic_decision_panel_binding_missing')}
    else{
      $panel=Read-R7JsonFile (Resolve-R7RuntimePath $sessionRoot ([string]$panelBinding.relative_path))
      try{$setItem=Get-R7HotspotCurrentArtifact $sessionRoot 'hotspot_research_set';foreach($e in(Test-R7HotspotDecision $payload $panel $setItem.Payload)){$mappingErrors.Add($e)}}catch{$mappingErrors.Add($_.Exception.Message)}
      foreach($name in @('artifact_id','revision','sha256')){$expected=if($name-eq'artifact_id'){[string]$panelBinding.artifact_id}elseif($name-eq'revision'){1}else{'sha256:'+[string]$panelBinding.sha256};if([string]$payload.panel_ref.$name-ne[string]$expected){$mappingErrors.Add("topic_decision_panel_ref_mismatch:$name")}}
    }
  }
  if([string]$task.node_id -eq 'hotspot_content_brief'){
    $sourceBinding=@($task.input_artifact_bindings|Where-Object{[string]$_.artifact_type-eq'selected_topic_source'})|Select-Object -First 1
    if($null-eq$sourceBinding){$mappingErrors.Add('hotspot_brief_source_binding_missing')}
    else{$source=Read-R7JsonFile (Resolve-R7RuntimePath $sessionRoot ([string]$sourceBinding.relative_path));$sourceRef=[ordered]@{artifact_id=[string]$sourceBinding.artifact_id;revision=1;sha256='sha256:'+[string]$sourceBinding.sha256};foreach($e in(Test-R7HotspotBriefV04 $payload $sourceRef $source)){$mappingErrors.Add($e)}}
  }
  if([string]$task.node_id -eq 'hotspot_structure_plan'){
    $briefBinding=@($task.input_artifact_bindings|Where-Object{[string]$_.artifact_type-eq'content_brief'})|Select-Object -First 1;$sourceBinding=@($task.input_artifact_bindings|Where-Object{[string]$_.artifact_type-eq'selected_topic_source'})|Select-Object -First 1
    if($null-eq$briefBinding-or$null-eq$sourceBinding){$mappingErrors.Add('hotspot_structure_materialized_inputs_missing')}else{foreach($e in(Test-R7HotspotStructurePlan $payload $briefBinding $sourceBinding)){$mappingErrors.Add($e)}}
  }
  if([string]$task.node_id -eq 'hotspot_draft'){
    $briefBinding=@($task.input_artifact_bindings|Where-Object{[string]$_.artifact_type-eq'content_brief'})|Select-Object -First 1;$structureBinding=@($task.input_artifact_bindings|Where-Object{[string]$_.artifact_type-eq'short_video_structure_plan'})|Select-Object -First 1;$sourceBinding=@($task.input_artifact_bindings|Where-Object{[string]$_.artifact_type-eq'selected_topic_source'})|Select-Object -First 1
    if($null-eq$briefBinding-or$null-eq$structureBinding-or$null-eq$sourceBinding){$mappingErrors.Add('hotspot_draft_materialized_inputs_missing')}
    else{$briefRef=[ordered]@{artifact_id=[string]$briefBinding.artifact_id;revision=1;sha256='sha256:'+[string]$briefBinding.sha256};$structureRef=[ordered]@{artifact_id=[string]$structureBinding.artifact_id;revision=1;sha256='sha256:'+[string]$structureBinding.sha256};foreach($e in(Test-R7HotspotDraftV04 $payload $briefRef $structureRef)){$mappingErrors.Add($e)};if([string]$payload.content_source_id-ne[string]$sourceBinding.artifact_id){$mappingErrors.Add('hotspot_draft_source_id_mismatch')}}
  }
  if([string]$task.node_id -eq 'delivery_topic_freshness_review'){
    $sourceBinding=@($task.input_artifact_bindings|Where-Object{[string]$_.artifact_type-eq'selected_topic_source'})|Select-Object -First 1
    if($null-eq$sourceBinding){$mappingErrors.Add('freshness_review_source_binding_missing')}
    else{
      $source=Read-R7JsonFile (Resolve-R7RuntimePath $sessionRoot ([string]$sourceBinding.relative_path))
      $sourceRef=[ordered]@{artifact_id=[string]$sourceBinding.artifact_id;revision=[int]$source.selected_topic_source_revision;sha256='sha256:'+[string]$sourceBinding.sha256}
      foreach($e in(Test-R7TopicFreshnessReview $payload $sourceRef)){$mappingErrors.Add($e)}
    }
  }
  if($mappingErrors.Count){return New-R7RuntimeResult 'producer_payload_mapping_error' 1 $payload $mappingErrors.ToArray()}
  $routeClass=Get-R7RuntimeRouteClass $registries ([string]$task.node_id) $ResultStatus
  $quality=switch($routeClass){'success'{'pass'}'warning'{'pass_with_warnings'}'waiting'{'human_review_required'}default{'fail'}}
  $submissionId="SUB-$($task.session_id)-$($task.node_id)-$($artifactId)-$AttemptNo"
  $submission=[ordered]@{
    schema_id='taoge://schemas/r7/semantic-artifact-submission/v0.2';schema_version='0.2';submission_id=$submissionId;task_envelope_id=[string]$task.task_envelope_id;session_id=[string]$task.session_id;plan_id=[string]$task.plan_id;node_id=[string]$task.node_id;skill_ref=[string]$task.skill_ref;attempt_no=$AttemptNo;submitted_at=[DateTimeOffset]::UtcNow.ToString('o');input_binding_digest=[string]$task.input_binding_digest;output_artifact_type=[string]$adapter.artifact_type;output_contract_version=[string]$task.task_contract_version;output_artifact_id=$artifactId;output_revision=$outputRevision;result_status=$ResultStatus;requested_action=$null;source_artifact_ids=[object[]]@($task.input_artifact_bindings|ForEach-Object{[string]$_.artifact_id});quality_status=$quality;delivery_eligibility='trace_only';check_ids=[object[]]@("R7-H3-$($task.node_id)-payload-root");payload=$payload;evidence_refs=[object[]]@($absolutePayload.Substring($sessionRoot.Length+1).Replace('\','/'));idempotency_key=[string]$task.idempotency_key;write_intent='submit_for_deterministic_commit';requested_machine_writes=[object[]]@()
  }
  $submissionPath=Resolve-R7RuntimePath $sessionRoot "intermediate/r7/submissions/$submissionId.json"
  if(Test-Path -LiteralPath $submissionPath){
    $existing=Read-R7JsonFile $submissionPath
    if((Get-R7RuntimeObjectDigest $existing) -ne (Get-R7RuntimeObjectDigest ([pscustomobject](($submission|ConvertTo-Json -Depth 60)|ConvertFrom-Json)))){return New-R7RuntimeResult 'submission_build_conflict' 1 $submission @()}
  }else{Write-P0EvidenceAtomicText $submissionPath (ConvertTo-P0EvidenceJsonText $submission)}
  return New-R7RuntimeResult 'submission_built' 0 ([pscustomobject]@{SubmissionId=$submissionId;SubmissionPath=$submissionPath.Substring($sessionRoot.Length+1).Replace('\','/');NodeId=[string]$task.node_id;ArtifactId=$artifactId;ResultStatus=$ResultStatus}) @()
}

function Get-R7RuntimeBlueprint {
  param([object]$Registries,[string]$BlueprintId)
  return @($Registries.Blueprints.blueprints|Where-Object{[string]$_.blueprint_id -eq $BlueprintId})|Select-Object -First 1
}

function Get-R7RuntimeNode {
  param([object]$Registries,[string]$NodeId)
  return @($Registries.Nodes.nodes|Where-Object{[string]$_.node_id -eq $NodeId})|Select-Object -First 1
}

function Get-R7RuntimeStepKind {
  param([string]$Kind)
  switch($Kind){
    'semantic_skill'{return 'agent_required'}
    'human_gate'{return 'human_gate'}
    'external_side_effect'{return 'external_side_effect'}
    'deterministic_tool'{return 'deterministic_tool'}
    default{throw "node_step_kind_invalid:$Kind"}
  }
}

function New-R7RuntimePlan {
  param([string]$SessionId,[string]$BlueprintId,[object]$Registries)
  $blueprint=Get-R7RuntimeBlueprint $Registries $BlueprintId
  if($null -eq $blueprint){throw "blueprint_missing:$BlueprintId"}
  $isV02=[string]$blueprint.blueprint_version -eq '0.2'
  $isHotspot=[string]$blueprint.blueprint_id -eq 'hotspot_to_delivery_single_v0.2'
  $steps=[Collections.Generic.List[object]]::new()
  $planStepId="STEP-$SessionId-session_plan"
  $steps.Add([ordered]@{
    step_id=$planStepId;step_kind='deterministic_tool';operation='create_r7_session_plan';node_id='session_plan';skill_ref='semantic-workflow-coordinator';task_contract_version=$(if($isHotspot){'r7-semantic-workflow-coordinator-v0.7'}elseif($isV02){'r7-semantic-workflow-coordinator-v0.6'}else{'r7-semantic-workflow-coordinator-v0.2'});output_schema_ref=$(if($isHotspot){'taoge://schemas/p0/session-execution-plan/v0.8'}elseif($isV02){'taoge://schemas/p0/session-execution-plan/v0.7'}else{'taoge://schemas/p0/session-execution-plan/v0.6'});requires_step_ids=@();produces_artifact_type='session_execution_plan';success_state='succeeded';failure_route='semantic-workflow-coordinator';retry_policy=[ordered]@{mode='never';automatic_retries=0;max_attempts=1;idempotency_scope='session_step_input_digest'}
  })
  $previous=$planStepId
  foreach($nodeId in @($blueprint.node_refs)){
    $node=Get-R7RuntimeNode $Registries ([string]$nodeId)
    if($null -eq $node){throw "blueprint_node_missing:$nodeId"}
    $kind=Get-R7RuntimeStepKind ([string]$node.step_kind)
    $policyMode=if($kind -eq 'deterministic_tool'){'bounded'}elseif($kind -eq 'external_side_effect'){'reconcile_first'}else{'never'}
    $automatic=if($kind -eq 'deterministic_tool'){1}else{0}
    $max=if($kind -eq 'deterministic_tool'){2}else{1}
    $item=[ordered]@{
      step_id="STEP-$SessionId-$nodeId";step_kind=$kind;node_id=[string]$nodeId;skill_ref=[string]$node.skill_ref;task_contract_version=[string]::Join('+',@($node.required_contract_versions));output_schema_ref=[string]$node.output_schema_ref;requires_step_ids=@($previous);produces_artifact_type=[string]$node.output_artifact_type;success_state='succeeded';failure_route=[string]$node.failure_route;retry_policy=[ordered]@{mode=$policyMode;automatic_retries=$automatic;max_attempts=$max;idempotency_scope='session_step_input_digest'}
    }
    if($kind -eq 'deterministic_tool'){$item.operation=[string]$nodeId}
    $steps.Add($item)
    $previous=[string]$item.step_id
  }
  $document=[ordered]@{plan_id="PLAN-$SessionId-R7-001"}
  if($isHotspot){$document.plan_revision=1;$document.supersedes_plan_id=$null;$document.restart_from_node_id=$null;$document.replan_reason=$null;$document.carried_forward_artifact_refs=[object[]]@();$document.invalidated_artifact_refs=[object[]]@()}
  $document.session_id=$SessionId;$document.workflow_definition_version=$(if($isHotspot){'r7-hotspot-semantic-workflow-v0.2'}elseif($isV02){'r7-single-semantic-workflow-v0.2'}else{'r7-single-semantic-workflow-v0.1'});$document.contract_bundle_version=$(if($isHotspot){'p0-contract-bundle-v0.8'}elseif($isV02){'p0-contract-bundle-v0.7'}else{'p0-contract-bundle-v0.6'});$document.plan_schema_id=$(if($isHotspot){'taoge://schemas/p0/session-execution-plan/v0.8'}elseif($isV02){'taoge://schemas/p0/session-execution-plan/v0.7'}else{'taoge://schemas/p0/session-execution-plan/v0.6'});$document.event_schema_id='taoge://schemas/p0/execution-event/v0.2';$document.artifact_lineage_schema_id='taoge://schemas/p0/artifact-lineage/v0.2';$document.render_input_schema_id=$(if($isHotspot){'taoge://schemas/final-delivery/typed-components/v0.7'}else{'taoge://schemas/final-delivery/typed-components/v0.6'});$document.renderer_version=$(if($isHotspot){'final-delivery-renderer-v0.7'}else{'final-delivery-renderer-v0.6'});$document.template_version=$(if($isHotspot){'final-delivery-template-v0.7'}else{'final-delivery-template-v0.6'});$document.runtime_mode='single';$document.topic_count=1;$document.final_delivery_count=1;$document.blueprint_id=$BlueprintId;$document.blueprint_version=[string]$blueprint.blueprint_version;$document.steps=[object[]]$steps.ToArray()
  return [pscustomobject](($document|ConvertTo-Json -Depth 40)|ConvertFrom-Json)
}

function Initialize-R7RuntimeSession {
  param([string]$ProjectRoot,[string]$Session,[string]$BlueprintId)
  $sessionRoot=[IO.Path]::GetFullPath($Session)
  if(-not(Test-Path -LiteralPath $sessionRoot)){return New-R7RuntimeResult 'session_missing' 2 $null @($sessionRoot)}
  $sessionId=Split-Path -Leaf $sessionRoot
  $registries=Get-R7RuntimeRegistries $ProjectRoot
  $plan=New-R7RuntimePlan $sessionId $BlueprintId $registries
  $errors=@(Test-P0PlanContract $plan)
  if($errors.Count){return New-R7RuntimeResult 'plan_contract_failed' 1 $plan $errors}
  $planPath=Join-Path $sessionRoot 'intermediate/p0/session-execution-plan.json'
  $planText=ConvertTo-P0EvidenceJsonText $plan
  if(Test-Path -LiteralPath $planPath){
    $old=Get-R7RuntimeTextDigest ((Get-Content -Raw -LiteralPath $planPath -Encoding UTF8).TrimEnd("`r","`n"))
    $new=Get-R7RuntimeTextDigest $planText.TrimEnd("`r","`n")
    if($old -ne $new){return New-R7RuntimeResult 'session_plan_conflict' 1 $null @()}
  }else{Write-P0EvidenceAtomicText $planPath $planText}
  $eventPath=Join-Path $sessionRoot 'intermediate/p0/execution-events.jsonl'
  $digest=Get-R7RuntimeTextDigest $planText.TrimEnd("`r","`n")
  $write=Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId "STEP-$sessionId-session_plan" -EventType 'plan.created.v1' -EventSource 'runner' -StateBefore 'ready' -StateAfter 'succeeded' -PayloadDigest $digest -IdempotencyKey "${sessionId}:r7-plan:${BlueprintId}:$($plan.blueprint_version):$($plan.plan_schema_id)" -ExpectedLastSequenceNo @(Get-P0EvidenceEvents $eventPath).Count -ResultCode 'r7_session_plan_created' -SafeSummary 'Version-pinned R7 semantic workflow plan created' -OutputArtifactIds @([string]$plan.plan_id) -InputDigest $digest -ExecutionAttemptId "ATT-$sessionId-plan-1"
  if($write.ExitCode -ne 0){return New-R7RuntimeResult $write.ResultCode $write.ExitCode $null $write.Errors}
  $projection=Update-P0StateProjection $sessionRoot $plan $eventPath $false
  if($projection.ExitCode -ne 0){return New-R7RuntimeResult $projection.ResultCode $projection.ExitCode $null $projection.Errors}
  [void](Write-P0ResumeSummary $sessionRoot $plan $projection.Projection)
  return New-R7RuntimeResult $(if($write.ResultCode -eq 'duplicate_reused'){'duplicate_reused'}else{'session_initialized'}) 0 ([pscustomobject]@{PlanPath='intermediate/p0/session-execution-plan.json';NextStepId=$projection.Projection.next_step_id}) @()
}

function Resolve-R7RuntimeBinding {
  param([string]$ProjectRoot,[string]$SessionRoot,[object]$Selector)
  $root=if([string]$Selector.resolver_type -eq 'project_registry'){$ProjectRoot}else{$SessionRoot}
  if([string]$Selector.resolver_type -in @('current_collection')){throw "selector_runtime_pending:$($Selector.selector_id)"}
  $selectedPath=''
  foreach($relative in @($Selector.path_candidates)){
    $candidate=Resolve-R7RuntimePath $root ([string]$relative)
    if(Test-Path -LiteralPath $candidate -PathType Leaf){$selectedPath=$candidate;break}
  }
  if([string]::IsNullOrWhiteSpace($selectedPath)){
    if([bool]$Selector.allow_empty){return $null}
    throw "selector_input_missing:$($Selector.selector_id)"
  }
  $relativePath=$selectedPath.Substring($root.TrimEnd('\').Length+1).Replace('\','/')
  $digest=Get-R7RuntimeHash $selectedPath -WithoutPrefix
  $artifactId=''
  $status='materialized'
  if([IO.Path]::GetExtension($selectedPath) -eq '.json'){
    $document=Read-R7JsonFile $selectedPath
    if([string]$Selector.resolver_type -in @('current_pointer','first_current_pointer')){
      $artifactId=Get-R7RuntimeField $document @('artifact_id')
      $status=Get-R7RuntimeField $document @('status')
      $revisionRelative=Get-R7RuntimeField $document @('revision_path')
      if([string]::IsNullOrWhiteSpace($revisionRelative)){throw "selector_pointer_revision_missing:$($Selector.selector_id)"}
      $revisionPath=Resolve-R7RuntimePath $SessionRoot $revisionRelative
      if(-not(Test-Path -LiteralPath $revisionPath -PathType Leaf)){throw "selector_pointer_target_missing:$($Selector.selector_id)"}
      $actual=Get-R7RuntimeHash $revisionPath -WithoutPrefix
      $expected=([string]$document.sha256)-replace '^sha256:',''
      if($actual -ne $expected){throw "selector_pointer_digest_mismatch:$($Selector.selector_id)"}
      $selectedPath=$revisionPath;$relativePath=$revisionRelative.Replace('\','/');$digest=$actual
    }else{
      $artifactId=Get-R7RuntimeField $document @($Selector.artifact_id_fields)
      $candidateStatus=Get-R7RuntimeField $document @($Selector.status_fields)
      if(-not [string]::IsNullOrWhiteSpace($candidateStatus)){$status=$candidateStatus}
    }
  }
  if([string]::IsNullOrWhiteSpace($artifactId)){$artifactId="SRC-$($Selector.selector_id)-$($digest.Substring(0,12))"}
  return [ordered]@{artifact_id=$artifactId;artifact_type=[string]$Selector.artifact_type;relative_path=$relativePath;sha256=$digest;status=$status;materialization_status='materialized';current_ref_status='current'}
}

function Get-R7RuntimeAllowedActions {
  param([object]$ActionRegistry,[string]$OutputType)
  $aliases=@($OutputType)
  switch($OutputType){
    'visual_coverage_ledger'{$aliases+='visual_need_analysis'}
    'image_asset_set'{$aliases+='visual_asset'}
    'cover_composition'{$aliases+='cover_rendition'}
    'final_delivery_render_candidate'{$aliases+='final_delivery'}
    'viewport_acceptance_report'{$aliases+='final_delivery'}
    'workflow_session_record'{$aliases+=@('workflow_session','final_delivery','draft','content_brief','platform_package','visual_need_analysis','visual_asset','cover_rendition')}
  }
  $actions=[Collections.Generic.List[string]]::new()
  foreach($action in @($ActionRegistry.actions|Where-Object{$_.lifecycle_status -eq 'active' -and @($_.allowed_target_types|Where-Object{$_ -in $aliases}).Count -gt 0}|Sort-Object action_code)){
    $code=[string]$action.action_code
    if(-not $actions.Contains($code)){$actions.Add($code)}
  }
  # Returning an empty PowerShell array from a function emits no pipeline object and
  # becomes $null at the call site.  Keep the list object intact until task assembly
  # so Windows PowerShell 5.1 serializes an honest JSON [] rather than {}.
  return ,$actions
}

function Get-R7RuntimePendingReceipts {
  param([string]$SessionRoot)
  $root=Join-Path $SessionRoot 'intermediate/r7/commits'
  if(-not(Test-Path -LiteralPath $root)){return @()}
  return [object[]]@(Get-ChildItem -LiteralPath $root -File -Filter '*.json'|ForEach-Object{Read-R7JsonFile $_.FullName}|Where-Object{$_.phase -ne 'projection_rebuilt'})
}

function Prepare-R7RuntimeTask {
  param([string]$ProjectRoot,[string]$Session)
  $sessionRoot=[IO.Path]::GetFullPath($Session)
  $planPath=Join-Path $sessionRoot 'intermediate/p0/session-execution-plan.json'
  if(-not(Test-Path -LiteralPath $planPath)){return New-R7RuntimeResult 'session_plan_missing' 2 $null @()}
  $plan=Read-P0JsonFile $planPath
  $planErrors=@(Test-P0PlanContract $plan)
  if($planErrors.Count){return New-R7RuntimeResult 'plan_contract_failed' 1 $null $planErrors}
  $pending=@(Get-R7RuntimePendingReceipts $sessionRoot)
  if($pending.Count){return New-R7RuntimeResult 'pending_submission_requires_reconcile' 2 $pending @()}
  $eventPath=Join-Path $sessionRoot 'intermediate/p0/execution-events.jsonl'
  $projectionResult=Update-P0StateProjection $sessionRoot $plan $eventPath $false
  if($projectionResult.ExitCode -ne 0){return New-R7RuntimeResult $projectionResult.ResultCode $projectionResult.ExitCode $null $projectionResult.Errors}
  $projection=$projectionResult.Projection
  if($projection.current_state -eq 'completed'){return New-R7RuntimeResult 'workflow_completed' 0 $projection @()}
  $step=@($plan.steps|Where-Object{$_.step_id -eq $projection.next_step_id})|Select-Object -First 1
  if($null -eq $step){return New-R7RuntimeResult 'projection_next_step_missing' 1 $projection @()}
  if($step.step_kind -eq 'deterministic_tool'){return New-R7RuntimeResult 'deterministic_node_ready' 0 $step @()}
  $registries=Get-R7RuntimeRegistries $ProjectRoot
  $node=Get-R7RuntimeNode $registries ([string]$step.node_id)
  $guidance=@($registries.Guidance.nodes|Where-Object{$_.node_id -eq $step.node_id})|Select-Object -First 1
  if($null -eq $node -or $null -eq $guidance){return New-R7RuntimeResult 'task_registry_missing' 1 $step @()}
  $bindings=[Collections.Generic.List[object]]::new()
  try{
    foreach($selectorId in @($node.input_selectors)){
      $selector=@($registries.Selectors.selectors|Where-Object{$_.selector_id -eq $selectorId})|Select-Object -First 1
      if($null -eq $selector){throw "selector_registry_missing:$selectorId"}
      $binding=Resolve-R7RuntimeBinding $ProjectRoot $sessionRoot $selector
      if($null -ne $binding){$bindings.Add($binding)}
    }
  }catch{return New-R7RuntimeResult 'task_envelope_error' 1 $null @($_.Exception.Message)}
  if($bindings.Count -eq 0){return New-R7RuntimeResult 'task_envelope_error' 1 $null @('task_inputs_empty')}
  $bindingDigest=Get-R7RuntimeObjectDigest ([object[]]$bindings.ToArray()) -WithoutPrefix
  $safeNode=[string]$step.node_id
  $taskId="TASK-$($plan.session_id)-$safeNode-$($bindingDigest.Substring(0,12))"
  $taskPath=Join-Path $sessionRoot "intermediate/r7/tasks/$taskId.json"
  if(Test-Path -LiteralPath $taskPath){$task=Read-R7JsonFile $taskPath}
  else{
    $lastDigest=Get-R7RuntimeHash $eventPath -WithoutPrefix
    $taskActionRegistry=$(if([string]$plan.blueprint_id-eq'hotspot_to_delivery_single_v0.2'){$registries.Actions}else{$registries.DirectActions})
    $allowedActions=Get-R7RuntimeAllowedActions $taskActionRegistry ([string]$step.produces_artifact_type)
    $taskV02=[string]$plan.blueprint_version -eq '0.2'
    $task=[ordered]@{
      schema_id=$(if($taskV02){'taoge://schemas/r7/semantic-task-envelope/v0.2'}else{'taoge://schemas/r7/semantic-task-envelope/v0.1'});schema_version=$(if($taskV02){'0.2'}else{'0.1'});task_envelope_id=$taskId;session_id=[string]$plan.session_id;plan_id=[string]$plan.plan_id;blueprint_id=[string]$plan.blueprint_id;blueprint_version=[string]$plan.blueprint_version;node_id=$safeNode;skill_ref=[string]$step.skill_ref;task_contract_version=[string]$step.task_contract_version;action_registry_version=[string]$taskActionRegistry.registry_id;created_at=[DateTimeOffset]::UtcNow.ToString('o');input_artifact_bindings=[object[]]$bindings.ToArray();input_binding_digest=$bindingDigest;business_objective=[string]$guidance.business_objective;decision_boundaries=[object[]]@($guidance.decision_boundaries);required_output_schema_ref=[string]$step.output_schema_ref;allowed_statuses=[object[]]@($node.allowed_result_statuses);allowed_actions=[object[]]$allowedActions.ToArray();output_commit_policy='deterministic_submitter_pointer_last';idempotency_key="$($plan.session_id):${safeNode}:$bindingDigest";resume_context=[ordered]@{projection_version=[int]$projection.projected_through_sequence_no;projected_event_sequence=[int]$projection.projected_through_sequence_no;last_event_digest=$lastDigest;pending_submission_status='none'}
    }
    $taskErrors=@(Test-R7TaskEnvelopeContract ([pscustomobject](($task|ConvertTo-Json -Depth 50)|ConvertFrom-Json)) $taskActionRegistry)
    if($taskErrors.Count){return New-R7RuntimeResult 'task_envelope_error' 1 $task $taskErrors}
    Write-P0EvidenceAtomicText $taskPath (ConvertTo-P0EvidenceJsonText $task)
  }
  $events=@(Get-P0EvidenceEvents $eventPath)
  $stateAfter=switch([string]$step.step_kind){'agent_required'{'waiting_agent'}'human_gate'{'waiting_human'}'external_side_effect'{'waiting_external'}default{'waiting_agent'}}
  $payloadDigest=Get-R7RuntimeHash $taskPath
  $write=Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId ([string]$step.step_id) -EventType 'semantic.task_prepared.v1' -EventSource 'runner' -StateBefore 'ready' -StateAfter $stateAfter -PayloadDigest $payloadDigest -IdempotencyKey ([string]$task.idempotency_key) -ExpectedLastSequenceNo $events.Count -ResultCode 'semantic_task_ready' -SafeSummary 'One contract-bound semantic task prepared' -OutputArtifactIds @([string]$task.task_envelope_id) -InputDigest ('sha256:'+$bindingDigest) -ExecutionAttemptId "ATT-$($plan.session_id)-$safeNode-1"
  if($write.ExitCode -ne 0){return New-R7RuntimeResult $write.ResultCode $write.ExitCode $task $write.Errors}
  $projectionResult=Update-P0StateProjection $sessionRoot $plan $eventPath $false
  [void](Write-P0ResumeSummary $sessionRoot $plan $projectionResult.Projection)
  return New-R7RuntimeResult $(if($write.ResultCode -eq 'duplicate_reused'){'task_reused'}else{'task_prepared'}) 0 ([pscustomobject]@{Task=$task;TaskPath=$taskPath.Substring($sessionRoot.Length+1).Replace('\','/');CurrentState=$projectionResult.Projection.current_state}) @()
}

function Test-R7RuntimeSubmissionV02 {
  param([object]$Submission,[object]$Task,[object]$Registries)
  $errors=[Collections.Generic.List[string]]::new()
  $required=@('schema_id','schema_version','submission_id','task_envelope_id','session_id','plan_id','node_id','skill_ref','attempt_no','submitted_at','input_binding_digest','output_artifact_type','output_contract_version','output_artifact_id','output_revision','result_status','requested_action','source_artifact_ids','quality_status','delivery_eligibility','check_ids','payload','evidence_refs','idempotency_key','write_intent','requested_machine_writes')
  foreach($e in (Test-R7RequiredProperties $Submission $required 'semantic_submission_v02')){$errors.Add($e)}
  foreach($e in (Test-R7AllowedProperties $Submission $required 'semantic_submission_v02')){$errors.Add($e)}
  if($errors.Count){return [object[]]$errors.ToArray()}
  if($Submission.schema_id -ne 'taoge://schemas/r7/semantic-artifact-submission/v0.2' -or [string]$Submission.schema_version -ne '0.2'){$errors.Add('semantic_submission_v02_version_invalid')}
  foreach($name in @('task_envelope_id','session_id','plan_id','node_id','skill_ref','input_binding_digest','idempotency_key')){if([string]$Submission.$name -ne [string]$Task.$name){$errors.Add("semantic_submission_envelope_mismatch:$name")}}
  if([string]$Submission.result_status -notin @($Task.allowed_statuses)){$errors.Add("semantic_submission_status_not_allowed:$($Submission.result_status)")}
  if($null -ne $Submission.requested_action -and [string]$Submission.requested_action -notin @($Task.allowed_actions)){$errors.Add("enum_registry_error:$($Submission.requested_action)")}
  if($Submission.write_intent -ne 'submit_for_deterministic_commit' -or @($Submission.requested_machine_writes).Count -ne 0){$errors.Add('semantic_submission_machine_write_forbidden')}
  if(-not(Test-R7Digest ([string]$Submission.input_binding_digest))){$errors.Add('semantic_submission_input_digest_invalid')}
  if([int]$Submission.output_revision -lt 1){$errors.Add('semantic_submission_revision_invalid')}
  $knownInputs=@($Task.input_artifact_bindings|ForEach-Object{[string]$_.artifact_id})
  foreach($source in @($Submission.source_artifact_ids)){if([string]$source -notin $knownInputs){$errors.Add("semantic_submission_source_unknown:$source")}}
  $profile=@($Registries.Commits.profiles|Where-Object{$_.artifact_type -eq $Submission.output_artifact_type})|Select-Object -First 1
  if($null -eq $profile){$errors.Add("artifact_commit_profile_missing:$($Submission.output_artifact_type)")}
  else{
    $payloadId=Get-R7RuntimeField $Submission.payload @([string]$profile.artifact_id_field)
    $payloadStatus=Get-R7RuntimeField $Submission.payload @([string]$profile.status_field)
    $expectedPayloadStatus=Get-R7RuntimeField $profile.status_value_map @([string]$Submission.result_status)
    if($payloadId -ne [string]$Submission.output_artifact_id){$errors.Add('semantic_submission_payload_artifact_id_mismatch')}
    if(Test-R7HasProperty $profile 'revision_field'){
      $payloadRevision=Get-R7RuntimeField $Submission.payload @([string]$profile.revision_field)
      if([string]$Submission.output_revision -ne $payloadRevision){$errors.Add('semantic_submission_payload_revision_mismatch')}
    }
    if([string]::IsNullOrWhiteSpace($expectedPayloadStatus)){$errors.Add('semantic_submission_status_mapping_missing')}
    elseif($payloadStatus -ne $expectedPayloadStatus){$errors.Add("semantic_submission_payload_status_mismatch:expected=$expectedPayloadStatus;actual=$payloadStatus")}
  }
  return [object[]]$errors.ToArray()
}

function Get-R7RuntimeRouteClass {
  param([object]$Registries,[string]$NodeId,[string]$Status)
  $entry=@($Registries.StatusRoutes.nodes|Where-Object{$_.node_id -eq $NodeId})|Select-Object -First 1
  if($null -eq $entry){return ''}
  foreach($name in @('success','warning','waiting','failure')){if($Status -in @($entry.$name)){return $name}}
  return ''
}

function Write-R7RuntimeReceipt {
  param([string]$Path,[hashtable]$Values)
  $receipt=[ordered]@{schema_id='taoge://schemas/r7/semantic-commit-receipt/v0.1';schema_version='0.1';commit_receipt_id="COMMIT-$($Values.submission_id)";session_id=$Values.session_id;task_envelope_id=$Values.task_envelope_id;submission_id=$Values.submission_id;artifact_id=$Values.artifact_id;artifact_type=$Values.artifact_type;idempotency_key=$Values.idempotency_key;phase=$Values.phase;revision_path=$Values.revision_path;revision_sha256=$Values.revision_sha256;pointer_path=$Values.pointer_path;producer_event_id=$Values.producer_event_id;projection_status=$Values.projection_status;updated_at=[DateTimeOffset]::UtcNow.ToString('o')}
  Write-P0EvidenceAtomicText $Path (ConvertTo-P0EvidenceJsonText $receipt)
  return [pscustomobject](($receipt|ConvertTo-Json -Depth 10)|ConvertFrom-Json)
}

function Submit-R7RuntimeArtifact {
  param([string]$ProjectRoot,[string]$Session,[string]$SubmissionPath)
  $sessionRoot=[IO.Path]::GetFullPath($Session)
  $absoluteSubmission=if([IO.Path]::IsPathRooted($SubmissionPath)){[IO.Path]::GetFullPath($SubmissionPath)}else{Resolve-R7RuntimePath $sessionRoot $SubmissionPath}
  if(-not(Test-Path -LiteralPath $absoluteSubmission)){return New-R7RuntimeResult 'submission_missing' 2 $null @($absoluteSubmission)}
  $submission=Read-R7JsonFile $absoluteSubmission
  $taskPath=Join-Path $sessionRoot "intermediate/r7/tasks/$($submission.task_envelope_id).json"
  if(-not(Test-Path -LiteralPath $taskPath)){return New-R7RuntimeResult 'task_envelope_missing' 2 $null @()}
  $task=Read-R7JsonFile $taskPath
  $registries=Get-R7RuntimeRegistries $ProjectRoot
  $errors=@(Test-R7RuntimeSubmissionV02 $submission $task $registries)
  if($errors.Count){return New-R7RuntimeResult 'semantic_submission_error' 1 $submission $errors}
  foreach($binding in @($task.input_artifact_bindings)){
    $path=Resolve-R7RuntimePath $sessionRoot ([string]$binding.relative_path)
    if(-not(Test-Path -LiteralPath $path)){return New-R7RuntimeResult 'cross_artifact_binding_error' 1 $submission @("input_missing:$($binding.artifact_id)")}
    if((Get-R7RuntimeHash $path -WithoutPrefix) -ne [string]$binding.sha256){return New-R7RuntimeResult 'cross_artifact_binding_error' 1 $submission @("input_digest_changed:$($binding.artifact_id)")}
  }
  $routeClass=Get-R7RuntimeRouteClass $registries ([string]$submission.node_id) ([string]$submission.result_status)
  if([string]::IsNullOrWhiteSpace($routeClass)){return New-R7RuntimeResult 'semantic_submission_error' 1 $submission @('status_route_missing')}
  if($routeClass -eq 'failure'){return New-R7RuntimeResult 'semantic_submission_business_failure' 2 $submission @()}
  $plan=Read-P0JsonFile (Join-Path $sessionRoot 'intermediate/p0/session-execution-plan.json')
  $step=@($plan.steps|Where-Object{$_.node_id -eq $submission.node_id})|Select-Object -First 1
  if($null -eq $step){return New-R7RuntimeResult 'submission_step_missing' 1 $submission @()}
  if($routeClass -eq 'waiting'){
    $eventPath=Join-Path $sessionRoot 'intermediate/p0/execution-events.jsonl'
    $events=@(Get-P0EvidenceEvents $eventPath)
    $stateBefore=switch([string]$step.step_kind){'agent_required'{'waiting_agent'}'human_gate'{'waiting_human'}'external_side_effect'{'waiting_external'}default{'running'}}
    $stateAfter=if([string]$submission.result_status -match 'human|authorization|review'){'waiting_human'}elseif($step.step_kind -eq 'external_side_effect'){'waiting_external'}else{'waiting_agent'}
    $eventSource=switch([string]$step.step_kind){'agent_required'{'agent_recorder'}'human_gate'{'human_recorder'}'external_side_effect'{'reconciler'}default{'runner'}}
    $write=Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId ([string]$step.step_id) -EventType 'semantic.waiting.v1' -EventSource $eventSource -StateBefore $stateBefore -StateAfter $stateAfter -PayloadDigest (Get-R7RuntimeHash $absoluteSubmission) -IdempotencyKey ([string]$submission.idempotency_key) -ExpectedLastSequenceNo $events.Count -ResultCode ([string]$submission.result_status) -SafeSummary 'Semantic producer reported an explicit wait without committing a current artifact' -OutputArtifactIds @() -InputDigest ('sha256:'+[string]$submission.input_binding_digest) -ExecutionAttemptId "ATT-$($plan.session_id)-$($submission.node_id)-$($submission.attempt_no)"
    if($write.ExitCode -ne 0){return New-R7RuntimeResult $write.ResultCode $write.ExitCode $submission $write.Errors}
    $projection=Update-P0StateProjection $sessionRoot $plan $eventPath $false
    if($projection.ExitCode -ne 0){return New-R7RuntimeResult $projection.ResultCode $projection.ExitCode $submission $projection.Errors}
    [void](Write-P0ResumeSummary $sessionRoot $plan $projection.Projection)
    return New-R7RuntimeResult 'semantic_waiting' 2 ([pscustomobject]@{Status=[string]$submission.result_status;CurrentState=$projection.Projection.current_state;NextStepId=$projection.Projection.next_step_id;ArtifactCommitted=$false}) @()
  }
  $profile=@($registries.Commits.profiles|Where-Object{$_.artifact_type -eq $submission.output_artifact_type})|Select-Object -First 1
  $revisionArtifactId=[string]$submission.output_artifact_id
  if([int]$submission.output_revision-gt1){$revisionArtifactId+="-r$('{0:000}'-f[int]$submission.output_revision)"}
  $revisionRelative=([string]$registries.Commits.default_revision_path_template).Replace('{artifact_type}',[string]$submission.output_artifact_type).Replace('{artifact_id}',$revisionArtifactId)
  $pointerRelative=([string]$registries.Commits.default_pointer_path_template).Replace('{artifact_type}',[string]$submission.output_artifact_type)
  $revisionPath=Resolve-R7RuntimePath $sessionRoot $revisionRelative
  $pointerPath=Resolve-R7RuntimePath $sessionRoot $pointerRelative
  $receiptPath=Resolve-R7RuntimePath $sessionRoot "intermediate/r7/commits/$($submission.submission_id).json"
  if(Test-Path -LiteralPath $receiptPath){
    $existingReceipt=Read-R7JsonFile $receiptPath
    if([string]$existingReceipt.phase -eq 'projection_rebuilt'){
      $duplicateErrors=[Collections.Generic.List[string]]::new()
      if([string]$existingReceipt.submission_id -ne [string]$submission.submission_id){$duplicateErrors.Add('duplicate_receipt_submission_mismatch')}
      if([string]$existingReceipt.idempotency_key -ne [string]$submission.idempotency_key){$duplicateErrors.Add('duplicate_receipt_idempotency_mismatch')}
      if(-not(Test-Path -LiteralPath $revisionPath -PathType Leaf)){$duplicateErrors.Add('duplicate_revision_missing')}
      elseif((Get-R7RuntimeHash $revisionPath) -ne [string]$existingReceipt.revision_sha256){$duplicateErrors.Add('duplicate_revision_digest_mismatch')}
      if(-not(Test-Path -LiteralPath $pointerPath -PathType Leaf)){$duplicateErrors.Add('duplicate_pointer_missing')}
      else{
        $existingPointer=Read-R7JsonFile $pointerPath
        if([string]$existingPointer.submission_id -ne [string]$submission.submission_id){$duplicateErrors.Add('duplicate_pointer_submission_mismatch')}
      }
      if($duplicateErrors.Count){return New-R7RuntimeResult 'duplicate_evidence_conflict' 1 $submission ([object[]]$duplicateErrors.ToArray())}
      $projectionPath=Join-Path $sessionRoot 'intermediate/p0/state-projection.json'
      $nextStepId=$null
      if(Test-Path -LiteralPath $projectionPath){$nextStepId=[string](Read-R7JsonFile $projectionPath).next_step_id}
      return New-R7RuntimeResult 'duplicate_reused' 0 ([pscustomobject]@{ArtifactId=[string]$submission.output_artifact_id;RevisionPath=$revisionRelative;PointerPath=$pointerRelative;EventId=[string]$existingReceipt.producer_event_id;NextStepId=$nextStepId;RouteClass=$routeClass}) @()
    }
  }
  $values=@{submission_id=[string]$submission.submission_id;session_id=[string]$submission.session_id;task_envelope_id=[string]$submission.task_envelope_id;artifact_id=[string]$submission.output_artifact_id;artifact_type=[string]$submission.output_artifact_type;idempotency_key=[string]$submission.idempotency_key;phase='validated';revision_path=$null;revision_sha256=$null;pointer_path=$null;producer_event_id=$null;projection_status='pending'}
  [void](Write-R7RuntimeReceipt $receiptPath $values)
  $revisionText=ConvertTo-P0EvidenceJsonText $submission.payload
  $revisionDigest=Get-R7RuntimeTextDigest $revisionText
  if(Test-Path -LiteralPath $revisionPath){
    if((Get-R7RuntimeHash $revisionPath) -ne $revisionDigest){return New-R7RuntimeResult 'immutable_revision_conflict' 1 $submission @()}
  }else{Write-P0EvidenceAtomicText $revisionPath $revisionText}
  $values.phase='revision_written';$values.revision_path=$revisionRelative;$values.revision_sha256=$revisionDigest
  [void](Write-R7RuntimeReceipt $receiptPath $values)
  $eventPath=Join-Path $sessionRoot 'intermediate/p0/execution-events.jsonl'
  $events=@(Get-P0EvidenceEvents $eventPath)
  $safeSession=([string]$plan.session_id -replace '[^A-Za-z0-9_-]','-')
  $predictedEventId='EVT-'+$safeSession+'-'+($events.Count+1).ToString('0000')
  try{$lineagePath=Write-P0EvidenceLineage $sessionRoot ([string]$submission.output_artifact_id) ([string]$submission.output_artifact_type) $predictedEventId @($submission.source_artifact_ids) $revisionRelative $revisionDigest ([string]$submission.quality_status) ([string]$submission.delivery_eligibility) @($submission.check_ids) -Revision ([int]$submission.output_revision)}catch{return New-R7RuntimeResult 'lineage_commit_error' 1 $submission @($_.Exception.Message)}
  $values.phase='lineage_written';$values.producer_event_id=$predictedEventId
  [void](Write-R7RuntimeReceipt $receiptPath $values)
  $pointer=[ordered]@{schema_id='taoge://schemas/r7/semantic-current-pointer/v0.1';schema_version='0.1';artifact_type=[string]$submission.output_artifact_type;artifact_id=[string]$submission.output_artifact_id;revision=[int]$submission.output_revision;revision_path=$revisionRelative;sha256=$revisionDigest;status=[string]$submission.result_status;task_envelope_id=[string]$submission.task_envelope_id;submission_id=[string]$submission.submission_id;producer_event_id=$predictedEventId;committed_at=[DateTimeOffset]::UtcNow.ToString('o')}
  if(Test-Path -LiteralPath $pointerPath){
    $existing=Read-R7JsonFile $pointerPath
    if($existing.submission_id -ne $submission.submission_id -and [int]$existing.revision -ge [int]$submission.output_revision){return New-R7RuntimeResult 'current_pointer_revision_conflict' 1 $submission @()}
  }
  Write-P0EvidenceAtomicText $pointerPath (ConvertTo-P0EvidenceJsonText $pointer)
  $values.phase='pointer_committed';$values.pointer_path=$pointerRelative
  [void](Write-R7RuntimeReceipt $receiptPath $values)
  $eventSource=switch([string]$step.step_kind){'agent_required'{'agent_recorder'}'human_gate'{'human_recorder'}'external_side_effect'{'reconciler'}default{'runner'}}
  $payloadDigest=Get-R7RuntimeHash $absoluteSubmission
  $write=Write-P0EvidenceEvent -EventPath $eventPath -Plan $plan -StepId ([string]$step.step_id) -EventType 'semantic.result_committed.v1' -EventSource $eventSource -StateBefore $(switch([string]$step.step_kind){'agent_required'{'waiting_agent'}'human_gate'{'waiting_human'}'external_side_effect'{'waiting_external'}default{'running'}}) -StateAfter 'succeeded' -PayloadDigest $payloadDigest -IdempotencyKey ([string]$submission.idempotency_key) -ExpectedLastSequenceNo $events.Count -ResultCode "semantic_$routeClass" -SafeSummary 'Typed semantic artifact committed by deterministic submitter' -OutputArtifactIds @([string]$submission.output_artifact_id) -InputDigest ('sha256:'+[string]$submission.input_binding_digest) -ExecutionAttemptId "ATT-$($plan.session_id)-$($submission.node_id)-$($submission.attempt_no)"
  if($write.ExitCode -ne 0){return New-R7RuntimeResult $write.ResultCode $write.ExitCode $submission $write.Errors}
  $values.phase='event_committed';$values.producer_event_id=[string]$write.Event.event_id
  [void](Write-R7RuntimeReceipt $receiptPath $values)
  $projection=Update-P0StateProjection $sessionRoot $plan $eventPath $false
  if($projection.ExitCode -ne 0){return New-R7RuntimeResult $projection.ResultCode $projection.ExitCode $submission $projection.Errors}
  [void](Write-P0ResumeSummary $sessionRoot $plan $projection.Projection)
  $values.phase='projection_rebuilt';$values.projection_status='current'
  [void](Write-R7RuntimeReceipt $receiptPath $values)
  return New-R7RuntimeResult $(if($write.ResultCode -eq 'duplicate_reused'){'duplicate_reused'}else{'semantic_artifact_committed'}) 0 ([pscustomobject]@{ArtifactId=[string]$submission.output_artifact_id;RevisionPath=$revisionRelative;PointerPath=$pointerRelative;LineagePath=$lineagePath.Substring($sessionRoot.Length+1).Replace('\','/');EventId=[string]$write.Event.event_id;NextStepId=$projection.Projection.next_step_id;RouteClass=$routeClass}) @()
}

function Reconcile-R7RuntimeSubmission {
  param([string]$ProjectRoot,[string]$Session,[string]$SubmissionId)
  $sessionRoot=[IO.Path]::GetFullPath($Session)
  $path="intermediate/r7/submissions/$SubmissionId.json"
  $result=Submit-R7RuntimeArtifact $ProjectRoot $sessionRoot $path
  if($result.ExitCode -eq 0 -and $result.ResultCode -eq 'semantic_artifact_committed'){$result.ResultCode='submission_reconciled'}
  return $result
}
