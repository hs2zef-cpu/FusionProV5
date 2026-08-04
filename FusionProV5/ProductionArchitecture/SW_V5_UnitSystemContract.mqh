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

struct SWV5_SymbolUnitSpecification
{
   string symbol;
   int    digits;
   double point_size;
   double tick_size;
   double pip_size;
   double tick_value_profit;
   double tick_value_loss;
   double contract_size;
   double volume_minimum;
   double volume_maximum;
   double volume_step;
   int    stops_level_points;
   int    freeze_level_points;
   string account_currency;
   datetime observed_at;
   bool   complete;
};

struct SWV5_UnitNormalizationRequest
{
   SWV5_PricePurpose          purpose;
   SWV5_NormalizationDirection price_rounding;
   SWV5_NormalizationDirection volume_rounding;
   int                        direction;
   double                     raw_price;
   double                     raw_stop_price;
   double                     raw_limit_price;
   double                     raw_volume;
   double                     reference_market_price;
};

struct SWV5_NormalizedUnits
{
   double price;
   double stop_price;
   double limit_price;
   double volume;
   double stop_distance_price;
   double stop_distance_points;
   double stop_distance_ticks;
   double projected_tick_value;
   bool   price_aligned_to_tick;
   bool   volume_aligned_to_step;
   bool   stops_level_satisfied;
   bool   freeze_level_satisfied;
};

struct SWV5_UnitValidationResult
{
   SWV5_ContractDecision decision;
   bool                  point_valid;
   bool                  tick_valid;
   bool                  pip_explicit;
   bool                  volume_range_valid;
   bool                  volume_step_valid;
   bool                  tick_value_valid;
   bool                  stops_level_valid;
   bool                  freeze_level_valid;
};

class ISWV5UnitSystemContract
{
public:
   virtual string ContractName() = 0;
   virtual bool ValidateSpecification(const SWV5_SymbolUnitSpecification &specification,
                                      SWV5_UnitValidationResult &result) = 0;
   virtual bool Normalize(const SWV5_SymbolUnitSpecification &specification,
                          const SWV5_UnitNormalizationRequest &request,
                          SWV5_NormalizedUnits &normalized,
                          SWV5_UnitValidationResult &result) = 0;
};

#endif
