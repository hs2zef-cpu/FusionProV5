#ifndef SW_V5_MOMENTUM_ENGINE_MQH
#define SW_V5_MOMENTUM_ENGINE_MQH

#include "..\\Core\\SW_V5_Types.mqh"

class CMomentumEngine
{
private:
   double m_v4BodyAtr;
   double m_v5BodyAtr;
   bool   m_useRsi50;
   bool   m_useMacd;
   bool   m_useStoch;
   double m_stochOb;
   double m_stochOs;

public:
   CMomentumEngine()
   {
      m_v4BodyAtr = 0.32;
      m_v5BodyAtr = 0.36;
      m_useRsi50 = true;
      m_useMacd = true;
      m_useStoch = true;
      m_stochOb = 80.0;
      m_stochOs = 20.0;
   }

   bool Configure(const double v4BodyAtr,
                  const double v5BodyAtr,
                  const bool useRsi50,
                  const bool useMacd,
                  const bool useStoch,
                  const double stochOb,
                  const double stochOs)
   {
      if(v4BodyAtr <= 0.0 || v5BodyAtr <= 0.0 || stochOs < 0.0 || stochOb > 100.0 || stochOs >= stochOb)
         return false;

      m_v4BodyAtr = v4BodyAtr;
      m_v5BodyAtr = v5BodyAtr;
      m_useRsi50 = useRsi50;
      m_useMacd = useMacd;
      m_useStoch = useStoch;
      m_stochOb = stochOb;
      m_stochOs = stochOs;
      return true;
   }

   void Evaluate(const SWV5_EngineInput &engineInput, SWV5_MomentumResult &result)
   {
      SWV5_InitMomentumResult(result, engineInput);
      result.v4_body_threshold = m_v4BodyAtr;
      result.v5_body_threshold = m_v5BodyAtr;

      bool requiredReady = (engineInput.market.has_rates &&
                            engineInput.indicators.has_momentum_indicators &&
                            engineInput.indicators.has_rsi &&
                            engineInput.indicators.has_atr &&
                            (!m_useMacd || engineInput.indicators.has_macd) &&
                            (!m_useStoch || engineInput.indicators.has_stoch));
      if(!requiredReady)
      {
         result.header.reason_flags |= SWV5_REASON_DATA_MISSING;
         result.header.reason_text = "Momentum indicators not ready";
         return;
      }

      MqlRates bar;
      if(result.use_closed)
         bar = engineInput.market.closed_bar;
      else
         bar = engineInput.market.current_bar;
      bool valuesValid = (SWV5_IsFinite(bar.open) && SWV5_IsFinite(bar.close) &&
                          SWV5_IsFinite(engineInput.indicators.rsi) &&
                          engineInput.indicators.rsi != EMPTY_VALUE &&
                          SWV5_IsFinite(engineInput.indicators.atr) &&
                          engineInput.indicators.atr != EMPTY_VALUE && engineInput.indicators.atr > 0.0);
      if(m_useMacd)
         valuesValid = valuesValid && SWV5_IsFinite(engineInput.indicators.macd_main) && SWV5_IsFinite(engineInput.indicators.macd_signal) &&
                       engineInput.indicators.macd_main != EMPTY_VALUE && engineInput.indicators.macd_signal != EMPTY_VALUE;
      if(m_useStoch)
         valuesValid = valuesValid && SWV5_IsFinite(engineInput.indicators.stoch_k) && SWV5_IsFinite(engineInput.indicators.stoch_d) &&
                       engineInput.indicators.stoch_k != EMPTY_VALUE && engineInput.indicators.stoch_d != EMPTY_VALUE;
      if(!valuesValid)
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.reason_text = "Invalid momentum input value";
         return;
      }

      result.body_value = MathAbs(bar.close - bar.open);
      result.atr_value = engineInput.indicators.atr;
      result.body_atr_ratio = result.body_value / result.atr_value;
      result.v4_body_threshold_met = (result.body_value >= result.atr_value * m_v4BodyAtr);
      result.v5_body_threshold_met = (result.body_value >= result.atr_value * m_v5BodyAtr);
      result.rsi_value = engineInput.indicators.rsi;

      if(!m_useRsi50)
         result.rsi_state = "BYPASSED";
      else if(result.rsi_value > 50.0)
      {
         result.rsi_state = "BULLISH";
         result.header.reason_flags |= SWV5_REASON_RSI_BULLISH;
      }
      else if(result.rsi_value < 50.0)
      {
         result.rsi_state = "BEARISH";
         result.header.reason_flags |= SWV5_REASON_RSI_BEARISH;
      }
      else
         result.rsi_state = "NEUTRAL";

      if(!m_useMacd)
      {
         result.macd_main_value = EMPTY_VALUE;
         result.macd_signal_value = EMPTY_VALUE;
         result.macd_histogram_value = 0.0;
         result.macd_state = "BYPASSED";
      }
      else
      {
         result.macd_main_value = engineInput.indicators.macd_main;
         result.macd_signal_value = engineInput.indicators.macd_signal;
         result.macd_histogram_value = result.macd_main_value - result.macd_signal_value;
         if(result.macd_main_value > result.macd_signal_value || result.macd_histogram_value > 0.0)
         {
            result.macd_state = "BULLISH";
            result.header.reason_flags |= SWV5_REASON_MACD_BULLISH;
         }
         else if(result.macd_main_value < result.macd_signal_value || result.macd_histogram_value < 0.0)
         {
            result.macd_state = "BEARISH";
            result.header.reason_flags |= SWV5_REASON_MACD_BEARISH;
         }
         else
            result.macd_state = "NEUTRAL";
      }

      if(!m_useStoch)
      {
         result.stoch_k_value = 0.0;
         result.stoch_d_value = 0.0;
         result.stoch_state = "BYPASSED";
      }
      else
      {
         result.stoch_k_value = engineInput.indicators.stoch_k;
         result.stoch_d_value = engineInput.indicators.stoch_d;
         if(result.stoch_k_value > result.stoch_d_value && result.stoch_k_value > m_stochOs)
         {
            result.stoch_state = "BULLISH";
            result.header.reason_flags |= SWV5_REASON_STOCH_BULLISH;
         }
         else if(result.stoch_k_value < result.stoch_d_value && result.stoch_k_value < m_stochOb)
         {
            result.stoch_state = "BEARISH";
            result.header.reason_flags |= SWV5_REASON_STOCH_BEARISH;
         }
         else
            result.stoch_state = "NEUTRAL";
      }

      if(result.v4_body_threshold_met && bar.close > bar.open)
      {
         result.bias = SWV5_BIAS_BULLISH;
         result.momentum_state = "BULLISH";
      }
      else if(result.v4_body_threshold_met && bar.close < bar.open)
      {
         result.bias = SWV5_BIAS_BEARISH;
         result.momentum_state = "BEARISH";
      }
      else
      {
         result.bias = SWV5_BIAS_NEUTRAL;
         result.momentum_state = "NEUTRAL";
      }

      result.strength = result.v4_body_threshold_met ? 1.0 : 0.0;
      result.header.reason_flags |= result.v4_body_threshold_met ? SWV5_REASON_MOMENTUM_BODY_MET : SWV5_REASON_MOMENTUM_BODY_BELOW;
      result.header.reason_flags |= SWV5_REASON_CONFIRMATION_CONTEXT_REQUIRED;
      result.raw_legacy_confirmation_points = 0;
      result.confirmation_context_ready = false;
      result.ready = true;
      result.header.health = SWV5_HEALTH_HEALTHY;
      result.header.valid = true;
      result.header.score = 0.0;
      result.header.confidence = 1.0;
      result.header.reason_text = "V4.2 momentum evidence; candidate-direction score context remains legacy";
   }
};

#endif
