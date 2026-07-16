# Talking Head Image PIP Contract

```yaml
skill_id: talking-head-image-pip
contract_version: 0.11.0
contract_status: confirmed
contract_set_version: r6-content-evidence-v0.2+r3-visual-coverage-v0.5+p0-delivery-v0.8
required_readiness: ready | ready_with_warnings
orchestrates:
  - static-visual-director
  - image-prompt-compiler
  - image-asset-producer
  - news-evidence-pip
  - visual-asset-reviewer
  - visual-asset-finalizer
  - delivery-visual-reviewer
  - copywriting-quality-review
```

Producer routing follows the exclusive source class. Evidence uses real capture/annotation, exact existing assets require scoped authorization, and all remaining accepted tasks enter Image 2 as generated-context bases. There is no cost, count, or per-image confirmation gate. External results are persisted before deterministic derivation and reconciled after interruption.

The five semantic stages are intent, route, generated-context brief when applicable, asset review, and delivery review. They use separate producer/reviewer roles. Operations must resolve through `routes/r7-visual-operation-registry.yaml`; missing capability is an explicit waiting state.
