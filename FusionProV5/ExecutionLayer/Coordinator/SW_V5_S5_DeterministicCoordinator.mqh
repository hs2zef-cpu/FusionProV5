#ifndef SW_V5_S5_DETERMINISTIC_COORDINATOR_MQH
#define SW_V5_S5_DETERMINISTIC_COORDINATOR_MQH

// SPRINT 5 PHASE C CANDIDATE
// SINGLE-THREADED EVENT-LOCAL COORDINATOR / NO DURABILITY OR PLATFORM ACCESS

#include "SW_V5_S5_CoordinatorCommon.mqh"

class SWV5S5_DeterministicCoordinator
{
private:
   bool DeriveDirectionalRequestBinding(const SWV5_PersistenceNamespace &persistence_namespace,
                                        const string ingress_identity,const int direction,
                                        string &correlation_id,string &attempt_id,string &idempotency_key)
   {
      correlation_id=""; attempt_id=""; idempotency_key="";
      if(direction!=1 && direction!=-1) return false;
      return SWV5S5_DeriveRequestBinding(persistence_namespace,
                                         SWV5S5_REQUEST_BINDING_POLICY_ID,
                                         SWV5S5_REQUEST_BINDING_POLICY_VERSION,
                                         ingress_identity,0,
                                         correlation_id,attempt_id,idempotency_key);
   }

   void Emit(ISWV5S5CoordinatorTraceSink &sink,
             const SWV5S5_CoordinatorAdmissionEvent &event,
             const SWV5S5_CoordinatorTraceStep step,const int domain_disposition,
             const bool grant,const bool invoked,
             const SWV5S5_CoordinatorDisposition final_disposition)
   {
      SWV5S5_CoordinatorTraceEntry trace;
      ZeroMemory(trace);
      trace.event_id=event.event_id;
      trace.event_ordinal=event.event_ordinal;
      trace.step=step;
      trace.request_correlation_id=event.request_correlation_id;
      trace.attempt_id=event.attempt_id;
      trace.domain_disposition=domain_disposition;
      trace.claim_granted_in_current_event=grant;
      trace.fake_broker_invoked=invoked;
      trace.final_disposition=final_disposition;
      sink.Append(trace);
   }

   bool EventValid(const SWV5S5_CoordinatorAdmissionEvent &event)
   {
      return event.event_id!="" && event.event_ordinal>0 &&
             event.request_correlation_id!="" && event.attempt_id!="" &&
             event.normalized_payload_identity!="";
   }

   bool PreparedCommandCoherent(const SWV5S5_CoordinatorPreparedAdmission &prepared)
   {
      return prepared.claim_command.expected_authority_revision==
                prepared.claim_command.expected_authority_record.authority_revision &&
             prepared.transition.proposed_next_record.authority_revision==
                prepared.claim_command.expected_authority_revision+1 &&
             prepared.transition.proposed_next_record.permit.permit_id==
                prepared.claim_command.expected_authority_record.permit.permit_id &&
             prepared.transition.proposed_next_record.permit.permit_digest==
                prepared.claim_command.expected_authority_record.permit.permit_digest &&
             prepared.transition.proposed_next_record.invocation_claim_id==prepared.claim_command.claim_id &&
             prepared.transition.proposed_next_record.admission_snapshot_digest==
                prepared.claim_command.admission_proof.snapshot.snapshot_digest;
   }

   void Finish(SWV5S5_CoordinatorResult &result,
               const SWV5S5_CoordinatorDisposition disposition,
               const string reason,const bool grant,const bool invoked,
               const bool reconcile)
   {
      result.disposition=disposition;
      result.reason_code=reason;
      result.claim_granted_in_current_event=grant;
      result.fake_broker_invoked=invoked;
      result.reconciliation_required=reconcile;
   }

public:
   bool ProcessIngress(const SWV5S5_CoordinatorIngressEvent &event,
                       ISWV5S5CoordinatorLedgerAuthority &ledger_authority,
                       ISWV5S5CoordinatorTraceSink &trace_sink,
                       SWV5S5_CoordinatorLedgerResult &ledger_result,
                       SWV5S5_CoordinatorResult &result)
   {
      ZeroMemory(result);
      result.event_id=event.event_id;
      result.event_ordinal=event.event_ordinal;
      SWV5S5_CoordinatorAdmissionEvent diagnostic;
      ZeroMemory(diagnostic);
      diagnostic.event_id=event.event_id;
      diagnostic.event_ordinal=event.event_ordinal;
      SWV5S5_IngressValidationResult authoritative_result;
      ZeroMemory(authoritative_result);
      ZeroMemory(ledger_result);
      if(event.event_id=="" || event.event_ordinal==0 ||
         !SWV5S5_ValidateTrustedIngressForAcceptance(event.context,event.ingress,event.freshness,
                                                      event.current_trust,event.trust_anchor,event.trust_scope,
                                                      authoritative_result))
      {
         Finish(result,SWV5S5_COORD_ADMISSION_DENIED,"TRUSTED_INGRESS_DENIED",false,false,false);
         Emit(trace_sink,diagnostic,SWV5S5_COORD_TRACE_INGRESS_VALIDATED,
              (int)authoritative_result.disposition,false,false,result.disposition);
         return false;
      }
      if(!ledger_authority.AcceptOrDeduplicate(event,authoritative_result,ledger_result) ||
         ledger_result.record.ingress_identity!=event.ingress.ingress_identity ||
         ledger_result.record.payload_digest!=event.ingress.payload_digest ||
         ledger_result.record.publication_sequence!=event.ingress.publication.publication_sequence ||
         ledger_result.header.ledger_digest=="" ||
         !SWV5S5_EqualNamespace(ledger_result.header.persistence_namespace,event.persistence_namespace))
      {
         Finish(result,SWV5S5_COORD_ADMISSION_DENIED,"LEDGER_AUTHORITY_DENIED_OR_MISMATCHED",false,false,false);
         Emit(trace_sink,diagnostic,SWV5S5_COORD_TRACE_COMPLETED,
              (int)ledger_result.disposition,false,false,result.disposition);
         return false;
      }
      string ledger_record_digest;
      if(!SWV5S5_ValidLedgerLifecycle(ledger_result.record) ||
         !SWV5S5_DeriveLedgerRecordDigest(ledger_result.record,ledger_record_digest) ||
         ledger_result.record.record_digest!=ledger_record_digest)
      { Finish(result,SWV5S5_COORD_ADMISSION_DENIED,"LEDGER_COMPLETE_RECORD_INVALID",false,false,false); return false; }
      if(authoritative_result.no_entry)
      {
         if(ledger_result.record.lifecycle_state!=SWV5S5_REJECTED_NO_ENTRY)
            return false;
         Finish(result,SWV5S5_COORD_NO_ENTRY,"WAIT_OR_BLOCKED_NO_REQUEST",false,false,false);
         Emit(trace_sink,diagnostic,SWV5S5_COORD_TRACE_INGRESS_VALIDATED,
              (int)authoritative_result.disposition,false,false,result.disposition);
         return true;
      }
      if(ledger_result.disposition==SWV5S5_INGRESS_EVALUATION_DUPLICATE)
      {
         result.request_correlation_id=ledger_result.record.logical_correlation_id;
         Finish(result,SWV5S5_COORD_LEDGER_DUPLICATE,"LEDGER_DUPLICATE_NO_NEW_SEQUENCE",false,false,false);
         Emit(trace_sink,diagnostic,SWV5S5_COORD_TRACE_COMPLETED,(int)ledger_result.disposition,false,false,result.disposition);
         return true;
      }
      if(!authoritative_result.directional_nomination || ledger_result.disposition!=SWV5S5_INGRESS_EVALUATION_NEW)
      {
         Finish(result,SWV5S5_COORD_ADMISSION_DENIED,"LEDGER_DIRECTIONAL_ACCEPTANCE_DENIED",false,false,false);
         Emit(trace_sink,diagnostic,SWV5S5_COORD_TRACE_INGRESS_VALIDATED,
              (int)authoritative_result.disposition,false,false,result.disposition);
         return false;
      }
      result.request_correlation_id=ledger_result.record.logical_correlation_id;
      diagnostic.request_correlation_id=result.request_correlation_id;
      Finish(result,SWV5S5_COORD_LEDGER_ACCEPTED_NEW,
             (event.ingress.decision.direction==1 ? "BUY_LEDGER_ACCEPTED" : "SELL_LEDGER_ACCEPTED"),
             false,false,false);
      Emit(trace_sink,diagnostic,SWV5S5_COORD_TRACE_REQUEST_BOUND,
           (int)authoritative_result.disposition,false,false,result.disposition);
      return true;
   }

   bool MaterializeAndProgress(const SWV5S5_CoordinatorMaterializationInput &materialization,
                               ISWV5S5CoordinatorRequestSequenceAuthority &sequence_authority,
                               ISWV5S5CoordinatorBlueprintAuthority &blueprint_authority,
                               ISWV5S5CoordinatorRequestProgressionAuthority &progression_authority,
                               SWV5S5_CoordinatorMaterializationResult &result)
   {
      ZeroMemory(result);
      string correlation,attempt,idempotency,binding_digest;
      if(materialization.ledger.disposition!=SWV5S5_INGRESS_EVALUATION_NEW ||
         !DeriveDirectionalRequestBinding(materialization.ledger.header.persistence_namespace,
                                           materialization.accepted_ingress.ingress_identity,
                                           materialization.accepted_ingress.decision.direction,
                                           correlation,attempt,idempotency))
      { result.reason_code="ORDINAL_ZERO_BINDING_FAILED"; return false; }
      if(!sequence_authority.Reserve(correlation,result.sequence) ||
         (result.sequence.disposition!=SWV5S5_SEQUENCE_RESERVED_NEW &&
          result.sequence.disposition!=SWV5S5_SEQUENCE_EXISTING_IDEMPOTENT) ||
         result.sequence.logical_correlation_id!=correlation || result.sequence.reserved_sequence==0)
      { result.reason_code="SEQUENCE_AUTHORITY_DENIED"; return false; }
      ZeroMemory(result.binding); SWV5S5_InitContractVersion(result.binding.contract_version);
      result.binding.binding_policy_id=SWV5S5_REQUEST_BINDING_POLICY_ID;
      result.binding.binding_policy_version=SWV5S5_REQUEST_BINDING_POLICY_VERSION;
      result.binding.persistence_namespace=materialization.ledger.header.persistence_namespace;
      result.binding.accepted_ingress_identity=materialization.accepted_ingress.ingress_identity;
      result.binding.accepted_at=materialization.ledger.record.accepted_at;
      result.binding.logical_correlation_id=correlation;
      result.binding.logical_request_sequence=result.sequence.reserved_sequence;
      result.binding.attempt_ordinal=0;
      result.binding.attempt_id=attempt;
      result.binding.idempotency_key=idempotency;
      if(!SWV5S5_DeriveRequestBindingDigest(result.binding,binding_digest))
      { result.reason_code="BINDING_DIGEST_FAILED"; return false; }
      result.binding.binding_digest=binding_digest;
      if(!blueprint_authority.BuildInitial(materialization,result.binding,result.blueprint))
      { result.reason_code="BLUEPRINT_AUTHORITY_DENIED"; return false; }
      SWV5S5_ValidationResult blueprint_validation;
      if(!SWV5S5_ValidateInitialBlueprint(materialization.context,result.blueprint,materialization.accepted_ingress,
                                           materialization.ledger.record,materialization.normalized_payload,
                                           materialization.normalization_identity,materialization.risk_authorization,
                                           blueprint_validation))
      { result.reason_code="FROZEN_INITIAL_BLUEPRINT_INVALID"; return false; }
      if(!progression_authority.ProgressToSubmission(result.blueprint.pending_request,result.progressed_request) ||
         result.progressed_request.state!=SWV5_REQUEST_SUBMISSION_PENDING ||
         result.progressed_request.lifecycle_phase!=SWV5_EXECUTION_PHASE_SUBMISSION ||
         !SWV5S5_EqualRequestIdentity(result.progressed_request.intent.request_identity,
                                      result.blueprint.pending_request.intent.request_identity))
      { result.reason_code="REQUEST_PROGRESSION_NOT_ADMISSIBLE"; return false; }
      result.disposition=SWV5S5_COORD_REQUEST_SUBMISSION_READY;
      result.reason_code="OWNER_RETURNED_SUBMISSION_PENDING";
      return true;
   }

   bool ProcessTakeover(const string request_correlation_id,
                        ISWV5S5CoordinatorOwnershipAuthority &ownership_authority,
                        SWV5S5_CoordinatorResult &result)
   {
      ZeroMemory(result);
      SWV5S5_CoordinatorDisposition owner_result=SWV5S5_COORD_INVALID;
      if(request_correlation_id=="" ||
         !ownership_authority.EvaluateTakeover(request_correlation_id,owner_result))
      { result.disposition=SWV5S5_COORD_INVALID; result.reason_code="TAKEOVER_AUTHORITY_DENIED"; return false; }
      result.request_correlation_id=request_correlation_id;
      result.disposition=owner_result;
      result.reconciliation_required=(owner_result==SWV5S5_COORD_TAKEOVER_RECONCILIATION ||
                                      owner_result==SWV5S5_COORD_ALREADY_CLAIMED_UNCERTAIN);
      result.reason_code="OWNER_RETURNED_TAKEOVER_DISPOSITION";
      return true;
   }

   bool ProcessReconciliationRequired(const SWV5S5_SubmissionAuthorityRecord &record,
                                      SWV5S5_CoordinatorResult &result)
   {
      ZeroMemory(result);
      if(record.state!=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED)
      { result.disposition=SWV5S5_COORD_INVALID; result.reason_code="RECONCILIATION_STATE_INVALID"; return false; }
      result.request_correlation_id=record.permit.request_identity.request_id.correlation_id;
      result.attempt_id=record.permit.unique_attempt_id;
      result.disposition=SWV5S5_COORD_CLAIMED_RECONCILIATION_REQUIRED;
      result.reconciliation_required=true;
      result.fake_broker_invoked=false;
      result.reason_code="CLAIMED_UNRESOLVED_NO_RETRY";
      return true;
   }

   bool ProcessFakeBrokerResponse(const SWV5S5_FakeBrokerResult &response,
                                  SWV5S5_CoordinatorResult &result)
   {
      ZeroMemory(result);
      if(response.outcome==SWV5S5_FAKE_BROKER_REQUEST_RECEIVED)
      {
         result.disposition=SWV5S5_COORD_BROKER_ACKNOWLEDGED;
         result.reason_code="ACKNOWLEDGEMENT_NOT_EXECUTION_CONFIRMATION";
         return true;
      }
      if(response.outcome==SWV5S5_FAKE_BROKER_REJECTED)
      {
         result.disposition=SWV5S5_COORD_FAKE_BROKER_REJECTED;
         result.reason_code="SCRIPTED_REJECTION_NOT_BASKET_MUTATION";
         return true;
      }
      result.disposition=SWV5S5_COORD_FAKE_BROKER_UNCERTAIN;
      result.reconciliation_required=true;
      result.reason_code="UNKNOWN_RESPONSE_RECONCILIATION_REQUIRED";
      return true;
   }

   bool ProcessAdmission(const SWV5S5_CoordinatorAdmissionEvent &event,
                         ISWV5S5CoordinatorAdmissionPreparation &preparation,
                         ISWV5S5CoordinatorInvocationClaimAuthority &claim_authority,
                         ISWV5S5CoordinatorFakeBrokerPort &fake_broker,
                         ISWV5S5CoordinatorTraceSink &trace_sink,
                         SWV5S5_CoordinatorResult &result)
   {
      ZeroMemory(result);
      result.event_id=event.event_id;
      result.event_ordinal=event.event_ordinal;
      result.request_correlation_id=event.request_correlation_id;
      result.attempt_id=event.attempt_id;
      Emit(trace_sink,event,SWV5S5_COORD_TRACE_EVENT_RECEIVED,0,false,false,SWV5S5_COORD_INVALID);

      if(!EventValid(event) ||
         event.request_state!=SWV5_REQUEST_SUBMISSION_PENDING ||
         event.request_phase!=SWV5_EXECUTION_PHASE_SUBMISSION)
      {
         Finish(result,SWV5S5_COORD_ADMISSION_DENIED,"REQUEST_LIFECYCLE_NOT_ADMISSIBLE",false,false,false);
         Emit(trace_sink,event,SWV5S5_COORD_TRACE_COMPLETED,0,false,false,result.disposition);
         return false;
      }

      SWV5S5_CoordinatorPreparedAdmission prepared;
      ZeroMemory(prepared);
      if(!preparation.PrepareSameEvent(event,prepared) ||
         prepared.event_id!=event.event_id || prepared.event_ordinal!=event.event_ordinal ||
         prepared.operation_token=="" || !prepared.transition.transition_eligible ||
         prepared.transition.disposition!=SWV5S5_CLAIM_TRANSITION_ELIGIBLE ||
         !PreparedCommandCoherent(prepared))
      {
         Finish(result,SWV5S5_COORD_ADMISSION_DENIED,"SAME_EVENT_ADMISSION_NOT_PREPARED",false,false,false);
         Emit(trace_sink,event,SWV5S5_COORD_TRACE_COMPLETED,(int)prepared.transition.disposition,false,false,result.disposition);
         return false;
      }
      Emit(trace_sink,event,SWV5S5_COORD_TRACE_ADMISSION_PREPARED,(int)prepared.transition.disposition,false,false,SWV5S5_COORD_INVALID);

      if(event.interruption_point==SWV5S5_COORD_INTERRUPT_BEFORE_CLAIM)
      {
         Finish(result,SWV5S5_COORD_INTERRUPTED_RECOLLECT,"PROVISIONAL_P_LOST_RECOLLECT",false,false,false);
         Emit(trace_sink,event,SWV5S5_COORD_TRACE_COMPLETED,(int)prepared.transition.disposition,false,false,result.disposition);
         return true;
      }

      SWV5S5_CoordinatorClaimOperationResult claim_operation;
      ZeroMemory(claim_operation);
      bool claim_call=claim_authority.TryClaimInvocation(prepared.claim_command,event.event_id,
         event.event_ordinal,prepared.operation_token,claim_operation);
      SWV5S5_InvocationClaimResult claim=claim_operation.claim;
      Emit(trace_sink,event,SWV5S5_COORD_TRACE_CLAIM_ATTEMPTED,(int)claim.disposition,claim.claim_granted_now,false,SWV5S5_COORD_INVALID);

      const bool operation_bound=claim_operation.event_id==event.event_id &&
         claim_operation.event_ordinal==event.event_ordinal &&
         claim_operation.operation_token==prepared.operation_token;
      const bool frozen_result_valid=claim_call && operation_bound &&
         SWV5S5_ValidateAuthoritativeClaimResult(prepared.transition,claim);

      const bool authoritative_grant=frozen_result_valid && claim.claim_granted_now &&
         claim.disposition==SWV5S5_CLAIM_GRANTED_NOW &&
         claim.resulting_authority_record.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED &&
         claim.resulting_authority_record.permit.request_identity.request_id.correlation_id==event.request_correlation_id &&
         claim.resulting_authority_record.permit.request_identity.request_id.attempt_id==event.attempt_id &&
         claim.resulting_authority_record.permit.unique_attempt_id==event.attempt_id &&
         claim.resulting_authority_record.permit.normalization_identity==event.normalized_payload_identity;
      if(!authoritative_grant)
      {
         if(claim.claim_granted_now || claim.disposition==SWV5S5_CLAIM_GRANTED_NOW)
         {
            Finish(result,SWV5S5_COORD_INVALID,"AUTHORITATIVE_CLAIM_RESULT_INVALID_OR_REPLAYED",false,false,true);
            Emit(trace_sink,event,SWV5S5_COORD_TRACE_RECONCILIATION_REQUIRED,(int)claim.disposition,false,false,result.disposition);
            return false;
         }
         if(claim.resulting_authority_record.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED ||
            claim.disposition==SWV5S5_CLAIM_ALREADY_CLAIMED)
         {
            Finish(result,SWV5S5_COORD_ALREADY_CLAIMED_UNCERTAIN,
                   "PERSISTED_CLAIM_HAS_NO_EVENT_LOCAL_GRANT",false,false,true);
            Emit(trace_sink,event,SWV5S5_COORD_TRACE_RECONCILIATION_REQUIRED,
                 (int)claim.disposition,false,false,result.disposition);
            return true;
         }
         SWV5S5_CoordinatorDisposition denied=(claim.disposition==SWV5S5_CLAIM_STALE_OWNER ?
                                                SWV5S5_COORD_STALE_OWNER : SWV5S5_COORD_CLAIM_DENIED);
         Finish(result,denied,"CLAIM_NOT_GRANTED_CURRENT_EVENT",false,false,false);
         Emit(trace_sink,event,SWV5S5_COORD_TRACE_COMPLETED,(int)claim.disposition,false,false,result.disposition);
         return false;
      }

      SWV5S5_ConditionalAdmissionResult completed;
      ZeroMemory(completed);
      SWV5S5_CompleteConditionalAdmission(claim,completed);
      if(!completed.claim_authorized || completed.operation_state!=SWV5S5_ADMISSION_COMPLETED)
      {
         Finish(result,SWV5S5_COORD_INVALID,"PHASE_B_ADMISSION_COMPLETION_REJECTED",false,false,true);
         Emit(trace_sink,event,SWV5S5_COORD_TRACE_RECONCILIATION_REQUIRED,(int)claim.disposition,false,false,result.disposition);
         return false;
      }
      Emit(trace_sink,event,SWV5S5_COORD_TRACE_CLAIM_GRANTED_CURRENT_EVENT,
           (int)claim.disposition,true,false,SWV5S5_COORD_INVALID);

      if(event.interruption_point==SWV5S5_COORD_INTERRUPT_AFTER_CLAIM_BEFORE_BROKER)
      {
         Finish(result,SWV5S5_COORD_CLAIMED_RECONCILIATION_REQUIRED,
                "CLAIM_COMMITTED_BROKER_NOT_INVOKED",true,false,true);
         Emit(trace_sink,event,SWV5S5_COORD_TRACE_RECONCILIATION_REQUIRED,(int)claim.disposition,true,false,result.disposition);
         return true;
      }

      SWV5S5_FakeBrokerInvocation invocation;
      ZeroMemory(invocation);
      invocation.event_id=event.event_id;
      invocation.event_ordinal=event.event_ordinal;
      invocation.event_local_invocation_sequence=1;
      // The broker record is projected from the complete owning-authority result,
      // never rebuilt from a locally asserted success state.
      invocation.request_correlation_id=claim.resulting_authority_record.permit.request_identity.request_id.correlation_id;
      invocation.attempt_id=claim.resulting_authority_record.permit.unique_attempt_id;
      invocation.normalized_payload_identity=claim.resulting_authority_record.permit.normalization_identity;
      invocation.claim_id=claim.resulting_authority_record.invocation_claim_id;
      SWV5S5_FakeBrokerResult broker_result;
      ZeroMemory(broker_result);
      bool invoked=fake_broker.InvokeFake(invocation,broker_result);
      if(!invoked)
      {
         Finish(result,SWV5S5_COORD_FAKE_BROKER_UNCERTAIN,"FAKE_BROKER_NO_RESULT",true,true,true);
      }
      else if(broker_result.outcome==SWV5S5_FAKE_BROKER_REJECTED)
      {
         Finish(result,SWV5S5_COORD_FAKE_BROKER_REJECTED,"FAKE_BROKER_SCRIPTED_REJECTION",true,true,false);
      }
      else if(broker_result.outcome==SWV5S5_FAKE_BROKER_REQUEST_RECEIVED)
      {
         // Request receipt is only an acknowledgement, never execution confirmation.
         Finish(result,SWV5S5_COORD_FAKE_BROKER_INVOKED,"FAKE_BROKER_REQUEST_RECEIVED_NOT_CONFIRMED",true,true,false);
      }
      else
      {
         Finish(result,SWV5S5_COORD_FAKE_BROKER_UNCERTAIN,"FAKE_BROKER_UNCERTAIN",true,true,true);
      }
      Emit(trace_sink,event,SWV5S5_COORD_TRACE_FAKE_BROKER_INVOKED,(int)broker_result.outcome,true,true,result.disposition);
      return true;
   }
};

#endif
