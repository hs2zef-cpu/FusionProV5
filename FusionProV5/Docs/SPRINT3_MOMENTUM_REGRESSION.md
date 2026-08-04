# Fusion Pro V5 Sprint 3 Momentum Regression

## Oracle Boundary

CMomentumRegression independently re-implements the extracted V4.2 formulas. It does not call CMomentumEngine, share its calculation helpers, access DecisionEngine, or assign a final action.

The oracle captures coherent snapshot metadata, data-quality flags, execution mode, source shift, RSI state/value, MACD histogram state/value, Stochastic state/value, candle body and ATR ratio, both body thresholds, Trend-independent body bias, isolated score 0.0, raw contribution 0, and readiness.

Candidate-direction confirmation booleans and 10/10/5 additions are excluded because their direction comes from unmigrated mixed-domain arbitration. This boundary is explicit rather than represented as a false standalone score.

## Statuses

- PASS: ready oracle and valid V5 output match for metadata, shifts, values, states, body qualifiers, bias, and isolated contribution.
- EXPECTED_DIFFERENCE: reserved for an approved, documented fixture difference; Sprint 3 does not emit it automatically.
- FAIL: ready values differ.
- NOT_READY: required source data or the V5 result is unavailable or invalid.

## CSV

The emitted columns are:

timestamp, symbol, timeframe, execution_mode, use_closed, source_bar_shift, snapshot_sequence, history_generation, data_quality_flags, V4/V5 RSI state and value, V4/V5 MACD state and histogram, V4/V5 Stochastic state and K value, V4/V5 momentum bias, V4/V5 momentum score, V4/V5 readiness, match_status, and mismatch_reason.

InpLogMomentumRegression controls Experts-log output.

## Regression Status

The in-process oracle is integrated and compiles. Historical project status is **NOT_READY** because representative MT5 runtime history has not been executed or reviewed. A live per-snapshot PASS is evidence for that snapshot only and is not a claim of full historical equivalence.

