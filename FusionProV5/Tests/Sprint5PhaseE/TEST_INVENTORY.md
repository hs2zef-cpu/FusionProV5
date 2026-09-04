# Sprint 5 Phase E Test Inventory

TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

The independent offline oracle contains **52 unique ordinary integrated
scenarios**. Mutation controls are inventoried separately because they test
deliberately broken behavior rather than correct-path scenario outcomes.

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
| **Ordinary scenario total** | **52** |

Every scenario crosses at least two phase boundaries and declares invariants,
phases, authorities, ordered events, literal expected outcome, literal broker
count, literal restart disposition, and literal durable summary. The count is not
an optimization target; no isolated component arithmetic/digest/state-table test
is repeated.

MQL functions are compile-only and are inventoried by
`verify_phase_e_source.py`. MQL assertions are **NOT executed**.

## Mutation controls

`verify_phase_e_mutation_controls.py` contains eight Python-only controls:

- `MC-P`
- `MC-JOINT`
- `MC-DOMAIN`
- `MC-OWNERSHIP-LOGICAL`
- `MC-OWNERSHIP-DURABLE`
- `MC-GRANT`
- `MC-BROKER-DEDUPE`
- `MC-STALE-CAS-EQUALITY`

The prior Phase-E generation counted three controls inside the 55-scenario
total. That inventory did not cover every required mutation class. This
correction retains all ordinary semantic negatives, separates the controls, and
expands targeted mutation evidence to 8/8. See `NEGATIVE_CONTROL_MATRIX.md`.
