param(
  [string]$TemplatePath = "templates/final-delivery/final-delivery.template.html",
  [string]$V03TemplatePath = "templates/final-delivery/final-delivery.v0.3.template.html"
)

$ErrorActionPreference = "Stop"

try {
  if (-not (Test-Path -LiteralPath $TemplatePath)) {
    Write-Output "FDR-001 fail template_missing $TemplatePath"
    exit 1
  }

  $template = Get-Content -LiteralPath $TemplatePath -Raw -Encoding UTF8
  $checks = @(
    @{ id = "FDR-002"; label = "section_delivery_meta"; needles = @("SECTION: delivery_meta", "SECTION: topic_rationale", "SECTION: final_script", "SECTION: cover_design", "SECTION: picture_in_picture", "SECTION: platform_package", "SECTION: trace_links", "SECTION: human_final_review") },
    @{ id = "FDR-003"; label = "required_fields"; needles = @("html_builder_mode", "html_template_source", "final_delivery_status", "image_assets_status", "source_research_run_id", "cover_design_package_id", "image_asset_type", "image_production_path", "cover_asset_role", "cover_text_render_strategy", "platform_cover_strategy", "cover_composition_status", "cover_embeds") },
    @{ id = "FDR-004"; label = "human_review_menu"; needles = @("认可", "局部返工", "导出转交包", "记录人工发布结果", "归档今天不发") },
    @{ id = "FDR-005"; label = "honest_image_states"; needles = @("generated", "pending_external", "generation_failed", "manual_required") },
    @{ id = "FDR-006"; label = "copy_download"; needles = @("textarea", "可复制", "下载") },
    @{ id = "FDR-007"; label = "publish_boundary"; needles = @("不自动发布", "不登录平台", "不自动评论") },
    @{ id = "FDR-008"; label = "cover_composition_delivery"; needles = @("cover_ready_assets", "cover_background_assets", "cover_prompt_only_assets", "upload_ready_cover_count", "prompt_only_cover_count", "composition_ready", "cover_quality_summary", "可上传封面成品", "重做封面", "再加一个封面") },
    @{ id = "FDR-009"; label = "visual_text_delivery"; needles = @("visual_text_plan_id", "visual_text_quality_gate_status", "visual_text_delivery_summary", "visual_text_decision", "visual_text_role", "visual_text_render_strategy", "information_delta", "source_binding_status", "evidence_source_path", "本图按计划无字") },
    @{ id = "FDR-010"; label = "typed_delivery_first"; needles = @("delivery_readiness", "delivery_warning_codes", "human_actions", "audit-details", "展开运行证据", "展开追溯与运行证据") }
  )

  $failed = New-Object System.Collections.Generic.List[string]
  foreach ($check in $checks) {
    $missing = @($check.needles | Where-Object { -not $template.Contains($_) })
    if ($missing.Count -gt 0) {
      $failed.Add(("{0} fail {1} missing: {2}" -f $check.id, $check.label, ([string]::Join(", ", $missing))))
    } else {
      Write-Output ("{0} pass {1}" -f $check.id, $check.label)
    }
  }

  if ($template -match '(?is)<\s*script\b|\bon[a-z]+\s*=|javascript\s*:') {
    $failed.Add("FDR-011 fail no_script_or_inline_handlers unsafe executable HTML detected")
  } else {
    Write-Output "FDR-011 pass no_script_or_inline_handlers"
  }

  if ([regex]::Matches($template, '<h1\b', 'IgnoreCase').Count -ne 1 -or [regex]::Matches($template, '<main\b', 'IgnoreCase').Count -ne 1) {
    $failed.Add("FDR-012 fail semantic_page_structure expected exactly one h1 and one main")
  } else {
    Write-Output "FDR-012 pass semantic_page_structure"
  }

  if (-not (Test-Path -LiteralPath $V03TemplatePath)) {
    $failed.Add("FDR-013 fail v03_template_missing $V03TemplatePath")
  } else {
    $v03 = Get-Content -LiteralPath $V03TemplatePath -Raw -Encoding UTF8
    $v03Needles = @('{{readiness_banner}}','{{provenance_banner}}','{{duration_summary}}','{{platform_units}}','{{pip_cards}}','{{warning_items}}','{{action_cards}}','{{audit_meta}}','{{trace_links}}','delivery-list','选中文本后复制','不会登录平台或自动发布')
    $v03Missing = @($v03Needles | Where-Object { -not $v03.Contains($_) })
    if ($v03Missing.Count -or $v03 -match '(?is)<\s*script\b|\bon[a-z]+\s*=|javascript\s*:' -or [regex]::Matches($v03,'<h1\b','IgnoreCase').Count-ne1 -or [regex]::Matches($v03,'<main\b','IgnoreCase').Count-ne1) {
      $failed.Add("FDR-013 fail v03_workbench_contract missing=$([string]::Join(',', $v03Missing))")
    } else {
      Write-Output "FDR-013 pass v03_workbench_contract"
    }
  }

  if ($failed.Count -gt 0) {
    $failed | ForEach-Object { Write-Output $_ }
    exit 1
  }

  Write-Output "FINAL_DELIVERY_TEMPLATE_CHECK=pass"
  exit 0
} catch {
  Write-Error ("{0} at line {1}: {2}" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line)
  exit 3
}
