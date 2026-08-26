# Sprint 5 Phase C.1 audit-finding closure matrix

| Finding | Code correction | Direct MQL assertion | Reference case |
|---|---|---|---|
| CRITICAL-1 initial ordinal | Frozen binding helper now receives ordinal 0 | Exact frozen correlation/idempotency/attempt-0; attempt-1 differs | All initial requests carry ordinal 0 |
| CRITICAL-2 prepared/Claim validation | Coherent package, exact prepared command, current-event binding, mandatory frozen full-result validator | Valid control; ten mutations; split package; replay | Mismatch family and grant replay |
| MAJOR-1 incomplete orchestration | Added Ledger, Sequence, Blueprint, progression, takeover, reconciliation, and response ports/handlers | Frozen Ledger/Sequence/Blueprint controls and handler dispatch | Nineteen end-to-end orchestration cases |
| MAJOR-2 weak verification | Valid Claim fixture derives the complete proposed record; fixed vectors replace invented Phase B hashes; model scope narrowed | Complete valid pair and negative controls | Explicit stateful model, twice-identical traces |

No finding is closed by documentation alone.
