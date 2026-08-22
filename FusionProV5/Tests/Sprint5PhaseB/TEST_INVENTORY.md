# Sprint 5 Phase B.1 executable verification inventory

Status: **TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS**

The original “126 deterministic cases” was a documentation inventory and was not executed. It is not reported as an executed result. Phase B.1 replaces that claim with the following exact evidence classes.

## MQL assertion harness

`SW_V5_S5_PHASE_B_ASSERTIONS.mq5` invokes `SWV5S5_RunAllPhaseBAssertions()`, which calls every registered test group and retains the exact assertion/failure counters. The source contains **125 actual assertion calls** across nine registered groups:

| Registered group | Assertion calls | Material behavior |
|---|---:|---|
| `TestCanonicalAndIdentity` | 13 | SHA/canonical vectors and fixed independently generated request identities |
| `TestLedgerAndSequence` | 10 | below-HWM denial, explicit membership, compaction, allocator index, overflow/corruption |
| `TestADR020Ordering` | 6 | Hard Kill and Trust before-P/after-P/post-Claim/time ordering |
| `TestSnapshotSemantics` | 22 | typed completeness, mutation instability, ABA, distinct clocks, no manufactured Claim clock, scope/payload/permit failures |
| `TestProducerTrust` | 18 | current anchor, exact ingress scope, statuses, supersession continuity |
| `TestClaimBoundary` | 27 | pure preparation, full durable result, replay, ownership/takeover, snapshot/request/payload/permit, Risk/Trust expiry |
| `TestPermitIdentity` | 4 | stable Permit ID and same-ID/different-content conflict |
| `TestBlueprintAndPermitPreparation` | 12 | complete initial V5 state, fabricated broker/confirmation evidence rejection, and non-authoritative permit preparation |
| `TestFencedPublication` | 13 | request-set/checkpoint expected-current evidence and full-payload integrity |

MetaEditor X64 Regular compiles this harness. It is **not executed** in Phase B.1 because MT5 Terminal and Strategy Tester are outside the authorized boundary.

## Independent executable oracle

`verify_phase_b.ps1` executes **89 independent PowerShell/.NET assertions** covering canonical framing, standard SHA vectors, fixed preimages/hashes, Permit/Binding/Attempt/Idempotency identity, anti-replay/overflow/publication/Claim reference models, forbidden APIs, dependency direction, cycles, and five adversarial verifier self-tests.

This is a test oracle. It does not execute the MQL production/candidate implementation.
