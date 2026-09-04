# Sprint 5 Phase F0 Self-Verification

TEST ONLY / F0 / NOT FOR PRODUCTION.

## Evidence classification

- Offline Python negative controls: executable deterministic model evidence.
- MQL compile: compile evidence only.
- Static/source scan: source and isolation evidence only.
- MQL runtime: **NOT EXECUTED**.
- Strategy Tester: **NOT EXECUTED**.
- Attended Demo: **NOT EXECUTED**.
- Broker/server observation: **NONE**.

## Current results

The package provides a default-disarmed, single-market-send measurement probe,
an independent read-only active/history query probe,
R0–R5 candidate classification, query/completeness and negative-evidence
contracts, correlation candidate matrix, Tester/Demo classification, 15 offline
mutation controls, and explicit evidence schema.

Empirical Phase-F0 gates remain blocked because no current Demo/HEDGING
environment was available. No broker-visible pre-send carrier, complete query
profile, clock/watermark profile, or authoritative no-side-effect rule has been
proven. These are not converted into timeout or callback-absence claims.

Phase F implementation is NOT AUTHORIZED. Phase F0 is not closed by this
self-verification document.

## Executed offline/compiler gates

- F0 deliberate mutants: **15/15 PASS**, 0 failed, two deterministic runs;
  digest `bfd4f55b417a738aa66db9b255454b4fa0dca34c1d62e14fc944013ed9bcb412`.
- F0 source/isolation scan: **PASS**; one `OrderSend` occurrence exists only in
  the isolated default-disarmed Demo probe; production reverse dependencies 0;
  forbidden scope paths 0.
- Evidence-contract manifest: MetaEditor X64 Regular, **0 errors / 0 warnings**.
- Default-disarmed Demo profile probe: MetaEditor X64 Regular,
  **0 errors / 0 warnings**.
- Read-only query probe: MetaEditor X64 Regular, **0 errors / 0 warnings**.
- Phase B regression: **139/139 PASS**.
- Phase C regression: **22/22 PASS**.
- Phase D regression: **318/318 PASS**.
- Phase E ordinary oracle: **52/52 PASS**.
- Phase E mutation controls: **8/8 PASS**.
- `git diff --check`: **PASS** at the pre-commit gate.

Engineering gate result: **PHASE F0 BLOCKED — FUSION DECISION REQUIRED** until
attended Demo/HEDGING measurement proves correlation, query completeness,
clock/watermark behavior, and a safe negative-evidence rule.
