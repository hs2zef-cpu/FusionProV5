# Phase F0 Clock Skew and Watermark Measurement

TEST ONLY / F0 / DEMO MEASUREMENT REQUIRED.

| Measurement | Samples | Current result |
|---|---:|---|
| Terminal/local clock | 3 | Epochs `1788612098`, `1788612139`, `1788612329` |
| Broker/server clock | 3 | Epochs `1788586898`, `1788586939`, `1788587129` |
| Observed skew/range | 3 | local minus server = exactly +25,200 seconds (+07:00) in all samples |
| Active-order visibility latency | 0 | NOT MEASURED |
| Position visibility latency | 0 | NOT MEASURED |
| History-order visibility latency | 0 | NOT MEASURED |
| History-deal visibility latency | 0 | NOT MEASURED |
| Reconnect visibility latency | 0 | NOT MEASURED |
| Stable re-read interval | 1 | 41 seconds; query counts and returned row unchanged; completeness still `UNPROVEN` |

## Build-6180 classification

The exact +25,200-second difference is classified as a clock-basis/timezone
observation. It is not broker settlement latency, order/deal visibility latency,
a watermark interval, or an authoritative negative-evidence timeout.

Both query history windows were exactly 86,400 server-time seconds. One
non-XAUUSD, zero-volume/zero-price account record was timestamped within each
window. Its age relative to query time is not interpreted as trading visibility
latency.

These three samples belong only to `F0-6180-PRESEND-001`. Archival
`F0-QRY-001` clock data is not included.

Future attended-Demo runs must record raw observations rather than optimize a
timeout. Persisted timestamps are evidence, not current clock authority. No
duration in this document may be interpreted as proof that no side effect
occurred.
