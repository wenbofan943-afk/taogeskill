param([string]$FixturePath='examples/r5-h6-account-identity-fixtures/fixtures.json',[string]$ReportPath='state/checks/r5-h6-account-identity-report.json')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'AccountStartupCheckV02.ps1')

function Copy-R5H6FixtureObject {
  param([Parameter(Mandatory=$true)]$Value)
  return ($Value | ConvertTo-Json -Depth 40 | ConvertFrom-Json)
}

try {
  $root=Split-Path -Parent $PSScriptRoot
  $target=if([IO.Path]::IsPathRooted($FixturePath)){[IO.Path]::GetFullPath($FixturePath)}else{Join-Path $root $FixturePath}
  $fixture=Get-Content -LiteralPath $target -Raw -Encoding UTF8|ConvertFrom-Json
  if($fixture.schema_id -ne 'taoge://fixtures/r5-h6-account-identity/v0.1'){throw 'fixture_schema_invalid'}
  if([string]::IsNullOrWhiteSpace([string]$fixture.default_requested_at)){throw 'fixture_default_requested_at_missing'}
  $rows=[Collections.Generic.List[object]]::new()

  foreach($case in @($fixture.cases)) {
    $request=Copy-R5H6FixtureObject $case.request
    if(-not($request.PSObject.Properties.Name -contains 'requested_at')){$request|Add-Member -NotePropertyName requested_at -NotePropertyValue ([string]$fixture.default_requested_at)}
    $request|Add-Member -NotePropertyName identity_binding -NotePropertyValue (New-R5AccountIdentityBinding $case.binding) -Force
    $actual=Resolve-R5H6AccountStartupCheck $request
    $errors=[Collections.Generic.List[string]]::new()
    if([string]$actual.startup_result-ne[string]$case.expected.startup_result){$errors.Add('startup_result_mismatch')}
    if([string]$actual.account_snapshot_status-ne[string]$case.expected.snapshot_status){$errors.Add('snapshot_status_mismatch')}
    if([bool]$actual.identity_verified-ne[bool]$case.expected.identity_verified){$errors.Add('identity_verified_mismatch')}
    if(-not[string]::IsNullOrWhiteSpace([string]$case.expected.required_error)-and @($actual.identity_errors)-notcontains[string]$case.expected.required_error){$errors.Add('required_identity_error_missing')}
    $snapshot=New-R5H6AccountSessionSnapshot $request $actual
    if($snapshot.schema_id-ne'taoge://account/session-snapshot/v0.2'){$errors.Add('snapshot_schema_invalid')}
    if([string]$snapshot.snapshot_at-ne[string]$request.requested_at){$errors.Add('snapshot_time_not_materialized_from_request')}
    if(@($snapshot.captured_fields.publishing_platforms|Where-Object{$_-is[Array]}).Count-gt0){$errors.Add('snapshot_array_nested')}
    $rows.Add([ordered]@{fixture_id=$case.fixture_id;expected_result=$case.expected.startup_result;actual_result=$actual.startup_result;expectation_met=($errors.Count-eq0);errors=@($errors)})
  }

  $timeCase=$fixture.cases[0]
  $timeRequest=Copy-R5H6FixtureObject $timeCase.request
  $timeRequest|Add-Member -NotePropertyName identity_binding -NotePropertyValue (New-R5AccountIdentityBinding $timeCase.binding) -Force
  $timeCheck=Resolve-R5H6AccountStartupCheck $timeRequest
  $missingError=''
  try{$null=New-R5H6AccountSessionSnapshot $timeRequest $timeCheck}catch{$missingError=$_.Exception.Message}
  $rows.Add([ordered]@{fixture_id='R5H6-TIME-001-missing-materialized-time';expected_result='snapshot_time_missing';actual_result=$missingError;expectation_met=($missingError-eq'snapshot_time_missing');errors=@($(if($missingError-ne'snapshot_time_missing'){'missing_time_not_blocked'}))})

  $invalidRequest=Copy-R5H6FixtureObject $timeRequest
  $invalidRequest|Add-Member -NotePropertyName requested_at -NotePropertyValue '2026-07-15T00:00:00' -Force
  $invalidError=''
  try{$null=New-R5H6AccountSessionSnapshot $invalidRequest $timeCheck}catch{$invalidError=$_.Exception.Message}
  $rows.Add([ordered]@{fixture_id='R5H6-TIME-002-timezone-required';expected_result='snapshot_time_invalid';actual_result=$invalidError;expectation_met=($invalidError-eq'snapshot_time_invalid');errors=@($(if($invalidError-ne'snapshot_time_invalid'){'invalid_time_not_blocked'}))})

  $smokeCase=$fixture.cases[0]
  $smokeRequest=Copy-R5H6FixtureObject $smokeCase.request
  $smokeRequest|Add-Member -NotePropertyName requested_at -NotePropertyValue ([string]$fixture.default_requested_at) -Force
  $smokeRequest|Add-Member -NotePropertyName schema_id -NotePropertyValue 'taoge://account/startup-request/v0.2' -Force
  $smokeRequest|Add-Member -NotePropertyName identity_binding -NotePropertyValue (New-R5AccountIdentityBinding $smokeCase.binding) -Force
  $smokeInput=Join-Path $root 'state/checks/r5-h6-account-startup-request.json'
  $smokeOutput=Join-Path $root 'state/checks/r5-h6-account-startup-result.json'
  Write-TaogeUtf8NoBomJson -Path $smokeInput -Value $smokeRequest -Depth 16
  $entry=Join-Path $PSScriptRoot 'invoke-account-startup-check-v0.2.ps1'
  $entryOutput=@(& $entry -InputPath $smokeInput -OutputPath $smokeOutput -WriteSnapshot -FixtureMode 2>&1)
  $entrySucceeded=$?
  $snapshotPath=Join-Path (Split-Path -Parent $smokeOutput) 'account-session-snapshot.v0.2.json'
  $entrySnapshot=if(Test-Path -LiteralPath $snapshotPath){Get-Content -LiteralPath $snapshotPath -Raw -Encoding UTF8|ConvertFrom-Json}else{$null}
  $entryWriteSmoke=$entrySucceeded-and$entryOutput-contains'ACCOUNT_STARTUP_CHECK_V02=account_ready'-and$null-ne$entrySnapshot-and[string]$entrySnapshot.snapshot_at-eq[string]$smokeRequest.requested_at
  if(-not$entryWriteSmoke){$rows.Add([ordered]@{fixture_id='R5H6-ENTRY-WRITE-SMOKE';expected_result='account_ready+snapshot_time_written';actual_result=[string]::Join(';',@($entryOutput));expectation_met=$false;errors=@('entry_write_smoke_failed')})}

  $failed=@($rows|Where-Object{-not $_.expectation_met})
  $report=[ordered]@{schema_id='taoge://reports/r5/h6-account-identity/v0.1';overall_result=if($failed.Count-eq0){'pass'}else{'fail'};case_count=$rows.Count;failure_count=$failed.Count;entry_write_smoke=$entryWriteSmoke;results=@($rows)}
  $out=if([IO.Path]::IsPathRooted($ReportPath)){[IO.Path]::GetFullPath($ReportPath)}else{Join-Path $root $ReportPath}
  Write-TaogeUtf8NoBomJson -Path $out -Value $report -Depth 16
  "R5_H6_ACCOUNT_IDENTITY_CHECK=$($report.overall_result)"
  "CASE_COUNT=$($report.case_count)"
  "REPORT=$out"
  if($failed.Count-gt0){exit 1}
} catch {Write-Error $_;exit 3}
