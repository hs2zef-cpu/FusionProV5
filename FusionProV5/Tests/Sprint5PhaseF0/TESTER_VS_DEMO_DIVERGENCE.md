# Phase F0 Tester versus Demo Evidence Classification

TEST ONLY / F0 / NOT FOR PRODUCTION.

| Test class | Required evidence class |
|---|---|
| Pure retcode classification invariants | TESTER SUFFICIENT plus offline tests |
| DTO/evidence schema validation | TESTER SUFFICIENT |
| Deterministic duplicate/out-of-order callback handling model | TESTER SUFFICIENT; Demo observation also required |
| Real broker retcodes/external retcodes | DEMO REQUIRED |
| Network disconnect/transport ambiguity | DEMO REQUIRED |
| Reconnect behavior | DEMO REQUIRED |
| Broker comment rewrite/truncation | DEMO REQUIRED |
| Active/history query visibility and latency | DEMO REQUIRED |
| Callback pressure/order on target profile | BOTH REQUIRED where safely reproducible |
| Partial/delayed fill | BOTH REQUIRED or NOT REPRODUCIBLE / MANUAL EVIDENCE ONLY |
| Authoritative negative-side-effect proof | DEMO REQUIRED |
| Compile/interface/source isolation | neither runtime mode; compiler/static evidence |

Strategy Tester may never substitute for Demo on transport, reconnect, real
broker behavior, query visibility, or negative-side-effect proof. No Tester or
Demo execution occurred in this F0 preparation run.
