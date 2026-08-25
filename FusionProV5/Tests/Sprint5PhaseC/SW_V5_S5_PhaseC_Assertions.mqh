#ifndef SW_V5_S5_PHASE_C_ASSERTIONS_MQH
#define SW_V5_S5_PHASE_C_ASSERTIONS_MQH

// TEST ONLY / NON-PRODUCTION / NO BROKER ACCESS
// Compile-only MQL assertions. Execution requires a later separately authorized gate.

#include "SW_V5_S5_PhaseC_TestDoubles.mqh"

int SWV5S5_PhaseCAssertionCount=0;
int SWV5S5_PhaseCAssertionFailures=0;

void SWV5S5_PhaseCAssert(const bool condition)
{
   SWV5S5_PhaseCAssertionCount++;
   if(!condition) SWV5S5_PhaseCAssertionFailures++;
}

void SWV5S5_BuildPhaseCEvent(const string event_id,const ulong ordinal,
                             SWV5S5_CoordinatorAdmissionEvent &event)
{
   ZeroMemory(event);
   event.event_id=event_id;
   event.event_ordinal=ordinal;
   event.request_correlation_id="request-A";
   event.attempt_id="attempt-A-1";
   event.normalized_payload_identity="normalized-A";
   event.request_state=SWV5_REQUEST_SUBMISSION_PENDING;
   event.request_phase=SWV5_EXECUTION_PHASE_SUBMISSION;
   event.interruption_point=SWV5S5_COORD_INTERRUPT_NONE;
   event.claim_command.expected_authority_record.permit.request_identity.request_id.correlation_id=event.request_correlation_id;
   event.claim_command.expected_authority_record.permit.request_identity.request_id.attempt_id=event.attempt_id;
   event.claim_command.expected_authority_record.permit.unique_attempt_id=event.attempt_id;
   event.claim_command.expected_authority_record.permit.normalization_identity=event.normalized_payload_identity;
}

void SWV5S5_RunPhaseCCompileOnlyAssertions(void)
{
   SWV5S5_DeterministicCoordinator coordinator;
   SWV5S5_ScriptedAdmissionPreparation admission;
   SWV5S5_ScriptedClaimAuthority claim;
   SWV5S5_ScriptedFakeBroker broker;
   SWV5S5_TestTraceSink trace;
   SWV5S5_CoordinatorAdmissionEvent event;
   SWV5S5_CoordinatorResult result;
   SWV5S5_BuildPhaseCEvent("E1",1,event);
   bool ok=coordinator.ProcessAdmission(event,admission,claim,broker,trace,result);
   SWV5S5_PhaseCAssert(ok);
   SWV5S5_PhaseCAssert(result.disposition==SWV5S5_COORD_FAKE_BROKER_INVOKED);
   SWV5S5_PhaseCAssert(result.claim_granted_in_current_event);
   SWV5S5_PhaseCAssert(result.fake_broker_invoked);
   SWV5S5_PhaseCAssert(broker.InvocationCount()==1);
   SWV5S5_PhaseCAssert(trace.Count()>=4);

   SWV5S5_BuildPhaseCEvent("E2",2,event);
   ok=coordinator.ProcessAdmission(event,admission,claim,broker,trace,result);
   SWV5S5_PhaseCAssert(ok);
   SWV5S5_PhaseCAssert(result.disposition==SWV5S5_COORD_ALREADY_CLAIMED_UNCERTAIN);
   SWV5S5_PhaseCAssert(!result.claim_granted_in_current_event);
   SWV5S5_PhaseCAssert(!result.fake_broker_invoked);
   SWV5S5_PhaseCAssert(result.reconciliation_required);
   SWV5S5_PhaseCAssert(broker.InvocationCount()==1);

   SWV5S5_ScriptedClaimAuthority before_claim;
   SWV5S5_ScriptedFakeBroker before_broker;
   SWV5S5_TestTraceSink before_trace;
   SWV5S5_BuildPhaseCEvent("E3",3,event);
   event.interruption_point=SWV5S5_COORD_INTERRUPT_BEFORE_CLAIM;
   ok=coordinator.ProcessAdmission(event,admission,before_claim,before_broker,before_trace,result);
   SWV5S5_PhaseCAssert(ok);
   SWV5S5_PhaseCAssert(result.disposition==SWV5S5_COORD_INTERRUPTED_RECOLLECT);
   SWV5S5_PhaseCAssert(before_claim.call_count==0);
   SWV5S5_PhaseCAssert(before_broker.InvocationCount()==0);

   SWV5S5_ScriptedClaimAuthority after_claim;
   SWV5S5_ScriptedFakeBroker after_broker;
   SWV5S5_TestTraceSink after_trace;
   SWV5S5_BuildPhaseCEvent("E4",4,event);
   event.interruption_point=SWV5S5_COORD_INTERRUPT_AFTER_CLAIM_BEFORE_BROKER;
   ok=coordinator.ProcessAdmission(event,admission,after_claim,after_broker,after_trace,result);
   SWV5S5_PhaseCAssert(ok);
   SWV5S5_PhaseCAssert(result.disposition==SWV5S5_COORD_CLAIMED_RECONCILIATION_REQUIRED);
   SWV5S5_PhaseCAssert(result.reconciliation_required);
   SWV5S5_PhaseCAssert(after_broker.InvocationCount()==0);

   SWV5S5_ScriptedClaimAuthority stale;
   stale.next_disposition=SWV5S5_CLAIM_STALE_OWNER;
   SWV5S5_ScriptedFakeBroker stale_broker;
   SWV5S5_TestTraceSink stale_trace;
   SWV5S5_BuildPhaseCEvent("E5",5,event);
   ok=coordinator.ProcessAdmission(event,admission,stale,stale_broker,stale_trace,result);
   SWV5S5_PhaseCAssert(!ok);
   SWV5S5_PhaseCAssert(result.disposition==SWV5S5_COORD_STALE_OWNER);
   SWV5S5_PhaseCAssert(stale_broker.InvocationCount()==0);

   SWV5S5_ScriptedClaimAuthority lifecycle_claim;
   SWV5S5_ScriptedFakeBroker lifecycle_broker;
   SWV5S5_TestTraceSink lifecycle_trace;
   SWV5S5_BuildPhaseCEvent("E6",6,event);
   event.request_state=SWV5_REQUEST_CONFIRMED;
   ok=coordinator.ProcessAdmission(event,admission,lifecycle_claim,lifecycle_broker,lifecycle_trace,result);
   SWV5S5_PhaseCAssert(!ok);
   SWV5S5_PhaseCAssert(lifecycle_claim.call_count==0);
   SWV5S5_PhaseCAssert(lifecycle_broker.InvocationCount()==0);

   SWV5S5_CoordinatorIngressEvent invalid_ingress;
   ZeroMemory(invalid_ingress);
   invalid_ingress.event_id="INGRESS-DENIED";
   invalid_ingress.event_ordinal=7;
   SWV5S5_TestTraceSink ingress_trace;
   ok=coordinator.ProcessIngress(invalid_ingress,ingress_trace,result);
   SWV5S5_PhaseCAssert(!ok);
   SWV5S5_PhaseCAssert(result.disposition==SWV5S5_COORD_ADMISSION_DENIED);
   SWV5S5_PhaseCAssert(result.request_correlation_id=="" && result.attempt_id=="");

   SWV5S5_DeterministicInMemoryTestQueue queue;
   SWV5S5_TestQueueEvent q1,q2,out;
   q1.event_id="Q1"; q1.ordinal=1; q1.scenario_code=11;
   q2.event_id="Q2"; q2.ordinal=2; q2.scenario_code=12;
   queue.Enqueue(q1); queue.Enqueue(q2);
   SWV5S5_PhaseCAssert(queue.Pending()==2);
   SWV5S5_PhaseCAssert(queue.TryDequeue(out) && out.event_id=="Q1" && out.ordinal==1);
   SWV5S5_PhaseCAssert(queue.TryDequeue(out) && out.event_id=="Q2" && out.ordinal==2);
   SWV5S5_PhaseCAssert(!queue.TryDequeue(out));
}

#endif
