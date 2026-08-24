# Sprint 5 Phase B.2 verification

Status: **TEST ONLY — NOT FOR PRODUCTION — NO BROKER ACCESS**

The package has three distinct evidence layers:

1. `SW_V5_S5_PHASE_B_COMPILE.mq5`: umbrella compile probe.
2. `SW_V5_S5_PHASE_B_ASSERTIONS.mq5`: compile-only MQL source with 148 assertion call sites. It is not executed in Phase B.2.
3. `verify_phase_b.ps1`: independent deterministic PowerShell/.NET reference oracle with 122 executable assertions. It does not execute MQL.

Run the permitted oracle from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File FusionProV5/Tests/Sprint5PhaseB/verify_phase_b.ps1
git diff --check
```

MetaEditor X64 Regular may compile both manifests. Do not launch MT5 Terminal or Strategy Tester. No broker, physical store, event loop, callback, or runtime coordinator is included.
