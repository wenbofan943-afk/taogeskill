param(
  [Parameter(Mandatory=$true)][ValidateSet('new_baseline','new_snapshot','evaluate_session','new_cohort','append_session','evaluate_route','evaluate_project')][string]$Mode,
  [string]$ProjectRoot='',[string]$RegistryPath='',
  [string]$BaselinePath='',[string]$SnapshotPath='',[string]$ObservationPath='',[string]$LedgerOutputPath='',[string]$SessionEvidencePath='',
  [string]$CohortPath='',[string]$DirectRoutePath='',[string]$HotspotRoutePath='',[string]$OutputPath='',
  [string]$BaselineId='',[string]$SnapshotId='',[string]$SessionId='',[string]$CohortId='',[string]$Route='',[string]$Timestamp=''
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'R7MaturityEvidence.ps1')
if([string]::IsNullOrWhiteSpace($ProjectRoot)){$ProjectRoot=Split-Path -Parent $PSScriptRoot}
if([string]::IsNullOrWhiteSpace($RegistryPath)){$RegistryPath=Join-Path $ProjectRoot 'routes/r7-runtime-capability-registry.json'}
try{
  $result=switch($Mode){
    'new_baseline'{New-R7MaturityBaseline $ProjectRoot $RegistryPath $BaselineId $Timestamp $OutputPath}
    'new_snapshot'{New-R7RunCapabilitySnapshot $ProjectRoot $RegistryPath $BaselinePath $SnapshotId $SessionId $Timestamp $OutputPath}
    'evaluate_session'{Invoke-R7SessionAutonomyEvaluation $ObservationPath $SnapshotPath $LedgerOutputPath $OutputPath}
    'new_cohort'{New-R7AutonomyCertificationCohort $CohortId ((Read-R7MaturityJson $BaselinePath).maturity_baseline_digest) $Timestamp $OutputPath}
    'append_session'{Add-R7SessionEvidenceToCohort $CohortPath $SessionEvidencePath}
    'evaluate_route'{Get-R7RouteAutonomyEvidence $CohortPath $Route $OutputPath}
    'evaluate_project'{Get-R7ProjectMaturityEvidence $CohortPath $DirectRoutePath $HotspotRoutePath $OutputPath}
  }
  [pscustomobject]@{result_code=$(if(Test-R7MaturityProperty $result 'result_code'){[string]$result.result_code}else{'pass'});mode=$Mode;output_path=$OutputPath}|ConvertTo-Json -Compress
  exit 0
}catch{[Console]::Error.WriteLine($_.Exception.Message);exit 1}
