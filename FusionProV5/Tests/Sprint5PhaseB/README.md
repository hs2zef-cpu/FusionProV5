# Sprint 5 Phase B.3 verification

Status: **TEST ONLY — NOT FOR PRODUCTION — NO BROKER ACCESS**

The package has three distinct evidence layers:

1. `SW_V5_S5_PHASE_B_COMPILE.mq5`: umbrella compile probe.
2. `SW_V5_S5_PHASE_B_ASSERTIONS.mq5`: compile-only MQL source with 183 assertion function invocations on 181 source call lines and 184 textual occurrences including the declaration. It is not executed in Phase B.3.
3. `verify_phase_b.ps1`: independent deterministic PowerShell/.NET reference oracle with 139 executable assertions. It does not execute MQL.

Run the permitted oracle from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File FusionProV5/Tests/Sprint5PhaseB/verify_phase_b.ps1
git diff --check
```

MetaEditor X64 Regular may compile both manifests. Do not launch MT5 Terminal or Strategy Tester. No broker, physical store, event loop, callback, or runtime coordinator is included.
