# R3 Generated Image Sample

> 状态：generated_path_sample_pass  
> 主责：验证 R3 图片资产链中的 `generated` 路径：真实图片文件、generation record、metadata sidecar、checksum 和 HTML 展示是否能闭合。  
> 边界：本样本只验证一张脱敏样本图，不代表完整真实内容测试通过，不生成 public_release，不接外部 API，不自动发布。

---

## 1. 样本目标

本样本验证：

```text
visual_plan
-> image_prompt_set
-> image_generation_record
-> image_asset_set(generated)
-> metadata_sidecar
-> html_embed_manifest
-> final-delivery.html
```

和上一条 R3 pending_external dry-run 不同，本样本必须有真实图片文件，并能通过 checksum、sidecar 和 HTML 预览 / 下载路径追溯。

---

## 2. 样本路径

```text
accounts/sample-account/runs/SR3GEN-001/
├── manifest.yaml
├── intermediate/
│   ├── 00-execution-trace.md
│   ├── 04-draft.md
│   ├── 05-visual-plan.md
│   ├── 06-quality-review.md
│   └── 07-r3-generated-check.md
├── assets/
│   └── images/
│       ├── IMG-SR3GEN-001-001.png
│       ├── image-assets.md
│       ├── generation-records/
│       │   └── GEN-SR3GEN-001-001.md
│       └── metadata/
│           └── IMG-SR3GEN-001-001.metadata.yaml
└── deliverables/
    ├── content-delivery-record.md
    ├── html-embed-manifest.md
    └── final-delivery.html
```

---

## 3. 验证结果

```yaml
sample_id: SR3GEN-001
sample_status: pass
image_path_mode: generated
generated_path_verified: true
image_file_exists: true
metadata_sidecar_exists: true
checksum_algorithm: sha256
html_embed_manifest_status: embed_ready
final_delivery_html_status: html_ready
html_link_check: pass
```

本样本只说明 R3 generated 图片路径闭合，不说明真实内容测试通过，也不说明开源发布完成。
