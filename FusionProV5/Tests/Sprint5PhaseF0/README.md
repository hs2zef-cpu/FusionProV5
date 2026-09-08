# Sprint 5 Phase F0 — Broker Profile / Evidence Gate

TEST ONLY / F0 / DEMO ONLY / NOT FOR PRODUCTION.

Phase F0 prepares and measures the exact evidence needed before Fusion can
decide whether Phase F implementation is safe. It does not implement a Broker
Adapter and grants no execution, recovery, Risk, Basket, or production
authority.

Current empirical status: **ONE CORRECTED BUILD-6180 STRATEGY BUY CONFIRMED;
SEPARATE MANUAL CLEANUP COMPLETE.** From corrected committed source
`e5411a5...`, all four preflight permissions were true before exactly one
attended Demo/HEDGING BUY. The query channel then observed position/order
`5055862979`, deal `4360221913`, Magic `1179670069`, comment
`F0-NR2-BUY-20260907`, volume `0.01`, and execution price `4413.493`.

A separately authorized manual operator cleanup produced Magic-zero SELL order
`5055880854` and exit deal `4360237506`, linked to position `5055862979` for the
full `0.01` volume. The cleanup is not strategy identity or a second strategy
entry. The post-cleanup query reported zero positions and active orders. Query
completeness remains `UNPROVEN`; zero totals are not generalized into
authoritative emptiness or negative evidence.

The earlier client-local rejection remains immutable historical evidence. No
retry, reconnect, pending order, automatic close, or second strategy entry
occurred in the corrected run. Runtime strategy identity remains frozen as
`SWV5_RUNTIME_STRATEGY_MAGIC=1179670069`. No further `OrderSend` is authorized.

## Offline verification

```powershell
python -B FusionProV5/Tests/Sprint5PhaseF0/verify_phase_f0_negative_controls.py
python -B FusionProV5/Tests/Sprint5PhaseF0/verify_phase_f0_source.py
```

`SW_V5_S5_PHASE_F0_COMPILE.mq5` is a compile-only evidence-contract manifest.
`SW_V5_S5_PHASE_F0_DEMO_PROFILE_PROBE.mq5` is an isolated, default-disarmed,
single-send attended-Demo probe. Never run it on live/real-money, NETTING,
unattended, production VPS, or production paths.

`SW_V5_S5_PHASE_F0_QUERY_PROBE.mq5` is read-only and reports positions, orders,
history orders, history deals, window bounds, and per-row read failures. It never
certifies completeness from row count and performs no broker mutation. Its
Magic classification reports runtime match, fixture/reference, zero, or
unrelated while explicitly denying Magic-only correlation authority.

`SW_V5_S5_PHASE_F0_QUERY_POSITIVE_CONTROL.mq5` is a read-only build/run-boundary
probe for the known F0 entry and cleanup records. Build-6182 PRE/POST reconnect
evidence passed the fixed inclusion/exclusion/filter/depth matrix. Its result is
limited to the tested controls; completeness remains `UNPROVEN`, and the
observed linkage is RUN-SCOPED / NON-AUTHORITATIVE.

`ATTENDED_DEMO_RUNBOOK.md` defines the mandatory operator-present safety gate.
It is preparation only and does not authorize running the probe unattended.

Phase F and Phase G remain NOT AUTHORIZED. No main merge or Architecture Lock is
authorized.
