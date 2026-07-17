# Resume and recovery

1. Read the version-pinned session plan, event projection, and current pointer.
2. If a pending submission exists, route to reconciliation before new work.
3. If the projection names one next step, route only to that registered node.
4. If hashes, revisions, or pointers disagree, return `blocked` with the
   contract-break fingerprint; do not repair or copy artifacts.
5. If the session is complete, report completion instead of starting a new
   session silently.
