#ifndef SW_V5_TREND_ENGINE_MQH
#define SW_V5_TREND_ENGINE_MQH

#include "..\\Core\\SW_V5_Types.mqh"

class CTrendEngine
{
public:
   string Name()
   {
      return "TrendEngine";
   }

   bool Evaluate(const SWV5_EngineInput &engineInput, SWV5_TrendResult &result)
   {
      SWV5_InitTrendResult(result, engineInput);
      result.trend_fast_value = engineInput.indicators.trend_fast;
      result.trend_slow_value = engineInput.indicators.trend_slow;
      result.macro_fast_value = engineInput.indicators.macro_fast;
      result.macro_slow_value = engineInput.indicators.macro_slow;
      result.use_closed = engineInput.indicators.use_closed;
      result.trend_shift = engineInput.indicators.trend_shift;
      result.macro_shift = engineInput.indicators.macro_shift;

      if(!engineInput.indicators.has_trend_indicators)
      {
         result.header.health = SWV5_HEALTH_UNAVAILABLE;
         result.header.reason_flags |= SWV5_REASON_DATA_MISSING;
         result.header.reason_text = "V4.2 H1 trend EMA inputs unavailable";
         return false;
      }

      result.header.health = SWV5_HEALTH_HEALTHY;
      result.header.valid = true;
      result.header.score = 0.0;
      result.header.confidence = 1.0;

      if(result.trend_fast_value > result.trend_slow_value)
      {
         result.trend_up = true;
         result.trend_state = "TREND_UP";
         result.bias = SWV5_BIAS_BULLISH;
         result.header.reason_flags |= SWV5_REASON_TREND_UP;
      }
      else if(result.trend_fast_value < result.trend_slow_value)
      {
         result.trend_down = true;
         result.trend_state = "TREND_DOWN";
         result.bias = SWV5_BIAS_BEARISH;
         result.header.reason_flags |= SWV5_REASON_TREND_DOWN;
      }
      else
      {
         result.trend_state = "TREND_FLAT";
         result.bias = SWV5_BIAS_NEUTRAL;
         result.header.reason_flags |= SWV5_REASON_TREND_FLAT;
      }

      if(!engineInput.indicators.has_macro_indicators)
      {
         result.header.health = SWV5_HEALTH_DEGRADED;
         result.header.confidence = 0.0;
         result.header.reason_flags |= SWV5_REASON_PARTIAL_DATA;
         result.macro_direction = 0;
         result.macro_state = "MACRO_NOT_READY";
         result.header.reason_text = "H1 EMA gate ready; H4 macro EMA inputs unavailable";
         return true;
      }

      if(result.macro_fast_value > result.macro_slow_value)
      {
         result.macro_direction = 1;
         result.macro_state = "MACRO_UP";
         result.header.reason_flags |= SWV5_REASON_MACRO_UP;
      }
      else if(result.macro_fast_value < result.macro_slow_value)
      {
         result.macro_direction = -1;
         result.macro_state = "MACRO_DOWN";
         result.header.reason_flags |= SWV5_REASON_MACRO_DOWN;
      }
      else
      {
         result.macro_direction = 0;
         result.macro_state = "MACRO_FLAT";
         result.header.reason_flags |= SWV5_REASON_MACRO_FLAT;
      }

      result.header.reason_text = "V4.2 H1 EMA direction gate; no standalone trend score";
      return true;
   }
};

#endif
