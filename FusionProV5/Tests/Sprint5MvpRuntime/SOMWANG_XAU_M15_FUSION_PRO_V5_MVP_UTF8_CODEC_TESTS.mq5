#property strict
#property tester_no_cache

// REAL MQL TEST ONLY / NOT FOR TRADING / NO BROKER MUTATION.

#include "SW_V5_S5_MvpRuntimeAssertions.mqh"

bool SWV5S5_MvpCodecStringRoundTrip(const string value)
{
   string encoded,decoded;
   SWV5S5_MvpCodecReader reader;
   if(!SWV5S5_CanonicalString("utf",value,encoded)) return false;
   reader.Init(encoded);
   return reader.ReadString("utf",decoded) && reader.AtEnd() && decoded==value;
}

bool SWV5S5_MvpCodecStringRejects(const string encoded)
{
   string decoded;
   SWV5S5_MvpCodecReader reader;
   reader.Init(encoded);
   return !reader.ReadString("utf",decoded) || !reader.AtEnd();
}

void SWV5S5_RunMvpUtf8CodecAssertions(SWV5S5_MvpTestCollector &c)
{
   SWV5S5_MvpRecord(c,"UTF8-ASCII-ROUNDTRIP",SWV5S5_MvpCodecStringRoundTrip("ASCII"));
   SWV5S5_MvpRecord(c,"UTF8-THAI-ROUNDTRIP",SWV5S5_MvpCodecStringRoundTrip("ทดสอบ"));
   SWV5S5_MvpRecord(c,"UTF8-MIXED-ROUNDTRIP",SWV5S5_MvpCodecStringRoundTrip("MVP-ทดสอบ-5"));
   SWV5S5_MvpRecord(c,"UTF8-MULTIBYTE-ROUNDTRIP",SWV5S5_MvpCodecStringRoundTrip("café"));
   SWV5S5_MvpRecord(c,"UTF8-EMPTY-ROUNDTRIP",SWV5S5_MvpCodecStringRoundTrip(""));
   SWV5S5_MvpRecord(c,"UTF8-DECLARED-TOO-SHORT-REJECTED",SWV5S5_MvpCodecStringRejects("utf:s:2:ก"));
   SWV5S5_MvpRecord(c,"UTF8-DECLARED-TOO-LONG-REJECTED",SWV5S5_MvpCodecStringRejects("utf:s:4:ก"));
   SWV5S5_MvpRecord(c,"UTF8-MID-CODEPOINT-REJECTED",SWV5S5_MvpCodecStringRejects("utf:s:1:ก"));
   SWV5S5_MvpRecord(c,"UTF8-MALFORMED-SEQUENCE-REJECTED",SWV5S5_MvpCodecStringRejects("utf:s:1:é"));
   SWV5S5_MvpRecord(c,"UTF8-TRAILING-DATA-REJECTED",SWV5S5_MvpCodecStringRejects("utf:s:3:กX"));
}

int OnInit(void)
{
   SWV5S5_MvpTestCollector collector;
   ZeroMemory(collector); collector.signature=1469598103934665603;
   SWV5S5_RunMvpUtf8CodecAssertions(collector);
   Print("MVP_UTF8_CODEC_SUMMARY|total=",collector.total,"|passed=",collector.passed,
      "|failed=",collector.failed,"|skipped=0|signature=",collector.signature,
      "|broker_submission_calls=0");
   ExpertRemove();
   return (collector.failed==0 ? INIT_SUCCEEDED : INIT_FAILED);
}

void OnTick(void) {}
