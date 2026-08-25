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
                                         ingress_identity,1,
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
                       ISWV5S5CoordinatorTraceSink &trace_sink,
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
      if(authoritative_result.no_entry)
      {
         Finish(result,SWV5S5_COORD_NO_ENTRY,"WAIT_OR_BLOCKED_NO_REQUEST",false,false,false);
         Emit(trace_sink,diagnostic,SWV5S5_COORD_TRACE_INGRESS_VALIDATED,
              (int)authoritative_result.disposition,false,false,result.disposition);
         return true;
      }
      string correlation_id,attempt_id,idempotency_key;
      if(!authoritative_result.directional_nomination ||
         !DeriveDirectionalRequestBinding(event.persistence_namespace,event.ingress.ingress_identity,
                                           event.ingress.decision.direction,
                                           correlation_id,attempt_id,idempotency_key))
      {
         Finish(result,SWV5S5_COORD_ADMISSION_DENIED,"DIRECTIONAL_BINDING_DENIED",false,false,false);
         Emit(trace_sink,diagnostic,SWV5S5_COORD_TRACE_INGRESS_VALIDATED,
              (int)authoritative_result.disposition,false,false,result.disposition);
         return false;
      }
      result.request_correlation_id=correlation_id;
      result.attempt_id=attempt_id;
      diagnostic.request_correlation_id=correlation_id;
      diagnostic.attempt_id=attempt_id;
      Finish(result,SWV5S5_COORD_REQUEST_NOMINATED,
             (event.ingress.decision.direction==1 ? "BUY_NOMINATED" : "SELL_NOMINATED"),
             false,false,false);
      Emit(trace_sink,diagnostic,SWV5S5_COORD_TRACE_REQUEST_BOUND,
           (int)authoritative_result.disposition,false,false,result.disposition);
      return true;
   }

   bool ProcessAdmission(const SWV5S5_CoordinatorAdmissionEvent &event,
                         ISWV5S5CoordinatorAdmissionPreparation &preparation,
                         ISWV5S5InvocationClaimAuthority &claim_authority,
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

      SWV5S5_InvocationClaimTransition prepared;
      ZeroMemory(prepared);
      if(!preparation.PrepareSameEvent(event,prepared) || !prepared.transition_eligible ||
         prepared.disposition!=SWV5S5_CLAIM_TRANSITION_ELIGIBLE)
      {
         Finish(result,SWV5S5_COORD_ADMISSION_DENIED,"SAME_EVENT_ADMISSION_NOT_PREPARED",false,false,false);
         Emit(trace_sink,event,SWV5S5_COORD_TRACE_COMPLETED,(int)prepared.disposition,false,false,result.disposition);
         return false;
      }
      Emit(trace_sink,event,SWV5S5_COORD_TRACE_ADMISSION_PREPARED,(int)prepared.disposition,false,false,SWV5S5_COORD_INVALID);

      if(event.interruption_point==SWV5S5_COORD_INTERRUPT_BEFORE_CLAIM)
      {
         Finish(result,SWV5S5_COORD_INTERRUPTED_RECOLLECT,"PROVISIONAL_P_LOST_RECOLLECT",false,false,false);
         Emit(trace_sink,event,SWV5S5_COORD_TRACE_COMPLETED,(int)prepared.disposition,false,false,result.disposition);
         return true;
      }

      SWV5S5_InvocationClaimResult claim;
      ZeroMemory(claim);
      bool claim_call=claim_authority.TryClaimInvocation(event.claim_command,claim);
      Emit(trace_sink,event,SWV5S5_COORD_TRACE_CLAIM_ATTEMPTED,(int)claim.disposition,
           claim.claim_granted_now,false,SWV5S5_COORD_INVALID);

      const bool authoritative_grant=claim_call && claim.claim_granted_now &&
         claim.disposition==SWV5S5_CLAIM_GRANTED_NOW &&
         claim.resulting_authority_record.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED &&
         claim.resulting_authority_record.permit.request_identity.request_id.correlation_id==event.request_correlation_id &&
         claim.resulting_authority_record.permit.request_identity.request_id.attempt_id==event.attempt_id &&
         claim.resulting_authority_record.permit.unique_attempt_id==event.attempt_id &&
         claim.resulting_authority_record.permit.normalization_identity==event.normalized_payload_identity;
      if(!authoritative_grant)
      {
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
