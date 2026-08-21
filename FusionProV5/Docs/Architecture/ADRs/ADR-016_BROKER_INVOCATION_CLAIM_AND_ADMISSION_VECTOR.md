# ADR-016: Broker Invocation Claim And Admission Vector

## Status

Proposed for Sprint 5 Phase A.2 independent architecture re-review.

Governance note: this ADR defines **Sprint 5 Candidate Contracts — NOT V5 existing authority**. It authorizes no broker API, runtime, or Phase B implementation.

## Context

A durable permit state readable after restart cannot distinguish the one event that won admission from a duplicate event that merely observes the state. Exactly-once adapter admission therefore needs a durable state transition whose success returns a non-replayable event-local grant, while current Risk and every other admission-invalidating authority are compared at that same boundary.

## Decision

`TryClaimInvocation(...)` is a future linearizable Submission Authority operation:

```text
COMMITTED_NOT_INVOKED
  -> INVOCATION_CLAIMED_UNRESOLVED
```

It compares expected permit ID/revision/state, exact current request/attempt/payload, current ownership fence and takeover generation, current authoritative time, and the expected Admission Version Vector/revision. The claim transition and ownership takeover share one serializable authority boundary: if takeover wins first the stale claim fails; if claim wins first takeover observes `INVOCATION_CLAIMED_UNRESOLVED` and quiesces. It succeeds exactly once and durably persists claimant identity/fence, claim sequence/revision, authoritative claim time, claim digest/integrity, and the complete compared vector. Only the caller that performs the successful transition receives ephemeral result `CLAIM_GRANTED_NOW`. Every later call returns already-claimed, conflict, invalid, expired, or equivalent fail-closed disposition and can never recreate `CLAIM_GRANTED_NOW`.

Only the same serialized host event holding `CLAIM_GRANTED_NOW` may invoke the Broker Adapter. Merely reading `INVOCATION_CLAIMED_UNRESOLVED` grants nothing. Duplicate events, restart, takeover, a second host, or a second callback cannot invoke the adapter from persisted state.

Immediately before the claim, the host obtains the current complete authority binding, calls the real V5 `ISWV5RiskContract::ValidateAuthorization(context, authorization, current_binding, decision)`, validates current Producer Trust and Hard Kill, and validates current ownership, account namespace/epoch/mode, Basket, request/set revision, symbol specification, margin authority, Basket-risk authority, normalized payload, and exclusive expiries. The claim CAS rechecks that exact vector and current authoritative time. Risk expiry at equality fails.

The immutable Submission Admission Version Vector binds at least:

- ownership fence and lease/takeover generation;
- Producer Trust record/generation/status, producer component/instance/epoch, and validity policy;
- Hard Kill latch/state/generation;
- account namespace/epoch and account-mode observation identity;
- Basket ID/version;
- pending-request identity/state/set revision;
- symbol-specification sequence;
- margin authority ID/generation/digest/freshness;
- resulting Basket-risk authority ID/generation/digest;
- V5 Risk authorization ID, a candidate canonical digest of the complete authorization, and exclusive expiry;
- request correlation/attempt and normalized payload identity/digest;
- authoritative validation clock ID/sequence/time; and
- versioned admission policy identity.

Canonical claim and vector integrity use ADR-009 framing. The Admission Version Vector digest preimage begins with typed domain `SWV5-SPRINT5-ADMISSION-VECTOR-V1` and contains the fields above in fixed contract order except its own digest. The Invocation Claim digest preimage begins with `SWV5-SPRINT5-INVOCATION-CLAIM-V1` and contains permit identity/revision, complete claimed vector/digest, claimant/fence, claim sequence/revision/time, and policy/version except its own digest. Each full record appends its digest; same identity/revision with different content is conflict.

Every host-accepted admission-invalidating change advances one monotonic `admission_revision` in the serialized host authority stream. This is a derived snapshot generation, never a replacement for a domain authority. Ownership/fence, Producer Trust, Hard Kill, Basket version, account epoch/mode, symbol specification, material Risk evidence/expiry, and request state/set revision changes advance it. Any mismatch denies claim and broker invocation.

Successful claim is the conservative irreversible external-side-effect point. Crash after claim but before the broker call is `UNCERTAIN`, not retryable. Later authority changes cannot pretend the attempt never existed; they block new increasing authority while authoritative broker evidence is reconciled.

### Exactly-once counterexample proof

1. Permit P is `COMMITTED_NOT_INVOKED`.
2. Event E1 calls `TryClaimInvocation`, wins the CAS, receives `CLAIM_GRANTED_NOW`, and durably produces `INVOCATION_CLAIMED_UNRESOLVED`.
3. Duplicate E2 compares P and finds it already claimed, so receives no grant and cannot call the adapter.
4. Restart and takeover can load only the persisted claimed state, never E1's ephemeral result, so neither can call the adapter.
5. Claimed state blocks a competing permit/retry until authoritative disposition.

## Consequences

- Claim, not permit, closes the final Risk/Hard Kill/trust TOCTOU boundary.
- Exactly one serialized event can enter the adapter for an attempt.
- Availability may be lost after claim-before-call crash; safety is preserved.
- Phase B can define pure DTOs, outcomes, vector validation, and interfaces without broker code.
