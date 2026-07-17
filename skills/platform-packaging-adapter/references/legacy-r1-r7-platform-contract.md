---
applicability: historical_only
load_when: contract_version in r1,r7 && mode in legacy,replay
source_contract: pre-R8-H4 platform packaging CONTRACT
---

# Historical platform handoff contract

This reference preserves the pre-R8-H4 Markdown-era handoff gates for replay and audit. It is not a current payload contract.

The historical `platform_package_input` required the following visual and trace fields before packaging:

```text
visual_text_plan_id
image_asset_set_id
visual_text_quality_gate_status
image_asset_trace_status
asset_trace_quality_gate_status
html_embed_readiness_status
```

Historical readiness required:

```text
review_status = review_pass
static_visual_quality_gate_status = pass
visual_text_quality_gate_status = pass / not_applicable
image_asset_trace_status = pass
asset_trace_quality_gate_status = pass
html_embed_readiness_status = pass
```

The old contract could also describe `platform_package_input`, `cover_variant_set`, and `content_delivery_record` in one Skill. R8-H4 removed those embedded current responsibilities. Current semantic nodes own exactly one typed `platform_package`; historical files remain replay-only.
