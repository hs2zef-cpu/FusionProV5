#ifndef SW_V5_S5_F_BROKER_ADAPTER_TYPES_MQH
#define SW_V5_S5_F_BROKER_ADAPTER_TYPES_MQH

// SPRINT 5 PHASE F BROKER ADAPTER
// PLATFORM-NEUTRAL DTOs. NO BROKER ACCESS. NO AUTHORITY CREATION.

#include "../Contracts/SW_V5_S5_ReconciliationEvidenceContract.mqh"
#include "../../Configuration/SW_V5_RuntimeIdentityProfile.mqh"

#define SWV5S5_F_ADAPTER_PROFILE_ID "SWV5-SPRINT5-PHASE-F-BROKER-ADAPTER-PROFILE-V1"
#define SWV5S5_F_ADAPTER_DOMAIN_SUBMISSION "SWV5-SPRINT5-PHASE-F-BROKER-SUBMISSION-V1"
#define SWV5S5_F_ADAPTER_DOMAIN_WIRE "SWV5-SPRINT5-PHASE-F-BROKER-WIRE-PAYLOAD-V1"
#define SWV5S5_F_ADAPTER_DOMAIN_CALLBACK "SWV5-SPRINT5-PHASE-F-BROKER-CALLBACK-V1"
#define SWV5S5_F_ADAPTER_DOMAIN_QUERY "SWV5-SPRINT5-PHASE-F-BROKER-QUERY-SNAPSHOT-V1"
#define SWV5S5_F_ADAPTER_DOMAIN_EXECUTION_QUERY "SWV5-SPRINT5-PHASE-F-EXECUTION-PENDING-SNAPSHOT-V1"
#define SWV5S5_F_ADAPTER_DOMAIN_PUBLICATION "SWV5-SPRINT5-PHASE-F-RECONCILIATION-PUBLICATION-V1"
#define SWV5S5_F_MARKET_PRICE_SEMANTICS "INDICATIVE_REQUEST_PRICE_BROKER_FILL_DETERMINED"

enum SWV5S5_F_AdapterPreflightDisposition
{
   SWV5S5_F_ADAPTER_PREFLIGHT_INVALID=0,
   SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT=1,
   SWV5S5_F_ADAPTER_PREFLIGHT_READY_CURRENT_CLAIM=2
};

enum SWV5S5_F_AdapterSyncClassification
{
   SWV5S5_F_ADAPTER_SYNC_NOT_INVOKED=0,
   SWV5S5_F_ADAPTER_SYNC_PRE_CALL_REJECTED=1,
   SWV5S5_F_ADAPTER_SYNC_ACCEPTED_UNRESOLVED=2,
   SWV5S5_F_ADAPTER_SYNC_TRANSPORT_FAILURE_UNRESOLVED=3,
   SWV5S5_F_ADAPTER_SYNC_UNKNOWN_UNRESOLVED=4,
   SWV5S5_F_ADAPTER_SYNC_MALFORMED_UNRESOLVED=5,
   SWV5S5_F_ADAPTER_SYNC_BROKER_REJECTION_CANDIDATE_UNRESOLVED=6,
   SWV5S5_F_ADAPTER_SYNC_CLIENT_LOCAL_REJECTION_UNRESOLVED=7,
   SWV5S5_F_ADAPTER_SYNC_TIMEOUT_UNRESOLVED=8
};

struct SWV5S5_F_AdapterEnvironment
{
   string broker_identity;
   string server;
   long account_login;
   string account_currency;
   string symbol;
   int terminal_build;
   int mql_build;
   int account_trade_mode;
   SWV5_AccountPositionMode account_mode;
   bool connected;
   bool terminal_trade_allowed;
   bool mql_trade_allowed;
   bool account_trade_allowed;
   bool account_trade_expert;
   int symbol_trade_mode;
   int symbol_execution_mode;
   ulong symbol_filling_mask;
   int symbol_digits;
   double point;
   double tick_size;
   double volume_min;
   double volume_max;
   double volume_step;
   ulong runtime_magic;
};

struct SWV5S5_F_AdapterSubmissionCommand
{
   SWV5_ContractVersion contract_version;
   SWV5S5_InvocationClaimTransition prepared_claim;
   SWV5S5_InvocationClaimResult authoritative_claim;
   SWV5S5_F_ProfileScope expected_profile;
   SWV5S5_F_AdapterEnvironment observed_environment;
   int direction;
   double volume;
   double price;
   double stop_price;
   double limit_price;
   ulong filling_mode;
   string comment_metadata;
   string submission_digest;
   // Digest supplied by the authoritative caller for the exact, final wire
   // representation. The adapter verifies it after constructing the request
   // and before the sole platform invocation.
   string wire_payload_digest;
};

// Platform-neutral, field-for-field projection of the final MqlTradeRequest.
// It is populated from the constructed platform request, never used to mutate
// it, and digest-bound immediately before the sole OrderSend invocation.
struct SWV5S5_F_AdapterWireRequest
{
   int action;
   ulong magic;
   ulong order_ticket;
   string symbol;
   double volume;
   double price;
   double stop_limit_price;
   double stop_loss_price;
   double take_profit_price;
   ulong deviation_points;
   int order_type;
   int filling_type;
   int time_type;
   datetime expiration;
   string comment;
   ulong position_ticket;
   ulong position_by_ticket;
};

// Complete neutral copy of every MqlTradeResult field. Synchronous fields are
// acknowledgement/provisional evidence only and never final confirmation.
struct SWV5S5_F_AdapterSyncResult
{
   bool invocation_attempted;
   bool transport_result;
   int last_error;
   uint retcode;
   uint retcode_external;
   ulong request_id_session_local;
   ulong order_ticket;
   ulong deal_ticket;
   double volume;
   double price;
   double bid;
   double ask;
   string comment;
   SWV5S5_F_AdapterSyncClassification classification;
   bool final_confirmation;
   bool retry_allowed;
   string claim_id;
   string claim_record_digest;
   string request_correlation_id;
   string attempt_id;
   string profile_digest;
   string observed_environment_digest;
   string result_digest;
   string reason_code;
};

// Callback DTO is observational evidence only. Its identity is bound to the
// request/Claim/profile context supplied by the durable adapter evidence store.
struct SWV5S5_F_AdapterCallbackEvidence
{
   SWV5_ContractVersion contract_version;
   string request_correlation_id;
   string attempt_id;
   string invocation_claim_id;
   string claim_record_digest;
   string profile_digest;
   ulong callback_sequence;
   datetime observed_at;
   int transaction_type;
   ulong order_ticket;
   ulong deal_ticket;
   ulong position_identifier;
   ulong position_by_identifier;
   string symbol;
   int order_type;
   int order_state;
   int deal_type;
   double price;
   double volume;
   int request_action;
   ulong request_magic;
   string request_comment;
   uint result_retcode;
   uint result_retcode_external;
   ulong request_id_session_local;
   bool final_confirmation;
   bool retry_allowed;
   string evidence_digest;
};

struct SWV5S5_F_BrokerPositionRow
{
   bool read_success;
   ulong ticket;
   ulong position_identifier;
   string symbol;
   ulong magic;
   int direction;
   double volume;
   datetime time_msc;
   string comment;
};

struct SWV5S5_F_BrokerOrderRow
{
   bool read_success;
   ulong ticket;
   ulong position_identifier;
   string symbol;
   ulong magic;
   int order_type;
   int order_state;
   double volume_initial;
   double volume_current;
   datetime setup_time_msc;
   datetime done_time_msc;
   string comment;
};

struct SWV5S5_F_BrokerDealRow
{
   bool read_success;
   ulong ticket;
   ulong order_ticket;
   ulong position_identifier;
   string symbol;
   ulong magic;
   int deal_type;
   int entry_type;
   double volume;
   double price;
   datetime time_msc;
   string comment;
};

struct SWV5S5_F_BrokerQuerySnapshot
{
   SWV5_ContractVersion contract_version;
   SWV5S5_F_ProfileScope profile;
   string broker_read_path_id;
   string broker_authority_instance_id;
   string broker_sequence_authority_id;
   ulong owner_query_sequence;
   ulong connection_generation;
   ulong restart_generation;
   datetime history_from;
   datetime history_to;
   datetime observed_at;
   bool positions_enumeration_complete;
   bool orders_enumeration_complete;
   bool history_orders_enumeration_complete;
   bool history_deals_enumeration_complete;
   bool callback_transactions_enumeration_complete;
   uint positions_reported_total;
   uint orders_reported_total;
   uint history_orders_reported_total;
   uint history_deals_reported_total;
   uint callback_transactions_reported_total;
   uint row_read_failures;
   SWV5S5_F_BrokerPositionRow positions[];
   SWV5S5_F_BrokerOrderRow orders[];
   SWV5S5_F_BrokerOrderRow history_orders[];
   SWV5S5_F_BrokerDealRow history_deals[];
   SWV5S5_F_AdapterCallbackEvidence callback_transactions[];
   SWV5_AuthoritativeQuerySet query_set;
   // These fields report consumption of a separately governed proof. The
   // adapter has no interface that can create, approve, or persist that proof.
   bool completeness_claimed;
   bool visibility_watermark_claimed;
   string capability_proof_digest_consumed;
   string snapshot_digest;
};

struct SWV5S5_F_ExecutionPendingSnapshot
{
   SWV5_ContractVersion contract_version;
   SWV5S5_F_ProfileScope profile;
   string execution_read_path_id;
   string execution_authority_instance_id;
   string execution_sequence_authority_id;
   ulong owner_query_sequence;
   ulong connection_generation;
   ulong restart_generation;
   datetime observed_at;
   bool operation_success;
   bool enumeration_complete;
   uint reported_total;
   uint row_read_failures;
   uint matching_pending_requests;
   uint unrelated_rows;
   SWV5_AuthoritativeQuerySet query_set;
   string snapshot_digest;
};

struct SWV5S5_F_ReconciliationPublication
{
   SWV5_ContractVersion contract_version;
   SWV5S5_F_ReconciliationBinding binding;
   SWV5S5_F_ReconciliationResult result;
   SWV5_InstanceLease current_publication_lease;
   string expected_store_revision;
   ulong expected_reconciliation_revision;
   ulong proposed_reconciliation_revision;
   string publication_digest;
};

class ISWV5S5FBrokerEvidenceStore
{
public:
   virtual bool PersistSubmissionResult(const SWV5S5_F_AdapterSubmissionCommand &command,
                                        const SWV5S5_F_AdapterSyncResult &result)=0;
   virtual bool PersistCallbackEvidence(const SWV5S5_F_AdapterCallbackEvidence &evidence)=0;
   virtual bool ResolveCallbackBinding(const ulong order_ticket,const ulong deal_ticket,
                                       const ulong position_identifier,
                                       const ulong request_id_session_local,
                                       const ulong request_magic,
                                       SWV5S5_F_ReconciliationBinding &binding)=0;
   virtual bool LoadCallbackEvidence(const SWV5S5_F_ReconciliationBinding &binding,
                                     SWV5S5_F_AdapterCallbackEvidence &evidence[],
                                     uint &reported_total,bool &enumeration_complete,
                                     uint &row_read_failures)=0;
   virtual bool ReserveBrokerQuerySequence(const SWV5S5_F_ProfileScope &profile,
                                           ulong &owner_query_sequence)=0;
};

class ISWV5S5FExecutionPendingQuery
{
public:
   virtual bool ObservePendingRequest(const SWV5S5_F_ReconciliationBinding &binding,
                                      SWV5S5_F_ExecutionPendingSnapshot &snapshot)=0;
};

class ISWV5S5FReconciliationPublicationAuthority
{
public:
   // Implementation must compare current lease/fence and exact expected store
   // and reconciliation revisions in one CAS boundary. Content equality never
   // converts stale CAS into success.
   virtual bool TryPublishReconciliation(const SWV5S5_F_ReconciliationPublication &publication,
                                         string &committed_store_revision)=0;
};

#endif // SW_V5_S5_F_BROKER_ADAPTER_TYPES_MQH
