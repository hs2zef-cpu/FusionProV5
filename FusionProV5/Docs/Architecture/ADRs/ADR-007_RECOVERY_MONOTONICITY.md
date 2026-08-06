# ADR-007: Recovery Monotonicity and Evidence

## Status

Accepted as a corrective contract decision for independent review.

Governance note: this decision is part of the Sprint 4.1 Candidate / In Review package. It does not Architecture Lock the candidate, replace Sprint 4 as the authorized baseline, or authorize runtime implementation.

## Decision

The Basket lifecycle remains the sole authority for cumulative recovery attempts and current recovery layer. An `ACTIVE -> RECOVERY` request carries typed prior and proposed attempt/layer values, authorization identity, evidence identity, sequence, and timestamp. The proposal must increment cumulative attempts and layer exactly once. The decision exposes the resulting attempt, layer, state, and state version.

Accepted recovery evidence identities are durable and reconstructible. Restart restores both counters and their accepted-evidence index. A repeated identity cannot increment counters again, and any regression or reset fails closed.

## Consequences

- Local arithmetic is not recovery verification; interface output is authoritative.
- Restart cannot infer attempts from positions or reset counters.
- Duplicate or stale evidence preserves the prior state version and counters.
