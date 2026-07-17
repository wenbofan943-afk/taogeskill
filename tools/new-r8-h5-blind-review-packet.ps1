[CmdletBinding()]
param(
  [string]$ProjectRoot,
  [string]$EvaluationId = 'R8-H5-BLIND-20260717'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
. (Join-Path $ProjectRoot 'tools\WindowsRuntimeHelper.ps1')

$evidenceRoot = Join-Path $ProjectRoot ('state\checks\r8\' + $EvaluationId)
$sharedPath = Join-Path $evidenceRoot 'shared-input.json'
$baselinePath = Join-Path $evidenceRoot 'arm-baseline\raw-output.json'
$candidatePath = Join-Path $evidenceRoot 'arm-candidate\raw-output.json'
$mappingPath = Join-Path $evidenceRoot 'allocation-private.json'
$packetJsonPath = Join-Path $evidenceRoot 'blind-review-packet.json'
$packetMarkdownPath = Join-Path $evidenceRoot 'blind-review-packet.md'
$machineAuditPath = Join-Path $evidenceRoot 'machine-audit.json'
$fixturePath = Join-Path $ProjectRoot 'examples\r8-skill-context-fixtures\h5-ab-cases.json'

foreach ($requiredPath in @($sharedPath, $baselinePath, $candidatePath, $fixturePath)) {
  if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
    throw "Required H5 blind-review input is missing: $requiredPath"
  }
}

function Read-TaogeJsonFile {
  param([Parameter(Mandatory = $true)][string]$Path)
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-ArmOutput {
  param(
    [Parameter(Mandatory = $true)]$Output,
    [Parameter(Mandatory = $true)][string]$ExpectedRole,
    [Parameter(Mandatory = $true)][string[]]$ExpectedIds
  )

  if ([string]$Output.schema_id -ne 'taoge://reports/r8/h5-blind-arm-output/v0.1') {
    throw "$ExpectedRole output schema_id is invalid."
  }
  if ([string]$Output.evaluation_id -ne $EvaluationId) {
    throw "$ExpectedRole output evaluation_id is invalid."
  }
  if ([string]$Output.arm_role -ne $ExpectedRole) {
    throw "$ExpectedRole output arm_role is invalid."
  }

  $cases = @($Output.cases)
  $actualIds = @($cases | ForEach-Object { [string]$_.eval_id })
  if ($actualIds.Count -ne $ExpectedIds.Count) {
    throw "$ExpectedRole output case count is invalid."
  }
  if (@($actualIds | Sort-Object -Unique).Count -ne $actualIds.Count) {
    throw "$ExpectedRole output contains duplicate eval_id values."
  }
  foreach ($expectedId in $ExpectedIds) {
    if ($actualIds -notcontains $expectedId) {
      throw "$ExpectedRole output is missing eval_id: $expectedId"
    }
  }

  $requiredFields = @(
    'eval_id',
    'skill_id',
    'result_status',
    'actual_node_id',
    'loaded_reference_ids',
    'legacy_reference_loaded',
    'output_artifact_type',
    'output_payload',
    'contract_selection_result',
    'manual_assist_count',
    'notes'
  )
  foreach ($case in $cases) {
    $fieldNames = @($case.PSObject.Properties.Name)
    foreach ($requiredField in $requiredFields) {
      if ($fieldNames -notcontains $requiredField) {
        throw "$ExpectedRole output $($case.eval_id) is missing field: $requiredField"
      }
    }
    if (@('produced', 'waiting', 'blocked') -notcontains [string]$case.result_status) {
      throw "$ExpectedRole output $($case.eval_id) has invalid result_status."
    }
    if (@('pass', 'fail', 'not_applicable') -notcontains [string]$case.contract_selection_result) {
      throw "$ExpectedRole output $($case.eval_id) has invalid contract_selection_result."
    }
    if ($null -eq $case.manual_assist_count -or [int]$case.manual_assist_count -ne 0) {
      throw "$ExpectedRole output $($case.eval_id) is not an unassisted result."
    }
  }

  $serialized = $Output | ConvertTo-Json -Depth 50 -Compress
  if ($serialized -match '"expected_[^"]*"\s*:') {
    throw "$ExpectedRole output contains forbidden expected_* fields."
  }
}

function Get-CaseById {
  param(
    [Parameter(Mandatory = $true)]$Output,
    [Parameter(Mandatory = $true)][string]$EvalId
  )
  return @($Output.cases | Where-Object { [string]$_.eval_id -eq $EvalId })[0]
}

function New-BlindView {
  param([Parameter(Mandatory = $true)]$Case)
  $payloadJson = $Case.output_payload | ConvertTo-Json -Depth 50
  $payloadJson = $payloadJson -replace '(?i)historical baseline', 'historical implementation'
  $payloadJson = $payloadJson -replace '(?i)baseline monolith', 'historical implementation'
  $blindSafePayload = $payloadJson | ConvertFrom-Json
  return [ordered]@{
    result_status = [string]$Case.result_status
    output_artifact_type = [string]$Case.output_artifact_type
    output_payload = $blindSafePayload
    contract_selection_result = [string]$Case.contract_selection_result
  }
}

$shared = Read-TaogeJsonFile -Path $sharedPath
$baseline = Read-TaogeJsonFile -Path $baselinePath
$candidate = Read-TaogeJsonFile -Path $candidatePath
$fixture = Read-TaogeJsonFile -Path $fixturePath
$expectedIds = @($shared.cases | ForEach-Object { [string]$_.eval_id })

Assert-ArmOutput -Output $baseline -ExpectedRole 'baseline' -ExpectedIds $expectedIds
Assert-ArmOutput -Output $candidate -ExpectedRole 'candidate' -ExpectedIds $expectedIds

$candidateAuditRecords = @()
foreach ($expectedCase in @($fixture.cases)) {
  $evalId = [string]$expectedCase.prompt_id
  $actualCase = Get-CaseById -Output $candidate -EvalId $evalId
  $expectedNode = if ($null -eq $expectedCase.expected_node_id) { '' } else { [string]$expectedCase.expected_node_id }
  $actualNode = if ($null -eq $actualCase.actual_node_id) { '' } else { [string]$actualCase.actual_node_id }
  $expectedReferences = @($expectedCase.expected_references | ForEach-Object { [string]$_ } | Sort-Object)
  $actualReferences = @($actualCase.loaded_reference_ids | ForEach-Object { [string]$_ } | Sort-Object)
  $referenceMatch = (($expectedReferences -join "`n") -ceq ($actualReferences -join "`n"))
  $checks = [ordered]@{
    skill_id = ([string]$actualCase.skill_id -ceq [string]$expectedCase.skill_id)
    actual_node_id = ($actualNode -ceq $expectedNode)
    loaded_reference_ids = $referenceMatch
    legacy_reference_loaded = ([bool]$actualCase.legacy_reference_loaded -eq [bool]$expectedCase.expected_legacy_reference_loaded)
    contract_selection_result = ([string]$actualCase.contract_selection_result -ceq [string]$expectedCase.expected_contract_selection_result)
    manual_assist_count = ([int]$actualCase.manual_assist_count -eq 0)
  }
  $failedChecks = @($checks.Keys | Where-Object { -not [bool]$checks[$_] })
  $candidateAuditRecords += [ordered]@{
    eval_id = $evalId
    result = if ($failedChecks.Count -eq 0) { 'pass' } else { 'fail' }
    failed_checks = $failedChecks
    expected = [ordered]@{
      node_id = if ([string]::IsNullOrEmpty($expectedNode)) { $null } else { $expectedNode }
      references = $expectedReferences
      legacy_reference_loaded = [bool]$expectedCase.expected_legacy_reference_loaded
      contract_selection_result = [string]$expectedCase.expected_contract_selection_result
    }
    actual = [ordered]@{
      node_id = if ([string]::IsNullOrEmpty($actualNode)) { $null } else { $actualNode }
      references = $actualReferences
      legacy_reference_loaded = [bool]$actualCase.legacy_reference_loaded
      contract_selection_result = [string]$actualCase.contract_selection_result
      manual_assist_count = [int]$actualCase.manual_assist_count
    }
  }
}
$failedCandidateAudit = @($candidateAuditRecords | Where-Object { $_.result -eq 'fail' })
$machineAudit = [ordered]@{
  schema_id = 'taoge://reports/r8/h5-blind-machine-audit/v0.1'
  evaluation_id = $EvaluationId
  overall_result = if ($failedCandidateAudit.Count -eq 0) { 'pass' } else { 'fail' }
  arm_contract_integrity = 'pass'
  candidate_current_contract_pass_count = $candidateAuditRecords.Count - $failedCandidateAudit.Count
  candidate_current_contract_case_count = $candidateAuditRecords.Count
  candidate_current_contract_fail_count = $failedCandidateAudit.Count
  candidate_records = $candidateAuditRecords
  interpretation = if ($failedCandidateAudit.Count -eq 0) {
    'The candidate arm matched the current routing and reference-selection contract.'
  } else {
    'The blind preference packet remains usable, but H5 cannot close until the listed machine-contract mismatches are resolved in a fresh unassisted run.'
  }
}
Write-TaogeUtf8NoBomJson -Path $machineAuditPath -Value $machineAudit -Depth 30

if (Test-Path -LiteralPath $mappingPath -PathType Leaf) {
  $allocation = Read-TaogeJsonFile -Path $mappingPath
  if ([string]$allocation.evaluation_id -ne $EvaluationId) {
    throw 'Existing private allocation belongs to another evaluation.'
  }
} else {
  $salt = [guid]::NewGuid().ToString('N')
  $mappingRows = @()
  foreach ($case in @($shared.cases | Where-Object { [string]$_.case_class -ne 'rejection' })) {
    $hashInput = [System.Text.Encoding]::UTF8.GetBytes(([string]$case.eval_id + ':' + $salt))
    $digest = [System.Security.Cryptography.SHA256]::Create().ComputeHash($hashInput)
    $aRole = if (($digest[0] % 2) -eq 0) { 'baseline' } else { 'candidate' }
    $bRole = if ($aRole -eq 'baseline') { 'candidate' } else { 'baseline' }
    $mappingRows += [ordered]@{
      eval_id = [string]$case.eval_id
      A = $aRole
      B = $bRole
    }
  }
  $allocation = [ordered]@{
    schema_id = 'taoge://reports/r8/h5-blind-allocation-private/v0.1'
    evaluation_id = $EvaluationId
    salt = $salt
    mappings = $mappingRows
  }
  Write-TaogeUtf8NoBomJson -Path $mappingPath -Value $allocation -Depth 20
}

$reviewCases = @()
foreach ($case in @($shared.cases | Where-Object { [string]$_.case_class -ne 'rejection' })) {
  $evalId = [string]$case.eval_id
  $matchingAllocations = @($allocation.mappings | Where-Object { [string]$_.eval_id -eq $evalId })
  if ($matchingAllocations.Count -ne 1) {
    throw "Private allocation must contain exactly one row for eval_id: $evalId"
  }
  $mapping = $matchingAllocations[0]
  if (@('baseline', 'candidate') -notcontains [string]$mapping.A -or
      @('baseline', 'candidate') -notcontains [string]$mapping.B -or
      [string]$mapping.A -eq [string]$mapping.B) {
    throw "Private allocation contains an invalid A/B role pair for eval_id: $evalId"
  }
  $baselineCase = Get-CaseById -Output $baseline -EvalId $evalId
  $candidateCase = Get-CaseById -Output $candidate -EvalId $evalId
  $roleCases = @{
    baseline = $baselineCase
    candidate = $candidateCase
  }
  $reviewCases += [ordered]@{
    eval_id = $evalId
    skill_id = [string]$case.skill_id
    case_class = [string]$case.case_class
    prompt_text = [string]$case.prompt_text
    input_context = $case.input_context
    business_input = $case.business_input
    A = New-BlindView -Case $roleCases[[string]$mapping.A]
    B = New-BlindView -Case $roleCases[[string]$mapping.B]
    reviewer_choice = $null
    reviewer_reason = $null
  }
}

$rejectionAudit = @()
foreach ($case in @($shared.cases | Where-Object { [string]$_.case_class -eq 'rejection' })) {
  $evalId = [string]$case.eval_id
  $baselineCase = Get-CaseById -Output $baseline -EvalId $evalId
  $candidateCase = Get-CaseById -Output $candidate -EvalId $evalId
  $rejectionAudit += [ordered]@{
    eval_id = $evalId
    skill_id = [string]$case.skill_id
    baseline_status = [string]$baselineCase.result_status
    baseline_contract_selection_result = [string]$baselineCase.contract_selection_result
    candidate_status = [string]$candidateCase.result_status
    candidate_contract_selection_result = [string]$candidateCase.contract_selection_result
  }
}

$packet = [ordered]@{
  schema_id = 'taoge://reports/r8/h5-blind-review-packet/v0.1'
  evaluation_id = $EvaluationId
  reviewer_instructions = @(
    'Review A and B without trying to infer implementation identity.',
    'For each case choose A, B, or tie and give one business reason.',
    'Judge correctness, usefulness, clarity, and faithful handling of uncertainty.',
    'Rejection cases are machine-audited separately and are not preference items.'
  )
  review_cases = $reviewCases
  rejection_case_count = $rejectionAudit.Count
  rejection_evidence = 'machine-audit.json'
}
Write-TaogeUtf8NoBomJson -Path $packetJsonPath -Value $packet -Depth 50

$markdown = New-Object System.Collections.Generic.List[string]
$markdown.Add('# R8-H5 Anonymous A/B Review')
$markdown.Add('')
$markdown.Add('Choose A, B, or tie for each case. Give one business reason. Do not infer implementation identity.')
$markdown.Add('')
foreach ($case in $reviewCases) {
  $markdown.Add(('## ' + [string]$case.eval_id))
  $markdown.Add('')
  $markdown.Add(('Skill: ' + [string]$case.skill_id + ' | Case: ' + [string]$case.case_class))
  $markdown.Add('')
  $markdown.Add(('Prompt: ' + [string]$case.prompt_text))
  $markdown.Add('')
  $markdown.Add('### A')
  $markdown.Add('')
  $markdown.Add('```json')
  $markdown.Add(($case.A | ConvertTo-Json -Depth 50))
  $markdown.Add('```')
  $markdown.Add('')
  $markdown.Add('### B')
  $markdown.Add('')
  $markdown.Add('```json')
  $markdown.Add(($case.B | ConvertTo-Json -Depth 50))
  $markdown.Add('```')
  $markdown.Add('')
  $markdown.Add('Choice: [ ] A  [ ] B  [ ] tie')
  $markdown.Add('')
  $markdown.Add('Reason:')
  $markdown.Add('')
}
Write-TaogeUtf8NoBomLines -Path $packetMarkdownPath -Lines $markdown

Write-Output "R8_H5_BLIND_REVIEW_PACKET=ready"
Write-Output "REVIEW_CASES=$($reviewCases.Count)"
Write-Output "REJECTION_CASES=$($rejectionAudit.Count)"
Write-Output "MACHINE_AUDIT=$($machineAudit.overall_result)"
Write-Output "CANDIDATE_CONTRACT=$($machineAudit.candidate_current_contract_pass_count)/$($machineAudit.candidate_current_contract_case_count)"
Write-Output "MACHINE_AUDIT_PATH=$machineAuditPath"
Write-Output "PACKET_JSON=$packetJsonPath"
Write-Output "PACKET_MARKDOWN=$packetMarkdownPath"
