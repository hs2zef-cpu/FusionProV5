#ifndef SW_V5_S5_REFERENCE_SEQUENCE_STORE_MQH
#define SW_V5_S5_REFERENCE_SEQUENCE_STORE_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS

#include "SW_V5_S5_FakeTransactionalStore.mqh"

struct SWV5S5_ReferenceSequenceEntry
{
   string correlation_id;
   ulong request_sequence;
   string binding_digest;
};

class SWV5S5_ReferenceSequenceStore
{
private:
   SWV5S5_ReferenceSequenceEntry m_entries[];
   ulong m_revision;
   ulong m_hwm;
   bool m_corrupt;

public:
   SWV5S5_ReferenceSequenceStore(void):m_revision(1),m_hwm(0),m_corrupt(false) {}

   bool Reserve(const string correlation_id,const string binding_digest,
                const ulong expected_revision,ulong &sequence,bool &existing)
   {
      existing=false;
      sequence=0;
      if(m_corrupt || correlation_id=="" || binding_digest=="")
         return false;
      for(int i=0;i<ArraySize(m_entries);i++)
         if(m_entries[i].correlation_id==correlation_id)
         {
            if(m_entries[i].binding_digest!=binding_digest)
               return false;
            sequence=m_entries[i].request_sequence;
            existing=true;
            return true;
         }
      if(expected_revision!=m_revision || m_hwm==18446744073709551615)
         return false;
      sequence=m_hwm+1;
      int n=ArraySize(m_entries);
      ArrayResize(m_entries,n+1);
      m_entries[n].correlation_id=correlation_id;
      m_entries[n].request_sequence=sequence;
      m_entries[n].binding_digest=binding_digest;
      m_hwm=sequence;
      m_revision++;
      return true;
   }

   void InjectCorruption(void) { m_corrupt=true; }
   ulong Revision(void) const { return m_revision; }
   ulong HighWatermark(void) const { return m_hwm; }
   int Count(void) const { return ArraySize(m_entries); }
};

#endif
