#ifndef SW_V5_PERSISTENCE_CONTRACT_MQH
#define SW_V5_PERSISTENCE_CONTRACT_MQH

#include "SW_V5_BasketContract.mqh"

enum SWV5_PersistenceLoadStatus
{
   SWV5_PERSISTENCE_NOT_FOUND = 0,
   SWV5_PERSISTENCE_LOADED = 1,
   SWV5_PERSISTENCE_VERSION_INCOMPATIBLE = 2,
   SWV5_PERSISTENCE_CHECKSUM_FAILED = 3,
   SWV5_PERSISTENCE_TRUNCATED = 4,
   SWV5_PERSISTENCE_OWNER_CONFLICT = 5,
   SWV5_PERSISTENCE_SEQUENCE_REGRESSION = 6
};

enum SWV5_ReconciliationStatus
{
   SWV5_RECONCILIATION_NOT_STARTED = 0,
   SWV5_RECONCILIATION_MATCHED = 1,
   SWV5_RECONCILIATION_BROKER_AHEAD = 2,
   SWV5_RECONCILIATION_PERSISTENCE_AHEAD = 3,
   SWV5_RECONCILIATION_CONFLICT = 4,
   SWV5_RECONCILIATION_CORRUPT = 5,
   SWV5_RECONCILIATION_OWNERSHIP_CONFLICT = 6,
   SWV5_RECONCILIATION_MANUAL_REQUIRED = 7
};

enum SWV5_CorruptionDisposition
{
   SWV5_CORRUPTION_REJECT_RECORD = 0,
   SWV5_CORRUPTION_USE_LAST_VERIFIED = 1,
   SWV5_CORRUPTION_HALT_AND_RECONCILE = 2,
   SWV5_CORRUPTION_REQUIRE_OPERATOR = 3
};

struct SWV5_PersistenceRecordHeader
{
   SWV5_ContractVersion contract_version;
   ulong                record_sequence;
   ulong                previous_record_sequence;
   string               payload_digest;
   ulong                payload_size;
   SWV5_OwnerIdentity   writer;
   SWV5_BasketID        basket_id;
   datetime             written_at;
};

struct SWV5_PersistedCheckpoint
{
   SWV5_PersistenceRecordHeader header;
   SWV5_BasketAggregate         basket;
   ulong                        last_confirmed_deal_ticket;
   ulong                        last_confirmed_order_ticket;
   ulong                        last_confirmed_transaction_sequence;
   bool                         clean_shutdown;
};

struct SWV5_PersistenceLoadResult
{
   SWV5_PersistenceLoadStatus status;
   SWV5_CorruptionDisposition corruption_disposition;
   bool                       checksum_valid;
   bool                       version_compatible;
   bool                       owner_compatible;
   string                     diagnostic;
};

struct SWV5_AuthoritativeBrokerSummary
{
   SWV5_BasketID         basket_id;
   ulong                 magic;
   string                symbol;
   double                aggregate_position_volume;
   uint                  position_count;
   uint                  order_count;
   ulong                 latest_deal_ticket;
   ulong                 latest_order_ticket;
   datetime              observed_at;
   SWV5_AuthoritySource  authority;
};

struct SWV5_RestartReconciliationInput
{
   SWV5_PersistedCheckpoint      persisted;
   SWV5_AuthoritativeBrokerSummary broker;
   SWV5_OwnerIdentity           claimant;
   bool                         persistence_available;
   bool                         broker_query_complete;
};

struct SWV5_RestartReconciliationResult
{
   SWV5_ReconciliationStatus status;
   SWV5_BasketState          required_state;
   bool                      may_resume;
   bool                      requires_checkpoint_rewrite;
   bool                      requires_operator;
   ulong                     reason_flags;
   string                    diagnostic;
};

class ISWV5PersistenceContract
{
public:
   virtual string ContractName() = 0;
   virtual bool ValidateRecord(const SWV5_PersistedCheckpoint &checkpoint,
                               SWV5_PersistenceLoadResult &result) = 0;
   virtual bool LoadLatest(const SWV5_BasketID &basket_id,
                           SWV5_PersistedCheckpoint &checkpoint,
                           SWV5_PersistenceLoadResult &result) = 0;
   virtual bool SaveCheckpoint(const SWV5_PersistedCheckpoint &checkpoint,
                               SWV5_ContractDecision &decision) = 0;
   virtual bool ReconcileRestart(const SWV5_RestartReconciliationInput &engineInput,
                                 SWV5_RestartReconciliationResult &result) = 0;
};

#endif
