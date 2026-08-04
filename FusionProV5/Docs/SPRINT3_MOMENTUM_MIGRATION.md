# Fusion Pro V5 Sprint 3 Momentum Migration

## Summary

Sprint 3 migrates the independently observable momentum portion of the supplied V4.2 source into CMomentumEngine. It adds a typed result, snapshot readiness metadata, an independent V4.2 oracle, validation, orchestration, diagnostics, and compact dashboard rows. It does not migrate rating fusion, candidate-direction arbitration, hard confirmation blocks, or any final BUY/SELL rule.

## Exact V4.2 Momentum Scope

- MomentumSignal() computes abs(close-open) and passes when body is greater than or equal to ATR * bodyMult. It then requires candle direction and the externally supplied Trend gate (allowBuy or allowSell).
- V4 core uses V4_MomentumBody_ATR = 0.32; V5 core uses V5_MomentumBody_ATR = 0.36.
- RSI uses period 14 by default. When InpUseRSI50Filter is enabled, a long candidate confirms only at RSI > 50; a short candidate confirms only at RSI < 50. Equality does not confirm. When disabled, confirmation returns true.
- MACD uses 12/26/9 by default. Histogram is main - signal. Long confirms when main > signal or histogram > 0; short confirms when main < signal or histogram < 0. When disabled, confirmation returns true and histogram output remains 0.0.
- Stochastic uses 5/3/3 SMA, STO_LOWHIGH. Long confirms at K > D and K > 20; short confirms at K < D and K < 80. When disabled, confirmation returns true and K/D outputs remain 0.0.
- Closed-bar mode uses shift 1; preview/every-tick mode uses shift 0 for the body bar and RSI/ATR/MACD/Stochastic.
- RSI and ATR failure aborts V4.2 Evaluate(). Enabled MACD/Stochastic read failure returns false from that confirmation helper. All indicator handles are mandatory at initialization.
- EffectiveMomentumBars() returns 18, 24, 36, or a custom minimum of 6, but its value is never consumed by signal logic.
- There is no MACD crossover history, slope, acceleration, weakening, previous-bar momentum comparison, or momentum lookback calculation.
- RSI/MACD/Stochastic add 10/10/5 only after a candidate direction is produced by Trend, Entry, Price Action/Breakout, macro, and V4/V5 arbitration. Those mixed responsibilities remain legacy.
- Optional hard confirmation flags can zero the final candidate direction. That final-confirmation behavior is not inside MomentumEngine.

## Source Mapping

| V4.2 source | Variable/function | Momentum responsibility | V5 destination | Status |
|---|---|---|---|---|
| Lines 50, 544-550 | InpMomentumBars_Custom, EffectiveMomentumBars() | Deprecated preset/custom value, unused by signals | Documentation only | Not migrated by design |
| Lines 96, 106 | V4_MomentumBody_ATR, V5_MomentumBody_ATR | Exact body/ATR thresholds 0.32 and 0.36 | Momentum configuration and result threshold fields | Migrated |
| Lines 268-275 | MomentumSignal() | Body threshold and candle direction | CMomentumEngine::Evaluate() | Momentum portion migrated; Trend gate excluded |
| Lines 125, 378-384 | InpUseRSI50Filter, RSI50Confirm() | Directional RSI-50 evidence | rsi_value, rsi_state | Migrated |
| Lines 126, 356-366 | InpUseMACDFilter, MACDConfirm() | Main, signal, histogram sign | MACD result fields/state | Migrated |
| Lines 127, 131-132, 368-376 | Stochastic inputs and StochConfirm() | K/D timing with exact 20/80 bounds | Stochastic result fields/state | Migrated |
| Lines 450-456 | useClosed, sh and required reads | Source bar and indicator shift | use_closed, source_bar_shift, cache readiness | Migrated |
| Lines 473-478 | Dual ComputeCoreRating() calls | V4/V5 body thresholds feed mixed core rating | V4/V5 qualifier booleans | Qualifiers migrated; core rating excluded |
| Lines 500-509 | candidateDir and hard confirmation blocks | Candidate-dependent final confirmation | confirmation_context_ready=false | Remains legacy |
| Lines 518-520 | +10/+10/+5 | Candidate-dependent fusion score | Raw contribution field 0; header score 0.0 | Remains legacy |
| Lines 916-929 | RSI/ATR/MACD/Stochastic handles | Periods, methods, initialization readiness | Existing IndicatorCache handles | Preserved |

## Snapshot Changes

Schema version advances from V2 to V3. SWV5_IndicatorSnapshot adds only readiness metadata:

- has_momentum_indicators
- has_rsi
- has_atr
- has_macd
- has_stoch

No new buffers are copied. Existing RSI, ATR, MACD main/signal, and Stochastic K/D fields are reused. MACD histogram is derived inside the engine exactly as main - signal. No previous-bar or lookback arrays were added because V4.2 does not use them.

## MomentumEngine Contract

- Input is const SWV5_EngineInput.
- No platform, CopyBuffer, engine, chart, alert, account, order, position, or trade calls.
- V4/V5 body threshold evidence and directional RSI/MACD/Stochastic states use exact source comparisons.
- bias and momentum_state represent the Trend-independent V4 body qualifier direction.
- strength maps the source boolean qualifier to 1.0 or 0.0; this is DTO normalization, not a trading rule.
- confidence is 1.0 only when required snapshot data is ready.
- header.score is 0.0. V4.2 has no standalone momentum score.
- raw_legacy_confirmation_points is 0 and confirmation_context_ready is false because the source weights require an externally produced candidate direction.
- The engine never emits a final action.

## Integration

The orchestrator builds and validates one coherent snapshot, runs Trend then Momentum, runs existing adapters and policy, validates typed results, runs both independent regressions, and finally calls DecisionEngine. DecisionEngine treats Momentum as mandatory health input but adds no momentum-based BUY/SELL rule. Regression results are diagnostic-only.

The read-only dashboard adds Momentum health, state, score, and regression status. It receives const DTOs, displays their fields, and performs no momentum or decision calculation.

## Runtime Checklist

- [ ] Indicator and SW_FIBO_BASIC_V3 load successfully.
- [ ] Momentum health/state and both regression statuses are visible.
- [ ] Trend regression remains PASS where ready.
- [ ] Momentum regression emits PASS, FAIL, EXPECTED_DIFFERENCE, or NOT_READY correctly.
- [ ] Closed-bar uses shift 1 and every-tick uses shift 0.
- [ ] M15, M30, and H1 switching does not crash.
- [ ] Chart resize preserves panel layout.
- [ ] Remove/reload creates no duplicate dashboard objects.
- [ ] Journal/Experts show no CopyBuffer, invalid-handle, array-range, snapshot, or action-regression errors.
- [ ] No unexpected final-action change occurs.

## Known Limitations

- No representative MT5 history has been captured in this build environment.
- Per-snapshot PASS compares the V5 engine with an independently coded formula oracle over the same immutable snapshot; it is not full historical equivalence.
- Candidate-direction confirmations, their 10/10/5 score additions, hard confirmation blocks, full rating fusion, and final arbitration remain legacy.
- The V4 body state is reported before its external Trend gate; Trend remains an independent engine.

## Recommendation

Sprint 3 is compile-ready for manual regression capture, but **not ready for Sprint 4 migration** until the runtime checklist and representative closed-bar/every-tick CSV history have been reviewed.

