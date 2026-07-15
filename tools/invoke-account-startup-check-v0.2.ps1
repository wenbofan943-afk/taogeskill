param([string]$InputPath,[string]$OutputPath,[switch]$WriteSnapshot,[switch]$FixtureMode,[switch]$SelfTest)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'EnvironmentPreflight.ps1')
. (Join-Path $PSScriptRoot 'AccountStartupCheckV02.ps1')

function Test-R5H6BindingFiles {
  param([Parameter(Mandatory=$true)]$Request,[Parameter(Mandatory=$true)][string]$ProjectRoot)
  $errors = [Collections.Generic.List[string]]::new()
  $binding = Get-R5H6PropertyValue $Request 'identity_binding'
  $account = Get-R5H6PropertyValue $Request 'account'
  $directory = [string](Get-R5H6PropertyValue $account 'account_slug')
  $identity = [string](Get-R5H6PropertyValue $binding 'account_identity_id')
  $technical = [string](Get-R5H6PropertyValue $binding 'account_technical_slug')
  $records = @([pscustomobject]@{ relative_ref=[string](Get-R5H6PropertyValue $binding 'account_profile_ref'); sha256=[string](Get-R5H6PropertyValue $binding 'account_profile_sha256'); asset_type='account_profile' }) + @((Get-R5H6PropertyValue $binding 'asset_bindings'))
  foreach ($record in $records) {
    $target = Join-Path $ProjectRoot ([string](Get-R5H6PropertyValue $record 'relative_ref'))
    $contained = Resolve-TaogeContainedPath -AllowedRoot (Join-Path $ProjectRoot "accounts/$directory") -CandidatePath $target -RejectReparsePoints
    if ($contained.status -ne 'pass') { $errors.Add("asset_file_outside_account_root:$($record.asset_type)"); continue }
    if (-not (Test-Path -LiteralPath $target)) { $errors.Add("asset_file_missing:$($record.asset_type)"); continue }
    if ((Get-R5H6PathDigest -Path $target) -ne [string](Get-R5H6PropertyValue $record 'sha256')) { $errors.Add("asset_sha256_mismatch:$($record.asset_type)") }
    if (Test-Path -LiteralPath $target -PathType Container) { continue }
    $text = Get-Content -LiteralPath $target -Raw -Encoding UTF8
    if (-not $text.Contains("account_identity_id: $identity")) { $errors.Add("asset_identity_marker_missing:$($record.asset_type)") }
    if (-not $text.Contains("account_technical_slug: $technical")) { $errors.Add("asset_technical_slug_marker_missing:$($record.asset_type)") }
  }
  return @($errors)
}

try {
  if ($SelfTest) {
    $candidate = [pscustomobject]@{ binding_id='AIB-sample-v1'; binding_version='1'; account_identity_id='AID-sample-v1'; account_technical_slug='sample-account'; account_display_name='Sample Account'; account_directory_key='sample-account'; account_profile_ref='accounts/sample-account/account_profile.md'; asset_bindings=@([pscustomobject]@{ asset_type='radar_policy'; relative_ref='accounts/sample-account/radar-policy.yaml'; account_identity_id='AID-sample-v1'; account_technical_slug='sample-account'; sha256='fixture' },[pscustomobject]@{ asset_type='query_lexicon'; relative_ref='accounts/sample-account/query-lexicon.yaml'; account_identity_id='AID-sample-v1'; account_technical_slug='sample-account'; sha256='fixture' }) }
    $binding = New-R5AccountIdentityBinding $candidate
    $request = [pscustomobject]@{ session_id='SAMPLE-R5H6-SELFTEST'; requested_at='2026-07-15T00:00:00Z'; task_type='hotspot_research'; identity_binding=$binding; account=[pscustomobject]@{ account_slug='sample-account'; account_display_name='Sample Account'; account_identity_id='AID-sample-v1'; account_technical_slug='sample-account'; publishing_platforms=@('douyin'); target_duration='content_determined'; audience_priority=@('buyer'); high_risk_topic_policy='verify_mechanism_only'; radar_policy_ref='accounts/sample-account/radar-policy.yaml'; query_lexicon_ref='accounts/sample-account/query-lexicon.yaml'; radar_policy_status='policy_active' } }
    $result = Resolve-R5H6AccountStartupCheck $request
    if ($result.startup_result -ne 'account_ready' -or -not $result.identity_verified) { throw 'self_test_result_unexpected' }
    $snapshot = New-R5H6AccountSessionSnapshot $request $result
    if ($snapshot.schema_id -ne 'taoge://account/session-snapshot/v0.2' -or $snapshot.snapshot_at -ne $request.requested_at) { throw 'self_test_snapshot_unexpected' }
    'ACCOUNT_STARTUP_CHECK_V02_SELF_TEST=pass'; exit 0
  }
  if ([string]::IsNullOrWhiteSpace($InputPath) -or [string]::IsNullOrWhiteSpace($OutputPath)) { throw 'usage_requires_input_and_output_paths' }
  $root=Split-Path -Parent $PSScriptRoot;$inputTarget=if([IO.Path]::IsPathRooted($InputPath)){[IO.Path]::GetFullPath($InputPath)}else{Join-Path $root $InputPath};$outputTarget=if([IO.Path]::IsPathRooted($OutputPath)){[IO.Path]::GetFullPath($OutputPath)}else{Join-Path $root $OutputPath};$request=Get-Content -LiteralPath $inputTarget -Raw -Encoding UTF8|ConvertFrom-Json
  if ($request.schema_id -ne 'taoge://account/startup-request/v0.2') { throw 'startup_request_schema_invalid' }
  if ($null -eq (Get-R5H6PropertyValue $request 'identity_binding') -and -not [string]::IsNullOrWhiteSpace([string]$request.identity_binding_ref)) {
    $bindingTarget=Join-Path $root ([string]$request.identity_binding_ref);$allowed=Join-Path $root "accounts/$($request.account.account_slug)";$contained=Resolve-TaogeContainedPath -AllowedRoot $allowed -CandidatePath $bindingTarget -RejectReparsePoints
    if ($contained.status -ne 'pass') { throw 'identity_binding_ref_outside_account_root' }
    $request | Add-Member -NotePropertyName identity_binding -NotePropertyValue (Get-Content -LiteralPath $bindingTarget -Raw -Encoding UTF8|ConvertFrom-Json) -Force
  }
  if (-not $FixtureMode) { $request | Add-Member -NotePropertyName identity_preflight_errors -NotePropertyValue @(Test-R5H6BindingFiles $request $root) -Force }
  $result=Resolve-R5H6AccountStartupCheck $request
  if ($WriteSnapshot -and $result.snapshot_write_allowed) {
    $snapshotTarget=if($FixtureMode){Join-Path (Split-Path -Parent $outputTarget) 'account-session-snapshot.v0.2.json'}else{Join-Path $root $result.account_snapshot_ref};$allowed=if($FixtureMode){Join-Path $root 'state/checks'}else{Join-Path $root "accounts/$($result.account_slug)/runs/$($result.session_id)"};$contained=Resolve-TaogeContainedPath -AllowedRoot $allowed -CandidatePath $snapshotTarget -RejectReparsePoints
    if ($contained.status -ne 'pass') { throw 'snapshot_path_not_allowed' }
    Write-TaogeUtf8NoBomJson -Path $snapshotTarget -Value (New-R5H6AccountSessionSnapshot $request $result) -Depth 16
    $result.account_snapshot_ref=if($FixtureMode){$snapshotTarget}else{$result.account_snapshot_ref};$result.snapshot_write_status='written'
  }
  Write-TaogeUtf8NoBomJson -Path $outputTarget -Value $result -Depth 16;"ACCOUNT_STARTUP_CHECK_V02=$($result.startup_result)";"IDENTITY_VERIFIED=$($result.identity_verified)";"OUTPUT=$outputTarget";exit 0
} catch { Write-Error $_;exit 3 }
