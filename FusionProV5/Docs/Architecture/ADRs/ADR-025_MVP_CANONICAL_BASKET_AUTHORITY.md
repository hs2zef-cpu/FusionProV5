# ADR-025: Narrow MVP canonical Basket authority

## Status and scope

Implementation of the Fusion-authorized canonical flat Basket closure, pending
Fusion review. No Architecture Lock, actual D1 permission, Phase G permission,
recovery trading, or production-readiness declaration is conveyed.
Frozen Production V5 and Sprint 5 contract DTOs/interfaces remain unchanged.

## Authority boundary

`SWV5S5_MvpBasketStateMachine` implements the frozen Basket interface as a
closed MVP subset. It validates IDLE, OPENING, ACTIVE and fail-closed HALTED/ERROR
paths. Recovery/close trading authorization is deliberately unavailable.
`SWV5S5_MvpBasketLifecycleAuthority` alone publishes operational Basket state.
The host coordinates; Risk, Signal, Decision and Broker consume authority and
cannot issue a Basket version. No production file imports a test/reference owner.

## Flat initialization

Missing CURRENT is not flatness. Initialization requires canonical namespace
and Genesis readiness, an exact live physical ownership lease, Demo/HEDGING
Broker identity, successful complete positions/orders observations with zero
rows/failures/exposure, an independently read complete empty Execution request
set, no operational Submission record/index entry, and same-scope/fence
BootstrapZero. The verified infrastructure Submission GENESIS envelope is not
an operational Claim.

Only that owner issues and create-only persists IDLE/version 1 with zero
attempts, layer, volumes and counts, MATCHED reconciliation and
ZERO_RESIDUAL_CONFIRMED closure. Required V5 nested query/event integrity is
derived from facts. The frozen V5 compatibility checksum is not an authority
credential: complete physical payloads use domain-separated SHA-256 and guarded
CAS/readback. Aggregate payloads are lossless typed records, not version/count
projections. Identical repeated initialization is idempotent; conflicting,
corrupt or stale-owner state fails closed without replacement.

## Admission and confirmation

Risk, Intent, Blueprint, PendingRequest, Permit, both Admission collections and
Claim pin/vector consume the same physically loaded version. Initial D1 leaves
Basket IDLE/v1 throughout Claim admission. There is no Basket write between
CLAIM_GRANTED_NOW and send. IDLE plus claimed-unresolved remains a valid
unresolved state, never permission for another increasing request.

Acknowledgement, retcode, ticket or callback arrival is not confirmation.
Positive reconciliation must pass frozen Phase F evidence validation and prove
the exact CURRENT open position from the same complete Broker observation.
The owner retains full IDLE/v1, OPEN_AUTHORIZED request, OPENING/v2,
OPEN_CONFIRMED request and ACTIVE/v3. Immutable history and final CURRENT are
published in one ownership-guarded SQLite pair transaction. Physical row revision
advances once while the two ordered logical state versions advance twice.
Neither IDLE-to-ACTIVE nor a partially visible history publication is allowed.

## Restart handoff

Reconciliation publication persists the complete typed frozen publication,
not merely its result digest. A crash before Basket publication or before
Submission terminalization can resume from the exact re-derived publication,
physical Claim, original pin/vector, current lease and newly queried positive
Broker evidence. A previously published ACTIVE requires exact ordered-history
and CURRENT validation; it cannot be republished with fresh versions.
No Claim grant is reconstructed. D6 has no submission capability.
No-positive D6 remains unresolved; negative completeness is not authorized.

## Verification boundary

REAL-MQL tests use actual production owners and suite-private physical SQLite
stores. External market/Broker observations are explicitly test-only fixtures;
they are not proof of actual Demo D1 or live exposure. Two SQLite trigger faults
abort real owner writes at the confirmation handoffs; restart must complete
without rewriting Basket history or creating another submission. Python oracle,
source checks, compiler results and MQL execution evidence are reported separately.
