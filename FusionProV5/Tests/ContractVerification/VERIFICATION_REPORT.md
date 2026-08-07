# Sprint 4.4 Semantic Contract Verification Report

> TEST ONLY - NOT FOR PRODUCTION - NO BROKER ACCESS

## Verdict

**PASS - READY FOR INDEPENDENT REVIEW**

Sprint 4 remains the authorized baseline. Sprint 4.1 remains Candidate / In Review. Sprint 4.4 closes audit findings but does not declare Architecture Lock, production readiness, or runtime authorization.

## Generated evidence

- Exported at UTC: `2026-08-07T13:17:40Z`
- Tested source commit: `d77de8caed416364388688b40a9e13ddcbcee542`
- Evidence exporter SHA-256: `4ca40c09b92a5d457b120d3e61afe9da98ccd7fdc6cc98696ad2811a26a2f0cd`
- Manifest SHA-256: `450206d0dde297d2ae583f923821a7e6f5228a19f3f1ba8ed9f6e740b326d136`
- Verification source digest: `ce404c8ce292b54cbf3773dde5f5f1b940e2c7e7958f2dc2a9ff11146c6560fe`
- Architecture compile: 0 errors, 0 warnings, X64 Regular
- Test compile: 0 errors, 0 warnings, X64 Regular
- Tests: 238 total, 238 passed, 0 failed, 0 skipped
- Deterministic signature: `6132791249901820115`
- Independent runs: 2; signatures and counts identical
- Terminal build: 6090
- Broker/server evidence: Exness-MT5Trial6 (Demo/Trial Strategy Tester)
- Account mode: HEDGING deterministic contract fixture

## Scope

- 238 executable cases, including 236 interface-behavior cases and 2 supporting pure equality cases.
- All 49 Basket state pairs execute through `ISWV5BasketStateMachineContract`.
- Restart reconstructs the complete persisted request set and derives readiness from canonical request state.
- Persistence digests bind every serialized request field, order, count, and record sequence.
- Risk authorization binds complete limits, projected values, account snapshot, Hard Kill namespace and generation.
- Recovery, execution, statistics, and ownership interfaces return and verify monotonic resulting state.
- No broker command, runtime implementation, live account mutation, file/network validator dependency, Signal Engine change, or frozen baseline change is present.
