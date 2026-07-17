param(
  [string]$ProjectRoot = '',
  [string]$RegistryPath = '',
  [string]$FixturePath = '',
  [string]$ReportPath = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
if ([string]::IsNullOrWhiteSpace($RegistryPath)) {
  $RegistryPath = Join-Path $ProjectRoot 'routes/r8-skill-context-registry.yaml'
}
if ([string]::IsNullOrWhiteSpace($FixturePath)) {
  $FixturePath = Join-Path $ProjectRoot 'examples/r8-skill-context-fixtures/h2-hotspot-load-cases.json'
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = Join-Path $ProjectRoot 'state/checks/r8-h2-hotspot-context-report.json'
}

. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'YamlHelper.ps1')

function Get-R8H2Value {
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

function Get-R8H2Items {
  param([object]$Value)
  if ($null -eq $Value) { return }
  if ($Value -is [System.Collections.IDictionary] -and $Value.Count -eq 0) { return }
  if ($Value -is [pscustomobject] -and @($Value.PSObject.Properties).Count -eq 0) { return }
  foreach ($item in @($Value)) { Write-Output $item }
}

function Resolve-R8H2Path {
  param([string]$RelativePath)
  if ([string]::IsNullOrWhiteSpace($RelativePath) -or [System.IO.Path]::IsPathRooted($RelativePath)) {
    return $null
  }
  $full = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot ($RelativePath -replace '/', '\')))
  $prefix = $ProjectRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $null
  }
  return $full
}

function Test-R8H2Clause {
  param([string]$Clause, [object]$Context)
  $match = [regex]::Match($Clause.Trim(), '^(contract_version|node_id|status|mode|target_platforms)\s*(==|!=|contains|in)\s*(.+)$')
  if (-not $match.Success) { return $false }
  $actual = [string](Get-R8H2Value $Context $match.Groups[1].Value)
  $operator = $match.Groups[2].Value
  $expected = @($match.Groups[3].Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  switch ($operator) {
    '==' { return $expected.Count -eq 1 -and $actual -eq $expected[0] }
    '!=' { return $expected.Count -eq 1 -and $actual -ne $expected[0] }
    'in' { return $actual -in $expected }
    'contains' { return @($actual.Split(',') | ForEach-Object { $_.Trim() }) | Where-Object { $_ -in $expected } | Select-Object -First 1 }
  }
  return $false
}

function Test-R8H2Condition {
  param([string]$Condition, [object]$Context)
  foreach ($clause in @($Condition -split '\s*&&\s*')) {
    if (-not (Test-R8H2Clause $clause $Context)) { return $false }
  }
  return $true
}

function Add-R8H2Check {
  param(
    [System.Collections.Generic.List[object]]$Checks,
    [string]$CheckId,
    [bool]$Passed,
    [string]$Detail
  )
  $Checks.Add([pscustomobject][ordered]@{
    check_id = $CheckId
    result = $(if ($Passed) { 'pass' } else { 'fail' })
    detail = $Detail
  })
}

$registry = Read-YamlFile $RegistryPath
$fixture = Get-Content -LiteralPath $FixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
$skill = @(Get-R8H2Items (Get-R8H2Value $registry 'skills') | Where-Object {
  [string](Get-R8H2Value $_ 'skill_id') -eq 'hotspot-topic-research'
}) | Select-Object -First 1
if ($null -eq $skill) { throw 'hotspot-topic-research registry entry is missing.' }

$checks = [System.Collections.Generic.List[object]]::new()
$skillPath = Resolve-R8H2Path ([string](Get-R8H2Value $skill 'skill_entry_path'))
$contractPath = Resolve-R8H2Path 'skills/hotspot-topic-research/CONTRACT.md'
$metadataPath = Resolve-R8H2Path 'skills/hotspot-topic-research/agents/openai.yaml'
$assetPath = Resolve-R8H2Path 'skills/hotspot-topic-research/assets/legacy-standalone-output-template.md'
$skillText = [System.IO.File]::ReadAllText($skillPath)
$contractText = [System.IO.File]::ReadAllText($contractPath)
$metadataText = [System.IO.File]::ReadAllText($metadataPath)
$assetText = [System.IO.File]::ReadAllText($assetPath)
$lineCount = [System.IO.File]::ReadAllLines($skillPath).Count

Add-R8H2Check $checks 'entry_line_limit' ($lineCount -le 500) "line_count=$lineCount"
Add-R8H2Check $checks 'entry_current_only' (
  $skillText -notmatch '(?m)^## R1 Contract Runtime$' -and
  $skillText -notmatch '(?m)^## R1 Contract Runtime|^## R1 Contract$' -and
  $skillText -match 'single_output:' -and
  $skillText -match 'hotspot_research_request' -and
  $skillText -match 'hotspot_research_set'
) 'Current entry is compact and legacy output blocks are absent.'
Add-R8H2Check $checks 'contract_current_only' (
  $contractText -match 'Skill contract version.*0\.3\.0' -and
  $contractText -match 'exactly_one_when_committed' -and
  $contractText -notmatch '3-5.*topic_card'
) 'CONTRACT describes the current request/set ownership.'

$conditional = @(Get-R8H2Items (Get-R8H2Value $skill 'conditional_references'))
$expectedIds = @('event_and_trend_model', 'evidence_risk_scoring', 'source_and_query_strategy')
$actualIds = @($conditional | ForEach-Object { [string](Get-R8H2Value $_ 'reference_id') } | Sort-Object)
Add-R8H2Check $checks 'three_current_references' (
  [string]::Join('|', $actualIds) -eq [string]::Join('|', $expectedIds)
) ([string]::Join(',', $actualIds))

foreach ($reference in $conditional) {
  $referenceId = [string](Get-R8H2Value $reference 'reference_id')
  $referencePath = [string](Get-R8H2Value $reference 'path')
  $loadWhen = [string](Get-R8H2Value $reference 'load_when')
  $fullPath = Resolve-R8H2Path $referencePath
  $leaf = Split-Path -Leaf $referencePath
  $exists = $null -ne $fullPath -and (Test-Path -LiteralPath $fullPath -PathType Leaf)
  $headerText = if ($exists) { [string]::Join("`n", @([System.IO.File]::ReadAllLines($fullPath) | Select-Object -First 12)) } else { '' }
  Add-R8H2Check $checks "reference_${referenceId}" (
    $exists -and
    $referencePath -match '^skills/hotspot-topic-research/references/[^/]+\.md$' -and
    $skillText -match [regex]::Escape("./references/$leaf") -and
    $headerText -match 'applicability:\s*current_only' -and
    $headerText -match [regex]::Escape($loadWhen)
  ) "$referencePath | $loadWhen"
}

$legacy = @(Get-R8H2Items (Get-R8H2Value $skill 'legacy_references'))
$legacyPath = if ($legacy.Count -eq 1) { [string]$legacy[0] } else { '' }
$legacyFullPath = Resolve-R8H2Path $legacyPath
$legacyText = if ($null -ne $legacyFullPath -and (Test-Path -LiteralPath $legacyFullPath)) {
  [System.IO.File]::ReadAllText($legacyFullPath)
} else { '' }
Add-R8H2Check $checks 'legacy_isolation' (
  $legacy.Count -eq 1 -and
  $legacyText -match 'applicability:\s*historical_only' -and
  $legacyText -match 'contract_version in r1,r5 && mode in legacy,replay' -and
  $legacyText -match 'assets/legacy-standalone-output-template\.md' -and
  $skillText -notmatch 'assets/legacy-standalone-output-template\.md' -and
  $assetText -match 'applicability:\s*historical_only'
) $legacyPath

$metadata = Read-YamlFile $metadataPath
$interface = Get-R8H2Value $metadata 'interface'
$shortDescription = [string](Get-R8H2Value $interface 'short_description')
$defaultPrompt = [string](Get-R8H2Value $interface 'default_prompt')
Add-R8H2Check $checks 'metadata_current_responsibility' (
  $shortDescription.Length -ge 25 -and
  $shortDescription.Length -le 64 -and
  $shortDescription -match 'typed research set' -and
  $defaultPrompt -match [regex]::Escape('$hotspot-topic-research') -and
  $defaultPrompt -match 'without rendering the selection panel'
) "short_description_length=$($shortDescription.Length)"

$caseResults = [System.Collections.Generic.List[object]]::new()
foreach ($case in @($fixture.cases)) {
  $loaded = @($conditional | Where-Object {
    Test-R8H2Condition ([string](Get-R8H2Value $_ 'load_when')) $case.context
  } | ForEach-Object {
    [string](Get-R8H2Value $_ 'reference_id')
  } | Sort-Object)
  $expected = @($case.expected_references | ForEach-Object { [string]$_ } | Sort-Object)
  $legacyLoaded = (
    [string]$case.context.contract_version -in @('r1', 'r5') -and
    [string]$case.context.mode -in @('legacy', 'replay')
  )
  $passed = (
    [string]::Join('|', $loaded) -eq [string]::Join('|', $expected) -and
    $legacyLoaded -eq [bool]$case.expected_legacy
  )
  $caseResults.Add([pscustomobject][ordered]@{
    case_id = [string]$case.case_id
    expected_references = [object[]]$expected
    actual_references = [object[]]$loaded
    expected_legacy = [bool]$case.expected_legacy
    actual_legacy = $legacyLoaded
    result = $(if ($passed) { 'pass' } else { 'fail' })
  })
}

$failedChecks = @($checks | Where-Object { $_.result -ne 'pass' })
$failedCases = @($caseResults | Where-Object { $_.result -ne 'pass' })
$report = [pscustomobject][ordered]@{
  schema_id = 'taoge://reports/r8/hotspot-context-h2/v0.1'
  generated_at = [DateTimeOffset]::UtcNow.ToString('o')
  fixture_set_id = [string]$fixture.fixture_set_id
  overall_result = $(if ($failedChecks.Count -eq 0 -and $failedCases.Count -eq 0) { 'pass' } else { 'fail' })
  skill_entry_line_count = $lineCount
  conditional_reference_count = $conditional.Count
  legacy_reference_count = $legacy.Count
  structural_check_count = $checks.Count
  structural_pass_count = $checks.Count - $failedChecks.Count
  fixture_case_count = $caseResults.Count
  fixture_pass_count = $caseResults.Count - $failedCases.Count
  checks = [object[]]$checks.ToArray()
  cases = [object[]]$caseResults.ToArray()
  network_called = $false
  provider_called = $false
  private_account_used = $false
  publishing_called = $false
}

$reportDirectory = Split-Path -Parent $ReportPath
if (-not (Test-Path -LiteralPath $reportDirectory)) {
  New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
}
Write-TaogeUtf8NoBomJson -Path $ReportPath -Value $report -Depth 60
Write-Output ("R8-H2 hotspot context: {0}; structural={1}/{2}; fixtures={3}/{4}; lines={5}" -f `
  $report.overall_result, $report.structural_pass_count, $report.structural_check_count, `
  $report.fixture_pass_count, $report.fixture_case_count, $lineCount)
if ($report.overall_result -ne 'pass') { exit 1 }
exit 0
