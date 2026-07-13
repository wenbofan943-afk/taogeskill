param(
  [string]$InputPath,
  [string]$OutputPath,
  [switch]$WriteSnapshot,
  [switch]$FixtureMode,
  [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'AccountStartupCheck.ps1')
. (Join-Path $PSScriptRoot 'EnvironmentPreflight.ps1')

try {
  if ($SelfTest) {
    $probe = [pscustomobject]@{
      session_id = 'SAMPLE-R5H5-SELFTEST'
      task_type = 'hotspot_research'
      account = [pscustomobject]@{
        account_slug = 'sample-account'
        publishing_platforms = @('douyin')
        target_duration = '60s'
        audience_priority = @('buyer')
        high_risk_topic_policy = 'verify_mechanism_only'
        radar_policy_ref = 'examples/policy.yaml'
        query_lexicon_ref = 'examples/lexicon.yaml'
        radar_policy_status = 'policy_active'
      }
    }
    $result = Resolve-R5AccountStartupCheck -InputObject $probe
    if ($result.startup_result -ne 'account_ready' -or $result.next_skill -ne 'hotspot-topic-research') {
      throw 'self_test_result_unexpected'
    }
    $snapshot = New-R5AccountSessionSnapshot -InputObject $probe -StartupCheck $result
    if ($snapshot.schema_id -ne 'taoge://account/session-snapshot/v0.1' -or $snapshot.account_slug -ne 'sample-account') {
      throw 'self_test_snapshot_unexpected'
    }
    'ACCOUNT_STARTUP_CHECK_SELF_TEST=pass'
    exit 0
  }
  if ([string]::IsNullOrWhiteSpace($InputPath) -or [string]::IsNullOrWhiteSpace($OutputPath)) {
    throw 'usage_requires_input_and_output_paths'
  }
  $projectRoot = Split-Path -Parent $PSScriptRoot
  $inputTarget = if ([IO.Path]::IsPathRooted($InputPath)) { [IO.Path]::GetFullPath($InputPath) } else { Join-Path $projectRoot $InputPath }
  $outputTarget = if ([IO.Path]::IsPathRooted($OutputPath)) { [IO.Path]::GetFullPath($OutputPath) } else { Join-Path $projectRoot $OutputPath }
  $request = Get-Content -LiteralPath $inputTarget -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($request.schema_id -ne 'taoge://account/startup-request/v0.1') { throw 'startup_request_schema_invalid' }
  $result = Resolve-R5AccountStartupCheck -InputObject $request
  if ($WriteSnapshot -and $result.snapshot_write_allowed) {
    $snapshotTarget = if ($FixtureMode) {
      Join-Path (Split-Path -Parent $outputTarget) 'account-session-snapshot.json'
    } else {
      Join-Path $projectRoot $result.account_snapshot_ref
    }
    $allowedRoot = if ($FixtureMode) { Join-Path $projectRoot 'state/checks' } else { Join-Path $projectRoot "accounts/$($result.account_slug)/runs/$($result.session_id)" }
    $containment = Resolve-TaogeContainedPath -AllowedRoot $allowedRoot -CandidatePath $snapshotTarget -RejectReparsePoints
    if ($containment.status -ne 'pass') { throw "snapshot_path_not_allowed:$([string]::Join('|', @($containment.errors)))" }
    $snapshot = New-R5AccountSessionSnapshot -InputObject $request -StartupCheck $result
    Write-TaogeUtf8NoBomJson -Path $snapshotTarget -Value $snapshot -Depth 12
    $result.account_snapshot_ref = if ($FixtureMode) { $snapshotTarget } else { $result.account_snapshot_ref }
    $result.snapshot_write_status = 'written'
  }
  Write-TaogeUtf8NoBomJson -Path $outputTarget -Value $result -Depth 12
  "ACCOUNT_STARTUP_CHECK=$($result.startup_result)"
  "NEXT_SKILL=$($result.next_skill)"
  "OUTPUT=$outputTarget"
  exit 0
} catch {
  Write-Error $_
  exit 3
}
