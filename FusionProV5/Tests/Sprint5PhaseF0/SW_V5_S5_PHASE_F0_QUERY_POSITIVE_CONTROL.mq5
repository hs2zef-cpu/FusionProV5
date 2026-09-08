#property strict
#property script_show_inputs

#include "../../Configuration/SW_V5_RuntimeIdentityProfile.mqh"

// TEST ONLY / F0 / ATTENDED DEMO ONLY / READ-ONLY / NOT FOR PRODUCTION.
// NO BROKER MUTATION. This probe only selects and enumerates existing history.
// Cardinality-1 observations are run-scoped and non-authoritative.

input string InpObservationLabel="PRE_RECONNECT";

const ulong SWV5S5_F0_KNOWN_ORDER=5055862979;
const ulong SWV5S5_F0_KNOWN_ENTRY_DEAL=4360221913;
const ulong SWV5S5_F0_KNOWN_POSITION=5055862979;
const ulong SWV5S5_F0_CLEANUP_ORDER=5055880854;
const ulong SWV5S5_F0_CLEANUP_DEAL=4360237506;

void SWV5S5_F0EvaluateSelectedHistory(const string matrix_id,
                                      const long from_epoch,
                                      const long to_epoch,
                                      const int requested_depth,
                                      const bool selection_success,
                                      const int selection_error)
  {
   const int orders_total=(selection_success ? HistoryOrdersTotal() : 0);
   const int deals_total=(selection_success ? HistoryDealsTotal() : 0);
   const int order_depth=(requested_depth<=0 ? orders_total : MathMin(requested_depth,orders_total));
   const int deal_depth=(requested_depth<=0 ? deals_total : MathMin(requested_depth,deals_total));
   int order_reads_ok=0;
   int order_read_failures=0;
   int deal_reads_ok=0;
   int deal_read_failures=0;
   int known_order_found=0;
   int known_entry_deal_found=0;
   int cleanup_order_found=0;
   int cleanup_deal_found=0;
   int xauusd_order_matches=0;
   int xauusd_deal_matches=0;
   int wrong_symbol_order_matches=0;
   int wrong_symbol_deal_matches=0;
   int runtime_magic_order_matches=0;
   int runtime_magic_deal_matches=0;
   int zero_magic_order_matches=0;
   int zero_magic_deal_matches=0;

   for(int i=0;i<order_depth;i++)
     {
      ResetLastError();
      const ulong ticket=HistoryOrderGetTicket(i);
      if(ticket==0)
        { order_read_failures++; continue; }
      order_reads_ok++;
      const string symbol=HistoryOrderGetString(ticket,ORDER_SYMBOL);
      const long magic=HistoryOrderGetInteger(ticket,ORDER_MAGIC);
      if(ticket==SWV5S5_F0_KNOWN_ORDER) known_order_found++;
      if(ticket==SWV5S5_F0_CLEANUP_ORDER) cleanup_order_found++;
      if(symbol=="XAUUSD") xauusd_order_matches++;
      if(symbol=="__F0_WRONG_SYMBOL__") wrong_symbol_order_matches++;
      if((ulong)magic==SWV5_RUNTIME_STRATEGY_MAGIC) runtime_magic_order_matches++;
      if(magic==0) zero_magic_order_matches++;
     }

   for(int i=0;i<deal_depth;i++)
     {
      ResetLastError();
      const ulong ticket=HistoryDealGetTicket(i);
      if(ticket==0)
        { deal_read_failures++; continue; }
      deal_reads_ok++;
      const string symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);
      const long magic=HistoryDealGetInteger(ticket,DEAL_MAGIC);
      if(ticket==SWV5S5_F0_KNOWN_ENTRY_DEAL) known_entry_deal_found++;
      if(ticket==SWV5S5_F0_CLEANUP_DEAL) cleanup_deal_found++;
      if(symbol=="XAUUSD") xauusd_deal_matches++;
      if(symbol=="__F0_WRONG_SYMBOL__") wrong_symbol_deal_matches++;
      if((ulong)magic==SWV5_RUNTIME_STRATEGY_MAGIC) runtime_magic_deal_matches++;
      if(magic==0) zero_magic_deal_matches++;
     }

   PrintFormat("F0_PC_MATRIX|observation=%s|id=%s|server_from=%I64d|server_to=%I64d|selection_success=%d|selection_error=%d|orders_total=%d|deals_total=%d|requested_depth=%d|order_depth=%d|deal_depth=%d|order_reads_ok=%d|order_read_failures=%d|deal_reads_ok=%d|deal_read_failures=%d|known_order_found=%d|known_entry_deal_found=%d|cleanup_order_found=%d|cleanup_deal_found=%d|xauusd_order_matches=%d|xauusd_deal_matches=%d|wrong_symbol_order_matches=%d|wrong_symbol_deal_matches=%d|runtime_magic_order_matches=%d|runtime_magic_deal_matches=%d|zero_magic_order_matches=%d|zero_magic_deal_matches=%d|completeness=UNPROVEN",
               InpObservationLabel,matrix_id,from_epoch,to_epoch,(int)selection_success,selection_error,
               orders_total,deals_total,requested_depth,order_depth,deal_depth,order_reads_ok,
               order_read_failures,deal_reads_ok,deal_read_failures,known_order_found,
               known_entry_deal_found,cleanup_order_found,cleanup_deal_found,xauusd_order_matches,
               xauusd_deal_matches,wrong_symbol_order_matches,wrong_symbol_deal_matches,
               runtime_magic_order_matches,runtime_magic_deal_matches,zero_magic_order_matches,
               zero_magic_deal_matches);
  }

void SWV5S5_F0RunWindow(const string matrix_id,
                        const datetime from_time,
                        const datetime to_time,
                        const int requested_depth)
  {
   ResetLastError();
   const bool selected=HistorySelect(from_time,to_time);
   const int selection_error=GetLastError();
   SWV5S5_F0EvaluateSelectedHistory(matrix_id,(long)from_time,(long)to_time,
                                    requested_depth,selected,selection_error);
  }

void SWV5S5_F0RunPositionFilter(const string matrix_id,const ulong position_id)
  {
   ResetLastError();
   const bool selected=HistorySelectByPosition(position_id);
   const int selection_error=GetLastError();
   SWV5S5_F0EvaluateSelectedHistory(matrix_id,0,0,0,selected,selection_error);
  }

void OnStart()
  {
   PrintFormat("F0_PC_ATTEST|observation=%s|company=%s|server=%s|trade_mode=%d|margin_mode=%d|terminal_build=%d|mql_build=%d|symbol=%s|connected=%d",
               InpObservationLabel,AccountInfoString(ACCOUNT_COMPANY),AccountInfoString(ACCOUNT_SERVER),
               (int)AccountInfoInteger(ACCOUNT_TRADE_MODE),(int)AccountInfoInteger(ACCOUNT_MARGIN_MODE),
               (int)TerminalInfoInteger(TERMINAL_BUILD),__MQLBUILD__,_Symbol,
               (int)TerminalInfoInteger(TERMINAL_CONNECTED));
   PrintFormat("F0_PC_BEGIN|observation=%s|connected=%d|server_now=%I64d|local_now=%I64d|known_order=%I64u|known_entry_deal=%I64u|known_position=%I64u|runtime_magic=%I64u|query_only=YES|cardinality_one_non_authoritative=YES",
               InpObservationLabel,(int)TerminalInfoInteger(TERMINAL_CONNECTED),(long)TimeTradeServer(),
               (long)TimeLocal(),SWV5S5_F0_KNOWN_ORDER,SWV5S5_F0_KNOWN_ENTRY_DEAL,
               SWV5S5_F0_KNOWN_POSITION,SWV5_RUNTIME_STRATEGY_MAGIC);
   Print("F0_PC_ENUMERATION|pagination_api=NONE_EXPOSED|client_enumeration_depths=1,2,FULL|filters=CLIENT_SIDE_AFTER_HISTORY_SELECT");

   SWV5S5_F0RunWindow("WIDE_INCLUDE_FULL",1788796719,1788803919,0);
   SWV5S5_F0RunWindow("WIDE_INCLUDE_REPEAT_FULL",1788796719,1788803919,0);
   SWV5S5_F0RunWindow("ENTRY_SECOND_INCLUDE_FULL",1788800319,1788800319,0);
   SWV5S5_F0RunWindow("BEFORE_ENTRY_EXCLUDE_FULL",1788796719,1788800318,0);
   SWV5S5_F0RunWindow("AFTER_ENTRY_EXCLUDE_FULL",1788800320,1788803919,0);
   SWV5S5_F0RunWindow("CLEANUP_SECOND_INCLUDE_FULL",1788800706,1788800706,0);
   SWV5S5_F0RunWindow("WIDE_INCLUDE_DEPTH_1",1788796719,1788803919,1);
   SWV5S5_F0RunWindow("WIDE_INCLUDE_DEPTH_2",1788796719,1788803919,2);
   SWV5S5_F0RunPositionFilter("POSITION_FILTER_KNOWN",SWV5S5_F0_KNOWN_POSITION);
   SWV5S5_F0RunPositionFilter("POSITION_FILTER_UNKNOWN",999999999999);

   PrintFormat("F0_PC_END|observation=%s|raw_observation_only|completeness_not_certified|no_order_send=YES",
               InpObservationLabel);
  }
