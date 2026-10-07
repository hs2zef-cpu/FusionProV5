#ifndef SW_V5_S5_MVP_BOOTSTRAP_SAFETY_AUTHORITIES_MQH
#define SW_V5_S5_MVP_BOOTSTRAP_SAFETY_AUTHORITIES_MQH

// MVP RUNTIME AUTHORITY — PRE-D1 BOOTSTRAP SAFETY ONLY.
// REAL READ-ONLY OBSERVATION / NO PHASE-F REQUEST / NO BROKER MUTATION.

#include "SW_V5_S5_MvpAuthorityRecordCodec.mqh"
#include "SW_V5_S5_MvpReadOnlyPlatform.mqh"
#include "SW_V5_S5_MvpAccountRiskRecordCodec.mqh"

const string SWV5S5_MVP_DOMAIN_BOOTSTRAP_ZERO="MVP_BOOTSTRAP_ZERO_STATE_AUTHORITY";
const string SWV5S5_MVP_BOOTSTRAP_ZERO_KEY="CURRENT";
const string SWV5S5_MVP_BOOTSTRAP_ZERO_DIGEST_DOMAIN="SWV5-S5-MVP-BOOTSTRAP-ZERO-V1";
const string SWV5S5_MVP_BOOTSTRAP_BROKER_DIGEST_DOMAIN="SWV5-S5-MVP-BOOTSTRAP-BROKER-ZERO-V1";
const string SWV5S5_MVP_BOOTSTRAP_PERSISTENCE_DIGEST_DOMAIN="SWV5-S5-MVP-BOOTSTRAP-PERSISTENCE-ZERO-V1";

struct SWV5S5_MvpBootstrapBrokerObservation
{
   SWV5S5_MvpRuntimeProfileObservation profile;
   datetime observed_at;
   bool positions_query_succeeded;
   bool active_orders_query_succeeded;
   bool enumeration_complete;
   uint row_failures;
   uint total_positions;
   uint total_active_orders;
   double total_exposure_volume;
   string snapshot_digest;
};

class ISWV5S5MvpBootstrapBrokerObserver
{
public:
   virtual bool Capture(const string symbol,SWV5S5_MvpBootstrapBrokerObservation &observation)=0;
};

bool SWV5S5_MvpBootstrapBrokerDigest(const SWV5S5_MvpBootstrapBrokerObservation &o,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalString("broker",o.profile.broker_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("server",o.profile.server,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("account_login",o.profile.account_login,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("currency",o.profile.account_currency,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("symbol",o.profile.symbol,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("trade_mode",o.profile.account_trade_mode,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("account_mode",o.profile.account_mode,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("connected",o.profile.connected,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("positions_query",o.positions_query_succeeded,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("orders_query",o.active_orders_query_succeeded,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("complete",o.enumeration_complete,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("row_failures",o.row_failures,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("positions",o.total_positions,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("orders",o.total_active_orders,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("exposure",o.total_exposure_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",o.observed_at,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_MVP_BOOTSTRAP_BROKER_DIGEST_DOMAIN,body,digest);
}

class SWV5S5_MvpMt5BootstrapBrokerObserver : public ISWV5S5MvpBootstrapBrokerObserver
{
public:
   virtual bool Capture(const string symbol,SWV5S5_MvpBootstrapBrokerObservation &o)
   {
      ZeroMemory(o); SWV5S5_MvpMt5ReadOnlyPlatform platform;
      if(!platform.CaptureProfile(symbol,o.profile,o.observed_at) ||
         !SWV5S5_MvpProfileMatches(o.profile,ACCOUNT_TRADE_MODE_DEMO)) return false;
      ResetLastError(); const int position_total=PositionsTotal();
      o.positions_query_succeeded=(position_total>=0 && GetLastError()==0);
      if(!o.positions_query_succeeded) return false;
      o.total_positions=(uint)position_total; o.total_exposure_volume=0.0;
      for(int i=0;i<position_total;i++)
      {
         ResetLastError(); const ulong ticket=PositionGetTicket(i);
         if(ticket==0 || GetLastError()!=0){ o.row_failures++; continue; }
         const double volume=PositionGetDouble(POSITION_VOLUME);
         if(!MathIsValidNumber(volume) || volume<0.0 || GetLastError()!=0)
         { o.row_failures++; continue; }
         o.total_exposure_volume+=volume;
      }
      ResetLastError(); const int order_total=OrdersTotal();
      o.active_orders_query_succeeded=(order_total>=0 && GetLastError()==0);
      if(!o.active_orders_query_succeeded) return false;
      o.total_active_orders=(uint)order_total;
      for(int i=0;i<order_total;i++)
      {
         ResetLastError(); const ulong ticket=OrderGetTicket(i);
         if(ticket==0 || GetLastError()!=0) o.row_failures++;
      }
      o.enumeration_complete=o.row_failures==0 && o.total_positions==0 &&
         o.total_active_orders==0 && o.total_exposure_volume==0.0;
      return SWV5S5_MvpBootstrapBrokerDigest(o,o.snapshot_digest);
   }
};

struct SWV5S5_MvpBootstrapZeroStateAuthority
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_AccountRiskNamespace account_namespace;
   SWV5_OwnershipFence ownership_fence;
   string hard_kill_latch_id;
   ulong hard_kill_latch_generation;
   SWV5_TypedReconciliationEvidence broker_evidence;
   SWV5_TypedReconciliationEvidence persistence_evidence;
   SWV5_ExposureReductionEvidence exposure_evidence;
   datetime observed_at;
   ulong authority_sequence;
   string authority_id;
   string authority_digest;
};

bool SWV5S5_MvpBootstrapZeroCanonical(const SWV5S5_MvpBootstrapZeroStateAuthority &a,
                                      const bool include_digest,string &body)
{
   body=""; string f,nested;
   if(!SWV5S5_MvpCodecEncode_SWV5_ContractVersion(a.contract_version,nested) ||
      !SWV5S5_CanonicalNested("contract_version",nested,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_PersistenceNamespace(a.persistence_namespace,nested) ||
      !SWV5S5_CanonicalNested("persistence_namespace",nested,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_AccountRiskNamespace(a.account_namespace,nested) ||
      !SWV5S5_CanonicalNested("account_namespace",nested,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_OwnershipFence(a.ownership_fence,nested) ||
      !SWV5S5_CanonicalNested("ownership_fence",nested,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("latch_id",a.hard_kill_latch_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("latch_generation",a.hard_kill_latch_generation,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_TypedReconciliationEvidence(a.broker_evidence,nested) ||
      !SWV5S5_CanonicalNested("broker_evidence",nested,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_TypedReconciliationEvidence(a.persistence_evidence,nested) ||
      !SWV5S5_CanonicalNested("persistence_evidence",nested,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_ExposureReductionEvidence(a.exposure_evidence,nested) ||
      !SWV5S5_CanonicalNested("exposure_evidence",nested,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",a.observed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("authority_sequence",a.authority_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("authority_id",a.authority_id,f)) return false; body+=f;
   if(include_digest)
   { if(!SWV5S5_CanonicalString("authority_digest",a.authority_digest,f)) return false; body+=f; }
   return true;
}

bool SWV5S5_MvpBootstrapZeroDigest(const SWV5S5_MvpBootstrapZeroStateAuthority &a,string &digest)
{
   string body; return SWV5S5_MvpBootstrapZeroCanonical(a,false,body) &&
      SWV5S5_DomainDigest(SWV5S5_MVP_BOOTSTRAP_ZERO_DIGEST_DOMAIN,body,digest);
}

bool SWV5S5_MvpDecodeBootstrapZero(const string payload,SWV5S5_MvpBootstrapZeroStateAuthority &a)
{
   ZeroMemory(a); SWV5S5_MvpCodecReader r; r.Init(payload); string nested;
   if(!r.ReadNested("contract_version",nested) || !SWV5S5_MvpCodecDecode_SWV5_ContractVersion(nested,a.contract_version)) return false;
   if(!r.ReadNested("persistence_namespace",nested) || !SWV5S5_MvpCodecDecode_SWV5_PersistenceNamespace(nested,a.persistence_namespace)) return false;
   if(!r.ReadNested("account_namespace",nested) || !SWV5S5_MvpCodecDecode_SWV5_AccountRiskNamespace(nested,a.account_namespace)) return false;
   if(!r.ReadNested("ownership_fence",nested) || !SWV5S5_MvpCodecDecode_SWV5_OwnershipFence(nested,a.ownership_fence)) return false;
   if(!r.ReadString("latch_id",a.hard_kill_latch_id) || !r.ReadUnsigned("latch_generation",a.hard_kill_latch_generation)) return false;
   if(!r.ReadNested("broker_evidence",nested) || !SWV5S5_MvpCodecDecode_SWV5_TypedReconciliationEvidence(nested,a.broker_evidence)) return false;
   if(!r.ReadNested("persistence_evidence",nested) || !SWV5S5_MvpCodecDecode_SWV5_TypedReconciliationEvidence(nested,a.persistence_evidence)) return false;
   if(!r.ReadNested("exposure_evidence",nested) || !SWV5S5_MvpCodecDecode_SWV5_ExposureReductionEvidence(nested,a.exposure_evidence)) return false;
   long observed=0; if(!r.ReadInteger("observed_at",observed)) return false; a.observed_at=(datetime)observed;
   if(!r.ReadUnsigned("authority_sequence",a.authority_sequence) || !r.ReadString("authority_id",a.authority_id) ||
      !r.ReadString("authority_digest",a.authority_digest) || !r.AtEnd()) return false;
   string digest; return SWV5S5_MvpBootstrapZeroDigest(a,digest) && digest==a.authority_digest;
}

bool SWV5S5_MvpInfrastructureRowAllowed(const SWV5S5_MvpAuthorityRow &row)
{
   if(row.record_key=="GENESIS") return true;
   return (row.domain_key=="MVP_OPERATOR_PROVISIONING_REFERENCE" ||
           row.domain_key=="MVP_PRODUCER_TRUST" ||
           row.domain_key==SWV5S5_MVP_DOMAIN_OWNERSHIP ||
           row.domain_key=="MVP_HARD_KILL_STATE" ||
           row.domain_key==SWV5S5_MVP_DOMAIN_BOOTSTRAP_ZERO);
}

class SWV5S5_MvpBootstrapPersistenceZeroProducer
{
public:
   bool Observe(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_PersistenceNamespace &scope,
                const datetime observed_at,const ulong sequence,
                SWV5_TypedReconciliationEvidence &evidence,string &snapshot_digest)
   {
      ZeroMemory(evidence); snapshot_digest=""; SWV5S5_MvpAuthorityRow rows[];
      if(observed_at<=0 || sequence==0 || !store.ReadAllRows(rows)) return false;
      string body="",f,row_body;
      for(int i=0;i<ArraySize(rows);i++)
      {
         if(rows[i].domain_key==SWV5S5_MVP_DOMAIN_ACCOUNT_RISK)
         {
            // The account namespace record is setup infrastructure, not exposure
            // or an operational request. Recognize only its complete valid row,
            // not a blanket domain exemption. Frozen release semantics unchanged.
            SWV5S5_MvpAccountRiskAuthorityRecord account;
            if(!SWV5S5_MvpAccountRiskValidateRow(store,rows[i],account) ||
               !SWV5S5_EqualNamespace(scope,account.persistence_namespace)) return false;
         }
         else if(!SWV5S5_MvpInfrastructureRowAllowed(rows[i])) return false;
         row_body="";
         if(!SWV5S5_CanonicalString("domain",rows[i].domain_key,f)) return false; row_body+=f;
         if(!SWV5S5_CanonicalString("key",rows[i].record_key,f)) return false; row_body+=f;
         if(!SWV5S5_CanonicalUInt("revision",rows[i].logical_revision,f)) return false; row_body+=f;
         if(!SWV5S5_CanonicalString("store_revision",rows[i].store_revision,f)) return false; row_body+=f;
         if(!SWV5S5_CanonicalInt("state",rows[i].state,f)) return false; row_body+=f;
         if(!SWV5S5_CanonicalString("payload_digest",rows[i].payload_digest,f)) return false; row_body+=f;
         if(!SWV5S5_CanonicalIndexed("row",(ulong)i,row_body,f)) return false; body+=f;
      }
      if(!SWV5S5_DomainDigest(SWV5S5_MVP_BOOTSTRAP_PERSISTENCE_DIGEST_DOMAIN,body,snapshot_digest)) return false;
      SWV5S5_MvpInitProductionVersion(evidence.contract_version); evidence.persistence_namespace=scope;
      evidence.evidence_id="PERSISTENCE-ZERO-"+snapshot_digest;
      evidence.issuing_component=SWV5_COMPONENT_AUTHORITY_PERSISTENCE;
      evidence.authority_source=SWV5_AUTHORITY_PERSISTED_CHECKPOINT;
      evidence.evidence_sequence=sequence; evidence.observed_at=observed_at;
      evidence.state_digest=snapshot_digest; return true;
   }
};

class SWV5S5_MvpBootstrapZeroAuthorityStore
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
public:
   bool Configure(const string path,const string namespace_digest)
   { return m_store.Open(path,namespace_digest); }

   bool Persist(const SWV5S5_MvpBootstrapZeroStateAuthority &authority,
                const SWV5S5_MvpAuthorityRow &ownership_guard,SWV5S5_MvpAuthorityRow &committed)
   {
      string digest,payload;
      if(!SWV5S5_MvpBootstrapZeroDigest(authority,digest) || digest!=authority.authority_digest ||
         !SWV5S5_MvpBootstrapZeroCanonical(authority,true,payload)) return false;
      SWV5S5_MvpAuthorityRow current; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_BOOTSTRAP_ZERO,SWV5S5_MVP_BOOTSTRAP_ZERO_KEY,current,found) || found)
         return false;
      return m_store.CompareAndSetWithGuard(SWV5S5_MVP_DOMAIN_BOOTSTRAP_ZERO,SWV5S5_MVP_BOOTSTRAP_ZERO_KEY,
         0,"","",0,1,1,digest,payload,authority.observed_at,
         ownership_guard.domain_key,ownership_guard.record_key,ownership_guard.logical_revision,
         ownership_guard.store_revision,ownership_guard.payload_digest,ownership_guard.state,committed);
   }

   bool Load(SWV5S5_MvpBootstrapZeroStateAuthority &authority,SWV5S5_MvpAuthorityRow &row,bool &found)
   {
      ZeroMemory(authority); found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_BOOTSTRAP_ZERO,SWV5S5_MVP_BOOTSTRAP_ZERO_KEY,row,found) || !found)
         return !found;
      string digest;
      return SWV5S5_MvpDecodeBootstrapZero(row.payload,authority) &&
         SWV5S5_MvpBootstrapZeroDigest(authority,digest) && digest==row.payload_digest &&
         digest==authority.authority_digest;
   }
};

class SWV5S5_MvpBootstrapZeroAuthorityProducer
{
public:
   bool Produce(const SWV5_ContractValidationContext &context,const SWV5_PersistenceNamespace &scope,
                const SWV5_AccountRiskNamespace &account,const SWV5_InstanceLease &lease,
                const SWV5_HardKillState &hard_kill,ISWV5S5MvpBootstrapBrokerObserver &broker,
                SWV5S5_MvpSqliteAuthorityStore &physical_store,
                SWV5S5_MvpBootstrapZeroStateAuthority &authority)
   {
      ZeroMemory(authority); SWV5S5_MvpBootstrapBrokerObservation observed;
      if(!broker.Capture(SWV5S5_MVP_SYMBOL,observed) || !observed.positions_query_succeeded ||
         !observed.active_orders_query_succeeded || !observed.enumeration_complete || observed.row_failures!=0 ||
         observed.total_positions!=0 || observed.total_active_orders!=0 || observed.total_exposure_volume!=0.0 ||
         observed.observed_at!=context.clock_time || !SWV5S5_MvpProfileMatches(observed.profile,ACCOUNT_TRADE_MODE_DEMO) ||
         observed.profile.broker_identity!=account.broker_identity || observed.profile.server!=account.server ||
         observed.profile.account_login!=account.account_login || hard_kill.state!=SWV5_HARD_KILL_ACTIVE ||
         hard_kill.latch_id=="" || hard_kill.latch_generation==0 ||
         !SWV5S5_EqualNamespace(scope,hard_kill.persistence_namespace) ||
         !SWV5S5_EqualOwnershipKey(lease.fence.ownership_namespace,scope.ownership_namespace) ||
         (lease.status!=SWV5_LOCK_ACQUIRED && lease.status!=SWV5_LOCK_RENEWED) ||
         lease.expires_at<=context.clock_time) return false;
      SWV5S5_MvpInitProductionVersion(authority.contract_version);
      authority.persistence_namespace=scope; authority.account_namespace=account;
      authority.ownership_fence=lease.fence; authority.hard_kill_latch_id=hard_kill.latch_id;
      authority.hard_kill_latch_generation=hard_kill.latch_generation;
      authority.observed_at=context.clock_time; authority.authority_sequence=context.clock_sequence;
      SWV5S5_MvpInitProductionVersion(authority.broker_evidence.contract_version);
      authority.broker_evidence.persistence_namespace=scope;
      authority.broker_evidence.evidence_id="BROKER-ZERO-"+observed.snapshot_digest;
      authority.broker_evidence.issuing_component=SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER;
      authority.broker_evidence.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
      authority.broker_evidence.evidence_sequence=context.clock_sequence;
      authority.broker_evidence.observed_at=context.clock_time;
      authority.broker_evidence.state_digest=observed.snapshot_digest;
      SWV5S5_MvpBootstrapPersistenceZeroProducer persistence; string persistence_digest;
      if(!persistence.Observe(physical_store,scope,context.clock_time,context.clock_sequence,
                              authority.persistence_evidence,persistence_digest)) return false;
      SWV5S5_MvpInitProductionVersion(authority.exposure_evidence.contract_version);
      authority.exposure_evidence.evidence_id="EXPOSURE-ZERO-"+observed.snapshot_digest;
      authority.exposure_evidence.issuing_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
      authority.exposure_evidence.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
      authority.exposure_evidence.observed_exposure_volume=0.0;
      authority.exposure_evidence.prior_exposure_volume=0.0;
      authority.exposure_evidence.zero_or_reducing=true;
      authority.exposure_evidence.evidence_sequence=context.clock_sequence;
      authority.exposure_evidence.observed_at=context.clock_time;
      string identity_body="",f;
      if(!SWV5S5_CanonicalString("broker",observed.snapshot_digest,f)) return false; identity_body+=f;
      if(!SWV5S5_CanonicalString("persistence",persistence_digest,f)) return false; identity_body+=f;
      if(!SWV5S5_CanonicalUInt("sequence",context.clock_sequence,f)) return false; identity_body+=f;
      string identity_digest;
      if(!SWV5S5_DomainDigest(SWV5S5_MVP_BOOTSTRAP_ZERO_DIGEST_DOMAIN+"-ID",identity_body,identity_digest)) return false;
      authority.authority_id="BOOTSTRAP-ZERO-"+identity_digest;
      return SWV5S5_MvpBootstrapZeroDigest(authority,authority.authority_digest);
   }
};

class SWV5S5_MvpHardKillRiskGovernanceIssuer
{
public:
   bool Issue(const SWV5S5_MvpOperatorInvocation &operator_invocation,
              const SWV5_ContractValidationContext &context,const SWV5_HardKillState &current_state,
              const SWV5S5_MvpBootstrapZeroStateAuthority &bootstrap,
              SWV5_HardKillReleaseEvidence &evidence,
              SWV5_HardKillReleaseAuthorityRecord &record)
   {
      ZeroMemory(evidence); ZeroMemory(record); string bootstrap_digest;
      if(!SWV5S5_MvpOperatorInvocationValid(operator_invocation,context.clock_time) ||
         current_state.state!=SWV5_HARD_KILL_ACTIVE ||
         !SWV5S5_MvpBootstrapZeroDigest(bootstrap,bootstrap_digest) ||
         bootstrap_digest!=bootstrap.authority_digest || bootstrap.observed_at!=context.clock_time ||
         bootstrap.hard_kill_latch_id!=current_state.latch_id ||
         bootstrap.hard_kill_latch_generation!=current_state.latch_generation ||
         !SWV5S5_EqualNamespace(bootstrap.persistence_namespace,current_state.persistence_namespace) ||
         bootstrap.exposure_evidence.observed_exposure_volume!=0.0 ||
         bootstrap.exposure_evidence.prior_exposure_volume!=0.0 || !bootstrap.exposure_evidence.zero_or_reducing)
         return false;
      evidence.contract_version=current_state.contract_version;
      evidence.persistence_namespace=current_state.persistence_namespace;
      evidence.release_id="MVP-BOOTSTRAP-RELEASE-"+bootstrap_digest;
      evidence.latch_id=current_state.latch_id; evidence.latch_generation=current_state.latch_generation;
      evidence.release_generation=current_state.release_generation+1;
      evidence.approval_policy_id="HARD-KILL-RELEASE-V5";
      evidence.approval_sequence=bootstrap.authority_sequence;
      evidence.operator_identity.operator_id=operator_invocation.operator_id;
      evidence.operator_identity.authority_role=operator_invocation.authority_role;
      evidence.operator_identity.authentication_reference=operator_invocation.authentication_reference;
      evidence.operator_identity.authenticated_at=operator_invocation.authenticated_at;
      evidence.approving_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
      evidence.broker_evidence=bootstrap.broker_evidence;
      evidence.persistence_evidence=bootstrap.persistence_evidence;
      evidence.exposure_evidence=bootstrap.exposure_evidence;
      evidence.approved_at=context.clock_time; evidence.released_at=context.clock_time;
      evidence.expires_at=context.clock_time+(datetime)SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS;
      evidence.release_record_sequence=bootstrap.authority_sequence;
      evidence.audit_reference=bootstrap.authority_id;
      if(!SWV5S5_MvpHardKillReleaseDigest(evidence,evidence.release_record_digest)) return false;
      record.contract_version=current_state.contract_version; record.persistence_namespace=current_state.persistence_namespace;
      record.account_namespace=current_state.account_namespace; record.latch_id=evidence.latch_id;
      record.latch_generation=evidence.latch_generation; record.release_id=evidence.release_id;
      record.release_generation=evidence.release_generation; record.operator_identity=evidence.operator_identity;
      record.approving_component=evidence.approving_component; record.approval_policy_id=evidence.approval_policy_id;
      record.approval_sequence=evidence.approval_sequence; record.broker_evidence_reference=evidence.broker_evidence;
      record.persistence_evidence_reference=evidence.persistence_evidence;
      record.exposure_evidence_reference=evidence.exposure_evidence; record.approved_at=evidence.approved_at;
      record.released_at=evidence.released_at; record.expires_at=evidence.expires_at;
      record.release_record_sequence=evidence.release_record_sequence;
      record.authority_record_id="MVP-HK-RISK-AUTH-"+bootstrap_digest;
      record.issuing_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
      record.authority_source=SWV5_AUTHORITY_HARD_KILL_RELEASE_RECORD;
      return SWV5S5_MvpHardKillAuthorityRecordDigest(record,record.authority_record_digest);
   }
};

#endif // SW_V5_S5_MVP_BOOTSTRAP_SAFETY_AUTHORITIES_MQH
