# ADR-002: Account Position Mode

## Status

Accepted for initial production implementation planning.

Governance note: this technical decision is part of the Sprint 4.1 Candidate / In Review package. It does not Architecture Lock Sprint 4.1, replace the Sprint 4 authorized baseline, or authorize runtime implementation.

## Decision

The first future execution implementation will support Hedging accounts only. Netting is rejected fail-closed until a separately approved Netting Basket model defines position aggregation, recovery-attempt accounting, partial closes, ticket attribution, and restart reconstruction.

Contract DTOs retain explicit `SWV5_AccountPositionMode` values so unsupported or unknown modes cannot be inferred.

## Consequences

- Position count is never used as Recovery layer or attempt count.
- An unknown, Netting, or changing account mode blocks execution readiness.
- Netting support requires its own ADR, fixtures, and compatibility review.
