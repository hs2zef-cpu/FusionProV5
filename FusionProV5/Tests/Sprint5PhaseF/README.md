# Sprint 5 Phase F Entry Contract Verification

Status: **CANDIDATE / IN REVIEW**. This directory is test-only, not for production, and has no broker access.

The compile manifest proves that the standalone Phase F reconciliation overlay is type-compatible with the frozen Sprint 5 contracts. `verify_phase_f_entry.py` is an independent table-driven oracle for the required state transitions and fail-closed cases. It neither imports MQL behavior nor claims MT5/broker validation.

Run:

```text
python verify_phase_f_entry.py
```

The current F0 profile remains insufficient for authoritative negative evidence because query completeness capability and a visibility watermark remain unproven. Phase F Broker Adapter implementation and execution are not authorized.
