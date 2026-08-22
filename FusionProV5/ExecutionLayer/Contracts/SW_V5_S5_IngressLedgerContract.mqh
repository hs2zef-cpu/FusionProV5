#ifndef SW_V5_S5_INGRESS_LEDGER_CONTRACT_MQH
#define SW_V5_S5_INGRESS_LEDGER_CONTRACT_MQH

// SPRINT 5 PHASE B CANDIDATE CONTRACT
// PURE LEDGER PROPOSALS / NO CAS OR PHYSICAL STORE IMPLEMENTATION

#include "SW_V5_S5_ProducerTrustContract.mqh"

struct SWV5S5_IngressLedgerHeader
{
   SWV5_ContractVersion contract_version;
   string policy_id;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   string producer_authority_record_id;
   string producer_instance;
   ulong producer_epoch;
   ulong highest_accepted_publication_sequence;
   ulong revision;
   ulong previous_revision;
   ulong compaction_generation;
   string canonical_membership_binding_index;
   string ledger_digest;
};

struct SWV5S5_IngressLedgerRecord
{
   SWV5_ContractVersion contract_version;
   string ingress_identity;
   string payload_digest;
   ulong publication_sequence;
   SWV5S5_IngressLifecycleState lifecycle_state;
   string logical_correlation_id;
   ulong reserved_request_sequence;
   datetime accepted_at;
   string bound_request_id;
   string terminal_disposition;
   ulong record_sequence;
   ulong record_revision;
   string record_digest;
};

struct SWV5S5_IngressLedgerObservation
{
   SWV5S5_IngressLedgerHeader header;
   bool identity_present;
   SWV5S5_IngressLedgerRecord existing_record;
};

struct SWV5S5_IngressLedgerProposal
{
   SWV5S5_IngressLedgerHeader expected_header;
   SWV5S5_IngressLedgerRecord proposed_record;
   ulong proposed_next_revision;
   string proposal_digest;
};

bool SWV5S5_DeriveLedgerRecordDigest(const SWV5S5_IngressLedgerRecord &record,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",record.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("ingress_identity",record.ingress_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("payload_digest",record.payload_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("publication_sequence",record.publication_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("lifecycle_state",record.lifecycle_state,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("logical_correlation_id",record.logical_correlation_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("reserved_request_sequence",record.reserved_request_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("accepted_at",record.accepted_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("bound_request_id",record.bound_request_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("terminal_disposition",record.terminal_disposition,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("record_sequence",record.record_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("record_revision",record.record_revision,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INGRESS_LEDGER,body,digest);
}

bool SWV5S5_DeriveLedgerProposalDigest(const SWV5S5_IngressLedgerProposal &proposal,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalString("expected_ledger_digest",proposal.expected_header.ledger_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expected_revision",proposal.expected_header.revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("record_digest",proposal.proposed_record.record_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("proposed_next_revision",proposal.proposed_next_revision,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INGRESS_LEDGER,body,digest);
}

bool SWV5S5_ValidLedgerLifecycle(const SWV5S5_IngressLedgerRecord &record)
{
   if(record.lifecycle_state<SWV5S5_REJECTED_NO_ENTRY ||
      record.lifecycle_state>SWV5S5_TERMINALLY_BLOCKED_TRUST_REVOKED) return false;
   if(record.lifecycle_state==SWV5S5_REJECTED_NO_ENTRY)
      return record.logical_correlation_id=="" && record.reserved_request_sequence==0 && record.bound_request_id=="";
   if(record.logical_correlation_id=="" || record.reserved_request_sequence==0 || record.accepted_at<=0) return false;
   if(record.lifecycle_state==SWV5S5_ACCEPTED_REQUEST_PENDING) return record.bound_request_id=="";
   if(record.lifecycle_state==SWV5S5_BOUND_TO_REQUEST || record.lifecycle_state==SWV5S5_TERMINALLY_PROCESSED)
      return record.bound_request_id!="";
   return record.lifecycle_state==SWV5S5_TERMINALLY_BLOCKED_TRUST_REVOKED && record.terminal_disposition!="";
}

SWV5S5_IngressEvaluationDisposition SWV5S5_EvaluateLedgerIngress(
   const SWV5S5_IngressLedgerObservation &observed,const string ingress_identity,
   const string payload_digest,const ulong publication_sequence)
{
   if(ingress_identity=="" || payload_digest=="" || publication_sequence==0 ||
      !SWV5S5_IsCandidateVersion(observed.header.contract_version)) return SWV5S5_INGRESS_EVALUATION_INVALID;
   if(observed.identity_present)
   {
      if(observed.existing_record.ingress_identity!=ingress_identity) return SWV5S5_INGRESS_EVALUATION_CONFLICT;
      return observed.existing_record.payload_digest==payload_digest ?
             SWV5S5_INGRESS_EVALUATION_DUPLICATE : SWV5S5_INGRESS_EVALUATION_CONFLICT;
   }
   if(publication_sequence<=observed.header.highest_accepted_publication_sequence)
      return SWV5S5_INGRESS_EVALUATION_REPLAY_RESOLVED;
   return SWV5S5_INGRESS_EVALUATION_NEW;
}

bool SWV5S5_ValidateLedgerProposal(const SWV5_ContractValidationContext &context,
                                   const SWV5S5_IngressLedgerObservation &observed,
                                   const SWV5S5_IngressLedgerProposal &proposal,
                                   SWV5S5_ValidationResult &result)
{
   string expected_record_digest,expected_proposal_digest;
   if(!SWV5S5_EqualNamespace(observed.header.persistence_namespace,proposal.expected_header.persistence_namespace) ||
      !SWV5S5_EqualFence(observed.header.ownership_fence,proposal.expected_header.ownership_fence) ||
      observed.header.revision!=proposal.expected_header.revision ||
      proposal.proposed_next_revision!=observed.header.revision+1 ||
      proposal.proposed_record.record_revision!=proposal.proposed_next_revision ||
      proposal.proposed_record.ingress_identity=="" || !SWV5S5_ValidLedgerLifecycle(proposal.proposed_record) ||
      !SWV5S5_DeriveLedgerRecordDigest(proposal.proposed_record,expected_record_digest) ||
      proposal.proposed_record.record_digest!=expected_record_digest ||
      !SWV5S5_DeriveLedgerProposalDigest(proposal,expected_proposal_digest) ||
      proposal.proposal_digest!=expected_proposal_digest)
   { SWV5S5_Deny(context,"LEDGER_PROPOSAL_DENIED","",result); return false; }
   SWV5S5_Allow(context,"LEDGER_PROPOSAL_VALID",result); return true;
}

class ISWV5S5IngressLedgerContract
{
public:
   virtual bool ProposeAcceptance(const SWV5_ContractValidationContext &context,
                                  const SWV5S5_IngressLedgerObservation &observed,
                                  const SWV5S5_IngressLedgerRecord &candidate,
                                  SWV5S5_IngressLedgerProposal &proposal,
                                  SWV5S5_ValidationResult &result)=0;
};

#endif
