# Sprint 5 Phase B.1 — Breaking Candidate-Contract Change Report

Phase B.1 is a breaking correction to the unapproved Sprint 5 candidate package. The candidate schema advances from 1 to 2 and minimum-compatible version from 1 to 2. No audited Production Contract V5 type or interface changes.

Breaking changes include:

- generic stable tokens replaced by typed authority views;
- generic publication proposal replaced by request-set/checkpoint proposals;
- replayable Claim evaluator replaced by pure transition preparation plus abstract authoritative `TryClaimInvocation`;
- Claim result now returns the complete durable Submission Authority record;
- Permit, Trust anchor/scope, Ledger, Sequence, Request Binding, Admission Snapshot, and Orchestration signatures expanded or replaced;
- pure dispositions distinguish proposal eligibility from authoritative commit/grant outcomes.

There is no runtime migration because the Sprint 5 package is Candidate / In Review, has no authorized runtime/store implementation, and has not been merged to main. Any consumer of the original Phase B candidate must recompile against the Phase B.1 schema and pass a new independent contract re-audit.
