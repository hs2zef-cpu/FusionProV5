# Fusion Pro V5 Sprint 2 Trend Regression

## Baseline

`SW_V5_TrendRegression.mqh` encodes a V4.2 trend oracle before the V5 TrendEngine migration. The oracle is intentionally independent from `CTrendEngine` and reproduces only these source behaviors:

- H1 EMA fast/slow alignment always reads shift `1`.
- H4 macro EMA alignment reads shift `1` for closed-bar evaluation and shift `0` for every-tick preview.
- Fast above slow is bullish/up, fast below slow is bearish/down, and equality is neutral/flat.
- H1 trend is a direction gate into `ComputeCoreRating`; it has no standalone numeric score contribution, so the isolated trend score is `0.0`.
- Macro direction is a downstream compatibility dependency. The V4.2 final-score penalty and final direction logic remain in the legacy path and are not migrated in Sprint 2.

## Comparison Status

- `PASS`: the in-process V4.2 oracle and V5 result match for metadata, shifts, bias, isolated score, and macro state.
- `EXPECTED_DIFFERENCE`: reserved for an explicitly documented, approved fixture difference. Sprint 2 does not generate this status automatically.
- `FAIL`: a ready V4.2 oracle and valid V5 result differ.
- `NOT_READY`: required EMA inputs or the V5 result are unavailable.

## CSV Format

```text
timestamp,snapshot_sequence,history_generation,symbol,timeframe,v4_trend_bias,v5_trend_bias,v4_trend_score,v5_trend_score,v4_macro_state,v5_macro_state,match_status,mismatch_reason
```

`CTrendRegression::CsvHeader()` and the result `csv_row` provide the logging format. `InpLogTrendRegression` controls emission to the Experts log.

## Evidence Boundary

A `PASS` proves parity for the current immutable snapshot against the extracted V4.2 oracle. It does not prove full historical equivalence. Exact equivalence remains unclaimed until the indicator is run over representative MT5 history in closed-bar and every-tick modes and the emitted rows are reviewed.

## Sprint 2 Result

The regression fixture compiles and is integrated into each orchestrated evaluation. No historical MT5 dataset was executed in this environment, so the project-level historical result remains `NOT_READY`; live rows will report `PASS`, `FAIL`, or `NOT_READY` per snapshot.
