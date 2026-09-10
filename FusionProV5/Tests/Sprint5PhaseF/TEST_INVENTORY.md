# Phase F Entry Patch Test Inventory

All tests are deterministic, test-only, not for production and have no broker access.

| IDs | Coverage | Expected behavior |
|---|---|---|
| F-001..005 | authoritative local `NO_CALL` proof, post-Claim and broker-evidence contradictions | only valid local absence proof yields `NO_CALL`; all contradictions block |
| F-006 | claimed request without terminal evidence | unresolved |
| F-007..014 | orphan binding, pinned correlation/capability proof, ordered full deal set, direction and full/partial positive evidence | valid evidence confirms; invalid/orphan evidence blocks |
| F-015..030 | authoritative negative baseline; capability, lag, stability, generation, high-watermark, sequence, source-independence, row and completeness failures | only complete joint proof confirms negative; other candidates remain unresolved |
| F-031..033 | correlation/capability/negative-policy pin drift | blocked |
| F-034..040 | terminal replay lattice, partition/evidence binding, later conflicts | exact replay preserved; mismatch/conflict blocked |
| F-041..042 | blocked-state replay with valid/invalid binding | blocked remains sticky |
| F-043 | simultaneous positive and negative evidence | blocked |
| F-044 | incomplete operation/enumeration | unresolved |
| F-045..046 | positive or negative broker evidence presented against `NO_CALL` | blocked |
| F-047..048 | later evidence presented against negative/partial terminal states | blocked |

Mutation controls are separate from ordinary cases:

| ID | Deliberate defect |
|---|---|
| MC-NOCALL-BYPASS | returns `NO_CALL` after Claim |
| MC-ORPHAN-BINDING | confirms durable side effect with invalid binding |
| MC-RESIDUAL-AUTHORITY | turns partial residual into submission authority |
| MC-WATERMARK-COLLAPSE | accepts reads before lag/stability thresholds |
| MC-CAPABILITY-SELFATTEST | lets Broker Adapter author its own proof |
| MC-POLICY-DRIFT | evaluates current policy rather than pinned policy |
| MC-TERMINAL-OVERWRITE | moves terminal confirmation backward |
| MC-SINGLE-ROW-POSITIVE | confirms after reading only the first enumerated row |
| MC-DIGEST-DOMAIN-SUBSTITUTION | accepts digest from a foreign canonical domain |
| MC-SHARED-EVIDENCE-SOURCE | treats one shared cache as independent Broker/Execution evidence |

For every mutation: `PASS = unsafe_result_observed && target_assertion_detected`.
