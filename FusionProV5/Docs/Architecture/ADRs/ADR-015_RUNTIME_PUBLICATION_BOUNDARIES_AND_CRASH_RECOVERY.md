# ADR-015: Runtime Publication Boundaries And Crash Recovery

## Status

Revised proposal for Sprint 5 Phase A.2 independent architecture re-review.

Governance note: this ADR documents exact V5 operation boundaries and future Sprint 5 authorities. It authorizes no store implementation.

## Context

V5 exposes `SavePendingRequests()` and `SaveCheckpoint()` separately. Neither signature accepts sufficient expected-current request-set/checkpoint identity, store revision, and ownership/takeover evidence to prove stale-owner-safe complete replacement by itself. `PublishRestartQueryWatermarks()` is narrowly atomic only for its validated proposal and must retain its exact special semantics. V5 exposes no general multi-domain transaction.

## Decision

Architecture claims only these existing V5 boundaries:

- `SavePendingRequests()` independently validates/publishes a complete ordered V5 request set but is not by itself the future cross-owner publication guard;
- `SaveCheckpoint()` independently validates/publishes one V5 checkpoint but is not by itself the future cross-owner publication guard; and
- `PublishRestartQueryWatermarks()` atomically advances only its exact validated restart proposal, two owner-specific query high-watermarks, and checkpoint publication metadata.

Future normal runtime must never call `SavePendingRequests()` or `SaveCheckpoint()` as an unfenced direct complete replacement. The Sprint 5 Fenced Runtime Publication Authority in ADR-018 is the only future Execution Layer admission path for authoritative request-set/checkpoint publication. Phase D must place its expected-current and ownership comparisons at the physical store/lock boundary surrounding the durable mutation while preserving all V5 semantic validation. If the selected store cannot do this, runtime work is blocked pending an approved contract revision; the requirement cannot be weakened.

The Ingress Ledger, Request Sequence Authority, pending-request set, checkpoint, and Submission Permit/Invocation Claim journal are separate authority domains. There is no global transaction. Each operation publishes only its own success. A partial durable combination is explicitly dirty/unresolved, fails runtime readiness, and converges by deterministic identity/revision reconciliation; it cannot be interpreted as success by a later host.

Before runtime eligibility the host uses ADR-018 fenced checkpoint publication for `clean_shutdown=false`. Normal related changes publish the complete request set through fenced request-set authority first, reload/validate the durable result, then publish a checkpoint through fenced checkpoint authority. Statistics remains reconstructible from authoritative deal history. A CAS failure preserves prior authority and revokes runtime eligibility. Only orderly shutdown after all domains converge may publish `clean_shutdown=true`.

## Consequences

- Exact V5 method limits are explicit; no expected-current parameters are invented.
- Stale-owner complete-set and checkpoint replacement are closed by one future publication authority.
- Crash convergence relies on durable identities, revisions, actual V5 validation/reconciliation, and fail-closed readiness.
- Physical transaction/store technology remains a Phase D decision.
