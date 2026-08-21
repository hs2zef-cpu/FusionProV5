# ADR-011: Broker Adapter Platform Boundary

## Status

Proposed for Sprint 5 Phase A independent architecture review.

Governance note: this decision defines a future boundary only. Phase A contains no broker adapter, platform call, or transaction callback implementation.

## Context

ADR-001 places broker execution in a separate host and assigns the EA Host the platform transaction callback. Production Contract V5 assigns Broker Adapter authority to broker query and margin evidence but does not fully document the platform translation boundary.

## Decision

The future Broker Adapter is the sole translator between V5 Execution DTOs and platform-specific broker facilities. It receives only an already-normalized, currently owned, Risk-authorized submission request. It returns raw submission/result evidence, immutable normalized transaction evidence, independently authoritative margin records, symbol specifications, and complete Broker-owned positions/orders/deals/transactions query snapshots.

The EA Host remains the sole platform callback owner; it captures the callback and passes the immutable raw capture through the adapter before serialized Execution validation. Execution remains owner of pending-request query authority.

The adapter cannot make or reinterpret a directional decision, classify a retcode by caller assertion, issue Risk authorization, transition Basket state, select Recovery policy, govern Persistence, or publish Statistics. Raw retcodes are classified only through the versioned V5 Execution policy.

## Consequences

- Platform dependencies remain outside the Signal Engine and domain policy.
- Broker and Execution restart-query authority remain independently sourced.
- Broker/build-specific retcode mappings, transaction ordering, query behavior, and Demo evidence are mandatory before any Phase F adapter is reviewable.
- This ADR authorizes no trade API.
