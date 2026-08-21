# ADR-010: EA Host Single-Writer Event Serialization

## Status

Proposed for Sprint 5 Phase A independent architecture review.

Governance note: this decision is architecture-only. It grants no runtime, broker, or production authorization.

## Context

Sprint 4 assigns independent domain authorities but does not settle how concurrent platform callbacks are prevented from advancing the same pending request, Basket, checkpoint, or ownership-bound state twice.

## Decision

The future EA Host is the sole orchestration and mutation coordinator for one ownership namespace. Signal ingress, timer/lease maintenance, platform transaction capture, restart/reconciliation, and persistence-publication events enter one deterministic, non-reentrant dispatcher. Each accepted event receives a monotonic host event sequence under the current ownership fence, and one event completes its authoritative decision/publication boundary before the next may advance the same state.

Platform callbacks capture immutable evidence only. They do not directly mutate Execution, Basket, Statistics, Risk, or Persistence. The dispatcher invokes each V5 domain interface and accepts only the complete returned decision/state; it cannot edit domain state locally. Transaction evidence captured while runtime eligibility is false is retained for reconciliation rather than treated as executable authority or discarded.

Lease loss immediately revokes mutation and publication rights. Persistence publication uses compare-and-set against the expected fence, record sequence, and store revision. A failed publication preserves the previous authoritative checkpoint and forces reconciliation/halt.

## Consequences

- Callback interleaving cannot create two authoritative writers.
- Single-host orchestration does not erase independent domain ownership.
- A later implementation must define and verify bounded queue durability, overload behavior, and crash recovery before Phase C can pass.
- Logs and dashboard events remain downstream observers.
