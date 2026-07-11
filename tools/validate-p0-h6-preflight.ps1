param(
  [Parameter(Mandatory=$true)][string]$H5SessionPath,
  [Parameter(Mandatory=$true)][string]$PromptSourceSessionPath,
  [string]$ReportPath='state/checks/p0-h6-preflight-report.json'
)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2.0
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
function Resolve-H6Path([string]$Path){$candidate=if([IO.Path]::IsPathRooted($Path)){$Path}else{Join-Path $projectRoot $Path};return [IO.Path]::GetFullPath($candidate)}
function Get-H6Digest([string]$Text){$bytes=[Text.Encoding]::UTF8.GetBytes($Text);$hash=[Security.Cryptography.SHA256]::Create().ComputeHash($bytes);return 'sha256:'+(($hash|ForEach-Object{$_.ToString('x2')})-join'')}
try{
  $h5=Resolve-H6Path $H5SessionPath;$source=Resolve-H6Path $PromptSourceSessionPath;$accounts=[IO.Path]::GetFullPath((Join-Path $projectRoot 'accounts')).TrimEnd('\')
  if(-not(Test-Path $h5)-or-not(Test-Path $source)){Write-Error 'h5_or_prompt_source_missing';exit 4}
  if(-not$h5.StartsWith($accounts+'\',[StringComparison]::OrdinalIgnoreCase)-or-not$source.StartsWith($accounts+'\',[StringComparison]::OrdinalIgnoreCase)-or(Split-Path -Parent (Split-Path -Parent $h5))-ne(Split-Path -Parent (Split-Path -Parent $source))){throw 'h6_sessions_must_share_project_account'}
  $provenance=Get-Content -Raw (Join-Path $h5 'inputs/h5-regression-provenance.json') -Encoding UTF8|ConvertFrom-Json
  $records=@(Get-ChildItem (Join-Path $source 'assets/images/generation-records') -Filter 'GEN-*.md' -File|Sort-Object Name)
  $prompts=[System.Collections.Generic.List[object]]::new();$errors=[System.Collections.Generic.List[string]]::new()
  foreach($record in $records){$text=Get-Content -Raw $record.FullName -Encoding UTF8;$match=[regex]::Match($text,'(?ms)^## Prompt Used\s*\r?\n(.*?)\s*$');if(-not$match.Success){$errors.Add("prompt_text_missing:$($record.Name)");continue};$prompt=$match.Groups[1].Value.Trim();$asset=[regex]::Match($text,'(?m)^asset_id:\s*(.+?)\s*$').Groups[1].Value.Trim();$type=[regex]::Match($text,'(?m)^image_asset_type:\s*(.+?)\s*$').Groups[1].Value.Trim();$prompts.Add([pscustomobject][ordered]@{source_record=$record.Name;source_session_id=(Split-Path -Leaf $source);source_asset_id=$asset;image_asset_type=$type;prompt_text=$prompt;prompt_sha256=Get-H6Digest $prompt})}
  $coverCount=@($prompts|Where-Object{$_.image_asset_type -eq 'cover_image'}).Count;$pipCount=@($prompts|Where-Object{$_.image_asset_type -eq 'picture_in_picture_image'}).Count
  if($coverCount -ne [int]$provenance.cover_background_count){$errors.Add('cover_prompt_count_mismatch')};if($pipCount -ne [int]$provenance.planned_pip_count){$errors.Add('pip_prompt_count_mismatch')};if($prompts.Count -ne ($coverCount+$pipCount)){$errors.Add('baseline_prompt_evidence_count_mismatch')}
  if(@($prompts|Group-Object prompt_sha256|Where-Object{$_.Count -gt 1}).Count){$errors.Add('prompt_digest_duplicate')}
  $result=if($errors.Count){'blocked'}else{'baseline_prompt_evidence_ready_waiting_visual_need_analysis'}
  $report=[ordered]@{schema_id='taoge://reports/p0/h6-preflight/v0.2';schema_version='0.2';generated_at=[DateTimeOffset]::UtcNow.ToString('o');h5_session_id=(Split-Path -Leaf $h5);prompt_source_session_id=(Split-Path -Leaf $source);preflight_result=$result;provider_route='codex_builtin_image2';visual_count_policy='content_derived_unbounded';generation_policy='generate_all_accepted';provider_call_limit=$null;cost_gate='not_applicable';baseline_prompt_evidence_count=$prompts.Count;accepted_visual_task_count=$null;external_calls_executed=0;prompts=[object[]]$prompts.ToArray();errors=[object[]]$errors.ToArray()}
  $out=Resolve-H6Path $ReportPath;$parent=Split-Path -Parent $out;if(-not(Test-Path $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};[IO.File]::WriteAllText($out,(($report|ConvertTo-Json -Depth 20)+"`n"),[Text.UTF8Encoding]::new($false))
  Write-Output "P0_H6_PREFLIGHT=$result";Write-Output "BASELINE_PROMPT_EVIDENCE_COUNT=$($prompts.Count)";Write-Output "PIP_PROMPT_EVIDENCE_COUNT=$pipCount";Write-Output "COVER_PROMPT_EVIDENCE_COUNT=$coverCount";Write-Output 'PROVIDER_CALL_LIMIT=not_applicable';Write-Output "REPORT=$out";if($errors.Count){exit 2};exit 0
}catch{Write-Error ('P0_H6_PREFLIGHT_ERROR='+$_.Exception.Message);exit 3}
