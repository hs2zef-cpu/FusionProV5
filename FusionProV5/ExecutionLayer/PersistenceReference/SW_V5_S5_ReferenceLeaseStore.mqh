#ifndef SW_V5_S5_REFERENCE_LEASE_STORE_MQH
#define SW_V5_S5_REFERENCE_LEASE_STORE_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// Complete frozen lease/takeover DTOs; no boolean safety authority.

#include "SW_V5_S5_FakeTransactionalStore.mqh"
#include "SW_V5_S5_FakeAuthoritativeClock.mqh"
#include "SW_V5_S5_ReferenceProductionIntegrity.mqh"

bool SWV5S5_ReferenceOwnershipKeyEqual(const SWV5_OwnershipKey &a,const SWV5_OwnershipKey &b)
{
   string ca,cb; return SWV5S5_CanonicalOwnershipKey("key",a,ca) &&
      SWV5S5_CanonicalOwnershipKey("key",b,cb) && ca==cb;
}

bool SWV5S5_ReferenceOwnerEqual(const SWV5_OwnerIdentity &a,const SWV5_OwnerIdentity &b)
{
   return SWV5S5_ReferenceOwnershipKeyEqual(a.key,b.key) &&
      a.instance_id==b.instance_id && a.process_fingerprint==b.process_fingerprint && a.started_at==b.started_at;
}

bool SWV5S5_ReferenceOwnershipNamespaceDigest(const SWV5_OwnershipKey &key,string &digest)
{
   string canonical; return SWV5S5_CanonicalOwnershipKey("ownership_namespace",key,canonical) &&
      SWV5S5_DomainDigest("SWV5-S5-PHASE-D1-OWNERSHIP-NAMESPACE",canonical,digest);
}

bool SWV5S5_ReferenceDeriveFenceToken(const SWV5_OwnershipFence &fence,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalOwnershipKey("namespace",fence.ownership_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalOwnershipKey("owner_key",fence.owner.key,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("instance",fence.owner.instance_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("process",fence.owner.process_fingerprint,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("started_at",fence.owner.started_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("lease_version",fence.lease_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("takeover_generation",fence.takeover_generation,f)) return false; body+=f;
   return SWV5S5_DomainDigest("SWV5-S5-PHASE-D1-OWNERSHIP-FENCE",body,digest);
}

bool SWV5S5_ReferenceCanonicalLease(const SWV5_InstanceLease &lease,string &canonical,
                                     string &namespace_digest,string &fence_digest)
{
   if(!SWV5S5_CanonicalInstanceLease("lease",lease,canonical) ||
      !SWV5S5_ReferenceOwnershipNamespaceDigest(lease.fence.ownership_namespace,namespace_digest) ||
      !SWV5S5_ReferenceCanonicalFenceDigest(lease.fence,fence_digest)) return false;
   if(lease.status!=SWV5_LOCK_UNCLAIMED)
   {
      string expected;
      if(!SWV5S5_ReferenceDeriveFenceToken(lease.fence,expected) ||
         lease.fence.fencing_token_digest!=expected) return false;
   }
   return lease.store_revision!="" && lease.clock_id!="" && lease.clock_authority!=SWV5_TIME_AUTHORITY_NONE;
}

class SWV5S5_ReferenceLeaseStore
{
private:
   SWV5S5_FakeTransactionalStore m_store;
   SWV5_InstanceLease m_lease;
   SWV5_PersistenceNamespace m_persistence_namespace;
   bool m_namespace_configured;
   bool m_initialized;

   bool BuildRow(const SWV5_InstanceLease &lease,const ulong revision,SWV5S5_ReferenceDomainRow &row) const
   {
      string canonical,scope,fence,digest;
      if(!SWV5S5_ReferenceCanonicalLease(lease,canonical,scope,fence) ||
         !SWV5S5_ReferenceCanonicalPayloadDigest(SWV5S5_REF_DOMAIN_LEASE,canonical,digest)) return false;
      ZeroMemory(row); row.domain=SWV5S5_REF_DOMAIN_LEASE; row.persistence_namespace_digest=scope;
      row.store_revision=revision; row.authority_fence_digest=fence; row.payload=canonical; row.payload_digest=digest;
      return true;
   }

   bool Commit(const SWV5_InstanceLease &proposed,const SWV5S5_ReferenceFaultPoint fault,
               SWV5S5_ReferenceTransactionResult &transaction)
   {
      SWV5S5_ReferenceDomainRow current,row,readback;
      string canonical,scope,fence;
      if(!m_store.Load(SWV5S5_REF_DOMAIN_LEASE,current) ||
         !SWV5S5_ReferenceCanonicalLease(m_lease,canonical,scope,fence) || current.payload!=canonical ||
         current.persistence_namespace_digest!=scope || current.authority_fence_digest!=fence ||
         !BuildRow(proposed,current.store_revision+1,row)) return false;
      const bool committed=m_store.CompareAndSet(SWV5S5_REF_DOMAIN_LEASE,scope,current.store_revision,
         current.payload_digest,current.authority_fence_digest,row,fault,transaction);
      if(transaction.durable_state_matches_proposal) m_lease=proposed;
      return committed && transaction.this_transaction_won &&
         m_store.Load(SWV5S5_REF_DOMAIN_LEASE,readback) && readback.payload==row.payload &&
         readback.payload_digest==row.payload_digest;
   }

   bool TypedReconciliationValid(const SWV5_TypedReconciliationEvidence &evidence,
                                  const SWV5_ComponentAuthority component,
                                  const SWV5_AuthoritySource source,
                                  const SWV5S5_ReferenceClockObservation &clock,
                                  const ulong enclosing_sequence,
                                  const datetime enclosing_observed_at) const
   {
      return m_namespace_configured && SWV5S5_IsV5Version(evidence.contract_version) &&
         SWV5S5_EqualNamespace(evidence.persistence_namespace,m_persistence_namespace) &&
         SWV5S5_ReferenceOwnershipKeyEqual(evidence.persistence_namespace.ownership_namespace,
            m_lease.fence.ownership_namespace) && evidence.persistence_namespace.basket_id.value!="" &&
         evidence.evidence_id!="" && SWV5S5_IsDigest64Lower(evidence.state_digest) &&
         evidence.issuing_component==component && evidence.authority_source==source &&
         evidence.evidence_sequence>0 && evidence.evidence_sequence<=enclosing_sequence &&
         evidence.observed_at==enclosing_observed_at && evidence.observed_at==clock.observed_at;
   }

   bool CompleteOwnerValid(const SWV5_OwnerIdentity &owner) const
   {
      return SWV5S5_ReferenceOwnerComplete(owner) &&
         SWV5S5_ReferenceOwnershipKeyComplete(m_lease.fence.ownership_namespace) &&
         SWV5S5_ReferenceOwnershipKeyEqual(owner.key,m_lease.fence.ownership_namespace);
   }

   bool TakeoverEvidenceValid(const SWV5S5_ReferenceClockObservation &validated_clock,
                              const SWV5_OwnershipClaim &claim) const
   {
      const SWV5_OwnershipTakeoverEvidence e=claim.takeover_evidence;
      const SWV5_LeaseExpiryEvidence x=e.lease_expiry;
      if(!SWV5S5_IsV5Version(claim.contract_version) ||
         !SWV5_TestFenceComplete(m_lease.fence) ||
         !SWV5_TestFenceComplete(claim.expected_fence) ||
         !SWV5S5_IsV5Version(e.contract_version) || !SWV5S5_IsV5Version(x.contract_version) ||
         !SWV5S5_IsV5Version(m_lease.contract_version) ||
         !SWV5S5_IsV5Version(m_lease.fence.contract_version) ||
         !SWV5S5_IsV5Version(claim.expected_fence.contract_version) ||
         !SWV5S5_IsV5Version(e.broker_reconciliation.contract_version) ||
         !SWV5S5_IsV5Version(e.persistence_reconciliation.contract_version) ||
         !SWV5S5_ReferenceOwnerComplete(m_lease.fence.owner) ||
         !SWV5S5_ReferenceOwnershipKeyEqual(m_lease.fence.owner.key,m_lease.fence.ownership_namespace) ||
         !CompleteOwnerValid(claim.claimant) || SWV5S5_ReferenceOwnerEqual(claim.claimant,m_lease.fence.owner) ||
         m_lease.store_revision=="" || m_lease.heartbeat_sequence==0 ||
         m_lease.clock_id!=validated_clock.clock_id || m_lease.clock_authority!=validated_clock.authority ||
         m_lease.clock_authority==SWV5_TIME_AUTHORITY_NONE ||
         m_lease.acquired_clock_sequence>m_lease.heartbeat_clock_sequence ||
         m_lease.heartbeat_clock_sequence>=m_lease.expiry_clock_sequence ||
         m_lease.acquired_at>m_lease.heartbeat_at || m_lease.heartbeat_at>=m_lease.expires_at ||
         validated_clock.observation_sequence<m_lease.expiry_clock_sequence ||
         !x.expired || x.observed_at<=0 || e.observed_at<=0 || e.evidenced_at<=0 ||
         e.observed_at!=x.observed_at || e.observed_at!=validated_clock.observed_at ||
         e.observed_at>e.evidenced_at || e.evidenced_at>validated_clock.observed_at ||
         !SWV5S5_ReferenceOwnershipKeyEqual(x.observed_ownership_key,m_lease.fence.ownership_namespace) ||
         !SWV5S5_ReferenceOwnershipKeyEqual(x.observed_ownership_namespace,m_lease.fence.ownership_namespace) ||
         !SWV5S5_ReferenceOwnerEqual(x.observed_owner,m_lease.fence.owner) ||
         x.clock_id!=validated_clock.clock_id || x.clock_authority!=validated_clock.authority ||
         x.observed_clock_sequence!=validated_clock.observation_sequence ||
         x.observed_lease_version!=m_lease.fence.lease_version ||
         x.observed_heartbeat_sequence!=m_lease.heartbeat_sequence ||
         x.observed_store_revision!=m_lease.store_revision || x.observed_expiry_time!=m_lease.expires_at ||
         x.observed_takeover_generation!=m_lease.fence.takeover_generation ||
         validated_clock.observed_at<m_lease.expires_at ||
         !SWV5S5_ReferenceOwnerEqual(e.observed_owner,m_lease.fence.owner) ||
         !SWV5S5_ReferenceOwnershipKeyEqual(e.observed_ownership_key,m_lease.fence.ownership_namespace) ||
         !SWV5S5_ReferenceOwnershipKeyEqual(e.observed_ownership_namespace,m_lease.fence.ownership_namespace) ||
         e.observed_lease_version!=m_lease.fence.lease_version || e.observed_store_revision!=m_lease.store_revision ||
         e.observed_heartbeat_sequence!=m_lease.heartbeat_sequence || e.observed_clock_id!=validated_clock.clock_id ||
         e.observed_clock_authority!=validated_clock.authority ||
         e.observed_clock_sequence!=validated_clock.observation_sequence ||
         e.observed_expiry_time!=m_lease.expires_at ||
         e.observed_takeover_generation!=m_lease.fence.takeover_generation ||
         e.proposed_takeover_generation!=m_lease.fence.takeover_generation+1 ||
         e.authority==SWV5_COMPONENT_AUTHORITY_NONE || e.authority==SWV5_COMPONENT_AUTHORITY_EXECUTION ||
         e.authority==SWV5_COMPONENT_AUTHORITY_TEST_FIXTURE ||
         e.independent_authority_source!=SWV5_AUTHORITY_OPERATOR || e.evidence_sequence==0 ||
         !m_namespace_configured ||
         !SWV5S5_EqualNamespace(e.broker_reconciliation.persistence_namespace,m_persistence_namespace) ||
         !SWV5S5_EqualNamespace(e.persistence_reconciliation.persistence_namespace,m_persistence_namespace) ||
         e.broker_reconciliation.evidence_id==e.persistence_reconciliation.evidence_id ||
         !TypedReconciliationValid(e.broker_reconciliation,SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER,
            SWV5_AUTHORITY_LIVE_BROKER_STATE,validated_clock,e.evidence_sequence,e.observed_at) ||
         !TypedReconciliationValid(e.persistence_reconciliation,SWV5_COMPONENT_AUTHORITY_PERSISTENCE,
            SWV5_AUTHORITY_PERSISTED_CHECKPOINT,validated_clock,e.evidence_sequence,e.observed_at)) return false;
      return true;
   }

public:
   SWV5S5_ReferenceLeaseStore(void):m_namespace_configured(false),m_initialized(false)
   { ZeroMemory(m_lease); ZeroMemory(m_persistence_namespace); }

   bool Initialize(const SWV5_InstanceLease &unclaimed)
   {
      if(m_initialized || unclaimed.status!=SWV5_LOCK_UNCLAIMED ||
         !SWV5S5_ReferenceOwnershipKeyComplete(unclaimed.fence.ownership_namespace)) return false;
      SWV5S5_ReferenceDomainRow row; if(!BuildRow(unclaimed,1,row) || !m_store.Seed(row)) return false;
      m_lease=unclaimed; m_initialized=true; return true;
   }

   // Takeover requires an independently configured complete Persistence
   // Namespace. The Lease DTO alone contains only the ownership namespace and
   // cannot authorize a Basket-scoped reconciliation.
   bool Initialize(const SWV5_InstanceLease &unclaimed,const SWV5_PersistenceNamespace &persistence_namespace)
   {
      if(!SWV5S5_ReferencePersistenceNamespaceComplete(persistence_namespace) ||
         !SWV5S5_ReferenceOwnershipKeyEqual(persistence_namespace.ownership_namespace,
                                             unclaimed.fence.ownership_namespace)) return false;
      if(!Initialize(unclaimed)) return false;
      m_persistence_namespace=persistence_namespace; m_namespace_configured=true;
      return true;
   }

   // TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.
   // Seed an independently observed expired row for takeover probes. Ordinary
   // Initialize remains UNCLAIMED-only. Seeding creates no ownership grant;
   // Takeover must still pass its complete semantic gate and central CAS.
   bool SeedObservedLeaseForVerification(const SWV5_InstanceLease &observed,
                                         const SWV5_PersistenceNamespace &persistence_namespace)
   {
      if(m_initialized || observed.status!=SWV5_LOCK_EXPIRED ||
         !SWV5S5_ReferencePersistenceNamespaceComplete(persistence_namespace) ||
         !SWV5S5_ReferenceOwnerComplete(observed.fence.owner) ||
         !SWV5S5_ReferenceOwnershipKeyEqual(observed.fence.owner.key,observed.fence.ownership_namespace) ||
         !SWV5S5_ReferenceOwnershipKeyEqual(persistence_namespace.ownership_namespace,observed.fence.ownership_namespace))
         return false;
      SWV5S5_ReferenceDomainRow row;
      if(!BuildRow(observed,1,row) || !m_store.Seed(row)) return false;
      m_lease=observed; m_persistence_namespace=persistence_namespace;
      m_namespace_configured=true; m_initialized=true;
      return true;
   }

   bool Acquire(SWV5S5_FakeAuthoritativeClock &clock,
                const SWV5S5_ReferenceClockObservation &validated_clock,
                const SWV5_OwnershipClaim &claim,SWV5_InstanceLease &result,
                SWV5S5_ReferenceTransactionResult &transaction)
   {
      if(!m_initialized || !clock.ValidateAccepted(validated_clock) || m_lease.status!=SWV5_LOCK_UNCLAIMED ||
         claim.expected_store_revision!=m_lease.store_revision || claim.lease_duration_seconds==0 ||
         !CompleteOwnerValid(claim.claimant) ||
         !SWV5S5_EqualFence(claim.expected_fence,m_lease.fence)) return false;
      result=m_lease; result.status=SWV5_LOCK_ACQUIRED; result.fence.owner=claim.claimant;
      result.fence.lease_version=m_lease.fence.lease_version+1;
      result.store_revision="LEASE-STORE-"+(string)2; result.heartbeat_sequence=1;
      result.clock_id=validated_clock.clock_id; result.clock_authority=validated_clock.authority;
      result.acquired_clock_sequence=validated_clock.observation_sequence;
      result.heartbeat_clock_sequence=validated_clock.observation_sequence;
      result.expiry_clock_sequence=validated_clock.observation_sequence+claim.lease_duration_seconds;
      result.acquired_at=validated_clock.observed_at; result.heartbeat_at=validated_clock.observed_at;
      result.expires_at=validated_clock.observed_at+(datetime)claim.lease_duration_seconds;
      if(!SWV5S5_ReferenceDeriveFenceToken(result.fence,result.fence.fencing_token_digest)) return false;
      return Commit(result,SWV5S5_REF_FAULT_NONE,transaction);
   }

   bool Heartbeat(SWV5S5_FakeAuthoritativeClock &clock,
                  const SWV5S5_ReferenceClockObservation &validated_clock,
                  const SWV5_InstanceLease &expected,const uint lease_seconds,
                  SWV5_InstanceLease &result,SWV5S5_ReferenceTransactionResult &transaction)
   {
      string expected_canonical,current_canonical,a,b,c,d;
      if(!m_initialized || !clock.ValidateAccepted(validated_clock) || lease_seconds==0 ||
         !SWV5S5_ReferenceCanonicalLease(expected,expected_canonical,a,b) ||
         !SWV5S5_ReferenceCanonicalLease(m_lease,current_canonical,c,d) || expected_canonical!=current_canonical ||
         (m_lease.status!=SWV5_LOCK_ACQUIRED && m_lease.status!=SWV5_LOCK_RENEWED) ||
         validated_clock.observation_sequence<=m_lease.heartbeat_clock_sequence ||
         validated_clock.observed_at<m_lease.heartbeat_at) return false;
      result=m_lease; result.status=SWV5_LOCK_RENEWED;
      result.store_revision="LEASE-STORE-HEARTBEAT-"+(string)(m_lease.heartbeat_sequence+1);
      result.heartbeat_sequence=m_lease.heartbeat_sequence+1;
      result.heartbeat_clock_sequence=validated_clock.observation_sequence;
      result.expiry_clock_sequence=validated_clock.observation_sequence+lease_seconds;
      result.heartbeat_at=validated_clock.observed_at; result.expires_at=validated_clock.observed_at+(datetime)lease_seconds;
      return Commit(result,SWV5S5_REF_FAULT_NONE,transaction);
   }

   bool Takeover(SWV5S5_FakeAuthoritativeClock &clock,
                 const SWV5S5_ReferenceClockObservation &validated_clock,
                 const SWV5_OwnershipClaim &claim,SWV5_InstanceLease &result,
                 SWV5S5_ReferenceTransactionResult &transaction)
   {
      if(!m_initialized || !clock.ValidateAccepted(validated_clock) || m_lease.status!=SWV5_LOCK_EXPIRED ||
         !SWV5S5_EqualFence(claim.expected_fence,m_lease.fence) || claim.expected_store_revision!=m_lease.store_revision ||
         claim.lease_duration_seconds==0 || !TakeoverEvidenceValid(validated_clock,claim)) return false;
      const SWV5_OwnershipTakeoverEvidence e=claim.takeover_evidence;
      result=m_lease; result.status=SWV5_LOCK_ACQUIRED; result.fence.owner=claim.claimant;
      result.fence.lease_version=m_lease.fence.lease_version+1;
      result.fence.takeover_generation=e.proposed_takeover_generation;
      result.store_revision="LEASE-STORE-TAKEOVER"; result.heartbeat_sequence=1;
      result.acquired_clock_sequence=validated_clock.observation_sequence;
      result.heartbeat_clock_sequence=validated_clock.observation_sequence;
      result.expiry_clock_sequence=validated_clock.observation_sequence+claim.lease_duration_seconds;
      result.acquired_at=validated_clock.observed_at; result.heartbeat_at=validated_clock.observed_at;
      result.expires_at=validated_clock.observed_at+(datetime)claim.lease_duration_seconds;
      if(!SWV5S5_ReferenceDeriveFenceToken(result.fence,result.fence.fencing_token_digest)) return false;
      if(!SWV5_TestFenceComplete(result.fence)) return false;
      return Commit(result,SWV5S5_REF_FAULT_NONE,transaction);
   }

   bool Load(SWV5_InstanceLease &lease) const
   {
      SWV5S5_ReferenceDomainRow row; string canonical,scope,fence;
      if(!m_initialized || !m_store.Load(SWV5S5_REF_DOMAIN_LEASE,row) ||
         !SWV5S5_ReferenceCanonicalLease(m_lease,canonical,scope,fence) || row.payload!=canonical) return false;
      lease=m_lease; return true;
   }
};

#endif
