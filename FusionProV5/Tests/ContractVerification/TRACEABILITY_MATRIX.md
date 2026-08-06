# Sprint 4.3 Contract Verification Traceability Matrix

> TEST ONLY - NOT FOR PRODUCTION - NO BROKER ACCESS

| Requirement | Contract field/interface | Implementation under test | Test IDs | Expected result |
|---|---|---|---|---|
| All 49 Basket pairs and version rules | state pair, cause, expected/resulting version | `SWV5_TestBasketStateContract::ValidateTransition` | BSM-01–BSM-49 | Allowed +1; same/forbidden stable |
| IDLE and close invariants | residual, live positions/orders/pending, queries | `SWV5_TestBasketContract::ValidateCloseCompletion` | BAS-06, XDM-12 | Residual or incomplete evidence rejects completion |
| Recovery monotonicity | `recovery_evidence`, accepted index, resulting attempt/layer/version | Basket state interface | IFC-01–IFC-03 | Exact +1; regression/duplicate rejected |
| Phase identity | request identity, broker identity, lifecycle phase | `SWV5_TestExecutionContract::ValidateIntent/ValidatePhaseTransition` | IFC-04–IFC-06 | No future IDs; no acknowledgement-to-completed jump |
| Acknowledgement boundary | retcode evidence, cumulative confirmation | Execution interface | EXE-02–EXE-03, EXE-16, IFC-26 | Acknowledgement leaves confirmed volume unchanged |
| Partial fill/residual | cumulative confirmed and residual volume | `AcceptTransactionEvidence` | EXE-11, IFC-27, XDM-12 | Partial status; residual remains managed |
| Durable duplicate/out-of-order | canonical identity index, digest, revision, transaction sequence | Execution/Statistics interfaces | IFC-24–IFC-25, IFC-29 | Known event idempotent; unseen older event accepted once |
| Restart reconstruction | pending DTO, request-set header, readiness disposition | `SWV5_TestPersistenceContract::ReconcileRestart` | PER-05–PER-15, IFC-07–IFC-08 | Exactly one safe/reconcile/retry-forbidden/close-only/halted disposition |
| Pending-request persistence round trip | full persisted request payload, set header, namespace, digest, revision | `SWV5_TestPersistenceContract::Configure/SavePendingRequests/LoadPendingRequests` | PRT-01–PRT-11 | Every field and record order survives deep-copy round trip; foreign/corrupt/unconfigured storage fails closed |
| Account namespace and epoch | broker, server, login, currency, strategy, Magic, authority, epoch | `SWV5_TestRiskContract::Evaluate` | IFC-09–IFC-11 | Mixed identity or epoch rejected |
| Account mode binding | intent, Risk input/auth, pending, persisted request, broker summary | Execution/Risk/Persistence interfaces | IFC-12–IFC-13, IFC-28 | Netting/Unknown/change invalidates readiness |
| Typed takeover | typed broker/store/lease evidence, observed revision, generation, authority | `SWV5_TestOwnershipContract::Acquire` | IFC-19–IFC-21 | Valid independent evidence accepts; stale/self-issued rejects |
| Typed Hard Kill release | approver, broker/store/exposure evidence, expiry/generation/audit | `SWV5_TestRiskContract::ValidateHardKillRelease` | IFC-22–IFC-23, XDM-10 | Independent complete release accepts; execution self-approval rejects |
| Unit safety | operation kind/price, direction, freshness, applied rounding | `SWV5_TestUnitSystemContract::Normalize` | UNT-01–UNT-10, IFC-14–IFC-18 | Wrong side/freeze/stale reject; increase down; residual close broker-safe |
| Risk authorization binding | request identity, fence, namespace, mode, Basket/spec/epoch/terms/expiry | `ValidateAuthorization` | RSK-02–RSK-16 | Any binding change rejects |
| Statistics monetary completeness | profit, commission, swap, fee, currency, durable identity | Statistics interface | STA-01–STA-13, IFC-29 | Net includes all components; duplicate does not double count |
| Determinism | complete input/context and decision DTO | All interfaces | COM-05, IFC-30, PRT-09 and two complete runs | Identical counts, outputs, persisted payloads, and signature |

The production headers define interfaces only. `SW_V5_InterfaceContractImplementations.mqh` is the explicit test-only implementation under test; `SW_V5_ReferenceValidators.mqh` contains pure rules invoked behind those interfaces.
