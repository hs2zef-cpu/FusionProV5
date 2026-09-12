#ifndef SW_V5_S5_MVP_MANUAL_PROVISIONING_AUTHORITIES_MQH
#define SW_V5_S5_MVP_MANUAL_PROVISIONING_AUTHORITIES_MQH

// MANUALLY LAUNCHED DEMO DEPLOYMENT AUTHORITY ONLY.
// The runtime host must never call these provisioning methods.

#include "SW_V5_S5_MvpEvidenceRecoveryAuthorities.mqh"

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
      string body="",f,digest;
      if(!SWV5S5_CanonicalString("genesis_id",m_genesis_id,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("manifest_digest",m_manifest_digest,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("domain",domain,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("genesis_generation",1,f)) return false; body+=f;
      if(!SWV5S5_DomainDigest(domain,body,digest)) return false;
      SWV5S5_MvpAuthorityRow row; bool found=false;
      if(!m_store.ReadRow(domain,"GENESIS",row,found)) return false;
      if(found) return row.logical_revision==1 && row.payload_digest==digest && row.payload==body;
      return m_store.CompareAndSet(domain,"GENESIS",0,"","",0,1,0,digest,body,now,row);
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
      return DomainSeed(SWV5S5_MVP_DOMAIN_OPERATOR,now);
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
      string payload="",f;
      if(!SWV5S5_CanonicalString("record_digest",record.record_digest,f)) return false; payload+=f;
      if(!SWV5S5_CanonicalString("operator_id",operator_invocation.operator_id,f)) return false; payload+=f;
      if(!SWV5S5_CanonicalString("authentication_reference",operator_invocation.authentication_reference,f)) return false; payload+=f;
      SWV5S5_MvpAuthorityRow current,committed; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_PRODUCER_TRUST,"CURRENT",current,found)) return false;
      return m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_PRODUCER_TRUST,"CURRENT",
         (found ? current.logical_revision : 0),(found ? current.store_revision : ""),
         (found ? current.payload_digest : ""),(found ? current.state : 0),
         (found ? current.logical_revision+1 : 1),1,record.record_digest,payload,now,committed);
   }
};

class SWV5S5_MvpManualSafetyReleaseProvisioner
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
public:
   bool Configure(const string relative_path,const string namespace_digest)
   { return m_store.Open(relative_path,namespace_digest); }

   bool PersistApprovedRelease(const SWV5S5_MvpOperatorInvocation &operator_invocation,
                               const SWV5_ContractValidationContext &context,
                               const SWV5_HardKillState &current_state,
                               const SWV5_HardKillReleaseEvidence &evidence,
                               const SWV5_HardKillReleaseAuthorityRecord &authority_record,
                               ISWV5RiskContract &risk_contract,const bool zero_state_reconciled,
                               SWV5S5_MvpAuthorityRow &committed)
   {
      SWV5_ContractDecision decision;
      if(!zero_state_reconciled || !SWV5S5_MvpOperatorInvocationValid(operator_invocation,context.clock_time) ||
         evidence.operator_identity.operator_id!=operator_invocation.operator_id ||
         evidence.operator_identity.authority_role!=operator_invocation.authority_role ||
         evidence.operator_identity.authentication_reference!=operator_invocation.authentication_reference ||
         evidence.operator_identity.authenticated_at!=operator_invocation.authenticated_at ||
         authority_record.operator_identity.operator_id!=operator_invocation.operator_id ||
         authority_record.operator_identity.authentication_reference!=operator_invocation.authentication_reference ||
         authority_record.release_id!=evidence.release_id ||
         authority_record.latch_id!=evidence.latch_id ||
         authority_record.latch_generation!=evidence.latch_generation ||
         authority_record.release_generation!=evidence.release_generation ||
         authority_record.authority_record_digest=="" || evidence.release_record_digest=="" ||
         evidence.expires_at>context.clock_time+(datetime)SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS ||
         !risk_contract.ValidateHardKillRelease(context,current_state,evidence,decision)) return false;
      string payload="",f,digest;
      if(!SWV5S5_CanonicalString("release_record_digest",evidence.release_record_digest,f)) return false; payload+=f;
      if(!SWV5S5_CanonicalString("authority_record_digest",authority_record.authority_record_digest,f)) return false; payload+=f;
      if(!SWV5S5_CanonicalString("operator_id",operator_invocation.operator_id,f)) return false; payload+=f;
      if(!SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL_RELEASE,payload,digest)) return false;
      SWV5S5_MvpAuthorityRow current; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL_RELEASE,"CURRENT",current,found)) return false;
      return m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_HARD_KILL_RELEASE,"CURRENT",
         (found ? current.logical_revision : 0),(found ? current.store_revision : ""),
         (found ? current.payload_digest : ""),(found ? current.state : 0),
         (found ? current.logical_revision+1 : 1),1,digest,payload,context.clock_time,committed);
   }
};

#endif // SW_V5_S5_MVP_MANUAL_PROVISIONING_AUTHORITIES_MQH
