# Talking Head Image PIP Contract

```yaml
skill_id: talking-head-image-pip
contract_version: 0.9.0
contract_status: confirmed
contract_set_version: r6-script-structure-v0.1+r3-visual-coverage-v0.4+p0-delivery-v0.5
required_readiness: ready | ready_with_warnings
orchestrates:
  - static-visual-director
  - image-prompt-compiler
  - image-asset-producer
  - news-evidence-pip
  - copywriting-quality-review
```

Producer routing follows the ledger disposition. Only `generate_visual` enters Image 2. There is no cost, count, or per-image confirmation gate. External results are persisted before deterministic derivation and reconciled after interruption.
