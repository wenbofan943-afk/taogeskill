# Cover Design Package

```yaml
cover_design_package_id: CDP-SR3DR-001
package_id: PKG-SR3DR-001
visual_plan_id: VP-SR3DR-001
image_asset_set_id: IMGSET-SR3DR-001
source_research_run_id: R-SR3DR-001
account: sample-account
target_platforms:
  - sample_platform
recommended_cover_title: 画中画不是装饰
cover_image_source: prompt_only
cover_background_asset_id: COVER-SR3DR-001-001
cover_visual_concept: 右侧任务化规划卡与左侧杂乱配图形成强弱对比
cover_job: viewpoint_signal
cover_text_render_strategy: prompt_only
platform_cover_strategy: prompt_only
cover_layout: 右侧任务化规划卡作为视觉主体，左侧杂乱配图作弱对比，上方留 20% 字幕安全区
cover_safe_area: 标题放上方安全区，不压主体，不贴近平台 UI 边缘
cover_text_overlay: 画中画不是装饰
platform_cover_notes: dry-run 样本不区分真实平台，只验证封面标题、视频标题、封面图设计分离
cover_variant_set_id: CVS-SR3DR-001
cover_design_status: cover_design_pass
artifact_path: intermediate/08-cover-design-package.md
next_skill: copywriting-quality-review
```

## Cover Variant Set

```yaml
cover_variant_set_id: CVS-SR3DR-001
package_id: PKG-SR3DR-001
recommended_variant_id: COVER-SR3DR-001-001
variant_set_status: variant_set_ready
recommend_reason: 该封面一眼能解释“普通配图”和“留存任务图”的差别，适合 R3 dry-run 样本。
```

| variant_id | variant_role | cover_title | cover_image_source | expected_click_reason | risk_note |
|---|---|---|---|---|---|
| COVER-SR3DR-001-001 | conflict | 画中画不是装饰 | prompt_only | 有认知冲突，能让创作者意识到配图不是越多越好 | 样本不生成真实封面图，只交付 Seedream 入参 |
