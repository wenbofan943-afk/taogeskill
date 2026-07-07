# Workflow Check Report

```yaml
workflow_check_report:
  check_id: CHECK-sample-SR3GEN-001-001
  checked_at: 2026-07-07
  check_scope: sample
  target_path: docs/tutorials/r3-generated-image-sample/accounts/sample-account/runs/SR3GEN-001
  checker_version: r1-r4-readonly-checker-v0.1
  readonly: true
  overall_result: pass
  maturity_observed: l3_candidate_path_evidence
  blocking_count: 0
  warning_count: 0
  info_count: 4
  next_action: update_project_status_then_consider_r4_public_release_candidate_or_session_scope_checker
```

## Summary

```text
检查范围：sample-scope，只检查 R3 generated 图片路径样本。
目标路径：docs/tutorials/r3-generated-image-sample/accounts/sample-account/runs/SR3GEN-001
结论：pass。
成熟度观察：R3 generated 路径已有 L3 candidate 证据，但不代表完整项目 L3。
边界说明：本次不检查真实账号 session，不生成 public_release，不接 CI。
```

## Checks

| check_item_id | group | severity | status | evidence | recommendation | backwrite_target |
|---|---|---|---|---|---|---|
| CHECK-R3-001 | r3_assets | blocker | pass | `intermediate/05-visual-plan.md` 存在 visual_budget，final_required_count=1。 | 无需返修。 | 无 |
| CHECK-R3-002 | r3_assets | blocker | pass | required 图 `IMGTASK-SR3GEN-001-001` 有 `retention_task` 和插入位置。 | 无需返修。 | 无 |
| CHECK-R3-003 | r3_assets | blocker | pass | `PROMPT-SR3GEN-001-001` 保留完整 prompt_card，未缩水成关键词。 | 无需返修。 | 无 |
| CHECK-R3-004 | r3_assets | blocker | pass | `assets/images/IMG-SR3GEN-001-001.png` 存在且可读；checksum 匹配。 | 无需返修。 | 无 |
| CHECK-R3-005 | r3_assets | blocker | pass | `assets/images/metadata/IMG-SR3GEN-001-001.metadata.yaml` 存在，含 sha256、尺寸、prompt、record 路径。 | 无需返修。 | 无 |
| CHECK-R3-006 | r3_assets | blocker | pass | `image_status=generated`，HTML 直接展示图片；无 pending / failed / manual 伪装。 | 无需返修。 | 无 |
| CHECK-R3-007 | r3_assets | warn | pass | 本样本明确 `generated_path_verified: true`；不再用 pending_external 代替 generated。 | 无需返修。 | 无 |
| CHECK-R3-008 | r3_assets | warn | pass | `deliverables/final-delivery.html` 能展示图片、提供下载链接，并链接到 generation_record、metadata_sidecar、image_asset_set、visual_plan 和 quality_review。 | 无需返修。 | 无 |
| CHECK-HTML-001 | delivery | blocker | pass | final-delivery.html 本地链接 7 个，断链 0。 | 无需返修。 | 无 |

## Blocking Issues

```text
无。
```

## Warnings

```text
无。
```

## Info

```text
1. 图片来自 Codex 内置 imagegen 环境能力，不算 skill 自身出图能力。
2. 本样本只验证一张 generated 图，不代表完整真实内容测试。
3. 本样本不生成 public_release。
4. 本样本可作为后续 public sample 的 generated_image_path_verified=true 证据来源。
```

## Human Prompt

```text
R3 generated 图片路径样本已经通过：图片文件、sidecar、checksum、HTML 预览和下载都能闭合。它解决了之前“只验证 pending_external，没有验证真实 generated 图”的缺口。下一步可以把项目状态中的 R3 warning 降级，然后再决定是补 session-scope checker，还是进入 R4 public_release candidate 设计。
```
