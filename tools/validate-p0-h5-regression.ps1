param(
  [Parameter(Mandatory=$true)][string]$SessionPath,
  [Parameter(Mandatory=$true)][string]$BaselineSessionPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'P0EvidenceRuntime.ps1')
. (Join-Path $PSScriptRoot 'P0RuntimeV02.ps1')

function Resolve-H5CheckPath([string]$Path) {
  $candidate = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $projectRoot $Path }
  return [System.IO.Path]::GetFullPath($candidate)
}
function Get-H5CheckHash([string]$Path) { return 'sha256:' + (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Add-H5Assertion([System.Collections.Generic.List[object]]$Items, [System.Collections.Generic.List[string]]$Errors, [string]$Id, [bool]$Pass, [string]$Evidence) {
  $Items.Add([ordered]@{ assertion_id=$Id; result=$(if($Pass){'pass'}else{'fail'}); evidence=$Evidence })
  if (-not $Pass) { $Errors.Add($Id) }
}
function Write-H5CheckJson([string]$Path, [object]$Value) {
  $parent=Split-Path -Parent $Path; if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
  [System.IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 50).TrimEnd("`r","`n")+"`n"),[System.Text.UTF8Encoding]::new($false))
}

try {
  $session = Resolve-H5CheckPath $SessionPath
  $baseline = Resolve-H5CheckPath $BaselineSessionPath
  if (-not (Test-Path -LiteralPath $session) -or -not (Test-Path -LiteralPath $baseline)) { throw 'session_or_baseline_missing' }
  $accountsRoot=[System.IO.Path]::GetFullPath((Join-Path $projectRoot 'accounts')).TrimEnd('\')
  if(-not $session.StartsWith($accountsRoot+'\',[System.StringComparison]::OrdinalIgnoreCase)-or-not $baseline.StartsWith($accountsRoot+'\',[System.StringComparison]::OrdinalIgnoreCase)-or(Split-Path -Parent $session)-ne(Split-Path -Parent $baseline)){throw 'h5_sessions_must_share_project_account_runs_directory'}
  $sessionId=Split-Path -Leaf $session; $baselineId=Split-Path -Leaf $baseline
  $assertions=[System.Collections.Generic.List[object]]::new(); $errors=[System.Collections.Generic.List[string]]::new()
  Add-H5Assertion $assertions $errors 'new_session_isolated' ($session -ne $baseline -and $sessionId -ne $baselineId) "$baselineId -> $sessionId"

  $manifestPath=Join-Path $session 'manifest.yaml'; $manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
  Add-H5Assertion $assertions $errors 'manifest_h5_boundary' ($manifest -match 'run_mode: phase_1_real_regression_with_verified_images_reused' -and $manifest -match 'image_provider_invoked: false' -and $manifest -match 'publishing_invoked: false') $manifestPath
  Add-H5Assertion $assertions $errors 'manifest_pass_with_warnings' ($manifest -match 'overall_result: pass_with_warnings') $manifestPath

  $provenance=Read-P0JsonFile (Join-Path $session 'inputs/h5-regression-provenance.json')
  Add-H5Assertion $assertions $errors 'baseline_identity_bound' ($provenance.baseline_session_id -eq $baselineId -and $provenance.session_id -eq $sessionId) 'inputs/h5-regression-provenance.json'
  Add-H5Assertion $assertions $errors 'content_semantic_digest_equal' ($provenance.baseline_content_semantic_sha256 -eq $provenance.target_content_semantic_sha256 -and (Test-P0Digest $provenance.target_content_semantic_sha256)) ([string]$provenance.target_content_semantic_sha256)
  Add-H5Assertion $assertions $errors 'no_external_side_effects' ([int]$provenance.provider_invocation_count -eq 0 -and [int]$provenance.publishing_invocation_count -eq 0) 'provider=0;publishing=0'

  $plan=Read-P0JsonFile (Join-Path $session 'intermediate/p0/session-execution-plan.json')
  $events=@(Get-P0EvidenceEvents (Join-Path $session 'intermediate/p0/execution-events.jsonl'))
  Add-H5Assertion $assertions $errors 'plan_contract_valid' (@(Test-P0PlanContract $plan).Count -eq 0) 'intermediate/p0/session-execution-plan.json'
  Add-H5Assertion $assertions $errors 'event_contract_valid' (@(Test-P0EventLogContract $events).Count -eq 0) "events=$($events.Count)"
  Add-H5Assertion $assertions $errors 'runtime_steps_complete' ($events.Count -eq 4 -and @($events|Where-Object{$_.state_after -eq 'succeeded'}).Count -eq 4) 'plan+reuse+compile+render'
  Add-H5Assertion $assertions $errors 'runtime_has_no_external_step' (@($plan.steps|Where-Object{$_.step_kind -eq 'external_side_effect'}).Count -eq 0 -and @($events|Where-Object{$_.event_source -eq 'external_recorder'}).Count -eq 0) 'no external step/event'

  $projection=Read-P0JsonFile (Join-Path $session 'intermediate/p0/state-projection.json')
  $resume=Read-P0JsonFile (Join-Path $session 'intermediate/p0/resume-summary.json')
  Add-H5Assertion $assertions $errors 'projection_complete' ($projection.current_state -eq 'completed' -and [int]$projection.projected_through_sequence_no -eq $events.Count) 'intermediate/p0/state-projection.json'
  Add-H5Assertion $assertions $errors 'resume_complete' ($resume.current_state -eq 'completed' -and $null -eq $resume.next_step_id) 'intermediate/p0/resume-summary.json'

  $candidate=Read-P0JsonFile (Join-Path $session 'deliverables/p0/final-delivery-render-candidate.json')
  $renderInput=Read-P0JsonFile (Join-Path $session 'deliverables/p0/final-delivery-render-input.json')
  Add-H5Assertion $assertions $errors 'candidate_contract_valid' (@(Test-P0RenderInputContract $candidate).Count -eq 0) 'deliverables/p0/final-delivery-render-candidate.json'
  Add-H5Assertion $assertions $errors 'render_input_contract_valid' (@(Test-P0RenderInputContract $renderInput).Count -eq 0) 'deliverables/p0/final-delivery-render-input.json'
  $requiredWarnings=@('content_reused_from_baseline','verified_images_reused','external_image_generation_not_tested','publishing_not_tested')
  $missingWarnings=@($requiredWarnings|Where-Object{@($renderInput.production_status.warning_codes) -notcontains $_})
  Add-H5Assertion $assertions $errors 'required_warning_codes_preserved' ($missingWarnings.Count -eq 0) ([string]::Join(',',@($renderInput.production_status.warning_codes)))
  Add-H5Assertion $assertions $errors 'delivery_readiness_derived_warning' ($renderInput.production_status.delivery_readiness -eq 'ready_with_warnings' -and $renderInput.production_status.overall_quality_status -eq 'pass_with_warnings') 'ready_with_warnings'
  $deliveryCards=@($renderInput.cover_cards)+@($renderInput.pip_cards)
  $expectedDeliveryCards=[int]$provenance.planned_pip_count+[int]$provenance.planned_platform_cover_count+[int]$provenance.cover_background_count
  Add-H5Assertion $assertions $errors 'delivery_cards_match_baseline_plan' ($deliveryCards.Count -eq $expectedDeliveryCards -and @($deliveryCards|Where-Object{$_.asset_status -eq 'reused_verified'}).Count -eq $expectedDeliveryCards) "cards=$($deliveryCards.Count);expected=$expectedDeliveryCards"
  Add-H5Assertion $assertions $errors 'upload_covers_match_baseline_plan' (@($renderInput.cover_cards|Where-Object{$_.cover_role -eq 'platform_cover' -and $_.status -eq 'ready'}).Count -eq [int]$provenance.planned_platform_cover_count) "platform_covers=$($provenance.planned_platform_cover_count)"

  $reuse=Read-P0JsonFile (Join-Path $session 'assets/images/reuse-manifest.json')
  Add-H5Assertion $assertions $errors 'copied_assets_match_provenance' (@($reuse.assets).Count -eq [int]$provenance.copied_asset_count -and @($reuse.assets|Where-Object{$_.included_in_delivery}).Count -eq [int]$provenance.delivery_asset_count) "assets=$(@($reuse.assets).Count);delivery=$(@($reuse.assets|Where-Object{$_.included_in_delivery}).Count)"
  $assetFailures=[System.Collections.Generic.List[string]]::new()
  foreach($asset in @($reuse.assets)){
    $targetPath=Join-Path $session ([string]$asset.relative_path); $sourcePath=Join-Path $baseline (([string]$asset.relative_path).Replace([string]$asset.asset_id,[string]$asset.source_asset_id)); $sidecarPath=Join-Path $session ([string]$asset.sidecar_path)
    if(-not(Test-Path -LiteralPath $targetPath)-or-not(Test-Path -LiteralPath $sourcePath)-or-not(Test-Path -LiteralPath $sidecarPath)){ $assetFailures.Add("missing:$($asset.asset_id)"); continue }
    $sidecar=Read-P0JsonFile $sidecarPath; $targetHash=Get-H5CheckHash $targetPath; $sourceHash=Get-H5CheckHash $sourcePath; $oldSidecar=Join-Path $session ([string]$sidecar.source_sidecar_path)
    if($targetHash -ne [string]$asset.sha256 -or $sourceHash -ne [string]$asset.sha256 -or $sidecar.source_session_id -ne $baselineId -or $sidecar.source_asset_id -ne $asset.source_asset_id -or $sidecar.asset_id -ne $asset.asset_id -or $sidecar.asset_status -ne 'reused_verified' -or [bool]$sidecar.external_provider_invoked){$assetFailures.Add("binding:$($asset.asset_id)")}
    if(-not(Test-Path -LiteralPath $oldSidecar)-or(Get-H5CheckHash $oldSidecar)-ne [string]$sidecar.source_sidecar_sha256){$assetFailures.Add("source_sidecar:$($asset.asset_id)")}
    if([string]::IsNullOrWhiteSpace([string]$sidecar.source_binding_id)-or[string]::IsNullOrWhiteSpace([string]$sidecar.target_binding_id)-or[string]::IsNullOrWhiteSpace([string]$sidecar.beat_binding)-or$sidecar.expected_usage -ne $sidecar.visual_role){$assetFailures.Add("prompt_beat_usage:$($asset.asset_id)")}
    if($sidecar.content_semantic_sha256 -ne $provenance.target_content_semantic_sha256){$assetFailures.Add("content:$($asset.asset_id)")}
  }
  Add-H5Assertion $assertions $errors 'asset_digest_sidecar_source_closed' ($assetFailures.Count -eq 0) ([string]::Join(',',@($assetFailures)))

  $lineageDirectory=Join-Path $session 'deliverables/p0/lineage'
  $lineageFiles=@(Get-ChildItem -LiteralPath $lineageDirectory -Filter '*.json' -File)
  $lineageErrors=[System.Collections.Generic.List[string]]::new()
  foreach($file in $lineageFiles){$document=Read-P0JsonFile $file.FullName; foreach($error in @(Test-P0LineageContract $document)){$lineageErrors.Add("$($file.Name):$error")}}
  Add-H5Assertion $assertions $errors 'copied_artifact_lineage_valid' ($lineageFiles.Count -ge 19 -and $lineageErrors.Count -eq 0) "lineage_files=$($lineageFiles.Count)"
  Add-H5Assertion $assertions $errors 'render_lineage_present' ((Test-Path -LiteralPath (Join-Path $session 'deliverables/p0/render-input-lineage.json')) -and (Test-Path -LiteralPath (Join-Path $session 'deliverables/p0/artifact-lineage-manifest.json'))) 'render input + final HTML lineage'

  $receipt=Read-P0JsonFile (Join-Path $session 'deliverables/p0/render-receipt.json'); $htmlPath=Join-Path $session 'deliverables/final-delivery.html'
  Add-H5Assertion $assertions $errors 'render_receipt_valid' (@(Test-P0V2RenderReceipt $receipt).Count -eq 0 -and $receipt.output_html_sha256 -eq (Get-H5CheckHash $htmlPath)) 'deliverables/p0/render-receipt.json'
  Add-H5Assertion $assertions $errors 'render_receipt_assets_complete' (@($receipt.included_asset_ids).Count -eq $expectedDeliveryCards -and @($requiredWarnings|Where-Object{@($receipt.warning_codes)-notcontains $_}).Count -eq 0) "assets=$(@($receipt.included_asset_ids).Count);expected=$expectedDeliveryCards"
  $html=Get-Content -LiteralPath $htmlPath -Raw -Encoding UTF8
  Add-H5Assertion $assertions $errors 'final_html_h5_identity_and_warnings' ($html -match [regex]::Escape($sessionId) -and $html -match 'content_reused_from_baseline' -and $html -notmatch '(?is)<\s*script\b|\bon[a-z]+\s*=|javascript\s*:') $htmlPath
  $runtimeCheck=Invoke-P0RuntimeV02 -Session $session -Plan $plan -EventPath (Join-Path $session 'intermediate/p0/execution-events.jsonl') -Mode 'validate' -ProjectRoot $projectRoot
  Add-H5Assertion $assertions $errors 'runtime_validate_completed' ($runtimeCheck.ExitCode -eq 0 -and @($runtimeCheck.Lines) -contains 'WORKFLOW_RUNTIME_RESULT=plan_valid_completed') ([string]::Join(';',@($runtimeCheck.Lines)))

  $result=if($errors.Count){'fail'}else{'pass_with_warnings'}
  $report=[ordered]@{schema_id='taoge://reports/p0/h5-real-regression/v0.1';schema_version='0.1';session_id=$sessionId;baseline_session_id=$baselineId;generated_at=[DateTimeOffset]::UtcNow.ToString('o');overall_result=$result;failure_category=$(if($errors.Count){'workflow_or_fixture_defect'}else{$null});warning_codes=$requiredWarnings;not_tested_scope=@('new_content_quality','new_image_provider','automatic_publishing','platform_login','real_distribution_effect');assertions=[object[]]$assertions.ToArray();errors=[object[]]$errors.ToArray()}
  $reportPath=Join-Path $session 'intermediate/p0/h5-regression-check-report.json'; Write-H5CheckJson $reportPath $report
  Write-Output "P0_H5_CHECK_RESULT=$result"; Write-Output "ASSERTION_COUNT=$($assertions.Count)"; Write-Output "ERROR_COUNT=$($errors.Count)"; Write-Output "REPORT=$reportPath"
  if($errors.Count){$errors|ForEach-Object{Write-Output "ERROR=$_"};exit 1}; exit 0
} catch {
  Write-Error ('P0_H5_CHECKER_ERROR=' + $_.Exception.Message); exit 3
}
