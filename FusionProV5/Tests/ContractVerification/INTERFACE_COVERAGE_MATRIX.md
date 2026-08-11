# Sprint 4.6 Phase E1 V4 Candidate Interface Coverage Matrix

> TEST ONLY - NOT FOR PRODUCTION - NO BROKER ACCESS

| Production interface | Test-only methods exercised | Direct executable coverage |
|---|---|---|
| `ISWV5ContractVersionPolicy` | `EvaluateCompatibility` | COM-01–COM-03, COM-10–COM-11 |
| `ISWV5BasketStateMachineContract` | `ValidateState`, `ValidateTransition` | COM-04–COM-06, COM-12, BSM-01–BSM-49, BAS-02, IFC-01–IFC-03, IFC-30–IFC-31, S44-16, S45BR-01–S45BR-10 |
| `ISWV5BasketContract` | `ValidateAggregate`, `ValidatePartialClose`, `ValidateCloseCompletion` | BAS-01, BAS-03–BAS-08, XDM-04, XDM-12 |
| `ISWV5ExecutionContract` | `ValidateIntent`, `ValidatePhaseTransition`, `ClassifyResultRetcode`, `AcceptTransactionEvidence`, `EvaluateRetry` | EXE-01–EXE-16, XDM-01–XDM-02, XDM-07, XDM-11, IFC-04–IFC-06, IFC-24–IFC-27, IFC-32, S44-17–S44-18, S45A-01–S45A-10, S45F-01–S45F-02, S46AE-01–S46AE-42, S46DR-01–S46DR-20 |
| `ISWV5PersistenceContract` | `ValidateRecord`, `Configure`, `LoadLatest`, `LoadPendingRequests`, `SavePendingRequests`, `SaveCheckpoint`, `ReconcileRestart` | PER-01–PER-15, XDM-01, XDM-03, XDM-08, XDM-11, IFC-07–IFC-08, IFC-28, IFC-33–IFC-36, PRT-01–PRT-11, S44-01–S44-11, S45BR-10, S45F-02, S45DP-08–S45DP-12, S45DP-15–S45DP-16, S46CP-01–S46CP-20, S46EI-15 |
| `ISWV5RiskContract` | `ValidateLimits`, `Evaluate`, `ValidateAuthorization`, `ValidateHardKillRelease` | RSK-01–RSK-16, XDM-01, XDM-05–XDM-06, XDM-09–XDM-10, IFC-09–IFC-13, IFC-22–IFC-23, IFC-37, S44-12–S44-15, S45CR-01–S45CR-29, S45DO-32–S45DO-33, S46BR-01–S46BR-31, S46BH-01–S46BH-40 |
| `ISWV5StatisticsContract` | `ValidateDeal`, `AccumulateDeal`, `Finalize` | STA-01–STA-13, IFC-29, IFC-38, S44-19–S44-20 |
| `ISWV5InstanceOwnershipContract` | `Acquire`, `Heartbeat`, `DetectConflict`, `Release` | COM-09, OWN-01–OWN-11, IFC-19–IFC-21, IFC-39–IFC-40, S44-21–S44-25, S45BO-01–S45BO-10, S45DO-01–S45DO-33 |
| `ISWV5UnitSystemContract` | `ValidateSpecification`, `Normalize` | UNT-01–UNT-10, XDM-01, XDM-05, IFC-14–IFC-18, S45CU-01–S45CU-20 |

Phase E1 direct coverage adds persistence `ValidateRecord`, `SaveCheckpoint`, `Configure`, and `LoadLatest` cases `S46E1-16` through `S46E1-18`, Statistics `AccumulateDeal` case `S46E1-19`, and Execution `AcceptTransactionEvidence` case `S46E1-20`. The pure canonical integrity, classification, and append reference path is covered by `S46E1-01` through `S46E1-15`.

The concrete implementations are deterministic in-memory test doubles marked `TEST ONLY`, `NOT FOR PRODUCTION`, and `NO BROKER ACCESS`. Interface compilation proves signature conformance; behavioral credibility is assessed separately in `TEST_CREDIBILITY_MATRIX.md`.
