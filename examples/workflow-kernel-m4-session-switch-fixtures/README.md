# M4 Session Switch Fixtures

This fixture set verifies only the deterministic session-generation boundary:

- new direct and hotspot sessions bind to `kernel_v1_current`;
- existing version-pinned R7 sessions resume on `legacy_r7` without mutation;
- an engaged rollback affects only future new sessions;
- an existing kernel session never changes generation during rollback;
- partial, tampered, ambiguous, or out-of-root bindings fail closed.

The fixtures run offline under `state/checks/`. They do not use private accounts,
call a provider, execute semantic workers, certify L3, or migrate an existing
session.
