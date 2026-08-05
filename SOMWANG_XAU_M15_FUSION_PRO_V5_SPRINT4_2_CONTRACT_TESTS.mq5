//+------------------------------------------------------------------+
//| TEST ONLY                                                        |
//| NOT FOR PRODUCTION                                               |
//| NO BROKER ACCESS                                                 |
//| Sprint 4.2 deterministic Production Contract V2 verification.   |
//+------------------------------------------------------------------+
#property strict
#property version "5.42"

#include "FusionProV5\Tests\ContractVerification\SW_V5_ContractTestRunner.mqh"

bool g_swv5_contract_tests_passed=false;

int OnInit()
{
   g_swv5_contract_tests_passed=SWV5_RunContractVerification();
   PrintFormat("SWV5_CONTRACT_TEST_RUNNER verdict=%s",g_swv5_contract_tests_passed ? "PASS" : "FAIL");
   return g_swv5_contract_tests_passed ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick()
{
   // Intentionally empty. Tests execute once from deterministic fixtures in OnInit().
}

double OnTester()
{
   return g_swv5_contract_tests_passed ? 1.0 : 0.0;
}
//+------------------------------------------------------------------+
