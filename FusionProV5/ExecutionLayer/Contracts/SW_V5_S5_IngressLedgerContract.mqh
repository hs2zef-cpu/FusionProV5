#ifndef SW_V5_S5_INGRESS_LEDGER_CONTRACT_MQH
#define SW_V5_S5_INGRESS_LEDGER_CONTRACT_MQH

// SPRINT 5 PHASE B.3 CANDIDATE CONTRACT
// EXPLICIT ORDERED MEMBERSHIP/BINDING INDEX / NO CAS OR PHYSICAL STORE

#include "SW_V5_S5_ProducerTrustContract.mqh"

struct SWV5S5_IngressLedgerIndexEntry
{
   string ingress_identity;
   ulong publication_sequence;
   string payload_digest;
   SWV5S5_IngressLifecycleState lifecycle_state;
   string logical_correlation_id;
   ulong reserved_request_sequence;
   datetime accepted_at;
   string bound_request_id;
   string terminal_trust_disposition;
   ulong record_sequence;
   ulong record_revision;
   string record_digest;
};

struct SWV5S5_IngressLedgerHeader
{
   SWV5_ContractVersion contract_version;
   string policy_id;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   string producer_authority_record_id;
   ulong producer_authority_generation;
   string producer_instance;
   ulong producer_epoch;
   ulong highest_accepted_publication_sequence;
   ulong revision;
   ulong previous_revision;
   ulong compaction_generation;
   uint membership_count;
   string membership_binding_index_digest;
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

struct SWV5S5_IngressLedgerObservation { SWV5S5_IngressLedgerHeader header; };

struct SWV5S5_IngressLedgerProposal
{
   SWV5S5_IngressLedgerHeader expected_header;
   SWV5S5_IngressLedgerRecord proposed_record;
   ulong proposed_next_revision;
   string proposal_digest;
};

struct SWV5S5_IngressLedgerCompactionProposal
{
   SWV5S5_IngressLedgerHeader expected_header;
   ulong proposed_compaction_generation;
   ulong proposed_revision;
   ulong preserved_high_watermark;
   uint proposed_membership_count;
   string proposed_membership_digest;
   string proposal_digest;
};

bool SWV5S5_ValidLedgerLifecycleValues(const SWV5S5_IngressLifecycleState state,
                                       const string correlation,const ulong reservation,
                                       const string request_id,const string terminal)
{
   if(state<SWV5S5_REJECTED_NO_ENTRY || state>SWV5S5_TERMINALLY_BLOCKED_TRUST_REVOKED) return false;
   if(state==SWV5S5_REJECTED_NO_ENTRY) return correlation=="" && reservation==0 && request_id=="";
   if(correlation=="" || reservation==0) return false;
   if(state==SWV5S5_ACCEPTED_REQUEST_PENDING) return request_id=="";
   if(state==SWV5S5_BOUND_TO_REQUEST || state==SWV5S5_TERMINALLY_PROCESSED) return request_id!="";
   return terminal!="";
}

bool SWV5S5_ValidLedgerLifecycle(const SWV5S5_IngressLedgerRecord &record)
{
   return record.accepted_at>0 && SWV5S5_ValidLedgerLifecycleValues(record.lifecycle_state,
      record.logical_correlation_id,record.reserved_request_sequence,record.bound_request_id,record.terminal_disposition);
}

bool SWV5S5_DeriveLedgerRecordDigest(const SWV5S5_IngressLedgerRecord &record,string &digest)
{
   string body="",f;
#define SWV5S5_LR_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define SWV5S5_LR_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define SWV5S5_LR_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("version",record.contract_version,f)) return false; body+=f;
   SWV5S5_LR_S("ingress_identity",record.ingress_identity); SWV5S5_LR_S("payload_digest",record.payload_digest);
   SWV5S5_LR_U("publication_sequence",record.publication_sequence); SWV5S5_LR_I("lifecycle_state",record.lifecycle_state);
   SWV5S5_LR_S("logical_correlation_id",record.logical_correlation_id); SWV5S5_LR_U("reserved_request_sequence",record.reserved_request_sequence);
   SWV5S5_LR_I("accepted_at",record.accepted_at); SWV5S5_LR_S("bound_request_id",record.bound_request_id);
   SWV5S5_LR_S("terminal_disposition",record.terminal_disposition); SWV5S5_LR_U("record_sequence",record.record_sequence);
   SWV5S5_LR_U("record_revision",record.record_revision);
#undef SWV5S5_LR_S
#undef SWV5S5_LR_U
#undef SWV5S5_LR_I
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INGRESS_LEDGER,body,digest);
}

bool SWV5S5_DeriveLedgerIndexDigest(const SWV5S5_IngressLedgerIndexEntry &entries[],string &digest)
{
   string body="",entry="",f;
   for(int i=0;i<ArraySize(entries);i++)
   {
      const SWV5S5_IngressLedgerIndexEntry e=entries[i]; entry="";
      if(e.ingress_identity=="" || e.publication_sequence==0 || e.accepted_at<=0 || !SWV5S5_IsDigest64Lower(e.payload_digest) ||
         !SWV5S5_ValidLedgerLifecycleValues(e.lifecycle_state,e.logical_correlation_id,e.reserved_request_sequence,
                                            e.bound_request_id,e.terminal_trust_disposition) ||
         (i>0 && StringCompare(entries[i-1].ingress_identity,e.ingress_identity)>=0)) return false;
      for(int j=i+1;j<ArraySize(entries);j++)
         if(entries[j].publication_sequence==e.publication_sequence ||
            entries[j].record_sequence==e.record_sequence || entries[j].record_revision==e.record_revision) return false;
#define SWV5S5_LI_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else entry+=f
#define SWV5S5_LI_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else entry+=f
#define SWV5S5_LI_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else entry+=f
      SWV5S5_LI_S("ingress_identity",e.ingress_identity); SWV5S5_LI_U("publication_sequence",e.publication_sequence);
      SWV5S5_LI_S("payload_digest",e.payload_digest); SWV5S5_LI_I("lifecycle_state",e.lifecycle_state);
      SWV5S5_LI_S("logical_correlation_id",e.logical_correlation_id); SWV5S5_LI_U("reserved_request_sequence",e.reserved_request_sequence);
      SWV5S5_LI_I("accepted_at",e.accepted_at);
      SWV5S5_LI_S("bound_request_id",e.bound_request_id); SWV5S5_LI_S("terminal_trust_disposition",e.terminal_trust_disposition);
      SWV5S5_LI_U("record_sequence",e.record_sequence); SWV5S5_LI_U("record_revision",e.record_revision);
      SWV5S5_LI_S("record_digest",e.record_digest);
#undef SWV5S5_LI_S
#undef SWV5S5_LI_U
#undef SWV5S5_LI_I
      if(!SWV5S5_CanonicalIndexed("membership",(ulong)i,entry,f)) return false; body+=f;
   }
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INGRESS_LEDGER,body,digest);
}

bool SWV5S5_ValidateLedgerRecordIndexLinkage(const SWV5S5_IngressLedgerIndexEntry &entries[],
                                             const SWV5S5_IngressLedgerRecord &records[])
{
   if(ArraySize(entries)!=ArraySize(records)) return false;
   for(int i=0;i<ArraySize(entries);i++)
   {
      string digest;
      const SWV5S5_IngressLedgerIndexEntry e=entries[i];
      const SWV5S5_IngressLedgerRecord r=records[i];
      if(!SWV5S5_IsCandidateVersion(r.contract_version) || !SWV5S5_ValidLedgerLifecycle(r) ||
         !SWV5S5_DeriveLedgerRecordDigest(r,digest) || r.record_digest!=digest ||
         e.ingress_identity!=r.ingress_identity || e.publication_sequence!=r.publication_sequence ||
         e.payload_digest!=r.payload_digest || e.lifecycle_state!=r.lifecycle_state ||
         e.logical_correlation_id!=r.logical_correlation_id ||
         e.reserved_request_sequence!=r.reserved_request_sequence || e.accepted_at!=r.accepted_at ||
         e.bound_request_id!=r.bound_request_id || e.terminal_trust_disposition!=r.terminal_disposition ||
         e.record_sequence!=r.record_sequence || e.record_revision!=r.record_revision ||
         e.record_digest!=r.record_digest || e.record_sequence==0 || e.record_revision==0) return false;
      for(int j=i+1;j<ArraySize(entries);j++)
         if(entries[j].record_sequence==e.record_sequence || entries[j].record_revision==e.record_revision) return false;
   }
   return true;
}

bool SWV5S5_DeriveLedgerHeaderDigest(const SWV5S5_IngressLedgerHeader &header,
                                     const SWV5S5_IngressLedgerIndexEntry &entries[],string &digest)
{
   string index_digest,body="",f;
   ulong highest=0;
   for(int i=0;i<ArraySize(entries);i++)
   {
      if(entries[i].publication_sequence>header.highest_accepted_publication_sequence) return false;
      if(entries[i].publication_sequence>highest) highest=entries[i].publication_sequence;
   }
   if(header.membership_count!=(uint)ArraySize(entries) || !SWV5S5_DeriveLedgerIndexDigest(entries,index_digest) ||
      header.membership_binding_index_digest!=index_digest ||
      (ArraySize(entries)==0 && header.highest_accepted_publication_sequence!=0) ||
      (ArraySize(entries)>0 && highest!=header.highest_accepted_publication_sequence) ||
      header.producer_authority_record_id=="" || header.producer_authority_generation==0 ||
      header.producer_instance=="" || header.producer_epoch==0 || header.revision==0) return false;
#define SWV5S5_LH_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define SWV5S5_LH_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("version",header.contract_version,f)) return false; body+=f;
   SWV5S5_LH_S("policy_id",header.policy_id); if(!SWV5S5_CanonicalNamespace("scope",header.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",header.ownership_fence,f)) return false; body+=f;
   SWV5S5_LH_S("producer_authority_record_id",header.producer_authority_record_id);
   SWV5S5_LH_U("producer_authority_generation",header.producer_authority_generation);
   SWV5S5_LH_S("producer_instance",header.producer_instance); SWV5S5_LH_U("producer_epoch",header.producer_epoch);
   SWV5S5_LH_U("highest_accepted_publication_sequence",header.highest_accepted_publication_sequence);
   SWV5S5_LH_U("revision",header.revision); SWV5S5_LH_U("previous_revision",header.previous_revision);
   SWV5S5_LH_U("compaction_generation",header.compaction_generation); SWV5S5_LH_U("membership_count",header.membership_count);
   SWV5S5_LH_S("membership_binding_index_digest",index_digest);
#undef SWV5S5_LH_S
#undef SWV5S5_LH_U
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INGRESS_LEDGER,body,digest);
}

int SWV5S5_FindLedgerMembership(const SWV5S5_IngressLedgerIndexEntry &entries[],const string identity)
{ for(int i=0;i<ArraySize(entries);i++) if(entries[i].ingress_identity==identity) return i; return -1; }

SWV5S5_IngressEvaluationDisposition SWV5S5_EvaluateLedgerIngress(
   const SWV5S5_IngressLedgerHeader &header,const SWV5S5_IngressLedgerIndexEntry &entries[],
   const SWV5S5_IngressLedgerRecord &records[],
   const string ingress_identity,const string payload_digest,const ulong publication_sequence)
{
   string expected;
   if(ingress_identity=="" || !SWV5S5_IsDigest64Lower(payload_digest) || publication_sequence==0 ||
      !SWV5S5_IsCandidateVersion(header.contract_version) ||
      !SWV5S5_DeriveLedgerHeaderDigest(header,entries,expected) || header.ledger_digest!=expected ||
      !SWV5S5_ValidateLedgerRecordIndexLinkage(entries,records))
      return SWV5S5_INGRESS_EVALUATION_INVALID;
   int found=SWV5S5_FindLedgerMembership(entries,ingress_identity);
   if(found>=0)
      return entries[found].payload_digest==payload_digest && entries[found].publication_sequence==publication_sequence ?
             SWV5S5_INGRESS_EVALUATION_DUPLICATE : SWV5S5_INGRESS_EVALUATION_CONFLICT;
   if(publication_sequence<=header.highest_accepted_publication_sequence) return SWV5S5_INGRESS_EVALUATION_DENIED;
   return SWV5S5_INGRESS_EVALUATION_NEW;
}

bool SWV5S5_DeriveLedgerCompactionProposalDigest(const SWV5S5_IngressLedgerCompactionProposal &proposal,
                                                  string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalString("expected_ledger_digest",proposal.expected_header.ledger_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("proposed_compaction_generation",proposal.proposed_compaction_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("proposed_revision",proposal.proposed_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("preserved_high_watermark",proposal.preserved_high_watermark,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("proposed_membership_digest",proposal.proposed_membership_digest,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INGRESS_LEDGER,body,digest);
}

bool SWV5S5_ValidateLedgerCompaction(const SWV5S5_IngressLedgerHeader &observed,
                                     const SWV5S5_IngressLedgerIndexEntry &before_entries[],
                                     const SWV5S5_IngressLedgerRecord &before_records[],
                                     const SWV5S5_IngressLedgerCompactionProposal &proposal,
                                     const SWV5S5_IngressLedgerIndexEntry &after_entries[],
                                     const SWV5S5_IngressLedgerRecord &after_records[])
{
   string observed_digest,after_digest,expected_proposal;
   if(!SWV5S5_DeriveLedgerHeaderDigest(observed,before_entries,observed_digest) || observed.ledger_digest!=observed_digest ||
      !SWV5S5_ValidateLedgerRecordIndexLinkage(before_entries,before_records) ||
      !SWV5S5_ValidateLedgerRecordIndexLinkage(after_entries,after_records) ||
      proposal.expected_header.ledger_digest!=observed.ledger_digest ||
      proposal.proposed_membership_count!=(uint)ArraySize(after_entries) ||
      proposal.proposed_membership_count!=(uint)ArraySize(before_entries) ||
      !SWV5S5_DeriveLedgerIndexDigest(after_entries,after_digest) || proposal.proposed_membership_digest!=after_digest ||
      after_digest!=observed.membership_binding_index_digest ||
      proposal.preserved_high_watermark!=observed.highest_accepted_publication_sequence ||
      observed.revision==18446744073709551615 || observed.compaction_generation==18446744073709551615 ||
      proposal.proposed_revision!=observed.revision+1 ||
      proposal.proposed_compaction_generation!=observed.compaction_generation+1) return false;
   for(int i=0;i<ArraySize(before_entries);i++)
   {
      if(before_entries[i].ingress_identity!=after_entries[i].ingress_identity ||
         before_entries[i].publication_sequence!=after_entries[i].publication_sequence ||
         before_entries[i].payload_digest!=after_entries[i].payload_digest ||
         before_entries[i].lifecycle_state!=after_entries[i].lifecycle_state ||
         before_entries[i].logical_correlation_id!=after_entries[i].logical_correlation_id ||
         before_entries[i].reserved_request_sequence!=after_entries[i].reserved_request_sequence ||
         before_entries[i].accepted_at!=after_entries[i].accepted_at ||
         before_entries[i].bound_request_id!=after_entries[i].bound_request_id ||
         before_entries[i].terminal_trust_disposition!=after_entries[i].terminal_trust_disposition ||
         before_entries[i].record_sequence!=after_entries[i].record_sequence ||
         before_entries[i].record_revision!=after_entries[i].record_revision ||
         before_entries[i].record_digest!=after_entries[i].record_digest) return false;
   }
   return SWV5S5_DeriveLedgerCompactionProposalDigest(proposal,expected_proposal) &&
          proposal.proposal_digest==expected_proposal;
}

class ISWV5S5IngressLedgerContract
{
public:
   virtual bool TryCommitAcceptance(const SWV5S5_IngressLedgerHeader &expected_header,
                                    const SWV5S5_IngressLedgerIndexEntry &expected_entries[],
                                    const SWV5S5_IngressLedgerRecord &expected_records[],
                                    const SWV5S5_IngressLedgerProposal &proposal,
                                    SWV5S5_ValidationResult &authoritative_result)=0;
};

#endif
