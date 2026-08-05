# Sprint 4.2 Contract Verification Test Inventory

> **TEST ONLY — NOT FOR PRODUCTION — NO BROKER ACCESS**

## Executable Inventory

| Domain | Test IDs | Count | Primary verification |
|---|---:|---:|---|
| Common and versioning | `COM-01`–`COM-12` | 12 | Contract identity, compatibility, canonical clock, fencing, namespace, deterministic replay, mandatory fail-close |
| Basket state machine | `BSM-01`–`BSM-49` | 49 | Every state pair, allowed/forbidden/same classification, state-version behavior, closure evidence |
| Basket aggregate | `BAS-01`–`BAS-08` | 8 | Canonical identity, recovery monotonicity, partial close, residual exposure, closure completeness, Hedging-only mode |
| Unit system | `UNT-01`–`UNT-10` | 10 | Tick/point/pip separation, volume step, stops, freeze, currencies, specification sequence, tolerance |
| Instance ownership | `OWN-01`–`OWN-11` | 11 | Lease acquisition, expiry, takeover, CAS/store revision, clock identity, stale-owner rejection |
| Execution | `EXE-01`–`EXE-16` | 16 | Intent validity, acknowledgement boundary, retcode mapping, confirmation, correlation, duplicate/out-of-order evidence |
| Persistence and restart | `PER-01`–`PER-15` | 15 | Record integrity, namespace isolation, authoritative reconciliation, pending requests, durable Hard Kill |
| Risk | `RSK-01`–`RSK-16` | 16 | Hard Kill precedence/release, immutable authorization binding, expiry, limits, snapshots, monetary basis |
| Statistics | `STA-01`–`STA-13` | 13 | Attribution, identity-set deduplication, arbitrary ordering, residual accounting, monetary completeness |
| Cross-domain | `XDM-01`–`XDM-12` | 12 | Ordered evidence gates and fail-closed cross-contract negative scenarios |
| **Total** |  | **162** | All cases in `SPRINT4_1_CONTRACT_VALIDATION_SPEC.md` |

## Execution Model

- Every case is executed twice inside one harness invocation.
- The full harness is executed in two independent Strategy Tester sessions.
- Each run uses fixed DTO fixtures and an explicit `SWV5_ContractValidationContext`.
- No validator obtains time, symbol, account, order, position, history, file, random, or network state internally.
- A test is never skipped because a contract surface is inconvenient; incompatible or incomplete evidence is expected to fail closed.
