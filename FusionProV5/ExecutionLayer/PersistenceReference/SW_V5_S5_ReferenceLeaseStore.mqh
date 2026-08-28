#ifndef SW_V5_S5_REFERENCE_LEASE_STORE_MQH
#define SW_V5_S5_REFERENCE_LEASE_STORE_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS

#include "SW_V5_S5_FakeTransactionalStore.mqh"
#include "SW_V5_S5_FakeAuthoritativeClock.mqh"

struct SWV5S5_ReferenceLease
{
   string owner_id;
   string ownership_namespace_digest;
   ulong lease_version;
   ulong takeover_generation;
   string fencing_token_digest;
   ulong store_revision;
   ulong heartbeat_sequence;
   ulong heartbeat_clock_sequence;
   datetime heartbeat_at;
   datetime expires_at;
   bool claimed;
};

class SWV5S5_ReferenceLeaseStore
{
private:
   SWV5S5_ReferenceLease m_lease;

   string FenceDigest(const SWV5S5_ReferenceLease &lease) const
   {
      return SWV5S5_ReferenceDigest("OWNERSHIP-FENCE",
         lease.ownership_namespace_digest+"|"+lease.owner_id+"|"+
         (string)lease.lease_version+"|"+(string)lease.takeover_generation);
   }

public:
   void InitializeUnclaimed(const string namespace_digest)
   {
      ZeroMemory(m_lease);
      m_lease.ownership_namespace_digest=namespace_digest;
      m_lease.store_revision=1;
   }

   bool Acquire(const string owner_id,const ulong expected_store_revision,
                const ulong clock_sequence,const datetime now,
                const uint lease_seconds,SWV5S5_ReferenceLease &result)
   {
      if(m_lease.claimed || owner_id=="" || expected_store_revision!=m_lease.store_revision ||
         clock_sequence==0 || now<=0 || lease_seconds==0)
         return false;
      m_lease.claimed=true;
      m_lease.owner_id=owner_id;
      m_lease.lease_version=1;
      m_lease.takeover_generation=1;
      m_lease.store_revision++;
      m_lease.heartbeat_sequence=1;
      m_lease.heartbeat_clock_sequence=clock_sequence;
      m_lease.heartbeat_at=now;
      m_lease.expires_at=now+(datetime)lease_seconds;
      m_lease.fencing_token_digest=FenceDigest(m_lease);
      result=m_lease;
      return true;
   }

   bool Heartbeat(const string owner_id,const ulong expected_store_revision,
                  const string expected_fence_digest,const ulong clock_sequence,
                  const datetime now,const uint lease_seconds,
                  SWV5S5_ReferenceLease &result)
   {
      if(!m_lease.claimed || owner_id!=m_lease.owner_id ||
         expected_store_revision!=m_lease.store_revision ||
         expected_fence_digest!=m_lease.fencing_token_digest ||
         clock_sequence<=m_lease.heartbeat_clock_sequence || now<m_lease.heartbeat_at ||
         lease_seconds==0)
         return false;
      const string stable_fence=m_lease.fencing_token_digest;
      const ulong stable_lease_version=m_lease.lease_version;
      const ulong stable_takeover_generation=m_lease.takeover_generation;
      m_lease.store_revision++;
      m_lease.heartbeat_sequence++;
      m_lease.heartbeat_clock_sequence=clock_sequence;
      m_lease.heartbeat_at=now;
      m_lease.expires_at=now+(datetime)lease_seconds;
      m_lease.fencing_token_digest=stable_fence;
      m_lease.lease_version=stable_lease_version;
      m_lease.takeover_generation=stable_takeover_generation;
      result=m_lease;
      return true;
   }

   bool Takeover(const string new_owner_id,const ulong expected_store_revision,
                 const string expected_fence_digest,const ulong proposed_generation,
                 const ulong clock_sequence,const datetime now,
                 const bool expiry_valid,const bool broker_reconciled,
                 const bool persistence_reconciled,const bool independent_authority,
                 const uint lease_seconds,SWV5S5_ReferenceLease &result)
   {
      if(!m_lease.claimed || new_owner_id=="" || new_owner_id==m_lease.owner_id ||
         expected_store_revision!=m_lease.store_revision ||
         expected_fence_digest!=m_lease.fencing_token_digest ||
         proposed_generation!=m_lease.takeover_generation+1 ||
         clock_sequence<=m_lease.heartbeat_clock_sequence || now<m_lease.expires_at ||
         !expiry_valid || !broker_reconciled || !persistence_reconciled ||
         !independent_authority || lease_seconds==0)
         return false;
      m_lease.owner_id=new_owner_id;
      m_lease.lease_version++;
      m_lease.takeover_generation=proposed_generation;
      m_lease.store_revision++;
      m_lease.heartbeat_sequence=1;
      m_lease.heartbeat_clock_sequence=clock_sequence;
      m_lease.heartbeat_at=now;
      m_lease.expires_at=now+(datetime)lease_seconds;
      m_lease.fencing_token_digest=FenceDigest(m_lease);
      result=m_lease;
      return true;
   }

   SWV5S5_ReferenceLease Current(void) const { return m_lease; }
};

#endif
