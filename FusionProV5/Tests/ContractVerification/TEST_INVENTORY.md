# Sprint 4.5 V4 Candidate Executable Test Inventory

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
| **Total** |  | **368** | **40** | **96** | **190** | **17** | **13** | **11** | **1** | **0** |

`MG` means `MERGE_GATING_BEHAVIOR`. The five behavioral columns total 356. The remaining 12 cases are explicitly supporting or conformance-only; none is represented as behavioral proof. The complete per-ID rationale is in `TEST_CREDIBILITY_MATRIX.md`.

The suite is deterministic, in-memory, and test-only. It does not query terminal time, accounts, positions, orders, history, symbols, files, network, or randomness.
