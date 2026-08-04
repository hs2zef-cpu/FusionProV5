# Fusion Pro V5 Runtime Evidence

This folder defines how Sprint 3.2.1 MT5 runtime evidence is recorded. Do not mark a run VERIFIED without inspectable terminal artifacts.

## Suggested Session Layout

```text
Evidence/
  README.md
  SW_V5_RegressionCsvWriter.mqh
  sessions/
    YYYYMMDD_HHMM_server_symbol_mode/
      test_record.md
      chart.png
      journal.txt
      experts.txt
      SWV5_SPRINT3_2_1_TREND_REGRESSION.csv
      SWV5_SPRINT3_2_1_MOMENTUM_REGRESSION.csv
```

The `sessions` tree is a template only and is not created with fabricated artifacts.

## CSV Location

At runtime, MetaTrader writes enabled CSV output to:

```text
<Terminal Data Folder>/MQL5/Files/
```

Use `File -> Open Data Folder` in MT5. Copy the resulting CSV into the evidence session only after the run. The indicator also prints the resolved terminal Files directory when CSV export is enabled.

CSV deduplication is process-local. Removing or reloading the indicator resets its in-memory sequence and deduplication state, so evidence from separate sessions may contain repeated identities.

## Required Record

Use the template in `FusionProV5/Docs/SPRINT3_2_RUNTIME_EVIDENCE.md`. Record terminal build, broker/server, symbol, timeframe, mode, inputs, compile/attachment/layout lifecycle, Journal/Experts status, both regressions, mismatch reasons, data-quality behavior, file references, and tester decision.

Allowed final statuses are `PASS`, `FAIL`, and `INCONCLUSIVE`. `PENDING` means evidence has not yet been captured.
