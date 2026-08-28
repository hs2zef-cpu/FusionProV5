#ifndef SW_V5_S5_REFERENCE_INGRESS_LEDGER_STORE_MQH
#define SW_V5_S5_REFERENCE_INGRESS_LEDGER_STORE_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS

#include "SW_V5_S5_FakeTransactionalStore.mqh"

struct SWV5S5_ReferenceLedgerRecord
{
   string ingress_id;
   string payload_digest;
   string correlation_id;
   ulong request_sequence;
   datetime accepted_at;
   ulong record_sequence;
   string record_digest;
};

struct SWV5S5_ReferenceLedgerIndexEntry
{
   string ingress_id;
   string payload_digest;
   string correlation_id;
   ulong request_sequence;
   datetime accepted_at;
   ulong record_sequence;
   string record_digest;
   string index_digest;
};

class SWV5S5_ReferenceIngressLedgerStore
{
private:
   SWV5S5_ReferenceLedgerRecord m_records[];
   SWV5S5_ReferenceLedgerIndexEntry m_index[];
   ulong m_revision;
   ulong m_publication_hwm;
   ulong m_compaction_generation;
   bool m_corrupt;

public:
   SWV5S5_ReferenceIngressLedgerStore(void):m_revision(1),m_publication_hwm(0),m_compaction_generation(0),m_corrupt(false) {}

   bool Validate(void) const
   {
      if(m_corrupt || ArraySize(m_records)!=ArraySize(m_index))
         return false;
      for(int i=0;i<ArraySize(m_records);i++)
      {
         string record_digest=SWV5S5_ReferenceDigest("LEDGER-RECORD",
            m_records[i].ingress_id+"|"+m_records[i].payload_digest+"|"+
            m_records[i].correlation_id+"|"+(string)m_records[i].request_sequence);
         string index_digest=SWV5S5_ReferenceDigest("LEDGER-INDEX",
            m_index[i].ingress_id+"|"+m_index[i].payload_digest+"|"+
            m_index[i].correlation_id+"|"+(string)m_index[i].request_sequence+"|"+
            (string)m_index[i].accepted_at+"|"+(string)m_index[i].record_sequence+"|"+
            m_index[i].record_digest);
         if(record_digest!=m_records[i].record_digest || index_digest!=m_index[i].index_digest ||
            m_index[i].ingress_id!=m_records[i].ingress_id ||
            m_index[i].payload_digest!=m_records[i].payload_digest ||
            m_index[i].correlation_id!=m_records[i].correlation_id ||
            m_index[i].request_sequence!=m_records[i].request_sequence ||
            m_index[i].accepted_at!=m_records[i].accepted_at ||
            m_index[i].record_sequence!=m_records[i].record_sequence ||
            m_index[i].record_digest!=m_records[i].record_digest)
            return false;
      }
      return true;
   }

   bool Accept(const string ingress_id,const string payload_digest,
               const string correlation_id,const ulong request_sequence,
               const ulong publication_sequence,const datetime accepted_at,
               const ulong expected_revision,bool &idempotent)
   {
      idempotent=false;
      if(!Validate() || ingress_id=="" || payload_digest=="" || correlation_id=="" ||
         request_sequence==0 || accepted_at<=0)
         return false;
      for(int i=0;i<ArraySize(m_records);i++)
         if(m_records[i].ingress_id==ingress_id)
         {
            idempotent=(m_records[i].payload_digest==payload_digest &&
                        m_records[i].correlation_id==correlation_id &&
                        m_records[i].request_sequence==request_sequence);
            return idempotent;
         }
      if(expected_revision!=m_revision || publication_sequence<=m_publication_hwm)
         return false;
      int n=ArraySize(m_records);
      ArrayResize(m_records,n+1);
      m_records[n].ingress_id=ingress_id;
      m_records[n].payload_digest=payload_digest;
      m_records[n].correlation_id=correlation_id;
      m_records[n].request_sequence=request_sequence;
      m_records[n].accepted_at=accepted_at;
      m_records[n].record_sequence=(ulong)n+1;
      m_records[n].record_digest=SWV5S5_ReferenceDigest("LEDGER-RECORD",
         ingress_id+"|"+payload_digest+"|"+correlation_id+"|"+(string)request_sequence);
      ArrayResize(m_index,n+1);
      m_index[n].ingress_id=ingress_id;
      m_index[n].payload_digest=payload_digest;
      m_index[n].correlation_id=correlation_id;
      m_index[n].request_sequence=request_sequence;
      m_index[n].accepted_at=accepted_at;
      m_index[n].record_sequence=(ulong)n+1;
      m_index[n].record_digest=m_records[n].record_digest;
      m_index[n].index_digest=SWV5S5_ReferenceDigest("LEDGER-INDEX",
         ingress_id+"|"+payload_digest+"|"+correlation_id+"|"+(string)request_sequence+"|"+
         (string)accepted_at+"|"+(string)(n+1)+"|"+m_records[n].record_digest);
      m_publication_hwm=publication_sequence;
      m_revision++;
      return true;
   }

   bool Compact(const ulong expected_revision)
   {
      if(!Validate() || expected_revision!=m_revision)
         return false;
      m_revision++;
      m_compaction_generation++;
      return true;
   }

   void InjectCorruption(void) { m_corrupt=true; }
   int Count(void) const { return ArraySize(m_records); }
   int IndexCount(void) const { return ArraySize(m_index); }
   ulong Revision(void) const { return m_revision; }
   ulong CompactionGeneration(void) const { return m_compaction_generation; }
};

#endif
