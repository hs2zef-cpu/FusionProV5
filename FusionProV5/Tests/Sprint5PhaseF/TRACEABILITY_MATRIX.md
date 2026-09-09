# Sprint 5 Phase F Entry Traceability

| Requirement | Contract element | Tests |
|---|---|---|
| Claim is uncertainty boundary | `ReconciliationBinding`, `SUBMISSION_UNRESOLVED` | F-002..F-006, F-013..F-018 |
| Positive durable evidence and complete ordered deal set | `TargetedPositiveEvidence` | F-008, F-011, F-028..F-029 |
| Magic/comment not sole authority; policy independently approved | correlation policy/digest | F-007, F-027 |
| Authoritative negative evidence | `NegativeEvidencePolicy`, two observations | F-005, F-009, F-018 |
| Restart/takeover monotonicity | Claim fence plus current lease | F-006, F-010, F-018 |
| Partial effect safety | requested/confirmed/residual volume | F-011 |
| Claim compatibility | positive evidence requires claim identity/digest | F-012 |
| Terminal idempotence and frozen-state/volume consistency | terminal replay branch | F-019..F-021, F-025..F-026 |
