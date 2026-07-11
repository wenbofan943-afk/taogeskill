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
