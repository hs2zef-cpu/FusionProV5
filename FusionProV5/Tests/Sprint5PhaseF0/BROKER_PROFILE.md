# Phase F0 Broker Profile

TEST ONLY / F0 / DEMO ONLY / NOT FOR PRODUCTION.

## Measurement status

**BUILD-6180 POST-MAGIC ATTENDED DEMO PRE-SEND PROFILE OBSERVED — NO BROKER
CALL.**

Run `F0-6180-POST-MAGIC-PRESEND-001` was captured from a stable local build-6180
terminal using committed source `dc7b5e293894e9c6233b975f4d820efa2291eb55`.
Both runnable probes were freshly compiled by MetaEditor 6180, their installed
EX5 hashes matched the compiled artifacts, and the profile probe remained
default-disarmed. All pre-materialization observations are archival and are not
backfilled into this profile.

No broker submission, callback profile, retcode, fill, order, position, or
comment-carrier preservation claim was produced by this pre-send run.

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
| Server/local time | Two post-materialization samples; local minus server = +25,200 seconds in both samples |
| Connection state | `connected=1` in all post-materialization observations |

The isolated probe prints these values but is disarmed by default. Its output is
evidence only after Demo and HEDGING are positively attested during an attended
run. No profile portability to another broker, server, account, symbol, or build
may be inferred.

This profile is scoped only to Exness Technologies Ltd / Exness-MT5Trial6 /
Demo / HEDGING / XAUUSD / terminal and MQL build 6180. It is not portable to a
different broker, server, account mode, symbol, or build.

The fresh disarmed lifecycle completed with
`F0_DEINIT|reason=1|send_attempted=0`. No `F0_SYNC`, `F0_TX`, `F0_ONTRADE`,
retry, pending-order, broker-submission, or `OrderSend` execution evidence was
present. This profile satisfies the post-materialization pre-send observation
gate but does not itself authorize a send; separate explicit confirmation is
still required.
