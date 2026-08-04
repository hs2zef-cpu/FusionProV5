# Fusion Pro V5 Sprint 3.2 Runtime Evidence

## Evidence Status

The user reports that MT5 checks have already been performed for local compilation, attachment, M15/M30/H1 switching, dashboard rendering, resize/reload, Journal/Experts inspection, and Trend/Momentum regression states. Those checks are **REPORTED PERFORMED / EVIDENCE PENDING** because systematic artifacts were not supplied with Sprint 3.2. They are not marked VERIFIED and are not fabricated here.

## Test Record Template

Create one record per terminal, broker, symbol, timeframe, execution mode, and material input set.

```text
Evidence ID:
Status: PENDING | PASS | FAIL | INCONCLUSIVE
Tester decision:
Test date/time and timezone:
MT5 terminal build:
Broker/server:
Symbol:
Timeframe:
Execution mode: CLOSED_BAR | EVERY_TICK | REPLAY
Indicator version:
Indicator input preset or full input reference:
Stale tolerance seconds:

MetaEditor compile result:
Chart attachment result:
M15/M30/H1 switch result:
Resize result:
Remove/reload result:
Terminal restart result:
Journal errors:
Experts errors:

Price Action health/state/block result:
Legacy score-semantics warning result:
Invalid score-semantics fail-closed result:
History baseline initialization result:
Normal new-bar history result:
Timeframe reset result:
Injected/observed history discontinuity result:
Stale-data result:
Weekend/closed-session result:

Trend regression status and mismatch reason:
Momentum regression status and mismatch reason:
Duplicate CSV row check:
Unexpected final-action change:

Trend CSV path:
Momentum CSV path:
Screenshot/file references:
Journal export reference:
Experts export reference:
Notes and limitations:
```

## Required Manual Checklist

- [ ] Dashboard defaults to Y=150.
- [ ] Price Action health is displayed.
- [ ] PA block reason is visible when PA blocks.
- [ ] Score-semantics warning is visible.
- [ ] Default settings do not silently report fixed score 80 below threshold 85.
- [ ] Invalid/incompatible score semantics fail closed with a clear reason.
- [ ] M15/M30/H1 switching works.
- [ ] CLOSED_BAR mode works.
- [ ] EVERY_TICK mode works.
- [ ] History baseline initializes without an alarm.
- [ ] A normal new bar does not raise HISTORY_CHANGED.
- [ ] Timeframe switching resets the baseline.
- [ ] A genuine discontinuity raises HISTORY_CHANGED.
- [ ] Genuine stale data raises STALE_DATA.
- [ ] Weekend/closed market does not create an obvious stale false positive.
- [ ] Trend regression remains correct.
- [ ] Momentum regression remains correct.
- [ ] CSV rows are generated without duplicate snapshot rows.
- [ ] Resize/reload/restart works.
- [ ] No duplicate objects or object leaks remain.
- [ ] Journal and Experts contain no runtime errors.
- [ ] No unexpected final-action change occurs beyond the accepted non-comparable-score closure.

## Verification Rule

Mark an item VERIFIED only when the record contains an inspectable MT5 artifact or the user supplies explicit evidence for it. A remembered or reported run may be recorded as performed, but remains evidence pending.

## Sprint 3.2.1 Follow-Up

The supplied Sprint 3.2 evidence established two transient zero-token sequences. In both sequences, formula regression remained PASS while data quality flagged the history event. Sprint 3.2.1 hardens the baseline and expands CSV evidence; it does not reinterpret regression PASS as snapshot health.

Required new evidence files:

- `SWV5_SPRINT3_2_1_TREND_REGRESSION.csv`
- `SWV5_SPRINT3_2_1_MOMENTUM_REGRESSION.csv`

Additional evidence requirements:

- [ ] A transient nonpositive token exports `TOKEN_UNAVAILABLE`.
- [ ] The same row exports `snapshot_usable=false`.
- [ ] The same row exports `final_action=BLOCKED` and `HISTORY_TOKEN_UNAVAILABLE`.
- [ ] `last_valid_history_generation` remains the pre-event valid baseline.
- [ ] The first valid recovery is compared with that baseline and does not create a false jump.
- [ ] A genuine shrink, reset, or abnormal jump still fails closed.
- [ ] Closed-bar and every-tick CSV deduplication match the documented process-local rule.

Sprint 3.2.1 runtime status is **PENDING**. No checklist item above is marked PASS by implementation or compilation alone.
