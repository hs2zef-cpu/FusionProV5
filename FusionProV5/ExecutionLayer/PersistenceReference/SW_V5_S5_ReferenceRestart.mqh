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

bool SWV5S5_ReferenceReleaseAuthorityValid(const SWV5_HardKillReleaseAuthorityRecord &record,
                                           const SWV5_PersistedCheckpoint &checkpoint,
                                           const SWV5_ContractValidationContext &context)
{
   return record.authority_record_id!="" && record.authority_record_digest!="" && record.latch_id==checkpoint.hard_kill_state.latch_id &&
      record.latch_generation==checkpoint.hard_kill_state.latch_generation && record.release_generation>=checkpoint.hard_kill_state.release_generation &&
      record.persistence_namespace.basket_id.value==checkpoint.header.persistence_namespace.basket_id.value &&
      record.account_namespace.account_mode==checkpoint.hard_kill_state.account_namespace.account_mode &&
      record.operator_identity.operator_id!="" && record.operator_identity.authentication_reference!="" &&
      record.operator_identity.authenticated_at>0 && record.approved_at>0 && record.released_at>=record.approved_at &&
      record.expires_at>context.clock_time;
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
