#ifndef SW_V5_PERSISTENCE_CONTRACT_MQH
#define SW_V5_PERSISTENCE_CONTRACT_MQH

#include "SW_V5_ExecutionContract.mqh"

enum SWV5_PersistenceLoadStatus
{
   SWV5_PERSISTENCE_NOT_FOUND = 0,
   SWV5_PERSISTENCE_LOADED = 1,
   SWV5_PERSISTENCE_VERSION_INCOMPATIBLE = 2,
   SWV5_PERSISTENCE_CHECKSUM_FAILED = 3,
   SWV5_PERSISTENCE_TRUNCATED = 4,
   SWV5_PERSISTENCE_OWNER_CONFLICT = 5,
   SWV5_PERSISTENCE_SEQUENCE_REGRESSION = 6,
   SWV5_PERSISTENCE_BASKET_MISMATCH = 7,
   SWV5_PERSISTENCE_PREVIOUS_SEQUENCE_MISMATCH = 8,
   SWV5_PERSISTENCE_PAYLOAD_SIZE_MISMATCH = 9
};

enum SWV5_ReconciliationStatus
{
   SWV5_RECONCILIATION_NOT_STARTED = 0,
   SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED = 1,
   SWV5_RECONCILIATION_BROKER_AHEAD_HALT = 2,
   SWV5_RECONCILIATION_PERSISTENCE_AHEAD_HALT = 3,
   SWV5_RECONCILIATION_CONFLICT_HALT = 4,
   SWV5_RECONCILIATION_CORRUPT_HALT = 5,
   SWV5_RECONCILIATION_OWNERSHIP_CONFLICT_HALT = 6,
   SWV5_RECONCILIATION_MANUAL_REQUIRED = 7
};

enum SWV5_CorruptionDisposition
{
   SWV5_CORRUPTION_REJECT_RECORD = 0,
   SWV5_CORRUPTION_USE_LAST_VERIFIED = 1,
   SWV5_CORRUPTION_HALT_AND_RECONCILE = 2,
   SWV5_CORRUPTION_REQUIRE_OPERATOR = 3
};

enum SWV5_RestartReadinessDisposition
{
   SWV5_RESTART_SAFE_TO_RESUME = 0,
   SWV5_RESTART_RECONCILIATION_REQUIRED = 1,
   SWV5_RESTART_RETRY_FORBIDDEN = 2,
   SWV5_RESTART_CLOSE_ONLY = 3,
   SWV5_RESTART_HALTED = 4
};

struct SWV5_PersistenceRecordHeader
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   ulong                record_sequence;
   ulong                previous_record_sequence;
   string               payload_digest;
   ulong                payload_size;
   datetime             written_at;
};

struct SWV5_PersistedRequestEvidence
{
   SWV5_ContractVersion       contract_version;
   SWV5_PersistenceNamespace  persistence_namespace;
   SWV5_OwnershipFence        ownership_fence;
   SWV5_PendingRequest        pending_request;
   SWV5_AccountPositionMode   account_mode;
   ulong                      record_sequence;
   datetime                   recorded_at;
};

struct SWV5_PersistedRequestSetHeader
{
   SWV5_ContractVersion contract_version;
   uint                 request_count;
   string               request_set_digest;
   string               request_index_revision;
   ulong                record_sequence;
};

struct SWV5_PersistedCheckpoint
{
   SWV5_PersistenceRecordHeader header;
   SWV5_BasketAggregate         basket;
   SWV5_ExecutionCorrelation    last_confirmed_correlation;
   SWV5_PersistedRequestSetHeader pending_request_set;
   bool                         has_latest_pending_request;
   SWV5_PersistedRequestEvidence latest_pending_request;
   SWV5_HardKillState           hard_kill_state;
   bool                         clean_shutdown;
};

struct SWV5_PersistenceLoadResult
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceLoadStatus status;
   SWV5_CorruptionDisposition corruption_disposition;
   string                     diagnostic;
};

struct SWV5_AuthoritativeBrokerSummary
{
   SWV5_ContractVersion  contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   double                aggregate_position_volume;
   double                residual_volume;
   uint                  position_count;
   uint                  order_count;
   uint                  pending_request_count;
   SWV5_ExecutionCorrelation latest_confirmed_correlation;
   SWV5_AccountPositionMode account_mode;
   SWV5_AuthoritativeQuerySet queries;
   datetime              observed_at;
   SWV5_AuthoritySource  authority;
};

struct SWV5_RestartReconciliationInput
{
   SWV5_ContractVersion          contract_version;
   SWV5_PersistenceNamespace     persistence_namespace;
   SWV5_PersistedCheckpoint      persisted;
   SWV5_AuthoritativeBrokerSummary broker;
   SWV5_OwnershipFence           claimant_fence;
   SWV5_PersistenceLoadStatus   persistence_status;
};

struct SWV5_RestartReconciliationResult
{
   SWV5_ContractVersion     contract_version;
   SWV5_ReconciliationStatus status;
   SWV5_RestartReadinessDisposition readiness_disposition;
   SWV5_BasketState          required_state;
   ulong                     reason_flags;
   string                    diagnostic;
};

class ISWV5PersistenceContract
{
public:
   virtual string ContractName() = 0;
   virtual bool ValidateRecord(const SWV5_ContractValidationContext &context,
                               const SWV5_PersistedCheckpoint &checkpoint,
                               SWV5_PersistenceLoadResult &result) = 0;
   virtual bool LoadLatest(const SWV5_ContractValidationContext &context,
                           const SWV5_PersistenceNamespace &persistence_namespace,
                           SWV5_PersistedCheckpoint &checkpoint,
                           SWV5_PersistenceLoadResult &result) = 0;
   virtual bool LoadPendingRequests(const SWV5_ContractValidationContext &context,
                                    const SWV5_PersistenceNamespace &persistence_namespace,
                                    SWV5_PersistedRequestEvidence &requests[],
                                    SWV5_PersistenceLoadResult &result) = 0;
   virtual bool SavePendingRequests(const SWV5_ContractValidationContext &context,
                                    const SWV5_PersistenceNamespace &persistence_namespace,
                                    const SWV5_PersistedRequestEvidence &requests[],
                                    const SWV5_PersistedRequestSetHeader &set_header,
                                    SWV5_ContractDecision &decision) = 0;
   virtual bool SaveCheckpoint(const SWV5_ContractValidationContext &context,
                               const SWV5_PersistedCheckpoint &checkpoint,
                               SWV5_ContractDecision &decision) = 0;
   virtual bool ReconcileRestart(const SWV5_ContractValidationContext &context,
                                 const SWV5_RestartReconciliationInput &engineInput,
                                 const SWV5_PersistedRequestEvidence &pending_requests[],
                                 SWV5_RestartReconciliationResult &result) = 0;
};

#endif
