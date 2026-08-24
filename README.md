# Fusion Pro V5

## Purpose

Fusion Pro V5 is an MQL5 trading-system architecture project. The current repository preserves the frozen Signal Engine baseline and the isolated Sprint 4 production architecture contracts. The Sprint 5 Phase A.4 Architecture Gate passed. The independent Phase B.1 contract re-audit failed with 2 Critical, 6 Major, and 0 Minor findings; Phase B.2 is authorized only to correct the remaining pure, platform-independent candidate-contract and verification defects. It contains no production broker execution.

## Repository Location

Canonical repository root:

`C:\Users\Nutthakrit\Documents\FusionProV5`

GitHub remote:

`https://github.com/hs2zef-cpu/FusionProV5.git`

## Repository Structure

- `FusionProV5/`: Project modules and supporting material.
- `FusionProV5/Docs/`: Version, Sprint, compilation, and architecture records.
- `FusionProV5/Docs/Architecture/`: Authoritative architecture documents.
- `FusionProV5/Evidence/`: Runtime and regression evidence guidance.
- `FusionProV5/ProductionArchitecture/`: Sprint 4 production architecture contracts.
- `FusionProV5/ExecutionLayer/Contracts/`: Isolated Sprint 5 pure candidate contracts.
- `FusionProV5/Tools/`: Repository and development tools.
- `FusionProV5/Scripts/`: Repeatable project scripts.
- `FusionProV5/Tests/`: Deterministic, test-only contract verification assets.
- `FusionProV5/Archive/`: Retained historical project material.
- Root `*.mq5`: Sprint manifests and preserved source baselines.

## Current Sprint

Sprint 4 Architecture remains the current authorized architecture baseline. The audited Sprint 4 Production Contract V5 package has been fast-forwarded into `main`, but it remains **UNLOCKED / PENDING FORMAL ARCHITECTURE APPROVAL**.

The Final Independent Sprint 5 Phase A.4 Architecture Gate returned `PASS`, with no Critical or Major findings, and is **CLOSED**. Approved architecture authority is commit `31e76411829e2f2e6acb24740ddca32b886969e0`. The independent Sprint 5 Phase B.1 Contract Re-Audit returned **FAIL — 2 Critical / 6 Major / 0 Minor**. The Architecture Review Gate remains closed because this is an implementation-conformance failure against the approved ADRs. Sprint 5 Phase B.2 is **AUTHORIZED — FINAL PHASE B CONTRACT CONFORMANCE CORRECTION ONLY** on the isolated `sprint5-phase-b-pure-contracts` branch. The corrected artifacts remain Sprint 5 Candidate Contracts, not existing V5 authority; Phase C is not authorized.

The Final Independent Merge Audit passed with no Critical or Major findings. All six Critical findings, all three prior Final-Audit MAJOR findings, and the infrastructure closure matrix are closed. Merge Safety was `SAFE`, the final verdict was `PASS`, and the audited package was declared ready to merge.

The audited evidence commit `87f77c8b0b9253c2a851540085f8b7ce14cf2e52` was fast-forwarded from old main `ed8b2b61ff83982faece7b7babd5ae6fd993e5f4` into local and remote `main`; no merge commit was created, and the candidate branch was retained. Its frozen technical source remains `ef556a94636e977e35e961be28ae03c9838615d4` with tree `19db1538ab3ddfc982006ba89d43cf01c5e51f18`; the merged evidence tree is `c088ae72ee66e1896d7a6ed0ad62d1fec190f6b3`, and the D5 verification digest is `fe46965aa392df1a1dcc1cd919b77581445a589a1c694217ddb4a5b489617778`. Earlier V4 and Sprint 4.8 source/evidence generations remain superseded historical records.

Sprint 3.2.1 remains the frozen Signal Engine baseline. Architecture Lock, Phase C, runtime, broker, physical store, MT5 integration, Signal-to-Execution wiring, merge to main, production, and live trading remain unauthorized. After Phase B.2 self-verification, the next gate is a **NEW INDEPENDENT SPRINT 5 PHASE B.2 CONTRACT RE-AUDIT** in a fresh review task.

## Repository Workflow

1. Confirm the authorized Sprint and read the current version and architecture records.
2. Create a focused branch for approved work.
3. Keep changes within the explicitly authorized scope.
4. Review the diff and required evidence before requesting approval.
5. Merge only reviewed and approved changes into the primary branch.

Generated binaries, logs, temporary files, and CSV evidence remain local and are excluded from version control.
