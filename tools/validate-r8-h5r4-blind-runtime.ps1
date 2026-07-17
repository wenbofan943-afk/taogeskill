param(
  [string]$ProjectRoot = '',
  [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = Join-Path $ProjectRoot 'state/checks/r8-h5r4-blind-runtime-report.json'
}
. (Join-Path $PSScriptRoot 'R8H5BlindRuntime.ps1')
Initialize-R8H5BlindRuntime $ProjectRoot

$errors = [System.Collections.Generic.List[string]]::new()
$negativePass = 0
$h5r3ReportPath = Join-Path $ProjectRoot 'state/checks/r8-h5r3-evaluation-runtime-report.json'
& (Join-Path $PSScriptRoot 'validate-r8-h5r3-evaluation-runtime.ps1') -ProjectRoot $ProjectRoot -ReportPath $h5r3ReportPath
if (-not $?) { throw 'h5r3_fixture_precondition_failed' }
$h5r3 = Read-R8H5EvaluationJson $h5r3ReportPath
$root = Join-Path $ProjectRoot "state/checks/r8/$($h5r3.evaluation_id)/$($h5r3.attempt_id)"
$fixture = Read-R8H5EvaluationJson (Join-Path $ProjectRoot 'examples/r8-h5r2-input-fixtures/cases.json')

if (-not (Test-Path -LiteralPath (Join-Path $root 'input-compile-result.json'))) {
  $caseRows = @()
  foreach ($case in @($fixture.cases)) {
    $semantic = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $root "cases/$($case.semantic_case_id)/semantic-case.json")
    $caseRows += [pscustomobject][ordered]@{
      semantic_case_id = $semantic.semantic_case_id
      semantic_case_digest = $semantic.semantic_case_digest
      semantic_projection_digest = Get-R8H5ObjectDigest $semantic.semantic_input
      arm_inputs = @()
    }
  }
  $compileResult = [pscustomobject][ordered]@{
    schema_id = 'taoge://reports/r8/h5r2-input-compile/v0.1'
    evaluation_id = $h5r3.evaluation_id
    attempt_id = $h5r3.attempt_id
    compiled_at = '2026-07-18T11:00:00+08:00'
    result = 'pass'
    case_count = $caseRows.Count
    arm_input_count = $caseRows.Count * 2
    arm_execution_started = $false
    cases = @($caseRows)
  }
  [void](Write-R8H5ImmutableJson (Join-Path $root 'input-compile-result.json') $compileResult)
}

# Blind projections are outputs of the runtime under test. Rebuild only these
# fixture-owned dynamic files so a runtime revision cannot reuse a stale packet.
foreach ($case in @($fixture.cases)) {
  $fixturePairPath = Resolve-R8H5EvaluationPath $root "cases/$($case.semantic_case_id)/blind-pair.json"
  if (Test-Path -LiteralPath $fixturePairPath -PathType Leaf) {
    Remove-Item -LiteralPath $fixturePairPath -Force
  }
}
foreach ($fixturePacketName in @('blind-review-packet.json','blind-review-packet.md')) {
  $fixturePacketPath = Join-Path $root $fixturePacketName
  if (Test-Path -LiteralPath $fixturePacketPath -PathType Leaf) {
    Remove-Item -LiteralPath $fixturePacketPath -Force
  }
}

$packet = New-R8H5BlindReviewPacket $root '2026-07-18T11:10:00+08:00'
$packetReplay = New-R8H5BlindReviewPacket $root '2026-07-18T11:10:00+08:00'
if ((ConvertTo-R8H5CanonicalJson $packet) -ne (ConvertTo-R8H5CanonicalJson $packetReplay)) {
  $errors.Add('blind_packet_replay_not_byte_stable')
}
if ($packet.blind_pair_count -ne 4 -or $packet.packet_status -ne 'ready_for_human_review') {
  $errors.Add("blind_pair_count_or_status_invalid:$($packet.blind_pair_count):$($packet.packet_status)")
}

foreach ($case in @($fixture.cases)) {
  $caseRoot = Resolve-R8H5EvaluationPath $root "cases/$($case.semantic_case_id)"
  $comparison = Read-R8H5EvaluationJson (Join-Path $caseRoot 'comparability-verdict.json')
  $pairPath = Join-Path $caseRoot 'blind-pair.json'
  if ($comparison.comparability_status -eq 'comparable') {
    if (-not (Test-Path -LiteralPath $pairPath -PathType Leaf)) { $errors.Add("eligible_pair_missing:$($case.semantic_case_id)") }
  } elseif (Test-Path -LiteralPath $pairPath -PathType Leaf) {
    $errors.Add("ineligible_pair_exists:$($case.semantic_case_id)")
  }
}

$markdown = [System.IO.File]::ReadAllText((Join-Path $root 'blind-review-packet.md'),(Get-TaogeUtf8NoBomEncoding))
if ($markdown -match '(?i)a_arm_role|b_arm_role|source_commit|dependency_snapshot|\bbaseline\b|\bcandidate\b') {
  $errors.Add('blind_markdown_identity_leak')
}
if ($markdown -match 'allocation-record') { $errors.Add('blind_markdown_mapping_ref_leak') }
if ($markdown -match '"Length"\s*:') {
  $errors.Add('blind_markdown_scalar_serialized_as_length_object')
}
if ($markdown -match '"hashtags"\s*:\s*\{\s*\}' -or
    $markdown -match '"notes"\s*:\s*"') {
  $errors.Add('blind_markdown_array_shape_collapsed')
}

$normalRoot = Resolve-R8H5EvaluationPath $root 'cases/CASE-HOTSPOT-NORMAL-001'
$semantic = Read-R8H5EvaluationJson (Join-Path $normalRoot 'semantic-case.json')
$machine = Read-R8H5EvaluationJson (Join-Path $normalRoot 'machine-verdict.json')
$comparison = Read-R8H5EvaluationJson (Join-Path $normalRoot 'comparability-verdict.json')
$baseline = Read-R8H5EvaluationJson (Join-Path $normalRoot 'baseline/arm-result.json')
$candidate = Read-R8H5EvaluationJson (Join-Path $normalRoot 'candidate/arm-result.json')

try {
  $badMachine = $machine | ConvertTo-Json -Depth 40 -Compress | ConvertFrom-Json
  $badMachine.verdict_status = 'fail'
  [void](New-R8H5BlindPair $root $semantic $badMachine $comparison $baseline $candidate '2026-07-18T11:11:00+08:00')
  $errors.Add('machine_fail_blind_pair_accepted')
} catch { $negativePass++ }

try {
  $badComparison = $comparison | ConvertTo-Json -Depth 40 -Compress | ConvertFrom-Json
  $badComparison.comparability_status = 'behavior_only'
  $badComparison.blind_pair_allowed = $false
  [void](New-R8H5BlindPair $root $semantic $machine $badComparison $baseline $candidate '2026-07-18T11:11:00+08:00')
  $errors.Add('noncomparable_blind_pair_accepted')
} catch { $negativePass++ }

try {
  $badResult = $baseline | ConvertTo-Json -Depth 40 -Compress | ConvertFrom-Json
  $badResult.output_digest = 'sha256:' + ('0' * 64)
  [void](New-R8H5BlindPair $root $semantic $machine $comparison $badResult $candidate '2026-07-18T11:11:00+08:00')
  $errors.Add('tampered_arm_result_blind_pair_accepted')
} catch { $negativePass++ }

$firstPair = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $root $packet.blind_pair_refs[0])
$allocation = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $root $firstPair.allocation_record_ref)
$commitmentBody = [pscustomobject][ordered]@{
  evaluation_id = $allocation.evaluation_id
  attempt_id = $allocation.attempt_id
  semantic_case_id = $allocation.semantic_case_id
  a_arm_role = $allocation.a_arm_role
  b_arm_role = $allocation.b_arm_role
  nonce = $allocation.nonce
}
if ((Get-R8H5ObjectDigest $commitmentBody) -ne $firstPair.allocation_commitment_digest) {
  $errors.Add('allocation_commitment_not_bound')
}

$result = if ($errors.Count -eq 0 -and $packet.blind_pair_count -eq 4 -and $negativePass -eq 3) { 'pass' } else { 'fail' }
$report = [pscustomobject][ordered]@{
  schema_id = 'taoge://reports/r8/h5r4-blind-runtime/v0.1'
  generated_at = [DateTimeOffset]::Now.ToString('o')
  result = $result
  build_profile = 'dev'
  fixture_evaluation_id = $h5r3.evaluation_id
  blind_pair_count = $packet.blind_pair_count
  false_success_negative_pass_count = $negativePass
  allocation_mapping_separate = $true
  packet_identity_leak_count = @($errors | Where-Object { $_ -match 'leak' }).Count
  human_review_started = $false
  finalizer_started = $false
  network_called = $false
  provider_called = $false
  private_account_used = $false
  public_profile_validation = 'not_run_in_current_dev_profile'
  errors = @($errors)
}
Write-TaogeUtf8NoBomJson -Path $ReportPath -Value $report -Depth 20
Write-Output "result=$result"
Write-Output "blind_pair_count=$($report.blind_pair_count)"
Write-Output "false_success_negative_pass_count=$negativePass"
Write-Output "report=$ReportPath"
if ($result -ne 'pass') {
  foreach ($item in $errors) { Write-Output "error=$item" }
  exit 1
}
