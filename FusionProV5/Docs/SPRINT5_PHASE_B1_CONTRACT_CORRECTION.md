# Sprint 5 Phase B.1 — Contract Conformance Correction

Status: **CORRECTIVE CANDIDATE / READY FOR INDEPENDENT RE-AUDIT AFTER SELF-VERIFICATION**

The first independent Sprint 5 Phase B Contract Implementation Audit returned `FAIL` with 2 Critical, 10 Major, and 3 Minor findings. Phase B.1 corrects only the candidate implementation against approved ADR-009 through ADR-020. The Architecture Review Gate remains closed. Phase C, runtime, broker access, physical persistence, Architecture Lock, and merge to main remain unauthorized.

## Audit-finding closure matrix

| Audit finding | Corrected files | Exact technical mechanism | Test evidence |
|---|---|---|---|
| CRITICAL-1 replayable Claim grant | `SW_V5_S5_InvocationClaimContract.mqh` | Pure `PrepareInvocationClaimTransition` returns only an eligible complete N+1 durable proposal; abstract `TryClaimInvocation` is the sole grant-bearing boundary; result contains full durable record | `TestClaimBoundary`; oracle CLM-001/002; static no-grant assignment |
| CRITICAL-2 current ownership/full snapshot | Claim and Admission Snapshot contracts | Claim binds actual current `SWV5_InstanceLease`, exact fence/takeover/liveness, full typed snapshot, recomputed digest, request/attempt/payload/permit/policy/clock | `TestClaimBoundary`, `TestSnapshotSemantics` |
| MAJOR-1 Hard Kill after P | Admission and Claim contracts | Removed `hard_kill_blocks_increase`; after-P state mutation is ordered later, while Claim-time deadlines remain mandatory | `TestADR020Ordering`; static veto-absence check |
| MAJOR-2 manufactured stable token | Admission Snapshot contract | Deleted generic `SWV5S5_StableAuthorityToken`; typed V5/Sprint 5 owner records carry mutation evidence separately from projection digests | `TestSnapshotSemantics`; static generic-token absence |
| MAJOR-3 incomplete snapshot | Admission Snapshot contract | Added Ownership, Lease, Trust, Hard Kill, Account, Basket, request set, specification, Margin, Basket-risk, Risk, normalized payload, Permit, policy/format, and three clocks | `TestSnapshotSemantics` |
| MAJOR-4 incorrect double collect | Admission Snapshot contract | Compares typed owner evidence and complete projection digests; permits distinct V1/V2 observation time with same authority and nonregression | `TestSnapshotSemantics` |
| MAJOR-5 incomplete Producer Trust | Producer Trust contract | Anchor binds exact current record/generation; validator binds exact ingress/source scope; successor requires authoritative supersession continuity | `TestProducerTrust` |
| MAJOR-6 incomplete Permit | Submission Authority contract | Complete typed Permit, exact stable preimage, content conflict, expected-index preparation, abstract commit authority | Permit and Blueprint groups; oracle PER cases |
| MAJOR-7 weak Ledger/Sequence authority | Ledger and Request Sequence contracts | Explicit ordered indexes; recomputed header/authority digests; below-HWM absence denies; compaction/index/overflow continuity | `TestLedgerAndSequence`; oracle LED/SEQ cases |
| MAJOR-8 ADR-013 identities/blueprint | Request Binding contract | Policy/version-bound correlation excludes sequence; Attempt and idempotency derive from correlation; complete initial V5 state validation | Canonical and Blueprint groups; fixed oracle hashes |
| MAJOR-9 incomplete publication evidence | Runtime Publication contract | Separate request-set/checkpoint proposals bind exact current digest/revision/store/fence/takeover and complete proposed payload projection | `TestFencedPublication`; oracle PUB cases |
| MAJOR-10 non-executable verification | Sprint5PhaseB tests | Added 125-call MQL assertion harness and 89-case independent executable oracle; removed the old inventory-as-execution claim | Both compile gates; oracle 89/89 |
| MINOR documentation | VERSION, README, Changelog, Phase B docs | Recorded failed first audit, Phase B.1 authorization, closed Architecture Review, Phase C denial | Governance commit |
| MINOR SHA overflow | Canonical contract | Padding arithmetic promotes before addition, checks representable bounds, and fails closed | Standard SHA vectors; compile gates |
| MINOR disposition naming | Common, Sequence, Publication, Claim contracts | Pure results now say `PROPOSAL_VALID`/`TRANSITION_ELIGIBLE`; `COMMITTED`/`GRANTED_NOW` are authoritative outcomes only | Static boundary checks and assertion source |

## Typed authority and ABA proof matrix

Snapshot projection digests provide deterministic content comparison. They are not owner mutation authority. The owner-specific evidence below is compared independently, so an A→B→A payload cannot compare unchanged after a safety-relevant owner mutation.

| Authority | Owner | Owner mutation evidence | Snapshot payload binding | ABA proof |
|---|---|---|---|---|
| Ownership | Instance Ownership | owner identity, lease version, takeover generation, fencing-token digest | complete `SWV5_OwnershipFence` projection | takeover/fence token must advance/change |
| Lease liveness | Instance Ownership/store | store revision, heartbeat sequence/clock, expiry sequence/time | complete `SWV5_InstanceLease` liveness projection | intervening heartbeat/store mutation changes evidence |
| Producer Trust | Trust Authority | authority record ID/generation and record digest | complete Trust record projection | successor must match anchored supersession chain |
| Hard Kill | Risk Governance | latch ID/generation, release generation and authority reference | complete latch/release projection | generation/release evidence records intervening mutation |
| Account/mode | Account authority | snapshot epoch and sequence | complete account namespace/mode/source projection | epoch/sequence prevents returned numeric payload from hiding mutation |
| Basket | Basket authority | Basket ID, state version, recovery index revision | lifecycle, exposure/count/query projection | state version/index evidence changes across mutation |
| Pending request set | Execution | request-set revision/digest and record sequence | ordered complete pending-request projections | revision/record sequence plus content prevents restored-set ABA |
| Symbol specification | Unit authority | specification sequence and observation interval | complete unit specification projection | owner sequence changes on specification publication |
| Margin | Broker Margin Authority | record ID/sequence/digest and observation sequence | typed Margin authority projection | authoritative record sequence/digest changes |
| Basket risk | Risk Governance | record ID/sequence/digest and source snapshot | typed resulting-Basket-risk projection | authority/source snapshot identities change |
| Risk authorization | Risk Governance | authorization ID, risk epoch/sequence, exclusive expiry | complete request/fence/account/Basket/spec/Hard Kill projection | epoch/sequence and unique authorization prevent reuse |
| Normalized payload | Unit authority | normalization identity and specification sequence | complete `SWV5_NormalizedUnits` projection | new normalization/spec identity exposes mutation |
| Submission Permit | Submission Authority | permit ID/revision/digest | complete typed Permit projection | same ID/different content is conflict; revision/digest advances |
| Validation clocks | configured time authority | clock ID/authority/sequence/time | distinct V1, V2, and final Claim observations | sequence/time nonregression exposes intervening observation |
| Policy/format | governance/canonical policy | exact policy ID/version and format ID | fixed policy/format projection | a policy/version change cannot compare equal |

## Verification classification

- MQL compile tests: umbrella and assertion harness, MetaEditor X64 Regular.
- MQL assertions present: 125 actual calls across nine registered groups.
- MQL assertions executed: **NO — PHASE B SAFETY BOUNDARY**.
- Independent PowerShell/.NET reference assertions: 89 executed, 89 passed.
- Static checks: forbidden APIs, dependency direction, include cycles, pure-grant absence, opaque-index absence, and proposal/authority split.

The PowerShell verifier is an independent test oracle, not MQL production execution.
