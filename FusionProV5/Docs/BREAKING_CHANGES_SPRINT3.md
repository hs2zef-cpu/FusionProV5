# Breaking Changes Sprint 3

## API Changes

- Snapshot schema version advances from 2 to 3.
- SWV5_IndicatorSnapshot adds momentum readiness fields.
- SWV5_MomentumResult replaces the placeholder state-only DTO with typed momentum evidence.
- CCentralOrchestrator::Evaluate() adds MomentumResult and MomentumRegressionResult outputs. The Sprint 2 overload is retained for source compatibility.
- CCentralOrchestrator::Init() adds optional momentum configuration parameters with V4.2 defaults.
- CDecisionEngine::Decide() now requires MomentumResult.
- CReadOnlyDashboard::Render() now requires MomentumResult and MomentumRegressionResult.
- The Sprint 3 dashboard default height is 536 pixels to fit four compact new rows.

## Behavioral Compatibility

- No final BUY/SELL rule was added.
- Momentum score remains 0.0; candidate-dependent V4.2 score additions remain legacy.
- Legacy Fibo compatibility remains active.
- Missing or invalid mandatory Momentum output now fails safely through DecisionEngine.
- PriceActionEngine, TrendEngine, Trend regression, trading thresholds, and legacy adapter logic are unchanged.

## Preserved Artifacts

- The locked Sprint 2.2 project remains untouched.
- Original V4.2 and Fibo V3 files remain byte-identical.
- Sprint 3 is contained in a new project folder and main indicator.

