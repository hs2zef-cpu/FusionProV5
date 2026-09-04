# Sprint 5 Phase E Test Inventory

TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

The independent offline oracle contains **55 unique integrated scenarios**:

| Group | Count |
|---|---:|
| Happy | 2 |
| WAIT/BLOCKED | 2 |
| Crash M1–M9 | 9 |
| Restart N1–N13 | 13 |
| ADR-020 | 7 |
| Takeover O1–O6 | 6 |
| Semantic/resealed P1–P11 | 11 |
| Exactly-once matrix | 8 mappings within Crash/Restart/Semantic/Takeover scenarios; no duplicate count |
| Scheduler invariance | 2 |
| Harness negative controls | 3 |
| **Total** | **55** |

Every scenario crosses at least two phase boundaries and declares invariants,
phases, authorities, ordered events, literal expected outcome, literal broker
count, literal restart disposition, and literal durable summary. The count is not
an optimization target; no isolated component arithmetic/digest/state-table test
is repeated.

MQL functions are compile-only and are inventoried by
`verify_phase_e_source.py`. MQL assertions are **NOT executed**.
