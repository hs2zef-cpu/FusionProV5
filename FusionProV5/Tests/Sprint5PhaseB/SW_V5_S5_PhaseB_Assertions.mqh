#ifndef SW_V5_S5_PHASE_B_ASSERTIONS_MQH
#define SW_V5_S5_PHASE_B_ASSERTIONS_MQH

// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// Actual MQL assertions over Phase B pure functions. COMPILE ONLY in Phase B.1.

#include "../../ExecutionLayer/Contracts/SW_V5_S5_Contracts.mqh"
#include "SW_V5_S5_PhaseB_TestVectors.mqh"

int SWV5S5_ASSERTIONS_RUN=0;
int SWV5S5_ASSERTIONS_FAILED=0;

void SWV5S5_Assert(const bool condition)
{
   SWV5S5_ASSERTIONS_RUN++;
   if(!condition) SWV5S5_ASSERTIONS_FAILED++;
}

void SWV5S5_TestInitV5(SWV5_ContractVersion &v)
{
   ZeroMemory(v);
   v.contract_name=SWV5_PRODUCTION_CONTRACT_NAME;
   v.schema_version=SWV5_PRODUCTION_CONTRACT_VERSION;
   v.minimum_compatible_version=SWV5_PRODUCTION_MINIMUM_COMPATIBLE_VERSION;
   v.policy_id=SWV5_PRODUCTION_CONTRACT_POLICY;
}

void SWV5S5_TestContext(SWV5_ContractValidationContext &c,const datetime now,const ulong sequence)
{
   ZeroMemory(c); SWV5S5_TestInitV5(c.expected_version);
   c.clock_id="TEST-CLOCK"; c.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   c.clock_time=now; c.clock_sequence=sequence; c.evaluation_sequence=sequence;
   c.price_tolerance=0.00001; c.volume_tolerance=0.00001;
}

void SWV5S5_TestScope(SWV5_PersistenceNamespace &scope,SWV5_OwnershipFence &fence)
{
   ZeroMemory(scope); ZeroMemory(fence);
   SWV5S5_TestInitV5(scope.contract_version); SWV5S5_TestInitV5(fence.contract_version);
   scope.ownership_namespace.account_login=1001; scope.ownership_namespace.broker_identity="TEST-BROKER";
   scope.ownership_namespace.server="TEST-SERVER"; scope.ownership_namespace.symbol="XAUUSD";
   scope.ownership_namespace.strategy_id="FUSION"; scope.ownership_namespace.magic=5005;
   scope.basket_id.value="BASKET-1";
   fence.ownership_namespace=scope.ownership_namespace; fence.owner.key=scope.ownership_namespace;
   fence.owner.instance_id="OWNER-A"; fence.owner.process_fingerprint="PROC-A"; fence.owner.started_at=800;
   fence.lease_version=3; fence.takeover_generation=2; fence.fencing_token_digest=SWV5S5_SHA256_ABC;
}

void SWV5S5_TestRequest(const SWV5_PersistenceNamespace &scope,SWV5_ExecutionRequestIdentity &request)
{
   ZeroMemory(request); SWV5S5_TestInitV5(request.contract_version);
   string correlation,attempt,idempotency;
   SWV5S5_DeriveRequestBinding(scope,SWV5S5_REQUEST_BINDING_POLICY_ID,
      SWV5S5_REQUEST_BINDING_POLICY_VERSION,"INGRESS-A",0,correlation,attempt,idempotency);
   request.request_id.correlation_id=correlation; request.request_id.attempt_id=attempt;
   request.request_id.parent_attempt_id=""; request.request_id.monotonic_sequence=1;
   request.request_id.created_at=900; request.idempotency_key=idempotency;
}

void SWV5S5_TestNormalized(const SWV5_PersistenceNamespace &scope,const SWV5_OwnershipFence &fence,
                           SWV5_NormalizedUnits &units)
{
   ZeroMemory(units); SWV5S5_TestInitV5(units.contract_version);
   units.persistence_namespace=scope; units.ownership_fence=fence;
   units.derived_operation_semantic=SWV5_UNIT_OPERATION_OPEN;
   units.price=2000.0; units.stop_price=1990.0; units.limit_price=2010.0; units.volume=0.10;
   units.current_exposure_volume=0.0; units.target_exposure_volume=0.10;
   units.resulting_exposure_volume=0.10; units.residual_exposure_volume=0.0;
   units.stop_distance_price=10.0; units.stop_distance_points=1000.0; units.stop_distance_ticks=1000.0;
   units.monetary_tick_value_per_volume_unit=1.0; units.monetary_value_currency="USD";
   units.specification_sequence=7; units.applied_entry_rounding=SWV5_NORMALIZE_NEAREST;
   units.applied_stop_rounding=SWV5_NORMALIZE_DOWN; units.applied_limit_rounding=SWV5_NORMALIZE_UP;
   units.applied_volume_rounding=SWV5_NORMALIZE_DOWN; units.price_aligned_to_tick=true;
   units.volume_aligned_to_step=true; units.stops_level_satisfied=true; units.freeze_level_satisfied=true;
   units.caller_flags_consistent=true;
}

bool SWV5S5_BuildClaimFixture(SWV5_ContractValidationContext &context,
                              SWV5S5_InvocationClaimCommand &command)
{
   SWV5S5_TestContext(context,1000,3);
   SWV5_PersistenceNamespace scope; SWV5_OwnershipFence fence;
   SWV5S5_TestScope(scope,fence);
   SWV5_ExecutionRequestIdentity request; SWV5S5_TestRequest(scope,request);
   SWV5_NormalizedUnits units; SWV5S5_TestNormalized(scope,fence,units);

   SWV5S5_SubmissionPermit permit; ZeroMemory(permit); SWV5S5_InitContractVersion(permit.contract_version);
   permit.permit_policy_id=SWV5S5_PERMIT_POLICY_ID; permit.permit_policy_version=SWV5S5_PERMIT_POLICY_VERSION;
   permit.canonical_format_id=SWV5S5_CANONICAL_POLICY_ID; permit.permit_revision=1; permit.reserved_at=950;
   permit.persistence_namespace=scope; permit.ownership_fence=fence;
   SWV5S5_TestInitV5(permit.account_namespace.contract_version);
   permit.account_namespace.broker_identity="TEST-BROKER"; permit.account_namespace.server="TEST-SERVER";
   permit.account_namespace.account_login=1001; permit.account_namespace.account_currency="USD";
   permit.account_namespace.strategy_id="FUSION"; permit.account_namespace.magic=5005;
   permit.account_namespace.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   permit.account_namespace.authoritative_source=SWV5_AUTHORITY_SIGNAL_DTO;
   permit.account_namespace.snapshot_epoch=4; permit.account_namespace.snapshot_sequence=8;
   permit.account_epoch=4; permit.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   permit.request_identity=request; permit.unique_attempt_id=request.request_id.attempt_id;
   permit.normalized_payload=units; permit.normalization_identity="NORMALIZATION-A";
   permit.symbol_specification_sequence=7; permit.basket_id=scope.basket_id; permit.basket_state_version=2;
   SWV5S5_InitContractVersion(permit.producer_trust.contract_version);
   permit.producer_trust.authority_record_id="TRUST-A"; permit.producer_trust.authority_generation=5;
   permit.producer_trust.issuer_identity="TRUST-ISSUER"; permit.producer_trust.issuer_policy_id="TRUST-POLICY";
   permit.producer_trust.producer_component="DECISION"; permit.producer_trust.producer_instance="PRODUCER-A";
   permit.producer_trust.producer_epoch=6; permit.producer_trust.persistence_namespace=scope;
   permit.producer_trust.symbol="XAUUSD"; permit.producer_trust.timeframe=15; permit.producer_trust.execution_mode=1;
   permit.producer_trust.clock_id="TEST-CLOCK"; permit.producer_trust.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   permit.producer_trust.status=SWV5S5_TRUST_AUTHORIZED; permit.producer_trust.valid_from=900;
   permit.producer_trust.valid_until=1100;
   if(!SWV5S5_DeriveProducerTrustDigest(permit.producer_trust,permit.producer_trust.record_digest)) return false;
   SWV5S5_TestInitV5(permit.risk_authorization.contract_version);
   permit.risk_authorization.authorization_id="RISK-A"; permit.risk_authorization.request_identity=request;
   permit.risk_authorization.persistence_namespace=scope; permit.risk_authorization.ownership_fence=fence;
   permit.risk_authorization.account_namespace=permit.account_namespace;
   permit.risk_authorization.account_mode=SWV5_ACCOUNT_MODE_HEDGING; permit.risk_authorization.disposition=SWV5_RISK_ALLOW;
   permit.risk_authorization.basket_state_version=2; permit.risk_authorization.symbol_specification_sequence=7;
   permit.risk_authorization.authorized_intent_type=SWV5_INTENT_OPEN; permit.risk_authorization.authorized_direction=1;
   permit.risk_authorization.authorized_volume=0.10; permit.risk_authorization.authorized_price=2000.0;
   permit.risk_authorization.authorized_stop_price=1990.0; permit.risk_authorization.authorized_limit_price=2010.0;
   permit.risk_authorization.risk_snapshot_epoch=4; permit.risk_authorization.risk_snapshot_sequence=8;
   permit.risk_authorization.hard_kill_latch_id="HK-A"; permit.risk_authorization.hard_kill_latch_generation=3;
   permit.risk_authorization.evaluated_at=950; permit.risk_authorization.expires_at=1100;
   SWV5S5_TestInitV5(permit.margin_authority.contract_version);
   permit.margin_authority.persistence_namespace=scope; permit.margin_authority.ownership_fence=fence;
   permit.margin_authority.account_namespace=permit.account_namespace;
   permit.margin_authority.request_identity=request; permit.margin_authority.authority_record_id="MARGIN-A";
   permit.margin_authority.basket_id=scope.basket_id; permit.margin_authority.symbol="XAUUSD";
   permit.margin_authority.symbol_specification_sequence=7;
   permit.margin_authority.authority_record_sequence=4; permit.margin_authority.authority_record_digest=SWV5S5_SHA256_EMPTY;
   permit.margin_authority.observation_sequence=4; permit.margin_authority.additional_margin=10.0;
   permit.margin_authority.projected_account_margin=20.0;
   SWV5S5_TestInitV5(permit.basket_risk_authority.contract_version);
   permit.basket_risk_authority.persistence_namespace=scope; permit.basket_risk_authority.ownership_fence=fence;
   permit.basket_risk_authority.account_namespace=permit.account_namespace;
   permit.basket_risk_authority.request_identity=request; permit.basket_risk_authority.authority_record_id="BASKET-RISK-A";
   permit.basket_risk_authority.basket_id=scope.basket_id; permit.basket_risk_authority.basket_state_version=2;
   permit.basket_risk_authority.symbol="XAUUSD"; permit.basket_risk_authority.symbol_specification_sequence=7;
   permit.basket_risk_authority.authority_record_sequence=5;
   permit.basket_risk_authority.authority_record_digest=SWV5S5_SHA256_ABC;
   permit.basket_risk_authority.source_snapshot_digest=SWV5S5_SHA256_EMPTY;
   permit.basket_risk_authority.resulting_basket_maximum_loss=50.0;
   permit.hard_kill_latch_id="HK-A"; permit.hard_kill_latch_generation=3;
   permit.valid_from=900; permit.valid_until=1100;
   if(!SWV5S5_DerivePermitId(permit,permit.permit_id) || !SWV5S5_DerivePermitDigest(permit,permit.permit_digest)) return false;

   SWV5S5_SubmissionAuthorityRecord observed; ZeroMemory(observed); SWV5S5_InitContractVersion(observed.contract_version);
   observed.permit=permit; observed.state=SWV5S5_COMMITTED_NOT_INVOKED; observed.authority_revision=1;
   if(!SWV5S5_DeriveDurableSubmissionAuthorityDigest(observed,observed.durable_record_digest)) return false;

   SWV5S5_AdmissionAuthorityCollection collect; ZeroMemory(collect);
   collect.persistence_namespace=scope; collect.request_identity=request; collect.attempt_id=request.request_id.attempt_id;
   collect.ownership.fence=fence;
   SWV5S5_TestInitV5(collect.lease_liveness.lease.contract_version);
   collect.lease_liveness.lease.fence=fence; collect.lease_liveness.lease.status=SWV5_LOCK_RENEWED;
   collect.lease_liveness.lease.store_revision="LEASE-STORE-4"; collect.lease_liveness.lease.heartbeat_sequence=9;
   collect.lease_liveness.lease.clock_id="TEST-CLOCK"; collect.lease_liveness.lease.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   collect.lease_liveness.lease.heartbeat_clock_sequence=2; collect.lease_liveness.lease.expiry_clock_sequence=9;
   collect.lease_liveness.lease.heartbeat_at=990; collect.lease_liveness.lease.expires_at=1200;
   collect.producer_trust.record=permit.producer_trust;
   SWV5S5_TestInitV5(collect.hard_kill.state.contract_version); collect.hard_kill.state.persistence_namespace=scope;
   collect.hard_kill.state.latch_id="HK-A"; collect.hard_kill.state.latch_generation=3;
   collect.hard_kill.state.state=SWV5_HARD_KILL_INACTIVE;
   collect.account.account_namespace=permit.account_namespace;
   SWV5S5_TestInitV5(collect.basket.basket.contract_version); collect.basket.basket.basket_id=scope.basket_id;
   collect.basket.basket.ownership_fence=fence; collect.basket.basket.state=SWV5_BASKET_IDLE;
   collect.basket.basket.state_version=2; collect.basket.basket.state_entered_at=900;
   collect.request_set.persistence_namespace=scope; collect.request_set.ownership_fence=fence;
   SWV5S5_TestInitV5(collect.request_set.header.contract_version); collect.request_set.header.request_count=0;
   collect.request_set.header.request_index_revision="REQUEST-SET-1"; collect.request_set.header.record_sequence=1;
   if(!SWV5S5_SHA256("",collect.request_set.header.request_set_digest)) return false;
   SWV5S5_TestInitV5(collect.symbol_specification.specification.contract_version);
   collect.symbol_specification.specification.symbol="XAUUSD"; collect.symbol_specification.specification.specification_sequence=7;
   collect.symbol_specification.specification.point_size=0.01; collect.symbol_specification.specification.tick_size=0.01;
   collect.symbol_specification.specification.pip_size=0.1; collect.symbol_specification.specification.tick_value_profit=1.0;
   collect.symbol_specification.specification.tick_value_loss=1.0; collect.symbol_specification.specification.contract_size=100.0;
   collect.symbol_specification.specification.tick_value_basis_volume=1.0;
   collect.symbol_specification.specification.volume_minimum=0.01; collect.symbol_specification.specification.volume_maximum=100.0;
   collect.symbol_specification.specification.volume_step=0.01; collect.symbol_specification.specification.account_currency="USD";
   collect.symbol_specification.specification.tick_value_currency="USD";
   collect.symbol_specification.specification.authority_source=SWV5_AUTHORITY_SIGNAL_DTO;
   collect.symbol_specification.specification.observed_at=990; collect.symbol_specification.specification.valid_until=1100;
   collect.symbol_specification.specification.complete=true;
   collect.margin.record=permit.margin_authority; collect.basket_risk.record=permit.basket_risk_authority;
   collect.risk_authorization.authorization=permit.risk_authorization;
   collect.normalized_payload.payload=units; collect.normalized_payload.normalization_identity="NORMALIZATION-A";
   collect.submission_permit.permit=permit;
   collect.policy_format.admission_policy_id=SWV5S5_POLICY_ID;
   collect.policy_format.admission_policy_version=SWV5S5_SCHEMA_VERSION;
   collect.policy_format.canonical_format_id=SWV5S5_CANONICAL_POLICY_ID;
   collect.collect_clock.clock_id="TEST-CLOCK"; collect.collect_clock.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   collect.collect_clock.clock_sequence=1; collect.collect_clock.observed_at=998;

   SWV5S5_AdmissionSnapshot snapshot; ZeroMemory(snapshot); SWV5S5_InitContractVersion(snapshot.contract_version);
   snapshot.canonical_policy_id=SWV5S5_CANONICAL_POLICY_ID; snapshot.collect_v1=collect; snapshot.collect_v2=collect;
   snapshot.collect_v2.collect_clock.clock_sequence=2; snapshot.collect_v2.collect_clock.observed_at=999;
   SWV5S5_DoubleCollectResult collect_result;
   if(!SWV5S5_DoubleCollect(snapshot,collect_result)) return false;
   snapshot.claim_clock.clock_id="TEST-CLOCK"; snapshot.claim_clock.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   snapshot.claim_clock.clock_sequence=3; snapshot.claim_clock.observed_at=1000;
   if(!SWV5S5_DeriveAdmissionSnapshotDigest(snapshot,snapshot.snapshot_digest)) return false;

   ZeroMemory(command); SWV5S5_InitContractVersion(command.contract_version);
   command.claim_policy_id=SWV5S5_POLICY_ID; command.claim_policy_version=SWV5S5_SCHEMA_VERSION;
   command.expected_authority_record=observed; command.expected_authority_revision=observed.authority_revision;
   command.expected_authority_digest=observed.durable_record_digest; command.admission_snapshot=snapshot;
   command.current_ownership_lease=collect.lease_liveness.lease; command.claim_clock=snapshot.claim_clock;
   if(!SWV5S5_DeriveClaimId(command,command.claim_id) ||
      !SWV5S5_DeriveClaimCommandDigest(command,command.command_digest)) return false;
   return true;
}

bool SWV5S5_RefreshClaimFixture(SWV5S5_InvocationClaimCommand &command)
{
   SWV5S5_SubmissionPermit permit=command.expected_authority_record.permit;
   if(!SWV5S5_DeriveProducerTrustDigest(permit.producer_trust,permit.producer_trust.record_digest) ||
      !SWV5S5_DerivePermitId(permit,permit.permit_id) || !SWV5S5_DerivePermitDigest(permit,permit.permit_digest)) return false;
   command.expected_authority_record.permit=permit;
   if(!SWV5S5_DeriveDurableSubmissionAuthorityDigest(command.expected_authority_record,
                                                      command.expected_authority_record.durable_record_digest)) return false;
   command.expected_authority_digest=command.expected_authority_record.durable_record_digest;
   command.admission_snapshot.collect_v1.producer_trust.record=permit.producer_trust;
   command.admission_snapshot.collect_v2.producer_trust.record=permit.producer_trust;
   command.admission_snapshot.collect_v1.risk_authorization.authorization=permit.risk_authorization;
   command.admission_snapshot.collect_v2.risk_authorization.authorization=permit.risk_authorization;
   command.admission_snapshot.collect_v1.submission_permit.permit=permit;
   command.admission_snapshot.collect_v2.submission_permit.permit=permit;
   command.admission_snapshot.claim_clock=command.claim_clock;
   if(!SWV5S5_DeriveAdmissionSnapshotDigest(command.admission_snapshot,command.admission_snapshot.snapshot_digest) ||
      !SWV5S5_DeriveClaimId(command,command.claim_id) ||
      !SWV5S5_DeriveClaimCommandDigest(command,command.command_digest)) return false;
   return true;
}

void SWV5S5_TestCanonicalAndIdentity()
{
   SWV5S5_Assert(SWV5S5_VectorSHA256Empty());
   SWV5S5_Assert(SWV5S5_VectorSHA256Abc());
   SWV5S5_Assert(SWV5S5_VectorCanonicalScalars());
   SWV5S5_Assert(SWV5S5_VectorNestedIndexed());
   SWV5S5_Assert(SWV5S5_VectorDomainSeparation());
   SWV5_PersistenceNamespace scope; SWV5_OwnershipFence fence; SWV5S5_TestScope(scope,fence);
   SWV5S5_Assert(SWV5S5_VectorRequestIdentity(scope,"INGRESS-A"));
   string c0,a0,k0,c1,a1,k1;
   SWV5S5_DeriveRequestBinding(scope,SWV5S5_REQUEST_BINDING_POLICY_ID,1,"INGRESS-A",0,c0,a0,k0);
   SWV5S5_DeriveRequestBinding(scope,SWV5S5_REQUEST_BINDING_POLICY_ID,1,"INGRESS-A",1,c1,a1,k1);
   SWV5S5_Assert(c0==SWV5S5_EXPECTED_CORRELATION);
   SWV5S5_Assert(a0==SWV5S5_EXPECTED_ATTEMPT_0);
   SWV5S5_Assert(a1==SWV5S5_EXPECTED_ATTEMPT_1);
   SWV5S5_Assert(k0==SWV5S5_EXPECTED_IDEMPOTENCY);
   SWV5S5_Assert(c0==c1); SWV5S5_Assert(a0!=a1); SWV5S5_Assert(k0==k1);
}

void SWV5S5_TestLedgerAndSequence()
{
   SWV5_PersistenceNamespace scope; SWV5_OwnershipFence fence; SWV5S5_TestScope(scope,fence);
   SWV5S5_IngressLedgerIndexEntry entries[]; ArrayResize(entries,0);
   SWV5S5_IngressLedgerHeader header; ZeroMemory(header); SWV5S5_InitContractVersion(header.contract_version);
   header.policy_id=SWV5S5_POLICY_ID; header.persistence_namespace=scope; header.ownership_fence=fence;
   header.producer_authority_record_id="TRUST-A"; header.producer_instance="P"; header.producer_epoch=1;
   header.highest_accepted_publication_sequence=10; header.revision=2;
   SWV5S5_DeriveLedgerIndexDigest(entries,header.membership_binding_index_digest);
   SWV5S5_DeriveLedgerHeaderDigest(header,entries,header.ledger_digest);
   SWV5S5_Assert(SWV5S5_EvaluateLedgerIngress(header,entries,"UNSEEN",SWV5S5_SHA256_EMPTY,10)==SWV5S5_INGRESS_EVALUATION_DENIED);
   SWV5S5_Assert(SWV5S5_EvaluateLedgerIngress(header,entries,"NEW",SWV5S5_SHA256_EMPTY,11)==SWV5S5_INGRESS_EVALUATION_NEW);

   SWV5S5_RequestSequenceIndexEntry reservations[]; ArrayResize(reservations,0);
   SWV5S5_RequestSequenceAuthority authority; ZeroMemory(authority); SWV5S5_InitContractVersion(authority.contract_version);
   authority.policy_id=SWV5S5_REQUEST_BINDING_POLICY_ID; authority.policy_version=1;
   authority.persistence_namespace=scope; authority.ownership_fence=fence;
   authority.allocator_revision=18446744073709551615; authority.request_sequence_high_watermark=2;
   SWV5S5_DeriveSequenceIndexDigest(reservations,authority.reservation_index_digest);
   SWV5S5_DeriveSequenceAuthorityDigest(authority,reservations,authority.authority_digest);
   SWV5S5_RequestSequenceReservation proposal; ZeroMemory(proposal); SWV5S5_InitContractVersion(proposal.contract_version);
   proposal.persistence_namespace=scope; proposal.ownership_fence=fence; proposal.logical_correlation_id="C";
   proposal.binding_digest=SWV5S5_SHA256_EMPTY; proposal.expected_allocator_revision=authority.allocator_revision;
   proposal.expected_authority_digest=authority.authority_digest; proposal.observed_high_watermark=2;
   proposal.proposed_sequence=3; proposal.proposed_allocator_revision=0;
   SWV5S5_DeriveSequenceReservationDigest(proposal,proposal.reservation_digest);
   SWV5S5_RequestSequenceResult sequence_result;
   SWV5S5_Assert(!SWV5S5_PrepareSequenceReservation(authority,reservations,proposal,sequence_result));
   SWV5S5_Assert(sequence_result.disposition==SWV5S5_SEQUENCE_CONFLICT);

   SWV5S5_IngressLedgerIndexEntry before[]; SWV5S5_IngressLedgerIndexEntry after[];
   ArrayResize(before,1); ArrayResize(after,1); ZeroMemory(before[0]);
   before[0].ingress_identity="INGRESS-A"; before[0].publication_sequence=10;
   before[0].payload_digest=SWV5S5_SHA256_EMPTY; before[0].lifecycle_state=SWV5S5_BOUND_TO_REQUEST;
   before[0].logical_correlation_id="CORR-A"; before[0].reserved_request_sequence=1;
   before[0].bound_request_id="REQUEST-A"; before[0].record_sequence=1; before[0].record_revision=2;
   before[0].record_digest=SWV5S5_SHA256_ABC; after[0]=before[0];
   header.membership_count=1; header.compaction_generation=2;
   SWV5S5_DeriveLedgerIndexDigest(before,header.membership_binding_index_digest);
   SWV5S5_DeriveLedgerHeaderDigest(header,before,header.ledger_digest);
   SWV5S5_IngressLedgerCompactionProposal compaction; ZeroMemory(compaction);
   compaction.expected_header=header; compaction.proposed_compaction_generation=3;
   compaction.proposed_revision=3; compaction.preserved_high_watermark=10;
   compaction.proposed_membership_count=1;
   SWV5S5_DeriveLedgerIndexDigest(after,compaction.proposed_membership_digest);
   SWV5S5_DeriveLedgerCompactionProposalDigest(compaction,compaction.proposal_digest);
   SWV5S5_Assert(SWV5S5_ValidateLedgerCompaction(header,before,compaction,after));
   ArrayResize(after,0);
   SWV5S5_Assert(!SWV5S5_ValidateLedgerCompaction(header,before,compaction,after));

   SWV5S5_RequestSequenceIndexEntry indexed[]; ArrayResize(indexed,1); ZeroMemory(indexed[0]);
   indexed[0].logical_correlation_id="C"; indexed[0].reserved_sequence=2;
   indexed[0].reservation_revision=4; indexed[0].binding_digest=SWV5S5_SHA256_EMPTY;
   authority.allocator_revision=4; authority.request_sequence_high_watermark=2; authority.reservation_count=1;
   SWV5S5_DeriveSequenceIndexDigest(indexed,authority.reservation_index_digest);
   SWV5S5_DeriveSequenceAuthorityDigest(authority,indexed,authority.authority_digest);
   proposal.expected_allocator_revision=4; proposal.expected_authority_digest=authority.authority_digest;
   proposal.proposed_sequence=2; proposal.proposed_allocator_revision=4;
   SWV5S5_DeriveSequenceReservationDigest(proposal,proposal.reservation_digest);
   SWV5S5_Assert(SWV5S5_PrepareSequenceReservation(authority,indexed,proposal,sequence_result));
   SWV5S5_Assert(sequence_result.disposition==SWV5S5_SEQUENCE_EXISTING_IDEMPOTENT && sequence_result.reserved_sequence==2);
   proposal.proposed_sequence=3; SWV5S5_DeriveSequenceReservationDigest(proposal,proposal.reservation_digest);
   SWV5S5_Assert(!SWV5S5_PrepareSequenceReservation(authority,indexed,proposal,sequence_result));
   SWV5S5_RequestSequenceAuthority corrupt=authority; corrupt.authority_digest=SWV5S5_SHA256_EMPTY;
   SWV5S5_Assert(!SWV5S5_PrepareSequenceReservation(corrupt,indexed,proposal,sequence_result));
}

void SWV5S5_TestADR020Ordering()
{
   SWV5S5_Assert(SWV5S5_EvaluateConcurrentMutation(SWV5S5_AUTHORITY_HARD_KILL,SWV5S5_MUTATION_BEFORE_P,true)==SWV5S5_MUTATION_BLOCK_CURRENT);
   SWV5S5_Assert(SWV5S5_EvaluateConcurrentMutation(SWV5S5_AUTHORITY_HARD_KILL,SWV5S5_MUTATION_AFTER_P_BEFORE_CLAIM,true)==SWV5S5_MUTATION_CURRENT_RETAINED_LATER_BLOCKED);
   SWV5S5_Assert(SWV5S5_EvaluateConcurrentMutation(SWV5S5_AUTHORITY_HARD_KILL,SWV5S5_MUTATION_AFTER_CLAIM,true)==SWV5S5_MUTATION_POST_CLAIM_RECONCILE);
   SWV5S5_Assert(SWV5S5_TrustMutationDisposition(SWV5S5_MUTATION_BEFORE_P,true,false)==SWV5S5_TRUST_BLOCK_BEFORE_P);
   SWV5S5_Assert(SWV5S5_TrustMutationDisposition(SWV5S5_MUTATION_AFTER_P_BEFORE_CLAIM,true,false)==SWV5S5_TRUST_CURRENT_RETAINED_LATER_BLOCKED);
   SWV5S5_Assert(SWV5S5_TrustMutationDisposition(SWV5S5_MUTATION_AFTER_P_BEFORE_CLAIM,true,true)==SWV5S5_TRUST_CLAIM_TIME_EXPIRED);
}

void SWV5S5_TestSnapshotSemantics()
{
   SWV5_ContractValidationContext context; SWV5S5_InvocationClaimCommand command;
   SWV5S5_Assert(SWV5S5_BuildClaimFixture(context,command));
   SWV5S5_Assert(command.admission_snapshot.collect_v1.collect_clock.observed_at!=command.admission_snapshot.collect_v2.collect_clock.observed_at);
   SWV5S5_Assert(command.admission_snapshot.collect_v2.collect_clock.clock_sequence>=command.admission_snapshot.collect_v1.collect_clock.clock_sequence);
   SWV5S5_Assert(command.admission_snapshot.claim_clock.observed_at>command.admission_snapshot.collect_v2.collect_clock.observed_at);
   SWV5S5_AdmissionSnapshot stable_pair=command.admission_snapshot;
   datetime supplied_claim_time=stable_pair.claim_clock.observed_at;
   SWV5S5_DoubleCollectResult stable_pair_result;
   SWV5S5_Assert(SWV5S5_DoubleCollect(stable_pair,stable_pair_result));
   SWV5S5_Assert(stable_pair.claim_clock.observed_at==supplied_claim_time);

   SWV5S5_AdmissionSnapshot regressed=command.admission_snapshot;
   regressed.collect_v2.collect_clock.clock_sequence=0;
   SWV5S5_DoubleCollectResult result;
   SWV5S5_Assert(!SWV5S5_DoubleCollect(regressed,result));
   SWV5S5_Assert(result.disposition==SWV5S5_COLLECT_CLOCK_REGRESSION);

   SWV5S5_AdmissionSnapshot hard_kill_changed=command.admission_snapshot;
   hard_kill_changed.collect_v2.hard_kill.state.latch_generation++;
   SWV5S5_Assert(!SWV5S5_DoubleCollect(hard_kill_changed,result));
   SWV5S5_Assert(result.disposition==SWV5S5_COLLECT_RETRYABLE_UNSTABLE && result.changed_authority=="HARD_KILL");

   SWV5S5_AdmissionSnapshot aba=command.admission_snapshot;
   aba.collect_v2.ownership.fence.takeover_generation+=2;
   aba.collect_v2.ownership.fence.fencing_token_digest=SWV5S5_SHA256_EMPTY;
   SWV5S5_Assert(!SWV5S5_DoubleCollect(aba,result));
   SWV5S5_Assert(result.changed_authority=="OWNERSHIP");

   SWV5S5_AdmissionSnapshot missing=command.admission_snapshot;
   missing.collect_v2.margin.record.authority_record_id="";
   SWV5S5_Assert(!SWV5S5_DoubleCollect(missing,result));
   SWV5S5_Assert(result.disposition==SWV5S5_COLLECT_FAIL_CLOSED);

   SWV5S5_AdmissionSnapshot wrong_scope=command.admission_snapshot;
   wrong_scope.collect_v2.persistence_namespace.basket_id.value="WRONG";
   SWV5S5_Assert(!SWV5S5_DoubleCollect(wrong_scope,result));
   SWV5S5_Assert(result.changed_authority=="ENVELOPE");

   SWV5S5_AdmissionSnapshot wrong_payload=command.admission_snapshot;
   wrong_payload.collect_v2.normalized_payload.payload.volume=0.20;
   SWV5S5_Assert(!SWV5S5_DoubleCollect(wrong_payload,result));
   SWV5S5_Assert(result.changed_authority=="NORMALIZED_PAYLOAD");

   SWV5S5_AdmissionSnapshot wrong_permit=command.admission_snapshot;
   wrong_permit.collect_v2.submission_permit.permit.permit_revision++;
   SWV5S5_Assert(!SWV5S5_DoubleCollect(wrong_permit,result));
   SWV5S5_Assert(result.disposition==SWV5S5_COLLECT_FAIL_CLOSED);

   string first_digest=command.admission_snapshot.snapshot_digest;
   SWV5S5_AdmissionSnapshot clock_changed=command.admission_snapshot;
   clock_changed.claim_clock.clock_sequence++;
   string changed_digest;
   SWV5S5_Assert(SWV5S5_DeriveAdmissionSnapshotDigest(clock_changed,changed_digest));
   SWV5S5_Assert(first_digest!=changed_digest);
}

bool SWV5S5_BuildTrustFixture(SWV5_ContractValidationContext &context,
                              SWV5S5_ProducerTrustRecord &record,
                              SWV5S5_ProducerTrustAnchor &anchor,
                              SWV5S5_ProducerTrustScope &scope,
                              SWV5S5_IngressEnvelope &ingress)
{
   SWV5S5_InvocationClaimCommand command;
   if(!SWV5S5_BuildClaimFixture(context,command)) return false;
   record=command.expected_authority_record.permit.producer_trust;
   ZeroMemory(anchor); anchor.issuer_identity=record.issuer_identity; anchor.issuer_policy_id=record.issuer_policy_id;
   anchor.trust_anchor_id="ANCHOR-A"; anchor.current_authority_record_id=record.authority_record_id;
   anchor.current_authority_generation=record.authority_generation;
   ZeroMemory(ingress); SWV5S5_InitContractVersion(ingress.contract_version);
   ingress.canonical_policy_id=SWV5S5_CANONICAL_POLICY_ID;
   ingress.producer.authority_record_id=record.authority_record_id;
   ingress.producer.producer_component=record.producer_component;
   ingress.producer.producer_instance=record.producer_instance;
   ingress.producer.producer_epoch=record.producer_epoch;
   ingress.producer.authority_generation=record.authority_generation;
   ingress.snapshot.symbol=record.symbol; ingress.snapshot.timeframe=record.timeframe;
   ingress.snapshot.execution_mode=record.execution_mode;
   ingress.publication.clock_id=record.clock_id; ingress.publication.clock_authority=record.clock_authority;
   ingress.publication.publication_time=990; ingress.publication.publication_sequence=1;
   if(!SWV5S5_DeriveIngressIdentityAndDigest(ingress,ingress.ingress_identity,ingress.payload_digest)) return false;
   ZeroMemory(scope); scope.persistence_namespace=record.persistence_namespace;
   scope.producer_component=record.producer_component; scope.producer_instance=record.producer_instance;
   scope.producer_epoch=record.producer_epoch; scope.symbol=record.symbol; scope.timeframe=record.timeframe;
   scope.execution_mode=record.execution_mode; scope.publication_clock_id=record.clock_id;
   scope.publication_clock_authority=record.clock_authority; scope.ingress_identity=ingress.ingress_identity;
   return true;
}

void SWV5S5_TestProducerTrust()
{
   SWV5_ContractValidationContext context; SWV5S5_ProducerTrustRecord record;
   SWV5S5_ProducerTrustAnchor anchor; SWV5S5_ProducerTrustScope scope; SWV5S5_IngressEnvelope ingress;
   SWV5S5_Assert(SWV5S5_BuildTrustFixture(context,record,anchor,scope,ingress));
   SWV5S5_ValidationResult validation;
   SWV5S5_Assert(SWV5S5_ValidateProducerTrust(context,record,anchor,scope,ingress,validation));
   SWV5S5_ProducerTrustAnchor wrong_anchor=anchor; wrong_anchor.current_authority_generation++;
   SWV5S5_Assert(!SWV5S5_ValidateProducerTrust(context,record,wrong_anchor,scope,ingress,validation));
   wrong_anchor=anchor; wrong_anchor.issuer_identity="WRONG";
   SWV5S5_Assert(!SWV5S5_ValidateProducerTrust(context,record,wrong_anchor,scope,ingress,validation));
   wrong_anchor=anchor; wrong_anchor.issuer_policy_id="WRONG";
   SWV5S5_Assert(!SWV5S5_ValidateProducerTrust(context,record,wrong_anchor,scope,ingress,validation));
   SWV5S5_ProducerTrustScope wrong_scope=scope; wrong_scope.producer_component="WRONG";
   SWV5S5_Assert(!SWV5S5_ValidateProducerTrust(context,record,anchor,wrong_scope,ingress,validation));
   wrong_scope=scope; wrong_scope.producer_instance="WRONG";
   SWV5S5_Assert(!SWV5S5_ValidateProducerTrust(context,record,anchor,wrong_scope,ingress,validation));
   wrong_scope=scope; wrong_scope.producer_epoch++;
   SWV5S5_Assert(!SWV5S5_ValidateProducerTrust(context,record,anchor,wrong_scope,ingress,validation));
   wrong_scope=scope; wrong_scope.persistence_namespace.basket_id.value="WRONG";
   SWV5S5_Assert(!SWV5S5_ValidateProducerTrust(context,record,anchor,wrong_scope,ingress,validation));
   wrong_scope=scope; wrong_scope.symbol="WRONG";
   SWV5S5_Assert(!SWV5S5_ValidateProducerTrust(context,record,anchor,wrong_scope,ingress,validation));
   wrong_scope=scope; wrong_scope.timeframe++;
   SWV5S5_Assert(!SWV5S5_ValidateProducerTrust(context,record,anchor,wrong_scope,ingress,validation));
   wrong_scope=scope; wrong_scope.execution_mode++;
   SWV5S5_Assert(!SWV5S5_ValidateProducerTrust(context,record,anchor,wrong_scope,ingress,validation));
   wrong_scope=scope; wrong_scope.publication_clock_id="WRONG";
   SWV5S5_Assert(!SWV5S5_ValidateProducerTrust(context,record,anchor,wrong_scope,ingress,validation));
   SWV5S5_ProducerTrustRecord status=record; status.status=SWV5S5_TRUST_SUSPENDED;
   SWV5S5_DeriveProducerTrustDigest(status,status.record_digest);
   SWV5S5_Assert(!SWV5S5_ValidateProducerTrust(context,status,anchor,scope,ingress,validation));
   status=record; status.status=SWV5S5_TRUST_REVOKED; SWV5S5_DeriveProducerTrustDigest(status,status.record_digest);
   SWV5S5_Assert(!SWV5S5_ValidateProducerTrust(context,status,anchor,scope,ingress,validation));
   status=record; status.status=SWV5S5_TRUST_SUPERSEDED; status.superseding_record_id="NEXT";
   status.superseding_generation=record.authority_generation+1; SWV5S5_DeriveProducerTrustDigest(status,status.record_digest);
   SWV5S5_Assert(!SWV5S5_ValidateProducerTrust(context,status,anchor,scope,ingress,validation));
   SWV5S5_ProducerTrustRecord successor=record; successor.authority_record_id="NEXT";
   successor.authority_generation++; successor.producer_epoch++; SWV5S5_DeriveProducerTrustDigest(successor,successor.record_digest);
   SWV5S5_ProducerTrustAnchor successor_anchor=anchor; successor_anchor.current_authority_record_id="NEXT";
   successor_anchor.current_authority_generation=successor.authority_generation;
   SWV5S5_Assert(SWV5S5_ValidateTrustSuccessor(status,successor,successor_anchor));
   successor_anchor.current_authority_generation++;
   SWV5S5_Assert(!SWV5S5_ValidateTrustSuccessor(status,successor,successor_anchor));
}

void SWV5S5_TestClaimBoundary()
{
   SWV5_ContractValidationContext context; SWV5S5_InvocationClaimCommand command;
   SWV5S5_Assert(SWV5S5_BuildClaimFixture(context,command));
   SWV5S5_InvocationClaimTransition transition;
   SWV5S5_Assert(SWV5S5_PrepareInvocationClaimTransition(context,command,transition));
   SWV5S5_Assert(transition.transition_eligible);
   SWV5S5_Assert(transition.disposition==SWV5S5_CLAIM_TRANSITION_ELIGIBLE);
   SWV5S5_Assert(transition.proposed_next_record.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED);
   SWV5S5_Assert(transition.proposed_next_record.authority_revision==2);
   SWV5S5_InvocationClaimResult authoritative; ZeroMemory(authoritative); SWV5S5_InitContractVersion(authoritative.contract_version);
   authoritative.disposition=SWV5S5_CLAIM_GRANTED_NOW; authoritative.claim_granted_now=true;
   authoritative.resulting_authority_record=transition.proposed_next_record;
   SWV5S5_Assert(SWV5S5_ValidateAuthoritativeClaimResult(transition,authoritative));

   SWV5S5_InvocationClaimCommand replay=command;
   replay.expected_authority_record=transition.proposed_next_record;
   replay.expected_authority_revision=transition.proposed_next_record.authority_revision;
   replay.expected_authority_digest=transition.proposed_next_record.durable_record_digest;
   SWV5S5_DeriveClaimId(replay,replay.claim_id); SWV5S5_DeriveClaimCommandDigest(replay,replay.command_digest);
   SWV5S5_InvocationClaimTransition replay_transition;
   SWV5S5_Assert(!SWV5S5_PrepareInvocationClaimTransition(context,replay,replay_transition));
   SWV5S5_Assert(replay_transition.disposition==SWV5S5_CLAIM_ALREADY_CLAIMED);

   SWV5S5_InvocationClaimCommand random_snapshot=command;
   random_snapshot.admission_snapshot.snapshot_digest=SWV5S5_SHA256_EMPTY;
   SWV5S5_InvocationClaimTransition random_result;
   SWV5S5_Assert(!SWV5S5_PrepareInvocationClaimTransition(context,random_snapshot,random_result));
   SWV5S5_Assert(random_result.disposition==SWV5S5_CLAIM_SNAPSHOT_MISMATCH);

   SWV5S5_InvocationClaimCommand stale=command;
   stale.current_ownership_lease.fence.takeover_generation++;
   SWV5S5_DeriveClaimCommandDigest(stale,stale.command_digest);
   SWV5S5_InvocationClaimTransition stale_result;
   SWV5S5_Assert(!SWV5S5_PrepareInvocationClaimTransition(context,stale,stale_result));
   SWV5S5_Assert(stale_result.disposition==SWV5S5_CLAIM_STALE_OWNER);

   SWV5S5_InvocationClaimCommand wrong_request=command;
   wrong_request.admission_snapshot.collect_v2.request_identity.request_id.attempt_id="WRONG";
   SWV5S5_DeriveAdmissionSnapshotDigest(wrong_request.admission_snapshot,wrong_request.admission_snapshot.snapshot_digest);
   SWV5S5_DeriveClaimId(wrong_request,wrong_request.claim_id); SWV5S5_DeriveClaimCommandDigest(wrong_request,wrong_request.command_digest);
   SWV5S5_InvocationClaimTransition wrong_result;
   SWV5S5_Assert(!SWV5S5_PrepareInvocationClaimTransition(context,wrong_request,wrong_result));
   SWV5S5_Assert(wrong_result.disposition==SWV5S5_CLAIM_SNAPSHOT_MISMATCH);

   SWV5S5_InvocationClaimCommand wrong_payload=command;
   wrong_payload.admission_snapshot.collect_v2.normalized_payload.payload.volume=0.20;
   SWV5S5_DeriveAdmissionSnapshotDigest(wrong_payload.admission_snapshot,wrong_payload.admission_snapshot.snapshot_digest);
   SWV5S5_DeriveClaimId(wrong_payload,wrong_payload.claim_id); SWV5S5_DeriveClaimCommandDigest(wrong_payload,wrong_payload.command_digest);
   SWV5S5_InvocationClaimTransition wrong_payload_result;
   SWV5S5_Assert(!SWV5S5_PrepareInvocationClaimTransition(context,wrong_payload,wrong_payload_result));
   SWV5S5_Assert(wrong_payload_result.disposition==SWV5S5_CLAIM_SNAPSHOT_MISMATCH);

   SWV5S5_InvocationClaimCommand wrong_permit=command;
   wrong_permit.admission_snapshot.collect_v2.submission_permit.permit.permit_revision++;
   SWV5S5_DerivePermitDigest(wrong_permit.admission_snapshot.collect_v2.submission_permit.permit,
                             wrong_permit.admission_snapshot.collect_v2.submission_permit.permit.permit_digest);
   SWV5S5_DeriveAdmissionSnapshotDigest(wrong_permit.admission_snapshot,wrong_permit.admission_snapshot.snapshot_digest);
   SWV5S5_DeriveClaimId(wrong_permit,wrong_permit.claim_id); SWV5S5_DeriveClaimCommandDigest(wrong_permit,wrong_permit.command_digest);
   SWV5S5_InvocationClaimTransition wrong_permit_result;
   SWV5S5_Assert(!SWV5S5_PrepareInvocationClaimTransition(context,wrong_permit,wrong_permit_result));
   SWV5S5_Assert(wrong_permit_result.disposition==SWV5S5_CLAIM_SNAPSHOT_MISMATCH);

   SWV5_ContractValidationContext expired_context=context; expired_context.clock_time=1100; expired_context.clock_sequence=4;
   SWV5S5_InvocationClaimCommand expired=command; expired.claim_clock.clock_sequence=4; expired.claim_clock.observed_at=1100;
   expired.admission_snapshot.claim_clock=expired.claim_clock;
   SWV5S5_DeriveAdmissionSnapshotDigest(expired.admission_snapshot,expired.admission_snapshot.snapshot_digest);
   SWV5S5_DeriveClaimId(expired,expired.claim_id); SWV5S5_DeriveClaimCommandDigest(expired,expired.command_digest);
   SWV5S5_InvocationClaimTransition expired_result;
   SWV5S5_Assert(!SWV5S5_PrepareInvocationClaimTransition(expired_context,expired,expired_result));
   SWV5S5_Assert(expired_result.disposition==SWV5S5_CLAIM_EXPIRED);

   SWV5S5_InvocationClaimCommand risk_expired=command;
   risk_expired.expected_authority_record.permit.risk_authorization.expires_at=1000;
   SWV5S5_Assert(SWV5S5_RefreshClaimFixture(risk_expired));
   SWV5S5_InvocationClaimTransition risk_expired_result;
   SWV5S5_Assert(!SWV5S5_PrepareInvocationClaimTransition(context,risk_expired,risk_expired_result));
   SWV5S5_Assert(risk_expired_result.disposition==SWV5S5_CLAIM_EXPIRED);

   SWV5S5_InvocationClaimCommand trust_expired=command;
   trust_expired.expected_authority_record.permit.producer_trust.valid_until=1000;
   SWV5S5_Assert(SWV5S5_RefreshClaimFixture(trust_expired));
   SWV5S5_InvocationClaimTransition trust_expired_result;
   SWV5S5_Assert(!SWV5S5_PrepareInvocationClaimTransition(context,trust_expired,trust_expired_result));
   SWV5S5_Assert(trust_expired_result.disposition==SWV5S5_CLAIM_EXPIRED);
}

void SWV5S5_TestPermitIdentity()
{
   SWV5_ContractValidationContext context; SWV5S5_InvocationClaimCommand command;
   SWV5S5_Assert(SWV5S5_BuildClaimFixture(context,command));
   SWV5S5_SubmissionPermit first=command.expected_authority_record.permit;
   SWV5S5_SubmissionPermit revised=first; revised.permit_revision++;
   string first_id,revised_id; SWV5S5_DerivePermitId(first,first_id); SWV5S5_DerivePermitId(revised,revised_id);
   SWV5S5_Assert(first_id==SWV5S5_EXPECTED_PERMIT_ID);
   SWV5S5_Assert(first_id==revised_id);
   SWV5S5_DerivePermitDigest(revised,revised.permit_digest);
   SWV5S5_Assert(SWV5S5_EvaluatePermitIdentityConflict(first,revised)==SWV5S5_PERMIT_CONFLICT);
}

void SWV5S5_TestBlueprintAndPermitPreparation()
{
   SWV5_ContractValidationContext context; SWV5S5_InvocationClaimCommand command;
   SWV5S5_Assert(SWV5S5_BuildClaimFixture(context,command));
   SWV5S5_SubmissionPermit permit=command.expected_authority_record.permit;
   SWV5S5_InitialRequestBlueprint blueprint; ZeroMemory(blueprint); SWV5S5_InitContractVersion(blueprint.contract_version);
   SWV5S5_InitContractVersion(blueprint.binding.contract_version);
   blueprint.binding.binding_policy_id=SWV5S5_REQUEST_BINDING_POLICY_ID;
   blueprint.binding.binding_policy_version=SWV5S5_REQUEST_BINDING_POLICY_VERSION;
   blueprint.binding.persistence_namespace=permit.persistence_namespace;
   blueprint.binding.accepted_ingress_identity="INGRESS-A"; blueprint.binding.accepted_at=900;
   blueprint.binding.logical_correlation_id=permit.request_identity.request_id.correlation_id;
   blueprint.binding.logical_request_sequence=permit.request_identity.request_id.monotonic_sequence;
   blueprint.binding.attempt_ordinal=0; blueprint.binding.attempt_id=permit.request_identity.request_id.attempt_id;
   blueprint.binding.idempotency_key=permit.request_identity.idempotency_key;
   SWV5S5_DeriveRequestBindingDigest(blueprint.binding,blueprint.binding.binding_digest);
   SWV5S5_TestInitV5(blueprint.pending_request.contract_version);
   SWV5S5_TestInitV5(blueprint.pending_request.intent.contract_version);
   blueprint.pending_request.intent.persistence_namespace=permit.persistence_namespace;
   blueprint.pending_request.intent.ownership_fence=permit.ownership_fence;
   blueprint.pending_request.intent.request_identity=permit.request_identity;
   blueprint.pending_request.intent.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   blueprint.pending_request.intent.intent_type=SWV5_INTENT_OPEN; blueprint.pending_request.intent.direction=1;
   blueprint.pending_request.intent.normalized_volume=permit.normalized_payload.volume;
   blueprint.pending_request.intent.normalized_price=permit.normalized_payload.price;
   blueprint.pending_request.intent.normalized_stop_price=permit.normalized_payload.stop_price;
   blueprint.pending_request.intent.normalized_limit_price=permit.normalized_payload.limit_price;
   blueprint.pending_request.intent.symbol_specification_sequence=permit.symbol_specification_sequence;
   blueprint.pending_request.intent.expected_basket_version=permit.basket_state_version;
   blueprint.pending_request.intent.risk_authorization_id=permit.risk_authorization.authorization_id;
   blueprint.pending_request.intent.authorization_expires_at=permit.risk_authorization.expires_at;
   blueprint.pending_request.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   blueprint.pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_INTENT;
   blueprint.pending_request.state=SWV5_REQUEST_CREATED;
   blueprint.pending_request.residual_requested_volume=permit.normalized_payload.volume;
   blueprint.pending_request.retry_disposition=SWV5_RETRY_FORBIDDEN;
   blueprint.pending_request.authorization_identity=permit.risk_authorization.authorization_id;
   blueprint.pending_request.normalization_identity=permit.normalization_identity;
   blueprint.pending_request.last_changed_at=900;
   SWV5S5_DeriveInitialBlueprintDigest(blueprint,blueprint.blueprint_digest);
   SWV5S5_ValidationResult validation;
   SWV5S5_Assert(SWV5S5_ValidateInitialBlueprint(context,blueprint,validation));
   SWV5S5_InitialRequestBlueprint invalid=blueprint; invalid.pending_request.state=SWV5_REQUEST_ACKNOWLEDGED;
   SWV5S5_Assert(!SWV5S5_ValidateInitialBlueprint(context,invalid,validation));
   invalid=blueprint; invalid.pending_request.intent.request_identity.request_id.created_at=901;
   SWV5S5_Assert(!SWV5S5_ValidateInitialBlueprint(context,invalid,validation));
   invalid=blueprint; SWV5S5_TestInitV5(invalid.pending_request.latest_submission.contract_version);
   SWV5S5_Assert(!SWV5S5_ValidateInitialBlueprint(context,invalid,validation));
   invalid=blueprint; invalid.pending_request.latest_retcode.broker_comment="FABRICATED";
   SWV5S5_Assert(!SWV5S5_ValidateInitialBlueprint(context,invalid,validation));
   invalid=blueprint; invalid.pending_request.latest_authoritative_confirmation.residual_volume=0.01;
   SWV5S5_Assert(!SWV5S5_ValidateInitialBlueprint(context,invalid,validation));

   SWV5S5_SubmissionAuthorityIndexEntry index[]; ArrayResize(index,0);
   SWV5S5_PermitPreparationCommand preparation; ZeroMemory(preparation); SWV5S5_InitContractVersion(preparation.contract_version);
   SWV5S5_DeriveSubmissionIndexDigest(index,preparation.expected_index_digest);
   preparation.expected_index_revision=0; preparation.proposed_permit=permit;
   SWV5S5_DerivePermitPreparationCommandDigest(preparation,preparation.command_digest);
   SWV5S5_PermitPreparationResult prepared;
   SWV5S5_Assert(SWV5S5_PreparePermitCommit(context,index,preparation,prepared));
   SWV5S5_Assert(prepared.disposition==SWV5S5_PERMIT_PROPOSAL_VALID);
   SWV5S5_Assert(prepared.proposed_record.state==SWV5S5_COMMITTED_NOT_INVOKED);
   ArrayResize(index,1); ZeroMemory(index[0]);
   index[0].logical_correlation_id=permit.request_identity.request_id.correlation_id;
   index[0].attempt_id="OTHER-ATTEMPT"; index[0].permit_id="OTHER-PERMIT";
   index[0].permit_digest=SWV5S5_SHA256_EMPTY; index[0].state=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED;
   SWV5S5_DeriveSubmissionIndexDigest(index,preparation.expected_index_digest);
   SWV5S5_DerivePermitPreparationCommandDigest(preparation,preparation.command_digest);
   SWV5S5_Assert(!SWV5S5_PreparePermitCommit(context,index,preparation,prepared));
   SWV5S5_Assert(prepared.disposition==SWV5S5_PERMIT_LOGICAL_REQUEST_UNRESOLVED);
}

void SWV5S5_TestFencedPublication()
{
   SWV5_ContractValidationContext context; SWV5S5_InvocationClaimCommand command;
   SWV5S5_Assert(SWV5S5_BuildClaimFixture(context,command));
   SWV5S5_SubmissionPermit permit=command.expected_authority_record.permit;
   SWV5_PendingRequest current_requests[]; SWV5_PendingRequest proposed_requests[];
   ArrayResize(current_requests,1); ArrayResize(proposed_requests,1); ZeroMemory(current_requests[0]);
   SWV5S5_TestInitV5(current_requests[0].contract_version); SWV5S5_TestInitV5(current_requests[0].intent.contract_version);
   current_requests[0].intent.persistence_namespace=permit.persistence_namespace;
   current_requests[0].intent.ownership_fence=permit.ownership_fence;
   current_requests[0].intent.request_identity=permit.request_identity;
   current_requests[0].lifecycle_phase=SWV5_EXECUTION_PHASE_INTENT;
   current_requests[0].state=SWV5_REQUEST_CREATED; current_requests[0].last_changed_at=900;
   proposed_requests[0]=current_requests[0]; proposed_requests[0].state=SWV5_REQUEST_RISK_AUTHORIZED;
   string current_digest,proposed_digest;
   SWV5S5_DeriveCompleteRequestSetDigest(current_requests,current_digest);
   SWV5S5_DeriveCompleteRequestSetDigest(proposed_requests,proposed_digest);
   SWV5S5_RequestSetPublicationAuthority authority; ZeroMemory(authority); SWV5S5_InitContractVersion(authority.contract_version);
   authority.policy_id=SWV5S5_PUBLICATION_POLICY_ID; authority.policy_version=1;
   authority.persistence_namespace=permit.persistence_namespace; authority.ownership_fence=permit.ownership_fence;
   authority.store_revision="STORE-1"; SWV5S5_TestInitV5(authority.current_set_header.contract_version);
   authority.current_set_header.request_count=1; authority.current_set_header.request_set_digest=current_digest;
   authority.current_set_header.request_index_revision="SET-1"; authority.current_set_header.record_sequence=4;
   authority.current_complete_set_digest=current_digest;
   SWV5S5_RequestSetPublicationProposal proposal; ZeroMemory(proposal); SWV5S5_InitContractVersion(proposal.contract_version);
   proposal.policy_id=SWV5S5_PUBLICATION_POLICY_ID; proposal.policy_version=1;
   proposal.persistence_namespace=permit.persistence_namespace; proposal.expected_ownership_fence=permit.ownership_fence;
   proposal.expected_takeover_generation=permit.ownership_fence.takeover_generation;
   proposal.expected_store_revision="STORE-1"; proposal.expected_request_set_revision="SET-1";
   proposal.expected_request_set_digest=current_digest; proposal.expected_record_sequence=4;
   proposal.proposed_store_revision="STORE-2"; SWV5S5_TestInitV5(proposal.proposed_set_header.contract_version);
   proposal.proposed_set_header.request_count=1; proposal.proposed_set_header.request_set_digest=proposed_digest;
   proposal.proposed_set_header.request_index_revision="SET-2"; proposal.proposed_set_header.record_sequence=5;
   proposal.proposed_complete_set_digest=proposed_digest;
   SWV5S5_DeriveRequestSetProposalDigest(proposal,proposal.proposal_digest);
   SWV5S5_FencedPublicationResult result;
   SWV5S5_Assert(SWV5S5_EvaluateRequestSetPublication(authority,current_requests,proposal,proposed_requests,result));
   SWV5S5_Assert(result.disposition==SWV5S5_PUBLICATION_PROPOSAL_VALID);
   SWV5S5_RequestSetPublicationProposal stale=proposal; stale.expected_request_set_digest=SWV5S5_SHA256_EMPTY;
   SWV5S5_DeriveRequestSetProposalDigest(stale,stale.proposal_digest);
   SWV5S5_Assert(!SWV5S5_EvaluateRequestSetPublication(authority,current_requests,stale,proposed_requests,result));
   SWV5S5_Assert(result.disposition==SWV5S5_PUBLICATION_STALE_REVISION);
   stale=proposal; stale.expected_store_revision="STALE"; SWV5S5_DeriveRequestSetProposalDigest(stale,stale.proposal_digest);
   SWV5S5_Assert(!SWV5S5_EvaluateRequestSetPublication(authority,current_requests,stale,proposed_requests,result));
   stale=proposal; stale.expected_ownership_fence.takeover_generation++; SWV5S5_DeriveRequestSetProposalDigest(stale,stale.proposal_digest);
   SWV5S5_Assert(!SWV5S5_EvaluateRequestSetPublication(authority,current_requests,stale,proposed_requests,result));
   stale=proposal; stale.expected_takeover_generation++; SWV5S5_DeriveRequestSetProposalDigest(stale,stale.proposal_digest);
   SWV5S5_Assert(!SWV5S5_EvaluateRequestSetPublication(authority,current_requests,stale,proposed_requests,result));
   proposed_requests[0].state=SWV5_REQUEST_CONFIRMED;
   SWV5S5_Assert(!SWV5S5_EvaluateRequestSetPublication(authority,current_requests,proposal,proposed_requests,result));

   SWV5S5_CheckpointPublicationAuthority checkpoint_authority; ZeroMemory(checkpoint_authority);
   SWV5S5_InitContractVersion(checkpoint_authority.contract_version);
   checkpoint_authority.policy_id=SWV5S5_PUBLICATION_POLICY_ID; checkpoint_authority.policy_version=1;
   checkpoint_authority.persistence_namespace=permit.persistence_namespace; checkpoint_authority.ownership_fence=permit.ownership_fence;
   SWV5S5_TestInitV5(checkpoint_authority.current_header.contract_version);
   checkpoint_authority.current_header.persistence_namespace=permit.persistence_namespace;
   checkpoint_authority.current_header.ownership_fence=permit.ownership_fence;
   checkpoint_authority.current_header.record_sequence=7; checkpoint_authority.current_header.store_revision="CP-1";
   checkpoint_authority.current_checkpoint_projection_digest=SWV5S5_SHA256_EMPTY;
   SWV5S5_CheckpointPublicationProposal checkpoint; ZeroMemory(checkpoint); SWV5S5_InitContractVersion(checkpoint.contract_version);
   checkpoint.policy_id=SWV5S5_PUBLICATION_POLICY_ID; checkpoint.policy_version=1;
   checkpoint.persistence_namespace=permit.persistence_namespace; checkpoint.expected_ownership_fence=permit.ownership_fence;
   checkpoint.expected_takeover_generation=permit.ownership_fence.takeover_generation;
   checkpoint.expected_store_revision="CP-1"; checkpoint.expected_record_sequence=7;
   checkpoint.expected_checkpoint_projection_digest=SWV5S5_SHA256_EMPTY;
   SWV5S5_TestInitV5(checkpoint.proposed_checkpoint.header.contract_version);
   checkpoint.proposed_checkpoint.header.persistence_namespace=permit.persistence_namespace;
   checkpoint.proposed_checkpoint.header.ownership_fence=permit.ownership_fence;
   checkpoint.proposed_checkpoint.header.previous_record_sequence=7;
   checkpoint.proposed_checkpoint.header.record_sequence=8; checkpoint.proposed_checkpoint.header.store_revision="CP-2";
   checkpoint.proposed_checkpoint.header.payload_digest=SWV5S5_SHA256_ABC;
   SWV5S5_DeriveCheckpointProjection(checkpoint.proposed_checkpoint,checkpoint.proposed_checkpoint_projection_digest);
   SWV5S5_DeriveCheckpointProposalDigest(checkpoint,checkpoint.proposal_digest);
   SWV5S5_Assert(SWV5S5_EvaluateCheckpointPublication(checkpoint_authority,checkpoint,result));
   SWV5S5_Assert(result.disposition==SWV5S5_PUBLICATION_PROPOSAL_VALID);
   SWV5S5_CheckpointPublicationProposal wrong_checkpoint=checkpoint;
   wrong_checkpoint.expected_record_sequence=6; SWV5S5_DeriveCheckpointProposalDigest(wrong_checkpoint,wrong_checkpoint.proposal_digest);
   SWV5S5_Assert(!SWV5S5_EvaluateCheckpointPublication(checkpoint_authority,wrong_checkpoint,result));
   wrong_checkpoint=checkpoint; wrong_checkpoint.proposed_checkpoint.header.payload_digest=SWV5S5_SHA256_EMPTY;
   SWV5S5_Assert(!SWV5S5_EvaluateCheckpointPublication(checkpoint_authority,wrong_checkpoint,result));
}

int SWV5S5_RunAllPhaseBAssertions()
{
   SWV5S5_ASSERTIONS_RUN=0; SWV5S5_ASSERTIONS_FAILED=0;
   SWV5S5_TestCanonicalAndIdentity();
   SWV5S5_TestLedgerAndSequence();
   SWV5S5_TestADR020Ordering();
   SWV5S5_TestSnapshotSemantics();
   SWV5S5_TestProducerTrust();
   SWV5S5_TestClaimBoundary();
   SWV5S5_TestPermitIdentity();
   SWV5S5_TestBlueprintAndPermitPreparation();
   SWV5S5_TestFencedPublication();
   return SWV5S5_ASSERTIONS_FAILED;
}

#endif
