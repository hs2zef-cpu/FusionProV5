# Sprint 5 Phase D Reference Verification

**TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS**

This package verifies the authorized Phase D persistence/restart design using an in-memory fake transactional store, an explicitly supplied fake authoritative clock/query source, compile-only MQL reference code, and an independent deterministic Python verifier.

It does not execute MQL assertions and does not prove MQL runtime behavior, real SQLite/database behavior, filesystem durability, cross-terminal locking, real platform-clock provenance, broker behavior, or production readiness. MT5 Terminal and Strategy Tester are not used.

The reference enforces independent Genesis, Lease, Ledger, Sequence, Submission/Claim, Pending Request Set, and Checkpoint transaction domains. D.4 completes the independently identified ownership-key/Lease-clock, live-Lease/Basket/vector, Hard-Kill release and RENEWED zero-history gaps; D.3 self-verification did not independently close those gaps. Prior version/time binding, canonical digests and post-readback publication behavior are preserved. Request Set and row digests remain distinct, every persisted request is scanned, and an uncertain commit never recreates event-local authority.

Run the offline verifier twice-internally:

```powershell
python FusionProV5/Tests/Sprint5PhaseD/verify_phase_d_reference.py
```

Run the static isolation scan:

```powershell
powershell -NoProfile -File FusionProV5/Tests/Sprint5PhaseD/verify_phase_d_static.ps1
```

The MQL manifests are compiler-only probes:

- `SW_V5_S5_PHASE_D_COMPILE.mq5`
- `SW_V5_S5_PHASE_D_ASSERTIONS.mq5`

MQL assertions executed: **NO**.

Evidence classification for this hardening revision:

- MQL direct positive assertion functions: **17**
- MQL direct negative assertion functions: **157**
- Independent D.2 audit baseline: **19** complete re-sealed semantic probes and **34** non-creditable legacy probes
- D.4 headline closure uses direct typed/re-sealed probes; compile-only presence is not reported as executed proof
- MQL direct negative assertions: **YES**
- MQL assertions compiled: **YES**
- MQL assertions executed: **NO**
- Python executable scenarios: **294** unique IDs per run, repeated twice internally

D.3 independent final re-audit: **FAIL — Critical 3 / Major 3 / Minor 0**. D.4 self-verification is not independent closure. Phase E remains **NOT AUTHORIZED** pending independent D.4 PASS.

D.4 adds complete governed ownership-key validation, current-Lease clock/expiry binding, a common live ACQUIRED/RENEWED restart gate, frozen Basket/vector/Hard-Kill intrinsic predicates, full Broker identity/HWM relations, exact release policy/account/exposure/chronology, and RENEWED zero-history controls. The explicit frozen-validator dependency is reference-only, not a production dependency. See `D4_SEMANTIC_EVIDENCE.md` for the 26 re-sealed / 12 direct typed-status paths and the observed-expired-row test setup correction. The 34 legacy non-proving probes are not D.4 closure evidence.
