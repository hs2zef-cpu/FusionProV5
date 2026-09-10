# Phase F Evidence Authority Matrix

| Observation/artifact | Required authority | Permitted conclusion |
|---|---|---|
| Digest-bound local Claim/invocation absence proof | Execution store / Execution request-state authority | `NO_CALL` only before successful Claim |
| Successful Claim | frozen Submission Authority | ambiguity begins; no retry |
| Sync return, retcode, callback, timeout or request-id fields | provisional classification | never confirmation alone |
| Magic/comment coincidence | request-correlation aid only | never terminal authority |
| Pinned correlation policy plus independently governed capability proof and complete ordered broker evidence | positive evidence | full or partial side effect confirmed |
| Durable broker effect with invalid/missing/foreign Claim binding | Broker evidence plus failed authority binding | orphan side effect; `RECONCILIATION_BLOCKED` |
| Partial confirmed effect | reconciliation reporting | residual is never submission authority |
| Bare capability/completeness/watermark booleans | self-attestation | no authority |
| Operator-approved, profile-bound capability-proof artifact pinned before Claim | independent governance authority | may qualify correlation/completeness/watermark checks |
| Zero rows from incomplete/unproven query | non-authoritative candidate | remains unresolved |
| Two generation-stable observations after lag/stability gates from separately owned Broker and Execution paths | bounded authoritative negative evidence | no side effect confirmed |
| Shared cache/common authority, sequence failure, back-to-back read, generation drift or row-read failure | invalid joint negative proof | remains unresolved/fails closed |
| Evidence applied to terminal state | conflict detector only | preserve exact replay or move to sticky blocked state |

Capability proof, correlation policy, negative policy, positive evidence, negative observation and terminal result have distinct canonical digest domains. Current-latest policy lookup is forbidden; the evaluator consumes only identities/versions/digests pinned to the request/admission/Claim boundary.
