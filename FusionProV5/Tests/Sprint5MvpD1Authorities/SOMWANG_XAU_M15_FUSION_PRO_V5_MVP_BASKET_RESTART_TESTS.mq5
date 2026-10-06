#property strict
#property tester_no_cache
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.
#include "SW_V5_S5_MvpBasketAuthorityAssertions.mqh"
int OnInit(void)
{
   SWV5S5_MvpD1Collector c; ZeroMemory(c); c.signature=1469598103934665603;
   SWV5S5_TestBasketConfirmationCrash(c,true); SWV5S5_TestBasketConfirmationCrash(c,false);
   Print("MVP_BASKET_RESTART_SUMMARY|total=",c.total,"|passed=",c.passed,"|failed=",c.failed,
      "|skipped=0|signature=",c.signature,"|broker_submission_calls=0");
   ExpertRemove(); return c.failed==0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick(void){}
