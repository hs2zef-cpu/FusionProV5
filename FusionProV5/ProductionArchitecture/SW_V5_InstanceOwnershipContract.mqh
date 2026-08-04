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

enum SWV5_OwnershipRecoveryDisposition
{
   SWV5_OWNER_RECOVERY_FORBIDDEN = 0,
   SWV5_OWNER_RECOVERY_AFTER_EXPIRY = 1,
   SWV5_OWNER_RECOVERY_AFTER_RECONCILIATION = 2,
   SWV5_OWNER_RECOVERY_OPERATOR_REQUIRED = 3
};

struct SWV5_InstanceLease
{
   SWV5_OwnerIdentity     owner;
   SWV5_InstanceLockStatus status;
   ulong                  lease_version;
   string                 lease_token_digest;
   datetime               acquired_at;
   datetime               heartbeat_at;
   datetime               expires_at;
};

struct SWV5_OwnershipClaim
{
   SWV5_OwnerIdentity claimant;
   ulong              expected_lease_version;
   uint               lease_duration_seconds;
   datetime           requested_at;
   bool               broker_state_reconciled;
   bool               persistence_reconciled;
};

struct SWV5_OwnershipConflict
{
   SWV5_OwnershipKey  key;
   SWV5_OwnerIdentity claimant;
   SWV5_OwnerIdentity incumbent;
   SWV5_InstanceLockStatus status;
   bool               simultaneous_heartbeat;
   bool               stale_incumbent;
   bool               execution_must_halt;
   string             diagnostic;
};

struct SWV5_OwnershipDecision
{
   SWV5_ContractDecision decision;
   SWV5_InstanceLease    resulting_lease;
   SWV5_OwnershipRecoveryDisposition recovery_disposition;
   bool                  exclusive_owner_confirmed;
};

class ISWV5InstanceOwnershipContract
{
public:
   virtual string ContractName() = 0;
   virtual bool Acquire(const SWV5_OwnershipClaim &claim,
                        const SWV5_InstanceLease &observed,
                        SWV5_OwnershipDecision &decision) = 0;
   virtual bool Heartbeat(const SWV5_InstanceLease &lease,
                          const datetime observed_time,
                          SWV5_OwnershipDecision &decision) = 0;
   virtual bool DetectConflict(const SWV5_OwnershipClaim &claim,
                               const SWV5_InstanceLease &observed,
                               SWV5_OwnershipConflict &conflict) = 0;
   virtual bool Release(const SWV5_InstanceLease &lease,
                        SWV5_OwnershipDecision &decision) = 0;
};

#endif
