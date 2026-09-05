# Sprint 5 Phase F0 Self-Verification

TEST ONLY / F0 / NOT FOR PRODUCTION.

## Evidence classification

- Offline Python negative controls: executable deterministic model evidence.
- MQL compile: compile evidence only.
- Static/source scan: source and isolation evidence only.
- MQL runtime: **EXECUTED FOR READ-ONLY QUERY AND DEFAULT-DISARMED PROFILE ONLY**.
- Strategy Tester: **NOT EXECUTED**.
- Attended Demo: **EXECUTED FOR BUILD-6180 PRE-SEND OBSERVATION ONLY**.
- Broker/server observation: **ENVIRONMENT AND READ-ONLY QUERY ONLY; NO BROKER CALL**.

## Current results

The package provides a default-disarmed, single-market-send measurement probe,
an independent read-only active/history query probe,
R0–R5 candidate classification, query/completeness and negative-evidence
contracts, correlation candidate matrix, Tester/Demo classification, 19 offline
mutation controls, and explicit evidence schema.

The build-6180 Demo/HEDGING pre-send environment is now profiled. Two read-only
queries 41 seconds apart retained `UNPROVEN` completeness, and the environment
probe remained default-disarmed. No broker-visible pre-send carrier, complete
query profile, broker visibility watermark, callback/retcode profile, or
authoritative no-side-effect rule has been proven. These are not converted into
timeout or callback-absence claims.

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

Runtime-Magic materialization result: **PASS FOR SOURCE/COMPILE/OFFLINE GATES;
NO BROKER CALL.** `SWV5_RUNTIME_STRATEGY_MAGIC=1179670069` is defined only in
`Configuration/SW_V5_RuntimeIdentityProfile.mqh`; the Demo probe has no Magic
input, and NC-16 through NC-19 fail closed. The prior lifecycle ended with
`F0_DEINIT|reason=1|send_attempted=0` and remains historical evidence.

No final send confirmation may be requested from this source-only gate. The new
probe binaries require a fresh build-6180 read-only/default-disarmed attended
observation, followed by separate explicit confirmation. Phase F0 remains open;
Phase F remains unauthorized.
