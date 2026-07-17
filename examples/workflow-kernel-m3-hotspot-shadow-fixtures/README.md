# Workflow kernel M3 hotspot shadow fixtures

This fixture set validates the isolated hotspot shadow adapter introduced by
`ARCH-20260718-002`.

It covers:

- full frozen-observation parity;
- research and freshness external wait/reconcile;
- Topic Gate and final human waits;
- semantic-update and topic-revalidation replans;
- command idempotency, projection rebuild, tamper detection, containment, and
  false-success negatives.

All inputs are offline and synthetic. The checker does not access the network,
invoke a provider, write current production state, or certify a runtime switch.
