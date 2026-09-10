# Sprint 5 Phase F Entry Contract Verification

Status: **CANDIDATE / IN REVIEW**. This directory is test-only, not for production, and has no broker access.

The compile manifest proves that the standalone Phase F reconciliation overlay is type-compatible with the frozen Sprint 5 contracts. `verify_phase_f_entry.py` is an independent table-driven oracle for the required state transitions and fail-closed cases. `verify_phase_f_mutation_controls.py` uses deliberately broken test doubles; PASS requires both `unsafe_result_observed` and `target_assertion_detected`. Neither verifier imports MQL behavior or claims MT5/broker validation.

Run:

```text
python verify_phase_f_entry.py
python verify_phase_f_mutation_controls.py
python verify_phase_f_source.py
```

The current F0 profile remains insufficient for authoritative negative evidence because query completeness capability and a visibility watermark remain unproven. Phase F Broker Adapter implementation and execution are not authorized.
