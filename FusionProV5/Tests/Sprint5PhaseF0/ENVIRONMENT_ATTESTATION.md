# Phase F0 Environment Attestation

TEST ONLY / F0 / NO CREDENTIALS.

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

## Pre-send disposition

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
