# ADR-009: Signal Decision Ingress Boundary

## Status

Proposed for Sprint 5 Phase A independent architecture review.

Governance note: this decision is part of the Sprint 5 Phase A Architecture Candidate / In Review. It does not Architecture Lock Production Contract V5, authorize runtime implementation, or modify the frozen Signal Engine.

## Context

ADR-001 separates broker execution from the indicator but intentionally leaves the future ingress contract unspecified. The frozen `SWV5_DecisionResult` carries the final action and result header, while its authoritative symbol, timeframe, execution mode, snapshot schema, and closed-bar identity originate in the immutable snapshot header. An Execution Layer cannot safely consume a naked action or reconstruct missing producer facts.

## Decision

A future Signal Ingress Adapter will consume one immutable, versioned ingress envelope published from the `DecisionEngine` path. The envelope binds the unmodified `SWV5_DecisionResult` to its authoritative `SWV5_SnapshotHeader` identity, a stable producer/component and producer-instance identity, publication timestamp and sequence, canonical correlation identity, canonical-format identifier, and payload digest.

Snapshot fields are carried from their existing authority and are not recalculated by the consumer. Request, attempt, broker, Basket, lease, Risk, and persistence identities are not invented at ingress; they remain distinct downstream V5 authorities.

Ingress validation is deterministic and fail-closed for unknown/incompatible schema, missing or corrupt identity, wrong symbol/timeframe, action/direction contradiction, invalid Decision result, stale input, duplicate membership, replay below the durable high-watermark, or digest mismatch. `WAIT` and `BLOCKED` are auditable no-entry outcomes and can never create an Execution Intent. `BUY`/`SELL` nominate the existing direction only; the adapter may deny eligibility but may not reverse or reinterpret it.

`ProductionArchitecture` does not include Signal Engine headers. A later pure adapter/DTO project must preserve that physical dependency direction.

## Consequences

- The Execution Layer consumes Decision authority without becoming a second Signal Engine.
- Signal identity and logical Execution request identity remain explicitly correlated but distinct.
- Freshness limits, canonical encoding, durable anti-replay retention, and producer trust provisioning require approved policy before Phase B implementation.
- No runtime connection is created by this ADR.
