# Sprint 5 Phase C.2 coverage matrix

| Scenario | Direct MQL | Queue-dispatched MQL | Reference model |
|---|---:|---:|---:|
| BUY full path | YES | YES | YES |
| SELL full path | YES | YES | YES |
| Duplicate ingress / no second reservation | YES | YES | YES |
| WAIT / no request | YES | YES | YES |
| BLOCKED / no request | YES | YES | YES |
| Two distinct requests | NO | YES | YES |
| Request progression | YES | YES | YES |
| Malformed Ledger authority | YES | NO | YES |
| Malformed Sequence authority | YES | NO | YES |
| BUY→SELL and SELL→BUY reversal | YES | YES | YES |
| Duplicate admission | YES | YES | YES |
| Takeover before Claim | YES | YES | YES |
| Claim before takeover | YES | YES | YES |
| Crash before Claim / recollect | YES | YES | YES |
| Crash after Claim | YES | YES | YES |
| Claimed-unresolved reconciliation follow-up | YES | YES | YES |
| Claim corruption family | YES | NO | YES |
| Prior-event grant replay | YES | NO | YES |
| Hard Kill before P | YES | NO | YES |
| Producer Trust invalid before P | YES | NO | YES |
| Risk expiry `<`, `==`, `>` | YES | NO | YES |
| Fake-broker acknowledgement, not confirmation | YES | YES | YES |

## Public event dispatch matrix

| Event kind | Handler | Direct MQL | Queue-dispatched MQL |
|---|---|---:|---:|
| `ACCEPTED_INGRESS` | `ProcessIngress` | YES | YES |
| `REQUEST_PROGRESSION` | `MaterializeAndProgress` | YES | YES |
| `SUBMISSION_ADMISSION` | `ProcessAdmission` | YES | YES |
| `OWNERSHIP_TAKEOVER` | `ProcessTakeover` | YES | YES |
| `FAKE_BROKER_RESPONSE` | `ProcessFakeBrokerResponse` | YES | YES |
| `RECONCILIATION_REQUIRED` | `ProcessReconciliationRequired` | YES | YES |

All MQL assertions are compile-only in Phase C.2 and are not execution evidence. The queue is a deterministic test scheduler and is never an authority source.
