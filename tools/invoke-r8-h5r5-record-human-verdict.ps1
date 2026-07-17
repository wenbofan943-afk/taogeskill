param(
  [string]$ProjectRoot = '',
  [Parameter(Mandatory=$true)][string]$EvaluationRoot,
  [Parameter(Mandatory=$true)][string]$RequestPath
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}
$EvaluationRoot = (Resolve-Path -LiteralPath $EvaluationRoot).Path
. (Join-Path $PSScriptRoot 'R8H5FinalizationRuntime.ps1')
Initialize-R8H5FinalizationRuntime $ProjectRoot
$request = Read-R8H5EvaluationJson (Resolve-Path -LiteralPath $RequestPath).Path
$verdict = New-R8H5HumanVerdict $EvaluationRoot $request
Write-Output 'result=human_verdict_committed'
Write-Output "human_verdict_id=$($verdict.human_verdict_id)"
Write-Output "semantic_case_id=$($verdict.semantic_case_id)"
