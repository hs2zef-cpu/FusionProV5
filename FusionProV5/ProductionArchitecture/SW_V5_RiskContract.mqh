#ifndef SW_V5_RISK_CONTRACT_MQH
#define SW_V5_RISK_CONTRACT_MQH

#include "SW_V5_ExecutionContract.mqh"

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
   ulong    snapshot_sequence;
   long     account_login;
   string   currency;
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
   ulong    snapshot_sequence;
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
   ulong         snapshot_sequence;
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

struct SWV5_ProjectedRequestRisk
{
   SWV5_ContractVersion contract_version;
   ulong    snapshot_sequence;
   string   symbol;
   double   projected_volume;
   double   projected_symbol_volume;
   double   projected_aggregate_volume;
   double   projected_notional;
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
   SWV5_RiskLimits           limits;
   SWV5_AccountRiskSnapshot  account;
   SWV5_ExposureRiskSnapshot exposure;
   SWV5_BasketRiskSnapshot   basket;
   SWV5_ProjectedRequestRisk projected;
   SWV5_OwnershipFence       ownership_fence;
   SWV5_HardKillState        hard_kill_state;
};

struct SWV5_RiskAuthorization
{
   SWV5_ContractVersion contract_version;
   string                authorization_id;
   string                limits_contract_id;
   SWV5_ExecutionCorrelation correlation;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence  ownership_fence;
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
   ulong                 account_risk_snapshot_sequence;
   ulong                 exposure_risk_snapshot_sequence;
   ulong                 basket_risk_snapshot_sequence;
   ulong                 projected_risk_snapshot_sequence;
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
   virtual string ContractName() = 0;
   virtual bool ValidateLimits(const SWV5_ContractValidationContext &context,
                               const SWV5_RiskLimits &limits,
                               SWV5_ContractDecision &decision) = 0;
   virtual bool Evaluate(const SWV5_ContractValidationContext &context,
                         const SWV5_RiskEvaluationInput &engineInput,
                         SWV5_RiskAuthorization &authorization) = 0;
   virtual bool ValidateAuthorization(const SWV5_ContractValidationContext &context,
                                      const SWV5_RiskAuthorization &authorization,
                                      const SWV5_ExecutionIntent &intent,
                                      SWV5_ContractDecision &decision) = 0;
   virtual bool ValidateHardKillRelease(const SWV5_ContractValidationContext &context,
                                        const SWV5_HardKillReleaseEvidence &evidence,
                                        SWV5_ContractDecision &decision) = 0;
};

#endif
