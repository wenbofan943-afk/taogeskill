# M5 Compatibility Isolation Fixtures

This fixture set proves the compatibility boundary, not runtime autonomy:

- current Workflow IR and component catalog contain no legacy blueprint/node projection;
- a new `kernel_v1_current` session commits a v0.2 binding without a compatibility-catalog digest;
- current session start succeeds when the legacy catalog is absent from an isolated project;
- legacy plans and compile-time parity sources resolve only through the read-only compatibility loader;
- current callers, unknown versions, wrong routes, cross-generation binding fields, and cross-boundary assets fail closed;
- an already committed M4 v0.1 binding remains resumable without migration.

The fixtures are offline, use only `state/checks/`, and do not read private
accounts, call providers, certify runtime autonomy, or publish anything.
