# Fusion Pro V5 Sprint 3.2 Architecture Audit Closure

## Summary

Sprint 3.2 closes only CRITICAL-1, the CRITICAL-2 evidence-capture gap, MAJOR-4, MAJOR-6, and MAJOR-7 from the Sprint 3.1 architecture audit. It does not migrate a new domain engine, V4.2 composite scoring, rating fusion, or final arbitration.

## Findings Closed

- CRITICAL-1: Fibo fixed score semantics are explicit and cannot be compared with the V4.2 composite threshold.
- CRITICAL-2 evidence gap: a repeatable runtime evidence template and decision-neutral CSV files are available. User-reported MT5 execution is acknowledged; verification remains pending until artifacts are attached.
- MAJOR-4: DecisionEngine is the sole final validation owner. Orchestrator no longer validates snapshots or results.
- MAJOR-6: Price Action health, state, bias, confidence, and block cause are visible.
- MAJOR-7: HISTORY_CHANGED and STALE_DATA now have real producers.

## Changed Files

- New: `SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT3_2.mq5`
- Updated Core: `SW_V5_Types.mqh`, `SW_V5_ResultValidator.mqh`
- Updated boundaries: `SW_V5_LegacyEngineAdapter.mqh`, `SW_V5_ExecutionPolicy.mqh`, `SW_V5_DecisionEngine.mqh`, `SW_V5_Orchestrator.mqh`
- Updated data/platform: `SW_V5_PlatformAdapter.mqh`, `SW_V5_IndicatorCache.mqh`
- Updated diagnostics: `SW_V5_ReadOnlyDashboard.mqh`, both regression modules
- New evidence writer: `FusionProV5/Evidence/SW_V5_RegressionCsvWriter.mqh`
- New/updated Sprint 3.2 documentation and compile log under `FusionProV5/Docs` and `FusionProV5/Evidence`

## Legacy Score Contract

`SWV5_ScoreSemantics` distinguishes no score, fixed legacy evidence, V4.2 composite score, normalized engine score, and explicitly non-comparable score. `SWV5_LegacyResult` reports its header score, semantic, threshold-comparability flag, and maximum reachable score.

The Fibo adapter declares:

- score constant: `SWV5_LEGACY_FIBO_SIGNAL_SCORE = 80.0`
- confidence constant: `SWV5_LEGACY_FIBO_CONFIDENCE = 0.60`
- semantic: `SWV5_SCORE_LEGACY_FIXED`
- comparable to `InpMinScoreToSignal`: false
- maximum reachable score: 80.0

ExecutionPolicy checks comparability and semantic compatibility before any numeric threshold comparison. A Fibo signal therefore fails closed with `LEGACY_SCORE_NOT_COMPARABLE`; it is never mislabeled as below threshold. Initialization prints the same warning. A future comparable producer whose declared maximum is below the configured threshold fails initialization.

This intentionally changes the former legacy signal path: Fibo fixed evidence no longer produces BUY/SELL through a threshold calibrated for the unported V4.2 composite model. No replacement score or threshold was invented.

## Configuration Validation

Initialization explicitly checks engine periods/threshold ranges, cooldown, panel position/size/font/spacing, stale tolerance, and the derived execution mode. IndicatorCache reports the names of unavailable mandatory handles. Missing `SW_FIBO_BASIC_V3` fails initialization. The active score producer contract is validated and produces either a clear non-comparability warning or a safe initialization failure for an unreachable comparable producer. CSV file failures are warnings because evidence output is decision-neutral.

## Validation Ownership

Orchestrator builds input, runs engines/adapters/policy, runs regressions, and calls DecisionEngine. It contains no validator calls.

DecisionEngine validates the complete input and each result once. Its input is const. Snapshot/input validation returns `SWV5_ValidationResult` without mutating the source DTO. Existing per-result validators still mutate a failed result header idempotently; this retained behavior is isolated to DecisionEngine and should be converted to pure query results in a later dedicated refactor.

## Price Action Visibility

The read-only dashboard receives `const SWV5_PriceActionResult&` and displays:

- Price Action health
- PA state and bias
- PA score as `--`, because no migrated PA score contract exists
- existing confidence where valid
- concise PA block reason when DecisionEngine records Price Action as the blocking engine

The dashboard performs no PA calculation and writes no decision or DTO field.

## History Continuity

The platform adapter instance retains the previous valid `Bars()` generation and execution context. First evaluation and symbol/timeframe/mode changes reset the baseline. Equal generation and `+1` are normal. Shrink, large reset, and jumps greater than one raise `SWV5_DQ_HISTORY_CHANGED` for the current snapshot and record previous/current generation, typed state, and reason.

The baseline advances after each observation so one discontinuity does not permanently poison subsequent snapshots. A normal new bar does not raise the flag.

## Stale Policy

Stale checks use broker trade-session metadata when available:

- CLOSED_BAR: latest current or closed bar age may satisfy freshness, allowing normal session gaps.
- EVERY_TICK: latest tick time must be within `InpStaleToleranceSeconds` during an expected active session.
- REPLAY: live wall-clock checks are disabled.
- Closed sessions: no stale flag is raised.
- Missing session metadata: stale detection is conservatively suppressed and labeled uncertain.

Default tolerance is 180 seconds and valid range is 1 through 86400 seconds.

## Regression Evidence

Trend and Momentum rows contain timestamp, symbol, timeframe, execution mode, snapshot sequence, history generation, oracle fields, engine fields, status, primary mismatch reason, mismatch flags, and data-quality flags. The writer opens files safely, appends headers, deduplicates identical sequence/generation pairs, and runs only after the decision has been produced.

Files are written under the terminal data directory `MQL5/Files`:

- `SWV5_SPRINT3_2_TREND_REGRESSION.csv`
- `SWV5_SPRINT3_2_MOMENTUM_REGRESSION.csv`

File-open/write failures are reported in Journal/Experts and cannot affect decisions.

## Static Verification

- `CopyBuffer()` code call exists only in IndicatorCache.
- Engines contain no platform, chart, account, trade, or other-engine calls.
- DecisionEngine is the only final action writer.
- Orchestrator contains no validator call.
- Incompatible score comparison is guarded in policy and rejected by validation.
- Price Action is present in Dashboard as a const DTO.
- HISTORY_CHANGED and STALE_DATA are set by PlatformAdapter.
- Equal and `+1` history generations are normal.
- Closed/unknown sessions suppress stale blocking.
- Regression modules have no DecisionEngine/action/policy access.
- Dashboard has no account/trade/file APIs and no DTO assignment.
- Trend, Momentum, and Price Action engine hashes match Sprint 3.1.
- V4.2 and Fibo source hashes match Sprint 3.1.
- Locked Sprint 3.1 remains in its separate original folder.

## Preserved Hashes

- V4.2: `8B7ACBD243415376AF1E476944B4E2228CD0A3ED0247572BC3E91A74499CAE6D`
- Fibo V3: `0A86A83177F686F04F5B85BBABE610CB92EA450E6994864C40C6BB25FCFC4D3D`
- TrendEngine: `17865AFE4B36E6EC6E5C1C57DB1BE895B1360E28172E6A54765AF365FA0D35D4`
- MomentumEngine: `0E2B9F899A57899B3AFF1EA34CB9D96E6E34F02BB054B35CF2B3591CF2B60456`
- PriceActionEngine: `5E0F94D6D7FF426E914DDB16F61ECA837D91B80259E223C889547ED66A92CE70`

## Known Limitations

- `Bars()` cannot detect every same-count broker correction and may classify a legitimate bulk history load as a discontinuity.
- Session schedules are broker metadata and may be absent or imperfect; unavailable metadata suppresses stale blocking.
- The closed-bar age policy is conservative and requires MT5 observation around session openings and holidays.
- Result validation still mutates failure headers, once and only inside DecisionEngine.
- Existing oracle methodology remains a hand-extracted narrow slice; no golden external fixtures were added.
- Manual checks are user-reported as performed, but no screenshot, CSV, Journal, Experts, terminal-build, or broker artifact was supplied to this sprint package.

## Remaining Audit Findings

Not addressed by Sprint 3.2 scope: MAJOR-3 golden fixture methodology, MAJOR-5 historical harness compatibility, MINOR-8 through MINOR-13, and SUGGESTION-14 through SUGGESTION-19 except the accepted const-correctness and named-score work tied directly to this sprint.

## Recommendation

**NOT READY TO LOCK.** Static verification and compilation pass, but Sprint 3.2 runtime evidence must be captured with the supplied template, including CSV and terminal diagnostics, before locking the Sprint 3 baseline.
