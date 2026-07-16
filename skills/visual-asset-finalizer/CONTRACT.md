# Visual Asset Finalizer Contract

```yaml
skill_id: visual-asset-finalizer
contract_version: 0.3.0
status: active_direct_v05_and_historical_v04
input_schema: taoge://schemas/r7/image-asset-set/v0.4 + taoge://schemas/r3/visual-stage-set/v0.1
output_schema: taoge://schemas/r7/image-asset-delivery-set/v0.2
record_schema: taoge://schemas/r7/asset-finalize-record/v0.1
producer: deterministic_tool_only
next_skill: copywriting-quality-review
```

The finalizer is fail-closed and idempotent. It never generates, captures, crops, overlays, annotates, rewrites, or visually approves an asset. One task produces one finalize record and one delivery binding. Required postprocess, evidence files, parent hashes, output hashes and actual-image review must already be complete.

Direct v0.5 joins the independent review set by task and delivery-asset digest. Zero visual finalizes as an empty `finalized_no_visual` set. Historical v0.4 retains image-asset-set v0.3 and delivery-set v0.1 replay behavior.

For current H2 runs, the review input is `taoge://schemas/r3/visual-asset-review/v0.1`, must be `pass`, must bind the exact final-candidate SHA256, and must be produced by the independent `visual_quality_reviewer` role.
