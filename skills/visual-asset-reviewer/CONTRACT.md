# Visual Asset Reviewer Contract

```yaml
skill_id: visual-asset-reviewer
contract_version: 0.1.0
status: active_h2_compiled
role: visual_quality_reviewer
input: current delivery-candidate raster + bound semantic/provenance evidence
output_schema: taoge://schemas/r3/visual-asset-review/v0.1
runtime: tools/invoke-r7-visual-semantic.ps1
runtime_mode: finalize_asset_review
next_on_pass: visual-asset-finalizer
```

The reviewer is independent, raster-observing, immutable and fail-closed. Eight dimensions are mandatory. A revision verdict must identify the minimal target, owning producer and stale scope; the reviewer never performs the revision.
