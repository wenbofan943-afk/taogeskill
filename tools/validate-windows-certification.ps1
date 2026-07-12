param(
  [string]$FixturePath = 'examples/windows-certification-fixture/fixtures.json',
  [string]$ReportPath = 'state/checks/windows-certification-fixture-report.json'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
. (Join-Path $PSScriptRoot 'WindowsEnvironmentCertification.ps1')

function Add-CertificationCheck {
  param([System.Collections.Generic.List[object]]$Checks,[string]$Id,[bool]$Passed,[string]$Evidence)
  $Checks.Add([ordered]@{check_id=$Id;status=$(if($Passed){'pass'}else{'fail'});evidence=$Evidence})
}

try {
  $fixtureFull = if([System.IO.Path]::IsPathRooted($FixturePath)){[System.IO.Path]::GetFullPath($FixturePath)}else{[System.IO.Path]::GetFullPath((Join-Path $projectRoot $FixturePath))}
  $fixture = Get-Content -LiteralPath $fixtureFull -Raw -Encoding UTF8 | ConvertFrom-Json
  $checks = [System.Collections.Generic.List[object]]::new()
  foreach($case in @($fixture.cases)){
    $statuses = @(Get-TaogeCertificationAxisStatus -Facts $case.facts)
    $actual = @($statuses | Where-Object environment_status -eq 'observed' | ForEach-Object axis | Sort-Object)
    $expected = @($case.observed_axes | ForEach-Object {[string]$_} | Sort-Object)
    $same = $actual.Count-eq$expected.Count -and [string]::Join('|',$actual)-ceq[string]::Join('|',$expected)
    Add-CertificationCheck $checks ("WIN-H7-FIXTURE-$($case.case_id)") $same ("expected="+[string]::Join(',',$expected)+";actual="+[string]::Join(',',$actual))
  }
  $workRoot = Join-Path $projectRoot 'state/checks/windows-certification-probe-work'
  if(-not(Test-Path -LiteralPath $workRoot)){New-Item -ItemType Directory -Path $workRoot -Force|Out-Null}
  $actualObservation = Get-TaogeWindowsCertificationFacts -TargetRoot $workRoot -ProbeWrite
  Add-CertificationCheck $checks 'WIN-H7-ACTUAL-AXIS-CARDINALITY' (@($actualObservation.axes).Count-eq7) "count=$(@($actualObservation.axes).Count)"
  Add-CertificationCheck $checks 'WIN-H7-ACTUAL-CASE-PROBE-CLEANUP' ([bool]$actualObservation.facts.case_probe_cleanup_succeeded -and @(Get-ChildItem -LiteralPath $workRoot -Filter '.taoge-case-*' -Force -ErrorAction SilentlyContinue).Count-eq0) "status=$($actualObservation.facts.case_probe_status)"
  Add-CertificationCheck $checks 'WIN-H7-PROBE-DOES-NOT-CERTIFY' (@($actualObservation.axes|Where-Object certification_status -ne 'not_certified_by_probe_alone').Count-eq0) 'Every axis requires full workflow validation after environment observation.'
  Add-CertificationCheck $checks 'WIN-H7-NO-SYSTEM-CONFIG-MUTATION' (-not[bool]$actualObservation.facts.system_configuration_mutated) 'Probe may create and clean files but must not change registry, policy, filesystem flags, shares, or Git config.'
  $failed=@($checks|Where-Object status -eq 'fail')
  $report=[ordered]@{windows_certification_fixture_report=[ordered]@{schema_version='taoge.windows-certification-fixture-report.v0.1';fixture_set_id=[string]$fixture.fixture_set_id;result=$(if($failed.Count){'fail'}else{'pass'});check_count=$checks.Count;pass_count=@($checks|Where-Object status -eq 'pass').Count;fail_count=$failed.Count;checks=[object[]]$checks.ToArray();actual_facts=$actualObservation.facts;system_configuration_mutated=$false}}
  $reportFull=if([System.IO.Path]::IsPathRooted($ReportPath)){[System.IO.Path]::GetFullPath($ReportPath)}else{[System.IO.Path]::GetFullPath((Join-Path $projectRoot $ReportPath))}
  Write-TaogeUtf8NoBomJson -Path $reportFull -Value $report -Depth 20
  foreach($check in $checks){Write-Output "$($check.check_id) $($check.status) $($check.evidence)"}
  Write-Output "WINDOWS_CERTIFICATION_FIXTURE=$($report.windows_certification_fixture_report.result)"
  if($failed.Count){exit 1}
  exit 0
} catch {
  Write-Error ("WINDOWS_CERTIFICATION_FIXTURE_ERROR="+$_.Exception.Message)
  exit 3
}
