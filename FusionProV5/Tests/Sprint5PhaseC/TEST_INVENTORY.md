# Sprint 5 Phase C.1 test inventory

MQL assertions are **present and compiled, not executed**. Direct controls cover ordinal 0/1 fixed vectors, a complete valid prepared/Claim pair, exactly once, duplicate denial, ten full-result corruptions, Prepared-A/Command-B, prior-event replay, both crash boundaries, recollection, frozen Ledger/Sequence/Blueprint controls, takeover, reconciliation, acknowledgement classification, conforming Hard Kill/Trust/Risk denials, and queue dispatch.

The executed reference model contains 19 deterministic cases:

1. BUY end-to-end
2. SELL end-to-end
3. duplicate ingress
4. WAIT
5. BLOCKED
6. two requests
7. request progression
8. duplicate admission
9. takeover before Claim
10. Claim before takeover
11. crash before Claim and recollect
12. crash after Claim
13. uncertain follow-up
14. Claim mismatch family
15. prior-event grant replay
16. Hard Kill denial
17. Trust denial
18. Risk `<`, `==`, and `>` expiry
19. acknowledgement-not-confirmation response

Each reference case runs twice with identical results and traces. Determinism does not prove frozen Phase B correctness.
