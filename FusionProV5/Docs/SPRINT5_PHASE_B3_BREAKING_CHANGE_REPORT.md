# Sprint 5 Phase B.3 — Candidate Breaking-Change Report

Status: **PHASE B CANDIDATE CONTRACT ONLY / NO RUNTIME AUTHORIZATION**

`SWV5S5_EvaluateLedgerIngress(...)` now requires the complete authoritative `SWV5S5_IngressLedgerRecord[]` alongside the header and membership index. This intentionally breaks index-only callers so no normal authority evaluator can emit `NEW`, `DUPLICATE`, `CONFLICT`, or `DENIED` without proving complete record integrity and record/index linkage.

Admission Proof validation is semantically stricter without a signature change: the exact request member must be `SWV5_REQUEST_SUBMISSION_PENDING` in `SWV5_EXECUTION_PHASE_SUBMISSION`.

Producer Trust successor validation is semantically stricter without a signature change: all immutable issuer and producer scope fields must remain exact.

Claim preparation is semantically clarified without a signature change: a takeover/current-fence mismatch returns `SWV5S5_CLAIM_STALE_OWNER`; same-owner proof-content or liveness mismatch remains fail-closed under its existing validation path.

There is no Production Contract V5, ADR, runtime, broker, or physical-store change.
