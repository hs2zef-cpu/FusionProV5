# Sprint 5 Phase C coverage matrix

| Requirement | Production boundary | MQL compile assertion | Executable reference scenario |
|---|---|---|---|
| Same-event Claim gate | `ProcessAdmission` authoritative-grant predicate | Success and duplicate controls | C-01, C-06, C-07 |
| Exact request lifecycle | Submission Pending + Submission checks | Stable-terminal denial | C-01, C-06 |
| No reusable provisional P | Before-Claim interruption returns recollect | Claim call count remains zero | C-10 |
| Claimed uncertainty | Claimed record without grant emits reconciliation | Duplicate and after-Claim controls | C-07, C-11, C-12 |
| Takeover ordering | Phase B Claim disposition is consumed | Stale-owner denial | C-08, C-09 |
| Ingress authority | Frozen trusted-ingress validator and binding function | Invalid no-entry direction controls | C-02–C-05 |
| Hard Kill / Trust overlap | Complete owner result is consumed; no post-P re-read | Interface path compiles | C-13, C-14 |
| Risk exclusive expiry | Phase B Claim result is consumed | Denied result cannot call broker | C-15 |
| Queue non-authority | Test-only FIFO stores only event identity/order/scenario | FIFO assertions | All scenarios |
| Deterministic trace | Immutable diagnostic entry emitted at each step | Trace population assertions | Two identical full runs |
| Broker isolation | Fake-only abstract port; no platform APIs | Invocation record assertions | C-01, C-06–C-12 |

This matrix demonstrates Phase C orchestration semantics only. It does not prove physical persistence, linearizability, real broker behavior, MQL runtime behavior, or production readiness.
