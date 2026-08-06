# ADR-008: Canonical Risk Account Namespace and Epoch

## Status

Accepted as a corrective contract decision for independent review.

Governance note: this decision is part of the Sprint 4.1 Candidate / In Review package. It does not Architecture Lock the candidate, replace Sprint 4 as the authorized baseline, or authorize runtime implementation.

## Decision

All Risk inputs and authorizations bind one canonical account namespace: broker identity, server, account login, account currency, strategy ID, Magic scope, account position mode, authoritative source, snapshot epoch, and snapshot sequence.

Account, exposure, Basket, projected, equity/daily-loss, and Hard Kill evidence must share that namespace and epoch. Different per-domain sequences are permitted only inside the same epoch and authoritative namespace. The same login on another broker or server, an unknown/changing position mode, or a mixed epoch fails closed.

## Consequences

- Login alone is never an account identity.
- Authorization cannot be replayed across broker, server, strategy, Magic scope, mode, or epoch.
- Restart reconciliation validates the same namespace before execution readiness.
