# Fusion Pro V5 Sprint 4.1 Contract Hardening

## Status

**CANDIDATE / IN REVIEW**

Pending formal approval. Sprint 4 Architecture remains the authorized baseline. Sprint 4.1 is not Architecture Locked and grants no runtime authorization.

## Scope

Sprint 4.1 reviews and hardens Production Architecture contracts only. It adds no broker command path, automated trading, concrete store, concrete lease mechanism, Basket execution, Recovery algorithm, or Signal-to-Execution wiring.

Sprint 3.2.1 remains frozen.

## Contract Version

Sprint 4.1 advanced the schema from version 1 to version 2. Sprint 4.3 advanced the corrective candidate to version 3. Sprint 4.5 advances the still-unlocked candidate to version 4 with minimum compatible version 4.

Version 2 introduced the original hardening. Version 3 added the following boundaries, and version 4 completes authority binding, canonical validation, Risk/Unit semantics, ownership/CAS separation, and durable fingerprinting before formal approval:

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
- Phase-specific request identity and broker-generated correlation
- Explicit recovery proposal/evidence and resulting counters
- Reconstructible pending-request and durable event identity indexes
- Canonical Risk account namespace, coherent epoch, and account-mode binding
- Typed ownership takeover and Hard Kill release evidence
- Contract-derived unit rounding, directional stop validation, actual-price freeze checks, and specification expiry
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
- ADR-007: Recovery counters are monotonic and evidence-idempotent.
- ADR-008: Risk uses one canonical account namespace and epoch.

## Verification Status

- Contract source review: complete
- Deterministic test specification: complete
- Forbidden broker/runtime API static check: complete; no matches
- Signal Engine dependency static check: complete; no matches
- Frozen `.mq5` and Signal Engine diff check: complete; no changes
- Repository whitespace and line-ending policy check: complete
- MetaEditor X64 Regular compilation of the unchanged Sprint 4 Architecture manifest: `0 errors, 0 warnings`
- Sprint 4.2 executable verification sub-sprint: authorized and present
- Sprint 4.4 historical semantic corrective suite: 238 passed, 0 failed, 0 skipped in two MT5 Demo Strategy Tester runs; identical signature `6132791249901820115`
- Sprint 4.5 immutable verification: 368 passed, 0 failed, 0 skipped in each of two intentional independent MT5 Demo Strategy Tester runs; identical signature `14243830495988534780`; tested source `f768205573d44d71a7f55b8e893ae0b48770d451`

## Definition Of Done

- Formal approval promotes Sprint 4.1 from Candidate / In Review; until then Sprint 4 remains the authorized baseline.
- All contract changes are reviewed and approved.
- Contract version policy is accepted.
- All unresolved decisions in Sprint 4.1 scope have ADRs.
- Every safety-critical rule has table-driven cases.
- No broker execution or Signal Engine dependency exists.
- Sprint 3.2.1 remains unchanged.
- Verification evidence remains test-only and does not authorize runtime implementation.
