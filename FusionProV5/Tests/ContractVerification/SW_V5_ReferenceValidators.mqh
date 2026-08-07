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

bool SWV5_TestRequestIdentityEqual(const SWV5_ExecutionRequestIdentity &left,
                                   const SWV5_ExecutionRequestIdentity &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestRequestEqual(left.request_id,right.request_id) &&
          left.idempotency_key==right.idempotency_key;
}

bool SWV5_TestRequestIdentityComplete(const SWV5_ExecutionRequestIdentity &identity)
{
   return SWV5_TestVersionValid(identity.contract_version) &&
          identity.request_id.correlation_id!="" && identity.request_id.attempt_id!="" &&
          identity.request_id.monotonic_sequence>0 && identity.request_id.created_at>0 &&
          identity.idempotency_key!="";
}

bool SWV5_TestCorrelationEqual(const SWV5_ExecutionCorrelation &left,const SWV5_ExecutionCorrelation &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          left.phase==right.phase &&
          SWV5_TestRequestIdentityEqual(left.request_identity,right.request_identity) &&
          SWV5_TestVersionEqual(left.broker_identity.contract_version,right.broker_identity.contract_version) &&
          left.broker_identity.order_ticket==right.broker_identity.order_ticket &&
          left.broker_identity.deal_ticket==right.broker_identity.deal_ticket &&
          left.broker_identity.position_identifier==right.broker_identity.position_identifier &&
          left.broker_identity.broker_event_id==right.broker_identity.broker_event_id &&
          left.broker_identity.transaction_sequence==right.broker_identity.transaction_sequence;
}

bool SWV5_TestCorrelationComplete(const SWV5_ExecutionCorrelation &correlation)
{
   if(!SWV5_TestVersionValid(correlation.contract_version) ||
      !SWV5_TestRequestIdentityComplete(correlation.request_identity))
      return false;
   if(correlation.phase==SWV5_EXECUTION_PHASE_INTENT || correlation.phase==SWV5_EXECUTION_PHASE_SUBMISSION)
      return correlation.broker_identity.order_ticket==0 && correlation.broker_identity.deal_ticket==0 &&
             correlation.broker_identity.position_identifier==0 && correlation.broker_identity.broker_event_id=="" &&
             correlation.broker_identity.transaction_sequence==0;
   if(!SWV5_TestVersionValid(correlation.broker_identity.contract_version))
      return false;
   if(correlation.phase==SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT)
      return correlation.broker_identity.order_ticket>0;
   return correlation.broker_identity.broker_event_id!="" &&
          correlation.broker_identity.transaction_sequence>0 &&
          (correlation.broker_identity.order_ticket>0 || correlation.broker_identity.deal_ticket>0 ||
           correlation.broker_identity.position_identifier>0);
}

bool SWV5_TestEventIdentitySetContains(const SWV5_DurableEventIdentitySet &set,
                                        const SWV5_BrokerExecutionIdentity &identity)
{
   const string token=identity.broker_event_id+"|"+IntegerToString((long)identity.transaction_sequence);
   return token!="|0" && StringFind(";"+set.canonical_event_index+";",";"+token+";")>=0;
}

string SWV5_TestEventSetDigest(const SWV5_DurableEventIdentitySet &set)
{
   return SWV5_TestCanonicalHash("SWV5-EVENT-SET-V3|"+set.canonical_event_index+"|"+
                                 IntegerToString((long)set.accepted_identity_count)+"|"+
                                 IntegerToString((long)set.highest_transaction_sequence)+"|"+
                                 IntegerToString((long)set.index_revision)+"|"+
                                 IntegerToString((long)set.compaction_generation));
}

bool SWV5_TestEventSetIntegrityValid(const SWV5_DurableEventIdentitySet &set)
{
   return SWV5_TestVersionValid(set.contract_version) && set.compaction_generation>0 &&
          set.identity_set_digest==SWV5_TestEventSetDigest(set) &&
          ((set.accepted_identity_count==0 && set.canonical_event_index=="" && set.highest_transaction_sequence==0) ||
           (set.accepted_identity_count>0 && set.canonical_event_index!="" && set.highest_transaction_sequence>0));
}

SWV5_StatisticsIdentityDisposition SWV5_TestAppendEventIdentity(const string event_id,
                                                                 const ulong sequence,
                                                                 const SWV5_DurableEventIdentitySet &current,
                                                                 SWV5_DurableEventIdentitySet &next)
{
   next=current;
   if(event_id=="" || sequence==0 || !SWV5_TestEventSetIntegrityValid(current))
      return SWV5_STAT_IDENTITY_CONFLICT;
   const string token=event_id+"|"+IntegerToString((long)sequence);
   const string wrapped=";"+current.canonical_event_index+";";
   if(StringFind(wrapped,";"+token+";")>=0)
      return SWV5_STAT_IDENTITY_DUPLICATE;
   if(StringFind(wrapped,";"+event_id+"|")>=0 || StringFind(wrapped,"|"+IntegerToString((long)sequence)+";")>=0)
      return SWV5_STAT_IDENTITY_CONFLICT;
   next.canonical_event_index+=(next.canonical_event_index=="" ? "" : ";")+token;
   next.accepted_identity_count++;
   if(sequence>next.highest_transaction_sequence)
      next.highest_transaction_sequence=sequence;
   next.index_revision++;
   next.identity_set_digest=SWV5_TestEventSetDigest(next);
   return sequence<current.highest_transaction_sequence ? SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW : SWV5_STAT_IDENTITY_NEW;
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
   if(request.from_state==SWV5_BASKET_ACTIVE && request.to_state==SWV5_BASKET_RECOVERY)
   {
      const string recovery_token=request.recovery_evidence.evidence_identity+"|"+IntegerToString((long)request.recovery_evidence.evidence_sequence);
      return SWV5_TestRequestIdentityEqual(request.recovery_evidence.request_identity,request.correlation.request_identity) &&
             request.recovery_evidence.prior_cumulative_recovery_attempts==snapshot.cumulative_recovery_attempts &&
             request.recovery_evidence.proposed_cumulative_recovery_attempts==snapshot.cumulative_recovery_attempts+1 &&
             request.recovery_evidence.prior_recovery_layer==snapshot.current_recovery_layer &&
             request.recovery_evidence.proposed_recovery_layer==snapshot.current_recovery_layer+1 &&
             request.recovery_evidence.authorization_id!="" && request.recovery_evidence.evidence_identity!="" &&
             request.recovery_evidence.evidence_sequence>0 && request.recovery_evidence.evidenced_at<=request.evidence_time &&
             StringFind(";"+snapshot.accepted_recovery_evidence.canonical_event_index+";",";"+recovery_token+";")<0;
   }
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

bool SWV5_TestSpecificationValid(const SWV5_ContractValidationContext &context,
                                 const SWV5_SymbolUnitSpecification &specification)
{
   return SWV5_TestVersionValid(specification.contract_version) && specification.complete &&
          specification.symbol!="" && specification.specification_sequence>0 &&
          specification.point_size>0.0 && specification.tick_size>0.0 && specification.pip_size>0.0 &&
          specification.tick_value_profit>0.0 && specification.tick_value_loss>0.0 &&
          specification.tick_value_basis_volume>0.0 && specification.contract_size>0.0 &&
          specification.volume_minimum>0.0 && specification.volume_maximum>=specification.volume_minimum &&
          specification.volume_step>0.0 && specification.account_currency!="" &&
          specification.tick_value_currency==specification.account_currency &&
          specification.observed_at<=context.clock_time && specification.valid_until>=context.clock_time;
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
   if(!SWV5_TestContextValid(context) || !SWV5_TestSpecificationValid(context,specification) ||
      request.expected_specification_sequence!=specification.specification_sequence ||
      request.market_bid<=0.0 || request.market_ask<=0.0 || request.market_ask<request.market_bid)
      return false;
   normalized.contract_version=request.contract_version;
   normalized.persistence_namespace=request.persistence_namespace;
   normalized.ownership_fence=request.ownership_fence;
   const SWV5_NormalizationDirection entry_rounding=(request.direction>0 ? SWV5_NORMALIZE_UP : SWV5_NORMALIZE_DOWN);
   const SWV5_NormalizationDirection stop_rounding=(request.direction>0 ? SWV5_NORMALIZE_DOWN : SWV5_NORMALIZE_UP);
   const SWV5_NormalizationDirection limit_rounding=(request.direction>0 ? SWV5_NORMALIZE_DOWN : SWV5_NORMALIZE_UP);
   const SWV5_NormalizationDirection volume_rounding=(request.exposure_increasing ? SWV5_NORMALIZE_DOWN :
                                                       (request.protective_operation ? SWV5_NORMALIZE_UP : SWV5_NORMALIZE_NEAREST));
   normalized.price=SWV5_TestRoundToStep(request.raw_price,specification.tick_size,entry_rounding);
   normalized.stop_price=SWV5_TestRoundToStep(request.raw_stop_price,specification.tick_size,stop_rounding);
   normalized.limit_price=SWV5_TestRoundToStep(request.raw_limit_price,specification.tick_size,limit_rounding);
   normalized.volume=SWV5_TestRoundToStep(request.raw_volume,specification.volume_step,volume_rounding);
   normalized.stop_distance_price=MathAbs(request.operation_price-normalized.stop_price);
   normalized.stop_distance_points=normalized.stop_distance_price/specification.point_size;
   normalized.stop_distance_ticks=normalized.stop_distance_price/specification.tick_size;
   normalized.monetary_tick_value_per_volume_unit=specification.tick_value_profit/specification.tick_value_basis_volume;
   normalized.monetary_value_currency=specification.tick_value_currency;
   normalized.specification_sequence=specification.specification_sequence;
   normalized.applied_entry_rounding=entry_rounding;
   normalized.applied_stop_rounding=stop_rounding;
   normalized.applied_limit_rounding=limit_rounding;
   normalized.applied_volume_rounding=volume_rounding;
   normalized.price_aligned_to_tick=SWV5_TestNear(normalized.price/specification.tick_size,
                                                  MathRound(normalized.price/specification.tick_size),context.price_tolerance);
   normalized.volume_aligned_to_step=SWV5_TestNear(normalized.volume/specification.volume_step,
                                                   MathRound(normalized.volume/specification.volume_step),context.volume_tolerance);
   normalized.stops_level_satisfied=normalized.stop_distance_points+context.price_tolerance>=specification.stops_level_points;
   const bool stop_side_valid=(request.raw_stop_price<=0.0) ||
                              (request.direction>0 ? normalized.stop_price<request.operation_price : normalized.stop_price>request.operation_price);
   const double operation_market_side=(request.direction>0 ? request.market_bid : request.market_ask);
   const double market_distance_points=MathAbs(request.operation_price-operation_market_side)/specification.point_size;
   normalized.freeze_level_satisfied=!request.protective_operation || market_distance_points+context.price_tolerance>=specification.freeze_level_points;
   return normalized.volume>=specification.volume_minimum-context.volume_tolerance &&
          normalized.volume<=specification.volume_maximum+context.volume_tolerance &&
          normalized.price_aligned_to_tick && normalized.volume_aligned_to_step &&
          stop_side_valid && normalized.stops_level_satisfied && normalized.freeze_level_satisfied;
}

bool SWV5_TestCanTakeover(const SWV5_ContractValidationContext &context,
                          const SWV5_OwnershipClaim &claim,
                          const SWV5_InstanceLease &observed)
{
   return SWV5_TestContextValid(context) && observed.status==SWV5_LOCK_EXPIRED &&
           observed.clock_id==context.clock_id && context.clock_sequence>=observed.expiry_clock_sequence &&
            context.clock_time>=observed.expires_at && claim.takeover_evidence.lease_expiry.expired &&
            SWV5_TestOwnershipKeyEqual(claim.takeover_evidence.lease_expiry.observed_ownership_key,observed.fence.ownership_namespace) &&
            claim.takeover_evidence.lease_expiry.clock_id==context.clock_id &&
            claim.takeover_evidence.lease_expiry.clock_authority==context.clock_authority &&
            claim.takeover_evidence.lease_expiry.observed_clock_sequence>=observed.expiry_clock_sequence &&
            claim.takeover_evidence.lease_expiry.observed_at<=context.clock_time &&
            claim.takeover_evidence.lease_expiry.observed_lease_version==observed.fence.lease_version &&
            claim.takeover_evidence.lease_expiry.observed_heartbeat_sequence==observed.heartbeat_sequence &&
            claim.takeover_evidence.lease_expiry.observed_store_revision==observed.fence.store_revision &&
            claim.takeover_evidence.lease_expiry.observed_expiry_time==observed.expires_at &&
            claim.takeover_evidence.observed_lease_version==observed.fence.lease_version &&
           claim.takeover_evidence.observed_store_revision==observed.fence.store_revision &&
           claim.takeover_evidence.proposed_takeover_generation==observed.fence.takeover_generation+1 &&
           claim.takeover_evidence.broker_reconciliation.evidence_id!="" &&
           claim.takeover_evidence.persistence_reconciliation.evidence_id!="" &&
           claim.takeover_evidence.authority!=SWV5_COMPONENT_AUTHORITY_EXECUTION &&
           claim.takeover_evidence.evidence_sequence>0 && claim.takeover_evidence.evidenced_at<=context.clock_time &&
           claim.takeover_evidence.broker_reconciliation.issuing_component==SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER &&
           claim.takeover_evidence.persistence_reconciliation.issuing_component==SWV5_COMPONENT_AUTHORITY_PERSISTENCE &&
           claim.takeover_evidence.broker_reconciliation.evidence_sequence>0 &&
           claim.takeover_evidence.persistence_reconciliation.evidence_sequence>0 &&
           claim.takeover_evidence.broker_reconciliation.observed_at<=context.clock_time &&
           claim.takeover_evidence.persistence_reconciliation.observed_at<=context.clock_time &&
           SWV5_TestOwnershipKeyEqual(claim.takeover_evidence.broker_reconciliation.persistence_namespace.ownership_namespace,observed.fence.ownership_namespace) &&
           SWV5_TestOwnershipKeyEqual(claim.takeover_evidence.persistence_reconciliation.persistence_namespace.ownership_namespace,observed.fence.ownership_namespace) &&
           SWV5_TestOwnershipKeyEqual(claim.claimant.key,observed.fence.ownership_namespace) &&
          SWV5_TestFenceEqual(claim.expected_fence,observed.fence);
}

bool SWV5_TestHeartbeatValid(const SWV5_ContractValidationContext &context,
                              const SWV5_InstanceLease &caller,
                              const SWV5_InstanceLease &observed)
{
   return SWV5_TestContextValid(context) && caller.status==SWV5_LOCK_ACQUIRED && observed.status==SWV5_LOCK_ACQUIRED &&
          caller.clock_id==context.clock_id && observed.clock_id==context.clock_id &&
           SWV5_TestFenceEqual(caller.fence,observed.fence) &&
          SWV5_TestOwnershipKeyEqual(caller.fence.ownership_namespace,observed.fence.ownership_namespace) &&
          caller.heartbeat_sequence==observed.heartbeat_sequence &&
          caller.heartbeat_clock_sequence==observed.heartbeat_clock_sequence &&
          context.clock_sequence>observed.heartbeat_clock_sequence &&
          context.clock_time>=observed.heartbeat_at && context.clock_time<observed.expires_at;
}

bool SWV5_TestIntentValid(const SWV5_ContractValidationContext &context,const SWV5_ExecutionIntent &intent)
{
   return SWV5_TestContextValid(context) && SWV5_TestVersionValid(intent.contract_version) &&
          SWV5_TestNamespaceComplete(intent.persistence_namespace) && SWV5_TestRequestIdentityComplete(intent.request_identity) &&
          intent.account_mode==SWV5_ACCOUNT_MODE_HEDGING &&
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
   confirmed_volume=pending.cumulative_confirmed_volume;
   residual_volume=pending.residual_requested_volume;
   if(!SWV5_TestNamespaceEqual(pending.intent.persistence_namespace,evidence.persistence_namespace) ||
      !SWV5_TestFenceEqual(pending.intent.ownership_fence,evidence.ownership_fence) ||
       !SWV5_TestRequestIdentityEqual(pending.intent.request_identity,evidence.correlation.request_identity) ||
       pending.account_mode!=pending.intent.account_mode || pending.account_mode!=SWV5_ACCOUNT_MODE_HEDGING ||
      evidence.expected_basket_version!=pending.intent.expected_basket_version ||
      evidence.symbol_specification_sequence!=pending.intent.symbol_specification_sequence ||
      !SWV5_TestCorrelationComplete(evidence.correlation))
      return SWV5_CONFIRMATION_CONFLICT;
   if(SWV5_TestEventIdentitySetContains(pending.accepted_event_identities,evidence.correlation.broker_identity))
      return pending.state==SWV5_REQUEST_PARTIALLY_CONFIRMED ? SWV5_CONFIRMATION_PARTIAL : SWV5_CONFIRMATION_CONFIRMED;
   confirmed_volume+=evidence.confirmed_volume;
   residual_volume=MathMax(0.0,pending.intent.normalized_volume-confirmed_volume);
   if(residual_volume>0.0000001)
      return SWV5_CONFIRMATION_PARTIAL;
   return SWV5_CONFIRMATION_CONFIRMED;
}

bool SWV5_TestDecisionEqual(const SWV5_ContractDecision &left,const SWV5_ContractDecision &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          left.disposition==right.disposition &&
          left.reason_flags==right.reason_flags &&
          left.reason_code==right.reason_code &&
          left.reason_text==right.reason_text &&
          left.evaluated_schema_version==right.evaluated_schema_version &&
          left.evaluation_sequence==right.evaluation_sequence &&
          left.evaluated_at==right.evaluated_at;
}

bool SWV5_TestIntentEqual(const SWV5_ExecutionIntent &left,const SWV5_ExecutionIntent &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestNamespaceEqual(left.persistence_namespace,right.persistence_namespace) &&
          SWV5_TestFenceEqual(left.ownership_fence,right.ownership_fence) &&
          SWV5_TestRequestIdentityEqual(left.request_identity,right.request_identity) &&
          left.account_mode==right.account_mode &&
          left.intent_type==right.intent_type &&
          left.direction==right.direction &&
          left.normalized_volume==right.normalized_volume &&
          left.normalized_price==right.normalized_price &&
          left.normalized_stop_price==right.normalized_stop_price &&
          left.normalized_limit_price==right.normalized_limit_price &&
          left.symbol_specification_sequence==right.symbol_specification_sequence &&
          left.expected_basket_version==right.expected_basket_version &&
          left.risk_authorization_id==right.risk_authorization_id &&
          left.authorization_expires_at==right.authorization_expires_at;
}

bool SWV5_TestSubmissionEqual(const SWV5_SubmissionEvidence &left,const SWV5_SubmissionEvidence &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestRequestIdentityEqual(left.request_identity,right.request_identity) &&
          left.submission_attempt_count==right.submission_attempt_count &&
          left.submitted_at==right.submitted_at &&
          left.authority==right.authority;
}

bool SWV5_TestRetcodeEvidenceEqual(const SWV5_ResultRetcodeEvidence &left,const SWV5_ResultRetcodeEvidence &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestNamespaceEqual(left.persistence_namespace,right.persistence_namespace) &&
          SWV5_TestFenceEqual(left.ownership_fence,right.ownership_fence) &&
          SWV5_TestCorrelationEqual(left.correlation,right.correlation) &&
          left.raw_retcode==right.raw_retcode &&
          left.broker_comment==right.broker_comment &&
          left.observed_at==right.observed_at;
}

bool SWV5_TestRetcodeClassificationEqual(const SWV5_ResultRetcodeClassification &left,
                                         const SWV5_ResultRetcodeClassification &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          left.classification==right.classification &&
          left.retry_disposition==right.retry_disposition &&
          left.mapping_policy_id==right.mapping_policy_id &&
          SWV5_TestDecisionEqual(left.decision,right.decision);
}

bool SWV5_TestAuthoritativeConfirmationEqual(const SWV5_AuthoritativeConfirmationEvidence &left,
                                             const SWV5_AuthoritativeConfirmationEvidence &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestCorrelationEqual(left.correlation,right.correlation) &&
          left.status==right.status &&
          left.cumulative_confirmed_volume==right.cumulative_confirmed_volume &&
          left.residual_volume==right.residual_volume &&
          left.authority==right.authority &&
          left.confirmation_sequence==right.confirmation_sequence &&
          left.confirmed_at==right.confirmed_at;
}

bool SWV5_TestEventIdentitySetEqual(const SWV5_DurableEventIdentitySet &left,
                                    const SWV5_DurableEventIdentitySet &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          left.canonical_event_index==right.canonical_event_index &&
          left.identity_set_digest==right.identity_set_digest &&
          left.accepted_identity_count==right.accepted_identity_count &&
          left.highest_transaction_sequence==right.highest_transaction_sequence &&
          left.index_revision==right.index_revision &&
          left.compaction_generation==right.compaction_generation;
}

bool SWV5_TestPendingRequestEqual(const SWV5_PendingRequest &left,const SWV5_PendingRequest &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestIntentEqual(left.intent,right.intent) &&
          left.account_mode==right.account_mode &&
          left.lifecycle_phase==right.lifecycle_phase &&
          left.state==right.state &&
          left.submission_attempt_count==right.submission_attempt_count &&
          SWV5_TestSubmissionEqual(left.latest_submission,right.latest_submission) &&
          SWV5_TestRetcodeEvidenceEqual(left.latest_retcode,right.latest_retcode) &&
          SWV5_TestRetcodeClassificationEqual(left.latest_retcode_classification,right.latest_retcode_classification) &&
          SWV5_TestAuthoritativeConfirmationEqual(left.latest_authoritative_confirmation,right.latest_authoritative_confirmation) &&
          left.cumulative_confirmed_volume==right.cumulative_confirmed_volume &&
          left.residual_requested_volume==right.residual_requested_volume &&
          SWV5_TestEventIdentitySetEqual(left.accepted_event_identities,right.accepted_event_identities) &&
          left.retry_disposition==right.retry_disposition &&
          left.authorization_identity==right.authorization_identity &&
          left.normalization_identity==right.normalization_identity &&
          left.last_changed_at==right.last_changed_at;
}

bool SWV5_TestPersistedRequestEqual(const SWV5_PersistedRequestEvidence &left,
                                    const SWV5_PersistedRequestEvidence &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestNamespaceEqual(left.persistence_namespace,right.persistence_namespace) &&
          SWV5_TestFenceEqual(left.ownership_fence,right.ownership_fence) &&
          SWV5_TestPendingRequestEqual(left.pending_request,right.pending_request) &&
          left.account_mode==right.account_mode &&
          left.record_sequence==right.record_sequence &&
          left.recorded_at==right.recorded_at;
}

bool SWV5_TestPersistedRequestValid(const SWV5_PersistedRequestEvidence &record,
                                    const SWV5_PersistenceNamespace &expected_namespace)
{
   const SWV5_PendingRequest pending=record.pending_request;
   return SWV5_TestVersionValid(record.contract_version) &&
          SWV5_TestNamespaceEqual(record.persistence_namespace,expected_namespace) &&
          SWV5_TestFenceComplete(record.ownership_fence) &&
          SWV5_TestVersionValid(pending.contract_version) &&
          SWV5_TestVersionValid(pending.intent.contract_version) &&
          SWV5_TestRequestIdentityComplete(pending.intent.request_identity) &&
          pending.intent.normalized_volume>0.0 && pending.intent.normalized_price>0.0 &&
          pending.intent.symbol_specification_sequence>0 && pending.intent.expected_basket_version>0 &&
          pending.intent.risk_authorization_id!="" && pending.intent.authorization_expires_at>0 &&
          SWV5_TestNamespaceEqual(pending.intent.persistence_namespace,expected_namespace) &&
          SWV5_TestFenceEqual(record.ownership_fence,pending.intent.ownership_fence) &&
          record.account_mode==SWV5_ACCOUNT_MODE_HEDGING &&
          pending.account_mode==record.account_mode &&
          pending.intent.account_mode==record.account_mode &&
          SWV5_TestVersionValid(pending.latest_submission.contract_version) &&
          SWV5_TestRequestIdentityEqual(pending.latest_submission.request_identity,pending.intent.request_identity) &&
          SWV5_TestVersionValid(pending.latest_retcode.contract_version) &&
          SWV5_TestNamespaceEqual(pending.latest_retcode.persistence_namespace,expected_namespace) &&
          SWV5_TestFenceEqual(pending.latest_retcode.ownership_fence,record.ownership_fence) &&
          SWV5_TestRequestIdentityEqual(pending.latest_retcode.correlation.request_identity,pending.intent.request_identity) &&
          SWV5_TestVersionValid(pending.latest_retcode_classification.contract_version) &&
          pending.latest_retcode_classification.mapping_policy_id!="" &&
          SWV5_TestVersionValid(pending.latest_authoritative_confirmation.contract_version) &&
          SWV5_TestRequestIdentityEqual(pending.latest_authoritative_confirmation.correlation.request_identity,pending.intent.request_identity) &&
           SWV5_TestEventSetIntegrityValid(pending.accepted_event_identities) &&
          pending.authorization_identity!="" && pending.normalization_identity!="" &&
          pending.last_changed_at>0 && record.record_sequence>0 && record.recorded_at>0;
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

bool SWV5_TestRequestSetValid(const SWV5_PersistenceNamespace &persistence_namespace,
                              const SWV5_PersistedRequestEvidence &requests[],
                              const SWV5_PersistedRequestSetHeader &header)
{
   if(!SWV5_TestNamespaceComplete(persistence_namespace) || !SWV5_TestVersionValid(header.contract_version) ||
      ArraySize(requests)!=(int)header.request_count || header.record_sequence==0 ||
      header.request_set_digest!=SWV5_TestRequestSetDigest(requests) ||
      header.request_index_revision!=SWV5_TestRequestSetRevision(requests,header.record_sequence))
      return false;
   ulong previous_sequence=0;
   for(int index=0;index<ArraySize(requests);index++)
   {
      if(!SWV5_TestPersistedRequestValid(requests[index],persistence_namespace) ||
         requests[index].record_sequence<=previous_sequence || requests[index].record_sequence>header.record_sequence)
         return false;
      previous_sequence=requests[index].record_sequence;
   }
   return true;
}

SWV5_ReconciliationStatus SWV5_TestRestartDisposition(const SWV5_RestartReconciliationInput &engineInput,
                                                        const SWV5_PersistedRequestEvidence &pending_requests[],
                                                        SWV5_RestartReadinessDisposition &readiness)
{
   readiness=SWV5_RESTART_HALTED;
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
   if(engineInput.persisted.pending_request_set.request_count!=engineInput.broker.pending_request_count ||
      !SWV5_TestRequestSetValid(engineInput.persistence_namespace,pending_requests,engineInput.persisted.pending_request_set))
      return SWV5_RECONCILIATION_CONFLICT_HALT;
   if(ArraySize(pending_requests)==0)
   {
      if(engineInput.persisted.has_latest_pending_request)
         return SWV5_RECONCILIATION_CONFLICT_HALT;
      if(engineInput.persisted.hard_kill_state.state==SWV5_HARD_KILL_ACTIVE ||
         engineInput.persisted.hard_kill_state.state==SWV5_HARD_KILL_RELEASE_PENDING)
      {
         readiness=SWV5_RESTART_CLOSE_ONLY;
         return SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED;
      }
      readiness=SWV5_RESTART_SAFE_TO_RESUME;
      return SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED;
   }
   if(!engineInput.persisted.has_latest_pending_request ||
      !SWV5_TestPersistedRequestEqual(engineInput.persisted.latest_pending_request,pending_requests[ArraySize(pending_requests)-1]))
      return SWV5_RECONCILIATION_CONFLICT_HALT;
   bool reconciliation_required=false;
   bool retry_forbidden=false;
   for(int index=0;index<ArraySize(pending_requests);index++)
   {
      const SWV5_PendingRequest pending=pending_requests[index].pending_request;
      if(pending_requests[index].account_mode!=engineInput.broker.account_mode ||
         !SWV5_TestNamespaceEqual(pending_requests[index].persistence_namespace,engineInput.persistence_namespace) ||
         !SWV5_TestFenceEqual(pending_requests[index].ownership_fence,engineInput.claimant_fence) ||
         !SWV5_TestRequestIdentityComplete(pending.intent.request_identity))
         return SWV5_RECONCILIATION_CONFLICT_HALT;
      const double expected_residual=MathMax(0.0,pending.intent.normalized_volume-pending.cumulative_confirmed_volume);
      if(!SWV5_TestNear(expected_residual,pending.residual_requested_volume,0.0000001))
         return SWV5_RECONCILIATION_CONFLICT_HALT;
      if(pending.lifecycle_phase==SWV5_EXECUTION_PHASE_UNCERTAIN || pending.state==SWV5_REQUEST_RECONCILIATION_REQUIRED)
         reconciliation_required=true;
      else if(pending.retry_disposition==SWV5_RETRY_FORBIDDEN && pending.state!=SWV5_REQUEST_CONFIRMED)
         retry_forbidden=true;
      else if(pending.state!=SWV5_REQUEST_CONFIRMED && pending.state!=SWV5_REQUEST_CANCELLED && pending.state!=SWV5_REQUEST_REJECTED)
         reconciliation_required=true;
   }
   if(engineInput.persisted.hard_kill_state.state==SWV5_HARD_KILL_ACTIVE ||
      engineInput.persisted.hard_kill_state.state==SWV5_HARD_KILL_RELEASE_PENDING)
      readiness=SWV5_RESTART_CLOSE_ONLY;
   else if(reconciliation_required)
      readiness=SWV5_RESTART_RECONCILIATION_REQUIRED;
   else if(retry_forbidden)
      readiness=SWV5_RESTART_RETRY_FORBIDDEN;
   else
      readiness=SWV5_RESTART_SAFE_TO_RESUME;
   return SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED;
}

bool SWV5_TestMonetaryBasisComplete(const SWV5_RiskMonetaryBasis &basis)
{
   return SWV5_TestVersionValid(basis.contract_version) && basis.currency!="" && basis.account_currency!="" &&
          basis.conversion_rate_to_account_currency>0.0 && basis.conversion_source!="" && basis.valuation_at>0 &&
          basis.calculation_basis!=SWV5_RISK_BASIS_UNDEFINED && basis.sign_convention!=SWV5_RISK_SIGN_UNDEFINED &&
          basis.includes_realized && basis.includes_unrealized && basis.includes_commission && basis.includes_swap && basis.includes_fee;
}

bool SWV5_TestAccountNamespaceEqual(const SWV5_AccountRiskNamespace &left,
                                    const SWV5_AccountRiskNamespace &right,
                                    const bool require_sequence=true)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          left.broker_identity==right.broker_identity && left.server==right.server &&
          left.account_login==right.account_login && left.account_currency==right.account_currency &&
          left.strategy_id==right.strategy_id && left.magic==right.magic &&
          left.account_mode==right.account_mode && left.authoritative_source==right.authoritative_source &&
          left.snapshot_epoch==right.snapshot_epoch && (!require_sequence || left.snapshot_sequence==right.snapshot_sequence);
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
                                     const SWV5_ExecutionIntent &intent,
                                     const SWV5_HardKillState &current_hard_kill_state)
{
   return SWV5_TestContextValid(context) && authorization.disposition==SWV5_RISK_ALLOW &&
          authorization.authorization_id!="" && authorization.authorization_id==intent.risk_authorization_id &&
          authorization.limits_contract_id!="" && authorization.authorized_limits.contract_id==authorization.limits_contract_id &&
          SWV5_TestVersionValid(authorization.authorized_limits.contract_version) &&
          authorization.evaluated_at<=context.clock_time && authorization.expires_at>=context.clock_time &&
           SWV5_TestRequestIdentityEqual(authorization.request_identity,intent.request_identity) &&
           SWV5_TestNamespaceEqual(authorization.persistence_namespace,intent.persistence_namespace) &&
           SWV5_TestFenceEqual(authorization.ownership_fence,intent.ownership_fence) &&
           authorization.account_mode==intent.account_mode && authorization.account_mode==SWV5_ACCOUNT_MODE_HEDGING &&
           authorization.account_namespace.account_mode==authorization.account_mode &&
           authorization.account_namespace.broker_identity==intent.persistence_namespace.ownership_namespace.broker_identity &&
           authorization.account_namespace.server==intent.persistence_namespace.ownership_namespace.server &&
           authorization.account_namespace.account_login==intent.persistence_namespace.ownership_namespace.account_login &&
           authorization.account_namespace.strategy_id==intent.persistence_namespace.ownership_namespace.strategy_id &&
           authorization.account_namespace.magic==intent.persistence_namespace.ownership_namespace.magic &&
          authorization.basket_state_version==intent.expected_basket_version &&
          authorization.symbol_specification_sequence==intent.symbol_specification_sequence &&
          authorization.authorized_intent_type==intent.intent_type &&
          authorization.authorized_direction==intent.direction &&
          SWV5_TestNear(authorization.authorized_volume,intent.normalized_volume,context.volume_tolerance) &&
          SWV5_TestNear(authorization.authorized_price,intent.normalized_price,context.price_tolerance) &&
          SWV5_TestNear(authorization.authorized_stop_price,intent.normalized_stop_price,context.price_tolerance) &&
          SWV5_TestNear(authorization.authorized_limit_price,intent.normalized_limit_price,context.price_tolerance) &&
            authorization.risk_snapshot_epoch>0 && authorization.risk_snapshot_epoch==authorization.account_namespace.snapshot_epoch &&
           authorization.risk_snapshot_sequence>0 && authorization.risk_snapshot_sequence==authorization.account_namespace.snapshot_sequence &&
           authorization.authorized_projected_loss>=0.0 && authorization.authorized_projected_notional>=0.0 &&
           authorization.authorized_projected_margin>=0.0 &&
           authorization.hard_kill_latch_id!="" && authorization.hard_kill_latch_generation>0 &&
           current_hard_kill_state.state==SWV5_HARD_KILL_INACTIVE &&
           SWV5_TestNamespaceEqual(current_hard_kill_state.persistence_namespace,authorization.persistence_namespace) &&
           SWV5_TestAccountNamespaceEqual(current_hard_kill_state.account_namespace,authorization.account_namespace,true) &&
           current_hard_kill_state.latch_id==authorization.hard_kill_latch_id &&
           current_hard_kill_state.latch_generation==authorization.hard_kill_latch_generation &&
           SWV5_TestMonetaryBasisComplete(authorization.monetary_basis) && authorization.reason_text!="";
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
           evidence.approving_component!=SWV5_COMPONENT_AUTHORITY_NONE &&
           evidence.approving_component!=SWV5_COMPONENT_AUTHORITY_EXECUTION &&
           evidence.broker_evidence.evidence_id!="" && evidence.broker_evidence.state_digest!="" &&
           evidence.broker_evidence.issuing_component==SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER &&
           evidence.broker_evidence.authority_source==SWV5_AUTHORITY_LIVE_BROKER_STATE &&
           evidence.broker_evidence.evidence_sequence>0 && evidence.broker_evidence.observed_at<=context.clock_time &&
           SWV5_TestNamespaceEqual(evidence.broker_evidence.persistence_namespace,evidence.persistence_namespace) &&
           evidence.persistence_evidence.evidence_id!="" && evidence.persistence_evidence.state_digest!="" &&
           evidence.persistence_evidence.issuing_component==SWV5_COMPONENT_AUTHORITY_PERSISTENCE &&
           evidence.persistence_evidence.authority_source==SWV5_AUTHORITY_PERSISTED_CHECKPOINT &&
           evidence.persistence_evidence.evidence_sequence>0 && evidence.persistence_evidence.observed_at<=context.clock_time &&
           SWV5_TestNamespaceEqual(evidence.persistence_evidence.persistence_namespace,evidence.persistence_namespace) &&
           evidence.exposure_evidence.evidence_id!="" && evidence.exposure_evidence.zero_or_reducing &&
           evidence.exposure_evidence.issuing_component==SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE &&
           evidence.exposure_evidence.evidence_sequence>0 && evidence.exposure_evidence.observed_at<=context.clock_time &&
           evidence.exposure_evidence.observed_exposure_volume>=0.0 && evidence.exposure_evidence.prior_exposure_volume>=0.0 &&
           evidence.exposure_evidence.observed_exposure_volume<=evidence.exposure_evidence.prior_exposure_volume+context.volume_tolerance &&
           evidence.audit_reference!="" &&
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
   if(evidence.prior_identity_index_revision!=state.identities.index_revision)
      return false;
   if(evidence.disposition==SWV5_STAT_IDENTITY_DUPLICATE)
      return evidence.membership_proof!="" && SWV5_TestEventIdentitySetContains(state.identities,evidence.correlation.broker_identity);
   if(evidence.disposition==SWV5_STAT_IDENTITY_NEW || evidence.disposition==SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW)
      return evidence.membership_proof=="" && SWV5_TestCorrelationComplete(evidence.correlation);
   return false;
}

double SWV5_TestDealNet(const SWV5_AuthoritativeDeal &deal)
{
   return deal.gross_profit+deal.commission+deal.swap+deal.fee;
}

#endif
