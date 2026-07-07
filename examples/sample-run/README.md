# Sample Run

```yaml
sample_only: true
sample_run_status: template
contains_real_account: false
contains_real_customer_data: false
generated_image_path_verified: false
```

## 目的

本目录用于未来公开包中的 sample run。  
它应该展示一条内容链路的最小可读结构：

```text
manifest
execution_trace
topic / brief / draft / visual_plan
image_asset_set 或 pending_external
quality_review
platform_package
final-delivery.html
```

## 当前模板口径

R4 alpha 可以先使用 `pending_external` 图片占位样例。  
如果未来加入真实 generated 图片样本，必须补齐：

```text
asset_path
metadata_sidecar
checksum
generation_record
html_embed_manifest
```

不得把 pending_external 样例说成真实图片生成路径已通过。

