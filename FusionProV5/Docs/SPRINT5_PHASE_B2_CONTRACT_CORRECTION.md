# Sprint 5 Phase B.2 — Final Contract Conformance Closure

Status: **CORRECTIVE CANDIDATE / READY FOR NEW INDEPENDENT CONTRACT RE-AUDIT AFTER SELF-VERIFICATION**

The independent Phase B.1 re-audit returned `FAIL`: 2 Critical, 6 Major, 0 Minor. Phase B.2 corrects those candidate implementation defects only. Architecture Review remains `CLOSED`; Phase C, runtime, broker, physical persistence, MT5 Terminal/Tester, Architecture Lock, and merge to main remain unauthorized.

## B.1 finding closure

| Finding | Candidate correction | Direct evidence |
|---|---|---|
| CRITICAL: Claim accepted recomputable but semantically invalid snapshot | One `SWV5S5_AdmissionProof` validates V1, V2, stable owner evidence, safety equality, cross-domain relationships, pre-P policy, and claim-time authority before Claim preparation | Admission/Claim assertions; ADM oracle |
| CRITICAL: request materialization not transitive to ingress | Blueprint validator receives exact ingress, normalized Unit output, normalization identity, and Risk authorization; recomputes ingress identity/digest and enforces action/direction/OPEN | Blueprint assertions; BLP oracle |
| MAJOR: incomplete durable Claim record/wrong domain | Claimed record retains complete compared Admission Snapshot; durable claimed digest uses Invocation Claim domain | retained-snapshot assertions; domain-use scan |
| MAJOR: incomplete Trust continuity/integration/currentness | successor verifies both digests and anchor; combined trusted-ingress boundary; Permit preparation receives independent current Trust | Trust assertions; TRU oracle |
| MAJOR: Ledger/Sequence integrity | accepted-at is indexed; complete record/index linkage and compaction; unique Sequence index and HWM validation | Ledger/Sequence assertions and oracle |
| MAJOR: checkpoint incomplete projection | full actual V5 checkpoint header, Basket, request evidence, correlation, Hard Kill/release evidence, reconciliation vector, and clean-shutdown state are canonicalized | checkpoint mutation assertions; CHK oracle |
| MAJOR: verification overclaim | documentation separates compile-only MQL call sites, executed independent model, and static scans | inventory and README |
| MAJOR: normalized payload ABA | content digest is separate from Unit authority ID/revision/digest and specification sequence | Admission assertion; ADM-006 |

## Dependency refactor

`SW_V5_S5_SubmissionRecordContract.mqh` owns the durable Submission Authority record and includes the complete Admission Snapshot after the Permit value type is defined. This breaks the former include cycle without duplicate DTOs or incomplete members. Permit preparation remains in the durable-record layer; the Permit value remains lower-level.

No Production Contract V5 header or approved architecture ADR semantic text changes in Phase B.2.
