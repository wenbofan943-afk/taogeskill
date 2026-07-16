Set-StrictMode -Version 2.0

if(-not(Get-Command Write-TaogeUtf8NoBomJson -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')}

function Test-R7MaturityProperty {
  param([object]$Object,[string]$Name)
  return $null-ne$Object -and $null-ne$Object.PSObject.Properties[$Name]
}

function Read-R7MaturityJson {
  param([Parameter(Mandatory=$true)][string]$Path)
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "evidence_file_missing:$Path"}
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Test-R7MaturitySchemaInstance {
  param([Parameter(Mandatory=$true)][string]$SchemaPath,[Parameter(Mandatory=$true)][string]$InstancePath)
  $schema=Read-R7MaturityJson $SchemaPath;$instance=Read-R7MaturityJson $InstancePath;$errors=[Collections.Generic.List[string]]::new()
  foreach($name in @($schema.required)){if(-not(Test-R7MaturityProperty $instance ([string]$name))){$errors.Add("required_missing:$name")}}
  if((Test-R7MaturityProperty $schema 'additionalProperties')-and$schema.additionalProperties-eq$false){foreach($property in @($instance.PSObject.Properties.Name)){if(-not(Test-R7MaturityProperty $schema.properties ([string]$property))){$errors.Add("additional_property:$property")}}}
  foreach($property in @($schema.properties.PSObject.Properties)){
    $name=[string]$property.Name;if(-not(Test-R7MaturityProperty $instance $name)){continue};$rule=$property.Value;$value=$instance.$name
    if(Test-R7MaturityProperty $rule 'const'){if([string]$value-ne[string]$rule.const){$errors.Add("const_mismatch:$name")}}
    if(Test-R7MaturityProperty $rule 'enum'){if([string]$value-notin@($rule.enum|ForEach-Object{[string]$_})){$errors.Add("enum_mismatch:$name")}}
    if((Test-R7MaturityProperty $rule 'pattern')-and[string]$value-notmatch[string]$rule.pattern){$errors.Add("pattern_mismatch:$name")}
    if(Test-R7MaturityProperty $rule 'type'){
      $valid=switch([string]$rule.type){'string'{$value-is[string]}'array'{$value-is[Collections.IEnumerable]-and$value-isnot[string]}'object'{$null-ne$value-and$value-isnot[string]-and$value-isnot[ValueType]}'integer'{$value-is[int]-or$value-is[long]}'boolean'{$value-is[bool]}default{$true}}
      if(-not$valid){$errors.Add("type_mismatch:$name")}
    }
  }
  return [object[]]$errors.ToArray()
}

function Get-R7MaturityHashText {
  param([Parameter(Mandatory=$true)][string]$Text)
  $sha=[Security.Cryptography.SHA256]::Create()
  try{$bytes=[Text.Encoding]::UTF8.GetBytes($Text);return 'sha256:'+([BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant())}finally{$sha.Dispose()}
}

function Get-R7MaturityFileHash {
  param([Parameter(Mandatory=$true)][string]$Path)
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "capability_entry_missing:$Path"}
  $stream=[IO.File]::OpenRead($Path);$sha=[Security.Cryptography.SHA256]::Create()
  try{return 'sha256:'+([BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant())}finally{$sha.Dispose();$stream.Dispose()}
}

function Test-R7MaturityDateTime {
  param([string]$Value)
  $parsed=[datetimeoffset]::MinValue
  return -not[string]::IsNullOrWhiteSpace($Value) -and $Value-match '^\d{4}-\d{2}-\d{2}T.+(Z|[+-]\d{2}:\d{2})$' -and [datetimeoffset]::TryParse($Value,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$parsed)
}

function Resolve-R7MaturityProjectPath {
  param([string]$ProjectRoot,[string]$RelativePath)
  $root=[IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')
  $path=[IO.Path]::GetFullPath((Join-Path $root $RelativePath))
  if(-not($path.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase))){throw "capability_path_outside_project:$RelativePath"}
  return $path
}

function Get-R7CapabilityMaterialization {
  param([string]$ProjectRoot,[object]$Registry)
  $seen=@{};$items=[Collections.Generic.List[object]]::new()
  foreach($capability in @($Registry.capabilities|Sort-Object capability_id)){
    $id=[string]$capability.capability_id
    if([string]::IsNullOrWhiteSpace($id)-or$seen.ContainsKey($id)){throw "capability_id_invalid_or_duplicate:$id"};$seen[$id]=$true
    $mode=[string]$capability.identity_mode;$entry=[string]$capability.producer_entry
    $identity=switch($mode){'local_file'{Get-R7MaturityFileHash (Resolve-R7MaturityProjectPath $ProjectRoot $entry)}'provider_identity'{Get-R7MaturityHashText "provider|$id|$entry|$($capability.version)"}'human_gate_identity'{Get-R7MaturityHashText "human_gate|$id|$entry|$($capability.version)"}default{throw "capability_identity_mode_invalid:${id}:$mode"}}
    $items.Add([pscustomobject][ordered]@{capability_id=$id;kind=[string]$capability.kind;producer_entry=$entry;version=[string]$capability.version;identity_mode=$mode;observed_identity=$identity;coverage_categories=[object[]]@($capability.coverage_categories)})
  }
  return [object[]]$items.ToArray()
}

function Get-R7ContractSurfaceMaterialization {
  param([string]$ProjectRoot,[object]$Registry)
  $seen=@{};$surfaces=[Collections.Generic.List[object]]::new()
  foreach($surface in @($Registry.contract_surfaces|Sort-Object surface_id)){
    $surfaceId=[string]$surface.surface_id;if([string]::IsNullOrWhiteSpace($surfaceId)-or$seen.ContainsKey($surfaceId)){throw "contract_surface_invalid_or_duplicate:$surfaceId"};$seen[$surfaceId]=$true
    $files=[Collections.Generic.List[object]]::new();foreach($relativePath in @($surface.paths|Sort-Object)){$path=[string]$relativePath;$files.Add([pscustomobject][ordered]@{path=$path;sha256=Get-R7MaturityFileHash (Resolve-R7MaturityProjectPath $ProjectRoot $path)})}
    if($files.Count-lt1){throw "contract_surface_empty:$surfaceId"};$surfaceDigest=Get-R7MaturityHashText ([string]::Join("`n",@($files|ForEach-Object{"$($_.path)|$($_.sha256)"})))
    $surfaces.Add([pscustomobject][ordered]@{surface_id=$surfaceId;surface_digest=$surfaceDigest;files=[object[]]$files.ToArray()})
  }
  if($surfaces.Count-lt4){throw 'contract_surface_bundle_incomplete'};return [object[]]$surfaces.ToArray()
}

function New-R7MaturityBaseline {
  param([string]$ProjectRoot,[string]$RegistryPath,[string]$BaselineId,[string]$CreatedAt,[string]$OutputPath)
  if(-not(Test-R7MaturityDateTime $CreatedAt)){throw 'baseline_created_at_invalid'}
  $registry=Read-R7MaturityJson $RegistryPath;$surfaces=Get-R7ContractSurfaceMaterialization $ProjectRoot $registry;$capabilities=Get-R7CapabilityMaterialization $ProjectRoot $registry
  $digestSource=[string]::Join("`n",@($surfaces|ForEach-Object{"surface|$($_.surface_id)|$($_.surface_digest)"})+@($capabilities|ForEach-Object{"capability|$($_.capability_id)|$($_.kind)|$($_.version)|$($_.observed_identity)"}))
  $result=[pscustomobject][ordered]@{schema_id='taoge://schemas/r7/maturity-baseline/v0.1';schema_version='0.1';baseline_id=$BaselineId;maturity_baseline_digest=Get-R7MaturityHashText $digestSource;registry_ref='routes/r7-runtime-capability-registry.json';contract_surfaces=$surfaces;capabilities=$capabilities;created_at=$CreatedAt}
  Write-TaogeUtf8NoBomJson -Path $OutputPath -Value $result -Depth 20;return $result
}

function New-R7RunCapabilitySnapshot {
  param([string]$ProjectRoot,[string]$RegistryPath,[string]$BaselinePath,[string]$SnapshotId,[string]$SessionId,[string]$RunStartedAt,[string]$OutputPath)
  if(-not(Test-R7MaturityDateTime $RunStartedAt)){throw 'run_started_at_invalid'}
  $baseline=Read-R7MaturityJson $BaselinePath;$registry=Read-R7MaturityJson $RegistryPath;$surfaces=Get-R7ContractSurfaceMaterialization $ProjectRoot $registry;$capabilities=Get-R7CapabilityMaterialization $ProjectRoot $registry
  $digestSource=[string]::Join("`n",@($surfaces|ForEach-Object{"surface|$($_.surface_id)|$($_.surface_digest)"})+@($capabilities|ForEach-Object{"capability|$($_.capability_id)|$($_.kind)|$($_.version)|$($_.observed_identity)"}));$digest=Get-R7MaturityHashText $digestSource
  if($digest-ne[string]$baseline.maturity_baseline_digest){throw 'maturity_baseline_changed'}
  $result=[pscustomobject][ordered]@{schema_id='taoge://schemas/r7/run-capability-snapshot/v0.1';schema_version='0.1';snapshot_id=$SnapshotId;session_id=$SessionId;maturity_baseline_digest=$digest;run_started_at=$RunStartedAt;contract_surfaces=$surfaces;capabilities=$capabilities}
  Write-TaogeUtf8NoBomJson -Path $OutputPath -Value $result -Depth 20;return $result
}

function Add-R7Intervention {
  param([Collections.Generic.List[object]]$List,[string]$Code,[string]$Evidence,[string]$Owner='runtime')
  $List.Add([pscustomobject][ordered]@{intervention_code=$Code;evidence=$Evidence;owning_capability=$Owner})
}

function Get-R7InputFingerprint {
  param([object]$Observation)
  $identity=$Observation.input_identity;$route=[string]$Observation.entry_route
  $required=if($route-eq'direct_delivery'){@('account_identity_digest','original_normalized_body_digest','intake_mode')}else{@('account_identity_digest','event_cluster_digest','selected_source_set_digest')}
  foreach($field in $required){if(-not(Test-R7MaturityProperty $identity $field)-or[string]::IsNullOrWhiteSpace([string]$identity.$field)){throw "input_identity_missing:$field"}}
  $source=[string]::Join('|',@($required|ForEach-Object{[string]$identity.$_}))
  $distinct=if($route-eq'hotspot_to_delivery'){[string]$identity.event_cluster_digest}else{$source}
  return [pscustomobject]@{Fingerprint=Get-R7MaturityHashText $source;DistinctnessKey=$distinct}
}

function Invoke-R7SessionAutonomyEvaluation {
  param([string]$ObservationPath,[string]$SnapshotPath,[string]$LedgerOutputPath,[string]$EvidenceOutputPath)
  $observation=Read-R7MaturityJson $ObservationPath;$snapshot=Read-R7MaturityJson $SnapshotPath
  if([string]$observation.maturity_baseline_digest-ne[string]$snapshot.maturity_baseline_digest){throw 'session_baseline_mismatch'}
  if([string]$observation.session_id-ne[string]$snapshot.session_id){throw 'session_snapshot_identity_mismatch'}
  if(-not(Test-R7MaturityDateTime ([string]$observation.run_started_at))){throw 'run_started_at_invalid'}
  $registered=@{};foreach($cap in @($snapshot.capabilities)){$registered[[string]$cap.capability_id]=$cap}
  $interventions=[Collections.Generic.List[object]]::new();$completed=@{};$semanticParity=$true;$deterministicParity=$true;$externalParity=$true;$humanParity=$true;$coverage=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach($step in @($observation.step_executions)){
    $stepId=[string]$step.step_id;$capabilityId=[string]$step.capability_id;$completed[$stepId]=$step
    if(-not$registered.ContainsKey($capabilityId)){Add-R7Intervention $interventions 'unregistered_execution' "$stepId|$capabilityId" $capabilityId}
    $source=[string]$step.execution_source;if($source-notin@('skill_defined','deterministic_runtime','external_provider','human_gate')){Add-R7Intervention $interventions 'agent_or_manual_execution' "$stepId|$source" $capabilityId}
    if([string]$step.status-ne'succeeded'){if([string]$step.step_kind-eq'semantic'){$semanticParity=$false}else{$deterministicParity=$false}}
    foreach($category in @($step.coverage_categories)){if(-not[string]::IsNullOrWhiteSpace([string]$category)){$null=$coverage.Add([string]$category)}}
  }
  foreach($expected in @($observation.expected_step_ids)){if(-not$completed.ContainsKey([string]$expected)){$semanticParity=$false;$deterministicParity=$false}}
  foreach($commit in @($observation.artifact_commits)){
    $capabilityId=[string]$commit.producer_capability_id
    if(-not$registered.ContainsKey($capabilityId)){Add-R7Intervention $interventions 'artifact_unregistered_producer' "$($commit.artifact_id)|$capabilityId" $capabilityId}
    if([string]::IsNullOrWhiteSpace([string]$commit.receipt_ref)-or[string]::IsNullOrWhiteSpace([string]$commit.event_ref)){Add-R7Intervention $interventions 'artifact_commit_provenance_missing' ([string]$commit.artifact_id) $capabilityId}
  }
  foreach($task in @($observation.external_tasks)){
    $capabilityId=[string]$task.capability_id;if(-not$registered.ContainsKey($capabilityId)){Add-R7Intervention $interventions 'external_task_unregistered' "$($task.task_id)|$capabilityId" $capabilityId}
    if([string]$task.status-eq'succeeded' -and (@($task.attempt_refs).Count-lt1-or[string]::IsNullOrWhiteSpace([string]$task.outcome_ref)-or[string]::IsNullOrWhiteSpace([string]$task.output_ref))){$externalParity=$false;Add-R7Intervention $interventions 'external_evidence_parity_missing' ([string]$task.task_id) $capabilityId}
    foreach($category in @($task.coverage_categories)){if(-not[string]::IsNullOrWhiteSpace([string]$category)){$null=$coverage.Add([string]$category)}}
  }
  foreach($gate in @($observation.human_gates)){
    $capabilityId=[string]$gate.capability_id;$valid=$registered.ContainsKey($capabilityId)-and[string]$registered[$capabilityId].kind-eq'human_gate'-and[string]$gate.status-eq'completed'-and-not[string]::IsNullOrWhiteSpace([string]$gate.typed_decision_ref)
    if(-not$valid){$humanParity=$false;Add-R7Intervention $interventions 'unregistered_or_untyped_human_action' ([string]$gate.gate_id) $capabilityId}
  }
  foreach($write in @($observation.file_writes)){
    $capabilityId=[string]$write.writer_capability_id
    if(-not$registered.ContainsKey($capabilityId)){Add-R7Intervention $interventions 'file_write_unregistered_producer' "$($write.relative_path)|$capabilityId" $capabilityId}
    if(-not[bool]$write.registered_output){$code=if([string]$write.relative_path-match'(?i)(candidate|final-delivery\.html|current-pointer|execution-events)'){'machine_object_producer_bypass'}else{'run_specific_helper_output'};Add-R7Intervention $interventions $code ([string]$write.relative_path) $capabilityId}
  }
  foreach($declaration in @($observation.manual_intervention_declarations)){Add-R7Intervention $interventions 'declared_manual_intervention' ([string]$declaration.description) 'declared'}
  $fingerprint=Get-R7InputFingerprint $observation;$deliveryStatus=[string]$observation.final_delivery.status;$blockers=@($observation.current_contract_blockers)
  $allParity=$semanticParity-and$deterministicParity-and$externalParity-and$humanParity
  $outcome=if($deliveryStatus-eq'delivered' -and $allParity-and$interventions.Count-eq0-and$blockers.Count-eq0){'autonomous_delivery'}elseif($deliveryStatus-eq'waiting' -and $interventions.Count-eq0){$null=$coverage.Add('honest_waiting');'autonomous_waiting'}elseif($deliveryStatus-eq'delivered'){'assisted_delivery'}else{'failed'}
  $ledger=[pscustomobject][ordered]@{schema_id='taoge://schemas/r7/intervention-ledger/v0.1';schema_version='0.1';ledger_id="ledger-$($observation.session_id)";session_id=[string]$observation.session_id;derived_from_observation_ref=[IO.Path]::GetFullPath($ObservationPath);interventions=[object[]]$interventions.ToArray();intervention_count=$interventions.Count;manual_patch_detected=($interventions.Count-gt0)}
  Write-TaogeUtf8NoBomJson -Path $LedgerOutputPath -Value $ledger -Depth 20
  $evidence=[pscustomobject][ordered]@{schema_id='taoge://schemas/r7/session-autonomy-evidence/v0.1';schema_version='0.1';evidence_id="session-evidence-$($observation.session_id)";session_id=[string]$observation.session_id;entry_route=[string]$observation.entry_route;maturity_baseline_digest=[string]$observation.maturity_baseline_digest;run_started_at=[string]$observation.run_started_at;input_fingerprint=[string]$fingerprint.Fingerprint;input_distinctness_key=[string]$fingerprint.DistinctnessKey;outcome=$outcome;semantic_step_parity=$semanticParity;deterministic_step_parity=$deterministicParity;external_side_effect_parity=$externalParity;human_gate_parity=$humanParity;intervention_ledger_ref=[IO.Path]::GetFullPath($LedgerOutputPath);final_delivery_ref=[string]$observation.final_delivery.ref;coverage_categories=[object[]]@($coverage|Sort-Object);current_contract_blockers=[object[]]$blockers}
  Write-TaogeUtf8NoBomJson -Path $EvidenceOutputPath -Value $evidence -Depth 20;return $evidence
}

function New-R7AutonomyCertificationCohort {
  param([string]$CohortId,[string]$MaturityBaselineDigest,[string]$OpenedAt,[string]$OutputPath)
  if(-not(Test-R7MaturityDateTime $OpenedAt)){throw 'cohort_opened_at_invalid'}
  $cohort=[pscustomobject][ordered]@{schema_id='taoge://schemas/r7/autonomy-certification-cohort/v0.1';schema_version='0.1';cohort_id=$CohortId;maturity_baseline_digest=$MaturityBaselineDigest;opened_at=$OpenedAt;route_ledgers=[pscustomobject][ordered]@{direct_delivery=@();hotspot_to_delivery=@()};capability_coverage=@();current_contract_blockers=@()}
  Write-TaogeUtf8NoBomJson -Path $OutputPath -Value $cohort -Depth 30;return $cohort
}

function Add-R7SessionEvidenceToCohort {
  param([string]$CohortPath,[string]$SessionEvidencePath)
  $cohort=Read-R7MaturityJson $CohortPath;$evidence=Read-R7MaturityJson $SessionEvidencePath
  if([string]$cohort.maturity_baseline_digest-ne[string]$evidence.maturity_baseline_digest){throw 'cohort_baseline_mismatch'}
  $route=[string]$evidence.entry_route;if($route-notin@('direct_delivery','hotspot_to_delivery')){throw 'cohort_route_invalid'}
  $all=@($cohort.route_ledgers.direct_delivery)+@($cohort.route_ledgers.hotspot_to_delivery);$duplicate=@($all|Where-Object{$_.session_id-eq$evidence.session_id})
  $evidenceDigest=Get-R7MaturityFileHash $SessionEvidencePath
  if($duplicate.Count){if([string]$duplicate[0].evidence_digest-eq$evidenceDigest){return [pscustomobject]@{result_code='duplicate_reused';cohort=$cohort}};throw 'cohort_session_evidence_conflict'}
  $entry=[pscustomobject][ordered]@{session_id=[string]$evidence.session_id;run_started_at=[string]$evidence.run_started_at;outcome=[string]$evidence.outcome;input_fingerprint=[string]$evidence.input_fingerprint;input_distinctness_key=[string]$evidence.input_distinctness_key;evidence_ref=[IO.Path]::GetFullPath($SessionEvidencePath);evidence_digest=$evidenceDigest;coverage_categories=[object[]]@($evidence.coverage_categories)}
  $ledger=@($cohort.route_ledgers.$route)+@($entry);$cohort.route_ledgers.$route=[object[]]@($ledger|Sort-Object @{Expression={[datetimeoffset]::Parse($_.run_started_at)}},session_id)
  $coverage=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);foreach($category in @($cohort.capability_coverage)+@($evidence.coverage_categories)){$null=$coverage.Add([string]$category)};$cohort.capability_coverage=[object[]]@($coverage|Sort-Object)
  $blockers=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);foreach($item in @($cohort.current_contract_blockers)+@($evidence.current_contract_blockers)){$null=$blockers.Add([string]$item)};$cohort.current_contract_blockers=[object[]]@($blockers|Sort-Object)
  Write-TaogeUtf8NoBomJson -Path $CohortPath -Value $cohort -Depth 30;return [pscustomobject]@{result_code='session_appended';cohort=$cohort}
}

function Get-R7RouteAutonomyEvidence {
  param([string]$CohortPath,[ValidateSet('direct_delivery','hotspot_to_delivery')][string]$Route,[string]$OutputPath)
  $cohort=Read-R7MaturityJson $CohortPath;$count=0;$fingerprints=[Collections.Generic.List[string]]::new();$keys=[Collections.Generic.List[string]]::new()
  foreach($entry in @($cohort.route_ledgers.$Route)){
    switch([string]$entry.outcome){'autonomous_delivery'{$count++;$fingerprints.Add([string]$entry.input_fingerprint);$keys.Add([string]$entry.input_distinctness_key)}'autonomous_waiting'{}default{$count=0;$fingerprints.Clear();$keys.Clear()}}
  }
  $distinct=@($fingerprints|Select-Object -Unique);$distinctKeys=@($keys|Select-Object -Unique);$isL3=$count-ge2-and$distinct.Count-ge2-and($Route-ne'hotspot_to_delivery'-or$distinctKeys.Count-ge2)
  $status=if($isL3){'l3'}elseif($count-ge1){'candidate'}else{'not_proven'}
  $result=[pscustomobject][ordered]@{schema_id='taoge://schemas/r7/route-autonomy-evidence/v0.1';schema_version='0.1';route_evidence_id="$($cohort.cohort_id)-$Route";route_id=$Route;maturity_baseline_digest=[string]$cohort.maturity_baseline_digest;ordered_sample_refs=[object[]]@($cohort.route_ledgers.$Route);consecutive_autonomous_delivery_count=$count;distinct_input_fingerprints=[object[]]$distinct;route_status=$status}
  Write-TaogeUtf8NoBomJson -Path $OutputPath -Value $result -Depth 30;return $result
}

function Get-R7ProjectMaturityEvidence {
  param([string]$CohortPath,[string]$DirectRoutePath,[string]$HotspotRoutePath,[string]$OutputPath)
  $cohort=Read-R7MaturityJson $CohortPath;$direct=Read-R7MaturityJson $DirectRoutePath;$hotspot=Read-R7MaturityJson $HotspotRoutePath
  foreach($item in @($direct,$hotspot)){if([string]$item.maturity_baseline_digest-ne[string]$cohort.maturity_baseline_digest){throw 'project_route_baseline_mismatch'}}
  $required=@('generated_context','source_bound_evidence','explicit_existing_asset','deterministic_postprocess','revision_resume','honest_waiting');$missing=@($required|Where-Object{$_-notin@($cohort.capability_coverage)})
  $routesReady=[string]$direct.route_status-eq'l3'-and[string]$hotspot.route_status-eq'l3';$blockers=@($cohort.current_contract_blockers)
  $status=if($routesReady-and$missing.Count-eq0-and$blockers.Count-eq0){'l3'}elseif($routesReady){'l3_candidate'}else{'l2_8'}
  $result=[pscustomobject][ordered]@{schema_id='taoge://schemas/r7/project-maturity-evidence/v0.1';schema_version='0.1';project_evidence_id="$($cohort.cohort_id)-project";maturity_baseline_digest=[string]$cohort.maturity_baseline_digest;direct_route_evidence_ref=[IO.Path]::GetFullPath($DirectRoutePath);hotspot_route_evidence_ref=[IO.Path]::GetFullPath($HotspotRoutePath);capability_coverage=[object[]]@($cohort.capability_coverage);missing_capability_coverage=[object[]]$missing;unresolved_current_contract_blockers=[object[]]$blockers;project_status=$status}
  Write-TaogeUtf8NoBomJson -Path $OutputPath -Value $result -Depth 30;return $result
}
