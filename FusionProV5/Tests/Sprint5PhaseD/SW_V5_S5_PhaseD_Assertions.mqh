#ifndef SW_V5_S5_PHASE_D_ASSERTIONS_MQH
#define SW_V5_S5_PHASE_D_ASSERTIONS_MQH

// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// COMPILE ONLY. These assertions are never executed by this Phase D task.

#include "../../ExecutionLayer/PersistenceReference/SW_V5_S5_PersistenceReference.mqh"

bool SWV5S5_PhaseDCompileStoreAssertion(void)
{
   SWV5S5_FakeTransactionalStore store;
   SWV5S5_ReferenceDomainRow old_row,proposed;
   old_row.domain=SWV5S5_REF_DOMAIN_LEDGER;
   old_row.persistence_namespace_digest="NS";
   old_row.store_revision=1;
   old_row.authority_fence_digest="FENCE";
   old_row.payload="OLD";
   old_row.payload_digest=SWV5S5_ReferenceDigest("ROW","OLD");
   proposed=old_row;
   proposed.store_revision=2;
   proposed.payload="NEW";
   proposed.payload_digest=SWV5S5_ReferenceDigest("ROW","NEW");
   if(!store.Seed(old_row)) return false;
   SWV5S5_ReferenceTransactionResult result;
   return store.CompareAndSet(SWV5S5_REF_DOMAIN_LEDGER,1,old_row.payload_digest,"FENCE",
                              proposed,SWV5S5_REF_FAULT_NONE,result) &&
          result.this_transaction_won && result.disposition==SWV5S5_REF_COMMITTED;
}

bool SWV5S5_PhaseDCompileClockAssertion(void)
{
   SWV5S5_FakeAuthoritativeClock clock;
   clock.Configure("CLOCK",SWV5_TIME_AUTHORITY_BROKER_SERVER,"XAUUSD");
   SWV5S5_ReferenceClockObservation observation;
   observation.clock_id="CLOCK";
   observation.authority=SWV5_TIME_AUTHORITY_BROKER_SERVER;
   observation.source_symbol="XAUUSD";
   observation.observation_sequence=1;
   observation.observed_at=100;
   observation.event_identity="EVENT-1";
   observation.current_event_provenance=true;
   return clock.Accept(observation);
}

bool SWV5S5_PhaseDCompileLeaseAssertion(void)
{
   SWV5S5_ReferenceLeaseStore lease_store;
   lease_store.InitializeUnclaimed("NS");
   SWV5S5_ReferenceLease lease;
   if(!lease_store.Acquire("OWNER-A",1,1,100,10,lease)) return false;
   string stable_fence=lease.fencing_token_digest;
   if(!lease_store.Heartbeat("OWNER-A",lease.store_revision,stable_fence,2,105,10,lease)) return false;
   return lease.fencing_token_digest==stable_fence && lease.lease_version==1 && lease.takeover_generation==1;
}

bool SWV5S5_PhaseDCompileSequenceAssertion(void)
{
   SWV5S5_ReferenceSequenceStore store;
   ulong sequence=0;
   bool existing=false;
   if(!store.Reserve("CORRELATION","BINDING",1,sequence,existing)) return false;
   if(existing || sequence!=1) return false;
   return store.Reserve("CORRELATION","BINDING",store.Revision(),sequence,existing) && existing && sequence==1;
}

bool SWV5S5_PhaseDCompileClaimAssertion(void)
{
   SWV5S5_ReferenceSubmissionStore store;
   SWV5S5_ReferenceSubmissionRecord record;
   record.request_id="REQUEST";
   record.attempt_id="ATTEMPT";
   record.permit_digest="PERMIT";
   record.ownership_fence_digest="FENCE";
   record.authority_revision=1;
   record.state=SWV5S5_COMMITTED_NOT_INVOKED;
   if(!store.CommitPermit(record)) return false;
   SWV5S5_ReferenceClaimResult claim;
   return store.Claim("ATTEMPT",1,"PERMIT","FENCE",false,claim) &&
          claim.claim_granted_now && claim.claim_disposition==SWV5S5_CLAIM_GRANTED_NOW;
}

void SWV5S5_RunPhaseDCompileOnlyAssertions(void)
{
   bool compile_only=SWV5S5_PhaseDCompileStoreAssertion();
   compile_only=compile_only && SWV5S5_PhaseDCompileClockAssertion();
   compile_only=compile_only && SWV5S5_PhaseDCompileLeaseAssertion();
   compile_only=compile_only && SWV5S5_PhaseDCompileSequenceAssertion();
   compile_only=compile_only && SWV5S5_PhaseDCompileClaimAssertion();
}

#endif
