param(
  [Parameter(Mandatory=$true)][string]$SessionPath,
  [string]$ReportPath = 'state/checks/p0-h7-finalize-semantic-report.json'
)

$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'P0RuntimeV02.ps1')
. (Join-Path $PSScriptRoot 'P0EvidenceRuntime.ps1')
. (Join-Path $PSScriptRoot 'P0FinalDeliveryV03.ps1')

try{
  $root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path;$session=(Resolve-Path -LiteralPath $SessionPath).Path;$sessionId=Split-Path -Leaf $session
  $planPath=Join-Path $session 'intermediate/p0/session-execution-plan.json';$eventPath=Join-Path $session 'intermediate/p0/execution-events.jsonl';$inputPath=Join-Path $session 'deliverables/p0/final-delivery-render-input.json';$manifestPath=Join-Path $session 'manifest.yaml'
  foreach($path in @($planPath,$eventPath,$inputPath,$manifestPath)){if(-not(Test-Path -LiteralPath $path)){throw "h7_finalize_input_missing:$path"}}
  $reportFull=if([IO.Path]::IsPathRooted($ReportPath)){$ReportPath}else{Join-Path $root $ReportPath}
  $checkerOutput=@(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validate-p0-h7-delivery.ps1') -SessionPath $session -ReportPath $reportFull 2>&1|ForEach-Object{[string]$_});$checkerExit=$LASTEXITCODE
  if($checkerExit-ne0){throw('h7_semantic_gate_failed:'+([string]::Join(';',$checkerOutput)))}
  $report=Read-P0JsonFile $reportFull;if($report.overall_result-notin@('pass','pass_with_warnings')-or[int]$report.error_count-ne0){throw 'h7_semantic_report_not_passed'}
  $plan=Read-P0JsonFile $planPath;$events=@(Get-P0V2Events $eventPath);$input=Read-P0JsonFile $inputPath;$inputDigest=Get-P0V2Hash $inputPath
  if(-not(Test-P0V3RevisionClosure $session $input $inputDigest $root)){throw 'h7_revision_closure_invalid'}
  $projectionResult=Update-P0StateProjection $session $plan $eventPath $true;if($projectionResult.ExitCode-ne0){throw('h7_projection_rebuild_failed:'+($projectionResult.Errors-join';'))}
  $summary=Write-P0ResumeSummary $session $plan $projectionResult.Projection
  if([int]$projectionResult.Projection.projected_through_sequence_no-ne$events.Count-or$projectionResult.Projection.current_state-ne'completed'-or$summary.current_state-ne'completed'){throw 'h7_projection_resume_not_closed'}
  $manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
  $replacements=[ordered]@{
    'contract_set_version: p0-contract-bundle-v0.2'='contract_set_version: p0-contract-bundle-v0.3'
    'task_context_type: p0_h6_real_image_regression'='task_context_type: p0_h7_final_delivery_semantic_closure'
    'run_mode: phase_2_real_regression_with_new_image2_assets'='run_mode: h7_revision_rebuild_reusing_verified_h6_assets'
  }
  foreach($key in $replacements.Keys){$manifest=$manifest.Replace($key,$replacements[$key])}
  $manifest=[regex]::Replace($manifest,'(?m)^current_stage:.*$','current_stage: final_delivery_human_review')
  $manifest=[regex]::Replace($manifest,'(?m)^updated_at:.*$','updated_at: '+(Get-Date -Format 'yyyy-MM-dd'))
  $warningCodes=[string]::Join(', ',@($input.production_status.warning_codes|Sort-Object -Unique));$manifest=[regex]::Replace($manifest,'(?m)^  warning_codes:.*$','  warning_codes: '+$warningCodes)
  if($manifest-notmatch'(?m)^h7_delivery:'){
    $manifest=$manifest.TrimEnd()+"`n`nh7_delivery:`n  delivery_revision_id: $($input.delivery_revision.delivery_revision_id)`n  semantic_check_count: $($report.check_count)`n  semantic_result: $($report.overall_result)`n  additional_image_provider_invocation_count: 0`n  platform_unit_count: $(@($input.platform_delivery_units).Count)`n  pip_count: $(@($input.pip_cards).Count)`n  publishing_invoked: false`n"
  }
  Write-P0V2AtomicText $manifestPath $manifest
  Write-Output 'P0_H7_FINALIZE_RESULT=completed_waiting_human_review';Write-Output "DELIVERY_REVISION_ID=$($input.delivery_revision.delivery_revision_id)";Write-Output "PROJECTED_THROUGH=$($events.Count)";Write-Output "SEMANTIC_RESULT=$($report.overall_result)";Write-Output 'ADDITIONAL_IMAGE_PROVIDER_INVOCATION_COUNT=0'
  exit 0
}catch{Write-Error('P0_H7_FINALIZE_ERROR='+$_.Exception.Message);exit 3}
