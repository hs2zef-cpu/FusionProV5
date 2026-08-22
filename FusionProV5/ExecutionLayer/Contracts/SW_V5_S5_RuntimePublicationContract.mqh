#ifndef SW_V5_S5_RUNTIME_PUBLICATION_CONTRACT_MQH
#define SW_V5_S5_RUNTIME_PUBLICATION_CONTRACT_MQH

// SPRINT 5 PHASE B.1 CANDIDATE CONTRACT
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
   if(!SWV5S5_CanonicalString("basket_id",checkpoint.header.persistence_namespace.basket_id.value,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("request_set_version",checkpoint.pending_request_set.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("request_count",checkpoint.pending_request_set.request_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("request_set_digest",checkpoint.pending_request_set.request_set_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("request_set_revision",checkpoint.pending_request_set.request_index_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("request_set_record_sequence",checkpoint.pending_request_set.record_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("has_latest_pending_request",checkpoint.has_latest_pending_request,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("hard_kill_latch_id",checkpoint.hard_kill_state.latch_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("hard_kill_generation",checkpoint.hard_kill_state.latch_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("hard_kill_state",checkpoint.hard_kill_state.state,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("hard_kill_release_generation",checkpoint.hard_kill_state.release_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("hard_kill_release_digest",checkpoint.hard_kill_state.release_evidence.release_record_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("hard_kill_authority_digest",checkpoint.hard_kill_state.release_authority_reference.authority_record_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("basket_lifecycle_id",checkpoint.basket.lifecycle.basket_id.value,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("basket_lifecycle_state",checkpoint.basket.lifecycle.state,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("basket_lifecycle_version",checkpoint.basket.lifecycle.state_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("reconciliation_revision",checkpoint.reconciliation_vector.reconciliation_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("reconciliation_digest",checkpoint.reconciliation_vector.source_summary_digest,f)) return false; body+=f;
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
