param(
  [string]$TemplatePath = "templates/final-delivery/final-delivery.template.html"
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
    @{ id = "FDR-009"; label = "visual_text_delivery"; needles = @("visual_text_plan_id", "visual_text_quality_gate_status", "visual_text_delivery_summary", "visual_text_decision", "visual_text_role", "visual_text_render_strategy", "information_delta", "source_binding_status", "evidence_source_path", "本图按计划无字") }
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
