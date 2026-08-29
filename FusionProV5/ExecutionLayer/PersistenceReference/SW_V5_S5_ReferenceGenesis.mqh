#ifndef SW_V5_S5_REFERENCE_GENESIS_MQH
#define SW_V5_S5_REFERENCE_GENESIS_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// Genesis provisions six typed bootstrap domains. Every domain is validated,
// canonically bound to the immutable Genesis envelope, stored, and read back.

#include "SW_V5_S5_ReferenceLeaseStore.mqh"

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

// Typed empty Submission/Claim journal bootstrap state. It is deliberately
// distinct from a SubmissionAuthorityRecord, which requires a valid permit.
struct SWV5S5_ReferenceSubmissionJournal
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   string genesis_id;
   string manifest_digest;
   uint record_count;
   ulong journal_revision;
   string journal_digest;
};

bool SWV5S5_ReferenceGenesisImmutableCanonical(const SWV5S5_ReferenceGenesisRequest &request,
                                                string &canonical)
{
   string f; canonical="";
   if(!SWV5S5_IsCandidateVersion(request.contract_version) || request.genesis_id=="" ||
      request.genesis_policy_id=="" || request.genesis_policy_version==0 ||
      request.operator_identity.operator_id=="" || request.operator_identity.authority_role=="" ||
      request.operator_identity.authentication_reference=="" || request.operator_identity.authenticated_at<=0 ||
      request.authority_component!=SWV5_COMPONENT_AUTHORITY_OPERATOR || request.authority_source!=SWV5_AUTHORITY_OPERATOR ||
      request.creation_clock_id=="" || request.creation_clock_authority==SWV5_TIME_AUTHORITY_NONE ||
      request.creation_clock_sequence==0 || request.created_at<=0 || request.manifest_digest=="" ||
      request.ownership_fence.owner.instance_id!="" || request.ownership_fence.owner.process_fingerprint!="" ||
      request.ownership_fence.owner.started_at!=0 || request.ownership_fence.lease_version!=0 ||
      request.ownership_fence.takeover_generation!=0 || request.ownership_fence.fencing_token_digest!="") return false;
#define SWV5S5_GI_ADD(x) if(!(x)) return false; else canonical+=f
   SWV5S5_GI_ADD(SWV5S5_CanonicalContractVersion("contract_version",request.contract_version,f));
   SWV5S5_GI_ADD(SWV5S5_CanonicalNamespace("persistence_namespace",request.persistence_namespace,f));
   SWV5S5_GI_ADD(SWV5S5_CanonicalFence("ownership_fence",request.ownership_fence,f));
   SWV5S5_GI_ADD(SWV5S5_CanonicalString("genesis_id",request.genesis_id,f));
   SWV5S5_GI_ADD(SWV5S5_CanonicalString("genesis_policy_id",request.genesis_policy_id,f));
   SWV5S5_GI_ADD(SWV5S5_CanonicalUInt("genesis_policy_version",request.genesis_policy_version,f));
   SWV5S5_GI_ADD(SWV5S5_CanonicalOperatorIdentity("operator_identity",request.operator_identity,f));
   SWV5S5_GI_ADD(SWV5S5_CanonicalInt("authority_component",request.authority_component,f));
   SWV5S5_GI_ADD(SWV5S5_CanonicalInt("authority_source",request.authority_source,f));
   SWV5S5_GI_ADD(SWV5S5_CanonicalString("creation_clock_id",request.creation_clock_id,f));
   SWV5S5_GI_ADD(SWV5S5_CanonicalInt("creation_clock_authority",request.creation_clock_authority,f));
   SWV5S5_GI_ADD(SWV5S5_CanonicalUInt("creation_clock_sequence",request.creation_clock_sequence,f));
   SWV5S5_GI_ADD(SWV5S5_CanonicalDatetime("created_at",request.created_at,f));
   SWV5S5_GI_ADD(SWV5S5_CanonicalString("manifest_digest",request.manifest_digest,f));
#undef SWV5S5_GI_ADD
   return true;
}

bool SWV5S5_ReferenceGenesisRecordImmutableCanonical(const SWV5S5_ReferenceGenesisRecord &record,
                                                      string &canonical)
{
   SWV5S5_ReferenceGenesisRequest request;
   request.contract_version=record.contract_version; request.persistence_namespace=record.persistence_namespace;
   request.ownership_fence=record.ownership_fence; request.genesis_id=record.genesis_id;
   request.genesis_policy_id=record.genesis_policy_id; request.genesis_policy_version=record.genesis_policy_version;
   request.operator_identity=record.operator_identity; request.authority_component=record.authority_component;
   request.authority_source=record.authority_source; request.creation_clock_id=record.creation_clock_id;
   request.creation_clock_authority=record.creation_clock_authority;
   request.creation_clock_sequence=record.creation_clock_sequence; request.created_at=record.created_at;
   request.manifest_digest=record.manifest_digest;
   return SWV5S5_ReferenceGenesisImmutableCanonical(request,canonical);
}

bool SWV5S5_ReferenceGenesisCanonical(const SWV5S5_ReferenceGenesisRecord &record,string &payload,
                                      string &scope,string &fence)
{
   string immutable,f;
   if(!SWV5S5_ReferenceGenesisRecordImmutableCanonical(record,immutable) ||
      !SWV5S5_ReferenceCanonicalNamespaceDigest(record.persistence_namespace,scope) ||
      !SWV5S5_ReferenceCanonicalFenceDigest(record.ownership_fence,fence) ||
      record.state<SWV5S5_GENESIS_PROVISIONING || record.state>SWV5S5_GENESIS_READY_FOR_RECONCILIATION ||
      record.generation==0 || record.revision==0 || record.hard_kill_state!=SWV5_HARD_KILL_ACTIVE ||
      record.hard_kill_latch_generation==0 || record.hard_kill_release_generation!=0) return false;
   payload=immutable;
#define SWV5S5_GR_ADD(x) if(!(x)) return false; else payload+=f
   SWV5S5_GR_ADD(SWV5S5_CanonicalInt("state",record.state,f));
   SWV5S5_GR_ADD(SWV5S5_CanonicalUInt("generation",record.generation,f));
   SWV5S5_GR_ADD(SWV5S5_CanonicalUInt("revision",record.revision,f));
   SWV5S5_GR_ADD(SWV5S5_CanonicalInt("hard_kill_state",record.hard_kill_state,f));
   SWV5S5_GR_ADD(SWV5S5_CanonicalUInt("hard_kill_latch_generation",record.hard_kill_latch_generation,f));
   SWV5S5_GR_ADD(SWV5S5_CanonicalUInt("hard_kill_release_generation",record.hard_kill_release_generation,f));
#undef SWV5S5_GR_ADD
   return true;
}

bool SWV5S5_ReferenceSubmissionJournalPreimage(const SWV5S5_ReferenceSubmissionJournal &journal,
                                                string &canonical)
{
   string f; canonical="";
   if(!SWV5S5_IsCandidateVersion(journal.contract_version) || journal.genesis_id=="" ||
      journal.manifest_digest=="" || journal.record_count!=0 || journal.journal_revision!=1) return false;
#define SWV5S5_SJ_ADD(x) if(!(x)) return false; else canonical+=f
   SWV5S5_SJ_ADD(SWV5S5_CanonicalContractVersion("contract_version",journal.contract_version,f));
   SWV5S5_SJ_ADD(SWV5S5_CanonicalNamespace("persistence_namespace",journal.persistence_namespace,f));
   SWV5S5_SJ_ADD(SWV5S5_CanonicalFence("ownership_fence",journal.ownership_fence,f));
   SWV5S5_SJ_ADD(SWV5S5_CanonicalString("genesis_id",journal.genesis_id,f));
   SWV5S5_SJ_ADD(SWV5S5_CanonicalString("manifest_digest",journal.manifest_digest,f));
   SWV5S5_SJ_ADD(SWV5S5_CanonicalUInt("record_count",journal.record_count,f));
   SWV5S5_SJ_ADD(SWV5S5_CanonicalUInt("journal_revision",journal.journal_revision,f));
#undef SWV5S5_SJ_ADD
   return true;
}

bool SWV5S5_ReferenceSubmissionJournalCanonical(const SWV5S5_ReferenceSubmissionJournal &journal,
                                                 string &canonical)
{
   string preimage,expected,f;
   if(!SWV5S5_ReferenceSubmissionJournalPreimage(journal,preimage) ||
      !SWV5S5_DomainDigest("SWV5-S5-PHASE-D1-SUBMISSION-JOURNAL",preimage,expected) ||
      journal.journal_digest!=expected ||
      !SWV5S5_CanonicalString("journal_digest",journal.journal_digest,f)) return false;
   canonical=preimage+f; return true;
}

class SWV5S5_ReferenceGenesis
{
private:
   SWV5S5_FakeTransactionalStore m_store;
   SWV5S5_ReferenceGenesisRecord m_record;
   bool m_has_genesis;
   SWV5_InstanceLease m_lease;
   SWV5S5_IngressLedgerHeader m_ledger_header;
   SWV5S5_IngressLedgerIndexEntry m_ledger_index[];
   SWV5S5_IngressLedgerRecord m_ledger_records[];
   SWV5S5_RequestSequenceAuthority m_sequence_authority;
   SWV5S5_RequestSequenceIndexEntry m_sequence_index[];
   SWV5S5_ReferenceSubmissionJournal m_submission_journal;
   SWV5S5_RequestSetPublicationAuthority m_request_authority;
   SWV5_PendingRequest m_requests[];
   SWV5_PersistedCheckpoint m_checkpoint;

   bool BoundPayload(const string typed_state,string &payload) const
   {
      string f; payload="";
      if(typed_state=="" || !SWV5S5_CanonicalString("genesis_id",m_record.genesis_id,f)) return false; payload+=f;
      if(!SWV5S5_CanonicalUInt("genesis_generation",m_record.generation,f)) return false; payload+=f;
      if(!SWV5S5_CanonicalString("manifest_digest",m_record.manifest_digest,f)) return false; payload+=f;
      if(!SWV5S5_CanonicalNested("typed_state",typed_state,f)) return false; payload+=f;
      return true;
   }

   bool SeedDomain(const SWV5S5_ReferenceDomain domain,const string typed_state)
   {
      string payload,scope,fence;
      if(!m_has_genesis || m_record.state!=SWV5S5_GENESIS_PROVISIONING ||
         domain==SWV5S5_REF_DOMAIN_GENESIS || !BoundPayload(typed_state,payload) ||
         !SWV5S5_ReferenceCanonicalNamespaceDigest(m_record.persistence_namespace,scope) ||
         !SWV5S5_ReferenceCanonicalFenceDigest(m_record.ownership_fence,fence)) return false;
      SWV5S5_ReferenceDomainRow row,readback; ZeroMemory(row); row.domain=domain;
      row.persistence_namespace_digest=scope; row.authority_fence_digest=fence;
      row.store_revision=1; row.payload=payload;
      if(!SWV5S5_ReferenceCanonicalPayloadDigest(domain,payload,row.payload_digest) || !m_store.Seed(row) ||
         !m_store.Load(domain,readback)) return false;
      return SWV5S5_ReferenceRowIntegrity(readback) && readback.payload==row.payload &&
         readback.payload_digest==row.payload_digest && readback.persistence_namespace_digest==scope &&
         readback.authority_fence_digest==fence && readback.store_revision==1;
   }

   bool LoadDomain(const SWV5S5_ReferenceDomain domain,const string typed_state) const
   {
      string payload,scope,fence; SWV5S5_ReferenceDomainRow row;
      if(!BoundPayload(typed_state,payload) || !m_store.Load(domain,row) || !SWV5S5_ReferenceRowIntegrity(row) ||
         !SWV5S5_ReferenceCanonicalNamespaceDigest(m_record.persistence_namespace,scope) ||
         !SWV5S5_ReferenceCanonicalFenceDigest(m_record.ownership_fence,fence)) return false;
      return row.payload==payload && row.persistence_namespace_digest==scope &&
         row.authority_fence_digest==fence && row.store_revision==1;
   }

   bool LeaseCanonical(const SWV5_InstanceLease &lease,string &canonical) const
   {
      string scope,fence;
      return SWV5S5_ReferenceCanonicalLease(lease,canonical,scope,fence) &&
         SWV5S5_IsCandidateVersion(lease.contract_version) &&
         lease.status==SWV5_LOCK_UNCLAIMED && lease.fence.owner.instance_id=="" &&
         lease.fence.owner.process_fingerprint=="" && lease.fence.owner.started_at==0 &&
         lease.fence.fencing_token_digest=="" && lease.fence.lease_version==0 &&
         lease.fence.takeover_generation==0 && lease.heartbeat_sequence==0 &&
         SWV5S5_EqualFence(lease.fence,m_record.ownership_fence) &&
         SWV5S5_ReferenceOwnershipKeyEqual(lease.fence.ownership_namespace,
                                            m_record.persistence_namespace.ownership_namespace);
   }

   bool SubmissionCanonical(const SWV5S5_ReferenceSubmissionJournal &journal,string &canonical) const
   {
      return SWV5S5_ReferenceSubmissionJournalCanonical(journal,canonical) &&
         SWV5S5_EqualNamespace(journal.persistence_namespace,m_record.persistence_namespace) &&
         SWV5S5_EqualFence(journal.ownership_fence,m_record.ownership_fence) &&
         journal.genesis_id==m_record.genesis_id && journal.manifest_digest==m_record.manifest_digest;
   }

   bool LedgerCanonical(const SWV5S5_IngressLedgerHeader &header,
                        const SWV5S5_IngressLedgerIndexEntry &index[],
                        const SWV5S5_IngressLedgerRecord &records[],string &canonical) const
   {
      string header_digest,index_digest,f; canonical="";
      if(!SWV5S5_IsCandidateVersion(header.contract_version) ||
         header.policy_id=="" ||
         !SWV5S5_EqualNamespace(header.persistence_namespace,m_record.persistence_namespace) ||
         !SWV5S5_EqualFence(header.ownership_fence,m_record.ownership_fence) ||
         ArraySize(index)!=0 || ArraySize(records)!=0 || header.membership_count!=0 ||
         header.highest_accepted_publication_sequence!=0 || header.revision!=1 ||
         header.previous_revision!=0 || header.compaction_generation!=0 ||
         !SWV5S5_DeriveLedgerIndexDigest(index,index_digest) ||
         !SWV5S5_DeriveLedgerHeaderDigest(header,index,header_digest) || header.ledger_digest!=header_digest ||
         !SWV5S5_ValidateLedgerRecordIndexLinkage(index,records)) return false;
      if(!SWV5S5_CanonicalString("ledger_header_digest",header_digest,f)) return false; canonical+=f;
      if(!SWV5S5_CanonicalString("ledger_index_digest",index_digest,f)) return false; canonical+=f;
      if(!SWV5S5_CanonicalUInt("ledger_record_count",ArraySize(records),f)) return false; canonical+=f;
      return true;
   }

   bool SequenceCanonical(const SWV5S5_RequestSequenceAuthority &authority,
                          const SWV5S5_RequestSequenceIndexEntry &index[],string &canonical) const
   {
      string authority_digest,index_digest,f; canonical="";
      if(!SWV5S5_IsCandidateVersion(authority.contract_version) ||
         authority.policy_id=="" || authority.policy_version==0 ||
         !SWV5S5_EqualNamespace(authority.persistence_namespace,m_record.persistence_namespace) ||
         !SWV5S5_EqualFence(authority.ownership_fence,m_record.ownership_fence) || ArraySize(index)!=0 ||
         authority.allocator_revision!=1 || authority.request_sequence_high_watermark!=0 ||
         authority.reservation_count!=0 || !SWV5S5_DeriveSequenceIndexDigest(index,index_digest) ||
         !SWV5S5_DeriveSequenceAuthorityDigest(authority,index,authority_digest) ||
         authority.authority_digest!=authority_digest) return false;
      if(!SWV5S5_CanonicalString("sequence_authority_digest",authority_digest,f)) return false; canonical+=f;
      if(!SWV5S5_CanonicalString("sequence_index_digest",index_digest,f)) return false; canonical+=f;
      return true;
   }

   bool RequestSetCanonical(const SWV5S5_RequestSetPublicationAuthority &authority,
                            const SWV5_PendingRequest &requests[],string &canonical) const
   {
      string set_digest,f; canonical="";
      if(!SWV5S5_IsCandidateVersion(authority.contract_version) ||
         authority.policy_id!=SWV5S5_PUBLICATION_POLICY_ID ||
         authority.policy_version!=SWV5S5_PUBLICATION_POLICY_VERSION ||
         !SWV5S5_EqualNamespace(authority.persistence_namespace,m_record.persistence_namespace) ||
         !SWV5S5_EqualFence(authority.ownership_fence,m_record.ownership_fence) ||
         authority.store_revision=="" || ArraySize(requests)!=0 ||
         !SWV5S5_IsV5Version(authority.current_set_header.contract_version) ||
         authority.current_set_header.request_count!=0 || authority.current_set_header.record_sequence!=1 ||
         authority.current_set_header.request_index_revision=="" ||
         !SWV5S5_DeriveCompleteRequestSetDigest(requests,set_digest) ||
         authority.current_set_header.request_set_digest!=set_digest ||
         authority.current_complete_set_digest!=set_digest) return false;
      if(!SWV5S5_CanonicalString("store_revision",authority.store_revision,f)) return false; canonical+=f;
      if(!SWV5S5_CanonicalString("request_index_revision",authority.current_set_header.request_index_revision,f)) return false; canonical+=f;
      if(!SWV5S5_CanonicalUInt("record_sequence",authority.current_set_header.record_sequence,f)) return false; canonical+=f;
      if(!SWV5S5_CanonicalString("complete_set_digest",set_digest,f)) return false; canonical+=f;
      return true;
   }

   bool CheckpointCanonical(const SWV5_PersistedCheckpoint &checkpoint,string &canonical) const
   {
      string projection,set_digest,f; canonical="";
      if(!SWV5S5_IsV5Version(checkpoint.header.contract_version) ||
         !SWV5S5_EqualNamespace(checkpoint.header.persistence_namespace,m_record.persistence_namespace) ||
         !SWV5S5_EqualFence(checkpoint.header.ownership_fence,m_record.ownership_fence) ||
         checkpoint.header.record_sequence!=1 || checkpoint.header.previous_record_sequence!=0 ||
         checkpoint.header.store_revision=="" || checkpoint.header.payload_digest=="" ||
         checkpoint.header.payload_size==0 || checkpoint.header.written_at<=0 ||
         checkpoint.clean_shutdown || checkpoint.has_latest_pending_request ||
         checkpoint.basket.lifecycle.reconciliation_state!=SWV5_RECONCILIATION_STATE_REQUIRED ||
         checkpoint.pending_request_set.request_count!=0 || checkpoint.pending_request_set.record_sequence!=1 ||
         checkpoint.pending_request_set.request_set_digest!=m_request_authority.current_complete_set_digest ||
         checkpoint.pending_request_set.request_index_revision!=m_request_authority.current_set_header.request_index_revision ||
         checkpoint.hard_kill_state.state!=SWV5_HARD_KILL_ACTIVE ||
         checkpoint.hard_kill_state.latch_id=="" || checkpoint.hard_kill_state.activation_reason=="" ||
         checkpoint.hard_kill_state.activation_authority=="" || checkpoint.hard_kill_state.activated_at<=0 ||
         checkpoint.hard_kill_state.latch_generation!=m_record.hard_kill_latch_generation ||
         checkpoint.hard_kill_state.release_generation!=m_record.hard_kill_release_generation ||
         !SWV5S5_EqualNamespace(checkpoint.hard_kill_state.persistence_namespace,m_record.persistence_namespace) ||
         checkpoint.reconciliation_vector.broker_query_sequence_high_watermark!=0 ||
         checkpoint.reconciliation_vector.request_query_sequence_high_watermark!=0 ||
         checkpoint.reconciliation_vector.pending_request_count!=0 ||
         checkpoint.reconciliation_vector.reconciliation_revision==0 ||
         checkpoint.reconciliation_vector.source_summary_digest=="" ||
         checkpoint.reconciliation_vector.request_set_digest!=checkpoint.pending_request_set.request_set_digest ||
         checkpoint.reconciliation_vector.request_set_revision!=checkpoint.pending_request_set.request_index_revision ||
         !SWV5S5_EqualNamespace(checkpoint.reconciliation_vector.persistence_namespace,m_record.persistence_namespace) ||
         !SWV5S5_EqualFence(checkpoint.reconciliation_vector.ownership_fence,m_record.ownership_fence) ||
         !SWV5S5_DeriveCompleteRequestSetDigest(m_requests,set_digest) ||
         checkpoint.pending_request_set.request_set_digest!=set_digest ||
         !SWV5S5_DeriveCheckpointProjection(checkpoint,projection)) return false;
      if(!SWV5S5_CanonicalString("checkpoint_projection",projection,f)) return false; canonical+=f;
      if(!SWV5S5_CanonicalString("request_set_digest",set_digest,f)) return false; canonical+=f;
      if(!SWV5S5_CanonicalString("hard_kill_genesis_binding",m_record.genesis_id,f)) return false; canonical+=f;
      return true;
   }

public:
   SWV5S5_ReferenceGenesis(void):m_has_genesis(false)
   {
      ZeroMemory(m_record); ZeroMemory(m_lease); ZeroMemory(m_ledger_header);
      ZeroMemory(m_sequence_authority); ZeroMemory(m_submission_journal);
      ZeroMemory(m_request_authority); ZeroMemory(m_checkpoint);
   }

   bool BeginProvisioning(const SWV5S5_ReferenceGenesisRequest &request,bool &idempotent)
   {
      idempotent=false; string requested,current;
      if(!SWV5S5_ReferenceGenesisImmutableCanonical(request,requested)) return false;
      if(m_has_genesis)
      {
         if(!SWV5S5_ReferenceGenesisRecordImmutableCanonical(m_record,current)) return false;
         idempotent=(requested==current); return idempotent;
      }
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
      SWV5S5_ReferenceDomainRow row,readback; ZeroMemory(row); row.domain=SWV5S5_REF_DOMAIN_GENESIS;
      row.persistence_namespace_digest=scope; row.authority_fence_digest=fence; row.store_revision=1; row.payload=payload;
      if(!SWV5S5_ReferenceCanonicalPayloadDigest(row.domain,payload,row.payload_digest) || !m_store.Seed(row) ||
         !m_store.Load(row.domain,readback) || readback.payload!=row.payload || readback.payload_digest!=row.payload_digest) return false;
      m_record=next; m_has_genesis=true; return true;
   }

   bool InitializeLease(const SWV5_InstanceLease &lease)
   {
      string canonical;
      if(!LeaseCanonical(lease,canonical)) return false;
      if(!SeedDomain(SWV5S5_REF_DOMAIN_LEASE,canonical)) return false; m_lease=lease; return true;
   }

   bool InitializeLedger(const SWV5S5_IngressLedgerHeader &header,
                         const SWV5S5_IngressLedgerIndexEntry &index[],
                         const SWV5S5_IngressLedgerRecord &records[])
   {
      string canonical; if(!LedgerCanonical(header,index,records,canonical) ||
         !SeedDomain(SWV5S5_REF_DOMAIN_LEDGER,canonical)) return false;
      m_ledger_header=header; ArrayResize(m_ledger_index,0); ArrayResize(m_ledger_records,0); return true;
   }

   bool InitializeSequence(const SWV5S5_RequestSequenceAuthority &authority,
                           const SWV5S5_RequestSequenceIndexEntry &index[])
   {
      string canonical; if(!SequenceCanonical(authority,index,canonical) ||
         !SeedDomain(SWV5S5_REF_DOMAIN_SEQUENCE,canonical)) return false;
      m_sequence_authority=authority; ArrayResize(m_sequence_index,0); return true;
   }

   bool InitializeSubmission(const SWV5S5_ReferenceSubmissionJournal &journal)
   {
      string canonical;
      if(!SubmissionCanonical(journal,canonical) || !SeedDomain(SWV5S5_REF_DOMAIN_SUBMISSION,canonical)) return false;
      m_submission_journal=journal; return true;
   }

   // TEST-VERIFICATION FAULT INJECTION ONLY. Installs a digest-valid typed
   // journal which intentionally violates the immutable Genesis binding.
   bool InjectDigestValidSubmissionMismatchForVerification(const SWV5S5_ReferenceSubmissionJournal &journal)
   {
      string canonical,payload,scope,fence;
      if(!m_has_genesis || m_record.state!=SWV5S5_GENESIS_PROVISIONING ||
         !SWV5S5_ReferenceSubmissionJournalCanonical(journal,canonical) ||
         SubmissionCanonical(journal,payload) || !BoundPayload(canonical,payload) ||
         !SWV5S5_ReferenceCanonicalNamespaceDigest(m_record.persistence_namespace,scope) ||
         !SWV5S5_ReferenceCanonicalFenceDigest(m_record.ownership_fence,fence)) return false;
      SWV5S5_ReferenceDomainRow row; ZeroMemory(row); row.domain=SWV5S5_REF_DOMAIN_SUBMISSION;
      row.persistence_namespace_digest=scope; row.authority_fence_digest=fence; row.store_revision=1; row.payload=payload;
      if(!SWV5S5_ReferenceCanonicalPayloadDigest(row.domain,row.payload,row.payload_digest) ||
         !m_store.InjectDigestValidRowForVerification(row)) return false;
      m_submission_journal=journal; return true;
   }

   bool InitializeRequestSet(const SWV5S5_RequestSetPublicationAuthority &authority,
                             const SWV5_PendingRequest &requests[])
   {
      string canonical; if(!RequestSetCanonical(authority,requests,canonical) ||
         !SeedDomain(SWV5S5_REF_DOMAIN_REQUEST_SET,canonical)) return false;
      m_request_authority=authority; ArrayResize(m_requests,0); return true;
   }

   bool InitializeCheckpoint(const SWV5_PersistedCheckpoint &checkpoint)
   {
      string canonical; if(!CheckpointCanonical(checkpoint,canonical) ||
         !SeedDomain(SWV5S5_REF_DOMAIN_CHECKPOINT,canonical)) return false;
      m_checkpoint=checkpoint; return true;
   }

   bool Finalize(void)
   {
      if(!m_has_genesis || m_record.state!=SWV5S5_GENESIS_PROVISIONING) return false;
      string lease_state,ledger_state,sequence_state,submission_state,request_state,checkpoint_state;
      if(!LeaseCanonical(m_lease,lease_state) ||
         !LedgerCanonical(m_ledger_header,m_ledger_index,m_ledger_records,ledger_state) ||
         !SequenceCanonical(m_sequence_authority,m_sequence_index,sequence_state) ||
         !SubmissionCanonical(m_submission_journal,submission_state) ||
         !RequestSetCanonical(m_request_authority,m_requests,request_state) ||
         !CheckpointCanonical(m_checkpoint,checkpoint_state) ||
         !LoadDomain(SWV5S5_REF_DOMAIN_LEASE,lease_state) || !LoadDomain(SWV5S5_REF_DOMAIN_LEDGER,ledger_state) ||
         !LoadDomain(SWV5S5_REF_DOMAIN_SEQUENCE,sequence_state) || !LoadDomain(SWV5S5_REF_DOMAIN_SUBMISSION,submission_state) ||
         !LoadDomain(SWV5S5_REF_DOMAIN_REQUEST_SET,request_state) || !LoadDomain(SWV5S5_REF_DOMAIN_CHECKPOINT,checkpoint_state)) return false;
      SWV5S5_ReferenceDomainRow current,proposed; SWV5S5_ReferenceTransactionResult transaction;
      SWV5S5_ReferenceGenesisRecord next=m_record; next.state=SWV5S5_GENESIS_READY_FOR_RECONCILIATION; next.revision++;
      string payload,new_scope,new_fence;
      if(!m_store.Load(SWV5S5_REF_DOMAIN_GENESIS,current) ||
         !SWV5S5_ReferenceGenesisCanonical(next,payload,new_scope,new_fence)) return false;
      ZeroMemory(proposed); proposed.domain=SWV5S5_REF_DOMAIN_GENESIS; proposed.persistence_namespace_digest=new_scope;
      proposed.authority_fence_digest=new_fence; proposed.store_revision=current.store_revision+1; proposed.payload=payload;
      if(!SWV5S5_ReferenceCanonicalPayloadDigest(proposed.domain,payload,proposed.payload_digest) ||
         !m_store.CompareAndSet(proposed.domain,current.persistence_namespace_digest,current.store_revision,
                                current.payload_digest,current.authority_fence_digest,proposed,
                                SWV5S5_REF_FAULT_NONE,transaction) || !transaction.this_transaction_won) return false;
      m_record=next; return true;
   }

   SWV5S5_ReferenceGenesisRecord Current(void) const { return m_record; }
};

#endif
