# ADR-015: Runtime Publication Boundaries And Crash Recovery

## Status

Proposed for Sprint 5 Phase A.1 independent architecture re-review.

Governance note: this ADR documents actual V5 operation boundaries and future Sprint 5 journals. It authorizes no store implementation.

## Context

V5 exposes `SavePendingRequests()` and `SaveCheckpoint()` separately. `PublishRestartQueryWatermarks()` is atomic only for its validated proposal, the two accepted query high-watermarks, and checkpoint publication metadata. V5 exposes no general atomic transaction across Basket, pending requests, accepted events, Hard Kill, reconciliation, Statistics, ingress, and submission permits.

## Decision

Architecture claims only these existing V5 boundaries:

- `SavePendingRequests()` independently publishes the complete ordered V5 request set;
- `SaveCheckpoint()` independently publishes one V5 checkpoint;
- `PublishRestartQueryWatermarks()` atomically advances its two owner-specific query high-watermarks and the validated checkpoint metadata described by that interface.

The Host Ingress Ledger and Submission Permit journal each require a separately versioned, fenced, digest-bound Sprint 5 Candidate persistence contract. Atomicity is local to one ledger mutation. Submission Permit commitment has the additionally narrow ADR-014 requirement to serialize its ownership-fence comparison and permit insertion with takeover authority; it is not a general multi-domain transaction.

At runtime the host first publishes an open-session checkpoint with `clean_shutdown=false` before eligibility. Related V5 changes use independently fenced/versioned writes in an explicit recovery order: authoritative complete pending-request state first; then a checkpoint derived from the observed durable request set and validated Basket/Hard Kill/reconciliation state. Statistics remains reconstructible from authoritative deal history and is not claimed as part of either write.

The host may expose a dependent authoritative state only after its required operation succeeds. A crash or failure between related writes creates dirty/unresolved state, revokes runtime eligibility, and requires complete restart reconciliation. The later write may not infer that the earlier write succeeded, manufacture missing state, or reinterpret a partial publication. CAS failure preserves the previously authoritative record. Orderly shutdown alone may publish `clean_shutdown=true` after all authoritative work is reconciled.

## Consequences

- No fictitious multi-domain atomicity is claimed.
- Crash convergence relies on durable identities, deterministic bindings, actual V5 reconciliation, and fail-closed readiness.
- Physical transaction/store technology remains a Phase D decision.
