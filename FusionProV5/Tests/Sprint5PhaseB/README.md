# Sprint 5 Phase B.1 verification

Status: **TEST ONLY — NOT FOR PRODUCTION — NO BROKER ACCESS**

This package has three deliberately separate verification layers:

1. `SW_V5_S5_PHASE_B_COMPILE.mq5` is the umbrella compile probe.
2. `SW_V5_S5_PHASE_B_ASSERTIONS.mq5` is a compile-only MQL harness containing 125 actual assertion calls and one entrypoint that invokes every registered group. It is compiled, not executed.
3. `verify_phase_b.ps1` is an independently implemented PowerShell/.NET test oracle with 89 executable assertions. It does not execute MQL code and is not a substitute for future separately authorized runtime tests.

Run the platform-independent oracle from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File FusionProV5/Tests/Sprint5PhaseB/verify_phase_b.ps1
git diff --check
```

MetaEditor X64 Regular may compile the two `.mq5` manifests. Do not launch MT5 Terminal or Strategy Tester. No physical store, CAS engine, broker adapter, event loop, callback, or runtime coordinator is supplied.
