# ADR-018: Fenced Runtime Publication Authority

## Status

Proposed for Sprint 5 Phase A.2 independent architecture re-review.

Governance note: this is a **Sprint 5 Candidate Contract — NOT V5 existing authority**. It authorizes no store or runtime implementation and does not alter V5 interfaces.

## Context

The existing V5 `SavePendingRequests()` and `SaveCheckpoint()` signatures do not carry enough expected-current revision, digest, store, ownership, and takeover inputs to prove stale-owner-safe complete replacement. Host serialization protects one process, not a stale process racing a takeover.

## Decision

The Fenced Runtime Publication Authority is the only future normal-runtime Execution Layer admission path for authoritative complete pending-request-set and checkpoint publication. It owns concurrency/publication admission only; it does not own Execution lifecycle, Basket, Risk, Hard Kill, Instance Ownership, or domain validation policy.

`CompareAndPublishPendingRequestSet(...)` linearizably compares at least persistence namespace, expected current set revision/digest, expected store/publication revision, expected current ownership fence/takeover generation, and a proposed next set revision/sequence, complete proposed ordered request set, and proposed digest. On success the physical mutation and next publication metadata become durable as one store boundary. A stale expectation/fence fails with no overwrite.

`CompareAndPublishCheckpoint(...)` linearizably compares at least persistence namespace, expected current checkpoint/store revision, expected prior record sequence, expected ownership fence/takeover generation, and proposed checkpoint identity/digest. Choosing a larger sequence never bypasses a stale fence or expected-current mismatch.

Proposal integrity uses ADR-009 framing. Request-set proposals use typed domain `SWV5-SPRINT5-REQUEST-SET-PUBLICATION-V1`; checkpoint proposals use `SWV5-SPRINT5-CHECKPOINT-PUBLICATION-V1`. Each preimage contains the complete expected-current vector, proposed-next vector, ordered payload or checkpoint identity, and policy/version in fixed contract order except its own digest; the full proposal appends the digest. A digest match never substitutes for expected-current, store, or ownership authority.

Both paths must preserve and invoke the applicable V5 semantic validation. Existing `ISWV5PersistenceContract::SavePendingRequests()` and `SaveCheckpoint()` remain audited V5 operations, but future host code cannot call them as unfenced direct replacements. Phase D must implement the Sprint 5 guard at the selected physical store/lock boundary around durable publication. If impossible without changing V5 semantics, implementation is blocked pending an approved contract revision.

ADR-003 remains the accepted V5 persistence/lease atomicity authority. This ADR does not replace it; it defines the missing future normal-host publication-admission layer around the exact V5 save boundaries. The special V5 `PublishRestartQueryWatermarks()` remains unchanged and is not routed through a reinterpreted general transaction. No global transaction across ingress, sequence, requests, checkpoint, Submission Authority, Basket, or Statistics is claimed.

## Consequences

- A stale host cannot overwrite a newer request set or checkpoint.
- Request-set and checkpoint revisions remain separate publication domains.
- Publication CAS failure preserves prior authority and revokes runtime eligibility pending reconciliation.
- Phase B can define pure proposals/outcomes/interfaces; Phase D owns store feasibility proof.
