# Phase F Evidence Authority Matrix

| Observation | Authority | Permitted conclusion |
|---|---|---|
| Pre-call validation failure before Claim/call | local authoritative fact | `NO_CALL` only |
| Successful Claim | frozen submission authority | ambiguity begins; no retry |
| Synchronous return, retcode, request id, order/deal fields | provisional classification | never confirmation alone |
| Callback/transaction event alone | provisional evidence | remains unresolved until durable query proof |
| Exact durable ordered deal set and order/position linkage under independently approved correlation policy | positive evidence | full or partial side effect confirmed |
| Magic, comment, or ticket coincidence alone | non-authoritative hint | no terminal conclusion |
| Zero rows from incomplete/unproven query | non-authoritative negative candidate | remains unresolved |
| Two complete joint observations after a proven visibility watermark | authoritative negative evidence | no side effect confirmed |
| Query error/read failure/truncation/reconnect-generation mismatch | ambiguity | remains unresolved |

Broker Adapter and Execution query sets retain separate component ownership. A joint conclusion consumes both without creating a duplicate source of truth.
