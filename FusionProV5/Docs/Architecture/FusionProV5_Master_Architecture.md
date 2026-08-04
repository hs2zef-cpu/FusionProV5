# Fusion Pro V5 — Master Context and Architecture Constitution

**Fusion Pro V5**  
**Master Architecture Constitution**

| Metadata | Value |
|---|---|
| Version | 2.0 |
| Date | 2026-08-03 |
| Status | **ACTIVE** |
| Authorized Baseline | **Sprint 4 Architecture** |

## Revision History

| Version | Date | Summary |
|---|---|---|
| 1.0 | 2026-08-02 | Initial official Architecture Constitution after Sprint 3.2 Patch 1. |
| 1.1 | 2026-08-03 | Authorized Sprint 3.2.1 history-token hardening baseline and runtime evidence gate. |
| 2.0 | 2026-08-03 | Authorized isolated Sprint 4 production contracts; Sprint 3.2.1 frozen as Signal Engine baseline. |

## Purpose

This document is the authoritative context for all future Fusion Pro V5 conversations, architecture reviews, audits, and Codex tasks.

It exists to prevent unauthorized implementation, baseline confusion, Signal Engine and Execution Layer coupling, unverified reuse of `XAU_Scalper_AI_v17`, weakening of established architecture, and misclassification of intentionally deferred work as defects.

## Authoritative Baseline

The current authorized architecture project is **Fusion Pro V5 Sprint 4 Architecture**.

The frozen Signal Engine baseline is **Fusion Pro V5 Sprint 3.2.1**. Sprint 4 does not modify or runtime-wire it.

Project:

`C:\Users\Nutthakrit\Documents\FusionProV5`

Main source:

`SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_ARCHITECTURE.mq5`

Latest verified MetaEditor compilation:

- Errors: `0`
- Warnings: `0`
- Target: X64 Regular
- Production contract version: V1
- Frozen Signal snapshot schema: V5

The previous Sprint 3.2 Patch 1 project remains unchanged and available as the rollback baseline.

Sprint 3.2 Patch 1 changed only these defaults:

```mql5
input bool InpExportTrendRegressionCsv = true;
input bool InpExportMomentumRegressionCsv = true;
```

`InpLogTrendRegression` and `InpLogMomentumRegression` remain `false`.

The original V4.2 source and `SW_FIBO_BASIC_V3.mq5` remain unchanged.

## Status Vocabulary

- **Implemented:** Present in the authorized baseline and compile-verified.
- **Evidence pending:** Implemented, but required MT5 runtime artifacts have not been inspected.
- **Deferred by design:** Intentionally outside the current Sprint or Signal Engine boundary.
- **Unauthorized:** Created without an approved Sprint scope and must not be treated as project work.
- **Production-ready:** Must never be claimed from compilation or static analysis alone.

## Completed Sprints

| Sprint | Authorized scope |
|---|---|
| Sprint 1 | Architectural skeleton: Platform Adapter, IndicatorCache, snapshots, engines, orchestrator, DecisionEngine, dashboard, and legacy compatibility. |
| Sprint 1.1 | Typed DTOs, validation, snapshot metadata, engine health, normalized score/confidence contracts, and stronger ownership boundaries. |
| Sprint 2 | Exact V4.2 H1 trend gate and H4 macro-direction migration with independent regression comparison. |
| Sprint 2.1 | Read-only dashboard converted to a framed chart-object overlay. |
| Sprint 2.2 | Configurable panel corner, offsets, font size, and row spacing. |
| Sprint 3 | Isolated V4.2 Momentum evidence migration and independent regression comparison. |
| Sprint 3.1 | Typed regression diagnostics, dashboard auto-height, and default Y offset 150. |
| Sprint 3.2 | Score-semantics closure, centralized validation ownership, Price Action visibility, history/stale producers, and CSV evidence writer. |
| Sprint 3.2 Patch 1 | Trend and Momentum CSV export enabled by default for verification. No runtime logic changed. |
| Sprint 3.2.1 | Nonpositive history-token hardening, explicit fail-closed diagnostics, preserved last-valid baseline, and expanded CSV decision evidence. |
| Sprint 4 Architecture | Isolated production Basket, Persistence, Execution, Risk, Statistics, Instance Ownership, and Unit System contracts. No runtime implementation. |

## Architecture Boundary

Fusion Pro V5 Sprint 3.2.1 remains the frozen **MT5 Indicator and Signal Engine**.

Fusion Pro V5 Sprint 4 Architecture is an isolated **production contract layer**. It defines types, ownership, interfaces, lifecycle rules, and evidence requirements only. It is not an automated trading system and is not connected to the Signal Engine at runtime.

It is not an automated trading EA.

It does not own:

- Orders or pending orders
- Open positions
- Basket lifecycle
- Recovery
- Trade execution
- Production persistence
- Transaction reconciliation
- `OnTradeTransaction`
- Trade-history statistics
- Execution-instance ownership

These responsibilities belong to a future Execution Layer or separate EA host unless an approved Architecture Decision Record explicitly changes this boundary.

Execution-related contracts may be designed in a future approved Sprint. Execution logic must not be inserted into the indicator merely because it may eventually be useful.

```text
Market / Indicator Data
        ↓
Immutable Snapshot
        ↓
Independent Signal Engines
        ↓
DecisionEngine
        ↓
Signal DTO
        ↓
Future Execution Layer / EA
        ↓
Broker
```

The Dashboard reads DTOs only and remains outside the decision path:

```text
Immutable Snapshot / Engine Results / Decision Result
                         ↓
                  Read-Only Dashboard
```

The current `ExecutionPolicy` name refers to an advisory signal-policy gate inside the indicator. It is not a broker execution adapter and must not be interpreted as one.

## Current Architecture

| Component | Current responsibility |
|---|---|
| Platform Adapter | Owns terminal market, history, session, spread, and stale-data access outside indicator-buffer reads. |
| IndicatorCache | Sole owner of indicator handles and every `CopyBuffer()` call. |
| Market Snapshot | Versioned market data and quality metadata assembled before engine evaluation. |
| Indicator Snapshot | Coherent cached indicator values aligned with the market snapshot. |
| Engine Input | Immutable-by-contract combination of market and indicator snapshots. |
| TrendEngine | Reports exact migrated V4.2 H1 trend direction and H4 macro context. |
| MomentumEngine | Reports isolated body/ATR, RSI, MACD, and Stochastic evidence without final arbitration. |
| PriceActionEngine | Reports state, bias, strength, confidence, and reasons only. |
| LegacyEngineAdapter | Preserves compatible Fibo indicator-buffer evidence. |
| DecisionEngine | Validates inputs/results and exclusively assigns final action. |
| Dashboard | Displays supplied DTO state without calculating or mutating trading information. |
| Regression modules | Independently compare migrated Trend and Momentum behavior with extracted V4.2 formulas. |
| CSV evidence writer | Writes decision-neutral regression rows after evaluation and deduplicates sequence/generation pairs. |

## Important Behavioral State

- Trend standalone score remains `0.0` because V4.2 uses trend as a directional gate.
- Momentum standalone score remains `0.0` because candidate-dependent scoring has not been migrated.
- Price Action has no approved production score contract; the dashboard displays PA score as `--`.
- Fibo fixed score `80` is marked non-comparable with the V4.2 composite threshold.
- A non-comparable Fibo signal fails closed rather than being mislabeled as merely below threshold.
- No complete V5 final decision rule has been migrated.
- Normal output may therefore be `WAIT` or `BLOCKED`.
- This is controlled migration behavior, not evidence of a defective system.

## Architecture Decisions And Rationale

| Decision | Why it exists |
|---|---|
| Snapshots are immutable | Prevents engines from evaluating different data or mutating shared evidence. |
| IndicatorCache owns buffer access | Prevents duplicate handles, inconsistent shifts, and hidden platform dependencies. |
| Engines are independent | Allows each signal domain to be migrated, tested, rejected, or replaced separately. |
| DecisionEngine owns final action | Prevents engines, adapters, dashboards, and policies from issuing conflicting decisions. |
| Dashboard is read-only | Presentation must never influence signal or trading behavior. |
| Regression is decision-neutral | A diagnostic mechanism must not silently become a trading rule. |
| Score semantics are explicit | Numerically similar scores from different models are not automatically comparable. |
| Unmigrated scores remain zero or unavailable | Avoids inventing trading rules during architectural migration. |
| History/stale detection belongs in Platform Adapter | These checks depend on terminal history, sessions, and wall-clock context. |
| Execution remains outside the indicator | Broker-side state requires different ownership, lifecycle, persistence, and reconciliation guarantees. |
| Legacy compatibility is isolated | Existing evidence can be observed without allowing legacy implementation to control the new architecture. |
| Runtime evidence is separate from compilation | Compile success cannot prove broker behavior, chart lifecycle, historical parity, or transaction correctness. |

## Non-Negotiable Architecture Rules

| ID | Rule | Reason | Violation example | Required enforcement |
|---|---|---|---|---|
| AR-001 | DecisionEngine is the only component allowed to assign BUY, SELL, WAIT, or BLOCKED. | Guarantees one final decision authority. | TrendEngine directly emits BUY. | Static action-assignment search, review, and DecisionEngine tests. |
| AR-002 | No Engine may place, modify, or close trades. | Engines are pure signal-domain evaluators. | MomentumEngine calls `OrderSend`. | Forbidden-API scan in every Engine file. |
| AR-003 | No Engine may call another Engine. | Prevents hidden coupling and evaluation-order dependencies. | PriceActionEngine calls TrendEngine. | Dependency scan and constructor/include review. |
| AR-004 | IndicatorCache is the sole owner of `CopyBuffer()` and indicator handles. | Ensures coherent reads and centralized lifecycle management. | Regression code creates an RSI handle. | Repository-wide `CopyBuffer` and indicator-handle scan. |
| AR-005 | Snapshots and Engine inputs are immutable. | Ensures every Engine evaluates identical evidence. | Engine changes data-quality flags in its input. | Const inputs, DTO review, and mutation scans. |
| AR-006 | Dashboard is permanently read-only. | UI must not become a hidden controller. | Dashboard changes score or sends a trade. | Const DTO parameters and forbidden account/trade API scan. |
| AR-007 | Regression diagnostics must never influence final decisions. | Regression is evidence, not strategy logic. | DecisionEngine blocks because regression status is FAIL. | No regression DTO in DecisionEngine inputs. |
| AR-008 | Platform and broker APIs must remain outside Engines. | Keeps signal logic deterministic and testable. | TrendEngine calls `AccountInfoInteger`. | Platform-API scan of the Engines directory. |
| AR-009 | Execution, Basket, Recovery, Persistence, Statistics, and transaction reconciliation belong outside the Signal Engine. | These require authoritative broker-state ownership. | Indicator manages recovery positions. | Boundary review and separate approved EA architecture. |
| AR-010 | No code from `XAU_Scalper_AI_v17` may be copied into Fusion Pro V5. | v17 contains critical lifecycle, risk, and accounting failures. | Copying its Recovery function. | Source review and provenance declaration. |
| AR-011 | Any v17 concept must be independently validated and tested before adoption. | A useful idea may still be incorrectly implemented or architecturally incompatible. | Reusing adaptive regime scoring without lockout tests. | New specification, independent implementation, and regression fixtures. |
| AR-012 | No implementation may begin without an approved Sprint scope and Definition of Done. | Prevents speculative or unauthorized project changes. | Creating execution interfaces from a context-only request. | Explicit user approval recorded before file modification. |
| AR-013 | Unauthorized experimental folders are not baselines and must never be merged automatically. | Prevents accidental adoption of unreviewed work. | Continuing from `SPRINT4_SAFETY_FOUNDATION`. | Baseline confirmation before every task. |
| AR-014 | Sprint 4 Architecture is the authorized architecture project; Sprint 3.2.1 is the frozen Signal Engine baseline. | Maintains two explicit, non-conflicting ownership boundaries. | Treating contracts as implemented execution or modifying the frozen signal baseline. | State both paths before future implementation. |

## Intentional Current Limitations

The following are intentionally incomplete and must not be reported as accidental omissions:

- No automated execution
- No concrete Basket lifecycle implementation
- No Recovery algorithm
- No concrete transaction coordinator
- No runtime transaction reconciliation
- No concrete production Persistence store
- No concrete authoritative Statistics service
- No concrete duplicate-instance lock store
- No concrete Hard Risk evaluator
- No complete V4.2 composite Decision migration
- No final production Price Action scoring
- No production EA release

Controlled incompleteness is acceptable while the migration remains explicit, testable, and fail-closed.

A limitation becomes a defect only when it violates an approved Sprint specification, an established architecture rule, or claimed behavior.

## Authorized Versus Unauthorized Work

| Status | Work |
|---|---|
| Authorized | Sprint 1 |
| Authorized | Sprint 1.1 |
| Authorized | Sprint 2 |
| Authorized | Sprint 2.1 |
| Authorized | Sprint 2.2 |
| Authorized | Sprint 3 |
| Authorized | Sprint 3.1 |
| Authorized | Sprint 3.2 |
| Authorized | Sprint 3.2 Patch 1 |
| Authorized | Sprint 3.2.1 |
| Authorized | Sprint 4 Architecture |
| Unauthorized / Experimental | `SPRINT4_SAFETY_FOUNDATION` |

The `SPRINT4_SAFETY_FOUNDATION` folder:

- Was created because of a misunderstanding
- Was not requested
- Was not reviewed or approved
- Is not a baseline
- Must not be merged into Sprint 3.2
- Must not be used as the source for future work
- May be inspected later only as discarded experimental material when explicitly requested by the user

Its existence does not authorize Sprint 4 and does not change the current architecture.

## Baseline Lock Conditions

Sprint 3.2.1 is frozen by explicit user decision. Its remaining runtime evidence limitations remain historical context and do not authorize source changes.

Sprint 4 Architecture cannot be locked until review confirms:

- Every required production domain has a typed contract and sole owner
- Basket transitions and invariants are complete and fail-closed
- Persistence cannot override authoritative broker state
- Request acknowledgement cannot confirm basket state
- Risk authorization is separate from execution
- Statistics use authoritative deal history
- Duplicate ownership conflicts halt readiness
- Unit normalization rules are explicit
- No runtime execution or recovery algorithm is present
- MetaEditor compilation remains zero errors and zero warnings

Historical Sprint 3.2.1 evidence topics included:

- XAUUSD M15 runtime verification during an active market
- Trend regression CSV review
- Momentum regression CSV review
- Closed-bar behavior
- Every-tick behavior
- History continuity behavior
- Stale-data behavior
- Journal checks
- Experts checks
- Dashboard resize and object lifecycle
- Indicator remove/reload
- Terminal or chart restart behavior
- Timeframe switching
- Evidence recording with terminal build, broker/server, symbol, inputs, date, and timezone

User-reported tests may be recorded as performed, but they remain **evidence pending** until screenshots, CSV files, Journal/Experts exports, or equivalent inspectable artifacts exist.

The expected CSV files are:

- `SWV5_SPRINT3_2_1_TREND_REGRESSION.csv`
- `SWV5_SPRINT3_2_1_MOMENTUM_REGRESSION.csv`

CSV generation is enabled by default in Patch 1. Experts-log regression output remains disabled by default.

## Remaining Technical Limitations In Sprint 3.2

- `Bars()` history generation cannot detect every same-count broker history correction.
- A legitimate bulk history load may resemble a discontinuity.
- Broker session metadata may be missing or imperfect.
- Missing session metadata suppresses stale blocking conservatively.
- Result validators still mutate failed result headers inside DecisionEngine.
- Regression oracles are independently coded extracted formulas, not external golden datasets.
- Per-snapshot regression PASS does not prove full historical equivalence.
- Candidate-direction scoring, macro penalties, confirmation additions, and final V4.2 arbitration remain unmigrated.

## Sprint 4 Architecture Authorization

Sprint 4 Architecture is explicitly authorized as an isolated production-contract project.

Authorized scope:

- Basket lifecycle states, transitions, and invariants
- Versioned persistence and restart reconciliation contracts
- Request, result-retcode, transaction-confirmation, and retry contracts
- Account, basket, exposure, equity, daily loss, Hard Kill, and aggregate exposure risk contracts
- Basket identity, cumulative recovery-attempt, layer, residual, partial-close, and close-verification contracts
- Authoritative deal-history statistics contracts
- Duplicate-instance ownership, heartbeat, lease, recovery, and conflict contracts
- Point, tick, pip, price, volume, step, tick-value, stops-level, freeze-level, and normalization contracts

The authorization does not include concrete runtime behavior, broker integration, persistence stores, lock stores, recovery algorithms, basket execution, or Signal-to-Execution wiring.

The complete contract specification is `FusionProV5_Sprint4_Production_Architecture.md`. Future implementation requires a separate approved Sprint with adapters, test fixtures, failure policy, and Definition of Done.

## Production Lessons From XAU_Scalper_AI_v17

No v17 source code may be reproduced or copied. The audit is used only to identify failure patterns.

### Signal Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| Signal and regime logic were coupled to mutable trading state. | Signal behavior can change because of execution outcomes or stale basket state. | Not currently; Fusion engines are independent. Risk returns if v17 concepts are adopted. | Regime and Signal concepts must consume immutable snapshots and emit DTO evidence only. |
| Adaptive scoring could permanently suppress strategies after one loss. | A transient outcome can create irreversible self-disable behavior. | No equivalent production logic exists now. | Adaptation requires bounded updates, recovery behavior, persistence tests, and explicit reset semantics. |
| Some concepts relied on current forming bars. | Signals can repaint or change before bar close. | Fusion supports explicit closed-bar/every-tick modes. | Every migrated rule must declare source shifts and receive regression coverage for both modes. |

### Execution Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| No authoritative `OnTradeTransaction` confirmation. | A successful request does not prove the intended position state exists. | Not currently because Fusion has no execution. | Future EA must reconcile request results with transaction events. |
| Command retcodes were not consistently validated. | Rejected, partial, or broker-modified requests may be treated as successful. | Not currently. | Every command requires classified `ResultRetcode` handling and confirmed state transition. |
| Failed close operations could still reset basket state. | Residual positions become unmanaged. | Not currently. | State cannot reset until authoritative reconciliation confirms zero residual exposure. |

### Risk Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| Stop Loss was absent and hard guards were disabled by default. | Loss can become unbounded before discretionary logic reacts. | Not currently because there are no trades. | Future execution requires fail-closed hard risk limits before activation. |
| Account-level and strategy-level risk were mixed. | One strategy can consume or misinterpret account-wide capacity. | Future risk only. | Separate account risk, strategy risk, basket risk, and command validation. |

### Basket And Recovery Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| Netting position count was treated as Recovery layer count. | Netting collapses layers into one position, allowing incorrect or unlimited attempts. | Not currently. | Account mode must be explicitly supported or rejected by a mode-specific basket model. |
| Recovery limits counted open positions instead of cumulative attempts. | Closing or merging positions can reset the apparent limit. | Not currently. | Persist a monotonic cumulative attempt counter per basket. |
| Partial close was treated as complete basket closure. | Remaining exposure becomes orphaned. | Not currently. | Basket completion requires confirmed zero residual volume. |

### Persistence And Restart Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| Persisted state was not reliably reconciled with broker state. | Restart can duplicate, abandon, or misclassify exposure. | Not currently because Fusion owns no trades. | Use versioned persistence and reconcile positions, orders, and history before resuming. |
| Runtime state depended heavily on globals. | State can disappear or become contradictory after reload. | Signal snapshots are rebuilt safely; future execution remains exposed. | Execution state must be versioned, validated, and reconstructable. |

### Statistics Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| Partial closes and basket completion were misattributed. | Win/loss and adaptive metrics become false. | Fusion has no trade statistics. | Calculate statistics from authoritative deal history with basket attribution. |
| Commission, swap, and fee were not reliably included. | Reported profitability differs from actual account results. | Not currently. | Net results must include profit, commission, swap, and fee from deals. |

### Broker And Unit Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| Point, pip, tick size, and price distance were not consistently separated. | Prices and stops become wrong across symbols or brokers. | Signal calculations remain exposed only where units are assumed; no order risk yet. | Use symbol-native tick size, point, digits, and monetary tick value explicitly. |
| Volume step and broker limits were not consistently normalized. | Requests can be rejected or exceed intended risk. | Not currently. | Validate min/max/step and normalize volume before every future command. |
| Stops and freeze levels were not comprehensively enforced. | Modification or close requests can fail unexpectedly. | Not currently. | Future execution preflight must validate stops level, freeze level, trade mode, and filling mode. |

### Operational Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| Multiple instances could manage the same basket. | Duplicate recovery, closing, or state resets can occur. | Signal indicator instances are read-only; future execution would be exposed. | Future EA requires atomic ownership keyed by account, server, symbol, strategy, and magic. |
| Architecture was monolithic and globally coupled. | Local fixes create unrelated regressions and make testing unreliable. | Fusion currently avoids this through boundaries. | Preserve adapters, immutable DTOs, independent engines, central decision authority, and separate execution ownership. |

## Risks Fusion V5 Must Continue To Avoid

- Treating the unauthorized Sprint 4 folder as valid work
- Converting recommendations into implementation without approval
- Adding execution behavior to the indicator by assumption
- Mixing broker state into Signal Engines
- Allowing Engines to assign final actions
- Allowing regression results to block or generate signals
- Comparing scores with incompatible semantics
- Inventing scores for intentionally unmigrated logic
- Claiming historical equivalence from same-snapshot comparisons
- Claiming runtime verification without inspectable evidence
- Supporting Netting or Hedging implicitly
- Enabling Recovery before state, persistence, reconciliation, and hard risk are proven
- Resetting lifecycle state before residual exposure is confirmed absent
- Reusing v17 code because a concept appears familiar
- Weakening Fusion architecture to imitate v17 behavior

## Open Design Questions

- Should the next authorized Sprint remain purely inside the Signal Engine?
- Which V4.2 domain should be migrated next?
- Should execution live in a separate repository, sibling project, or EA host?
- Should future execution support Hedging only or separate Hedging and Netting models?
- What external datasets qualify as golden regression fixtures?
- What score model will eventually replace or reproduce the V4.2 composite model?
- How should final Price Action scoring be specified?
- What evidence threshold is required to lock each Sprint?
- Should result validation become completely non-mutating?
- Should history generation move beyond the current `Bars()` token?
- What Architecture Decision Record process will authorize boundary changes?
- Which exact files may be modified in the next Sprint?

## Future Recommendations

These are recommendations only and are not authorized implementation:

1. Review and lock the Sprint 4 production contracts before selecting any implementation work.
2. Decide whether the next Sprint builds test fixtures, platform adapters, or remains documentation-only.
3. Require an approved scope, file list, exclusions, rollback point, failure tests, and Definition of Done.
4. Keep any future Execution Layer physically and logically separate until an ADR authorizes integration.
5. Evaluate v17 Regime Detection, Signal Logic, and Dashboard concepts only through independent specifications and tests.
6. Build external golden fixtures before claiming full V4.2 migration parity.
7. Introduce Basket, Recovery, Risk, Persistence, and transaction work only after the Execution boundary is formally approved.

A provisional risk-oriented order, requiring separate approval at every step, would be:

1. Lock Sprint 3.2 evidence.
2. Complete remaining Signal Engine migrations or explicitly close their scope.
3. Approve the Indicator-to-Execution boundary and repository structure.
4. Design lifecycle, persistence, reconciliation, and ownership contracts.
5. Design account, strategy, basket, and command risk.
6. Implement and test broker execution in Strategy Tester and demo only.
7. Add basket lifecycle before Recovery.
8. Add bounded Recovery only after fault testing.
9. Build authoritative statistics from deal history.
10. Consider production release only after broker-specific evidence.

## Master Context Usage Instructions

Before performing any future work, every AI agent must:

1. Read this Master Context completely.
2. Confirm that Sprint 4 Architecture is the authorized architecture project and Sprint 3.2.1 is the frozen Signal Engine baseline.
3. Ignore `SPRINT4_SAFETY_FOUNDATION` unless the user explicitly requests inspection of discarded experimental material.
4. Classify the request as documentation, design, audit, runtime verification, or implementation.
5. Confirm the approved Sprint scope and Definition of Done before implementation.
6. Ask for explicit approval when Sprint scope or architecture boundaries are ambiguous.
7. Never create files merely because implementation may be useful.
8. Never modify the frozen baseline unless explicitly instructed.
9. Never copy code from `XAU_Scalper_AI_v17`.
10. Never mix Signal Engine responsibilities with future Execution Layer responsibilities.
11. Report uncertainty and unresolved decisions instead of inventing architecture.
12. Distinguish implemented, deferred, evidence-pending, and unauthorized work.
13. Keep recommendations separate from authorized actions.
14. Re-read the newest user instruction before editing, compiling, or creating artifacts.
15. Report exact files intended for modification before making approved changes.

## Next Authorized Action

"Review and lock Sprint 4 Architecture. No runtime implementation is currently authorized."
