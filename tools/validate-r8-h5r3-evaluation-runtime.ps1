param(
  [string]$ProjectRoot = '',
  [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
} else {
  $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = Join-Path $ProjectRoot 'state/checks/r8-h5r3-evaluation-runtime-report.json'
}
. (Join-Path $PSScriptRoot 'R8H5EvaluationRuntime.ps1')
Initialize-R8H5EvaluationRuntime $ProjectRoot

function Copy-R8H5FixtureObject {
  param([object]$Value)
  return $Value | ConvertTo-Json -Depth 60 -Compress | ConvertFrom-Json
}

function New-R8H5FixtureArtifactRef {
  param([string]$ArtifactId,[string]$Seed)
  return [pscustomobject][ordered]@{
    artifact_id = $ArtifactId
    revision = 1
    sha256 = Get-R8H5TextDigest $Seed
  }
}

function New-R8H5FixtureBusinessOutput {
  param([object]$SemanticCase,[string]$ArmRole,[string]$Profile,[object]$ScenarioArm)
  $suffix = "$($SemanticCase.semantic_case_id)-$ArmRole"
  if ($Profile -eq 'hotspot_valid') {
    $request = $SemanticCase.semantic_input.request_context
    $topicId = "TOPIC-$suffix"
    $topicDigest = Get-R8H5TextDigest "topic|$suffix"
    $topicRef = [pscustomobject][ordered]@{
      component_type = 'topic_option'
      component_id = $topicId
      component_sha256 = $topicDigest
    }
    return [pscustomobject][ordered]@{
      schema_id = 'taoge://schemas/r7/hotspot-research-set/v0.1'
      schema_version = '0.1.0'
      research_set_id = "RESEARCH-SET-$suffix"
      research_set_revision = 1
      account_identity_ref = $request.account_identity_ref
      account_snapshot_ref = $request.account_snapshot_ref
      radar_policy_ref = $request.radar_policy_ref
      research_request_ref = New-R8H5FixtureArtifactRef $request.research_request_id "request|$suffix"
      research_run_record = [pscustomobject]@{ run_id = "RUN-$suffix" }
      signals = @([pscustomobject]@{ signal_id = "SIGNAL-$suffix" })
      events = @([pscustomobject]@{ event_id = "EVENT-$suffix" })
      candidates = @([pscustomobject]@{ candidate_id = "CANDIDATE-$suffix" })
      topic_options = @([pscustomobject][ordered]@{
        topic_id = $topicId
        used_vehicle_direct_relevance = $true
        fact_status = 'verified_fixture'
      })
      topic_evidence_packets = @([pscustomobject]@{ topic_id = $topicId })
      panel_model = [pscustomobject][ordered]@{
        ordered_topic_option_refs = @($topicRef)
        recommended_topic_ref = $topicRef
        recommendation_reason = 'Fixture recommendation with direct used-vehicle relevance.'
      }
      source_records = @([pscustomobject]@{ source_id = "SOURCE-$suffix" })
      ledger_write_refs = @()
      component_digest_map = [pscustomobject]@{ topic = $topicDigest }
      researched_at = '2026-07-18T10:30:00+08:00'
      research_set_status = 'ready_for_panel'
    }
  }
  if ($Profile -eq 'router_valid') {
    return [pscustomobject][ordered]@{
      schema_id = 'taoge://schemas/r8/h5/business/router-decision/v0.1'
      schema_version = '0.1'
      router_decision_id = "ROUTER-DECISION-$suffix"
      intent = $SemanticCase.semantic_input.entry_router_request.intent
      decision_status = 'selected'
      selected_node_id = $ScenarioArm.selected_node_id
      executed_node_id = $null
      reason_code = 'registered_next_node_selected'
      next_action = $ScenarioArm.selected_node_id
    }
  }
  if ($Profile -eq 'platform_valid') {
    $packages = @()
    foreach ($platform in @($SemanticCase.semantic_input.target_platforms)) {
      $packages += [pscustomobject][ordered]@{
        platform = $platform
        title = "Title for $platform"
        cover_title = "Cover for $platform"
        body_text = $SemanticCase.semantic_input.draft.body_text
        hashtags = @('used-vehicle')
        notes = @('fixture-only')
      }
    }
    $payload = [ordered]@{
      schema_id = if ($ArmRole -eq 'baseline') { 'taoge://schemas/r7/platform-package/v0.1' } else { 'taoge://schemas/r7/platform-package/v0.2' }
      schema_version = if ($ArmRole -eq 'baseline') { '0.1' } else { '0.2' }
      platform_package_id = "PLATFORM-PACKAGE-$suffix"
    }
    if ($ArmRole -eq 'candidate') { $payload.delivery_title = 'Fixture delivery title' }
    $payload.draft_ref = [pscustomobject]@{ draft_id = $SemanticCase.semantic_input.draft.draft_id }
    $payload.primary_platform = $SemanticCase.semantic_input.target_platforms[0]
    $payload.packages = @($packages)
    $payload.package_status = 'package_pass'
    $payload.next_skill = 'cover-design-compiler'
    return [pscustomobject]$payload
  }
  throw "fixture_output_profile_unknown:$Profile"
}

function New-R8H5FixtureRecordRequest {
  param([object]$SemanticCase,[string]$ArmRole,[object]$ScenarioArm,[string]$EvaluatedAt)
  $outputPath = if ([string]::IsNullOrWhiteSpace([string]$ScenarioArm.output_profile)) {
    $null
  } else {
    "cases/$($SemanticCase.semantic_case_id)/$ArmRole/business-output.json"
  }
  $requestedNode = switch ($SemanticCase.skill_id) {
    'hotspot-topic-research' { 'hotspot_research' }
    'propagation-router' { 'propagation_router' }
    'platform-packaging-adapter' { 'platform_package_h7' }
  }
  return [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r8/h5/requests/h5-arm-result-record-request/v0.1'
    schema_version = '0.1'
    semantic_case_id = $SemanticCase.semantic_case_id
    arm_role = $ArmRole
    skill_id = $SemanticCase.skill_id
    arm_input_ref = "cases/$($SemanticCase.semantic_case_id)/$ArmRole/arm-input.json"
    prompt_digest = Get-R8H5TextDigest "prompt|$($SemanticCase.semantic_case_id)|$ArmRole"
    reported_result_status = $ScenarioArm.status
    requested_node_id = $requestedNode
    selected_node_id = $ScenarioArm.selected_node_id
    executed_node_id = $ScenarioArm.executed_node_id
    reference_load_observation = 'observed'
    loaded_reference_ids = @()
    manual_assist_observation = 'not_observable'
    manual_assist_count = $null
    duration_ms = 100
    token_observation = 'not_observable'
    input_tokens = $null
    business_output_relative_path = $outputPath
    result_recorded_at = $EvaluatedAt
    supersedes = $null
  }
}

$errors = [System.Collections.Generic.List[string]]::new()
$negativePass = 0
$h5r2FixturePath = Join-Path $ProjectRoot 'examples/r8-h5r2-input-fixtures/cases.json'
$h5r3FixturePath = Join-Path $ProjectRoot 'examples/r8-h5r3-evaluation-fixtures/scenarios.json'
$h5r2 = Read-R8H5EvaluationJson $h5r2FixturePath
$h5r3 = Read-R8H5EvaluationJson $h5r3FixturePath
$head = Get-R8H5GitCommit $ProjectRoot 'HEAD'
$surfaceText = [string]::Join("`n",@(
  [System.IO.File]::ReadAllText($h5r2FixturePath,(Get-TaogeUtf8NoBomEncoding)),
  [System.IO.File]::ReadAllText($h5r3FixturePath,(Get-TaogeUtf8NoBomEncoding)),
  [System.IO.File]::ReadAllText((Join-Path $ProjectRoot 'tools/R8H5EvaluationRuntime.ps1'),(Get-TaogeUtf8NoBomEncoding)),
  [System.IO.File]::ReadAllText((Join-Path $ProjectRoot 'tools/R8H5SchemaRuntime.ps1'),(Get-TaogeUtf8NoBomEncoding)),
  [System.IO.File]::ReadAllText((Join-Path $ProjectRoot 'tools/invoke-r8-h5r3-evaluation.ps1'),(Get-TaogeUtf8NoBomEncoding)),
  [System.IO.File]::ReadAllText((Join-Path $ProjectRoot 'routes/r8-h5-machine-evaluation.yaml'),(Get-TaogeUtf8NoBomEncoding)),
  [System.IO.File]::ReadAllText((Join-Path $ProjectRoot 'templates/schema/r8/h5/requests/h5-arm-result-record-request.v0.1.schema.json'),(Get-TaogeUtf8NoBomEncoding)),
  [System.IO.File]::ReadAllText((Join-Path $ProjectRoot 'templates/schema/r8/h5/business/router-decision.v0.1.schema.json'),(Get-TaogeUtf8NoBomEncoding))
))
$surfaceDigest = (Get-R8H5TextDigest $surfaceText).Substring(7,12)
$evaluationId = "EVAL-R8-H5R3-$($head.Substring(0,8))-$surfaceDigest"
$attemptId = 'ATTEMPT-001'
$evaluationRoot = Join-Path $ProjectRoot "state/checks/r8/$evaluationId/$attemptId"

$semanticById = @{}
foreach ($case in @($h5r2.cases)) {
  [void](Invoke-R8H5CaseCompile $ProjectRoot $case $evaluationId $attemptId $evaluationRoot $h5r3.evaluated_at)
  $semanticPath = Resolve-R8H5EvaluationPath $evaluationRoot "cases/$($case.semantic_case_id)/semantic-case.json"
  $semanticById[$case.semantic_case_id] = Read-R8H5EvaluationJson $semanticPath
}

$recordRequests = @()
foreach ($scenario in @($h5r3.scenarios)) {
  $semantic = $semanticById[[string]$scenario.semantic_case_id]
  if ($null -eq $semantic) { $errors.Add("scenario_semantic_case_missing:$($scenario.semantic_case_id)"); continue }
  foreach ($armRole in @('baseline','candidate')) {
    $scenarioArm = $scenario.$armRole
    if (-not [string]::IsNullOrWhiteSpace([string]$scenarioArm.output_profile)) {
      $output = New-R8H5FixtureBusinessOutput $semantic $armRole $scenarioArm.output_profile $scenarioArm
      $outputPath = Resolve-R8H5EvaluationPath $evaluationRoot "cases/$($semantic.semantic_case_id)/$armRole/business-output.json"
      [void](Write-R8H5ImmutableJson $outputPath $output)
    }
    $recordRequests += New-R8H5FixtureRecordRequest $semantic $armRole $scenarioArm $h5r3.evaluated_at
  }
}
$recordCatalogPath = Join-Path $evaluationRoot 'h5r3-record-requests.json'
[void](Write-R8H5ImmutableJson $recordCatalogPath ([pscustomobject][ordered]@{
  schema_id = 'taoge://fixtures/r8/h5r3-record-requests/v0.1'
  record_requests = @($recordRequests)
}))

$cli = Join-Path $ProjectRoot 'tools/invoke-r8-h5r3-evaluation.ps1'
$cliResult = Invoke-TaogeProcessCapture -FilePath 'powershell.exe' -Arguments @(
  '-NoProfile','-ExecutionPolicy','Bypass','-File',$cli,
  '-ProjectRoot',$ProjectRoot,'-EvaluationRoot',$evaluationRoot,
  '-RecordRequestPath',$recordCatalogPath,'-EvaluatedAt',$h5r3.evaluated_at
)
if ($cliResult.stdout -notmatch 'result=evaluation_completed') { $errors.Add('h5r3_cli_result_missing') }

$armResultCount = 0
$machineCount = 0
$comparabilityCount = 0
foreach ($scenario in @($h5r3.scenarios)) {
  $caseRoot = Resolve-R8H5EvaluationPath $evaluationRoot "cases/$($scenario.semantic_case_id)"
  foreach ($armRole in @('baseline','candidate')) {
    $result = Read-R8H5EvaluationJson (Join-Path $caseRoot "$armRole/arm-result.json")
    $armResultCount++
    $schemaErrors = @(Test-R8H5JsonSchemaValue (Join-Path $ProjectRoot 'templates/schema/r8/h5/h5-arm-result.v0.2.schema.json') $result)
    if ($schemaErrors.Count -gt 0) { $errors.Add("arm_result_schema_fail:$($scenario.semantic_case_id):${armRole}:$($schemaErrors -join ',')") }
  }
  $machine = Read-R8H5EvaluationJson (Join-Path $caseRoot 'machine-verdict.json')
  $comparison = Read-R8H5EvaluationJson (Join-Path $caseRoot 'comparability-verdict.json')
  $machineCount++
  $comparabilityCount++
  if ($machine.verdict_status -ne $scenario.expected_machine_status) { $errors.Add("machine_status_mismatch:$($scenario.semantic_case_id)") }
  if ($comparison.comparability_status -ne $scenario.expected_comparability_status) { $errors.Add("comparability_status_mismatch:$($scenario.semantic_case_id)") }
  if (($comparison.comparability_status -eq 'comparable') -ne ($comparison.blind_pair_allowed -eq $true)) {
    $errors.Add("blind_eligibility_mismatch:$($scenario.semantic_case_id)")
  }
  foreach ($pair in @(
    @('templates/schema/r8/h5/h5-machine-verdict.v0.2.schema.json',$machine),
    @('templates/schema/r8/h5/h5-comparability-verdict.v0.2.schema.json',$comparison)
  )) {
    $schemaErrors = @(Test-R8H5JsonSchemaValue (Join-Path $ProjectRoot $pair[0]) $pair[1])
    if ($schemaErrors.Count -gt 0) { $errors.Add("verdict_schema_fail:$($scenario.semantic_case_id):$($schemaErrors -join ',')") }
  }
}

$normalSemantic = $semanticById['CASE-HOTSPOT-NORMAL-001']
$normalRequest = @($recordRequests | Where-Object { $_.semantic_case_id -eq $normalSemantic.semantic_case_id -and $_.arm_role -eq 'baseline' })[0]

$missingOutput = Copy-R8H5FixtureObject $normalRequest
$missingOutput.business_output_relative_path = $null
if ((New-R8H5ArmResult $evaluationRoot $missingOutput).result_status -eq 'invalid_output') { $negativePass++ } else { $errors.Add('false_success_missing_output') }

$invalidOutputPath = Resolve-R8H5EvaluationPath $evaluationRoot 'negative/invalid-output.json'
[void](Write-R8H5ImmutableJson $invalidOutputPath ([pscustomobject]@{schema_id='wrong'}))
$invalidOutput = Copy-R8H5FixtureObject $normalRequest
$invalidOutput.business_output_relative_path = 'negative/invalid-output.json'
if ((New-R8H5ArmResult $evaluationRoot $invalidOutput).result_status -eq 'invalid_output') { $negativePass++ } else { $errors.Add('false_success_invalid_schema') }

$nonproducedWithOutput = Copy-R8H5FixtureObject $normalRequest
$nonproducedWithOutput.reported_result_status = 'waiting_valid'
if ((New-R8H5ArmResult $evaluationRoot $nonproducedWithOutput).result_status -eq 'invalid_output') { $negativePass++ } else { $errors.Add('false_success_nonproduced_with_output') }

try {
  $bad = Copy-R8H5FixtureObject $normalRequest
  $bad.manual_assist_count = 0
  [void](New-R8H5ArmResult $evaluationRoot $bad)
  $errors.Add('false_observation_manual_assist_accepted')
} catch { $negativePass++ }

try {
  $bad = Copy-R8H5FixtureObject $normalRequest
  $bad.input_tokens = 0
  [void](New-R8H5ArmResult $evaluationRoot $bad)
  $errors.Add('false_observation_tokens_accepted')
} catch { $negativePass++ }

try {
  $bad = Copy-R8H5FixtureObject $normalRequest
  $bad.business_output_relative_path = '../escape.json'
  [void](New-R8H5ArmResult $evaluationRoot $bad)
  $errors.Add('output_path_escape_accepted')
} catch { $negativePass++ }

try {
  $bad = Copy-R8H5FixtureObject $normalRequest
  $bad.result_recorded_at = '2026-07-18T11:00:00'
  [void](New-R8H5ArmResult $evaluationRoot $bad)
  $errors.Add('timestamp_without_timezone_accepted')
} catch { $negativePass++ }

$mainCaseRoot = Resolve-R8H5EvaluationPath $evaluationRoot 'cases/CASE-HOTSPOT-NORMAL-001'
$baselineResult = Read-R8H5EvaluationJson (Join-Path $mainCaseRoot 'baseline/arm-result.json')
$candidateResult = Read-R8H5EvaluationJson (Join-Path $mainCaseRoot 'candidate/arm-result.json')
$tampered = Copy-R8H5FixtureObject $baselineResult
$tampered.input_digest = 'sha256:' + ('0' * 64)
$tamperedVerdict = New-R8H5MachineVerdict $evaluationRoot $normalSemantic $tampered $candidateResult $h5r3.evaluated_at
if ($tamperedVerdict.verdict_status -eq 'fail' -and 'arm_input_digest_mismatch' -in @($tamperedVerdict.baseline_failed_check_ids)) { $negativePass++ } else { $errors.Add('input_digest_tamper_not_blocked') }

$wrongType = Copy-R8H5FixtureObject $baselineResult
$wrongType.business_artifact_ref.artifact_type = 'platform_package'
$wrongTypeVerdict = New-R8H5MachineVerdict $evaluationRoot $normalSemantic $wrongType $candidateResult $h5r3.evaluated_at
$wrongTypeComparison = New-R8H5ComparabilityVerdict $normalSemantic $wrongType $candidateResult $wrongTypeVerdict 1 $h5r3.evaluated_at
if ($wrongTypeVerdict.verdict_status -eq 'fail' -and $wrongTypeComparison.comparability_status -eq 'invalid' -and -not $wrongTypeComparison.blind_pair_allowed) { $negativePass++ } else { $errors.Add('machine_fail_false_comparable') }

$tamperedArtifactPath = Resolve-R8H5EvaluationPath $evaluationRoot 'negative/tampered-artifact.json'
$originalPayload = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $evaluationRoot $baselineResult.business_artifact_ref.relative_path)
$tamperedPayload = Copy-R8H5FixtureObject $originalPayload
$tamperedPayload.research_run_record = [pscustomobject]@{run_id='TAMPERED'}
[void](Write-R8H5ImmutableJson $tamperedArtifactPath $tamperedPayload)
$tamperedArtifactResult = Copy-R8H5FixtureObject $baselineResult
$tamperedArtifactResult.business_artifact_ref.relative_path = 'negative/tampered-artifact.json'
$tamperedArtifactVerdict = New-R8H5MachineVerdict $evaluationRoot $normalSemantic $tamperedArtifactResult $candidateResult $h5r3.evaluated_at
if ($tamperedArtifactVerdict.verdict_status -eq 'fail' -and 'business_artifact_digest_mismatch' -in @($tamperedArtifactVerdict.baseline_failed_check_ids)) { $negativePass++ } else { $errors.Add('artifact_hash_tamper_not_blocked') }

$rejectionSemantic = $semanticById['CASE-HOTSPOT-REJECTION-001']
$rejectionProduced = Copy-R8H5FixtureObject $baselineResult
$rejectionProduced.semantic_case_id = $rejectionSemantic.semantic_case_id
$rejectionProduced.evaluation_id = $rejectionSemantic.evaluation_id
$rejectionProduced.attempt_id = $rejectionSemantic.attempt_id
$rejectionProduced.arm_input_ref = "cases/$($rejectionSemantic.semantic_case_id)/baseline/arm-input.json"
$rejectionProduced.dependency_snapshot_ref = "cases/$($rejectionSemantic.semantic_case_id)/baseline/dependency-snapshot.json"
$rejectionProduced.selected_node_id = 'hotspot_research'
$rejectionProduced.executed_node_id = 'hotspot_research'
$rejectionProduced.business_artifact_ref.relative_path = 'cases/CASE-HOTSPOT-NORMAL-001/baseline/business-output.json'
$rejectionProduced.input_digest = (Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $evaluationRoot $rejectionProduced.arm_input_ref)).input_digest
$rejectionProduced.snapshot_digest = (Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $evaluationRoot $rejectionProduced.dependency_snapshot_ref)).closure_digest
$rejectionCandidate = Copy-R8H5FixtureObject $rejectionProduced
$rejectionCandidate.arm_role = 'candidate'
$rejectionCandidate.arm_input_ref = "cases/$($rejectionSemantic.semantic_case_id)/candidate/arm-input.json"
$rejectionCandidate.dependency_snapshot_ref = "cases/$($rejectionSemantic.semantic_case_id)/candidate/dependency-snapshot.json"
$rejectionCandidate.input_digest = (Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $evaluationRoot $rejectionCandidate.arm_input_ref)).input_digest
$rejectionCandidate.snapshot_digest = (Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $evaluationRoot $rejectionCandidate.dependency_snapshot_ref)).closure_digest
$rejectionVerdict = New-R8H5MachineVerdict $evaluationRoot $rejectionSemantic $rejectionProduced $rejectionCandidate $h5r3.evaluated_at
$rejectionComparison = New-R8H5ComparabilityVerdict $rejectionSemantic $rejectionProduced $rejectionCandidate $rejectionVerdict 0 $h5r3.evaluated_at
if ($rejectionVerdict.verdict_status -eq 'fail' -and $rejectionComparison.comparability_status -eq 'invalid' -and -not $rejectionComparison.blind_pair_allowed) { $negativePass++ } else { $errors.Add('rejection_artifact_false_success') }

$waitingBaseline = Copy-R8H5FixtureObject (Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $evaluationRoot 'cases/CASE-HOTSPOT-CONDITIONAL-001/baseline/arm-result.json'))
$waitingCandidate = Copy-R8H5FixtureObject (Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $evaluationRoot 'cases/CASE-HOTSPOT-CONDITIONAL-001/candidate/arm-result.json'))
$syntheticNormal = Copy-R8H5FixtureObject $semanticById['CASE-HOTSPOT-CONDITIONAL-001']
$syntheticNormal.case_class = 'normal'
$syntheticMachine = [pscustomobject]@{ verdict_status = 'pass' }
$insufficient = New-R8H5ComparabilityVerdict $syntheticNormal $waitingBaseline $waitingCandidate $syntheticMachine 0 $h5r3.evaluated_at
if ($insufficient.comparability_status -eq 'insufficient_comparable_samples' -and -not $insufficient.blind_pair_allowed) { $negativePass++ } else { $errors.Add('insufficient_sample_state_missing') }

try {
  $conflictPath = Resolve-R8H5EvaluationPath $evaluationRoot 'negative/immutable.json'
  [void](Write-R8H5ImmutableJson $conflictPath ([pscustomobject]@{value='A'}))
  [void](Write-R8H5ImmutableJson $conflictPath ([pscustomobject]@{value='B'}))
  $errors.Add('immutable_conflict_accepted')
} catch { $negativePass++ }

$expectedComparable = @($h5r3.scenarios | Where-Object { $_.expected_comparability_status -eq 'comparable' }).Count
$actualComparable = 0
foreach ($scenario in @($h5r3.scenarios)) {
  $comparison = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $evaluationRoot "cases/$($scenario.semantic_case_id)/comparability-verdict.json")
  if ($comparison.comparability_status -eq 'comparable') { $actualComparable++ }
}
$result = if ($errors.Count -eq 0 -and $armResultCount -eq 18 -and $machineCount -eq 9 -and
  $comparabilityCount -eq 9 -and $actualComparable -eq $expectedComparable -and $negativePass -eq 13) { 'pass' } else { 'fail' }
$report = [pscustomobject][ordered]@{
  schema_id = 'taoge://reports/r8/h5r3-evaluation-runtime/v0.1'
  generated_at = [DateTimeOffset]::Now.ToString('o')
  result = $result
  build_profile = 'dev'
  evaluation_id = $evaluationId
  attempt_id = $attemptId
  arm_result_count = $armResultCount
  machine_verdict_count = $machineCount
  comparability_verdict_count = $comparabilityCount
  comparable_count = $actualComparable
  false_success_negative_pass_count = $negativePass
  arm_execution_started = $false
  blind_pair_generated = $false
  human_review_started = $false
  network_called = $false
  provider_called = $false
  private_account_used = $false
  public_profile_validation = 'not_run_in_current_dev_profile'
  errors = @($errors)
}
Write-TaogeUtf8NoBomJson -Path $ReportPath -Value $report -Depth 30
Write-Output "result=$result"
Write-Output "arm_result_count=$armResultCount"
Write-Output "machine_verdict_count=$machineCount"
Write-Output "comparability_verdict_count=$comparabilityCount"
Write-Output "comparable_count=$actualComparable"
Write-Output "false_success_negative_pass_count=$negativePass"
Write-Output "report=$ReportPath"
if ($result -ne 'pass') {
  foreach ($item in $errors) { Write-Output "error=$item" }
  exit 1
}
exit 0
