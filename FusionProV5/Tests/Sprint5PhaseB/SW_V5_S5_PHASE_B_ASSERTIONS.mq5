// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// COMPILE ONLY: Phase B.1 does not execute this script in MT5 or Strategy Tester.
#property strict

#include "SW_V5_S5_PhaseB_Assertions.mqh"

int SWV5S5_PHASE_B_VISIBLE_FAILURE_COUNT=-1;

void OnStart()
{
   // One entrypoint invokes every registered MQL assertion. The global retains
   // the exact visible failure count for a future separately authorized runner.
   SWV5S5_PHASE_B_VISIBLE_FAILURE_COUNT=SWV5S5_RunAllPhaseBAssertions();
}
