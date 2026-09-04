# Phase F0 Broker Profile

TEST ONLY / F0 / DEMO ONLY / NOT FOR PRODUCTION.

## Measurement status

**NOT MEASURED — ATTENDED DEMO/HEDGING ENVIRONMENT NOT AVAILABLE IN THIS RUN.**

Read-only preflight found no running `terminal64` or `metatester64` process.
Historical terminal logs are not current environment attestation and were not
used as broker evidence. No broker/server behavior is claimed.

## Required exact profile fields

| Field | Current evidence |
|---|---|
| Broker name | NOT MEASURED |
| Server | NOT MEASURED |
| Login identity | NOT MEASURED; publish only a stable redacted hash |
| Account trade mode | NOT MEASURED |
| Margin mode | NOT MEASURED; must equal HEDGING or STOP |
| Terminal build | NOT MEASURED |
| MQL/compiler build | compiler evidence only; runtime build NOT MEASURED |
| Exact symbol | NOT MEASURED |
| Symbol specification | NOT MEASURED |
| Execution/filling modes | NOT MEASURED |
| Order capabilities | NOT MEASURED; pending orders excluded by F0 scope |
| Server/local time | NOT MEASURED |
| Connection state | NOT MEASURED |

The isolated probe prints these values but is disarmed by default. Its output is
evidence only after Demo and HEDGING are positively attested during an attended
run. No profile portability to another broker, server, account, symbol, or build
may be inferred.
