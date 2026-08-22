# Sprint 5 Phase B verification

Status: **TEST ONLY — NOT FOR PRODUCTION — NO BROKER ACCESS**

This package verifies the compile shape and deterministic source invariants of the Sprint 5 Phase B pure contracts. It does not run MetaTrader Terminal or Strategy Tester. The `.mq5` file is an empty-entrypoint MetaEditor compile probe only.

Run the platform-independent gates from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File FusionProV5/Tests/Sprint5PhaseB/verify_phase_b.ps1
git diff --check
```

The verifier checks the contract inventory, forbidden API tokens, dependency direction, include cycles, required domain identities, independent .NET SHA-256 vectors, and test-inventory coverage. MetaEditor compilation is a separate compiler-only gate.

No physical store, CAS engine, broker adapter, event loop, callback, or runtime coordinator is supplied here.
