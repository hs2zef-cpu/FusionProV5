# Breaking Changes Sprint 3.2

## DTO And API Changes

- Snapshot schema advances from V3 to V4 for history/stale diagnostics.
- `SWV5_LegacyResult` adds score semantics, comparability, and maximum reachable score.
- `SWV5_DecisionResult` adds the blocking engine.
- `CDecisionEngine::Decide()` accepts const EngineInput.
- Dashboard `Render()` now requires const PriceActionResult.
- Orchestrator `Init()` adds optional stale-tolerance configuration.
- Trend regression CSV adds execution mode, typed primary reason, mismatch flags, and data-quality flags.

## Accepted Behavioral Change

The fixed Fibo score is not treated as V4.2 composite score. Fibo signals now fail closed with `LEGACY_SCORE_NOT_COMPARABLE` instead of being numerically compared with `InpMinScoreToSignal`. This can remove legacy BUY/SELL output that was previously reachable only when users manually lowered the threshold to 80 or below.

No substitute score, threshold reduction, new BUY/SELL rule, or V4.2 composite migration was added.

## Preserved Behavior

- Trend and Momentum formulas are unchanged.
- Price Action calculation is unchanged and remains unmigrated placeholder state evidence.
- Trend/Momentum regression comparison formulas are unchanged.
- Indicator thresholds, `useClosed`, and shift behavior are unchanged.
- DecisionEngine remains the only final-action writer.
- Regression and dashboard remain decision-neutral/read-only.
- Original V4.2, Fibo V3, and the locked Sprint 3.1 folder remain untouched.

