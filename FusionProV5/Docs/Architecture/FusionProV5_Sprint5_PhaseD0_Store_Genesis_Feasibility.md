# Fusion Pro V5 Sprint 5 Phase D0 — Store And Genesis Feasibility

## Governance

| Item | Result |
|---|---|
| Architecture Review | **CLOSED** |
| Phase B pure-contract gate | **CLOSED / PASS** |
| Phase C deterministic orchestration gate | **CLOSED / PASS** at `55cd230ca222c60cd42dd218efe5e175ba70acd6` |
| D0 scope | **Documentation-only targeted ADR resolution** |
| Phase D implementation | **NOT AUTHORIZED** |
| MT5 Terminal / Strategy Tester / broker / trading | **NOT AUTHORIZED** |
| D0 self-assessment | **PASS — APPROVED CANDIDATES PENDING INDEPENDENT REVIEW** |

ADR-021 and ADR-022 resolve only the two intentionally deferred Phase D entry questions. ADR-009 through ADR-020 and the frozen Phase B/C sources are unchanged.

## Official MQL5 evidence

Reviewed 2026-08-27:

| Evidence | Official conclusion | D0 use |
|---|---|---|
| [Working with databases](https://www.mql5.com/en/docs/database) | MQL5 database functions use SQLite and expose explicit transaction APIs. | Establishes native SQLite candidate and transaction surface. |
| [DatabaseOpen](https://www.mql5.com/en/docs/database/databaseopen) | `DATABASE_OPEN_COMMON` places the database in the common folder of all terminals. | Establishes common shared-location model; does not alone prove contention behavior. |
| [DatabaseTransactionBegin](https://www.mql5.com/en/docs/database/databasetransactionbegin), [Commit](https://www.mql5.com/en/docs/database/databasetransactioncommit), [Rollback](https://www.mql5.com/en/docs/database/databasetransactionrollback) | MQL5 exposes explicit transaction begin/commit/rollback. | Supports one-domain atomic mutation and rollback. |
| [MQL5 SQLite transactions](https://www.mql5.com/en/book/advanced/sqlite/sqlite_transactions) | Describes ACID properties and consistent database state after interruption. | Supports crash-consistency candidate; real terminal/build evidence remains required. |
| [GlobalVariableSetOnCondition](https://www.mql5.com/en/docs/globals/globalvariablesetoncondition) | Atomic access/mutex for several EAs within one client terminal. | Explicitly insufficient as sole cross-terminal authority. |
| [TimeCurrent](https://www.mql5.com/en/docs/dateandtime/timecurrent) | Last-known server-formed quote time; independent of local computer settings. | Selected lease-clock observation source with stale/no-observation restrictions. |
| [TimeTradeServer](https://www.mql5.com/en/docs/dateandtime/timetradeserver) | Client-calculated and dependent on local computer time settings. | Rejected as independent lease-time authority. |

## Candidate comparison

Scores: `3` directly supports the requirement, `2` feasible with explicit protocol/evidence, `1` weak/limited, `0` unsuitable. Scores are architectural comparison, not runtime certification.

| Criterion | SQLite / MQL5 common DB | Terminal Global Variables | Raw common files + move/rename | External service/database |
|---|---:|---:|---:|---:|
| Cross-terminal visibility | 3 | 0 | 3 | 3 |
| Exact CAS feasibility | 3 | 1 | 1 | 3 |
| Transaction atomicity | 3 | 0 | 0 | 3 |
| Durability | 3 | 1 | 2 | 3 |
| Crash consistency | 3 | 1 | 1 | 3 |
| Corruption detection/linkage | 3 | 0 | 2 | 3 |
| Multi-writer behavior | 2 | 1 | 0 | 3 |
| Native common-folder support | 3 | 1 | 3 | 0 |
| Deterministic readback | 3 | 1 | 2 | 3 |
| Independent domain transactions | 3 | 0 | 0 | 3 |
| Phase D fake-store modelability | 3 | 1 | 2 | 2 |
| Added trust/deployment surface | 3 | 3 | 2 | 0 |
| Total / 36 | **35** | **10** | **18** | **29** |

SQLite is the only native MT5-safe option reviewed that combines a common path, conditional SQL mutation, explicit transactions, durable typed state, deterministic readback, and independent domain transactions. It is selected as an **approved candidate**, conditional on later cross-terminal platform evidence. Failure of that evidence blocks a real adapter.

## Physical authority summary

| Domain | Exact comparison authority | One-domain atomic result | Crash/uncertainty disposition |
|---|---|---|---|
| Lease | namespace + exact lease row/store revision + immutable fence + liveness fields | heartbeat preserving fence, acquisition, release, or takeover | authoritative readback; no takeover/reacquire inference |
| Ledger | header revision/digest + exact ordered index/records + fence | one accepted record/index/header or one compaction | preserve corrupt/partial evidence; disable authority |
| Sequence | allocator revision/digest + full correlation index + fence | idempotent existing sequence or unique next sequence | committed gaps allowed; never recycle |
| Submission/Claim | exact authority revision/digest/state + permit/request/attempt + current fence | one state transition to claimed | claimed is uncertain; never recreate event-local grant |
| Request set | exact set/store revisions, digest, sequence, fence, takeover generation | complete ordered set + next identities | dirty/unresolved until authoritative reload |
| Checkpoint | exact store revision, prior sequence, projection digest, fence, takeover generation | one complete next checkpoint | dirty/unresolved; no clean-shutdown inference |

Request set and checkpoint remain separate transactions ordered as: request set, authoritative reload/validation, checkpoint. No global transaction exists.

## Lease-clock feasibility

The selected source is a Platform Clock Adapter's current-event `TimeCurrent()` observation, identified as broker-server authority and ordered by a DB-backed monotonic sequence. The DB sequence orders evidence but does not manufacture wall time. Equal-second current observations may receive distinct sequences; expiry is still decided from server-formed timestamps. No new server observation, cached/stale observation, regression, wrong authority, or restart-only stored value proves expiry. `TimeTradeServer`, local time, UTC, tick counters, queue ordinals, and database revisions are rejected as lease wall-clock authority.

## Genesis summary

The separate Operator/Deployment Genesis Provisioning Authority creates one canonical identity and a fail-closed initial manifest. Absence is not clean. Initial Hard Kill is `ACTIVE`, release generation is zero, checkpoint `clean_shutdown=false`, reconciliation is required, request/Ledger/Sequence/Submission collections are canonically empty, and ownership is explicitly unclaimed. Normal runtime cannot use bootstrap envelopes as operational authority. Fresh full-query zero-state reconciliation and independent Hard Kill release evidence are required before increasing execution could become eligible.

## D0 threat matrix

| # | Threat | Comparison authority | Atomic primitive | Resulting durable state | Fail-closed disposition | Future Phase D test |
|---:|---|---|---|---|---|---|
| 1 | Two writers, same expected revision | exact domain row/revision/digest/fence | conditional SQL mutation in transaction | exactly one next revision | loser reloads; no overwrite | `CAS-TWO-WRITERS` |
| 2 | Stale writer | current revision/digest/fence | conditional SQL mutation | current row unchanged | stale/conflict | `CAS-STALE` |
| 3 | DB busy/locked | SQLite lock result | begin/statement boundary | no assumed change | unavailable/reconcile | `CAS-BUSY` |
| 4 | Crash before CAS | prior committed row | transaction boundary | prior state | restart reload | `CRASH-PRE-CAS` |
| 5 | Crash during transaction | SQLite transaction journal | rollback/recovery | prior committed state | reload/validate | `CRASH-IN-TXN` |
| 6 | Crash after commit before observation | authoritative committed row | commit + readback protocol | prior or exact next state | uncertain; reconcile; no blind retry | `CRASH-POST-COMMIT` |
| 7 | Corrupt row digest | canonical row digest | read validation | corruption preserved | halt/operator | `CORRUPT-ROW` |
| 8 | Corrupt header/index linkage | complete ordered linkage digest | domain read validation | corruption preserved | halt/operator | `CORRUPT-LINKAGE` |
| 9 | Request set committed, checkpoint absent | separate domain revisions | ordered separate transactions | new set + old checkpoint | dirty/unresolved | `CRASH-SET-BEFORE-CP` |
| 10 | Sequence reserved, Ledger absent | Sequence authority index | Sequence transaction | permanent unused sequence | gap retained; reconcile | `CRASH-SEQ-BEFORE-LEDGER` |
| 11 | Claim committed, caller crashes before broker | Submission authority state | claim CAS | claimed unresolved | no grant replay; reconcile | `CRASH-CLAIM-PRE-BROKER` |
| 12 | Heartbeat race | exact lease store revision/fence | lease CAS | one heartbeat revision | loser reloads | `LEASE-HEARTBEAT-RACE` |
| 13 | Takeover race | stale lease + expiry + reconciliation evidence | lease takeover CAS | one new fence/generation | losers stale; no takeover | `LEASE-TAKEOVER-RACE` |
| 14 | Regressed/stale clock | clock ID/authority/time/sequence | clock-row CAS | prior observation | no takeover/admission | `CLOCK-STALE-REGRESS` |
| 15 | No server-time observation | current-event provenance | none | prior observation only | no expiry proof | `CLOCK-NO-OBSERVATION` |
| 16 | Same-second observations | platform event + clock sequence | clock-row CAS | same timestamp, higher sequence | no manufactured future time | `CLOCK-SAME-SECOND` |
| 17 | Genesis absent | unique namespace metadata | genesis insert CAS | no operational state | not provisioned/runtime disabled | `GENESIS-ABSENT` |
| 18 | Genesis partial | genesis state + manifest | per-domain transactions + final CAS | `PROVISIONING` retained | operator intervention | `GENESIS-PARTIAL` |
| 19 | Duplicate identical provisioning | genesis ID/manifest digest | read/compare | same completed genesis | idempotent no-op | `GENESIS-DUPLICATE` |
| 20 | Conflicting provisioning | namespace + genesis ID/digest | insert/compare CAS | original retained | conflict/halt | `GENESIS-CONFLICT` |
| 21 | Stale host request-set overwrite | set/store revisions + fence/generation | request-set CAS | current set retained | stale owner/revision | `PUBLICATION-STALE-SET` |
| 22 | Stale host checkpoint overwrite | store/record revisions + fence/generation | checkpoint CAS | current checkpoint retained | stale owner/revision | `PUBLICATION-STALE-CP` |

## Future Phase D boundary

After both ADRs pass a new independent review and Phase D is separately authorized, Phase D may implement only:

- a deterministic fake transactional store matching the selected SQLite/CAS semantics;
- a fake authoritative clock matching the observation protocol;
- lease, Ledger, Sequence, Submission/Claim, request-set, checkpoint, genesis, and restart reference behavior;
- authoritative readback and corruption validation; and
- deterministic crash/fault injection.

Phase D must not add real MQL5 `Database*` calls unless a later explicit scope authorizes them. It must not add broker calls, live account access, real persistence deployment, runtime wiring, or trading.

## Future Phase D exit tests

| Family | Mandatory coverage |
|---|---|
| CRASH | before mutation, during transaction, after commit-before-observation, set-before-checkpoint, sequence-before-Ledger, claim-before-broker |
| CAS | one winner, stale revision/fence/generation, identical replay, conflict, heartbeat/takeover races |
| CORRUPTION | row digest, header/index linkage, partial membership, schema/version, namespace collision, partial genesis |
| FULL-QUERY | all mandatory Broker/Execution query domains, wrong authority, missing/stale/incomplete evidence |
| RESTART | clean/dirty, claimed uncertainty, pending request reconstruction, monotonic watermarks, no blind retry |
| GENESIS | absent, unique create, exact duplicate, conflict, partial, first operational publication |
| LEASE/TAKEOVER | same-owner fence stability, clock failure, expiry evidence, reconciliation prerequisites, stale owner rejection |
| SEQUENCE | same-correlation idempotency, different-correlation uniqueness, permanent crash gap |
| PUBLICATION | complete ordered request set, reload-before-checkpoint, stale set/checkpoint overwrite rejection |
| CLAIM JOURNAL | one event-local grant, persisted claimed no grant, restart/takeover uncertainty |

## Self-pass result

The package selects a concrete candidate, defines falsifiable CAS/clock/genesis behavior, preserves every frozen authority boundary, and contains documentation only. It is ready for a new independent D0 ADR review; Phase D implementation remains unauthorized.
