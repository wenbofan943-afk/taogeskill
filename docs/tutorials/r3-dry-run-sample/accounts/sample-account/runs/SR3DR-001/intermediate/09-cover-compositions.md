# Cover Compositions

```yaml
cover_composition_id: CC-SR3DR-001
cover_design_package_id: CDP-SR3DR-001
cover_variant_id: COVER-SR3DR-001-001
package_id: PKG-SR3DR-001
source_research_run_id: R-SR3DR-001
platform: sample_platform
platform_cover_strategy: prompt_only
source_background_asset_id: COVER-SR3DR-001-001
cover_title: 画中画不是装饰
text_lines:
  - 画中画
  - 不是装饰
cover_text_render_strategy: prompt_only
output_asset_id:
output_path:
cover_composition_status: prompt_only
quality_gate_status: pass
artifact_path: intermediate/09-cover-compositions.md
next_skill: copywriting-quality-review
```

```yaml
layout_spec:
  canvas_size: 1080x1440
  aspect_ratio: 3:4
  text_box: 上方 20% 安全区，左对齐两行粗体
  subject_safe_area: 右侧任务卡主体不得被文字遮挡
  platform_ui_safe_area: 四周保留 8% 安全边距
complete_prompt: >
  竖版短视频封面底图，右侧是一张清晰的任务化视觉规划卡，左侧是几张杂乱、弱化、失焦的普通配图，形成“有任务的画面”和“装饰素材”的强烈对比。现代编辑台风格，真实纸张与屏幕质感，青绿色和警示橙作辅助色，主体清楚，画面上方预留干净标题区，不生成任何文字，不出现品牌、手机号、微信号或真实个人信息。3:4 竖版。
negative_prompt: 错别字、水印、联系方式、平台 logo、真实账号、车牌、密集小字、PPT 截图感
human_action_required: 将完整 prompt 粘贴到支持的图片模型生成底图，再按 layout_spec 叠加准确中文标题并回填新 image_asset_id。
```
