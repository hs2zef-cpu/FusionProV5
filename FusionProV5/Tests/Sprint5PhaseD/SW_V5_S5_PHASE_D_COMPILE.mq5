// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// COMPILE ONLY. Do not execute in MT5 Terminal or Strategy Tester.
#property strict

#include "../../ExecutionLayer/PersistenceReference/SW_V5_S5_PersistenceReference.mqh"

void OnStart(void)
{
   SWV5S5_FakeTransactionalStore store;
   SWV5S5_FakeAuthoritativeClock clock;
   SWV5S5_FakePlatformQuerySource platform_queries;
   SWV5S5_ReferenceLeaseStore lease;
   SWV5S5_ReferenceIngressLedgerStore ledger;
   SWV5S5_ReferenceSequenceStore sequence;
   SWV5S5_ReferenceSubmissionStore submission;
   SWV5S5_ReferencePublicationStore publication;
   SWV5S5_ReferenceGenesis genesis;
}
