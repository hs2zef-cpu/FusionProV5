# Sprint 4.7 Phase A - Adversarial Safety Closure

Status: CANDIDATE / IN REVIEW

Architecture Lock: NOT CLAIMED

Runtime authorization: NONE

## Scope

This corrective phase closes five audit Criticals in the deterministic Production Contract V4 candidate and its test-only reference implementations. It does not implement runtime, broker execution, persistence, or trading behavior.

## Canonical decisions

1. Risk projections are post-operation Basket, symbol, aggregate, and aggregate-notional values. Under HEDGING, they must be causally coherent with current exposure and the requested OPEN, INCREASE, REDUCE, CLOSE, or CANCEL_PENDING operation. `projected_margin` remains additional request margin.
2. `SWV5_IsFiniteNumber` is the canonical prerequisite for every double consumed by Risk or authoritative transaction/persistence validation. Invalid numbers fail before comparisons or mutation.
3. Hard Kill release authority exists only while `approved_at <= current_time < expires_at`. Equality at expiry is expired.
4. Checkpoint integrity and checkpoint semantic validity are independent mandatory gates. `ReconcileRestart` validates both without relying on caller prevalidation.
5. Retry uses explicit valid and eligible enum allowlists. Unknown values, including equal invalid values across two fields, deny.

## Contract version

Production Contract V4 remains Candidate / In Review and unlocked. These corrections strengthen validation semantics without changing a DTO or interface signature, so the V4 version and policy remain unchanged.

## Verification

The executable suite contains 634 tests: 610 behavioral, 23 supporting pure-function, one conformance-only, and zero weak false positives. The five Sprint 4.7 targeted groups contain 18, 18, 7, 18, and 12 tests respectively. Phase A does not create immutable evidence or modify historical evidence/exporter artifacts.
