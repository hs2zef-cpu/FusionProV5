# Phase F Broker Adapter Traceability Matrix

| Requirement | Implementation boundary | Test IDs |
|---|---|---|
| Current ephemeral Claim only | `AdapterValidatePreflight`, `SubmitExactlyOnce` | BA-001, MQL-PREFLIGHT-01–04, MC-CLAIM-FABRICATION |
| Exact profile and permissions | platform `CaptureEnvironment`, pure preflight | BA-002–006, MQL-PREFLIGHT-05–10, MC-PREFLIGHT-BYPASS |
| Bound payload, runtime Magic, exact one-to-one filling | pure preflight and single request construction | BA-007–008, BA-043, MQL-PREFLIGHT-11–15, MQL-FILL-01–04, MC-FILLING-COERCION |
| Final permission/profile/specification sample | `CaptureEnvironment`, `AdapterValidateFinalEnvironment` | BA-041, MQL-TOCTOU-01–03, MC-TOCTOU-WINDOW |
| Final wire-ready request digest; no later mutation | `CaptureWireRequest`, `DeriveAdapterWirePayloadDigest` | BA-042, MQL-WIRE-01–02, MC-POSTDIGEST-NORMALIZE |
| Symbol-derived numeric and market/SL/TP semantics | canonical-grid and market-protection validators | MQL-GRID-01–05, MQL-PRICE-01–04 |
| Complete synchronous capture; never confirmation | `AdapterSyncResult`, `AdapterClassifySync` | BA-009, BA-012–014, BA-035–040, MQL-SYNC-01–05, MC-SYNC-AS-CONFIRMATION |
| Callback observational only | `CaptureCallback` plus evidence-store interface | BA-010–011, MC-CALLBACK-AS-CONFIRMATION |
| Durable Broker enumeration/bookkeeping | `QueryAuthoritativeBrokerDomains` | BA-015, BA-021, BA-034, BA-045, MQL-QUERY-01–02, MC-INCOMPLETE-AS-EMPTY, MC-QUERY-ROW-OMISSION |
| Capability proof is externally authored | consumed proof digest only; no adapter authoring interface | BA-021, BA-044, MC-CAPABILITY-SELFATTEST, MC-ADAPTER-SELFATTEST |
| Independent Execution pending path | `AdapterBuildExecutionPendingSnapshot` | BA-025, MQL-EVIDENCE-01–02, MC-SHARED-EVIDENCE-SOURCE |
| Ordered positive correlation | `AdapterBuildPositiveEvidence` | BA-016–018, BA-033, MC-MAGIC-COMMENT-SOLE |
| Partial residual is non-authority | accepted evaluator delegation | BA-017, MQL-RECON-01, MC-RESIDUAL-AUTHORITY |
| Negative proof prerequisites | snapshot projection plus accepted evaluator | BA-021–026 |
| Execution-store-only NO_CALL | accepted evaluator, no Broker construction path | BA-019–020 |
| Terminal monotonicity | accepted evaluator delegation | BA-030–032, MQL-RECON-02–03, MC-TERMINAL-REGRESSION |
| Lease/fence/revision CAS publication | `AdapterValidatePublication`, publication authority interface | BA-027–028, MC-STALE-CAS-EQUALITY |
| No retry and exactly one source send site | one-shot adapter plus source-shape verifier | all 45 cases, MC-AUTO-RETRY, source checks |
| Platform isolation | exclusive platform boundary and source verifier | source checks |
