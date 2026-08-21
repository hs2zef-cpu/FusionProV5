# ADR-014: Submission Permit Reservation And Takeover Quiescence

## Status

Revised proposal for Sprint 5 Phase A.2 independent architecture re-review.

Governance note: this ADR defines a **Sprint 5 Candidate Contract — NOT V5 existing authority**. It contains no broker implementation.

## Context

The Phase A.1 Submission Permit incorrectly made permit commitment the irreversible external-side-effect boundary. A durable reservation alone cannot grant exactly-once adapter invocation after duplicate events, restart, or takeover. Final Risk validation also requires a transition that atomically compares the complete current admission snapshot.

## Decision

A Submission Permit is a durable, fenced, single-use **admission reservation** for one logical request, unique attempt, exact normalized payload, and exact authority binding. Permit creation yields state `COMMITTED_NOT_INVOKED`; it does not consume broker-side-effect authority and never authorizes the Broker Adapter by itself.

The permit binds contract/policy/format, permit ID/revision/digest and commit time; namespace and ownership fence; account namespace/epoch and HEDGING mode; request/attempt; exact normalized payload and symbol-specification sequence; Basket ID/version; Producer Trust record/generation/component/instance/epoch/status/validity policy; V5 Risk authorization and evidence references; Hard Kill identity/generation; and the Admission Version Vector/revision defined by ADR-016. `permit_id` remains the ADR-009 `H` of typed domain `SWV5-SPRINT5-PERMIT-ID-V1`, namespace, permit policy/version, logical request, and unique attempt. The permit digest preimage remains typed domain `SWV5-SPRINT5-SUBMISSION-PERMIT-V1` followed by every permit field except its own digest; the full permit appends it. Same ID with different content is a conflict.

Creation is linearizable with current ownership/takeover authority and proves no permit exists for the attempt and no unresolved competing Submission Authority exists for the logical request. It may prepare admission, but the irreversible boundary is the later Invocation Claim in ADR-016.

If Producer Trust becomes revoked/superseded after permit creation but before claim, current authority invalidates the unclaimed permit to `INVALIDATED_BEFORE_CLAIM`, preserves it for audit, blocks claim, and applies the applicable V5 request cancellation/rejection/reconciliation disposition. Signal replay cannot recreate that authority.

Permit/Submission Authority states are:

- `COMMITTED_NOT_INVOKED`;
- `INVOCATION_CLAIMED_UNRESOLVED`;
- `AUTHORITATIVE_SIDE_EFFECT_CONFIRMED`;
- `AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED`;
- `AUTHORITATIVE_REJECTED`;
- `INVALIDATED_BEFORE_CLAIM`; and
- `CONFLICT_MANUAL_REQUIRED`.

These states correlate to, but never replace, the V5 Execution request state/lifecycle. `COMMITTED_NOT_INVOKED` corresponds to a prepared unique V5 attempt before irreversible submission. `INVOCATION_CLAIMED_UNRESOLVED` requires V5 `SWV5_REQUEST_SUBMISSION_PENDING` and, on restart/takeover or missing disposition, `SWV5_REQUEST_RECONCILIATION_REQUIRED` / `SWV5_EXECUTION_PHASE_UNCERTAIN`. Authoritative terminal evidence drives the applicable existing V5 confirmed/rejected/reconciliation outcome.

### Takeover before claim

An old host cannot claim after ownership loss, and a new owner cannot use the old permit as an invocation capability. Under current authority the unclaimed permit is durably invalidated to `INVALIDATED_BEFORE_CLAIM` and retained for audit. Current Producer Trust, Hard Kill, Risk, request, Unit, Basket, account, and ownership authority are re-evaluated. A new attempt and permit may be created only when the existing V5 retry/request policy separately permits progression. The old permit never migrates.

### Takeover after claim

An `INVOCATION_CLAIMED_UNRESOLVED` record is preserved. No host can invoke from it, mint a competing permit, or retry the logical request. V5 reconciliation-required/uncertain disposition applies until complete authoritative position, order, deal, transaction, history, and Execution-request evidence under a versioned broker-specific policy establishes positive or negative result. Timeout, reconnect, missing callback, or a locally empty query is never proof. The exact broker/build negative-evidence horizon remains Phase F.

Producer Trust or Hard Kill change after claim cannot erase the potentially external attempt. It blocks all new increasing authority while broker evidence remains admissible and must be reconciled.

Only authoritative evidence may move claimed Submission Authority to a terminal disposition. Terminal replay is idempotent; conflicting terminal evidence selects `CONFLICT_MANUAL_REQUIRED`.

## Consequences

- Permit creation is preparation; successful Invocation Claim is final broker admission.
- Unclaimed prior-owner permits are auditable but non-transferable.
- Claimed attempts sacrifice availability after ambiguous crashes to prevent duplicate external side effects.
- ADR-016 owns exactly-once Invocation Claim and the Admission Version Vector.
