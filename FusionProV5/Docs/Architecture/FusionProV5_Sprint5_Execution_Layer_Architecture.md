# Fusion Pro V5 Sprint 5 Phase A.1 — Execution Layer Architecture Safety Closure

## Governance Status

| Item | Status |
|---|---|
| Sprint 5 Phase A.1 | **ARCHITECTURE SAFETY CLOSURE CANDIDATE / IN REVIEW** |
| Authorized work | Architecture and ADR documentation only |
| Authorized architecture baseline | Sprint 4 Architecture |
| Production Contract V5 | Audited and merged; **Architecture Lock not granted** |
| Runtime implementation | **NOT AUTHORIZED** |
| Broker implementation | **NOT AUTHORIZED** |
| Production or live trading | **NOT AUTHORIZED** |
| Phase B | **NOT AUTHORIZED** |
| Next gate | New Independent Sprint 5 Architecture Re-review |

This document answers: **How can the audited Production Contract V5 become an Execution Layer architecture without coupling broker runtime into the frozen Signal Engine, duplicating requests after a crash, or allowing competing external broker side effects across lease takeover?** It does not authorize or specify how to call a broker API.

The initial Phase A independent review returned **FAIL / NOT READY FOR PHASE B** with one Critical and six Major findings. Phase A.1 closes those findings as architecture proposals for a new independent re-review; it does not self-approve them.

## Authorities And Preserved Baselines

This candidate is subordinate to, and reconciled with:

- `FusionProV5_Master_Architecture.md`
- `FusionProV5_Sprint4_Production_Architecture.md`
- `FusionProV5_Contract_Versioning_Policy.md`
- all Production Contract V5 headers under `FusionProV5/ProductionArchitecture/`
- ADR-001 through ADR-008
- ADR-009 through ADR-012 introduced by Phase A and revised where required by Phase A.1
- ADR-013 through ADR-015 introduced by Phase A.1

Sprint 3.2.1 remains the frozen Signal Engine. `DecisionEngine` remains the sole authority for `BUY`, `SELL`, `WAIT`, and `BLOCKED`. Production Contract V5 remains the merged, audited, unlocked contract authority. Sprint 5 Phase A.1 neither changes those sources nor grants Architecture Lock or Phase B authorization.

The Producer Trust Authority, Host Ingress Ledger, deterministic request-binding policy, Submission Permit, and their persistence interfaces are explicitly **Sprint 5 Candidate Contracts — NOT V5 existing authority**. V5 names are used only for capabilities its audited interfaces actually expose.

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
| Runtime orchestration | EA Host | Serialize events, invoke domain boundaries, enforce readiness | Replace domain validation or mutate domain state outside returned decisions |
| Instance ownership | Instance Ownership service | Lease, heartbeat, conflict, takeover, release, fence evidence | Basket or Execution self-election |
| Basket lifecycle | Basket State Machine | Validate and publish Basket state transitions | Infer confirmation from acknowledgement or Signal DTO |
| Pending requests | Execution Coordinator | Own logical request lifecycle, correlation, retry, and confirmation | Broker policy, Risk policy, or directional decision |
| Submission admission | Future Submission Permit authority | Commit one exact request/attempt/payload before external side effect | Submit without permit or mint competing permit after takeover |
| Units | Unit System | Validate symbol specification and normalize price/volume terms | Infer universal pip/digit rules |
| Risk | Risk Gate / Risk Governance | Evaluate the complete V5 risk envelope and issue bound authorization | Quick-check bypass or signal-score override |
| Platform/broker translation | Broker Adapter | Future platform calls, authoritative broker queries, raw result/event normalization, margin authority | Signal, Basket, Risk, Recovery, or Persistence policy |
| Transaction callback | EA Host | Sole platform callback entry and immutable event capture | Direct callback mutation of multiple domains |
| Persistence | Persistence service | Validate/load/save V5 request/checkpoint records and perform the narrowly scoped restart-watermark publication | Manufacture broker truth, release authority, or general atomicity |
| Statistics | Statistics service | Validate and accumulate authoritative deal history | Count requests or acknowledgements as trades |
| Recovery/restart | EA Host orchestration using Basket, Persistence, Ownership, Risk, and Execution contracts | Run the fail-closed recovery protocol | Recovery trading algorithm or bypass of another authority |
| Hard Kill | Risk Governance with independent release authority | Enforce latch and validate release provenance | Automatic restart release or execution-issued release |
| Diagnostics | Logs/dashboard/audit sinks | Observe immutable records | Become authority or mutate operational state |

The EA Host is the single production orchestration and mutation coordinator, not a shared-state super-module. Each domain accepts immutable inputs and publishes state only through its owning contract result. The host cannot edit a result locally to simulate a successful domain transition. Sprint 5 candidate authorities do not retroactively become V5 fields or methods.

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

Canonical encoding follows the V5 fixed typed length-prefixed convention: fields appear in specified order; strings encode field name, type, character length, and exact value; integers, enums, booleans, and datetimes use locale-independent decimal text; doubles use fixed 16-decimal point notation with negative-zero normalization; arrays use explicit order indices and are never silently sorted. `H` is fixed for Sprint 5 V1 as SHA-256 over UTF-8 bytes (no BOM and no Unicode normalization) of the canonical character stream and is emitted as 64 lowercase hexadecimal characters under policy ID `SWV5-SHA256-UTF8-V1`. The domain separator is the first typed canonical field, never unframed concatenation.

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

The same nonrecursive rule governs the future candidate authority records: Producer Trust digest uses typed domain `SWV5-SPRINT5-PRODUCER-TRUST-V1`; ordered Ingress Ledger digest uses `SWV5-SPRINT5-INGRESS-LEDGER-V1`; and Submission Permit digest uses `SWV5-SPRINT5-SUBMISSION-PERMIT-V1`. Each preimage contains every fixed-order field (and explicit record index for arrays) except its own digest; the full record appends the digest. Permit ID separately derives from `SWV5-SPRINT5-PERMIT-ID-V1`, persistence namespace, permit policy/version, logical request, and unique attempt. Same derived ID with different content is a conflict.

### Freshness Policy

Validation consumes an explicit authoritative context compatible with `SWV5_ContractValidationContext` and a versioned ingress freshness policy identifying required clock ID/authority. `max_age` must be positive and `max_future_skew` nonnegative. Envelope publication clock and evaluation-context clock must exactly match that policy. No validator may call `TimeCurrent()` or another hidden clock.

Fail-closed comparisons are exact:

- reject future publication when `publication_time > evaluation_time + max_future_skew`;
- reject expired publication when `evaluation_time >= publication_time + max_age`;
- reject zero/invalid time, arithmetic overflow, unknown policy/version, or mismatched clock authority.

The expiry boundary is exclusive. Numeric thresholds remain versioned deployment/test inputs; the semantics do not. After restart, a fresh authoritative evaluation context is mandatory. A previously accepted ingress resolves from its durable ledger record and cannot be reaccepted as new even if the replayed envelope is now stale.

### Producer Trust And Sequence Authority

The future pure Producer Trust Authority record contains record contract/policy ID, authority-record ID/generation/digest, issuing authority identity/policy, producer component, producer instance and epoch, authorization status (`AUTHORIZED`, `SUSPENDED`, `SUPERSEDED`, or `REVOKED`), allowed persistence namespace/symbol/timeframe/execution-mode/clock scope, validity interval `[valid_from, valid_until)`, and superseding record/generation. Validation also consumes an independently configured expected issuer/policy/generation trust anchor; no caller boolean is authority. Only `AUTHORIZED` is eligible. Publication must occur within the interval, and the record must still be current at evaluation. Scope mismatch or namespace collision fails closed.

Publication sequence is positive and strictly monotonic per authorized producer instance/epoch: a new identity requires `sequence > durable_high_watermark`; gaps are permitted; zero or lower sequence fails closed. Same-instance reset or regression fails closed. Sequence reset is allowed only through a newly authorized instance/epoch and superseding authority generation. Equal sequence and equal ingress identity resolves idempotently; equal sequence with different content is a conflict. An old or superseded producer cannot regain authority by replaying valid historical bytes. Credential and authority-record storage mechanics remain deployment scope.

`WAIT` and `BLOCKED` become durable `REJECTED_NO_ENTRY` outcomes and can never create an Execution Intent. `BUY` or `SELL` may only nominate direction and begin eligibility evaluation. The adapter rejects any action/direction mismatch and may deny eligibility but cannot reverse, promote, or reinterpret the Decision.

## Durable Host Ingress Ledger And Request Binding

The Host Ingress Ledger is a **Sprint 5 Candidate Contract — NOT V5 existing authority**. Its independently versioned, fenced, digest-bound header owns persistence namespace, ownership fence, producer authority/instance/epoch, ingress policy, highest accepted publication sequence, canonical membership/binding index, record/previous revision, compaction generation, and ledger digest.

Each record owns ingress identity/sequence, acceptance disposition, deterministic logical request identity, namespace-monotonic request sequence, authoritative acceptance time, materialization state, terminal disposition, and revision/digest. States are:

- `REJECTED_NO_ENTRY` — valid `WAIT`/`BLOCKED`; terminal; no request permitted.
- `ACCEPTED_REQUEST_PENDING` — directional ingress durably accepted; deterministic request not yet durably found.
- `BOUND_TO_REQUEST` — exact deterministic logical request exists in the V5 pending-request set.
- `TERMINALLY_PROCESSED` — the bound request has a terminal authoritative disposition.

Evaluation dispositions `NEW`, `DUPLICATE`, `REPLAY_RESOLVED`, and `CONFLICT` do not replace lifecycle state. Compaction must preserve membership, binding, per-producer high-watermark, and generation so an accepted identity cannot become new again.

Logical `correlation_id` is derived as the versioned hash of domain `SWV5-SPRINT5-REQUEST-BINDING-V1`, persistence namespace, request-binding policy ID/version, and accepted ingress identity. The acceptance CAS also persists a namespace-monotonic request sequence and authoritative acceptance time. The exact reconstructible initial V5 identity uses `attempt_id = H("SWV5-SPRINT5-ATTEMPT-V1", correlation_id, 0)`, empty parent attempt, that persisted sequence, `created_at` equal to acceptance time, and `idempotency_key = H("SWV5-SPRINT5-IDEMPOTENCY-V1", correlation_id)`. Retries allocate a durable ordinal greater than zero and a unique attempt ID under the same correlation.

The crash-safe protocol uses no fictitious cross-domain transaction:

1. CAS-persist `ACCEPTED_REQUEST_PENDING` in the Sprint 5 ledger.
2. Derive the same logical request identity.
3. Use V5 `LoadPendingRequests()` to locate that exact request; if absent, publish the complete set containing its exact blueprint through `SavePendingRequests()` and reload/validate it.
4. CAS-advance the ledger to `BOUND_TO_REQUEST` only after the durable request is observed.

Crash after step 1 leaves accepted/request-pending authority; restart reconstructs the same identity and resumes steps 3–4. Crash after step 3 but before step 4 finds the same existing request and converges the ledger. Replaying the Signal after either crash cannot create a second logical request and cannot silently discard the accepted intent.

## Single-Writer And Event Serialization Model

The EA Host owns one deterministic mutation stream per ownership namespace. Platform callbacks perform capture only: each callback creates an immutable event envelope and submits it to the host dispatcher. Only the dispatcher may invoke state-changing domain operations.

Events include signal ingress, timer/lease maintenance, platform transaction capture, restart/reconciliation work, and persistence-publication completion. Each accepted event receives a host event sequence under the current ownership fence. Processing is non-reentrant and one event completes its decision/publication boundary before the next can advance the same authoritative state.

Deterministic rules:

1. Startup/reconciliation gates are processed before signal eligibility.
2. While not runtime-eligible, signal events may be rejected or retained only under an approved bounded ingress policy; they cannot create requests.
3. Captured transaction evidence is never dropped because readiness is false. It is serialized into reconciliation processing and may only mutate through the Execution contract.
4. Lease loss immediately removes mutation eligibility. Later events are captured for audit/reconciliation but cannot publish owner-authoritative state.
5. Persistence publication uses expected record sequence, store revision, ownership fence, and compare-and-set. Publication failure leaves the last authoritative checkpoint unchanged and forces reconciliation/halt.
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
12. CAS-persist the accepted ingress as `ACCEPTED_REQUEST_PENDING`, derive its deterministic logical request, then use V5 `SavePendingRequests()` to publish `SWV5_REQUEST_CREATED` and `SWV5_REQUEST_RISK_AUTHORIZED`; converge the ledger to `BOUND_TO_REQUEST`.
13. Immediately before external admission, reacquire the complete current authority envelope and call `ISWV5RiskContract::ValidateAuthorization(context, authorization, current_binding, decision)` plus current ownership, Hard Kill, mode, Basket, Unit/specification, request/attempt, and normalized-payload validation.
14. If and only if all current bindings pass, durably commit one single-use Sprint 5 Submission Permit for the exact logical request, unique attempt, and payload. Before commit no broker side effect is allowed; after commit the attempt is externally uncertain until authoritative disposition.
15. Advance the V5 request through `SWV5_REQUEST_SUBMISSION_PENDING` under its independent request-set publication boundary and pass the exact request, attempt, and committed permit to a future Broker Adapter.
16. Record raw result-retcode evidence and classify it through the versioned Execution policy. Acknowledgement remains pending confirmation.
17. Capture platform transaction/deal evidence, validate correlation, ownership, sequence, symbol-specification and expected Basket version, then call `AcceptTransactionEvidence`.
18. Persist the complete returned pending-request state through `SavePendingRequests()`. Never reconstruct it locally.
19. Only authoritative confirmation may make a Basket transition, update confirmed/residual volume, or make a deal eligible for Statistics.
20. Publish the derived V5 checkpoint separately through `SaveCheckpoint()`. Statistics consumes validated authoritative deal evidence downstream and remains reconstructible from deal history.

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

Earlier Risk evaluation is necessary but insufficient for broker admission. Immediately before committing a Submission Permit, the host must invoke the existing `ISWV5RiskContract::ValidateAuthorization()` against the complete **current** `SWV5_RiskEvaluationInput`. Current margin/Basket-risk authority records and freshness, ownership fence, account namespace/epoch/mode, Basket version, symbol-specification sequence, Hard Kill state/generation, exact request/attempt, normalized payload, and exclusive authorization expiry must still match. A changed binding yields no permit and no broker call.

## Submission Permit And External-Side-Effect Authority

The Submission Permit is a **Sprint 5 Candidate Contract — NOT V5 existing authority**. It is a durable, versioned, digest-bound, single-use admission record created only under current ownership and serialized execution. Its narrowly scoped commit operation is linearizable with ownership/takeover authority: it atomically compares the expected current fence/lease generation, proves no permit already exists for the attempt and no unresolved competing permit exists for the logical request, and inserts the permit. If takeover wins first, stale commit fails; if commit wins first, takeover must observe and quiesce the unresolved permit. This is not general V5 or cross-domain atomicity. It binds:

- permit policy/format, ID, committed timestamp, record sequence/revision, and digest;
- persistence namespace and ownership fence at issuance;
- account namespace/epoch and HEDGING mode;
- one logical request and one unique attempt identity;
- exact normalized price/stop/limit/volume payload and normalization identity;
- Basket ID/version and symbol-specification sequence;
- complete current V5 Risk authorization and its authority-evidence references; and
- current Hard Kill state, latch identity, and generation.

The commit point is deliberately irreversible:

- **Before permit commit:** no external side effect is allowed.
- **After permit commit:** the exact attempt is `COMMITTED_UNRESOLVED` and treated as possibly externally submitted, even if the host crashes before invoking the adapter.
- The permit cannot be reused, reassigned, or converted into a different attempt/payload.
- Absence of a callback or passage of time is not proof that no side effect occurred.

Permit dispositions are `COMMITTED_UNRESOLVED`, `AUTHORITATIVE_SIDE_EFFECT_CONFIRMED`, `AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED`, `AUTHORITATIVE_REJECTED`, and `CONFLICT_MANUAL_REQUIRED`. Only authoritative evidence may reach a terminal disposition; replay is idempotent, while conflicting terminal evidence requires manual reconciliation.

Availability may be lost after a commit-before-call crash, but safety requires reconciliation rather than blind resubmission. Broker call duration may exceed lease duration; safety comes from the one durable attempt and takeover quiescence, not an optimistic timing assumption.

### Lease Loss And Takeover Quiescence

Lease loss before permit commit means no permit and no broker call. Lease loss after permit commit revokes the old host's general mutation/publication rights but does not erase the auditable one-attempt authority. If invocation had not started when loss was observed, it must not start, while the permit remains unresolved; if already externally in flight, it may complete beyond local control. Its result must be reconciled and published by a current owner.

A takeover must load every unresolved permit before admitting any increasing action. It cannot mint a competing permit or blind retry for that logical request. The request enters `SWV5_REQUEST_RECONCILIATION_REQUIRED` with lifecycle phase `SWV5_EXECUTION_PHASE_UNCERTAIN` until definitive authoritative disposition exists.

### Positive And Negative Evidence

Unresolved permit disposition requires the broker-specific evidence policy to evaluate complete authoritative position, order, deal, transaction, history, and Execution-request evidence. No retry is permitted until the contracted policy proves terminal positive or negative disposition. An immediate missing callback, timeout alone, reconnect, or locally empty query is not negative evidence. The exact broker/build negative-evidence horizon remains Phase F.

### Hard Kill After Commit

If Hard Kill latches after commit, no new increasing permit is eligible. The committed attempt remains uncertain/in-flight and is not erased. Later confirmation must still be reconciled, after which only separately authorized V5 reducing/close-only behavior may follow.

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

The future Broker Adapter is the only component allowed to translate between V5 DTOs and platform-specific broker facilities. Phase A contains no adapter implementation.

Conceptual side-effect inputs are an already-normalized V5 request, its exact unique current attempt identity, and the matching durably committed single-use Submission Permit. The adapter must reject invocation without an exact permit/request/attempt/payload match and committed/unresolved status. It consumes the permit and never creates, renews, or broadens submission authority. Conceptual outputs are raw submission evidence, raw retcode evidence, immutable transaction evidence, independently authoritative margin records, symbol specifications, and complete Broker-owned positions/orders/deals/transactions query snapshots.

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

The exact audited V5 operation boundaries are:

- `SavePendingRequests()` independently publishes the complete ordered request set.
- `SaveCheckpoint()` independently publishes one checkpoint.
- `PublishRestartQueryWatermarks()` atomically advances only the two accepted owner-specific query high-watermarks and validated checkpoint publication metadata within that interface's exact proposal.

V5 exposes no general transaction across Basket, pending requests, accepted events, Hard Kill, reconciliation, Statistics, ingress, and submission permits. The Host Ingress Ledger and Submission Permit journal each require a separately versioned/fenced/digest-bound Sprint 5 Candidate persistence contract, with atomicity local to one ledger/journal CAS mutation unless a future approved store proves more.

Before runtime eligibility, the host publishes an open-session checkpoint with `clean_shutdown=false`. Normal related V5 changes use independently fenced/versioned writes: publish the complete authoritative pending-request result first, then publish a checkpoint derived from the observed durable request set and validated Basket/Hard Kill/reconciliation state. Statistics remains reconstructible from authoritative deal history and is not claimed inside either operation.

A failed CAS preserves the prior authoritative record. A crash/failure between related writes creates dirty/unresolved state, revokes runtime eligibility, and requires complete restart reconciliation. No later publication may infer an earlier success, manufacture missing state, or reinterpret a partial publication. Only orderly shutdown after all domains converge may publish `clean_shutdown=true`.

The complete pending-request array, accepted identity sets, Hard Kill provenance, ownership authority, ingress/request bindings, unresolved permits, and reconciliation state cannot be reconstructed from the last request, current positions, logs, or counters after restart.

## Fail-Closed Startup And Restart Gate

The host begins runtime-disabled. A clean shutdown is evidence, never a bypass. The mandatory sequence is:

1. Pin the exact supported contract/policy versions; reject incompatible or unknown records without mutation.
2. Establish the intended ownership namespace and HEDGING account mode; unknown, Netting, or changed mode halts readiness.
3. Acquire or recover the instance lease through compare-and-set using the authoritative lease clock. Do not infer ownership from lease absence or missed heartbeat.
4. Load and validate the latest checkpoint, full ordered pending-request set, Sprint 5 Ingress Ledger, and Submission Permit journal. Corrupt/incompatible state remains immutable evidence and causes the contract-defined corruption disposition.
5. Load Hard Kill state. A released historical latch additionally requires the independent authority record; it cannot be reconstructed from the checkpoint.
6. Obtain independently authoritative Broker Adapter snapshots for positions, orders, deals, and transactions, and the Execution-owned pending-request query snapshot.
7. Require the exact V5 closed query union: positions, orders, deals, transactions, and pending requests. Enforce source ownership, digest, freshness, observation sequence, and owner-specific persisted anti-replay high-watermarks.
8. Reconcile namespace, Basket identity/state/version, HEDGING mode, exposure and residual volume, positions/orders, complete request-set identity, latest correlations, transaction watermark, Hard Kill generation, ownership fence, and reconciliation revision.
9. Converge `ACCEPTED_REQUEST_PENDING` and `BOUND_TO_REQUEST` ledger states against the deterministic request identity; never create a second request.
10. Inspect every unresolved Submission Permit. Any committed unresolved attempt blocks increasing execution and retry until authoritative disposition.
11. Resolve uncertain or pending requests from authoritative transaction/deal/request evidence; never retry solely because the process restarted.
12. Validate every accepted-event and accepted-ingress identity set, fingerprint/membership policy, producer high-watermark, and compaction generation so replay remains idempotent after restart.
13. Require `SWV5_RESTART_SAFE_TO_RESUME` and the required reconciled Basket state. Every other disposition remains disabled, close-only, halted, or reconciliation-required as returned.
14. Use the specifically scoped V5 `PublishRestartQueryWatermarks()` operation for its reconciled checkpoint/query-watermark proposal; do not treat it as general publication atomicity.
15. Publish/verify the open-session `clean_shutdown=false` checkpoint and revalidate lease liveness, Hard Kill, account mode, symbol specification, and Risk authority at the enable boundary.
16. Only then may the host mark the namespace runtime-eligible. Every later event rechecks the authorities whose expiry or generation can invalidate eligibility.

A new namespace with no record must use an explicitly provisioned genesis policy and fresh zero-state reconciliation; absence is not evidence that Hard Kill, exposure, or prior requests are clean. The physical store, platform query implementation, and provisioning credentials remain later-phase decisions.

## Complete Reconciliation Domains

Reconciliation is never positions-only. The mandatory query union is exactly:

- Broker Adapter: positions, orders, deals, transactions
- Execution Coordinator: pending requests

Required identity also includes namespace, account mode, Basket state/version, long/short/net/aggregate/Basket/residual volume, order/position/request counts, latest confirmed correlation and broker identity, transaction watermark, request-set digest/revision, Hard Kill generation, ownership fence, and reconciliation revision. Incomplete, stale, replayed, mixed-owner, unknown-bit, future-dated, or ambiguous evidence fails closed.

## Basket, Recovery, Hard Kill, And Statistics

### Basket

Basket is the sole authoritative execution-state domain. A Signal DTO is intent input, not Basket state; an acknowledgement is pending evidence, not Basket state. Transitions require the V5 state machine and authoritative confirmation. Partial close updates confirmed and residual exposure. `CLOSING -> IDLE` requires confirmed zero positions, zero orders, zero residual volume, and zero pending requests.

### Recovery

Recovery remains an architecture-level lifecycle boundary only. Basket owns cumulative recovery attempts and current layer separately. Accepted recovery evidence is durable and replay-idempotent. No averaging, grid, martingale, or recovery trading behavior is defined. Recovery cannot bypass Ownership, Persistence, Reconciliation, Units, Risk, or Hard Kill.

### Hard Kill

Hard Kill is a durable latch evaluated first. Restart, signal arrival, lease takeover, or reattachment cannot clear it. While active, only contract-approved reconciliation and separately authorized reducing/close-only work is eligible. `RELEASED` requires the V5 independent release-authority record and exact provenance; Persistence or Execution cannot self-issue or reconstruct it.

### Statistics

Statistics is downstream of authoritative confirmed deal evidence. Before mutation it validates finite price, volume, profit, commission, swap, and fee; attribution; account currency; ticket/correlation chain; deal-history completeness; and durable identity disposition. Requests and acknowledgements never count as trades. Duplicate deals are idempotent, and partial closes do not complete Basket statistics while residual exposure remains.

## Instance Ownership And Stale-Host Policy

The ownership key remains account login + broker + server + symbol + strategy ID + Magic. The immutable ownership fence carries owner, ownership namespace, lease version, takeover generation, and fencing digest. Same-owner heartbeat changes liveness and store revision, not the ownership-authority fence. Valid takeover changes the authority generation and invalidates every stale prior-owner binding.

Fence or lease mismatch removes general mutation rights immediately. Before Submission Permit commit it also forbids broker admission. After commit it cannot revoke or duplicate the exact one-attempt external-side-effect authority: the old host cannot publish general state, the new host cannot mint a competing permit, and the unresolved attempt must converge through authoritative reconciliation. A stale host receiving broker events may capture immutable evidence and route it to reconciliation/audit, but it cannot accept the event into authoritative request/Basket state or publish a checkpoint. No implicit takeover is allowed.

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
| Unauthorized or superseded producer | Reject; no ledger acceptance or request | Producer Trust Authority |
| Ingress replay after restart | Resolve durable prior disposition/binding; no second request | Ingress Ledger |
| Permit committed; broker call unobserved | Keep `COMMITTED_UNRESOLVED`; no retry until authoritative negative evidence | Submission Permit / Execution |
| Lease lost before permit | No permit and no broker call | Instance Ownership / Submission Authority |
| Lease lost after permit | Preserve exact unresolved attempt; revoke general writes; takeover quiesces | Submission Permit / Ownership |
| Takeover sees unresolved permit | `SWV5_REQUEST_RECONCILIATION_REQUIRED` / `SWV5_EXECUTION_PHASE_UNCERTAIN`; block increasing execution and retry | New owner / Execution |
| Hard Kill after permit | Preserve attempt; block new increase; reconcile; reduce/close only if separately authorized | Risk Governance / Execution |
| Risk binding changed before permit | Deny permit and broker call; return current V5 safe disposition | Risk / Submission Authority |
| State publication partially completed | Runtime disabled; preserve each prior authority; full restart reconciliation | Persistence / Host gate |
| Queue overload or captured-event loss | Stop admission; mark stream unreliable; halt/reconcile from authoritative queries | EA Host / Broker Adapter |

## Threat And Failure Matrix

`Settled for Phase B` means pure DTO/validator/interface semantics are fixed; it does not authorize Phase B or claim later runtime evidence.

| # | Threat | Authoritative owner | Safe disposition | Settled for Phase B | Later dependency |
|---:|---|---|---|---|---|
| 1 | Duplicate signal | Ingress Ledger | Resolve prior identity/disposition; no second request | Yes | Phase D storage/compaction |
| 2 | Replay after restart | Ingress Ledger / Execution | Recover prior binding by deterministic request ID | Yes | Phase D durable store |
| 3 | Producer restart / sequence reset | Producer Trust | Reject same-epoch reset; require newly authorized epoch | Yes | Deployment provisioning |
| 4 | Stale signal | Signal Ingress | Reject at exclusive max-age/future-skew boundary | Yes | Policy thresholds |
| 5 | Two EA hosts | Instance Ownership | Conflict/halt; one current fence only | Yes | Phase D CAS technology |
| 6 | Lease takeover | Ownership / Host gate | Reconcile ledger, permits, V5 state before readiness | Yes | Phase D store/lease implementation |
| 7 | Lease loss during submission | Submission Permit | Before commit: no call; after commit: unresolved one-attempt authority, no competitor | Yes | Phase F adapter evidence |
| 8 | Duplicate callback | Execution | Durable idempotent no-op | Yes | Phase C fixtures |
| 9 | Out-of-order callback | Execution | Apply V5 sequence policy once or reconcile | Yes | Phase F broker ordering profile |
| 10 | Partial fill | Execution / Basket | Persist cumulative/residual state; no completion | Yes | Phase E integration fixtures |
| 11 | Acknowledgement without confirmation | Execution | Remain confirmation-pending; no Basket/Statistics mutation | Yes | Phase C fixtures |
| 12 | Unknown broker disposition | Execution / Permit | `UNCERTAIN`/reconciliation; no retry | Yes | Phase F negative-evidence policy |
| 13 | Crash before broker call | Submission Permit | If pre-commit, no side effect; if post-commit, unresolved/no resubmit | Yes | Phase D journal; Phase F evidence |
| 14 | Crash after broker call | Execution / Permit | Unresolved until authoritative broker/history reconciliation | Yes | Phase F broker evidence |
| 15 | Restart with pending request | Host / Persistence / Execution | Runtime disabled; complete five-domain query and disposition | Yes | Phase D reference implementation |
| 16 | Dirty shutdown | Host / Persistence | `clean_shutdown=false`; full restart gate | Yes | Phase D crash tests |
| 17 | Corrupt persistence | Persistence | Preserve; contract disposition; no self-heal | Yes | Phase D corruption tests |
| 18 | Hard Kill during pending request | Risk / Execution | Latch; block increase; reconcile; authorized reduction only | Yes | Phase E fixtures |
| 19 | Historical RELEASED Hard Kill without provenance | Risk Governance | Reject release; remain disabled/latched | Yes | Deployment authority storage |
| 20 | Broker reconnect | Broker Adapter / Execution | Preserve uncertainty; refresh complete authority and reconcile | Yes | Phase F profile |
| 21 | Incomplete broker query set | Broker Adapter / Persistence | Runtime disabled; fail reconciliation | Yes | Phase F query implementation |
| 22 | Missing Execution pending-request query | Execution / Persistence | Runtime disabled; fail reconciliation | Yes | Phase D/E implementation |
| 23 | Replayed query snapshot | Persistence | Reject against owner-specific high-watermark | Yes | Existing V5 / Phase D |
| 24 | Non-finite broker data | Receiving V5 domain | Reject before Risk/state/Statistics/persistence mutation | Yes | Phase E/F fixtures |
| 25 | Unit mismatch | Unit System | Invalidate normalization, Risk, permit, and request | Yes | Phase E/F fixtures |
| 26 | Wrong account mode | Host / bound V5 domains | Halt; HEDGING-only | Yes | Existing V5 |
| 27 | Persistence CAS failure | Persistence / Host gate | Preserve prior record; disable runtime; reconcile | Yes | Phase D technology |
| 28 | Statistics replay | Statistics | Durable idempotent no-op; never double-count | Yes | Phase E fixtures |
| 29 | Genesis/no-record startup | Operations / Risk / Host gate | No assume-clean; provision genesis and reconcile zero state | Yes | Phase D provisioning implementation |
| 30 | Queue overload/event loss | EA Host / Broker Adapter | Stop admission; mark stream unreliable; authoritative reconciliation | Yes | Phase C queue implementation |

## Observability And Traceability

Every audit event must carry, where applicable: ingress identity and producer; snapshot sequence/history generation/symbol/timeframe; host event sequence; persistence namespace and Basket ID; ownership fence lease/takeover generation; logical correlation/attempt/idempotency identity; lifecycle phase/request state; broker order/deal/position/event/transaction identity; Risk authorization and Hard Kill latch/generation; symbol-specification sequence; Basket state/version; accepted-event index revision; checkpoint record/store/reconciliation revisions; authoritative timestamp/source; and reason/disposition.

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
17. Sprint 5 Phase A.1 authorizes no runtime code, broker API, or Phase B implementation.
18. Every authoritative state change is returned by its owning contract and published through that contract's actual operation boundary before a dependent action; no general V5 multi-domain atomicity is assumed.
19. A stale ownership fence cannot mutate or publish general authoritative state; a previously committed permit remains only the exact unresolved one-attempt authority and cannot be duplicated.
20. Signal, logical request, broker execution, Basket, and persistence identities remain distinct and explicitly correlated.
21. Canonical ingress identity and payload digest use nonrecursive, domain-separated preimages.
22. A digest does not establish producer trust; current independent Producer Trust Authority is mandatory.
23. Producer publication sequence is monotonic per authorized instance/epoch; reset requires a newly authorized epoch.
24. Durable ingress acceptance resolves replay to one deterministic logical request across crashes.
25. Attempt identity is unique and never aliases logical request or ingress identity.
26. No broker side effect is allowed before a durable single-use Submission Permit commit.
27. After permit commit, the attempt remains uncertain until authoritative positive or negative disposition; timeout alone never permits retry.
28. Final permit admission requires current `ISWV5RiskContract::ValidateAuthorization()` against the complete binding.
29. Takeover cannot mint a competing permit while an unresolved permit exists.
30. Queue overload or event loss revokes admission and requires authoritative reconciliation.

## OPEN ARCHITECTURE QUESTIONS

| Question | Why it matters | Blocking? | Proposed ADR owner | Blocks phase |
|---|---|---|---|---|
| Which physical store/lock technology proves the required durable compare-and-set, atomic publication, crash consistency, and authoritative lease clock on MT5? | V5 specifies semantics but not a technology. | Blocking | Persistence architecture owner | Phase D |
| What versioned broker/platform retcode table and transaction-order profile applies to each supported terminal/broker build? | Adapter classification and ordering cannot be guessed. | Blocking | Broker Adapter owner | Phase F |
| What concrete host queue durability and capacity policy preserves captured transaction evidence during overload or process failure? | Single-writer semantics require a bounded failure policy, not silent event loss. | Blocking | EA Host owner | Phase C |
| What deployment authority provisions a new namespace's genesis Hard Kill/checkpoint state? | Missing persistence cannot be treated as clean authority. | Blocking | Operations/Risk Governance owner | Phase D |
| What broker/build-specific negative-evidence horizon and complete proof rule establishes that a committed attempt had no side effect? | Architecture forbids timeout-as-proof, but broker evidence behavior is deployment-specific. | Blocking | Broker Adapter / Verification authority | Phase F |
| What exact Risk thresholds and trading-day configuration apply to a deployment? | Contracts define validation, not deployment values. | Nonblocking for pure contracts | Risk Governance owner | Phase E/F deployment |
| Where are Producer Trust, Hard Kill release, and operator credentials stored and rotated? | Trust semantics are fixed, but secret mechanics are deployment concerns. | Nonblocking for pure contracts | Security/Operations owner | Production deployment |
| What broker-specific Hedging fixtures and evidence threshold permit a Demo adapter to pass independent audit? | Architecture alone cannot prove broker behavior. | Blocking | Verification authority | Phase F/G |

Phase B requires no new safety decision: ADR-009 and ADR-013 through ADR-015 fix canonical construction, freshness/trust semantics, durable replay/binding, publication boundaries, and submission authority. Remaining questions concern Phase C queue implementation, Phase D storage/genesis technology, Phase F broker profiles/negative evidence/evidence thresholds, or deployment values/credentials. No unresolved question permits an implementation phase to weaken or bypass V5.

## Proposed Sprint 5 Implementation Phases

| Phase | Scope | Entry gate | Exit gate |
|---|---|---|---|
| A.1 | Architecture safety closure and ADRs only | Independent Phase A review findings | New independent re-review closes Critical/Major architecture gaps |
| B | Pure ingress/Producer Trust/Ledger/Submission Permit DTOs, orchestration interfaces, compatibility and deterministic policy validators; no broker API | Phase A.1 independently approved and Phase B separately authorized | Compile/static isolation; deterministic table specifications; no runtime dependency or new safety decision |
| C | Deterministic single-writer reference coordinator with fake broker only | Phase B contracts approved; queue policy resolved | Event-order, duplicate, replay, uncertainty, partial-fill, and lease-loss fixtures pass |
| D | Persistence/restart reference implementation against a fake platform/store | Store/genesis ADRs approved | Crash/CAS/corruption/full-query/restart tests pass; no MT5 broker calls |
| E | Integrated V5 Risk, Basket, transaction, Hard Kill, Statistics, and recovery-boundary fixtures | Phases C/D pass; deployment Risk policy approved | Full positive/negative/cross-domain deterministic suite passes fail-closed |
| F | MT5 Demo Broker Adapter and Strategy Tester only | Broker profiles/retcodes accepted; independent safety authorization | Demo/tester compile and broker-specific evidence pass; no live chart/trading |
| G | Reproducible integration evidence and independent audit | Exact source freeze; all earlier gates pass | Immutable evidence, provenance, full audit, explicit go/no-go recommendation |

No phase authorizes live trading. Any production or live authorization requires a separate, explicit post-audit decision.

### Phase B Contractability Test

**YES:** after independent approval and separate authorization, a Phase B developer can implement only pure DTOs, pure validators/contracts, the Producer Trust input, Host Ingress Ledger contract, deterministic request-binding policy, Submission Permit contract, publication/orchestration interfaces, and deterministic policy interfaces without inventing a new safety-relevant architecture decision. Physical queue/store/lock technology, broker-specific evidence, deployment values, and credentials remain correctly deferred to later phases.

## Acceptance Criteria And Traceability

### Phase A Independent-Review Closure Matrix

| Finding | Closure mechanism | Candidate status |
|---|---|---|
| CRITICAL-1 external side effect after fence check | Linearizable ownership-aware one-attempt permit commit, irreversible uncertainty, and takeover quiescence | Closed for re-review |
| MAJOR-1 recursive/ambiguous ingress construction | Fixed Source Body → identity preimage → identity → digest preimage → digest → Full DTO dependency | Closed for re-review |
| MAJOR-2 undefined freshness/trust | Exact exclusive freshness comparisons plus independent Producer Trust record and epoch lifecycle | Closed for re-review |
| MAJOR-3 no durable ingress replay authority | Fenced/digest-bound Host Ingress Ledger with high-watermark, membership, compaction, and dispositions | Closed for re-review |
| MAJOR-4 no atomic/idempotent Signal→request crash protocol | Deterministic complete initial request blueprint plus two-direction convergence without cross-domain transaction | Closed for re-review |
| MAJOR-5 false general atomicity | Exact separate V5 operation boundaries and ADR-015 dirty/unresolved recovery protocol | Closed for re-review |
| MAJOR-6 no final current Risk validation | Mandatory existing `ISWV5RiskContract::ValidateAuthorization()` immediately before ownership-aware permit commit | Closed for re-review |

| Criterion | Architecture location |
|---|---|
| Every V5 authority has one runtime owner; no dual mutation owner | Architectural Components And Sole Authorities |
| Signal ingress and no competing direction are defined | Signal DTO Ingress Architecture |
| Canonical ingress construction, freshness, and producer trust are nonrecursive and deterministic | Nonrecursive Canonical Construction; Freshness Policy; Producer Trust And Sequence Authority |
| Replay after restart binds to one logical request | Durable Host Ingress Ledger And Request Binding |
| Host orchestration and serialization are deterministic | Single-Writer And Event Serialization Model |
| Contract-safe end-to-end order is defined | Safe Signal-To-Execution Pipeline |
| V5 Risk ordering/binding has no bypass | Risk Gate Ordering And Binding |
| Existing request states and identity phases are preserved | Execution Request Lifecycle |
| Broker and callback boundaries are explicit | Broker Adapter Boundary; Acknowledgement, Confirmation, And Transaction Ownership |
| External submission has one durable attempt and takeover quiescence | Submission Permit And External-Side-Effect Authority |
| Persistence claims match exact V5 operations and crash recovery | Persistence Boundaries And Crash-Safe Publication; Fail-Closed Startup And Restart Gate |
| Hard Kill, Recovery, Basket, Statistics, ownership, mode, and Units retain V5 authority | Corresponding domain sections |
| Failure taxonomy and threat matrix exist | Failure Taxonomy; Threat And Failure Matrix |
| Formal invariants and later phase gates exist | Formal Architecture Invariants; Proposed Sprint 5 Implementation Phases |
| No runtime API/source change or hidden approval is granted | Governance Status; Out Of Scope |

## Out Of Scope

Phase A.1 explicitly excludes:

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

V3S remains an independent Research Lab. Its M5 logic, experiments, and discoveries are not Sprint 5 inputs and cannot authorize M15 execution. Any future hypothesis must complete the separate V3S validation and formal Fusion adoption process before it can become a reviewed Signal Engine change. Phase A creates no V3S dependency.

## Review Recommendation

This document is ready to be evaluated as a **Sprint 5 Phase A.1 Architecture Safety Closure Candidate / In Review** only after its documentation diff passes scope and consistency checks. The required next action is a **New Independent Sprint 5 Architecture Re-review**. Phase B, runtime implementation, broker implementation, Architecture Lock, and production trading remain not granted.
