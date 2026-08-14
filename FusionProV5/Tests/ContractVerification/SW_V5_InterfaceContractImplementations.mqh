//+------------------------------------------------------------------+
//| TEST ONLY                                                        |
//| NOT FOR PRODUCTION                                               |
//| NO BROKER ACCESS                                                 |
//| Deterministic in-memory ISWV5* contract implementations.        |
//+------------------------------------------------------------------+
#ifndef SW_V5_INTERFACE_CONTRACT_IMPLEMENTATIONS_MQH
#define SW_V5_INTERFACE_CONTRACT_IMPLEMENTATIONS_MQH

#include "SW_V5_ReferenceValidators.mqh"

void SWV5_TestSetDecision(const SWV5_ContractValidationContext &context,
                          const bool allowed,
                          const string reason,
                          SWV5_ContractDecision &decision)
{
   decision.contract_version=context.expected_version;
   decision.disposition=(allowed ? SWV5_DISPOSITION_ALLOW : SWV5_DISPOSITION_DENY);
   decision.reason_flags=(allowed ? 0 : 1);
   decision.reason_code=reason;
   decision.reason_text=reason;
   decision.evaluated_schema_version=context.expected_version.schema_version;
   decision.evaluation_sequence=context.evaluation_sequence;
   decision.evaluated_at=context.clock_time;
}

class SWV5_TestVersionPolicy : public ISWV5ContractVersionPolicy
{
public:
   virtual string ContractName() { return "ISWV5ContractVersionPolicy/V"+IntegerToString(SWV5_PRODUCTION_CONTRACT_VERSION); }
   virtual bool EvaluateCompatibility(const SWV5_ContractValidationContext &context,
                                      const SWV5_ContractVersion &candidate,
                                      SWV5_ContractCompatibilityResult &result)
   {
      result.evaluated_version=candidate;
      result.compatibility=SWV5_TestCompatibility(candidate,context);
      result.reason_code=(result.compatibility==SWV5_COMPATIBILITY_EXACT ? "EXACT" : "REJECTED");
      result.reason_text=result.reason_code;
      return result.compatibility==SWV5_COMPATIBILITY_EXACT;
   }
};

class SWV5_TestBasketStateContract : public ISWV5BasketStateMachineContract
{
public:
   virtual string ContractName() { return "ISWV5BasketStateMachineContract/V"+IntegerToString(SWV5_PRODUCTION_CONTRACT_VERSION); }
   virtual bool ValidateState(const SWV5_ContractValidationContext &context,
                              const SWV5_BasketLifecycleSnapshot &snapshot,
                              SWV5_BasketInvariantReport &report)
   {
      const bool valid=SWV5_TestContextValid(context) && snapshot.basket_id.value!="" &&
                       SWV5_TestFenceComplete(snapshot.ownership_fence) &&
                       !(snapshot.state==SWV5_BASKET_IDLE &&
                         (snapshot.residual_volume>context.volume_tolerance || snapshot.live_position_count>0 ||
                          snapshot.live_order_count>0 || snapshot.pending_request_count>0));
      report.contract_version=context.expected_version;
      report.status=(valid ? SWV5_CONTRACT_VALID : SWV5_CONTRACT_INVALID);
      report.satisfied_flags=(valid ? SWV5_INVARIANT_BASKET_ID_REQUIRED|SWV5_INVARIANT_OWNER_REQUIRED : 0);
      report.violated_flags=(valid ? 0 : SWV5_INVARIANT_IDLE_HAS_NO_EXPOSURE);
      report.primary_violation=(valid ? "" : "BASKET_STATE_INVALID");
      return valid;
   }
   virtual bool ValidateTransition(const SWV5_ContractValidationContext &context,
                                   const SWV5_BasketLifecycleSnapshot &snapshot,
                                   const SWV5_BasketTransitionRequest &request,
                                   SWV5_BasketTransitionDecision &decision)
   {
      decision.resulting_accepted_recovery_evidence=snapshot.accepted_recovery_evidence;
      decision.recovery_evidence_added=false;
      decision.recovery_evidence_duplicate=false;
      decision.resulting_state=snapshot.state;
      decision.resulting_state_version=snapshot.state_version;
      decision.resulting_cumulative_recovery_attempts=snapshot.cumulative_recovery_attempts;
      decision.resulting_recovery_layer=snapshot.current_recovery_layer;
      const bool recovery_operation=request.recovery_evidence.evidence_identity!="" ||
                                    (request.from_state==SWV5_BASKET_ACTIVE && request.to_state==SWV5_BASKET_RECOVERY);
      if(recovery_operation)
      {
         const bool new_envelope=SWV5_TestRecoveryNewEnvelopeValid(context,snapshot,request);
         const bool replay_envelope=SWV5_TestRecoveryReplayEnvelopeValid(context,snapshot,request);
         const string fingerprint=SWV5_TestCanonicalRecoveryTransition(request);
         SWV5_StatisticsIdentityDisposition identity_disposition=SWV5_STAT_IDENTITY_CONFLICT;
         if(new_envelope || replay_envelope)
            identity_disposition=SWV5_TestClassifyDurableFingerprint(request.recovery_evidence.evidence_identity,
                                                                     request.recovery_evidence.evidence_sequence,
                                                                     fingerprint,
                                                                     snapshot.accepted_recovery_evidence);
         if(replay_envelope && identity_disposition==SWV5_STAT_IDENTITY_DUPLICATE)
         {
            decision.contract_version=context.expected_version;
            SWV5_TestSetDecision(context,true,"RECOVERY_EVIDENCE_DUPLICATE",decision.decision);
            decision.recovery_evidence_duplicate=true;
            decision.invariants.contract_version=context.expected_version;
            decision.invariants.status=SWV5_CONTRACT_VALID;
            decision.invariants.satisfied_flags=SWV5_INVARIANT_VERSION_MONOTONIC|SWV5_INVARIANT_SAME_STATE_VERSION_STABLE;
            decision.invariants.violated_flags=0;
            decision.invariants.primary_violation="";
            return true;
         }
         if(new_envelope && (identity_disposition==SWV5_STAT_IDENTITY_NEW || identity_disposition==SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW))
         {
            SWV5_DurableEventIdentitySet accepted;
            const SWV5_StatisticsIdentityDisposition appended=SWV5_TestAppendDurableFingerprint(request.recovery_evidence.evidence_identity,
                                                                                                 request.recovery_evidence.evidence_sequence,
                                                                                                 fingerprint,
                                                                                                 snapshot.accepted_recovery_evidence,
                                                                                                 accepted);
            if(appended==SWV5_STAT_IDENTITY_NEW || appended==SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW)
            {
               decision.contract_version=context.expected_version;
               SWV5_TestSetDecision(context,true,"RECOVERY_TRANSITION_ACCEPTED",decision.decision);
               decision.resulting_state=request.to_state;
               decision.resulting_state_version=snapshot.state_version+1;
               decision.resulting_cumulative_recovery_attempts=request.recovery_evidence.proposed_cumulative_recovery_attempts;
               decision.resulting_recovery_layer=request.recovery_evidence.proposed_recovery_layer;
               decision.resulting_accepted_recovery_evidence=accepted;
               decision.recovery_evidence_added=true;
               decision.invariants.contract_version=context.expected_version;
               decision.invariants.status=SWV5_CONTRACT_VALID;
               decision.invariants.satisfied_flags=SWV5_INVARIANT_VERSION_MONOTONIC;
               decision.invariants.violated_flags=0;
               decision.invariants.primary_violation="";
               return true;
            }
         }
         decision.contract_version=context.expected_version;
         const string rejection_reason=(!new_envelope && !replay_envelope ? "RECOVERY_ENVELOPE_INVALID" : "RECOVERY_EVIDENCE_CONFLICT");
         SWV5_TestSetDecision(context,false,rejection_reason,decision.decision);
         decision.invariants.contract_version=context.expected_version;
         decision.invariants.status=SWV5_CONTRACT_INVALID;
         decision.invariants.satisfied_flags=0;
         decision.invariants.violated_flags=SWV5_INVARIANT_VERSION_MONOTONIC;
         decision.invariants.primary_violation=rejection_reason;
         return false;
      }
      ulong resulting_version=snapshot.state_version;
      const SWV5_TestBasketRule rule=SWV5_TestEvaluateBasketTransition(context,snapshot,request,resulting_version);
      const bool allowed=(rule!=SWV5_TEST_BASKET_FORBID);
      decision.contract_version=context.expected_version;
      SWV5_TestSetDecision(context,allowed,(allowed ? "TRANSITION_ACCEPTED" : "TRANSITION_REJECTED"),decision.decision);
      decision.resulting_state=(allowed ? request.to_state : snapshot.state);
      decision.resulting_state_version=resulting_version;
      decision.invariants.contract_version=context.expected_version;
      decision.invariants.status=(allowed ? SWV5_CONTRACT_VALID : SWV5_CONTRACT_INVALID);
      decision.invariants.satisfied_flags=(allowed ? SWV5_INVARIANT_VERSION_MONOTONIC : 0);
      decision.invariants.violated_flags=(allowed ? 0 : SWV5_INVARIANT_VERSION_MONOTONIC);
      decision.invariants.primary_violation=(allowed ? "" : "TRANSITION_REJECTED");
      return allowed;
   }
};

class SWV5_TestBasketContract : public ISWV5BasketContract
{
public:
   virtual string ContractName() { return "ISWV5BasketContract/V"+IntegerToString(SWV5_PRODUCTION_CONTRACT_VERSION); }
   virtual bool ValidateAggregate(const SWV5_ContractValidationContext &context,
                                  const SWV5_BasketAggregate &basket,
                                  SWV5_BasketValidationResult &result)
   {
      const bool valid=SWV5_TestContextValid(context) && SWV5_TestAggregateIdentityValid(basket);
      result.contract_version=context.expected_version;
      SWV5_TestSetDecision(context,valid,(valid ? "AGGREGATE_VALID" : "AGGREGATE_INVALID"),result.decision);
      result.lifecycle_invariants.contract_version=context.expected_version;
      result.lifecycle_invariants.status=(valid ? SWV5_CONTRACT_VALID : SWV5_CONTRACT_INVALID);
      return valid;
   }
   virtual bool ValidatePartialClose(const SWV5_ContractValidationContext &context,
                                     const SWV5_BasketAggregate &basket,
                                     const SWV5_PartialCloseEvidence &evidence,
                                     SWV5_ContractDecision &decision)
   {
      const bool valid=SWV5_TestContextValid(context) && SWV5_TestPartialCloseValid(basket,evidence);
      SWV5_TestSetDecision(context,valid,(valid ? "PARTIAL_CLOSE_VALID" : "PARTIAL_CLOSE_INVALID"),decision);
      return valid;
   }
   virtual bool ValidateCloseCompletion(const SWV5_ContractValidationContext &context,
                                        const SWV5_BasketAggregate &basket,
                                        const SWV5_CloseVerificationEvidence &evidence,
                                        SWV5_ContractDecision &decision)
   {
      const bool valid=SWV5_TestContextValid(context) &&
                       SWV5_TestNamespaceEqual(basket.persistence_namespace,evidence.persistence_namespace) &&
                       SWV5_TestCloseComplete(evidence);
      SWV5_TestSetDecision(context,valid,(valid ? "CLOSE_COMPLETE" : "RESIDUAL_EXPOSURE"),decision);
      return valid;
   }
};

class SWV5_TestExecutionContract : public ISWV5ExecutionContract
{
public:
   virtual string ContractName() { return "ISWV5ExecutionContract/V"+IntegerToString(SWV5_PRODUCTION_CONTRACT_VERSION); }
   virtual bool ValidateIntent(const SWV5_ContractValidationContext &context,const SWV5_ExecutionIntent &intent,SWV5_ContractDecision &decision)
   {
      const bool valid=SWV5_TestIntentValid(context,intent);
      SWV5_TestSetDecision(context,valid,(valid ? "INTENT_VALID" : "INTENT_INVALID"),decision);
      return valid;
   }
   virtual bool ValidatePhaseTransition(const SWV5_ContractValidationContext &context,
                                        const SWV5_ExecutionLifecyclePhase current_phase,
                                        const SWV5_ExecutionLifecyclePhase proposed_phase,
                                        SWV5_ContractDecision &decision)
   {
      bool valid=false;
      if(current_phase==SWV5_EXECUTION_PHASE_INTENT)
         valid=(proposed_phase==SWV5_EXECUTION_PHASE_SUBMISSION || proposed_phase==SWV5_EXECUTION_PHASE_REJECTED);
      else if(current_phase==SWV5_EXECUTION_PHASE_SUBMISSION)
         valid=(proposed_phase==SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT || proposed_phase==SWV5_EXECUTION_PHASE_REJECTED || proposed_phase==SWV5_EXECUTION_PHASE_UNCERTAIN);
      else if(current_phase==SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT)
         valid=(proposed_phase==SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION || proposed_phase==SWV5_EXECUTION_PHASE_REJECTED || proposed_phase==SWV5_EXECUTION_PHASE_UNCERTAIN);
      else if(current_phase==SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION)
         valid=(proposed_phase==SWV5_EXECUTION_PHASE_PARTIAL_FILL || proposed_phase==SWV5_EXECUTION_PHASE_COMPLETED);
      else if(current_phase==SWV5_EXECUTION_PHASE_PARTIAL_FILL)
         valid=(proposed_phase==SWV5_EXECUTION_PHASE_PARTIAL_FILL || proposed_phase==SWV5_EXECUTION_PHASE_COMPLETED || proposed_phase==SWV5_EXECUTION_PHASE_UNCERTAIN);
      SWV5_TestSetDecision(context,valid,(valid ? "PHASE_ALLOWED" : "PHASE_REJECTED"),decision);
      return valid;
   }
   virtual bool ClassifyResultRetcode(const SWV5_ContractValidationContext &context,const SWV5_ResultRetcodeEvidence &evidence,SWV5_ResultRetcodeClassification &classification)
   {
      classification.contract_version=context.expected_version;
      classification.classification=SWV5_RETCODE_UNCLASSIFIED;
      classification.retry_disposition=SWV5_RETRY_FORBIDDEN;
      classification.mapping_policy_id="TEST-RETCODE-MAP-V3";
      if(!SWV5_TestRetcodeEnvelopeValid(context,evidence))
      {
         SWV5_TestSetDecision(context,false,"RETCODE_ENVELOPE_INVALID",classification.decision);
         return false;
      }
      classification.classification=SWV5_TestClassifyRetcode(evidence.raw_retcode);
      classification.retry_disposition=(classification.classification==SWV5_RETCODE_CONNECTION_UNCERTAIN ? SWV5_RETRY_REQUIRES_RECONCILIATION : SWV5_RETRY_FORBIDDEN);
      const bool known=(classification.classification!=SWV5_RETCODE_UNCLASSIFIED);
      SWV5_TestSetDecision(context,known,(known ? "RETCODE_CLASSIFIED" : "RETCODE_UNKNOWN"),classification.decision);
      return known;
   }
   virtual bool AcceptTransactionEvidence(const SWV5_ContractValidationContext &context,const SWV5_PendingRequest &pending,const SWV5_TransactionEvidence &evidence,SWV5_ExecutionConfirmation &confirmation)
   {
      confirmation.contract_version=context.expected_version;
      confirmation.persistence_namespace=pending.intent.persistence_namespace;
      confirmation.ownership_fence=pending.intent.ownership_fence;
      confirmation.correlation=pending.latest_retcode.correlation;
      confirmation.evidence_disposition=SWV5_TRANSACTION_EVIDENCE_INVALID;
      confirmation.status=SWV5_CONFIRMATION_CONFLICT;
      confirmation.disposition=SWV5_DISPOSITION_RECONCILE;
      confirmation.confirmed_volume=pending.cumulative_confirmed_volume;
      confirmation.residual_volume=pending.residual_requested_volume;
      confirmation.symbol_specification_sequence=pending.intent.symbol_specification_sequence;
      confirmation.resulting_pending_request=pending;
      confirmation.event_identity_added=false;
      confirmation.duplicate_event=false;
      confirmation.diagnostic="EXECUTION_ENVELOPE_INVALID";
      if(!SWV5_TestTransactionEnvelopeValid(context,pending,evidence))
         return false;
      double confirmed=0.0,residual=0.0;
      SWV5_TransactionEvidenceDisposition evidence_disposition=SWV5_TRANSACTION_EVIDENCE_INVALID;
      const SWV5_ConfirmationStatus status=SWV5_TestConfirmExecution(context,pending,evidence,evidence_disposition,confirmed,residual);
      confirmation.persistence_namespace=evidence.persistence_namespace;
      confirmation.ownership_fence=evidence.ownership_fence;
      confirmation.correlation=evidence.correlation;
      confirmation.evidence_disposition=evidence_disposition;
      confirmation.status=status;
      confirmation.confirmed_volume=confirmed;
      confirmation.residual_volume=residual;
      confirmation.symbol_specification_sequence=evidence.symbol_specification_sequence;
      if(status==SWV5_CONFIRMATION_PENDING)
      {
         confirmation.disposition=(evidence_disposition==SWV5_TRANSACTION_EVIDENCE_RECONCILIATION_REQUIRED ? SWV5_DISPOSITION_RECONCILE : SWV5_DISPOSITION_DENY);
         confirmation.diagnostic=(evidence_disposition==SWV5_TRANSACTION_EVIDENCE_RECONCILIATION_REQUIRED ? "NON_CONFIRMING_RECONCILIATION_REQUIRED" : "ACKNOWLEDGEMENT_ONLY_NO_CONFIRMATION");
         return evidence_disposition==SWV5_TRANSACTION_EVIDENCE_ACKNOWLEDGEMENT_ONLY;
      }
      SWV5_DurableEventIdentitySet updated_identities;
      string evidence_fingerprint="";
      SWV5_StatisticsIdentityDisposition identity_disposition=SWV5_STAT_IDENTITY_CONFLICT;
      if(status!=SWV5_CONFIRMATION_CONFLICT)
         identity_disposition=SWV5_TestClassifyExecutionEvidence(evidence,pending.accepted_event_identities,evidence_fingerprint);
      if((identity_disposition==SWV5_STAT_IDENTITY_NEW || identity_disposition==SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW) &&
         (pending.lifecycle_phase==SWV5_EXECUTION_PHASE_COMPLETED ||
          evidence.confirmed_volume>pending.residual_requested_volume+context.volume_tolerance))
         identity_disposition=SWV5_STAT_IDENTITY_CONFLICT;
      if(identity_disposition==SWV5_STAT_IDENTITY_NEW || identity_disposition==SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW)
         identity_disposition=SWV5_TestAppendExecutionEvidence(evidence,pending.accepted_event_identities,updated_identities,evidence_fingerprint);
      SWV5_ConfirmationStatus effective_status=status;
      if(identity_disposition==SWV5_STAT_IDENTITY_CONFLICT)
         effective_status=SWV5_CONFIRMATION_CONFLICT;
      else if(identity_disposition==SWV5_STAT_IDENTITY_DUPLICATE)
      {
         confirmation.duplicate_event=true;
         effective_status=(pending.residual_requested_volume>context.volume_tolerance ? SWV5_CONFIRMATION_PARTIAL : SWV5_CONFIRMATION_CONFIRMED);
         confirmed=pending.cumulative_confirmed_volume;
         residual=pending.residual_requested_volume;
      }
      confirmation.status=effective_status;
      confirmation.disposition=(effective_status==SWV5_CONFIRMATION_CONFLICT ? SWV5_DISPOSITION_RECONCILE : SWV5_DISPOSITION_ALLOW);
      confirmation.confirmed_volume=confirmed;
      confirmation.residual_volume=residual;
      confirmation.symbol_specification_sequence=evidence.symbol_specification_sequence;
      if(effective_status==SWV5_CONFIRMATION_CONFIRMED || effective_status==SWV5_CONFIRMATION_PARTIAL)
      {
         if(identity_disposition!=SWV5_STAT_IDENTITY_DUPLICATE)
         {
            confirmation.resulting_pending_request.accepted_event_identities=updated_identities;
            confirmation.resulting_pending_request.cumulative_confirmed_volume=confirmed;
            confirmation.resulting_pending_request.residual_requested_volume=residual;
            confirmation.resulting_pending_request.lifecycle_phase=(effective_status==SWV5_CONFIRMATION_PARTIAL ? SWV5_EXECUTION_PHASE_PARTIAL_FILL : SWV5_EXECUTION_PHASE_COMPLETED);
            confirmation.resulting_pending_request.state=(effective_status==SWV5_CONFIRMATION_PARTIAL ? SWV5_REQUEST_PARTIALLY_CONFIRMED : SWV5_REQUEST_CONFIRMED);
            confirmation.resulting_pending_request.latest_authoritative_confirmation.contract_version=context.expected_version;
            confirmation.resulting_pending_request.latest_authoritative_confirmation.correlation=evidence.correlation;
            confirmation.resulting_pending_request.latest_authoritative_confirmation.status=effective_status;
            confirmation.resulting_pending_request.latest_authoritative_confirmation.cumulative_confirmed_volume=confirmed;
            confirmation.resulting_pending_request.latest_authoritative_confirmation.residual_volume=residual;
            confirmation.resulting_pending_request.latest_authoritative_confirmation.authority=evidence.authority;
            confirmation.resulting_pending_request.latest_authoritative_confirmation.confirmation_sequence=evidence.correlation.broker_identity.transaction_sequence;
            confirmation.resulting_pending_request.latest_authoritative_confirmation.confirmed_at=evidence.transaction_time;
            confirmation.resulting_pending_request.retry_disposition=SWV5_RETRY_FORBIDDEN;
            confirmation.resulting_pending_request.last_changed_at=context.clock_time;
            confirmation.event_identity_added=true;
         }
         confirmation.diagnostic=(confirmation.duplicate_event ? "EVIDENCE_DUPLICATE_IDEMPOTENT" : "EVIDENCE_ACCEPTED_AND_APPLIED");
         return true;
      }
      confirmation.diagnostic="EVIDENCE_CONFLICT";
      return false;
   }
   virtual bool EvaluateRetry(const SWV5_ContractValidationContext &context,const SWV5_PendingRequest &pending,const SWV5_RetryPolicy &policy,const SWV5_RetryRiskFreshnessEvidence &risk_evidence,const SWV5_RetryNormalizationFreshnessEvidence &normalization_evidence,SWV5_ContractDecision &decision)
   {
      const bool valid=SWV5_TestRetryFreshnessValid(context,pending,policy,risk_evidence,normalization_evidence);
      SWV5_TestSetDecision(context,valid,(valid ? "RETRY_ALLOWED" : "RETRY_FORBIDDEN"),decision);
      return valid;
   }
};

class SWV5_TestPersistenceContract : public ISWV5PersistenceContract
{
private:
   SWV5_PersistedCheckpoint m_checkpoint;
   SWV5_PersistedRequestEvidence m_requests[];
   SWV5_PersistedRequestSetHeader m_request_set_header;
   SWV5_PersistenceNamespace m_storage_namespace;
   int m_request_count;
   bool m_checkpoint_configured;
   bool m_requests_configured;

   void ClearRequests()
   {
      ArrayResize(m_requests,0);
      m_request_count=0;
      m_requests_configured=false;
   }

   void CopyRequests(const SWV5_PersistedRequestEvidence &source[])
   {
      const int count=ArraySize(source);
      ArrayResize(m_requests,count);
      for(int index=0;index<count;index++)
         m_requests[index]=source[index];
      m_request_count=count;
   }

   bool RequestSetValid(const SWV5_ContractValidationContext &context,
                        const SWV5_PersistenceNamespace &persistence_namespace,
                        const SWV5_PersistedRequestEvidence &requests[],
                        const SWV5_PersistedRequestSetHeader &set_header)
   {
      return SWV5_TestRequestSetValid(context,persistence_namespace,requests,set_header);
   }
public:
   SWV5_TestPersistenceContract()
   {
      m_checkpoint_configured=false;
      m_requests_configured=false;
      m_request_count=0;
      ArrayResize(m_requests,0);
   }
   void Configure(const SWV5_PersistedCheckpoint &checkpoint,const SWV5_PersistedRequestEvidence &requests[])
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      ClearRequests();
      m_checkpoint_configured=false;
      if(!SWV5_TestPersistenceRecordValid(context,checkpoint))
         return;
      if(!RequestSetValid(context,checkpoint.header.persistence_namespace,requests,checkpoint.pending_request_set))
         return;
      if((ArraySize(requests)==0 && checkpoint.has_latest_pending_request) ||
         (ArraySize(requests)>0 && (!checkpoint.has_latest_pending_request ||
           !SWV5_TestPersistedRequestEqual(checkpoint.latest_pending_request,requests[ArraySize(requests)-1]))))
         return;
      m_checkpoint=checkpoint;
      m_storage_namespace=checkpoint.header.persistence_namespace;
      m_request_set_header=checkpoint.pending_request_set;
      m_checkpoint_configured=true;
      CopyRequests(requests);
      m_requests_configured=true;
   }
   virtual string ContractName() { return "ISWV5PersistenceContract/V"+IntegerToString(SWV5_PRODUCTION_CONTRACT_VERSION); }
   virtual bool ValidateRecord(const SWV5_ContractValidationContext &context,const SWV5_PersistedCheckpoint &checkpoint,SWV5_PersistenceLoadResult &result)
   {
      const bool valid=SWV5_TestPersistenceRecordValid(context,checkpoint);
      result.contract_version=context.expected_version;
      result.status=(valid ? SWV5_PERSISTENCE_LOADED : SWV5_PERSISTENCE_CHECKSUM_FAILED);
      result.corruption_disposition=(valid ? SWV5_CORRUPTION_REJECT_RECORD : SWV5_CORRUPTION_HALT_AND_RECONCILE);
      result.diagnostic=(valid ? "RECORD_VALID" : "RECORD_INVALID");
      return valid;
   }
   virtual bool LoadLatest(const SWV5_ContractValidationContext &context,const SWV5_PersistenceNamespace &persistence_namespace,SWV5_PersistedCheckpoint &checkpoint,SWV5_PersistenceLoadResult &result)
   {
      const bool valid=m_checkpoint_configured && SWV5_TestContextValid(context) &&
                        SWV5_TestNamespaceEqual(persistence_namespace,m_checkpoint.header.persistence_namespace) &&
                        SWV5_TestPersistenceRecordValid(context,m_checkpoint);
      if(valid) checkpoint=m_checkpoint;
      result.contract_version=context.expected_version;
      result.status=(valid ? SWV5_PERSISTENCE_LOADED : SWV5_PERSISTENCE_NOT_FOUND);
      result.corruption_disposition=SWV5_CORRUPTION_REJECT_RECORD;
      result.diagnostic=(valid ? "LOADED" : "NOT_FOUND");
      return valid;
   }
   virtual bool LoadPendingRequests(const SWV5_ContractValidationContext &context,const SWV5_PersistenceNamespace &persistence_namespace,SWV5_PersistedRequestEvidence &requests[],SWV5_PersistenceLoadResult &result)
   {
      bool records_valid=true;
      for(int index=0;index<ArraySize(m_requests);index++)
      {
         if(!SWV5_TestPersistedRequestValid(context,m_requests[index],m_storage_namespace))
         {
            records_valid=false;
            break;
         }
      }
      const bool checkpoint_coherent=!m_checkpoint_configured ||
                                     (SWV5_TestNamespaceEqual(m_storage_namespace,m_checkpoint.header.persistence_namespace) &&
                                      m_request_count==(int)m_checkpoint.pending_request_set.request_count &&
                                      m_request_set_header.request_set_digest==m_checkpoint.pending_request_set.request_set_digest &&
                                      m_request_set_header.request_index_revision==m_checkpoint.pending_request_set.request_index_revision &&
                                      m_request_set_header.record_sequence==m_checkpoint.pending_request_set.record_sequence);
      const bool valid=m_requests_configured && SWV5_TestContextValid(context) &&
                        SWV5_TestNamespaceEqual(persistence_namespace,m_storage_namespace) &&
                        RequestSetValid(context,m_storage_namespace,m_requests,m_request_set_header) &&
                        m_request_count==ArraySize(m_requests) &&
                       m_request_count==(int)m_request_set_header.request_count &&
                       m_request_set_header.request_set_digest!="" &&
                       m_request_set_header.request_index_revision!="" &&
                       m_request_set_header.record_sequence>0 &&
                       checkpoint_coherent && records_valid;
      ArrayResize(requests,0);
      if(valid)
      {
         ArrayResize(requests,m_request_count);
         for(int index=0;index<m_request_count;index++)
            requests[index]=m_requests[index];
      }
      result.contract_version=context.expected_version;
      result.status=(valid ? SWV5_PERSISTENCE_LOADED :
                    (m_requests_configured && !SWV5_TestNamespaceEqual(persistence_namespace,m_storage_namespace) ? SWV5_PERSISTENCE_OWNER_CONFLICT : SWV5_PERSISTENCE_TRUNCATED));
      result.corruption_disposition=(valid ? SWV5_CORRUPTION_REJECT_RECORD : SWV5_CORRUPTION_HALT_AND_RECONCILE);
      result.diagnostic=(valid ? "REQUESTS_LOADED" : "REQUEST_SET_INVALID");
      return valid;
   }
   virtual bool SavePendingRequests(const SWV5_ContractValidationContext &context,const SWV5_PersistenceNamespace &persistence_namespace,const SWV5_PersistedRequestEvidence &requests[],const SWV5_PersistedRequestSetHeader &set_header,SWV5_ContractDecision &decision)
   {
      const bool checkpoint_coherent=!m_checkpoint_configured ||
                                     SWV5_TestNamespaceEqual(persistence_namespace,m_checkpoint.header.persistence_namespace);
      const bool monotonic_revision=(!m_requests_configured || set_header.record_sequence>m_request_set_header.record_sequence) &&
                                    (!m_checkpoint_configured || set_header.record_sequence>m_checkpoint.header.record_sequence);
      const bool valid=SWV5_TestContextValid(context) && checkpoint_coherent &&
                        monotonic_revision &&
                        RequestSetValid(context,persistence_namespace,requests,set_header);
      if(valid)
      {
         ClearRequests();
         m_storage_namespace=persistence_namespace;
         m_request_set_header=set_header;
         CopyRequests(requests);
         m_requests_configured=true;
         if(m_checkpoint_configured)
         {
            m_checkpoint.pending_request_set=set_header;
            m_checkpoint.has_latest_pending_request=(ArraySize(requests)>0);
            if(ArraySize(requests)>0)
               m_checkpoint.latest_pending_request=requests[ArraySize(requests)-1];
             else
                ZeroMemory(m_checkpoint.latest_pending_request);
             // The V5 reconciliation vector is part of the persisted source of
             // truth and must evolve atomically with request-set replacement.
             m_checkpoint.reconciliation_vector.pending_request_count=set_header.request_count;
             m_checkpoint.reconciliation_vector.request_set_digest=set_header.request_set_digest;
             m_checkpoint.reconciliation_vector.request_set_revision=set_header.request_index_revision;
             m_checkpoint.reconciliation_vector.reconciliation_revision=set_header.record_sequence;
             m_checkpoint.basket.lifecycle.pending_request_count=set_header.request_count;
             m_checkpoint.header.previous_record_sequence=m_checkpoint.header.record_sequence;
             m_checkpoint.header.record_sequence=set_header.record_sequence;
             m_checkpoint.header.written_at=context.clock_time;
             m_checkpoint.header.store_revision=SWV5_TestCanonicalHash(
                SWV5_TestCanonicalField("format","s","SWV5-CHECKPOINT-STORE-REVISION-V5-LP1")+
                SWV5_TestCanonicalField("prior_store_revision","s",m_checkpoint.header.store_revision)+
                SWV5_TestCanonicalUnsignedField("record_sequence",m_checkpoint.header.record_sequence)+
                SWV5_TestCanonicalField("request_set_revision","s",set_header.request_index_revision));
             m_checkpoint.reconciliation_vector.source_summary_digest=SWV5_TestReconciliationSourceDigest(m_checkpoint.reconciliation_vector);
             SWV5_TestSealCheckpoint(m_checkpoint);
          }
      }
      SWV5_TestSetDecision(context,valid,(valid ? "REQUEST_SET_SAVED" : "REQUEST_SET_REJECTED"),decision);
      return valid;
   }
   virtual bool SaveCheckpoint(const SWV5_ContractValidationContext &context,const SWV5_PersistedCheckpoint &checkpoint,SWV5_ContractDecision &decision)
   {
      const bool valid=SWV5_TestPersistenceRecordValid(context,checkpoint);
      if(valid)
      {
         m_checkpoint=checkpoint;
         // Store integrity metadata is independently derived from the copied body.
         SWV5_TestSealCheckpoint(m_checkpoint);
         m_checkpoint_configured=true;
      }
      SWV5_TestSetDecision(context,valid,(valid ? "CHECKPOINT_SAVED" : "CHECKPOINT_REJECTED"),decision);
      return valid;
   }
   virtual bool PublishRestartQueryWatermarks(const SWV5_ContractValidationContext &context,
                                              const SWV5_RestartReconciliationInput &reconciliation_input,
                                              const SWV5_PersistedRequestEvidence &pending_requests[],
                                              const SWV5_AcceptedQueryWatermarkProposal &proposal,
                                              SWV5_PersistedCheckpoint &published_checkpoint,
                                              SWV5_ContractDecision &decision)
   {
      ZeroMemory(published_checkpoint);
      SWV5_RestartReadinessDisposition source_readiness=SWV5_RESTART_HALTED;
      const SWV5_ReconciliationStatus source_status=
         SWV5_TestRestartDisposition(context,reconciliation_input,pending_requests,source_readiness);
      SWV5_AcceptedQueryWatermarkProposal expected_proposal;
      const bool source_safe=source_status==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED &&
                             source_readiness==SWV5_RESTART_SAFE_TO_RESUME &&
                             SWV5_TestBuildAcceptedQueryWatermarkProposal(context,reconciliation_input,source_readiness,expected_proposal);
      bool valid=m_checkpoint_configured && source_safe && SWV5_TestContextValid(context) &&
                 SWV5_TestPersistenceRecordValid(context,m_checkpoint) &&
                 SWV5_TestCanonicalCheckpointPayload(reconciliation_input.persisted)==SWV5_TestCanonicalCheckpointPayload(m_checkpoint) &&
                 SWV5_TestCanonicalAcceptedQueryWatermarkProposal(proposal)==SWV5_TestCanonicalAcceptedQueryWatermarkProposal(expected_proposal) &&
                 SWV5_TestAcceptedQueryWatermarkProposalValid(context,m_checkpoint,proposal) &&
                 context.clock_time>=m_checkpoint.header.written_at;
      SWV5_PersistedCheckpoint candidate;
      if(valid)
      {
         candidate=m_checkpoint;
         candidate.reconciliation_vector.broker_query_sequence_high_watermark=
            proposal.accepted_broker_query_high_watermark;
         candidate.reconciliation_vector.request_query_sequence_high_watermark=
            proposal.accepted_execution_query_high_watermark;
         candidate.reconciliation_vector.reconciliation_revision=proposal.next_reconciliation_revision;
         candidate.header.previous_record_sequence=m_checkpoint.header.record_sequence;
         candidate.header.record_sequence=m_checkpoint.header.record_sequence+1;
         candidate.header.written_at=context.clock_time;
         candidate.header.store_revision=SWV5_TestCanonicalHash(
            SWV5_TestCanonicalField("format","s","SWV5-RESTART-QUERY-PUBLICATION-V5-LP1")+
            SWV5_TestCanonicalField("prior_store_revision","s",m_checkpoint.header.store_revision)+
            SWV5_TestCanonicalUnsignedField("record_sequence",candidate.header.record_sequence)+
            SWV5_TestCanonicalUnsignedField("broker_query_high_watermark",proposal.accepted_broker_query_high_watermark)+
            SWV5_TestCanonicalUnsignedField("execution_query_high_watermark",proposal.accepted_execution_query_high_watermark)+
            SWV5_TestCanonicalUnsignedField("reconciliation_revision",proposal.next_reconciliation_revision));
         candidate.reconciliation_vector.source_summary_digest=
            SWV5_TestReconciliationSourceDigest(candidate.reconciliation_vector);
         SWV5_TestSealCheckpoint(candidate);
         valid=SWV5_TestPersistenceRecordValid(context,candidate);
      }
      if(valid)
      {
         m_checkpoint=candidate;
         published_checkpoint=candidate;
      }
      SWV5_TestSetDecision(context,valid,(valid ? "RESTART_QUERY_WATERMARKS_PUBLISHED" : "RESTART_QUERY_WATERMARK_PUBLICATION_REJECTED"),decision);
      return valid;
   }
   virtual bool ReconcileRestart(const SWV5_ContractValidationContext &context,const SWV5_RestartReconciliationInput &engineInput,const SWV5_PersistedRequestEvidence &pending_requests[],SWV5_RestartReconciliationResult &result)
   {
      ZeroMemory(result);
      result.contract_version=context.expected_version;
      result.status=SWV5_TestRestartDisposition(context,engineInput,pending_requests,result.readiness_disposition);
      result.required_state=(result.status==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED ? engineInput.persisted.basket.lifecycle.state : SWV5_BASKET_HALTED);
      result.reason_flags=(result.readiness_disposition==SWV5_RESTART_SAFE_TO_RESUME ? 0 : 1);
      result.diagnostic=(result.readiness_disposition==SWV5_RESTART_SAFE_TO_RESUME ? "SAFE_TO_RESUME" :
                         (result.readiness_disposition==SWV5_RESTART_RECONCILIATION_REQUIRED ? "RECONCILIATION_REQUIRED" :
                          (result.readiness_disposition==SWV5_RESTART_RETRY_FORBIDDEN ? "RETRY_FORBIDDEN" :
                            (result.readiness_disposition==SWV5_RESTART_CLOSE_ONLY ? "CLOSE_ONLY" : "HALTED"))));
      result.has_accepted_query_watermark_proposal=
         SWV5_TestBuildAcceptedQueryWatermarkProposal(context,engineInput,result.readiness_disposition,result.accepted_query_watermarks);
      return result.readiness_disposition==SWV5_RESTART_SAFE_TO_RESUME;
   }
};

class SWV5_TestRiskContract : public ISWV5RiskContract
{
public:
   virtual string ContractName() { return "ISWV5RiskContract/V"+IntegerToString(SWV5_PRODUCTION_CONTRACT_VERSION); }
   virtual bool ValidateLimits(const SWV5_ContractValidationContext &context,const SWV5_RiskLimits &limits,SWV5_ContractDecision &decision)
   {
      const bool valid=SWV5_TestContextValid(context) && SWV5_TestRiskLimitsComplete(context,limits);
      SWV5_TestSetDecision(context,valid,(valid ? "LIMITS_VALID" : "LIMITS_INVALID"),decision);
      return valid;
   }
   virtual bool Evaluate(const SWV5_ContractValidationContext &context,const SWV5_RiskEvaluationInput &engineInput,SWV5_RiskAuthorization &authorization)
   {
      const bool coherent=SWV5_TestRiskInputCoherent(context,engineInput);
      ZeroMemory(authorization);
      authorization.contract_version=context.expected_version;
      authorization.authorization_id="";
      authorization.limits_contract_id="";
      authorization.request_identity.request_id.correlation_id="";
      authorization.request_identity.request_id.attempt_id="";
      authorization.request_identity.request_id.parent_attempt_id="";
      authorization.request_identity.idempotency_key="";
      authorization.persistence_namespace.basket_id.value="";
      authorization.hard_kill_latch_id="";
      authorization.authorized_volume=0.0;
      authorization.authorized_projected_margin=0.0;
      authorization.disposition=SWV5_RISK_RECONCILIATION_REQUIRED;
      authorization.blocking_domain=SWV5_RISK_DOMAIN_ACCOUNT;
      authorization.reason_flags=SWV5_RISK_DATA_UNAVAILABLE;
      authorization.reason_text="RISK_INPUT_INCOHERENT";
      if(!coherent)
         return false;
      authorization.authorization_id=engineInput.intent.risk_authorization_id;
      authorization.limits_contract_id=engineInput.limits.contract_id;
      authorization.authorized_limits=engineInput.limits;
      authorization.request_identity=engineInput.intent.request_identity;
      authorization.persistence_namespace=engineInput.intent.persistence_namespace;
      authorization.ownership_fence=engineInput.ownership_fence;
      authorization.account_namespace=engineInput.account_namespace;
      authorization.account_mode=engineInput.account_mode;
      authorization.disposition=SWV5_RISK_ALLOW;
      authorization.blocking_domain=SWV5_RISK_DOMAIN_NONE;
      authorization.reason_flags=0;
      authorization.basket_state_version=engineInput.intent.expected_basket_version;
      authorization.symbol_specification_sequence=engineInput.intent.symbol_specification_sequence;
      authorization.authorized_intent_type=engineInput.intent.intent_type;
      authorization.authorized_direction=engineInput.intent.direction;
      authorization.authorized_volume=engineInput.intent.normalized_volume;
      authorization.authorized_price=engineInput.intent.normalized_price;
      authorization.authorized_stop_price=engineInput.intent.normalized_stop_price;
      authorization.authorized_limit_price=engineInput.intent.normalized_limit_price;
      authorization.risk_snapshot_epoch=engineInput.account_namespace.snapshot_epoch;
      authorization.risk_snapshot_sequence=engineInput.account_namespace.snapshot_sequence;
      authorization.authorized_projected_loss=engineInput.projected.basket_risk_evidence.resulting_basket_maximum_loss;
      authorization.authorized_projected_notional=engineInput.projected.projected_notional;
      authorization.authorized_projected_margin=engineInput.projected.margin_evidence.additional_margin;
      authorization.hard_kill_latch_id=engineInput.hard_kill_state.latch_id;
      authorization.hard_kill_latch_generation=engineInput.hard_kill_state.latch_generation;
      authorization.monetary_basis=engineInput.projected.monetary_basis;
      authorization.evaluated_at=context.clock_time;
      const datetime policy_expiry=context.clock_time+(datetime)engineInput.limits.maximum_snapshot_age_seconds;
      authorization.expires_at=(engineInput.intent.authorization_expires_at<policy_expiry ? engineInput.intent.authorization_expires_at : policy_expiry);
      authorization.reason_text="COMPLETE_AUTHORIZATION";
      return true;
   }
   virtual bool ValidateAuthorization(const SWV5_ContractValidationContext &context,const SWV5_RiskAuthorization &authorization,const SWV5_RiskEvaluationInput &current_binding,SWV5_ContractDecision &decision)
   {
      const bool valid=SWV5_TestAuthorizationMatches(context,authorization,current_binding);
      SWV5_TestSetDecision(context,valid,(valid ? "AUTHORIZATION_VALID" : "AUTHORIZATION_INVALID"),decision);
      return valid;
   }
   virtual bool ValidateHardKillRelease(const SWV5_ContractValidationContext &context,const SWV5_HardKillState &current_state,const SWV5_HardKillReleaseEvidence &evidence,SWV5_ContractDecision &decision)
   {
      return ValidateHardKillReleaseMode(context,current_state,evidence,SWV5_HARD_KILL_RELEASE_CURRENT_EXECUTION,decision);
   }
   virtual bool ValidateHardKillReleaseMode(const SWV5_ContractValidationContext &context,const SWV5_HardKillState &current_state,const SWV5_HardKillReleaseEvidence &evidence,const SWV5_HardKillReleaseValidationMode mode,SWV5_ContractDecision &decision)
   {
      const bool valid=mode==SWV5_HARD_KILL_RELEASE_CURRENT_EXECUTION &&
                       SWV5_TestHardKillReleaseValid(context,current_state,evidence,mode) &&
                       SWV5_TestNamespaceEqual(current_state.persistence_namespace,evidence.persistence_namespace);
      SWV5_TestSetDecision(context,valid,(valid ? "HARD_KILL_RELEASE_VALID" : "HARD_KILL_RELEASE_REJECTED"),decision);
      return valid;
   }
   virtual bool ValidateHistoricalHardKillRelease(const SWV5_ContractValidationContext &context,const SWV5_HardKillState &persisted_state,const SWV5_HardKillReleaseEvidence &checkpoint_evidence,const SWV5_HardKillReleaseAuthorityRecord &authority_record,SWV5_ContractDecision &decision)
   {
      const bool valid=SWV5_TestHistoricalHardKillReleaseValid(context,persisted_state,checkpoint_evidence,authority_record);
      SWV5_TestSetDecision(context,valid,
                           valid ? "HARD_KILL_HISTORICAL_AUTHORITY_VERIFIED" : "HARD_KILL_HISTORICAL_AUTHORITY_MISMATCH",
                           decision);
      if(!valid) decision.disposition=SWV5_DISPOSITION_HALT;
      return valid;
   }
};

class SWV5_TestStatisticsContract : public ISWV5StatisticsContract
{
public:
   virtual string ContractName() { return "ISWV5StatisticsContract/V"+IntegerToString(SWV5_PRODUCTION_CONTRACT_VERSION); }
   virtual bool ValidateDeal(const SWV5_ContractValidationContext &validation_context,const SWV5_AuthoritativeDeal &deal,const SWV5_StatisticsBuildContext &context,SWV5_ContractDecision &decision)
   {
      const bool valid=SWV5_TestDealValid(deal,context);
      SWV5_TestSetDecision(validation_context,valid,(valid ? "DEAL_VALID" : "DEAL_INVALID"),decision);
      return valid;
   }
   virtual bool AccumulateDeal(const SWV5_ContractValidationContext &validation_context,const SWV5_AuthoritativeDeal &deal,const SWV5_StatisticsDeduplicationEvidence &deduplication_evidence,const SWV5_BasketStatistics &current,SWV5_BasketStatistics &next)
   {
      if(!SWV5_TestVersionValid(deal.contract_version) || !SWV5_TestNamespaceEqual(deal.persistence_namespace,current.persistence_namespace) ||
         !SWV5_TestCorrelationComplete(deal.correlation) || !deal.monetary_components_complete || deal.account_currency=="" ||
         !SWV5_TestCorrelationEqual(deal.correlation,deduplication_evidence.correlation) ||
         deduplication_evidence.prior_identity_index_revision!=current.deduplication.identities.index_revision)
         return false;
      next=current;
      SWV5_DurableEventIdentitySet updated_identities;
      const SWV5_StatisticsIdentityDisposition actual=SWV5_TestAppendEventIdentity(deal.correlation.broker_identity.broker_event_id,
                                                                                    deal.correlation.broker_identity.transaction_sequence,
                                                                                    current.deduplication.identities,
                                                                                    updated_identities);
      if(actual==SWV5_STAT_IDENTITY_CONFLICT || actual!=deduplication_evidence.disposition)
         return false;
      if(actual==SWV5_STAT_IDENTITY_DUPLICATE)
      {
         if(deduplication_evidence.membership_proof=="") return false;
         next.deduplication.duplicate_deal_count++;
         return true;
      }
      if(deduplication_evidence.membership_proof!="") return false;
      next.deduplication.identities=updated_identities;
      next.deal_count++;
      if(deal.entry_kind==SWV5_DEAL_ENTRY_IN) { next.entry_deal_count++; next.entered_volume+=deal.volume; }
      else { next.exit_deal_count++; next.exited_volume+=deal.volume; }
      next.residual_volume=MathMax(0.0,current.residual_volume-deal.volume);
      if(next.residual_volume>validation_context.volume_tolerance)
         next.partial_close_count++;
      next.gross_profit+=deal.gross_profit;
      next.commission+=deal.commission;
      next.swap+=deal.swap;
      next.fee+=deal.fee;
      next.authoritative_net_result+=SWV5_TestDealNet(deal);
      next.deduplication.unique_deal_count++;
      if(next.first_deal_time==0 || deal.deal_time<next.first_deal_time) next.first_deal_time=deal.deal_time;
      if(deal.deal_time>next.last_deal_time) next.last_deal_time=deal.deal_time;
      return true;
   }
   virtual bool Finalize(const SWV5_ContractValidationContext &validation_context,const SWV5_StatisticsBuildContext &context,const SWV5_BasketStatistics &statistics,SWV5_StatisticsValidationResult &result)
   {
      const bool valid=SWV5_TestQueriesComplete(context.history_queries) && statistics.history_complete && statistics.account_currency!="" &&
                       SWV5_TestNear(statistics.authoritative_net_result,statistics.gross_profit+statistics.commission+statistics.swap+statistics.fee,validation_context.price_tolerance);
      result.contract_version=validation_context.expected_version;
      SWV5_TestSetDecision(validation_context,valid,(valid ? "STATISTICS_COMPLETE" : "STATISTICS_INCOMPLETE"),result.decision);
      result.validation_flags=(valid ? SWV5_STAT_SOURCE_AUTHORITATIVE|SWV5_STAT_MONETARY_COMPLETE|SWV5_STAT_IDENTITY_SET_VALID : 0);
      return valid;
   }
};

class SWV5_TestOwnershipContract : public ISWV5InstanceOwnershipContract
{
public:
   virtual string ContractName() { return "ISWV5InstanceOwnershipContract/V"+IntegerToString(SWV5_PRODUCTION_CONTRACT_VERSION); }
   virtual bool Acquire(const SWV5_ContractValidationContext &context,const SWV5_OwnershipClaim &claim,const SWV5_InstanceLease &observed,SWV5_OwnershipDecision &decision)
   {
      const bool unclaimed=observed.status==SWV5_LOCK_UNCLAIMED;
      const bool valid=(unclaimed ? SWV5_TestUnclaimedClaimValid(context,claim,observed) : SWV5_TestCanTakeover(context,claim,observed));
      decision.contract_version=context.expected_version;
      SWV5_TestSetDecision(context,valid,(valid ? "OWNERSHIP_ACQUIRED" : "OWNERSHIP_REJECTED"),decision.decision);
      decision.resulting_lease=observed;
      if(valid)
      {
         decision.resulting_lease.contract_version=context.expected_version;
         decision.resulting_lease.fence.contract_version=context.expected_version;
         decision.resulting_lease.fence.ownership_namespace=claim.claimant.key;
         decision.resulting_lease.fence.owner=claim.claimant;
         decision.resulting_lease.fence.lease_version=observed.fence.lease_version+1;
          decision.resulting_lease.status=SWV5_LOCK_ACQUIRED;
          decision.resulting_lease.clock_id=context.clock_id;
          decision.resulting_lease.clock_authority=context.clock_authority;
         decision.resulting_lease.acquired_clock_sequence=context.clock_sequence;
         decision.resulting_lease.heartbeat_clock_sequence=context.clock_sequence;
         decision.resulting_lease.expiry_clock_sequence=context.clock_sequence+claim.lease_duration_seconds;
          decision.resulting_lease.heartbeat_sequence=(unclaimed ? 1 : observed.heartbeat_sequence+1);
         decision.resulting_lease.acquired_at=context.clock_time;
         decision.resulting_lease.heartbeat_at=context.clock_time;
         decision.resulting_lease.expires_at=context.clock_time+(datetime)claim.lease_duration_seconds;
         if(observed.status==SWV5_LOCK_EXPIRED)
            decision.resulting_lease.fence.takeover_generation=claim.takeover_evidence.proposed_takeover_generation;
         decision.resulting_lease.fence.fencing_token_digest=SWV5_TestCanonicalHash(
             SWV5_TestCanonicalField("format","s","SWV5-OWNERSHIP-FENCE-V"+IntegerToString(SWV5_PRODUCTION_CONTRACT_VERSION))+
             SWV5_TestCanonicalField("ownership_namespace","x",SWV5_TestCanonicalOwnershipKey(claim.claimant.key))+
             SWV5_TestCanonicalField("owner","x",SWV5_TestCanonicalOwner(claim.claimant))+
             SWV5_TestCanonicalUnsignedField("lease_version",decision.resulting_lease.fence.lease_version)+
             SWV5_TestCanonicalUnsignedField("takeover_generation",decision.resulting_lease.fence.takeover_generation));
         decision.resulting_lease.store_revision=SWV5_TestCanonicalHash(
            SWV5_TestCanonicalField("format","s","SWV5-OWNERSHIP-STORE-REVISION-V1")+
            SWV5_TestCanonicalField("prior_store_revision","s",observed.store_revision)+
            SWV5_TestCanonicalField("fencing_token_digest","s",decision.resulting_lease.fence.fencing_token_digest)+
            SWV5_TestCanonicalUnsignedField("lease_version",decision.resulting_lease.fence.lease_version)+
            SWV5_TestCanonicalUnsignedField("takeover_generation",decision.resulting_lease.fence.takeover_generation));
      }
      return valid;
   }
   virtual bool Heartbeat(const SWV5_ContractValidationContext &context,const SWV5_InstanceLease &lease,const SWV5_InstanceLease &observed,SWV5_OwnershipDecision &decision)
   {
      const bool valid=SWV5_TestHeartbeatValid(context,lease,observed);
      decision.contract_version=context.expected_version;
      SWV5_TestSetDecision(context,valid,(valid ? "HEARTBEAT_VALID" : "HEARTBEAT_REJECTED"),decision.decision);
      decision.resulting_lease=observed;
      if(valid)
      {
          const ulong sequence_extension=observed.expiry_clock_sequence-observed.heartbeat_clock_sequence;
          const datetime time_extension=observed.expires_at-observed.heartbeat_at;
          decision.resulting_lease.status=SWV5_LOCK_RENEWED;
          decision.resulting_lease.heartbeat_sequence=observed.heartbeat_sequence+1;
         decision.resulting_lease.heartbeat_clock_sequence=context.clock_sequence;
         decision.resulting_lease.expiry_clock_sequence=context.clock_sequence+sequence_extension;
          decision.resulting_lease.heartbeat_at=context.clock_time;
          decision.resulting_lease.expires_at=context.clock_time+time_extension;
          decision.resulting_lease.store_revision=SWV5_TestCanonicalHash(
             SWV5_TestCanonicalField("format","s","SWV5-OWNERSHIP-STORE-REVISION-V1")+
             SWV5_TestCanonicalField("prior_store_revision","s",observed.store_revision)+
             SWV5_TestCanonicalField("fencing_token_digest","s",observed.fence.fencing_token_digest)+
             SWV5_TestCanonicalUnsignedField("heartbeat_sequence",decision.resulting_lease.heartbeat_sequence)+
             SWV5_TestCanonicalUnsignedField("heartbeat_clock_sequence",decision.resulting_lease.heartbeat_clock_sequence));
      }
      return valid;
   }
   virtual bool DetectConflict(const SWV5_ContractValidationContext &context,const SWV5_OwnershipClaim &claim,const SWV5_InstanceLease &observed,SWV5_OwnershipConflict &conflict)
   {
      const bool detected=SWV5_TestActiveOwnedStatus(observed.status) && !SWV5_TestOwnerEqual(claim.claimant,observed.fence.owner);
      conflict.contract_version=context.expected_version;
      conflict.key=observed.fence.ownership_namespace;
      conflict.claimant=claim.claimant;
      conflict.incumbent=observed.fence.owner;
      conflict.status=(detected ? SWV5_LOCK_CONFLICT : observed.status);
      conflict.simultaneous_heartbeat=detected;
      conflict.stale_incumbent=false;
      conflict.diagnostic=(detected ? "OWNER_CONFLICT" : "NO_CONFLICT");
      return detected;
   }
   virtual bool Release(const SWV5_ContractValidationContext &context,const SWV5_InstanceLease &lease,const SWV5_InstanceLease &observed,SWV5_OwnershipDecision &decision)
   {
      const bool valid=SWV5_TestActiveOwnedStatus(lease.status) && SWV5_TestInstanceLeaseEqual(lease,observed);
      decision.contract_version=context.expected_version;
      SWV5_TestSetDecision(context,valid,(valid ? "RELEASED" : "STALE_OWNER"),decision.decision);
      decision.resulting_lease=observed;
      if(valid) decision.resulting_lease.status=SWV5_LOCK_RELEASED;
      return valid;
   }
};

class SWV5_TestUnitSystemContract : public ISWV5UnitSystemContract
{
public:
   virtual string ContractName() { return "ISWV5UnitSystemContract/V"+IntegerToString(SWV5_PRODUCTION_CONTRACT_VERSION); }
   virtual bool ValidateSpecification(const SWV5_ContractValidationContext &context,const SWV5_SymbolUnitSpecification &specification,SWV5_UnitValidationResult &result)
   {
      const bool valid=SWV5_TestSpecificationValid(context,specification);
      result.contract_version=context.expected_version;
      SWV5_TestSetDecision(context,valid,(valid ? "SPECIFICATION_VALID" : "SPECIFICATION_INVALID"),result.decision);
      result.validation_flags=(valid ? SWV5_UNIT_POINT_VALID|SWV5_UNIT_TICK_VALID|SWV5_UNIT_SPECIFICATION_FRESH : 0);
      return valid;
   }
   virtual bool Normalize(const SWV5_ContractValidationContext &context,const SWV5_SymbolUnitSpecification &specification,const SWV5_UnitNormalizationRequest &request,SWV5_NormalizedUnits &normalized,SWV5_UnitValidationResult &result)
   {
      const bool valid=SWV5_TestNormalize(context,specification,request,normalized);
      result.contract_version=context.expected_version;
      SWV5_TestSetDecision(context,valid,(valid ? "UNITS_NORMALIZED" : "UNITS_REJECTED"),result.decision);
      result.validation_flags=0;
      if(valid)
      {
         result.validation_flags=SWV5_UNIT_POINT_VALID|SWV5_UNIT_TICK_VALID|SWV5_UNIT_SPECIFICATION_FRESH|
                                 SWV5_UNIT_STOPS_LEVEL_VALID|SWV5_UNIT_FREEZE_LEVEL_VALID;
         if(normalized.volume_aligned_to_step)
            result.validation_flags|=SWV5_UNIT_VOLUME_STEP_VALID;
         if(normalized.derived_operation_semantic!=SWV5_UNIT_OPERATION_RESIDUAL_CLOSE)
            result.validation_flags|=SWV5_UNIT_VOLUME_RANGE_VALID;
      }
      return valid;
   }
};

#endif
