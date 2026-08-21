# Fusion Pro V5 Sprint 4 Production Architecture

## Status And Boundary

Sprint 4 defines production contracts only. It contains no broker command path, concrete execution coordinator, concrete persistence store, concrete lock store, recovery algorithm, or basket execution algorithm.

The frozen Signal Engine remains Sprint 3.2.1. Its `DecisionEngine` produces the final signal DTO. A future execution host may consume that DTO only through a separately approved ingress contract. Sprint 4 does not connect the two layers at runtime.

## Sprint 4.1 Hardening Overlay

Governance status: **MERGED / AUDITED / UNLOCKED — FORMAL ARCHITECTURE APPROVAL PENDING**. Sprint 4 remains the authorized architecture baseline. The audited Production Contract V5 overlay is present on main, is not Architecture Locked, and grants no runtime authorization.

Sprint 4.1 introduced contract schema version 2, Sprint 4.3 advanced the corrective package to version 3, and Sprint 4.5 advanced it to version 4. Sprint 4.8 completed Production Contract V5 with minimum compatible version 5. V3 added monotonic recovery evidence, phase-specific execution identity, reconstructible pending requests, full account namespace/epoch and mode binding, typed takeover and Hard Kill release evidence, durable identity indexes, and the earlier Unit safety model. V4 completed durable evidence fingerprinting, full Risk authorization rebinding, contract-derived Unit operation semantics, and separation of ownership authority from mutable heartbeat/store revision. V5 adds the audited authority, canonical serialization, reconstruction, finite-value, reconciliation, query-snapshot, and evidence-credibility closures without authorizing runtime implementation.

Sprint 4.2 through Sprint 4.8 form the verification and corrective history behind the merged V5 package. Sprint 4.3 replaced the helper-only verification claim with interface-level implementations; Sprint 4.4 completed restart, payload-integrity, authorization-output, durable-identity, and ownership-mutation semantics; Sprint 4.5 applied further authority-binding, canonical-validation, ownership/persistence, Risk/Unit, and credibility hardening; Sprint 4.6 became failed-candidate history; Sprint 4.7 closed the resulting adversarial safety, coverage, and evidence-reproducibility findings; and Sprint 4.8 completed V5 and its immutable verification. The Final Independent Merge Audit passed with no Critical or Major findings, all six Critical and three prior Final-Audit MAJOR findings closed, infrastructure closure matrix all pass, and Merge Safety SAFE. Evidence commit `87f77c8b0b9253c2a851540085f8b7ce14cf2e52` was fast-forwarded into main with no merge commit. No verification milestone or merge declares Architecture Lock, grants runtime authorization, or changes Sprint 4 as the authorized baseline through implication.

Every contract operation receives an explicit validation context containing expected version identity, one clock ID/authority/time/sequence, evaluation sequence, and numeric tolerances. Contract validators may not obtain hidden wall-clock, broker, account, symbol, file, or random input. Fail-closed behavior is mandatory and cannot be disabled by a caller.

The accepted ADR set fixes these boundaries:

- Execution remains outside the indicator.
- Initial future execution support is Hedging-only; Netting is rejected until separately modeled.
- Persistence and leases require compare-and-set evidence and authoritative time.
- Raw retcodes are mapped by policy; acknowledgements never confirm Basket state.
- Pip is explicit and normalization is bound to a symbol-specification sequence.
- Hard Kill is durable and release requires independent auditable operator evidence.

Sprint 4.1 still contains no concrete production implementation.

## Ownership Model

| Domain | Sole future owner | Authority consumed | Forbidden ownership |
|---|---|---|---|
| Signal decision | Existing `DecisionEngine` | Immutable Signal Engine snapshots | Production contracts cannot rewrite the signal. |
| Instance lease | Instance Ownership service | Atomic lease record and heartbeat clock | Basket and execution components cannot self-elect. |
| Basket lifecycle | Basket State Machine | Confirmed transaction evidence and reconciled broker state | Signal, dashboard, and statistics cannot transition state. |
| Broker request lifecycle | Execution Coordinator | Result-retcode evidence and transaction events | Basket state cannot assume request success. |
| Risk authorization | Risk Gate | Authoritative account, basket, exposure, and equity snapshots | Execution cannot bypass or extend authorization. |
| Persistence | Persistence service | Versioned checkpoints and reconciled broker facts | Persisted data cannot override live broker state. |
| Statistics | Statistics service | Authoritative deal history only | Runtime counters and requested volume are not accounting truth. |
| Units | Unit System | Symbol-native broker specification | Strategy code cannot infer pip, tick, or lot-step rules. |

## Basket State Machine

States are `IDLE`, `OPENING`, `ACTIVE`, `RECOVERY`, `CLOSING`, `HALTED`, and `ERROR`.

### Allowed Transitions

| From | To | Required evidence |
|---|---|---|
| IDLE | OPENING | Exclusive owner, valid risk authorization, zero exposure, zero pending requests, new BasketID. |
| IDLE | HALTED | Hard Kill or explicit operator halt. |
| OPENING | ACTIVE | Confirmed exposure, no unresolved submission, basket version match. |
| OPENING | CLOSING | Partial/residual exposure must be removed or opening must be cancelled and reconciled. |
| OPENING | HALTED | Hard Kill, ownership loss, or uncertain broker state. |
| OPENING | ERROR | Contradictory authoritative evidence or contract violation. |
| ACTIVE | RECOVERY | Separately approved future recovery authorization and monotonic cumulative attempt increment. |
| ACTIVE | CLOSING | Close authorization or mandatory risk reduction. |
| ACTIVE | HALTED | Hard Kill, ownership conflict, or unavailable authoritative risk data. |
| ACTIVE | ERROR | State invariant or reconciliation failure. |
| RECOVERY | ACTIVE | Recovery request confirmed, no pending request, aggregate state reconciled. |
| RECOVERY | CLOSING | Recovery denied, risk close, or operator close. |
| RECOVERY | HALTED | Hard Kill, ownership conflict, or uncertain confirmation. |
| RECOVERY | ERROR | Attempt/layer contradiction or reconciliation failure. |
| CLOSING | IDLE | Authoritative confirmation of zero positions, zero orders, zero residual volume, and zero pending requests. |
| CLOSING | HALTED | Close remains uncertain or ownership is lost. |
| CLOSING | ERROR | Broker facts contradict the basket ledger. |
| HALTED | CLOSING | Ownership and broker state reconciled and residual exposure exists. |
| HALTED | IDLE | Operator reset after authoritative zero-residual confirmation. |
| HALTED | ERROR | Reconciliation discovers contradictory state. |
| ERROR | HALTED | Reconciliation establishes a known state; future action remains disabled. |

### Forbidden Transitions

All transitions not listed above are forbidden. Critical examples:

- IDLE directly to ACTIVE, RECOVERY, or CLOSING
- OPENING directly to RECOVERY or IDLE
- ACTIVE directly to IDLE
- RECOVERY directly to IDLE or OPENING
- CLOSING back to ACTIVE, RECOVERY, or OPENING
- HALTED directly to ACTIVE, RECOVERY, or OPENING
- ERROR directly to IDLE, ACTIVE, RECOVERY, OPENING, or CLOSING

A same-state event is not a transition and must not increment `state_version`.

### State Invariants

- Every non-IDLE basket has a stable, nonempty BasketID and confirmed exclusive owner.
- `state_version` and `recovery_attempt` are monotonic and cannot be reconstructed from open-position count.
- IDLE requires zero exposure, zero residual volume, zero pending requests, and confirmed close state.
- OPENING has exactly one authorized opening lifecycle and cannot issue unrelated exposure requests.
- ACTIVE requires reconciled positive exposure and no unresolved opening request.
- RECOVERY records cumulative attempt and current layer separately. The state defines no recovery algorithm.
- CLOSING forbids new exposure and cannot reset to IDLE before zero-residual confirmation.
- HALTED forbids exposure-increasing actions. Risk-reducing action requires fresh authorization and ownership.
- ERROR permits reconciliation only. It cannot silently reset lifecycle data.
- Partial close never means basket completion while residual volume, position, order, or pending request remains.

## Basket Contract

- `BasketID` is stable for the full lifecycle and is never inferred from position count.
- `Magic` scopes strategy attribution but is not a unique BasketID.
- `RecoveryAttempt` is a cumulative monotonic counter for all authorized attempts.
- `RecoveryLayer` describes the currently represented layer and never substitutes for cumulative attempts.
- `Residual Position` is authoritative broker volume remaining after confirmed deals.
- `Partial Close` is a deal-history event that updates closed and residual volume without ending the basket.
- `Close Verification` requires authoritative zero positions, zero orders, zero residual volume, and zero pending requests.

## Persistence Contract

### Versioning

Every checkpoint carries contract name, schema version, minimum compatible version, monotonic record sequence, previous sequence, payload digest, payload size, writer identity, BasketID, and timestamp.

An incompatible, truncated, checksum-failed, regressed, or foreign-owner record is never loaded as healthy state.

### Restart Reconciliation

1. Begin with execution disabled.
2. Acquire or recover the exclusive instance lease.
3. Load the latest verified checkpoint without trusting it as broker truth.
4. Query authoritative positions, orders, transactions, and deal history.
5. Compare BasketID, Magic, symbol, exposure, tickets, pending requests, and lifecycle version.
6. Resolve to MATCHED, BROKER_AHEAD, PERSISTENCE_AHEAD, CONFLICT, CORRUPT, OWNERSHIP_CONFLICT, or MANUAL_REQUIRED.
7. Enter HALTED or ERROR for every unresolved result.
8. Write a reconciled checkpoint before any future execution readiness can be considered.

### Crash Recovery And Corruption

- An unconfirmed pending request is never blindly retried after restart.
- Transaction and deal history are queried before request disposition is selected.
- A corrupt latest record may fall back only to a previously verified checkpoint as a reconciliation clue.
- Live broker facts remain authoritative over persisted intent.
- No checkpoint may be overwritten by an instance that does not hold the current lease.
- Durable write, digest verification, sequence validation, and atomic publication are required of any future store implementation.

## Execution Contract

### Request Lifecycle

`CREATED -> RISK_AUTHORIZED -> SUBMISSION_PENDING -> ACKNOWLEDGED -> CONFIRMATION_PENDING -> CONFIRMED`

Alternative terminal states are `PARTIALLY_CONFIRMED`, `REJECTED`, `EXPIRED`, `RECONCILIATION_REQUIRED`, and `CANCELLED`.

Each logical intent has a pre-submission request identity containing correlation ID, attempt ID, parent attempt, idempotency key, and monotonic sequence. It contains no broker-generated future identity. Broker order, deal, position, event, and transaction identities enter only at acknowledgement or authoritative evidence phases. Basket version, normalized units, risk authorization, account mode, and authorization expiry are bound to the intent.

Execution phases are `Intent`, `Submission`, `Acknowledgement`, `Authoritative Confirmation`, `Partial Fill`, and terminal `Completed`, `Rejected`, or `Uncertain`. Acknowledgement never confirms Basket state.

### ResultRetcode Policy

- A request-level accepted result means pending confirmation, not completed basket state.
- Permanent rejection is terminal and cannot be retried unchanged.
- Transient rejection requires bounded backoff and full preflight revalidation.
- Price or volume change requires new normalization and risk authorization.
- Connection uncertainty requires reconciliation before any retry.
- Unknown classifications fail closed.

### Transaction Ownership And Confirmation

The future EA host owns the platform transaction callback. It must convert each callback into immutable `SWV5_TransactionEvidence` and deliver it to one Execution Coordinator. No other component may independently mutate request or basket state from the callback.

Only transaction/deal evidence can confirm volume and price. A Basket transition is allowed only after the Execution Coordinator produces confirmation tied to the request ID and expected basket version.

### Retry Policy

- Retries are bounded by count and backoff.
- Every attempt receives a unique attempt ID.
- Risk authorization and normalized units are refreshed when expired or invalidated.
- An uncertain prior attempt blocks retry until reconciliation proves its disposition.
- Retry cannot create a second logical basket or reset recovery-attempt counters.

## Risk Contract

Risk evaluation is fail-closed and ordered:

1. Hard Kill latch
2. Ownership and authoritative-data availability
3. Account Risk and margin capacity
4. Equity floor and Daily Loss
5. Aggregate Exposure across strategies/baskets
6. Symbol Exposure
7. Basket Risk and hard basket loss
8. Projected request risk

Risk domains remain separate. Account limits cannot be replaced with basket metrics, and basket limits cannot claim account-wide safety.

A risk authorization is short-lived, immutable, and bound to request ID, basket state version, normalized terms, and evaluation timestamp. Execution cannot increase volume, change price terms, or reuse an expired authorization.

Hard Kill is latched. It permits only contract-approved risk reduction, reconciliation, and operator-reviewed release. Restart does not clear it.

## Statistics Contract

Authoritative statistics are rebuilt from deal history attributed by BasketID, Magic, symbol, position identifier, and ticket chain.

For each deal:

```text
net_result = gross_profit + commission + swap + fee
```

Partial closes increment exit-deal and partial-close counts and reduce residual volume. They do not close the basket statistically while authoritative residual volume remains. Runtime counters, requested volume, and UI state are never accepted as accounting truth.

## Duplicate Instance Contract

The ownership key is account login + server + symbol + strategy ID + Magic.

- Acquisition uses a versioned lease and compare-and-set semantics.
- Heartbeats renew only the matching owner and lease version.
- A missed heartbeat does not authorize immediate takeover.
- Takeover requires lease expiry plus persistence and broker reconciliation.
- Simultaneous heartbeats or differing owners for one key are conflicts and halt execution readiness.
- Lock corruption requires operator or reconciliation policy; it never defaults to ownership.
- Release is accepted only from the current owner and must preserve evidence for crash diagnosis.

## Unit System Contract

- Point is the broker quote-point size.
- Tick is the minimum valid price increment.
- Price values are normalized to tick size, not merely decimal digits.
- Pip is explicit symbol metadata or strategy configuration; it is never inferred universally from point.
- Volume is bounded by minimum and maximum and aligned to volume step.
- LotStep is represented by `volume_step`; rounding direction must be explicit for risk intent.
- TickValue uses broker profit/loss values and account currency; stale or incomplete values block authorization.
- StopsLevel is validated for initial protective/trigger distances.
- FreezeLevel is validated for operations near current market price.
- Price, stop, limit, and volume are renormalized after any broker specification change.
- Floating-point comparisons use tick/step tolerances derived from symbol specification.

## Interfaces

| Interface | Contract responsibility |
|---|---|
| `ISWV5BasketStateMachineContract` | Validate lifecycle state and transition invariants. |
| `ISWV5BasketContract` | Validate aggregate, partial close, residual exposure, and close completion. |
| `ISWV5PersistenceContract` | Validate/load/save versioned checkpoints and reconcile restart. |
| `ISWV5ExecutionContract` | Validate intents, classify retcodes, accept transaction evidence, and evaluate retry. |
| `ISWV5RiskContract` | Validate limits and issue immutable risk authorization. |
| `ISWV5StatisticsContract` | Validate and accumulate authoritative deal evidence. |
| `ISWV5InstanceOwnershipContract` | Acquire, heartbeat, detect conflict, and release leases. |
| `ISWV5UnitSystemContract` | Validate symbol units and normalize terms. |

These are abstract contracts. Sprint 4 provides no concrete implementation.

Every method consumes `const SWV5_ContractValidationContext &context`. The context remains part of the version 5 merged-but-unlocked interface contract and makes expiry, freshness, ordering, and floating-point decisions reproducible in table-driven fixtures.

## Data Flow

```text
Frozen Signal Engine Decision DTO
              |
              v
Future Signal Ingress (not implemented)
              |
              v
Instance Ownership -> Unit Validation -> Risk Authorization
              |                              |
              +-------------> Execution Intent
                                      |
                                      v
                         Future Broker Adapter
                                      |
                         Retcode + Transaction Evidence
                                      |
                                      v
                         Execution Confirmation
                                      |
                +---------------------+--------------------+
                v                     v                    v
       Basket State Machine     Persistence          Deal Statistics
```

No arrow in this diagram is connected at runtime in Sprint 4.

## Lifecycle Safety Order

1. Establish exclusive ownership.
2. Load and validate persistence.
3. Query authoritative broker state and deal history.
4. Reconcile before selecting lifecycle state.
5. Validate symbol units.
6. Evaluate all risk domains.
7. Register an immutable pending request before future submission.
8. Treat request acknowledgement as pending.
9. Confirm through transaction/deal evidence.
10. Transition basket state and persist the new version.
11. Rebuild statistics from authoritative deals.

## Known Design Risks

- The physical persistence and atomic-lock technologies are not selected; required compare-and-set semantics are defined.
- Initial future support is Hedging-only. Netting remains explicitly unsupported.
- Broker-specific transaction ordering and duplicate behavior have specified fixtures but no broker evidence.
- Retcode classification requires a versioned broker/platform mapping table before implementation.
- Pip semantics require explicit symbol-specific configuration or authoritative metadata.
- Risk thresholds remain unconfigured; Hard Kill release governance is defined but not implemented.
- Contract interfaces have an implemented, executed, deterministic test-only suite. It is verification evidence, not production implementation.

## Sprint Boundary

Sprint 4 stops at architecture. Implementation of adapters, stores, locks, risk calculations, broker requests, recovery behavior, basket execution, or signal-to-execution wiring requires a new explicitly authorized Sprint.

The audited Production Contract V5 package is merged to main but remains unlocked until explicit formal Architecture Lock approval. Sprint 4.2 through Sprint 4.8 provide its verification and corrective evidence history. Merge or later Architecture Lock would not by itself authorize runtime implementation; the next technical work requires separately approved Sprint 5 scope for any future Execution Layer or EA Host.
