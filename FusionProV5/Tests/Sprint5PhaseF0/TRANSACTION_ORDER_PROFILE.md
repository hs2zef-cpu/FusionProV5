# Phase F0 Transaction / Callback Order Profile

TEST ONLY / F0 / DEMO MEASUREMENT REQUIRED.

**CALLBACK ORDER IS OBSERVATIONAL, NOT AUTHORITY.**

**CALLBACK ABSENCE HAS ZERO NEGATIVE-EVIDENCE VALUE.**

Known platform constraints preserved by this profile:

- trade-transaction arrival priority is not guaranteed;
- the transaction queue is finite;
- one request may generate several trade transactions;
- synchronous `OrderSend` output is not final deal/Basket confirmation;
- no invented monotonic callback-order field exists.

| Required profile case | Current raw runs | Status |
|---|---:|---|
| Normal submission | 1 | OBSERVED ONCE; accepted BUY, full-volume deal, order-to-deal-to-position linkage |
| Partial fill | 0 | DEMO REQUIRED / profile-dependent reproducibility |
| Delayed processing | 0 | DEMO REQUIRED |
| Read-only historical query across reconnect | 1 | Known entry and cleanup order/deal remained visible; open-position reconnect remains unproven |
| Duplicate-looking transactions | 0 | DEMO REQUIRED |
| Safe pressure/load observation | 0 | DEMO REQUIRED; operator-controlled |

The isolated probe can log synchronous results, `OnTrade`, and raw
`OnTradeTransaction` arrivals. It does not derive causal policy from the trace.
The request Magic is bound directly to `SWV5_RUNTIME_STRATEGY_MAGIC`; matching
Magic is strategy-scope evidence only and cannot confirm request identity,
submission outcome, order, deal, position, or Basket state by itself.
The one build-6180 API invocation emitted no `F0_TX` or `F0_ONTRADE`. That
absence is retained as raw observation only and proves neither delivery nor
non-delivery to the broker. No callback ordering, order lifecycle, or position
behavior has been empirically profiled.

The later corrected run emitted five `F0_TX` observations and seven `F0_ONTRADE`
observations for one successful request. The request callback exposed runtime
Magic, comment, retcode, and the session-local request ID; the query channel
later exposed the linked position, history order, and history deal. Arrival
order remains observational and is not promoted to authority. This single run
does not establish a general callback-order guarantee, duplicate-handling rule,
partial-fill model, or reconnect behavior.

Named empirical asymmetry `F0-EMP-MANUAL-CLEANUP-MAGIC-ZERO-ASYMMETRY`:
the separately authorized manual cleanup exit used Magic `0` while its order
and deal retained position ID `5055862979`. This is limited to the observed
manual-cleanup path and must not be generalized to SL, TP, stop-out, or other
broker-generated exits. The build-6182 reconnect check was query-only and did
not test callbacks, unresolved submission, or open exposure.
