# Fusion Pro V5 Sprint 5 Phase D — Persistence / Restart Reference Implementation

> **Phase D.3 final independent re-audit status: FAIL — Critical 3 / Major 3 / Minor 0.** Sprint 5 Phase D.4 is a narrow corrective self-verification candidate and remains subject to a new independent final re-audit; Phase E is not authorized.

## Scope and status

Sprint 5 Phase D implements a deterministic reference model only. It uses an in-memory fake transactional store and explicitly supplied fake authoritative clock/query observations. It has no physical persistence, real SQLite adapter, real platform clock, broker access, runtime wiring, MT5 Terminal execution, or Strategy Tester execution.

Phase D does not prove database locking, cross-terminal contention, filesystem durability, actual platform crash behavior, or real server-time provenance. Those remain subject to separate later authorization and evidence.

## Authority domains

Every conditional mutation belongs to exactly one independently revised domain:

1. Genesis/schema metadata
2. Lease/clock observations
3. Host Ingress Ledger
4. Request Sequence Authority
5. Submission Permit / Invocation Claim journal
6. Pending Request Set publication
7. Checkpoint publication

There is no global transaction. A partial cross-domain combination remains dirty/unresolved and cannot establish readiness.

## Core semantics

- Each authority domain validates a complete typed proposed state, derives its own canonical row, and only then calls central CAS; CAS also compares the complete expected namespace, store revision, payload digest, and authority fence.
- The result distinguishes the transaction that won now from a later read observing the same proposed state.
- A durable commit whose caller did not observe success is `COMMIT_OUTCOME_UNCERTAIN`; readback may discover it, but event-local authority is never recreated.
- `CLAIM_GRANTED_NOW` exists only on the exact observed Claim transaction winner. Persisted `INVOCATION_CLAIMED_UNRESOLVED`, restart, replay, and takeover never grant.
- Same-owner heartbeat advances store/liveness evidence while preserving owner, ownership namespace, lease version, takeover generation, and fencing digest.
- Takeover validates every frozen V5 envelope version, complete claimant identity, exact outer/expiry/current observation time, complete Persistence Namespace, typed Broker/Persistence reconciliation, independent authority, and one exact CAS winner.
- Genesis is `ABSENT -> PROVISIONING -> READY_FOR_RECONCILIATION`, initializes every domain independently, starts with active Hard Kill generation 1, and uses a bootstrap checkpoint with `clean_shutdown=false`.
- A partial or corrupt genesis remains disabled and is not auto-repaired.
- The full ordered request set publishes with distinct frozen set and durable-row digests, must be authoritatively reloaded, and only then may a matching checkpoint publish.
- Restart validates the exact frozen Production V5 LP2 checkpoint payload and complete reconciliation-vector source digest, requires Basket reconciliation `MATCHED`, binds Basket state/version and Hard Kill generation, scans every persisted request, and requires complete fresh Broker/Execution query authority. ADR-022 zero-history is accepted only for an exact Genesis zero-state with no fabricated correlation, Broker identity, or transaction HWM. A released Hard Kill also requires a fully validated persisted release envelope and independent authority record effective at the supplied clock.
- Publication results remain `PROPOSAL_VALID` during pure evaluation and become `COMMITTED` only after the reference store wins CAS and verifies authoritative readback; failed, uncertain, or unreadable outcomes never claim committed authority.

## Verification result

| Gate | Result |
|---|---|
| Phase D.4 executable reference | **294 / 294 PASS**, 0 failed, 0 skipped, 294 unique IDs |
| Repeated deterministic runs | **2 — identical** |
| Final durable-state digest | `a67f5a9f3e451f20a3203121df73a98f5ffa7b32678de1fb9c78d2fdfc6cd023` |
| Reference result digest | `861e930ea77b05e3f207351971429c127c15336c6659f6bf1b45da684b3d1f3e` |
| Frozen Phase B verifier | **139 / 139 PASS**, MQL production executed false |
| Phase C reference regression | **22 scenarios PASS**, 2 identical runs |
| Phase D umbrella compile | **0 errors / 0 warnings**, X64 Regular |
| Phase D MQL assertions compile | **0 errors / 0 warnings**, X64 Regular |
| Frozen Phase B umbrella/assertions compile | **0 errors / 0 warnings**, X64 Regular |
| Phase C umbrella/assertions compile | **0 errors / 0 warnings**, X64 Regular |
| MQL assertions executed | **NO** |
| Forbidden executable API scan | **PASS — 0 matches** |

The Python result is an independent executable adversarial oracle aligned with the corrected boundaries, not MQL conformance proof. The MQL source defines 17 positive and 157 negative named assertion functions; they compile but are not executed. The previous independent audit credited 19 complete re-sealed semantic probes and identified 34 non-creditable legacy probes; D.4 adds 38 direct negative closure probes: 26 re-sealed paths and 12 direct typed/status paths, plus four positive active-Lease controls without claiming that compile-only presence is runtime proof. The next gate is a **New Independent Sprint 5 Phase D.4 Final Persistence / Restart Re-Audit**. Phase E remains unauthorized.

## D.4 conformance closure

The reference reuses the frozen complete ownership-key/owner, active-heartbeat Lease, Basket, reconciliation-vector, Hard-Kill state, account-namespace, and historical release predicates. Takeover additionally binds the current Lease clock and expiry sequence. Ordinary and zero-history restart share one active Lease gate and both accept valid ACQUIRED and RENEWED states. Release evidence and independent authority require exact `HARD-KILL-RELEASE-V5`, complete account identity, nonnegative non-increasing exposure, and authentication/evidence chronology.

Takeover probe setup now uses an explicit TEST ONLY observed-expired-row seed: ordinary initialization remains UNCLAIMED-only, and no seed grants authority. D.4 negatives first establish a valid positive control. This removes setup-failure false positives without changing central CAS or the independently closed Publication, Claim, Ledger, Genesis, or Sequence semantics. See `../Tests/Sprint5PhaseD/D4_SEMANTIC_EVIDENCE.md`.
