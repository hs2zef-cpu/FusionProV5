# Phase F Broker Adapter Traceability Matrix

| Requirement | Implementation boundary | Test IDs |
|---|---|---|
| Current ephemeral Claim only | `AdapterValidatePreflight`, `SubmitExactlyOnce` | BA-001, MC-CLAIM-FABRICATION |
| Exact profile and permissions | platform `CaptureEnvironment`, pure preflight | BA-002–006, MC-PREFLIGHT-BYPASS |
| Bound payload, runtime Magic, filling | pure preflight and single request construction | BA-007–008 |
| Complete synchronous capture; never confirmation | `AdapterSyncResult`, `AdapterClassifySync` | BA-009, BA-012–014, BA-035–040, MC-SYNC-AS-CONFIRMATION |
| Callback observational only | `CaptureCallback` plus evidence-store interface | BA-010–011, MC-CALLBACK-AS-CONFIRMATION |
| Durable Broker enumeration/bookkeeping | `QueryAuthoritativeBrokerDomains` | BA-015, BA-021, BA-034, MC-INCOMPLETE-AS-EMPTY |
| Independent Execution pending path | `AdapterBuildExecutionPendingSnapshot` | BA-025, MC-SHARED-EVIDENCE-SOURCE |
| Ordered positive correlation | `AdapterBuildPositiveEvidence` | BA-016–018, BA-033, MC-MAGIC-COMMENT-SOLE |
| Partial residual is non-authority | accepted evaluator delegation | BA-017, MC-RESIDUAL-AUTHORITY |
| Negative proof prerequisites | snapshot projection plus accepted evaluator | BA-021–026 |
| Execution-store-only NO_CALL | accepted evaluator, no Broker construction path | BA-019–020 |
| Terminal monotonicity | accepted evaluator delegation | BA-030–032, MC-TERMINAL-REGRESSION |
| Lease/fence/revision CAS publication | `AdapterValidatePublication`, publication authority interface | BA-027–028, MC-STALE-CAS-EQUALITY |
| No retry | all result/callback DTOs and accepted evaluator | all 40 cases, MC-AUTO-RETRY |
| Platform isolation | exclusive platform boundary and source verifier | source checks |
