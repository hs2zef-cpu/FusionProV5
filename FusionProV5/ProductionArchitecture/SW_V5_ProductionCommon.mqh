#ifndef SW_V5_PRODUCTION_COMMON_MQH
#define SW_V5_PRODUCTION_COMMON_MQH

#define SWV5_PRODUCTION_CONTRACT_NAME "SWV5-PRODUCTION"
#define SWV5_PRODUCTION_CONTRACT_VERSION 4
#define SWV5_PRODUCTION_MINIMUM_COMPATIBLE_VERSION 4
#define SWV5_PRODUCTION_CONTRACT_POLICY "SWV5-PRODUCTION-V4"

// Canonical numeric safety boundary for all Production Contract validators.
// Comparisons are never a substitute for this check because NaN can evade
// ordinary ordered comparisons.
bool SWV5_IsFiniteNumber(const double value)
{
   return MathIsValidNumber(value);
}

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

enum SWV5_ContractDisposition
{
   SWV5_DISPOSITION_UNAVAILABLE = 0,
   SWV5_DISPOSITION_ALLOW = 1,
   SWV5_DISPOSITION_DENY = 2,
   SWV5_DISPOSITION_HALT = 3,
   SWV5_DISPOSITION_RECONCILE = 4,
   SWV5_DISPOSITION_OPERATOR_REQUIRED = 5,
   SWV5_DISPOSITION_CONFLICT = 6
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

enum SWV5_ReconciliationState
{
   SWV5_RECONCILIATION_STATE_NOT_STARTED = 0,
   SWV5_RECONCILIATION_STATE_MATCHED = 1,
   SWV5_RECONCILIATION_STATE_REQUIRED = 2,
   SWV5_RECONCILIATION_STATE_CONFLICT = 3,
   SWV5_RECONCILIATION_STATE_MANUAL = 4
};

enum SWV5_ContractCompatibility
{
   SWV5_COMPATIBILITY_UNKNOWN = 0,
   SWV5_COMPATIBILITY_EXACT = 1,
   SWV5_COMPATIBILITY_BACKWARD_COMPATIBLE = 2,
   SWV5_COMPATIBILITY_MIGRATION_REQUIRED = 3,
   SWV5_COMPATIBILITY_REJECTED = 4
};

enum SWV5_TimeAuthority
{
   SWV5_TIME_AUTHORITY_NONE = 0,
   SWV5_TIME_AUTHORITY_BROKER_SERVER = 1,
   SWV5_TIME_AUTHORITY_DURABLE_STORE = 2,
   SWV5_TIME_AUTHORITY_MONOTONIC_HOST = 3,
   SWV5_TIME_AUTHORITY_TEST_FIXTURE = 4
};

enum SWV5_ExecutionLifecyclePhase
{
   SWV5_EXECUTION_PHASE_INTENT = 0,
   SWV5_EXECUTION_PHASE_SUBMISSION = 1,
   SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT = 2,
   SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION = 3,
   SWV5_EXECUTION_PHASE_PARTIAL_FILL = 4,
   SWV5_EXECUTION_PHASE_COMPLETED = 5,
   SWV5_EXECUTION_PHASE_REJECTED = 6,
   SWV5_EXECUTION_PHASE_UNCERTAIN = 7
};

enum SWV5_ComponentAuthority
{
   SWV5_COMPONENT_AUTHORITY_NONE = 0,
   SWV5_COMPONENT_AUTHORITY_EXECUTION = 1,
   SWV5_COMPONENT_AUTHORITY_PERSISTENCE = 2,
   SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER = 3,
   SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE = 4,
   SWV5_COMPONENT_AUTHORITY_OPERATOR = 5,
   SWV5_COMPONENT_AUTHORITY_TEST_FIXTURE = 6,
   SWV5_COMPONENT_AUTHORITY_UNIT_SYSTEM = 7
};

struct SWV5_ContractVersion
{
   string contract_name;
   int    schema_version;
   int    minimum_compatible_version;
   string policy_id;
};

struct SWV5_ContractValidationContext
{
   SWV5_ContractVersion expected_version;
   string               clock_id;
   SWV5_TimeAuthority   clock_authority;
   datetime             clock_time;
   ulong                clock_sequence;
   ulong                evaluation_sequence;
   double               price_tolerance;
   double               volume_tolerance;
};

struct SWV5_ContractCompatibilityResult
{
   SWV5_ContractVersion       evaluated_version;
   SWV5_ContractCompatibility compatibility;
   string                      reason_code;
   string                      reason_text;
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

struct SWV5_ExecutionRequestIdentity
{
   SWV5_ContractVersion contract_version;
   SWV5_RequestID       request_id;
   string               idempotency_key;
};

struct SWV5_BrokerExecutionIdentity
{
   SWV5_ContractVersion contract_version;
   ulong                order_ticket;
   ulong                deal_ticket;
   ulong                position_identifier;
   string               broker_event_id;
   ulong                transaction_sequence;
};

struct SWV5_ExecutionCorrelation
{
   SWV5_ContractVersion        contract_version;
   SWV5_ExecutionLifecyclePhase phase;
   SWV5_ExecutionRequestIdentity request_identity;
   SWV5_BrokerExecutionIdentity  broker_identity;
};

enum SWV5_DurableFingerprintPolicy
{
   SWV5_DURABLE_FINGERPRINT_POLICY_UNDEFINED=0,
   SWV5_DURABLE_FINGERPRINT_IDENTITY_ONLY=1,
   SWV5_DURABLE_FINGERPRINT_REQUIRED=2
};

struct SWV5_DurableEventIdentitySet
{
   SWV5_ContractVersion contract_version;
   // V4 candidate encoding is SWV5-DURABLE-EVENT-SET-V4-LP1: ordered,
   // typed, length-prefixed identity entries. Legacy delimiter indexes fail
   // closed; no runtime migration exists because V4 is not approved/locked.
   // IDENTITY_ONLY forbids fingerprint entries. REQUIRED enforces exactly one
   // canonical fingerprint mapping for every accepted identity in event order.
   SWV5_DurableFingerprintPolicy fingerprint_policy;
   string               canonical_event_index;
   string               canonical_fingerprint_index;
   string               identity_set_digest;
   uint                 accepted_identity_count;
   ulong                highest_transaction_sequence;
   ulong                index_revision;
   ulong                compaction_generation;
};

struct SWV5_OwnershipKey
{
   long   account_login;
   string broker_identity;
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

struct SWV5_OwnershipFence
{
   SWV5_ContractVersion contract_version;
   SWV5_OwnershipKey    ownership_namespace;
   SWV5_OwnerIdentity   owner;
   ulong                lease_version;
   ulong                takeover_generation;
   string               fencing_token_digest;
};

struct SWV5_PersistenceNamespace
{
   SWV5_ContractVersion contract_version;
   SWV5_OwnershipKey    ownership_namespace;
   SWV5_BasketID        basket_id;
};

struct SWV5_OperatorIdentity
{
   string   operator_id;
   string   authority_role;
   string   authentication_reference;
   datetime authenticated_at;
};

struct SWV5_AccountRiskNamespace
{
   SWV5_ContractVersion     contract_version;
   string                   broker_identity;
   string                   server;
   long                     account_login;
   string                   account_currency;
   string                   strategy_id;
   ulong                    magic;
   SWV5_AccountPositionMode account_mode;
   SWV5_AuthoritySource     authoritative_source;
   ulong                    snapshot_epoch;
   ulong                    snapshot_sequence;
};

struct SWV5_TypedReconciliationEvidence
{
   SWV5_ContractVersion   contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   string                 evidence_id;
   SWV5_ComponentAuthority issuing_component;
   SWV5_AuthoritySource   authority_source;
   ulong                  evidence_sequence;
   datetime               observed_at;
   string                 state_digest;
};

struct SWV5_ExposureReductionEvidence
{
   // This evidence is valid only as a nested member of a Hard Kill release
   // envelope. Its governed namespace is the enclosing release namespace,
   // bound to the current Hard Kill account-risk namespace by Risk validation.
   SWV5_ContractVersion   contract_version;
   string                 evidence_id;
   SWV5_ComponentAuthority issuing_component;
   SWV5_AuthoritySource   authority_source;
   double                 observed_exposure_volume;
   double                 prior_exposure_volume;
   bool                   zero_or_reducing;
   ulong                  evidence_sequence;
   datetime               observed_at;
};

enum SWV5_HardKillLatchState
{
   SWV5_HARD_KILL_INACTIVE = 0,
   SWV5_HARD_KILL_ACTIVE = 1,
   SWV5_HARD_KILL_RELEASE_PENDING = 2,
   SWV5_HARD_KILL_RELEASED = 3
};

struct SWV5_HardKillReleaseEvidence
{
   // The outer persistence namespace scopes every nested evidence record.
   // The current Hard Kill state supplies the full account-risk namespace.
   SWV5_ContractVersion  contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   string                release_id;
   string                latch_id;
   ulong                 latch_generation;
   ulong                 release_generation;
   SWV5_OperatorIdentity operator_identity;
   SWV5_ComponentAuthority approving_component;
   SWV5_TypedReconciliationEvidence broker_evidence;
   SWV5_TypedReconciliationEvidence persistence_evidence;
   SWV5_ExposureReductionEvidence exposure_evidence;
   datetime              approved_at;
   datetime              expires_at;
   string                audit_reference;
};

struct SWV5_HardKillState
{
   SWV5_ContractVersion         contract_version;
   SWV5_PersistenceNamespace    persistence_namespace;
   SWV5_AccountRiskNamespace    account_namespace;
   string                       latch_id;
   ulong                        latch_generation;
   SWV5_HardKillLatchState      state;
   string                       activation_reason;
   datetime                     activated_at;
   string                       activation_authority;
   ulong                        release_generation;
   SWV5_HardKillReleaseEvidence release_evidence;
};

const ulong SWV5_QUERY_POSITIONS = 1;
const ulong SWV5_QUERY_ORDERS = 2;
const ulong SWV5_QUERY_DEALS = 4;
const ulong SWV5_QUERY_TRANSACTIONS = 8;
const ulong SWV5_QUERY_PENDING_REQUESTS = 16;

struct SWV5_AuthoritativeQuerySet
{
   SWV5_ContractVersion contract_version;
   ulong                required_flags;
   ulong                completed_flags;
   ulong                authoritative_flags;
   ulong                observation_sequence;
};

struct SWV5_ContractDecision
{
   SWV5_ContractVersion     contract_version;
   SWV5_ContractDisposition disposition;
   ulong               reason_flags;
   string              reason_code;
   string              reason_text;
   int                 evaluated_schema_version;
   ulong               evaluation_sequence;
   datetime            evaluated_at;
};

class ISWV5ContractVersionPolicy
{
public:
   virtual string ContractName() = 0;
   virtual bool EvaluateCompatibility(const SWV5_ContractValidationContext &context,
                                      const SWV5_ContractVersion &candidate,
                                      SWV5_ContractCompatibilityResult &result) = 0;
};

#endif
