# ADR-009: Canonical Signal Decision Ingress Boundary

## Status

Revised proposal for Sprint 5 Phase A.2 independent architecture re-review.

Governance note: this revised decision is part of the Sprint 5 Phase A.2 Invocation & Publication Authority Closure Candidate / In Review. It does not Architecture Lock Production Contract V5, authorize Phase B/runtime implementation, or modify the frozen Signal Engine.

## Context

ADR-001 separates broker execution from the indicator but intentionally leaves the future ingress contract unspecified. The frozen `SWV5_DecisionResult` carries the final action and result header, while its authoritative symbol, timeframe, execution mode, snapshot schema, and closed-bar identity originate in the immutable snapshot header. An Execution Layer cannot safely consume a naked action or reconstruct missing producer facts.

## Decision

A future Signal Ingress Adapter will consume one immutable, versioned ingress envelope published from the `DecisionEngine` path. The envelope binds the unmodified `SWV5_DecisionResult` to its exact authoritative `SWV5_SnapshotHeader` facts, a stable producer authority/component and producer-instance/epoch identity, publication clock ID/authority/time and sequence, canonical-format and ingress-policy identities, a derived ingress identity, and a payload digest.

Snapshot fields are carried from their existing authority and are not recalculated by the consumer. Request, attempt, broker, Basket, lease, Risk, and persistence identities are not invented at ingress; they remain distinct downstream V5 authorities.

### Nonrecursive canonical construction

Canonical encoding preserves the V5 fixed-order, typed length-prefixed model while freezing a distinct Sprint 5 format precisely. Each field is `<ASCII-name>:<type>:<length>:<value>`. Type tokens are exactly `s` string, `b` boolean, `i` signed integer/enum/datetime, `u` unsigned integer, `d` double, and `x` nested canonical record or explicitly indexed entry. `length` is the unsigned canonical decimal count of UTF-8 octets in `value`, not an MQL character count. Strings are valid Unicode scalar-value sequences encoded as strict UTF-8; an unpaired UTF-16 surrogate or any ill-formed sequence is rejected. No BOM and no Unicode normalization are applied: the exact code-point sequence is authoritative. Empty string is `<name>:s:0:`. Boolean is exactly `0` or `1`; enum, signed integer, and nonnegative datetime are base-10 with optional leading `-` only for a negative signed integer/enum, no leading `+`, no redundant leading zero, and no negative zero; unsigned integer is base-10 with no sign or redundant leading zero. Doubles retain fixed 16-decimal point notation with non-finite rejection and negative-zero normalization. Arrays carry explicit zero-based indices and are never silently sorted. `H` is SHA-256 over the exact framed UTF-8 octets and emits 64 lowercase hexadecimal characters under policy ID `SWV5-SHA256-UTF8-V1`. A domain separator is the first typed field, never an unframed concatenation. Existing V5 serializers and DTOs are unchanged; a Phase B Sprint 5 serializer must use this separately identified Sprint 5 format rather than infer length from `StringLen()`.

Construction has this one-way dependency:

```text
Source Canonical Body
  -> Ingress Identity Preimage
  -> Derived Ingress Identity
  -> Digest Preimage
  -> Payload Digest
  -> Full DTO
```

The Source Canonical Body contains every source field except the two derived fields: ingress version/policy/format, producer authority and instance/epoch reference, publication clock ID/authority/time and sequence, exact snapshot facts, and exact Decision result. The Identity Preimage is domain `SWV5-SPRINT5-INGRESS-ID-V1` followed by the canonical Source Body; it excludes both `ingress_identity` and `payload_digest`. The derived identity is the versioned deterministic hash of that preimage. The Digest Preimage is domain `SWV5-SPRINT5-INGRESS-PAYLOAD-V1`, the canonical Source Body, and the derived ingress identity; it excludes only `payload_digest`. The Full DTO is Source Body + ingress identity + payload digest in fixed order. A digest proves content integrity only, never producer trust.

The authoritative Snapshot identity is the exact tuple of snapshot schema, sequence, history generation, execution mode, data-quality flags, symbol, timeframe, and closed-bar time. The Decision binding is the complete Decision result whose header sequence/generation must equal that tuple. Ingress identity derives from both. A downstream logical request identity is separately derived under ADR-013, and broker identity is populated only at the V5 acknowledgement/evidence phase. None are aliases.

### Freshness and producer authority

Validation consumes a future pure Producer Trust Authority record and an explicit validation context compatible with `SWV5_ContractValidationContext`; validators use no hidden clock. The versioned ingress freshness policy identifies the required clock ID/authority, positive `max_age`, and nonnegative `max_future_skew`. Envelope publication clock and validation-context clock must exactly match that policy. Reject when `publication_time > evaluation_time + max_future_skew`, and reject when `evaluation_time >= publication_time + max_age`. The expiry boundary is therefore exclusive. Overflow, zero/invalid time, unknown policy, mismatched clock identity/authority, or evaluation under a superseded producer epoch fails closed.

The Producer Trust Authority record identifies authority-record ID/version/generation and digest; issuing authority identity/policy; producer component; producer instance and epoch; allowed persistence namespace, symbol, timeframe, execution mode, and clock identity/authority; authorization status (`AUTHORIZED`, `SUSPENDED`, `SUPERSEDED`, or `REVOKED`); validity interval `[valid_from, valid_until)`; and superseding record/generation. Its digest preimage is typed domain `SWV5-SPRINT5-PRODUCER-TRUST-V1` followed by every field in fixed order except the digest itself; the full record appends the digest. Validation also consumes the independently configured expected issuer/policy/generation trust anchor; a caller boolean is not authority. Only `AUTHORIZED` is eligible. Publication must occur inside the interval, the record must still be the current authorized generation at evaluation, and the envelope scope must match exactly. A valid digest without that independent authority input is unauthorized.

Trust is a continuing authority, not a one-time ingress check. Current Producer Trust must be revalidated before request materialization or progression creates new increasing authority, before Submission Permit creation, and immediately before Invocation Claim. Every nonterminal ingress/request origin is revalidated at startup and takeover. Revocation or supersession before request materialization durably selects `TERMINALLY_BLOCKED_TRUST_REVOKED`; accepted evidence remains auditable and replay cannot resurrect it. Revocation after request creation but before claim blocks permit/claim and uses the applicable V5 cancellation, rejection, or reconciliation disposition without inventing a V5 state. Revocation after a successful Invocation Claim cannot erase the uncertain attempt or broker evidence; it blocks all new increasing authority and retry until authoritative disposition.

Producer publication sequence is positive and strictly monotonic per authorized instance/epoch: a new identity must have `sequence > durable_high_watermark`; gaps are permitted; zero or lower sequence fails closed. A same-instance reset/regression fails closed. A reset is legal only under a newly authorized instance/epoch and superseding authority generation. Equal sequence with the same ingress identity resolves idempotently from the durable ledger; equal sequence with different content is a conflict. Old/superseded producers and namespace collisions cannot regain authority by replay.

Ingress validation is deterministic and fail-closed for unknown/incompatible schema, missing or corrupt identity, wrong scope, action/direction contradiction, invalid Decision result, stale/future input, unauthorized/superseded producer, duplicate conflict, sequence regression, or digest mismatch. `WAIT` and `BLOCKED` are auditable no-entry outcomes and can never create an Execution Intent. `BUY`/`SELL` nominate the existing direction only; the adapter may deny eligibility but may not reverse or reinterpret it.

`ProductionArchitecture` does not include Signal Engine headers. A later pure adapter/DTO project must preserve that physical dependency direction.

## Consequences

- The Execution Layer consumes Decision authority without becoming a second Signal Engine.
- Signal identity and logical Execution request identity remain explicitly correlated but distinct.
- Phase B may define pure DTOs and validators from these fixed semantics; numeric thresholds and credential/storage mechanics remain versioned deployment inputs.
- Durable acceptance and request binding are governed by ADR-013 rather than in-memory ingress state.
- No runtime connection is created by this ADR.
