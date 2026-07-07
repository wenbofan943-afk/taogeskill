# R3 Dry-run Sample

> 状态：dry_run_pass_pending_external_path  
> 主责：用最小假样本验证 R3 图片资产链是否能被另一个 AI 按合同理解和执行。  
> 边界：本样本不生成真实图片、不调用外部 API、不代表完整真实测试通过。

---

## 1. 样本目标

R3 dry-run 只验证一件事：

```text
一篇内容的一张 required 图片，能否从 visual_beat 走到 prompt_card、generation_record、image_asset_or_fallback、metadata_sidecar_if_generated 和 html_embed_manifest。
```

样本可以只验证 1 张 required 图；正式内容仍按 R3 视觉预算生成 required_visuals。

---

## 2. 目录结构

以下结构相对于本教程目录：

```text
accounts/sample-account/runs/SR3DR-001/
├── manifest.yaml
├── intermediate/
│   ├── 00-execution-trace.md
│   ├── 04-draft.md
│   ├── 05-visual-plan.md
│   ├── 06-quality-review.md
│   └── 07-r3-dry-run-check.md
├── assets/
│   └── images/
│       ├── image-assets.md
│       ├── generation-records/
│       │   └── GEN-SR3DR-001-001.md
│       └── metadata/
│           └── README.md
└── deliverables/
    ├── content-delivery-record.md
    ├── html-embed-manifest.md
    └── final-delivery.html
```

如果样本选择 pending / failed / manual 路径，可以没有图片文件和 sidecar，但必须有 generation record 或人工任务说明。

---

## 3. 必填字段

`manifest.yaml` 必须包含：

```yaml
contract_set_version: r3-asset-runtime-v0.1
sample_run_type: r3_minimum_asset_chain
legacy_session: false
image_asset_set:
  image_asset_set_id:
  image_assets_status:
  generation_records_dir:
  metadata_dir:
  html_embed_manifest_status:
r3_sample_gate:
  sample_scope: one_content_minimum_asset_chain
  r3_sample_gate_status: pass / fail
trace_check:
  r3_check_ids:
    - R3CHK-001
    - R3CHK-002
```

`image-assets.md` 必须包含：

```text
image_asset_set_id
visual_plan_id
required_count
generated_count
pending_count
failed_count
rejected_count
image_assets_status
assets[]
```

单张 asset 必须包含：

```text
image_asset_id
image_task_id
beat_id
source_prompt_id
generation_run_id
image_status
insert_after_text
insert_before_text
prompt_used_full_path
asset_path 或 fallback 说明
metadata_sidecar_path（仅 generated 必填）
```

---

## 4. Dry-run 检查

最小检查项：

| ID | 检查 | 失败处理 |
|---|---|---|
| R3DR-001 | visual_budget 存在 | 回 `talking-head-image-pip` |
| R3DR-002 | required 图有 retention_task | 回 `talking-head-image-pip` |
| R3DR-003 | prompt_card 完整 | 回 `talking-head-image-pip` |
| R3DR-004 | generation_record 存在 | 回 `talking-head-image-pip` |
| R3DR-005 | image_status 诚实 | 回 `talking-head-image-pip` |
| R3DR-006 | generated 图有 sidecar | 阻断或降级 |
| R3DR-007 | pending / failed / manual 不被当成 generated | 修 HTML |
| R3DR-008 | html_embed_manifest 能决定展示方式 | 回 `final-delivery-builder` |
| R3DR-009 | execution_trace 记录来源 | 回写 trace |
| R3DR-010 | 没有外部 API / API key | 立即阻断 |

---

## 5. 通过口径

```text
R3 dry-run pass 只说明图片资产链最小合同可读、可接、可追溯。
它不说明真实图片质量通过。
它不说明 R1-R4 完整真实测试通过。
它不说明可以开源发布。
```

---

## 6. 本轮验证结果

```yaml
dry_run_id: R3DRY-SR3DR-001
verified_at: 2026-07-07
sample_path: accounts/sample-account/runs/SR3DR-001/
sample_status: pass
image_path_mode: pending_external
generated_path_verified: false
html_link_check: pass
missing_required_file_count: 0
r3dr_fail_count: 0
html_broken_link_count: 0
```

本轮验证通过的是 `pending_external` 路径：

```text
visual_plan
-> image_prompt_set
-> image_generation_record
-> image_asset_set(pending_external)
-> html_embed_manifest(placeholder)
-> final-delivery.html
```

未验证：

```text
真实 image 生成。
generated 图片文件存在性。
metadata sidecar 写入。
真实图片质量。
完整真实内容生产。
R1-R4 全链路开源前验收。
```
