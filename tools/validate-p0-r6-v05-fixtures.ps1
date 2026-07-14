param([string]$ReportPath)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'P0ContractHelper.ps1')

function Copy-P0V5Object { param([object]$Value) return (($Value | ConvertTo-Json -Depth 80) | ConvertFrom-Json) }
function Add-P0V5Case { param([object]$Results,[string]$CaseId,[bool]$Pass,[object]$Evidence) $Results.Add([ordered]@{case_id=$CaseId;status=$(if($Pass){'pass'}else{'fail'});evidence=$Evidence}) }

$project = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $project 'examples/p0-runtime-v0.5-fixture'
$candidatePath = Join-Path $fixture 'deliverables/p0/final-delivery-render-candidate.json'
$base = Get-Content -LiteralPath $candidatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$results = [System.Collections.Generic.List[object]]::new()

$baseErrors = @(Test-P0RenderInputContract (Copy-P0V5Object $base))
Add-P0V5Case $results 'valid_candidate' ($baseErrors.Count -eq 0) $baseErrors

$cases = @(
  @('structure_order_gap','structure_stage_v05_order_gap'),
  @('beat_stage_missing','beat_card_v05_stage_missing'),
  @('beat_duplicate','beat_card_v05_duplicate'),
  @('script_readiness_mismatch','script_readiness_v05_mismatch'),
  @('coverage_false_complete','visual_coverage_v05_false_complete'),
  @('derived_count_wrong','visual_count_v05_mismatch:derived_visual_asset_count'),
  @('provider_attempt_on_existing','visual_task_v05_provider_attempt_invalid'),
  @('reused_capture_attempt','visual_task_v05_reused_capture_attempt_invalid'),
  @('occurrence_count_wrong','visual_count_v05_mismatch:visual_insert_occurrence_count'),
  @('zero_false_ready','beat_card_v05_task_unknown'),
  @('alignment_mismatch','alignment_status_v05_mismatch'),
  @('trace_insufficient','trace_cards_v05_insufficient')
)
foreach ($case in $cases) {
  $copy = Copy-P0V5Object $base
  switch ($case[0]) {
    'structure_order_gap' { $copy.content_structure_card.stages[1].order = 3 }
    'beat_stage_missing' { $copy.content_beat_cards[1].stage_id = 'STAGE-MISSING' }
    'beat_duplicate' { $copy.content_beat_cards[1].beat_id = $copy.content_beat_cards[0].beat_id }
    'script_readiness_mismatch' { $copy.production_status.script_readiness = 'blocked' }
    'coverage_false_complete' { $copy.visual_coverage_summary.unresolved_beat_ids = @('BEAT-H7-V05-002') }
    'derived_count_wrong' { $copy.visual_coverage_summary.counts.derived_visual_asset_count = 2 }
    'provider_attempt_on_existing' { $copy.visual_coverage_summary.task_summaries[0].provider_attempt_count = 1; $copy.visual_coverage_summary.counts.provider_generation_attempt_count = 1 }
    'reused_capture_attempt' { $task=$copy.visual_coverage_summary.task_summaries[0]; $task.disposition='use_source_evidence'; $task.capture_mode='reuse_verified_capture'; $task.source_capture_attempt_count=1; $copy.visual_coverage_summary.counts.source_capture_attempt_count=1 }
    'occurrence_count_wrong' { $copy.visual_coverage_summary.counts.visual_insert_occurrence_count = 2 }
    'zero_false_ready' { $copy.visual_coverage_summary.task_summaries=@(); $copy.visual_coverage_summary.counts.derived_visual_asset_count=0; $copy.visual_coverage_summary.counts.materialized_visual_asset_count=0 }
    'alignment_mismatch' { $copy.production_status.alignment_status = 'needs_visual_revision' }
    'trace_insufficient' { $copy.trace_cards = @($copy.trace_cards | Select-Object -First 8) }
  }
  $errors = @(Test-P0RenderInputContract $copy)
  $matched = @($errors | Where-Object { [string]$_ -like ('*' + $case[1] + '*') }).Count -gt 0
  Add-P0V5Case $results $case[0] $matched $errors
}

$work = Join-Path $project ('state/checks/p0-r6-v05-' + [guid]::NewGuid().ToString('N').Substring(0,8))
Copy-Item -LiteralPath $fixture -Destination $work -Recurse
$entry = Join-Path $PSScriptRoot 'invoke-workflow-runtime.ps1'
$compileOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entry -SessionPath $work -Mode compile_render_input)
$compileExit = $LASTEXITCODE
$renderOutput = @(); $renderExit = 1
if ($compileExit -eq 0) { $renderOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entry -SessionPath $work -Mode render_final_delivery); $renderExit = $LASTEXITCODE }
$htmlPath = Join-Path $work 'deliverables/final-delivery.html'
$renderPass = $compileExit -eq 0 -and $renderExit -eq 0 -and (Test-Path -LiteralPath $htmlPath)
if ($renderPass) {
  $html = Get-Content -LiteralPath $htmlPath -Raw -Encoding UTF8
  foreach ($token in @('data-template-version="0.5.0"','id="content-structure"','id="script-review"','id="visual-coverage"','talking_head_intentional','use_existing_asset')) { if ($html -notmatch [regex]::Escape($token)) { $renderPass = $false } }
  if ($html -match '\{\{[^}]+\}\}' -or $html -match '(?is)<\s*script\b|javascript\s*:') { $renderPass = $false }
}
Add-P0V5Case $results 'runtime_compile_render' $renderPass (@($compileOutput) + @($renderOutput))

$idempotentPass = $false
if ($renderPass) {
  $firstHash = Get-TaogeFileSha256 -Path $htmlPath
  $second = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entry -SessionPath $work -Mode render_final_delivery)
  $secondExit = $LASTEXITCODE
  $idempotentPass = $secondExit -eq 0 -and (@($second | Where-Object { $_ -eq 'WORKFLOW_RUNTIME_RESULT=skipped_reused' }).Count -eq 1) -and $firstHash -eq (Get-TaogeFileSha256 -Path $htmlPath)
  Add-P0V5Case $results 'runtime_idempotent_reuse' $idempotentPass $second
} else { Add-P0V5Case $results 'runtime_idempotent_reuse' $false @('render prerequisite failed') }

$receiptPass = $false
if ($renderPass) {
  $receipt = Get-Content -LiteralPath (Join-Path $work 'deliverables/p0/render-receipt.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $manifest = Get-Content -LiteralPath (Join-Path $work 'deliverables/p0/delivery-revision.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $receiptPass = $receipt.schema_version -eq '0.5' -and $receipt.renderer_version -eq 'final-delivery-renderer-v0.5' -and $manifest.schema_version -eq '0.5' -and $manifest.revision_status -eq 'current'
}
Add-P0V5Case $results 'revision_marker_last' $receiptPass @($work)

$failed = @($results | Where-Object { $_.status -ne 'pass' })
$report = [ordered]@{schema_version='0.1';checker='validate-p0-r6-v05-fixtures';generated_at=[DateTimeOffset]::UtcNow.ToString('o');work_root=$work;case_count=$results.Count;pass_count=$results.Count-$failed.Count;fail_count=$failed.Count;result=$(if($failed.Count){'fail'}else{'pass'});cases=[object[]]$results.ToArray()}
if (-not [string]::IsNullOrWhiteSpace($ReportPath)) { Write-TaogeUtf8NoBomJson -Path $ReportPath -Value $report -Depth 50 }
Write-Output ('P0_R6_V05_FIXTURE_RESULT=' + $report.result)
Write-Output ('P0_R6_V05_FIXTURE_CASES=' + $results.Count)
Write-Output ('P0_R6_V05_WORK_ROOT=' + $work)
if ($failed.Count) { $failed | ForEach-Object { Write-Output ('P0_R6_V05_FAIL=' + $_.case_id) }; exit 1 }
