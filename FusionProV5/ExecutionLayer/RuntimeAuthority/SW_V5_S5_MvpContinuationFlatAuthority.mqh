#ifndef SW_V5_S5_MVP_CONTINUATION_FLAT_AUTHORITY_MQH
#define SW_V5_S5_MVP_CONTINUATION_FLAT_AUTHORITY_MQH
// ATTENDED CONTINUATION ONLY. Not BootstrapZero or Phase-F/D6 negative evidence.
#include "SW_V5_S5_MvpContinuationPhysicalCodec.mqh"
const string SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT="MVP_CONTINUATION_FLAT_STATE_AUTHORITY";
const string SWV5S5_MVP_CONTINUATION_FLAT_DIGEST="SWV5-S5-MVP-CONTINUATION-FLAT-V1";

struct SWV5S5_MvpContinuationFlatAuthority
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace scope;
   SWV5_AccountRiskNamespace account;
   SWV5_OwnershipFence fence;
   SWV5_HardKillState active;
   SWV5S5_MvpOperatorInvocation op;
   SWV5_TypedReconciliationEvidence broker,persistence;
   SWV5_ExposureReductionEvidence exposure;
   string clock_id,physical_snapshot_digest,key,authority_digest;
   string bound_rows_payload,broker_observation_payload;
   SWV5_TimeAuthority clock_authority;
   ulong clock_sequence;
   datetime observed_at; // accepted FINALIZATION time; typed observations retain their actual times
};

bool SWV5S5_MvpContinuationFlatPayload(const SWV5S5_MvpContinuationFlatAuthority &v,const bool with_digest,string &body)
{
   string n,f; body="";
#define CONT_FLAT_N(name,type,value) if(!SWV5S5_MvpCodecEncode_##type(value,n) || !SWV5S5_CanonicalNested(name,n,f)) return false; else body+=f
   CONT_FLAT_N("version",SWV5_ContractVersion,v.contract_version);
   CONT_FLAT_N("scope",SWV5_PersistenceNamespace,v.scope);
   CONT_FLAT_N("account",SWV5_AccountRiskNamespace,v.account);
   CONT_FLAT_N("fence",SWV5_OwnershipFence,v.fence);
   CONT_FLAT_N("active",SWV5_HardKillState,v.active);
   CONT_FLAT_N("broker",SWV5_TypedReconciliationEvidence,v.broker);
   CONT_FLAT_N("persistence",SWV5_TypedReconciliationEvidence,v.persistence);
   CONT_FLAT_N("exposure",SWV5_ExposureReductionEvidence,v.exposure);
#undef CONT_FLAT_N
   string unused;
   if(!SWV5S5_MvpOperatorPayload(v.op,n,unused) || !SWV5S5_CanonicalNested("operator",n,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("clock_id",v.clock_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("clock_authority",(int)v.clock_authority,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("clock_sequence",v.clock_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",v.observed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("physical_snapshot_digest",v.physical_snapshot_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNested("bound_rows",v.bound_rows_payload,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNested("broker_observation",v.broker_observation_payload,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("key",v.key,f)) return false; body+=f;
   if(with_digest){ if(!SWV5S5_CanonicalString("authority_digest",v.authority_digest,f)) return false; body+=f; }
   return true;
}
bool SWV5S5_MvpContinuationFlatDigest(const SWV5S5_MvpContinuationFlatAuthority &v,string &digest)
{ string body; return SWV5S5_MvpContinuationFlatPayload(v,false,body) && SWV5S5_DomainDigest(SWV5S5_MVP_CONTINUATION_FLAT_DIGEST,body,digest); }

bool SWV5S5_MvpDecodeContinuationFlat(const string body,SWV5S5_MvpContinuationFlatAuthority &v)
{
   ZeroMemory(v); SWV5S5_MvpCodecReader r; r.Init(body); string n; long x;
#define CONT_FLAT_READ(name,type,value) if(!r.ReadNested(name,n) || !SWV5S5_MvpCodecDecode_##type(n,value)) return false
   CONT_FLAT_READ("version",SWV5_ContractVersion,v.contract_version);
   CONT_FLAT_READ("scope",SWV5_PersistenceNamespace,v.scope);
   CONT_FLAT_READ("account",SWV5_AccountRiskNamespace,v.account);
   CONT_FLAT_READ("fence",SWV5_OwnershipFence,v.fence);
   CONT_FLAT_READ("active",SWV5_HardKillState,v.active);
   CONT_FLAT_READ("broker",SWV5_TypedReconciliationEvidence,v.broker);
   CONT_FLAT_READ("persistence",SWV5_TypedReconciliationEvidence,v.persistence);
   CONT_FLAT_READ("exposure",SWV5_ExposureReductionEvidence,v.exposure);
#undef CONT_FLAT_READ
   if(!r.ReadNested("operator",n)) return false;
   SWV5S5_MvpCodecReader op; op.Init(n);
   if(!op.ReadString("operator_id",v.op.operator_id) || !op.ReadString("authority_role",v.op.authority_role) ||
      !op.ReadString("authentication_reference",v.op.authentication_reference) || !op.ReadInteger("authenticated_at",x) || !op.AtEnd()) return false;
   v.op.authenticated_at=(datetime)x;
   if(!r.ReadString("clock_id",v.clock_id) || !r.ReadInteger("clock_authority",x) || x!=(int)SWV5_TIME_AUTHORITY_BROKER_SERVER) return false;
   v.clock_authority=(SWV5_TimeAuthority)x;
   if(!r.ReadUnsigned("clock_sequence",v.clock_sequence) || !r.ReadInteger("observed_at",x)) return false; v.observed_at=(datetime)x;
   string digest;
   return r.ReadString("physical_snapshot_digest",v.physical_snapshot_digest) &&
      r.ReadNested("bound_rows",v.bound_rows_payload) && r.ReadNested("broker_observation",v.broker_observation_payload) && r.ReadString("key",v.key) &&
      r.ReadString("authority_digest",v.authority_digest) && r.AtEnd() &&
      SWV5S5_MvpContinuationFlatDigest(v,digest) && digest==v.authority_digest;
}

bool SWV5S5_MvpContinuationBrokerZero(ISWV5S5MvpBootstrapBrokerObserver &broker,
                                    const SWV5_AccountRiskNamespace &account,const datetime at,
                                    SWV5S5_MvpBootstrapBrokerObservation &observed)
{
   string digest;
   const datetime capture_started=TimeCurrent(); // diagnostic lower bound, never a publication
   const bool captured=broker.Capture(SWV5S5_MVP_SYMBOL,observed);
   const bool accepted=captured && SWV5S5_MvpProfileMatches(observed.profile,ACCOUNT_TRADE_MODE_DEMO) &&
      observed.profile.broker_identity==account.broker_identity && observed.profile.server==account.server &&
      observed.profile.account_login==account.account_login && observed.observed_at>=at &&
      observed.observed_at>=capture_started && observed.observed_at<=TimeCurrent() &&
      observed.positions_query_succeeded && observed.active_orders_query_succeeded && observed.enumeration_complete &&
      observed.row_failures==0 && observed.total_positions==0 && observed.total_active_orders==0 &&
      MathIsValidNumber(observed.total_exposure_volume) && observed.total_exposure_volume==0.0 &&
      SWV5S5_MvpBootstrapBrokerDigest(observed,digest) && digest==observed.snapshot_digest;
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
   // TEST ONLY diagnostics of the SAME captured values/predicate. No recapture,
   // timestamp rewrite, synthetic zero-state or changed acceptance condition.
   string rejecting_field="NONE";
   if(!captured)rejecting_field="capture";
   else if(!SWV5S5_MvpProfileMatches(observed.profile,ACCOUNT_TRADE_MODE_DEMO))rejecting_field="profile";
   else if(observed.profile.broker_identity!=account.broker_identity)rejecting_field="broker_identity";
   else if(observed.profile.server!=account.server)rejecting_field="server";
   else if(observed.profile.account_login!=account.account_login)rejecting_field="account_login";
   else if(observed.observed_at<at || observed.observed_at<capture_started || observed.observed_at>TimeCurrent())rejecting_field="observed_at";
   else if(!observed.positions_query_succeeded)rejecting_field="positions_query_succeeded";
   else if(!observed.active_orders_query_succeeded)rejecting_field="active_orders_query_succeeded";
   else if(!observed.enumeration_complete)rejecting_field="enumeration_complete";
   else if(observed.row_failures!=0)rejecting_field="row_failures";
   else if(observed.total_positions!=0)rejecting_field="total_positions";
   else if(observed.total_active_orders!=0)rejecting_field="total_active_orders";
   else if(!MathIsValidNumber(observed.total_exposure_volume))rejecting_field="finite_exposure";
   else if(observed.total_exposure_volume!=0.0)rejecting_field="total_exposure_volume";
   else if(!accepted)rejecting_field="snapshot_digest";
   Print("CONTINUATION_BROKER_PRE_GATE_VALUES|accepted=",accepted,"|capture=",captured,
      "|positions=",observed.total_positions,"|positions_query=",observed.positions_query_succeeded,
      "|orders=",observed.total_active_orders,"|orders_query=",observed.active_orders_query_succeeded,
      "|exposure=",observed.total_exposure_volume,"|observed_at=",(long)observed.observed_at,"|expected_clock_time=",(long)at,
      "|complete=",observed.enumeration_complete,"|row_failures=",observed.row_failures,"|rejecting_field=",rejecting_field,
      "|pending_request_predicate=NOT_INCLUDED");
#endif
   return accepted;
}

// Different input type and domain; never coerces to BootstrapZero.
bool SWV5S5_MvpIssueContinuationRelease(const SWV5S5_MvpContinuationFlatAuthority &flat,
                                      SWV5_HardKillReleaseEvidence &e,SWV5_HardKillReleaseAuthorityRecord &a)
{
   ZeroMemory(e); ZeroMemory(a); string digest;
   SWV5S5_MvpBootstrapBrokerObservation observed; SWV5S5_MvpAuthorityRow bound[]; string account_a,account_b;
   if(!SWV5S5_MvpContinuationFlatDigest(flat,digest) || digest!=flat.authority_digest ||
      !SWV5S5_IsV5Version(flat.contract_version) || !SWV5S5_MvpContinuationDecodeRows(flat.bound_rows_payload,bound) ||
      !SWV5S5_DomainDigest(SWV5S5_MVP_CONTINUATION_FLAT_DIGEST+"-STORE",flat.bound_rows_payload,digest) || digest!=flat.physical_snapshot_digest ||
      !SWV5S5_MvpContinuationDecodeBroker(flat.broker_observation_payload,observed) ||
      !SWV5S5_MvpProfileMatches(observed.profile,ACCOUNT_TRADE_MODE_DEMO) ||
      observed.observed_at<flat.op.authenticated_at || observed.observed_at>flat.observed_at ||
      observed.profile.broker_identity!=flat.account.broker_identity || observed.profile.server!=flat.account.server ||
      observed.profile.account_login!=flat.account.account_login || !observed.positions_query_succeeded ||
      !observed.active_orders_query_succeeded || !observed.enumeration_complete || observed.row_failures!=0 ||
      observed.total_positions!=0 || observed.total_active_orders!=0 || observed.total_exposure_volume!=0.0 ||
      observed.snapshot_digest!=flat.broker.state_digest ||
      !SWV5S5_CanonicalAccountNamespace("account",flat.account,account_a) ||
      !SWV5S5_CanonicalAccountNamespace("account",flat.active.account_namespace,account_b) || account_a!=account_b ||
      flat.active.state!=SWV5_HARD_KILL_ACTIVE || flat.active.activation_reason!="CONTINUATION_REAUTHORIZATION" ||
      flat.active.release_generation==18446744073709551615 ||
      !SWV5S5_MvpOperatorInvocationValid(flat.op,flat.observed_at) ||
      flat.clock_sequence==0 || flat.clock_authority!=SWV5_TIME_AUTHORITY_BROKER_SERVER ||
      flat.key=="" || flat.observed_at<=0 || flat.active.latch_generation==0 || flat.active.release_generation==0 ||
      !SWV5S5_EqualNamespace(flat.scope,flat.active.persistence_namespace) ||
      !SWV5S5_EqualOwnershipKey(flat.fence.ownership_namespace,flat.scope.ownership_namespace) ||
      flat.broker.issuing_component!=SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER ||
      flat.broker.authority_source!=SWV5_AUTHORITY_LIVE_BROKER_STATE ||
      flat.persistence.issuing_component!=SWV5_COMPONENT_AUTHORITY_PERSISTENCE ||
      flat.persistence.authority_source!=SWV5_AUTHORITY_PERSISTED_CHECKPOINT ||
      !SWV5S5_EqualNamespace(flat.scope,flat.broker.persistence_namespace) ||
      !SWV5S5_EqualNamespace(flat.scope,flat.persistence.persistence_namespace) ||
      flat.broker.observed_at!=observed.observed_at || flat.exposure.observed_at!=observed.observed_at ||
      flat.persistence.observed_at<flat.op.authenticated_at || flat.persistence.observed_at>flat.observed_at ||
      flat.broker.evidence_sequence!=flat.clock_sequence || flat.persistence.evidence_sequence!=flat.clock_sequence || flat.exposure.evidence_sequence!=flat.clock_sequence ||
      flat.persistence.state_digest!=flat.physical_snapshot_digest ||
      flat.exposure.issuing_component!=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE ||
      flat.exposure.authority_source!=SWV5_AUTHORITY_LIVE_BROKER_STATE ||
      flat.exposure.observed_exposure_volume!=0.0 || flat.exposure.prior_exposure_volume!=0.0 || !flat.exposure.zero_or_reducing) return false;
   e.contract_version=flat.contract_version; e.persistence_namespace=flat.scope;
   e.release_id="MVP-CONTINUATION-RELEASE-"+flat.authority_digest;
   e.latch_id=flat.active.latch_id; e.latch_generation=flat.active.latch_generation;
   e.release_generation=flat.active.release_generation+1; e.approval_policy_id="HARD-KILL-RELEASE-V5";
   e.approval_sequence=flat.clock_sequence; e.release_record_sequence=flat.clock_sequence;
   e.operator_identity.operator_id=flat.op.operator_id; e.operator_identity.authority_role=flat.op.authority_role;
   e.operator_identity.authentication_reference=flat.op.authentication_reference;
   e.operator_identity.authenticated_at=flat.op.authenticated_at;
   e.approving_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
   e.broker_evidence=flat.broker; e.persistence_evidence=flat.persistence; e.exposure_evidence=flat.exposure;
   e.approved_at=flat.observed_at; e.released_at=flat.observed_at;
   e.expires_at=flat.observed_at+(datetime)SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS;
   e.audit_reference=SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT+"/"+flat.key+"/"+flat.authority_digest;
   if(!SWV5S5_MvpHardKillReleaseDigest(e,e.release_record_digest)) return false;
   a.contract_version=flat.contract_version; a.persistence_namespace=flat.scope; a.account_namespace=flat.account;
   a.latch_id=e.latch_id; a.latch_generation=e.latch_generation; a.release_id=e.release_id; a.release_generation=e.release_generation;
   a.operator_identity=e.operator_identity; a.approving_component=e.approving_component; a.approval_policy_id=e.approval_policy_id;
   a.approval_sequence=e.approval_sequence; a.broker_evidence_reference=e.broker_evidence;
   a.persistence_evidence_reference=e.persistence_evidence; a.exposure_evidence_reference=e.exposure_evidence;
   a.approved_at=e.approved_at; a.released_at=e.released_at; a.expires_at=e.expires_at; a.release_record_sequence=e.release_record_sequence;
   a.authority_record_id="MVP-CONTINUATION-RISK-AUTH-"+flat.authority_digest;
   a.issuing_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE; a.authority_source=SWV5_AUTHORITY_HARD_KILL_RELEASE_RECORD;
   return SWV5S5_MvpHardKillAuthorityRecordDigest(a,a.authority_record_digest);
}
// Physical validators are shared by the producer AND release boundaries.
bool SWV5S5_MvpContinuationInventoryAllowedDiagnostic(SWV5S5_MvpSqliteAuthorityStore &store,SWV5S5_MvpAuthorityRow &rows[],string &reason)
{
   reason="";
   if(!SWV5S5_MvpContinuationGenesisValid(store)){reason="PRESTATE_GENESIS_INVALID";return false;}
   if(!store.ReadAllRows(rows)){reason="PRESTATE_INVENTORY_READ_FAILED";return false;}
   for(int i=0;i<ArraySize(rows);i++)
   {
      const SWV5S5_MvpAuthorityRow row=rows[i];
      if(!SWV5S5_MvpContinuationRowValid(store,row)){reason="PRESTATE_ROW_PHYSICAL_INVALID/"+row.domain_key;return false;}
      if(row.record_key=="GENESIS")
      {
         bool known=row.domain_key==SWV5S5_MVP_DOMAIN_GENESIS;
         for(int d=0;d<SWV5S5_MvpGenesisDomainCount();d++)if(row.domain_key==SWV5S5_MvpGenesisDomain(d))known=true;
         if(!known){reason="PRESTATE_OPERATIONAL_ROW_PRESENT/"+row.domain_key;return false;}continue;
      }
      if(row.domain_key==SWV5S5_MVP_DOMAIN_OWNERSHIP && (row.record_key==SWV5S5_MVP_OWNERSHIP_KEY || row.record_key==SWV5S5_MVP_OWNERSHIP_CLOCK_KEY))continue;
      if(row.record_key=="CURRENT" && (row.domain_key==SWV5S5_MVP_DOMAIN_ACCOUNT_RISK || row.domain_key==SWV5S5_MVP_DOMAIN_PRODUCER_TRUST ||
         row.domain_key==SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE || row.domain_key==SWV5S5_MVP_DOMAIN_HARD_KILL ||
         row.domain_key==SWV5S5_MVP_DOMAIN_BOOTSTRAP_ZERO || row.domain_key==SWV5S5_MVP_DOMAIN_BASKET || row.domain_key==SWV5S5_MVP_DOMAIN_HARD_KILL_RELEASE))continue;
      if(row.domain_key==SWV5S5_MVP_DOMAIN_REQUEST_SET && row.record_key==SWV5S5_MVP_REQUEST_SET_KEY)continue;
      if(row.domain_key==SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE || row.domain_key==SWV5S5_MVP_DOMAIN_RELEASE_HISTORY ||
         row.domain_key=="MVP_ATTENDED_CONTINUATION_ACTIVATION" || row.domain_key==SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT)continue;
      reason="PRESTATE_OPERATIONAL_ROW_PRESENT/"+row.domain_key;return false; // Closed allowlist unchanged.
   }
   return true;
}
bool SWV5S5_MvpContinuationInventoryAllowed(SWV5S5_MvpSqliteAuthorityStore &store,SWV5S5_MvpAuthorityRow &rows[])
{
   string reason;return SWV5S5_MvpContinuationInventoryAllowedDiagnostic(store,rows,reason);
}

bool SWV5S5_MvpContinuationPhysicalInvariants(SWV5S5_MvpSqliteAuthorityStore &store,
   const SWV5_ContractValidationContext &context,const SWV5S5_MvpContinuationFlatAuthority &flat)
{
   SWV5S5_MvpAuthorityRow row,rows[];bool found=false;string ns,a,b,op,auth;
   if(!SWV5S5_MvpOwnershipNamespaceDigest(flat.scope.ownership_namespace,ns) || ns!=store.NamespaceDigest() ||
      !SWV5S5_MvpContinuationInventoryAllowed(store,rows))return false;
   SWV5_InstanceLease lease;SWV5S5_MvpLeasePublicationAuthority ownership;
   if(!ownership.LoadCurrentLease(store,flat.fence.ownership_namespace,flat.fence,lease,row) ||
      lease.status!=SWV5_LOCK_RENEWED || !SWV5S5_MvpLeaseCurrentForClock(context,flat.fence,lease))return false;
   SWV5S5_MvpAccountRiskAuthorityRecord account;
   if(!store.ReadRow(SWV5S5_MVP_DOMAIN_ACCOUNT_RISK,"CURRENT",row,found) || !found ||
      !SWV5S5_MvpAccountRiskValidateRow(store,row,account) || !SWV5S5_EqualNamespace(account.persistence_namespace,flat.scope) ||
      !SWV5S5_CanonicalAccountNamespace("account",account.account_namespace,a) || !SWV5S5_CanonicalAccountNamespace("account",flat.account,b) || a!=b)return false;
   SWV5S5_ProducerTrustRecord trust;SWV5S5_ProducerTrustAnchor anchor;
   if(!store.ReadRow(SWV5S5_MVP_DOMAIN_PRODUCER_TRUST,"CURRENT",row,found) || !found || row.state!=1 ||
      !SWV5S5_MvpDecodeProducerTrustPhysical(row.payload,trust,anchor,op,auth) || !SWV5S5_IsCandidateVersion(trust.contract_version) ||
      trust.authority_generation!=1 || anchor.current_authority_generation!=1 || anchor.trust_anchor_id=="" ||
      trust.authority_record_id!=anchor.current_authority_record_id || trust.issuer_identity!=anchor.issuer_identity ||
      trust.issuer_policy_id!=anchor.issuer_policy_id || trust.status!=SWV5S5_TRUST_AUTHORIZED ||
      trust.superseding_record_id!="" || trust.superseding_generation!=0 ||
      trust.producer_component!="DECISION" || trust.producer_instance!=SWV5S5_MVP_PRODUCER_INSTANCE || trust.producer_epoch!=1 ||
      trust.symbol!=SWV5S5_MVP_SYMBOL || trust.timeframe!=(int)PERIOD_M15 || trust.execution_mode!=1 ||
      !SWV5S5_EqualNamespace(trust.persistence_namespace,flat.scope) || trust.clock_id!=context.clock_id || trust.clock_authority!=context.clock_authority ||
      trust.valid_from<=0 || trust.valid_from>context.clock_time || context.clock_time>=trust.valid_until ||
      trust.valid_until>trust.valid_from+(datetime)SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS)return false;
   SWV5S5_MvpReconciliationGovernanceBundle governance;
   if(!store.ReadRow(SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE,"CURRENT",row,found) || !found || row.state!=1 ||
      !SWV5S5_MvpDecodeGovernance(row.payload,governance) || !SWV5S5_MvpGovernanceValid(governance,context.clock_time) ||
      !SWV5S5_EqualNamespace(governance.profile.persistence_namespace,flat.scope) ||
      !SWV5S5_CanonicalAccountNamespace("account",governance.profile.account_namespace,a) || a!=b ||
      !governance.capability_proof.correlation_capability_proven || governance.capability_proof.query_completeness_capability_proven ||
      governance.capability_proof.visibility_watermark_proven || governance.capability_proof.proven_visibility_lag_seconds!=0)return false;
   SWV5S5_MvpRequestSetPhysicalState requests;
   if(!store.ReadRow(SWV5S5_MVP_DOMAIN_REQUEST_SET,SWV5S5_MVP_REQUEST_SET_KEY,row,found) || !found ||
      !SWV5S5_MvpDecodeRequestSetState(row.payload,requests) || !SWV5S5_EqualNamespace(requests.view.persistence_namespace,flat.scope) ||
      !SWV5S5_EqualFence(requests.view.ownership_fence,flat.fence) || ArraySize(requests.view.requests)!=0 || requests.view.header.request_count!=0)return false;
   string projection=requests.view.projection_digest;
   if(!SWV5S5_DeriveRequestSetProjection(requests.view) || projection!=requests.view.projection_digest)return false;
   SWV5_BasketAggregate basket;SWV5_BasketInvariantReport report;SWV5S5_MvpBasketStateMachine machine;SWV5S5_MvpBasketLifecycleAuthority baskets;
   return baskets.LoadCurrentBasket(store,basket,row,found) && found && row.logical_revision==1 &&
      SWV5S5_EqualNamespace(basket.persistence_namespace,flat.scope) && SWV5S5_EqualFence(basket.lifecycle.ownership_fence,flat.fence) &&
      basket.lifecycle.state==SWV5_BASKET_IDLE && basket.lifecycle.state_version==1 && basket.lifecycle.aggregate_open_volume==0.0 &&
      basket.lifecycle.residual_volume==0.0 && basket.initial_volume==0.0 && basket.aggregate_closed_volume==0.0 &&
      basket.close_verification==SWV5_CLOSE_ZERO_RESIDUAL_CONFIRMED && machine.ValidateState(context,basket.lifecycle,report);
}

// The sole allowed divergence is the expected Hard Kill lifecycle CAS, plus
// a monotonic accepted clock publication on validated resume (Fusion decision).
bool SWV5S5_MvpContinuationBoundRowsCurrent(SWV5S5_MvpSqliteAuthorityStore &store,
   const SWV5_ContractValidationContext &context,const SWV5S5_MvpContinuationFlatAuthority &flat,
   const bool validated_resume,SWV5S5_MvpAuthorityRow &actual[])
{
   SWV5S5_MvpAuthorityRow bound[];SWV5_HardKillReleaseEvidence e;SWV5_HardKillReleaseAuthorityRecord authority;
   if(!SWV5S5_MvpIssueContinuationRelease(flat,e,authority) || !SWV5S5_MvpContinuationDecodeRows(flat.bound_rows_payload,bound) ||
      !SWV5S5_MvpContinuationPhysicalInvariants(store,context,flat) || !store.ReadAllRows(actual))return false;
   int extra=0;bool clock_seen=false,latch_seen=false;
   for(int i=0;i<ArraySize(actual);i++)
   {
      int j=-1;for(int x=0;x<ArraySize(bound);x++)if(bound[x].domain_key==actual[i].domain_key && bound[x].record_key==actual[i].record_key)j=x;
      if(j<0)
      {
         if(actual[i].domain_key==SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT && actual[i].record_key==flat.key)
         {string payload;if(!SWV5S5_MvpContinuationFlatPayload(flat,true,payload) || actual[i].payload!=payload || actual[i].logical_revision!=1 || actual[i].state!=1)return false;extra++;continue;}
         if(actual[i].domain_key==SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE && actual[i].record_key==authority.authority_record_id && validated_resume)
         {SWV5_HardKillState released;SWV5_HardKillReleaseAuthorityRecord a; if(!SWV5S5_MvpDecodeReleaseBundle(actual[i].payload,released,a) || a.authority_record_digest!=authority.authority_record_digest)return false;extra++;continue;}
         return false;
      }
      if(actual[i].domain_key==SWV5S5_MVP_DOMAIN_OWNERSHIP && actual[i].record_key==SWV5S5_MVP_OWNERSHIP_CLOCK_KEY)
      {
         SWV5S5_MvpLeaseClockObservation old,now;clock_seen=true;
         if(!SWV5S5_MvpDecodeLeaseClockPayload(bound[j].payload,old) || !SWV5S5_MvpLeaseClockObservationValid(old) ||
            old.clock_id!=flat.clock_id || old.clock_sequence>flat.clock_sequence || old.observed_at!=flat.op.authenticated_at ||
            !SWV5S5_MvpDecodeLeaseClockPayload(actual[i].payload,now) || !SWV5S5_MvpLeaseClockObservationValid(now) ||
            now.clock_id!=old.clock_id || now.clock_authority!=old.clock_authority || now.broker_identity!=old.broker_identity ||
            now.server!=old.server || now.account_login!=old.account_login || now.source_symbol!=old.source_symbol ||
            now.clock_id!=context.clock_id || now.clock_authority!=context.clock_authority ||
            now.clock_sequence!=context.clock_sequence || now.observed_at!=context.clock_time || actual[i].logical_revision!=now.clock_sequence ||
            now.clock_sequence<flat.clock_sequence || now.observed_at<flat.observed_at)return false;
         if(!SWV5S5_MvpContinuationRowExact(bound[j],actual[i]) &&
            ((!validated_resume && now.clock_sequence!=flat.clock_sequence) || now.clock_sequence<=old.clock_sequence ||
            now.observed_at<old.observed_at || now.platform_observation_id==old.platform_observation_id ||
            actual[i].logical_revision-bound[j].logical_revision!=now.clock_sequence-old.clock_sequence))return false;
         continue;
      }
      if(actual[i].domain_key==SWV5S5_MVP_DOMAIN_HARD_KILL && actual[i].record_key=="CURRENT")
      {
         latch_seen=true;string initial,payload,digest;SWV5_HardKillState expected=flat.active;
         if(!SWV5S5_MvpCodecEncode_SWV5_HardKillState(flat.active,initial) || bound[j].payload!=initial ||
            bound[j].state!=(int)SWV5_HARD_KILL_ACTIVE)return false;
         if(actual[i].state==(int)SWV5_HARD_KILL_ACTIVE){if(!SWV5S5_MvpContinuationRowExact(bound[j],actual[i]))return false;continue;}
         expected.state=SWV5_HARD_KILL_RELEASE_PENDING;expected.release_evidence=e;ulong steps=1;
         if(actual[i].state==(int)SWV5_HARD_KILL_RELEASED && validated_resume)
         {
            expected.state=SWV5_HARD_KILL_RELEASED;expected.release_generation=e.release_generation;steps=2;
            expected.release_authority_reference.contract_version=authority.contract_version;
            expected.release_authority_reference.authority_record_id=authority.authority_record_id;
            expected.release_authority_reference.authority_record_sequence=authority.release_record_sequence;
            expected.release_authority_reference.authority_record_digest=authority.authority_record_digest;
            expected.release_authority_reference.release_id=authority.release_id;
            expected.release_authority_reference.latch_generation=authority.latch_generation;
            expected.release_authority_reference.release_generation=authority.release_generation;
         }
         else if(actual[i].state!=(int)SWV5_HARD_KILL_RELEASE_PENDING)return false;
         if(actual[i].logical_revision!=bound[j].logical_revision+steps || actual[i].updated_at<flat.observed_at || actual[i].updated_at>context.clock_time ||
            !SWV5S5_CanonicalHardKillState("hard_kill",expected,payload) || actual[i].payload!=payload ||
            !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,payload,digest) || actual[i].payload_digest!=digest)return false;
         continue;
      }
      if(!SWV5S5_MvpContinuationRowExact(bound[j],actual[i]))return false;
   }
   return clock_seen && latch_seen && extra>=1 && ArraySize(actual)==ArraySize(bound)+extra;
}
#endif
