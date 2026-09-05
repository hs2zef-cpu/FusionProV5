# Phase F0 Runtime Strategy Magic Governance Decision and Materialization

APPROVED AS CANDIDATE FOR IMPLEMENTATION / F0 MATERIALIZED / NO SEND AUTHORITY /
NO BROKER ACCESS.

This document records the Fusion-approved candidate and its narrow F0
materialization. It does not change a DTO or interface, authorize Phase F, arm
a probe, or authorize a broker call.

## Candidate

Fusion approved exactly one positive frozen runtime strategy Magic:

| Field | Candidate |
|---|---|
| Symbolic name | `SWV5_RUNTIME_STRATEGY_MAGIC` |
| Decimal value | `1179670069` |
| Hex value | `0x46505635` |
| Encoding rationale | Four ASCII bytes `F`, `P`, `V`, `5` |
| Status | Approved as candidate for F0 implementation; materialized; no send authority |

The value is nonzero, fits within signed 32-bit range as well as MQL5 `ulong`,
is not time-, request-, attempt-, account-, symbol-, broker-, ticket-, or
session-derived, and does not equal the repository fixture/reference values
`5042001`, `5005`, or `550015`.

The value is not claimed globally collision-free. Its authority comes from an
exclusive Fusion Pro V5 reservation plus the existing composite namespace:
account login + broker + server + symbol + strategy ID + Magic. Magic remains a
strategy attribution scope, never a BasketID or per-request correlation ID.
Manual activity and other EAs remain separate collision/adversarial concerns;
the attended profile must fail closed if the same account/symbol already uses
this value outside the governed Fusion identity.

## Complete repository inventory

### Production data model and contract enforcement

| File | Existing Magic role/invariant |
|---|---|
| `ProductionArchitecture/SW_V5_ProductionCommon.mqh` | `SWV5_OwnershipKey.magic` is part of ownership identity; `SWV5_PersistenceNamespace` contains that key; `SWV5_AccountRiskNamespace.magic` binds account-risk authority. No value is assigned. |
| `ExecutionLayer/Contracts/SW_V5_S5_Common.mqh` | Ownership-key equality includes Magic. Fence and persistence-namespace equality inherit that exact comparison. |
| `ExecutionLayer/Contracts/SW_V5_S5_Canonical.mqh` | Canonical ownership-key serialization includes unsigned field `magic`; namespace/fence digests therefore bind it. |
| `ExecutionLayer/Contracts/SW_V5_S5_AdmissionSnapshotContract.mqh` | Admission rejects account-risk Magic that differs from the persistence ownership namespace. |
| `ExecutionLayer/Contracts/SW_V5_S5_RequestBindingContract.mqh` | Initial request blueprint rejects risk-authorization Magic that differs from intent persistence ownership Magic. |
| `ExecutionLayer/Contracts/SW_V5_S5_SubmissionAuthorityContract.mqh` | Canonical account-risk namespace serialization includes Magic, binding permit/risk authority digests. |
| `ExecutionLayer/Contracts/SW_V5_S5_RuntimePublicationContract.mqh` | Canonical checkpoint/Hard-Kill account namespace includes `account_magic`. |
| `ExecutionLayer/Contracts/SW_V5_S5_AdmissionContract.mqh` | Uses complete namespace/fence equality transitively; no independent value or override. |
| `ExecutionLayer/Contracts/SW_V5_S5_InvocationClaimContract.mqh` | Claim validation uses the current fence/namespace transitively; no independent value or override. |
| `ExecutionLayer/Contracts/SW_V5_S5_SubmissionRecordContract.mqh` | Persists the already-bound permit/request namespace; no independent Magic source. |

No Phase C or Phase E source contains a direct Magic literal or independent
Magic validator. Those phases carry the existing namespace/fence objects and
must remain unchanged.

### Reference validators, canonical decoders, and fixtures

| File | Existing use |
|---|---|
| `Tests/ContractVerification/SW_V5_ReferenceValidators.mqh` | Requires ownership and risk namespace Magic `>0`; compares Magic across ownership, persistence, and account-risk namespaces. |
| `Tests/ContractVerification/SW_V5_CanonicalDecoder.mqh` | Decodes unsigned `magic` in ownership and account-risk namespaces. |
| `Tests/ContractVerification/SW_V5_ContractTestRunner.mqh` | Mutates Magic to prove wrong namespace/binding rejection, ownership bypass rejection, and risk namespace mismatch rejection. |
| `Tests/ContractVerification/SW_V5_TestFixtures.mqh` | Uses `5042001` only as Contract Verification fixture data for ownership and account-risk namespaces; canonical fixture serialization includes Magic. |
| `Tests/ContractVerification/SPRINT4_8_CANONICAL_COVERAGE_MATRIX.md` | Records Magic as one dimension of ownership, margin, risk, reconciliation, and checkpoint coverage. |
| `Tests/ContractVerification/sprint4_6_tester_evidence.txt` | Archived evidence for wrong-Magic rejection tests; no runtime value assignment. |
| `Tests/Sprint5PhaseB/SW_V5_S5_PhaseB_Assertions.mqh` | Uses `5005` only in Phase-B test scope and test submission permit. |
| `Tests/Sprint5PhaseB/verify_phase_b.ps1` | Canonically serializes a caller-supplied test Magic in synthetic ownership keys. |
| `Tests/Sprint5PhaseD/SW_V5_S5_PhaseD_Assertions.mqh` and `D4_SEMANTIC_EVIDENCE.md` | Use zero only as an incomplete-key negative case. |
| `Tests/Sprint5PhaseD/frozen_dto_digest.py` and `verify_phase_d_reference.py` | Use `550015` only as frozen reference/oracle fixture data and require positive/equal Magic. |

Fixture/reference disposition is immutable for this proposal:

- `5042001` remains Contract Verification fixture data only.
- `5005` remains Phase-B assertion fixture data only.
- `550015` remains Phase-D frozen reference/oracle data only.
- `0` remains invalid/negative data and may identify observed account/balance or
  non-strategy rows; it is never runtime strategy identity or a probe input.

None is repurposed, migrated, aliased, or accepted as the runtime constant.

### Architecture and governance assumptions

| File | Existing assumption |
|---|---|
| `Docs/Architecture/ADRs/ADR-003_PERSISTENCE_AND_LEASE_ATOMICITY.md` | Persistence is keyed by broker/server/account/strategy/symbol/Magic/Basket. |
| `Docs/Architecture/ADRs/ADR-008_RISK_ACCOUNT_NAMESPACE.md` | Risk authority binds broker/server/account/currency/strategy/Magic/mode/epoch and cannot replay across Magic scope. |
| `Docs/Architecture/ADRs/ADR-021_PHYSICAL_STORE_CAS_AND_LEASE_CLOCK.md` | Canonical store digest preimage includes Magic. |
| `Docs/Architecture/FusionProV5_Master_Architecture.md` | Future atomic ownership includes account/server/symbol/strategy/Magic. |
| `Docs/Architecture/FusionProV5_Sprint4_Production_Architecture.md` | Magic scopes strategy attribution, is not BasketID, participates in recovery comparison/statistics attribution, and is part of the ownership key. |
| `Docs/Architecture/FusionProV5_Sprint5_Execution_Layer_Architecture.md` | Ownership key remains account/broker/server/symbol/strategy/Magic across heartbeat and takeover. |
| `Docs/SPRINT4_1_CONTRACT_HARDENING.md`, `SPRINT4_1_CONTRACT_VALIDATION_SPEC.md`, `SPRINT4_3_CONTRACT_CORRECTION.md` | Persistence and risk tests require complete composite Magic binding and reject Magic-only attribution. |

### F0 broker request and query use

| File | Existing use |
|---|---|
| `Tests/Sprint5PhaseF0/SW_V5_S5_PHASE_F0_DEMO_PROFILE_PROBE.mq5` | Remains default-disarmed, has no Magic input, binds `MqlTradeRequest.magic` directly to the SSOT, and logs callback `request.magic`. |
| `Tests/Sprint5PhaseF0/SW_V5_S5_PHASE_F0_QUERY_PROBE.mq5` | Reads `POSITION_MAGIC`, `ORDER_MAGIC`, history-order Magic, and `DEAL_MAGIC`; classifies all rows without filtering or Magic-only authority; never mutates broker state. |
| `Tests/Sprint5PhaseF0/ATTENDED_DEMO_RUNBOOK.md` | Requires Magic to retain its frozen strategy meaning. |
| `Tests/Sprint5PhaseF0/CORRELATION_IDENTITY_DESIGN.md` | Rejects Magic as a unique request ID and forbids repartitioning it for correlation. |
| `Tests/Sprint5PhaseF0/BROKER_PROFILE.md`, `ENVIRONMENT_ATTESTATION.md`, `COVERAGE_MATRIX.md`, `PHASE_F0_SELF_VERIFICATION.md`, `README.md`, and `Evidence/README.md` | Record the missing exact runtime value and fail the send gate closed. |
| `Tests/Sprint5PhaseF0/QUERY_COMPLETENESS_PROFILE.md`, `Evidence/F0-QRY-001.json`, and `Evidence/F0-6180-PRESEND-001.json` | Preserve the observed non-XAUUSD account/balance row with `magic=0`; it is explicitly not strategy evidence or runtime authority. |
| `Tests/Sprint5PhaseF0/verify_phase_f0_negative_controls.py`, `NEGATIVE_CONTROLS.md`, and `TEST_INVENTORY.md` | Define proposal-only deliberate mutants for zero, fixture substitution, cross-domain conflict, and per-request mutation. |

## Compatibility proof

Adding one immutable positive configuration value does not redefine existing
ownership, admission, claim, persistence, risk, or publication semantics:

1. Every DTO field already exists; no DTO, enum, interface, or method signature
   needs to change.
2. Existing validators already require positive Magic and exact cross-domain
   equality. The candidate satisfies, rather than relaxes, those predicates.
3. Existing canonical serialization and digests already include Magic. Supplying
   one constant changes instantiated identity data, not the canonical algorithm.
4. Ownership, persistence, risk authorization, admission, request binding,
   invocation claim, checkpoint, and Hard-Kill records must all receive the same
   value through their existing construction path.
5. The value remains stable across requests, attempts, retries, restart,
   heartbeat, lease renewal, and takeover. A different value is a different
   namespace and must fail closed; it is never an in-place mutation.
6. Symbol and BasketID remain separate key dimensions, so one strategy Magic
   does not collapse baskets or symbols.
7. Existing Phase B/C/D/E fixtures and frozen digests remain untouched because
   they validate semantics with synthetic data, not deployment configuration.

The proof fails if any consumer introduces another literal, permits an input
override, derives Magic per request, or treats Magic alone as correlation.

## Approved canonical SSOT location

Fusion approved and this change creates exactly one normative code location:

`FusionProV5/Configuration/SW_V5_RuntimeIdentityProfile.mqh`

That header owns the sole executable numeric definition. This document records
the approved symbol and value but is not a second executable or normative
definition.

No existing Contract, Production V5, Phase B, Phase C, Phase D, or Phase E file
is edited to hold or duplicate the literal. A future governance record may
point to the header as normative, but must not become a second executable source
of truth.

## Materialized F0 consumers

The approved F0-only implementation is limited to:

1. `Configuration/SW_V5_RuntimeIdentityProfile.mqh` — sole executable numeric definition.
2. `Tests/Sprint5PhaseF0/SW_V5_S5_PHASE_F0_DEMO_PROFILE_PROBE.mq5` — include the
   SSOT, remove mutable Magic input, and bind `request.magic` directly.
3. `Tests/Sprint5PhaseF0/SW_V5_S5_PHASE_F0_QUERY_PROBE.mq5` — reference the SSOT
   when classifying returned broker rows; continue reporting all rows.
4. `Tests/Sprint5PhaseF0/verify_phase_f0_negative_controls.py` — reads the
   approved header as data without duplicating the runtime literal and retains
   NC-16 through NC-19 against the approved value.
5. `Tests/Sprint5PhaseF0/verify_phase_f0_source.py` — assert one definition, no
   probe override, exact request binding, and no fixture/reference collision.
6. `Tests/Sprint5PhaseF0/EVIDENCE_SCHEMA.json` — require the Magic value and SSOT
   identity in measured-run evidence.
7. `Tests/Sprint5PhaseF0/ATTENDED_DEMO_RUNBOOK.md`, `BROKER_PROFILE.md`,
   `CORRELATION_IDENTITY_DESIGN.md`, `ENVIRONMENT_ATTESTATION.md`,
   `COVERAGE_MATRIX.md`, `TEST_INVENTORY.md`, `NEGATIVE_CONTROLS.md`,
   `PHASE_F0_SELF_VERIFICATION.md`, `TRANSACTION_ORDER_PROFILE.md`, `README.md`,
   `Evidence/README.md`, and this proposal/decision record — refer to the
   symbolic SSOT and governance status; transaction documentation must
   distinguish matching strategy evidence from unrelated rows.
8. Any new post-materialization F0 evidence JSON — record the symbolic profile identity
   and exact value required by `EVIDENCE_SCHEMA.json`; never rewrite historical
   observations.

Historical evidence JSON remains unchanged after materialization: its
`magic=0` row is an observed non-XAUUSD
account/balance record, not a configuration placeholder to backfill.

Existing contract validators, canonical serializers, persistence references,
and Phase B/C/D/E sources consume Magic through existing DTOs and therefore
must not include the configuration header or change for F0.

No Phase-F composition root, Broker Adapter, or production broker-query source
exists in the authorized scope. Those future files must consume the same SSOT
only under a separate Phase-F authorization; this proposal neither names them
as implemented consumers nor authorizes creating them.

## Negative controls

The F0 offline suite contains four proposal-specific deliberate mutants:

| ID | Unsafe behavior | Required detector |
|---|---|---|
| NC-16 | Zero Magic accepted | Require positive and exact SSOT value |
| NC-17 | `5042001`, `5005`, or `550015` accepted as runtime identity | Reject fixture/reference values as deployment authority |
| NC-18 | Ownership, persistence, account-risk, and broker-request Magic disagree | Require all governed domains to equal the SSOT value |
| NC-19 | Magic changes per request | Require immutable value across request/attempt/retry/restart/takeover |

These controls are offline model evidence. They do not approve the candidate or
prove broker behavior.

## Approval boundary and risks

- Fusion approved the value and normative path for this narrow F0 materialization.
- Account-level collision with another EA cannot be excluded by numeric design
  alone; attended query/profile evidence and operational reservation are still
  required.
- Changing the approved value after any persisted/broker evidence exists would
  create a different authority namespace and requires explicit migration and
  reconciliation; silent replacement is forbidden.
- Magic remains strategy scope only. Comment/tickets remain the F0 correlation
  study; request_id remains session-local.
- Phase F, production Broker Adapter, unattended Demo, live trading, Phase G,
  Architecture Lock, and main merge remain unauthorized.

## Materialization verdict

The approved constant instantiates existing semantics without redefining them.
All F0 construction boundaries consume the one SSOT fail-closed. A fresh
post-materialization disarmed/query gate and separate explicit final send
confirmation remain required.

`F0 RUNTIME MAGIC MATERIALIZATION READY FOR FUSION REVIEW`
