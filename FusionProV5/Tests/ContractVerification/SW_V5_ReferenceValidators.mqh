//+------------------------------------------------------------------+
//| TEST ONLY                                                        |
//| NOT FOR PRODUCTION                                               |
//| NO BROKER ACCESS                                                 |
//+------------------------------------------------------------------+
#ifndef SW_V5_REFERENCE_VALIDATORS_MQH
#define SW_V5_REFERENCE_VALIDATORS_MQH

#include "SW_V5_TestFixtures.mqh"

enum SWV5_TestBasketRule
{
   SWV5_TEST_BASKET_FORBID=0,
   SWV5_TEST_BASKET_ALLOW=1,
   SWV5_TEST_BASKET_SAME=2
};

bool SWV5_TestNear(const double left,const double right,const double tolerance)
{
   return MathAbs(left-right)<=tolerance;
}

bool SWV5_TestVersionEqual(const SWV5_ContractVersion &left,const SWV5_ContractVersion &right)
{
   return left.contract_name==right.contract_name &&
          left.schema_version==right.schema_version &&
          left.minimum_compatible_version==right.minimum_compatible_version &&
          left.policy_id==right.policy_id;
}

bool SWV5_TestVersionValid(const SWV5_ContractVersion &version)
{
   return version.contract_name!="" &&
          version.schema_version==SWV5_PRODUCTION_CONTRACT_VERSION &&
          version.minimum_compatible_version==SWV5_PRODUCTION_MINIMUM_COMPATIBLE_VERSION &&
          version.policy_id==SWV5_PRODUCTION_CONTRACT_POLICY;
}

bool SWV5_TestContextValid(const SWV5_ContractValidationContext &context)
{
   return SWV5_TestVersionValid(context.expected_version) &&
          context.clock_id!="" &&
          context.clock_authority!=SWV5_TIME_AUTHORITY_NONE &&
          context.clock_time>0 &&
          context.clock_sequence>0 &&
          context.evaluation_sequence>0 &&
          context.price_tolerance>=0.0 &&
          context.volume_tolerance>=0.0;
}

SWV5_ContractCompatibility SWV5_TestCompatibility(const SWV5_ContractVersion &candidate,
                                                   const SWV5_ContractValidationContext &context)
{
   if(!SWV5_TestContextValid(context) || candidate.contract_name=="" || candidate.policy_id!=SWV5_PRODUCTION_CONTRACT_POLICY)
      return SWV5_COMPATIBILITY_REJECTED;
   if(candidate.schema_version<SWV5_PRODUCTION_MINIMUM_COMPATIBLE_VERSION ||
      candidate.minimum_compatible_version>SWV5_PRODUCTION_CONTRACT_VERSION)
      return SWV5_COMPATIBILITY_MIGRATION_REQUIRED;
   if(SWV5_TestVersionEqual(candidate,context.expected_version))
      return SWV5_COMPATIBILITY_EXACT;
   return SWV5_COMPATIBILITY_REJECTED;
}

bool SWV5_TestOwnershipKeyEqual(const SWV5_OwnershipKey &left,const SWV5_OwnershipKey &right)
{
   return left.account_login==right.account_login &&
          left.broker_identity==right.broker_identity &&
          left.server==right.server &&
          left.symbol==right.symbol &&
          left.strategy_id==right.strategy_id &&
          left.magic==right.magic;
}

bool SWV5_TestOwnerEqual(const SWV5_OwnerIdentity &left,const SWV5_OwnerIdentity &right)
{
   return SWV5_TestOwnershipKeyEqual(left.key,right.key) &&
          left.instance_id==right.instance_id &&
          left.process_fingerprint==right.process_fingerprint &&
          left.started_at==right.started_at;
}

bool SWV5_TestFenceEqual(const SWV5_OwnershipFence &left,const SWV5_OwnershipFence &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestOwnershipKeyEqual(left.ownership_namespace,right.ownership_namespace) &&
          SWV5_TestOwnerEqual(left.owner,right.owner) &&
          left.lease_version==right.lease_version &&
          left.takeover_generation==right.takeover_generation &&
          left.fencing_token_digest==right.fencing_token_digest &&
          left.store_revision==right.store_revision;
}

bool SWV5_TestFenceComplete(const SWV5_OwnershipFence &fence)
{
   return SWV5_TestVersionValid(fence.contract_version) &&
          fence.owner.instance_id!="" && fence.owner.process_fingerprint!="" &&
          SWV5_TestOwnershipKeyEqual(fence.ownership_namespace,fence.owner.key) &&
          fence.lease_version>0 && fence.takeover_generation>0 &&
          fence.fencing_token_digest!="" && fence.store_revision!="";
}

bool SWV5_TestNamespaceEqual(const SWV5_PersistenceNamespace &left,const SWV5_PersistenceNamespace &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestOwnershipKeyEqual(left.ownership_namespace,right.ownership_namespace) &&
          left.basket_id.value==right.basket_id.value;
}

bool SWV5_TestNamespaceComplete(const SWV5_PersistenceNamespace &space)
{
   return SWV5_TestVersionValid(space.contract_version) &&
          space.ownership_namespace.account_login>0 &&
          space.ownership_namespace.broker_identity!="" &&
          space.ownership_namespace.server!="" &&
          space.ownership_namespace.symbol!="" &&
          space.ownership_namespace.strategy_id!="" &&
          space.ownership_namespace.magic>0 &&
          space.basket_id.value!="";
}

bool SWV5_TestRequestEqual(const SWV5_RequestID &left,const SWV5_RequestID &right)
{
   return left.correlation_id==right.correlation_id &&
          left.attempt_id==right.attempt_id &&
          left.parent_attempt_id==right.parent_attempt_id &&
          left.monotonic_sequence==right.monotonic_sequence &&
          left.created_at==right.created_at;
}

bool SWV5_TestCorrelationEqual(const SWV5_ExecutionCorrelation &left,const SWV5_ExecutionCorrelation &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestRequestEqual(left.request_id,right.request_id) &&
          left.order_ticket==right.order_ticket &&
          left.deal_ticket==right.deal_ticket &&
          left.position_identifier==right.position_identifier &&
          left.event_id==right.event_id &&
          left.idempotency_key==right.idempotency_key &&
          left.transaction_sequence==right.transaction_sequence;
}

bool SWV5_TestCorrelationComplete(const SWV5_ExecutionCorrelation &correlation)
{
   return SWV5_TestVersionValid(correlation.contract_version) &&
          correlation.request_id.correlation_id!="" &&
          correlation.request_id.attempt_id!="" &&
          correlation.request_id.monotonic_sequence>0 &&
          correlation.request_id.created_at>0 &&
          correlation.order_ticket>0 &&
          correlation.deal_ticket>0 &&
          correlation.position_identifier>0 &&
          correlation.event_id!="" &&
          correlation.idempotency_key!="" &&
          correlation.transaction_sequence>0;
}

bool SWV5_TestQueriesComplete(const SWV5_AuthoritativeQuerySet &queries)
{
   return SWV5_TestVersionValid(queries.contract_version) &&
          queries.required_flags>0 &&
          (queries.completed_flags&queries.required_flags)==queries.required_flags &&
          (queries.authoritative_flags&queries.required_flags)==queries.required_flags &&
          queries.observation_sequence>0;
}

SWV5_TestBasketRule SWV5_TestBasketPairRule(const SWV5_BasketState from_state,const SWV5_BasketState to_state)
{
   if(from_state<SWV5_BASKET_IDLE || from_state>SWV5_BASKET_ERROR ||
      to_state<SWV5_BASKET_IDLE || to_state>SWV5_BASKET_ERROR)
      return SWV5_TEST_BASKET_FORBID;
   if(from_state==to_state)
      return SWV5_TEST_BASKET_SAME;
   const int key=((int)from_state*7)+(int)to_state;
   switch(key)
   {
      case 1: case 5:
      case 9: case 11: case 12: case 13:
      case 17: case 18: case 19: case 20:
      case 23: case 25: case 26: case 27:
      case 28: case 33: case 34:
      case 35: case 39: case 41:
      case 47:
         return SWV5_TEST_BASKET_ALLOW;
   }
   return SWV5_TEST_BASKET_FORBID;
}

bool SWV5_TestBasketCauseValid(const SWV5_BasketState from_state,
                               const SWV5_BasketState to_state,
                               const SWV5_BasketTransitionCause cause)
{
   if(from_state==to_state)
      return cause==SWV5_TRANSITION_NONE;
   if(from_state==SWV5_BASKET_IDLE && to_state==SWV5_BASKET_OPENING)
      return cause==SWV5_TRANSITION_OPEN_AUTHORIZED;
   if(from_state==SWV5_BASKET_IDLE && to_state==SWV5_BASKET_HALTED)
      return cause==SWV5_TRANSITION_HARD_KILL || cause==SWV5_TRANSITION_OPERATOR_HALT;
   if(from_state==SWV5_BASKET_OPENING && to_state==SWV5_BASKET_ACTIVE)
      return cause==SWV5_TRANSITION_OPEN_CONFIRMED;
   if(from_state==SWV5_BASKET_OPENING && to_state==SWV5_BASKET_CLOSING)
      return cause==SWV5_TRANSITION_OPEN_PARTIAL || cause==SWV5_TRANSITION_CLOSE_AUTHORIZED;
   if((from_state==SWV5_BASKET_OPENING || from_state==SWV5_BASKET_ACTIVE ||
       from_state==SWV5_BASKET_RECOVERY || from_state==SWV5_BASKET_CLOSING) && to_state==SWV5_BASKET_HALTED)
      return cause==SWV5_TRANSITION_HARD_KILL || cause==SWV5_TRANSITION_OWNERSHIP_LOST ||
             cause==SWV5_TRANSITION_BROKER_STATE_UNCERTAIN;
   if(from_state==SWV5_BASKET_ACTIVE && to_state==SWV5_BASKET_RECOVERY)
      return cause==SWV5_TRANSITION_RECOVERY_AUTHORIZED;
   if((from_state==SWV5_BASKET_ACTIVE || from_state==SWV5_BASKET_RECOVERY) && to_state==SWV5_BASKET_CLOSING)
      return cause==SWV5_TRANSITION_CLOSE_AUTHORIZED || cause==SWV5_TRANSITION_MANDATORY_RISK_REDUCTION;
   if(from_state==SWV5_BASKET_RECOVERY && to_state==SWV5_BASKET_ACTIVE)
      return cause==SWV5_TRANSITION_RECOVERY_CONFIRMED;
   if(from_state==SWV5_BASKET_CLOSING && to_state==SWV5_BASKET_IDLE)
      return cause==SWV5_TRANSITION_CLOSE_CONFIRMED_EMPTY;
   if(from_state==SWV5_BASKET_HALTED && to_state==SWV5_BASKET_IDLE)
      return cause==SWV5_TRANSITION_OPERATOR_RESET;
   if(from_state==SWV5_BASKET_HALTED && to_state==SWV5_BASKET_CLOSING)
      return cause==SWV5_TRANSITION_CLOSE_AUTHORIZED || cause==SWV5_TRANSITION_RECONCILIATION_CONFIRMED;
   if(from_state==SWV5_BASKET_ERROR && to_state==SWV5_BASKET_HALTED)
      return cause==SWV5_TRANSITION_RECONCILIATION_CONFIRMED;
   if(to_state==SWV5_BASKET_ERROR)
      return cause==SWV5_TRANSITION_CONTRACT_VIOLATION || cause==SWV5_TRANSITION_RECONCILIATION_FAILED;
   return false;
}

bool SWV5_TestBasketEvidenceValid(const SWV5_BasketLifecycleSnapshot &snapshot,
                                  const SWV5_BasketTransitionRequest &request)
{
   if(!SWV5_TestVersionValid(snapshot.contract_version) ||
      !SWV5_TestVersionValid(request.contract_version) ||
      snapshot.basket_id.value=="" ||
      snapshot.basket_id.value!=request.basket_id.value ||
      !SWV5_TestFenceEqual(snapshot.ownership_fence,request.ownership_fence) ||
      snapshot.state!=request.from_state ||
      snapshot.state_version!=request.expected_state_version ||
      !SWV5_TestBasketCauseValid(request.from_state,request.to_state,request.cause) ||
      !SWV5_TestQueriesComplete(request.broker_queries))
      return false;
   if(request.to_state==SWV5_BASKET_IDLE)
      return SWV5_TestNear(request.residual_volume,0.0,0.0000001) &&
             request.live_position_count==0 && request.live_order_count==0 && request.pending_request_count==0;
   if(request.from_state==SWV5_BASKET_IDLE && request.to_state==SWV5_BASKET_OPENING)
      return SWV5_TestNear(request.residual_volume,0.0,0.0000001) &&
             request.live_position_count==0 && request.live_order_count==0 && request.pending_request_count==0 &&
             request.risk_decision.disposition==SWV5_DISPOSITION_ALLOW &&
             request.reconciliation_state==SWV5_RECONCILIATION_STATE_MATCHED;
   if(request.to_state==SWV5_BASKET_ACTIVE)
      return request.confirmation_authority==SWV5_AUTHORITY_TRANSACTION_EVENT &&
             request.reconciliation_state==SWV5_RECONCILIATION_STATE_MATCHED;
   if(request.from_state==SWV5_BASKET_HALTED && request.to_state==SWV5_BASKET_CLOSING)
      return request.residual_volume>0.0 && request.reconciliation_state==SWV5_RECONCILIATION_STATE_MATCHED;
   return true;
}

SWV5_TestBasketRule SWV5_TestEvaluateBasketTransition(const SWV5_ContractValidationContext &context,
                                                       const SWV5_BasketLifecycleSnapshot &snapshot,
                                                       const SWV5_BasketTransitionRequest &request,
                                                       ulong &resulting_version)
{
   resulting_version=snapshot.state_version;
   if(!SWV5_TestContextValid(context))
      return SWV5_TEST_BASKET_FORBID;
   const SWV5_TestBasketRule rule=SWV5_TestBasketPairRule(snapshot.state,request.to_state);
   if(rule==SWV5_TEST_BASKET_SAME)
      return rule;
   if(rule==SWV5_TEST_BASKET_ALLOW && SWV5_TestBasketEvidenceValid(snapshot,request))
   {
      resulting_version=snapshot.state_version+1;
      return SWV5_TEST_BASKET_ALLOW;
   }
   return SWV5_TEST_BASKET_FORBID;
}

bool SWV5_TestAggregateIdentityValid(const SWV5_BasketAggregate &basket)
{
   return SWV5_TestNamespaceComplete(basket.persistence_namespace) &&
          basket.persistence_namespace.basket_id.value==basket.lifecycle.basket_id.value &&
          SWV5_TestFenceComplete(basket.lifecycle.ownership_fence) &&
          basket.account_mode==SWV5_ACCOUNT_MODE_HEDGING;
}

bool SWV5_TestPartialCloseValid(const SWV5_BasketAggregate &basket,const SWV5_PartialCloseEvidence &evidence)
{
   return SWV5_TestNamespaceEqual(basket.persistence_namespace,evidence.persistence_namespace) &&
          SWV5_TestFenceEqual(basket.lifecycle.ownership_fence,evidence.ownership_fence) &&
          SWV5_TestCorrelationComplete(evidence.correlation) &&
          evidence.authority==SWV5_AUTHORITY_TRANSACTION_EVENT &&
          evidence.closed_volume>0.0 && evidence.closed_volume<=evidence.volume_before &&
          SWV5_TestNear(evidence.volume_before-evidence.closed_volume,evidence.residual_volume,0.0000001);
}

bool SWV5_TestCloseComplete(const SWV5_CloseVerificationEvidence &evidence)
{
   return evidence.state==SWV5_CLOSE_ZERO_RESIDUAL_CONFIRMED &&
          SWV5_TestNear(evidence.broker_residual_volume,0.0,0.0000001) &&
          evidence.broker_position_count==0 && evidence.broker_order_count==0 &&
          evidence.pending_request_count==0 && SWV5_TestQueriesComplete(evidence.broker_queries);
}

bool SWV5_TestSpecificationValid(const SWV5_SymbolUnitSpecification &specification)
{
   return SWV5_TestVersionValid(specification.contract_version) && specification.complete &&
          specification.symbol!="" && specification.specification_sequence>0 &&
          specification.point_size>0.0 && specification.tick_size>0.0 && specification.pip_size>0.0 &&
          specification.tick_value_profit>0.0 && specification.tick_value_loss>0.0 &&
          specification.tick_value_basis_volume>0.0 && specification.contract_size>0.0 &&
          specification.volume_minimum>0.0 && specification.volume_maximum>=specification.volume_minimum &&
          specification.volume_step>0.0 && specification.account_currency!="" &&
          specification.tick_value_currency==specification.account_currency;
}

double SWV5_TestRoundToStep(const double value,const double step,const SWV5_NormalizationDirection direction)
{
   const double units=value/step;
   if(direction==SWV5_NORMALIZE_DOWN)
      return MathFloor(units+0.0000000001)*step;
   if(direction==SWV5_NORMALIZE_UP)
      return MathCeil(units-0.0000000001)*step;
   return MathRound(units)*step;
}

bool SWV5_TestNormalize(const SWV5_ContractValidationContext &context,
                        const SWV5_SymbolUnitSpecification &specification,
                        const SWV5_UnitNormalizationRequest &request,
                        SWV5_NormalizedUnits &normalized)
{
   if(!SWV5_TestContextValid(context) || !SWV5_TestSpecificationValid(specification) ||
      request.expected_specification_sequence!=specification.specification_sequence ||
      request.market_bid<=0.0 || request.market_ask<=0.0 || request.market_ask<request.market_bid)
      return false;
   normalized.contract_version=request.contract_version;
   normalized.persistence_namespace=request.persistence_namespace;
   normalized.ownership_fence=request.ownership_fence;
   normalized.price=SWV5_TestRoundToStep(request.raw_price,specification.tick_size,request.price_rounding);
   normalized.stop_price=SWV5_TestRoundToStep(request.raw_stop_price,specification.tick_size,request.price_rounding);
   normalized.limit_price=SWV5_TestRoundToStep(request.raw_limit_price,specification.tick_size,request.price_rounding);
   normalized.volume=SWV5_TestRoundToStep(request.raw_volume,specification.volume_step,request.volume_rounding);
   normalized.stop_distance_price=MathAbs(request.reference_market_price-normalized.stop_price);
   normalized.stop_distance_points=normalized.stop_distance_price/specification.point_size;
   normalized.stop_distance_ticks=normalized.stop_distance_price/specification.tick_size;
   normalized.monetary_tick_value_per_volume_unit=specification.tick_value_profit/specification.tick_value_basis_volume;
   normalized.monetary_value_currency=specification.tick_value_currency;
   normalized.specification_sequence=specification.specification_sequence;
   normalized.applied_price_rounding=request.price_rounding;
   normalized.applied_volume_rounding=request.volume_rounding;
   normalized.price_aligned_to_tick=SWV5_TestNear(normalized.price/specification.tick_size,
                                                  MathRound(normalized.price/specification.tick_size),context.price_tolerance);
   normalized.volume_aligned_to_step=SWV5_TestNear(normalized.volume/specification.volume_step,
                                                   MathRound(normalized.volume/specification.volume_step),context.volume_tolerance);
   normalized.stops_level_satisfied=normalized.stop_distance_points+context.price_tolerance>=specification.stops_level_points;
   const double market_distance_points=MathAbs(request.reference_market_price-(request.direction>0 ? request.market_ask : request.market_bid))/specification.point_size;
   normalized.freeze_level_satisfied=!request.protective_operation || market_distance_points+context.price_tolerance>=specification.freeze_level_points;
   return normalized.volume>=specification.volume_minimum-context.volume_tolerance &&
          normalized.volume<=specification.volume_maximum+context.volume_tolerance &&
          normalized.price_aligned_to_tick && normalized.volume_aligned_to_step &&
          normalized.stops_level_satisfied && normalized.freeze_level_satisfied;
}

bool SWV5_TestCanTakeover(const SWV5_ContractValidationContext &context,
                          const SWV5_OwnershipClaim &claim,
                          const SWV5_InstanceLease &observed)
{
   return SWV5_TestContextValid(context) && observed.status==SWV5_LOCK_EXPIRED &&
          observed.clock_id==context.clock_id && context.clock_sequence>=observed.expiry_clock_sequence &&
          context.clock_time>=observed.expires_at && claim.broker_state_reconciled &&
          claim.persistence_reconciled && claim.broker_reconciliation_id!="" &&
          claim.persistence_reconciliation_id!="" &&
          SWV5_TestOwnershipKeyEqual(claim.claimant.key,observed.fence.ownership_namespace) &&
          SWV5_TestFenceEqual(claim.expected_fence,observed.fence);
}

bool SWV5_TestHeartbeatValid(const SWV5_ContractValidationContext &context,
                             const SWV5_InstanceLease &caller,
                             const SWV5_InstanceLease &observed)
{
   return SWV5_TestContextValid(context) && caller.clock_id==context.clock_id &&
          SWV5_TestFenceEqual(caller.fence,observed.fence) &&
          caller.heartbeat_sequence>=observed.heartbeat_sequence;
}

bool SWV5_TestIntentValid(const SWV5_ContractValidationContext &context,const SWV5_ExecutionIntent &intent)
{
   return SWV5_TestContextValid(context) && SWV5_TestVersionValid(intent.contract_version) &&
          SWV5_TestNamespaceComplete(intent.persistence_namespace) && SWV5_TestCorrelationComplete(intent.correlation) &&
          intent.normalized_volume>0.0 && intent.normalized_price>0.0 &&
          intent.symbol_specification_sequence>0 && intent.expected_basket_version>0 &&
          intent.risk_authorization_id!="" && intent.authorization_expires_at>=context.clock_time;
}

SWV5_ResultRetcodeClass SWV5_TestClassifyRetcode(const uint raw_retcode)
{
   switch(raw_retcode)
   {
      case 1: return SWV5_RETCODE_ACCEPTED_PENDING_CONFIRMATION;
      case 2: return SWV5_RETCODE_SYNCHRONOUS_DEAL_REPORTED_PENDING_EVIDENCE;
      case 3: return SWV5_RETCODE_REJECTED_PERMANENT;
      case 4: return SWV5_RETCODE_CONNECTION_UNCERTAIN;
      case 5: return SWV5_RETCODE_PRICE_CHANGED;
      case 6: return SWV5_RETCODE_VOLUME_CHANGED;
   }
   return SWV5_RETCODE_UNCLASSIFIED;
}

SWV5_ConfirmationStatus SWV5_TestConfirmExecution(const SWV5_PendingRequest &pending,
                                                   const SWV5_TransactionEvidence &evidence,
                                                   double &confirmed_volume,
                                                   double &residual_volume)
{
   confirmed_volume=pending.confirmed_volume;
   residual_volume=pending.residual_requested_volume;
   if(!SWV5_TestNamespaceEqual(pending.intent.persistence_namespace,evidence.persistence_namespace) ||
      !SWV5_TestFenceEqual(pending.intent.ownership_fence,evidence.ownership_fence) ||
      !SWV5_TestRequestEqual(pending.intent.correlation.request_id,evidence.correlation.request_id) ||
      evidence.expected_basket_version!=pending.intent.expected_basket_version ||
      evidence.symbol_specification_sequence!=pending.intent.symbol_specification_sequence ||
      !SWV5_TestCorrelationComplete(evidence.correlation))
      return SWV5_CONFIRMATION_CONFLICT;
   if(evidence.correlation.event_id==pending.last_accepted_correlation.event_id ||
      evidence.correlation.idempotency_key==pending.last_accepted_correlation.idempotency_key)
      return pending.state==SWV5_REQUEST_PARTIALLY_CONFIRMED ? SWV5_CONFIRMATION_PARTIAL : SWV5_CONFIRMATION_CONFIRMED;
   if(evidence.correlation.transaction_sequence<pending.last_accepted_correlation.transaction_sequence)
      return SWV5_CONFIRMATION_CONFLICT;
   confirmed_volume+=evidence.confirmed_volume;
   residual_volume=MathMax(0.0,pending.intent.normalized_volume-confirmed_volume);
   if(residual_volume>0.0000001)
      return SWV5_CONFIRMATION_PARTIAL;
   return SWV5_CONFIRMATION_CONFIRMED;
}

bool SWV5_TestPersistenceRecordValid(const SWV5_PersistedCheckpoint &checkpoint)
{
   return SWV5_TestVersionValid(checkpoint.header.contract_version) &&
          SWV5_TestNamespaceComplete(checkpoint.header.persistence_namespace) &&
          SWV5_TestFenceEqual(checkpoint.header.ownership_fence,checkpoint.basket.lifecycle.ownership_fence) &&
          checkpoint.header.record_sequence>checkpoint.header.previous_record_sequence &&
          checkpoint.header.payload_digest!="" && checkpoint.header.payload_size>0 &&
          checkpoint.header.written_at>0 &&
          checkpoint.header.persistence_namespace.basket_id.value==checkpoint.basket.lifecycle.basket_id.value;
}

SWV5_ReconciliationStatus SWV5_TestRestartDisposition(const SWV5_RestartReconciliationInput &engineInput)
{
   if(engineInput.persistence_status!=SWV5_PERSISTENCE_LOADED)
      return SWV5_RECONCILIATION_CORRUPT_HALT;
   if(!SWV5_TestNamespaceComplete(engineInput.persistence_namespace))
      return SWV5_RECONCILIATION_CONFLICT_HALT;
   if(!SWV5_TestNamespaceEqual(engineInput.persistence_namespace,engineInput.persisted.header.persistence_namespace) ||
      !SWV5_TestNamespaceEqual(engineInput.persistence_namespace,engineInput.broker.persistence_namespace))
      return SWV5_RECONCILIATION_CONFLICT_HALT;
   if(!SWV5_TestFenceEqual(engineInput.claimant_fence,engineInput.persisted.header.ownership_fence))
      return SWV5_RECONCILIATION_OWNERSHIP_CONFLICT_HALT;
   if(!SWV5_TestQueriesComplete(engineInput.broker.queries))
      return SWV5_RECONCILIATION_MANUAL_REQUIRED;
   const double persisted_volume=engineInput.persisted.basket.lifecycle.residual_volume;
   const double broker_volume=engineInput.broker.residual_volume;
   if(broker_volume>persisted_volume+0.0000001)
      return SWV5_RECONCILIATION_BROKER_AHEAD_HALT;
   if(persisted_volume>broker_volume+0.0000001)
      return SWV5_RECONCILIATION_PERSISTENCE_AHEAD_HALT;
   if(engineInput.persisted.persisted_pending_request_count!=engineInput.broker.pending_request_count ||
      (engineInput.persisted.persisted_pending_request_count>0 && engineInput.persisted.pending_request_set_digest==""))
      return SWV5_RECONCILIATION_CONFLICT_HALT;
   if(engineInput.persisted.persisted_pending_request_count>0 &&
      (engineInput.persisted.latest_pending_request.confirmation_status==SWV5_CONFIRMATION_NOT_STARTED ||
       engineInput.persisted.latest_pending_request.confirmation_status==SWV5_CONFIRMATION_PENDING ||
       engineInput.persisted.latest_pending_request.confirmation_status==SWV5_CONFIRMATION_CONFLICT ||
       !SWV5_TestNamespaceEqual(engineInput.persisted.latest_pending_request.persistence_namespace,engineInput.persistence_namespace) ||
       !SWV5_TestFenceEqual(engineInput.persisted.latest_pending_request.ownership_fence,engineInput.claimant_fence) ||
       !SWV5_TestCorrelationComplete(engineInput.persisted.latest_pending_request.correlation)))
      return SWV5_RECONCILIATION_CONFLICT_HALT;
   return SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED;
}

bool SWV5_TestMonetaryBasisComplete(const SWV5_RiskMonetaryBasis &basis)
{
   return SWV5_TestVersionValid(basis.contract_version) && basis.currency!="" && basis.account_currency!="" &&
          basis.conversion_rate_to_account_currency>0.0 && basis.conversion_source!="" && basis.valuation_at>0 &&
          basis.calculation_basis!=SWV5_RISK_BASIS_UNDEFINED && basis.sign_convention!=SWV5_RISK_SIGN_UNDEFINED &&
          basis.includes_realized && basis.includes_unrealized && basis.includes_commission && basis.includes_swap && basis.includes_fee;
}

SWV5_RiskDisposition SWV5_TestRiskPrecheck(const SWV5_HardKillState &hard_kill,
                                           const SWV5_OwnershipFence &required_fence,
                                           const SWV5_OwnershipFence &observed_fence)
{
   if(hard_kill.state==SWV5_HARD_KILL_ACTIVE || hard_kill.state==SWV5_HARD_KILL_RELEASE_PENDING)
      return SWV5_RISK_HARD_KILL;
   if(!SWV5_TestFenceComplete(required_fence) || !SWV5_TestFenceEqual(required_fence,observed_fence))
      return SWV5_RISK_RECONCILIATION_REQUIRED;
   return SWV5_RISK_ALLOW;
}

bool SWV5_TestAuthorizationMatches(const SWV5_ContractValidationContext &context,
                                    const SWV5_RiskAuthorization &authorization,
                                    const SWV5_ExecutionIntent &intent)
{
   return SWV5_TestContextValid(context) && authorization.disposition==SWV5_RISK_ALLOW &&
          authorization.expires_at>=context.clock_time &&
          SWV5_TestCorrelationEqual(authorization.correlation,intent.correlation) &&
          SWV5_TestNamespaceEqual(authorization.persistence_namespace,intent.persistence_namespace) &&
          SWV5_TestFenceEqual(authorization.ownership_fence,intent.ownership_fence) &&
          authorization.basket_state_version==intent.expected_basket_version &&
          authorization.symbol_specification_sequence==intent.symbol_specification_sequence &&
          authorization.authorized_intent_type==intent.intent_type &&
          authorization.authorized_direction==intent.direction &&
          SWV5_TestNear(authorization.authorized_volume,intent.normalized_volume,context.volume_tolerance) &&
          SWV5_TestNear(authorization.authorized_price,intent.normalized_price,context.price_tolerance) &&
          SWV5_TestNear(authorization.authorized_stop_price,intent.normalized_stop_price,context.price_tolerance) &&
          SWV5_TestNear(authorization.authorized_limit_price,intent.normalized_limit_price,context.price_tolerance) &&
          authorization.account_risk_snapshot_sequence>0 && authorization.exposure_risk_snapshot_sequence>0 &&
          authorization.basket_risk_snapshot_sequence>0 && authorization.projected_risk_snapshot_sequence>0 &&
          authorization.hard_kill_latch_id!="" && authorization.hard_kill_latch_generation>0 &&
          SWV5_TestMonetaryBasisComplete(authorization.monetary_basis);
}

bool SWV5_TestHardKillReleaseValid(const SWV5_ContractValidationContext &context,
                                   const SWV5_HardKillState &state,
                                   const SWV5_HardKillReleaseEvidence &evidence)
{
   return state.state==SWV5_HARD_KILL_RELEASE_PENDING && evidence.release_id!="" &&
          evidence.latch_id==state.latch_id && evidence.latch_generation==state.latch_generation &&
          evidence.release_generation==state.release_generation+1 &&
          evidence.operator_identity.operator_id!="" && evidence.operator_identity.authority_role!="" &&
          evidence.operator_identity.authentication_reference!="" &&
          evidence.broker_state_reconciled && evidence.persistence_reconciled &&
          evidence.zero_or_reducing_exposure_confirmed && evidence.audit_reference!="" &&
          evidence.approved_at<=context.clock_time && evidence.expires_at>=context.clock_time;
}

bool SWV5_TestDealValid(const SWV5_AuthoritativeDeal &deal,const SWV5_StatisticsBuildContext &context)
{
   return SWV5_TestVersionValid(deal.contract_version) &&
          SWV5_TestNamespaceEqual(deal.persistence_namespace,context.persistence_namespace) &&
          SWV5_TestCorrelationComplete(deal.correlation) && deal.authority==SWV5_AUTHORITY_DEAL_HISTORY &&
          deal.volume>0.0 && deal.price>0.0 && deal.account_currency!="" &&
          deal.monetary_components_complete && context.account_mode==SWV5_ACCOUNT_MODE_HEDGING &&
          SWV5_TestQueriesComplete(context.history_queries);
}

bool SWV5_TestDedupEvidenceValid(const SWV5_StatisticsDeduplicationEvidence &evidence,
                                 const SWV5_StatisticsDeduplicationState &state)
{
   if(evidence.prior_identity_set_digest!=state.identity_set_digest || evidence.identity_index_sequence!=state.identity_index_sequence+1)
      return false;
   if(evidence.disposition==SWV5_STAT_IDENTITY_DUPLICATE)
      return evidence.membership_proof!="";
   if(evidence.disposition==SWV5_STAT_IDENTITY_NEW || evidence.disposition==SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW)
      return evidence.membership_proof=="" && SWV5_TestCorrelationComplete(evidence.correlation);
   return false;
}

double SWV5_TestDealNet(const SWV5_AuthoritativeDeal &deal)
{
   return deal.gross_profit+deal.commission+deal.swap+deal.fee;
}

#endif
