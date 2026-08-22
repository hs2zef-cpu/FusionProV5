# Sprint 5 Phase B deterministic test inventory

All cases are pure contract/reference cases. Runtime execution is deferred.

| IDs | Contract cases |
|---|---|
| CAN-001..018 | Empty/ASCII/multibyte/invalid-surrogate strings; booleans; signed/unsigned/datetime/double; negative zero; non-finite denial; nested/indexed values; domain separation; SHA-256 empty and `abc` |
| ING-001..016 | BUY, SELL, WAIT, BLOCKED, action contradiction, sequence/generation mismatch, trust/scope/clock mismatch, stale/exact-expiry/future-skew, sequence idempotency/conflict |
| TRU-001..009 | Independent anchor, status allowlist, interval, generation/epoch succession, same-sequence idempotency, conflict, pre-P/post-P/claim-time continuity |
| LED-001..011 | New, duplicate, conflict, unseen below HWM, compaction continuity, pending/bound recovery states, deterministic reconstruction, namespace/fence denial |
| SEQ-001..006 | Same-correlation idempotency, different-correlation monotonicity, gaps, stale revision, stale owner, overflow denial |
| BND-001..006 | Stable logical correlation/idempotency, ordinal-zero attempt, retry attempt change, no broker identity, initial V5 lifecycle blueprint |
| PUB-001..010 | Request-set/checkpoint correct revision, stale logical/store revision, digest/fence/takeover mismatch, next revision, larger-sequence stale-fence denial |
| PER-001..006 | Deterministic permit identity, binding/revision/interval/digest validation, conflict |
| CLM-001..016 | Valid claim, second claim no grant, durable record no grant, snapshot/permit/revision/owner/takeover/time failures, Trust expiry, Risk before/equal/after expiry, uncertainty no retry authority |
| ADM-001..010 | Typed vector scopes, all stable tokens, double collect, mutation instability, provisional P, failed claim ineffective, successful claim effective |
| MUT-001..012 | Hard Kill/Trust/basket/request/account/symbol/margin/risk mutation before P, after P, and post-claim dispositions |
| ORC-001..006 | Immutable ingress, binding, permit, admission, claim, and fenced-publication interface shapes |
