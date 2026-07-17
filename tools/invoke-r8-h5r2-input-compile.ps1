param(
  [string]$ProjectRoot = '',
  [Parameter(Mandatory=$true)][string]$SourcePath,
  [Parameter(Mandatory=$true)][string]$EvaluationId,
  [Parameter(Mandatory=$true)][string]$AttemptId,
  [Parameter(Mandatory=$true)][string]$CompiledAt,
  [string]$OutputRoot = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
} else {
  $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = Join-Path $ProjectRoot "state/checks/r8/$EvaluationId/$AttemptId"
}
. (Join-Path $PSScriptRoot 'R8H5InputRuntime.ps1')

$catalog = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8 | ConvertFrom-Json
$results = @()
foreach ($case in @($catalog.cases)) {
  $results += Invoke-R8H5CaseCompile -ProjectRoot $ProjectRoot -Case $case `
    -EvaluationId $EvaluationId -AttemptId $AttemptId -OutputRoot $OutputRoot -CompiledAt $CompiledAt
}
$catalogResult = [pscustomobject][ordered]@{
  schema_id = 'taoge://reports/r8/h5r2-input-compile/v0.1'
  evaluation_id = $EvaluationId
  attempt_id = $AttemptId
  compiled_at = $CompiledAt
  result = 'pass'
  case_count = $results.Count
  arm_input_count = $results.Count * 2
  arm_execution_started = $false
  cases = @($results)
}
[void](Write-R8H5ImmutableJson (Join-Path $OutputRoot 'input-compile-result.json') $catalogResult)
Write-Output "result=pass"
Write-Output "case_count=$($results.Count)"
Write-Output "arm_input_count=$($results.Count * 2)"
Write-Output "output_root=$OutputRoot"
