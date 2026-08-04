# Fusion Pro V5 Sprint 2 Trend Migration

## Summary

Sprint 2 adds the first migrated domain logic: the V4.2 H1 trend gate and H4 macro direction. It also adds an independent regression oracle, typed trend diagnostics, result validation, and a spaced read-only dashboard. Momentum, Price Action, Structure, Volume, Context, Fibo, Risk, and final signal logic were not migrated.

## Exact V4.2 Logic Migrated

Source behavior extracted from `Evaluate()` and `MacroTrendDir()`:

```text
H1 trend shift = 1 in both closed-bar and preview modes
trendUp = EMA fast > EMA slow
trendDn = EMA fast < EMA slow

H4 macro shift = useClosed ? 1 : 0
macro = +1 when EMA fast > EMA slow
macro = -1 when EMA fast < EMA slow
macro =  0 when equal or unavailable
```

The H1 result gates `ComputeCoreRating` through `allowBuy=trendUp` and `allowSell=trendDn`. V4.2 does not add a standalone trend number to `e.score`; therefore `SWV5_TrendResult.header.score` is `0.0`. The V4.2 macro penalty and final direction arbitration remain in the legacy path.

## File Tree

```text
SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT2.mq5
FusionProV5/
  Core/
    SW_V5_Types.mqh
    SW_V5_ResultValidator.mqh
  Indicators/
    SW_V5_IndicatorCache.mqh
  Engines/
    SW_V5_TrendEngine.mqh
  Regression/
    SW_V5_TrendRegression.mqh
  Orchestration/
    SW_V5_Orchestrator.mqh
  Decision/
    SW_V5_DecisionEngine.mqh
  Dashboard/
    SW_V5_ReadOnlyDashboard.mqh
  Docs/
    SPRINT2_TREND_MIGRATION.md
    SPRINT2_TREND_REGRESSION.md
    COMPILE_REPORT.md
    BREAKING_CHANGES_SPRINT2.md
```

## Changed Files

- New: `SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT2.mq5`
- New: `FusionProV5/Regression/SW_V5_TrendRegression.mqh`
- Changed: `FusionProV5/Core/SW_V5_Types.mqh`
- Changed: `FusionProV5/Core/SW_V5_ResultValidator.mqh`
- Changed: `FusionProV5/Indicators/SW_V5_IndicatorCache.mqh`
- Changed: `FusionProV5/Engines/SW_V5_TrendEngine.mqh`
- Changed: `FusionProV5/Orchestration/SW_V5_Orchestrator.mqh`
- Changed: `FusionProV5/Decision/SW_V5_DecisionEngine.mqh` (diagnostic wording only)
- Changed: `FusionProV5/Dashboard/SW_V5_ReadOnlyDashboard.mqh`
- New/updated Sprint 2 documentation under `FusionProV5/Docs/`

## DTO Additions

`SWV5_IndicatorSnapshot` now records EMA periods, `use_closed`, trade/trend/macro shifts, and separate trend/macro readiness. `SWV5_TrendResult` now records H1 state booleans, bias, raw H1/H4 EMA values, macro direction/state, `use_closed`, and shifts. New trend/macro reason flags identify the source state.

## TrendEngine Contract

- Input: const `SWV5_EngineInput` only.
- Output: typed `SWV5_TrendResult` with health, validity, score, confidence, flags, sequence, and history generation.
- Dependencies: immutable market/indicator DTOs only.
- Side effects: none.
- Prohibited calls: no `CopyBuffer`, platform, drawing, alert, account, trade, dashboard, or other-engine APIs.
- Authority: reports trend state only; never emits a final decision action.

## Decision Integration

DecisionEngine still validates TrendResult and remains the only writer of `SWV5_DecisionResult.action`. Regression comparison runs before decision generation but its result is diagnostic-only and is not passed into DecisionEngine. No Sprint 2 trend-based final signal rule was added. Legacy buffer compatibility remains active.

## Dashboard

The dashboard now uses a 21-pixel line gap, top-down layout, aligned labels, and separate Health, State, Action, and Metadata sections. Legacy numeric buffers were replaced by `Legacy Adapter : Healthy/Degraded`. Trend bias/score and regression status are visible. Advice remains `WAIT`, `BLOCKED`, or `LEGACY SIGNAL`; no Fibo/context advice was invented.

## Static Checks

- `CopyBuffer()` appears once in V5 code, in `SW_V5_IndicatorCache.mqh`.
- TrendEngine forbidden API scan: no matches.
- TrendEngine calls no other engine.
- Final action assignments occur only in `SW_V5_DecisionEngine.mqh`.
- Dashboard accepts const DTO references and only updates chart labels.
- Regression code contains no decision/action/policy access.
- H1 shift is always `1`; H4 shift is closed `1`, every-tick `0`.
- Result validation checks snapshot sequence, history generation, shifts, bias, macro direction, and EMA values.
- PriceActionEngine and all other unmigrated engines are unchanged.
- SHA-256 hashes of V4.2, Fibo V3, and the Sprint 1.1 harness match their source copies.

## Runtime Checklist

- [ ] Sprint 2 indicator loads successfully in MT5.
- [ ] `SW_FIBO_BASIC_V3` loads successfully through `iCustom`.
- [ ] Journal and Experts show no runtime errors.
- [ ] Dashboard renders with readable spacing and no overlap.
- [ ] Trend bias and score display.
- [ ] Regression status displays.
- [ ] Switching timeframe does not crash.
- [ ] Reload and terminal restart do not crash.
- [ ] No `CopyBuffer` failure is reported.
- [ ] No array-out-of-range error is reported.
- [ ] No invalid handle is reported.
- [ ] No snapshot mismatch is reported.
- [ ] Closed-bar and every-tick CSV rows are captured over representative history.

## Known Limitations

- Historical MT5 runtime regression has not been executed in this build environment.
- The regression oracle compares V5 to independently extracted V4.2 formulas over the same snapshot; it is not a second running V4.2 indicator instance.
- V4.2 final score, macro penalty, V4/V5 rating arbitration, confirmations, and final signal rules remain legacy/unmigrated.
- `history_generation` still uses the platform bar count token introduced in Sprint 1.1.

## Recommendation

The code is compile-clean and structurally complete for Sprint 2, but it is **not ready for Sprint 3 migration** until the manual MT5 runtime checklist and representative historical regression capture are completed without failures.
