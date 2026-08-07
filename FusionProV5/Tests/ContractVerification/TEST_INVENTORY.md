# Sprint 4.4 Semantic Contract Test Inventory

> TEST ONLY - NOT FOR PRODUCTION - NO BROKER ACCESS

| Domain | Test IDs | Count | Implementation under test |
|---|---:|---:|---|
| Common/versioning | COM-01–COM-12 | 12 | `ISWV5ContractVersionPolicy` and canonical validation context |
| Basket state | BSM-01–BSM-49 | 49 | `ISWV5BasketStateMachineContract` across every state pair |
| Basket aggregate | BAS-01–BAS-08 | 8 | `ISWV5BasketContract` plus recovery interface rejection |
| Unit system | UNT-01–UNT-10 | 10 | `ISWV5UnitSystemContract` |
| Ownership | OWN-01–OWN-11 | 11 | `ISWV5InstanceOwnershipContract` and fencing/CAS validators |
| Execution | EXE-01–EXE-16 | 16 | `ISWV5ExecutionContract` |
| Persistence/restart | PER-01–PER-15 | 15 | `ISWV5PersistenceContract` |
| Risk | RSK-01–RSK-16 | 16 | `ISWV5RiskContract` |
| Statistics | STA-01–STA-13 | 13 | `ISWV5StatisticsContract` |
| Cross-domain | XDM-01–XDM-12 | 12 | Ordered interface gates and negative scenarios |
| Corrective interface cases | IFC-01–IFC-30 | 30 | All ten Sprint 4.3 findings through actual `ISWV5*` methods |
| Interface method conformance | IFC-31–IFC-40 | 10 | Direct invocation of remaining production interface methods |
| Persistence round trip | PRT-01–PRT-11 | 11 | Full-record deep-copy Save/Load through `ISWV5PersistenceContract` |
| Sprint 4.4 semantic closure | S44-01 through S44-25 | 25 | Full restart set, payload integrity, Risk output, durable identity, heartbeat/takeover semantics |
| **Executable total** |  | **238** | Two in-process replays and two independent Demo tester runs |
| **Interface-credible total** |  | **236** | COM-07 and COM-08 are supporting pure equality cases and are not counted as interface behavior |

All test implementations are deterministic, in-memory, and test-only. Except for the two explicitly supporting equality cases, assertions invoke advertised interfaces and consume meaningful outputs or state mutations. No validator queries terminal time, account, positions, orders, history, symbols, files, network, or randomness.
