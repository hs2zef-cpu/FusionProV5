#property strict
#property tester_no_cache
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER MUTATION.
#include "SW_V5_S5_MvpAttendedLaunchAssertions.mqh"
SWV5S5_TestAttendedLaunchSuite suite;
bool finished=false;
int OnInit(void)
{ return MQLInfoInteger(MQL_TESTER) && AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO && _Symbol=="XAUUSD" ? INIT_SUCCEEDED : INIT_FAILED; }
void OnTick(void)
{
   if(finished) return;
   if(!suite.Started()) { suite.Start(); return; }
   if(suite.ReadyToFinish()) { finished=true; suite.Finish(); ExpertRemove(); }
}
