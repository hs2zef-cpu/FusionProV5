# ADR-005: Unit and Pip Policy

## Status

Accepted.

## Decision

Point, tick, pip, price, volume step, and monetary tick value remain distinct. Pip size must be explicit symbol configuration or authoritative metadata; it is never universally inferred from digits or point size.

Price normalization uses tick size. Volume normalization uses volume step and records the rounding direction. Exposure-increasing volume defaults to conservative downward rounding. Stops and freeze checks use explicit bid/ask context, operation purpose, direction, and the same symbol-specification sequence used for normalization.

The specification sequence flows unchanged through normalized evidence, Execution Intent, pending request, persisted request evidence, and Risk Authorization. Any mismatch invalidates the authorization and request.

## Consequences

- Stale or changed symbol specifications invalidate normalized terms and Risk authorization.
- Missing tick value, currency mismatch, invalid step, or incomplete market context fails closed.
- Monetary tick value identifies its currency and basis volume.
- Closing residual exposure may require a separately specified broker-safe rounding rule; it cannot reuse an exposure-increase assumption silently.
