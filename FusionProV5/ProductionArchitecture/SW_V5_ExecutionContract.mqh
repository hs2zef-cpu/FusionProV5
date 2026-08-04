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
   SWV5_RETCODE_CONFIRMED_SYNCHRONOUSLY = 2,
   SWV5_RETCODE_REJECTED_PERMANENT = 3,
   SWV5_RETCODE_REJECTED_TRANSIENT = 4,
   SWV5_RETCODE_PRICE_CHANGED = 5,
   SWV5_RETCODE_VOLUME_CHANGED = 6,
   SWV5_RETCODE_MARKET_CLOSED = 7,
   SWV5_RETCODE_CONNECTION_UNCERTAIN = 8,
   SWV5_RETCODE_OWNERSHIP_CONFLICT = 9,
   SWV5_RETCODE_RECONCILIATION_REQUIRED = 10
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
   SWV5_RequestID           request_id;
   SWV5_BasketID            basket_id;
   SWV5_ExecutionIntentType intent_type;
   int                      direction;
   double                   normalized_volume;
   double                   normalized_price;
   double                   normalized_stop_price;
   double                   normalized_limit_price;
   ulong                    expected_basket_version;
   string                   risk_authorization_id;
   datetime                 authorization_expires_at;
};

struct SWV5_ResultRetcodeEvidence
{
   SWV5_RequestID         request_id;
   uint                   raw_retcode;
   SWV5_ResultRetcodeClass classification;
   SWV5_RetryDisposition  retry_disposition;
   string                 broker_comment;
   datetime               observed_at;
};

struct SWV5_TransactionEvidence
{
   SWV5_RequestID        request_id;
   SWV5_BasketID         basket_id;
   ulong                 transaction_sequence;
   ulong                 deal_ticket;
   ulong                 order_ticket;
   ulong                 position_identifier;
   double                confirmed_volume;
   double                confirmed_price;
   datetime              transaction_time;
   SWV5_AuthoritySource  authority;
};

struct SWV5_PendingRequest
{
   SWV5_ExecutionIntent    intent;
   SWV5_PendingRequestState state;
   uint                    submission_attempt_count;
   SWV5_ResultRetcodeEvidence latest_retcode;
   SWV5_ConfirmationStatus confirmation;
   double                  confirmed_volume;
   double                  residual_requested_volume;
   datetime                last_changed_at;
};

struct SWV5_RetryPolicy
{
   uint                  maximum_attempts;
   uint                  initial_backoff_milliseconds;
   uint                  maximum_backoff_milliseconds;
   bool                  require_fresh_risk_authorization;
   bool                  require_fresh_unit_normalization;
   SWV5_RetryDisposition disposition;
};

struct SWV5_ExecutionConfirmation
{
   SWV5_RequestID          request_id;
   SWV5_ConfirmationStatus status;
   double                  confirmed_volume;
   double                  residual_volume;
   ulong                   authoritative_deal_ticket;
   ulong                   authoritative_position_identifier;
   bool                    basket_update_allowed;
   bool                    reconciliation_required;
   string                  diagnostic;
};

class ISWV5ExecutionContract
{
public:
   virtual string ContractName() = 0;
   virtual bool ValidateIntent(const SWV5_ExecutionIntent &intent,
                               SWV5_ContractDecision &decision) = 0;
   virtual bool ClassifyResultRetcode(const SWV5_ResultRetcodeEvidence &evidence,
                                      SWV5_ContractDecision &decision) = 0;
   virtual bool AcceptTransactionEvidence(const SWV5_PendingRequest &pending,
                                          const SWV5_TransactionEvidence &evidence,
                                          SWV5_ExecutionConfirmation &confirmation) = 0;
   virtual bool EvaluateRetry(const SWV5_PendingRequest &pending,
                              const SWV5_RetryPolicy &policy,
                              SWV5_ContractDecision &decision) = 0;
};

#endif
