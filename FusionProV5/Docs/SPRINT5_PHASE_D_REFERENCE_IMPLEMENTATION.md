# Fusion Pro V5 Sprint 5 Phase D — Persistence / Restart Reference Implementation

> **Phase D.1 independent re-audit status: FAIL — Critical 3 / Major 5 / Minor 0.** Sprint 5 Phase D.2 is the authorized narrow corrective implementation and remains subject to a new independent final re-audit; Phase E is not authorized.

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
- Takeover requires the complete Persistence Namespace, typed Broker/Persistence reconciliation, expiry, fresh clock evidence, independent authority, and one exact CAS winner.
- Genesis is `ABSENT -> PROVISIONING -> READY_FOR_RECONCILIATION`, initializes every domain independently, starts with active Hard Kill generation 1, and uses a bootstrap checkpoint with `clean_shutdown=false`.
- A partial or corrupt genesis remains disabled and is not auto-repaired.
- The full ordered request set publishes with distinct frozen set and durable-row digests, must be authoritatively reloaded, and only then may a matching checkpoint publish.
- Restart binds complete Broker and Execution summary digests, reconciles checkpoint/vector/request relations, scans every persisted request, and requires the exact Broker positions/orders/deals/transactions union plus the separate Execution pending-request query, fresh owner-specific sequences, matching namespace/fence/account mode, and independent Hard Kill release authority.

## Verification result

| Gate | Result |
|---|---|
| Phase D.2 executable reference | **209 / 209 PASS**, 0 failed, 0 skipped, 209 unique IDs |
| Repeated deterministic runs | **2 — identical** |
| Final durable-state digest | `75ca56a79a70d8bfd5025acf30eb535a1999bba19c1ccd11c61f2e674df3ef76` |
| Reference result digest | `031318a4721b377ae323ccaae4dc0c2c273fceb8470ad98b7667c9b8d083d4a4` |
| Frozen Phase B verifier | **139 / 139 PASS**, MQL production executed false |
| Phase C reference regression | **22 scenarios PASS**, 2 identical runs |
| Phase D umbrella compile | **0 errors / 0 warnings**, X64 Regular |
| Phase D MQL assertions compile | **0 errors / 0 warnings**, X64 Regular |
| Frozen Phase B umbrella/assertions compile | **0 errors / 0 warnings**, X64 Regular |
| Phase C umbrella/assertions compile | **0 errors / 0 warnings**, X64 Regular |
| MQL assertions executed | **NO** |
| Forbidden executable API scan | **PASS — 0 matches** |

The Python result is an independent executable adversarial oracle aligned with the corrected boundaries, not MQL conformance proof. The MQL source provides 10 positive and 86 negative compile-only probes, including 28 re-sealed semantic probes; those assertions were not executed. The next gate is a **New Independent Sprint 5 Phase D.2 Final Persistence / Restart Re-Audit**. Phase E remains unauthorized.
