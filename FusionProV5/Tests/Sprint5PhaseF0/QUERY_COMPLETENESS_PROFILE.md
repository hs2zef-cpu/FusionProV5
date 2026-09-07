# Phase F0 Query Completeness Profile

TEST ONLY / F0 / DEMO MEASUREMENT REQUIRED.

Incomplete and empty are distinct outcomes. A successful API call with zero rows
is not authoritative empty unless the complete required domain and time window
are proven covered.

## Successful BUY and cleanup observations

Run `F0-6180-SUCCESSFUL-BUY-CLEANUP-001` produced two post-action reads. The
first positively observed one open runtime-Magic BUY position, its history
order, and its history deal. The second positively observed the separately
authorized Magic-zero operator cleanup order and exit deal linked to the same
position, while reporting zero positions and active orders.

| Read | Positions | Active orders | History orders | History deals | Completeness |
|---|---:|---:|---:|---:|---|
| Post-fill | 1 | 0 | 1 | 1 | `UNPROVEN` |
| Post-cleanup | 0 | 0 | 2 | 2 | `UNPROVEN` |

Positive returned records prove that those specific records were visible. The
post-cleanup full-volume exit deal plus shared position ID positively supports
closure of the observed position. Zero totals still do not prove global
authoritative emptiness because completeness remains `UNPROVEN`.

| Broker-owned domain | Candidate MQL5 API | Required enumeration/window evidence | Post-attempt build-6180 observation |
|---|---|---|---|
| Active positions | `PositionsTotal`, indexed selection and complete field reads | Exact account/server/symbol filters, count stability, per-row read success | API success; 0 rows; `UNPROVEN` |
| Active orders | `OrdersTotal`, indexed selection and complete field reads | Exact filters, count stability, per-row read success | API success; 0 rows; `UNPROVEN` |
| History orders | `HistorySelect`, `HistoryOrdersTotal`, indexed reads | Server-time window, selection success, truncation/latency/re-read evidence | `HistorySelect` success; 0 rows; `UNPROVEN` |
| History deals | `HistorySelect`, `HistoryDealsTotal`, indexed reads | Server-time window, selection success, truncation/latency/re-read evidence | `HistorySelect` success; 0 rows; `UNPROVEN` |

The post-attempt query for `F0-6180-CLIENT-LOCAL-REJECT-001` covered
`1788708834..1788795234`, exactly 86,400 server-time seconds. It reported API
success, zero rows in all four domains, and `UNPROVEN` completeness. Runtime
strategy rows and unrelated rows were both zero in this separate query.

Those zero counts do not prove that the failed API invocation had no broker side
effect. They also do not erase or contradict the separate 2026-09-05 baseline,
whose earlier window contained one Magic-zero account/balance row.

The prior read captured for `F0-6180-POST-MAGIC-PRESEND-001` had history
window was `1788527700..1788614100`, exactly 86,400 server-time seconds. It
reported `connected=1`, `history_select_success=1`, and `last_error=0`.

The query returned 1 total history-deal row, 0 runtime-strategy-matching rows,
and 1 unrelated/non-strategy row. The single returned row has no symbol, no
order or position identity, `magic=0`, `volume=0`, `price=0`, and comment
`D-trial-USD-d323c05a010a40`. It is classified as a non-XAUUSD account/balance
record for this profile. It is not XAUUSD execution, correlation, visibility,
or no-side-effect evidence, and it is not silently discarded from the raw
snapshot.

The materialized read-only probe now classifies every returned Magic as runtime
match, fixture/reference, zero account/balance/non-strategy, or unrelated. It
does not filter rows and explicitly denies correlation authority from Magic
alone. The classification was not present in these historical observations and
is not backfilled into their raw evidence.

MT5 durable query APIs above do not constitute a separate durable broker
transaction-history query. Live callback transactions and queryable durable
orders/deals/positions are different evidence channels.

Required result metadata: success/failure, completeness enum, window bounds,
server-time basis, filters, row count, per-row read status, profile/build,
connection state, stable re-read observations, and digest.

Repeated-read stability was not measured inside this new run boundary. This does
not prove broker-query completeness, absence of truncation, history visibility
latency, or authoritative emptiness. All earlier query evidence, including the
prior 41-second re-read, is archival and is not combined with this observation.

Verdict: complete broker query evidence **has not been obtained**. Zero-row
domains remain `UNPROVEN`, and empty-result and authoritative-no-side-effect
claims are prohibited.
