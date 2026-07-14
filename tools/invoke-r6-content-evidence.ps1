param(
  [ValidateSet('validate_direct_intake','validate_evidence_bundle','render_evidence_pip','self_test')]
  [string]$Mode = 'self_test',
  [string]$InputPath = '',
  [string]$SessionRoot = '',
  [string]$OutputPath = '',
  [string]$SidecarPath = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'R6ContentEvidenceRuntime.ps1')

function Resolve-R6CliPath {
  param([Parameter(Mandatory=$true)][string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
  return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

function Resolve-R6SessionPath {
  param([Parameter(Mandatory=$true)][string]$SessionRoot, [Parameter(Mandatory=$true)][string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
  return [System.IO.Path]::GetFullPath((Join-Path $SessionRoot $Path))
}

function New-R6SelfTestDirect {
  return [pscustomobject]@{
    schema_id='taoge://r6/direct-content-intake/v0.1'
    schema_version='0.1.0'
    intake_id='intake-fixture-001'
    content_source_id='direct-card-fixture-001'
    session_id='session-fixture-001'
    account=[pscustomobject]@{account_id='account-fixture-001';account_slug='sample-account';account_display_name='示例账号';identity_binding_id='binding-fixture-001';account_snapshot_id='snapshot-fixture-001'}
    content_origin='user_supplied_draft'
    topic_origin='direct_user_input'
    direct_intent='direct_delivery'
    revision_policy='preserve_voice'
    structural_rewrite_requested=$false
    original_draft=[pscustomobject]@{artifact_id='draft-fixture-001';relative_path='inputs/user-supplied-draft.md';sha256=('a' * 64);character_count=12}
    content_goal='验证直供入口'
    target_audiences=@('示例受众')
    claim_map=@([pscustomobject]@{claim_id='claim-fixture-001';source_text='这是一个观点';claim_type='opinion';claim_evidence_status='not_required'})
    direct_content_status='direct_content_ready'
    human_gate=$false
    next_skill='content-brief-compiler'
    lineage=[pscustomobject]@{producer_skill='direct-content-intake';consumer_skill='content-brief-compiler';input_artifact_ids=@('draft-fixture-001','snapshot-fixture-001');output_artifact_ids=@('direct-card-fixture-001')}
  }
}

function New-R6SelfTestEvidence {
  return [pscustomobject]@{
    schema_id='taoge://r6/news-evidence-pip/v0.1'
    schema_version='0.1.0'
    session_id='session-fixture-001'
    account=[pscustomobject]@{account_id='account-fixture-001';account_slug='sample-account';account_display_name='示例账号';account_snapshot_id='snapshot-fixture-001';evidence_visual_grammar=[pscustomobject]@{source_label='来源事实';commentary_label='示例解读';source_color='#2457D6';commentary_color='#C1440E'}}
    claim=[pscustomobject]@{claim_id='claim-fixture-002';source_text='示例公开资料显示该指标为 42。';claim_type='statistic'}
    source=[pscustomobject]@{source_id='source-fixture-001';publisher='示例研究机构';canonical_url='https://example.invalid/r6-source';title='公开资料示例';source_type='research';published_at='2026-07-01T00:00:00+08:00';accessed_at='2026-07-14T09:00:00+08:00';source_access_status='accessible'}
    capture=[pscustomobject]@{capture_id='capture-fixture-001';source_id='source-fixture-001';captured_url='file:///fixture/source-page.html';fixture_mode=$true;capture_at='2026-07-14T09:01:00+08:00';viewport=[pscustomobject]@{width=1280;height=960};selected_target=[pscustomobject]@{selector='#evidence';visible_quote='示例指标 42';crop=[pscustomobject]@{x=100;y=160;width=1080;height=600}};screenshot_path='captures/fixture.png';sha256=('b' * 64);attempt_number=1;attempt_history=@();capture_status='captured';capture_integrity_status='verified';image_production_path='source_capture'}
    binding=[pscustomobject]@{binding_id='evidence-binding-fixture-001';claim_id='claim-fixture-002';source_id='source-fixture-001';capture_id='capture-fixture-001';claim_evidence_status='supported';rationale='可见文本直接支持示例主张。'}
    pip=[pscustomobject]@{pip_id='pip-fixture-001';binding_id='evidence-binding-fixture-001';asset_role='evidence_support';creator_commentary='这是对公开资料的示例解读。';copyright_review_status='approved';privacy_review_status='approved';publish_risk_status='approved';render_status='render_ready';asset_path=$null;asset_sha256=$null;renderer_digest=('c' * 64);template_digest=('d' * 64)}
    lineage=[pscustomobject]@{producer_skill='news-evidence-pip';consumer_skill='copywriting-quality-review';input_artifact_ids=@('claim-fixture-002','source-fixture-001','capture-fixture-001','evidence-binding-fixture-001');output_artifact_ids=@('pip-fixture-001')}
  }
}

try {
  if ($Mode -eq 'self_test') {
    $directResult = Test-R6DirectContentIntake -Data (New-R6SelfTestDirect)
    $evidenceResult = Test-R6EvidenceBundle -Data (New-R6SelfTestEvidence)
    if ($directResult.status -ne 'pass' -or $evidenceResult.status -ne 'pass') {
      throw "self_test_failed:direct=$($directResult.status):evidence=$($evidenceResult.status)"
    }
    Write-Output 'R6_CONTENT_EVIDENCE_SELF_TEST=pass'
    exit 0
  }

  if ([string]::IsNullOrWhiteSpace($InputPath)) { throw 'InputPath_required' }
  $inputFull = Resolve-R6CliPath $InputPath
  $data = Get-Content -LiteralPath $inputFull -Raw -Encoding UTF8 | ConvertFrom-Json

  if ($Mode -eq 'validate_direct_intake') {
    $result = Test-R6DirectContentIntake -Data $data
    Write-Output "R6_DIRECT_INTAKE_CHECK=$($result.status)"
    foreach ($errorCode in @($result.errors)) { Write-Output "ERROR=$errorCode" }
    if ($result.status -ne 'pass') { exit 1 }
    exit 0
  }

  $sessionFull = ''
  if (-not [string]::IsNullOrWhiteSpace($SessionRoot)) { $sessionFull = Resolve-R6CliPath $SessionRoot }
  if ($Mode -eq 'validate_evidence_bundle') {
    $result = Test-R6EvidenceBundle -Data $data -SessionRoot $sessionFull
    Write-Output "R6_EVIDENCE_BUNDLE_CHECK=$($result.status)"
    foreach ($errorCode in @($result.errors)) { Write-Output "ERROR=$errorCode" }
    if ($result.status -ne 'pass') { exit 1 }
    exit 0
  }

  if ([string]::IsNullOrWhiteSpace($sessionFull)) { throw 'SessionRoot_required' }
  if ([string]::IsNullOrWhiteSpace($OutputPath)) { throw 'OutputPath_required' }
  if ([string]::IsNullOrWhiteSpace($SidecarPath)) { throw 'SidecarPath_required' }
  $renderResult = Render-R6EvidencePip -Bundle $data -SessionRoot $sessionFull -OutputPath (Resolve-R6SessionPath -SessionRoot $sessionFull -Path $OutputPath) -SidecarPath (Resolve-R6SessionPath -SessionRoot $sessionFull -Path $SidecarPath)
  Write-Output "R6_EVIDENCE_RENDER=$($renderResult.status)"
  Write-Output "RENDER_ACTION=$($renderResult.action)"
  Write-Output "ASSET_PATH=$($renderResult.asset_path)"
  Write-Output "ASSET_SHA256=$($renderResult.asset_sha256)"
  exit 0
} catch {
  Write-Error $_
  exit 3
}
