# Fusion Pro V5

Current governance: the independent Phase D.5 re-audit passed with **Critical
NONE / Major NONE / Minor NONE**. Phase D is **CLOSED / COMPLETE** at
`f0434d0e84907b1d454deec0abb899c16b35cd35`; another Phase-D audit is required
only if Phase-D code changes. [Phase E](FusionProV5/Docs/SPRINT5_PHASE_E_AUTHORIZATION_STATUS.md)
is authorized for integrated V5 fixtures and reference-integration conformance
only. Phase F/G, runtime/platform/broker work, MT5, and main merge remain
unauthorized.

## Purpose

Fusion Pro V5 is an MQL5 trading-system architecture project. The current repository preserves the frozen Signal Engine baseline and the isolated Sprint 4 production architecture contracts. The Architecture Review and Phase B/C/D gates are closed/pass. Phase E integration-conformance fixtures are authorized; they grant no production authority or runtime authorization.

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

The Final Independent Sprint 5 Phase A.4 Architecture Gate is **CLOSED** at `31e76411829e2f2e6acb24740ddca32b886969e0`. The Phase B gate is **CLOSED / PASS** at `1366edb25238463c9a76fa78257196dbf4c64e34`. The New Independent Phase C.2 Final Orchestration Re-Audit returned **PASS — Critical NONE / Major NONE / Minor NONE**. Phase C completeness is **COMPLETE**, and the deterministic orchestration gate is **CLOSED / PASS** at `55cd230ca222c60cd42dd218efe5e175ba70acd6`.

The Final Independent Merge Audit passed with no Critical or Major findings. All six Critical findings, all three prior Final-Audit MAJOR findings, and the infrastructure closure matrix are closed. Merge Safety was `SAFE`, the final verdict was `PASS`, and the audited package was declared ready to merge.

The audited evidence commit `87f77c8b0b9253c2a851540085f8b7ce14cf2e52` was fast-forwarded from old main `ed8b2b61ff83982faece7b7babd5ae6fd993e5f4` into local and remote `main`; no merge commit was created, and the candidate branch was retained. Its frozen technical source remains `ef556a94636e977e35e961be28ae03c9838615d4` with tree `19db1538ab3ddfc982006ba89d43cf01c5e51f18`; the merged evidence tree is `c088ae72ee66e1896d7a6ed0ad62d1fec190f6b3`, and the D5 verification digest is `fe46965aa392df1a1dcc1cd919b77581445a589a1c694217ddb4a5b489617778`. Earlier V4 and Sprint 4.8 source/evidence generations remain superseded historical records.

Sprint 3.2.1 remains the frozen Signal Engine baseline. Phase D is **CLOSED / COMPLETE** after the independent D.5 PASS. Phase E is authorized only for deterministic test fixtures, harnesses and independent reference evidence. Phase F/G, physical persistence, real SQLite/database code, real broker/platform integration, MT5 runtime, Terminal/Strategy Tester, Signal-to-Execution wiring, merge to main, production, and live trading remain unauthorized.

## Repository Workflow

1. Confirm the authorized Sprint and read the current version and architecture records.
2. Create a focused branch for approved work.
3. Keep changes within the explicitly authorized scope.
4. Review the diff and required evidence before requesting approval.
5. Merge only reviewed and approved changes into the primary branch.

Generated binaries, logs, temporary files, and CSV evidence remain local and are excluded from version control.
