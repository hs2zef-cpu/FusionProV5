# Fusion Pro V5 Contract Versioning Policy

## Status

Candidate policy for the Sprint 4.1 review package. Pending formal approval; not Architecture Locked. Sprint 4 remains the authorized architecture baseline.

## Current Contract

- Schema version: `4`
- Minimum compatible version: `4`
- Policy ID: `SWV5-PRODUCTION-V4`
- Sprint 4 version 1 records are architecture artifacts, not production persistence records.

Version 4 is an intentionally incompatible evolution of the unlocked version 3 candidate. It adds durable immutable evidence fingerprint binding, completes Risk authorization rebinding against the full current Risk input, and makes Unit safety derive operation semantics from intent, operation kind, purpose, and current/target exposure. Caller flags are consistency evidence only. Version 3 remains historical candidate work and was never Architecture Locked or authorized for runtime use. Version 2 added deterministic validation context, authoritative query completeness, transaction identity, authorization binding, and lease compare-and-set evidence. Version 3 corrected earlier review defects by making recovery state explicit, splitting pre- and post-submission identity, making pending requests reconstructible, binding Risk to a canonical account namespace/epoch and account mode, replacing self-attested evidence, making idempotency membership reconstructible, and introducing the earlier Unit safety model.

The Sprint 4.5 Phase C signature and Unit DTO additions and the Phase D ownership-evidence additions are V4 candidate completion, not a V5 release. V4 has never been approved, locked, emitted by runtime, or accepted as a durable compatibility baseline. Phase D completes the unresolved candidate by binding the authoritative clock and complete observed lease identity into ownership lifecycle and takeover evidence, and by separating immutable ownership-authority fencing from mutable lease-record CAS revision. These corrections therefore complete the same unresolved candidate before formal approval. After V4 approval, the same required-field or interface-signature changes would require a schema increment and migration review.

Phase D request-set identity uses deterministic typed length-prefixed fields in fixed DTO and array order. Strings are encoded with their field name, type, character length, and exact value, so delimiters and Unicode content remain unambiguous. Signed integers, unsigned integers, enums, booleans, and datetimes use locale-independent decimal text. Doubles use fixed 16-decimal point notation with deterministic negative-zero normalization. Request arrays are order-sensitive: every record is bound to its explicit zero-based order index, and implementations do not sort silently.

## Version Fields

Every durable or externally exchanged contract record must identify:

- Contract name
- Schema version
- Minimum compatible version
- Policy ID
- Record or evaluation sequence where applicable
- Writer/owner identity where applicable
- Authoritative timestamp and time source where applicable

Cross-domain DTOs carry `SWV5_ContractVersion` directly or through a canonical envelope such as `SWV5_ExecutionCorrelation`, `SWV5_OwnershipFence`, or `SWV5_PersistenceNamespace`.

## Compatibility Rules

1. Exact version is readable and writable when contract name and policy ID match.
2. A newer reader may read an older record only when the reader explicitly declares backward compatibility and all required fields have deterministic defaults.
3. A writer never emits an older schema.
4. Missing contract identity, unknown policy, or incompatible minimum version is rejected.
5. Persistence does not mutate or overwrite an incompatible record while attempting recovery.
6. Migration creates a new sequence-linked record; it never silently edits the source record.
7. Broker reconciliation occurs after loading a migrated record and before execution readiness.
8. Contract DTO changes and behavioral rule changes are versioned separately from implementation releases.
9. `ISWV5ContractVersionPolicy::EvaluateCompatibility()` is the sole compatibility-decision interface.

## Change Classification

| Change | Required action |
|---|---|
| Documentation clarification with no semantic effect | No schema increment |
| New optional diagnostic with a deterministic default | Compatibility review |
| New required field or invariant | Increment schema version |
| Enum value reinterpretation or removal | Increment schema version and migration policy |
| Interface signature change | Increment schema version |
| Authority, confirmation, risk, or ownership rule change | Increment schema version and ADR |

## Deterministic Validation

Every contract operation receives `SWV5_ContractValidationContext`. It contains one clock ID, one clock authority, one clock time, and one clock sequence. Lease evidence references the same clock ID. Validators must not call wall-clock, broker, account, file, or random APIs internally.

Fail-closed behavior is mandatory and is not caller-configurable. Contract outcomes use one canonical disposition; convenience booleans are not part of authoritative decisions.

Identical inputs and context must produce identical decisions, reason codes, flags, and resulting DTO values.

## Lock Rule

A contract version may be marked locked only when:

- Every documented invariant maps to a DTO field and table-driven test.
- All required ADRs are accepted.
- Positive, negative, boundary, stale, duplicate, corruption, and conflict cases are specified.
- No unknown or incomplete authoritative input can produce an allow decision.
- Static review confirms Signal Engine and broker-execution isolation.
