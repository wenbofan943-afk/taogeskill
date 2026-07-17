# Resume and recovery

1. Run the deterministic session entry in resume mode. If a committed runtime
   binding exists, obey it. If only a version-pinned legacy plan exists, route
   to `legacy_r7` without adding a binding.
2. Read the version-pinned session plan, event projection, and current pointer.
3. If a pending submission exists, route to reconciliation before new work.
4. If the projection names one next step, route only to that registered node.
5. If hashes, revisions, pointers, or runtime-binding markers disagree, return `blocked` with the
   contract-break fingerprint; do not repair or copy artifacts.
6. If the session is complete, report completion instead of starting a new
   session silently.
