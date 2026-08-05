# ADR-006: Hard Kill Governance

## Status

Accepted.

## Decision

Hard Kill is a durable latch. Restart, reattachment, ownership takeover, or a new signal cannot clear it. While latched, only reconciliation and explicitly authorized risk-reducing or close-only actions are eligible.

The canonical `SWV5_HardKillState` contains persistence namespace, latch identity, latch generation, activation state/reason/authority/time, release generation, and release evidence. It is stored in every persisted checkpoint and its generation is bound into Risk Authorization.

Release requires identified operator authority, broker and persistence reconciliation, confirmed zero or reducing exposure, an expiry, and an auditable reference. Release evidence cannot be created or approved by the execution component that consumes it.

## Consequences

- Missing, expired, self-issued, or incomplete release evidence is rejected.
- Hard Kill evaluation precedes every other Risk domain.
- Restart loads and reconciles the persisted latch before any readiness decision.
- Detailed operator workflow and credential storage remain deployment concerns for a later approved Sprint.
