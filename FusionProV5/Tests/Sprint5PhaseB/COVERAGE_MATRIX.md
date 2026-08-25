# Sprint 5 Phase B.3 contract coverage matrix

| Authority | Corrected candidate boundary | Direct MQL source assertions | Independent executable model | Deferred |
|---|---|---|---|---|
| Trusted ingress | Structural ingress plus current anchored Trust; exact successor scope | trusted/untrusted acceptance; six re-digested successor scope mutations | exact-scope successor and mutation cases | adapter/Trust store |
| Ledger | ordinary authority evaluation requires complete record/index linkage | orphan/corrupt/revision/sequence/accepted-at invalid; duplicate/conflict/new/denied controls; compaction | complete linked authority, orphan, corruption, replay/HWM cases | physical CAS ledger |
| Request sequence | unique correlation/sequence index and exact HWM | duplicate sequence, HWM, corrupt authority | SEQ cases | linearizable allocator |
| Initial request | exact ingress action/direction, normalized payload, Risk | reversal/no-entry/Risk/payload | BLP cases | runtime materialization |
| Submission Permit | current Trust and typed nested authorities | current Trust preparation/conflict | PER cases | physical permit commit |
| Admission Proof | semantic V1/V2, exact `SUBMISSION_PENDING`/Submission request lifecycle, stability, relations, claim-time validity | valid control; confirmed/rejected/expired/created/invalid-phase/invalid-enum denial | lifecycle-aware ADM cases | authority collectors |
| Invocation Claim | complete proof required; pure transition only; takeover-first is stale owner | valid/corrupt/stale/expired/terminal-request; direct conditional completion | CLM cases | atomic claim store |
| Durable Claim | full compared snapshot and Claim digest domain | retained recomputation/mutation | domain separation | restart implementation |
| Publication | complete request set/checkpoint projections | expected-current/checkpoint mutation | PUB/CHK cases | physical publication |

Production Contract V5 and approved architecture ADR semantics are unchanged. MQL assertions are compile-only; PowerShell assertions execute independently.
