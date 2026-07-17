param(
  [Parameter(Mandatory=$true)][string]$Session,
  [Parameter(Mandatory=$true)][ValidateSet('initialize','prepare_task','submit','reconcile','rebuild_projection','run_deterministic')][string]$Mode,
  [string]$BlueprintId='direct_delivery_single_v0.6',
  [ValidateSet('production','no_provider','reuse_only')][string]$TestProfile='production',
  [string]$SubmissionPath='',
  [string]$SubmissionId=''
)

$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WorkflowCompatibilityLoader.ps1')
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$implementationRef='compatibility/legacy-r7/tools/invoke-r7-semantic-workflow.impl.ps1'
$implementationPath=Resolve-WorkflowCompatibilityAsset `
  -ProjectRoot $projectRoot `
  -AssetReference $implementationRef `
  -CallerRuntimeGeneration 'legacy_r7'

& $implementationPath @PSBoundParameters
exit $LASTEXITCODE
