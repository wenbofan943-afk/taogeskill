param(
  [Parameter(Mandatory=$true)][string]$SessionRoot,
  [Parameter(Mandatory=$true)][string]$AssetSetPath,
  [string]$OutputPath='intermediate/r7/h7/image-asset-delivery-set.json'
)
$ErrorActionPreference='Stop'
$requestedSessionRoot=$SessionRoot
$requestedAssetSetPath=$AssetSetPath
$requestedOutputPath=$OutputPath
. (Join-Path $PSScriptRoot 'P0RuntimeV02.ps1')
. (Join-Path $PSScriptRoot 'R7ContractHelper.ps1')
. (Join-Path $PSScriptRoot 'R7SemanticRuntime.ps1')
. (Join-Path $PSScriptRoot 'R7H7DeliveryContract.ps1')
$root=[IO.Path]::GetFullPath($requestedSessionRoot)
$assetPath=if([IO.Path]::IsPathRooted($requestedAssetSetPath)){[IO.Path]::GetFullPath($requestedAssetSetPath)}else{Resolve-R7RuntimePath $root $requestedAssetSetPath}
$assetSet=Read-R7JsonFile $assetPath
$result=New-R7H7ImageAssetDeliverySet $root $assetSet (Get-R7RuntimeHash $assetPath)
if($result.ExitCode-ne0){$result|ConvertTo-Json -Depth 20;exit $result.ExitCode}
foreach($record in @($result.RecordWrites)){
  if([string]::IsNullOrWhiteSpace([string]$record.RelativePath)){throw 'finalize_record_path_missing'}
  $recordPath=Resolve-R7RuntimePath $root ([string]$record.RelativePath)
  Write-P0EvidenceAtomicText $recordPath ([string]$record.Text)
  if((Get-R7RuntimeHash $recordPath)-ne[string]$record.Sha256){throw "finalize_record_digest_mismatch:$($record.RelativePath)"}
}
if([string]::IsNullOrWhiteSpace($requestedOutputPath)){throw 'finalize_output_path_missing'}
$out=Resolve-R7RuntimePath $root $requestedOutputPath
Write-P0EvidenceAtomicText $out (ConvertTo-P0EvidenceJsonText $result.Data)
[pscustomobject]@{ResultCode='finalized';ExitCode=0;OutputPath=$requestedOutputPath;DeliveryAssetCount=[int]$result.Data.delivery_asset_count}|ConvertTo-Json -Depth 5
