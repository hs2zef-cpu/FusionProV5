#ifndef SW_V5_S5_MVP_MANUAL_PROVISIONING_AUTHORITIES_MQH
#define SW_V5_S5_MVP_MANUAL_PROVISIONING_AUTHORITIES_MQH

// MANUALLY LAUNCHED DEMO DEPLOYMENT AUTHORITY ONLY.
// The runtime host must never call these provisioning methods.

#include "SW_V5_S5_MvpEvidenceRecoveryAuthorities.mqh"
#include "SW_V5_S5_MvpAuthorityRecordCodec.mqh"

const string SWV5S5_MVP_DOMAIN_GENESIS="MVP_NAMESPACE_GENESIS";
const string SWV5S5_MVP_DOMAIN_OPERATOR="MVP_OPERATOR_PROVISIONING_REFERENCE";
const string SWV5S5_MVP_DOMAIN_PRODUCER_TRUST="MVP_PRODUCER_TRUST";
const string SWV5S5_MVP_DOMAIN_HARD_KILL="MVP_HARD_KILL_STATE";
const string SWV5S5_MVP_DOMAIN_HARD_KILL_RELEASE="MVP_HARD_KILL_RELEASE_AUTHORITY";
const string SWV5S5_MVP_GENESIS_POLICY="SWV5-SPRINT5-GENESIS-PROVISIONING-V1";
const int SWV5S5_MVP_GENESIS_PROVISIONING=1;
const int SWV5S5_MVP_GENESIS_READY_FOR_RECONCILIATION=2;

int SWV5S5_MvpGenesisDomainCount(void) { return 13; }

string SWV5S5_MvpGenesisDomain(const int index)
{
   if(index==0) return SWV5S5_MVP_DOMAIN_OPERATOR;
   if(index==1) return SWV5S5_MVP_DOMAIN_PRODUCER_TRUST;
   if(index==2) return SWV5S5_MVP_DOMAIN_OWNERSHIP;
   if(index==3) return SWV5S5_MVP_DOMAIN_HARD_KILL;
   if(index==4) return "MVP_SYMBOL_SPECIFICATION";
   if(index==5) return "MVP_INGRESS_LEDGER";
   if(index==6) return "MVP_REQUEST_SEQUENCE";
   if(index==7) return SWV5S5_MVP_DOMAIN_SUBMISSION;
   if(index==8) return SWV5S5_MVP_DOMAIN_EXECUTION_PENDING;
   if(index==9) return SWV5S5_MVP_DOMAIN_BROKER_SYNC;
   if(index==10) return SWV5S5_MVP_DOMAIN_BROKER_CALLBACK_INDEX;
   if(index==11) return SWV5S5_MVP_DOMAIN_RECONCILIATION;
   if(index==12) return "MVP_RECOVERY_METADATA";
   return "";
}

bool SWV5S5_MvpGenesisManifestDigest(string &digest)
{
   string body="",f;
   for(int i=0;i<SWV5S5_MvpGenesisDomainCount();i++)
   { if(!SWV5S5_CanonicalIndexed("domain",(ulong)i,SWV5S5_MvpGenesisDomain(i),f)) return false; body+=f; }
   return SWV5S5_DomainDigest(SWV5S5_MVP_GENESIS_POLICY,body,digest);
}

bool SWV5S5_MvpOperatorPayload(const SWV5S5_MvpOperatorInvocation &operator_invocation,string &payload,
                               string &digest)
{
   string f; payload="";
   if(!SWV5S5_CanonicalString("operator_id",operator_invocation.operator_id,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalString("authority_role",operator_invocation.authority_role,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalString("authentication_reference",operator_invocation.authentication_reference,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalDatetime("authenticated_at",operator_invocation.authenticated_at,f)) return false; payload+=f;
   return SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_OPERATOR,payload,digest);
}

class SWV5S5_MvpManualGenesisProvisioner
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
   string m_genesis_id,m_manifest_digest;

   bool DomainSeed(const string domain,const datetime now)
   {
      string body="",f,digest; int initial_state=0;
      if(!SWV5S5_CanonicalString("genesis_id",m_genesis_id,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("manifest_digest",m_manifest_digest,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("domain",domain,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("genesis_generation",1,f)) return false; body+=f;
      if(domain==SWV5S5_MVP_DOMAIN_HARD_KILL)
      {
         initial_state=(int)SWV5_HARD_KILL_ACTIVE;
         if(!SWV5S5_CanonicalString("latch_id","GENESIS-LATCH/"+m_genesis_id,f)) return false; body+=f;
         if(!SWV5S5_CanonicalUInt("latch_generation",1,f)) return false; body+=f;
         if(!SWV5S5_CanonicalUInt("release_generation",0,f)) return false; body+=f;
         if(!SWV5S5_CanonicalString("activation_reason","NAMESPACE_GENESIS_NOT_RECONCILED",f)) return false; body+=f;
         if(!SWV5S5_CanonicalString("activation_authority",SWV5S5_MVP_GENESIS_POLICY,f)) return false; body+=f;
      }
      else if(domain==SWV5S5_MVP_DOMAIN_OWNERSHIP) initial_state=(int)SWV5_LOCK_UNCLAIMED;
      if(!SWV5S5_DomainDigest(domain,body,digest)) return false;
      SWV5S5_MvpAuthorityRow row; bool found=false;
      if(!m_store.ReadRow(domain,"GENESIS",row,found)) return false;
      if(found) return row.logical_revision==1 && row.payload_digest==digest && row.payload==body && row.state==initial_state;
      if(!m_store.CompareAndSet(domain,"GENESIS",0,"","",0,1,initial_state,digest,body,now,row)) return false;
      if(domain==SWV5S5_MVP_DOMAIN_HARD_KILL)
      {
         SWV5S5_MvpAuthorityRow current; bool current_found=false;
         if(!m_store.ReadRow(domain,"CURRENT",current,current_found) || current_found) return false;
         return m_store.CompareAndSet(domain,"CURRENT",0,"","",0,1,(int)SWV5_HARD_KILL_ACTIVE,
            digest,body,now,current);
      }
      return true;
   }

public:
   bool Configure(const string relative_path,const string namespace_digest)
   { m_genesis_id=""; m_manifest_digest=""; return m_store.Open(relative_path,namespace_digest); }

   bool Begin(const SWV5S5_MvpOperatorInvocation &operator_invocation,const datetime now)
   {
      if(!SWV5S5_MvpOperatorInvocationValid(operator_invocation,now) ||
         !SWV5S5_MvpGenesisManifestDigest(m_manifest_digest)) return false;
      string operator_payload,operator_digest,body="",f,digest;
      if(!SWV5S5_MvpOperatorPayload(operator_invocation,operator_payload,operator_digest)) return false;
      if(!SWV5S5_CanonicalString("schema_id",SWV5S5_MVP_STORE_SCHEMA_ID,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("schema_version",SWV5S5_MVP_STORE_SCHEMA_VERSION,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("policy_id",SWV5S5_MVP_GENESIS_POLICY,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("namespace_digest",m_store.NamespaceDigest(),f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("operator_digest",operator_digest,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("manifest_digest",m_manifest_digest,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("generation",1,f)) return false; body+=f;
      if(!SWV5S5_CanonicalDatetime("created_at",now,f)) return false; body+=f;
      if(!SWV5S5_DomainDigest(SWV5S5_MVP_GENESIS_POLICY,body,m_genesis_id)) return false;
      if(!SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_GENESIS,body,digest)) return false;
      SWV5S5_MvpAuthorityRow row; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_GENESIS,"GENESIS",row,found) || found) return false;
      if(!m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_GENESIS,"GENESIS",0,"","",0,1,
         SWV5S5_MVP_GENESIS_PROVISIONING,digest,body,now,row)) return false;
      string operator_seed=operator_payload,f2,operator_seed_digest;
      if(!SWV5S5_CanonicalString("genesis_id",m_genesis_id,f2)) return false; operator_seed+=f2;
      if(!SWV5S5_CanonicalString("manifest_digest",m_manifest_digest,f2)) return false; operator_seed+=f2;
      if(!SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_OPERATOR,operator_seed,operator_seed_digest)) return false;
      return m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_OPERATOR,"GENESIS",0,"","",0,1,0,
         operator_seed_digest,operator_seed,now,row);
   }

   bool InitializeAllDomains(const datetime now)
   {
      if(m_genesis_id=="" || m_manifest_digest=="") return false;
      for(int i=1;i<SWV5S5_MvpGenesisDomainCount();i++)
         if(!DomainSeed(SWV5S5_MvpGenesisDomain(i),now)) return false;
      return true;
   }

   bool FinalizeReadyForReconciliation(const datetime now)
   {
      SWV5S5_MvpAuthorityRow genesis,row,committed; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_GENESIS,"GENESIS",genesis,found) || !found ||
         genesis.state!=SWV5S5_MVP_GENESIS_PROVISIONING) return false;
      for(int i=0;i<SWV5S5_MvpGenesisDomainCount();i++)
      {
         bool domain_found=false;
         if(!m_store.ReadRow(SWV5S5_MvpGenesisDomain(i),"GENESIS",row,domain_found) || !domain_found ||
            row.logical_revision!=1 || StringFind(row.payload,m_genesis_id)<0 ||
            StringFind(row.payload,m_manifest_digest)<0) return false;
      }
      string body=genesis.payload,f,digest;
      if(!SWV5S5_CanonicalString("completed_manifest_digest",m_manifest_digest,f)) return false; body+=f;
      if(!SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_GENESIS,body,digest)) return false;
      return m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_GENESIS,"GENESIS",genesis.logical_revision,
         genesis.store_revision,genesis.payload_digest,genesis.state,genesis.logical_revision+1,
         SWV5S5_MVP_GENESIS_READY_FOR_RECONCILIATION,digest,body,now,committed);
   }

   bool IsReadyForReconciliation(bool &ready)
   {
      ready=false; SWV5S5_MvpAuthorityRow row; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_GENESIS,"GENESIS",row,found)) return false;
      ready=found && row.state==SWV5S5_MVP_GENESIS_READY_FOR_RECONCILIATION;
      return true;
   }
};

class SWV5S5_MvpManualProducerTrustProvisioner
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
public:
   bool Configure(const string relative_path,const string namespace_digest)
   { return m_store.Open(relative_path,namespace_digest); }

   bool Provision(const SWV5S5_MvpOperatorInvocation &operator_invocation,
                  const SWV5S5_ProducerTrustAnchor &anchor,
                  const SWV5S5_ProducerTrustScope &scope,const datetime now,
                  SWV5S5_ProducerTrustRecord &record)
   {
      ZeroMemory(record);
      string namespace_projection;
      if(!SWV5S5_MvpOperatorInvocationValid(operator_invocation,now) || anchor.issuer_identity=="" ||
         anchor.issuer_policy_id=="" || anchor.current_authority_record_id=="" ||
         anchor.current_authority_generation==0 || scope.producer_component!="DECISION" ||
         scope.producer_instance!=SWV5S5_MVP_PRODUCER_INSTANCE || scope.symbol!=SWV5S5_MVP_SYMBOL ||
         !SWV5S5_CanonicalNamespace("namespace",scope.persistence_namespace,namespace_projection) ||
         scope.producer_epoch==0 ||
         scope.publication_clock_authority!=SWV5_TIME_AUTHORITY_BROKER_SERVER || scope.publication_clock_id=="") return false;
      SWV5S5_InitContractVersion(record.contract_version);
      record.authority_record_id=anchor.current_authority_record_id;
      record.authority_generation=anchor.current_authority_generation;
      record.issuer_identity=anchor.issuer_identity; record.issuer_policy_id=anchor.issuer_policy_id;
      record.producer_component=scope.producer_component; record.producer_instance=scope.producer_instance;
      record.producer_epoch=scope.producer_epoch; record.persistence_namespace=scope.persistence_namespace;
      record.symbol=scope.symbol; record.timeframe=scope.timeframe; record.execution_mode=scope.execution_mode;
      record.clock_id=scope.publication_clock_id; record.clock_authority=scope.publication_clock_authority;
      record.status=SWV5S5_TRUST_AUTHORIZED; record.valid_from=now;
      record.valid_until=now+(datetime)SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS;
      record.superseding_record_id=""; record.superseding_generation=0;
      if(!SWV5S5_DeriveProducerTrustDigest(record,record.record_digest)) return false;
      string payload="";
      if(!SWV5S5_MvpEncodeProducerTrustPhysical(record,anchor,operator_invocation.operator_id,
          operator_invocation.authentication_reference,payload)) return false;
      SWV5S5_MvpAuthorityRow current,committed; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_PRODUCER_TRUST,"CURRENT",current,found)) return false;
      return m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_PRODUCER_TRUST,"CURRENT",
         (found ? current.logical_revision : 0),(found ? current.store_revision : ""),
         (found ? current.payload_digest : ""),(found ? current.state : 0),
         (found ? current.logical_revision+1 : 1),1,record.record_digest,payload,now,committed);
   }

   bool LoadCurrent(SWV5S5_ProducerTrustRecord &record,SWV5S5_ProducerTrustAnchor &anchor,
                    string &operator_id,string &authentication_reference,bool &found)
   {
      ZeroMemory(record); ZeroMemory(anchor); operator_id=""; authentication_reference=""; found=false;
      SWV5S5_MvpAuthorityRow row; bool row_found=false; string digest,store_revision;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_PRODUCER_TRUST,"CURRENT",row,row_found)) return false;
      if(!row_found) return true;
      if(row.state!=1 || row.logical_revision==0 ||
         !SWV5S5_MvpDecodeProducerTrustPhysical(row.payload,record,anchor,operator_id,
                                                authentication_reference) ||
         !SWV5S5_DeriveProducerTrustDigest(record,digest) || digest!=record.record_digest ||
         !m_store.DeriveStoreRevision(row.domain_key,row.record_key,row.logical_revision,
                                      row.payload_digest,store_revision) || store_revision!=row.store_revision ||
         row.payload_digest!=record.record_digest) return false;
      found=true;
      return true;
   }
};

class SWV5S5_MvpManualSafetyReleaseProvisioner
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;

   bool StatePayload(const SWV5_HardKillState &state,string &payload,string &digest)
   {
      if(!SWV5S5_CanonicalHardKillState("hard_kill",state,payload)) return false;
      return SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,payload,digest);
   }

   bool SameOperator(const SWV5_OperatorIdentity &left,const SWV5_OperatorIdentity &right)
   {
      string a,b; return SWV5S5_CanonicalOperatorIdentity("operator",left,a) &&
         SWV5S5_CanonicalOperatorIdentity("operator",right,b) && a==b;
   }

   bool SameTypedEvidence(const SWV5_TypedReconciliationEvidence &left,
                          const SWV5_TypedReconciliationEvidence &right)
   {
      string a,b; return SWV5S5_CanonicalTypedReconciliationEvidence("evidence",left,a) &&
         SWV5S5_CanonicalTypedReconciliationEvidence("evidence",right,b) && a==b;
   }

   bool SameExposureEvidence(const SWV5_ExposureReductionEvidence &left,
                             const SWV5_ExposureReductionEvidence &right)
   {
      string a,b; return SWV5S5_CanonicalExposureReductionEvidence("evidence",left,a) &&
         SWV5S5_CanonicalExposureReductionEvidence("evidence",right,b) && a==b;
   }

   bool SameAccountNamespace(const SWV5_AccountRiskNamespace &left,
                             const SWV5_AccountRiskNamespace &right)
   {
      string a,b; return SWV5S5_CanonicalAccountNamespace("account",left,a) &&
         SWV5S5_CanonicalAccountNamespace("account",right,b) && a==b;
   }
public:
   bool Configure(const string relative_path,const string namespace_digest)
   { return m_store.Open(relative_path,namespace_digest); }

   bool StageReleasePending(const SWV5S5_MvpOperatorInvocation &operator_invocation,
                            const SWV5_ContractValidationContext &context,
                            const SWV5_HardKillState &active_state,
                            const SWV5_HardKillReleaseEvidence &evidence,
                            SWV5_HardKillState &pending_state,
                            SWV5S5_MvpAuthorityRow &committed)
   {
      ZeroMemory(pending_state);
      if(!SWV5S5_MvpOperatorInvocationValid(operator_invocation,context.clock_time) ||
         active_state.state!=SWV5_HARD_KILL_ACTIVE || active_state.latch_id=="" ||
         active_state.latch_generation==0 || evidence.latch_id!=active_state.latch_id ||
         evidence.latch_generation!=active_state.latch_generation ||
         evidence.release_generation!=active_state.release_generation+1 ||
         evidence.operator_identity.operator_id!=operator_invocation.operator_id ||
         evidence.operator_identity.authority_role!=operator_invocation.authority_role ||
         evidence.operator_identity.authentication_reference!=operator_invocation.authentication_reference ||
         evidence.operator_identity.authenticated_at!=operator_invocation.authenticated_at) return false;
      SWV5S5_MvpAuthorityRow latch; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",latch,found) || !found ||
         latch.state!=(int)SWV5_HARD_KILL_ACTIVE || StringFind(latch.payload,active_state.latch_id)<0) return false;
      pending_state=active_state; pending_state.state=SWV5_HARD_KILL_RELEASE_PENDING;
      pending_state.release_evidence=evidence;
      string payload,digest;
      if(!StatePayload(pending_state,payload,digest)) return false;
      return m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",
         latch.logical_revision,latch.store_revision,latch.payload_digest,latch.state,
         latch.logical_revision+1,(int)SWV5_HARD_KILL_RELEASE_PENDING,digest,payload,
         context.clock_time,committed);
   }

   bool PersistApprovedRelease(const SWV5S5_MvpOperatorInvocation &operator_invocation,
                               const SWV5_ContractValidationContext &context,
                               const SWV5_HardKillState &current_state,
                               const SWV5_HardKillReleaseEvidence &evidence,
                               const SWV5_HardKillReleaseAuthorityRecord &authority_record,
                               const SWV5_InstanceLease &current_lease,
                               const SWV5S5_F_ReconciliationResult &zero_state_reconciliation,
                               ISWV5RiskContract &risk_contract,
                               SWV5S5_MvpAuthorityRow &committed)
   {
      SWV5_ContractDecision decision;
      string evidence_digest,authority_digest,pending_payload,pending_digest,reconciliation_digest;
      SWV5S5_LeaseLivenessAuthorityView lease_view; lease_view.lease=current_lease;
      const bool zero_state_valid=SWV5S5_F_DeriveResultDigest(zero_state_reconciliation,reconciliation_digest) &&
         reconciliation_digest==zero_state_reconciliation.result_digest &&
         zero_state_reconciliation.state==SWV5S5_F_NO_SIDE_EFFECT_CONFIRMED &&
         zero_state_reconciliation.disposition==SWV5S5_F_DISPOSITION_NEGATIVE_CONFIRMED &&
         zero_state_reconciliation.authoritative_negative && !zero_state_reconciliation.authoritative_positive &&
         !zero_state_reconciliation.retry_allowed && zero_state_reconciliation.residual_volume<=context.volume_tolerance;
      const bool lease_valid=SWV5S5_DeriveLeaseProjection(lease_view) &&
         (current_lease.status==SWV5_LOCK_ACQUIRED || current_lease.status==SWV5_LOCK_RENEWED) &&
         current_lease.clock_id==context.clock_id && current_lease.clock_authority==context.clock_authority &&
         current_lease.heartbeat_clock_sequence<=context.clock_sequence && current_lease.expires_at>context.clock_time &&
         SWV5S5_EqualOwnershipKey(current_lease.fence.ownership_namespace,
                                  current_state.persistence_namespace.ownership_namespace);
      if(!zero_state_valid || !lease_valid ||
         !SWV5S5_MvpOperatorInvocationValid(operator_invocation,context.clock_time) ||
         !SWV5S5_MvpVersionExact(context,authority_record.contract_version) ||
         !SWV5S5_MvpVersionExact(context,authority_record.persistence_namespace.contract_version) ||
         !SWV5S5_MvpVersionExact(context,authority_record.account_namespace.contract_version) ||
         evidence.operator_identity.operator_id!=operator_invocation.operator_id ||
         evidence.operator_identity.authority_role!=operator_invocation.authority_role ||
         evidence.operator_identity.authentication_reference!=operator_invocation.authentication_reference ||
         evidence.operator_identity.authenticated_at!=operator_invocation.authenticated_at ||
         !SameOperator(authority_record.operator_identity,evidence.operator_identity) ||
         authority_record.release_id!=evidence.release_id ||
         authority_record.latch_id!=evidence.latch_id ||
         authority_record.latch_generation!=evidence.latch_generation ||
         authority_record.release_generation!=evidence.release_generation ||
         authority_record.approving_component!=evidence.approving_component ||
         authority_record.approval_policy_id!=evidence.approval_policy_id ||
         authority_record.approval_sequence!=evidence.approval_sequence ||
         !SameTypedEvidence(authority_record.broker_evidence_reference,evidence.broker_evidence) ||
         !SameTypedEvidence(authority_record.persistence_evidence_reference,evidence.persistence_evidence) ||
         !SameExposureEvidence(authority_record.exposure_evidence_reference,evidence.exposure_evidence) ||
         authority_record.approved_at!=evidence.approved_at || authority_record.released_at!=evidence.released_at ||
         authority_record.expires_at!=evidence.expires_at ||
         authority_record.release_record_sequence!=evidence.release_record_sequence ||
         authority_record.authority_record_id=="" ||
         authority_record.issuing_component!=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE ||
         authority_record.authority_source!=SWV5_AUTHORITY_HARD_KILL_RELEASE_RECORD ||
         !SWV5S5_EqualNamespace(authority_record.persistence_namespace,current_state.persistence_namespace) ||
         !SameAccountNamespace(authority_record.account_namespace,current_state.account_namespace) ||
         !SWV5S5_MvpHardKillReleaseDigest(evidence,evidence_digest) ||
         evidence_digest!=evidence.release_record_digest ||
         !SWV5S5_MvpHardKillAuthorityRecordDigest(authority_record,authority_digest) ||
         authority_digest!=authority_record.authority_record_digest ||
         evidence.expires_at>context.clock_time+(datetime)SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS ||
         !risk_contract.ValidateHardKillRelease(context,current_state,evidence,decision) ||
         !StatePayload(current_state,pending_payload,pending_digest)) return false;
      string payload="",f,digest;
      if(!SWV5S5_CanonicalString("release_record_digest",evidence.release_record_digest,f)) return false; payload+=f;
      if(!SWV5S5_CanonicalString("authority_record_digest",authority_record.authority_record_digest,f)) return false; payload+=f;
      if(!SWV5S5_CanonicalString("operator_id",operator_invocation.operator_id,f)) return false; payload+=f;
      if(!SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL_RELEASE,payload,digest)) return false;
      SWV5S5_MvpAuthorityRow latch; bool latch_found=false;
      SWV5S5_MvpAuthorityRow ownership; bool ownership_found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",latch,latch_found) || !latch_found ||
         latch.state!=(int)SWV5_HARD_KILL_RELEASE_PENDING || latch.payload_digest!=pending_digest ||
         latch.payload!=pending_payload ||
         !m_store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,ownership,ownership_found) ||
         !ownership_found || ownership.payload_digest!=lease_view.projection_digest ||
         ownership.state!=(int)current_lease.status) return false;
      SWV5S5_MvpAuthorityRow current; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL_RELEASE,"CURRENT",current,found)) return false;
      SWV5S5_MvpAuthorityRow release_row;
      if(found)
      {
         if(current.state!=1 || current.payload_digest!=digest || current.payload!=payload) return false;
         release_row=current;
      }
      else if(!m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_HARD_KILL_RELEASE,"CURRENT",
         0,"","",0,1,1,digest,payload,context.clock_time,release_row)) return false;
      SWV5_HardKillState released_state=current_state;
      released_state.state=SWV5_HARD_KILL_RELEASED;
      released_state.release_generation=evidence.release_generation;
      released_state.release_evidence=evidence;
      released_state.release_authority_reference.contract_version=authority_record.contract_version;
      released_state.release_authority_reference.authority_record_id=authority_record.authority_record_id;
      released_state.release_authority_reference.authority_record_sequence=authority_record.release_record_sequence;
      released_state.release_authority_reference.authority_record_digest=authority_record.authority_record_digest;
      released_state.release_authority_reference.release_id=authority_record.release_id;
      released_state.release_authority_reference.latch_generation=authority_record.latch_generation;
      released_state.release_authority_reference.release_generation=authority_record.release_generation;
      string latch_payload,latch_digest;
      if(!StatePayload(released_state,latch_payload,latch_digest)) return false;
      return m_store.CompareAndSetWithGuard(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",
         latch.logical_revision,latch.store_revision,latch.payload_digest,latch.state,
         latch.logical_revision+1,(int)SWV5_HARD_KILL_RELEASED,latch_digest,latch_payload,context.clock_time,
         SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,ownership.logical_revision,
         ownership.store_revision,ownership.payload_digest,ownership.state,committed);
   }
};

#endif // SW_V5_S5_MVP_MANUAL_PROVISIONING_AUTHORITIES_MQH
