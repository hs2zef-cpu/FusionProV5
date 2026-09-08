# Phase F0 Broker Profile

TEST ONLY / F0 / DEMO ONLY / NOT FOR PRODUCTION.

## Measurement status

**BUILD-6180 SINGLE SUCCESSFUL MARKET BUY OBSERVED — NARROW PROFILE ONLY.**

Run `F0-6180-SUCCESSFUL-BUY-CLEANUP-001` used corrected committed source
`e5411a522247d48889701353f89bdf13968f7ab8`. All four permission properties
were `1` before the sole `OrderSend`. The broker returned retcode `10009`,
order/position `5055862979`, and deal `4360221913`; the following query observed
the matching BUY position, history order, and history deal at volume `0.01` and
price `4413.493`. This proves only the behavior of this one request on this exact
profile. It is not a general broker-behavior certification.

A separately authorized manual operator cleanup produced Magic-zero SELL order
`5055880854` and exit deal `4360237506`, linked to position `5055862979`, for the
full `0.01` volume. The post-cleanup query reported zero positions and zero
active orders. Magic zero identifies the cleanup as non-strategy activity; the
position linkage identifies what it closed. Query completeness remains
`UNPROVEN`.

Run `F0-6180-POST-MAGIC-PRESEND-001` was captured from a stable local build-6180
terminal using committed source `dc7b5e293894e9c6233b975f4d820efa2291eb55`.
Both runnable probes were freshly compiled by MetaEditor 6180, their installed
EX5 hashes matched the compiled artifacts, and the profile probe remained
default-disarmed. All pre-materialization observations are archival and are not
backfilled into this profile.

The later run `F0-6180-CLIENT-LOCAL-REJECT-001` invoked `OrderSend` once from the
same executable source. The client rejected the call because AutoTrading was
disabled. The result produced no request ID, order, deal, callback, fill,
position, or broker-carried comment evidence. It therefore profiles the local
terminal gate only, not broker acceptance/rejection behavior.

## Required exact profile fields

| Field | Current evidence |
|---|---|
| Broker name | Exness Technologies Ltd |
| Server | Exness-MT5Trial6 |
| Login identity | Freshly derived stable SHA-256 redacted hash in `F0-6180-POST-MAGIC-PRESEND-001.json`; raw login prohibited |
| Account trade mode | Demo, operator-attested and journal-observed |
| Margin mode | Retail HEDGING, operator-attested and journal-observed |
| Terminal / MQL build | 6180 / 6180 |
| Compiler build | MetaEditor 6180; X64 Regular; both probes 0 errors / 0 warnings |
| Exact symbol | XAUUSD |
| Digits / point | 3 / 0.001 |
| Tick size / value | 0.001 / 0.1; profit and loss tick values both 0.1 |
| Contract size | 100 |
| Volume min / max / step | 0.01 / 200 / 0.01 |
| Stops / freeze level | 0 / 0 |
| Symbol trade / execution mode | 4 / 2 |
| Filling-mode flags | 1; FOK capability observed |
| Pending-order scope | Excluded; market/increasing probe only |
| Frozen strategy Magic | `SWV5_RUNTIME_STRATEGY_MAGIC=1179670069` (`0x46505635`, `FPV5`) in `Configuration/SW_V5_RuntimeIdentityProfile.mqh` |
| Server/local time | Eleven post-materialization samples; local minus server = +25,200 seconds in all samples |
| Connection state | `connected=1` in all post-materialization observations |

The isolated probe prints these values but is disarmed by default. Its output is
evidence only after Demo and HEDGING are positively attested during an attended
run. No profile portability to another broker, server, account, symbol, or build
may be inferred.

This profile is scoped only to Exness Technologies Ltd / Exness-MT5Trial6 /
Demo / HEDGING / XAUUSD / terminal and MQL build 6180. It is not portable to a
different broker, server, account mode, symbol, or build.

The historical disarmed lifecycle completed with `send_attempted=0`. The later
armed lifecycle completed with `send_attempted=1`, exactly one failed API
invocation, and no retry. Its post-attempt zero-row query remains `UNPROVEN` and
cannot certify absence of a side effect. No additional send is authorized.

The corrective four-property permission snapshot and fail-closed pre-call
checks were empirically exercised by the successful run. No retry, second
strategy entry, reconnect, pending order, or automatic close occurred. No
additional `OrderSend` is authorized.

## Build-6182 read-only follow-up

Build 6180 remains the immutable successful send/cleanup profile. A separate
build-6182 run boundary recompiled the ordinary query and new positive-control
probes and performed no broker mutation. PRE/POST attestations matched this same
Demo/HEDGING broker, server, account, and symbol profile. Both known entry and
cleanup order/deal pairs remained visible across an attended same-terminal
reconnect/restart, and the tested window/filter/depth controls behaved as
specified. This profiles read-only historical visibility only. It does not
extend the build-6180 send profile or authorize any new `OrderSend`.
