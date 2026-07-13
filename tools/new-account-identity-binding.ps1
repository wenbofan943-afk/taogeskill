param([string]$InputPath,[string]$OutputPath,[switch]$FixtureMode,[switch]$SelfTest)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'EnvironmentPreflight.ps1')
. (Join-Path $PSScriptRoot 'AccountIdentityBinding.ps1')
try {
  if ($SelfTest) {
    $candidate=[pscustomobject]@{binding_id='AIB-selftest-v1';binding_version='1';account_identity_id='AID-selftest-v1';account_technical_slug='selftest-account';account_display_name='Selftest Account';account_directory_key='selftest-account';account_profile_ref='accounts/selftest-account/account_profile.md';account_profile_sha256=('0'*64);asset_bindings=@([pscustomobject]@{asset_type='radar_policy';relative_ref='accounts/selftest-account/radar-policy.yaml';account_identity_id='AID-selftest-v1';account_technical_slug='selftest-account';sha256=('0'*64)},[pscustomobject]@{asset_type='query_lexicon';relative_ref='accounts/selftest-account/query-lexicon.yaml';account_identity_id='AID-selftest-v1';account_technical_slug='selftest-account';sha256=('0'*64)})}
    $binding=New-R5AccountIdentityBinding $candidate
    $probe=[pscustomobject]@{account=[pscustomobject]@{account_slug='selftest-account';account_display_name='Selftest Account';account_identity_id='AID-selftest-v1';account_technical_slug='selftest-account'};identity_binding=$binding}
    if (-not (Test-R5AccountIdentityBinding $probe).identity_verified) { throw 'self_test_binding_invalid' }
    'ACCOUNT_IDENTITY_BINDING_SELF_TEST=pass'; exit 0
  }
  if ([string]::IsNullOrWhiteSpace($InputPath) -or [string]::IsNullOrWhiteSpace($OutputPath)) { throw 'usage_requires_input_and_output_paths' }
  $root=Split-Path -Parent $PSScriptRoot;$inputTarget=if([IO.Path]::IsPathRooted($InputPath)){[IO.Path]::GetFullPath($InputPath)}else{Join-Path $root $InputPath};$outputTarget=if([IO.Path]::IsPathRooted($OutputPath)){[IO.Path]::GetFullPath($OutputPath)}else{Join-Path $root $OutputPath};$candidate=Get-Content -LiteralPath $inputTarget -Raw -Encoding UTF8|ConvertFrom-Json;$directory=[string]$candidate.account_directory_key;$allowed=Join-Path $root "accounts/$directory";$outCheck=Resolve-TaogeContainedPath -AllowedRoot $allowed -CandidatePath $outputTarget -RejectReparsePoints
  if ($outCheck.status -ne 'pass') { throw 'binding_output_outside_account_root' }
  if (-not $FixtureMode) {$records=@([pscustomobject]@{relative_ref=$candidate.account_profile_ref;asset_type='account_profile'})+@($candidate.asset_bindings);foreach($record in $records){$target=Join-Path $root ([string]$record.relative_ref);$contained=Resolve-TaogeContainedPath -AllowedRoot $allowed -CandidatePath $target -RejectReparsePoints;if($contained.status -ne 'pass'){throw "binding_asset_outside_account_root:$($record.asset_type)"};if(-not(Test-Path -LiteralPath $target)){throw "binding_asset_missing:$($record.asset_type)"};if($record.asset_type -eq 'account_profile'){$candidate.account_profile_sha256=Get-TaogeFileSha256 $target}else{$record.sha256=Get-TaogeFileSha256 $target}}}
  $binding=New-R5AccountIdentityBinding $candidate;Write-TaogeUtf8NoBomJson -Path $outputTarget -Value $binding -Depth 16;"ACCOUNT_IDENTITY_BINDING=written";"BINDING_DIGEST=$($binding.binding_digest)";"OUTPUT=$outputTarget";exit 0
} catch {Write-Error $_;exit 3}
