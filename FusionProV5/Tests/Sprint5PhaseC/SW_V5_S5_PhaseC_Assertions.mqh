#ifndef SW_V5_S5_PHASE_C_ASSERTIONS_MQH
#define SW_V5_S5_PHASE_C_ASSERTIONS_MQH

// TEST ONLY / NON-PRODUCTION / NO BROKER ACCESS
// Direct actual-function assertions. COMPILE ONLY; never executed in this phase.
#include "SW_V5_S5_PhaseC_TestDoubles.mqh"

int SWV5S5_PhaseCAssertionCount=0;
int SWV5S5_PhaseCAssertionFailures=0;
void SWV5S5_PhaseCAssert(const bool condition)
{ SWV5S5_PhaseCAssertionCount++; if(!condition) SWV5S5_PhaseCAssertionFailures++; }

bool SWV5S5_BuildPhaseCEvent(const string id,const ulong ordinal,SWV5S5_CoordinatorAdmissionEvent &event)
{
   ZeroMemory(event); SWV5_ContractValidationContext context;
   if(!SWV5S5_BuildClaimFixture(context,event.preparation_seed)) return false;
   event.event_id=id; event.event_ordinal=ordinal;
   event.request_correlation_id=event.preparation_seed.expected_authority_record.permit.request_identity.request_id.correlation_id;
   event.attempt_id=event.preparation_seed.expected_authority_record.permit.unique_attempt_id;
   event.normalized_payload_identity=event.preparation_seed.expected_authority_record.permit.normalization_identity;
   event.request_state=SWV5_REQUEST_SUBMISSION_PENDING; event.request_phase=SWV5_EXECUTION_PHASE_SUBMISSION;
   event.interruption_point=SWV5S5_COORD_INTERRUPT_NONE; return true;
}

bool SWV5S5_ConfigureValidClaim(const SWV5S5_CoordinatorAdmissionEvent &event,SWV5S5_ScriptedClaimAuthority &claim)
{
   SWV5_ContractValidationContext context; SWV5S5_TestContext(context,1000,3);
   SWV5S5_InvocationClaimCommand command=event.preparation_seed; SWV5S5_InvocationClaimTransition transition;
   if(!SWV5S5_PrepareInvocationClaimTransition(context,SWV5S5_TEST_RISK,command,transition)) return false;
   claim.ConfigureValid(transition); return SWV5S5_ValidateAuthoritativeClaimResult(transition,claim.scripted_result);
}

void SWV5S5_AssertCorruptClaimRejected(const int mutation)
{
   SWV5S5_DeterministicCoordinator coordinator; SWV5S5_ScriptedAdmissionPreparation prep;
   SWV5S5_ScriptedClaimAuthority claim; SWV5S5_ScriptedFakeBroker broker; SWV5S5_TestTraceSink trace;
   SWV5S5_CoordinatorAdmissionEvent event; SWV5S5_CoordinatorResult result;
   SWV5S5_PhaseCAssert(SWV5S5_BuildPhaseCEvent("BAD-"+(string)mutation,(ulong)(100+mutation),event));
   SWV5S5_PhaseCAssert(SWV5S5_ConfigureValidClaim(event,claim));
   if(mutation==1) claim.scripted_result.resulting_authority_record.authority_revision++;
   if(mutation==2) claim.scripted_result.resulting_authority_record.permit.permit_id="WRONG";
   if(mutation==3) claim.scripted_result.resulting_authority_record.permit.permit_revision++;
   if(mutation==4) claim.scripted_result.resulting_authority_record.permit.permit_digest=SWV5S5_SHA256_EMPTY;
   if(mutation==5) claim.scripted_result.resulting_authority_record.admission_snapshot_digest=SWV5S5_SHA256_EMPTY;
   if(mutation==6) claim.scripted_result.resulting_authority_record.admission_snapshot.collect_v2.hard_kill.state.latch_generation++;
   if(mutation==7) claim.scripted_result.resulting_authority_record.invocation_claim_id="WRONG";
   if(mutation==8) claim.scripted_result.resulting_authority_record.durable_record_digest=SWV5S5_SHA256_EMPTY;
   if(mutation==9) { claim.scripted_result.resulting_authority_record.claimed_at++; SWV5S5_DeriveDurableSubmissionAuthorityDigest(claim.scripted_result.resulting_authority_record,claim.scripted_result.resulting_authority_record.durable_record_digest); }
   if(mutation==10) { claim.scripted_result.resulting_authority_record.claim_ownership_lease.fence.fencing_token_digest=SWV5S5_SHA256_EMPTY; SWV5S5_DeriveDurableSubmissionAuthorityDigest(claim.scripted_result.resulting_authority_record,claim.scripted_result.resulting_authority_record.durable_record_digest); }
   bool ok=coordinator.ProcessAdmission(event,prep,claim,broker,trace,result);
   SWV5S5_PhaseCAssert(!ok && broker.InvocationCount()==0 && result.reconciliation_required);
}

void SWV5S5_RunPhaseCCompileOnlyAssertions(void)
{
   SWV5_PersistenceNamespace scope; SWV5_OwnershipFence fence; SWV5S5_TestScope(scope,fence);
   string c0,a0,i0,c1,a1,i1;
   SWV5S5_PhaseCAssert(SWV5S5_DeriveRequestBinding(scope,SWV5S5_REQUEST_BINDING_POLICY_ID,1,"INGRESS-A",0,c0,a0,i0));
   SWV5S5_PhaseCAssert(SWV5S5_DeriveRequestBinding(scope,SWV5S5_REQUEST_BINDING_POLICY_ID,1,"INGRESS-A",1,c1,a1,i1));
   SWV5S5_PhaseCAssert(c0==SWV5S5_EXPECTED_CORRELATION && i0==SWV5S5_EXPECTED_IDEMPOTENCY && a0==SWV5S5_EXPECTED_ATTEMPT_0);
   SWV5S5_PhaseCAssert(c0==c1 && i0==i1 && a1==SWV5S5_EXPECTED_ATTEMPT_1 && a0!=a1);

   SWV5S5_DeterministicCoordinator coordinator; SWV5S5_ScriptedAdmissionPreparation prep;
   SWV5S5_ScriptedClaimAuthority claim; SWV5S5_ScriptedFakeBroker broker; SWV5S5_TestTraceSink trace;
   SWV5S5_CoordinatorAdmissionEvent event; SWV5S5_CoordinatorResult result;
   SWV5S5_PhaseCAssert(SWV5S5_BuildPhaseCEvent("E1",1,event));
   SWV5S5_PhaseCAssert(SWV5S5_ConfigureValidClaim(event,claim));
   SWV5S5_PhaseCAssert(coordinator.ProcessAdmission(event,prep,claim,broker,trace,result));
   SWV5S5_PhaseCAssert(result.disposition==SWV5S5_COORD_FAKE_BROKER_INVOKED && broker.InvocationCount()==1);
   event.event_id="E2"; event.event_ordinal=2;
   SWV5S5_PhaseCAssert(coordinator.ProcessAdmission(event,prep,claim,broker,trace,result));
   SWV5S5_PhaseCAssert(result.disposition==SWV5S5_COORD_ALREADY_CLAIMED_UNCERTAIN && broker.InvocationCount()==1);
   for(int mutation=1;mutation<=10;mutation++) SWV5S5_AssertCorruptClaimRejected(mutation);

   SWV5S5_ScriptedAdmissionPreparation split; split.corrupt_prepared_command=true;
   SWV5S5_ScriptedClaimAuthority split_claim; SWV5S5_ScriptedFakeBroker split_broker; SWV5S5_TestTraceSink split_trace;
   SWV5S5_BuildPhaseCEvent("SPLIT",30,event); SWV5S5_ConfigureValidClaim(event,split_claim);
   SWV5S5_PhaseCAssert(!coordinator.ProcessAdmission(event,split,split_claim,split_broker,split_trace,result));
   SWV5S5_PhaseCAssert(split_claim.call_count==0 && split_broker.InvocationCount()==0);

   SWV5S5_ScriptedAdmissionPreparation replay_prep; SWV5S5_ScriptedClaimAuthority replay;
   SWV5S5_ScriptedFakeBroker replay_broker; SWV5S5_TestTraceSink replay_trace;
   SWV5S5_BuildPhaseCEvent("REPLAY",31,event); SWV5S5_ConfigureValidClaim(event,replay); replay.replay_prior_event_binding=true;
   SWV5S5_PhaseCAssert(!coordinator.ProcessAdmission(event,replay_prep,replay,replay_broker,replay_trace,result));
   SWV5S5_PhaseCAssert(replay_broker.InvocationCount()==0);

   SWV5S5_ScriptedAdmissionPreparation crash_prep; SWV5S5_ScriptedClaimAuthority crash_claim;
   SWV5S5_ScriptedFakeBroker crash_broker; SWV5S5_TestTraceSink crash_trace;
   SWV5S5_BuildPhaseCEvent("CRASH-BEFORE",40,event); SWV5S5_ConfigureValidClaim(event,crash_claim);
   event.interruption_point=SWV5S5_COORD_INTERRUPT_BEFORE_CLAIM;
   SWV5S5_PhaseCAssert(coordinator.ProcessAdmission(event,crash_prep,crash_claim,crash_broker,crash_trace,result));
   SWV5S5_PhaseCAssert(crash_claim.call_count==0 && crash_broker.InvocationCount()==0);
   event.event_id="RECOLLECT"; event.event_ordinal=41; event.interruption_point=SWV5S5_COORD_INTERRUPT_NONE;
   SWV5S5_PhaseCAssert(coordinator.ProcessAdmission(event,crash_prep,crash_claim,crash_broker,crash_trace,result));
   SWV5S5_PhaseCAssert(crash_prep.call_count==2 && crash_broker.InvocationCount()==1);
   SWV5S5_ScriptedAdmissionPreparation after_prep; SWV5S5_ScriptedClaimAuthority after_claim;
   SWV5S5_ScriptedFakeBroker after_broker; SWV5S5_TestTraceSink after_trace;
   SWV5S5_BuildPhaseCEvent("CRASH-AFTER",42,event); SWV5S5_ConfigureValidClaim(event,after_claim);
   event.interruption_point=SWV5S5_COORD_INTERRUPT_AFTER_CLAIM_BEFORE_BROKER;
   SWV5S5_PhaseCAssert(coordinator.ProcessAdmission(event,after_prep,after_claim,after_broker,after_trace,result));
   SWV5S5_PhaseCAssert(result.reconciliation_required && after_broker.InvocationCount()==0);
   event.event_id="AFTER-FOLLOW"; event.event_ordinal=43; event.interruption_point=SWV5S5_COORD_INTERRUPT_NONE;
   SWV5S5_PhaseCAssert(coordinator.ProcessAdmission(event,after_prep,after_claim,after_broker,after_trace,result));
   SWV5S5_PhaseCAssert(after_broker.InvocationCount()==0);

   // Frozen direct Blueprint/Ledger/Sequence controls remain compiled unchanged.
   SWV5S5_TestLedgerAndSequence();
   SWV5S5_TestBlueprintAndPermitPreparation();

   SWV5S5_ScriptedOwnershipAuthority ownership;
   SWV5S5_PhaseCAssert(coordinator.ProcessTakeover(c0,ownership,result) && result.reconciliation_required);
   SWV5S5_SubmissionAuthorityRecord claimed=claim.scripted_result.resulting_authority_record;
   SWV5S5_PhaseCAssert(coordinator.ProcessReconciliationRequired(claimed,result) && !result.fake_broker_invoked);
   SWV5S5_FakeBrokerResult ack; ack.outcome=SWV5S5_FAKE_BROKER_REQUEST_RECEIVED;
   SWV5S5_PhaseCAssert(coordinator.ProcessFakeBrokerResponse(ack,result) && result.disposition==SWV5S5_COORD_BROKER_ACKNOWLEDGED);

   SWV5S5_CoordinatorAdmissionEvent denied; SWV5S5_BuildPhaseCEvent("HK",60,denied);
   denied.preparation_seed.admission_proof.snapshot.collect_v1.hard_kill.state.state=SWV5_HARD_KILL_ACTIVE;
   denied.preparation_seed.admission_proof.snapshot.collect_v2.hard_kill.state.state=SWV5_HARD_KILL_ACTIVE;
   SWV5S5_RefreshAdversarialAdmissionEvidence(denied.preparation_seed);
   SWV5S5_ScriptedAdmissionPreparation deny_prep; SWV5S5_ScriptedClaimAuthority deny_claim;
   SWV5S5_ScriptedFakeBroker deny_broker; SWV5S5_TestTraceSink deny_trace;
   SWV5S5_PhaseCAssert(!coordinator.ProcessAdmission(denied,deny_prep,deny_claim,deny_broker,deny_trace,result));
   SWV5S5_BuildPhaseCEvent("TRUST",61,denied); denied.preparation_seed.expected_authority_record.permit.producer_trust.status=SWV5S5_TRUST_REVOKED; SWV5S5_RefreshClaimFixture(denied.preparation_seed);
   SWV5S5_PhaseCAssert(!coordinator.ProcessAdmission(denied,deny_prep,deny_claim,deny_broker,deny_trace,result));
   SWV5S5_BuildPhaseCEvent("RISK-EQUAL",62,denied); denied.preparation_seed.expected_authority_record.permit.risk_authorization.expires_at=1000; SWV5S5_RefreshClaimFixture(denied.preparation_seed);
   SWV5S5_PhaseCAssert(!coordinator.ProcessAdmission(denied,deny_prep,deny_claim,deny_broker,deny_trace,result));
   SWV5S5_BuildPhaseCEvent("RISK-AFTER",63,denied); denied.preparation_seed.expected_authority_record.permit.risk_authorization.expires_at=999; SWV5S5_RefreshClaimFixture(denied.preparation_seed);
   SWV5S5_PhaseCAssert(!coordinator.ProcessAdmission(denied,deny_prep,deny_claim,deny_broker,deny_trace,result));

   SWV5S5_DeterministicInMemoryTestQueue queue; SWV5S5_TestQueueEvent q1,q2,out;
   q1.event_id="Q1"; q1.ordinal=1; q1.scenario_code=SWV5S5_COORD_EVENT_OWNERSHIP_TAKEOVER;
   q2.event_id="Q2"; q2.ordinal=2; q2.scenario_code=SWV5S5_COORD_EVENT_RECONCILIATION_REQUIRED;
   queue.Enqueue(q1); queue.Enqueue(q2);
   SWV5S5_DeterministicTestDispatcher dispatcher;
   SWV5S5_PhaseCAssert(queue.TryDequeue(out) && dispatcher.Dispatch(coordinator,out,ownership,claimed,result));
   SWV5S5_PhaseCAssert(queue.TryDequeue(out) && dispatcher.Dispatch(coordinator,out,ownership,claimed,result));
}
#endif
