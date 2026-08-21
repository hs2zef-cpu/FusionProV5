# ADR-014: Submission Authority, In-Flight Attempt, And Takeover Quiescence

## Status

Proposed for Sprint 5 Phase A.1 independent architecture re-review.

Governance note: this ADR defines a **Sprint 5 Candidate Contract — NOT V5 existing authority**. It contains no broker implementation.

## Context

An ownership fence protects internal publication but cannot retract an external broker side effect after a process passes its final lease check. Safety therefore cannot depend on a broker call completing before lease expiry.

## Decision

Before any future side-effecting adapter invocation, the host must durably commit exactly one single-use Submission Permit for one logical request and one unique attempt. Permit commitment is a narrowly scoped, linearizable Sprint 5 Submission Authority operation: in the same authority decision it compares the current ownership fence/lease authority, verifies no permit already exists for the attempt and no unresolved competing permit exists for the logical request, and inserts the committed permit. The permit/ownership coordination must share one serializable authority boundary. If takeover wins first, the stale commit fails; if permit commit wins first, takeover observes the unresolved permit and must quiesce. This is not a general V5 transaction.

The permit binds:

- Sprint 5 contract/policy/format identity, permit ID, record sequence/revision/digest, and committed timestamp;
- persistence namespace, current ownership fence at issuance, account namespace/epoch and HEDGING mode;
- complete logical request and unique attempt identity;
- exact normalized intent/payload, normalization identity, symbol-specification sequence, and Basket ID/version;
- complete current V5 Risk authorization identity, binding, exclusive expiry, and current authority-evidence references;
- current Hard Kill state, latch ID, and generation; and
- permit disposition and single-use/invocation evidence.

`permit_id` is deterministic under ADR-009 `H` from typed domain `SWV5-SPRINT5-PERMIT-ID-V1`, persistence namespace, permit policy/version, complete logical request, and unique attempt identity. The permit digest preimage is typed domain `SWV5-SPRINT5-SUBMISSION-PERMIT-V1` followed by every permit field in fixed order except the digest itself; the full permit appends the digest. Same permit ID with different content is a conflict.

Immediately before commit, under one serialized host event, the host re-obtains current authoritative inputs and invokes the existing `ISWV5RiskContract::ValidateAuthorization(context, authorization, current_binding, decision)`. It also revalidates ownership/lease, Hard Kill, account namespace/epoch/mode, Basket version, symbol specification, V5 margin/Basket-risk evidence freshness, request/attempt identity, and exact normalized payload. The commit operation itself then atomically rechecks the expected current fence/lease generation. Any mismatch or race means no permit and no broker call.

The durable permit commit is the irreversible logical boundary:

- before commit, no broker side effect is allowed;
- after commit, the exact attempt is `COMMITTED_UNRESOLVED` and must be treated as possibly externally submitted, even if a crash occurs before the call;
- the permit cannot authorize another attempt or be replayed as a second invocation;
- absence of an immediate callback or elapsed time is not negative proof.

Permit dispositions are `COMMITTED_UNRESOLVED`, `AUTHORITATIVE_SIDE_EFFECT_CONFIRMED`, `AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED`, `AUTHORITATIVE_REJECTED`, and `CONFLICT_MANUAL_REQUIRED`. Only authoritative evidence may move a committed permit from unresolved to a terminal disposition; terminal mutation is idempotent and conflicting terminal evidence selects `CONFLICT_MANUAL_REQUIRED`.

Ordinary lease loss after commit does not revoke the historical one-attempt authority and cannot allow a new owner to mint a competing permit. The old host loses all general mutation/publication rights. If the broker invocation had not started when lease loss was observed, it must not be started, but the committed attempt still remains unresolved; if the invocation was already externally in flight, it may complete beyond local control. Any result must be reconciled and published by a current owner. A takeover must inspect unresolved permits and put their requests in `SWV5_REQUEST_RECONCILIATION_REQUIRED` with lifecycle phase `SWV5_EXECUTION_PHASE_UNCERTAIN`; increasing execution and retry remain blocked.

Resolution requires complete authoritative broker position/order/deal/transaction/history and Execution-request evidence under a versioned broker-specific positive or negative-evidence policy. No retry is permitted until that policy establishes definitive disposition. The broker-specific negative-evidence horizon is Phase F, but the no-proof/no-retry semantic is fixed now.

If Hard Kill latches after commit, no new increasing permit may be admitted. The committed attempt remains uncertain until authoritative disposition; confirmation is still reconciled, and only separately authorized V5 reducing/close-only action may follow.

## Consequences

- External safety depends on one durable attempt and takeover quiescence, not lease duration.
- A crash before the actual call may sacrifice availability, but never permits blind resubmission.
- The permit journal and validator are future Sprint 5 candidate contracts, not V5 Persistence capabilities.
