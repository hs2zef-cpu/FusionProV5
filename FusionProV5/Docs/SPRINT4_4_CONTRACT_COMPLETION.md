# Sprint 4.4 Contract Completion and Semantic Verification

Status: **CANDIDATE / IN REVIEW**

Sprint 4 remains the authorized architecture baseline. Sprint 4.4 is corrective contract and test-only work on the Sprint 4.1 candidate branch. It is not Architecture Locked, does not authorize runtime implementation, and does not claim production readiness.

## Scope

Sprint 4.4 closes the six Major findings from the final independent merge audit without changing trading logic or implementing a production runtime.

## Contract boundary corrections

1. Restart reconciliation receives the complete ordered persisted-request array. `latest_pending_request` is explicitly optional summary state and cannot substitute for the array.
2. Request-set headers bind deterministic canonical payload serialization, record order, record sequences, count, digest, index revision, and namespace. Empty sets have an explicit canonical representation.
3. Risk authorization returns and validates the complete limits, projected-loss/notional/margin basis, account snapshot sequence, full account namespace, Hard Kill identity/generation, monetary basis, normalized execution terms, and expiry.
4. Basket recovery and execution confirmations return updated durable identity state. Statistics accumulation returns the updated deduplication state through the existing `next` output.
5. Ownership heartbeat returns a renewed lease. Typed takeover expiry evidence binds the observed ownership key, lease/store versions, heartbeat sequence, expiry time/sequence, and authoritative clock.
6. False-positive tests were rewritten to invoke contract interfaces and assert meaningful outputs or mutations. Two pure equality cases remain explicitly supporting-only and are excluded from the interface-credible count.

## Deterministic readiness policy

Restart examines every ordered pending request before deriving exactly one disposition:

- coherent checkpoint and zero pending requests: `SAFE_TO_RESUME`
- any uncertain request: `RECONCILIATION_REQUIRED`
- any request whose retry disposition is forbidden: `RETRY_FORBIDDEN`
- persisted active Hard Kill: `CLOSE_ONLY`
- corrupt set, foreign namespace, mixed account mode, incomplete identity, missing member, or residual arithmetic mismatch: `HALTED`

The complete request set is authoritative. The checkpoint's `latest_pending_request` is a coherency-checked cache of the last ordered record when `has_latest_pending_request` is true; canonical empty sets clear it.

## Evidence policy

Final counts, signature, compile results, immutable source SHA, and hashes are generated only after the source commit is clean and both independent Demo Strategy Tester runs complete. Generated evidence must be committed separately from the tested source.

## Prohibitions

- no broker execution or live-trading API
- no account, order, position, history, symbol, file, network, random, or live-clock query in validators
- no Signal Engine, DecisionEngine, dashboard, runtime, adapter, platform, orchestration, regression, or frozen Sprint change
- no Architecture Lock, production-readiness, or runtime-authorization claim
