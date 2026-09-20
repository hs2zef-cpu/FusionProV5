#property strict
#property tester_no_cache

// OFFLINE TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

#include "SW_V5_S5_MvpOwnershipRoundTripAssertions.mqh"

int OnInit(void)
{
   SWV5S5_ControlledDemoCollector collector;
   SWV5S5_RunControlledDemoAssertions(collector);
   SWV5S5_RunOwnershipRoundTripAssertions(collector);
   Print("CONTROLLED_DEMO_SUMMARY|total=",collector.total,"|passed=",collector.passed,
      "|failed=",collector.failed,"|skipped=0|signature=",collector.signature,
      "|broker_submission_calls=0");
   ExpertRemove();
   return (collector.failed==0 ? INIT_SUCCEEDED : INIT_FAILED);
}

void OnTick(void) {}
