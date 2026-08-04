# Fusion Pro V5 Sprint 3.2.1 History Token Hardening

## Scope

Sprint 3.2.1 is a narrow safety and diagnostics patch. It changes only transient history-token handling, input validation evidence, CSV evidence, version identification, and related documentation. It does not change signal formulas, score semantics, thresholds, shifts, stale-data policy, or trading behavior.

## Root Cause

Sprint 3.2 Patch 1 cast `Bars(symbol, timeframe)` directly to `ulong` and stored the result as the active history generation. `ApplyHistoryContinuity()` then unconditionally copied that value into its baseline. A transient zero therefore replaced a valid baseline, and the next valid token was compared with zero and classified as an abnormal jump.

`Bars()` may be temporarily nonpositive while terminal history is unavailable or being synchronized. A nonpositive result is an unavailable observation, not a valid history generation.

## Snapshot Contract

Snapshot schema V5 distinguishes:

| Field | Meaning |
|---|---|
| `observed_history_generation` | Current `Bars()` observation; zero when unavailable. |
| `last_valid_history_generation` | Valid baseline that existed before the current observation. |
| `history_token_valid` | Whether the current observation is positive and valid. |
| `history_change_state` | Continuity state, including explicit token unavailability. |
| `history_baseline_reset` | Whether initialization or context change requires a new baseline. |
| `history_reason` | Typed reason for the current classification. |
| `snapshot_usable` | Whether the market snapshot passes history, stale, and core data-quality gates. |

Typed reasons include `NONE`, `BASELINE_INITIALIZED`, `NORMAL_INCREMENT`, `CONTEXT_RESET`, `TOKEN_UNAVAILABLE`, `HISTORY_SHRINK`, `HISTORY_RESET`, `ABNORMAL_JUMP`, `NORMAL_UNCHANGED`, and `TOKEN_RECOVERED`.

## Baseline Preservation

- A nonpositive token remains visible as observed value zero.
- The snapshot is marked `TOKEN_UNAVAILABLE` and unusable.
- Zero never replaces the internal last-valid baseline.
- The next valid token is compared with the preserved last-valid token.
- Recovery advance is accepted only when it is no larger than the elapsed closed-bar interval since the last valid observation.
- A recovery advance beyond that interval remains an abnormal jump.
- Shrink and reset classification remains active and fail-closed.
- Symbol, timeframe, or execution-mode changes discard the old context baseline and initialize the new context safely.

## Validation And Decision

`ResultValidator` rejects an unavailable history token with the explicit reason `HISTORY_TOKEN_UNAVAILABLE`. `DecisionEngine` remains the only final-action writer and converts that failed input validation into `BLOCKED`. No fallback value hides the invalid observation, and regression status is not a DecisionEngine input.

## CSV Evidence

The existing Trend and Momentum regression columns are preserved. Sprint 3.2.1 appends:

- `observed_history_generation`
- `last_valid_history_generation`
- `history_token_valid`
- `history_change_reason`
- `snapshot_usable`
- `final_action`
- `final_decision_reason`

Output files:

- `SWV5_SPRINT3_2_1_TREND_REGRESSION.csv`
- `SWV5_SPRINT3_2_1_MOMENTUM_REGRESSION.csv`

A row may correctly contain regression `PASS`, `snapshot_usable=false`, `final_action=BLOCKED`, and `history_change_reason=TOKEN_UNAVAILABLE`. Regression PASS means formula parity only; it does not certify snapshot health or authorize a final action.

Deduplication remains process-local and keyed by snapshot sequence plus observed generation for each CSV stream. Reloading the indicator resets the in-memory deduplication state, so separate sessions can repeat an evaluation identity. No persistent deduplication was introduced.

## Manual Runtime Checklist

Use XAUUSD M15. Do not mark any item PASS without inspectable evidence.

### Closed-Bar Mode

- [ ] Attach the Sprint 3.2.1 indicator.
- [ ] Confirm a normal valid history token and CSV rows.
- [ ] Confirm normal new bars do not raise unexpected `HISTORY_CHANGED`.
- [ ] Confirm Trend and Momentum regression results remain consistent.
- [ ] Confirm final action and final decision reason are exported.

### Every-Tick Mode

- [ ] Observe multiple ticks on the same bar.
- [ ] Confirm the token remains stable during normal ticks.
- [ ] Confirm no duplicate evidence flood beyond one row per evaluation identity.

### Reconnect Test

- [ ] Interrupt network connectivity once, then reconnect.
- [ ] If `Bars() <= 0` occurs, confirm `TOKEN_UNAVAILABLE`.
- [ ] Confirm `snapshot_usable=false` and `final_action=BLOCKED`.
- [ ] Confirm the previous valid baseline is preserved in CSV.
- [ ] Confirm the first valid recovery does not produce a false abnormal jump.
- [ ] Confirm later normal increments return to normal state.
- [ ] Confirm a genuine discontinuity still raises `HISTORY_CHANGED`.

### Lifecycle Checks

- [ ] Remove and reattach the indicator.
- [ ] Restart the chart or terminal.
- [ ] Inspect Journal and Experts for runtime errors.
- [ ] Confirm no invalid handle or `CopyBuffer()` errors.
- [ ] Confirm no dashboard object leaks.
- [ ] Confirm both CSV files open and append correctly.

## Known Limitations

- `Bars()` remains a proxy and cannot detect every same-count broker history correction.
- A legitimate bulk history load may still resemble a discontinuity.
- Recovery tolerance uses elapsed closed-bar intervals; unusual broker history synchronization may still require evidence-based classification.
- CSV deduplication does not persist across indicator reloads or terminal restarts.
- Runtime behavior remains evidence-pending until the user supplies MT5 artifacts.
