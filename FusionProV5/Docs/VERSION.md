# Fusion Pro V5

## Project Version

### Current Version

Sprint 4.8 Production Contract V5 Candidate

### Date

2026-08-21

### Status

**CANDIDATE / IN REVIEW**

Corrective contract and verification work is part of the Sprint 4.1 candidate branch. Sprint 4 remains the authorized baseline. Sprint 4.8 and Production Contract V5 are Candidate / In Review / Unlocked / Pending Approval. Production Contract V4 is a superseded candidate / historical pre-approval artifact. B10.1 source `e56e51e72dc5fd9ee47d847781a545134b092059` and evidence `b6b36f204d4ebeb3aab4fdacf31b0b8b5b8e1b91` are immutable superseded failed-final-audit history. Phase B11 source `b9b175a5226dd85c3eaacc86c2daca2a42f24b01` and D4 are superseded development and failed-verification history. B11.6 is technically frozen at `ef556a94636e977e35e961be28ae03c9838615d4`; D5 immutable verification passed, and E5 reproducible evidence is complete. All six Critical findings, three Final-Audit MAJOR findings, and parser/harness closures are closed. The next gate is a new Final Independent Merge Audit. No Architecture Lock, runtime authorization, production-readiness claim, merge authorization, or formal approval is made.

## Current Authorized Baseline

Sprint 4 Architecture

`SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_ARCHITECTURE`

## Current Review Candidate

`SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_1_CONTRACT_HARDENING`

Review-candidate compile manifest:

`SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_3_CONTRACT_TESTS.mq5` (test only)

Sprint 4.2 is an authorized verification sub-sprint within this candidate branch. Sprint 4.3 introduced V3, Sprint 4.4 completed remaining semantic findings, and Sprint 4.5 advanced the unresolved candidate to V4. Sprint 4.6 is failed-candidate history and Sprint 4.7 is superseded immutable V4 history. Sprint 4.8 is the current V5 corrective candidate. None is a production or runtime authorization.

## Frozen Signal Baseline

`SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT3_2_1`

Sprint 3.2.1 is frozen and remains the rollback and Signal Engine baseline. The Sprint 4 project is isolated and does not modify or runtime-wire that baseline.

## Purpose

Define production Basket, Persistence, Execution, Risk, Statistics, Duplicate Instance, and Unit System contracts before execution exists.

## Current State

- Production Contract V5 corrective candidate (minimum compatible version 5)
- Production Contract V4 superseded candidate / historical pre-approval artifact
- Deterministic validation context required by every contract interface
- Contract compatibility and migration policy documented
- Execution host and Hedging-only initial account-mode decisions recorded
- Persistence/lease compare-and-set and authoritative clock rules recorded
- Transaction idempotency and raw-retcode mapping ownership recorded
- Pip/unit and Hard Kill governance decisions recorded
- Table-driven validation specification and executable interface-level suite complete
- Basket state machine contract complete
- Persistence and restart reconciliation contract complete
- Execution request and confirmation contract complete
- Risk-domain contract complete
- Basket aggregate and close-verification contract complete
- Authoritative deal statistics contract complete
- Duplicate-instance lease contract complete
- Unit and normalization contract complete
- No concrete production implementation
- No broker command path
- Sprint 4.4 historical Architecture and test manifests, MetaEditor X64 Regular: 0 errors, 0 warnings
- Sprint 4.4 historical MT5 Demo Strategy Tester evidence: 238 passed, 0 failed, 0 skipped, repeated twice with signature `6132791249901820115`
- Sprint 4.5 immutable verification: 368 passed, 0 failed, 0 skipped in each of two intentional independent MT5 Demo Strategy Tester runs; identical signature `14243830495988534780`; tested source `f768205573d44d71a7f55b8e893ae0b48770d451`
- Sprint 4.6 immutable verification: 561 passed, 0 failed, 0 skipped in each of two intentional MT5 Demo/Trial Strategy Tester runs; identical signature `11321096574546544847`; tested source `50f0dc5f35f3fafd8604081cee6cb0c07cb9effe`; source tree `32c04850f08b488f6376943135d83df992979e78`
- Sprint 4.6 credibility: 537 behavioral, 23 supporting pure-function, 1 conformance-only, 0 weak false-positive; 561 total
- Sprint 4.6 source/evidence is superseded failed-candidate history after the final independent merge audit found five Critical safety defects and Major coverage/provenance gaps
- Sprint 4.7 immutable verification: 634 passed, 0 failed, 0 skipped in each of two intentional MT5 Demo Strategy Tester runs; identical signature `18433705061502137480`; tested source `008411c67239372968a4f742519984169044b7e4`
- Sprint 4.7 credibility: 610 behavioral, 23 supporting pure-function, 1 conformance-only, 0 weak false-positive; 634 total
- Sprint 4.7 exporter offline verification: 26 passed, 0 failed, 0 skipped; repository hashes are exact Git index/commit blob-byte SHA-256 values
- Sprint 4.8 prior technically frozen source: `06e0d6e2c9c9138a73ebe69bbdd1766c813d5f89`; source tree `13b9a0dc020dbdd293e648c5a6f4c4d1cba05147`; now immutable superseded failed-audit history
- Sprint 4.8 immutable verification: 846 passed, 0 failed, 0 skipped in each of two intentional MT5 Demo Strategy Tester runs; identical signature `12393352988365616976`
- Sprint 4.8 credibility: 773 behavioral, 59 supporting pure-function, 14 conformance-only, 0 weak false-positive; 846 total
- Sprint 4.8 prior reproducible evidence commit: `eebbd169aeff6afaeeaba75c1c120d823e2ec2b3`; immutable superseded failed-audit history, not current merge evidence
- Sprint 4.8 B10.1 superseded failed-final-audit source/evidence: `e56e51e72dc5fd9ee47d847781a545134b092059` / `b6b36f204d4ebeb3aab4fdacf31b0b8b5b8e1b91`
- Sprint 4.8 B11.6 technically frozen source: `ef556a94636e977e35e961be28ae03c9838615d4`; source tree `19db1538ab3ddfc982006ba89d43cf01c5e51f18`
- Sprint 4.8 D5 immutable verification: 969 passed, 0 failed, 0 skipped in each of two intentional MT5 Trial/Demo Strategy Tester runs; identical signature `18372369681406354017`; D4 remains failed historical evidence and is superseded as verification authority
- Sprint 4.8 B11.6 credibility: 892 behavioral, 63 supporting pure-function, 14 conformance-only, 0 weak false-positive; 969 total; exactly 10 round-trip cases
- Sprint 4.8 B11.6 exporter offline verification: 140 passed, 0 failed, 0 skipped; signature `5ee6614cc75642262a67e29661642787d9974de3e364499e05563baf83552bc5`
- Verification-source format `SWV5-SPRINT48-B11-VERIFICATION-SOURCE-V5`; digest `fe46965aa392df1a1dcc1cd919b77581445a589a1c694217ddb4a5b489617778`
- All six Critical findings, three Final-Audit MAJOR findings, and terminal-build, tester-server, exporter-identity, deterministic-provenance, and test-credibility parser/harness findings are closed
- Static isolation and frozen-baseline scans: complete with no violations

## Next Authorized Action

Perform a new Final Independent Merge Audit against the B11.6 frozen source and E5 reproducible evidence. Sprint 4 Architecture remains the authorized baseline until formal approval.

Do not merge or begin runtime implementation without separate approval. Any adapter, store, lock, risk calculation, broker integration, recovery behavior, basket execution, or Signal-to-Execution wiring requires a separately approved Sprint.
