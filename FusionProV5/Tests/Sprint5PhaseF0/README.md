# Sprint 5 Phase F0 — Broker Profile / Evidence Gate

TEST ONLY / F0 / DEMO ONLY / NOT FOR PRODUCTION.

Phase F0 prepares and measures the exact evidence needed before Fusion can
decide whether Phase F implementation is safe. It does not implement a Broker
Adapter and grants no execution, recovery, Risk, Basket, or production
authority.

Current empirical status: **BUILD-6180 POST-MAGIC PRE-SEND GATE PASS; NO BROKER
CALL.** An operator-present Demo/HEDGING run executed one fresh read-only query
and one default-disarmed environment/profile observation on Exness-MT5Trial6 /
XAUUSD from accepted source `dc7b5e2...`. Query completeness remains `UNPROVEN`.
No probe was armed, and no retcode, callback, fill, position, broker correlation,
reconnect, or negative-side-effect evidence has been produced.

The post-materialization lifecycle completed with `send_attempted=0`. Runtime
strategy identity is frozen as
`SWV5_RUNTIME_STRATEGY_MAGIC=1179670069` in
`Configuration/SW_V5_RuntimeIdentityProfile.mqh`; fixture/reference values are
not runtime authority. The fresh gate permits requesting a separate explicit
final confirmation; it does not authorize or perform a send itself.

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
