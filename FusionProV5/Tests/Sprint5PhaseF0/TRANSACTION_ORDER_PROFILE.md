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
| Normal submission | 0 | NOT REACHED; one client-local rejection before broker acknowledgement |
| Partial fill | 0 | DEMO REQUIRED / profile-dependent reproducibility |
| Delayed processing | 0 | DEMO REQUIRED |
| Reconnect | 0 | DEMO REQUIRED |
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
