param(
  [string]$ProjectRoot = '',
  [string]$FixturePath = '',
  [string]$ReportRoot = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
if ([string]::IsNullOrWhiteSpace($FixturePath)) {
  $FixturePath = Join-Path $ProjectRoot 'examples/r8-skill-context-fixtures/h5-ab-cases.json'
}
if ([string]::IsNullOrWhiteSpace($ReportRoot)) {
  $ReportRoot = Join-Path $ProjectRoot 'state/checks/r8/R8-H5-CURRENT'
}
$ReportRoot = [System.IO.Path]::GetFullPath($ReportRoot)
$rootPrefix = $ProjectRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if (-not $ReportRoot.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'report_root_outside_project'
}

. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'YamlHelper.ps1')
. (Join-Path $PSScriptRoot 'R8PlatformPackagingRuntime.ps1')

function Get-R8H5Value {
  param([object]$Object, [string]$Name)
  if ($null -eq $Object) { return $null }
  if ($Object -is [System.Collections.IDictionary]) {
    if ($Object.Contains($Name)) { return $Object[$Name] }
    return $null
  }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Get-R8H5Items {
  param([object]$Value)
  if ($null -eq $Value) { return }
  if ($Value -is [System.Collections.IDictionary] -and $Value.Count -eq 0) { return }
  if ($Value -is [pscustomobject] -and @($Value.PSObject.Properties).Count -eq 0) { return }
  foreach ($item in @($Value)) { Write-Output $item }
}

function Get-R8H5TextDigest {
  param([string]$Text)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
  $algorithm = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hash = $algorithm.ComputeHash($bytes)
    return 'sha256:' + (([System.BitConverter]::ToString($hash)) -replace '-', '').ToLowerInvariant()
  } finally {
    $algorithm.Dispose()
  }
}

function Get-R8H5FileText {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Get-R8H5TextLineCount {
  param([string]$Text)
  if ([string]::IsNullOrEmpty($Text)) { return 0 }
  $reader = [System.IO.StringReader]::new($Text)
  $count = 0
  try {
    while ($null -ne $reader.ReadLine()) { $count++ }
  } finally {
    $reader.Dispose()
  }
  return $count
}

function Resolve-R8H5ProjectPath {
  param([string]$RelativePath)
  if ([string]::IsNullOrWhiteSpace($RelativePath) -or [System.IO.Path]::IsPathRooted($RelativePath)) {
    return $null
  }
  $full = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot ($RelativePath -replace '/', '\')))
  if (-not $full.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $null
  }
  return $full
}

function Invoke-R8H5Process {
  param(
    [string]$Id,
    [string]$FilePath,
    [object[]]$Arguments
  )
  $stdoutPath = Join-Path $ReportRoot "logs/$Id.stdout.log"
  $stderrPath = Join-Path $ReportRoot "logs/$Id.stderr.log"
  foreach ($path in @($stdoutPath, $stderrPath)) {
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) {
      New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (Test-Path -LiteralPath $path) {
      Remove-Item -LiteralPath $path -Force
    }
  }
  $watch = [System.Diagnostics.Stopwatch]::StartNew()
  $process = Start-TaogeProcess -FilePath $FilePath -Arguments $Arguments `
    -StandardOutputPath $stdoutPath -StandardErrorPath $stderrPath `
    -WorkingDirectory $ProjectRoot -Wait -Hidden
  $watch.Stop()
  $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-R8H5FileText $stdoutPath } else { '' }
  $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-R8H5FileText $stderrPath } else { '' }
  return [pscustomobject][ordered]@{
    id = $Id
    exit_code = [int]$process.ExitCode
    duration_ms = [int64]$watch.ElapsedMilliseconds
    stdout_path = $stdoutPath.Substring($ProjectRoot.Length + 1).Replace('\', '/')
    stderr_path = $stderrPath.Substring($ProjectRoot.Length + 1).Replace('\', '/')
    stdout_tail = [string]::Join("`n", @($stdout -split "`r?`n" | Select-Object -Last 8))
    stderr_tail = [string]::Join("`n", @($stderr -split "`r?`n" | Select-Object -Last 8))
  }
}

function Get-R8H5GitText {
  param([string]$Commit, [string]$Path, [string]$Id)
  $result = Invoke-R8H5Process -Id "git-$Id" -FilePath 'git.exe' `
    -Arguments @('-C', $ProjectRoot, 'show', "${Commit}:$Path")
  if ($result.exit_code -ne 0) {
    throw "baseline_git_show_failed:$Commit`:$Path`:$($result.stderr_tail)"
  }
  $outputPath = Join-Path $ProjectRoot ($result.stdout_path -replace '/', '\')
  return Get-R8H5FileText $outputPath
}

function Test-R8H5Clause {
  param([string]$Clause, [object]$Context)
  $match = [regex]::Match($Clause.Trim(), '^(contract_version|node_id|status|mode|target_platforms)\s*(==|!=|contains|in)\s*(.+)$')
  if (-not $match.Success) { return $false }
  $name = $match.Groups[1].Value
  $actualValue = Get-R8H5Value $Context $name
  $operator = $match.Groups[2].Value
  $expected = @($match.Groups[3].Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  if ($operator -eq 'contains') {
    $actualItems = @(Get-R8H5Items $actualValue | ForEach-Object { [string]$_ })
    return @($actualItems | Where-Object { $_ -in $expected }).Count -gt 0
  }
  $actual = [string]$actualValue
  switch ($operator) {
    '==' { return $expected.Count -eq 1 -and $actual -eq $expected[0] }
    '!=' { return $expected.Count -eq 1 -and $actual -ne $expected[0] }
    'in' { return $actual -in $expected }
  }
  return $false
}

function Test-R8H5Condition {
  param([string]$Condition, [object]$Context)
  foreach ($clause in @($Condition -split '\s*&&\s*')) {
    if (-not (Test-R8H5Clause $clause $Context)) { return $false }
  }
  return $true
}

function New-R8H5PlatformPayload {
  param([object]$Context, [string]$PromptId)
  $packages = @()
  foreach ($platform in @(Get-R8H5Items (Get-R8H5Value $Context 'package_platforms'))) {
    $packages += [pscustomobject][ordered]@{
      platform = [string]$platform
      title = "fixture-$platform"
      cover_title = "fixture-$platform"
      body_text = 'Synthetic body'
      hashtags = @('fixture')
      notes = @('manual')
    }
  }
  return [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r7/platform-package/v0.2'
    schema_version = '0.2'
    platform_package_id = "PK-$PromptId"
    delivery_title = 'Synthetic delivery'
    draft_ref = [pscustomobject]@{}
    primary_platform = [string](Get-R8H5Value $Context 'primary_platform')
    packages = [object[]]$packages
    package_status = 'package_pass'
    next_skill = 'cover-design-compiler'
  }
}

if (Test-Path -LiteralPath $ReportRoot) {
  Remove-Item -LiteralPath $ReportRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null

$fixture = Get-Content -LiteralPath $FixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
$registry = Read-YamlFile (Join-Path $ProjectRoot 'routes/r8-skill-context-registry.yaml')
$nodeRegistry = Read-YamlFile (Join-Path $ProjectRoot 'routes/r7-node-registry.yaml')
$platformSchema = Get-Content -LiteralPath (Join-Path $ProjectRoot 'templates/schema/r7/platform-package.v0.2.schema.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$supportedPlatforms = @($platformSchema.properties.primary_platform.enum | ForEach-Object { [string]$_ })

$skillSnapshots = @{}
foreach ($skillFixture in @($fixture.skills)) {
  $skillId = [string]$skillFixture.skill_id
  $candidatePath = Resolve-R8H5ProjectPath ([string]$skillFixture.skill_path)
  if ($null -eq $candidatePath -or -not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
    throw "candidate_skill_missing:$skillId"
  }
  $baselineText = Get-R8H5GitText ([string]$skillFixture.baseline_commit) ([string]$skillFixture.skill_path) $skillId
  $candidateText = Get-R8H5FileText $candidatePath
  $registrySkill = @(Get-R8H5Items (Get-R8H5Value $registry 'skills') | Where-Object {
    [string](Get-R8H5Value $_ 'skill_id') -eq $skillId
  }) | Select-Object -First 1
  if ($null -eq $registrySkill) { throw "registry_skill_missing:$skillId" }
  $skillSnapshots[$skillId] = [pscustomobject][ordered]@{
    fixture = $skillFixture
    registry = $registrySkill
    baseline_text = $baselineText
    candidate_text = $candidateText
    baseline_digest = Get-R8H5TextDigest $baselineText
    candidate_digest = Get-R8H5TextDigest $candidateText
    baseline_line_count = Get-R8H5TextLineCount $baselineText
    candidate_line_count = [System.IO.File]::ReadAllLines($candidatePath).Count
  }
}

$records = [System.Collections.Generic.List[object]]::new()
foreach ($case in @($fixture.cases)) {
  $watch = [System.Diagnostics.Stopwatch]::StartNew()
  $skillId = [string]$case.skill_id
  $snapshot = $skillSnapshots[$skillId]
  $context = $case.input_context
  $conditional = @(Get-R8H5Items (Get-R8H5Value $snapshot.registry 'conditional_references'))
  $loaded = @($conditional | Where-Object {
    Test-R8H5Condition ([string](Get-R8H5Value $_ 'load_when')) $context
  } | ForEach-Object {
    [string](Get-R8H5Value $_ 'reference_id')
  } | Sort-Object)
  $expectedReferences = @($case.expected_references | ForEach-Object { [string]$_ } | Sort-Object)

  $contractVersion = [string](Get-R8H5Value $context 'contract_version')
  $mode = [string](Get-R8H5Value $context 'mode')
  $legacyLoaded = (
    $contractVersion -in @('r1', 'r2', 'r5') -and
    $mode -in @('legacy', 'replay')
  )
  $actualNodeId = $null
  $contractResult = 'fail'
  $schemaGate = 'not_applicable'

  if ($skillId -eq 'hotspot-topic-research') {
    if ($contractVersion -eq 'r7' -and [string](Get-R8H5Value $context 'node_id') -eq 'hotspot_research') {
      $actualNodeId = 'hotspot_research'
      $contractResult = 'pass'
      $schemaGate = 'pass'
    }
  } elseif ($skillId -eq 'propagation-router') {
    if ([string](Get-R8H5Value $context 'task_type') -eq 'content_run' -and
        -not [string]::IsNullOrWhiteSpace([string](Get-R8H5Value $context 'current_node_id'))) {
      $actualNodeId = [string](Get-R8H5Value $context 'current_node_id')
      $contractResult = 'pass'
      $schemaGate = 'pass'
    }
  } elseif ($skillId -eq 'platform-packaging-adapter') {
    $targets = @(Get-R8H5Items (Get-R8H5Value $context 'target_platforms') | ForEach-Object { [string]$_ })
    $accountSnapshot = [pscustomobject][ordered]@{
      captured_fields = [pscustomobject][ordered]@{
        publishing_platforms = [object[]]$targets
      }
    }
    $payload = New-R8H5PlatformPayload $context ([string]$case.prompt_id)
    $platformErrors = @(Test-R8PlatformPackageTargetContract -Payload $payload -AccountSnapshot $accountSnapshot -SupportedPlatforms $supportedPlatforms)
    if ($platformErrors.Count -eq 0) {
      $actualNodeId = [string](Get-R8H5Value $context 'node_id')
      $contractResult = 'pass'
      $schemaGate = 'pass'
    }
  }

  $candidateContext = $snapshot.candidate_text
  $loadedReferenceLines = 0
  foreach ($reference in $conditional) {
    $referenceId = [string](Get-R8H5Value $reference 'reference_id')
    if ($referenceId -notin $loaded) { continue }
    $referencePath = Resolve-R8H5ProjectPath ([string](Get-R8H5Value $reference 'path'))
    if ($null -eq $referencePath -or -not (Test-Path -LiteralPath $referencePath -PathType Leaf)) {
      throw "candidate_reference_missing:$skillId`:$referenceId"
    }
    $referenceText = Get-R8H5FileText $referencePath
    $candidateContext += "`n" + $referenceText
    $loadedReferenceLines += [System.IO.File]::ReadAllLines($referencePath).Count
  }

  $qualityAssertions = [System.Collections.Generic.List[object]]::new()
  foreach ($marker in @($snapshot.fixture.contract_markers)) {
    $markerText = [string]$marker
    $baselineHas = $snapshot.baseline_text.IndexOf($markerText, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    $candidateHas = $candidateContext.IndexOf($markerText, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    $qualityAssertions.Add([pscustomobject][ordered]@{
      assertion_id = "contract_marker:$markerText"
      assertion_type = 'contract_preservation'
      baseline_result = $(if ($baselineHas) { 'pass' } else { 'fail' })
      candidate_result = $(if ($candidateHas) { 'pass' } else { 'fail' })
      result = $(if ($baselineHas -and $candidateHas) { 'pass' } else { 'fail' })
    })
  }

  $nodeExpected = Get-R8H5Value $case 'expected_node_id'
  $nodeMatches = (
    ($null -eq $nodeExpected -and $null -eq $actualNodeId) -or
    ([string]$nodeExpected -eq [string]$actualNodeId)
  )
  $referenceMatches = [string]::Join('|', $loaded) -eq [string]::Join('|', $expectedReferences)
  $legacyMatches = $legacyLoaded -eq [bool]$case.expected_legacy_reference_loaded
  $contractMatches = $contractResult -eq [string]$case.expected_contract_selection_result
  $schemaMatches = $schemaGate -eq [string]$case.expected_schema_gate
  $qualityMatches = @($qualityAssertions | Where-Object { $_.result -ne 'pass' }).Count -eq 0
  $candidateContextLineCount = [int]$snapshot.candidate_line_count + $loadedReferenceLines
  $efficiencyImproved = $candidateContextLineCount -lt [int]$snapshot.baseline_line_count
  $casePass = $nodeMatches -and $referenceMatches -and $legacyMatches -and
    $contractMatches -and $schemaMatches -and $qualityMatches -and $efficiencyImproved
  $watch.Stop()

  $inputJson = $context | ConvertTo-Json -Depth 30 -Compress
  $record = [pscustomobject][ordered]@{
    eval_id = [string]$case.prompt_id
    skill_id = $skillId
    case_class = [string]$case.case_class
    baseline_commit = [string]$snapshot.fixture.baseline_commit
    baseline_contract_digest = [string]$snapshot.baseline_digest
    candidate_contract_digest = [string]$snapshot.candidate_digest
    prompt_id = [string]$case.prompt_id
    input_fingerprint = Get-R8H5TextDigest $inputJson
    expected_node_id = $nodeExpected
    actual_node_id = $actualNodeId
    loaded_reference_ids = [object[]]$loaded
    legacy_reference_loaded = $legacyLoaded
    output_artifact_type = [string]$snapshot.fixture.expected_output_artifact_type
    schema_gate = $schemaGate
    contract_selection_result = $contractResult
    wrong_route_count = $(if ($nodeMatches) { 0 } else { 1 })
    irrelevant_reference_load_count = $(if ($referenceMatches) { 0 } else { @($loaded | Where-Object { $_ -notin $expectedReferences }).Count })
    manual_assist_count = 0
    duration_ms = [int64]$watch.ElapsedMilliseconds
    input_tokens = 'not_observable'
    baseline_context_line_count = [int]$snapshot.baseline_line_count
    candidate_context_line_count = $candidateContextLineCount
    observable_efficiency_improved = $efficiencyImproved
    output_quality_assertions = [object[]]$qualityAssertions.ToArray()
    human_blind_preference = 'not_assessed'
    overall_result = $(if ($casePass) { 'pass' } else { 'fail' })
  }
  $recordDirectory = Join-Path $ReportRoot ([string]$case.prompt_id)
  Write-TaogeUtf8NoBomJson -Path (Join-Path $recordDirectory 'skill-context-eval-record.json') -Value $record -Depth 40
  $records.Add($record)
}

$matrixDefinitions = @(
  [pscustomobject]@{ id='r8_h1_inventory'; scope='current_metadata'; script='tools/validate-r8-h1-skill-context.ps1'; arguments=@() },
  [pscustomobject]@{ id='r8_h2_hotspot'; scope='current_skill'; script='tools/validate-r8-h2-hotspot-context.ps1'; arguments=@() },
  [pscustomobject]@{ id='r8_h3_router_gates'; scope='current_skill'; script='tools/validate-r8-h3-router-human-gates.ps1'; arguments=@() },
  [pscustomobject]@{ id='r8_h4_platform'; scope='current_skill'; script='tools/validate-r8-h4-platform-context.ps1'; arguments=@() },
  [pscustomobject]@{ id='r7_h1_contracts'; scope='current_contract'; script='tools/validate-r7-h1-contracts.ps1'; arguments=@() },
  [pscustomobject]@{ id='r7_h2_runtime'; scope='current_runtime'; script='tools/validate-r7-h2-runtime.ps1'; arguments=@() },
  [pscustomobject]@{ id='r7_h3_producers'; scope='current_runtime'; script='tools/validate-r7-h3-producer-adapters.ps1'; arguments=@() },
  [pscustomobject]@{ id='r7_l3_h2_visual'; scope='current_runtime'; script='tools/validate-r7-l3-h2-visual-semantic.ps1'; arguments=@() },
  [pscustomobject]@{ id='r7_l3_h3_direct'; scope='current_end_to_end'; script='tools/validate-r7-l3-h3-direct-route.ps1'; arguments=@() },
  [pscustomobject]@{ id='r7_l3_h4_hotspot'; scope='current_end_to_end'; script='tools/validate-r7-l3-h4-hotspot-route.ps1'; arguments=@() },
  [pscustomobject]@{ id='r7_h4_candidate_html'; scope='current_end_to_end_and_legacy'; script='tools/validate-r7-h4-candidate-runtime.ps1'; arguments=@() },
  [pscustomobject]@{ id='p0_h2_legacy'; scope='legacy_replay'; script='tools/validate-p0-h2-runtime.ps1'; arguments=@() },
  [pscustomobject]@{ id='sample_legacy_replay'; scope='legacy_replay'; script='tools/validate-regression-suite.ps1'; arguments=@() },
  [pscustomobject]@{ id='field_schema'; scope='metadata_and_contract'; script='tools/validate-field-schema.ps1'; arguments=@() },
  [pscustomobject]@{ id='route_schema'; scope='metadata_and_contract'; script='tools/validate-route-schema.ps1'; arguments=@() },
  [pscustomobject]@{ id='doc_governance'; scope='documentation'; script='tools/validate-doc-governance.ps1'; arguments=@() }
)

$matrix = [System.Collections.Generic.List[object]]::new()
foreach ($definition in $matrixDefinitions) {
  $scriptPath = Resolve-R8H5ProjectPath ([string]$definition.script)
  if ($null -eq $scriptPath -or -not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    $matrix.Add([pscustomobject][ordered]@{
      check_id = [string]$definition.id
      scope = [string]$definition.scope
      result = 'fail'
      exit_code = 3
      duration_ms = 0
      stdout_path = $null
      stderr_path = $null
      stderr_tail = "checker_missing:$([string]$definition.script)"
    })
    continue
  }
  $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)
  $arguments += @($definition.arguments)
  $run = Invoke-R8H5Process -Id ([string]$definition.id) -FilePath 'powershell.exe' -Arguments $arguments
  $matrix.Add([pscustomobject][ordered]@{
    check_id = [string]$definition.id
    scope = [string]$definition.scope
    result = $(if ($run.exit_code -eq 0) { 'pass' } else { 'fail' })
    exit_code = [int]$run.exit_code
    duration_ms = [int64]$run.duration_ms
    stdout_path = [string]$run.stdout_path
    stderr_path = [string]$run.stderr_path
    stdout_tail = [string]$run.stdout_tail
    stderr_tail = [string]$run.stderr_tail
  })
}

$failedRecords = @($records | Where-Object { $_.overall_result -ne 'pass' })
$failedMatrix = @($matrix | Where-Object { $_.result -ne 'pass' })
$classCoverage = @($fixture.cases | Group-Object skill_id | ForEach-Object {
  [pscustomobject][ordered]@{
    skill_id = [string]$_.Name
    normal_count = @($_.Group | Where-Object { $_.case_class -eq 'normal' }).Count
    conditional_or_resume_count = @($_.Group | Where-Object { $_.case_class -eq 'conditional_or_resume' }).Count
    rejection_count = @($_.Group | Where-Object { $_.case_class -eq 'rejection' }).Count
  }
})
$classCoveragePass = @($classCoverage | Where-Object {
  $_.normal_count -lt 1 -or $_.conditional_or_resume_count -lt 1 -or $_.rejection_count -lt 1
}).Count -eq 0
$allEfficiencyImproved = @($records | Where-Object { -not $_.observable_efficiency_improved }).Count -eq 0
$humanBlindStatus = 'not_assessed'
$machinePass = $failedRecords.Count -eq 0 -and $failedMatrix.Count -eq 0 -and
  $classCoveragePass -and $allEfficiencyImproved
$overall = if ($machinePass) { 'pass_with_warnings' } else { 'fail' }

$report = [pscustomobject][ordered]@{
  schema_id = 'taoge://reports/r8/h5-ab-total-regression/v0.1'
  generated_at = [DateTimeOffset]::UtcNow.ToString('o')
  fixture_set_id = [string]$fixture.fixture_set_id
  overall_result = $overall
  machine_regression_result = $(if ($machinePass) { 'pass' } else { 'fail' })
  current_switch_readiness = $(if ($machinePass) { 'waiting_human_blind_review' } else { 'blocked_machine_regression' })
  human_blind_review = $humanBlindStatus
  input_tokens = 'not_observable'
  baseline_policy = [string]$fixture.baseline_policy
  eval_record_count = $records.Count
  eval_pass_count = $records.Count - $failedRecords.Count
  eval_fail_count = $failedRecords.Count
  matrix_check_count = $matrix.Count
  matrix_pass_count = $matrix.Count - $failedMatrix.Count
  matrix_fail_count = $failedMatrix.Count
  class_coverage_result = $(if ($classCoveragePass) { 'pass' } else { 'fail' })
  class_coverage = [object[]]$classCoverage
  observable_efficiency_result = $(if ($allEfficiencyImproved) { 'pass' } else { 'fail' })
  no_new_manual_assist = @($records | Where-Object { $_.manual_assist_count -ne 0 }).Count -eq 0
  current_legacy_confusion_count = @($records | Where-Object {
    $_.legacy_reference_loaded -and $_.case_class -ne 'legacy_replay'
  }).Count
  records = [object[]]$records.ToArray()
  regression_matrix = [object[]]$matrix.ToArray()
  not_tested_scope = @(
    'human_blind_business_output_preference',
    'real_private_account',
    'network',
    'provider',
    'publishing',
    'public_build',
    'remote_ci'
  )
  network_called = $false
  provider_called = $false
  private_account_used = $false
  publishing_called = $false
}

$reportPath = Join-Path $ReportRoot 'r8-h5-ab-total-regression-report.json'
Write-TaogeUtf8NoBomJson -Path $reportPath -Value $report -Depth 70
Write-Output "R8_H5_RESULT=$overall"
Write-Output "R8_H5_MACHINE_RESULT=$($report.machine_regression_result)"
Write-Output "R8_H5_AB=$($report.eval_pass_count)/$($report.eval_record_count)"
Write-Output "R8_H5_MATRIX=$($report.matrix_pass_count)/$($report.matrix_check_count)"
Write-Output "R8_H5_CURRENT_SWITCH_READINESS=$($report.current_switch_readiness)"
Write-Output "R8_H5_REPORT=$reportPath"
if (-not $machinePass) { exit 1 }
exit 0
