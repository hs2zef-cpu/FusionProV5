# Sprint 5 Phase F Broker Adapter — Auditor Clearing Package

TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

Accepted Phase F reconciliation contract: `4e5a785f77d291c2e43499da9da9c5fb7572f5cb`.
Canonical implementation before this evidence patch: `fcbcb11d49eb73d94304a332f2203c8154b366e2`.
This package supplies evidence completeness only. It grants no Phase G, Architecture Lock, main-merge,
production, Demo mutation, deployment, or live-trading authority.

## A. Accepted Contract Closure at `4e5a785f`

| Finding | Closure boundary | Accepted evidence |
|---|---|---|
| F-1 NO_CALL structural authority | `SWV5S5_F_NoCallProof` and `SWV5S5_F_IsNoCallProofValid` | F-001–005, MC-NOCALL-BYPASS |
| F-2 orphan side effect | `SWV5S5_F_HasDurableBrokerSideEffectShape`; orphan/unauthorized positive is conflict | F-007–008, MC-ORPHAN-BINDING |
| F-3 residual non-authority | Partial result explicitly denies residual submission authority and requires a new identity/admission | F-010, F-036, MC-RESIDUAL-AUTHORITY |
| F-4 lag/stability/generation/sequence | Negative policy and observations bind generations, high-watermarks, lag and stability | F-015–029, MC-WATERMARK-COLLAPSE |
| F-5 independent capability proof | `SWV5S5_F_CapabilityProof` and `SWV5S5_F_IsCapabilityProofValid` | F-013, F-030, MC-CAPABILITY-SELFATTEST |
| F-6 policy pinning | Binding pins correlation, capability, and negative-policy ID/version/digest | F-031–033, MC-POLICY-DRIFT |
| F-7 terminal lattice | Terminal partition/evidence is monotonic; conflict enters sticky BLOCKED | F-034–042, MC-TERMINAL-OVERWRITE |
| F-8 credible mutations | Deliberately broken independent doubles require unsafe observation and target detection | all Phase F entry `MC-*` rows |
| F-9 digest-domain separation | Eight distinct domain constants bind typed canonical records | MC-DIGEST-DOMAIN-SUBSTITUTION and source verifier |
| F-10 read-path independence | Broker and Execution paths, authorities, sequence authorities, snapshots and digests are distinct | F-027, MC-SHARED-EVIDENCE-SOURCE |

## B. Exact `OrderSend` Code Shape

Static verification of `SW_V5_S5_F_BrokerPlatformBoundary.mqh` establishes:

- exactly one `OrderSend(` source site, inside `SubmitExactlyOnce`;
- `m_send_consumed=true` occurs before Claim/preflight processing and has no reset path;
- `SWV5S5_ValidateAuthoritativeClaimResult` plus `claim_granted_now` validates current-operation authority;
- `CaptureEnvironment` immediately re-samples profile, permission, and symbol specification;
- `SWV5S5_F_AdapterValidateFinalEnvironment` rejects any final-sample drift;
- the wire-ready neutral copy of `MqlTradeRequest` is digested before the send;
- the digest-to-send interval contains no request assignment, normalization, filling coercion, loop, retry,
  or re-entry path;
- the synchronous result is observational (`final_confirmation=false`) and `retry_allowed=false` for every class.

The last platform read and the platform call cannot be atomic. This irreducible TOCTOU interval is not claimed
away: every uncertain result remains unresolved and cannot authorize retry.

## C. REAL_MQL_EXECUTED

MetaEditor X64 Regular compiled the assertion manifest with 0 errors and 0 warnings. MT5 Demo Strategy Tester
executed 48/48 pure assertions, 0 failed, 0 skipped, signature
`a308afa7b57c6afbf93e9e5313be04a5e5e3c849464a08aced833e626fc02bae`, and explicit `broker_calls=0`.

Exact IDs:

`MQL-GRID-01-BINARY-DECIMAL`, `MQL-GRID-02-OFF-GRID`, `MQL-GRID-03-ZERO-OPTIONAL`,
`MQL-GRID-04-ZERO-REQUIRED`, `MQL-GRID-05-CANONICAL-EQUALITY`, `MQL-FILL-01-FOK-EXACT`,
`MQL-FILL-02-IOC-EXACT`, `MQL-FILL-03-COMBINED-REJECT`, `MQL-FILL-04-UNSUPPORTED-REJECT`,
`MQL-PRICE-01-BUY-SEMANTICS`, `MQL-PRICE-02-SELL-SEMANTICS`, `MQL-PRICE-03-BUY-WRONG-SIDE`,
`MQL-PRICE-04-OFF-TICK`, `MQL-WIRE-01-DETERMINISTIC`, `MQL-WIRE-02-MUTATION-SENSITIVE`,
`MQL-TOCTOU-01-STABLE-SAMPLE`, `MQL-TOCTOU-02-PERMISSION-CHANGE`, `MQL-TOCTOU-03-SPEC-CHANGE`,
`MQL-QUERY-01-EMPTY-COMPLETE`, `MQL-QUERY-02-OMITTED-ROW-REJECT`, `MQL-EVIDENCE-01-INDEPENDENT`,
`MQL-EVIDENCE-02-SHARED-AUTHORITY-REJECT`, `MQL-QUERY-03-EXECUTION-COMPLETE`,
`MQL-QUERY-04-EXECUTION-OMISSION-REJECT`, `MQL-PREFLIGHT-01-CURRENT-EPHEMERAL-CLAIM`,
`MQL-PREFLIGHT-02-CURRENT-CLAIM-REQUIRED`, `MQL-PREFLIGHT-03-CLAIM-GRANTED-NOW-FALSE`,
`MQL-PREFLIGHT-04-STALE-AUTHORITATIVE-CLAIM`, `MQL-PREFLIGHT-05-EXACT-PROFILE-MISMATCH`,
`MQL-PREFLIGHT-06-CONNECTION-FALSE`, `MQL-PREFLIGHT-07-TERMINAL-PERMISSION-FALSE`,
`MQL-PREFLIGHT-08-MQL-PERMISSION-FALSE`, `MQL-PREFLIGHT-09-ACCOUNT-PERMISSION-FALSE`,
`MQL-PREFLIGHT-10-EXPERT-PERMISSION-FALSE`, `MQL-PREFLIGHT-11-DIRECTION-MISMATCH`,
`MQL-PREFLIGHT-12-VOLUME-MISMATCH`, `MQL-PREFLIGHT-13-PRICE-MISMATCH`,
`MQL-PREFLIGHT-14-SUBMISSION-DIGEST-MISMATCH`, `MQL-PREFLIGHT-15-COMBINED-FILLING-REJECT`,
`MQL-FINAL-ENV-01-SPEC-MISMATCH-REJECT`, `MQL-SYNC-01-ACCEPTED-REMAINS-NONFINAL`,
`MQL-SYNC-02-CLIENT-LOCAL-NONRETRY`, `MQL-SYNC-03-TIMEOUT-NONRETRY`,
`MQL-SYNC-04-TRANSPORT-NONRETRY`, `MQL-SYNC-05-UNKNOWN-NONRETRY`,
`MQL-RECON-01-PARTIAL-RESIDUAL-NONAUTHORITY`, `MQL-RECON-02-TERMINAL-CONFLICT-BLOCKED`, and
`MQL-RECON-03-BLOCKED-STICKY`.

These invoke actual functions from Broker Adapter Core, Broker Reconciliation Integration, and the accepted
Phase F evaluator. The runtime claim fixture explicitly initializes canonical empty strings because MQL
`ZeroMemory` produces nullable strings that are not canonical empty-string evidence.

## D. Other Evidence Classes

- **PYTHON_ORACLE:** Broker Adapter 45/45, signature
  `9642dade71218316436ad87f4119a7ea299936ce0571f95fb5da016c7cb0d460`.
- **PYTHON_MUTATION:** Broker Adapter 17/17, signature
  `77771eaf3cacdc5e11e2ef0779d388fb6a88ff21feaedfcab54eff1359691171`.
  The five audit-specific mutants use target-specific detectors; all 17 mappings are in
  `MUTATION_CREDIBILITY_MATRIX.md`.
- **PYTHON_ORACLE:** accepted Phase F entry suite 48/48, signature
  `f8cad8bffdc2655d0fa224163f27da4e4fbfeeb73407bf7d8d79550cff18339e`.
- **PYTHON_MUTATION:** accepted Phase F entry mutations 10/10, digest
  `52d8f56813e3330aef1953244a8a72dc26a24f8c561f13c91cdce1eb1ed46dc1`.
- **STATIC_SOURCE:** exact send shape, one-shot fuse, API isolation, final re-sample/digest order, no retry,
  no proof authorship, exact row accounting, Broker/Execution independence, accepted-contract immutability,
  and protected Phase B/C/D/E isolation.
- **NOT_EXECUTABLE_WITHOUT_BROKER:** the real platform `SubmitExactlyOnce` call through `OrderSend`, real
  `CaptureEnvironment` reads, live Broker query enumeration, and terminal callback delivery. They are excluded
  because no Demo `OrderSend` or broker mutation is authorized. Their pure guards are REAL_MQL_EXECUTED; their
  orchestration/source shape is STATIC_SOURCE; their outcome model is independently PYTHON_ORACLE tested.

No non-executable case is counted in the 48 REAL_MQL_EXECUTED assertions.

## E. Scope and Isolation

The auditable implementation/evidence scope is `4e5a785f77d291c2e43499da9da9c5fb7572f5cb..HEAD`.
The source verifier must pass at the final evidence commit and proves the accepted reconciliation contract plus
Phase B/C/D/E, ProductionArchitecture, Signal Engine, DecisionEngine, Engines, Dashboard, Coordinator and
PersistenceReference are unchanged. This patch contains test/evidence hardening only. No Demo/live broker
mutation was performed.
