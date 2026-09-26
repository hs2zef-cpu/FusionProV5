#ifndef SW_V5_S5_MVP_DEPLOYMENT_PROFILE_MQH
#define SW_V5_S5_MVP_DEPLOYMENT_PROFILE_MQH

// LOCKED DEMO DEPLOYMENT POLICY. This file is intentionally not generic.
// It grants no runtime authority and contains no broker mutation API.

#include "SW_V5_S5_MvpSqliteAuthorityStore.mqh"
#include "../../Configuration/SW_V5_RuntimeIdentityProfile.mqh"

const string SWV5S5_MVP_PROFILE_ID="FUSION-V5-DEMO-MVP-V1";
const string SWV5S5_MVP_RISK_POLICY_ID="FUSION-V5-DEMO-MVP-RISK-V1";
const string SWV5S5_MVP_SYMBOL="XAUUSD";
const string SWV5S5_MVP_ACCOUNT_CURRENCY="USD";
const string SWV5S5_MVP_OPERATOR_ROLE="FUSION_DEMO_MVP_OPERATOR";
const string SWV5S5_MVP_PRODUCER_INSTANCE="DEMO-MVP-GATE-V1";
const string SWV5S5_MVP_BASKET_RISK_POLICY="RESULTING_BASKET_MAXIMUM_ACCOUNT_CURRENCY_LOSS/V5";
const string SWV5S5_MVP_CONVERSION_SOURCE="ACCOUNT_CURRENCY_IDENTITY";
const double SWV5S5_MVP_POINT_SIZE=0.001;
const int    SWV5S5_MVP_DIGITS=3;
const double SWV5S5_MVP_MAX_VOLUME=0.01;
const double SWV5S5_MVP_MAX_EXISTING_MARGIN=0.01;
const double SWV5S5_MVP_COST_RESERVE_USD=1.00;
const uint   SWV5S5_MVP_SPECIFICATION_LIFETIME_SECONDS=10;
const uint   SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS=3600;

struct SWV5S5_MvpOperatorInvocation
{
   string operator_id;
   string authority_role;
   string authentication_reference;
   datetime authenticated_at;
};

struct SWV5S5_MvpRuntimeProfileObservation
{
   string broker_identity;
   string server;
   long account_login;
   string account_currency;
   string symbol;
   int account_trade_mode;
   SWV5_AccountPositionMode account_mode;
   bool connected;
   bool account_trade_allowed;
   bool account_trade_expert;
};

// Production DTOs nested inside Sprint 5 authority records retain the frozen
// Production Contract V5 identity. Sprint 5 wrapper DTOs use
// SWV5S5_InitContractVersion instead.
void SWV5S5_MvpInitProductionVersion(SWV5_ContractVersion &version)
{
   ZeroMemory(version);
   version.contract_name=SWV5_PRODUCTION_CONTRACT_NAME;
   version.schema_version=SWV5_PRODUCTION_CONTRACT_VERSION;
   version.minimum_compatible_version=SWV5_PRODUCTION_MINIMUM_COMPATIBLE_VERSION;
   version.policy_id=SWV5_PRODUCTION_CONTRACT_POLICY;
}

bool SWV5S5_MvpNear(const double left,const double right,const double tolerance=1.0e-9)
{
   return MathIsValidNumber(left) && MathIsValidNumber(right) && MathAbs(left-right)<=tolerance;
}

bool SWV5S5_MvpOperatorInvocationValid(const SWV5S5_MvpOperatorInvocation &invocation,
                                       const datetime now)
{
   return invocation.operator_id!="" && invocation.authority_role==SWV5S5_MVP_OPERATOR_ROLE &&
      invocation.authentication_reference!="" && invocation.authenticated_at==now && now>0;
}

bool SWV5S5_MvpProfileMatches(const SWV5S5_MvpRuntimeProfileObservation &observation,
                              const int demo_trade_mode)
{
   return observation.broker_identity!="" && observation.server!="" && observation.account_login>0 &&
      observation.account_currency==SWV5S5_MVP_ACCOUNT_CURRENCY &&
      observation.symbol==SWV5S5_MVP_SYMBOL && observation.account_trade_mode==demo_trade_mode &&
      observation.account_mode==SWV5_ACCOUNT_MODE_HEDGING && observation.connected;
}

void SWV5S5_MvpLoadRiskLimits(SWV5_RiskLimits &limits)
{
   ZeroMemory(limits);
   SWV5S5_MvpInitProductionVersion(limits.contract_version);
   limits.contract_id=SWV5S5_MVP_RISK_POLICY_ID;
   limits.minimum_equity=100.00;
   limits.maximum_daily_net_loss=10.00;
   limits.maximum_account_margin_fraction=0.10;
   limits.maximum_basket_loss=5.00;
   limits.maximum_basket_volume=0.01;
   limits.maximum_symbol_volume=0.01;
   limits.maximum_aggregate_volume=0.01;
   limits.maximum_aggregate_notional=10000.00;
   limits.maximum_live_baskets=1;
   limits.maximum_cumulative_recovery_attempts=1;
   limits.maximum_snapshot_age_seconds=5;
   limits.trading_day_policy=SWV5_TRADING_DAY_BROKER_SERVER;
   limits.trading_day_utc_offset_minutes=0;
   limits.hard_kill_enabled=true;
}

bool SWV5S5_MvpRiskLimitsExact(const SWV5_RiskLimits &limits)
{
   return limits.contract_id==SWV5S5_MVP_RISK_POLICY_ID &&
      SWV5S5_MvpNear(limits.minimum_equity,100.00) &&
      SWV5S5_MvpNear(limits.maximum_daily_net_loss,10.00) &&
      SWV5S5_MvpNear(limits.maximum_account_margin_fraction,0.10) &&
      SWV5S5_MvpNear(limits.maximum_basket_loss,5.00) &&
      SWV5S5_MvpNear(limits.maximum_basket_volume,0.01) &&
      SWV5S5_MvpNear(limits.maximum_symbol_volume,0.01) &&
      SWV5S5_MvpNear(limits.maximum_aggregate_volume,0.01) &&
      SWV5S5_MvpNear(limits.maximum_aggregate_notional,10000.00) &&
      limits.maximum_live_baskets==1 && limits.maximum_cumulative_recovery_attempts==1 &&
      limits.maximum_snapshot_age_seconds==5 &&
      limits.trading_day_policy==SWV5_TRADING_DAY_BROKER_SERVER &&
      limits.trading_day_utc_offset_minutes==0 && limits.hard_kill_enabled;
}

#endif // SW_V5_S5_MVP_DEPLOYMENT_PROFILE_MQH
