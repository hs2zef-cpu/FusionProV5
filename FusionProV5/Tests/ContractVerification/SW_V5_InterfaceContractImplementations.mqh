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
   virtual string ContractName() { return "ISWV5ContractVersionPolicy/V3"; }
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
   virtual string ContractName() { return "ISWV5BasketStateMachineContract/V3"; }
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
      ulong resulting_version=snapshot.state_version;
      const SWV5_TestBasketRule rule=SWV5_TestEvaluateBasketTransition(context,snapshot,request,resulting_version);
      const bool allowed=(rule!=SWV5_TEST_BASKET_FORBID);
      decision.contract_version=context.expected_version;
      SWV5_TestSetDecision(context,allowed,(allowed ? "TRANSITION_ACCEPTED" : "TRANSITION_REJECTED"),decision.decision);
      decision.resulting_state=(allowed ? request.to_state : snapshot.state);
      decision.resulting_state_version=resulting_version;
      decision.resulting_cumulative_recovery_attempts=snapshot.cumulative_recovery_attempts;
      decision.resulting_recovery_layer=snapshot.current_recovery_layer;
      if(allowed && snapshot.state==SWV5_BASKET_ACTIVE && request.to_state==SWV5_BASKET_RECOVERY)
      {
         decision.resulting_cumulative_recovery_attempts=request.recovery_evidence.proposed_cumulative_recovery_attempts;
         decision.resulting_recovery_layer=request.recovery_evidence.proposed_recovery_layer;
      }
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
   virtual string ContractName() { return "ISWV5BasketContract/V3"; }
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
   virtual string ContractName() { return "ISWV5ExecutionContract/V3"; }
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
      classification.classification=SWV5_TestClassifyRetcode(evidence.raw_retcode);
      classification.retry_disposition=(classification.classification==SWV5_RETCODE_CONNECTION_UNCERTAIN ? SWV5_RETRY_REQUIRES_RECONCILIATION : SWV5_RETRY_FORBIDDEN);
      classification.mapping_policy_id="TEST-RETCODE-MAP-V3";
      const bool known=(classification.classification!=SWV5_RETCODE_UNCLASSIFIED);
      SWV5_TestSetDecision(context,known,(known ? "RETCODE_CLASSIFIED" : "RETCODE_UNKNOWN"),classification.decision);
      return known;
   }
   virtual bool AcceptTransactionEvidence(const SWV5_ContractValidationContext &context,const SWV5_PendingRequest &pending,const SWV5_TransactionEvidence &evidence,SWV5_ExecutionConfirmation &confirmation)
   {
      double confirmed=0.0,residual=0.0;
      const SWV5_ConfirmationStatus status=SWV5_TestConfirmExecution(pending,evidence,confirmed,residual);
      confirmation.contract_version=context.expected_version;
      confirmation.persistence_namespace=evidence.persistence_namespace;
      confirmation.ownership_fence=evidence.ownership_fence;
      confirmation.correlation=evidence.correlation;
      confirmation.status=status;
      confirmation.disposition=(status==SWV5_CONFIRMATION_CONFLICT ? SWV5_DISPOSITION_RECONCILE : SWV5_DISPOSITION_ALLOW);
      confirmation.confirmed_volume=confirmed;
      confirmation.residual_volume=residual;
      confirmation.symbol_specification_sequence=evidence.symbol_specification_sequence;
      confirmation.diagnostic=(status==SWV5_CONFIRMATION_CONFLICT ? "EVIDENCE_CONFLICT" : "EVIDENCE_ACCEPTED");
      return status==SWV5_CONFIRMATION_CONFIRMED || status==SWV5_CONFIRMATION_PARTIAL;
   }
   virtual bool EvaluateRetry(const SWV5_ContractValidationContext &context,const SWV5_PendingRequest &pending,const SWV5_RetryPolicy &policy,SWV5_ContractDecision &decision)
   {
      const bool valid=pending.lifecycle_phase!=SWV5_EXECUTION_PHASE_UNCERTAIN && pending.submission_attempt_count<policy.maximum_attempts &&
                       policy.disposition!=SWV5_RETRY_FORBIDDEN && policy.earliest_retry_at<=context.clock_time;
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

   bool RequestSetValid(const SWV5_PersistenceNamespace &persistence_namespace,
                        const SWV5_PersistedRequestEvidence &requests[],
                        const SWV5_PersistedRequestSetHeader &set_header)
   {
      if(!SWV5_TestNamespaceComplete(persistence_namespace) ||
         !SWV5_TestVersionValid(set_header.contract_version) ||
         ArraySize(requests)!=(int)set_header.request_count ||
         set_header.request_set_digest=="" ||
         set_header.request_index_revision=="" ||
         set_header.record_sequence==0)
         return false;
      for(int index=0;index<ArraySize(requests);index++)
      {
         if(!SWV5_TestPersistedRequestValid(requests[index],persistence_namespace))
            return false;
      }
      return true;
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
      ClearRequests();
      m_checkpoint_configured=SWV5_TestPersistenceRecordValid(checkpoint);
      if(!m_checkpoint_configured)
         return;
      m_checkpoint=checkpoint;
      m_storage_namespace=checkpoint.header.persistence_namespace;
      m_request_set_header=checkpoint.pending_request_set;
      if(!RequestSetValid(m_storage_namespace,requests,m_request_set_header))
         return;
      CopyRequests(requests);
      m_requests_configured=true;
   }
   virtual string ContractName() { return "ISWV5PersistenceContract/V3"; }
   virtual bool ValidateRecord(const SWV5_ContractValidationContext &context,const SWV5_PersistedCheckpoint &checkpoint,SWV5_PersistenceLoadResult &result)
   {
      const bool valid=SWV5_TestContextValid(context) && SWV5_TestPersistenceRecordValid(checkpoint);
      result.contract_version=context.expected_version;
      result.status=(valid ? SWV5_PERSISTENCE_LOADED : SWV5_PERSISTENCE_CHECKSUM_FAILED);
      result.corruption_disposition=(valid ? SWV5_CORRUPTION_REJECT_RECORD : SWV5_CORRUPTION_HALT_AND_RECONCILE);
      result.diagnostic=(valid ? "RECORD_VALID" : "RECORD_INVALID");
      return valid;
   }
   virtual bool LoadLatest(const SWV5_ContractValidationContext &context,const SWV5_PersistenceNamespace &persistence_namespace,SWV5_PersistedCheckpoint &checkpoint,SWV5_PersistenceLoadResult &result)
   {
      const bool valid=m_checkpoint_configured && SWV5_TestContextValid(context) &&
                       SWV5_TestNamespaceEqual(persistence_namespace,m_checkpoint.header.persistence_namespace);
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
         if(!SWV5_TestPersistedRequestValid(m_requests[index],m_storage_namespace))
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
      const bool valid=SWV5_TestContextValid(context) && checkpoint_coherent &&
                       RequestSetValid(persistence_namespace,requests,set_header);
      if(valid)
      {
         ClearRequests();
         m_storage_namespace=persistence_namespace;
         m_request_set_header=set_header;
         CopyRequests(requests);
         m_requests_configured=true;
         if(m_checkpoint_configured)
            m_checkpoint.pending_request_set=set_header;
      }
      SWV5_TestSetDecision(context,valid,(valid ? "REQUEST_SET_SAVED" : "REQUEST_SET_REJECTED"),decision);
      return valid;
   }
   virtual bool SaveCheckpoint(const SWV5_ContractValidationContext &context,const SWV5_PersistedCheckpoint &checkpoint,SWV5_ContractDecision &decision)
   {
      const bool valid=SWV5_TestPersistenceRecordValid(checkpoint);
      if(valid)
      {
         m_checkpoint=checkpoint;
         m_checkpoint_configured=true;
      }
      SWV5_TestSetDecision(context,valid,(valid ? "CHECKPOINT_SAVED" : "CHECKPOINT_REJECTED"),decision);
      return valid;
   }
   virtual bool ReconcileRestart(const SWV5_ContractValidationContext &context,const SWV5_RestartReconciliationInput &engineInput,SWV5_RestartReconciliationResult &result)
   {
      result.contract_version=context.expected_version;
      result.status=SWV5_TestRestartDisposition(engineInput);
      result.required_state=(result.status==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED ? engineInput.persisted.basket.lifecycle.state : SWV5_BASKET_HALTED);
      result.reason_flags=(result.status==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED ? 0 : 1);
      result.diagnostic=(result.reason_flags==0 ? "MATCHED" : "RECONCILIATION_REQUIRED");
      result.readiness_disposition=(result.status==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED && engineInput.persisted.pending_request_set.request_count==0 ? SWV5_RESTART_SAFE_TO_RESUME :
                                    (engineInput.persisted.hard_kill_state.state==SWV5_HARD_KILL_ACTIVE ? SWV5_RESTART_CLOSE_ONLY : SWV5_RESTART_HALTED));
      return result.readiness_disposition==SWV5_RESTART_SAFE_TO_RESUME;
   }
};

class SWV5_TestRiskContract : public ISWV5RiskContract
{
public:
   virtual string ContractName() { return "ISWV5RiskContract/V3"; }
   virtual bool ValidateLimits(const SWV5_ContractValidationContext &context,const SWV5_RiskLimits &limits,SWV5_ContractDecision &decision)
   {
      const bool valid=limits.contract_id!="" && limits.maximum_snapshot_age_seconds>0 && limits.maximum_cumulative_recovery_attempts>0;
      SWV5_TestSetDecision(context,valid,(valid ? "LIMITS_VALID" : "LIMITS_INVALID"),decision);
      return valid;
   }
   virtual bool Evaluate(const SWV5_ContractValidationContext &context,const SWV5_RiskEvaluationInput &engineInput,SWV5_RiskAuthorization &authorization)
   {
      const bool coherent=engineInput.account_mode==SWV5_ACCOUNT_MODE_HEDGING && engineInput.intent.account_mode==engineInput.account_mode &&
                          SWV5_TestAccountNamespaceEqual(engineInput.account_namespace,engineInput.account.account_namespace,false) &&
                          SWV5_TestAccountNamespaceEqual(engineInput.account_namespace,engineInput.exposure.account_namespace,false) &&
                          SWV5_TestAccountNamespaceEqual(engineInput.account_namespace,engineInput.basket.account_namespace,false) &&
                          SWV5_TestAccountNamespaceEqual(engineInput.account_namespace,engineInput.projected.account_namespace,false) &&
                          engineInput.account_namespace.snapshot_epoch==engineInput.hard_kill_state.account_namespace.snapshot_epoch;
      authorization.contract_version=context.expected_version;
      authorization.request_identity=engineInput.intent.request_identity;
      authorization.persistence_namespace=engineInput.intent.persistence_namespace;
      authorization.ownership_fence=engineInput.ownership_fence;
      authorization.account_namespace=engineInput.account_namespace;
      authorization.account_mode=engineInput.account_mode;
      authorization.disposition=(coherent ? SWV5_RISK_ALLOW : SWV5_RISK_RECONCILIATION_REQUIRED);
      authorization.risk_snapshot_epoch=engineInput.account_namespace.snapshot_epoch;
      authorization.evaluated_at=context.clock_time;
      authorization.expires_at=context.clock_time+60;
      authorization.reason_text=(coherent ? "COHERENT_EPOCH" : "ACCOUNT_NAMESPACE_CONFLICT");
      return coherent;
   }
   virtual bool ValidateAuthorization(const SWV5_ContractValidationContext &context,const SWV5_RiskAuthorization &authorization,const SWV5_ExecutionIntent &intent,SWV5_ContractDecision &decision)
   {
      const bool valid=SWV5_TestAuthorizationMatches(context,authorization,intent);
      SWV5_TestSetDecision(context,valid,(valid ? "AUTHORIZATION_VALID" : "AUTHORIZATION_INVALID"),decision);
      return valid;
   }
   virtual bool ValidateHardKillRelease(const SWV5_ContractValidationContext &context,const SWV5_HardKillState &current_state,const SWV5_HardKillReleaseEvidence &evidence,SWV5_ContractDecision &decision)
   {
      const bool valid=SWV5_TestHardKillReleaseValid(context,current_state,evidence) &&
                       SWV5_TestNamespaceEqual(current_state.persistence_namespace,evidence.persistence_namespace);
      SWV5_TestSetDecision(context,valid,(valid ? "HARD_KILL_RELEASE_VALID" : "HARD_KILL_RELEASE_REJECTED"),decision);
      return valid;
   }
};

class SWV5_TestStatisticsContract : public ISWV5StatisticsContract
{
public:
   virtual string ContractName() { return "ISWV5StatisticsContract/V3"; }
   virtual bool ValidateDeal(const SWV5_ContractValidationContext &validation_context,const SWV5_AuthoritativeDeal &deal,const SWV5_StatisticsBuildContext &context,SWV5_ContractDecision &decision)
   {
      const bool valid=SWV5_TestDealValid(deal,context);
      SWV5_TestSetDecision(validation_context,valid,(valid ? "DEAL_VALID" : "DEAL_INVALID"),decision);
      return valid;
   }
   virtual bool AccumulateDeal(const SWV5_ContractValidationContext &validation_context,const SWV5_AuthoritativeDeal &deal,const SWV5_StatisticsDeduplicationEvidence &deduplication_evidence,const SWV5_BasketStatistics &current,SWV5_BasketStatistics &next)
   {
      if(!SWV5_TestDedupEvidenceValid(deduplication_evidence,current.deduplication)) return false;
      next=current;
      if(deduplication_evidence.disposition==SWV5_STAT_IDENTITY_DUPLICATE)
      {
         next.deduplication.duplicate_deal_count++;
         return true;
      }
      next.deal_count++;
      next.exit_deal_count++;
      next.exited_volume+=deal.volume;
      next.residual_volume=MathMax(0.0,current.residual_volume-deal.volume);
      if(next.residual_volume>validation_context.volume_tolerance)
         next.partial_close_count++;
      next.gross_profit+=deal.gross_profit;
      next.commission+=deal.commission;
      next.swap+=deal.swap;
      next.fee+=deal.fee;
      next.authoritative_net_result+=SWV5_TestDealNet(deal);
      next.deduplication.unique_deal_count++;
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
   virtual string ContractName() { return "ISWV5InstanceOwnershipContract/V3"; }
   virtual bool Acquire(const SWV5_ContractValidationContext &context,const SWV5_OwnershipClaim &claim,const SWV5_InstanceLease &observed,SWV5_OwnershipDecision &decision)
   {
      const bool valid=(observed.status==SWV5_LOCK_UNCLAIMED || SWV5_TestCanTakeover(context,claim,observed));
      decision.contract_version=context.expected_version;
      SWV5_TestSetDecision(context,valid,(valid ? "OWNERSHIP_ACQUIRED" : "OWNERSHIP_REJECTED"),decision.decision);
      decision.resulting_lease=observed;
      if(valid)
      {
         decision.resulting_lease.fence.owner=claim.claimant;
         decision.resulting_lease.fence.lease_version=observed.fence.lease_version+1;
         if(observed.status==SWV5_LOCK_EXPIRED)
            decision.resulting_lease.fence.takeover_generation=claim.takeover_evidence.proposed_takeover_generation;
      }
      return valid;
   }
   virtual bool Heartbeat(const SWV5_ContractValidationContext &context,const SWV5_InstanceLease &lease,SWV5_OwnershipDecision &decision)
   {
      const bool valid=SWV5_TestHeartbeatValid(context,lease,lease);
      decision.contract_version=context.expected_version;
      SWV5_TestSetDecision(context,valid,(valid ? "HEARTBEAT_VALID" : "HEARTBEAT_REJECTED"),decision.decision);
      decision.resulting_lease=lease;
      return valid;
   }
   virtual bool DetectConflict(const SWV5_ContractValidationContext &context,const SWV5_OwnershipClaim &claim,const SWV5_InstanceLease &observed,SWV5_OwnershipConflict &conflict)
   {
      const bool detected=observed.status==SWV5_LOCK_ACQUIRED && !SWV5_TestOwnerEqual(claim.claimant,observed.fence.owner);
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
      const bool valid=SWV5_TestFenceEqual(lease.fence,observed.fence);
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
   virtual string ContractName() { return "ISWV5UnitSystemContract/V3"; }
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
      result.validation_flags=(valid ? SWV5_UNIT_POINT_VALID|SWV5_UNIT_TICK_VALID|SWV5_UNIT_VOLUME_STEP_VALID|SWV5_UNIT_SPECIFICATION_FRESH|SWV5_UNIT_STOPS_LEVEL_VALID|SWV5_UNIT_FREEZE_LEVEL_VALID : 0);
      return valid;
   }
};

#endif
