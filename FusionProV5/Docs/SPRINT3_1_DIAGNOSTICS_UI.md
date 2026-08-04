# Fusion Pro V5 Sprint 3.1 Diagnostics and UI

## Summary

Sprint 3.1 is diagnostics and dashboard hardening only. It changes the validated default dashboard Y offset to 150, exposes typed Momentum regression mismatch reasons, and derives panel height from visible content. Trading logic, engine calculations, thresholds, regression pass/fail rules, and DecisionEngine behavior are unchanged.

## Changed Files

- New main: SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT3_1.mq5
- Updated: FusionProV5/Regression/SW_V5_MomentumRegression.mqh
- Updated: FusionProV5/Dashboard/SW_V5_ReadOnlyDashboard.mqh
- New: FusionProV5/Docs/SPRINT3_1_DIAGNOSTICS_UI.md
- New: FusionProV5/Docs/BREAKING_CHANGES_SPRINT3_1.md
- Updated: FusionProV5/Docs/COMPILE_REPORT.md

## Default Position

- Default corner remains CORNER_LEFT_UPPER.
- Default X offset remains 14.
- Default Y offset is now 150.
- InpPanelY remains configurable and is passed into the dashboard.
- The dashboard contains no internal hardcoded override of the configured position.

## Typed Momentum Regression Diagnostics

SWV5_MomentumRegressionResult now exposes:

- status
- primary_reason
- mismatch_flags
- diagnostic_text
- mismatch_reason
- snapshot_sequence
- history_generation

Supported reasons map only to comparisons already present in Sprint 3: NOT_READY, METADATA, SHIFT, BODY/ATR, RSI value/state, MACD histogram/state, Stochastic K/state, bias, momentum state, score, and MULTIPLE. MACD main/signal and Stochastic D categories were not added because Sprint 3 did not compare those fields independently.

PASS reports primary reason NONE, zero flags, and diagnostic text NONE. NOT_READY records the available readiness cause. FAIL preserves every detected mismatch in flags and detailed CSV text.

## Mismatch Priority

1. NOT_READY is used when either side cannot produce a ready comparison.
2. METADATA has highest FAIL priority because sequence or history-generation mismatch invalidates the comparison context.
3. SHIFT is next because source-bar mismatch invalidates value comparisons.
4. MULTIPLE is used when more than one non-foundational mismatch is present.
5. A single remaining mismatch reports its specific typed reason.

Regression status and diagnostics remain disconnected from DecisionEngine and cannot change final action.

## Automatic Height

InpPanelAutoHeight defaults to true. InpPanelHeight remains available for compatibility and is used when auto height is false.

The calculation includes the 58-pixel header, four section headings, section gaps, separators, all 18 visible rows, the effective row step, and bottom padding:

effective row step = max(InpPanelRowGap, InpPanelFontSize + 6)

required height = last visible row Y + max(16, InpPanelFontSize + 7)

With supported settings, calculated height ranges from 528 pixels at font 8/spacing 18 to 587 pixels at font 12/spacing 22. The default font 9/spacing 20 height is 556 pixels.

When auto height is false, the panel uses max(InpPanelHeight, required height). A manual value can add space but cannot clip rows. Height is recalculated during initialization/rendering and CHARTEVENT_CHART_CHANGE without recreating existing objects.

## Read-Only Boundary

The dashboard formats supplied DTO fields only. It does not calculate indicators, compare regression values, mutate DTOs, assign actions, change health/data-quality flags, call account/trading APIs, or expose trade buttons.

## Preservation Hashes

- TrendEngine: 17865AFE4B36E6EC6E5C1C57DB1BE895B1360E28172E6A54765AF365FA0D35D4
- MomentumEngine: 0E2B9F899A57899B3AFF1EA34CB9D96E6E34F02BB054B35CF2B3591CF2B60456
- DecisionEngine: 2F5FBDDF0BF0B7B9743D35F92A9197F478F3C92A746C88D5CAD1CB5E9C3DA9A3
- IndicatorCache: D342974A050F5F31F19D8ED816C56E0DB46E8258A2114BB5471560E0853909E0
- TrendRegression: 90D6722F7BCDDB5E3CB1CF3C66CBA83BD5C98DF9F59A02EB3E84FAF17BB8A8E0
- V4.2 source: 8B7ACBD243415376AF1E476944B4E2228CD0A3ED0247572BC3E91A74499CAE6D
- Fibo V3 source: 0A86A83177F686F04F5B85BBABE610CB92EA450E6994864C40C6BB25FCFC4D3D

## Manual Runtime Checklist

- [ ] Dashboard defaults to Y=150 and does not overlap One-click Trading.
- [ ] Manual Y offset and all corners remain adjustable.
- [ ] Auto height fits every row with no text outside the panel.
- [ ] Font sizes 8, 9, 10, 11, and 12 render correctly.
- [ ] Row spacing 18 through 22 renders correctly.
- [ ] PASS displays reason NONE.
- [ ] FAIL displays a useful specific or MULTIPLE reason.
- [ ] NOT_READY displays the available readiness cause.
- [ ] Chart resize and M15/M30/H1 switching preserve layout.
- [ ] Remove/reload creates no duplicates, flicker, or object leaks.
- [ ] Journal and Experts contain no runtime errors.
- [ ] Final actions match Sprint 3 behavior.

## Known Limitations

MetaEditor compilation cannot verify chart overlap, pixel clipping, flicker, object lifecycle, or runtime-injected regression failures. Historical regression equivalence remains unclaimed.

## Recommendation

Sprint 3.1 is compile-ready, but it should not be locked until the manual MT5 checklist is completed.

