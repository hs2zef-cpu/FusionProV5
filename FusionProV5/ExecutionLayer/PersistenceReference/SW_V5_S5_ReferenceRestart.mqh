#ifndef SW_V5_S5_REFERENCE_RESTART_MQH
#define SW_V5_S5_REFERENCE_RESTART_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
#include "SW_V5_S5_ReferenceGenesis.mqh"
#include "SW_V5_S5_FakePlatformQuerySource.mqh"
#include "SW_V5_S5_ReferenceLeaseStore.mqh"

struct SWV5S5_ReferenceRestartResult
{
   SWV5_RestartReadinessDisposition disposition;
   bool increasing_execution_eligible;
   bool query_union_complete;
   bool authoritative_sources_separated;
   string diagnostic;
};

bool SWV5S5_ReferenceReleaseAuthorityPreimage(const SWV5_HardKillReleaseAuthorityRecord &record,
                                               string &preimage)
{
   string f; preimage="";
#define SWV5S5_HKA_ADD(x) if(!(x)) return false; else preimage+=f
   SWV5S5_HKA_ADD(SWV5S5_CanonicalContractVersion("contract_version",record.contract_version,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalNamespace("persistence_namespace",record.persistence_namespace,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalAccountNamespace("account_namespace",record.account_namespace,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalString("latch_id",record.latch_id,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalUInt("latch_generation",record.latch_generation,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalString("release_id",record.release_id,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalUInt("release_generation",record.release_generation,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalOperatorIdentity("operator_identity",record.operator_identity,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalInt("approving_component",record.approving_component,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalString("approval_policy_id",record.approval_policy_id,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalUInt("approval_sequence",record.approval_sequence,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalCheckpointTypedEvidence("broker_evidence_reference",record.broker_evidence_reference,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalCheckpointTypedEvidence("persistence_evidence_reference",record.persistence_evidence_reference,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalCheckpointExposureEvidence("exposure_evidence_reference",record.exposure_evidence_reference,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalDatetime("approved_at",record.approved_at,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalDatetime("released_at",record.released_at,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalDatetime("expires_at",record.expires_at,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalUInt("release_record_sequence",record.release_record_sequence,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalString("authority_record_id",record.authority_record_id,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalInt("issuing_component",record.issuing_component,f));
   SWV5S5_HKA_ADD(SWV5S5_CanonicalInt("authority_source",record.authority_source,f));
#undef SWV5S5_HKA_ADD
   return true;
}

bool SWV5S5_ReferenceReleaseAuthorityDigest(const SWV5_HardKillReleaseAuthorityRecord &record,
                                             string &digest)
{
   string preimage,format;
   return SWV5S5_ReferenceReleaseAuthorityPreimage(record,preimage) &&
      SWV5S5_CanonicalString("format","SWV5-HARD-KILL-AUTHORITY-V5-LP1",format) &&
      SWV5S5_SHA256(format+preimage,digest);
}

bool SWV5S5_ReferenceAccountNamespaceEqual(const SWV5_AccountRiskNamespace &a,
                                            const SWV5_AccountRiskNamespace &b)
{
   string ca,cb;
   return SWV5S5_CanonicalAccountNamespace("account_namespace",a,ca) &&
      SWV5S5_CanonicalAccountNamespace("account_namespace",b,cb) && ca==cb;
}

bool SWV5S5_ReferenceTypedEvidenceEqual(const SWV5_TypedReconciliationEvidence &a,
                                         const SWV5_TypedReconciliationEvidence &b)
{
   string ca,cb;
   return SWV5S5_CanonicalCheckpointTypedEvidence("evidence",a,ca) &&
      SWV5S5_CanonicalCheckpointTypedEvidence("evidence",b,cb) && ca==cb;
}

bool SWV5S5_ReferenceExposureEvidenceEqual(const SWV5_ExposureReductionEvidence &a,
                                            const SWV5_ExposureReductionEvidence &b)
{
   string ca,cb;
   return SWV5S5_CanonicalCheckpointExposureEvidence("evidence",a,ca) &&
      SWV5S5_CanonicalCheckpointExposureEvidence("evidence",b,cb) && ca==cb;
}

bool SWV5S5_ReferenceRestartNear(const double a,const double b,const double tolerance)
{ return SWV5_IsFiniteNumber(a) && SWV5_IsFiniteNumber(b) && MathAbs(a-b)<=tolerance; }

bool SWV5S5_ReferenceRestartCorrelationEqual(const SWV5_ExecutionCorrelation &a,
                                              const SWV5_ExecutionCorrelation &b)
{
   string ca,cb; return SWV5S5_CanonicalCheckpointCorrelation("correlation",a,ca) &&
      SWV5S5_CanonicalCheckpointCorrelation("correlation",b,cb) && ca==cb;
}

bool SWV5S5_ReferenceRestartBrokerIdentityEqual(const SWV5_BrokerExecutionIdentity &a,
                                                 const SWV5_BrokerExecutionIdentity &b)
{
   string ca,cb; return SWV5S5_CanonicalCheckpointBrokerIdentity("broker",a,ca) &&
      SWV5S5_CanonicalCheckpointBrokerIdentity("broker",b,cb) && ca==cb;
}

bool SWV5S5_ReferenceLiveLeaseValid(const SWV5_ContractValidationContext &context,
                                     const SWV5_InstanceLease &lease,
                                     const SWV5_OwnershipFence &claimant_fence)
{
   string expected_fence_digest;
   return SWV5_TestHeartbeatValid(context,lease,lease) && lease.store_revision!="" &&
      SWV5S5_ReferenceOwnershipKeyComplete(lease.fence.ownership_namespace) &&
      SWV5S5_ReferenceOwnerComplete(lease.fence.owner) &&
      SWV5S5_ReferenceOwnershipKeyEqual(lease.fence.owner.key,lease.fence.ownership_namespace) &&
      SWV5S5_EqualFence(lease.fence,claimant_fence) &&
      SWV5S5_ReferenceDeriveFenceToken(lease.fence,expected_fence_digest) &&
      lease.fence.fencing_token_digest==expected_fence_digest;
}

bool SWV5S5_ReferencePersistedRequestEqual(const SWV5_PersistedRequestEvidence &a,
                                            const SWV5_PersistedRequestEvidence &b)
{
   string ca,cb; return SWV5S5_CanonicalCheckpointPersistedRequest("request",a,ca) &&
      SWV5S5_CanonicalCheckpointPersistedRequest("request",b,cb) && ca==cb;
}

bool SWV5S5_ReferencePersistedRequestValid(const SWV5_PersistedRequestEvidence &evidence,
                                            const SWV5_PersistenceNamespace &scope,
                                            const SWV5_OwnershipFence &fence,
                                            const SWV5_AccountPositionMode account_mode)
{
   string canonical;
   const SWV5_PendingRequest request=evidence.pending_request;
   if(!SWV5S5_IsV5Version(evidence.contract_version) || !SWV5S5_IsV5Version(request.contract_version) ||
      !SWV5S5_EqualNamespace(evidence.persistence_namespace,scope) ||
      !SWV5S5_EqualFence(evidence.ownership_fence,fence) || evidence.account_mode!=account_mode ||
      !SWV5S5_EqualNamespace(request.intent.persistence_namespace,scope) ||
      !SWV5S5_EqualFence(request.intent.ownership_fence,fence) || request.account_mode!=account_mode ||
      request.intent.account_mode!=account_mode || evidence.record_sequence==0 || evidence.recorded_at<=0 ||
      !SWV5S5_CanonicalPendingRequest(request,canonical) ||
      !SWV5_IsFiniteNumber(request.intent.normalized_volume) ||
      !SWV5_IsFiniteNumber(request.cumulative_confirmed_volume) ||
      !SWV5_IsFiniteNumber(request.residual_requested_volume) || request.intent.normalized_volume<0.0 ||
      request.cumulative_confirmed_volume<0.0 || request.residual_requested_volume<0.0 ||
      MathAbs(MathMax(0.0,request.intent.normalized_volume-request.cumulative_confirmed_volume)-
              request.residual_requested_volume)>0.0000001) return false;
   return request.intent.request_identity.request_id.correlation_id!="" &&
      request.intent.request_identity.request_id.attempt_id!="" &&
      request.intent.request_identity.idempotency_key!="";
}

bool SWV5S5_ReferencePersistedReleaseEvidenceValid(const SWV5_HardKillState &state,
                                                    const SWV5_ContractValidationContext &context)
{
   const SWV5_HardKillReleaseEvidence evidence=state.release_evidence;
   string expected_digest;
   return SWV5S5_IsV5Version(state.contract_version) &&
      SWV5S5_IsV5Version(state.persistence_namespace.contract_version) &&
      SWV5S5_IsV5Version(state.account_namespace.contract_version) &&
      SWV5S5_IsV5Version(evidence.contract_version) &&
      SWV5S5_IsV5Version(evidence.broker_evidence.contract_version) &&
      SWV5S5_IsV5Version(evidence.persistence_evidence.contract_version) &&
      SWV5S5_IsV5Version(evidence.exposure_evidence.contract_version) &&
      SWV5S5_EqualNamespace(evidence.persistence_namespace,state.persistence_namespace) &&
      evidence.release_id!="" && evidence.latch_id==state.latch_id &&
      evidence.latch_generation==state.latch_generation && evidence.latch_generation>0 &&
      evidence.release_generation==state.release_generation && evidence.release_generation>0 &&
      evidence.approval_policy_id=="HARD-KILL-RELEASE-V5" && evidence.approval_sequence>0 &&
      evidence.operator_identity.operator_id!="" && evidence.operator_identity.authority_role!="" &&
      evidence.operator_identity.authentication_reference!="" && evidence.operator_identity.authenticated_at>0 &&
      evidence.approving_component==SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE &&
      evidence.broker_evidence.evidence_id!="" && evidence.broker_evidence.state_digest!="" &&
      evidence.broker_evidence.evidence_sequence>0 && evidence.broker_evidence.observed_at>0 &&
      SWV5S5_EqualNamespace(evidence.broker_evidence.persistence_namespace,state.persistence_namespace) &&
      evidence.broker_evidence.issuing_component==SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER &&
      evidence.broker_evidence.authority_source==SWV5_AUTHORITY_LIVE_BROKER_STATE &&
      evidence.persistence_evidence.evidence_id!="" && evidence.persistence_evidence.state_digest!="" &&
      evidence.persistence_evidence.evidence_sequence>0 && evidence.persistence_evidence.observed_at>0 &&
      SWV5S5_EqualNamespace(evidence.persistence_evidence.persistence_namespace,state.persistence_namespace) &&
      evidence.persistence_evidence.issuing_component==SWV5_COMPONENT_AUTHORITY_PERSISTENCE &&
      evidence.persistence_evidence.authority_source==SWV5_AUTHORITY_PERSISTED_CHECKPOINT &&
      evidence.exposure_evidence.evidence_id!="" && evidence.exposure_evidence.evidence_sequence>0 &&
      evidence.exposure_evidence.observed_at>0 && evidence.exposure_evidence.zero_or_reducing &&
      SWV5_IsFiniteNumber(evidence.exposure_evidence.observed_exposure_volume) &&
      SWV5_IsFiniteNumber(evidence.exposure_evidence.prior_exposure_volume) &&
      evidence.exposure_evidence.observed_exposure_volume>=0.0 &&
      evidence.exposure_evidence.prior_exposure_volume>=0.0 &&
      evidence.exposure_evidence.observed_exposure_volume<=evidence.exposure_evidence.prior_exposure_volume+context.volume_tolerance &&
      evidence.exposure_evidence.issuing_component==SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE &&
      evidence.exposure_evidence.authority_source==SWV5_AUTHORITY_LIVE_BROKER_STATE &&
      evidence.approved_at>0 && evidence.released_at>=evidence.approved_at &&
      evidence.released_at<=context.clock_time && context.clock_time<evidence.expires_at &&
      evidence.operator_identity.authenticated_at<=evidence.approved_at &&
      evidence.broker_evidence.observed_at>=evidence.operator_identity.authenticated_at &&
      evidence.persistence_evidence.observed_at>=evidence.operator_identity.authenticated_at &&
      evidence.exposure_evidence.observed_at>=evidence.operator_identity.authenticated_at &&
      evidence.broker_evidence.observed_at<=evidence.approved_at &&
      evidence.persistence_evidence.observed_at<=evidence.approved_at &&
      evidence.exposure_evidence.observed_at<=evidence.approved_at &&
      evidence.release_record_sequence>0 && evidence.audit_reference!="" &&
      SWV5S5_ReferenceReleaseEvidenceDigest(evidence,expected_digest) &&
      evidence.release_record_digest==expected_digest && SWV5S5_IsDigest64Lower(evidence.release_record_digest);
}

bool SWV5S5_ReferenceZeroHistoryCandidate(const SWV5_RestartReconciliationInput &restart_input,
                                           const SWV5_PersistedRequestEvidence &pending_requests[],
                                           const SWV5S5_ReferenceGenesisRecord &genesis,
                                           const SWV5_InstanceLease &lease)
{
   const SWV5_PersistedReconciliationVector reconciliation=restart_input.persisted.reconciliation_vector;
   return genesis.state==SWV5S5_GENESIS_READY_FOR_RECONCILIATION &&
      SWV5_TestActiveOwnedStatus(lease.status) && SWV5S5_EqualFence(lease.fence,restart_input.claimant_fence) &&
      ArraySize(pending_requests)==0 && restart_input.persisted.pending_request_set.request_count==0 &&
      restart_input.restart_requests.pending_request_count==0 && reconciliation.pending_request_count==0 &&
      restart_input.broker.position_count==0 && restart_input.broker.order_count==0 &&
      restart_input.broker.symbol_long_volume==0.0 && restart_input.broker.symbol_short_volume==0.0 &&
      restart_input.broker.symbol_net_volume==0.0 && restart_input.broker.aggregate_position_volume==0.0 &&
      restart_input.broker.basket_open_volume==0.0 && restart_input.broker.residual_volume==0.0 &&
      reconciliation.position_count==0 && reconciliation.order_count==0 && reconciliation.symbol_long_volume==0.0 &&
      reconciliation.symbol_short_volume==0.0 && reconciliation.symbol_net_volume==0.0 && reconciliation.aggregate_position_volume==0.0 &&
      reconciliation.basket_open_volume==0.0 && reconciliation.residual_volume==0.0 &&
      restart_input.persisted.basket.lifecycle.live_position_count==0 && restart_input.persisted.basket.lifecycle.live_order_count==0 &&
      restart_input.persisted.basket.lifecycle.pending_request_count==0 && restart_input.persisted.basket.lifecycle.aggregate_open_volume==0.0 &&
      restart_input.persisted.basket.lifecycle.residual_volume==0.0 &&
      restart_input.persisted.basket.lifecycle.state==SWV5_BASKET_IDLE &&
      restart_input.persisted.basket.close_verification==SWV5_CLOSE_ZERO_RESIDUAL_CONFIRMED &&
      restart_input.persisted.basket.aggregate_closed_volume==restart_input.persisted.basket.initial_volume &&
      restart_input.broker.transaction_high_watermark==0 && reconciliation.transaction_high_watermark==0 &&
      SWV5S5_ReferenceZeroCorrelation(restart_input.broker.latest_confirmed_correlation) &&
      SWV5S5_ReferenceZeroCorrelation(reconciliation.latest_confirmed_correlation) &&
      SWV5S5_ReferenceZeroCorrelation(restart_input.persisted.last_confirmed_correlation) &&
      SWV5S5_ReferenceZeroBrokerIdentity(restart_input.broker.latest_broker_event_identity) &&
      SWV5S5_ReferenceZeroBrokerIdentity(reconciliation.latest_broker_event_identity);
}

bool SWV5S5_ReferenceCheckpointSemanticValid(const SWV5_ContractValidationContext &context,
                                              const SWV5_RestartReconciliationInput &restart_input,
                                              const SWV5_PersistedRequestEvidence &pending_requests[],
                                              const SWV5S5_ReferenceGenesisRecord &genesis,
                                              const SWV5_InstanceLease &lease,
                                              const string request_set_digest,
                                              bool &zero_history)
{
   const SWV5_PersistedCheckpoint checkpoint=restart_input.persisted;
   const SWV5_PersistedReconciliationVector reconciliation=checkpoint.reconciliation_vector;
   string source_digest;
   zero_history=SWV5S5_ReferenceZeroHistoryCandidate(restart_input,pending_requests,genesis,lease);
    if(!SWV5S5_ReferenceCheckpointProductionIntegrityValid(checkpoint,context) ||
       !SWV5_TestCheckpointBasketSemanticValid(context,checkpoint.basket,
          restart_input.persistence_namespace,restart_input.claimant_fence) ||
       !SWV5_TestReconciliationVectorValid(context,checkpoint) ||
       !SWV5_TestCheckpointHardKillSemanticValid(context,checkpoint.hard_kill_state,
          restart_input.persistence_namespace) ||
      !SWV5S5_IsV5Version(checkpoint.basket.contract_version) ||
      !SWV5S5_IsV5Version(checkpoint.basket.lifecycle.contract_version) ||
      !SWV5S5_IsV5Version(checkpoint.pending_request_set.contract_version) ||
      !SWV5S5_IsV5Version(checkpoint.hard_kill_state.contract_version) ||
      !SWV5S5_IsV5Version(reconciliation.contract_version) ||
      !SWV5S5_EqualNamespace(checkpoint.header.persistence_namespace,restart_input.persistence_namespace) ||
      !SWV5S5_EqualNamespace(checkpoint.basket.persistence_namespace,restart_input.persistence_namespace) ||
      !SWV5S5_EqualNamespace(checkpoint.hard_kill_state.persistence_namespace,restart_input.persistence_namespace) ||
      !SWV5S5_EqualNamespace(reconciliation.persistence_namespace,restart_input.persistence_namespace) ||
      checkpoint.basket.lifecycle.basket_id.value!=restart_input.persistence_namespace.basket_id.value ||
      reconciliation.basket_id.value!=restart_input.persistence_namespace.basket_id.value ||
      !SWV5S5_EqualFence(checkpoint.header.ownership_fence,restart_input.claimant_fence) ||
      !SWV5S5_EqualFence(checkpoint.basket.lifecycle.ownership_fence,restart_input.claimant_fence) ||
      !SWV5S5_EqualFence(reconciliation.ownership_fence,restart_input.claimant_fence) ||
      !SWV5S5_EqualFence(lease.fence,restart_input.claimant_fence) ||
      checkpoint.basket.account_mode!=restart_input.broker.account_mode || reconciliation.account_mode!=restart_input.broker.account_mode ||
      checkpoint.basket.lifecycle.reconciliation_state!=SWV5_RECONCILIATION_STATE_MATCHED ||
      reconciliation.basket_state!=checkpoint.basket.lifecycle.state ||
      reconciliation.basket_state_version!=checkpoint.basket.lifecycle.state_version ||
      reconciliation.hard_kill_generation!=checkpoint.hard_kill_state.latch_generation ||
      reconciliation.pending_request_count!=checkpoint.pending_request_set.request_count ||
      reconciliation.pending_request_count!=(uint)ArraySize(pending_requests) ||
      checkpoint.pending_request_set.request_set_digest!=request_set_digest ||
      reconciliation.request_set_digest!=request_set_digest ||
      reconciliation.request_set_revision!=checkpoint.pending_request_set.request_index_revision ||
      reconciliation.reconciliation_revision==0 || reconciliation.broker_query_sequence_high_watermark==0 ||
      reconciliation.request_query_sequence_high_watermark==0 ||
      !SWV5S5_ReferenceReconciliationSourceDigest(reconciliation,source_digest) || reconciliation.source_summary_digest!=source_digest ||
      !SWV5S5_ReferenceRestartNear(reconciliation.symbol_long_volume,restart_input.broker.symbol_long_volume,context.volume_tolerance) ||
      !SWV5S5_ReferenceRestartNear(reconciliation.symbol_short_volume,restart_input.broker.symbol_short_volume,context.volume_tolerance) ||
      !SWV5S5_ReferenceRestartNear(reconciliation.symbol_net_volume,restart_input.broker.symbol_net_volume,context.volume_tolerance) ||
      !SWV5S5_ReferenceRestartNear(reconciliation.aggregate_position_volume,restart_input.broker.aggregate_position_volume,context.volume_tolerance) ||
      !SWV5S5_ReferenceRestartNear(reconciliation.basket_open_volume,restart_input.broker.basket_open_volume,context.volume_tolerance) ||
      !SWV5S5_ReferenceRestartNear(reconciliation.residual_volume,restart_input.broker.residual_volume,context.volume_tolerance) ||
      !SWV5S5_ReferenceRestartNear(reconciliation.aggregate_position_volume,checkpoint.basket.lifecycle.aggregate_open_volume,context.volume_tolerance) ||
      !SWV5S5_ReferenceRestartNear(reconciliation.residual_volume,checkpoint.basket.lifecycle.residual_volume,context.volume_tolerance) ||
      reconciliation.position_count!=restart_input.broker.position_count || reconciliation.order_count!=restart_input.broker.order_count ||
      reconciliation.position_count!=checkpoint.basket.lifecycle.live_position_count || reconciliation.order_count!=checkpoint.basket.lifecycle.live_order_count)
      return false;
   if(zero_history)
      return SWV5S5_ReferenceBrokerSummaryValid(restart_input.broker,true);
   return SWV5S5_ReferenceBrokerSummaryValid(restart_input.broker) && reconciliation.transaction_high_watermark>0 &&
      SWV5S5_ReferenceRestartCorrelationEqual(reconciliation.latest_confirmed_correlation,restart_input.broker.latest_confirmed_correlation) &&
      SWV5S5_ReferenceRestartCorrelationEqual(checkpoint.last_confirmed_correlation,restart_input.broker.latest_confirmed_correlation) &&
      SWV5S5_ReferenceRestartBrokerIdentityEqual(reconciliation.latest_broker_event_identity,restart_input.broker.latest_broker_event_identity) &&
      reconciliation.transaction_high_watermark==restart_input.broker.transaction_high_watermark;
}

bool SWV5S5_ReferenceReleaseAuthorityValid(const SWV5_HardKillReleaseAuthorityRecord &record,
                                           const SWV5_PersistedCheckpoint &checkpoint,
                                           const SWV5_ContractValidationContext &context)
{
   const SWV5_HardKillState state=checkpoint.hard_kill_state;
   const SWV5_HardKillReleaseEvidence evidence=state.release_evidence;
   const SWV5_HardKillReleaseAuthorityReference reference=state.release_authority_reference;
   string expected_digest,operator_record,operator_evidence;
   if(!SWV5S5_ReferencePersistedReleaseEvidenceValid(state,context) ||
      !SWV5S5_IsV5Version(record.contract_version) || !SWV5S5_IsV5Version(reference.contract_version) ||
      !SWV5S5_ReferenceReleaseAuthorityDigest(record,expected_digest) ||
      record.authority_record_digest!=expected_digest || !SWV5S5_IsDigest64Lower(record.authority_record_digest) ||
      !SWV5S5_EqualNamespace(record.persistence_namespace,checkpoint.header.persistence_namespace) ||
      !SWV5S5_EqualNamespace(record.persistence_namespace,state.persistence_namespace) ||
      !SWV5S5_ReferenceAccountNamespaceEqual(record.account_namespace,state.account_namespace) ||
      record.latch_id=="" || record.latch_id!=state.latch_id ||
      record.latch_generation==0 || record.latch_generation!=state.latch_generation ||
      record.release_id=="" || record.release_id!=evidence.release_id ||
      record.release_generation==0 || record.release_generation!=state.release_generation ||
      record.release_generation!=evidence.release_generation || record.approval_policy_id!="HARD-KILL-RELEASE-V5" ||
      record.approval_policy_id!=evidence.approval_policy_id || record.approval_sequence==0 ||
      record.approval_sequence!=evidence.approval_sequence || record.release_record_sequence==0 ||
      record.release_record_sequence!=evidence.release_record_sequence ||
      record.issuing_component!=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE ||
      record.authority_source!=SWV5_AUTHORITY_HARD_KILL_RELEASE_RECORD ||
      record.approving_component!=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE ||
      record.operator_identity.operator_id=="" || record.operator_identity.authority_role=="" ||
      record.operator_identity.authentication_reference=="" || record.operator_identity.authenticated_at<=0 ||
      !SWV5S5_CanonicalOperatorIdentity("operator",record.operator_identity,operator_record) ||
      !SWV5S5_CanonicalOperatorIdentity("operator",evidence.operator_identity,operator_evidence) ||
      operator_record!=operator_evidence || record.approving_component!=evidence.approving_component ||
      !SWV5S5_ReferenceTypedEvidenceEqual(record.broker_evidence_reference,evidence.broker_evidence) ||
      !SWV5S5_ReferenceTypedEvidenceEqual(record.persistence_evidence_reference,evidence.persistence_evidence) ||
      !SWV5S5_ReferenceExposureEvidenceEqual(record.exposure_evidence_reference,evidence.exposure_evidence) ||
      record.broker_evidence_reference.evidence_id=="" || record.broker_evidence_reference.state_digest=="" ||
      record.broker_evidence_reference.evidence_sequence==0 || record.broker_evidence_reference.observed_at<=0 ||
      !SWV5S5_EqualNamespace(record.broker_evidence_reference.persistence_namespace,record.persistence_namespace) ||
      record.broker_evidence_reference.issuing_component!=SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER ||
      record.broker_evidence_reference.authority_source!=SWV5_AUTHORITY_LIVE_BROKER_STATE ||
      record.persistence_evidence_reference.evidence_id=="" || record.persistence_evidence_reference.state_digest=="" ||
      record.persistence_evidence_reference.evidence_sequence==0 || record.persistence_evidence_reference.observed_at<=0 ||
      !SWV5S5_EqualNamespace(record.persistence_evidence_reference.persistence_namespace,record.persistence_namespace) ||
      record.persistence_evidence_reference.issuing_component!=SWV5_COMPONENT_AUTHORITY_PERSISTENCE ||
      record.persistence_evidence_reference.authority_source!=SWV5_AUTHORITY_PERSISTED_CHECKPOINT ||
      record.exposure_evidence_reference.evidence_id=="" ||
      record.exposure_evidence_reference.evidence_sequence==0 || record.exposure_evidence_reference.observed_at<=0 ||
      !SWV5_IsFiniteNumber(record.exposure_evidence_reference.observed_exposure_volume) ||
      !SWV5_IsFiniteNumber(record.exposure_evidence_reference.prior_exposure_volume) ||
      record.exposure_evidence_reference.issuing_component!=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE ||
      record.exposure_evidence_reference.authority_source!=SWV5_AUTHORITY_LIVE_BROKER_STATE ||
      !record.exposure_evidence_reference.zero_or_reducing ||
      record.exposure_evidence_reference.observed_exposure_volume<0.0 ||
      record.exposure_evidence_reference.prior_exposure_volume<0.0 ||
      record.exposure_evidence_reference.observed_exposure_volume>
         record.exposure_evidence_reference.prior_exposure_volume+context.volume_tolerance ||
      record.approved_at<=0 || record.released_at<record.approved_at || record.released_at>context.clock_time ||
      record.expires_at<=context.clock_time ||
      record.operator_identity.authenticated_at>record.approved_at ||
      record.broker_evidence_reference.observed_at<record.operator_identity.authenticated_at ||
      record.persistence_evidence_reference.observed_at<record.operator_identity.authenticated_at ||
      record.exposure_evidence_reference.observed_at<record.operator_identity.authenticated_at ||
      record.broker_evidence_reference.observed_at>record.approved_at ||
      record.persistence_evidence_reference.observed_at>record.approved_at ||
      record.exposure_evidence_reference.observed_at>record.approved_at ||
      record.approved_at!=evidence.approved_at || record.released_at!=evidence.released_at ||
      record.expires_at!=evidence.expires_at || record.authority_record_id=="" ||
      reference.authority_record_id!=record.authority_record_id ||
      reference.authority_record_sequence!=record.release_record_sequence ||
      reference.authority_record_digest!=record.authority_record_digest || reference.release_id!=record.release_id ||
      reference.latch_generation!=record.latch_generation || reference.release_generation!=record.release_generation ||
      !SWV5_TestRiskAccountNamespaceComplete(context,record.account_namespace) ||
      !SWV5_TestRiskAccountNamespaceBelongsToPersistence(record.account_namespace,record.persistence_namespace) ||
      !SWV5_TestHistoricalHardKillReleaseValid(context,state,evidence,record)) return false;
   return true;
}

bool SWV5S5_EvaluateReferenceRestart(const SWV5_ContractValidationContext &context,
                                     const SWV5_RestartReconciliationInput &restart_input,
                                     const SWV5_PersistedRequestEvidence &pending_requests[],
                                     const SWV5S5_ReferenceGenesisRecord &genesis,
                                     const SWV5_InstanceLease &lease,
                                     SWV5S5_ReferenceRestartResult &result)
{
   ZeroMemory(result); result.disposition=SWV5_RESTART_HALTED;
   string checkpoint_projection,set_digest,broker_digest,execution_digest;
   SWV5_PendingRequest requests[]; ArrayResize(requests,ArraySize(pending_requests));
   for(int i=0;i<ArraySize(pending_requests);i++) requests[i]=pending_requests[i].pending_request;
   const bool schema=SWV5S5_IsV5Version(restart_input.persisted.header.contract_version) && SWV5S5_IsCandidateVersion(restart_input.contract_version);
   const bool namespace_ok=SWV5S5_ReferencePersistenceNamespaceComplete(restart_input.persistence_namespace) &&
      SWV5S5_EqualNamespace(restart_input.persistence_namespace,restart_input.persisted.header.persistence_namespace) &&
      SWV5S5_EqualNamespace(restart_input.persistence_namespace,restart_input.restart_requests.persistence_namespace) &&
      SWV5S5_EqualNamespace(restart_input.persistence_namespace,restart_input.broker.persistence_namespace) &&
      SWV5S5_ReferenceOwnershipKeyEqual(restart_input.persistence_namespace.ownership_namespace,restart_input.claimant_fence.ownership_namespace);
   const bool fence_ok=SWV5S5_EqualFence(restart_input.claimant_fence,restart_input.persisted.header.ownership_fence) &&
      SWV5S5_EqualFence(restart_input.claimant_fence,lease.fence);
   result.query_union_complete=SWV5S5_ReferenceQueryValid(restart_input.broker.queries,
      SWV5_RESTART_BROKER_QUERY_FLAGS_V5,SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER,
      SWV5_AUTHORITY_LIVE_BROKER_STATE,restart_input.broker.observation_sequence,
      restart_input.broker.observed_at) &&
      SWV5S5_ReferenceQueryValid(restart_input.restart_requests.pending_request_query,
      SWV5_RESTART_EXECUTION_QUERY_FLAGS_V5,SWV5_COMPONENT_AUTHORITY_EXECUTION,
      SWV5_AUTHORITY_EXECUTION_REQUEST_STATE,restart_input.restart_requests.observation_sequence,
      restart_input.restart_requests.observed_at);
   result.authoritative_sources_separated=restart_input.broker.authority==SWV5_AUTHORITY_LIVE_BROKER_STATE &&
      restart_input.restart_requests.authority_source==SWV5_AUTHORITY_EXECUTION_REQUEST_STATE;
   if(!schema || !namespace_ok || !fence_ok || genesis.state!=SWV5S5_GENESIS_READY_FOR_RECONCILIATION ||
      restart_input.persistence_status!=SWV5_PERSISTENCE_LOADED ||
      !SWV5S5_ReferenceLiveLeaseValid(context,lease,restart_input.claimant_fence))
   { result.diagnostic="SCHEMA_GENESIS_PERSISTENCE_OR_OWNER_INVALID"; return false; }
   bool zero_history=false;
   if(!SWV5S5_DeriveCheckpointProjection(restart_input.persisted,checkpoint_projection) ||
      !SWV5S5_DeriveCompleteRequestSetDigest(requests,set_digest) ||
       restart_input.persisted.pending_request_set.request_set_digest!=set_digest ||
       restart_input.persisted.pending_request_set.request_count!=(uint)ArraySize(requests) ||
       !SWV5S5_ReferenceCheckpointSemanticValid(context,restart_input,pending_requests,genesis,lease,set_digest,zero_history) ||
       !SWV5S5_ReferenceExecutionSummaryValid(restart_input.restart_requests) ||
       !SWV5S5_ReferenceBrokerSummaryDigest(restart_input.broker,broker_digest) || restart_input.broker.complete_summary_digest!=broker_digest ||
       !SWV5S5_ReferenceExecutionSummaryDigest(restart_input.restart_requests,execution_digest) || restart_input.restart_requests.complete_summary_digest!=execution_digest)
   { result.diagnostic="COMPLETE_TYPED_STATE_DIGEST_INVALID"; return false; }
   if(!result.query_union_complete || !result.authoritative_sources_separated)
   { result.disposition=SWV5_RESTART_RECONCILIATION_REQUIRED; result.diagnostic="QUERY_UNION_OR_SOURCE_SEPARATION_INVALID"; return false; }
   if(restart_input.broker.queries.observation_sequence<=restart_input.persisted.reconciliation_vector.broker_query_sequence_high_watermark ||
       restart_input.restart_requests.pending_request_query.observation_sequence<=restart_input.persisted.reconciliation_vector.request_query_sequence_high_watermark ||
       restart_input.broker.observation_sequence>context.evaluation_sequence ||
       restart_input.restart_requests.observation_sequence>context.evaluation_sequence ||
       restart_input.persisted.header.written_at>restart_input.broker.observed_at ||
       restart_input.persisted.header.written_at>restart_input.restart_requests.observed_at ||
       restart_input.broker.observed_at<=0 || restart_input.restart_requests.observed_at<=0 || context.clock_time<restart_input.broker.observed_at ||
       context.clock_time<restart_input.restart_requests.observed_at || context.clock_time-restart_input.broker.observed_at>SWV5_MAX_RESTART_EVIDENCE_AGE_SECONDS_V5 ||
       context.clock_time-restart_input.restart_requests.observed_at>SWV5_MAX_RESTART_EVIDENCE_AGE_SECONDS_V5)
   { result.disposition=SWV5_RESTART_RECONCILIATION_REQUIRED; result.diagnostic="QUERY_FRESHNESS_OR_ANTI_REPLAY_FAILED"; return false; }
   const SWV5_PersistedReconciliationVector persisted_vector=restart_input.persisted.reconciliation_vector;
   if(!SWV5S5_EqualNamespace(persisted_vector.persistence_namespace,restart_input.persistence_namespace) ||
      persisted_vector.basket_id.value!=restart_input.persistence_namespace.basket_id.value ||
      persisted_vector.account_mode!=restart_input.broker.account_mode ||
      !SWV5S5_EqualFence(persisted_vector.ownership_fence,restart_input.claimant_fence) ||
      !SWV5S5_ReferenceRestartNear(restart_input.broker.symbol_net_volume,
         restart_input.broker.symbol_long_volume-restart_input.broker.symbol_short_volume,context.volume_tolerance) ||
      !SWV5S5_ReferenceRestartNear(restart_input.broker.symbol_long_volume,persisted_vector.symbol_long_volume,context.volume_tolerance) ||
      !SWV5S5_ReferenceRestartNear(restart_input.broker.symbol_short_volume,persisted_vector.symbol_short_volume,context.volume_tolerance) ||
      !SWV5S5_ReferenceRestartNear(restart_input.broker.symbol_net_volume,persisted_vector.symbol_net_volume,context.volume_tolerance) ||
      !SWV5S5_ReferenceRestartNear(restart_input.broker.aggregate_position_volume,persisted_vector.aggregate_position_volume,context.volume_tolerance) ||
      !SWV5S5_ReferenceRestartNear(restart_input.broker.basket_open_volume,persisted_vector.basket_open_volume,context.volume_tolerance) ||
      !SWV5S5_ReferenceRestartNear(restart_input.broker.residual_volume,persisted_vector.residual_volume,context.volume_tolerance) ||
      restart_input.broker.position_count!=persisted_vector.position_count || restart_input.broker.order_count!=persisted_vector.order_count ||
      !SWV5S5_ReferenceRestartCorrelationEqual(restart_input.broker.latest_confirmed_correlation,persisted_vector.latest_confirmed_correlation) ||
      !SWV5S5_ReferenceRestartBrokerIdentityEqual(restart_input.broker.latest_broker_event_identity,persisted_vector.latest_broker_event_identity) ||
      (!zero_history && !SWV5S5_ReferenceRestartBrokerIdentityEqual(
         restart_input.broker.latest_broker_event_identity,
         restart_input.broker.latest_confirmed_correlation.broker_identity)) ||
      (!zero_history && restart_input.broker.transaction_high_watermark!=
         restart_input.broker.latest_broker_event_identity.transaction_sequence) ||
      restart_input.broker.transaction_high_watermark!=persisted_vector.transaction_high_watermark ||
      restart_input.restart_requests.pending_request_count!=persisted_vector.pending_request_count ||
      restart_input.restart_requests.pending_request_count!=(uint)ArraySize(pending_requests) ||
      restart_input.restart_requests.request_set_digest!=set_digest ||
      restart_input.restart_requests.request_set_digest!=persisted_vector.request_set_digest ||
      restart_input.restart_requests.request_set_revision!=persisted_vector.request_set_revision ||
      restart_input.restart_requests.request_set_revision!=restart_input.persisted.pending_request_set.request_index_revision ||
      restart_input.restart_requests.reconciliation_revision!=persisted_vector.reconciliation_revision ||
      persisted_vector.request_set_digest!=restart_input.persisted.pending_request_set.request_set_digest)
   { result.disposition=SWV5_RESTART_RECONCILIATION_REQUIRED; result.diagnostic="BROKER_EXECUTION_CHECKPOINT_RELATION_INVALID"; return false; }
   if(ArraySize(pending_requests)==0 && restart_input.persisted.has_latest_pending_request)
   { result.diagnostic="LATEST_REQUEST_WITH_EMPTY_SET"; return false; }
   if(ArraySize(pending_requests)>0 && (!restart_input.persisted.has_latest_pending_request ||
      !SWV5S5_ReferencePersistedRequestEqual(restart_input.persisted.latest_pending_request,
                                             pending_requests[ArraySize(pending_requests)-1])))
   { result.diagnostic="LATEST_REQUEST_RELATION_INVALID"; return false; }
   bool reconciliation_required=false,retry_forbidden=false;
   ulong previous_record_sequence=0;
   for(int p=0;p<ArraySize(pending_requests);p++)
   {
      if(!SWV5S5_ReferencePersistedRequestValid(pending_requests[p],restart_input.persistence_namespace,
         restart_input.claimant_fence,restart_input.broker.account_mode) ||
         pending_requests[p].record_sequence<=previous_record_sequence ||
         pending_requests[p].record_sequence>restart_input.persisted.pending_request_set.record_sequence)
      { result.diagnostic="PERSISTED_REQUEST_INVALID"; return false; }
      previous_record_sequence=pending_requests[p].record_sequence;
      const SWV5_PendingRequest pending=pending_requests[p].pending_request;
      if(pending.lifecycle_phase==SWV5_EXECUTION_PHASE_UNCERTAIN ||
         pending.state==SWV5_REQUEST_RECONCILIATION_REQUIRED ||
         pending.state==SWV5_REQUEST_CONFIRMATION_PENDING || pending.state==SWV5_REQUEST_PARTIALLY_CONFIRMED)
         reconciliation_required=true;
      else if(pending.retry_disposition==SWV5_RETRY_FORBIDDEN && pending.state!=SWV5_REQUEST_CONFIRMED &&
              pending.state!=SWV5_REQUEST_CANCELLED && pending.state!=SWV5_REQUEST_REJECTED)
         retry_forbidden=true;
      else if(pending.state!=SWV5_REQUEST_CONFIRMED && pending.state!=SWV5_REQUEST_CANCELLED &&
              pending.state!=SWV5_REQUEST_REJECTED)
         reconciliation_required=true;
   }
   if(restart_input.persisted.hard_kill_state.state==SWV5_HARD_KILL_ACTIVE || restart_input.persisted.hard_kill_state.state==SWV5_HARD_KILL_RELEASE_PENDING)
   { result.disposition=SWV5_RESTART_CLOSE_ONLY; result.diagnostic="HARD_KILL_ACTIVE"; return false; }
   if(restart_input.persisted.hard_kill_state.state==SWV5_HARD_KILL_RELEASED &&
      (!restart_input.has_release_authority_record || !SWV5S5_ReferenceReleaseAuthorityValid(restart_input.release_authority_record,restart_input.persisted,context)))
   { result.disposition=SWV5_RESTART_HALTED; result.diagnostic="INDEPENDENT_RELEASE_AUTHORITY_INVALID"; return false; }
   if(!restart_input.persisted.clean_shutdown || restart_input.persisted.reconciliation_vector.request_set_digest!=set_digest)
   { result.disposition=SWV5_RESTART_RECONCILIATION_REQUIRED; result.diagnostic="DIRTY_OR_SPLIT_PUBLICATION"; return false; }
   if(reconciliation_required)
   { result.disposition=SWV5_RESTART_RECONCILIATION_REQUIRED; result.diagnostic="UNRESOLVED_REQUEST_REQUIRES_RECONCILIATION"; return false; }
   if(retry_forbidden)
   { result.disposition=SWV5_RESTART_RETRY_FORBIDDEN; result.diagnostic="UNRESOLVED_REQUEST_RETRY_FORBIDDEN"; return false; }
   result.disposition=SWV5_RESTART_SAFE_TO_RESUME; result.increasing_execution_eligible=true; result.diagnostic="SAFE_TO_RESUME"; return true;
}

#endif
