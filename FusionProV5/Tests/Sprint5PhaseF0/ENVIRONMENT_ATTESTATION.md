# Phase F0 Environment Attestation

TEST ONLY / F0 / NO CREDENTIALS.

## Successful run F0-6180-SUCCESSFUL-BUY-CLEANUP-001

Corrected source `e5411a522247d48889701353f89bdf13968f7ab8` was compiled with
MetaEditor 6180. Installed query/profile EX5 hashes matched the fresh artifacts.
The pre-send and armed observations both reported build 6180, Demo, Retail
HEDGING, Exness Technologies Ltd / Exness-MT5Trial6, XAUUSD, connected, and all
four trading permissions equal to `1`.

Exactly one strategy BUY at minimum volume `0.01` was observed and positively
reconstructed. The separately authorized manual cleanup was not a strategy
retry or second strategy entry. Post-cleanup positions and active orders were
reported as zero; query completeness remains `UNPROVEN`. No reconnect occurred,
and no further `OrderSend` is authorized.

## Read-only follow-up F0-6182-POSITIVE-CONTROL-RECONNECT-001

This is a separate build/run boundary. Both PRE_RECONNECT and POST_RECONNECT
reported terminal/MQL build 6182, Demo, Retail HEDGING, Exness Technologies Ltd
/ Exness-MT5Trial6, XAUUSD, and `connected=1`. The ordinary and positive-control
sources and freshly compiled/installed EX5 artifacts are identified by SHA-256
in the evidence file. No build-6180 binary or current-build attestation was
reused as build-6182 evidence. The run was read-only and made no `OrderSend`.

## Historical empirical run F0-6180-CLIENT-LOCAL-REJECT-001

| Field | Result |
|---|---|
| Observation date | 2026-09-07 |
| Repository baseline commit/tree | `35186ca036f9222cd85e6309ff33966b1bd9242f` / `56cbfb310bb930e213b353c5d0466a400e083a02` |
| Executable-source commit/tree | `dc7b5e293894e9c6233b975f4d820efa2291eb55` / `38bc1d3577ce22955bf9ec59f1f757e6d29d4414` |
| Broker/server | Exness Technologies Ltd / Exness-MT5Trial6 |
| Account trade/margin mode | `0` Demo / `2` Retail HEDGING |
| Symbol/chart | XAUUSD, M15 |
| Terminal/MQL build | 6180 / 6180 |
| Runtime identity | `SWV5_RUNTIME_STRATEGY_MAGIC=1179670069` |
| Intended measurement | One market BUY, minimum volume `0.01`, FOK, comment `F0R-0907-151028` |
| API invocation | Exactly one `OrderSend` call; no retry or reattach |
| Synchronous result | `transport_result=0`, `last_error=4752`, `retcode=10027`, `request_id=0`, `order=0`, `deal=0` |
| Result classification | Client-local post-invocation rejection; fail-closed R4 pending Fusion classification decision |
| Callback trace | No `F0_TX` or `F0_ONTRADE`; absence is not negative evidence |
| Lifecycle close | `F0_DEINIT|reason=1|send_attempted=1` |
| Post-attempt query | API success; positions/orders/history orders/history deals all reported 0; every domain `UNPROVEN` |
| Manual cleanup | NOT REQUIRED by observed query; no exposure was observed, but authoritative absence was not proven |
| Reconnect | NOT PERFORMED |
| Strategy Tester | NOT USED |

The terminal recorded `automated trading is enabled` only after the rejected
attempt. That state change is a new environment boundary and does not transform
the prior rejection into acceptance or authorize a retry. The attached armed EA
was removed before the post-attempt query.

## Current post-materialization run F0-6180-POST-MAGIC-PRESEND-001

| Field | Result |
|---|---|
| Observation date | 2026-09-05 |
| Source commit/tree | `dc7b5e293894e9c6233b975f4d820efa2291eb55` / `38bc1d3577ce22955bf9ec59f1f757e6d29d4414` |
| Broker/server | Exness Technologies Ltd / Exness-MT5Trial6 |
| Account trade/margin mode | `0` Demo / `2` Retail HEDGING |
| Symbol/chart | XAUUSD, M15 |
| Terminal/MQL/MetaEditor build | 6180 / 6180 / 6180 |
| Compile result | Query, profile, and contract manifest: X64 Regular, 0 errors / 0 warnings |
| Installed binary identity | Query and profile EX5 SHA-256 exactly match fresh compiled artifacts |
| Connection/history selection | `connected=1`; `history_select_success=1`; `last_error=0` |
| Query window | 86,400 server-time seconds |
| Runtime identity | `SWV5_RUNTIME_STRATEGY_MAGIC=1179670069`; SSOT marker observed in both probes |
| Query disposition | All domains `UNPROVEN`; 1 total history-deal row, 0 runtime-strategy-matching rows, and 1 Magic-zero non-XAUUSD account/balance row |
| Profile disposition | `F0_DISARMED|environment_observation_only` |
| Lifecycle close | `F0_DEINIT|reason=1|send_attempted=0` |
| Broker/trade markers | No `F0_SYNC`, `F0_TX`, `F0_ONTRADE`, retry, pending-order, or broker submission |
| Strategy Tester | NOT USED |

The account identity hash was derived afresh from the current terminal log and
matched the prior stable redacted value; no raw login or credential is stored.

## Historical pre-materialization build-6180 run F0-6180-PRESEND-001

| Field | Result |
|---|---|
| Observation date | 2026-09-05 |
| Source commit/tree | `c41378d5e067568b81ecae4bffb06891d960d11f` / `1943fc53e1b970f65528ec41f0805e5a6bf5410f` |
| Broker/server | Exness Technologies Ltd / Exness-MT5Trial6 |
| Account trade mode | `0` = Demo |
| Account margin mode | `2` = Retail HEDGING |
| Demo/HEDGING attested | YES; runtime and operator evidence |
| Symbol/chart | XAUUSD, M15 |
| Terminal/MQL build | 6180 / 6180 |
| MetaEditor build | 6180; both probes compiled X64 Regular with 0 errors / 0 warnings |
| Connection | `connected=1` in both query and profile observations |
| Query runs | Two read-only runs, 41 seconds apart, before profile observation |
| Profile disposition | `F0_DISARMED|environment_observation_only` |
| Broker calls | NONE |
| Strategy Tester | NOT USED |

No `F0_SYNC`, `F0_TX`, or `F0_ONTRADE` marker was emitted. No login,
password, token, or account secret is stored; only a stable one-way
account-identity hash is present in the sanitized evidence record.

## Archived pre-6180 run F0-QRY-001

| Field | Result |
|---|---|
| Observation date | 2026-09-05 |
| Source commit/tree | `c41378d5e067568b81ecae4bffb06891d960d11f` / `1943fc53e1b970f65528ec41f0805e5a6bf5410f` |
| Running MT5 Terminal detected | YES |
| Running MetaTester detected | NO |
| Broker/server | Exness Technologies Ltd / Exness-MT5Trial6 |
| Account classification | Demo; operator-attested and journal-observed |
| Margin mode | Retail HEDGING; operator-attested and journal-observed |
| Demo attested | YES |
| HEDGING attested | YES |
| Symbol context | XAUUSD, M15 |
| Terminal build at query | 6090 |
| Current terminal build after automatic update/restart | 6140 |
| Query connection state | `connected=1` |
| Terminal/Tester execution | Attended Demo read-only MQL script; no Strategy Tester |
| Broker calls | NONE |

The read-only query ran at 11:22:29 local journal time. After that observation,
the terminal automatically updated and restarted from build 6090 to build 6140.
The build-6140 journal subsequently recorded authorization, synchronization,
and `trading has been enabled, demo account - hedging mode`. The query evidence
is therefore retained as a valid pre-update observation, but it is not treated
as current-build query-completeness proof.

No login, password, token, or account secret is stored. The evidence record
contains only a one-way account-identity hash.

## Pre-send disposition (historical)

**FRESH BUILD-6180 POST-MATERIALIZATION PRE-SEND GATE PASS; READY FOR SEPARATE
EXPLICIT SEND CONFIRMATION.** Demo, HEDGING, broker, server, symbol, build,
connection, minimum volume, filling capability, query-before-profile order,
governed Magic, and default-disarmed state were observed from the accepted
source. Query results remain `UNPROVEN`, not authoritative empty or negative
evidence.

The terminal journal records explicit EA removal and
`F0_DEINIT|reason=1|send_attempted=0`. The disarmed observation lifecycle is
complete and no broker call occurred.

The runtime source now freezes `SWV5_RUNTIME_STRATEGY_MAGIC=1179670069`
(`0x46505635`, `FPV5`) in
`Configuration/SW_V5_RuntimeIdentityProfile.mqh`. Values `5042001`, `5005`, and
`550015` remain test fixtures or reference data and are not runtime authority;
`0` remains invalid. The Demo probe has no mutable Magic input.

The installed runnable EX5 hashes matched their fresh build-6180 compiled
artifacts. The accepted source and all observation identities matched. This gate
does not arm or send; Fusion/operator must separately review the evidence and
provide explicit final confirmation at a new action boundary.

`F0-QRY-001` and `F0-6180-PRESEND-001` remain archival evidence and are not
combined or backfilled into `F0-6180-POST-MAGIC-PRESEND-001`.

## Mandatory attended-run attestation

Before an armed probe, the operator must attest presence and verify at runtime:

- `ACCOUNT_TRADE_MODE_DEMO`;
- `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`;
- exact expected broker/server/symbol;
- connection is current;
- minimal volume and market order only;
- no live/real-money or production VPS;
- no unresolved prior experimental attempt;
- evidence destination contains no credentials.

Failure of any item is a local R0 reject and no broker call may occur.

The empirical run proved that terminal/MQL/account trading-permission state must
also be positively attested before any future arm. The F0 corrective candidate
now checks `TERMINAL_TRADE_ALLOWED`, `MQL_TRADE_ALLOWED`,
`ACCOUNT_TRADE_ALLOWED`, and `ACCOUNT_TRADE_EXPERT` before setting
`send_attempted`. This is source/compile/offline evidence only. A second send
still requires separate Fusion authorization and a completely new run boundary.
