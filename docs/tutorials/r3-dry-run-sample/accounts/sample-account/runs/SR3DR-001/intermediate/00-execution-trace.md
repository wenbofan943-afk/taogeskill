# Execution Trace

```yaml
trace_id: TRACE-SR3DR-001
session_id: SR3DR-001
contract_set_version: r3-asset-runtime-v0.1
agent_assist_level: low
environment_capability:
  image_generation: unavailable_or_not_used
skill_defined:
  - draft -> static_visual_director_plan
  - static_visual_director_plan -> visual_plan
  - draft -> visual_plan
  - visual_plan -> image_prompt_set
  - image_task -> image_asset_type
  - image_task -> image_production_path
  - image_prompt_set -> image_generation_record
  - image_generation_record -> image_asset_set
  - platform_package -> cover-design-compiler
  - cover-design-compiler -> cover_design_package
  - cover-design-compiler -> cover_composition(prompt_only)
  - cover_composition -> copywriting-quality-review(cover_review)
  - cover_review -> cover_quality_gate
  - image_asset_set -> html_embed_manifest
  - html_embed_manifest -> final_delivery
agent_orchestrated:
  - create tutorial sample files
user_decision:
  - approve_r3_dry_run
external_api_called: false
api_key_used: false
```

## Trace Summary

本 dry-run 不生成真实图片，不调用外部图片 API。  
图片状态使用 `pending_external`，用于验证 R3 是否能诚实展示“待外部生成”，并保留完整提示词、插入位置和追溯记录。

## Trace Steps

| Step | Action | Expected Skill | Input Artifact | Output Artifact | Artifact Path | Next Skill | Execution Source | Gate | Check | Recovery | Result |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | build static visual director plan | talking-head-image-pip | intermediate/04-draft.md | static_visual_director_plan | intermediate/04-static-visual-director-plan.md | talking-head-image-pip | skill_defined | R3CHK-016 | pass | fix director plan | pass |
| 2 | build visual plan | talking-head-image-pip | intermediate/04-static-visual-director-plan.md | visual_plan | intermediate/05-visual-plan.md | talking-head-image-pip | skill_defined | R3CHK-001 | pass | fix visual budget | pass |
| 3 | build prompt set | talking-head-image-pip | intermediate/05-visual-plan.md | image_prompt_set | intermediate/05-visual-plan.md | talking-head-image-pip | skill_defined | R3CHK-005 | pass | fix prompt card | pass |
| 4 | decide image type | talking-head-image-pip | intermediate/05-visual-plan.md | image_asset_type | assets/images/image-assets.md | talking-head-image-pip | skill_defined | R3CHK-017 | pass | set image_asset_type | pass |
| 5 | decide production path | talking-head-image-pip | intermediate/05-visual-plan.md | image_production_path | assets/images/generation-records/GEN-SR3DR-001-001.md | talking-head-image-pip | skill_defined | R3CHK-018 | pass | set production path | pass |
| 6 | record generation attempt | talking-head-image-pip | intermediate/05-visual-plan.md | image_generation_record | assets/images/generation-records/GEN-SR3DR-001-001.md | talking-head-image-pip | skill_defined | R3CHK-006 | pass | add generation record | pass |
| 7 | materialize fallback asset set | talking-head-image-pip | assets/images/generation-records/GEN-SR3DR-001-001.md | image_asset_set | assets/images/image-assets.md | copywriting-quality-review | skill_defined | R3CHK-009 | pass | fix honest status | pass |
| 8 | review static visual quality | copywriting-quality-review | intermediate/05-visual-plan.md | quality_review | intermediate/06-quality-review.md | platform-packaging-adapter | skill_defined | R3CHK-021 | pass | fix quality gates | pass |
| 9 | build cover design package | cover-design-compiler | intermediate/08-platform-package-draft.md | cover_design_package | intermediate/08-cover-design-package.md | cover-design-compiler | skill_defined | R3CHK-026 | pass | add cover package | pass |
| 10 | compile prompt-only cover | cover-design-compiler | intermediate/08-cover-design-package.md | cover_composition | intermediate/09-cover-compositions.md | copywriting-quality-review | manual_fallback | R3CHK-027 | pass | deliver complete prompt-only package | pass |
| 11 | review cover fallback | copywriting-quality-review | intermediate/09-cover-compositions.md | cover_quality_gate | intermediate/09-cover-quality-review.md | final-delivery-builder | skill_defined | R3CHK-025 | pass | return cover-design-compiler | pass |
| 12 | build html embed manifest | final-delivery-builder | assets/images/image-assets.md | html_embed_manifest | deliverables/html-embed-manifest.md | final-delivery-builder | skill_defined | R3CHK-012 | pass | fix embed manifest | pass |
| 13 | build final delivery | final-delivery-builder | deliverables/html-embed-manifest.md | final_delivery | deliverables/final-delivery.html | human_final_review | skill_defined | R3CHK-028 | pass | rebuild final HTML | pass |
