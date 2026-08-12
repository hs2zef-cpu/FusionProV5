# Sprint 4.7 Phase A V4 Candidate Executable Test Inventory

> TEST ONLY - NOT FOR PRODUCTION - NO BROKER ACCESS

| Domain | IDs | Total | MG | State | Negative | Round trip | Invariant | Supporting | Conformance | Weak |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Common/versioning | COM-01–COM-12 | 12 | 3 | 0 | 6 | 0 | 1 | 2 | 0 | 0 |
| Basket state pairs | BSM-01–BSM-49 | 49 | 0 | 49 | 0 | 0 | 0 | 0 | 0 | 0 |
| Basket aggregate | BAS-01–BAS-08 | 8 | 0 | 0 | 6 | 0 | 2 | 0 | 0 | 0 |
| Unit system baseline | UNT-01–UNT-10 | 10 | 3 | 0 | 7 | 0 | 0 | 0 | 0 | 0 |
| Ownership baseline | OWN-01–OWN-11 | 11 | 2 | 2 | 7 | 0 | 0 | 0 | 0 | 0 |
| Execution baseline | EXE-01–EXE-16 | 16 | 6 | 4 | 5 | 0 | 1 | 0 | 0 | 0 |
| Phase A execution authority | S45A-01–S45A-10 | 10 | 0 | 5 | 5 | 0 | 0 | 0 | 0 | 0 |
| Phase A durable fingerprint | S45F-01–S45F-02 | 2 | 0 | 0 | 1 | 1 | 0 | 0 | 0 | 0 |
| Phase B recovery canonical path | S45BR-01–S45BR-10 | 10 | 0 | 2 | 7 | 1 | 0 | 0 | 0 | 0 |
| Phase B unclaimed acquire | S45BO-01–S45BO-10 | 10 | 0 | 2 | 7 | 0 | 1 | 0 | 0 | 0 |
| Phase C Risk binding | S45CR-01–S45CR-29 | 29 | 1 | 0 | 28 | 0 | 0 | 0 | 0 | 0 |
| Phase C Unit safety | S45CU-01–S45CU-20 | 20 | 8 | 0 | 11 | 0 | 1 | 0 | 0 | 0 |
| Phase D ownership lifecycle | S45DO-01–S45DO-33 | 33 | 0 | 10 | 22 | 0 | 1 | 0 | 0 | 0 |
| Phase D persistence canonical | S45DP-01–S45DP-16 | 16 | 0 | 0 | 5 | 2 | 0 | 9 | 0 | 0 |
| Persistence/restart baseline | PER-01–PER-15 | 15 | 3 | 0 | 11 | 0 | 1 | 0 | 0 | 0 |
| Risk baseline | RSK-01–RSK-16 | 16 | 0 | 0 | 16 | 0 | 0 | 0 | 0 | 0 |
| Statistics | STA-01–STA-13 | 13 | 0 | 5 | 7 | 0 | 1 | 0 | 0 | 0 |
| Cross-domain | XDM-01–XDM-12 | 12 | 2 | 2 | 8 | 0 | 0 | 0 | 0 | 0 |
| Interface correction/conformance | IFC-01–IFC-40 | 40 | 7 | 10 | 14 | 4 | 4 | 0 | 1 | 0 |
| Persistence round trip | PRT-01–PRT-11 | 11 | 0 | 0 | 4 | 7 | 0 | 0 | 0 | 0 |
| Sprint 4.4 semantic closure | S44-01–S44-25 | 25 | 5 | 5 | 13 | 2 | 0 | 0 | 0 | 0 |
| Sprint 4.6 execution envelope | S46AE-01–S46AE-42 | 42 | 1 | 3 | 38 | 0 | 0 | 0 | 0 | 0 |
| Sprint 4.6 Risk safety | S46BR-01–S46BR-31 | 31 | 1 | 0 | 30 | 0 | 0 | 0 | 0 | 0 |
| Sprint 4.6 Hard Kill release | S46BH-01–S46BH-40 | 40 | 1 | 0 | 39 | 0 | 0 | 0 | 0 | 0 |
| Sprint 4.6 checkpoint integrity | S46CP-01–S46CP-20 | 20 | 0 | 0 | 15 | 2 | 1 | 2 | 0 | 0 |
| Sprint 4.6 durable event identity | S46EI-01–S46EI-20 | 20 | 0 | 4 | 5 | 1 | 0 | 10 | 0 | 0 |
| Sprint 4.6 retry freshness | S46DR-01–S46DR-20 | 20 | 3 | 0 | 16 | 0 | 1 | 0 | 0 | 0 |
| Sprint 4.6 fingerprint uniqueness | S46E1-01 through S46E1-20 | 20 | 1 | 2 | 15 | 0 | 2 | 0 | 0 | 0 |
| Sprint 4.7 Risk projection binding | S47-RISK-01 through S47-RISK-18 | 18 | 2 | 0 | 16 | 0 | 0 | 0 | 0 | 0 |
| Sprint 4.7 non-finite rejection | S47-NUM-01 through S47-NUM-18 | 18 | 0 | 0 | 18 | 0 | 0 | 0 | 0 | 0 |
| Sprint 4.7 Hard Kill expiry | S47-HK-01 through S47-HK-07 | 7 | 1 | 0 | 6 | 0 | 0 | 0 | 0 | 0 |
| Sprint 4.7 checkpoint semantics | S47-CHK-01 through S47-CHK-18 | 18 | 0 | 0 | 18 | 0 | 0 | 0 | 0 | 0 |
| Sprint 4.7 retry enum whitelist | S47-RETRY-01 through S47-RETRY-12 | 12 | 2 | 0 | 9 | 0 | 1 | 0 | 0 | 0 |
| **Total** |  | **634** | **52** | **105** | **415** | **20** | **18** | **23** | **1** | **0** |

`MG` means `MERGE_GATING_BEHAVIOR`. The five behavioral columns total 610. The remaining 24 cases are explicitly supporting or conformance-only; none is represented as behavioral proof. The complete per-ID rationale is in `TEST_CREDIBILITY_MATRIX.md`.

The suite is deterministic, in-memory, and test-only. It does not query terminal time, accounts, positions, orders, history, symbols, files, network, or randomness.
