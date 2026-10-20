#property strict
#property tester_no_cache
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER MUTATION.
#include "../../ExecutionLayer/Contracts/SW_V5_S5_Canonical.mqh"
#include "SW_V5_S5_MvpContinuationTestIsolation.mqh"
string test_stop_stage="";
string test_fired_stop_stage="";
bool SWV5S5_TestContinuationStopStage(const string stage)
{
   if(!MQLInfoInteger(MQL_TESTER) || test_stop_stage!=stage)return false;
   test_fired_stop_stage="INTERRUPT_AFTER_"+(stage=="PENDING" ? "RELEASE_PENDING" : stage);
   Print("CONTINUATION_INJECTION_FIRED|",test_fired_stop_stage);return true;
}
#define SWV5S5_TEST_CONTINUATION_FAULTS
#include "../../ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh"
#include "../../ExecutionLayer/ControlledDemo/SW_V5_S5_MvpAttendedLaunch.mqh"
#include "SW_V5_S5_MvpContinuationAssertions.mqh"
SWV5S5_TestContinuationSuite suite;
int OnInit() { return MQLInfoInteger(MQL_TESTER) && AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO && _Symbol=="XAUUSD" ? INIT_SUCCEEDED : INIT_FAILED; }
void OnTick()
{
   if(TimeCurrent()<=1791817607) return; // COPY's latest original deadline
   if(!suite.Started()) {suite.Start(); return;}
   if(suite.FinishLaterTick()) ExpertRemove();
}
