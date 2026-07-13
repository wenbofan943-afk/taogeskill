param([string]$FixturePath='examples/r5-h2-account-radar-fixtures/fixtures.json',[string]$ReportPath='state/checks/r5-h2-account-radar-report.json')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
function Test-Case($case) {
  $e=[System.Collections.Generic.List[string]]::new(); $p=$case.policy; $t=$case.term
  if($p.schema_id -ne 'taoge://account/radar-policy/v0.1'){$e.Add('schema_id_invalid')}
  if($p.used_car_priority_mode -ne 'direct_first'){$e.Add('used_car_priority_invalid')}
  if([int]$p.new_car_spillover_threshold -ne 3){$e.Add('spillover_threshold_must_be_3')}
  if(@($p.new_car_spillover_proof_types).Count -lt 1){$e.Add('spillover_proof_types_missing')}
  if($p.lexicon_feedback_policy -ne 'exploratory_selection_feedback'){$e.Add('feedback_policy_invalid')}
  $counts=@('run_count','signal_assist_count','candidate_assist_count','selected_candidate_assist_count','rejected_candidate_assist_count')
  foreach($name in $counts){if($null -eq $t.$name -or [int]$t.$name -lt 0){$e.Add("term_counter_invalid:$name")}}
  if($t.term_status -notin @('exploration','preferred','deprioritized','blocked')){$e.Add('term_status_invalid')}
  if($t.term_status -eq 'blocked' -and @($p.topic_exclusions) -notcontains $t.term){$e.Add('blocked_requires_policy_exclusion')}
  return @($e)
}
try {
  $root=Split-Path -Parent $PSScriptRoot; $fixtureTarget=if([IO.Path]::IsPathRooted($FixturePath)){[IO.Path]::GetFullPath($FixturePath)}else{Join-Path $root $FixturePath}; $fixture=Get-Content -LiteralPath $fixtureTarget -Raw -Encoding UTF8|ConvertFrom-Json
  $rows=[System.Collections.Generic.List[object]]::new()
  foreach($case in @($fixture.cases)){$errors=@(Test-Case $case);$actual=if($errors.Count){'fail'}else{'pass'};$rows.Add([ordered]@{fixture_id=$case.fixture_id;expected_result=$case.expected_result;actual_result=$actual;expectation_met=($actual -eq $case.expected_result);errors=$errors})}
  $failed=@($rows|Where-Object{-not $_.expectation_met});$report=[ordered]@{schema_id='taoge://reports/r5/h2-account-radar/v0.1';overall_result=$(if($failed.Count){'fail'}else{'pass'});case_count=$rows.Count;failure_count=$failed.Count;results=@($rows.ToArray())}
  $target=if([IO.Path]::IsPathRooted($ReportPath)){[IO.Path]::GetFullPath($ReportPath)}else{Join-Path $root $ReportPath};Write-TaogeUtf8NoBomJson -Path $target -Value $report -Depth 12
  Write-Output "R5_H2_ACCOUNT_RADAR_CHECK=$($report.overall_result)";Write-Output "CASE_COUNT=$($report.case_count)";Write-Output "REPORT=$target";if($failed.Count){exit 1}
} catch {Write-Error $_;exit 3}
