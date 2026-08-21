# ADR-011: Broker Adapter Platform Boundary

## Status

Revised proposal for Sprint 5 Phase A.1 independent architecture re-review.

Governance note: this decision defines a future boundary only. Phase A contains no broker adapter, platform call, or transaction callback implementation.

## Context

ADR-001 places broker execution in a separate host and assigns the EA Host the platform transaction callback. Production Contract V5 assigns Broker Adapter authority to broker query and margin evidence but does not fully document the platform translation boundary.

## Decision

The future Broker Adapter is the sole translator between V5 Execution DTOs and platform-specific broker facilities. For a side-effecting invocation it must receive an already-normalized V5 request, its exact current unique attempt identity, and the matching durably committed single-use Submission Permit defined by ADR-014. The adapter validates the permit's identity, payload digest, committed/unresolved status, and request/attempt binding and rejects invocation without an exact valid permit. It consumes submission authority; it never creates or renews it.

The adapter returns raw submission/result evidence, immutable normalized transaction evidence, independently authoritative margin records, symbol specifications, and complete Broker-owned positions/orders/deals/transactions query snapshots. A call may outlive ordinary lease duration; safety derives from one committed attempt, takeover quiescence, and reconciliation—not optimistic call timing.

The EA Host remains the sole platform callback owner; it captures the callback and passes the immutable raw capture through the adapter before serialized Execution validation. Execution remains owner of pending-request query authority.

The adapter cannot make or reinterpret a directional decision, classify a retcode by caller assertion, issue Risk authorization, transition Basket state, select Recovery policy, govern Persistence, or publish Statistics. Raw retcodes are classified only through the versioned V5 Execution policy.

## Consequences

- Platform dependencies remain outside the Signal Engine and domain policy.
- Broker and Execution restart-query authority remain independently sourced.
- Broker/build-specific retcode mappings, transaction ordering, query behavior, and Demo evidence are mandatory before any Phase F adapter is reviewable.
- A committed permit is not confirmation and cannot be reused for another attempt.
- This ADR authorizes no trade API.
