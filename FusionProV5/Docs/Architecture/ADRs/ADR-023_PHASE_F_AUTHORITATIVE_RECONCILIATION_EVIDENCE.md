# ADR-023 — Phase F Authoritative Reconciliation Evidence

Status: **CANDIDATE / IN REVIEW — NOT ARCHITECTURE LOCKED**

Decision scope: contract semantics only; no Broker Adapter or runtime authorization.

## Context

ADR-019, ADR-020, ADR-021 and frozen Phase B–E place a submission in `INVOCATION_CLAIMED_UNRESOLVED` as soon as Claim succeeds. A synchronous return, retcode, callback, timeout, transport failure, or a query returning zero rows cannot by itself prove whether a broker side effect exists. Restart and takeover must preserve that ambiguity without recreating Claim authority or permitting a duplicate invocation.

## Candidate decision

Phase F introduces a standalone reconciliation-evidence overlay. It consumes immutable projections of frozen Claim, request, persistence, ownership, query-authority, checkpoint, risk and Hard Kill records. It does not replace or modify any of those sources of truth.

The explicit state model is:

- `NO_CALL`: a digest-bound authoritative Execution-store proof establishes no successful Claim and no invocation; broker evidence can never create this state.
- `SUBMISSION_UNRESOLVED`: successful Claim exists but neither authoritative positive nor authoritative negative evidence exists.
- `SIDE_EFFECT_POSITIVELY_CONFIRMED`: durable broker order/deal evidence proves full requested effect.
- `PARTIAL_EFFECT_CONFIRMED`: durable evidence proves some effect while residual volume remains unresolved/exposed.
- `NO_SIDE_EFFECT_CONFIRMED`: fully qualified authoritative negative evidence proves absence for the bounded request/profile observation.
- `RECONCILIATION_BLOCKED`: binding is stale/invalid or authoritative evidence conflicts.

All reconciliation outcomes set `retry_allowed=false`. A negative terminal outcome may permit only a distinct future attempt through the existing admission, permit and Claim workflow.

`RECONCILIATION_BLOCKED` is sticky inside this evaluator. Evidence cannot clear it; only a separately governed operator/recovery authority outside this contract may do so. Otherwise-valid durable broker evidence with a missing, stale, foreign or invalid Claim/request/fence binding is an orphan side effect and transitions to `RECONCILIATION_BLOCKED`.

Terminal replay is idempotent only when the persisted confirmed/residual volume partition, authoritative evidence digest and frozen Submission Authority state agree with the terminal reconciliation state. A mismatch fails closed to `RECONCILIATION_BLOCKED`; replay never reconstructs confirmed volume as zero. Residual volume is reporting state only and is never submission authority. Submitting any remainder requires a new request identity, coherent admission snapshot, permit and successful Claim.

## Positive evidence

Authoritative positive evidence requires all of the following:

1. Exact profile, request identity, invocation Claim identity and Claim-record digest binding.
2. The exact correlation policy identity/version/digest pinned to the coherent admission/Claim boundary; current-latest policy lookup is forbidden. Magic or comment cannot be sole authority.
3. A separately governed, digest-bound capability-proof artifact approved and valid at the request boundary. It is profile-bound and cannot be authored or approved by the Broker Adapter it qualifies.
4. Independent durable query confirmation owned by the Broker Adapter authority.
5. Non-zero broker order/deal identifiers, a canonically digested ordered deal set, successful reading of every enumerated row, deal-to-order linkage and a shared non-zero position identifier.
6. Symbol, direction, finite execution price and finite volume consistency with the bound request.
7. Query sequence later than the persisted broker-query high-watermark and observation time no earlier than Claim.
8. A canonical evidence digest.

A synchronous success/retcode or callback remains provisional until these conditions are met.

## Negative evidence

Authoritative negative evidence is an explicitly profile-scoped capability, not an inference from empty arrays. It requires:

1. The exact correlation, negative-evidence and capability-proof identities/versions/digests pinned before Claim to the coherent request/admission boundary. Policy drift is a blocking conflict.
2. A domain-separated, independently governed capability-proof artifact establishing query-completeness and visibility-watermark capability for the exact broker profile. Bare booleans are not authority.
3. Exact authoritative Broker flags for positions, orders, deals and transactions, plus the separately owned Execution pending-request flag.
4. Successful, complete enumeration with zero row-read failures and history coverage beginning at or before Claim.
5. Separately owned Broker and Execution read paths, distinct authority instances and independently advancing owner-specific sequences. A shared cache/snapshot cannot satisfy the joint proof.
6. Two stable joint observations: the first is no earlier than `claimed_at + proven_visibility_lag`; the second is no earlier than the first plus the required stability interval; both sequences first exceed their persisted high-watermarks and then advance strictly.
7. Identical connection and restart generations across both observations, equal to the required current generations. Any generation change invalidates the pair.
8. Zero request-matching rows in every required domain and canonical observation digests.

Unrelated rows do not invalidate an observation. Query failure, partial enumeration, unsupported completeness, stale generation, a missing watermark, or merely zero returned rows preserves `SUBMISSION_UNRESOLVED`.

The current F0 Exness Demo profile evidence explicitly remains `UNPROVEN`; therefore it cannot satisfy this negative-evidence contract.

Capability proof, correlation policy, negative policy, positive evidence, negative observation and terminal reconciliation result use distinct canonical digest domains. Cross-domain digest substitution fails validation.

## Retcode and callback semantics

Pre-call local rejection can establish `NO_CALL` only if neither Claim nor invocation occurred. Client-local post-invocation rejection, broker-rejection candidates, accepted/provisional fields, timeout, platform/transport error, unknown retcode, malformed response, callback-only evidence and callback absence are all non-terminal classifications. A broker-rejection candidate reaches a terminal rejection only when the same fully qualified negative-evidence requirements are met.

## Ownership, restart and publication

The original Claim fence remains immutable evidence of who acquired invocation authority. Reconciliation publication requires a valid current lease/fence and CAS revision. A current owner may publish evidence about the historical Claim but cannot rewrite it. Restart, reconnect or takeover never recreates `CLAIM_GRANTED_NOW`, never authorizes retry and never moves backwards from Claimed to Committed.

## Consequences and deferred work

This candidate closes the contract vocabulary and deterministic reference model only. It does not prove broker-query completeness, visibility watermarks, correlation carrier selectivity, reconnect behavior with exposure, physical persistence, platform clocks or any real Broker Adapter behavior. Those require separately authorized Phase F/G implementation and empirical gates.
