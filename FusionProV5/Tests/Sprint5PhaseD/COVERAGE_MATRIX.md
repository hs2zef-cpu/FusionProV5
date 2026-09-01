# Sprint 5 Phase D Coverage Matrix

**TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS**

| Requirement | Reference authority / operation | Test IDs |
|---|---|---|
| One-domain CAS and event-local winner | `SWV5S5_FakeTransactionalStore::CompareAndSet`; Python `FakeTransactionalStore.cas` | `CAS-TWO-WRITERS-*`, `CAS-UNCERTAIN-*`, `D1-CAS-*` |
| Genesis exact immutable duplicate, typed domains, partial and digest-valid wrong-content failure | MQL `ReferenceGenesis` typed initializers/`Finalize`; Python `Genesis.begin/initialize/finalize` | `GENESIS-*`; `SWV5S5_D1*Genesis*` |
| Initial Hard Kill and bootstrap checkpoint | Genesis domain payloads | `GENESIS-HARD-KILL`, `GENESIS-CHECKPOINT` |
| Validated authoritative clock observation | `SWV5S5_FakeAuthoritativeClock::AcceptAndSeal/ValidateAccepted`; Python `Clock.accept` | `CLOCK-*`, D1 typed clock probes |
| Stable heartbeat fence / complete namespace and typed takeover evidence | MQL `ReferenceLeaseStore`; Python `Lease.heartbeat/takeover` | `LEASE-*`, `D2-TAKEOVER-*` |
| Exact proposed Ledger header/readback and compaction | MQL `ReferenceIngressLedgerStore`; Python `Ledger.accept/validate/compact/reload` | `LEDGER-*`, `D2-LEDGER-*`, `CORRUPT-*` |
| Namespace sequence idempotency, gaps, and complete durable reconstruction | MQL `ReferenceSequenceStore`; Python `SequenceStore.reserve/durable_payload/reload` | `SEQUENCE-*`, `D2-SEQUENCE-*`, `CRASH-SEQ-*` |
| Complete Permit/Risk/normalization Claim binding and event-local grant | MQL `ReferenceSubmissionStore`; Python `SubmissionJournal.claim/reload` | `CLAIM-*`, `D2-CLAIM-RESEALED-*`, `CRASH-CLAIM-*` |
| Distinct set/row digests and authoritative Set reload before Checkpoint | MQL `ReferencePublicationStore`; Python `PublicationStore` | `PUBLICATION-*`, `D2-CHECKPOINT-*`, `CRASH-SET-*` |
| Complete domain-canonical proposed-state validation | six typed reference stores and Python typed builders/loaders | `D2-DOMAIN-CANONICAL-*` |
| Complete Broker/Execution summary digest, exact query union, checkpoint/request reconciliation, all-request scan | MQL `FakePlatformQuerySource`/`ReferenceRestart`; Python `restart` | `QUERY-*`, `D2-RESTART-*` |
| Claimed-unresolved and canonical independent Hard Kill release authority | `SWV5S5_ReferenceReleaseAuthorityValid`; Python `valid_release_authority`/`restart` | `RESTART-CLAIMED-*`, `RESTART-ACTIVE-*`, `RESTART-RELEASE-*`; `SWV5S5_D1*Restart*` |
| Direct MQL source evidence | 10 positive, 86 negative, including 28 re-sealed semantic compile-only probes | `SWV5S5_D1*`, `SWV5S5_D2*`; compiled YES, executed NO |
| Deterministic repeated execution | complete `run_suite` equality | verifier summary `runs=2`, `deterministic=true` |
