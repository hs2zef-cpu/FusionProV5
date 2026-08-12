#ifndef SW_V5_RISK_CONTRACT_MQH
#define SW_V5_RISK_CONTRACT_MQH

#include "SW_V5_UnitSystemContract.mqh"

enum SWV5_RiskDomain
{
   SWV5_RISK_DOMAIN_NONE = 0,
   SWV5_RISK_DOMAIN_ACCOUNT = 1,
   SWV5_RISK_DOMAIN_BASKET = 2,
   SWV5_RISK_DOMAIN_EXPOSURE = 3,
   SWV5_RISK_DOMAIN_EQUITY = 4,
   SWV5_RISK_DOMAIN_DAILY_LOSS = 5,
   SWV5_RISK_DOMAIN_HARD_KILL = 6,
   SWV5_RISK_DOMAIN_AGGREGATE_EXPOSURE = 7
};

enum SWV5_RiskDisposition
{
   SWV5_RISK_ALLOW = 0,
   SWV5_RISK_BLOCK_REQUEST = 1,
   SWV5_RISK_REDUCE_ONLY = 2,
   SWV5_RISK_CLOSE_ONLY = 3,
   SWV5_RISK_HALT_STRATEGY = 4,
   SWV5_RISK_HARD_KILL = 5,
   SWV5_RISK_RECONCILIATION_REQUIRED = 6
};

enum SWV5_TradingDayBoundaryPolicy
{
   SWV5_TRADING_DAY_UNDEFINED = 0,
   SWV5_TRADING_DAY_BROKER_SERVER = 1,
   SWV5_TRADING_DAY_UTC = 2,
   SWV5_TRADING_DAY_CONFIGURED_OFFSET = 3
};

enum SWV5_RiskCalculationBasis
{
   SWV5_RISK_BASIS_UNDEFINED = 0,
   SWV5_RISK_BASIS_MARK_TO_MARKET = 1,
   SWV5_RISK_BASIS_PROTECTIVE_STOP = 2,
   SWV5_RISK_BASIS_STRESS_SCENARIO = 3
};

enum SWV5_RiskSignConvention
{
   SWV5_RISK_SIGN_UNDEFINED = 0,
   SWV5_RISK_LOSS_NEGATIVE = 1,
   SWV5_RISK_LOSS_POSITIVE = 2
};

const ulong SWV5_RISK_ACCOUNT_LIMIT = 1;
const ulong SWV5_RISK_BASKET_LOSS_LIMIT = 2;
const ulong SWV5_RISK_SYMBOL_EXPOSURE_LIMIT = 4;
const ulong SWV5_RISK_EQUITY_FLOOR = 8;
const ulong SWV5_RISK_DAILY_LOSS_LIMIT = 16;
const ulong SWV5_RISK_AGGREGATE_EXPOSURE_LIMIT = 32;
const ulong SWV5_RISK_DATA_UNAVAILABLE = 64;
const ulong SWV5_RISK_OWNER_UNCONFIRMED = 128;
const ulong SWV5_RISK_HARD_KILL_LATCHED = 256;

struct SWV5_RiskLimits
{
   SWV5_ContractVersion contract_version;
   string contract_id;
   double minimum_equity;
   double maximum_daily_net_loss;
   double maximum_account_margin_fraction;
   double maximum_basket_loss;
   double maximum_basket_volume;
   double maximum_symbol_volume;
   double maximum_aggregate_volume;
   double maximum_aggregate_notional;
   uint   maximum_live_baskets;
   uint   maximum_cumulative_recovery_attempts;
   uint   maximum_snapshot_age_seconds;
   SWV5_TradingDayBoundaryPolicy trading_day_policy;
   int    trading_day_utc_offset_minutes;
   bool   hard_kill_enabled;
};

struct SWV5_AccountRiskSnapshot
{
   SWV5_ContractVersion contract_version;
   SWV5_AccountRiskNamespace account_namespace;
   double   balance;
   double   equity;
   double   margin;
   double   free_margin;
   double   daily_realized_net;
   double   daily_unrealized_net;
   datetime trading_day_start;
   datetime observed_at;
   bool     authoritative;
};

struct SWV5_ExposureRiskSnapshot
{
   SWV5_ContractVersion contract_version;
   SWV5_AccountRiskNamespace account_namespace;
   string   symbol;
   double   symbol_long_volume;
   double   symbol_short_volume;
   double   symbol_net_volume;
   double   aggregate_volume;
   double   aggregate_notional;
   uint     live_basket_count;
   datetime observed_at;
   bool     complete;
};

struct SWV5_BasketRiskSnapshot
{
   SWV5_ContractVersion contract_version;
   SWV5_AccountRiskNamespace account_namespace;
   SWV5_BasketLifecycleSnapshot lifecycle;
   double        realized_net;
   double        unrealized_net;
   double        maximum_adverse_net;
   datetime      observed_at;
};

struct SWV5_RiskMonetaryBasis
{
   SWV5_ContractVersion    contract_version;
   string                  currency;
   string                  account_currency;
   double                  conversion_rate_to_account_currency;
   string                  conversion_source;
   datetime                valuation_at;
   SWV5_RiskCalculationBasis calculation_basis;
   SWV5_RiskSignConvention sign_convention;
   bool                    includes_realized;
   bool                    includes_unrealized;
   bool                    includes_commission;
   bool                    includes_swap;
   bool                    includes_fee;
};

struct SWV5_MarginProjectionEvidence
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_AccountRiskNamespace account_namespace;
   SWV5_OwnershipFence ownership_fence;
   SWV5_ExecutionRequestIdentity request_identity;
   SWV5_BasketID basket_id;
   string symbol;
   ulong symbol_specification_sequence;
   SWV5_ExecutionIntentType intent_type;
   int direction;
   double requested_volume;
   double requested_price;
   double current_account_margin;
   double current_free_margin;
   double projected_account_margin;
   double additional_margin;
   string account_currency;
   SWV5_ComponentAuthority issuing_component;
   SWV5_AuthoritySource authority_source;
   string calculation_reference;
   datetime observed_at;
   datetime calculated_at;
   ulong evidence_sequence;
   // Reference to the independently supplied Broker Margin Authority record.
   string authority_record_id;
   ulong authority_record_sequence;
   string authority_record_digest;
   // Canonical V5 typed length-prefixed digest; excludes this field itself.
   string evidence_digest;
};

// Independently supplied by the Broker Adapter / Broker Margin Authority.
// Risk Governance consumes this record but must not reconstruct it from the
// request-side projection evidence that it validates.
struct SWV5_MarginAuthorityRecord
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_AccountRiskNamespace account_namespace;
   SWV5_OwnershipFence ownership_fence;
   SWV5_ExecutionRequestIdentity request_identity;
   SWV5_BasketID basket_id;
   string symbol;
   ulong symbol_specification_sequence;
   SWV5_ExecutionIntentType intent_type;
   int direction;
   double requested_volume;
   double requested_price;
   double current_account_margin;
   double projected_account_margin;
   double additional_margin;
   double current_free_margin;
   string account_currency;
   string broker_calculation_reference;
   ulong observation_sequence;
   datetime observed_at;
   datetime calculated_at;
   string authority_record_id;
   ulong authority_record_sequence;
   // Canonical V5 typed length-prefixed digest; excludes only this field.
   string authority_record_digest;
   SWV5_ComponentAuthority issuing_component;
   SWV5_AuthoritySource authority_source;
};

struct SWV5_BasketRiskProjectionEvidence
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_AccountRiskNamespace account_namespace;
   SWV5_OwnershipFence ownership_fence;
   SWV5_BasketID basket_id;
   ulong basket_state_version;
   SWV5_ExecutionRequestIdentity request_identity;
   string symbol;
   ulong symbol_specification_sequence;
   double existing_bounded_basket_loss;
   double incremental_request_bounded_loss;
   double interaction_or_offset_adjustment;
   double resulting_basket_maximum_loss;
   double realized_loss_basis;
   double unrealized_loss_basis;
   double accrued_cost_basis;
   SWV5_RiskMonetaryBasis monetary_basis;
   string calculation_policy_id;
   string source_snapshot_digest;
   SWV5_ComponentAuthority issuing_component;
   SWV5_AuthoritySource authority_source;
   datetime observed_at;
   datetime calculated_at;
   ulong evidence_sequence;
   // Reference to the separately supplied Risk Governance authority record.
   string authority_record_id;
   ulong authority_record_sequence;
   string authority_record_digest;
   // Canonical V5 typed length-prefixed digest; excludes this field itself.
   string evidence_digest;
};

// Independent resulting-Basket Risk authority. Broker/live position facts and
// Basket lifecycle state are inputs to Risk Governance; the caller projection
// cannot originate this record or its source-snapshot identity.
struct SWV5_BasketRiskAuthorityRecord
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_AccountRiskNamespace account_namespace;
   SWV5_OwnershipFence ownership_fence;
   SWV5_BasketID basket_id;
   ulong basket_state_version;
   SWV5_ExecutionRequestIdentity request_identity;
   string symbol;
   ulong symbol_specification_sequence;
   string source_snapshot_id;
   string source_snapshot_digest;
   double existing_bounded_basket_loss;
   double incremental_request_bounded_loss;
   double interaction_or_offset_adjustment;
   double resulting_basket_maximum_loss;
   double realized_loss_basis;
   double unrealized_loss_basis;
   double accrued_cost_basis;
   SWV5_RiskMonetaryBasis monetary_basis;
   string calculation_policy_id;
   ulong observation_sequence;
   datetime observed_at;
   datetime calculated_at;
   string authority_record_id;
   ulong authority_record_sequence;
   // Canonical V5 typed length-prefixed digest; excludes only this field.
   string authority_record_digest;
   SWV5_ComponentAuthority issuing_component;
   SWV5_AuthoritySource authority_source;
};

struct SWV5_ProjectedRequestRisk
{
   SWV5_ContractVersion contract_version;
   SWV5_AccountRiskNamespace account_namespace;
   string   symbol;
   // Post-operation gross Basket, symbol and account exposure. Under the
   // HEDGING policy these fields must causally account for the requested
   // operation; they are not caller-supplied limit hints.
   double   projected_volume;
   double   projected_symbol_volume;
   double   projected_aggregate_volume;
   // Post-operation aggregate notional in monetary_basis account currency.
   double   projected_notional;
   SWV5_MarginProjectionEvidence margin_evidence;
   SWV5_BasketRiskProjectionEvidence basket_risk_evidence;
   // Non-authoritative compatibility mirrors. V5 validators require exact
   // equality with the nested authoritative evidence and never trust them alone.
   double   projected_margin;
   double   projected_maximum_loss;
   SWV5_RiskMonetaryBasis monetary_basis;
   datetime calculated_at;
   bool     complete;
};

struct SWV5_RiskEvaluationInput
{
   SWV5_ContractVersion     contract_version;
   SWV5_ExecutionIntent      intent;
   SWV5_AccountRiskNamespace account_namespace;
   SWV5_AccountPositionMode  account_mode;
   SWV5_RiskLimits           limits;
   SWV5_AccountRiskSnapshot  account;
   SWV5_ExposureRiskSnapshot exposure;
   SWV5_BasketRiskSnapshot   basket;
   SWV5_ProjectedRequestRisk projected;
   bool has_margin_authority_record;
   SWV5_MarginAuthorityRecord margin_authority_record;
   bool has_basket_risk_authority_record;
   SWV5_BasketRiskAuthorityRecord basket_risk_authority_record;
   SWV5_SymbolUnitSpecification symbol_specification;
   SWV5_OwnershipFence       ownership_fence;
   SWV5_HardKillState        hard_kill_state;
};

struct SWV5_RiskAuthorization
{
   SWV5_ContractVersion contract_version;
   string                authorization_id;
   string                limits_contract_id;
   SWV5_RiskLimits       authorized_limits;
   SWV5_ExecutionRequestIdentity request_identity;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence  ownership_fence;
   SWV5_AccountRiskNamespace account_namespace;
   SWV5_AccountPositionMode account_mode;
   SWV5_RiskDisposition  disposition;
   SWV5_RiskDomain       blocking_domain;
   ulong                 reason_flags;
   ulong                 basket_state_version;
   ulong                 symbol_specification_sequence;
   SWV5_ExecutionIntentType authorized_intent_type;
   int                   authorized_direction;
   double                authorized_volume;
   double                authorized_price;
   double                authorized_stop_price;
   double                authorized_limit_price;
   ulong                 risk_snapshot_epoch;
   ulong                 risk_snapshot_sequence;
   double                authorized_projected_loss;
   double                authorized_projected_notional;
   double                authorized_projected_margin;
   string                hard_kill_latch_id;
   ulong                 hard_kill_latch_generation;
   SWV5_RiskMonetaryBasis monetary_basis;
   datetime              evaluated_at;
   datetime              expires_at;
   string                reason_text;
};

class ISWV5RiskContract
{
public:
   // Evaluate is an independent fail-closed boundary. It must validate the
   // complete current Risk envelope even when Execution validated the intent.
   virtual string ContractName() = 0;
   virtual bool ValidateLimits(const SWV5_ContractValidationContext &context,
                               const SWV5_RiskLimits &limits,
                               SWV5_ContractDecision &decision) = 0;
   virtual bool Evaluate(const SWV5_ContractValidationContext &context,
                         const SWV5_RiskEvaluationInput &engineInput,
                         SWV5_RiskAuthorization &authorization) = 0;
   virtual bool ValidateAuthorization(const SWV5_ContractValidationContext &context,
                                      const SWV5_RiskAuthorization &authorization,
                                      const SWV5_RiskEvaluationInput &current_binding,
                                      SWV5_ContractDecision &decision) = 0;
   virtual bool ValidateHardKillRelease(const SWV5_ContractValidationContext &context,
                                        const SWV5_HardKillState &current_state,
                                        const SWV5_HardKillReleaseEvidence &evidence,
                                        SWV5_ContractDecision &decision) = 0;
   virtual bool ValidateHardKillReleaseMode(const SWV5_ContractValidationContext &context,
                                        const SWV5_HardKillState &current_state,
                                        const SWV5_HardKillReleaseEvidence &evidence,
                                        const SWV5_HardKillReleaseValidationMode mode,
                                        SWV5_ContractDecision &decision) = 0;
   // This legacy-shaped mode boundary is valid for CURRENT_EXECUTION only.
   // HISTORICAL_PERSISTED must use ValidateHistoricalHardKillRelease because
   // it cannot be authorized without the independent record input.
   // Historical RELEASED authority is a two-trust-domain validation. The
   // checkpoint-local evidence is diagnostic/content data; the independently
   // supplied authority record is the semantic authorization input.
   virtual bool ValidateHistoricalHardKillRelease(const SWV5_ContractValidationContext &context,
                                        const SWV5_HardKillState &persisted_state,
                                        const SWV5_HardKillReleaseEvidence &checkpoint_evidence,
                                        const SWV5_HardKillReleaseAuthorityRecord &authority_record,
                                        SWV5_ContractDecision &decision) = 0;
};

#endif
