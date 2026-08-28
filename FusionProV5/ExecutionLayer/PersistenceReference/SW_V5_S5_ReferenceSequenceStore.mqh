#ifndef SW_V5_S5_REFERENCE_SEQUENCE_STORE_MQH
#define SW_V5_S5_REFERENCE_SEQUENCE_STORE_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
#include "SW_V5_S5_FakeTransactionalStore.mqh"

bool SWV5S5_ReferenceCanonicalSequence(const SWV5S5_RequestSequenceAuthority &authority,
                                       const SWV5S5_RequestSequenceIndexEntry &entries[],
                                       string &canonical,string &namespace_digest,string &fence_digest)
{
   string ad,index,scope,fence,revision,hwm,count,f;
   if(!SWV5S5_DeriveSequenceAuthorityDigest(authority,entries,ad) || authority.authority_digest!=ad ||
      !SWV5S5_DeriveSequenceIndexDigest(entries,index) || authority.reservation_index_digest!=index ||
      !SWV5S5_ReferenceCanonicalNamespaceDigest(authority.persistence_namespace,namespace_digest) ||
      !SWV5S5_ReferenceCanonicalFenceDigest(authority.ownership_fence,fence_digest) ||
      !SWV5S5_CanonicalNamespace("scope",authority.persistence_namespace,scope) ||
      !SWV5S5_CanonicalFence("fence",authority.ownership_fence,fence) ||
      !SWV5S5_CanonicalUInt("allocator_revision",authority.allocator_revision,revision) ||
      !SWV5S5_CanonicalUInt("high_watermark",authority.request_sequence_high_watermark,hwm) ||
      !SWV5S5_CanonicalUInt("reservation_count",authority.reservation_count,count) ||
      !SWV5S5_CanonicalString("authority_digest",ad,f)) return false;
   canonical=scope+fence+revision+hwm+count+f+index;
   return true;
}

class SWV5S5_ReferenceSequenceStore
{
private:
   SWV5S5_FakeTransactionalStore m_store;
   SWV5S5_RequestSequenceAuthority m_authority;
   SWV5S5_RequestSequenceIndexEntry m_entries[];
   bool m_initialized;

   bool BuildRow(const SWV5S5_RequestSequenceAuthority &authority,
                 const SWV5S5_RequestSequenceIndexEntry &entries[],const ulong revision,
                 SWV5S5_ReferenceDomainRow &row) const
   {
      string canonical,scope,fence,digest;
      if(!SWV5S5_ReferenceCanonicalSequence(authority,entries,canonical,scope,fence) ||
         !SWV5S5_ReferenceCanonicalPayloadDigest(SWV5S5_REF_DOMAIN_SEQUENCE,canonical,digest)) return false;
      ZeroMemory(row); row.domain=SWV5S5_REF_DOMAIN_SEQUENCE; row.persistence_namespace_digest=scope;
      row.store_revision=revision; row.authority_fence_digest=fence; row.payload=canonical; row.payload_digest=digest;
      return true;
   }

public:
   SWV5S5_ReferenceSequenceStore(void):m_initialized(false) { ZeroMemory(m_authority); }

   bool Initialize(const SWV5S5_RequestSequenceAuthority &authority,
                   const SWV5S5_RequestSequenceIndexEntry &entries[])
   {
      if(m_initialized) return false;
      SWV5S5_ReferenceDomainRow row;
      if(!BuildRow(authority,entries,1,row) || !m_store.Seed(row)) return false;
      m_authority=authority; ArrayResize(m_entries,ArraySize(entries));
      for(int i=0;i<ArraySize(entries);i++) m_entries[i]=entries[i];
      m_initialized=true; return true;
   }

   bool Reserve(const SWV5S5_RequestSequenceReservation &proposal,
                SWV5S5_RequestSequenceResult &result,
                SWV5S5_ReferenceTransactionResult &transaction)
   {
      ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
      result.logical_correlation_id=proposal.logical_correlation_id;
      if(!m_initialized) return false;
      SWV5S5_RequestSequenceResult prepared;
      if(!SWV5S5_PrepareSequenceReservation(m_authority,m_entries,proposal,prepared)) { result=prepared; return false; }
      int existing=SWV5S5_FindSequenceReservation(m_entries,proposal.logical_correlation_id);
      if(existing>=0)
      {
         result=prepared; result.disposition=SWV5S5_SEQUENCE_EXISTING_IDEMPOTENT;
         // Expected revision was already proved by PrepareSequenceReservation.
         transaction.disposition=SWV5S5_REF_COMMITTED; transaction.this_transaction_won=false;
         transaction.durable_state_matches_proposal=true; transaction.durable_revision=0;
         return true;
      }
      SWV5S5_RequestSequenceAuthority proposed=m_authority;
      SWV5S5_RequestSequenceIndexEntry old_entries[]; ArrayResize(old_entries,ArraySize(m_entries));
      for(int oi=0;oi<ArraySize(m_entries);oi++) old_entries[oi]=m_entries[oi];
      SWV5S5_RequestSequenceIndexEntry next;
      next.logical_correlation_id=proposal.logical_correlation_id; next.reserved_sequence=proposal.proposed_sequence;
      next.reservation_revision=proposal.proposed_allocator_revision; next.binding_digest=proposal.binding_digest;
      int n=ArraySize(m_entries); ArrayResize(m_entries,n+1); m_entries[n]=next;
      proposed.allocator_revision=proposal.proposed_allocator_revision;
      proposed.request_sequence_high_watermark=proposal.proposed_sequence;
      proposed.reservation_count=(uint)(n+1);
      if(!SWV5S5_DeriveSequenceIndexDigest(m_entries,proposed.reservation_index_digest) ||
         !SWV5S5_DeriveSequenceAuthorityDigest(proposed,m_entries,proposed.authority_digest)) { ArrayResize(m_entries,n); return false; }
      SWV5S5_ReferenceDomainRow current,row; string canonical,scope,fence;
      if(!m_store.Load(SWV5S5_REF_DOMAIN_SEQUENCE,current) ||
         !SWV5S5_ReferenceCanonicalSequence(m_authority,old_entries,canonical,scope,fence)) { ArrayResize(m_entries,n); return false; }
      // Rebuild current row from the pre-mutation state.
      if(!BuildRow(m_authority,old_entries,current.store_revision,current)) { ArrayResize(m_entries,n); return false; }
      if(!BuildRow(proposed,m_entries,current.store_revision+1,row)) { ArrayResize(m_entries,n); return false; }
      const bool committed=m_store.CompareAndSet(SWV5S5_REF_DOMAIN_SEQUENCE,scope,current.store_revision,
         current.payload_digest,current.authority_fence_digest,row,SWV5S5_REF_FAULT_NONE,transaction);
      if(!committed || !transaction.this_transaction_won) { ArrayResize(m_entries,ArraySize(old_entries)); for(int ri=0;ri<ArraySize(old_entries);ri++) m_entries[ri]=old_entries[ri]; return false; }
      m_authority=proposed;
      result=prepared; result.disposition=SWV5S5_SEQUENCE_RESERVED_NEW;
      result.resulting_authority_digest=proposed.authority_digest; return true;
   }

   ulong Revision(void) const { return m_authority.allocator_revision; }
   ulong HighWatermark(void) const { return m_authority.request_sequence_high_watermark; }
   int Count(void) const { return ArraySize(m_entries); }
};

#endif
