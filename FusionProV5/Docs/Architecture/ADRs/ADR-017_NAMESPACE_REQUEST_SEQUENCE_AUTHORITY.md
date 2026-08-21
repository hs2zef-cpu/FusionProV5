# ADR-017: Namespace Request Sequence Authority

## Status

Proposed for Sprint 5 Phase A.2 independent architecture re-review.

Governance note: this is a **Sprint 5 Candidate Contract — NOT V5 existing authority**. It authorizes no persistence implementation.

## Context

Producer-scoped ledgers cannot own a namespace-wide logical request sequence when signal, reduce/close-only, recovery-origin, and future authorized origins may allocate concurrently. A crash after allocation also must not allocate a second sequence for the same logical request.

## Decision

Exactly one durable Request Sequence Authority owns only allocation/reservation of the monotonic logical request sequence per persistence namespace. Execution Coordinator remains logical request lifecycle owner. Producers, ledgers, recovery paths, and request-origin adapters are not allocators.

All request origins call a linearizable, fenced operation equivalent to:

```text
ReserveRequestSequence(persistence_namespace,
                       logical_correlation_id,
                       current_ownership_fence,
                       ...)
```

The operation compares namespace, current fence/takeover authority, expected allocator revision, policy/version, and canonical proposal. If the correlation already has a valid reservation, it returns the same sequence and never advances the allocator. Otherwise it atomically advances the namespace high-watermark and durably binds the new sequence to that correlation. Gaps are allowed. Corruption, conflicting correlation binding, stale owner, or revision mismatch fails closed.

The canonical authority record uses ADR-009 framing and typed domain `SWV5-SPRINT5-REQUEST-SEQUENCE-AUTHORITY-V1`, followed in fixed order by contract/policy/format, namespace, current authority fence/takeover, allocator prior/current revision and high-watermark, and ordered correlation-to-sequence reservations. The digest field is excluded from its own preimage and appended to the full record. Same correlation with different sequence or same revision with different content is conflict.

A crash after reservation but before another domain records it is safe: replay uses the deterministic correlation and receives the same reservation. An orphan reservation is a harmless gap. Retries under the same logical request retain the logical sequence and use a separate durable attempt ordinal/identity.

## Consequences

- Concurrent producer epochs and non-signal origins share one sequence order.
- Exactly one sequence is bound to each logical correlation.
- The allocator owns no ingress acceptance, request lifecycle, retry policy, or broker authority.
- Phase D must select a store capable of its linearizable fenced reservation semantics.
