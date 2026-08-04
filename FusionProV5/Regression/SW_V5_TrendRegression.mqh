#ifndef SW_V5_TREND_REGRESSION_MQH
#define SW_V5_TREND_REGRESSION_MQH

#include "..\\Core\\SW_V5_Types.mqh"

enum SWV5_TrendRegressionStatus
{
   SWV5_REGRESSION_PASS = 0,
   SWV5_REGRESSION_EXPECTED_DIFFERENCE = 1,
   SWV5_REGRESSION_FAIL = 2,
   SWV5_REGRESSION_NOT_READY = 3
};

enum SWV5_TrendRegressionReason
{
   SWV5_TREND_REG_REASON_NONE = 0,
   SWV5_TREND_REG_REASON_NOT_READY = 1,
   SWV5_TREND_REG_REASON_METADATA = 2,
   SWV5_TREND_REG_REASON_SHIFT = 3,
   SWV5_TREND_REG_REASON_BIAS = 4,
   SWV5_TREND_REG_REASON_SCORE = 5,
   SWV5_TREND_REG_REASON_MACRO = 6
};

const ulong SWV5_TREND_MISMATCH_NONE = 0;
const ulong SWV5_TREND_MISMATCH_NOT_READY = 1;
const ulong SWV5_TREND_MISMATCH_METADATA = 2;
const ulong SWV5_TREND_MISMATCH_SHIFT = 4;
const ulong SWV5_TREND_MISMATCH_BIAS = 8;
const ulong SWV5_TREND_MISMATCH_SCORE = 16;
const ulong SWV5_TREND_MISMATCH_MACRO = 32;

struct SWV5_V42TrendBaseline
{
   bool            ready;
   datetime        timestamp;
   ulong           snapshot_sequence;
   ulong           history_generation;
   string          symbol;
   ENUM_TIMEFRAMES timeframe;
   ENUM_TIMEFRAMES trend_timeframe;
   ENUM_TIMEFRAMES macro_timeframe;
   int             trend_fast_period;
   int             trend_slow_period;
   bool            use_closed;
   int             trend_shift;
   int             macro_shift;
   double          trend_fast;
   double          trend_slow;
   double          macro_fast;
   double          macro_slow;
   SWV5_Bias       trend_bias;
   double          trend_score;
   int             macro_direction;
   string          macro_state;
   ulong           reason_flags;
   string          readiness_reason;
};

struct SWV5_TrendRegressionResult
{
   SWV5_TrendRegressionStatus status;
   datetime                   timestamp;
   ulong                      snapshot_sequence;
   ulong                      history_generation;
   string                     symbol;
   ENUM_TIMEFRAMES            timeframe;
   SWV5_ExecutionMode         execution_mode;
   ulong                      data_quality_flags;
   SWV5_Bias                  v4_trend_bias;
   SWV5_Bias                  v5_trend_bias;
   double                     v4_trend_score;
   double                     v5_trend_score;
   string                     v4_macro_state;
   string                     v5_macro_state;
   SWV5_TrendRegressionReason primary_reason;
   ulong                      mismatch_flags;
   string                     mismatch_reason;
   string                     csv_row;
};

string SWV5_TrendRegressionReasonText(const SWV5_TrendRegressionReason reason)
{
   if(reason == SWV5_TREND_REG_REASON_NOT_READY) return "NOT_READY";
   if(reason == SWV5_TREND_REG_REASON_METADATA) return "METADATA_MISMATCH";
   if(reason == SWV5_TREND_REG_REASON_SHIFT) return "SHIFT_MISMATCH";
   if(reason == SWV5_TREND_REG_REASON_BIAS) return "BIAS_MISMATCH";
   if(reason == SWV5_TREND_REG_REASON_SCORE) return "SCORE_MISMATCH";
   if(reason == SWV5_TREND_REG_REASON_MACRO) return "MACRO_MISMATCH";
   return "NONE";
}

string SWV5_TrendRegressionStatusText(const SWV5_TrendRegressionStatus status)
{
   if(status == SWV5_REGRESSION_PASS) return "PASS";
   if(status == SWV5_REGRESSION_EXPECTED_DIFFERENCE) return "EXPECTED_DIFFERENCE";
   if(status == SWV5_REGRESSION_FAIL) return "FAIL";
   return "NOT_READY";
}

class CTrendRegression
{
private:
   string CsvField(const string value)
   {
      string escaped = value;
      StringReplace(escaped, "\"", "\"\"");
      return "\"" + escaped + "\"";
   }

   void BuildCsvRow(SWV5_TrendRegressionResult &result)
   {
      result.csv_row = TimeToString(result.timestamp, TIME_DATE | TIME_SECONDS) + "," +
                       CsvField(result.symbol) + "," + CsvField(EnumToString(result.timeframe)) + "," +
                       CsvField(SWV5_ExecutionModeText(result.execution_mode)) + "," +
                       IntegerToString((int)result.snapshot_sequence) + "," + IntegerToString((int)result.history_generation) + "," +
                       CsvField(SWV5_BiasText(result.v4_trend_bias)) + "," +
                       CsvField(SWV5_BiasText(result.v5_trend_bias)) + "," +
                       DoubleToString(result.v4_trend_score, 1) + "," +
                       DoubleToString(result.v5_trend_score, 1) + "," +
                       CsvField(result.v4_macro_state) + "," +
                       CsvField(result.v5_macro_state) + "," +
                       CsvField(SWV5_TrendRegressionStatusText(result.status)) + "," +
                       CsvField(SWV5_TrendRegressionReasonText(result.primary_reason)) + "," +
                       IntegerToString((int)result.mismatch_flags) + "," +
                       IntegerToString((int)result.data_quality_flags) + "," +
                       CsvField(result.mismatch_reason);
   }

public:
   string CsvHeader()
   {
      return "timestamp,symbol,timeframe,execution_mode,snapshot_sequence,history_generation,v4_trend_bias,v5_trend_bias,v4_trend_score,v5_trend_score,v4_macro_state,v5_macro_state,match_status,primary_mismatch_reason,mismatch_flags,data_quality_flags,mismatch_reason";
   }

   void CaptureV42Baseline(const SWV5_EngineInput &engineInput, SWV5_V42TrendBaseline &baseline)
   {
      ZeroMemory(baseline);
      baseline.timestamp = engineInput.market.header.closed_bar_time;
      baseline.snapshot_sequence = engineInput.market.header.sequence;
      baseline.history_generation = engineInput.market.header.history_generation;
      baseline.symbol = engineInput.market.header.symbol;
      baseline.timeframe = engineInput.market.header.timeframe;
      baseline.trend_timeframe = engineInput.indicators.trend_timeframe;
      baseline.macro_timeframe = engineInput.indicators.macro_timeframe;
      baseline.trend_fast_period = engineInput.indicators.trend_fast_period;
      baseline.trend_slow_period = engineInput.indicators.trend_slow_period;
      baseline.use_closed = engineInput.indicators.use_closed;
      baseline.trend_shift = engineInput.indicators.trend_shift;
      baseline.macro_shift = engineInput.indicators.macro_shift;
      baseline.trend_fast = engineInput.indicators.trend_fast;
      baseline.trend_slow = engineInput.indicators.trend_slow;
      baseline.macro_fast = engineInput.indicators.macro_fast;
      baseline.macro_slow = engineInput.indicators.macro_slow;
      baseline.trend_bias = SWV5_BIAS_NEUTRAL;
      baseline.trend_score = 0.0;
      baseline.macro_direction = 0;
      baseline.macro_state = "MACRO_NOT_READY";
      baseline.reason_flags = SWV5_REASON_NONE;
      baseline.readiness_reason = "";

      if(!engineInput.indicators.has_trend_indicators)
      {
         baseline.reason_flags |= SWV5_REASON_DATA_MISSING;
         baseline.readiness_reason = "V4.2 H1 EMA inputs are not ready";
         return;
      }
      if(!engineInput.indicators.has_macro_indicators)
      {
         baseline.reason_flags |= SWV5_REASON_DATA_MISSING;
         baseline.readiness_reason = "V4.2 H4 EMA inputs are not ready";
         return;
      }

      if(baseline.trend_fast > baseline.trend_slow)
         baseline.trend_bias = SWV5_BIAS_BULLISH;
      else if(baseline.trend_fast < baseline.trend_slow)
         baseline.trend_bias = SWV5_BIAS_BEARISH;

      if(baseline.macro_fast > baseline.macro_slow)
      {
         baseline.macro_direction = 1;
         baseline.macro_state = "MACRO_UP";
      }
      else if(baseline.macro_fast < baseline.macro_slow)
      {
         baseline.macro_direction = -1;
         baseline.macro_state = "MACRO_DOWN";
      }
      else
      {
         baseline.macro_state = "MACRO_FLAT";
      }

      baseline.ready = true;
      baseline.readiness_reason = "V4.2 trend oracle ready";
   }

   bool Compare(const SWV5_EngineInput &engineInput,
                const SWV5_TrendResult &trend,
                SWV5_TrendRegressionResult &result)
   {
      ZeroMemory(result);
      result.status = SWV5_REGRESSION_NOT_READY;
      result.timestamp = engineInput.market.header.closed_bar_time;
      result.snapshot_sequence = engineInput.market.header.sequence;
      result.history_generation = engineInput.market.header.history_generation;
      result.symbol = engineInput.market.header.symbol;
      result.timeframe = engineInput.market.header.timeframe;
      result.execution_mode = engineInput.market.header.execution_mode;
      result.data_quality_flags = engineInput.market.header.data_quality_flags | engineInput.indicators.header.data_quality_flags;
      result.primary_reason = SWV5_TREND_REG_REASON_NOT_READY;
      result.mismatch_flags = SWV5_TREND_MISMATCH_NOT_READY;
      result.v4_trend_bias = SWV5_BIAS_NEUTRAL;
      result.v5_trend_bias = trend.bias;
      result.v4_trend_score = 0.0;
      result.v5_trend_score = trend.header.score;
      result.v4_macro_state = "MACRO_NOT_READY";
      result.v5_macro_state = trend.macro_state;
      result.mismatch_reason = "";

      SWV5_V42TrendBaseline baseline;
      CaptureV42Baseline(engineInput, baseline);
      result.v4_trend_bias = baseline.trend_bias;
      result.v4_trend_score = baseline.trend_score;
      result.v4_macro_state = baseline.macro_state;

      if(!baseline.ready || !trend.header.valid)
      {
         result.status = SWV5_REGRESSION_NOT_READY;
         result.mismatch_reason = (!baseline.ready ? baseline.readiness_reason : "V5 trend result is not valid");
         BuildCsvRow(result);
         return false;
      }

      if(trend.header.snapshot_sequence != baseline.snapshot_sequence ||
         trend.header.history_generation != baseline.history_generation)
      {
         result.status = SWV5_REGRESSION_FAIL;
         result.primary_reason = SWV5_TREND_REG_REASON_METADATA;
         result.mismatch_flags = SWV5_TREND_MISMATCH_METADATA;
         result.mismatch_reason = "Snapshot metadata mismatch";
      }
      else if(trend.trend_shift != baseline.trend_shift || trend.macro_shift != baseline.macro_shift ||
              trend.use_closed != baseline.use_closed)
      {
         result.status = SWV5_REGRESSION_FAIL;
         result.primary_reason = SWV5_TREND_REG_REASON_SHIFT;
         result.mismatch_flags = SWV5_TREND_MISMATCH_SHIFT;
         result.mismatch_reason = "useClosed or bar-shift mismatch";
      }
      else if(trend.bias != baseline.trend_bias)
      {
         result.status = SWV5_REGRESSION_FAIL;
         result.primary_reason = SWV5_TREND_REG_REASON_BIAS;
         result.mismatch_flags = SWV5_TREND_MISMATCH_BIAS;
         result.mismatch_reason = "Trend bias mismatch";
      }
      else if(trend.header.score != baseline.trend_score)
      {
         result.status = SWV5_REGRESSION_FAIL;
         result.primary_reason = SWV5_TREND_REG_REASON_SCORE;
         result.mismatch_flags = SWV5_TREND_MISMATCH_SCORE;
         result.mismatch_reason = "Standalone trend score mismatch";
      }
      else if(trend.macro_direction != baseline.macro_direction || trend.macro_state != baseline.macro_state)
      {
         result.status = SWV5_REGRESSION_FAIL;
         result.primary_reason = SWV5_TREND_REG_REASON_MACRO;
         result.mismatch_flags = SWV5_TREND_MISMATCH_MACRO;
         result.mismatch_reason = "Macro trend mismatch";
      }
      else
      {
         result.status = SWV5_REGRESSION_PASS;
         result.primary_reason = SWV5_TREND_REG_REASON_NONE;
         result.mismatch_flags = SWV5_TREND_MISMATCH_NONE;
         result.mismatch_reason = "";
      }

      BuildCsvRow(result);
      return (result.status == SWV5_REGRESSION_PASS || result.status == SWV5_REGRESSION_EXPECTED_DIFFERENCE);
   }
};

#endif
