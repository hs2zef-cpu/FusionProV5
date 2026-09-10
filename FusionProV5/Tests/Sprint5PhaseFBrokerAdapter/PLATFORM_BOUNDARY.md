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

There is no `OrderSendAsync`, `CTrade`, position open/close helper, pending-order
construction, retry loop, timer/tick handler, reconnect-driven invocation, or
`OnTradeTransaction` implementation. A future host may forward its callback to
`CaptureCallback`, which resolves an existing durable submission mapping before
persisting observational evidence. The adapter itself never installs an event
handler or reconstructs Claim authority.
