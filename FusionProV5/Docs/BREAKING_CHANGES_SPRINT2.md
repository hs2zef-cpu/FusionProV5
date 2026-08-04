# Breaking Changes Sprint 2

## API Changes

- `CCentralOrchestrator::Evaluate()` now returns an additional `SWV5_TrendRegressionResult` output parameter before the decision result.
- `CReadOnlyDashboard::Render()` now requires TrendResult and TrendRegressionResult in addition to the prior inputs.
- `SWV5_IndicatorSnapshot` adds trend periods, readiness fields, `use_closed`, and explicit shift metadata.
- `SWV5_TrendResult` adds raw EMA values, H1 state flags, H4 macro state/direction, and shift metadata.

## Behavioral Compatibility

- The Sprint 1.1 placeholder TrendEngine score (`60.0`/`20.0`) is removed. The migrated V4.2 isolated trend contribution is `0.0` because V4.2 trend is a direction gate, not a standalone score addition.
- Preview/every-tick H4 macro reads now use shift `0`, matching V4.2. Closed-bar H4 and all H1 trend reads use shift `1`.
- No final BUY/SELL rule changed. LegacyEngineAdapter remains active and DecisionEngine remains the sole final action authority.

## Preserved Artifacts

- `SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT1.mq5` remains byte-identical to the Sprint 1.1 source.
- `SOMWANG_XAU_M15_FUSION_PRO_V4_2_LOOKBACK_CONFIRM_FIX.mq5` and `SW_FIBO_BASIC_V3.mq5` remain byte-identical to their source files.
