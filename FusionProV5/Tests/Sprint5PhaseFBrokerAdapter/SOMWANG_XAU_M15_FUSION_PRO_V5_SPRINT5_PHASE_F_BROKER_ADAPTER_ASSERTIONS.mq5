#property strict

// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.
// Run in MT5 Demo Strategy Tester only. This EA executes pure assertions and
// never constructs or invokes the platform Broker Adapter.

#include "SW_V5_S5_PhaseF_BrokerAdapterAssertions.mqh"

int g_swv5s5_f_mql_failures=1;

int OnInit()
{
   SWV5S5_F_MqlAssertionResult result;
   g_swv5s5_f_mql_failures=SWV5S5_F_RunBrokerAdapterMqlAssertions(result);
   return (g_swv5s5_f_mql_failures==0 ? INIT_SUCCEEDED : INIT_FAILED);
}

void OnTick()
{
}

double OnTester()
{
   return (g_swv5s5_f_mql_failures==0 ? 1.0 : 0.0);
}
