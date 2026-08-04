#ifndef SW_V5_LEGACY_ENGINE_ADAPTER_MQH
#define SW_V5_LEGACY_ENGINE_ADAPTER_MQH

#include "..\\Core\\SW_V5_Types.mqh"

const double SWV5_LEGACY_FIBO_SIGNAL_SCORE = 80.0;
const double SWV5_LEGACY_FIBO_CONFIDENCE = 0.60;

class CLegacyEngineAdapter
{
public:
   string Name()
   {
      return "LegacyEngineAdapter";
   }

   bool Evaluate(const SWV5_EngineInput &engineInput, SWV5_LegacyResult &result)
   {
      SWV5_InitLegacyResult(result, engineInput);
      result.header.health = SWV5_HEALTH_HEALTHY;
      result.header.valid = true;
      result.header.reason_text = "No legacy buffer signal";
      result.score_semantics = SWV5_SCORE_LEGACY_FIXED;
      result.score_comparable_to_execution_threshold = false;
      result.maximum_reachable_score = SWV5_LEGACY_FIBO_SIGNAL_SCORE;
      result.buy_buffer = engineInput.indicators.legacy_buy_buffer;
      result.sell_buffer = engineInput.indicators.legacy_sell_buffer;

      if(!engineInput.indicators.has_legacy_buffers)
      {
         result.header.health = SWV5_HEALTH_DEGRADED;
         result.header.reason_flags |= SWV5_REASON_PARTIAL_DATA;
         result.header.reason_text = "Legacy buffers unavailable";
         return true;
      }

      bool hasBuy = (result.buy_buffer != EMPTY_VALUE && result.buy_buffer != 0.0);
      bool hasSell = (result.sell_buffer != EMPTY_VALUE && result.sell_buffer != 0.0);

      if(hasBuy && !hasSell)
      {
         result.legacy_direction = 1;
         result.has_legacy_signal = true;
         result.header.score = SWV5_LEGACY_FIBO_SIGNAL_SCORE;
         result.header.confidence = SWV5_LEGACY_FIBO_CONFIDENCE;
         result.header.reason_flags |= SWV5_REASON_LEGACY_BUY;
         result.header.reason_text = "Existing legacy buy buffer is populated";
      }
      else if(hasSell && !hasBuy)
      {
         result.legacy_direction = -1;
         result.has_legacy_signal = true;
         result.header.score = SWV5_LEGACY_FIBO_SIGNAL_SCORE;
         result.header.confidence = SWV5_LEGACY_FIBO_CONFIDENCE;
         result.header.reason_flags |= SWV5_REASON_LEGACY_SELL;
         result.header.reason_text = "Existing legacy sell buffer is populated";
      }
      else if(hasBuy && hasSell)
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.reason_text = "Both legacy buffers are populated";
      }

      return result.header.valid;
   }
};

#endif
