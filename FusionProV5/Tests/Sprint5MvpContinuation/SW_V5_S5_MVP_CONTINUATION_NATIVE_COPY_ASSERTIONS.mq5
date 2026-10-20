#property strict
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER MUTATION.
// Explicit attended native OnTick harness. Every SQLite target is a TEST_ONLY
// copy; native submission is removed from this binary by the isolation header.
#include "../../ExecutionLayer/Contracts/SW_V5_S5_Canonical.mqh"
#include "SW_V5_S5_MvpContinuationTestIsolation.mqh"
string test_stop_stage="";
string test_fired_stop_stage="";
bool SWV5S5_TestContinuationStopStage(const string stage)
{
   if(!test_live_native_copy_armed || test_stop_stage!=stage)return false;
   test_fired_stop_stage="INTERRUPT_AFTER_"+(stage=="PENDING" ? "RELEASE_PENDING" : stage);
   Print("CONTINUATION_INJECTION_FIRED|",test_fired_stop_stage);return true;
}
#define SWV5S5_TEST_CONTINUATION_FAULTS
#include "../../ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh"
#include "../../ExecutionLayer/ControlledDemo/SW_V5_S5_MvpAttendedLaunch.mqh"
#include "SW_V5_S5_MvpContinuationAssertions.mqh"
input string explicit_test_only_marker="";
input string initial_copy_relative_path="";
input string expected_initial_copy_sha256="";
input bool execute_test_copy_once=false;
input bool operator_confirmed_test_copy=false;
SWV5S5_TestContinuationSuite test_suite;
bool native_test_ack=false,native_test_consumed=false,native_test_finished=false;
const string expected_copy_sha="bec62e7435d29d5511a41bf85c74ae443994c5804b3a9574af90d861fe674ef6";
bool NativeCopyGate()
{
   string digest;
   if(explicit_test_only_marker!="TEST_ONLY_AUTHORIZED_UNCOMMITTED_DRAFT" || !execute_test_copy_once || !operator_confirmed_test_copy ||
      expected_initial_copy_sha256!=expected_copy_sha || StringFind(initial_copy_relative_path,"TEST_ONLY_MVP_CONTINUATION_")!=0 ||
      StringFind(initial_copy_relative_path,"..")>=0 || StringFind(initial_copy_relative_path,"/")>=0 || StringFind(initial_copy_relative_path,"\\")>=0 ||
      _Symbol!="XAUUSD" || _Period!=PERIOD_M15 || MQLInfoInteger(MQL_TESTER) ||
      !SWV5S5_TestContinuationFileSha(initial_copy_relative_path,digest) || digest!=expected_copy_sha ||
      !SWV5S5_TestContinuationFileSha("fusion_v5_mvp_demo_authority.sqlite",digest) || digest!=expected_copy_sha ||
      FileIsExist("fusion_v5_mvp_demo_authority.sqlite-wal",FILE_COMMON) || FileIsExist("fusion_v5_mvp_demo_authority.sqlite-shm",FILE_COMMON))return false;
   SWV5S5_MvpMt5ReadOnlyPlatform platform;SWV5S5_MvpRuntimeProfileObservation profile;datetime at;
   SWV5S5_MvpSqliteAuthorityStore copy;SWV5S5_MvpAuthorityRow row;SWV5_InstanceLease lease;bool found=false;
   return platform.CaptureProfile(_Symbol,profile,at) && SWV5S5_MvpProfileMatches(profile,ACCOUNT_TRADE_MODE_DEMO) &&
      profile.broker_identity=="Exness Technologies Ltd" && profile.server=="Exness-MT5Trial6" &&
      copy.OpenReadOnly(initial_copy_relative_path,"58408af3c3381470aa50161762e4f1102eec5d214448495a79d732cd31d90d8c") &&
      copy.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,row,found) && found &&
      SWV5S5_MvpDecodeOwnershipLeasePhysical(row.payload,lease) && profile.account_login==lease.fence.owner.key.account_login &&
      profile.account_login%10000==6169;
}
int OnInit()
{
   native_test_ack=false;native_test_consumed=false;test_live_native_copy_armed=false;
   if(!NativeCopyGate() || !test_suite.ConfigureCopy(initial_copy_relative_path))
   {Print("CONTINUATION_NATIVE_COPY|FAIL_CLOSED|INITIAL_HASH_PATH_OR_PROFILE");return INIT_FAILED;}
   Print("CONTINUATION_NATIVE_COPY|READY|TEST_ONLY|WAIT_FOR_FRESH_A|copy=",initial_copy_relative_path,"|sha256=",expected_copy_sha);
   return INIT_SUCCEEDED;
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_KEYDOWN && lparam==65 && !native_test_consumed && !native_test_ack && NativeCopyGate())native_test_ack=true;
}
void OnTick()
{
   if(native_test_finished)return;
   if(!native_test_consumed)
   {
      if(!native_test_ack)return;
      native_test_consumed=true;native_test_ack=false;
      MqlTick tick;const datetime now=TimeCurrent();
      if(!NativeCopyGate() || !SymbolInfoTick(_Symbol,tick) || tick.time!=now || tick.time_msc/1000!=(long)tick.time ||
         now<=1791817607 || tick.bid<=0.0 || tick.ask<tick.bid)
      {Print("CONTINUATION_NATIVE_COPY|FAIL_CLOSED|NO_FRESH_POST_EXPIRY_NATIVE_TICK|NO_RETRY");native_test_finished=true;return;}
      test_live_native_copy_armed=true;
      Print("CONTINUATION_NATIVE_COPY|START|native_time=",(long)now,"|tick_time_msc=",tick.time_msc,
         "|terminal_build=",TerminalInfoInteger(TERMINAL_BUILD),"|mql_build=",__MQLBUILD__,"|TEST_ONLY");
      test_suite.Start();return;
   }
   if(test_suite.FinishLaterTick())
   {
      string digest;const bool original_ok=SWV5S5_TestContinuationFileSha("fusion_v5_mvp_demo_authority.sqlite",digest) && digest==expected_copy_sha;
      Print("CONTINUATION_NATIVE_COPY|COMPLETE|original_unchanged=",original_ok,"|original_sha256=",digest,
         "|forbidden_transport_calls=",test_forbidden_transport_calls,"|NO_REAL_DEPLOYMENT_AUTHORIZATION");
      native_test_finished=true;test_live_native_copy_armed=false;
   }
}
