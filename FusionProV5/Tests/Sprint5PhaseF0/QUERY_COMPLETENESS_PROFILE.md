# Phase F0 Query Completeness Profile

TEST ONLY / F0 / DEMO MEASUREMENT REQUIRED.

Incomplete and empty are distinct outcomes. A successful API call with zero rows
is not authoritative empty unless the complete required domain and time window
are proven covered.

| Broker-owned domain | Candidate MQL5 API | Required enumeration/window evidence | Current status |
|---|---|---|---|
| Active positions | `PositionsTotal`, indexed selection and complete field reads | Exact account/server/symbol filters, count stability, per-row read success | NOT MEASURED |
| Active orders | `OrdersTotal`, indexed selection and complete field reads | Exact filters, count stability, per-row read success | NOT MEASURED |
| History orders | `HistorySelect`, `HistoryOrdersTotal`, indexed reads | Server-time window, selection success, truncation/latency/re-read evidence | NOT MEASURED |
| History deals | `HistorySelect`, `HistoryDealsTotal`, indexed reads | Server-time window, selection success, truncation/latency/re-read evidence | NOT MEASURED |

MT5 durable query APIs above do not constitute a separate durable broker
transaction-history query. Live callback transactions and queryable durable
orders/deals/positions are different evidence channels.

Required result metadata: success/failure, completeness enum, window bounds,
server-time basis, filters, row count, per-row read status, profile/build,
connection state, stable re-read observations, and digest.

Verdict: complete broker query evidence **has not been obtained**. Empty-result
and authoritative-no-side-effect claims are therefore prohibited.
