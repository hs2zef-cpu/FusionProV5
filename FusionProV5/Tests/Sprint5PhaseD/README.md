# Sprint 5 Phase D Reference Verification

**TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS**

This package verifies the authorized Phase D persistence/restart design using an in-memory fake transactional store, an explicitly supplied fake authoritative clock/query source, compile-only MQL reference code, and an independent deterministic Python verifier.

It does not execute MQL assertions and does not prove MQL runtime behavior, real SQLite/database behavior, filesystem durability, cross-terminal locking, real platform-clock provenance, broker behavior, or production readiness. MT5 Terminal and Strategy Tester are not used.

The reference enforces independent Genesis, Lease, Ledger, Sequence, Submission/Claim, Pending Request Set, and Checkpoint transaction domains. Genesis accepts only typed bootstrap DTOs, binds every domain to the immutable Genesis ID/manifest/namespace/fence, and validates complete readback before readiness. Each durable transition validates the complete typed authority and derives its domain-canonical row before CAS. Complete Permit/Risk/normalization authority is bound at Claim; Takeover binds a complete Persistence Namespace and typed reconciliation; Request Set and row digests remain distinct; Request Set is authoritatively reloaded before checkpoint publication; Sequence and Ledger reconstruct complete durable state; Restart validates complete Broker/Execution summaries and every persisted request. An uncertain committed Claim never recreates event-local `CLAIM_GRANTED_NOW` authority.

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

- MQL direct positive assertion functions: **10**
- MQL direct negative assertion functions: **86**
- Re-sealed semantic negative assertion functions: **28**
- Non-proving assertion functions used as closure evidence: **0**
- MQL direct negative assertions: **YES**
- MQL assertions compiled: **YES**
- MQL assertions executed: **NO**
- Python executable scenarios: **209** unique IDs per run, repeated twice internally
