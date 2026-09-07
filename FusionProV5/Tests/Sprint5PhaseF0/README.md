# Sprint 5 Phase F0 — Broker Profile / Evidence Gate

TEST ONLY / F0 / DEMO ONLY / NOT FOR PRODUCTION.

Phase F0 prepares and measures the exact evidence needed before Fusion can
decide whether Phase F implementation is safe. It does not implement a Broker
Adapter and grants no execution, recovery, Risk, Basket, or production
authority.

Current empirical status: **BUILD-6180 SINGLE-SEND ATTEMPT CONSUMED; CLIENT-LOCAL
REJECTION; PHASE F0 BLOCKED.** From clean evidence baseline `35186ca...`, the
operator explicitly confirmed one attended Demo/HEDGING BUY measurement. The
probe invoked `OrderSend` exactly once, but the terminal rejected it locally
with `last_error=4752`, `retcode=10027`, and comment `AutoTrading disabled by
client`. No request ID, order, deal, callback, fill, position, or broker-carried
correlation evidence was produced.

The armed lifecycle completed with `F0_DEINIT|reason=1|send_attempted=1`, without
retry or reattach. A post-attempt query reported zero rows in all four domains,
but completeness remains `UNPROVEN`; this is not authoritative proof of no side
effect. Runtime strategy identity remains frozen as
`SWV5_RUNTIME_STRATEGY_MAGIC=1179670069` in
`Configuration/SW_V5_RuntimeIdentityProfile.mqh`; fixture/reference values are
not runtime authority. The one-send allowance for this run is consumed. A new
send requires a new clean run boundary and explicit Fusion authorization.

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

`ATTENDED_DEMO_RUNBOOK.md` defines the mandatory operator-present safety gate.
It is preparation only and does not authorize running the probe unattended.

Phase F and Phase G remain NOT AUTHORIZED. No main merge or Architecture Lock is
authorized.
