# ADR-019: Coherent Admission Snapshot Protocol

## Status

Proposed for Sprint 5 Phase A.3 independent architecture re-review.

Governance note: this ADR defines **Sprint 5 Candidate Contract semantics only**. It grants no Phase B, runtime, broker, production, or live-trading authorization and does not Architecture Lock Production Contract V5.

## Context

The Phase A.2 independent re-review found one remaining Phase-B-blocking Major: a derived host admission counter was not contractably owned or shared and therefore could not prove that separately owned admission authorities formed one coherent input. Requiring every domain mutation to update one host counter would introduce an unnecessary global authority and would still not make independently read records coherent.

The Admission Version Vector must instead be the authoritative immutable safety snapshot. Each participating authority must provide an immutable, payload-bound comparison token that changes for every safety-relevant mutation and cannot be reused after change. Existing V5 identities, generations, sequences, revisions, fences, and digests are used where available; Sprint 5 candidate records must carry equivalent explicit tokens. No common storage technology is required.

## Decision

### Submission Admission Version Vector

The **Submission Admission Version Vector** is the complete immutable admissibility snapshot for one exact permit, logical request, unique attempt, and normalized payload. It contains the following exact authority evidence in fixed contract order:

| Authority | Sole owner | Stable comparison token | Time-bound? |
|---|---|---|---|
| Ownership authority | Instance Ownership service | complete `SWV5_OwnershipFence`: `ownership_namespace`, `owner`, `lease_version`, `takeover_generation`, `fencing_token_digest` | Yes: current lease must be live |
| Lease liveness | Instance Ownership service | complete `SWV5_InstanceLease` liveness projection: `fence`, `status`, `store_revision`, `heartbeat_sequence`, `clock_id`, `clock_authority`, acquired/heartbeat/expiry clock sequences and times | Yes |
| Producer Trust | Producer Trust Authority | trust-record ID, generation, canonical record digest, status, superseding generation/record, producer component/instance/epoch and scope | Yes: exact validity interval |
| Hard Kill | Risk Governance and independent release authority | complete `SWV5_HardKillState` binding: namespaces, `latch_id`, `latch_generation`, `state`, `release_generation`, release evidence/reference ID/sequence/digest, plus candidate canonical full-state digest | Yes where release evidence has validity |
| Account and mode observation | V5 Risk/account authority source | complete `SWV5_AccountRiskNamespace`, including `account_mode`, `authoritative_source`, `snapshot_epoch`, `snapshot_sequence`, plus candidate canonical full-record observation identity/digest | Yes: observation freshness |
| Basket lifecycle | Basket State Machine | `basket_id`, `state_version`, plus candidate canonical digest of complete `SWV5_BasketLifecycleSnapshot` | No independent wall-clock expiry; binding must remain current |
| Current request and request set | Execution Coordinator plus Fenced Runtime Publication Authority | exact request correlation/attempt/state plus `SWV5_PersistedRequestSetHeader.request_set_digest`, `request_index_revision`, `record_sequence`, and candidate canonical complete-request digest | No independent wall-clock expiry; binding must remain current |
| Symbol specification | Unit System / authoritative specification source | `symbol`, `specification_sequence`, plus candidate canonical digest of complete `SWV5_SymbolUnitSpecification` | Yes: `valid_until` and freshness policy |
| Margin authority | Broker Adapter margin authority | `authority_record_id`, `authority_record_sequence`, `authority_record_digest`, `observation_sequence`, issuing component/source and exact request/account/fence scope | Yes: freshness policy |
| Resulting Basket-risk authority | Risk Gate / Basket-risk authority source | `authority_record_id`, `authority_record_sequence`, `authority_record_digest`, `observation_sequence`, `source_snapshot_id`, `source_snapshot_digest`, and exact Basket/request/account/fence scope | Yes: freshness policy |
| Risk authorization | Risk Gate / Risk Governance | authorization ID, risk-snapshot epoch/sequence, candidate canonical complete-authorization digest and exclusive expiry | Yes: exclusive expiry |
| Normalized request payload | Execution Coordinator using Unit System result | normalization identity, normalized intent identity, symbol-specification sequence, exact correlation/attempt and candidate canonical payload digest | Bound to the time-bound authorities it references |
| Submission Permit | Submission Permit authority | permit ID, revision, state, digest and exact request/attempt/payload binding | Yes where permit policy defines validity |
| Validation clock | Authoritative clock source named by `SWV5_ContractValidationContext` | `clock_id`, `clock_authority`, nonregressing `clock_sequence`, `evaluation_sequence`, and `clock_time` for each collect and final claim evaluation | Yes |
| Policy and format | Version Policy authority | contract name, schema/minimum-compatible versions, admission-policy ID/version and canonical-format ID/version | No; exact compatibility is mandatory |

Every row is contractable only if its owner supplies the record and token as one coherent immutable read. A token must be mutation-advancing, non-reusable/ABA-resistant, scope-bound, and cryptographically or structurally bound to the complete safety payload. A larger token alone does not prove validity. If any owner cannot satisfy these properties, Phase B and runtime admission are blocked; the builder may not invent or repair a token.

Broker-derived and account-derived inputs are compared through their authoritative record identity/generation/digest/observation sequence and freshness, never through naked numeric values. Same-owner heartbeat may leave the ownership-authority fence stable while advancing the separate liveness/store token; a takeover advances ownership authority and invalidates the prior owner.

### Stable double-collect protocol

One serialized host event performs this pure deterministic protocol:

1. Read every authority record and token into complete collection `V1`.
2. Validate every `V1` record structurally and semantically, including namespace, scope, request, attempt, payload, policy, authority source, token/payload integrity, and time bounds.
3. Read every authority record and token again into complete collection `V2`.
4. Validate every `V2` record identically.
5. Compare every safety-relevant identity, version, generation, sequence, revision, fence, digest, status, scope, namespace, request, attempt, and payload binding in `V1` and `V2`.
6. Require both observations to use the same authoritative clock identity/authority and require clock sequences/times to be nonregressing. Per-collect clock readings are observation metadata, not fields required to remain numerically equal.
7. Obtain the authoritative current claim-evaluation time, append the two clock observations and claim-time observation to the final snapshot, and recheck every exclusive expiry, validity interval, and freshness bound.
8. If any record/token is missing or invalid, any safety projection differs, any scope/binding differs, time regresses, or a bound is no longer valid, discard the collection and retry only within a bounded policy; otherwise fail closed.
9. If the complete safety projections are equal, construct immutable coherent Admission Snapshot `S`.

In this ADR, `V1 == V2` means equality of the complete safety projection plus identical scope/request/payload bindings under one nonregressing authoritative clock. It does not mean two platform reads are atomically simultaneous or that their observation timestamps are byte-identical.

If continuous change prevents a stable pair within the bounded attempt policy, the outcome is **NO CLAIM**. Availability loss is acceptable; comparison is never weakened to manufacture stability.

### Linearization and concurrent changes

Because each owner returns token and payload coherently and every safety mutation advances a non-reusable payload-bound token, two complete consecutive equal safety projections establish an **Admission Snapshot Linearization Point** in the stable interval after completion of `V1` and before the first safety-relevant mutation ordered after `V2`. The architecture orders a concurrent authority change either before admission when the pair observes it, or after admission when it commits after that stable point. This is a versioned stable-collect proof, not a distributed transaction.

Example: `V1` sees Trust `T1`, Basket `B1`, and Hard Kill `H1`. Trust commits `T2=REVOKED` before its second authoritative read. The Trust generation/status/digest in `V2` differs, the snapshot is discarded, and no Invocation Claim occurs. The same proof applies to Hard Kill generation, Basket version, specification sequence, account epoch/mode observation, request-set revision, margin authority, Basket-risk authority, Risk authorization, ownership, and every other vector member.

If `V1 == V2` establishes `S`, the real V5 Risk validation passes against exactly `S`, all bounds remain valid, and Invocation Claim succeeds, then a Trust, Hard Kill, or other authority change that begins or commits after the established snapshot point—even if observed physically before the adapter call—is logically ordered after admission. Existing post-claim rules then apply: no second invocation, no new increasing authority, claimed uncertainty is preserved where applicable, and authoritative broker evidence remains admissible for reconciliation. Later revocation cannot erase a potentially external attempt. It never clears Hard Kill or creates new authority.

### Same-event claim and expiry

`S` is evidence for one immediate claim attempt, not a reusable capability. In the same non-reentrant serialized host event that completed the stable collect, the host must:

1. construct `S`;
2. call the real V5 `ISWV5RiskContract::ValidateAuthorization(...)` against the exact current binding represented by `S`;
3. obtain authoritative current claim time and revalidate Producer Trust, Risk exclusive expiry, permit validity, lease liveness, and all freshness/specification bounds; and
4. immediately call `TryClaimInvocation()` with the exact permit ID/revision/state, immutable snapshot digest, current ownership/takeover authority, and authoritative claim time.

There is no queue, defer, scheduling, process, persistence, or restart boundary between validation and claim. Interruption before successful claim destroys invocation authority. A later event must build and validate a new snapshot. Equality at an exclusive expiry fails closed.

Ownership/takeover is additionally rechecked inside the linearizable Invocation Claim operation because Submission Authority and takeover share their serialization boundary. Takeover-first rejects the stale claim; claim-first exposes claimed-unresolved state to takeover. This does not weaken the vector proof.

### Canonical snapshot identity

Canonical encoding uses the frozen ADR-009 UTF-8 and primitive framing rules. The digest preimage begins with typed domain `SWV5-SPRINT5-ADMISSION-SNAPSHOT-V1` and appends every vector field, the two collect clock observations, final claim-evaluation clock observation, permit binding, and policy/format identity in fixed contract order, excluding only the snapshot digest itself. The complete snapshot appends that digest.

The digest proves content identity only. A matching digest does not prove freshness, trust, liveness, or authorization and cannot replace authoritative validation.

### No hidden authority and no persisted replay

The Admission Snapshot Builder/Validator reads authoritative immutable records, validates tokens/scopes, compares complete collections, and constructs evidence. It cannot create Producer Trust, change Hard Kill or Basket, issue Risk authorization, allocate a request sequence, change ownership, create direction, or replace an owner’s validation policy.

An old snapshot may be persisted only for audit and correlation. Restart/takeover loads and reconciles the underlying authorities; a new invocation always builds a new coherent snapshot. Runtime eligibility may remain generally enabled after restart, but every new Invocation Claim requires this protocol. Notifications are acceleration/diagnostic mechanisms only: a missed notification cannot authorize a stale claim after an authoritative token changes.

### Failure dispositions

All of the following yield **NO CLAIM** and no broker invocation:

- `V1 != V2` for any safety projection or binding;
- invalid or missing authority token;
- authority expiry during collection;
- authority expiry or freshness failure before claim;
- no stable pair after bounded attempts;
- interruption after snapshot construction but before claim;
- snapshot/vector digest mismatch;
- replay of a persisted snapshot after restart/takeover; and
- Trust, Hard Kill, Basket, specification, account, request-set, margin, Basket-risk, Risk, ownership, or other token change between collects.

Only a change logically ordered after the established snapshot point and a successful claim follows existing post-claim uncertainty/revocation/reconciliation rules.

## Consequences

- No host-wide or namespace-wide admission counter is an authoritative safety input.
- Coherence depends on explicit owner-supplied, payload-bound, ABA-resistant tokens rather than a fictitious global transaction.
- Phase B can define pure DTOs, stable-token types, comparison outcomes, canonicalization/digest, and a claim interface without choosing a common store or inventing policy.
- Runtime implementation remains unauthorized and must fail closed if any required token or coherent read cannot be implemented.
