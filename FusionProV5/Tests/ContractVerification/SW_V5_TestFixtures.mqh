//+------------------------------------------------------------------+
//| TEST ONLY                                                        |
//| NOT FOR PRODUCTION                                               |
//| NO BROKER ACCESS                                                 |
//+------------------------------------------------------------------+
#ifndef SW_V5_TEST_FIXTURES_MQH
#define SW_V5_TEST_FIXTURES_MQH

#include "..\..\ProductionArchitecture\SW_V5_ProductionContracts.mqh"

const datetime SWV5_TEST_TIME=D'2026.08.05 12:00:00';

string SWV5_TestCanonicalHash(const string value);

void SWV5_TestMakeVersion(SWV5_ContractVersion &version)
{
   version.contract_name="SWV5-PRODUCTION";
   version.schema_version=SWV5_PRODUCTION_CONTRACT_VERSION;
   version.minimum_compatible_version=SWV5_PRODUCTION_MINIMUM_COMPATIBLE_VERSION;
   version.policy_id=SWV5_PRODUCTION_CONTRACT_POLICY;
}

void SWV5_TestMakeContext(SWV5_ContractValidationContext &context)
{
   SWV5_TestMakeVersion(context.expected_version);
   context.clock_id="TEST-CLOCK-1";
   context.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   context.clock_time=SWV5_TEST_TIME;
   context.clock_sequence=1000;
   context.evaluation_sequence=2000;
   context.price_tolerance=0.0000001;
   context.volume_tolerance=0.0000001;
}

void SWV5_TestMakeOwnershipKey(SWV5_OwnershipKey &key)
{
   key.account_login=700001;
   key.broker_identity="TEST-BROKER";
   key.server="TEST-SERVER";
   key.symbol="XAUUSD.TEST";
   key.strategy_id="FUSION-PRO-V5";
   key.magic=5042001;
}

void SWV5_TestMakeOwner(SWV5_OwnerIdentity &owner,const string instance_id="INSTANCE-A")
{
   SWV5_TestMakeOwnershipKey(owner.key);
   owner.instance_id=instance_id;
   owner.process_fingerprint="TEST-PROCESS-A";
   owner.started_at=SWV5_TEST_TIME-3600;
}

void SWV5_TestMakeFence(SWV5_OwnershipFence &fence)
{
   SWV5_TestMakeVersion(fence.contract_version);
   SWV5_TestMakeOwnershipKey(fence.ownership_namespace);
   SWV5_TestMakeOwner(fence.owner);
   fence.lease_version=7;
   fence.takeover_generation=2;
   fence.fencing_token_digest="FENCE-DIGEST-A";
   fence.store_revision="STORE-REV-7";
}

void SWV5_TestMakeNamespace(SWV5_PersistenceNamespace &space)
{
   SWV5_TestMakeVersion(space.contract_version);
   SWV5_TestMakeOwnershipKey(space.ownership_namespace);
   space.basket_id.value="BASKET-0001";
}

void SWV5_TestMakeRequestIdentity(SWV5_ExecutionRequestIdentity &identity)
{
   SWV5_TestMakeVersion(identity.contract_version);
   identity.request_id.correlation_id="REQ-0001";
   identity.request_id.attempt_id="ATTEMPT-0001";
   identity.request_id.parent_attempt_id="";
   identity.request_id.monotonic_sequence=300;
   identity.request_id.created_at=SWV5_TEST_TIME-60;
   identity.idempotency_key="IDEMPOTENCY-0001";
}

void SWV5_TestMakeCorrelation(SWV5_ExecutionCorrelation &correlation,const ulong transaction_sequence=400)
{
   SWV5_TestMakeVersion(correlation.contract_version);
   correlation.phase=SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION;
   SWV5_TestMakeRequestIdentity(correlation.request_identity);
   SWV5_TestMakeVersion(correlation.broker_identity.contract_version);
   correlation.broker_identity.order_ticket=5001;
   correlation.broker_identity.deal_ticket=6001;
   correlation.broker_identity.position_identifier=7001;
   correlation.broker_identity.broker_event_id="EVENT-0001";
   correlation.broker_identity.transaction_sequence=transaction_sequence;
}

void SWV5_TestMakeAccountNamespace(SWV5_AccountRiskNamespace &space,const ulong sequence=101)
{
   SWV5_TestMakeVersion(space.contract_version);
   space.broker_identity="TEST-BROKER";
   space.server="TEST-SERVER";
   space.account_login=700001;
   space.account_currency="USD";
   space.strategy_id="FUSION-PRO-V5";
   space.magic=5042001;
   space.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   space.authoritative_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
   space.snapshot_epoch=77;
   space.snapshot_sequence=sequence;
}

void SWV5_TestMakeTypedReconciliation(SWV5_TypedReconciliationEvidence &evidence,
                                      const string evidence_id,
                                      const SWV5_ComponentAuthority component)
{
   SWV5_TestMakeVersion(evidence.contract_version);
   SWV5_TestMakeNamespace(evidence.persistence_namespace);
   evidence.evidence_id=evidence_id;
   evidence.issuing_component=component;
   evidence.authority_source=(component==SWV5_COMPONENT_AUTHORITY_PERSISTENCE ? SWV5_AUTHORITY_PERSISTED_CHECKPOINT : SWV5_AUTHORITY_LIVE_BROKER_STATE);
   evidence.evidence_sequence=950;
   evidence.observed_at=SWV5_TEST_TIME-5;
   evidence.state_digest=evidence_id+"-DIGEST";
}

void SWV5_TestMakeEventIdentitySet(SWV5_DurableEventIdentitySet &set,const bool populated=false)
{
   SWV5_TestMakeVersion(set.contract_version);
   set.canonical_event_index=(populated ? "EVENT-0001|400" : "");
   set.accepted_identity_count=(populated ? 1 : 0);
   set.highest_transaction_sequence=(populated ? 400 : 0);
   set.index_revision=(populated ? 1 : 0);
   set.compaction_generation=1;
   set.identity_set_digest=SWV5_TestCanonicalHash("SWV5-EVENT-SET-V3|"+set.canonical_event_index+"|"+
                                                  IntegerToString((long)set.accepted_identity_count)+"|"+
                                                  IntegerToString((long)set.highest_transaction_sequence)+"|"+
                                                  IntegerToString((long)set.index_revision)+"|"+
                                                  IntegerToString((long)set.compaction_generation));
}

void SWV5_TestMakeQueries(SWV5_AuthoritativeQuerySet &queries,const ulong required_flags)
{
   SWV5_TestMakeVersion(queries.contract_version);
   queries.required_flags=required_flags;
   queries.completed_flags=required_flags;
   queries.authoritative_flags=required_flags;
   queries.observation_sequence=900;
}

void SWV5_TestMakeLifecycle(SWV5_BasketLifecycleSnapshot &snapshot,const SWV5_BasketState state)
{
   SWV5_TestMakeVersion(snapshot.contract_version);
   snapshot.basket_id.value="BASKET-0001";
   SWV5_TestMakeFence(snapshot.ownership_fence);
   snapshot.state=state;
   snapshot.state_version=12;
   snapshot.cumulative_recovery_attempts=3;
   snapshot.current_recovery_layer=2;
   SWV5_TestMakeEventIdentitySet(snapshot.accepted_recovery_evidence,false);
   snapshot.aggregate_open_volume=(state==SWV5_BASKET_IDLE ? 0.0 : 0.30);
   snapshot.residual_volume=(state==SWV5_BASKET_IDLE ? 0.0 : 0.20);
   snapshot.live_position_count=(state==SWV5_BASKET_IDLE ? 0 : 1);
   snapshot.live_order_count=0;
   snapshot.pending_request_count=0;
   snapshot.reconciliation_state=SWV5_RECONCILIATION_STATE_MATCHED;
   SWV5_TestMakeQueries(snapshot.broker_queries,SWV5_QUERY_POSITIONS|SWV5_QUERY_ORDERS|SWV5_QUERY_PENDING_REQUESTS);
   snapshot.state_entered_at=SWV5_TEST_TIME-120;
}

SWV5_BasketTransitionCause SWV5_TestCauseForPair(const SWV5_BasketState from_state,
                                                  const SWV5_BasketState to_state)
{
   if(from_state==to_state)
      return SWV5_TRANSITION_NONE;
   if(to_state==SWV5_BASKET_OPENING)
      return SWV5_TRANSITION_OPEN_AUTHORIZED;
   if(to_state==SWV5_BASKET_ACTIVE)
      return (from_state==SWV5_BASKET_RECOVERY ? SWV5_TRANSITION_RECOVERY_CONFIRMED : SWV5_TRANSITION_OPEN_CONFIRMED);
   if(to_state==SWV5_BASKET_RECOVERY)
      return SWV5_TRANSITION_RECOVERY_AUTHORIZED;
   if(to_state==SWV5_BASKET_CLOSING)
      return SWV5_TRANSITION_CLOSE_AUTHORIZED;
   if(to_state==SWV5_BASKET_HALTED)
   {
      if(from_state==SWV5_BASKET_ERROR)
         return SWV5_TRANSITION_RECONCILIATION_CONFIRMED;
      if(from_state==SWV5_BASKET_IDLE)
         return SWV5_TRANSITION_OPERATOR_HALT;
      return SWV5_TRANSITION_HARD_KILL;
   }
   if(to_state==SWV5_BASKET_ERROR)
      return SWV5_TRANSITION_CONTRACT_VIOLATION;
   if(to_state==SWV5_BASKET_IDLE)
      return (from_state==SWV5_BASKET_HALTED ? SWV5_TRANSITION_OPERATOR_RESET : SWV5_TRANSITION_CLOSE_CONFIRMED_EMPTY);
   return SWV5_TRANSITION_NONE;
}

void SWV5_TestMakeTransition(const SWV5_BasketLifecycleSnapshot &snapshot,
                             const SWV5_BasketState to_state,
                             SWV5_BasketTransitionRequest &request)
{
   SWV5_TestMakeVersion(request.contract_version);
   request.basket_id=snapshot.basket_id;
   request.ownership_fence=snapshot.ownership_fence;
   request.from_state=snapshot.state;
   request.to_state=to_state;
   request.cause=SWV5_TestCauseForPair(snapshot.state,to_state);
   request.expected_state_version=snapshot.state_version;
   SWV5_TestMakeCorrelation(request.correlation);
   SWV5_TestMakeVersion(request.recovery_evidence.contract_version);
   request.recovery_evidence.request_identity=request.correlation.request_identity;
   request.recovery_evidence.prior_cumulative_recovery_attempts=snapshot.cumulative_recovery_attempts;
   request.recovery_evidence.proposed_cumulative_recovery_attempts=snapshot.cumulative_recovery_attempts;
   request.recovery_evidence.prior_recovery_layer=snapshot.current_recovery_layer;
   request.recovery_evidence.proposed_recovery_layer=snapshot.current_recovery_layer;
   request.recovery_evidence.authorization_id="";
   request.recovery_evidence.evidence_identity="";
   request.recovery_evidence.evidence_sequence=0;
   request.recovery_evidence.evidenced_at=0;
   if(snapshot.state==SWV5_BASKET_ACTIVE && to_state==SWV5_BASKET_RECOVERY)
   {
      request.recovery_evidence.proposed_cumulative_recovery_attempts=snapshot.cumulative_recovery_attempts+1;
      request.recovery_evidence.proposed_recovery_layer=snapshot.current_recovery_layer+1;
      request.recovery_evidence.authorization_id="RECOVERY-AUTH-0001";
      request.recovery_evidence.evidence_identity="RECOVERY-EVIDENCE-0001";
      request.recovery_evidence.evidence_sequence=901;
      request.recovery_evidence.evidenced_at=SWV5_TEST_TIME;
   }
   request.evidence_time=SWV5_TEST_TIME;
   SWV5_TestMakeVersion(request.risk_decision.contract_version);
   request.risk_decision.disposition=SWV5_DISPOSITION_ALLOW;
   request.risk_decision.reason_flags=0;
   request.risk_decision.reason_code="TEST-RISK-ALLOW";
   request.risk_decision.reason_text="deterministic fixture";
   request.risk_decision.evaluated_schema_version=SWV5_PRODUCTION_CONTRACT_VERSION;
   request.risk_decision.evaluation_sequence=2000;
   request.risk_decision.evaluated_at=SWV5_TEST_TIME;
   request.reconciliation_state=SWV5_RECONCILIATION_STATE_MATCHED;
   request.residual_volume=snapshot.residual_volume;
   request.live_position_count=snapshot.live_position_count;
   request.live_order_count=snapshot.live_order_count;
   request.pending_request_count=snapshot.pending_request_count;
   request.broker_queries=snapshot.broker_queries;
   request.confirmation_authority=SWV5_AUTHORITY_TRANSACTION_EVENT;
   if(to_state==SWV5_BASKET_IDLE)
   {
      request.residual_volume=0.0;
      request.live_position_count=0;
      request.live_order_count=0;
      request.pending_request_count=0;
   }
   if(snapshot.state==SWV5_BASKET_IDLE && to_state==SWV5_BASKET_OPENING)
   {
      request.residual_volume=0.0;
      request.live_position_count=0;
      request.live_order_count=0;
      request.pending_request_count=0;
   }
   if(snapshot.state==SWV5_BASKET_HALTED && to_state==SWV5_BASKET_CLOSING)
   {
      request.residual_volume=0.20;
      request.live_position_count=1;
   }
}

void SWV5_TestMakeIntent(SWV5_ExecutionIntent &intent)
{
   SWV5_TestMakeVersion(intent.contract_version);
   SWV5_TestMakeNamespace(intent.persistence_namespace);
   SWV5_TestMakeFence(intent.ownership_fence);
   SWV5_TestMakeRequestIdentity(intent.request_identity);
   intent.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   intent.intent_type=SWV5_INTENT_OPEN;
   intent.direction=1;
   intent.normalized_volume=0.10;
   intent.normalized_price=2400.0;
   intent.normalized_stop_price=2390.0;
   intent.normalized_limit_price=2420.0;
   intent.symbol_specification_sequence=50;
   intent.expected_basket_version=12;
   intent.risk_authorization_id="RISK-AUTH-0001";
   intent.authorization_expires_at=SWV5_TEST_TIME+300;
}

void SWV5_TestMakeHardKill(SWV5_HardKillState &state,const SWV5_HardKillLatchState latch_state)
{
   SWV5_TestMakeVersion(state.contract_version);
   SWV5_TestMakeNamespace(state.persistence_namespace);
   SWV5_TestMakeAccountNamespace(state.account_namespace);
   state.latch_id="HARD-KILL-0001";
   state.latch_generation=4;
   state.state=latch_state;
   state.activation_reason=(latch_state==SWV5_HARD_KILL_ACTIVE ? "TEST-LIMIT" : "");
   state.activated_at=SWV5_TEST_TIME-300;
   state.activation_authority="RISK-CONTRACT";
   state.release_generation=0;
   SWV5_TestMakeVersion(state.release_evidence.contract_version);
   state.release_evidence.persistence_namespace=state.persistence_namespace;
   state.release_evidence.release_id="";
   state.release_evidence.latch_id=state.latch_id;
   state.release_evidence.latch_generation=state.latch_generation;
   state.release_evidence.release_generation=0;
   state.release_evidence.operator_identity.operator_id="";
   state.release_evidence.operator_identity.authority_role="";
   state.release_evidence.operator_identity.authentication_reference="";
   state.release_evidence.operator_identity.authenticated_at=0;
   state.release_evidence.approving_component=SWV5_COMPONENT_AUTHORITY_NONE;
   SWV5_TestMakeTypedReconciliation(state.release_evidence.broker_evidence,"",SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER);
   SWV5_TestMakeTypedReconciliation(state.release_evidence.persistence_evidence,"",SWV5_COMPONENT_AUTHORITY_PERSISTENCE);
   SWV5_TestMakeVersion(state.release_evidence.exposure_evidence.contract_version);
   state.release_evidence.exposure_evidence.evidence_id="";
   state.release_evidence.exposure_evidence.issuing_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
   state.release_evidence.exposure_evidence.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
   state.release_evidence.exposure_evidence.observed_exposure_volume=0.0;
   state.release_evidence.exposure_evidence.prior_exposure_volume=0.0;
   state.release_evidence.exposure_evidence.zero_or_reducing=false;
   state.release_evidence.exposure_evidence.evidence_sequence=0;
   state.release_evidence.exposure_evidence.observed_at=0;
   state.release_evidence.approved_at=0;
   state.release_evidence.expires_at=0;
   state.release_evidence.audit_reference="";
}

void SWV5_TestMakeSymbolSpecification(SWV5_SymbolUnitSpecification &specification)
{
   SWV5_TestMakeVersion(specification.contract_version);
   specification.symbol="XAUUSD.TEST";
   specification.specification_sequence=50;
   specification.digits=2;
   specification.point_size=0.01;
   specification.tick_size=0.05;
   specification.pip_size=0.10;
   specification.tick_value_profit=1.0;
   specification.tick_value_loss=1.0;
   specification.contract_size=100.0;
   specification.tick_value_basis_volume=1.0;
   specification.volume_minimum=0.01;
   specification.volume_maximum=100.0;
   specification.volume_step=0.01;
   specification.stops_level_points=100;
   specification.freeze_level_points=50;
   specification.account_currency="USD";
   specification.tick_value_currency="USD";
   specification.observed_at=SWV5_TEST_TIME-10;
   specification.valid_until=SWV5_TEST_TIME+300;
   specification.complete=true;
}

void SWV5_TestMakeUnitRequest(SWV5_UnitNormalizationRequest &request)
{
   SWV5_TestMakeVersion(request.contract_version);
   SWV5_TestMakeNamespace(request.persistence_namespace);
   SWV5_TestMakeFence(request.ownership_fence);
   request.purpose=SWV5_PRICE_ENTRY;
   request.operation_kind=SWV5_OPERATION_MARKET_ENTRY;
   request.direction=1;
   request.raw_price=2400.03;
   request.raw_stop_price=2398.50;
   request.raw_limit_price=2420.00;
   request.raw_volume=0.015;
   request.reference_market_price=2400.00;
   request.operation_price=2400.03;
   request.market_bid=2399.95;
   request.market_ask=2400.00;
   request.expected_specification_sequence=50;
   request.exposure_increasing=true;
   request.protective_operation=false;
}

void SWV5_TestMakeMonetaryBasis(SWV5_RiskMonetaryBasis &basis)
{
   SWV5_TestMakeVersion(basis.contract_version);
   basis.currency="USD";
   basis.account_currency="USD";
   basis.conversion_rate_to_account_currency=1.0;
   basis.conversion_source="TEST-FIXTURE";
   basis.valuation_at=SWV5_TEST_TIME;
   basis.calculation_basis=SWV5_RISK_BASIS_PROTECTIVE_STOP;
   basis.sign_convention=SWV5_RISK_LOSS_POSITIVE;
   basis.includes_realized=true;
   basis.includes_unrealized=true;
   basis.includes_commission=true;
   basis.includes_swap=true;
   basis.includes_fee=true;
}

void SWV5_TestMakeRiskAuthorization(SWV5_RiskAuthorization &authorization)
{
   SWV5_TestMakeVersion(authorization.contract_version);
   authorization.authorization_id="RISK-AUTH-0001";
   authorization.limits_contract_id="RISK-LIMITS-V1";
   SWV5_TestMakeVersion(authorization.authorized_limits.contract_version);
   authorization.authorized_limits.contract_id=authorization.limits_contract_id;
   authorization.authorized_limits.maximum_snapshot_age_seconds=60;
   authorization.authorized_limits.maximum_cumulative_recovery_attempts=5;
   SWV5_TestMakeRequestIdentity(authorization.request_identity);
   SWV5_TestMakeNamespace(authorization.persistence_namespace);
   SWV5_TestMakeFence(authorization.ownership_fence);
   SWV5_TestMakeAccountNamespace(authorization.account_namespace);
   authorization.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   authorization.disposition=SWV5_RISK_ALLOW;
   authorization.blocking_domain=SWV5_RISK_DOMAIN_NONE;
   authorization.reason_flags=0;
   authorization.basket_state_version=12;
   authorization.symbol_specification_sequence=50;
   authorization.authorized_intent_type=SWV5_INTENT_OPEN;
   authorization.authorized_direction=1;
   authorization.authorized_volume=0.10;
   authorization.authorized_price=2400.0;
   authorization.authorized_stop_price=2390.0;
   authorization.authorized_limit_price=2420.0;
   authorization.risk_snapshot_epoch=77;
   authorization.risk_snapshot_sequence=101;
   authorization.authorized_projected_loss=125.0;
   authorization.authorized_projected_notional=240.0;
   authorization.authorized_projected_margin=24.0;
   authorization.hard_kill_latch_id="HARD-KILL-0001";
   authorization.hard_kill_latch_generation=4;
   SWV5_TestMakeMonetaryBasis(authorization.monetary_basis);
   authorization.evaluated_at=SWV5_TEST_TIME;
   authorization.expires_at=SWV5_TEST_TIME+300;
   authorization.reason_text="TEST-ALLOW";
}

void SWV5_TestMakeRiskInput(SWV5_RiskEvaluationInput &engineInput)
{
   SWV5_TestMakeVersion(engineInput.contract_version);
   SWV5_TestMakeIntent(engineInput.intent);
   SWV5_TestMakeAccountNamespace(engineInput.account_namespace);
   engineInput.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   SWV5_TestMakeVersion(engineInput.limits.contract_version);
   engineInput.limits.contract_id="RISK-LIMITS-V3";
   engineInput.limits.minimum_equity=9000.0;
   engineInput.limits.maximum_daily_net_loss=500.0;
   engineInput.limits.maximum_account_margin_fraction=0.50;
   engineInput.limits.maximum_basket_loss=300.0;
   engineInput.limits.maximum_basket_volume=1.0;
   engineInput.limits.maximum_symbol_volume=2.0;
   engineInput.limits.maximum_aggregate_volume=5.0;
   engineInput.limits.maximum_aggregate_notional=100000.0;
   engineInput.limits.maximum_live_baskets=10;
   engineInput.limits.maximum_snapshot_age_seconds=60;
   engineInput.limits.maximum_cumulative_recovery_attempts=5;
   SWV5_TestMakeVersion(engineInput.account.contract_version);
   engineInput.account.account_namespace=engineInput.account_namespace;
   engineInput.account.balance=10000.0;
   engineInput.account.equity=10000.0;
   engineInput.account.margin=100.0;
   engineInput.account.free_margin=9900.0;
   engineInput.account.daily_realized_net=0.0;
   engineInput.account.daily_unrealized_net=0.0;
   engineInput.account.trading_day_start=SWV5_TEST_TIME-3600;
   engineInput.account.observed_at=SWV5_TEST_TIME;
   engineInput.account.authoritative=true;
   SWV5_TestMakeVersion(engineInput.exposure.contract_version);
   engineInput.exposure.account_namespace=engineInput.account_namespace;
   engineInput.exposure.symbol="XAUUSD.TEST";
   engineInput.exposure.aggregate_volume=0.30;
   engineInput.exposure.aggregate_notional=720.0;
   engineInput.exposure.observed_at=SWV5_TEST_TIME;
   engineInput.exposure.complete=true;
   SWV5_TestMakeVersion(engineInput.basket.contract_version);
   engineInput.basket.account_namespace=engineInput.account_namespace;
   SWV5_TestMakeLifecycle(engineInput.basket.lifecycle,SWV5_BASKET_ACTIVE);
   engineInput.basket.observed_at=SWV5_TEST_TIME;
   SWV5_TestMakeVersion(engineInput.projected.contract_version);
   engineInput.projected.account_namespace=engineInput.account_namespace;
   engineInput.projected.symbol="XAUUSD.TEST";
   engineInput.projected.projected_volume=0.10;
   engineInput.projected.projected_symbol_volume=0.40;
   engineInput.projected.projected_aggregate_volume=0.40;
   engineInput.projected.projected_notional=240.0;
   engineInput.projected.projected_margin=24.0;
   engineInput.projected.projected_maximum_loss=125.0;
   SWV5_TestMakeMonetaryBasis(engineInput.projected.monetary_basis);
   engineInput.projected.calculated_at=SWV5_TEST_TIME;
   engineInput.projected.complete=true;
   engineInput.ownership_fence=engineInput.intent.ownership_fence;
   SWV5_TestMakeHardKill(engineInput.hard_kill_state,SWV5_HARD_KILL_INACTIVE);
   engineInput.hard_kill_state.account_namespace=engineInput.account_namespace;
}

void SWV5_TestMakeValidHardKillRelease(SWV5_HardKillState &state)
{
   SWV5_TestMakeHardKill(state,SWV5_HARD_KILL_RELEASE_PENDING);
   state.release_evidence.release_id="RELEASE-0001";
   state.release_evidence.release_generation=state.release_generation+1;
   state.release_evidence.operator_identity.operator_id="RISK-OFFICER-1";
   state.release_evidence.operator_identity.authority_role="INDEPENDENT-RISK";
   state.release_evidence.operator_identity.authentication_reference="AUTH-REF-1";
   state.release_evidence.operator_identity.authenticated_at=SWV5_TEST_TIME-30;
   state.release_evidence.approving_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
   SWV5_TestMakeTypedReconciliation(state.release_evidence.broker_evidence,"BROKER-RELEASE-1",SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER);
   SWV5_TestMakeTypedReconciliation(state.release_evidence.persistence_evidence,"STORE-RELEASE-1",SWV5_COMPONENT_AUTHORITY_PERSISTENCE);
   state.release_evidence.exposure_evidence.evidence_id="EXPOSURE-RELEASE-1";
   state.release_evidence.exposure_evidence.issuing_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
   state.release_evidence.exposure_evidence.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
   state.release_evidence.exposure_evidence.observed_exposure_volume=0.0;
   state.release_evidence.exposure_evidence.prior_exposure_volume=0.10;
   state.release_evidence.exposure_evidence.zero_or_reducing=true;
   state.release_evidence.exposure_evidence.evidence_sequence=952;
   state.release_evidence.exposure_evidence.observed_at=SWV5_TEST_TIME-5;
   state.release_evidence.approved_at=SWV5_TEST_TIME-10;
   state.release_evidence.expires_at=SWV5_TEST_TIME+60;
   state.release_evidence.audit_reference="AUDIT-RELEASE-0001";
}

void SWV5_TestMakeDeal(SWV5_AuthoritativeDeal &deal,const SWV5_DealEntryKind entry_kind=SWV5_DEAL_ENTRY_OUT)
{
   SWV5_TestMakeVersion(deal.contract_version);
   SWV5_TestMakeNamespace(deal.persistence_namespace);
   SWV5_TestMakeCorrelation(deal.correlation);
   deal.entry_kind=entry_kind;
   deal.direction=-1;
   deal.volume=0.10;
   deal.price=2410.0;
   deal.gross_profit=100.0;
   deal.commission=-2.0;
   deal.swap=-1.0;
   deal.fee=-0.5;
   deal.account_currency="USD";
   deal.monetary_components_complete=true;
   deal.deal_time=SWV5_TEST_TIME;
   deal.authority=SWV5_AUTHORITY_DEAL_HISTORY;
}

void SWV5_TestMakeAggregate(SWV5_BasketAggregate &basket,const SWV5_BasketState state=SWV5_BASKET_ACTIVE)
{
   SWV5_TestMakeVersion(basket.contract_version);
   SWV5_TestMakeNamespace(basket.persistence_namespace);
   basket.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   SWV5_TestMakeLifecycle(basket.lifecycle,state);
   basket.initial_volume=0.30;
   basket.aggregate_closed_volume=0.10;
   basket.close_verification=(state==SWV5_BASKET_IDLE ? SWV5_CLOSE_ZERO_RESIDUAL_CONFIRMED : SWV5_CLOSE_NOT_REQUESTED);
   basket.opened_at=SWV5_TEST_TIME-600;
   basket.updated_at=SWV5_TEST_TIME;
}

void SWV5_TestMakePartialClose(const SWV5_BasketAggregate &basket,SWV5_PartialCloseEvidence &evidence)
{
   SWV5_TestMakeVersion(evidence.contract_version);
   evidence.persistence_namespace=basket.persistence_namespace;
   evidence.ownership_fence=basket.lifecycle.ownership_fence;
   SWV5_TestMakeCorrelation(evidence.correlation);
   evidence.volume_before=0.30;
   evidence.closed_volume=0.10;
   evidence.residual_volume=0.20;
   evidence.confirmed_at=SWV5_TEST_TIME;
   evidence.authority=SWV5_AUTHORITY_TRANSACTION_EVENT;
}

void SWV5_TestMakeCloseEvidence(const SWV5_BasketAggregate &basket,SWV5_CloseVerificationEvidence &evidence)
{
   SWV5_TestMakeVersion(evidence.contract_version);
   evidence.persistence_namespace=basket.persistence_namespace;
   evidence.ownership_fence=basket.lifecycle.ownership_fence;
   evidence.state=SWV5_CLOSE_ZERO_RESIDUAL_CONFIRMED;
   evidence.broker_residual_volume=0.0;
   evidence.broker_position_count=0;
   evidence.broker_order_count=0;
   evidence.pending_request_count=0;
   SWV5_TestMakeQueries(evidence.broker_queries,SWV5_QUERY_POSITIONS|SWV5_QUERY_ORDERS|SWV5_QUERY_PENDING_REQUESTS);
   evidence.verified_at=SWV5_TEST_TIME;
   evidence.authority=SWV5_AUTHORITY_LIVE_BROKER_STATE;
}

void SWV5_TestMakeLease(SWV5_InstanceLease &lease,const SWV5_InstanceLockStatus status=SWV5_LOCK_ACQUIRED)
{
   SWV5_TestMakeVersion(lease.contract_version);
   SWV5_TestMakeFence(lease.fence);
   lease.status=status;
   lease.heartbeat_sequence=20;
   lease.clock_id="TEST-CLOCK-1";
   lease.acquired_clock_sequence=800;
   lease.heartbeat_clock_sequence=900;
   lease.expiry_clock_sequence=1100;
   lease.acquired_at=SWV5_TEST_TIME-300;
   lease.heartbeat_at=SWV5_TEST_TIME-60;
   lease.expires_at=SWV5_TEST_TIME+60;
}

void SWV5_TestMakeClaim(SWV5_OwnershipClaim &claim,const SWV5_InstanceLease &observed)
{
   SWV5_TestMakeVersion(claim.contract_version);
   SWV5_TestMakeOwner(claim.claimant,"INSTANCE-B");
   claim.expected_fence=observed.fence;
   claim.lease_duration_seconds=120;
   SWV5_TestMakeVersion(claim.takeover_evidence.contract_version);
   SWV5_TestMakeTypedReconciliation(claim.takeover_evidence.broker_reconciliation,"BROKER-RECON-1",SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER);
   SWV5_TestMakeTypedReconciliation(claim.takeover_evidence.persistence_reconciliation,"STORE-RECON-1",SWV5_COMPONENT_AUTHORITY_PERSISTENCE);
   SWV5_TestMakeVersion(claim.takeover_evidence.lease_expiry.contract_version);
   claim.takeover_evidence.lease_expiry.observed_ownership_key=observed.fence.ownership_namespace;
   claim.takeover_evidence.lease_expiry.clock_id="TEST-CLOCK-1";
   claim.takeover_evidence.lease_expiry.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   claim.takeover_evidence.lease_expiry.observed_clock_sequence=1200;
   claim.takeover_evidence.lease_expiry.observed_at=SWV5_TEST_TIME;
   claim.takeover_evidence.lease_expiry.observed_lease_version=observed.fence.lease_version;
   claim.takeover_evidence.lease_expiry.observed_heartbeat_sequence=observed.heartbeat_sequence;
   claim.takeover_evidence.lease_expiry.observed_store_revision=observed.fence.store_revision;
   claim.takeover_evidence.lease_expiry.observed_expiry_time=observed.expires_at;
   claim.takeover_evidence.lease_expiry.expired=true;
   claim.takeover_evidence.observed_lease_version=observed.fence.lease_version;
   claim.takeover_evidence.observed_store_revision=observed.fence.store_revision;
   claim.takeover_evidence.proposed_takeover_generation=observed.fence.takeover_generation+1;
   claim.takeover_evidence.authority=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
   claim.takeover_evidence.evidence_sequence=951;
   claim.takeover_evidence.evidenced_at=SWV5_TEST_TIME;
}

void SWV5_TestMakePending(SWV5_PendingRequest &pending)
{
   SWV5_TestMakeVersion(pending.contract_version);
   SWV5_TestMakeIntent(pending.intent);
   pending.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   pending.lifecycle_phase=SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT;
   pending.state=SWV5_REQUEST_CONFIRMATION_PENDING;
   pending.submission_attempt_count=1;
   SWV5_TestMakeVersion(pending.latest_submission.contract_version);
   pending.latest_submission.request_identity=pending.intent.request_identity;
   pending.latest_submission.submission_attempt_count=1;
   pending.latest_submission.submitted_at=SWV5_TEST_TIME-10;
   pending.latest_submission.authority=SWV5_AUTHORITY_TRANSACTION_EVENT;
   SWV5_TestMakeVersion(pending.latest_retcode.contract_version);
   pending.latest_retcode.persistence_namespace=pending.intent.persistence_namespace;
   pending.latest_retcode.ownership_fence=pending.intent.ownership_fence;
   SWV5_TestMakeCorrelation(pending.latest_retcode.correlation);
   pending.latest_retcode.correlation.phase=SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT;
   pending.latest_retcode.raw_retcode=1;
   pending.latest_retcode.broker_comment="TEST-ACK";
   pending.latest_retcode.observed_at=SWV5_TEST_TIME;
   SWV5_TestMakeVersion(pending.latest_retcode_classification.contract_version);
   pending.latest_retcode_classification.classification=SWV5_RETCODE_ACCEPTED_PENDING_CONFIRMATION;
   pending.latest_retcode_classification.retry_disposition=SWV5_RETRY_FORBIDDEN;
   pending.latest_retcode_classification.mapping_policy_id="TEST-RETCODE-MAP-V1";
   SWV5_TestMakeVersion(pending.latest_retcode_classification.decision.contract_version);
   pending.latest_retcode_classification.decision.disposition=SWV5_DISPOSITION_DENY;
   pending.latest_retcode_classification.decision.reason_flags=1;
   pending.latest_retcode_classification.decision.reason_code="AWAIT_AUTHORITATIVE_CONFIRMATION";
   pending.latest_retcode_classification.decision.reason_text="AWAIT_AUTHORITATIVE_CONFIRMATION";
   pending.latest_retcode_classification.decision.evaluated_schema_version=SWV5_PRODUCTION_CONTRACT_VERSION;
   pending.latest_retcode_classification.decision.evaluation_sequence=2000;
   pending.latest_retcode_classification.decision.evaluated_at=SWV5_TEST_TIME;
   SWV5_TestMakeVersion(pending.latest_authoritative_confirmation.contract_version);
   SWV5_TestMakeCorrelation(pending.latest_authoritative_confirmation.correlation);
   pending.latest_authoritative_confirmation.status=SWV5_CONFIRMATION_NOT_STARTED;
   pending.latest_authoritative_confirmation.cumulative_confirmed_volume=0.0;
   pending.latest_authoritative_confirmation.residual_volume=0.10;
   pending.latest_authoritative_confirmation.authority=SWV5_AUTHORITY_NONE;
   pending.latest_authoritative_confirmation.confirmation_sequence=0;
   pending.latest_authoritative_confirmation.confirmed_at=0;
   pending.cumulative_confirmed_volume=0.0;
   pending.residual_requested_volume=0.10;
   SWV5_TestMakeEventIdentitySet(pending.accepted_event_identities,false);
   pending.retry_disposition=SWV5_RETRY_FORBIDDEN;
   pending.authorization_identity=pending.intent.risk_authorization_id;
   pending.normalization_identity="NORMALIZATION-50-2400.00-0.10";
   pending.last_changed_at=SWV5_TEST_TIME;
}

void SWV5_TestMakePersistedRequest(SWV5_PersistedRequestEvidence &record,const int ordinal=1)
{
   SWV5_TestMakeVersion(record.contract_version);
   SWV5_TestMakeNamespace(record.persistence_namespace);
   SWV5_TestMakeFence(record.ownership_fence);
   SWV5_TestMakePending(record.pending_request);
   const string suffix=StringFormat("%04d",ordinal);
   record.pending_request.intent.request_identity.request_id.correlation_id="REQ-"+suffix;
   record.pending_request.intent.request_identity.request_id.attempt_id="ATTEMPT-"+suffix;
   record.pending_request.intent.request_identity.request_id.monotonic_sequence=300+(ulong)ordinal;
   record.pending_request.intent.request_identity.idempotency_key="IDEMPOTENCY-"+suffix;
   record.pending_request.latest_submission.request_identity=record.pending_request.intent.request_identity;
   record.pending_request.latest_retcode.correlation.request_identity=record.pending_request.intent.request_identity;
   record.pending_request.latest_authoritative_confirmation.correlation.request_identity=record.pending_request.intent.request_identity;
   record.pending_request.authorization_identity="RISK-AUTH-"+suffix;
   record.pending_request.intent.risk_authorization_id=record.pending_request.authorization_identity;
   record.pending_request.normalization_identity="NORMALIZATION-"+suffix;
   record.pending_request.last_changed_at=SWV5_TEST_TIME+ordinal;
   record.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   record.record_sequence=20+(ulong)ordinal;
   record.recorded_at=SWV5_TEST_TIME+ordinal;
}

string SWV5_TestCanonicalHash(const string value)
{
   ulong hash=1469598103934665603;
   for(int index=0;index<StringLen(value);index++)
   {
      hash^=(ulong)StringGetCharacter(value,index);
      hash*=1099511628211;
   }
   return StringFormat("%I64u",hash);
}

string SWV5_TestCanonicalVersion(const SWV5_ContractVersion &value)
{
   return value.contract_name+"|"+IntegerToString((long)value.schema_version)+"|"+
          IntegerToString((long)value.minimum_compatible_version)+"|"+value.policy_id;
}

string SWV5_TestCanonicalOwnershipKey(const SWV5_OwnershipKey &value)
{
   return IntegerToString(value.account_login)+"|"+value.broker_identity+"|"+value.server+"|"+
          value.symbol+"|"+value.strategy_id+"|"+IntegerToString((long)value.magic);
}

string SWV5_TestCanonicalOwner(const SWV5_OwnerIdentity &value)
{
   return SWV5_TestCanonicalOwnershipKey(value.key)+"|"+value.instance_id+"|"+
          value.process_fingerprint+"|"+IntegerToString((long)value.started_at);
}

string SWV5_TestCanonicalFence(const SWV5_OwnershipFence &value)
{
   return SWV5_TestCanonicalVersion(value.contract_version)+"|"+SWV5_TestCanonicalOwnershipKey(value.ownership_namespace)+"|"+
          SWV5_TestCanonicalOwner(value.owner)+"|"+IntegerToString((long)value.lease_version)+"|"+
          IntegerToString((long)value.takeover_generation)+"|"+value.fencing_token_digest+"|"+value.store_revision;
}

string SWV5_TestCanonicalNamespace(const SWV5_PersistenceNamespace &value)
{
   return SWV5_TestCanonicalVersion(value.contract_version)+"|"+SWV5_TestCanonicalOwnershipKey(value.ownership_namespace)+"|"+value.basket_id.value;
}

string SWV5_TestCanonicalRequestIdentity(const SWV5_ExecutionRequestIdentity &value)
{
   return SWV5_TestCanonicalVersion(value.contract_version)+"|"+value.request_id.correlation_id+"|"+
          value.request_id.attempt_id+"|"+value.request_id.parent_attempt_id+"|"+
          IntegerToString((long)value.request_id.monotonic_sequence)+"|"+IntegerToString((long)value.request_id.created_at)+"|"+
          value.idempotency_key;
}

string SWV5_TestCanonicalBrokerIdentity(const SWV5_BrokerExecutionIdentity &value)
{
   return SWV5_TestCanonicalVersion(value.contract_version)+"|"+IntegerToString((long)value.order_ticket)+"|"+
          IntegerToString((long)value.deal_ticket)+"|"+IntegerToString((long)value.position_identifier)+"|"+
          value.broker_event_id+"|"+IntegerToString((long)value.transaction_sequence);
}

string SWV5_TestCanonicalCorrelation(const SWV5_ExecutionCorrelation &value)
{
   return SWV5_TestCanonicalVersion(value.contract_version)+"|"+IntegerToString((long)value.phase)+"|"+
          SWV5_TestCanonicalRequestIdentity(value.request_identity)+"|"+SWV5_TestCanonicalBrokerIdentity(value.broker_identity);
}

string SWV5_TestCanonicalDecision(const SWV5_ContractDecision &value)
{
   return SWV5_TestCanonicalVersion(value.contract_version)+"|"+IntegerToString((long)value.disposition)+"|"+
          IntegerToString((long)value.reason_flags)+"|"+value.reason_code+"|"+value.reason_text+"|"+
          IntegerToString((long)value.evaluated_schema_version)+"|"+IntegerToString((long)value.evaluation_sequence)+"|"+
          IntegerToString((long)value.evaluated_at);
}

string SWV5_TestCanonicalIntent(const SWV5_ExecutionIntent &value)
{
   return SWV5_TestCanonicalVersion(value.contract_version)+"|"+SWV5_TestCanonicalNamespace(value.persistence_namespace)+"|"+
          SWV5_TestCanonicalFence(value.ownership_fence)+"|"+SWV5_TestCanonicalRequestIdentity(value.request_identity)+"|"+
          IntegerToString((long)value.account_mode)+"|"+IntegerToString((long)value.intent_type)+"|"+IntegerToString(value.direction)+"|"+
          DoubleToString(value.normalized_volume,8)+"|"+DoubleToString(value.normalized_price,8)+"|"+
          DoubleToString(value.normalized_stop_price,8)+"|"+DoubleToString(value.normalized_limit_price,8)+"|"+
          IntegerToString((long)value.symbol_specification_sequence)+"|"+IntegerToString((long)value.expected_basket_version)+"|"+
          value.risk_authorization_id+"|"+IntegerToString((long)value.authorization_expires_at);
}

string SWV5_TestCanonicalEventSet(const SWV5_DurableEventIdentitySet &value)
{
   return SWV5_TestCanonicalVersion(value.contract_version)+"|"+value.canonical_event_index+"|"+value.identity_set_digest+"|"+
          IntegerToString((long)value.accepted_identity_count)+"|"+IntegerToString((long)value.highest_transaction_sequence)+"|"+
          IntegerToString((long)value.index_revision)+"|"+IntegerToString((long)value.compaction_generation);
}

string SWV5_TestCanonicalPending(const SWV5_PendingRequest &value)
{
   string text=SWV5_TestCanonicalVersion(value.contract_version)+"|"+SWV5_TestCanonicalIntent(value.intent)+"|"+
               IntegerToString((long)value.account_mode)+"|"+IntegerToString((long)value.lifecycle_phase)+"|"+
               IntegerToString((long)value.state)+"|"+IntegerToString((long)value.submission_attempt_count);
   text+="|"+SWV5_TestCanonicalVersion(value.latest_submission.contract_version)+"|"+
         SWV5_TestCanonicalRequestIdentity(value.latest_submission.request_identity)+"|"+
         IntegerToString((long)value.latest_submission.submission_attempt_count)+"|"+
         IntegerToString((long)value.latest_submission.submitted_at)+"|"+IntegerToString((long)value.latest_submission.authority);
   text+="|"+SWV5_TestCanonicalVersion(value.latest_retcode.contract_version)+"|"+
         SWV5_TestCanonicalNamespace(value.latest_retcode.persistence_namespace)+"|"+SWV5_TestCanonicalFence(value.latest_retcode.ownership_fence)+"|"+
         SWV5_TestCanonicalCorrelation(value.latest_retcode.correlation)+"|"+IntegerToString((long)value.latest_retcode.raw_retcode)+"|"+
         value.latest_retcode.broker_comment+"|"+IntegerToString((long)value.latest_retcode.observed_at);
   text+="|"+SWV5_TestCanonicalVersion(value.latest_retcode_classification.contract_version)+"|"+
         IntegerToString((long)value.latest_retcode_classification.classification)+"|"+
         IntegerToString((long)value.latest_retcode_classification.retry_disposition)+"|"+
         value.latest_retcode_classification.mapping_policy_id+"|"+SWV5_TestCanonicalDecision(value.latest_retcode_classification.decision);
   text+="|"+SWV5_TestCanonicalVersion(value.latest_authoritative_confirmation.contract_version)+"|"+
         SWV5_TestCanonicalCorrelation(value.latest_authoritative_confirmation.correlation)+"|"+
         IntegerToString((long)value.latest_authoritative_confirmation.status)+"|"+
         DoubleToString(value.latest_authoritative_confirmation.cumulative_confirmed_volume,8)+"|"+
         DoubleToString(value.latest_authoritative_confirmation.residual_volume,8)+"|"+
         IntegerToString((long)value.latest_authoritative_confirmation.authority)+"|"+
         IntegerToString((long)value.latest_authoritative_confirmation.confirmation_sequence)+"|"+
         IntegerToString((long)value.latest_authoritative_confirmation.confirmed_at);
   text+="|"+DoubleToString(value.cumulative_confirmed_volume,8)+"|"+DoubleToString(value.residual_requested_volume,8)+"|"+
         SWV5_TestCanonicalEventSet(value.accepted_event_identities)+"|"+IntegerToString((long)value.retry_disposition)+"|"+
         value.authorization_identity+"|"+value.normalization_identity+"|"+IntegerToString((long)value.last_changed_at);
   return text;
}

string SWV5_TestCanonicalPersistedRequest(const SWV5_PersistedRequestEvidence &value)
{
   return SWV5_TestCanonicalVersion(value.contract_version)+"|"+SWV5_TestCanonicalNamespace(value.persistence_namespace)+"|"+
          SWV5_TestCanonicalFence(value.ownership_fence)+"|"+SWV5_TestCanonicalPending(value.pending_request)+"|"+
          IntegerToString((long)value.account_mode)+"|"+IntegerToString((long)value.record_sequence)+"|"+
          IntegerToString((long)value.recorded_at);
}

string SWV5_TestRequestSetDigest(const SWV5_PersistedRequestEvidence &requests[])
{
   string canonical="SWV5-PERSISTED-REQUEST-SET-V3|"+IntegerToString(ArraySize(requests));
   for(int index=0;index<ArraySize(requests);index++)
      canonical+="|"+IntegerToString(index)+"|"+SWV5_TestCanonicalPersistedRequest(requests[index]);
   return SWV5_TestCanonicalHash(canonical);
}

string SWV5_TestRequestSetRevision(const SWV5_PersistedRequestEvidence &requests[],const ulong record_sequence)
{
   return SWV5_TestCanonicalHash("SWV5-REQUEST-INDEX-V3|"+IntegerToString((long)record_sequence)+"|"+SWV5_TestRequestSetDigest(requests));
}

void SWV5_TestBindRequestSetHeader(SWV5_PersistedRequestSetHeader &header,
                                   const SWV5_PersistedRequestEvidence &requests[],
                                   const ulong record_sequence)
{
   SWV5_TestMakeVersion(header.contract_version);
   header.request_count=(uint)ArraySize(requests);
   header.request_set_digest=SWV5_TestRequestSetDigest(requests);
   header.request_index_revision=SWV5_TestRequestSetRevision(requests,record_sequence);
   header.record_sequence=record_sequence;
}

void SWV5_TestMakeRequestSetHeader(SWV5_PersistedRequestSetHeader &header,
                                   const uint request_count,
                                   const ulong record_sequence=30)
{
   SWV5_TestMakeVersion(header.contract_version);
   header.request_count=request_count;
   header.request_set_digest="UNBOUND-REQUEST-SET-DIGEST";
   header.request_index_revision="UNBOUND-REQUEST-INDEX-REVISION";
   header.record_sequence=record_sequence;
}

void SWV5_TestMakeTransaction(const SWV5_PendingRequest &pending,SWV5_TransactionEvidence &evidence,const double volume=0.10)
{
   SWV5_TestMakeVersion(evidence.contract_version);
   evidence.persistence_namespace=pending.intent.persistence_namespace;
   evidence.ownership_fence=pending.intent.ownership_fence;
   SWV5_TestMakeCorrelation(evidence.correlation);
   evidence.correlation.request_identity=pending.intent.request_identity;
   evidence.event_kind=SWV5_TRANSACTION_EVENT_DEAL_ADDED;
   evidence.confirmed_volume=volume;
   evidence.confirmed_price=pending.intent.normalized_price;
   evidence.symbol_specification_sequence=pending.intent.symbol_specification_sequence;
   evidence.expected_basket_version=pending.intent.expected_basket_version;
   evidence.transaction_time=SWV5_TEST_TIME;
   evidence.received_at=SWV5_TEST_TIME;
   evidence.authority=SWV5_AUTHORITY_TRANSACTION_EVENT;
   evidence.history_cross_checked=true;
}

void SWV5_TestMakeCheckpoint(SWV5_PersistedCheckpoint &checkpoint)
{
   SWV5_TestMakeVersion(checkpoint.header.contract_version);
   SWV5_TestMakeNamespace(checkpoint.header.persistence_namespace);
   SWV5_TestMakeFence(checkpoint.header.ownership_fence);
   checkpoint.header.record_sequence=20;
   checkpoint.header.previous_record_sequence=19;
   checkpoint.header.payload_digest="PAYLOAD-DIGEST-20";
   checkpoint.header.payload_size=4096;
   checkpoint.header.written_at=SWV5_TEST_TIME-10;
   SWV5_TestMakeAggregate(checkpoint.basket,SWV5_BASKET_ACTIVE);
   SWV5_TestMakeCorrelation(checkpoint.last_confirmed_correlation);
   SWV5_PersistedRequestEvidence empty_requests[];
   ArrayResize(empty_requests,0);
   SWV5_TestBindRequestSetHeader(checkpoint.pending_request_set,empty_requests,20);
   checkpoint.has_latest_pending_request=false;
   SWV5_TestMakeVersion(checkpoint.latest_pending_request.contract_version);
   checkpoint.latest_pending_request.persistence_namespace=checkpoint.header.persistence_namespace;
   checkpoint.latest_pending_request.ownership_fence=checkpoint.header.ownership_fence;
   SWV5_TestMakePending(checkpoint.latest_pending_request.pending_request);
   checkpoint.latest_pending_request.pending_request.state=SWV5_REQUEST_CONFIRMED;
   checkpoint.latest_pending_request.pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_COMPLETED;
   checkpoint.latest_pending_request.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   checkpoint.latest_pending_request.record_sequence=20;
   checkpoint.latest_pending_request.recorded_at=SWV5_TEST_TIME-10;
   SWV5_TestMakeHardKill(checkpoint.hard_kill_state,SWV5_HARD_KILL_INACTIVE);
   checkpoint.clean_shutdown=true;
}

void SWV5_TestMakeBrokerSummary(const SWV5_PersistedCheckpoint &checkpoint,SWV5_AuthoritativeBrokerSummary &broker)
{
   SWV5_TestMakeVersion(broker.contract_version);
   broker.persistence_namespace=checkpoint.header.persistence_namespace;
   broker.aggregate_position_volume=checkpoint.basket.lifecycle.aggregate_open_volume;
   broker.residual_volume=checkpoint.basket.lifecycle.residual_volume;
   broker.position_count=checkpoint.basket.lifecycle.live_position_count;
   broker.order_count=checkpoint.basket.lifecycle.live_order_count;
   broker.pending_request_count=checkpoint.pending_request_set.request_count;
   broker.latest_confirmed_correlation=checkpoint.last_confirmed_correlation;
   broker.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   SWV5_TestMakeQueries(broker.queries,SWV5_QUERY_POSITIONS|SWV5_QUERY_ORDERS|SWV5_QUERY_DEALS|SWV5_QUERY_TRANSACTIONS|SWV5_QUERY_PENDING_REQUESTS);
   broker.observed_at=SWV5_TEST_TIME;
   broker.authority=SWV5_AUTHORITY_LIVE_BROKER_STATE;
}

void SWV5_TestMakeRestartInput(SWV5_RestartReconciliationInput &engineInput)
{
   SWV5_TestMakeVersion(engineInput.contract_version);
   SWV5_TestMakeCheckpoint(engineInput.persisted);
   engineInput.persistence_namespace=engineInput.persisted.header.persistence_namespace;
   SWV5_TestMakeBrokerSummary(engineInput.persisted,engineInput.broker);
   engineInput.claimant_fence=engineInput.persisted.header.ownership_fence;
   engineInput.persistence_status=SWV5_PERSISTENCE_LOADED;
}

void SWV5_TestMakeStatisticsContext(SWV5_StatisticsBuildContext &context)
{
   SWV5_TestMakeVersion(context.contract_version);
   SWV5_TestMakeNamespace(context.persistence_namespace);
   context.history_from=SWV5_TEST_TIME-86400;
   context.history_to=SWV5_TEST_TIME;
   context.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   SWV5_TestMakeQueries(context.history_queries,SWV5_QUERY_DEALS|SWV5_QUERY_TRANSACTIONS);
}

void SWV5_TestMakeDedupState(SWV5_StatisticsDeduplicationState &state)
{
   SWV5_TestMakeVersion(state.contract_version);
   SWV5_TestMakeEventIdentitySet(state.identities,true);
   state.identities.canonical_event_index="EVENT-0001|400;EVENT-0002|399";
   state.identities.accepted_identity_count=2;
   state.identities.highest_transaction_sequence=400;
   state.identities.index_revision=2;
   state.identities.identity_set_digest=SWV5_TestCanonicalHash("SWV5-EVENT-SET-V3|"+state.identities.canonical_event_index+"|2|400|2|1");
   state.unique_deal_count=2;
   state.duplicate_deal_count=1;
}

void SWV5_TestMakeDedupEvidence(SWV5_StatisticsDeduplicationEvidence &evidence,
                                const SWV5_StatisticsDeduplicationState &state,
                                const SWV5_StatisticsIdentityDisposition disposition)
{
   SWV5_TestMakeVersion(evidence.contract_version);
   const ulong sequence=(disposition==SWV5_STAT_IDENTITY_DUPLICATE ? 400 : state.identities.highest_transaction_sequence+1);
   SWV5_TestMakeCorrelation(evidence.correlation,sequence);
   evidence.correlation.broker_identity.broker_event_id=(disposition==SWV5_STAT_IDENTITY_DUPLICATE ? "EVENT-0001" : "EVENT-NEW-"+IntegerToString((long)sequence));
   evidence.prior_identity_index_revision=state.identities.index_revision;
   evidence.membership_proof=(disposition==SWV5_STAT_IDENTITY_DUPLICATE ? "MEMBERSHIP-PROOF" : "");
   evidence.disposition=disposition;
}

void SWV5_TestMakeStatistics(SWV5_BasketStatistics &statistics)
{
   SWV5_TestMakeVersion(statistics.contract_version);
   SWV5_TestMakeNamespace(statistics.persistence_namespace);
   statistics.deal_count=10;
   statistics.entry_deal_count=5;
   statistics.exit_deal_count=5;
   statistics.partial_close_count=1;
   statistics.entered_volume=1.0;
   statistics.exited_volume=0.8;
   statistics.residual_volume=0.2;
   statistics.gross_profit=100.0;
   statistics.commission=-2.0;
   statistics.swap=-1.0;
   statistics.fee=-0.5;
   statistics.authoritative_net_result=96.5;
   statistics.first_deal_time=SWV5_TEST_TIME-3600;
   statistics.last_deal_time=SWV5_TEST_TIME;
   statistics.account_currency="USD";
   SWV5_TestMakeDedupState(statistics.deduplication);
   statistics.history_complete=true;
}

#endif
