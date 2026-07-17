param(
  [string]$ProjectRoot = '',
  [Parameter(Mandatory=$true)][string]$EvaluationRoot,
  [Parameter(Mandatory=$true)][string]$RecordRequestPath,
  [Parameter(Mandatory=$true)][string]$EvaluatedAt
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
} else {
  $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}
$EvaluationRoot = Resolve-Path -LiteralPath $EvaluationRoot | Select-Object -ExpandProperty Path
. (Join-Path $PSScriptRoot 'R8H5EvaluationRuntime.ps1')
Initialize-R8H5EvaluationRuntime $ProjectRoot

$catalog = Read-R8H5EvaluationJson $RecordRequestPath
$records = @()
foreach ($request in @($catalog.record_requests)) {
  $result = New-R8H5ArmResult $EvaluationRoot $request
  $resultPath = Resolve-R8H5EvaluationPath $EvaluationRoot "cases/$($request.semantic_case_id)/$($request.arm_role)/arm-result.json"
  [void](Write-R8H5ImmutableJson $resultPath $result)
  $records += $result
}

$evaluations = @()
foreach ($caseId in @($records.semantic_case_id | Select-Object -Unique)) {
  $caseRoot = Resolve-R8H5EvaluationPath $EvaluationRoot "cases/$caseId"
  $semantic = Read-R8H5EvaluationJson (Join-Path $caseRoot 'semantic-case.json')
  $baseline = @($records | Where-Object { $_.semantic_case_id -eq $caseId -and $_.arm_role -eq 'baseline' })
  $candidate = @($records | Where-Object { $_.semantic_case_id -eq $caseId -and $_.arm_role -eq 'candidate' })
  if ($baseline.Count -ne 1 -or $candidate.Count -ne 1) { throw "arm_result_pair_incomplete:$caseId" }
  $machine = New-R8H5MachineVerdict $EvaluationRoot $semantic $baseline[0] $candidate[0] $EvaluatedAt
  [void](Write-R8H5ImmutableJson (Join-Path $caseRoot 'machine-verdict.json') $machine)
  $evaluations += [pscustomobject][ordered]@{
    semantic_case = $semantic
    baseline = $baseline[0]
    candidate = $candidate[0]
    machine = $machine
  }
}

$comparableCounts = @{}
foreach ($item in $evaluations) {
  $skillId = [string]$item.semantic_case.skill_id
  if (-not $comparableCounts.ContainsKey($skillId)) { $comparableCounts[$skillId] = 0 }
  if ($item.machine.verdict_status -eq 'pass' -and
      $item.baseline.result_status -eq 'produced_business_artifact' -and
      $item.candidate.result_status -eq 'produced_business_artifact' -and
      $item.baseline.business_artifact_ref.artifact_type -eq $item.candidate.business_artifact_ref.artifact_type -and
      $item.baseline.business_artifact_ref.artifact_type -eq $item.semantic_case.expected_primary_output_type) {
    $comparableCounts[$skillId]++
  }
}

$comparability = @()
foreach ($item in $evaluations) {
  $skillId = [string]$item.semantic_case.skill_id
  $verdict = New-R8H5ComparabilityVerdict $item.semantic_case $item.baseline $item.candidate `
    $item.machine ([int]$comparableCounts[$skillId]) $EvaluatedAt
  $caseRoot = Resolve-R8H5EvaluationPath $EvaluationRoot "cases/$($item.semantic_case.semantic_case_id)"
  [void](Write-R8H5ImmutableJson (Join-Path $caseRoot 'comparability-verdict.json') $verdict)
  $comparability += $verdict
}

$summary = [pscustomobject][ordered]@{
  schema_id = 'taoge://reports/r8/h5r3-evaluation/v0.1'
  evaluation_id = $evaluations[0].semantic_case.evaluation_id
  attempt_id = $evaluations[0].semantic_case.attempt_id
  evaluated_at = $EvaluatedAt
  result = 'evaluation_completed'
  arm_result_count = $records.Count
  machine_verdict_count = $evaluations.Count
  comparability_verdict_count = $comparability.Count
  machine_pass_count = @($evaluations.machine | Where-Object { $_.verdict_status -eq 'pass' }).Count
  comparable_count = @($comparability | Where-Object { $_.comparability_status -eq 'comparable' }).Count
  blind_eligible_count = @($comparability | Where-Object { $_.blind_pair_allowed -eq $true }).Count
  arm_execution_performed_by_evaluator = $false
  blind_pair_generated = $false
  human_review_started = $false
}
[void](Write-R8H5ImmutableJson (Join-Path $EvaluationRoot 'h5r3-evaluation-summary.json') $summary)
Write-Output 'result=evaluation_completed'
Write-Output "arm_result_count=$($summary.arm_result_count)"
Write-Output "machine_verdict_count=$($summary.machine_verdict_count)"
Write-Output "comparability_verdict_count=$($summary.comparability_verdict_count)"
Write-Output "comparable_count=$($summary.comparable_count)"
Write-Output "blind_eligible_count=$($summary.blind_eligible_count)"
