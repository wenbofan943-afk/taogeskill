param(
  [Parameter(Mandatory=$true)][string]$SessionPath,
  [string]$ReportPath = 'state/checks/p0-h7-v04-delivery-report.json'
)

$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'P0ContractV04.ps1')
. (Join-Path $PSScriptRoot 'P0RuntimeV02.ps1')
. (Join-Path $PSScriptRoot 'P0FinalDeliveryV04.ps1')

function Add-H7V04Check([Collections.Generic.List[object]]$Checks,[Collections.Generic.List[string]]$Failures,[string]$Id,[bool]$Pass,[string]$Evidence){$Checks.Add([ordered]@{check_id=$Id;status=$(if($Pass){'pass'}else{'fail'});evidence=$Evidence});if(-not$Pass){$Failures.Add("${Id}:$Evidence")}}
function Write-H7V04Json([string]$Path,[object]$Value){$parent=Split-Path -Parent $Path;if(-not(Test-Path $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 60)+"`n"),[Text.UTF8Encoding]::new($false))}

try{
  $session=(Resolve-Path -LiteralPath $SessionPath).Path
  $paths=[ordered]@{candidate=Join-Path $session 'deliverables/p0/final-delivery-render-candidate.json';input=Join-Path $session 'deliverables/p0/final-delivery-render-input.json';revision=Join-Path $session 'deliverables/p0/delivery-revision.json';receipt=Join-Path $session 'deliverables/p0/render-receipt.json';html=Join-Path $session 'deliverables/final-delivery.html'}
  foreach($path in $paths.Values){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "h7_v04_required_artifact_missing:$path"}}
  $candidate=Read-P0JsonFile $paths.candidate;$input=Read-P0JsonFile $paths.input;$revision=Read-P0JsonFile $paths.revision;$receipt=Read-P0JsonFile $paths.receipt;$html=Get-Content $paths.html -Raw -Encoding UTF8
  $checks=[Collections.Generic.List[object]]::new();$failures=[Collections.Generic.List[string]]::new()
  $candidateErrors=@(Test-P0RenderInputContract $candidate);Add-H7V04Check $checks $failures 'H7V04-001-candidate-contract' ($candidateErrors.Count-eq0) ($candidateErrors-join';')
  $inputErrors=@(Test-P0RenderInputContract $input);Add-H7V04Check $checks $failures 'H7V04-002-input-contract' ($inputErrors.Count-eq0) ($inputErrors-join';')
  Add-H7V04Check $checks $failures 'H7V04-003-version' ($input.schema_version-eq'typed_components_v0.4'-and$input.template_version-eq'final-delivery-template-v0.4') "$($input.schema_version)/$($input.template_version)"
  Add-H7V04Check $checks $failures 'H7V04-004-revision-state' ($input.delivery_revision.revision_status-eq'compiled'-and$input.delivery_revision.semantic_gate_status-eq'pass'-and$revision.revision_status-eq'current') "$($input.delivery_revision.revision_status)/$($revision.revision_status)"
  $inputDigest=Get-P0V2Hash $paths.input;Add-H7V04Check $checks $failures 'H7V04-005-revision-closure' (Test-P0V4RevisionClosure $session $input $inputDigest $projectRoot) $paths.revision
  $receiptErrors=@(Test-P0V4RenderReceipt $receipt);Add-H7V04Check $checks $failures 'H7V04-006-receipt' ($receiptErrors.Count-eq0-and$receipt.delivery_revision_id-eq$input.delivery_revision.delivery_revision_id) ($receiptErrors-join';')
  $referenceErrors=@(Test-P0V2MaterializedReferences $input $session);Add-H7V04Check $checks $failures 'H7V04-007-materialized-bindings' ($referenceErrors.Count-eq0) ($referenceErrors-join';')
  $scope=(Get-P0V4DeliveryReadiness $input).platform_delivery_scope_status;Add-H7V04Check $checks $failures 'H7V04-008-scope-derived' ($scope-eq$input.production_status.platform_delivery_scope_status) "$scope/$($input.production_status.platform_delivery_scope_status)"
  $coverPass=@($input.cover_cards|Where-Object{$_.cover_delivery_status-ne'visual_pass'-or$_.visual_review_status-ne'pass'-or$_.reviewer_type-notin@('codex_visual_review','human_visual_review')}).Count-eq0
  Add-H7V04Check $checks $failures 'H7V04-009-explicit-visual-review' $coverPass "cover_count=$(@($input.cover_cards).Count)"
  $visualPass=@($input.visual_insert_cards|Where-Object{$_.aspect_ratio_verification_status-ne'pass'-or$_.presentation_mode-notin@('full_frame_replace','speaker_plus_visual','split_screen','floating_card','source_evidence_card','background_plate')}).Count-eq0
  Add-H7V04Check $checks $failures 'H7V04-010-visual-insert-presentation' $visualPass "visual_insert_count=$(@($input.visual_insert_cards).Count)"
  $htmlErrors=@(Test-P0V4RenderedHtml $html $paths.html $session);Add-H7V04Check $checks $failures 'H7V04-011-html-contract' ($htmlErrors.Count-eq0) ($htmlErrors-join';')
  $responsive=$html.Contains('grid-template-columns:minmax(0,.9fr) minmax(0,1.1fr)')-and$html.Contains('@media(max-width:760px)')-and$html.Contains('overflow-x:hidden')
  Add-H7V04Check $checks $failures 'H7V04-012-responsive-no-overflow-contract' $responsive 'template has minmax(0), mobile collapse, and root overflow guard'
  $previewLabel=$html.Contains('平台表面预览（不等于真实平台截图）')-and$html.Contains('deterministic_surface_mock')
  Add-H7V04Check $checks $failures 'H7V04-013-preview-evidence-honesty' $previewLabel 'deterministic preview is labelled as non-platform screenshot'
  $accountsRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot 'accounts')).TrimEnd('\')+'\';$realAccountDataExecuted=$session.StartsWith($accountsRoot,[StringComparison]::OrdinalIgnoreCase)
  $overall=if($failures.Count){'fail'}else{'pass'};$report=[ordered]@{schema_id='taoge://reports/p0/h7-v04-delivery/v0.1';schema_version='0.1';generated_at=[DateTimeOffset]::UtcNow.ToString('o');session_id=[string]$input.session_id;overall_result=$overall;check_count=$checks.Count;failure_count=$failures.Count;checks=[object[]]$checks.ToArray();failures=[object[]]$failures.ToArray();real_account_data_executed=$realAccountDataExecuted;image_provider_called=$false;real_platform_preview_executed=$false;publishing_executed=$false}
  $target=if([IO.Path]::IsPathRooted($ReportPath)){$ReportPath}else{Join-Path $projectRoot $ReportPath};Write-H7V04Json $target $report
  Write-Output "P0_H7_V04_DELIVERY=$overall";Write-Output "CHECK_COUNT=$($checks.Count)";Write-Output "REPORT=$target";if($failures.Count){$failures|ForEach-Object{Write-Output "ERROR=$_"};exit 1};exit 0
}catch{Write-Error("P0_H7_V04_DELIVERY_ERROR="+$_.Exception.Message);exit 3}
