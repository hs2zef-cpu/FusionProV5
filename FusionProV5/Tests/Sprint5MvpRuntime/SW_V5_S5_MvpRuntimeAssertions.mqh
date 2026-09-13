#ifndef SW_V5_S5_MVP_RUNTIME_ASSERTIONS_MQH
#define SW_V5_S5_MVP_RUNTIME_ASSERTIONS_MQH

// OFFLINE TEST ONLY / NO BROKER MUTATION / NO OrderSend.

#include "../../ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpOfflineOrchestrator.mqh"
#include "../ContractVerification/SW_V5_TestFixtures.mqh"

struct SWV5S5_MvpTestCollector
{
   uint total;
   uint passed;
   uint failed;
   ulong signature;
};

void SWV5S5_MvpRecord(SWV5S5_MvpTestCollector &c,const string id,const bool passed)
{
   c.total++; if(passed)c.passed++; else c.failed++;
   string item=id+":"+(passed ? "PASS" : "FAIL");
   for(int i=0;i<StringLen(item);i++) c.signature=(c.signature^(ulong)StringGetCharacter(item,i))*1099511628211;
   Print("MVP_TEST|",id,"|",(passed ? "PASS" : "FAIL"));
}

void SWV5S5_MvpFixtureContext(SWV5_ContractValidationContext &context)
{
   ZeroMemory(context); SWV5S5_InitContractVersion(context.expected_version);
   context.clock_id="BROKER-SERVER-CLOCK"; context.clock_authority=SWV5_TIME_AUTHORITY_BROKER_SERVER;
   context.clock_time=D'2026.09.12 12:00:05'; context.clock_sequence=100;
   context.evaluation_sequence=100; context.price_tolerance=0.0000001; context.volume_tolerance=0.0000001;
}

void SWV5S5_MvpFixtureSpecification(const SWV5_ContractValidationContext &context,
                                    SWV5_SymbolUnitSpecification &specification)
{
   ZeroMemory(specification); specification.contract_version=context.expected_version;
   specification.symbol=SWV5S5_MVP_SYMBOL; specification.specification_sequence=1;
   specification.digits=3; specification.point_size=0.001; specification.tick_size=0.001;
   specification.pip_size=0.10; specification.tick_value_profit=0.01; specification.tick_value_loss=0.01;
   specification.contract_size=100.0; specification.calculation_mode=SWV5_SYMBOL_CALCULATION_XAU_QUANTITY;
   specification.tick_value_basis_volume=0.01; specification.volume_minimum=0.01;
   specification.volume_maximum=100.0; specification.volume_step=0.01;
   specification.stops_level_points=0; specification.freeze_level_points=0;
   specification.account_currency="USD"; specification.tick_value_currency="USD";
   specification.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
   specification.observed_at=context.clock_time-5;
   specification.valid_until=specification.observed_at+10; specification.complete=true;
}

bool SWV5S5_MvpCallbackEqual(const SWV5S5_F_AdapterCallbackEvidence &a,
                             const SWV5S5_F_AdapterCallbackEvidence &b)
{
   return a.request_correlation_id==b.request_correlation_id && a.attempt_id==b.attempt_id &&
      a.invocation_claim_id==b.invocation_claim_id && a.claim_record_digest==b.claim_record_digest &&
      a.profile_digest==b.profile_digest && a.callback_sequence==b.callback_sequence &&
      a.observed_at==b.observed_at && a.transaction_type==b.transaction_type &&
      a.order_ticket==b.order_ticket && a.deal_ticket==b.deal_ticket &&
      a.position_identifier==b.position_identifier && a.position_by_identifier==b.position_by_identifier &&
      a.symbol==b.symbol && a.order_type==b.order_type && a.order_state==b.order_state &&
      a.deal_type==b.deal_type && SWV5S5_MvpNear(a.price,b.price) && SWV5S5_MvpNear(a.volume,b.volume) &&
      a.request_action==b.request_action && a.request_magic==b.request_magic &&
      a.request_comment==b.request_comment && a.result_retcode==b.result_retcode &&
      a.result_retcode_external==b.result_retcode_external &&
      a.request_id_session_local==b.request_id_session_local &&
      a.final_confirmation==b.final_confirmation && a.retry_allowed==b.retry_allowed &&
      a.evidence_digest==b.evidence_digest;
}

void SWV5S5_RunMvpRuntimeAssertions(SWV5S5_MvpTestCollector &c)
{
   ZeroMemory(c); c.signature=1469598103934665603;
   SWV5S5_MvpRecord(c,"PROFILE-ID",SWV5S5_MVP_PROFILE_ID=="FUSION-V5-DEMO-MVP-V1");
   SWV5S5_MvpRecord(c,"RISK-POLICY-ID",SWV5S5_MVP_RISK_POLICY_ID=="FUSION-V5-DEMO-MVP-RISK-V1");
   SWV5S5_MvpRecord(c,"PROFILE-SYMBOL",SWV5S5_MVP_SYMBOL=="XAUUSD");
   SWV5S5_MvpRecord(c,"PROFILE-POINT",SWV5S5_MvpNear(SWV5S5_MVP_POINT_SIZE,0.001));
   SWV5S5_MvpRecord(c,"PROFILE-PIP",SWV5S5_MvpNear(SWV5S5_MVP_POINT_SIZE*100.0,0.10));
   SWV5S5_MvpRecord(c,"PROFILE-VOLUME",SWV5S5_MvpNear(SWV5S5_MVP_MAX_VOLUME,0.01));

   SWV5_ContractValidationContext context; SWV5S5_MvpFixtureContext(context);
   SWV5_SymbolUnitSpecification specification; SWV5S5_MvpFixtureSpecification(context,specification);
   SWV5S5_MvpRecord(c,"SYMBOL-VALID",SWV5S5_MvpSpecificationValid(context,specification));
   SWV5_SymbolUnitSpecification changed=specification; changed.symbol="EURUSD";
   SWV5S5_MvpRecord(c,"SYMBOL-WRONG",!SWV5S5_MvpSpecificationValid(context,changed));
   changed=specification; changed.digits=2;
   SWV5S5_MvpRecord(c,"SYMBOL-DIGITS",!SWV5S5_MvpSpecificationValid(context,changed));
   changed=specification; changed.point_size=0.01;
   SWV5S5_MvpRecord(c,"SYMBOL-POINT",!SWV5S5_MvpSpecificationValid(context,changed));
   changed=specification; changed.complete=false;
   SWV5S5_MvpRecord(c,"SYMBOL-INCOMPLETE",!SWV5S5_MvpSpecificationValid(context,changed));
   changed=specification; changed.valid_until=context.clock_time;
   SWV5S5_MvpRecord(c,"SYMBOL-EXCLUSIVE-EXPIRY",!SWV5S5_MvpSpecificationValid(context,changed));
   changed=specification; changed.pip_size=0.01;
   SWV5S5_MvpRecord(c,"SYMBOL-PIP-CONVENTION",!SWV5S5_MvpSpecificationValid(context,changed));
   changed=specification; changed.account_currency="EUR";
   SWV5S5_MvpRecord(c,"SYMBOL-NON-USD",!SWV5S5_MvpSpecificationValid(context,changed));
   changed=specification; changed.authority_source=SWV5_AUTHORITY_SIGNAL_DTO;
   SWV5S5_MvpRecord(c,"SYMBOL-LIVE-AUTHORITY",!SWV5S5_MvpSpecificationValid(context,changed));

   SWV5S5_MvpOperatorInvocation op;
   op.operator_id="OPERATOR-1"; op.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
   op.authentication_reference="AUTH-EXPLICIT-1"; op.authenticated_at=context.clock_time;
   SWV5S5_MvpRecord(c,"OPERATOR-VALID",SWV5S5_MvpOperatorInvocationValid(op,context.clock_time));
   SWV5S5_MvpOperatorInvocation changed_op=op; changed_op.operator_id="";
   SWV5S5_MvpRecord(c,"OPERATOR-ID-BLANK",!SWV5S5_MvpOperatorInvocationValid(changed_op,context.clock_time));
   changed_op=op; changed_op.authority_role="";
   SWV5S5_MvpRecord(c,"OPERATOR-ROLE-BLANK",!SWV5S5_MvpOperatorInvocationValid(changed_op,context.clock_time));
   changed_op=op; changed_op.authority_role="WRONG";
   SWV5S5_MvpRecord(c,"OPERATOR-ROLE-WRONG",!SWV5S5_MvpOperatorInvocationValid(changed_op,context.clock_time));
   changed_op=op; changed_op.authentication_reference="";
   SWV5S5_MvpRecord(c,"OPERATOR-AUTH-BLANK",!SWV5S5_MvpOperatorInvocationValid(changed_op,context.clock_time));
   changed_op=op; changed_op.authenticated_at--;
   SWV5S5_MvpRecord(c,"OPERATOR-CLOCK-MISMATCH",!SWV5S5_MvpOperatorInvocationValid(changed_op,context.clock_time));

   SWV5_RiskLimits limits; SWV5S5_MvpLoadRiskLimits(limits);
   SWV5S5_MvpRecord(c,"RISK-LIMITS-EXACT",SWV5S5_MvpRiskLimitsExact(limits));
   SWV5_RiskLimits changed_limits=limits; changed_limits.minimum_equity=99.0;
   SWV5S5_MvpRecord(c,"RISK-EQUITY-LOCK",!SWV5S5_MvpRiskLimitsExact(changed_limits));
   changed_limits=limits; changed_limits.maximum_daily_net_loss=11.0;
   SWV5S5_MvpRecord(c,"RISK-DAILY-LOSS-LOCK",!SWV5S5_MvpRiskLimitsExact(changed_limits));
   changed_limits=limits; changed_limits.maximum_account_margin_fraction=0.11;
   SWV5S5_MvpRecord(c,"RISK-MARGIN-LOCK",!SWV5S5_MvpRiskLimitsExact(changed_limits));
   changed_limits=limits; changed_limits.maximum_basket_loss=5.01;
   SWV5S5_MvpRecord(c,"RISK-BASKET-LOSS-LOCK",!SWV5S5_MvpRiskLimitsExact(changed_limits));
   changed_limits=limits; changed_limits.maximum_aggregate_notional=10001.0;
   SWV5S5_MvpRecord(c,"RISK-NOTIONAL-LOCK",!SWV5S5_MvpRiskLimitsExact(changed_limits));
   changed_limits=limits; changed_limits.maximum_live_baskets=2;
   SWV5S5_MvpRecord(c,"RISK-BASKET-COUNT-LOCK",!SWV5S5_MvpRiskLimitsExact(changed_limits));
   changed_limits=limits; changed_limits.maximum_snapshot_age_seconds=6;
   SWV5S5_MvpRecord(c,"RISK-FRESHNESS-LOCK",!SWV5S5_MvpRiskLimitsExact(changed_limits));

   SWV5S5_MvpRecord(c,"RECON-BLOCKED-STICKY",SWV5S5_MvpReconciliationTransitionAllowed(
      (int)SWV5S5_F_RECONCILIATION_BLOCKED,(int)SWV5S5_F_RECONCILIATION_BLOCKED));
   SWV5S5_MvpRecord(c,"RECON-BLOCKED-NO-ESCAPE",!SWV5S5_MvpReconciliationTransitionAllowed(
      (int)SWV5S5_F_RECONCILIATION_BLOCKED,(int)SWV5S5_F_SUBMISSION_UNRESOLVED));
   SWV5S5_MvpRecord(c,"RECON-TERMINAL-MONOTONIC",!SWV5S5_MvpReconciliationTransitionAllowed(
      (int)SWV5S5_F_SIDE_EFFECT_POSITIVELY_CONFIRMED,(int)SWV5S5_F_NO_SIDE_EFFECT_CONFIRMED));
   SWV5S5_MvpRecord(c,"RECON-UNRESOLVED-TO-POSITIVE",SWV5S5_MvpReconciliationTransitionAllowed(
      (int)SWV5S5_F_SUBMISSION_UNRESOLVED,(int)SWV5S5_F_SIDE_EFFECT_POSITIVELY_CONFIRMED));

   SWV5S5_F_AdapterCallbackEvidence callback; ZeroMemory(callback); SWV5S5_F_InitVersion(callback.contract_version);
   callback.request_correlation_id="CORR-1"; callback.attempt_id="ATT-1"; callback.invocation_claim_id="CLAIM-1";
   callback.claim_record_digest="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
   callback.profile_digest="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
   callback.callback_sequence=1; callback.observed_at=context.clock_time; callback.transaction_type=1;
   callback.order_ticket=11; callback.deal_ticket=12; callback.position_identifier=13;
   callback.symbol="XAUUSD"; callback.order_type=0; callback.order_state=1; callback.deal_type=0;
   callback.price=3500.125; callback.volume=0.01; callback.request_action=1;
   callback.request_magic=SWV5_RUNTIME_STRATEGY_MAGIC; callback.request_comment="MVP,UTF8-OK";
   callback.result_retcode=10009; callback.request_id_session_local=44;
   callback.final_confirmation=false; callback.retry_allowed=false;
   SWV5S5_F_DeriveCallbackDigest(callback,callback.evidence_digest);
   string callback_payload; SWV5S5_F_AdapterCallbackEvidence decoded;
   SWV5S5_MvpRecord(c,"CALLBACK-ENCODE",SWV5S5_MvpCallbackPayload(callback,callback_payload));
   SWV5S5_MvpRecord(c,"CALLBACK-ROUNDTRIP",SWV5S5_MvpDecodeCallbackPayload(callback_payload,decoded) &&
      SWV5S5_MvpCallbackEqual(callback,decoded));
   string corrupt_payload=StringSubstr(callback_payload,0,StringLen(callback_payload)-1)+
      (StringSubstr(callback_payload,StringLen(callback_payload)-1)=="0" ? "1" : "0");
   SWV5S5_MvpRecord(c,"CALLBACK-CORRUPT-CLOSED",!SWV5S5_MvpDecodeCallbackPayload(corrupt_payload,decoded));
   SWV5S5_MvpRecord(c,"CALLBACK-EXACT-ORDER",SWV5S5_MvpCallbackMatchesSubmission(11,0,0,11,12,44));
   SWV5S5_MvpRecord(c,"CALLBACK-EXACT-REQUEST",SWV5S5_MvpCallbackMatchesSubmission(0,0,44,11,12,44));
   SWV5S5_MvpRecord(c,"CALLBACK-MAGIC-ONLY-DENIED",!SWV5S5_MvpCallbackMatchesSubmission(0,0,0,11,12,44));
   SWV5S5_MvpRecord(c,"CALLBACK-CONFLICT-DENIED",!SWV5S5_MvpCallbackMatchesSubmission(11,99,44,11,12,44));

   bool execution_rows[2]; execution_rows[0]=true; execution_rows[1]=false;
   uint materialized=0,row_failures=0; bool enumeration_complete=true;
   SWV5S5_MvpSummarizeExecutionRows(execution_rows,true,true,3,materialized,row_failures,enumeration_complete);
   SWV5S5_MvpRecord(c,"EXECUTION-MATERIALIZED-COUNT",materialized==1);
   SWV5S5_MvpRecord(c,"EXECUTION-ROW-FAILURE-COUNT",row_failures==2);
   SWV5S5_MvpRecord(c,"EXECUTION-INCOMPLETE-CLOSED",!enumeration_complete);

   const string ns="1111111111111111111111111111111111111111111111111111111111111111";
   SWV5S5_MvpSqliteAuthorityStore store;
   const bool opened=store.Open("mvp_runtime_store_80e9.sqlite",ns);
   SWV5S5_MvpRecord(c,"STORE-OPEN",opened);
   string body="authority-body",digest; SWV5S5_DomainDigest("MVP-TEST",body,digest);
   SWV5S5_MvpAuthorityRow committed,loaded; bool found=false;
   const bool inserted=opened && store.CompareAndSet("TEST","ROW",0,"","",0,1,1,digest,body,context.clock_time,committed);
   SWV5S5_MvpRecord(c,"STORE-CAS-INSERT",inserted);
   SWV5S5_MvpRecord(c,"STORE-STALE-CAS",inserted && !store.CompareAndSet("TEST","ROW",0,"","",0,1,1,digest,body,context.clock_time,loaded));
   SWV5S5_MvpRecord(c,"STORE-ROLLBACK",store.TestRollbackWrite("TEST","ROLLBACK",digest,body,context.clock_time));
   store.Close();
   SWV5S5_MvpSqliteAuthorityStore reopened;
   const bool reopen_ok=reopened.Open("mvp_runtime_store_80e9.sqlite",ns) &&
      reopened.ReadRow("TEST","ROW",loaded,found) && found && loaded.payload_digest==digest;
   SWV5S5_MvpRecord(c,"STORE-REOPEN",reopen_ok);
   reopened.Close();
   SWV5S5_MvpSqliteAuthorityStore wrong_namespace;
   SWV5S5_MvpRecord(c,"STORE-NAMESPACE-MISMATCH",!wrong_namespace.Open("mvp_runtime_store_80e9.sqlite",
      "2222222222222222222222222222222222222222222222222222222222222222"));
   SWV5S5_MvpSqliteAuthorityStore invalid_path;
   SWV5S5_MvpRecord(c,"STORE-COMMON-FILENAME-ONLY",!invalid_path.Open("../mvp_runtime_escape.sqlite",ns));

   SWV5S5_MvpSqliteAuthorityStore claim_seed;
   const bool claim_open=claim_seed.Open("mvp_runtime_claim_80e9.sqlite",ns);
   string claim_body="DURABLE|CLAIM_ID=CLAIM-RESTART",claim_digest;
   SWV5S5_DomainDigest("CLAIM-RESTART",claim_body,claim_digest);
   const bool claim_insert=claim_open && claim_seed.CompareAndSet(SWV5S5_MVP_DOMAIN_SUBMISSION,
      SWV5S5_MVP_SUBMISSION_KEY,0,"","",0,1,(int)SWV5S5_INVOCATION_CLAIMED_UNRESOLVED,
      claim_digest,claim_body,context.clock_time,committed);
   claim_seed.Close();
   SWV5S5_MvpInvocationClaimAuthority claim_authority; SWV5S5_MvpReloadedClaim reloaded;
   const bool reload_ok=claim_insert && claim_authority.Configure("mvp_runtime_claim_80e9.sqlite",ns) &&
      claim_authority.ReloadClaim(reloaded);
   SWV5S5_MvpRecord(c,"CLAIM-RELOAD",reload_ok && reloaded.found && reloaded.invocation_claim_id=="CLAIM-RESTART");
   SWV5S5_MvpRecord(c,"CLAIM-GRANT-NOT-RECONSTRUCTED",reload_ok && !reloaded.claim_granted_now);

   SWV5_PendingRequest incomplete_requests[2]; bool incomplete_rows[2];
   ZeroMemory(incomplete_requests); incomplete_rows[0]=true; incomplete_rows[1]=false;
   incomplete_requests[0].contract_version=context.expected_version;
   SWV5S5_MvpExecutionPendingQuery execution_query;
   const string execution_ns="5555555555555555555555555555555555555555555555555555555555555555";
   const bool execution_persisted=execution_query.Configure("mvp_runtime_execution_80e9.sqlite",execution_ns) &&
      execution_query.PublishObservationSource(incomplete_requests,incomplete_rows,true,true,3,7,2,4,
                                               context.clock_time);
   SWV5S5_MvpExecutionPendingQuery execution_restart; SWV5S5_MvpExecutionObservationStatus execution_status;
   const bool execution_reloaded=execution_persisted &&
      execution_restart.Configure("mvp_runtime_execution_80e9.sqlite",execution_ns) &&
      execution_restart.LoadPersistedObservationStatus(execution_status);
   SWV5S5_MvpRecord(c,"EXECUTION-INCOMPLETE-PERSISTED",execution_reloaded && execution_status.found &&
      execution_status.operation_success && !execution_status.enumeration_complete &&
      execution_status.reported_total==3 && execution_status.materialized_row_count==1 &&
      execution_status.row_read_failures==2);
   SWV5S5_F_ReconciliationBinding unused_binding; SWV5S5_F_ExecutionPendingSnapshot restart_snapshot;
   ZeroMemory(unused_binding);
   SWV5S5_MvpRecord(c,"EXECUTION-RESTART-NOT-EMPTY-AUTHORITY",execution_reloaded &&
      !execution_restart.ObservePendingRequest(unused_binding,restart_snapshot));

   SWV5S5_MvpManualGenesisProvisioner partial;
   const string ns_partial="3333333333333333333333333333333333333333333333333333333333333333";
   bool partial_ready=true;
   const bool partial_ok=partial.Configure("mvp_runtime_genesis_partial_80e9.sqlite",ns_partial) &&
      partial.Begin(op,context.clock_time) && partial.IsReadyForReconciliation(partial_ready);
   SWV5S5_MvpRecord(c,"GENESIS-PARTIAL-DISABLED",partial_ok && !partial_ready);
   SWV5S5_MvpManualGenesisProvisioner genesis;
   const string ns_genesis="4444444444444444444444444444444444444444444444444444444444444444";
   bool ready=false;
   const bool genesis_ok=genesis.Configure("mvp_runtime_genesis_full_80e9.sqlite",ns_genesis) &&
      genesis.Begin(op,context.clock_time) && genesis.InitializeAllDomains(context.clock_time) &&
      genesis.FinalizeReadyForReconciliation(context.clock_time) && genesis.IsReadyForReconciliation(ready);
   SWV5S5_MvpRecord(c,"GENESIS-READY-FOR-RECONCILIATION",genesis_ok && ready);
   SWV5S5_MvpSqliteAuthorityStore genesis_readback; SWV5S5_MvpAuthorityRow genesis_latch;
   bool genesis_latch_found=false;
   const bool genesis_latched=genesis_ok && genesis_readback.Open("mvp_runtime_genesis_full_80e9.sqlite",ns_genesis) &&
      genesis_readback.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",genesis_latch,genesis_latch_found) &&
      genesis_latch_found && genesis_latch.state==(int)SWV5_HARD_KILL_ACTIVE;
   SWV5S5_MvpRecord(c,"GENESIS-NOT-RUNTIME-ENABLED",genesis_latched);

   SWV5_HardKillState active_state; SWV5_TestMakeHardKill(active_state,SWV5_HARD_KILL_ACTIVE);
   active_state.contract_version=context.expected_version;
   active_state.persistence_namespace.contract_version=context.expected_version;
   active_state.account_namespace.contract_version=context.expected_version;
   active_state.release_evidence.contract_version=context.expected_version;
   active_state.persistence_namespace.ownership_namespace.broker_identity=active_state.account_namespace.broker_identity;
   active_state.persistence_namespace.ownership_namespace.server=active_state.account_namespace.server;
   active_state.persistence_namespace.ownership_namespace.account_login=active_state.account_namespace.account_login;
   active_state.persistence_namespace.ownership_namespace.strategy_id=active_state.account_namespace.strategy_id;
   active_state.persistence_namespace.ownership_namespace.magic=active_state.account_namespace.magic;
   SWV5_HardKillReleaseEvidence release=active_state.release_evidence;
   release.persistence_namespace=active_state.persistence_namespace; release.release_id="MVP-RELEASE-1";
   release.latch_id=active_state.latch_id; release.latch_generation=active_state.latch_generation;
   release.release_generation=active_state.release_generation+1; release.approval_policy_id="HARD-KILL-RELEASE-V5";
   release.approval_sequence=1; release.operator_identity.operator_id="OPERATOR-1";
   release.operator_identity.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
   release.operator_identity.authentication_reference="AUTH-EXPLICIT-1";
   release.operator_identity.authenticated_at=context.clock_time;
   release.approving_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
   release.broker_evidence.contract_version=context.expected_version;
   release.broker_evidence.persistence_namespace=active_state.persistence_namespace;
   release.broker_evidence.evidence_id="BROKER-ZERO-1";
   release.broker_evidence.issuing_component=SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER;
   release.broker_evidence.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
   release.broker_evidence.evidence_sequence=1; release.broker_evidence.observed_at=context.clock_time;
   release.broker_evidence.state_digest="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
   release.persistence_evidence.contract_version=context.expected_version;
   release.persistence_evidence.persistence_namespace=active_state.persistence_namespace;
   release.persistence_evidence.evidence_id="STORE-ZERO-1";
   release.persistence_evidence.issuing_component=SWV5_COMPONENT_AUTHORITY_PERSISTENCE;
   release.persistence_evidence.authority_source=SWV5_AUTHORITY_PERSISTED_CHECKPOINT;
   release.persistence_evidence.evidence_sequence=1; release.persistence_evidence.observed_at=context.clock_time;
   release.persistence_evidence.state_digest="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
   release.exposure_evidence.contract_version=context.expected_version;
   release.exposure_evidence.evidence_id="EXPOSURE-ZERO-1";
   release.exposure_evidence.issuing_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
   release.exposure_evidence.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
   release.exposure_evidence.observed_exposure_volume=0.0;
   release.exposure_evidence.prior_exposure_volume=0.01; release.exposure_evidence.zero_or_reducing=true;
   release.exposure_evidence.evidence_sequence=1; release.exposure_evidence.observed_at=context.clock_time;
   release.approved_at=context.clock_time; release.released_at=context.clock_time;
   release.expires_at=context.clock_time+60; release.release_record_sequence=1;
   release.audit_reference="MVP-RELEASE-AUDIT-1";
   SWV5S5_MvpHardKillReleaseDigest(release,release.release_record_digest);
   SWV5_HardKillReleaseAuthorityRecord authority; ZeroMemory(authority);
   authority.contract_version=context.expected_version; authority.persistence_namespace=active_state.persistence_namespace;
   authority.account_namespace=active_state.account_namespace; authority.latch_id=release.latch_id;
   authority.latch_generation=release.latch_generation; authority.release_id=release.release_id;
   authority.release_generation=release.release_generation; authority.operator_identity=release.operator_identity;
   authority.approving_component=release.approving_component; authority.approval_policy_id=release.approval_policy_id;
   authority.approval_sequence=release.approval_sequence; authority.broker_evidence_reference=release.broker_evidence;
   authority.persistence_evidence_reference=release.persistence_evidence;
   authority.exposure_evidence_reference=release.exposure_evidence; authority.approved_at=release.approved_at;
   authority.released_at=release.released_at; authority.expires_at=release.expires_at;
   authority.release_record_sequence=release.release_record_sequence; authority.authority_record_id="MVP-HK-AUTH-1";
   authority.issuing_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
   authority.authority_source=SWV5_AUTHORITY_HARD_KILL_RELEASE_RECORD;
   SWV5S5_MvpHardKillAuthorityRecordDigest(authority,authority.authority_record_digest);
   const string hard_kill_ns="6666666666666666666666666666666666666666666666666666666666666666";
   string active_payload,active_digest; SWV5S5_CanonicalHardKillState("hard_kill",active_state,active_payload);
   SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,active_payload,active_digest);
   SWV5_InstanceLease release_lease; SWV5_TestMakeLease(release_lease,SWV5_LOCK_ACQUIRED);
   release_lease.fence.ownership_namespace=active_state.persistence_namespace.ownership_namespace;
   release_lease.fence.owner.key=active_state.persistence_namespace.ownership_namespace;
   release_lease.clock_id=context.clock_id; release_lease.clock_authority=context.clock_authority;
   release_lease.acquired_clock_sequence=context.clock_sequence-2;
   release_lease.heartbeat_clock_sequence=context.clock_sequence-1;
   release_lease.expiry_clock_sequence=context.clock_sequence+60;
   release_lease.acquired_at=context.clock_time-2; release_lease.heartbeat_at=context.clock_time-1;
   release_lease.expires_at=context.clock_time+60;
   SWV5S5_LeaseLivenessAuthorityView release_lease_view; release_lease_view.lease=release_lease;
   string release_lease_payload;
   const bool release_lease_canonical=SWV5S5_CanonicalInstanceLease("lease",release_lease,release_lease_payload);
   const bool release_lease_shape=SWV5S5_IsV5Version(release_lease.contract_version) &&
      release_lease.status==SWV5_LOCK_ACQUIRED && release_lease.expires_at>release_lease.heartbeat_at;
   const bool release_lease_derived=SWV5S5_DeriveLeaseProjection(release_lease_view);
   const bool release_lease_valid=release_lease_shape && release_lease_canonical && release_lease_derived;
   SWV5S5_MvpRecord(c,"HARD-KILL-CURRENT-LEASE-VERSION",SWV5S5_IsV5Version(release_lease.contract_version));
   SWV5S5_MvpRecord(c,"HARD-KILL-CURRENT-LEASE-STATUS",release_lease.status==SWV5_LOCK_ACQUIRED);
   SWV5S5_MvpRecord(c,"HARD-KILL-CURRENT-LEASE-TIME",release_lease.expires_at>release_lease.heartbeat_at);
   SWV5S5_MvpRecord(c,"HARD-KILL-CURRENT-LEASE-SHAPE",release_lease_shape);
   SWV5S5_MvpRecord(c,"HARD-KILL-CURRENT-LEASE-CANONICAL",release_lease_canonical);
   SWV5S5_MvpRecord(c,"HARD-KILL-CURRENT-LEASE-DIGEST",release_lease_derived);
   SWV5S5_MvpRecord(c,"HARD-KILL-CURRENT-LEASE-FIXTURE",release_lease_valid);
   SWV5S5_F_ReconciliationResult zero_reconciliation; ZeroMemory(zero_reconciliation);
   zero_reconciliation.contract_version=context.expected_version;
   zero_reconciliation.state=SWV5S5_F_NO_SIDE_EFFECT_CONFIRMED;
   zero_reconciliation.disposition=SWV5S5_F_DISPOSITION_NEGATIVE_CONFIRMED;
   zero_reconciliation.proposed_submission_state=SWV5S5_AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED;
   zero_reconciliation.authoritative_positive=false; zero_reconciliation.authoritative_negative=true;
   zero_reconciliation.retry_allowed=false; zero_reconciliation.requires_new_admission_for_any_future_attempt=true;
   zero_reconciliation.cumulative_confirmed_volume=0.0; zero_reconciliation.residual_volume=0.0;
   zero_reconciliation.residual_is_submission_authority=false;
   zero_reconciliation.requires_new_request_identity_for_residual=true;
   zero_reconciliation.authoritative_evidence_digest="cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";
   zero_reconciliation.reason_code="MVP_ZERO_STATE_RECONCILED";
   SWV5S5_F_DeriveResultDigest(zero_reconciliation,zero_reconciliation.result_digest);
   SWV5S5_MvpSqliteAuthorityStore hard_kill_seed; SWV5S5_MvpAuthorityRow hard_kill_row;
   const bool hard_kill_seeded=hard_kill_seed.Open("mvp_runtime_hardkill_80e9.sqlite",hard_kill_ns) &&
      hard_kill_seed.CompareAndSet(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",0,"","",0,1,
         (int)SWV5_HARD_KILL_ACTIVE,active_digest,active_payload,context.clock_time,hard_kill_row) &&
      release_lease_valid && hard_kill_seed.CompareAndSet(SWV5S5_MVP_DOMAIN_OWNERSHIP,
         SWV5S5_MVP_OWNERSHIP_KEY,0,"","",0,1,(int)release_lease.status,
         release_lease_view.projection_digest,release_lease_payload,context.clock_time,hard_kill_row);
   SWV5S5_MvpRecord(c,"HARD-KILL-AUTHORITY-SEED",hard_kill_seeded);
   hard_kill_seed.Close();
   SWV5S5_MvpManualSafetyReleaseProvisioner release_provisioner; SWV5_HardKillState pending_state;
   SWV5S5_MvpAuthorityRow pending_row,released_row;
   const bool pending_ok=hard_kill_seeded && release_provisioner.Configure("mvp_runtime_hardkill_80e9.sqlite",hard_kill_ns) &&
      release_provisioner.StageReleasePending(op,context,active_state,release,pending_state,pending_row);
   SWV5S5_MvpRecord(c,"HARD-KILL-ACTIVE-TO-PENDING",pending_ok &&
      pending_row.state==(int)SWV5_HARD_KILL_RELEASE_PENDING);
   SWV5S5_MvpRiskContract runtime_risk;
   SWV5_InstanceLease stale_release_lease=release_lease;
   stale_release_lease.fence.takeover_generation++;
   stale_release_lease.fence.fencing_token_digest="FENCE-DIGEST-STALE";
   SWV5S5_MvpAuthorityRow stale_release_row;
   const bool stale_release_denied=pending_ok && !release_provisioner.PersistApprovedRelease(op,context,pending_state,
      release,authority,stale_release_lease,zero_reconciliation,runtime_risk,stale_release_row);
   SWV5S5_MvpRecord(c,"HARD-KILL-STALE-OWNER-DENIED",stale_release_denied);
   SWV5S5_MvpSqliteAuthorityStore stale_release_readback; SWV5S5_MvpAuthorityRow stale_release_artifact;
   bool stale_release_artifact_found=false;
   const bool stale_release_no_artifact=stale_release_denied &&
      stale_release_readback.Open("mvp_runtime_hardkill_80e9.sqlite",hard_kill_ns) &&
      stale_release_readback.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL_RELEASE,"CURRENT",
         stale_release_artifact,stale_release_artifact_found) && !stale_release_artifact_found;
   SWV5S5_MvpRecord(c,"HARD-KILL-STALE-OWNER-NO-ARTIFACT",stale_release_no_artifact);
   stale_release_readback.Close();
   const bool released_ok=pending_ok && release_provisioner.PersistApprovedRelease(op,context,pending_state,release,
      authority,release_lease,zero_reconciliation,runtime_risk,released_row);
   SWV5S5_MvpRecord(c,"HARD-KILL-PENDING-TO-RELEASED",released_ok &&
      released_row.state==(int)SWV5_HARD_KILL_RELEASED);
   SWV5S5_MvpSqliteAuthorityStore hard_kill_restart; SWV5S5_MvpAuthorityRow persisted_release;
   bool persisted_release_found=false;
   const bool release_restarted=released_ok && hard_kill_restart.Open("mvp_runtime_hardkill_80e9.sqlite",hard_kill_ns) &&
      hard_kill_restart.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",persisted_release,persisted_release_found);
   SWV5S5_MvpRecord(c,"HARD-KILL-RELEASE-RESTART",release_restarted && persisted_release_found &&
      persisted_release.state==(int)SWV5_HARD_KILL_RELEASED &&
      StringFind(persisted_release.payload,authority.authority_record_digest)>=0);

   SWV5S5_MvpRecoveryResult recovery; ZeroMemory(recovery);
   SWV5S5_MvpRecord(c,"RECOVERY-ZERO-SUBMISSION-CALLS",recovery.submission_calls==0);
   SWV5S5_MvpRecord(c,"RECOVERY-NO-CLAIM-GRANT",!recovery.claim_grant_reconstructed);
}

#endif // SW_V5_S5_MVP_RUNTIME_ASSERTIONS_MQH
