#ifndef SW_V5_S5_F_BROKER_PLATFORM_BOUNDARY_MQH
#define SW_V5_S5_F_BROKER_PLATFORM_BOUNDARY_MQH

// SPRINT 5 PHASE F BROKER ADAPTER — EXCLUSIVE MT5 PLATFORM BOUNDARY
// Direct account/symbol/query/callback/OrderSend APIs are confined here.
// Compiling this boundary does not authorize or perform a broker-mutating run.

#include "SW_V5_S5_F_BrokerAdapterCore.mqh"

class SWV5S5_F_BrokerPlatformAdapter
{
private:
   bool m_send_consumed;
   string m_broker_read_path_id;
   string m_broker_authority_instance_id;
   ulong m_connection_generation;
   ulong m_restart_generation;

   bool CaptureEnvironment(const string symbol,SWV5S5_F_AdapterEnvironment &environment) const
   {
      ZeroMemory(environment);
      environment.broker_identity=AccountInfoString(ACCOUNT_COMPANY);
      environment.server=AccountInfoString(ACCOUNT_SERVER);
      environment.account_login=AccountInfoInteger(ACCOUNT_LOGIN);
      environment.account_currency=AccountInfoString(ACCOUNT_CURRENCY);
      environment.symbol=symbol;
      environment.terminal_build=(int)TerminalInfoInteger(TERMINAL_BUILD);
      environment.mql_build=(int)__MQLBUILD__;
      environment.account_trade_mode=(int)AccountInfoInteger(ACCOUNT_TRADE_MODE);
      environment.account_mode=(SWV5_AccountPositionMode)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
      environment.connected=(bool)TerminalInfoInteger(TERMINAL_CONNECTED);
      environment.terminal_trade_allowed=(bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
      environment.mql_trade_allowed=(bool)MQLInfoInteger(MQL_TRADE_ALLOWED);
      environment.account_trade_allowed=(bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED);
      environment.account_trade_expert=(bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
      environment.symbol_trade_mode=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
      environment.symbol_execution_mode=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_EXEMODE);
      environment.symbol_filling_mask=(ulong)SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
      environment.symbol_digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
      environment.point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      environment.tick_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      environment.volume_min=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
      environment.volume_max=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
      environment.volume_step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
      environment.runtime_magic=SWV5_RUNTIME_STRATEGY_MAGIC;
      return environment.broker_identity!="" && environment.server!="" &&
         environment.account_login>0 && environment.account_currency!="" &&
         environment.symbol!="" && environment.terminal_build>0 && environment.mql_build>0;
   }

   ENUM_ORDER_TYPE_FILLING PlatformFilling(const ulong capability_flag) const
   {
      if(capability_flag==2) return ORDER_FILLING_IOC;
      return ORDER_FILLING_FOK;
   }

   bool CanonicalQuerySnapshot(SWV5S5_F_BrokerQuerySnapshot &snapshot,string &digest) const
   {
      string body="",f,row;
      if(!SWV5S5_CanonicalString("profile_digest",snapshot.profile.profile_digest,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("broker_read_path_id",snapshot.broker_read_path_id,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("broker_authority_instance_id",snapshot.broker_authority_instance_id,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("owner_query_sequence",snapshot.owner_query_sequence,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("connection_generation",snapshot.connection_generation,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("restart_generation",snapshot.restart_generation,f)) return false; body+=f;
      if(!SWV5S5_CanonicalDatetime("history_from",snapshot.history_from,f)) return false; body+=f;
      if(!SWV5S5_CanonicalDatetime("history_to",snapshot.history_to,f)) return false; body+=f;
      if(!SWV5S5_CanonicalDatetime("observed_at",snapshot.observed_at,f)) return false; body+=f;
      if(!SWV5S5_CanonicalBool("positions_complete",snapshot.positions_enumeration_complete,f)) return false; body+=f;
      if(!SWV5S5_CanonicalBool("orders_complete",snapshot.orders_enumeration_complete,f)) return false; body+=f;
      if(!SWV5S5_CanonicalBool("history_orders_complete",snapshot.history_orders_enumeration_complete,f)) return false; body+=f;
      if(!SWV5S5_CanonicalBool("history_deals_complete",snapshot.history_deals_enumeration_complete,f)) return false; body+=f;
      if(!SWV5S5_CanonicalBool("callbacks_complete",snapshot.callback_transactions_enumeration_complete,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("positions_total",snapshot.positions_reported_total,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("orders_total",snapshot.orders_reported_total,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("history_orders_total",snapshot.history_orders_reported_total,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("history_deals_total",snapshot.history_deals_reported_total,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("callbacks_total",snapshot.callback_transactions_reported_total,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("row_read_failures",snapshot.row_read_failures,f)) return false; body+=f;
      for(int i=0;i<ArraySize(snapshot.positions);i++)
      {
         row="";
         if(!SWV5S5_CanonicalBool("read",snapshot.positions[i].read_success,f)) return false; row+=f;
         if(!SWV5S5_CanonicalUInt("ticket",snapshot.positions[i].ticket,f)) return false; row+=f;
         if(!SWV5S5_CanonicalUInt("position",snapshot.positions[i].position_identifier,f)) return false; row+=f;
         if(!SWV5S5_CanonicalString("symbol",snapshot.positions[i].symbol,f)) return false; row+=f;
         if(!SWV5S5_CanonicalUInt("magic",snapshot.positions[i].magic,f)) return false; row+=f;
         if(!SWV5S5_CanonicalInt("direction",snapshot.positions[i].direction,f)) return false; row+=f;
         if(!SWV5S5_CanonicalDouble("volume",snapshot.positions[i].volume,f)) return false; row+=f;
         if(!SWV5S5_CanonicalDatetime("time_msc",snapshot.positions[i].time_msc,f)) return false; row+=f;
         if(!SWV5S5_CanonicalString("comment",snapshot.positions[i].comment,f)) return false; row+=f;
         if(!SWV5S5_CanonicalIndexed("position_row",(ulong)i,row,f)) return false; body+=f;
      }
      for(int i=0;i<ArraySize(snapshot.orders);i++)
      {
         row="";
         if(!SWV5S5_CanonicalBool("read",snapshot.orders[i].read_success,f)) return false; row+=f;
         if(!SWV5S5_CanonicalUInt("ticket",snapshot.orders[i].ticket,f)) return false; row+=f;
         if(!SWV5S5_CanonicalUInt("position",snapshot.orders[i].position_identifier,f)) return false; row+=f;
         if(!SWV5S5_CanonicalString("symbol",snapshot.orders[i].symbol,f)) return false; row+=f;
         if(!SWV5S5_CanonicalUInt("magic",snapshot.orders[i].magic,f)) return false; row+=f;
         if(!SWV5S5_CanonicalInt("order_type",snapshot.orders[i].order_type,f)) return false; row+=f;
         if(!SWV5S5_CanonicalInt("order_state",snapshot.orders[i].order_state,f)) return false; row+=f;
         if(!SWV5S5_CanonicalDouble("volume_initial",snapshot.orders[i].volume_initial,f)) return false; row+=f;
         if(!SWV5S5_CanonicalDouble("volume_current",snapshot.orders[i].volume_current,f)) return false; row+=f;
         if(!SWV5S5_CanonicalDatetime("setup_time_msc",snapshot.orders[i].setup_time_msc,f)) return false; row+=f;
         if(!SWV5S5_CanonicalDatetime("done_time_msc",snapshot.orders[i].done_time_msc,f)) return false; row+=f;
         if(!SWV5S5_CanonicalString("comment",snapshot.orders[i].comment,f)) return false; row+=f;
         if(!SWV5S5_CanonicalIndexed("active_order_row",(ulong)i,row,f)) return false; body+=f;
      }
      for(int i=0;i<ArraySize(snapshot.history_orders);i++)
      {
         row="";
         if(!SWV5S5_CanonicalBool("read",snapshot.history_orders[i].read_success,f)) return false; row+=f;
         if(!SWV5S5_CanonicalUInt("ticket",snapshot.history_orders[i].ticket,f)) return false; row+=f;
         if(!SWV5S5_CanonicalUInt("position",snapshot.history_orders[i].position_identifier,f)) return false; row+=f;
         if(!SWV5S5_CanonicalString("symbol",snapshot.history_orders[i].symbol,f)) return false; row+=f;
         if(!SWV5S5_CanonicalUInt("magic",snapshot.history_orders[i].magic,f)) return false; row+=f;
         if(!SWV5S5_CanonicalInt("order_type",snapshot.history_orders[i].order_type,f)) return false; row+=f;
         if(!SWV5S5_CanonicalInt("order_state",snapshot.history_orders[i].order_state,f)) return false; row+=f;
         if(!SWV5S5_CanonicalDouble("volume_initial",snapshot.history_orders[i].volume_initial,f)) return false; row+=f;
         if(!SWV5S5_CanonicalDouble("volume_current",snapshot.history_orders[i].volume_current,f)) return false; row+=f;
         if(!SWV5S5_CanonicalDatetime("setup_time_msc",snapshot.history_orders[i].setup_time_msc,f)) return false; row+=f;
         if(!SWV5S5_CanonicalDatetime("done_time_msc",snapshot.history_orders[i].done_time_msc,f)) return false; row+=f;
         if(!SWV5S5_CanonicalString("comment",snapshot.history_orders[i].comment,f)) return false; row+=f;
         if(!SWV5S5_CanonicalIndexed("history_order_row",(ulong)i,row,f)) return false; body+=f;
      }
      for(int i=0;i<ArraySize(snapshot.history_deals);i++)
      {
         row="";
         if(!SWV5S5_CanonicalBool("read",snapshot.history_deals[i].read_success,f)) return false; row+=f;
         if(!SWV5S5_CanonicalUInt("ticket",snapshot.history_deals[i].ticket,f)) return false; row+=f;
         if(!SWV5S5_CanonicalUInt("order",snapshot.history_deals[i].order_ticket,f)) return false; row+=f;
         if(!SWV5S5_CanonicalUInt("position",snapshot.history_deals[i].position_identifier,f)) return false; row+=f;
         if(!SWV5S5_CanonicalString("symbol",snapshot.history_deals[i].symbol,f)) return false; row+=f;
         if(!SWV5S5_CanonicalUInt("magic",snapshot.history_deals[i].magic,f)) return false; row+=f;
         if(!SWV5S5_CanonicalInt("deal_type",snapshot.history_deals[i].deal_type,f)) return false; row+=f;
         if(!SWV5S5_CanonicalInt("entry_type",snapshot.history_deals[i].entry_type,f)) return false; row+=f;
         if(!SWV5S5_CanonicalDouble("volume",snapshot.history_deals[i].volume,f)) return false; row+=f;
         if(!SWV5S5_CanonicalDouble("price",snapshot.history_deals[i].price,f)) return false; row+=f;
         if(!SWV5S5_CanonicalDatetime("time_msc",snapshot.history_deals[i].time_msc,f)) return false; row+=f;
         if(!SWV5S5_CanonicalString("comment",snapshot.history_deals[i].comment,f)) return false; row+=f;
         if(!SWV5S5_CanonicalIndexed("history_deal_row",(ulong)i,row,f)) return false; body+=f;
      }
      for(int i=0;i<ArraySize(snapshot.callback_transactions);i++)
      {
         string callback_digest;
         if(!SWV5S5_F_DeriveCallbackDigest(snapshot.callback_transactions[i],callback_digest) ||
            callback_digest!=snapshot.callback_transactions[i].evidence_digest ||
            !SWV5S5_CanonicalString("callback_digest",callback_digest,row) ||
            !SWV5S5_CanonicalIndexed("callback_row",(ulong)i,row,f)) return false; body+=f;
      }
      if(!SWV5S5_CanonicalBool("completeness_claimed",snapshot.completeness_claimed,f)) return false; body+=f;
      if(!SWV5S5_CanonicalBool("visibility_watermark_claimed",snapshot.visibility_watermark_claimed,f)) return false; body+=f;
      return SWV5S5_DomainDigest(SWV5S5_F_ADAPTER_DOMAIN_QUERY,body,digest);
   }

public:
   SWV5S5_F_BrokerPlatformAdapter(const string broker_read_path_id,
                                  const string broker_authority_instance_id,
                                  const ulong connection_generation,
                                  const ulong restart_generation)
   {
      m_send_consumed=false;
      m_broker_read_path_id=broker_read_path_id;
      m_broker_authority_instance_id=broker_authority_instance_id;
      m_connection_generation=connection_generation;
      m_restart_generation=restart_generation;
   }

   // Exactly one invocation is possible per adapter instance. The accepted
   // ephemeral Claim must belong to this call. Failure never retries.
   bool SubmitExactlyOnce(SWV5S5_F_AdapterSubmissionCommand &command,
                          ISWV5S5FBrokerEvidenceStore &evidence_store,
                          SWV5S5_F_AdapterSyncResult &captured)
   {
      ZeroMemory(captured);
      captured.retry_allowed=false;
      captured.final_confirmation=false;
      if(m_send_consumed)
      { captured.classification=SWV5S5_F_ADAPTER_SYNC_PRE_CALL_REJECTED; captured.reason_code="ADAPTER_INSTANCE_SEND_ALREADY_CONSUMED"; return false; }
      // A submission command is one-shot even when local preflight rejects it.
      // Permission/profile changes therefore require a new authoritative flow;
      // this object can never turn a failed call into an implicit retry.
      m_send_consumed=true;
      if(!CaptureEnvironment(command.expected_profile.symbol,command.observed_environment))
      { captured.classification=SWV5S5_F_ADAPTER_SYNC_PRE_CALL_REJECTED; captured.reason_code="ENVIRONMENT_CAPTURE_FAILED"; return false; }
      string preflight_reason;
      if(SWV5S5_F_AdapterValidatePreflight(command,preflight_reason)!=SWV5S5_F_ADAPTER_PREFLIGHT_READY_CURRENT_CLAIM)
      { captured.classification=SWV5S5_F_ADAPTER_SYNC_PRE_CALL_REJECTED; captured.reason_code=preflight_reason; return false; }

      // Consumed immediately before the only broker mutation boundary. No code
      // path resets this latch and no reconnect callback invokes this method.
      MqlTradeRequest request={};
      MqlTradeResult result={};
      request.action=TRADE_ACTION_DEAL;
      request.symbol=command.expected_profile.symbol;
      request.magic=SWV5_RUNTIME_STRATEGY_MAGIC;
      request.comment=command.comment_metadata;
      request.type=(command.direction==1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      request.volume=command.volume;
      request.price=command.price;
      request.sl=command.stop_price;
      request.tp=command.limit_price;
      request.type_filling=PlatformFilling(command.filling_mode);
      request.type_time=ORDER_TIME_GTC;

      ResetLastError();
      captured.invocation_attempted=true;
      captured.transport_result=OrderSend(request,result);
      captured.last_error=GetLastError();
      captured.retcode=result.retcode;
      captured.retcode_external=(uint)result.retcode_external;
      captured.request_id_session_local=result.request_id;
      captured.order_ticket=result.order;
      captured.deal_ticket=result.deal;
      captured.volume=result.volume;
      captured.price=result.price;
      captured.bid=result.bid;
      captured.ask=result.ask;
      captured.comment=result.comment;
      captured.classification=SWV5S5_F_AdapterClassifySync(true,captured.transport_result,captured.retcode);
      captured.final_confirmation=false;
      captured.retry_allowed=false;
      captured.claim_id=command.authoritative_claim.resulting_authority_record.invocation_claim_id;
      captured.claim_record_digest=command.authoritative_claim.resulting_authority_record.durable_record_digest;
      captured.request_correlation_id=command.authoritative_claim.resulting_authority_record.permit.request_identity.request_id.correlation_id;
      captured.attempt_id=command.authoritative_claim.resulting_authority_record.permit.unique_attempt_id;
      captured.profile_digest=command.expected_profile.profile_digest;
      if(!SWV5S5_F_DeriveAdapterEnvironmentDigest(command.observed_environment,
                                                   captured.observed_environment_digest)) return false;
      captured.reason_code="SYNCHRONOUS_RESULT_CAPTURED_RECONCILIATION_REQUIRED";
      if(!SWV5S5_F_DeriveAdapterSyncResultDigest(captured,captured.result_digest)) return false;
      return evidence_store.PersistSubmissionResult(command,captured);
   }

   // Caller supplies the already-bound durable reconciliation context. This
   // method captures evidence only; it grants no authority and confirms nothing.
   bool CaptureCallback(const SWV5_ContractValidationContext &context,
                        const ulong callback_sequence,
                        const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result,
                        ISWV5S5FBrokerEvidenceStore &evidence_store)
   {
      SWV5S5_F_ReconciliationBinding binding;
      ZeroMemory(binding);
      if(!evidence_store.ResolveCallbackBinding(transaction.order,transaction.deal,
         transaction.position,result.request_id,request.magic,binding)) return false;
      if(!SWV5S5_F_IsBindingValid(context,binding) || callback_sequence==0) return false;
      SWV5S5_F_AdapterCallbackEvidence evidence;
      ZeroMemory(evidence); SWV5S5_F_InitVersion(evidence.contract_version);
      evidence.request_correlation_id=binding.request_identity.request_id.correlation_id;
      evidence.attempt_id=binding.request_identity.request_id.attempt_id;
      evidence.invocation_claim_id=binding.invocation_claim_id;
      evidence.claim_record_digest=binding.claim_record_digest;
      evidence.profile_digest=binding.profile.profile_digest;
      evidence.callback_sequence=callback_sequence;
      evidence.observed_at=TimeTradeServer();
      evidence.transaction_type=(int)transaction.type;
      evidence.order_ticket=transaction.order;
      evidence.deal_ticket=transaction.deal;
      evidence.position_identifier=transaction.position;
      evidence.position_by_identifier=transaction.position_by;
      evidence.symbol=transaction.symbol;
      evidence.order_type=(int)transaction.order_type;
      evidence.order_state=(int)transaction.order_state;
      evidence.deal_type=(int)transaction.deal_type;
      evidence.price=transaction.price;
      evidence.volume=transaction.volume;
      evidence.request_action=(int)request.action;
      evidence.request_magic=request.magic;
      evidence.request_comment=request.comment;
      evidence.result_retcode=result.retcode;
      evidence.result_retcode_external=(uint)result.retcode_external;
      evidence.request_id_session_local=result.request_id;
      evidence.final_confirmation=false;
      evidence.retry_allowed=false;
      if(!SWV5S5_F_DeriveCallbackDigest(evidence,evidence.evidence_digest)) return false;
      return evidence_store.PersistCallbackEvidence(evidence);
   }

   bool QueryAuthoritativeBrokerDomains(const SWV5S5_F_ReconciliationBinding &binding,
                                        const SWV5S5_F_CapabilityProof &capability_proof,
                                        const datetime history_from,const datetime history_to,
                                        ISWV5S5FBrokerEvidenceStore &evidence_store,
                                        SWV5S5_F_BrokerQuerySnapshot &snapshot)
   {
      ZeroMemory(snapshot); SWV5S5_F_InitVersion(snapshot.contract_version);
      SWV5S5_F_AdapterEnvironment current_environment;
      if(!CaptureEnvironment(binding.profile.symbol,current_environment) ||
         !SWV5S5_F_AdapterEnvironmentMatchesProfile(binding.profile,current_environment)) return false;
      snapshot.profile=binding.profile;
      snapshot.broker_read_path_id=m_broker_read_path_id;
      snapshot.broker_authority_instance_id=m_broker_authority_instance_id;
      snapshot.connection_generation=m_connection_generation;
      snapshot.restart_generation=m_restart_generation;
      snapshot.history_from=history_from; snapshot.history_to=history_to;
      if(m_broker_read_path_id=="" || m_broker_authority_instance_id=="" ||
         m_connection_generation==0 || m_restart_generation==0 ||
         history_from<=0 || history_to<history_from ||
         !evidence_store.ReserveBrokerQuerySequence(binding.profile,snapshot.owner_query_sequence)) return false;

      snapshot.positions_reported_total=(uint)PositionsTotal();
      ArrayResize(snapshot.positions,(int)snapshot.positions_reported_total);
      snapshot.positions_enumeration_complete=true;
      for(int i=0;i<(int)snapshot.positions_reported_total;i++)
      {
         ZeroMemory(snapshot.positions[i]);
         const ulong ticket=PositionGetTicket(i);
         snapshot.positions[i].read_success=(ticket>0);
         if(!snapshot.positions[i].read_success){ snapshot.row_read_failures++; snapshot.positions_enumeration_complete=false; continue; }
         snapshot.positions[i].ticket=ticket;
         snapshot.positions[i].position_identifier=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
         snapshot.positions[i].symbol=PositionGetString(POSITION_SYMBOL);
         snapshot.positions[i].magic=(ulong)PositionGetInteger(POSITION_MAGIC);
         snapshot.positions[i].direction=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? 1 : -1);
         snapshot.positions[i].volume=PositionGetDouble(POSITION_VOLUME);
         snapshot.positions[i].time_msc=(datetime)PositionGetInteger(POSITION_TIME_MSC);
         snapshot.positions[i].comment=PositionGetString(POSITION_COMMENT);
      }

      snapshot.orders_reported_total=(uint)OrdersTotal();
      ArrayResize(snapshot.orders,(int)snapshot.orders_reported_total);
      snapshot.orders_enumeration_complete=true;
      for(int i=0;i<(int)snapshot.orders_reported_total;i++)
      {
         ZeroMemory(snapshot.orders[i]);
         const ulong ticket=OrderGetTicket(i);
         snapshot.orders[i].read_success=(ticket>0);
         if(!snapshot.orders[i].read_success){ snapshot.row_read_failures++; snapshot.orders_enumeration_complete=false; continue; }
         snapshot.orders[i].ticket=ticket;
         snapshot.orders[i].position_identifier=(ulong)OrderGetInteger(ORDER_POSITION_ID);
         snapshot.orders[i].symbol=OrderGetString(ORDER_SYMBOL);
         snapshot.orders[i].magic=(ulong)OrderGetInteger(ORDER_MAGIC);
         snapshot.orders[i].order_type=(int)OrderGetInteger(ORDER_TYPE);
         snapshot.orders[i].order_state=(int)OrderGetInteger(ORDER_STATE);
         snapshot.orders[i].volume_initial=OrderGetDouble(ORDER_VOLUME_INITIAL);
         snapshot.orders[i].volume_current=OrderGetDouble(ORDER_VOLUME_CURRENT);
         snapshot.orders[i].setup_time_msc=(datetime)OrderGetInteger(ORDER_TIME_SETUP_MSC);
         snapshot.orders[i].comment=OrderGetString(ORDER_COMMENT);
      }

      const bool history_selected=HistorySelect(history_from,history_to);
      snapshot.history_orders_enumeration_complete=history_selected;
      snapshot.history_deals_enumeration_complete=history_selected;
      if(history_selected)
      {
         snapshot.history_orders_reported_total=(uint)HistoryOrdersTotal();
         ArrayResize(snapshot.history_orders,(int)snapshot.history_orders_reported_total);
         for(int i=0;i<(int)snapshot.history_orders_reported_total;i++)
         {
            ZeroMemory(snapshot.history_orders[i]);
            const ulong ticket=HistoryOrderGetTicket(i);
            snapshot.history_orders[i].read_success=(ticket>0);
            if(!snapshot.history_orders[i].read_success){ snapshot.row_read_failures++; snapshot.history_orders_enumeration_complete=false; continue; }
            snapshot.history_orders[i].ticket=ticket;
            snapshot.history_orders[i].position_identifier=(ulong)HistoryOrderGetInteger(ticket,ORDER_POSITION_ID);
            snapshot.history_orders[i].symbol=HistoryOrderGetString(ticket,ORDER_SYMBOL);
            snapshot.history_orders[i].magic=(ulong)HistoryOrderGetInteger(ticket,ORDER_MAGIC);
            snapshot.history_orders[i].order_type=(int)HistoryOrderGetInteger(ticket,ORDER_TYPE);
            snapshot.history_orders[i].order_state=(int)HistoryOrderGetInteger(ticket,ORDER_STATE);
            snapshot.history_orders[i].volume_initial=HistoryOrderGetDouble(ticket,ORDER_VOLUME_INITIAL);
            snapshot.history_orders[i].volume_current=HistoryOrderGetDouble(ticket,ORDER_VOLUME_CURRENT);
            snapshot.history_orders[i].setup_time_msc=(datetime)HistoryOrderGetInteger(ticket,ORDER_TIME_SETUP_MSC);
            snapshot.history_orders[i].done_time_msc=(datetime)HistoryOrderGetInteger(ticket,ORDER_TIME_DONE_MSC);
            snapshot.history_orders[i].comment=HistoryOrderGetString(ticket,ORDER_COMMENT);
         }
         snapshot.history_deals_reported_total=(uint)HistoryDealsTotal();
         ArrayResize(snapshot.history_deals,(int)snapshot.history_deals_reported_total);
         for(int i=0;i<(int)snapshot.history_deals_reported_total;i++)
         {
            ZeroMemory(snapshot.history_deals[i]);
            const ulong ticket=HistoryDealGetTicket(i);
            snapshot.history_deals[i].read_success=(ticket>0);
            if(!snapshot.history_deals[i].read_success){ snapshot.row_read_failures++; snapshot.history_deals_enumeration_complete=false; continue; }
            snapshot.history_deals[i].ticket=ticket;
            snapshot.history_deals[i].order_ticket=(ulong)HistoryDealGetInteger(ticket,DEAL_ORDER);
            snapshot.history_deals[i].position_identifier=(ulong)HistoryDealGetInteger(ticket,DEAL_POSITION_ID);
            snapshot.history_deals[i].symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);
            snapshot.history_deals[i].magic=(ulong)HistoryDealGetInteger(ticket,DEAL_MAGIC);
            snapshot.history_deals[i].deal_type=(int)HistoryDealGetInteger(ticket,DEAL_TYPE);
            snapshot.history_deals[i].entry_type=(int)HistoryDealGetInteger(ticket,DEAL_ENTRY);
            snapshot.history_deals[i].volume=HistoryDealGetDouble(ticket,DEAL_VOLUME);
            snapshot.history_deals[i].price=HistoryDealGetDouble(ticket,DEAL_PRICE);
            snapshot.history_deals[i].time_msc=(datetime)HistoryDealGetInteger(ticket,DEAL_TIME_MSC);
            snapshot.history_deals[i].comment=HistoryDealGetString(ticket,DEAL_COMMENT);
         }
      }
      else snapshot.row_read_failures++;

      uint callback_read_failures=0;
      if(!evidence_store.LoadCallbackEvidence(binding,snapshot.callback_transactions,
         snapshot.callback_transactions_enumeration_complete,callback_read_failures)) return false;
      snapshot.callback_transactions_reported_total=(uint)ArraySize(snapshot.callback_transactions);
      snapshot.row_read_failures+=callback_read_failures;
      snapshot.observed_at=TimeTradeServer();

      const bool governed_capability=SWV5S5_F_IsCapabilityProofValid(binding,capability_proof);
      snapshot.completeness_claimed=governed_capability && capability_proof.query_completeness_capability_proven &&
         snapshot.positions_enumeration_complete && snapshot.orders_enumeration_complete &&
         snapshot.history_orders_enumeration_complete && snapshot.history_deals_enumeration_complete &&
         snapshot.callback_transactions_enumeration_complete && snapshot.row_read_failures==0;
      snapshot.visibility_watermark_claimed=governed_capability && capability_proof.visibility_watermark_proven;

      SWV5S5_InitContractVersion(snapshot.query_set.contract_version);
      snapshot.query_set.required_flags=SWV5_QUERY_POSITIONS|SWV5_QUERY_ORDERS|SWV5_QUERY_DEALS|SWV5_QUERY_TRANSACTIONS;
      snapshot.query_set.completed_flags=0;
      if(snapshot.positions_enumeration_complete) snapshot.query_set.completed_flags|=SWV5_QUERY_POSITIONS;
      if(snapshot.orders_enumeration_complete && snapshot.history_orders_enumeration_complete) snapshot.query_set.completed_flags|=SWV5_QUERY_ORDERS;
      if(snapshot.history_deals_enumeration_complete) snapshot.query_set.completed_flags|=SWV5_QUERY_DEALS;
      if(snapshot.callback_transactions_enumeration_complete) snapshot.query_set.completed_flags|=SWV5_QUERY_TRANSACTIONS;
      snapshot.query_set.authoritative_flags=(snapshot.completeness_claimed ? snapshot.query_set.completed_flags : 0);
      snapshot.query_set.observation_sequence=snapshot.owner_query_sequence;
      snapshot.query_set.observed_at=snapshot.observed_at;
      snapshot.query_set.issuing_component=SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER;
      snapshot.query_set.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
      snapshot.query_set.snapshot_id=m_broker_authority_instance_id+":"+IntegerToString((long)snapshot.owner_query_sequence);
      if(!CanonicalQuerySnapshot(snapshot,snapshot.snapshot_digest)) return false;
      snapshot.query_set.snapshot_digest=snapshot.snapshot_digest;
      return true;
   }
};

#endif // SW_V5_S5_F_BROKER_PLATFORM_BOUNDARY_MQH
