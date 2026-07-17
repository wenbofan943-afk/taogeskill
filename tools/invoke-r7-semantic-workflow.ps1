param(
  [Parameter(Mandatory=$true)][string]$Session,
  [Parameter(Mandatory=$true)][ValidateSet('initialize','prepare_task','submit','reconcile','rebuild_projection','run_deterministic')][string]$Mode,
  [string]$BlueprintId='direct_delivery_single_v0.6',
  [ValidateSet('production','no_provider','reuse_only')][string]$TestProfile='production',
  [string]$SubmissionPath='',
  [string]$SubmissionId=''
)

$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'R7ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'R7SemanticRuntime.ps1')
. (Join-Path $PSScriptRoot 'R7CandidateRuntime.ps1')
. (Join-Path $PSScriptRoot 'R7ViewportRuntime.ps1')
. (Join-Path $PSScriptRoot 'R7HotspotRuntime.ps1')

try{
  $sessionRoot=if([IO.Path]::IsPathRooted($Session)){[IO.Path]::GetFullPath($Session)}else{[IO.Path]::GetFullPath((Join-Path $projectRoot $Session))}
  $result=switch($Mode){
    'initialize'{Initialize-R7RuntimeSession $projectRoot $sessionRoot $BlueprintId $TestProfile}
    'prepare_task'{Prepare-R7RuntimeTask $projectRoot $sessionRoot}
    'submit'{if([string]::IsNullOrWhiteSpace($SubmissionPath)){New-R7RuntimeResult 'submission_path_required' 2}else{Submit-R7RuntimeArtifact $projectRoot $sessionRoot $SubmissionPath}}
    'reconcile'{if([string]::IsNullOrWhiteSpace($SubmissionId)){New-R7RuntimeResult 'submission_id_required' 2}else{Reconcile-R7RuntimeSubmission $projectRoot $sessionRoot $SubmissionId}}
    'run_deterministic'{Invoke-R7DeterministicNode $projectRoot $sessionRoot}
    'rebuild_projection'{
      $plan=Read-P0JsonFile (Join-Path $sessionRoot 'intermediate/p0/session-execution-plan.json')
      $projection=Update-P0StateProjection $sessionRoot $plan (Join-Path $sessionRoot 'intermediate/p0/execution-events.jsonl') $true
      if($projection.ExitCode -eq 0){[void](Write-P0ResumeSummary $sessionRoot $plan $projection.Projection)}
      New-R7RuntimeResult $projection.ResultCode $projection.ExitCode $projection.Projection $projection.Errors
    }
  }
  Write-Output "R7_RUNTIME_RESULT=$($result.ResultCode)"
  Write-Output "R7_RUNTIME_MODE=$Mode"
  if($null -ne $result.Data){Write-Output ('R7_RUNTIME_DATA='+($result.Data|ConvertTo-Json -Depth 40 -Compress))}
  foreach($errorItem in @($result.Errors)){Write-Output "R7_RUNTIME_ERROR=$errorItem"}
  exit $result.ExitCode
}catch{
  Write-Error ('R7_RUNTIME_TOOL_ERROR='+$_.Exception.Message)
  exit 3
}
