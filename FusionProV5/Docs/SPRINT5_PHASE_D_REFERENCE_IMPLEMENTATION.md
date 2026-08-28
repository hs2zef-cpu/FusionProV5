# Fusion Pro V5 Sprint 5 Phase D — Persistence / Restart Reference Implementation

> **Independent audit status: FAIL — Critical 3 / Major 7 / Minor 0.** The candidate described below is incomplete and does not authorize Phase E. Sprint 5 Phase D.1 is authorized to correct its frozen-authority-conformance and verification gaps.

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

- CAS compares the complete expected namespace, store revision, payload digest, and authority fence before staging one next revision.
- The result distinguishes the transaction that won now from a later read observing the same proposed state.
- A durable commit whose caller did not observe success is `COMMIT_OUTCOME_UNCERTAIN`; readback may discover it, but event-local authority is never recreated.
- `CLAIM_GRANTED_NOW` exists only on the exact observed Claim transaction winner. Persisted `INVOCATION_CLAIMED_UNRESOLVED`, restart, replay, and takeover never grant.
- Same-owner heartbeat advances store/liveness evidence while preserving owner, ownership namespace, lease version, takeover generation, and fencing digest.
- Takeover requires expiry, Broker reconciliation, Persistence reconciliation, fresh clock evidence, independent authority, and one exact CAS winner.
- Genesis is `ABSENT -> PROVISIONING -> READY_FOR_RECONCILIATION`, initializes every domain independently, starts with active Hard Kill generation 1, and uses a bootstrap checkpoint with `clean_shutdown=false`.
- A partial or corrupt genesis remains disabled and is not auto-repaired.
- The full ordered request set publishes first, must be authoritatively reloaded, and only then may a matching checkpoint publish.
- Restart requires the exact Broker positions/orders/deals/transactions union plus the separate Execution pending-request query, fresh owner-specific sequences, matching namespace/fence/account mode, and independent Hard Kill release authority.

## Verification result

| Gate | Result |
|---|---|
| Phase D executable reference | **127 / 127 PASS**, 0 failed, 0 skipped |
| Repeated deterministic runs | **2 — identical** |
| Final durable-state digest | `a1da58e9b0b78c0071a6f83cc9f3be28dae3b5e72fc3cc9576d48c0febfe1de9` |
| Reference result digest | `24c2becde97ef466e4478051619fd8c6c821050a98eb51190d057677dfc2830a` |
| Frozen Phase B verifier | **139 / 139 PASS**, MQL production executed false |
| Phase C reference regression | **22 scenarios PASS**, 2 identical runs |
| Phase D umbrella compile | **0 errors / 0 warnings**, X64 Regular |
| Phase D MQL assertions compile | **0 errors / 0 warnings**, X64 Regular |
| Frozen Phase B umbrella/assertions compile | **0 errors / 0 warnings**, X64 Regular |
| Phase C umbrella/assertions compile | **0 errors / 0 warnings**, X64 Regular |
| MQL assertions executed | **NO** |
| Forbidden executable API scan | **PASS — 0 matches** |

The recorded 127/127 Python result is historical evidence for the failed parallel oracle and is not MQL conformance proof. The next gate after D.1 correction is a **New Independent Sprint 5 Phase D.1 Persistence / Restart Re-Audit**. Phase E remains unauthorized.
