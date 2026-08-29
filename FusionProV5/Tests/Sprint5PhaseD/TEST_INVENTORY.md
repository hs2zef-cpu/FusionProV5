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

The hardened D.1 oracle executes 167 scenarios (167 passed, 0 failed, 0 skipped) twice in one invocation. Equality covers test output, final durable state digest, authority revisions, grant counts, traces, and the serialized result digest. Separately, the MQL assertion source defines 5 direct positive and 65 direct negative functions. Those MQL probes compile only and are never executed.
