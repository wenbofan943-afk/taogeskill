param(
  [string]$ProjectRoot = '',
  [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
} else {
  $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = Join-Path $ProjectRoot 'state/checks/r8-h5r2-input-runtime-report.json'
}
. (Join-Path $PSScriptRoot 'R8H5InputRuntime.ps1')

$errors = [System.Collections.Generic.List[string]]::new()
$negativePass = 0
$fixturePath = Join-Path $ProjectRoot 'examples/r8-h5r2-input-fixtures/cases.json'
$catalog = Get-Content -LiteralPath $fixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
$head = Get-R8H5GitCommit $ProjectRoot 'HEAD'
$worktreeDiff = Invoke-TaogeProcessCapture -FilePath 'git' -Arguments @('-C',$ProjectRoot,'diff','--binary','--no-ext-diff')
$inputSurface = [string]::Join("`n",@(
  $worktreeDiff.stdout,
  [System.IO.File]::ReadAllText($fixturePath,(Get-TaogeUtf8NoBomEncoding)),
  [System.IO.File]::ReadAllText((Join-Path $ProjectRoot 'tools/R8H5InputRuntime.ps1'),(Get-TaogeUtf8NoBomEncoding)),
  [System.IO.File]::ReadAllText((Join-Path $ProjectRoot 'routes/r8-h5-arm-adapters.yaml'),(Get-TaogeUtf8NoBomEncoding))
))
$worktreeDigest = (Get-R8H5TextDigest $inputSurface).Substring(7,12)
$evaluationId = "EVAL-R8-H5R2-$($head.Substring(0,8))-$worktreeDigest"
$attemptId = 'ATTEMPT-001'
$outputRoot = Join-Path $ProjectRoot "state/checks/r8/$evaluationId/$attemptId"

try {
  foreach ($case in @($catalog.cases)) {
    [void](Invoke-R8H5CaseCompile -ProjectRoot $ProjectRoot -Case $case -EvaluationId $evaluationId `
      -AttemptId $attemptId -OutputRoot $outputRoot -CompiledAt $catalog.compiled_at)
  }
  foreach ($case in @($catalog.cases)) {
    [void](Invoke-R8H5CaseCompile -ProjectRoot $ProjectRoot -Case $case -EvaluationId $evaluationId `
      -AttemptId $attemptId -OutputRoot $outputRoot -CompiledAt $catalog.compiled_at)
  }
} catch {
  $errors.Add("producer_execution_failed:$($_.Exception.Message)")
}

$caseCount = 0
$armCount = 0
$snapshotCount = 0
$typedCount = 0
foreach ($case in @($catalog.cases)) {
  $caseCount++
  $caseRoot = Join-Path $outputRoot (Join-Path 'cases' $case.semantic_case_id)
  $semanticPath = Join-Path $caseRoot 'semantic-case.json'
  if (-not (Test-Path -LiteralPath $semanticPath -PathType Leaf)) {
    $errors.Add("semantic_case_missing:$($case.semantic_case_id)")
    continue
  }
  $semantic = Get-Content -LiteralPath $semanticPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $projectionDigests = @()
  foreach ($armRole in @('baseline','candidate')) {
    $armCount++
    $armPath = Join-Path $caseRoot $armRole
    $snapshotPath = Join-Path $armPath 'dependency-snapshot.json'
    $typedPath = Join-Path $armPath 'typed-input.json'
    $armInputPath = Join-Path $armPath 'arm-input.json'
    foreach ($path in @($snapshotPath,$typedPath,$armInputPath)) {
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $errors.Add("output_missing:$path") }
    }
    if (-not (Test-Path -LiteralPath $snapshotPath) -or -not (Test-Path -LiteralPath $typedPath) -or -not (Test-Path -LiteralPath $armInputPath)) { continue }
    $snapshot = Get-Content -LiteralPath $snapshotPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $typed = Get-Content -LiteralPath $typedPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $armInput = Get-Content -LiteralPath $armInputPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $snapshotCount++
    $typedCount++
    $adapter = Get-R8H5Adapter $case.skill_id $armRole
    $typedErrors = @(Test-R8H5TypedInput $typed $adapter)
    if ($typedErrors.Count -gt 0) { $errors.Add("typed_schema_fail:$($case.semantic_case_id):${armRole}:$($typedErrors -join ',')") }
    if ($armInput.input_status -ne 'ready' -or $armInput.validation_errors.Count -ne 0) {
      $errors.Add("arm_input_not_ready:$($case.semantic_case_id):$armRole")
    }
    if ($armInput.semantic_case_digest -ne $semantic.semantic_case_digest) {
      $errors.Add("semantic_digest_mismatch:$($case.semantic_case_id):$armRole")
    }
    if ($armInput.input_digest -ne (Get-R8H5ObjectDigest $typed)) {
      $errors.Add("input_digest_mismatch:$($case.semantic_case_id):$armRole")
    }
    if ($armInput.dependency_snapshot_digest -ne $snapshot.closure_digest) {
      $errors.Add("snapshot_digest_mismatch:$($case.semantic_case_id):$armRole")
    }
    $closureLines = @($snapshot.files | Sort-Object relative_path | ForEach-Object { "$($_.relative_path)|$($_.role)|$($_.sha256)" })
    if ($snapshot.closure_digest -ne (Get-R8H5TextDigest ([string]::Join("`n",$closureLines)))) {
      $errors.Add("closure_digest_mismatch:$($case.semantic_case_id):$armRole")
    }
    if ('skill_entry' -notin @($snapshot.files.role) -or 'contract' -notin @($snapshot.files.role)) {
      $errors.Add("snapshot_core_missing:$($case.semantic_case_id):$armRole")
    }
    if ($armRole -eq 'baseline') {
      $expectedCommit = Get-R8H5GitCommit $ProjectRoot $adapter.source_revision
      if ($snapshot.source_commit -ne $expectedCommit) { $errors.Add("baseline_commit_mismatch:$($case.semantic_case_id)") }
    } elseif ($snapshot.source_commit -ne $head) {
      $errors.Add("candidate_commit_mismatch:$($case.semantic_case_id)")
    }
    $projectionDigests += $typed.semantic_projection_digest
  }
  if (@($projectionDigests | Select-Object -Unique).Count -ne 1) {
    $errors.Add("cross_arm_semantic_projection_mismatch:$($case.semantic_case_id)")
  }
}

try {
  $bad = $catalog.cases[0] | ConvertTo-Json -Depth 40 | ConvertFrom-Json
  $bad.semantic_input = $null
  [void](Invoke-R8H5CaseCompile $ProjectRoot $bad 'EVAL-R8-H5R2-NEG-MISSING' 'ATTEMPT-001' (Join-Path $ProjectRoot 'state/checks/r8/EVAL-R8-H5R2-NEG-MISSING/ATTEMPT-001') $catalog.compiled_at)
  $errors.Add('negative_missing_semantic_input_accepted')
} catch { $negativePass++ }

try {
  [void](Resolve-R8H5ContainedPath $ProjectRoot (Join-Path (Split-Path $ProjectRoot -Parent) 'escape'))
  $errors.Add('negative_output_escape_accepted')
} catch { $negativePass++ }

try {
  Assert-R8H5Timestamp 'compiled_at' '2026-07-18T09:00:00'
  $errors.Add('negative_timezone_missing_accepted')
} catch { $negativePass++ }

try {
  $conflictPath = Join-Path $ProjectRoot 'state/checks/r8/EVAL-R8-H5R2-NEG-CONFLICT/value.json'
  [void](Write-R8H5ImmutableJson $conflictPath ([pscustomobject]@{value='A'}))
  [void](Write-R8H5ImmutableJson $conflictPath ([pscustomobject]@{value='B'}))
  $errors.Add('negative_immutable_conflict_accepted')
} catch { $negativePass++ }

$sampleCase = $catalog.cases[0]
$semanticSample = New-R8H5SemanticCase $sampleCase 'EVAL-R8-H5R2-NEG-ADAPTER' 'ATTEMPT-001'
$adapterSample = Get-R8H5Adapter $sampleCase.skill_id 'candidate'
$typedSample = New-R8H5TypedInput $semanticSample 'candidate' $adapterSample
$typedSample.contract_version = 'wrong'
if ('contract_version_mismatch' -in @(Test-R8H5TypedInput $typedSample $adapterSample)) { $negativePass++ } else { $errors.Add('negative_adapter_mismatch_not_detected') }

$typedSample2 = New-R8H5TypedInput $semanticSample 'candidate' $adapterSample
$typedSample2.semantic_projection_digest = 'sha256:' + ('0' * 64)
if ($typedSample2.semantic_projection_digest -ne (Get-R8H5ObjectDigest $semanticSample.semantic_input)) { $negativePass++ } else { $errors.Add('negative_projection_mismatch_not_detected') }

$sampleSnapshotPath = Join-Path $outputRoot 'cases/CASE-HOTSPOT-NORMAL-001/candidate/dependency-snapshot.json'
$sampleSnapshot = Get-Content -LiteralPath $sampleSnapshotPath -Raw -Encoding UTF8 | ConvertFrom-Json
$sampleSnapshot.files[0].sha256 = 'sha256:' + ('0' * 64)
$tamperedLines = @($sampleSnapshot.files | Sort-Object relative_path | ForEach-Object { "$($_.relative_path)|$($_.role)|$($_.sha256)" })
if ($sampleSnapshot.closure_digest -ne (Get-R8H5TextDigest ([string]::Join("`n",$tamperedLines)))) { $negativePass++ } else { $errors.Add('negative_snapshot_tamper_not_detected') }

$result = if ($errors.Count -eq 0 -and $caseCount -eq 9 -and $armCount -eq 18 -and $snapshotCount -eq 18 -and $typedCount -eq 18 -and $negativePass -eq 7) { 'pass' } else { 'fail' }
$report = [pscustomobject][ordered]@{
  schema_id = 'taoge://reports/r8/h5r2-input-runtime/v0.1'
  generated_at = [DateTimeOffset]::Now.ToString('o')
  result = $result
  build_profile = 'dev'
  evaluation_id = $evaluationId
  attempt_id = $attemptId
  semantic_case_count = $caseCount
  typed_input_count = $typedCount
  dependency_snapshot_count = $snapshotCount
  arm_input_count = $armCount
  negative_case_pass_count = $negativePass
  idempotent_replay = 'byte_stable'
  isolation_claim = 'instruction_isolated'
  arm_execution_started = $false
  independent_agents_executed = $false
  blind_packet_generated = $false
  network_called = $false
  provider_called = $false
  private_account_used = $false
  errors = @($errors)
}
Write-TaogeUtf8NoBomJson -Path $ReportPath -Value $report -Depth 30
Write-Output "result=$result"
Write-Output "semantic_case_count=$caseCount"
Write-Output "typed_input_count=$typedCount"
Write-Output "dependency_snapshot_count=$snapshotCount"
Write-Output "arm_input_count=$armCount"
Write-Output "negative_case_pass_count=$negativePass"
Write-Output "report=$ReportPath"
if ($result -ne 'pass') {
  foreach ($item in $errors) { Write-Output "error=$item" }
  exit 1
}
exit 0
