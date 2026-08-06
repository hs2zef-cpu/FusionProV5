# ADR-005: Unit and Pip Policy

## Status

Accepted.

Governance note: this technical decision is part of the Sprint 4.1 Candidate / In Review package. It does not Architecture Lock Sprint 4.1, replace the Sprint 4 authorized baseline, or authorize runtime implementation.

## Decision

Point, tick, pip, price, volume step, and monetary tick value remain distinct. Pip size must be explicit symbol configuration or authoritative metadata; it is never universally inferred from digits or point size.

Price normalization uses tick size. Volume normalization uses volume step and records the rounding direction. The contract derives separate entry, stop, limit, exposure-increase, reduction, and residual-close rounding rules; callers cannot choose them. Exposure-increasing volume always rounds conservatively downward. Protective and residual exits use their explicit broker-safe rule. Stop validation is directional, and freeze checks use the actual operation price and market side. A symbol specification past `valid_until` is rejected.

The specification sequence flows unchanged through normalized evidence, Execution Intent, pending request, persisted request evidence, and Risk Authorization. Any mismatch invalidates the authorization and request.

## Consequences

- Stale or changed symbol specifications invalidate normalized terms and Risk authorization.
- Missing tick value, currency mismatch, invalid step, or incomplete market context fails closed.
- Monetary tick value identifies its currency and basis volume.
- Closing residual exposure may require a separately specified broker-safe rounding rule; it cannot reuse an exposure-increase assumption silently.
