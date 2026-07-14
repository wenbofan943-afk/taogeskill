param(
  [Parameter(Mandatory=$true)][string]$Session,
  [Parameter(Mandatory=$true)][string]$TaskEnvelopeId,
  [Parameter(Mandatory=$true)][string]$PayloadPath,
  [Parameter(Mandatory=$true)][string]$ResultStatus,
  [int]$AttemptNo=1
)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'R7ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'R7SemanticRuntime.ps1')
try{
  $sessionRoot=if([IO.Path]::IsPathRooted($Session)){[IO.Path]::GetFullPath($Session)}else{[IO.Path]::GetFullPath((Join-Path $projectRoot $Session))}
  $result=New-R7RuntimeSubmissionFromPayload $projectRoot $sessionRoot $TaskEnvelopeId $PayloadPath $ResultStatus $AttemptNo
  Write-Output "R7_SUBMISSION_BUILD_RESULT=$($result.ResultCode)"
  if($null -ne $result.Data){Write-Output ('R7_SUBMISSION_BUILD_DATA='+($result.Data|ConvertTo-Json -Compress -Depth 20))}
  foreach($errorItem in @($result.Errors)){Write-Output "R7_SUBMISSION_BUILD_ERROR=$errorItem"}
  exit $result.ExitCode
}catch{Write-Error ('R7_SUBMISSION_BUILD_TOOL_ERROR='+$_.Exception.Message);exit 3}
