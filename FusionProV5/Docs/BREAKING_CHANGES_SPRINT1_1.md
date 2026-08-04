# Breaking Changes From Sprint 1 To Sprint 1.1

## Source/API Breaking Changes

- `SWV5_MarketSnapshot` no longer contains indicator values.
- New `SWV5_IndicatorSnapshot` contains EMA, RSI, ATR, ADX, MACD, Stochastic, volume ratio, and legacy buffers.
- Engines now receive `SWV5_EngineInput` instead of a market snapshot alone.
- Generic `SWV5_EngineResult` was removed.
- Engine outputs are now typed, including `SWV5_PriceActionResult`, `SWV5_TrendResult`, and `SWV5_LegacyResult`.
- `SWV5_Decision` was replaced with `SWV5_DecisionResult`.
- `SWV5_ACTION_BLOCK` was renamed to `SWV5_ACTION_BLOCKED`.
- Scores are now `double` values normalized to `0.0..100.0`.

## Behavioral Changes

- Unsafe metadata, invalid result values, or mandatory engine unavailability now fails safely through `DecisionEngine`.
- Orchestrator no longer overrides the final action after decision generation.
- Legacy Fibo buffer absence is reported as degraded/partial compatibility data instead of full V4.2 preservation.

## Non-Breaking Preservations

- Main harness filename remains `SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT1.mq5`.
- Original V4.2 and Fibo V3 source files remain untouched.
- No new trading rules were introduced.
- Existing Sprint 1 legacy-buffer BUY/SELL path remains gated by `DecisionEngine` and `ExecutionPolicy`.
