#ifndef SW_V5_S5_REFERENCE_PUBLICATION_STORE_MQH
#define SW_V5_S5_REFERENCE_PUBLICATION_STORE_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
#include "SW_V5_S5_FakeTransactionalStore.mqh"

class SWV5S5_ReferencePublicationStore
{
private:
   SWV5S5_FakeTransactionalStore m_store;
   SWV5S5_RequestSetPublicationAuthority m_request_authority;
   SWV5_PendingRequest m_requests[];
   SWV5_PersistedCheckpoint m_checkpoint;
   SWV5S5_CheckpointPublicationAuthority m_checkpoint_authority;
   ulong m_request_store_revision;
   ulong m_checkpoint_store_revision;
   bool m_initialized;

   bool RequestPayload(const SWV5_PendingRequest &requests[],string &payload,string &set_digest,
                        string &row_digest,string &scope,string &fence) const
   {
      string field;
      if(!SWV5S5_DeriveCompleteRequestSetDigest(requests,set_digest) ||
         !SWV5S5_ReferenceCanonicalNamespaceDigest(m_request_authority.persistence_namespace,scope) ||
         !SWV5S5_ReferenceCanonicalFenceDigest(m_request_authority.ownership_fence,fence) ||
         !SWV5S5_CanonicalString("set_digest",set_digest,field)) return false;
      payload=field;
      for(int i=0;i<ArraySize(requests);i++)
      {
         string c; if(!SWV5S5_CanonicalPendingRequest(requests[i],c) || !SWV5S5_CanonicalIndexed("request",(ulong)i,c,field)) return false;
         payload+=field;
      }
      return SWV5S5_ReferenceCanonicalPayloadDigest(SWV5S5_REF_DOMAIN_REQUEST_SET,payload,row_digest);
   }

   bool CheckpointPayload(const SWV5_PersistedCheckpoint &checkpoint,string &payload,string &digest,
                          string &scope,string &fence) const
   {
      string projection,field;
      if(!SWV5S5_DeriveCheckpointProjection(checkpoint,projection) ||
         !SWV5S5_ReferenceCanonicalNamespaceDigest(checkpoint.header.persistence_namespace,scope) ||
         !SWV5S5_ReferenceCanonicalFenceDigest(checkpoint.header.ownership_fence,fence) ||
         !SWV5S5_CanonicalString("projection",projection,field)) return false;
      payload=field; return SWV5S5_ReferenceCanonicalPayloadDigest(SWV5S5_REF_DOMAIN_CHECKPOINT,payload,digest);
   }

public:
   SWV5S5_ReferencePublicationStore(void):m_request_store_revision(1),m_checkpoint_store_revision(1),m_initialized(false) { ZeroMemory(m_checkpoint); }

   bool Initialize(const SWV5S5_RequestSetPublicationAuthority &request_authority,
                   const SWV5_PendingRequest &requests[],const SWV5S5_CheckpointPublicationAuthority &checkpoint_authority,
                   const SWV5_PersistedCheckpoint &checkpoint)
   {
      if(m_initialized) return false;
      string payload,set_digest,digest,scope,fence; SWV5S5_ReferenceDomainRow row;
      m_request_authority=request_authority; m_checkpoint_authority=checkpoint_authority;
      if(!RequestPayload(requests,payload,set_digest,digest,scope,fence) ||
         request_authority.current_complete_set_digest!=set_digest ||
         request_authority.current_set_header.request_set_digest!=set_digest ||
         request_authority.current_set_header.request_count!=(uint)ArraySize(requests) ||
         checkpoint.pending_request_set.request_set_digest!=set_digest ||
         checkpoint.pending_request_set.request_index_revision!=request_authority.current_set_header.request_index_revision ||
         checkpoint.pending_request_set.record_sequence!=request_authority.current_set_header.record_sequence) return false;
      ZeroMemory(row); row.domain=SWV5S5_REF_DOMAIN_REQUEST_SET; row.persistence_namespace_digest=scope; row.store_revision=1;
      row.authority_fence_digest=fence; row.payload=payload; row.payload_digest=digest;
      if(!m_store.Seed(row)) return false;
      if(!CheckpointPayload(checkpoint,payload,digest,scope,fence)) return false;
      ZeroMemory(row); row.domain=SWV5S5_REF_DOMAIN_CHECKPOINT; row.persistence_namespace_digest=scope; row.store_revision=1;
      row.authority_fence_digest=fence; row.payload=payload; row.payload_digest=digest;
      if(!m_store.Seed(row)) return false;
      for(int i=0;i<ArraySize(requests);i++){ int n=ArraySize(m_requests); ArrayResize(m_requests,n+1); m_requests[n]=requests[i]; }
      m_checkpoint=checkpoint; m_initialized=true; return true;
   }

   bool TryPublishRequestSet(const SWV5S5_RequestSetPublicationProposal &proposal,
                             const SWV5_PendingRequest &proposed_requests[],
                             SWV5S5_FencedPublicationResult &result,
                             SWV5S5_ReferenceTransactionResult &transaction)
   {
      if(!m_initialized || !SWV5S5_EvaluateRequestSetPublication(m_request_authority,m_requests,proposal,proposed_requests,result)) return false;
      string current_payload,current_set_digest,current_row_digest,current_scope,current_fence;
      string proposed_payload,proposed_set_digest,proposed_row_digest,p_scope,p_fence;
      SWV5S5_ReferenceDomainRow current,row,readback;
      if(!RequestPayload(m_requests,current_payload,current_set_digest,current_row_digest,current_scope,current_fence) ||
         !RequestPayload(proposed_requests,proposed_payload,proposed_set_digest,proposed_row_digest,p_scope,p_fence) ||
         current_set_digest!=m_request_authority.current_complete_set_digest ||
         proposal.proposed_complete_set_digest!=proposed_set_digest ||
         proposal.expected_store_revision!=(string)m_request_store_revision ||
         !m_store.Load(SWV5S5_REF_DOMAIN_REQUEST_SET,current) || current.payload!=current_payload ||
         current.payload_digest!=current_row_digest || current.persistence_namespace_digest!=current_scope ||
         current.authority_fence_digest!=current_fence) return false;
      ZeroMemory(row); row.domain=SWV5S5_REF_DOMAIN_REQUEST_SET; row.persistence_namespace_digest=p_scope;
      row.store_revision=current.store_revision+1; row.authority_fence_digest=p_fence; row.payload=proposed_payload;
      row.payload_digest=proposed_row_digest;
      if(!m_store.CompareAndSet(row.domain,current_scope,current.store_revision,current.payload_digest,current.authority_fence_digest,row,
                                SWV5S5_REF_FAULT_NONE,transaction)) return false;
      ArrayResize(m_requests,ArraySize(proposed_requests)); for(int i=0;i<ArraySize(proposed_requests);i++) m_requests[i]=proposed_requests[i];
      m_request_authority.current_set_header=proposal.proposed_set_header; m_request_authority.current_complete_set_digest=proposed_set_digest;
      m_request_authority.store_revision=proposal.proposed_store_revision; m_request_store_revision++;
      string verify_payload,verify_set,verify_row,verify_scope,verify_fence;
      return m_store.Load(SWV5S5_REF_DOMAIN_REQUEST_SET,readback) && readback.payload==row.payload &&
         RequestPayload(m_requests,verify_payload,verify_set,verify_row,verify_scope,verify_fence) &&
         verify_payload==readback.payload && verify_row==readback.payload_digest &&
         verify_set==m_request_authority.current_complete_set_digest;
   }

   bool TryPublishCheckpoint(const SWV5S5_CheckpointPublicationProposal &proposal,
                             SWV5S5_FencedPublicationResult &result,
                             SWV5S5_ReferenceTransactionResult &transaction)
   {
      if(!m_initialized) return false;
      // Authoritative Request Set reload is intentionally before proposal
      // evaluation. A caller-provided digest cannot substitute for this row.
      string set_payload,set_digest,set_row_digest,set_scope,set_fence;
      SWV5S5_ReferenceDomainRow set_row;
      if(!RequestPayload(m_requests,set_payload,set_digest,set_row_digest,set_scope,set_fence) ||
         !m_store.Load(SWV5S5_REF_DOMAIN_REQUEST_SET,set_row) || set_row.payload!=set_payload ||
         set_row.payload_digest!=set_row_digest || set_digest!=m_request_authority.current_complete_set_digest ||
         proposal.proposed_checkpoint.pending_request_set.request_set_digest!=set_digest ||
         proposal.proposed_checkpoint.pending_request_set.request_count!=(uint)ArraySize(m_requests) ||
         proposal.proposed_checkpoint.pending_request_set.request_index_revision!=m_request_authority.current_set_header.request_index_revision ||
         proposal.proposed_checkpoint.pending_request_set.record_sequence!=m_request_authority.current_set_header.record_sequence ||
         !SWV5S5_EvaluateCheckpointPublication(m_checkpoint_authority,proposal,result)) return false;
      string payload,digest,scope,fence; SWV5S5_ReferenceDomainRow current,row,readback;
      if(!CheckpointPayload(m_checkpoint,payload,digest,scope,fence) ||
         !m_store.Load(SWV5S5_REF_DOMAIN_CHECKPOINT,current) ||
         current.payload!=payload || current.payload_digest!=digest ||
         proposal.expected_store_revision!=(string)m_checkpoint_store_revision) return false;
      string proposed_payload,proposed_digest,p_scope,p_fence;
      if(!CheckpointPayload(proposal.proposed_checkpoint,proposed_payload,proposed_digest,p_scope,p_fence)) return false;
      ZeroMemory(row); row.domain=SWV5S5_REF_DOMAIN_CHECKPOINT; row.persistence_namespace_digest=p_scope;
      row.store_revision=current.store_revision+1; row.authority_fence_digest=p_fence; row.payload=proposed_payload; row.payload_digest=proposed_digest;
      if(!m_store.CompareAndSet(row.domain,scope,current.store_revision,current.payload_digest,current.authority_fence_digest,row,
                                SWV5S5_REF_FAULT_NONE,transaction)) return false;
      m_checkpoint=proposal.proposed_checkpoint; m_checkpoint_store_revision++;
      m_checkpoint_authority.current_header=m_checkpoint.header;
      m_checkpoint_authority.current_checkpoint_projection_digest=proposal.proposed_checkpoint_projection_digest;
      return m_store.Load(SWV5S5_REF_DOMAIN_CHECKPOINT,readback) && readback.payload==row.payload &&
         readback.payload_digest==row.payload_digest;
   }

   bool RequestSetDeepCopyIntact(const SWV5_PendingRequest &caller[]) const
   {
      if(ArraySize(caller)!=ArraySize(m_requests)) return false;
      for(int i=0;i<ArraySize(caller);i++){ string a,b; if(!SWV5S5_CanonicalPendingRequest(caller[i],a) || !SWV5S5_CanonicalPendingRequest(m_requests[i],b) || a!=b) return false; }
      return true;
   }

   bool LoadRequestSet(SWV5S5_RequestSetPublicationAuthority &authority,SWV5_PendingRequest &requests[]) const
   {
      string payload,set_digest,row_digest,scope,fence; SWV5S5_ReferenceDomainRow row;
      if(!m_initialized || !RequestPayload(m_requests,payload,set_digest,row_digest,scope,fence) ||
         !m_store.Load(SWV5S5_REF_DOMAIN_REQUEST_SET,row) || row.payload!=payload || row.payload_digest!=row_digest ||
         set_digest!=m_request_authority.current_complete_set_digest) return false;
      authority=m_request_authority; ArrayResize(requests,ArraySize(m_requests));
      for(int i=0;i<ArraySize(m_requests);i++) requests[i]=m_requests[i];
      return true;
   }

   bool LoadCheckpoint(SWV5_PersistedCheckpoint &checkpoint) const
   {
      string payload,digest,scope,fence; SWV5S5_ReferenceDomainRow row;
      if(!m_initialized || !CheckpointPayload(m_checkpoint,payload,digest,scope,fence) ||
         !m_store.Load(SWV5S5_REF_DOMAIN_CHECKPOINT,row) || row.payload!=payload || row.payload_digest!=digest) return false;
      checkpoint=m_checkpoint; return true;
   }
};

#endif
