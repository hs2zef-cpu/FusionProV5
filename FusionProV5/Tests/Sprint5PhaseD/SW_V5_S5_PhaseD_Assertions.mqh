#ifndef SW_V5_S5_PHASE_D_ASSERTIONS_MQH
#define SW_V5_S5_PHASE_D_ASSERTIONS_MQH

// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// Compile-only direct probes. They are deliberately never executed.
#include "../../ExecutionLayer/PersistenceReference/SW_V5_S5_PersistenceReference.mqh"

bool SWV5S5_PhaseDCompileStoreAssertion(void)
{
   SWV5S5_FakeTransactionalStore store; SWV5S5_ReferenceDomainRow current,proposed; string digest;
   ZeroMemory(current); current.domain=SWV5S5_REF_DOMAIN_LEDGER; current.persistence_namespace_digest="NS";
   current.store_revision=1; current.authority_fence_digest="FENCE"; current.payload="CANONICAL";
   if(!SWV5S5_ReferenceCanonicalPayloadDigest(current.domain,current.payload,digest)) return false; current.payload_digest=digest;
   proposed=current; proposed.store_revision=2; proposed.payload="CANONICAL-2";
   if(!SWV5S5_ReferenceCanonicalPayloadDigest(proposed.domain,proposed.payload,digest)) return false; proposed.payload_digest=digest;
   SWV5S5_ReferenceTransactionResult result;
   return store.Seed(current) && store.CompareAndSet(current.domain,"NS",1,current.payload_digest,"FENCE",proposed,SWV5S5_REF_FAULT_NONE,result);
}

bool SWV5S5_PhaseDCompileClockAssertion(void)
{
   SWV5S5_FakeAuthoritativeClock clock; clock.Configure("CLOCK",SWV5_TIME_AUTHORITY_BROKER_SERVER,"XAUUSD");
   SWV5S5_ReferenceClockObservation candidate,validated; ZeroMemory(candidate);
   candidate.clock_id="CLOCK"; candidate.authority=SWV5_TIME_AUTHORITY_BROKER_SERVER; candidate.source_symbol="XAUUSD";
   candidate.observation_sequence=1; candidate.observed_at=100; candidate.event_identity="EVENT-1"; candidate.current_event_provenance=true;
   return clock.AcceptAndSeal(candidate,validated) && clock.ValidateAccepted(validated);
}

bool SWV5S5_PhaseDCompileLeaseAssertion(void)
{
   SWV5S5_ReferenceLeaseStore lease; SWV5_InstanceLease observed,result; SWV5_OwnershipClaim claim;
   SWV5S5_FakeAuthoritativeClock clock; SWV5S5_ReferenceClockObservation observation,validated; SWV5S5_ReferenceTransactionResult tx;
   return lease.Initialize(observed) && lease.Acquire(clock,validated,claim,result,tx);
}

bool SWV5S5_PhaseDCompileClaimAssertion(void)
{
   SWV5S5_ReferenceSubmissionStore store; SWV5S5_SubmissionAuthorityRecord record;
   SWV5S5_InvocationClaimCommand command; SWV5S5_InvocationClaimTransition transition; SWV5S5_InvocationClaimResult result;
   SWV5S5_ReferenceTransactionResult tx;
   return store.Initialize(record) && store.TryClaimInvocation(command,transition,SWV5S5_REF_FAULT_NONE,result,tx);
}

bool SWV5S5_PhaseDCompileSequenceAssertion(void)
{
   SWV5S5_ReferenceSequenceStore store; SWV5S5_RequestSequenceAuthority authority; SWV5S5_RequestSequenceIndexEntry entries[];
   SWV5S5_RequestSequenceReservation proposal; SWV5S5_RequestSequenceResult result; SWV5S5_ReferenceTransactionResult tx;
   return store.Initialize(authority,entries) && store.Reserve(proposal,result,tx);
}

bool SWV5S5_PhaseDCompileRestartAssertion(void)
{
   SWV5_ContractValidationContext context; SWV5_RestartReconciliationInput restart_input; SWV5_PersistedRequestEvidence requests[];
   SWV5S5_ReferenceGenesisRecord genesis; SWV5_InstanceLease lease; SWV5S5_ReferenceRestartResult result;
   return SWV5S5_EvaluateReferenceRestart(context,restart_input,requests,genesis,lease,result);
}

void SWV5S5_RunPhaseDCompileOnlyAssertions(void)
{
   // Deliberately not called by any runtime or tester manifest.
}

#endif
