param(
  [string]$FixturePath = 'examples/r3-visual-presentation-fixtures/fixtures.json',
  [string]$ReportPath = 'state/checks/r3-visual-presentation-report.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'R3VisualPresentation.ps1')

function Resolve-R3VPProjectPath([string]$Path) { if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }; return [IO.Path]::GetFullPath((Join-Path $projectRoot $Path)) }
function Copy-R3VPObject([object]$Value) { return ($Value | ConvertTo-Json -Depth 60 | ConvertFrom-Json) }
function Set-R3VPMutation([object]$Document,[object]$Mutation) {
  $tokens = @(([string]$Mutation.path).Split('.')); $cursor = $Document
  for ($i=0; $i -lt $tokens.Count-1; $i++) { $cursor = $cursor.($tokens[$i]) }
  $leaf = $tokens[-1]
  if (Test-R3VPHasProperty $cursor $leaf) { $cursor.$leaf = $Mutation.value } else { $cursor | Add-Member -NotePropertyName $leaf -NotePropertyValue $Mutation.value }
}
function Add-R3VPResult($List,[string]$Id,[string]$Expected,[string]$Actual,[object[]]$Errors,[string]$Evidence) {
  $List.Add([ordered]@{fixture_id=$Id;expected_result=$Expected;actual_result=$Actual;expectation_met=($Expected -eq $Actual);errors=$Errors;evidence=$Evidence})
}
function New-R3VPSyntheticImage([string]$Path) {
  Add-Type -AssemblyName System.Drawing
  $parent = Split-Path -Parent $Path; if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  $bitmap = New-Object System.Drawing.Bitmap(1600,900,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $brushes = @()
  try {
    $graphics.Clear([System.Drawing.Color]::FromArgb(25,35,55))
    $colors = @([System.Drawing.Color]::FromArgb(190,65,75),[System.Drawing.Color]::FromArgb(36,160,120),[System.Drawing.Color]::FromArgb(232,170,55),[System.Drawing.Color]::FromArgb(70,110,210))
    for ($i=0; $i -lt 4; $i++) { $brush = New-Object System.Drawing.SolidBrush($colors[$i]); $brushes += $brush; $graphics.FillRectangle($brush,100+($i*375),250,280,400) }
    $bitmap.Save($Path,[System.Drawing.Imaging.ImageFormat]::Png)
  } finally { foreach ($brush in $brushes) { $brush.Dispose() }; $graphics.Dispose(); $bitmap.Dispose() }
}
function Invoke-R3VPChild([string]$ScriptPath,[object[]]$Arguments,[string]$Stdout,[string]$Stderr) {
  $powershell = (Get-Command powershell.exe).Source
  $process = Start-TaogeProcess -FilePath $powershell -Arguments (@('-NoProfile','-ExecutionPolicy','Bypass','-File',$ScriptPath) + $Arguments) -StandardOutputPath $Stdout -StandardErrorPath $Stderr -WorkingDirectory $projectRoot -Wait -Hidden
  return [pscustomobject]@{ExitCode=$process.ExitCode;Stdout=$(if(Test-Path -LiteralPath $Stdout){Get-Content -LiteralPath $Stdout -Raw -Encoding UTF8}else{''});Stderr=$(if(Test-Path -LiteralPath $Stderr){Get-Content -LiteralPath $Stderr -Raw -Encoding UTF8}else{''})}
}

try {
  $fixtureFull = Resolve-R3VPProjectPath $FixturePath
  $fixture = Get-Content -LiteralPath $fixtureFull -Raw -Encoding UTF8 | ConvertFrom-Json
  $results = [System.Collections.Generic.List[object]]::new()
  foreach ($case in @($fixture.cases)) {
    if (Test-R3VPHasProperty $case 'expected_scope_status') {
      $actual = Get-R3PlatformDeliveryScopeStatus @($case.platform_units)
      Add-R3VPResult $results ([string]$case.fixture_id) ([string]$case.expected_scope_status) $actual @() $fixtureFull
      continue
    }
    if (Test-R3VPHasProperty $case 'visual_insert') {
      $errors = @(Test-R3VisualInsertTask $case.visual_insert)
      $actual = if ($errors.Count) { 'fail_visual_insert' } else { 'pass_visual_insert' }
      Add-R3VPResult $results ([string]$case.fixture_id) ([string]$case.expected_result) $actual $errors $fixtureFull
      continue
    }
    $plan = Copy-R3VPObject $fixture.template
    foreach ($mutation in @($case.mutations)) { Set-R3VPMutation $plan $mutation }
    $errors = @(Test-R3CoverRenderPlan $plan)
    $actual = if ($errors.Count) { 'fail' } else { 'pass' }
    Add-R3VPResult $results ([string]$case.fixture_id) ([string]$case.expected_result) $actual $errors $fixtureFull
  }

  $work = Join-Path $projectRoot 'state/checks/r3-visual-presentation-work'
  if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
  New-Item -ItemType Directory -Path (Join-Path $work 'assets') -Force | Out-Null
  New-R3VPSyntheticImage (Join-Path $work 'assets/source-landscape.png')
  $runtimePlan = Copy-R3VPObject $fixture.template
  $runtimePlanPath = Join-Path $work 'cover-render-plan.json'
  Write-TaogeUtf8NoBomJson -Path $runtimePlanPath -Value $runtimePlan -Depth 50
  $composeOut = Join-Path $work 'compose.stdout.log'; $composeErr = Join-Path $work 'compose.stderr.log'
  $compose = Invoke-R3VPChild (Join-Path $projectRoot 'skills/cover-design-compiler/scripts/compose-cover-v0.2.ps1') @('-SessionRoot',$work,'-PlanPath','cover-render-plan.json') $composeOut $composeErr
  $composeErrors = [System.Collections.Generic.List[string]]::new()
  if ($compose.ExitCode -ne 0) { $composeErrors.Add('compose_exit_nonzero:' + $compose.Stderr) }
  $recordPath = Join-Path $work 'assets/output-cover.record.json'
  if (-not (Test-Path -LiteralPath $recordPath)) { $composeErrors.Add('compose_record_missing') }
  if ($composeErrors.Count -eq 0) {
    $record = Get-Content -LiteralPath $recordPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($error in (Test-R3CoverCompositionRecord $record $runtimePlan)) { $composeErrors.Add($error) }
    if ($record.cover_delivery_status -ne 'waiting_visual_review') { $composeErrors.Add('composer_illegally_self_approved_visual_gate') }
  }
  Add-R3VPResult $results 'R3VP-014-compose-runtime-smoke' 'pass' $(if($composeErrors.Count){'fail'}else{'pass'}) @($composeErrors.ToArray()) $composeOut

  $reviewOut = Join-Path $work 'review.stdout.log'; $reviewErr = Join-Path $work 'review.stderr.log'
  $review = Invoke-R3VPChild (Join-Path $projectRoot 'skills/cover-design-compiler/scripts/record-cover-visual-review.ps1') @('-SessionRoot',$work,'-CompositionRecordPath','assets/output-cover.record.json','-ReviewRecordPath','assets/output-cover.review.json','-ReviewerType','codex_visual_review','-ReviewScope','fixture_only','-VisualReviewStatus','pass','-ReviewStatement','Fixture-only raster review; not valid for a real delivery.') $reviewOut $reviewErr
  $reviewErrors = [System.Collections.Generic.List[string]]::new()
  if ($review.ExitCode -ne 0) { $reviewErrors.Add('review_exit_nonzero:' + $review.Stderr) }
  $reviewPath = Join-Path $work 'assets/output-cover.review.json'
  if (-not (Test-Path -LiteralPath $reviewPath)) { $reviewErrors.Add('review_record_missing') }
  if ($reviewErrors.Count -eq 0) { $reviewRecord = Get-Content -LiteralPath $reviewPath -Raw -Encoding UTF8 | ConvertFrom-Json; foreach ($error in (Test-R3CoverVisualReviewRecord $reviewRecord $record)) { $reviewErrors.Add($error) } }
  Add-R3VPResult $results 'R3VP-015-explicit-review-runtime-smoke' 'pass' $(if($reviewErrors.Count){'fail'}else{'pass'}) @($reviewErrors.ToArray()) $reviewOut
  $reviewReuseOut = Join-Path $work 'review-reuse.stdout.log'; $reviewReuseErr = Join-Path $work 'review-reuse.stderr.log'
  $reviewReuse = Invoke-R3VPChild (Join-Path $projectRoot 'skills/cover-design-compiler/scripts/record-cover-visual-review.ps1') @('-SessionRoot',$work,'-CompositionRecordPath','assets/output-cover.record.json','-ReviewRecordPath','assets/output-cover.review.json','-ReviewerType','codex_visual_review','-ReviewScope','fixture_only','-VisualReviewStatus','pass','-ReviewStatement','Fixture-only raster review; not valid for a real delivery.') $reviewReuseOut $reviewReuseErr
  $reviewReuseActual = if ($reviewReuse.ExitCode -eq 0 -and $reviewReuse.Stdout -match 'COVER_VISUAL_REVIEW_STATUS=skipped_reused') { 'pass' } else { 'fail' }
  Add-R3VPResult $results 'R3VP-015B-review-idempotent-reuse' 'pass' $reviewReuseActual @($(if($reviewReuseActual-eq'fail'){"review_idempotency_failed:$($reviewReuse.Stderr)"})) $reviewReuseOut

  $badWork = Join-Path $projectRoot 'state/checks/r3-visual-presentation-bad-crop-work'
  if (Test-Path -LiteralPath $badWork) { Remove-Item -LiteralPath $badWork -Recurse -Force }
  New-Item -ItemType Directory -Path (Join-Path $badWork 'assets') -Force | Out-Null
  New-R3VPSyntheticImage (Join-Path $badWork 'assets/source-landscape.png')
  $badPlan = Copy-R3VPObject $fixture.template
  $badPlan.protected_regions[0].x = 0.03; $badPlan.protected_regions[0].width = 0.2
  Write-TaogeUtf8NoBomJson -Path (Join-Path $badWork 'cover-render-plan.json') -Value $badPlan -Depth 50
  $bad = Invoke-R3VPChild (Join-Path $projectRoot 'skills/cover-design-compiler/scripts/compose-cover-v0.2.ps1') @('-SessionRoot',$badWork,'-PlanPath','cover-render-plan.json') (Join-Path $badWork 'compose.stdout.log') (Join-Path $badWork 'compose.stderr.log')
  $badActual = if ($bad.ExitCode -ne 0 -and -not (Test-Path -LiteralPath (Join-Path $badWork 'assets/output-cover.png')) -and $bad.Stderr -match 'destructive_crop_protected_region') { 'pass' } else { 'fail' }
  Add-R3VPResult $results 'R3VP-016-destructive-crop-blocked-before-output' 'pass' $badActual @($(if($badActual-eq'fail'){'destructive_crop_false_success'})) (Join-Path $badWork 'compose.stderr.log')

  $coverage = @(
    @{id='R3VP-COVERAGE-DICTIONARY';path='交接物字段词典.md';tokens=@('visual_insert','cover_rendition','deterministic_surface_mock','primary_ready_secondary_pending','codex_visual_review')},
    @{id='R3VP-COVERAGE-ORCHESTRATOR';path='skills/talking-head-image-pip/SKILL.md';tokens=@('structure-bound beat map','Dispatch every accepted task by disposition','generate_visual','use_existing_asset','all accepted Image 2 tasks run')},
    @{id='R3VP-COVERAGE-COVER-SKILL';path='skills/cover-design-compiler/SKILL.md';tokens=@('compose-cover-v0.2.ps1','record-cover-visual-review.ps1','waiting_visual_review','focal_crop')},
    @{id='R3VP-COVERAGE-PROMPT';path='skills/image-prompt-compiler/SKILL.md';tokens=@('presentation_mode','target canvas','placement_slot')},
    @{id='R3VP-COVERAGE-ASSET';path='skills/image-asset-producer/SKILL.md';tokens=@('actual_width_px','aspect_ratio_verification_status','visual_insert')},
    @{id='R3VP-COVERAGE-H7';path='skills/final-delivery-builder/SKILL.md';tokens=@('Current v0.6 Contract','typed_components_v0.6','per-rendition cover review','v0.1-v0.5 are read-only replay')},
    @{id='R3VP-COVERAGE-SCHEMA';path='templates/schema/r3/cover-render-plan.v0.1.schema.json';tokens=@('protected_regions','adaptation_strategy','visual_review_record_path')}
  )
  foreach ($item in $coverage) {
    $full = Join-Path $projectRoot $item.path; $missing = @()
    if (-not (Test-Path -LiteralPath $full)) { $missing = @('file_missing') } else { $text = Get-Content -LiteralPath $full -Raw -Encoding UTF8; $missing = @($item.tokens | Where-Object { -not $text.Contains($_) }) }
    Add-R3VPResult $results $item.id 'pass' $(if($missing.Count){'fail'}else{'pass'}) @($missing | ForEach-Object { "coverage_token_missing:$_" }) $item.path
  }

  $failed = @($results | Where-Object { -not $_.expectation_met }); $overall = if ($failed.Count) { 'fail' } else { 'pass' }
  $report = [ordered]@{schema_id='taoge://reports/r3/visual-presentation/v0.1';schema_version='0.1';generated_at=[DateTimeOffset]::UtcNow.ToString('o');overall_result=$overall;case_count=$results.Count;failure_count=$failed.Count;external_provider_called=$false;platform_login_used=$false;publishing_executed=$false;results=[object[]]$results.ToArray()}
  $reportFull = Resolve-R3VPProjectPath $ReportPath; Write-TaogeUtf8NoBomJson -Path $reportFull -Value $report -Depth 60
  Write-Output "R3_VISUAL_PRESENTATION_CHECK=$overall"; Write-Output "CASE_COUNT=$($results.Count)"; Write-Output "FAILURE_COUNT=$($failed.Count)"; Write-Output "REPORT=$reportFull"
  if ($failed.Count) { foreach ($failure in $failed) { Write-Output "ERROR=$($failure.fixture_id):$([string]::Join(',',@($failure.errors)))" }; exit 1 }
  exit 0
} catch { Write-Error ('R3_VISUAL_PRESENTATION_CHECKER_ERROR=' + $_.Exception.Message); exit 3 }
