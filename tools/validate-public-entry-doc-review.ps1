param(
  [string]$ProjectRoot = '',
  [string]$ContractPath = '',
  [string]$ReportPath = '',
  [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'YamlHelper.ps1')

function New-ReviewFinding {
  param([string]$Id, [string]$Status, [string]$Evidence, [string]$Remediation)
  return [pscustomobject]@{
    check_id = $Id
    status = $Status
    evidence = $Evidence
    remediation = $Remediation
  }
}

function Get-EntryDocumentText {
  param([string]$Root, [string]$RelativePath, [hashtable]$Overrides)
  if ($null -ne $Overrides -and $Overrides.ContainsKey($RelativePath)) {
    return [string]$Overrides[$RelativePath]
  }
  $path = Join-Path $Root $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "missing_document:$RelativePath"
  }
  return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}

function Invoke-PublicEntryDocumentReview {
  param([string]$Root, [string]$ResolvedContractPath, [hashtable]$Overrides = @{})

  $findings = New-Object 'System.Collections.Generic.List[object]'
  $errors = New-Object 'System.Collections.Generic.List[string]'
  $contract = Read-YamlFile -Path $ResolvedContractPath
  foreach ($key in @('schema_version', 'contract_id', 'current_release_version', 'homepage_role', 'release_blocking', 'policy', 'entry_documents')) {
    if (-not $contract.Contains($key)) {
      $errors.Add("missing_contract_key:$key")
      $findings.Add((New-ReviewFinding "PUBLIC-DOC-001-$key" 'fail' "contract_key_missing=$key" 'Restore the required public-entry review contract field.'))
    }
  }

  $versionPath = Join-Path $Root 'VERSION'
  if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
    $errors.Add('missing_VERSION')
    $findings.Add((New-ReviewFinding 'PUBLIC-DOC-002' 'fail' 'VERSION missing' 'Restore VERSION before public-document review.'))
  } else {
    $actualVersion = [System.IO.File]::ReadAllText($versionPath, [System.Text.Encoding]::UTF8).Trim()
    $declaredVersion = [string]$contract['current_release_version']
    $versionStatus = if ($actualVersion -eq $declaredVersion) { 'pass' } else { 'fail' }
    if ($versionStatus -eq 'fail') { $errors.Add("contract_version_mismatch:$declaredVersion!=$actualVersion") }
    $findings.Add((New-ReviewFinding 'PUBLIC-DOC-002' $versionStatus "contract_version=$declaredVersion;VERSION=$actualVersion" 'Update the review contract for the candidate version before public build.'))
  }

  $policy = $contract['policy']
  $allowedStatuses = @($policy['required_review_statuses'])
  $seenPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  $entries = @($contract['entry_documents'])
  if ($entries.Count -eq 0) {
    $errors.Add('entry_documents_empty')
    $findings.Add((New-ReviewFinding 'PUBLIC-DOC-003' 'fail' 'entry_documents empty' 'Register every public entry document.'))
  }

  foreach ($entry in $entries) {
    $relativePath = [string]$entry['path']
    $entryId = 'PUBLIC-DOC-' + ('{0:d3}' -f ($findings.Count + 3))
    if ([string]::IsNullOrWhiteSpace($relativePath)) {
      $errors.Add('entry_path_missing')
      $findings.Add((New-ReviewFinding $entryId 'fail' 'entry path missing' 'Give the review entry a repository-relative path.'))
      continue
    }
    if (-not $seenPaths.Add($relativePath)) {
      $errors.Add("duplicate_entry:$relativePath")
      $findings.Add((New-ReviewFinding $entryId 'fail' "duplicate_entry=$relativePath" 'Keep exactly one review record per public entry document.'))
      continue
    }

    $status = [string]$entry['review_status']
    $reason = [string]$entry['review_reason']
    if ($allowedStatuses -notcontains $status -or [string]::IsNullOrWhiteSpace($reason)) {
      $errors.Add("review_attestation_invalid:$relativePath")
      $findings.Add((New-ReviewFinding $entryId 'fail' "path=$relativePath;review_status=$status;reason_present=$(-not [string]::IsNullOrWhiteSpace($reason))" 'Record reviewed_updated or reviewed_no_change and a concrete reason for this candidate.'))
      continue
    }

    try {
      $text = Get-EntryDocumentText -Root $Root -RelativePath $relativePath -Overrides $Overrides
    } catch {
      $errors.Add($_.Exception.Message)
      $findings.Add((New-ReviewFinding $entryId 'fail' $_.Exception.Message 'Restore the entry document or remove it only through an approved public-entry contract change.'))
      continue
    }

    $missingTokens = New-Object 'System.Collections.Generic.List[string]'
    foreach ($token in @($entry['required_tokens'])) {
      if (-not [string]::IsNullOrWhiteSpace([string]$token) -and -not $text.Contains([string]$token)) { $missingTokens.Add([string]$token) }
    }
    $forbiddenHits = New-Object 'System.Collections.Generic.List[string]'
    foreach ($token in @($entry['forbidden_tokens'])) {
      if (-not [string]::IsNullOrWhiteSpace([string]$token) -and $text.Contains([string]$token)) { $forbiddenHits.Add([string]$token) }
    }
    $entryStatus = if ($missingTokens.Count -eq 0 -and $forbiddenHits.Count -eq 0) { 'pass' } else { 'fail' }
    if ($entryStatus -eq 'fail') { $errors.Add("entry_content_invalid:$relativePath") }
    $evidence = "path=$relativePath;review_status=$status;missing_required=$([string]::Join('|', @($missingTokens)));forbidden_hits=$([string]::Join('|', @($forbiddenHits)))"
    $findings.Add((New-ReviewFinding $entryId $entryStatus $evidence 'Update the entry document or its approved candidate review contract; do not ship stale public claims.'))
  }

  $readmeEntry = @($entries | Where-Object { [string]$_['path'] -eq 'README.md' })
  $readmeStatus = if ($readmeEntry.Count -eq 1 -and [string]$contract['homepage_role'] -eq 'current_public_landing_only') { 'pass' } else { 'fail' }
  if ($readmeStatus -eq 'fail') { $errors.Add('homepage_role_or_readme_registration_invalid') }
  $findings.Add((New-ReviewFinding 'PUBLIC-DOC-090' $readmeStatus "homepage_role=$([string]$contract['homepage_role']);readme_entries=$($readmeEntry.Count)" 'README must be registered once and declared as the current public landing page.'))

  return [pscustomobject]@{
    overall_result = if ($errors.Count -eq 0) { 'pass' } else { 'fail' }
    error_count = $errors.Count
    errors = [object[]]$errors.ToArray()
    findings = [object[]]$findings.ToArray()
  }
}

try {
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
  $root = Resolve-TaogeFileSystemPath -Path $ProjectRoot
  if ([string]::IsNullOrWhiteSpace($ContractPath)) { $ContractPath = Join-Path $root 'docs\governance\public-entry-document-review.yaml' }
  $resolvedContractPath = Resolve-TaogeFileSystemPath -Path $ContractPath
  if ([string]::IsNullOrWhiteSpace($ReportPath)) { $ReportPath = Join-Path $root 'state\checks\public-entry-doc-review-report.json' }
  $resolvedReportPath = [System.IO.Path]::GetFullPath($ReportPath)

  $review = Invoke-PublicEntryDocumentReview -Root $root -ResolvedContractPath $resolvedContractPath
  $selfTestResult = 'not_run'
  $selfTestEvidence = @()
  if ($SelfTest) {
    $currentReadme = Get-EntryDocumentText -Root $root -RelativePath 'README.md' -Overrides @{}
    $negative = Invoke-PublicEntryDocumentReview -Root $root -ResolvedContractPath $resolvedContractPath -Overrides @{ 'README.md' = ($currentReadme + "`n`nv1.9.1`nPowerShell 7 为推荐宿主") }
    $selfTestResult = if ($review.overall_result -eq 'pass' -and $negative.overall_result -eq 'fail') { 'pass' } else { 'fail' }
    $selfTestEvidence = @("base=$($review.overall_result)", "stale_readme_negative=$($negative.overall_result)")
  }
  $overall = if ($review.overall_result -eq 'pass' -and $selfTestResult -ne 'fail') { 'pass' } else { 'fail' }
  $report = [ordered]@{
    schema_id = 'taoge://reports/public-entry-document-review/v0.1'
    command_name = 'validate-public-entry-doc-review'
    project_root = $root
    contract_path = $resolvedContractPath
    overall_result = $overall
    exit_code = if ($overall -eq 'pass') { 0 } else { 1 }
    review = $review
    self_test = [ordered]@{ result = $selfTestResult; evidence = [object[]]$selfTestEvidence }
  }
  Write-TaogeUtf8NoBomJson -Path $resolvedReportPath -Value $report -Depth 20
  Write-Output "PUBLIC_ENTRY_DOCUMENT_REVIEW=$overall"
  if ($SelfTest) { Write-Output "PUBLIC_ENTRY_DOCUMENT_REVIEW_SELF_TEST=$selfTestResult" }
  Write-Output "REPORT=$resolvedReportPath"
  if ($overall -ne 'pass') { exit 1 }
  exit 0
} catch {
  Write-Error ('PUBLIC_ENTRY_DOCUMENT_REVIEW_ERROR=' + $_.Exception.Message)
  exit 3
}
