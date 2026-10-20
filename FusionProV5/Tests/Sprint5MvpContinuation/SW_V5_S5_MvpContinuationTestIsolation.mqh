#ifndef SW_V5_S5_MVP_CONTINUATION_TEST_ISOLATION_MQH
#define SW_V5_S5_MVP_CONTINUATION_TEST_ISOLATION_MQH
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER MUTATION.
// Included BEFORE the native PREFLIGHT host. Removes native transport from
// the test binary at preprocessing time; any accidental dispatch is a FAIL.
uint test_forbidden_transport_calls=0;
bool test_live_native_copy_armed=false;
bool FUSION_TEST_ONLY_FORBIDDEN_SEND(MqlTradeRequest &request,MqlTradeResult &result)
{
   test_forbidden_transport_calls++;ZeroMemory(result);result.retcode=TRADE_RETCODE_ERROR;
   Print("CONTINUATION_FATAL|FORBIDDEN_TRANSPORT_DISPATCH|FAIL");return false;
}
#define OrderSend FUSION_TEST_ONLY_FORBIDDEN_SEND
#define OrderSendAsync FUSION_TEST_ONLY_FORBIDDEN_SEND
bool SWV5S5_TestContinuationFileSha(const string path,string &digest)
{
   digest="";const int h=FileOpen(path,FILE_READ|FILE_BIN|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h==INVALID_HANDLE)return false;
   const ulong size=FileSize(h);if(size==0 || size>16777216){FileClose(h);return false;}
   uchar bytes[];ArrayResize(bytes,(int)size);const uint read=FileReadArray(h,bytes);FileClose(h);
   if(read!=(uint)size)return false;
   // Contract SHA-256, not string/UTF-8 conversion of binary data.
   return SWV5S5_SHA256Bytes(bytes,digest);
}
#endif
