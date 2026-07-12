param(
  [string]$TargetPath = ".",
  [string]$SchemaPath = "templates/schema/field-schema.v0.1.json",
  [string]$HumanReportPath = "",
  [string]$MachineReportPath = ""
)

$ErrorActionPreference = "Stop"

$yamlHelperPath = Join-Path $PSScriptRoot "YamlHelper.ps1"
if (Test-Path -LiteralPath $yamlHelperPath) {
  . $yamlHelperPath
}

function Get-RelativePathSafe {
  param([string]$BasePath, [string]$Path)
  $base = (Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\') + '\'
  $full = (Resolve-Path -LiteralPath $Path).Path
  if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $full.Substring($base.Length)
  }
  return $full
}

function New-Check {
  param(
    [string]$Id,
    [string]$Group,
    [string]$Status,
    [string]$Evidence,
    [string]$Remediation
  )
  [pscustomobject]@{
    check_item_id = $Id
    group = $Group
    severity = "blocker"
    status = $Status
    evidence = $Evidence
    remediation = $Remediation
  }
}

function Test-MapHasValue {
  param(
    [object]$Map,
    [string]$Field
  )
  if ($null -eq $Map) { return $false }
  if ($Map -is [hashtable] -or $Map -is [System.Collections.Specialized.OrderedDictionary]) {
    return $Map.Contains($Field) -and -not [string]::IsNullOrWhiteSpace([string]$Map[$Field])
  }
  return $Map.PSObject.Properties.Name.Contains($Field) -and -not [string]::IsNullOrWhiteSpace([string]$Map.$Field)
}

function Get-MapValue {
  param(
    [object]$Map,
    [string]$Field
  )
  if ($null -eq $Map) { return "" }
  if ($Map -is [hashtable] -or $Map -is [System.Collections.Specialized.OrderedDictionary]) {
    if ($Map.Contains($Field)) { return [string]$Map[$Field] }
    return ""
  }
  if ($Map.PSObject.Properties.Name.Contains($Field)) { return [string]$Map.$Field }
  return ""
}

try {
  if (-not (Test-Path -LiteralPath $TargetPath)) {
    Write-Error "TargetPath not found: $TargetPath"
    exit 4
  }
  if (-not (Test-Path -LiteralPath $SchemaPath)) {
    Write-Error "SchemaPath not found: $SchemaPath"
    exit 4
  }

  $target = (Resolve-Path -LiteralPath $TargetPath).Path
  $schema = Get-Content -LiteralPath $SchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
  $defaultReportDir = if ($target -eq $projectRoot) { Join-Path $projectRoot 'state\checks' } else { $target }

  if ([string]::IsNullOrWhiteSpace($HumanReportPath)) {
    $HumanReportPath = Join-Path $defaultReportDir "field-schema-check-report.md"
  }
  if ([string]::IsNullOrWhiteSpace($MachineReportPath)) {
    $MachineReportPath = Join-Path $defaultReportDir "field-schema-check-report.json"
  }
  @($HumanReportPath, $MachineReportPath) | ForEach-Object {
    $reportDir = Split-Path -Parent $_
    if (-not [string]::IsNullOrWhiteSpace($reportDir) -and -not (Test-Path -LiteralPath $reportDir)) {
      New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
  }

  $checks = New-Object System.Collections.Generic.List[object]
  $checkRunId = "FIELD-SCHEMA-" + (Get-Date -Format "yyyyMMdd-HHmmss")

  $releasePath = Join-Path $target $schema.artifacts.release_record.path
  if (Test-Path -LiteralPath $releasePath) {
    $release = (Get-Content -LiteralPath $releasePath -Raw -Encoding UTF8 | ConvertFrom-Json).release_record
    foreach ($field in $schema.artifacts.release_record.required_fields) {
      $status = if ($null -ne $release.$field -and "$($release.$field)" -ne "") { "pass" } else { "fail" }
      $checks.Add((New-Check "SCHEMA-REL-REQ-$field" "release_record" $status $field "Add required release_record field."))
    }
    foreach ($field in $schema.artifacts.release_record.enum_fields.PSObject.Properties.Name) {
      $enumName = $schema.artifacts.release_record.enum_fields.$field
      $allowed = if ($enumName -eq "next_skill_allowed") { @($schema.next_skill_allowed) } else { @($schema.enums.$enumName) }
      $value = "$($release.$field)"
      $status = if ($allowed -contains $value) { "pass" } else { "fail" }
      $checks.Add((New-Check "SCHEMA-REL-ENUM-$field" "release_record" $status "$field=$value" "Use allowed $field value."))
    }
  } else {
    $checks.Add((New-Check "SCHEMA-REL-FILE" "release_record" "warning" "release-record.json missing" "Build public release before release schema validation."))
  }

  $sampleDirs = @(Get-ChildItem -LiteralPath (Join-Path $target "examples") -Directory -Filter "sample-*" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^sample-\d{2}-' })
  if ($sampleDirs.Count -eq 0) {
    $checks.Add((New-Check "SCHEMA-SAMPLE-FILES" "sample_record" "fail" "No examples/sample-* directories" "Add P4 sample directories."))
  }
  foreach ($dir in $sampleDirs) {
    $manifestPath = Join-Path $dir.FullName "manifest.yaml"
    if (-not (Test-Path -LiteralPath $manifestPath)) {
      $checks.Add((New-Check "SCHEMA-SAMPLE-MANIFEST-$($dir.Name)" "sample_record" "fail" "$($dir.Name)/manifest.yaml missing" "Add sample manifest.yaml."))
      continue
    }

    $manifest = Read-YamlFile $manifestPath

    foreach ($field in $schema.artifacts.sample_record.required_fields) {
      $status = if (Test-MapHasValue $manifest $field) { "pass" } else { "fail" }
      $checks.Add((New-Check "SCHEMA-SAMPLE-REQ-$($dir.Name)-$field" "sample_record" $status "$($dir.Name):$field" "Add required sample_record field."))
    }
    foreach ($field in $schema.artifacts.sample_record.enum_fields.PSObject.Properties.Name) {
      $enumName = $schema.artifacts.sample_record.enum_fields.$field
      $allowed = @($schema.enums.$enumName)
      $value = Get-MapValue $manifest $field
      $status = if ($allowed -contains $value) { "pass" } else { "fail" }
      $checks.Add((New-Check "SCHEMA-SAMPLE-ENUM-$($dir.Name)-$field" "sample_record" $status "$($dir.Name):$field=$value" "Use allowed $field value."))
    }
  }

  if ($schema.artifacts.PSObject.Properties.Name -contains "regression_suite") {
    $suitePath = Join-Path $target $schema.artifacts.regression_suite.path
    if (Test-Path -LiteralPath $suitePath) {
      $suiteText = Get-Content -LiteralPath $suitePath -Raw -Encoding UTF8
      $suiteMap = Read-YamlFile $suitePath
      foreach ($field in $schema.artifacts.regression_suite.required_fields) {
        $status = if (Test-MapHasValue $suiteMap $field) { "pass" } else { "fail" }
        $checks.Add((New-Check "SCHEMA-REGSUITE-REQ-$field" "regression_suite" $status $field "Add required regression suite field."))
      }
      foreach ($text in $schema.artifacts.regression_suite.required_text) {
        $status = if ($suiteText.Contains($text)) { "pass" } else { "fail" }
        $checks.Add((New-Check "SCHEMA-REGSUITE-TEXT-$($text.Replace(':','-').Replace(' ','_'))" "regression_suite" $status $text "Add required regression suite fixture text."))
      }
    } else {
      $checks.Add((New-Check "SCHEMA-REGSUITE-FILE" "regression_suite" "fail" "examples/regression-suite.yaml missing" "Add regression suite manifest."))
    }
  }

  if ($schema.artifacts.PSObject.Properties.Name -contains "p0_h1_contract_suite") {
    $p0SuitePath = Join-Path $target $schema.artifacts.p0_h1_contract_suite.path
    if (Test-Path -LiteralPath $p0SuitePath) {
      $p0Suite = Get-Content -LiteralPath $p0SuitePath -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($field in $schema.artifacts.p0_h1_contract_suite.required_fields) {
        $status = if ($p0Suite.PSObject.Properties.Name -contains $field -and $null -ne $p0Suite.$field -and "$($p0Suite.$field)" -ne '') { 'pass' } else { 'fail' }
        $checks.Add((New-Check "SCHEMA-P0H1-REQ-$field" "p0_h1_contract_suite" $status $field "Add required P0-H1 contract suite field."))
      }
      $fixtureIds = @($p0Suite.cases | ForEach-Object { [string]$_.fixture_id })
      foreach ($fixtureId in $schema.artifacts.p0_h1_contract_suite.required_fixture_ids) {
        $status = if ($fixtureIds -contains $fixtureId) { 'pass' } else { 'fail' }
        $checks.Add((New-Check "SCHEMA-P0H1-FIXTURE-$fixtureId" "p0_h1_contract_suite" $status $fixtureId "Add required P0-H1 fixture case."))
      }
    } else {
      $checks.Add((New-Check "SCHEMA-P0H1-FILE" "p0_h1_contract_suite" "fail" "examples/p0-h1-contract-fixtures/fixtures.json missing" "Add the P0-H1 contract fixture suite."))
    }
  }

  if ($schema.artifacts.PSObject.Properties.Name -contains "p0_h2_runtime_fixture") {
    $p0H2FixturePath = Join-Path $target $schema.artifacts.p0_h2_runtime_fixture.path
    if (Test-Path -LiteralPath $p0H2FixturePath) {
      $p0H2Fixture = Get-Content -LiteralPath $p0H2FixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($field in $schema.artifacts.p0_h2_runtime_fixture.required_fields) {
        $status = if ($p0H2Fixture.PSObject.Properties.Name -contains $field -and $null -ne $p0H2Fixture.$field -and "$($p0H2Fixture.$field)" -ne '') { 'pass' } else { 'fail' }
        $checks.Add((New-Check "SCHEMA-P0H2-REQ-$field" "p0_h2_runtime_fixture" $status $field "Add required P0-H2 runtime fixture field."))
      }
    } else {
      $checks.Add((New-Check "SCHEMA-P0H2-FILE" "p0_h2_runtime_fixture" "fail" "P0-H2 runtime fixture missing" "Add the P0-H2 runtime fixture."))
    }
  }

  if ($schema.artifacts.PSObject.Properties.Name -contains "p0_h3_recovery_suite") {
    $p0H3SuitePath = Join-Path $target $schema.artifacts.p0_h3_recovery_suite.path
    if (Test-Path -LiteralPath $p0H3SuitePath) {
      $p0H3Suite = Get-Content -LiteralPath $p0H3SuitePath -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($field in $schema.artifacts.p0_h3_recovery_suite.required_fields) {
        $status = if ($p0H3Suite.PSObject.Properties.Name -contains $field -and $null -ne $p0H3Suite.$field -and "$($p0H3Suite.$field)" -ne '') { 'pass' } else { 'fail' }
        $checks.Add((New-Check "SCHEMA-P0H3-REQ-$field" "p0_h3_recovery_suite" $status $field "Add required P0-H3 recovery suite field."))
      }
      $fixtureIds = @($p0H3Suite.cases | ForEach-Object { [string]$_.fixture_id })
      foreach ($fixtureId in $schema.artifacts.p0_h3_recovery_suite.required_fixture_ids) {
        $status = if ($fixtureIds -contains $fixtureId) { 'pass' } else { 'fail' }
        $checks.Add((New-Check "SCHEMA-P0H3-FIXTURE-$fixtureId" "p0_h3_recovery_suite" $status $fixtureId "Add required P0-H3 fixture case."))
      }
      $resultSchemaPath = Join-Path $target 'templates/schema/p0-h3/fixture-result.v0.2.schema.json'
      if (Test-Path -LiteralPath $resultSchemaPath) {
        $resultSchemaText = Get-Content -LiteralPath $resultSchemaPath -Raw -Encoding UTF8
        foreach ($field in $schema.artifacts.p0_h3_recovery_suite.required_result_fields) {
          $status = if ($resultSchemaText.Contains(('"' + $field + '"'))) { 'pass' } else { 'fail' }
          $checks.Add((New-Check "SCHEMA-P0H3-RESULT-$field" "p0_h3_fixture_result" $status $field "Add required P0-H3 unified result field."))
        }
      } else {
        $checks.Add((New-Check "SCHEMA-P0H3-RESULT-FILE" "p0_h3_fixture_result" "fail" "templates/schema/p0-h3/fixture-result.v0.2.schema.json missing" "Add the P0-H3 result schema."))
      }
    } else {
      $checks.Add((New-Check "SCHEMA-P0H3-FILE" "p0_h3_recovery_suite" "fail" "P0-H3 recovery suite missing" "Add the P0-H3 recovery fixture suite."))
    }
  }

  if ($schema.artifacts.PSObject.Properties.Name -contains "p0_h4_evidence_fixture") {
    $p0H4FixturePath = Join-Path $target $schema.artifacts.p0_h4_evidence_fixture.path
    if (Test-Path -LiteralPath $p0H4FixturePath) {
      $p0H4Fixture = Get-Content -LiteralPath $p0H4FixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($field in $schema.artifacts.p0_h4_evidence_fixture.required_fields) {
        $status = if ($p0H4Fixture.PSObject.Properties.Name -contains $field -and $null -ne $p0H4Fixture.$field) { 'pass' } else { 'fail' }
        $checks.Add((New-Check "SCHEMA-P0H4-REQ-$field" "p0_h4_evidence_fixture" $status $field "Add required P0-H4 evidence fixture field."))
      }
      $commandPath = Join-Path $target 'tools/invoke-p0-evidence.ps1'
      $commandText = if (Test-Path -LiteralPath $commandPath) { Get-Content -LiteralPath $commandPath -Raw -Encoding UTF8 } else { '' }
      foreach ($command in $schema.artifacts.p0_h4_evidence_fixture.required_commands) {
        $status = if ($commandText.Contains($command)) { 'pass' } else { 'fail' }
        $checks.Add((New-Check "SCHEMA-P0H4-COMMAND-$command" "p0_h4_evidence_command" $status $command "Implement the required P0-H4 command."))
      }
      foreach ($relativePath in @($schema.artifacts.p0_h4_evidence_fixture.required_schema_files) + @($schema.artifacts.p0_h4_evidence_fixture.required_runtime_files)) {
        $status = if (Test-Path -LiteralPath (Join-Path $target $relativePath)) { 'pass' } else { 'fail' }
        $safeId = $relativePath.Replace('/','-').Replace('\','-').Replace('.','-')
        $checks.Add((New-Check "SCHEMA-P0H4-FILE-$safeId" "p0_h4_evidence_files" $status $relativePath "Add the required P0-H4 runtime or schema file."))
      }
    } else {
      $checks.Add((New-Check "SCHEMA-P0H4-FIXTURE" "p0_h4_evidence_fixture" "fail" "P0-H4 evidence fixture missing" "Add the P0-H4 evidence fixture."))
    }
  }

  if ($schema.artifacts.PSObject.Properties.Name -contains 'p0_h7_runtime_fixture') {
    $h7Definition=$schema.artifacts.p0_h7_runtime_fixture;$h7Path=Join-Path $target $h7Definition.path
    if(Test-Path -LiteralPath $h7Path){$h7=Get-Content -LiteralPath $h7Path -Raw -Encoding UTF8|ConvertFrom-Json;foreach($field in $h7Definition.required_fields){$status=if($h7.PSObject.Properties.Name-contains$field){'pass'}else{'fail'};$checks.Add((New-Check "SCHEMA-P0H7-REQ-$field" 'p0_h7_runtime_fixture' $status $field 'Add the required P0-H7 typed input field.'))};foreach($relativePath in $h7Definition.required_files){$status=if(Test-Path -LiteralPath (Join-Path $target $relativePath)){'pass'}else{'fail'};$safeId=$relativePath.Replace('/','-').Replace('\','-').Replace('.','-');$checks.Add((New-Check "SCHEMA-P0H7-FILE-$safeId" 'p0_h7_runtime_files' $status $relativePath 'Add the required P0-H7 runtime, schema, template, or checker file.'))}}else{$checks.Add((New-Check 'SCHEMA-P0H7-FIXTURE' 'p0_h7_runtime_fixture' 'fail' $h7Definition.path 'Add the P0-H7 runtime fixture.'))}
  }

  $templatePath = Join-Path $target $schema.artifacts.final_delivery_template.path
  if (Test-Path -LiteralPath $templatePath) {
    $template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
    foreach ($token in $schema.artifacts.final_delivery_template.required_tokens) {
      $status = if ($template.Contains($token)) { "pass" } else { "fail" }
      $checks.Add((New-Check "SCHEMA-FD-TOKEN-$token" "final_delivery_template" $status $token "Add required final_delivery template token."))
    }
    foreach ($field in $schema.artifacts.final_delivery_template.required_enum_tokens.PSObject.Properties.Name) {
      $enumName = $schema.artifacts.final_delivery_template.required_enum_tokens.$field
      $missingValues = @($schema.enums.$enumName | Where-Object { -not $template.Contains($_) })
      $status = if ($missingValues.Count -eq 0) { "pass" } else { "fail" }
      $checks.Add((New-Check "SCHEMA-FD-ENUMTOKENS-$field" "final_delivery_template" $status "$field missing: $([string]::Join(', ', $missingValues))" "Document all allowed $field states in template."))
    }
  } else {
    $checks.Add((New-Check "SCHEMA-FD-FILE" "final_delivery_template" "fail" "final-delivery.template.html missing" "Add final delivery template."))
  }

  $manifestPath = Join-Path $target $schema.artifacts.public_manifest.path
  if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
    $manifestMap = Read-YamlFile $manifestPath
    foreach ($field in $schema.artifacts.public_manifest.required_fields) {
      $status = if (Test-MapHasValue $manifestMap $field) { "pass" } else { "fail" }
      $checks.Add((New-Check "SCHEMA-PUBMAN-REQ-$field" "public_manifest" $status $field "Add required public manifest field."))
    }
    foreach ($text in $schema.artifacts.public_manifest.required_text) {
      $status = if ($manifestText.Contains($text)) { "pass" } else { "fail" }
      $checks.Add((New-Check "SCHEMA-PUBMAN-TEXT-$($text.Replace(':','-').Replace(' ','_'))" "public_manifest" $status $text "Align public manifest publish state."))
    }
  } else {
    $checks.Add((New-Check "SCHEMA-PUBMAN-FILE" "public_manifest" "fail" "public-manifest.yaml missing" "Add public manifest."))
  }

  $failed = @($checks | Where-Object { $_.status -eq "fail" })
  $exitCode = if ($failed.Count -gt 0) { 1 } else { 0 }
  $overall = if ($exitCode -eq 0) { "pass" } else { "fail" }

  $report = [ordered]@{
    field_schema_check_report = [ordered]@{
      check_run_id = $checkRunId
      schema_id = $schema.schema_id
      schema_version = $schema.schema_version
      exit_code = $exitCode
      overall_result = $overall
      blocker_count = $failed.Count
      target_path = $target
      checks = [object[]]$checks.ToArray()
    }
  }
  $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $MachineReportPath -Encoding UTF8

  $lines = @("# Field Schema Check Report", "", '```yaml')
  $lines += "check_run_id: $checkRunId"
  $lines += "schema_version: $($schema.schema_version)"
  $lines += "exit_code: $exitCode"
  $lines += "overall_result: $overall"
  $lines += "blocker_count: $($failed.Count)"
  $lines += '```'
  $lines += ""
  $lines += "| Check ID | Group | Status | Evidence | Remediation |"
  $lines += "|---|---|---|---|---|"
  foreach ($check in $checks) {
    $lines += "| $($check.check_item_id) | $($check.group) | $($check.status) | $($check.evidence) | $($check.remediation) |"
  }
  $lines | Set-Content -LiteralPath $HumanReportPath -Encoding UTF8

  if ($exitCode -eq 0) {
    Write-Output "FIELD_SCHEMA_CHECK=pass"
  } else {
    Write-Output "FIELD_SCHEMA_CHECK=fail"
  }
  exit $exitCode
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
