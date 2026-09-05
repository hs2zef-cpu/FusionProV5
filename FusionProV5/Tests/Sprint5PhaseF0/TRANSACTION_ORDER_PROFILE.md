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
| Normal submission | 0 | DEMO REQUIRED |
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
No callback/order behavior has been empirically profiled in this run.
