# Sprint 5 Phase D Coverage Matrix

**TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS**

| Requirement | Reference authority / operation | Test IDs |
|---|---|---|
| One-domain CAS and event-local winner | `FakeTransactionalStore.cas` | `CAS-TWO-WRITERS-*`, `CAS-UNCERTAIN-*` |
| Genesis unique provisioning and partial failure | `Genesis.begin/initialize/finalize` | `GENESIS-*` |
| Initial Hard Kill and bootstrap checkpoint | Genesis domain payloads | `GENESIS-HARD-KILL`, `GENESIS-CHECKPOINT` |
| Authoritative clock observation | `Clock.accept` | `CLOCK-*` |
| Stable heartbeat fence / complete takeover evidence | `Lease.heartbeat/takeover` | `LEASE-*` |
| Complete durable Ledger and compaction | `Ledger.accept/validate/compact` | `LEDGER-*`, `CORRUPT-*` |
| Namespace sequence idempotency and gaps | `SequenceStore.reserve` | `SEQUENCE-*`, `CRASH-SEQ-*` |
| Event-local Claim grant | `SubmissionJournal.claim/reload` | `CLAIM-*`, `CRASH-CLAIM-*` |
| Fenced request-set/checkpoint order | `PublicationStore` | `PUBLICATION-*`, `CRASH-SET-*` |
| Exact broker/Execution query union | `restart` | `QUERY-*` |
| Claimed-unresolved and Hard Kill restart | `restart` | `RESTART-CLAIMED-*`, `RESTART-ACTIVE-*` |
| Deterministic repeated execution | complete `run_suite` equality | verifier summary `runs=2`, `deterministic=true` |
