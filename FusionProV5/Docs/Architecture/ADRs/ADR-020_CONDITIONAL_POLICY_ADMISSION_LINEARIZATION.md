# ADR-020: Conditional Policy Admission Linearization

## Status

Proposed for Sprint 5 Phase A.4 final independent architecture re-review.

Governance note: this ADR defines **Sprint 5 candidate architecture semantics only**. It grants no Phase B, runtime, broker, production, or live-trading authorization and does not Architecture Lock Production Contract V5.

## Context

ADR-019 establishes a coherent stable-snapshot point during two complete authoritative collects. ADR-014 and ADR-016 require successful Invocation Claim before broker admission, while Producer Trust and Hard Kill policy must also order correctly against concurrent mutation. Treating every mutation physically observed before Claim as an automatic policy veto conflicts with the earlier stable-snapshot point; treating the snapshot alone as completed admission would make an interrupted or failed Claim authoritative. One operation and one conditional ordering model are required.

## Decision

### One Increasing Execution Admission operation

**Increasing Execution Admission** is one logical linearizable operation for one exact Submission Permit, logical request, unique attempt, and normalized payload.

- **Operation start:** immediately before the first authoritative `V1` read in the ADR-019 collection, inside one non-reentrant serialized host event.
- **Operation interval:** from that start until either successful Invocation Claim or a failed/aborted admission result.
- **Admission Operation Completion:** only `TryClaimInvocation()` successfully changing `COMMITTED_NOT_INVOKED -> INVOCATION_CLAIMED_UNRESOLVED` and returning event-local `CLAIM_GRANTED_NOW`.
- **Failed operation:** validation failure, expired deadline, ownership/takeover loss, invalid/conflicting permit, interruption, abort, or failed Claim CAS. No broker admission occurred.

The operation contains the stable double collect, snapshot construction, exact V5 Risk authorization validation, claim-time validity/liveness checks, and Invocation Claim. The successful Claim permits one immediate Broker Adapter call in the same event; the physical call is not a second policy-admission operation.

### Conditional Policy Admission Linearization Point

The stable point established by equal ADR-019 safety projections is a **provisional snapshot point**. If and only if the same uninterrupted Increasing Execution Admission operation later completes successfully, that point becomes the **Policy Admission Linearization Point** `P` of the successful operation.

If the operation fails or aborts, the provisional point grants no authority, has no successful policy effect, and remains at most diagnostic computation. Snapshot construction alone never admits execution.

These terms have distinct fixed meanings:

1. **Policy Admission Linearization Point:** the logical serialization point of a successful increasing-admission operation, located within the coherent ADR-019 stable interval.
2. **Admission Operation Completion:** successful `TryClaimInvocation()` returning `CLAIM_GRANTED_NOW`. Without completion, `P` never becomes effective.
3. **External-Side-Effect Uncertainty Point:** the same successful Invocation Claim. From completion onward, the attempt is potentially externally submitted even if a crash precedes the adapter call.

Claim is therefore the completion and conservative uncertainty boundary, not a second policy-evaluation linearization point. A successful operation may linearize earlier at `P` within its execution interval, as ordinary linearizability permits.

### Concurrent mutation ordering

Every admission-invalidating authority mutation is ordered relative to `P`:

- If it linearizes **before `P`**, the coherent snapshot must contain it or become unstable/invalid. The operation cannot successfully linearize using superseded authority.
- If it linearizes **after `P`**, it is ordered after that successful admission and cannot retroactively revoke or rewrite it. It governs subsequent admissions, permits/attempts, runtime eligibility, and reconciliation/recovery as applicable.
- A provisional point has this effect only if Claim later succeeds. Failed Claim means there was no completed admission to order before the mutation.

This is ordering of overlapping linearizable operations. It is not a global cross-domain lock, a distributed transaction, or a requirement for common storage.

| Authority mutation | Linearizes before `P` | Linearizes after `P` before Claim | After successful Claim |
|---|---|---|---|
| Hard Kill | Blocks increasing admission; snapshot contains the latch or is unstable | Does not retroactively cancel this admission if Claim completes; blocks every later increasing admission | Preserve claimed/possibly external attempt; reconcile; only separately authorized reducing/close-only work |
| Producer Trust revocation | Blocks admission; accepted ingress remains auditable and receives the applicable terminal/blocking disposition | Does not retroactively cancel this admission if Claim completes; blocks later ingress/admissions and retry/new increase | Preserve claimed uncertainty/evidence; post-claim revocation rules |
| Basket state/version | Snapshot must use the new state/version or fail stability | Ordered after this admission; cannot rewrite its bound snapshot | Later lifecycle/reconciliation rules apply |
| Request/request-set revision | Snapshot must use the new state/revision or fail stability | Ordered after this admission | Later request lifecycle applies; no duplicate invocation |
| Account namespace/epoch/mode | Snapshot must use the new observation or fail stability | Ordered after this admission | Subsequent readiness/reconciliation uses the new authority |
| Symbol specification | Snapshot must use the new sequence/specification or fail stability | Ordered after this admission | Future admission uses the new specification |
| Margin/Basket-risk evidence | Snapshot must use the new authority evidence or fail stability | Ordered after this admission | Future admission re-evaluates with new evidence |
| Risk authority/evidence generation | Snapshot must use the new authority/evidence or fail stability | Ordered after this admission | Governs future admission and reconciliation as applicable |

The ordering rule concerns explicit authority mutations. The following are separate mandatory Claim-completion conditions and must still be valid at authoritative claim time:

- Producer Trust `[valid_from, valid_until)`; `claim_time >= valid_until` fails;
- V5 Risk authorization exclusive expiry; equality or later fails;
- permit state/revision and any explicit permit deadline;
- current ownership fence/takeover and lease liveness;
- symbol-specification, margin, Basket-risk, account-observation, and other explicitly freshness-bound deadlines; and
- authoritative clock identity, sequence, and nonregression.

Expiry is not retrospectively ordered after admission as an authority mutation. Failure of any mandatory Claim-time condition means Claim cannot complete and the provisional point never becomes effective.

### Hard Kill compatibility

ADR-006 remains unchanged and authoritative. “While latched, only reconciliation and explicitly authorized risk-reducing or close-only actions are eligible” means an increasing admission whose `P` occurs after the Hard Kill latch is authoritative must fail. ADR-020 permits no bypass:

- Hard Kill before `P` blocks the operation.
- `P` before a concurrent Hard Kill activation orders this one successful admission first, provided every Completion condition passes.
- The later latch blocks all subsequent increasing admission, cannot be cleared or weakened, preserves the already claimed/possibly external attempt, and permits authoritative broker evidence to reconcile.

Counterexample: `V1/V2` establish coherent `H1=not latched` and provisional `P`; `H2=latched` linearizes after `P`; the same uninterrupted operation later wins Claim. Conditional completion makes the operation linearize at `P` before `H2`. `H2` cannot cancel this one attempt but blocks every later increasing admission. If `H2` linearizes before `P`, the pair must contain `H2` or become unstable and no Claim under `H1` may complete.

### Producer Trust compatibility

Producer Trust revoked/superseded before `P` blocks admission, leaves accepted ingress auditable, and selects the applicable terminal/blocking disposition. Revocation after `P` during the same operation does not retroactively revoke that admission if Claim completes; it blocks all later increasing admissions, new producer publication, retry, and new increasing authority while resulting broker evidence remains reconcilable.

Trust validity expiry is different from explicit revocation. The Trust interval must remain valid at Claim under the authoritative claim clock. `claim_time >= valid_until` yields no Claim and no completed admission even when the provisional snapshot point was earlier.

### V5 Risk validation

The real `ISWV5RiskContract::ValidateAuthorization(context, authorization, current_binding, decision)` validates the exact coherent `SWV5_RiskEvaluationInput` binding represented by snapshot `S` and the explicit Claim-time conditions required by V5. It validates the operation that conditionally linearizes at `P`; it does not prove that every independently owned record is physically unchanged at a later wall-clock instant. No such cross-domain freeze is required or claimed. Structural validity, exact binding, snapshot integrity, authoritative time, exclusive authorization expiry, and all specified freshness checks remain fail-closed.

### Invocation Claim and ownership

`TryClaimInvocation()` compares exact permit ID/revision/state, exact snapshot digest, current ownership fence/takeover authority, authoritative claim time, and required explicit time-bound validity/liveness. It does not re-evaluate every non-time authority mutation after `P`; ADR-020 orders those mutations relative to `P`.

Ownership remains special because Invocation Claim and takeover share one serializable Submission Authority boundary. Takeover-first makes Claim fail, so the provisional point has no effect. Claim-first completes admission at `P`, returns `CLAIM_GRANTED_NOW` once, and makes takeover observe claimed uncertainty. A stale owner never receives the grant.

### Permit invalidation

An unclaimed permit is invalidated when the operation cannot establish a valid coherent snapshot; an invalidating mutation is authoritative before `P`; ownership/takeover prevents Claim; a required Claim-time validity/liveness condition fails; the permit is invalid/conflicting; or the operation aborts under policy. A non-time mutation ordered after `P` must not by itself retroactively invalidate the permit for that same uninterrupted operation if Claim otherwise completes. It blocks subsequent authority instead.

The snapshot and provisional point cannot be reused, persisted as invocation authority, moved to another event or host, or restored after restart. A later event begins a new operation and new collect.

### Same-event purpose and crash semantics

The same-event/no-defer rule proves that collection, provisional `P`, validation, and Claim belong to one Increasing Execution Admission operation. It prevents replay, scheduling reuse, restart reuse, and another-event reuse. It does not freeze independent authority owners; ADR-020 orders their concurrent mutations.

Crash before successful Claim means no admission completed and the provisional point has no authority. Crash after Claim but before the adapter call preserves `INVOCATION_CLAIMED_UNRESOLVED`, uncertainty, no re-invocation, no blind retry, and mandatory authoritative reconciliation.

## Consequences

- One logical admission operation has one conditional policy linearization point and one completion/uncertainty boundary.
- Hard Kill and Producer Trust remain fail-closed without treating physical Claim time as a second non-time policy snapshot.
- Phase B can define pure conditional-admission outcomes and concurrent-mutation tables without inventing a lock, counter, transaction, or policy.
- Phase B, runtime, broker implementation, Architecture Lock, and production use remain unauthorized.
