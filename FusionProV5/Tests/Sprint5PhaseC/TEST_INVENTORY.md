# Sprint 5 Phase C test inventory

| ID | Scenario | Required result |
|---|---|---|
| C-01 | One directional event | BUY nominates BUY; one current-event Claim invokes once |
| C-02 | Duplicate ingress | Same deterministic logical request; no duplicate creation |
| C-03 | WAIT | No request and no fake-broker call |
| C-04 | BLOCKED | No request and no fake-broker call |
| C-05 | Two different requests | Stable distinct identities; BUY/SELL preserved |
| C-06 | Duplicate submission | One invocation; duplicate becomes reconciliation |
| C-07 | Claim winner then duplicate | Only winner receives current-event grant |
| C-08 | Takeover before Claim | Stale owner; no invocation |
| C-09 | Claim before takeover | One invocation; takeover observes quiescence/uncertainty |
| C-10 | Crash before Claim | Provisional P lost; later event recollects |
| C-11 | Crash after Claim before call | Zero call; claimed-unresolved requires reconciliation |
| C-12 | Uncertain followed by event | No grant reconstruction and no retry |
| C-13 | Hard Kill ordering | Before-P blocks; after-P overlap retained; later blocked |
| C-14 | Trust ordering | Before-P/expiry blocks; after-P overlap retained |
| C-15 | Risk expiry boundary | `<` eligible; `==` and `>` denied |

The MQL source contains 33 compile-only assertions covering the coordinator gate, duplicate behavior, both interruption boundaries, stale ownership, lifecycle denial, denied-ingress non-materialization, and FIFO queue ordering. `MQL ASSERTIONS EXECUTED = NO`.
