#ifndef SW_V5_S5_FAKE_TRANSACTIONAL_STORE_MQH
#define SW_V5_S5_FAKE_TRANSACTIONAL_STORE_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS

#include "SW_V5_S5_ReferenceStoreCommon.mqh"

class SWV5S5_FakeTransactionalStore
{
private:
   SWV5S5_ReferenceDomainRow m_rows[];
   SWV5S5_ReferenceTraceEntry m_trace[];
   ulong m_transaction_sequence;

   int FindRow(const SWV5S5_ReferenceDomain domain) const
   {
      for(int i=0;i<ArraySize(m_rows);i++)
         if(m_rows[i].domain==domain)
            return i;
      return -1;
   }

   void Trace(const string transaction_id,const SWV5S5_ReferenceDomain domain,
              const string step,const ulong expected_revision,
              const ulong durable_revision,
              const SWV5S5_ReferenceTransactionDisposition disposition)
   {
      int n=ArraySize(m_trace);
      ArrayResize(m_trace,n+1);
      m_trace[n].transaction_id=transaction_id;
      m_trace[n].domain=domain;
      m_trace[n].step=step;
      m_trace[n].expected_revision=expected_revision;
      m_trace[n].durable_revision=durable_revision;
      m_trace[n].disposition=disposition;
   }

public:
   SWV5S5_FakeTransactionalStore(void):m_transaction_sequence(0) {}

   bool Seed(const SWV5S5_ReferenceDomainRow &row)
   {
      if(FindRow(row.domain)>=0 || !SWV5S5_ReferenceRowIntegrity(row))
         return false;
      int n=ArraySize(m_rows);
      ArrayResize(m_rows,n+1);
      m_rows[n]=row;
      return true;
   }

   bool Load(const SWV5S5_ReferenceDomain domain,SWV5S5_ReferenceDomainRow &row) const
   {
      int index=FindRow(domain);
      if(index<0)
         return false;
      row=m_rows[index];
      return SWV5S5_ReferenceRowIntegrity(row);
   }

   bool CompareAndSet(const SWV5S5_ReferenceDomain domain,
                      const string expected_namespace_digest,
                      const ulong expected_revision,
                      const string expected_payload_digest,
                      const string expected_fence_digest,
                      const SWV5S5_ReferenceDomainRow &proposed,
                      const SWV5S5_ReferenceFaultPoint fault,
                      SWV5S5_ReferenceTransactionResult &result)
   {
      ZeroMemory(result);
      result.domain=domain;
      result.expected_revision=expected_revision;
      result.transaction_id="REF-TXN-"+(string)(++m_transaction_sequence);
      int index=FindRow(domain);
      if(index<0 || !SWV5S5_ReferenceRowIntegrity(m_rows[index]))
      {
         result.disposition=SWV5S5_REF_CORRUPT_STATE;
         result.diagnostic="MISSING_OR_CORRUPT_DOMAIN";
         Trace(result.transaction_id,domain,"SNAPSHOT",expected_revision,0,result.disposition);
         return false;
      }
      result.durable_revision=m_rows[index].store_revision;
      if(fault==SWV5S5_REF_FAULT_AFTER_SNAPSHOT ||
         fault==SWV5S5_REF_FAULT_BEFORE_EXPECTED_COMPARE ||
         fault==SWV5S5_REF_FAULT_BEFORE_MUTATION)
      {
         result.disposition=SWV5S5_REF_CRASH_BEFORE_MUTATION;
         result.diagnostic="CRASH_BEFORE_MUTATION";
         Trace(result.transaction_id,domain,"PRE_MUTATION_CRASH",expected_revision,result.durable_revision,result.disposition);
         return false;
      }
      if(m_rows[index].domain!=domain ||
         m_rows[index].persistence_namespace_digest!=expected_namespace_digest ||
         m_rows[index].store_revision!=expected_revision ||
         m_rows[index].payload_digest!=expected_payload_digest ||
         m_rows[index].authority_fence_digest!=expected_fence_digest)
      {
         result.disposition=SWV5S5_REF_EXPECTED_STATE_MISMATCH;
         result.diagnostic="EXACT_EXPECTED_CURRENT_MISMATCH";
         Trace(result.transaction_id,domain,"EXPECTED_COMPARE",expected_revision,result.durable_revision,result.disposition);
         return false;
      }
      if(proposed.domain!=domain || proposed.store_revision!=expected_revision+1 ||
         proposed.persistence_namespace_digest!=expected_namespace_digest ||
         proposed.authority_fence_digest=="" ||
         !SWV5S5_ReferenceRowIntegrity(proposed))
      {
         result.disposition=SWV5S5_REF_CONFLICT;
         result.diagnostic="PROPOSED_STATE_INVALID";
         return false;
      }
      if(fault==SWV5S5_REF_FAULT_AFTER_EXPECTED_VALIDATION ||
         fault==SWV5S5_REF_FAULT_AFTER_STAGED_MUTATION ||
         fault==SWV5S5_REF_FAULT_BEFORE_COMMIT)
      {
         result.disposition=SWV5S5_REF_CRASH_DURING_TRANSACTION;
         result.diagnostic="STAGED_MUTATION_ROLLED_BACK";
         Trace(result.transaction_id,domain,"ROLLBACK",expected_revision,result.durable_revision,result.disposition);
         return false;
      }
      m_rows[index]=proposed;
      result.durable_revision=proposed.store_revision;
      result.durable_payload_digest=proposed.payload_digest;
      result.durable_state_matches_proposal=true;
      if(fault==SWV5S5_REF_FAULT_AFTER_DURABLE_COMMIT)
      {
         result.disposition=SWV5S5_REF_COMMIT_OUTCOME_UNCERTAIN;
         result.this_transaction_won=false;
         result.diagnostic="DURABLE_COMMIT_CALLER_DID_NOT_OBSERVE";
         Trace(result.transaction_id,domain,"COMMIT_UNCERTAIN",expected_revision,result.durable_revision,result.disposition);
         return false;
      }
      if(fault==SWV5S5_REF_FAULT_BEFORE_READBACK)
      {
         result.disposition=SWV5S5_REF_READBACK_MISMATCH;
         result.this_transaction_won=false;
         result.diagnostic="READBACK_NOT_OBSERVED";
         return false;
      }
      result.disposition=SWV5S5_REF_COMMITTED;
      result.this_transaction_won=true;
      result.diagnostic="THIS_TRANSACTION_WON";
      Trace(result.transaction_id,domain,"COMMIT_READBACK",expected_revision,result.durable_revision,result.disposition);
      return true;
   }

   int TraceCount(void) const { return ArraySize(m_trace); }

   bool InjectStoredPayloadWithoutDigest(const SWV5S5_ReferenceDomain domain,const string payload)
   {
      int index=FindRow(domain);
      if(index<0) return false;
      m_rows[index].payload=payload;
      return true;
   }
};

#endif
