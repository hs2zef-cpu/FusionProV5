#property strict
#property tester_no_cache

// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
#include "SW_V5_S5_MvpD1AuthorityAssertions.mqh"

int OnInit(void)
{
   SWV5S5_MvpD1Collector collector;
   SWV5S5_RunMvpD1AuthorityAssertions(collector);
   Print("MVP_D1_AUTHORITY_SUMMARY|total=",collector.total,"|passed=",collector.passed,
      "|failed=",collector.failed,"|skipped=0|signature=",collector.signature,
      "|broker_submission_calls=0");
   ExpertRemove();
   return collector.failed==0 ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick(void) {}
