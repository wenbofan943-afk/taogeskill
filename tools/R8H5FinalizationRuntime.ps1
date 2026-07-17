. (Join-Path $PSScriptRoot 'R8H5BlindRuntime.ps1')

function Initialize-R8H5FinalizationRuntime {
  param([string]$ProjectRoot)
  Initialize-R8H5BlindRuntime $ProjectRoot
}

function Assert-R8H5HumanVerdictDigest {
  param([object]$Verdict)
  $body = [pscustomobject][ordered]@{
    schema_id = $Verdict.schema_id
    schema_version = $Verdict.schema_version
    human_verdict_id = $Verdict.human_verdict_id
    evaluation_id = $Verdict.evaluation_id
    attempt_id = $Verdict.attempt_id
    semantic_case_id = $Verdict.semantic_case_id
    blind_pair_ref = $Verdict.blind_pair_ref
    reviewer_role = $Verdict.reviewer_role
    choice = $Verdict.choice
    business_reason = $Verdict.business_reason
    verdict_status = $Verdict.verdict_status
    submitted_at = $Verdict.submitted_at
    supersedes = $Verdict.supersedes
  }
  if ((Get-R8H5ObjectDigest $body) -ne [string]$Verdict.verdict_digest) {
    throw 'human_verdict_digest_mismatch'
  }
}

function New-R8H5HumanVerdict {
  param([string]$EvaluationRoot,[object]$Request)
  Assert-R8H5Schema 'templates/schema/r8/h5/requests/h5-human-verdict-record-request.v0.1.schema.json' $Request 'human_verdict_request_invalid'
  Assert-R8H5Timestamp 'submitted_at' ([string]$Request.submitted_at)
  $pairPath = Resolve-R8H5EvaluationPath $EvaluationRoot ([string]$Request.blind_pair_ref)
  $pair = Read-R8H5EvaluationJson $pairPath
  Assert-R8H5Schema 'templates/schema/r8/h5/h5-blind-pair.v0.2.schema.json' $pair 'blind_pair_invalid'
  if ($pair.pair_status -ne 'ready' -or
      $pair.evaluation_id -ne $Request.evaluation_id -or
      $pair.attempt_id -ne $Request.attempt_id -or
      $pair.semantic_case_id -ne $Request.semantic_case_id) {
    throw 'human_verdict_blind_pair_binding_invalid'
  }
  foreach ($side in @('a','b')) {
    $presentation = [string]$pair.$side.presentation
    if ((Get-R8H5TextDigest $presentation) -ne [string]$pair.$side.content_digest) {
      throw "human_verdict_blind_presentation_digest_mismatch:$side"
    }
  }
  $body = [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r8/h5/h5-human-verdict/v0.2'
    schema_version = '0.2'
    human_verdict_id = "HUMAN-VERDICT-$($Request.semantic_case_id)"
    evaluation_id = $Request.evaluation_id
    attempt_id = $Request.attempt_id
    semantic_case_id = $Request.semantic_case_id
    blind_pair_ref = $Request.blind_pair_ref
    reviewer_role = 'human_owner'
    choice = $Request.choice
    business_reason = $Request.business_reason
    verdict_status = 'committed'
    submitted_at = $Request.submitted_at
    supersedes = $Request.supersedes
  }
  $verdict = [pscustomobject][ordered]@{}
  foreach ($property in $body.PSObject.Properties) {
    $verdict | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
  }
  $verdict | Add-Member -NotePropertyName verdict_digest -NotePropertyValue (Get-R8H5ObjectDigest $body)
  Assert-R8H5Schema 'templates/schema/r8/h5/h5-human-verdict.v0.2.schema.json' $verdict 'human_verdict_invalid'
  Assert-R8H5HumanVerdictDigest $verdict
  $target = Resolve-R8H5EvaluationPath $EvaluationRoot "cases/$($Request.semantic_case_id)/human-verdict.json"
  [void](Write-R8H5ImmutableJson $target $verdict)
  return $verdict
}

function Resolve-R8H5HumanChoice {
  param([string]$EvaluationRoot,[object]$Pair,[object]$Verdict)
  if ($Verdict.choice -eq 'tie') { return 'tie' }
  $allocation = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $EvaluationRoot ([string]$Pair.allocation_record_ref))
  Assert-R8H5Schema 'templates/schema/r8/h5/h5-blind-allocation-record.v0.1.schema.json' $allocation 'allocation_record_invalid'
  $commitmentBody = [pscustomobject][ordered]@{
    evaluation_id = $allocation.evaluation_id
    attempt_id = $allocation.attempt_id
    semantic_case_id = $allocation.semantic_case_id
    a_arm_role = $allocation.a_arm_role
    b_arm_role = $allocation.b_arm_role
    nonce = $allocation.nonce
  }
  if ($allocation.blind_pair_ref -ne $Verdict.blind_pair_ref -or
      $allocation.evaluation_id -ne $Verdict.evaluation_id -or
      $allocation.attempt_id -ne $Verdict.attempt_id -or
      $allocation.semantic_case_id -ne $Verdict.semantic_case_id -or
      $allocation.a_arm_role -eq $allocation.b_arm_role -or
      (Get-R8H5ObjectDigest $commitmentBody) -ne $Pair.allocation_commitment_digest -or
      $allocation.allocation_commitment_digest -ne $Pair.allocation_commitment_digest) {
    throw 'finalizer_allocation_binding_invalid'
  }
  if ($Verdict.choice -eq 'A') { return [string]$allocation.a_arm_role }
  return [string]$allocation.b_arm_role
}

function Get-R8H5ReadinessStatus {
  param(
    [bool]$HumanComplete,[bool]$AllMachine,[bool]$AllRejections,
    [bool]$HasBaselinePreference,[System.Collections.IDictionary]$ComparableCounts
  )
  if (-not $HumanComplete) { return 'waiting_human' }
  $insufficient = @($ComparableCounts.Keys | Where-Object { $ComparableCounts[$_] -lt 1 }).Count -gt 0
  if ($insufficient) { return 'insufficient_samples' }
  if (-not $AllMachine -or -not $AllRejections -or $HasBaselinePreference) { return 'failed' }
  return 'passed'
}

function New-R8H5EvaluationFinalization {
  param([string]$EvaluationRoot,[string]$FinalizedAt)
  Assert-R8H5Timestamp 'finalized_at' $FinalizedAt
  $compileResult = Read-R8H5EvaluationJson (Join-Path $EvaluationRoot 'input-compile-result.json')
  $caseSummaries = @()
  $counts = [ordered]@{
    'hotspot-topic-research' = 0
    'propagation-router' = 0
    'platform-packaging-adapter' = 0
  }
  $blockers = [System.Collections.Generic.List[string]]::new()
  $allMachine = $true
  $allRejections = $true
  $humanComplete = $true

  foreach ($caseItem in @($compileResult.cases)) {
    $caseId = [string]$caseItem.semantic_case_id
    $caseRoot = Resolve-R8H5EvaluationPath $EvaluationRoot "cases/$caseId"
    $semantic = Read-R8H5EvaluationJson (Join-Path $caseRoot 'semantic-case.json')
    $machine = Read-R8H5EvaluationJson (Join-Path $caseRoot 'machine-verdict.json')
    $comparison = Read-R8H5EvaluationJson (Join-Path $caseRoot 'comparability-verdict.json')
    Assert-R8H5Schema 'templates/schema/r8/h5/h5-semantic-case.v0.2.schema.json' $semantic 'semantic_case_invalid'
    Assert-R8H5Schema 'templates/schema/r8/h5/h5-machine-verdict.v0.2.schema.json' $machine 'machine_verdict_invalid'
    Assert-R8H5Schema 'templates/schema/r8/h5/h5-comparability-verdict.v0.2.schema.json' $comparison 'comparability_invalid'
    if ($machine.evaluation_id -ne $compileResult.evaluation_id -or
        $machine.attempt_id -ne $compileResult.attempt_id -or
        $comparison.evaluation_id -ne $compileResult.evaluation_id -or
        $comparison.attempt_id -ne $compileResult.attempt_id -or
        $machine.semantic_case_id -ne $caseId -or
        $comparison.semantic_case_id -ne $caseId) {
      throw "finalizer_case_binding_invalid:$caseId"
    }
    if ($machine.verdict_status -ne 'pass') {
      $allMachine = $false
      $blockers.Add("machine_gate_failed:$caseId")
    }
    if ($semantic.case_class -eq 'rejection') {
      $closed = $machine.verdict_status -eq 'pass' -and
        $comparison.comparability_status -eq 'behavior_only' -and
        $comparison.blind_pair_allowed -eq $false
      if (-not $closed) {
        $allRejections = $false
        $blockers.Add("rejection_not_fail_closed:$caseId")
      }
    }

    $humanRef = $null
    $caseResult = if ($machine.verdict_status -eq 'pass') { 'machine_only_pass' } else { 'failed' }
    if ($comparison.comparability_status -eq 'comparable' -and $comparison.blind_pair_allowed -eq $true) {
      $counts[[string]$semantic.skill_id]++
      $pairRef = "cases/$caseId/blind-pair.json"
      $pair = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $EvaluationRoot $pairRef)
      Assert-R8H5Schema 'templates/schema/r8/h5/h5-blind-pair.v0.2.schema.json' $pair 'blind_pair_invalid'
      $humanRef = "cases/$caseId/human-verdict.json"
      $humanPath = Resolve-R8H5EvaluationPath $EvaluationRoot $humanRef
      if (Test-Path -LiteralPath $humanPath -PathType Leaf) {
        $human = Read-R8H5EvaluationJson $humanPath
        Assert-R8H5Schema 'templates/schema/r8/h5/h5-human-verdict.v0.2.schema.json' $human 'human_verdict_invalid'
        Assert-R8H5HumanVerdictDigest $human
        if ($human.verdict_status -ne 'committed' -or $human.blind_pair_ref -ne $pairRef -or
            $human.evaluation_id -ne $compileResult.evaluation_id -or
            $human.attempt_id -ne $compileResult.attempt_id -or
            $human.semantic_case_id -ne $caseId) {
          throw "finalizer_human_verdict_binding_invalid:$caseId"
        }
        $caseResult = Resolve-R8H5HumanChoice $EvaluationRoot $pair $human
        if ($caseResult -eq 'baseline') { $blockers.Add("baseline_preferred:$caseId") }
      } else {
        $humanComplete = $false
        $humanRef = $null
        $blockers.Add("human_verdict_missing:$caseId")
      }
    }
    $caseSummaries += [pscustomobject][ordered]@{
      semantic_case_id = $caseId
      machine_verdict_ref = "cases/$caseId/machine-verdict.json"
      comparability_verdict_ref = "cases/$caseId/comparability-verdict.json"
      human_verdict_ref = $humanRef
      case_result = $caseResult
    }
  }

  foreach ($skillId in @('hotspot-topic-research','propagation-router','platform-packaging-adapter')) {
    if ($counts[$skillId] -lt 1) { $blockers.Add("insufficient_comparable_samples:$skillId") }
  }
  $hasBaselinePreference = @($caseSummaries | Where-Object { $_.case_result -eq 'baseline' }).Count -gt 0
  $readiness = Get-R8H5ReadinessStatus $humanComplete $allMachine $allRejections $hasBaselinePreference $counts
  $finalization = [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r8/h5/h5-evaluation-finalization/v0.3'
    schema_version = '0.3'
    evaluation_finalization_id = "FINALIZATION-$($compileResult.evaluation_id)-$($compileResult.attempt_id)"
    evaluation_id = $compileResult.evaluation_id
    attempt_id = $compileResult.attempt_id
    case_summaries = @($caseSummaries)
    per_skill_comparable_counts = [pscustomobject]$counts
    all_machine_gates_pass = $allMachine
    all_rejection_cases_fail_closed = $allRejections
    human_verdicts_complete = $humanComplete
    readiness_blockers = @($blockers | Select-Object -Unique)
    current_switch_readiness = $readiness
    overall_result = if ($readiness -eq 'passed') { 'pass' } else { 'fail' }
    finalized_at = $FinalizedAt
    supersedes = $null
  }
  Assert-R8H5Schema 'templates/schema/r8/h5/h5-evaluation-finalization.v0.3.schema.json' $finalization 'evaluation_finalization_invalid'
  return $finalization
}

function New-R8H5StateProjection {
  param([object]$Finalization,[string]$ProjectedAt)
  Assert-R8H5Timestamp 'projected_at' $ProjectedAt
  Assert-R8H5Schema 'templates/schema/r8/h5/h5-evaluation-finalization.v0.3.schema.json' $Finalization 'evaluation_finalization_invalid'
  $projection = [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r8/h5/h5-evaluation-state-projection/v0.1'
    schema_version = '0.1'
    evaluation_id = $Finalization.evaluation_id
    attempt_id = $Finalization.attempt_id
    finalization_ref = 'evaluation-finalization.json'
    finalization_digest = Get-R8H5ObjectDigest $Finalization
    current_switch_readiness = $Finalization.current_switch_readiness
    overall_result = $Finalization.overall_result
    readiness_blockers = @($Finalization.readiness_blockers)
    projection_status = 'projected_from_finalization_only'
    projected_at = $ProjectedAt
  }
  Assert-R8H5Schema 'templates/schema/r8/h5/h5-evaluation-state-projection.v0.1.schema.json' $projection 'state_projection_invalid'
  return $projection
}
