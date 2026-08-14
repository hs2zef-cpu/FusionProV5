//+------------------------------------------------------------------+
//| TEST ONLY                                                        |
//| NOT FOR PRODUCTION                                               |
//| NO BROKER ACCESS                                                 |
//+------------------------------------------------------------------+
#ifndef SW_V5_TEST_FIXTURES_MQH
#define SW_V5_TEST_FIXTURES_MQH

#include "..\..\ProductionArchitecture\SW_V5_ProductionContracts.mqh"

const datetime SWV5_TEST_TIME=D'2026.08.05 12:00:00';

double SWV5_TestNaN()
{
   return MathArcsin(2.0);
}

double SWV5_TestPositiveInfinity()
{
   return MathPow(10.0,400.0);
}

string SWV5_TestCanonicalHash(const string value);
string SWV5_TestCanonicalField(const string name,const string type,const string value);
string SWV5_TestCanonicalIntegerField(const string name,const long value);
string SWV5_TestCanonicalUnsignedField(const string name,const ulong value);
string SWV5_TestCanonicalDoubleField(const string name,const double value);
string SWV5_TestCanonicalBoolField(const string name,const bool value);
string SWV5_TestCanonicalDurableEventEntry(const string event_id,const ulong sequence);
string SWV5_TestCanonicalDurableFingerprintEntry(const string event_id,const ulong sequence,const string fingerprint);
string SWV5_TestEventSetDigest(const SWV5_DurableEventIdentitySet &set);
string SWV5_TestCanonicalCheckpointPayload(const SWV5_PersistedCheckpoint &checkpoint);
string SWV5_TestCheckpointPayloadDigest(const SWV5_PersistedCheckpoint &checkpoint);
ulong SWV5_TestCheckpointPayloadSize(const SWV5_PersistedCheckpoint &checkpoint);
void SWV5_TestSealCheckpoint(SWV5_PersistedCheckpoint &checkpoint);
string SWV5_TestMarginEvidenceDigest(const SWV5_MarginProjectionEvidence &evidence);
string SWV5_TestBasketRiskEvidenceDigest(const SWV5_BasketRiskProjectionEvidence &evidence);
string SWV5_TestMarginAuthorityDigest(const SWV5_MarginAuthorityRecord &record);
string SWV5_TestBasketRiskAuthorityDigest(const SWV5_BasketRiskAuthorityRecord &record);
string SWV5_TestHardKillReleaseDigest(const SWV5_HardKillReleaseEvidence &evidence);
string SWV5_TestCanonicalHardKillAuthorityRecord(const SWV5_HardKillReleaseAuthorityRecord &record);
string SWV5_TestHardKillAuthorityRecordDigest(const SWV5_HardKillReleaseAuthorityRecord &record);
string SWV5_TestBrokerSummaryDigest(const SWV5_AuthoritativeBrokerSummary &summary);
string SWV5_TestRestartRequestSummaryDigest(const SWV5_AuthoritativeRestartRequestSummary &summary);
string SWV5_TestReconciliationSourceDigest(const SWV5_PersistedReconciliationVector &value);
string SWV5_TestAcceptedQueryWatermarkProposalDigest(const SWV5_AcceptedQueryWatermarkProposal &proposal);

void SWV5_TestMakeVersion(SWV5_ContractVersion &version)
{
   version.contract_name=SWV5_PRODUCTION_CONTRACT_NAME;
   version.schema_version=SWV5_PRODUCTION_CONTRACT_VERSION;
   version.minimum_compatible_version=SWV5_PRODUCTION_MINIMUM_COMPATIBLE_VERSION;
   version.policy_id=SWV5_PRODUCTION_CONTRACT_POLICY;
}

void SWV5_TestSetForeignContractIdentity(SWV5_ContractVersion &version)
{
   version.contract_name="FOREIGN-PRODUCTION-CONTRACT";
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

void SWV5_TestMakeEventIdentitySet(SWV5_DurableEventIdentitySet &set,
                                   const bool populated=false,
                                   const SWV5_DurableFingerprintPolicy fingerprint_policy=SWV5_DURABLE_FINGERPRINT_IDENTITY_ONLY)
{
   SWV5_TestMakeVersion(set.contract_version);
   set.fingerprint_policy=fingerprint_policy;
   set.canonical_event_index=(populated ? SWV5_TestCanonicalDurableEventEntry("EVENT-0001",400) : "");
   set.canonical_fingerprint_index=(populated && fingerprint_policy==SWV5_DURABLE_FINGERPRINT_REQUIRED ?
                                    SWV5_TestCanonicalDurableFingerprintEntry("EVENT-0001",400,"FINGERPRINT-EVENT-0001") : "");
   set.accepted_identity_count=(populated ? 1 : 0);
   set.highest_transaction_sequence=(populated ? 400 : 0);
   set.index_revision=(populated ? 1 : 0);
   set.compaction_generation=1;
   set.identity_set_digest=SWV5_TestEventSetDigest(set);
}

string SWV5_TestQuerySnapshotDigest(const SWV5_AuthoritativeQuerySet &queries);

void SWV5_TestMakeQueries(SWV5_AuthoritativeQuerySet &queries,const ulong required_flags)
{
   SWV5_TestMakeVersion(queries.contract_version);
   queries.required_flags=required_flags;
   queries.completed_flags=required_flags;
   queries.authoritative_flags=required_flags;
   queries.observation_sequence=900;
   queries.observed_at=SWV5_TEST_TIME;
   const bool execution_owned=(required_flags==SWV5_QUERY_PENDING_REQUESTS);
   queries.issuing_component=(execution_owned ? SWV5_COMPONENT_AUTHORITY_EXECUTION : SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER);
   queries.authority_source=(execution_owned ? SWV5_AUTHORITY_EXECUTION_REQUEST_STATE : SWV5_AUTHORITY_LIVE_BROKER_STATE);
   queries.snapshot_id=(execution_owned ? "EXECUTION-QUERY-" : "BROKER-QUERY-")+IntegerToString((long)queries.observation_sequence);
   queries.snapshot_digest="";
   queries.snapshot_digest=SWV5_TestQuerySnapshotDigest(queries);
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
   SWV5_TestMakeEventIdentitySet(snapshot.accepted_recovery_evidence,false,SWV5_DURABLE_FINGERPRINT_REQUIRED);
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
   state.release_evidence.approval_policy_id="";
   state.release_evidence.approval_sequence=0;
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
   state.release_evidence.released_at=0;
   state.release_evidence.expires_at=0;
   state.release_evidence.release_record_sequence=0;
   state.release_evidence.release_record_digest="";
   state.release_evidence.audit_reference="";
   SWV5_TestMakeVersion(state.release_authority_reference.contract_version);
   state.release_authority_reference.authority_record_id="";
   state.release_authority_reference.authority_record_sequence=0;
   state.release_authority_reference.authority_record_digest="";
   state.release_authority_reference.release_id="";
   state.release_authority_reference.latch_generation=state.latch_generation;
   state.release_authority_reference.release_generation=0;
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
   specification.calculation_mode=SWV5_SYMBOL_CALCULATION_XAU_QUANTITY;
   specification.tick_value_basis_volume=1.0;
   specification.volume_minimum=0.01;
   specification.volume_maximum=100.0;
   specification.volume_step=0.01;
   specification.stops_level_points=100;
   specification.freeze_level_points=50;
   specification.account_currency="USD";
   specification.tick_value_currency="USD";
   specification.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
   specification.observed_at=SWV5_TEST_TIME-10;
   specification.valid_until=SWV5_TEST_TIME+300;
   specification.complete=true;
}

void SWV5_TestMakeUnitRequest(SWV5_UnitNormalizationRequest &request)
{
   SWV5_TestMakeVersion(request.contract_version);
   SWV5_TestMakeNamespace(request.persistence_namespace);
   SWV5_TestMakeFence(request.ownership_fence);
   request.intent_type=SWV5_INTENT_OPEN;
   request.purpose=SWV5_PRICE_ENTRY;
   request.operation_kind=SWV5_OPERATION_MARKET_ENTRY;
   request.direction=1;
   request.raw_price=2400.03;
   request.raw_stop_price=2398.50;
   request.raw_limit_price=2420.00;
   request.raw_volume=0.015;
   request.current_exposure_volume=0.0;
   request.target_exposure_volume=0.015;
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
   authorization.authorized_limits.minimum_equity=9000.0;
   authorization.authorized_limits.maximum_daily_net_loss=500.0;
   authorization.authorized_limits.maximum_account_margin_fraction=0.50;
   authorization.authorized_limits.maximum_basket_loss=300.0;
   authorization.authorized_limits.maximum_basket_volume=1.0;
   authorization.authorized_limits.maximum_symbol_volume=2.0;
   authorization.authorized_limits.maximum_aggregate_volume=5.0;
   authorization.authorized_limits.maximum_aggregate_notional=100000.0;
   authorization.authorized_limits.maximum_live_baskets=10;
   authorization.authorized_limits.maximum_snapshot_age_seconds=60;
   authorization.authorized_limits.maximum_cumulative_recovery_attempts=5;
   authorization.authorized_limits.trading_day_policy=SWV5_TRADING_DAY_BROKER_SERVER;
   authorization.authorized_limits.trading_day_utc_offset_minutes=0;
   authorization.authorized_limits.hard_kill_enabled=true;
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
   authorization.authorized_projected_notional=960.0;
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
   engineInput.limits.maximum_aggregate_notional=1000000.0;
   engineInput.limits.maximum_live_baskets=10;
   engineInput.limits.maximum_snapshot_age_seconds=60;
   engineInput.limits.maximum_cumulative_recovery_attempts=5;
   engineInput.limits.trading_day_policy=SWV5_TRADING_DAY_BROKER_SERVER;
   engineInput.limits.trading_day_utc_offset_minutes=0;
   engineInput.limits.hard_kill_enabled=true;
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
   engineInput.exposure.symbol_long_volume=0.30;
   engineInput.exposure.symbol_short_volume=0.0;
   engineInput.exposure.symbol_net_volume=0.30;
   engineInput.exposure.aggregate_volume=0.30;
   engineInput.exposure.aggregate_notional=72000.0;
   engineInput.exposure.live_basket_count=1;
   engineInput.exposure.observed_at=SWV5_TEST_TIME;
   engineInput.exposure.complete=true;
   SWV5_TestMakeVersion(engineInput.basket.contract_version);
   engineInput.basket.account_namespace=engineInput.account_namespace;
   // OPEN targets an empty Basket. Existing 0.30 symbol/account exposure is
   // deliberately external to this Basket so causal projection is exercised.
   SWV5_TestMakeLifecycle(engineInput.basket.lifecycle,SWV5_BASKET_IDLE);
   engineInput.basket.realized_net=0.0;
   engineInput.basket.unrealized_net=0.0;
   engineInput.basket.maximum_adverse_net=0.0;
   engineInput.basket.observed_at=SWV5_TEST_TIME;
   SWV5_TestMakeVersion(engineInput.projected.contract_version);
   engineInput.projected.account_namespace=engineInput.account_namespace;
   engineInput.projected.symbol="XAUUSD.TEST";
   engineInput.projected.projected_volume=0.10;
   engineInput.projected.projected_symbol_volume=0.40;
   engineInput.projected.projected_aggregate_volume=0.40;
   engineInput.projected.projected_notional=96000.0;
   SWV5_TestMakeMonetaryBasis(engineInput.projected.monetary_basis);
   engineInput.projected.calculated_at=SWV5_TEST_TIME;
   engineInput.projected.complete=true;
   SWV5_TestMakeSymbolSpecification(engineInput.symbol_specification);
   SWV5_MarginProjectionEvidence margin;
   SWV5_TestMakeVersion(margin.contract_version);
   margin.persistence_namespace=engineInput.intent.persistence_namespace;
   margin.account_namespace=engineInput.account_namespace;
   margin.ownership_fence=engineInput.intent.ownership_fence;
   margin.request_identity=engineInput.intent.request_identity;
   margin.basket_id=engineInput.intent.persistence_namespace.basket_id;
   margin.symbol=engineInput.projected.symbol;
   margin.symbol_specification_sequence=engineInput.intent.symbol_specification_sequence;
   margin.intent_type=engineInput.intent.intent_type;
   margin.direction=engineInput.intent.direction;
   margin.requested_volume=engineInput.intent.normalized_volume;
   margin.requested_price=engineInput.intent.normalized_price;
   margin.current_account_margin=engineInput.account.margin;
   margin.current_free_margin=engineInput.account.free_margin;
   margin.projected_account_margin=124.0;
   margin.additional_margin=24.0;
   margin.account_currency=engineInput.account_namespace.account_currency;
   margin.issuing_component=SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER;
   margin.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
   margin.calculation_reference="BROKER-MARGIN-0001";
   margin.observed_at=SWV5_TEST_TIME-2;
   margin.calculated_at=SWV5_TEST_TIME-1;
   margin.evidence_sequence=1101;
   margin.authority_record_id="MARGIN-AUTHORITY-0001";
   margin.authority_record_sequence=1102;
   margin.authority_record_digest="PENDING-MARGIN-AUTHORITY-DIGEST";
   margin.evidence_digest=SWV5_TestMarginEvidenceDigest(margin);
   engineInput.projected.margin_evidence=margin;
   SWV5_BasketRiskProjectionEvidence loss;
   SWV5_TestMakeVersion(loss.contract_version);
   loss.persistence_namespace=engineInput.intent.persistence_namespace;
   loss.account_namespace=engineInput.account_namespace;
   loss.ownership_fence=engineInput.intent.ownership_fence;
   loss.basket_id=engineInput.intent.persistence_namespace.basket_id;
   loss.basket_state_version=engineInput.intent.expected_basket_version;
   loss.request_identity=engineInput.intent.request_identity;
   loss.symbol=engineInput.projected.symbol;
   loss.symbol_specification_sequence=engineInput.intent.symbol_specification_sequence;
   loss.existing_bounded_basket_loss=25.0;
   loss.incremental_request_bounded_loss=100.0;
   loss.interaction_or_offset_adjustment=0.0;
   loss.resulting_basket_maximum_loss=125.0;
   loss.realized_loss_basis=0.0;
   loss.unrealized_loss_basis=0.0;
   loss.accrued_cost_basis=0.0;
   loss.monetary_basis=engineInput.projected.monetary_basis;
   loss.calculation_policy_id="RESULTING_BASKET_MAXIMUM_ACCOUNT_CURRENCY_LOSS/V5";
   loss.source_snapshot_digest="RISK-SNAPSHOT-0001";
   loss.issuing_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
   loss.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
   loss.observed_at=SWV5_TEST_TIME-2;
   loss.calculated_at=SWV5_TEST_TIME-1;
   loss.evidence_sequence=1201;
   loss.authority_record_id="BASKET-RISK-AUTHORITY-0001";
   loss.authority_record_sequence=1202;
   loss.authority_record_digest="PENDING-BASKET-RISK-AUTHORITY-DIGEST";
   loss.evidence_digest=SWV5_TestBasketRiskEvidenceDigest(loss);
   engineInput.projected.basket_risk_evidence=loss;
   engineInput.projected.projected_margin=margin.additional_margin;
   engineInput.projected.projected_maximum_loss=loss.resulting_basket_maximum_loss;
   engineInput.has_margin_authority_record=true;
   SWV5_MarginAuthorityRecord margin_authority;
   margin_authority.contract_version=margin.contract_version;
   margin_authority.persistence_namespace=margin.persistence_namespace;
   margin_authority.account_namespace=margin.account_namespace;
   margin_authority.ownership_fence=margin.ownership_fence;
   margin_authority.request_identity=margin.request_identity;
   margin_authority.basket_id=margin.basket_id;
   margin_authority.symbol=margin.symbol;
   margin_authority.symbol_specification_sequence=margin.symbol_specification_sequence;
   margin_authority.intent_type=margin.intent_type;
   margin_authority.direction=margin.direction;
   margin_authority.requested_volume=margin.requested_volume;
   margin_authority.requested_price=margin.requested_price;
   margin_authority.current_account_margin=margin.current_account_margin;
   margin_authority.projected_account_margin=margin.projected_account_margin;
   margin_authority.additional_margin=margin.additional_margin;
   margin_authority.current_free_margin=margin.current_free_margin;
   margin_authority.account_currency=margin.account_currency;
   margin_authority.broker_calculation_reference=margin.calculation_reference;
   margin_authority.observation_sequence=1100;
   margin_authority.observed_at=margin.observed_at;
   margin_authority.calculated_at=margin.calculated_at;
   margin_authority.authority_record_id=margin.authority_record_id;
   margin_authority.authority_record_sequence=margin.authority_record_sequence;
   margin_authority.issuing_component=SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER;
   margin_authority.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
   margin_authority.authority_record_digest=SWV5_TestMarginAuthorityDigest(margin_authority);
   engineInput.margin_authority_record=margin_authority;
   engineInput.projected.margin_evidence.authority_record_digest=margin_authority.authority_record_digest;
   engineInput.projected.margin_evidence.evidence_digest=SWV5_TestMarginEvidenceDigest(engineInput.projected.margin_evidence);
   engineInput.has_basket_risk_authority_record=true;
   SWV5_BasketRiskAuthorityRecord basket_authority;
   basket_authority.contract_version=loss.contract_version;
   basket_authority.persistence_namespace=loss.persistence_namespace;
   basket_authority.account_namespace=loss.account_namespace;
   basket_authority.ownership_fence=loss.ownership_fence;
   basket_authority.basket_id=loss.basket_id;
   basket_authority.basket_state_version=loss.basket_state_version;
   basket_authority.request_identity=loss.request_identity;
   basket_authority.symbol=loss.symbol;
   basket_authority.symbol_specification_sequence=loss.symbol_specification_sequence;
   basket_authority.source_snapshot_id="BASKET-SOURCE-0001";
   basket_authority.source_snapshot_digest=loss.source_snapshot_digest;
   basket_authority.existing_bounded_basket_loss=loss.existing_bounded_basket_loss;
   basket_authority.incremental_request_bounded_loss=loss.incremental_request_bounded_loss;
   basket_authority.interaction_or_offset_adjustment=loss.interaction_or_offset_adjustment;
   basket_authority.resulting_basket_maximum_loss=loss.resulting_basket_maximum_loss;
   basket_authority.realized_loss_basis=loss.realized_loss_basis;
   basket_authority.unrealized_loss_basis=loss.unrealized_loss_basis;
   basket_authority.accrued_cost_basis=loss.accrued_cost_basis;
   basket_authority.monetary_basis=loss.monetary_basis;
   basket_authority.calculation_policy_id=loss.calculation_policy_id;
   basket_authority.observation_sequence=1200;
   basket_authority.observed_at=loss.observed_at;
   basket_authority.calculated_at=loss.calculated_at;
   basket_authority.authority_record_id=loss.authority_record_id;
   basket_authority.authority_record_sequence=loss.authority_record_sequence;
   basket_authority.issuing_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
   basket_authority.authority_source=SWV5_AUTHORITY_RISK_GOVERNANCE_RECORD;
   basket_authority.authority_record_digest=SWV5_TestBasketRiskAuthorityDigest(basket_authority);
   engineInput.basket_risk_authority_record=basket_authority;
   engineInput.projected.basket_risk_evidence.authority_record_digest=basket_authority.authority_record_digest;
   engineInput.projected.basket_risk_evidence.evidence_digest=SWV5_TestBasketRiskEvidenceDigest(engineInput.projected.basket_risk_evidence);
   engineInput.ownership_fence=engineInput.intent.ownership_fence;
   SWV5_TestMakeHardKill(engineInput.hard_kill_state,SWV5_HARD_KILL_INACTIVE);
   engineInput.hard_kill_state.account_namespace=engineInput.account_namespace;
}

void SWV5_TestApplyRiskNamespace(SWV5_RiskEvaluationInput &engineInput,
                                 const SWV5_AccountRiskNamespace &account_namespace)
{
   engineInput.account_namespace=account_namespace;
   engineInput.account.account_namespace=account_namespace;
   engineInput.exposure.account_namespace=account_namespace;
   engineInput.basket.account_namespace=account_namespace;
   engineInput.projected.account_namespace=account_namespace;
   engineInput.projected.margin_evidence.account_namespace=account_namespace;
   engineInput.projected.basket_risk_evidence.account_namespace=account_namespace;
   engineInput.hard_kill_state.account_namespace=account_namespace;
   SWV5_OwnershipKey key=engineInput.intent.persistence_namespace.ownership_namespace;
   key.broker_identity=account_namespace.broker_identity;
   key.server=account_namespace.server;
   key.account_login=account_namespace.account_login;
   key.strategy_id=account_namespace.strategy_id;
   key.magic=account_namespace.magic;
   engineInput.intent.persistence_namespace.ownership_namespace=key;
   engineInput.intent.ownership_fence.ownership_namespace=key;
   engineInput.intent.ownership_fence.owner.key=key;
   engineInput.ownership_fence.ownership_namespace=key;
   engineInput.ownership_fence.owner.key=key;
   engineInput.basket.lifecycle.ownership_fence.ownership_namespace=key;
   engineInput.basket.lifecycle.ownership_fence.owner.key=key;
   engineInput.hard_kill_state.persistence_namespace.ownership_namespace=key;
   engineInput.projected.monetary_basis.account_currency=account_namespace.account_currency;
   engineInput.projected.margin_evidence.account_currency=account_namespace.account_currency;
   engineInput.projected.margin_evidence.persistence_namespace=engineInput.intent.persistence_namespace;
   engineInput.projected.margin_evidence.ownership_fence=engineInput.intent.ownership_fence;
   engineInput.projected.basket_risk_evidence.persistence_namespace=engineInput.intent.persistence_namespace;
   engineInput.projected.basket_risk_evidence.ownership_fence=engineInput.intent.ownership_fence;
   engineInput.projected.margin_evidence.evidence_digest=SWV5_TestMarginEvidenceDigest(engineInput.projected.margin_evidence);
   engineInput.projected.basket_risk_evidence.evidence_digest=SWV5_TestBasketRiskEvidenceDigest(engineInput.projected.basket_risk_evidence);
}

void SWV5_TestMakeValidHardKillRelease(SWV5_HardKillState &state)
{
   SWV5_TestMakeHardKill(state,SWV5_HARD_KILL_RELEASE_PENDING);
   state.release_evidence.release_id="RELEASE-0001";
   state.release_evidence.release_generation=state.release_generation+1;
   state.release_evidence.approval_policy_id="HARD-KILL-RELEASE-V5";
   state.release_evidence.approval_sequence=953;
   state.release_evidence.operator_identity.operator_id="RISK-OFFICER-1";
   state.release_evidence.operator_identity.authority_role="INDEPENDENT-RISK";
   state.release_evidence.operator_identity.authentication_reference="AUTH-REF-1";
   state.release_evidence.operator_identity.authenticated_at=SWV5_TEST_TIME-30;
   state.release_evidence.approving_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
   SWV5_TestMakeTypedReconciliation(state.release_evidence.broker_evidence,"BROKER-RELEASE-1",SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER);
   SWV5_TestMakeTypedReconciliation(state.release_evidence.persistence_evidence,"STORE-RELEASE-1",SWV5_COMPONENT_AUTHORITY_PERSISTENCE);
   state.release_evidence.broker_evidence.observed_at=SWV5_TEST_TIME-25;
   state.release_evidence.persistence_evidence.observed_at=SWV5_TEST_TIME-20;
   state.release_evidence.exposure_evidence.evidence_id="EXPOSURE-RELEASE-1";
   state.release_evidence.exposure_evidence.issuing_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
   state.release_evidence.exposure_evidence.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
   state.release_evidence.exposure_evidence.observed_exposure_volume=0.0;
   state.release_evidence.exposure_evidence.prior_exposure_volume=0.10;
   state.release_evidence.exposure_evidence.zero_or_reducing=true;
   state.release_evidence.exposure_evidence.evidence_sequence=952;
   state.release_evidence.exposure_evidence.observed_at=SWV5_TEST_TIME-15;
   state.release_evidence.approved_at=SWV5_TEST_TIME-10;
   state.release_evidence.released_at=SWV5_TEST_TIME-5;
   state.release_evidence.expires_at=SWV5_TEST_TIME+60;
   state.release_evidence.release_record_sequence=954;
   state.release_evidence.audit_reference="AUDIT-RELEASE-0001";
   state.release_evidence.release_record_digest=SWV5_TestHardKillReleaseDigest(state.release_evidence);
}

void SWV5_TestMakeHistoricalHardKillRelease(SWV5_HardKillState &state)
{
   SWV5_TestMakeValidHardKillRelease(state);
   state.state=SWV5_HARD_KILL_RELEASED;
   state.release_generation=state.release_evidence.release_generation;
   state.release_evidence.expires_at=SWV5_TEST_TIME-1;
   state.release_evidence.release_record_digest=SWV5_TestHardKillReleaseDigest(state.release_evidence);
}

void SWV5_TestMakeHardKillAuthorityRecord(const SWV5_HardKillState &state,
                                           SWV5_HardKillReleaseAuthorityRecord &record)
{
   record.contract_version=state.release_evidence.contract_version;
   record.persistence_namespace=state.persistence_namespace;
   record.account_namespace=state.account_namespace;
   record.latch_id=state.latch_id;
   record.latch_generation=state.latch_generation;
   record.release_id=state.release_evidence.release_id;
   record.release_generation=state.release_evidence.release_generation;
   record.operator_identity=state.release_evidence.operator_identity;
   record.approving_component=state.release_evidence.approving_component;
   record.approval_policy_id=state.release_evidence.approval_policy_id;
   record.approval_sequence=state.release_evidence.approval_sequence;
   record.broker_evidence_reference=state.release_evidence.broker_evidence;
   record.persistence_evidence_reference=state.release_evidence.persistence_evidence;
   record.exposure_evidence_reference=state.release_evidence.exposure_evidence;
   record.approved_at=state.release_evidence.approved_at;
   record.released_at=state.release_evidence.released_at;
   record.expires_at=state.release_evidence.expires_at;
   record.release_record_sequence=state.release_evidence.release_record_sequence;
   record.authority_record_id="HK-AUTHORITY-RECORD-0001";
   record.issuing_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
   record.authority_source=SWV5_AUTHORITY_HARD_KILL_RELEASE_RECORD;
   record.authority_record_digest=SWV5_TestHardKillAuthorityRecordDigest(record);
}

void SWV5_TestBindHardKillAuthorityReference(SWV5_HardKillState &state,
                                              const SWV5_HardKillReleaseAuthorityRecord &record)
{
   state.release_authority_reference.contract_version=record.contract_version;
   state.release_authority_reference.authority_record_id=record.authority_record_id;
   state.release_authority_reference.authority_record_sequence=record.release_record_sequence;
   state.release_authority_reference.authority_record_digest=record.authority_record_digest;
   state.release_authority_reference.release_id=record.release_id;
   state.release_authority_reference.latch_generation=record.latch_generation;
   state.release_authority_reference.release_generation=record.release_generation;
}

void SWV5_TestMakeHistoricalHardKillAuthority(SWV5_HardKillState &state,
                                               SWV5_HardKillReleaseAuthorityRecord &record)
{
   SWV5_TestMakeHistoricalHardKillRelease(state);
   SWV5_TestMakeHardKillAuthorityRecord(state,record);
   SWV5_TestBindHardKillAuthorityReference(state,record);
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
   lease.store_revision="STORE-REV-7";
   lease.heartbeat_sequence=20;
   lease.clock_id="TEST-CLOCK-1";
   lease.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
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
   claim.expected_store_revision=observed.store_revision;
   claim.lease_duration_seconds=120;
   SWV5_TestMakeVersion(claim.takeover_evidence.contract_version);
   SWV5_TestMakeTypedReconciliation(claim.takeover_evidence.broker_reconciliation,"BROKER-RECON-1",SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER);
   SWV5_TestMakeTypedReconciliation(claim.takeover_evidence.persistence_reconciliation,"STORE-RECON-1",SWV5_COMPONENT_AUTHORITY_PERSISTENCE);
   SWV5_TestMakeVersion(claim.takeover_evidence.lease_expiry.contract_version);
   claim.takeover_evidence.lease_expiry.observed_ownership_key=observed.fence.ownership_namespace;
   claim.takeover_evidence.lease_expiry.observed_owner=observed.fence.owner;
   claim.takeover_evidence.lease_expiry.observed_ownership_namespace=observed.fence.ownership_namespace;
   claim.takeover_evidence.lease_expiry.clock_id="TEST-CLOCK-1";
   claim.takeover_evidence.lease_expiry.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   claim.takeover_evidence.lease_expiry.observed_clock_sequence=observed.expiry_clock_sequence;
   claim.takeover_evidence.lease_expiry.observed_at=SWV5_TEST_TIME;
   claim.takeover_evidence.lease_expiry.observed_lease_version=observed.fence.lease_version;
   claim.takeover_evidence.lease_expiry.observed_heartbeat_sequence=observed.heartbeat_sequence;
   claim.takeover_evidence.lease_expiry.observed_store_revision=observed.store_revision;
   claim.takeover_evidence.lease_expiry.observed_expiry_time=observed.expires_at;
   claim.takeover_evidence.lease_expiry.observed_takeover_generation=observed.fence.takeover_generation;
   claim.takeover_evidence.lease_expiry.expired=true;
   claim.takeover_evidence.observed_ownership_key=observed.fence.ownership_namespace;
   claim.takeover_evidence.observed_owner=observed.fence.owner;
   claim.takeover_evidence.observed_ownership_namespace=observed.fence.ownership_namespace;
   claim.takeover_evidence.observed_lease_version=observed.fence.lease_version;
   claim.takeover_evidence.observed_store_revision=observed.store_revision;
   claim.takeover_evidence.observed_heartbeat_sequence=observed.heartbeat_sequence;
   claim.takeover_evidence.observed_clock_id=observed.clock_id;
   claim.takeover_evidence.observed_clock_authority=observed.clock_authority;
   claim.takeover_evidence.observed_clock_sequence=observed.expiry_clock_sequence;
   claim.takeover_evidence.observed_expiry_time=observed.expires_at;
   claim.takeover_evidence.observed_at=SWV5_TEST_TIME;
   claim.takeover_evidence.observed_takeover_generation=observed.fence.takeover_generation;
   claim.takeover_evidence.proposed_takeover_generation=observed.fence.takeover_generation+1;
   claim.takeover_evidence.authority=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
   claim.takeover_evidence.independent_authority_source=SWV5_AUTHORITY_OPERATOR;
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
   pending.latest_retcode.correlation.broker_identity.deal_ticket=0;
   pending.latest_retcode.correlation.broker_identity.position_identifier=0;
   pending.latest_retcode.correlation.broker_identity.broker_event_id="";
   pending.latest_retcode.correlation.broker_identity.transaction_sequence=0;
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
   pending.latest_authoritative_confirmation.correlation=pending.latest_retcode.correlation;
   pending.latest_authoritative_confirmation.status=SWV5_CONFIRMATION_NOT_STARTED;
   pending.latest_authoritative_confirmation.cumulative_confirmed_volume=0.0;
   pending.latest_authoritative_confirmation.residual_volume=0.10;
   pending.latest_authoritative_confirmation.authority=SWV5_AUTHORITY_NONE;
   pending.latest_authoritative_confirmation.confirmation_sequence=0;
   pending.latest_authoritative_confirmation.confirmed_at=0;
   pending.cumulative_confirmed_volume=0.0;
   pending.residual_requested_volume=0.10;
   SWV5_TestMakeEventIdentitySet(pending.accepted_event_identities,false,SWV5_DURABLE_FINGERPRINT_REQUIRED);
   pending.retry_disposition=SWV5_RETRY_FORBIDDEN;
   pending.authorization_identity=pending.intent.risk_authorization_id;
   pending.normalization_identity="NORMALIZATION-50-2400.00-0.10";
   pending.last_changed_at=SWV5_TEST_TIME;
}

void SWV5_TestMakeRetryCandidate(SWV5_PendingRequest &pending)
{
   SWV5_TestMakePending(pending);
   pending.retry_disposition=SWV5_RETRY_AFTER_REVALIDATION;
   pending.latest_retcode_classification.classification=SWV5_RETCODE_CONNECTION_UNCERTAIN;
   pending.latest_retcode_classification.retry_disposition=SWV5_RETRY_AFTER_REVALIDATION;
   pending.last_changed_at=SWV5_TEST_TIME-1;
}

void SWV5_TestMakeRetryPolicy(const SWV5_ContractValidationContext &context,SWV5_RetryPolicy &policy)
{
   SWV5_TestMakeVersion(policy.contract_version);
   policy.maximum_attempts=3;
   policy.initial_backoff_milliseconds=100;
   policy.maximum_backoff_milliseconds=1000;
   policy.require_fresh_risk_authorization=true;
   policy.require_fresh_unit_normalization=true;
   policy.disposition=SWV5_RETRY_AFTER_REVALIDATION;
   policy.authorization_deadline=context.clock_time+120;
   policy.earliest_retry_at=context.clock_time;
}

void SWV5_TestMakeRetryRiskEvidence(const SWV5_ContractValidationContext &context,
                                    const SWV5_PendingRequest &pending,
                                    SWV5_RetryRiskFreshnessEvidence &evidence)
{
   SWV5_TestMakeVersion(evidence.contract_version);
   evidence.persistence_namespace=pending.intent.persistence_namespace;
   evidence.ownership_fence=pending.intent.ownership_fence;
   evidence.request_identity=pending.intent.request_identity;
   evidence.account_mode=pending.account_mode;
   evidence.expected_basket_version=pending.intent.expected_basket_version;
   evidence.symbol_specification_sequence=pending.intent.symbol_specification_sequence;
   evidence.authorization_id=pending.authorization_identity;
   evidence.authorized_volume=pending.intent.normalized_volume;
   evidence.evidenced_at=context.clock_time;
   evidence.expires_at=pending.intent.authorization_expires_at;
   evidence.evidence_sequence=context.evaluation_sequence;
   evidence.issuing_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
}

void SWV5_TestMakeRetryNormalizationEvidence(const SWV5_ContractValidationContext &context,
                                             const SWV5_PendingRequest &pending,
                                             SWV5_RetryNormalizationFreshnessEvidence &evidence)
{
   SWV5_TestMakeVersion(evidence.contract_version);
   evidence.persistence_namespace=pending.intent.persistence_namespace;
   evidence.ownership_fence=pending.intent.ownership_fence;
   evidence.request_identity=pending.intent.request_identity;
   evidence.account_mode=pending.account_mode;
   evidence.expected_basket_version=pending.intent.expected_basket_version;
   evidence.symbol_specification_sequence=pending.intent.symbol_specification_sequence;
   evidence.intent_type=pending.intent.intent_type;
   evidence.direction=pending.intent.direction;
   evidence.normalized_volume=pending.intent.normalized_volume;
   evidence.normalized_price=pending.intent.normalized_price;
   evidence.normalized_stop_price=pending.intent.normalized_stop_price;
   evidence.normalized_limit_price=pending.intent.normalized_limit_price;
   evidence.normalization_identity=pending.normalization_identity;
   evidence.evidenced_at=context.clock_time;
   evidence.evidence_sequence=context.evaluation_sequence;
   evidence.issuing_component=SWV5_COMPONENT_AUTHORITY_UNIT_SYSTEM;
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
   record.pending_request.last_changed_at=SWV5_TEST_TIME-ordinal;
   record.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   record.record_sequence=20+(ulong)ordinal;
   record.recorded_at=SWV5_TEST_TIME;
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
   return SWV5_TestCanonicalField("contract_name","s",value.contract_name)+
          SWV5_TestCanonicalIntegerField("schema_version",value.schema_version)+
          SWV5_TestCanonicalIntegerField("minimum_compatible_version",value.minimum_compatible_version)+
          SWV5_TestCanonicalField("policy_id","s",value.policy_id);
}

string SWV5_TestCanonicalOwnershipKey(const SWV5_OwnershipKey &value)
{
   return SWV5_TestCanonicalIntegerField("account_login",value.account_login)+
          SWV5_TestCanonicalField("broker_identity","s",value.broker_identity)+
          SWV5_TestCanonicalField("server","s",value.server)+
          SWV5_TestCanonicalField("symbol","s",value.symbol)+
          SWV5_TestCanonicalField("strategy_id","s",value.strategy_id)+
          SWV5_TestCanonicalUnsignedField("magic",value.magic);
}

string SWV5_TestCanonicalOwner(const SWV5_OwnerIdentity &value)
{
   return SWV5_TestCanonicalField("key","x",SWV5_TestCanonicalOwnershipKey(value.key))+
          SWV5_TestCanonicalField("instance_id","s",value.instance_id)+
          SWV5_TestCanonicalField("process_fingerprint","s",value.process_fingerprint)+
          SWV5_TestCanonicalIntegerField("started_at",value.started_at);
}

string SWV5_TestCanonicalFence(const SWV5_OwnershipFence &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("ownership_namespace","x",SWV5_TestCanonicalOwnershipKey(value.ownership_namespace))+
          SWV5_TestCanonicalField("owner","x",SWV5_TestCanonicalOwner(value.owner))+
          SWV5_TestCanonicalUnsignedField("lease_version",value.lease_version)+
          SWV5_TestCanonicalUnsignedField("takeover_generation",value.takeover_generation)+
          SWV5_TestCanonicalField("fencing_token_digest","s",value.fencing_token_digest);
}

string SWV5_TestCanonicalNamespace(const SWV5_PersistenceNamespace &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("ownership_namespace","x",SWV5_TestCanonicalOwnershipKey(value.ownership_namespace))+
          SWV5_TestCanonicalField("basket_id","s",value.basket_id.value);
}

string SWV5_TestCanonicalRequestIdentity(const SWV5_ExecutionRequestIdentity &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("correlation_id","s",value.request_id.correlation_id)+
          SWV5_TestCanonicalField("attempt_id","s",value.request_id.attempt_id)+
          SWV5_TestCanonicalField("parent_attempt_id","s",value.request_id.parent_attempt_id)+
          SWV5_TestCanonicalUnsignedField("monotonic_sequence",value.request_id.monotonic_sequence)+
          SWV5_TestCanonicalIntegerField("created_at",value.request_id.created_at)+
          SWV5_TestCanonicalField("idempotency_key","s",value.idempotency_key);
}

string SWV5_TestCanonicalBrokerIdentity(const SWV5_BrokerExecutionIdentity &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalUnsignedField("order_ticket",value.order_ticket)+
          SWV5_TestCanonicalUnsignedField("deal_ticket",value.deal_ticket)+
          SWV5_TestCanonicalUnsignedField("position_identifier",value.position_identifier)+
          SWV5_TestCanonicalField("broker_event_id","s",value.broker_event_id)+
          SWV5_TestCanonicalUnsignedField("transaction_sequence",value.transaction_sequence);
}

string SWV5_TestCanonicalCorrelation(const SWV5_ExecutionCorrelation &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalIntegerField("phase",(long)value.phase)+
          SWV5_TestCanonicalField("request_identity","x",SWV5_TestCanonicalRequestIdentity(value.request_identity))+
          SWV5_TestCanonicalField("broker_identity","x",SWV5_TestCanonicalBrokerIdentity(value.broker_identity));
}

string SWV5_TestCanonicalField(const string name,const string type,const string value)
{
   return name+":"+type+":"+IntegerToString(StringLen(value))+":"+value;
}

string SWV5_TestCanonicalIntegerField(const string name,const long value)
{
   return SWV5_TestCanonicalField(name,"i",IntegerToString(value));
}

string SWV5_TestCanonicalUnsignedField(const string name,const ulong value)
{
   return SWV5_TestCanonicalField(name,"u",StringFormat("%I64u",value));
}

string SWV5_TestCanonicalDoubleField(const string name,const double value)
{
   // Contract identity uses a locale-independent fixed 16-decimal representation.
   // Deterministic negative zero is normalized to positive zero before encoding.
   const double normalized=(MathAbs(value)<0.00000000000000005 ? 0.0 : value);
   return SWV5_TestCanonicalField(name,"d",DoubleToString(normalized,16));
}

string SWV5_TestCanonicalBoolField(const string name,const bool value)
{
   return SWV5_TestCanonicalField(name,"b",value ? "1" : "0");
}

string SWV5_TestCanonicalTransactionEvidence(const SWV5_TransactionEvidence &value)
{
   string canonical=SWV5_TestCanonicalField("format","s","SWV5-EXECUTION-EVIDENCE-FINGERPRINT-V1");
   canonical+=SWV5_TestCanonicalField("contract_name","s",value.contract_version.contract_name);
   canonical+=SWV5_TestCanonicalUnsignedField("schema_version",value.contract_version.schema_version);
   canonical+=SWV5_TestCanonicalUnsignedField("minimum_compatible_version",value.contract_version.minimum_compatible_version);
   canonical+=SWV5_TestCanonicalField("policy_id","s",value.contract_version.policy_id);
   canonical+=SWV5_TestCanonicalField("namespace_contract_name","s",value.persistence_namespace.contract_version.contract_name);
   canonical+=SWV5_TestCanonicalUnsignedField("namespace_schema_version",value.persistence_namespace.contract_version.schema_version);
   canonical+=SWV5_TestCanonicalUnsignedField("namespace_minimum_compatible_version",value.persistence_namespace.contract_version.minimum_compatible_version);
   canonical+=SWV5_TestCanonicalField("namespace_policy_id","s",value.persistence_namespace.contract_version.policy_id);
   canonical+=SWV5_TestCanonicalIntegerField("namespace_account_login",value.persistence_namespace.ownership_namespace.account_login);
   canonical+=SWV5_TestCanonicalField("namespace_broker","s",value.persistence_namespace.ownership_namespace.broker_identity);
   canonical+=SWV5_TestCanonicalField("namespace_server","s",value.persistence_namespace.ownership_namespace.server);
   canonical+=SWV5_TestCanonicalField("namespace_symbol","s",value.persistence_namespace.ownership_namespace.symbol);
   canonical+=SWV5_TestCanonicalField("namespace_strategy","s",value.persistence_namespace.ownership_namespace.strategy_id);
   canonical+=SWV5_TestCanonicalUnsignedField("namespace_magic",value.persistence_namespace.ownership_namespace.magic);
   canonical+=SWV5_TestCanonicalField("basket_id","s",value.persistence_namespace.basket_id.value);
   canonical+=SWV5_TestCanonicalField("fence_contract_name","s",value.ownership_fence.contract_version.contract_name);
   canonical+=SWV5_TestCanonicalUnsignedField("fence_schema_version",value.ownership_fence.contract_version.schema_version);
   canonical+=SWV5_TestCanonicalUnsignedField("fence_minimum_compatible_version",value.ownership_fence.contract_version.minimum_compatible_version);
   canonical+=SWV5_TestCanonicalField("fence_policy_id","s",value.ownership_fence.contract_version.policy_id);
   canonical+=SWV5_TestCanonicalIntegerField("fence_account_login",value.ownership_fence.ownership_namespace.account_login);
   canonical+=SWV5_TestCanonicalField("fence_broker","s",value.ownership_fence.ownership_namespace.broker_identity);
   canonical+=SWV5_TestCanonicalField("fence_server","s",value.ownership_fence.ownership_namespace.server);
   canonical+=SWV5_TestCanonicalField("fence_symbol","s",value.ownership_fence.ownership_namespace.symbol);
   canonical+=SWV5_TestCanonicalField("fence_strategy","s",value.ownership_fence.ownership_namespace.strategy_id);
   canonical+=SWV5_TestCanonicalUnsignedField("fence_magic",value.ownership_fence.ownership_namespace.magic);
   canonical+=SWV5_TestCanonicalIntegerField("owner_account_login",value.ownership_fence.owner.key.account_login);
   canonical+=SWV5_TestCanonicalField("owner_broker","s",value.ownership_fence.owner.key.broker_identity);
   canonical+=SWV5_TestCanonicalField("owner_server","s",value.ownership_fence.owner.key.server);
   canonical+=SWV5_TestCanonicalField("owner_symbol","s",value.ownership_fence.owner.key.symbol);
   canonical+=SWV5_TestCanonicalField("owner_strategy","s",value.ownership_fence.owner.key.strategy_id);
   canonical+=SWV5_TestCanonicalUnsignedField("owner_magic",value.ownership_fence.owner.key.magic);
   canonical+=SWV5_TestCanonicalField("owner_instance_id","s",value.ownership_fence.owner.instance_id);
   canonical+=SWV5_TestCanonicalField("owner_process_fingerprint","s",value.ownership_fence.owner.process_fingerprint);
   canonical+=SWV5_TestCanonicalIntegerField("owner_started_at",value.ownership_fence.owner.started_at);
   canonical+=SWV5_TestCanonicalUnsignedField("lease_version",value.ownership_fence.lease_version);
   canonical+=SWV5_TestCanonicalUnsignedField("takeover_generation",value.ownership_fence.takeover_generation);
   canonical+=SWV5_TestCanonicalField("fencing_token_digest","s",value.ownership_fence.fencing_token_digest);
   canonical+=SWV5_TestCanonicalField("request_contract_name","s",value.correlation.request_identity.contract_version.contract_name);
   canonical+=SWV5_TestCanonicalUnsignedField("request_schema_version",value.correlation.request_identity.contract_version.schema_version);
   canonical+=SWV5_TestCanonicalUnsignedField("request_minimum_compatible_version",value.correlation.request_identity.contract_version.minimum_compatible_version);
   canonical+=SWV5_TestCanonicalField("request_policy_id","s",value.correlation.request_identity.contract_version.policy_id);
   canonical+=SWV5_TestCanonicalField("correlation_id","s",value.correlation.request_identity.request_id.correlation_id);
   canonical+=SWV5_TestCanonicalField("attempt_id","s",value.correlation.request_identity.request_id.attempt_id);
   canonical+=SWV5_TestCanonicalField("parent_attempt_id","s",value.correlation.request_identity.request_id.parent_attempt_id);
   canonical+=SWV5_TestCanonicalUnsignedField("request_monotonic_sequence",value.correlation.request_identity.request_id.monotonic_sequence);
   canonical+=SWV5_TestCanonicalIntegerField("request_created_at",value.correlation.request_identity.request_id.created_at);
   canonical+=SWV5_TestCanonicalField("idempotency_key","s",value.correlation.request_identity.idempotency_key);
   canonical+=SWV5_TestCanonicalIntegerField("execution_phase",(long)value.correlation.phase);
   canonical+=SWV5_TestCanonicalUnsignedField("order_ticket",value.correlation.broker_identity.order_ticket);
   canonical+=SWV5_TestCanonicalUnsignedField("deal_ticket",value.correlation.broker_identity.deal_ticket);
   canonical+=SWV5_TestCanonicalUnsignedField("position_identifier",value.correlation.broker_identity.position_identifier);
   canonical+=SWV5_TestCanonicalField("broker_event_id","s",value.correlation.broker_identity.broker_event_id);
   canonical+=SWV5_TestCanonicalUnsignedField("transaction_sequence",value.correlation.broker_identity.transaction_sequence);
   canonical+=SWV5_TestCanonicalIntegerField("event_kind",(long)value.event_kind);
   canonical+=SWV5_TestCanonicalDoubleField("confirmed_volume",value.confirmed_volume);
   canonical+=SWV5_TestCanonicalDoubleField("confirmed_price",value.confirmed_price);
   canonical+=SWV5_TestCanonicalUnsignedField("symbol_specification_sequence",value.symbol_specification_sequence);
   canonical+=SWV5_TestCanonicalUnsignedField("expected_basket_version",value.expected_basket_version);
   canonical+=SWV5_TestCanonicalIntegerField("transaction_time",value.transaction_time);
   canonical+=SWV5_TestCanonicalIntegerField("received_at",value.received_at);
   canonical+=SWV5_TestCanonicalIntegerField("authority",(long)value.authority);
   canonical+=SWV5_TestCanonicalBoolField("history_cross_checked",value.history_cross_checked);
   return canonical;
}

string SWV5_TestCanonicalRecoveryTransition(const SWV5_BasketTransitionRequest &value)
{
   string canonical=SWV5_TestCanonicalField("format","s","SWV5-RECOVERY-EVIDENCE-FINGERPRINT-V1");
   canonical+=SWV5_TestCanonicalField("contract_name","s",value.contract_version.contract_name);
   canonical+=SWV5_TestCanonicalUnsignedField("schema_version",value.contract_version.schema_version);
   canonical+=SWV5_TestCanonicalUnsignedField("minimum_compatible_version",value.contract_version.minimum_compatible_version);
   canonical+=SWV5_TestCanonicalField("policy_id","s",value.contract_version.policy_id);
   canonical+=SWV5_TestCanonicalField("basket_id","s",value.basket_id.value);
   canonical+=SWV5_TestCanonicalIntegerField("fence_account_login",value.ownership_fence.ownership_namespace.account_login);
   canonical+=SWV5_TestCanonicalField("fence_broker","s",value.ownership_fence.ownership_namespace.broker_identity);
   canonical+=SWV5_TestCanonicalField("fence_server","s",value.ownership_fence.ownership_namespace.server);
   canonical+=SWV5_TestCanonicalField("fence_symbol","s",value.ownership_fence.ownership_namespace.symbol);
   canonical+=SWV5_TestCanonicalField("fence_strategy","s",value.ownership_fence.ownership_namespace.strategy_id);
   canonical+=SWV5_TestCanonicalUnsignedField("fence_magic",value.ownership_fence.ownership_namespace.magic);
   canonical+=SWV5_TestCanonicalField("owner_instance_id","s",value.ownership_fence.owner.instance_id);
   canonical+=SWV5_TestCanonicalField("owner_process_fingerprint","s",value.ownership_fence.owner.process_fingerprint);
   canonical+=SWV5_TestCanonicalIntegerField("owner_started_at",value.ownership_fence.owner.started_at);
   canonical+=SWV5_TestCanonicalUnsignedField("lease_version",value.ownership_fence.lease_version);
   canonical+=SWV5_TestCanonicalUnsignedField("takeover_generation",value.ownership_fence.takeover_generation);
   canonical+=SWV5_TestCanonicalField("fencing_token_digest","s",value.ownership_fence.fencing_token_digest);
   canonical+=SWV5_TestCanonicalIntegerField("from_state",(long)value.from_state);
   canonical+=SWV5_TestCanonicalIntegerField("to_state",(long)value.to_state);
   canonical+=SWV5_TestCanonicalIntegerField("cause",(long)value.cause);
   canonical+=SWV5_TestCanonicalUnsignedField("expected_state_version",value.expected_state_version);
   canonical+=SWV5_TestCanonicalField("correlation_id","s",value.correlation.request_identity.request_id.correlation_id);
   canonical+=SWV5_TestCanonicalField("attempt_id","s",value.correlation.request_identity.request_id.attempt_id);
   canonical+=SWV5_TestCanonicalField("parent_attempt_id","s",value.correlation.request_identity.request_id.parent_attempt_id);
   canonical+=SWV5_TestCanonicalUnsignedField("request_monotonic_sequence",value.correlation.request_identity.request_id.monotonic_sequence);
   canonical+=SWV5_TestCanonicalIntegerField("request_created_at",value.correlation.request_identity.request_id.created_at);
   canonical+=SWV5_TestCanonicalField("idempotency_key","s",value.correlation.request_identity.idempotency_key);
   canonical+=SWV5_TestCanonicalField("recovery_correlation_id","s",value.recovery_evidence.request_identity.request_id.correlation_id);
   canonical+=SWV5_TestCanonicalField("recovery_attempt_id","s",value.recovery_evidence.request_identity.request_id.attempt_id);
   canonical+=SWV5_TestCanonicalField("recovery_parent_attempt_id","s",value.recovery_evidence.request_identity.request_id.parent_attempt_id);
   canonical+=SWV5_TestCanonicalUnsignedField("recovery_request_sequence",value.recovery_evidence.request_identity.request_id.monotonic_sequence);
   canonical+=SWV5_TestCanonicalIntegerField("recovery_request_created_at",value.recovery_evidence.request_identity.request_id.created_at);
   canonical+=SWV5_TestCanonicalField("recovery_idempotency_key","s",value.recovery_evidence.request_identity.idempotency_key);
   canonical+=SWV5_TestCanonicalUnsignedField("prior_recovery_attempts",value.recovery_evidence.prior_cumulative_recovery_attempts);
   canonical+=SWV5_TestCanonicalUnsignedField("proposed_recovery_attempts",value.recovery_evidence.proposed_cumulative_recovery_attempts);
   canonical+=SWV5_TestCanonicalUnsignedField("prior_recovery_layer",value.recovery_evidence.prior_recovery_layer);
   canonical+=SWV5_TestCanonicalUnsignedField("proposed_recovery_layer",value.recovery_evidence.proposed_recovery_layer);
   canonical+=SWV5_TestCanonicalField("authorization_id","s",value.recovery_evidence.authorization_id);
   canonical+=SWV5_TestCanonicalField("evidence_identity","s",value.recovery_evidence.evidence_identity);
   canonical+=SWV5_TestCanonicalUnsignedField("evidence_sequence",value.recovery_evidence.evidence_sequence);
   canonical+=SWV5_TestCanonicalIntegerField("evidenced_at",value.recovery_evidence.evidenced_at);
   canonical+=SWV5_TestCanonicalIntegerField("evidence_time",value.evidence_time);
   canonical+=SWV5_TestCanonicalIntegerField("risk_disposition",(long)value.risk_decision.disposition);
   canonical+=SWV5_TestCanonicalUnsignedField("risk_reason_flags",value.risk_decision.reason_flags);
   canonical+=SWV5_TestCanonicalField("risk_reason_code","s",value.risk_decision.reason_code);
   canonical+=SWV5_TestCanonicalUnsignedField("risk_evaluation_sequence",value.risk_decision.evaluation_sequence);
   canonical+=SWV5_TestCanonicalIntegerField("risk_evaluated_at",value.risk_decision.evaluated_at);
   canonical+=SWV5_TestCanonicalIntegerField("reconciliation_state",(long)value.reconciliation_state);
   canonical+=SWV5_TestCanonicalDoubleField("residual_volume",value.residual_volume);
   canonical+=SWV5_TestCanonicalUnsignedField("live_position_count",value.live_position_count);
   canonical+=SWV5_TestCanonicalUnsignedField("live_order_count",value.live_order_count);
   canonical+=SWV5_TestCanonicalUnsignedField("pending_request_count",value.pending_request_count);
   canonical+=SWV5_TestCanonicalUnsignedField("query_required_flags",value.broker_queries.required_flags);
   canonical+=SWV5_TestCanonicalUnsignedField("query_completed_flags",value.broker_queries.completed_flags);
   canonical+=SWV5_TestCanonicalUnsignedField("query_authoritative_flags",value.broker_queries.authoritative_flags);
   canonical+=SWV5_TestCanonicalUnsignedField("query_observation_sequence",value.broker_queries.observation_sequence);
   canonical+=SWV5_TestCanonicalIntegerField("confirmation_authority",(long)value.confirmation_authority);
   return canonical;
}

string SWV5_TestCanonicalDecision(const SWV5_ContractDecision &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalIntegerField("disposition",(long)value.disposition)+
          SWV5_TestCanonicalUnsignedField("reason_flags",value.reason_flags)+
          SWV5_TestCanonicalField("reason_code","s",value.reason_code)+
          SWV5_TestCanonicalField("reason_text","s",value.reason_text)+
          SWV5_TestCanonicalIntegerField("evaluated_schema_version",value.evaluated_schema_version)+
          SWV5_TestCanonicalUnsignedField("evaluation_sequence",value.evaluation_sequence)+
          SWV5_TestCanonicalIntegerField("evaluated_at",value.evaluated_at);
}

string SWV5_TestCanonicalIntent(const SWV5_ExecutionIntent &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(value.persistence_namespace))+
          SWV5_TestCanonicalField("ownership_fence","x",SWV5_TestCanonicalFence(value.ownership_fence))+
          SWV5_TestCanonicalField("request_identity","x",SWV5_TestCanonicalRequestIdentity(value.request_identity))+
          SWV5_TestCanonicalIntegerField("account_mode",(long)value.account_mode)+
          SWV5_TestCanonicalIntegerField("intent_type",(long)value.intent_type)+
          SWV5_TestCanonicalIntegerField("direction",value.direction)+
          SWV5_TestCanonicalDoubleField("normalized_volume",value.normalized_volume)+
          SWV5_TestCanonicalDoubleField("normalized_price",value.normalized_price)+
          SWV5_TestCanonicalDoubleField("normalized_stop_price",value.normalized_stop_price)+
          SWV5_TestCanonicalDoubleField("normalized_limit_price",value.normalized_limit_price)+
          SWV5_TestCanonicalUnsignedField("symbol_specification_sequence",value.symbol_specification_sequence)+
          SWV5_TestCanonicalUnsignedField("expected_basket_version",value.expected_basket_version)+
          SWV5_TestCanonicalField("risk_authorization_id","s",value.risk_authorization_id)+
          SWV5_TestCanonicalIntegerField("authorization_expires_at",value.authorization_expires_at);
}

string SWV5_TestCanonicalEventSet(const SWV5_DurableEventIdentitySet &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalIntegerField("fingerprint_policy",(long)value.fingerprint_policy)+
          SWV5_TestCanonicalField("canonical_event_index","s",value.canonical_event_index)+
          SWV5_TestCanonicalField("canonical_fingerprint_index","s",value.canonical_fingerprint_index)+
          SWV5_TestCanonicalField("identity_set_digest","s",value.identity_set_digest)+
          SWV5_TestCanonicalUnsignedField("accepted_identity_count",value.accepted_identity_count)+
          SWV5_TestCanonicalUnsignedField("highest_transaction_sequence",value.highest_transaction_sequence)+
          SWV5_TestCanonicalUnsignedField("index_revision",value.index_revision)+
          SWV5_TestCanonicalUnsignedField("compaction_generation",value.compaction_generation);
}

string SWV5_TestCanonicalDurableEventEntry(const string event_id,const ulong sequence)
{
   const string identity=SWV5_TestCanonicalField("event_id","s",event_id)+
                         SWV5_TestCanonicalUnsignedField("transaction_sequence",sequence);
   return SWV5_TestCanonicalField("entry","x",identity);
}

string SWV5_TestEventSetDigest(const SWV5_DurableEventIdentitySet &set)
{
   const string canonical=SWV5_TestCanonicalField("format","s","SWV5-DURABLE-EVENT-SET-V"+IntegerToString(SWV5_PRODUCTION_CONTRACT_VERSION)+"-LP1")+
                          SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(set.contract_version))+
                          SWV5_TestCanonicalIntegerField("fingerprint_policy",(long)set.fingerprint_policy)+
                          SWV5_TestCanonicalField("canonical_event_index","x",set.canonical_event_index)+
                          SWV5_TestCanonicalField("canonical_fingerprint_index","x",set.canonical_fingerprint_index)+
                          SWV5_TestCanonicalUnsignedField("accepted_identity_count",set.accepted_identity_count)+
                          SWV5_TestCanonicalUnsignedField("highest_transaction_sequence",set.highest_transaction_sequence)+
                          SWV5_TestCanonicalUnsignedField("index_revision",set.index_revision)+
                          SWV5_TestCanonicalUnsignedField("compaction_generation",set.compaction_generation);
   return SWV5_TestCanonicalHash(canonical);
}

string SWV5_TestCanonicalPending(const SWV5_PendingRequest &value)
{
   string submission=SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.latest_submission.contract_version))+
                     SWV5_TestCanonicalField("request_identity","x",SWV5_TestCanonicalRequestIdentity(value.latest_submission.request_identity))+
                     SWV5_TestCanonicalUnsignedField("submission_attempt_count",value.latest_submission.submission_attempt_count)+
                     SWV5_TestCanonicalIntegerField("submitted_at",value.latest_submission.submitted_at)+
                     SWV5_TestCanonicalIntegerField("authority",(long)value.latest_submission.authority);
   string retcode=SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.latest_retcode.contract_version))+
                  SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(value.latest_retcode.persistence_namespace))+
                  SWV5_TestCanonicalField("ownership_fence","x",SWV5_TestCanonicalFence(value.latest_retcode.ownership_fence))+
                  SWV5_TestCanonicalField("correlation","x",SWV5_TestCanonicalCorrelation(value.latest_retcode.correlation))+
                  SWV5_TestCanonicalUnsignedField("raw_retcode",value.latest_retcode.raw_retcode)+
                  SWV5_TestCanonicalField("broker_comment","s",value.latest_retcode.broker_comment)+
                  SWV5_TestCanonicalIntegerField("observed_at",value.latest_retcode.observed_at);
   string classification=SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.latest_retcode_classification.contract_version))+
                         SWV5_TestCanonicalIntegerField("classification",(long)value.latest_retcode_classification.classification)+
                         SWV5_TestCanonicalIntegerField("retry_disposition",(long)value.latest_retcode_classification.retry_disposition)+
                         SWV5_TestCanonicalField("mapping_policy_id","s",value.latest_retcode_classification.mapping_policy_id)+
                         SWV5_TestCanonicalField("decision","x",SWV5_TestCanonicalDecision(value.latest_retcode_classification.decision));
   string confirmation=SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.latest_authoritative_confirmation.contract_version))+
                       SWV5_TestCanonicalField("correlation","x",SWV5_TestCanonicalCorrelation(value.latest_authoritative_confirmation.correlation))+
                       SWV5_TestCanonicalIntegerField("status",(long)value.latest_authoritative_confirmation.status)+
                       SWV5_TestCanonicalDoubleField("cumulative_confirmed_volume",value.latest_authoritative_confirmation.cumulative_confirmed_volume)+
                       SWV5_TestCanonicalDoubleField("residual_volume",value.latest_authoritative_confirmation.residual_volume)+
                       SWV5_TestCanonicalIntegerField("authority",(long)value.latest_authoritative_confirmation.authority)+
                       SWV5_TestCanonicalUnsignedField("confirmation_sequence",value.latest_authoritative_confirmation.confirmation_sequence)+
                       SWV5_TestCanonicalIntegerField("confirmed_at",value.latest_authoritative_confirmation.confirmed_at);
   string text=SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
               SWV5_TestCanonicalField("intent","x",SWV5_TestCanonicalIntent(value.intent))+
               SWV5_TestCanonicalIntegerField("account_mode",(long)value.account_mode)+
               SWV5_TestCanonicalIntegerField("lifecycle_phase",(long)value.lifecycle_phase)+
               SWV5_TestCanonicalIntegerField("state",(long)value.state)+
               SWV5_TestCanonicalUnsignedField("submission_attempt_count",value.submission_attempt_count)+
               SWV5_TestCanonicalField("latest_submission","x",submission)+
               SWV5_TestCanonicalField("latest_retcode","x",retcode)+
               SWV5_TestCanonicalField("latest_retcode_classification","x",classification)+
               SWV5_TestCanonicalField("latest_authoritative_confirmation","x",confirmation)+
               SWV5_TestCanonicalDoubleField("cumulative_confirmed_volume",value.cumulative_confirmed_volume)+
               SWV5_TestCanonicalDoubleField("residual_requested_volume",value.residual_requested_volume)+
               SWV5_TestCanonicalField("accepted_event_identities","x",SWV5_TestCanonicalEventSet(value.accepted_event_identities))+
               SWV5_TestCanonicalIntegerField("retry_disposition",(long)value.retry_disposition)+
               SWV5_TestCanonicalField("authorization_identity","s",value.authorization_identity)+
               SWV5_TestCanonicalField("normalization_identity","s",value.normalization_identity)+
               SWV5_TestCanonicalIntegerField("last_changed_at",value.last_changed_at);
   return text;
}

string SWV5_TestCanonicalPersistedRequest(const SWV5_PersistedRequestEvidence &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(value.persistence_namespace))+
          SWV5_TestCanonicalField("ownership_fence","x",SWV5_TestCanonicalFence(value.ownership_fence))+
          SWV5_TestCanonicalField("pending_request","x",SWV5_TestCanonicalPending(value.pending_request))+
          SWV5_TestCanonicalIntegerField("account_mode",(long)value.account_mode)+
          SWV5_TestCanonicalUnsignedField("record_sequence",value.record_sequence)+
          SWV5_TestCanonicalIntegerField("recorded_at",value.recorded_at);
}

string SWV5_TestCanonicalQueries(const SWV5_AuthoritativeQuerySet &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalUnsignedField("required_flags",value.required_flags)+
          SWV5_TestCanonicalUnsignedField("completed_flags",value.completed_flags)+
          SWV5_TestCanonicalUnsignedField("authoritative_flags",value.authoritative_flags)+
          SWV5_TestCanonicalUnsignedField("observation_sequence",value.observation_sequence)+
          SWV5_TestCanonicalIntegerField("observed_at",value.observed_at)+
          SWV5_TestCanonicalIntegerField("issuing_component",(long)value.issuing_component)+
          SWV5_TestCanonicalIntegerField("authority_source",(long)value.authority_source)+
          SWV5_TestCanonicalField("snapshot_id","s",value.snapshot_id)+
          SWV5_TestCanonicalField("snapshot_digest","s",value.snapshot_digest);
}

string SWV5_TestQuerySnapshotDigest(const SWV5_AuthoritativeQuerySet &queries)
{
   SWV5_AuthoritativeQuerySet canonical=queries;
   canonical.snapshot_digest="";
   return SWV5_TestCanonicalHash(SWV5_TestCanonicalField("format","s","SWV5-QUERY-SNAPSHOT-V5-LP1")+
                                 SWV5_TestCanonicalQueries(canonical));
}

void SWV5_TestSealQuerySnapshot(SWV5_AuthoritativeQuerySet &queries)
{
   queries.snapshot_digest="";
   queries.snapshot_digest=SWV5_TestQuerySnapshotDigest(queries);
}

string SWV5_TestCanonicalAcceptedQueryWatermarkProposal(const SWV5_AcceptedQueryWatermarkProposal &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(value.persistence_namespace))+
          SWV5_TestCanonicalField("ownership_fence","x",SWV5_TestCanonicalFence(value.ownership_fence))+
          SWV5_TestCanonicalField("expected_store_revision","s",value.expected_store_revision)+
          SWV5_TestCanonicalUnsignedField("expected_record_sequence",value.expected_record_sequence)+
          SWV5_TestCanonicalUnsignedField("accepted_broker_query_high_watermark",value.accepted_broker_query_high_watermark)+
          SWV5_TestCanonicalUnsignedField("accepted_execution_query_high_watermark",value.accepted_execution_query_high_watermark)+
          SWV5_TestCanonicalUnsignedField("broker_snapshot_observation_sequence",value.broker_snapshot_observation_sequence)+
          SWV5_TestCanonicalUnsignedField("execution_snapshot_observation_sequence",value.execution_snapshot_observation_sequence)+
          SWV5_TestCanonicalUnsignedField("next_reconciliation_revision",value.next_reconciliation_revision)+
          SWV5_TestCanonicalField("proposal_digest","s",value.proposal_digest);
}

string SWV5_TestAcceptedQueryWatermarkProposalDigest(const SWV5_AcceptedQueryWatermarkProposal &proposal)
{
   SWV5_AcceptedQueryWatermarkProposal canonical=proposal;
   canonical.proposal_digest="";
   return SWV5_TestCanonicalHash(SWV5_TestCanonicalField("format","s","SWV5-ACCEPTED-QUERY-WATERMARK-PROPOSAL-V5-LP1")+
                                 SWV5_TestCanonicalAcceptedQueryWatermarkProposal(canonical));
}

void SWV5_TestSealAcceptedQueryWatermarkProposal(SWV5_AcceptedQueryWatermarkProposal &proposal)
{
   proposal.proposal_digest="";
   proposal.proposal_digest=SWV5_TestAcceptedQueryWatermarkProposalDigest(proposal);
}

string SWV5_TestCanonicalAccountNamespace(const SWV5_AccountRiskNamespace &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("broker_identity","s",value.broker_identity)+
          SWV5_TestCanonicalField("server","s",value.server)+
          SWV5_TestCanonicalIntegerField("account_login",value.account_login)+
          SWV5_TestCanonicalField("account_currency","s",value.account_currency)+
          SWV5_TestCanonicalField("strategy_id","s",value.strategy_id)+
          SWV5_TestCanonicalUnsignedField("magic",value.magic)+
          SWV5_TestCanonicalIntegerField("account_mode",(long)value.account_mode)+
          SWV5_TestCanonicalIntegerField("authoritative_source",(long)value.authoritative_source)+
          SWV5_TestCanonicalUnsignedField("snapshot_epoch",value.snapshot_epoch)+
          SWV5_TestCanonicalUnsignedField("snapshot_sequence",value.snapshot_sequence);
}

string SWV5_TestCanonicalRiskMonetaryBasis(const SWV5_RiskMonetaryBasis &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("currency","s",value.currency)+
          SWV5_TestCanonicalField("account_currency","s",value.account_currency)+
          SWV5_TestCanonicalDoubleField("conversion_rate_to_account_currency",value.conversion_rate_to_account_currency)+
          SWV5_TestCanonicalField("conversion_source","s",value.conversion_source)+
          SWV5_TestCanonicalIntegerField("valuation_at",value.valuation_at)+
          SWV5_TestCanonicalIntegerField("calculation_basis",(long)value.calculation_basis)+
          SWV5_TestCanonicalIntegerField("sign_convention",(long)value.sign_convention)+
          SWV5_TestCanonicalBoolField("includes_realized",value.includes_realized)+
          SWV5_TestCanonicalBoolField("includes_unrealized",value.includes_unrealized)+
          SWV5_TestCanonicalBoolField("includes_commission",value.includes_commission)+
          SWV5_TestCanonicalBoolField("includes_swap",value.includes_swap)+
          SWV5_TestCanonicalBoolField("includes_fee",value.includes_fee);
}

string SWV5_TestCanonicalSymbolUnitSpecification(const SWV5_SymbolUnitSpecification &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("symbol","s",value.symbol)+
          SWV5_TestCanonicalUnsignedField("specification_sequence",value.specification_sequence)+
          SWV5_TestCanonicalIntegerField("digits",value.digits)+
          SWV5_TestCanonicalDoubleField("point_size",value.point_size)+
          SWV5_TestCanonicalDoubleField("tick_size",value.tick_size)+
          SWV5_TestCanonicalDoubleField("pip_size",value.pip_size)+
          SWV5_TestCanonicalDoubleField("tick_value_profit",value.tick_value_profit)+
          SWV5_TestCanonicalDoubleField("tick_value_loss",value.tick_value_loss)+
          SWV5_TestCanonicalDoubleField("contract_size",value.contract_size)+
          SWV5_TestCanonicalIntegerField("calculation_mode",(long)value.calculation_mode)+
          SWV5_TestCanonicalDoubleField("tick_value_basis_volume",value.tick_value_basis_volume)+
          SWV5_TestCanonicalDoubleField("volume_minimum",value.volume_minimum)+
          SWV5_TestCanonicalDoubleField("volume_maximum",value.volume_maximum)+
          SWV5_TestCanonicalDoubleField("volume_step",value.volume_step)+
          SWV5_TestCanonicalIntegerField("stops_level_points",value.stops_level_points)+
          SWV5_TestCanonicalIntegerField("freeze_level_points",value.freeze_level_points)+
          SWV5_TestCanonicalField("account_currency","s",value.account_currency)+
          SWV5_TestCanonicalField("tick_value_currency","s",value.tick_value_currency)+
          SWV5_TestCanonicalIntegerField("authority_source",(long)value.authority_source)+
          SWV5_TestCanonicalIntegerField("observed_at",value.observed_at)+
          SWV5_TestCanonicalIntegerField("valid_until",value.valid_until)+
          SWV5_TestCanonicalBoolField("complete",value.complete);
}

string SWV5_TestSymbolUnitSpecificationDigest(const SWV5_SymbolUnitSpecification &value)
{
   return SWV5_TestCanonicalHash(SWV5_TestCanonicalField("format","s","SWV5-SYMBOL-UNIT-SPECIFICATION-V5-LP1")+
                                 SWV5_TestCanonicalSymbolUnitSpecification(value));
}

string SWV5_TestCanonicalTypedReconciliation(const SWV5_TypedReconciliationEvidence &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(value.persistence_namespace))+
          SWV5_TestCanonicalField("evidence_id","s",value.evidence_id)+
          SWV5_TestCanonicalIntegerField("issuing_component",(long)value.issuing_component)+
          SWV5_TestCanonicalIntegerField("authority_source",(long)value.authority_source)+
          SWV5_TestCanonicalUnsignedField("evidence_sequence",value.evidence_sequence)+
          SWV5_TestCanonicalIntegerField("observed_at",value.observed_at)+
          SWV5_TestCanonicalField("state_digest","s",value.state_digest);
}

string SWV5_TestCanonicalExposureEvidence(const SWV5_ExposureReductionEvidence &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("evidence_id","s",value.evidence_id)+
          SWV5_TestCanonicalIntegerField("issuing_component",(long)value.issuing_component)+
          SWV5_TestCanonicalIntegerField("authority_source",(long)value.authority_source)+
          SWV5_TestCanonicalDoubleField("observed_exposure_volume",value.observed_exposure_volume)+
          SWV5_TestCanonicalDoubleField("prior_exposure_volume",value.prior_exposure_volume)+
          SWV5_TestCanonicalBoolField("zero_or_reducing",value.zero_or_reducing)+
          SWV5_TestCanonicalUnsignedField("evidence_sequence",value.evidence_sequence)+
          SWV5_TestCanonicalIntegerField("observed_at",value.observed_at);
}

string SWV5_TestCanonicalOperator(const SWV5_OperatorIdentity &value)
{
   return SWV5_TestCanonicalField("operator_id","s",value.operator_id)+
          SWV5_TestCanonicalField("authority_role","s",value.authority_role)+
          SWV5_TestCanonicalField("authentication_reference","s",value.authentication_reference)+
          SWV5_TestCanonicalIntegerField("authenticated_at",value.authenticated_at);
}

string SWV5_TestCanonicalHardKillRelease(const SWV5_HardKillReleaseEvidence &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(value.persistence_namespace))+
          SWV5_TestCanonicalField("release_id","s",value.release_id)+
          SWV5_TestCanonicalField("latch_id","s",value.latch_id)+
          SWV5_TestCanonicalUnsignedField("latch_generation",value.latch_generation)+
           SWV5_TestCanonicalUnsignedField("release_generation",value.release_generation)+
           SWV5_TestCanonicalField("approval_policy_id","s",value.approval_policy_id)+
           SWV5_TestCanonicalUnsignedField("approval_sequence",value.approval_sequence)+
          SWV5_TestCanonicalField("operator_identity","x",SWV5_TestCanonicalOperator(value.operator_identity))+
          SWV5_TestCanonicalIntegerField("approving_component",(long)value.approving_component)+
          SWV5_TestCanonicalField("broker_evidence","x",SWV5_TestCanonicalTypedReconciliation(value.broker_evidence))+
          SWV5_TestCanonicalField("persistence_evidence","x",SWV5_TestCanonicalTypedReconciliation(value.persistence_evidence))+
          SWV5_TestCanonicalField("exposure_evidence","x",SWV5_TestCanonicalExposureEvidence(value.exposure_evidence))+
           SWV5_TestCanonicalIntegerField("approved_at",value.approved_at)+
           SWV5_TestCanonicalIntegerField("released_at",value.released_at)+
           SWV5_TestCanonicalIntegerField("expires_at",value.expires_at)+
           SWV5_TestCanonicalUnsignedField("release_record_sequence",value.release_record_sequence)+
           SWV5_TestCanonicalField("audit_reference","s",value.audit_reference);
}

string SWV5_TestHardKillReleaseDigest(const SWV5_HardKillReleaseEvidence &evidence)
{
   return SWV5_TestCanonicalHash(SWV5_TestCanonicalField("format","s","SWV5-HARD-KILL-RELEASE-V5-LP1")+
                                 SWV5_TestCanonicalHardKillRelease(evidence));
}

string SWV5_TestCanonicalHardKillAuthorityReference(const SWV5_HardKillReleaseAuthorityReference &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("authority_record_id","s",value.authority_record_id)+
          SWV5_TestCanonicalUnsignedField("authority_record_sequence",value.authority_record_sequence)+
          SWV5_TestCanonicalField("authority_record_digest","s",value.authority_record_digest)+
          SWV5_TestCanonicalField("release_id","s",value.release_id)+
          SWV5_TestCanonicalUnsignedField("latch_generation",value.latch_generation)+
          SWV5_TestCanonicalUnsignedField("release_generation",value.release_generation);
}

string SWV5_TestCanonicalHardKillAuthorityRecord(const SWV5_HardKillReleaseAuthorityRecord &record)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(record.contract_version))+
          SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(record.persistence_namespace))+
          SWV5_TestCanonicalField("account_namespace","x",SWV5_TestCanonicalAccountNamespace(record.account_namespace))+
          SWV5_TestCanonicalField("latch_id","s",record.latch_id)+
          SWV5_TestCanonicalUnsignedField("latch_generation",record.latch_generation)+
          SWV5_TestCanonicalField("release_id","s",record.release_id)+
          SWV5_TestCanonicalUnsignedField("release_generation",record.release_generation)+
          SWV5_TestCanonicalField("operator_identity","x",SWV5_TestCanonicalOperator(record.operator_identity))+
          SWV5_TestCanonicalIntegerField("approving_component",(long)record.approving_component)+
          SWV5_TestCanonicalField("approval_policy_id","s",record.approval_policy_id)+
          SWV5_TestCanonicalUnsignedField("approval_sequence",record.approval_sequence)+
          SWV5_TestCanonicalField("broker_evidence_reference","x",SWV5_TestCanonicalTypedReconciliation(record.broker_evidence_reference))+
          SWV5_TestCanonicalField("persistence_evidence_reference","x",SWV5_TestCanonicalTypedReconciliation(record.persistence_evidence_reference))+
          SWV5_TestCanonicalField("exposure_evidence_reference","x",SWV5_TestCanonicalExposureEvidence(record.exposure_evidence_reference))+
          SWV5_TestCanonicalIntegerField("approved_at",record.approved_at)+
          SWV5_TestCanonicalIntegerField("released_at",record.released_at)+
          SWV5_TestCanonicalIntegerField("expires_at",record.expires_at)+
          SWV5_TestCanonicalUnsignedField("release_record_sequence",record.release_record_sequence)+
          SWV5_TestCanonicalField("authority_record_id","s",record.authority_record_id)+
          SWV5_TestCanonicalIntegerField("issuing_component",(long)record.issuing_component)+
          SWV5_TestCanonicalIntegerField("authority_source",(long)record.authority_source);
}

string SWV5_TestHardKillAuthorityRecordDigest(const SWV5_HardKillReleaseAuthorityRecord &record)
{
   return SWV5_TestCanonicalHash(SWV5_TestCanonicalField("format","s","SWV5-HARD-KILL-AUTHORITY-V5-LP1")+
                                 SWV5_TestCanonicalHardKillAuthorityRecord(record));
}

string SWV5_TestCanonicalMarginEvidence(const SWV5_MarginProjectionEvidence &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(value.persistence_namespace))+
          SWV5_TestCanonicalField("account_namespace","x",SWV5_TestCanonicalAccountNamespace(value.account_namespace))+
          SWV5_TestCanonicalField("ownership_fence","x",SWV5_TestCanonicalFence(value.ownership_fence))+
          SWV5_TestCanonicalField("request_identity","x",SWV5_TestCanonicalRequestIdentity(value.request_identity))+
          SWV5_TestCanonicalField("basket_id","s",value.basket_id.value)+
          SWV5_TestCanonicalField("symbol","s",value.symbol)+
          SWV5_TestCanonicalUnsignedField("symbol_specification_sequence",value.symbol_specification_sequence)+
          SWV5_TestCanonicalIntegerField("intent_type",(long)value.intent_type)+
          SWV5_TestCanonicalIntegerField("direction",value.direction)+
          SWV5_TestCanonicalDoubleField("requested_volume",value.requested_volume)+
          SWV5_TestCanonicalDoubleField("requested_price",value.requested_price)+
          SWV5_TestCanonicalDoubleField("current_account_margin",value.current_account_margin)+
          SWV5_TestCanonicalDoubleField("current_free_margin",value.current_free_margin)+
          SWV5_TestCanonicalDoubleField("projected_account_margin",value.projected_account_margin)+
          SWV5_TestCanonicalDoubleField("additional_margin",value.additional_margin)+
          SWV5_TestCanonicalField("account_currency","s",value.account_currency)+
          SWV5_TestCanonicalIntegerField("issuing_component",(long)value.issuing_component)+
          SWV5_TestCanonicalIntegerField("authority_source",(long)value.authority_source)+
          SWV5_TestCanonicalField("calculation_reference","s",value.calculation_reference)+
          SWV5_TestCanonicalIntegerField("observed_at",value.observed_at)+
           SWV5_TestCanonicalIntegerField("calculated_at",value.calculated_at)+
           SWV5_TestCanonicalUnsignedField("evidence_sequence",value.evidence_sequence)+
           SWV5_TestCanonicalField("authority_record_id","s",value.authority_record_id)+
           SWV5_TestCanonicalUnsignedField("authority_record_sequence",value.authority_record_sequence)+
           SWV5_TestCanonicalField("authority_record_digest","s",value.authority_record_digest);
}

string SWV5_TestCanonicalMarginAuthority(const SWV5_MarginAuthorityRecord &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(value.persistence_namespace))+
          SWV5_TestCanonicalField("account_namespace","x",SWV5_TestCanonicalAccountNamespace(value.account_namespace))+
          SWV5_TestCanonicalField("ownership_fence","x",SWV5_TestCanonicalFence(value.ownership_fence))+
          SWV5_TestCanonicalField("request_identity","x",SWV5_TestCanonicalRequestIdentity(value.request_identity))+
          SWV5_TestCanonicalField("basket_id","s",value.basket_id.value)+
          SWV5_TestCanonicalField("symbol","s",value.symbol)+
          SWV5_TestCanonicalUnsignedField("symbol_specification_sequence",value.symbol_specification_sequence)+
          SWV5_TestCanonicalIntegerField("intent_type",(long)value.intent_type)+
          SWV5_TestCanonicalIntegerField("direction",value.direction)+
          SWV5_TestCanonicalDoubleField("requested_volume",value.requested_volume)+
          SWV5_TestCanonicalDoubleField("requested_price",value.requested_price)+
          SWV5_TestCanonicalDoubleField("current_account_margin",value.current_account_margin)+
          SWV5_TestCanonicalDoubleField("projected_account_margin",value.projected_account_margin)+
          SWV5_TestCanonicalDoubleField("additional_margin",value.additional_margin)+
          SWV5_TestCanonicalDoubleField("current_free_margin",value.current_free_margin)+
          SWV5_TestCanonicalField("account_currency","s",value.account_currency)+
          SWV5_TestCanonicalField("broker_calculation_reference","s",value.broker_calculation_reference)+
          SWV5_TestCanonicalUnsignedField("observation_sequence",value.observation_sequence)+
          SWV5_TestCanonicalIntegerField("observed_at",value.observed_at)+
          SWV5_TestCanonicalIntegerField("calculated_at",value.calculated_at)+
          SWV5_TestCanonicalField("authority_record_id","s",value.authority_record_id)+
          SWV5_TestCanonicalUnsignedField("authority_record_sequence",value.authority_record_sequence)+
          SWV5_TestCanonicalIntegerField("issuing_component",(long)value.issuing_component)+
          SWV5_TestCanonicalIntegerField("authority_source",(long)value.authority_source);
}

string SWV5_TestMarginAuthorityDigest(const SWV5_MarginAuthorityRecord &record)
{
   return SWV5_TestCanonicalHash(SWV5_TestCanonicalField("format","s","SWV5-MARGIN-AUTHORITY-V5-LP1")+
                                 SWV5_TestCanonicalMarginAuthority(record));
}

string SWV5_TestMarginEvidenceDigest(const SWV5_MarginProjectionEvidence &evidence)
{
   return SWV5_TestCanonicalHash(SWV5_TestCanonicalField("format","s","SWV5-MARGIN-PROJECTION-V5-LP1")+
                                 SWV5_TestCanonicalMarginEvidence(evidence));
}

string SWV5_TestCanonicalBasketRiskEvidence(const SWV5_BasketRiskProjectionEvidence &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(value.persistence_namespace))+
          SWV5_TestCanonicalField("account_namespace","x",SWV5_TestCanonicalAccountNamespace(value.account_namespace))+
          SWV5_TestCanonicalField("ownership_fence","x",SWV5_TestCanonicalFence(value.ownership_fence))+
          SWV5_TestCanonicalField("basket_id","s",value.basket_id.value)+
          SWV5_TestCanonicalUnsignedField("basket_state_version",value.basket_state_version)+
          SWV5_TestCanonicalField("request_identity","x",SWV5_TestCanonicalRequestIdentity(value.request_identity))+
          SWV5_TestCanonicalField("symbol","s",value.symbol)+
          SWV5_TestCanonicalUnsignedField("symbol_specification_sequence",value.symbol_specification_sequence)+
          SWV5_TestCanonicalDoubleField("existing_bounded_basket_loss",value.existing_bounded_basket_loss)+
          SWV5_TestCanonicalDoubleField("incremental_request_bounded_loss",value.incremental_request_bounded_loss)+
          SWV5_TestCanonicalDoubleField("interaction_or_offset_adjustment",value.interaction_or_offset_adjustment)+
          SWV5_TestCanonicalDoubleField("resulting_basket_maximum_loss",value.resulting_basket_maximum_loss)+
          SWV5_TestCanonicalDoubleField("realized_loss_basis",value.realized_loss_basis)+
          SWV5_TestCanonicalDoubleField("unrealized_loss_basis",value.unrealized_loss_basis)+
          SWV5_TestCanonicalDoubleField("accrued_cost_basis",value.accrued_cost_basis)+
          SWV5_TestCanonicalField("monetary_basis","x",SWV5_TestCanonicalRiskMonetaryBasis(value.monetary_basis))+
          SWV5_TestCanonicalField("calculation_policy_id","s",value.calculation_policy_id)+
          SWV5_TestCanonicalField("source_snapshot_digest","s",value.source_snapshot_digest)+
          SWV5_TestCanonicalIntegerField("issuing_component",(long)value.issuing_component)+
          SWV5_TestCanonicalIntegerField("authority_source",(long)value.authority_source)+
          SWV5_TestCanonicalIntegerField("observed_at",value.observed_at)+
           SWV5_TestCanonicalIntegerField("calculated_at",value.calculated_at)+
           SWV5_TestCanonicalUnsignedField("evidence_sequence",value.evidence_sequence)+
           SWV5_TestCanonicalField("authority_record_id","s",value.authority_record_id)+
           SWV5_TestCanonicalUnsignedField("authority_record_sequence",value.authority_record_sequence)+
           SWV5_TestCanonicalField("authority_record_digest","s",value.authority_record_digest);
}

string SWV5_TestCanonicalBasketRiskAuthority(const SWV5_BasketRiskAuthorityRecord &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(value.persistence_namespace))+
          SWV5_TestCanonicalField("account_namespace","x",SWV5_TestCanonicalAccountNamespace(value.account_namespace))+
          SWV5_TestCanonicalField("ownership_fence","x",SWV5_TestCanonicalFence(value.ownership_fence))+
          SWV5_TestCanonicalField("basket_id","s",value.basket_id.value)+
          SWV5_TestCanonicalUnsignedField("basket_state_version",value.basket_state_version)+
          SWV5_TestCanonicalField("request_identity","x",SWV5_TestCanonicalRequestIdentity(value.request_identity))+
          SWV5_TestCanonicalField("symbol","s",value.symbol)+
          SWV5_TestCanonicalUnsignedField("symbol_specification_sequence",value.symbol_specification_sequence)+
          SWV5_TestCanonicalField("source_snapshot_id","s",value.source_snapshot_id)+
          SWV5_TestCanonicalField("source_snapshot_digest","s",value.source_snapshot_digest)+
          SWV5_TestCanonicalDoubleField("existing_bounded_basket_loss",value.existing_bounded_basket_loss)+
          SWV5_TestCanonicalDoubleField("incremental_request_bounded_loss",value.incremental_request_bounded_loss)+
          SWV5_TestCanonicalDoubleField("interaction_or_offset_adjustment",value.interaction_or_offset_adjustment)+
          SWV5_TestCanonicalDoubleField("resulting_basket_maximum_loss",value.resulting_basket_maximum_loss)+
          SWV5_TestCanonicalDoubleField("realized_loss_basis",value.realized_loss_basis)+
          SWV5_TestCanonicalDoubleField("unrealized_loss_basis",value.unrealized_loss_basis)+
          SWV5_TestCanonicalDoubleField("accrued_cost_basis",value.accrued_cost_basis)+
          SWV5_TestCanonicalField("monetary_basis","x",SWV5_TestCanonicalRiskMonetaryBasis(value.monetary_basis))+
          SWV5_TestCanonicalField("calculation_policy_id","s",value.calculation_policy_id)+
          SWV5_TestCanonicalUnsignedField("observation_sequence",value.observation_sequence)+
          SWV5_TestCanonicalIntegerField("observed_at",value.observed_at)+
          SWV5_TestCanonicalIntegerField("calculated_at",value.calculated_at)+
          SWV5_TestCanonicalField("authority_record_id","s",value.authority_record_id)+
          SWV5_TestCanonicalUnsignedField("authority_record_sequence",value.authority_record_sequence)+
          SWV5_TestCanonicalIntegerField("issuing_component",(long)value.issuing_component)+
          SWV5_TestCanonicalIntegerField("authority_source",(long)value.authority_source);
}

string SWV5_TestBasketRiskAuthorityDigest(const SWV5_BasketRiskAuthorityRecord &record)
{
   return SWV5_TestCanonicalHash(SWV5_TestCanonicalField("format","s","SWV5-BASKET-RISK-AUTHORITY-V5-LP1")+
                                 SWV5_TestCanonicalBasketRiskAuthority(record));
}

string SWV5_TestBasketRiskEvidenceDigest(const SWV5_BasketRiskProjectionEvidence &evidence)
{
   return SWV5_TestCanonicalHash(SWV5_TestCanonicalField("format","s","SWV5-BASKET-RISK-PROJECTION-V5-LP1")+
                                 SWV5_TestCanonicalBasketRiskEvidence(evidence));
}

string SWV5_TestCanonicalHardKill(const SWV5_HardKillState &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(value.persistence_namespace))+
          SWV5_TestCanonicalField("account_namespace","x",SWV5_TestCanonicalAccountNamespace(value.account_namespace))+
          SWV5_TestCanonicalField("latch_id","s",value.latch_id)+
          SWV5_TestCanonicalUnsignedField("latch_generation",value.latch_generation)+
          SWV5_TestCanonicalIntegerField("state",(long)value.state)+
          SWV5_TestCanonicalField("activation_reason","s",value.activation_reason)+
          SWV5_TestCanonicalIntegerField("activated_at",value.activated_at)+
          SWV5_TestCanonicalField("activation_authority","s",value.activation_authority)+
          SWV5_TestCanonicalUnsignedField("release_generation",value.release_generation)+
           SWV5_TestCanonicalField("release_evidence","x",SWV5_TestCanonicalHardKillRelease(value.release_evidence))+
           SWV5_TestCanonicalField("release_record_digest","s",value.release_evidence.release_record_digest)+
           SWV5_TestCanonicalField("release_authority_reference","x",SWV5_TestCanonicalHardKillAuthorityReference(value.release_authority_reference));
}

string SWV5_TestCanonicalReconciliationVector(const SWV5_PersistedReconciliationVector &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(value.persistence_namespace))+
          SWV5_TestCanonicalField("basket_id","s",value.basket_id.value)+
          SWV5_TestCanonicalIntegerField("account_mode",(long)value.account_mode)+
          SWV5_TestCanonicalDoubleField("symbol_long_volume",value.symbol_long_volume)+
          SWV5_TestCanonicalDoubleField("symbol_short_volume",value.symbol_short_volume)+
          SWV5_TestCanonicalDoubleField("symbol_net_volume",value.symbol_net_volume)+
          SWV5_TestCanonicalDoubleField("aggregate_position_volume",value.aggregate_position_volume)+
          SWV5_TestCanonicalDoubleField("basket_open_volume",value.basket_open_volume)+
          SWV5_TestCanonicalDoubleField("residual_volume",value.residual_volume)+
          SWV5_TestCanonicalUnsignedField("position_count",value.position_count)+
          SWV5_TestCanonicalUnsignedField("order_count",value.order_count)+
          SWV5_TestCanonicalUnsignedField("pending_request_count",value.pending_request_count)+
          SWV5_TestCanonicalField("latest_confirmed_correlation","x",SWV5_TestCanonicalCorrelation(value.latest_confirmed_correlation))+
          SWV5_TestCanonicalField("latest_broker_event_identity","x",SWV5_TestCanonicalBrokerIdentity(value.latest_broker_event_identity))+
          SWV5_TestCanonicalUnsignedField("transaction_high_watermark",value.transaction_high_watermark)+
          SWV5_TestCanonicalUnsignedField("broker_query_sequence_high_watermark",value.broker_query_sequence_high_watermark)+
          SWV5_TestCanonicalUnsignedField("request_query_sequence_high_watermark",value.request_query_sequence_high_watermark)+
          SWV5_TestCanonicalField("request_set_digest","s",value.request_set_digest)+
          SWV5_TestCanonicalField("request_set_revision","s",value.request_set_revision)+
          SWV5_TestCanonicalIntegerField("basket_state",(long)value.basket_state)+
          SWV5_TestCanonicalUnsignedField("basket_state_version",value.basket_state_version)+
          SWV5_TestCanonicalUnsignedField("hard_kill_generation",value.hard_kill_generation)+
          SWV5_TestCanonicalField("ownership_fence","x",SWV5_TestCanonicalFence(value.ownership_fence))+
          SWV5_TestCanonicalUnsignedField("reconciliation_revision",value.reconciliation_revision)+
          SWV5_TestCanonicalField("source_summary_digest","s",value.source_summary_digest);
}

string SWV5_TestReconciliationVectorDigest(const SWV5_PersistedReconciliationVector &value)
{
   return SWV5_TestCanonicalHash(SWV5_TestCanonicalField("format","s","SWV5-RECONCILIATION-VECTOR-V5-LP1")+
                                 SWV5_TestCanonicalReconciliationVector(value));
}

string SWV5_TestReconciliationSourceDigest(const SWV5_PersistedReconciliationVector &value)
{
   SWV5_PersistedReconciliationVector canonical=value;
   canonical.source_summary_digest="";
   return SWV5_TestCanonicalHash(SWV5_TestCanonicalField("format","s","SWV5-RECONCILIATION-SOURCE-V5-LP1")+
                                 SWV5_TestCanonicalReconciliationVector(canonical));
}

string SWV5_TestCanonicalBrokerSummary(const SWV5_AuthoritativeBrokerSummary &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(value.persistence_namespace))+
          SWV5_TestCanonicalDoubleField("symbol_long_volume",value.symbol_long_volume)+
          SWV5_TestCanonicalDoubleField("symbol_short_volume",value.symbol_short_volume)+
          SWV5_TestCanonicalDoubleField("symbol_net_volume",value.symbol_net_volume)+
          SWV5_TestCanonicalDoubleField("aggregate_position_volume",value.aggregate_position_volume)+
          SWV5_TestCanonicalField("basket_id","s",value.basket_id.value)+
          SWV5_TestCanonicalDoubleField("basket_open_volume",value.basket_open_volume)+
          SWV5_TestCanonicalDoubleField("residual_volume",value.residual_volume)+
          SWV5_TestCanonicalUnsignedField("position_count",value.position_count)+
          SWV5_TestCanonicalUnsignedField("order_count",value.order_count)+
          SWV5_TestCanonicalField("latest_confirmed_correlation","x",SWV5_TestCanonicalCorrelation(value.latest_confirmed_correlation))+
          SWV5_TestCanonicalField("latest_broker_event_identity","x",SWV5_TestCanonicalBrokerIdentity(value.latest_broker_event_identity))+
          SWV5_TestCanonicalUnsignedField("transaction_high_watermark",value.transaction_high_watermark)+
          SWV5_TestCanonicalUnsignedField("observation_sequence",value.observation_sequence)+
          SWV5_TestCanonicalIntegerField("account_mode",(long)value.account_mode)+
          SWV5_TestCanonicalField("queries","x",SWV5_TestCanonicalQueries(value.queries))+
          SWV5_TestCanonicalIntegerField("observed_at",value.observed_at)+
          SWV5_TestCanonicalIntegerField("authority",(long)value.authority);
}

string SWV5_TestCanonicalRestartRequestSummary(const SWV5_AuthoritativeRestartRequestSummary &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(value.persistence_namespace))+
          SWV5_TestCanonicalField("basket_id","s",value.basket_id.value)+
          SWV5_TestCanonicalIntegerField("account_mode",(long)value.account_mode)+
          SWV5_TestCanonicalUnsignedField("pending_request_count",value.pending_request_count)+
          SWV5_TestCanonicalField("request_set_digest","s",value.request_set_digest)+
          SWV5_TestCanonicalField("request_set_revision","s",value.request_set_revision)+
          SWV5_TestCanonicalUnsignedField("reconciliation_revision",value.reconciliation_revision)+
          SWV5_TestCanonicalUnsignedField("observation_sequence",value.observation_sequence)+
          SWV5_TestCanonicalIntegerField("observed_at",value.observed_at)+
          SWV5_TestCanonicalIntegerField("authority",(long)value.authority)+
          SWV5_TestCanonicalIntegerField("authority_source",(long)value.authority_source)+
          SWV5_TestCanonicalField("pending_request_query","x",SWV5_TestCanonicalQueries(value.pending_request_query));
}

string SWV5_TestRestartRequestSummaryDigest(const SWV5_AuthoritativeRestartRequestSummary &summary)
{
   return SWV5_TestCanonicalHash(SWV5_TestCanonicalField("format","s","SWV5-RESTART-REQUEST-SUMMARY-V5-LP1")+
                                 SWV5_TestCanonicalRestartRequestSummary(summary));
}

string SWV5_TestBrokerSummaryDigest(const SWV5_AuthoritativeBrokerSummary &summary)
{
   return SWV5_TestCanonicalHash(SWV5_TestCanonicalField("format","s","SWV5-BROKER-SUMMARY-V5-LP1")+
                                 SWV5_TestCanonicalBrokerSummary(summary));
}

string SWV5_TestCanonicalLifecycle(const SWV5_BasketLifecycleSnapshot &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("basket_id","s",value.basket_id.value)+
          SWV5_TestCanonicalField("ownership_fence","x",SWV5_TestCanonicalFence(value.ownership_fence))+
          SWV5_TestCanonicalIntegerField("state",(long)value.state)+
          SWV5_TestCanonicalUnsignedField("state_version",value.state_version)+
          SWV5_TestCanonicalUnsignedField("cumulative_recovery_attempts",value.cumulative_recovery_attempts)+
          SWV5_TestCanonicalUnsignedField("current_recovery_layer",value.current_recovery_layer)+
          SWV5_TestCanonicalField("accepted_recovery_evidence","x",SWV5_TestCanonicalEventSet(value.accepted_recovery_evidence))+
          SWV5_TestCanonicalDoubleField("aggregate_open_volume",value.aggregate_open_volume)+
          SWV5_TestCanonicalDoubleField("residual_volume",value.residual_volume)+
          SWV5_TestCanonicalUnsignedField("live_position_count",value.live_position_count)+
          SWV5_TestCanonicalUnsignedField("live_order_count",value.live_order_count)+
          SWV5_TestCanonicalUnsignedField("pending_request_count",value.pending_request_count)+
          SWV5_TestCanonicalIntegerField("reconciliation_state",(long)value.reconciliation_state)+
          SWV5_TestCanonicalField("broker_queries","x",SWV5_TestCanonicalQueries(value.broker_queries))+
          SWV5_TestCanonicalIntegerField("state_entered_at",value.state_entered_at);
}

string SWV5_TestCanonicalBasket(const SWV5_BasketAggregate &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalField("persistence_namespace","x",SWV5_TestCanonicalNamespace(value.persistence_namespace))+
          SWV5_TestCanonicalIntegerField("account_mode",(long)value.account_mode)+
          SWV5_TestCanonicalField("lifecycle","x",SWV5_TestCanonicalLifecycle(value.lifecycle))+
          SWV5_TestCanonicalDoubleField("initial_volume",value.initial_volume)+
          SWV5_TestCanonicalDoubleField("aggregate_closed_volume",value.aggregate_closed_volume)+
          SWV5_TestCanonicalIntegerField("close_verification",(long)value.close_verification)+
          SWV5_TestCanonicalIntegerField("opened_at",value.opened_at)+
          SWV5_TestCanonicalIntegerField("updated_at",value.updated_at);
}

string SWV5_TestCanonicalRequestSetHeader(const SWV5_PersistedRequestSetHeader &value)
{
   return SWV5_TestCanonicalField("contract_version","x",SWV5_TestCanonicalVersion(value.contract_version))+
          SWV5_TestCanonicalUnsignedField("request_count",value.request_count)+
          SWV5_TestCanonicalField("request_set_digest","s",value.request_set_digest)+
          SWV5_TestCanonicalField("request_index_revision","s",value.request_index_revision)+
          SWV5_TestCanonicalUnsignedField("record_sequence",value.record_sequence);
}

string SWV5_TestCanonicalCheckpointPayload(const SWV5_PersistedCheckpoint &checkpoint)
{
   // payload_digest and payload_size are the integrity envelope and are deliberately
   // excluded from the body they describe. Every other persisted field is bound here.
    return SWV5_TestCanonicalField("format","s","SWV5-CHECKPOINT-V5-LP1")+
          SWV5_TestCanonicalField("header_contract_version","x",SWV5_TestCanonicalVersion(checkpoint.header.contract_version))+
          SWV5_TestCanonicalField("header_persistence_namespace","x",SWV5_TestCanonicalNamespace(checkpoint.header.persistence_namespace))+
          SWV5_TestCanonicalField("header_ownership_fence","x",SWV5_TestCanonicalFence(checkpoint.header.ownership_fence))+
           SWV5_TestCanonicalUnsignedField("record_sequence",checkpoint.header.record_sequence)+
           SWV5_TestCanonicalUnsignedField("previous_record_sequence",checkpoint.header.previous_record_sequence)+
           SWV5_TestCanonicalField("store_revision","s",checkpoint.header.store_revision)+
           SWV5_TestCanonicalIntegerField("written_at",checkpoint.header.written_at)+
          SWV5_TestCanonicalField("basket","x",SWV5_TestCanonicalBasket(checkpoint.basket))+
          SWV5_TestCanonicalField("last_confirmed_correlation","x",SWV5_TestCanonicalCorrelation(checkpoint.last_confirmed_correlation))+
          SWV5_TestCanonicalField("pending_request_set","x",SWV5_TestCanonicalRequestSetHeader(checkpoint.pending_request_set))+
          SWV5_TestCanonicalBoolField("has_latest_pending_request",checkpoint.has_latest_pending_request)+
          SWV5_TestCanonicalField("latest_pending_request","x",SWV5_TestCanonicalPersistedRequest(checkpoint.latest_pending_request))+
           SWV5_TestCanonicalField("hard_kill_state","x",SWV5_TestCanonicalHardKill(checkpoint.hard_kill_state))+
           SWV5_TestCanonicalField("reconciliation_vector","x",SWV5_TestCanonicalReconciliationVector(checkpoint.reconciliation_vector))+
           SWV5_TestCanonicalBoolField("clean_shutdown",checkpoint.clean_shutdown);
}

string SWV5_TestCheckpointPayloadDigest(const SWV5_PersistedCheckpoint &checkpoint)
{
   return SWV5_TestCanonicalHash(SWV5_TestCanonicalCheckpointPayload(checkpoint));
}

ulong SWV5_TestCheckpointPayloadSize(const SWV5_PersistedCheckpoint &checkpoint)
{
   // Size unit is the deterministic MQL string character count used by LP1 fields.
   return (ulong)StringLen(SWV5_TestCanonicalCheckpointPayload(checkpoint));
}

void SWV5_TestSealCheckpoint(SWV5_PersistedCheckpoint &checkpoint)
{
   const string canonical=SWV5_TestCanonicalCheckpointPayload(checkpoint);
   checkpoint.header.payload_digest=SWV5_TestCanonicalHash(canonical);
   checkpoint.header.payload_size=(ulong)StringLen(canonical);
}

string SWV5_TestCanonicalRequestSet(const SWV5_PersistedRequestEvidence &requests[])
{
   string canonical=SWV5_TestCanonicalField("format","s","SWV5-PERSISTED-REQUEST-SET-V5-LP1")+
                    SWV5_TestCanonicalUnsignedField("request_count",(ulong)ArraySize(requests));
   for(int index=0;index<ArraySize(requests);index++)
   {
      const string ordered_record=SWV5_TestCanonicalUnsignedField("order_index",(ulong)index)+
                                  SWV5_TestCanonicalField("record","x",SWV5_TestCanonicalPersistedRequest(requests[index]));
      canonical+=SWV5_TestCanonicalField("ordered_request","x",ordered_record);
   }
   return canonical;
}

string SWV5_TestRequestSetDigest(const SWV5_PersistedRequestEvidence &requests[])
{
   return SWV5_TestCanonicalHash(SWV5_TestCanonicalRequestSet(requests));
}

string SWV5_TestRequestSetRevision(const SWV5_PersistedRequestEvidence &requests[],const ulong record_sequence)
{
   const string canonical=SWV5_TestCanonicalField("format","s","SWV5-REQUEST-INDEX-REVISION-V5-LP1")+
                          SWV5_TestCanonicalUnsignedField("record_sequence",record_sequence)+
                          SWV5_TestCanonicalField("request_set_digest","s",SWV5_TestRequestSetDigest(requests));
   return SWV5_TestCanonicalHash(canonical);
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

// Rebind every V5 checkpoint field that is causally derived from its current
// payload. Tests must use this after changing Basket or request-set content;
// resealing the outer digest alone is not a valid V5 fixture.
void SWV5_TestRefreshCheckpointVector(SWV5_PersistedCheckpoint &checkpoint)
{
   checkpoint.basket.lifecycle.pending_request_count=checkpoint.pending_request_set.request_count;
   checkpoint.reconciliation_vector.contract_version=checkpoint.header.contract_version;
   checkpoint.reconciliation_vector.persistence_namespace=checkpoint.header.persistence_namespace;
   checkpoint.reconciliation_vector.basket_id=checkpoint.header.persistence_namespace.basket_id;
   checkpoint.reconciliation_vector.account_mode=checkpoint.basket.account_mode;
   checkpoint.reconciliation_vector.symbol_long_volume=checkpoint.basket.lifecycle.aggregate_open_volume;
   checkpoint.reconciliation_vector.symbol_short_volume=0.0;
   checkpoint.reconciliation_vector.symbol_net_volume=checkpoint.basket.lifecycle.aggregate_open_volume;
   checkpoint.reconciliation_vector.aggregate_position_volume=checkpoint.basket.lifecycle.aggregate_open_volume;
   checkpoint.reconciliation_vector.basket_open_volume=checkpoint.basket.lifecycle.aggregate_open_volume;
   checkpoint.reconciliation_vector.residual_volume=checkpoint.basket.lifecycle.residual_volume;
   checkpoint.reconciliation_vector.position_count=checkpoint.basket.lifecycle.live_position_count;
   checkpoint.reconciliation_vector.order_count=checkpoint.basket.lifecycle.live_order_count;
   checkpoint.reconciliation_vector.pending_request_count=checkpoint.pending_request_set.request_count;
   checkpoint.reconciliation_vector.latest_confirmed_correlation=checkpoint.last_confirmed_correlation;
   checkpoint.reconciliation_vector.latest_broker_event_identity=checkpoint.last_confirmed_correlation.broker_identity;
   checkpoint.reconciliation_vector.transaction_high_watermark=checkpoint.last_confirmed_correlation.broker_identity.transaction_sequence;
   // These are persisted anti-replay anchors from the last accepted restart
   // query observations, not aliases of transaction or request revisions.
   if(checkpoint.reconciliation_vector.broker_query_sequence_high_watermark==0)
      checkpoint.reconciliation_vector.broker_query_sequence_high_watermark=899;
   if(checkpoint.reconciliation_vector.request_query_sequence_high_watermark==0)
      checkpoint.reconciliation_vector.request_query_sequence_high_watermark=899;
   checkpoint.reconciliation_vector.request_set_digest=checkpoint.pending_request_set.request_set_digest;
   checkpoint.reconciliation_vector.request_set_revision=checkpoint.pending_request_set.request_index_revision;
   checkpoint.reconciliation_vector.basket_state=checkpoint.basket.lifecycle.state;
   checkpoint.reconciliation_vector.basket_state_version=checkpoint.basket.lifecycle.state_version;
   checkpoint.reconciliation_vector.hard_kill_generation=checkpoint.hard_kill_state.latch_generation;
   checkpoint.reconciliation_vector.ownership_fence=checkpoint.header.ownership_fence;
   checkpoint.reconciliation_vector.source_summary_digest=SWV5_TestReconciliationSourceDigest(checkpoint.reconciliation_vector);
}

void SWV5_TestBindCheckpointRequests(SWV5_RestartReconciliationInput &restart,
                                     const SWV5_PersistedRequestEvidence &requests[],
                                     const ulong record_sequence,
                                     const uint execution_request_count,
                                     const string execution_request_set_digest,
                                     const string execution_request_set_revision,
                                     const ulong execution_reconciliation_revision)
{
   SWV5_TestBindRequestSetHeader(restart.persisted.pending_request_set,requests,record_sequence);
   restart.persisted.has_latest_pending_request=(ArraySize(requests)>0);
   if(ArraySize(requests)>0)
      restart.persisted.latest_pending_request=requests[ArraySize(requests)-1];
   else
      ZeroMemory(restart.persisted.latest_pending_request);
   SWV5_TestRefreshCheckpointVector(restart.persisted);
   // Execution-owned authority values are explicit inputs. Never copy them
   // from the persisted checkpoint that they independently corroborate.
   restart.restart_requests.pending_request_count=execution_request_count;
   restart.restart_requests.request_set_digest=execution_request_set_digest;
   restart.restart_requests.request_set_revision=execution_request_set_revision;
   restart.restart_requests.reconciliation_revision=execution_reconciliation_revision;
   restart.restart_requests.complete_summary_digest=SWV5_TestRestartRequestSummaryDigest(restart.restart_requests);
   restart.broker.complete_summary_digest=SWV5_TestBrokerSummaryDigest(restart.broker);
   restart.persisted.reconciliation_vector.source_summary_digest=SWV5_TestReconciliationSourceDigest(restart.persisted.reconciliation_vector);
   SWV5_TestSealCheckpoint(restart.persisted);
}

void SWV5_TestRefreshRiskInputBindings(SWV5_RiskEvaluationInput &engineInput)
{
   engineInput.projected.margin_evidence.persistence_namespace=engineInput.intent.persistence_namespace;
   engineInput.projected.margin_evidence.ownership_fence=engineInput.intent.ownership_fence;
   engineInput.projected.margin_evidence.request_identity=engineInput.intent.request_identity;
   engineInput.projected.margin_evidence.basket_id=engineInput.intent.persistence_namespace.basket_id;
   engineInput.margin_authority_record.persistence_namespace=engineInput.intent.persistence_namespace;
   engineInput.margin_authority_record.ownership_fence=engineInput.intent.ownership_fence;
   engineInput.margin_authority_record.request_identity=engineInput.intent.request_identity;
   engineInput.margin_authority_record.basket_id=engineInput.intent.persistence_namespace.basket_id;
   engineInput.margin_authority_record.account_namespace=engineInput.account_namespace;
   engineInput.margin_authority_record.authority_record_digest=SWV5_TestMarginAuthorityDigest(engineInput.margin_authority_record);
   engineInput.projected.margin_evidence.authority_record_digest=engineInput.margin_authority_record.authority_record_digest;
   engineInput.projected.margin_evidence.evidence_digest=SWV5_TestMarginEvidenceDigest(engineInput.projected.margin_evidence);
   engineInput.projected.basket_risk_evidence.persistence_namespace=engineInput.intent.persistence_namespace;
   engineInput.projected.basket_risk_evidence.ownership_fence=engineInput.intent.ownership_fence;
   engineInput.projected.basket_risk_evidence.request_identity=engineInput.intent.request_identity;
   engineInput.projected.basket_risk_evidence.basket_id=engineInput.intent.persistence_namespace.basket_id;
   engineInput.projected.basket_risk_evidence.basket_state_version=engineInput.intent.expected_basket_version;
   engineInput.basket_risk_authority_record.persistence_namespace=engineInput.intent.persistence_namespace;
   engineInput.basket_risk_authority_record.ownership_fence=engineInput.intent.ownership_fence;
   engineInput.basket_risk_authority_record.request_identity=engineInput.intent.request_identity;
   engineInput.basket_risk_authority_record.basket_id=engineInput.intent.persistence_namespace.basket_id;
   engineInput.basket_risk_authority_record.basket_state_version=engineInput.intent.expected_basket_version;
   engineInput.basket_risk_authority_record.account_namespace=engineInput.account_namespace;
   engineInput.basket_risk_authority_record.authority_record_digest=SWV5_TestBasketRiskAuthorityDigest(engineInput.basket_risk_authority_record);
   engineInput.projected.basket_risk_evidence.authority_record_digest=engineInput.basket_risk_authority_record.authority_record_digest;
   engineInput.projected.basket_risk_evidence.evidence_digest=SWV5_TestBasketRiskEvidenceDigest(engineInput.projected.basket_risk_evidence);
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

void SWV5_TestMakeAcknowledgementTransaction(const SWV5_PendingRequest &pending,
                                              SWV5_TransactionEvidence &evidence)
{
   SWV5_TestMakeTransaction(pending,evidence,0.0);
   evidence.event_kind=SWV5_TRANSACTION_EVENT_ORDER_ACCEPTED;
   evidence.correlation.phase=SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT;
   evidence.correlation.broker_identity.deal_ticket=0;
   evidence.correlation.broker_identity.position_identifier=0;
   evidence.correlation.broker_identity.broker_event_id="ORDER-ACK-EVENT-0001";
   evidence.correlation.broker_identity.transaction_sequence=400;
   evidence.confirmed_volume=0.0;
   evidence.confirmed_price=0.0;
   evidence.authority=SWV5_AUTHORITY_TRANSACTION_EVENT;
   evidence.history_cross_checked=false;
}

void SWV5_TestMakeCheckpoint(SWV5_PersistedCheckpoint &checkpoint)
{
   SWV5_TestMakeVersion(checkpoint.header.contract_version);
   SWV5_TestMakeNamespace(checkpoint.header.persistence_namespace);
   SWV5_TestMakeFence(checkpoint.header.ownership_fence);
   checkpoint.header.record_sequence=20;
   checkpoint.header.previous_record_sequence=19;
   checkpoint.header.store_revision="CHECKPOINT-STORE-REV-20";
   checkpoint.header.payload_digest="";
   checkpoint.header.payload_size=0;
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
   SWV5_TestMakeVersion(checkpoint.reconciliation_vector.contract_version);
   checkpoint.reconciliation_vector.persistence_namespace=checkpoint.header.persistence_namespace;
   checkpoint.reconciliation_vector.basket_id=checkpoint.header.persistence_namespace.basket_id;
   checkpoint.reconciliation_vector.account_mode=checkpoint.basket.account_mode;
   checkpoint.reconciliation_vector.symbol_long_volume=checkpoint.basket.lifecycle.aggregate_open_volume;
   checkpoint.reconciliation_vector.symbol_short_volume=0.0;
   checkpoint.reconciliation_vector.symbol_net_volume=checkpoint.basket.lifecycle.aggregate_open_volume;
   checkpoint.reconciliation_vector.aggregate_position_volume=checkpoint.basket.lifecycle.aggregate_open_volume;
   checkpoint.reconciliation_vector.basket_open_volume=checkpoint.basket.lifecycle.aggregate_open_volume;
   checkpoint.reconciliation_vector.residual_volume=checkpoint.basket.lifecycle.residual_volume;
   checkpoint.reconciliation_vector.position_count=checkpoint.basket.lifecycle.live_position_count;
   checkpoint.reconciliation_vector.order_count=checkpoint.basket.lifecycle.live_order_count;
   checkpoint.reconciliation_vector.pending_request_count=checkpoint.pending_request_set.request_count;
   checkpoint.reconciliation_vector.latest_confirmed_correlation=checkpoint.last_confirmed_correlation;
   checkpoint.reconciliation_vector.latest_broker_event_identity=checkpoint.last_confirmed_correlation.broker_identity;
   checkpoint.reconciliation_vector.transaction_high_watermark=checkpoint.last_confirmed_correlation.broker_identity.transaction_sequence;
   checkpoint.reconciliation_vector.broker_query_sequence_high_watermark=899;
   checkpoint.reconciliation_vector.request_query_sequence_high_watermark=899;
   checkpoint.reconciliation_vector.request_set_digest=checkpoint.pending_request_set.request_set_digest;
   checkpoint.reconciliation_vector.request_set_revision=checkpoint.pending_request_set.request_index_revision;
   checkpoint.reconciliation_vector.basket_state=checkpoint.basket.lifecycle.state;
   checkpoint.reconciliation_vector.basket_state_version=checkpoint.basket.lifecycle.state_version;
   checkpoint.reconciliation_vector.hard_kill_generation=checkpoint.hard_kill_state.latch_generation;
   checkpoint.reconciliation_vector.ownership_fence=checkpoint.header.ownership_fence;
   checkpoint.reconciliation_vector.reconciliation_revision=20;
   checkpoint.reconciliation_vector.source_summary_digest=SWV5_TestReconciliationSourceDigest(checkpoint.reconciliation_vector);
   checkpoint.clean_shutdown=true;
   SWV5_TestSealCheckpoint(checkpoint);
}

// Build broker evidence from the Broker Adapter fixture domain only. No value
// is read from the persisted checkpoint that it will later corroborate.
void SWV5_TestMakeIndependentBrokerSummary(SWV5_AuthoritativeBrokerSummary &broker)
{
   SWV5_TestMakeVersion(broker.contract_version);
   SWV5_TestMakeNamespace(broker.persistence_namespace);
   broker.symbol_long_volume=0.30;
   broker.symbol_short_volume=0.0;
   broker.symbol_net_volume=0.30;
   broker.aggregate_position_volume=0.30;
   broker.basket_id.value="BASKET-0001";
   broker.basket_open_volume=0.30;
   broker.residual_volume=0.20;
   broker.position_count=1;
   broker.order_count=0;
   SWV5_TestMakeCorrelation(broker.latest_confirmed_correlation);
   broker.latest_broker_event_identity=broker.latest_confirmed_correlation.broker_identity;
   broker.transaction_high_watermark=400;
   broker.observation_sequence=901;
   broker.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   SWV5_TestMakeQueries(broker.queries,SWV5_RESTART_BROKER_QUERY_FLAGS_V5);
   broker.observed_at=SWV5_TEST_TIME;
   broker.authority=SWV5_AUTHORITY_LIVE_BROKER_STATE;
   broker.complete_summary_digest=SWV5_TestBrokerSummaryDigest(broker);
}

// Build the Execution/Pending-Request authority view independently. The empty
// canonical request set is computed from its own fixture input, never copied
// from Persistence.
void SWV5_TestMakeIndependentRestartRequestSummary(SWV5_AuthoritativeRestartRequestSummary &summary)
{
   SWV5_TestMakeVersion(summary.contract_version);
   SWV5_TestMakeNamespace(summary.persistence_namespace);
   summary.basket_id.value="BASKET-0001";
   summary.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   SWV5_PersistedRequestEvidence empty_requests[];
   ArrayResize(empty_requests,0);
   summary.pending_request_count=0;
   summary.request_set_digest=SWV5_TestRequestSetDigest(empty_requests);
   summary.request_set_revision=SWV5_TestRequestSetRevision(empty_requests,20);
   summary.reconciliation_revision=20;
   summary.observation_sequence=902;
   summary.observed_at=SWV5_TEST_TIME;
   summary.authority=SWV5_COMPONENT_AUTHORITY_EXECUTION;
   summary.authority_source=SWV5_AUTHORITY_EXECUTION_REQUEST_STATE;
   SWV5_TestMakeQueries(summary.pending_request_query,SWV5_RESTART_EXECUTION_QUERY_FLAGS_V5);
   summary.complete_summary_digest=SWV5_TestRestartRequestSummaryDigest(summary);
}

void SWV5_TestMakeRestartInput(SWV5_RestartReconciliationInput &engineInput)
{
   SWV5_TestMakeVersion(engineInput.contract_version);
   SWV5_TestMakeCheckpoint(engineInput.persisted);
   engineInput.persistence_namespace=engineInput.persisted.header.persistence_namespace;
   SWV5_TestMakeIndependentBrokerSummary(engineInput.broker);
   SWV5_TestMakeIndependentRestartRequestSummary(engineInput.restart_requests);
   engineInput.persisted.reconciliation_vector.source_summary_digest=SWV5_TestReconciliationSourceDigest(engineInput.persisted.reconciliation_vector);
   SWV5_TestSealCheckpoint(engineInput.persisted);
   engineInput.claimant_fence=engineInput.persisted.header.ownership_fence;
   engineInput.persistence_status=SWV5_PERSISTENCE_LOADED;
   engineInput.has_release_authority_record=false;
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
   state.identities.canonical_event_index=SWV5_TestCanonicalDurableEventEntry("EVENT-0001",400)+
                                          SWV5_TestCanonicalDurableEventEntry("EVENT-0002",399);
   state.identities.canonical_fingerprint_index="";
   state.identities.accepted_identity_count=2;
   state.identities.highest_transaction_sequence=400;
   state.identities.index_revision=2;
   state.identities.identity_set_digest=SWV5_TestEventSetDigest(state.identities);
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
