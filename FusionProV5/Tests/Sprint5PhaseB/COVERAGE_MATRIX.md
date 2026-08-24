# Sprint 5 Phase B.2 contract coverage matrix

| Authority | Corrected candidate boundary | Direct MQL source assertions | Independent executable model | Deferred |
|---|---|---|---|---|
| Trusted ingress | Structural ingress plus current anchored Trust is mandatory | trusted/untrusted acceptance | Trust successor/binding | adapter/Trust store |
| Ledger | accepted-at and complete record/index linkage | linkage, compaction, accepted-at mutation | LED cases | physical CAS ledger |
| Request sequence | unique correlation/sequence index and exact HWM | duplicate sequence, HWM, corrupt authority | SEQ cases | linearizable allocator |
| Initial request | exact ingress action/direction, normalized payload, Risk | reversal/no-entry/Risk/payload | BLP cases | runtime materialization |
| Submission Permit | current Trust and typed nested authorities | current Trust preparation/conflict | PER cases | physical permit commit |
| Admission Proof | semantic V1/V2, stability, relations, claim-time validity | valid proof and authority mutations | ADM cases | authority collectors |
| Invocation Claim | complete proof required; pure transition only | valid/corrupt/stale/expired | CLM cases | atomic claim store |
| Durable Claim | full compared snapshot and Claim digest domain | retained recomputation/mutation | domain separation | restart implementation |
| Publication | complete request set/checkpoint projections | expected-current/checkpoint mutation | PUB/CHK cases | physical publication |

Production Contract V5 and approved architecture ADR semantics are unchanged. MQL assertions are compile-only; PowerShell assertions execute independently.
