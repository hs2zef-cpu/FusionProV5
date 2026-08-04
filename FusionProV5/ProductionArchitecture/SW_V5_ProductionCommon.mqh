#ifndef SW_V5_PRODUCTION_COMMON_MQH
#define SW_V5_PRODUCTION_COMMON_MQH

#define SWV5_PRODUCTION_CONTRACT_VERSION 1

enum SWV5_AccountPositionMode
{
   SWV5_ACCOUNT_MODE_UNKNOWN = 0,
   SWV5_ACCOUNT_MODE_HEDGING = 1,
   SWV5_ACCOUNT_MODE_NETTING = 2,
   SWV5_ACCOUNT_MODE_REJECTED = 3
};

enum SWV5_ContractStatus
{
   SWV5_CONTRACT_UNAVAILABLE = 0,
   SWV5_CONTRACT_VALID = 1,
   SWV5_CONTRACT_DEGRADED = 2,
   SWV5_CONTRACT_INVALID = 3,
   SWV5_CONTRACT_CONFLICT = 4
};

enum SWV5_AuthoritySource
{
   SWV5_AUTHORITY_NONE = 0,
   SWV5_AUTHORITY_SIGNAL_DTO = 1,
   SWV5_AUTHORITY_PERSISTED_CHECKPOINT = 2,
   SWV5_AUTHORITY_LIVE_BROKER_STATE = 3,
   SWV5_AUTHORITY_DEAL_HISTORY = 4,
   SWV5_AUTHORITY_TRANSACTION_EVENT = 5,
   SWV5_AUTHORITY_OPERATOR = 6
};

enum SWV5_ConfirmationStatus
{
   SWV5_CONFIRMATION_NOT_STARTED = 0,
   SWV5_CONFIRMATION_PENDING = 1,
   SWV5_CONFIRMATION_CONFIRMED = 2,
   SWV5_CONFIRMATION_REJECTED = 3,
   SWV5_CONFIRMATION_PARTIAL = 4,
   SWV5_CONFIRMATION_EXPIRED = 5,
   SWV5_CONFIRMATION_CONFLICT = 6
};

struct SWV5_ContractVersion
{
   string contract_name;
   int    schema_version;
   int    minimum_compatible_version;
};

struct SWV5_BasketID
{
   string value;
};

struct SWV5_RequestID
{
   string   correlation_id;
   string   attempt_id;
   string   parent_attempt_id;
   ulong    monotonic_sequence;
   datetime created_at;
};

struct SWV5_OwnershipKey
{
   long   account_login;
   string server;
   string symbol;
   string strategy_id;
   ulong  magic;
};

struct SWV5_OwnerIdentity
{
   SWV5_OwnershipKey key;
   string             instance_id;
   string             process_fingerprint;
   datetime           started_at;
};

struct SWV5_ContractDecision
{
   SWV5_ContractStatus status;
   bool                allowed;
   ulong               reason_flags;
   string              reason_code;
   string              reason_text;
};

#endif
