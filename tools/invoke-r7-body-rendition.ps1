param([Parameter(Mandatory=$true)][string]$SessionRoot,[Parameter(Mandatory=$true)][string]$RequestPath)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'WindowsRuntimeHelper.ps1')
function Resolve-BodyPath([string]$Root,[string]$Relative){
  if([IO.Path]::IsPathRooted($Relative)-or$Relative-match'(^|[\\/])\.\.([\\/]|$)'){throw "body_rendition_path_invalid:$Relative"}
  $r=[IO.Path]::GetFullPath($Root).TrimEnd([char]92,[char]47);$p=[IO.Path]::GetFullPath((Join-Path $r $Relative));if(-not$p.StartsWith($r+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw "body_rendition_root_escape:$Relative"};return $p
}
function Get-BodyHash([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
try{
  $root=[IO.Path]::GetFullPath($SessionRoot);$request=Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8|ConvertFrom-Json
  foreach($name in @('schema_id','schema_version','operation_id','session_id','rendition_id','source_asset_ref','target_canvas','output_relative_path','record_relative_path','requested_at')){if($null-eq$request.PSObject.Properties[$name]){throw "body_rendition_request_missing:$name"}}
  if($request.schema_id-ne'taoge://schemas/r7/body-image-rendition-request/v0.1'-or$request.schema_version-ne'0.1'){throw 'body_rendition_request_version_invalid'}
  if($request.operation_id-notin@('crop_fit_pad','platform_rendition')){throw 'body_rendition_operation_invalid'}
  $source=Resolve-BodyPath $root ([string]$request.source_asset_ref.relative_path);$output=Resolve-BodyPath $root ([string]$request.output_relative_path);$record=Resolve-BodyPath $root ([string]$request.record_relative_path)
  if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw 'body_rendition_source_missing'};$sourceHash=Get-BodyHash $source;if($sourceHash-ne(([string]$request.source_asset_ref.sha256)-replace'^sha256:','')){throw 'body_rendition_source_hash_mismatch'}
  $digest='sha256:'+((Get-BodyHash $RequestPath));if(Test-Path -LiteralPath $record){$prior=Get-Content -LiteralPath $record -Raw -Encoding UTF8|ConvertFrom-Json;if($prior.request_digest-ne$digest){throw 'body_rendition_revision_required'};if($prior.status-in@('succeeded','reconciled')-and(Test-Path -LiteralPath $output)){if((Get-BodyHash $output)-eq(($prior.output_ref.sha256)-replace'^sha256:','')){Write-Output 'BODY_RENDITION_STATUS=pass';Write-Output 'BODY_RENDITION_ACTION=reused_verified';exit 0}}}
  $start=[ordered]@{schema_id='taoge://records/r7/body-image-rendition/v0.1';schema_version='0.1';rendition_id=$request.rendition_id;operation_id=$request.operation_id;request_digest=$digest;status='started';source_asset_ref=$request.source_asset_ref;started_at=[DateTimeOffset]::UtcNow.ToString('o')};Write-TaogeUtf8NoBomJson -Path $record -Value $start -Depth 12
  Add-Type -AssemblyName System.Drawing;$img=$null;$canvas=$null;$g=$null
  try{$img=[Drawing.Image]::FromFile($source);$w=[int]$request.target_canvas.width_px;$h=[int]$request.target_canvas.height_px;$canvas=New-Object Drawing.Bitmap($w,$h);$g=[Drawing.Graphics]::FromImage($canvas);$g.Clear([Drawing.Color]::FromArgb(20,24,32));$scale=[Math]::Min($w/$img.Width,$h/$img.Height);$dw=[int][Math]::Round($img.Width*$scale);$dh=[int][Math]::Round($img.Height*$scale);$g.DrawImage($img,[int](($w-$dw)/2),[int](($h-$dh)/2),$dw,$dh);$parent=Split-Path -Parent $output;if(-not(Test-Path $parent)){New-Item -ItemType Directory -Force -Path $parent|Out-Null};$canvas.Save($output,[Drawing.Imaging.ImageFormat]::Png)}finally{foreach($x in @($g,$canvas,$img)){if($null-ne$x){$x.Dispose()}}}
  $result=[ordered]@{schema_id='taoge://records/r7/body-image-rendition/v0.1';schema_version='0.1';rendition_id=$request.rendition_id;operation_id=$request.operation_id;request_digest=$digest;status='succeeded';source_asset_ref=$request.source_asset_ref;output_ref=[ordered]@{relative_path=$request.output_relative_path;sha256='sha256:'+(Get-BodyHash $output)};completed_at=[DateTimeOffset]::UtcNow.ToString('o')};Write-TaogeUtf8NoBomJson -Path $record -Value $result -Depth 12;Write-Output 'BODY_RENDITION_STATUS=pass';Write-Output 'BODY_RENDITION_ACTION=rendered';Write-Output "OUTPUT_PATH=$output"
}catch{Write-Error $_;exit 3}
