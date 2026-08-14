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

Sprint 4.2 is an authorized verification sub-sprint within the Sprint 4.1 candidate branch. Sprint 4.3 introduced Production Contract V3 interface verification, Sprint 4.4 completed its remaining semantic boundaries, and Sprint 4.5 advanced the unlocked contract candidate to V4. Sprint 4.6 evidence is superseded failed-candidate history after final independent audit. Sprint 4.7 is immutable historical evidence for the now-superseded V4 candidate. Sprint 4.8 is the current Production Contract V5 Candidate / In Review and remains unlocked. None of these verification sub-sprints changes the authorized baseline, declares Architecture Lock, grants runtime authorization, establishes production readiness, or authorizes merge. A specific tested source commit may be frozen solely to make verification and evidence immutable; that technical source freeze is not Architecture Lock, formal approval, production readiness, runtime authorization, or merge authorization.

Sprint 4.7 immutable verification passed `634/634` against its V4 source, but Sprint 4.8 supersedes that candidate contract. Production Contract V4 is a superseded candidate / historical pre-approval artifact. Sprint 4.8 source `06e0d6e2c9c9138a73ebe69bbdd1766c813d5f89` was technically source-frozen and its immutable verification passed `846/846` twice with identical signature `12393352988365616976`; evidence commit `eebbd169aeff6afaeeaba75c1c120d823e2ec2b3` packaged those facts. The subsequent final independent audit failed, so both commits are immutable, superseded failed-audit history rather than current merge evidence. Phase B10 is corrective Candidate / In Review work with no current final source freeze. It closes the query-domain mask, classifies `snapshot_id` as diagnostic-only, adds explicit atomic publication of accepted owner-specific anti-replay high-watermarks, and makes evidence verification derive the tested Git tree and rebuild one canonical verification-source digest. Local verification passed 934/934 MQL cases and 73/73 offline exporter cases; these are working-tree review facts, not immutable final evidence. A new source review and separately authorized freeze/evidence cycle are required. Production Contract V5 remains unlocked, and Sprint 4 remains the authorized baseline. No runtime authorization, production-readiness claim, merge authorization, formal approval, or Architecture Lock is granted.

## Repository Workflow

1. Confirm the authorized Sprint and read the current version and architecture records.
2. Create a focused branch for approved work.
3. Keep changes within the explicitly authorized scope.
4. Review the diff and required evidence before requesting approval.
5. Merge only reviewed and approved changes into the primary branch.

Generated binaries, logs, temporary files, and CSV evidence remain local and are excluded from version control.
