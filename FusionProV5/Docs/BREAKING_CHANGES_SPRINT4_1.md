# Breaking Changes: Sprint 4.1 Contract Hardening

Governance status: **CANDIDATE / IN REVIEW**. These proposed version 2 changes are pending formal approval and are not Architecture Locked. Sprint 4 remains the authorized baseline.

## Version Change

Production contract schema changes from version 1 to version 2. Version 2 has minimum compatible version 2.

## Interface Changes

- Every domain method receives `SWV5_ContractValidationContext`.
- Retcode classification returns `SWV5_ResultRetcodeClassification` instead of trusting classification fields supplied in raw evidence.
- Ownership `Release()` validates both the caller lease and observed store lease.
- Risk adds `ValidateHardKillRelease()`.
- Persistence lookup now requires `SWV5_PersistenceNamespace`, not BasketID.
- Persistence adds `LoadPendingRequests()` for complete pending-request reconstruction.

## Required Evidence Changes

- Basket close and transition evidence now records live positions/orders and query completeness.
- Partial-close and transaction evidence now has stable event identity and transaction sequence.
- Persistence records pending-request disposition and broker/history query completeness.
- Ownership records store revision, heartbeat sequence, takeover generation, and time authority.
- Risk authorization binds request, Basket, normalized terms, policy, owner, and expiry.
- Statistics records duplicate detection, transaction sequence, currency, and monetary completeness.
- Unit normalization binds to a symbol-specification sequence and explicit bid/ask context.
- `SWV5_OwnershipFence` is propagated through Basket, Execution, Risk, transaction, and Persistence evidence.
- `SWV5_ExecutionCorrelation` replaces separate request/order/deal/position identity fields.
- Persisted checkpoints contain canonical durable Hard Kill state.
- Basket lifecycle is the sole owner of recovery, open/residual volume, live counts, and pending count.
- Restart readiness uses one reconciliation disposition instead of parallel booleans.
- Canonical decision DTOs no longer expose contradictory allow/status booleans.

## Retcode Rename

`SWV5_RETCODE_CONFIRMED_SYNCHRONOUSLY` is replaced by `SWV5_RETCODE_SYNCHRONOUS_DEAL_REPORTED_PENDING_EVIDENCE`. A synchronous request result cannot independently confirm Basket state.

## Compatibility

No production implementation exists, so no runtime migration is performed. Any future implementation must target version 2 or receive an approved compatibility design.

No Sprint 3.2.1 Signal Engine API or behavior changed.
