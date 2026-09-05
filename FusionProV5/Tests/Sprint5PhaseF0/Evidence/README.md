# Phase F0 Raw Evidence Directory

Measured evidence inventory:

- `F0-6180-PRESEND-001.json`: standalone attended Demo build-6180 evidence;
  two read-only query observations followed by one default-disarmed environment
  and symbol-profile observation, ending with `send_attempted=0`. No broker
  call. At capture time the exact frozen runtime Magic was undefined; this
  historical record is not backfilled after materialization.
- `F0-QRY-001.json`: attended Demo read-only query observation from terminal
  build 6090, before the automatic update/restart to build 6140. No broker call.
  Archival pre-6180 evidence only; prohibited from combination with the future
  build-6180 empirical profile.

Future files must conform to `../EVIDENCE_SCHEMA.json`, identify the immutable
source commit/tree, redact the account login with a stable hash, contain no
credentials, and preserve lossless raw callback/query observations. A timeout,
callback absence, zero row count, or synchronous retcode must never be exported
as authoritative proof of no side effect.

Post-materialization evidence must record `SWV5_RUNTIME_STRATEGY_MAGIC`, its
canonical SSOT path, and per-row Magic classification. Magic match alone is not
correlation authority. Existing evidence files remain immutable observations.
