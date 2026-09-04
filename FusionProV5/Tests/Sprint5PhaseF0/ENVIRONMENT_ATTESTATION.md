# Phase F0 Environment Attestation

TEST ONLY / F0 / NO CREDENTIALS.

## Current run

| Field | Result |
|---|---|
| Observation date | 2026-09-04 |
| Running MT5 Terminal detected | NO |
| Running MetaTester detected | NO |
| Current broker/server | NOT OBSERVED |
| Current account classification | NOT OBSERVED |
| Current margin mode | NOT OBSERVED |
| Demo attested | NO |
| HEDGING attested | NO |
| Terminal/Tester execution | NONE |
| Broker calls | NONE |

Historical logs were present but are not accepted as current environment
attestation. No login, password, token, or account secret was collected.

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
