# ADR-003: Persistence and Lease Atomicity

## Status

Accepted as a technology-neutral contract requirement.

Governance note: this technical decision is part of the Sprint 4.1 Candidate / In Review package. It does not Architecture Lock Sprint 4.1, replace the Sprint 4 authorized baseline, or authorize runtime implementation.

## Decision

Persistence publication and instance ownership use compare-and-set semantics against an observed version and store revision. The lease clock must be identified and authoritative. A missed heartbeat alone never authorizes takeover.

`SWV5_OwnershipFence` is the single immutable fencing identity. It contains the full ownership namespace, owner, lease version, takeover generation, fencing-token digest, and store revision. The same fence must be carried by Basket, Risk, Execution, transaction, and Persistence evidence.

Persistence is addressed by `SWV5_PersistenceNamespace`: broker/server, account, strategy, symbol, Magic scope, and BasketID. BasketID alone is never a persistence key.

Takeover requires typed, versioned lease-expiry, broker-reconciliation, and persistence-reconciliation evidence; the observed lease version and store revision; an independent authority source; and a new monotonic takeover generation. Self-attested reconciliation booleans are not evidence. Writes from a non-owner or stale store revision are rejected.

The typed expiry evidence must repeat and exactly match the observed ownership key, lease version, store revision, heartbeat sequence, clock identity and authority, expiry timestamp, and expiry clock sequence. Heartbeat returns a renewed lease with a monotonic heartbeat sequence, authoritative heartbeat clock sequence/time, and extended expiry while preserving the owner and fence.

Restart reconciliation consumes the complete ordered persisted-request array. `latest_pending_request` is only an optional summary of the last ordered record and is never a replacement for the set. Request-set digest and revision are computed from canonical serialization of every record, including nested fields, record order, record sequence, count, and namespace. The empty set has a deterministic digest and revision and clears the summary.

Sprint 4.1 does not select or implement a physical store.

## Consequences

- Split-brain and stale-writer scenarios fail closed.
- Release and heartbeat operations validate the observed lease version and store revision.
- Any fence mismatch or namespace mismatch invalidates downstream authorization and execution.
- Lease timestamps and validation use the same `clock_id` and validation-context clock authority.
- Store corruption or unavailable authoritative time requires reconciliation or operator action.
