//+------------------------------------------------------------------+
//| TEST ONLY                                                        |
//| NOT FOR PRODUCTION                                               |
//| NO BROKER ACCESS                                                 |
//+------------------------------------------------------------------+
#ifndef SW_V5_TEST_FIXTURES_MQH
#define SW_V5_TEST_FIXTURES_MQH

#include "..\..\ProductionArchitecture\SW_V5_ProductionContracts.mqh"

const datetime SWV5_TEST_TIME=D'2026.08.05 12:00:00';

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

void SWV5_TestMakeCorrelation(SWV5_ExecutionCorrelation &correlation,const ulong transaction_sequence=400)
{
   SWV5_TestMakeVersion(correlation.contract_version);
   correlation.request_id.correlation_id="REQ-0001";
   correlation.request_id.attempt_id="ATTEMPT-0001";
   correlation.request_id.parent_attempt_id="";
   correlation.request_id.monotonic_sequence=300;
   correlation.request_id.created_at=SWV5_TEST_TIME-60;
   correlation.order_ticket=5001;
   correlation.deal_ticket=6001;
   correlation.position_identifier=7001;
   correlation.event_id="EVENT-0001";
   correlation.idempotency_key="IDEMPOTENCY-0001";
   correlation.transaction_sequence=transaction_sequence;
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
   SWV5_TestMakeCorrelation(intent.correlation);
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
   state.release_evidence.broker_state_reconciled=false;
   state.release_evidence.persistence_reconciled=false;
   state.release_evidence.zero_or_reducing_exposure_confirmed=false;
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
   specification.complete=true;
}

void SWV5_TestMakeUnitRequest(SWV5_UnitNormalizationRequest &request)
{
   SWV5_TestMakeVersion(request.contract_version);
   SWV5_TestMakeNamespace(request.persistence_namespace);
   SWV5_TestMakeFence(request.ownership_fence);
   request.purpose=SWV5_PRICE_ENTRY;
   request.price_rounding=SWV5_NORMALIZE_NEAREST;
   request.volume_rounding=SWV5_NORMALIZE_DOWN;
   request.direction=1;
   request.raw_price=2400.03;
   request.raw_stop_price=2398.50;
   request.raw_limit_price=2420.00;
   request.raw_volume=0.015;
   request.reference_market_price=2400.00;
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
   SWV5_TestMakeCorrelation(authorization.correlation);
   SWV5_TestMakeNamespace(authorization.persistence_namespace);
   SWV5_TestMakeFence(authorization.ownership_fence);
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
   authorization.account_risk_snapshot_sequence=101;
   authorization.exposure_risk_snapshot_sequence=102;
   authorization.basket_risk_snapshot_sequence=103;
   authorization.projected_risk_snapshot_sequence=104;
   authorization.hard_kill_latch_id="HARD-KILL-0001";
   authorization.hard_kill_latch_generation=4;
   SWV5_TestMakeMonetaryBasis(authorization.monetary_basis);
   authorization.evaluated_at=SWV5_TEST_TIME;
   authorization.expires_at=SWV5_TEST_TIME+300;
   authorization.reason_text="TEST-ALLOW";
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
   claim.broker_state_reconciled=true;
   claim.persistence_reconciled=true;
   claim.broker_reconciliation_id="BROKER-RECON-1";
   claim.persistence_reconciliation_id="STORE-RECON-1";
}

void SWV5_TestMakePending(SWV5_PendingRequest &pending)
{
   SWV5_TestMakeVersion(pending.contract_version);
   SWV5_TestMakeIntent(pending.intent);
   pending.state=SWV5_REQUEST_CONFIRMATION_PENDING;
   pending.submission_attempt_count=1;
   SWV5_TestMakeVersion(pending.latest_retcode.contract_version);
   pending.latest_retcode.persistence_namespace=pending.intent.persistence_namespace;
   pending.latest_retcode.ownership_fence=pending.intent.ownership_fence;
   pending.latest_retcode.correlation=pending.intent.correlation;
   pending.latest_retcode.raw_retcode=1;
   pending.latest_retcode.broker_comment="TEST-ACK";
   pending.latest_retcode.observed_at=SWV5_TEST_TIME;
   SWV5_TestMakeVersion(pending.latest_retcode_classification.contract_version);
   pending.latest_retcode_classification.classification=SWV5_RETCODE_ACCEPTED_PENDING_CONFIRMATION;
   pending.latest_retcode_classification.retry_disposition=SWV5_RETRY_FORBIDDEN;
   pending.latest_retcode_classification.mapping_policy_id="TEST-RETCODE-MAP-V1";
   pending.confirmed_volume=0.0;
   pending.residual_requested_volume=0.10;
   SWV5_TestMakeVersion(pending.last_accepted_correlation.contract_version);
   pending.last_accepted_correlation.request_id=pending.intent.correlation.request_id;
   pending.last_accepted_correlation.order_ticket=0;
   pending.last_accepted_correlation.deal_ticket=0;
   pending.last_accepted_correlation.position_identifier=0;
   pending.last_accepted_correlation.event_id="";
   pending.last_accepted_correlation.idempotency_key="";
   pending.last_accepted_correlation.transaction_sequence=0;
   pending.last_changed_at=SWV5_TEST_TIME;
}

void SWV5_TestMakeTransaction(const SWV5_PendingRequest &pending,SWV5_TransactionEvidence &evidence,const double volume=0.10)
{
   SWV5_TestMakeVersion(evidence.contract_version);
   evidence.persistence_namespace=pending.intent.persistence_namespace;
   evidence.ownership_fence=pending.intent.ownership_fence;
   evidence.correlation=pending.intent.correlation;
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
   checkpoint.persisted_pending_request_count=0;
   checkpoint.pending_request_set_digest="EMPTY-SET-DIGEST";
   SWV5_TestMakeVersion(checkpoint.latest_pending_request.contract_version);
   checkpoint.latest_pending_request.persistence_namespace=checkpoint.header.persistence_namespace;
   checkpoint.latest_pending_request.ownership_fence=checkpoint.header.ownership_fence;
   SWV5_TestMakeCorrelation(checkpoint.latest_pending_request.correlation);
   checkpoint.latest_pending_request.confirmation_status=SWV5_CONFIRMATION_CONFIRMED;
   checkpoint.latest_pending_request.symbol_specification_sequence=50;
   checkpoint.latest_pending_request.expected_basket_version=12;
   checkpoint.latest_pending_request.normalized_volume=0.10;
   checkpoint.latest_pending_request.normalized_price=2400.0;
   checkpoint.latest_pending_request.normalized_stop_price=2390.0;
   checkpoint.latest_pending_request.normalized_limit_price=2420.0;
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
   broker.pending_request_count=checkpoint.persisted_pending_request_count;
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
   state.identity_set_digest="SET-DIGEST-10";
   state.unique_deal_count=10;
   state.duplicate_deal_count=1;
   state.highest_transaction_sequence=400;
   state.identity_index_sequence=10;
}

void SWV5_TestMakeDedupEvidence(SWV5_StatisticsDeduplicationEvidence &evidence,
                                const SWV5_StatisticsDeduplicationState &state,
                                const SWV5_StatisticsIdentityDisposition disposition)
{
   SWV5_TestMakeVersion(evidence.contract_version);
   SWV5_TestMakeCorrelation(evidence.correlation,state.highest_transaction_sequence+1);
   evidence.prior_identity_set_digest=state.identity_set_digest;
   evidence.membership_proof=(disposition==SWV5_STAT_IDENTITY_DUPLICATE ? "MEMBERSHIP-PROOF" : "");
   evidence.identity_index_sequence=state.identity_index_sequence+1;
   evidence.disposition=disposition;
}

#endif
