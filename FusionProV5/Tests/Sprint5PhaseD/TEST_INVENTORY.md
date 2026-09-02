# Sprint 5 Phase D Test Inventory

**TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS**

| Family | Executable reference coverage |
|---|---|
| CRASH | pre-CAS, in-transaction rollback, post-commit uncertainty, set-before-checkpoint, sequence-before-Ledger, Claim-before-broker |
| CAS | both winner orderings, stale revision/digest/fence/generation, busy, readback mismatch, exact replay/conflict |
| CORRUPTION | schema identity/version, namespace collision, row digest, linkage/member/HWM/duplicate corruption, corrupt-source no-compaction |
| FULL_QUERY | exact broker and Execution union; every missing domain; wrong authority; stale/future observations |
| RESTART | safe, dirty, split publication, broker/persistence ahead, ownership conflict, corruption, claimed uncertainty, request mismatch, canonical independent Hard Kill release authority/digest/reference failures |
| GENESIS | absent, unique create, complete immutable duplicate equality, typed domain initialization, digest-valid semantic conflict, partial, no host self-provision, no operational reprovision |
| LEASE_TAKEOVER | acquire/race, heartbeat/fence stability/race, wrong owner, no clock, complete-evidence takeover/race |
| SEQUENCE | first/idempotent/distinct/conflict/stale, durable crash gap, no reuse, duplicate-sequence corruption |
| PUBLICATION | fenced request set, stale revision/fence, reload gate, checkpoint, split crash, clean-shutdown convergence |
| CLAIM_JOURNAL | one winner, competing/stale writers, persisted replay, permit/fence mismatch, uncertain commit, restart/takeover no grant |
| CLAIM_COMPLETE_AUTHORITY | eight re-sealed Permit ID/revision, Risk ID/content, normalization ID/payload, Basket/spec, request/attempt substitutions |
| TAKEOVER_COMPLETE_AUTHORITY | complete namespace, owner/fence/revision/generation, Broker/Persistence state, evidence sequence/time, independent authority |
| DOMAIN_CANONICAL | digest-valid foreign typed payloads rejected in Submission, Lease, Ledger, Sequence, Request Set, and Checkpoint domains |
| LEDGER_EXACT | exact complete proposed-header/records/index durable readback |
| RESTART_COMPLETE_AUTHORITY | re-sealed Broker/Execution mismatches, checkpoint/vector mismatch, and unsafe request after index zero |
| D3_TAKEOVER | all frozen V5 versions, complete claimant identity, and exact outer/expiry/current observation time |
| D3_RESTART | exact Production LP2 integrity, complete vector source digest, Basket reconciliation/state/version, and Hard Kill generation |
| D3_HARD_KILL | future-effective release, persisted release digest/audit, and authority-reference version |
| D3_ZERO_HISTORY | legitimate Genesis zero-history plus identity/HWM/exposure/query/namespace adversarial cases |
| D3_PUBLICATION | proposal-only state, verified post-readback commitment, and failure/uncertainty non-commitment |

The D.3 oracle executes 248 unique scenarios (248 passed, 0 failed, 0 skipped) twice in one invocation. Equality covers test output, final durable state digest, authority revisions, grant counts, traces, and serialized result digest. Separately, the MQL assertion source defines 13 direct positive and 119 direct negative functions. Those MQL probes compile only and are never executed; they are not substituted for Python executable evidence or independent review.
