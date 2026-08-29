# Sprint 5 Phase D Coverage Matrix

**TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS**

| Requirement | Reference authority / operation | Test IDs |
|---|---|---|
| One-domain CAS and event-local winner | `SWV5S5_FakeTransactionalStore::CompareAndSet`; Python `FakeTransactionalStore.cas` | `CAS-TWO-WRITERS-*`, `CAS-UNCERTAIN-*`, `D1-CAS-*` |
| Genesis exact immutable duplicate, typed domains, partial and digest-valid wrong-content failure | MQL `ReferenceGenesis` typed initializers/`Finalize`; Python `Genesis.begin/initialize/finalize` | `GENESIS-*`; `SWV5S5_D1*Genesis*` |
| Initial Hard Kill and bootstrap checkpoint | Genesis domain payloads | `GENESIS-HARD-KILL`, `GENESIS-CHECKPOINT` |
| Validated authoritative clock observation | `SWV5S5_FakeAuthoritativeClock::AcceptAndSeal/ValidateAccepted`; Python `Clock.accept` | `CLOCK-*`, D1 typed clock probes |
| Stable heartbeat fence / complete takeover evidence | `Lease.heartbeat/takeover` | `LEASE-*` |
| Complete durable Ledger and compaction | `Ledger.accept/validate/compact` | `LEDGER-*`, `CORRUPT-*` |
| Namespace sequence idempotency and gaps | `SequenceStore.reserve` | `SEQUENCE-*`, `CRASH-SEQ-*` |
| Event-local Claim grant | `SubmissionJournal.claim/reload` | `CLAIM-*`, `CRASH-CLAIM-*` |
| Fenced request-set/checkpoint order | `PublicationStore` | `PUBLICATION-*`, `CRASH-SET-*` |
| Exact broker/Execution query union | `restart` | `QUERY-*` |
| Claimed-unresolved and canonical independent Hard Kill release authority | `SWV5S5_ReferenceReleaseAuthorityValid`; Python `valid_release_authority`/`restart` | `RESTART-CLAIMED-*`, `RESTART-ACTIVE-*`, `RESTART-RELEASE-*`; `SWV5S5_D1*Restart*` |
| Direct MQL source evidence | 5 positive and 65 negative compile-only function probes | `SWV5S5_D1Positive*`, `SWV5S5_D1Negative*`; compiled YES, executed NO |
| Deterministic repeated execution | complete `run_suite` equality | verifier summary `runs=2`, `deterministic=true` |
