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

bool SWV5S5_ReferenceReleaseAuthorityValid(const SWV5_HardKillReleaseAuthorityRecord &record,
                                           const SWV5_PersistedCheckpoint &checkpoint,
                                           const SWV5_ContractValidationContext &context)
{
   const SWV5_HardKillState state=checkpoint.hard_kill_state;
   const SWV5_HardKillReleaseEvidence evidence=state.release_evidence;
   const SWV5_HardKillReleaseAuthorityReference reference=state.release_authority_reference;
   string expected_digest,operator_record,operator_evidence;
   if(!SWV5S5_IsV5Version(record.contract_version) ||
      !SWV5S5_ReferenceReleaseAuthorityDigest(record,expected_digest) ||
      record.authority_record_digest!=expected_digest || !SWV5S5_IsDigest64Lower(record.authority_record_digest) ||
      !SWV5S5_EqualNamespace(record.persistence_namespace,checkpoint.header.persistence_namespace) ||
      !SWV5S5_EqualNamespace(record.persistence_namespace,state.persistence_namespace) ||
      !SWV5S5_ReferenceAccountNamespaceEqual(record.account_namespace,state.account_namespace) ||
      record.latch_id=="" || record.latch_id!=state.latch_id ||
      record.latch_generation==0 || record.latch_generation!=state.latch_generation ||
      record.release_id=="" || record.release_id!=evidence.release_id ||
      record.release_generation==0 || record.release_generation!=state.release_generation ||
      record.release_generation!=evidence.release_generation || record.approval_policy_id=="" ||
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
      record.approved_at<=0 || record.released_at<record.approved_at || record.expires_at<=context.clock_time ||
      record.operator_identity.authenticated_at>record.approved_at ||
      record.broker_evidence_reference.observed_at>record.approved_at ||
      record.persistence_evidence_reference.observed_at>record.approved_at ||
      record.exposure_evidence_reference.observed_at>record.approved_at ||
      record.approved_at!=evidence.approved_at || record.released_at!=evidence.released_at ||
      record.expires_at!=evidence.expires_at || record.authority_record_id=="" ||
      reference.authority_record_id!=record.authority_record_id ||
      reference.authority_record_sequence!=record.release_record_sequence ||
      reference.authority_record_digest!=record.authority_record_digest || reference.release_id!=record.release_id ||
      reference.latch_generation!=record.latch_generation || reference.release_generation!=record.release_generation) return false;
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
   const bool namespace_ok=SWV5S5_EqualNamespace(restart_input.persistence_namespace,restart_input.persisted.header.persistence_namespace) &&
      SWV5S5_EqualNamespace(restart_input.persistence_namespace,restart_input.restart_requests.persistence_namespace) &&
      SWV5S5_EqualNamespace(restart_input.persistence_namespace,restart_input.broker.persistence_namespace) &&
      SWV5S5_ReferenceOwnershipKeyEqual(restart_input.persistence_namespace.ownership_namespace,restart_input.claimant_fence.ownership_namespace);
   const bool fence_ok=SWV5S5_EqualFence(restart_input.claimant_fence,restart_input.persisted.header.ownership_fence) &&
      SWV5S5_EqualFence(restart_input.claimant_fence,lease.fence);
   result.query_union_complete=restart_input.broker.queries.required_flags==SWV5_RESTART_BROKER_QUERY_FLAGS_V5 &&
      restart_input.broker.queries.completed_flags==SWV5_RESTART_BROKER_QUERY_FLAGS_V5 &&
      restart_input.restart_requests.pending_request_query.required_flags==SWV5_RESTART_EXECUTION_QUERY_FLAGS_V5 &&
      restart_input.restart_requests.pending_request_query.completed_flags==SWV5_RESTART_EXECUTION_QUERY_FLAGS_V5;
   result.authoritative_sources_separated=restart_input.broker.authority==SWV5_AUTHORITY_LIVE_BROKER_STATE &&
      restart_input.restart_requests.authority_source==SWV5_AUTHORITY_EXECUTION_REQUEST_STATE;
   if(!schema || !namespace_ok || !fence_ok || genesis.state!=SWV5S5_GENESIS_READY_FOR_RECONCILIATION ||
      restart_input.persistence_status!=SWV5_PERSISTENCE_LOADED || lease.status==SWV5_LOCK_CONFLICT || lease.status==SWV5_LOCK_RECOVERY_REQUIRED)
   { result.diagnostic="SCHEMA_GENESIS_PERSISTENCE_OR_OWNER_INVALID"; return false; }
   if(!SWV5S5_DeriveCheckpointProjection(restart_input.persisted,checkpoint_projection) ||
      !SWV5S5_DeriveCompleteRequestSetDigest(requests,set_digest) ||
      restart_input.persisted.pending_request_set.request_set_digest!=set_digest ||
      restart_input.persisted.pending_request_set.request_count!=(uint)ArraySize(requests) ||
      restart_input.restart_requests.request_set_digest!=set_digest ||
      !SWV5S5_ReferenceBrokerSummaryDigest(restart_input.broker,broker_digest) || restart_input.broker.complete_summary_digest!=broker_digest ||
      !SWV5S5_ReferenceExecutionSummaryDigest(restart_input.restart_requests,execution_digest) || restart_input.restart_requests.complete_summary_digest!=execution_digest)
   { result.diagnostic="COMPLETE_TYPED_STATE_DIGEST_INVALID"; return false; }
   if(!result.query_union_complete || !result.authoritative_sources_separated)
   { result.disposition=SWV5_RESTART_RECONCILIATION_REQUIRED; result.diagnostic="QUERY_UNION_OR_SOURCE_SEPARATION_INVALID"; return false; }
   if(restart_input.broker.queries.observation_sequence<=restart_input.persisted.reconciliation_vector.broker_query_sequence_high_watermark ||
      restart_input.restart_requests.pending_request_query.observation_sequence<=restart_input.persisted.reconciliation_vector.request_query_sequence_high_watermark ||
      restart_input.broker.observed_at<=0 || restart_input.restart_requests.observed_at<=0 || context.clock_time<restart_input.broker.observed_at ||
      context.clock_time<restart_input.restart_requests.observed_at || context.clock_time-restart_input.broker.observed_at>SWV5_MAX_RESTART_EVIDENCE_AGE_SECONDS_V5 ||
      context.clock_time-restart_input.restart_requests.observed_at>SWV5_MAX_RESTART_EVIDENCE_AGE_SECONDS_V5)
   { result.disposition=SWV5_RESTART_RECONCILIATION_REQUIRED; result.diagnostic="QUERY_FRESHNESS_OR_ANTI_REPLAY_FAILED"; return false; }
   if(ArraySize(pending_requests)>0 && (pending_requests[0].pending_request.state==SWV5_REQUEST_CONFIRMATION_PENDING ||
      pending_requests[0].pending_request.state==SWV5_REQUEST_RECONCILIATION_REQUIRED))
   { result.disposition=SWV5_RESTART_RETRY_FORBIDDEN; result.diagnostic="CLAIMED_UNRESOLVED"; return false; }
   if(restart_input.persisted.hard_kill_state.state==SWV5_HARD_KILL_ACTIVE || restart_input.persisted.hard_kill_state.state==SWV5_HARD_KILL_RELEASE_PENDING)
   { result.disposition=SWV5_RESTART_CLOSE_ONLY; result.diagnostic="HARD_KILL_ACTIVE"; return false; }
   if(restart_input.persisted.hard_kill_state.state==SWV5_HARD_KILL_RELEASED &&
      (!restart_input.has_release_authority_record || !SWV5S5_ReferenceReleaseAuthorityValid(restart_input.release_authority_record,restart_input.persisted,context)))
   { result.disposition=SWV5_RESTART_HALTED; result.diagnostic="INDEPENDENT_RELEASE_AUTHORITY_INVALID"; return false; }
   if(!restart_input.persisted.clean_shutdown || restart_input.persisted.reconciliation_vector.request_set_digest!=set_digest)
   { result.disposition=SWV5_RESTART_RECONCILIATION_REQUIRED; result.diagnostic="DIRTY_OR_SPLIT_PUBLICATION"; return false; }
   result.disposition=SWV5_RESTART_SAFE_TO_RESUME; result.increasing_execution_eligible=true; result.diagnostic="SAFE_TO_RESUME"; return true;
}

#endif
