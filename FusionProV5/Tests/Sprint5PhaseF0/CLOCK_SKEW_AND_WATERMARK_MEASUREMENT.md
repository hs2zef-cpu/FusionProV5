# Phase F0 Clock Skew and Watermark Measurement

TEST ONLY / F0 / DEMO MEASUREMENT REQUIRED.

| Measurement | Samples | Current result |
|---|---:|---|
| Terminal/local clock | 11 | Prior six samples plus `1788824831`, `1788824975`, `1788825519`, `1788825630`, `1788825968` |
| Broker/server clock | 11 | Prior six samples plus `1788799631`, `1788799775`, `1788800319`, `1788800430`, `1788800768` |
| Observed skew/range | 11 | local minus server = exactly +25,200 seconds (+07:00) in all samples |
| Active-order visibility latency | 0 | NOT MEASURED |
| Position visibility latency | 1 | Positive observation at approximately 110.976 seconds; no guarantee |
| History-order visibility latency | 1 | Positive observation at approximately 110.976 seconds; no guarantee |
| History-deal visibility latency | 1 | Positive observation at approximately 110.976 seconds; no guarantee |
| Reconnect visibility latency | 0 | NOT MEASURED |
| Stable re-read interval | 0 | NOT MEASURED in the post-materialization run; completeness remains `UNPROVEN` |
| API-invocation to post-attempt query | 2 | Historical rejection 685.920 seconds; successful run 110.976 seconds; neither is a visibility guarantee |

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

The corrected successful run added five +25,200-second samples. Its first
post-fill query occurred approximately `110.976` seconds after the synchronous
result and positively observed the position, history order, and history deal.
That is one visibility sample, not an upper-bound guarantee, stable watermark,
or negative-evidence timeout. Reconnect visibility remains unmeasured.
