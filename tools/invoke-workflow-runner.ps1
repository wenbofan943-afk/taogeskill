param([Parameter(Mandatory=$true)][string]$SessionPath,[ValidateSet('validate','render_final_delivery')][string]$Mode='validate')
$ErrorActionPreference='Stop'
try {
  & (Join-Path $PSScriptRoot 'validate-workflow-lineage.ps1') -SessionPath $SessionPath
  if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
  if($Mode -eq 'render_final_delivery'){ & (Join-Path $PSScriptRoot 'render-final-delivery.ps1') -SessionPath $SessionPath; exit $LASTEXITCODE }
  Write-Output 'WORKFLOW_RUNNER_RESULT=validated'; exit 0
} catch { Write-Error $_; exit 3 }
