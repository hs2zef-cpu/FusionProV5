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

const ulong SWV5_STAT_SOURCE_AUTHORITATIVE = 1;
const ulong SWV5_STAT_ATTRIBUTION_VALID = 2;
const ulong SWV5_STAT_MONETARY_COMPLETE = 4;
const ulong SWV5_STAT_PARTIAL_CLOSES_RECONCILED = 8;
const ulong SWV5_STAT_RESIDUAL_RECONCILED = 16;
const ulong SWV5_STAT_IDENTITY_SET_VALID = 32;
const ulong SWV5_STAT_TICKET_CHAIN_COMPLETE = 64;

struct SWV5_AuthoritativeDeal
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_ExecutionCorrelation correlation;
   SWV5_DealEntryKind   entry_kind;
   int                  direction;
   double               volume;
   double               price;
   double               gross_profit;
   double               commission;
   double               swap;
   double               fee;
   string               account_currency;
   bool                 monetary_components_complete;
   datetime             deal_time;
   SWV5_AuthoritySource authority;
};

enum SWV5_StatisticsIdentityDisposition
{
   SWV5_STAT_IDENTITY_UNCLASSIFIED = 0,
   SWV5_STAT_IDENTITY_NEW = 1,
   SWV5_STAT_IDENTITY_DUPLICATE = 2,
   SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW = 3,
   SWV5_STAT_IDENTITY_CONFLICT = 4
};

struct SWV5_StatisticsDeduplicationEvidence
{
   SWV5_ContractVersion contract_version;
   SWV5_ExecutionCorrelation correlation;
   string               prior_identity_set_digest;
   string               membership_proof;
   ulong                identity_index_sequence;
   SWV5_StatisticsIdentityDisposition disposition;
};

struct SWV5_StatisticsDeduplicationState
{
   SWV5_ContractVersion contract_version;
   string               identity_set_digest;
   uint                 unique_deal_count;
   uint                 duplicate_deal_count;
   ulong                highest_transaction_sequence;
   ulong                identity_index_sequence;
};

struct SWV5_BasketStatistics
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
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
   string         account_currency;
   SWV5_StatisticsDeduplicationState deduplication;
   bool          history_complete;
};

struct SWV5_StatisticsBuildContext
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   datetime      history_from;
   datetime      history_to;
   SWV5_AccountPositionMode account_mode;
   SWV5_AuthoritativeQuerySet history_queries;
};

struct SWV5_StatisticsValidationResult
{
   SWV5_ContractVersion contract_version;
   SWV5_ContractDecision decision;
   ulong                 validation_flags;
};

class ISWV5StatisticsContract
{
public:
   virtual string ContractName() = 0;
   virtual bool ValidateDeal(const SWV5_ContractValidationContext &validation_context,
                             const SWV5_AuthoritativeDeal &deal,
                             const SWV5_StatisticsBuildContext &context,
                             SWV5_ContractDecision &decision) = 0;
   virtual bool AccumulateDeal(const SWV5_ContractValidationContext &validation_context,
                               const SWV5_AuthoritativeDeal &deal,
                               const SWV5_StatisticsDeduplicationEvidence &deduplication_evidence,
                               const SWV5_BasketStatistics &current,
                               SWV5_BasketStatistics &next) = 0;
   virtual bool Finalize(const SWV5_ContractValidationContext &validation_context,
                         const SWV5_StatisticsBuildContext &context,
                         const SWV5_BasketStatistics &statistics,
                         SWV5_StatisticsValidationResult &result) = 0;
};

#endif
