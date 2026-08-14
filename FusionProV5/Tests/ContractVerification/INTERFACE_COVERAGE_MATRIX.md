# Sprint 4.8 Phase B10 V5 Candidate Interface Coverage Matrix

> TEST ONLY - NOT FOR PRODUCTION - NO BROKER ACCESS

| Production interface | Test-only methods exercised | Direct executable coverage |
|---|---|---|
| `ISWV5ContractVersionPolicy` | `EvaluateCompatibility` | COM-01–COM-03, COM-10–COM-11 |
| `ISWV5BasketStateMachineContract` | `ValidateState`, `ValidateTransition` | COM-04–COM-06, COM-12, BSM-01–BSM-49, BAS-02, IFC-01–IFC-03, IFC-30–IFC-31, S44-16, S45BR-01–S45BR-10 |
| `ISWV5BasketContract` | `ValidateAggregate`, `ValidatePartialClose`, `ValidateCloseCompletion` | BAS-01, BAS-03–BAS-08, XDM-04, XDM-12 |
| `ISWV5ExecutionContract` | `ValidateIntent`, `ValidatePhaseTransition`, `ClassifyResultRetcode`, `AcceptTransactionEvidence`, `EvaluateRetry` | EXE-01–EXE-16, XDM-01–XDM-02, XDM-07, XDM-11, IFC-04–IFC-06, IFC-24–IFC-27, IFC-32, S44-17–S44-18, S45A-01–S45A-10, S45F-01–S45F-02, S46AE-01–S46AE-42, S46DR-01–S46DR-20 |
| `ISWV5PersistenceContract` | `ValidateRecord`, `Configure`, `LoadLatest`, `LoadPendingRequests`, `SavePendingRequests`, `SaveCheckpoint`, `ReconcileRestart`, `PublishRestartQueryWatermarks` | PER-01–PER-15, XDM-01, XDM-03, XDM-08, XDM-11, IFC-07–IFC-08, IFC-28, IFC-33–IFC-36, PRT-01–PRT-11, S44-01–S44-11, S45BR-10, S45F-02, S45DP-08–S45DP-12, S45DP-15–S45DP-16, S46CP-01–S46CP-20, S46EI-15, S48-QPUB-01–S48-QPUB-12 |
| `ISWV5RiskContract` | `ValidateLimits`, `Evaluate`, `ValidateAuthorization`, `ValidateHardKillRelease` | RSK-01–RSK-16, XDM-01, XDM-05–XDM-06, XDM-09–XDM-10, IFC-09–IFC-13, IFC-22–IFC-23, IFC-37, S44-12–S44-15, S45CR-01–S45CR-29, S45DO-32–S45DO-33, S46BR-01–S46BR-31, S46BH-01–S46BH-40 |
| `ISWV5StatisticsContract` | `ValidateDeal`, `AccumulateDeal`, `Finalize` | STA-01–STA-13, IFC-29, IFC-38, S44-19–S44-20 |
| `ISWV5InstanceOwnershipContract` | `Acquire`, `Heartbeat`, `DetectConflict`, `Release` | COM-09, OWN-01–OWN-11, IFC-19–IFC-21, IFC-39–IFC-40, S44-21–S44-25, S45BO-01–S45BO-10, S45DO-01–S45DO-33 |
| `ISWV5UnitSystemContract` | `ValidateSpecification`, `Normalize` | UNT-01–UNT-10, XDM-01, XDM-05, IFC-14–IFC-18, S45CU-01–S45CU-20 |

Phase E1 direct coverage adds persistence `ValidateRecord`, `SaveCheckpoint`, `Configure`, and `LoadLatest` cases `S46E1-16` through `S46E1-18`, Statistics `AccumulateDeal` case `S46E1-19`, and Execution `AcceptTransactionEvidence` case `S46E1-20`. The pure canonical integrity, classification, and append reference path is covered by `S46E1-01` through `S46E1-15`.

The concrete implementations are deterministic in-memory test doubles marked `TEST ONLY`, `NOT FOR PRODUCTION`, and `NO BROKER ACCESS`. Interface compilation proves signature conformance; behavioral credibility is assessed separately in `TEST_CREDIBILITY_MATRIX.md`.

## Sprint 4.7 Phase A additions

- `ISWV5RiskContract.Evaluate`: S47-RISK-01 through S47-RISK-18 and S47-NUM-01 through S47-NUM-11.
- `ISWV5RiskContract.ValidateHardKillRelease`: S47-HK-01 through S47-HK-07.
- `ISWV5ExecutionContract.AcceptTransactionEvidence`: S47-NUM-12 through S47-NUM-17.
- `ISWV5ExecutionContract.EvaluateRetry`: S47-RETRY-01 through S47-RETRY-12.
- `ISWV5PersistenceContract.SavePendingRequests`: S47-NUM-18.
- `ISWV5PersistenceContract.ValidateRecord` and `ReconcileRestart`: S47-CHK-01 through S47-CHK-18.

These cases prove the public test-only implementations against causal projection, non-finite, exclusive-expiry, resealed-semantic-corruption, and invalid-enum adversaries.

## Sprint 4.8 Phase B5 V5 additions

- `ISWV5RiskContract.Evaluate` and its canonical reference validation: S48-MARGIN-01 through S48-MARGIN-15, S48-LOSS-01 through S48-LOSS-15, and S48-NOTIONAL-01 through S48-NOTIONAL-10.
- `ISWV5PersistenceContract.ReconcileRestart`: S48-RST-01 through S48-RST-20 and S48-HKA-*.
- `ISWV5RiskContract.ValidateHardKillRelease` plus independent release-authority validation: S48-HKR-* and S48-HKA-*.
- The test-only decoder does not add a production interface. S48-RT-V5-01 through V5-07 reconstruct the seven required DTOs from canonical strings; S48-RT-NEG-01 through NEG-11 enforce parser failure boundaries.
- S48-CAN-* verifies canonical-field coverage as supporting pure-function evidence. S48-META-01 verifies machine identity against the compiled V5 constants.

## Sprint 4.8 Phase B6 additions

- `ISWV5RiskContract.Evaluate`: S48-MAUTH-01 through S48-MAUTH-15 and S48-BAUTH-01 through S48-BAUTH-15 verify independently supplied Broker Margin and Risk Governance authority boundaries.
- `ISWV5PersistenceContract.SavePendingRequests`, `LoadLatest`, and `LoadPendingRequests`: S48-PAT-01 through S48-PAT-12 verify successful and failed replacement atomicity.
- Every active test-only implementation `ContractName()`: S48-ID-01 through S48-ID-09; S48-ID-10 through S48-ID-12 cover result, serializer, suite and decoder identities.

## Sprint 4.8 Phase B7 additions

- `ISWV5PersistenceContract.ReconcileRestart`: S48-RFULL-01 through S48-RFULL-20 materially cover the complete independently owned Broker Adapter exposure vector and Execution pending-request/reconciliation-authority vector.
- The test-only decoder adds S48-RT-V5-15 for reconstructive round trip of `SWV5_AuthoritativeRestartRequestSummary`; S48-CAN-DTO-10 proves all its fields are digest-bound.

## Sprint 4.8 Phase B8 additions

- `ISWV5PersistenceContract.ReconcileRestart`: S48-QRY-01 through S48-QRY-10 prove the V5 contract - not the caller - defines exact Broker and Execution masks whose union covers all five required query domains.
- `ISWV5PersistenceContract.ReconcileRestart`: S48-RAUTH-01 through S48-RAUTH-04 separately enforce the Execution issuer and Execution/Pending-Request authority source.
- `ISWV5PersistenceContract.ReconcileRestart`: S48-FRESH-01 through S48-FRESH-10 enforce deterministic 60-second freshness, checkpoint-time ordering, and sequence coherence.
- `ISWV5PersistenceContract.ReconcileRestart`: S48-RFULL-21 through S48-RFULL-26 add isolated reduced-mask, stale broker/request, wrong-source, exact-boundary, and fully fresh vectors; all mismatch cases start from SAFE and preserve the checkpoint.
- `SWV5_TestDecodeRestartRequestSummary`: S48-RT-NEG-12 rejects omitted authority-source content.

## Sprint 4.8 Phase B9 additions

- `ISWV5PersistenceContract.ReconcileRestart`: S48-QAUTH-01 through S48-QAUTH-10 require owner-specific, independently fresh nested query authority whose sequence advances beyond the persisted Broker or Execution high-watermark. Fresh wrapper metadata cannot refresh an old nested snapshot.
- `ISWV5PersistenceContract.ReconcileRestart`: S48-RFIX-01 through S48-RFIX-02 prove Persistence and Execution request metadata are independent inputs and that coherent one-sided mutation remains unsafe.
- `SWV5_TestDecodeQuerySnapshot`: S48-RT-V5-16 performs a true new-object reconstruction; S48-RT-NEG-13 rejects missing query time or authority provenance.
- `Export-Sprint48Evidence.ps1`: EXP48-47 and EXP48-57 prove each deterministic stream is independently complete; EXP48-58 through EXP48-64 validate the source-bound offline result; EXP48-65 through EXP48-66 prove VerifyIndex and VerifyCommit reject hash-valid but semantically fabricated evidence.

## Sprint 4.8 Phase B10 additions

- `ISWV5PersistenceContract.ReconcileRestart`: S48-QRY-01 through S48-QRY-13 enforce closed-world owner masks; S48-QID-01 through S48-QID-03 prove `snapshot_id` is diagnostic and cannot bypass timestamp/sequence anti-replay.
- `ISWV5PersistenceContract.ReconcileRestart`: SAFE results expose a digest-bound `SWV5_AcceptedQueryWatermarkProposal` derived from the validated Broker and Execution query sequences.
- `ISWV5PersistenceContract.PublishRestartQueryWatermarks`: S48-QPUB-01 through S48-QPUB-12 verify atomic monotonic high-watermark publication, CAS fencing, replay rejection, owner separation, coherent checkpoint metadata, and failure atomicity.
- `SWV5_TestDecodeAcceptedQueryWatermarkProposal`: S48-RT-V5-17 performs new-object reconstruction; S48-CAN-DTO-12 covers every proposal field.
- `Export-Sprint48Evidence.ps1`: EXP48-68 through EXP48-73 prove VerifyIndex and VerifyCommit independently derive the source tree and rebuild the canonical verification-source digest against direct and internally recomputed forgeries.
