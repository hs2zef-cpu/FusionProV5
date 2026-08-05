# Sprint 4.1 Deterministic Contract Validation Specification

## Purpose

This document defines executable, table-driven requirements for Production Architecture contract version 2. It specifies expected behavior; Sprint 4.1 does not implement broker execution, stores, locks, or trading algorithms.

## Determinism Rules

- Every row supplies an explicit `SWV5_ContractValidationContext`.
- No validator may obtain time, prices, account state, symbol properties, files, randomness, or broker state internally.
- Identical DTOs and context produce identical output fields and reason codes.
- NaN, infinity, negative impossible values, unknown enums, missing identities, stale versions, and incomplete authoritative queries fail closed.
- Price and volume comparisons use only context-derived tolerances.
- Only `SWV5_DISPOSITION_ALLOW` authorizes an action. Fail-closed behavior is mandatory and has no caller override.
- Unknown or conflicting evidence never defaults to success.

## Common And Versioning Cases

| ID | Input | Expected result |
|---|---|---|
| COM-01 | Exact schema, minimum version, and policy ID | `EXACT`; canonical disposition permits the requested operation |
| COM-02 | Candidate schema below minimum compatible version | Rejected; migration required |
| COM-03 | Unknown policy ID | Rejected |
| COM-04 | Missing clock ID, clock authority, clock time, or clock sequence for an expiry decision | Fail closed |
| COM-05 | Repeated identical context and DTO | Byte-equivalent decision fields |
| COM-06 | Zero evaluation sequence where monotonic evidence is required | Invalid |
| COM-07 | Ownership fence differs anywhere in one cross-domain chain | Conflict and fail closed |
| COM-08 | Persistence namespace differs anywhere in one chain | Conflict and fail closed |
| COM-09 | Lease clock ID differs from validation clock ID | Invalid clock evidence |
| COM-10 | Cross-domain DTO has missing/incompatible contract identity | Rejected |
| COM-11 | Compatibility result does not echo the evaluated version identity | Invalid result |
| COM-12 | Caller requests fail-open behavior | Unsupported; no such contract field or interface parameter exists |

## Basket State Machine Cases

All 49 state pairs are specified below. Allowed transitions increment `state_version` exactly once. Forbidden and same-state evaluations leave it unchanged.

| ID | From | To | Disposition | Required evidence / result |
|---|---|---|---|---|
| BSM-01 | IDLE | IDLE | SAME | Observation only; version unchanged |
| BSM-02 | IDLE | OPENING | ALLOW | Matching fence/namespace, Risk allow, reconciliation matched, zero exposure/orders/pending; version +1 |
| BSM-03 | IDLE | ACTIVE | FORBID | Direct activation forbidden; version unchanged |
| BSM-04 | IDLE | RECOVERY | FORBID | No active Basket; version unchanged |
| BSM-05 | IDLE | CLOSING | FORBID | No close lifecycle; version unchanged |
| BSM-06 | IDLE | HALTED | ALLOW | Hard Kill or operator halt evidence; version +1 |
| BSM-07 | IDLE | ERROR | FORBID | No direct error transition; version unchanged |
| BSM-08 | OPENING | IDLE | FORBID | Must reconcile through CLOSING/HALTED; version unchanged |
| BSM-09 | OPENING | OPENING | SAME | Observation only; version unchanged |
| BSM-10 | OPENING | ACTIVE | ALLOW | Authoritative correlated transaction, positive exposure, complete queries, matching fence; version +1 |
| BSM-11 | OPENING | RECOVERY | FORBID | Opening cannot enter Recovery; version unchanged |
| BSM-12 | OPENING | CLOSING | ALLOW | Partial/residual exposure or reconciled cancellation; version +1 |
| BSM-13 | OPENING | HALTED | ALLOW | Hard Kill, fence loss, or uncertain broker evidence; version +1 |
| BSM-14 | OPENING | ERROR | ALLOW | Contract violation or contradictory authoritative evidence; version +1 |
| BSM-15 | ACTIVE | IDLE | FORBID | Must close and verify zero; version unchanged |
| BSM-16 | ACTIVE | OPENING | FORBID | Basket already active; version unchanged |
| BSM-17 | ACTIVE | ACTIVE | SAME | Observation only; version unchanged |
| BSM-18 | ACTIVE | RECOVERY | ALLOW | Recovery authorization and cumulative attempt increment; version +1 |
| BSM-19 | ACTIVE | CLOSING | ALLOW | Close authorization or mandatory Risk reduction; version +1 |
| BSM-20 | ACTIVE | HALTED | ALLOW | Hard Kill, fence conflict, or unavailable authoritative Risk data; version +1 |
| BSM-21 | ACTIVE | ERROR | ALLOW | Invariant or reconciliation failure; version +1 |
| BSM-22 | RECOVERY | IDLE | FORBID | Must close and verify zero; version unchanged |
| BSM-23 | RECOVERY | OPENING | FORBID | Cannot restart opening lifecycle; version unchanged |
| BSM-24 | RECOVERY | ACTIVE | ALLOW | Correlated recovery confirmation, no pending request, reconciled aggregate; version +1 |
| BSM-25 | RECOVERY | RECOVERY | SAME | Observation only; attempt/layer unchanged |
| BSM-26 | RECOVERY | CLOSING | ALLOW | Recovery denial, Risk close, or operator close; version +1 |
| BSM-27 | RECOVERY | HALTED | ALLOW | Hard Kill, fence conflict, or uncertain confirmation; version +1 |
| BSM-28 | RECOVERY | ERROR | ALLOW | Attempt/layer contradiction or reconciliation failure; version +1 |
| BSM-29 | CLOSING | IDLE | ALLOW | Zero residual/positions/orders/pending and all authoritative query flags complete; version +1 |
| BSM-30 | CLOSING | OPENING | FORBID | New exposure forbidden; version unchanged |
| BSM-31 | CLOSING | ACTIVE | FORBID | Close cannot reactivate Basket; version unchanged |
| BSM-32 | CLOSING | RECOVERY | FORBID | Recovery forbidden while closing; version unchanged |
| BSM-33 | CLOSING | CLOSING | SAME | Observation only; version unchanged |
| BSM-34 | CLOSING | HALTED | ALLOW | Close uncertainty or fence loss; version +1 |
| BSM-35 | CLOSING | ERROR | ALLOW | Broker facts contradict canonical lifecycle; version +1 |
| BSM-36 | HALTED | IDLE | ALLOW | Operator reset plus authoritative zero verification; version +1 |
| BSM-37 | HALTED | OPENING | FORBID | Exposure increase forbidden; version unchanged |
| BSM-38 | HALTED | ACTIVE | FORBID | Direct resume forbidden; version unchanged |
| BSM-39 | HALTED | RECOVERY | FORBID | Recovery forbidden; version unchanged |
| BSM-40 | HALTED | CLOSING | ALLOW | Matching fence, reconciliation matched, residual exposure exists; version +1 |
| BSM-41 | HALTED | HALTED | SAME | Observation only; version unchanged |
| BSM-42 | HALTED | ERROR | ALLOW | Reconciliation discovers contradiction; version +1 |
| BSM-43 | ERROR | IDLE | FORBID | Direct reset forbidden; version unchanged |
| BSM-44 | ERROR | OPENING | FORBID | New exposure forbidden; version unchanged |
| BSM-45 | ERROR | ACTIVE | FORBID | Direct resume forbidden; version unchanged |
| BSM-46 | ERROR | RECOVERY | FORBID | Recovery forbidden; version unchanged |
| BSM-47 | ERROR | CLOSING | FORBID | Must first establish known HALTED state; version unchanged |
| BSM-48 | ERROR | HALTED | ALLOW | Reconciliation establishes known state; version +1 |
| BSM-49 | ERROR | ERROR | SAME | Reconciliation observation only; version unchanged |

Unknown state or transition cause is invalid and fails closed.

## Basket Aggregate Cases

| ID | Input | Expected result |
|---|---|---|
| BAS-01 | Aggregate namespace Basket ID and lifecycle Basket ID differ | Invalid |
| BAS-02 | Recovery attempt regresses | Invalid |
| BAS-03 | Partial close event matches Basket and decreases volume once | Valid |
| BAS-04 | Duplicate partial-close event ID | Idempotent; no second decrement |
| BAS-05 | Partial close exceeds prior volume | Invalid |
| BAS-06 | Close evidence has zero residual but incomplete order query | Not complete |
| BAS-07 | Magic or symbol alone is used instead of the composite persistence namespace and Basket ID | Invalid attribution |
| BAS-08 | Unsupported account mode | Fail closed |

## Unit System Cases

| ID | Input | Expected result |
|---|---|---|
| UNT-01 | Tick size differs from point size | Price aligns to tick, not point |
| UNT-02 | Pip size missing | Specification invalid |
| UNT-03 | Volume between steps, exposure increase, round down | Conservative lower valid step |
| UNT-04 | Volume below minimum after rounding | Rejected |
| UNT-05 | Tick-value currency differs from account currency | Rejected unless an approved conversion contract exists |
| UNT-06 | Stops distance below StopsLevel | Rejected |
| UNT-07 | Operation violates FreezeLevel | Rejected |
| UNT-08 | Specification sequence changes after normalization | Normalized terms stale |
| UNT-09 | Missing bid/ask for directional stop validation | Rejected |
| UNT-10 | Floating boundary within declared tolerance | Deterministic aligned result |

## Instance Ownership Cases

| ID | Input | Expected result |
|---|---|---|
| OWN-01 | Unclaimed key and matching store revision | Acquire with version increment |
| OWN-02 | Active incumbent with different claimant | Conflict; execution must halt |
| OWN-03 | Missed heartbeat before authoritative expiry | Takeover forbidden |
| OWN-04 | Expired lease without reconciliation | Takeover forbidden |
| OWN-05 | Expired lease with broker and persistence reconciliation | Takeover eligible with generation increment |
| OWN-06 | Heartbeat owner/token/version mismatch | Rejected |
| OWN-07 | Release against stale observed store revision | Rejected |
| OWN-08 | Simultaneous heartbeat evidence | Conflict and halt |
| OWN-09 | Corrupt lock or unavailable authoritative clock | Recovery/operator required |
| OWN-10 | Fence lease version, generation, token digest, or store revision differs from the accepted lease | Stale-owner conflict; fail closed |
| OWN-11 | Lease clock ID differs from validation-context clock ID | Invalid lease evidence; fail closed |

## Execution Cases

| ID | Input | Expected result |
|---|---|---|
| EXE-01 | Valid normalized intent and unexpired authorization | Intent valid |
| EXE-02 | Accepted request retcode only | Confirmation remains pending |
| EXE-03 | Synchronous deal reported without transaction/history evidence | Confirmation remains pending |
| EXE-04 | Known permanent rejection | Terminal rejection; retry forbidden |
| EXE-05 | Connection uncertainty | Reconciliation required before retry |
| EXE-06 | Price or volume changed | Fresh normalization and Risk authorization required |
| EXE-07 | Transaction request/attempt identity, namespace, or Basket mismatch | Conflict; no Basket update |
| EXE-08 | Transaction expected-version mismatch | Reconciliation required |
| EXE-09 | Duplicate event ID/sequence | Idempotent; confirmed volume unchanged |
| EXE-10 | Out-of-order conflicting event | Reconciliation required |
| EXE-11 | Partial confirmed volume | Partial status and exact residual volume |
| EXE-12 | Retry exceeds maximum attempts | Forbidden |
| EXE-13 | Unknown raw retcode mapping | Fail closed; mapping unknown |
| EXE-14 | Order/deal/position/event/idempotency identity is missing where the event kind requires it | Correlation incomplete; no confirmation |
| EXE-15 | Transaction carries stale ownership fence | Conflict; halt and reconcile |
| EXE-16 | Confirmation is based only on request acknowledgement | Remains pending; no Basket state advancement |

## Persistence And Restart Cases

| ID | Input | Expected result |
|---|---|---|
| PER-01 | Exact version, digest, size, sequence, composite namespace, and ownership fence | Record valid |
| PER-02 | Digest or payload-size mismatch | Corrupt; never loaded healthy |
| PER-03 | Sequence regression or broken previous-sequence link | Rejected |
| PER-04 | Foreign namespace/Basket or stale ownership fence | Conflict |
| PER-05 | Persisted and broker summaries have matching complete correlation and complete queries | MATCHED; checkpoint rewrite permitted |
| PER-06 | Broker ahead | HALTED until reconciled checkpoint is written |
| PER-07 | Persistence ahead | HALTED or operator required; persisted intent cannot override broker |
| PER-08 | Any required broker/history/pending-request query incomplete | Canonical reconciliation status is a halt/manual outcome; never matched |
| PER-09 | Pending request disposition unknown | Blind retry forbidden |
| PER-10 | Corrupt latest record and valid prior record | Prior record is a clue only; broker reconciliation still required |
| PER-11 | Exclusive lease unconfirmed | Ownership conflict; no readiness |
| PER-12 | Active Hard Kill latch present at checkpoint | Restart result preserves active latch; exposure increase forbidden |
| PER-13 | Checkpoint pending count or set digest cannot be reconstructed from persisted request records | Conflict halt; blind retry forbidden |
| PER-14 | `LoadLatest` or pending-request lookup omits any composite namespace field | Request invalid; no BasketID-only lookup |
| PER-15 | Latest pending record does not match request-set membership evidence | Conflict halt; full pending set must be loaded |

## Risk Cases

| ID | Input | Expected result |
|---|---|---|
| RSK-01 | Hard Kill latched | Evaluated first; no exposure increase |
| RSK-02 | Ownership fence missing, stale, or inconsistent with intent/Basket | Block before financial calculations |
| RSK-03 | Account/exposure/projected snapshot incomplete or stale | Fail closed |
| RSK-04 | Equity below floor | Block or mandatory reduction per policy |
| RSK-05 | Daily loss exceeds limit under configured boundary | Block/Halt according to limits |
| RSK-06 | Aggregate exposure exceeds limit while Basket limit passes | Block in aggregate domain |
| RSK-07 | Basket loss exceeds limit | Close-only or halt according to limits |
| RSK-08 | Authorization correlation, Basket/state version, fence, specification sequence, intent type/direction, or normalized terms mismatch | Rejected |
| RSK-09 | Authorization expired at context time | Rejected |
| RSK-10 | Execution attempts larger volume than authorized | Rejected |
| RSK-11 | Hard Kill release missing operator/audit/reconciliation evidence | Rejected |
| RSK-12 | Restart with previously latched Hard Kill | Latch remains active |
| RSK-13 | Any account/exposure/Basket/projected snapshot sequence differs from the authorization binding | Authorization invalid |
| RSK-14 | Hard Kill latch ID or generation changes after evaluation | Authorization invalid |
| RSK-15 | Monetary currency, conversion basis, valuation time, calculation basis, sign convention, or component inclusion is missing | Projected Risk invalid |
| RSK-16 | Intent changes request attempt while correlation ID remains the same | Authorization invalid; reevaluation required |

## Statistics Cases

| ID | Input | Expected result |
|---|---|---|
| STA-01 | Authoritative attributed entry deal | Entry volume/count updated |
| STA-02 | Exit deal with profit, commission, swap, and fee | Net equals exact component sum |
| STA-03 | Partial close with residual volume | Partial count increments; Basket remains open |
| STA-04 | Event identity already proven present in the deduplication set | Idempotent duplicate; no double counting |
| STA-05 | Composite namespace, Basket, or full correlation chain mismatch | Attribution invalid |
| STA-06 | Missing monetary component completeness | Finalization fails closed |
| STA-07 | Incomplete history query | `history_complete=false`; final result not authoritative |
| STA-08 | Zero residual with complete exit chain | Basket statistical completion eligible |
| STA-09 | Netting mode under initial Hedging-only policy | Rejected |
| STA-10 | Older transaction arrives after a newer transaction but has a new valid event identity | Accumulated once; classified out-of-order without loss |
| STA-11 | Claimed duplicate lacks membership proof or prior set digest | Identity disposition invalid; fail closed |
| STA-12 | Same deal ticket appears under conflicting event/idempotency identity | Conflict; statistics not finalized |
| STA-13 | Currency or any profit/commission/swap/fee component is incomplete | Monetary completeness flag absent; finalization denied |

## Cross-Domain Cases

| ID | Scenario | Expected result |
|---|---|---|
| XDM-01 | Lease acquired, persistence matched, units valid, Risk allowed, transaction confirmed | Ordered state advancement only after each evidence gate |
| XDM-02 | Ownership lost after acknowledgement but before transaction | HALTED; reconcile transaction; no retry |
| XDM-03 | Crash with unconfirmed request | Restart halted; history queried; blind retry forbidden |
| XDM-04 | Partial close followed by restart | Residual exposure reconstructed and managed; never IDLE |
| XDM-05 | Symbol specification changes after Risk authorization | Authorization invalid; renormalize and reevaluate |
| XDM-06 | Hard Kill occurs during OPENING | Exposure increase stops; only reconciled reduction eligible |
| XDM-07 | Duplicate transaction after checkpoint replay | No duplicate volume, state transition, or statistics |
| XDM-08 | Store and broker both unavailable | ERROR/HALTED; never execution-ready |
| XDM-09 | Ownership fence changes between normalization, Risk, persistence, and transaction evidence | Stale-owner conflict; no execution or state update |
| XDM-10 | Hard Kill release evidence is present but latch/release generation does not match the durable checkpoint | Release rejected; latch remains active |
| XDM-11 | Pending request is acknowledged before crash but has no transaction/history confirmation | Restart reconciles; acknowledgement is never confirmation |
| XDM-12 | Partial close reports success while positions/orders/pending queries or residual volume remain nonzero | Basket remains CLOSING/HALTED; never IDLE |

## Required Test Record

Each future fixture records:

- Case ID and contract policy ID
- Complete input DTOs and validation context
- Expected boolean return
- Expected canonical disposition/status, reason code, and reason flags
- Expected resulting state/version/volume where applicable
- Actual result and deterministic replay result
- Pass, fail, or inconclusive status

No case is considered verified by compilation alone.
