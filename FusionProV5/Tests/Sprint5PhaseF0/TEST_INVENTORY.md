# Phase F0 Measurement and Future Phase-F Test Inventory

TEST ONLY / F0 / NOT FOR PRODUCTION.

| Test ID | Case | Classification | Current execution |
|---|---|---|---|
| F0-ENV-01 | Demo/HEDGING/environment attestation | F0 profile only / Demo required | PASS for build-6180 pre-send observation; no broker call |
| F0-CORR-01 | comment preservation across active/history domains | F0 profile only / Demo required | NOT RUN |
| F0-CORR-02 | request_id reuse across sessions | F0 profile only / Demo required | OFFLINE mutant only |
| F0-RET-01 | success acknowledgement, not confirmation | future Phase F Demo | OFFLINE invariant only |
| F0-RET-02 | explicit rejection | F0 profile only / Demo required | NOT RUN |
| F0-RET-03 | timeout/ambiguity and no retry | future Phase F Demo | OFFLINE mutant only |
| F0-SEND-01 | duplicate submission | future Phase F Tester + Demo | OFFLINE mutant only |
| F0-CLAIM-01 | persisted Claim replay | F0 executed offline | PASS via NC-01 |
| F0-CRASH-01 | crash before/during/after send | future Phase F Demo | BLOCKED pending profile |
| F0-CB-01 | duplicate callback | F0 executed offline + future Demo | PASS via NC-06 |
| F0-CB-02 | out-of-order callback | F0 executed offline + future Demo | PASS via NC-07 |
| F0-FILL-01 | partial/delayed fill | BOTH REQUIRED / maybe manual-only | NOT RUN |
| F0-CONN-01 | reconnect | DEMO REQUIRED | NOT RUN |
| F0-OWN-01 | lease loss/takeover/stale owner | future Phase F Tester + Demo | PASS offline NC-09 only |
| F0-QUERY-01 | incomplete/conflicting query | F0 executed offline + Demo required | PASS via NC-05/NC-13 |
| F0-EVID-01 | non-finite evidence | future Phase F Tester | NOT RUN |
| F0-SPEC-01 | stale symbol specification | F0 executed offline + Demo required | PASS via NC-11 |
| F0-UNIT-01 | unit mismatch | future Phase F Tester | NOT RUN |
| F0-MODE-01 | HEDGING enforcement / NETTING rejection | F0 executed offline + Demo attestation | PASS via NC-12 plus build-6180 Demo/HEDGING observation; NETTING not exercised on Demo |
| F0-MODE-02 | account-mode change | future Phase F Demo | NOT RUN |
| F0-NEG-01 | authoritative negative side-effect proof | DEMO REQUIRED | BLOCKED pending profile |
| F0-PEND-01 | pending-order rejection | F0 source/static | PASS; probe contains no pending action |
| F0-PRESS-01 | callback pressure | DEMO REQUIRED / operator-controlled | NOT RUN |
| F0-TESTER-01 | Tester substituted for Demo | F0 executed offline | PASS via NC-15 |
| F0-MAGIC-01 | Zero runtime Magic | F0 executed offline | PASS via NC-16 |
| F0-MAGIC-02 | Fixture/reference value used as runtime Magic | F0 executed offline | PASS via NC-17 |
| F0-MAGIC-03 | Conflicting Magic across governed domains | F0 executed offline | PASS via NC-18 |
| F0-MAGIC-04 | Mutable-per-request Magic | F0 executed offline | PASS via NC-19 |

F0 does not claim execution of future Phase-F tests. Pending orders remain out
of scope. Unknown or ambiguous outcomes remain no-retry unresolved evidence.
