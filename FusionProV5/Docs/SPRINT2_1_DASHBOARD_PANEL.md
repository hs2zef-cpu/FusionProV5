# Fusion Pro V5 Sprint 2.1 Dashboard Panel

## Scope

Sprint 2.1 changes only the dashboard presentation layer and adds a dedicated `SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT2_1.mq5` harness. Sprint 2 trend, regression, decision, snapshot, IndicatorCache, threshold, final-action, and legacy behavior remain unchanged.

## Panel Structure

The dashboard is a framed chart overlay composed from a fixed set of chart objects:

- `OBJ_RECTANGLE_LABEL`: opaque panel background, header bar, live indicator, and section separators.
- `OBJ_LABEL`: title, section headings, field labels, and field values.
- Prefix: `SWV5_S21_DASH_`.
- Default corner: `CORNER_LEFT_UPPER`.
- Default size: `344 x 456` pixels.
- Default row gap: `20` pixels.

The panel has four sections: Engine Health, Market State, Final Decision, and System. It displays no legacy buffer numbers and contains no buttons or interactive controls.

## Object Lifecycle

- Every object name is deterministic and prefix-scoped.
- `ObjectFind()` precedes `ObjectCreate()`, so an existing object is reused.
- Text, color, position, and style properties are set only when their value changed.
- Static row labels and dynamic values use separate update paths to avoid clearing/repainting values.
- `ChartRedraw()` runs only after a property change.
- `OBJPROP_BACK=false` and explicit Z-order keep the opaque panel in front of candles.
- Objects are non-selectable, unselected, and hidden from the object list.
- `Clear()` deletes all objects with the dashboard prefix and is called by `OnDeinit()`.
- `OnChartEvent(CHARTEVENT_CHART_CHANGE)` reapplies layout after chart resizing.
- Timeframe changes and reloads use normal deinitialization/reinitialization cleanup.

## Configurable Inputs

- `InpPanelCorner`
- `InpPanelX`
- `InpPanelY`
- `InpPanelWidth`
- `InpPanelHeight`
- `InpPanelRowGap`

Width is validated to `320..600`, row gap to `18..22`, and height must fit all rows for the selected gap.

## Read-Only Boundary

`Render()` receives only const references to EngineInput, TrendResult, LegacyResult, DecisionResult, and TrendRegressionResult. The dashboard maps existing enum/status values to text and display colors only. It does not assign DTO fields, calculate scores, create decisions, call engines, or invoke account/trade APIs.

## Static Check Results

- No DTO-field assignments in Dashboard.
- No account, order, position, deal, history, or trading-library calls in Dashboard.
- No `CopyBuffer`, `CopyRates`, `iCustom`, alerts, or notifications in Dashboard.
- No final action assignment in Dashboard.
- Fixed unique prefix present in both Dashboard and Sprint 2.1 harness.
- Prefix cleanup is called from `OnDeinit()`.
- TrendEngine, regression, DecisionEngine, snapshot types, IndicatorCache, Orchestrator, and Sprint 2 harness hashes match the Sprint 2 baseline.
- Original V4.2 and Fibo V3 hashes match the Sprint 2 baseline.

## Runtime Checklist

- [ ] Panel overlays candles with a fully opaque background.
- [ ] Header, labels, and values are readable and not crowded.
- [ ] Rows maintain at least 18 pixels of vertical spacing.
- [ ] Repeated ticks do not cause visible flicker.
- [ ] Repeated ticks do not create duplicate objects.
- [ ] Remove/reload leaves no dashboard objects behind.
- [ ] Timeframe switching recreates one clean panel.
- [ ] Chart resizing keeps the configured corner and offsets.
- [ ] Terminal/indicator restart recreates one clean panel.
- [ ] BLOCKED, DEGRADED, INVALID, and failed regression states are visually obvious.
- [ ] Journal and Experts contain no runtime errors.

Manual MT5 chart validation remains required because MetaEditor compilation cannot verify pixels, flicker, or terminal object lifecycle behavior.
