#ifndef SW_V5_S5_REFERENCE_INGRESS_LEDGER_STORE_MQH
#define SW_V5_S5_REFERENCE_INGRESS_LEDGER_STORE_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
#include "SW_V5_S5_FakeTransactionalStore.mqh"

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
      string current_payload,current_scope,current_fence,expected_digest,proposal_expected;
      SWV5S5_ReferenceDomainRow current,row;
      if(!m_initialized || !m_store.Load(SWV5S5_REF_DOMAIN_LEDGER,current) ||
         !CanonicalState(m_header,m_index,m_records,current_payload,current_scope,current_fence) ||
         current.payload!=current_payload || expected_header.ledger_digest!=m_header.ledger_digest ||
         !SWV5S5_DeriveLedgerHeaderDigest(expected_header,expected_index,expected_digest) ||
         expected_digest!=m_header.ledger_digest ||
         proposal.expected_header.ledger_digest!=m_header.ledger_digest ||
         !SWV5S5_DeriveLedgerHeaderDigest(proposal.expected_header,expected_index,proposal_expected) ||
         proposal_expected!=proposal.expected_header.ledger_digest ||
         proposal.proposed_next_revision!=m_header.revision+1 ||
         !SWV5S5_ValidateLedgerRecordIndexLinkage(proposed_index,proposed_records) ||
         !BuildRow(proposal.expected_header,proposed_index,proposed_records,current.store_revision+1,row))
      { result.disposition=SWV5_DISPOSITION_DENY; result.reason_code="LEDGER_CAS_PRECONDITION"; return false; }
      if(!m_store.CompareAndSet(SWV5S5_REF_DOMAIN_LEDGER,current_scope,current.store_revision,current.payload_digest,current.authority_fence_digest,row,
                                SWV5S5_REF_FAULT_NONE,transaction)) { result.disposition=SWV5_DISPOSITION_DENY; result.reason_code="LEDGER_CAS_FAILED"; return false; }
      m_header=proposal.expected_header; m_header.revision=proposal.proposed_next_revision; m_header.ledger_digest="";
      ArrayResize(m_index,ArraySize(proposed_index)); ArrayResize(m_records,ArraySize(proposed_records));
      for(int i=0;i<ArraySize(proposed_index);i++) m_index[i]=proposed_index[i];
      for(int j=0;j<ArraySize(proposed_records);j++) m_records[j]=proposed_records[j];
      if(!SWV5S5_DeriveLedgerHeaderDigest(m_header,m_index,m_header.ledger_digest)) { result.disposition=SWV5_DISPOSITION_DENY; result.reason_code="LEDGER_READBACK_FAILED"; return false; }
      result.disposition=SWV5_DISPOSITION_ALLOW; result.reason_code="LEDGER_COMMITTED"; return true;
   }

   bool Validate(void) const
   {
      string p,s,f; return m_initialized && CanonicalState(m_header,m_index,m_records,p,s,f);
   }
   int Count(void) const { return ArraySize(m_records); }
   int IndexCount(void) const { return ArraySize(m_index); }
   ulong Revision(void) const { return m_header.revision; }
   ulong CompactionGeneration(void) const { return m_header.compaction_generation; }
   void InjectCorruption(void) { m_header.ledger_digest="CORRUPT"; }
};

#endif
