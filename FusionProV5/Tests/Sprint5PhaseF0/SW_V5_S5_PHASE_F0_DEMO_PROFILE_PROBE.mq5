#property strict
#property version "1.00"

// TEST ONLY / F0 / ATTENDED DEMO ONLY / NOT FOR PRODUCTION.
// NO SIGNAL INPUT. NO LOOP. NO RETRY. NO PENDING ORDERS. NO AUTO-CLOSE.
// Default configuration is disarmed and performs environment observation only.

input bool InpOperatorAttestsAttendedDemo=false;
input bool InpArmExactlyOneMarketSend=false;
input string InpExpectedServer="";
input ulong InpFrozenStrategyMagic=0;
input string InpCorrelationComment="";
input ENUM_ORDER_TYPE InpMarketSide=ORDER_TYPE_BUY;
input ENUM_ORDER_TYPE_FILLING InpMeasuredFilling=ORDER_FILLING_FOK;

bool g_send_attempted=false;

void SWV5S5_F0PrintEnvironment()
  {
   PrintFormat("F0_ENV|company=%s|server=%s|trade_mode=%d|margin_mode=%d|login_redacted=YES|terminal_build=%d|mql_build=%d|symbol=%s|connected=%d|server_time=%I64d|local_time=%I64d",
               AccountInfoString(ACCOUNT_COMPANY),AccountInfoString(ACCOUNT_SERVER),
               (int)AccountInfoInteger(ACCOUNT_TRADE_MODE),(int)AccountInfoInteger(ACCOUNT_MARGIN_MODE),
               (int)TerminalInfoInteger(TERMINAL_BUILD),(int)__MQLBUILD__,_Symbol,
               (int)TerminalInfoInteger(TERMINAL_CONNECTED),(long)TimeTradeServer(),(long)TimeLocal());
   PrintFormat("F0_SYMBOL|digits=%d|point=%.10f|tick_size=%.10f|tick_value=%.10f|tick_value_profit=%.10f|tick_value_loss=%.10f|contract_size=%.10f|volume_min=%.10f|volume_max=%.10f|volume_step=%.10f|filling_mode=%d|stops_level=%d|freeze_level=%d|trade_mode=%d|execution_mode=%d",
               (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS),SymbolInfoDouble(_Symbol,SYMBOL_POINT),
               SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),
               SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT),SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_LOSS),
               SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),
               SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),
               (int)SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE),(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
               (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL),(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE),
               (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_EXEMODE));
  }

bool SWV5S5_F0EnvironmentPermitsSingleProbe()
  {
   if(!InpOperatorAttestsAttendedDemo)
     { Print("F0_LOCAL_REJECT|operator_attestation_missing"); return false; }
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO)
     { Print("F0_LOCAL_REJECT|account_not_demo"); return false; }
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     { Print("F0_LOCAL_REJECT|account_not_hedging"); return false; }
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
     { Print("F0_LOCAL_REJECT|terminal_not_connected"); return false; }
   if(InpExpectedServer=="" || AccountInfoString(ACCOUNT_SERVER)!=InpExpectedServer)
     { Print("F0_LOCAL_REJECT|server_attestation_mismatch"); return false; }
   if(InpCorrelationComment=="")
     { Print("F0_LOCAL_REJECT|correlation_comment_empty"); return false; }
   if(InpMarketSide!=ORDER_TYPE_BUY && InpMarketSide!=ORDER_TYPE_SELL)
     { Print("F0_LOCAL_REJECT|pending_or_non_market_order_forbidden"); return false; }
   return true;
  }

int OnInit()
  {
   SWV5S5_F0PrintEnvironment();
   if(!InpArmExactlyOneMarketSend)
     { Print("F0_DISARMED|environment_observation_only"); return INIT_SUCCEEDED; }
   if(g_send_attempted || !SWV5S5_F0EnvironmentPermitsSingleProbe())
      return INIT_FAILED;

   g_send_attempted=true;
   MqlTradeRequest request={};
   MqlTradeResult result={};
   request.action=TRADE_ACTION_DEAL;
   request.symbol=_Symbol;
   request.magic=InpFrozenStrategyMagic;
   request.comment=InpCorrelationComment;
   request.type=InpMarketSide;
   request.volume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   request.price=(InpMarketSide==ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID));
   request.type_filling=InpMeasuredFilling;
   request.type_time=ORDER_TIME_GTC;

   const bool transport_result=OrderSend(request,result);
   PrintFormat("F0_SYNC|transport_result=%d|last_error=%d|retcode=%u|retcode_external=%d|request_id_session_local=%u|order=%I64u|deal=%I64u|volume=%.10f|price=%.10f|bid=%.10f|ask=%.10f|comment=%s",
               (int)transport_result,GetLastError(),result.retcode,result.retcode_external,result.request_id,
               result.order,result.deal,result.volume,result.price,result.bid,result.ask,result.comment);
   Print("F0_NO_RETRY|sync_result_is_not_confirmation|timeout_is_not_negative_evidence");
   return INIT_SUCCEEDED;
  }

void OnTrade()
  {
   Print("F0_ONTRADE|observational_only");
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   PrintFormat("F0_TX|arrival_observational_only=YES|type=%d|order=%I64u|deal=%I64u|position=%I64u|position_by=%I64u|symbol=%s|order_type=%d|order_state=%d|deal_type=%d|price=%.10f|volume=%.10f|request_action=%d|request_magic=%I64u|request_comment=%s|result_retcode=%u|result_external=%d|request_id_session_local=%u",
               (int)trans.type,trans.order,trans.deal,trans.position,trans.position_by,trans.symbol,
               (int)trans.order_type,(int)trans.order_state,(int)trans.deal_type,trans.price,trans.volume,
               (int)request.action,request.magic,request.comment,result.retcode,result.retcode_external,result.request_id);
  }

void OnDeinit(const int reason)
  {
   PrintFormat("F0_DEINIT|reason=%d|send_attempted=%d",reason,(int)g_send_attempted);
  }
