param(
  [string]$ProjectRoot = '',
  [Parameter(Mandatory=$true)][string]$EvaluationRoot,
  [Parameter(Mandatory=$true)][string]$FinalizedAt
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}
$EvaluationRoot = (Resolve-Path -LiteralPath $EvaluationRoot).Path
. (Join-Path $PSScriptRoot 'R8H5FinalizationRuntime.ps1')
Initialize-R8H5FinalizationRuntime $ProjectRoot
$finalization = New-R8H5EvaluationFinalization $EvaluationRoot $FinalizedAt
[void](Write-R8H5ImmutableJson (Join-Path $EvaluationRoot 'evaluation-finalization.json') $finalization)
$projection = New-R8H5StateProjection $finalization $FinalizedAt
[void](Write-R8H5ImmutableJson (Join-Path $EvaluationRoot 'h5-state-projection.json') $projection)
Write-Output 'result=evaluation_finalized'
Write-Output "current_switch_readiness=$($finalization.current_switch_readiness)"
Write-Output "overall_result=$($finalization.overall_result)"
Write-Output "readiness_blockers=$([string]::Join(',',@($finalization.readiness_blockers)))"
