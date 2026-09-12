# Sprint 5 Phase F Broker Adapter Verification

TEST ONLY / NOT FOR PRODUCTION. No Demo or live broker mutation is authorized.

This directory verifies the Phase F Broker Adapter implementation against the
accepted entry contract at commit `4e5a785f77d291c2e43499da9da9c5fb7572f5cb`.
The compile manifest includes the production adapter boundary but executes no
adapter method. A separate Strategy-Tester-only MQL harness executes pure adapter
assertions and reports `broker_calls=0`. Deterministic integration tests use an
independent Python broker-double oracle; a separate Python mutation suite proves
the named unsafe models are detected; static source controls verify boundary
shape and isolation. These four evidence classes are reported separately and
none substitutes for another.

The expanded MQL harness executes 48 pure production-function assertions,
including authoritative Claim/preflight guards, all permission flags, payload
binding, synchronous classification, partial residual non-authority, terminal
conflict, and sticky BLOCKED behavior. `AUDITOR_CLEARING_PACKAGE.md` records the
evidence classes and exact IDs. `MUTATION_CREDIBILITY_MATRIX.md` maps every
mutant to its unsafe predicate, detector, provenance, and targeted guard.

The adapter has four layers:

1. neutral DTOs and persistence-facing interfaces;
2. pure Claim/preflight and synchronous-result classification;
3. pure Broker/Execution evidence projection into the accepted reconciliation contract;
4. one exclusive MT5 platform boundary for environment reads, broker queries,
   callback capture, and the single guarded `OrderSend` call.

No capability proof is created here. Until an independently governed proof is
present and valid, query completeness and visibility-watermark claims remain
false and authoritative negative reconciliation remains naturally unreachable.

The final environment re-sample reduces the permission/profile/specification
TOCTOU window but cannot eliminate a platform change between the last read and
`OrderSend`. That irreducible window is explicitly non-authoritative: any
uncertain synchronous outcome remains unresolved and is never retried.
