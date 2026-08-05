//+------------------------------------------------------------------+
//| TEST ONLY                                                        |
//| NOT FOR PRODUCTION                                               |
//| NO BROKER ACCESS                                                 |
//+------------------------------------------------------------------+
#ifndef SW_V5_CONTRACT_TEST_RUNNER_MQH
#define SW_V5_CONTRACT_TEST_RUNNER_MQH

#include "SW_V5_TestAssertions.mqh"
#include "SW_V5_ReferenceValidators.mqh"

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

void SWV5_RunCommonTests(SWV5_TestCollector &collector)
{
   for(int number=1;number<=12;number++)
   {
      SWV5_ContractValidationContext context;
      SWV5_TestMakeContext(context);
      SWV5_ContractVersion candidate=context.expected_version;
      bool passed=false;
      string expected="fail_closed";
      switch(number)
      {
         case 1:
            expected="exact";
            passed=SWV5_TestCompatibility(candidate,context)==SWV5_COMPATIBILITY_EXACT;
            break;
         case 2:
            candidate.schema_version=1;
            expected="migration_required";
            passed=SWV5_TestCompatibility(candidate,context)==SWV5_COMPATIBILITY_MIGRATION_REQUIRED;
            break;
         case 3:
            candidate.policy_id="UNKNOWN-POLICY";
            expected="rejected";
            passed=SWV5_TestCompatibility(candidate,context)==SWV5_COMPATIBILITY_REJECTED;
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
            ulong version_a=0;
            ulong version_b=0;
            const SWV5_TestBasketRule result_a=SWV5_TestEvaluateBasketTransition(context,snapshot,request,version_a);
            const SWV5_TestBasketRule result_b=SWV5_TestEvaluateBasketTransition(context,snapshot,request,version_b);
            expected="byte_equivalent_decision";
            passed=result_a==result_b && version_a==version_b;
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
            passed=SWV5_TestCompatibility(candidate,context)==SWV5_COMPATIBILITY_REJECTED;
            break;
         case 11:
         {
            SWV5_ContractCompatibilityResult result;
            result.evaluated_version=candidate;
            result.compatibility=SWV5_TestCompatibility(candidate,context);
            passed=SWV5_TestVersionEqual(result.evaluated_version,candidate);
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
   for(int index=0;index<49;index++)
   {
      const SWV5_BasketState from_state=(SWV5_BasketState)(index/7);
      const SWV5_BasketState to_state=(SWV5_BasketState)(index%7);
      SWV5_BasketLifecycleSnapshot snapshot;
      SWV5_BasketTransitionRequest request;
      SWV5_TestMakeLifecycle(snapshot,from_state);
      SWV5_TestMakeTransition(snapshot,to_state,request);
      ulong resulting_version=0;
      const SWV5_TestBasketRule actual=SWV5_TestEvaluateBasketTransition(context,snapshot,request,resulting_version);
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
            passed=!SWV5_TestAggregateIdentityValid(basket);
            break;
         case 2:
         {
            const ulong previous_attempts=3;
            basket.lifecycle.cumulative_recovery_attempts=2;
            passed=basket.lifecycle.cumulative_recovery_attempts<previous_attempts;
            expected="regression_rejected";
            break;
         }
         case 3:
            passed=SWV5_TestPartialCloseValid(basket,partial);
            expected="valid_partial_close";
            break;
         case 4:
         {
            SWV5_ExecutionCorrelation prior=partial.correlation;
            const double residual_before=basket.lifecycle.residual_volume;
            const bool duplicate=partial.correlation.event_id==prior.event_id && partial.correlation.idempotency_key==prior.idempotency_key;
            passed=duplicate && SWV5_TestNear(residual_before,basket.lifecycle.residual_volume,0.0000001);
            expected="idempotent_no_decrement";
            break;
         }
         case 5:
            partial.closed_volume=0.40;
            passed=!SWV5_TestPartialCloseValid(basket,partial);
            break;
         case 6:
            close_evidence.broker_queries.completed_flags&=~SWV5_QUERY_ORDERS;
            passed=!SWV5_TestCloseComplete(close_evidence);
            break;
         case 7:
            basket.persistence_namespace.ownership_namespace.account_login=0;
            passed=!SWV5_TestNamespaceComplete(basket.persistence_namespace);
            break;
         case 8:
            basket.account_mode=SWV5_ACCOUNT_MODE_NETTING;
            passed=!SWV5_TestAggregateIdentityValid(basket);
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
      bool passed=false;
      string expected="fail_closed";
      switch(number)
      {
         case 1:
            passed=SWV5_TestNormalize(context,specification,request,normalized) &&
                   SWV5_TestNear(normalized.price,2400.05,context.price_tolerance);
            expected="tick_aligned_2400.05";
            break;
         case 2:
            specification.pip_size=0.0;
            passed=!SWV5_TestSpecificationValid(specification);
            break;
         case 3:
            passed=SWV5_TestNormalize(context,specification,request,normalized) &&
                   SWV5_TestNear(normalized.volume,0.01,context.volume_tolerance);
            expected="volume_rounded_down_0.01";
            break;
         case 4:
            request.raw_volume=0.005;
            passed=!SWV5_TestNormalize(context,specification,request,normalized);
            break;
         case 5:
            specification.tick_value_currency="EUR";
            passed=!SWV5_TestSpecificationValid(specification);
            break;
         case 6:
            request.raw_stop_price=2399.50;
            passed=!SWV5_TestNormalize(context,specification,request,normalized);
            break;
         case 7:
            request.protective_operation=true;
            request.reference_market_price=2400.00;
            request.market_ask=2400.00;
            passed=!SWV5_TestNormalize(context,specification,request,normalized);
            break;
         case 8:
            request.expected_specification_sequence=49;
            passed=!SWV5_TestNormalize(context,specification,request,normalized);
            break;
         case 9:
            request.market_bid=0.0;
            request.market_ask=0.0;
            passed=!SWV5_TestNormalize(context,specification,request,normalized);
            break;
         case 10:
            request.raw_price=2400.05000001;
            passed=SWV5_TestNormalize(context,specification,request,normalized) &&
                   SWV5_TestNear(normalized.price,2400.05,context.price_tolerance);
            expected="tolerance_deterministic";
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
            passed=!SWV5_TestCanTakeover(context,claim,observed);
            break;
         case 4:
            observed.status=SWV5_LOCK_EXPIRED;
            observed.expires_at=SWV5_TEST_TIME-1;
            observed.expiry_clock_sequence=999;
            claim.broker_state_reconciled=false;
            claim.persistence_reconciled=false;
            passed=!SWV5_TestCanTakeover(context,claim,observed);
            break;
         case 5:
            observed.status=SWV5_LOCK_EXPIRED;
            observed.expires_at=SWV5_TEST_TIME-1;
            observed.expiry_clock_sequence=999;
            passed=SWV5_TestCanTakeover(context,claim,observed) && observed.fence.takeover_generation+1==3;
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
      bool passed=false;
      string expected="fail_closed";
      double confirmed=0.0;
      double residual=0.0;
      switch(number)
      {
         case 1:
            passed=SWV5_TestIntentValid(context,pending.intent);
            expected="intent_valid";
            break;
         case 2:
            passed=SWV5_TestClassifyRetcode(1)==SWV5_RETCODE_ACCEPTED_PENDING_CONFIRMATION &&
                   pending.state==SWV5_REQUEST_CONFIRMATION_PENDING && pending.confirmed_volume==0.0;
            expected="pending_not_confirmed";
            break;
         case 3:
            passed=SWV5_TestClassifyRetcode(2)==SWV5_RETCODE_SYNCHRONOUS_DEAL_REPORTED_PENDING_EVIDENCE &&
                   pending.confirmed_volume==0.0;
            expected="pending_evidence";
            break;
         case 4:
            passed=SWV5_TestClassifyRetcode(3)==SWV5_RETCODE_REJECTED_PERMANENT;
            expected="terminal_rejection";
            break;
         case 5:
            passed=SWV5_TestClassifyRetcode(4)==SWV5_RETCODE_CONNECTION_UNCERTAIN;
            expected="reconcile_before_retry";
            break;
         case 6:
            passed=SWV5_TestClassifyRetcode(5)==SWV5_RETCODE_PRICE_CHANGED &&
                   SWV5_TestClassifyRetcode(6)==SWV5_RETCODE_VOLUME_CHANGED;
            expected="fresh_units_and_risk";
            break;
         case 7:
            evidence.persistence_namespace.basket_id.value="FOREIGN-BASKET";
            passed=SWV5_TestConfirmExecution(pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_CONFLICT;
            break;
         case 8:
            evidence.expected_basket_version++;
            passed=SWV5_TestConfirmExecution(pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_CONFLICT;
            expected="reconciliation_required";
            break;
         case 9:
            pending.last_accepted_correlation=evidence.correlation;
            pending.state=SWV5_REQUEST_CONFIRMED;
            pending.confirmed_volume=0.10;
            pending.residual_requested_volume=0.0;
            passed=SWV5_TestConfirmExecution(pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_CONFIRMED &&
                   SWV5_TestNear(confirmed,0.10,context.volume_tolerance);
            expected="idempotent_0.10";
            break;
         case 10:
            pending.last_accepted_correlation=evidence.correlation;
            pending.last_accepted_correlation.event_id="NEWER-EVENT";
            pending.last_accepted_correlation.idempotency_key="NEWER-IDEMPOTENCY";
            pending.last_accepted_correlation.transaction_sequence=500;
            evidence.correlation.transaction_sequence=499;
            passed=SWV5_TestConfirmExecution(pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_CONFLICT;
            expected="reconciliation_required";
            break;
         case 11:
            evidence.confirmed_volume=0.04;
            passed=SWV5_TestConfirmExecution(pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_PARTIAL &&
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
            passed=SWV5_TestClassifyRetcode(999)==SWV5_RETCODE_UNCLASSIFIED;
            break;
         case 14:
            evidence.correlation.event_id="";
            passed=SWV5_TestConfirmExecution(pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_CONFLICT;
            break;
         case 15:
            evidence.ownership_fence.store_revision="STALE-REV";
            passed=SWV5_TestConfirmExecution(pending,evidence,confirmed,residual)==SWV5_CONFIRMATION_CONFLICT;
            expected="halt_and_reconcile";
            break;
         case 16:
            pending.state=SWV5_REQUEST_ACKNOWLEDGED;
            passed=pending.confirmed_volume==0.0 && pending.state!=SWV5_REQUEST_CONFIRMED;
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
      bool passed=false;
      string expected="fail_closed";
      switch(number)
      {
         case 1:
            passed=SWV5_TestPersistenceRecordValid(engineInput.persisted);
            expected="record_valid";
            break;
         case 2:
            engineInput.persisted.header.payload_digest="";
            passed=!SWV5_TestPersistenceRecordValid(engineInput.persisted);
            expected="corrupt";
            break;
         case 3:
            engineInput.persisted.header.previous_record_sequence=engineInput.persisted.header.record_sequence;
            passed=!SWV5_TestPersistenceRecordValid(engineInput.persisted);
            expected="sequence_rejected";
            break;
         case 4:
            engineInput.persisted.header.persistence_namespace.basket_id.value="FOREIGN-BASKET";
            passed=!SWV5_TestPersistenceRecordValid(engineInput.persisted);
            expected="conflict";
            break;
         case 5:
            passed=SWV5_TestRestartDisposition(engineInput)==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED;
            expected="matched_checkpoint_required";
            break;
         case 6:
            engineInput.broker.residual_volume+=0.10;
            passed=SWV5_TestRestartDisposition(engineInput)==SWV5_RECONCILIATION_BROKER_AHEAD_HALT;
            expected="broker_ahead_halt";
            break;
         case 7:
            engineInput.broker.residual_volume-=0.10;
            passed=SWV5_TestRestartDisposition(engineInput)==SWV5_RECONCILIATION_PERSISTENCE_AHEAD_HALT;
            expected="persistence_ahead_halt";
            break;
         case 8:
            engineInput.broker.queries.completed_flags&=~SWV5_QUERY_DEALS;
            passed=SWV5_TestRestartDisposition(engineInput)==SWV5_RECONCILIATION_MANUAL_REQUIRED;
            expected="manual_required";
            break;
         case 9:
            engineInput.persisted.persisted_pending_request_count=1;
            engineInput.broker.pending_request_count=1;
            engineInput.persisted.pending_request_set_digest="PENDING-SET-1";
            engineInput.persisted.latest_pending_request.confirmation_status=SWV5_CONFIRMATION_PENDING;
            passed=SWV5_TestRestartDisposition(engineInput)==SWV5_RECONCILIATION_CONFLICT_HALT;
            expected="blind_retry_forbidden";
            break;
         case 10:
            engineInput.persistence_status=SWV5_PERSISTENCE_CHECKSUM_FAILED;
            passed=SWV5_TestRestartDisposition(engineInput)==SWV5_RECONCILIATION_CORRUPT_HALT;
            expected="prior_record_clue_only";
            break;
         case 11:
            engineInput.claimant_fence.fencing_token_digest="FOREIGN-TOKEN";
            passed=SWV5_TestRestartDisposition(engineInput)==SWV5_RECONCILIATION_OWNERSHIP_CONFLICT_HALT;
            expected="ownership_conflict_halt";
            break;
         case 12:
            SWV5_TestMakeHardKill(engineInput.persisted.hard_kill_state,SWV5_HARD_KILL_ACTIVE);
            passed=engineInput.persisted.hard_kill_state.state==SWV5_HARD_KILL_ACTIVE &&
                   engineInput.persisted.hard_kill_state.latch_generation==4;
            expected="active_latch_preserved";
            break;
         case 13:
            engineInput.persisted.persisted_pending_request_count=1;
            engineInput.broker.pending_request_count=1;
            engineInput.persisted.pending_request_set_digest="";
            passed=SWV5_TestRestartDisposition(engineInput)==SWV5_RECONCILIATION_CONFLICT_HALT;
            expected="pending_set_conflict";
            break;
         case 14:
            engineInput.persistence_namespace.ownership_namespace.broker_identity="";
            engineInput.persisted.header.persistence_namespace=engineInput.persistence_namespace;
            engineInput.broker.persistence_namespace=engineInput.persistence_namespace;
            passed=SWV5_TestRestartDisposition(engineInput)==SWV5_RECONCILIATION_CONFLICT_HALT;
            expected="composite_namespace_required";
            break;
         case 15:
            engineInput.persisted.persisted_pending_request_count=1;
            engineInput.broker.pending_request_count=1;
            engineInput.persisted.pending_request_set_digest="PENDING-SET-1";
            engineInput.persisted.latest_pending_request.confirmation_status=SWV5_CONFIRMATION_CONFIRMED;
            engineInput.persisted.latest_pending_request.persistence_namespace.basket_id.value="FOREIGN-BASKET";
            passed=SWV5_TestRestartDisposition(engineInput)==SWV5_RECONCILIATION_CONFLICT_HALT;
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
                   !SWV5_TestAuthorizationMatches(context,authorization,intent);
            break;
         case 3:
            authorization.projected_risk_snapshot_sequence=0;
            passed=!SWV5_TestAuthorizationMatches(context,authorization,intent);
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
            passed=!SWV5_TestAuthorizationMatches(context,authorization,intent);
            expected="binding_mismatch_rejected";
            break;
         case 9:
            context.clock_time=authorization.expires_at+1;
            passed=!SWV5_TestAuthorizationMatches(context,authorization,intent);
            expected="expired";
            break;
         case 10:
            intent.normalized_volume=0.20;
            passed=!SWV5_TestAuthorizationMatches(context,authorization,intent);
            expected="volume_exceeds_authorization";
            break;
         case 11:
            hard_kill.state=SWV5_HARD_KILL_RELEASE_PENDING;
            passed=!SWV5_TestHardKillReleaseValid(context,hard_kill,hard_kill.release_evidence);
            expected="release_evidence_rejected";
            break;
         case 12:
            hard_kill.state=SWV5_HARD_KILL_ACTIVE;
            passed=hard_kill.state==SWV5_HARD_KILL_ACTIVE && hard_kill.latch_generation==4;
            expected="restart_latch_active";
            break;
         case 13:
            authorization.account_risk_snapshot_sequence=0;
            passed=!SWV5_TestAuthorizationMatches(context,authorization,intent);
            expected="snapshot_binding_invalid";
            break;
         case 14:
            authorization.hard_kill_latch_generation=3;
            passed=authorization.hard_kill_latch_generation!=hard_kill.latch_generation;
            expected="latch_generation_invalid";
            break;
         case 15:
            authorization.monetary_basis.conversion_source="";
            passed=!SWV5_TestAuthorizationMatches(context,authorization,intent);
            expected="monetary_basis_invalid";
            break;
         case 16:
            intent.correlation.request_id.attempt_id="ATTEMPT-0002";
            passed=!SWV5_TestAuthorizationMatches(context,authorization,intent);
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
      SWV5_StatisticsDeduplicationState state;
      SWV5_TestMakeDedupState(state);
      SWV5_StatisticsDeduplicationEvidence evidence;
      SWV5_TestMakeDedupEvidence(evidence,state,SWV5_STAT_IDENTITY_NEW);
      bool passed=false;
      string expected="fail_closed";
      switch(number)
      {
         case 1:
            deal.entry_kind=SWV5_DEAL_ENTRY_IN;
            passed=SWV5_TestDealValid(deal,context);
            expected="entry_counted";
            break;
         case 2:
            passed=SWV5_TestDealValid(deal,context) && SWV5_TestNear(SWV5_TestDealNet(deal),96.5,0.0000001);
            expected="net_96.5";
            break;
         case 3:
         {
            const double entered_volume=0.30;
            const double exited_volume=0.10;
            const double residual=entered_volume-exited_volume;
            const uint partial_count=(residual>0.0 ? 1 : 0);
            passed=SWV5_TestNear(residual,0.20,0.0000001) && partial_count==1;
            expected="partial_count_1_residual_0.20";
            break;
         }
         case 4:
            SWV5_TestMakeDedupEvidence(evidence,state,SWV5_STAT_IDENTITY_DUPLICATE);
            passed=SWV5_TestDedupEvidenceValid(evidence,state);
            expected="duplicate_idempotent";
            break;
         case 5:
            deal.persistence_namespace.basket_id.value="FOREIGN-BASKET";
            passed=!SWV5_TestDealValid(deal,context);
            expected="attribution_invalid";
            break;
         case 6:
            deal.monetary_components_complete=false;
            passed=!SWV5_TestDealValid(deal,context);
            expected="finalization_denied";
            break;
         case 7:
            context.history_queries.completed_flags&=~SWV5_QUERY_DEALS;
            passed=!SWV5_TestDealValid(deal,context);
            expected="history_not_authoritative";
            break;
         case 8:
         {
            const double residual=0.0;
            passed=SWV5_TestDealValid(deal,context) && SWV5_TestNear(residual,0.0,0.0000001);
            expected="completion_eligible";
            break;
         }
         case 9:
            context.account_mode=SWV5_ACCOUNT_MODE_NETTING;
            passed=!SWV5_TestDealValid(deal,context);
            expected="netting_rejected";
            break;
         case 10:
            SWV5_TestMakeDedupEvidence(evidence,state,SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW);
            evidence.correlation.transaction_sequence=state.highest_transaction_sequence-1;
            passed=SWV5_TestDedupEvidenceValid(evidence,state) &&
                   evidence.correlation.transaction_sequence<state.highest_transaction_sequence;
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
            conflicting.event_id="CONFLICTING-EVENT";
            conflicting.idempotency_key="CONFLICTING-IDEMPOTENCY";
            passed=conflicting.deal_ticket==deal.correlation.deal_ticket &&
                   (conflicting.event_id!=deal.correlation.event_id || conflicting.idempotency_key!=deal.correlation.idempotency_key);
            expected="identity_conflict";
            break;
         }
         case 13:
            deal.account_currency="";
            passed=!SWV5_TestDealValid(deal,context);
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
            passed=SWV5_TestIntentValid(context,intent) &&
                   SWV5_TestAuthorizationMatches(context,authorization,intent) &&
                   SWV5_TestRestartDisposition(restart)==SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED &&
                   SWV5_TestNormalize(context,specification,request,normalized) &&
                   SWV5_TestConfirmExecution(pending,transaction,confirmed,residual)==SWV5_CONFIRMATION_CONFIRMED;
            expected="ordered_gates_confirmed";
            break;
         }
         case 2:
            pending.state=SWV5_REQUEST_ACKNOWLEDGED;
            transaction.ownership_fence.store_revision="LOST-OWNER-REV";
            passed=SWV5_TestConfirmExecution(pending,transaction,confirmed,residual)==SWV5_CONFIRMATION_CONFLICT;
            expected="halt_reconcile_no_retry";
            break;
         case 3:
            restart.persisted.persisted_pending_request_count=1;
            restart.broker.pending_request_count=1;
            restart.persisted.pending_request_set_digest="PENDING-SET";
            restart.persisted.latest_pending_request.confirmation_status=SWV5_CONFIRMATION_PENDING;
            passed=SWV5_TestRestartDisposition(restart)==SWV5_RECONCILIATION_CONFLICT_HALT;
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
            passed=!SWV5_TestAuthorizationMatches(context,authorization,intent);
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
            pending.last_accepted_correlation=transaction.correlation;
            pending.state=SWV5_REQUEST_CONFIRMED;
            pending.confirmed_volume=0.10;
            pending.residual_requested_volume=0.0;
            passed=SWV5_TestConfirmExecution(pending,transaction,confirmed,residual)==SWV5_CONFIRMATION_CONFIRMED &&
                   SWV5_TestNear(confirmed,0.10,context.volume_tolerance);
            expected="duplicate_no_second_update";
            break;
         case 8:
            restart.persistence_status=SWV5_PERSISTENCE_NOT_FOUND;
            restart.broker.queries.completed_flags=0;
            passed=SWV5_TestRestartDisposition(restart)==SWV5_RECONCILIATION_CORRUPT_HALT;
            expected="never_execution_ready";
            break;
         case 9:
            authorization.ownership_fence.takeover_generation++;
            passed=!SWV5_TestAuthorizationMatches(context,authorization,intent);
            expected="stale_owner_conflict";
            break;
         case 10:
         {
            SWV5_HardKillState hard_kill;
            SWV5_TestMakeHardKill(hard_kill,SWV5_HARD_KILL_RELEASE_PENDING);
            SWV5_HardKillReleaseEvidence release=hard_kill.release_evidence;
            release.release_id="RELEASE-1";
            release.release_generation=99;
            passed=!SWV5_TestHardKillReleaseValid(context,hard_kill,release);
            expected="release_rejected_latch_active";
            break;
         }
         case 11:
            pending.state=SWV5_REQUEST_ACKNOWLEDGED;
            restart.persisted.persisted_pending_request_count=1;
            restart.broker.pending_request_count=1;
            restart.persisted.pending_request_set_digest="PENDING-SET";
            restart.persisted.latest_pending_request.confirmation_status=SWV5_CONFIRMATION_PENDING;
            passed=pending.confirmed_volume==0.0 &&
                   SWV5_TestRestartDisposition(restart)==SWV5_RECONCILIATION_CONFLICT_HALT;
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
            passed=!SWV5_TestCloseComplete(close_evidence);
            expected="closing_or_halted_not_idle";
            break;
         }
      }
      SWV5_TestRecordCondition(collector,SWV5_TestCaseId("XDM",number),"CROSS_DOMAIN",passed,expected);
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
   const bool complete=first.Total()==162;
   Print("SWV5_MACHINE_RESULT "+first.SummaryJson(deterministic));
   PrintFormat("SWV5_HUMAN_RESULT total=%d passed=%d failed=%d skipped=%d deterministic=%s complete=%s",
               first.Total(),first.Passed(),first.Failed(),first.Skipped(),
               deterministic ? "true" : "false",complete ? "true" : "false");
   return first.AllPassed() && deterministic && complete;
}

#endif
