#property strict
#property tester_no_cache
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.
#include "SW_V5_S5_MvpBasketAuthorityAssertions.mqh"
int OnInit(void)
{
   SWV5S5_MvpD1Collector c; SWV5S5_RunMvpBasketAuthorityAssertions(c);
   Print("MVP_BASKET_AUTHORITY_SUMMARY|total=",c.total,"|passed=",c.passed,"|failed=",c.failed,
      "|skipped=0|signature=",c.signature,"|broker_submission_calls=0");
   ExpertRemove(); return c.failed==0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick(void){}
