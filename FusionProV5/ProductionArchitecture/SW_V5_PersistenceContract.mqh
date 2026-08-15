#ifndef SW_V5_PERSISTENCE_CONTRACT_MQH
#define SW_V5_PERSISTENCE_CONTRACT_MQH

// A matching payload digest proves integrity only. Restart authority also
// requires independent semantic validation of every persisted component.

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

// V5 restart safety policy. The complete requirement is contract-defined and
// split by semantic owner: Broker Adapter owns broker-observed domains while
// Execution owns the pending-request query. No caller-supplied mask can weaken
// either partition or the complete union.
const ulong SWV5_RESTART_BROKER_QUERY_FLAGS_V5 =
   SWV5_QUERY_POSITIONS|SWV5_QUERY_ORDERS|SWV5_QUERY_DEALS|
   SWV5_QUERY_TRANSACTIONS;
const ulong SWV5_RESTART_EXECUTION_QUERY_FLAGS_V5 = SWV5_QUERY_PENDING_REQUESTS;
const ulong SWV5_RESTART_REQUIRED_QUERY_FLAGS_V5 =
   SWV5_RESTART_BROKER_QUERY_FLAGS_V5|SWV5_RESTART_EXECUTION_QUERY_FLAGS_V5;

// An observation exactly this old remains valid. Older, zero, future, or
// pre-checkpoint observations fail closed. Validation uses the supplied
// authoritative context clock only; no hidden live clock is permitted.
const long SWV5_MAX_RESTART_EVIDENCE_AGE_SECONDS_V5 = 60;

struct SWV5_PersistenceRecordHeader
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   ulong                record_sequence;
   ulong                previous_record_sequence;
   // Store/CAS revision for this checkpoint publication. It advances with
   // every successful mutation and remains separate from ownership fencing.
   string               store_revision;
   // SWV5-CHECKPOINT-V5-LP2 separates the body, digest preimage, and full DTO.
   // payload_size is the body's canonical MQL string character count and is
   // ordinary digest-bound envelope metadata. Only payload_digest is excluded
   // from its own nonrecursive preimage; the full DTO carries both members.
   // payload_digest is the deterministic canonical hash of that preimage.
   // This is integrity-contract evidence, not cryptographic tamper resistance.
   string               payload_digest;
   ulong                payload_size;
   datetime             written_at;
};

struct SWV5_PersistedRequestEvidence
{
   SWV5_ContractVersion       contract_version;
   SWV5_PersistenceNamespace  persistence_namespace;
   SWV5_OwnershipFence        ownership_fence;
   // Nested durable event sets carry an explicit fingerprint policy. Persisted
   // execution requests require exact one-to-one fingerprint mappings.
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

struct SWV5_PersistedReconciliationVector
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_BasketID basket_id;
   SWV5_AccountPositionMode account_mode;
   double symbol_long_volume;
   double symbol_short_volume;
   double symbol_net_volume;
   double aggregate_position_volume;
   double basket_open_volume;
   double residual_volume;
   uint position_count;
   uint order_count;
   uint pending_request_count;
   SWV5_ExecutionCorrelation latest_confirmed_correlation;
   SWV5_BrokerExecutionIdentity latest_broker_event_identity;
   ulong transaction_high_watermark;
   // Independently persisted anti-replay anchors for the two query-authority
   // streams. A restart observation must advance beyond these high-watermarks.
   ulong broker_query_sequence_high_watermark;
   ulong request_query_sequence_high_watermark;
   string request_set_digest;
   string request_set_revision;
   SWV5_BasketState basket_state;
   ulong basket_state_version;
   ulong hard_kill_generation;
   SWV5_OwnershipFence ownership_fence;
   ulong reconciliation_revision;
   // Digest of the complete reconciliation-vector source state excluding only
   // this field. It is not a copied broker-summary digest or authority proof.
   string source_summary_digest;
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
   SWV5_PersistedReconciliationVector reconciliation_vector;
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
   double                symbol_long_volume;
   double                symbol_short_volume;
   double                symbol_net_volume;
   double                aggregate_position_volume;
   // Broker Adapter observation for this namespace/Basket. This is not read
   // from the persisted reconciliation vector.
   SWV5_BasketID         basket_id;
   double                basket_open_volume;
   double                residual_volume;
   uint                  position_count;
   uint                  order_count;
   SWV5_ExecutionCorrelation latest_confirmed_correlation;
   SWV5_BrokerExecutionIdentity latest_broker_event_identity;
   ulong                 transaction_high_watermark;
   ulong                 observation_sequence;
   // Digest of every broker-summary field except this digest field itself.
   string                complete_summary_digest;
   SWV5_AccountPositionMode account_mode;
   SWV5_AuthoritativeQuerySet queries;
   datetime              observed_at;
   SWV5_AuthoritySource  authority;
};

// Execution owns the durable pending-request view used during restart. Broker
// Adapter cannot legitimately issue request-set identity or reconciliation
// publication revisions, and Persistence cannot independently corroborate its
// own stored values. This snapshot must therefore be supplied independently
// by the Execution/Pending-Request authority boundary.
struct SWV5_AuthoritativeRestartRequestSummary
{
   SWV5_ContractVersion       contract_version;
   SWV5_PersistenceNamespace  persistence_namespace;
   SWV5_BasketID              basket_id;
   SWV5_AccountPositionMode   account_mode;
   uint                       pending_request_count;
   string                     request_set_digest;
   string                     request_set_revision;
   ulong                      reconciliation_revision;
   ulong                      observation_sequence;
   datetime                   observed_at;
   SWV5_ComponentAuthority    authority;
   SWV5_AuthoritySource       authority_source;
   // Execution-owned completion evidence for the pending-request query. It is
   // separate from Broker Adapter query evidence by construction.
   SWV5_AuthoritativeQuerySet pending_request_query;
   // Canonical digest of every field above; excluded from its own preimage.
   string                     complete_summary_digest;
};

struct SWV5_RestartReconciliationInput
{
   SWV5_ContractVersion          contract_version;
   SWV5_PersistenceNamespace     persistence_namespace;
   SWV5_PersistedCheckpoint      persisted;
   SWV5_AuthoritativeBrokerSummary broker;
   SWV5_AuthoritativeRestartRequestSummary restart_requests;
   SWV5_OwnershipFence           claimant_fence;
   SWV5_PersistenceLoadStatus   persistence_status;
   // RELEASED checkpoints require this independently obtained authority input.
   // It must never be reconstructed from persisted.hard_kill_state.
   bool                         has_release_authority_record;
   SWV5_HardKillReleaseAuthorityRecord release_authority_record;
};

// Pure reconciliation output proposed for a separate atomic Persistence
// publication. The accepted values are derived from validated Broker and
// Execution query snapshots; callers may not substitute arbitrary counters.
struct SWV5_AcceptedQueryWatermarkProposal
{
   SWV5_ContractVersion      contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence       ownership_fence;
   string                    expected_store_revision;
   ulong                     expected_record_sequence;
   ulong                     accepted_broker_query_high_watermark;
   ulong                     accepted_execution_query_high_watermark;
   ulong                     broker_snapshot_observation_sequence;
   ulong                     execution_snapshot_observation_sequence;
   ulong                     next_reconciliation_revision;
   // Canonical digest of every field above; excluded from its own preimage.
   string                    proposal_digest;
};

struct SWV5_RestartReconciliationResult
{
   SWV5_ContractVersion     contract_version;
   SWV5_ReconciliationStatus status;
   SWV5_RestartReadinessDisposition readiness_disposition;
   SWV5_BasketState          required_state;
   ulong                     reason_flags;
   string                    diagnostic;
   bool                      has_accepted_query_watermark_proposal;
   SWV5_AcceptedQueryWatermarkProposal accepted_query_watermarks;
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
   // Atomically advances the two owner-specific restart query anti-replay
   // anchors and all checkpoint publication metadata under store/CAS fencing.
   // The exact reconciliation input and request set are revalidated so a
   // caller-fabricated proposal cannot publish. Failure must leave the
   // previously published checkpoint unchanged.
   virtual bool PublishRestartQueryWatermarks(const SWV5_ContractValidationContext &context,
                                              const SWV5_RestartReconciliationInput &reconciliation_input,
                                              const SWV5_PersistedRequestEvidence &pending_requests[],
                                              const SWV5_AcceptedQueryWatermarkProposal &proposal,
                                              SWV5_PersistedCheckpoint &published_checkpoint,
                                              SWV5_ContractDecision &decision) = 0;
   virtual bool ReconcileRestart(const SWV5_ContractValidationContext &context,
                                 const SWV5_RestartReconciliationInput &engineInput,
                                 const SWV5_PersistedRequestEvidence &pending_requests[],
                                 SWV5_RestartReconciliationResult &result) = 0;
};

#endif
