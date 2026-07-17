param(
  [string]$ProjectRoot = '',
  [Parameter(Mandatory=$true)][string]$SourcePath,
  [Parameter(Mandatory=$true)][string]$EvaluationId,
  [Parameter(Mandatory=$true)][string]$AttemptId,
  [Parameter(Mandatory=$true)][string]$PreparedAt,
  [string]$OutputRoot = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = Join-Path $ProjectRoot "state/checks/r8/$EvaluationId/$AttemptId"
}
. (Join-Path $PSScriptRoot 'R8H5BlindRuntime.ps1')
Initialize-R8H5BlindRuntime $ProjectRoot

& (Join-Path $PSScriptRoot 'invoke-r8-h5r2-input-compile.ps1') -ProjectRoot $ProjectRoot `
  -SourcePath $SourcePath -EvaluationId $EvaluationId -AttemptId $AttemptId `
  -CompiledAt $PreparedAt -OutputRoot $OutputRoot
if (-not $?) { throw 'h5r2_input_compile_failed' }

$compileResult = Read-R8H5EvaluationJson (Join-Path $OutputRoot 'input-compile-result.json')
$taskCount = 0
foreach ($caseItem in @($compileResult.cases)) {
  $semantic = Read-R8H5EvaluationJson (Resolve-R8H5EvaluationPath $OutputRoot "cases/$($caseItem.semantic_case_id)/semantic-case.json")
  foreach ($role in @('baseline','candidate')) {
    [void](New-R8H5ArmExecutionTask $OutputRoot $semantic $role $PreparedAt)
    $taskCount++
  }
}
$summary = [pscustomobject][ordered]@{
  schema_id = 'taoge://reports/r8/h5r4-prepare/v0.1'
  evaluation_id = $EvaluationId
  attempt_id = $AttemptId
  result = 'ready_for_independent_arms'
  task_count = $taskCount
  isolation_level = 'instruction_isolated'
  arm_execution_started = $false
  prepared_at = $PreparedAt
}
[void](Write-R8H5ImmutableJson (Join-Path $OutputRoot 'h5r4-prepare-summary.json') $summary)
Write-Output 'result=ready_for_independent_arms'
Write-Output "task_count=$taskCount"
Write-Output "output_root=$OutputRoot"
