param(
  [string]$ProjectRoot = '',
  [string]$WorkRoot = '',
  [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}
if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
  $WorkRoot = Join-Path $ProjectRoot 'state/checks'
} else {
  $WorkRoot = [System.IO.Path]::GetFullPath($WorkRoot)
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = Join-Path $WorkRoot 'r8-h5r5-finalization-runtime-report.json'
}
. (Join-Path $PSScriptRoot 'R8H5FinalizationRuntime.ps1')
Initialize-R8H5FinalizationRuntime $ProjectRoot

$errors = [System.Collections.Generic.List[string]]::new()
$negativePass = 0
$h5r3ReportPath = Join-Path $WorkRoot 'r8-h5r3-evaluation-runtime-report.json'
$h5r4ReportPath = Join-Path $WorkRoot 'r8-h5r4-blind-runtime-report.json'
& (Join-Path $PSScriptRoot 'validate-r8-h5r4-blind-runtime.ps1') `
  -ProjectRoot $ProjectRoot `
  -WorkRoot $WorkRoot `
  -ReportPath $h5r4ReportPath
if (-not $?) { throw 'h5r4_fixture_precondition_failed' }
$h5r3 = Read-R8H5EvaluationJson $h5r3ReportPath
$root = Join-Path $WorkRoot "r8/$($h5r3.evaluation_id)/$($h5r3.attempt_id)"
$packet = Read-R8H5EvaluationJson (Join-Path $root 'blind-review-packet.json')

# H5R5 owns these dynamic fixture outputs and rebuilds them from immutable H5R4 evidence.
foreach ($pairRef in @($packet.blind_pair_refs)) {
  $pair = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $root $pairRef)
  $verdictPath = Resolve-R8H5EvaluationPath $root "cases/$($pair.semantic_case_id)/human-verdict.json"
  if (Test-Path -LiteralPath $verdictPath -PathType Leaf) { Remove-Item -LiteralPath $verdictPath -Force }
}
foreach ($name in @('evaluation-finalization.json','h5-state-projection.json')) {
  $path = Join-Path $root $name
  if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force }
}

$pre = New-R8H5EvaluationFinalization $root '2026-07-18T12:00:00+08:00'
if ($pre.current_switch_readiness -ne 'waiting_human' -or $pre.human_verdicts_complete -ne $false) {
  $errors.Add('missing_human_verdict_did_not_wait')
}

$requests = @()
foreach ($pairRef in @($packet.blind_pair_refs)) {
  $pair = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $root $pairRef)
  $request = [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r8/h5/requests/h5-human-verdict-record-request/v0.1'
    schema_version = '0.1'
    evaluation_id = $pair.evaluation_id
    attempt_id = $pair.attempt_id
    semantic_case_id = $pair.semantic_case_id
    blind_pair_ref = $pairRef
    reviewer_role = 'human_owner'
    choice = 'tie'
    business_reason = 'Fixture tie keeps the finalizer focused on machine and sample blockers.'
    submitted_at = '2026-07-18T12:01:00+08:00'
    supersedes = $null
  }
  $requests += $request
  $first = New-R8H5HumanVerdict $root $request
  $replay = New-R8H5HumanVerdict $root $request
  if ((ConvertTo-R8H5CanonicalJson $first) -ne (ConvertTo-R8H5CanonicalJson $replay)) {
    $errors.Add("human_verdict_replay_not_stable:$($pair.semantic_case_id)")
  }
}

$post = New-R8H5EvaluationFinalization $root '2026-07-18T12:02:00+08:00'
if ($post.current_switch_readiness -ne 'passed' -or $post.human_verdicts_complete -ne $true) {
  $errors.Add('all_skill_fixture_did_not_finalize_pass')
}
$routerZeroCounts = [ordered]@{
  'hotspot-topic-research' = 1
  'propagation-router' = 0
  'platform-packaging-adapter' = 2
}
$routerZeroReadiness = Get-R8H5ReadinessStatus $true $true $true $false $routerZeroCounts
if ($routerZeroReadiness -ne 'insufficient_samples') {
  $errors.Add('router_zero_sample_policy_not_insufficient')
}
$mappingPair = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $root $packet.blind_pair_refs[0])
$mappingAllocation = Read-R8H5EvaluationJson (
  Resolve-R8H5EvaluationPath $root ([string]$mappingPair.allocation_record_ref)
)
$mappingVerdictA = $requests[0] | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
$mappingVerdictA.choice = 'A'
$mappingVerdictB = $requests[0] | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
$mappingVerdictB.choice = 'B'
$allocationMappingKnownAnswer = (
  (Resolve-R8H5HumanChoice $root $mappingPair $mappingVerdictA) -eq $mappingAllocation.a_arm_role -and
  (Resolve-R8H5HumanChoice $root $mappingPair $mappingVerdictB) -eq $mappingAllocation.b_arm_role
)
if (-not $allocationMappingKnownAnswer) {
  $errors.Add('allocation_mapping_known_answer_failed')
}
[void](Write-R8H5ImmutableJson (Join-Path $root 'evaluation-finalization.json') $post)
$projection = New-R8H5StateProjection $post '2026-07-18T12:02:00+08:00'
[void](Write-R8H5ImmutableJson (Join-Path $root 'h5-state-projection.json') $projection)
if ($projection.current_switch_readiness -ne $post.current_switch_readiness -or
    $projection.overall_result -ne $post.overall_result -or
    $projection.finalization_digest -ne (Get-R8H5ObjectDigest $post) -or
    $projection.projection_status -ne 'projected_from_finalization_only') {
  $errors.Add('state_projection_recomputed_or_mismatched')
}

try {
  $bad = $requests[0] | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
  $bad.semantic_case_id = 'CASE-WRONG-BINDING'
  [void](New-R8H5HumanVerdict $root $bad)
  $errors.Add('mismatched_human_verdict_binding_accepted')
} catch { $negativePass++ }

try {
  $changed = $requests[0] | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
  $changed.choice = 'A'
  $changed.business_reason = 'Conflicting second verdict.'
  [void](New-R8H5HumanVerdict $root $changed)
  $errors.Add('conflicting_human_verdict_overwrite_accepted')
} catch { $negativePass++ }

try {
  $pair = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $root $packet.blind_pair_refs[0])
  $badPair = $pair | ConvertTo-Json -Depth 40 -Compress | ConvertFrom-Json
  $badPair.blind_pair_id = 'BLIND-PAIR-TAMPERED'
  $badPair.a.content_digest = 'sha256:' + ('0' * 64)
  $badRef = "cases/$($pair.semantic_case_id)/blind-pair-tampered.json"
  [void](Write-R8H5ImmutableJson (Resolve-R8H5EvaluationPath $root $badRef) $badPair)
  $badRequest = $requests[0] | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
  $badRequest.blind_pair_ref = $badRef
  [void](New-R8H5HumanVerdict $root $badRequest)
  $errors.Add('tampered_blind_presentation_accepted')
} catch { $negativePass++ }

$result = if ($errors.Count -eq 0 -and $negativePass -eq 3) { 'pass' } else { 'fail' }
$report = [pscustomobject][ordered]@{
  schema_id = 'taoge://reports/r8/h5r5-finalization-runtime/v0.1'
  generated_at = [DateTimeOffset]::Now.ToString('o')
  result = $result
  build_profile = 'dev'
  human_verdict_count = $requests.Count
  false_success_negative_pass_count = $negativePass
  pre_human_readiness = $pre.current_switch_readiness
  finalized_readiness = $post.current_switch_readiness
  router_comparable_count = $post.per_skill_comparable_counts.'propagation-router'
  router_zero_sample_policy_readiness = $routerZeroReadiness
  finalizer_only_readiness_producer = $true
  allocation_mapping_known_answer_passed = $allocationMappingKnownAnswer
  state_projection_derived_only = (
    $projection.projection_status -eq 'projected_from_finalization_only' -and
    $projection.finalization_digest -eq (Get-R8H5ObjectDigest $post)
  )
  network_called = $false
  provider_called = $false
  private_account_used = $false
  public_profile_validation = 'not_run_in_current_dev_profile'
  errors = @($errors)
}
Write-TaogeUtf8NoBomJson -Path $ReportPath -Value $report -Depth 20
Write-Output "result=$result"
Write-Output "human_verdict_count=$($report.human_verdict_count)"
Write-Output "false_success_negative_pass_count=$negativePass"
Write-Output "finalized_readiness=$($report.finalized_readiness)"
Write-Output "router_comparable_count=$($report.router_comparable_count)"
Write-Output "report=$ReportPath"
if ($result -ne 'pass') {
  foreach ($item in $errors) { Write-Output "error=$item" }
  exit 1
}
