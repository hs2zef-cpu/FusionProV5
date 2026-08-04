# Breaking Changes Sprint 3.1

## Dashboard API

- New nine-argument Configure overload accepts auto-height mode and manual height.
- Existing Configure overloads remain available and use manual-height compatibility behavior.
- The new Sprint 3.1 harness defaults InpPanelY to 150.
- InpPanelAutoHeight is new and defaults to true.
- InpPanelHeight remains 536 and is used as a manual minimum only when auto height is false.
- A read-only Reg Reason row is added.

## Regression DTO

- SWV5_MomentumRegressionResult adds typed primary_reason, mismatch_flags, and diagnostic_text fields.
- Momentum CSV adds primary_reason, mismatch_flags, and diagnostic_text columns.
- PASS/FAIL/NOT_READY outcomes use the existing Sprint 3 comparisons.

## Behavioral Compatibility

- No Trend or Momentum calculation changed.
- No threshold changed.
- No DecisionEngine or final-action behavior changed.
- No new BUY/SELL rule was introduced.
- Regression diagnostics remain decision-neutral.

