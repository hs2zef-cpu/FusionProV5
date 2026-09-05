#property strict
#property script_show_inputs

#include "../../Configuration/SW_V5_RuntimeIdentityProfile.mqh"

// TEST ONLY / F0 / ATTENDED DEMO ONLY / READ-ONLY / NOT FOR PRODUCTION.
// This probe submits, modifies, and closes nothing. It reports raw query reads;
// it does not certify completeness or authoritative emptiness.

input int InpHistoryWindowSeconds=86400;

string SWV5S5_F0MagicClassification(const long raw_magic)
  {
   const ulong magic=(ulong)raw_magic;
   if(magic==SWV5_RUNTIME_STRATEGY_MAGIC)
      return "RUNTIME_MAGIC_MATCH_NOT_SOLE_CORRELATION_AUTHORITY";
   if(magic==0)
      return "MAGIC_ZERO_ACCOUNT_BALANCE_OR_NON_STRATEGY";
   if(magic==5042001 || magic==5005 || magic==550015)
      return "FIXTURE_REFERENCE_MAGIC_NON_RUNTIME";
   return "UNRELATED_MAGIC";
  }

void SWV5S5_F0Positions()
  {
   const int total=PositionsTotal();
   PrintFormat("F0_QUERY_DOMAIN|positions|api_success=1|reported_total=%d|completeness=UNPROVEN",total);
   for(int i=0;i<total;i++)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0)
        { PrintFormat("F0_POSITION_READ_FAILURE|index=%d|last_error=%d",i,GetLastError()); continue; }
      const long magic=PositionGetInteger(POSITION_MAGIC);
      PrintFormat("F0_POSITION|index=%d|ticket=%I64u|identifier=%I64u|symbol=%s|magic=%I64d|magic_class=%s|type=%d|volume=%.10f|time_msc=%I64d|comment=%s",
                  i,ticket,(ulong)PositionGetInteger(POSITION_IDENTIFIER),PositionGetString(POSITION_SYMBOL),
                  magic,SWV5S5_F0MagicClassification(magic),(int)PositionGetInteger(POSITION_TYPE),
                  PositionGetDouble(POSITION_VOLUME),PositionGetInteger(POSITION_TIME_MSC),PositionGetString(POSITION_COMMENT));
     }
  }

void SWV5S5_F0Orders()
  {
   const int total=OrdersTotal();
   PrintFormat("F0_QUERY_DOMAIN|orders|api_success=1|reported_total=%d|completeness=UNPROVEN",total);
   for(int i=0;i<total;i++)
     {
      const ulong ticket=OrderGetTicket(i);
      if(ticket==0)
        { PrintFormat("F0_ORDER_READ_FAILURE|index=%d|last_error=%d",i,GetLastError()); continue; }
      const long magic=OrderGetInteger(ORDER_MAGIC);
      PrintFormat("F0_ORDER|index=%d|ticket=%I64u|symbol=%s|magic=%I64d|magic_class=%s|type=%d|state=%d|position_id=%I64u|position_by_id=%I64u|volume_initial=%.10f|volume_current=%.10f|time_setup_msc=%I64d|comment=%s",
                  i,ticket,OrderGetString(ORDER_SYMBOL),magic,SWV5S5_F0MagicClassification(magic),(int)OrderGetInteger(ORDER_TYPE),
                  (int)OrderGetInteger(ORDER_STATE),(ulong)OrderGetInteger(ORDER_POSITION_ID),
                  (ulong)OrderGetInteger(ORDER_POSITION_BY_ID),OrderGetDouble(ORDER_VOLUME_INITIAL),
                  OrderGetDouble(ORDER_VOLUME_CURRENT),OrderGetInteger(ORDER_TIME_SETUP_MSC),OrderGetString(ORDER_COMMENT));
     }
  }

void SWV5S5_F0HistoryOrders()
  {
   const int total=HistoryOrdersTotal();
   PrintFormat("F0_QUERY_DOMAIN|history_orders|history_select_success=1|reported_total=%d|completeness=UNPROVEN",total);
   for(int i=0;i<total;i++)
     {
      const ulong ticket=HistoryOrderGetTicket(i);
      if(ticket==0)
        { PrintFormat("F0_HISTORY_ORDER_READ_FAILURE|index=%d|last_error=%d",i,GetLastError()); continue; }
      const long magic=HistoryOrderGetInteger(ticket,ORDER_MAGIC);
      PrintFormat("F0_HISTORY_ORDER|index=%d|ticket=%I64u|symbol=%s|magic=%I64d|magic_class=%s|type=%d|state=%d|position_id=%I64u|time_setup_msc=%I64d|time_done_msc=%I64d|comment=%s",
                  i,ticket,HistoryOrderGetString(ticket,ORDER_SYMBOL),magic,SWV5S5_F0MagicClassification(magic),
                  (int)HistoryOrderGetInteger(ticket,ORDER_TYPE),(int)HistoryOrderGetInteger(ticket,ORDER_STATE),
                  (ulong)HistoryOrderGetInteger(ticket,ORDER_POSITION_ID),HistoryOrderGetInteger(ticket,ORDER_TIME_SETUP_MSC),
                  HistoryOrderGetInteger(ticket,ORDER_TIME_DONE_MSC),HistoryOrderGetString(ticket,ORDER_COMMENT));
     }
  }

void SWV5S5_F0HistoryDeals()
  {
   const int total=HistoryDealsTotal();
   PrintFormat("F0_QUERY_DOMAIN|history_deals|history_select_success=1|reported_total=%d|completeness=UNPROVEN",total);
   for(int i=0;i<total;i++)
     {
      const ulong ticket=HistoryDealGetTicket(i);
      if(ticket==0)
        { PrintFormat("F0_HISTORY_DEAL_READ_FAILURE|index=%d|last_error=%d",i,GetLastError()); continue; }
      const long magic=HistoryDealGetInteger(ticket,DEAL_MAGIC);
      PrintFormat("F0_HISTORY_DEAL|index=%d|ticket=%I64u|order=%I64u|position_id=%I64u|symbol=%s|magic=%I64d|magic_class=%s|type=%d|entry=%d|volume=%.10f|price=%.10f|time_msc=%I64d|comment=%s",
                  i,ticket,(ulong)HistoryDealGetInteger(ticket,DEAL_ORDER),(ulong)HistoryDealGetInteger(ticket,DEAL_POSITION_ID),
                  HistoryDealGetString(ticket,DEAL_SYMBOL),magic,SWV5S5_F0MagicClassification(magic),
                  (int)HistoryDealGetInteger(ticket,DEAL_TYPE),(int)HistoryDealGetInteger(ticket,DEAL_ENTRY),
                  HistoryDealGetDouble(ticket,DEAL_VOLUME),HistoryDealGetDouble(ticket,DEAL_PRICE),
                  HistoryDealGetInteger(ticket,DEAL_TIME_MSC),HistoryDealGetString(ticket,DEAL_COMMENT));
     }
  }

void OnStart()
  {
   const datetime server_to=TimeTradeServer();
   const datetime local_now=TimeLocal();
   const datetime server_from=server_to-MathMax(1,InpHistoryWindowSeconds);
   const bool history_ok=HistorySelect(server_from,server_to);
   PrintFormat("F0_QUERY_BEGIN|server_from=%I64d|server_to=%I64d|local_now=%I64d|connected=%d|history_select_success=%d|last_error=%d",
               (long)server_from,(long)server_to,(long)local_now,(int)TerminalInfoInteger(TERMINAL_CONNECTED),
               (int)history_ok,GetLastError());
   PrintFormat("F0_QUERY_IDENTITY|runtime_strategy_magic=%I64u|magic_alone_not_correlation_authority=YES",
               SWV5_RUNTIME_STRATEGY_MAGIC);
   SWV5S5_F0Positions();
   SWV5S5_F0Orders();
   if(history_ok)
     {
      SWV5S5_F0HistoryOrders();
      SWV5S5_F0HistoryDeals();
     }
   else
      Print("F0_QUERY_INCOMPLETE|history_select_failed|empty_is_forbidden");
   Print("F0_QUERY_END|raw_observation_only|completeness_not_certified");
  }
