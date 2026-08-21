# ADR-010: EA Host Single-Writer Event Serialization

## Status

Revised proposal for Sprint 5 Phase A.1 independent architecture re-review.

Governance note: this decision is architecture-only. It grants no runtime, broker, or production authorization.

## Context

Sprint 4 assigns independent domain authorities but does not settle how concurrent platform callbacks are prevented from advancing the same pending request, Basket, checkpoint, or ownership-bound state twice.

## Decision

The future EA Host is the sole orchestration and mutation coordinator for one ownership namespace. Signal ingress, timer/lease maintenance, platform transaction capture, restart/reconciliation, and persistence-publication events enter one deterministic, non-reentrant dispatcher. Each accepted event receives a monotonic host event sequence under the current ownership fence, and one event completes its authoritative decision/publication boundary before the next may advance the same state.

Platform callbacks capture immutable evidence only. They do not directly mutate Execution, Basket, Statistics, Risk, or Persistence. The dispatcher invokes each V5 domain interface and accepts only the complete returned decision/state; it cannot edit domain state locally. Transaction evidence captured while runtime eligibility is false is retained for reconciliation rather than treated as executable authority or discarded.

Lease loss immediately revokes general mutation and publication rights. It cannot revoke an already durably committed, single-use Submission Permit: that exact attempt remains unresolved external-side-effect authority under ADR-014, while no owner may mint a competing permit. Persistence operations use their actual operation-specific compare-and-set/fencing semantics. A failed or partial publication forces runtime-disable and reconciliation under ADR-015.

## Consequences

- Callback interleaving cannot create two authoritative writers.
- Single-host orchestration does not erase independent domain ownership.
- A later implementation must define and verify bounded queue durability, overload behavior, and crash recovery before Phase C can pass.
- Logs and dashboard events remain downstream observers.
