# Fusion Pro V5 Sprint 5 Phase A — Execution Layer / EA Host Architecture

## Governance Status

| Item | Status |
|---|---|
| Sprint 5 Phase A | **ARCHITECTURE CANDIDATE / IN REVIEW** |
| Authorized work | Architecture and ADR documentation only |
| Authorized architecture baseline | Sprint 4 Architecture |
| Production Contract V5 | Audited and merged; **Architecture Lock not granted** |
| Runtime implementation | **NOT AUTHORIZED** |
| Broker implementation | **NOT AUTHORIZED** |
| Production or live trading | **NOT AUTHORIZED** |
| Next gate | Independent Sprint 5 Architecture Review |

This document answers: **How can the audited Production Contract V5 become an Execution Layer architecture without coupling broker runtime into the frozen Signal Engine?** It does not authorize or specify how to call a broker API.

## Authorities And Preserved Baselines

This candidate is subordinate to, and reconciled with:

- `FusionProV5_Master_Architecture.md`
- `FusionProV5_Sprint4_Production_Architecture.md`
- `FusionProV5_Contract_Versioning_Policy.md`
- all Production Contract V5 headers under `FusionProV5/ProductionArchitecture/`
- ADR-001 through ADR-008
- ADR-009 through ADR-012 introduced by this candidate

Sprint 3.2.1 remains the frozen Signal Engine. `DecisionEngine` remains the sole authority for `BUY`, `SELL`, `WAIT`, and `BLOCKED`. Production Contract V5 remains the merged, audited, unlocked contract authority. Sprint 5 Phase A neither changes those sources nor grants Architecture Lock.

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
| Runtime orchestration | EA Host | Serialize events, invoke domain boundaries, enforce readiness | Replace domain validation or mutate domain state outside returned decisions |
| Instance ownership | Instance Ownership service | Lease, heartbeat, conflict, takeover, release, fence evidence | Basket or Execution self-election |
| Basket lifecycle | Basket State Machine | Validate and publish Basket state transitions | Infer confirmation from acknowledgement or Signal DTO |
| Pending requests | Execution Coordinator | Own logical request lifecycle, correlation, retry, and confirmation | Broker policy, Risk policy, or directional decision |
| Units | Unit System | Validate symbol specification and normalize price/volume terms | Infer universal pip/digit rules |
| Risk | Risk Gate / Risk Governance | Evaluate the complete V5 risk envelope and issue bound authorization | Quick-check bypass or signal-score override |
| Platform/broker translation | Broker Adapter | Future platform calls, authoritative broker queries, raw result/event normalization, margin authority | Signal, Basket, Risk, Recovery, or Persistence policy |
| Transaction callback | EA Host | Sole platform callback entry and immutable event capture | Direct callback mutation of multiple domains |
| Persistence | Persistence service | Validate/load/save checkpoints and atomically publish revisions/high-watermarks | Manufacture broker truth or release authority |
| Statistics | Statistics service | Validate and accumulate authoritative deal history | Count requests or acknowledgements as trades |
| Recovery/restart | EA Host orchestration using Basket, Persistence, Ownership, Risk, and Execution contracts | Run the fail-closed recovery protocol | Recovery trading algorithm or bypass of another authority |
| Hard Kill | Risk Governance with independent release authority | Enforce latch and validate release provenance | Automatic restart release or execution-issued release |
| Diagnostics | Logs/dashboard/audit sinks | Observe immutable records | Become authority or mutate operational state |

The EA Host is the single production orchestration and mutation coordinator, not a shared-state super-module. Each domain accepts immutable inputs and publishes state only through its own V5 interface result. The host cannot edit a result locally to simulate a successful domain transition.

## Signal DTO Ingress Architecture

### Existing Source Fields

The current frozen source defines `SWV5_DecisionResult` as:

- `header`, an `SWV5_ResultHeader` containing `engine_kind`, `health`, `valid`, `score`, `confidence`, `reason_flags`, `snapshot_sequence`, `history_generation`, `reason_text`, and `validation_error`
- `action`
- `direction`
- `state`
- `blocking_engine`

The upstream immutable `SWV5_SnapshotHeader` already defines `schema_version`, `sequence`, `history_generation`, `execution_mode`, `data_quality_flags`, `symbol`, `timeframe`, and `closed_bar_time`. The ingress boundary must preserve these authoritative producer facts without duplicating them as independently mutable values.

### Candidate Ingress Envelope

A future pure DTO contract must carry:

| Field group | Required authority |
|---|---|
| Ingress contract | Contract name, schema version, minimum-compatible version, policy ID |
| Producer | Stable producer component identity and producer-instance identity |
| Source snapshot | The authoritative snapshot schema, sequence, history generation, execution mode, data-quality flags, symbol, timeframe, and closed-bar time |
| Decision | The unmodified `SWV5_DecisionResult` fields listed above |
| Publication | Decision publication timestamp and producer publication sequence |
| Correlation | Stable ingress/correlation identity derived from the canonical envelope, not generated by the consumer |
| Integrity | Canonical payload digest and declared canonical format |

The envelope does not duplicate request, attempt, order, deal, position, Basket, lease, Risk authorization, or symbol-specification identities. Those begin at their existing V5 authority boundaries. Signal correlation may be linked to a later logical request, but it never becomes broker identity.

Ingress validation must fail closed for an unknown or unsupported version, malformed or missing identity, digest mismatch, wrong symbol, wrong timeframe, invalid Decision result, incoherent snapshot sequence/generation, stale publication, duplicate identity, or replay below the accepted ingress high-watermark. Freshness uses an explicit authoritative host validation context and policy; no hidden wall clock is permitted.

`WAIT` and `BLOCKED` are consumed as auditable no-entry outcomes. They cannot create an Execution Intent. `BUY` or `SELL` may only nominate direction and begin eligibility evaluation; they do not authorize execution. The adapter must reject any mismatch between `action` and `direction`. It may block a signal for safety but may not reverse, promote, or reinterpret it.

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
12. Register and durably publish `SWV5_REQUEST_CREATED`, then bind the valid authorization and publish `SWV5_REQUEST_RISK_AUTHORIZED`; publication must precede future broker submission.
13. Advance through `SWV5_REQUEST_SUBMISSION_PENDING` only inside the serialized host stream, then pass the already-authorized request to a future Broker Adapter.
14. Record raw result-retcode evidence and classify it through the versioned Execution policy. Acknowledgement remains pending confirmation.
15. Capture platform transaction/deal evidence, validate correlation, ownership, sequence, symbol-specification and expected Basket version, then call `AcceptTransactionEvidence`.
16. Persist the complete returned pending-request state. Never reconstruct it locally.
17. Only authoritative confirmation may make a Basket transition, update confirmed/residual volume, or make a deal eligible for Statistics.
18. Atomically publish the resulting Basket, pending-request, accepted-event, Hard Kill, reconciliation, and checkpoint authority. Statistics consumes validated authoritative deal evidence downstream.

If an atomic publication boundary cannot be completed, the host does not expose a partially advanced authoritative state; it halts/reconciles according to the failure taxonomy.

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

Conceptual inputs are an already-validated and authorized submission request, current ownership fence, normalized units, and explicit query/margin requests. Conceptual outputs are raw submission evidence, raw retcode evidence, immutable transaction evidence, independently authoritative margin records, symbol specifications, and complete Broker-owned positions/orders/deals/transactions query snapshots.

The adapter does not classify retcodes by caller assertion and does not own directional decisions, Risk limits, Basket transitions, Recovery policy, request retry policy, Persistence governance, or Statistics. Execution owns the pending-request query domain. The adapter must never manufacture pending-request authority from broker state.

## Persistence And Atomic Publication

Authoritative persistable state includes:

- versioned record header, persistence namespace, ownership fence, store/CAS revision, record/previous sequence, timestamp, size, and digest
- complete Basket aggregate and lifecycle, state version, recovery counters, residual exposure, and accepted recovery identities
- ordered complete pending-request set and each complete returned pending-request state
- durable accepted transaction/deal identities and fingerprint mappings
- last confirmed request/broker correlation and transaction high-watermark
- Hard Kill state, release reference, and independently sourced release-authority linkage
- reconciliation vector, owner-specific Broker/Execution query high-watermarks, request-set identity, and reconciliation revision
- clean/dirty shutdown evidence

Acknowledgements, logs, UI state, and locally reconstructed summaries are not substitutes. Checkpoint publication and `PublishRestartQueryWatermarks` require compare-and-set against the observed store revision, expected record sequence, and current ownership fence. Accepted owner-specific query high-watermarks and their checkpoint metadata advance atomically. Failed publication must preserve the previously published checkpoint byte-for-byte and force reconciliation/halt.

The complete pending-request array, accepted identity sets, Hard Kill provenance, ownership authority, and reconciliation state cannot be reconstructed from the last request, current positions, logs, or counters after restart.

## Fail-Closed Startup And Restart Gate

The host begins runtime-disabled. A clean shutdown is evidence, never a bypass. The mandatory sequence is:

1. Pin the exact supported contract/policy versions; reject incompatible or unknown records without mutation.
2. Establish the intended ownership namespace and HEDGING account mode; unknown, Netting, or changed mode halts readiness.
3. Acquire or recover the instance lease through compare-and-set using the authoritative lease clock. Do not infer ownership from lease absence or missed heartbeat.
4. Load and validate the latest checkpoint and the full ordered pending-request set. Corrupt/incompatible state remains immutable evidence and causes the contract-defined corruption disposition.
5. Load Hard Kill state. A released historical latch additionally requires the independent authority record; it cannot be reconstructed from the checkpoint.
6. Obtain independently authoritative Broker Adapter snapshots for positions, orders, deals, and transactions, and the Execution-owned pending-request query snapshot.
7. Require the exact V5 closed query union: positions, orders, deals, transactions, and pending requests. Enforce source ownership, digest, freshness, observation sequence, and owner-specific persisted anti-replay high-watermarks.
8. Reconcile namespace, Basket identity/state/version, HEDGING mode, exposure and residual volume, positions/orders, complete request-set identity, latest correlations, transaction watermark, Hard Kill generation, ownership fence, and reconciliation revision.
9. Resolve uncertain or pending requests from authoritative transaction/deal/request evidence; never retry solely because the process restarted.
10. Validate every accepted-event identity set and fingerprint policy so replay remains idempotent after restart.
11. Require `SWV5_RESTART_SAFE_TO_RESUME` and the required reconciled Basket state. Every other disposition remains disabled, close-only, halted, or reconciliation-required as returned.
12. Atomically publish the reconciled checkpoint and accepted Broker/Execution query high-watermarks under the current fence and store revision.
13. Revalidate lease liveness, Hard Kill, account mode, symbol specification, and Risk authority at the enable boundary.
14. Only then may the host mark the namespace runtime-eligible. Every later event rechecks the authorities whose expiry or generation can invalidate eligibility.

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

Fence or lease mismatch removes mutation rights immediately. A stale host receiving broker events may capture immutable evidence and route it to reconciliation/audit, but it cannot accept the event into authoritative request/Basket state or publish a checkpoint. No implicit takeover is allowed.

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
| Broker transient rejection | Retain request; retry only after required backoff/revalidation | Execution |
| Unknown broker disposition | Retain pending/uncertain state; reconciliation required; no blind retry | Execution |
| Transaction conflict/out-of-order unknown | Retain evidence; reconciliation/halt as returned | Execution |
| Idempotent duplicate transaction/deal | Successful no-op; preserve authoritative version and counters | Execution / Statistics |
| Partial confirmation | Retain pending with residual exposure; no completion | Execution / Basket |
| Authoritative-state conflict | Halt/error; require reconciliation or operator | Basket / Persistence |

## Threat And Failure Matrix

| Threat / failure | Fail-closed response | Authority |
|---|---|---|
| Duplicate signal | Reject by canonical identity membership; no request | Signal Ingress |
| Stale signal | Reject against explicit authoritative freshness policy | Signal Ingress |
| Duplicate callback | Idempotent no-op through durable event membership | Execution |
| Out-of-order callback | Apply V5 sequence policy once or reconcile; never double-count | Execution |
| Unknown broker disposition | Keep uncertain; prohibit retry until reconciliation | Execution |
| Partial fill | Persist cumulative/residual state; no full Basket confirmation | Execution / Basket |
| Restart during pending request | Start disabled; query all domains; resolve from authority | Host / Persistence / Execution |
| Dirty shutdown | Full restart gate; clean flag cannot be inferred | Host / Persistence |
| Corrupt persistence | Preserve evidence; use contract disposition; never self-heal | Persistence |
| Lease loss | Revoke mutation/publication rights immediately | Instance Ownership |
| Two EA instances | Conflict; halt readiness; no implicit winner | Instance Ownership |
| Hard Kill during pending request | Latch durably; block increase; authorize only safe reduction path | Risk Governance / Execution |
| Broker reconnect | Keep uncertain requests pending; refresh queries and reconcile | Broker Adapter / Execution |
| Incomplete history/query snapshot | Runtime disabled; fail reconciliation | Broker Adapter / Execution / Persistence |
| Non-finite broker value | Reject before Risk, state, Statistics, or persistence mutation | Receiving V5 domain |
| Unit/specification mismatch | Invalidate normalization, Risk authorization, and request | Unit System |
| Wrong account mode | Halt readiness; HEDGING-only | Host / all bound V5 domains |

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
17. Sprint 5 Phase A authorizes no runtime code or broker API.
18. Every authoritative state change is returned by its owning V5 domain and durably published before dependent submission or readiness.
19. A stale ownership fence cannot mutate or publish authoritative state.
20. Signal, logical request, broker execution, Basket, and persistence identities remain distinct and explicitly correlated.

## OPEN ARCHITECTURE QUESTIONS

| Question | Why it matters | Blocking? | Proposed ADR owner | Blocks phase |
|---|---|---|---|---|
| Which physical store/lock technology proves the required durable compare-and-set, atomic publication, crash consistency, and authoritative lease clock on MT5? | V5 specifies semantics but not a technology. | Blocking | Persistence architecture owner | Phase D |
| What versioned broker/platform retcode table and transaction-order profile applies to each supported terminal/broker build? | Adapter classification and ordering cannot be guessed. | Blocking | Broker Adapter owner | Phase F |
| What are the canonical ingress serialization format, maximum freshness policy per execution mode, durable anti-replay retention/compaction policy, and producer trust provisioning mechanism? | ADR-009 fixes the boundary but implementation constants and trust material require reviewable policy. | Blocking | Signal Ingress owner | Phase B |
| What concrete host queue durability and capacity policy preserves captured transaction evidence during overload or process failure? | Single-writer semantics require a bounded failure policy, not silent event loss. | Blocking | EA Host owner | Phase C |
| What deployment authority provisions a new namespace's genesis Hard Kill/checkpoint state? | Missing persistence cannot be treated as clean authority. | Blocking | Operations/Risk Governance owner | Phase D |
| What exact Risk thresholds, trading-day configuration, and release-credential storage apply to a deployment? | Contracts define validation, not deployment values or secrets. | Blocking | Risk Governance owner | Phase E/F |
| What broker-specific Hedging fixtures and evidence threshold permit a Demo adapter to pass independent audit? | Architecture alone cannot prove broker behavior. | Blocking | Verification authority | Phase F/G |

No unresolved question permits an implementation phase to weaken or bypass V5. Each named phase remains blocked until its blocking question has an accepted ADR/policy and deterministic evidence plan.

## Proposed Sprint 5 Implementation Phases

| Phase | Scope | Entry gate | Exit gate |
|---|---|---|---|
| A | Architecture and ADRs only | Audited V5 merged; explicit Phase A authorization | Independent architecture review; no Critical/Major ownership conflict |
| B | Pure ingress DTO, orchestration DTOs, compatibility and validation contracts; no broker API | Phase A approved; ingress policy question resolved | Compile/static isolation; deterministic table specs; no runtime dependency |
| C | Deterministic single-writer reference coordinator with fake broker only | Phase B contracts approved; queue policy resolved | Event-order, duplicate, replay, uncertainty, partial-fill, and lease-loss fixtures pass |
| D | Persistence/restart reference implementation against a fake platform/store | Store/genesis ADRs approved | Crash/CAS/corruption/full-query/restart tests pass; no MT5 broker calls |
| E | Integrated V5 Risk, Basket, transaction, Hard Kill, Statistics, and recovery-boundary fixtures | Phases C/D pass; deployment Risk policy approved | Full positive/negative/cross-domain deterministic suite passes fail-closed |
| F | MT5 Demo Broker Adapter and Strategy Tester only | Broker profiles/retcodes accepted; independent safety authorization | Demo/tester compile and broker-specific evidence pass; no live chart/trading |
| G | Reproducible integration evidence and independent audit | Exact source freeze; all earlier gates pass | Immutable evidence, provenance, full audit, explicit go/no-go recommendation |

No phase authorizes live trading. Any production or live authorization requires a separate, explicit post-audit decision.

## Acceptance Criteria And Traceability

| Criterion | Architecture location |
|---|---|
| Every V5 authority has one runtime owner; no dual mutation owner | Architectural Components And Sole Authorities |
| Signal ingress and no competing direction are defined | Signal DTO Ingress Architecture |
| Host orchestration and serialization are deterministic | Single-Writer And Event Serialization Model |
| Contract-safe end-to-end order is defined | Safe Signal-To-Execution Pipeline |
| V5 Risk ordering/binding has no bypass | Risk Gate Ordering And Binding |
| Existing request states and identity phases are preserved | Execution Request Lifecycle |
| Broker and callback boundaries are explicit | Broker Adapter Boundary; Acknowledgement, Confirmation, And Transaction Ownership |
| Persistence, restart, and complete reconciliation are fail-closed | Persistence And Atomic Publication; Fail-Closed Startup And Restart Gate |
| Hard Kill, Recovery, Basket, Statistics, ownership, mode, and Units retain V5 authority | Corresponding domain sections |
| Failure taxonomy and threat matrix exist | Failure Taxonomy; Threat And Failure Matrix |
| Formal invariants and later phase gates exist | Formal Architecture Invariants; Proposed Sprint 5 Implementation Phases |
| No runtime API/source change or hidden approval is granted | Governance Status; Out Of Scope |

## Out Of Scope

Phase A explicitly excludes:

- `OrderSend`, `OrderSendAsync`, `CTrade`, or any trade call
- a real Broker Adapter or live `OnTradeTransaction` implementation
- order placement, position changes, or stop-loss/take-profit changes
- production persistence, filesystem, database, lease, or lock implementation
- recovery trading, grid, averaging, martingale, or hedging logic
- Signal Engine or `DecisionEngine` changes
- V3S integration, optimization, or parameter tuning
- Architecture Lock, runtime authorization, production readiness, production authorization, or live-trading authorization

## V3S Boundary

V3S remains an independent Research Lab. Its M5 logic, experiments, and discoveries are not Sprint 5 inputs and cannot authorize M15 execution. Any future hypothesis must complete the separate V3S validation and formal Fusion adoption process before it can become a reviewed Signal Engine change. Phase A creates no V3S dependency.

## Review Recommendation

This document is ready to be evaluated as an **Architecture Candidate / In Review** only after its documentation diff passes scope and consistency checks. The required next action is an **Independent Sprint 5 Architecture Review**. Runtime implementation, broker implementation, Architecture Lock, and production trading remain not granted.
