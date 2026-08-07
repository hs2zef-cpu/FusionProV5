# ADR-004: Transaction Confirmation and Idempotency

## Status

Accepted.

Governance note: this technical decision is part of the Sprint 4.1 Candidate / In Review package. It does not Architecture Lock Sprint 4.1, replace the Sprint 4 authorized baseline, or authorize runtime implementation.

## Decision

Request acknowledgement never confirms Basket state. A synchronous result that reports a deal remains pending until authoritative transaction or deal-history evidence is correlated to the request, Basket, expected state version, and normalized volume.

Transaction evidence has a stable event ID and monotonic transaction sequence. Duplicate evidence is idempotent. Out-of-order, conflicting, unknown, or cross-Basket evidence requires reconciliation and cannot increase confirmed volume twice.

`SWV5_ExecutionRequestIdentity` is the pre-submission identity and contains only logical request, attempt, parent-attempt, idempotency, and monotonic identity. `SWV5_BrokerExecutionIdentity` is populated only after broker acknowledgement or authoritative evidence. `SWV5_ExecutionCorrelation` combines them with an explicit lifecycle phase for post-submission evidence. Partial closes, confirmations, persisted request evidence, and Statistics deals use the phase-appropriate identity.

Accepted event membership is durable and reconstructible through a versioned canonical identity index plus digest, revision, highest sequence, and compaction generation. Remembering only the last event is insufficient; replaying event A after event B remains duplicate when A is already a member.

Acceptance returns the complete resulting pending-request state: lifecycle phase/state, cumulative and residual volume, latest authoritative confirmation, retry disposition, and the updated durable identity set. The caller persists that returned state; it must not reconstruct a final state locally.

Retcode classification is derived from a versioned mapping policy. Callers supply raw evidence, not trusted classifications.

## Consequences

- Retry is forbidden while an earlier attempt has uncertain disposition.
- Each retry uses a unique attempt ID under one logical correlation ID.
- Correlation and ownership-fence mismatch fail closed.
- Broker-specific mapping tables and ordering fixtures are required before a broker adapter is authorized.
- A reused event identity paired with a conflicting sequence fails closed; an unseen older sequence follows the explicit out-of-order-new policy and is accepted at most once.
