# Sprint 5 Phase D Coverage Matrix

**TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS**

| Requirement | Reference authority / operation | Test IDs |
|---|---|---|
| One-domain CAS and event-local winner | `SWV5S5_FakeTransactionalStore::CompareAndSet`; Python `FakeTransactionalStore.cas` | `CAS-TWO-WRITERS-*`, `CAS-UNCERTAIN-*`, `D1-CAS-*` |
| Genesis exact immutable duplicate, typed domains, partial and digest-valid wrong-content failure | MQL `ReferenceGenesis` typed initializers/`Finalize`; Python `Genesis.begin/initialize/finalize` | `GENESIS-*`; `SWV5S5_D1*Genesis*` |
| Initial Hard Kill and bootstrap checkpoint | Genesis domain payloads | `GENESIS-HARD-KILL`, `GENESIS-CHECKPOINT` |
| Validated authoritative clock observation | `SWV5S5_FakeAuthoritativeClock::AcceptAndSeal/ValidateAccepted`; Python `Clock.accept` | `CLOCK-*`, D1 typed clock probes |
| Stable heartbeat fence / complete namespace and typed takeover evidence | MQL `ReferenceLeaseStore`; Python `Lease.heartbeat/takeover` | `LEASE-*`, `D2-TAKEOVER-*` |
| Complete frozen Takeover versions, claimant identity, and exact observation point | centralized MQL takeover validator; structured Python evidence | `D3-TAKEOVER-*`; `SWV5S5_D3NegativeTakeover*` |
| Exact proposed Ledger header/readback and compaction | MQL `ReferenceIngressLedgerStore`; Python `Ledger.accept/validate/compact/reload` | `LEDGER-*`, `D2-LEDGER-*`, `CORRUPT-*` |
| Namespace sequence idempotency, gaps, and complete durable reconstruction | MQL `ReferenceSequenceStore`; Python `SequenceStore.reserve/durable_payload/reload` | `SEQUENCE-*`, `D2-SEQUENCE-*`, `CRASH-SEQ-*` |
| Complete Permit/Risk/normalization Claim binding and event-local grant | MQL `ReferenceSubmissionStore`; Python `SubmissionJournal.claim/reload` | `CLAIM-*`, `D2-CLAIM-RESEALED-*`, `CRASH-CLAIM-*` |
| Distinct set/row digests and authoritative Set reload before Checkpoint | MQL `ReferencePublicationStore`; Python `PublicationStore` | `PUBLICATION-*`, `D2-CHECKPOINT-*`, `CRASH-SET-*` |
| Complete domain-canonical proposed-state validation | six typed reference stores and Python typed builders/loaders | `D2-DOMAIN-CANONICAL-*` |
| Complete Broker/Execution summary digest, exact query union, checkpoint/request reconciliation, all-request scan | MQL `FakePlatformQuerySource`/`ReferenceRestart`; Python `restart` | `QUERY-*`, `D2-RESTART-*` |
| Production LP2 checkpoint, full vector/source digest, Basket state/version/reconciliation, Hard Kill generation | MQL complete restart-checkpoint validator; Python structured checkpoint | `D3-RESTART-*` |
| ADR-022 exact zero-history | Genesis-ready zero classification without prior correlation/event/HWM | `D3-ZERO-*`; `SWV5S5_D3*ZeroHistory*` |
| Publication commitment only after CAS/readback | MQL/Python reference publication stores | `D3-PUBLICATION-*` |
| Claimed-unresolved and canonical independent Hard Kill release authority | `SWV5S5_ReferenceReleaseAuthorityValid`; Python `valid_release_authority`/`restart` | `RESTART-CLAIMED-*`, `RESTART-ACTIVE-*`, `RESTART-RELEASE-*`; `SWV5S5_D1*Restart*` |
| Direct MQL source evidence | 17 named positive and 157 named negative functions; compile-only, executed NO | `SWV5S5_D1*`, `SWV5S5_D2*`, `SWV5S5_D3*`, `SWV5S5_D4*` |
| Deterministic repeated execution | complete `run_suite` equality | verifier summary `runs=2`, `deterministic=true` |

D.4 focused mappings:

| Requirement | MQL source/direct evidence | Python family |
|---|---|---|
| Complete ownership key and governed namespace; current Lease clock/expiry boundary | `ReferenceOwnershipKeyComplete`, `TakeoverEvidenceValid`; `D4NegativeTakeover*` | D4_TAKEOVER (9) |
| Live Lease and frozen Basket/vector/Hard-Kill intrinsic semantics, full Broker identity/HWM | `ReferenceLiveLeaseValid`, `ReferenceCheckpointSemanticValid`; `D4*Ordinary*`, `D4NegativeRestart*`, `D4*ReleaseEnvelope`, `D4NegativeReleasedGeneration` | D4_RESTART (20) |
| Exact policy, complete account, typed exposure, authentication/evidence chronology | `ReferenceReleaseAuthorityValid`; `D4NegativeRelease*` | D4_HARD_KILL (9) |
| ACQUIRED/RENEWED zero-history and inactive/incomplete/wrong-clock denial | `ReferenceZeroHistoryCandidate`; `D4*ZeroHistory*` | D4_ZERO_HISTORY (8) |

All D.4 direct probes are compile-only. Their positive-control guards and resealing classification are documented in `D4_SEMANTIC_EVIDENCE.md`.
