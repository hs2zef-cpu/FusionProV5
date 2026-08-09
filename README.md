# Fusion Pro V5

## Purpose

Fusion Pro V5 is an MQL5 trading-system architecture project. The current repository preserves the frozen Signal Engine baseline and the isolated Sprint 4 production architecture contracts. Sprint 4 defines contracts only and contains no production broker execution.

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
- `FusionProV5/Tools/`: Repository and development tools.
- `FusionProV5/Scripts/`: Repeatable project scripts.
- `FusionProV5/Tests/`: Deterministic, test-only contract verification assets.
- `FusionProV5/Archive/`: Retained historical project material.
- Root `*.mq5`: Sprint manifests and preserved source baselines.

## Current Sprint

Sprint 4 Architecture remains the current authorized architecture baseline.

`SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_1_CONTRACT_HARDENING` is the Sprint 4.1 **Candidate / In Review**. It is pending formal approval, is not Architecture Locked, and grants no runtime authorization.

Sprint 4.1 hardens the isolated Sprint 4 contracts with versioning, deterministic validation requirements, Architecture Decision Records, and table-driven test specifications. Sprint 3.2.1 remains the frozen Signal Engine baseline. Sprint 4.1 contains no broker execution or runtime wiring.

Sprint 4.2 is an authorized verification sub-sprint within the Sprint 4.1 candidate branch. Sprint 4.3 introduced Production Contract V3 interface verification, and Sprint 4.4 completed its remaining semantic boundaries. Sprint 4.5 is corrective candidate work that advances the unlocked contract candidate to V4 and hardens authority binding, canonical validation, Risk and Unit safety, ownership lifecycle, persistence canonicalization, and test credibility. None of these verification sprints changes the authorized baseline, declares Architecture Lock, grants runtime authorization, or establishes production readiness.

Sprint 4.5 immutable verification passed `368/368` cases with `0` failed and `0` skipped in two intentional independent MT5 Demo Strategy Tester runs. Both runs produced deterministic signature `14243830495988534780` against tested source `f768205573d44d71a7f55b8e893ae0b48770d451`. This evidence supports review of the candidate only.

## Repository Workflow

1. Confirm the authorized Sprint and read the current version and architecture records.
2. Create a focused branch for approved work.
3. Keep changes within the explicitly authorized scope.
4. Review the diff and required evidence before requesting approval.
5. Merge only reviewed and approved changes into the primary branch.

Generated binaries, logs, temporary files, and CSV evidence remain local and are excluded from version control.
