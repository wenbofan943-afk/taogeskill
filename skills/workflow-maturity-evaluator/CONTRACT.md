# Workflow Maturity Evaluator Contract

```yaml
skill_id: workflow-maturity-evaluator
contract_version: "0.1"
owner_project: taoge-creative-workflow
status: active
confirmed_scope: R7-C133-C160
compile_batch: R7-L3-H1
runtime_activation: offline_fixture_active_real_certification_requires_H2_H5
```

## Trigger and preconditions

Trigger only for baseline creation, run-start capability freeze, session evidence derivation, cohort append, route evaluation, or project evaluation. Required objects must exist at fixed caller-selected paths and share one baseline digest.

## Reads and validation

- versioned capability registry and current local producer files;
- caller-materialized timestamps with timezone;
- observation facts for steps, commits, external attempts, human gates, file writes, final delivery, and blockers;
- immutable session evidence already appended to a cohort.

The runtime derives fingerprints and interventions. It rejects missing capability entries, baseline drift, session/snapshot mismatch, duplicate conflicts, and route/project cross-baseline input.

## Produces and paths

The command writes one of these v0.1 objects to the explicit `-OutputPath`: maturity baseline, run snapshot, intervention ledger, session autonomy evidence, cohort, route autonomy evidence, or project maturity evidence. Real certification objects belong inside the private session/cohort evidence area; fixture reports belong under `state/checks/`.

## Automatic progression

Successful session evaluation may append to its pre-opened cohort. Successful append may recompute route and project evidence. It must not start a new content run, call a provider, or publish.

## Human gates

No new human decision is created by this Skill. It validates only already-registered typed human decisions. A human edit to machine state is an intervention, not a gate.

## Failure semantics

```text
maturity_baseline_changed
session_baseline_mismatch
session_snapshot_identity_mismatch
cohort_baseline_mismatch
cohort_session_evidence_conflict
input_identity_missing
run_started_at_invalid
```

All failures preserve prior evidence. `duplicate_reused` is successful idempotent replay.

## Transparency and maturity

`intervention_ledger` is machine-derived and distinguishes unregistered execution, artifact producer mismatch, missing external evidence, untyped human action, unregistered file writer, machine-object producer bypass, run-specific helper output, and declared manual intervention. One fixture pass proves only H1 compilation, not route/project L3.

## Acceptance examples

1. Two distinct direct autonomous deliveries produce route L3.
2. A waiting sample does not increment or reset the route count.
3. An unregistered helper produces assisted delivery.
4. Two hotspot sessions with the same event cluster do not produce route L3.
5. Both routes at L3 with incomplete capability coverage produce `l3_candidate`.
6. Full coverage with a current blocker still produces `l3_candidate`.

## Open-source boundary

Schemas, registry identities, Skill, runtime, checker, and sanitized fixtures are publishable. Real account paths, session evidence, source captures, provider outputs, and private cohort data are not.
