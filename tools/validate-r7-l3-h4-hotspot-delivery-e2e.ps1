param(
  [string]$ProjectRoot=(Split-Path -Parent $PSScriptRoot),
  [string]$WorkRoot='',
  [string]$ReportPath=''
)
$ErrorActionPreference='Stop'
$ProjectRoot=[IO.Path]::GetFullPath($ProjectRoot)
if([string]::IsNullOrWhiteSpace($WorkRoot)){$WorkRoot=Join-Path $ProjectRoot 'state/checks/r7-l3-h4-hotspot-delivery-e2e'}
if([string]::IsNullOrWhiteSpace($ReportPath)){$ReportPath=Join-Path $ProjectRoot 'state/checks/r7-l3-h4-hotspot-delivery-e2e-report.json'}
$WorkRoot=[IO.Path]::GetFullPath($WorkRoot);$ReportPath=[IO.Path]::GetFullPath($ReportPath)
$allowedRoot=([IO.Path]::GetFullPath((Join-Path $ProjectRoot 'state/checks')).TrimEnd('\')+'\')
if(-not$WorkRoot.StartsWith($allowedRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'work_root_outside_state_checks'}
if(-not$ReportPath.StartsWith($allowedRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'report_path_outside_state_checks'}
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'R7CandidateRuntime.ps1')
. (Join-Path $PSScriptRoot 'R7ViewportRuntime.ps1')
. (Join-Path $PSScriptRoot 'R7VisualSemanticRuntime.ps1')

function Write-HotspotE2EJson([string]$Path,[object]$Value){Write-P0EvidenceAtomicText $Path (ConvertTo-P0EvidenceJsonText $Value)}
function Require-HotspotE2E([bool]$Condition,[string]$Code){if(-not$Condition){throw $Code}}

try {
  if(Test-Path -LiteralPath $WorkRoot){Remove-Item -LiteralPath $WorkRoot -Recurse -Force}
  New-Item -ItemType Directory -Path $WorkRoot -Force|Out-Null
  $fixture=Get-Content -Raw -Encoding UTF8 (Join-Path $ProjectRoot 'examples/r7-l3-h4-hotspot-delivery-fixture/cases.json')|ConvertFrom-Json
  Require-HotspotE2E ([string]$fixture.privacy_class-eq'public_redacted_synthetic'-and@($fixture.cases).Count-eq1) 'fixture_catalog_invalid'
  $candidateRoot=Join-Path (Split-Path -Parent $WorkRoot) '.r7hot-e2e'
  $candidateHuman=Join-Path $candidateRoot 'report.md';$candidateMachine=Join-Path $candidateRoot 'report.json'
  $candidateOutput=@(& (Join-Path $PSScriptRoot 'validate-r7-h4-candidate-runtime.ps1') -WorkRoot $candidateRoot -HumanReportPath $candidateHuman -MachineReportPath $candidateMachine 2>&1)
  if($LASTEXITCODE-ne0){throw ('candidate_fixture_failed:'+([string]::Join(';',@($candidateOutput))))}
  $candidateRun=Get-ChildItem -LiteralPath $candidateRoot -Directory|Sort-Object LastWriteTime -Descending|Select-Object -First 1
  Require-HotspotE2E ($null-ne$candidateRun) 'candidate_fixture_run_missing'
  $session=Join-Path $candidateRun.FullName 'R7-L3-H4-HOTSPOT-E2E'
  Require-HotspotE2E (Test-Path -LiteralPath $session) 'hotspot_same_session_missing'
  $candidate=Get-R7CandidateCurrentArtifact $session 'final_delivery_render_candidate'
  Require-HotspotE2E ([string]$candidate.Payload.content_source_context.content_origin-eq'hotspot_selected_topic') 'hotspot_origin_not_bound'
  Require-HotspotE2E (@($candidate.Payload.source_map).Count-eq18) 'hotspot_source_map_not_complete'
  $rendered=Get-R7CandidateCurrentArtifact $session 'final_delivery'
  Require-HotspotE2E (Test-Path -LiteralPath (Join-Path $session $rendered.Payload.html_path)) 'hotspot_final_html_missing'
  $viewport=Invoke-R7ViewportAcceptance $ProjectRoot $session
  Require-HotspotE2E ($viewport.ExitCode-eq0) ('viewport_failed:'+([string]::Join(';',@($viewport.Errors))))
  $viewportItem=Get-R7CandidateCurrentArtifact $session 'viewport_acceptance_report'
  Require-HotspotE2E ([string]$viewportItem.Payload.overall_result-eq'pass'-and@($viewportItem.Payload.profiles).Count-eq2) 'viewport_evidence_incomplete'
  $visualTask=Prepare-R7RuntimeTask $ProjectRoot $session
  Require-HotspotE2E ($visualTask.ExitCode-eq0-and[string]$visualTask.Data.Task.node_id-eq'delivery_visual_review') 'delivery_visual_review_task_missing'
  $assets=Get-R7CandidateCurrentArtifact $session 'image_asset_delivery_set'
  $visualReview=[ordered]@{schema_id='taoge://schemas/r3/delivery-visual-review/v0.1';schema_version='0.1';delivery_visual_review_id='DVR-HOTSPOT-E2E-001';review_revision=1;session_id='R7-L3-H4-HOTSPOT-E2E';role='delivery_reviewer';reviewer_task_envelope_ref=[ordered]@{task_envelope_id=[string]$visualTask.Data.Task.task_envelope_id};producer_task_envelope_refs=@([ordered]@{task_envelope_id=[string]$rendered.Pointer.task_envelope_id},[ordered]@{task_envelope_id=[string]$viewportItem.Pointer.task_envelope_id});delivery_asset_refs=@($assets.Payload.delivery_assets|ForEach-Object{[ordered]@{asset_id=[string]$_.delivery_asset_ref.asset_id;sha256=[string]$_.delivery_asset_ref.sha256}});html_ref=[ordered]@{path=[string]$rendered.Payload.html_path;sha256=[string]$rendered.Payload.html_sha256};desktop_screenshot_ref=[ordered]@{sha256=[string]$viewportItem.Payload.profiles[0].screenshot_sha256};mobile_screenshot_ref=[ordered]@{sha256=[string]$viewportItem.Payload.profiles[1].screenshot_sha256};actual_delivery_assets_viewed=$true;actual_screenshots_viewed=$true;base_asset_view_only=$false;dimensions=@('final_asset_binding','desktop_readability','mobile_readability','source_transparency','action_usability','safe_area')|ForEach-Object{[ordered]@{dimension_id=$_;status='pass';finding='public redacted fixture reviewed'}};review_status='pass';freshness_status='current';blocking_issue_codes=@();revision_request=$null;reviewer_mutation_declared=$false;input_bundle_digest='sha256:'+[string]$visualTask.Data.Task.input_binding_digest;reviewed_at='2026-07-18T00:10:00+08:00';next_stage='business-delivery-acceptance'}
  $visualPath=Join-Path $session 'intermediate/r7/payloads/hotspot-delivery-review.json';Write-HotspotE2EJson $visualPath $visualReview
  $visualBuild=New-R7RuntimeSubmissionFromPayload $ProjectRoot $session ([string]$visualTask.Data.Task.task_envelope_id) $visualPath pass
  Require-HotspotE2E ($visualBuild.ExitCode-eq0) ('delivery_visual_review_build_failed:'+([string]::Join(';',@($visualBuild.Errors))))
  $visualSubmit=Submit-R7RuntimeArtifact $ProjectRoot $session ([string]$visualBuild.Data.SubmissionPath)
  Require-HotspotE2E ($visualSubmit.ExitCode-eq0) ('delivery_visual_review_commit_failed:'+([string]::Join(';',@($visualSubmit.Errors))))
  $businessTask=Prepare-R7RuntimeTask $ProjectRoot $session
  Require-HotspotE2E ($businessTask.ExitCode-eq0-and[string]$businessTask.Data.Task.node_id-eq'business_delivery_acceptance_l3') 'business_delivery_acceptance_task_missing'
  $dimensions=@('information_hierarchy','delivery_title_quality','final_asset_binding','readiness_truthfulness','visual_human_review','action_usability')|ForEach-Object{[ordered]@{dimension_id=$_;status='pass';finding='public redacted fixture reviewed'}}
  $businessReview=[ordered]@{schema_id='taoge://schemas/r7/business-delivery-acceptance/v0.1';schema_version='0.1';business_acceptance_id='BDA-HOTSPOT-E2E-001';session_id='R7-L3-H4-HOTSPOT-E2E';final_delivery_ref=[ordered]@{artifact_id=[string]$rendered.Pointer.artifact_id;sha256=[string]$rendered.Sha256};viewport_report_ref=[ordered]@{artifact_id=[string]$viewportItem.Pointer.artifact_id;sha256=[string]$viewportItem.Sha256};html_sha256=[string]$viewportItem.Payload.html_sha256;reviewer_type='codex_visual_review';review_evidence=[ordered]@{desktop_screenshot_ref=[ordered]@{sha256=[string]$viewportItem.Payload.profiles[0].screenshot_sha256};mobile_screenshot_ref=[ordered]@{sha256=[string]$viewportItem.Payload.profiles[1].screenshot_sha256};actual_images_viewed=$true};dimensions=[object[]]$dimensions;business_delivery_status='pass';blocking_issue_codes=@();warning_codes=@();reviewed_at='2026-07-18T00:11:00+08:00';next_skill='propagation-router'}
  $businessPath=Join-Path $session 'intermediate/r7/payloads/hotspot-business-acceptance.json';Write-HotspotE2EJson $businessPath $businessReview
  $businessBuild=New-R7RuntimeSubmissionFromPayload $ProjectRoot $session ([string]$businessTask.Data.Task.task_envelope_id) $businessPath pass
  Require-HotspotE2E ($businessBuild.ExitCode-eq0) ('business_acceptance_build_failed:'+([string]::Join(';',@($businessBuild.Errors))))
  $businessSubmit=Submit-R7RuntimeArtifact $ProjectRoot $session ([string]$businessBuild.Data.SubmissionPath)
  Require-HotspotE2E ($businessSubmit.ExitCode-eq0) ('business_acceptance_commit_failed:'+([string]::Join(';',@($businessSubmit.Errors))))
  $finalGate=Prepare-R7RuntimeTask $ProjectRoot $session
  Require-HotspotE2E ($finalGate.ExitCode-eq0-and[string]$finalGate.Data.Task.node_id-eq'final_human_gate_h7') 'final_human_gate_not_waiting'
  $report=[ordered]@{schema_id='taoge://reports/r7/l3-h4-hotspot-delivery-e2e/v0.1';schema_version='0.1';fixture_set_id=[string]$fixture.fixture_set_id;result='pass';session_root=$session;route='hotspot_to_delivery_single_v0.5';final_html_path=[string]$rendered.Payload.html_path;viewport_result=[string]$viewportItem.Payload.overall_result;final_human_gate_status='waiting_human';recovery_status='resume_from_final_human_gate';network_called=$false;provider_called=$false;publishing_called=$false;automation_claim='not_certified';notes=@('Front-chain semantic artifacts are public-redacted fixture seeds in this same session.','Candidate compilation, HTML render, viewport acceptance, delivery visual review, and business acceptance execute through existing runtime contracts.','The fixture stops before final human decision; it does not publish.')}
  Write-HotspotE2EJson $ReportPath $report
  $report|ConvertTo-Json -Depth 20
}catch{Write-Error $_.Exception.Message;exit 1}
