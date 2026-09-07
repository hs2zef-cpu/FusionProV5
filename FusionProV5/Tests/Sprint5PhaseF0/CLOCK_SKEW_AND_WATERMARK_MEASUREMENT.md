# Phase F0 Clock Skew and Watermark Measurement

TEST ONLY / F0 / DEMO MEASUREMENT REQUIRED.

| Measurement | Samples | Current result |
|---|---:|---|
| Terminal/local clock | 6 | Epochs `1788639300`, `1788639344`, `1788817413`, `1788817485`, `1788819748`, `1788820434` |
| Broker/server clock | 6 | Epochs `1788614100`, `1788614144`, `1788792213`, `1788792285`, `1788794548`, `1788795234` |
| Observed skew/range | 6 | local minus server = exactly +25,200 seconds (+07:00) in all samples |
| Active-order visibility latency | 0 | NOT MEASURED |
| Position visibility latency | 0 | NOT MEASURED |
| History-order visibility latency | 0 | NOT MEASURED |
| History-deal visibility latency | 0 | NOT MEASURED |
| Reconnect visibility latency | 0 | NOT MEASURED |
| Stable re-read interval | 0 | NOT MEASURED in the post-materialization run; completeness remains `UNPROVEN` |
| API-invocation to post-attempt query | 1 | Approximately 685.920 seconds; observation only, not a visibility guarantee |

## Post-materialization build-6180 classification

The exact +25,200-second difference is classified as a clock-basis/timezone
observation. It is not broker settlement latency, order/deal visibility latency,
a watermark interval, or an authoritative negative-evidence timeout.

The query history window was exactly 86,400 server-time seconds. One non-XAUUSD,
zero-volume/zero-price account record was timestamped within the window. Its age
relative to query time is not interpreted as trading visibility latency.

These two samples belong only to `F0-6180-POST-MAGIC-PRESEND-001` and are not
combined with archival pre-materialization clock data.

Future attended-Demo runs must record raw observations rather than optimize a
timeout. Persisted timestamps are evidence, not current clock authority. No
duration in this document may be interpreted as proof that no side effect
occurred.

The empirical attempt and post-attempt query retained the exact +25,200-second
local/server difference. The elapsed interval to the query is not settlement
latency because no broker acknowledgement or durable broker row was observed.
