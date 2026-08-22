#ifndef SW_V5_S5_REQUEST_SEQUENCE_CONTRACT_MQH
#define SW_V5_S5_REQUEST_SEQUENCE_CONTRACT_MQH

// SPRINT 5 PHASE B CANDIDATE CONTRACT
// PURE LINEARIZABLE RESERVATION SHAPE / NO ALLOCATOR STORE IMPLEMENTATION

#include "SW_V5_S5_IngressLedgerContract.mqh"

struct SWV5S5_RequestSequenceAuthority
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   ulong allocator_revision;
   ulong request_sequence_high_watermark;
   string canonical_correlation_index;
   string authority_digest;
};

struct SWV5S5_RequestSequenceReservation
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   string logical_correlation_id;
   ulong expected_allocator_revision;
   ulong observed_high_watermark;
   ulong proposed_sequence;
   ulong proposed_allocator_revision;
   string reservation_digest;
};

struct SWV5S5_RequestSequenceResult
{
   SWV5_ContractVersion contract_version;
   SWV5S5_RequestSequenceDisposition disposition;
   string logical_correlation_id;
   ulong reserved_sequence;
   ulong resulting_allocator_revision;
   string reason_code;
};

bool SWV5S5_DeriveSequenceReservationDigest(const SWV5S5_RequestSequenceReservation &proposal,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",proposal.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",proposal.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",proposal.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("logical_correlation_id",proposal.logical_correlation_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expected_allocator_revision",proposal.expected_allocator_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("observed_high_watermark",proposal.observed_high_watermark,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("proposed_sequence",proposal.proposed_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("proposed_allocator_revision",proposal.proposed_allocator_revision,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_REQUEST_SEQUENCE,body,digest);
}

bool SWV5S5_EvaluateSequenceReservation(const SWV5S5_RequestSequenceAuthority &authority,
                                         const SWV5S5_RequestSequenceReservation &proposal,
                                         const bool correlation_exists,
                                         const ulong existing_sequence,
                                         SWV5S5_RequestSequenceResult &result)
{
   ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
   result.logical_correlation_id=proposal.logical_correlation_id;
   string expected_digest;
   if(!SWV5S5_IsCandidateVersion(authority.contract_version) ||
      !SWV5S5_IsCandidateVersion(proposal.contract_version) ||
      !SWV5S5_IsDigest64Lower(authority.authority_digest) ||
      !SWV5S5_DeriveSequenceReservationDigest(proposal,expected_digest) ||
      proposal.reservation_digest!=expected_digest)
   { result.disposition=SWV5S5_SEQUENCE_INVALID; return false; }
   if(!SWV5S5_EqualNamespace(authority.persistence_namespace,proposal.persistence_namespace) ||
      !SWV5S5_EqualFence(authority.ownership_fence,proposal.ownership_fence))
   { result.disposition=SWV5S5_SEQUENCE_STALE_OWNER; return false; }
   if(proposal.expected_allocator_revision!=authority.allocator_revision)
   { result.disposition=SWV5S5_SEQUENCE_STALE_REVISION; return false; }
   if(proposal.logical_correlation_id=="") { result.disposition=SWV5S5_SEQUENCE_INVALID; return false; }
   if(correlation_exists)
   {
      if(existing_sequence==0 || proposal.proposed_sequence!=existing_sequence)
      { result.disposition=SWV5S5_SEQUENCE_CONFLICT; return false; }
      result.disposition=SWV5S5_SEQUENCE_EXISTING_IDEMPOTENT;
      result.reserved_sequence=existing_sequence;
      result.resulting_allocator_revision=authority.allocator_revision;
      return true;
   }
   if(authority.request_sequence_high_watermark==18446744073709551615 ||
      proposal.observed_high_watermark!=authority.request_sequence_high_watermark ||
      proposal.proposed_sequence!=authority.request_sequence_high_watermark+1 ||
      proposal.proposed_allocator_revision!=authority.allocator_revision+1)
   { result.disposition=SWV5S5_SEQUENCE_CONFLICT; return false; }
   result.disposition=SWV5S5_SEQUENCE_RESERVED_NEW;
   result.reserved_sequence=proposal.proposed_sequence;
   result.resulting_allocator_revision=proposal.proposed_allocator_revision;
   return true;
}

class ISWV5S5RequestSequenceAuthority
{
public:
   virtual bool ReserveRequestSequence(const SWV5S5_RequestSequenceAuthority &observed,
                                       const SWV5S5_RequestSequenceReservation &proposal,
                                       SWV5S5_RequestSequenceResult &result)=0;
};

#endif
