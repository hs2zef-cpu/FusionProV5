#ifndef SW_V5_S5_RUNTIME_PUBLICATION_CONTRACT_MQH
#define SW_V5_S5_RUNTIME_PUBLICATION_CONTRACT_MQH

// SPRINT 5 PHASE B CANDIDATE CONTRACT
// PURE FENCED PUBLICATION PROPOSALS / NO WRITE, CAS, OR STORE IMPLEMENTATION

#include "SW_V5_S5_RequestBindingContract.mqh"

struct SWV5S5_PublicationAuthority
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   string store_revision;
   ulong logical_revision;
   string current_payload_digest;
};

struct SWV5S5_FencedPublicationProposal
{
   SWV5_ContractVersion contract_version;
   string domain;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   string expected_store_revision;
   ulong expected_logical_revision;
   ulong proposed_logical_revision;
   string complete_payload_digest;
   string proposal_digest;
};

struct SWV5S5_FencedPublicationResult
{
   SWV5_ContractVersion contract_version;
   SWV5S5_PublicationDisposition disposition;
   ulong proposed_logical_revision;
   string reason_code;
};

bool SWV5S5_DerivePublicationProposalDigest(const SWV5S5_FencedPublicationProposal &proposal,
                                             string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",proposal.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("domain",proposal.domain,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",proposal.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",proposal.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("expected_store_revision",proposal.expected_store_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expected_logical_revision",proposal.expected_logical_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("proposed_logical_revision",proposal.proposed_logical_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("complete_payload_digest",proposal.complete_payload_digest,f)) return false; body+=f;
   return SWV5S5_DomainDigest(proposal.domain,body,digest);
}

bool SWV5S5_EvaluateFencedPublication(const SWV5S5_PublicationAuthority &authority,
                                      const SWV5S5_FencedPublicationProposal &proposal,
                                      const string expected_domain,
                                      SWV5S5_FencedPublicationResult &result)
{
   ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
   result.proposed_logical_revision=proposal.proposed_logical_revision;
   string expected_digest;
   if(proposal.domain!=expected_domain || !SWV5S5_IsCandidateVersion(proposal.contract_version) ||
      !SWV5S5_IsDigest64Lower(proposal.complete_payload_digest) ||
      !SWV5S5_DerivePublicationProposalDigest(proposal,expected_digest) ||
      proposal.proposal_digest!=expected_digest)
   { result.disposition=SWV5S5_PUBLICATION_INTEGRITY_FAILURE; result.reason_code="PUBLICATION_INTEGRITY"; return false; }
   if(!SWV5S5_EqualNamespace(authority.persistence_namespace,proposal.persistence_namespace) ||
      !SWV5S5_EqualFence(authority.ownership_fence,proposal.ownership_fence))
   { result.disposition=SWV5S5_PUBLICATION_STALE_OWNER; result.reason_code="STALE_OWNER"; return false; }
   if(authority.store_revision!=proposal.expected_store_revision ||
      authority.logical_revision!=proposal.expected_logical_revision)
   { result.disposition=SWV5S5_PUBLICATION_STALE_REVISION; result.reason_code="STALE_REVISION"; return false; }
   if(authority.logical_revision==18446744073709551615 ||
      proposal.proposed_logical_revision!=authority.logical_revision+1)
   { result.disposition=SWV5S5_PUBLICATION_CONFLICT; result.reason_code="NON_MONOTONIC_REVISION"; return false; }
   result.disposition=SWV5S5_PUBLICATION_ELIGIBLE; result.reason_code="ELIGIBLE"; return true;
}

bool SWV5S5_EvaluateRequestSetPublication(const SWV5S5_PublicationAuthority &authority,
                                           const SWV5S5_FencedPublicationProposal &proposal,
                                           SWV5S5_FencedPublicationResult &result)
{ return SWV5S5_EvaluateFencedPublication(authority,proposal,SWV5S5_DOMAIN_REQUEST_SET_PUBLICATION,result); }

bool SWV5S5_EvaluateCheckpointPublication(const SWV5S5_PublicationAuthority &authority,
                                           const SWV5S5_FencedPublicationProposal &proposal,
                                           SWV5S5_FencedPublicationResult &result)
{ return SWV5S5_EvaluateFencedPublication(authority,proposal,SWV5S5_DOMAIN_CHECKPOINT_PUBLICATION,result); }

class ISWV5S5FencedRuntimePublicationContract
{
public:
   virtual bool ProposeRequestSet(const SWV5S5_PublicationAuthority &observed,
                                  const SWV5S5_FencedPublicationProposal &proposal,
                                  SWV5S5_FencedPublicationResult &result)=0;
   virtual bool ProposeCheckpoint(const SWV5S5_PublicationAuthority &observed,
                                  const SWV5S5_FencedPublicationProposal &proposal,
                                  SWV5S5_FencedPublicationResult &result)=0;
};

#endif
