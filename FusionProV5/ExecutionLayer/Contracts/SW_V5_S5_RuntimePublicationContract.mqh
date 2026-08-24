#ifndef SW_V5_S5_RUNTIME_PUBLICATION_CONTRACT_MQH
#define SW_V5_S5_RUNTIME_PUBLICATION_CONTRACT_MQH

// SPRINT 5 PHASE B.2 CANDIDATE CONTRACT
// DOMAIN-SPECIFIC PURE PROPOSALS + ABSTRACT COMMIT / NO PHYSICAL WRITE

#include "SW_V5_S5_RequestBindingContract.mqh"

struct SWV5S5_RequestSetPublicationAuthority
{
   SWV5_ContractVersion contract_version;
   string policy_id;
   uint policy_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   string store_revision;
   SWV5_PersistedRequestSetHeader current_set_header;
   string current_complete_set_digest;
};

struct SWV5S5_RequestSetPublicationProposal
{
   SWV5_ContractVersion contract_version;
   string policy_id;
   uint policy_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence expected_ownership_fence;
   ulong expected_takeover_generation;
   string expected_store_revision;
   string expected_request_set_revision;
   string expected_request_set_digest;
   ulong expected_record_sequence;
   string proposed_store_revision;
   SWV5_PersistedRequestSetHeader proposed_set_header;
   string proposed_complete_set_digest;
   string proposal_digest;
};

struct SWV5S5_CheckpointPublicationAuthority
{
   SWV5_ContractVersion contract_version;
   string policy_id;
   uint policy_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   SWV5_PersistenceRecordHeader current_header;
   string current_checkpoint_projection_digest;
};

struct SWV5S5_CheckpointPublicationProposal
{
   SWV5_ContractVersion contract_version;
   string policy_id;
   uint policy_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence expected_ownership_fence;
   ulong expected_takeover_generation;
   string expected_store_revision;
   ulong expected_record_sequence;
   string expected_checkpoint_projection_digest;
   SWV5_PersistedCheckpoint proposed_checkpoint;
   string proposed_checkpoint_projection_digest;
   string proposal_digest;
};

struct SWV5S5_FencedPublicationResult
{
   SWV5_ContractVersion contract_version;
   SWV5S5_PublicationDisposition disposition;
   string proposed_store_revision;
   ulong proposed_record_sequence;
   string resulting_projection_digest;
   string reason_code;
};

bool SWV5S5_DeriveCompleteRequestSetDigest(const SWV5_PendingRequest &requests[],string &digest)
{
   string body="",record,f;
   for(int i=0;i<ArraySize(requests);i++)
   {
      if(!SWV5S5_CanonicalPendingRequest(requests[i],record) ||
         !SWV5S5_CanonicalIndexed("request",(ulong)i,record,f)) return false;
      body+=f;
   }
   return SWV5S5_SHA256(body,digest);
}

bool SWV5S5_DeriveRequestSetProposalDigest(const SWV5S5_RequestSetPublicationProposal &proposal,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",proposal.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("policy_id",proposal.policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("policy_version",proposal.policy_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",proposal.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("expected_fence",proposal.expected_ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expected_takeover_generation",proposal.expected_takeover_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("expected_store_revision",proposal.expected_store_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("expected_request_set_revision",proposal.expected_request_set_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("expected_request_set_digest",proposal.expected_request_set_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expected_record_sequence",proposal.expected_record_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("proposed_store_revision",proposal.proposed_store_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("proposed_header_version",proposal.proposed_set_header.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("proposed_set_revision",proposal.proposed_set_header.request_index_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("proposed_record_sequence",proposal.proposed_set_header.record_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("proposed_request_count",proposal.proposed_set_header.request_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("proposed_header_set_digest",proposal.proposed_set_header.request_set_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("proposed_complete_set_digest",proposal.proposed_complete_set_digest,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_REQUEST_SET_PUBLICATION,body,digest);
}

bool SWV5S5_EvaluateRequestSetPublication(const SWV5S5_RequestSetPublicationAuthority &authority,
                                           const SWV5_PendingRequest &current_requests[],
                                           const SWV5S5_RequestSetPublicationProposal &proposal,
                                           const SWV5_PendingRequest &proposed_requests[],
                                           SWV5S5_FencedPublicationResult &result)
{
   ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
   string current_digest,proposed_digest,expected_proposal;
   if(!SWV5S5_IsCandidateVersion(authority.contract_version) || !SWV5S5_IsCandidateVersion(proposal.contract_version) ||
      authority.policy_id!=SWV5S5_PUBLICATION_POLICY_ID || authority.policy_version!=SWV5S5_PUBLICATION_POLICY_VERSION ||
      !SWV5S5_IsV5Version(authority.current_set_header.contract_version) ||
      !SWV5S5_IsV5Version(proposal.proposed_set_header.contract_version) ||
      !SWV5S5_DeriveCompleteRequestSetDigest(current_requests,current_digest) ||
      authority.current_set_header.request_count!=(uint)ArraySize(current_requests) ||
      authority.current_set_header.request_set_digest!=current_digest || authority.current_complete_set_digest!=current_digest ||
      !SWV5S5_DeriveCompleteRequestSetDigest(proposed_requests,proposed_digest) ||
      proposal.proposed_set_header.request_count!=(uint)ArraySize(proposed_requests) ||
      proposal.proposed_set_header.request_set_digest!=proposed_digest || proposal.proposed_complete_set_digest!=proposed_digest ||
      proposal.policy_id!=SWV5S5_PUBLICATION_POLICY_ID || proposal.policy_version!=SWV5S5_PUBLICATION_POLICY_VERSION ||
      !SWV5S5_DeriveRequestSetProposalDigest(proposal,expected_proposal) || proposal.proposal_digest!=expected_proposal)
   { result.disposition=SWV5S5_PUBLICATION_INTEGRITY_FAILURE; result.reason_code="REQUEST_SET_INTEGRITY"; return false; }
   if(!SWV5S5_EqualNamespace(authority.persistence_namespace,proposal.persistence_namespace) ||
      !SWV5S5_EqualFence(authority.ownership_fence,proposal.expected_ownership_fence) ||
      proposal.expected_takeover_generation!=authority.ownership_fence.takeover_generation)
   { result.disposition=SWV5S5_PUBLICATION_STALE_OWNER; result.reason_code="REQUEST_SET_STALE_OWNER"; return false; }
   if(authority.store_revision!=proposal.expected_store_revision ||
      authority.current_set_header.request_index_revision!=proposal.expected_request_set_revision ||
      current_digest!=proposal.expected_request_set_digest ||
      authority.current_set_header.record_sequence!=proposal.expected_record_sequence)
   { result.disposition=SWV5S5_PUBLICATION_STALE_REVISION; result.reason_code="REQUEST_SET_EXPECTED_CURRENT_MISMATCH"; return false; }
   if(authority.current_set_header.record_sequence==18446744073709551615 ||
      proposal.proposed_set_header.record_sequence!=authority.current_set_header.record_sequence+1 ||
      proposal.proposed_store_revision==authority.store_revision ||
      proposal.proposed_set_header.request_index_revision==authority.current_set_header.request_index_revision)
   { result.disposition=SWV5S5_PUBLICATION_CONFLICT; result.reason_code="REQUEST_SET_NEXT_STATE_INVALID"; return false; }
   result.disposition=SWV5S5_PUBLICATION_PROPOSAL_VALID;
   result.proposed_store_revision=proposal.proposed_store_revision;
   result.proposed_record_sequence=proposal.proposed_set_header.record_sequence;
   result.resulting_projection_digest=proposed_digest;
   result.reason_code="REQUEST_SET_PROPOSAL_VALID_NO_COMMIT";
   return true;
}

bool SWV5S5_CanonicalCheckpointBrokerIdentity(const string name,const SWV5_BrokerExecutionIdentity &v,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("order",v.order_ticket,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("deal",v.deal_ticket,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("position",v.position_identifier,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("event",v.broker_event_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("transaction",v.transaction_sequence,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalCheckpointCorrelation(const string name,const SWV5_ExecutionCorrelation &v,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("phase",v.phase,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",v.request_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalCheckpointBrokerIdentity("broker",v.broker_identity,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalCheckpointEventSet(const string name,const SWV5_DurableEventIdentitySet &v,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("fingerprint_policy",v.fingerprint_policy,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("event_index",v.canonical_event_index,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("fingerprint_index",v.canonical_fingerprint_index,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("identity_set_digest",v.identity_set_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("count",v.accepted_identity_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("transaction_hwm",v.highest_transaction_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("index_revision",v.index_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("compaction_generation",v.compaction_generation,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalCheckpointQueries(const string name,const SWV5_AuthoritativeQuerySet &v,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("required",v.required_flags,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("completed",v.completed_flags,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("authoritative",v.authoritative_flags,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("observation_sequence",v.observation_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",v.observed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("issuing_component",v.issuing_component,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("authority_source",v.authority_source,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("snapshot_id",v.snapshot_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("snapshot_digest",v.snapshot_digest,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalCheckpointTypedEvidence(const string name,
                                              const SWV5_TypedReconciliationEvidence &v,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",v.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("evidence_id",v.evidence_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("issuing_component",v.issuing_component,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("authority_source",v.authority_source,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("evidence_sequence",v.evidence_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",v.observed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("state_digest",v.state_digest,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalCheckpointExposureEvidence(const string name,
                                                 const SWV5_ExposureReductionEvidence &v,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("evidence_id",v.evidence_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("issuing_component",v.issuing_component,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("authority_source",v.authority_source,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("observed_exposure_volume",v.observed_exposure_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("prior_exposure_volume",v.prior_exposure_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("zero_or_reducing",v.zero_or_reducing,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("evidence_sequence",v.evidence_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",v.observed_at,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalCheckpointLifecycle(const string name,const SWV5_BasketLifecycleSnapshot &v,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("basket_id",v.basket_id.value,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",v.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("state",v.state,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("state_version",v.state_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("recovery_attempts",v.cumulative_recovery_attempts,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("recovery_layer",v.current_recovery_layer,f)) return false; body+=f;
   if(!SWV5S5_CanonicalCheckpointEventSet("recovery_evidence",v.accepted_recovery_evidence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("open_volume",v.aggregate_open_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("residual_volume",v.residual_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("positions",v.live_position_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("orders",v.live_order_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("pending",v.pending_request_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("reconciliation",v.reconciliation_state,f)) return false; body+=f;
   if(!SWV5S5_CanonicalCheckpointQueries("queries",v.broker_queries,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("state_entered_at",v.state_entered_at,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalCheckpointBasket(const string name,const SWV5_BasketAggregate &v,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",v.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("account_mode",v.account_mode,f)) return false; body+=f;
   if(!SWV5S5_CanonicalCheckpointLifecycle("lifecycle",v.lifecycle,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("initial_volume",v.initial_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("closed_volume",v.aggregate_closed_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("close_verification",v.close_verification,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("opened_at",v.opened_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("updated_at",v.updated_at,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalCheckpointPersistedRequest(const string name,const SWV5_PersistedRequestEvidence &v,string &field)
{
   string body="",f,request;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",v.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",v.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalPendingRequest(v.pending_request,request) || !SWV5S5_CanonicalNested("request",request,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("account_mode",v.account_mode,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("record_sequence",v.record_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("recorded_at",v.recorded_at,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalCheckpointHardKill(const string name,const SWV5_HardKillState &v,string &field)
{
   string body="",f;
#define SWV5S5_CHK_S(n,x) if(!SWV5S5_CanonicalString(n,x,f)) return false; else body+=f
#define SWV5S5_CHK_U(n,x) if(!SWV5S5_CanonicalUInt(n,x,f)) return false; else body+=f
#define SWV5S5_CHK_I(n,x) if(!SWV5S5_CanonicalInt(n,x,f)) return false; else body+=f
#define SWV5S5_CHK_D(n,x) if(!SWV5S5_CanonicalDouble(n,x,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",v.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("account_version",v.account_namespace.contract_version,f)) return false; body+=f;
   SWV5S5_CHK_S("account_broker",v.account_namespace.broker_identity); SWV5S5_CHK_S("account_server",v.account_namespace.server);
   SWV5S5_CHK_I("account_login",v.account_namespace.account_login); SWV5S5_CHK_S("account_currency",v.account_namespace.account_currency);
   SWV5S5_CHK_S("account_strategy",v.account_namespace.strategy_id); SWV5S5_CHK_U("account_magic",v.account_namespace.magic);
   SWV5S5_CHK_I("account_mode",v.account_namespace.account_mode); SWV5S5_CHK_I("account_source",v.account_namespace.authoritative_source);
   SWV5S5_CHK_U("account_epoch",v.account_namespace.snapshot_epoch); SWV5S5_CHK_U("account_sequence",v.account_namespace.snapshot_sequence);
   SWV5S5_CHK_S("latch_id",v.latch_id); SWV5S5_CHK_U("latch_generation",v.latch_generation); SWV5S5_CHK_I("state",v.state);
   SWV5S5_CHK_S("activation_reason",v.activation_reason); SWV5S5_CHK_I("activated_at",v.activated_at);
   SWV5S5_CHK_S("activation_authority",v.activation_authority); SWV5S5_CHK_U("release_generation",v.release_generation);
   if(!SWV5S5_CanonicalContractVersion("release_version",v.release_evidence.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("release_scope",v.release_evidence.persistence_namespace,f)) return false; body+=f;
   SWV5S5_CHK_S("release_id",v.release_evidence.release_id);
   SWV5S5_CHK_S("release_latch_id",v.release_evidence.latch_id);
   SWV5S5_CHK_U("release_latch_generation",v.release_evidence.latch_generation);
   SWV5S5_CHK_U("release_generation",v.release_evidence.release_generation);
   SWV5S5_CHK_S("release_approval_policy",v.release_evidence.approval_policy_id);
   SWV5S5_CHK_U("release_approval_sequence",v.release_evidence.approval_sequence);
   SWV5S5_CHK_S("release_operator",v.release_evidence.operator_identity.operator_id);
   SWV5S5_CHK_S("release_role",v.release_evidence.operator_identity.authority_role);
   SWV5S5_CHK_S("release_authentication",v.release_evidence.operator_identity.authentication_reference);
   SWV5S5_CHK_I("release_authenticated_at",v.release_evidence.operator_identity.authenticated_at);
   SWV5S5_CHK_I("release_approving_component",v.release_evidence.approving_component);
   if(!SWV5S5_CanonicalCheckpointTypedEvidence("release_broker_evidence",v.release_evidence.broker_evidence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalCheckpointTypedEvidence("release_persistence_evidence",v.release_evidence.persistence_evidence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalCheckpointExposureEvidence("release_exposure_evidence",v.release_evidence.exposure_evidence,f)) return false; body+=f;
   SWV5S5_CHK_I("release_approved_at",v.release_evidence.approved_at); SWV5S5_CHK_I("release_released_at",v.release_evidence.released_at);
   SWV5S5_CHK_I("release_expires_at",v.release_evidence.expires_at); SWV5S5_CHK_U("release_record_sequence",v.release_evidence.release_record_sequence);
   SWV5S5_CHK_S("release_record_digest",v.release_evidence.release_record_digest); SWV5S5_CHK_S("release_audit",v.release_evidence.audit_reference);
   if(!SWV5S5_CanonicalContractVersion("authority_reference_version",v.release_authority_reference.contract_version,f)) return false; body+=f;
   SWV5S5_CHK_S("authority_record_id",v.release_authority_reference.authority_record_id);
   SWV5S5_CHK_U("authority_record_sequence",v.release_authority_reference.authority_record_sequence);
   SWV5S5_CHK_S("authority_record_digest",v.release_authority_reference.authority_record_digest);
   SWV5S5_CHK_S("authority_release_id",v.release_authority_reference.release_id);
   SWV5S5_CHK_U("authority_latch_generation",v.release_authority_reference.latch_generation);
   SWV5S5_CHK_U("authority_release_generation",v.release_authority_reference.release_generation);
#undef SWV5S5_CHK_S
#undef SWV5S5_CHK_U
#undef SWV5S5_CHK_I
#undef SWV5S5_CHK_D
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalCheckpointReconciliation(const string name,const SWV5_PersistedReconciliationVector &v,string &field)
{
   string body="",f;
#define SWV5S5_CR_U(n,x) if(!SWV5S5_CanonicalUInt(n,x,f)) return false; else body+=f
#define SWV5S5_CR_D(n,x) if(!SWV5S5_CanonicalDouble(n,x,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",v.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("basket_id",v.basket_id.value,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("account_mode",v.account_mode,f)) return false; body+=f;
   SWV5S5_CR_D("long",v.symbol_long_volume); SWV5S5_CR_D("short",v.symbol_short_volume); SWV5S5_CR_D("net",v.symbol_net_volume);
   SWV5S5_CR_D("aggregate",v.aggregate_position_volume); SWV5S5_CR_D("basket_open",v.basket_open_volume); SWV5S5_CR_D("residual",v.residual_volume);
   SWV5S5_CR_U("positions",v.position_count); SWV5S5_CR_U("orders",v.order_count); SWV5S5_CR_U("pending",v.pending_request_count);
   if(!SWV5S5_CanonicalCheckpointCorrelation("latest_correlation",v.latest_confirmed_correlation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalCheckpointBrokerIdentity("latest_broker",v.latest_broker_event_identity,f)) return false; body+=f;
   SWV5S5_CR_U("transaction_hwm",v.transaction_high_watermark); SWV5S5_CR_U("broker_query_hwm",v.broker_query_sequence_high_watermark);
   SWV5S5_CR_U("request_query_hwm",v.request_query_sequence_high_watermark);
   if(!SWV5S5_CanonicalString("request_set_digest",v.request_set_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("request_set_revision",v.request_set_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("basket_state",v.basket_state,f)) return false; body+=f;
   SWV5S5_CR_U("basket_version",v.basket_state_version); SWV5S5_CR_U("hard_kill_generation",v.hard_kill_generation);
   if(!SWV5S5_CanonicalFence("fence",v.ownership_fence,f)) return false; body+=f;
   SWV5S5_CR_U("reconciliation_revision",v.reconciliation_revision);
   if(!SWV5S5_CanonicalString("source_summary_digest",v.source_summary_digest,f)) return false; body+=f;
#undef SWV5S5_CR_U
#undef SWV5S5_CR_D
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_DeriveCheckpointProjection(const SWV5_PersistedCheckpoint &checkpoint,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("header_version",checkpoint.header.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",checkpoint.header.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",checkpoint.header.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("record_sequence",checkpoint.header.record_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("previous_record_sequence",checkpoint.header.previous_record_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("store_revision",checkpoint.header.store_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("payload_digest",checkpoint.header.payload_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("payload_size",checkpoint.header.payload_size,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("written_at",checkpoint.header.written_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalCheckpointBasket("basket",checkpoint.basket,f)) return false; body+=f;
   if(!SWV5S5_CanonicalCheckpointCorrelation("last_confirmed_correlation",checkpoint.last_confirmed_correlation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("request_set_version",checkpoint.pending_request_set.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("request_count",checkpoint.pending_request_set.request_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("request_set_digest",checkpoint.pending_request_set.request_set_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("request_set_revision",checkpoint.pending_request_set.request_index_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("request_set_record_sequence",checkpoint.pending_request_set.record_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("has_latest_pending_request",checkpoint.has_latest_pending_request,f)) return false; body+=f;
   if(!SWV5S5_CanonicalCheckpointPersistedRequest("latest_pending_request",checkpoint.latest_pending_request,f)) return false; body+=f;
   if(!SWV5S5_CanonicalCheckpointHardKill("hard_kill",checkpoint.hard_kill_state,f)) return false; body+=f;
   if(!SWV5S5_CanonicalCheckpointReconciliation("reconciliation",checkpoint.reconciliation_vector,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("clean_shutdown",checkpoint.clean_shutdown,f)) return false; body+=f;
   return SWV5S5_SHA256(body,digest);
}

bool SWV5S5_DeriveCheckpointProposalDigest(const SWV5S5_CheckpointPublicationProposal &proposal,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",proposal.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("policy_id",proposal.policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("policy_version",proposal.policy_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",proposal.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("expected_fence",proposal.expected_ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expected_takeover_generation",proposal.expected_takeover_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("expected_store_revision",proposal.expected_store_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expected_record_sequence",proposal.expected_record_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("expected_projection",proposal.expected_checkpoint_projection_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("proposed_projection",proposal.proposed_checkpoint_projection_digest,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_CHECKPOINT_PUBLICATION,body,digest);
}

bool SWV5S5_EvaluateCheckpointPublication(const SWV5S5_CheckpointPublicationAuthority &authority,
                                           const SWV5S5_CheckpointPublicationProposal &proposal,
                                           SWV5S5_FencedPublicationResult &result)
{
   ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
   string proposed_projection,expected_proposal;
   if(!SWV5S5_IsCandidateVersion(authority.contract_version) || !SWV5S5_IsCandidateVersion(proposal.contract_version) ||
      authority.policy_id!=SWV5S5_PUBLICATION_POLICY_ID || authority.policy_version!=SWV5S5_PUBLICATION_POLICY_VERSION ||
      proposal.policy_id!=SWV5S5_PUBLICATION_POLICY_ID || proposal.policy_version!=SWV5S5_PUBLICATION_POLICY_VERSION ||
      !SWV5S5_IsV5Version(authority.current_header.contract_version) ||
      !SWV5S5_IsV5Version(proposal.proposed_checkpoint.header.contract_version) ||
      !SWV5S5_DeriveCheckpointProjection(proposal.proposed_checkpoint,proposed_projection) ||
      proposed_projection!=proposal.proposed_checkpoint_projection_digest ||
      !SWV5S5_DeriveCheckpointProposalDigest(proposal,expected_proposal) || proposal.proposal_digest!=expected_proposal)
   { result.disposition=SWV5S5_PUBLICATION_INTEGRITY_FAILURE; result.reason_code="CHECKPOINT_INTEGRITY"; return false; }
   if(!SWV5S5_EqualNamespace(authority.persistence_namespace,authority.current_header.persistence_namespace) ||
      !SWV5S5_EqualFence(authority.ownership_fence,authority.current_header.ownership_fence) ||
      !SWV5S5_EqualNamespace(authority.persistence_namespace,proposal.persistence_namespace) ||
      !SWV5S5_EqualNamespace(proposal.persistence_namespace,proposal.proposed_checkpoint.header.persistence_namespace) ||
      !SWV5S5_EqualFence(authority.ownership_fence,proposal.expected_ownership_fence) ||
      proposal.expected_takeover_generation!=authority.ownership_fence.takeover_generation)
   { result.disposition=SWV5S5_PUBLICATION_STALE_OWNER; result.reason_code="CHECKPOINT_STALE_OWNER"; return false; }
   if(authority.current_header.store_revision!=proposal.expected_store_revision ||
      authority.current_header.record_sequence!=proposal.expected_record_sequence ||
      authority.current_checkpoint_projection_digest!=proposal.expected_checkpoint_projection_digest)
   { result.disposition=SWV5S5_PUBLICATION_STALE_REVISION; result.reason_code="CHECKPOINT_EXPECTED_CURRENT_MISMATCH"; return false; }
   if(authority.current_header.record_sequence==18446744073709551615 ||
      proposal.proposed_checkpoint.header.previous_record_sequence!=authority.current_header.record_sequence ||
      proposal.proposed_checkpoint.header.record_sequence!=authority.current_header.record_sequence+1 ||
      proposal.proposed_checkpoint.header.store_revision==authority.current_header.store_revision ||
      !SWV5S5_EqualFence(proposal.proposed_checkpoint.header.ownership_fence,authority.ownership_fence))
   { result.disposition=SWV5S5_PUBLICATION_CONFLICT; result.reason_code="CHECKPOINT_NEXT_STATE_INVALID"; return false; }
   result.disposition=SWV5S5_PUBLICATION_PROPOSAL_VALID;
   result.proposed_store_revision=proposal.proposed_checkpoint.header.store_revision;
   result.proposed_record_sequence=proposal.proposed_checkpoint.header.record_sequence;
   result.resulting_projection_digest=proposed_projection;
   result.reason_code="CHECKPOINT_PROPOSAL_VALID_NO_COMMIT";
   return true;
}

class ISWV5S5FencedRuntimePublicationAuthority
{
public:
   // Future physical implementation owns expected-current comparison and may
   // return PUBLICATION_COMMITTED only after the actual fenced write succeeds.
   virtual bool TryPublishRequestSet(const SWV5S5_RequestSetPublicationProposal &proposal,
                                     const SWV5_PendingRequest &proposed_requests[],
                                     SWV5S5_FencedPublicationResult &authoritative_result)=0;
   virtual bool TryPublishCheckpoint(const SWV5S5_CheckpointPublicationProposal &proposal,
                                     SWV5S5_FencedPublicationResult &authoritative_result)=0;
};

#endif
