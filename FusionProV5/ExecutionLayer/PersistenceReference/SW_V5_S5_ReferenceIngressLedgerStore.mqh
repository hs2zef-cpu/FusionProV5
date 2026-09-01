#ifndef SW_V5_S5_REFERENCE_INGRESS_LEDGER_STORE_MQH
#define SW_V5_S5_REFERENCE_INGRESS_LEDGER_STORE_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
#include "SW_V5_S5_FakeTransactionalStore.mqh"

bool SWV5S5_ReferenceLedgerProposalDigest(const SWV5S5_IngressLedgerProposal &proposal,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalString("expected_ledger_digest",proposal.expected_header.ledger_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("proposed_record_digest",proposal.proposed_record.record_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("proposed_next_revision",proposal.proposed_next_revision,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INGRESS_LEDGER,body,digest);
}

class SWV5S5_ReferenceIngressLedgerStore
{
private:
   SWV5S5_FakeTransactionalStore m_store;
   SWV5S5_IngressLedgerHeader m_header;
   SWV5S5_IngressLedgerIndexEntry m_index[];
   SWV5S5_IngressLedgerRecord m_records[];
   bool m_initialized;

   bool CanonicalState(const SWV5S5_IngressLedgerHeader &header,
                       const SWV5S5_IngressLedgerIndexEntry &index[],
                       const SWV5S5_IngressLedgerRecord &records[],string &payload,
                       string &scope,string &fence) const
   {
      string hd,id,link,ns,fn,f;
      if(!SWV5S5_DeriveLedgerHeaderDigest(header,index,hd) || header.ledger_digest!=hd ||
         !SWV5S5_DeriveLedgerIndexDigest(index,id) || header.membership_binding_index_digest!=id ||
         !SWV5S5_ValidateLedgerRecordIndexLinkage(index,records) ||
         !SWV5S5_ReferenceCanonicalNamespaceDigest(header.persistence_namespace,scope) ||
         !SWV5S5_ReferenceCanonicalFenceDigest(header.ownership_fence,fence) ||
         !SWV5S5_CanonicalString("header_digest",hd,f)) return false;
      payload=f+id;
      for(int i=0;i<ArraySize(records);i++)
      {
         if(!SWV5S5_CanonicalString("record_digest",records[i].record_digest,f)) return false;
         payload+=f;
      }
      return true;
   }

   bool BuildRow(const SWV5S5_IngressLedgerHeader &header,const SWV5S5_IngressLedgerIndexEntry &index[],
                 const SWV5S5_IngressLedgerRecord &records[],const ulong revision,SWV5S5_ReferenceDomainRow &row) const
   {
      string payload,scope,fence,digest;
      if(!CanonicalState(header,index,records,payload,scope,fence) ||
         !SWV5S5_ReferenceCanonicalPayloadDigest(SWV5S5_REF_DOMAIN_LEDGER,payload,digest)) return false;
      ZeroMemory(row); row.domain=SWV5S5_REF_DOMAIN_LEDGER; row.persistence_namespace_digest=scope;
      row.store_revision=revision; row.authority_fence_digest=fence; row.payload=payload; row.payload_digest=digest; return true;
   }

   bool ExactRecords(const SWV5S5_IngressLedgerRecord &a[],const SWV5S5_IngressLedgerRecord &b[]) const
   {
      if(ArraySize(a)!=ArraySize(b)) return false;
      for(int i=0;i<ArraySize(a);i++)
      {
         string da,db;
         if(!SWV5S5_DeriveLedgerRecordDigest(a[i],da) || a[i].record_digest!=da ||
            !SWV5S5_DeriveLedgerRecordDigest(b[i],db) || b[i].record_digest!=db || da!=db) return false;
      }
      return true;
   }

public:
   SWV5S5_ReferenceIngressLedgerStore(void):m_initialized(false) { ZeroMemory(m_header); }

   bool Initialize(const SWV5S5_IngressLedgerHeader &header,
                   const SWV5S5_IngressLedgerIndexEntry &index[],
                   const SWV5S5_IngressLedgerRecord &records[])
   {
      if(m_initialized) return false; SWV5S5_ReferenceDomainRow row;
      if(!BuildRow(header,index,records,1,row) || !m_store.Seed(row)) return false;
      m_header=header; ArrayResize(m_index,ArraySize(index)); ArrayResize(m_records,ArraySize(records));
      for(int i=0;i<ArraySize(index);i++) m_index[i]=index[i];
      for(int j=0;j<ArraySize(records);j++) m_records[j]=records[j];
      m_initialized=true; return true;
   }

   bool TryCommitAcceptance(const SWV5S5_IngressLedgerHeader &expected_header,
                            const SWV5S5_IngressLedgerIndexEntry &expected_index[],
                            const SWV5S5_IngressLedgerRecord &expected_records[],
                            const SWV5S5_IngressLedgerProposal &proposal,
                            const SWV5S5_IngressLedgerIndexEntry &proposed_index[],
                            const SWV5S5_IngressLedgerRecord &proposed_records[],
                            SWV5S5_ValidationResult &result,SWV5S5_ReferenceTransactionResult &transaction)
   {
      ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
      string current_payload,current_scope,current_fence,expected_payload,expected_scope,expected_fence;
      string proposal_expected,index_digest;
      SWV5S5_ReferenceDomainRow current,row,readback;
      SWV5S5_IngressLedgerHeader proposed_header=m_header;
      proposed_header.previous_revision=m_header.revision;
      proposed_header.revision=proposal.proposed_next_revision;
      proposed_header.membership_count=(uint)ArraySize(proposed_index);
      ulong highest=0;
      for(int h=0;h<ArraySize(proposed_index);h++)
         if(proposed_index[h].publication_sequence>highest) highest=proposed_index[h].publication_sequence;
      proposed_header.highest_accepted_publication_sequence=highest;
      proposed_header.membership_binding_index_digest=""; proposed_header.ledger_digest="";
      if(!m_initialized || !m_store.Load(SWV5S5_REF_DOMAIN_LEDGER,current) ||
         !CanonicalState(m_header,m_index,m_records,current_payload,current_scope,current_fence) ||
         current.payload!=current_payload || current.persistence_namespace_digest!=current_scope ||
         current.authority_fence_digest!=current_fence ||
         !CanonicalState(expected_header,expected_index,expected_records,expected_payload,expected_scope,expected_fence) ||
         expected_payload!=current_payload || expected_scope!=current_scope || expected_fence!=current_fence ||
         !ExactRecords(expected_records,m_records) ||
         !CanonicalState(proposal.expected_header,expected_index,expected_records,expected_payload,expected_scope,expected_fence) ||
         expected_payload!=current_payload ||
         proposal.proposed_next_revision!=m_header.revision+1 ||
         ArraySize(proposed_records)!=ArraySize(m_records)+1 || ArraySize(proposed_index)!=ArraySize(m_index)+1 ||
         !SWV5S5_ValidateLedgerRecordIndexLinkage(proposed_index,proposed_records) ||
         !SWV5S5_DeriveLedgerRecordDigest(proposal.proposed_record,proposal_expected) ||
         proposal.proposed_record.record_digest!=proposal_expected ||
         proposed_records[ArraySize(proposed_records)-1].record_digest!=proposal.proposed_record.record_digest ||
         !SWV5S5_ReferenceLedgerProposalDigest(proposal,proposal_expected) || proposal.proposal_digest!=proposal_expected ||
         !SWV5S5_DeriveLedgerIndexDigest(proposed_index,index_digest))
      { result.disposition=SWV5_DISPOSITION_DENY; result.reason_code="LEDGER_CAS_PRECONDITION"; return false; }
      for(int p=0;p<ArraySize(m_records);p++)
         if(proposed_records[p].record_digest!=m_records[p].record_digest || proposed_index[p].record_digest!=m_index[p].record_digest)
         { result.disposition=SWV5_DISPOSITION_DENY; result.reason_code="LEDGER_PREFIX_CHANGED"; return false; }
      proposed_header.membership_binding_index_digest=index_digest;
      if(!SWV5S5_DeriveLedgerHeaderDigest(proposed_header,proposed_index,proposed_header.ledger_digest) ||
         !BuildRow(proposed_header,proposed_index,proposed_records,current.store_revision+1,row))
      { result.disposition=SWV5_DISPOSITION_DENY; result.reason_code="LEDGER_PROPOSED_STATE_INVALID"; return false; }
      if(!m_store.CompareAndSet(SWV5S5_REF_DOMAIN_LEDGER,current_scope,current.store_revision,current.payload_digest,current.authority_fence_digest,row,
                                SWV5S5_REF_FAULT_NONE,transaction)) { result.disposition=SWV5_DISPOSITION_DENY; result.reason_code="LEDGER_CAS_FAILED"; return false; }
      m_header=proposed_header;
      ArrayResize(m_index,ArraySize(proposed_index)); ArrayResize(m_records,ArraySize(proposed_records));
      for(int i=0;i<ArraySize(proposed_index);i++) m_index[i]=proposed_index[i];
      for(int j=0;j<ArraySize(proposed_records);j++) m_records[j]=proposed_records[j];
      if(!m_store.Load(SWV5S5_REF_DOMAIN_LEDGER,readback) || readback.payload!=row.payload ||
         readback.payload_digest!=row.payload_digest || !Validate())
      { result.disposition=SWV5_DISPOSITION_DENY; result.reason_code="LEDGER_READBACK_FAILED"; return false; }
      result.disposition=SWV5_DISPOSITION_ALLOW; result.reason_code="LEDGER_COMMITTED"; return true;
   }

   bool TryCompact(const SWV5S5_IngressLedgerCompactionProposal &proposal,
                   const SWV5S5_IngressLedgerIndexEntry &after_index[],
                   const SWV5S5_IngressLedgerRecord &after_records[],
                   SWV5S5_ReferenceTransactionResult &transaction)
   {
      if(!m_initialized || !SWV5S5_ValidateLedgerCompaction(m_header,m_index,m_records,
         proposal,after_index,after_records)) return false;
      SWV5S5_IngressLedgerHeader next=m_header;
      next.previous_revision=m_header.revision; next.revision=proposal.proposed_revision;
      next.compaction_generation=proposal.proposed_compaction_generation;
      next.membership_count=proposal.proposed_membership_count;
      next.membership_binding_index_digest=proposal.proposed_membership_digest;
      next.ledger_digest="";
      SWV5S5_ReferenceDomainRow current,row,readback; string payload,scope,fence;
      if(!SWV5S5_DeriveLedgerHeaderDigest(next,after_index,next.ledger_digest) ||
         !m_store.Load(SWV5S5_REF_DOMAIN_LEDGER,current) ||
         !CanonicalState(m_header,m_index,m_records,payload,scope,fence) || current.payload!=payload ||
         !BuildRow(next,after_index,after_records,current.store_revision+1,row) ||
         !m_store.CompareAndSet(SWV5S5_REF_DOMAIN_LEDGER,scope,current.store_revision,current.payload_digest,
            current.authority_fence_digest,row,SWV5S5_REF_FAULT_NONE,transaction)) return false;
      m_header=next; ArrayResize(m_index,ArraySize(after_index)); ArrayResize(m_records,ArraySize(after_records));
      for(int i=0;i<ArraySize(after_index);i++) m_index[i]=after_index[i];
      for(int j=0;j<ArraySize(after_records);j++) m_records[j]=after_records[j];
      return m_store.Load(SWV5S5_REF_DOMAIN_LEDGER,readback) && readback.payload==row.payload && Validate();
   }

   bool Validate(void) const
   {
      string p,s,f; return m_initialized && CanonicalState(m_header,m_index,m_records,p,s,f);
   }
   int Count(void) const { return ArraySize(m_records); }
   int IndexCount(void) const { return ArraySize(m_index); }
   ulong Revision(void) const { return m_header.revision; }
   ulong CompactionGeneration(void) const { return m_header.compaction_generation; }
   bool Load(SWV5S5_IngressLedgerHeader &header,SWV5S5_IngressLedgerIndexEntry &index[],
             SWV5S5_IngressLedgerRecord &records[]) const
   {
      if(!Validate()) return false; header=m_header; ArrayResize(index,ArraySize(m_index)); ArrayResize(records,ArraySize(m_records));
      for(int i=0;i<ArraySize(m_index);i++) index[i]=m_index[i];
      for(int j=0;j<ArraySize(m_records);j++) records[j]=m_records[j];
      return true;
   }
   void InjectCorruption(void) { m_header.ledger_digest="CORRUPT"; }
};

#endif
