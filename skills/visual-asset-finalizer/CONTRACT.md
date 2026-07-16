# Visual Asset Finalizer Contract

```yaml
skill_id: visual-asset-finalizer
contract_version: 0.1.0
status: active
input_schema: taoge://schemas/r7/image-asset-set/v0.3
output_schema: taoge://schemas/r7/image-asset-delivery-set/v0.1
record_schema: taoge://schemas/r7/asset-finalize-record/v0.1
producer: deterministic_tool_only
next_skill: copywriting-quality-review
```

The finalizer is fail-closed and idempotent. It never generates, captures, crops, overlays, annotates, rewrites, or visually approves an asset. One task produces one finalize record and one delivery binding. Required postprocess, evidence files, parent hashes, output hashes and actual-image review must already be complete.
