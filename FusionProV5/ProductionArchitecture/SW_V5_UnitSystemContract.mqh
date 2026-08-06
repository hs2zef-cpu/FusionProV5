#ifndef SW_V5_UNIT_SYSTEM_CONTRACT_MQH
#define SW_V5_UNIT_SYSTEM_CONTRACT_MQH

#include "SW_V5_ProductionCommon.mqh"

enum SWV5_NormalizationDirection
{
   SWV5_NORMALIZE_NEAREST = 0,
   SWV5_NORMALIZE_DOWN = 1,
   SWV5_NORMALIZE_UP = 2
};

enum SWV5_PricePurpose
{
   SWV5_PRICE_ENTRY = 0,
   SWV5_PRICE_STOP_LOSS = 1,
   SWV5_PRICE_TAKE_PROFIT = 2,
   SWV5_PRICE_CLOSE = 3,
   SWV5_PRICE_TRIGGER = 4
};

enum SWV5_TradeOperationKind
{
   SWV5_OPERATION_MARKET_ENTRY = 0,
   SWV5_OPERATION_PENDING_ENTRY = 1,
   SWV5_OPERATION_MODIFY_STOP = 2,
   SWV5_OPERATION_MODIFY_LIMIT = 3,
   SWV5_OPERATION_REDUCE = 4,
   SWV5_OPERATION_CLOSE = 5
};

const ulong SWV5_UNIT_POINT_VALID = 1;
const ulong SWV5_UNIT_TICK_VALID = 2;
const ulong SWV5_UNIT_PIP_EXPLICIT = 4;
const ulong SWV5_UNIT_VOLUME_RANGE_VALID = 8;
const ulong SWV5_UNIT_VOLUME_STEP_VALID = 16;
const ulong SWV5_UNIT_TICK_VALUE_VALID = 32;
const ulong SWV5_UNIT_TICK_VALUE_CURRENCY_VALID = 64;
const ulong SWV5_UNIT_SPECIFICATION_FRESH = 128;
const ulong SWV5_UNIT_STOPS_LEVEL_VALID = 256;
const ulong SWV5_UNIT_FREEZE_LEVEL_VALID = 512;

struct SWV5_SymbolUnitSpecification
{
   SWV5_ContractVersion contract_version;
   string symbol;
   ulong  specification_sequence;
   int    digits;
   double point_size;
   double tick_size;
   double pip_size;
   double tick_value_profit;
   double tick_value_loss;
   double contract_size;
   double tick_value_basis_volume;
   double volume_minimum;
   double volume_maximum;
   double volume_step;
   int    stops_level_points;
   int    freeze_level_points;
   string account_currency;
   string tick_value_currency;
   datetime observed_at;
   datetime valid_until;
   bool   complete;
};

struct SWV5_UnitNormalizationRequest
{
   SWV5_ContractVersion       contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence       ownership_fence;
   SWV5_PricePurpose          purpose;
   SWV5_TradeOperationKind    operation_kind;
   int                        direction;
   double                     raw_price;
   double                     raw_stop_price;
   double                     raw_limit_price;
   double                     raw_volume;
   double                     reference_market_price;
   double                     operation_price;
   double                     market_bid;
   double                     market_ask;
   ulong                      expected_specification_sequence;
   bool                       exposure_increasing;
   bool                       protective_operation;
};

struct SWV5_NormalizedUnits
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   double price;
   double stop_price;
   double limit_price;
   double volume;
   double stop_distance_price;
   double stop_distance_points;
   double stop_distance_ticks;
   double monetary_tick_value_per_volume_unit;
   string monetary_value_currency;
   ulong  specification_sequence;
   SWV5_NormalizationDirection applied_entry_rounding;
   SWV5_NormalizationDirection applied_stop_rounding;
   SWV5_NormalizationDirection applied_limit_rounding;
   SWV5_NormalizationDirection applied_volume_rounding;
   bool   price_aligned_to_tick;
   bool   volume_aligned_to_step;
   bool   stops_level_satisfied;
   bool   freeze_level_satisfied;
};

struct SWV5_UnitValidationResult
{
   SWV5_ContractVersion contract_version;
   SWV5_ContractDecision decision;
   ulong                 validation_flags;
};

class ISWV5UnitSystemContract
{
public:
   virtual string ContractName() = 0;
   virtual bool ValidateSpecification(const SWV5_ContractValidationContext &context,
                                      const SWV5_SymbolUnitSpecification &specification,
                                      SWV5_UnitValidationResult &result) = 0;
   virtual bool Normalize(const SWV5_ContractValidationContext &context,
                          const SWV5_SymbolUnitSpecification &specification,
                          const SWV5_UnitNormalizationRequest &request,
                          SWV5_NormalizedUnits &normalized,
                          SWV5_UnitValidationResult &result) = 0;
};

#endif
