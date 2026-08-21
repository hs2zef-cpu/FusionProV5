# ADR-012: Fail-Closed Startup And Runtime-Enable Gate

## Status

Revised proposal for Sprint 5 Phase A.1 independent architecture re-review.

Governance note: this decision is an architecture candidate. It does not declare Production Contract V5 Architecture Locked or authorize runtime implementation.

## Context

Production Contract V5 defines compatibility, ownership, persistence, complete restart queries, reconciliation, Hard Kill provenance, and atomic high-watermark publication. It does not name one host-level gate that prevents a restarted process from accepting a new signal before those authorities converge.

## Decision

The EA Host starts runtime-disabled. Clean shutdown evidence never bypasses restart validation. Runtime eligibility requires, in order:

1. exact supported contract/policy compatibility and HEDGING account mode;
2. valid current ownership acquired/recovered through compare-and-set and authoritative lease time;
3. validated checkpoint, complete ordered pending-request state, Sprint 5 Ingress Ledger, and Submission Permit journal;
4. persisted Hard Kill state and, for historical `RELEASED`, an independently obtained matching release-authority record;
5. fresh, complete, owner-correct, anti-replay-advancing Broker snapshots for positions/orders/deals/transactions and an independent Execution pending-request snapshot;
6. full V5 reconciliation of namespace, ownership, Basket, exposure, residuals, requests, correlations, transaction/event identities, Hard Kill, and revisions;
7. convergence of every accepted-ingress/request binding and inspection of every unresolved Submission Permit; any unresolved permit or uncertain attempt blocks increasing execution and blind retry;
8. contract result `SWV5_RESTART_SAFE_TO_RESUME` with no unresolved or uncertain prior attempt eligible for retry;
9. the specifically scoped atomic `PublishRestartQueryWatermarks()` publication of the reconciled checkpoint and both accepted query high-watermarks under the current fence/store revision; and
10. final revalidation of lease liveness, Hard Kill, account mode, symbol specification, and Risk authority.

Any missing, stale, corrupt, replayed, conflicting, or unknown authority keeps the host disabled in the returned close-only, halt, reconciliation, or operator-required disposition. A new namespace requires an explicitly provisioned genesis policy plus fresh zero-state reconciliation; missing persistence is not proof of a clean state.

## Consequences

- Restart cannot make a signal execution-eligible by itself.
- Positions-only or clean-flag-only recovery is forbidden.
- Pending/uncertain requests cannot be blindly retried.
- Store/genesis technology and deployment authority must be resolved before Phase D implementation.
