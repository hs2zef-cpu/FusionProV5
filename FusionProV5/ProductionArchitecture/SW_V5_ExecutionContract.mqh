#ifndef SW_V5_EXECUTION_CONTRACT_MQH
#define SW_V5_EXECUTION_CONTRACT_MQH

#include "SW_V5_BasketContract.mqh"

enum SWV5_ExecutionIntentType
{
   SWV5_INTENT_OPEN = 0,
   SWV5_INTENT_INCREASE = 1,
   SWV5_INTENT_REDUCE = 2,
   SWV5_INTENT_CLOSE = 3,
   SWV5_INTENT_CANCEL_PENDING = 4
};

enum SWV5_PendingRequestState
{
   SWV5_REQUEST_CREATED = 0,
   SWV5_REQUEST_RISK_AUTHORIZED = 1,
   SWV5_REQUEST_SUBMISSION_PENDING = 2,
   SWV5_REQUEST_ACKNOWLEDGED = 3,
   SWV5_REQUEST_CONFIRMATION_PENDING = 4,
   SWV5_REQUEST_CONFIRMED = 5,
   SWV5_REQUEST_PARTIALLY_CONFIRMED = 6,
   SWV5_REQUEST_REJECTED = 7,
   SWV5_REQUEST_EXPIRED = 8,
   SWV5_REQUEST_RECONCILIATION_REQUIRED = 9,
   SWV5_REQUEST_CANCELLED = 10
};

enum SWV5_ResultRetcodeClass
{
   SWV5_RETCODE_UNCLASSIFIED = 0,
   SWV5_RETCODE_ACCEPTED_PENDING_CONFIRMATION = 1,
   SWV5_RETCODE_SYNCHRONOUS_DEAL_REPORTED_PENDING_EVIDENCE = 2,
   SWV5_RETCODE_REJECTED_PERMANENT = 3,
   SWV5_RETCODE_REJECTED_TRANSIENT = 4,
   SWV5_RETCODE_PRICE_CHANGED = 5,
   SWV5_RETCODE_VOLUME_CHANGED = 6,
   SWV5_RETCODE_MARKET_CLOSED = 7,
   SWV5_RETCODE_CONNECTION_UNCERTAIN = 8,
   SWV5_RETCODE_OWNERSHIP_CONFLICT = 9,
   SWV5_RETCODE_RECONCILIATION_REQUIRED = 10
};

enum SWV5_TransactionEventKind
{
   SWV5_TRANSACTION_EVENT_UNKNOWN = 0,
   SWV5_TRANSACTION_EVENT_ORDER_ACCEPTED = 1,
   SWV5_TRANSACTION_EVENT_DEAL_ADDED = 2,
   SWV5_TRANSACTION_EVENT_POSITION_CHANGED = 3,
   SWV5_TRANSACTION_EVENT_ORDER_REMOVED = 4,
   SWV5_TRANSACTION_EVENT_HISTORY_CONFIRMED = 5
};

enum SWV5_RetryDisposition
{
   SWV5_RETRY_FORBIDDEN = 0,
   SWV5_RETRY_AFTER_REVALIDATION = 1,
   SWV5_RETRY_AFTER_BACKOFF = 2,
   SWV5_RETRY_REQUIRES_NEW_AUTHORIZATION = 3,
   SWV5_RETRY_REQUIRES_RECONCILIATION = 4
};

struct SWV5_ExecutionIntent
{
   SWV5_ContractVersion     contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence      ownership_fence;
   SWV5_ExecutionCorrelation correlation;
   SWV5_ExecutionIntentType intent_type;
   int                      direction;
   double                   normalized_volume;
   double                   normalized_price;
   double                   normalized_stop_price;
   double                   normalized_limit_price;
   ulong                    symbol_specification_sequence;
   ulong                    expected_basket_version;
   string                   risk_authorization_id;
   datetime                 authorization_expires_at;
};

struct SWV5_ResultRetcodeEvidence
{
   SWV5_ContractVersion  contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence   ownership_fence;
   SWV5_ExecutionCorrelation correlation;
   uint                   raw_retcode;
   string                 broker_comment;
   datetime               observed_at;
};

struct SWV5_ResultRetcodeClassification
{
   SWV5_ContractVersion   contract_version;
   SWV5_ResultRetcodeClass classification;
   SWV5_RetryDisposition   retry_disposition;
   string                  mapping_policy_id;
   SWV5_ContractDecision   decision;
};

struct SWV5_TransactionEvidence
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   SWV5_ExecutionCorrelation correlation;
   SWV5_TransactionEventKind event_kind;
   double                confirmed_volume;
   double                confirmed_price;
   ulong                 symbol_specification_sequence;
   ulong                 expected_basket_version;
   datetime              transaction_time;
   datetime              received_at;
   SWV5_AuthoritySource  authority;
   bool                  history_cross_checked;
};

struct SWV5_PendingRequest
{
   SWV5_ContractVersion    contract_version;
   SWV5_ExecutionIntent    intent;
   SWV5_PendingRequestState state;
   uint                    submission_attempt_count;
   SWV5_ResultRetcodeEvidence latest_retcode;
   SWV5_ResultRetcodeClassification latest_retcode_classification;
   double                  confirmed_volume;
   double                  residual_requested_volume;
   SWV5_ExecutionCorrelation last_accepted_correlation;
   datetime                last_changed_at;
};

struct SWV5_RetryPolicy
{
   SWV5_ContractVersion  contract_version;
   uint                  maximum_attempts;
   uint                  initial_backoff_milliseconds;
   uint                  maximum_backoff_milliseconds;
   bool                  require_fresh_risk_authorization;
   bool                  require_fresh_unit_normalization;
   SWV5_RetryDisposition disposition;
   datetime              authorization_deadline;
   datetime              earliest_retry_at;
};

struct SWV5_ExecutionConfirmation
{
   SWV5_ContractVersion    contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence     ownership_fence;
   SWV5_ExecutionCorrelation correlation;
   SWV5_ConfirmationStatus status;
   SWV5_ContractDisposition disposition;
   double                  confirmed_volume;
   double                  residual_volume;
   ulong                   symbol_specification_sequence;
   string                  diagnostic;
};

class ISWV5ExecutionContract
{
public:
   virtual string ContractName() = 0;
   virtual bool ValidateIntent(const SWV5_ContractValidationContext &context,
                               const SWV5_ExecutionIntent &intent,
                               SWV5_ContractDecision &decision) = 0;
   virtual bool ClassifyResultRetcode(const SWV5_ContractValidationContext &context,
                                      const SWV5_ResultRetcodeEvidence &evidence,
                                      SWV5_ResultRetcodeClassification &classification) = 0;
   virtual bool AcceptTransactionEvidence(const SWV5_ContractValidationContext &context,
                                          const SWV5_PendingRequest &pending,
                                          const SWV5_TransactionEvidence &evidence,
                                          SWV5_ExecutionConfirmation &confirmation) = 0;
   virtual bool EvaluateRetry(const SWV5_ContractValidationContext &context,
                              const SWV5_PendingRequest &pending,
                              const SWV5_RetryPolicy &policy,
                              SWV5_ContractDecision &decision) = 0;
};

#endif
