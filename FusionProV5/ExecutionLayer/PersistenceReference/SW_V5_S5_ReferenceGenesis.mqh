#ifndef SW_V5_S5_REFERENCE_GENESIS_MQH
#define SW_V5_S5_REFERENCE_GENESIS_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// Provisioning authority is a complete typed operator record. Domain
// readiness is derived from central-store readback, never boolean flags.

#include "SW_V5_S5_ReferenceStoreCommon.mqh"

enum SWV5S5_ReferenceGenesisState
{
   SWV5S5_GENESIS_ABSENT = 0,
   SWV5S5_GENESIS_PROVISIONING = 1,
   SWV5S5_GENESIS_READY_FOR_RECONCILIATION = 2
};

struct SWV5S5_ReferenceGenesisRequest
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   string genesis_id;
   string genesis_policy_id;
   uint genesis_policy_version;
   SWV5_OperatorIdentity operator_identity;
   SWV5_ComponentAuthority authority_component;
   SWV5_AuthoritySource authority_source;
   string creation_clock_id;
   SWV5_TimeAuthority creation_clock_authority;
   ulong creation_clock_sequence;
   datetime created_at;
   string manifest_digest;
};

struct SWV5S5_ReferenceGenesisRecord
{
   SWV5_ContractVersion contract_version;
   SWV5S5_ReferenceGenesisState state;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   string genesis_id;
   string genesis_policy_id;
   uint genesis_policy_version;
   SWV5_OperatorIdentity operator_identity;
   SWV5_ComponentAuthority authority_component;
   SWV5_AuthoritySource authority_source;
   string creation_clock_id;
   SWV5_TimeAuthority creation_clock_authority;
   ulong creation_clock_sequence;
   datetime created_at;
   string manifest_digest;
   ulong generation;
   ulong revision;
   SWV5_HardKillLatchState hard_kill_state;
   ulong hard_kill_latch_generation;
   ulong hard_kill_release_generation;
};

bool SWV5S5_ReferenceGenesisCanonical(const SWV5S5_ReferenceGenesisRecord &record,string &payload,
                                      string &scope,string &fence)
{
   if(!SWV5S5_ReferenceCanonicalNamespaceDigest(record.persistence_namespace,scope) ||
      !SWV5S5_ReferenceCanonicalFenceDigest(record.ownership_fence,fence) ||
      record.genesis_id=="" || record.manifest_digest=="" || record.operator_identity.operator_id=="" ||
      record.operator_identity.authority_role=="" || record.operator_identity.authentication_reference=="" ||
      record.operator_identity.authenticated_at<=0 || record.creation_clock_id=="" || record.creation_clock_sequence==0 ||
      record.created_at<=0 || record.generation==0 || record.revision==0) return false;
   string a,b,c,d,e,f,g,h,i,j,k,l;
   if(!SWV5S5_CanonicalContractVersion("version",record.contract_version,a) ||
      !SWV5S5_CanonicalNamespace("scope",record.persistence_namespace,b) ||
      !SWV5S5_CanonicalFence("fence",record.ownership_fence,c) ||
      !SWV5S5_CanonicalString("genesis_id",record.genesis_id,d) ||
      !SWV5S5_CanonicalString("policy",record.genesis_policy_id,e) ||
      !SWV5S5_CanonicalUInt("policy_version",record.genesis_policy_version,f) ||
      !SWV5S5_CanonicalString("operator",record.operator_identity.operator_id,g) ||
      !SWV5S5_CanonicalString("auth_reference",record.operator_identity.authentication_reference,h) ||
      !SWV5S5_CanonicalString("clock_id",record.creation_clock_id,i) ||
      !SWV5S5_CanonicalUInt("clock_sequence",record.creation_clock_sequence,j) ||
      !SWV5S5_CanonicalDatetime("created_at",record.created_at,k) ||
      !SWV5S5_CanonicalString("manifest",record.manifest_digest,l)) return false;
   payload=a+b+c+d+e+f+g+h+i+j+k+l; return true;
}

class SWV5S5_ReferenceGenesis
{
private:
   SWV5S5_FakeTransactionalStore m_store;
   SWV5S5_ReferenceGenesisRecord m_record;
   bool m_has_genesis;

   bool SeedDomain(const SWV5S5_ReferenceDomain domain,const string payload)
   {
      if(payload=="" || domain==SWV5S5_REF_DOMAIN_GENESIS) return false;
      SWV5S5_ReferenceDomainRow row; ZeroMemory(row); row.domain=domain;
      row.persistence_namespace_digest=SWV5S5_ReferenceDigest("GENESIS-NAMESPACE",m_record.manifest_digest);
      row.authority_fence_digest=SWV5S5_ReferenceDigest("GENESIS-FENCE",m_record.genesis_id);
      row.store_revision=1; row.payload=payload;
      if(!SWV5S5_ReferenceCanonicalPayloadDigest(domain,payload,row.payload_digest)) return false;
      return m_store.Seed(row);
   }

public:
   SWV5S5_ReferenceGenesis(void):m_has_genesis(false) { ZeroMemory(m_record); }

   bool BeginProvisioning(const SWV5S5_ReferenceGenesisRequest &request,bool &idempotent)
   {
      idempotent=false;
      if(m_has_genesis)
      {
         string a,b; if(!SWV5S5_ReferenceGenesisCanonical(m_record,a,b,b)) return false;
         idempotent=request.genesis_id==m_record.genesis_id && request.manifest_digest==m_record.manifest_digest &&
                    request.operator_identity.operator_id==m_record.operator_identity.operator_id &&
                    request.operator_identity.authentication_reference==m_record.operator_identity.authentication_reference;
         return idempotent;
      }
      if(!SWV5S5_IsCandidateVersion(request.contract_version) || request.genesis_id=="" ||
         request.genesis_policy_id=="" || request.genesis_policy_version==0 ||
         request.operator_identity.operator_id=="" || request.operator_identity.authority_role=="" ||
         request.operator_identity.authentication_reference=="" || request.operator_identity.authenticated_at<=0 ||
         request.authority_component==SWV5_COMPONENT_AUTHORITY_NONE || request.authority_source==SWV5_AUTHORITY_NONE ||
         request.creation_clock_id=="" || request.creation_clock_sequence==0 || request.created_at<=0 || request.manifest_digest=="") return false;
      SWV5S5_ReferenceGenesisRecord next; ZeroMemory(next); next.contract_version=request.contract_version;
      next.state=SWV5S5_GENESIS_PROVISIONING; next.persistence_namespace=request.persistence_namespace;
      next.ownership_fence=request.ownership_fence; next.genesis_id=request.genesis_id;
      next.genesis_policy_id=request.genesis_policy_id; next.genesis_policy_version=request.genesis_policy_version;
      next.operator_identity=request.operator_identity; next.authority_component=request.authority_component;
      next.authority_source=request.authority_source; next.creation_clock_id=request.creation_clock_id;
      next.creation_clock_authority=request.creation_clock_authority; next.creation_clock_sequence=request.creation_clock_sequence;
      next.created_at=request.created_at; next.manifest_digest=request.manifest_digest; next.generation=1; next.revision=1;
      next.hard_kill_state=SWV5_HARD_KILL_ACTIVE; next.hard_kill_latch_generation=1; next.hard_kill_release_generation=0;
      string payload,scope,fence; if(!SWV5S5_ReferenceGenesisCanonical(next,payload,scope,fence)) return false;
      SWV5S5_ReferenceDomainRow row; ZeroMemory(row); row.domain=SWV5S5_REF_DOMAIN_GENESIS;
      row.persistence_namespace_digest=scope; row.authority_fence_digest=fence; row.store_revision=1; row.payload=payload;
      if(!SWV5S5_ReferenceCanonicalPayloadDigest(row.domain,payload,row.payload_digest) || !m_store.Seed(row)) return false;
      m_record=next; m_has_genesis=true; return true;
   }

   bool InitializeDomain(const SWV5S5_ReferenceDomain domain,const string complete_canonical_state)
   {
      if(!m_has_genesis || m_record.state!=SWV5S5_GENESIS_PROVISIONING || complete_canonical_state=="" ||
         domain==SWV5S5_REF_DOMAIN_GENESIS) return false;
      string payload="GENESIS="+m_record.genesis_id+"|MANIFEST="+m_record.manifest_digest+"|"+complete_canonical_state;
      return SeedDomain(domain,payload);
   }

   bool Finalize(void)
   {
      if(!m_has_genesis || m_record.state!=SWV5S5_GENESIS_PROVISIONING) return false;
      for(int d=1;d<=6;d++) { SWV5S5_ReferenceDomainRow row; if(!m_store.Load((SWV5S5_ReferenceDomain)d,row)) return false; }
      m_record.state=SWV5S5_GENESIS_READY_FOR_RECONCILIATION; m_record.revision++; return true;
   }

   SWV5S5_ReferenceGenesisRecord Current(void) const { return m_record; }
};

#endif
