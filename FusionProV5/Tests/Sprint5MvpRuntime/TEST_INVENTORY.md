# Demo MVP Runtime Authority Test Inventory

All tests are offline and non-submitting.

| Domain | Executed coverage |
|---|---|
| Symbol | exact symbol/digits/point/currency, completeness, exclusive expiry, live authority, pip convention, durable sequence/pinning |
| Risk | equity, daily loss, margin fraction, Basket loss, volume, notional, Basket count, freshness, completeness, Demo/USD/HEDGING, latch, unresolved operation |
| Margin | flat state, active orders, current margin ceiling, calculation failure, positive finite result, exact projected formula |
| Basket risk | protective stop presence/side, calculation failure, loss sign, fixed reserve, maximum loss, clean exposure, rollover denial |
| Trust/startup | explicit operator identity/role/authentication/time, 60-minute validity, partial genesis, reconciliation-only readiness, no auto-enable |
| Store/CAS | initial CAS, stale writer, one Claim winner, non-persisted event-local grant, rollback, reopen, namespace mismatch, terminal restart |
| Evidence/publication | callback full round trip, corruption rejection, exact synchronous identity binding, conflicting-ID rejection, BLOCKED sticky, terminal monotonicity |
| Execution observation | operation/enumeration status, reported/materialized/failure counts, omitted-row accounting, independent read/authority/sequence identities, persisted incomplete restart metadata |
| Hard Kill | genesis ACTIVE latch, ACTIVE→RELEASE_PENDING→RELEASED CAS sequence, independent authority binding, released-state restart persistence |
| Recovery | zero submission calls, no Claim grant reconstruction, independent evidence, incomplete-evidence preservation, stale publication denial |
| Isolation | no runtime OrderSend/OrderSendAsync/CTrade, read-only SymbolInfo/History/OrderCalc primitives only |
