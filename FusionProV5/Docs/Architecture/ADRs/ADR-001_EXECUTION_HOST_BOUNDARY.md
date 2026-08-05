# ADR-001: Execution Host Boundary

## Status

Accepted for Sprint 4.1 contract hardening.

## Decision

Future broker execution must live in a separate EA host or separately approved execution project. The frozen Sprint 3.2.1 indicator may publish an immutable Signal DTO through a future ingress contract, but it cannot own orders, positions, `OnTradeTransaction`, Basket state, Persistence, Risk, or Statistics.

Sprint 4.1 defines and verifies contracts only. It does not create the ingress, EA host, broker adapter, or runtime wiring.

## Consequences

- Signal logic remains deterministic and broker-independent.
- The EA host will be the sole owner of the platform transaction callback.
- A future integration Sprint requires an explicit DTO ingress specification and failure policy.
- No Production Architecture header may include a Signal Engine header.

