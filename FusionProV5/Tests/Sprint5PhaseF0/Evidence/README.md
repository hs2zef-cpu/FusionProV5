# Phase F0 Raw Evidence Directory

Measured evidence inventory:

- `F0-6182-POSITIVE-CONTROL-RECONNECT-001.json`: read-only build-6182
  positive-control evidence. Ten fixed window/filter/depth cases produced the
  expected inclusion, exclusion, enumeration, and explicit-error behavior both
  before and after an attended same-terminal reconnect/restart boundary. The
  unknown-position filter failed explicitly with `4753`. Ordinary queries
  reported 0 positions, 0 active orders, 2 history orders, and 2 history deals;
  all completeness remains `UNPROVEN`. Correlation is RUN-SCOPED /
  NON-AUTHORITATIVE with cardinality-1 confounding. No broker mutation or
  `OrderSend` occurred.
- `F0-6180-SUCCESSFUL-BUY-CLEANUP-001.json`: attended Demo build-6180
  evidence from corrected source `e5411a5...`. Exactly one strategy BUY was
  submitted with runtime Magic `1179670069`, filled at `4413.493`, and
  positively reconstructed as position/order `5055862979` and deal
  `4360221913`. A separately authorized manual operator cleanup produced SELL
  order `5055880854` and exit deal `4360237506`, both linked to the same
  position. The post-cleanup query reported zero positions and active orders.
  All query domains remain `UNPROVEN`; the Magic-zero cleanup is operator
  activity, not strategy identity. No retry, second strategy entry, or
  reconnect occurred.
- `F0-6180-CLIENT-LOCAL-REJECT-001.json`: attended Demo build-6180 evidence
  from clean repository baseline `35186ca...`. One authorized BUY API invocation
  was rejected by the local client with error `4752` / retcode `10027` because
  AutoTrading was disabled. The one-send allowance was consumed; no retry,
  broker acknowledgement, callback, ticket, fill, or exposure was observed.
  The post-attempt zero-row query remains `UNPROVEN` and is not authoritative
  negative evidence.
- `F0-6180-POST-MAGIC-PRESEND-001.json`: fresh attended Demo build-6180
  post-materialization evidence from committed source `dc7b5e2...`; one
  read-only query followed by one default-disarmed environment/profile
  observation and explicit `F0_DEINIT|reason=1|send_attempted=0`. Runtime Magic
  matches the SSOT, installed EX5 hashes match the fresh compile, and no broker
  call or trade callback marker occurred.
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

Evidence produced from the corrective preflight source must additionally record
the `F0_PERMISSIONS` snapshot for `TERMINAL_TRADE_ALLOWED`,
`MQL_TRADE_ALLOWED`, `ACCOUNT_TRADE_ALLOWED`, and `ACCOUNT_TRADE_EXPERT`.
Historical evidence is never backfilled with those fields.
