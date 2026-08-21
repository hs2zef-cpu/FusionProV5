# ADR-013: Durable Ingress Acceptance And Deterministic Request Binding

## Status

Revised proposal for Sprint 5 Phase A.4 final independent architecture re-review.

Governance note: this ADR defines **Sprint 5 Candidate Contracts — NOT V5 existing authority**. It authorizes no DTO, store, or runtime implementation.

## Context

In-memory deduplication cannot prevent a second logical request after restart. V5 persists Execution requests but has no Signal-ingress ledger, namespace-wide request-sequence allocator, or atomic Signal-to-request transaction. Existing V5 `SavePendingRequests()` also cannot by itself prove cross-owner linearizable complete-set replacement.

## Decision

If separately authorized, Phase B will specify a pure Host Ingress Ledger contract persisted independently under compare-and-set. Its header binds contract/policy identity, persistence namespace, ownership fence, Producer Trust record/generation, producer instance/epoch, publication high-watermark, ingress policy, record/previous revision, compaction generation, membership/binding index, and ledger digest.

Each record binds ingress identity/sequence, acceptance disposition, deterministic logical correlation ID, a reservation returned by the Request Sequence Authority in ADR-017, authoritative acceptance time, request-materialization state, terminal disposition, record sequence, and integrity digest. The ledger digest preimage remains typed domain `SWV5-SPRINT5-INGRESS-LEDGER-V1` followed by every header and ordered record field, including explicit record indices, except the ledger digest itself; ADR-009 `H` produces the digest and the full ledger appends it. Authoritative states are:

- `REJECTED_NO_ENTRY`: valid `WAIT`/`BLOCKED`, terminal, no request permitted;
- `ACCEPTED_REQUEST_PENDING`: accepted directional ingress, request not yet durably observed;
- `BOUND_TO_REQUEST`: the exact deterministic logical request exists durably;
- `TERMINALLY_PROCESSED`: downstream request has an authoritative terminal disposition; and
- `TERMINALLY_BLOCKED_TRUST_REVOKED`: accepted evidence retained, but current Producer Trust revoked/superseded before request materialization and no execution authority may be created.

New, duplicate, replay-resolved, and conflict are evaluation dispositions, not lifecycle states. Compaction preserves membership, bindings, trust-terminal disposition, high-watermarks, and generation.

Logical `correlation_id` derives from ADR-009 `H`, domain `SWV5-SPRINT5-REQUEST-BINDING-V1`, persistence namespace, binding policy/version, and accepted ingress identity. The ledger is **not** the request-sequence allocator. The flow is:

1. CAS-persist `ACCEPTED_REQUEST_PENDING` with deterministic correlation ID and acceptance time.
2. Revalidate current Producer Trust; on revocation/supersession CAS-select `TERMINALLY_BLOCKED_TRUST_REVOKED` and stop.
3. Call ADR-017 `ReserveRequestSequence()` with the namespace, deterministic correlation ID, and current ownership fence. Existing reservation returns the same sequence; a new correlation reserves the next namespace-wide sequence.
4. CAS-bind the returned reservation in the ledger.
5. Construct the exact initial V5 blueprint: `attempt_id = H("SWV5-SPRINT5-ATTEMPT-V1", correlation_id, 0)`, empty parent attempt, reserved sequence, `created_at` equal to acceptance time, and `idempotency_key = H("SWV5-SPRINT5-IDEMPOTENCY-V1", correlation_id)`.
6. Use V5 `LoadPendingRequests()` to locate the exact request. If absent, publish the complete proposed set only through ADR-018 `CompareAndPublishPendingRequestSet()`; never call `SavePendingRequests()` as an unfenced direct replacement.
7. Reload/validate the durable set, then CAS-advance the ledger to `BOUND_TO_REQUEST`.

There is no fictitious cross-domain transaction. Crash after acceptance replays the same correlation. Crash after sequence reservation reuses the reservation; an orphan reservation is a harmless gap, not authority for a second request. Crash after request publication finds the same exact request and converges the ledger. Retries remain under the same logical correlation and sequence, allocate a durable ordinal greater than zero and unique attempt ID, and do not allocate another logical sequence.

Current Producer Trust is revalidated before any materialization/progression that creates increasing authority. After request creation, explicit revocation is ordered under ADR-020: revocation before the Increasing Execution Admission operation's conditional Policy Admission Linearization Point blocks admission and selects the applicable V5 request disposition; revocation after that point does not retroactively revoke the same operation if Claim completes, but blocks every later increase and retry. Claim-time Trust validity remains mandatory. Successful Claim preserves the uncertain attempt and admissible broker evidence.

## Consequences

- Signal replay, reservation replay, and crash convergence resolve to one logical request.
- All request origins share one namespace-wide allocator under ADR-017.
- Complete request-set publication is guarded by ADR-018, not inferred from existing V5 method signatures.
- The ledger, sequence authority, request-set store, and Submission Authority remain separate durable domains with explicit partial-state recovery.
