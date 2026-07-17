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
  $FixturePath = Join-Path $ProjectRoot 'examples/r8-skill-context-fixtures/h4-platform-load-cases.json'
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = Join-Path $ProjectRoot 'state/checks/r8-h4-platform-context-report.json'
}

. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'YamlHelper.ps1')
. (Join-Path $PSScriptRoot 'WorkflowCompatibilityLoader.ps1')
. (Join-Path $PSScriptRoot 'R8PlatformPackagingRuntime.ps1')

function Get-R8H4Value {
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

function Get-R8H4Items {
  param([object]$Value)
  if ($null -eq $Value) { return }
  if ($Value -is [System.Collections.IDictionary] -and $Value.Count -eq 0) { return }
  if ($Value -is [pscustomobject] -and @($Value.PSObject.Properties).Count -eq 0) { return }
  foreach ($item in @($Value)) { Write-Output $item }
}

function Resolve-R8H4Path {
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

function Add-R8H4Check {
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

function Test-R8H4LoadCondition {
  param([string]$Condition, [string[]]$Targets)
  $match = [regex]::Match($Condition, '^target_platforms\s+contains\s+([a-z_]+)$')
  return $match.Success -and $match.Groups[1].Value -in $Targets
}

function New-R8H4Package {
  param([object]$Case)
  $items = @()
  foreach ($platform in @($Case.package_platforms)) {
    $items += [pscustomobject][ordered]@{
      platform = [string]$platform
      title = "title-$platform"
      cover_title = "cover-$platform"
      body_text = "body-$platform"
      hashtags = @('fixture')
      notes = @('manual')
    }
  }
  return [pscustomobject][ordered]@{
    schema_id = 'taoge://schemas/r7/platform-package/v0.2'
    schema_version = '0.2'
    platform_package_id = "PK-$([string]$Case.case_id)"
    delivery_title = 'Fixture delivery title'
    draft_ref = [pscustomobject]@{}
    primary_platform = [string]$Case.primary_platform
    packages = [object[]]$items
    package_status = 'package_pass'
    next_skill = 'cover-design-compiler'
  }
}

$registry = Read-YamlFile $RegistryPath
$fixture = Get-Content -LiteralPath $FixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
$skill = @(Get-R8H4Items (Get-R8H4Value $registry 'skills') | Where-Object {
  [string](Get-R8H4Value $_ 'skill_id') -eq 'platform-packaging-adapter'
}) | Select-Object -First 1
if ($null -eq $skill) { throw 'platform-packaging-adapter registry entry is missing.' }

$checks = [System.Collections.Generic.List[object]]::new()
$skillPath = Resolve-R8H4Path ([string](Get-R8H4Value $skill 'skill_entry_path'))
$contractPath = Resolve-R8H4Path 'skills/platform-packaging-adapter/CONTRACT.md'
$metadataPath = Resolve-R8H4Path 'skills/platform-packaging-adapter/agents/openai.yaml'
$assetPath = Resolve-R8H4Path 'skills/platform-packaging-adapter/assets/platform-package-template.md'
$legacyPath = Resolve-R8H4Path 'skills/platform-packaging-adapter/references/legacy-r1-r7-platform-packaging.md'
$legacyContractPath = Resolve-R8H4Path 'skills/platform-packaging-adapter/references/legacy-r1-r7-platform-contract.md'
$semanticRuntimePath = Resolve-R8H4Path 'tools/R7SemanticRuntime.ps1'
$semanticRuntimeImplementationPath = Resolve-WorkflowCompatibilityAsset -ProjectRoot $ProjectRoot -AssetReference 'compatibility/legacy-r7/tools/R7SemanticRuntime.impl.ps1' -CallerRuntimeGeneration 'compile_time_compatibility'
$adapterRegistryPath = Resolve-WorkflowCompatibilityAsset -ProjectRoot $ProjectRoot -AssetReference 'compatibility/legacy-r7/routes/r7-producer-adapter-registry.yaml' -CallerRuntimeGeneration 'compile_time_compatibility'
$schemaPath = Resolve-R8H4Path 'templates/schema/r7/platform-package.v0.2.schema.json'

$skillText = [System.IO.File]::ReadAllText($skillPath)
$contractText = [System.IO.File]::ReadAllText($contractPath)
$metadataText = [System.IO.File]::ReadAllText($metadataPath)
$assetText = [System.IO.File]::ReadAllText($assetPath)
$legacyText = [System.IO.File]::ReadAllText($legacyPath)
$legacyContractText = [System.IO.File]::ReadAllText($legacyContractPath)
$semanticRuntimeText = [System.IO.File]::ReadAllText($semanticRuntimePath) + [System.IO.File]::ReadAllText($semanticRuntimeImplementationPath)
$adapterRegistryText = [System.IO.File]::ReadAllText($adapterRegistryPath)
$lineCount = [System.IO.File]::ReadAllLines($skillPath).Count

Add-R8H4Check $checks 'entry_line_limit' ($lineCount -le 500) "line_count=$lineCount"
Add-R8H4Check $checks 'entry_current_only' (
  $skillText -match 'single_output:\s*platform_package' -and
  $skillText -match 'captured_fields\.publishing_platforms' -and
  $skillText -notmatch '(?m)^## R1 Contract Runtime$' -and
  $skillText -match 'Do not infer platforms from chat or default to all platforms'
) 'Entry keeps the current shared contract and has no embedded legacy/default-all rule.'
Add-R8H4Check $checks 'contract_current_only' (
  $contractText -match 'Skill contract version:\s*`0\.6\.0`' -and
  $contractText -match 'produces exactly one typed `platform_package`' -and
  $contractText -notmatch 'cover_variant_set_id'
) 'CONTRACT is current-only and points to machine truth.'
Add-R8H4Check $checks 'template_asset' (
  $assetText -match 'applicability:\s*current_only' -and
  $assetText -match 'Repeat the package item once for each selected platform and for no others'
) 'Current assembly template is isolated as an asset.'
Add-R8H4Check $checks 'legacy_isolation' (
  $legacyText -match 'applicability:\s*historical_only' -and
  $legacyText -match 'contract_version in r1,r7 && mode in legacy,replay' -and
  $legacyContractText -match 'applicability:\s*historical_only' -and
  $legacyContractText -match 'contract_version in r1,r7 && mode in legacy,replay' -and
  $skillText -match 'legacy-r1-r7-platform-packaging\.md' -and
  $skillText -match 'legacy-r1-r7-platform-contract\.md'
) 'Historical embedded entry and handoff contract are isolated behind an explicit replay condition.'

$legacyReferences = @(Get-R8H4Items (Get-R8H4Value $skill 'legacy_references'))
Add-R8H4Check $checks 'two_legacy_references' (
  $legacyReferences.Count -eq 2 -and
  $legacyReferences -contains 'skills/platform-packaging-adapter/references/legacy-r1-r7-platform-packaging.md' -and
  $legacyReferences -contains 'skills/platform-packaging-adapter/references/legacy-r1-r7-platform-contract.md'
) ([string]::Join(',', $legacyReferences))

$conditional = @(Get-R8H4Items (Get-R8H4Value $skill 'conditional_references'))
$expectedMap = [ordered]@{
  douyin = 'skills/platform-packaging-adapter/references/douyin.md'
  kuaishou = 'skills/platform-packaging-adapter/references/kuaishou.md'
  wechat_channels = 'skills/platform-packaging-adapter/references/wechat-channels.md'
  xiaohongshu = 'skills/platform-packaging-adapter/references/xiaohongshu.md'
}
$actualIds = @($conditional | ForEach-Object { [string](Get-R8H4Value $_ 'reference_id') } | Sort-Object)
Add-R8H4Check $checks 'four_platform_references' (
  [string]::Join('|', $actualIds) -eq [string]::Join('|', @($expectedMap.Keys | Sort-Object))
) ([string]::Join(',', $actualIds))

foreach ($reference in $conditional) {
  $referenceId = [string](Get-R8H4Value $reference 'reference_id')
  $referencePath = [string](Get-R8H4Value $reference 'path')
  $loadWhen = [string](Get-R8H4Value $reference 'load_when')
  $fullPath = Resolve-R8H4Path $referencePath
  $leaf = Split-Path -Leaf $referencePath
  $text = if ($null -ne $fullPath -and (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
    [string]::Join("`n", @([System.IO.File]::ReadAllLines($fullPath) | Select-Object -First 12))
  } else { '' }
  Add-R8H4Check $checks "reference_$referenceId" (
    $expectedMap.Contains($referenceId) -and
    $referencePath -eq $expectedMap[$referenceId] -and
    $loadWhen -eq "target_platforms contains $referenceId" -and
    $skillText -match [regex]::Escape("./references/$leaf") -and
    $text -match 'applicability:\s*current_only' -and
    $text -match [regex]::Escape($loadWhen)
  ) "$referencePath | $loadWhen"
}

$metadata = Read-YamlFile $metadataPath
$interface = Get-R8H4Value $metadata 'interface'
$shortDescription = [string](Get-R8H4Value $interface 'short_description')
$defaultPrompt = [string](Get-R8H4Value $interface 'default_prompt')
Add-R8H4Check $checks 'metadata_current_responsibility' (
  $shortDescription.Length -ge 25 -and
  $shortDescription.Length -le 64 -and
  $defaultPrompt -match [regex]::Escape('$platform-packaging-adapter') -and
  $defaultPrompt -match 'exactly the platforms selected'
) "short_description_length=$($shortDescription.Length)"

Add-R8H4Check $checks 'runtime_linkage' (
  $adapterRegistryText -match '(?ms)^\s*-\s+node_id:\s*platform_package_h7\s*$.*?^\s+validation_mode:\s*json_schema_root_and_platform_target_contract\s*$' -and
  $adapterRegistryText -match '(?ms)^\s*-\s+node_id:\s*platform_package\s*$.*?^\s+validation_mode:\s*json_schema_root_and_platform_target_contract\s*$' -and
  $semanticRuntimeText -match 'Test-R8PlatformPackageTargetContract'
) 'Both current packaging nodes call the deterministic target parity validator.'

$schema = Get-Content -LiteralPath $schemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
$schemaPlatforms = @($schema.properties.primary_platform.enum | ForEach-Object { [string]$_ } | Sort-Object)
Add-R8H4Check $checks 'current_schema_capability_honesty' (
  [string]::Join('|', $schemaPlatforms) -eq 'douyin|wechat_channels|xiaohongshu'
) ([string]::Join(',', $schemaPlatforms))

$caseResults = [System.Collections.Generic.List[object]]::new()
foreach ($case in @($fixture.cases)) {
  $targets = @($case.target_platforms | ForEach-Object { [string]$_ })
  $loaded = @($conditional | Where-Object {
    Test-R8H4LoadCondition ([string](Get-R8H4Value $_ 'load_when')) $targets
  } | ForEach-Object {
    [string](Get-R8H4Value $_ 'reference_id')
  } | Sort-Object)
  $expectedReferences = @($case.expected_references | ForEach-Object { [string]$_ } | Sort-Object)
  $snapshot = [pscustomobject][ordered]@{
    captured_fields = [pscustomobject][ordered]@{
      publishing_platforms = [object[]]$targets
    }
  }
  $payload = New-R8H4Package $case
  $errors = @(Test-R8PlatformPackageTargetContract -Payload $payload -AccountSnapshot $snapshot -SupportedPlatforms $schemaPlatforms)
  $actualResult = if ($errors.Count -eq 0) { 'pass' } else { 'fail' }
  $expectedErrorsFound = $true
  foreach ($expectedError in @($case.expected_error_contains)) {
    if (-not @($errors | Where-Object { $_ -like "$expectedError*" }).Count) {
      $expectedErrorsFound = $false
    }
  }
  $passed = (
    [string]::Join('|', $loaded) -eq [string]::Join('|', $expectedReferences) -and
    $actualResult -eq [string]$case.expected_contract_result -and
    $expectedErrorsFound
  )
  $caseResults.Add([pscustomobject][ordered]@{
    case_id = [string]$case.case_id
    expected_references = [object[]]$expectedReferences
    actual_references = [object[]]$loaded
    expected_contract_result = [string]$case.expected_contract_result
    actual_contract_result = $actualResult
    errors = [object[]]$errors
    result = $(if ($passed) { 'pass' } else { 'fail' })
  })
}

$failedChecks = @($checks | Where-Object { $_.result -ne 'pass' })
$failedCases = @($caseResults | Where-Object { $_.result -ne 'pass' })
$report = [pscustomobject][ordered]@{
  schema_id = 'taoge://reports/r8/platform-context-h4/v0.1'
  generated_at = [DateTimeOffset]::UtcNow.ToString('o')
  fixture_set_id = [string]$fixture.fixture_set_id
  overall_result = $(if ($failedChecks.Count -eq 0 -and $failedCases.Count -eq 0) { 'pass' } else { 'fail' })
  skill_entry_line_count = $lineCount
  conditional_reference_count = $conditional.Count
  legacy_reference_count = $legacyReferences.Count
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
Write-Output ("R8-H4 platform context: {0}; structural={1}/{2}; fixtures={3}/{4}; lines={5}" -f `
  $report.overall_result, $report.structural_pass_count, $report.structural_check_count, `
  $report.fixture_pass_count, $report.fixture_case_count, $lineCount)
if ($report.overall_result -ne 'pass') { exit 1 }
exit 0
