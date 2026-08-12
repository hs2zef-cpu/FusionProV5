//+------------------------------------------------------------------+
//| TEST ONLY                                                        |
//| NOT FOR PRODUCTION                                               |
//| NO BROKER ACCESS                                                 |
//| Sprint 4.8 V5 deterministic contract verification.              |
//+------------------------------------------------------------------+
#property strict
#property version "5.60"

#include "FusionProV5\Tests\ContractVerification\SW_V5_ContractTestRunner.mqh"

input bool InpPhaseATargetedOnly=false;
input bool InpPhaseBTargetedOnly=false;
input bool InpPhaseCTargetedOnly=false;
input bool InpPhaseDTargetedOnly=false;
input bool InpPhaseETargetedOnly=false;
input bool InpS4421TargetedOnly=false;
input bool InpSprint46PhaseATargetedOnly=false;
input bool InpSprint46OwnershipRegressionOnly=false;
input bool InpSprint46PhaseBTargetedOnly=false;
input bool InpSprint46RiskRegressionOnly=false;
input bool InpSprint46CheckpointTargetedOnly=false;
input bool InpSprint46EventIdentityTargetedOnly=false;
input bool InpSprint46PersistenceRegressionOnly=false;
input bool InpSprint46StatisticsRegressionOnly=false;
input bool InpSprint46ExecutionFingerprintRegressionOnly=false;
input bool InpSprint46E1FingerprintTargetedOnly=false;
input bool InpSprint46RetryTargetedOnly=false;
input bool InpPER02TargetedOnly=false;
input bool InpSprint47RiskProjectionTargetedOnly=false;
input bool InpSprint47NonFiniteTargetedOnly=false;
input bool InpSprint47HardKillTargetedOnly=false;
input bool InpSprint47CheckpointTargetedOnly=false;
input bool InpSprint47RetryEnumTargetedOnly=false;
input bool InpSprint48HardKillAuthorityTargetedOnly=false;
input bool InpSprint48CanonicalIntegrityTargetedOnly=false;
input bool InpSprint48CanonicalAffectedTargetedOnly=false;
input bool InpSprint48HistoricalRegressionTargetedOnly=false;
input bool InpSprint48RoundTripTargetedOnly=false;
input bool InpSprint48MetadataTargetedOnly=false;
input bool InpSprint48PreviousSafetyTargetedOnly=false;
input bool InpSprint48B6MarginAuthorityTargetedOnly=false;
input bool InpSprint48B6BasketAuthorityTargetedOnly=false;
input bool InpSprint48B6PersistenceAtomicityTargetedOnly=false;
input bool InpSprint48B6IdentityTargetedOnly=false;

bool g_swv5_contract_tests_passed=false;

string SWV5_SelectedSuiteName()
{
   if(InpSprint48B6IdentityTargetedOnly) return "SPRINT4.8-V5-IDENTITY";
   if(InpSprint48B6PersistenceAtomicityTargetedOnly) return "SPRINT4.8-V5-PERSISTENCE-ATOMICITY";
   if(InpSprint48B6BasketAuthorityTargetedOnly) return "SPRINT4.8-V5-BASKET-AUTHORITY";
   if(InpSprint48B6MarginAuthorityTargetedOnly) return "SPRINT4.8-V5-MARGIN-AUTHORITY";
   if(InpSprint48PreviousSafetyTargetedOnly) return "SPRINT4.8-PREVIOUS-SAFETY";
   if(InpSprint48MetadataTargetedOnly) return "SPRINT4.8-METADATA-CONFORMANCE";
   if(InpSprint48RoundTripTargetedOnly) return "SPRINT4.8-TRUE-ROUND-TRIP";
   if(InpSprint48HistoricalRegressionTargetedOnly) return "SPRINT4.8-HISTORICAL-REGRESSIONS";
   if(InpSprint48CanonicalIntegrityTargetedOnly) return "SPRINT4.8-CANONICAL-INTEGRITY";
   if(InpSprint48CanonicalAffectedTargetedOnly) return "SPRINT4.8-CANONICAL-AFFECTED";
   if(InpSprint48HardKillAuthorityTargetedOnly) return "SPRINT4.8-HARD-KILL-AUTHORITY";
   if(InpSprint47RiskProjectionTargetedOnly) return "SPRINT4.7-RISK-PROJECTION";
   if(InpSprint47NonFiniteTargetedOnly) return "SPRINT4.7-NONFINITE";
   if(InpSprint47HardKillTargetedOnly) return "SPRINT4.7-HARD-KILL-EXPIRY";
   if(InpSprint47CheckpointTargetedOnly) return "SPRINT4.7-CHECKPOINT-SEMANTICS";
   if(InpSprint47RetryEnumTargetedOnly) return "SPRINT4.7-RETRY-ENUM";
   if(InpSprint46E1FingerprintTargetedOnly) return "SPRINT4.6-E1-FINGERPRINT-UNIQUENESS";
   if(InpSprint46RetryTargetedOnly) return "SPRINT4.6-RETRY-FRESHNESS";
   if(InpPER02TargetedOnly) return "SPRINT4.6-PER-02-CREDIBILITY";
   if(InpSprint46CheckpointTargetedOnly) return "SPRINT4.6-CHECKPOINT-INTEGRITY";
   if(InpSprint46EventIdentityTargetedOnly) return "SPRINT4.6-DURABLE-EVENT-IDENTITY";
   if(InpSprint46PersistenceRegressionOnly) return "SPRINT4.6-PERSISTENCE-REGRESSION";
   if(InpSprint46StatisticsRegressionOnly) return "SPRINT4.6-STATISTICS-REGRESSION";
   if(InpSprint46ExecutionFingerprintRegressionOnly) return "SPRINT4.6-EXECUTION-FINGERPRINT-REGRESSION";
   if(InpSprint46PhaseBTargetedOnly) return "SPRINT4.6-PHASE-B";
   if(InpSprint46RiskRegressionOnly) return "SPRINT4.6-RISK-REGRESSION";
   if(InpSprint46PhaseATargetedOnly) return "SPRINT4.6-PHASE-A";
   if(InpSprint46OwnershipRegressionOnly) return "SPRINT4.6-OWNERSHIP-REGRESSION";
   if(InpPhaseETargetedOnly) return "SPRINT4.5-PHASE-E";
   if(InpS4421TargetedOnly) return "SPRINT4.5-S44-21";
   if(InpPhaseDTargetedOnly) return "SPRINT4.5-PHASE-D";
   if(InpPhaseCTargetedOnly) return "SPRINT4.5-PHASE-C";
   if(InpPhaseBTargetedOnly) return "SPRINT4.5-PHASE-B";
   if(InpPhaseATargetedOnly) return "SPRINT4.5-PHASE-A";
   return "SPRINT4.8-V5-FULL";
}

bool SWV5_RunSelectedSuite()
{
   if(InpSprint48B6IdentityTargetedOnly) return SWV5_RunSprint48B6IdentityTargetedVerification();
   if(InpSprint48B6PersistenceAtomicityTargetedOnly) return SWV5_RunSprint48B6PersistenceAtomicityTargetedVerification();
   if(InpSprint48B6BasketAuthorityTargetedOnly) return SWV5_RunSprint48B6BasketAuthorityTargetedVerification();
   if(InpSprint48B6MarginAuthorityTargetedOnly) return SWV5_RunSprint48B6MarginAuthorityTargetedVerification();
   if(InpSprint48PreviousSafetyTargetedOnly) return SWV5_RunSprint48PreviousSafetyTargetedVerification();
   if(InpSprint48MetadataTargetedOnly) return SWV5_RunSprint48MetadataTargetedVerification();
   if(InpSprint48RoundTripTargetedOnly) return SWV5_RunSprint48RoundTripTargetedVerification();
   if(InpSprint48HistoricalRegressionTargetedOnly) return SWV5_RunSprint48HistoricalRegressionTargetedVerification();
   if(InpSprint48CanonicalIntegrityTargetedOnly) return SWV5_RunSprint48CanonicalIntegrityTargetedVerification();
   if(InpSprint48CanonicalAffectedTargetedOnly) return SWV5_RunSprint48CanonicalAffectedTargetedVerification();
   if(InpSprint48HardKillAuthorityTargetedOnly) return SWV5_RunSprint48HardKillAuthorityTargetedVerification();
   if(InpSprint47RiskProjectionTargetedOnly) return SWV5_RunSprint47RiskProjectionTargetedVerification();
   if(InpSprint47NonFiniteTargetedOnly) return SWV5_RunSprint47NonFiniteTargetedVerification();
   if(InpSprint47HardKillTargetedOnly) return SWV5_RunSprint47HardKillTargetedVerification();
   if(InpSprint47CheckpointTargetedOnly) return SWV5_RunSprint47CheckpointTargetedVerification();
   if(InpSprint47RetryEnumTargetedOnly) return SWV5_RunSprint47RetryEnumTargetedVerification();
   if(InpSprint46E1FingerprintTargetedOnly) return SWV5_RunSprint46E1FingerprintTargetedVerification();
   if(InpSprint46RetryTargetedOnly) return SWV5_RunSprint46RetryTargetedVerification();
   if(InpPER02TargetedOnly) return SWV5_RunPER02TargetedVerification();
   if(InpSprint46CheckpointTargetedOnly) return SWV5_RunSprint46CheckpointTargetedVerification();
   if(InpSprint46EventIdentityTargetedOnly) return SWV5_RunSprint46EventIdentityTargetedVerification();
   if(InpSprint46PersistenceRegressionOnly) return SWV5_RunSprint46PersistenceRegressionVerification();
   if(InpSprint46StatisticsRegressionOnly) return SWV5_RunSprint46StatisticsRegressionVerification();
   if(InpSprint46ExecutionFingerprintRegressionOnly) return SWV5_RunSprint46ExecutionFingerprintRegressionVerification();
   if(InpSprint46PhaseBTargetedOnly) return SWV5_RunSprint46PhaseBTargetedVerification();
   if(InpSprint46RiskRegressionOnly) return SWV5_RunSprint46RiskRegressionVerification();
   if(InpSprint46PhaseATargetedOnly) return SWV5_RunSprint46PhaseATargetedVerification();
   if(InpSprint46OwnershipRegressionOnly) return SWV5_RunSprint46OwnershipRegressionVerification();
   if(InpPhaseETargetedOnly) return SWV5_RunPhaseETargetedVerification();
   if(InpS4421TargetedOnly) return SWV5_RunS4421TargetedVerification();
   if(InpPhaseDTargetedOnly) return SWV5_RunPhaseDTargetedVerification();
   if(InpPhaseCTargetedOnly) return SWV5_RunPhaseCTargetedVerification();
   if(InpPhaseBTargetedOnly) return SWV5_RunPhaseBTargetedVerification();
   if(InpPhaseATargetedOnly) return SWV5_RunPhaseATargetedVerification();
   return SWV5_RunContractVerification();
}

int OnInit()
{
   const string suite=SWV5_SelectedSuiteName();
   SWV5_TestSetSuiteIdentity(suite);
   Print("SWV5_RUN_METADATA suite="+suite+" fixture_account_mode=HEDGING fixture_broker=TEST-BROKER fixture_server=TEST-SERVER broker_access=false");
   g_swv5_contract_tests_passed=SWV5_RunSelectedSuite();
   PrintFormat("SWV5_CONTRACT_TEST_RUNNER verdict=%s",g_swv5_contract_tests_passed ? "PASS" : "FAIL");
   return g_swv5_contract_tests_passed ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick()
{
   // Intentionally empty. All verification uses deterministic in-memory fixtures.
}

double OnTester()
{
   PrintFormat("SWV5_ONTESTER_SUCCESS result=%d",g_swv5_contract_tests_passed ? 1 : 0);
   return g_swv5_contract_tests_passed ? 1.0 : 0.0;
}
//+------------------------------------------------------------------+
