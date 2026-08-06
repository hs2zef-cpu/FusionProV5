# Sprint 4.3 Interface Coverage Matrix

> TEST ONLY - NOT FOR PRODUCTION - NO BROKER ACCESS

| Production interface | Implemented test methods | Direct executable coverage |
|---|---|---|
| `ISWV5ContractVersionPolicy` | `EvaluateCompatibility` | COM-01–COM-03, COM-10–COM-11 |
| `ISWV5BasketStateMachineContract` | `ValidateState`, `ValidateTransition` | BSM-01–BSM-49, BAS-02, IFC-01–IFC-03, IFC-30–IFC-31 |
| `ISWV5BasketContract` | `ValidateAggregate`, `ValidatePartialClose`, `ValidateCloseCompletion` | BAS-01, BAS-03, BAS-05–BAS-08, XDM-12 |
| `ISWV5ExecutionContract` | `ValidateIntent`, `ValidatePhaseTransition`, `ClassifyResultRetcode`, `AcceptTransactionEvidence`, `EvaluateRetry` | EXE-01–EXE-16, XDM-01–XDM-02, XDM-07, IFC-04–IFC-06, IFC-24–IFC-27, IFC-32 |
| `ISWV5PersistenceContract` | `ValidateRecord`, `LoadLatest`, `LoadPendingRequests`, `SavePendingRequests`, `SaveCheckpoint`, `ReconcileRestart` | PER-01–PER-15, XDM-01, XDM-03, XDM-08, XDM-11, IFC-07–IFC-08, IFC-28, IFC-33–IFC-36, PRT-01–PRT-11 |
| `ISWV5RiskContract` | `ValidateLimits`, `Evaluate`, `ValidateAuthorization`, `ValidateHardKillRelease` | RSK-01–RSK-16, XDM-01, XDM-05–XDM-06, XDM-09–XDM-10, IFC-09–IFC-13, IFC-22–IFC-23, IFC-37 |
| `ISWV5StatisticsContract` | `ValidateDeal`, `AccumulateDeal`, `Finalize` | STA-01–STA-13, IFC-29, IFC-38 |
| `ISWV5InstanceOwnershipContract` | `Acquire`, `Heartbeat`, `DetectConflict`, `Release` | OWN-01–OWN-11, IFC-19–IFC-21, IFC-39–IFC-40 |
| `ISWV5UnitSystemContract` | `ValidateSpecification`, `Normalize` | UNT-01–UNT-10, XDM-01, XDM-05, IFC-14–IFC-18 |

All concrete classes are marked TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS. Compilation enforces signature conformance to the production interfaces.
