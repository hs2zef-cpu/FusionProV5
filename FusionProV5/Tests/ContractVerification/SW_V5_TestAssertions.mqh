//+------------------------------------------------------------------+
//| TEST ONLY                                                        |
//| NOT FOR PRODUCTION                                               |
//| NO BROKER ACCESS                                                 |
//+------------------------------------------------------------------+
#ifndef SW_V5_TEST_ASSERTIONS_MQH
#define SW_V5_TEST_ASSERTIONS_MQH

struct SWV5_TestRecord
{
   string id;
   string domain;
   bool   passed;
   bool   skipped;
   string expected;
   string actual;
   string detail;
};

ulong SWV5_TestHashAppend(ulong hash,const string value)
{
   ulong result=hash;
   const int length=StringLen(value);
   for(int index=0;index<length;index++)
   {
      result^=(ulong)StringGetCharacter(value,index);
      result*=1099511628211;
   }
   return result;
}

string SWV5_TestBoolText(const bool value)
{
   return value ? "true" : "false";
}

class SWV5_TestCollector
{
private:
   int              m_total;
   int              m_passed;
   int              m_failed;
   int              m_skipped;
   ulong            m_signature;
   SWV5_TestRecord  m_records[];

public:
   SWV5_TestCollector()
   {
      Reset();
   }

   void Reset()
   {
      m_total=0;
      m_passed=0;
      m_failed=0;
      m_skipped=0;
      m_signature=1469598103934665603;
      ArrayResize(m_records,0);
   }

   void Record(const string id,
               const string domain,
               const bool passed,
               const string expected,
               const string actual,
               const string detail="")
   {
      const int slot=ArraySize(m_records);
      ArrayResize(m_records,slot+1);
      m_records[slot].id=id;
      m_records[slot].domain=domain;
      m_records[slot].passed=passed;
      m_records[slot].skipped=false;
      m_records[slot].expected=expected;
      m_records[slot].actual=actual;
      m_records[slot].detail=detail;
      m_total++;
      if(passed)
         m_passed++;
      else
         m_failed++;
      m_signature=SWV5_TestHashAppend(m_signature,id+"|"+domain+"|"+SWV5_TestBoolText(passed)+"|"+expected+"|"+actual+"|"+detail);
      PrintFormat("SWV5_TEST id=%s domain=%s outcome=%s expected=%s actual=%s detail=%s",
                  id,domain,passed ? "PASS" : "FAIL",expected,actual,detail);
   }

   void Skip(const string id,const string domain,const string reason)
   {
      const int slot=ArraySize(m_records);
      ArrayResize(m_records,slot+1);
      m_records[slot].id=id;
      m_records[slot].domain=domain;
      m_records[slot].passed=false;
      m_records[slot].skipped=true;
      m_records[slot].expected="executed";
      m_records[slot].actual="skipped";
      m_records[slot].detail=reason;
      m_total++;
      m_skipped++;
      m_signature=SWV5_TestHashAppend(m_signature,id+"|"+domain+"|SKIP|"+reason);
   }

   int Total() const
   {
      return m_total;
   }

   int Passed() const
   {
      return m_passed;
   }

   int Failed() const
   {
      return m_failed;
   }

   int Skipped() const
   {
      return m_skipped;
   }

   ulong Signature() const
   {
      return m_signature;
   }

   bool AllPassed() const
   {
      return m_total>0 && m_failed==0 && m_skipped==0 && m_passed==m_total;
   }

   string SummaryJson(const bool deterministic) const
   {
      return StringFormat("{\"schema\":\"SWV5-CONTRACT-TEST-RESULT-V2\",\"contract_policy\":\"SWV5-PRODUCTION-V3\",\"implementation\":\"ISWV5-INTERFACE-LEVEL\",\"total\":%d,\"passed\":%d,\"failed\":%d,\"skipped\":%d,\"signature\":\"%I64u\",\"deterministic\":%s}",
                          m_total,m_passed,m_failed,m_skipped,m_signature,deterministic ? "true" : "false");
   }
};

#endif
