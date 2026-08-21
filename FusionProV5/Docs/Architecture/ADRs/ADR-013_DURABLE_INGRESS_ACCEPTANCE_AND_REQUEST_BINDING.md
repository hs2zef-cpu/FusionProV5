# ADR-013: Durable Ingress Acceptance And Deterministic Request Binding

## Status

Proposed for Sprint 5 Phase A.1 independent architecture re-review.

Governance note: this ADR defines a **Sprint 5 Candidate Contract — NOT V5 existing authority**. It authorizes no DTO or persistence implementation.

## Context

In-memory deduplication cannot prevent a second logical request after restart. V5 persists Execution requests but has no Signal-ingress ledger or atomic Signal-to-request transaction.

## Decision

If separately authorized, Phase B would specify a pure Host Ingress Ledger contract, persisted independently under compare-and-set. The ledger header binds contract/policy identity, persistence namespace, current ownership fence, Producer Trust Authority record/generation, producer instance/epoch, highest accepted publication sequence, ingress policy version, record/previous revision, compaction generation, canonical accepted-record index, and ledger digest.

Each ingress record binds ingress identity, producer publication sequence, acceptance disposition, deterministic logical request correlation identity, namespace-monotonic request sequence, authoritative acceptance time, request-materialization state, terminal disposition, record sequence, and integrity digest. The ledger digest preimage is typed domain `SWV5-SPRINT5-INGRESS-LEDGER-V1` followed by every header and ordered record field, including explicit record indices, except the ledger digest itself. ADR-009 `H` produces the digest; the full ledger appends it. Authoritative states are:

- `REJECTED_NO_ENTRY`: valid `WAIT`/`BLOCKED`, terminal, no request permitted;
- `ACCEPTED_REQUEST_PENDING`: accepted directional ingress; deterministic request not yet durably found;
- `BOUND_TO_REQUEST`: exact deterministic logical request exists durably;
- `TERMINALLY_PROCESSED`: downstream request has a terminal authoritative disposition.

New, duplicate, replay-resolved, and conflict are evaluation dispositions, not replacement lifecycle states. Compaction must retain an authoritative membership/binding proof and high-watermark; it cannot make a previously accepted identity new again.

Using ADR-009 `H` and typed canonical framing, logical `correlation_id` is derived deterministically from domain `SWV5-SPRINT5-REQUEST-BINDING-V1`, persistence namespace, request-binding policy ID/version, and accepted ingress identity. The acceptance CAS also persists one namespace-monotonic request sequence and authoritative acceptance time. The initial V5 request blueprint is exact and reconstructible: `correlation_id` as above; `attempt_id = H("SWV5-SPRINT5-ATTEMPT-V1", correlation_id, 0)`; empty parent attempt; the persisted request sequence; `created_at` equal to acceptance time; and `idempotency_key = H("SWV5-SPRINT5-IDEMPOTENCY-V1", correlation_id)`. Retries allocate a new durable attempt ordinal greater than zero and a unique attempt ID under the same correlation; they never reuse the initial attempt. Broker identity remains later still.

The crash protocol does not claim a cross-domain transaction:

1. CAS-persist `ACCEPTED_REQUEST_PENDING` before request materialization.
2. Derive the logical request identity deterministically.
3. Use V5 `LoadPendingRequests()` to locate that exact request; if absent, publish the complete set containing the exact blueprint through `SavePendingRequests()` and reload/validate it.
4. CAS-advance the ledger to `BOUND_TO_REQUEST` only after the durable request is observed.

If a crash follows step 1, restart reconstructs the same request identity and resumes steps 3–4. If a crash follows step 3, restart finds that same request and converges step 4. Neither direction discards accepted intent or creates a second logical request.

## Consequences

- Signal replay after restart resolves to the prior ledger record and cannot create a second request.
- The ledger needs a future Sprint 5 persistence interface/store contract; it is not a new V5 checkpoint field or V5 operation.
- Physical retention, compaction storage, and credentials remain later implementation concerns; Phase B safety semantics are fixed.
