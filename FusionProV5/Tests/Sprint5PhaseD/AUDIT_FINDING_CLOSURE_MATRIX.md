# Sprint 5 Phase D.2 Audit-Finding Closure Matrix

**TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS**

| Finding | Exact source correction | Direct MQL positive evidence | Re-sealed/direct MQL negative evidence | Python adversarial evidence | D.2 self-status |
|---|---|---|---|---|---|
| CRITICAL-1 Claim substitution | `ReferenceSubmissionStore` validates complete Permit/Risk/normalization, recomputes nested authority digests, canonicalizes the complete Submission record, and compares exact current/prepared/next authority before CAS and final frozen result validation | `D1PositiveClaim` | eight Permit/Risk/normalization/Basket/spec/request mutations are re-sealed before rejection | `D2-CLAIM-RESEALED-*` (8) | CLOSED; independent re-audit required |
| CRITICAL-2 Takeover namespace/reconciliation | `ReferenceLeaseStore` independently configures and compares the complete Persistence Namespace and validates typed Broker/Persistence evidence identity, source, digest, sequence, time, lease/fence/revision/generation relation | `D1PositiveTakeover` | foreign full namespace plus semantically wrong Broker/Persistence evidence | `D2-TAKEOVER-*` (10) | CLOSED; independent re-audit required |
| CRITICAL-3 Restart/query safety | `FakePlatformQuerySource` digests every frozen Broker/Execution DTO field; `ReferenceRestart` reconciles checkpoint/vector/request/query/lease semantics and scans every persisted request | `D1PositiveRestartSafeToResume` | re-sealed Basket/account/query/HWM/correlation/Execution-count/revision and unsafe-second-request probes | `D2-RESTART-*` (11) | CLOSED; independent re-audit required |
| MAJOR-1 domain-canonical CAS | Each public authority store reconstructs and validates its typed proposed state, derives its row internally, and validates exact typed readback around central CAS | domain positive store paths | foreign canonical domain probes for Submission, Lease, Ledger, Sequence, Request Set, Checkpoint | `D2-DOMAIN-CANONICAL-*` (8) | CLOSED; independent re-audit required |
| MAJOR-2 Ledger proposed-state plumbing | `ReferenceIngressLedgerStore` derives one exact next header/index/record state before CAS, commits that row, validates readback, and implements frozen compaction | `D2PositiveLedgerAcceptance`, `D2PositiveLedgerCompaction` | wrong proposed revision, re-sealed accepted-at/HWM, broken linkage and membership | `D2-LEDGER-*`, `CORRUPT-*` | CLOSED; independent re-audit required |
| MAJOR-3 Request Set / Checkpoint publication plumbing | `ReferencePublicationStore` keeps frozen set digest separate from row digest, deep-copies/reloads the set, and requires authoritative set reload before Checkpoint evaluation/CAS | `D2PositiveRequestSetPublication`, `D2PositiveCheckpointAfterSetReload` | stale prepared Checkpoint and foreign canonical Request Set/Checkpoint probes | `D2-CHECKPOINT-*`, `D2-DOMAIN-CANONICAL-REQUEST-SET`, `D2-DOMAIN-CANONICAL-CHECKPOINT` | CLOSED; independent re-audit required |
| MAJOR-4 Python/MQL alignment | Python models corrected complete-authority boundaries, typed domain builders, durable reconstruction, digest-domain separation, and all-request scan | 10 compile-only positive functions | 86 compile-only negative functions, including 28 re-sealed semantic probes | 209/209, two identical internal runs, 209 unique IDs | CLOSED; independent re-audit required |
| MAJOR-5 documentation/evidence overclaim | Phase D documentation states fake-store/fake-clock/reference limits, compile-only MQL classification, exact current counts/digests, and no MQL runtime/SQLite/platform proof | documentation cross-reference | no runtime, production, or Phase E claim | verifier classification is explicit | CLOSED; independent re-audit required |

Preserved closures:

- Genesis: **CLOSED**; no D.2 semantic change.
- Domain CAS routing: **CLOSED**; D.2 adds typed proposed-state validation without reopening the central routing decision.

No finding is closed by documentation alone. Phase D.2 still requires a new independent final persistence/restart re-audit. Phase E is not authorized.
