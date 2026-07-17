param(
  [string]$ProjectRoot = '',
  [Parameter(Mandatory=$true)][string]$EvaluationRoot,
  [Parameter(Mandatory=$true)][string]$EvaluatedAt,
  [Parameter(Mandatory=$true)][int]$BaselineManualAssistCount,
  [Parameter(Mandatory=$true)][int]$CandidateManualAssistCount
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}
$EvaluationRoot = (Resolve-Path -LiteralPath $EvaluationRoot).Path
. (Join-Path $PSScriptRoot 'R8H5BlindRuntime.ps1')
Initialize-R8H5BlindRuntime $ProjectRoot

$compileResult = Read-R8H5EvaluationJson (Join-Path $EvaluationRoot 'input-compile-result.json')
$requests = @()
foreach ($caseItem in @($compileResult.cases)) {
  $caseId = [string]$caseItem.semantic_case_id
  foreach ($role in @('baseline','candidate')) {
    $task = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $EvaluationRoot "cases/$caseId/$role/arm-task.json")
    $submission = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $EvaluationRoot "cases/$caseId/$role/arm-execution-submission.json")
    $assist = if ($role -eq 'baseline') { $BaselineManualAssistCount } else { $CandidateManualAssistCount }
    $requests += ConvertTo-R8H5RecordRequest $EvaluationRoot $task $submission $assist
  }
}
$catalog = [pscustomobject][ordered]@{ record_requests=@($requests) }
$catalogPath = Join-Path $EvaluationRoot 'arm-result-record-requests.json'
[void](Write-R8H5ImmutableJson $catalogPath $catalog)

& (Join-Path $PSScriptRoot 'invoke-r8-h5r3-evaluation.ps1') -ProjectRoot $ProjectRoot `
  -EvaluationRoot $EvaluationRoot -RecordRequestPath $catalogPath -EvaluatedAt $EvaluatedAt
if (-not $?) { throw 'h5r3_evaluation_failed' }

$packet = New-R8H5BlindReviewPacket $EvaluationRoot $EvaluatedAt
$summary = [pscustomobject][ordered]@{
  schema_id = 'taoge://reports/r8/h5r4-arm-execution/v0.1'
  evaluation_id = $compileResult.evaluation_id
  attempt_id = $compileResult.attempt_id
  result = 'arms_evaluated_packet_generated'
  independent_arm_count = 2
  arm_submission_count = $requests.Count
  baseline_manual_assist_count = $BaselineManualAssistCount
  candidate_manual_assist_count = $CandidateManualAssistCount
  blind_pair_count = $packet.blind_pair_count
  packet_status = $packet.packet_status
  human_review_started = $false
  finalizer_started = $false
  evaluated_at = $EvaluatedAt
}
[void](Write-R8H5ImmutableJson (Join-Path $EvaluationRoot 'h5r4-execution-summary.json') $summary)
Write-Output 'result=arms_evaluated_packet_generated'
Write-Output "arm_submission_count=$($summary.arm_submission_count)"
Write-Output "blind_pair_count=$($summary.blind_pair_count)"
Write-Output "packet_status=$($summary.packet_status)"
