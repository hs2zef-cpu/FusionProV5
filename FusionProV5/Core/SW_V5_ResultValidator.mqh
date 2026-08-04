#ifndef SW_V5_RESULT_VALIDATOR_MQH
#define SW_V5_RESULT_VALIDATOR_MQH

#include "SW_V5_Types.mqh"

class CSWV5ResultValidator
{
private:
   bool ValidExecutionMode(const SWV5_ExecutionMode mode)
   {
      return (mode == SWV5_EXECUTION_CLOSED_BAR || mode == SWV5_EXECUTION_EVERY_TICK || mode == SWV5_EXECUTION_REPLAY);
   }

   bool ValidEngineKind(const SWV5_EngineKind kind)
   {
      return (kind >= SWV5_ENGINE_MARKET && kind <= SWV5_ENGINE_LEGACY);
   }

   bool ValidHealth(const SWV5_EngineHealth health)
   {
      return (health == SWV5_HEALTH_HEALTHY || health == SWV5_HEALTH_DEGRADED ||
              health == SWV5_HEALTH_UNAVAILABLE || health == SWV5_HEALTH_INVALID);
   }

   bool ValidMomentumState(const string state, const bool allowBypassed)
   {
      if(state == "BULLISH" || state == "BEARISH" || state == "NEUTRAL")
         return true;
      return (allowBypassed && state == "BYPASSED");
   }

   bool ValidateScoreConfidence(SWV5_ResultHeader &header)
   {
      if(!SWV5_IsFinite(header.score) || !SWV5_IsFinite(header.confidence))
      {
         header.health = SWV5_HEALTH_INVALID;
         header.valid = false;
         header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         header.validation_error = "NaN or infinity in score/confidence";
         return false;
      }
      if(header.score < 0.0 || header.score > 100.0 || header.confidence < 0.0 || header.confidence > 1.0)
      {
         header.health = SWV5_HEALTH_INVALID;
         header.valid = false;
         header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         header.validation_error = "Score/confidence outside normalized ranges";
         return false;
      }
      return true;
   }

   bool ValidateHeader(SWV5_ResultHeader &header, const SWV5_EngineInput &engineInput, const SWV5_EngineKind expectedKind)
   {
      if(!ValidEngineKind(header.engine_kind) || header.engine_kind != expectedKind || !ValidHealth(header.health))
      {
         header.health = SWV5_HEALTH_INVALID;
         header.valid = false;
         header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         header.validation_error = "Invalid engine kind or health";
         return false;
      }
      if(header.snapshot_sequence != engineInput.market.header.sequence ||
         header.history_generation != engineInput.market.header.history_generation)
      {
         header.health = SWV5_HEALTH_INVALID;
         header.valid = false;
         header.reason_flags |= SWV5_REASON_SNAPSHOT_MISMATCH;
         header.validation_error = "Result metadata mismatch";
         return false;
      }
      if(header.health == SWV5_HEALTH_INVALID || header.health == SWV5_HEALTH_UNAVAILABLE)
      {
         header.valid = false;
         if(header.health == SWV5_HEALTH_INVALID) header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         if(header.health == SWV5_HEALTH_UNAVAILABLE) header.reason_flags |= SWV5_REASON_ENGINE_UNAVAILABLE;
         return false;
      }
      return ValidateScoreConfidence(header);
   }

public:
   bool ValidateInput(const SWV5_EngineInput &engineInput, SWV5_ValidationResult &validation)
   {
      SWV5_InitValidationResult(validation);
      SWV5_MarketSnapshot market = engineInput.market;
      SWV5_IndicatorSnapshot indicators = engineInput.indicators;

      if(market.header.schema_version != SWV5_SCHEMA_VERSION)
      {
         validation.error_text = "Market snapshot schema mismatch";
         validation.reason_flags = SWV5_REASON_SNAPSHOT_MISMATCH;
      }
      else if(!ValidExecutionMode(market.header.execution_mode))
      {
         validation.error_text = "Invalid execution mode";
         validation.reason_flags = SWV5_REASON_SNAPSHOT_MISMATCH;
      }
      else if(!market.history_token_valid ||
              (market.header.data_quality_flags & SWV5_DQ_HISTORY_TOKEN_UNAVAILABLE) != 0)
      {
         validation.error_text = "HISTORY_TOKEN_UNAVAILABLE";
         validation.health = SWV5_HEALTH_UNAVAILABLE;
         validation.reason_flags = SWV5_REASON_HISTORY_TOKEN_UNAVAILABLE;
      }
      else if(market.header.symbol == "" || market.header.timeframe == PERIOD_CURRENT ||
              market.header.closed_bar_time <= 0 || !market.has_rates)
      {
         validation.error_text = "Market snapshot data missing";
         validation.health = SWV5_HEALTH_UNAVAILABLE;
         validation.reason_flags = SWV5_REASON_DATA_MISSING;
      }
      else if((market.header.data_quality_flags & SWV5_DQ_HISTORY_CHANGED) != 0)
      {
         validation.error_text = market.history_change_reason;
         validation.reason_flags = SWV5_REASON_HISTORY_CHANGED;
      }
      else if((market.header.data_quality_flags & SWV5_DQ_STALE_DATA) != 0)
      {
         validation.error_text = market.stale_reason;
         validation.reason_flags = SWV5_REASON_STALE_SNAPSHOT;
      }
      else if((market.header.data_quality_flags & (SWV5_DQ_MISSING_DATA | SWV5_DQ_SNAPSHOT_MISMATCH | SWV5_DQ_INVALID_VALUE)) != 0)
      {
         validation.error_text = "Market snapshot data quality failure";
         validation.reason_flags = SWV5_REASON_SNAPSHOT_MISMATCH;
      }
      else if(indicators.header.schema_version != SWV5_SCHEMA_VERSION ||
              indicators.header.sequence != market.header.sequence ||
              indicators.header.history_generation != market.header.history_generation ||
              indicators.header.closed_bar_time != market.header.closed_bar_time ||
              indicators.header.symbol != market.header.symbol ||
              indicators.header.timeframe != market.header.timeframe)
      {
         validation.error_text = "Indicator snapshot metadata mismatch";
         validation.reason_flags = SWV5_REASON_SNAPSHOT_MISMATCH;
      }
      else if((indicators.header.data_quality_flags & SWV5_DQ_HISTORY_CHANGED) != 0)
      {
         validation.error_text = market.history_change_reason;
         validation.reason_flags = SWV5_REASON_HISTORY_CHANGED;
      }
      else if((indicators.header.data_quality_flags & SWV5_DQ_STALE_DATA) != 0)
      {
         validation.error_text = market.stale_reason;
         validation.reason_flags = SWV5_REASON_STALE_SNAPSHOT;
      }
      else if((indicators.header.data_quality_flags & (SWV5_DQ_MISSING_DATA | SWV5_DQ_COPYBUFFER_FAILURE |
                                                       SWV5_DQ_SNAPSHOT_MISMATCH | SWV5_DQ_INVALID_VALUE)) != 0)
      {
         validation.error_text = "Indicator snapshot data quality failure";
         validation.reason_flags = SWV5_REASON_SNAPSHOT_MISMATCH;
      }

      if(validation.error_text != "")
      {
         validation.valid = false;
         if(validation.health == SWV5_HEALTH_HEALTHY)
            validation.health = SWV5_HEALTH_INVALID;
         return false;
      }
      return true;
   }

   bool ValidateMarketSnapshot(SWV5_MarketSnapshot &market, string &error)
   {
      error = "";
      if(market.header.schema_version != SWV5_SCHEMA_VERSION)
         error = "Market snapshot schema mismatch";
      else if(!ValidExecutionMode(market.header.execution_mode))
         error = "Invalid execution mode";
      else if(market.header.symbol == "" || market.header.timeframe == PERIOD_CURRENT)
         error = "Market snapshot symbol/timeframe missing";
      else if(!market.history_token_valid ||
              (market.header.data_quality_flags & SWV5_DQ_HISTORY_TOKEN_UNAVAILABLE) != 0)
         error = "HISTORY_TOKEN_UNAVAILABLE";
      else if(market.header.closed_bar_time <= 0)
         error = "Market snapshot closed bar time missing";
      else if(!market.has_rates)
         error = "Market rates missing";
      else if((market.header.data_quality_flags & (SWV5_DQ_MISSING_DATA | SWV5_DQ_HISTORY_CHANGED | SWV5_DQ_STALE_DATA | SWV5_DQ_SNAPSHOT_MISMATCH | SWV5_DQ_INVALID_VALUE)) != 0)
         error = "Market snapshot data quality failure";

      if(error != "")
      {
         market.header.data_quality_flags |= SWV5_DQ_INVALID_VALUE;
         return false;
      }
      return true;
   }

   bool ValidateIndicatorSnapshot(SWV5_IndicatorSnapshot &indicators, const SWV5_MarketSnapshot &market, string &error)
   {
      error = "";
      if(indicators.header.schema_version != SWV5_SCHEMA_VERSION)
         error = "Indicator snapshot schema mismatch";
      else if(indicators.header.sequence != market.header.sequence ||
              indicators.header.history_generation != market.header.history_generation ||
              indicators.header.closed_bar_time != market.header.closed_bar_time ||
              indicators.header.symbol != market.header.symbol ||
              indicators.header.timeframe != market.header.timeframe)
         error = "Indicator snapshot metadata mismatch";
      else if((indicators.header.data_quality_flags & (SWV5_DQ_MISSING_DATA | SWV5_DQ_COPYBUFFER_FAILURE | SWV5_DQ_HISTORY_CHANGED | SWV5_DQ_STALE_DATA | SWV5_DQ_SNAPSHOT_MISMATCH | SWV5_DQ_INVALID_VALUE)) != 0)
         error = "Indicator snapshot data quality failure";

      if(error != "")
      {
         indicators.header.data_quality_flags |= SWV5_DQ_SNAPSHOT_MISMATCH;
         return false;
      }
      return true;
   }

   bool ValidateInput(SWV5_EngineInput &engineInput, string &error)
   {
      if(!ValidateMarketSnapshot(engineInput.market, error))
         return false;
      if(!ValidateIndicatorSnapshot(engineInput.indicators, engineInput.market, error))
         return false;
      return true;
   }

   bool ValidatePriceAction(SWV5_PriceActionResult &result, const SWV5_EngineInput &engineInput)
   {
      if(!ValidateHeader(result.header, engineInput, SWV5_ENGINE_PRICE_ACTION))
         return false;
      if(!SWV5_IsFinite(result.strength) || result.strength < 0.0 || result.strength > 1.0)
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.validation_error = "Price action strength outside 0..1";
         return false;
      }
      return true;
   }

   bool ValidateTrend(SWV5_TrendResult &result, const SWV5_EngineInput &engineInput)
   {
      if(!ValidateHeader(result.header, engineInput, SWV5_ENGINE_TREND))
         return false;
      if(result.bias < SWV5_BIAS_BEARISH || result.bias > SWV5_BIAS_BULLISH ||
         result.macro_direction < -1 || result.macro_direction > 1)
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.validation_error = "Invalid trend bias or macro direction";
         return false;
      }
      if(result.trend_up && result.trend_down)
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.validation_error = "Trend cannot be up and down simultaneously";
         return false;
      }
      if(result.trend_shift != engineInput.indicators.trend_shift ||
         result.macro_shift != engineInput.indicators.macro_shift ||
         result.use_closed != engineInput.indicators.use_closed)
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_SNAPSHOT_MISMATCH;
         result.header.validation_error = "Trend useClosed or shift metadata mismatch";
         return false;
      }
      if(!SWV5_IsFinite(result.trend_fast_value) || !SWV5_IsFinite(result.trend_slow_value) ||
         result.trend_fast_value == EMPTY_VALUE || result.trend_slow_value == EMPTY_VALUE)
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.validation_error = "Invalid H1 trend EMA value";
         return false;
      }
      if(result.macro_state != "MACRO_NOT_READY" &&
         (!SWV5_IsFinite(result.macro_fast_value) || !SWV5_IsFinite(result.macro_slow_value) ||
          result.macro_fast_value == EMPTY_VALUE || result.macro_slow_value == EMPTY_VALUE))
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.validation_error = "Invalid H4 macro EMA value";
         return false;
      }
      return true;
   }

   bool ValidateMomentum(SWV5_MomentumResult &result, const SWV5_EngineInput &engineInput)
   {
      if(!ValidateHeader(result.header, engineInput, SWV5_ENGINE_MOMENTUM))
         return false;
      if(!result.ready || result.momentum_state == "NOT_READY")
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.validation_error = "Valid momentum result cannot be not ready";
         return false;
      }
      if(result.bias < SWV5_BIAS_BEARISH || result.bias > SWV5_BIAS_BULLISH ||
         !ValidMomentumState(result.momentum_state, false) ||
         !ValidMomentumState(result.rsi_state, true) ||
         !ValidMomentumState(result.macd_state, true) ||
         !ValidMomentumState(result.stoch_state, true))
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.validation_error = "Invalid momentum bias or state";
         return false;
      }
      if(!SWV5_IsFinite(result.strength) || result.strength < 0.0 || result.strength > 1.0)
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.validation_error = "Momentum strength outside 0..1";
         return false;
      }
      if(result.use_closed != engineInput.indicators.use_closed ||
         result.source_bar_shift != engineInput.indicators.trade_indicator_shift)
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_SNAPSHOT_MISMATCH;
         result.header.validation_error = "Momentum useClosed or shift metadata mismatch";
         return false;
      }
      if(!SWV5_IsFinite(result.body_value) || !SWV5_IsFinite(result.atr_value) ||
         !SWV5_IsFinite(result.body_atr_ratio) || !SWV5_IsFinite(result.v4_body_threshold) ||
         !SWV5_IsFinite(result.v5_body_threshold) || result.body_value < 0.0 || result.atr_value <= 0.0 ||
         result.body_atr_ratio < 0.0 || result.v4_body_threshold <= 0.0 || result.v5_body_threshold <= 0.0 ||
         !SWV5_IsFinite(result.rsi_value) || result.rsi_value == EMPTY_VALUE)
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.validation_error = "Invalid momentum body, ATR, threshold, or RSI value";
         return false;
      }
      if(result.macd_state != "BYPASSED" &&
         (!SWV5_IsFinite(result.macd_main_value) || !SWV5_IsFinite(result.macd_signal_value) ||
          !SWV5_IsFinite(result.macd_histogram_value) || result.macd_main_value == EMPTY_VALUE || result.macd_signal_value == EMPTY_VALUE))
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.validation_error = "Invalid MACD momentum value";
         return false;
      }
      if(result.stoch_state != "BYPASSED" &&
         (!SWV5_IsFinite(result.stoch_k_value) || !SWV5_IsFinite(result.stoch_d_value) ||
          result.stoch_k_value == EMPTY_VALUE || result.stoch_d_value == EMPTY_VALUE))
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.validation_error = "Invalid Stochastic momentum value";
         return false;
      }
      if((result.bias == SWV5_BIAS_BULLISH && result.momentum_state != "BULLISH") ||
         (result.bias == SWV5_BIAS_BEARISH && result.momentum_state != "BEARISH") ||
         (result.bias == SWV5_BIAS_NEUTRAL && result.momentum_state != "NEUTRAL") ||
         (!result.v4_body_threshold_met && result.bias != SWV5_BIAS_NEUTRAL) ||
         result.raw_legacy_confirmation_points < 0 || result.raw_legacy_confirmation_points > 25)
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.validation_error = "Contradictory momentum result";
         return false;
      }
      return true;
   }

   bool ValidateLegacy(SWV5_LegacyResult &result, const SWV5_EngineInput &engineInput)
   {
      if(!ValidateHeader(result.header, engineInput, SWV5_ENGINE_LEGACY))
         return false;
      if(result.legacy_direction < -1 || result.legacy_direction > 1)
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.validation_error = "Invalid legacy direction";
         return false;
      }
      if(result.score_semantics < SWV5_SCORE_NONE || result.score_semantics > SWV5_SCORE_NOT_COMPARABLE ||
         !SWV5_IsFinite(result.maximum_reachable_score) || result.maximum_reachable_score < 0.0 ||
         result.maximum_reachable_score > 100.0)
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.validation_error = "Invalid legacy score contract";
         return false;
      }
      if(result.score_comparable_to_execution_threshold &&
         result.score_semantics != SWV5_SCORE_V42_COMPOSITE &&
         result.score_semantics != SWV5_SCORE_NORMALIZED_ENGINE)
      {
         result.header.health = SWV5_HEALTH_INVALID;
         result.header.valid = false;
         result.header.reason_flags |= SWV5_REASON_INVALID_ENGINE_RESULT;
         result.header.validation_error = "Legacy score comparability contradicts semantics";
         return false;
      }
      return true;
   }

   bool ValidatePolicy(SWV5_PolicyResult &result, const SWV5_EngineInput &engineInput)
   {
      return ValidateHeader(result.header, engineInput, SWV5_ENGINE_CONTEXT);
   }
};

#endif
