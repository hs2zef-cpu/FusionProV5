# Sprint 5 Phase B.1 contract coverage matrix

| Authority | ADR | Corrected Phase B.1 contract | Verification | Deferred physical work |
|---|---|---|---|---|
| Signal/Decision ingress and Trust | ADR-009 | Exact ingress-bound current Trust anchor/generation/scope | Trust MQL group; oracle binding/static cases | Adapter/Trust store |
| Durable ingress acceptance | ADR-013 | Explicit ordered Ledger membership/binding index; unseen-below-HWM denial; compaction continuity | Ledger/Sequence MQL group; oracle LED cases | Physical CAS ledger |
| Request binding | ADR-013 | Policy/version-bound correlation; ordinal attempt; correlation-only idempotency; complete initial V5 blueprint | Canonical/Blueprint MQL groups; fixed oracle hashes | Runtime materialization |
| Permit reservation | ADR-014/016 | Complete typed Permit; stable ID; content conflict; pure preparation vs abstract commit | Permit/Blueprint MQL groups; oracle PER cases | Physical permit commit |
| Namespace request sequence | ADR-017 | Explicit authority-owned reservation index and recomputed authority digest | Ledger/Sequence MQL group; oracle SEQ cases | Linearizable allocator |
| Fenced publication | ADR-018 | Separate request-set/checkpoint proposals with exact-current digest/revision/fence/takeover/full payload | Publication MQL group; oracle PUB cases | Physical publication |
| Coherent admission snapshot | ADR-019 | Complete typed owner views, owner mutation evidence distinct from projection digest, V1/V2/final clocks | Snapshot/Claim MQL groups | Authority collectors |
| Conditional policy admission | ADR-020 | Pure Claim transition proposal; authoritative atomic Claim interface; no second Hard Kill/Trust-status veto | Claim/ADR-020 MQL groups; oracle CLM cases | Shared serialization backend |

Production Contract V5 persistence interfaces remain unchanged. No Phase C–G implementation is present.
