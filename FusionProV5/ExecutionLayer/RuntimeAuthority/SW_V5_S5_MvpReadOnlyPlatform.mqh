#ifndef SW_V5_S5_MVP_READ_ONLY_PLATFORM_MQH
#define SW_V5_S5_MVP_READ_ONLY_PLATFORM_MQH

// Read-only MT5 observation/calculation boundary for the locked Demo MVP.
// NO ORDER SEND, NO POSITION/ORDER MUTATION, NO CHART OR TERMINAL SETTING CHANGE.

#include "SW_V5_S5_MvpDeploymentProfile.mqh"

struct SWV5S5_MvpAccountObservation
{
   SWV5S5_MvpRuntimeProfileObservation profile;
   double balance;
   double equity;
   double margin;
   double free_margin;
   double daily_realized_net;
   double daily_unrealized_net;
   datetime trading_day_start;
   datetime observed_at;
   uint positions_total;
   uint orders_total;
   bool history_complete;
   bool complete;
};

class ISWV5S5MvpReadOnlyPlatform
{
public:
   virtual bool CaptureProfile(const string symbol,SWV5S5_MvpRuntimeProfileObservation &profile,
                               datetime &observed_at)=0;
   virtual bool CaptureSymbolSpecification(const string symbol,const ulong specification_sequence,
                                           const datetime observed_at,
                                           SWV5_SymbolUnitSpecification &specification)=0;
   virtual bool CaptureFlatAccount(const datetime observed_at,SWV5S5_MvpAccountObservation &account)=0;
   virtual bool CalculateMargin(const int direction,const string symbol,const double volume,
                                const double price,double &margin)=0;
   virtual bool CalculateProfit(const int direction,const string symbol,const double volume,
                                const double entry_price,const double stop_price,double &profit)=0;
};

class SWV5S5_MvpMt5ReadOnlyPlatform : public ISWV5S5MvpReadOnlyPlatform
{
private:
   SWV5_AccountPositionMode AccountMode(void) const
   {
      const long mode=AccountInfoInteger(ACCOUNT_MARGIN_MODE);
      if(mode==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) return SWV5_ACCOUNT_MODE_HEDGING;
      if(mode==ACCOUNT_MARGIN_MODE_RETAIL_NETTING || mode==ACCOUNT_MARGIN_MODE_EXCHANGE)
         return SWV5_ACCOUNT_MODE_NETTING;
      return SWV5_ACCOUNT_MODE_UNKNOWN;
   }

   bool CaptureDailyTradingNet(const datetime observed_at,datetime &day_start,double &net)
   {
      MqlDateTime parts;
      if(!TimeToStruct(observed_at,parts)) return false;
      parts.hour=0; parts.min=0; parts.sec=0;
      day_start=StructToTime(parts); net=0.0;
      if(day_start<=0 || !HistorySelect(day_start,observed_at)) return false;
      const int total=HistoryDealsTotal();
      if(total<0) return false;
      for(int i=0;i<total;i++)
      {
         ResetLastError();
         const ulong ticket=HistoryDealGetTicket(i);
         if(ticket==0 || GetLastError()!=0) return false;
         ResetLastError();
         const long type=HistoryDealGetInteger(ticket,DEAL_TYPE);
         const double profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);
         const double commission=HistoryDealGetDouble(ticket,DEAL_COMMISSION);
         const double swap=HistoryDealGetDouble(ticket,DEAL_SWAP);
         const double fee=HistoryDealGetDouble(ticket,DEAL_FEE);
         if(GetLastError()!=0 || !MathIsValidNumber(profit) || !MathIsValidNumber(commission) ||
            !MathIsValidNumber(swap) || !MathIsValidNumber(fee)) return false;
         if(type==DEAL_TYPE_BUY || type==DEAL_TYPE_SELL)
            net+=profit+commission+swap+fee;
      }
      return MathIsValidNumber(net);
   }

public:
   virtual bool CaptureProfile(const string symbol,SWV5S5_MvpRuntimeProfileObservation &profile,
                               datetime &observed_at)
   {
      ZeroMemory(profile);
      observed_at=TimeCurrent();
      if(observed_at<=0) return false;
      ResetLastError();
      profile.broker_identity=AccountInfoString(ACCOUNT_COMPANY);
      profile.server=AccountInfoString(ACCOUNT_SERVER);
      profile.account_login=AccountInfoInteger(ACCOUNT_LOGIN);
      profile.account_currency=AccountInfoString(ACCOUNT_CURRENCY);
      profile.symbol=symbol;
      profile.account_trade_mode=(int)AccountInfoInteger(ACCOUNT_TRADE_MODE);
      profile.account_mode=AccountMode();
      profile.connected=(bool)TerminalInfoInteger(TERMINAL_CONNECTED);
      profile.account_trade_allowed=(bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED);
      profile.account_trade_expert=(bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
      return GetLastError()==0 && profile.broker_identity!="" && profile.server!="" &&
         profile.account_login>0 && profile.account_currency!="";
   }

   virtual bool CaptureSymbolSpecification(const string symbol,const ulong specification_sequence,
                                           const datetime observed_at,
                                           SWV5_SymbolUnitSpecification &specification)
   {
      ZeroMemory(specification);
      if(symbol!=SWV5S5_MVP_SYMBOL || specification_sequence==0 || observed_at<=0) return false;
      long digits=0,stops=0,freeze=0,calculation_mode=0;
      double point=0.0,tick=0.0,tick_profit=0.0,tick_loss=0.0,contract_size=0.0;
      double volume_min=0.0,volume_max=0.0,volume_step=0.0;
      if(!SymbolInfoInteger(symbol,SYMBOL_DIGITS,digits) ||
         !SymbolInfoDouble(symbol,SYMBOL_POINT,point) ||
         !SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE,tick) ||
         !SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT,tick_profit) ||
         !SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_LOSS,tick_loss) ||
         !SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE,contract_size) ||
         !SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN,volume_min) ||
         !SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX,volume_max) ||
         !SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP,volume_step) ||
         !SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL,stops) ||
         !SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL,freeze) ||
         !SymbolInfoInteger(symbol,SYMBOL_TRADE_CALC_MODE,calculation_mode)) return false;
      const string account_currency=AccountInfoString(ACCOUNT_CURRENCY);
      if(digits!=SWV5S5_MVP_DIGITS || !SWV5S5_MvpNear(point,SWV5S5_MVP_POINT_SIZE) ||
         tick<=0.0 || tick_profit<=0.0 || tick_loss<=0.0 || contract_size<=0.0 ||
         volume_min<=0.0 || volume_max<volume_min || volume_step<=0.0 ||
         account_currency!=SWV5S5_MVP_ACCOUNT_CURRENCY || stops<0 || freeze<0) return false;
      SWV5S5_MvpInitProductionVersion(specification.contract_version);
      specification.symbol=symbol;
      specification.specification_sequence=specification_sequence;
      specification.digits=(int)digits;
      specification.point_size=point;
      specification.tick_size=tick;
      specification.pip_size=point*100.0;
      specification.tick_value_profit=tick_profit;
      specification.tick_value_loss=tick_loss;
      specification.contract_size=contract_size;
      specification.calculation_mode=SWV5_SYMBOL_CALCULATION_XAU_QUANTITY;
      specification.tick_value_basis_volume=1.0;
      specification.volume_minimum=volume_min;
      specification.volume_maximum=volume_max;
      specification.volume_step=volume_step;
      specification.stops_level_points=(int)stops;
      specification.freeze_level_points=(int)freeze;
      specification.account_currency=account_currency;
      specification.tick_value_currency=account_currency;
      specification.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
      specification.observed_at=observed_at;
      specification.valid_until=observed_at+(datetime)SWV5S5_MVP_SPECIFICATION_LIFETIME_SECONDS;
      specification.complete=true;
      return specification.pip_size==0.10 && calculation_mode>=0;
   }

   virtual bool CaptureFlatAccount(const datetime observed_at,SWV5S5_MvpAccountObservation &account)
   {
      ZeroMemory(account);
      datetime profile_at=0;
      if(!CaptureProfile(SWV5S5_MVP_SYMBOL,account.profile,profile_at) || profile_at!=observed_at ||
         !SWV5S5_MvpProfileMatches(account.profile,ACCOUNT_TRADE_MODE_DEMO)) return false;
      ResetLastError();
      account.balance=AccountInfoDouble(ACCOUNT_BALANCE);
      account.equity=AccountInfoDouble(ACCOUNT_EQUITY);
      account.margin=AccountInfoDouble(ACCOUNT_MARGIN);
      account.free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      account.positions_total=(uint)PositionsTotal();
      account.orders_total=(uint)OrdersTotal();
      account.observed_at=observed_at;
      account.daily_unrealized_net=0.0;
      if(GetLastError()!=0 || !MathIsValidNumber(account.balance) || !MathIsValidNumber(account.equity) ||
         !MathIsValidNumber(account.margin) || !MathIsValidNumber(account.free_margin) ||
         account.positions_total!=0 || account.orders_total!=0 || account.margin>SWV5S5_MVP_MAX_EXISTING_MARGIN)
         return false;
      account.history_complete=CaptureDailyTradingNet(observed_at,account.trading_day_start,
                                                       account.daily_realized_net);
      account.complete=account.history_complete;
      return account.complete;
   }

   virtual bool CalculateMargin(const int direction,const string symbol,const double volume,
                                const double price,double &margin)
   {
      margin=0.0;
      if(symbol!=SWV5S5_MVP_SYMBOL || (direction!=1 && direction!=-1) || volume<=0.0 ||
         volume>SWV5S5_MVP_MAX_VOLUME || price<=0.0) return false;
      const ENUM_ORDER_TYPE type=(direction==1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      return OrderCalcMargin(type,symbol,volume,price,margin) &&
         MathIsValidNumber(margin) && margin>0.0;
   }

   virtual bool CalculateProfit(const int direction,const string symbol,const double volume,
                                const double entry_price,const double stop_price,double &profit)
   {
      profit=0.0;
      if(symbol!=SWV5S5_MVP_SYMBOL || (direction!=1 && direction!=-1) || volume<=0.0 ||
         volume>SWV5S5_MVP_MAX_VOLUME || entry_price<=0.0 || stop_price<=0.0 ||
         (direction==1 && stop_price>=entry_price) || (direction==-1 && stop_price<=entry_price)) return false;
      const ENUM_ORDER_TYPE type=(direction==1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      return OrderCalcProfit(type,symbol,volume,entry_price,stop_price,profit) &&
         MathIsValidNumber(profit) && profit<0.0;
   }
};

#endif // SW_V5_S5_MVP_READ_ONLY_PLATFORM_MQH
