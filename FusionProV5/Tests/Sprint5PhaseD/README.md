# Sprint 5 Phase D Reference Verification

**TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS**

This package verifies the authorized Phase D persistence/restart design using an in-memory fake transactional store, an explicitly supplied fake authoritative clock/query source, compile-only MQL reference code, and an independent deterministic Python verifier.

It does not execute MQL assertions and does not prove MQL runtime behavior, real SQLite/database behavior, filesystem durability, cross-terminal locking, real platform-clock provenance, broker behavior, or production readiness. MT5 Terminal and Strategy Tester are not used.

The reference enforces independent Genesis, Lease, Ledger, Sequence, Submission/Claim, Pending Request Set, and Checkpoint transaction domains. Every durable transition carries a complete typed DTO envelope, namespace/fence binding, and recomputed canonical payload digest. Request-set publication must be authoritatively reloaded before checkpoint publication. An uncertain committed Claim never recreates event-local `CLAIM_GRANTED_NOW` authority.

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
