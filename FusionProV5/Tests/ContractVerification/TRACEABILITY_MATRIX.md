# Sprint 4.8 Phase B6 V5 Candidate Verification Traceability Matrix

> TEST ONLY - NOT FOR PRODUCTION - NO BROKER ACCESS

| Requirement | Contract field/interface | Executable IDs | Material evidence |
|---|---|---|---|
| Contract compatibility and deterministic output | Version policy and validation context | COM-01–COM-06, COM-09–COM-12 | Exact/migration/rejection decisions; hostile preseed overwritten; invalid clocks/sequences fail closed |
| All 49 Basket transitions | `ValidateTransition`, state/version | BSM-01–BSM-49 | Independent pair table; allowed +1; same/forbidden stable |
| Recovery mutation and durable replay | Recovery evidence and accepted identity set | IFC-01–IFC-03, S44-16, S45BR-01–S45BR-10 | First mutation, exact no-op replay, canonical negative mutations, restart-restored replay |
| IDLE and close-completion invariants | Residual/live counts/query authority | BAS-06, XDM-04, XDM-12 | Missing evidence or residual exposure denies completion |
| Partial-close arithmetic | Partial-close evidence and Basket residual | BAS-03–BAS-05, EXE-11, IFC-27 | Coherent partial allowed; over-close rejected; returned residual remains managed |
| Acknowledgement cannot confirm | Transaction event kind/authority/phase | EXE-16, XDM-11, IFC-26, S45A-01–S45A-06 | Actual acknowledgement interface returns pending, no identity/money mutation, persisted restart not ready |
| Authoritative execution confirmation | `AcceptTransactionEvidence` | EXE-09–EXE-11, IFC-24–IFC-27, S44-17–S44-18, S45A-07–S45A-10 | Full/partial returned state, exact replay idempotency, conflicting fingerprint no mutation |
| Durable execution fingerprint | Canonical event/fingerprint index | S45F-01–S45F-02 | Eight material mutations conflict; identity survives persistence round trip |
| Retry policy and current typed proof | `EvaluateRetry`, Risk freshness evidence, normalization freshness evidence, exclusive authorization deadline | EXE-12, IFC-32, S46DR-01–S46DR-20 | Current canonical retry allows; each context/contract/fence/deadline/freshness/spec/Basket/budget/lifecycle/request mutation denies; evaluation does not mutate pending state |
| Complete restart readiness | Full ordered pending set, broker summary, Hard Kill | PER-05–PER-15, XDM-03, XDM-08, XDM-11, S44-01–S44-05 | Safe/reconcile/retry-forbidden/close-only/halted dispositions from actual set contents |
| Persistence header/payload integrity | Namespace, count, digest, revision, record sequence | PER-01–PER-04, PER-13–PER-15, S44-06–S44-09, S45DP-08–S45DP-12, S46CP-01–S46CP-20 | Foreign/corrupt/stale payloads reject before storage mutation; PER-02 retains a stale non-empty digest after a nested mutation |
| Durable collision-safe event identity | Typed length-prefix event encoding, fingerprint, ordered durable identity set | S46EI-01–S46EI-20 | Exact replay is stable, unseen older evidence is retained, conflicts/malformed payloads reject, and checkpoint round trip reconstructs the full ordered set |
| Persistence deep-copy round trip | Configure/Save/Load interfaces | IFC-33–IFC-36, PRT-01–PRT-11, S44-10–S44-11, S45DP-15–S45DP-16 | Field/order equality, caller isolation, replacement semantics, no stale latest summary |
| Canonical collision resistance | Typed length-prefixed serializer/digest helpers | S45DP-01–S45DP-07, S45DP-13–S45DP-14 | Adversarial delimiter/unicode/field changes differ; independent equal fixtures match |
| Ownership unclaimed acquisition | Claimant/key/CAS/clock bindings | OWN-01, S45BO-01–S45BO-10 | Complete acquired lease; invalid claims return field-equal observed lease |
| Same-owner heartbeat semantics | Immutable fence; mutable liveness/store revision | OWN-06, OWN-11, IFC-39, S44-21–S44-22, S45DO-01–S45DO-16, S45DO-32 | Returned-state heartbeat chain, stable authority fence, monotonic heartbeat/expiry/CAS revision, Risk auth remains valid |
| Typed takeover and stale-owner fencing | Takeover evidence/generation/authority | OWN-03–OWN-05, IFC-19–IFC-21, S44-23–S44-25, S45DO-17–S45DO-31, S45DO-33 | Complete takeover succeeds; every stale/malformed dimension rejects; old authorization invalidated |
| Ownership conflict/release | `DetectConflict`, `Release` | OWN-02, OWN-07–OWN-10, IFC-39–IFC-40 | Conflict identities exposed; stale release rejected; matching lease transitions RELEASED |
| Risk authorization construction | `Evaluate`, authorization DTO | IFC-09, S44-12, S45CR-01 | Complete independently asserted binding and coherent ALLOW state |
| Risk binding mutation resistance | `ValidateAuthorization` | RSK-02–RSK-16, IFC-10–IFC-13, S44-13–S44-15, S45CR-02–S45CR-29 | Every limits/account/mode/Basket/spec/term/money/Hard Kill/fence/identity/time mutation denies |
| Hard Kill release | Typed independent release evidence | RSK-11, IFC-22–IFC-23, XDM-10 | Complete independent release allows; self/incomplete/mismatched release denies |
| Derived unit policy | Operation semantics and directional rounding | UNT-01–UNT-10, IFC-14–IFC-18, S45CU-01–S45CU-20 | Caller flags cannot override; safe rounding material outputs; stale/wrong-side/freeze/stops/range fail closed |
| Statistics monetary completeness | Profit/commission/swap/fee/net | STA-02, STA-08, S44-19 | Actual accumulator changes every component; returned next state finalizes |
| Statistics durable deduplication | Identity set/revision/counts | STA-03–STA-04, STA-10–STA-12, IFC-29, S44-19–S44-20 | Unique and out-of-order mutate once; duplicate changes only duplicate counter |
| Cross-domain gate ordering | Unit/Risk/Persistence/Execution interfaces | XDM-01–XDM-12 | Coherent path succeeds; stale owner, Hard Kill, residual, restart, and spec failures close safely |
| Determinism | Complete inputs and returned DTOs | COM-05, S45CU-16, S45DP-13–S45DP-14 plus suite replay | Independent identical inputs produce identical material results and signatures |

## Sprint 4.7 Phase A additions

| Requirement | Contract field/interface | Executable IDs | Material evidence |
|---|---|---|---|
| Risk projection/request/current-exposure causality | `SWV5_RiskEvaluationInput.intent`, `exposure`, `basket`, `projected`; `ISWV5RiskContract.Evaluate` | S47-RISK-01 through S47-RISK-18 | OPEN/INCREASE lower bounds, REDUCE/CLOSE/CANCEL semantics, current exposure coherence, tolerance acceptance, cleared denial output |
| Canonical finite-number boundary | `SWV5_IsFiniteNumber`; Risk, pending, transaction, confirmation numeric fields | S47-NUM-01 through S47-NUM-18 | NaN/+Infinity denied before comparisons; transaction and persistence paths preserve state |
| Exclusive Hard Kill release interval | `SWV5_HardKillReleaseEvidence.approved_at/expires_at`; `ValidateHardKillRelease` | S47-HK-01 through S47-HK-07 | Only `approved_at <= now < expires_at` permits release; equality denies without latch mutation |
| Checkpoint semantic authority | Checkpoint header/Basket/correlation/pending/Hard Kill plus `ValidateRecord` and `ReconcileRestart` | S47-CHK-01 through S47-CHK-18 | Correctly resealed semantic corruption and foreign restart/broker bindings halt; integrity alone never resumes |
| Retry enum allowlist | Pending lifecycle/state, retry dispositions, retcode class, nested correlation phase; `EvaluateRetry` | S47-RETRY-01 through S47-RETRY-12 | Explicit eligible values allow; unknown/equal-invalid/terminal/conflict values deny; input remains unchanged |

Phase E1 adds `S46E1-01` through `S46E1-15` for typed fingerprint policy, exact one-to-one identity/fingerprint mapping, canonical order, deterministic classification, and fail-closed duplicate/conflicting/orphan/malformed/count/digest cases. `S46E1-16` through `S46E1-18` trace ambiguous mappings through checkpoint validation, save, configure, and load; `S46E1-19` preserves statistics one-count-only behavior; `S46E1-20` preserves execution exposure, residual, and event state on conflict.

The per-ID credibility category and mutation-resistance rationale are authoritative in `TEST_CREDIBILITY_MATRIX.md`.

Sprint 4.7 Phase A retains the unlocked V4 candidate shape. It adds canonical validation behavior only; no DTO or interface signature changed.

## Sprint 4.8 Phase B5 V5 traceability

| Requirement | Contract field/interface | Executable IDs | Material evidence |
|---|---|---|---|
| Additional broker-authoritative margin | `SWV5_MarginProjectionEvidence`; Risk evaluation | S48-MARGIN-01 through S48-MARGIN-15 | Complete request/account/namespace/fence/spec/freshness binding and `projected = current + additional`; tiny positive understatement denies. |
| Complete resulting Basket loss | `SWV5_BasketRiskProjectionEvidence`, nested `SWV5_RiskMonetaryBasis` | S48-LOSS-01 through S48-LOSS-15 | Existing + incremental + adjustment = resulting maximum; full monetary/source/freshness identity bound. |
| Aggregate notional | `SWV5_SymbolUnitSpecification`, Risk projection | S48-NOTIONAL-01 through S48-NOTIONAL-10 | Contract size, calculation mode, price, volume, conversion and specification sequence all materially enforced. |
| Restart semantic authority | `ReconcileRestart`, persisted reconciliation vector, broker summary | S48-RST-01 through S48-RST-20 | Only clean MATCHED exact-V5 complete reconciliation is safe; dirty/unresolved/incomplete/mismatch states halt or reconcile. |
| Independent Hard Kill release authority | `SWV5_HardKillReleaseAuthorityRecord`, `ValidateHardKillRelease`, restart | S48-HKR-*, S48-HKA-* | Checkpoint content integrity cannot originate release authority; missing/forged/stale authority fails closed. |
| Canonical V5 field coverage | V5 DTO serializers/digests | S48-CAN-* | Typed length-prefixed, ordered, nested canonical binding covers all authoritative fields. |
| True reconstructive round trip | Seven required V5 DTOs and test-side LP1 decoder | S48-RT-V5-01 through V5-07 | Serialized input alone constructs a brand-new DTO; exact bytes and digest must match. |
| Decoder fail-closed boundary | LP1 name/type/length/order/nesting/scalars/version | S48-RT-NEG-01 through NEG-11 | Every malformed/truncated/unsupported input is rejected with no default-field reconstruction. |
| Machine metadata identity | `SWV5_PRODUCTION_CONTRACT_VERSION`, `SWV5_PRODUCTION_CONTRACT_POLICY` | S48-META-01 | Reported V5 schema/policy derive from the single compiled source of truth. |

## Sprint 4.8 Phase B6 traceability

| Requirement | Contract field/interface | Executable IDs | Material evidence |
|---|---|---|---|
| Independent broker margin authority | `SWV5_MarginAuthorityRecord`, projection authority reference, `ISWV5RiskContract.Evaluate` | S48-MAUTH-01 through S48-MAUTH-15 | Missing or mismatched authority denies; a coherently resealed tiny caller projection cannot override the unchanged Broker Adapter record. |
| Independent resulting-Basket-risk authority | `SWV5_BasketRiskAuthorityRecord`, source snapshot identity/digest, projection authority reference | S48-BAUTH-01 through S48-BAUTH-15 | Understated caller projection and arbitrary source identity deny against unchanged Risk Governance authority, including impaired-Basket scenarios. |
| Atomic request-set replacement | Checkpoint header, request set/latest, Basket pending count, reconciliation vector/revision/source digest, CAS revision | S48-PAT-01 through S48-PAT-12, S45DP-16, S44-10 through S44-11 | A-to-B and empty replacement publish one coherent checkpoint; rejected replacement preserves the previous checkpoint. |
| V5 identity closure | All test-only `ContractName()` methods, serializer/result/suite identities, decoder exact version | S48-ID-01 through S48-ID-12 | Active identities derive V5 from canonical constants; historical V4 input remains fail-closed. |
| New authority canonical coverage | Typed LP1 serializers/digests for both authority DTOs | S48-CAN-AUTH-01 through S48-CAN-AUTH-02 | Every authority field changes its digest; only the self-digest is excluded. |

## Sprint 4.8 Phase B7 traceability

| Requirement | Contract field/interface | Executable IDs | Material evidence |
|---|---|---|---|
| Complete broker exposure reconciliation | `SWV5_AuthoritativeBrokerSummary`, `basket_id`, `basket_open_volume`, Broker Adapter authority | S48-RFULL-01 through S48-RFULL-02, S48-RFULL-06 through S48-RFULL-20 | Every independently broker-observed exposure, count, identity, sequence, namespace, and digest dimension is compared; one-field coherent mutations remain unsafe. |
| Independent pending-request reconciliation | `SWV5_AuthoritativeRestartRequestSummary`, Execution authority, request count/digest/revision | S48-RFULL-03 through S48-RFULL-04, S48-RFULL-16 through S48-RFULL-18 | Count equality cannot hide a different request set; missing/stale/mismatched independently sealed authority fails closed. |
| Independent reconciliation revision | `SWV5_AuthoritativeRestartRequestSummary.reconciliation_revision` | S48-RFULL-05 | Persistence publication revision must be corroborated by the independently supplied Execution restart snapshot, not copied into Broker Adapter evidence. |
| Restart-authority canonical round trip | Canonical serializer/digest and decoder | S48-CAN-DTO-10, S48-RT-V5-15 | All fields affect the digest and decode into a new exact DTO. |

## Sprint 4.8 Phase B8 traceability

| Requirement | Contract field/interface | Test ID | Verification |
|---|---|---|---|
| Contract-defined mandatory restart queries | Broker/Execution query-mask constants and `SWV5_TestRestartQuerySnapshotValid` | S48-QRY-01 through S48-QRY-10, S48-RFULL-21 | Broker positions/orders/deals/transactions and Execution pending requests are exact owner-specific masks whose union is fixed by V5; caller flags cannot downgrade either gate. |
| Independent request authority source | `SWV5_AuthoritativeRestartRequestSummary.authority`, `.authority_source` | S48-RAUTH-01 through S48-RAUTH-04, S48-RFULL-24 | Execution issuer and Execution/Pending-Request trust source are independently required and digest-bound. |
| Bounded restart freshness | `SWV5_MAX_RESTART_EVIDENCE_AGE_SECONDS_V5`, broker/request `observed_at` | S48-FRESH-01 through S48-FRESH-08, S48-RFULL-22 through S48-RFULL-25 | Zero, future, pre-checkpoint, and older-than-60-second evidence fails; exact 60-second age is accepted. |
| Sequence coherence without cross-domain aliasing | query/broker/request `observation_sequence`, validation-context `evaluation_sequence` | S48-FRESH-09 through S48-FRESH-10 | Independent streams may differ; each is nonzero/current and query evidence cannot be newer than its enclosing broker summary. |
| Isolated request revision mismatch | `request_set_revision`, request-summary digest, checkpoint payload | S48-RST-18 | The case proves a safe baseline, mutates and reseals only independent request authority, and verifies byte-identical valid persistence before rejection. |
| Authority-source reconstruction | canonical restart-request serializer/decoder | S48-CAN-DTO-10, S48-RT-V5-15, S48-RT-NEG-12 | Source is serialized, digest-sensitive, reconstructed from input, and mandatory during decode. |

## Sprint 4.8 Phase B9 traceability

| Requirement | Contract field/interface | Test ID | Verification |
|---|---|---|---|
| Query snapshot authority is independent of wrapper metadata | `SWV5_AuthoritativeQuerySet.observed_at`, `.issuing_component`, `.authority_source`, `.snapshot_digest`; diagnostic-only `.snapshot_id` | S48-QAUTH-01 through S48-QAUTH-06, S48-QAUTH-09 through S48-QAUTH-10 | Old, zero, future, post-wrapper, or coherently resealed stale nested evidence denies; exact boundary and current snapshots allow. The diagnostic label supplies no trust. |
| Owner-specific anti-replay sequence | persisted `broker_query_sequence_high_watermark`, `request_query_sequence_high_watermark`; nested query `observation_sequence` | S48-QAUTH-07 through S48-QAUTH-08 | Each query stream must advance beyond its persisted owner-specific high-watermark without aliasing Broker and Execution clocks. |
| Split query ownership | broker query flags vs Execution pending-request query flags | S48-QRY-01 through S48-QRY-10, S48-QAUTH-09 | Broker Adapter owns positions/orders/deals/transactions; Execution owns pending-request query state; their exact union is the V5 restart requirement. |
| Independent request-side fixtures | `SWV5_TestBindCheckpointRequests` explicit semantic inputs and independently built `SWV5_AuthoritativeRestartRequestSummary` | S48-RFIX-01 through S48-RFIX-02 | Persistence and Execution values no longer originate from the same fixture object; one-side coherent mutation is detected while the other remains unchanged. |
| Query canonical reconstruction | query serializer/digest and test-side decoder | S48-CAN-DTO-11, S48-RT-V5-16, S48-RT-NEG-13 | Every authority field is digest-bound, reconstructs into a new object, and missing timestamp/provenance fails closed. |
| Semantic evidence verification | exporter semantic core and source-bound offline result | EXP48-47, EXP48-57 through EXP48-67 | Either replay stream truncation, malformed/missing offline result/case, or hash-valid fabricated evidence is rejected by generation and both Git verification modes. |

## Sprint 4.8 Phase B10 traceability

| Requirement | Contract field/interface | Test ID | Verification |
|---|---|---|---|
| Closed-world query masks | `SWV5_QUERY_KNOWN_FLAGS_V5`, owner-specific required masks, restart validator | S48-QRY-01 through S48-QRY-13 | Exact owner masks pass; missing, zero, reduced, version-drifted, and unknown completed/authoritative/required bits fail after canonical resealing. |
| Diagnostic-only snapshot label | `SWV5_AuthoritativeQuerySet.snapshot_id` | S48-QID-01 through S48-QID-03 | Empty/arbitrary labels do not grant or deny authority; a fresh-looking label cannot bypass owner-specific sequence anti-replay. |
| Accepted-query proposal | `SWV5_RestartReconciliationResult.accepted_query_watermarks` | S48-QPUB-01 through S48-QPUB-02, S48-QPUB-12 | Only SAFE reconciliation emits the two validated owner-specific sequences and current CAS/revision linkage. |
| Atomic anti-replay publication | `ISWV5PersistenceContract.PublishRestartQueryWatermarks` | S48-QPUB-03 through S48-QPUB-11 | Both anchors, reconciliation/record sequence, written time, store revision, source/payload digests and size publish atomically; replay, rollback, swapping and CAS failure reject without state mutation. |
| Proposal canonical reconstruction | proposal serializer/digest/decoder | S48-CAN-DTO-12, S48-RT-V5-17 | Every proposal semantic is digest-bound and reconstructs into a fresh zeroed DTO. |
| Evidence root of trust | Git-derived tree and canonical B10 verification-source digest core | EXP48-68 through EXP48-73 | Index and commit verification reject a repeated fake tree, direct digest forgery, and recomputed digest over a forged independently derivable source-blob input. |
