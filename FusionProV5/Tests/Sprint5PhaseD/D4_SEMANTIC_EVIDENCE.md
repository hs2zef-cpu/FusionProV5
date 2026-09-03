# Sprint 5 Phase D.4 Semantic Evidence Classification

**TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS**

D.4 self-verification only. MQL assertions executed: **NO**. Python is an independent executable oracle; its JSON model is not byte-for-byte MQL canonical or runtime proof.

## Direct source inventory

The source contains 17 positive and 157 negative named assertion functions. Four positives and 38 negatives belong to D.4. Parameterized rejection helpers are named `Reject...` and are excluded from assertion counts.

| D.4 negative family | Entry points | Integrity/semantic treatment |
|---|---:|---|
| Incomplete account/magic/broker/server/symbol/strategy key | 6 | Equally incomplete claimant/governed namespace; fence digest re-derived; governed initialization and takeover both reject |
| Current Lease clock ID/authority and insufficient expiry sequence | 3 | Direct typed clock inputs; fresh accepted fake-clock token; outer expiry sequence synchronized |
| Ordinary and zero-history UNCLAIMED/EXPIRED/RELEASED/CORRUPT | 8 | Direct Lease status mutation, positive baseline established |
| Basket enum/version, net-volume, full Broker tickets, transaction HWM, invalid Hard Kill enum | 6 | Vector source digest, Production checkpoint payload and affected Broker summary resealed |
| Policy, observed/prior/increasing exposure, three chronology fields, incomplete/foreign account | 9 | Persisted release digest, independent authority digest/reference and checkpoint resealed in parity |
| INACTIVE/ACTIVE/RELEASE_PENDING/RELEASED envelope contradiction | 4 | Checkpoint resealed; released-generation mismatch remains intentional |
| Zero-history incomplete owner | 1 | Fence and checkpoint/vector resealed; governed key remains complete and contradictory owner is rejected |
| Zero-history wrong clock | 1 | Direct current-Lease clock mismatch with valid positive zero-history control |
| **Total** | **38** | **26 re-sealed paths / 12 direct typed-status paths** |

The four positive controls cover ordinary ACQUIRED, ordinary RENEWED, zero-history ACQUIRED and zero-history RENEWED. Takeover negatives additionally require the existing positive takeover control to succeed first. All D.4 restart/release negatives use the supplied valid positive restart control before mutation; setup failure cannot satisfy them.

The historical 34 non-proving probes are retained, not rewritten or used as D.4 closure evidence. No old safety scenario is deleted.

## Takeover setup correction

The previous helper called UNCLAIMED-only `Initialize` and then EXPIRED-only `Takeover`, so it could not establish a successful takeover control. The new `SeedObservedLeaseForVerification` is explicitly test-only, one-shot, and seeds a canonical independently observed expired row. It does not create ownership or a grant. `Takeover` still validates all typed evidence before central CAS; the positive helper now verifies winner/readback, claimant identity, generation advance and changed fence.

This is a reference/test setup correction within D.4, not a new runtime load path. Publication, Claim, domain-CAS, Ledger, Genesis and Sequence are unchanged.

## Frozen predicate reuse

The reference-only dependency on the frozen `SW_V5_ReferenceValidators.mqh` reuses exact ownership completeness, active-heartbeat Lease, Basket, reconciliation-vector, Hard-Kill state, account and historical-release predicates. It does not modify or runtime-wire Production V5 or frozen Phase B/C. It prevents copied validators from drifting from the frozen contract rules.

## Executable verification

294 unique scenarios: 294 passed, 0 failed, 0 skipped. Two final invocations each performed two identical internal runs.

- D.4 additions: Takeover 9; Restart 20; Hard Kill 9; Zero History 8 (46 total).
- Retained scenarios: 248.
- Result digest: `861e930ea77b05e3f207351971429c127c15336c6659f6bf1b45da684b3d1f3e`.
- Durable-state digest: `a67f5a9f3e451f20a3203121df73a98f5ffa7b32678de1fb9c78d2fdfc6cd023`.
- Phase B: 139/139; Phase C: 22/22, approved digest unchanged.
- Six MetaEditor X64 Regular compiler-only manifests: 0 errors / 0 warnings each.

Fake store and fake clock are not SQLite, platform durability, real clock, cross-terminal or broker proof. D.4 independent re-audit is not yet performed. Phase D is incomplete; Phase E is not authorized.
