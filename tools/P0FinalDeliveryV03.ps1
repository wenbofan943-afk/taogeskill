Set-StrictMode -Version 2.0

function Get-P0V3PlatformReadinessLabel {
  param([string]$Value)
  switch ($Value) { 'ready' { '可发布' } 'ready_with_warnings' { '可发布，有提醒' } 'blocked' { '暂不可发布' } default { '需要处理' } }
}

function Get-P0V3DeliveryReadinessLabel {
  param([string]$Value)
  switch ($Value) { 'ready' { '交付物已齐，可以人工发布' } 'ready_with_warnings' { '交付物已齐，请先阅读发布前提醒' } 'blocked' { '暂不可发布，请先处理阻断项' } default { '仍有物料需要处理' } }
}

function Get-P0V3SourceId {
  param([object]$Document, [string]$ArtifactType)
  $binding = @($Document.delivery_revision.source_artifact_bindings | Where-Object { $_.artifact_type -eq $ArtifactType }) | Select-Object -First 1
  if ($null -eq $binding) { return 'not_available' }
  return [string]$binding.artifact_id
}

function ConvertTo-P0V3PlatformUnitsHtml {
  param([object]$Document, [string]$Session, [string]$HtmlBase)
  $items = [System.Collections.Generic.List[string]]::new()
  foreach ($unit in @($Document.platform_delivery_units | Sort-Object display_order)) {
    $cover = Resolve-P0V2SessionReference $Session ([string]$unit.cover_asset_path) $HtmlBase
    $hashtags = [string]::Join(' ', @($unit.hashtags | ForEach-Object { Encode-P0V2Html $_ }))
    $items.Add(('<article class="card platform-card" id="{0}"><div><h3>{1}</h3><img src="{2}" alt="{3}"><a class="download" href="{2}" download>下载该平台封面</a></div><div><span class="label">封面标题</span><textarea class="copy-field" readonly>{4}</textarea><span class="label">视频标题</span><textarea class="copy-field" readonly>{5}</textarea><span class="label">发布描述</span><textarea class="copy-field" readonly>{6}</textarea><span class="label">话题标签</span><p>{7}</p><span class="label">状态</span><strong>{8}</strong></div></article>' -f (Encode-P0V2Html $unit.unit_id),(Encode-P0V2Html $unit.platform_label),(Encode-P0V2Html $cover.HtmlPath),(Encode-P0V2Html $unit.rendered_cover_text),(Encode-P0V2Html $unit.cover_title),(Encode-P0V2Html $unit.video_title),(Encode-P0V2Html $unit.publish_description),$hashtags,(Encode-P0V2Html (Get-P0V3PlatformReadinessLabel ([string]$unit.publish_readiness)))))
  }
  return [string]::Join("`n", $items)
}

function ConvertTo-P0V3EvidenceMetaHtml {
  param([string]$SidecarPath)
  if (-not (Test-Path -LiteralPath $SidecarPath -PathType Leaf)) { return '' }
  try {
    $sidecar = Get-Content -LiteralPath $SidecarPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($sidecar.schema_id -ne 'taoge://r6/evidence-pip-sidecar/v0.1') { return '' }
    $required = @('publisher','canonical_url','source_title','capture_at','source_screenshot_sha256','claim_evidence_status','binding_id','source_label','commentary_label','creator_commentary')
    if (@($required | Where-Object { -not (Test-P0HasProperty $sidecar $_) -or [string]::IsNullOrWhiteSpace([string]$sidecar.$_) }).Count -gt 0) { return '<div class="banner warn">证据追溯字段不完整，请回到新闻证据画中画修复。</div>' }
    if ([string]$sidecar.canonical_url -notmatch '^https?://') { return '<div class="banner warn">证据来源链接不是公开 HTTP(S) 地址。</div>' }
    $hash = [string]$sidecar.source_screenshot_sha256
    $shortHash = if ($hash.Length -gt 16) { $hash.Substring(0,16) + '…' } else { $hash }
    return ('<div class="evidence-meta"><span class="label">{0}</span><p><strong>{1}</strong> · {2}</p><p><a href="{3}" target="_blank" rel="noopener noreferrer">打开公开来源</a> · 捕获 {4}</p><p>证据关系：{5} · 截图 SHA256：<code>{6}</code></p><span class="label">{7}</span><p>{8}</p></div>' -f (Encode-P0V2Html $sidecar.source_label),(Encode-P0V2Html $sidecar.publisher),(Encode-P0V2Html $sidecar.source_title),(Encode-P0V2Html $sidecar.canonical_url),(Encode-P0V2Html $sidecar.capture_at),(Encode-P0V2Html $sidecar.claim_evidence_status),(Encode-P0V2Html $shortHash),(Encode-P0V2Html $sidecar.commentary_label),(Encode-P0V2Html $sidecar.creator_commentary))
  } catch {
    return '<div class="banner warn">证据 sidecar 无法读取，请回到新闻证据画中画修复。</div>'
  }
}

function ConvertTo-P0V3PipCardsHtml {
  param([object]$Document, [string]$Session, [string]$HtmlBase)
  if (@($Document.pip_cards).Count -eq 0) { return '<div class="card">本篇经视觉需求分析后不需要画中画。</div>' }
  $items = [System.Collections.Generic.List[string]]::new()
  foreach ($card in @($Document.pip_cards | Sort-Object display_order)) {
    $asset = Resolve-P0V2SessionReference $Session ([string]$card.relative_path) $HtmlBase
    $prompt = Resolve-P0V2SessionReference $Session ([string]$card.prompt_path) $HtmlBase
    $generation = Resolve-P0V2SessionReference $Session ([string]$card.generation_record_path) $HtmlBase
    $sidecar = Resolve-P0V2SessionReference $Session ([string]$card.sidecar_path) $HtmlBase
    $evidenceMeta = ConvertTo-P0V3EvidenceMetaHtml -SidecarPath $sidecar.FullPath
    $items.Add(('<article class="card pip-card" id="{0}"><div><h3>画中画 {1}</h3><img src="{2}" alt="{3}"><a class="download" href="{2}" download>下载图片</a></div><div><span class="label">精确插入位置</span><p>在“{4}”之后，进入“{5}”之前。</p><span class="label">这张图解决什么</span><p>{6}</p><span class="label">画面文字</span><p>{7}</p>{12}<details><summary>展开图片追溯</summary><div class="details-body"><p>语义触发：{8}</p><p><a href="{9}">完整提示词组</a> · <a href="{10}">生产记录</a> · <a href="{11}">图片 sidecar</a></p></div></details></div></article>' -f (Encode-P0V2Html $card.card_id),([int]$card.display_order),(Encode-P0V2Html $asset.HtmlPath),(Encode-P0V2Html $card.preview_alt),(Encode-P0V2Html $card.insert_after_text),(Encode-P0V2Html $card.insert_before_text),(Encode-P0V2Html $card.narrative_function),(Encode-P0V2Html $card.visual_text_summary),(Encode-P0V2Html $card.trigger_text),(Encode-P0V2Html $prompt.HtmlPath),(Encode-P0V2Html $generation.HtmlPath),(Encode-P0V2Html $sidecar.HtmlPath),$evidenceMeta))
  }
  return [string]::Join("`n", $items)
}

function ConvertTo-P0V3WarningsHtml {
  param([object]$Document)
  $active = @($Document.warning_items | Where-Object { $_.resolution_status -ne 'resolved' })
  if ($active.Count -eq 0) { return '<div class="banner ok">当前没有开放的发布前提醒。</div>' }
  $items = [System.Collections.Generic.List[string]]::new()
  foreach ($warning in $active) {
    $items.Add(('<article class="warning-item"><strong>{0}</strong><p>{1}</p><span class="label">建议处理</span><p>{2}</p></article>' -f (Encode-P0V2Html $warning.user_message),(Encode-P0V2Html $warning.impact),(Encode-P0V2Html $warning.recommended_action)))
  }
  return [string]::Join("`n", $items)
}

function ConvertTo-P0V3TraceHtml {
  param([object]$Document, [string]$Session, [string]$HtmlBase)
  $items = [System.Collections.Generic.List[string]]::new()
  foreach ($card in @($Document.trace_cards | Sort-Object display_order)) {
    $reference = Resolve-P0V2SessionReference $Session ([string]$card.relative_path) $HtmlBase
    $items.Add(('<article class="card"><span class="label">{0} · {1}</span><a href="{2}">{3}</a></article>' -f (Encode-P0V2Html $card.artifact_type),(Encode-P0V2Html $card.artifact_id),(Encode-P0V2Html $reference.HtmlPath),(Encode-P0V2Html $card.label)))
  }
  return [string]::Join("`n", $items)
}

function ConvertTo-P0V3ActionsHtml {
  param([object]$Document)
  $items = [System.Collections.Generic.List[string]]::new()
  foreach ($card in @($Document.action_cards | Sort-Object display_order)) {
    $items.Add(('<article class="action"><strong>{0}</strong><p>{1}</p><span class="label">可直接回复</span><code>{2}</code></article>' -f (Encode-P0V2Html $card.label),(Encode-P0V2Html $card.instruction),(Encode-P0V2Html $card.reply_example)))
  }
  return [string]::Join("`n", $items)
}

function New-P0V3ViewTexts {
  param([object]$Document, [string]$Session, [string]$ProjectRoot)
  $templatePath = Join-Path $ProjectRoot 'templates/final-delivery/final-delivery.v0.3.template.html'
  if (-not (Test-Path -LiteralPath $templatePath)) { throw 'final_delivery_v03_template_missing' }
  $template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
  $htmlPath = Join-Path $Session ([string]$Document.delivery_revision.generated_view_paths.final_html)
  $htmlBase = Split-Path -Parent $htmlPath
  $readinessClass = if ($Document.production_status.delivery_readiness -eq 'ready') { 'ok' } else { 'warn' }
  $readinessBanner = '<div class="banner {0}"><strong>{1}</strong></div>' -f $readinessClass,(Encode-P0V2Html (Get-P0V3DeliveryReadinessLabel ([string]$Document.production_status.delivery_readiness)))
  $provenanceBanner = '<div class="banner"><strong>本轮生产说明：</strong>{0}</div>' -f (Encode-P0V2Html $Document.run_provenance.user_summary)
  $topicSummary = '<article class="card"><strong>{0}</strong><p>{1}</p></article>' -f (Encode-P0V2Html $Document.topic.title),(Encode-P0V2Html $Document.topic.why_now)
  $durationSummary = switch ([string]$Document.duration_estimate.duration_estimate_status) {
    'measured' { '<div class="banner">实测口播时长：{0} 秒。</div>' -f [int]$Document.duration_estimate.measured_duration_seconds }
    'derived_range' { '<div class="banner">预计口播时长：{0}–{1} 秒；依据：{2}。</div>' -f [int]$Document.duration_estimate.estimated_duration_min_seconds,[int]$Document.duration_estimate.estimated_duration_max_seconds,(Encode-P0V2Html $Document.duration_estimate.derivation_method) }
    default { '<div class="banner">口播时长暂不估算：{0}</div>' -f (Encode-P0V2Html $Document.duration_estimate.not_available_reason) }
  }
  $auditCodes = [string]::Join(', ', @($Document.production_status.warning_codes))
  $auditMeta = '<p><strong>Revision：</strong>{0} · <strong>Session：</strong>{1} · <strong>Render input：</strong>{2}</p><p><strong>内部提醒代码：</strong>{3}</p>' -f (Encode-P0V2Html $Document.delivery_revision.delivery_revision_id),(Encode-P0V2Html $Document.session_id),(Encode-P0V2Html $Document.render_input_id),(Encode-P0V2Html $auditCodes)
  $replacements = [ordered]@{
    title = Encode-P0V2Html $Document.topic.title
    readiness_banner = $readinessBanner
    provenance_banner = $provenanceBanner
    topic_summary = $topicSummary
    duration_summary = $durationSummary
    script_text = Encode-P0V2Html $Document.script_card.final_text
    platform_units = ConvertTo-P0V3PlatformUnitsHtml $Document $Session $htmlBase
    pip_cards = ConvertTo-P0V3PipCardsHtml $Document $Session $htmlBase
    warning_items = ConvertTo-P0V3WarningsHtml $Document
    action_cards = ConvertTo-P0V3ActionsHtml $Document
    audit_meta = $auditMeta
    trace_links = ConvertTo-P0V3TraceHtml $Document $Session $htmlBase
  }
  foreach ($key in $replacements.Keys) { $template = $template.Replace('{{' + $key + '}}', [string]$replacements[$key]) }
  $scriptText = @"
# Final Script

```yaml
delivery_revision_id: $($Document.delivery_revision.delivery_revision_id)
draft_id: $($Document.script_card.source_draft_id)
duration_estimate_status: $($Document.duration_estimate.duration_estimate_status)
status: $($Document.script_card.status)
```

$($Document.script_card.final_text)
"@
  $visualRows = @($Document.pip_cards | Sort-Object display_order | ForEach-Object { "| $($_.display_order) | $($_.asset_id) | $($_.insert_after_text) | $($_.insert_before_text) | $($_.narrative_function) | $($_.relative_path) |" })
  $visualText = @"
# Final Visual Plan

> delivery_revision_id: $($Document.delivery_revision.delivery_revision_id)

| 顺序 | 图片资产 | 插在这句之后 | 进入这句之前 | 作用 | 文件 |
|---:|---|---|---|---|---|
$([string]::Join("`n", $visualRows))
"@
  $platformRows = @($Document.platform_delivery_units | Sort-Object display_order | ForEach-Object { "| $($_.platform_label) | $($_.cover_title) | $($_.video_title) | $($_.publish_description) | $([string]::Join(' ', @($_.hashtags))) | $($_.cover_asset_path) |" })
  $platformText = @"
# Final Platform Package

> delivery_revision_id: $($Document.delivery_revision.delivery_revision_id)

| 平台 | 封面标题 | 视频标题 | 发布描述 | 标签 | 封面成品 |
|---|---|---|---|---|---|
$([string]::Join("`n", $platformRows))
"@
  $recordText = @"
# Content Delivery Record

```yaml
delivery_revision_id: $($Document.delivery_revision.delivery_revision_id)
delivery_id: $($Document.final_delivery_id)
session_id: $($Document.session_id)
draft_id: $(Get-P0V3SourceId $Document 'draft')
visual_need_analysis_id: $(Get-P0V3SourceId $Document 'visual_need_analysis')
quality_review_id: $(Get-P0V3SourceId $Document 'quality_review')
platform_package_id: $(Get-P0V3SourceId $Document 'platform_package')
cover_quality_gate_id: $(Get-P0V3SourceId $Document 'cover_quality_review')
image_asset_set_id: $(Get-P0V3SourceId $Document 'image_asset_set')
delivery_readiness: $($Document.production_status.delivery_readiness)
revision_status: current
publish_status: publish_not_started
artifact_path: deliverables/content-delivery-record.md
next_skill: human_final_review
```

本记录与同 revision 的 HTML、最终文案、视觉方案和平台包共同构成发布前交付；不表示已经登录平台或发布。
"@
  return [pscustomobject]@{
    TemplatePath = $templatePath
    Html = $template.TrimEnd("`r", "`n") + "`n"
    FinalScript = $scriptText.Trim() + "`n"
    FinalVisualPlan = $visualText.Trim() + "`n"
    FinalPlatformPackage = $platformText.Trim() + "`n"
    ContentDeliveryRecord = $recordText.Trim() + "`n"
  }
}

function Test-P0V3RenderedHtml {
  param([string]$Html, [string]$OutputPath, [string]$Session)
  $errors = [System.Collections.Generic.List[string]]::new()
  if ($Html -match '\{\{[^}]+\}\}') { $errors.Add('v03_unresolved_template_token') }
  if ($Html -match '(?is)<\s*script\b|\bon[a-z]+\s*=|javascript\s*:') { $errors.Add('v03_unsafe_html_output') }
  if ([regex]::Matches($Html, '<h1\b', 'IgnoreCase').Count -ne 1 -or [regex]::Matches($Html, '<main\b', 'IgnoreCase').Count -ne 1) { $errors.Add('v03_page_structure_invalid') }
  if ($Html -match 'H5 不登录平台|图片状态必须诚实展示|cover_design_package_id</span>|无待外部生成封面|在「[^」]+」附近') { $errors.Add('v03_stale_or_internal_user_copy_visible') }
  foreach ($validationError in (Get-P0V2BrokenReferences $Html $OutputPath $Session)) { $errors.Add($validationError) }
  return [object[]]$errors.ToArray()
}

function Test-P0V3RenderReceipt {
  param([object]$Receipt)
  $errors = [System.Collections.Generic.List[string]]::new()
  $fields = @('schema_id','schema_version','receipt_id','delivery_revision_id','render_input_sha256','renderer_version','template_sha256','included_card_ids','included_asset_ids','warning_codes','output_view_sha256')
  foreach ($validationError in (Test-P0RequiredProperties $Receipt $fields 'render_receipt_v03')) { $errors.Add($validationError) }
  foreach ($validationError in (Test-P0AllowedProperties $Receipt $fields 'render_receipt_v03')) { $errors.Add($validationError) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Receipt.schema_id -ne 'taoge://schemas/p0/render-receipt/v0.3' -or $Receipt.schema_version -ne '0.3' -or $Receipt.renderer_version -ne 'final-delivery-renderer-v0.3') { $errors.Add('render_receipt_v03_version_invalid') }
  foreach ($field in @('render_input_sha256','template_sha256')) { if (-not (Test-P0Digest $Receipt.$field)) { $errors.Add("render_receipt_v03_digest_invalid:$field") } }
  foreach ($property in $Receipt.output_view_sha256.PSObject.Properties) { if (-not (Test-P0Digest $property.Value)) { $errors.Add("render_receipt_v03_output_digest_invalid:$($property.Name)") } }
  return [object[]]$errors.ToArray()
}

function Test-P0V3RevisionClosure {
  param([string]$Session, [object]$Document, [string]$DocumentDigest, [string]$ProjectRoot)
  $paths = $Document.delivery_revision.generated_view_paths
  $manifestPath = Join-Path $Session ([string]$paths.revision_manifest)
  $receiptPath = Join-Path $Session 'deliverables/p0/render-receipt.json'
  if (-not (Test-Path -LiteralPath $manifestPath) -or -not (Test-Path -LiteralPath $receiptPath)) { return $false }
  try {
    $manifest = Read-P0JsonFile $manifestPath
    $receipt = Read-P0JsonFile $receiptPath
    $templatePath = Join-Path $ProjectRoot 'templates/final-delivery/final-delivery.v0.3.template.html'
    if (@(Test-P0V3RenderReceipt $receipt).Count -ne 0 -or $manifest.revision_status -ne 'current' -or $manifest.delivery_revision_id -ne $Document.delivery_revision.delivery_revision_id -or $receipt.render_input_sha256 -ne $DocumentDigest -or $receipt.template_sha256 -ne (Get-P0V2Hash $templatePath)) { return $false }
    foreach ($artifact in @($manifest.output_artifacts)) {
      $path = Join-Path $Session ([string]$artifact.path)
      if (-not (Test-Path -LiteralPath $path) -or (Get-P0V2Hash $path) -ne [string]$artifact.sha256) { return $false }
    }
    return $true
  } catch { return $false }
}

function Write-P0V3DeliveryViews {
  param([object]$Document, [string]$Session, [string]$ProjectRoot, [string]$DocumentDigest)
  $views = New-P0V3ViewTexts $Document $Session $ProjectRoot
  $paths = $Document.delivery_revision.generated_view_paths
  $writeMap = [ordered]@{
    final_script = [pscustomobject]@{ Path=[string]$paths.final_script; Text=$views.FinalScript }
    final_visual_plan = [pscustomobject]@{ Path=[string]$paths.final_visual_plan; Text=$views.FinalVisualPlan }
    final_platform_package = [pscustomobject]@{ Path=[string]$paths.final_platform_package; Text=$views.FinalPlatformPackage }
    content_delivery_record = [pscustomobject]@{ Path=[string]$paths.content_delivery_record; Text=$views.ContentDeliveryRecord }
    final_html = [pscustomobject]@{ Path=[string]$paths.final_html; Text=$views.Html }
  }
  foreach ($entry in $writeMap.GetEnumerator()) {
    $full = Join-Path $Session ([string]$entry.Value.Path)
    Write-P0V2AtomicText $full ([string]$entry.Value.Text)
  }
  $htmlPath = Join-Path $Session ([string]$paths.final_html)
  $htmlErrors = @(Test-P0V3RenderedHtml (Get-Content -LiteralPath $htmlPath -Raw -Encoding UTF8) $htmlPath $Session)
  if ($htmlErrors.Count) { throw ('v03_rendered_html_invalid:' + [string]::Join(';', $htmlErrors)) }
  $outputArtifacts = [System.Collections.Generic.List[object]]::new()
  $digestObject = [ordered]@{}
  foreach ($entry in $writeMap.GetEnumerator()) {
    $full = Join-Path $Session ([string]$entry.Value.Path)
    $digest = Get-P0V2Hash $full
    $digestObject[$entry.Key] = $digest
    $outputArtifacts.Add([ordered]@{ artifact_type=$entry.Key; path=[string]$entry.Value.Path; sha256=$digest })
  }
  $cardIds = @([string]$Document.script_card.card_id) + @($Document.cover_cards + $Document.pip_cards + $Document.platform_cards + $Document.trace_cards + $Document.action_cards | ForEach-Object { [string]$_.card_id })
  $assetIds = @($Document.cover_cards + $Document.pip_cards | ForEach-Object { [string]$_.asset_id } | Sort-Object -Unique)
  $receipt = [ordered]@{
    schema_id='taoge://schemas/p0/render-receipt/v0.3'; schema_version='0.3'; receipt_id=('RCP-' + [string]$Document.final_delivery_id)
    delivery_revision_id=[string]$Document.delivery_revision.delivery_revision_id; render_input_sha256=$DocumentDigest
    renderer_version='final-delivery-renderer-v0.3'; template_sha256=Get-P0V2Hash $views.TemplatePath
    included_card_ids=[object[]]@($cardIds | Sort-Object -Unique); included_asset_ids=[object[]]$assetIds
    warning_codes=[object[]]@($Document.production_status.warning_codes | Sort-Object -Unique); output_view_sha256=[pscustomobject]$digestObject
  }
  $receiptErrors = @(Test-P0V3RenderReceipt ([pscustomobject]$receipt))
  if ($receiptErrors.Count) { throw ('v03_receipt_invalid:' + [string]::Join(';', $receiptErrors)) }
  Write-P0V2AtomicText (Join-Path $Session 'deliverables/p0/render-receipt.json') (ConvertTo-P0V2JsonText $receipt)
  $manifest = [ordered]@{
    schema_id='taoge://schemas/p0/delivery-revision/v0.3'; schema_version='0.3'
    delivery_revision_id=[string]$Document.delivery_revision.delivery_revision_id; session_id=[string]$Document.session_id
    revision_no=[int]$Document.delivery_revision.revision_no; revision_status='current'; semantic_gate_status='pass'
    render_input_id=[string]$Document.render_input_id; render_input_sha256=$DocumentDigest
    source_artifact_bindings=[object[]]$Document.delivery_revision.source_artifact_bindings
    output_artifacts=[object[]]$outputArtifacts.ToArray(); committed_at=[DateTimeOffset]::UtcNow.ToString('o')
  }
  Write-P0V2AtomicText (Join-Path $Session ([string]$paths.revision_manifest)) (ConvertTo-P0V2JsonText $manifest)
  return [pscustomobject]@{ HtmlSha256=[string]$digestObject.final_html; Receipt=$receipt; Manifest=$manifest }
}
