//+------------------------------------------------------------------+
//| TEST ONLY                                                        |
//| NOT FOR PRODUCTION                                               |
//| NO BROKER ACCESS                                                 |
//+------------------------------------------------------------------+
#ifndef SW_V5_CONTRACT_TEST_RUNNER_MQH
#define SW_V5_CONTRACT_TEST_RUNNER_MQH

string g_swv5_test_id_filter="";

bool SWV5_TestIdSelected(const string id)
{
   return g_swv5_test_id_filter=="" || StringFind(","+g_swv5_test_id_filter+",",","+id+",")>=0;
}

#include "SW_V5_TestAssertions.mqh"
#include "SW_V5_InterfaceContractImplementations.mqh"
#include "SW_V5_CanonicalDecoder.mqh"

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

bool SWV5_TestExecutionRejectsWithoutMutation(SWV5_TestExecutionContract &implementation,
                                               const SWV5_ContractValidationContext &context,
                                               const SWV5_PendingRequest &pending,
                                               const SWV5_TransactionEvidence &evidence)
{
   SWV5_ExecutionConfirmation confirmation;
   const bool accepted=implementation.AcceptTransactionEvidence(context,pending,evidence,confirmation);
   return !accepted && confirmation.status==SWV5_CONFIRMATION_CONFLICT &&
          confirmation.disposition==SWV5_DISPOSITION_RECONCILE &&
          confirmation.evidence_disposition==SWV5_TRANSACTION_EVIDENCE_INVALID &&
          !confirmation.event_identity_added && !confirmation.duplicate_event &&
          SWV5_TestPendingRequestEqual(confirmation.resulting_pending_request,pending) &&
          SWV5_TestNear(confirmation.confirmed_volume,pending.cumulative_confirmed_volume,context.volume_tolerance) &&
          SWV5_TestNear(confirmation.residual_volume,pending.residual_requested_volume,context.volume_tolerance) &&
          SWV5_TestEventIdentitySetEqual(confirmation.resulting_pending_request.accepted_event_identities,
                                         pending.accepted_event_identities);
}

SWV5_ReconciliationStatus SWV5_TestInterfaceRestart(SWV5_TestPersistenceContract &implementation,
                                                     const SWV5_ContractValidationContext &context,
                                                     const SWV5_RestartReconciliationInput &engineInput,
                                                     const SWV5_PersistedRequestEvidence &pending_requests[],
                                                     SWV5_RestartReadinessDisposition &readiness)
{
   SWV5_RestartReconciliationResult result;
   implementation.ReconcileRestart(context,engineInput,pending_requests,result);
   readiness=result.readiness_disposition;
   return result.status;
}

SWV5_ReconciliationStatus SWV5_TestInterfaceRestart(SWV5_TestPersistenceContract &implementation,
                                                     const SWV5_ContractValidationContext &context,
                                                     const SWV5_RestartReconciliationInput &engineInput,
                                                     SWV5_RestartReadinessDisposition &readiness)
{
   SWV5_PersistedRequestEvidence empty_requests[];
   ArrayResize(empty_requests,0);
   return SWV5_TestInterfaceRestart(implementation,context,engineInput,empty_requests,readiness);
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
         {
            context.clock_id="";
            SWV5_BasketLifecycleSnapshot snapshot;
            SWV5_TestMakeLifecycle(snapshot,SWV5_BASKET_IDLE);
            SWV5_BasketInvariantReport report;
            SWV5_TestBasketStateContract basket_contract;
            passed=!basket_contract.ValidateState(context,snapshot,report) && report.status==SWV5_CONTRACT_INVALID;
            expected="missing_clock_fails_closed";
            break;
         }
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
             expected="material_transition_and_replay_equivalent";
             passed=allowed_a && allowed_b &&
                    result_a.decision.disposition==SWV5_DISPOSITION_ALLOW &&
                    result_a.resulting_state==SWV5_BASKET_CLOSING &&
                    result_a.resulting_state_version==snapshot.state_version+1 &&
                    result_a.resulting_state==result_b.resulting_state &&
                    result_a.resulting_state_version==result_b.resulting_state_version &&
                    result_a.resulting_cumulative_recovery_attempts==result_b.resulting_cumulative_recovery_attempts;
            break;
         }
         case 6:
         {
            context.evaluation_sequence=0;
            SWV5_BasketLifecycleSnapshot snapshot;
            SWV5_TestMakeLifecycle(snapshot,SWV5_BASKET_IDLE);
            SWV5_BasketInvariantReport report;
            SWV5_TestBasketStateContract basket_contract;
            passed=!basket_contract.ValidateState(context,snapshot,report) && report.status==SWV5_CONTRACT_INVALID;
            expected="missing_sequence_fails_closed";
            break;
         }
         case 7:
         {
            SWV5_OwnershipFence left;
            SWV5_OwnershipFence right;
            SWV5_TestMakeFence(left);
            SWV5_TestMakeFence(right);
            right.fencing_token_digest="STALE-FENCE";
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
            SWV5_TestOwnershipContract ownership;
            SWV5_OwnershipDecision heartbeat;
            passed=!ownership.Heartbeat(context,lease,lease,heartbeat) &&
                   heartbeat.decision.disposition==SWV5_DISPOSITION_DENY;
            expected="wrong_clock_heartbeat_rejected";
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
            ZeroMemory(result);
            result.evaluated_version.contract_name="PRESEEDED-WRONG-VERSION";
            result.compatibility=SWV5_COMPATIBILITY_REJECTED;
            passed=implementation.EvaluateCompatibility(context,candidate,result) &&
                   SWV5_TestVersionEqual(result.evaluated_version,candidate) &&
                   result.compatibility==SWV5_COMPATIBILITY_EXACT && result.reason_code=="EXACT";
            expected="preseeded_output_replaced_with_exact_result";
            break;
         }
         case 12:
         {
            SWV5_BasketLifecycleSnapshot snapshot;
            SWV5_TestMakeLifecycle(snapshot,SWV5_BASKET_IDLE);
            SWV5_BasketInvariantReport report;
            SWV5_TestBasketStateContract basket_contract;
            context.evaluation_sequence=0;
            passed=!basket_contract.ValidateState(context,snapshot,report) &&
                   report.status==SWV5_CONTRACT_INVALID;
            expected="invalid_context_fails_closed";
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
            SWV5_ContractDecision first,replay,rejected;
            const bool first_ok=implementation.ValidatePartialClose(context,basket,partial,first);
            const bool replay_ok=implementation.ValidatePartialClose(context,basket,partial,replay);
            SWV5_PartialCloseEvidence impossible=partial;
            impossible.closed_volume=impossible.volume_before+0.01;
            const bool impossible_ok=implementation.ValidatePartialClose(context,basket,impossible,rejected);
            passed=first_ok && replay_ok && !impossible_ok &&
                   first.disposition==SWV5_DISPOSITION_ALLOW && rejected.disposition==SWV5_DISPOSITION_DENY &&
                   SWV5_TestDecisionEqual(first,replay) &&
                   SWV5_TestNear(basket.lifecycle.residual_volume,0.20,context.volume_tolerance);
            expected="valid_replay_stable_and_impossible_close_rejected";
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
            passed=!implementation.ValidateAggregate(context,basket,basket_result) &&
                   basket_result.decision.disposition==SWV5_DISPOSITION_DENY;
            expected="incomplete_namespace_rejected";
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
            passed=implementation.Acquire(context,claim,observed,ownership_decision) &&
                   ownership_decision.resulting_lease.status==SWV5_LOCK_ACQUIRED &&
                   ownership_decision.resulting_lease.fence.lease_version==observed.fence.lease_version+1 &&
                   SWV5_TestOwnerEqual(ownership_decision.resulting_lease.fence.owner,claim.claimant);
            expected="acquire_version_8";
            break;
         }
         case 2:
         {
            SWV5_OwnershipConflict conflict;
            passed=implementation.DetectConflict(context,claim,observed,conflict) &&
                   conflict.status==SWV5_LOCK_CONFLICT &&
                   SWV5_TestOwnerEqual(conflict.claimant,claim.claimant) && SWV5_TestOwnerEqual(conflict.incumbent,observed.fence.owner);
            expected="conflict_halt";
            break;
         }
         case 3:
            observed.status=SWV5_LOCK_EXPIRED;
            context.clock_sequence=1000;
            observed.expiry_clock_sequence=1100;
            SWV5_TestMakeClaim(claim,observed);
            passed=!implementation.Acquire(context,claim,observed,ownership_decision);
            break;
         case 4:
            observed.status=SWV5_LOCK_EXPIRED;
            observed.expires_at=SWV5_TEST_TIME-1;
            observed.expiry_clock_sequence=999;
            SWV5_TestMakeClaim(claim,observed);
            claim.takeover_evidence.broker_reconciliation.evidence_id="";
            claim.takeover_evidence.persistence_reconciliation.evidence_id="";
            passed=!implementation.Acquire(context,claim,observed,ownership_decision);
            break;
         case 5:
            observed.status=SWV5_LOCK_EXPIRED;
            observed.expires_at=SWV5_TEST_TIME-1;
            observed.expiry_clock_sequence=999;
            SWV5_TestMakeClaim(claim,observed);
            passed=implementation.Acquire(context,claim,observed,ownership_decision) &&
                   ownership_decision.resulting_lease.fence.takeover_generation==3;
            expected="takeover_generation_3";
            break;
         case 6:
         {
            SWV5_InstanceLease caller=observed;
            caller.fence.fencing_token_digest="STALE-TOKEN";
            passed=!implementation.Heartbeat(context,caller,observed,ownership_decision) &&
                   ownership_decision.decision.disposition==SWV5_DISPOSITION_DENY;
            expected="stale_token_heartbeat_rejected";
            break;
         }
         case 7:
         {
            SWV5_InstanceLease caller=observed;
            caller.store_revision="STALE-REV";
            passed=!implementation.Release(context,caller,observed,ownership_decision) &&
                   ownership_decision.resulting_lease.status==observed.status;
            expected="stale_revision_release_rejected";
            break;
         }
         case 8:
         {
            SWV5_OwnershipConflict conflict;
            passed=implementation.DetectConflict(context,claim,observed,conflict) &&
                   conflict.simultaneous_heartbeat && conflict.status==SWV5_LOCK_CONFLICT;
            expected="conflict_halt";
            break;
         }
         case 9:
            observed.status=SWV5_LOCK_CORRUPT;
            context.clock_authority=SWV5_TIME_AUTHORITY_NONE;
            passed=!implementation.Acquire(context,claim,observed,ownership_decision) &&
                   ownership_decision.decision.disposition==SWV5_DISPOSITION_DENY;
            expected="operator_required";
            break;
         case 10:
         {
            SWV5_InstanceLease stale=observed;
            stale.fence.lease_version++;
            passed=!implementation.Release(context,stale,observed,ownership_decision) &&
                   ownership_decision.resulting_lease.status==observed.status;
            break;
         }
         case 11:
         {
            SWV5_InstanceLease caller=observed;
            caller.clock_id="FOREIGN-CLOCK";
            passed=!implementation.Heartbeat(context,caller,observed,ownership_decision) &&
                   ownership_decision.decision.disposition==SWV5_DISPOSITION_DENY;
            break;
         }
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
         {
            SWV5_ExecutionConfirmation first,replay;
            const bool first_ok=implementation.AcceptTransactionEvidence(context,pending,evidence,first);
            const bool replay_ok=implementation.AcceptTransactionEvidence(context,first.resulting_pending_request,evidence,replay);
            passed=first_ok && replay_ok && replay.duplicate_event && !replay.event_identity_added &&
                   SWV5_TestNear(replay.confirmed_volume,first.confirmed_volume,context.volume_tolerance) &&
                   SWV5_TestNear(replay.residual_volume,first.residual_volume,context.volume_tolerance) &&
                   SWV5_TestEventIdentitySetEqual(replay.resulting_pending_request.accepted_event_identities,
                                                  first.resulting_pending_request.accepted_event_identities);
            expected="idempotent_0.10";
            break;
         }
         case 10:
         {
            SWV5_DurableEventIdentitySet newer;
            SWV5_TransactionEvidence newer_evidence=evidence;
            newer_evidence.correlation.broker_identity.broker_event_id="NEWER-EVENT";
            newer_evidence.correlation.broker_identity.transaction_sequence=500;
            SWV5_TestAppendDurableFingerprint("NEWER-EVENT",500,
                                              SWV5_TestCanonicalTransactionEvidence(newer_evidence),
                                              pending.accepted_event_identities,newer);
            pending.accepted_event_identities=newer;
            evidence.correlation.broker_identity.transaction_sequence=499;
            evidence.correlation.broker_identity.broker_event_id="OLDER-UNSEEN-EVENT";
            passed=SWV5_TestInterfaceConfirmation(implementation,context,pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_CONFIRMED;
            expected="out_of_order_new_accepted_once";
            break;
         }
         case 11:
            evidence.confirmed_volume=0.04;
            passed=SWV5_TestInterfaceConfirmation(implementation,context,pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_PARTIAL &&
                   SWV5_TestNear(confirmed,0.04,context.volume_tolerance) && SWV5_TestNear(residual,0.06,context.volume_tolerance);
            expected="partial_0.04_residual_0.06";
            break;
         case 12:
         {
            SWV5_TestMakeRetryCandidate(pending);
            SWV5_RetryPolicy policy;
            SWV5_TestMakeRetryPolicy(context,policy);
            SWV5_RetryRiskFreshnessEvidence risk_evidence;
            SWV5_TestMakeRetryRiskEvidence(context,pending,risk_evidence);
            SWV5_RetryNormalizationFreshnessEvidence normalization_evidence;
            SWV5_TestMakeRetryNormalizationEvidence(context,pending,normalization_evidence);
            pending.submission_attempt_count=3;
            pending.latest_submission.submission_attempt_count=3;
            SWV5_ContractDecision retry_decision;
            passed=!implementation.EvaluateRetry(context,pending,policy,risk_evidence,normalization_evidence,retry_decision) &&
                   retry_decision.disposition==SWV5_DISPOSITION_DENY;
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
            evidence.ownership_fence.fencing_token_digest="STALE-FENCE";
            passed=SWV5_TestInterfaceConfirmation(implementation,context,pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_CONFLICT;
            expected="halt_and_reconcile";
            break;
         case 16:
         {
            pending.state=SWV5_REQUEST_ACKNOWLEDGED;
            pending.lifecycle_phase=SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT;
            SWV5_TestMakeAcknowledgementTransaction(pending,evidence);
            SWV5_ExecutionConfirmation acknowledgement;
            passed=implementation.AcceptTransactionEvidence(context,pending,evidence,acknowledgement) &&
                   acknowledgement.evidence_disposition==SWV5_TRANSACTION_EVIDENCE_ACKNOWLEDGEMENT_ONLY &&
                   acknowledgement.status==SWV5_CONFIRMATION_PENDING &&
                   !acknowledgement.event_identity_added && !acknowledgement.duplicate_event &&
                   SWV5_TestPendingRequestEqual(acknowledgement.resulting_pending_request,pending) &&
                   acknowledgement.resulting_pending_request.cumulative_confirmed_volume==0.0 &&
                   acknowledgement.resulting_pending_request.state==SWV5_REQUEST_ACKNOWLEDGED;
            expected="ack_interface_preserves_unconfirmed_pending_state";
            break;
         }
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("EXE",number),"EXECUTION",passed,expected);
   }
}

bool SWV5_TestPER02Behavior()
{
   SWV5_ContractValidationContext context;
   SWV5_TestMakeContext(context);
   SWV5_PersistedCheckpoint checkpoint;
   SWV5_TestMakeCheckpoint(checkpoint);
   SWV5_TestPersistenceContract persistence;
   SWV5_PersistenceLoadResult validation_result,load_result;
   SWV5_ContractDecision save_decision;
   const bool baseline_valid=persistence.ValidateRecord(context,checkpoint,validation_result) &&
                             persistence.SaveCheckpoint(context,checkpoint,save_decision);
   SWV5_PersistedCheckpoint corrupted=checkpoint;
   corrupted.basket.lifecycle.cumulative_recovery_attempts++;
   const bool stale_digest_retained=corrupted.header.payload_digest!="" &&
                                    corrupted.header.payload_digest==checkpoint.header.payload_digest &&
                                    corrupted.header.payload_size==checkpoint.header.payload_size;
   const bool rejected=!persistence.ValidateRecord(context,corrupted,validation_result) &&
                       !persistence.SaveCheckpoint(context,corrupted,save_decision);
   SWV5_PersistedCheckpoint loaded;
   const bool original_preserved=persistence.LoadLatest(context,checkpoint.header.persistence_namespace,loaded,load_result) &&
                                 loaded.basket.lifecycle.cumulative_recovery_attempts==checkpoint.basket.lifecycle.cumulative_recovery_attempts &&
                                 SWV5_TestPersistenceRecordValid(context,loaded);
   return baseline_valid && stale_digest_retained && rejected && original_preserved;
}

void SWV5_RunPersistenceTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=15;number++)
   {
      if(!SWV5_TestIdSelected(SWV5_TestCaseId("PER",number))) continue;
      SWV5_RestartReconciliationInput engineInput;
      SWV5_TestMakeRestartInput(engineInput);
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_TestPersistenceContract implementation;
      SWV5_PersistenceLoadResult load_result;
      SWV5_RestartReadinessDisposition readiness;
      SWV5_PersistedRequestEvidence pending_requests[];
      ArrayResize(pending_requests,0);
      bool passed=false;
      string expected="fail_closed";
      switch(number)
      {
         case 1:
            passed=implementation.ValidateRecord(context,engineInput.persisted,load_result);
            expected="record_valid";
            break;
         case 2:
            passed=SWV5_TestPER02Behavior();
            expected="stale_digest_after_payload_corruption";
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
            engineInput.broker.complete_summary_digest=SWV5_TestBrokerSummaryDigest(engineInput.broker);
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,readiness)==SWV5_RECONCILIATION_BROKER_AHEAD_HALT;
            expected="broker_ahead_halt";
            break;
         case 7:
            engineInput.broker.residual_volume-=0.10;
            engineInput.broker.complete_summary_digest=SWV5_TestBrokerSummaryDigest(engineInput.broker);
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,readiness)==SWV5_RECONCILIATION_PERSISTENCE_AHEAD_HALT;
            expected="persistence_ahead_halt";
            break;
         case 8:
            engineInput.broker.queries.completed_flags&=~SWV5_QUERY_DEALS;
            engineInput.broker.complete_summary_digest=SWV5_TestBrokerSummaryDigest(engineInput.broker);
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,readiness)==SWV5_RECONCILIATION_MANUAL_REQUIRED;
            expected="manual_required";
            break;
         case 9:
            ArrayResize(pending_requests,1);
            SWV5_TestMakePersistedRequest(pending_requests[0],1);
            pending_requests[0].pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_UNCERTAIN;
            pending_requests[0].pending_request.state=SWV5_REQUEST_RECONCILIATION_REQUIRED;
            pending_requests[0].pending_request.retry_disposition=SWV5_RETRY_REQUIRES_RECONCILIATION;
            SWV5_TestBindCheckpointRequests(engineInput,pending_requests,30);
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,pending_requests,readiness)==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED &&
                   readiness==SWV5_RESTART_RECONCILIATION_REQUIRED;
            expected="uncertain_requires_reconciliation";
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
            SWV5_TestSealCheckpoint(engineInput.persisted);
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,pending_requests,readiness)==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED &&
                   readiness==SWV5_RESTART_CLOSE_ONLY;
            expected="active_latch_close_only";
            break;
         case 13:
            ArrayResize(pending_requests,1);
            SWV5_TestMakePersistedRequest(pending_requests[0],2);
            SWV5_TestBindCheckpointRequests(engineInput,pending_requests,30);
            engineInput.persisted.pending_request_set.request_set_digest="COPIED-FROM-OTHER-PAYLOAD";
            engineInput.persisted.reconciliation_vector.request_set_digest=engineInput.persisted.pending_request_set.request_set_digest;
            engineInput.persisted.reconciliation_vector.source_summary_digest=
               SWV5_TestReconciliationSourceDigest(engineInput.persisted.reconciliation_vector);
            SWV5_TestSealCheckpoint(engineInput.persisted);
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,pending_requests,readiness)==SWV5_RECONCILIATION_CONFLICT_HALT &&
                   readiness==SWV5_RESTART_HALTED;
            expected="payload_digest_conflict";
            break;
         case 14:
            engineInput.persistence_namespace.ownership_namespace.broker_identity="";
            engineInput.persisted.header.persistence_namespace=engineInput.persistence_namespace;
            engineInput.broker.persistence_namespace=engineInput.persistence_namespace;
            SWV5_TestSealCheckpoint(engineInput.persisted);
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,readiness)==SWV5_RECONCILIATION_CORRUPT_HALT && readiness==SWV5_RESTART_HALTED;
            expected="semantically_invalid_composite_namespace_halts";
            break;
         case 15:
            ArrayResize(pending_requests,1);
            SWV5_TestMakePersistedRequest(pending_requests[0],3);
            pending_requests[0].persistence_namespace.basket_id.value="FOREIGN-BASKET";
            SWV5_TestBindRequestSetHeader(engineInput.persisted.pending_request_set,pending_requests,30);
            engineInput.persisted.has_latest_pending_request=true;
            engineInput.persisted.latest_pending_request=pending_requests[0];
            engineInput.broker.pending_request_count=1;
            SWV5_TestSealCheckpoint(engineInput.persisted);
            passed=SWV5_TestInterfaceRestart(implementation,context,engineInput,pending_requests,readiness)==SWV5_RECONCILIATION_CORRUPT_HALT &&
                   readiness==SWV5_RESTART_HALTED;
            expected="semantically_invalid_membership_halts";
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
      SWV5_RiskEvaluationInput current;
      SWV5_TestMakeRiskInput(current);
      SWV5_RiskAuthorization authorization;
      SWV5_TestRiskContract implementation;
      const bool base_evaluated=implementation.Evaluate(context,current,authorization);
      SWV5_ContractDecision contract_decision;
      bool passed=false;
      string expected="fail_closed";
      switch(number)
      {
         case 1:
         {
            SWV5_RiskEvaluationInput risk_input;
            SWV5_TestMakeRiskInput(risk_input);
            risk_input.hard_kill_state.state=SWV5_HARD_KILL_ACTIVE;
            passed=!implementation.Evaluate(context,risk_input,authorization) && authorization.disposition!=SWV5_RISK_ALLOW;
            expected="exposure_increase_blocked";
            break;
         }
         case 2:
            authorization.ownership_fence.fencing_token_digest="STALE-FENCE";
            passed=base_evaluated && SWV5_TestRiskPrecheck(current.hard_kill_state,current.intent.ownership_fence,authorization.ownership_fence)==SWV5_RISK_RECONCILIATION_REQUIRED &&
                    !implementation.ValidateAuthorization(context,authorization,current,contract_decision);
            break;
         case 3:
            authorization.risk_snapshot_epoch=0;
            passed=base_evaluated && !implementation.ValidateAuthorization(context,authorization,current,contract_decision);
            expected="stale_snapshot_blocked";
            break;
         case 4:
         {
            SWV5_RiskEvaluationInput risk_input;
            SWV5_TestMakeRiskInput(risk_input);
            risk_input.account.equity=risk_input.limits.minimum_equity-1.0;
            passed=!implementation.Evaluate(context,risk_input,authorization) && authorization.disposition!=SWV5_RISK_ALLOW;
            expected="equity_block";
            break;
         }
         case 5:
         {
            SWV5_RiskEvaluationInput risk_input;
            SWV5_TestMakeRiskInput(risk_input);
            risk_input.account.daily_realized_net=-(risk_input.limits.maximum_daily_net_loss+1.0);
            passed=!implementation.Evaluate(context,risk_input,authorization) && authorization.disposition!=SWV5_RISK_ALLOW;
            expected="daily_loss_halt";
            break;
         }
         case 6:
         {
            SWV5_RiskEvaluationInput risk_input;
            SWV5_TestMakeRiskInput(risk_input);
            risk_input.projected.projected_aggregate_volume=risk_input.limits.maximum_aggregate_volume+0.1;
            passed=!implementation.Evaluate(context,risk_input,authorization) && authorization.disposition!=SWV5_RISK_ALLOW;
            expected="aggregate_domain_block";
            break;
         }
         case 7:
         {
            SWV5_RiskEvaluationInput risk_input;
            SWV5_TestMakeRiskInput(risk_input);
            risk_input.projected.projected_maximum_loss=risk_input.limits.maximum_basket_loss+1.0;
            passed=!implementation.Evaluate(context,risk_input,authorization) && authorization.disposition!=SWV5_RISK_ALLOW;
            expected="basket_close_only";
            break;
         }
         case 8:
            authorization.symbol_specification_sequence++;
            passed=base_evaluated && !implementation.ValidateAuthorization(context,authorization,current,contract_decision);
            expected="binding_mismatch_rejected";
            break;
         case 9:
            context.clock_time=authorization.expires_at+1;
            passed=base_evaluated && !implementation.ValidateAuthorization(context,authorization,current,contract_decision);
            expected="expired";
            break;
         case 10:
            current.intent.normalized_volume=0.20;
            passed=base_evaluated && !implementation.ValidateAuthorization(context,authorization,current,contract_decision);
            expected="volume_exceeds_authorization";
            break;
         case 11:
            current.hard_kill_state.state=SWV5_HARD_KILL_RELEASE_PENDING;
            passed=!implementation.ValidateHardKillRelease(context,current.hard_kill_state,current.hard_kill_state.release_evidence,contract_decision);
            expected="release_evidence_rejected";
            break;
         case 12:
         {
            SWV5_RiskEvaluationInput risk_input;
            SWV5_TestMakeRiskInput(risk_input);
            risk_input.hard_kill_state.state=SWV5_HARD_KILL_ACTIVE;
            passed=!implementation.Evaluate(context,risk_input,authorization) && authorization.disposition!=SWV5_RISK_ALLOW;
            expected="restart_latch_active";
            break;
         }
         case 13:
            authorization.account_namespace.snapshot_epoch=0;
            passed=base_evaluated && !implementation.ValidateAuthorization(context,authorization,current,contract_decision);
            expected="snapshot_binding_invalid";
            break;
         case 14:
            authorization.hard_kill_latch_generation=3;
            passed=base_evaluated && !implementation.ValidateAuthorization(context,authorization,current,contract_decision);
            expected="latch_generation_invalid";
            break;
         case 15:
            authorization.monetary_basis.conversion_source="";
            passed=base_evaluated && !implementation.ValidateAuthorization(context,authorization,current,contract_decision);
            expected="monetary_basis_invalid";
            break;
         case 16:
            current.intent.request_identity.request_id.attempt_id="ATTEMPT-0002";
            passed=base_evaluated && !implementation.ValidateAuthorization(context,authorization,current,contract_decision);
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
         {
            SWV5_BasketStatistics current,next;
            SWV5_TestMakeStatistics(current);
            deal.correlation=evidence.correlation;
            passed=implementation.AccumulateDeal(validation_context,deal,evidence,current,next) &&
                   next.deal_count==current.deal_count+1 &&
                   next.deduplication.unique_deal_count==current.deduplication.unique_deal_count+1 &&
                   next.deduplication.identities.accepted_identity_count==current.deduplication.identities.accepted_identity_count+1 &&
                   SWV5_TestNear(next.gross_profit,current.gross_profit+100.0,0.0000001) &&
                   SWV5_TestNear(next.commission,current.commission-2.0,0.0000001) &&
                   SWV5_TestNear(next.swap,current.swap-1.0,0.0000001) &&
                   SWV5_TestNear(next.fee,current.fee-0.5,0.0000001) &&
                   SWV5_TestNear(next.authoritative_net_result,current.authoritative_net_result+96.5,0.0000001);
            expected="unique_deal_mutates_all_money_counts_and_identity";
            break;
         }
         case 3:
         {
            SWV5_BasketStatistics current,next;
            SWV5_TestMakeStatistics(current);
            current.residual_volume=0.30;
            current.partial_close_count=0;
            deal.correlation=evidence.correlation;
            passed=implementation.AccumulateDeal(validation_context,deal,evidence,current,next) &&
                   SWV5_TestNear(next.residual_volume,0.20,0.0000001) && next.partial_close_count==1;
            expected="partial_count_1_residual_0.20";
            break;
         }
         case 4:
         {
            SWV5_TestMakeDedupEvidence(evidence,state,SWV5_STAT_IDENTITY_DUPLICATE);
            SWV5_BasketStatistics current,next;
            SWV5_TestMakeStatistics(current);
            deal.correlation=evidence.correlation;
            passed=implementation.AccumulateDeal(validation_context,deal,evidence,current,next) &&
                   next.deal_count==current.deal_count && next.entry_deal_count==current.entry_deal_count &&
                   next.exit_deal_count==current.exit_deal_count && next.partial_close_count==current.partial_close_count &&
                   SWV5_TestNear(next.gross_profit,current.gross_profit,validation_context.price_tolerance) &&
                   SWV5_TestNear(next.commission,current.commission,validation_context.price_tolerance) &&
                   SWV5_TestNear(next.swap,current.swap,validation_context.price_tolerance) &&
                   SWV5_TestNear(next.fee,current.fee,validation_context.price_tolerance) &&
                   SWV5_TestNear(next.authoritative_net_result,current.authoritative_net_result,validation_context.price_tolerance) &&
                   SWV5_TestEventIdentitySetEqual(next.deduplication.identities,current.deduplication.identities) &&
                   next.deduplication.duplicate_deal_count==current.deduplication.duplicate_deal_count+1;
            expected="duplicate_replay_only_increments_duplicate_counter";
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
            SWV5_BasketStatistics current,next;
            SWV5_TestMakeStatistics(current);
            current.residual_volume=deal.volume;
            deal.correlation=evidence.correlation;
            const bool accumulated=implementation.AccumulateDeal(validation_context,deal,evidence,current,next);
            SWV5_StatisticsValidationResult result;
            passed=accumulated && SWV5_TestNear(next.residual_volume,0.0,validation_context.volume_tolerance) &&
                   implementation.Finalize(validation_context,context,next,result) &&
                   result.decision.disposition==SWV5_DISPOSITION_ALLOW &&
                   (result.validation_flags&SWV5_STAT_MONETARY_COMPLETE)!=0 &&
                   (result.validation_flags&SWV5_STAT_IDENTITY_SET_VALID)!=0;
            expected="returned_accumulation_state_is_completion_eligible";
            break;
         }
         case 9:
            context.account_mode=SWV5_ACCOUNT_MODE_NETTING;
            passed=!implementation.ValidateDeal(validation_context,deal,context,contract_decision);
            expected="netting_rejected";
            break;
         case 10:
         {
            SWV5_TestMakeDedupEvidence(evidence,state,SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW);
            evidence.correlation.broker_identity.transaction_sequence=state.identities.highest_transaction_sequence-2;
            evidence.correlation.broker_identity.broker_event_id="OUT-OF-ORDER-NEW";
            deal.correlation=evidence.correlation;
            SWV5_BasketStatistics current,next;
            SWV5_TestMakeStatistics(current);
            passed=implementation.AccumulateDeal(validation_context,deal,evidence,current,next) &&
                   next.deduplication.identities.accepted_identity_count==current.deduplication.identities.accepted_identity_count+1 &&
                   next.deduplication.identities.highest_transaction_sequence==current.deduplication.identities.highest_transaction_sequence &&
                   next.deduplication.unique_deal_count==current.deduplication.unique_deal_count+1;
            expected="out_of_order_accumulated_once";
            break;
         }
         case 11:
         {
            SWV5_TestMakeDedupEvidence(evidence,state,SWV5_STAT_IDENTITY_DUPLICATE);
            evidence.membership_proof="";
            deal.correlation=evidence.correlation;
            SWV5_BasketStatistics current,next;
            SWV5_TestMakeStatistics(current);
            passed=!implementation.AccumulateDeal(validation_context,deal,evidence,current,next);
            expected="identity_evidence_rejected";
            break;
         }
         case 12:
         {
            SWV5_BasketStatistics current,next;
            SWV5_TestMakeStatistics(current);
            SWV5_TestMakeDedupEvidence(evidence,state,SWV5_STAT_IDENTITY_NEW);
            evidence.correlation.broker_identity.broker_event_id="EVENT-0001";
            deal.correlation=evidence.correlation;
            passed=!implementation.AccumulateDeal(validation_context,deal,evidence,current,next);
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
      if(!SWV5_TestIdSelected(SWV5_TestCaseId("XDM",number))) continue;
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_RiskEvaluationInput risk_binding;
      SWV5_TestMakeRiskInput(risk_binding);
      SWV5_ExecutionIntent intent=risk_binding.intent;
      SWV5_RiskAuthorization authorization;
      SWV5_RestartReconciliationInput restart;
      SWV5_TestMakeRestartInput(restart);
      SWV5_PendingRequest pending;
      SWV5_TestMakePending(pending);
      SWV5_TransactionEvidence transaction;
      SWV5_TestMakeTransaction(pending,transaction);
      SWV5_TestExecutionContract execution_contract;
      SWV5_TestRiskContract risk_contract;
      const bool risk_evaluated=risk_contract.Evaluate(context,risk_binding,authorization);
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
             passed=risk_evaluated && execution_contract.ValidateIntent(context,intent,contract_decision) &&
                    risk_contract.ValidateAuthorization(context,authorization,risk_binding,contract_decision) &&
                    SWV5_TestInterfaceRestart(persistence_contract,context,restart,readiness)==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED &&
                    unit_contract.Normalize(context,specification,request,normalized,unit_result) &&
                    SWV5_TestInterfaceConfirmation(execution_contract,context,pending,transaction,confirmed,residual)==SWV5_CONFIRMATION_CONFIRMED;
            expected="ordered_gates_confirmed";
            break;
         }
         case 2:
            pending.state=SWV5_REQUEST_ACKNOWLEDGED;
            transaction.ownership_fence.takeover_generation++;
            passed=SWV5_TestInterfaceConfirmation(execution_contract,context,pending,transaction,confirmed,residual)==SWV5_CONFIRMATION_CONFLICT;
            expected="halt_reconcile_no_retry";
            break;
         case 3:
         {
            SWV5_PersistedRequestEvidence pending_requests[];
            ArrayResize(pending_requests,1);
            SWV5_TestMakePersistedRequest(pending_requests[0],1);
            pending_requests[0].pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_UNCERTAIN;
            pending_requests[0].pending_request.state=SWV5_REQUEST_RECONCILIATION_REQUIRED;
            pending_requests[0].pending_request.retry_disposition=SWV5_RETRY_REQUIRES_RECONCILIATION;
            SWV5_TestBindCheckpointRequests(restart,pending_requests,30);
            passed=SWV5_TestInterfaceRestart(persistence_contract,context,restart,pending_requests,readiness)==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED &&
                   readiness==SWV5_RESTART_RECONCILIATION_REQUIRED;
            expected="uncertain_restart_reconciles_no_blind_retry";
            break;
         }
         case 4:
         {
            SWV5_BasketAggregate basket;
            SWV5_TestMakeAggregate(basket,SWV5_BASKET_CLOSING);
            SWV5_CloseVerificationEvidence close_evidence;
            SWV5_TestMakeCloseEvidence(basket,close_evidence);
            close_evidence.broker_residual_volume=0.10;
            close_evidence.broker_position_count=1;
            passed=!basket_contract.ValidateCloseCompletion(context,basket,close_evidence,contract_decision) &&
                   contract_decision.disposition==SWV5_DISPOSITION_DENY;
            expected="residual_close_completion_denied";
            break;
         }
         case 5:
            risk_binding.intent.symbol_specification_sequence=51;
            passed=risk_evaluated && !risk_contract.ValidateAuthorization(context,authorization,risk_binding,contract_decision);
            expected="renormalize_reevaluate";
            break;
         case 6:
         {
            SWV5_HardKillState hard_kill;
            SWV5_TestMakeHardKill(hard_kill,SWV5_HARD_KILL_ACTIVE);
            SWV5_RiskEvaluationInput risk_input;
            SWV5_TestMakeRiskInput(risk_input);
            risk_input.hard_kill_state=hard_kill;
            SWV5_RiskAuthorization denied;
            passed=!risk_contract.Evaluate(context,risk_input,denied) &&
                   denied.disposition==SWV5_RISK_RECONCILIATION_REQUIRED;
            expected="hard_kill_blocks_risk_authorization";
            break;
         }
         case 7:
         {
            SWV5_ExecutionConfirmation first,replay;
            const bool first_ok=execution_contract.AcceptTransactionEvidence(context,pending,transaction,first);
            const bool replay_ok=execution_contract.AcceptTransactionEvidence(context,first.resulting_pending_request,transaction,replay);
            passed=first_ok && replay_ok && replay.duplicate_event && !replay.event_identity_added &&
                   SWV5_TestNear(replay.confirmed_volume,first.confirmed_volume,context.volume_tolerance) &&
                   SWV5_TestNear(replay.residual_volume,first.residual_volume,context.volume_tolerance) &&
                   SWV5_TestEventIdentitySetEqual(replay.resulting_pending_request.accepted_event_identities,
                                                  first.resulting_pending_request.accepted_event_identities);
            expected="duplicate_no_second_update";
            break;
         }
         case 8:
            restart.persistence_status=SWV5_PERSISTENCE_NOT_FOUND;
            restart.broker.queries.completed_flags=0;
            passed=SWV5_TestInterfaceRestart(persistence_contract,context,restart,readiness)==SWV5_RECONCILIATION_CORRUPT_HALT;
            expected="never_execution_ready";
            break;
         case 9:
            authorization.ownership_fence.takeover_generation++;
            passed=risk_evaluated && !risk_contract.ValidateAuthorization(context,authorization,risk_binding,contract_decision);
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
         {
            pending.state=SWV5_REQUEST_ACKNOWLEDGED;
            pending.lifecycle_phase=SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT;
            SWV5_TestMakeAcknowledgementTransaction(pending,transaction);
            SWV5_ExecutionConfirmation acknowledgement;
            const bool acknowledgement_ok=execution_contract.AcceptTransactionEvidence(context,pending,transaction,acknowledgement);
            SWV5_PersistedRequestEvidence pending_requests[];
            ArrayResize(pending_requests,1);
            SWV5_TestMakePersistedRequest(pending_requests[0],1);
            pending_requests[0].pending_request=acknowledgement.resulting_pending_request;
            SWV5_TestBindCheckpointRequests(restart,pending_requests,30);
            passed=acknowledgement_ok && acknowledgement.status==SWV5_CONFIRMATION_PENDING &&
                   acknowledgement.evidence_disposition==SWV5_TRANSACTION_EVIDENCE_ACKNOWLEDGEMENT_ONLY &&
                   !acknowledgement.event_identity_added &&
                   acknowledgement.resulting_pending_request.cumulative_confirmed_volume==0.0 &&
                   SWV5_TestInterfaceRestart(persistence_contract,context,restart,pending_requests,readiness)==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED &&
                   readiness==SWV5_RESTART_RETRY_FORBIDDEN;
            expected="ack_returned_state_persists_unconfirmed_and_retry_forbidden";
            break;
         }
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

void SWV5_RunSprint45ExecutionAuthorityTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=10;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_PendingRequest pending;
      SWV5_TestMakePending(pending);
      SWV5_TransactionEvidence evidence;
      SWV5_TestMakeTransaction(pending,evidence,0.10);
      SWV5_TestExecutionContract execution;
      SWV5_ExecutionConfirmation confirmation;
      bool accepted=false;
      bool passed=false;
      string expected="fail_closed";
      if(number==1 || number==2)
      {
         SWV5_TestMakeAcknowledgementTransaction(pending,evidence);
         accepted=execution.AcceptTransactionEvidence(context,pending,evidence,confirmation);
         passed=accepted && confirmation.evidence_disposition==SWV5_TRANSACTION_EVIDENCE_ACKNOWLEDGEMENT_ONLY &&
                confirmation.status==SWV5_CONFIRMATION_PENDING && !confirmation.event_identity_added &&
                confirmation.resulting_pending_request.cumulative_confirmed_volume==pending.cumulative_confirmed_volume &&
                confirmation.resulting_pending_request.residual_requested_volume==pending.residual_requested_volume;
         expected=(number==1 ? "acknowledgement_cannot_confirm" : "order_ticket_cannot_confirm");
      }
      else if(number==3)
      {
         evidence.event_kind=SWV5_TRANSACTION_EVENT_POSITION_CHANGED;
         accepted=execution.AcceptTransactionEvidence(context,pending,evidence,confirmation);
         passed=!accepted && confirmation.evidence_disposition==SWV5_TRANSACTION_EVIDENCE_RECONCILIATION_REQUIRED &&
                confirmation.status==SWV5_CONFIRMATION_PENDING && !confirmation.event_identity_added &&
                confirmation.resulting_pending_request.cumulative_confirmed_volume==pending.cumulative_confirmed_volume;
         expected="position_change_requires_reconciliation";
      }
      else
      {
         if(number==4) evidence.authority=SWV5_AUTHORITY_SIGNAL_DTO;
         if(number==5) evidence.confirmed_volume=0.0;
         if(number==6) evidence.correlation.phase=SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT;
         if(number==8)
            evidence.confirmed_volume=0.04;
         if(number==9)
         {
            SWV5_ExecutionConfirmation first,replay;
            const bool first_ok=execution.AcceptTransactionEvidence(context,pending,evidence,first);
            const bool replay_ok=execution.AcceptTransactionEvidence(context,first.resulting_pending_request,evidence,replay);
            accepted=replay_ok;
            confirmation=replay;
            passed=first_ok && replay_ok && replay.duplicate_event && !replay.event_identity_added &&
                   replay.evidence_disposition==SWV5_TRANSACTION_EVIDENCE_AUTHORITATIVE_CONFIRMATION &&
                   SWV5_TestNear(replay.resulting_pending_request.cumulative_confirmed_volume,
                                 first.resulting_pending_request.cumulative_confirmed_volume,context.volume_tolerance) &&
                   SWV5_TestNear(replay.resulting_pending_request.residual_requested_volume,
                                 first.resulting_pending_request.residual_requested_volume,context.volume_tolerance) &&
                   SWV5_TestEventIdentitySetEqual(replay.resulting_pending_request.accepted_event_identities,
                                                  first.resulting_pending_request.accepted_event_identities);
         }
         else if(number==10)
         {
            evidence.confirmed_volume=0.04;
            SWV5_ExecutionConfirmation first,conflict;
            const bool first_ok=execution.AcceptTransactionEvidence(context,pending,evidence,first);
            SWV5_TransactionEvidence conflicting=evidence;
            conflicting.confirmed_price+=0.10;
            const bool conflict_ok=execution.AcceptTransactionEvidence(context,first.resulting_pending_request,conflicting,conflict);
            accepted=conflict_ok;
            confirmation=conflict;
            passed=first_ok && !conflict_ok && conflict.status==SWV5_CONFIRMATION_CONFLICT &&
                   conflict.disposition==SWV5_DISPOSITION_RECONCILE && !conflict.event_identity_added && !conflict.duplicate_event &&
                   SWV5_TestNear(conflict.resulting_pending_request.cumulative_confirmed_volume,
                                 first.resulting_pending_request.cumulative_confirmed_volume,context.volume_tolerance) &&
                   SWV5_TestNear(conflict.resulting_pending_request.residual_requested_volume,
                                 first.resulting_pending_request.residual_requested_volume,context.volume_tolerance) &&
                   SWV5_TestEventIdentitySetEqual(conflict.resulting_pending_request.accepted_event_identities,
                                                  first.resulting_pending_request.accepted_event_identities);
         }
         else
            accepted=execution.AcceptTransactionEvidence(context,pending,evidence,confirmation);
         if(number>=4 && number<=6)
            passed=!accepted && confirmation.status==SWV5_CONFIRMATION_CONFLICT && !confirmation.event_identity_added &&
                   confirmation.resulting_pending_request.cumulative_confirmed_volume==pending.cumulative_confirmed_volume;
         else if(number==7)
            passed=accepted && confirmation.status==SWV5_CONFIRMATION_CONFIRMED && confirmation.event_identity_added &&
                   confirmation.resulting_pending_request.cumulative_confirmed_volume==0.10 && confirmation.resulting_pending_request.residual_requested_volume==0.0;
         else if(number==8)
            passed=accepted && confirmation.evidence_disposition==SWV5_TRANSACTION_EVIDENCE_AUTHORITATIVE_CONFIRMATION &&
                   confirmation.status==SWV5_CONFIRMATION_PARTIAL && confirmation.event_identity_added && !confirmation.duplicate_event &&
                   confirmation.resulting_pending_request.lifecycle_phase==SWV5_EXECUTION_PHASE_PARTIAL_FILL &&
                   confirmation.resulting_pending_request.state==SWV5_REQUEST_PARTIALLY_CONFIRMED &&
                   SWV5_TestNear(confirmation.resulting_pending_request.cumulative_confirmed_volume,0.04,context.volume_tolerance) &&
                   SWV5_TestNear(confirmation.resulting_pending_request.residual_requested_volume,0.06,context.volume_tolerance) &&
                   confirmation.resulting_pending_request.accepted_event_identities.accepted_identity_count==pending.accepted_event_identities.accepted_identity_count+1 &&
                   confirmation.resulting_pending_request.accepted_event_identities.canonical_fingerprint_index!="";
         expected=(number==4 ? "non_authoritative_source_rejected" :
                  (number==5 ? "zero_volume_rejected" :
                  (number==6 ? "wrong_phase_rejected" :
                  (number==7 ? "authoritative_deal_confirms" :
                  (number==8 ? "authoritative_partial_fill" :
                  (number==9 ? "authoritative_duplicate_idempotent" : "conflicting_identity_rejected"))))));
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S45A",number),"SPRINT4_5_EXECUTION_AUTHORITY",passed,expected);
   }
}

void SWV5_RunSprint45FingerprintTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=2;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_PendingRequest pending;
      SWV5_TestMakePending(pending);
      SWV5_TransactionEvidence evidence;
      SWV5_TestMakeTransaction(pending,evidence,0.04);
      SWV5_TestExecutionContract execution;
      SWV5_ExecutionConfirmation first;
      const bool first_ok=execution.AcceptTransactionEvidence(context,pending,evidence,first);
      bool passed=first_ok && first.event_identity_added &&
                  first.resulting_pending_request.accepted_event_identities.canonical_fingerprint_index!="";
      string expected="fingerprint_binding";
      if(number==1)
      {
         for(int mutation=0;mutation<8 && passed;mutation++)
         {
            SWV5_TransactionEvidence conflicting=evidence;
            if(mutation==0) conflicting.confirmed_volume=0.05;
            if(mutation==1) conflicting.confirmed_price+=0.10;
            if(mutation==2) conflicting.event_kind=SWV5_TRANSACTION_EVENT_HISTORY_CONFIRMED;
            if(mutation==3) conflicting.correlation.request_identity.request_id.attempt_id="CONFLICTING-ATTEMPT";
            if(mutation==4) conflicting.expected_basket_version++;
            if(mutation==5) conflicting.symbol_specification_sequence++;
            if(mutation==6) conflicting.authority=SWV5_AUTHORITY_DEAL_HISTORY;
            if(mutation==7) conflicting.correlation.broker_identity.deal_ticket++;
            SWV5_ExecutionConfirmation conflict;
            const bool conflict_ok=execution.AcceptTransactionEvidence(context,first.resulting_pending_request,conflicting,conflict);
            passed=!conflict_ok && conflict.status==SWV5_CONFIRMATION_CONFLICT &&
                   conflict.disposition==SWV5_DISPOSITION_RECONCILE && !conflict.event_identity_added && !conflict.duplicate_event &&
                   SWV5_TestNear(conflict.resulting_pending_request.cumulative_confirmed_volume,
                                 first.resulting_pending_request.cumulative_confirmed_volume,context.volume_tolerance) &&
                   SWV5_TestNear(conflict.resulting_pending_request.residual_requested_volume,
                                 first.resulting_pending_request.residual_requested_volume,context.volume_tolerance) &&
                   SWV5_TestEventIdentitySetEqual(conflict.resulting_pending_request.accepted_event_identities,
                                                  first.resulting_pending_request.accepted_event_identities);
         }
         expected="eight_material_mutations_fail_closed";
      }
      else
      {
         SWV5_TestPersistenceContract persistence;
         SWV5_PersistedRequestEvidence saved[];
         ArrayResize(saved,1);
         SWV5_TestMakePersistedRequest(saved[0],45);
         saved[0].pending_request=first.resulting_pending_request;
         saved[0].persistence_namespace=first.resulting_pending_request.intent.persistence_namespace;
         saved[0].ownership_fence=first.resulting_pending_request.intent.ownership_fence;
         saved[0].account_mode=first.resulting_pending_request.account_mode;
         SWV5_PersistedRequestSetHeader header;
         SWV5_TestBindRequestSetHeader(header,saved,145);
         SWV5_ContractDecision decision;
         SWV5_PersistenceLoadResult load_result;
         SWV5_PersistedRequestEvidence loaded[];
         const bool round_trip=persistence.SavePendingRequests(context,saved[0].persistence_namespace,saved,header,decision) &&
                               persistence.LoadPendingRequests(context,saved[0].persistence_namespace,loaded,load_result) &&
                               ArraySize(loaded)==1 && SWV5_TestPersistedRequestEqual(saved[0],loaded[0]);
         SWV5_ExecutionConfirmation replay,conflict;
         const bool replay_ok=round_trip && execution.AcceptTransactionEvidence(context,loaded[0].pending_request,evidence,replay);
         SWV5_TransactionEvidence conflicting=evidence;
         conflicting.confirmed_price+=0.10;
         const bool conflict_ok=round_trip && execution.AcceptTransactionEvidence(context,loaded[0].pending_request,conflicting,conflict);
         passed=passed && round_trip && replay_ok && replay.duplicate_event && !replay.event_identity_added &&
                !conflict_ok && conflict.status==SWV5_CONFIRMATION_CONFLICT && !conflict.duplicate_event && !conflict.event_identity_added &&
                SWV5_TestEventIdentitySetEqual(loaded[0].pending_request.accepted_event_identities,
                                               first.resulting_pending_request.accepted_event_identities) &&
                SWV5_TestEventIdentitySetEqual(replay.resulting_pending_request.accepted_event_identities,
                                               loaded[0].pending_request.accepted_event_identities) &&
                SWV5_TestEventIdentitySetEqual(conflict.resulting_pending_request.accepted_event_identities,
                                               loaded[0].pending_request.accepted_event_identities);
         expected="fingerprint_survives_round_trip_replay_and_conflict";
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S45F",number),"SPRINT4_5_DURABLE_FINGERPRINT",passed,expected);
   }
}

// Sprint 4.6 Phase A credibility trace. Every case starts from a valid returned/fixture state,
// invokes the real test interface, asserts material output/no-mutation, and targets one unsafe omission.
// S46AE-01 valid intent; detects unusable canonical path.
// S46AE-02 schema version; detects version-valid/equality omission.
// S46AE-03 foreign contract name; detects V4-looking foreign identity acceptance.
// S46AE-04 empty fence digest; detects incomplete-fence acceptance.
// S46AE-05 complete foreign fence; detects missing fence-to-namespace relation.
// S46AE-06..11 broker/server/login/strategy/symbol/Magic namespace mutations; each detects a missing key-field binding.
// S46AE-12 invalid intent enum; detects arbitrary enum acceptance.
// S46AE-13 invalid direction; detects arbitrary direction acceptance.
// S46AE-14 cancel plus trading terms; detects contradictory intent/direction/term acceptance.
// S46AE-15 foreign policy; detects policy identity omission.
// S46AE-16 foreign namespace contract; detects nested namespace version omission.
// S46AE-17 foreign request contract; detects request-identity version omission.
// S46AE-18 foreign expected context identity; detects non-Production validation context acceptance.
// S46AE-19 valid acknowledgement; proves acknowledgement-only state and zero exposure mutation.
// S46AE-20 foreign acknowledgement fence; detects acknowledgement fast-path bypass.
// S46AE-21 foreign acknowledgement namespace; detects acknowledgement namespace bypass.
// S46AE-22 valid authoritative deal; proves canonical confirmation path.
// S46AE-23 wrong evidence schema; detects transaction version omission.
// S46AE-24 coherent foreign evidence namespace/fence; detects pending-to-evidence scope omission.
// S46AE-25 stale fence token; detects stale-owner confirmation.
// S46AE-26 wrong Basket; detects Basket correlation omission.
// S46AE-27 wrong request attempt; detects request correlation omission.
// S46AE-28 invalid inherited intent enum; detects pending-intent bypass.
// S46AE-29 real same-owner heartbeat; proves stable authority remains usable.
// S46AE-30 real takeover; proves stale prior-owner pending state is rejected.
// S46AE-31..41 mutate one otherwise-unrelated nested contract identity; each detects that exact missing version check.
// S46AE-42 coherently foreign V4-looking envelope; detects local-validity-only validation across the whole envelope.
void SWV5_RunSprint46ExecutionEnvelopeTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=42;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_PendingRequest pending;
      SWV5_TestMakePending(pending);
      SWV5_TransactionEvidence evidence;
      SWV5_TestMakeTransaction(pending,evidence);
      SWV5_TestExecutionContract execution;
      bool passed=false;
      string expected="fail_closed_without_mutation";

      if(number<=18)
      {
         SWV5_ExecutionIntent intent=pending.intent;
         if(number==2) intent.contract_version.schema_version--;
         if(number==3) SWV5_TestSetForeignContractIdentity(intent.contract_version);
         if(number==4) intent.ownership_fence.fencing_token_digest="";
         if(number==5)
         {
            intent.ownership_fence.ownership_namespace.server="FOREIGN-FENCE-SERVER";
            intent.ownership_fence.owner.key.server="FOREIGN-FENCE-SERVER";
         }
         if(number==6) intent.persistence_namespace.ownership_namespace.broker_identity="FOREIGN-BROKER";
         if(number==7) intent.persistence_namespace.ownership_namespace.server="FOREIGN-SERVER";
         if(number==8) intent.persistence_namespace.ownership_namespace.account_login++;
         if(number==9) intent.persistence_namespace.ownership_namespace.strategy_id="FOREIGN-STRATEGY";
         if(number==10) intent.persistence_namespace.ownership_namespace.symbol="FOREIGN-SYMBOL";
         if(number==11) intent.persistence_namespace.ownership_namespace.magic++;
         if(number==12) intent.intent_type=(SWV5_ExecutionIntentType)99;
         if(number==13) intent.direction=2;
         if(number==14) intent.intent_type=SWV5_INTENT_CANCEL_PENDING;
         if(number==15) intent.contract_version.policy_id="FOREIGN-POLICY";
         if(number==16) SWV5_TestSetForeignContractIdentity(intent.persistence_namespace.contract_version);
         if(number==17) SWV5_TestSetForeignContractIdentity(intent.request_identity.contract_version);
         if(number==18) context.expected_version.contract_name="FOREIGN-EXPECTED-CONTRACT";
         SWV5_ContractDecision decision;
         const bool accepted=execution.ValidateIntent(context,intent,decision);
         passed=(number==1 ? accepted && decision.disposition==SWV5_DISPOSITION_ALLOW :
                             !accepted && decision.disposition==SWV5_DISPOSITION_DENY);
         if(number==1) expected="canonical_intent_accepted";
         if(number==2) expected="wrong_intent_schema_rejected";
         if(number==3) expected="foreign_intent_contract_rejected";
         if(number==4) expected="incomplete_fence_rejected";
         if(number==5) expected="foreign_complete_fence_rejected";
         if(number==6) expected="wrong_broker_binding_rejected";
         if(number==7) expected="wrong_server_binding_rejected";
         if(number==8) expected="wrong_account_login_binding_rejected";
         if(number==9) expected="wrong_strategy_binding_rejected";
         if(number==10) expected="wrong_symbol_binding_rejected";
         if(number==11) expected="wrong_magic_binding_rejected";
         if(number==12) expected="invalid_intent_enum_rejected";
         if(number==13) expected="invalid_direction_rejected";
         if(number==14) expected="contradictory_cancel_terms_rejected";
         if(number==15) expected="foreign_policy_rejected";
         if(number==16) expected="foreign_namespace_contract_rejected";
         if(number==17) expected="foreign_request_contract_rejected";
         if(number==18) expected="foreign_expected_context_rejected";
      }
      else
      {
         if(number>=19 && number<=21)
            SWV5_TestMakeAcknowledgementTransaction(pending,evidence);
         if(number==20)
         {
            evidence.ownership_fence.ownership_namespace.server="FOREIGN-FENCE-SERVER";
            evidence.ownership_fence.owner.key.server="FOREIGN-FENCE-SERVER";
         }
         if(number==21) evidence.persistence_namespace.basket_id.value="FOREIGN-ACK-BASKET";
         if(number==23) evidence.contract_version.schema_version--;
         if(number==24)
         {
            evidence.persistence_namespace.ownership_namespace.server="FOREIGN-EVIDENCE-SERVER";
            evidence.ownership_fence.ownership_namespace.server="FOREIGN-EVIDENCE-SERVER";
            evidence.ownership_fence.owner.key.server="FOREIGN-EVIDENCE-SERVER";
         }
         if(number==25) evidence.ownership_fence.fencing_token_digest="STALE-OWNER-FENCE";
         if(number==26) evidence.persistence_namespace.basket_id.value="FOREIGN-BASKET";
         if(number==27) evidence.correlation.request_identity.request_id.attempt_id="FOREIGN-ATTEMPT";
         if(number==28) pending.intent.intent_type=(SWV5_ExecutionIntentType)99;
         if(number==31) SWV5_TestSetForeignContractIdentity(evidence.contract_version);
         if(number==32) SWV5_TestSetForeignContractIdentity(evidence.correlation.contract_version);
         if(number==33) SWV5_TestSetForeignContractIdentity(evidence.correlation.broker_identity.contract_version);
         if(number==34) SWV5_TestSetForeignContractIdentity(pending.contract_version);
         if(number==35) SWV5_TestSetForeignContractIdentity(pending.intent.contract_version);
         if(number==36) SWV5_TestSetForeignContractIdentity(pending.accepted_event_identities.contract_version);
         if(number==37) SWV5_TestSetForeignContractIdentity(pending.latest_authoritative_confirmation.contract_version);
         if(number==38) SWV5_TestSetForeignContractIdentity(pending.latest_submission.contract_version);
         if(number==39) SWV5_TestSetForeignContractIdentity(pending.latest_retcode.contract_version);
         if(number==40) SWV5_TestSetForeignContractIdentity(pending.latest_retcode_classification.contract_version);
         if(number==41) SWV5_TestSetForeignContractIdentity(pending.latest_retcode.correlation.contract_version);
         if(number==42)
         {
            SWV5_TestSetForeignContractIdentity(pending.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.intent.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.intent.persistence_namespace.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.intent.ownership_fence.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.intent.request_identity.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.latest_submission.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.latest_submission.request_identity.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.latest_retcode.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.latest_retcode.persistence_namespace.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.latest_retcode.ownership_fence.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.latest_retcode.correlation.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.latest_retcode.correlation.request_identity.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.latest_retcode.correlation.broker_identity.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.latest_retcode_classification.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.latest_retcode_classification.decision.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.latest_authoritative_confirmation.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.latest_authoritative_confirmation.correlation.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.latest_authoritative_confirmation.correlation.request_identity.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.latest_authoritative_confirmation.correlation.broker_identity.contract_version);
            SWV5_TestSetForeignContractIdentity(pending.accepted_event_identities.contract_version);
            SWV5_TestSetForeignContractIdentity(evidence.contract_version);
            SWV5_TestSetForeignContractIdentity(evidence.persistence_namespace.contract_version);
            SWV5_TestSetForeignContractIdentity(evidence.ownership_fence.contract_version);
            SWV5_TestSetForeignContractIdentity(evidence.correlation.contract_version);
            SWV5_TestSetForeignContractIdentity(evidence.correlation.request_identity.contract_version);
            SWV5_TestSetForeignContractIdentity(evidence.correlation.broker_identity.contract_version);
         }

         if(number==19)
         {
            SWV5_ExecutionConfirmation acknowledgement;
            const bool accepted=execution.AcceptTransactionEvidence(context,pending,evidence,acknowledgement);
            passed=accepted && acknowledgement.evidence_disposition==SWV5_TRANSACTION_EVIDENCE_ACKNOWLEDGEMENT_ONLY &&
                   acknowledgement.status==SWV5_CONFIRMATION_PENDING && !acknowledgement.event_identity_added &&
                   !acknowledgement.duplicate_event && SWV5_TestPendingRequestEqual(acknowledgement.resulting_pending_request,pending) &&
                   SWV5_TestNear(acknowledgement.confirmed_volume,pending.cumulative_confirmed_volume,context.volume_tolerance) &&
                   SWV5_TestNear(acknowledgement.residual_volume,pending.residual_requested_volume,context.volume_tolerance);
            expected="valid_acknowledgement_no_exposure_mutation";
         }
         else if(number==22)
         {
            SWV5_ExecutionConfirmation confirmation;
            const bool accepted=execution.AcceptTransactionEvidence(context,pending,evidence,confirmation);
            passed=accepted && confirmation.evidence_disposition==SWV5_TRANSACTION_EVIDENCE_AUTHORITATIVE_CONFIRMATION &&
                   confirmation.status==SWV5_CONFIRMATION_CONFIRMED && confirmation.event_identity_added &&
                   !confirmation.duplicate_event && confirmation.resulting_pending_request.state==SWV5_REQUEST_CONFIRMED &&
                   SWV5_TestNear(confirmation.resulting_pending_request.cumulative_confirmed_volume,0.10,context.volume_tolerance) &&
                   SWV5_TestNear(confirmation.resulting_pending_request.residual_requested_volume,0.0,context.volume_tolerance);
            expected="valid_authoritative_deal_confirms";
         }
         else if(number==29)
         {
            SWV5_InstanceLease lease;
            SWV5_TestMakeLease(lease);
            SWV5_TestOwnershipContract ownership;
            SWV5_OwnershipDecision heartbeat;
            SWV5_ExecutionConfirmation confirmation;
            const bool renewed=ownership.Heartbeat(context,lease,lease,heartbeat);
            const bool accepted=renewed && execution.AcceptTransactionEvidence(context,pending,evidence,confirmation);
            passed=accepted && SWV5_TestFenceEqual(lease.fence,heartbeat.resulting_lease.fence) &&
                   confirmation.status==SWV5_CONFIRMATION_CONFIRMED && confirmation.event_identity_added;
            expected="same_owner_heartbeat_preserves_execution_authority";
         }
         else if(number==30)
         {
            SWV5_InstanceLease observed;
            SWV5_OwnershipClaim claim;
            SWV5_TestMakeExpiredTakeoverFixture(context,observed,claim);
            SWV5_TestOwnershipContract ownership;
            SWV5_OwnershipDecision takeover;
            const bool acquired=ownership.Acquire(context,claim,observed,takeover);
            evidence.ownership_fence=takeover.resulting_lease.fence;
            passed=acquired && !SWV5_TestFenceEqual(pending.intent.ownership_fence,evidence.ownership_fence) &&
                   SWV5_TestExecutionRejectsWithoutMutation(execution,context,pending,evidence);
            expected="takeover_invalidates_stale_pending_owner";
         }
         else
         {
            passed=SWV5_TestExecutionRejectsWithoutMutation(execution,context,pending,evidence);
            if(number==20) expected="foreign_acknowledgement_fence_rejected";
            if(number==21) expected="foreign_acknowledgement_namespace_rejected";
            if(number==23) expected="wrong_transaction_schema_rejected";
            if(number==24) expected="coherent_foreign_transaction_namespace_rejected";
            if(number==25) expected="stale_owner_transaction_rejected";
            if(number==26) expected="wrong_basket_transaction_rejected";
            if(number==27) expected="wrong_request_transaction_rejected";
            if(number==28) expected="invalid_inherited_intent_rejected";
            if(number==31) expected="foreign_evidence_contract_rejected";
            if(number==32) expected="foreign_correlation_contract_rejected";
            if(number==33) expected="foreign_broker_identity_contract_rejected";
            if(number==34) expected="foreign_pending_contract_rejected";
            if(number==35) expected="foreign_pending_intent_contract_rejected";
            if(number==36) expected="foreign_durable_event_set_contract_rejected";
            if(number==37) expected="foreign_authoritative_state_contract_rejected";
            if(number==38) expected="foreign_submission_contract_rejected";
            if(number==39) expected="foreign_retcode_contract_rejected";
            if(number==40) expected="foreign_retcode_classification_contract_rejected";
            if(number==41) expected="foreign_retcode_correlation_contract_rejected";
            if(number==42) expected="coherent_foreign_v4_envelope_rejected";
         }
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S46AE",number),"SPRINT4_6_EXECUTION_ENVELOPE",passed,expected);
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
                   result.resulting_state_version==snapshot.state_version+1 && result.recovery_evidence_added &&
                   result.resulting_accepted_recovery_evidence.accepted_identity_count==snapshot.accepted_recovery_evidence.accepted_identity_count+1;
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
            SWV5_BasketTransitionDecision first,replay;
            const bool first_ok=basket_state.ValidateTransition(context,snapshot,request,first);
            SWV5_BasketLifecycleSnapshot restored=snapshot;
            restored.state=first.resulting_state;
            restored.state_version=first.resulting_state_version;
            restored.cumulative_recovery_attempts=first.resulting_cumulative_recovery_attempts;
            restored.current_recovery_layer=first.resulting_recovery_layer;
            restored.accepted_recovery_evidence=first.resulting_accepted_recovery_evidence;
            passed=first_ok && basket_state.ValidateTransition(context,restored,request,replay) && replay.recovery_evidence_duplicate &&
                   replay.resulting_state_version==restored.state_version &&
                   replay.resulting_cumulative_recovery_attempts==restored.cumulative_recovery_attempts &&
                   SWV5_TestEventIdentitySetEqual(replay.resulting_accepted_recovery_evidence,restored.accepted_recovery_evidence);
            expected="duplicate_recovery_evidence_idempotent";
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
            passed=SWV5_TestInterfaceRestart(persistence,context,restart,readiness)==SWV5_RECONCILIATION_CORRUPT_HALT &&
                   readiness==SWV5_RESTART_HALTED;
            expected="unsealed_uncertain_request_corrupt_halt";
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
            if(number==9)
            {
               passed=evaluated && risk.ValidateAuthorization(context,authorization,engineInput,decision) &&
                      authorization.authorization_id==engineInput.intent.risk_authorization_id &&
                      authorization.limits_contract_id==engineInput.limits.contract_id &&
                      authorization.authorized_limits.contract_id==engineInput.limits.contract_id &&
                      SWV5_TestAccountNamespaceEqual(authorization.account_namespace,engineInput.account_namespace,true) &&
                      authorization.risk_snapshot_epoch==engineInput.account_namespace.snapshot_epoch &&
                      authorization.risk_snapshot_sequence==engineInput.account_namespace.snapshot_sequence &&
                      authorization.basket_state_version==engineInput.intent.expected_basket_version &&
                      authorization.symbol_specification_sequence==engineInput.intent.symbol_specification_sequence &&
                      authorization.authorized_volume==engineInput.intent.normalized_volume &&
                      authorization.hard_kill_latch_generation==engineInput.hard_kill_state.latch_generation &&
                      authorization.authorized_projected_loss==engineInput.projected.projected_maximum_loss &&
                      SWV5_TestMonetaryBasisComplete(authorization.monetary_basis);
            }
            else
               passed=!evaluated && authorization.disposition==SWV5_RISK_RECONCILIATION_REQUIRED;
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
            SWV5_RiskEvaluationInput risk_input;
            SWV5_TestMakeRiskInput(risk_input);
            SWV5_RiskAuthorization authorization;
            const bool evaluated=risk.Evaluate(context,risk_input,authorization);
            authorization.account_mode=SWV5_ACCOUNT_MODE_NETTING;
            passed=evaluated && !risk.ValidateAuthorization(context,authorization,risk_input,decision);
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
            if(number==15) { SWV5_TestMakeStopUnitRequest(request,1); request.operation_price=request.market_bid; }
            if(number==16) { request.intent_type=SWV5_INTENT_INCREASE; request.current_exposure_volume=0.10; request.target_exposure_volume=0.115; }
            if(number==17) SWV5_TestMakeCloseUnitRequest(request,0.005);
            if(number==18) specification.valid_until=context.clock_time-1;
            SWV5_NormalizedUnits normalized;
            SWV5_UnitValidationResult result;
            const bool normalized_ok=units.Normalize(context,specification,request,normalized,result);
            if(number==14 || number==15 || number==18) passed=!normalized_ok;
            else if(number==16) passed=normalized_ok && normalized.applied_volume_rounding==SWV5_NORMALIZE_DOWN && SWV5_TestNear(normalized.volume,0.01,context.volume_tolerance);
            else passed=normalized_ok && normalized.derived_operation_semantic==SWV5_UNIT_OPERATION_RESIDUAL_CLOSE &&
                        normalized.applied_volume_rounding==SWV5_NORMALIZE_NEAREST && SWV5_TestNear(normalized.volume,0.005,context.volume_tolerance);
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
            if(number==20) claim.takeover_evidence.lease_expiry.observed_store_revision="STALE-NESTED-REVISION";
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
               evidence.confirmed_volume=0.04;
               SWV5_ExecutionConfirmation first;
               const bool first_ok=execution.AcceptTransactionEvidence(context,pending,evidence,first);
               SWV5_TransactionEvidence newer;
               SWV5_TestMakeTransaction(first.resulting_pending_request,newer,0.06);
               newer.correlation.broker_identity.broker_event_id="EVENT-NEWER";
               newer.correlation.broker_identity.transaction_sequence=500;
               SWV5_ExecutionConfirmation second,replay;
               const bool second_ok=execution.AcceptTransactionEvidence(context,first.resulting_pending_request,newer,second);
               const bool replay_ok=execution.AcceptTransactionEvidence(context,second.resulting_pending_request,evidence,replay);
               passed=first_ok && second_ok && replay_ok && replay.duplicate_event && !replay.event_identity_added &&
                      SWV5_TestPendingRequestEqual(replay.resulting_pending_request,second.resulting_pending_request) &&
                      replay.resulting_pending_request.accepted_event_identities.accepted_identity_count==2;
            }
            else if(number==25)
            {
               evidence.confirmed_volume=0.04;
               evidence.correlation.broker_identity.broker_event_id="EVENT-NEWER";
               evidence.correlation.broker_identity.transaction_sequence=500;
               SWV5_ExecutionConfirmation first,second;
               const bool first_ok=execution.AcceptTransactionEvidence(context,pending,evidence,first);
               SWV5_TransactionEvidence older;
               SWV5_TestMakeTransaction(first.resulting_pending_request,older,0.06);
               older.correlation.broker_identity.broker_event_id="EVENT-OLDER-UNSEEN";
               older.correlation.broker_identity.transaction_sequence=499;
               const bool second_ok=execution.AcceptTransactionEvidence(context,first.resulting_pending_request,older,second);
               passed=first_ok && second_ok && second.event_identity_added &&
                      second.resulting_pending_request.state==SWV5_REQUEST_CONFIRMED &&
                      second.resulting_pending_request.accepted_event_identities.accepted_identity_count==2 &&
                      second.resulting_pending_request.accepted_event_identities.highest_transaction_sequence==500;
            }
            else if(number==26)
            {
               pending.state=SWV5_REQUEST_ACKNOWLEDGED;
               pending.lifecycle_phase=SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT;
               SWV5_TestMakeAcknowledgementTransaction(pending,evidence);
               SWV5_ExecutionConfirmation acknowledgement;
               passed=execution.AcceptTransactionEvidence(context,pending,evidence,acknowledgement) &&
                      acknowledgement.evidence_disposition==SWV5_TRANSACTION_EVIDENCE_ACKNOWLEDGEMENT_ONLY &&
                      acknowledgement.status==SWV5_CONFIRMATION_PENDING && !acknowledgement.event_identity_added &&
                      SWV5_TestPendingRequestEqual(acknowledgement.resulting_pending_request,pending);
            }
            else
            {
               SWV5_ExecutionConfirmation partial;
               passed=execution.AcceptTransactionEvidence(context,pending,evidence,partial) &&
                      partial.status==SWV5_CONFIRMATION_PARTIAL && partial.event_identity_added &&
                      partial.resulting_pending_request.state==SWV5_REQUEST_PARTIALLY_CONFIRMED &&
                      SWV5_TestNear(partial.resulting_pending_request.residual_requested_volume,0.06,context.volume_tolerance);
            }
            expected=(number==24 ? "replayed_A_after_B_is_duplicate" : (number==25 ? "out_of_order_unseen_accepted_once" : (number==26 ? "ack_not_confirmation" : "partial_fill_residual")));
            break;
         }
         case 28:
         {
            SWV5_RestartReconciliationInput restart;
            SWV5_TestMakeRestartInput(restart);
            SWV5_PersistedRequestEvidence pending_requests[];
            ArrayResize(pending_requests,1);
            SWV5_TestMakePersistedRequest(pending_requests[0],1);
            pending_requests[0].account_mode=SWV5_ACCOUNT_MODE_NETTING;
            SWV5_TestBindRequestSetHeader(restart.persisted.pending_request_set,pending_requests,30);
            restart.persisted.has_latest_pending_request=true;
            restart.persisted.latest_pending_request=pending_requests[0];
            restart.broker.pending_request_count=1;
            SWV5_TestSealCheckpoint(restart.persisted);
            SWV5_RestartReadinessDisposition readiness;
            SWV5_TestSealCheckpoint(restart.persisted);
            passed=SWV5_TestInterfaceRestart(persistence,context,restart,pending_requests,readiness)==SWV5_RECONCILIATION_CORRUPT_HALT &&
                   readiness==SWV5_RESTART_HALTED;
            expected="persisted_mode_mismatch_corrupt_halt";
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
            deal.correlation=evidence.correlation;
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
            expected="valid_idle_state_reported";
            break;
         }
         case 32:
         {
            SWV5_PendingRequest pending;
            SWV5_TestMakeRetryCandidate(pending);
            SWV5_RetryPolicy policy;
            SWV5_TestMakeRetryPolicy(context,policy);
            SWV5_RetryRiskFreshnessEvidence risk_evidence;
            SWV5_TestMakeRetryRiskEvidence(context,pending,risk_evidence);
            SWV5_RetryNormalizationFreshnessEvidence normalization_evidence;
            SWV5_TestMakeRetryNormalizationEvidence(context,pending,normalization_evidence);
            passed=execution.EvaluateRetry(context,pending,policy,risk_evidence,normalization_evidence,decision) &&
                   decision.disposition==SWV5_DISPOSITION_ALLOW;
            expected="retry_after_revalidation_allowed";
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
                expected="load_latest_restores_checkpoint";
            }
            else
            {
               SWV5_PersistedRequestEvidence loaded_requests[];
               passed=persistence.LoadPendingRequests(context,checkpoint.header.persistence_namespace,loaded_requests,result) &&
                      ArraySize(loaded_requests)==0;
                expected="load_pending_restores_empty_set";
            }
            break;
         }
         case 35:
         {
            SWV5_PersistedCheckpoint checkpoint;
            SWV5_TestMakeCheckpoint(checkpoint);
            SWV5_PersistedRequestEvidence requests[];
            ArrayResize(requests,0);
            SWV5_PersistedRequestEvidence loaded[];
            SWV5_PersistenceLoadResult load_result;
            passed=persistence.SavePendingRequests(context,checkpoint.header.persistence_namespace,requests,checkpoint.pending_request_set,decision) &&
                   persistence.LoadPendingRequests(context,checkpoint.header.persistence_namespace,loaded,load_result) &&
                   ArraySize(loaded)==0 && load_result.status==SWV5_PERSISTENCE_LOADED;
            expected="save_empty_pending_set_loads_empty";
            break;
         }
         case 36:
         {
            SWV5_PersistedCheckpoint checkpoint;
            SWV5_TestMakeCheckpoint(checkpoint);
            SWV5_PersistedCheckpoint expected_checkpoint=checkpoint;
            const bool saved=persistence.SaveCheckpoint(context,checkpoint,decision);
            checkpoint.header.payload_digest="CALLER-MUTATED-AFTER-SAVE";
            checkpoint.basket.lifecycle.basket_id.value="CALLER-MUTATED-BASKET";
            checkpoint.clean_shutdown=!checkpoint.clean_shutdown;
            SWV5_PersistedCheckpoint loaded;
            SWV5_PersistenceLoadResult load_result;
            passed=saved && persistence.LoadLatest(context,expected_checkpoint.header.persistence_namespace,loaded,load_result) &&
                   loaded.header.payload_digest==expected_checkpoint.header.payload_digest &&
                   loaded.header.record_sequence==expected_checkpoint.header.record_sequence &&
                   SWV5_TestNamespaceEqual(loaded.header.persistence_namespace,expected_checkpoint.header.persistence_namespace) &&
                   SWV5_TestFenceEqual(loaded.header.ownership_fence,expected_checkpoint.header.ownership_fence) &&
                   loaded.basket.lifecycle.basket_id.value==expected_checkpoint.basket.lifecycle.basket_id.value &&
                   loaded.basket.lifecycle.state==expected_checkpoint.basket.lifecycle.state &&
                   loaded.basket.lifecycle.state_version==expected_checkpoint.basket.lifecycle.state_version &&
                   loaded.hard_kill_state.latch_id==expected_checkpoint.hard_kill_state.latch_id &&
                   loaded.clean_shutdown==expected_checkpoint.clean_shutdown;
            expected="checkpoint_save_load_deep_copy_observable_fields";
            break;
         }
         case 37:
         {
            SWV5_RiskEvaluationInput risk_input;
            SWV5_TestMakeRiskInput(risk_input);
            passed=risk.ValidateLimits(context,risk_input.limits,decision);
            expected="complete_valid_limits_accepted";
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
            expected="complete_statistics_finalize_valid";
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
            passed=ownership.Heartbeat(context,lease,lease,heartbeat) &&
                   heartbeat.resulting_lease.status==SWV5_LOCK_RENEWED &&
                   heartbeat.resulting_lease.heartbeat_sequence==lease.heartbeat_sequence+1 &&
                   heartbeat.resulting_lease.heartbeat_clock_sequence==context.clock_sequence &&
                   heartbeat.resulting_lease.heartbeat_at==context.clock_time &&
                   heartbeat.resulting_lease.expires_at>lease.expires_at &&
                   ownership.DetectConflict(context,claim,lease,conflict) && conflict.status==SWV5_LOCK_CONFLICT;
            expected="heartbeat_renews_and_conflict_detects";
            break;
         }
         case 40:
         {
            SWV5_InstanceLease lease;
            SWV5_TestMakeLease(lease);
            SWV5_OwnershipDecision result;
            passed=ownership.Release(context,lease,lease,result) && result.resulting_lease.status==SWV5_LOCK_RELEASED;
            expected="matching_owner_release_transitions_state";
            break;
         }
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("IFC",number),"INTERFACE_CORRECTION",passed,expected);
   }
}

void SWV5_RunPersistenceRoundTripTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=11;number++)
   {
      if(!SWV5_TestIdSelected(SWV5_TestCaseId("PRT",number))) continue;
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_TestPersistenceContract persistence;
      SWV5_ContractDecision decision;
      SWV5_PersistenceLoadResult result;
      bool passed=false;
      string expected="fail_closed";
      switch(number)
      {
         case 1:
         {
            SWV5_PersistedCheckpoint checkpoint;
            SWV5_TestMakeCheckpoint(checkpoint);
            SWV5_PersistedRequestEvidence configured[];
            ArrayResize(configured,1);
            SWV5_TestMakePersistedRequest(configured[0],1);
            SWV5_PersistedRequestEvidence expected_record=configured[0];
            SWV5_TestBindRequestSetHeader(checkpoint.pending_request_set,configured,31);
            checkpoint.has_latest_pending_request=true;
            checkpoint.latest_pending_request=configured[0];
            SWV5_TestRefreshCheckpointVector(checkpoint);
            SWV5_TestSealCheckpoint(checkpoint);
            persistence.Configure(checkpoint,configured);
            configured[0].pending_request.intent.request_identity.request_id.correlation_id="CALLER-MUTATED";
            SWV5_PersistedRequestEvidence loaded[];
            passed=persistence.LoadPendingRequests(context,checkpoint.header.persistence_namespace,loaded,result) &&
                   ArraySize(loaded)==1 && SWV5_TestPersistedRequestEqual(expected_record,loaded[0]);
            expected="configure_load_field_equal";
            break;
         }
         case 2:
         {
            SWV5_PersistedRequestEvidence saved[];
            ArrayResize(saved,1);
            SWV5_TestMakePersistedRequest(saved[0],2);
            SWV5_PersistedRequestSetHeader header;
            SWV5_TestBindRequestSetHeader(header,saved,32);
            SWV5_PersistedRequestEvidence loaded[];
            ArrayResize(loaded,2);
            ArrayResize(loaded,0);
            passed=persistence.SavePendingRequests(context,saved[0].persistence_namespace,saved,header,decision) &&
                   persistence.LoadPendingRequests(context,saved[0].persistence_namespace,loaded,result) &&
                   ArraySize(loaded)==1 && SWV5_TestPersistedRequestEqual(saved[0],loaded[0]);
            expected="save_clear_load_field_equal";
            break;
         }
         case 3:
         {
            SWV5_PersistedRequestEvidence saved[];
            ArrayResize(saved,3);
            for(int index=0;index<3;index++) SWV5_TestMakePersistedRequest(saved[index],index+3);
            SWV5_PersistedRequestSetHeader header;
            SWV5_TestBindRequestSetHeader(header,saved,33);
            SWV5_PersistedRequestEvidence loaded[];
            bool ordered=persistence.SavePendingRequests(context,saved[0].persistence_namespace,saved,header,decision) &&
                         persistence.LoadPendingRequests(context,saved[0].persistence_namespace,loaded,result) && ArraySize(loaded)==3;
            for(int index=0;ordered && index<3;index++) ordered=SWV5_TestPersistedRequestEqual(saved[index],loaded[index]);
            passed=ordered;
            expected="multiple_records_order_and_content";
            break;
         }
         case 4:
         {
            SWV5_PersistedRequestEvidence saved[];
            ArrayResize(saved,1);
            SWV5_TestMakePersistedRequest(saved[0],6);
            saved[0].pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_PARTIAL_FILL;
            saved[0].pending_request.state=SWV5_REQUEST_PARTIALLY_CONFIRMED;
            saved[0].pending_request.cumulative_confirmed_volume=0.04;
            saved[0].pending_request.residual_requested_volume=0.06;
            saved[0].pending_request.latest_authoritative_confirmation.correlation.phase=SWV5_EXECUTION_PHASE_PARTIAL_FILL;
            saved[0].pending_request.latest_authoritative_confirmation.correlation.broker_identity.broker_event_id="EVENT-PARTIAL-0001";
            saved[0].pending_request.latest_authoritative_confirmation.correlation.broker_identity.transaction_sequence=401;
            saved[0].pending_request.latest_authoritative_confirmation.status=SWV5_CONFIRMATION_PARTIAL;
            saved[0].pending_request.latest_authoritative_confirmation.cumulative_confirmed_volume=0.04;
            saved[0].pending_request.latest_authoritative_confirmation.residual_volume=0.06;
            saved[0].pending_request.latest_authoritative_confirmation.authority=SWV5_AUTHORITY_TRANSACTION_EVENT;
            saved[0].pending_request.latest_authoritative_confirmation.confirmation_sequence=401;
            saved[0].pending_request.latest_authoritative_confirmation.confirmed_at=SWV5_TEST_TIME;
            SWV5_TestMakeEventIdentitySet(saved[0].pending_request.accepted_event_identities,true,SWV5_DURABLE_FINGERPRINT_REQUIRED);
            SWV5_PersistedRequestSetHeader header;
            SWV5_TestBindRequestSetHeader(header,saved,34);
            SWV5_PersistedRequestEvidence loaded[];
            passed=persistence.SavePendingRequests(context,saved[0].persistence_namespace,saved,header,decision) &&
                   persistence.LoadPendingRequests(context,saved[0].persistence_namespace,loaded,result) && ArraySize(loaded)==1 &&
                   SWV5_TestPersistedRequestEqual(saved[0],loaded[0]) &&
                   loaded[0].pending_request.cumulative_confirmed_volume==0.04 &&
                   loaded[0].pending_request.residual_requested_volume==0.06 &&
                   loaded[0].pending_request.latest_authoritative_confirmation.status==SWV5_CONFIRMATION_PARTIAL &&
                   loaded[0].pending_request.accepted_event_identities.accepted_identity_count==1;
            expected="partial_fill_payload_preserved";
            break;
         }
         case 5:
         {
            SWV5_PersistedRequestEvidence saved[];
            ArrayResize(saved,1);
            SWV5_TestMakePersistedRequest(saved[0],7);
            saved[0].pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_UNCERTAIN;
            saved[0].pending_request.state=SWV5_REQUEST_RECONCILIATION_REQUIRED;
            saved[0].pending_request.retry_disposition=SWV5_RETRY_REQUIRES_RECONCILIATION;
            SWV5_PersistedRequestSetHeader header;
            SWV5_TestBindRequestSetHeader(header,saved,35);
            SWV5_PersistedRequestEvidence loaded[];
            passed=persistence.SavePendingRequests(context,saved[0].persistence_namespace,saved,header,decision) &&
                   persistence.LoadPendingRequests(context,saved[0].persistence_namespace,loaded,result) && ArraySize(loaded)==1 &&
                   SWV5_TestPersistedRequestEqual(saved[0],loaded[0]) &&
                   loaded[0].pending_request.lifecycle_phase==SWV5_EXECUTION_PHASE_UNCERTAIN &&
                   loaded[0].pending_request.state==SWV5_REQUEST_RECONCILIATION_REQUIRED &&
                   loaded[0].pending_request.retry_disposition==SWV5_RETRY_REQUIRES_RECONCILIATION;
            expected="uncertain_reconciliation_payload_preserved";
            break;
         }
         case 6:
         {
            SWV5_PersistedRequestEvidence saved[];
            ArrayResize(saved,1);
            SWV5_TestMakePersistedRequest(saved[0],8);
            SWV5_PersistedRequestSetHeader header;
            SWV5_TestBindRequestSetHeader(header,saved,36);
            SWV5_PersistenceNamespace foreign=saved[0].persistence_namespace;
            foreign.ownership_namespace.server="FOREIGN-SERVER";
            SWV5_PersistedRequestEvidence loaded[];
            ArrayResize(loaded,1);
            passed=persistence.SavePendingRequests(context,saved[0].persistence_namespace,saved,header,decision) &&
                   !persistence.LoadPendingRequests(context,foreign,loaded,result) && ArraySize(loaded)==0 &&
                   result.status==SWV5_PERSISTENCE_OWNER_CONFLICT;
            expected="foreign_namespace_rejected";
            break;
         }
         case 7:
         {
            SWV5_PersistedCheckpoint checkpoint;
            SWV5_TestMakeCheckpoint(checkpoint);
            SWV5_PersistedRequestEvidence configured[];
            ArrayResize(configured,1);
            SWV5_TestMakePersistedRequest(configured[0],9);
            SWV5_TestBindRequestSetHeader(checkpoint.pending_request_set,configured,37);
            checkpoint.pending_request_set.request_count=2;
            checkpoint.has_latest_pending_request=true;
            checkpoint.latest_pending_request=configured[0];
            persistence.Configure(checkpoint,configured);
            SWV5_PersistedRequestEvidence loaded[];
            const bool configured_rejected=!persistence.LoadPendingRequests(context,checkpoint.header.persistence_namespace,loaded,result) && ArraySize(loaded)==0;
            SWV5_PersistedRequestSetHeader mismatched=checkpoint.pending_request_set;
            const bool save_rejected=!persistence.SavePendingRequests(context,configured[0].persistence_namespace,configured,mismatched,decision);
            passed=configured_rejected && save_rejected;
            expected="count_header_mismatch_rejected";
            break;
         }
         case 8:
         {
            SWV5_PersistedRequestEvidence saved[];
            ArrayResize(saved,1);
            SWV5_TestMakePersistedRequest(saved[0],10);
            SWV5_PersistedRequestSetHeader missing_digest;
            SWV5_TestBindRequestSetHeader(missing_digest,saved,38);
            missing_digest.request_set_digest="";
            SWV5_PersistedRequestSetHeader missing_revision;
            SWV5_TestBindRequestSetHeader(missing_revision,saved,38);
            missing_revision.request_index_revision="";
            passed=!persistence.SavePendingRequests(context,saved[0].persistence_namespace,saved,missing_digest,decision) &&
                   !persistence.SavePendingRequests(context,saved[0].persistence_namespace,saved,missing_revision,decision);
            expected="missing_digest_and_revision_rejected";
            break;
         }
         case 9:
         {
            SWV5_PersistedRequestEvidence saved[];
            ArrayResize(saved,2);
            SWV5_TestMakePersistedRequest(saved[0],11);
            SWV5_TestMakePersistedRequest(saved[1],12);
            SWV5_PersistedRequestSetHeader header;
            SWV5_TestBindRequestSetHeader(header,saved,39);
            SWV5_PersistedRequestEvidence first[];
            SWV5_PersistedRequestEvidence second[];
            bool same=persistence.SavePendingRequests(context,saved[0].persistence_namespace,saved,header,decision) &&
                      persistence.LoadPendingRequests(context,saved[0].persistence_namespace,first,result) &&
                      persistence.LoadPendingRequests(context,saved[0].persistence_namespace,second,result) &&
                      ArraySize(first)==2 && ArraySize(second)==2;
            for(int index=0;same && index<2;index++)
               same=SWV5_TestPersistedRequestEqual(first[index],second[index]) && SWV5_TestPersistedRequestEqual(saved[index],second[index]);
            passed=same;
            expected="repeat_load_deterministic";
            break;
         }
         case 10:
         {
            SWV5_PersistedRequestEvidence saved[];
            ArrayResize(saved,1);
            SWV5_TestMakePersistedRequest(saved[0],13);
            SWV5_PersistedRequestEvidence immutable=saved[0];
            SWV5_PersistedRequestSetHeader header;
            SWV5_TestBindRequestSetHeader(header,saved,40);
            const bool stored=persistence.SavePendingRequests(context,saved[0].persistence_namespace,saved,header,decision);
            saved[0].pending_request.intent.request_identity.idempotency_key="MUTATED-AFTER-SAVE";
            saved[0].pending_request.cumulative_confirmed_volume=99.0;
            saved[0].record_sequence=999;
            header.request_set_digest="MUTATED-HEADER";
            SWV5_PersistedRequestEvidence loaded[];
            passed=stored && persistence.LoadPendingRequests(context,immutable.persistence_namespace,loaded,result) &&
                   ArraySize(loaded)==1 && SWV5_TestPersistedRequestEqual(immutable,loaded[0]);
            expected="save_deep_copy_isolated_from_caller";
            break;
         }
         case 11:
         {
            SWV5_PersistenceNamespace persistence_namespace;
            SWV5_TestMakeNamespace(persistence_namespace);
            SWV5_PersistedRequestEvidence loaded[];
            ArrayResize(loaded,1);
            passed=!persistence.LoadPendingRequests(context,persistence_namespace,loaded,result) &&
                   ArraySize(loaded)==0 && result.status==SWV5_PERSISTENCE_TRUNCATED;
            expected="unconfigured_storage_rejected";
            break;
         }
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("PRT",number),"PERSISTENCE_ROUND_TRIP",passed,expected);
   }
}

bool SWV5_TestS4421HeartbeatSemantic()
{
   SWV5_ContractValidationContext context;
   SWV5_TestMakeContext(context);
   SWV5_InstanceLease observed;
   SWV5_TestMakeLease(observed);
   SWV5_TestOwnershipContract ownership;
   SWV5_OwnershipDecision first,second,third;
   SWV5_ContractValidationContext context1=context;
   context1.clock_sequence+=10;
   context1.clock_time+=10;
   const bool first_ok=ownership.Heartbeat(context1,observed,observed,first);
   SWV5_ContractValidationContext context2=context1;
   context2.clock_sequence+=10;
   context2.clock_time+=10;
   const bool second_ok=first_ok && ownership.Heartbeat(context2,first.resulting_lease,first.resulting_lease,second);
   SWV5_ContractValidationContext context3=context2;
   context3.clock_sequence+=10;
   context3.clock_time+=10;
   const bool third_ok=second_ok && ownership.Heartbeat(context3,second.resulting_lease,second.resulting_lease,third);
   return first_ok && second_ok && third_ok &&
          first.resulting_lease.status==SWV5_LOCK_RENEWED &&
          second.resulting_lease.status==SWV5_LOCK_RENEWED && third.resulting_lease.status==SWV5_LOCK_RENEWED &&
          SWV5_TestFenceEqual(first.resulting_lease.fence,observed.fence) &&
          SWV5_TestFenceEqual(second.resulting_lease.fence,first.resulting_lease.fence) &&
          SWV5_TestFenceEqual(third.resulting_lease.fence,second.resulting_lease.fence) &&
          first.resulting_lease.store_revision!=observed.store_revision &&
          second.resulting_lease.store_revision!=first.resulting_lease.store_revision &&
          third.resulting_lease.store_revision!=second.resulting_lease.store_revision &&
          first.resulting_lease.heartbeat_sequence==observed.heartbeat_sequence+1 &&
          second.resulting_lease.heartbeat_sequence==first.resulting_lease.heartbeat_sequence+1 &&
          third.resulting_lease.heartbeat_sequence==second.resulting_lease.heartbeat_sequence+1 &&
          first.resulting_lease.heartbeat_clock_sequence==context1.clock_sequence &&
          second.resulting_lease.heartbeat_clock_sequence==context2.clock_sequence &&
          third.resulting_lease.heartbeat_clock_sequence==context3.clock_sequence &&
          first.resulting_lease.heartbeat_at==context1.clock_time &&
          second.resulting_lease.heartbeat_at==context2.clock_time && third.resulting_lease.heartbeat_at==context3.clock_time &&
          first.resulting_lease.expiry_clock_sequence>observed.expiry_clock_sequence &&
          second.resulting_lease.expiry_clock_sequence>first.resulting_lease.expiry_clock_sequence &&
          third.resulting_lease.expiry_clock_sequence>second.resulting_lease.expiry_clock_sequence &&
          first.resulting_lease.expires_at>observed.expires_at &&
          second.resulting_lease.expires_at>first.resulting_lease.expires_at &&
          third.resulting_lease.expires_at>second.resulting_lease.expires_at &&
          third.resulting_lease.acquired_at==observed.acquired_at &&
          third.resulting_lease.acquired_clock_sequence==observed.acquired_clock_sequence;
}

void SWV5_RunSprint44SemanticTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=25;number++)
   {
      if(!SWV5_TestIdSelected(SWV5_TestCaseId("S44",number))) continue;
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_TestPersistenceContract persistence;
      SWV5_TestRiskContract risk;
      SWV5_TestBasketStateContract basket_state;
      SWV5_TestExecutionContract execution;
      SWV5_TestStatisticsContract statistics;
      SWV5_TestOwnershipContract ownership;
      bool passed=false;
      string expected="semantic_fail_closed";
      switch(number)
      {
         case 1:
         {
            SWV5_RestartReconciliationInput restart;
            SWV5_TestMakeRestartInput(restart);
            SWV5_PersistedRequestEvidence requests[];
            ArrayResize(requests,0);
            SWV5_RestartReadinessDisposition readiness;
            passed=SWV5_TestInterfaceRestart(persistence,context,restart,requests,readiness)==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED && readiness==SWV5_RESTART_SAFE_TO_RESUME;
            expected="complete_empty_set_safe";
            break;
         }
         case 2:
         {
            SWV5_RestartReconciliationInput restart;
            SWV5_TestMakeRestartInput(restart);
            SWV5_PersistedRequestEvidence requests[];
            ArrayResize(requests,2);
            SWV5_TestMakePersistedRequest(requests[0],1);
            SWV5_TestMakePersistedRequest(requests[1],2);
            requests[0].pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_UNCERTAIN;
            requests[0].pending_request.state=SWV5_REQUEST_RECONCILIATION_REQUIRED;
            requests[0].pending_request.retry_disposition=SWV5_RETRY_REQUIRES_RECONCILIATION;
            SWV5_TestBindCheckpointRequests(restart,requests,50);
            SWV5_RestartReadinessDisposition readiness;
            passed=SWV5_TestInterfaceRestart(persistence,context,restart,requests,readiness)==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED && readiness==SWV5_RESTART_RECONCILIATION_REQUIRED;
            expected="multi_request_uncertain_reconcile";
            break;
         }
         case 3:
         {
            SWV5_RestartReconciliationInput restart;
            SWV5_TestMakeRestartInput(restart);
            SWV5_PersistedRequestEvidence requests[];
            ArrayResize(requests,1);
            SWV5_TestMakePersistedRequest(requests[0],1);
            requests[0].pending_request.state=SWV5_REQUEST_CONFIRMATION_PENDING;
            requests[0].pending_request.retry_disposition=SWV5_RETRY_FORBIDDEN;
            SWV5_TestBindCheckpointRequests(restart,requests,50);
            SWV5_RestartReadinessDisposition readiness;
            passed=SWV5_TestInterfaceRestart(persistence,context,restart,requests,readiness)==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED && readiness==SWV5_RESTART_RETRY_FORBIDDEN;
            expected="pending_retry_forbidden";
            break;
         }
         case 4:
         {
            SWV5_RestartReconciliationInput restart;
            SWV5_TestMakeRestartInput(restart);
            SWV5_TestMakeHardKill(restart.persisted.hard_kill_state,SWV5_HARD_KILL_ACTIVE);
            SWV5_TestSealCheckpoint(restart.persisted);
            SWV5_PersistedRequestEvidence requests[];
            ArrayResize(requests,0);
            SWV5_RestartReadinessDisposition readiness;
            passed=SWV5_TestInterfaceRestart(persistence,context,restart,requests,readiness)==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED && readiness==SWV5_RESTART_CLOSE_ONLY;
            expected="hard_kill_close_only";
            break;
         }
         case 5:
         {
            SWV5_RestartReconciliationInput restart;
            SWV5_TestMakeRestartInput(restart);
            SWV5_PersistedRequestEvidence requests[];
            ArrayResize(requests,1);
            SWV5_TestMakePersistedRequest(requests[0],1);
            requests[0].pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_PARTIAL_FILL;
            requests[0].pending_request.state=SWV5_REQUEST_PARTIALLY_CONFIRMED;
            requests[0].pending_request.cumulative_confirmed_volume=0.04;
            requests[0].pending_request.residual_requested_volume=0.05;
            SWV5_TestBindRequestSetHeader(restart.persisted.pending_request_set,requests,50);
            restart.persisted.has_latest_pending_request=true;
            restart.persisted.latest_pending_request=requests[0];
            restart.broker.pending_request_count=1;
            SWV5_RestartReadinessDisposition readiness;
            SWV5_TestSealCheckpoint(restart.persisted);
            passed=SWV5_TestInterfaceRestart(persistence,context,restart,requests,readiness)==SWV5_RECONCILIATION_CORRUPT_HALT && readiness==SWV5_RESTART_HALTED;
            expected="partial_residual_semantic_corruption_halts";
            break;
         }
         case 6:
         case 7:
         case 8:
         case 9:
         {
            SWV5_PersistedRequestEvidence requests[];
            ArrayResize(requests,2);
            SWV5_TestMakePersistedRequest(requests[0],1);
            SWV5_TestMakePersistedRequest(requests[1],2);
            SWV5_PersistedRequestSetHeader header;
            SWV5_TestBindRequestSetHeader(header,requests,50);
            if(number==6) requests[1].pending_request.intent.normalized_stop_price-=1.0;
            if(number==7) { SWV5_PersistedRequestEvidence swap=requests[0]; requests[0]=requests[1]; requests[1]=swap; }
            if(number==8) header.request_index_revision="STALE-REVISION";
            if(number==9) header.request_set_digest=SWV5_TestCanonicalHash("OTHER-PAYLOAD");
            SWV5_ContractDecision decision;
            passed=!persistence.SavePendingRequests(context,requests[0].persistence_namespace,requests,header,decision);
            expected=(number==6 ? "nested_mutation_breaks_digest" : (number==7 ? "reorder_breaks_digest" : (number==8 ? "stale_revision_rejected" : "copied_digest_rejected")));
            break;
         }
         case 10:
         case 11:
         {
            SWV5_PersistedCheckpoint checkpoint;
            SWV5_TestMakeCheckpoint(checkpoint);
            SWV5_PersistedRequestEvidence empty[];
            ArrayResize(empty,0);
            persistence.Configure(checkpoint,empty);
            SWV5_PersistedRequestEvidence requests[];
            ArrayResize(requests,2);
            SWV5_TestMakePersistedRequest(requests[0],1);
            SWV5_TestMakePersistedRequest(requests[1],2);
            SWV5_PersistedRequestSetHeader header;
            SWV5_TestBindRequestSetHeader(header,requests,50);
            SWV5_ContractDecision decision;
            bool stored=persistence.SavePendingRequests(context,checkpoint.header.persistence_namespace,requests,header,decision);
            if(number==11)
            {
               SWV5_PersistedRequestSetHeader empty_header;
               SWV5_TestBindRequestSetHeader(empty_header,empty,51);
               stored=stored && persistence.SavePendingRequests(context,checkpoint.header.persistence_namespace,empty,empty_header,decision);
            }
            SWV5_PersistedCheckpoint loaded;
            SWV5_PersistenceLoadResult load_result;
            const bool loaded_ok=persistence.LoadLatest(context,checkpoint.header.persistence_namespace,loaded,load_result);
            if(number==10)
               passed=stored && loaded_ok && loaded.has_latest_pending_request && loaded.pending_request_set.request_count==2 && SWV5_TestPersistedRequestEqual(loaded.latest_pending_request,requests[1]);
            else
               passed=stored && loaded_ok && !loaded.has_latest_pending_request && loaded.pending_request_set.request_count==0 && loaded.latest_pending_request.record_sequence==0;
            expected=(number==10 ? "checkpoint_summary_tracks_last_record" : "empty_set_clears_latest_summary");
            break;
         }
         case 12:
         case 13:
         case 14:
         case 15:
         {
            SWV5_RiskEvaluationInput risk_input;
            SWV5_TestMakeRiskInput(risk_input);
            if(number==14) risk_input.hard_kill_state.account_namespace.server="FOREIGN-SERVER";
            SWV5_RiskAuthorization authorization;
            const bool evaluated=risk.Evaluate(context,risk_input,authorization);
            SWV5_ContractDecision decision;
            if(number==12)
               passed=evaluated && risk.ValidateAuthorization(context,authorization,risk_input,decision) && authorization.authorization_id!="" && authorization.authorized_limits.contract_id==risk_input.limits.contract_id && authorization.authorized_projected_notional==risk_input.projected.projected_notional;
            else if(number==13)
            {
               authorization.authorization_id="";
               passed=evaluated && !risk.ValidateAuthorization(context,authorization,risk_input,decision);
            }
            else if(number==14)
               passed=!evaluated && authorization.disposition==SWV5_RISK_RECONCILIATION_REQUIRED;
            else
            {
               risk_input.hard_kill_state.latch_generation++;
               passed=evaluated && !risk.ValidateAuthorization(context,authorization,risk_input,decision);
            }
            expected=(number==12 ? "complete_authorization_round_trip" : (number==13 ? "missing_authorization_field_rejected" : (number==14 ? "full_hard_kill_namespace_rejected" : "hard_kill_generation_invalidates")));
            break;
         }
         case 16:
         {
            SWV5_BasketLifecycleSnapshot snapshot;
            SWV5_TestMakeLifecycle(snapshot,SWV5_BASKET_ACTIVE);
            SWV5_BasketTransitionRequest request;
            SWV5_TestMakeTransition(snapshot,SWV5_BASKET_RECOVERY,request);
            SWV5_BasketTransitionDecision first,replay;
            const bool first_ok=basket_state.ValidateTransition(context,snapshot,request,first);
            snapshot.state=first.resulting_state;
            snapshot.state_version=first.resulting_state_version;
            snapshot.cumulative_recovery_attempts=first.resulting_cumulative_recovery_attempts;
            snapshot.current_recovery_layer=first.resulting_recovery_layer;
            snapshot.accepted_recovery_evidence=first.resulting_accepted_recovery_evidence;
            passed=first_ok && first.recovery_evidence_added && basket_state.ValidateTransition(context,snapshot,request,replay) && replay.recovery_evidence_duplicate && replay.resulting_cumulative_recovery_attempts==snapshot.cumulative_recovery_attempts;
            expected="recovery_add_once_replay_stable";
            break;
         }
         case 17:
         case 18:
         {
            SWV5_PendingRequest pending;
            SWV5_TestMakePending(pending);
            SWV5_TransactionEvidence first_event;
            SWV5_TestMakeTransaction(pending,first_event,0.04);
            SWV5_ExecutionConfirmation first;
            const bool first_ok=execution.AcceptTransactionEvidence(context,pending,first_event,first);
            SWV5_TransactionEvidence second_event;
            SWV5_TestMakeTransaction(first.resulting_pending_request,second_event,0.06);
            second_event.correlation.broker_identity.transaction_sequence=401;
            second_event.correlation.broker_identity.broker_event_id=(number==18 ? first_event.correlation.broker_identity.broker_event_id : "EVENT-0002");
            SWV5_ExecutionConfirmation second;
            const bool second_ok=execution.AcceptTransactionEvidence(context,first.resulting_pending_request,second_event,second);
            if(number==17)
            {
               SWV5_ExecutionConfirmation replay;
               const bool replay_ok=execution.AcceptTransactionEvidence(context,second.resulting_pending_request,first_event,replay);
               passed=first_ok && second_ok && replay_ok && replay.duplicate_event && replay.resulting_pending_request.accepted_event_identities.accepted_identity_count==2 && replay.resulting_pending_request.cumulative_confirmed_volume==0.10;
            }
            else
               passed=first_ok && !second_ok && second.status==SWV5_CONFIRMATION_CONFLICT;
            expected=(number==17 ? "execution_add_two_replay_first_stable" : "reused_event_identity_conflict");
            break;
         }
         case 19:
         case 20:
         {
            SWV5_BasketStatistics current;
            SWV5_TestMakeStatistics(current);
            SWV5_AuthoritativeDeal deal;
            SWV5_TestMakeDeal(deal);
            SWV5_StatisticsDeduplicationEvidence evidence;
            SWV5_TestMakeDedupEvidence(evidence,current.deduplication,number==20 ? SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW : SWV5_STAT_IDENTITY_NEW);
            if(number==20)
            {
               evidence.correlation.broker_identity.transaction_sequence=398;
               evidence.correlation.broker_identity.broker_event_id="OUT-OF-ORDER-398";
            }
            deal.correlation=evidence.correlation;
            SWV5_BasketStatistics first;
            const bool first_ok=statistics.AccumulateDeal(context,deal,evidence,current,first);
            if(number==19)
            {
               SWV5_StatisticsDeduplicationEvidence duplicate=evidence;
               duplicate.prior_identity_index_revision=first.deduplication.identities.index_revision;
               duplicate.disposition=SWV5_STAT_IDENTITY_DUPLICATE;
               duplicate.membership_proof="MEMBERSHIP-PROOF";
               SWV5_BasketStatistics replay;
               const bool replay_ok=statistics.AccumulateDeal(context,deal,duplicate,first,replay);
               passed=first_ok && replay_ok && replay.authoritative_net_result==first.authoritative_net_result && replay.deal_count==first.deal_count && replay.deduplication.duplicate_deal_count==first.deduplication.duplicate_deal_count+1;
            }
            else
               passed=first_ok && first.deduplication.identities.highest_transaction_sequence==current.deduplication.identities.highest_transaction_sequence && first.deduplication.identities.accepted_identity_count==current.deduplication.identities.accepted_identity_count+1;
            expected=(number==19 ? "statistics_first_then_duplicate_no_double_money" : "statistics_out_of_order_unique_once");
            break;
         }
         case 21:
         case 22:
         {
            SWV5_InstanceLease observed;
            SWV5_TestMakeLease(observed);
            SWV5_InstanceLease caller=observed;
            if(number==22) caller.store_revision="STALE-REVISION";
            SWV5_OwnershipDecision result;
            const bool renewed=ownership.Heartbeat(context,caller,observed,result);
            if(number==21)
               passed=renewed && SWV5_TestS4421HeartbeatSemantic();
            else
               passed=!renewed && result.resulting_lease.heartbeat_sequence==observed.heartbeat_sequence;
            expected=(number==21 ? "heartbeat_monotonic_renewal" : "stale_heartbeat_rejected");
            break;
         }
         case 23:
         case 24:
         case 25:
         {
            SWV5_InstanceLease observed;
            SWV5_TestMakeLease(observed,SWV5_LOCK_EXPIRED);
            observed.expires_at=context.clock_time-1;
            observed.expiry_clock_sequence=context.clock_sequence-1;
            SWV5_OwnershipClaim claim;
            SWV5_TestMakeClaim(claim,observed);
            if(number==23) claim.takeover_evidence.lease_expiry.observed_heartbeat_sequence++;
            if(number==25) claim.claimant.key.server="FOREIGN-SERVER";
            SWV5_OwnershipDecision first,second;
            const bool first_ok=ownership.Acquire(context,claim,observed,first);
            if(number==24)
               passed=first_ok && !ownership.Acquire(context,claim,first.resulting_lease,second);
            else
               passed=!first_ok;
            expected=(number==23 ? "nested_expiry_mismatch_rejected" : (number==24 ? "duplicate_takeover_rejected" : "foreign_namespace_takeover_rejected"));
            break;
         }
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S44",number),"SPRINT4_4_SEMANTIC",passed,expected);
   }
}

void SWV5_TestApplyRecoveryDecision(const SWV5_BasketTransitionDecision &decision,
                                    SWV5_BasketLifecycleSnapshot &snapshot)
{
   snapshot.state=decision.resulting_state;
   snapshot.state_version=decision.resulting_state_version;
   snapshot.cumulative_recovery_attempts=decision.resulting_cumulative_recovery_attempts;
   snapshot.current_recovery_layer=decision.resulting_recovery_layer;
   snapshot.accepted_recovery_evidence=decision.resulting_accepted_recovery_evidence;
}

bool SWV5_TestRecoveryDecisionUnchanged(const SWV5_BasketLifecycleSnapshot &snapshot,
                                        const SWV5_BasketTransitionDecision &decision)
{
   return decision.resulting_state==snapshot.state &&
          decision.resulting_state_version==snapshot.state_version &&
          decision.resulting_cumulative_recovery_attempts==snapshot.cumulative_recovery_attempts &&
          decision.resulting_recovery_layer==snapshot.current_recovery_layer &&
          SWV5_TestEventIdentitySetEqual(decision.resulting_accepted_recovery_evidence,snapshot.accepted_recovery_evidence) &&
          !decision.recovery_evidence_added;
}

// Phase B recovery mutation trace (prior; request mutation; method; expected disposition/state; defect caught):
// S45BR-01 ACTIVE; none; ValidateTransition; ALLOW/RECOVERY plus one durable identity; first acceptance semantics.
// S45BR-02 returned RECOVERY; none; ValidateTransition; ALLOW/DUPLICATE with no mutation; known-identity fast path correctness.
// S45BR-03 returned RECOVERY; foreign owner; ValidateTransition; DENY/unchanged; stale-owner duplicate bypass.
// S45BR-04 returned RECOVERY; stale store revision; ValidateTransition; DENY/unchanged; stale-fence duplicate bypass.
// S45BR-05 returned RECOVERY; foreign Basket ID; ValidateTransition; DENY/unchanged; Basket-binding duplicate bypass.
// S45BR-06 returned RECOVERY; altered coherent request identity; ValidateTransition; DENY/unchanged; fingerprint conflict.
// S45BR-07 returned RECOVERY; invalid clock authority; ValidateTransition; DENY/unchanged; context-validation bypass.
// S45BR-08 returned RECOVERY; wrong expected state version; ValidateTransition; DENY/unchanged; lifecycle-version bypass.
// S45BR-09 returned RECOVERY; altered prior/proposed attempt and layer; ValidateTransition; DENY/unchanged; recovery-content bypass.
// S45BR-10 persistence-restored RECOVERY; exact request; ValidateTransition; ALLOW/DUPLICATE unchanged; restart idempotency.

void SWV5_RunSprint45RecoveryValidationTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=10;number++)
   {
      if(!SWV5_TestIdSelected(SWV5_TestCaseId("S45BR",number))) continue;
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_BasketLifecycleSnapshot initial;
      SWV5_TestMakeLifecycle(initial,SWV5_BASKET_ACTIVE);
      SWV5_BasketTransitionRequest request;
      SWV5_TestMakeTransition(initial,SWV5_BASKET_RECOVERY,request);
      SWV5_TestBasketStateContract implementation;
      SWV5_BasketTransitionDecision first;
      const bool first_ok=implementation.ValidateTransition(context,initial,request,first);
      SWV5_BasketLifecycleSnapshot restored=initial;
      if(first_ok)
         SWV5_TestApplyRecoveryDecision(first,restored);
      bool passed=false;
      string expected="fail_closed";
      if(number==1)
      {
         passed=first_ok && first.recovery_evidence_added && !first.recovery_evidence_duplicate &&
                first.resulting_state==SWV5_BASKET_RECOVERY && first.resulting_state_version==initial.state_version+1 &&
                first.resulting_cumulative_recovery_attempts==initial.cumulative_recovery_attempts+1 &&
                first.resulting_recovery_layer==initial.current_recovery_layer+1 &&
                first.resulting_accepted_recovery_evidence.accepted_identity_count==initial.accepted_recovery_evidence.accepted_identity_count+1 &&
                first.resulting_accepted_recovery_evidence.canonical_fingerprint_index!="";
         expected="first_valid_recovery_added_once";
      }
      else if(number==10)
      {
         SWV5_PersistedCheckpoint checkpoint;
         SWV5_TestMakeCheckpoint(checkpoint);
            checkpoint.basket.lifecycle=restored;
            SWV5_TestRefreshCheckpointVector(checkpoint);
            SWV5_TestSealCheckpoint(checkpoint);
         SWV5_PersistedRequestEvidence empty[];
         ArrayResize(empty,0);
         SWV5_TestPersistenceContract persistence;
         persistence.Configure(checkpoint,empty);
         SWV5_PersistedCheckpoint loaded;
         SWV5_PersistenceLoadResult load_result;
         const bool loaded_ok=persistence.LoadLatest(context,checkpoint.header.persistence_namespace,loaded,load_result);
         SWV5_BasketTransitionDecision replay;
         const bool replay_ok=loaded_ok && implementation.ValidateTransition(context,loaded.basket.lifecycle,request,replay);
         passed=first_ok && replay_ok && replay.recovery_evidence_duplicate && !replay.recovery_evidence_added &&
                SWV5_TestRecoveryDecisionUnchanged(loaded.basket.lifecycle,replay);
         expected="restart_restored_exact_replay_idempotent";
      }
      else
      {
         SWV5_ContractValidationContext replay_context=context;
         SWV5_BasketTransitionRequest replay_request=request;
         if(number==3) replay_request.ownership_fence.owner.instance_id="FOREIGN-OWNER";
         if(number==4) replay_request.ownership_fence.fencing_token_digest="STALE-FENCE";
         if(number==5) replay_request.basket_id.value="FOREIGN-BASKET";
         if(number==6)
         {
            replay_request.correlation.request_identity.request_id.attempt_id="ALTERED-ATTEMPT";
            replay_request.correlation.request_identity.idempotency_key="ALTERED-IDEMPOTENCY";
            replay_request.recovery_evidence.request_identity=replay_request.correlation.request_identity;
         }
         if(number==7) replay_context.clock_authority=SWV5_TIME_AUTHORITY_NONE;
         if(number==8) replay_request.expected_state_version++;
         if(number==9)
         {
            replay_request.recovery_evidence.prior_cumulative_recovery_attempts++;
            replay_request.recovery_evidence.proposed_cumulative_recovery_attempts++;
            replay_request.recovery_evidence.prior_recovery_layer++;
            replay_request.recovery_evidence.proposed_recovery_layer++;
         }
         SWV5_BasketTransitionDecision replay;
         const bool replay_ok=implementation.ValidateTransition(replay_context,restored,replay_request,replay);
         if(number==2)
         {
            passed=first_ok && replay_ok && replay.recovery_evidence_duplicate && !replay.recovery_evidence_added &&
                   SWV5_TestRecoveryDecisionUnchanged(restored,replay);
            expected="returned_state_exact_replay_idempotent";
         }
         else
         {
            passed=first_ok && !replay_ok && !replay.recovery_evidence_duplicate &&
                   replay.decision.disposition==SWV5_DISPOSITION_DENY &&
                   SWV5_TestRecoveryDecisionUnchanged(restored,replay);
            if(number==3) expected="known_identity_foreign_owner_rejected";
            if(number==4) expected="known_identity_stale_fence_rejected";
            if(number==5) expected="known_identity_wrong_basket_rejected";
            if(number==6) expected="known_identity_changed_request_fingerprint_conflict";
            if(number==7) expected="known_identity_invalid_context_rejected";
            if(number==8) expected="known_identity_wrong_state_version_rejected";
            if(number==9) expected="known_identity_altered_attempt_layer_rejected";
         }
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S45BR",number),"SPRINT4_5_RECOVERY_CANONICAL_PATH",passed,expected);
   }
}

bool SWV5_TestRejectedAcquireUnchanged(const SWV5_InstanceLease &observed,
                                       const SWV5_OwnershipDecision &decision)
{
   return decision.decision.disposition==SWV5_DISPOSITION_DENY &&
          decision.resulting_lease.status==observed.status &&
          SWV5_TestFenceEqual(decision.resulting_lease.fence,observed.fence) &&
          decision.resulting_lease.heartbeat_sequence==observed.heartbeat_sequence;
}

// Phase B ownership mutation trace (prior; claim mutation; method; expected disposition/state; defect caught):
// S45BO-01 UNCLAIMED; none; Acquire; ALLOW/ACQUIRED coherent lease; valid acquisition semantics.
// S45BO-02 UNCLAIMED; invalid clock authority; Acquire; DENY/unchanged; context-validation bypass.
// S45BO-03 UNCLAIMED; foreign expected namespace; Acquire; DENY/unchanged; observed-namespace bypass.
// S45BO-04 UNCLAIMED; empty claimant instance; Acquire; DENY/unchanged; malformed-claimant bypass.
// S45BO-05 UNCLAIMED; each key dimension altered; Acquire; DENY/unchanged; account/broker/server/symbol/strategy/Magic bypass.
// S45BO-06 UNCLAIMED; zero and excessive durations; Acquire; DENY/unchanged; expiry-policy bypass.
// S45BO-07 UNCLAIMED; stale expected store revision; Acquire; DENY/unchanged; observed-fence/CAS bypass.
// S45BO-08 UNCLAIMED; claimant key mismatch; Acquire; DENY/unchanged; claimant-namespace binding bypass.
// S45BO-09 UNCLAIMED; none; Acquire; ALLOW/ACQUIRED field-coherent lease; patched-empty-lease defect.
// S45BO-10 returned ACQUIRED; none; pure lifecycle validation; valid future input; unusable Acquire-result defect.

void SWV5_RunSprint45UnclaimedAcquireTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=10;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_InstanceLease observed;
      SWV5_TestMakeLease(observed,SWV5_LOCK_UNCLAIMED);
      SWV5_OwnershipClaim claim;
      SWV5_TestMakeClaim(claim,observed);
      SWV5_TestOwnershipContract implementation;
      bool passed=false;
      string expected="fail_closed";
      if(number==5)
      {
         bool all_rejected=true;
         for(int field=0;field<6;field++)
         {
            SWV5_OwnershipClaim altered=claim;
            if(field==0) altered.claimant.key.account_login++;
            if(field==1) altered.claimant.key.broker_identity="FOREIGN-BROKER";
            if(field==2) altered.claimant.key.server="FOREIGN-SERVER";
            if(field==3) altered.claimant.key.symbol="FOREIGN-SYMBOL";
            if(field==4) altered.claimant.key.strategy_id="FOREIGN-STRATEGY";
            if(field==5) altered.claimant.key.magic++;
            SWV5_OwnershipDecision decision;
            all_rejected=all_rejected && !implementation.Acquire(context,altered,observed,decision) &&
                         SWV5_TestRejectedAcquireUnchanged(observed,decision);
         }
         passed=all_rejected;
         expected="all_ownership_key_dimensions_bound";
      }
      else if(number==6)
      {
         SWV5_OwnershipDecision zero_decision,long_decision;
         SWV5_OwnershipClaim zero_claim=claim;
         zero_claim.lease_duration_seconds=0;
         SWV5_OwnershipClaim long_claim=claim;
         long_claim.lease_duration_seconds=86401;
         passed=!implementation.Acquire(context,zero_claim,observed,zero_decision) &&
                SWV5_TestRejectedAcquireUnchanged(observed,zero_decision) &&
                !implementation.Acquire(context,long_claim,observed,long_decision) &&
                SWV5_TestRejectedAcquireUnchanged(observed,long_decision);
         expected="invalid_lease_duration_rejected";
      }
      else
      {
         if(number==2) context.clock_authority=SWV5_TIME_AUTHORITY_NONE;
         if(number==3)
         {
            claim.claimant.key.server="FOREIGN-SERVER";
            claim.expected_fence.ownership_namespace.server="FOREIGN-SERVER";
            claim.expected_fence.owner.key.server="FOREIGN-SERVER";
         }
         if(number==4) claim.claimant.instance_id="";
         if(number==7) claim.expected_store_revision="STALE-REVISION";
         if(number==8) claim.claimant.key.symbol="MISMATCHED-SYMBOL";
         SWV5_OwnershipDecision decision;
         const bool acquired=implementation.Acquire(context,claim,observed,decision);
         if(number==1)
         {
            passed=acquired && SWV5_TestAcquiredLeaseCoherent(context,claim,observed,decision.resulting_lease);
            expected="valid_unclaimed_claim_acquired";
         }
         else if(number==9)
         {
            passed=acquired && SWV5_TestAcquiredLeaseCoherent(context,claim,observed,decision.resulting_lease) &&
                   decision.resulting_lease.fence.fencing_token_digest!=observed.fence.fencing_token_digest;
            expected="resulting_lease_field_coherence";
         }
         else if(number==10)
         {
            SWV5_ContractValidationContext later=context;
            later.clock_sequence++;
            later.clock_time++;
            passed=acquired && SWV5_TestAcquiredLeaseCoherent(context,claim,observed,decision.resulting_lease) &&
                   SWV5_TestHeartbeatValid(later,decision.resulting_lease,decision.resulting_lease);
            expected="resulting_lease_valid_for_later_lifecycle";
         }
         else
         {
            passed=!acquired && SWV5_TestRejectedAcquireUnchanged(observed,decision);
            if(number==2) expected="invalid_context_rejected";
            if(number==3) expected="foreign_ownership_namespace_rejected";
            if(number==4) expected="malformed_claimant_rejected";
            if(number==7) expected="stale_store_revision_rejected";
            if(number==8) expected="claimant_key_mismatch_rejected";
         }
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S45BO",number),"SPRINT4_5_UNCLAIMED_ACQUIRE_CANONICAL_PATH",passed,expected);
   }
}

// Phase C Risk trace: every case starts with Evaluate(valid current binding), invokes ValidateAuthorization,
// expects matching input to ALLOW and every mutation to DENY without changing the returned authorization.
// S45CR-01 complete binding; 02 all RiskLimit fields; 03 broker/server/login/currency/strategy/Magic; 04 account mode.
// S45CR-05 Basket version; 06 specification sequence; 07 volume; 08 price; 09 stop; 10 limit.
// S45CR-11 projected loss; 12 projected notional; 13 projected margin; 14 every monetary-basis category.
// S45CR-15 Hard Kill latch ID; 16 generation; 17 expiry; 18 ownership fence; 19 request identity; 20 ALLOW contradiction.
// S45CR-21 contract version; 22 authorization ID; 23 limits contract ID; 24 epoch; 25 sequence; 26 evaluated time.
// S45CR-27 intent type; 28 direction; 29 persistence Basket namespace. A validator ignoring the named binding fails the case.
void SWV5_RunSprint45RiskBindingTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=29;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_RiskEvaluationInput current;
      SWV5_TestMakeRiskInput(current);
      SWV5_TestRiskContract implementation;
      SWV5_RiskAuthorization authorization;
      const bool evaluated=implementation.Evaluate(context,current,authorization);
      SWV5_ContractDecision decision;
      bool passed=false;
      string expected="fail_closed";
      if(number==1)
      {
         passed=evaluated && implementation.ValidateAuthorization(context,authorization,current,decision) &&
                SWV5_TestVersionEqual(authorization.contract_version,context.expected_version) &&
                authorization.authorization_id==current.intent.risk_authorization_id &&
                authorization.limits_contract_id==current.limits.contract_id &&
                SWV5_TestRiskLimitsEqual(authorization.authorized_limits,current.limits,context) &&
                SWV5_TestRequestIdentityEqual(authorization.request_identity,current.intent.request_identity) &&
                SWV5_TestNamespaceEqual(authorization.persistence_namespace,current.intent.persistence_namespace) &&
                SWV5_TestFenceEqual(authorization.ownership_fence,current.ownership_fence) &&
                SWV5_TestAccountNamespaceEqual(authorization.account_namespace,current.account_namespace,true) &&
                authorization.account_mode==current.account_mode && authorization.disposition==SWV5_RISK_ALLOW &&
                authorization.blocking_domain==SWV5_RISK_DOMAIN_NONE && authorization.reason_flags==0 &&
                authorization.basket_state_version==current.basket.lifecycle.state_version &&
                authorization.symbol_specification_sequence==current.intent.symbol_specification_sequence &&
                authorization.authorized_intent_type==current.intent.intent_type &&
                authorization.authorized_direction==current.intent.direction &&
                SWV5_TestNear(authorization.authorized_volume,current.intent.normalized_volume,context.volume_tolerance) &&
                SWV5_TestNear(authorization.authorized_price,current.intent.normalized_price,context.price_tolerance) &&
                SWV5_TestNear(authorization.authorized_stop_price,current.intent.normalized_stop_price,context.price_tolerance) &&
                SWV5_TestNear(authorization.authorized_limit_price,current.intent.normalized_limit_price,context.price_tolerance) &&
                authorization.risk_snapshot_epoch==current.account_namespace.snapshot_epoch &&
                authorization.risk_snapshot_sequence==current.account_namespace.snapshot_sequence &&
                SWV5_TestNear(authorization.authorized_projected_loss,current.projected.projected_maximum_loss,context.price_tolerance) &&
                SWV5_TestNear(authorization.authorized_projected_notional,current.projected.projected_notional,context.price_tolerance) &&
                SWV5_TestNear(authorization.authorized_projected_margin,current.projected.projected_margin,context.price_tolerance) &&
                SWV5_TestMonetaryBasisEqual(authorization.monetary_basis,current.projected.monetary_basis,context) &&
                authorization.hard_kill_latch_id==current.hard_kill_state.latch_id &&
                authorization.hard_kill_latch_generation==current.hard_kill_state.latch_generation &&
                authorization.evaluated_at==context.clock_time && authorization.expires_at>=context.clock_time &&
                authorization.reason_text!="";
         expected="complete_evaluate_and_full_rebind";
      }
      else if(number==2)
      {
         bool all_rejected=evaluated;
         for(int field=0;field<14;field++)
         {
            SWV5_RiskEvaluationInput changed=current;
            if(field==0) changed.limits.minimum_equity-=1.0;
            if(field==1) changed.limits.maximum_daily_net_loss+=1.0;
            if(field==2) changed.limits.maximum_account_margin_fraction+=0.01;
            if(field==3) changed.limits.maximum_basket_loss+=1.0;
            if(field==4) changed.limits.maximum_basket_volume+=0.1;
            if(field==5) changed.limits.maximum_symbol_volume+=0.1;
            if(field==6) changed.limits.maximum_aggregate_volume+=0.1;
            if(field==7) changed.limits.maximum_aggregate_notional+=1.0;
            if(field==8) changed.limits.maximum_live_baskets++;
            if(field==9) changed.limits.maximum_cumulative_recovery_attempts++;
            if(field==10) changed.limits.maximum_snapshot_age_seconds++;
            if(field==11) changed.limits.trading_day_policy=SWV5_TRADING_DAY_UTC;
            if(field==12) changed.limits.trading_day_utc_offset_minutes=60;
            if(field==13) changed.limits.hard_kill_enabled=false;
            all_rejected=all_rejected && !implementation.ValidateAuthorization(context,authorization,changed,decision);
         }
         passed=all_rejected;
         expected="every_risk_limit_field_bound";
      }
      else if(number==3)
      {
         bool all_rejected=evaluated;
         for(int field=0;field<6;field++)
         {
            SWV5_RiskEvaluationInput changed=current;
            SWV5_AccountRiskNamespace changed_namespace=changed.account_namespace;
            if(field==0) changed_namespace.broker_identity="OTHER-BROKER";
            if(field==1) changed_namespace.server="OTHER-SERVER";
            if(field==2) changed_namespace.account_login++;
            if(field==3) changed_namespace.account_currency="EUR";
            if(field==4) changed_namespace.strategy_id="OTHER-STRATEGY";
            if(field==5) changed_namespace.magic++;
            SWV5_TestApplyRiskNamespace(changed,changed_namespace);
            all_rejected=all_rejected && !implementation.ValidateAuthorization(context,authorization,changed,decision);
         }
         passed=all_rejected;
         expected="all_account_risk_namespace_dimensions_bound";
      }
      else if(number==14)
      {
         bool all_rejected=evaluated;
         for(int field=0;field<9;field++)
         {
            SWV5_RiskEvaluationInput changed=current;
            if(field==0) changed.projected.monetary_basis.currency="EUR";
            if(field==1) changed.projected.monetary_basis.conversion_rate_to_account_currency=1.10;
            if(field==2) changed.projected.monetary_basis.conversion_source="OTHER-SOURCE";
            if(field==3) changed.projected.monetary_basis.valuation_at--;
            if(field==4) changed.projected.monetary_basis.calculation_basis=SWV5_RISK_BASIS_STRESS_SCENARIO;
            if(field==5) changed.projected.monetary_basis.sign_convention=SWV5_RISK_LOSS_NEGATIVE;
            if(field==6) changed.projected.monetary_basis.includes_commission=false;
            if(field==7) changed.projected.monetary_basis.includes_swap=false;
            if(field==8) changed.projected.monetary_basis.includes_fee=false;
            all_rejected=all_rejected && !implementation.ValidateAuthorization(context,authorization,changed,decision);
         }
         passed=all_rejected;
         expected="complete_monetary_basis_binding";
      }
      else if(number==20)
      {
         SWV5_RiskAuthorization changed_domain=authorization;
         changed_domain.blocking_domain=SWV5_RISK_DOMAIN_ACCOUNT;
         SWV5_RiskAuthorization changed_reason=authorization;
         changed_reason.reason_flags=SWV5_RISK_ACCOUNT_LIMIT;
         passed=evaluated && !implementation.ValidateAuthorization(context,changed_domain,current,decision) &&
                !implementation.ValidateAuthorization(context,changed_reason,current,decision);
         expected="allow_state_domain_and_reason_coherent";
      }
      else
      {
         if(number==4)
         {
            SWV5_AccountRiskNamespace changed_namespace=current.account_namespace;
            changed_namespace.account_mode=SWV5_ACCOUNT_MODE_NETTING;
            SWV5_TestApplyRiskNamespace(current,changed_namespace);
            current.account_mode=SWV5_ACCOUNT_MODE_NETTING;
            current.intent.account_mode=SWV5_ACCOUNT_MODE_NETTING;
         }
         if(number==5)
         {
            current.basket.lifecycle.state_version++;
            current.intent.expected_basket_version=current.basket.lifecycle.state_version;
         }
         if(number==6) current.intent.symbol_specification_sequence++;
         if(number==7) current.intent.normalized_volume+=0.01;
         if(number==8) current.intent.normalized_price+=0.05;
         if(number==9) current.intent.normalized_stop_price-=0.05;
         if(number==10) current.intent.normalized_limit_price+=0.05;
         if(number==11) current.projected.projected_maximum_loss+=1.0;
         if(number==12) current.projected.projected_notional+=1.0;
         if(number==13) current.projected.projected_margin+=1.0;
         if(number==15) current.hard_kill_state.latch_id="OTHER-LATCH";
         if(number==16) current.hard_kill_state.latch_generation++;
         if(number==17) authorization.expires_at=context.clock_time-1;
         if(number==18)
         {
            current.ownership_fence.fencing_token_digest="CURRENT-FENCE-DIGEST";
            current.intent.ownership_fence=current.ownership_fence;
            current.basket.lifecycle.ownership_fence=current.ownership_fence;
         }
         if(number==19) current.intent.request_identity.request_id.attempt_id="CURRENT-ATTEMPT-2";
         if(number==21) authorization.contract_version.schema_version--;
         if(number==22) authorization.authorization_id="OTHER-AUTHORIZATION";
         if(number==23) current.limits.contract_id="OTHER-LIMITS-CONTRACT";
         if(number==24)
         {
            SWV5_AccountRiskNamespace changed_namespace=current.account_namespace;
            changed_namespace.snapshot_epoch++;
            SWV5_TestApplyRiskNamespace(current,changed_namespace);
         }
         if(number==25)
         {
            SWV5_AccountRiskNamespace changed_namespace=current.account_namespace;
            changed_namespace.snapshot_sequence++;
            SWV5_TestApplyRiskNamespace(current,changed_namespace);
         }
         if(number==26) authorization.evaluated_at=context.clock_time+1;
         if(number==27) current.intent.intent_type=SWV5_INTENT_INCREASE;
         if(number==28) current.intent.direction=-1;
         if(number==29)
         {
            current.intent.persistence_namespace.basket_id.value="OTHER-BASKET";
            current.hard_kill_state.persistence_namespace.basket_id.value="OTHER-BASKET";
            current.basket.lifecycle.basket_id.value="OTHER-BASKET";
         }
         passed=evaluated && !implementation.ValidateAuthorization(context,authorization,current,decision) &&
                decision.disposition==SWV5_DISPOSITION_DENY;
         if(number==4) expected="account_mode_mismatch_rejected";
         if(number==5) expected="basket_version_mismatch_rejected";
         if(number==6) expected="specification_sequence_mismatch_rejected";
         if(number==7) expected="volume_mismatch_rejected";
         if(number==8) expected="price_mismatch_rejected";
         if(number==9) expected="stop_mismatch_rejected";
         if(number==10) expected="limit_mismatch_rejected";
         if(number==11) expected="projected_loss_mismatch_rejected";
         if(number==12) expected="projected_notional_mismatch_rejected";
         if(number==13) expected="projected_margin_mismatch_rejected";
         if(number==15) expected="hard_kill_latch_id_mismatch_rejected";
         if(number==16) expected="hard_kill_generation_mismatch_rejected";
         if(number==17) expected="expired_authorization_rejected";
         if(number==18) expected="ownership_fence_mismatch_rejected";
         if(number==19) expected="request_identity_mismatch_rejected";
         if(number==21) expected="wrong_authorization_contract_version_rejected";
         if(number==22) expected="authorization_identity_mismatch_rejected";
         if(number==23) expected="limits_contract_identity_mismatch_rejected";
         if(number==24) expected="risk_snapshot_epoch_mismatch_rejected";
         if(number==25) expected="risk_snapshot_sequence_mismatch_rejected";
         if(number==26) expected="future_evaluated_time_rejected";
         if(number==27) expected="intent_type_mismatch_rejected";
         if(number==28) expected="direction_mismatch_rejected";
         if(number==29) expected="persistence_basket_namespace_mismatch_rejected";
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S45CR",number),"SPRINT4_5_RISK_AUTHORIZATION_BINDING",passed,expected);
   }
}

void SWV5_TestMakeReduceUnitRequest(SWV5_UnitNormalizationRequest &request)
{
   SWV5_TestMakeUnitRequest(request);
   request.intent_type=SWV5_INTENT_REDUCE;
   request.purpose=SWV5_PRICE_CLOSE;
   request.operation_kind=SWV5_OPERATION_REDUCE;
   request.raw_stop_price=0.0;
   request.raw_limit_price=0.0;
   request.current_exposure_volume=0.115;
   request.target_exposure_volume=0.100;
   request.raw_volume=0.015;
   request.exposure_increasing=false;
   request.protective_operation=false;
}

void SWV5_TestMakeCloseUnitRequest(SWV5_UnitNormalizationRequest &request,const double current_volume)
{
   SWV5_TestMakeUnitRequest(request);
   request.intent_type=SWV5_INTENT_CLOSE;
   request.purpose=SWV5_PRICE_CLOSE;
   request.operation_kind=SWV5_OPERATION_CLOSE;
   request.raw_stop_price=0.0;
   request.raw_limit_price=0.0;
   request.current_exposure_volume=current_volume;
   request.target_exposure_volume=0.0;
   request.raw_volume=current_volume;
   request.exposure_increasing=false;
   request.protective_operation=false;
}

void SWV5_TestMakeStopUnitRequest(SWV5_UnitNormalizationRequest &request,const int direction)
{
   SWV5_TestMakeUnitRequest(request);
   request.intent_type=SWV5_INTENT_REDUCE;
   request.purpose=SWV5_PRICE_STOP_LOSS;
   request.operation_kind=SWV5_OPERATION_MODIFY_STOP;
   request.direction=direction;
   request.raw_volume=0.0;
   request.current_exposure_volume=0.10;
   request.target_exposure_volume=0.10;
   request.exposure_increasing=false;
   request.protective_operation=true;
   request.raw_limit_price=0.0;
}

void SWV5_TestMakeLimitUnitRequest(SWV5_UnitNormalizationRequest &request,const int direction)
{
   SWV5_TestMakeUnitRequest(request);
   request.intent_type=SWV5_INTENT_REDUCE;
   request.purpose=SWV5_PRICE_TAKE_PROFIT;
   request.operation_kind=SWV5_OPERATION_MODIFY_LIMIT;
   request.direction=direction;
   request.raw_volume=0.0;
   request.current_exposure_volume=0.10;
   request.target_exposure_volume=0.10;
   request.exposure_increasing=false;
   request.protective_operation=false;
   request.raw_stop_price=0.0;
   request.operation_price=(direction>0 ? 2401.00 : 2399.00);
   request.raw_limit_price=(direction>0 ? 2420.03 : 2380.03);
}

bool SWV5_TestNormalizedUnitEqual(const SWV5_NormalizedUnits &left,const SWV5_NormalizedUnits &right)
{
   return left.derived_operation_semantic==right.derived_operation_semantic &&
          left.price==right.price && left.stop_price==right.stop_price && left.limit_price==right.limit_price &&
          left.volume==right.volume && left.resulting_exposure_volume==right.resulting_exposure_volume &&
          left.residual_exposure_volume==right.residual_exposure_volume &&
          left.applied_entry_rounding==right.applied_entry_rounding &&
          left.applied_stop_rounding==right.applied_stop_rounding &&
          left.applied_limit_rounding==right.applied_limit_rounding &&
          left.applied_volume_rounding==right.applied_volume_rounding &&
          left.price_aligned_to_tick==right.price_aligned_to_tick &&
          left.volume_aligned_to_step==right.volume_aligned_to_step &&
          left.stops_level_satisfied==right.stops_level_satisfied &&
          left.freeze_level_satisfied==right.freeze_level_satisfied &&
          left.caller_flags_consistent==right.caller_flags_consistent;
}

// Phase C Unit trace: every case invokes Normalize and inspects the derived semantic, rounding, normalized values, and safety flags.
// S45CU-01 OPEN/down; 02 INCREASE/down; 03 caller override; 04 REDUCE/down; 05 FULL_CLOSE exact.
// S45CU-06 RESIDUAL_CLOSE exact; 07 impossible residual; 08 buy stop side; 09 sell stop side; 10 freeze; 11 stops level.
// S45CU-12 stale spec; 13 purpose/kind contradiction; 14 lot step; 15 min/max; 16 identical replay.
// S45CU-17 buy target/down; 18 sell target/up; 19 invalid step; 20 malformed market. A flag-selected policy fails 01-04.
void SWV5_RunSprint45UnitSafetyTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=20;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_SymbolUnitSpecification specification;
      SWV5_TestMakeSymbolSpecification(specification);
      SWV5_UnitNormalizationRequest request;
      SWV5_TestMakeUnitRequest(request);
      SWV5_TestUnitSystemContract implementation;
      SWV5_NormalizedUnits normalized;
      SWV5_UnitValidationResult result;
      bool passed=false;
      string expected="fail_closed";
      if(number==2)
      {
         request.intent_type=SWV5_INTENT_INCREASE;
         request.current_exposure_volume=0.10;
         request.target_exposure_volume=0.115;
         passed=implementation.Normalize(context,specification,request,normalized,result) &&
                normalized.derived_operation_semantic==SWV5_UNIT_OPERATION_INCREASE &&
                normalized.applied_volume_rounding==SWV5_NORMALIZE_DOWN &&
                SWV5_TestNear(normalized.volume,0.01,context.volume_tolerance) &&
                SWV5_TestNear(normalized.resulting_exposure_volume,0.11,context.volume_tolerance);
         expected="increase_derived_down_rounding";
      }
      else if(number==4)
      {
         SWV5_TestMakeReduceUnitRequest(request);
         passed=implementation.Normalize(context,specification,request,normalized,result) &&
                normalized.derived_operation_semantic==SWV5_UNIT_OPERATION_REDUCE &&
                normalized.applied_volume_rounding==SWV5_NORMALIZE_DOWN &&
                SWV5_TestNear(normalized.volume,0.01,context.volume_tolerance) &&
                SWV5_TestNear(normalized.resulting_exposure_volume,0.105,context.volume_tolerance);
         expected="reduce_broker_valid_down_rounding";
      }
      else if(number==5 || number==6 || number==7)
      {
         SWV5_TestMakeCloseUnitRequest(request,(number==5 ? 0.10 : (number==6 ? 0.005 : 0.015)));
         const bool normalized_ok=implementation.Normalize(context,specification,request,normalized,result);
         if(number==5)
            passed=normalized_ok && normalized.derived_operation_semantic==SWV5_UNIT_OPERATION_FULL_CLOSE &&
                   SWV5_TestNear(normalized.volume,0.10,context.volume_tolerance) &&
                   SWV5_TestNear(normalized.resulting_exposure_volume,0.0,context.volume_tolerance);
         if(number==6)
            passed=normalized_ok && normalized.derived_operation_semantic==SWV5_UNIT_OPERATION_RESIDUAL_CLOSE &&
                   SWV5_TestNear(normalized.volume,0.005,context.volume_tolerance) && !normalized.volume_aligned_to_step &&
                   SWV5_TestNear(normalized.residual_exposure_volume,0.0,context.volume_tolerance);
         if(number==7) passed=!normalized_ok;
         expected=(number==5 ? "full_close_exact_rule" : (number==6 ? "subminimum_residual_exact_close_rule" : "off_step_residual_close_rejected"));
      }
      else if(number==8 || number==9 || number==10 || number==11)
      {
         SWV5_TestMakeStopUnitRequest(request,(number==9 ? -1 : 1));
         if(number==8) request.raw_stop_price=request.operation_price+1.0;
         if(number==9) request.raw_stop_price=request.operation_price-1.0;
         if(number==10) { request.raw_stop_price=2398.50; request.operation_price=request.market_bid; }
         if(number==11) request.raw_stop_price=request.operation_price-0.50;
         passed=!implementation.Normalize(context,specification,request,normalized,result);
         expected=(number==8 ? "buy_wrong_side_stop_rejected" : (number==9 ? "sell_wrong_side_stop_rejected" : (number==10 ? "freeze_violation_rejected" : "stops_level_violation_rejected")));
      }
      else if(number==15)
      {
         SWV5_UnitNormalizationRequest below=request;
         below.raw_volume=0.005;
         below.target_exposure_volume=0.005;
         SWV5_UnitNormalizationRequest above=request;
         above.raw_volume=100.015;
         above.target_exposure_volume=100.015;
         SWV5_NormalizedUnits below_normalized,above_normalized;
         SWV5_UnitValidationResult below_result,above_result;
         passed=!implementation.Normalize(context,specification,below,below_normalized,below_result) &&
                !implementation.Normalize(context,specification,above,above_normalized,above_result);
         expected="minimum_and_maximum_volume_enforced";
      }
      else if(number==16)
      {
         SWV5_NormalizedUnits replay;
         SWV5_UnitValidationResult replay_result;
         const bool first_ok=implementation.Normalize(context,specification,request,normalized,result);
         const bool replay_ok=implementation.Normalize(context,specification,request,replay,replay_result);
         passed=first_ok && replay_ok && SWV5_TestNormalizedUnitEqual(normalized,replay) &&
                SWV5_TestDecisionEqual(result.decision,replay_result.decision);
         expected="identical_normalization_deterministic";
      }
      else if(number==17 || number==18)
      {
         SWV5_TestMakeLimitUnitRequest(request,(number==17 ? 1 : -1));
         const bool normalized_ok=implementation.Normalize(context,specification,request,normalized,result);
         passed=normalized_ok && normalized.derived_operation_semantic==SWV5_UNIT_OPERATION_LIMIT_TARGET &&
                normalized.applied_limit_rounding==(number==17 ? SWV5_NORMALIZE_DOWN : SWV5_NORMALIZE_UP) &&
                SWV5_TestNear(normalized.limit_price,(number==17 ? 2420.00 : 2380.05),context.price_tolerance) &&
                normalized.freeze_level_satisfied;
         expected=(number==17 ? "buy_limit_target_rounds_directionally_safe" : "sell_limit_target_rounds_directionally_safe");
      }
      else if(number==19)
      {
         specification.volume_step=0.0;
         passed=!implementation.Normalize(context,specification,request,normalized,result);
         expected="invalid_lot_step_rejected";
      }
      else if(number==20)
      {
         request.market_bid=0.0;
         request.market_ask=0.0;
         passed=!implementation.Normalize(context,specification,request,normalized,result);
         expected="malformed_market_context_rejected";
      }
      else
      {
         if(number==3) request.exposure_increasing=false;
         if(number==12) specification.valid_until=context.clock_time-1;
         if(number==13) request.purpose=SWV5_PRICE_CLOSE;
         if(number==14) { request.raw_volume=0.019; request.target_exposure_volume=0.019; }
         const bool normalized_ok=implementation.Normalize(context,specification,request,normalized,result);
         if(number==1)
            passed=normalized_ok && normalized.derived_operation_semantic==SWV5_UNIT_OPERATION_OPEN &&
                   normalized.applied_volume_rounding==SWV5_NORMALIZE_DOWN && normalized.caller_flags_consistent &&
                   SWV5_TestNear(normalized.volume,0.01,context.volume_tolerance) &&
                   SWV5_TestNear(normalized.resulting_exposure_volume,0.01,context.volume_tolerance);
         if(number==3 || number==12 || number==13) passed=!normalized_ok;
         if(number==14)
            passed=normalized_ok && normalized.applied_volume_rounding==SWV5_NORMALIZE_DOWN &&
                   SWV5_TestNear(normalized.volume,0.01,context.volume_tolerance) && normalized.volume_aligned_to_step;
         if(number==1) expected="open_derived_down_rounding";
         if(number==3) expected="caller_flag_override_rejected";
         if(number==12) expected="stale_specification_rejected";
         if(number==13) expected="purpose_operation_contradiction_rejected";
         if(number==14) expected="lot_step_normalization_deterministic";
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S45CU",number),"SPRINT4_5_DERIVED_UNIT_SAFETY",passed,expected);
   }
}

bool SWV5_TestBuildHeartbeatChain(SWV5_InstanceLease &acquired,
                                  SWV5_InstanceLease &heartbeat1,
                                  SWV5_InstanceLease &heartbeat2,
                                  SWV5_InstanceLease &heartbeat3)
{
   SWV5_TestOwnershipContract implementation;
   SWV5_ContractValidationContext acquire_context;
   SWV5_TestMakeContext(acquire_context);
   SWV5_InstanceLease observed;
   SWV5_TestMakeLease(observed,SWV5_LOCK_UNCLAIMED);
   SWV5_OwnershipClaim claim;
   SWV5_TestMakeClaim(claim,observed);
   SWV5_OwnershipDecision decision;
   if(!implementation.Acquire(acquire_context,claim,observed,decision))
      return false;
   acquired=decision.resulting_lease;
   SWV5_ContractValidationContext heartbeat_context=acquire_context;
   heartbeat_context.clock_sequence+=10;
   heartbeat_context.clock_time+=10;
   if(!implementation.Heartbeat(heartbeat_context,acquired,acquired,decision))
      return false;
   heartbeat1=decision.resulting_lease;
   heartbeat_context.clock_sequence+=10;
   heartbeat_context.clock_time+=10;
   if(!implementation.Heartbeat(heartbeat_context,heartbeat1,heartbeat1,decision))
      return false;
   heartbeat2=decision.resulting_lease;
   heartbeat_context.clock_sequence+=10;
   heartbeat_context.clock_time+=10;
   if(!implementation.Heartbeat(heartbeat_context,heartbeat2,heartbeat2,decision))
      return false;
   heartbeat3=decision.resulting_lease;
   return true;
}

void SWV5_TestMakeExpiredTakeoverFixture(SWV5_ContractValidationContext &context,
                                         SWV5_InstanceLease &observed,
                                         SWV5_OwnershipClaim &claim)
{
   SWV5_TestMakeContext(context);
   SWV5_TestMakeLease(observed,SWV5_LOCK_EXPIRED);
   observed.expires_at=context.clock_time-1;
   observed.expiry_clock_sequence=context.clock_sequence-1;
   SWV5_TestMakeClaim(claim,observed);
}

// Phase D Ownership trace:
// S45DO-01..16 prove acquire -> three returned-lease heartbeats and fail-closed mutation cases.
// S45DO-17..31 prove complete typed takeover binding, generation monotonicity, and usable result state.
// S45DO-32..33 prove same-owner heartbeat preserves authorization while takeover invalidates the stale fence.
void SWV5_RunSprint45OwnershipLifecycleTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=33;number++)
   {
      if(!SWV5_TestIdSelected(SWV5_TestCaseId("S45DO",number))) continue;
      bool passed=false;
      string expected="fail_closed";
      if(number<=8)
      {
         SWV5_InstanceLease acquired,heartbeat1,heartbeat2,heartbeat3;
         const bool chain=SWV5_TestBuildHeartbeatChain(acquired,heartbeat1,heartbeat2,heartbeat3);
         if(number==1) passed=chain && acquired.status==SWV5_LOCK_ACQUIRED && acquired.heartbeat_sequence==1;
         if(number==2) passed=chain && heartbeat1.status==SWV5_LOCK_RENEWED;
         if(number==3) passed=chain && heartbeat2.status==SWV5_LOCK_RENEWED;
         if(number==4) passed=chain && heartbeat3.status==SWV5_LOCK_RENEWED;
         if(number==5) passed=chain && heartbeat1.heartbeat_sequence==acquired.heartbeat_sequence+1 &&
                                      heartbeat2.heartbeat_sequence==heartbeat1.heartbeat_sequence+1 &&
                                      heartbeat3.heartbeat_sequence==heartbeat2.heartbeat_sequence+1 &&
                                      heartbeat1.fence.lease_version==acquired.fence.lease_version &&
                                      heartbeat2.fence.lease_version==heartbeat1.fence.lease_version &&
                                      heartbeat3.fence.lease_version==heartbeat2.fence.lease_version;
         if(number==6) passed=chain && heartbeat1.heartbeat_at>acquired.heartbeat_at &&
                                      heartbeat2.heartbeat_at>heartbeat1.heartbeat_at && heartbeat3.heartbeat_at>heartbeat2.heartbeat_at;
         if(number==7) passed=chain && heartbeat1.expires_at>acquired.expires_at &&
                                      heartbeat2.expires_at>heartbeat1.expires_at && heartbeat3.expires_at>heartbeat2.expires_at;
         if(number==8) passed=chain && SWV5_TestOwnerEqual(acquired.fence.owner,heartbeat3.fence.owner) &&
                                      SWV5_TestOwnershipKeyEqual(acquired.fence.ownership_namespace,heartbeat3.fence.ownership_namespace) &&
                                      acquired.fence.takeover_generation==heartbeat3.fence.takeover_generation &&
                                      acquired.clock_id==heartbeat3.clock_id && acquired.clock_authority==heartbeat3.clock_authority &&
                                      SWV5_TestFenceEqual(acquired.fence,heartbeat1.fence) &&
                                      SWV5_TestFenceEqual(heartbeat1.fence,heartbeat2.fence) &&
                                      SWV5_TestFenceEqual(heartbeat2.fence,heartbeat3.fence) &&
                                      acquired.store_revision!=heartbeat1.store_revision &&
                                      heartbeat1.store_revision!=heartbeat2.store_revision &&
                                      heartbeat2.store_revision!=heartbeat3.store_revision;
         if(number==1) expected="valid_unclaimed_acquire";
         if(number==2) expected="heartbeat_one_accepts_acquired";
         if(number==3) expected="heartbeat_two_accepts_returned_renewed";
         if(number==4) expected="heartbeat_three_accepts_returned_renewed";
         if(number==5) expected="heartbeat_sequence_monotonic_lease_authority_stable";
         if(number==6) expected="authoritative_heartbeat_time_advances";
         if(number==7) expected="expiry_extends_each_renewal";
         if(number==8) expected="owner_namespace_generation_stable_revisions_coherent";
      }
      else if(number<=16)
      {
         SWV5_ContractValidationContext context;
         SWV5_TestMakeContext(context);
         SWV5_InstanceLease observed;
         SWV5_TestMakeLease(observed);
         SWV5_InstanceLease caller=observed;
         if(number==9) caller.fence.owner.instance_id="WRONG-OWNER";
         if(number==10) { caller.fence.ownership_namespace.server="FOREIGN-SERVER"; caller.fence.owner.key.server="FOREIGN-SERVER"; }
         if(number==11) caller.fence.fencing_token_digest="STALE-FENCE";
         if(number==12) caller.fence.lease_version--;
         if(number==13) caller.heartbeat_sequence--;
         if(number==14) context.clock_sequence=observed.heartbeat_clock_sequence;
         if(number==15) caller.store_revision="STALE-STORE-REVISION";
         if(number==16) { context.clock_time=observed.expires_at; context.clock_sequence=observed.expiry_clock_sequence; }
         SWV5_TestOwnershipContract implementation;
         SWV5_OwnershipDecision decision;
         const bool rejected=!implementation.Heartbeat(context,caller,observed,decision);
         passed=rejected && SWV5_TestInstanceLeaseEqual(decision.resulting_lease,observed);
         if(number==9) expected="wrong_owner_rejected_without_mutation";
         if(number==10) expected="foreign_namespace_rejected_without_mutation";
         if(number==11) expected="stale_fence_rejected_without_mutation";
         if(number==12) expected="stale_lease_version_rejected_without_mutation";
         if(number==13) expected="regressed_heartbeat_sequence_rejected";
         if(number==14) expected="regressed_clock_sequence_rejected";
         if(number==15) expected="store_revision_mismatch_rejected";
         if(number==16) expected="expired_beyond_renewal_policy_rejected";
      }
      else if(number<=31)
      {
         SWV5_ContractValidationContext context;
         SWV5_InstanceLease observed;
         SWV5_OwnershipClaim claim;
         SWV5_TestMakeExpiredTakeoverFixture(context,observed,claim);
         if(number==18) claim.takeover_evidence.proposed_takeover_generation=observed.fence.takeover_generation;
         if(number==19) claim.takeover_evidence.proposed_takeover_generation=observed.fence.takeover_generation-1;
         if(number==20) claim.takeover_evidence.lease_expiry.observed_ownership_key.server="OTHER-SERVER";
         if(number==21) claim.takeover_evidence.observed_ownership_namespace.server="OTHER-SERVER";
         if(number==22) claim.takeover_evidence.lease_expiry.observed_lease_version--;
         if(number==23) claim.takeover_evidence.observed_store_revision="STALE-STORE-REVISION";
         if(number==24) claim.takeover_evidence.lease_expiry.observed_heartbeat_sequence--;
         if(number==25) claim.takeover_evidence.observed_clock_id="OTHER-CLOCK";
         if(number==26) claim.takeover_evidence.lease_expiry.clock_authority=SWV5_TIME_AUTHORITY_DURABLE_STORE;
         if(number==27) claim.takeover_evidence.lease_expiry.observed_expiry_time--;
         if(number==28) claim.takeover_evidence.broker_reconciliation.state_digest="";
         if(number==29) claim.takeover_evidence.persistence_reconciliation.evidence_id="";
         if(number==30) { claim.takeover_evidence.authority=SWV5_COMPONENT_AUTHORITY_EXECUTION; claim.takeover_evidence.independent_authority_source=SWV5_AUTHORITY_TRANSACTION_EVENT; }
         SWV5_TestOwnershipContract implementation;
         SWV5_OwnershipDecision decision;
         const bool acquired_ok=implementation.Acquire(context,claim,observed,decision);
         if(number==17)
            passed=acquired_ok && decision.resulting_lease.status==SWV5_LOCK_ACQUIRED;
         else if(number==31)
         {
            SWV5_ContractValidationContext heartbeat_context=context;
            heartbeat_context.clock_sequence+=10;
            heartbeat_context.clock_time+=10;
            SWV5_OwnershipDecision heartbeat;
            passed=acquired_ok && decision.resulting_lease.fence.takeover_generation==claim.takeover_evidence.proposed_takeover_generation &&
                   decision.resulting_lease.fence.lease_version==observed.fence.lease_version+1 &&
                   decision.resulting_lease.store_revision!=observed.store_revision &&
                   SWV5_TestOwnerEqual(decision.resulting_lease.fence.owner,claim.claimant) &&
                   implementation.Heartbeat(heartbeat_context,decision.resulting_lease,decision.resulting_lease,heartbeat) &&
                   heartbeat.resulting_lease.status==SWV5_LOCK_RENEWED;
         }
         else
            passed=!acquired_ok && SWV5_TestInstanceLeaseEqual(decision.resulting_lease,observed);
         if(number==17) expected="valid_expired_takeover_succeeds";
         if(number==18) expected="same_generation_rejected";
         if(number==19) expected="lower_generation_rejected";
         if(number==20) expected="nested_ownership_key_mismatch_rejected";
         if(number==21) expected="top_level_namespace_mismatch_rejected";
         if(number==22) expected="nested_lease_version_mismatch_rejected";
         if(number==23) expected="top_level_store_revision_mismatch_rejected";
         if(number==24) expected="nested_heartbeat_sequence_mismatch_rejected";
         if(number==25) expected="top_level_clock_id_mismatch_rejected";
         if(number==26) expected="nested_clock_authority_mismatch_rejected";
         if(number==27) expected="nested_expiry_timestamp_mismatch_rejected";
         if(number==28) expected="broker_reconciliation_incomplete_rejected";
         if(number==29) expected="persistence_reconciliation_incomplete_rejected";
         if(number==30) expected="self_attested_non_independent_authority_rejected";
         if(number==31) expected="takeover_result_coherent_and_heartbeat_usable";
      }
      else
      {
         SWV5_TestRiskContract risk;
         SWV5_RiskEvaluationInput current;
         SWV5_TestMakeRiskInput(current);
         SWV5_RiskAuthorization authorization;
         SWV5_ContractDecision risk_decision;
         if(number==32)
         {
            SWV5_InstanceLease acquired,heartbeat1,heartbeat2,heartbeat3;
            const bool chain=SWV5_TestBuildHeartbeatChain(acquired,heartbeat1,heartbeat2,heartbeat3);
            current.ownership_fence=acquired.fence;
            current.intent.ownership_fence=acquired.fence;
            current.basket.lifecycle.ownership_fence=acquired.fence;
            SWV5_TestRefreshRiskInputBindings(current);
            SWV5_ContractValidationContext evaluation_context;
            SWV5_TestMakeContext(evaluation_context);
            const bool evaluated=chain && risk.Evaluate(evaluation_context,current,authorization);
            current.ownership_fence=heartbeat1.fence;
            current.intent.ownership_fence=heartbeat1.fence;
            current.basket.lifecycle.ownership_fence=heartbeat1.fence;
            SWV5_TestRefreshRiskInputBindings(current);
            SWV5_ContractValidationContext heartbeat_context=evaluation_context;
            heartbeat_context.clock_time+=10;
            heartbeat_context.clock_sequence+=10;
            passed=evaluated && SWV5_TestFenceEqual(acquired.fence,heartbeat1.fence) &&
                   risk.ValidateAuthorization(heartbeat_context,authorization,current,risk_decision);
            expected="same_owner_heartbeat_preserves_risk_authorization_fence";
         }
         else
         {
            SWV5_ContractValidationContext context;
            SWV5_InstanceLease observed;
            SWV5_OwnershipClaim claim;
            SWV5_TestMakeExpiredTakeoverFixture(context,observed,claim);
            current.ownership_fence=observed.fence;
            current.intent.ownership_fence=observed.fence;
            current.basket.lifecycle.ownership_fence=observed.fence;
            const bool evaluated=risk.Evaluate(context,current,authorization);
            SWV5_TestOwnershipContract ownership;
            SWV5_OwnershipDecision takeover;
            const bool acquired=ownership.Acquire(context,claim,observed,takeover);
            current.ownership_fence=takeover.resulting_lease.fence;
            current.intent.ownership_fence=takeover.resulting_lease.fence;
            current.basket.lifecycle.ownership_fence=takeover.resulting_lease.fence;
            passed=evaluated && acquired &&
                   !SWV5_TestFenceEqual(authorization.ownership_fence,takeover.resulting_lease.fence) &&
                   !risk.ValidateAuthorization(context,authorization,current,risk_decision);
            expected="takeover_invalidates_stale_owner_authorization";
         }
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S45DO",number),"SPRINT4_5_OWNERSHIP_LIFECYCLE",passed,expected);
   }
}

// Phase D Persistence trace: typed length-prefixed canonical payloads, ordered request binding,
// tamper rejection, deterministic empty/replay behavior, and replacement-summary coherence.
void SWV5_RunSprint45PersistenceCanonicalTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=16;number++)
   {
      if(!SWV5_TestIdSelected(SWV5_TestCaseId("S45DP",number))) continue;
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_TestPersistenceContract persistence;
      SWV5_ContractDecision decision;
      SWV5_PersistenceLoadResult load_result;
      SWV5_PersistedRequestEvidence requests[];
      ArrayResize(requests,2);
      SWV5_TestMakePersistedRequest(requests[0],1);
      SWV5_TestMakePersistedRequest(requests[1],2);
      bool passed=false;
      string expected="fail_closed";
      if(number==1 || number==2 || number==3)
      {
         SWV5_PersistedRequestEvidence left=requests[0];
         SWV5_PersistedRequestEvidence right=requests[0];
         if(number==1) { left.pending_request.latest_retcode.broker_comment="A|B"; right.pending_request.latest_retcode.broker_comment="A"; right.pending_request.normalization_identity="B|"+right.pending_request.normalization_identity; }
         if(number==2) { left.pending_request.latest_retcode.broker_comment="alpha:beta, spaced\nUnicode-ทดสอบ"; right.pending_request.latest_retcode.broker_comment="alpha"; right.pending_request.normalization_identity="beta, spaced\nUnicode-ทดสอบ:"+right.pending_request.normalization_identity; }
         if(number==3)
         {
            left.pending_request.intent.request_identity.request_id.correlation_id="A|B";
            left.pending_request.intent.request_identity.request_id.attempt_id="C";
            right.pending_request.intent.request_identity.request_id.correlation_id="A";
            right.pending_request.intent.request_identity.request_id.attempt_id="B|C";
            const string naive_left=left.pending_request.intent.request_identity.request_id.correlation_id+"|"+left.pending_request.intent.request_identity.request_id.attempt_id;
            const string naive_right=right.pending_request.intent.request_identity.request_id.correlation_id+"|"+right.pending_request.intent.request_identity.request_id.attempt_id;
            passed=naive_left==naive_right && SWV5_TestCanonicalPersistedRequest(left)!=SWV5_TestCanonicalPersistedRequest(right);
         }
         else
            passed=SWV5_TestCanonicalPersistedRequest(left)!=SWV5_TestCanonicalPersistedRequest(right);
         expected=(number==1 ? "pipe_content_collision_safe" : (number==2 ? "colon_unicode_line_content_collision_safe" : "deliberate_naive_collision_separated"));
      }
      else if(number>=4 && number<=7)
      {
         const string original=SWV5_TestRequestSetDigest(requests);
         if(number==4) requests[0].pending_request.latest_retcode.broker_comment="ONE-NESTED-STRING-CHANGED";
         if(number==5) requests[0].pending_request.intent.normalized_price+=0.05;
         if(number==6) requests[0].pending_request.accepted_event_identities.canonical_fingerprint_index="FINGERPRINT-CHANGED";
         if(number==7)
         {
            SWV5_PersistedRequestEvidence swap=requests[0];
            requests[0]=requests[1];
            requests[1]=swap;
         }
         passed=original!=SWV5_TestRequestSetDigest(requests);
         if(number==4) expected="nested_string_changes_digest";
         if(number==5) expected="nested_numeric_changes_digest";
         if(number==6) expected="event_fingerprint_changes_digest";
         if(number==7) expected="request_order_changes_digest";
      }
      else if(number>=8 && number<=12)
      {
         SWV5_PersistedRequestSetHeader header;
         SWV5_TestBindRequestSetHeader(header,requests,40);
         if(number==8)
         {
            SWV5_PersistedRequestEvidence other[];
            ArrayResize(other,1);
            other[0]=requests[0];
            header.request_set_digest=SWV5_TestRequestSetDigest(other);
         }
         if(number==9) header.request_count++;
         if(number==10) requests[1].record_sequence=requests[0].record_sequence;
         if(number==11) requests[1].persistence_namespace.ownership_namespace.server="FOREIGN-SERVER";
         if(number==12)
         {
            SWV5_PersistedRequestEvidence first[];
            ArrayResize(first,1);
            first[0]=requests[0];
            SWV5_PersistedRequestSetHeader first_header;
            SWV5_TestBindRequestSetHeader(first_header,first,40);
            const bool first_saved=persistence.SavePendingRequests(context,first[0].persistence_namespace,first,first_header,decision);
            SWV5_TestBindRequestSetHeader(header,requests,40);
            passed=first_saved && !persistence.SavePendingRequests(context,requests[0].persistence_namespace,requests,header,decision);
         }
         else
            passed=!persistence.SavePendingRequests(context,requests[0].persistence_namespace,requests,header,decision);
         if(number==8) expected="copied_digest_from_other_payload_rejected";
         if(number==9) expected="request_count_mismatch_rejected";
         if(number==10) expected="record_sequence_mismatch_rejected";
         if(number==11) expected="request_namespace_mismatch_rejected";
         if(number==12) expected="stale_request_index_revision_rejected";
      }
      else if(number==13 || number==14)
      {
         if(number==13)
         {
            SWV5_PersistedRequestEvidence empty_a[],empty_b[],nonempty[];
            ArrayResize(empty_a,0);
            ArrayResize(empty_b,0);
            ArrayResize(nonempty,1);
            SWV5_TestMakePersistedRequest(nonempty[0],1);
            const string canonical_a=SWV5_TestCanonicalRequestSet(empty_a);
            const string canonical_b=SWV5_TestCanonicalRequestSet(empty_b);
            const string digest_a=SWV5_TestRequestSetDigest(empty_a);
            const string digest_b=SWV5_TestRequestSetDigest(empty_b);
            passed=canonical_a==canonical_b && digest_a==digest_b && canonical_a!="" && digest_a!="" &&
                   canonical_a!=SWV5_TestCanonicalRequestSet(nonempty) && digest_a!=SWV5_TestRequestSetDigest(nonempty);
            expected="independent_empty_sets_stable_and_distinct_from_nonempty";
         }
         else
         {
            SWV5_PersistedRequestEvidence independently_built[];
            ArrayResize(independently_built,2);
            SWV5_TestMakePersistedRequest(independently_built[0],1);
            SWV5_TestMakePersistedRequest(independently_built[1],2);
            const string canonical_original=SWV5_TestCanonicalRequestSet(requests);
            const string digest_original=SWV5_TestRequestSetDigest(requests);
            const bool independent_equal=canonical_original==SWV5_TestCanonicalRequestSet(independently_built) &&
                                         digest_original==SWV5_TestRequestSetDigest(independently_built);
            independently_built[1].pending_request.latest_retcode.broker_comment="ADVERSARIAL-MUTATION";
            passed=independent_equal &&
                   canonical_original!=SWV5_TestCanonicalRequestSet(independently_built) &&
                   digest_original!=SWV5_TestRequestSetDigest(independently_built);
            expected="independent_serialization_equal_and_nested_mutation_distinct";
         }
      }
      else if(number==15)
      {
         SWV5_PersistedRequestEvidence saved[];
         ArrayResize(saved,1);
         saved[0]=requests[0];
         SWV5_PersistedRequestSetHeader header;
         SWV5_TestBindRequestSetHeader(header,saved,40);
         SWV5_PersistedRequestEvidence loaded[];
         passed=persistence.SavePendingRequests(context,saved[0].persistence_namespace,saved,header,decision) &&
                persistence.LoadPendingRequests(context,saved[0].persistence_namespace,loaded,load_result) &&
                ArraySize(loaded)==1 && SWV5_TestPersistedRequestEqual(saved[0],loaded[0]);
         expected="save_a_load_a_round_trip";
      }
      else if(number==16)
      {
         SWV5_PersistedCheckpoint checkpoint;
         SWV5_TestMakeCheckpoint(checkpoint);
         SWV5_PersistedRequestEvidence empty[];
         ArrayResize(empty,0);
         persistence.Configure(checkpoint,empty);
         SWV5_PersistedRequestEvidence set_a[],set_b[];
         ArrayResize(set_a,1);
         ArrayResize(set_b,1);
         set_a[0]=requests[0];
         set_b[0]=requests[1];
         SWV5_PersistedRequestSetHeader header_a,header_b;
         SWV5_TestBindRequestSetHeader(header_a,set_a,40);
         SWV5_TestBindRequestSetHeader(header_b,set_b,41);
         SWV5_PersistedRequestEvidence loaded[];
         SWV5_PersistedCheckpoint loaded_checkpoint;
         const bool saved_a=persistence.SavePendingRequests(context,checkpoint.header.persistence_namespace,set_a,header_a,decision);
         const bool saved_b=persistence.SavePendingRequests(context,checkpoint.header.persistence_namespace,set_b,header_b,decision);
         passed=saved_a && saved_b &&
                persistence.LoadPendingRequests(context,checkpoint.header.persistence_namespace,loaded,load_result) && ArraySize(loaded)==1 &&
                SWV5_TestPersistedRequestEqual(loaded[0],set_b[0]) && !SWV5_TestPersistedRequestEqual(loaded[0],set_a[0]) &&
                persistence.LoadLatest(context,checkpoint.header.persistence_namespace,loaded_checkpoint,load_result) &&
                loaded_checkpoint.has_latest_pending_request &&
                SWV5_TestPersistedRequestEqual(loaded_checkpoint.latest_pending_request,set_b[0]) &&
                loaded_checkpoint.pending_request_set.request_count==1 &&
                loaded_checkpoint.pending_request_set.request_set_digest==header_b.request_set_digest &&
                loaded_checkpoint.pending_request_set.request_index_revision==header_b.request_index_revision;
         expected="save_b_replaces_a_without_stale_summary";
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S45DP",number),"SPRINT4_5_PERSISTENCE_CANONICAL",passed,expected);
   }
}

bool SWV5_TestRiskRejectsAndClearsAuthorization(SWV5_TestRiskContract &implementation,
                                                const SWV5_ContractValidationContext &context,
                                                const SWV5_RiskEvaluationInput &engineInput)
{
   SWV5_RiskAuthorization authorization;
   SWV5_TestMakeRiskAuthorization(authorization);
   return !implementation.Evaluate(context,engineInput,authorization) &&
          authorization.disposition!=SWV5_RISK_ALLOW &&
          authorization.authorization_id=="" && authorization.request_identity.request_id.correlation_id=="" &&
          authorization.persistence_namespace.basket_id.value=="" && authorization.hard_kill_latch_id=="" &&
          MathAbs(authorization.authorized_volume)<=context.volume_tolerance &&
          MathAbs(authorization.authorized_projected_margin)<=context.price_tolerance;
}

// Sprint 4.6 Phase B Risk trace. Every negative case starts with SWV5_TestMakeRiskInput,
// mutates exactly the named field, calls Evaluate, and requires a cleared non-ALLOW output.
// S46BR-02 intent_type; 03 direction; 04/05 volume; 06 price; 07 stop; 08 cancel type; 09 expiry.
// S46BR-10 projected_volume; 11 symbol volume; 12 aggregate volume; 13 notional; 14 margin; 15 maximum loss.
// S46BR-16 basket<=symbol relation; 17 symbol<=aggregate; 18 request margin cap; 19 current+additional cap.
// S46BR-20 usable free margin; 21 account age; 22 exposure age; 23 Basket age; 24 projection age; 25 valuation age.
// S46BR-26 epoch; 27 monetary completeness; 28 Hard Kill; 29 account mode; 30 namespace; 31 exact nested version.
// Removing the corresponding predicate makes the named case produce an unsafe ALLOW or complete-looking authorization.
void SWV5_RunSprint46RiskSafetyTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=31;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_RiskEvaluationInput engineInput;
      SWV5_TestMakeRiskInput(engineInput);
      SWV5_TestRiskContract implementation;
      SWV5_RiskAuthorization authorization;
      SWV5_ContractDecision decision;
      bool passed=false;
      string expected="fail_closed";
      if(number==1)
      {
         passed=implementation.Evaluate(context,engineInput,authorization) &&
                authorization.disposition==SWV5_RISK_ALLOW &&
                authorization.blocking_domain==SWV5_RISK_DOMAIN_NONE && authorization.reason_flags==0 &&
                authorization.authorization_id==engineInput.intent.risk_authorization_id &&
                implementation.ValidateAuthorization(context,authorization,engineInput,decision);
         expected="complete_safe_input_allowed";
      }
      else
      {
         if(number==2) engineInput.intent.intent_type=(SWV5_ExecutionIntentType)99;
         if(number==3) engineInput.intent.direction=2;
         if(number==4) engineInput.intent.normalized_volume=0.0;
         if(number==5) engineInput.intent.normalized_volume=-0.10;
         if(number==6) engineInput.intent.normalized_price=0.0;
         if(number==7) engineInput.intent.normalized_stop_price=engineInput.intent.normalized_price+1.0;
         if(number==8) engineInput.intent.intent_type=SWV5_INTENT_CANCEL_PENDING;
         if(number==9) engineInput.intent.authorization_expires_at=context.clock_time-1;
         if(number==10) engineInput.projected.projected_volume=-0.01;
         if(number==11) engineInput.projected.projected_symbol_volume=-0.01;
         if(number==12) engineInput.projected.projected_aggregate_volume=-0.01;
         if(number==13) engineInput.projected.projected_notional=-1.0;
         if(number==14) engineInput.projected.projected_margin=-1.0;
         if(number==15) engineInput.projected.projected_maximum_loss=-1.0;
         if(number==16) engineInput.projected.projected_volume=engineInput.projected.projected_symbol_volume+0.01;
         if(number==17) engineInput.projected.projected_symbol_volume=engineInput.projected.projected_aggregate_volume+0.01;
         if(number==18) engineInput.projected.projected_margin=engineInput.account.equity*engineInput.limits.maximum_account_margin_fraction+1.0;
         if(number==19) engineInput.projected.projected_margin=engineInput.account.equity*engineInput.limits.maximum_account_margin_fraction-engineInput.account.margin+1.0;
         if(number==20) engineInput.account.free_margin=engineInput.projected.projected_margin-1.0;
         if(number==21) engineInput.account.observed_at=context.clock_time-(datetime)engineInput.limits.maximum_snapshot_age_seconds-1;
         if(number==22) engineInput.exposure.observed_at=context.clock_time-(datetime)engineInput.limits.maximum_snapshot_age_seconds-1;
         if(number==23) engineInput.basket.observed_at=context.clock_time-(datetime)engineInput.limits.maximum_snapshot_age_seconds-1;
         if(number==24) engineInput.projected.calculated_at=context.clock_time-(datetime)engineInput.limits.maximum_snapshot_age_seconds-1;
         if(number==25) engineInput.projected.monetary_basis.valuation_at=context.clock_time-(datetime)engineInput.limits.maximum_snapshot_age_seconds-1;
         if(number==26) engineInput.exposure.account_namespace.snapshot_epoch++;
         if(number==27) engineInput.projected.monetary_basis.includes_fee=false;
         if(number==28) engineInput.hard_kill_state.state=SWV5_HARD_KILL_ACTIVE;
         if(number==29) engineInput.account_mode=SWV5_ACCOUNT_MODE_NETTING;
         if(number==30) engineInput.projected.account_namespace.broker_identity="FOREIGN-BROKER";
         if(number==31) SWV5_TestSetForeignContractIdentity(engineInput.projected.contract_version);
         passed=SWV5_TestRiskRejectsAndClearsAuthorization(implementation,context,engineInput);
         if(number==2) expected="invalid_intent_enum_rejected";
         if(number==3) expected="invalid_direction_rejected";
         if(number==4) expected="zero_trading_volume_rejected";
         if(number==5) expected="negative_trading_volume_rejected";
         if(number==6) expected="zero_required_price_rejected";
         if(number==7) expected="contradictory_stop_rejected";
         if(number==8) expected="cancel_with_trading_terms_rejected";
         if(number==9) expected="expired_intent_authorization_rejected";
         if(number==10) expected="negative_projected_volume_rejected";
         if(number==11) expected="negative_projected_symbol_volume_rejected";
         if(number==12) expected="negative_projected_aggregate_volume_rejected";
         if(number==13) expected="negative_projected_notional_rejected";
         if(number==14) expected="negative_projected_margin_rejected";
         if(number==15) expected="negative_projected_loss_rejected";
         if(number==16) expected="basket_projection_above_symbol_rejected";
         if(number==17) expected="symbol_projection_above_aggregate_rejected";
         if(number==18) expected="projected_margin_above_account_cap_rejected";
         if(number==19) expected="current_plus_additional_margin_above_cap_rejected";
         if(number==20) expected="projected_margin_above_free_margin_rejected";
         if(number==21) expected="stale_account_snapshot_rejected";
         if(number==22) expected="stale_exposure_snapshot_rejected";
         if(number==23) expected="stale_basket_snapshot_rejected";
         if(number==24) expected="stale_projected_snapshot_rejected";
         if(number==25) expected="stale_monetary_valuation_rejected";
         if(number==26) expected="mixed_epoch_rejected";
         if(number==27) expected="incomplete_monetary_basis_rejected";
         if(number==28) expected="active_hard_kill_rejected";
         if(number==29) expected="account_mode_mismatch_rejected";
         if(number==30) expected="account_namespace_mismatch_rejected";
         if(number==31) expected="foreign_nested_contract_rejected";
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S46BR",number),"SPRINT4_6_RISK_SAFETY",passed,expected);
   }
}

// Sprint 4.6 Phase B Hard Kill trace. Every negative case starts with one complete
// RELEASE_PENDING state, mutates exactly one field, invokes ValidateHardKillRelease,
// and requires rejection. The cases detect omitted context/version, namespace,
// time-order, authority, latch-generation, and exposure-reduction predicates.
void SWV5_RunSprint46HardKillReleaseTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=40;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_HardKillState state;
      SWV5_TestMakeValidHardKillRelease(state);
      SWV5_HardKillReleaseEvidence evidence=state.release_evidence;
      SWV5_TestRiskContract implementation;
      SWV5_ContractDecision decision;
      bool passed=false;
      string expected="fail_closed";
      if(number==1)
      {
         passed=implementation.ValidateHardKillRelease(context,state,evidence,decision) &&
                decision.disposition==SWV5_DISPOSITION_ALLOW;
         expected="complete_release_evidence_accepted";
      }
      else
      {
         if(number==2) context.clock_sequence=0;
         if(number==3) state.contract_version.schema_version--;
         if(number==4) evidence.contract_version.schema_version--;
         if(number==5) evidence.broker_evidence.contract_version.schema_version--;
         if(number==6) evidence.persistence_namespace.basket_id.value="FOREIGN-BASKET";
         if(number==7) evidence.persistence_namespace.ownership_namespace.broker_identity="FOREIGN-BROKER";
         if(number==8) evidence.persistence_namespace.ownership_namespace.server="FOREIGN-SERVER";
         if(number==9) evidence.persistence_namespace.ownership_namespace.account_login++;
         if(number==10) evidence.broker_evidence.observed_at=evidence.operator_identity.authenticated_at-1;
         if(number==11) evidence.persistence_evidence.observed_at=evidence.operator_identity.authenticated_at-1;
         if(number==12) evidence.exposure_evidence.observed_at=evidence.operator_identity.authenticated_at-1;
         if(number==13) evidence.broker_evidence.observed_at=0;
         if(number==14) evidence.operator_identity.authenticated_at=evidence.approved_at+1;
         if(number==15) evidence.expires_at=context.clock_time-1;
         if(number==16) evidence.approving_component=SWV5_COMPONENT_AUTHORITY_EXECUTION;
         if(number==17) evidence.broker_evidence.authority_source=SWV5_AUTHORITY_PERSISTED_CHECKPOINT;
         if(number==18) evidence.persistence_evidence.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
         if(number==19) evidence.exposure_evidence.authority_source=SWV5_AUTHORITY_NONE;
         if(number==20) evidence.latch_id="FOREIGN-LATCH";
         if(number==21) evidence.latch_generation++;
         if(number==22) evidence.release_generation=state.release_generation;
         if(number==23) evidence.exposure_evidence.observed_exposure_volume=evidence.exposure_evidence.prior_exposure_volume+0.01;
         if(number==24) evidence.exposure_evidence.zero_or_reducing=false;
         if(number==25) state.state=SWV5_HARD_KILL_ACTIVE;
         if(number==26) evidence.release_id="";
         if(number==27) evidence.audit_reference="";
         if(number==28) evidence.approved_at=context.clock_time+1;
         if(number==29) state.account_namespace.account_mode=SWV5_ACCOUNT_MODE_NETTING;
         if(number==30) SWV5_TestSetForeignContractIdentity(evidence.exposure_evidence.contract_version);
         if(number==31) evidence.broker_evidence.persistence_namespace.basket_id.value="FOREIGN-BASKET";
         if(number==32) evidence.operator_identity.authenticated_at=0;
         if(number==33) evidence.expires_at=evidence.approved_at;
         if(number==34) evidence.approving_component=SWV5_COMPONENT_AUTHORITY_NONE;
         if(number==35) evidence.broker_evidence.issuing_component=SWV5_COMPONENT_AUTHORITY_EXECUTION;
         if(number==36) evidence.persistence_evidence.issuing_component=SWV5_COMPONENT_AUTHORITY_EXECUTION;
         if(number==37) evidence.exposure_evidence.issuing_component=SWV5_COMPONENT_AUTHORITY_EXECUTION;
         if(number==38) evidence.exposure_evidence.prior_exposure_volume=-0.01;
         if(number==39) evidence.exposure_evidence.observed_exposure_volume=-0.01;
         if(number==40) evidence.exposure_evidence.evidence_sequence=0;
         passed=!implementation.ValidateHardKillRelease(context,state,evidence,decision) &&
                decision.disposition!=SWV5_DISPOSITION_ALLOW;
         if(number==2) expected="invalid_context_rejected";
         if(number==3) expected="wrong_state_contract_version_rejected";
         if(number==4) expected="wrong_release_contract_version_rejected";
         if(number==5) expected="wrong_broker_nested_version_rejected";
         if(number==6) expected="foreign_release_namespace_rejected";
         if(number==7) expected="wrong_broker_rejected";
         if(number==8) expected="wrong_server_rejected";
         if(number==9) expected="wrong_account_rejected";
         if(number==10) expected="stale_broker_evidence_rejected";
         if(number==11) expected="stale_persistence_evidence_rejected";
         if(number==12) expected="stale_exposure_evidence_rejected";
         if(number==13) expected="zero_observation_time_rejected";
         if(number==14) expected="authentication_after_approval_rejected";
         if(number==15) expected="expired_approval_rejected";
         if(number==16) expected="execution_approval_rejected";
         if(number==17) expected="wrong_broker_authority_rejected";
         if(number==18) expected="wrong_persistence_authority_rejected";
         if(number==19) expected="wrong_exposure_authority_rejected";
         if(number==20) expected="latch_id_mismatch_rejected";
         if(number==21) expected="latch_generation_mismatch_rejected";
         if(number==22) expected="non_monotonic_release_generation_rejected";
         if(number==23) expected="exposure_increase_rejected";
         if(number==24) expected="zero_or_reducing_contradiction_rejected";
         if(number==25) expected="non_pending_state_rejected";
         if(number==26) expected="empty_release_id_rejected";
         if(number==27) expected="empty_audit_reference_rejected";
         if(number==28) expected="future_approval_rejected";
         if(number==29) expected="unsupported_account_mode_rejected";
         if(number==30) expected="foreign_exposure_contract_rejected";
         if(number==31) expected="nested_broker_namespace_rejected";
         if(number==32) expected="zero_authentication_time_rejected";
         if(number==33) expected="non_positive_release_window_rejected";
         if(number==34) expected="missing_approver_rejected";
         if(number==35) expected="wrong_broker_component_rejected";
         if(number==36) expected="wrong_persistence_component_rejected";
         if(number==37) expected="wrong_exposure_component_rejected";
         if(number==38) expected="negative_prior_exposure_rejected";
         if(number==39) expected="negative_observed_exposure_rejected";
         if(number==40) expected="zero_exposure_sequence_rejected";
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S46BH",number),"SPRINT4_6_HARD_KILL_RELEASE",passed,expected);
   }
}

// Sprint 4.6 Phase C checkpoint trace. S46CP-01 proves a sealed baseline.
// S46CP-02..16 mutate one persisted safety field or integrity-envelope member
// without resealing and require fail-closed validation. S46CP-17..20 prove
// deterministic serialization, delimiter/Unicode safety, round trip, and copy isolation.
void SWV5_RunSprint46CheckpointIntegrityTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=20;number++)
   {
      SWV5_PersistedCheckpoint checkpoint;
      SWV5_TestMakeCheckpoint(checkpoint);
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_TestPersistenceContract persistence;
      SWV5_PersistenceLoadResult load_result;
      SWV5_ContractDecision decision;
      bool passed=false;
      string expected="mutation_rejected";
      if(number==1)
      {
         passed=SWV5_TestPersistenceRecordValid(context,checkpoint) &&
                checkpoint.header.payload_digest==SWV5_TestCheckpointPayloadDigest(checkpoint) &&
                checkpoint.header.payload_size==SWV5_TestCheckpointPayloadSize(checkpoint);
         expected="valid_canonical_checkpoint";
      }
      else if(number>=2 && number<=12)
      {
         if(number==2) checkpoint.header.payload_digest="";
         if(number==3) checkpoint.header.payload_digest="ARBITRARY-NONEMPTY-FAKE";
         if(number==4) checkpoint.basket.lifecycle.state=SWV5_BASKET_RECOVERY;
         if(number==5) checkpoint.basket.lifecycle.cumulative_recovery_attempts++;
         if(number==6) checkpoint.header.ownership_fence.fencing_token_digest="MUTATED-FENCE";
         if(number==7) checkpoint.latest_pending_request.pending_request.authorization_identity="MUTATED-PENDING";
         if(number==8) checkpoint.latest_pending_request.pending_request.cumulative_confirmed_volume+=0.01;
         if(number==9) checkpoint.hard_kill_state.latch_generation++;
         if(number==10) checkpoint.header.persistence_namespace.ownership_namespace.server="MUTATED-SERVER";
         if(number==11) checkpoint.latest_pending_request.pending_request.accepted_event_identities.canonical_fingerprint_index="MUTATED-FINGERPRINT";
         if(number==12) checkpoint.header.payload_size++;
         passed=!persistence.ValidateRecord(context,checkpoint,load_result) && load_result.status==SWV5_PERSISTENCE_CHECKSUM_FAILED;
         if(number==2) expected="empty_digest_rejected";
         if(number==3) expected="nonempty_fake_digest_rejected";
         if(number==4) expected="stale_digest_after_basket_state_mutation";
         if(number==5) expected="stale_digest_after_recovery_counter_mutation";
         if(number==6) expected="stale_digest_after_ownership_fence_mutation";
         if(number==7) expected="stale_digest_after_pending_request_mutation";
         if(number==8) expected="stale_digest_after_confirmed_volume_mutation";
         if(number==9) expected="stale_digest_after_hard_kill_generation_mutation";
         if(number==10) expected="stale_digest_after_namespace_mutation";
         if(number==11) expected="stale_digest_after_event_fingerprint_mutation";
         if(number==12) expected="wrong_payload_size_rejected";
      }
      else if(number==13)
      {
         SWV5_PersistedCheckpoint other;
         SWV5_TestMakeCheckpoint(other);
         checkpoint.latest_pending_request.pending_request.authorization_identity="AUTH|:;, spaces\n雪";
         other.latest_pending_request.pending_request.authorization_identity="AUTH|:;, spaces\n雪";
         SWV5_TestSealCheckpoint(checkpoint); SWV5_TestSealCheckpoint(other);
         passed=SWV5_TestPersistenceRecordValid(context,checkpoint) && SWV5_TestPersistenceRecordValid(context,other) &&
                checkpoint.header.payload_digest==other.header.payload_digest && checkpoint.header.payload_size==other.header.payload_size;
         expected="unicode_delimiter_payload_deterministic";
      }
      else if(number==14)
      {
         SWV5_PersistedCheckpoint other;
         SWV5_TestMakeCheckpoint(other);
         passed=SWV5_TestCanonicalCheckpointPayload(checkpoint)==SWV5_TestCanonicalCheckpointPayload(other) &&
                checkpoint.header.payload_digest==other.header.payload_digest;
         expected="identical_payload_identical_serialization_digest";
      }
      else if(number==15)
      {
         checkpoint.latest_pending_request.pending_request.authorization_identity="NESTED-A";
         SWV5_TestSealCheckpoint(checkpoint);
         const string digest_a=checkpoint.header.payload_digest;
         checkpoint.latest_pending_request.pending_request.authorization_identity="NESTED-B";
         passed=!SWV5_TestPersistenceRecordValid(context,checkpoint) && digest_a!=SWV5_TestCheckpointPayloadDigest(checkpoint);
         expected="one_nested_character_changes_digest";
      }
      else if(number==16)
      {
         const string canonical=SWV5_TestCanonicalCheckpointPayload(checkpoint);
         SWV5_PersistedCheckpoint loaded;
         passed=persistence.SaveCheckpoint(context,checkpoint,decision) &&
                persistence.LoadLatest(context,checkpoint.header.persistence_namespace,loaded,load_result) &&
                SWV5_TestCanonicalCheckpointPayload(loaded)==canonical &&
                loaded.header.payload_digest==SWV5_TestCheckpointPayloadDigest(loaded) &&
                loaded.header.payload_size==SWV5_TestCheckpointPayloadSize(loaded);
         expected="save_load_retains_integrity";
      }
      else if(number==17)
      {
         const string saved_digest=checkpoint.header.payload_digest;
         const bool saved=persistence.SaveCheckpoint(context,checkpoint,decision);
         checkpoint.basket.lifecycle.residual_volume=9.99;
         checkpoint.hard_kill_state.latch_id="CALLER-MUTATION";
         SWV5_PersistedCheckpoint loaded;
         passed=saved && persistence.LoadLatest(context,checkpoint.header.persistence_namespace,loaded,load_result) &&
                loaded.header.payload_digest==saved_digest &&
                loaded.basket.lifecycle.residual_volume!=9.99 &&
                loaded.hard_kill_state.latch_id!="CALLER-MUTATION";
         expected="caller_mutation_cannot_change_stored_checkpoint";
      }
      else if(number==18)
      {
         SWV5_PersistedCheckpoint loaded;
         const bool saved=persistence.SaveCheckpoint(context,checkpoint,decision) &&
                          persistence.LoadLatest(context,checkpoint.header.persistence_namespace,loaded,load_result);
         loaded.basket.lifecycle.residual_volume+=0.01;
         passed=saved && !persistence.ValidateRecord(context,loaded,load_result);
         expected="corrupted_loaded_copy_rejected";
      }
      else if(number==19)
      {
         SWV5_PersistedCheckpoint other=checkpoint;
         other.basket.updated_at++;
         SWV5_TestSealCheckpoint(other);
         other.header.payload_digest=checkpoint.header.payload_digest;
         passed=!persistence.ValidateRecord(context,other,load_result);
         expected="copied_digest_from_other_checkpoint_rejected";
      }
      else if(number==20)
      {
         checkpoint.header.previous_record_sequence=checkpoint.header.record_sequence;
         SWV5_TestSealCheckpoint(checkpoint);
         passed=!persistence.ValidateRecord(context,checkpoint,load_result);
         expected="record_sequence_header_inconsistency_rejected";
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S46CP",number),"SPRINT4_6_CHECKPOINT_INTEGRITY",passed,expected);
   }
}

// Sprint 4.6 Phase C durable identity trace. Every accepted identity is a typed,
// length-prefixed entry. Exact membership and conflict classification never use
// delimiter substring search; malformed/legacy encodings fail closed.
void SWV5_RunSprint46DurableIdentityTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=20;number++)
   {
      SWV5_DurableEventIdentitySet current,next;
      SWV5_TestMakeEventIdentitySet(current,false);
      bool passed=false;
      string expected="fail_closed";
      if(number==1)
      {
         passed=SWV5_TestAppendEventIdentity("NORMAL-EVENT",100,current,next)==SWV5_STAT_IDENTITY_NEW && SWV5_TestEventSetIntegrityValid(next);
         expected="normal_event_insert";
      }
      else if(number==2)
      {
         SWV5_TestAppendEventIdentity("REPLAY-EVENT",100,current,next); current=next;
         passed=SWV5_TestAppendEventIdentity("REPLAY-EVENT",100,current,next)==SWV5_STAT_IDENTITY_DUPLICATE;
         expected="exact_replay_duplicate";
      }
      else if(number>=3 && number<=6)
      {
         string event_id="EVENT|PIPE";
         if(number==4) event_id="EVENT;SEMICOLON";
         if(number==5) event_id="EVENT:COLON";
         if(number==6) event_id="เหตุการณ์-雪";
         SWV5_BrokerExecutionIdentity identity; ZeroMemory(identity);
         identity.broker_event_id=event_id; identity.transaction_sequence=100;
         passed=SWV5_TestAppendEventIdentity(event_id,100,current,next)==SWV5_STAT_IDENTITY_NEW &&
                SWV5_TestEventIdentitySetContains(next,identity) && SWV5_TestEventSetIntegrityValid(next);
         if(number==3) expected="pipe_in_event_id_safe";
         if(number==4) expected="semicolon_in_event_id_safe";
         if(number==5) expected="colon_in_event_id_safe";
         if(number==6) expected="unicode_event_id_safe";
      }
      else if(number==7)
      {
         SWV5_DurableEventIdentitySet temp;
         SWV5_TestAppendEventIdentity("EVENT-LONG",100,current,temp); current=temp;
         const SWV5_StatisticsIdentityDisposition disposition=SWV5_TestAppendEventIdentity("EVENT",101,current,next);
         passed=disposition==SWV5_STAT_IDENTITY_NEW && SWV5_TestEventSetIntegrityValid(next);
         expected="substring_event_ids_distinct";
      }
      else if(number==8)
      {
         SWV5_BrokerExecutionIdentity false_match; ZeroMemory(false_match);
         SWV5_TestAppendEventIdentity("EVENT-400-DIGITS",7,current,next);
         false_match.broker_event_id="EVENT"; false_match.transaction_sequence=400;
         passed=!SWV5_TestEventIdentitySetContains(next,false_match);
         expected="sequence_digits_inside_id_not_membership";
      }
      else if(number==9)
      {
         SWV5_DurableEventIdentitySet pair_set,single_set,temp;
         SWV5_TestMakeEventIdentitySet(pair_set,false);
         SWV5_TestMakeEventIdentitySet(single_set,false);
         SWV5_TestAppendEventIdentity("A",1,pair_set,temp); pair_set=temp;
         SWV5_TestAppendEventIdentity("B",2,pair_set,temp); pair_set=temp;
         SWV5_TestAppendEventIdentity("A|1;B",2,single_set,temp); single_set=temp;
         const string legacy_pair="A|1;B|2";
         const string legacy_single="A|1;B|2";
         passed=legacy_pair==legacy_single && pair_set.canonical_event_index!=single_set.canonical_event_index &&
                pair_set.identity_set_digest!=single_set.identity_set_digest;
         expected="legacy_collision_separated_by_typed_encoding";
      }
      else if(number==10 || number==11)
      {
         SWV5_TestAppendEventIdentity("EVENT-A",100,current,next); current=next;
         const SWV5_StatisticsIdentityDisposition disposition=(number==10 ?
            SWV5_TestAppendEventIdentity("EVENT-A",101,current,next) :
            SWV5_TestAppendEventIdentity("EVENT-B",100,current,next));
         passed=disposition==SWV5_STAT_IDENTITY_CONFLICT;
         expected=(number==10 ? "same_event_id_different_sequence_conflict" : "different_event_id_same_sequence_conflict");
      }
      else if(number==12)
      {
         SWV5_TestAppendEventIdentity("EVENT-A",100,current,next); current=next;
         passed=SWV5_TestAppendEventIdentity("EVENT-B",99,current,next)==SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW &&
                next.highest_transaction_sequence==100;
         expected="unique_out_of_order_explicitly_accepted";
      }
      else if(number==13)
      {
         SWV5_DurableEventIdentitySet temp;
         SWV5_TestAppendEventIdentity("EVENT-A",100,current,temp); current=temp;
         SWV5_TestAppendEventIdentity("EVENT-B",101,current,temp); current=temp;
         SWV5_TestAppendEventIdentity("EVENT-C",102,current,temp); current=temp;
         passed=SWV5_TestAppendEventIdentity("EVENT-A",100,current,next)==SWV5_STAT_IDENTITY_DUPLICATE;
         expected="replay_after_later_events_duplicate";
      }
      else if(number==14)
      {
         SWV5_ContractValidationContext context;
         SWV5_TestMakeContext(context);
         SWV5_PendingRequest pending;
         SWV5_TestMakePending(pending);
         SWV5_TransactionEvidence evidence;
         SWV5_TestMakeTransaction(pending,evidence,0.04);
         evidence.correlation.broker_identity.broker_event_id="EXEC|;雪";
         SWV5_TestExecutionContract execution;
         SWV5_ExecutionConfirmation accepted,conflict;
         const bool first=execution.AcceptTransactionEvidence(context,pending,evidence,accepted);
         evidence.confirmed_price+=1.0;
         const bool second=execution.AcceptTransactionEvidence(context,accepted.resulting_pending_request,evidence,conflict);
         passed=first && !second && conflict.status==SWV5_CONFIRMATION_CONFLICT && !conflict.event_identity_added;
         expected="execution_fingerprint_conflict_still_fails_closed";
      }
      else if(number==15)
      {
         SWV5_TestMakeEventIdentitySet(current,false,SWV5_DURABLE_FINGERPRINT_REQUIRED);
         SWV5_TestAppendDurableFingerprint("ROUND|TRIP;雪",100,"ROUND|TRIP-FP;雪",current,next); current=next;
         SWV5_PersistedCheckpoint checkpoint,loaded;
         SWV5_TestMakeCheckpoint(checkpoint);
         checkpoint.basket.lifecycle.accepted_recovery_evidence=current;
         SWV5_TestSealCheckpoint(checkpoint);
         SWV5_ContractValidationContext context; SWV5_TestMakeContext(context);
         SWV5_TestPersistenceContract persistence;
         SWV5_ContractDecision decision; SWV5_PersistenceLoadResult load_result;
         passed=persistence.SaveCheckpoint(context,checkpoint,decision) &&
                persistence.LoadLatest(context,checkpoint.header.persistence_namespace,loaded,load_result) &&
                SWV5_TestEventIdentitySetEqual(current,loaded.basket.lifecycle.accepted_recovery_evidence);
         expected="event_set_checkpoint_round_trip";
      }
      else if(number==16 || number==17)
      {
         SWV5_DurableEventIdentitySet first,second;
         SWV5_TestMakeEventIdentitySet(first,false); SWV5_TestMakeEventIdentitySet(second,false);
         SWV5_TestAppendEventIdentity("EVENT-A",100,first,current); first=current;
         SWV5_TestAppendEventIdentity(number==16 ? "EVENT-B" : "EVENT-A",number==16 ? 100 : 101,second,current); second=current;
         passed=first.identity_set_digest!=second.identity_set_digest;
         expected=(number==16 ? "digest_changes_with_event_id" : "digest_changes_with_sequence");
      }
      else if(number==18)
      {
         SWV5_DurableEventIdentitySet first,second,temp;
         SWV5_TestMakeEventIdentitySet(first,false,SWV5_DURABLE_FINGERPRINT_REQUIRED);
         SWV5_TestAppendDurableFingerprint("EVENT-A",100,"FP-A",first,temp); first=temp; second=first;
         second.canonical_fingerprint_index=SWV5_TestCanonicalDurableFingerprintEntry("EVENT-A",100,"FP-B");
         first.identity_set_digest=SWV5_TestEventSetDigest(first); second.identity_set_digest=SWV5_TestEventSetDigest(second);
         passed=SWV5_TestEventSetIntegrityValid(first) && SWV5_TestEventSetIntegrityValid(second) &&
                first.identity_set_digest!=second.identity_set_digest;
         expected="digest_changes_with_fingerprint";
      }
      else if(number==19)
      {
         SWV5_TestMakeEventIdentitySet(current,true);
         current.canonical_event_index="entry:x:999:event_id:s:1:A";
         current.identity_set_digest=SWV5_TestEventSetDigest(current);
         passed=!SWV5_TestEventSetIntegrityValid(current);
         expected="malformed_canonical_identity_rejected";
      }
      else if(number==20)
      {
         SWV5_TestMakeEventIdentitySet(current,true);
         current.accepted_identity_count++;
         current.identity_set_digest=SWV5_TestEventSetDigest(current);
         passed=!SWV5_TestEventSetIntegrityValid(current);
         expected="accepted_identity_count_mismatch_rejected";
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S46EI",number),"SPRINT4_6_DURABLE_IDENTITY",passed,expected);
   }
}

void SWV5_TestMakeRequiredFingerprintPair(SWV5_DurableEventIdentitySet &set)
{
   SWV5_DurableEventIdentitySet next;
   SWV5_TestMakeEventIdentitySet(set,false,SWV5_DURABLE_FINGERPRINT_REQUIRED);
   SWV5_TestAppendDurableFingerprint("EVENT-A",100,"FP-A",set,next);
   set=next;
   SWV5_TestAppendDurableFingerprint("EVENT-B",101,"FP-B",set,next);
   set=next;
}

void SWV5_TestMakeAmbiguousFingerprintSet(SWV5_DurableEventIdentitySet &set,
                                           const bool identical_fingerprints)
{
   SWV5_TestMakeRequiredFingerprintPair(set);
   set.canonical_fingerprint_index=SWV5_TestCanonicalDurableFingerprintEntry("EVENT-A",100,"FP-A")+
                                   SWV5_TestCanonicalDurableFingerprintEntry("EVENT-A",100,
                                      identical_fingerprints ? "FP-A" : "FP-CONFLICT");
   set.identity_set_digest=SWV5_TestEventSetDigest(set);
}

// Sprint 4.6 Phase E1 durable fingerprint trace. Fingerprint-required sets
// enforce exactly one canonical mapping per accepted (event_id, sequence).
// Ambiguous or noncanonical persistent state fails closed before classification.
void SWV5_RunSprint46FingerprintUniquenessTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=20;number++)
   {
      SWV5_DurableEventIdentitySet current,next;
      SWV5_TestMakeRequiredFingerprintPair(current);
      bool passed=false;
      string expected="fail_closed";
      if(number==1)
      {
         passed=SWV5_TestEventSetIntegrityValid(current) && current.accepted_identity_count==2;
         expected="valid_one_to_one_mapping";
      }
      else if(number==2)
      {
         passed=SWV5_TestClassifyDurableFingerprint("EVENT-A",100,"FP-A",current)==SWV5_STAT_IDENTITY_DUPLICATE &&
                SWV5_TestAppendDurableFingerprint("EVENT-A",100,"FP-A",current,next)==SWV5_STAT_IDENTITY_DUPLICATE &&
                SWV5_TestEventIdentitySetEqual(current,next);
         expected="exact_replay_duplicate_no_mutation";
      }
      else if(number==3)
      {
         passed=SWV5_TestClassifyDurableFingerprint("EVENT-A",100,"FP-CHANGED",current)==SWV5_STAT_IDENTITY_CONFLICT &&
                SWV5_TestAppendDurableFingerprint("EVENT-A",100,"FP-CHANGED",current,next)==SWV5_STAT_IDENTITY_CONFLICT &&
                SWV5_TestEventIdentitySetEqual(current,next);
         expected="same_identity_different_fingerprint_conflict";
      }
      else if(number==4 || number==5)
      {
         SWV5_TestMakeAmbiguousFingerprintSet(current,number==4);
         passed=!SWV5_TestEventSetIntegrityValid(current);
         expected=(number==4 ? "duplicate_identical_mapping_rejected" : "duplicate_conflicting_mapping_rejected");
      }
      else if(number==6)
      {
         current.canonical_fingerprint_index=SWV5_TestCanonicalDurableFingerprintEntry("EVENT-A",100,"FP-A")+
                                             SWV5_TestCanonicalDurableFingerprintEntry("EVENT-ORPHAN",101,"FP-B");
         current.identity_set_digest=SWV5_TestEventSetDigest(current);
         passed=!SWV5_TestEventSetIntegrityValid(current);
         expected="orphan_mapping_rejected";
      }
      else if(number==7)
      {
         current.canonical_event_index=SWV5_TestCanonicalDurableEventEntry("EVENT-A",100)+
                                       SWV5_TestCanonicalDurableEventEntry("EVENT-A",100);
         current.identity_set_digest=SWV5_TestEventSetDigest(current);
         passed=!SWV5_TestEventSetIntegrityValid(current);
         expected="duplicate_event_identity_rejected";
      }
      else if(number==8)
      {
         current.canonical_fingerprint_index=SWV5_TestCanonicalDurableFingerprintEntry("EVENT-A",100,"FP-A");
         current.identity_set_digest=SWV5_TestEventSetDigest(current);
         passed=!SWV5_TestEventSetIntegrityValid(current);
         expected="fingerprint_count_lower_than_event_count_rejected";
      }
      else if(number==9)
      {
         current.canonical_fingerprint_index+=SWV5_TestCanonicalDurableFingerprintEntry("EVENT-A",100,"FP-A");
         current.identity_set_digest=SWV5_TestEventSetDigest(current);
         passed=!SWV5_TestEventSetIntegrityValid(current);
         expected="fingerprint_count_greater_than_event_count_rejected";
      }
      else if(number==10)
      {
         current.canonical_fingerprint_index=SWV5_TestCanonicalDurableFingerprintEntry("EVENT-B",101,"FP-B")+
                                             SWV5_TestCanonicalDurableFingerprintEntry("EVENT-A",100,"FP-A");
         current.identity_set_digest=SWV5_TestEventSetDigest(current);
         passed=!SWV5_TestEventSetIntegrityValid(current);
         expected="reordered_noncanonical_mapping_rejected";
      }
      else if(number==11)
      {
         current.canonical_fingerprint_index="entry:x:999:identity:x:0:";
         current.identity_set_digest=SWV5_TestEventSetDigest(current);
         passed=!SWV5_TestEventSetIntegrityValid(current);
         expected="malformed_mapping_rejected";
      }
      else if(number==12)
      {
         SWV5_TestMakeEventIdentitySet(current,false,SWV5_DURABLE_FINGERPRINT_REQUIRED);
         const string event_id="EVENT|:;, spaces\né›ª";
         const string fingerprint="FP|:;, spaces\né›ª";
         passed=SWV5_TestAppendDurableFingerprint(event_id,777,fingerprint,current,next)==SWV5_STAT_IDENTITY_NEW &&
                SWV5_TestEventSetIntegrityValid(next) &&
                SWV5_TestClassifyDurableFingerprint(event_id,777,fingerprint,next)==SWV5_STAT_IDENTITY_DUPLICATE;
         expected="unicode_delimiter_mapping_round_trip";
      }
      else if(number==13)
      {
         SWV5_DurableEventIdentitySet forward,reverse;
         SWV5_TestMakeAmbiguousFingerprintSet(forward,false);
         SWV5_TestMakeRequiredFingerprintPair(reverse);
         reverse.canonical_fingerprint_index=SWV5_TestCanonicalDurableFingerprintEntry("EVENT-A",100,"FP-CONFLICT")+
                                             SWV5_TestCanonicalDurableFingerprintEntry("EVENT-A",100,"FP-A");
         reverse.identity_set_digest=SWV5_TestEventSetDigest(reverse);
         const SWV5_StatisticsIdentityDisposition first=SWV5_TestClassifyDurableFingerprint("EVENT-A",100,"FP-A",forward);
         const SWV5_StatisticsIdentityDisposition second=SWV5_TestClassifyDurableFingerprint("EVENT-A",100,"FP-A",reverse);
         passed=first==SWV5_STAT_IDENTITY_CONFLICT && second==SWV5_STAT_IDENTITY_CONFLICT;
         expected="ordering_attempts_have_identical_fail_closed_result";
      }
      else if(number==14)
      {
         SWV5_TestMakeAmbiguousFingerprintSet(current,false);
         passed=SWV5_TestClassifyDurableFingerprint("EVENT-A",100,"FP-A",current)==SWV5_STAT_IDENTITY_CONFLICT;
         expected="ambiguous_state_never_duplicate";
      }
      else if(number==15)
      {
         const string sealed_digest=current.identity_set_digest;
         current.canonical_fingerprint_index=SWV5_TestCanonicalDurableFingerprintEntry("EVENT-A",100,"FP-MUTATED")+
                                             SWV5_TestCanonicalDurableFingerprintEntry("EVENT-B",101,"FP-B");
         passed=!SWV5_TestEventSetIntegrityValid(current) &&
                sealed_digest!=SWV5_TestEventSetDigest(current);
         expected="fingerprint_mutation_detected_by_digest";
      }
      else if(number>=16 && number<=18)
      {
         SWV5_TestMakeAmbiguousFingerprintSet(current,false);
         SWV5_PersistedCheckpoint checkpoint;
         SWV5_TestMakeCheckpoint(checkpoint);
         checkpoint.basket.lifecycle.accepted_recovery_evidence=current;
         SWV5_TestSealCheckpoint(checkpoint);
         SWV5_ContractValidationContext context;
         SWV5_TestMakeContext(context);
         SWV5_TestPersistenceContract persistence;
         SWV5_PersistenceLoadResult load_result;
         SWV5_ContractDecision decision;
         if(number==16)
         {
            passed=!persistence.ValidateRecord(context,checkpoint,load_result);
            expected="checkpoint_ambiguous_mapping_rejected";
         }
         else if(number==17)
         {
            passed=!persistence.SaveCheckpoint(context,checkpoint,decision);
            expected="save_checkpoint_rejects_ambiguous_mapping";
         }
         else
         {
            SWV5_PersistedRequestEvidence requests[];
            ArrayResize(requests,0);
            persistence.Configure(checkpoint,requests);
            SWV5_PersistedCheckpoint loaded;
            passed=!persistence.LoadLatest(context,checkpoint.header.persistence_namespace,loaded,load_result) &&
                   !persistence.ValidateRecord(context,checkpoint,load_result);
            expected="configure_load_validate_reject_ambiguous_mapping";
         }
      }
      else if(number==19)
      {
         SWV5_ContractValidationContext context;
         SWV5_TestMakeContext(context);
         SWV5_BasketStatistics current_statistics,next_statistics;
         SWV5_TestMakeStatistics(current_statistics);
         SWV5_AuthoritativeDeal deal;
         SWV5_TestMakeDeal(deal);
         SWV5_StatisticsDeduplicationEvidence evidence;
         SWV5_TestMakeDedupEvidence(evidence,current_statistics.deduplication,SWV5_STAT_IDENTITY_DUPLICATE);
         deal.correlation=evidence.correlation;
         SWV5_TestStatisticsContract statistics;
         passed=statistics.AccumulateDeal(context,deal,evidence,current_statistics,next_statistics) &&
                next_statistics.deal_count==current_statistics.deal_count &&
                next_statistics.entry_deal_count==current_statistics.entry_deal_count &&
                next_statistics.exit_deal_count==current_statistics.exit_deal_count &&
                next_statistics.partial_close_count==current_statistics.partial_close_count &&
                SWV5_TestNear(next_statistics.gross_profit,current_statistics.gross_profit,context.price_tolerance) &&
                SWV5_TestNear(next_statistics.authoritative_net_result,current_statistics.authoritative_net_result,context.price_tolerance) &&
                SWV5_TestEventIdentitySetEqual(next_statistics.deduplication.identities,current_statistics.deduplication.identities) &&
                next_statistics.deduplication.duplicate_deal_count==current_statistics.deduplication.duplicate_deal_count+1;
         expected="statistics_duplicate_counted_once_only";
      }
      else if(number==20)
      {
         SWV5_ContractValidationContext context;
         SWV5_TestMakeContext(context);
         SWV5_PendingRequest pending;
         SWV5_TestMakePending(pending);
         SWV5_TransactionEvidence evidence;
         SWV5_TestMakeTransaction(pending,evidence,0.04);
         SWV5_TestExecutionContract execution;
         SWV5_ExecutionConfirmation accepted,conflict;
         const bool first=execution.AcceptTransactionEvidence(context,pending,evidence,accepted);
         const SWV5_PendingRequest accepted_pending=accepted.resulting_pending_request;
         evidence.confirmed_price+=1.0;
         const bool second=execution.AcceptTransactionEvidence(context,accepted_pending,evidence,conflict);
         passed=first && !second && conflict.status==SWV5_CONFIRMATION_CONFLICT &&
                !conflict.event_identity_added &&
                SWV5_TestPendingRequestEqual(conflict.resulting_pending_request,accepted_pending) &&
                conflict.resulting_pending_request.cumulative_confirmed_volume==accepted_pending.cumulative_confirmed_volume &&
                conflict.resulting_pending_request.residual_requested_volume==accepted_pending.residual_requested_volume;
         expected="execution_conflict_preserves_exposure_residual_identity_state";
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S46E1",number),"SPRINT4_6_FINGERPRINT_UNIQUENESS",passed,expected);
   }
}

void SWV5_RunSprint46RetryFreshnessTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=20;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_PendingRequest pending;
      SWV5_TestMakeRetryCandidate(pending);
      SWV5_PendingRequest original=pending;
      SWV5_RetryPolicy policy;
      SWV5_TestMakeRetryPolicy(context,policy);
      SWV5_RetryRiskFreshnessEvidence risk_evidence;
      SWV5_TestMakeRetryRiskEvidence(context,pending,risk_evidence);
      SWV5_RetryNormalizationFreshnessEvidence normalization_evidence;
      SWV5_TestMakeRetryNormalizationEvidence(context,pending,normalization_evidence);
      SWV5_TestExecutionContract implementation;
      SWV5_ContractDecision decision;
      bool expect_allow=(number==1 || number==9 || number==12 || number==20);
      string expected="fail_closed";
      if(number==2) context.clock_sequence=0;
      if(number==3) SWV5_TestSetForeignContractIdentity(pending.contract_version);
      if(number==4)
      {
         risk_evidence.ownership_fence.fencing_token_digest="CURRENT-TAKEOVER-FENCE";
         normalization_evidence.ownership_fence.fencing_token_digest="CURRENT-TAKEOVER-FENCE";
      }
      if(number==5) policy.authorization_deadline=context.clock_time-1;
      if(number==6) policy.authorization_deadline=context.clock_time;
      if(number==7) risk_evidence.expires_at=context.clock_time-1;
      if(number==8) ZeroMemory(risk_evidence);
      if(number==10) normalization_evidence.evidenced_at=pending.last_changed_at;
      if(number==11) ZeroMemory(normalization_evidence);
      if(number==13)
      {
         risk_evidence.symbol_specification_sequence++;
         normalization_evidence.symbol_specification_sequence++;
      }
      if(number==14)
      {
         risk_evidence.expected_basket_version++;
         normalization_evidence.expected_basket_version++;
      }
      if(number==15)
      {
         pending.submission_attempt_count=policy.maximum_attempts;
         pending.latest_submission.submission_attempt_count=policy.maximum_attempts;
      }
      if(number==16)
      {
         pending.lifecycle_phase=SWV5_EXECUTION_PHASE_COMPLETED;
         pending.state=SWV5_REQUEST_CONFIRMED;
      }
      if(number==17) pending.state=SWV5_REQUEST_RECONCILIATION_REQUIRED;
      if(number==18) pending.latest_authoritative_confirmation.status=SWV5_CONFIRMATION_CONFLICT;
      if(number==19)
      {
         risk_evidence.request_identity.request_id.attempt_id="FOREIGN-ATTEMPT";
         normalization_evidence.request_identity.request_id.attempt_id="FOREIGN-ATTEMPT";
      }
      const bool allowed=implementation.EvaluateRetry(context,pending,policy,risk_evidence,normalization_evidence,decision);
      bool passed=(expect_allow ? allowed && decision.disposition==SWV5_DISPOSITION_ALLOW :
                                  !allowed && decision.disposition==SWV5_DISPOSITION_DENY);
      if(number==20) passed=passed && SWV5_TestPendingRequestEqual(pending,original);
      if(number==1) expected="valid_retry_allowed";
      if(number==2) expected="invalid_context_rejected";
      if(number==3) expected="foreign_contract_rejected";
      if(number==4) expected="stale_owner_after_takeover_rejected";
      if(number==5) expected="expired_authorization_deadline_rejected";
      if(number==6) expected="exact_deadline_exclusive_rejected";
      if(number==7) expected="expired_risk_authorization_rejected";
      if(number==8) expected="fresh_risk_required_absent_rejected";
      if(number==9) expected="fresh_risk_current_allowed";
      if(number==10) expected="stale_normalization_rejected";
      if(number==11) expected="fresh_normalization_absent_rejected";
      if(number==12) expected="fresh_normalization_current_allowed";
      if(number==13) expected="changed_symbol_specification_rejected";
      if(number==14) expected="changed_basket_version_rejected";
      if(number==15) expected="retry_budget_exhausted_rejected";
      if(number==16) expected="terminal_lifecycle_rejected";
      if(number==17) expected="reconciliation_required_rejected";
      if(number==18) expected="conflict_state_rejected";
      if(number==19) expected="foreign_request_identity_rejected";
      if(number==20) expected="valid_retry_does_not_mutate_pending";
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S46DR",number),"SPRINT4_6_RETRY_FRESHNESS",passed,expected);
   }
}

void SWV5_RunSprint47RiskProjectionTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=18;number++)
   {
      SWV5_ContractValidationContext context; SWV5_TestMakeContext(context);
      SWV5_RiskEvaluationInput engineInput; SWV5_TestMakeRiskInput(engineInput);
      SWV5_TestRiskContract implementation; SWV5_RiskAuthorization authorization;
      bool expect_allow=(number==1 || number==18);
      if(number==2) engineInput.projected.projected_volume=0.0;
      if(number==3) engineInput.projected.projected_symbol_volume=engineInput.exposure.symbol_long_volume+engineInput.exposure.symbol_short_volume;
      if(number==4) engineInput.projected.projected_aggregate_volume=engineInput.exposure.aggregate_volume;
      if(number==5) engineInput.projected.projected_notional=0.0;
      if(number==6) engineInput.projected.projected_margin=0.0;
      if(number==7) engineInput.account.free_margin=engineInput.projected.projected_margin-context.price_tolerance*2.0;
      if(number==8) engineInput.account.margin=engineInput.account.equity*engineInput.limits.maximum_account_margin_fraction-engineInput.projected.projected_margin+1.0;
      if(number==9)
      {
         engineInput.intent.intent_type=SWV5_INTENT_INCREASE;
         SWV5_TestMakeLifecycle(engineInput.basket.lifecycle,SWV5_BASKET_ACTIVE);
         engineInput.projected.projected_volume=engineInput.basket.lifecycle.aggregate_open_volume;
      }
      if(number==10)
      {
         engineInput.intent.intent_type=SWV5_INTENT_REDUCE;
         SWV5_TestMakeLifecycle(engineInput.basket.lifecycle,SWV5_BASKET_ACTIVE);
         engineInput.projected.projected_volume=0.40;
         engineInput.projected.projected_symbol_volume=0.20;
         engineInput.projected.projected_aggregate_volume=0.20;
         engineInput.projected.projected_notional=480.0;
         engineInput.projected.projected_margin=0.0;
      }
      if(number==11)
      {
         engineInput.intent.intent_type=SWV5_INTENT_CLOSE; engineInput.intent.normalized_volume=0.30;
         SWV5_TestMakeLifecycle(engineInput.basket.lifecycle,SWV5_BASKET_ACTIVE);
         engineInput.projected.projected_volume=0.01; engineInput.projected.projected_symbol_volume=0.0;
         engineInput.projected.projected_aggregate_volume=0.0; engineInput.projected.projected_notional=0.0; engineInput.projected.projected_margin=0.0;
      }
      if(number==12)
      {
         engineInput.intent.intent_type=SWV5_INTENT_CANCEL_PENDING; engineInput.intent.direction=0;
         engineInput.intent.normalized_volume=0.0; engineInput.intent.normalized_price=0.0;
         engineInput.intent.normalized_stop_price=0.0; engineInput.intent.normalized_limit_price=0.0;
         engineInput.projected.projected_volume=0.10; engineInput.projected.projected_symbol_volume=0.30;
         engineInput.projected.projected_aggregate_volume=0.30; engineInput.projected.projected_notional=720.0;
         engineInput.projected.projected_margin=0.0; engineInput.projected.projected_maximum_loss=0.0;
      }
      if(number==13) engineInput.projected.projected_symbol_volume=engineInput.projected.projected_volume-context.volume_tolerance*2.0;
      if(number==14) engineInput.projected.projected_aggregate_volume=engineInput.projected.projected_symbol_volume-context.volume_tolerance*2.0;
      if(number==15) engineInput.projected.projected_maximum_loss=0.0;
      if(number==16) engineInput.exposure.account_namespace.server="FOREIGN-SERVER";
      if(number==17) engineInput.exposure.symbol_long_volume=0.20;
      if(number==18)
      {
         engineInput.projected.projected_volume-=context.volume_tolerance*0.5;
         engineInput.projected.projected_symbol_volume-=context.volume_tolerance*0.5;
         engineInput.projected.projected_aggregate_volume-=context.volume_tolerance*0.5;
         engineInput.projected.projected_notional-=context.price_tolerance*0.5;
      }
      const bool allowed=implementation.Evaluate(context,engineInput,authorization);
      const bool passed=(expect_allow ? allowed && authorization.disposition==SWV5_RISK_ALLOW :
                                       !allowed && authorization.disposition!=SWV5_RISK_ALLOW && authorization.authorization_id=="");
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S47-RISK",number),"SPRINT4_7_RISK_PROJECTION",passed,
                               expect_allow ? "causally_bound_projection_allowed" : "understated_or_incoherent_projection_rejected");
   }
}

void SWV5_RunSprint47NonFiniteTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=18;number++)
   {
      SWV5_ContractValidationContext context; SWV5_TestMakeContext(context);
      bool passed=false;
      if(number<=11)
      {
         SWV5_RiskEvaluationInput engineInput; SWV5_TestMakeRiskInput(engineInput);
         const double nan=SWV5_TestNaN();
         if(number==1) engineInput.intent.normalized_volume=nan;
         if(number==2) engineInput.intent.normalized_price=nan;
         if(number==3) engineInput.projected.projected_volume=nan;
         if(number==4) engineInput.projected.projected_symbol_volume=nan;
         if(number==5) engineInput.projected.projected_aggregate_volume=nan;
         if(number==6) engineInput.projected.projected_notional=nan;
         if(number==7) engineInput.projected.projected_margin=nan;
         if(number==8) engineInput.projected.projected_maximum_loss=nan;
         if(number==9) engineInput.account.equity=nan;
         if(number==10) engineInput.account.free_margin=nan;
         if(number==11) engineInput.limits.maximum_basket_loss=nan;
         SWV5_TestRiskContract implementation; SWV5_RiskAuthorization authorization;
         passed=!implementation.Evaluate(context,engineInput,authorization) && authorization.disposition!=SWV5_RISK_ALLOW && authorization.authorization_id=="";
      }
      else if(number<=17)
      {
         SWV5_PendingRequest pending; SWV5_TestMakePending(pending);
         SWV5_TransactionEvidence evidence;
         if(number>=16) SWV5_TestMakeAcknowledgementTransaction(pending,evidence);
         else SWV5_TestMakeTransaction(pending,evidence,0.04);
         if(number==12 || number==16) evidence.confirmed_volume=SWV5_TestNaN();
         if(number==13 || number==17) evidence.confirmed_price=SWV5_TestNaN();
         if(number==14) evidence.confirmed_volume=SWV5_TestPositiveInfinity();
         if(number==15) evidence.confirmed_price=SWV5_TestPositiveInfinity();
         SWV5_TestExecutionContract implementation;
         passed=SWV5_TestExecutionRejectsWithoutMutation(implementation,context,pending,evidence);
      }
      else
      {
         SWV5_PersistedRequestEvidence requests[]; ArrayResize(requests,1); SWV5_TestMakePersistedRequest(requests[0],1);
         requests[0].pending_request.latest_authoritative_confirmation.cumulative_confirmed_volume=SWV5_TestNaN();
         SWV5_PersistedRequestSetHeader header; SWV5_TestBindRequestSetHeader(header,requests,50);
         SWV5_TestPersistenceContract implementation; SWV5_ContractDecision decision;
         passed=!implementation.SavePendingRequests(context,requests[0].persistence_namespace,requests,header,decision);
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S47-NUM",number),"SPRINT4_7_NONFINITE",passed,"nonfinite_rejected_without_authoritative_mutation");
   }
}

void SWV5_RunSprint47HardKillExpiryTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=7;number++)
   {
      SWV5_ContractValidationContext context; SWV5_TestMakeContext(context);
      SWV5_HardKillState state; SWV5_TestMakeValidHardKillRelease(state);
      SWV5_HardKillReleaseEvidence evidence=state.release_evidence;
      if(number==2 || number==7) context.clock_time=evidence.expires_at;
      if(number==3) context.clock_time=evidence.expires_at+1;
      if(number==4) evidence.expires_at=evidence.approved_at;
      if(number==5) evidence.expires_at=0;
      if(number==6) evidence.expires_at=evidence.approved_at-1;
      const SWV5_HardKillState original=state;
      SWV5_TestRiskContract implementation; SWV5_ContractDecision decision;
      const bool allowed=implementation.ValidateHardKillRelease(context,state,evidence,decision);
      bool passed=(number==1 ? allowed && decision.disposition==SWV5_DISPOSITION_ALLOW :
                               !allowed && decision.disposition!=SWV5_DISPOSITION_ALLOW);
      if(number==7) passed=passed && state.state==original.state && state.latch_id==original.latch_id &&
                                     state.latch_generation==original.latch_generation && state.release_generation==original.release_generation;
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S47-HK",number),"SPRINT4_7_HARD_KILL_EXPIRY",passed,
                               number==1 ? "exclusive_interval_valid" : "expired_or_invalid_release_denied_latch_unchanged");
   }
}

void SWV5_TestPrepareCheckpointPending(SWV5_RestartReconciliationInput &restart,
                                        SWV5_PersistedRequestEvidence &request)
{
   SWV5_TestMakePersistedRequest(request,1);
   SWV5_PersistedRequestEvidence requests[]; ArrayResize(requests,1); requests[0]=request;
   SWV5_TestBindRequestSetHeader(restart.persisted.pending_request_set,requests,50);
   restart.persisted.has_latest_pending_request=true;
   restart.persisted.latest_pending_request=request;
   restart.broker.pending_request_count=1;
}

void SWV5_RunSprint47CheckpointSemanticTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=18;number++)
   {
      SWV5_ContractValidationContext context; SWV5_TestMakeContext(context);
      SWV5_RestartReconciliationInput restart; SWV5_TestMakeRestartInput(restart);
      SWV5_PersistedRequestEvidence requests[]; ArrayResize(requests,0);
      const bool pending_case=(number==3 || number==4 || number==8 || number==9 || number==10 || number==11 || number==12 || number==13);
      if(pending_case)
      {
         ArrayResize(requests,1); SWV5_TestPrepareCheckpointPending(restart,requests[0]);
         if(number==3) requests[0].pending_request.lifecycle_phase=(SWV5_ExecutionLifecyclePhase)99;
         if(number==4) requests[0].pending_request.retry_disposition=(SWV5_RetryDisposition)99;
         if(number==8) requests[0].account_mode=(SWV5_AccountPositionMode)99;
         if(number==9) requests[0].pending_request.residual_requested_volume=-0.01;
         if(number==10) requests[0].pending_request.cumulative_confirmed_volume=requests[0].pending_request.intent.normalized_volume+0.01;
         if(number==11) requests[0].pending_request.intent.intent_type=(SWV5_ExecutionIntentType)99;
         if(number==12) requests[0].pending_request.intent.direction=2;
         if(number==13)
         {
            requests[0].pending_request.accepted_event_identities.canonical_event_index="impossible";
            requests[0].pending_request.accepted_event_identities.identity_set_digest=SWV5_TestEventSetDigest(requests[0].pending_request.accepted_event_identities);
         }
         SWV5_TestBindRequestSetHeader(restart.persisted.pending_request_set,requests,50);
         restart.persisted.latest_pending_request=requests[0];
      }
      if(number==1) restart.persisted.hard_kill_state.state=(SWV5_HardKillLatchState)99;
      if(number==2) restart.persisted.basket.lifecycle.state=(SWV5_BasketState)99;
      if(number==5) restart.persisted.last_confirmed_correlation.phase=(SWV5_ExecutionLifecyclePhase)99;
      if(number==6) SWV5_TestSetForeignContractIdentity(restart.persisted.header.contract_version);
      if(number==7) restart.persisted.header.persistence_namespace.ownership_namespace.server="FOREIGN-SERVER";
      if(number==14) restart.persisted.hard_kill_state.state=SWV5_HARD_KILL_ACTIVE;
      if(number==15)
      {
         restart.persisted.hard_kill_state.state=SWV5_HARD_KILL_RELEASE_PENDING;
         restart.persisted.hard_kill_state.release_evidence.release_id="RELEASE-INVALID";
         restart.persisted.hard_kill_state.release_evidence.release_generation=restart.persisted.hard_kill_state.release_generation;
      }
      if(number==16) restart.persisted.header.ownership_fence.ownership_namespace.server="FOREIGN-SERVER";
      SWV5_TestSealCheckpoint(restart.persisted);
      if(number==17) restart.persistence_namespace.ownership_namespace.server="FOREIGN-SERVER";
      if(number==18) restart.broker.persistence_namespace.ownership_namespace.server="FOREIGN-SERVER";
      const bool integrity_valid=restart.persisted.header.payload_digest==SWV5_TestCheckpointPayloadDigest(restart.persisted) &&
                                 restart.persisted.header.payload_size==SWV5_TestCheckpointPayloadSize(restart.persisted);
      SWV5_TestPersistenceContract implementation; SWV5_RestartReadinessDisposition readiness;
      const SWV5_ReconciliationStatus status=SWV5_TestInterfaceRestart(implementation,context,restart,requests,readiness);
      const bool passed=integrity_valid && readiness!=SWV5_RESTART_SAFE_TO_RESUME &&
                        status!=SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED;
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S47-CHK",number),"SPRINT4_7_CHECKPOINT_SEMANTICS",passed,
                               "resealed_integrity_valid_semantic_corruption_halts_restart");
   }
}

void SWV5_RunSprint47RetryEnumTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=12;number++)
   {
      SWV5_ContractValidationContext context; SWV5_TestMakeContext(context);
      SWV5_PendingRequest pending; SWV5_TestMakeRetryCandidate(pending); const SWV5_PendingRequest original=pending;
      SWV5_RetryPolicy policy; SWV5_TestMakeRetryPolicy(context,policy);
      SWV5_RetryRiskFreshnessEvidence risk; SWV5_TestMakeRetryRiskEvidence(context,pending,risk);
      SWV5_RetryNormalizationFreshnessEvidence normalization; SWV5_TestMakeRetryNormalizationEvidence(context,pending,normalization);
      const bool expect_allow=(number==1 || number==11 || number==12);
      if(number==2) pending.lifecycle_phase=(SWV5_ExecutionLifecyclePhase)99;
      if(number==3) policy.disposition=(SWV5_RetryDisposition)99;
      if(number==4) { pending.lifecycle_phase=(SWV5_ExecutionLifecyclePhase)99; pending.latest_retcode.correlation.phase=(SWV5_ExecutionLifecyclePhase)99; }
      if(number==5) { pending.retry_disposition=(SWV5_RetryDisposition)99; policy.disposition=(SWV5_RetryDisposition)99; }
      if(number==6) pending.latest_retcode_classification.classification=(SWV5_ResultRetcodeClass)99;
      if(number==7) pending.latest_retcode.correlation.phase=(SWV5_ExecutionLifecyclePhase)99;
      if(number==8) { pending.lifecycle_phase=SWV5_EXECUTION_PHASE_COMPLETED; pending.state=SWV5_REQUEST_CONFIRMED; }
      if(number==9) { pending.lifecycle_phase=SWV5_EXECUTION_PHASE_UNCERTAIN; pending.state=SWV5_REQUEST_RECONCILIATION_REQUIRED; }
      if(number==10) pending.latest_authoritative_confirmation.status=SWV5_CONFIRMATION_CONFLICT;
      SWV5_TestExecutionContract implementation; SWV5_ContractDecision decision;
      const bool allowed=implementation.EvaluateRetry(context,pending,policy,risk,normalization,decision);
      bool passed=(expect_allow ? allowed && decision.disposition==SWV5_DISPOSITION_ALLOW :
                                 !allowed && decision.disposition==SWV5_DISPOSITION_DENY);
      if(number==12) passed=passed && SWV5_TestPendingRequestEqual(pending,original);
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S47-RETRY",number),"SPRINT4_7_RETRY_ENUM",passed,
                               expect_allow ? "explicit_retry_whitelist_allowed_without_mutation" : "unknown_or_ineligible_enum_denied");
   }
}

void SWV5_RunSprint48MarginTests(SWV5_TestCollector &collector)
{
   SWV5_ContractValidationContext context; SWV5_TestMakeContext(context);
   for(int number=1;number<=15;number++)
   {
      SWV5_RiskEvaluationInput engineInput; SWV5_TestMakeRiskInput(engineInput);
      SWV5_MarginProjectionEvidence evidence=engineInput.projected.margin_evidence;
      bool reseal=true;
      if(number==2){ evidence.additional_margin=0.0; evidence.projected_account_margin=evidence.current_account_margin; }
      if(number==3){ evidence.additional_margin=context.price_tolerance*2.0; }
      if(number==4) evidence.request_identity.request_id.attempt_id="WRONG";
      if(number==5) evidence.symbol="OTHER";
      if(number==6) evidence.symbol_specification_sequence++;
      if(number==7){ evidence.observed_at=SWV5_TEST_TIME-120; evidence.calculated_at=SWV5_TEST_TIME-120; }
      if(number==8) evidence.account_namespace.account_login++;
      if(number==9) evidence.additional_margin=SWV5_TestNaN();
      if(number==10) evidence.projected_account_margin=engineInput.account.equity*engineInput.limits.maximum_account_margin_fraction+1.0;
      if(number==11){ evidence.additional_margin=engineInput.account.free_margin+1.0; evidence.projected_account_margin=evidence.current_account_margin+evidence.additional_margin; }
      if(number==12) evidence.current_account_margin++;
      if(number==13){ evidence.evidence_digest="CORRUPT"; reseal=false; }
      if(number==14) evidence.authority_source=SWV5_AUTHORITY_PERSISTED_CHECKPOINT;
      if(number==15)
      {
         evidence.additional_margin+=context.price_tolerance*0.5;
         evidence.projected_account_margin+=context.price_tolerance*0.5;
         engineInput.margin_authority_record.additional_margin=evidence.additional_margin;
         engineInput.margin_authority_record.projected_account_margin=evidence.projected_account_margin;
         engineInput.margin_authority_record.authority_record_digest=SWV5_TestMarginAuthorityDigest(engineInput.margin_authority_record);
         evidence.authority_record_digest=engineInput.margin_authority_record.authority_record_digest;
      }
      if(reseal) evidence.evidence_digest=SWV5_TestMarginEvidenceDigest(evidence);
      engineInput.projected.margin_evidence=evidence;
      engineInput.projected.projected_margin=evidence.additional_margin;
      const bool valid=SWV5_TestMarginEvidenceValid(context,engineInput);
      const bool expect=number==1 || number==15;
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S48-MARGIN",number),"SPRINT4_8_MARGIN",valid==expect,expect?"accepted":"rejected");
   }
}

void SWV5_RunSprint48LossTests(SWV5_TestCollector &collector)
{
   SWV5_ContractValidationContext context; SWV5_TestMakeContext(context);
   for(int number=1;number<=15;number++)
   {
      SWV5_RiskEvaluationInput engineInput; SWV5_TestMakeRiskInput(engineInput);
      SWV5_BasketRiskProjectionEvidence evidence=engineInput.projected.basket_risk_evidence;
      bool reseal=true;
      if(number==2){ evidence.existing_bounded_basket_loss=350.0; evidence.incremental_request_bounded_loss=1.0; evidence.resulting_basket_maximum_loss=351.0; }
      if(number==3){ evidence.existing_bounded_basket_loss=0.0; }
      if(number==4) evidence.basket_state_version++;
      if(number==5){ evidence.observed_at=SWV5_TEST_TIME-120; evidence.calculated_at=SWV5_TEST_TIME-120; }
      if(number==6) evidence.request_identity.request_id.attempt_id="WRONG";
      if(number==7) evidence.symbol_specification_sequence++;
      if(number==8) evidence.resulting_basket_maximum_loss=SWV5_TestNaN();
      if(number==9) evidence.resulting_basket_maximum_loss=engineInput.limits.maximum_basket_loss+1.0;
      if(number==10) evidence.resulting_basket_maximum_loss+=1.0;
      if(number==11) evidence.monetary_basis.account_currency="EUR";
      if(number==12) evidence.source_snapshot_digest="";
      if(number==13) evidence.issuing_component=SWV5_COMPONENT_AUTHORITY_EXECUTION;
      if(number==14){ evidence.evidence_digest="CORRUPT"; reseal=false; }
      if(number==15)
      {
         evidence.interaction_or_offset_adjustment=context.price_tolerance*0.5;
         evidence.resulting_basket_maximum_loss+=context.price_tolerance*0.5;
         engineInput.basket_risk_authority_record.interaction_or_offset_adjustment=evidence.interaction_or_offset_adjustment;
         engineInput.basket_risk_authority_record.resulting_basket_maximum_loss=evidence.resulting_basket_maximum_loss;
         engineInput.basket_risk_authority_record.authority_record_digest=SWV5_TestBasketRiskAuthorityDigest(engineInput.basket_risk_authority_record);
         evidence.authority_record_digest=engineInput.basket_risk_authority_record.authority_record_digest;
      }
      if(reseal) evidence.evidence_digest=SWV5_TestBasketRiskEvidenceDigest(evidence);
      engineInput.projected.basket_risk_evidence=evidence;
      engineInput.projected.projected_maximum_loss=evidence.resulting_basket_maximum_loss;
      const bool valid=SWV5_TestBasketRiskEvidenceValid(context,engineInput);
      const bool expect=number==1 || number==15;
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S48-LOSS",number),"SPRINT4_8_BASKET_LOSS",valid==expect,expect?"accepted":"rejected");
   }
}

void SWV5_RunSprint48NotionalTests(SWV5_TestCollector &collector)
{
   SWV5_ContractValidationContext context; SWV5_TestMakeContext(context);
   for(int number=1;number<=10;number++)
   {
      SWV5_RiskEvaluationInput engineInput; SWV5_TestMakeRiskInput(engineInput);
      if(number==2) engineInput.projected.projected_notional=engineInput.exposure.aggregate_notional+engineInput.intent.normalized_volume*engineInput.intent.normalized_price;
      if(number==3) engineInput.projected.projected_notional=engineInput.exposure.aggregate_notional+1.0;
      if(number==4) engineInput.symbol_specification.specification_sequence++;
      if(number==5) engineInput.projected.monetary_basis.conversion_rate_to_account_currency=0.5;
      if(number==6) engineInput.symbol_specification.contract_size=0.0;
      if(number==7) engineInput.symbol_specification.valid_until=SWV5_TEST_TIME-1;
      if(number==8) engineInput.symbol_specification.symbol="OTHER";
      if(number==9) engineInput.symbol_specification.calculation_mode=SWV5_SYMBOL_CALCULATION_UNSUPPORTED;
      const bool valid=SWV5_TestRiskInputCoherent(context,engineInput);
      const bool expect=number==1 || number==10;
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S48-NOTIONAL",number),"SPRINT4_8_NOTIONAL",valid==expect,expect?"accepted":"rejected");
   }
}

void SWV5_RunSprint48RestartTests(SWV5_TestCollector &collector)
{
   SWV5_ContractValidationContext context; SWV5_TestMakeContext(context);
   for(int number=1;number<=20;number++)
   {
      SWV5_RestartReconciliationInput engineInput; SWV5_TestMakeRestartInput(engineInput);
      if(number==2) engineInput.persisted.basket.lifecycle.reconciliation_state=SWV5_RECONCILIATION_STATE_REQUIRED;
      if(number==3) engineInput.persisted.basket.lifecycle.reconciliation_state=SWV5_RECONCILIATION_STATE_CONFLICT;
      if(number==4) engineInput.persisted.basket.lifecycle.reconciliation_state=SWV5_RECONCILIATION_STATE_MANUAL;
      if(number==5) engineInput.persisted.basket.lifecycle.reconciliation_state=SWV5_RECONCILIATION_STATE_NOT_STARTED;
      if(number==6) engineInput.persisted.clean_shutdown=false;
      if(number==7) engineInput.broker.symbol_long_volume+=0.1;
      if(number==8) engineInput.broker.symbol_short_volume+=0.1;
      if(number==9) engineInput.broker.symbol_net_volume+=0.1;
      if(number==10) engineInput.broker.aggregate_position_volume+=0.1;
      if(number==11) engineInput.broker.residual_volume+=0.1;
      if(number==12) engineInput.broker.position_count++;
      if(number==13) engineInput.broker.order_count++;
      if(number==14) engineInput.broker.pending_request_count++;
      if(number==15) engineInput.broker.latest_confirmed_correlation.broker_identity.broker_event_id="OTHER";
      if(number==16) engineInput.broker.latest_broker_event_identity.broker_event_id="OTHER";
      if(number==17) engineInput.broker.transaction_high_watermark++;
      if(number==18) engineInput.persisted.reconciliation_vector.request_set_revision="OTHER";
      if(number==19) engineInput.broker.queries.authoritative_flags=0;
      if(number==20) engineInput.broker.persistence_namespace.ownership_namespace.server="FOREIGN";
      if(number>=2 && number<=6) SWV5_TestSealCheckpoint(engineInput.persisted);
      if(number>=7 && number<=17) engineInput.broker.complete_summary_digest=SWV5_TestBrokerSummaryDigest(engineInput.broker);
      SWV5_PersistedRequestEvidence empty_requests[]; ArrayResize(empty_requests,0);
      SWV5_RestartReadinessDisposition readiness; const SWV5_ReconciliationStatus result=SWV5_TestRestartDisposition(context,engineInput,empty_requests,readiness);
      const bool safe=result==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED && readiness==SWV5_RESTART_SAFE_TO_RESUME;
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S48-RST",number),"SPRINT4_8_RESTART",safe==(number==1),number==1?"safe":"not_safe");
   }
}

void SWV5_TestMakeReleasedRestart(SWV5_RestartReconciliationInput &restart);
bool SWV5_TestRestartIsSafe(const SWV5_ContractValidationContext &context,
                            const SWV5_RestartReconciliationInput &restart);

void SWV5_RunSprint48HardKillTests(SWV5_TestCollector &collector)
{
   SWV5_ContractValidationContext context; SWV5_TestMakeContext(context);
   for(int number=1;number<=20;number++)
   {
      SWV5_HardKillState state; SWV5_HardKillReleaseAuthorityRecord authority_record;
      SWV5_TestMakeHistoricalHardKillAuthority(state,authority_record);
      SWV5_HardKillReleaseEvidence evidence=state.release_evidence; bool reseal=true;
      if(number==2) evidence.operator_identity.authority_role="";
      if(number==3) evidence.approving_component=SWV5_COMPONENT_AUTHORITY_EXECUTION;
      if(number==4) evidence.broker_evidence.authority_source=SWV5_AUTHORITY_PERSISTED_CHECKPOINT;
      if(number==5) evidence.persistence_evidence.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
      if(number==6) evidence.exposure_evidence.authority_source=SWV5_AUTHORITY_PERSISTED_CHECKPOINT;
      if(number==7) evidence.latch_generation++;
      if(number==8) evidence.release_generation++;
      if(number==9) evidence.persistence_namespace.ownership_namespace.server="FOREIGN";
      if(number==10) evidence.released_at=evidence.approved_at-1;
      if(number==11) evidence.released_at=evidence.expires_at;
      if(number==12) evidence.released_at=evidence.expires_at+1;
      if(number==13) evidence.release_record_digest="";
      if(number==14){ evidence.release_record_digest="CORRUPT"; reseal=false; }
      if(number==15) evidence.exposure_evidence.zero_or_reducing=false;
      if(number==16) evidence.operator_identity.operator_id="FORGED";
      if(number==17) evidence.approval_policy_id="";
      if(number==19) evidence.contract_version.schema_version=4;
      if(reseal && number!=13) evidence.release_record_digest=SWV5_TestHardKillReleaseDigest(evidence);
      bool valid=false;
      if(number==16)
      {
         // Exact HKR-16 attack: mutate checkpoint authority content, reseal both
         // its inner content digest and outer checkpoint digest, but leave the
         // independently supplied authority record unchanged.
         SWV5_RestartReconciliationInput restart; SWV5_TestMakeReleasedRestart(restart);
         restart.persisted.hard_kill_state.release_evidence.operator_identity.operator_id="FORGED";
         restart.persisted.hard_kill_state.release_evidence.release_record_digest=
            SWV5_TestHardKillReleaseDigest(restart.persisted.hard_kill_state.release_evidence);
         SWV5_TestSealCheckpoint(restart.persisted);
         valid=SWV5_TestRestartIsSafe(context,restart);
      }
      else
         valid=SWV5_TestHistoricalHardKillReleaseValid(context,state,evidence,authority_record);
      const bool expect=number==1 || number==18 || number==20;
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S48-HKR",number),"SPRINT4_8_HARD_KILL_HISTORY",valid==expect,expect?"accepted":"rejected");
   }
}

void SWV5_TestMakeReleasedRestart(SWV5_RestartReconciliationInput &restart)
{
   SWV5_TestMakeRestartInput(restart);
   SWV5_TestMakeHistoricalHardKillAuthority(restart.persisted.hard_kill_state,restart.release_authority_record);
   restart.has_release_authority_record=true;
   restart.persisted.reconciliation_vector.hard_kill_generation=restart.persisted.hard_kill_state.latch_generation;
   SWV5_TestSealCheckpoint(restart.persisted);
}

bool SWV5_TestRestartIsSafe(const SWV5_ContractValidationContext &context,
                            const SWV5_RestartReconciliationInput &restart)
{
   SWV5_PersistedRequestEvidence none[]; ArrayResize(none,0);
   SWV5_RestartReadinessDisposition readiness;
   const SWV5_ReconciliationStatus status=SWV5_TestRestartDisposition(context,restart,none,readiness);
   return status==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED && readiness==SWV5_RESTART_SAFE_TO_RESUME;
}

void SWV5_RunSprint48HardKillAuthorityTests(SWV5_TestCollector &collector)
{
   SWV5_ContractValidationContext context; SWV5_TestMakeContext(context);

   SWV5_RestartReconciliationInput baseline; SWV5_TestMakeReleasedRestart(baseline);
   SWV5_TestRecordCondition(collector,"S48-HKA-01","SPRINT4_8_HARD_KILL_AUTHORITY",
                            SWV5_TestRestartIsSafe(context,baseline),"independent_authority_allows_released_restart");

   // Checkpoint-local mutations are fully resealed. The independent authority
   // input remains unchanged, so rejection proves cross-domain binding rather
   // than detection of a stale checkpoint digest.
   for(int number=1;number<=12;number++)
   {
      SWV5_RestartReconciliationInput changed=baseline;
      if(number==1) changed.persisted.hard_kill_state.release_evidence.operator_identity.operator_id="FORGED-OPERATOR";
      if(number==2) changed.persisted.hard_kill_state.release_evidence.operator_identity.authority_role="FORGED-ROLE";
      if(number==3) changed.persisted.hard_kill_state.release_evidence.operator_identity.authentication_reference="FORGED-AUTH";
      if(number==4) changed.persisted.hard_kill_state.release_evidence.approving_component=SWV5_COMPONENT_AUTHORITY_OPERATOR;
      if(number==5) changed.persisted.hard_kill_state.release_evidence.approval_policy_id="FORGED-POLICY";
      if(number==6) changed.persisted.hard_kill_state.release_evidence.release_generation++;
      if(number==7) changed.persisted.hard_kill_state.release_authority_reference.authority_record_id="FORGED-RECORD";
      if(number==8) changed.persisted.hard_kill_state.release_authority_reference.authority_record_sequence++;
      if(number==9) changed.persisted.hard_kill_state.release_authority_reference.authority_record_digest="FORGED-DIGEST";
      if(number==10) changed.persisted.hard_kill_state.release_evidence.broker_evidence.evidence_id="FORGED-BROKER-EVIDENCE";
      if(number==11) changed.persisted.hard_kill_state.release_evidence.persistence_evidence.evidence_id="FORGED-STORE-EVIDENCE";
      if(number==12) changed.persisted.hard_kill_state.release_evidence.exposure_evidence.evidence_id="FORGED-EXPOSURE-EVIDENCE";
      changed.persisted.hard_kill_state.release_evidence.release_record_digest=
         SWV5_TestHardKillReleaseDigest(changed.persisted.hard_kill_state.release_evidence);
      SWV5_TestSealCheckpoint(changed.persisted);
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S48-HKA-C",number),"SPRINT4_8_HARD_KILL_AUTHORITY",
                               !SWV5_TestRestartIsSafe(context,changed),"resealed_checkpoint_authority_mismatch_halts");
   }

   for(int number=1;number<=6;number++)
   {
      SWV5_RestartReconciliationInput changed=baseline;
      if(number==1) changed.release_authority_record.operator_identity.operator_id="FORGED-OPERATOR";
      if(number==2) changed.release_authority_record.approval_policy_id="FORGED-POLICY";
      if(number==3) changed.release_authority_record.release_generation++;
      if(number==4) changed.release_authority_record.broker_evidence_reference.evidence_id="FORGED-EVIDENCE";
      if(number==5) changed.release_authority_record.released_at++;
      if(number==6) changed.release_authority_record.authority_record_digest="FORGED-DIGEST";
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S48-HKA-A",number),"SPRINT4_8_HARD_KILL_AUTHORITY",
                               !SWV5_TestRestartIsSafe(context,changed),"mutated_independent_authority_record_halts");
   }

   SWV5_RestartReconciliationInput missing=baseline;
   missing.has_release_authority_record=false;
   SWV5_TestRecordCondition(collector,"S48-HKA-M01","SPRINT4_8_HARD_KILL_AUTHORITY",
                            !SWV5_TestRestartIsSafe(context,missing),"released_without_independent_authority_halts");

   SWV5_RestartReconciliationInput active; SWV5_TestMakeRestartInput(active);
   SWV5_TestMakeHardKill(active.persisted.hard_kill_state,SWV5_HARD_KILL_ACTIVE);
   active.persisted.reconciliation_vector.hard_kill_generation=active.persisted.hard_kill_state.latch_generation;
   SWV5_TestSealCheckpoint(active.persisted);
   SWV5_PersistedRequestEvidence none[]; ArrayResize(none,0); SWV5_RestartReadinessDisposition readiness;
   const SWV5_ReconciliationStatus active_status=SWV5_TestRestartDisposition(context,active,none,readiness);
   SWV5_TestRecordCondition(collector,"S48-HKA-S01","SPRINT4_8_HARD_KILL_AUTHORITY",
                            active_status==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED && readiness==SWV5_RESTART_CLOSE_ONLY,
                            "active_remains_close_only");

   SWV5_RestartReconciliationInput pending; SWV5_TestMakeRestartInput(pending);
   SWV5_TestMakeValidHardKillRelease(pending.persisted.hard_kill_state);
   pending.persisted.reconciliation_vector.hard_kill_generation=pending.persisted.hard_kill_state.latch_generation;
   SWV5_TestSealCheckpoint(pending.persisted);
   const SWV5_ReconciliationStatus pending_status=SWV5_TestRestartDisposition(context,pending,none,readiness);
   SWV5_TestRecordCondition(collector,"S48-HKA-S02","SPRINT4_8_HARD_KILL_AUTHORITY",
                            pending_status==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED && readiness==SWV5_RESTART_CLOSE_ONLY,
                            "release_pending_remains_close_only");

   SWV5_TestRiskContract risk;
   SWV5_ContractDecision decision;
   const bool legacy_historical=risk.ValidateHardKillReleaseMode(context,
                                      baseline.persisted.hard_kill_state,
                                      baseline.persisted.hard_kill_state.release_evidence,
                                      SWV5_HARD_KILL_RELEASE_HISTORICAL_PERSISTED,
                                      decision);
   SWV5_TestRecordCondition(collector,"S48-HKA-S03","SPRINT4_8_HARD_KILL_AUTHORITY",
                            !legacy_historical && decision.disposition!=SWV5_DISPOSITION_ALLOW,
                            "historical_mode_without_independent_record_fails_closed");
}

bool SWV5_TestReplaceOnce(string &text,const string find,const string replacement)
{
   const int at=StringFind(text,find);
   if(at<0) return false;
   text=StringSubstr(text,0,at)+replacement+StringSubstr(text,at+StringLen(find));
   return true;
}

string SWV5_TestImpossibleFirstLength(const string text)
{
   const int first=StringFind(text,":");
   const int second=StringFind(text,":",first+1);
   const int third=StringFind(text,":",second+1);
   if(first<0 || second<0 || third<0) return "";
   return StringSubstr(text,0,second+1)+"999999999"+StringSubstr(text,third);
}

string SWV5_TestMalformedFieldPayload(const string text,const string field_prefix,const string replacement_character)
{
   const int at=StringFind(text,field_prefix);
   if(at<0) return "";
   const int length_start=at+StringLen(field_prefix);
   const int colon=StringFind(text,":",length_start);
   if(colon<0 || colon+1>=StringLen(text)) return "";
   return StringSubstr(text,0,colon+1)+replacement_character+StringSubstr(text,colon+2);
}

void SWV5_RunSprint48RoundTripTests(SWV5_TestCollector &collector)
{
   SWV5_RiskEvaluationInput risk; SWV5_TestMakeRiskInput(risk);
   SWV5_RestartReconciliationInput restart; SWV5_TestMakeReleasedRestart(restart);
   SWV5_HardKillState hard_kill=restart.persisted.hard_kill_state;

   const string margin_text=SWV5_TestCanonicalMarginEvidence(risk.projected.margin_evidence);
   SWV5_MarginProjectionEvidence margin_new;
   const bool margin_ok=SWV5_TestDecodeMarginEvidence(margin_text,margin_new) &&
                        margin_text==SWV5_TestCanonicalMarginEvidence(margin_new) &&
                        risk.projected.margin_evidence.evidence_digest==margin_new.evidence_digest;
   SWV5_TestRecordCondition(collector,"S48-RT-V5-01","SPRINT4_8_TRUE_ROUND_TRIP",margin_ok,"margin_reconstructed_exactly");

   const string basket_risk_text=SWV5_TestCanonicalBasketRiskEvidence(risk.projected.basket_risk_evidence);
   SWV5_BasketRiskProjectionEvidence basket_risk_new;
   const bool basket_risk_ok=SWV5_TestDecodeBasketRiskEvidence(basket_risk_text,basket_risk_new) &&
                             basket_risk_text==SWV5_TestCanonicalBasketRiskEvidence(basket_risk_new) &&
                             risk.projected.basket_risk_evidence.evidence_digest==basket_risk_new.evidence_digest;
   SWV5_TestRecordCondition(collector,"S48-RT-V5-02","SPRINT4_8_TRUE_ROUND_TRIP",basket_risk_ok,"basket_risk_reconstructed_exactly");

   const string broker_text=SWV5_TestCanonicalBrokerSummary(restart.broker);
   SWV5_AuthoritativeBrokerSummary broker_new;
   const bool broker_ok=SWV5_TestDecodeBrokerSummary(broker_text,broker_new) &&
                        broker_text==SWV5_TestCanonicalBrokerSummary(broker_new) &&
                        restart.broker.complete_summary_digest==broker_new.complete_summary_digest;
   SWV5_TestRecordCondition(collector,"S48-RT-V5-03","SPRINT4_8_TRUE_ROUND_TRIP",broker_ok,"broker_summary_reconstructed_exactly");

   const string vector_text=SWV5_TestCanonicalReconciliationVector(restart.persisted.reconciliation_vector);
   SWV5_PersistedReconciliationVector vector_new;
   const bool vector_ok=SWV5_TestDecodeReconciliationVector(vector_text,vector_new) &&
                        vector_text==SWV5_TestCanonicalReconciliationVector(vector_new) &&
                        SWV5_TestReconciliationVectorDigest(restart.persisted.reconciliation_vector)==SWV5_TestReconciliationVectorDigest(vector_new);
   SWV5_TestRecordCondition(collector,"S48-RT-V5-04","SPRINT4_8_TRUE_ROUND_TRIP",vector_ok,"reconciliation_vector_reconstructed_exactly");

   const string release_text=SWV5_TestCanonicalHardKillRelease(hard_kill.release_evidence);
   SWV5_HardKillReleaseEvidence release_new;
   const bool release_ok=SWV5_TestDecodeHardKillRelease(release_text,release_new) &&
                         release_text==SWV5_TestCanonicalHardKillRelease(release_new) &&
                         hard_kill.release_evidence.release_record_digest==release_new.release_record_digest;
   SWV5_TestRecordCondition(collector,"S48-RT-V5-05","SPRINT4_8_TRUE_ROUND_TRIP",release_ok,"hard_kill_release_reconstructed_exactly");

   const string authority_text=SWV5_TestCanonicalHardKillAuthorityRecord(restart.release_authority_record);
   SWV5_HardKillReleaseAuthorityRecord authority_new;
   const bool authority_ok=SWV5_TestDecodeHardKillAuthorityRecord(authority_text,authority_new) &&
                           authority_text==SWV5_TestCanonicalHardKillAuthorityRecord(authority_new) &&
                           restart.release_authority_record.authority_record_digest==authority_new.authority_record_digest;
   SWV5_TestRecordCondition(collector,"S48-RT-V5-06","SPRINT4_8_TRUE_ROUND_TRIP",authority_ok,"hard_kill_authority_reconstructed_exactly");

   const string checkpoint_text=SWV5_TestCanonicalCheckpointPayload(restart.persisted);
   SWV5_PersistedCheckpoint checkpoint_new;
   const bool checkpoint_ok=SWV5_TestDecodeCheckpoint(checkpoint_text,checkpoint_new) &&
                            checkpoint_text==SWV5_TestCanonicalCheckpointPayload(checkpoint_new) &&
                            restart.persisted.header.payload_digest==checkpoint_new.header.payload_digest;
   SWV5_TestRecordCondition(collector,"S48-RT-V5-07","SPRINT4_8_TRUE_ROUND_TRIP",checkpoint_ok,"checkpoint_reconstructed_exactly");

   string malformed=StringSubstr(margin_text,1); SWV5_MarginProjectionEvidence rejected;
   SWV5_TestRecordCondition(collector,"S48-RT-NEG-01","SPRINT4_8_TRUE_ROUND_TRIP",!SWV5_TestDecodeMarginEvidence(malformed,rejected),"truncated_prefix_rejected");
   malformed=StringSubstr(margin_text,0,StringLen(margin_text)-1);
   SWV5_TestRecordCondition(collector,"S48-RT-NEG-02","SPRINT4_8_TRUE_ROUND_TRIP",!SWV5_TestDecodeMarginEvidence(malformed,rejected),"truncated_payload_rejected");
   malformed=SWV5_TestImpossibleFirstLength(margin_text);
   SWV5_TestRecordCondition(collector,"S48-RT-NEG-03","SPRINT4_8_TRUE_ROUND_TRIP",!SWV5_TestDecodeMarginEvidence(malformed,rejected),"impossible_declared_length_rejected");
   malformed=margin_text; SWV5_TestReplaceOnce(malformed,"contract_version:x:","contract_version:s:");
   SWV5_TestRecordCondition(collector,"S48-RT-NEG-04","SPRINT4_8_TRUE_ROUND_TRIP",!SWV5_TestDecodeMarginEvidence(malformed,rejected),"malformed_type_rejected");
   malformed=margin_text; SWV5_TestReplaceOnce(malformed,"basket_id:s:","symbol:s:");
   SWV5_TestRecordCondition(collector,"S48-RT-NEG-05","SPRINT4_8_TRUE_ROUND_TRIP",!SWV5_TestDecodeMarginEvidence(malformed,rejected),"wrong_field_order_rejected");
   const int missing_at=StringFind(margin_text,"evidence_sequence:u:"); malformed=StringSubstr(margin_text,0,missing_at);
   SWV5_TestRecordCondition(collector,"S48-RT-NEG-06","SPRINT4_8_TRUE_ROUND_TRIP",!SWV5_TestDecodeMarginEvidence(malformed,rejected),"missing_field_rejected");
   malformed=margin_text+"X";
   SWV5_TestRecordCondition(collector,"S48-RT-NEG-07","SPRINT4_8_TRUE_ROUND_TRIP",!SWV5_TestDecodeMarginEvidence(malformed,rejected),"trailing_bytes_rejected");
   malformed=margin_text; SWV5_TestReplaceOnce(malformed,"SWV5-PRODUCTION","SWV5-PRODUCTIOX");
   SWV5_TestRecordCondition(collector,"S48-RT-NEG-08","SPRINT4_8_TRUE_ROUND_TRIP",!SWV5_TestDecodeMarginEvidence(malformed,rejected),"corrupt_nested_object_rejected");
   malformed=margin_text; SWV5_TestReplaceOnce(malformed,"schema_version:i:1:5","schema_version:i:1:4");
   SWV5_TestRecordCondition(collector,"S48-RT-NEG-09","SPRINT4_8_TRUE_ROUND_TRIP",!SWV5_TestDecodeMarginEvidence(malformed,rejected),"v4_contract_version_rejected");
   malformed=basket_risk_text; SWV5_TestReplaceOnce(malformed,"includes_fee:b:1:1","includes_fee:b:1:2");
   SWV5_BasketRiskProjectionEvidence basket_rejected;
   SWV5_TestRecordCondition(collector,"S48-RT-NEG-10","SPRINT4_8_TRUE_ROUND_TRIP",!SWV5_TestDecodeBasketRiskEvidence(malformed,basket_rejected),"malformed_boolean_rejected");
   malformed=SWV5_TestMalformedFieldPayload(margin_text,"requested_volume:d:","X");
   SWV5_TestRecordCondition(collector,"S48-RT-NEG-11","SPRINT4_8_TRUE_ROUND_TRIP",!SWV5_TestDecodeMarginEvidence(malformed,rejected),"malformed_numeric_rejected");
}

void SWV5_RunSprint48MetadataConformanceTests(SWV5_TestCollector &collector)
{
   const string expected_schema="SWV5-CONTRACT-TEST-RESULT-V"+IntegerToString(SWV5_PRODUCTION_CONTRACT_VERSION);
   const bool passed=SWV5_TestResultSchemaIdentity()==expected_schema &&
                     SWV5_TestResultProductionPolicy()==SWV5_PRODUCTION_CONTRACT_POLICY;
   SWV5_TestRecordCondition(collector,"S48-META-01","SPRINT4_8_METADATA_CONFORMANCE",passed,"machine_identity_matches_compiled_contract_constants");
}

void SWV5_RunSprint48B6MarginAuthorityTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=15;number++)
   {
      SWV5_ContractValidationContext context; SWV5_TestMakeContext(context);
      SWV5_RiskEvaluationInput engineInput; SWV5_TestMakeRiskInput(engineInput);
      if(number==2) engineInput.has_margin_authority_record=false;
      if(number==3)
      {
         engineInput.projected.margin_evidence.additional_margin=context.price_tolerance*2.0;
         engineInput.projected.margin_evidence.projected_account_margin=
            engineInput.projected.margin_evidence.current_account_margin+engineInput.projected.margin_evidence.additional_margin;
         engineInput.projected.projected_margin=engineInput.projected.margin_evidence.additional_margin;
         engineInput.projected.margin_evidence.evidence_digest=SWV5_TestMarginEvidenceDigest(engineInput.projected.margin_evidence);
      }
      if(number==4)
      {
         engineInput.projected.margin_evidence.additional_margin+=1.0;
         engineInput.projected.margin_evidence.projected_account_margin+=1.0;
         engineInput.projected.projected_margin=engineInput.projected.margin_evidence.additional_margin;
         engineInput.projected.margin_evidence.evidence_digest=SWV5_TestMarginEvidenceDigest(engineInput.projected.margin_evidence);
      }
      if(number==5){ engineInput.projected.margin_evidence.request_identity.request_id.attempt_id="FORGED"; engineInput.projected.margin_evidence.evidence_digest=SWV5_TestMarginEvidenceDigest(engineInput.projected.margin_evidence); }
      if(number==6){ engineInput.projected.margin_evidence.symbol="OTHER"; engineInput.projected.margin_evidence.evidence_digest=SWV5_TestMarginEvidenceDigest(engineInput.projected.margin_evidence); }
      if(number==7){ engineInput.projected.margin_evidence.symbol_specification_sequence++; engineInput.projected.margin_evidence.evidence_digest=SWV5_TestMarginEvidenceDigest(engineInput.projected.margin_evidence); }
      if(number==8){ engineInput.projected.margin_evidence.requested_volume+=0.01; engineInput.projected.margin_evidence.evidence_digest=SWV5_TestMarginEvidenceDigest(engineInput.projected.margin_evidence); }
      if(number==9){ engineInput.projected.margin_evidence.requested_price+=0.10; engineInput.projected.margin_evidence.evidence_digest=SWV5_TestMarginEvidenceDigest(engineInput.projected.margin_evidence); }
      if(number==10){ engineInput.projected.margin_evidence.account_namespace.account_login++; engineInput.projected.margin_evidence.evidence_digest=SWV5_TestMarginEvidenceDigest(engineInput.projected.margin_evidence); }
      if(number==11)
      {
         engineInput.margin_authority_record.observed_at=SWV5_TEST_TIME-120;
         engineInput.margin_authority_record.calculated_at=SWV5_TEST_TIME-120;
         engineInput.margin_authority_record.authority_record_digest=SWV5_TestMarginAuthorityDigest(engineInput.margin_authority_record);
         engineInput.projected.margin_evidence.observed_at=engineInput.margin_authority_record.observed_at;
         engineInput.projected.margin_evidence.calculated_at=engineInput.margin_authority_record.calculated_at;
         engineInput.projected.margin_evidence.authority_record_digest=engineInput.margin_authority_record.authority_record_digest;
         engineInput.projected.margin_evidence.evidence_digest=SWV5_TestMarginEvidenceDigest(engineInput.projected.margin_evidence);
      }
      if(number==12)
      {
         engineInput.margin_authority_record.authority_source=SWV5_AUTHORITY_PERSISTED_CHECKPOINT;
         engineInput.margin_authority_record.authority_record_digest=SWV5_TestMarginAuthorityDigest(engineInput.margin_authority_record);
         engineInput.projected.margin_evidence.authority_record_digest=engineInput.margin_authority_record.authority_record_digest;
         engineInput.projected.margin_evidence.evidence_digest=SWV5_TestMarginEvidenceDigest(engineInput.projected.margin_evidence);
      }
      if(number==13) engineInput.margin_authority_record.authority_record_digest="CORRUPT";
      if(number==14){ engineInput.projected.margin_evidence.authority_record_sequence++; engineInput.projected.margin_evidence.evidence_digest=SWV5_TestMarginEvidenceDigest(engineInput.projected.margin_evidence); }
      SWV5_TestRiskContract implementation; SWV5_RiskAuthorization authorization;
      const bool allowed=implementation.Evaluate(context,engineInput,authorization);
      const bool expected=(number==1 || number==15);
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S48-MAUTH",number),"SPRINT4_8_MARGIN_AUTHORITY",
                               allowed==expected,expected ? "independent_broker_margin_authority_allows" : "authority_disagreement_denies");
   }
}

void SWV5_RunSprint48B6BasketAuthorityTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=15;number++)
   {
      SWV5_ContractValidationContext context; SWV5_TestMakeContext(context);
      SWV5_RiskEvaluationInput engineInput; SWV5_TestMakeRiskInput(engineInput);
      SWV5_BasketRiskProjectionEvidence evidence=engineInput.projected.basket_risk_evidence;
      if(number==2) engineInput.has_basket_risk_authority_record=false;
      if(number==3){ evidence.existing_bounded_basket_loss=1.0; evidence.resulting_basket_maximum_loss=evidence.existing_bounded_basket_loss+evidence.incremental_request_bounded_loss+evidence.interaction_or_offset_adjustment; }
      if(number==4){ evidence.incremental_request_bounded_loss=1.0; evidence.resulting_basket_maximum_loss=evidence.existing_bounded_basket_loss+evidence.incremental_request_bounded_loss+evidence.interaction_or_offset_adjustment; }
      if(number==5){ evidence.existing_bounded_basket_loss=1.0; evidence.incremental_request_bounded_loss=1.0; evidence.resulting_basket_maximum_loss=2.0; }
      if(number==6) evidence.source_snapshot_digest="CALLER-INVENTED-SOURCE";
      if(number==7) evidence.basket_state_version++;
      if(number==8) evidence.request_identity.request_id.attempt_id="FORGED";
      if(number==9) evidence.symbol_specification_sequence++;
      if(number==10)
      {
         evidence.observed_at=SWV5_TEST_TIME-120; evidence.calculated_at=SWV5_TEST_TIME-120;
         engineInput.basket_risk_authority_record.observed_at=evidence.observed_at;
         engineInput.basket_risk_authority_record.calculated_at=evidence.calculated_at;
         engineInput.basket_risk_authority_record.authority_record_digest=SWV5_TestBasketRiskAuthorityDigest(engineInput.basket_risk_authority_record);
         evidence.authority_record_digest=engineInput.basket_risk_authority_record.authority_record_digest;
      }
      if(number==11) evidence.persistence_namespace.ownership_namespace.server="FOREIGN";
      if(number==12)
      {
         evidence.calculation_policy_id="WRONG-RISK-POLICY";
         engineInput.basket_risk_authority_record.calculation_policy_id=evidence.calculation_policy_id;
         engineInput.basket_risk_authority_record.authority_record_digest=SWV5_TestBasketRiskAuthorityDigest(engineInput.basket_risk_authority_record);
         evidence.authority_record_digest=engineInput.basket_risk_authority_record.authority_record_digest;
      }
      if(number==13) engineInput.basket_risk_authority_record.authority_record_digest="CORRUPT";
      if(number==14){ evidence.existing_bounded_basket_loss=1.0; evidence.incremental_request_bounded_loss=1.0; evidence.interaction_or_offset_adjustment=0.0; evidence.resulting_basket_maximum_loss=2.0; }
      if((number>=3 && number<=12) || number==14)
      {
         evidence.evidence_digest=SWV5_TestBasketRiskEvidenceDigest(evidence);
         engineInput.projected.basket_risk_evidence=evidence;
         engineInput.projected.projected_maximum_loss=evidence.resulting_basket_maximum_loss;
      }
      SWV5_TestRiskContract implementation; SWV5_RiskAuthorization authorization;
      const bool allowed=implementation.Evaluate(context,engineInput,authorization);
      const bool expected=(number==1 || number==15);
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S48-BAUTH",number),"SPRINT4_8_BASKET_AUTHORITY",
                               allowed==expected,expected ? "independent_resulting_basket_authority_allows" : "authority_or_source_disagreement_denies");
   }
}

void SWV5_RunSprint48B6PersistenceAtomicityTests(SWV5_TestCollector &collector)
{
   SWV5_ContractValidationContext context; SWV5_TestMakeContext(context);
   SWV5_PersistedCheckpoint checkpoint; SWV5_TestMakeCheckpoint(checkpoint);
   SWV5_PersistedRequestEvidence empty[]; ArrayResize(empty,0);
   SWV5_TestPersistenceContract persistence; persistence.Configure(checkpoint,empty);
   SWV5_PersistedRequestEvidence set_a[],set_b[]; ArrayResize(set_a,1); ArrayResize(set_b,1);
   SWV5_TestMakePersistedRequest(set_a[0],1); SWV5_TestMakePersistedRequest(set_b[0],2);
   SWV5_PersistedRequestSetHeader header_a,header_b;
   SWV5_TestBindRequestSetHeader(header_a,set_a,40); SWV5_TestBindRequestSetHeader(header_b,set_b,41);
   SWV5_ContractDecision decision; SWV5_PersistenceLoadResult load_result;
   const bool saved_a=persistence.SavePendingRequests(context,checkpoint.header.persistence_namespace,set_a,header_a,decision);
   SWV5_PersistedCheckpoint state_a; const bool loaded_a=persistence.LoadLatest(context,checkpoint.header.persistence_namespace,state_a,load_result);
   const string store_a=(loaded_a ? state_a.header.store_revision : "");
   const bool saved_b=persistence.SavePendingRequests(context,checkpoint.header.persistence_namespace,set_b,header_b,decision);
   SWV5_PersistedCheckpoint state_b; const bool loaded_b=persistence.LoadLatest(context,checkpoint.header.persistence_namespace,state_b,load_result);
   SWV5_PersistedRequestEvidence loaded_requests[];
   const bool requests_b=persistence.LoadPendingRequests(context,checkpoint.header.persistence_namespace,loaded_requests,load_result);
   const bool base=saved_a && loaded_a && saved_b && loaded_b && requests_b && ArraySize(loaded_requests)==1;
   SWV5_TestRecordCondition(collector,"S48-PAT-01","SPRINT4_8_PERSISTENCE_ATOMICITY",base && state_b.reconciliation_vector.pending_request_count==1 && state_b.reconciliation_vector.request_set_digest==header_b.request_set_digest && state_b.reconciliation_vector.request_set_revision==header_b.request_index_revision,"complete_vector_b");
   SWV5_TestRecordCondition(collector,"S48-PAT-02","SPRINT4_8_PERSISTENCE_ATOMICITY",base && state_b.has_latest_pending_request && SWV5_TestPersistedRequestEqual(state_b.latest_pending_request,set_b[0]),"latest_request_b");
   SWV5_TestRecordCondition(collector,"S48-PAT-03","SPRINT4_8_PERSISTENCE_ATOMICITY",base && state_b.pending_request_set.request_count==1 && state_b.reconciliation_vector.pending_request_count==1 && state_b.basket.lifecycle.pending_request_count==1,"pending_count_coherent_everywhere");
   SWV5_TestRecordCondition(collector,"S48-PAT-04","SPRINT4_8_PERSISTENCE_ATOMICITY",base && state_b.pending_request_set.request_set_digest==state_b.reconciliation_vector.request_set_digest && state_b.pending_request_set.request_index_revision==state_b.reconciliation_vector.request_set_revision,"digest_revision_coherent_everywhere");
   SWV5_TestRecordCondition(collector,"S48-PAT-05","SPRINT4_8_PERSISTENCE_ATOMICITY",base && state_b.reconciliation_vector.reconciliation_revision==41 && state_b.reconciliation_vector.reconciliation_revision>state_a.reconciliation_vector.reconciliation_revision,"reconciliation_revision_advanced");
   SWV5_TestRecordCondition(collector,"S48-PAT-06","SPRINT4_8_PERSISTENCE_ATOMICITY",base && state_b.header.record_sequence==41,"record_sequence_advanced");
   SWV5_TestRecordCondition(collector,"S48-PAT-07","SPRINT4_8_PERSISTENCE_ATOMICITY",base && state_b.header.previous_record_sequence==40,"previous_sequence_is_a");
   SWV5_TestRecordCondition(collector,"S48-PAT-08","SPRINT4_8_PERSISTENCE_ATOMICITY",base && state_b.header.store_revision!="" && state_b.header.store_revision!=store_a && SWV5_TestPersistenceRecordValid(context,state_b),"cas_revision_and_checkpoint_seal_coherent");

   SWV5_PersistedRequestSetHeader empty_header; SWV5_TestBindRequestSetHeader(empty_header,empty,42);
   const bool emptied=persistence.SavePendingRequests(context,checkpoint.header.persistence_namespace,empty,empty_header,decision);
   SWV5_PersistedCheckpoint state_empty; const bool loaded_empty=persistence.LoadLatest(context,checkpoint.header.persistence_namespace,state_empty,load_result);
   SWV5_TestRecordCondition(collector,"S48-PAT-09","SPRINT4_8_PERSISTENCE_ATOMICITY",emptied && loaded_empty && !state_empty.has_latest_pending_request && state_empty.pending_request_set.request_count==0 && state_empty.reconciliation_vector.pending_request_count==0 && state_empty.basket.lifecycle.pending_request_count==0,"empty_replacement_clears_all_request_state");

   const string before_failure=SWV5_TestCanonicalCheckpointPayload(state_empty);
   SWV5_PersistedRequestSetHeader invalid_header; SWV5_TestBindRequestSetHeader(invalid_header,set_b,43); invalid_header.request_set_digest="CORRUPT";
   const bool rejected=!persistence.SavePendingRequests(context,checkpoint.header.persistence_namespace,set_b,invalid_header,decision);
   SWV5_PersistedCheckpoint after_failure; const bool loaded_after=persistence.LoadLatest(context,checkpoint.header.persistence_namespace,after_failure,load_result);
   SWV5_TestRecordCondition(collector,"S48-PAT-10","SPRINT4_8_PERSISTENCE_ATOMICITY",rejected && loaded_after && before_failure==SWV5_TestCanonicalCheckpointPayload(after_failure),"failed_replace_is_atomic");
   SWV5_TestRecordCondition(collector,"S48-PAT-11","SPRINT4_8_PERSISTENCE_ATOMICITY",loaded_after && SWV5_TestPersistenceRecordValid(context,after_failure),"load_latest_observes_complete_post_save_state");
   SWV5_TestRecordCondition(collector,"S48-PAT-12","SPRINT4_8_PERSISTENCE_ATOMICITY",loaded_after && after_failure.reconciliation_vector.source_summary_digest==SWV5_TestReconciliationSourceDigest(after_failure.reconciliation_vector),"source_summary_is_full_vector_digest");
}

void SWV5_RunSprint48B6IdentityTests(SWV5_TestCollector &collector)
{
   const string suffix="/V"+IntegerToString(SWV5_PRODUCTION_CONTRACT_VERSION);
   SWV5_TestVersionPolicy version; SWV5_TestBasketStateContract state; SWV5_TestBasketContract basket;
   SWV5_TestExecutionContract execution; SWV5_TestPersistenceContract persistence; SWV5_TestRiskContract risk;
   SWV5_TestStatisticsContract statistics; SWV5_TestOwnershipContract ownership; SWV5_TestUnitSystemContract units;
   SWV5_TestRecordCondition(collector,"S48-ID-01","SPRINT4_8_V5_IDENTITY",version.ContractName()=="ISWV5ContractVersionPolicy"+suffix,"version_policy_v5");
   SWV5_TestRecordCondition(collector,"S48-ID-02","SPRINT4_8_V5_IDENTITY",state.ContractName()=="ISWV5BasketStateMachineContract"+suffix,"state_machine_v5");
   SWV5_TestRecordCondition(collector,"S48-ID-03","SPRINT4_8_V5_IDENTITY",basket.ContractName()=="ISWV5BasketContract"+suffix,"basket_v5");
   SWV5_TestRecordCondition(collector,"S48-ID-04","SPRINT4_8_V5_IDENTITY",execution.ContractName()=="ISWV5ExecutionContract"+suffix,"execution_v5");
   SWV5_TestRecordCondition(collector,"S48-ID-05","SPRINT4_8_V5_IDENTITY",persistence.ContractName()=="ISWV5PersistenceContract"+suffix,"persistence_v5");
   SWV5_TestRecordCondition(collector,"S48-ID-06","SPRINT4_8_V5_IDENTITY",risk.ContractName()=="ISWV5RiskContract"+suffix,"risk_v5");
   SWV5_TestRecordCondition(collector,"S48-ID-07","SPRINT4_8_V5_IDENTITY",statistics.ContractName()=="ISWV5StatisticsContract"+suffix,"statistics_v5");
   SWV5_TestRecordCondition(collector,"S48-ID-08","SPRINT4_8_V5_IDENTITY",ownership.ContractName()=="ISWV5InstanceOwnershipContract"+suffix,"ownership_v5");
   SWV5_TestRecordCondition(collector,"S48-ID-09","SPRINT4_8_V5_IDENTITY",units.ContractName()=="ISWV5UnitSystemContract"+suffix,"unit_system_v5");
   SWV5_TestRecordCondition(collector,"S48-ID-10","SPRINT4_8_V5_IDENTITY",SWV5_TestResultSchemaIdentity()=="SWV5-CONTRACT-TEST-RESULT-V5" && SWV5_TestResultProductionPolicy()==SWV5_PRODUCTION_CONTRACT_POLICY,"machine_schema_policy_v5");
   SWV5_RiskEvaluationInput engineInput; SWV5_TestMakeRiskInput(engineInput);
   const string expected_margin_digest=SWV5_TestCanonicalHash(SWV5_TestCanonicalField("format","s","SWV5-MARGIN-PROJECTION-V5-LP1")+SWV5_TestCanonicalMarginEvidence(engineInput.projected.margin_evidence));
   SWV5_TestRecordCondition(collector,"S48-ID-11","SPRINT4_8_V5_IDENTITY",expected_margin_digest==SWV5_TestMarginEvidenceDigest(engineInput.projected.margin_evidence),"active_serializer_format_v5");
   SWV5_MarginProjectionEvidence rejected; string historical=SWV5_TestCanonicalMarginEvidence(engineInput.projected.margin_evidence); SWV5_TestReplaceOnce(historical,"schema_version:i:1:5","schema_version:i:1:4");
   SWV5_TestRecordCondition(collector,"S48-ID-12","SPRINT4_8_V5_IDENTITY",StringFind(SWV5_TestSuiteIdentity(),"SPRINT4.8-V5-")==0 && !SWV5_TestDecodeMarginEvidence(historical,rejected),"current_suite_v5_and_historical_v4_rejected");
}

bool SWV5_TestMonetaryBasisMutationChangesBasketDigest(const int number)
{
   SWV5_RiskEvaluationInput risk; SWV5_TestMakeRiskInput(risk);
   const string original=SWV5_TestBasketRiskEvidenceDigest(risk.projected.basket_risk_evidence);
   SWV5_BasketRiskProjectionEvidence changed=risk.projected.basket_risk_evidence;
   switch(number)
   {
      case 1: changed.monetary_basis.contract_version.schema_version++; break;
      case 2: changed.monetary_basis.calculation_basis=(SWV5_RiskCalculationBasis)99; break;
      case 3: changed.monetary_basis.sign_convention=(SWV5_RiskSignConvention)99; break;
      case 4: changed.monetary_basis.includes_realized=!changed.monetary_basis.includes_realized; break;
      case 5: changed.monetary_basis.includes_unrealized=!changed.monetary_basis.includes_unrealized; break;
      case 6: changed.monetary_basis.includes_commission=!changed.monetary_basis.includes_commission; break;
      case 7: changed.monetary_basis.includes_swap=!changed.monetary_basis.includes_swap; break;
      case 8: changed.monetary_basis.includes_fee=!changed.monetary_basis.includes_fee; break;
      case 9: changed.monetary_basis.currency+=".MUTATED"; break;
      case 10: changed.monetary_basis.account_currency+=".MUTATED"; break;
      case 11: changed.monetary_basis.conversion_rate_to_account_currency+=0.25; break;
      case 12: changed.monetary_basis.conversion_source+=".MUTATED"; break;
      case 13: changed.monetary_basis.valuation_at++; break;
      default: return false;
   }
   return original!=SWV5_TestBasketRiskEvidenceDigest(changed);
}

bool SWV5_TestMarginAuthorityAllFieldsDigestBound()
{
   for(int number=1;number<=25;number++)
   {
      SWV5_RiskEvaluationInput risk; SWV5_TestMakeRiskInput(risk);
      SWV5_MarginAuthorityRecord changed=risk.margin_authority_record;
      const string original=SWV5_TestMarginAuthorityDigest(changed);
      switch(number)
      {
         case 1: changed.contract_version.schema_version++; break;
         case 2: changed.persistence_namespace.basket_id.value+="X"; break;
         case 3: changed.account_namespace.snapshot_sequence++; break;
         case 4: changed.ownership_fence.takeover_generation++; break;
         case 5: changed.request_identity.request_id.attempt_id+="X"; break;
         case 6: changed.basket_id.value+="X"; break;
         case 7: changed.symbol+="X"; break;
         case 8: changed.symbol_specification_sequence++; break;
         case 9: changed.intent_type=(SWV5_ExecutionIntentType)99; break;
         case 10: changed.direction=-changed.direction; break;
         case 11: changed.requested_volume+=0.01; break;
         case 12: changed.requested_price+=0.01; break;
         case 13: changed.current_account_margin+=1.0; break;
         case 14: changed.projected_account_margin+=1.0; break;
         case 15: changed.additional_margin+=1.0; break;
         case 16: changed.current_free_margin+=1.0; break;
         case 17: changed.account_currency+="X"; break;
         case 18: changed.broker_calculation_reference+="X"; break;
         case 19: changed.observation_sequence++; break;
         case 20: changed.observed_at++; break;
         case 21: changed.calculated_at++; break;
         case 22: changed.authority_record_id+="X"; break;
         case 23: changed.authority_record_sequence++; break;
         case 24: changed.issuing_component=SWV5_COMPONENT_AUTHORITY_EXECUTION; break;
         case 25: changed.authority_source=SWV5_AUTHORITY_PERSISTED_CHECKPOINT; break;
      }
      if(original==SWV5_TestMarginAuthorityDigest(changed)) return false;
   }
   return true;
}

bool SWV5_TestBasketAuthorityAllFieldsDigestBound()
{
   for(int number=1;number<=27;number++)
   {
      SWV5_RiskEvaluationInput risk; SWV5_TestMakeRiskInput(risk);
      SWV5_BasketRiskAuthorityRecord changed=risk.basket_risk_authority_record;
      const string original=SWV5_TestBasketRiskAuthorityDigest(changed);
      switch(number)
      {
         case 1: changed.contract_version.schema_version++; break;
         case 2: changed.persistence_namespace.basket_id.value+="X"; break;
         case 3: changed.account_namespace.snapshot_sequence++; break;
         case 4: changed.ownership_fence.takeover_generation++; break;
         case 5: changed.basket_id.value+="X"; break;
         case 6: changed.basket_state_version++; break;
         case 7: changed.request_identity.request_id.attempt_id+="X"; break;
         case 8: changed.symbol+="X"; break;
         case 9: changed.symbol_specification_sequence++; break;
         case 10: changed.source_snapshot_id+="X"; break;
         case 11: changed.source_snapshot_digest+="X"; break;
         case 12: changed.existing_bounded_basket_loss+=1.0; break;
         case 13: changed.incremental_request_bounded_loss+=1.0; break;
         case 14: changed.interaction_or_offset_adjustment+=1.0; break;
         case 15: changed.resulting_basket_maximum_loss+=1.0; break;
         case 16: changed.realized_loss_basis+=1.0; break;
         case 17: changed.unrealized_loss_basis+=1.0; break;
         case 18: changed.accrued_cost_basis+=1.0; break;
         case 19: changed.monetary_basis.conversion_source+="X"; break;
         case 20: changed.calculation_policy_id+="X"; break;
         case 21: changed.observation_sequence++; break;
         case 22: changed.observed_at++; break;
         case 23: changed.calculated_at++; break;
         case 24: changed.authority_record_id+="X"; break;
         case 25: changed.authority_record_sequence++; break;
         case 26: changed.issuing_component=SWV5_COMPONENT_AUTHORITY_EXECUTION; break;
         case 27: changed.authority_source=SWV5_AUTHORITY_PERSISTED_CHECKPOINT; break;
      }
      if(original==SWV5_TestBasketRiskAuthorityDigest(changed)) return false;
   }
   return true;
}

bool SWV5_TestMarginAllFieldsDigestBound()
{
   for(int number=1;number<=23;number++)
   {
      SWV5_RiskEvaluationInput risk; SWV5_TestMakeRiskInput(risk);
      SWV5_MarginProjectionEvidence changed=risk.projected.margin_evidence;
      const string original=SWV5_TestMarginEvidenceDigest(changed);
      switch(number)
      {
         case 1: changed.contract_version.schema_version++; break;
         case 2: changed.persistence_namespace.basket_id.value+="X"; break;
         case 3: changed.account_namespace.snapshot_sequence++; break;
         case 4: changed.ownership_fence.takeover_generation++; break;
         case 5: changed.request_identity.request_id.attempt_id+="X"; break;
         case 6: changed.basket_id.value+="X"; break;
         case 7: changed.symbol+="X"; break;
         case 8: changed.symbol_specification_sequence++; break;
         case 9: changed.intent_type=(SWV5_ExecutionIntentType)99; break;
         case 10: changed.direction=-changed.direction; break;
         case 11: changed.requested_volume+=0.01; break;
         case 12: changed.requested_price+=1.0; break;
         case 13: changed.current_account_margin+=1.0; break;
         case 14: changed.current_free_margin+=1.0; break;
         case 15: changed.projected_account_margin+=1.0; break;
         case 16: changed.additional_margin+=1.0; break;
         case 17: changed.account_currency+="X"; break;
         case 18: changed.issuing_component=(SWV5_ComponentAuthority)99; break;
         case 19: changed.authority_source=(SWV5_AuthoritySource)99; break;
         case 20: changed.calculation_reference+="X"; break;
         case 21: changed.observed_at++; break;
         case 22: changed.calculated_at++; break;
         case 23: changed.evidence_sequence++; break;
      }
      if(original==SWV5_TestMarginEvidenceDigest(changed)) return false;
   }
   return true;
}

bool SWV5_TestBasketRiskAllFieldsDigestBound()
{
   for(int number=1;number<=24;number++)
   {
      SWV5_RiskEvaluationInput risk; SWV5_TestMakeRiskInput(risk);
      SWV5_BasketRiskProjectionEvidence changed=risk.projected.basket_risk_evidence;
      const string original=SWV5_TestBasketRiskEvidenceDigest(changed);
      switch(number)
      {
         case 1: changed.contract_version.schema_version++; break;
         case 2: changed.persistence_namespace.basket_id.value+="X"; break;
         case 3: changed.account_namespace.snapshot_sequence++; break;
         case 4: changed.ownership_fence.takeover_generation++; break;
         case 5: changed.basket_id.value+="X"; break;
         case 6: changed.basket_state_version++; break;
         case 7: changed.request_identity.request_id.attempt_id+="X"; break;
         case 8: changed.symbol+="X"; break;
         case 9: changed.symbol_specification_sequence++; break;
         case 10: changed.existing_bounded_basket_loss+=1.0; break;
         case 11: changed.incremental_request_bounded_loss+=1.0; break;
         case 12: changed.interaction_or_offset_adjustment+=1.0; break;
         case 13: changed.resulting_basket_maximum_loss+=1.0; break;
         case 14: changed.realized_loss_basis+=1.0; break;
         case 15: changed.unrealized_loss_basis+=1.0; break;
         case 16: changed.accrued_cost_basis+=1.0; break;
         case 17: changed.monetary_basis.includes_fee=!changed.monetary_basis.includes_fee; break;
         case 18: changed.calculation_policy_id+="X"; break;
         case 19: changed.source_snapshot_digest+="X"; break;
         case 20: changed.issuing_component=(SWV5_ComponentAuthority)99; break;
         case 21: changed.authority_source=(SWV5_AuthoritySource)99; break;
         case 22: changed.observed_at++; break;
         case 23: changed.calculated_at++; break;
         case 24: changed.evidence_sequence++; break;
      }
      if(original==SWV5_TestBasketRiskEvidenceDigest(changed)) return false;
   }
   return true;
}

bool SWV5_TestUnitSpecificationAllFieldsBound()
{
   for(int number=1;number<=23;number++)
   {
      SWV5_SymbolUnitSpecification changed; SWV5_TestMakeSymbolSpecification(changed);
      const string original=SWV5_TestSymbolUnitSpecificationDigest(changed);
      switch(number)
      {
         case 1: changed.contract_version.schema_version++; break;
         case 2: changed.symbol+="X"; break;
         case 3: changed.specification_sequence++; break;
         case 4: changed.digits++; break;
         case 5: changed.point_size*=2.0; break;
         case 6: changed.tick_size*=2.0; break;
         case 7: changed.pip_size*=2.0; break;
         case 8: changed.tick_value_profit+=1.0; break;
         case 9: changed.tick_value_loss+=1.0; break;
         case 10: changed.contract_size+=1.0; break;
         case 11: changed.calculation_mode=(SWV5_SymbolCalculationMode)99; break;
         case 12: changed.tick_value_basis_volume+=1.0; break;
         case 13: changed.volume_minimum+=0.01; break;
         case 14: changed.volume_maximum+=0.01; break;
         case 15: changed.volume_step+=0.01; break;
         case 16: changed.stops_level_points++; break;
         case 17: changed.freeze_level_points++; break;
         case 18: changed.account_currency+="X"; break;
         case 19: changed.tick_value_currency+="X"; break;
         case 20: changed.authority_source=(SWV5_AuthoritySource)99; break;
         case 21: changed.observed_at++; break;
         case 22: changed.valid_until++; break;
         case 23: changed.complete=!changed.complete; break;
      }
      if(original==SWV5_TestSymbolUnitSpecificationDigest(changed)) return false;
   }
   return true;
}

bool SWV5_TestBrokerSummaryAllFieldsDigestBound()
{
   for(int number=1;number<=18;number++)
   {
      SWV5_RestartReconciliationInput restart; SWV5_TestMakeRestartInput(restart);
      SWV5_AuthoritativeBrokerSummary changed=restart.broker;
      const string original=SWV5_TestBrokerSummaryDigest(changed);
      switch(number)
      {
         case 1: changed.contract_version.schema_version++; break;
         case 2: changed.persistence_namespace.basket_id.value+="X"; break;
         case 3: changed.symbol_long_volume+=0.01; break;
         case 4: changed.symbol_short_volume+=0.01; break;
         case 5: changed.symbol_net_volume+=0.01; break;
         case 6: changed.aggregate_position_volume+=0.01; break;
         case 7: changed.residual_volume+=0.01; break;
         case 8: changed.position_count++; break;
         case 9: changed.order_count++; break;
         case 10: changed.pending_request_count++; break;
         case 11: changed.latest_confirmed_correlation.phase=(SWV5_ExecutionLifecyclePhase)99; break;
         case 12: changed.latest_broker_event_identity.transaction_sequence++; break;
         case 13: changed.transaction_high_watermark++; break;
         case 14: changed.observation_sequence++; break;
         case 15: changed.account_mode=(SWV5_AccountPositionMode)99; break;
         case 16: changed.queries.completed_flags^=SWV5_QUERY_DEALS; break;
         case 17: changed.observed_at++; break;
         case 18: changed.authority=(SWV5_AuthoritySource)99; break;
      }
      if(original==SWV5_TestBrokerSummaryDigest(changed)) return false;
   }
   return true;
}

bool SWV5_TestReconciliationAllFieldsDigestBound()
{
   for(int number=1;number<=24;number++)
   {
      SWV5_RestartReconciliationInput restart; SWV5_TestMakeRestartInput(restart);
      SWV5_PersistedReconciliationVector changed=restart.persisted.reconciliation_vector;
      const string original=SWV5_TestReconciliationVectorDigest(changed);
      switch(number)
      {
         case 1: changed.contract_version.schema_version++; break;
         case 2: changed.persistence_namespace.basket_id.value+="X"; break;
         case 3: changed.basket_id.value+="X"; break;
         case 4: changed.account_mode=(SWV5_AccountPositionMode)99; break;
         case 5: changed.symbol_long_volume+=0.01; break;
         case 6: changed.symbol_short_volume+=0.01; break;
         case 7: changed.symbol_net_volume+=0.01; break;
         case 8: changed.aggregate_position_volume+=0.01; break;
         case 9: changed.basket_open_volume+=0.01; break;
         case 10: changed.residual_volume+=0.01; break;
         case 11: changed.position_count++; break;
         case 12: changed.order_count++; break;
         case 13: changed.pending_request_count++; break;
         case 14: changed.latest_confirmed_correlation.phase=(SWV5_ExecutionLifecyclePhase)99; break;
         case 15: changed.latest_broker_event_identity.transaction_sequence++; break;
         case 16: changed.transaction_high_watermark++; break;
         case 17: changed.request_set_digest+="X"; break;
         case 18: changed.request_set_revision+="X"; break;
         case 19: changed.basket_state=(SWV5_BasketState)99; break;
         case 20: changed.basket_state_version++; break;
         case 21: changed.hard_kill_generation++; break;
         case 22: changed.ownership_fence.takeover_generation++; break;
         case 23: changed.reconciliation_revision++; break;
         case 24: changed.source_summary_digest+="X"; break;
      }
      if(original==SWV5_TestReconciliationVectorDigest(changed)) return false;
   }
   return true;
}

bool SWV5_TestHardKillReleaseAllFieldsDigestBound()
{
   for(int number=1;number<=22;number++)
   {
      SWV5_HardKillState state; SWV5_TestMakeHistoricalHardKillRelease(state);
      SWV5_HardKillReleaseEvidence changed=state.release_evidence;
      const string original=SWV5_TestHardKillReleaseDigest(changed);
      switch(number)
      {
         case 1: changed.contract_version.schema_version++; break;
         case 2: changed.persistence_namespace.basket_id.value+="X"; break;
         case 3: changed.release_id+="X"; break;
         case 4: changed.latch_id+="X"; break;
         case 5: changed.latch_generation++; break;
         case 6: changed.release_generation++; break;
         case 7: changed.approval_policy_id+="X"; break;
         case 8: changed.approval_sequence++; break;
         case 9: changed.operator_identity.operator_id+="X"; break;
         case 10: changed.operator_identity.authority_role+="X"; break;
         case 11: changed.operator_identity.authentication_reference+="X"; break;
         case 12: changed.operator_identity.authenticated_at++; break;
         case 13: changed.approving_component=(SWV5_ComponentAuthority)99; break;
         case 14: changed.broker_evidence.state_digest+="X"; break;
         case 15: changed.persistence_evidence.state_digest+="X"; break;
         case 16: changed.exposure_evidence.observed_exposure_volume+=0.01; break;
         case 17: changed.approved_at++; break;
         case 18: changed.released_at++; break;
         case 19: changed.expires_at++; break;
         case 20: changed.release_record_sequence++; break;
         case 21: changed.audit_reference+="X"; break;
         case 22: changed.broker_evidence.authority_source=(SWV5_AuthoritySource)99; break;
      }
      if(original==SWV5_TestHardKillReleaseDigest(changed)) return false;
   }
   return true;
}

bool SWV5_TestHardKillAuthorityAllFieldsDigestBound()
{
   for(int number=1;number<=24;number++)
   {
      SWV5_RestartReconciliationInput restart; SWV5_TestMakeReleasedRestart(restart);
      SWV5_HardKillReleaseAuthorityRecord changed=restart.release_authority_record;
      const string original=SWV5_TestHardKillAuthorityRecordDigest(changed);
      switch(number)
      {
         case 1: changed.contract_version.schema_version++; break;
         case 2: changed.persistence_namespace.basket_id.value+="X"; break;
         case 3: changed.account_namespace.snapshot_sequence++; break;
         case 4: changed.latch_id+="X"; break;
         case 5: changed.latch_generation++; break;
         case 6: changed.release_id+="X"; break;
         case 7: changed.release_generation++; break;
         case 8: changed.operator_identity.operator_id+="X"; break;
         case 9: changed.operator_identity.authority_role+="X"; break;
         case 10: changed.operator_identity.authentication_reference+="X"; break;
         case 11: changed.operator_identity.authenticated_at++; break;
         case 12: changed.approving_component=(SWV5_ComponentAuthority)99; break;
         case 13: changed.approval_policy_id+="X"; break;
         case 14: changed.approval_sequence++; break;
         case 15: changed.broker_evidence_reference.state_digest+="X"; break;
         case 16: changed.persistence_evidence_reference.state_digest+="X"; break;
         case 17: changed.exposure_evidence_reference.observed_exposure_volume+=0.01; break;
         case 18: changed.approved_at++; break;
         case 19: changed.released_at++; break;
         case 20: changed.expires_at++; break;
         case 21: changed.release_record_sequence++; break;
         case 22: changed.authority_record_id+="X"; break;
         case 23: changed.issuing_component=(SWV5_ComponentAuthority)99; break;
         case 24: changed.authority_source=(SWV5_AuthoritySource)99; break;
      }
      if(original==SWV5_TestHardKillAuthorityRecordDigest(changed)) return false;
   }
   return true;
}

bool SWV5_TestHardKillAuthorityReferenceAllFieldsBound()
{
   for(int number=1;number<=7;number++)
   {
      SWV5_RestartReconciliationInput restart; SWV5_TestMakeReleasedRestart(restart);
      SWV5_HardKillReleaseAuthorityReference changed=restart.persisted.hard_kill_state.release_authority_reference;
      const string original=SWV5_TestCanonicalHash(SWV5_TestCanonicalHardKillAuthorityReference(changed));
      if(number==1) changed.contract_version.schema_version++;
      if(number==2) changed.authority_record_id+="X";
      if(number==3) changed.authority_record_sequence++;
      if(number==4) changed.authority_record_digest+="X";
      if(number==5) changed.release_id+="X";
      if(number==6) changed.latch_generation++;
      if(number==7) changed.release_generation++;
      if(original==SWV5_TestCanonicalHash(SWV5_TestCanonicalHardKillAuthorityReference(changed))) return false;
   }
   return true;
}

bool SWV5_TestCheckpointAllAuthoritativeDomainsBound()
{
   for(int number=1;number<=12;number++)
   {
      SWV5_RestartReconciliationInput restart; SWV5_TestMakeReleasedRestart(restart);
      SWV5_PersistedCheckpoint changed=restart.persisted;
      const string original=SWV5_TestCheckpointPayloadDigest(changed);
      switch(number)
      {
         case 1: changed.header.record_sequence++; break;
         case 2: changed.header.ownership_fence.takeover_generation++; break;
         case 3: changed.basket.lifecycle.state_version++; break;
         case 4: changed.last_confirmed_correlation.broker_identity.transaction_sequence++; break;
         case 5: changed.pending_request_set.request_set_digest+="X"; break;
         case 6: changed.has_latest_pending_request=!changed.has_latest_pending_request; break;
         case 7: changed.latest_pending_request.record_sequence++; break;
         case 8: changed.hard_kill_state.release_authority_reference.authority_record_id+="X"; break;
         case 9: changed.reconciliation_vector.request_set_revision+="X"; break;
         case 10: changed.clean_shutdown=!changed.clean_shutdown; break;
         case 11: changed.header.written_at++; break;
         case 12: changed.hard_kill_state.release_evidence.operator_identity.authority_role+="X"; break;
      }
      if(original==SWV5_TestCheckpointPayloadDigest(changed)) return false;
   }
   return true;
}

bool SWV5_TestCanonicalNestedSerializerReuse()
{
   SWV5_RiskEvaluationInput risk; SWV5_TestMakeRiskInput(risk);
   SWV5_RestartReconciliationInput restart; SWV5_TestMakeReleasedRestart(restart);
   return StringFind(SWV5_TestCanonicalBasketRiskEvidence(risk.projected.basket_risk_evidence),
                     SWV5_TestCanonicalRiskMonetaryBasis(risk.projected.basket_risk_evidence.monetary_basis))>=0 &&
          StringFind(SWV5_TestCanonicalHardKillRelease(restart.persisted.hard_kill_state.release_evidence),
                     SWV5_TestCanonicalTypedReconciliation(restart.persisted.hard_kill_state.release_evidence.broker_evidence))>=0 &&
          StringFind(SWV5_TestCanonicalHardKillAuthorityRecord(restart.release_authority_record),
                     SWV5_TestCanonicalExposureEvidence(restart.release_authority_record.exposure_evidence_reference))>=0 &&
          StringFind(SWV5_TestCanonicalCheckpointPayload(restart.persisted),
                     SWV5_TestCanonicalReconciliationVector(restart.persisted.reconciliation_vector))>=0;
}

void SWV5_RunSprint48CanonicalIntegrityTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=13;number++)
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("S48-CAN-MB",number),"SPRINT4_8_CANONICAL_INTEGRITY",
                               SWV5_TestMonetaryBasisMutationChangesBasketDigest(number),"monetary_basis_mutation_changes_basket_risk_digest");
   SWV5_TestRecordCondition(collector,"S48-CAN-DTO-01","SPRINT4_8_CANONICAL_INTEGRITY",SWV5_TestMarginAllFieldsDigestBound(),"all_margin_fields_digest_bound");
   SWV5_TestRecordCondition(collector,"S48-CAN-DTO-02","SPRINT4_8_CANONICAL_INTEGRITY",SWV5_TestBasketRiskAllFieldsDigestBound(),"all_basket_risk_fields_digest_bound");
   SWV5_TestRecordCondition(collector,"S48-CAN-DTO-03","SPRINT4_8_CANONICAL_INTEGRITY",SWV5_TestUnitSpecificationAllFieldsBound(),"all_unit_specification_fields_bound");
   SWV5_TestRecordCondition(collector,"S48-CAN-DTO-04","SPRINT4_8_CANONICAL_INTEGRITY",SWV5_TestBrokerSummaryAllFieldsDigestBound(),"all_broker_summary_fields_digest_bound");
   SWV5_TestRecordCondition(collector,"S48-CAN-DTO-05","SPRINT4_8_CANONICAL_INTEGRITY",SWV5_TestReconciliationAllFieldsDigestBound(),"all_reconciliation_fields_digest_bound");
   SWV5_TestRecordCondition(collector,"S48-CAN-DTO-06","SPRINT4_8_CANONICAL_INTEGRITY",SWV5_TestHardKillReleaseAllFieldsDigestBound(),"all_hard_kill_release_fields_digest_bound");
   SWV5_TestRecordCondition(collector,"S48-CAN-DTO-07","SPRINT4_8_CANONICAL_INTEGRITY",SWV5_TestHardKillAuthorityAllFieldsDigestBound(),"all_authority_record_fields_digest_bound");
   SWV5_TestRecordCondition(collector,"S48-CAN-DTO-08","SPRINT4_8_CANONICAL_INTEGRITY",SWV5_TestHardKillAuthorityReferenceAllFieldsBound(),"all_authority_reference_fields_checkpoint_bindable");
   SWV5_TestRecordCondition(collector,"S48-CAN-DTO-09","SPRINT4_8_CANONICAL_INTEGRITY",SWV5_TestCheckpointAllAuthoritativeDomainsBound(),"checkpoint_all_authoritative_domains_bound");

   SWV5_RiskEvaluationInput risk; SWV5_TestMakeRiskInput(risk);
   SWV5_RestartReconciliationInput restart; SWV5_TestMakeReleasedRestart(restart);
   SWV5_MarginProjectionEvidence margin=risk.projected.margin_evidence; const string margin_digest=SWV5_TestMarginEvidenceDigest(margin); margin.evidence_digest+="X";
   SWV5_BasketRiskProjectionEvidence loss=risk.projected.basket_risk_evidence; const string loss_digest=SWV5_TestBasketRiskEvidenceDigest(loss); loss.evidence_digest+="X";
   SWV5_AuthoritativeBrokerSummary broker=restart.broker; const string broker_digest=SWV5_TestBrokerSummaryDigest(broker); broker.complete_summary_digest+="X";
   SWV5_HardKillReleaseEvidence release=restart.persisted.hard_kill_state.release_evidence; const string release_digest=SWV5_TestHardKillReleaseDigest(release); release.release_record_digest+="X";
   SWV5_HardKillReleaseAuthorityRecord authority=restart.release_authority_record; const string authority_digest=SWV5_TestHardKillAuthorityRecordDigest(authority); authority.authority_record_digest+="X";
   SWV5_PersistedCheckpoint checkpoint=restart.persisted; const string checkpoint_digest=SWV5_TestCheckpointPayloadDigest(checkpoint); checkpoint.header.payload_digest+="X"; checkpoint.header.payload_size++;
   SWV5_TestRecordCondition(collector,"S48-CAN-SELF-01","SPRINT4_8_CANONICAL_INTEGRITY",margin_digest==SWV5_TestMarginEvidenceDigest(margin),"margin_self_digest_excluded");
   SWV5_TestRecordCondition(collector,"S48-CAN-SELF-02","SPRINT4_8_CANONICAL_INTEGRITY",loss_digest==SWV5_TestBasketRiskEvidenceDigest(loss),"basket_risk_self_digest_excluded");
   SWV5_TestRecordCondition(collector,"S48-CAN-SELF-03","SPRINT4_8_CANONICAL_INTEGRITY",broker_digest==SWV5_TestBrokerSummaryDigest(broker),"broker_self_digest_excluded");
   SWV5_TestRecordCondition(collector,"S48-CAN-SELF-04","SPRINT4_8_CANONICAL_INTEGRITY",release_digest==SWV5_TestHardKillReleaseDigest(release),"release_self_digest_excluded");
   SWV5_TestRecordCondition(collector,"S48-CAN-SELF-05","SPRINT4_8_CANONICAL_INTEGRITY",authority_digest==SWV5_TestHardKillAuthorityRecordDigest(authority),"authority_self_digest_excluded");
   SWV5_TestRecordCondition(collector,"S48-CAN-SELF-06","SPRINT4_8_CANONICAL_INTEGRITY",checkpoint_digest==SWV5_TestCheckpointPayloadDigest(checkpoint),"checkpoint_integrity_envelope_excluded");

   const string a=SWV5_TestCanonicalField("a","s","1"),b=SWV5_TestCanonicalField("b","i","1");
   SWV5_TestRecordCondition(collector,"S48-CAN-FMT-01","SPRINT4_8_CANONICAL_INTEGRITY",a+b!=b+a,"adjacent_field_order_distinct");
   SWV5_TestRecordCondition(collector,"S48-CAN-FMT-02","SPRINT4_8_CANONICAL_INTEGRITY",SWV5_TestCanonicalField("v","s","1")!=SWV5_TestCanonicalIntegerField("v",1),"string_integer_type_distinct");
   SWV5_TestRecordCondition(collector,"S48-CAN-FMT-03","SPRINT4_8_CANONICAL_INTEGRITY",SWV5_TestCanonicalField("v","s","")!="","empty_field_not_missing");
   SWV5_TestRecordCondition(collector,"S48-CAN-FMT-04","SPRINT4_8_CANONICAL_INTEGRITY",StringSubstr(a,0,StringLen(a)-1)!=a,"truncation_changes_representation");
   const string split1=SWV5_TestCanonicalField("a","s","1")+SWV5_TestCanonicalField("b","s","23");
   const string split2=SWV5_TestCanonicalField("a","s","12")+SWV5_TestCanonicalField("b","s","3");
   SWV5_TestRecordCondition(collector,"S48-CAN-FMT-05","SPRINT4_8_CANONICAL_INTEGRITY",split1!=split2,"length_prefix_prevents_concatenation_ambiguity");
   SWV5_TestRecordCondition(collector,"S48-CAN-DRIFT-01","SPRINT4_8_CANONICAL_INTEGRITY",SWV5_TestCanonicalNestedSerializerReuse(),"parent_reuses_nested_canonical_serializers");
   SWV5_TestRecordCondition(collector,"S48-CAN-AUTH-01","SPRINT4_8_CANONICAL_INTEGRITY",SWV5_TestMarginAuthorityAllFieldsDigestBound(),"all_margin_authority_fields_digest_bound");
   SWV5_TestRecordCondition(collector,"S48-CAN-AUTH-02","SPRINT4_8_CANONICAL_INTEGRITY",SWV5_TestBasketAuthorityAllFieldsDigestBound(),"all_basket_authority_fields_digest_bound");
}

void SWV5_RunContractSuite(SWV5_TestCollector &collector)
{
   SWV5_RunCommonTests(collector);
   SWV5_RunBasketStateTests(collector);
   SWV5_RunBasketAggregateTests(collector);
   SWV5_RunUnitTests(collector);
   SWV5_RunOwnershipTests(collector);
   SWV5_RunExecutionTests(collector);
   SWV5_RunSprint45ExecutionAuthorityTests(collector);
   SWV5_RunSprint45FingerprintTests(collector);
   SWV5_RunSprint46ExecutionEnvelopeTests(collector);
   SWV5_RunSprint46RiskSafetyTests(collector);
   SWV5_RunSprint46HardKillReleaseTests(collector);
   SWV5_RunSprint46CheckpointIntegrityTests(collector);
   SWV5_RunSprint46DurableIdentityTests(collector);
   SWV5_RunSprint46FingerprintUniquenessTests(collector);
   SWV5_RunSprint46RetryFreshnessTests(collector);
   SWV5_RunSprint47RiskProjectionTests(collector);
   SWV5_RunSprint47NonFiniteTests(collector);
   SWV5_RunSprint47HardKillExpiryTests(collector);
   SWV5_RunSprint47CheckpointSemanticTests(collector);
   SWV5_RunSprint47RetryEnumTests(collector);
   SWV5_RunSprint48MarginTests(collector);
   SWV5_RunSprint48LossTests(collector);
   SWV5_RunSprint48NotionalTests(collector);
   SWV5_RunSprint48RestartTests(collector);
   SWV5_RunSprint48HardKillTests(collector);
   SWV5_RunSprint48HardKillAuthorityTests(collector);
   SWV5_RunSprint48CanonicalIntegrityTests(collector);
   SWV5_RunSprint48RoundTripTests(collector);
   SWV5_RunSprint48MetadataConformanceTests(collector);
   SWV5_RunSprint48B6MarginAuthorityTests(collector);
   SWV5_RunSprint48B6BasketAuthorityTests(collector);
   SWV5_RunSprint48B6PersistenceAtomicityTests(collector);
   SWV5_RunSprint48B6IdentityTests(collector);
   SWV5_RunSprint45RecoveryValidationTests(collector);
   SWV5_RunSprint45UnclaimedAcquireTests(collector);
   SWV5_RunSprint45RiskBindingTests(collector);
   SWV5_RunSprint45UnitSafetyTests(collector);
   SWV5_RunSprint45OwnershipLifecycleTests(collector);
   SWV5_RunSprint45PersistenceCanonicalTests(collector);
   SWV5_RunPersistenceTests(collector);
   SWV5_RunRiskTests(collector);
   SWV5_RunStatisticsTests(collector);
   SWV5_RunCrossDomainTests(collector);
   SWV5_RunInterfaceCorrectionTests(collector);
   SWV5_RunPersistenceRoundTripTests(collector);
   SWV5_RunSprint44SemanticTests(collector);
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
   const bool complete=first.Total()==846 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunPhaseATargetedVerification()
{
   SWV5_TestCollector first;
   SWV5_TestCollector replay;
   SWV5_RunSprint45ExecutionAuthorityTests(first);
   SWV5_RunSprint45FingerprintTests(first);
   SWV5_RunSprint45ExecutionAuthorityTests(replay);
   SWV5_RunSprint45FingerprintTests(replay);
   const bool deterministic=first.Total()==replay.Total() &&
                            first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==12 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint46PhaseATargetedVerification()
{
   SWV5_TestCollector first;
   SWV5_TestCollector replay;
   SWV5_RunSprint46ExecutionEnvelopeTests(first);
   SWV5_RunSprint46ExecutionEnvelopeTests(replay);
   const bool deterministic=first.Total()==replay.Total() &&
                            first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==42 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint46OwnershipRegressionVerification()
{
   SWV5_TestCollector first;
   SWV5_TestCollector replay;
   SWV5_RunSprint45OwnershipLifecycleTests(first);
   SWV5_TestRecordCondition(first,"S44-21","SPRINT4_4_SEMANTIC",SWV5_TestS4421HeartbeatSemantic(),"heartbeat_authority_stable_liveness_monotonic");
   SWV5_RunSprint45OwnershipLifecycleTests(replay);
   SWV5_TestRecordCondition(replay,"S44-21","SPRINT4_4_SEMANTIC",SWV5_TestS4421HeartbeatSemantic(),"heartbeat_authority_stable_liveness_monotonic");
   const bool deterministic=first.Total()==replay.Total() &&
                            first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==36 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint46PhaseBTargetedVerification()
{
   SWV5_TestCollector first;
   SWV5_TestCollector replay;
   SWV5_RunSprint46RiskSafetyTests(first);
   SWV5_RunSprint46HardKillReleaseTests(first);
   SWV5_RunSprint46RiskSafetyTests(replay);
   SWV5_RunSprint46HardKillReleaseTests(replay);
   const bool deterministic=first.Total()==replay.Total() &&
                            first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==71 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint46RiskRegressionVerification()
{
   SWV5_TestCollector first;
   SWV5_TestCollector replay;
   SWV5_RunRiskTests(first);
   SWV5_RunSprint45RiskBindingTests(first);
   SWV5_RunRiskTests(replay);
   SWV5_RunSprint45RiskBindingTests(replay);
   const bool deterministic=first.Total()==replay.Total() &&
                            first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==45 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint46CheckpointTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint46CheckpointIntegrityTests(first);
   SWV5_RunSprint46CheckpointIntegrityTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==20 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint46RetryTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint46RetryFreshnessTests(first);
   SWV5_RunSprint46RetryFreshnessTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==20 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunPER02TargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_TestRecordCondition(first,"PER-02","PERSISTENCE",SWV5_TestPER02Behavior(),"stale_digest_after_payload_corruption");
   SWV5_TestRecordCondition(replay,"PER-02","PERSISTENCE",SWV5_TestPER02Behavior(),"stale_digest_after_payload_corruption");
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==1 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint46EventIdentityTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint46DurableIdentityTests(first);
   SWV5_RunSprint46DurableIdentityTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==20 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint46E1FingerprintTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint46FingerprintUniquenessTests(first);
   SWV5_RunSprint46FingerprintUniquenessTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==20 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint46PersistenceRegressionVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunPersistenceTests(first); SWV5_RunPersistenceRoundTripTests(first); SWV5_RunSprint45PersistenceCanonicalTests(first);
   SWV5_RunPersistenceTests(replay); SWV5_RunPersistenceRoundTripTests(replay); SWV5_RunSprint45PersistenceCanonicalTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==42 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint46StatisticsRegressionVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunStatisticsTests(first); SWV5_RunStatisticsTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==13 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint46ExecutionFingerprintRegressionVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint45ExecutionAuthorityTests(first); SWV5_RunSprint45FingerprintTests(first);
   SWV5_RunSprint45ExecutionAuthorityTests(replay); SWV5_RunSprint45FingerprintTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==12 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunPhaseBTargetedVerification()
{
   SWV5_TestCollector first;
   SWV5_TestCollector replay;
   SWV5_RunSprint45RecoveryValidationTests(first);
   SWV5_RunSprint45UnclaimedAcquireTests(first);
   SWV5_RunSprint45RecoveryValidationTests(replay);
   SWV5_RunSprint45UnclaimedAcquireTests(replay);
   const bool deterministic=first.Total()==replay.Total() &&
                            first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==20 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunPhaseCTargetedVerification()
{
   SWV5_TestCollector first;
   SWV5_TestCollector replay;
   SWV5_RunSprint45RiskBindingTests(first);
   SWV5_RunSprint45UnitSafetyTests(first);
   SWV5_RunSprint45RiskBindingTests(replay);
   SWV5_RunSprint45UnitSafetyTests(replay);
   const bool deterministic=first.Total()==replay.Total() &&
                            first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==49 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunPhaseDTargetedVerification()
{
   SWV5_TestCollector first;
   SWV5_TestCollector replay;
   SWV5_RunSprint45OwnershipLifecycleTests(first);
   SWV5_RunSprint45PersistenceCanonicalTests(first);
   SWV5_RunSprint45OwnershipLifecycleTests(replay);
   SWV5_RunSprint45PersistenceCanonicalTests(replay);
   const bool deterministic=first.Total()==replay.Total() &&
                            first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==49 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunPhaseETargetedVerification()
{
   SWV5_TestCollector first;
   SWV5_TestCollector replay;
   SWV5_RunCommonTests(first);
   SWV5_RunBasketAggregateTests(first);
   SWV5_RunExecutionTests(first);
   SWV5_RunStatisticsTests(first);
   SWV5_RunCrossDomainTests(first);
   SWV5_RunInterfaceCorrectionTests(first);
   SWV5_RunSprint45PersistenceCanonicalTests(first);
   SWV5_TestRecordCondition(first,"S44-21","SPRINT4_4_SEMANTIC",SWV5_TestS4421HeartbeatSemantic(),"returned_heartbeat_chain_authority_stable_liveness_monotonic");
   SWV5_RunCommonTests(replay);
   SWV5_RunBasketAggregateTests(replay);
   SWV5_RunExecutionTests(replay);
   SWV5_RunStatisticsTests(replay);
   SWV5_RunCrossDomainTests(replay);
   SWV5_RunInterfaceCorrectionTests(replay);
   SWV5_RunSprint45PersistenceCanonicalTests(replay);
   SWV5_TestRecordCondition(replay,"S44-21","SPRINT4_4_SEMANTIC",SWV5_TestS4421HeartbeatSemantic(),"returned_heartbeat_chain_authority_stable_liveness_monotonic");
   const bool deterministic=first.Total()==replay.Total() &&
                            first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==118 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunS4421TargetedVerification()
{
   SWV5_TestCollector first;
   SWV5_TestCollector replay;
   SWV5_TestRecordCondition(first,"S44-21","SPRINT4_4_SEMANTIC",SWV5_TestS4421HeartbeatSemantic(),"heartbeat_authority_stable_liveness_monotonic");
   SWV5_TestRecordCondition(replay,"S44-21","SPRINT4_4_SEMANTIC",SWV5_TestS4421HeartbeatSemantic(),"heartbeat_authority_stable_liveness_monotonic");
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==1 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint47RiskProjectionTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint47RiskProjectionTests(first); SWV5_RunSprint47RiskProjectionTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() && first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==18 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint47NonFiniteTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint47NonFiniteTests(first); SWV5_RunSprint47NonFiniteTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() && first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==18 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint47HardKillTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint47HardKillExpiryTests(first); SWV5_RunSprint47HardKillExpiryTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() && first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==7 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint47CheckpointTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint47CheckpointSemanticTests(first); SWV5_RunSprint47CheckpointSemanticTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() && first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==18 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint47RetryEnumTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint47RetryEnumTests(first); SWV5_RunSprint47RetryEnumTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() && first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==12 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint48HardKillAuthorityTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint48HardKillTests(first);
   SWV5_RunSprint48HardKillAuthorityTests(first);
   SWV5_RunSprint48HardKillTests(replay);
   SWV5_RunSprint48HardKillAuthorityTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==43 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint48CanonicalIntegrityTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint48CanonicalIntegrityTests(first);
   SWV5_RunSprint48CanonicalIntegrityTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==36 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint48CanonicalAffectedTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint48LossTests(first); SWV5_RunSprint48MarginTests(first); SWV5_RunSprint48NotionalTests(first);
   SWV5_RunSprint48RestartTests(first); SWV5_RunSprint48HardKillTests(first); SWV5_RunSprint48HardKillAuthorityTests(first);
   SWV5_RunSprint48LossTests(replay); SWV5_RunSprint48MarginTests(replay); SWV5_RunSprint48NotionalTests(replay);
   SWV5_RunSprint48RestartTests(replay); SWV5_RunSprint48HardKillTests(replay); SWV5_RunSprint48HardKillAuthorityTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==103 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

void SWV5_RunSprint48HistoricalRegressionSet(SWV5_TestCollector &collector)
{
   g_swv5_test_id_filter="S45BR-10,S45DO-32,S45DP-16,PER-06,PER-07,PER-08,PER-09,PER-13,XDM-03,XDM-11,PRT-01,S44-02,S44-03,S44-10,S44-11";
   SWV5_RunSprint45RecoveryValidationTests(collector);
   SWV5_RunSprint45OwnershipLifecycleTests(collector);
   SWV5_RunSprint45PersistenceCanonicalTests(collector);
   SWV5_RunPersistenceTests(collector);
   SWV5_RunCrossDomainTests(collector);
   SWV5_RunPersistenceRoundTripTests(collector);
   SWV5_RunSprint44SemanticTests(collector);
   g_swv5_test_id_filter="";
}

bool SWV5_RunSprint48HistoricalRegressionTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint48HistoricalRegressionSet(first);
   SWV5_RunSprint48HistoricalRegressionSet(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() &&
                            first.Failed()==replay.Failed() && first.Skipped()==replay.Skipped() &&
                            first.Signature()==replay.Signature();
   const bool complete=first.Total()==15 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint48RoundTripTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint48RoundTripTests(first); SWV5_RunSprint48RoundTripTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() && first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==18 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint48MetadataTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint48MetadataConformanceTests(first); SWV5_RunSprint48MetadataConformanceTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() && first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==1 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

void SWV5_RunSprint48PreviousSafetySet(SWV5_TestCollector &collector)
{
   SWV5_RunSprint45ExecutionAuthorityTests(collector);
   SWV5_RunSprint45FingerprintTests(collector);
   SWV5_RunSprint46ExecutionEnvelopeTests(collector);
   SWV5_RunSprint47NonFiniteTests(collector);
   SWV5_RunSprint47HardKillExpiryTests(collector);
   SWV5_RunSprint47CheckpointSemanticTests(collector);
   SWV5_RunSprint46DurableIdentityTests(collector);
   SWV5_RunSprint46FingerprintUniquenessTests(collector);
   SWV5_RunSprint47RetryEnumTests(collector);
   SWV5_RunOwnershipTests(collector);
   SWV5_RunSprint45OwnershipLifecycleTests(collector);
   SWV5_RunPersistenceTests(collector);
   SWV5_RunPersistenceRoundTripTests(collector);
   SWV5_RunSprint45PersistenceCanonicalTests(collector);
}

bool SWV5_RunSprint48PreviousSafetyTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint48PreviousSafetySet(first); SWV5_RunSprint48PreviousSafetySet(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() && first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==235 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint48B6MarginAuthorityTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint48B6MarginAuthorityTests(first); SWV5_RunSprint48B6MarginAuthorityTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() && first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==15 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint48B6BasketAuthorityTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint48B6BasketAuthorityTests(first); SWV5_RunSprint48B6BasketAuthorityTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() && first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==15 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint48B6PersistenceAtomicityTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint48B6PersistenceAtomicityTests(first); SWV5_RunSprint48B6PersistenceAtomicityTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() && first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==12 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

bool SWV5_RunSprint48B6IdentityTargetedVerification()
{
   SWV5_TestCollector first,replay;
   SWV5_RunSprint48B6IdentityTests(first); SWV5_RunSprint48B6IdentityTests(replay);
   const bool deterministic=first.Total()==replay.Total() && first.Passed()==replay.Passed() && first.Failed()==replay.Failed() &&
                            first.Skipped()==replay.Skipped() && first.Signature()==replay.Signature();
   const bool complete=first.Total()==12 && first.Skipped()==0;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",first.Total(),first.Passed(),first.Failed(),first.Skipped(),deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

#endif
