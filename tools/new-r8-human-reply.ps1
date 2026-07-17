param(
  [Parameter(Mandatory=$true)][string]$Session,
  [Parameter(Mandatory=$true)][ValidateSet('topic_human_gate','final_human_decision_gate')][string]$GateNodeId,
  [Parameter(Mandatory=$true)][string]$ReplyText,
  [Parameter(Mandatory=$true)][string]$RecordedAt
)

$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'R7ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'R7SemanticRuntime.ps1')
. (Join-Path $PSScriptRoot 'R8HumanGateRuntime.ps1')

try{
  $sessionRoot=if([IO.Path]::IsPathRooted($Session)){[IO.Path]::GetFullPath($Session)}else{[IO.Path]::GetFullPath((Join-Path $projectRoot $Session))}
  if(-not(Test-Path -LiteralPath $sessionRoot -PathType Container)){throw 'session_missing'}
  $sessionId=Split-Path -Leaf $sessionRoot
  $replyDigest=Get-R7RuntimeTextDigest $ReplyText
  $reply=[pscustomobject][ordered]@{
    schema_id='taoge://schemas/r7/human-reply/v0.1'
    schema_version='0.1'
    reply_id="REPLY-$sessionId-$($replyDigest.Substring($replyDigest.Length-12))"
    session_id=$sessionId
    gate_node_id=$GateNodeId
    reply_text=$ReplyText
    reply_digest=$replyDigest
    recorded_at=$RecordedAt
  }
  $errors=@(Test-R8HumanReply $reply $sessionId $GateNodeId)
  if($errors.Count){foreach($item in $errors){Write-Output "R8_HUMAN_REPLY_ERROR=$item"};exit 1}
  $relative=if($GateNodeId-eq'topic_human_gate'){'inputs/topic-human-reply.json'}else{'inputs/final-human-reply.json'}
  $path=Join-Path $sessionRoot $relative
  $text=ConvertTo-P0EvidenceJsonText $reply
  if(Test-Path -LiteralPath $path -PathType Leaf){
    $existing=(Get-Content -Raw -Encoding UTF8 $path).TrimEnd("`r","`n")
    if($existing-ne$text.TrimEnd("`r","`n")){Write-Output 'R8_HUMAN_REPLY_RESULT=current_reply_conflict';exit 1}
    Write-Output 'R8_HUMAN_REPLY_RESULT=duplicate_reused'
  }else{
    Write-P0EvidenceAtomicText $path $text
    Write-Output 'R8_HUMAN_REPLY_RESULT=reply_recorded'
  }
  Write-Output "R8_HUMAN_REPLY_PATH=$relative"
  Write-Output "R8_HUMAN_REPLY_DIGEST=$replyDigest"
  exit 0
}catch{
  Write-Error ('R8_HUMAN_REPLY_TOOL_ERROR='+$_.Exception.Message)
  exit 3
}
