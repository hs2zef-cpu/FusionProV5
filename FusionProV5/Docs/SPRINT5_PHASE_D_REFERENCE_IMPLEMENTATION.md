# Fusion Pro V5 Sprint 5 Phase D — Persistence / Restart Reference Implementation

> **Phase D.2 final independent re-audit status: FAIL — Critical 3 / Major 4 / Minor 0.** Sprint 5 Phase D.3 is a narrow corrective self-verification candidate and remains subject to a new independent final re-audit; Phase E is not authorized.

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
| Phase D.3 executable reference | **248 / 248 PASS**, 0 failed, 0 skipped, 248 unique IDs |
| Repeated deterministic runs | **2 — identical** |
| Final durable-state digest | `7071f39e85ebea680f8359678f349ce3f92fca4553ae24078d8955982bd2061d` |
| Reference result digest | `4536625d1183eb3204766b54f3ca3c2e742d427a5d9ed1fa7b23129c9aa45b85` |
| Frozen Phase B verifier | **139 / 139 PASS**, MQL production executed false |
| Phase C reference regression | **22 scenarios PASS**, 2 identical runs |
| Phase D umbrella compile | **0 errors / 0 warnings**, X64 Regular |
| Phase D MQL assertions compile | **0 errors / 0 warnings**, X64 Regular |
| Frozen Phase B umbrella/assertions compile | **0 errors / 0 warnings**, X64 Regular |
| Phase C umbrella/assertions compile | **0 errors / 0 warnings**, X64 Regular |
| MQL assertions executed | **NO** |
| Forbidden executable API scan | **PASS — 0 matches** |

The Python result is an independent executable adversarial oracle aligned with the corrected boundaries, not MQL conformance proof. The MQL source defines 13 positive and 119 negative named assertion functions; they compile but are not executed. The previous independent audit credited 19 complete re-sealed semantic probes and identified 34 non-creditable legacy probes; D.3 adds direct typed and fully re-sealed probes for each current headline finding without claiming that compile-only presence is runtime proof. The next gate is a **New Independent Sprint 5 Phase D.3 Final Persistence / Restart Re-Audit**. Phase E remains unauthorized.
