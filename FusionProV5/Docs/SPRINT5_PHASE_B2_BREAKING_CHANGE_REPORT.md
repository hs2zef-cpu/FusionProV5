# Sprint 5 Phase B.2 — Breaking Candidate-Contract Change Report

Phase B.2 changes only the unapproved Sprint 5 candidate API. The candidate schema and minimum-compatible version advance from 2 to 3. Production Contract V5 is unchanged.

Breaking candidate changes:

- Claim commands carry a validated complete Admission Proof instead of a provisional snapshot alone.
- Claim preparation receives the V5 Risk validation interface.
- durable Submission Authority records retain the complete Admission Snapshot and moved to `SW_V5_S5_SubmissionRecordContract.mqh`.
- initial Blueprint validation requires exact accepted ingress, normalized payload/identity, and Risk authorization.
- Permit preparation requires independently current Trust anchor/scope/record and accepted ingress.
- Ledger compaction requires complete before/after record arrays and indexed accepted-at.
- Sequence authority validation enforces full-index uniqueness and exact HWM semantics.
- normalized payload/Permit views include Unit authority identity, revision, and digest.
- orchestration Admission evaluation returns the Admission Proof.

There is no runtime migration: Phase C is not authorized and no candidate contract is production-authorized.
