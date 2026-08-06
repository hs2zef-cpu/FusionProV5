# Breaking Changes: Sprint 4.3 Contract Correction

Governance status: corrective work within the Sprint 4.1 **CANDIDATE / IN REVIEW** branch. Sprint 4 remains the authorized baseline. This change is not Architecture Locked and grants no runtime authorization.

## Version Change

Production contract schema changes from version 2 to version 3. Version 3 has minimum compatible version 3 because required DTO fields and interface signatures changed and V2 cannot deterministically default the missing evidence.

## Breaking Contract Changes

- `SWV5_ExecutionIntent` now carries `SWV5_ExecutionRequestIdentity` and explicit account mode; it cannot contain future broker tickets.
- `SWV5_ExecutionCorrelation` now combines a lifecycle phase, pre-submission request identity, and post-submission broker identity.
- `ISWV5ExecutionContract` adds `ValidatePhaseTransition()`.
- Basket transitions add typed recovery evidence and decisions expose resulting recovery attempt/layer.
- Pending and persisted requests add reconstructible state, durable identity membership, acknowledgement/confirmation, retry, authorization, normalization, mode, fence, Basket version, and symbol-specification evidence.
- `ISWV5PersistenceContract` adds `SavePendingRequests()` and restart results add one canonical readiness disposition.
- Ownership claims replace reconciliation booleans with typed takeover evidence.
- Hard Kill release replaces reconciliation booleans with typed broker, persistence, exposure, and independent approval evidence.
- Risk snapshots and authorizations bind a full account namespace and coherent snapshot epoch.
- Unit normalization removes caller-selected rounding and adds explicit operation, separate applied rounding results, directional stop validation, actual-price freeze validation, and specification expiry.
- Statistics deduplication uses the common durable event identity set.

## Compatibility

No production runtime implementation or production persistence exists. No runtime data migration is performed. Any future implementation must target V3 or receive a separately approved migration design.

Sprint 3.2.1 and the Sprint 4 Architecture manifest remain unchanged.
