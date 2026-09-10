# Phase F Entry Patch Traceability Matrix

| Finding | Contract field/function | Oracle / mutation evidence |
|---|---|---|
| F-1 `NO_CALL` structural authority | `SWV5S5_F_NoCallProof`, `SWV5S5_F_IsNoCallProofValid` | F-001..005, MC-NOCALL-BYPASS |
| F-2 orphan side effect | `SWV5S5_F_HasDurableBrokerSideEffectShape`, `ORPHAN_OR_UNAUTHORIZED_POSITIVE_SIDE_EFFECT` | F-007..008, MC-ORPHAN-BINDING |
| F-3 residual non-authority | result residual authority flags and partial reason | F-010, F-036, MC-RESIDUAL-AUTHORITY |
| F-4 lag/stability/generation/sequence | negative observations, policy generation and high-watermark checks | F-015..029, MC-WATERMARK-COLLAPSE |
| F-5 independent capability proof | `SWV5S5_F_CapabilityProof`, `SWV5S5_F_IsCapabilityProofValid` | F-013, F-030, MC-CAPABILITY-SELFATTEST |
| F-6 policy pinning | `pinned_*_policy_*`, `pinned_capability_proof_*` | F-031..033, MC-POLICY-DRIFT |
| F-7 terminal lattice | sticky blocked branch, persisted partition/evidence digest, result digest | F-034..042, MC-TERMINAL-OVERWRITE |
| F-8 credible mutations | separate mutation-control runner | all `MC-*` rows |
| F-9 digest-domain separation | eight distinct `SWV5S5_F_DOMAIN_*` constants | MC-DIGEST-DOMAIN-SUBSTITUTION, source verifier |
| F-10 read-path independence | Broker/Execution path and authority-instance IDs | F-027, MC-SHARED-EVIDENCE-SOURCE |
| Frozen compatibility | pure overlay includes frozen contract without modifying it | source/isolation verifier and Phase B–E regressions |
