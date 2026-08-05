# ADR-004: Transaction Confirmation and Idempotency

## Status

Accepted.

## Decision

Request acknowledgement never confirms Basket state. A synchronous result that reports a deal remains pending until authoritative transaction or deal-history evidence is correlated to the request, Basket, expected state version, and normalized volume.

Transaction evidence has a stable event ID and monotonic transaction sequence. Duplicate evidence is idempotent. Out-of-order, conflicting, unknown, or cross-Basket evidence requires reconciliation and cannot increase confirmed volume twice.

`SWV5_ExecutionCorrelation` is the canonical cross-domain envelope for request correlation ID, attempt ID, parent attempt, order ticket, deal ticket, position identifier, event ID, idempotency key, and transaction sequence. Partial closes, confirmations, persisted request evidence, and Statistics deals use the same envelope.

Retcode classification is derived from a versioned mapping policy. Callers supply raw evidence, not trusted classifications.

## Consequences

- Retry is forbidden while an earlier attempt has uncertain disposition.
- Each retry uses a unique attempt ID under one logical correlation ID.
- Correlation and ownership-fence mismatch fail closed.
- Broker-specific mapping tables and ordering fixtures are required before a broker adapter is authorized.
