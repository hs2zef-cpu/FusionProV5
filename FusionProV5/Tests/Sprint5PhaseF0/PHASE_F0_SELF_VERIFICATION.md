# Sprint 5 Phase F0 Self-Verification

TEST ONLY / F0 / NOT FOR PRODUCTION.

## Evidence classification

- Offline Python negative controls: executable deterministic model evidence.
- MQL compile: compile evidence only.
- Static/source scan: source and isolation evidence only.
- MQL runtime: **EXECUTED FOR READ-ONLY QUERY, DEFAULT-DISARMED PROFILE, AND ONE ARMED API INVOCATION**.
- Strategy Tester: **NOT EXECUTED**.
- Attended Demo: **ONE BUILD-6180 API INVOCATION; CLIENT-LOCAL REJECTION**.
- Broker/server observation: **NO BROKER ACKNOWLEDGEMENT OR BROKER SIDE EFFECT PROVEN**.

## Current results

The package provides a default-disarmed, single-market-send measurement probe,
an independent read-only active/history query probe,
R0–R5 candidate classification, query/completeness and negative-evidence
contracts, correlation candidate matrix, Tester/Demo classification, 19 offline
mutation controls, and explicit evidence schema.

The fresh post-materialization build-6180 Demo/HEDGING pre-send environment is
profiled from accepted source `dc7b5e2...`. One read-only query retained
`UNPROVEN` completeness, runtime Magic matched the sole SSOT, installed binaries
matched the fresh compile, and the environment probe remained default-disarmed
through `F0_DEINIT|reason=1|send_attempted=0`. No broker-visible pre-send
carrier, complete query profile, broker visibility watermark, callback/retcode
profile, or authoritative no-side-effect rule has been proven. These are not
converted into timeout or callback-absence claims.

Phase F implementation is NOT AUTHORIZED. Phase F0 is not closed by this
self-verification document.

## Executed offline/compiler gates

- F0 deliberate mutants: **19/19 PASS**, 0 failed, two deterministic runs;
  digest `8605dd2aa8b054d71f8e9e4b49b91639cf8ca0a4ef3fdc7cd80e1e2c356b101`.
- F0 source/isolation scan: **PASS**; one `OrderSend` occurrence exists only in
  the isolated default-disarmed Demo probe; production reverse dependencies 0;
  forbidden scope paths 0.
- Evidence-contract manifest: MetaEditor X64 Regular, **0 errors / 0 warnings**.
- Default-disarmed Demo profile probe: MetaEditor 6180 X64 Regular,
  **0 errors / 0 warnings**.
- Read-only query probe: MetaEditor 6180 X64 Regular,
  **0 errors / 0 warnings**.
- Phase B regression: **139/139 PASS**.
- Phase C regression: **22/22 PASS**.
- Phase D regression: **318/318 PASS**.
- Phase E ordinary oracle: **52/52 PASS**.
- Phase E mutation controls: **8/8 PASS**.
- `git diff --check`: **PASS** at the pre-commit gate.

Empirical result: **CLIENT-LOCAL REJECTION; ONE-SEND BUDGET CONSUMED.** The
operator-authorized BUY attempt invoked `OrderSend` once and returned
`last_error=4752` / `retcode=10027` with no request ID, order, deal, or callback.
The EA was removed with `send_attempted=1`; no retry occurred. The post-attempt
query reported zero rows but remained `UNPROVEN`.

No durable correlation carrier, authoritative no-side-effect rule, broker
retcode profile, visibility watermark, or reconnect behavior was proven. The
run also exposed a missing terminal/MQL/account trading-permission preflight.
Phase F0 is blocked pending Fusion review; Phase F remains unauthorized.
