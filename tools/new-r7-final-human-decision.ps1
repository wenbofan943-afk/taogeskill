param(
  [Parameter(Mandatory=$true)][string]$Session,
  [Parameter(Mandatory=$true)][string]$TaskEnvelopeId,
  [Parameter(Mandatory=$true)][ValidateSet('human_confirm','revision_requested','export_requested','archive_requested')][string]$DecisionStatus,
  [Parameter(Mandatory=$true)][ValidateSet('publish_primary_manually','publish_all_manually','revise_copy','revise_visual','export_handoff','archive_session')][string]$RequestedAction,
  [string]$TargetArtifactId='',
  [string]$ProjectRoot
)

$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($ProjectRoot)){$ProjectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path}
. (Join-Path $PSScriptRoot 'R7ViewportRuntime.ps1')
$result=New-R7FinalHumanSubmission -ProjectRoot $ProjectRoot -Session $Session -TaskEnvelopeId $TaskEnvelopeId -DecisionStatus $DecisionStatus -RequestedAction $RequestedAction -TargetArtifactId $TargetArtifactId
$result|ConvertTo-Json -Depth 30
exit ([int]$result.ExitCode)
