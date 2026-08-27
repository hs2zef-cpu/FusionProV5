# Sprint 5 Phase C.2 test inventory

MQL assertions are **present and compiled, not executed**. Direct actual-function controls cover:

- ordinal-0 binding and explicit retry-ordinal separation;
- complete Ledger snapshot/current-membership validation, exact frozen-shaped commit binding, complete post-state validation, valid NEW/DUPLICATE/no-entry, and malformed header/index/record/linkage/correlation/reservation cases;
- complete Sequence current-state validation, exact frozen proposal/owner binding, resulting-state validation, valid new/idempotent reservations, and fabricated/stale/corrupt/changed/colliding reservations;
- frozen initial Blueprint validation;
- V5 phase-transition authority and full immutable request-content preservation, including both direction reversals and fifteen other one-field mutations;
- complete valid prepared/Claim pair, exactly once, ten full-result corruptions, split package, prior-event replay, crash boundaries, Hard Kill, Trust, and Risk expiry;
- all six public coordinator handlers.

Queue-dispatched compile-only MQL controls cover full BUY and SELL, duplicate ingress/admission, WAIT, BLOCKED, two distinct requests, progression, admission, takeover ordering, both crash boundaries, claimed-unresolved reconciliation, fake-broker invocation, and acknowledgement classification. Fake-broker direction is derived from the authoritative Claim/Permit/Risk graph, never from a queue flag.

The executed reference model contains 22 deterministic cases:

1. BUY
2. SELL
3. duplicate ingress
4. WAIT
5. BLOCKED
6. two requests
7. request progression
8. malformed Ledger authority
9. malformed Sequence authority
10. direction-reversal progression
11. duplicate admission
12. takeover before Claim
13. Claim before takeover
14. crash before Claim and recollect
15. crash after Claim
16. uncertain follow-up
17. Claim mismatch family
18. prior-event grant replay
19. Hard Kill denial
20. Trust denial
21. Risk `<`, `==`, and `>` expiry
22. acknowledgement-not-confirmation response

Each reference case runs twice with identical results and traces. Determinism does not prove frozen Phase B correctness.
