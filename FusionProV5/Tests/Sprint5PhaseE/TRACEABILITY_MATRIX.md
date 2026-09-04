# Sprint 5 Phase E Traceability Matrix

TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

| Fixture-contract invariant | Named scenario coverage |
|---|---|
| Total ingress-to-checkpoint identity chain | E-HAPPY-BUY, E-HAPPY-SELL |
| Direction unchanged | E-HAPPY-BUY, E-HAPPY-SELL |
| WAIT/BLOCKED grant no increasing authority | E-WAIT, E-BLOCKED |
| Dumb broker counts every presented invocation | E-HAPPY-BUY, E-CONTROL-BROKER-SILENT-DEDUPE |
| Exactly once comes from owner authority, not broker | duplicate ingress M1; duplicate event M2; duplicate submission M3; duplicate Claim M6; prior-result replay P10; restart after Claim N5; takeover after Claim O3; stale-owner replay O4 |
| No reconstructed event-local Claim grant | E-RESTART-N5, E-SEMANTIC-P10-NO-RECONSTRUCTED-GRANT |
| Crash-prefix durability and no blind retry | E-CRASH-M1 through E-CRASH-M9 |
| One injected clock; historical time not current authority | E-RESTART-N7, E-SEMANTIC-P3-STALE-BROKER |
| Risk valid strictly before expiry | E-ADR020-RISK-EXPIRES-AT-CLAIM, E-SEMANTIC-P8-RISK-EXPIRY-EQUALITY |
| Frozen ADR-020 P/Hard Kill ordering | E-ADR020-HK-BEFORE-P, E-ADR020-HK-AFTER-P |
| Frozen ADR-020 P/Trust ordering | E-ADR020-TRUST-BEFORE-P, E-ADR020-TRUST-AFTER-P |
| Claim-time ownership remains mandatory | E-ADR020-TAKEOVER-BEFORE-CLAIM, E-TAKEOVER-O1/O2 |
| Claim before takeover remains claimed uncertainty | E-ADR020-CLAIM-BEFORE-TAKEOVER, E-TAKEOVER-O3 |
| Claim fence and durable fenced CAS both load-bearing | E-TAKEOVER-O4/O5, E-CONTROL-NO-CLAIM-FENCE, E-CONTROL-STALE-CAS-EQUALITY |
| Stale identical content fails on epoch | E-TAKEOVER-O4, E-SEMANTIC-P7-RESEALED-STALE-EPOCH |
| Publication commits only after CAS/readback | E-RESTART-N6/N13, E-TAKEOVER-O6 |
| Ordinary ACQUIRED/RENEWED restart | E-RESTART-N1, E-RESTART-N2 |
| Zero-history ACQUIRED/RENEWED restart | E-RESTART-N3, E-RESTART-N4 |
| Active/invalid/released Hard Kill restart | E-RESTART-N10/N11/N12 |
| Four-way valid-sealed incoherence fails existing path | E-SEMANTIC-P11-FOUR-WAY-INCOHERENCE |
| Digest/type domains remain distinct | E-SEMANTIC-P5-CROSS-TYPE-DOMAIN |
| Cross-object semantic reseal cannot conceal mismatch | E-SEMANTIC-P1 through P11 |
| Scheduler is non-authoritative; result invariant | E-SCHEDULER-NORMAL, E-SCHEDULER-DUAL_OWNER |
| Harness detects missing Claim fence, stale CAS and broker dedupe | E-CONTROL-* |
| No mirror expected-state engine | all scenario objects declare literal expected fields |
| No new durable intent authority | E-HAPPY-BUY and Claim/crash/restart matrices retain only INVOCATION_CLAIMED_UNRESOLVED |
