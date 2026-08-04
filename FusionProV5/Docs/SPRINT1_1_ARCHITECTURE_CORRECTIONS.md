# Fusion Pro V5 Sprint 1.1 Architecture Corrections

## Summary

Sprint 1.1 hardens the Sprint 1 skeleton without migrating additional trading logic, redesigning strategy behavior, or modifying the original V4.2/Fibo V3 files.

## Updated Architecture Diagram

```text
OnCalculate harness
  |
  v
Central Orchestrator
  |
  +-- PlatformAdapter --> SWV5_MarketSnapshot
  |
  +-- IndicatorCache --> SWV5_IndicatorSnapshot
  |
  +-- ResultValidator validates snapshot metadata
  |
  +-- PriceActionEngine --> SWV5_PriceActionResult
  +-- TrendEngine       --> SWV5_TrendResult
  +-- LegacyAdapter     --> SWV5_LegacyResult
  +-- ExecutionPolicy   --> SWV5_PolicyResult
  |
  v
DecisionEngine --> SWV5_DecisionResult
  |
  v
ReadOnlyDashboard
```

## Corrections Made

- Split `SWV5_MarketSnapshot` from `SWV5_IndicatorSnapshot`.
- Added `SWV5_EngineInput` as the immutable engine input DTO by convention.
- Added snapshot metadata: schema version, sequence, history generation, execution mode, data-quality flags, symbol, timeframe, and closed bar time.
- Replaced generic `SWV5_EngineResult` with typed results.
- Expanded `SWV5_EngineKind`.
- Added `SWV5_EngineHealth`.
- Normalized `score`, `strength`, and `confidence` ranges.
- Expanded reason flags for action and inaction.
- Moved final action assignment fully into `DecisionEngine`.
- Kept dashboard read-only.
- Preserved legacy Fibo buffer compatibility through `LegacyEngineAdapter`.

## DTO Definitions

- `SWV5_SnapshotHeader`
- `SWV5_MarketSnapshot`
- `SWV5_IndicatorSnapshot`
- `SWV5_EngineInput`
- `SWV5_ResultHeader`
- `SWV5_MarketResult`
- `SWV5_TrendResult`
- `SWV5_MomentumResult`
- `SWV5_VolumeResult`
- `SWV5_StructureResult`
- `SWV5_PriceActionResult`
- `SWV5_ContextResult`
- `SWV5_LegacyResult`
- `SWV5_RiskResult`
- `SWV5_PolicyResult`
- `SWV5_DecisionResult`

## Validation Rules

- Reject invalid schema version.
- Reject invalid execution mode, engine kind, and engine health.
- Reject missing symbol, timeframe, rates, or closed bar time.
- Reject market/indicator snapshot mismatches by sequence, history generation, symbol, timeframe, or closed bar time.
- Reject required data-quality failures such as missing data, CopyBuffer failure, history changes, stale data, snapshot mismatch, and invalid values.
- Reject NaN, infinity, and out-of-range values.
- Required ranges:
  - `score`: `0.0..100.0`
  - `strength`: `0.0..1.0`
  - `confidence`: `0.0..1.0`
- Mandatory unavailable or invalid PriceAction/Trend results become final `BLOCKED` through `DecisionEngine`.

## Static-Check Results

- `CopyBuffer()` search: code-level call exists only in `FusionProV5/Indicators/SW_V5_IndicatorCache.mqh`.
- Engine-to-engine calls: none inside `FusionProV5/Engines`.
- Platform APIs inside `Engines/`: none found.
- Drawing, dashboard, alerts inside `Engines/`: none found.
- Final action assignment: `DecisionEngine` only; orchestrator/dashboard read the decision action but do not create it.
- PriceActionEngine: no final BUY/SELL fields or action output.
- Dashboard: only renders labels from const DTO inputs.
- ResultValidator covers ranges, enum validity, sequence, and history generation consistency.

## Compilation

- MetaEditor compile: `0 errors, 0 warnings`.
- Compile log: `FusionProV5/Docs/compile_sprint1_1.log`.

## Unresolved Assumptions

- V4.2 Fusion still has no plotted buffers, so full V4.2 behavior preservation is not claimed.
- Fibo V3 remains the only concrete legacy buffer compatibility source in Sprint 1.1.
- `history_generation` currently uses `Bars(symbol, timeframe)` as the practical MQL5 generation token.
- Execution remains an indicator harness, not an automated EA executor.

## Recommendation

Structurally ready for Sprint 2. Sprint 2 should begin with regression fixtures before migrating any V4.2 trading logic.
