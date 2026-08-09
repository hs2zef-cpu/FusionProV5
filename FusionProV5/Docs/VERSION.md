# Fusion Pro V5

## Project Version

### Current Version

Sprint 4.5 Authority Binding and State Semantics Candidate

### Date

2026-08-10

### Status

**CANDIDATE / IN REVIEW**

Corrective contract and verification work is part of the Sprint 4.1 candidate branch and remains pending independent review. Sprint 4.1 is not Architecture Locked and grants no runtime authorization.

## Current Authorized Baseline

Sprint 4 Architecture

`SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_ARCHITECTURE`

## Current Review Candidate

`SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_1_CONTRACT_HARDENING`

Review-candidate compile manifest:

`SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_3_CONTRACT_TESTS.mq5` (test only)

Sprint 4.2 is an authorized verification sub-sprint within this candidate branch. Sprint 4.3 introduced the V3 corrective package, Sprint 4.4 completed its remaining semantic findings, and Sprint 4.5 advances the unresolved candidate to V4 with authority-binding, canonical-validation, ownership, persistence, Risk, Unit, and test-credibility corrections. None is a production or runtime authorization.

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
- Static isolation and frozen-baseline scans: complete with no violations

## Next Authorized Action

Review and formally approve or reject the Sprint 4.1 Contract Hardening candidate. Sprint 4 Architecture remains the authorized baseline until approval.

Do not merge or begin runtime implementation without separate approval. Any adapter, store, lock, risk calculation, broker integration, recovery behavior, basket execution, or Signal-to-Execution wiring requires a separately approved Sprint.
