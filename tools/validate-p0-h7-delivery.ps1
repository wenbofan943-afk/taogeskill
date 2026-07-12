param(
  [Parameter(Mandatory=$true)][string]$SessionPath,
  [string]$ReportPath = 'state/checks/p0-h7-delivery-report.json'
)

$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'P0RuntimeV02.ps1')
. (Join-Path $PSScriptRoot 'P0FinalDeliveryV03.ps1')

function Read-H7CheckJson([string]$Path){Get-Content -LiteralPath $Path -Raw -Encoding UTF8|ConvertFrom-Json}
function Add-H7Check([Collections.Generic.List[object]]$Checks,[Collections.Generic.List[string]]$Errors,[string]$Id,[bool]$Pass,[string]$Evidence){$Checks.Add([ordered]@{check_id=$Id;status=$(if($Pass){'pass'}else{'fail'});evidence=$Evidence});if(-not $Pass){$Errors.Add("${Id}:$Evidence")}}
function Resolve-H7CheckPath([string]$Root,[string]$Relative){[IO.Path]::GetFullPath((Join-Path $Root $Relative))}

try{
  $session=(Resolve-Path -LiteralPath $SessionPath).Path;$sessionId=Split-Path -Leaf $session
  $candidatePath=Join-Path $session 'deliverables/p0/final-delivery-render-candidate.json';$inputPath=Join-Path $session 'deliverables/p0/final-delivery-render-input.json';$revisionPath=Join-Path $session 'deliverables/p0/delivery-revision.json';$receiptPath=Join-Path $session 'deliverables/p0/render-receipt.json';$htmlPath=Join-Path $session 'deliverables/final-delivery.html'
  foreach($path in @($candidatePath,$inputPath,$revisionPath,$receiptPath,$htmlPath)){if(-not(Test-Path -LiteralPath $path)){throw "h7_required_artifact_missing:$path"}}
  $candidate=Read-H7CheckJson $candidatePath;$input=Read-H7CheckJson $inputPath;$revision=Read-H7CheckJson $revisionPath;$receipt=Read-H7CheckJson $receiptPath;$html=Get-Content -LiteralPath $htmlPath -Raw -Encoding UTF8
  $checks=[Collections.Generic.List[object]]::new();$errors=[Collections.Generic.List[string]]::new()
  $candidateErrors=@(Test-P0RenderInputContract $candidate);Add-H7Check $checks $errors 'H7-001-candidate-contract' ($candidateErrors.Count-eq0) ($candidateErrors-join';')
  $inputErrors=@(Test-P0RenderInputContract $input);Add-H7Check $checks $errors 'H7-002-input-contract' ($inputErrors.Count-eq0) ($inputErrors-join';')
  Add-H7Check $checks $errors 'H7-003-version' ($input.schema_version-eq'typed_components_v0.3'-and$input.template_version-eq'final-delivery-template-v0.3') "$($input.schema_version)/$($input.template_version)"
  Add-H7Check $checks $errors 'H7-004-revision-binding' ($candidate.delivery_revision.delivery_revision_id-eq$input.delivery_revision.delivery_revision_id-and$input.delivery_revision.revision_status-eq'compiled'-and$input.delivery_revision.semantic_gate_status-eq'pass') "$($input.delivery_revision.delivery_revision_id)/$($input.delivery_revision.revision_status)"
  $inputDigest=Get-P0V2Hash $inputPath;Add-H7Check $checks $errors 'H7-005-revision-closure' (Test-P0V3RevisionClosure $session $input $inputDigest $projectRoot) $revisionPath
  $receiptErrors=@(Test-P0V3RenderReceipt $receipt);Add-H7Check $checks $errors 'H7-006-receipt' ($receiptErrors.Count-eq0-and$receipt.delivery_revision_id-eq$input.delivery_revision.delivery_revision_id) ($receiptErrors-join';')
  $unitPass=@($input.platform_delivery_units).Count-eq@($input.platform_cards).Count-and@($input.platform_delivery_units|Where-Object{$_.publish_readiness-ne'ready'}).Count-eq0
  Add-H7Check $checks $errors 'H7-007-platform-units' $unitPass "units=$(@($input.platform_delivery_units).Count);cards=$(@($input.platform_cards).Count)"
  $coverFailures=[Collections.Generic.List[string]]::new()
  foreach($unit in @($input.platform_delivery_units)){$cover=@($input.cover_cards|Where-Object{$_.card_id-eq$unit.cover_card_id})|Select-Object -First 1;if($null-eq$cover){$coverFailures.Add("missing:$($unit.platform)");continue};$path=Resolve-H7CheckPath $session ([string]$unit.cover_asset_path);$sidecar=Resolve-H7CheckPath $session ([string]$cover.sidecar_path);if((-not(Test-Path -LiteralPath $path))-or(-not(Test-Path -LiteralPath $sidecar))){$coverFailures.Add("file:$($unit.platform)");continue};$record=Read-H7CheckJson $sidecar;if(((ConvertTo-P0NormalizedDeliveryTitle $unit.cover_title)-ne(ConvertTo-P0NormalizedDeliveryTitle $record.cover_title))-or((Get-P0V2Hash $path)-ne[string]$unit.cover_sha256)){$coverFailures.Add("semantic:$($unit.platform)")}}
  Add-H7Check $checks $errors 'H7-008-cover-title-asset' ($coverFailures.Count-eq0) ($coverFailures-join',')
  $pipFailures=[Collections.Generic.List[string]]::new();foreach($card in @($input.pip_cards)){foreach($field in @('insert_after_text','insert_before_text')){if([string]::IsNullOrWhiteSpace([string]$card.$field)){$pipFailures.Add("$($card.card_id):$field")}};foreach($field in @('prompt_path','generation_record_path','sidecar_path')){if(([string]::IsNullOrWhiteSpace([string]$card.$field))-or(-not(Test-Path -LiteralPath (Resolve-H7CheckPath $session ([string]$card.$field))))){$pipFailures.Add("$($card.card_id):$field")}}}
  Add-H7Check $checks $errors 'H7-009-pip-exact-and-trace' ($pipFailures.Count-eq0) ($pipFailures-join',')
  $visualPath=Join-Path $session 'intermediate/p0/h6-visual-need-analysis.json';$placementFailures=[Collections.Generic.List[string]]::new()
  if(Test-Path -LiteralPath $visualPath){$visual=Read-H7CheckJson $visualPath;foreach($card in @($input.pip_cards)){$source=@($visual.candidates|Where-Object{$_.trigger_text-eq$card.trigger_text})|Select-Object -First 1;if($null-eq$source-or$source.insert_after_text-ne$card.insert_after_text-or$source.insert_before_text-ne$card.insert_before_text){$placementFailures.Add([string]$card.card_id)}}}
  Add-H7Check $checks $errors 'H7-010-placement-source-match' ($placementFailures.Count-eq0) ($placementFailures-join',')
  $activeCodes=@($input.warning_items|Where-Object{$_.resolution_status-ne'resolved'}|ForEach-Object{[string]$_.warning_code}|Sort-Object -Unique);$declaredCodes=@($input.production_status.warning_codes|Sort-Object -Unique)
  Add-H7Check $checks $errors 'H7-011-warning-union' (($activeCodes-join'|')-eq($declaredCodes-join'|')) (($activeCodes-join',')+' vs '+($declaredCodes-join','))
  $warningHumanPass=@($input.warning_items|Where-Object{[string]::IsNullOrWhiteSpace([string]$_.user_message)-or[string]::IsNullOrWhiteSpace([string]$_.impact)-or[string]::IsNullOrWhiteSpace([string]$_.recommended_action)}).Count-eq0
  Add-H7Check $checks $errors 'H7-012-warning-human-copy' $warningHumanPass "count=$(@($input.warning_items).Count)"
  $auditIndex=$html.IndexOf('<section id="audit">',[StringComparison]::Ordinal);$userHtml=if($auditIndex-gt0){$html.Substring(0,$auditIndex)}else{$html}
  $rawVisible=@($declaredCodes|Where-Object{$userHtml.Contains([string]$_)})
  $userLayerPass=($auditIndex-gt0)-and($rawVisible.Count-eq0)-and(-not($userHtml-match'H5 不登录平台|图片状态必须诚实展示|platform_cover|ready_with_warnings|short_video_talking_head'))
  Add-H7Check $checks $errors 'H7-013-user-layer-language' $userLayerPass ($rawVisible-join',')
  Add-H7Check $checks $errors 'H7-014-run-provenance' ($userHtml.Contains([string]$input.run_provenance.user_summary)-and$input.run_provenance.run_purpose-eq'regression') ([string]$input.run_provenance.user_summary)
  Add-H7Check $checks $errors 'H7-015-duration-honesty' (($input.duration_estimate.duration_estimate_status-eq'not_available')-and(-not(Test-P0HasProperty $input.script_card 'estimated_duration_seconds'))-and$userHtml.Contains('口播时长暂不估算')) ([string]$input.duration_estimate.duration_estimate_status)
  $viewFailures=[Collections.Generic.List[string]]::new();foreach($property in $input.delivery_revision.generated_view_paths.PSObject.Properties){$path=Resolve-H7CheckPath $session ([string]$property.Value);if(-not(Test-Path -LiteralPath $path)){$viewFailures.Add($property.Name)}}
  Add-H7Check $checks $errors 'H7-016-view-files' ($viewFailures.Count-eq0) ($viewFailures-join',')
  $revisionMentions=[Collections.Generic.List[string]]::new();foreach($path in @('deliverables/final-script.md','deliverables/final-visual-plan.md','deliverables/final-platform-package.md','deliverables/content-delivery-record.md')){$text=Get-Content -LiteralPath (Join-Path $session $path) -Raw -Encoding UTF8;if(-not $text.Contains([string]$input.delivery_revision.delivery_revision_id)){$revisionMentions.Add($path)}}
  Add-H7Check $checks $errors 'H7-017-view-revision-consistency' ($revisionMentions.Count-eq0) ($revisionMentions-join',')
  $visualText=Get-Content -LiteralPath (Join-Path $session 'deliverables/final-visual-plan.md') -Raw -Encoding UTF8;Add-H7Check $checks $errors 'H7-018-final-visual-count' ([regex]::Matches($visualText,'(?m)^\|\s*\d+\s*\|').Count-eq@($input.pip_cards).Count) "md=$([regex]::Matches($visualText,'(?m)^\|\s*\d+\s*\|').Count);input=$(@($input.pip_cards).Count)"
  $platformText=Get-Content -LiteralPath (Join-Path $session 'deliverables/final-platform-package.md') -Raw -Encoding UTF8;Add-H7Check $checks $errors 'H7-019-final-platform-count' ([regex]::Matches($platformText,'(?m)^\|\s*(?:抖音|快手|小红书|视频号)\s*\|').Count-eq@($input.platform_delivery_units).Count) "md=$([regex]::Matches($platformText,'(?m)^\|\s*(?:抖音|快手|小红书|视频号)\s*\|').Count);input=$(@($input.platform_delivery_units).Count)"
  $htmlErrors=@(Test-P0V3RenderedHtml $html $htmlPath $session);Add-H7Check $checks $errors 'H7-020-html-structure-links-security' ($htmlErrors.Count-eq0) ($htmlErrors-join';')
  $result=if($errors.Count){'fail'}elseif(@($input.warning_items|Where-Object{$_.resolution_status-ne'resolved'}).Count){'pass_with_warnings'}else{'pass'}
  $report=[ordered]@{schema_id='taoge://reports/p0/h7-delivery-semantic/v0.1';schema_version='0.1';session_id=$sessionId;generated_at=[DateTimeOffset]::UtcNow.ToString('o');overall_result=$result;check_count=$checks.Count;error_count=$errors.Count;warning_count=@($input.warning_items|Where-Object{$_.resolution_status-ne'resolved'}).Count;checks=[object[]]$checks.ToArray();errors=[object[]]$errors.ToArray();not_tested_scope=@('platform_login','automatic_publishing','distribution_effect')}
  $target=if([IO.Path]::IsPathRooted($ReportPath)){$ReportPath}else{Join-Path $projectRoot $ReportPath};$parent=Split-Path -Parent $target;if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};[IO.File]::WriteAllText($target,(($report|ConvertTo-Json -Depth 20)+"`n"),[Text.UTF8Encoding]::new($false))
  foreach($check in $checks){Write-Output "$($check.check_id) $($check.status) $($check.evidence)"}
  Write-Output "P0_H7_DELIVERY_CHECK=$result";Write-Output "CHECK_COUNT=$($checks.Count)";Write-Output "ERROR_COUNT=$($errors.Count)";Write-Output "REPORT=$target"
  if($errors.Count){exit 1};exit 0
}catch{Write-Error("P0_H7_DELIVERY_CHECK_ERROR="+$_.Exception.Message);exit 3}
