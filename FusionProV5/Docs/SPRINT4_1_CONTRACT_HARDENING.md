# Fusion Pro V5 Sprint 4.1 Contract Hardening

## Status

Contract hardening candidate. Review and approval are required before commit or lock.

## Scope

Sprint 4.1 reviews and hardens Production Architecture contracts only. It adds no broker command path, automated trading, concrete store, concrete lease mechanism, Basket execution, Recovery algorithm, or Signal-to-Execution wiring.

Sprint 3.2.1 remains frozen.

## Contract Version

Production contract schema advances from version 1 to version 2. Minimum compatible version is 2 because interface signatures and required evidence changed.

Version 2 adds:

- Deterministic validation context
- Explicit contract policy ID and compatibility result
- Authoritative time source and evaluation sequence
- Explicit price and volume tolerances
- Complete position/order/pending-request query evidence
- Transaction event identity and idempotency evidence
- Retcode classification output separated from raw evidence
- Persistence pending-request and reconciliation completeness evidence
- Lease store revision, heartbeat sequence, and takeover generation
- Projected request risk and authorization term binding
- Auditable Hard Kill release evidence
- Deal deduplication and monetary-component completeness
- Symbol-specification sequence and bid/ask normalization context
- Canonical immutable ownership fence propagated across all authoritative domains
- Composite persistence namespace replacing BasketID-only lookup
- Durable persisted Hard Kill latch and release state
- Canonical request/order/deal/position/event correlation envelope
- Canonical Basket lifecycle values and restart disposition
- Arbitrary-order Statistics identity-set evidence
- Complete projected-Risk currency and calculation basis

## Ownership Boundaries

- The future EA host is the sole transaction-callback owner.
- Retcode acknowledgement remains non-authoritative for Basket confirmation.
- Basket State Machine alone owns lifecycle transitions.
- Live broker facts override persisted intent.
- Risk authorization cannot be modified or extended by Execution.
- Lease ownership requires compare-and-set evidence and authoritative time.
- Statistics consumes authoritative deal evidence only.
- Unit System owns normalization and records the symbol-specification sequence.
- Basket lifecycle is the sole canonical owner of recovery attempt/layer, open/residual volume, and pending count.
- Persistence uses account/server/strategy/symbol/Magic/Basket namespace and stores Hard Kill state.

## Deterministic Validation Boundary

Every contract interface now receives `const SWV5_ContractValidationContext &context`. Implementations must not read time, broker state, files, account state, or symbol metadata internally while validating supplied DTOs.

Sprint 4.1 defines validation requirements and table-driven specifications. It does not add concrete production implementations.

## Architecture Decisions

- ADR-001: Future execution lives outside the indicator.
- ADR-002: Initial future execution is Hedging-only; Netting fails closed.
- ADR-003: Persistence and leases require compare-and-set semantics.
- ADR-004: Transactions, not acknowledgements, confirm Basket state.
- ADR-005: Pip is explicit; tick/point/volume units remain separate.
- ADR-006: Hard Kill is durable and operator release is audited.

## Verification Status

- Contract source review: complete
- Deterministic test specification: complete
- Forbidden broker/runtime API static check: complete; no matches
- Signal Engine dependency static check: complete; no matches
- Frozen `.mq5` and Signal Engine diff check: complete; no changes
- Repository whitespace and line-ending policy check: complete
- MetaEditor X64 Regular compilation of the unchanged Sprint 4 Architecture manifest: `0 errors, 0 warnings`
- Behavioral fixture implementation/execution: not part of this hardening change

## Definition Of Done

- All contract changes are reviewed and approved.
- Contract version policy is accepted.
- All unresolved decisions in Sprint 4.1 scope have ADRs.
- Every safety-critical rule has table-driven cases.
- No broker execution or Signal Engine dependency exists.
- Sprint 3.2.1 remains unchanged.
- Future fixture implementation and execution occur only after separate approval.
