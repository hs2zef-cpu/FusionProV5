#ifndef SW_V5_S5_MVP_ACCOUNT_OBSERVATION_PRODUCER_MQH
#define SW_V5_S5_MVP_ACCOUNT_OBSERVATION_PRODUCER_MQH

// Fresh, read-only initial-flat D1 observations. NO NAMESPACE TOKEN ISSUANCE.
#include "SW_V5_S5_MvpAccountRiskAuthority.mqh"
#include "SW_V5_S5_MvpBasketLifecycleAuthority.mqh"

class SWV5S5_MvpAccountObservationProducer
{
public:
   bool CaptureInitialFlat(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_ContractValidationContext &context,
                           const SWV5_PersistenceNamespace &scope,const SWV5_InstanceLease &lease,
                           ISWV5S5MvpReadOnlyPlatform &platform,SWV5S5_MvpAccountObservation &observed,
                           SWV5S5_MvpAccountObservationEnvelope &envelope)
   {
      ZeroMemory(envelope); ZeroMemory(observed);
      SWV5S5_MvpAccountRiskAuthority owner; SWV5S5_MvpAccountRiskAuthorityRecord record; SWV5S5_MvpAuthorityRow row;
      SWV5S5_MvpBasketLifecycleAuthority basket_owner; SWV5_BasketAggregate basket; SWV5S5_MvpAuthorityRow basket_row;
      if(!platform.CaptureFlatAccount(context.clock_time,observed) || !observed.complete || !observed.history_complete ||
         observed.observed_at!=context.clock_time || observed.trading_day_start<=0 || observed.trading_day_start>observed.observed_at ||
         observed.positions_total!=0 || observed.orders_total!=0 ||
         !owner.ValidateCurrent(store,scope,observed.profile,record,row) ||
         !basket_owner.ValidateCurrentBasket(store,context,scope,lease,basket,basket_row) ||
         basket.lifecycle.state!=SWV5_BASKET_IDLE || basket.lifecycle.aggregate_open_volume!=0.0 ||
         basket.lifecycle.live_position_count!=0 || basket.lifecycle.live_order_count!=0) return false;
      SWV5S5_MvpInitProductionVersion(envelope.account.contract_version);
      envelope.account.account_namespace=record.account_namespace;
      envelope.account.balance=observed.balance; envelope.account.equity=observed.equity;
      envelope.account.margin=observed.margin; envelope.account.free_margin=observed.free_margin;
      envelope.account.daily_realized_net=observed.daily_realized_net;
      envelope.account.daily_unrealized_net=observed.daily_unrealized_net;
      envelope.account.trading_day_start=observed.trading_day_start; envelope.account.observed_at=observed.observed_at;
      envelope.account.authoritative=true;
      SWV5S5_MvpInitProductionVersion(envelope.exposure.contract_version);
      envelope.exposure.account_namespace=record.account_namespace; envelope.exposure.symbol=observed.profile.symbol;
      // Zero derives from the complete physical account enumeration AND the
      // independent canonical flat Basket, never local request absence.
      envelope.exposure.observed_at=observed.observed_at; envelope.exposure.complete=true;
      envelope.namespace_record_digest=row.payload_digest;
      return SWV5S5_MvpObservationDigests(envelope.account,envelope.exposure,envelope.account_digest,
         envelope.exposure_digest,envelope.combined_digest);
   }
};

#endif // SW_V5_S5_MVP_ACCOUNT_OBSERVATION_PRODUCER_MQH
