#ifndef SW_V5_PRICE_ACTION_ENGINE_MQH
#define SW_V5_PRICE_ACTION_ENGINE_MQH

#include "..\\Core\\SW_V5_Types.mqh"

class CPriceActionEngine
{
public:
   string Name()
   {
      return "PriceActionEngine";
   }

   bool Evaluate(const SWV5_EngineInput &engineInput, SWV5_PriceActionResult &result)
   {
      SWV5_InitPriceActionResult(result, engineInput);
      if(!engineInput.market.has_rates)
      {
         result.header.health = SWV5_HEALTH_UNAVAILABLE;
         result.header.reason_flags |= SWV5_REASON_DATA_MISSING;
         result.header.reason_text = "Rates missing";
         return false;
      }

      MqlRates bar = engineInput.market.closed_bar;
      if(engineInput.market.header.execution_mode == SWV5_EXECUTION_EVERY_TICK)
         bar = engineInput.market.current_bar;

      double range = bar.high - bar.low;
      double body = MathAbs(bar.close - bar.open);
      result.header.health = SWV5_HEALTH_HEALTHY;
      result.header.valid = true;

      if(range <= 0.0)
      {
         result.state = "FLAT";
         result.bias = SWV5_BIAS_NEUTRAL;
         result.header.score = 0.0;
         result.strength = 0.0;
         result.header.confidence = 0.0;
         result.header.reason_flags |= SWV5_REASON_PRICE_ACTION_NEUTRAL;
         result.header.reason_text = "Zero range";
         return true;
      }

      result.strength = body / range;
      result.header.confidence = result.strength;
      result.header.score = result.strength * 100.0;

      if(bar.close > bar.open)
      {
         result.state = "BULLISH_CANDLE_STATE";
         result.bias = SWV5_BIAS_BULLISH;
         result.header.reason_text = "Bullish candle state only";
      }
      else if(bar.close < bar.open)
      {
         result.state = "BEARISH_CANDLE_STATE";
         result.bias = SWV5_BIAS_BEARISH;
         result.header.reason_text = "Bearish candle state only";
      }
      else
      {
         result.state = "NEUTRAL_CANDLE_STATE";
         result.bias = SWV5_BIAS_NEUTRAL;
         result.header.reason_flags |= SWV5_REASON_PRICE_ACTION_NEUTRAL;
         result.header.reason_text = "Neutral candle state";
      }

      return true;
   }
};

#endif
