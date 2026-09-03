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

The D.4 oracle executes 294 unique scenarios (294 passed, 0 failed, 0 skipped) twice in one invocation. Equality covers test output, final durable state digest, authority revisions, grant counts, traces, and serialized result digest. Separately, the MQL assertion source defines 17 direct positive and 157 direct negative functions. Those MQL probes compile only and are never executed; they are not substituted for Python executable evidence or independent review.

D.4 family totals: Takeover 9; Restart 20; Hard Kill 9; Zero History 8. Retained scenarios: 248; D.4 additions: 46; total: 294 unique IDs. No old safety test was deleted.

Named MQL counts exclude two parameterized rejection helpers (renamed `Reject...` to avoid counting helpers as assertions). D.4 adds 4 positive and 38 negative assertions; classification is 26 re-sealed paths and 12 direct typed/status paths. The 34 legacy non-proving probes remain excluded from D.4 closure. MQL assertions executed: **NO**.

## Executed family totals

| Family | Count |
|---|---:|
| CAS | 11 |
| CLAIM_COMPLETE_AUTHORITY | 8 |
| CLAIM_JOURNAL | 11 |
| CORRUPTION | 17 |
| CRASH | 7 |
| D3_HARD_KILL | 3 |
| D3_PUBLICATION | 8 |
| D3_RESTART | 7 |
| D3_TAKEOVER | 10 |
| D3_ZERO_HISTORY | 11 |
| D4_HARD_KILL | 9 |
| D4_RESTART | 20 |
| D4_TAKEOVER | 9 |
| D4_ZERO_HISTORY | 8 |
| DOMAIN_CANONICAL | 8 |
| FULL_QUERY | 17 |
| GENESIS | 35 |
| LEASE_TAKEOVER | 19 |
| LEDGER_EXACT | 1 |
| PUBLICATION | 12 |
| RESTART | 33 |
| RESTART_COMPLETE_AUTHORITY | 11 |
| SEQUENCE | 9 |
| TAKEOVER_COMPLETE_AUTHORITY | 10 |
| **Total** | **294** |
