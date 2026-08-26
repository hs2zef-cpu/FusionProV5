# Sprint 5 Phase C.1 coverage matrix

| Requirement | Coordinator implementation | Direct MQL source | Reference case |
|---|---|---|---|
| Initial ordinal 0 | Private frozen binding call uses `0` | Exact ordinal-0/1 fixed vectors | All new requests use local ordinal 0 |
| Coherent prepared package | Command and transition returned together | Prepared-A/Command-B denial | Explicit prepared/result identity |
| Full Claim validation | Frozen validator precedes completion/broker | Ten mismatch controls | Claim mismatch family |
| Current-event grant | Event/ordinal/operation token binding | Prior-event replay denial | Grant replay |
| Ledger/Sequence/Blueprint | Abstract authorities plus frozen Blueprint validator | Frozen direct controls compiled | Ingress-to-created flow |
| Progression | Complete owner-returned request required | Submission boundary controls | Progression/terminal denial |
| Takeover/reconciliation/response | Dedicated handlers | Handler/dispatcher controls | Ordering and acknowledgement cases |
| Queue | Test-only FIFO dispatcher | Dequeue-to-handler assertions | Stable ordered scenario execution |
| Safety ordering | Frozen preparation result consumed | Hard Kill/Trust/Risk fixtures | Hard Kill/Trust/Risk cases |

## Event implementation matrix

| Public event kind | Phase C status |
|---|---|
| Accepted ingress | Implemented by `ProcessIngress` with trusted validation and Ledger authority |
| Request progression | Implemented by `MaterializeAndProgress` with Sequence, Blueprint, and progression authorities |
| Submission/admission | Implemented by `ProcessAdmission` |
| Ownership/takeover | Implemented by `ProcessTakeover` |
| Fake broker response | Implemented by `ProcessFakeBrokerResponse`; acknowledgement is not confirmation |
| Reconciliation required | Implemented by `ProcessReconciliationRequired`; no retry or broker call |
