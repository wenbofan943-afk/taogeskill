param(
  [string]$ProjectRoot = '',
  [string]$FixturePath = '',
  [string]$WorkRoot = ''
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
if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
  $WorkRoot = Join-Path $ProjectRoot 'state/checks/r8/R8-H5-BLIND-20260717'
}
$WorkRoot = [System.IO.Path]::GetFullPath($WorkRoot)
$rootPrefix = $ProjectRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if (-not $WorkRoot.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'work_root_outside_project'
}

. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')

$fixture = Get-Content -LiteralPath $FixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
$sharedCases = @($fixture.cases | ForEach-Object {
  [pscustomobject][ordered]@{
    eval_id = [string]$_.prompt_id
    skill_id = [string]$_.skill_id
    case_class = [string]$_.case_class
    prompt_text = [string]$_.prompt_text
    input_context = $_.input_context
    business_input = $_.business_input
  }
})
$shared = [pscustomobject][ordered]@{
  schema_id = 'taoge://fixtures/r8/h5-blind-shared-input/v0.1'
  evaluation_id = 'R8-H5-BLIND-20260717'
  sample_only = $true
  privacy_class = 'public_redacted_synthetic'
  isolation_rule = 'Both arms receive this exact file. Expected fields and the other arm output are not included.'
  case_count = $sharedCases.Count
  cases = [object[]]$sharedCases
}

$outputContract = [ordered]@{
  schema_id = 'taoge://reports/r8/h5-blind-arm-output/v0.1'
  required_top_fields = @('schema_id','evaluation_id','arm_role','cases')
  required_case_fields = @(
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
  field_semantics = [ordered]@{
    actual_node_id = 'The node actually selected for execution. Use null when the request is rejected before routing; do not copy input_context.node_id into this field.'
    loaded_reference_ids = 'Only references actually loaded while handling this case.'
    manual_assist_count = 'Case-specific help received after the arm package was issued; use 0 only when none was received.'
  }
  enums = [ordered]@{
    result_status = @('produced','waiting','blocked')
    contract_selection_result = @('pass','fail','not_applicable')
  }
}

$arms = @(
  [pscustomobject][ordered]@{
    arm_role = 'baseline'
    allowed_context = @(
      'shared-input.json',
      'git show 716920e:skills/hotspot-topic-research/SKILL.md',
      'git show 5403528:skills/propagation-router/SKILL.md',
      'git show 40ce0b0:skills/platform-packaging-adapter/SKILL.md'
    )
    forbidden_context = @(
      'current target Skill files',
      'candidate arm directory or output',
      'expected_* fields from the source fixture',
      'R8 H5 audit conclusions'
    )
  },
  [pscustomobject][ordered]@{
    arm_role = 'candidate'
    allowed_context = @(
      'shared-input.json',
      'current target Skill entry',
      'only current references whose load_when matches the case',
      'current machine truth explicitly linked by the target Skill'
    )
    forbidden_context = @(
      'baseline Git snapshots',
      'baseline arm directory or output',
      'expected_* fields from the source fixture',
      'R8 H5 audit conclusions'
    )
  }
)

Write-TaogeUtf8NoBomJson -Path (Join-Path $WorkRoot 'shared-input.json') -Value $shared -Depth 60
foreach ($arm in $arms) {
  $armRoot = Join-Path $WorkRoot ("arm-" + [string]$arm.arm_role)
  $manifest = [pscustomobject][ordered]@{
    schema_id = 'taoge://reports/r8/h5-blind-arm-manifest/v0.1'
    evaluation_id = 'R8-H5-BLIND-20260717'
    arm_role = [string]$arm.arm_role
    shared_input_path = '../shared-input.json'
    output_path = 'raw-output.json'
    allowed_context = [object[]]$arm.allowed_context
    forbidden_context = [object[]]$arm.forbidden_context
    execution_rules = @(
      'Treat each case independently.',
      'Do not use expected answers or the other arm output.',
      'Do not browse the network or use private account data.',
      'Do not modify tracked project files.',
      'Return blocked or waiting rather than fabricate missing evidence.',
      'manual_assist_count counts case-specific help received after this package; use 0 only if none was received.'
    )
    output_contract = $outputContract
  }
  Write-TaogeUtf8NoBomJson -Path (Join-Path $armRoot 'arm-manifest.json') -Value $manifest -Depth 40
}

Write-Output "R8_H5_BLIND_PACKAGE=ready"
Write-Output "R8_H5_BLIND_CASES=$($sharedCases.Count)"
Write-Output "R8_H5_BLIND_ROOT=$WorkRoot"
exit 0
