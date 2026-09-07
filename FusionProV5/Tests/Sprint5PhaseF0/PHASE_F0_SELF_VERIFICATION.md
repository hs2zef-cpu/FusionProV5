# Sprint 5 Phase F0 Self-Verification

TEST ONLY / F0 / NOT FOR PRODUCTION.

## Evidence classification

- Offline Python negative controls: executable deterministic model evidence.
- MQL compile: compile evidence only.
- Static/source scan: source and isolation evidence only.
- MQL runtime: **EXECUTED FOR READ-ONLY QUERY, DEFAULT-DISARMED PROFILE, ONE HISTORICAL CLIENT-LOCAL REJECTION, AND ONE CORRECTED SUCCESSFUL BUY**.
- Strategy Tester: **NOT EXECUTED**.
- Attended Demo: **ONE HISTORICAL CLIENT-LOCAL REJECTION AND ONE CORRECTED SUCCESSFUL BUILD-6180 BUY; SEPARATE MANUAL CLEANUP COMPLETE**.
- Broker/server observation: **ONE MARKET BUY/FILL AND LINKED MANUAL EXIT POSITIVELY OBSERVED; GENERAL PROFILE NOT PROVEN**.

## Current results

The package provides a default-disarmed, single-market-send measurement probe,
an independent read-only active/history query probe,
R0–R5 candidate classification, query/completeness and negative-evidence
contracts, correlation candidate matrix, Tester/Demo classification, 24 offline
mutation controls, and explicit evidence schema.

The fresh post-materialization build-6180 Demo/HEDGING pre-send environment is
profiled from accepted source `dc7b5e2...`. One read-only query retained
`UNPROVEN` completeness, runtime Magic matched the sole SSOT, installed binaries
matched the fresh compile, and the environment probe remained default-disarmed
through `F0_DEINIT|reason=1|send_attempted=0`. No broker-visible pre-send
carrier, complete query profile, broker visibility watermark, callback/retcode
profile, or authoritative no-side-effect rule has been proven. These are not
converted into timeout or callback-absence claims.

The corrected attended run used source `e5411a5...`, observed all four trading
permissions true, invoked `OrderSend` exactly once, and positively reconstructed
the resulting BUY across position, history order, and history deal. A separate
manual Magic-zero cleanup closed the full observed volume and is not strategy
identity or a second strategy entry. Every query remains `UNPROVEN` for
completeness.

Phase F implementation is NOT AUTHORIZED. Phase F0 is not closed by this
self-verification document.

## Executed offline/compiler gates

- F0 deliberate mutants: **24/24 PASS**, 0 failed, two deterministic runs;
  digest `7a0cd0816d66f86dd73283c4e44f734922b5fbdbb22d30ebfe9fa06b4f44f8f5`;
  including four permission failures and one same-run permission-change mutant.
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
At that historical boundary Phase F0 was blocked pending Fusion review; Phase F
remained unauthorized.

That client-local rejection remains immutable historical evidence and is not
rewritten by the later run.

Corrected empirical result: **ONE STRATEGY BUY CONFIRMED; SEPARATE MANUAL
CLEANUP COMPLETE.** All permission properties were true before the call. Sync
retcode `10009` was not treated as confirmation by itself; the later query
observed position/order `5055862979` and deal `4360221913`. Manual cleanup order
`5055880854` and exit deal `4360237506` linked to the same position and closed
the full `0.01` observed volume. No retry, second strategy entry, pending order,
automatic close, or reconnect occurred. No further `OrderSend` is authorized.

General broker behavior, a durable authoritative correlation carrier,
authoritative negative-evidence rules, a visibility watermark, and reconnect
behavior remain unproven.
