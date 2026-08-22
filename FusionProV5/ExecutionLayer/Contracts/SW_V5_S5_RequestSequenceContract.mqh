#ifndef SW_V5_S5_REQUEST_SEQUENCE_CONTRACT_MQH
#define SW_V5_S5_REQUEST_SEQUENCE_CONTRACT_MQH

// SPRINT 5 PHASE B.1 CANDIDATE CONTRACT
// EXPLICIT AUTHORITY-OWNED INDEX / PURE PREPARATION / NO ALLOCATOR STORE

#include "SW_V5_S5_IngressLedgerContract.mqh"

struct SWV5S5_RequestSequenceIndexEntry
{
   string logical_correlation_id;
   ulong reserved_sequence;
   ulong reservation_revision;
   string binding_digest;
};

struct SWV5S5_RequestSequenceAuthority
{
   SWV5_ContractVersion contract_version;
   string policy_id;
   uint policy_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   ulong allocator_revision;
   ulong request_sequence_high_watermark;
   uint reservation_count;
   string reservation_index_digest;
   string authority_digest;
};

struct SWV5S5_RequestSequenceReservation
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   string logical_correlation_id;
   string binding_digest;
   ulong expected_allocator_revision;
   string expected_authority_digest;
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
   string resulting_authority_digest;
   string reason_code;
};

bool SWV5S5_DeriveSequenceIndexDigest(const SWV5S5_RequestSequenceIndexEntry &entries[],string &digest)
{
   string body="",f,entry;
   int count=ArraySize(entries);
   for(int i=0;i<count;i++)
   {
      entry="";
      if(entries[i].logical_correlation_id=="" || entries[i].reserved_sequence==0 ||
         entries[i].binding_digest=="" || (i>0 && StringCompare(entries[i-1].logical_correlation_id,entries[i].logical_correlation_id)>=0) ||
         !SWV5S5_CanonicalString("logical_correlation_id",entries[i].logical_correlation_id,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalUInt("reserved_sequence",entries[i].reserved_sequence,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalUInt("reservation_revision",entries[i].reservation_revision,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalString("binding_digest",entries[i].binding_digest,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalIndexed("reservation",(ulong)i,entry,f)) return false; body+=f;
   }
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_REQUEST_SEQUENCE,body,digest);
}

bool SWV5S5_DeriveSequenceAuthorityDigest(const SWV5S5_RequestSequenceAuthority &authority,
                                           const SWV5S5_RequestSequenceIndexEntry &entries[],string &digest)
{
   string index_digest,body="",f;
   if(authority.reservation_count!=(uint)ArraySize(entries) ||
      !SWV5S5_DeriveSequenceIndexDigest(entries,index_digest) ||
      authority.reservation_index_digest!=index_digest) return false;
   if(!SWV5S5_CanonicalContractVersion("version",authority.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("policy_id",authority.policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("policy_version",authority.policy_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",authority.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",authority.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("allocator_revision",authority.allocator_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("request_sequence_high_watermark",authority.request_sequence_high_watermark,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("reservation_count",authority.reservation_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("reservation_index_digest",index_digest,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_REQUEST_SEQUENCE,body,digest);
}

int SWV5S5_FindSequenceReservation(const SWV5S5_RequestSequenceIndexEntry &entries[],const string correlation)
{
   for(int i=0;i<ArraySize(entries);i++) if(entries[i].logical_correlation_id==correlation) return i;
   return -1;
}

bool SWV5S5_DeriveSequenceReservationDigest(const SWV5S5_RequestSequenceReservation &proposal,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",proposal.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",proposal.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",proposal.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("logical_correlation_id",proposal.logical_correlation_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("binding_digest",proposal.binding_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expected_allocator_revision",proposal.expected_allocator_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("expected_authority_digest",proposal.expected_authority_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("observed_high_watermark",proposal.observed_high_watermark,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("proposed_sequence",proposal.proposed_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("proposed_allocator_revision",proposal.proposed_allocator_revision,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_REQUEST_SEQUENCE,body,digest);
}

bool SWV5S5_PrepareSequenceReservation(const SWV5S5_RequestSequenceAuthority &authority,
                                        const SWV5S5_RequestSequenceIndexEntry &entries[],
                                        const SWV5S5_RequestSequenceReservation &proposal,
                                        SWV5S5_RequestSequenceResult &result)
{
   ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
   result.logical_correlation_id=proposal.logical_correlation_id;
   string expected_authority_digest,expected_proposal_digest;
   if(!SWV5S5_IsCandidateVersion(authority.contract_version) ||
      !SWV5S5_IsCandidateVersion(proposal.contract_version) ||
      authority.policy_id!=SWV5S5_REQUEST_BINDING_POLICY_ID ||
      authority.policy_version!=SWV5S5_REQUEST_BINDING_POLICY_VERSION ||
      !SWV5S5_DeriveSequenceAuthorityDigest(authority,entries,expected_authority_digest) ||
      authority.authority_digest!=expected_authority_digest ||
      proposal.expected_authority_digest!=authority.authority_digest ||
      !SWV5S5_DeriveSequenceReservationDigest(proposal,expected_proposal_digest) ||
      proposal.reservation_digest!=expected_proposal_digest)
   { result.disposition=SWV5S5_SEQUENCE_INVALID; result.reason_code="SEQUENCE_AUTHORITY_INVALID"; return false; }
   if(!SWV5S5_EqualNamespace(authority.persistence_namespace,proposal.persistence_namespace) ||
      !SWV5S5_EqualFence(authority.ownership_fence,proposal.ownership_fence))
   { result.disposition=SWV5S5_SEQUENCE_STALE_OWNER; result.reason_code="SEQUENCE_STALE_OWNER"; return false; }
   if(proposal.expected_allocator_revision!=authority.allocator_revision)
   { result.disposition=SWV5S5_SEQUENCE_STALE_REVISION; result.reason_code="SEQUENCE_STALE_REVISION"; return false; }
   int existing=SWV5S5_FindSequenceReservation(entries,proposal.logical_correlation_id);
   if(existing>=0)
   {
      if(entries[existing].binding_digest!=proposal.binding_digest ||
         proposal.proposed_sequence!=entries[existing].reserved_sequence)
      { result.disposition=SWV5S5_SEQUENCE_CONFLICT; result.reason_code="SEQUENCE_BINDING_CONFLICT"; return false; }
      result.disposition=SWV5S5_SEQUENCE_EXISTING_IDEMPOTENT;
      result.reserved_sequence=entries[existing].reserved_sequence;
      result.resulting_allocator_revision=authority.allocator_revision;
      result.resulting_authority_digest=authority.authority_digest;
      result.reason_code="SEQUENCE_EXISTING_IDEMPOTENT";
      return true;
   }
   if(authority.request_sequence_high_watermark==18446744073709551615 ||
      authority.allocator_revision==18446744073709551615 ||
      proposal.observed_high_watermark!=authority.request_sequence_high_watermark ||
      proposal.proposed_sequence!=authority.request_sequence_high_watermark+1 ||
      proposal.proposed_allocator_revision!=authority.allocator_revision+1)
   { result.disposition=SWV5S5_SEQUENCE_CONFLICT; result.reason_code="SEQUENCE_MONOTONICITY_CONFLICT"; return false; }
   result.disposition=SWV5S5_SEQUENCE_PROPOSAL_VALID;
   result.reserved_sequence=proposal.proposed_sequence;
   result.resulting_allocator_revision=proposal.proposed_allocator_revision;
   result.reason_code="SEQUENCE_PROPOSAL_VALID_NO_COMMIT";
   return true;
}

class ISWV5S5RequestSequenceAuthority
{
public:
   // Future physical implementation atomically compares the authority and index,
   // appends one reservation, and only then may return SEQUENCE_RESERVED_NEW.
   virtual bool TryReserveRequestSequence(const SWV5S5_RequestSequenceAuthority &expected,
                                          const SWV5S5_RequestSequenceIndexEntry &expected_entries[],
                                          const SWV5S5_RequestSequenceReservation &proposal,
                                          SWV5S5_RequestSequenceResult &authoritative_result)=0;
};

#endif
