# ADR-016: Broker Invocation Claim And Admission Vector

## Status

Revised proposal for Sprint 5 Phase A.4 final independent architecture re-review.

Governance note: this ADR defines **Sprint 5 Candidate Contracts — NOT V5 existing authority**. It authorizes no broker API, runtime, or Phase B implementation.

## Context

A durable permit state readable after restart cannot distinguish the one event that won admission from a duplicate event that merely observes the state. Exactly-once adapter admission therefore needs a durable state transition whose success returns a non-replayable event-local grant. ADR-020 distinguishes that completion/uncertainty boundary from the conditional Policy Admission Linearization Point established by the coherent snapshot inside the same operation.

## Decision

`TryClaimInvocation(...)` is a future linearizable Submission Authority operation:

```text
COMMITTED_NOT_INVOKED
  -> INVOCATION_CLAIMED_UNRESOLVED
```

It compares expected permit ID/revision/state, the exact immutable Admission Snapshot/Vector digest established under ADR-019, current ownership fence and takeover generation, and authoritative claim time. The claim transition and ownership takeover share one serializable authority boundary: if takeover wins first the stale claim fails; if claim wins first takeover observes `INVOCATION_CLAIMED_UNRESOLVED` and quiesces. It succeeds exactly once and durably persists claimant identity/fence, claim sequence/revision, authoritative claim time, claim digest/integrity, and the complete compared snapshot/vector. Only the caller that performs the successful transition receives ephemeral result `CLAIM_GRANTED_NOW`. Every later call returns already-claimed, conflict, invalid, expired, or equivalent fail-closed disposition and can never recreate `CLAIM_GRANTED_NOW`.

Only the same serialized host event holding `CLAIM_GRANTED_NOW` may invoke the Broker Adapter. Merely reading `INVOCATION_CLAIMED_UNRESOLVED` grants nothing. Duplicate events, restart, takeover, a second host, or a second callback cannot invoke the adapter from persisted state.

In one serialized host event immediately before claim, the host performs the ADR-019 stable double collect, constructs the coherent immutable Admission Snapshot, calls the real V5 `ISWV5RiskContract::ValidateAuthorization(context, authorization, current_binding, decision)` against exactly that binding, and validates all time bounds at authoritative current claim time. It then calls `TryClaimInvocation()` immediately with no queue/defer/scheduling boundary. Interruption before claim loses the snapshot; a later event must collect a new one. Risk expiry at equality fails.

This event is one ADR-020 Increasing Execution Admission operation. It starts before the first `V1` read and completes successfully only when this Claim returns `CLAIM_GRANTED_NOW`. The coherent snapshot point is provisional until completion; successful completion makes it the operation's Policy Admission Linearization Point. Failed validation, expiry, ownership loss, permit conflict, interruption, or failed CAS means no admission completed and the provisional point grants nothing.

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
- exact Submission Permit ID/revision/state/digest;
- authoritative validation clock ID/sequence/time; and
- versioned admission policy identity.

Canonical claim and snapshot integrity use ADR-009 framing. The immutable snapshot digest preimage begins with typed domain `SWV5-SPRINT5-ADMISSION-SNAPSHOT-V1` and contains every vector field, both authoritative collect-clock observations, final claim-time observation, permit binding, and policy/format identity in fixed contract order except its own digest. The complete snapshot appends its digest. The digest proves content identity, not freshness, trust, liveness, or authorization. The Invocation Claim digest preimage begins with `SWV5-SPRINT5-INVOCATION-CLAIM-V1` and contains permit identity/revision/state, complete snapshot/vector digest, claimant/fence/takeover, claim sequence/revision/time, and policy/version except its own digest. Each full record appends its digest; same identity/revision with different content is conflict.

No host or namespace-wide counter is an authoritative safety input. Each sole owner supplies one coherent immutable record plus a mutation-advancing, non-reusable/ABA-resistant, payload-bound stable comparison token. Two complete consecutive equal safety projections establish the ADR-019 provisional snapshot point. If and only if Claim completes, ADR-020 makes that point the successful operation's Policy Admission Linearization Point. Any token/binding mismatch, invalid or missing token, expiry/freshness failure, digest mismatch, bounded instability, persisted replay, or interruption before claim prevents completion.

Ownership/takeover is additionally rechecked by the linearizable Claim operation. Claim also compares exact permit state/revision, snapshot digest, authoritative claim time, and every explicit time-bound validity/liveness requirement. It does not re-prove that every non-time authority token remains physically unchanged after `P`; ADR-020 serializes those mutations relative to `P`. A mutation before `P` is observed or invalidates the pair. A mutation after `P` cannot retroactively revoke a successfully completed operation and governs later authority.

Successful Claim is Admission Operation Completion, exactly-once external-side-effect ownership Claim, and the conservative uncertainty point. It is not a second non-time policy-evaluation linearization point. Crash after Claim but before the broker call is `UNCERTAIN`, not retryable. Later authority changes cannot pretend the attempt never existed; they block new increasing authority while authoritative broker evidence is reconciled.

### Exactly-once counterexample proof

1. Permit P is `COMMITTED_NOT_INVOKED`.
2. Event E1 calls `TryClaimInvocation`, wins the CAS, receives `CLAIM_GRANTED_NOW`, and durably produces `INVOCATION_CLAIMED_UNRESOLVED`.
3. Duplicate E2 compares P and finds it already claimed, so receives no grant and cannot call the adapter.
4. Restart and takeover can load only the persisted claimed state, never E1's ephemeral result, so neither can call the adapter.
5. Claimed state blocks a competing permit/retry until authoritative disposition.

## Consequences

- Coherent stable collect plus same-event claim, not a global counter or permit, closes the final Risk/Hard Kill/trust admission race.
- Exactly one serialized event can enter the adapter for an attempt.
- Availability may be lost after claim-before-call crash; safety is preserved.
- Phase B can define pure DTOs, outcomes, vector validation, and interfaces without broker code.
