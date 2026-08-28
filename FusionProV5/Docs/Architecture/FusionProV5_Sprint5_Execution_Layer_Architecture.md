# Fusion Pro V5 Sprint 5 Phase A.4 — Final Policy Admission Linearization Closure

## Governance Status

| Item | Status |
|---|---|
| Sprint 5 Phase A.4 | **ARCHITECTURE REVIEW GATE CLOSED / PASS** |
| Approved architecture authority | `31e76411829e2f2e6acb24740ddca32b886969e0` |
| Authorized work | Sprint 5 Phase D fake-store/fake-clock persistence/restart reference implementation |
| Authorized architecture baseline | Sprint 4 Architecture |
| Production Contract V5 | Audited and merged; **Architecture Lock not granted** |
| Runtime implementation | **NOT AUTHORIZED** |
| Broker implementation | **NOT AUTHORIZED** |
| Production or live trading | **NOT AUTHORIZED** |
| Phase B | **CLOSED / PASS** at `1366edb25238463c9a76fa78257196dbf4c64e34` |
| Phase C | **CLOSED / PASS** at `55cd230ca222c60cd42dd218efe5e175ba70acd6` |
| Phase D0 | **CLOSED / PASS — ADR-021 AND ADR-022 APPROVED** |
| Phase D | **AUTHORIZED — REFERENCE IMPLEMENTATION ONLY** |
| Next gate | **NEW INDEPENDENT SPRINT 5 PHASE D PERSISTENCE / RESTART REFERENCE AUDIT** |

This document answers: **How can the audited Production Contract V5 become an Execution Layer architecture without coupling broker runtime into the frozen Signal Engine, duplicating requests after a crash, or allowing competing external broker side effects across lease takeover?** It does not authorize or specify how to call a broker API.

The Phase A.3 final independent re-review returned **FAIL** with one Phase-B-blocking Major. Phase A.4 closed that contradiction through one Increasing Execution Admission operation, a conditional Policy Admission Linearization Point, and Claim as its completion/uncertainty boundary. The subsequent Final Independent Phase A.4 Architecture Gate returned **PASS**, with no Critical or Major findings; the Architecture Review Gate is closed. Phase B and Phase C subsequently closed/pass. The New Independent Phase D0 review passed with no findings and approved ADR-021/ADR-022. Phase D authorization is limited to a deterministic fake-store/fake-clock reference implementation and does not authorize real persistence or runtime integration.

## Authorities And Preserved Baselines

This candidate is subordinate to, and reconciled with:

- `FusionProV5_Master_Architecture.md`
- `FusionProV5_Sprint4_Production_Architecture.md`
- `FusionProV5_Contract_Versioning_Policy.md`
- all Production Contract V5 headers under `FusionProV5/ProductionArchitecture/`
- ADR-001 through ADR-008
- ADR-009 through ADR-012 introduced by Phase A and revised through Phase A.4 where safety semantics required it
- ADR-013 through ADR-015 introduced by Phase A.1 and revised through Phase A.4 where safety semantics required it
- ADR-016 through ADR-018 introduced by Phase A.2 and revised through Phase A.4 where required
- ADR-019 Coherent Admission Snapshot Protocol introduced by Phase A.3 and revised by Phase A.4
- ADR-020 Conditional Policy Admission Linearization introduced by Phase A.4
- ADR-021 Physical Store, Compare-And-Set, And Lease Clock introduced by Phase D0 and approved by the independent D0 review
- ADR-022 Genesis Provisioning Authority introduced by Phase D0 and approved by the independent D0 review

Sprint 3.2.1 remains the frozen Signal Engine. `DecisionEngine` remains the sole authority for `BUY`, `SELL`, `WAIT`, and `BLOCKED`. Production Contract V5 remains the merged, audited, unlocked contract authority. Sprint 5 Phase A.4 neither changes those sources nor grants Architecture Lock or Phase B authorization.

The Producer Trust Authority, Host Ingress Ledger, Request Sequence Authority, deterministic request-binding policy, Fenced Runtime Publication Authority, Submission Permit, Increasing Execution Admission operation, Invocation Claim, Admission Version Vector/Gate, and their persistence interfaces are explicitly **Sprint 5 Candidate Contracts — NOT V5 existing authority**. V5 names are used only for capabilities its audited interfaces actually expose.

The preserved dependency direction is:

```text
Market / Indicator Data
  -> Immutable Snapshot
  -> Independent Signal Engines
  -> DecisionEngine
  -> Immutable Signal Ingress Envelope
  -> Separate Execution Layer / EA Host
  -> Future Broker Adapter
  -> Broker
```

`ProductionArchitecture` must not include Signal Engine headers. Any future integration must adapt a published immutable ingress record at the host boundary rather than make Production Contract headers depend on Signal Engine types.

## Architectural Components And Sole Authorities

| Domain | Sole authority / owner | Permitted responsibility | Prohibited responsibility |
|---|---|---|---|
| Directional decision | Frozen `DecisionEngine` | Emit the final decision result | Broker access, Basket mutation, execution reinterpretation |
| Signal ingress | Signal Ingress Adapter at the host boundary | Validate, deduplicate, freshness-check, and translate the published decision envelope | Recompute Trend, Momentum, Price Action, or Fibo; create a direction |
| Producer trust | Future Producer Trust Authority | Authorize producer component/instance/epoch and exact scope | Treat a digest or producer assertion as authority |
| Ingress acceptance | Future Host Ingress Ledger | Durably deduplicate accepted ingress and bind it to one logical request | Store only in memory or alias broker/request identity |
| Logical request sequence | Future Request Sequence Authority | Reserve one namespace-wide monotonic sequence idempotently by logical correlation | Own request lifecycle, producer sequence, or attempt ordinal |
| Runtime orchestration | EA Host | Serialize events, invoke domain boundaries, enforce readiness | Replace domain validation or mutate domain state outside returned decisions |
| Instance ownership | Instance Ownership service | Lease, heartbeat, conflict, takeover, release, fence evidence | Basket or Execution self-election |
| Basket lifecycle | Basket State Machine | Validate and publish Basket state transitions | Infer confirmation from acknowledgement or Signal DTO |
| Pending requests | Execution Coordinator | Own logical request lifecycle, correlation, retry, and confirmation | Broker policy, Risk policy, or directional decision |
| Submission reservation | Future Submission Permit authority | Reserve one exact request/attempt/payload as `COMMITTED_NOT_INVOKED` | Invoke adapter, recreate a claim grant, or migrate a prior-owner permit |
| Broker invocation admission | Future Invocation Claim / Host Admission Gate | Complete the exact coherent ADR-020 operation and grant exactly one event-local `CLAIM_GRANTED_NOW` | Treat Claim as a second non-time policy point or persisted claimed state as invocation authority |
| Units | Unit System | Validate symbol specification and normalize price/volume terms | Infer universal pip/digit rules |
| Risk | Risk Gate / Risk Governance | Evaluate the complete V5 risk envelope and issue bound authorization | Quick-check bypass or signal-score override |
| Platform/broker translation | Broker Adapter | Future platform calls, authoritative broker queries, raw result/event normalization, margin authority | Signal, Basket, Risk, Recovery, or Persistence policy |
| Transaction callback | EA Host | Sole platform callback entry and immutable event capture | Direct callback mutation of multiple domains |
| Persistence | Persistence service | Validate/load/save V5 request/checkpoint records and perform the narrowly scoped restart-watermark publication | Manufacture broker truth, release authority, or general atomicity |
| Runtime publication admission | Future Fenced Runtime Publication Authority | Linearize expected-current/fence checks for complete request-set and checkpoint writes | Own Execution, Basket, Risk, Hard Kill, or Ownership policy |
| Statistics | Statistics service | Validate and accumulate authoritative deal history | Count requests or acknowledgements as trades |
| Recovery/restart | EA Host orchestration using Basket, Persistence, Ownership, Risk, and Execution contracts | Run the fail-closed recovery protocol | Recovery trading algorithm or bypass of another authority |
| Hard Kill | Risk Governance with independent release authority | Enforce latch and validate release provenance | Automatic restart release or execution-issued release |
| Diagnostics | Logs/dashboard/audit sinks | Observe immutable records | Become authority or mutate operational state |

The EA Host is the single production orchestration and mutation coordinator, not a shared-state super-module. Each domain accepts immutable inputs and publishes state only through its owning contract result. The host cannot edit a result locally to simulate a successful domain transition. No host counter is authoritative cross-domain admission evidence: ADR-019 uses owner-supplied stable comparison tokens to build one coherent immutable Admission Snapshot. Sprint 5 candidate authorities do not retroactively become V5 fields or methods.

## Signal DTO Ingress Architecture

### Existing Source Fields

The current frozen source defines `SWV5_DecisionResult` as:

- `header`, an `SWV5_ResultHeader` containing `engine_kind`, `health`, `valid`, `score`, `confidence`, `reason_flags`, `snapshot_sequence`, `history_generation`, `reason_text`, and `validation_error`
- `action`
- `direction`
- `state`
- `blocking_engine`

The upstream immutable `SWV5_SnapshotHeader` already defines `schema_version`, `sequence`, `history_generation`, `execution_mode`, `data_quality_flags`, `symbol`, `timeframe`, and `closed_bar_time`. The ingress boundary must preserve these authoritative producer facts without duplicating them as independently mutable values.

### Candidate Ingress Envelope And Identity Domains

A future pure DTO contract must carry:

| Field group | Required authority |
|---|---|
| Ingress contract | Contract name, schema version, minimum-compatible version, policy ID, canonical-format ID |
| Producer | Producer Trust Authority record/generation, component identity, instance identity, and epoch |
| Source snapshot | Authoritative snapshot schema, sequence, history generation, execution mode, data-quality flags, symbol, timeframe, and closed-bar time |
| Decision | Unmodified `SWV5_DecisionResult` fields listed above |
| Publication | Producer publication clock ID/authority/time and strictly monotonic per-instance/epoch sequence |
| Ingress | Derived ingress identity |
| Integrity | Payload digest over the nonrecursive digest preimage |

Identity domains remain distinct:

- **Snapshot identity:** exact authoritative snapshot tuple above; not recomputed by the consumer.
- **Decision binding:** complete Decision result whose header snapshot sequence/history generation must exactly equal the snapshot tuple.
- **Ingress identity:** canonical identity derived from snapshot, Decision, producer, publication, version, policy, and format facts.
- **Logical Execution request identity:** separately derived from the accepted ingress under ADR-013.
- **Broker identity:** order/deal/position/event/transaction identity populated only in the V5 acknowledgement/evidence phases.

No identity is an alias for another.

### Nonrecursive Canonical Construction

Canonical encoding preserves the V5 fixed-order typed framing model while freezing a distinct Sprint 5 representation. Every field is `<ASCII-name>:<type>:<length>:<value>`. Type tokens are exactly `s` string, `b` boolean, `i` signed integer/enum/datetime, `u` unsigned integer, `d` double, and `x` nested canonical record or explicitly indexed entry. `length` is the unsigned canonical decimal count of UTF-8 octets in `value`, never an MQL-language character count. Input must be a valid Unicode scalar-value sequence; unpaired UTF-16 surrogates and ill-formed UTF-8 fail closed. No BOM and no Unicode normalization are applied, so the exact code-point sequence is authoritative. Empty string is `<name>:s:0:`. Boolean is exactly `0`/`1`. Enum, signed integer, and nonnegative datetime are base-10 with `-` only for a negative signed integer/enum, no `+`, redundant leading zero, or negative zero. Unsigned integer is base-10 without sign or redundant leading zero. Doubles use fixed 16-decimal point notation, reject non-finite values, and normalize negative zero. Arrays carry explicit zero-based indices and are never silently sorted. `H` is SHA-256 over the exact framed UTF-8 octets and emits 64 lowercase hexadecimal characters under policy `SWV5-SHA256-UTF8-V1`. Existing V5 serializers/DTOs are unchanged; Sprint 5 uses its separately identified format rather than inferring length from `StringLen()`.

The fixed dependency direction is:

```text
Source Canonical Body
  -> Ingress Identity Preimage
  -> Derived Ingress Identity
  -> Digest Preimage
  -> Payload Digest
  -> Full DTO
```

1. **Source Canonical Body:** ingress version/policy/format, producer authority/component/instance/epoch, publication clock ID/authority/time and sequence, exact snapshot facts, and exact Decision result. It excludes `ingress_identity` and `payload_digest`.
2. **Ingress Identity Preimage:** domain separator `SWV5-SPRINT5-INGRESS-ID-V1` followed by the canonical Source Body. It excludes `ingress_identity` and `payload_digest`.
3. **Derived Ingress Identity:** versioned deterministic hash of the identity preimage.
4. **Digest Preimage:** domain separator `SWV5-SPRINT5-INGRESS-PAYLOAD-V1`, canonical Source Body, and the derived ingress identity. It excludes only `payload_digest`.
5. **Payload Digest:** versioned deterministic hash of the digest preimage.
6. **Full DTO:** Source Body + ingress identity + payload digest in fixed field order.

Neither identity nor digest can depend on itself. A valid digest proves deterministic content integrity only; it is not producer authority.

The same nonrecursive rule governs future candidate authority records: Producer Trust uses `SWV5-SPRINT5-PRODUCER-TRUST-V1`; ordered Ingress Ledger uses `SWV5-SPRINT5-INGRESS-LEDGER-V1`; Request Sequence Authority uses `SWV5-SPRINT5-REQUEST-SEQUENCE-AUTHORITY-V1`; Submission Permit uses `SWV5-SPRINT5-SUBMISSION-PERMIT-V1`; Admission Vector uses `SWV5-SPRINT5-ADMISSION-VECTOR-V1`; Invocation Claim uses `SWV5-SPRINT5-INVOCATION-CLAIM-V1`; request-set publication proposals use `SWV5-SPRINT5-REQUEST-SET-PUBLICATION-V1`; and checkpoint publication proposals use `SWV5-SPRINT5-CHECKPOINT-PUBLICATION-V1`. Each preimage contains every fixed-order field (and explicit record index for arrays) except its own digest; the full record appends the digest. Permit ID separately derives from `SWV5-SPRINT5-PERMIT-ID-V1`, namespace, policy/version, logical request, and unique attempt. Same derived identity/revision with different content is conflict.

### Freshness Policy

Validation consumes an explicit authoritative context compatible with `SWV5_ContractValidationContext` and a versioned ingress freshness policy identifying required clock ID/authority. `max_age` must be positive and `max_future_skew` nonnegative. Envelope publication clock and evaluation-context clock must exactly match that policy. No validator may call `TimeCurrent()` or another hidden clock.

Fail-closed comparisons are exact:

- reject future publication when `publication_time > evaluation_time + max_future_skew`;
- reject expired publication when `evaluation_time >= publication_time + max_age`;
- reject zero/invalid time, arithmetic overflow, unknown policy/version, or mismatched clock authority.

The expiry boundary is exclusive. Numeric thresholds remain versioned deployment/test inputs; the semantics do not. After restart, a fresh authoritative evaluation context is mandatory. A previously accepted ingress resolves from its durable ledger record and cannot be reaccepted as new even if the replayed envelope is now stale.

### Producer Trust And Publication Sequence Authority

The future pure Producer Trust Authority record contains record contract/policy ID, authority-record ID/generation/digest, issuing authority identity/policy, producer component, producer instance and epoch, authorization status (`AUTHORIZED`, `SUSPENDED`, `SUPERSEDED`, or `REVOKED`), allowed persistence namespace/symbol/timeframe/execution-mode/clock scope, validity interval `[valid_from, valid_until)`, and superseding record/generation. Validation also consumes an independently configured expected issuer/policy/generation trust anchor; no caller boolean is authority. Only `AUTHORIZED` is eligible. Publication must occur within the interval, and the record must still be current at evaluation. Scope mismatch or namespace collision fails closed.

Publication sequence is positive and strictly monotonic per authorized producer instance/epoch: a new identity requires `sequence > durable_high_watermark`; gaps are permitted; zero or lower sequence fails closed. Same-instance reset or regression fails closed. Sequence reset is allowed only through a newly authorized instance/epoch and superseding authority generation. Equal sequence and equal ingress identity resolves idempotently; equal sequence with different content is a conflict. An old or superseded producer cannot regain authority by replaying valid historical bytes. Credential and authority-record storage mechanics remain deployment scope.

Producer Trust remains mandatory after acceptance. Before request materialization/progression creates increasing authority, before Submission Permit creation, and as an authority member of every ADR-019 Admission Snapshot, the record/generation/status/scope/validity must be validated. Startup and takeover revalidate every nonterminal ingress/request origin. Revocation or supersession before request materialization durably selects `TERMINALLY_BLOCKED_TRUST_REVOKED`; the accepted evidence remains audit history and replay cannot resurrect it.

During an ADR-020 Increasing Execution Admission operation, explicit Trust revocation/supersession is ordered against conditional Policy Admission Linearization Point `P`. Revocation before `P` blocks admission and selects the applicable existing V5 disposition. Revocation after `P` does not retroactively revoke that admission if Claim completes, but blocks every later producer publication, increasing admission, permit/attempt, and retry. Trust `[valid_from, valid_until)` remains a mandatory Claim-time condition: equality or later at `valid_until` yields no Claim and no completed admission.

`WAIT` and `BLOCKED` become durable `REJECTED_NO_ENTRY` outcomes and can never create an Execution Intent. `BUY` or `SELL` may only nominate direction and begin eligibility evaluation. The adapter rejects any action/direction mismatch and may deny eligibility but cannot reverse, promote, or reinterpret the Decision.

## Durable Host Ingress Ledger And Request Binding

The Host Ingress Ledger is a **Sprint 5 Candidate Contract — NOT V5 existing authority**. Its independently versioned, fenced, digest-bound header owns persistence namespace, ownership fence, producer authority/instance/epoch, ingress policy, highest accepted publication sequence, canonical membership/binding index, record/previous revision, compaction generation, and ledger digest.

Each record owns ingress identity/sequence, acceptance disposition, deterministic logical request identity, the reservation returned by the separate Request Sequence Authority, authoritative acceptance time, materialization state, terminal disposition, and revision/digest. States are:

- `REJECTED_NO_ENTRY` — valid `WAIT`/`BLOCKED`; terminal; no request permitted.
- `ACCEPTED_REQUEST_PENDING` — directional ingress durably accepted; deterministic request not yet durably found.
- `BOUND_TO_REQUEST` — exact deterministic logical request exists in the V5 pending-request set.
- `TERMINALLY_PROCESSED` — the bound request has a terminal authoritative disposition.
- `TERMINALLY_BLOCKED_TRUST_REVOKED` — accepted evidence is retained, but current trust revoked/superseded before materialization; no request, permit, or claim is allowed.

Evaluation dispositions `NEW`, `DUPLICATE`, `REPLAY_RESOLVED`, and `CONFLICT` do not replace lifecycle state. Compaction must preserve membership, binding, per-producer high-watermark, and generation so an accepted identity cannot become new again.

Logical `correlation_id` is derived as the versioned hash of domain `SWV5-SPRINT5-REQUEST-BINDING-V1`, persistence namespace, request-binding policy ID/version, and accepted ingress identity. The ledger is not a sequence allocator. Exactly one future namespace-wide Request Sequence Authority owns reservation for every logical request origin: signal-derived, separately authorized reduce/close-only, future recovery-origin, and any other authorized Execution origin.

Its linearizable `ReserveRequestSequence(persistence_namespace, logical_correlation_id, current_ownership_fence, expected_allocator_revision, ...)` compares namespace, fence/takeover authority, allocator revision, and policy. An existing correlation returns the same durable sequence; a new correlation advances the namespace high-watermark and binds the new sequence. Gaps are allowed. Retries under the same logical request retain that sequence and use a separate durable attempt ordinal/identity. Stale owner, conflict, or corruption fails closed.

The exact reconstructible initial V5 identity uses `attempt_id = H("SWV5-SPRINT5-ATTEMPT-V1", correlation_id, 0)`, empty parent attempt, the returned reserved sequence, `created_at` equal to acceptance time, and `idempotency_key = H("SWV5-SPRINT5-IDEMPOTENCY-V1", correlation_id)`. Retries allocate a durable ordinal greater than zero and a unique attempt ID under the same correlation.

The crash-safe protocol uses no fictitious cross-domain transaction:

1. CAS-persist `ACCEPTED_REQUEST_PENDING` and the deterministic correlation/acceptance time in the Sprint 5 ledger.
2. Revalidate current Producer Trust; if revoked/superseded, CAS-select `TERMINALLY_BLOCKED_TRUST_REVOKED` and stop.
3. Call `ReserveRequestSequence()` for the deterministic correlation and persist/bind the returned reservation in the ledger.
4. Construct the exact initial request blueprint.
5. Use V5 `LoadPendingRequests()` to locate that exact request; if absent, publish the complete set containing its blueprint only through `CompareAndPublishPendingRequestSet()` under the future Fenced Runtime Publication Authority, then reload/validate it.
6. CAS-advance the ledger to `BOUND_TO_REQUEST` only after the durable request is observed.

Crash after acceptance reconstructs the same correlation. Crash after reservation calls the allocator with that correlation and receives the same reservation; an orphan reservation is a harmless gap, not a second request. Crash after request publication finds the same exact request and converges the ledger. Replaying the Signal after any crash cannot create a second logical request or silently discard accepted intent.

## Single-Writer And Event Serialization Model

The EA Host owns one deterministic mutation stream per ownership namespace. Platform callbacks perform capture only: each callback creates an immutable event envelope and submits it to the host dispatcher. Only the dispatcher may invoke state-changing domain operations.

Events include signal ingress, timer/lease maintenance, platform transaction capture, restart/reconciliation work, and persistence-publication completion. Each accepted event receives a host event sequence under the current ownership fence. Processing is non-reentrant and one event completes its decision/publication boundary before the next can advance the same authoritative state.

Deterministic rules:

1. Startup/reconciliation gates are processed before signal eligibility.
2. While not runtime-eligible, signal events may be rejected or retained only under an approved bounded ingress policy; they cannot create requests.
3. Captured transaction evidence is never dropped because readiness is false. It is serialized into reconciliation processing and may only mutate through the Execution contract.
4. Lease loss immediately removes mutation eligibility. Later events are captured for audit/reconciliation but cannot publish owner-authoritative state.
5. Normal request-set/checkpoint publication uses the future Fenced Runtime Publication Authority to compare expected current identity/revision, store revision, ownership fence/takeover generation, and proposed complete state at the physical durable mutation. Publication failure leaves prior authority unchanged and forces reconciliation/halt.
6. Callback arrival order is diagnostic; authoritative broker transaction sequence, durable identity membership, and contract decisions determine acceptance.
7. Logs, dashboard refreshes, and telemetry are downstream observers and never enter the mutation stream as authority.

## Safe Signal-To-Execution Pipeline

The contract-derived order is:

1. Receive an immutable ingress envelope from the frozen Decision path.
2. Validate ingress version, identity, integrity, source snapshot coherence, symbol/timeframe scope, action/direction, freshness, duplicate membership, and replay high-watermark.
3. Reject `WAIT`/`BLOCKED` as no-entry outcomes; do not construct an Execution Intent.
4. Require the host runtime-enable gate to be current and require HEDGING account mode.
5. Validate the current instance ownership fence and lease liveness. A fence mismatch fails closed.
6. Apply the Hard Kill and recovery/lifecycle eligibility gates. Active Hard Kill permits only separately authorized reducing/close-only work.
7. Obtain a fresh authoritative symbol specification and normalize the proposed operation through `ISWV5UnitSystemContract`.
8. Acquire coherent authoritative account, exposure, Basket, broker-margin, Basket-risk, and Hard Kill inputs under one account namespace/epoch.
9. Build the V5 Execution Intent with logical request identity, normalized terms, expected Basket version, account mode, symbol-specification sequence, and current ownership fence.
10. Evaluate the complete V5 Risk input in its documented order and validate the returned immutable Risk authorization against the current binding.
11. Validate that the proposed operation and resulting Basket transition are eligible. A signal is not Basket evidence.
12. CAS-persist the accepted ingress as `ACCEPTED_REQUEST_PENDING`, revalidate Producer Trust, reserve the namespace-wide logical request sequence idempotently, and bind the reservation in the ledger.
13. Materialize the exact `SWV5_REQUEST_CREATED` / `SWV5_REQUEST_RISK_AUTHORIZED` blueprint and publish the complete set only through `CompareAndPublishPendingRequestSet()`; reload it and converge the ledger to `BOUND_TO_REQUEST`.
14. Create one single-use Sprint 5 Submission Permit reservation in `COMMITTED_NOT_INVOKED` for the exact request, unique attempt, payload, trust, Risk, Hard Kill, and admission bindings. Permit commitment is not broker-invocation authority.
15. Advance the V5 request through `SWV5_REQUEST_SUBMISSION_PENDING` using fenced complete-set publication and reload/validate the result.
16. In the same serialized event that will claim, begin one ADR-020 Increasing Execution Admission operation immediately before the first `V1` read; collect complete authority vectors `V1` and `V2`; require equal safety projections and identical scope/request/payload bindings; and establish the provisional coherent snapshot point.
17. Construct immutable Admission Snapshot `S`; call the real `ISWV5RiskContract::ValidateAuthorization(context, authorization, current_binding, decision)` against exactly `S`; and revalidate every explicit Claim-time expiry/freshness/liveness bound at authoritative current claim time.
18. Immediately call linearizable `TryClaimInvocation()` with the exact permit ID/revision/state, snapshot digest, current ownership/takeover authority, and authoritative claim time. Only successful CAS returning `CLAIM_GRANTED_NOW` completes admission and makes the provisional point effective as `P`. Only that winner may invoke the Broker Adapter in the same event. Persisted claimed state, duplicate events, restart, takeover, or a persisted snapshot grants no invocation authority.
19. Record raw result-retcode evidence and classify it through the versioned Execution policy. Acknowledgement remains pending confirmation.
20. Capture platform transaction/deal evidence, validate correlation, ownership, sequence, symbol-specification and expected Basket version, then call `AcceptTransactionEvidence`.
21. Publish the complete returned pending-request state through fenced request-set publication. Never reconstruct it locally or call V5 `SavePendingRequests()` as an unfenced direct replacement.
22. Only authoritative confirmation may make a Basket transition, update confirmed/residual volume, or make a deal eligible for Statistics.
23. Publish the derived V5 checkpoint separately through fenced checkpoint publication. Statistics consumes validated authoritative deal evidence downstream and remains reconstructible from deal history.

No general multi-domain atomic publication is claimed. Failure or crash between related operations revokes runtime eligibility and enters the ADR-015 dirty/unresolved reconciliation protocol.

## Risk Gate Ordering And Binding

There is no independent quick Risk path. The host must use `ISWV5RiskContract` and preserve this order:

1. Hard Kill latch
2. ownership and authoritative-data availability
3. account Risk and margin capacity, including authoritative additional margin
4. equity floor and Daily Loss
5. aggregate exposure and aggregate notional
6. symbol exposure
7. Basket Risk and authoritative resulting Basket maximum loss
8. projected request Risk

Every consumed numeric value must be finite. Risk evidence and authorization bind the full account namespace/epoch, HEDGING mode, request identity, persistence namespace, ownership fence, Basket ID/state version, normalized direction/price/stop/limit/volume, symbol-specification sequence, limits contract, monetary basis, margin authority, Basket-risk authority, Hard Kill latch/generation, evaluation time, and exclusive expiry. Any mismatch or uncertainty denies authorization. Signal score, confidence, or health can never override Risk.

Earlier Risk evaluation and permit reservation are necessary but insufficient for broker admission. Within one ADR-020 operation, the host establishes ADR-019 snapshot `S` and invokes the existing `ISWV5RiskContract::ValidateAuthorization()` against the complete `SWV5_RiskEvaluationInput` represented by exactly `S`. This validates the operation that conditionally linearizes at `P`; it does not prove that independently owned non-time authority records are physically unchanged at a later wall-clock instant. Structural validity, exact binding, snapshot integrity, exclusive authorization expiry, and specified freshness remain fail-closed. Claim separately compares exact snapshot digest, permit, ownership/takeover, authoritative claim time, and mandatory time/liveness conditions.

## Submission Permit, Invocation Claim, And External-Side-Effect Authority

Submission Permit and Invocation Claim are **Sprint 5 Candidate Contracts — NOT V5 existing authority**. The permit is a durable, fenced, digest-bound, single-use admission reservation for one exact logical request, unique attempt, normalized payload, and authority binding. Linearizable permit creation under current ownership yields `COMMITTED_NOT_INVOKED`; it proves no permit exists for the attempt and no unresolved competing Submission Authority exists for the request. It does **not** authorize adapter invocation.

The permit binds policy/format, ID/revision/digest/time; namespace and ownership fence; account namespace/epoch and HEDGING mode; request/attempt; normalized payload/identity; Basket/version and symbol specification; Producer Trust record/generation/component/instance/epoch/status/validity policy; V5 Risk authorization and authority references; and Hard Kill latch/state/generation. It records reservation-time bindings but is not the later authoritative Admission Snapshot. The claim-time snapshot includes this exact permit and requires every permit-constrained binding still to match.

Submission Authority states are `COMMITTED_NOT_INVOKED`, `INVOCATION_CLAIMED_UNRESOLVED`, `AUTHORITATIVE_SIDE_EFFECT_CONFIRMED`, `AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED`, `AUTHORITATIVE_REJECTED`, `INVALIDATED_BEFORE_CLAIM`, and `CONFLICT_MANUAL_REQUIRED`. They correlate to but never replace V5 Execution lifecycle. A claimed unresolved request is submission-pending and, when restarted/taken over or otherwise unresolved, uses existing `SWV5_REQUEST_RECONCILIATION_REQUIRED` / `SWV5_EXECUTION_PHASE_UNCERTAIN` semantics.

### Durable Invocation Claim And Admission Vector

`TryClaimInvocation(...)` is a mandatory linearizable transition:

```text
COMMITTED_NOT_INVOKED
  -> INVOCATION_CLAIMED_UNRESOLVED
```

It compares expected permit ID/revision/state; exact immutable Admission Snapshot/Vector digest; current ownership fence/takeover authority; authoritative claim time; and mandatory explicit time-bound validity/liveness. Claim and ownership takeover share one serializable authority boundary: takeover-first makes a stale claim fail, while claim-first makes takeover observe and quiesce `INVOCATION_CLAIMED_UNRESOLVED`. It succeeds once and durably persists claimant identity/fence, claim sequence/revision, authoritative claim time, and claim digest/integrity. Only the caller that performs the transition receives the non-durable event-local result `CLAIM_GRANTED_NOW`. Every later caller gets already-claimed, conflict, invalid, expired, or equivalent fail-closed outcome. Persisted claimed state can never recreate the grant.

The immutable Submission Admission Version Vector binds ownership fence and separate lease-liveness/takeover evidence; Producer Trust identity/generation/status/scope/validity; Hard Kill state/generation/release evidence; account namespace/epoch/mode observation; Basket ID/version; current request identity/state/set revision; symbol specification; margin authority identity/generation/digest/freshness; resulting Basket-risk authority identity/generation/digest; V5 Risk authorization ID, candidate canonical authorization digest, and exclusive expiry; request/attempt/payload digest; permit; validation clock ID/sequence/time; and policy identity. The vector, not a host counter, is authoritative safety evidence.

The one ADR-020 Increasing Execution Admission operation starts immediately before the first `V1` read and ends at successful Claim or failed/aborted admission. It executes ADR-019, invokes the real V5 `ISWV5RiskContract::ValidateAuthorization(context, authorization, current_binding, decision)` against exactly the resulting snapshot, and validates every explicit bound at authoritative claim time. Claim rechecks snapshot digest, exact permit, ownership/takeover, claim time, and mandatory validity/liveness. Expiry equality, collect mismatch, validation failure, ownership loss, permit conflict, interruption, or failed CAS means no admission completed.

### Coherent Admission Snapshot Protocol

ADR-019 defines the **Submission Admission Version Vector** as the authoritative immutable admissibility snapshot. Each sole owner must return its complete immutable safety record and stable token in one coherent read. Every token is mutation-advancing, non-reusable/ABA-resistant, scope-bound, and payload-bound; the builder cannot manufacture one.

| Authority | Sole owner | Stable comparison token | Time-bound? |
|---|---|---|---|
| Ownership authority | Instance Ownership | complete `SWV5_OwnershipFence`: namespace, owner, lease version, takeover generation, fencing digest | Lease liveness is time-bound |
| Lease liveness | Instance Ownership | `SWV5_InstanceLease` fence/status/store revision/heartbeat sequence/clock sequences and times | Yes |
| Producer Trust | Producer Trust Authority | record ID, generation, digest, status, supersession, producer scope | Exact validity interval |
| Hard Kill | Risk Governance / release authority | latch ID/generation/state, release generation/reference/sequence/digest, state digest | Release evidence where applicable |
| Account/mode observation | V5 Risk/account authority source | complete `SWV5_AccountRiskNamespace`, snapshot epoch/sequence, candidate canonical full-record observation identity/digest | Freshness-bound |
| Basket | Basket State Machine | Basket ID, state version, candidate canonical complete-lifecycle digest | Must remain current |
| Request/request set | Execution / Fenced Publication | correlation/attempt/state, request-set digest, request-index revision, record sequence, candidate complete-request digest | Must remain current |
| Symbol specification | Unit System / specification source | symbol, specification sequence, candidate canonical complete-specification digest | `valid_until`/freshness |
| Margin authority | Broker Adapter margin authority | authority-record ID/sequence/digest, observation sequence, issuing source and exact scope | Freshness-bound |
| Basket-risk authority | Risk Gate / Basket-risk source | authority-record ID/sequence/digest, observation sequence, source-snapshot ID/digest and exact scope | Freshness-bound |
| Risk authorization | Risk Gate / Risk Governance | authorization ID, risk snapshot epoch/sequence, complete-authorization digest, exclusive expiry | Yes |
| Normalized payload | Execution using Unit result | normalization/intent identity, spec sequence, correlation/attempt, payload digest | Inherits referenced bounds |
| Submission Permit | Permit authority | permit ID/revision/state/digest and exact binding | Policy-bound |
| Validation clock | `SWV5_ContractValidationContext` authority | clock ID/authority and nonregressing clock/evaluation sequences and times for both collects and claim | Yes |
| Policy/format | Version Policy | contract/schema/minimum-compatible versions, policy and canonical-format IDs/versions | Compatibility-bound |

Broker/account evidence uses authoritative record identity, generation/sequence, digest, observation sequence, and freshness rather than naked numeric values. Same-owner heartbeat may keep the ownership-authority fence stable while advancing the separate liveness/store token. Takeover advances ownership authority and invalidates the stale owner. If any authority cannot provide the stated coherent immutable read and token properties, Phase B/runtime admission stops rather than weakening the protocol.

One non-reentrant host event performs the stable double collect:

1. collect complete `V1` and validate every record/token/binding;
2. collect complete `V2` and validate identically;
3. require equality of every safety identity/version/generation/sequence/revision/fence/digest/status plus namespace, scope, request, attempt, permit, and payload binding;
4. require one authoritative clock identity/authority with nonregressing per-collect sequence/time;
5. obtain authoritative current claim time and recheck every validity, exclusive expiry, and freshness bound; and
6. on equality construct immutable snapshot `S`; otherwise discard and bounded-retry or fail closed.

`V1 == V2` means equal complete safety projections and bindings. Observation timestamps themselves may advance and are retained in `S`; the reads are not claimed atomically simultaneous. Equal consecutive complete projections establish a provisional stable snapshot point in the operation interval. If and only if the same operation later completes Claim and returns `CLAIM_GRANTED_NOW`, that provisional point becomes its **Policy Admission Linearization Point** `P`. Failed Claim or abort means the point grants no authority and no admission occurred.

An explicit authority mutation before `P` must be reflected in the coherent snapshot or make the pair unstable. A mutation after `P` is ordered after that successful admission—even if physically before Claim or the adapter call—and cannot retroactively revoke it. It governs all subsequent increasing authority and applicable reconciliation. This is ordinary linearizable concurrent-operation ordering, not a distributed transaction.

Snapshot `S` is not reusable. The same event constructs it, validates the real V5 Risk authorization against its exact binding, checks mandatory Claim-time bounds, claims, and—only for `CLAIM_GRANTED_NOW`—calls the adapter once. There is no queue/defer/scheduling/restart boundary. This binds snapshot and Claim into one operation and prevents replay/reuse; it does not freeze independent authority owners. Interruption before Claim leaves the provisional point ineffective; a later event starts a new operation and collect. Equality at exclusive expiry fails closed.

The snapshot digest uses frozen canonical framing, typed domain `SWV5-SPRINT5-ADMISSION-SNAPSHOT-V1`, and every vector field plus both collect-clock observations, final claim-time observation, permit binding, policy, and format in fixed order, excluding only its own digest. The complete record appends the digest. Digest equality proves content identity only, never freshness, trust, liveness, or authorization.

The Builder/Validator reads, validates, compares, and constructs immutable evidence. It owns no Trust, Hard Kill, Basket, Risk, request sequence, ownership, direction, or domain policy.

### Conditional Policy Admission Linearization

ADR-020 freezes three non-competing concepts:

1. **Policy Admission Linearization Point `P`:** logical policy serialization point of a successful increasing admission, inside the coherent snapshot interval.
2. **Admission Operation Completion:** successful `TryClaimInvocation()` returning `CLAIM_GRANTED_NOW`; without it, provisional `P` has no effect.
3. **External-Side-Effect Uncertainty Point:** the same successful Claim, after which the attempt is potentially externally submitted even if a crash precedes the adapter call.

Claim completes an operation whose successful policy effect conditionally linearizes earlier inside its own interval. Claim is not a second non-time policy evaluation.

| Authority mutation | Linearizes before `P` | Linearizes after `P` before Claim | After successful Claim |
|---|---|---|---|
| Hard Kill | Blocks increasing admission; snapshot contains latch or is unstable | Does not retroactively cancel this admission if Claim completes; blocks later increasing admission | Preserve claimed/possibly external attempt; reconcile; reduction/close only if separately authorized |
| Producer Trust revocation | Blocks; accepted ingress remains auditable with applicable disposition | Does not retroactively cancel if Claim completes; blocks later publication/admission/retry | Preserve uncertainty/evidence; post-claim rules |
| Basket state/version | Snapshot uses new state/version or fails stability | Ordered after this admission | Later lifecycle/reconciliation rules |
| Request/request-set revision | Snapshot uses new state/revision or fails stability | Ordered after this admission | Later lifecycle; no duplicate invocation |
| Account namespace/epoch/mode | Snapshot uses new observation or fails stability | Ordered after this admission | Subsequent readiness/reconciliation |
| Symbol specification | Snapshot uses new generation or fails stability | Ordered after this admission | Future admission uses new specification |
| Margin/Basket-risk evidence | Snapshot uses new evidence or fails stability | Ordered after this admission | Future admission re-evaluates |
| Risk authority/evidence generation | Snapshot uses new authority/evidence or fails stability | Ordered after this admission | Governs future admission/reconciliation |

Explicit time/liveness conditions are different from mutations. At Claim, Producer Trust must remain inside `[valid_from, valid_until)`; V5 Risk authorization must be before exclusive expiry; permit state/revision/deadline must be valid; current ownership/takeover and lease liveness must pass; and specification, margin, Basket-risk, account observation, authoritative clock, and every other expressly freshness-bound deadline must remain valid. Failure means Claim does not complete and provisional `P` grants nothing.

ADR-006 remains unchanged. An increasing operation whose `P` occurs after Hard Kill is authoritative must fail. If coherent `H1=not latched` establishes provisional `P`, concurrent `H2=latched` linearizes after `P`, and the same uninterrupted operation completes Claim, the admission is ordered before `H2`. This is not a bypass: `H2` remains latched, blocks every later increase, preserves the possibly external attempt, and permits authoritative evidence reconciliation. If `H2` is before `P`, the snapshot contains it or is unstable and no Claim under `H1` may complete.

### Exactly-Once Adapter Admission Proof

1. P is `COMMITTED_NOT_INVOKED`.
2. E1 calls `TryClaimInvocation`, wins, receives `CLAIM_GRANTED_NOW`, and persists `INVOCATION_CLAIMED_UNRESOLVED`.
3. Duplicate E2 calls the same operation, observes already-claimed, receives no grant, and cannot invoke.
4. Restart/takeover loads only claimed state, never E1's ephemeral grant, so cannot invoke.
5. No competing permit/retry exists until authoritative disposition.

Only the same serialized event holding `CLAIM_GRANTED_NOW` may call the Broker Adapter. No second callback, event, host, restart, or takeover can call from the claim record.

### Irreversible Boundary And Crash

- Before successful Invocation Claim, broker invocation is forbidden.
- After claim, the attempt is potentially externally submitted even if the process crashes before the actual call.
- Claim-success/crash-before-call is `UNCERTAIN`, not retryable; availability is deliberately sacrificed for safety.
- Absence of callback, elapsed time, reconnect, or locally empty query is not negative evidence.

### Lease Loss And Takeover

Lease loss before Claim prevents the old host from completing admission. A new owner cannot use the old `COMMITTED_NOT_INVOKED` permit; under current authority it invalidates it to `INVALIDATED_BEFORE_CLAIM`, retains it for audit, fully re-evaluates safety, and may create a new attempt/permit only when existing V5 retry/request policy allows. Takeover-first makes the conditional `P` ineffective; Claim-first completes admission at `P` and makes takeover observe claimed uncertainty.

If `INVOCATION_CLAIMED_UNRESOLVED` exists, takeover preserves it, prohibits adapter invocation, competing permit, and retry, and selects V5 reconciliation-required/uncertain disposition until authoritative positive or negative broker evidence resolves it. There is no timeout shortcut.

An unclaimed permit is invalidated when the operation cannot establish a coherent snapshot; an invalidating authority is before `P`; ownership/takeover prevents Claim; mandatory Claim-time validity/liveness fails; the permit is invalid/conflicting; or the operation aborts. A non-time Trust, Hard Kill, Basket, request, account, specification, or Risk-evidence mutation after `P` does not retroactively invalidate the same operation if Claim completes; it blocks later increasing authority. After Claim, no authority change can erase the potentially external attempt. Broker evidence remains admissible and must be reconciled, and only separately authorized V5 reducing/close-only behavior may follow the applicable disposition.

## Execution Request Lifecycle

Sprint 5 reuses the V5 request states and does not create a competing state machine:

```text
CREATED
  -> RISK_AUTHORIZED
  -> SUBMISSION_PENDING
  -> ACKNOWLEDGED
  -> CONFIRMATION_PENDING
  -> CONFIRMED
```

Alternative terminal/disposition states remain `PARTIALLY_CONFIRMED`, `REJECTED`, `EXPIRED`, `RECONCILIATION_REQUIRED`, and `CANCELLED`. V5 lifecycle phases remain `Intent`, `Submission`, `Acknowledgement`, `Authoritative Confirmation`, `Partial Fill`, `Completed`, `Rejected`, and `Uncertain`.

`SWV5_ExecutionRequestIdentity` exists before submission and contains the logical correlation, attempt, parent-attempt, idempotency, and monotonic identity. `SWV5_BrokerExecutionIdentity` is populated only by acknowledgement or authoritative broker evidence. One logical request may have bounded attempts, but every attempt is unique. An uncertain earlier disposition requires reconciliation and forbids blind retry.

## Acknowledgement, Confirmation, And Transaction Ownership

A synchronous accepted retcode, including one reporting a deal, is acknowledgement only. It cannot confirm Basket exposure, close completion, Statistics, or lifecycle state.

The EA Host is the sole owner of the future platform transaction callback. The flow is:

```text
platform callback
  -> immutable raw capture
  -> Broker Adapter normalization to SWV5_TransactionEvidence
  -> serialized host dispatcher
  -> Execution correlation/idempotency validation
  -> complete returned pending-request state
  -> Basket transition eligibility
  -> Statistics deal eligibility
  -> authoritative persistence publication
```

Only transaction/deal evidence correlated to the logical request, broker identity phase, persistence namespace, ownership fence, symbol-specification sequence, and expected Basket version can confirm volume. Duplicate evidence is an idempotent no-op. Conflicting or unknown evidence forces reconciliation. A partial fill updates cumulative and residual volume but is not full confirmation or Basket closure.

## Broker Adapter Boundary

The future Broker Adapter is the only component allowed to translate between V5 DTOs and platform-specific broker facilities. Phase A.4 contains no adapter implementation.

Conceptual side-effect inputs are an already-normalized V5 request, its exact unique current attempt, matching permit/claim/vector, and the event-local `CLAIM_GRANTED_NOW` returned to that same serialized host event. The adapter rejects invocation without exact permit/request/attempt/payload/vector match and that non-replayable result. Reading `INVOCATION_CLAIMED_UNRESOLVED` is insufficient. If a non-time authority mutation linearizes after `P` but before this physical call, the completed admission remains ordered first; the mutation cannot recreate, duplicate, cancel, or erase the attempt and blocks subsequent increasing admissions. The adapter consumes the event-local grant and never creates, renews, reconstructs, or broadens it. Conceptual outputs are raw submission evidence, raw retcode evidence, immutable transaction evidence, independently authoritative margin records, symbol specifications, and complete Broker-owned positions/orders/deals/transactions query snapshots.

The adapter does not classify retcodes by caller assertion and does not own directional decisions, Risk limits/authorization, Basket transitions, Recovery policy, request retry policy, permit issuance, Persistence governance, or Statistics. Execution owns the pending-request query domain. The adapter must never manufacture pending-request authority from broker state. Broker-call duration exceeding lease liveness cannot authorize a competing permit.

## Persistence Boundaries And Crash-Safe Publication

Authoritative persistable state includes:

- versioned record header, persistence namespace, ownership fence, store/CAS revision, record/previous sequence, timestamp, size, and digest
- complete Basket aggregate and lifecycle, state version, recovery counters, residual exposure, and accepted recovery identities
- ordered complete pending-request set and each complete returned pending-request state
- durable accepted transaction/deal identities and fingerprint mappings
- last confirmed request/broker correlation and transaction high-watermark
- Hard Kill state, release reference, and independently sourced release-authority linkage
- reconciliation vector, owner-specific Broker/Execution query high-watermarks, request-set identity, and reconciliation revision
- clean/dirty shutdown evidence

Acknowledgements, logs, UI state, and locally reconstructed summaries are not substitutes.

The exact audited V5 operation boundaries and their limitations are:

- `SavePendingRequests()` independently validates/publishes the complete ordered request set, but its signature does not by itself prove expected-current/fence-safe replacement across stale host/takeover.
- `SaveCheckpoint()` independently validates/publishes one checkpoint, but its signature does not by itself prove expected-current/fence-safe replacement across stale host/takeover.
- `PublishRestartQueryWatermarks()` atomically advances only the two accepted owner-specific query high-watermarks and validated checkpoint publication metadata within that interface's exact proposal.

V5 exposes no general transaction across Basket, pending requests, accepted events, Hard Kill, reconciliation, Statistics, ingress, sequence reservations, or Submission Authority. The Host Ingress Ledger, Request Sequence Authority, Fenced Runtime Publication Authority, and Submission Permit/Invocation Claim journal each require separately versioned/fenced/digest-bound Sprint 5 Candidate contracts.

The future Fenced Runtime Publication Authority is the only normal-runtime host path for complete request-set/checkpoint publication. `CompareAndPublishPendingRequestSet()` compares namespace, expected set revision/digest, expected store/publication revision, ownership fence/takeover generation, and proposed next revision/sequence, complete ordered set, and digest at one physical durable mutation. `CompareAndPublishCheckpoint()` similarly compares expected checkpoint/store revision, prior record sequence, fence/takeover, and proposed checkpoint identity/digest. A larger proposed sequence never overrides stale authority.

Future runtime must not call existing V5 `SavePendingRequests()` or `SaveCheckpoint()` as unfenced direct complete replacements. Phase D must implement the Sprint 5 guard at the physical store/lock boundary while preserving V5 validation. If the store cannot satisfy this, runtime work is blocked pending approved contract revision. The special `PublishRestartQueryWatermarks()` semantics are unchanged.

Before runtime eligibility, the host uses fenced checkpoint publication for `clean_shutdown=false`. Normal related changes publish the complete request set through fenced authority first, reload/validate it, then publish the checkpoint through fenced authority. Statistics remains reconstructible from authoritative deal history and is not claimed inside either operation.

A failed CAS preserves the prior authoritative record. A crash/failure between related writes creates dirty/unresolved state, revokes runtime eligibility, and requires complete restart reconciliation. No later publication may infer an earlier success, manufacture missing state, or reinterpret a partial publication. Only orderly shutdown after all domains converge may publish `clean_shutdown=true`.

Ingress Ledger, Request Sequence Authority, pending-request set, checkpoint, and Submission Permit/Invocation Claim remain separate durable domains. Partial combinations fail readiness and reconcile deterministically; there is no global transaction. The complete pending-request array, accepted identity sets, Hard Kill provenance, ownership authority, ingress/request bindings/reservations, permits/claims, publication revisions, audit-only prior Admission Snapshots, and reconciliation state cannot be reconstructed from the last request, current positions, logs, or counters after restart.

## Fail-Closed Startup And Restart Gate

The host begins runtime-disabled. A clean shutdown is evidence, never a bypass. The mandatory sequence is:

1. Pin the exact supported contract/policy versions; reject incompatible or unknown records without mutation.
2. Establish the intended ownership namespace and HEDGING account mode; unknown, Netting, or changed mode halts readiness.
3. Acquire or recover the instance lease through compare-and-set using the authoritative lease clock. Do not infer ownership from lease absence or missed heartbeat.
4. Load and validate the latest checkpoint, full ordered pending-request set, Sprint 5 Ingress Ledger, Request Sequence Authority reservations, Fenced Runtime Publication revisions, and Submission Permit/Invocation Claim journal. Corrupt/incompatible state remains immutable evidence and causes the contract-defined corruption disposition.
5. Load Hard Kill state. A released historical latch additionally requires the independent authority record; it cannot be reconstructed from the checkpoint.
6. Obtain independently authoritative Broker Adapter snapshots for positions, orders, deals, and transactions, and the Execution-owned pending-request query snapshot.
7. Require the exact V5 closed query union: positions, orders, deals, transactions, and pending requests. Enforce source ownership, digest, freshness, observation sequence, and owner-specific persisted anti-replay high-watermarks.
8. Reconcile namespace, Basket identity/state/version, HEDGING mode, exposure and residual volume, positions/orders, complete request-set identity, latest correlations, transaction watermark, Hard Kill generation, ownership fence, and reconciliation revision.
9. Load and validate current Producer Trust for every nonterminal ingress/request origin. Revoked/superseded pre-materialization work becomes `TERMINALLY_BLOCKED_TRUST_REVOKED`; later states follow ADR-020 ordering before/after conditional `P`, successful Claim completion, and mandatory Claim-time validity.
10. Converge ingress/request bindings and Request Sequence reservations; replay returns the same reservation and never creates a second request.
11. Inspect every permit and Invocation Claim. Invalidate/audit prior-owner unclaimed permits; preserve claimed-unresolved attempts and block invocation, competing permit, increasing execution, and retry.
12. Validate current fenced request-set/checkpoint publication state/revisions. Treat persisted prior Admission Snapshots/Vectors as audit/correlation evidence only; restart never restores them as executable authority or regenerates `CLAIM_GRANTED_NOW`.
13. Resolve uncertain or pending requests from authoritative transaction/deal/request evidence; never retry solely because the process restarted.
14. Validate every accepted-event/ingress identity set, fingerprint/membership policy, producer high-watermark, and compaction generation so replay remains idempotent.
15. Require `SWV5_RESTART_SAFE_TO_RESUME` and the required reconciled Basket state. Every other disposition remains disabled, close-only, halted, or reconciliation-required.
16. Use the specifically scoped V5 `PublishRestartQueryWatermarks()` for its exact reconciled proposal; do not treat it as general publication atomicity.
17. Publish/verify open-session `clean_shutdown=false` through fenced checkpoint authority and revalidate lease liveness, Producer Trust, Hard Kill, account mode, symbol specification, request-set publication, and Risk authority.
18. Only then may the host mark the namespace generally runtime-eligible. Every new Invocation Claim still requires a fresh ADR-019 coherent snapshot. Later Producer Trust revocation/supersession, request/checkpoint publication CAS failure, sequence conflict/corruption, claim conflict, Submission Authority corruption, or any existing V5 revocation condition disables it.

A new namespace with no record must use an explicitly provisioned genesis policy and fresh zero-state reconciliation; absence is not evidence that Hard Kill, exposure, or prior requests are clean. The physical store, platform query implementation, and provisioning credentials remain later-phase decisions.

## Complete Reconciliation Domains

Reconciliation is never positions-only. The mandatory query union is exactly:

- Broker Adapter: positions, orders, deals, transactions
- Execution Coordinator: pending requests

Required identity also includes namespace, account mode, Basket state/version, long/short/net/aggregate/Basket/residual volume, order/position/request counts, latest confirmed correlation and broker identity, transaction watermark, request-set digest/revision, Hard Kill generation, ownership fence, Producer Trust generation/status for nonterminal origins, sequence reservations, publication revisions, permits/claims, audit-only prior Admission Snapshot/vector identity, and reconciliation revision. Incomplete, stale, replayed, mixed-owner, unknown-bit, future-dated, or ambiguous evidence fails closed.

## Basket, Recovery, Hard Kill, And Statistics

### Basket

Basket is the sole authoritative execution-state domain. A Signal DTO is intent input, not Basket state; an acknowledgement is pending evidence, not Basket state. Transitions require the V5 state machine and authoritative confirmation. Partial close updates confirmed and residual exposure. `CLOSING -> IDLE` requires confirmed zero positions, zero orders, zero residual volume, and zero pending requests.

### Recovery

Recovery remains an architecture-level lifecycle boundary only. Basket owns cumulative recovery attempts and current layer separately. Accepted recovery evidence is durable and replay-idempotent. No averaging, grid, martingale, or recovery trading behavior is defined. Recovery cannot bypass Ownership, Persistence, Reconciliation, Units, Risk, or Hard Kill.

### Hard Kill

Hard Kill is a durable latch evaluated first. Restart, signal arrival, lease takeover, or reattachment cannot clear it. While active, only contract-approved reconciliation and separately authorized reducing/close-only work is eligible. Under ADR-020, an increasing admission with `P` after the latch is authoritative must fail; only an overlapping operation whose successful `P` is ordered before concurrent activation may complete, after which the latch blocks every later increase without erasing the claimed attempt. This is concurrency ordering, not a Hard Kill bypass. `RELEASED` requires the V5 independent release-authority record and exact provenance; Persistence or Execution cannot self-issue or reconstruct it.

### Statistics

Statistics is downstream of authoritative confirmed deal evidence. Before mutation it validates finite price, volume, profit, commission, swap, and fee; attribution; account currency; ticket/correlation chain; deal-history completeness; and durable identity disposition. Requests and acknowledgements never count as trades. Duplicate deals are idempotent, and partial closes do not complete Basket statistics while residual exposure remains.

## Instance Ownership And Stale-Host Policy

The ownership key remains account login + broker + server + symbol + strategy ID + Magic. The immutable ownership fence carries owner, ownership namespace, lease version, takeover generation, and fencing digest. Same-owner heartbeat changes liveness and store revision, not the ownership-authority fence. Valid takeover changes the authority generation and invalidates every stale prior-owner binding.

Fence or lease mismatch removes general mutation/publication rights immediately. Before Invocation Claim it forbids broker admission: the old host cannot claim, and the new host invalidates/audits an unclaimed prior-owner permit rather than using it. After claim it cannot revoke or duplicate the potentially external attempt: neither host may invoke from persisted state or mint a competitor, and the unresolved attempt converges through authoritative reconciliation. A stale host may capture immutable broker evidence for reconciliation/audit but cannot accept it into authoritative request/Basket state or publish. No implicit takeover is allowed.

## Account Mode And Unit Boundary

Initial implementation planning remains HEDGING-only. Unknown, Netting, rejected, or changing account mode fails closed across ingress eligibility, Execution, Risk, Persistence, and restart reconciliation. Netting requires a separate ADR and Basket model.

All execution numeric terms cross `ISWV5UnitSystemContract`. Point, tick, pip, price, volume step, stops level, freeze level, tick value, contract size, and currency basis remain distinct. Price uses tick alignment; volume uses the contract-derived operation semantic and volume-step rounding. A changed/stale symbol-specification sequence invalidates normalization, request, retry evidence, and Risk authorization. The generic host contains no hard-coded XAU digits or pip conversion.

## Failure Taxonomy

| Failure class | Required disposition | Authoritative owner |
|---|---|---|
| Invalid/stale/duplicate/replayed Signal input | Discard as execution input; audit; never create request | Signal Ingress |
| Unsupported contract/version or account mode | Block and halt readiness until approved compatibility exists | Version Policy / Host gate |
| Ownership/fence/lease failure | Remove mutation rights; halt/reconcile | Instance Ownership |
| Hard Kill active or release invalid | Block entry; allow only separately authorized reduce/close/reconcile | Risk Governance |
| Persistence corruption/CAS failure | Preserve prior record; halt/reconcile/operator as contract returns | Persistence |
| Incomplete/stale/conflicting reconciliation | Keep runtime disabled; reconcile/halt | Persistence + domain query owners |
| Risk denial or incomplete authority | Discard/expire unsubmitted intent; block request | Risk Gate |
| Broker permanent rejection | Retain terminal rejected evidence; no unchanged retry | Execution |
| Broker transient rejection | Retain terminal evidence for the attempt; any retry requires backoff, full revalidation, a new unique attempt, and a new permit | Execution |
| Unknown broker disposition | Retain pending/uncertain state; reconciliation required; no blind retry | Execution |
| Transaction conflict/out-of-order unknown | Retain evidence; reconciliation/halt as returned | Execution |
| Idempotent duplicate transaction/deal | Successful no-op; preserve authoritative version and counters | Execution / Statistics |
| Partial confirmation | Retain pending with residual exposure; no completion | Execution / Basket |
| Authoritative-state conflict | Halt/error; require reconciliation or operator | Basket / Persistence |
| Ingress accepted; request missing | Retain `ACCEPTED_REQUEST_PENDING`; materialize/locate the same deterministic request; no new identity | Ingress Ledger / Execution |
| Request exists; ingress final binding missing | Locate request by deterministic identity and CAS-converge ledger to `BOUND_TO_REQUEST` | Ingress Ledger / Execution |
| Same producer instance resets/regresses sequence | Reject conflict; halt that producer authority; no request | Producer Trust / Ingress Ledger |
| Unauthorized/superseded producer at initial ingress | Reject; no ledger acceptance or request | Producer Trust Authority |
| Trust revoked before request materialization | Retain accepted evidence; `TERMINALLY_BLOCKED_TRUST_REVOKED`; no request/permit/claim; replay cannot resurrect | Producer Trust / Ingress Ledger |
| Trust revoked after request, before `P` | Block operation; accepted ingress remains auditable; use applicable V5 disposition | Producer Trust / Execution |
| Trust revoked after `P` during same operation | If Claim completes, order revocation after this admission; block later publication/increase/retry; preserve evidence | Producer Trust / Submission Authority |
| Trust revoked after claim | Preserve uncertain claimed attempt/evidence; no new increase or retry until disposition | Producer Trust / Submission Authority / Execution |
| Ingress replay after restart | Resolve durable prior disposition/binding; no second request | Ingress Ledger |
| Permit committed but unclaimed | No broker authority; prior-owner permit is invalidated/audited on takeover; any new attempt requires full policy re-evaluation | Submission Permit / Ownership |
| Duplicate Invocation Claim | Only first CAS caller may receive `CLAIM_GRANTED_NOW`; later call fails closed and cannot invoke | Invocation Claim |
| Invocation Claim after restart or by new owner | Persisted claimed state or old permit grants nothing; no adapter call | Invocation Claim / Ownership |
| Claim succeeds then crash precedes adapter call | `UNCERTAIN`; no re-invocation or retry until authoritative disposition | Invocation Claim / Execution |
| Lease lost before claim | Old host cannot claim; new owner cannot use old permit | Instance Ownership / Submission Authority |
| Takeover sees claimed attempt | Preserve `INVOCATION_CLAIMED_UNRESOLVED`; V5 reconciliation-required/uncertain; block increasing execution/retry | New owner / Execution |
| Hard Kill after claim | Preserve uncertain attempt; block new increase; reconcile; reduce/close only if separately authorized | Risk Governance / Execution |
| Hard Kill activates after `P` before Claim | If Claim completes, order activation after this admission; keep latch active and block every later increase | Risk Governance / Admission Gate |
| Risk/trust/admission mutation before `P` | Snapshot reflects mutation or stable collect fails; no completed admission under old authority | Relevant sole authority / Admission Gate |
| Risk expiry exactly at claim boundary | Exclusive expiry fails current V5 validation and claim; no broker call | Risk / Invocation Claim |
| Sequence reservation orphan | Replay correlation returns same reservation; gap allowed; no second request | Request Sequence Authority |
| Stale complete request-set publication | Expected set/store/fence mismatch fails with no overwrite; runtime disabled | Fenced Runtime Publication Authority |
| Stale checkpoint publication | Expected checkpoint/store/fence mismatch fails even with larger sequence | Fenced Runtime Publication Authority |
| `V1 != V2` or Trust/Hard Kill/Basket/other token mismatch reflected by the collects | Discard snapshot; bounded retry or fail closed; no Claim | Relevant sole authority / Admission Gate |
| Invalid or missing stable authority token | Fail closed; no snapshot, claim, or broker call | Relevant sole authority |
| Authority expires during collect | Discard snapshot; no claim | Relevant time-bound authority |
| Authority expires before claim | Final time-bound validation fails; no claim | Relevant time-bound authority / Invocation Claim |
| No stable pair after bounded attempts | Stop admission; availability loss accepted | Admission Gate |
| Event interrupted after snapshot but before claim | Snapshot authority is lost; later event must recollect | EA Host / Invocation Claim |
| Claim validation/CAS/permit/ownership failure after provisional `P` | Admission operation fails; provisional point grants no authority | Submission Authority / relevant validator |
| Admission Snapshot digest mismatch | Reject as corrupt/conflicting; no claim | Admission Gate / Submission Authority |
| Persisted Admission Snapshot replay | Audit/correlation only; recollect current authorities; no claim from record | Host / Invocation Claim |
| State publication partially completed | Runtime disabled; preserve each prior authority; full restart reconciliation | Persistence / Host gate |
| Queue overload or captured-event loss | Stop admission; mark stream unreliable; halt/reconcile from authoritative queries | EA Host / Broker Adapter |

## Threat And Failure Matrix

`Settled for Phase B` means pure DTO/validator/interface semantics are fixed; it does not authorize Phase B or claim later runtime evidence.

| # | Threat | Authoritative owner | Comparison token | Safe disposition / Phase B semantics | Settled for Phase B | Later dependency |
|---:|---|---|---|---|---|---|
| 1 | Duplicate signal | Ingress Ledger | ingress ID/digest + ledger revision | Resolve prior disposition; no second request | Yes | Phase D storage/compaction |
| 2 | Replay after restart | Ingress Ledger / Execution | ingress binding + deterministic request ID/set revision | Recover prior binding; no second request | Yes | Phase D durable store |
| 3 | Producer restart / sequence reset | Producer Trust | trust generation + producer epoch/publication sequence | Reject same-epoch reset; require newly authorized epoch | Yes | Deployment provisioning |
| 4 | Stale signal | Signal Ingress | snapshot/publication sequence + authoritative times | Reject at exact exclusive boundary | Yes | Policy thresholds |
| 5 | Two EA hosts | Instance Ownership | ownership fence/takeover generation/digest | Conflict/halt; one current fence only | Yes | Phase D CAS technology |
| 6 | Lease takeover | Ownership / Host gate | fence/takeover + separate lease store/heartbeat tokens | Reconcile all domains; invalidate stale owner | Yes | Phase D store/lease implementation |
| 7 | Lease loss during submission | Submission Authority | fence/takeover + permit/claim revision | Pre-claim no call; post-claim uncertain/no duplicate | Yes | Phase D journal; Phase F evidence |
| 8 | Duplicate callback | Execution | broker event/transaction identity + accepted-set revision | Durable idempotent no-op | Yes | Phase C fixtures |
| 9 | Out-of-order callback | Execution | transaction sequence/watermark | Apply V5 policy once or reconcile | Yes | Phase F broker ordering profile |
| 10 | Partial fill | Execution / Basket | request-set digest/index revision/record sequence + Basket state version | Persist cumulative/residual; no completion | Yes | Phase E integration fixtures |
| 11 | Acknowledgement without confirmation | Execution | request-set digest/index revision/record sequence + evidence identity | Remain confirmation-pending; no Basket/Statistics mutation | Yes | Phase C fixtures |
| 12 | Unknown broker disposition | Execution / Invocation Claim | claim revision + broker evidence/query snapshot tokens | `UNCERTAIN`; no retry | Yes | Phase F negative-evidence policy |
| 13 | Crash before broker call | Invocation Claim | permit/claim revision + event-local grant | Before claim no authority; after claim uncertain/no re-invocation | Yes | Phase D journal; Phase F evidence |
| 14 | Crash after broker call | Execution / Invocation Claim | claim revision + broker evidence identity | Claimed unresolved until reconciliation | Yes | Phase F broker evidence |
| 15 | Restart with pending request | Host / Persistence / Execution | checkpoint/set/store/query revisions | Reconcile; no restored snapshot or regenerated grant | Yes | Phase D reference implementation |
| 16 | Dirty shutdown | Host / Persistence | checkpoint record/store revision + clean flag | Full restart gate | Yes | Phase D crash tests |
| 17 | Corrupt persistence | Persistence | header/digest/store revision | Preserve; contract disposition; no self-heal | Yes | Phase D corruption tests |
| 18 | Hard Kill during pending/admission | Risk Governance / Admission Gate / Execution | latch ID/generation/state/release digest | Before `P`: blocks increase. After `P` before Claim: ordered after this admission only if Claim completes; explicit Claim-time liveness still mandatory. Post-Claim: preserve uncertainty/evidence, block later increase, reduction/close only if separately authorized | Yes | Phase B/C ordering fixtures; Phase E integration |
| 19 | Historical RELEASED Hard Kill without provenance | Risk Governance | latch/release generation + release-authority reference/digest | Reject release; remain disabled/latched | Yes | Deployment authority storage |
| 20 | Broker reconnect | Broker Adapter / Execution | authoritative query observation sequence/digest | Preserve uncertainty; refresh/reconcile | Yes | Phase F profile |
| 21 | Incomplete broker query set | Broker Adapter / Persistence | query-set mask/identity/sequence/digest | Runtime disabled; fail reconciliation | Yes | Phase F query implementation |
| 22 | Missing Execution pending-request query | Execution / Persistence | pending-query identity/sequence/digest | Runtime disabled; fail reconciliation | Yes | Phase D/E implementation |
| 23 | Replayed query snapshot | Persistence | owner-specific observation sequence/high-watermark | Reject replay | Yes | Existing V5 / Phase D |
| 24 | Non-finite broker data | Receiving V5 domain | evidence identity/digest | Reject before mutation | Yes | Phase E/F fixtures |
| 25 | Unit mismatch | Unit System | specification sequence/digest + normalization identity | Invalidate normalization, Risk, permit, request | Yes | Phase E/F fixtures |
| 26 | Account-mode change | V5 Risk/account authority source | complete account namespace including mode/source/epoch/sequence + candidate canonical observation identity/digest | Before `P`: new observation is reflected or collect is unstable. After `P`: ordered after this admission only if Claim completes; halt subsequent non-HEDGING runtime. Explicit Claim-time bounds remain mandatory | Yes | Existing V5 / Phase C account observation |
| 27 | Persistence CAS failure | Publication / Host gate | expected store/publication revision + fence | Preserve prior record; disable/reconcile | Yes | Phase D technology |
| 28 | Statistics replay | Statistics | durable deal identity membership/revision | Idempotent no-op; never double-count | Yes | Phase E fixtures |
| 29 | Genesis/no-record startup | Operations / Risk / Host gate | provisioned genesis identity/version/digest | No assume-clean; reconcile zero state | Yes | Phase D provisioning implementation |
| 30 | Queue overload/event loss | EA Host / Broker Adapter | host event sequence + reliability generation | Stop admission; authoritative reconciliation | Yes | Phase C queue implementation |
| 31 | Duplicate orchestration event after claim | Invocation Claim | permit/claim revision/state/digest | Already-claimed; no adapter invocation | Yes | Phase C deterministic fixtures |
| 32 | Restart after claim before broker call | Host / Invocation Claim | claim revision/state/digest | Load uncertain only; never regenerate grant | Yes | Phase D crash fixtures |
| 33 | Producer Trust revoked after acceptance | Producer Trust / Ledger / Execution | trust record ID/generation/status/supersession/digest/validity | Before `P`: blocks. After `P` before Claim: ordered after this admission only if Claim completes; Trust interval must still be valid at Claim. Post-Claim: preserve uncertainty/evidence and block later increase/retry | Yes | Phase B/C trust-ordering fixtures and authority store |
| 34 | Two producer epochs allocate concurrently | Request Sequence Authority | namespace allocator revision + reservation digest | Unique monotonic idempotent reservation | Yes | Phase D allocator store |
| 35 | Stale host complete-set overwrite | Fenced Runtime Publication | set/store revision + fence + set digest | Mismatch; no write | Yes | Phase D physical CAS proof |
| 36 | Stale host checkpoint overwrite | Fenced Runtime Publication | checkpoint/store revision + fence + digest | Mismatch; no write | Yes | Phase D physical CAS proof |
| 37 | Risk/Hard Kill/trust change between permit and Claim | Relevant sole authorities / Admission Gate | Risk auth digest/expiry + Hard Kill generation/digest + Trust generation/status/digest | Before `P`: reflected/unstable and old authority cannot admit. After `P` before Claim: ordered after only if Claim completes. Claim-time expiry/liveness always mandatory. Post-Claim: preserve attempt and block later increase | Yes | Phase B/C conditional-linearization fixtures; Phase E integration |
| 38 | Invocation Claim race between events/hosts | Invocation Claim / Ownership | permit/claim revision + fence/takeover generation | One CAS winner gets event-local grant | Yes | Phase C/D concurrency fixtures |
| 39 | Authority changes between Admission Collect 1 and Collect 2 | Relevant sole authority / Admission Gate | the changed row's payload-bound stable token | Mutation before chosen `P`: reflected or `V1 != V2`. Mutation after `P` during the operation: ordered later only if Claim completes. Claim-time expiry/liveness remains mandatory. Failed Claim leaves no admission | Yes | Phase B stable-collect validator; Phase C ordering fixtures |
| 40 | Stale Admission Snapshot replay after restart | Host / Invocation Claim | snapshot digest plus permit/claim state and current owner tokens | Audit only; new same-event collect required; no claim from persisted snapshot | Yes | Phase D restart fixtures |
| 41 | Snapshot becomes time-expired before Invocation Claim | Time-bound authority / Invocation Claim | authoritative claim clock + included exclusive expiry/freshness bounds | Expiry is not a post-`P` mutation: Claim-time bound fails, equality at exclusive expiry fails, operation does not complete, and post-Claim rules never begin | Yes | Phase B boundary tables; Phase C clock fixtures |

## Observability And Traceability

Every audit event must carry, where applicable: ingress identity and Producer Trust record/generation/status; source snapshot sequence/history generation/symbol/timeframe; host event sequence; persistence namespace and Basket ID; ownership fence lease/takeover generation; request-sequence reservation/allocator revision; logical correlation/attempt/idempotency identity; lifecycle phase/request state/set revision; permit/claim ID/state/revision; Admission Snapshot/vector digest and collect/claim clock observations; broker order/deal/position/event/transaction identity; Risk authorization and Hard Kill latch/generation; symbol-specification sequence; Basket state/version; accepted-event index revision; checkpoint record/store/reconciliation revisions; authoritative timestamp/source; and reason/disposition.

Logs and dashboard DTOs are read-only projections. Log presence, ordering, or text is never accepted as confirmation, idempotency membership, release authority, checkpoint publication, or broker truth.

## Formal Architecture Invariants

1. The Sprint 3.2.1 Signal Engine remains frozen and broker-independent.
2. `DecisionEngine` remains the sole directional decision authority.
3. The EA Host cannot turn `WAIT` or `BLOCKED` into an entry or reverse `BUY`/`SELL`.
4. The EA Host owns runtime orchestration, not Signal interpretation or domain policy.
5. Broker Adapter cannot own Signal, Risk, Basket, Recovery, or Persistence policy.
6. Acknowledgement is never authoritative trade or Basket confirmation.
7. Uncertain broker disposition prohibits blind retry.
8. Duplicate transaction/deal evidence is idempotent and cannot mutate twice.
9. Authoritative mutation is single-writer and serialized per ownership namespace.
10. Startup and restart begin fail-closed and runtime-disabled.
11. Incomplete, stale, replayed, or conflicting reconciliation cannot enable execution.
12. Hard Kill cannot be cleared by restart, takeover, or signal arrival.
13. Risk rejection cannot be overridden by score, confidence, host, or adapter.
14. Persistence cannot self-heal corrupted authority or manufacture broker/release truth.
15. Unit normalization is centralized through the approved V5 Unit contract.
16. `ProductionArchitecture` cannot include Signal Engine headers directly.
17. Sprint 5 Phase A.4 authorizes no runtime code, broker API, or Phase B implementation.
18. Every authoritative state change is returned by its owning contract and published through that contract's actual operation boundary before a dependent action; no general V5 multi-domain atomicity is assumed.
19. A stale ownership fence cannot mutate/publish authoritative state or claim invocation; an unclaimed permit cannot migrate, and claimed state can never regenerate invocation authority.
20. Signal, logical request, broker execution, Basket, and persistence identities remain distinct and explicitly correlated.
21. Canonical ingress identity and payload digest use nonrecursive, domain-separated preimages.
22. A digest does not establish producer trust; current independent Producer Trust Authority is mandatory.
23. Producer publication sequence is monotonic per authorized instance/epoch; reset requires a newly authorized epoch.
24. Durable ingress acceptance plus one namespace-wide Request Sequence Authority resolves replay to one deterministic logical request and one reserved sequence across crashes.
25. Attempt identity is unique and never aliases logical request or ingress identity.
26. Permit commitment yields `COMMITTED_NOT_INVOKED` reservation only; it is never adapter-invocation authority.
27. Only the serialized event receiving `CLAIM_GRANTED_NOW` from the one successful `TryClaimInvocation()` transition may invoke the adapter.
28. Persisted `INVOCATION_CLAIMED_UNRESOLVED`, duplicate event, restart, takeover, or second host can never regenerate invocation authority.
29. Successful Invocation Claim is the conservative irreversible boundary; crash-after-claim-before-call is uncertain and not retryable.
30. Increasing admission requires one ADR-019 coherent immutable Admission Snapshot and real V5 `ISWV5RiskContract::ValidateAuthorization()` against exactly that binding; successful Claim conditionally linearizes the completed operation at snapshot point `P` under ADR-020.
31. Producer Trust is validated before materialization/progression, permit, and as part of snapshot authority; explicit revocation is ordered against `P`, while Trust validity remains mandatory at Claim and revocation never creates or resurrects increasing authority.
32. All logical request origins use one fenced, durable, idempotent namespace-wide sequence reservation authority; the Ingress Ledger is not an allocator.
33. Future normal complete request-set and checkpoint writes use the Fenced Runtime Publication Authority; V5 save methods are never treated as sufficient cross-owner guards by themselves.
34. Ingress, sequence, request set, checkpoint, and Submission Authority are separate durable domains; no fictitious global transaction exists.
35. Every admission-invalidating authority supplies a coherent immutable record and mutation-advancing, non-reusable/ABA-resistant, payload-bound stable token; no host/global counter proves cross-domain safety.
36. Takeover cannot invoke a prior claim or mint a competing permit/retry while a claimed unresolved attempt exists.
37. An increasing admission may complete only from one ADR-019 coherent snapshot, and successful completion conditionally linearizes at that snapshot's ADR-020 Policy Admission Linearization Point `P`. Any invalidating mutation before `P` is reflected or causes fail-closed instability. A mutation after `P` cannot retroactively revoke the completed admission but governs all subsequent increasing authority. Current ownership/takeover and explicit Claim-time expiry, freshness, permit, and lease-liveness requirements remain mandatory at successful Invocation Claim.
38. Queue overload or event loss revokes admission and requires authoritative reconciliation.
39. Two consecutive complete equal safety projections establish a provisional snapshot point; only successful Claim makes it the completed operation's Policy Admission Linearization Point, without claiming a distributed transaction.
40. An Admission Snapshot is usable only for immediate validation and claim in the same serialized event; interruption, defer, restart, or replay requires a new collect.
41. Any missing/invalid token, collect mismatch, digest mismatch, or time-bound failure yields no claim; equality at exclusive expiry fails closed.

## OPEN ARCHITECTURE QUESTIONS

| Question | Why it matters | Blocking? | Proposed ADR owner | Blocks phase |
|---|---|---|---|---|
| Which physical store/lock technology can represent the required durable compare-and-set, atomic publication, crash consistency, and authoritative lease clock on MT5? | Resolved and independently approved by ADR-021 as the SQLite/MQL5 common-folder candidate; later real-platform evidence remains required. | D0 gate closed | Persistence architecture owner | Phase D |
| What versioned broker/platform retcode table and transaction-order profile applies to each supported terminal/broker build? | Adapter classification and ordering cannot be guessed. | Blocking | Broker Adapter owner | Phase F |
| What concrete host queue durability and capacity policy preserves captured transaction evidence during overload or process failure? | Closed by the audited Phase C deterministic orchestration package. | Closed | EA Host owner | Phase C |
| What deployment authority provisions a new namespace's genesis Hard Kill/checkpoint state? | Resolved and independently approved by ADR-022 as a separate Operator/Deployment Genesis Provisioning Authority. | D0 gate closed | Operations/Risk Governance owner | Phase D |
| What broker/build-specific negative-evidence horizon and complete proof rule establishes that a claimed attempt had no side effect? | Architecture forbids timeout-as-proof, but broker evidence behavior is deployment-specific. | Blocking | Broker Adapter / Verification authority | Phase F |
| What exact Risk thresholds and trading-day configuration apply to a deployment? | Contracts define validation, not deployment values. | Nonblocking for pure contracts | Risk Governance owner | Phase E/F deployment |
| Where are Producer Trust, Hard Kill release, and operator credentials stored and rotated? | Trust semantics are fixed, but secret mechanics are deployment concerns. | Nonblocking for pure contracts | Security/Operations owner | Production deployment |
| What broker-specific Hedging fixtures and evidence threshold permit a Demo adapter to pass independent audit? | Architecture alone cannot prove broker behavior. | Blocking | Verification authority | Phase F/G |

Phase B required no new safety decision: ADR-009 and ADR-013 through ADR-020 fix canonical construction, continuing trust, durable replay/binding, namespace-wide sequence reservation, fenced publication, permit reservation, exactly-once claim, stable authority tokens, coherent double collect, conditional policy linearization, concurrent mutation ordering, expiry, and final snapshot semantics. Phase C is closed/pass. ADR-021 and ADR-022 provide the approved Phase D physical-store/clock and genesis decisions without changing those semantics. The D0 gate is closed/pass. Remaining questions concern later real-platform evidence, Phase F broker profiles/negative evidence/evidence thresholds, or deployment values/credentials. No unresolved question permits an implementation phase to weaken or bypass V5.

## Proposed Sprint 5 Implementation Phases

| Phase | Scope | Entry gate | Exit gate |
|---|---|---|---|
| A.4 | Final policy-admission linearization correction and ADRs only | Phase A.3 independent re-review's one remaining Major | Final independent re-review closes all Critical/Major architecture gaps |
| B | Pure ingress, Producer Trust, Ledger, Request Sequence, Fenced Publication, Permit, conditional Increasing Execution Admission outcome, Invocation Claim, stable-authority token, Admission Vector/Snapshot DTOs/interfaces/validators; no broker API | Phase A.4 independently approved and Phase B separately authorized | Compile/static isolation; deterministic concurrent-mutation/expiry tables; no runtime dependency or new safety decision |
| C | Deterministic single-writer reference coordinator with fake broker only | Phase B contracts approved; queue policy resolved | Event-order, duplicate, replay, uncertainty, partial-fill, and lease-loss fixtures pass |
| D | Persistence/restart reference implementation against a fake platform/store | Store/genesis ADRs approved | Crash/CAS/corruption/full-query/restart tests pass; no MT5 broker calls |
| E | Integrated V5 Risk, Basket, transaction, Hard Kill, Statistics, and recovery-boundary fixtures | Phases C/D pass; deployment Risk policy approved | Full positive/negative/cross-domain deterministic suite passes fail-closed |
| F | MT5 Demo Broker Adapter and Strategy Tester only | Broker profiles/retcodes accepted; independent safety authorization | Demo/tester compile and broker-specific evidence pass; no live chart/trading |
| G | Reproducible integration evidence and independent audit | Exact source freeze; all earlier gates pass | Immutable evidence, provenance, full audit, explicit go/no-go recommendation |

No phase authorizes live trading. Any production or live authorization requires a separate, explicit post-audit decision.

### Phase B Contractability Test

**YES:** after independent approval and separate authorization, a Phase B developer can implement only canonical ingress DTOs; Producer Trust, Ingress Ledger, Request Sequence Authority, deterministic request-binding, Fenced Runtime Publication, Submission Permit, stable-authority token and Admission Version Vector/Snapshot DTOs, stable double-collect validator, snapshot canonicalization/digest, conditional policy-admission result, concurrent-mutation dispositions, exact Claim-time validity/liveness outcomes, Invocation Claim consuming the exact snapshot, and pure orchestration/state interfaces without inventing another policy point, global/cross-domain lock, admission counter, distributed transaction, Hard Kill rule, Trust rule, mutation ordering, or expiry rule. Physical queue/store/lock technology, broker-specific evidence, deployment values, and credentials remain correctly deferred to later phases.

## Acceptance Criteria And Traceability

### Phase A.4 Independent Re-review Closure Matrix

| Finding | Closure mechanism | Candidate status |
|---|---|---|
| NEW CRITICAL-1 no durable exactly-once adapter invocation admission | One durable claim CAS plus non-replayable event-local `CLAIM_GRANTED_NOW`; persisted state/restart/takeover cannot invoke | Closed for re-review |
| MAJOR Producer Trust revocation after durable acceptance | Continuing revalidation and exact before-request, before-claim, after-claim dispositions | Closed for re-review |
| MAJOR stale complete pending-request replacement | ADR-018 expected-current/fence/store linearizable request-set publication | Closed for re-review |
| MAJOR final Risk/admission race from unowned cross-domain counter | ADR-019 owner-supplied stable tokens, complete double collect, coherent snapshot linearization, real V5 validation, same-event claim, and claim-time expiry checks | Closed for re-review |
| MAJOR inconsistent policy-admission linearization | ADR-020 one Increasing Execution Admission operation, conditional `P`, Claim completion/uncertainty, explicit mutation ordering, and mandatory Claim-time bounds | Closed for re-review |
| NEW MAJOR no sole request-sequence owner | ADR-017 one namespace-wide fenced idempotent reservation authority for every origin | Closed for re-review |
| MINOR canonical primitive precision | Strict UTF-8 octet length, Unicode validity/no-normalization, and exact primitive lexical tokens | Closed for re-review |

| Criterion | Architecture location |
|---|---|
| Every V5 authority has one runtime owner; no dual mutation owner | Architectural Components And Sole Authorities |
| Signal ingress and no competing direction are defined | Signal DTO Ingress Architecture |
| Canonical ingress construction, freshness, and producer trust are nonrecursive and deterministic | Nonrecursive Canonical Construction; Freshness Policy; Producer Trust And Publication Sequence Authority |
| Replay after restart binds to one logical request | Durable Host Ingress Ledger And Request Binding |
| Host orchestration and serialization are deterministic | Single-Writer And Event Serialization Model |
| Contract-safe end-to-end order is defined | Safe Signal-To-Execution Pipeline |
| V5 Risk ordering/binding has no bypass | Risk Gate Ordering And Binding |
| Existing request states and identity phases are preserved | Execution Request Lifecycle |
| Broker and callback boundaries are explicit | Broker Adapter Boundary; Acknowledgement, Confirmation, And Transaction Ownership |
| External submission has one durable claim, event-local grant, final admission vector, and takeover quiescence | Submission Permit, Invocation Claim, And External-Side-Effect Authority |
| Persistence claims match exact V5 operations and crash recovery | Persistence Boundaries And Crash-Safe Publication; Fail-Closed Startup And Restart Gate |
| Hard Kill, Recovery, Basket, Statistics, ownership, mode, and Units retain V5 authority | Corresponding domain sections |
| Failure taxonomy and threat matrix exist | Failure Taxonomy; Threat And Failure Matrix |
| Formal invariants and later phase gates exist | Formal Architecture Invariants; Proposed Sprint 5 Implementation Phases |
| No runtime API/source change or hidden approval is granted | Governance Status; Out Of Scope |

## Out Of Scope

Phase A.4 explicitly excludes:

- `OrderSend`, `OrderSendAsync`, `CTrade`, or any trade call
- a real Broker Adapter or live `OnTradeTransaction` implementation
- order placement, position changes, or stop-loss/take-profit changes
- production persistence, filesystem, database, lease, or lock implementation
- recovery trading, grid, averaging, martingale, or hedging logic
- Signal Engine or `DecisionEngine` changes
- V3S integration, optimization, or parameter tuning
- Architecture Lock, runtime authorization, production readiness, production authorization, or live-trading authorization
- Phase B implementation or authorization

## V3S Boundary

V3S remains an independent Research Lab. Its M5 logic, experiments, and discoveries are not Sprint 5 inputs and cannot authorize M15 execution. Any future hypothesis must complete the separate V3S validation and formal Fusion adoption process before it can become a reviewed Signal Engine change. Phase A.4 creates no V3S dependency.

## Review Recommendation

The Final Independent Sprint 5 Phase A.4 Architecture Gate is **CLOSED / PASS** at `31e76411829e2f2e6acb24740ddca32b886969e0`; Phase B is **CLOSED / PASS** at `1366edb25238463c9a76fa78257196dbf4c64e34`; and Phase C is **CLOSED / PASS** at `55cd230ca222c60cd42dd218efe5e175ba70acd6`. The New Independent Phase D0 review returned **PASS — Critical NONE / Major NONE / Minor NONE** and approved ADR-021/ADR-022. Phase D is authorized only for fake-store/fake-clock persistence/restart reference implementation. Broker implementation, real persistence/platform integration, MT5, Architecture Lock, merge to main, production, and live trading remain not granted.
