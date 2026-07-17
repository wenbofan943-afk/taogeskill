param(
  [string]$ProjectRoot = '',
  [string]$RegistryPath = '',
  [string]$FixtureCatalogPath = '',
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
if ([string]::IsNullOrWhiteSpace($FixtureCatalogPath)) {
  $FixtureCatalogPath = Join-Path $ProjectRoot 'examples/r8-skill-context-fixtures/fixture-catalog.json'
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = Join-Path $ProjectRoot 'state/checks/r8-h1-skill-context-report.json'
}

. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'YamlHelper.ps1')

function Get-R8Value {
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

function Copy-R8Object {
  param([object]$Value)
  return ($Value | ConvertTo-Json -Depth 60 | ConvertFrom-Json)
}

function Get-R8Items {
  param([object]$Value)
  if ($null -eq $Value) { return }
  if ($Value -is [System.Collections.IDictionary] -and $Value.Count -eq 0) { return }
  if ($Value -is [pscustomobject] -and @($Value.PSObject.Properties).Count -eq 0) { return }
  foreach ($item in @($Value)) { Write-Output $item }
}

function Resolve-R8ProjectPath {
  param([string]$Root, [string]$RelativePath)
  if ([string]::IsNullOrWhiteSpace($RelativePath) -or [System.IO.Path]::IsPathRooted($RelativePath)) {
    return $null
  }
  $candidate = [System.IO.Path]::GetFullPath((Join-Path $Root ($RelativePath -replace '/', '\')))
  $rootPrefix = $Root.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  if (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $null
  }
  return $candidate
}

function Get-R8SkillDirectories {
  param([string]$Root)
  $skillRoot = Join-Path $Root 'skills'
  return @(Get-ChildItem -LiteralPath $skillRoot -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md')
  } | Sort-Object Name)
}

function Get-R8OwnedNodes {
  param([object]$NodeRegistry, [string]$SkillId)
  return @(@(Get-R8Value $NodeRegistry 'nodes') | Where-Object {
    [string](Get-R8Value $_ 'skill_ref') -eq $SkillId
  } | ForEach-Object {
    [string](Get-R8Value $_ 'node_id')
  } | Sort-Object)
}

function Add-R8Error {
  param(
    [System.Collections.Generic.List[string]]$Errors,
    [string]$Code,
    [string]$Detail
  )
  $Errors.Add(('{0}:{1}' -f $Code, $Detail))
}

function Test-R8Registry {
  param(
    [object]$Registry,
    [string]$Root,
    [object]$NodeRegistry
  )

  $errors = [System.Collections.Generic.List[string]]::new()
  $warnings = [System.Collections.Generic.List[string]]::new()
  $debts = [System.Collections.Generic.List[object]]::new()
  $allowedTypes = @('router', 'producer', 'reviewer', 'builder', 'compatibility', 'human_gate')
  $allowedOwnership = @('current', 'compatibility', 'superseded')
  $allowedEmbeddedLegacy = @('absent', 'present_pending_extraction', 'whole_entry_compatibility')
  $allowedContextStatus = @('compliant', 'warning_review_required', 'entry_limit_exceeded_pending_recompile')
  $allowedLoadFields = 'contract_version|node_id|status|mode|target_platforms'
  $loadWhenPattern = '^(' + $allowedLoadFields + ')\s*(==|!=|contains|in)\s*[^&]+(\s*&&\s*(' + $allowedLoadFields + ')\s*(==|!=|contains|in)\s*[^&]+)*$'

  if ([string](Get-R8Value $Registry 'registry_id') -ne 'r8-skill-context-registry-v0.1') {
    Add-R8Error $errors 'registry_id_invalid' ([string](Get-R8Value $Registry 'registry_id'))
  }
  $policy = Get-R8Value $Registry 'entry_policy'
  if ([int](Get-R8Value $policy 'line_limit') -ne 500) {
    Add-R8Error $errors 'registry_line_limit_invalid' ([string](Get-R8Value $policy 'line_limit'))
  }
  if ([int](Get-R8Value $policy 'warning_threshold') -ne 350) {
    Add-R8Error $errors 'registry_warning_threshold_invalid' ([string](Get-R8Value $policy 'warning_threshold'))
  }
  if ([int](Get-R8Value $policy 'reference_depth_limit') -ne 1) {
    Add-R8Error $errors 'registry_reference_depth_invalid' ([string](Get-R8Value $policy 'reference_depth_limit'))
  }

  $skillDirectories = @(Get-R8SkillDirectories $Root)
  $actualSkillIds = @($skillDirectories | ForEach-Object { $_.Name } | Sort-Object)
  $entries = @(Get-R8Items (Get-R8Value $Registry 'skills'))
  $registeredSkillIds = @($entries | ForEach-Object { [string](Get-R8Value $_ 'skill_id') })
  $duplicates = @($registeredSkillIds | Group-Object | Where-Object { $_.Count -gt 1 })
  foreach ($duplicate in $duplicates) {
    Add-R8Error $errors 'skill_id_duplicate' ([string]$duplicate.Name)
  }
  $missing = @($actualSkillIds | Where-Object { $_ -notin $registeredSkillIds })
  $unknown = @($registeredSkillIds | Where-Object { $_ -notin $actualSkillIds })
  foreach ($skillId in $missing) { Add-R8Error $errors 'skill_inventory_missing' $skillId }
  foreach ($skillId in $unknown) { Add-R8Error $errors 'skill_inventory_unknown' $skillId }

  foreach ($entry in $entries) {
    $skillId = [string](Get-R8Value $entry 'skill_id')
    if ([string]::IsNullOrWhiteSpace($skillId)) {
      Add-R8Error $errors 'skill_id_missing' 'entry'
      continue
    }
    $skillType = [string](Get-R8Value $entry 'skill_type')
    if ($skillType -notin $allowedTypes) {
      Add-R8Error $errors 'skill_type_invalid' "$skillId=$skillType"
    }
    $userInvocable = Get-R8Value $entry 'user_invocable'
    if ($userInvocable -isnot [bool]) {
      Add-R8Error $errors 'user_invocable_not_boolean' $skillId
    }
    foreach ($field in @('current_contract_version', 'primary_input_artifact_type', 'primary_output_artifact_type')) {
      if ([string]::IsNullOrWhiteSpace([string](Get-R8Value $entry $field))) {
        Add-R8Error $errors 'required_field_missing' "$skillId.$field"
      }
    }

    $ownershipStatus = [string](Get-R8Value $entry 'ownership_status')
    if ($ownershipStatus -notin $allowedOwnership) {
      Add-R8Error $errors 'ownership_status_invalid' "$skillId=$ownershipStatus"
    }
    $embeddedLegacyStatus = [string](Get-R8Value $entry 'embedded_legacy_status')
    if ($embeddedLegacyStatus -notin $allowedEmbeddedLegacy) {
      Add-R8Error $errors 'embedded_legacy_status_invalid' "$skillId=$embeddedLegacyStatus"
    }
    if ($ownershipStatus -eq 'compatibility' -and $embeddedLegacyStatus -ne 'whole_entry_compatibility') {
      Add-R8Error $errors 'compatibility_entry_not_declared' $skillId
    }

    $entryPath = [string](Get-R8Value $entry 'skill_entry_path')
    $expectedEntryPath = "skills/$skillId/SKILL.md"
    if ($entryPath -ne $expectedEntryPath) {
      Add-R8Error $errors 'skill_entry_path_not_canonical' "$skillId=$entryPath"
    }
    $fullEntryPath = Resolve-R8ProjectPath $Root $entryPath
    if ($null -eq $fullEntryPath -or -not (Test-Path -LiteralPath $fullEntryPath -PathType Leaf)) {
      Add-R8Error $errors 'skill_entry_missing' "$skillId=$entryPath"
      continue
    }

    $lineCount = [System.IO.File]::ReadAllLines($fullEntryPath).Count
    $declaredLineCount = [int](Get-R8Value $entry 'entry_line_count')
    if ($lineCount -ne $declaredLineCount) {
      Add-R8Error $errors 'entry_line_count_mismatch' "$skillId declared=$declaredLineCount actual=$lineCount"
    }
    $actualDigest = 'sha256:' + (Get-TaogeFileSha256 -Path $fullEntryPath)
    $declaredDigest = [string](Get-R8Value $entry 'skill_entry_digest')
    if ($actualDigest -ne $declaredDigest) {
      Add-R8Error $errors 'entry_digest_mismatch' "$skillId declared=$declaredDigest actual=$actualDigest"
    }
    if ([int](Get-R8Value $entry 'entry_line_limit') -ne 500) {
      Add-R8Error $errors 'entry_line_limit_drift' $skillId
    }
    if ([int](Get-R8Value $entry 'entry_warning_threshold') -ne 350) {
      Add-R8Error $errors 'entry_warning_threshold_drift' $skillId
    }

    $entryText = [System.IO.File]::ReadAllText($fullEntryPath)
    $frontmatterNameMatch = [regex]::Match($entryText, '(?m)^name:\s*["'']?([^\r\n"'']+)["'']?\s*$')
    if (-not $frontmatterNameMatch.Success -or $frontmatterNameMatch.Groups[1].Value.Trim() -ne $skillId) {
      Add-R8Error $errors 'skill_frontmatter_name_mismatch' $skillId
    }

    $contextStatus = [string](Get-R8Value $entry 'context_policy_status')
    $plannedBatch = [string](Get-R8Value $entry 'planned_context_batch')
    if ($contextStatus -notin $allowedContextStatus) {
      Add-R8Error $errors 'context_policy_status_invalid' "$skillId=$contextStatus"
    } elseif ($lineCount -gt 500) {
      if ($contextStatus -ne 'entry_limit_exceeded_pending_recompile' -or [string]::IsNullOrWhiteSpace($plannedBatch) -or $plannedBatch -eq 'not_applicable') {
        Add-R8Error $errors 'entry_limit_debt_unacknowledged' $skillId
      } else {
        $warnings.Add("entry_limit_exceeded:${skillId}:$lineCount")
        $debts.Add([pscustomobject][ordered]@{
          skill_id = $skillId
          line_count = $lineCount
          line_limit = 500
          planned_context_batch = $plannedBatch
        })
      }
    } elseif ($lineCount -gt 350) {
      if ($contextStatus -ne 'warning_review_required') {
        Add-R8Error $errors 'entry_warning_unacknowledged' $skillId
      }
    } elseif ($contextStatus -ne 'compliant') {
      Add-R8Error $errors 'entry_context_status_false_positive' "$skillId=$contextStatus"
    }

    $alwaysLoaded = @(Get-R8Items (Get-R8Value $entry 'always_loaded_sections'))
    if ($alwaysLoaded.Count -eq 0 -or @($alwaysLoaded | Where-Object { [string]::IsNullOrWhiteSpace([string]$_) }).Count -gt 0) {
      Add-R8Error $errors 'always_loaded_sections_invalid' $skillId
    }

    $actualOwnedNodes = @(Get-R8OwnedNodes $NodeRegistry $skillId)
    $declaredOwnedNodes = @(Get-R8Items (Get-R8Value $entry 'owned_node_ids') | ForEach-Object { [string]$_ } | Sort-Object)
    if ([string]::Join('|', $actualOwnedNodes) -ne [string]::Join('|', $declaredOwnedNodes)) {
      Add-R8Error $errors 'owned_node_ids_mismatch' "$skillId declared=$([string]::Join(',', $declaredOwnedNodes)) actual=$([string]::Join(',', $actualOwnedNodes))"
    }

    $declaredReferencePaths = [System.Collections.Generic.List[string]]::new()
    foreach ($reference in @(Get-R8Items (Get-R8Value $entry 'conditional_references'))) {
      $referenceId = [string](Get-R8Value $reference 'reference_id')
      $referencePath = [string](Get-R8Value $reference 'path')
      $loadWhen = [string](Get-R8Value $reference 'load_when')
      $contentOwner = [string](Get-R8Value $reference 'content_owner')
      if ([string]::IsNullOrWhiteSpace($referenceId) -or [string]::IsNullOrWhiteSpace($contentOwner)) {
        Add-R8Error $errors 'conditional_reference_identity_missing' $skillId
      }
      if ($loadWhen -notmatch $loadWhenPattern) {
        Add-R8Error $errors 'conditional_reference_load_when_ambiguous' "$skillId.$referenceId=$loadWhen"
      }
      $expectedPrefix = "skills/$skillId/references/"
      $leaf = if ($referencePath.StartsWith($expectedPrefix)) { $referencePath.Substring($expectedPrefix.Length) } else { '' }
      if (-not $referencePath.StartsWith($expectedPrefix) -or [string]::IsNullOrWhiteSpace($leaf) -or $leaf.Contains('/') -or $leaf.Contains('\')) {
        Add-R8Error $errors 'conditional_reference_not_one_level' "$skillId.$referenceId=$referencePath"
      }
      $fullReferencePath = Resolve-R8ProjectPath $Root $referencePath
      if ($null -eq $fullReferencePath -or -not (Test-Path -LiteralPath $fullReferencePath -PathType Leaf)) {
        Add-R8Error $errors 'conditional_reference_missing' "$skillId.$referenceId=$referencePath"
      }
      if (-not [string]::IsNullOrWhiteSpace($leaf) -and $entryText -notmatch [regex]::Escape("references/$leaf")) {
        Add-R8Error $errors 'conditional_reference_not_linked_from_entry' "$skillId.$referenceId"
      }
      $declaredReferencePaths.Add($referencePath)
    }

    foreach ($legacyReference in @(Get-R8Items (Get-R8Value $entry 'legacy_references'))) {
      $legacyPath = [string]$legacyReference
      $expectedPrefix = "skills/$skillId/references/"
      $leaf = if ($legacyPath.StartsWith($expectedPrefix)) { $legacyPath.Substring($expectedPrefix.Length) } else { '' }
      if (-not $legacyPath.StartsWith($expectedPrefix) -or [string]::IsNullOrWhiteSpace($leaf) -or $leaf.Contains('/') -or $leaf.Contains('\') -or $leaf -notmatch '(legacy|replay)') {
        Add-R8Error $errors 'legacy_reference_not_one_level_or_unmarked' "$skillId=$legacyPath"
      }
      $fullLegacyPath = Resolve-R8ProjectPath $Root $legacyPath
      if ($null -eq $fullLegacyPath -or -not (Test-Path -LiteralPath $fullLegacyPath -PathType Leaf)) {
        Add-R8Error $errors 'legacy_reference_missing' "$skillId=$legacyPath"
      }
      if (-not [string]::IsNullOrWhiteSpace($leaf) -and $entryText -notmatch [regex]::Escape("references/$leaf")) {
        Add-R8Error $errors 'legacy_reference_not_linked_from_entry' "$skillId=$legacyPath"
      }
      $declaredReferencePaths.Add($legacyPath)
    }

    $referencesRoot = Join-Path (Split-Path -Parent $fullEntryPath) 'references'
    if (Test-Path -LiteralPath $referencesRoot -PathType Container) {
      $actualReferences = @(Get-ChildItem -LiteralPath $referencesRoot -File -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($Root.TrimEnd('\', '/').Length + 1).Replace('\', '/')
        $relative
      })
      foreach ($actualReference in $actualReferences) {
        if ($actualReference -notin $declaredReferencePaths) {
          Add-R8Error $errors 'reference_file_not_registered' "$skillId=$actualReference"
        }
      }
    }

    $machineTruthRefs = @(Get-R8Items (Get-R8Value $entry 'machine_truth_refs'))
    if ($machineTruthRefs.Count -eq 0) {
      Add-R8Error $errors 'machine_truth_refs_missing' $skillId
    }
    foreach ($machineTruthRef in $machineTruthRefs) {
      $fullTruthPath = Resolve-R8ProjectPath $Root ([string]$machineTruthRef)
      if ($null -eq $fullTruthPath -or -not (Test-Path -LiteralPath $fullTruthPath -PathType Leaf)) {
        Add-R8Error $errors 'machine_truth_ref_missing' "$skillId=$machineTruthRef"
      }
    }
  }

  return [pscustomobject][ordered]@{
    errors = [object[]]$errors.ToArray()
    warnings = [object[]]$warnings.ToArray()
    debts = [object[]]$debts.ToArray()
    structural_result = $(if ($errors.Count -eq 0) { 'pass' } else { 'fail' })
  }
}

function Invoke-R8Mutation {
  param([object]$Registry, [string]$Mutation)
  $copy = Copy-R8Object $Registry
  switch ($Mutation) {
    'none' { return $copy }
    'line_count_mismatch' {
      $copy.skills[0].entry_line_count = [int]$copy.skills[0].entry_line_count + 1
    }
    'digest_mismatch' {
      $copy.skills[0].skill_entry_digest = 'sha256:' + ('0' * 64)
    }
    'ambiguous_load_when' {
      $copy.skills[0].conditional_references = @([pscustomobject][ordered]@{
        reference_id = 'ambiguous'
        path = 'skills/account-onboarding/references/ambiguous.md'
        load_when = 'when needed'
        content_owner = 'account-onboarding'
      })
    }
    'nested_reference' {
      $copy.skills[0].conditional_references = @([pscustomobject][ordered]@{
        reference_id = 'nested'
        path = 'skills/account-onboarding/references/legacy/nested.md'
        load_when = 'mode == replay'
        content_owner = 'account-onboarding'
      })
    }
    'duplicate_skill_id' {
      $copy.skills = @($copy.skills) + @($copy.skills[0])
    }
    'missing_skill_entry' {
      $copy.skills = @($copy.skills | Select-Object -Skip 1)
    }
    'false_positive_entry_debt' {
      $target = @($copy.skills | Where-Object { $_.skill_id -eq 'platform-packaging-adapter' }) | Select-Object -First 1
      $target.context_policy_status = 'entry_limit_exceeded_pending_recompile'
      $target.planned_context_batch = 'R8-HX'
    }
    'node_ownership_mismatch' {
      $target = @($copy.skills | Where-Object { $_.skill_id -eq 'business-delivery-acceptance' }) | Select-Object -First 1
      $target.owned_node_ids = @()
    }
    'unknown_skill_entry' {
      $unknown = Copy-R8Object $copy.skills[0]
      $unknown.skill_id = 'unknown-project-skill'
      $unknown.skill_entry_path = 'skills/unknown-project-skill/SKILL.md'
      $copy.skills = @($copy.skills) + @($unknown)
    }
    'threshold_drift' {
      $copy.entry_policy.line_limit = 501
    }
    default {
      throw "Unknown R8 fixture mutation: $Mutation"
    }
  }
  return $copy
}

if (-not (Test-Path -LiteralPath $RegistryPath -PathType Leaf)) {
  throw "R8 registry not found: $RegistryPath"
}
if (-not (Test-Path -LiteralPath $FixtureCatalogPath -PathType Leaf)) {
  throw "R8 fixture catalog not found: $FixtureCatalogPath"
}

$registry = Read-YamlFile $RegistryPath
$nodeRegistryPath = Resolve-R8ProjectPath $ProjectRoot ([string](Get-R8Value $registry 'node_registry_ref'))
if ($null -eq $nodeRegistryPath -or -not (Test-Path -LiteralPath $nodeRegistryPath -PathType Leaf)) {
  throw "R8 node registry reference is invalid."
}
$nodeRegistry = Read-YamlFile $nodeRegistryPath
$catalog = Get-Content -LiteralPath $FixtureCatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json

$caseResults = [System.Collections.Generic.List[object]]::new()
foreach ($fixture in @($catalog.cases)) {
  $mutated = Invoke-R8Mutation $registry ([string]$fixture.mutation)
  $validation = Test-R8Registry $mutated $ProjectRoot $nodeRegistry
  $actual = [string]$validation.structural_result
  $expected = [string]$fixture.expected_result
  $caseResults.Add([pscustomobject][ordered]@{
    fixture_id = [string]$fixture.fixture_id
    mutation = [string]$fixture.mutation
    expected_result = $expected
    actual_result = $actual
    assertion_result = $(if ($actual -eq $expected) { 'pass' } else { 'fail' })
    error_count = @($validation.errors).Count
    errors = [object[]]$validation.errors
  })
}

$baseline = Test-R8Registry $registry $ProjectRoot $nodeRegistry
$failedCases = @($caseResults | Where-Object { $_.assertion_result -ne 'pass' })
$overall = if (@($baseline.errors).Count -gt 0 -or $failedCases.Count -gt 0) {
  'fail'
} elseif (@($baseline.debts).Count -gt 0) {
  'pass_with_warnings'
} else {
  'pass'
}
$report = [pscustomobject][ordered]@{
  schema_id = 'taoge://reports/r8/skill-context-h1/v0.1'
  generated_at = [DateTimeOffset]::UtcNow.ToString('o')
  registry_id = [string](Get-R8Value $registry 'registry_id')
  registry_path = 'routes/r8-skill-context-registry.yaml'
  fixture_set_id = [string]$catalog.fixture_set_id
  overall_result = $overall
  skill_count = @(Get-R8Items (Get-R8Value $registry 'skills')).Count
  structural_error_count = @($baseline.errors).Count
  known_context_debt_count = @($baseline.debts).Count
  known_context_debts = [object[]]$baseline.debts
  warnings = [object[]]$baseline.warnings
  fixture_case_count = $caseResults.Count
  fixture_pass_count = $caseResults.Count - $failedCases.Count
  fixture_fail_count = $failedCases.Count
  cases = [object[]]$caseResults.ToArray()
  network_called = $false
  provider_called = $false
  private_account_used = $false
  publishing_called = $false
  public_profile_validation = 'not_run_in_current_dev_profile'
}
Write-TaogeUtf8NoBomJson -Path $ReportPath -Value $report -Depth 60

Write-Output "R8_H1_SKILL_CONTEXT_CHECK=$overall"
Write-Output "SKILL_COUNT=$($report.skill_count)"
Write-Output "FIXTURE_CASE_COUNT=$($report.fixture_case_count)"
Write-Output "FIXTURE_FAIL_COUNT=$($report.fixture_fail_count)"
Write-Output "KNOWN_CONTEXT_DEBT_COUNT=$($report.known_context_debt_count)"
Write-Output "REPORT=$ReportPath"

if ($overall -eq 'fail') { exit 1 }
exit 0
