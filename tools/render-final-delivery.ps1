param(
  [Parameter(Mandatory=$true)][string]$SessionPath,
  [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'YamlHelper.ps1')
function V($M,[string]$K){ if($M -is [System.Collections.IDictionary]){return $M[$K]}; $p=$M.PSObject.Properties[$K]; if($p){return $p.Value}; return $null }
function EncodeHtml([string]$Text){ return [System.Net.WebUtility]::HtmlEncode($Text) }
try {
  $session=(Resolve-Path -LiteralPath $SessionPath).Path; $manifest=Read-YamlFile (Join-Path $session 'manifest.yaml'); $a=V $manifest 'artifacts'; $ids=V $manifest 'ids'; $statuses=V $manifest 'statuses'
  if([string]::IsNullOrWhiteSpace($OutputPath)){ $OutputPath=Join-Path $session 'deliverables/final-delivery.rendered.html' }
  $template=Get-Content -LiteralPath (Join-Path $PSScriptRoot '../templates/final-delivery/final-delivery.template.html') -Raw -Encoding UTF8
  $delivery=Get-Content -LiteralPath (Join-Path $session ([string](V $a 'content_delivery_record'))) -Raw -Encoding UTF8
  $script=Get-Content -LiteralPath (Join-Path $session ([string](V $a 'final_script'))) -Raw -Encoding UTF8
  $platform=Get-Content -LiteralPath (Join-Path $session ([string](V $a 'final_platform_package'))) -Raw -Encoding UTF8
  $topic=if($delivery -match '(?m)^topic_title:\s*(.+)$'){$matches[1]}else{[string](V $ids 'topic_id')}
  $images=Get-ChildItem -LiteralPath (Join-Path $session 'assets/images') -Filter 'PIP-*.png' -File | Select-Object -First 6 | ForEach-Object { '<div class="item"><img src="../assets/images/'+(EncodeHtml $_.Name)+'" alt="画中画 '+(EncodeHtml $_.BaseName)+'"><br><a href="../assets/images/'+(EncodeHtml $_.Name)+'" download>下载图片</a></div>' }
  $links=@(); foreach($key in @('topic_card','content_brief','draft','visual_plan','quality_review','platform_package','content_delivery_record','html_embed_manifest')){ $p=[string](V $a $key); if($p){$links += '<div class="item"><a href="../'+(EncodeHtml $p)+'">'+(EncodeHtml $key)+'</a></div>'} }
  $replace=@{title=$topic;account=[string](V $manifest 'account');session_id=[string](V $manifest 'session_id');source_research_run_id=[string](V $manifest 'source_research_run_id');delivery_page_mode='project_local';final_delivery_status='html_ready';image_assets_status=[string](V $statuses 'image_assets_status');visual_text_plan_id=[string](V $ids 'visual_text_plan_id');visual_text_quality_gate_status=[string](V $statuses 'visual_text_quality_gate_status');cover_design_package_id=[string](V $ids 'cover_design_package_id');upload_ready_cover_count='not_calculated';prompt_only_cover_count='not_calculated';html_builder_mode='skill_template_rendered';html_template_source='templates/final-delivery/final-delivery.template.html';topic_title=$topic;topic_rationale='由 content_delivery_record 与 research_run_id 追溯。';hook_text=($script -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 1);final_script=(EncodeHtml $script);cover_design_summary='请在追溯材料中查看封面合成记录。';cover_quality_summary='由 cover quality gate 决定是否可上传。';platform_cover_strategy='<div class="item">请查看封面合成记录</div>';cover_ready_assets='<div class="item">请查看封面合成记录与图片资产</div>';cover_background_assets='<div class="item">无独立汇总</div>';cover_prompt_only_assets='<div class="item">无</div>';visual_text_delivery_summary='请查看 html_embed_manifest。';picture_in_picture_assets=($images -join "`n");platform_package=('<div class="item"><pre>'+(EncodeHtml $platform)+'</pre></div>');trace_links=($links -join "`n");human_prompt='最终 HTML 已按固定模板渲染。可认可、局部返工、导出转交包、记录人工发布结果或归档。'}
  foreach($key in $replace.Keys){$template=$template.Replace('{{'+$key+'}}',[string]$replace[$key])}; $template | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  Write-Output "FINAL_DELIVERY_RENDERED=$OutputPath"; exit 0
} catch { Write-Error $_; exit 3 }
