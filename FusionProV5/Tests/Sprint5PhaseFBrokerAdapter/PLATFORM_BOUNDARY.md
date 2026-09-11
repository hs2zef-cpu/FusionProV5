# Exact MT5 API Boundary

All direct MT5 calls introduced by Phase F are confined to
`ExecutionLayer/BrokerAdapter/SW_V5_S5_F_BrokerPlatformBoundary.mqh`.

The boundary reads account/environment state with `AccountInfoInteger`,
`AccountInfoString`, `TerminalInfoInteger`, and `MQLInfoInteger`; reads symbol
capabilities with `SymbolInfoInteger` and `SymbolInfoDouble`; enumerates current
positions/orders with `PositionsTotal`, `PositionGet*`, `OrdersTotal`, and
`OrderGet*`; selects and enumerates history with `HistorySelect`,
`HistoryOrdersTotal`, `HistoryOrderGet*`, `HistoryDealsTotal`, and
`HistoryDealGet*`; timestamps observations with `TimeTradeServer`; and contains
one guarded synchronous `OrderSend` call.

Immediately before that call the boundary re-samples terminal/MQL/account/expert
permissions, the exact profile, and symbol specification; constructs a neutral
field-for-field copy of the final `MqlTradeRequest`; and verifies its caller-bound
wire digest. No normalization, filling coercion, or request-field assignment is
permitted after the digest. The source verifier proves one `OrderSend` token in
the submission method and rejects loop/retry shape.

This sequence narrows but cannot remove the irreducible interval between the
last platform read and the send. The adapter makes no atomicity claim for that
interval; ambiguity is reconciled as unresolved and cannot trigger a retry.

There is no `OrderSendAsync`, `CTrade`, position open/close helper, pending-order
construction, retry loop, timer/tick handler, reconnect-driven invocation, or
`OnTradeTransaction` implementation. A future host may forward its callback to
`CaptureCallback`, which resolves an existing durable submission mapping before
persisting observational evidence. The adapter itself never installs an event
handler or reconstructs Claim authority.

Query completeness is based on reported totals, enumerated row counts, and
per-row read status. A missing row or failed read fails closed. The adapter may
consume an independently governed capability-proof digest, but its interfaces
cannot create, approve, or persist that proof. Broker and Execution observations
must carry distinct read-path, authority-instance, sequence-authority, snapshot,
and digest identities.
