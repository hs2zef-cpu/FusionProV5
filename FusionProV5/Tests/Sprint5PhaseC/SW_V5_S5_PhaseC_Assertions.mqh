#ifndef SW_V5_S5_PHASE_C_ASSERTIONS_MQH
#define SW_V5_S5_PHASE_C_ASSERTIONS_MQH

// TEST ONLY / NON-PRODUCTION / NO BROKER ACCESS
// Direct actual-function assertions. COMPILE ONLY; never executed in this phase.
#include "SW_V5_S5_PhaseC_TestDoubles.mqh"

int SWV5S5_PhaseCAssertionCount=0;
int SWV5S5_PhaseCAssertionFailures=0;
void SWV5S5_PhaseCAssert(const bool condition)
{ SWV5S5_PhaseCAssertionCount++; if(!condition) SWV5S5_PhaseCAssertionFailures++; }

void SWV5S5_RebindCollectionDirection(SWV5S5_AdmissionAuthorityCollection &collect,
                                      const SWV5S5_SubmissionPermit &permit,
                                      const SWV5_ExecutionRequestIdentity &request,
                                      const int direction)
{
   collect.request_identity=request;
   collect.attempt_id=request.request_id.attempt_id;
   collect.request_set.requests[0].intent.request_identity=request;
   collect.request_set.requests[0].intent.direction=direction;
   collect.risk_authorization.authorization=permit.risk_authorization;
   collect.risk_authorization.current_binding.intent.request_identity=request;
   collect.risk_authorization.current_binding.intent.direction=direction;
   collect.risk_authorization.current_binding.projected.margin_evidence.request_identity=request;
   collect.risk_authorization.current_binding.projected.basket_risk_evidence.request_identity=request;
   collect.risk_authorization.current_binding.margin_authority_record=permit.margin_authority;
   collect.risk_authorization.current_binding.basket_risk_authority_record=permit.basket_risk_authority;
   collect.margin.record=permit.margin_authority;
   collect.basket_risk.record=permit.basket_risk_authority;
   collect.submission_permit.permit=permit;
   SWV5S5_DeriveCompleteRequestSetDigest(collect.request_set.requests,
                                          collect.request_set.header.request_set_digest);
}

bool SWV5S5_ConvertClaimFixtureDirection(SWV5S5_InvocationClaimCommand &command,const int direction)
{
   if(direction!=1 && direction!=-1) return false;
   SWV5S5_IngressEnvelope ingress=command.admission_proof.accepted_ingress;
   ingress.decision.action=direction; ingress.decision.direction=direction;
   ingress.decision.state=(direction==1 ? "BUY" : "SELL");
   if(!SWV5S5_DeriveIngressIdentityAndDigest(ingress,ingress.ingress_identity,ingress.payload_digest)) return false;
   SWV5S5_SubmissionPermit permit=command.expected_authority_record.permit;
   string correlation,attempt,idempotency;
   if(!SWV5S5_DeriveRequestBinding(permit.persistence_namespace,SWV5S5_REQUEST_BINDING_POLICY_ID,
      SWV5S5_REQUEST_BINDING_POLICY_VERSION,ingress.ingress_identity,0,correlation,attempt,idempotency)) return false;
   SWV5_ExecutionRequestIdentity request=permit.request_identity;
   request.request_id.correlation_id=correlation; request.request_id.attempt_id=attempt;
   request.request_id.parent_attempt_id=""; request.request_id.monotonic_sequence=1;
   request.request_id.created_at=900; request.idempotency_key=idempotency;
   permit.request_identity=request; permit.unique_attempt_id=attempt;
   permit.risk_authorization.request_identity=request;
   permit.risk_authorization.authorized_direction=direction;
   permit.margin_authority.request_identity=request; permit.margin_authority.direction=direction;
   permit.basket_risk_authority.request_identity=request;
   command.expected_authority_record.permit=permit;
   command.admission_proof.accepted_ingress=ingress;
   command.admission_proof.trust_scope.ingress_identity=ingress.ingress_identity;
   SWV5S5_RebindCollectionDirection(command.admission_proof.snapshot.collect_v1,permit,request,direction);
   SWV5S5_RebindCollectionDirection(command.admission_proof.snapshot.collect_v2,permit,request,direction);
   return SWV5S5_RefreshClaimFixture(command);
}

bool SWV5S5_BuildCoordinatorFixture(const string id,const ulong ordinal,const int action,
                                    SWV5S5_CoordinatorIngressEvent &event,
                                    SWV5S5_CoordinatorMaterializationInput &materialization,
                                    SWV5S5_ScriptedLedgerAuthority &ledger,
                                    SWV5S5_ScriptedRequestSequenceAuthority &sequence,
                                    SWV5S5_InvocationClaimCommand &claim_command)
{
   SWV5_ContractValidationContext claim_context;
   if(!SWV5S5_BuildClaimFixture(claim_context,claim_command)) return false;
   if((action==1 || action==-1) && !SWV5S5_ConvertClaimFixtureDirection(claim_command,action)) return false;
   SWV5S5_SubmissionPermit permit=claim_command.expected_authority_record.permit;
   ZeroMemory(event); event.event_id=id; event.event_ordinal=ordinal;
   event.persistence_namespace=permit.persistence_namespace;
   SWV5S5_TestContext(event.context,900,ordinal);
   event.ingress=claim_command.admission_proof.accepted_ingress;
   if(action==0 || action==9)
   {
      event.ingress.decision.action=action; event.ingress.decision.direction=0;
      event.ingress.decision.state=(action==0 ? "WAIT" : "BLOCKED");
      if(!SWV5S5_DeriveIngressIdentityAndDigest(event.ingress,event.ingress.ingress_identity,
                                                event.ingress.payload_digest)) return false;
      claim_command.admission_proof.trust_scope.ingress_identity=event.ingress.ingress_identity;
   }
   event.freshness.policy_id=SWV5S5_POLICY_ID;
   event.freshness.clock_id="TEST-CLOCK";
   event.freshness.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   event.freshness.max_age_seconds=200; event.freshness.max_future_skew_seconds=0;
   event.current_trust=permit.producer_trust;
   event.trust_anchor=claim_command.admission_proof.trust_anchor;
   event.trust_scope=claim_command.admission_proof.trust_scope;
   event.trust_scope.ingress_identity=event.ingress.ingress_identity;
   if(!ledger.Configure(permit.persistence_namespace,permit.ownership_fence,event.current_trust,event.ingress) ||
      !sequence.Configure(permit.persistence_namespace,permit.ownership_fence)) return false;
   ZeroMemory(materialization);
   materialization.event_id=id; materialization.event_ordinal=ordinal;
   materialization.context=event.context; materialization.accepted_ingress=event.ingress;
   materialization.normalized_payload=permit.normalized_payload;
   materialization.normalization_identity=permit.normalization_identity;
   materialization.risk_authorization=permit.risk_authorization;
   return true;
}

bool SWV5S5_RunDirectMaterialization(const string id,const ulong ordinal,const int direction,
                                     const int ledger_read_corruption,
                                     const int ledger_operation_corruption,
                                     const int sequence_read_corruption,
                                     const int sequence_operation_corruption,
                                     const int progression_mutation,
                                     SWV5S5_CoordinatorMaterializationResult &materialized,
                                     SWV5S5_ScriptedLedgerAuthority &ledger,
                                     SWV5S5_ScriptedRequestSequenceAuthority &sequence)
{
   SWV5S5_CoordinatorIngressEvent ingress_event;
   SWV5S5_CoordinatorMaterializationInput materialization_input;
   SWV5S5_InvocationClaimCommand claim_command;
   if(!SWV5S5_BuildCoordinatorFixture(id,ordinal,direction,ingress_event,materialization_input,ledger,sequence,claim_command)) return false;
   ledger.read_corruption=ledger_read_corruption;
   ledger.operation_corruption=ledger_operation_corruption;
   sequence.read_corruption=sequence_read_corruption;
   sequence.operation_corruption=sequence_operation_corruption;
   SWV5S5_DeterministicCoordinator coordinator; SWV5S5_TestTraceSink trace;
   SWV5S5_CoordinatorLedgerEvaluation evaluation;
   SWV5S5_IngressLedgerIndexEntry ledger_entries[];
   SWV5S5_IngressLedgerRecord ledger_records[];
   SWV5S5_CoordinatorResult ingress_result;
   if(!coordinator.ProcessIngress(ingress_event,ledger,trace,evaluation,ledger_entries,ledger_records,ingress_result)) return false;
   materialization_input.ledger=evaluation;
   SWV5S5_ScriptedBlueprintAuthority blueprint;
   SWV5S5_ScriptedRequestProgressionAuthority progression; progression.changed_at=materialization_input.context.clock_time;
   progression.mutation=progression_mutation;
   SWV5S5_ScriptedExecutionLifecycleAuthority lifecycle;
   return coordinator.MaterializeAndProgress(materialization_input,ledger_entries,ledger_records,ledger,sequence,blueprint,
                                              progression,lifecycle,materialized);
}

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

void SWV5S5_AssertDirectC2Authorities(void)
{
   SWV5S5_CoordinatorMaterializationResult materialized;
   SWV5S5_ScriptedLedgerAuthority ledger;
   SWV5S5_ScriptedRequestSequenceAuthority sequence;
   SWV5S5_PhaseCAssert(SWV5S5_RunDirectMaterialization("C2-BUY",200,1,0,0,0,0,0,
      materialized,ledger,sequence));
   SWV5S5_PhaseCAssert(materialized.binding.attempt_ordinal==0 &&
      materialized.sequence.disposition==SWV5S5_SEQUENCE_RESERVED_NEW &&
      materialized.progressed_request.intent.direction==1);

   SWV5S5_ScriptedLedgerAuthority sell_ledger;
   SWV5S5_ScriptedRequestSequenceAuthority sell_sequence;
   SWV5S5_PhaseCAssert(SWV5S5_RunDirectMaterialization("C2-SELL",201,-1,0,0,0,0,0,
      materialized,sell_ledger,sell_sequence));
   SWV5S5_PhaseCAssert(materialized.progressed_request.intent.direction==-1);

   // The direct SELL path must retain its direction through the authoritative
   // Claim boundary and into the fake-broker invocation envelope.
   SWV5S5_CoordinatorAdmissionEvent sell_admission;
   SWV5S5_PhaseCAssert(SWV5S5_BuildPhaseCEvent("C2-SELL-ADMISSION",202,sell_admission));
   SWV5S5_PhaseCAssert(SWV5S5_ConvertClaimFixtureDirection(sell_admission.preparation_seed,-1));
   SWV5S5_SubmissionPermit sell_permit=sell_admission.preparation_seed.expected_authority_record.permit;
   sell_admission.request_correlation_id=sell_permit.request_identity.request_id.correlation_id;
   sell_admission.attempt_id=sell_permit.unique_attempt_id;
   sell_admission.normalized_payload_identity=sell_permit.normalization_identity;
   SWV5S5_ScriptedAdmissionPreparation sell_preparation;
   SWV5S5_ScriptedClaimAuthority sell_claim;
   SWV5S5_PhaseCAssert(SWV5S5_ConfigureValidClaim(sell_admission,sell_claim));
   SWV5S5_ScriptedFakeBroker sell_broker; SWV5S5_TestTraceSink sell_trace;
   SWV5S5_CoordinatorResult sell_result;
   SWV5S5_DeterministicCoordinator sell_coordinator;
   SWV5S5_PhaseCAssert(sell_coordinator.ProcessAdmission(sell_admission,sell_preparation,sell_claim,
                                                          sell_broker,sell_trace,sell_result));
   SWV5S5_PhaseCAssert(sell_result.disposition==SWV5S5_COORD_FAKE_BROKER_INVOKED &&
      sell_broker.InvocationCount()==1 && sell_broker.invocations[0].direction==-1);

   SWV5S5_ScriptedLedgerAuthority buy_reversal_ledger;
   SWV5S5_ScriptedRequestSequenceAuthority buy_reversal_sequence;
   SWV5S5_PhaseCAssert(!SWV5S5_RunDirectMaterialization("BUY-TO-SELL",203,1,0,0,0,0,1,
      materialized,buy_reversal_ledger,buy_reversal_sequence));

   // Complete progression comparator: direction reversal plus every immutable
   // content class named by C.2 must fail before Admission.
   for(int mutation=1;mutation<=16;mutation++)
   {
      SWV5S5_ScriptedLedgerAuthority mutation_ledger;
      SWV5S5_ScriptedRequestSequenceAuthority mutation_sequence;
      SWV5S5_PhaseCAssert(!SWV5S5_RunDirectMaterialization("PROGRESS-MUT-"+(string)mutation,
         (ulong)(220+mutation),(mutation==1 ? -1 : 1),0,0,0,0,mutation,
         materialized,mutation_ledger,mutation_sequence));
   }

   // Complete current Ledger snapshot corruption must fail closed.
   for(int corruption=1;corruption<=2;corruption++)
   {
      SWV5S5_ScriptedLedgerAuthority corrupt_ledger;
      SWV5S5_ScriptedRequestSequenceAuthority valid_sequence;
      SWV5S5_PhaseCAssert(!SWV5S5_RunDirectMaterialization("LEDGER-HEADER-"+(string)corruption,
         (ulong)(250+corruption),1,corruption,0,0,0,0,materialized,corrupt_ledger,valid_sequence));
   }

   SWV5S5_CoordinatorIngressEvent duplicate_event;
   SWV5S5_CoordinatorMaterializationInput duplicate_input;
   SWV5S5_InvocationClaimCommand duplicate_claim;
   SWV5S5_ScriptedLedgerAuthority duplicate_ledger;
   SWV5S5_ScriptedRequestSequenceAuthority duplicate_sequence;
   SWV5S5_PhaseCAssert(SWV5S5_BuildCoordinatorFixture("LEDGER-DUP",270,1,duplicate_event,
      duplicate_input,duplicate_ledger,duplicate_sequence,duplicate_claim));
   SWV5S5_DeterministicCoordinator coordinator; SWV5S5_TestTraceSink trace;
   SWV5S5_CoordinatorLedgerEvaluation evaluation;
   SWV5S5_IngressLedgerIndexEntry ledger_entries[];
   SWV5S5_IngressLedgerRecord ledger_records[];
   SWV5S5_CoordinatorResult coordinator_result;
   SWV5S5_PhaseCAssert(coordinator.ProcessIngress(duplicate_event,duplicate_ledger,trace,evaluation,
      ledger_entries,ledger_records,coordinator_result));
   duplicate_input.ledger=evaluation;
   SWV5S5_ScriptedBlueprintAuthority blueprint;
   SWV5S5_ScriptedRequestProgressionAuthority progression; progression.changed_at=900;
   SWV5S5_ScriptedExecutionLifecycleAuthority lifecycle;
   SWV5S5_PhaseCAssert(coordinator.MaterializeAndProgress(duplicate_input,ledger_entries,ledger_records,
      duplicate_ledger,duplicate_sequence,blueprint,progression,lifecycle,materialized));
   int sequence_calls=duplicate_sequence.call_count;
   SWV5S5_PhaseCAssert(coordinator.ProcessIngress(duplicate_event,duplicate_ledger,trace,evaluation,
      ledger_entries,ledger_records,coordinator_result));
   SWV5S5_PhaseCAssert(evaluation.disposition==SWV5S5_INGRESS_EVALUATION_DUPLICATE &&
      coordinator_result.disposition==SWV5S5_COORD_LEDGER_DUPLICATE &&
      duplicate_sequence.call_count==sequence_calls);
   duplicate_input.ledger=evaluation;
   duplicate_input.ledger.disposition=SWV5S5_INGRESS_EVALUATION_NEW;
   int duplicate_blueprint_calls=blueprint.call_count;
   SWV5S5_PhaseCAssert(!coordinator.MaterializeAndProgress(duplicate_input,ledger_entries,ledger_records,
      duplicate_ledger,duplicate_sequence,blueprint,progression,lifecycle,materialized));
   SWV5S5_PhaseCAssert(duplicate_sequence.call_count==sequence_calls &&
      blueprint.call_count==duplicate_blueprint_calls);
   for(int corruption=3;corruption<=7;corruption++)
   {
      duplicate_ledger.read_corruption=corruption;
      SWV5S5_PhaseCAssert(!coordinator.ProcessIngress(duplicate_event,duplicate_ledger,trace,evaluation,
         ledger_entries,ledger_records,coordinator_result));
   }
   duplicate_ledger.read_corruption=0;

   // Frozen-shaped Ledger operation result cannot authorize without a complete
   // canonical post-state or exact event/proposal binding.
   for(int corruption=1;corruption<=4;corruption++)
   {
      SWV5S5_ScriptedLedgerAuthority operation_ledger;
      SWV5S5_ScriptedRequestSequenceAuthority valid_sequence;
      SWV5S5_PhaseCAssert(!SWV5S5_RunDirectMaterialization("LEDGER-OP-"+(string)corruption,
         (ulong)(280+corruption),1,0,corruption,0,0,0,materialized,operation_ledger,valid_sequence));
   }

   // Sequence current state, event binding, authoritative result, and resulting
   // complete state are independently checked.
   for(int corruption=1;corruption<=2;corruption++)
   {
      SWV5S5_ScriptedLedgerAuthority valid_ledger;
      SWV5S5_ScriptedRequestSequenceAuthority corrupt_sequence;
      SWV5S5_PhaseCAssert(!SWV5S5_RunDirectMaterialization("SEQ-READ-"+(string)corruption,
         (ulong)(300+corruption),1,0,0,corruption,0,0,materialized,valid_ledger,corrupt_sequence));
   }
   for(int corruption=1;corruption<=7;corruption++)
   {
      SWV5S5_ScriptedLedgerAuthority valid_ledger;
      SWV5S5_ScriptedRequestSequenceAuthority corrupt_sequence;
      SWV5S5_PhaseCAssert(!SWV5S5_RunDirectMaterialization("SEQ-OP-"+(string)corruption,
         (ulong)(310+corruption),1,0,0,0,corruption,0,materialized,valid_ledger,corrupt_sequence));
   }
   for(int corruption=9;corruption<=10;corruption++)
   {
      SWV5S5_ScriptedLedgerAuthority valid_ledger;
      SWV5S5_ScriptedRequestSequenceAuthority corrupt_sequence;
      SWV5S5_PhaseCAssert(!SWV5S5_RunDirectMaterialization("SEQ-POST-"+(string)corruption,
         (ulong)(330+corruption),1,0,0,0,corruption,0,materialized,valid_ledger,corrupt_sequence));
   }

   // Orphan reservation replay: complete second Ledger still consumes the same
   // authoritative sequence, while a changed-sequence post-state fails.
   SWV5S5_CoordinatorIngressEvent replay_event;
   SWV5S5_CoordinatorMaterializationInput replay_input;
   SWV5S5_InvocationClaimCommand replay_claim;
   SWV5S5_ScriptedLedgerAuthority replay_ledger;
   SWV5S5_ScriptedRequestSequenceAuthority ignored_sequence;
   SWV5S5_PhaseCAssert(SWV5S5_BuildCoordinatorFixture("SEQ-IDEMPOTENT",350,1,replay_event,replay_input,
      replay_ledger,ignored_sequence,replay_claim));
   SWV5S5_PhaseCAssert(coordinator.ProcessIngress(replay_event,replay_ledger,trace,evaluation,
      ledger_entries,ledger_records,coordinator_result));
   replay_input.ledger=evaluation; progression.changed_at=900;
   SWV5S5_PhaseCAssert(coordinator.MaterializeAndProgress(replay_input,ledger_entries,ledger_records,
      replay_ledger,duplicate_sequence,blueprint,progression,lifecycle,materialized));
   SWV5S5_PhaseCAssert(materialized.sequence.disposition==SWV5S5_SEQUENCE_EXISTING_IDEMPOTENT &&
      materialized.sequence.reserved_sequence==1);

   SWV5S5_ScriptedLedgerAuthority changed_ledger;
   SWV5S5_ScriptedRequestSequenceAuthority ignored_again;
   SWV5S5_PhaseCAssert(SWV5S5_BuildCoordinatorFixture("SEQ-CHANGED",351,1,replay_event,replay_input,
      changed_ledger,ignored_again,replay_claim));
   SWV5S5_PhaseCAssert(coordinator.ProcessIngress(replay_event,changed_ledger,trace,evaluation,
      ledger_entries,ledger_records,coordinator_result));
   replay_input.ledger=evaluation; duplicate_sequence.operation_corruption=8;
   SWV5S5_PhaseCAssert(!coordinator.MaterializeAndProgress(replay_input,ledger_entries,ledger_records,
      changed_ledger,duplicate_sequence,blueprint,progression,lifecycle,materialized));

   // WAIT and BLOCKED are complete Ledger records but never allocate sequence or request.
   for(int no_entry=0;no_entry<=1;no_entry++)
   {
      SWV5S5_CoordinatorIngressEvent no_entry_event;
      SWV5S5_CoordinatorMaterializationInput no_entry_input;
      SWV5S5_InvocationClaimCommand no_entry_claim;
      SWV5S5_ScriptedLedgerAuthority no_entry_ledger;
      SWV5S5_ScriptedRequestSequenceAuthority no_entry_sequence;
      int action=(no_entry==0 ? 0 : 9);
      SWV5S5_PhaseCAssert(SWV5S5_BuildCoordinatorFixture("NO-ENTRY-"+(string)action,
         (ulong)(370+no_entry),action,no_entry_event,no_entry_input,no_entry_ledger,no_entry_sequence,no_entry_claim));
      SWV5S5_PhaseCAssert(coordinator.ProcessIngress(no_entry_event,no_entry_ledger,trace,evaluation,
         ledger_entries,ledger_records,coordinator_result));
      SWV5S5_PhaseCAssert(coordinator_result.disposition==SWV5S5_COORD_NO_ENTRY &&
         evaluation.matched_record.lifecycle_state==SWV5S5_REJECTED_NO_ENTRY &&
         no_entry_sequence.call_count==0);
   }

   // The injected V5 lifecycle authority is mandatory; a denial blocks progression.
   SWV5S5_CoordinatorIngressEvent lifecycle_event;
   SWV5S5_CoordinatorMaterializationInput lifecycle_input;
   SWV5S5_InvocationClaimCommand lifecycle_claim;
   SWV5S5_ScriptedLedgerAuthority lifecycle_ledger;
   SWV5S5_ScriptedRequestSequenceAuthority lifecycle_sequence;
   SWV5S5_BuildCoordinatorFixture("V5-DENY",390,1,lifecycle_event,lifecycle_input,lifecycle_ledger,
                                  lifecycle_sequence,lifecycle_claim);
   coordinator.ProcessIngress(lifecycle_event,lifecycle_ledger,trace,evaluation,ledger_entries,ledger_records,
                              coordinator_result);
   lifecycle_input.ledger=evaluation; lifecycle.allow=false; progression.changed_at=900; progression.mutation=0;
   SWV5S5_PhaseCAssert(!coordinator.MaterializeAndProgress(lifecycle_input,ledger_entries,ledger_records,
      lifecycle_ledger,lifecycle_sequence,blueprint,progression,lifecycle,materialized));
}

void SWV5S5_AssertFullQueuedDirectional(const int direction,const ulong base_ordinal)
{
   SWV5S5_CoordinatorIngressEvent ingress_event;
   SWV5S5_CoordinatorMaterializationInput materialization;
   SWV5S5_InvocationClaimCommand claim_command;
   SWV5S5_ScriptedLedgerAuthority ledger;
   SWV5S5_ScriptedRequestSequenceAuthority sequence;
   SWV5S5_PhaseCAssert(SWV5S5_BuildCoordinatorFixture((direction==1 ? "QUEUE-BUY" : "QUEUE-SELL"),
      base_ordinal,direction,ingress_event,materialization,ledger,sequence,claim_command));
   SWV5S5_CoordinatorAdmissionEvent admission_event; ZeroMemory(admission_event);
   admission_event.preparation_seed=claim_command;
   admission_event.interruption_point=SWV5S5_COORD_INTERRUPT_NONE;
   SWV5S5_ScriptedAdmissionPreparation preparation;
   SWV5S5_ScriptedClaimAuthority claim;
   SWV5S5_PhaseCAssert(SWV5S5_ConfigureValidClaim(admission_event,claim));
   SWV5S5_ScriptedBlueprintAuthority blueprint;
   SWV5S5_ScriptedRequestProgressionAuthority progression; progression.changed_at=900;
   SWV5S5_ScriptedExecutionLifecycleAuthority lifecycle;
   SWV5S5_ScriptedOwnershipAuthority ownership;
   SWV5S5_ScriptedFakeBroker fake_broker;
   SWV5S5_TestTraceSink trace;
   SWV5S5_FakeBrokerResult response; response.outcome=SWV5S5_FAKE_BROKER_REQUEST_RECEIVED;
   response.scripted_code="QUEUE_ACK_NOT_CONFIRMATION";
   SWV5S5_SubmissionAuthorityRecord claimed_record=claim.scripted_result.resulting_authority_record;
   SWV5S5_CoordinatorLedgerEvaluation ledger_evaluation;
   SWV5S5_IngressLedgerIndexEntry ledger_entries[];
   SWV5S5_IngressLedgerRecord ledger_records[];
   SWV5S5_CoordinatorMaterializationResult materialized;
   SWV5S5_CoordinatorResult result;
   SWV5S5_DeterministicCoordinator coordinator;
   SWV5S5_DeterministicTestDispatcher dispatcher;
   SWV5S5_DeterministicInMemoryTestQueue queue;
   SWV5S5_TestQueueEvent event;
   event.kind=SWV5S5_COORD_EVENT_ACCEPTED_INGRESS; event.event_id="Q-INGRESS"; event.ordinal=base_ordinal;
   queue.Enqueue(event);
   event.kind=SWV5S5_COORD_EVENT_REQUEST_PROGRESSION; event.event_id="Q-PROGRESS"; event.ordinal=base_ordinal+1;
   queue.Enqueue(event);
   event.kind=SWV5S5_COORD_EVENT_SUBMISSION_ADMISSION; event.event_id="Q-ADMISSION"; event.ordinal=base_ordinal+2;
   queue.Enqueue(event);
   event.kind=SWV5S5_COORD_EVENT_FAKE_BROKER_RESPONSE; event.event_id="Q-ACK"; event.ordinal=base_ordinal+3;
   queue.Enqueue(event);
   bool saw_progress=false,saw_admission=false,saw_ack=false;
   SWV5S5_TestQueueEvent dequeued;
   while(queue.TryDequeue(dequeued))
   {
      bool ok=dispatcher.Dispatch(coordinator,dequeued,ingress_event,materialization,admission_event,response,
         claimed_record,ledger,sequence,blueprint,progression,lifecycle,preparation,claim,ownership,
         fake_broker,trace,ledger_evaluation,ledger_entries,ledger_records,materialized,result);
      SWV5S5_PhaseCAssert(ok);
      if(dequeued.kind==SWV5S5_COORD_EVENT_REQUEST_PROGRESSION)
         saw_progress=(materialized.disposition==SWV5S5_COORD_REQUEST_SUBMISSION_READY &&
                       materialized.progressed_request.intent.direction==direction);
      if(dequeued.kind==SWV5S5_COORD_EVENT_SUBMISSION_ADMISSION)
         saw_admission=(result.disposition==SWV5S5_COORD_FAKE_BROKER_INVOKED);
      if(dequeued.kind==SWV5S5_COORD_EVENT_FAKE_BROKER_RESPONSE)
         saw_ack=(result.disposition==SWV5S5_COORD_BROKER_ACKNOWLEDGED);
   }
   SWV5S5_PhaseCAssert(saw_progress && saw_admission && saw_ack);
   SWV5S5_PhaseCAssert(sequence.call_count==1 && blueprint.call_count==1 && progression.call_count==1);
   SWV5S5_PhaseCAssert(fake_broker.InvocationCount()==1 && fake_broker.invocations[0].direction==direction);
}

void SWV5S5_AssertQueuedDirectionReversalRejected(const int initial_direction,const ulong base_ordinal)
{
   SWV5S5_CoordinatorIngressEvent ingress_event;
   SWV5S5_CoordinatorMaterializationInput materialization;
   SWV5S5_InvocationClaimCommand claim_command;
   SWV5S5_ScriptedLedgerAuthority ledger;
   SWV5S5_ScriptedRequestSequenceAuthority sequence;
   SWV5S5_PhaseCAssert(SWV5S5_BuildCoordinatorFixture("QUEUE-REVERSAL-"+(string)initial_direction,
      base_ordinal,initial_direction,ingress_event,materialization,ledger,sequence,claim_command));
   SWV5S5_CoordinatorAdmissionEvent admission_event; ZeroMemory(admission_event);
   admission_event.preparation_seed=claim_command;
   SWV5S5_ScriptedBlueprintAuthority blueprint;
   SWV5S5_ScriptedRequestProgressionAuthority progression;
   progression.changed_at=900; progression.mutation=1;
   SWV5S5_ScriptedExecutionLifecycleAuthority lifecycle;
   SWV5S5_ScriptedAdmissionPreparation preparation;
   SWV5S5_ScriptedClaimAuthority claim;
   SWV5S5_ScriptedOwnershipAuthority ownership;
   SWV5S5_ScriptedFakeBroker fake_broker; SWV5S5_TestTraceSink trace;
   SWV5S5_FakeBrokerResult response; SWV5S5_SubmissionAuthorityRecord claimed_record;
   SWV5S5_CoordinatorLedgerEvaluation ledger_evaluation;
   SWV5S5_IngressLedgerIndexEntry ledger_entries[]; SWV5S5_IngressLedgerRecord ledger_records[];
   SWV5S5_CoordinatorMaterializationResult materialized; SWV5S5_CoordinatorResult result;
   SWV5S5_DeterministicCoordinator coordinator; SWV5S5_DeterministicTestDispatcher dispatcher;
   SWV5S5_TestQueueEvent event;
   event.kind=SWV5S5_COORD_EVENT_ACCEPTED_INGRESS; event.event_id="REVERSAL-INGRESS";
   event.ordinal=base_ordinal;
   SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,event,ingress_event,materialization,admission_event,
      response,claimed_record,ledger,sequence,blueprint,progression,lifecycle,preparation,claim,ownership,
      fake_broker,trace,ledger_evaluation,ledger_entries,ledger_records,materialized,result));
   event.kind=SWV5S5_COORD_EVENT_REQUEST_PROGRESSION; event.event_id="REVERSAL-PROGRESSION";
   event.ordinal=base_ordinal+1;
   SWV5S5_PhaseCAssert(!dispatcher.Dispatch(coordinator,event,ingress_event,materialization,admission_event,
      response,claimed_record,ledger,sequence,blueprint,progression,lifecycle,preparation,claim,ownership,
      fake_broker,trace,ledger_evaluation,ledger_entries,ledger_records,materialized,result));
   SWV5S5_PhaseCAssert(progression.call_count==1 && claim.call_count==0 && fake_broker.InvocationCount()==0);
}

void SWV5S5_AssertQueuedC2Controls(void)
{
   SWV5S5_AssertFullQueuedDirectional(1,500);
   SWV5S5_AssertFullQueuedDirectional(-1,510);
   SWV5S5_AssertQueuedDirectionReversalRejected(1,520);
   SWV5S5_AssertQueuedDirectionReversalRejected(-1,523);

   // Duplicate ingress and duplicate admission remain one sequence, one
   // materialization, and one broker invocation.
   SWV5S5_CoordinatorIngressEvent ingress_event;
   SWV5S5_CoordinatorMaterializationInput materialization;
   SWV5S5_InvocationClaimCommand claim_command;
   SWV5S5_ScriptedLedgerAuthority ledger;
   SWV5S5_ScriptedRequestSequenceAuthority sequence;
   SWV5S5_PhaseCAssert(SWV5S5_BuildCoordinatorFixture("QUEUE-DUP",530,1,ingress_event,materialization,
      ledger,sequence,claim_command));
   SWV5S5_CoordinatorAdmissionEvent admission_event; ZeroMemory(admission_event);
   admission_event.preparation_seed=claim_command;
   SWV5S5_ScriptedAdmissionPreparation preparation;
   SWV5S5_ScriptedClaimAuthority claim; SWV5S5_PhaseCAssert(SWV5S5_ConfigureValidClaim(admission_event,claim));
   SWV5S5_ScriptedBlueprintAuthority blueprint;
   SWV5S5_ScriptedRequestProgressionAuthority progression; progression.changed_at=900;
   SWV5S5_ScriptedExecutionLifecycleAuthority lifecycle;
   SWV5S5_ScriptedOwnershipAuthority ownership;
   SWV5S5_ScriptedFakeBroker fake_broker; SWV5S5_TestTraceSink trace;
   SWV5S5_FakeBrokerResult response; response.outcome=SWV5S5_FAKE_BROKER_REQUEST_RECEIVED;
   SWV5S5_SubmissionAuthorityRecord claimed_record=claim.scripted_result.resulting_authority_record;
   SWV5S5_CoordinatorLedgerEvaluation ledger_evaluation;
   SWV5S5_IngressLedgerIndexEntry ledger_entries[]; SWV5S5_IngressLedgerRecord ledger_records[];
   SWV5S5_CoordinatorMaterializationResult materialized; SWV5S5_CoordinatorResult result;
   SWV5S5_DeterministicCoordinator coordinator; SWV5S5_DeterministicTestDispatcher dispatcher;
   SWV5S5_DeterministicInMemoryTestQueue queue; SWV5S5_TestQueueEvent event,dequeued;
   event.kind=SWV5S5_COORD_EVENT_ACCEPTED_INGRESS; event.event_id="DUP-INGRESS-1"; event.ordinal=530; queue.Enqueue(event);
   event.kind=SWV5S5_COORD_EVENT_REQUEST_PROGRESSION; event.event_id="DUP-PROGRESS"; event.ordinal=531; queue.Enqueue(event);
   event.kind=SWV5S5_COORD_EVENT_SUBMISSION_ADMISSION; event.event_id="DUP-ADMISSION-1"; event.ordinal=532; queue.Enqueue(event);
   event.kind=SWV5S5_COORD_EVENT_ACCEPTED_INGRESS; event.event_id="DUP-INGRESS-2"; event.ordinal=533; queue.Enqueue(event);
   event.kind=SWV5S5_COORD_EVENT_SUBMISSION_ADMISSION; event.event_id="DUP-ADMISSION-2"; event.ordinal=534; queue.Enqueue(event);
   while(queue.TryDequeue(dequeued))
      SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,dequeued,ingress_event,materialization,admission_event,
         response,claimed_record,ledger,sequence,blueprint,progression,lifecycle,preparation,claim,ownership,
         fake_broker,trace,ledger_evaluation,ledger_entries,ledger_records,materialized,result));
   SWV5S5_PhaseCAssert(sequence.call_count==1 && blueprint.call_count==1 && progression.call_count==1 &&
      fake_broker.InvocationCount()==1);

   // Two distinct directional ingresses share one complete Ledger and one
   // namespace Sequence authority, producing sequences 1 and 2 deterministically.
   SWV5S5_CoordinatorIngressEvent two_event;
   SWV5S5_CoordinatorMaterializationInput two_materialization;
   SWV5S5_InvocationClaimCommand two_claim_command;
   SWV5S5_ScriptedLedgerAuthority two_ledger;
   SWV5S5_ScriptedRequestSequenceAuthority two_sequence;
   SWV5S5_PhaseCAssert(SWV5S5_BuildCoordinatorFixture("TWO-BUY",540,1,two_event,two_materialization,
      two_ledger,two_sequence,two_claim_command));
   SWV5S5_CoordinatorAdmissionEvent two_admission; ZeroMemory(two_admission);
   SWV5S5_ScriptedBlueprintAuthority two_blueprint;
   SWV5S5_ScriptedRequestProgressionAuthority two_progression; two_progression.changed_at=900;
   SWV5S5_ScriptedExecutionLifecycleAuthority two_lifecycle;
   SWV5S5_ScriptedAdmissionPreparation two_preparation;
   SWV5S5_ScriptedClaimAuthority two_claim;
   SWV5S5_ScriptedOwnershipAuthority two_ownership;
   SWV5S5_ScriptedFakeBroker two_broker; SWV5S5_TestTraceSink two_trace;
   SWV5S5_FakeBrokerResult two_response; SWV5S5_SubmissionAuthorityRecord two_record;
   SWV5S5_CoordinatorLedgerEvaluation two_evaluation;
   SWV5S5_IngressLedgerIndexEntry two_entries[]; SWV5S5_IngressLedgerRecord two_records[];
   SWV5S5_CoordinatorMaterializationResult first_request,second_request; SWV5S5_CoordinatorResult two_result;
   event.kind=SWV5S5_COORD_EVENT_ACCEPTED_INGRESS; event.event_id="TWO-BUY-INGRESS"; event.ordinal=540;
   SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,event,two_event,two_materialization,two_admission,
      two_response,two_record,two_ledger,two_sequence,two_blueprint,two_progression,two_lifecycle,
      two_preparation,two_claim,two_ownership,two_broker,two_trace,two_evaluation,two_entries,two_records,
      first_request,two_result));
   event.kind=SWV5S5_COORD_EVENT_REQUEST_PROGRESSION; event.event_id="TWO-BUY-PROGRESS"; event.ordinal=541;
   SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,event,two_event,two_materialization,two_admission,
      two_response,two_record,two_ledger,two_sequence,two_blueprint,two_progression,two_lifecycle,
      two_preparation,two_claim,two_ownership,two_broker,two_trace,two_evaluation,two_entries,two_records,
      first_request,two_result));
   two_event.ingress.publication.publication_sequence++;
   two_event.ingress.decision.action=-1; two_event.ingress.decision.direction=-1; two_event.ingress.decision.state="SELL";
   SWV5S5_DeriveIngressIdentityAndDigest(two_event.ingress,two_event.ingress.ingress_identity,two_event.ingress.payload_digest);
   two_event.trust_scope.ingress_identity=two_event.ingress.ingress_identity;
   two_materialization.accepted_ingress=two_event.ingress;
   string second_correlation,second_attempt,second_idempotency;
   SWV5S5_DeriveRequestBinding(two_event.persistence_namespace,SWV5S5_REQUEST_BINDING_POLICY_ID,
      SWV5S5_REQUEST_BINDING_POLICY_VERSION,two_event.ingress.ingress_identity,0,
      second_correlation,second_attempt,second_idempotency);
   SWV5_ExecutionRequestIdentity second_identity=two_materialization.risk_authorization.request_identity;
   second_identity.request_id.correlation_id=second_correlation;
   second_identity.request_id.attempt_id=second_attempt;
   second_identity.request_id.parent_attempt_id="";
   second_identity.request_id.monotonic_sequence=2;
   second_identity.request_id.created_at=900;
   second_identity.idempotency_key=second_idempotency;
   two_materialization.risk_authorization.request_identity=second_identity;
   two_materialization.risk_authorization.authorized_direction=-1;
   event.kind=SWV5S5_COORD_EVENT_ACCEPTED_INGRESS; event.event_id="TWO-SELL-INGRESS"; event.ordinal=542;
   SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,event,two_event,two_materialization,two_admission,
      two_response,two_record,two_ledger,two_sequence,two_blueprint,two_progression,two_lifecycle,
      two_preparation,two_claim,two_ownership,two_broker,two_trace,two_evaluation,two_entries,two_records,
      second_request,two_result));
   event.kind=SWV5S5_COORD_EVENT_REQUEST_PROGRESSION; event.event_id="TWO-SELL-PROGRESS"; event.ordinal=543;
   SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,event,two_event,two_materialization,two_admission,
      two_response,two_record,two_ledger,two_sequence,two_blueprint,two_progression,two_lifecycle,
      two_preparation,two_claim,two_ownership,two_broker,two_trace,two_evaluation,two_entries,two_records,
      second_request,two_result));
   SWV5S5_PhaseCAssert(first_request.sequence.reserved_sequence==1 && second_request.sequence.reserved_sequence==2 &&
      first_request.binding.logical_correlation_id!=second_request.binding.logical_correlation_id &&
      first_request.binding.attempt_ordinal==0 && second_request.binding.attempt_ordinal==0 &&
      first_request.progressed_request.intent.direction==1 && second_request.progressed_request.intent.direction==-1);

   // Queue-dispatched WAIT and BLOCKED stop after a complete no-entry Ledger commit.
   for(int no_entry=0;no_entry<=1;no_entry++)
   {
      SWV5S5_CoordinatorIngressEvent stop_event;
      SWV5S5_CoordinatorMaterializationInput stop_materialization;
      SWV5S5_InvocationClaimCommand stop_claim_command;
      SWV5S5_ScriptedLedgerAuthority stop_ledger;
      SWV5S5_ScriptedRequestSequenceAuthority stop_sequence;
      int action=(no_entry==0 ? 0 : 9);
      SWV5S5_PhaseCAssert(SWV5S5_BuildCoordinatorFixture("QUEUE-STOP-"+(string)action,(ulong)(550+no_entry),
         action,stop_event,stop_materialization,stop_ledger,stop_sequence,stop_claim_command));
      SWV5S5_CoordinatorAdmissionEvent stop_admission; ZeroMemory(stop_admission);
      SWV5S5_ScriptedBlueprintAuthority stop_blueprint;
      SWV5S5_ScriptedRequestProgressionAuthority stop_progression;
      SWV5S5_ScriptedExecutionLifecycleAuthority stop_lifecycle;
      SWV5S5_ScriptedAdmissionPreparation stop_preparation;
      SWV5S5_ScriptedClaimAuthority stop_claim;
      SWV5S5_ScriptedOwnershipAuthority stop_ownership;
      SWV5S5_ScriptedFakeBroker stop_broker; SWV5S5_TestTraceSink stop_trace;
      SWV5S5_FakeBrokerResult stop_response; SWV5S5_SubmissionAuthorityRecord stop_record;
      SWV5S5_CoordinatorLedgerEvaluation stop_evaluation;
      SWV5S5_IngressLedgerIndexEntry stop_entries[]; SWV5S5_IngressLedgerRecord stop_records[];
      SWV5S5_CoordinatorMaterializationResult stop_result; SWV5S5_CoordinatorResult stop_coordinator_result;
      event.kind=SWV5S5_COORD_EVENT_ACCEPTED_INGRESS; event.event_id="STOP"; event.ordinal=(ulong)(550+no_entry);
      SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,event,stop_event,stop_materialization,stop_admission,
         stop_response,stop_record,stop_ledger,stop_sequence,stop_blueprint,stop_progression,stop_lifecycle,
         stop_preparation,stop_claim,stop_ownership,stop_broker,stop_trace,stop_evaluation,stop_entries,
         stop_records,stop_result,stop_coordinator_result));
      SWV5S5_PhaseCAssert(stop_coordinator_result.disposition==SWV5S5_COORD_NO_ENTRY &&
         stop_sequence.call_count==0 && stop_blueprint.call_count==0 && stop_broker.InvocationCount()==0);
   }

   // Queue-dispatched crash boundaries and takeover ordering use the actual
   // admission handler. Before Claim can recollect; after Claim is uncertain and
   // neither takeover nor follow-up may invoke a second broker call.
   SWV5S5_CoordinatorIngressEvent crash_ingress;
   SWV5S5_CoordinatorMaterializationInput crash_materialization;
   SWV5S5_InvocationClaimCommand crash_command;
   SWV5S5_ScriptedLedgerAuthority crash_ledger;
   SWV5S5_ScriptedRequestSequenceAuthority crash_sequence;
   SWV5S5_BuildCoordinatorFixture("QUEUE-CRASH",560,1,crash_ingress,crash_materialization,
                                  crash_ledger,crash_sequence,crash_command);
   SWV5S5_CoordinatorAdmissionEvent crash_admission; ZeroMemory(crash_admission);
   crash_admission.preparation_seed=crash_command;
   SWV5S5_ScriptedAdmissionPreparation crash_preparation;
   SWV5S5_ScriptedClaimAuthority crash_claim;
   SWV5S5_ConfigureValidClaim(crash_admission,crash_claim);
   SWV5S5_ScriptedBlueprintAuthority crash_blueprint;
   SWV5S5_ScriptedRequestProgressionAuthority crash_progression;
   SWV5S5_ScriptedExecutionLifecycleAuthority crash_lifecycle;
   SWV5S5_ScriptedOwnershipAuthority crash_ownership;
   SWV5S5_ScriptedFakeBroker crash_broker; SWV5S5_TestTraceSink crash_trace;
   SWV5S5_FakeBrokerResult crash_response;
   SWV5S5_SubmissionAuthorityRecord crash_record=crash_command.expected_authority_record;
   SWV5S5_CoordinatorLedgerEvaluation crash_evaluation;
   SWV5S5_IngressLedgerIndexEntry crash_entries[]; SWV5S5_IngressLedgerRecord crash_records[];
   SWV5S5_CoordinatorMaterializationResult crash_materialized;
   crash_materialized.progressed_request=crash_command.admission_proof.snapshot.collect_v2.request_set.requests[0];
   SWV5S5_CoordinatorResult crash_result;
   event.kind=SWV5S5_COORD_EVENT_OWNERSHIP_TAKEOVER; event.event_id="QUEUE-TAKEOVER-BEFORE-CLAIM";
   event.ordinal=559;
   SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,event,crash_ingress,crash_materialization,crash_admission,
      crash_response,crash_record,crash_ledger,crash_sequence,crash_blueprint,crash_progression,crash_lifecycle,
      crash_preparation,crash_claim,crash_ownership,crash_broker,crash_trace,crash_evaluation,crash_entries,
      crash_records,crash_materialized,crash_result) && crash_result.reconciliation_required &&
      crash_claim.call_count==0 && crash_broker.InvocationCount()==0);
   crash_admission.interruption_point=SWV5S5_COORD_INTERRUPT_BEFORE_CLAIM;
   event.kind=SWV5S5_COORD_EVENT_SUBMISSION_ADMISSION; event.event_id="QUEUE-CRASH-BEFORE"; event.ordinal=560;
   SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,event,crash_ingress,crash_materialization,crash_admission,
      crash_response,crash_record,crash_ledger,crash_sequence,crash_blueprint,crash_progression,crash_lifecycle,
      crash_preparation,crash_claim,crash_ownership,crash_broker,crash_trace,crash_evaluation,crash_entries,
      crash_records,crash_materialized,crash_result));
   SWV5S5_PhaseCAssert(crash_result.disposition==SWV5S5_COORD_INTERRUPTED_RECOLLECT &&
      crash_claim.call_count==0 && crash_broker.InvocationCount()==0);
   crash_admission.interruption_point=SWV5S5_COORD_INTERRUPT_NONE;
   event.event_id="QUEUE-CRASH-RECOLLECT"; event.ordinal=561;
   SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,event,crash_ingress,crash_materialization,crash_admission,
      crash_response,crash_record,crash_ledger,crash_sequence,crash_blueprint,crash_progression,crash_lifecycle,
      crash_preparation,crash_claim,crash_ownership,crash_broker,crash_trace,crash_evaluation,crash_entries,
      crash_records,crash_materialized,crash_result));
   SWV5S5_PhaseCAssert(crash_broker.InvocationCount()==1);

   SWV5S5_ScriptedAdmissionPreparation after_preparation;
   SWV5S5_ScriptedClaimAuthority after_claim;
   SWV5S5_ConfigureValidClaim(crash_admission,after_claim);
   SWV5S5_ScriptedFakeBroker after_broker;
   crash_admission.interruption_point=SWV5S5_COORD_INTERRUPT_AFTER_CLAIM_BEFORE_BROKER;
   event.event_id="QUEUE-CRASH-AFTER"; event.ordinal=562;
   SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,event,crash_ingress,crash_materialization,crash_admission,
      crash_response,crash_record,crash_ledger,crash_sequence,crash_blueprint,crash_progression,crash_lifecycle,
      after_preparation,after_claim,crash_ownership,after_broker,crash_trace,crash_evaluation,crash_entries,
      crash_records,crash_materialized,crash_result));
   crash_record=after_claim.scripted_result.resulting_authority_record;
   SWV5S5_PhaseCAssert(crash_result.reconciliation_required && after_broker.InvocationCount()==0);
   event.kind=SWV5S5_COORD_EVENT_OWNERSHIP_TAKEOVER; event.event_id="QUEUE-CLAIM-THEN-TAKEOVER"; event.ordinal=563;
   SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,event,crash_ingress,crash_materialization,crash_admission,
      crash_response,crash_record,crash_ledger,crash_sequence,crash_blueprint,crash_progression,crash_lifecycle,
      after_preparation,after_claim,crash_ownership,after_broker,crash_trace,crash_evaluation,crash_entries,
      crash_records,crash_materialized,crash_result) && after_broker.InvocationCount()==0);
   event.kind=SWV5S5_COORD_EVENT_RECONCILIATION_REQUIRED; event.event_id="QUEUE-UNCERTAIN-FOLLOW"; event.ordinal=564;
   SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,event,crash_ingress,crash_materialization,crash_admission,
      crash_response,crash_record,crash_ledger,crash_sequence,crash_blueprint,crash_progression,crash_lifecycle,
      after_preparation,after_claim,crash_ownership,after_broker,crash_trace,crash_evaluation,crash_entries,
      crash_records,crash_materialized,crash_result) && after_broker.InvocationCount()==0 &&
      crash_sequence.call_count==0);

   // All control event kinds dispatch through the same typed queue boundary.
   event.kind=SWV5S5_COORD_EVENT_OWNERSHIP_TAKEOVER; event.event_id="TAKEOVER"; event.ordinal=570;
   SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,event,ingress_event,materialization,admission_event,response,
      claimed_record,ledger,sequence,blueprint,progression,lifecycle,preparation,claim,ownership,fake_broker,trace,
      ledger_evaluation,ledger_entries,ledger_records,materialized,result) && result.reconciliation_required);
   event.kind=SWV5S5_COORD_EVENT_RECONCILIATION_REQUIRED; event.event_id="RECONCILE"; event.ordinal=571;
   SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,event,ingress_event,materialization,admission_event,response,
      claimed_record,ledger,sequence,blueprint,progression,lifecycle,preparation,claim,ownership,fake_broker,trace,
      ledger_evaluation,ledger_entries,ledger_records,materialized,result) && !result.fake_broker_invoked);
   event.kind=SWV5S5_COORD_EVENT_FAKE_BROKER_RESPONSE; event.event_id="ACK"; event.ordinal=572;
   SWV5S5_PhaseCAssert(dispatcher.Dispatch(coordinator,event,ingress_event,materialization,admission_event,response,
      claimed_record,ledger,sequence,blueprint,progression,lifecycle,preparation,claim,ownership,fake_broker,trace,
      ledger_evaluation,ledger_entries,ledger_records,materialized,result) &&
      result.disposition==SWV5S5_COORD_BROKER_ACKNOWLEDGED);
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
   SWV5S5_ScriptedOwnershipAuthority preclaim_ownership;
   SWV5S5_PhaseCAssert(coordinator.ProcessTakeover(event.request_correlation_id,preclaim_ownership,result) &&
      result.reconciliation_required && claim.call_count==0 && broker.InvocationCount()==0);
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
   SWV5S5_AssertDirectC2Authorities();
   SWV5S5_AssertQueuedC2Controls();

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

}
#endif
