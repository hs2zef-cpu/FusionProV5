#ifndef SW_V5_STATISTICS_CONTRACT_MQH
#define SW_V5_STATISTICS_CONTRACT_MQH

#include "SW_V5_BasketContract.mqh"

enum SWV5_DealEntryKind
{
   SWV5_DEAL_ENTRY_UNKNOWN = 0,
   SWV5_DEAL_ENTRY_IN = 1,
   SWV5_DEAL_ENTRY_OUT = 2,
   SWV5_DEAL_ENTRY_INOUT = 3,
   SWV5_DEAL_ENTRY_STATE = 4
};

struct SWV5_AuthoritativeDeal
{
   ulong                deal_ticket;
   ulong                order_ticket;
   ulong                position_identifier;
   SWV5_BasketID        basket_id;
   ulong                magic;
   string               symbol;
   SWV5_DealEntryKind   entry_kind;
   int                  direction;
   double               volume;
   double               price;
   double               gross_profit;
   double               commission;
   double               swap;
   double               fee;
   datetime             deal_time;
   SWV5_AuthoritySource authority;
};

struct SWV5_BasketStatistics
{
   SWV5_BasketID basket_id;
   uint          deal_count;
   uint          entry_deal_count;
   uint          exit_deal_count;
   uint          partial_close_count;
   double        entered_volume;
   double        exited_volume;
   double        residual_volume;
   double        gross_profit;
   double        commission;
   double        swap;
   double        fee;
   double        authoritative_net_result;
   datetime      first_deal_time;
   datetime      last_deal_time;
   ulong         last_deal_ticket;
   bool          history_complete;
};

struct SWV5_StatisticsBuildContext
{
   SWV5_BasketID basket_id;
   datetime      history_from;
   datetime      history_to;
   ulong         expected_magic;
   string        expected_symbol;
   bool          history_query_complete;
};

struct SWV5_StatisticsValidationResult
{
   SWV5_ContractDecision decision;
   bool                  source_authoritative;
   bool                  basket_attribution_valid;
   bool                  fees_complete;
   bool                  partial_closes_reconciled;
   bool                  residual_volume_reconciled;
};

class ISWV5StatisticsContract
{
public:
   virtual string ContractName() = 0;
   virtual bool ValidateDeal(const SWV5_AuthoritativeDeal &deal,
                             const SWV5_StatisticsBuildContext &context,
                             SWV5_ContractDecision &decision) = 0;
   virtual bool AccumulateDeal(const SWV5_AuthoritativeDeal &deal,
                               const SWV5_BasketStatistics &current,
                               SWV5_BasketStatistics &next) = 0;
   virtual bool Finalize(const SWV5_StatisticsBuildContext &context,
                         const SWV5_BasketStatistics &statistics,
                         SWV5_StatisticsValidationResult &result) = 0;
};

#endif
