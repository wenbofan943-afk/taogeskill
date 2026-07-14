Set-StrictMode -Version 2.0

if (-not (Get-Command ConvertTo-P0V3WarningsHtml -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'P0FinalDeliveryV03.ps1')
}

function Get-P0V4ScopeLabel {
  param([string]$Value)
  switch ($Value) {
    'ready_all_target_platforms' { '全部目标平台物料已通过视觉验收，可以人工发布' }
    'primary_ready_secondary_pending' { '主平台可人工发布；次平台仍待视觉验收' }
    default { '当前不可发布，请先处理视觉或内容阻断项' }
  }
}

function Get-P0V4PlatformReadinessLabel {
  param([string]$Value)
  switch ($Value) { 'ready' { '可人工发布' } 'waiting_visual_review' { '等待视觉验收' } default { '暂不可发布' } }
}

function Get-P0V4PresentationLabel {
  param([string]$Value)
  switch ($Value) {
    'full_frame_replace' { '全屏替换' } 'speaker_plus_visual' { '人物加画中画' }
    'split_screen' { '分屏' } 'floating_card' { '浮层卡片' }
    'source_evidence_card' { '来源证据卡' } 'background_plate' { '背景板' }
    default { $Value }
  }
}

function ConvertTo-P0V4PlatformUnitsHtml {
  param([object]$Document,[string]$Session,[string]$HtmlBase)
  $items=[System.Collections.Generic.List[string]]::new()
  foreach($unit in @($Document.platform_delivery_units|Sort-Object display_order)){
    $asset=Resolve-P0V2SessionReference $Session ([string]$unit.cover_asset_path) $HtmlBase
    $preview=Resolve-P0V2SessionReference $Session ([string]$unit.cover_preview_path) $HtmlBase
    $hashtags=[string]::Join(' ',@($unit.hashtags|ForEach-Object{Encode-P0V2Html $_}))
    $badgeClass=switch([string]$unit.publish_readiness){'ready'{'ok'}'blocked'{'bad'}default{'warn'}}
    $items.Add(('<article class="card platform-card" id="{0}"><div><h3>{1}</h3><div class="asset-pair"><div><span class="label">封面成品</span><img src="{2}" alt="{3}"><a class="download" href="{2}" download>下载封面成品</a></div><div><span class="label">平台表面预览（不等于真实平台截图）</span><img src="{4}" alt="{3}的平台预览"></div></div></div><div><span class="badge {5}">{6}</span><span class="badge">{7}</span><span class="badge">{8}</span><span class="label">封面标题</span><textarea class="copy-field" readonly>{9}</textarea><span class="label">视频标题</span><textarea class="copy-field" readonly>{10}</textarea><span class="label">发布描述</span><textarea class="copy-field" readonly>{11}</textarea><span class="label">话题标签</span><p>{12}</p><span class="label">适配与验收</span><p>策略：{13}；视觉验收：{14}；表面规格：{15}</p></div></article>' -f
      (Encode-P0V2Html $unit.unit_id),(Encode-P0V2Html $unit.platform_label),(Encode-P0V2Html $asset.HtmlPath),(Encode-P0V2Html $unit.rendered_cover_text),(Encode-P0V2Html $preview.HtmlPath),$badgeClass,(Encode-P0V2Html (Get-P0V4PlatformReadinessLabel $unit.publish_readiness)),(Encode-P0V2Html $unit.platform_priority),(Encode-P0V2Html $unit.preview_evidence_type),(Encode-P0V2Html $unit.cover_title),(Encode-P0V2Html $unit.video_title),(Encode-P0V2Html $unit.publish_description),$hashtags,(Encode-P0V2Html $unit.adaptation_strategy),(Encode-P0V2Html $unit.visual_review_status),(Encode-P0V2Html $unit.surface_profile_id)))
  }
  return [string]::Join("`n",$items)
}

function ConvertTo-P0V4VisualInsertCardsHtml {
  param([object]$Document,[string]$Session,[string]$HtmlBase)
  if(@($Document.visual_insert_cards).Count-eq0){return '<div class="card">本篇经视觉需求分析后不需要视觉插入。</div>'}
  $items=[System.Collections.Generic.List[string]]::new()
  foreach($card in @($Document.visual_insert_cards|Sort-Object display_order)){
    $asset=Resolve-P0V2SessionReference $Session ([string]$card.relative_path) $HtmlBase
    $prompt=Resolve-P0V2SessionReference $Session ([string]$card.prompt_path) $HtmlBase
    $generation=Resolve-P0V2SessionReference $Session ([string]$card.generation_record_path) $HtmlBase
    $sidecar=Resolve-P0V2SessionReference $Session ([string]$card.sidecar_path) $HtmlBase
    $evidence=ConvertTo-P0V3EvidenceMetaHtml -SidecarPath $sidecar.FullPath
    $slot='{0:P0}, {1:P0}, {2:P0} × {3:P0}' -f [double]$card.placement_slot.x,[double]$card.placement_slot.y,[double]$card.placement_slot.width,[double]$card.placement_slot.height
    $items.Add(('<article class="card visual-card" id="{0}"><div><h3>视觉插入 {1}</h3><img src="{2}" alt="{3}"><a class="download" href="{2}" download>下载图片</a></div><div><span class="badge ok">比例已验证</span><span class="badge">{4}</span><span class="label">精确插入位置</span><p>在“{5}”之后，进入“{6}”之前。</p><span class="label">画面用途</span><p>{7}</p><span class="label">版式与槽位</span><p>{8}；目标视频 {9}×{10}px；槽位 {11}</p><span class="label">画面文字</span><p>{12}</p>{16}<details><summary>展开图片追溯</summary><div class="details-body"><p>语义触发：{13}</p><p><a href="{14}">完整提示词</a> · <a href="{15}">生产记录</a></p></div></details></div></article>' -f
      (Encode-P0V2Html $card.card_id),([int]$card.display_order),(Encode-P0V2Html $asset.HtmlPath),(Encode-P0V2Html $card.preview_alt),(Encode-P0V2Html (Get-P0V4PresentationLabel $card.presentation_mode)),(Encode-P0V2Html $card.insert_after_text),(Encode-P0V2Html $card.insert_before_text),(Encode-P0V2Html $card.narrative_function),(Encode-P0V2Html $card.presentation_mode),([int]$card.video_canvas.width_px),([int]$card.video_canvas.height_px),(Encode-P0V2Html $slot),(Encode-P0V2Html $card.visual_text_summary),(Encode-P0V2Html $card.trigger_text),(Encode-P0V2Html $prompt.HtmlPath),(Encode-P0V2Html $generation.HtmlPath),$evidence))
  }
  return [string]::Join("`n",$items)
}

function New-P0V4ViewTexts {
  param([object]$Document,[string]$Session,[string]$ProjectRoot)
  $templatePath=Join-Path $ProjectRoot 'templates/final-delivery/final-delivery.v0.4.template.html'
  if(-not(Test-Path -LiteralPath $templatePath)){throw 'final_delivery_v04_template_missing'}
  $template=Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
  $htmlPath=Join-Path $Session ([string]$Document.delivery_revision.generated_view_paths.final_html);$htmlBase=Split-Path -Parent $htmlPath
  $scope=[string]$Document.production_status.platform_delivery_scope_status
  $readinessClass=switch($scope){'ready_all_target_platforms'{'ok'}'primary_ready_secondary_pending'{'warn'}default{'bad'}}
  $readinessBanner='<div class="banner {0}"><strong>{1}</strong></div>' -f $readinessClass,(Encode-P0V2Html (Get-P0V4ScopeLabel $scope))
  $provenanceBanner='<div class="banner"><strong>本轮生产说明：</strong>{0}</div>' -f (Encode-P0V2Html $Document.run_provenance.user_summary)
  $topicSummary='<article class="card"><strong>{0}</strong><p>{1}</p></article>' -f (Encode-P0V2Html $Document.topic.title),(Encode-P0V2Html $Document.topic.why_now)
  $durationSummary=switch([string]$Document.duration_estimate.duration_estimate_status){'measured'{'<div class="banner">实测口播时长：{0} 秒。</div>' -f [int]$Document.duration_estimate.measured_duration_seconds}'derived_range'{'<div class="banner">预计口播时长：{0}–{1} 秒；依据：{2}。</div>' -f [int]$Document.duration_estimate.estimated_duration_min_seconds,[int]$Document.duration_estimate.estimated_duration_max_seconds,(Encode-P0V2Html $Document.duration_estimate.derivation_method)}default{'<div class="banner">口播时长暂不估算：{0}</div>' -f (Encode-P0V2Html $Document.duration_estimate.not_available_reason)}}
  $auditCodes=[string]::Join(', ',@($Document.production_status.warning_codes));$auditMeta='<p><strong>Revision：</strong>{0} · <strong>Session：</strong>{1} · <strong>Render input：</strong>{2}</p><p><strong>交付范围：</strong>{3} · <strong>内部提醒代码：</strong>{4}</p>' -f (Encode-P0V2Html $Document.delivery_revision.delivery_revision_id),(Encode-P0V2Html $Document.session_id),(Encode-P0V2Html $Document.render_input_id),(Encode-P0V2Html $scope),(Encode-P0V2Html $auditCodes)
  $replacements=[ordered]@{title=Encode-P0V2Html $Document.topic.title;readiness_banner=$readinessBanner;provenance_banner=$provenanceBanner;topic_summary=$topicSummary;duration_summary=$durationSummary;script_text=Encode-P0V2Html $Document.script_card.final_text;platform_units=ConvertTo-P0V4PlatformUnitsHtml $Document $Session $htmlBase;visual_insert_cards=ConvertTo-P0V4VisualInsertCardsHtml $Document $Session $htmlBase;warning_items=ConvertTo-P0V3WarningsHtml $Document;action_cards=ConvertTo-P0V3ActionsHtml $Document;audit_meta=$auditMeta;trace_links=ConvertTo-P0V3TraceHtml $Document $Session $htmlBase}
  foreach($key in $replacements.Keys){$template=$template.Replace('{{'+$key+'}}',[string]$replacements[$key])}
  $scriptText="# Final Script`n`n``````yaml`ndelivery_revision_id: $($Document.delivery_revision.delivery_revision_id)`ndraft_id: $($Document.script_card.source_draft_id)`nstatus: $($Document.script_card.status)`n```````n`n$($Document.script_card.final_text)`n"
  $visualRows=@($Document.visual_insert_cards|Sort-Object display_order|ForEach-Object{"| $($_.display_order) | $($_.presentation_mode) | $($_.insert_after_text) | $($_.insert_before_text) | $($_.narrative_function) | $($_.relative_path) |"})
  $visualText="# Final Visual Plan`n`n> delivery_revision_id: $($Document.delivery_revision.delivery_revision_id)`n`n| 顺序 | 呈现方式 | 插在这句之后 | 进入这句之前 | 作用 | 文件 |`n|---:|---|---|---|---|---|`n$([string]::Join("`n",$visualRows))`n"
  $platformRows=@($Document.platform_delivery_units|Sort-Object display_order|ForEach-Object{"| $($_.platform_label) | $($_.platform_priority) | $($_.cover_title) | $($_.video_title) | $($_.publish_readiness) | $($_.cover_asset_path) | $($_.cover_preview_path) |"})
  $platformText="# Final Platform Package`n`n> delivery_revision_id: $($Document.delivery_revision.delivery_revision_id)`n`n| 平台 | 优先级 | 封面标题 | 视频标题 | 状态 | 封面成品 | 表面预览 |`n|---|---|---|---|---|---|---|`n$([string]::Join("`n",$platformRows))`n"
  $recordText="# Content Delivery Record`n`n``````yaml`ndelivery_revision_id: $($Document.delivery_revision.delivery_revision_id)`ndelivery_id: $($Document.final_delivery_id)`nsession_id: $($Document.session_id)`ndraft_id: $(Get-P0V3SourceId $Document 'draft')`nvisual_need_analysis_id: $(Get-P0V3SourceId $Document 'visual_need_analysis')`nplatform_delivery_scope_status: $scope`nrevision_status: current`npublish_status: publish_not_started`nnext_skill: human_final_review`n```````n`n本记录与同 revision 的 HTML、最终文案、视觉方案和平台包共同构成发布前交付；不表示已经登录平台或发布。`n"
  return [pscustomobject]@{TemplatePath=$templatePath;Html=$template.TrimEnd("`r","`n")+"`n";FinalScript=$scriptText;FinalVisualPlan=$visualText;FinalPlatformPackage=$platformText;ContentDeliveryRecord=$recordText}
}

function Test-P0V4RenderedHtml {
  param([string]$Html,[string]$OutputPath,[string]$Session)
  $errors=[System.Collections.Generic.List[string]]::new()
  if($Html-match'\{\{[^}]+\}\}'){$errors.Add('v04_unresolved_template_token')}
  if($Html-match'(?is)<\s*script\b|\bon[a-z]+\s*=|javascript\s*:'){$errors.Add('v04_unsafe_html_output')}
  if([regex]::Matches($Html,'<h1\b','IgnoreCase').Count-ne1-or[regex]::Matches($Html,'<main\b','IgnoreCase').Count-ne1){$errors.Add('v04_page_structure_invalid')}
  if($Html-notmatch'data-template-version="0\.4\.0"' -or $Html-notmatch'平台表面预览'){$errors.Add('v04_visual_contract_missing')}
  foreach($error in (Get-P0V2BrokenReferences $Html $OutputPath $Session)){$errors.Add($error)}
  return [object[]]$errors.ToArray()
}

function Test-P0V4RenderReceipt {
  param([object]$Receipt)
  $errors=[System.Collections.Generic.List[string]]::new();$fields=@('schema_id','schema_version','receipt_id','delivery_revision_id','render_input_sha256','renderer_version','template_sha256','included_card_ids','included_asset_ids','warning_codes','output_view_sha256')
  foreach($error in (Test-P0RequiredProperties $Receipt $fields 'render_receipt_v04')){$errors.Add($error)};foreach($error in (Test-P0AllowedProperties $Receipt $fields 'render_receipt_v04')){$errors.Add($error)}
  if($errors.Count){return [object[]]$errors.ToArray()}
  if($Receipt.schema_id-ne'taoge://schemas/p0/render-receipt/v0.4'-or$Receipt.schema_version-ne'0.4'-or$Receipt.renderer_version-ne'final-delivery-renderer-v0.4'){$errors.Add('render_receipt_v04_version_invalid')}
  foreach($field in @('render_input_sha256','template_sha256')){if(-not(Test-P0Digest $Receipt.$field)){$errors.Add("render_receipt_v04_digest_invalid:$field")}}
  foreach($property in $Receipt.output_view_sha256.PSObject.Properties){if(-not(Test-P0Digest $property.Value)){$errors.Add("render_receipt_v04_output_digest_invalid:$($property.Name)")}}
  return [object[]]$errors.ToArray()
}

function Test-P0V4RevisionClosure {
  param([string]$Session,[object]$Document,[string]$DocumentDigest,[string]$ProjectRoot)
  $manifestPath=Join-Path $Session ([string]$Document.delivery_revision.generated_view_paths.revision_manifest);$receiptPath=Join-Path $Session 'deliverables/p0/render-receipt.json'
  if(-not(Test-Path $manifestPath)-or-not(Test-Path $receiptPath)){return $false}
  try{$manifest=Read-P0JsonFile $manifestPath;$receipt=Read-P0JsonFile $receiptPath;$templatePath=Join-Path $ProjectRoot 'templates/final-delivery/final-delivery.v0.4.template.html';if(@(Test-P0V4RenderReceipt $receipt).Count-ne0-or$manifest.revision_status-ne'current'-or$manifest.delivery_revision_id-ne$Document.delivery_revision.delivery_revision_id-or$receipt.render_input_sha256-ne$DocumentDigest-or$receipt.template_sha256-ne(Get-P0V2Hash $templatePath)){return $false};foreach($artifact in @($manifest.output_artifacts)){$path=Join-Path $Session ([string]$artifact.path);if(-not(Test-Path $path)-or(Get-P0V2Hash $path)-ne[string]$artifact.sha256){return $false}};return $true}catch{return $false}
}

function Write-P0V4DeliveryViews {
  param([object]$Document,[string]$Session,[string]$ProjectRoot,[string]$DocumentDigest)
  $views=New-P0V4ViewTexts $Document $Session $ProjectRoot;$paths=$Document.delivery_revision.generated_view_paths
  $writeMap=[ordered]@{final_script=[pscustomobject]@{Path=[string]$paths.final_script;Text=$views.FinalScript};final_visual_plan=[pscustomobject]@{Path=[string]$paths.final_visual_plan;Text=$views.FinalVisualPlan};final_platform_package=[pscustomobject]@{Path=[string]$paths.final_platform_package;Text=$views.FinalPlatformPackage};content_delivery_record=[pscustomobject]@{Path=[string]$paths.content_delivery_record;Text=$views.ContentDeliveryRecord};final_html=[pscustomobject]@{Path=[string]$paths.final_html;Text=$views.Html}}
  foreach($entry in $writeMap.GetEnumerator()){Write-P0V2AtomicText (Join-Path $Session ([string]$entry.Value.Path)) ([string]$entry.Value.Text)}
  $htmlPath=Join-Path $Session ([string]$paths.final_html);$htmlErrors=@(Test-P0V4RenderedHtml (Get-Content $htmlPath -Raw -Encoding UTF8) $htmlPath $Session);if($htmlErrors.Count){throw('v04_rendered_html_invalid:'+($htmlErrors-join';'))}
  $outputArtifacts=[System.Collections.Generic.List[object]]::new();$digestObject=[ordered]@{};foreach($entry in $writeMap.GetEnumerator()){$full=Join-Path $Session ([string]$entry.Value.Path);$digest=Get-P0V2Hash $full;$digestObject[$entry.Key]=$digest;$outputArtifacts.Add([ordered]@{artifact_type=$entry.Key;path=[string]$entry.Value.Path;sha256=$digest})}
  $cardIds=@([string]$Document.script_card.card_id)+@($Document.cover_cards+$Document.visual_insert_cards+$Document.platform_cards+$Document.trace_cards+$Document.action_cards|ForEach-Object{[string]$_.card_id});$assetIds=@($Document.cover_cards+$Document.visual_insert_cards|ForEach-Object{[string]$_.asset_id}|Sort-Object -Unique)
  $receipt=[ordered]@{schema_id='taoge://schemas/p0/render-receipt/v0.4';schema_version='0.4';receipt_id=('RCP-'+[string]$Document.final_delivery_id);delivery_revision_id=[string]$Document.delivery_revision.delivery_revision_id;render_input_sha256=$DocumentDigest;renderer_version='final-delivery-renderer-v0.4';template_sha256=Get-P0V2Hash $views.TemplatePath;included_card_ids=[object[]]@($cardIds|Sort-Object -Unique);included_asset_ids=[object[]]$assetIds;warning_codes=[object[]]@($Document.production_status.warning_codes|Sort-Object -Unique);output_view_sha256=[pscustomobject]$digestObject}
  $receiptErrors=@(Test-P0V4RenderReceipt ([pscustomobject]$receipt));if($receiptErrors.Count){throw('v04_receipt_invalid:'+($receiptErrors-join';'))};Write-P0V2AtomicText (Join-Path $Session 'deliverables/p0/render-receipt.json') (ConvertTo-P0V2JsonText $receipt)
  $manifest=[ordered]@{schema_id='taoge://schemas/p0/delivery-revision/v0.4';schema_version='0.4';delivery_revision_id=[string]$Document.delivery_revision.delivery_revision_id;session_id=[string]$Document.session_id;revision_no=[int]$Document.delivery_revision.revision_no;revision_status='current';semantic_gate_status='pass';render_input_id=[string]$Document.render_input_id;render_input_sha256=$DocumentDigest;source_artifact_bindings=[object[]]$Document.delivery_revision.source_artifact_bindings;output_artifacts=[object[]]$outputArtifacts.ToArray();committed_at=[DateTimeOffset]::UtcNow.ToString('o')}
  Write-P0V2AtomicText (Join-Path $Session ([string]$paths.revision_manifest)) (ConvertTo-P0V2JsonText $manifest);return [pscustomobject]@{HtmlSha256=[string]$digestObject.final_html;Receipt=$receipt;Manifest=$manifest}
}
