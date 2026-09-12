#ifndef SW_V5_S5_PHASE_F_BROKER_ADAPTER_ASSERTIONS_MQH
#define SW_V5_S5_PHASE_F_BROKER_ADAPTER_ASSERTIONS_MQH

// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.
// Pure MQL assertions for the Phase F Broker Adapter audit boundaries.

#include "../../ExecutionLayer/BrokerAdapter/SW_V5_S5_F_BrokerAdapter.mqh"
#include "../Sprint5PhaseB/SW_V5_S5_PhaseB_Assertions.mqh"

struct SWV5S5_F_MqlAssertionResult
{
   int total;
   int passed;
   int failed;
   int skipped;
   string signature_material;
};

void SWV5S5_F_MqlAssert(const string test_id,const bool condition,
                        SWV5S5_F_MqlAssertionResult &result)
{
   result.total++;
   if(condition) result.passed++; else result.failed++;
   result.signature_material+=test_id+"="+(condition ? "PASS" : "FAIL")+";";
   PrintFormat("S5F_BROKER_MQL_ASSERT|id=%s|result=%s",test_id,
               condition ? "PASS" : "FAIL");
}

void SWV5S5_F_MqlBuildWire(SWV5S5_F_AdapterWireRequest &wire)
{
   ZeroMemory(wire);
   wire.action=(int)TRADE_ACTION_DEAL;
   wire.magic=1179670069;
   wire.symbol="AUDIT_XAUUSD";
   wire.volume=0.30;
   wire.price=2500.10;
   wire.stop_loss_price=2499.90;
   wire.take_profit_price=2500.30;
   wire.order_type=(int)ORDER_TYPE_BUY;
   wire.filling_type=(int)ORDER_FILLING_FOK;
   wire.time_type=(int)ORDER_TIME_GTC;
   wire.comment="AUDIT-NO-SEND";
}

bool SWV5S5_F_MqlBuildProfile(const SWV5S5_SubmissionPermit &permit,
                              SWV5S5_F_ProfileScope &profile,
                              SWV5S5_F_AdapterEnvironment &environment)
{
   ZeroMemory(profile); SWV5S5_F_InitVersion(profile.contract_version);
   profile.persistence_namespace=permit.persistence_namespace;
   profile.persistence_namespace.ownership_namespace.magic=SWV5_RUNTIME_STRATEGY_MAGIC;
   profile.account_namespace=permit.account_namespace;
   profile.account_namespace.broker_identity="TEST-BROKER";
   profile.account_namespace.server="TEST-SERVER";
   profile.account_namespace.account_login=1001;
   profile.account_namespace.account_currency="USD";
   profile.account_namespace.magic=SWV5_RUNTIME_STRATEGY_MAGIC;
   profile.account_namespace.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   profile.account_namespace.authoritative_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
   profile.broker_identity=profile.account_namespace.broker_identity;
   profile.server=profile.account_namespace.server;
   profile.account_login=profile.account_namespace.account_login;
   profile.symbol=profile.persistence_namespace.ownership_namespace.symbol;
   profile.terminal_build=1;
   profile.mql_build=1;
   profile.profile_id=SWV5S5_F_ADAPTER_PROFILE_ID;
   if(!SWV5S5_F_DeriveProfileDigest(profile,profile.profile_digest) ||
      !SWV5S5_F_IsProfileValid(profile)) return false;

   ZeroMemory(environment);
   environment.broker_identity=profile.broker_identity;
   environment.server=profile.server;
   environment.account_login=profile.account_login;
   environment.account_currency=profile.account_namespace.account_currency;
   environment.symbol=profile.symbol;
   environment.terminal_build=profile.terminal_build;
   environment.mql_build=profile.mql_build;
   environment.account_trade_mode=0;
   environment.account_mode=profile.account_namespace.account_mode;
   environment.connected=true;
   environment.terminal_trade_allowed=true;
   environment.mql_trade_allowed=true;
   environment.account_trade_allowed=true;
   environment.account_trade_expert=true;
   environment.symbol_trade_mode=1;
   environment.symbol_execution_mode=0;
   environment.symbol_filling_mask=3;
   environment.symbol_digits=2;
   environment.point=0.01;
   environment.tick_size=0.01;
   environment.volume_min=0.01;
   environment.volume_max=100.0;
   environment.volume_step=0.01;
   environment.runtime_magic=SWV5_RUNTIME_STRATEGY_MAGIC;
   return SWV5S5_F_AdapterEnvironmentMatchesProfile(profile,environment) &&
      SWV5S5_F_AdapterPermissionsAllowMutation(environment);
}

bool SWV5S5_F_MqlBuildWireForCommand(const SWV5S5_F_AdapterSubmissionCommand &command,
                                     SWV5S5_F_AdapterWireRequest &wire)
{
   ZeroMemory(wire);
   wire.action=(int)TRADE_ACTION_DEAL;
   wire.magic=SWV5_RUNTIME_STRATEGY_MAGIC;
   wire.symbol=command.expected_profile.symbol;
   wire.volume=command.volume;
   wire.price=command.price;
   wire.stop_loss_price=command.stop_price;
   wire.take_profit_price=command.limit_price;
   wire.order_type=(command.direction==1 ? (int)ORDER_TYPE_BUY : (int)ORDER_TYPE_SELL);
   wire.filling_type=(command.filling_mode==1 ? (int)ORDER_FILLING_FOK : (int)ORDER_FILLING_IOC);
   wire.time_type=(int)ORDER_TIME_GTC;
   wire.comment=command.comment_metadata;
   return true;
}

bool SWV5S5_F_MqlBuildRuntimeClaimFixture(SWV5_ContractValidationContext &context,
                              SWV5S5_InvocationClaimCommand &command)
{
   SWV5S5_TestContext(context,1000,3);
   SWV5_PersistenceNamespace scope; SWV5_OwnershipFence fence;
   SWV5S5_TestScope(scope,fence);
   SWV5S5_IngressEnvelope ingress; if(!SWV5S5_TestIngress(scope,ingress)) return false;
   SWV5_ExecutionRequestIdentity request; SWV5S5_TestRequest(scope,ingress.ingress_identity,request);
   SWV5_NormalizedUnits units; SWV5S5_TestNormalized(scope,fence,units);

   SWV5S5_SubmissionPermit permit; ZeroMemory(permit); SWV5S5_InitContractVersion(permit.contract_version);
   permit.permit_policy_id=SWV5S5_PERMIT_POLICY_ID; permit.permit_policy_version=SWV5S5_PERMIT_POLICY_VERSION;
   permit.canonical_format_id=SWV5S5_CANONICAL_POLICY_ID; permit.permit_revision=1; permit.reserved_at=950;
   permit.persistence_namespace=scope; permit.ownership_fence=fence;
   SWV5S5_TestInitV5(permit.account_namespace.contract_version);
   permit.account_namespace.broker_identity="TEST-BROKER"; permit.account_namespace.server="TEST-SERVER";
   permit.account_namespace.account_login=1001; permit.account_namespace.account_currency="USD";
   permit.account_namespace.strategy_id="FUSION"; permit.account_namespace.magic=5005;
   permit.account_namespace.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   permit.account_namespace.authoritative_source=SWV5_AUTHORITY_SIGNAL_DTO;
   permit.account_namespace.snapshot_epoch=4; permit.account_namespace.snapshot_sequence=8;
   permit.account_epoch=4; permit.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   permit.request_identity=request; permit.unique_attempt_id=request.request_id.attempt_id;
   permit.normalized_payload=units; permit.normalization_identity="NORMALIZATION-A";
   permit.unit_authority_id="UNIT-A"; permit.unit_authority_revision=4;
   permit.unit_authority_digest=SWV5S5_SHA256_ABC;
   permit.symbol_specification_sequence=7; permit.basket_id=scope.basket_id; permit.basket_state_version=2;
   SWV5S5_InitContractVersion(permit.producer_trust.contract_version);
   permit.producer_trust.authority_record_id="TRUST-A"; permit.producer_trust.authority_generation=5;
   permit.producer_trust.issuer_identity="TRUST-ISSUER"; permit.producer_trust.issuer_policy_id="TRUST-POLICY";
   permit.producer_trust.producer_component="DECISION"; permit.producer_trust.producer_instance="PRODUCER-A";
   permit.producer_trust.producer_epoch=6; permit.producer_trust.persistence_namespace=scope;
   permit.producer_trust.symbol="XAUUSD"; permit.producer_trust.timeframe=15; permit.producer_trust.execution_mode=1;
   permit.producer_trust.clock_id="TEST-CLOCK"; permit.producer_trust.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   permit.producer_trust.status=SWV5S5_TRUST_AUTHORIZED; permit.producer_trust.valid_from=900;
   permit.producer_trust.valid_until=1100;
   // MQL ZeroMemory leaves nullable strings; canonical absence must be explicit.
   permit.producer_trust.superseding_record_id="";
   if(!SWV5S5_DeriveProducerTrustDigest(permit.producer_trust,permit.producer_trust.record_digest)) return false;
   SWV5S5_TestInitV5(permit.risk_authorization.contract_version);
   SWV5S5_TestInitV5(permit.risk_authorization.authorized_limits.contract_version);
   SWV5S5_TestInitV5(permit.risk_authorization.monetary_basis.contract_version);
   permit.risk_authorization.authorization_id="RISK-A"; permit.risk_authorization.request_identity=request;
   permit.risk_authorization.persistence_namespace=scope; permit.risk_authorization.ownership_fence=fence;
   permit.risk_authorization.account_namespace=permit.account_namespace;
   permit.risk_authorization.account_mode=SWV5_ACCOUNT_MODE_HEDGING; permit.risk_authorization.disposition=SWV5_RISK_ALLOW;
   permit.risk_authorization.basket_state_version=2; permit.risk_authorization.symbol_specification_sequence=7;
   permit.risk_authorization.authorized_intent_type=SWV5_INTENT_OPEN; permit.risk_authorization.authorized_direction=1;
   permit.risk_authorization.authorized_volume=0.10; permit.risk_authorization.authorized_price=2000.0;
   permit.risk_authorization.authorized_stop_price=1990.0; permit.risk_authorization.authorized_limit_price=2010.0;
   permit.risk_authorization.risk_snapshot_epoch=4; permit.risk_authorization.risk_snapshot_sequence=8;
   permit.risk_authorization.hard_kill_latch_id="HK-A"; permit.risk_authorization.hard_kill_latch_generation=3;
   permit.risk_authorization.evaluated_at=950; permit.risk_authorization.expires_at=1100;
   SWV5S5_TestInitV5(permit.margin_authority.contract_version);
   permit.margin_authority.persistence_namespace=scope; permit.margin_authority.ownership_fence=fence;
   permit.margin_authority.account_namespace=permit.account_namespace;
   permit.margin_authority.request_identity=request; permit.margin_authority.authority_record_id="MARGIN-A";
   permit.margin_authority.basket_id=scope.basket_id; permit.margin_authority.symbol="XAUUSD";
   permit.margin_authority.symbol_specification_sequence=7;
   permit.margin_authority.authority_record_sequence=4; permit.margin_authority.authority_record_digest=SWV5S5_SHA256_EMPTY;
   permit.margin_authority.observation_sequence=4; permit.margin_authority.additional_margin=10.0;
   permit.margin_authority.intent_type=SWV5_INTENT_OPEN; permit.margin_authority.direction=1;
   permit.margin_authority.requested_volume=0.10; permit.margin_authority.requested_price=2000.0;
   permit.margin_authority.account_currency="USD";
   permit.margin_authority.observed_at=995; permit.margin_authority.calculated_at=995;
   permit.margin_authority.projected_account_margin=20.0;
   SWV5S5_TestInitV5(permit.basket_risk_authority.contract_version);
   SWV5S5_TestInitV5(permit.basket_risk_authority.monetary_basis.contract_version);
   permit.basket_risk_authority.persistence_namespace=scope; permit.basket_risk_authority.ownership_fence=fence;
   permit.basket_risk_authority.account_namespace=permit.account_namespace;
   permit.basket_risk_authority.request_identity=request; permit.basket_risk_authority.authority_record_id="BASKET-RISK-A";
   permit.basket_risk_authority.basket_id=scope.basket_id; permit.basket_risk_authority.basket_state_version=2;
   permit.basket_risk_authority.symbol="XAUUSD"; permit.basket_risk_authority.symbol_specification_sequence=7;
   permit.basket_risk_authority.authority_record_sequence=5;
   permit.basket_risk_authority.authority_record_digest=SWV5S5_SHA256_ABC;
   permit.basket_risk_authority.source_snapshot_id="RISK-SNAPSHOT-A";
   permit.basket_risk_authority.source_snapshot_digest=SWV5S5_SHA256_EMPTY;
   permit.basket_risk_authority.resulting_basket_maximum_loss=50.0;
   permit.basket_risk_authority.observed_at=995; permit.basket_risk_authority.calculated_at=995;
   permit.hard_kill_latch_id="HK-A"; permit.hard_kill_latch_generation=3;
   permit.valid_from=900; permit.valid_until=1100;
   if(!SWV5S5_DerivePermitId(permit,permit.permit_id) || !SWV5S5_DerivePermitDigest(permit,permit.permit_digest)) return false;

   SWV5S5_SubmissionAuthorityRecord observed; ZeroMemory(observed); SWV5S5_InitContractVersion(observed.contract_version);
   observed.permit=permit; observed.state=SWV5S5_COMMITTED_NOT_INVOKED; observed.authority_revision=1;
   observed.invocation_claim_id="";
   observed.admission_snapshot.snapshot_digest="";
   observed.admission_snapshot_digest="";
   observed.claim_clock_id="";
   observed.claim_policy_id="";
   if(!SWV5S5_DeriveDurableSubmissionAuthorityDigest(observed,observed.durable_record_digest)) return false;

   SWV5S5_AdmissionAuthorityCollection collect; ZeroMemory(collect);
   collect.persistence_namespace=scope; collect.request_identity=request; collect.attempt_id=request.request_id.attempt_id;
   collect.ownership.fence=fence;
   SWV5S5_TestInitV5(collect.lease_liveness.lease.contract_version);
   collect.lease_liveness.lease.fence=fence; collect.lease_liveness.lease.status=SWV5_LOCK_RENEWED;
   collect.lease_liveness.lease.store_revision="LEASE-STORE-4"; collect.lease_liveness.lease.heartbeat_sequence=9;
   collect.lease_liveness.lease.clock_id="TEST-CLOCK"; collect.lease_liveness.lease.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   collect.lease_liveness.lease.heartbeat_clock_sequence=1; collect.lease_liveness.lease.expiry_clock_sequence=9;
   collect.lease_liveness.lease.heartbeat_at=990; collect.lease_liveness.lease.expires_at=1200;
   collect.producer_trust.record=permit.producer_trust;
   SWV5S5_TestHardKill(scope,permit.account_namespace,collect.hard_kill.state);
   collect.account.account_namespace=permit.account_namespace;
   SWV5S5_TestInitV5(collect.basket.basket.contract_version); collect.basket.basket.basket_id=scope.basket_id;
   collect.basket.basket.ownership_fence=fence; collect.basket.basket.state=SWV5_BASKET_OPENING;
   collect.basket.basket.state_version=2; collect.basket.basket.state_entered_at=900;
   SWV5S5_TestInitV5(collect.basket.basket.accepted_recovery_evidence.contract_version);
   SWV5S5_TestInitV5(collect.basket.basket.broker_queries.contract_version);
   collect.request_set.persistence_namespace=scope; collect.request_set.ownership_fence=fence;
   SWV5S5_TestInitV5(collect.request_set.header.contract_version); collect.request_set.header.request_count=1;
   collect.request_set.header.request_index_revision="REQUEST-SET-1"; collect.request_set.header.record_sequence=1;
   ArrayResize(collect.request_set.requests,1); ZeroMemory(collect.request_set.requests[0]);
   SWV5S5_TestInitV5(collect.request_set.requests[0].contract_version);
   SWV5S5_TestInitV5(collect.request_set.requests[0].intent.contract_version);
   collect.request_set.requests[0].intent.persistence_namespace=scope;
   collect.request_set.requests[0].intent.ownership_fence=fence;
   collect.request_set.requests[0].intent.request_identity=request;
   collect.request_set.requests[0].intent.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   collect.request_set.requests[0].intent.intent_type=SWV5_INTENT_OPEN;
   collect.request_set.requests[0].intent.direction=1;
   collect.request_set.requests[0].intent.normalized_volume=0.10;
   collect.request_set.requests[0].intent.normalized_price=2000.0;
   collect.request_set.requests[0].intent.normalized_stop_price=1990.0;
   collect.request_set.requests[0].intent.normalized_limit_price=2010.0;
   collect.request_set.requests[0].intent.symbol_specification_sequence=7;
   collect.request_set.requests[0].intent.expected_basket_version=2;
   collect.request_set.requests[0].intent.risk_authorization_id="RISK-A";
   collect.request_set.requests[0].intent.authorization_expires_at=1100;
   collect.request_set.requests[0].account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   collect.request_set.requests[0].lifecycle_phase=SWV5_EXECUTION_PHASE_SUBMISSION;
   collect.request_set.requests[0].state=SWV5_REQUEST_SUBMISSION_PENDING;
   collect.request_set.requests[0].residual_requested_volume=0.10;
   collect.request_set.requests[0].retry_disposition=SWV5_RETRY_FORBIDDEN;
   collect.request_set.requests[0].authorization_identity="RISK-A";
   collect.request_set.requests[0].normalization_identity="NORMALIZATION-A";
   collect.request_set.requests[0].last_changed_at=900;
   SWV5S5_TestPendingNestedVersions(collect.request_set.requests[0]);
   if(!SWV5S5_DeriveCompleteRequestSetDigest(collect.request_set.requests,
                                              collect.request_set.header.request_set_digest)) return false;
   SWV5S5_TestInitV5(collect.symbol_specification.specification.contract_version);
   collect.symbol_specification.specification.symbol="XAUUSD"; collect.symbol_specification.specification.specification_sequence=7;
   collect.symbol_specification.specification.point_size=0.01; collect.symbol_specification.specification.tick_size=0.01;
   collect.symbol_specification.specification.pip_size=0.1; collect.symbol_specification.specification.tick_value_profit=1.0;
   collect.symbol_specification.specification.tick_value_loss=1.0; collect.symbol_specification.specification.contract_size=100.0;
   collect.symbol_specification.specification.tick_value_basis_volume=1.0;
   collect.symbol_specification.specification.volume_minimum=0.01; collect.symbol_specification.specification.volume_maximum=100.0;
   collect.symbol_specification.specification.volume_step=0.01; collect.symbol_specification.specification.account_currency="USD";
   collect.symbol_specification.specification.tick_value_currency="USD";
   collect.symbol_specification.specification.authority_source=SWV5_AUTHORITY_SIGNAL_DTO;
   collect.symbol_specification.specification.observed_at=990; collect.symbol_specification.specification.valid_until=1100;
   collect.symbol_specification.specification.complete=true;
   collect.margin.record=permit.margin_authority; collect.basket_risk.record=permit.basket_risk_authority;
   collect.risk_authorization.authorization=permit.risk_authorization;
   SWV5_RiskEvaluationInput binding; ZeroMemory(binding); SWV5S5_TestInitV5(binding.contract_version);
   binding.intent=collect.request_set.requests[0].intent; binding.account_namespace=permit.account_namespace;
   binding.account_mode=SWV5_ACCOUNT_MODE_HEDGING; SWV5S5_TestInitV5(binding.limits.contract_version);
   binding.limits.contract_id="LIMITS-A"; binding.limits.maximum_snapshot_age_seconds=60;
   SWV5S5_TestInitV5(binding.account.contract_version); binding.account.account_namespace=permit.account_namespace;
   binding.account.observed_at=995; binding.account.authoritative=true;
   SWV5S5_TestInitV5(binding.exposure.contract_version); binding.exposure.account_namespace=permit.account_namespace;
   binding.exposure.symbol="XAUUSD"; binding.exposure.observed_at=995; binding.exposure.complete=true;
   SWV5S5_TestInitV5(binding.basket.contract_version); binding.basket.account_namespace=permit.account_namespace;
   binding.basket.lifecycle=collect.basket.basket; binding.basket.observed_at=995;
   SWV5S5_TestInitV5(binding.projected.contract_version); binding.projected.account_namespace=permit.account_namespace;
   binding.projected.symbol="XAUUSD"; binding.projected.complete=true; binding.projected.calculated_at=995;
   SWV5S5_TestInitV5(binding.projected.margin_evidence.contract_version);
   binding.projected.margin_evidence.persistence_namespace=scope;
   binding.projected.margin_evidence.account_namespace=permit.account_namespace;
   binding.projected.margin_evidence.ownership_fence=fence;
   binding.projected.margin_evidence.request_identity=request;
   SWV5S5_TestInitV5(binding.projected.basket_risk_evidence.contract_version);
   binding.projected.basket_risk_evidence.persistence_namespace=scope;
   binding.projected.basket_risk_evidence.account_namespace=permit.account_namespace;
   binding.projected.basket_risk_evidence.ownership_fence=fence;
   binding.projected.basket_risk_evidence.request_identity=request;
   SWV5S5_TestInitV5(binding.projected.basket_risk_evidence.monetary_basis.contract_version);
   SWV5S5_TestInitV5(binding.projected.monetary_basis.contract_version);
   binding.has_margin_authority_record=true; binding.margin_authority_record=permit.margin_authority;
   binding.has_basket_risk_authority_record=true; binding.basket_risk_authority_record=permit.basket_risk_authority;
   binding.symbol_specification=collect.symbol_specification.specification;
   binding.ownership_fence=fence; binding.hard_kill_state=collect.hard_kill.state;
   collect.risk_authorization.current_binding=binding;
   collect.normalized_payload.payload=units; collect.normalized_payload.normalization_identity="NORMALIZATION-A";
   collect.normalized_payload.unit_authority_id="UNIT-A"; collect.normalized_payload.unit_authority_revision=4;
   collect.normalized_payload.unit_authority_digest=SWV5S5_SHA256_ABC;
   collect.submission_permit.permit=permit;
   collect.policy_format.admission_policy_id=SWV5S5_POLICY_ID;
   collect.policy_format.admission_policy_version=SWV5S5_SCHEMA_VERSION;
   collect.policy_format.canonical_format_id=SWV5S5_CANONICAL_POLICY_ID;
   collect.collect_clock.clock_id="TEST-CLOCK"; collect.collect_clock.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   collect.collect_clock.clock_sequence=1; collect.collect_clock.observed_at=998;

   SWV5S5_AdmissionSnapshot snapshot; ZeroMemory(snapshot); SWV5S5_InitContractVersion(snapshot.contract_version);
   snapshot.canonical_policy_id=SWV5S5_CANONICAL_POLICY_ID; snapshot.collect_v1=collect; snapshot.collect_v2=collect;
   snapshot.collect_v2.collect_clock.clock_sequence=2; snapshot.collect_v2.collect_clock.observed_at=999;
   snapshot.claim_clock.clock_id="TEST-CLOCK"; snapshot.claim_clock.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   snapshot.claim_clock.clock_sequence=3; snapshot.claim_clock.observed_at=1000;
   SWV5S5_AdmissionProofInput proof_input; ZeroMemory(proof_input);
   proof_input.trust_anchor.issuer_identity="TRUST-ISSUER";
   proof_input.trust_anchor.issuer_policy_id="TRUST-POLICY";
   proof_input.trust_anchor.trust_anchor_id="TRUST-ANCHOR-A";
   proof_input.trust_anchor.current_authority_record_id="TRUST-A";
   proof_input.trust_anchor.current_authority_generation=5;
   proof_input.trust_scope.persistence_namespace=scope;
   proof_input.trust_scope.producer_component="DECISION";
   proof_input.trust_scope.producer_instance="PRODUCER-A";
   proof_input.trust_scope.producer_epoch=6;
   proof_input.trust_scope.symbol="XAUUSD"; proof_input.trust_scope.timeframe=15;
   proof_input.trust_scope.execution_mode=1; proof_input.trust_scope.publication_clock_id="TEST-CLOCK";
   proof_input.trust_scope.publication_clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   proof_input.trust_scope.ingress_identity=ingress.ingress_identity;
   proof_input.accepted_ingress=ingress; proof_input.current_ownership_lease=collect.lease_liveness.lease;
   SWV5S5_DoubleCollectResult collect_result; SWV5S5_AdmissionProof proof;
   if(!SWV5S5_DoubleCollect(context,proof_input,SWV5S5_TEST_RISK,snapshot,collect_result,proof)) return false;

   ZeroMemory(command); SWV5S5_InitContractVersion(command.contract_version);
   command.claim_policy_id=SWV5S5_POLICY_ID; command.claim_policy_version=SWV5S5_SCHEMA_VERSION;
   command.expected_authority_record=observed; command.expected_authority_revision=observed.authority_revision;
   command.expected_authority_digest=observed.durable_record_digest; command.admission_proof=proof;
   command.current_ownership_lease=collect.lease_liveness.lease; command.claim_clock=snapshot.claim_clock;
   if(!SWV5S5_DeriveClaimId(command,command.claim_id) ||
      !SWV5S5_DeriveClaimCommandDigest(command,command.command_digest)) return false;
   return true;
}

bool SWV5S5_F_MqlBuildValidPreflight(SWV5_ContractValidationContext &context,
                                     SWV5S5_F_AdapterSubmissionCommand &command)
{
   SWV5S5_InvocationClaimCommand claim_command;
   if(!SWV5S5_F_MqlBuildRuntimeClaimFixture(context,claim_command))
   { Print("S5F_BROKER_MQL_FIXTURE|stage=claim-command|result=FAIL"); return false; }
   SWV5S5_InvocationClaimTransition transition;
   if(!SWV5S5_PrepareInvocationClaimTransition(context,SWV5S5_TEST_RISK,
                                                claim_command,transition))
   { Print("S5F_BROKER_MQL_FIXTURE|stage=claim-transition|result=FAIL"); return false; }
   SWV5S5_InvocationClaimResult authoritative;
   ZeroMemory(authoritative); SWV5S5_InitContractVersion(authoritative.contract_version);
   authoritative.disposition=SWV5S5_CLAIM_GRANTED_NOW;
   authoritative.claim_granted_now=true;
   authoritative.resulting_authority_record=transition.proposed_next_record;
   if(!SWV5S5_ValidateAuthoritativeClaimResult(transition,authoritative))
   { Print("S5F_BROKER_MQL_FIXTURE|stage=claim-result|result=FAIL"); return false; }

   ZeroMemory(command); SWV5S5_F_InitVersion(command.contract_version);
   command.prepared_claim=transition;
   command.authoritative_claim=authoritative;
   if(!SWV5S5_F_MqlBuildProfile(authoritative.resulting_authority_record.permit,
                                command.expected_profile,command.observed_environment))
   { Print("S5F_BROKER_MQL_FIXTURE|stage=profile|result=FAIL"); return false; }
   command.direction=authoritative.resulting_authority_record.permit.risk_authorization.authorized_direction;
   command.volume=authoritative.resulting_authority_record.permit.normalized_payload.volume;
   command.price=authoritative.resulting_authority_record.permit.normalized_payload.price;
   command.stop_price=authoritative.resulting_authority_record.permit.normalized_payload.stop_price;
   command.limit_price=authoritative.resulting_authority_record.permit.normalized_payload.limit_price;
   command.filling_mode=1;
   command.comment_metadata="AUDIT-NO-SEND";
   SWV5S5_F_AdapterWireRequest wire;
   if(!SWV5S5_F_MqlBuildWireForCommand(command,wire) ||
      !SWV5S5_F_DeriveAdapterWirePayloadDigest(wire,command.wire_payload_digest) ||
      !SWV5S5_F_DeriveAdapterSubmissionDigest(command,command.submission_digest))
   { Print("S5F_BROKER_MQL_FIXTURE|stage=digests|result=FAIL"); return false; }
   string reason;
   const bool ready=SWV5S5_F_AdapterValidatePreflight(command,reason)==
      SWV5S5_F_ADAPTER_PREFLIGHT_READY_CURRENT_CLAIM;
   if(!ready) PrintFormat("S5F_BROKER_MQL_FIXTURE|stage=preflight|result=FAIL|reason=%s",reason);
   return ready;
}

bool SWV5S5_F_MqlBuildReconciliationFixture(SWV5_ContractValidationContext &context,
                                            SWV5S5_F_ReconciliationInput &candidate)
{
   SWV5S5_F_AdapterSubmissionCommand submission;
   if(!SWV5S5_F_MqlBuildValidPreflight(context,submission))
   { Print("S5F_BROKER_MQL_FIXTURE|stage=reconciliation-preflight|result=FAIL"); return false; }
   SWV5S5_TestContext(context,2000,20);
   ZeroMemory(candidate); SWV5S5_F_InitVersion(candidate.contract_version);
   candidate.prior_state=SWV5S5_F_SUBMISSION_UNRESOLVED;
   candidate.observation_kind=SWV5S5_F_ACCEPTED_SUBMISSION;
   SWV5S5_F_ReconciliationBinding binding;
   ZeroMemory(binding); SWV5S5_F_InitVersion(binding.contract_version);
   binding.profile=submission.expected_profile;
   binding.request_identity=submission.authoritative_claim.resulting_authority_record.permit.request_identity;
   binding.submission_state=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED;
   binding.pending_request_state=SWV5_REQUEST_SUBMISSION_PENDING;
   binding.pending_request_phase=SWV5_EXECUTION_PHASE_SUBMISSION;
   binding.permit_id=submission.authoritative_claim.resulting_authority_record.permit.permit_id;
   binding.invocation_claim_id=submission.authoritative_claim.resulting_authority_record.invocation_claim_id;
   binding.admission_snapshot_digest=submission.authoritative_claim.resulting_authority_record.admission_snapshot.snapshot_digest;
   binding.claim_record_digest=submission.authoritative_claim.resulting_authority_record.durable_record_digest;
   binding.claimed_at=1500;
   binding.claim_clock_sequence=10;
   binding.expected_store_revision="AUDIT-STORE-1";
   binding.expected_reconciliation_revision=1;
   binding.persisted_reconciliation_vector_digest=SWV5S5_SHA256_ABC;
   binding.checkpoint_digest=SWV5S5_SHA256_EMPTY;
   binding.request_set_digest=SWV5S5_SHA256_ABC;
   binding.execution_pending_summary_digest=SWV5S5_SHA256_EMPTY;
   binding.ordered_request_evidence_digest=SWV5S5_SHA256_ABC;
   binding.hard_kill_state_digest=SWV5S5_SHA256_EMPTY;
   binding.symbol_specification_sequence=7;
   binding.expected_basket_version=2;
   binding.direction=1;
   binding.requested_volume=0.10;
   binding.persisted_confirmed_volume=0.0;
   binding.persisted_residual_volume=0.10;

   SWV5_InstanceLease lease;
   ZeroMemory(lease); SWV5S5_TestInitV5(lease.contract_version);
   lease.fence=submission.authoritative_claim.resulting_authority_record.permit.ownership_fence;
   lease.fence.ownership_namespace=binding.profile.persistence_namespace.ownership_namespace;
   lease.fence.owner.key=lease.fence.ownership_namespace;
   lease.fence.fencing_token_digest=SWV5S5_SHA256_ABC;
   lease.fence.lease_version=1;
   lease.status=SWV5_LOCK_RENEWED;
   lease.store_revision=binding.expected_store_revision;
   lease.heartbeat_sequence=1;
   lease.clock_id=context.clock_id;
   lease.clock_authority=context.clock_authority;
   lease.acquired_clock_sequence=10;
   lease.heartbeat_clock_sequence=11;
   lease.expiry_clock_sequence=30;
   lease.acquired_at=1400;
   lease.heartbeat_at=1900;
   lease.expires_at=2100;
   binding.current_reconciliation_lease=lease;
   binding.claim_ownership_fence=lease.fence;

   SWV5S5_F_CorrelationPolicy policy;
   ZeroMemory(policy); SWV5S5_F_InitVersion(policy.contract_version);
   policy.policy_id=SWV5S5_F_CORRELATION_POLICY_ID;
   policy.policy_version=1;
   policy.broker_profile_id=binding.profile.profile_id;
   policy.broker_profile_digest=binding.profile.profile_digest;
   policy.issuing_component=SWV5_COMPONENT_AUTHORITY_OPERATOR;
   policy.authority_source=SWV5_AUTHORITY_OPERATOR;
   policy.approval_reference="AUDIT-CORRELATION-APPROVAL";
   policy.approved_at=1400;
   policy.broker_order_identity_required=true;
   policy.deal_order_link_required=true;
   policy.position_identifier_link_required=true;
   policy.ordered_deal_set_required=true;
   policy.magic_is_strategy_scope_only=true;
   policy.comment_is_non_authoritative=true;
   if(!SWV5S5_F_DeriveCorrelationPolicyDigest(policy,policy.policy_digest)) return false;
   binding.pinned_correlation_policy_id=policy.policy_id;
   binding.pinned_correlation_policy_version=policy.policy_version;
   binding.pinned_correlation_policy_digest=policy.policy_digest;

   SWV5S5_F_CapabilityProof proof;
   ZeroMemory(proof); SWV5S5_F_InitVersion(proof.contract_version);
   proof.artifact_id=SWV5S5_F_CAPABILITY_PROOF_ID;
   proof.artifact_version=1;
   proof.broker_profile_id=binding.profile.profile_id;
   proof.broker_profile_digest=binding.profile.profile_digest;
   proof.issuing_component=SWV5_COMPONENT_AUTHORITY_OPERATOR;
   proof.authority_source=SWV5_AUTHORITY_OPERATOR;
   proof.proof_source_reference="AUDIT-INDEPENDENT-PROOF";
   proof.approval_reference="AUDIT-CAPABILITY-APPROVAL";
   proof.approved_at=1400;
   proof.valid_from=1400;
   proof.valid_until=2100;
   proof.correlation_capability_proven=true;
   proof.query_completeness_capability_proven=true;
   proof.visibility_watermark_proven=true;
   proof.proven_visibility_lag_seconds=1;
   if(!SWV5S5_F_DeriveCapabilityProofDigest(proof,proof.proof_digest)) return false;
   binding.pinned_capability_proof_id=proof.artifact_id;
   binding.pinned_capability_proof_version=proof.artifact_version;
   binding.pinned_capability_proof_digest=proof.proof_digest;
   binding.pinned_negative_policy_id=SWV5S5_F_NEGATIVE_POLICY_ID;
   binding.pinned_negative_policy_version=1;
   binding.pinned_negative_policy_digest=SWV5S5_SHA256_ABC;

   SWV5S5_F_TargetedPositiveEvidence evidence;
   ZeroMemory(evidence); SWV5S5_F_InitVersion(evidence.contract_version);
   evidence.profile=binding.profile;
   evidence.request_identity=binding.request_identity;
   evidence.invocation_claim_id=binding.invocation_claim_id;
   evidence.claim_record_digest=binding.claim_record_digest;
   evidence.correlation_policy_id=policy.policy_id;
   evidence.correlation_policy_version=policy.policy_version;
   evidence.correlation_policy_digest=policy.policy_digest;
   evidence.capability_proof_id=proof.artifact_id;
   evidence.capability_proof_version=proof.artifact_version;
   evidence.capability_proof_digest=proof.proof_digest;
   evidence.independently_query_confirmed=true;
   evidence.magic_used_as_sole_authority=false;
   evidence.comment_used_as_sole_authority=false;
   SWV5S5_TestInitV5(evidence.query_set.contract_version);
   evidence.query_set.required_flags=SWV5_QUERY_ORDERS|SWV5_QUERY_DEALS;
   evidence.query_set.completed_flags=evidence.query_set.required_flags;
   evidence.query_set.authoritative_flags=evidence.query_set.required_flags;
   evidence.query_set.observation_sequence=1;
   evidence.query_set.observed_at=1600;
   evidence.query_set.issuing_component=SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER;
   evidence.query_set.authority_source=SWV5_AUTHORITY_DEAL_HISTORY;
   evidence.query_set.snapshot_id="AUDIT-BROKER-SNAPSHOT";
   evidence.query_set.snapshot_digest=SWV5S5_SHA256_ABC;
   evidence.order_ticket=101;
   evidence.deal_ticket=201;
   evidence.deal_order_ticket=101;
   evidence.deal_count=1;
   evidence.ordered_deal_set_digest=SWV5S5_SHA256_EMPTY;
   evidence.all_deals_linked_to_order_and_position=true;
   evidence.all_rows_read_successfully=true;
   evidence.position_identifier=301;
   evidence.order_position_identifier=301;
   evidence.deal_position_identifier=301;
   evidence.symbol=binding.profile.symbol;
   evidence.direction=binding.direction;
   evidence.execution_price=2000.0;
   evidence.cumulative_confirmed_volume=0.04;
   evidence.requested_volume=binding.requested_volume;
   evidence.observed_magic=SWV5_RUNTIME_STRATEGY_MAGIC;
   evidence.observed_comment="AUDIT-NO-SEND";
   evidence.observed_at=1600;
   if(!SWV5S5_F_DerivePositiveEvidenceDigest(evidence,evidence.evidence_digest) ||
      !SWV5S5_F_IsBindingValid(context,binding) ||
      !SWV5S5_F_IsPositiveEvidenceValid(context,binding,policy,proof,evidence))
   {
      PrintFormat("S5F_BROKER_MQL_FIXTURE|stage=reconciliation-validation|binding=%s|positive=%s",
         SWV5S5_F_IsBindingValid(context,binding) ? "PASS" : "FAIL",
         SWV5S5_F_IsPositiveEvidenceValid(context,binding,policy,proof,evidence) ? "PASS" : "FAIL");
      PrintFormat("S5F_BROKER_MQL_FIXTURE_DETAIL|profile=%s|request=%s|correlation=%s|capability=%s|query=%s|watermark=%s|digest64=%s|time=%s|volume=%s",
         SWV5S5_F_EqualProfile(binding.profile,evidence.profile) ? "PASS" : "FAIL",
         SWV5S5_EqualRequestIdentity(binding.request_identity,evidence.request_identity) ? "PASS" : "FAIL",
         SWV5S5_F_IsCorrelationPolicyValid(binding,policy) ? "PASS" : "FAIL",
         SWV5S5_F_IsCapabilityProofValid(binding,proof) ? "PASS" : "FAIL",
         SWV5S5_F_IsQuerySetExact(evidence.query_set,SWV5_QUERY_ORDERS|SWV5_QUERY_DEALS,
            SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER,SWV5_AUTHORITY_DEAL_HISTORY) ? "PASS" : "FAIL",
         evidence.query_set.observation_sequence>binding.expected_broker_query_high_watermark ? "PASS" : "FAIL",
         SWV5S5_IsDigest64Lower(evidence.ordered_deal_set_digest) ? "PASS" : "FAIL",
         evidence.observed_at>=evidence.query_set.observed_at && evidence.query_set.observed_at>=binding.claimed_at ? "PASS" : "FAIL",
         evidence.requested_volume==binding.requested_volume &&
            evidence.cumulative_confirmed_volume<=evidence.requested_volume+context.volume_tolerance ? "PASS" : "FAIL");
      PrintFormat("S5F_BROKER_MQL_QUERY_DETAIL|v=%s|required=%I64u|completed=%I64u|authoritative=%I64u|seq=%I64u|at=%I64d|component=%d|source=%d|id=%s|digest=%s",
         SWV5S5_IsV5Version(evidence.query_set.contract_version) ? "PASS" : "FAIL",
         evidence.query_set.required_flags,evidence.query_set.completed_flags,
         evidence.query_set.authoritative_flags,evidence.query_set.observation_sequence,
         (long)evidence.query_set.observed_at,(int)evidence.query_set.issuing_component,
         (int)evidence.query_set.authority_source,evidence.query_set.snapshot_id,
         evidence.query_set.snapshot_digest);
      return false;
   }
   candidate.binding=binding;
   candidate.correlation_policy=policy;
   candidate.capability_proof=proof;
   candidate.positive_evidence_present=true;
   candidate.positive_evidence=evidence;
   return
      SWV5S5_F_IsBindingValid(context,binding) &&
      SWV5S5_F_IsPositiveEvidenceValid(context,binding,policy,proof,evidence);
}

int SWV5S5_F_RunBrokerAdapterMqlAssertions(SWV5S5_F_MqlAssertionResult &result)
{
   ZeroMemory(result);
   long units=0;
   SWV5S5_F_MqlAssert("MQL-GRID-01-BINARY-DECIMAL",
      SWV5S5_F_AdapterCanonicalGridUnits(0.30,0.10,false,units) && units==3,result);
   SWV5S5_F_MqlAssert("MQL-GRID-02-OFF-GRID",
      !SWV5S5_F_AdapterCanonicalGridUnits(0.305,0.10,false,units),result);
   SWV5S5_F_MqlAssert("MQL-GRID-03-ZERO-OPTIONAL",
      SWV5S5_F_AdapterCanonicalGridUnits(0.0,0.01,true,units) && units==0,result);
   SWV5S5_F_MqlAssert("MQL-GRID-04-ZERO-REQUIRED",
      !SWV5S5_F_AdapterCanonicalGridUnits(0.0,0.01,false,units),result);
   SWV5S5_F_MqlAssert("MQL-GRID-05-CANONICAL-EQUALITY",
      SWV5S5_F_AdapterCanonicalGridEqual(0.1+0.2,0.3,0.1,false),result);

   ENUM_ORDER_TYPE_FILLING filling=ORDER_FILLING_RETURN;
   SWV5S5_F_MqlAssert("MQL-FILL-01-FOK-EXACT",
      SWV5S5_F_AdapterResolveFilling(1,3,filling) && filling==ORDER_FILLING_FOK,result);
   SWV5S5_F_MqlAssert("MQL-FILL-02-IOC-EXACT",
      SWV5S5_F_AdapterResolveFilling(2,3,filling) && filling==ORDER_FILLING_IOC,result);
   SWV5S5_F_MqlAssert("MQL-FILL-03-COMBINED-REJECT",
      !SWV5S5_F_AdapterResolveFilling(3,3,filling),result);
   SWV5S5_F_MqlAssert("MQL-FILL-04-UNSUPPORTED-REJECT",
      !SWV5S5_F_AdapterResolveFilling(1,2,filling),result);

   SWV5S5_F_MqlAssert("MQL-PRICE-01-BUY-SEMANTICS",
      SWV5S5_F_AdapterMarketProtectionValid(1,2500.10,2499.90,2500.30,0.10),result);
   SWV5S5_F_MqlAssert("MQL-PRICE-02-SELL-SEMANTICS",
      SWV5S5_F_AdapterMarketProtectionValid(-1,2500.10,2500.30,2499.90,0.10),result);
   SWV5S5_F_MqlAssert("MQL-PRICE-03-BUY-WRONG-SIDE",
      !SWV5S5_F_AdapterMarketProtectionValid(1,2500.10,2500.20,2500.30,0.10),result);
   SWV5S5_F_MqlAssert("MQL-PRICE-04-OFF-TICK",
      !SWV5S5_F_AdapterMarketProtectionValid(1,2500.105,2499.90,2500.30,0.10),result);

   SWV5S5_F_AdapterWireRequest wire,mutated_wire;
   SWV5S5_F_MqlBuildWire(wire);
   SWV5S5_F_MqlBuildWire(mutated_wire);
   string first_digest="",second_digest="",mutated_digest="";
   const bool first_ok=SWV5S5_F_DeriveAdapterWirePayloadDigest(wire,first_digest);
   const bool second_ok=SWV5S5_F_DeriveAdapterWirePayloadDigest(wire,second_digest);
   mutated_wire.take_profit_price=2500.40;
   const bool mutation_ok=SWV5S5_F_DeriveAdapterWirePayloadDigest(mutated_wire,mutated_digest);
   SWV5S5_F_MqlAssert("MQL-WIRE-01-DETERMINISTIC",
      first_ok && second_ok && first_digest==second_digest && first_digest!="",result);
   SWV5S5_F_MqlAssert("MQL-WIRE-02-MUTATION-SENSITIVE",
      first_ok && mutation_ok && first_digest!=mutated_digest,result);

   SWV5S5_F_AdapterEnvironment first_environment,second_environment;
   ZeroMemory(first_environment); ZeroMemory(second_environment);
   first_environment.broker_identity="BROKER-A";
   first_environment.server="DEMO-SERVER";
   first_environment.account_login=42;
   first_environment.account_currency="USD";
   first_environment.symbol="AUDIT_XAUUSD";
   first_environment.terminal_build=1;
   first_environment.mql_build=1;
   first_environment.account_trade_mode=0;
   first_environment.account_mode=SWV5_ACCOUNT_MODE_NETTING;
   first_environment.connected=true;
   first_environment.terminal_trade_allowed=true;
   first_environment.mql_trade_allowed=true;
   first_environment.account_trade_allowed=true;
   first_environment.account_trade_expert=true;
   first_environment.symbol_trade_mode=1;
   first_environment.symbol_execution_mode=2;
   first_environment.symbol_filling_mask=3;
   first_environment.symbol_digits=2;
   first_environment.point=0.01;
   first_environment.tick_size=0.10;
   first_environment.volume_min=0.01;
   first_environment.volume_max=100.0;
   first_environment.volume_step=0.01;
   first_environment.runtime_magic=1179670069;
   second_environment=first_environment;
   SWV5S5_F_MqlAssert("MQL-TOCTOU-01-STABLE-SAMPLE",
      SWV5S5_F_AdapterEnvironmentStable(first_environment,second_environment),result);
   second_environment.account_trade_expert=false;
   SWV5S5_F_MqlAssert("MQL-TOCTOU-02-PERMISSION-CHANGE",
      !SWV5S5_F_AdapterEnvironmentStable(first_environment,second_environment),result);
   second_environment=first_environment;
   second_environment.tick_size=0.01;
   SWV5S5_F_MqlAssert("MQL-TOCTOU-03-SPEC-CHANGE",
      !SWV5S5_F_AdapterEnvironmentStable(first_environment,second_environment),result);

   SWV5S5_F_BrokerQuerySnapshot broker;
   SWV5S5_F_ExecutionPendingSnapshot execution;
   ZeroMemory(broker); ZeroMemory(execution);
   broker.positions_enumeration_complete=true;
   broker.orders_enumeration_complete=true;
   broker.history_orders_enumeration_complete=true;
   broker.history_deals_enumeration_complete=true;
   broker.callback_transactions_enumeration_complete=true;
   SWV5S5_F_MqlAssert("MQL-QUERY-01-EMPTY-COMPLETE",
      SWV5S5_F_AdapterBrokerQueryShapeComplete(broker),result);
   broker.positions_reported_total=1;
   SWV5S5_F_MqlAssert("MQL-QUERY-02-OMITTED-ROW-REJECT",
      !SWV5S5_F_AdapterBrokerQueryShapeComplete(broker),result);
   broker.positions_reported_total=0;
   broker.broker_read_path_id="BROKER-READ";
   broker.broker_authority_instance_id="BROKER-AUTH";
   broker.broker_sequence_authority_id="BROKER-SEQ";
   broker.query_set.snapshot_id="BROKER-SNAPSHOT";
   broker.query_set.snapshot_digest="BROKER-DIGEST";
   execution.execution_read_path_id="EXECUTION-READ";
   execution.execution_authority_instance_id="EXECUTION-AUTH";
   execution.execution_sequence_authority_id="EXECUTION-SEQ";
   execution.query_set.snapshot_id="EXECUTION-SNAPSHOT";
   execution.query_set.snapshot_digest="EXECUTION-DIGEST";
   execution.operation_success=true;
   execution.enumeration_complete=true;
   SWV5S5_F_MqlAssert("MQL-EVIDENCE-01-INDEPENDENT",
      SWV5S5_F_AdapterEvidenceSourcesIndependent(broker,execution),result);
   execution.execution_sequence_authority_id=broker.broker_sequence_authority_id;
   SWV5S5_F_MqlAssert("MQL-EVIDENCE-02-SHARED-AUTHORITY-REJECT",
      !SWV5S5_F_AdapterEvidenceSourcesIndependent(broker,execution),result);
   execution.execution_sequence_authority_id="EXECUTION-SEQ";
   SWV5S5_F_MqlAssert("MQL-QUERY-03-EXECUTION-COMPLETE",
      SWV5S5_F_AdapterExecutionQueryShapeComplete(execution),result);
   execution.reported_total=1;
   SWV5S5_F_MqlAssert("MQL-QUERY-04-EXECUTION-OMISSION-REJECT",
      !SWV5S5_F_AdapterExecutionQueryShapeComplete(execution),result);

   SWV5_ContractValidationContext preflight_context;
   SWV5S5_F_AdapterSubmissionCommand valid_command;
   const bool valid_fixture=SWV5S5_F_MqlBuildValidPreflight(preflight_context,valid_command);
   string preflight_reason="";
   SWV5S5_F_MqlAssert("MQL-PREFLIGHT-01-CURRENT-EPHEMERAL-CLAIM",
      valid_fixture && SWV5S5_F_AdapterValidatePreflight(valid_command,preflight_reason)==
         SWV5S5_F_ADAPTER_PREFLIGHT_READY_CURRENT_CLAIM,result);

   SWV5S5_F_AdapterSubmissionCommand changed_command=valid_command;
   ZeroMemory(changed_command.authoritative_claim);
   SWV5S5_F_MqlAssert("MQL-PREFLIGHT-02-CURRENT-CLAIM-REQUIRED",
      SWV5S5_F_AdapterValidatePreflight(changed_command,preflight_reason)==
         SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT &&
         preflight_reason=="CURRENT_OPERATION_CLAIM_GRANT_REQUIRED",result);
   changed_command=valid_command;
   changed_command.authoritative_claim.claim_granted_now=false;
   SWV5S5_F_MqlAssert("MQL-PREFLIGHT-03-CLAIM-GRANTED-NOW-FALSE",
      SWV5S5_F_AdapterValidatePreflight(changed_command,preflight_reason)==
         SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT,result);
   changed_command=valid_command;
   changed_command.authoritative_claim.resulting_authority_record.durable_record_digest=SWV5S5_SHA256_EMPTY;
   SWV5S5_F_MqlAssert("MQL-PREFLIGHT-04-STALE-AUTHORITATIVE-CLAIM",
      SWV5S5_F_AdapterValidatePreflight(changed_command,preflight_reason)==
         SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT &&
         preflight_reason=="CURRENT_OPERATION_CLAIM_GRANT_REQUIRED",result);
   changed_command=valid_command;
   changed_command.observed_environment.server="FOREIGN-SERVER";
   SWV5S5_F_MqlAssert("MQL-PREFLIGHT-05-EXACT-PROFILE-MISMATCH",
      SWV5S5_F_AdapterValidatePreflight(changed_command,preflight_reason)==
         SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT &&
         preflight_reason=="EXACT_BROKER_PROFILE_MISMATCH",result);

#define SWV5S5_F_PERMISSION_CASE(test_name,field_name) \
   changed_command=valid_command; changed_command.observed_environment.field_name=false; \
   SWV5S5_F_MqlAssert(test_name,SWV5S5_F_AdapterValidatePreflight(changed_command,preflight_reason)== \
      SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT && preflight_reason=="TRADING_PERMISSION_NOT_POSITIVELY_ATTESTED",result)
   SWV5S5_F_PERMISSION_CASE("MQL-PREFLIGHT-06-CONNECTION-FALSE",connected);
   SWV5S5_F_PERMISSION_CASE("MQL-PREFLIGHT-07-TERMINAL-PERMISSION-FALSE",terminal_trade_allowed);
   SWV5S5_F_PERMISSION_CASE("MQL-PREFLIGHT-08-MQL-PERMISSION-FALSE",mql_trade_allowed);
   SWV5S5_F_PERMISSION_CASE("MQL-PREFLIGHT-09-ACCOUNT-PERMISSION-FALSE",account_trade_allowed);
   SWV5S5_F_PERMISSION_CASE("MQL-PREFLIGHT-10-EXPERT-PERMISSION-FALSE",account_trade_expert);
#undef SWV5S5_F_PERMISSION_CASE

   changed_command=valid_command; changed_command.direction=-1;
   SWV5S5_F_MqlAssert("MQL-PREFLIGHT-11-DIRECTION-MISMATCH",
      SWV5S5_F_AdapterValidatePreflight(changed_command,preflight_reason)==
         SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT &&
         preflight_reason=="COMMAND_NOT_EXACTLY_BOUND_TO_PERMIT",result);
   changed_command=valid_command; changed_command.volume+=0.01;
   SWV5S5_F_MqlAssert("MQL-PREFLIGHT-12-VOLUME-MISMATCH",
      SWV5S5_F_AdapterValidatePreflight(changed_command,preflight_reason)==
         SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT &&
         preflight_reason=="COMMAND_NOT_EXACTLY_BOUND_TO_PERMIT",result);
   changed_command=valid_command; changed_command.price+=0.01;
   SWV5S5_F_MqlAssert("MQL-PREFLIGHT-13-PRICE-MISMATCH",
      SWV5S5_F_AdapterValidatePreflight(changed_command,preflight_reason)==
         SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT &&
         preflight_reason=="COMMAND_NOT_EXACTLY_BOUND_TO_PERMIT",result);
   changed_command=valid_command; changed_command.submission_digest=SWV5S5_SHA256_EMPTY;
   SWV5S5_F_MqlAssert("MQL-PREFLIGHT-14-SUBMISSION-DIGEST-MISMATCH",
      SWV5S5_F_AdapterValidatePreflight(changed_command,preflight_reason)==
         SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT &&
         preflight_reason=="SUBMISSION_DIGEST_INVALID",result);
   changed_command=valid_command; changed_command.filling_mode=3;
   SWV5S5_F_MqlAssert("MQL-PREFLIGHT-15-COMBINED-FILLING-REJECT",
      SWV5S5_F_AdapterValidatePreflight(changed_command,preflight_reason)==
         SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT &&
         preflight_reason=="FILLING_MODE_NOT_SUPPORTED",result);

   SWV5S5_F_AdapterEnvironment changed_environment=valid_command.observed_environment;
   changed_environment.symbol_filling_mask=2;
   string final_reason="";
   SWV5S5_F_MqlAssert("MQL-FINAL-ENV-01-SPEC-MISMATCH-REJECT",
      !SWV5S5_F_AdapterValidateFinalEnvironment(valid_command.expected_profile,
         valid_command.observed_environment,changed_environment,final_reason) &&
         final_reason=="FINAL_ENVIRONMENT_RESAMPLE_CHANGED",result);

   SWV5S5_F_AdapterSyncResult sync;
   ZeroMemory(sync);
   sync.invocation_attempted=true;
   sync.classification=SWV5S5_F_AdapterClassifySync(true,true,10009);
   sync.final_confirmation=false;
   sync.retry_allowed=false;
   SWV5S5_F_MqlAssert("MQL-SYNC-01-ACCEPTED-REMAINS-NONFINAL",
      sync.classification==SWV5S5_F_ADAPTER_SYNC_ACCEPTED_UNRESOLVED &&
      SWV5S5_F_AdapterObservationKind(sync)==SWV5S5_F_ACCEPTED_SUBMISSION &&
      !sync.final_confirmation && !sync.retry_allowed,result);
   SWV5S5_F_MqlAssert("MQL-SYNC-02-CLIENT-LOCAL-NONRETRY",
      SWV5S5_F_AdapterClassifySync(true,false,10027)==
         SWV5S5_F_ADAPTER_SYNC_CLIENT_LOCAL_REJECTION_UNRESOLVED,result);
   SWV5S5_F_MqlAssert("MQL-SYNC-03-TIMEOUT-NONRETRY",
      SWV5S5_F_AdapterClassifySync(true,false,10012)==
         SWV5S5_F_ADAPTER_SYNC_TIMEOUT_UNRESOLVED,result);
   SWV5S5_F_MqlAssert("MQL-SYNC-04-TRANSPORT-NONRETRY",
      SWV5S5_F_AdapterClassifySync(true,false,0)==
         SWV5S5_F_ADAPTER_SYNC_TRANSPORT_FAILURE_UNRESOLVED,result);
   SWV5S5_F_MqlAssert("MQL-SYNC-05-UNKNOWN-NONRETRY",
      SWV5S5_F_AdapterClassifySync(true,true,19999)==
         SWV5S5_F_ADAPTER_SYNC_UNKNOWN_UNRESOLVED,result);

   SWV5_ContractValidationContext reconciliation_context;
   SWV5S5_F_ReconciliationInput reconciliation;
   const bool reconciliation_fixture=SWV5S5_F_MqlBuildReconciliationFixture(
      reconciliation_context,reconciliation);
   SWV5S5_F_ReconciliationResult reconciliation_result;
   const bool partial_result=reconciliation_fixture &&
      SWV5S5_F_EvaluateReconciliation(reconciliation_context,reconciliation,reconciliation_result);
   SWV5S5_F_MqlAssert("MQL-RECON-01-PARTIAL-RESIDUAL-NONAUTHORITY",
      partial_result && reconciliation_result.state==SWV5S5_F_PARTIAL_EFFECT_CONFIRMED &&
      !reconciliation_result.residual_is_submission_authority &&
      reconciliation_result.requires_new_request_identity_for_residual &&
      !reconciliation_result.retry_allowed,result);

   SWV5S5_F_ReconciliationInput terminal_conflict=reconciliation;
   terminal_conflict.prior_state=SWV5S5_F_PARTIAL_EFFECT_CONFIRMED;
   terminal_conflict.binding.submission_state=SWV5S5_AUTHORITATIVE_SIDE_EFFECT_CONFIRMED;
   terminal_conflict.binding.persisted_confirmed_volume=0.04;
   terminal_conflict.binding.persisted_residual_volume=0.06;
   terminal_conflict.binding.persisted_terminal_evidence_digest=
      terminal_conflict.positive_evidence.evidence_digest;
   const bool terminal_return=SWV5S5_F_EvaluateReconciliation(reconciliation_context,
      terminal_conflict,reconciliation_result);
   SWV5S5_F_MqlAssert("MQL-RECON-02-TERMINAL-CONFLICT-BLOCKED",
      !terminal_return && reconciliation_result.state==SWV5S5_F_RECONCILIATION_BLOCKED &&
      reconciliation_result.reason_code=="TERMINAL_EVIDENCE_CONFLICT" &&
      !reconciliation_result.retry_allowed,result);

   SWV5S5_F_ReconciliationInput blocked_input;
   ZeroMemory(blocked_input); SWV5S5_F_InitVersion(blocked_input.contract_version);
   blocked_input.prior_state=SWV5S5_F_RECONCILIATION_BLOCKED;
   const bool blocked_return=SWV5S5_F_EvaluateReconciliation(reconciliation_context,
      blocked_input,reconciliation_result);
   SWV5S5_F_MqlAssert("MQL-RECON-03-BLOCKED-STICKY",
      !blocked_return && reconciliation_result.state==SWV5S5_F_RECONCILIATION_BLOCKED &&
      reconciliation_result.reason_code==
         "RECONCILIATION_BLOCKED_STICKY_REQUIRES_EXTERNAL_RECOVERY_AUTHORITY" &&
      !reconciliation_result.retry_allowed,result);

   string signature="";
   SWV5S5_DomainDigest("SWV5-SPRINT5-PHASE-F-BROKER-MQL-ASSERTIONS-V1",
                       result.signature_material,signature);
   PrintFormat("S5F_BROKER_MQL_RESULT|total=%d|passed=%d|failed=%d|skipped=%d|signature=%s|broker_calls=0",
               result.total,result.passed,result.failed,result.skipped,signature);
   return result.failed;
}

#endif
