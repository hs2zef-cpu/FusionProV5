# Fusion Pro V5 — Master Context and Architecture Constitution

**Fusion Pro V5**  
**Master Architecture Constitution**

| Metadata | Value |
|---|---|
| Version | 5.12 |
| Date | 2026-09-04 |
| Status | **MERGED / AUDITED / UNLOCKED — FORMAL APPROVAL PENDING** |
| Authorized Baseline | **Sprint 4 Architecture** |
| Merged Contract Package | **Production Contract V5 at `87f77c8b0b9253c2a851540085f8b7ce14cf2e52`** |
| Architecture Lock | **NOT LOCKED — PENDING FORMAL APPROVAL** |

## Revision History

| Version | Date | Summary |
|---|---|---|
| 1.0 | 2026-08-02 | Initial official Architecture Constitution after Sprint 3.2 Patch 1. |
| 1.1 | 2026-08-03 | Authorized Sprint 3.2.1 history-token hardening baseline and runtime evidence gate. |
| 2.0 | 2026-08-03 | Authorized isolated Sprint 4 production contracts; Sprint 3.2.1 frozen as Signal Engine baseline. |
| 2.1 | 2026-08-05 | Hardened production contract version 2, deterministic validation context, ADR governance, and table-driven verification requirements. |
| 2.2 | 2026-08-05 | Corrected governance wording: Sprint 4 remains the authorized baseline; Sprint 4.1 is Candidate / In Review pending formal approval. |
| 2.3 | 2026-08-06 | Recorded Sprint 4.2 as an authorized verification sub-sprint and Sprint 4.3 as corrective interface-level verification; advanced the breaking candidate contracts to V3 without Architecture Lock or runtime authorization. |
| 2.4 | 2026-08-10 | Recorded Sprint 4.5 corrective candidate work and advanced the still-unlocked contracts to V4; Sprint 4 remained the authorized baseline and immutable verification was pending at the source-freeze checkpoint. |
| 2.5 | 2026-08-10 | Recorded final Sprint 4.5 immutable verification: two intentional independent MT5 Demo Strategy Tester runs passed 368/368 with identical signature against source `f768205573d44d71a7f55b8e893ae0b48770d451`; candidate governance remains unchanged. |
| 2.6 | 2026-08-12 | Recorded Sprint 4.6 final safety closure and immutable verification: two intentional MT5 Demo/Trial Strategy Tester runs passed 561/561 with identical signature against source `50f0dc5f35f3fafd8604081cee6cb0c07cb9effe`; final independent merge audit remains required and candidate governance remains unchanged. |
| 2.7 | 2026-08-12 | Recorded that Sprint 4.6 evidence became superseded failed-candidate history after final independent audit, and recorded Sprint 4.7 adversarial safety, coverage, and Git-blob evidence-reproducibility closure pending immutable verification. |
| 2.8 | 2026-08-12 | Recorded Sprint 4.7 immutable verification PASS against frozen source `008411c67239372968a4f742519984169044b7e4`: two intentional MT5 Demo Strategy Tester runs passed 634/634 with identical signature; final independent merge audit remains required and candidate governance remains unchanged. |
| 2.9 | 2026-08-12 | Recorded Sprint 4.8 source freeze and immutable verification PASS against source `06e0d6e2c9c9138a73ebe69bbdd1766c813d5f89`: two intentional MT5 Demo Strategy Tester runs passed 846/846 with identical signature, and reproducible Git-blob evidence packaging completed; final independent merge audit remains required and candidate governance remains unchanged. |
| 3.0 | 2026-08-12 | Recorded the failed final audit of the prior Sprint 4.8 source/evidence as immutable superseded history and opened Phase B7 corrective Candidate / In Review work without a current final source freeze, Architecture Lock, runtime authorization, production readiness, or merge authorization. |
| 3.1 | 2026-08-14 | Phase B8 contract-defined the five mandatory restart query domains, separated Execution request authority source, and added deterministic restart freshness and sequence-coherence policy. Candidate remains unlocked and unapproved. |
| 3.2 | 2026-08-14 | Phase B9 separated Broker and Execution query-snapshot authority, added owner-specific persisted anti-replay high-watermarks, independent request fixtures, and semantic evidence verification. Candidate remains unlocked and unapproved. |
| 3.3 | 2026-08-14 | Phase B10 closed the V5 query-domain mask, classified snapshot identifiers as diagnostic labels, defined atomic publication of accepted owner-specific query high-watermarks, and established Git-derived evidence tree and canonical verification-digest reconstruction. Candidate remains unlocked, unapproved, and not source-frozen. |
| 3.4 | 2026-08-15 | Recorded the B10.1 technical source freeze at `e56e51e72dc5fd9ee47d847781a545134b092059`, immutable 934/934 verification twice with identical signature, and reproducible evidence completion. Final independent merge audit remains required; candidate governance remains unchanged. |
| 3.5 | 2026-08-15 | Recorded B10.1 source/evidence as immutable superseded failed-final-audit history and opened B11 successor work for full DTO reconstruction, finite Statistics mutation boundaries, and source-bound per-ID credibility. B11 is Candidate / In Review, unlocked, uncommitted, and not source-frozen. |
| 3.6 | 2026-08-16 | Recorded B11 source `b9b175a5226dd85c3eaacc86c2daca2a42f24b01` as superseded development history and opened B11.1 terminal-build evidence-parser correction. B11.1 is Candidate / In Review, unlocked, uncommitted, and not source-frozen; exact D3 Generate remains blocked by a separate server-record parser mismatch. |
| 3.7 | 2026-08-16 | Recorded B11.2 server-evidence parser closure on top of B11.1: structured tester generation and supported legacy execution records are resolved centrally, source-bound symbol/timeframe and Trial/Demo policy remain fail-closed, and the exact unchanged D3 Generate path passes offline. B11.2 remains Candidate / In Review, unlocked, uncommitted, and not source-frozen. |
| 3.8 | 2026-08-21 | Recorded B11.6 source freeze `ef556a94636e977e35e961be28ae03c9838615d4`, D5 immutable verification PASS with two deterministic 969/969 runs, and E5 reproducible evidence completion. Six Critical, three Final-Audit MAJOR, and parser/harness findings are closed; D4 remains failed historical evidence superseded by D5. The next gate is a new Final Independent Merge Audit, and candidate governance remains unchanged. |
| 3.9 | 2026-08-21 | Recorded Final Independent Merge Audit PASS with no Critical or Major findings, infrastructure closure matrix all pass, and Merge Safety SAFE. Audited evidence commit `87f77c8b0b9253c2a851540085f8b7ce14cf2e52` was fast-forwarded into main from `ed8b2b61ff83982faece7b7babd5ae6fd993e5f4` with no merge commit; the candidate branch was retained. Production Contract V5 remains unlocked pending formal Architecture Lock approval, and runtime remains unauthorized. |
| 4.0 | 2026-08-21 | Opened Sprint 5 Phase A as a documentation-only Execution Layer / EA Host Architecture Candidate / In Review. Defined Signal ingress, sole runtime authorities, deterministic single-writer serialization, Broker Adapter boundary, fail-closed startup/reconciliation, and later phase gates. Sprint 4 remains the authorized baseline; Production Contract V5 remains merged/audited/unlocked; runtime and broker implementation remain unauthorized. |
| 4.1 | 2026-08-21 | Recorded the independent Phase A review failure (one Critical, six Major) and opened Phase A.1 Architecture Safety Closure Candidate / In Review. Corrected ingress canonicalization/trust/replay, deterministic request binding, exact V5 publication boundaries, durable one-attempt submission authority, takeover quiescence, final current Risk revalidation, and all 30 review threats. Phase B and runtime remain unauthorized. |
| 4.2 | 2026-08-21 | Recorded the Phase A.1 re-review failure and opened Phase A.2 Invocation & Publication Authority Closure Candidate / In Review. Separated permit reservation from exactly-once Invocation Claim, defined continuing Producer Trust lifecycle, one namespace-wide Request Sequence Authority, fenced request-set/checkpoint publication, an Admission Version Vector and a derived host-counter concept later superseded by Phase A.3, strict canonical UTF-8 primitive framing, and 38 reviewed threats. Phase B and runtime remain unauthorized. |
| 4.3 | 2026-08-21 | Recorded the Phase A.2 final independent re-review failure with no Critical findings and one remaining Major. Phase A.3 removes the unowned host counter from safety authority and defines ADR-019 owner-supplied stable tokens, coherent double collect, immutable Admission Snapshot linearization, same-event V5 Risk validation/Invocation Claim, and 41 reviewed threats. Phase B and runtime remain unauthorized; final independent re-review is next. |
| 4.4 | 2026-08-21 | Recorded the Phase A.3 final independent re-review failure with no Critical findings and one remaining Major. Phase A.4 defines ADR-020 one Increasing Execution Admission operation, conditional Policy Admission Linearization Point, successful Claim completion/uncertainty, concurrent mutation ordering, and mandatory Claim-time expiry/liveness. Phase B and runtime remain unauthorized; final independent re-review is next. |
| 4.5 | 2026-08-22 | Recorded Final Independent Sprint 5 Phase A.4 Architecture Gate PASS with no Critical or Major findings and closed the Architecture Review Gate at `31e76411829e2f2e6acb24740ddca32b886969e0`. Explicitly authorized Phase B for isolated pure candidate contracts and deterministic verification only. Architecture Lock, runtime, broker, MT5 integration, physical persistence, merge to main, production, and live trading remain unauthorized. |
| 4.6 | 2026-08-22 | Recorded the first independent Sprint 5 Phase B Contract Implementation Audit FAIL with 2 Critical, 10 Major, and 3 Minor findings, and authorized the Phase B.1 implementation-conformance correction only. The approved Phase A architecture is unchanged, the Architecture Review Gate remains closed, and Phase C/runtime remain unauthorized. |
| 4.7 | 2026-08-24 | Recorded the independent Sprint 5 Phase B.1 Contract Re-Audit FAIL with 2 Critical, 6 Major, and 0 Minor findings, and authorized the Phase B.2 final implementation-conformance correction only. The approved Phase A architecture and ADR semantics are unchanged, the Architecture Review Gate remains closed, and Phase C/runtime remain unauthorized. |
| 4.8 | 2026-08-25 | Recorded the independent Sprint 5 Phase B.2 Contract Re-Audit FAIL with 1 Critical, 3 Major, and 0 Minor findings, and authorized the narrow Phase B.3 implementation-conformance correction only. The approved Phase A architecture and ADR semantics are unchanged, the Architecture Review Gate remains closed, and Phase C/runtime remain unauthorized. |
| 4.9 | 2026-08-25 | Recorded the New Independent Sprint 5 Phase B.3 Contract Re-Audit PASS with no Critical, Major, or Minor findings; closed the Phase B pure-contract gate at `1366edb25238463c9a76fa78257196dbf4c64e34`; and authorized Phase C only for deterministic orchestration, scripted fake authorities, a deterministic in-memory test queue, and a test-only fake broker. Phase D/E/F/G, physical persistence, real broker/platform integration, MT5 runtime, main merge, production, and live trading remain unauthorized. |
| 5.0 | 2026-08-26 | Recorded the independent Phase C audit FAIL with 2 Critical, 2 Major, and 0 Minor findings and authorized Phase C.1 implementation-conformance correction only. Phase B and the Architecture Review remain closed; ADR semantics are unchanged. Phase D/E/F/G and runtime remain unauthorized. |
| 5.1 | 2026-08-26 | Recorded the independent Phase C.1 re-audit FAIL with 0 Critical, 4 Major, and 0 Minor findings. The two prior Critical findings and the truthful verification-model correction remain closed. Authorized Phase C.2 only for Ledger authority integrity, Request Sequence authority integrity, request-progression validation, and core queue-to-coordinator dispatch. Phase B and Architecture Review remain closed; ADR semantics are unchanged. Phase D/E/F/G, persistence, broker/runtime, MT5, and main merge remain unauthorized. |
| 5.2 | 2026-08-27 | Recorded the New Independent Phase C.2 Final Orchestration Re-Audit PASS with no Critical, Major, or Minor findings; closed the Phase C deterministic orchestration gate at `55cd230ca222c60cd42dd218efe5e175ba70acd6`; and authorized Phase D0 documentation-only store/CAS/lease-clock and genesis ADR resolution. Phase D implementation, Phase E/F/G, persistence/database code, broker/runtime, MT5, main merge, production, and live trading remain unauthorized. |
| 5.3 | 2026-08-27 | Completed the Phase D0 documentation-only candidate package: ADR-021 selects native MQL5 SQLite in the common folder with one-domain transactions, exact conditional CAS, authoritative readback, and `TimeCurrent()` server-formed observation policy; ADR-022 defines separate fail-closed genesis provisioning with active Hard Kill and mandatory zero-state reconciliation. Both remain pending new independent D0 review; Phase D implementation remains unauthorized. |
| 5.4 | 2026-08-28 | Recorded the New Independent Sprint 5 Phase D0 review PASS with no Critical, Major, or Minor findings; approved ADR-021 and ADR-022; closed the D0 gate; and authorized Phase D only for deterministic fake-store/fake-clock persistence/restart reference implementation. Real database/SQLite/clock/platform integration, Phase E/F/G, MT5, runtime, main merge, production, and live trading remain unauthorized. |
| 5.5 | 2026-08-28 | Recorded the independent Phase D persistence/restart audit FAIL with 3 Critical, 7 Major, and 0 Minor findings; Phase D is incomplete and Phase E is not authorized. Authorized D.1 only for frozen-authority-faithful correction of the fake-store/fake-clock reference and verification gap. Architecture, Phase B/C/D0, Production V5, and ADR semantics remain unchanged. |
| 5.6 | 2026-08-31 | Recorded the Phase D.1 re-audit FAIL with 3 Critical, 5 Major, and 0 Minor findings and authorized the narrow D.2 reference correction. |
| 5.7 | 2026-09-01 | Recorded the Phase D.2 final independent re-audit FAIL with 3 Critical, 4 Major, and 0 Minor findings and authorized only the enumerated D.3 correction. |
| 5.8 | 2026-09-02 | Recorded Phase D.3 self-verification of frozen-version/claimant/time takeover validation, complete Production LP2 checkpoint/vector/Hard Kill validation, ADR-022 zero-history, and post-readback publication results. Phase D remains incomplete pending a new independent D.3 re-audit; Phase E remains unauthorized. |
| 5.9 | 2026-09-03 | Recorded D.3 independent final re-audit FAIL (3 Critical / 3 Major / 0 Minor) and D.4 narrow takeover/live-Lease/Basket/Hard-Kill/RENEWED zero-history self-verification. No frozen semantics changed; independent D.4 re-audit remains required and Phase E unauthorized. |
| 5.10 | 2026-09-04 | Recorded independent Phase D.5 PASS with no Critical, Major, or Minor findings; closed Phase D at `f0434d0e84907b1d454deec0abb899c16b35cd35`; authorized Phase E integration-conformance fixtures only. Phase F/G, runtime/platform/broker, MT5, main merge, and production remain unauthorized. |
| 5.11 | 2026-09-04 | Recorded Fusion's final Phase E gate **CLOSED / PASS** at technical source `75351935154c57400525e16c4dfceb3103f8c740`, tree `370d4dc7c0caac153efef23521c0c6f66c9be062`, after AiPASS post-patch re-review **PASS — NO CRITICAL / MAJOR FINDINGS** and closure of M-1. This is governance closure only; Phase F/G, Architecture Lock, main merge, production/runtime, physical persistence/platform clock/real broker, and MT5 behavioral evidence remain unauthorized, unimplemented, or unproven as applicable. |
| 5.12 | 2026-09-04 | Authorized Sprint 5 Phase F0 for broker-profile, evidence-contract, measurement, and isolated test-harness work only. Attended Demo probes may be used solely for empirical profiling. Phase F implementation, production Broker Adapter/general execution, unattended Demo, live/real-money accounts, production VPS, Phase G, Architecture Lock, and main merge remain unauthorized or prohibited. |

## Purpose

This document is the authoritative context for all future Fusion Pro V5 conversations, architecture reviews, audits, and Codex tasks.

It exists to prevent unauthorized implementation, baseline confusion, Signal Engine and Execution Layer coupling, unverified reuse of `XAU_Scalper_AI_v17`, weakening of established architecture, and misclassification of intentionally deferred work as defects.

## Authoritative Baseline

The current authorized architecture baseline is **Fusion Pro V5 Sprint 4 Architecture**.

The audited **Fusion Pro V5 Production Contract V5** package has been merged to main. It remains **unlocked pending formal Architecture Lock approval** and grants no runtime authorization.

The frozen Signal Engine baseline is **Fusion Pro V5 Sprint 3.2.1**. Sprint 4 does not modify or runtime-wire it.

The Sprint 5 Architecture Review and Phase B/C/D/E gates are **CLOSED / PASS**. Phase E closed at technical source `75351935154c57400525e16c4dfceb3103f8c740`, tree `370d4dc7c0caac153efef23521c0c6f66c9be062`, after AiPASS post-patch re-review **PASS — NO CRITICAL / MAJOR FINDINGS** and Fusion closure of M-1. Production V5, frozen Phase B/C/D/E technical semantics, and ADR semantics remain unchanged. Real database/SQLite/clock/platform integration, Phase F/G, MT5 runtime or behavioral evidence, main merge, Architecture Lock, production readiness, production, and live trading remain unauthorized.

Project:

`C:\Users\Nutthakrit\Documents\FusionProV5`

Main source:

`SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_ARCHITECTURE.mq5`

Latest verified MetaEditor compilation:

- Errors: `0`
- Warnings: `0`
- Target: X64 Regular
- Production contract version: audited V5 package merged to main, unlocked; minimum compatible version 5
- Frozen Signal snapshot schema: V5

The Sprint 4 Architecture manifest remains unchanged. Historical Sprint 4.6 evidence is superseded failed-candidate history, Sprint 4.7 immutable verification is superseded V4 history, and earlier Sprint 4.8 source/evidence generations remain superseded V5 history. The B11.6 audited technical source is frozen at `ef556a94636e977e35e961be28ae03c9838615d4` with tree `19db1538ab3ddfc982006ba89d43cf01c5e51f18`; D5 immutable verification and E5 evidence bind to digest `fe46965aa392df1a1dcc1cd919b77581445a589a1c694217ddb4a5b489617778`. The Final Independent Merge Audit passed with no Critical or Major findings, all six Critical and three prior Final-Audit MAJOR findings closed, infrastructure closure matrix all pass, and Merge Safety SAFE. Evidence commit `87f77c8b0b9253c2a851540085f8b7ce14cf2e52` with tree `c088ae72ee66e1896d7a6ed0ad62d1fec190f6b3` was fast-forwarded into main from `ed8b2b61ff83982faece7b7babd5ae6fd993e5f4`; no merge commit was created, remote main was updated, and the candidate branch was retained. Production Contract V5 is merged and audited but remains unlocked. No Architecture Lock, production readiness, runtime authorization, broker execution authorization, or live-trading approval is granted.

The previous Sprint 3.2 Patch 1 project remains unchanged and available as the rollback baseline.

Sprint 3.2 Patch 1 changed only these defaults:

```mql5
input bool InpExportTrendRegressionCsv = true;
input bool InpExportMomentumRegressionCsv = true;
```

`InpLogTrendRegression` and `InpLogMomentumRegression` remain `false`.

The original V4.2 source and `SW_FIBO_BASIC_V3.mq5` remain unchanged.

## Status Vocabulary

- **Implemented:** Present in the authorized baseline and compile-verified.
- **Candidate / In Review:** Proposed architecture changes under formal review; not part of the authorized baseline and not Architecture Locked.
- **Merged / Audited / Unlocked:** Present on main after a successful audit and merge, but still awaiting an explicit formal Architecture Lock decision. Production Contract V5 currently has this status.
- **Architecture Locked:** Formally approved architecture baseline. Production Contract V5 does not currently have this status.
- **Evidence pending:** Implemented, but required MT5 runtime artifacts have not been inspected.
- **Deferred by design:** Intentionally outside the current Sprint or Signal Engine boundary.
- **Unauthorized:** Created without an approved Sprint scope and must not be treated as project work.
- **Production-ready:** Must never be claimed from compilation or static analysis alone.

## Completed Sprints

| Sprint | Authorized scope |
|---|---|
| Sprint 1 | Architectural skeleton: Platform Adapter, IndicatorCache, snapshots, engines, orchestrator, DecisionEngine, dashboard, and legacy compatibility. |
| Sprint 1.1 | Typed DTOs, validation, snapshot metadata, engine health, normalized score/confidence contracts, and stronger ownership boundaries. |
| Sprint 2 | Exact V4.2 H1 trend gate and H4 macro-direction migration with independent regression comparison. |
| Sprint 2.1 | Read-only dashboard converted to a framed chart-object overlay. |
| Sprint 2.2 | Configurable panel corner, offsets, font size, and row spacing. |
| Sprint 3 | Isolated V4.2 Momentum evidence migration and independent regression comparison. |
| Sprint 3.1 | Typed regression diagnostics, dashboard auto-height, and default Y offset 150. |
| Sprint 3.2 | Score-semantics closure, centralized validation ownership, Price Action visibility, history/stale producers, and CSV evidence writer. |
| Sprint 3.2 Patch 1 | Trend and Momentum CSV export enabled by default for verification. No runtime logic changed. |
| Sprint 3.2.1 | Nonpositive history-token hardening, explicit fail-closed diagnostics, preserved last-valid baseline, and expanded CSV decision evidence. |
| Sprint 4 Architecture | Isolated production Basket, Persistence, Execution, Risk, Statistics, Instance Ownership, and Unit System contracts. No runtime implementation. |

Sprint 4.1 Contract Hardening and its Sprint 4.2–4.8 corrective verification sequence produced the audited Production Contract V5 package now merged to main. Merge completion does not replace the explicit formal Architecture Lock decision, so V5 remains unlocked.

Sprint 4.2 through Sprint 4.8 are the verification and corrective history behind the merged V5 package. Sprint 4.6 remains failed-candidate history, Sprint 4.7 remains superseded V4 history, and earlier Sprint 4.8 generations remain superseded V5 history. B11.6 is the frozen audited technical source, D5 is its immutable verification authority, E5 is its reproducible evidence package, and the Final Independent Merge Audit is complete. These milestones do not declare Architecture Lock, authorize runtime, authorize production readiness, or replace explicit approval governance. A technical freeze or merge makes source and evidence immutable and available on main; neither constitutes Architecture Lock or formal runtime approval.

## Architecture Boundary

Fusion Pro V5 Sprint 3.2.1 remains the frozen **MT5 Indicator and Signal Engine**.

Fusion Pro V5 Sprint 4.1 is an isolated **production contract hardening layer** based on Sprint 4 Architecture. It defines types, ownership, interfaces, lifecycle rules, deterministic validation requirements, and evidence specifications only. It is not an automated trading system and is not connected to the Signal Engine at runtime.

It is not an automated trading EA.

It does not own:

- Orders or pending orders
- Open positions
- Basket lifecycle
- Recovery
- Trade execution
- Production persistence
- Transaction reconciliation
- `OnTradeTransaction`
- Trade-history statistics
- Execution-instance ownership

These responsibilities belong to a future Execution Layer or separate EA host unless an approved Architecture Decision Record explicitly changes this boundary.

Execution-related contracts may be designed in a future approved Sprint. Execution logic must not be inserted into the indicator merely because it may eventually be useful.

```text
Market / Indicator Data
        ↓
Immutable Snapshot
        ↓
Independent Signal Engines
        ↓
DecisionEngine
        ↓
Signal DTO
        ↓
Future Execution Layer / EA
        ↓
Broker
```

The Dashboard reads DTOs only and remains outside the decision path:

```text
Immutable Snapshot / Engine Results / Decision Result
                         ↓
                  Read-Only Dashboard
```

The current `ExecutionPolicy` name refers to an advisory signal-policy gate inside the indicator. It is not a broker execution adapter and must not be interpreted as one.

## Current Architecture

| Component | Current responsibility |
|---|---|
| Platform Adapter | Owns terminal market, history, session, spread, and stale-data access outside indicator-buffer reads. |
| IndicatorCache | Sole owner of indicator handles and every `CopyBuffer()` call. |
| Market Snapshot | Versioned market data and quality metadata assembled before engine evaluation. |
| Indicator Snapshot | Coherent cached indicator values aligned with the market snapshot. |
| Engine Input | Immutable-by-contract combination of market and indicator snapshots. |
| TrendEngine | Reports exact migrated V4.2 H1 trend direction and H4 macro context. |
| MomentumEngine | Reports isolated body/ATR, RSI, MACD, and Stochastic evidence without final arbitration. |
| PriceActionEngine | Reports state, bias, strength, confidence, and reasons only. |
| LegacyEngineAdapter | Preserves compatible Fibo indicator-buffer evidence. |
| DecisionEngine | Validates inputs/results and exclusively assigns final action. |
| Dashboard | Displays supplied DTO state without calculating or mutating trading information. |
| Regression modules | Independently compare migrated Trend and Momentum behavior with extracted V4.2 formulas. |
| CSV evidence writer | Writes decision-neutral regression rows after evaluation and deduplicates sequence/generation pairs. |

## Important Behavioral State

- Trend standalone score remains `0.0` because V4.2 uses trend as a directional gate.
- Momentum standalone score remains `0.0` because candidate-dependent scoring has not been migrated.
- Price Action has no approved production score contract; the dashboard displays PA score as `--`.
- Fibo fixed score `80` is marked non-comparable with the V4.2 composite threshold.
- A non-comparable Fibo signal fails closed rather than being mislabeled as merely below threshold.
- No complete V5 final decision rule has been migrated.
- Normal output may therefore be `WAIT` or `BLOCKED`.
- This is controlled migration behavior, not evidence of a defective system.

## Architecture Decisions And Rationale

| Decision | Why it exists |
|---|---|
| Snapshots are immutable | Prevents engines from evaluating different data or mutating shared evidence. |
| IndicatorCache owns buffer access | Prevents duplicate handles, inconsistent shifts, and hidden platform dependencies. |
| Engines are independent | Allows each signal domain to be migrated, tested, rejected, or replaced separately. |
| DecisionEngine owns final action | Prevents engines, adapters, dashboards, and policies from issuing conflicting decisions. |
| Dashboard is read-only | Presentation must never influence signal or trading behavior. |
| Regression is decision-neutral | A diagnostic mechanism must not silently become a trading rule. |
| Score semantics are explicit | Numerically similar scores from different models are not automatically comparable. |
| Unmigrated scores remain zero or unavailable | Avoids inventing trading rules during architectural migration. |
| History/stale detection belongs in Platform Adapter | These checks depend on terminal history, sessions, and wall-clock context. |
| Execution remains outside the indicator | Broker-side state requires different ownership, lifecycle, persistence, and reconciliation guarantees. |
| SQLite/MQL5 common-folder store is the Phase D physical candidate | Native transactions, conditional SQL, shared placement, and deterministic readback can model exact one-domain CAS; cross-terminal platform evidence remains mandatory. |
| Genesis uses a separate provisioning authority | Missing persistence is never clean, initial Hard Kill remains active, and runtime cannot self-authorize bootstrap. |
| Legacy compatibility is isolated | Existing evidence can be observed without allowing legacy implementation to control the new architecture. |
| Runtime evidence is separate from compilation | Compile success cannot prove broker behavior, chart lifecycle, historical parity, or transaction correctness. |

## Non-Negotiable Architecture Rules

| ID | Rule | Reason | Violation example | Required enforcement |
|---|---|---|---|---|
| AR-001 | DecisionEngine is the only component allowed to assign BUY, SELL, WAIT, or BLOCKED. | Guarantees one final decision authority. | TrendEngine directly emits BUY. | Static action-assignment search, review, and DecisionEngine tests. |
| AR-002 | No Engine may place, modify, or close trades. | Engines are pure signal-domain evaluators. | MomentumEngine calls `OrderSend`. | Forbidden-API scan in every Engine file. |
| AR-003 | No Engine may call another Engine. | Prevents hidden coupling and evaluation-order dependencies. | PriceActionEngine calls TrendEngine. | Dependency scan and constructor/include review. |
| AR-004 | IndicatorCache is the sole owner of `CopyBuffer()` and indicator handles. | Ensures coherent reads and centralized lifecycle management. | Regression code creates an RSI handle. | Repository-wide `CopyBuffer` and indicator-handle scan. |
| AR-005 | Snapshots and Engine inputs are immutable. | Ensures every Engine evaluates identical evidence. | Engine changes data-quality flags in its input. | Const inputs, DTO review, and mutation scans. |
| AR-006 | Dashboard is permanently read-only. | UI must not become a hidden controller. | Dashboard changes score or sends a trade. | Const DTO parameters and forbidden account/trade API scan. |
| AR-007 | Regression diagnostics must never influence final decisions. | Regression is evidence, not strategy logic. | DecisionEngine blocks because regression status is FAIL. | No regression DTO in DecisionEngine inputs. |
| AR-008 | Platform and broker APIs must remain outside Engines. | Keeps signal logic deterministic and testable. | TrendEngine calls `AccountInfoInteger`. | Platform-API scan of the Engines directory. |
| AR-009 | Execution, Basket, Recovery, Persistence, Statistics, and transaction reconciliation belong outside the Signal Engine. | These require authoritative broker-state ownership. | Indicator manages recovery positions. | Boundary review and separate approved EA architecture. |
| AR-010 | No code from `XAU_Scalper_AI_v17` may be copied into Fusion Pro V5. | v17 contains critical lifecycle, risk, and accounting failures. | Copying its Recovery function. | Source review and provenance declaration. |
| AR-011 | Any v17 concept must be independently validated and tested before adoption. | A useful idea may still be incorrectly implemented or architecturally incompatible. | Reusing adaptive regime scoring without lockout tests. | New specification, independent implementation, and regression fixtures. |
| AR-012 | No implementation may begin without an approved Sprint scope and Definition of Done. | Prevents speculative or unauthorized project changes. | Creating execution interfaces from a context-only request. | Explicit user approval recorded before file modification. |
| AR-013 | Unauthorized experimental folders are not baselines and must never be merged automatically. | Prevents accidental adoption of unreviewed work. | Continuing from `SPRINT4_SAFETY_FOUNDATION`. | Baseline confirmation before every task. |
| AR-014 | Sprint 4 Architecture is the authorized architecture baseline; audited Production Contract V5 is merged to main but remains unlocked; Sprint 3.2.1 is the frozen Signal Engine baseline. | Maintains explicit, non-conflicting governance and ownership boundaries. | Treating the merged V5 contracts as Architecture Locked or implemented execution, or modifying the frozen signal baseline. | State the authorized baseline, merged-unlocked contract status, and frozen Signal Engine before future work. |

## Intentional Current Limitations

The following are intentionally incomplete and must not be reported as accidental omissions:

- No automated execution
- No concrete Basket lifecycle implementation
- No Recovery algorithm
- No concrete transaction coordinator
- No runtime transaction reconciliation
- No concrete production Persistence store
- No concrete authoritative Statistics service
- No concrete duplicate-instance lock store
- No concrete Hard Risk evaluator
- No complete V4.2 composite Decision migration
- No final production Price Action scoring
- No production EA release

Controlled incompleteness is acceptable while the migration remains explicit, testable, and fail-closed.

A limitation becomes a defect only when it violates an approved Sprint specification, an established architecture rule, or claimed behavior.

## Authorized Versus Unauthorized Work

| Status | Work |
|---|---|
| Authorized | Sprint 1 |
| Authorized | Sprint 1.1 |
| Authorized | Sprint 2 |
| Authorized | Sprint 2.1 |
| Authorized | Sprint 2.2 |
| Authorized | Sprint 3 |
| Authorized | Sprint 3.1 |
| Authorized | Sprint 3.2 |
| Authorized | Sprint 3.2 Patch 1 |
| Authorized | Sprint 3.2.1 |
| Authorized | Sprint 4 Architecture |
| Merged / Audited / Unlocked — Formal Architecture Approval Pending | Sprint 4 Production Contract V5 package |
| Architecture Review Gate Closed / PASS | Sprint 5 Phase A.4 Final Policy Admission Linearization Closure at `31e76411829e2f2e6acb24740ddca32b886969e0` |
| Phase B Pure-Contract Gate Closed / PASS | Sprint 5 Phase B.3 at `1366edb25238463c9a76fa78257196dbf4c64e34` |
| Phase C Deterministic Orchestration Gate Closed / PASS | Sprint 5 Phase C.2 at `55cd230ca222c60cd42dd218efe5e175ba70acd6` |
| Authorized — Documentation-Only ADR Resolution | Sprint 5 Phase D0 physical store/CAS/lease-clock and genesis ADRs |
| Phase D Persistence/Restart Gate Closed / PASS | Sprint 5 Phase D at `f0434d0e84907b1d454deec0abb899c16b35cd35` |
| Phase E Integrated Fixture Gate Closed / PASS | Sprint 5 Phase E at `75351935154c57400525e16c4dfceb3103f8c740`, tree `370d4dc7c0caac153efef23521c0c6f66c9be062` |
| Authorized — Profile/Evidence Work Only | Sprint 5 Phase F0 broker/platform profiling and isolated attended-Demo measurement |
| Unauthorized / Experimental | `SPRINT4_SAFETY_FOUNDATION` |

The `SPRINT4_SAFETY_FOUNDATION` folder:

- Was created because of a misunderstanding
- Was not requested
- Was not reviewed or approved
- Is not a baseline
- Must not be merged into Sprint 3.2
- Must not be used as the source for future work
- May be inspected later only as discarded experimental material when explicitly requested by the user

Its existence does not authorize Sprint 4 and does not change the current architecture.

## Baseline Lock Conditions

Sprint 3.2.1 is frozen by explicit user decision. Its remaining runtime evidence limitations remain historical context and do not authorize source changes.

Sprint 4.1 Contract Hardening cannot be locked until review confirms:

- Every required production domain has a typed contract and sole owner
- Basket transitions and invariants are complete and fail-closed
- Persistence cannot override authoritative broker state
- Request acknowledgement cannot confirm basket state
- Risk authorization is separate from execution
- Statistics use authoritative deal history
- Duplicate ownership conflicts halt readiness
- Unit normalization rules are explicit
- Contract versioning and compatibility rules are explicit
- Every contract evaluation receives deterministic time, sequence, and tolerance context
- Accepted ADRs resolve execution boundary, account mode, ownership, confirmation, units, and Hard Kill governance
- Every safety-critical rule has a table-driven validation case
- No runtime execution or recovery algorithm is present
- MetaEditor compilation remains zero errors and zero warnings

Historical Sprint 3.2.1 evidence topics included:

- XAUUSD M15 runtime verification during an active market
- Trend regression CSV review
- Momentum regression CSV review
- Closed-bar behavior
- Every-tick behavior
- History continuity behavior
- Stale-data behavior
- Journal checks
- Experts checks
- Dashboard resize and object lifecycle
- Indicator remove/reload
- Terminal or chart restart behavior
- Timeframe switching
- Evidence recording with terminal build, broker/server, symbol, inputs, date, and timezone

User-reported tests may be recorded as performed, but they remain **evidence pending** until screenshots, CSV files, Journal/Experts exports, or equivalent inspectable artifacts exist.

The expected CSV files are:

- `SWV5_SPRINT3_2_1_TREND_REGRESSION.csv`
- `SWV5_SPRINT3_2_1_MOMENTUM_REGRESSION.csv`

CSV generation is enabled by default in Patch 1. Experts-log regression output remains disabled by default.

## Remaining Technical Limitations In Sprint 3.2

- `Bars()` history generation cannot detect every same-count broker history correction.
- A legitimate bulk history load may resemble a discontinuity.
- Broker session metadata may be missing or imperfect.
- Missing session metadata suppresses stale blocking conservatively.
- Result validators still mutate failed result headers inside DecisionEngine.
- Regression oracles are independently coded extracted formulas, not external golden datasets.
- Per-snapshot regression PASS does not prove full historical equivalence.
- Candidate-direction scoring, macro penalties, confirmation additions, and final V4.2 arbitration remain unmigrated.

## Sprint 4 Authorization And Post-Merge V5 State

Sprint 4 Architecture is explicitly authorized as an isolated production-contract project.

Sprint 4.1 hardening and Sprint 4.2–4.8 verification produced the audited Production Contract V5 package now merged to main. The package remains unlocked pending an explicit formal Architecture Lock decision and does not replace the Sprint 4 authorized baseline through merge alone. It does not authorize broker execution, runtime wiring, or concrete production services.

Merged audited contract scope:

- Basket lifecycle states, transitions, and invariants
- Versioned persistence and restart reconciliation contracts
- Request, result-retcode, transaction-confirmation, and retry contracts
- Account, basket, exposure, equity, daily loss, Hard Kill, and aggregate exposure risk contracts
- Basket identity, cumulative recovery-attempt, layer, residual, partial-close, and close-verification contracts
- Authoritative deal-history statistics contracts
- Duplicate-instance ownership, heartbeat, lease, recovery, and conflict contracts
- Point, tick, pip, price, volume, step, tick-value, stops-level, freeze-level, and normalization contracts

The authorization does not include concrete runtime behavior, broker integration, persistence stores, lock stores, recovery algorithms, basket execution, or Signal-to-Execution wiring.

The complete contract specification is `FusionProV5_Sprint4_Production_Architecture.md`. Future implementation requires a separate approved Sprint with adapters, test fixtures, failure policy, and Definition of Done.

## Production Lessons From XAU_Scalper_AI_v17

No v17 source code may be reproduced or copied. The audit is used only to identify failure patterns.

### Signal Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| Signal and regime logic were coupled to mutable trading state. | Signal behavior can change because of execution outcomes or stale basket state. | Not currently; Fusion engines are independent. Risk returns if v17 concepts are adopted. | Regime and Signal concepts must consume immutable snapshots and emit DTO evidence only. |
| Adaptive scoring could permanently suppress strategies after one loss. | A transient outcome can create irreversible self-disable behavior. | No equivalent production logic exists now. | Adaptation requires bounded updates, recovery behavior, persistence tests, and explicit reset semantics. |
| Some concepts relied on current forming bars. | Signals can repaint or change before bar close. | Fusion supports explicit closed-bar/every-tick modes. | Every migrated rule must declare source shifts and receive regression coverage for both modes. |

### Execution Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| No authoritative `OnTradeTransaction` confirmation. | A successful request does not prove the intended position state exists. | Not currently because Fusion has no execution. | Future EA must reconcile request results with transaction events. |
| Command retcodes were not consistently validated. | Rejected, partial, or broker-modified requests may be treated as successful. | Not currently. | Every command requires classified `ResultRetcode` handling and confirmed state transition. |
| Failed close operations could still reset basket state. | Residual positions become unmanaged. | Not currently. | State cannot reset until authoritative reconciliation confirms zero residual exposure. |

### Risk Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| Stop Loss was absent and hard guards were disabled by default. | Loss can become unbounded before discretionary logic reacts. | Not currently because there are no trades. | Future execution requires fail-closed hard risk limits before activation. |
| Account-level and strategy-level risk were mixed. | One strategy can consume or misinterpret account-wide capacity. | Future risk only. | Separate account risk, strategy risk, basket risk, and command validation. |

### Basket And Recovery Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| Netting position count was treated as Recovery layer count. | Netting collapses layers into one position, allowing incorrect or unlimited attempts. | Not currently. | Account mode must be explicitly supported or rejected by a mode-specific basket model. |
| Recovery limits counted open positions instead of cumulative attempts. | Closing or merging positions can reset the apparent limit. | Not currently. | Persist a monotonic cumulative attempt counter per basket. |
| Partial close was treated as complete basket closure. | Remaining exposure becomes orphaned. | Not currently. | Basket completion requires confirmed zero residual volume. |

### Persistence And Restart Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| Persisted state was not reliably reconciled with broker state. | Restart can duplicate, abandon, or misclassify exposure. | Not currently because Fusion owns no trades. | Use versioned persistence and reconcile positions, orders, and history before resuming. |
| Runtime state depended heavily on globals. | State can disappear or become contradictory after reload. | Signal snapshots are rebuilt safely; future execution remains exposed. | Execution state must be versioned, validated, and reconstructable. |

For the unlocked Production Contract V5 architecture now merged to main, restart query evidence is an independently authoritative nested snapshot. Broker Adapter owns positions, orders, deals, and transactions query completion; Execution owns pending-request query completion. Each snapshot has its own observation time, sequence, component/source provenance, stable identity, and canonical digest. Persistence owns separate prior-accepted Broker-query and Execution-query sequence high-watermarks. A restart query must be no older than 60 seconds under the explicit validation clock, must not postdate its enclosing authority summary, and must advance beyond its matching persisted high-watermark. Wrapper freshness, transaction sequence, request-set revision, and reconciliation revision are not substitutes for query freshness or query anti-replay authority.

### Statistics Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| Partial closes and basket completion were misattributed. | Win/loss and adaptive metrics become false. | Fusion has no trade statistics. | Calculate statistics from authoritative deal history with basket attribution. |
| Commission, swap, and fee were not reliably included. | Reported profitability differs from actual account results. | Not currently. | Net results must include profit, commission, swap, and fee from deals. |

### Broker And Unit Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| Point, pip, tick size, and price distance were not consistently separated. | Prices and stops become wrong across symbols or brokers. | Signal calculations remain exposed only where units are assumed; no order risk yet. | Use symbol-native tick size, point, digits, and monetary tick value explicitly. |
| Volume step and broker limits were not consistently normalized. | Requests can be rejected or exceed intended risk. | Not currently. | Validate min/max/step and normalize volume before every future command. |
| Stops and freeze levels were not comprehensively enforced. | Modification or close requests can fail unexpectedly. | Not currently. | Future execution preflight must validate stops level, freeze level, trade mode, and filling mode. |

### Operational Lessons

| Failure observed in v17 | Why dangerous | Applies to current Fusion V5 | Future prevention rule |
|---|---|---|---|
| Multiple instances could manage the same basket. | Duplicate recovery, closing, or state resets can occur. | Signal indicator instances are read-only; future execution would be exposed. | Future EA requires atomic ownership keyed by account, server, symbol, strategy, and magic. |
| Architecture was monolithic and globally coupled. | Local fixes create unrelated regressions and make testing unreliable. | Fusion currently avoids this through boundaries. | Preserve adapters, immutable DTOs, independent engines, central decision authority, and separate execution ownership. |

## Risks Fusion V5 Must Continue To Avoid

- Treating the unauthorized Sprint 4 folder as valid work
- Converting recommendations into implementation without approval
- Adding execution behavior to the indicator by assumption
- Mixing broker state into Signal Engines
- Allowing Engines to assign final actions
- Allowing regression results to block or generate signals
- Comparing scores with incompatible semantics
- Inventing scores for intentionally unmigrated logic
- Claiming historical equivalence from same-snapshot comparisons
- Claiming runtime verification without inspectable evidence
- Supporting Netting or Hedging implicitly
- Enabling Recovery before state, persistence, reconciliation, and hard risk are proven
- Resetting lifecycle state before residual exposure is confirmed absent
- Reusing v17 code because a concept appears familiar
- Weakening Fusion architecture to imitate v17 behavior

## Open Design Questions

- Which V4.2 domain should be migrated next?
- What exact later cross-terminal evidence will be required for the approved ADR-021 SQLite/clock candidate?
- Which broker-specific retcode mapping tables and transaction-order fixtures are required before adapter work?
- What external datasets qualify as golden regression fixtures?
- What score model will eventually replace or reproduce the V4.2 composite model?
- How should final Price Action scoring be specified?
- What evidence threshold is required to lock each Sprint?
- Should result validation become completely non-mutating?
- Should history generation move beyond the current `Bars()` token?
- What review authority and evidence threshold will accept future Architecture Decision Record changes?
- Which exact files may be modified in the next Sprint?

## Future Recommendations

These are recommendations only and are not authorized implementation:

1. Preserve the closed Sprint 5 Architecture, Phase B, and Phase C gates, and separately decide Architecture Lock for the audited Production Contract V5 package.
2. Preserve the approved Phase D0 store/genesis decisions while implementing only the authorized fake-store/fake-clock Phase D reference.
3. Require an approved scope, file list, exclusions, rollback point, failure tests, and Definition of Done.
4. Keep any future Execution Layer runtime physically and logically separate until the Sprint 5 Phase B pure contracts are independently audited and accepted.
5. Evaluate v17 Regime Detection, Signal Logic, and Dashboard concepts only through independent specifications and tests.
6. Build external golden fixtures before claiming full V4.2 migration parity.
7. Introduce Basket, Recovery, Risk, Persistence, and transaction work only after the Execution boundary is formally approved.

A provisional risk-oriented order, requiring separate approval at every step, would be:

1. Formally approve or reject Architecture Lock for the audited V5 contracts.
2. Complete remaining Signal Engine migrations or explicitly close their scope.
3. Complete and independently audit the authorized fake-platform/fake-store Phase D reference implementation against the approved lifecycle, persistence, reconciliation, ownership, and risk contracts.
4. Require separate later authorization and real-platform evidence before any physical SQLite, clock, broker, or runtime integration.
5. Implement and test any separately authorized broker execution in Strategy Tester and demo only.
6. Add basket lifecycle before Recovery.
7. Add bounded Recovery only after fault testing.
8. Build authoritative statistics from deal history.
9. Consider production release only after broker-specific evidence and separate authorization.

## Master Context Usage Instructions

Before performing any future work, every AI agent must:

1. Read this Master Context completely.
2. Confirm that Sprint 4 Architecture is the authorized architecture baseline, audited Production Contract V5 is merged to main but remains unlocked, and Sprint 3.2.1 is the frozen Signal Engine baseline.
3. Ignore `SPRINT4_SAFETY_FOUNDATION` unless the user explicitly requests inspection of discarded experimental material.
4. Classify the request as documentation, design, audit, runtime verification, or implementation.
5. Confirm the approved Sprint scope and Definition of Done before implementation.
6. Ask for explicit approval when Sprint scope or architecture boundaries are ambiguous.
7. Never create files merely because implementation may be useful.
8. Never modify the frozen baseline unless explicitly instructed.
9. Never copy code from `XAU_Scalper_AI_v17`.
10. Never mix Signal Engine responsibilities with future Execution Layer responsibilities.
11. Report uncertainty and unresolved decisions instead of inventing architecture.
12. Distinguish implemented, deferred, evidence-pending, and unauthorized work.
13. Keep recommendations separate from authorized actions.
14. Re-read the newest user instruction before editing, compiling, or creating artifacts.
15. Report exact files intended for modification before making approved changes.

## Next Authorized Action

"Complete only Sprint 5 Phase F0 broker-profile/evidence work. Attended Demo probes must remain isolated, operator-triggered, minimal, and test-only. Phase F implementation, a production Broker Adapter, unattended Demo, live/real-money accounts, production VPS, Phase G, Architecture Lock, main merge, production/runtime, and production readiness remain unauthorized or prohibited."
