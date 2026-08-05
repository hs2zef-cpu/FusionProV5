# Fusion Pro V5 Contract Versioning Policy

## Status

Candidate policy for the Sprint 4.1 review package. Pending formal approval; not Architecture Locked. Sprint 4 remains the authorized architecture baseline.

## Current Contract

- Schema version: `2`
- Minimum compatible version: `2`
- Policy ID: `SWV5-PRODUCTION-V2`
- Sprint 4 version 1 records are architecture artifacts, not production persistence records.

Version 2 is intentionally incompatible with version 1 because deterministic validation context, authoritative query completeness, transaction identity, authorization binding, and lease compare-and-set evidence were added to the contracts.

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
