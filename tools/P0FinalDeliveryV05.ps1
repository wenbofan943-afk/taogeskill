Set-StrictMode -Version 2.0

if (-not (Get-Command New-P0V4ViewTexts -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'P0FinalDeliveryV04.ps1')
}
if (-not (Get-Command ConvertTo-P0V04CompatibilityView -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'P0ContractV05.ps1')
}

function ConvertTo-P0V5StructureHtml {
  param([object]$Document)
  $items = [System.Collections.Generic.List[string]]::new()
  foreach ($stage in @($Document.content_structure_card.stages | Sort-Object order)) {
    $beats = [string]::Join(', ', @($stage.beat_ids | ForEach-Object { Encode-P0V2Html $_ }))
    $items.Add(('<article class="card"><span class="badge">{0}</span><h3>{1}. {2}</h3><p>{3}</p><p>beats: {4}</p></article>' -f (Encode-P0V2Html $stage.implementation_status), [int]$stage.order, (Encode-P0V2Html $stage.stage_id), (Encode-P0V2Html $stage.purpose), $beats))
  }
  return ('<div class="banner"><strong>{0}</strong><p>{1} -&gt; {2}</p><p>{3}</p></div><div class="grid">{4}</div>' -f (Encode-P0V2Html $Document.content_structure_card.selected_strategy_ref), (Encode-P0V2Html $Document.content_structure_card.audience_entry_state), (Encode-P0V2Html $Document.content_structure_card.audience_exit_state), (Encode-P0V2Html $Document.content_structure_card.core_promise), [string]::Join("`n", $items))
}

function ConvertTo-P0V5ReviewHtml {
  param([object]$Document)
  $items = [System.Collections.Generic.List[string]]::new()
  foreach ($issue in @($Document.script_review_card.issue_items)) {
    $items.Add(('<article class="card"><span class="badge">{0}</span><h3>{1}</h3><p>{2}</p><p>{3}</p><p>{4}</p></article>' -f (Encode-P0V2Html $issue.gate), (Encode-P0V2Html $issue.source_excerpt), (Encode-P0V2Html $issue.viewer_impact), (Encode-P0V2Html $issue.recommended_action), (Encode-P0V2Html $issue.resolution_status)))
  }
  if ($items.Count -eq 0) { $items.Add('<article class="card"><span class="badge ok">pass</span></article>') }
  return ('<div class="banner"><strong>script: {0}</strong> · alignment: {1}</div><div class="grid">{2}</div>' -f (Encode-P0V2Html $Document.script_review_card.script_readiness), (Encode-P0V2Html $Document.script_review_card.alignment_status), [string]::Join("`n", $items))
}

function ConvertTo-P0V5CoverageSummaryHtml {
  param([object]$Document)
  $counts = $Document.visual_coverage_summary.counts
  return ('<div class="banner"><strong>{0}</strong> · delivery: {1}<p>assets {2}/{3} · Image 2 tasks/attempts {4}/{5} · capture tasks/attempts {6}/{7} · occurrences {8}</p></div>' -f (Encode-P0V2Html $Document.visual_coverage_summary.coverage_completeness_status), (Encode-P0V2Html $Document.visual_coverage_summary.visual_delivery_readiness), [int]$counts.materialized_visual_asset_count, [int]$counts.derived_visual_asset_count, [int]$counts.provider_generation_task_count, [int]$counts.provider_generation_attempt_count, [int]$counts.source_capture_task_count, [int]$counts.source_capture_attempt_count, [int]$counts.visual_insert_occurrence_count)
}

function ConvertTo-P0V5BeatCardsHtml {
  param([object]$Document)
  $items = [System.Collections.Generic.List[string]]::new()
  foreach ($beat in @($Document.content_beat_cards | Sort-Object display_order)) {
    $tasks = [string]::Join(', ', @($beat.visual_task_ids | ForEach-Object { Encode-P0V2Html $_ }))
    $items.Add(('<article class="card" id="{0}"><span class="badge">{1}</span><span class="badge">{2}</span><h3>{3}. {4}</h3><blockquote>{5}</blockquote><p>{6}</p><p>tasks: {7}</p></article>' -f (Encode-P0V2Html $beat.card_id), (Encode-P0V2Html $beat.status), (Encode-P0V2Html $beat.visual_disposition), [int]$beat.display_order, (Encode-P0V2Html $beat.semantic_function), (Encode-P0V2Html $beat.source_excerpt), (Encode-P0V2Html $beat.visual_reason), $tasks))
  }
  return [string]::Join("`n", $items)
}

function New-P0V5ViewTexts {
  param([object]$Document,[string]$Session,[string]$ProjectRoot)
  $templatePath = Join-Path $ProjectRoot 'templates/final-delivery/final-delivery.v0.5.template.html'
  if (-not (Test-Path -LiteralPath $templatePath)) { throw 'final_delivery_v05_template_missing' }
  $template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
  $htmlPath = Join-Path $Session ([string]$Document.delivery_revision.generated_view_paths.final_html)
  $htmlBase = Split-Path -Parent $htmlPath
  $scope = [string]$Document.production_status.platform_delivery_scope_status
  $readinessClass = switch ($scope) { 'ready_all_target_platforms' {'ok'} 'primary_ready_secondary_pending' {'warn'} default {'bad'} }
  $readinessBanner = '<div class="banner {0}"><strong>{1}</strong></div>' -f $readinessClass, (Encode-P0V2Html (Get-P0V4ScopeLabel $scope))
  $provenanceBanner = '<div class="banner"><strong>provenance:</strong> {0}</div>' -f (Encode-P0V2Html $Document.run_provenance.user_summary)
  $topicSummary = '<article class="card"><strong>{0}</strong><p>{1}</p></article>' -f (Encode-P0V2Html $Document.topic.title), (Encode-P0V2Html $Document.topic.why_now)
  $durationSummary = switch ([string]$Document.duration_estimate.duration_estimate_status) { 'measured' {'<div class="banner">{0} seconds</div>' -f [int]$Document.duration_estimate.measured_duration_seconds} 'derived_range' {'<div class="banner">{0}-{1} seconds; {2}</div>' -f [int]$Document.duration_estimate.estimated_duration_min_seconds, [int]$Document.duration_estimate.estimated_duration_max_seconds, (Encode-P0V2Html $Document.duration_estimate.derivation_method)} default {'<div class="banner">duration: {0}</div>' -f (Encode-P0V2Html $Document.duration_estimate.not_available_reason)} }
  $auditCodes = [string]::Join(', ', @($Document.production_status.warning_codes))
  $auditMeta = '<p>Revision: {0} · Session: {1} · Render input: {2}</p><p>scope: {3} · warnings: {4}</p>' -f (Encode-P0V2Html $Document.delivery_revision.delivery_revision_id), (Encode-P0V2Html $Document.session_id), (Encode-P0V2Html $Document.render_input_id), (Encode-P0V2Html $scope), (Encode-P0V2Html $auditCodes)
  $replacements = [ordered]@{title=Encode-P0V2Html $Document.topic.title;readiness_banner=$readinessBanner;provenance_banner=$provenanceBanner;topic_summary=$topicSummary;duration_summary=$durationSummary;content_structure_card=ConvertTo-P0V5StructureHtml $Document;script_review_card=ConvertTo-P0V5ReviewHtml $Document;visual_coverage_summary=ConvertTo-P0V5CoverageSummaryHtml $Document;content_beat_cards=ConvertTo-P0V5BeatCardsHtml $Document;script_text=Encode-P0V2Html $Document.script_card.final_text;platform_units=ConvertTo-P0V4PlatformUnitsHtml $Document $Session $htmlBase;visual_insert_cards=ConvertTo-P0V4VisualInsertCardsHtml $Document $Session $htmlBase;warning_items=ConvertTo-P0V3WarningsHtml $Document;action_cards=ConvertTo-P0V3ActionsHtml $Document;audit_meta=$auditMeta;trace_links=ConvertTo-P0V3TraceHtml $Document $Session $htmlBase}
  foreach ($key in $replacements.Keys) { $template = $template.Replace('{{' + $key + '}}', [string]$replacements[$key]) }

  $v04 = New-P0V4ViewTexts (ConvertTo-P0V04CompatibilityView $Document) $Session $ProjectRoot
  $visualRows = @($Document.content_beat_cards | Sort-Object display_order | ForEach-Object { "| $($_.display_order) | $($_.beat_id) | $($_.stage_id) | $($_.visual_disposition) | $($_.visual_reason) | $([string]::Join(', ', @($_.visual_task_ids))) |" })
  $visualText = "# Final Visual Plan`n`n> delivery_revision_id: $($Document.delivery_revision.delivery_revision_id)`n`n| order | beat | stage | disposition | reason | tasks |`n|---:|---|---|---|---|---|`n$([string]::Join("`n", $visualRows))`n"
  $recordText = $v04.ContentDeliveryRecord + "`nstructure_plan_id: $($Document.content_structure_card.structure_plan_id)`nscript_design_review_id: $($Document.script_review_card.script_design_review_id)`nvisual_coverage_ledger_id: $($Document.visual_coverage_summary.visual_coverage_ledger_id)`nalignment_review_id: $($Document.script_review_card.alignment_review_id)`n"
  return [pscustomobject]@{TemplatePath=$templatePath;Html=$template.TrimEnd("`r","`n")+"`n";FinalScript=$v04.FinalScript;FinalVisualPlan=$visualText;FinalPlatformPackage=$v04.FinalPlatformPackage;ContentDeliveryRecord=$recordText}
}

function Test-P0V5RenderedHtml {
  param([string]$Html,[string]$OutputPath,[string]$Session)
  $errors = [System.Collections.Generic.List[string]]::new()
  if ($Html -match '\{\{[^}]+\}\}') { $errors.Add('v05_unresolved_template_token') }
  if ($Html -match '(?is)<\s*script\b|\bon[a-z]+\s*=|javascript\s*:') { $errors.Add('v05_unsafe_html_output') }
  if ([regex]::Matches($Html,'<h1\b','IgnoreCase').Count -ne 1 -or [regex]::Matches($Html,'<main\b','IgnoreCase').Count -ne 1) { $errors.Add('v05_page_structure_invalid') }
  foreach ($token in @('data-template-version="0.5.0"','id="content-structure"','id="script-review"','id="visual-coverage"')) { if ($Html -notmatch [regex]::Escape($token)) { $errors.Add("v05_business_section_missing:$token") } }
  foreach ($error in (Get-P0V2BrokenReferences $Html $OutputPath $Session)) { $errors.Add($error) }
  return [object[]]$errors.ToArray()
}

function Test-P0V5RenderReceipt {
  param([object]$Receipt)
  $errors = [System.Collections.Generic.List[string]]::new()
  $fields = @('schema_id','schema_version','receipt_id','delivery_revision_id','render_input_sha256','renderer_version','template_sha256','included_card_ids','included_asset_ids','warning_codes','output_view_sha256')
  foreach ($error in (Test-P0RequiredProperties $Receipt $fields 'render_receipt_v05')) { $errors.Add($error) }
  foreach ($error in (Test-P0AllowedProperties $Receipt $fields 'render_receipt_v05')) { $errors.Add($error) }
  if ($errors.Count) { return [object[]]$errors.ToArray() }
  if ($Receipt.schema_id -ne 'taoge://schemas/p0/render-receipt/v0.5' -or $Receipt.schema_version -ne '0.5' -or $Receipt.renderer_version -ne 'final-delivery-renderer-v0.5') { $errors.Add('render_receipt_v05_version_invalid') }
  foreach ($field in @('render_input_sha256','template_sha256')) { if (-not (Test-P0Digest $Receipt.$field)) { $errors.Add("render_receipt_v05_digest_invalid:$field") } }
  foreach ($property in $Receipt.output_view_sha256.PSObject.Properties) { if (-not (Test-P0Digest $property.Value)) { $errors.Add("render_receipt_v05_output_digest_invalid:$($property.Name)") } }
  return [object[]]$errors.ToArray()
}

function Test-P0V5RevisionClosure {
  param([string]$Session,[object]$Document,[string]$DocumentDigest,[string]$ProjectRoot)
  $manifestPath = Join-Path $Session ([string]$Document.delivery_revision.generated_view_paths.revision_manifest)
  $receiptPath = Join-Path $Session 'deliverables/p0/render-receipt.json'
  if (-not (Test-Path $manifestPath) -or -not (Test-Path $receiptPath)) { return $false }
  try {
    $manifest = Read-P0JsonFile $manifestPath; $receipt = Read-P0JsonFile $receiptPath
    $templatePath = Join-Path $ProjectRoot 'templates/final-delivery/final-delivery.v0.5.template.html'
    if (@(Test-P0V5RenderReceipt $receipt).Count -ne 0 -or $manifest.revision_status -ne 'current' -or $manifest.delivery_revision_id -ne $Document.delivery_revision.delivery_revision_id -or $receipt.render_input_sha256 -ne $DocumentDigest -or $receipt.template_sha256 -ne (Get-P0V2Hash $templatePath)) { return $false }
    foreach ($artifact in @($manifest.output_artifacts)) { $path = Join-Path $Session ([string]$artifact.path); if (-not (Test-Path $path) -or (Get-P0V2Hash $path) -ne [string]$artifact.sha256) { return $false } }
    return $true
  } catch { return $false }
}

function Write-P0V5DeliveryViews {
  param([object]$Document,[string]$Session,[string]$ProjectRoot,[string]$DocumentDigest)
  $views = New-P0V5ViewTexts $Document $Session $ProjectRoot; $paths = $Document.delivery_revision.generated_view_paths
  $writeMap = [ordered]@{final_script=[pscustomobject]@{Path=[string]$paths.final_script;Text=$views.FinalScript};final_visual_plan=[pscustomobject]@{Path=[string]$paths.final_visual_plan;Text=$views.FinalVisualPlan};final_platform_package=[pscustomobject]@{Path=[string]$paths.final_platform_package;Text=$views.FinalPlatformPackage};content_delivery_record=[pscustomobject]@{Path=[string]$paths.content_delivery_record;Text=$views.ContentDeliveryRecord};final_html=[pscustomobject]@{Path=[string]$paths.final_html;Text=$views.Html}}
  foreach ($entry in $writeMap.GetEnumerator()) { Write-P0V2AtomicText (Join-Path $Session ([string]$entry.Value.Path)) ([string]$entry.Value.Text) }
  $htmlPath = Join-Path $Session ([string]$paths.final_html); $htmlErrors = @(Test-P0V5RenderedHtml (Get-Content $htmlPath -Raw -Encoding UTF8) $htmlPath $Session); if ($htmlErrors.Count) { throw ('v05_rendered_html_invalid:' + ($htmlErrors -join ';')) }
  $outputArtifacts = [System.Collections.Generic.List[object]]::new(); $digestObject = [ordered]@{}
  foreach ($entry in $writeMap.GetEnumerator()) { $full = Join-Path $Session ([string]$entry.Value.Path); $digest = Get-P0V2Hash $full; $digestObject[$entry.Key] = $digest; $outputArtifacts.Add([ordered]@{artifact_type=$entry.Key;path=[string]$entry.Value.Path;sha256=$digest}) }
  $cardIds = @([string]$Document.script_card.card_id,[string]$Document.content_structure_card.card_id,[string]$Document.script_review_card.card_id,[string]$Document.visual_coverage_summary.card_id) + @($Document.content_beat_cards + $Document.cover_cards + $Document.visual_insert_cards + $Document.platform_cards + $Document.trace_cards + $Document.action_cards | ForEach-Object { [string]$_.card_id })
  $assetIds = @($Document.cover_cards + $Document.visual_insert_cards | ForEach-Object { [string]$_.asset_id } | Sort-Object -Unique)
  $receipt = [ordered]@{schema_id='taoge://schemas/p0/render-receipt/v0.5';schema_version='0.5';receipt_id=('RCP-'+[string]$Document.final_delivery_id);delivery_revision_id=[string]$Document.delivery_revision.delivery_revision_id;render_input_sha256=$DocumentDigest;renderer_version='final-delivery-renderer-v0.5';template_sha256=Get-P0V2Hash $views.TemplatePath;included_card_ids=[object[]]@($cardIds|Sort-Object -Unique);included_asset_ids=[object[]]$assetIds;warning_codes=[object[]]@($Document.production_status.warning_codes|Sort-Object -Unique);output_view_sha256=[pscustomobject]$digestObject}
  $receiptErrors = @(Test-P0V5RenderReceipt ([pscustomobject]$receipt)); if ($receiptErrors.Count) { throw ('v05_receipt_invalid:' + ($receiptErrors -join ';')) }
  Write-P0V2AtomicText (Join-Path $Session 'deliverables/p0/render-receipt.json') (ConvertTo-P0V2JsonText $receipt)
  $manifest = [ordered]@{schema_id='taoge://schemas/p0/delivery-revision/v0.5';schema_version='0.5';delivery_revision_id=[string]$Document.delivery_revision.delivery_revision_id;session_id=[string]$Document.session_id;revision_no=[int]$Document.delivery_revision.revision_no;revision_status='current';semantic_gate_status='pass';render_input_id=[string]$Document.render_input_id;render_input_sha256=$DocumentDigest;source_artifact_bindings=[object[]]$Document.delivery_revision.source_artifact_bindings;output_artifacts=[object[]]$outputArtifacts.ToArray();committed_at=[DateTimeOffset]::UtcNow.ToString('o')}
  Write-P0V2AtomicText (Join-Path $Session ([string]$paths.revision_manifest)) (ConvertTo-P0V2JsonText $manifest)
  return [pscustomobject]@{HtmlSha256=[string]$digestObject.final_html;Receipt=$receipt;Manifest=$manifest}
}
