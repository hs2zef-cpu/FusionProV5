//+------------------------------------------------------------------+
//| TEST ONLY                                                        |
//| NOT FOR PRODUCTION                                               |
//| NO BROKER ACCESS                                                 |
//| Sprint 4.3 deterministic interface-level contract verification. |
//+------------------------------------------------------------------+
#property strict
#property version "5.43"

#include "FusionProV5\Tests\ContractVerification\SW_V5_ContractTestRunner.mqh"

bool g_swv5_contract_tests_passed=false;

int OnInit()
{
   Print("SWV5_RUN_METADATA suite=SPRINT4.3 fixture_account_mode=HEDGING fixture_broker=TEST-BROKER fixture_server=TEST-SERVER broker_access=false");
   g_swv5_contract_tests_passed=SWV5_RunContractVerification();
   PrintFormat("SWV5_CONTRACT_TEST_RUNNER verdict=%s",g_swv5_contract_tests_passed ? "PASS" : "FAIL");
   return g_swv5_contract_tests_passed ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick()
{
   // Intentionally empty. All verification uses deterministic in-memory fixtures.
}

double OnTester()
{
   return g_swv5_contract_tests_passed ? 1.0 : 0.0;
}
//+------------------------------------------------------------------+
