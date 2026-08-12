# Fusion Pro V5

## Project Version

### Current Version

Sprint 4.7 Adversarial Safety and Evidence Reproducibility Candidate

### Date

2026-08-12

### Status

**CANDIDATE / IN REVIEW**

Corrective contract and verification work is part of the Sprint 4.1 candidate branch and remains pending immutable Sprint 4.7 verification, final independent merge audit, and formal approval. Sprint 4.1 is not Architecture Locked and grants no runtime authorization.

## Current Authorized Baseline

Sprint 4 Architecture

`SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_ARCHITECTURE`

## Current Review Candidate

`SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_1_CONTRACT_HARDENING`

Review-candidate compile manifest:

`SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_3_CONTRACT_TESTS.mq5` (test only)

Sprint 4.2 is an authorized verification sub-sprint within this candidate branch. Sprint 4.3 introduced the V3 corrective package, Sprint 4.4 completed its remaining semantic findings, Sprint 4.5 advanced the unresolved candidate to V4, and Sprint 4.6 produced historical candidate evidence that subsequently failed final independent merge audit. Sprint 4.7 closes the five resulting Critical safety findings and the coverage/provenance Major findings. None is a production or runtime authorization.

## Frozen Signal Baseline

`SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT3_2_1`

Sprint 3.2.1 is frozen and remains the rollback and Signal Engine baseline. The Sprint 4 project is isolated and does not modify or runtime-wire that baseline.

## Purpose

Define production Basket, Persistence, Execution, Risk, Statistics, Duplicate Instance, and Unit System contracts before execution exists.

## Current State

- Production contract version 4 corrective candidate (minimum compatible version 4)
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
- Sprint 4.7 reviewed suite: 634 passed, 0 failed, 0 skipped; deterministic signature `18433705061502137480`
- Sprint 4.7 credibility: 610 behavioral, 23 supporting pure-function, 1 conformance-only, 0 weak false-positive; 634 total
- Sprint 4.7 exporter offline verification: 26 passed, 0 failed, 0 skipped; repository hashes are exact Git index/commit blob-byte SHA-256 values
- Static isolation and frozen-baseline scans: complete with no violations

## Next Authorized Action

After the Sprint 4.7 source-freeze commit, perform immutable verification and evidence generation under the approved reproducibility pipeline. A new final independent merge audit remains required before any merge or formal approval decision. Sprint 4 Architecture remains the authorized baseline until approval.

Do not merge or begin runtime implementation without separate approval. Any adapter, store, lock, risk calculation, broker integration, recovery behavior, basket execution, or Signal-to-Execution wiring requires a separately approved Sprint.
