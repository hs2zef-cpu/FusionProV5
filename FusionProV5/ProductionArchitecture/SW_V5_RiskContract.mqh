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
   bool   hard_kill_enabled;
};

struct SWV5_AccountRiskSnapshot
{
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
   SWV5_BasketID basket_id;
   double        realized_net;
   double        unrealized_net;
   double        maximum_adverse_net;
   double        open_volume;
   ulong         cumulative_recovery_attempts;
   SWV5_BasketState state;
   datetime      observed_at;
};

struct SWV5_RiskEvaluationInput
{
   SWV5_ExecutionIntent      intent;
   SWV5_RiskLimits           limits;
   SWV5_AccountRiskSnapshot  account;
   SWV5_ExposureRiskSnapshot exposure;
   SWV5_BasketRiskSnapshot   basket;
   bool                      ownership_confirmed;
   bool                      hard_kill_latched;
};

struct SWV5_RiskAuthorization
{
   string                authorization_id;
   SWV5_RiskDisposition  disposition;
   SWV5_RiskDomain       blocking_domain;
   bool                  allowed;
   bool                  hard_kill_latched;
   ulong                 reason_flags;
   ulong                 basket_state_version;
   datetime              evaluated_at;
   datetime              expires_at;
   string                reason_text;
};

class ISWV5RiskContract
{
public:
   virtual string ContractName() = 0;
   virtual bool ValidateLimits(const SWV5_RiskLimits &limits,
                               SWV5_ContractDecision &decision) = 0;
   virtual bool Evaluate(const SWV5_RiskEvaluationInput &engineInput,
                         SWV5_RiskAuthorization &authorization) = 0;
   virtual bool ValidateAuthorization(const SWV5_RiskAuthorization &authorization,
                                      const SWV5_ExecutionIntent &intent,
                                      SWV5_ContractDecision &decision) = 0;
};

#endif
