#ifndef SW_V5_S5_MVP_RESUME_CLOCK_DIAGNOSTIC_GATE_MQH
#define SW_V5_S5_MVP_RESUME_CLOCK_DIAGNOSTIC_GATE_MQH
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS OR AUTHORITY GRANT.
// Pure gate. No file access or writes. Shared by native harness and source-
// extracted, non-native refusal tests; not a substitute for MQL execution.
bool ResumeClockDiagnosticInputsValid(const string marker,const string target,const string run_id)
{
   if(marker!="TEST_ONLY_RESUME_CLOCK_DIAGNOSTIC_NO_EXECUTION")return false;
   if(StringLen(run_id)!=32)return false;
   for(int p=0;p<32;p++)
   {
      const int c=(int)StringGetCharacter(run_id,p);
      if(!((c>=48 && c<=57) || (c>=97 && c<=102)))return false;
   }
   if(target=="fusion_v5_mvp_demo_authority.sqlite")return false;
   if(StringFind(target,"..")>=0 || StringFind(target,"/")>=0 ||
      StringFind(target,"\\")>=0 || StringFind(target,":")>=0)return false;
   return target=="TEST_ONLY_MVP_RESUME_CLOCK_DIAGNOSTIC_"+run_id+".sqlite";
}
#endif
