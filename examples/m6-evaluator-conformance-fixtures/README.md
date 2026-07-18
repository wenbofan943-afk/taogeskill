# M6 Evaluator Conformance Fixtures

This sample-only catalog binds known evaluator outcomes to the M6 freeze
contract. It covers topology preservation, invalid and non-comparable cases,
rejection fail-closed behavior, blind allocation mapping, known-answer
finalization, false-success mutations, and before/after source digest stability.

`compile_smoke` proves the suite is executable against the current worktree. It
does not certify the evaluator. Certification requires a clean committed source
revision and a separate `evaluation_certification` task.
