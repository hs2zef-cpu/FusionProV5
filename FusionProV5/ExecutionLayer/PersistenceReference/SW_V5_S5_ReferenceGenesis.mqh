#ifndef SW_V5_S5_REFERENCE_GENESIS_MQH
#define SW_V5_S5_REFERENCE_GENESIS_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS

#include "SW_V5_S5_ReferenceStoreCommon.mqh"

enum SWV5S5_ReferenceGenesisState
{
   SWV5S5_GENESIS_ABSENT = 0,
   SWV5S5_GENESIS_PROVISIONING = 1,
   SWV5S5_GENESIS_READY_FOR_RECONCILIATION = 2
};

struct SWV5S5_ReferenceGenesisRequest
{
   SWV5_PersistenceNamespace persistence_namespace;
   string persistence_namespace_digest;
   string ownership_namespace_digest;
   string genesis_id;
   string genesis_policy_id;
   uint genesis_policy_version;
   string operator_identity;
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
   SWV5S5_ReferenceGenesisState state;
   string genesis_id;
   string persistence_namespace_digest;
   string ownership_namespace_digest;
   string manifest_digest;
   ulong generation;
   ulong revision;
   bool hard_kill_active;
   ulong hard_kill_latch_generation;
   ulong hard_kill_release_generation;
   bool bootstrap_clean_shutdown;
   bool reconciliation_required;
};

class SWV5S5_ReferenceGenesis
{
private:
   SWV5S5_ReferenceGenesisRecord m_record;
   bool m_domain_initialized[7];
   bool m_operational_state_exists;

   bool SameRequest(const SWV5S5_ReferenceGenesisRequest &request) const
   {
      return request.genesis_id==m_record.genesis_id &&
             request.persistence_namespace_digest==m_record.persistence_namespace_digest &&
             request.ownership_namespace_digest==m_record.ownership_namespace_digest &&
             request.manifest_digest==m_record.manifest_digest;
   }

public:
   SWV5S5_ReferenceGenesis(void):m_operational_state_exists(false)
   {
      ZeroMemory(m_record);
      ArrayInitialize(m_domain_initialized,false);
   }

   bool BeginProvisioning(const SWV5S5_ReferenceGenesisRequest &request,bool &idempotent)
   {
      idempotent=false;
      if(m_record.state==SWV5S5_GENESIS_READY_FOR_RECONCILIATION)
      {
         idempotent=SameRequest(request);
         return idempotent;
      }
      if(m_record.state==SWV5S5_GENESIS_PROVISIONING || m_operational_state_exists ||
         request.persistence_namespace_digest=="" || request.ownership_namespace_digest=="" ||
         request.genesis_id=="" || request.genesis_policy_id=="" ||
         request.genesis_policy_version!=1 || request.operator_identity=="" ||
         request.authority_component!=SWV5_COMPONENT_AUTHORITY_OPERATOR ||
         request.authority_source!=SWV5_AUTHORITY_OPERATOR ||
         request.creation_clock_id=="" || request.creation_clock_sequence==0 ||
         request.created_at<=0 || request.manifest_digest=="")
         return false;
      m_record.state=SWV5S5_GENESIS_PROVISIONING;
      m_record.genesis_id=request.genesis_id;
      m_record.persistence_namespace_digest=request.persistence_namespace_digest;
      m_record.ownership_namespace_digest=request.ownership_namespace_digest;
      m_record.manifest_digest=request.manifest_digest;
      m_record.generation=1;
      m_record.revision=1;
      m_record.hard_kill_active=true;
      m_record.hard_kill_latch_generation=1;
      m_record.hard_kill_release_generation=0;
      m_record.bootstrap_clean_shutdown=false;
      m_record.reconciliation_required=true;
      return true;
   }

   bool InitializeDomain(const SWV5S5_ReferenceDomain domain,
                         const string manifest_digest)
   {
      int index=(int)domain;
      if(m_record.state!=SWV5S5_GENESIS_PROVISIONING || index<0 || index>=7 ||
         manifest_digest!=m_record.manifest_digest || m_domain_initialized[index])
         return false;
      m_domain_initialized[index]=true;
      return true;
   }

   bool Finalize(void)
   {
      if(m_record.state!=SWV5S5_GENESIS_PROVISIONING)
         return false;
      for(int i=0;i<7;i++)
         if(!m_domain_initialized[i])
            return false;
      m_record.state=SWV5S5_GENESIS_READY_FOR_RECONCILIATION;
      m_record.revision++;
      return true;
   }

   void MarkOperationalStateExists(void) { m_operational_state_exists=true; }
   SWV5S5_ReferenceGenesisRecord Current(void) const { return m_record; }
};

#endif
