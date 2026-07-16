---
name: workflow-maturity-evaluator
description: "Derive R7 session, route, and project autonomy evidence from registered runtime facts. Use when opening an L3 certification cohort, freezing a run capability snapshot, evaluating an observation, or recomputing route/project maturity without trusting self-reported manual-patch flags."
---

# Workflow Maturity Evaluator

## Purpose

Turn registered task, commit, attempt, human-gate, and file-write facts into append-only L3 evidence. Never infer autonomy from a successful HTML alone.

## Inputs

Read only versioned objects selected by the caller:

```text
routes/r7-runtime-capability-registry.json
maturity-baseline.v0.1
run-capability-snapshot.v0.1
autonomy-run-observation.v0.1
autonomy-certification-cohort.v0.1
```

The caller must materialize every audit timestamp with timezone. Do not use current machine time, file mtime, chat history, or a self-reported `manual_patch_detected=false` as evidence.

## Procedure

1. Before certification runs, call `tools/invoke-r7-maturity-evidence.ps1 -Mode new_baseline`, then `-Mode new_cohort`.
2. Before each run, call `-Mode new_snapshot`. A capability file or registered identity change must fail with `maturity_baseline_changed`; open a new baseline instead of mixing samples.
3. After the run reaches delivery, registered waiting, or failure, materialize one observation from task / receipt / event / artifact commit / provider attempt / human decision / file-write facts.
4. Call `-Mode evaluate_session`. The runtime writes the intervention ledger first, then session evidence. Unregistered execution, producer bypass, missing external parity, untyped human action, or declared manual help prevents autonomous delivery.
5. Append every certification run with `-Mode append_session`. Reusing the same evidence is idempotent; a different evidence digest for the same session is a conflict.
6. Call `-Mode evaluate_route` for direct and hotspot routes. Waiting neither increments nor resets; assisted delivery and failure reset the consecutive count. Two session IDs with the same input fingerprint do not prove repeatability.
7. Call `-Mode evaluate_project`. Project L3 requires both routes at L3, all six capability categories, and zero current contract blockers.

## Human gates

Registered Topic Gate, risk decision, and final acceptance are normal workflow nodes and do not reduce autonomy. Direct edits to machine artifacts, candidate, HTML, pointer, or event are interventions even when a human approved the business result.

## Failure and recovery

```text
maturity_baseline_changed -> open a new baseline and cohort; keep old evidence historical.
cohort_baseline_mismatch -> reject the append; never copy the sample into the cohort.
cohort_session_evidence_conflict -> inspect immutable evidence; do not overwrite it.
autonomous_waiting -> resume the same session after the registered blocker is resolved.
assisted_delivery / failed -> retain the ledger and let route consecutive count reset.
```

## Boundaries

- H1 is an offline evidence foundation. It does not run Image 2, browse, read private accounts, publish, or certify L3.
- Do not invent a helper to make a certification sample pass. Missing capability is an honest waiting result and a later `skill_compile` task.
- H2-H4 must connect current visual, direct, and hotspot producers before H5 real certification can start.
- A session outcome never upgrades a route or the project by itself.

## Output

Report the result code, baseline digest, evidence paths, intervention codes, route count/status, missing capability coverage, blockers, and project status. Keep public wording at L2.8 until a real H5 cohort produces project `l3`.
