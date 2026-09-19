#property strict
#property tester_no_cache

// REAL MQL TEST ONLY / NOT FOR TRADING / NO BROKER MUTATION.

#include "SW_V5_S5_MvpAuthorityRoundTripAssertions.mqh"

int OnInit(void)
{
   SWV5S5_MvpTestCollector collector;
   SWV5S5_RunMvpAuthorityRoundTripAssertions(collector);
   Print("MVP_AUTHORITY_ROUND_TRIP_SUMMARY|total=",collector.total,"|passed=",collector.passed,
      "|failed=",collector.failed,"|skipped=0|signature=",collector.signature,
      "|broker_submission_calls=0");
   ExpertRemove();
   return (collector.failed==0 ? INIT_SUCCEEDED : INIT_FAILED);
}

void OnTick(void) {}
