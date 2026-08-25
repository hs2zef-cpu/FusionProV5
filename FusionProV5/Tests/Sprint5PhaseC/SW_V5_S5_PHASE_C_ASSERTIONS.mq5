// TEST ONLY / NON-PRODUCTION / NO BROKER ACCESS
// COMPILE ONLY. Do not execute in MT5 Terminal or Strategy Tester.
#property strict

#include "SW_V5_S5_PhaseC_Assertions.mqh"

void OnStart(void)
{
   SWV5S5_RunPhaseCCompileOnlyAssertions();
}
