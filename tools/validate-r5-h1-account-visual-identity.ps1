param(
  [string]$FixturePath = 'examples/r5-h1-account-visual-identity-fixtures/fixtures.json',
  [string]$ReportPath = 'state/checks/r5-h1-account-visual-identity-report.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

function Resolve-R5H1Path([string]$Path) {
  if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
  return [IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

function Has-R5H1([object]$Object, [string]$Name) {
  return $null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name
}

function Test-R5H1NonEmptyString([object]$Value) {
  return $Value -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$Value)
}

function Test-R5H1NonEmptyArray([object]$Value) {
  return $null -ne $Value -and @($Value).Count -gt 0 -and @($Value | Where-Object { -not (Test-R5H1NonEmptyString $_) }).Count -eq 0
}

function Test-R5H1Identity([object]$Identity, [object]$Columns) {
  $errors = New-Object System.Collections.Generic.List[string]
  $required = @('schema_id','schema_version','identity_id','account_slug','identity_status','visual_promise','evidence_visual_grammar','cover_hierarchy','tone_and_color_direction','negative_aesthetics','image_count_policy','column_visual_template_refs','identity_override_policy')
  foreach ($field in $required) { if (-not (Has-R5H1 $Identity $field)) { $errors.Add("missing:$field") } }
  if ($errors.Count) { return @($errors) }
  $identitySchema = [string]$Identity.schema_id
  $identityVersion = [string]$Identity.schema_version
  $isV01 = $identitySchema -eq 'taoge://schemas/r5/account-visual-identity/v0.1' -and $identityVersion -eq '0.1'
  $isV02 = $identitySchema -eq 'taoge://schemas/r5/account-visual-identity/v0.2' -and $identityVersion -eq '0.2'
  if (-not $isV01 -and -not $isV02) { $errors.Add('schema_version_pair_invalid') }
  if ($isV02) {
    foreach ($field in @('account_identity_id','account_technical_slug')) { if (-not (Has-R5H1 $Identity $field) -or -not (Test-R5H1NonEmptyString $Identity.$field)) { $errors.Add("missing_or_blank:$field") } }
    if ((Has-R5H1 $Identity 'account_technical_slug') -and [string]$Identity.account_technical_slug -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { $errors.Add('account_technical_slug_invalid') }
  }
  foreach ($field in @('identity_id','account_slug','visual_promise','tone_and_color_direction','identity_override_policy')) { if (-not (Test-R5H1NonEmptyString $Identity.$field)) { $errors.Add("blank:$field") } }
  if (@('identity_draft','identity_active','identity_needs_revision','identity_archived') -notcontains [string]$Identity.identity_status) { $errors.Add('identity_status_invalid') }
  if (-not (Test-R5H1NonEmptyArray $Identity.evidence_visual_grammar)) { $errors.Add('evidence_visual_grammar_invalid') }
  if (-not (Test-R5H1NonEmptyArray $Identity.cover_hierarchy)) { $errors.Add('cover_hierarchy_invalid') }
  if (-not (Test-R5H1NonEmptyArray $Identity.negative_aesthetics)) { $errors.Add('negative_aesthetics_invalid') }
  if (-not (Test-R5H1NonEmptyArray $Identity.column_visual_template_refs)) { $errors.Add('column_visual_template_refs_invalid') }
  if ([string]$Identity.image_count_policy -ne 'content_derived_by_r3_0_to_n') { $errors.Add('image_count_policy_must_be_content_derived') }
  if ([string]$Identity.identity_override_policy -ne 'reason_required') { $errors.Add('identity_override_policy_invalid') }
  if (Has-R5H1 $Identity 'max_image_count' -or Has-R5H1 $Identity 'min_image_count' -or Has-R5H1 $Identity 'provider_call_limit') { $errors.Add('identity_cannot_set_cardinality_or_call_limit') }
  $expectedColumnSchema = if ($isV02) { 'taoge://schemas/r5/column-visual-templates/v0.2' } else { 'taoge://schemas/r5/column-visual-templates/v0.1' }
  $expectedColumnVersion = if ($isV02) { '0.2' } else { '0.1' }
  if (-not (Has-R5H1 $Columns 'schema_id') -or [string]$Columns.schema_id -ne $expectedColumnSchema -or -not (Has-R5H1 $Columns 'schema_version') -or [string]$Columns.schema_version -ne $expectedColumnVersion) { $errors.Add('column_schema_version_pair_invalid') }
  if (-not (Has-R5H1 $Columns 'account_slug') -or [string]$Columns.account_slug -ne [string]$Identity.account_slug) { $errors.Add('column_account_scope_mismatch') }
  if ($isV02) {
    foreach ($field in @('account_identity_id','account_technical_slug')) {
      if (-not (Has-R5H1 $Columns $field) -or [string]$Columns.$field -ne [string]$Identity.$field) { $errors.Add("column_identity_mismatch:$field") }
    }
  }
  $ids = @{}
  foreach ($template in @($Columns.templates)) {
    foreach ($field in @('column_template_id','column_name','applies_when','viewer_job','preferred_visual_roles','cover_hierarchy_override','visual_rules','prohibited_patterns')) {
      if (-not (Has-R5H1 $template $field)) { $errors.Add("column_missing:$field"); continue }
      if ($field -in @('preferred_visual_roles','visual_rules','prohibited_patterns') -and -not (Test-R5H1NonEmptyArray $template.$field)) { $errors.Add("column_array_invalid:$field") }
    }
    if (Has-R5H1 $template 'column_template_id') {
      $id = [string]$template.column_template_id
      if ($ids.ContainsKey($id)) { $errors.Add('column_template_id_duplicate') } else { $ids[$id] = $true }
    }
    if (Has-R5H1 $template 'image_count_policy' -or Has-R5H1 $template 'max_image_count') { $errors.Add('column_cannot_set_cardinality') }
  }
  return @($errors)
}

try {
  $fixtureFull = Resolve-R5H1Path $FixturePath
  if (-not (Test-Path -LiteralPath $fixtureFull)) { throw 'fixture_missing' }
  $fixture = Get-Content -LiteralPath $fixtureFull -Raw -Encoding UTF8 | ConvertFrom-Json
  $results = New-Object System.Collections.Generic.List[object]
  foreach ($case in @($fixture.cases)) {
    $errors = @(Test-R5H1Identity $case.identity $case.column_templates)
    $actual = if ($errors.Count) { 'fail' } else { 'pass' }
    $results.Add([ordered]@{fixture_id=[string]$case.fixture_id;expected_result=[string]$case.expected_result;actual_result=$actual;expectation_met=($actual -eq [string]$case.expected_result);errors=$errors})
  }
  # Keep this PowerShell 5.1 executable ASCII-only. The referenced source files
  # intentionally retain their native Chinese names.
  $productDocument = [string]::Concat([char[]]@(0x8D26,0x53F7,0x89C6,0x89C9,0x8EAB,0x4EFD,0x4E0E,0x4E8C,0x624B,0x8F66,0x4F18,0x5148,0x70ED,0x70B9,0x96F7,0x8FBE)) + '.md'
  $fieldDictionary = [string]::Concat([char[]]@(0x4EA4,0x63A5,0x7269,0x5B57,0x6BB5,0x8BCD,0x5178)) + '.md'
  $coverage = @(
    @{ path=(Join-Path 'docs/product' ('R5-' + $productDocument)); tokens=@('visual_identity_ref','content_derived_by_r3_0_to_n','column_visual_template_refs') },
    @{ path=$fieldDictionary; tokens=@('account_visual_identity','identity_override_policy','content_derived_by_r3_0_to_n') },
    @{ path='skills/account-onboarding/CONTRACT.md'; tokens=@('R5-H1','visual-identity.yaml','identity_draft') },
    @{ path='skills/static-visual-director/CONTRACT.md'; tokens=@('identity_id','identity_override_reason','cannot set image count') },
    @{ path='templates/account/account_profile.template.md'; tokens=@('visual_identity_ref','column_visual_template_refs','content_derived_by_r3_0_to_n') },
    @{ path='templates/schema/r5/account-visual-identity.v0.1.schema.json'; tokens=@('identity_status','negative_aesthetics','content_derived_by_r3_0_to_n') },
    @{ path='templates/schema/r5/account-visual-identity.v0.2.schema.json'; tokens=@('account_identity_id','account_technical_slug','content_derived_by_r3_0_to_n') },
    @{ path='templates/schema/r5/column-visual-templates.v0.2.schema.json'; tokens=@('account_identity_id','account_technical_slug','column_template_id') },
    @{ path='templates/account/visual-identity.template.yaml'; tokens=@('account-visual-identity/v0.2','account_identity_id','account_technical_slug') },
    @{ path='templates/account/column-visual-templates.template.yaml'; tokens=@('column-visual-templates/v0.2','account_identity_id','account_technical_slug') },
    @{ path='tools/validate-public-release.ps1'; tokens=@('P3REL-032','validate-r5-h1-account-visual-identity.ps1','r5_account_visual_identity_contract') },
    @{ path='tools/build-public-release.ps1'; tokens=@('validate-r5-h1-account-visual-identity.ps1') }
  )
  $coverageIndex = 0
  foreach ($item in $coverage) {
    $coverageIndex++
    $full = Join-Path $projectRoot $item.path
    $errors = @()
    if (-not (Test-Path -LiteralPath $full)) { $errors += 'file_missing' } else { $text = Get-Content -LiteralPath $full -Raw -Encoding UTF8; foreach ($token in $item.tokens) { if (-not $text.Contains($token)) { $errors += "coverage_token_missing:$token" } } }
    $actual = if ($errors.Count) { 'fail' } else { 'pass' }
    $results.Add([ordered]@{fixture_id=("R5H1-COVERAGE-{0:d2}" -f $coverageIndex);expected_result='pass';actual_result=$actual;expectation_met=($actual -eq 'pass');errors=$errors})
  }
  $failed = @($results | Where-Object { -not $_.expectation_met })
  $overall = if ($failed.Count) { 'fail' } else { 'pass' }
  $report = [ordered]@{schema_id='taoge://reports/r5/h1-account-visual-identity/v0.1';schema_version='0.1';generated_at=[DateTimeOffset]::UtcNow.ToString('o');overall_result=$overall;case_count=$results.Count;failure_count=$failed.Count;results=[object[]]$results.ToArray()}
  $out = Resolve-R5H1Path $ReportPath
  $parent = Split-Path -Parent $out
  if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  Write-TaogeUtf8NoBomText -Path $out -Text (($report | ConvertTo-Json -Depth 40) + "`n") -EnsureFinalNewline
  Write-Output "R5_H1_ACCOUNT_VISUAL_IDENTITY_CHECK=$overall"
  Write-Output "CASE_COUNT=$($results.Count)"
  Write-Output "FAILURE_COUNT=$($failed.Count)"
  Write-Output "REPORT=$out"
  if ($failed.Count) { exit 1 }
  exit 0
} catch {
  Write-Error ('R5_H1_ACCOUNT_VISUAL_IDENTITY_CHECKER_ERROR=' + $_.Exception.Message + ';STACK=' + $_.ScriptStackTrace)
  exit 3
}
