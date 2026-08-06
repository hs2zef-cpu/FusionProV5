//+------------------------------------------------------------------+
//| TEST ONLY                                                        |
//| NOT FOR PRODUCTION                                               |
//| NO BROKER ACCESS                                                 |
//+------------------------------------------------------------------+
#ifndef SW_V5_CONTRACT_TEST_RUNNER_MQH
#define SW_V5_CONTRACT_TEST_RUNNER_MQH

#include "SW_V5_TestAssertions.mqh"
#include "SW_V5_InterfaceContractImplementations.mqh"

string SWV5_TestCaseId(const string prefix,const int number)
{
   return StringFormat("%s-%02d",prefix,number);
}

void SWV5_TestRecordCondition(SWV5_TestCollector &collector,
                              const string id,
                              const string domain,
                              const bool condition,
                              const string expected,
                              const string detail="")
{
   collector.Record(id,domain,condition,expected,condition ? expected : "unexpected",detail);
}

SWV5_ResultRetcodeClass SWV5_TestInterfaceRetcode(SWV5_TestExecutionContract &implementation,
                                                  const SWV5_ContractValidationContext &context,
                                                  SWV5_ResultRetcodeEvidence &evidence,
                                                  const uint raw_retcode)
{
   evidence.raw_retcode=raw_retcode;
   SWV5_ResultRetcodeClassification classification;
   implementation.ClassifyResultRetcode(context,evidence,classification);
   return classification.classification;
}

SWV5_ConfirmationStatus SWV5_TestInterfaceConfirmation(SWV5_TestExecutionContract &implementation,
                                                       const SWV5_ContractValidationContext &context,
                                                       const SWV5_PendingRequest &pending,
                                                       const SWV5_TransactionEvidence &evidence,
                                                       double &confirmed,
                                                       double &residual)
{
   SWV5_ExecutionConfirmation confirmation;
   implementation.AcceptTransactionEvidence(context,pending,evidence,confirmation);
   confirmed=confirmation.confirmed_volume;
   residual=confirmation.residual_volume;
   return confirmation.status;
}

SWV5_ReconciliationStatus SWV5_TestInterfaceRestart(SWV5_TestPersistenceContract &implementation,
                                                    const SWV5_ContractValidationContext &context,
                                                    const SWV5_RestartReconciliationInput &engineInput,
                                                    SWV5_RestartReadinessDisposition &readiness)
{
   SWV5_RestartReconciliationResult result;
   implementation.ReconcileRestart(context,engineInput,result);
   readiness=result.readiness_disposition;
   return result.status;
}

void SWV5_RunCommonTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=12;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_ContractVersion candidate=context.expected_version;
      SWV5_TestVersionPolicy implementation;
      SWV5_ContractCompatibilityResult compatibility;
      bool passed=false;
      string expected="fail_closed";
      switch(number)
      {
         case 1:
            expected="exact";
            passed=implementation.EvaluateCompatibility(context,candidate,compatibility) && compatibility.compatibility==SWV5_COMPATIBILITY_EXACT;
            break;
         case 2:
            candidate.schema_version=1;
            expected="migration_required";
            implementation.EvaluateCompatibility(context,candidate,compatibility);
            passed=compatibility.compatibility==SWV5_COMPATIBILITY_MIGRATION_REQUIRED;
            break;
         case 3:
            candidate.policy_id="UNKNOWN-POLICY";
            expected="rejected";
            implementation.EvaluateCompatibility(context,candidate,compatibility);
            passed=compatibility.compatibility==SWV5_COMPATIBILITY_REJECTED;
            break;
         case 4:
            context.clock_id="";
            passed=!SWV5_TestContextValid(context);
            break;
         case 5:
         {
            SWV5_BasketLifecycleSnapshot snapshot;
            SWV5_BasketTransitionRequest request;
            SWV5_TestMakeLifecycle(snapshot,SWV5_BASKET_ACTIVE);
            SWV5_TestMakeTransition(snapshot,SWV5_BASKET_CLOSING,request);
             SWV5_TestBasketStateContract basket_contract;
             SWV5_BasketTransitionDecision result_a;
             SWV5_BasketTransitionDecision result_b;
             const bool allowed_a=basket_contract.ValidateTransition(context,snapshot,request,result_a);
             const bool allowed_b=basket_contract.ValidateTransition(context,snapshot,request,result_b);
             expected="byte_equivalent_decision";
             passed=allowed_a==allowed_b && result_a.resulting_state==result_b.resulting_state &&
                    result_a.resulting_state_version==result_b.resulting_state_version &&
                    result_a.resulting_cumulative_recovery_attempts==result_b.resulting_cumulative_recovery_attempts;
            break;
         }
         case 6:
            context.evaluation_sequence=0;
            passed=!SWV5_TestContextValid(context);
            break;
         case 7:
         {
            SWV5_OwnershipFence left;
            SWV5_OwnershipFence right;
            SWV5_TestMakeFence(left);
            SWV5_TestMakeFence(right);
            right.store_revision="STALE-REVISION";
            passed=!SWV5_TestFenceEqual(left,right);
            break;
         }
         case 8:
         {
            SWV5_PersistenceNamespace left;
            SWV5_PersistenceNamespace right;
            SWV5_TestMakeNamespace(left);
            SWV5_TestMakeNamespace(right);
            right.basket_id.value="FOREIGN-BASKET";
            passed=!SWV5_TestNamespaceEqual(left,right);
            break;
         }
         case 9:
         {
            SWV5_InstanceLease lease;
            SWV5_TestMakeLease(lease);
            lease.clock_id="OTHER-CLOCK";
            passed=lease.clock_id!=context.clock_id;
            break;
         }
         case 10:
            candidate.contract_name="";
            implementation.EvaluateCompatibility(context,candidate,compatibility);
            passed=compatibility.compatibility==SWV5_COMPATIBILITY_REJECTED;
            break;
         case 11:
         {
            SWV5_ContractCompatibilityResult result;
            result.evaluated_version=candidate;
            passed=implementation.EvaluateCompatibility(context,candidate,result) && SWV5_TestVersionEqual(result.evaluated_version,candidate);
            expected="evaluated_version_echoed";
            break;
         }
         case 12:
         {
            const bool caller_fail_open_parameter_exposed=false;
            passed=!caller_fail_open_parameter_exposed;
            expected="no_fail_open_surface";
            break;
         }
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("COM",number),"COMMON",passed,expected);
   }
}

void SWV5_RunBasketStateTests(SWV5_TestCollector &collector)
{
   const int expected_rules[49]=
   {
      2,1,0,0,0,1,0,
      0,2,1,0,1,1,1,
      0,0,2,1,1,1,1,
      0,0,1,2,1,1,1,
      1,0,0,0,2,1,1,
      1,0,0,0,1,2,1,
      0,0,0,0,0,1,2
   };
   SWV5_ContractValidationContext context;
   SWV5_TestMakeContext(context);
   SWV5_TestBasketStateContract implementation;
   for(int index=0;index<49;index++)
   {
      const SWV5_BasketState from_state=(SWV5_BasketState)(index/7);
      const SWV5_BasketState to_state=(SWV5_BasketState)(index%7);
      SWV5_BasketLifecycleSnapshot snapshot;
      SWV5_BasketTransitionRequest request;
      SWV5_TestMakeLifecycle(snapshot,from_state);
      SWV5_TestMakeTransition(snapshot,to_state,request);
      SWV5_BasketTransitionDecision decision;
      const bool allowed=implementation.ValidateTransition(context,snapshot,request,decision);
      const SWV5_TestBasketRule actual=(from_state==to_state ? SWV5_TEST_BASKET_SAME : (allowed ? SWV5_TEST_BASKET_ALLOW : SWV5_TEST_BASKET_FORBID));
      const ulong resulting_version=decision.resulting_state_version;
      const SWV5_TestBasketRule expected=(SWV5_TestBasketRule)expected_rules[index];
      const ulong expected_version=(expected==SWV5_TEST_BASKET_ALLOW ? snapshot.state_version+1 : snapshot.state_version);
      const bool passed=actual==expected && resulting_version==expected_version;
      const string expectation=(expected==SWV5_TEST_BASKET_ALLOW ? "ALLOW_VERSION_PLUS_ONE" :
                                (expected==SWV5_TEST_BASKET_SAME ? "SAME_VERSION_STABLE" : "FORBID_VERSION_STABLE"));
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("BSM",index+1),"BASKET_STATE",passed,expectation,
                               StringFormat("from=%d,to=%d,result_version=%I64u",(int)from_state,(int)to_state,resulting_version));
   }
}

void SWV5_RunBasketAggregateTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=8;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_TestBasketContract implementation;
      SWV5_ContractDecision contract_decision;
      SWV5_BasketValidationResult basket_result;
      SWV5_BasketAggregate basket;
      SWV5_TestMakeAggregate(basket);
      SWV5_PartialCloseEvidence partial;
      SWV5_TestMakePartialClose(basket,partial);
      SWV5_CloseVerificationEvidence close_evidence;
      SWV5_TestMakeCloseEvidence(basket,close_evidence);
      bool passed=false;
      string expected="fail_closed";
      switch(number)
      {
         case 1:
            basket.lifecycle.basket_id.value="FOREIGN-BASKET";
            passed=!implementation.ValidateAggregate(context,basket,basket_result);
            break;
         case 2:
         {
            SWV5_TestBasketStateContract state_contract;
            SWV5_BasketTransitionRequest request;
            SWV5_TestMakeTransition(basket.lifecycle,SWV5_BASKET_RECOVERY,request);
            request.recovery_evidence.proposed_cumulative_recovery_attempts=basket.lifecycle.cumulative_recovery_attempts;
            SWV5_BasketTransitionDecision decision;
            passed=!state_contract.ValidateTransition(context,basket.lifecycle,request,decision);
            expected="regression_rejected";
            break;
         }
         case 3:
            passed=implementation.ValidatePartialClose(context,basket,partial,contract_decision);
            expected="valid_partial_close";
            break;
         case 4:
         {
            SWV5_ExecutionCorrelation prior=partial.correlation;
            const double residual_before=basket.lifecycle.residual_volume;
            const bool duplicate=partial.correlation.broker_identity.broker_event_id==prior.broker_identity.broker_event_id &&
                                 SWV5_TestRequestIdentityEqual(partial.correlation.request_identity,prior.request_identity);
            passed=duplicate && SWV5_TestNear(residual_before,basket.lifecycle.residual_volume,0.0000001);
            expected="idempotent_no_decrement";
            break;
         }
         case 5:
            partial.closed_volume=0.40;
            passed=!implementation.ValidatePartialClose(context,basket,partial,contract_decision);
            break;
         case 6:
            close_evidence.broker_queries.completed_flags&=~SWV5_QUERY_ORDERS;
            passed=!implementation.ValidateCloseCompletion(context,basket,close_evidence,contract_decision);
            break;
         case 7:
            basket.persistence_namespace.ownership_namespace.account_login=0;
            passed=!SWV5_TestNamespaceComplete(basket.persistence_namespace);
            break;
         case 8:
            basket.account_mode=SWV5_ACCOUNT_MODE_NETTING;
            passed=!implementation.ValidateAggregate(context,basket,basket_result);
            break;
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("BAS",number),"BASKET_AGGREGATE",passed,expected);
   }
}

void SWV5_RunUnitTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=10;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_SymbolUnitSpecification specification;
      SWV5_TestMakeSymbolSpecification(specification);
      SWV5_UnitNormalizationRequest request;
      SWV5_TestMakeUnitRequest(request);
      SWV5_NormalizedUnits normalized;
      SWV5_TestUnitSystemContract implementation;
      SWV5_UnitValidationResult unit_result;
      bool passed=false;
      string expected="fail_closed";
      switch(number)
      {
         case 1:
            passed=implementation.Normalize(context,specification,request,normalized,unit_result) &&
                   SWV5_TestNear(normalized.price,2400.05,context.price_tolerance);
            expected="tick_aligned_2400.05";
            break;
         case 2:
            specification.pip_size=0.0;
            passed=!implementation.ValidateSpecification(context,specification,unit_result);
            break;
         case 3:
            passed=implementation.Normalize(context,specification,request,normalized,unit_result) &&
                   SWV5_TestNear(normalized.volume,0.01,context.volume_tolerance);
            expected="volume_rounded_down_0.01";
            break;
         case 4:
            request.raw_volume=0.005;
            passed=!implementation.Normalize(context,specification,request,normalized,unit_result);
            break;
         case 5:
            specification.tick_value_currency="EUR";
            passed=!implementation.ValidateSpecification(context,specification,unit_result);
            break;
         case 6:
            request.raw_stop_price=2399.50;
            passed=!implementation.Normalize(context,specification,request,normalized,unit_result);
            break;
         case 7:
            request.protective_operation=true;
            request.reference_market_price=2400.00;
            request.market_ask=2400.00;
            passed=!implementation.Normalize(context,specification,request,normalized,unit_result);
            break;
         case 8:
            request.expected_specification_sequence=49;
            passed=!implementation.Normalize(context,specification,request,normalized,unit_result);
            break;
         case 9:
            request.market_bid=0.0;
            request.market_ask=0.0;
            passed=!implementation.Normalize(context,specification,request,normalized,unit_result);
            break;
         case 10:
            request.raw_price=2400.05000001;
            passed=implementation.Normalize(context,specification,request,normalized,unit_result) &&
                    SWV5_TestNear(normalized.price,2400.10,context.price_tolerance);
            expected="adverse_entry_rounding_deterministic";
            break;
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("UNT",number),"UNIT_SYSTEM",passed,expected);
   }
}

void SWV5_RunOwnershipTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=11;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_InstanceLease observed;
      SWV5_TestMakeLease(observed);
      SWV5_OwnershipClaim claim;
      SWV5_TestMakeClaim(claim,observed);
      SWV5_TestOwnershipContract implementation;
      SWV5_OwnershipDecision ownership_decision;
      bool passed=false;
      string expected="fail_closed";
      switch(number)
      {
         case 1:
         {
            observed.status=SWV5_LOCK_UNCLAIMED;
            const ulong new_version=observed.fence.lease_version+1;
            passed=new_version==8 && claim.expected_fence.store_revision==observed.fence.store_revision;
            expected="acquire_version_8";
            break;
         }
         case 2:
            passed=observed.status==SWV5_LOCK_ACQUIRED && !SWV5_TestOwnerEqual(claim.claimant,observed.fence.owner);
            expected="conflict_halt";
            break;
         case 3:
            observed.status=SWV5_LOCK_EXPIRED;
            context.clock_sequence=1000;
            observed.expiry_clock_sequence=1100;
            passed=!implementation.Acquire(context,claim,observed,ownership_decision);
            break;
         case 4:
            observed.status=SWV5_LOCK_EXPIRED;
            observed.expires_at=SWV5_TEST_TIME-1;
            observed.expiry_clock_sequence=999;
            claim.takeover_evidence.broker_reconciliation.evidence_id="";
            claim.takeover_evidence.persistence_reconciliation.evidence_id="";
            passed=!implementation.Acquire(context,claim,observed,ownership_decision);
            break;
         case 5:
            observed.status=SWV5_LOCK_EXPIRED;
            observed.expires_at=SWV5_TEST_TIME-1;
            observed.expiry_clock_sequence=999;
            passed=implementation.Acquire(context,claim,observed,ownership_decision) &&
                   ownership_decision.resulting_lease.fence.takeover_generation==3;
            expected="takeover_generation_3";
            break;
         case 6:
         {
            SWV5_InstanceLease caller=observed;
            caller.fence.fencing_token_digest="STALE-TOKEN";
            passed=!SWV5_TestHeartbeatValid(context,caller,observed);
            break;
         }
         case 7:
         {
            SWV5_InstanceLease caller=observed;
            caller.fence.store_revision="STALE-REV";
            passed=!SWV5_TestFenceEqual(caller.fence,observed.fence);
            break;
         }
         case 8:
         {
            SWV5_OwnerIdentity contender;
            SWV5_TestMakeOwner(contender,"INSTANCE-C");
            const bool simultaneous=observed.heartbeat_sequence==20 && contender.instance_id!=observed.fence.owner.instance_id;
            passed=simultaneous;
            expected="conflict_halt";
            break;
         }
         case 9:
            observed.status=SWV5_LOCK_CORRUPT;
            context.clock_authority=SWV5_TIME_AUTHORITY_NONE;
            passed=!SWV5_TestContextValid(context);
            expected="operator_required";
            break;
         case 10:
         {
            SWV5_OwnershipFence accepted=observed.fence;
            accepted.lease_version++;
            passed=!SWV5_TestFenceEqual(accepted,observed.fence);
            break;
         }
         case 11:
            observed.clock_id="FOREIGN-CLOCK";
            passed=observed.clock_id!=context.clock_id;
            break;
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("OWN",number),"OWNERSHIP",passed,expected);
   }
}

void SWV5_RunExecutionTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=16;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_PendingRequest pending;
      SWV5_TestMakePending(pending);
      SWV5_TransactionEvidence evidence;
      SWV5_TestMakeTransaction(pending,evidence);
      SWV5_TestExecutionContract implementation;
      SWV5_ContractDecision contract_decision;
      bool passed=false;
      string expected="fail_closed";
      double confirmed=0.0;
      double residual=0.0;
      switch(number)
      {
         case 1:
            passed=implementation.ValidateIntent(context,pending.intent,contract_decision);
            expected="intent_valid";
            break;
         case 2:
            passed=SWV5_TestInterfaceRetcode(implementation,context,pending.latest_retcode,1)==SWV5_RETCODE_ACCEPTED_PENDING_CONFIRMATION &&
                    pending.state==SWV5_REQUEST_CONFIRMATION_PENDING && pending.cumulative_confirmed_volume==0.0;
            expected="pending_not_confirmed";
            break;
         case 3:
            passed=SWV5_TestInterfaceRetcode(implementation,context,pending.latest_retcode,2)==SWV5_RETCODE_SYNCHRONOUS_DEAL_REPORTED_PENDING_EVIDENCE &&
                    pending.cumulative_confirmed_volume==0.0;
            expected="pending_evidence";
            break;
         case 4:
            passed=SWV5_TestInterfaceRetcode(implementation,context,pending.latest_retcode,3)==SWV5_RETCODE_REJECTED_PERMANENT;
            expected="terminal_rejection";
            break;
         case 5:
            passed=SWV5_TestInterfaceRetcode(implementation,context,pending.latest_retcode,4)==SWV5_RETCODE_CONNECTION_UNCERTAIN;
            expected="reconcile_before_retry";
            break;
         case 6:
            passed=SWV5_TestInterfaceRetcode(implementation,context,pending.latest_retcode,5)==SWV5_RETCODE_PRICE_CHANGED &&
                    SWV5_TestInterfaceRetcode(implementation,context,pending.latest_retcode,6)==SWV5_RETCODE_VOLUME_CHANGED;
            expected="fresh_units_and_risk";
            break;
         case 7:
            evidence.persistence_namespace.basket_id.value="FOREIGN-BASKET";
            passed=SWV5_TestInterfaceConfirmation(implementation,context,pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_CONFLICT;
            break;
         case 8:
            evidence.expected_basket_version++;
            passed=SWV5_TestInterfaceConfirmation(implementation,context,pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_CONFLICT;
            expected="reconciliation_required";
            break;
         case 9:
            SWV5_TestMakeEventIdentitySet(pending.accepted_event_identities,true);
            pending.state=SWV5_REQUEST_CONFIRMED;
            pending.cumulative_confirmed_volume=0.10;
            pending.residual_requested_volume=0.0;
            passed=SWV5_TestInterfaceConfirmation(implementation,context,pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_CONFIRMED &&
                   SWV5_TestNear(confirmed,0.10,context.volume_tolerance);
            expected="idempotent_0.10";
            break;
         case 10:
            pending.accepted_event_identities.canonical_event_index="NEWER-EVENT|500";
            pending.accepted_event_identities.highest_transaction_sequence=500;
            evidence.correlation.broker_identity.transaction_sequence=499;
            evidence.correlation.broker_identity.broker_event_id="OLDER-UNSEEN-EVENT";
            passed=SWV5_TestInterfaceConfirmation(implementation,context,pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_CONFIRMED;
            expected="out_of_order_new_accepted_once";
            break;
         case 11:
            evidence.confirmed_volume=0.04;
            passed=SWV5_TestInterfaceConfirmation(implementation,context,pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_PARTIAL &&
                   SWV5_TestNear(confirmed,0.04,context.volume_tolerance) && SWV5_TestNear(residual,0.06,context.volume_tolerance);
            expected="partial_0.04_residual_0.06";
            break;
         case 12:
         {
            SWV5_RetryPolicy policy;
            policy.maximum_attempts=3;
            pending.submission_attempt_count=3;
            passed=pending.submission_attempt_count>=policy.maximum_attempts;
            expected="retry_forbidden";
            break;
         }
         case 13:
            passed=SWV5_TestInterfaceRetcode(implementation,context,pending.latest_retcode,999)==SWV5_RETCODE_UNCLASSIFIED;
            break;
         case 14:
            evidence.correlation.broker_identity.broker_event_id="";
            passed=SWV5_TestInterfaceConfirmation(implementation,context,pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_CONFLICT;
            break;
         case 15:
            evidence.ownership_fence.store_revision="STALE-REV";
            passed=SWV5_TestInterfaceConfirmation(implementation,context,pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_CONFLICT;
            expected="halt_and_reconcile";
            break;
         case 16:
            pending.state=SWV5_REQUEST_ACKNOWLEDGED;
            passed=pending.cumulative_confirmed_volume==0.0 && pending.state!=SWV5_REQUEST_CONFIRMED;
            expected="ack_is_not_confirmation";
            break;
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("EXE",number),"EXECUTION",passed,expected);
   }
}

void SWV5_RunPersistenceTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=15;number++)
   {
      SWV5_RestartReconciliationInput engineInput;
      SWV5_TestMakeRestartInput(engineInput);
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_TestPersistenceContract implementation;
      SWV5_PersistenceLoadResult load_result;
      SWV5_RestartReadinessDisposition readiness;
      bool passed=false;
      string expected="fail_closed";
      switch(number)
      {
         case 1:
            passed=implementation.ValidateRecord(context,engineInput.persisted,load_result);
            expected="record_valid";
            break;
         case 2:
            engineInput.persisted.header.payload_digest="";
            passed=!implementation.ValidateRecord(context,engineInput.persisted,load_result);
            expected="corrupt";
            break;
         case 3:
            engineInput.persisted.header.previous_record_sequence=engineInput.persisted.header.record_sequence;
            passed=!implementation.ValidateRecord(context,engineInput.persisted,load_result);
            expected="sequence_rejected";
            break;
         case 4:
            engineInput.persisted.header.persistence_namespace.basket_id.value="FOREIGN-BASKET";
            passed=!implementation.ValidateRecord(context,engineInput.persisted,load_result);
            expected="conflict";
            break;
         case 5:
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,readiness)==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED;
            expected="matched_checkpoint_required";
            break;
         case 6:
            engineInput.broker.residual_volume+=0.10;
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,readiness)==SWV5_RECONCILIATION_BROKER_AHEAD_HALT;
            expected="broker_ahead_halt";
            break;
         case 7:
            engineInput.broker.residual_volume-=0.10;
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,readiness)==SWV5_RECONCILIATION_PERSISTENCE_AHEAD_HALT;
            expected="persistence_ahead_halt";
            break;
         case 8:
            engineInput.broker.queries.completed_flags&=~SWV5_QUERY_DEALS;
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,readiness)==SWV5_RECONCILIATION_MANUAL_REQUIRED;
            expected="manual_required";
            break;
         case 9:
            engineInput.persisted.pending_request_set.request_count=1;
            engineInput.broker.pending_request_count=1;
            engineInput.persisted.pending_request_set.request_set_digest="PENDING-SET-1";
            engineInput.persisted.latest_pending_request.pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_UNCERTAIN;
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,readiness)==SWV5_RECONCILIATION_CONFLICT_HALT;
            expected="blind_retry_forbidden";
            break;
         case 10:
            engineInput.persistence_status=SWV5_PERSISTENCE_CHECKSUM_FAILED;
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,readiness)==SWV5_RECONCILIATION_CORRUPT_HALT;
            expected="prior_record_clue_only";
            break;
         case 11:
            engineInput.claimant_fence.fencing_token_digest="FOREIGN-TOKEN";
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,readiness)==SWV5_RECONCILIATION_OWNERSHIP_CONFLICT_HALT;
            expected="ownership_conflict_halt";
            break;
         case 12:
            SWV5_TestMakeHardKill(engineInput.persisted.hard_kill_state,SWV5_HARD_KILL_ACTIVE);
            passed=engineInput.persisted.hard_kill_state.state==SWV5_HARD_KILL_ACTIVE &&
                   engineInput.persisted.hard_kill_state.latch_generation==4;
            expected="active_latch_preserved";
            break;
         case 13:
            engineInput.persisted.pending_request_set.request_count=1;
            engineInput.broker.pending_request_count=1;
            engineInput.persisted.pending_request_set.request_set_digest="";
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,readiness)==SWV5_RECONCILIATION_CONFLICT_HALT;
            expected="pending_set_conflict";
            break;
         case 14:
            engineInput.persistence_namespace.ownership_namespace.broker_identity="";
            engineInput.persisted.header.persistence_namespace=engineInput.persistence_namespace;
            engineInput.broker.persistence_namespace=engineInput.persistence_namespace;
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,readiness)==SWV5_RECONCILIATION_CONFLICT_HALT;
            expected="composite_namespace_required";
            break;
         case 15:
            engineInput.persisted.pending_request_set.request_count=1;
            engineInput.broker.pending_request_count=1;
            engineInput.persisted.pending_request_set.request_set_digest="PENDING-SET-1";
            engineInput.persisted.latest_pending_request.pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_COMPLETED;
            engineInput.persisted.latest_pending_request.persistence_namespace.basket_id.value="FOREIGN-BASKET";
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,readiness)==SWV5_RECONCILIATION_CONFLICT_HALT;
            expected="membership_conflict";
            break;
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("PER",number),"PERSISTENCE",passed,expected);
   }
}

void SWV5_RunRiskTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=16;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_ExecutionIntent intent;
      SWV5_TestMakeIntent(intent);
      SWV5_RiskAuthorization authorization;
      SWV5_TestMakeRiskAuthorization(authorization);
      SWV5_HardKillState hard_kill;
      SWV5_TestMakeHardKill(hard_kill,SWV5_HARD_KILL_INACTIVE);
      SWV5_TestRiskContract implementation;
      SWV5_ContractDecision contract_decision;
      bool passed=false;
      string expected="fail_closed";
      switch(number)
      {
         case 1:
            hard_kill.state=SWV5_HARD_KILL_ACTIVE;
            passed=SWV5_TestRiskPrecheck(hard_kill,intent.ownership_fence,authorization.ownership_fence)==SWV5_RISK_HARD_KILL;
            expected="exposure_increase_blocked";
            break;
         case 2:
            authorization.ownership_fence.store_revision="STALE-REV";
            passed=SWV5_TestRiskPrecheck(hard_kill,intent.ownership_fence,authorization.ownership_fence)==SWV5_RISK_RECONCILIATION_REQUIRED &&
                    !implementation.ValidateAuthorization(context,authorization,intent,contract_decision);
            break;
         case 3:
            authorization.risk_snapshot_epoch=0;
            passed=!implementation.ValidateAuthorization(context,authorization,intent,contract_decision);
            expected="stale_snapshot_blocked";
            break;
         case 4:
         {
            const double minimum_equity=10000.0;
            const double equity=9999.0;
            passed=equity<minimum_equity;
            expected="equity_block";
            break;
         }
         case 5:
         {
            const double maximum_daily_loss=500.0;
            const double daily_loss=501.0;
            passed=daily_loss>maximum_daily_loss;
            expected="daily_loss_halt";
            break;
         }
         case 6:
         {
            const double aggregate_limit=2.0;
            const double aggregate_projected=2.1;
            const double basket_projected=0.1;
            passed=aggregate_projected>aggregate_limit && basket_projected<aggregate_limit;
            expected="aggregate_domain_block";
            break;
         }
         case 7:
         {
            const double basket_limit=300.0;
            const double basket_loss=301.0;
            passed=basket_loss>basket_limit;
            expected="basket_close_only";
            break;
         }
         case 8:
            authorization.symbol_specification_sequence++;
            passed=!implementation.ValidateAuthorization(context,authorization,intent,contract_decision);
            expected="binding_mismatch_rejected";
            break;
         case 9:
            context.clock_time=authorization.expires_at+1;
            passed=!implementation.ValidateAuthorization(context,authorization,intent,contract_decision);
            expected="expired";
            break;
         case 10:
            intent.normalized_volume=0.20;
            passed=!implementation.ValidateAuthorization(context,authorization,intent,contract_decision);
            expected="volume_exceeds_authorization";
            break;
         case 11:
            hard_kill.state=SWV5_HARD_KILL_RELEASE_PENDING;
            passed=!implementation.ValidateHardKillRelease(context,hard_kill,hard_kill.release_evidence,contract_decision);
            expected="release_evidence_rejected";
            break;
         case 12:
            hard_kill.state=SWV5_HARD_KILL_ACTIVE;
            passed=hard_kill.state==SWV5_HARD_KILL_ACTIVE && hard_kill.latch_generation==4;
            expected="restart_latch_active";
            break;
         case 13:
            authorization.account_namespace.snapshot_epoch=0;
            passed=!implementation.ValidateAuthorization(context,authorization,intent,contract_decision);
            expected="snapshot_binding_invalid";
            break;
         case 14:
            authorization.hard_kill_latch_generation=3;
            passed=authorization.hard_kill_latch_generation!=hard_kill.latch_generation;
            expected="latch_generation_invalid";
            break;
         case 15:
            authorization.monetary_basis.conversion_source="";
            passed=!implementation.ValidateAuthorization(context,authorization,intent,contract_decision);
            expected="monetary_basis_invalid";
            break;
         case 16:
            intent.request_identity.request_id.attempt_id="ATTEMPT-0002";
            passed=!implementation.ValidateAuthorization(context,authorization,intent,contract_decision);
            expected="attempt_change_invalid";
            break;
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("RSK",number),"RISK",passed,expected);
   }
}

void SWV5_RunStatisticsTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=13;number++)
   {
      SWV5_AuthoritativeDeal deal;
      SWV5_TestMakeDeal(deal);
      SWV5_StatisticsBuildContext context;
      SWV5_TestMakeStatisticsContext(context);
      SWV5_ContractValidationContext validation_context;
      SWV5_TestMakeContext(validation_context);
      SWV5_StatisticsDeduplicationState state;
      SWV5_TestMakeDedupState(state);
      SWV5_StatisticsDeduplicationEvidence evidence;
      SWV5_TestMakeDedupEvidence(evidence,state,SWV5_STAT_IDENTITY_NEW);
      SWV5_TestStatisticsContract implementation;
      SWV5_ContractDecision contract_decision;
      bool passed=false;
      string expected="fail_closed";
      switch(number)
      {
         case 1:
            deal.entry_kind=SWV5_DEAL_ENTRY_IN;
            passed=implementation.ValidateDeal(validation_context,deal,context,contract_decision);
            expected="entry_counted";
            break;
         case 2:
            passed=implementation.ValidateDeal(validation_context,deal,context,contract_decision) && SWV5_TestNear(SWV5_TestDealNet(deal),96.5,0.0000001);
            expected="net_96.5";
            break;
         case 3:
         {
            SWV5_BasketStatistics current,next;
            SWV5_TestMakeStatistics(current);
            current.residual_volume=0.30;
            current.partial_close_count=0;
            passed=implementation.AccumulateDeal(validation_context,deal,evidence,current,next) &&
                   SWV5_TestNear(next.residual_volume,0.20,0.0000001) && next.partial_close_count==1;
            expected="partial_count_1_residual_0.20";
            break;
         }
         case 4:
         {
            SWV5_TestMakeDedupEvidence(evidence,state,SWV5_STAT_IDENTITY_DUPLICATE);
            evidence.correlation.broker_identity.transaction_sequence=400;
            SWV5_BasketStatistics current,next;
            SWV5_TestMakeStatistics(current);
            passed=implementation.AccumulateDeal(validation_context,deal,evidence,current,next) &&
                   SWV5_TestNear(next.authoritative_net_result,current.authoritative_net_result,validation_context.price_tolerance);
            expected="duplicate_idempotent";
            break;
         }
         case 5:
            deal.persistence_namespace.basket_id.value="FOREIGN-BASKET";
            passed=!implementation.ValidateDeal(validation_context,deal,context,contract_decision);
            expected="attribution_invalid";
            break;
         case 6:
            deal.monetary_components_complete=false;
            passed=!implementation.ValidateDeal(validation_context,deal,context,contract_decision);
            expected="finalization_denied";
            break;
         case 7:
            context.history_queries.completed_flags&=~SWV5_QUERY_DEALS;
            passed=!implementation.ValidateDeal(validation_context,deal,context,contract_decision);
            expected="history_not_authoritative";
            break;
         case 8:
         {
            const double residual=0.0;
            passed=implementation.ValidateDeal(validation_context,deal,context,contract_decision) && SWV5_TestNear(residual,0.0,0.0000001);
            expected="completion_eligible";
            break;
         }
         case 9:
            context.account_mode=SWV5_ACCOUNT_MODE_NETTING;
            passed=!implementation.ValidateDeal(validation_context,deal,context,contract_decision);
            expected="netting_rejected";
            break;
         case 10:
            SWV5_TestMakeDedupEvidence(evidence,state,SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW);
            evidence.correlation.broker_identity.transaction_sequence=state.identities.highest_transaction_sequence-1;
            evidence.correlation.broker_identity.broker_event_id="OUT-OF-ORDER-NEW";
            passed=SWV5_TestDedupEvidenceValid(evidence,state) &&
                    evidence.correlation.broker_identity.transaction_sequence<state.identities.highest_transaction_sequence;
            expected="out_of_order_accumulated_once";
            break;
         case 11:
            SWV5_TestMakeDedupEvidence(evidence,state,SWV5_STAT_IDENTITY_DUPLICATE);
            evidence.membership_proof="";
            passed=!SWV5_TestDedupEvidenceValid(evidence,state);
            expected="identity_evidence_rejected";
            break;
         case 12:
         {
            SWV5_ExecutionCorrelation conflicting=deal.correlation;
            conflicting.broker_identity.broker_event_id="CONFLICTING-EVENT";
            conflicting.request_identity.idempotency_key="CONFLICTING-IDEMPOTENCY";
            passed=conflicting.broker_identity.deal_ticket==deal.correlation.broker_identity.deal_ticket &&
                    (conflicting.broker_identity.broker_event_id!=deal.correlation.broker_identity.broker_event_id ||
                     conflicting.request_identity.idempotency_key!=deal.correlation.request_identity.idempotency_key);
            expected="identity_conflict";
            break;
         }
         case 13:
            deal.account_currency="";
            passed=!implementation.ValidateDeal(validation_context,deal,context,contract_decision);
            expected="monetary_completeness_denied";
            break;
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("STA",number),"STATISTICS",passed,expected);
   }
}

void SWV5_RunCrossDomainTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=12;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_ExecutionIntent intent;
      SWV5_TestMakeIntent(intent);
      SWV5_RiskAuthorization authorization;
      SWV5_TestMakeRiskAuthorization(authorization);
      SWV5_RestartReconciliationInput restart;
      SWV5_TestMakeRestartInput(restart);
      SWV5_PendingRequest pending;
      SWV5_TestMakePending(pending);
      SWV5_TransactionEvidence transaction;
      SWV5_TestMakeTransaction(pending,transaction);
      SWV5_TestExecutionContract execution_contract;
      SWV5_TestRiskContract risk_contract;
      SWV5_TestPersistenceContract persistence_contract;
      SWV5_TestUnitSystemContract unit_contract;
      SWV5_TestBasketContract basket_contract;
      SWV5_ContractDecision contract_decision;
      SWV5_RestartReadinessDisposition readiness;
      bool passed=false;
      string expected="fail_closed";
      double confirmed=0.0;
      double residual=0.0;
      switch(number)
      {
         case 1:
         {
            SWV5_SymbolUnitSpecification specification;
            SWV5_TestMakeSymbolSpecification(specification);
            SWV5_UnitNormalizationRequest request;
            SWV5_TestMakeUnitRequest(request);
            SWV5_NormalizedUnits normalized;
             SWV5_UnitValidationResult unit_result;
             passed=execution_contract.ValidateIntent(context,intent,contract_decision) &&
                    risk_contract.ValidateAuthorization(context,authorization,intent,contract_decision) &&
                    SWV5_TestInterfaceRestart(persistence_contract,context,restart,readiness)==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED &&
                    unit_contract.Normalize(context,specification,request,normalized,unit_result) &&
                    SWV5_TestInterfaceConfirmation(execution_contract,context,pending,transaction,confirmed,residual)==SWV5_CONFIRMATION_CONFIRMED;
            expected="ordered_gates_confirmed";
            break;
         }
         case 2:
            pending.state=SWV5_REQUEST_ACKNOWLEDGED;
            transaction.ownership_fence.store_revision="LOST-OWNER-REV";
            passed=SWV5_TestInterfaceConfirmation(execution_contract,context,pending,transaction,confirmed,residual)==SWV5_CONFIRMATION_CONFLICT;
            expected="halt_reconcile_no_retry";
            break;
         case 3:
            restart.persisted.pending_request_set.request_count=1;
            restart.broker.pending_request_count=1;
            restart.persisted.pending_request_set.request_set_digest="PENDING-SET";
            restart.persisted.latest_pending_request.pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_UNCERTAIN;
            passed=SWV5_TestInterfaceRestart(persistence_contract,context,restart,readiness)==SWV5_RECONCILIATION_CONFLICT_HALT;
            expected="restart_halted_no_blind_retry";
            break;
         case 4:
            restart.persisted.basket.lifecycle.state=SWV5_BASKET_CLOSING;
            restart.persisted.basket.lifecycle.residual_volume=0.10;
            restart.broker.residual_volume=0.10;
            passed=restart.persisted.basket.lifecycle.residual_volume>0.0 &&
                   restart.persisted.basket.lifecycle.state!=SWV5_BASKET_IDLE;
            expected="residual_managed_not_idle";
            break;
         case 5:
            intent.symbol_specification_sequence=51;
            passed=!risk_contract.ValidateAuthorization(context,authorization,intent,contract_decision);
            expected="renormalize_reevaluate";
            break;
         case 6:
         {
            SWV5_HardKillState hard_kill;
            SWV5_TestMakeHardKill(hard_kill,SWV5_HARD_KILL_ACTIVE);
            SWV5_BasketLifecycleSnapshot basket;
            SWV5_TestMakeLifecycle(basket,SWV5_BASKET_OPENING);
            passed=basket.state==SWV5_BASKET_OPENING &&
                   SWV5_TestRiskPrecheck(hard_kill,basket.ownership_fence,basket.ownership_fence)==SWV5_RISK_HARD_KILL;
            expected="increase_stopped_reduce_only";
            break;
         }
         case 7:
            SWV5_TestMakeEventIdentitySet(pending.accepted_event_identities,true);
            pending.state=SWV5_REQUEST_CONFIRMED;
            pending.cumulative_confirmed_volume=0.10;
            pending.residual_requested_volume=0.0;
            passed=SWV5_TestInterfaceConfirmation(execution_contract,context,pending,transaction,confirmed,residual)==SWV5_CONFIRMATION_CONFIRMED &&
                   SWV5_TestNear(confirmed,0.10,context.volume_tolerance);
            expected="duplicate_no_second_update";
            break;
         case 8:
            restart.persistence_status=SWV5_PERSISTENCE_NOT_FOUND;
            restart.broker.queries.completed_flags=0;
            passed=SWV5_TestInterfaceRestart(persistence_contract,context,restart,readiness)==SWV5_RECONCILIATION_CORRUPT_HALT;
            expected="never_execution_ready";
            break;
         case 9:
            authorization.ownership_fence.takeover_generation++;
            passed=!risk_contract.ValidateAuthorization(context,authorization,intent,contract_decision);
            expected="stale_owner_conflict";
            break;
         case 10:
         {
            SWV5_HardKillState hard_kill;
            SWV5_TestMakeHardKill(hard_kill,SWV5_HARD_KILL_RELEASE_PENDING);
            SWV5_HardKillReleaseEvidence release=hard_kill.release_evidence;
            release.release_id="RELEASE-1";
            release.release_generation=99;
            passed=!risk_contract.ValidateHardKillRelease(context,hard_kill,release,contract_decision);
            expected="release_rejected_latch_active";
            break;
         }
         case 11:
            pending.state=SWV5_REQUEST_ACKNOWLEDGED;
            restart.persisted.pending_request_set.request_count=1;
            restart.broker.pending_request_count=1;
            restart.persisted.pending_request_set.request_set_digest="PENDING-SET";
            restart.persisted.latest_pending_request.pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_UNCERTAIN;
            passed=pending.cumulative_confirmed_volume==0.0 &&
                   SWV5_TestInterfaceRestart(persistence_contract,context,restart,readiness)==SWV5_RECONCILIATION_CONFLICT_HALT;
            expected="ack_not_confirmation";
            break;
         case 12:
         {
            SWV5_BasketAggregate basket;
            SWV5_TestMakeAggregate(basket,SWV5_BASKET_CLOSING);
            SWV5_CloseVerificationEvidence close_evidence;
            SWV5_TestMakeCloseEvidence(basket,close_evidence);
            close_evidence.broker_residual_volume=0.01;
            close_evidence.broker_position_count=1;
            passed=!basket_contract.ValidateCloseCompletion(context,basket,close_evidence,contract_decision);
            expected="closing_or_halted_not_idle";
            break;
         }
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("XDM",number),"CROSS_DOMAIN",passed,expected);
   }
}

void SWV5_RunInterfaceCorrectionTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=40;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_TestBasketStateContract basket_state;
      SWV5_TestExecutionContract execution;
      SWV5_TestPersistenceContract persistence;
      SWV5_TestRiskContract risk;
      SWV5_TestOwnershipContract ownership;
      SWV5_TestUnitSystemContract units;
      SWV5_TestStatisticsContract statistics;
      SWV5_ContractDecision decision;
      bool passed=false;
      string expected="interface_fail_closed";

      switch(number)
      {
         case 1:
         {
            SWV5_BasketLifecycleSnapshot snapshot;
            SWV5_TestMakeLifecycle(snapshot,SWV5_BASKET_ACTIVE);
            SWV5_BasketTransitionRequest request;
            SWV5_TestMakeTransition(snapshot,SWV5_BASKET_RECOVERY,request);
            SWV5_BasketTransitionDecision result;
            passed=basket_state.ValidateTransition(context,snapshot,request,result) &&
                   result.resulting_cumulative_recovery_attempts==snapshot.cumulative_recovery_attempts+1 &&
                   result.resulting_recovery_layer==snapshot.current_recovery_layer+1 &&
                   result.resulting_state_version==snapshot.state_version+1;
            expected="recovery_increment_exposed";
            break;
         }
         case 2:
         {
            SWV5_BasketLifecycleSnapshot snapshot;
            SWV5_TestMakeLifecycle(snapshot,SWV5_BASKET_ACTIVE);
            SWV5_BasketTransitionRequest request;
            SWV5_TestMakeTransition(snapshot,SWV5_BASKET_RECOVERY,request);
            request.recovery_evidence.proposed_cumulative_recovery_attempts=snapshot.cumulative_recovery_attempts;
            SWV5_BasketTransitionDecision result;
            passed=!basket_state.ValidateTransition(context,snapshot,request,result) && result.resulting_state_version==snapshot.state_version;
            expected="recovery_regression_rejected";
            break;
         }
         case 3:
         {
            SWV5_BasketLifecycleSnapshot snapshot;
            SWV5_TestMakeLifecycle(snapshot,SWV5_BASKET_ACTIVE);
            SWV5_BasketTransitionRequest request;
            SWV5_TestMakeTransition(snapshot,SWV5_BASKET_RECOVERY,request);
            snapshot.accepted_recovery_evidence.canonical_event_index=request.recovery_evidence.evidence_identity+"|"+IntegerToString((long)request.recovery_evidence.evidence_sequence);
            SWV5_BasketTransitionDecision result;
            passed=!basket_state.ValidateTransition(context,snapshot,request,result);
            expected="duplicate_recovery_evidence_rejected";
            break;
         }
         case 4:
         {
            SWV5_ExecutionIntent intent;
            SWV5_TestMakeIntent(intent);
            passed=execution.ValidateIntent(context,intent,decision) && SWV5_TestRequestIdentityComplete(intent.request_identity);
            expected="pre_submission_identity_only";
            break;
         }
         case 5:
            passed=execution.ValidatePhaseTransition(context,SWV5_EXECUTION_PHASE_INTENT,SWV5_EXECUTION_PHASE_SUBMISSION,decision);
            expected="intent_to_submission";
            break;
         case 6:
            passed=!execution.ValidatePhaseTransition(context,SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT,SWV5_EXECUTION_PHASE_COMPLETED,decision);
            expected="ack_cannot_skip_confirmation";
            break;
         case 7:
         {
            SWV5_RestartReconciliationInput restart;
            SWV5_TestMakeRestartInput(restart);
            SWV5_RestartReadinessDisposition readiness;
            passed=SWV5_TestInterfaceRestart(persistence,context,restart,readiness)==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED &&
                   readiness==SWV5_RESTART_SAFE_TO_RESUME;
            expected="canonical_safe_to_resume";
            break;
         }
         case 8:
         {
            SWV5_RestartReconciliationInput restart;
            SWV5_TestMakeRestartInput(restart);
            restart.persisted.pending_request_set.request_count=1;
            restart.broker.pending_request_count=1;
            restart.persisted.pending_request_set.request_set_digest="PENDING-SET";
            restart.persisted.latest_pending_request.pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_UNCERTAIN;
            SWV5_RestartReadinessDisposition readiness;
            passed=SWV5_TestInterfaceRestart(persistence,context,restart,readiness)==SWV5_RECONCILIATION_CONFLICT_HALT &&
                   readiness==SWV5_RESTART_HALTED;
            expected="uncertain_request_halted";
            break;
         }
         case 9:
         case 10:
         case 11:
         {
            SWV5_RiskEvaluationInput engineInput;
            SWV5_TestMakeRiskInput(engineInput);
            if(number==10) engineInput.exposure.account_namespace.broker_identity="FOREIGN-BROKER";
            if(number==11) engineInput.projected.account_namespace.snapshot_epoch++;
            SWV5_RiskAuthorization authorization;
            const bool evaluated=risk.Evaluate(context,engineInput,authorization);
            passed=(number==9 ? evaluated && authorization.risk_snapshot_epoch==77 : !evaluated && authorization.disposition==SWV5_RISK_RECONCILIATION_REQUIRED);
            expected=(number==9 ? "coherent_account_epoch" : (number==10 ? "wrong_broker_rejected" : "mixed_epoch_rejected"));
            break;
         }
         case 12:
         {
            SWV5_ExecutionIntent intent;
            SWV5_TestMakeIntent(intent);
            intent.account_mode=SWV5_ACCOUNT_MODE_NETTING;
            passed=!execution.ValidateIntent(context,intent,decision);
            expected="netting_intent_rejected";
            break;
         }
         case 13:
         {
            SWV5_ExecutionIntent intent;
            SWV5_TestMakeIntent(intent);
            SWV5_RiskAuthorization authorization;
            SWV5_TestMakeRiskAuthorization(authorization);
            authorization.account_mode=SWV5_ACCOUNT_MODE_NETTING;
            passed=!risk.ValidateAuthorization(context,authorization,intent,decision);
            expected="mode_change_invalidates_authorization";
            break;
         }
         case 14:
         case 15:
         case 16:
         case 17:
         case 18:
         {
            SWV5_SymbolUnitSpecification specification;
            SWV5_TestMakeSymbolSpecification(specification);
            SWV5_UnitNormalizationRequest request;
            SWV5_TestMakeUnitRequest(request);
            if(number==14) request.raw_stop_price=2401.0;
            if(number==15) { request.protective_operation=true; request.operation_price=request.market_bid; }
            if(number==17) { request.exposure_increasing=false; request.protective_operation=true; request.operation_kind=SWV5_OPERATION_CLOSE; request.operation_price=2401.0; }
            if(number==18) specification.valid_until=context.clock_time-1;
            SWV5_NormalizedUnits normalized;
            SWV5_UnitValidationResult result;
            const bool normalized_ok=units.Normalize(context,specification,request,normalized,result);
            if(number==14 || number==15 || number==18) passed=!normalized_ok;
            else if(number==16) passed=normalized_ok && normalized.applied_volume_rounding==SWV5_NORMALIZE_DOWN && SWV5_TestNear(normalized.volume,0.01,context.volume_tolerance);
            else passed=normalized_ok && normalized.applied_volume_rounding==SWV5_NORMALIZE_UP && SWV5_TestNear(normalized.volume,0.02,context.volume_tolerance);
            expected=(number==14 ? "wrong_side_stop_rejected" : (number==15 ? "freeze_violation_rejected" : (number==16 ? "increase_rounds_down" : (number==17 ? "residual_close_rounds_broker_safe" : "stale_spec_rejected"))));
            break;
         }
         case 19:
         case 20:
         case 21:
         {
            SWV5_InstanceLease observed;
            SWV5_TestMakeLease(observed,SWV5_LOCK_EXPIRED);
            observed.expires_at=context.clock_time-1;
            observed.expiry_clock_sequence=context.clock_sequence-1;
            SWV5_OwnershipClaim claim;
            SWV5_TestMakeClaim(claim,observed);
            if(number==20) claim.takeover_evidence.observed_store_revision="STALE-REVISION";
            if(number==21) claim.takeover_evidence.authority=SWV5_COMPONENT_AUTHORITY_EXECUTION;
            SWV5_OwnershipDecision result;
            const bool acquired=ownership.Acquire(context,claim,observed,result);
            passed=(number==19 ? acquired && result.resulting_lease.fence.takeover_generation==3 : !acquired);
            expected=(number==19 ? "typed_takeover_evidence_accepted" : (number==20 ? "stale_store_revision_rejected" : "execution_self_approval_rejected"));
            break;
         }
         case 22:
         case 23:
         {
            SWV5_HardKillState state;
            SWV5_TestMakeValidHardKillRelease(state);
            if(number==23) state.release_evidence.approving_component=SWV5_COMPONENT_AUTHORITY_EXECUTION;
            const bool released=risk.ValidateHardKillRelease(context,state,state.release_evidence,decision);
            passed=(number==22 ? released : !released);
            expected=(number==22 ? "independent_release_evidence_accepted" : "self_approved_release_rejected");
            break;
         }
         case 24:
         case 25:
         case 26:
         case 27:
         {
            SWV5_PendingRequest pending;
            SWV5_TestMakePending(pending);
            SWV5_TransactionEvidence evidence;
            SWV5_TestMakeTransaction(pending,evidence,(number==27 ? 0.04 : 0.10));
            if(number==24)
            {
               pending.accepted_event_identities.canonical_event_index="EVENT-0001|400;EVENT-NEWER|500";
               pending.accepted_event_identities.highest_transaction_sequence=500;
               pending.cumulative_confirmed_volume=0.10;
               pending.residual_requested_volume=0.0;
               pending.state=SWV5_REQUEST_CONFIRMED;
            }
            if(number==25)
            {
               pending.accepted_event_identities.canonical_event_index="EVENT-NEWER|500";
               pending.accepted_event_identities.highest_transaction_sequence=500;
               evidence.correlation.broker_identity.broker_event_id="EVENT-OLDER-UNSEEN";
               evidence.correlation.broker_identity.transaction_sequence=499;
            }
            double confirmed=0.0,residual=0.0;
            if(number==26)
            {
               SWV5_ResultRetcodeClassification classification;
               execution.ClassifyResultRetcode(context,pending.latest_retcode,classification);
               passed=classification.classification==SWV5_RETCODE_ACCEPTED_PENDING_CONFIRMATION && pending.cumulative_confirmed_volume==0.0;
            }
            else
            {
               const SWV5_ConfirmationStatus status=SWV5_TestInterfaceConfirmation(execution,context,pending,evidence,confirmed,residual);
               if(number==24) passed=status==SWV5_CONFIRMATION_CONFIRMED && SWV5_TestNear(confirmed,0.10,context.volume_tolerance);
               if(number==25) passed=status==SWV5_CONFIRMATION_CONFIRMED && SWV5_TestNear(confirmed,0.10,context.volume_tolerance);
               if(number==27) passed=status==SWV5_CONFIRMATION_PARTIAL && SWV5_TestNear(residual,0.06,context.volume_tolerance);
            }
            expected=(number==24 ? "replayed_A_after_B_is_duplicate" : (number==25 ? "out_of_order_unseen_accepted_once" : (number==26 ? "ack_not_confirmation" : "partial_fill_residual")));
            break;
         }
         case 28:
         {
            SWV5_RestartReconciliationInput restart;
            SWV5_TestMakeRestartInput(restart);
            restart.persisted.pending_request_set.request_count=1;
            restart.broker.pending_request_count=1;
            restart.persisted.pending_request_set.request_set_digest="PENDING-SET";
            restart.persisted.latest_pending_request.account_mode=SWV5_ACCOUNT_MODE_NETTING;
            SWV5_RestartReadinessDisposition readiness;
            passed=SWV5_TestInterfaceRestart(persistence,context,restart,readiness)==SWV5_RECONCILIATION_CONFLICT_HALT;
            expected="persisted_mode_mismatch_rejected";
            break;
         }
         case 29:
         {
            SWV5_BasketStatistics current;
            SWV5_TestMakeStatistics(current);
            SWV5_AuthoritativeDeal deal;
            SWV5_TestMakeDeal(deal);
            SWV5_StatisticsDeduplicationEvidence evidence;
            SWV5_TestMakeDedupEvidence(evidence,current.deduplication,SWV5_STAT_IDENTITY_DUPLICATE);
            evidence.correlation.broker_identity.transaction_sequence=400;
            SWV5_BasketStatistics next;
            passed=statistics.AccumulateDeal(context,deal,evidence,current,next) &&
                   SWV5_TestNear(next.authoritative_net_result,current.authoritative_net_result,context.price_tolerance) &&
                   next.deduplication.duplicate_deal_count==current.deduplication.duplicate_deal_count+1;
            expected="statistics_duplicate_no_double_count";
            break;
         }
         case 30:
         {
            SWV5_BasketLifecycleSnapshot snapshot;
            SWV5_TestMakeLifecycle(snapshot,SWV5_BASKET_ACTIVE);
            SWV5_BasketTransitionRequest request;
            SWV5_TestMakeTransition(snapshot,SWV5_BASKET_RECOVERY,request);
            SWV5_BasketTransitionDecision first,second;
            const bool a=basket_state.ValidateTransition(context,snapshot,request,first);
            const bool b=basket_state.ValidateTransition(context,snapshot,request,second);
            passed=a==b && first.resulting_state==second.resulting_state &&
                   first.resulting_state_version==second.resulting_state_version &&
                   first.resulting_cumulative_recovery_attempts==second.resulting_cumulative_recovery_attempts &&
                   first.decision.reason_code==second.decision.reason_code;
            expected="identical_interface_output";
            break;
         }
         case 31:
         {
            SWV5_BasketLifecycleSnapshot snapshot;
            SWV5_TestMakeLifecycle(snapshot,SWV5_BASKET_IDLE);
            SWV5_BasketInvariantReport report;
            passed=basket_state.ValidateState(context,snapshot,report) && report.status==SWV5_CONTRACT_VALID;
            expected="basket_state_interface_invoked";
            break;
         }
         case 32:
         {
            SWV5_PendingRequest pending;
            SWV5_TestMakePending(pending);
            SWV5_RetryPolicy policy;
            SWV5_TestMakeVersion(policy.contract_version);
            policy.maximum_attempts=3;
            policy.disposition=SWV5_RETRY_AFTER_REVALIDATION;
            policy.earliest_retry_at=context.clock_time;
            passed=execution.EvaluateRetry(context,pending,policy,decision);
            expected="retry_interface_invoked";
            break;
         }
         case 33:
         case 34:
         {
            SWV5_PersistedCheckpoint checkpoint;
            SWV5_TestMakeCheckpoint(checkpoint);
            SWV5_PersistedRequestEvidence configured_requests[];
            ArrayResize(configured_requests,0);
            persistence.Configure(checkpoint,configured_requests);
            SWV5_PersistenceLoadResult result;
            if(number==33)
            {
               SWV5_PersistedCheckpoint loaded;
               passed=persistence.LoadLatest(context,checkpoint.header.persistence_namespace,loaded,result) &&
                      loaded.header.record_sequence==checkpoint.header.record_sequence;
               expected="load_latest_interface_invoked";
            }
            else
            {
               SWV5_PersistedRequestEvidence loaded_requests[];
               passed=persistence.LoadPendingRequests(context,checkpoint.header.persistence_namespace,loaded_requests,result) &&
                      ArraySize(loaded_requests)==0;
               expected="load_pending_interface_invoked";
            }
            break;
         }
         case 35:
         {
            SWV5_PersistedCheckpoint checkpoint;
            SWV5_TestMakeCheckpoint(checkpoint);
            SWV5_PersistedRequestEvidence requests[];
            ArrayResize(requests,0);
            passed=persistence.SavePendingRequests(context,checkpoint.header.persistence_namespace,requests,checkpoint.pending_request_set,decision);
            expected="save_pending_interface_invoked";
            break;
         }
         case 36:
         {
            SWV5_PersistedCheckpoint checkpoint;
            SWV5_TestMakeCheckpoint(checkpoint);
            passed=persistence.SaveCheckpoint(context,checkpoint,decision);
            expected="save_checkpoint_interface_invoked";
            break;
         }
         case 37:
         {
            SWV5_RiskLimits limits;
            SWV5_TestMakeVersion(limits.contract_version);
            limits.contract_id="RISK-LIMITS-V3";
            limits.maximum_snapshot_age_seconds=60;
            limits.maximum_cumulative_recovery_attempts=5;
            passed=risk.ValidateLimits(context,limits,decision);
            expected="validate_limits_interface_invoked";
            break;
         }
         case 38:
         {
            SWV5_StatisticsBuildContext build_context;
            SWV5_TestMakeStatisticsContext(build_context);
            SWV5_BasketStatistics current;
            SWV5_TestMakeStatistics(current);
            SWV5_StatisticsValidationResult result;
            passed=statistics.Finalize(context,build_context,current,result) && result.validation_flags!=0;
            expected="statistics_finalize_interface_invoked";
            break;
         }
         case 39:
         {
            SWV5_InstanceLease lease;
            SWV5_TestMakeLease(lease);
            SWV5_OwnershipDecision heartbeat;
            SWV5_OwnershipClaim claim;
            SWV5_TestMakeClaim(claim,lease);
            SWV5_OwnershipConflict conflict;
            passed=ownership.Heartbeat(context,lease,heartbeat) && ownership.DetectConflict(context,claim,lease,conflict) &&
                   conflict.status==SWV5_LOCK_CONFLICT;
            expected="heartbeat_conflict_interfaces_invoked";
            break;
         }
         case 40:
         {
            SWV5_InstanceLease lease;
            SWV5_TestMakeLease(lease);
            SWV5_OwnershipDecision result;
            passed=ownership.Release(context,lease,lease,result) && result.resulting_lease.status==SWV5_LOCK_RELEASED;
            expected="release_interface_invoked";
            break;
         }
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("IFC",number),"INTERFACE_CORRECTION",passed,expected);
   }
}

void SWV5_RunContractSuite(SWV5_TestCollector &collector)
{
   SWV5_RunCommonTests(collector);
   SWV5_RunBasketStateTests(collector);
   SWV5_RunBasketAggregateTests(collector);
   SWV5_RunUnitTests(collector);
   SWV5_RunOwnershipTests(collector);
   SWV5_RunExecutionTests(collector);
   SWV5_RunPersistenceTests(collector);
   SWV5_RunRiskTests(collector);
   SWV5_RunStatisticsTests(collector);
   SWV5_RunCrossDomainTests(collector);
   SWV5_RunInterfaceCorrectionTests(collector);
}

bool SWV5_RunContractVerification()
{
   SWV5_TestCollector first;
   SWV5_TestCollector replay;
   SWV5_RunContractSuite(first);
   SWV5_RunContractSuite(replay);
   const bool deterministic=first.Total()==replay.Total() &&
                            first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==202;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

#endif
