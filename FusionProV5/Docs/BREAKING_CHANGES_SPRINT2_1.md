# Breaking Changes Sprint 2.1

## Dashboard Changes

- The unframed text-label presentation is replaced by an opaque framed chart-object panel.
- Dashboard objects now use the unique `SWV5_S21_DASH_` prefix in the Sprint 2.1 harness.
- A new seven-argument `Configure()` overload accepts corner, position, size, and row gap.
- The existing three-argument `Configure(prefix, x, y)` overload remains available for source compatibility.
- `RefreshLayout()` is new and is called for `CHARTEVENT_CHART_CHANGE`.

## New Inputs

- `InpPanelCorner`
- `InpPanelWidth`
- `InpPanelHeight`
- `InpPanelRowGap`

Existing `InpPanelX` and `InpPanelY` remain.

## Behavioral Compatibility

- No DTO schema or engine interface changed.
- No Trend, Regression, Decision, Snapshot, IndicatorCache, ExecutionPolicy, or Legacy behavior changed.
- No threshold or final BUY/SELL behavior changed.
- The Sprint 2 harness remains unchanged; Sprint 2.1 uses a new harness file.
