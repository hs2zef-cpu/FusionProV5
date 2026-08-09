#ifndef SW_V5_INSTANCE_OWNERSHIP_CONTRACT_MQH
#define SW_V5_INSTANCE_OWNERSHIP_CONTRACT_MQH

#include "SW_V5_ProductionCommon.mqh"

enum SWV5_InstanceLockStatus
{
   SWV5_LOCK_UNCLAIMED = 0,
   SWV5_LOCK_ACQUIRED = 1,
   SWV5_LOCK_RENEWED = 2,
   SWV5_LOCK_EXPIRED = 3,
   SWV5_LOCK_CONFLICT = 4,
   SWV5_LOCK_RECOVERY_REQUIRED = 5,
   SWV5_LOCK_RELEASED = 6,
   SWV5_LOCK_CORRUPT = 7
};

struct SWV5_InstanceLease
{
   SWV5_ContractVersion    contract_version;
   SWV5_OwnershipFence     fence;
   SWV5_InstanceLockStatus status;
   string                 store_revision;
   ulong                  heartbeat_sequence;
   string                 clock_id;
   SWV5_TimeAuthority     clock_authority;
   ulong                  acquired_clock_sequence;
   ulong                  heartbeat_clock_sequence;
   ulong                  expiry_clock_sequence;
   datetime               acquired_at;
   datetime               heartbeat_at;
   datetime               expires_at;
};

struct SWV5_LeaseExpiryEvidence
{
   SWV5_ContractVersion contract_version;
   SWV5_OwnershipKey    observed_ownership_key;
   SWV5_OwnerIdentity   observed_owner;
   SWV5_OwnershipKey    observed_ownership_namespace;
   string               clock_id;
   SWV5_TimeAuthority   clock_authority;
   ulong                observed_clock_sequence;
   datetime             observed_at;
   ulong                observed_lease_version;
   ulong                observed_heartbeat_sequence;
   string               observed_store_revision;
   datetime             observed_expiry_time;
   ulong                observed_takeover_generation;
   bool                 expired;
};

struct SWV5_OwnershipTakeoverEvidence
{
   SWV5_ContractVersion contract_version;
   SWV5_TypedReconciliationEvidence broker_reconciliation;
   SWV5_TypedReconciliationEvidence persistence_reconciliation;
   SWV5_LeaseExpiryEvidence lease_expiry;
   SWV5_OwnershipKey    observed_ownership_key;
   SWV5_OwnerIdentity   observed_owner;
   SWV5_OwnershipKey    observed_ownership_namespace;
   ulong                observed_lease_version;
   string               observed_store_revision;
   ulong                observed_heartbeat_sequence;
   string               observed_clock_id;
   SWV5_TimeAuthority   observed_clock_authority;
   ulong                observed_clock_sequence;
   datetime             observed_expiry_time;
   datetime             observed_at;
   ulong                observed_takeover_generation;
   ulong                proposed_takeover_generation;
   SWV5_ComponentAuthority authority;
   SWV5_AuthoritySource independent_authority_source;
   ulong                evidence_sequence;
   datetime             evidenced_at;
};

struct SWV5_OwnershipClaim
{
   SWV5_ContractVersion contract_version;
   SWV5_OwnerIdentity claimant;
   SWV5_OwnershipFence expected_fence;
   string             expected_store_revision;
   uint               lease_duration_seconds;
   SWV5_OwnershipTakeoverEvidence takeover_evidence;
};

struct SWV5_OwnershipConflict
{
   SWV5_ContractVersion contract_version;
   SWV5_OwnershipKey  key;
   SWV5_OwnerIdentity claimant;
   SWV5_OwnerIdentity incumbent;
   SWV5_InstanceLockStatus status;
   bool               simultaneous_heartbeat;
   bool               stale_incumbent;
   string             diagnostic;
};

struct SWV5_OwnershipDecision
{
   SWV5_ContractVersion contract_version;
   SWV5_ContractDecision decision;
   SWV5_InstanceLease    resulting_lease;
};

class ISWV5InstanceOwnershipContract
{
public:
   virtual string ContractName() = 0;
   virtual bool Acquire(const SWV5_ContractValidationContext &context,
                        const SWV5_OwnershipClaim &claim,
                        const SWV5_InstanceLease &observed,
                        SWV5_OwnershipDecision &decision) = 0;
   virtual bool Heartbeat(const SWV5_ContractValidationContext &context,
                          const SWV5_InstanceLease &lease,
                          const SWV5_InstanceLease &observed,
                          SWV5_OwnershipDecision &decision) = 0;
   virtual bool DetectConflict(const SWV5_ContractValidationContext &context,
                               const SWV5_OwnershipClaim &claim,
                               const SWV5_InstanceLease &observed,
                               SWV5_OwnershipConflict &conflict) = 0;
   virtual bool Release(const SWV5_ContractValidationContext &context,
                        const SWV5_InstanceLease &lease,
                        const SWV5_InstanceLease &observed,
                        SWV5_OwnershipDecision &decision) = 0;
};

#endif
