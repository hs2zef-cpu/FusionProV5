# Sprint 4.2 Contract Verification Traceability Matrix

> **TEST ONLY — NOT FOR PRODUCTION — NO BROKER ACCESS**

| Requirement | Contract field or interface surface | Executable test IDs |
|---|---|---|
| 1. All 49 Basket pairs | `SWV5_BasketLifecycleSnapshot.state`, `SWV5_BasketTransitionRequest.from_state/to_state`, `ISWV5BasketStateMachineContract::ValidateTransition` | `BSM-01`–`BSM-49` |
| 2. Allowed, forbidden, same-state | `SWV5_ContractDisposition`, Basket state pair and transition cause | `BSM-01`–`BSM-49` |
| 3. State version rules | `state_version`, `expected_state_version`, `resulting_state_version` | `BSM-01`–`BSM-49` |
| 4. IDLE closure invariants | residual volume, live position/order/pending counts, `SWV5_AuthoritativeQuerySet` | `BSM-29`, `BSM-36`, `BAS-06`, `XDM-12` |
| 5. Partial-close residual exposure | `SWV5_PartialCloseEvidence`, lifecycle residual volume, close evidence | `BAS-03`–`BAS-06`, `STA-03`, `XDM-04`, `XDM-12` |
| 6. Acknowledgement vs confirmation | `SWV5_ResultRetcodeClass`, `SWV5_PendingRequestState`, `SWV5_TransactionEvidence` | `EXE-02`, `EXE-03`, `EXE-16`, `XDM-11` |
| 7. Duplicate/out-of-order transaction | `event_id`, `idempotency_key`, `transaction_sequence`, confirmation volume | `EXE-09`, `EXE-10`, `STA-04`, `STA-10`–`STA-12`, `XDM-07` |
| 8. Ownership fencing | `SWV5_OwnershipFence` in Basket, Execution, Risk, Persistence, and transaction evidence | `COM-07`, `OWN-06`, `OWN-07`, `OWN-10`, `EXE-15`, `RSK-02`, `XDM-02`, `XDM-09` |
| 9. Lease/CAS behavior | lease version, takeover generation, fencing digest, store revision, clock sequence | `OWN-01`–`OWN-11` |
| 10. Namespace collision prevention | `SWV5_PersistenceNamespace`, full `SWV5_OwnershipKey`, Basket ID | `COM-08`, `BAS-01`, `BAS-07`, `PER-04`, `PER-14`, `STA-05` |
| 11. Restart disposition | `SWV5_RestartReconciliationInput/Result`, `SWV5_ReconciliationStatus`, authoritative queries | `PER-05`–`PER-11`, `PER-13`, `PER-15`, `XDM-03`, `XDM-08`, `XDM-11` |
| 12. Invalid persisted records | record version, digest, payload size, sequence, namespace, ownership fence | `PER-01`–`PER-04`, `PER-10`, `PER-11`, `PER-14` |
| 13. Hard Kill durability/release | `SWV5_HardKillState`, `SWV5_HardKillReleaseEvidence`, persisted checkpoint | `PER-12`, `RSK-01`, `RSK-11`, `RSK-12`, `RSK-14`, `XDM-06`, `XDM-10` |
| 14. Risk authorization binding | full correlation, Basket version, fence, normalized terms, snapshot sequences, latch generation, times | `RSK-02`, `RSK-03`, `RSK-08`–`RSK-10`, `RSK-13`, `RSK-14`, `RSK-16` |
| 15. Symbol specification sequence | normalization expectation, intent, persisted request, authorization | `UNT-08`, `EXE-06`, `RSK-08`, `XDM-05` |
| 16. Unit normalization | symbol unit specification and normalized-unit evidence | `UNT-01`–`UNT-10` |
| 17. Statistics dedup/partial accounting | deal correlation, dedup evidence/state, entered/exited/residual volume | `STA-01`, `STA-03`–`STA-12`, `XDM-07` |
| 18. Monetary completeness | profit, commission, swap, fee, currency, monetary completeness and basis | `STA-02`, `STA-06`, `STA-13`, `RSK-15` |
| 19. Cross-domain negatives | namespace, fence, latch, sequence, residual, reconciliation and confirmation gates | `XDM-02`–`XDM-12` |
| 20. Determinism | explicit validation context, result signature, complete repeated suite | `COM-05` plus two full 162-case passes per process and two independent terminal runs |

## Contract Ownership Check

The tests treat `SWV5_BasketLifecycleSnapshot` as the sole canonical Basket owner of recovery attempt/layer, aggregate open volume, residual volume, and pending count. Repeated values in transition, broker, close, persistence, Risk, or Statistics DTOs are validated as immutable evidence snapshots; they are never mutated into a competing authoritative Basket state.
