# Phase F0 Query Completeness Profile

TEST ONLY / F0 / DEMO MEASUREMENT REQUIRED.

Incomplete and empty are distinct outcomes. A successful API call with zero rows
is not authoritative empty unless the complete required domain and time window
are proven covered.

| Broker-owned domain | Candidate MQL5 API | Required enumeration/window evidence | Build-6180 observations |
|---|---|---|---|
| Active positions | `PositionsTotal`, indexed selection and complete field reads | Exact account/server/symbol filters, count stability, per-row read success | API success; 0 rows; `UNPROVEN` |
| Active orders | `OrdersTotal`, indexed selection and complete field reads | Exact filters, count stability, per-row read success | API success; 0 rows; `UNPROVEN` |
| History orders | `HistorySelect`, `HistoryOrdersTotal`, indexed reads | Server-time window, selection success, truncation/latency/re-read evidence | `HistorySelect` success; 0 rows; `UNPROVEN` |
| History deals | `HistorySelect`, `HistoryDealsTotal`, indexed reads | Server-time window, selection success, truncation/latency/re-read evidence | `HistorySelect` success; 1 row; `UNPROVEN` |

Two fresh build-6180 reads were captured 41 seconds apart. Their history windows
were `1788500498..1788586898` and `1788500539..1788586939`, each exactly 86,400
server-time seconds. Both reported `connected=1`, `history_select_success=1`,
and `last_error=0`. Counts and the single returned row were identical.

The single history-deal row has no symbol, no order or position identity,
`magic=0`, `volume=0`, `price=0`, and comment
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

Repeated-read count/row stability was observed for 41 seconds. This does not
prove broker-query completeness, absence of truncation, history visibility
latency, or authoritative emptiness. Earlier 6090/6140 query evidence is
archival and is not included in these build-6180 observations.

Verdict: complete broker query evidence **has not been obtained**. Zero-row
domains remain `UNPROVEN`, and empty-result and authoritative-no-side-effect
claims are prohibited.
