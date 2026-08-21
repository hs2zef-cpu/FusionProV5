# ADR-011: Broker Adapter Platform Boundary

## Status

Revised proposal for Sprint 5 Phase A.2 independent architecture re-review.

Governance note: this decision defines a future boundary only. Phase A.2 contains no broker adapter, platform call, or transaction callback implementation.

## Context

ADR-001 places broker execution in a separate host and assigns the EA Host the platform transaction callback. Production Contract V5 assigns Broker Adapter authority to broker query and margin evidence but does not fully document the platform translation boundary.

## Decision

The future Broker Adapter is the sole translator between V5 Execution DTOs and platform-specific broker facilities. A side-effecting invocation is admissible only from the same serialized host event that durably transitions the exact permit from `COMMITTED_NOT_INVOKED` to `INVOCATION_CLAIMED_UNRESOLVED` and receives the non-durable result `CLAIM_GRANTED_NOW` under ADR-016. It must also receive the already-normalized V5 request, exact current unique attempt, permit, and claim binding. Reading a persisted claimed state is never invocation authority. The adapter rejects a missing/mismatched claim result, permit, request, attempt, payload, or Admission Version Vector. It consumes the one event-local admission result; it never creates, renews, or reconstructs authority.

The adapter returns raw submission/result evidence, immutable normalized transaction evidence, independently authoritative margin records, symbol specifications, and complete Broker-owned positions/orders/deals/transactions query snapshots. A call may outlive ordinary lease duration; safety derives from one claimed attempt, non-replayable admission, takeover quiescence, and reconciliation—not optimistic call timing.

The EA Host remains the sole platform callback owner; it captures the callback and passes the immutable raw capture through the adapter before serialized Execution validation. Execution remains owner of pending-request query authority.

The adapter cannot make or reinterpret a directional decision, classify a retcode by caller assertion, issue Risk authorization, transition Basket state, select Recovery policy, govern Persistence, or publish Statistics. Raw retcodes are classified only through the versioned V5 Execution policy.

## Consequences

- Platform dependencies remain outside the Signal Engine and domain policy.
- Broker and Execution restart-query authority remain independently sourced.
- Broker/build-specific retcode mappings, transaction ordering, query behavior, and Demo evidence are mandatory before any Phase F adapter is reviewable.
- A committed permit is a reservation, not adapter-invocation authority or confirmation; `CLAIM_GRANTED_NOW` is never reproducible from persisted state.
- This ADR authorizes no trade API.
