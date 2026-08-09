//+------------------------------------------------------------------+
//| TEST ONLY                                                        |
//| NOT FOR PRODUCTION                                               |
//| NO BROKER ACCESS                                                 |
//| Sprint 4.5 deterministic contract verification.                 |
//+------------------------------------------------------------------+
#property strict
#property version "5.45"

#include "FusionProV5\Tests\ContractVerification\SW_V5_ContractTestRunner.mqh"

input bool InpPhaseATargetedOnly=false;
input bool InpPhaseBTargetedOnly=false;
input bool InpPhaseCTargetedOnly=false;
input bool InpPhaseDTargetedOnly=false;
input bool InpPhaseETargetedOnly=false;
input bool InpS4421TargetedOnly=false;

bool g_swv5_contract_tests_passed=false;

int OnInit()
{
   const string suite=(InpPhaseETargetedOnly ? "SPRINT4.5-PHASE-E" : (InpS4421TargetedOnly ? "SPRINT4.5-S44-21" : (InpPhaseDTargetedOnly ? "SPRINT4.5-PHASE-D" : (InpPhaseCTargetedOnly ? "SPRINT4.5-PHASE-C" : (InpPhaseBTargetedOnly ? "SPRINT4.5-PHASE-B" : (InpPhaseATargetedOnly ? "SPRINT4.5-PHASE-A" : "SPRINT4.5-FULL"))))));
   Print("SWV5_RUN_METADATA suite="+suite+" fixture_account_mode=HEDGING fixture_broker=TEST-BROKER fixture_server=TEST-SERVER broker_access=false");
   g_swv5_contract_tests_passed=(InpPhaseETargetedOnly ? SWV5_RunPhaseETargetedVerification() :
                                 (InpS4421TargetedOnly ? SWV5_RunS4421TargetedVerification() :
                                 (InpPhaseDTargetedOnly ? SWV5_RunPhaseDTargetedVerification() :
                                 (InpPhaseCTargetedOnly ? SWV5_RunPhaseCTargetedVerification() :
                                 (InpPhaseBTargetedOnly ? SWV5_RunPhaseBTargetedVerification() :
                                 (InpPhaseATargetedOnly ? SWV5_RunPhaseATargetedVerification() : SWV5_RunContractVerification()))))));
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
