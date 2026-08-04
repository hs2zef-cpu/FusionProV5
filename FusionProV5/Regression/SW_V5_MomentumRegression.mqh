#ifndef SW_V5_MOMENTUM_REGRESSION_MQH
#define SW_V5_MOMENTUM_REGRESSION_MQH

#include "..\\Core\\SW_V5_Types.mqh"

enum SWV5_MomentumRegressionStatus
{
   SWV5_MOMENTUM_REGRESSION_PASS = 0,
   SWV5_MOMENTUM_REGRESSION_EXPECTED_DIFFERENCE = 1,
   SWV5_MOMENTUM_REGRESSION_FAIL = 2,
   SWV5_MOMENTUM_REGRESSION_NOT_READY = 3
};

enum SWV5_MomentumRegressionReason
{
   SWV5_MOMENTUM_REG_REASON_NONE = 0,
   SWV5_MOMENTUM_REG_REASON_NOT_READY = 1,
   SWV5_MOMENTUM_REG_REASON_METADATA_MISMATCH = 2,
   SWV5_MOMENTUM_REG_REASON_SHIFT_MISMATCH = 3,
   SWV5_MOMENTUM_REG_REASON_BODY_ATR_MISMATCH = 4,
   SWV5_MOMENTUM_REG_REASON_RSI_VALUE_MISMATCH = 5,
   SWV5_MOMENTUM_REG_REASON_RSI_STATE_MISMATCH = 6,
   SWV5_MOMENTUM_REG_REASON_MACD_HISTOGRAM_MISMATCH = 7,
   SWV5_MOMENTUM_REG_REASON_MACD_STATE_MISMATCH = 8,
   SWV5_MOMENTUM_REG_REASON_STOCH_K_MISMATCH = 9,
   SWV5_MOMENTUM_REG_REASON_STOCH_STATE_MISMATCH = 10,
   SWV5_MOMENTUM_REG_REASON_BIAS_MISMATCH = 11,
   SWV5_MOMENTUM_REG_REASON_MOMENTUM_STATE_MISMATCH = 12,
   SWV5_MOMENTUM_REG_REASON_SCORE_MISMATCH = 13,
   SWV5_MOMENTUM_REG_REASON_MULTIPLE_MISMATCHES = 14
};

const ulong SWV5_MOMENTUM_MISMATCH_NONE           = 0;
const ulong SWV5_MOMENTUM_MISMATCH_NOT_READY      = 1;
const ulong SWV5_MOMENTUM_MISMATCH_METADATA       = 2;
const ulong SWV5_MOMENTUM_MISMATCH_SHIFT          = 4;
const ulong SWV5_MOMENTUM_MISMATCH_BODY_ATR       = 8;
const ulong SWV5_MOMENTUM_MISMATCH_RSI_VALUE      = 16;
const ulong SWV5_MOMENTUM_MISMATCH_RSI_STATE      = 32;
const ulong SWV5_MOMENTUM_MISMATCH_MACD_HISTOGRAM = 64;
const ulong SWV5_MOMENTUM_MISMATCH_MACD_STATE     = 128;
const ulong SWV5_MOMENTUM_MISMATCH_STOCH_K        = 256;
const ulong SWV5_MOMENTUM_MISMATCH_STOCH_STATE    = 512;
const ulong SWV5_MOMENTUM_MISMATCH_BIAS           = 1024;
const ulong SWV5_MOMENTUM_MISMATCH_MOMENTUM_STATE = 2048;
const ulong SWV5_MOMENTUM_MISMATCH_SCORE          = 4096;

struct SWV5_V42MomentumBaseline
{
   bool                ready;
   datetime            timestamp;
   string              symbol;
   ENUM_TIMEFRAMES     timeframe;
   SWV5_ExecutionMode  execution_mode;
   bool                use_closed;
   int                 source_bar_shift;
   ulong               snapshot_sequence;
   ulong               history_generation;
   ulong               data_quality_flags;
   double              rsi_value;
   string              rsi_state;
   double              macd_main;
   double              macd_signal;
   double              macd_histogram;
   string              macd_state;
   double              stoch_k;
   double              stoch_d;
   string              stoch_state;
   double              body_value;
   double              body_atr_ratio;
   bool                v4_body_threshold_met;
   bool                v5_body_threshold_met;
   SWV5_Bias           momentum_bias;
   string              momentum_state;
   double              momentum_score;
   int                 raw_legacy_confirmation_points;
   string              readiness_reason;
};

struct SWV5_MomentumRegressionResult
{
   SWV5_MomentumRegressionStatus status;
   SWV5_MomentumRegressionReason primary_reason;
   ulong                         mismatch_flags;
   string                        diagnostic_text;
   datetime                      timestamp;
   string                        symbol;
   ENUM_TIMEFRAMES               timeframe;
   SWV5_ExecutionMode            execution_mode;
   bool                          use_closed;
   int                           source_bar_shift;
   ulong                         snapshot_sequence;
   ulong                         history_generation;
   ulong                         data_quality_flags;
   string                        v4_rsi_state;
   string                        v5_rsi_state;
   double                        v4_rsi_value;
   double                        v5_rsi_value;
   string                        v4_macd_state;
   string                        v5_macd_state;
   double                        v4_macd_value;
   double                        v5_macd_value;
   string                        v4_stoch_state;
   string                        v5_stoch_state;
   double                        v4_stoch_value;
   double                        v5_stoch_value;
   SWV5_Bias                     v4_momentum_bias;
   SWV5_Bias                     v5_momentum_bias;
   double                        v4_momentum_score;
   double                        v5_momentum_score;
   bool                          v4_ready;
   bool                          v5_ready;
   string                        mismatch_reason;
   string                        csv_row;
};

string SWV5_MomentumRegressionStatusText(const SWV5_MomentumRegressionStatus status)
{
   if(status == SWV5_MOMENTUM_REGRESSION_PASS) return "PASS";
   if(status == SWV5_MOMENTUM_REGRESSION_EXPECTED_DIFFERENCE) return "EXPECTED_DIFFERENCE";
   if(status == SWV5_MOMENTUM_REGRESSION_FAIL) return "FAIL";
   return "NOT_READY";
}

string SWV5_MomentumRegressionReasonText(const SWV5_MomentumRegressionReason reason)
{
   if(reason == SWV5_MOMENTUM_REG_REASON_NOT_READY) return "NOT READY";
   if(reason == SWV5_MOMENTUM_REG_REASON_METADATA_MISMATCH) return "METADATA";
   if(reason == SWV5_MOMENTUM_REG_REASON_SHIFT_MISMATCH) return "SHIFT";
   if(reason == SWV5_MOMENTUM_REG_REASON_BODY_ATR_MISMATCH) return "BODY / ATR";
   if(reason == SWV5_MOMENTUM_REG_REASON_RSI_VALUE_MISMATCH) return "RSI VALUE";
   if(reason == SWV5_MOMENTUM_REG_REASON_RSI_STATE_MISMATCH) return "RSI STATE";
   if(reason == SWV5_MOMENTUM_REG_REASON_MACD_HISTOGRAM_MISMATCH) return "MACD HIST";
   if(reason == SWV5_MOMENTUM_REG_REASON_MACD_STATE_MISMATCH) return "MACD STATE";
   if(reason == SWV5_MOMENTUM_REG_REASON_STOCH_K_MISMATCH) return "STOCH K";
   if(reason == SWV5_MOMENTUM_REG_REASON_STOCH_STATE_MISMATCH) return "STOCH STATE";
   if(reason == SWV5_MOMENTUM_REG_REASON_BIAS_MISMATCH) return "BIAS";
   if(reason == SWV5_MOMENTUM_REG_REASON_MOMENTUM_STATE_MISMATCH) return "MOMENTUM STATE";
   if(reason == SWV5_MOMENTUM_REG_REASON_SCORE_MISMATCH) return "SCORE";
   if(reason == SWV5_MOMENTUM_REG_REASON_MULTIPLE_MISMATCHES) return "MULTIPLE";
   return "NONE";
}

class CMomentumRegression
{
private:
   double m_v4BodyAtr;
   double m_v5BodyAtr;
   bool   m_useRsi50;
   bool   m_useMacd;
   bool   m_useStoch;
   double m_stochOb;
   double m_stochOs;

   string CsvField(const string value)
   {
      string escaped = value;
      StringReplace(escaped, "\"", "\"\"");
      return "\"" + escaped + "\"";
   }

   bool SameValue(const double left, const double right)
   {
      if(left == EMPTY_VALUE || right == EMPTY_VALUE)
         return left == right;
      return MathAbs(left - right) <= 0.000000000001;
   }

   void AddMismatch(ulong &flags,
                    int &count,
                    string &details,
                    const ulong flag,
                    const string detail)
   {
      if((flags & flag) != 0)
         return;
      flags |= flag;
      count++;
      if(details != "")
         details += "; ";
      details += detail;
   }

   SWV5_MomentumRegressionReason SingleReason(const ulong flags)
   {
      if((flags & SWV5_MOMENTUM_MISMATCH_METADATA) != 0) return SWV5_MOMENTUM_REG_REASON_METADATA_MISMATCH;
      if((flags & SWV5_MOMENTUM_MISMATCH_SHIFT) != 0) return SWV5_MOMENTUM_REG_REASON_SHIFT_MISMATCH;
      if((flags & SWV5_MOMENTUM_MISMATCH_BODY_ATR) != 0) return SWV5_MOMENTUM_REG_REASON_BODY_ATR_MISMATCH;
      if((flags & SWV5_MOMENTUM_MISMATCH_RSI_VALUE) != 0) return SWV5_MOMENTUM_REG_REASON_RSI_VALUE_MISMATCH;
      if((flags & SWV5_MOMENTUM_MISMATCH_RSI_STATE) != 0) return SWV5_MOMENTUM_REG_REASON_RSI_STATE_MISMATCH;
      if((flags & SWV5_MOMENTUM_MISMATCH_MACD_HISTOGRAM) != 0) return SWV5_MOMENTUM_REG_REASON_MACD_HISTOGRAM_MISMATCH;
      if((flags & SWV5_MOMENTUM_MISMATCH_MACD_STATE) != 0) return SWV5_MOMENTUM_REG_REASON_MACD_STATE_MISMATCH;
      if((flags & SWV5_MOMENTUM_MISMATCH_STOCH_K) != 0) return SWV5_MOMENTUM_REG_REASON_STOCH_K_MISMATCH;
      if((flags & SWV5_MOMENTUM_MISMATCH_STOCH_STATE) != 0) return SWV5_MOMENTUM_REG_REASON_STOCH_STATE_MISMATCH;
      if((flags & SWV5_MOMENTUM_MISMATCH_BIAS) != 0) return SWV5_MOMENTUM_REG_REASON_BIAS_MISMATCH;
      if((flags & SWV5_MOMENTUM_MISMATCH_MOMENTUM_STATE) != 0) return SWV5_MOMENTUM_REG_REASON_MOMENTUM_STATE_MISMATCH;
      if((flags & SWV5_MOMENTUM_MISMATCH_SCORE) != 0) return SWV5_MOMENTUM_REG_REASON_SCORE_MISMATCH;
      return SWV5_MOMENTUM_REG_REASON_NONE;
   }

   SWV5_MomentumRegressionReason PrimaryReason(const ulong flags, const int mismatchCount)
   {
      if((flags & SWV5_MOMENTUM_MISMATCH_METADATA) != 0)
         return SWV5_MOMENTUM_REG_REASON_METADATA_MISMATCH;
      if((flags & SWV5_MOMENTUM_MISMATCH_SHIFT) != 0)
         return SWV5_MOMENTUM_REG_REASON_SHIFT_MISMATCH;
      if(mismatchCount > 1)
         return SWV5_MOMENTUM_REG_REASON_MULTIPLE_MISMATCHES;
      return SingleReason(flags);
   }

   void BuildCsvRow(SWV5_MomentumRegressionResult &result)
   {
      result.csv_row = TimeToString(result.timestamp, TIME_DATE | TIME_SECONDS) + "," +
                       CsvField(result.symbol) + "," + CsvField(EnumToString(result.timeframe)) + "," +
                       CsvField(SWV5_ExecutionModeText(result.execution_mode)) + "," +
                       (result.use_closed ? "true" : "false") + "," + IntegerToString(result.source_bar_shift) + "," +
                       IntegerToString((int)result.snapshot_sequence) + "," + IntegerToString((int)result.history_generation) + "," +
                       IntegerToString((int)result.data_quality_flags) + "," +
                       CsvField(result.v4_rsi_state) + "," + DoubleToString(result.v4_rsi_value, 8) + "," +
                       CsvField(result.v5_rsi_state) + "," + DoubleToString(result.v5_rsi_value, 8) + "," +
                       CsvField(result.v4_macd_state) + "," + DoubleToString(result.v4_macd_value, 8) + "," +
                       CsvField(result.v5_macd_state) + "," + DoubleToString(result.v5_macd_value, 8) + "," +
                       CsvField(result.v4_stoch_state) + "," + DoubleToString(result.v4_stoch_value, 8) + "," +
                       CsvField(result.v5_stoch_state) + "," + DoubleToString(result.v5_stoch_value, 8) + "," +
                       CsvField(SWV5_BiasText(result.v4_momentum_bias)) + "," + CsvField(SWV5_BiasText(result.v5_momentum_bias)) + "," +
                       DoubleToString(result.v4_momentum_score, 1) + "," + DoubleToString(result.v5_momentum_score, 1) + "," +
                       (result.v4_ready ? "true" : "false") + "," + (result.v5_ready ? "true" : "false") + "," +
                       CsvField(SWV5_MomentumRegressionStatusText(result.status)) + "," +
                       CsvField(SWV5_MomentumRegressionReasonText(result.primary_reason)) + "," +
                       IntegerToString((int)result.mismatch_flags) + "," +
                       CsvField(result.diagnostic_text) + "," + CsvField(result.mismatch_reason);
   }

public:
   CMomentumRegression()
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

   string CsvHeader()
   {
      return "timestamp,symbol,timeframe,execution_mode,use_closed,source_bar_shift,snapshot_sequence,history_generation,data_quality_flags,v4_rsi_state,v4_rsi_value,v5_rsi_state,v5_rsi_value,v4_macd_state,v4_macd_histogram,v5_macd_state,v5_macd_histogram,v4_stoch_state,v4_stoch_k,v5_stoch_state,v5_stoch_k,v4_momentum_bias,v5_momentum_bias,v4_momentum_score,v5_momentum_score,v4_ready,v5_ready,match_status,primary_reason,mismatch_flags,diagnostic_text,mismatch_reason";
   }

   void CaptureV42Baseline(const SWV5_EngineInput &engineInput, SWV5_V42MomentumBaseline &baseline)
   {
      ZeroMemory(baseline);
      baseline.symbol = engineInput.market.header.symbol;
      baseline.timeframe = engineInput.market.header.timeframe;
      baseline.execution_mode = engineInput.market.header.execution_mode;
      baseline.use_closed = engineInput.indicators.use_closed;
      baseline.source_bar_shift = engineInput.indicators.trade_indicator_shift;
      baseline.snapshot_sequence = engineInput.market.header.sequence;
      baseline.history_generation = engineInput.market.header.history_generation;
      baseline.data_quality_flags = engineInput.indicators.header.data_quality_flags;
      baseline.rsi_value = engineInput.indicators.rsi;
      baseline.rsi_state = "NOT_READY";
      baseline.macd_main = EMPTY_VALUE;
      baseline.macd_signal = EMPTY_VALUE;
      baseline.macd_histogram = 0.0;
      baseline.macd_state = "NOT_READY";
      baseline.stoch_k = 0.0;
      baseline.stoch_d = 0.0;
      baseline.stoch_state = "NOT_READY";
      baseline.momentum_bias = SWV5_BIAS_NEUTRAL;
      baseline.momentum_state = "NOT_READY";
      baseline.momentum_score = 0.0;
      baseline.raw_legacy_confirmation_points = 0;
      baseline.readiness_reason = "";

      MqlRates bar;
      if(baseline.use_closed)
         bar = engineInput.market.closed_bar;
      else
         bar = engineInput.market.current_bar;
      baseline.timestamp = bar.time;

      bool requiredReady = (engineInput.market.has_rates && engineInput.indicators.has_momentum_indicators &&
                            engineInput.indicators.has_rsi && engineInput.indicators.has_atr &&
                            (!m_useMacd || engineInput.indicators.has_macd) && (!m_useStoch || engineInput.indicators.has_stoch));
      if(!requiredReady || engineInput.indicators.atr <= 0.0)
      {
         baseline.readiness_reason = "V4.2 momentum inputs are not ready";
         return;
      }

      baseline.body_value = MathAbs(bar.close - bar.open);
      baseline.body_atr_ratio = baseline.body_value / engineInput.indicators.atr;
      baseline.v4_body_threshold_met = !(baseline.body_value < engineInput.indicators.atr * m_v4BodyAtr);
      baseline.v5_body_threshold_met = !(baseline.body_value < engineInput.indicators.atr * m_v5BodyAtr);

      if(!m_useRsi50)
         baseline.rsi_state = "BYPASSED";
      else if(baseline.rsi_value > 50.0)
         baseline.rsi_state = "BULLISH";
      else if(baseline.rsi_value < 50.0)
         baseline.rsi_state = "BEARISH";
      else
         baseline.rsi_state = "NEUTRAL";

      if(!m_useMacd)
         baseline.macd_state = "BYPASSED";
      else
      {
         baseline.macd_main = engineInput.indicators.macd_main;
         baseline.macd_signal = engineInput.indicators.macd_signal;
         baseline.macd_histogram = baseline.macd_main - baseline.macd_signal;
         if(baseline.macd_main > baseline.macd_signal || baseline.macd_histogram > 0.0)
            baseline.macd_state = "BULLISH";
         else if(baseline.macd_main < baseline.macd_signal || baseline.macd_histogram < 0.0)
            baseline.macd_state = "BEARISH";
         else
            baseline.macd_state = "NEUTRAL";
      }

      if(!m_useStoch)
         baseline.stoch_state = "BYPASSED";
      else
      {
         baseline.stoch_k = engineInput.indicators.stoch_k;
         baseline.stoch_d = engineInput.indicators.stoch_d;
         if(baseline.stoch_k > baseline.stoch_d && baseline.stoch_k > m_stochOs)
            baseline.stoch_state = "BULLISH";
         else if(baseline.stoch_k < baseline.stoch_d && baseline.stoch_k < m_stochOb)
            baseline.stoch_state = "BEARISH";
         else
            baseline.stoch_state = "NEUTRAL";
      }

      if(baseline.v4_body_threshold_met && bar.close > bar.open)
      {
         baseline.momentum_bias = SWV5_BIAS_BULLISH;
         baseline.momentum_state = "BULLISH";
      }
      else if(baseline.v4_body_threshold_met && bar.close < bar.open)
      {
         baseline.momentum_bias = SWV5_BIAS_BEARISH;
         baseline.momentum_state = "BEARISH";
      }
      else
         baseline.momentum_state = "NEUTRAL";

      baseline.ready = true;
      baseline.readiness_reason = "V4.2 momentum oracle ready";
   }

   bool Compare(const SWV5_EngineInput &engineInput,
                const SWV5_MomentumResult &momentum,
                SWV5_MomentumRegressionResult &result)
   {
      ZeroMemory(result);
      result.status = SWV5_MOMENTUM_REGRESSION_NOT_READY;
      result.primary_reason = SWV5_MOMENTUM_REG_REASON_NOT_READY;
      result.mismatch_flags = SWV5_MOMENTUM_MISMATCH_NOT_READY;
      result.diagnostic_text = "NOT READY";
      result.symbol = engineInput.market.header.symbol;
      result.timeframe = engineInput.market.header.timeframe;
      result.execution_mode = engineInput.market.header.execution_mode;
      result.use_closed = engineInput.indicators.use_closed;
      result.source_bar_shift = engineInput.indicators.trade_indicator_shift;
      result.snapshot_sequence = engineInput.market.header.sequence;
      result.history_generation = engineInput.market.header.history_generation;
      result.data_quality_flags = engineInput.market.header.data_quality_flags | engineInput.indicators.header.data_quality_flags;
      result.v5_rsi_state = momentum.rsi_state;
      result.v5_rsi_value = momentum.rsi_value;
      result.v5_macd_state = momentum.macd_state;
      result.v5_macd_value = momentum.macd_histogram_value;
      result.v5_stoch_state = momentum.stoch_state;
      result.v5_stoch_value = momentum.stoch_k_value;
      result.v5_momentum_bias = momentum.bias;
      result.v5_momentum_score = momentum.header.score;
      result.v5_ready = momentum.ready;

      SWV5_V42MomentumBaseline baseline;
      CaptureV42Baseline(engineInput, baseline);
      result.timestamp = baseline.timestamp;
      result.v4_rsi_state = baseline.rsi_state;
      result.v4_rsi_value = baseline.rsi_value;
      result.v4_macd_state = baseline.macd_state;
      result.v4_macd_value = baseline.macd_histogram;
      result.v4_stoch_state = baseline.stoch_state;
      result.v4_stoch_value = baseline.stoch_k;
      result.v4_momentum_bias = baseline.momentum_bias;
      result.v4_momentum_score = baseline.momentum_score;
      result.v4_ready = baseline.ready;

      if(!baseline.ready || !momentum.header.valid || !momentum.ready)
      {
         if(!baseline.ready)
         {
            result.diagnostic_text = "V4 INPUT NOT READY";
            result.mismatch_reason = baseline.readiness_reason;
         }
         else if(!momentum.header.valid)
         {
            result.diagnostic_text = "V5 RESULT INVALID";
            result.mismatch_reason = "V5 momentum result is not valid";
         }
         else
         {
            result.diagnostic_text = "V5 NOT READY";
            result.mismatch_reason = "V5 momentum result is not ready";
         }
         BuildCsvRow(result);
         return false;
      }

      result.primary_reason = SWV5_MOMENTUM_REG_REASON_NONE;
      result.mismatch_flags = SWV5_MOMENTUM_MISMATCH_NONE;
      result.diagnostic_text = "NONE";
      result.mismatch_reason = "";
      int mismatchCount = 0;

      if(momentum.header.snapshot_sequence != baseline.snapshot_sequence ||
         momentum.header.history_generation != baseline.history_generation)
         AddMismatch(result.mismatch_flags, mismatchCount, result.mismatch_reason,
                     SWV5_MOMENTUM_MISMATCH_METADATA, "Snapshot metadata mismatch");
      if(momentum.use_closed != baseline.use_closed || momentum.source_bar_shift != baseline.source_bar_shift)
         AddMismatch(result.mismatch_flags, mismatchCount, result.mismatch_reason,
                     SWV5_MOMENTUM_MISMATCH_SHIFT, "useClosed or source-bar shift mismatch");
      if(!SameValue(momentum.rsi_value, baseline.rsi_value))
         AddMismatch(result.mismatch_flags, mismatchCount, result.mismatch_reason,
                     SWV5_MOMENTUM_MISMATCH_RSI_VALUE, "RSI value mismatch");
      if(momentum.rsi_state != baseline.rsi_state)
         AddMismatch(result.mismatch_flags, mismatchCount, result.mismatch_reason,
                     SWV5_MOMENTUM_MISMATCH_RSI_STATE, "RSI state mismatch");
      if(!SameValue(momentum.macd_histogram_value, baseline.macd_histogram))
         AddMismatch(result.mismatch_flags, mismatchCount, result.mismatch_reason,
                     SWV5_MOMENTUM_MISMATCH_MACD_HISTOGRAM, "MACD histogram mismatch");
      if(momentum.macd_state != baseline.macd_state)
         AddMismatch(result.mismatch_flags, mismatchCount, result.mismatch_reason,
                     SWV5_MOMENTUM_MISMATCH_MACD_STATE, "MACD state mismatch");
      if(!SameValue(momentum.stoch_k_value, baseline.stoch_k))
         AddMismatch(result.mismatch_flags, mismatchCount, result.mismatch_reason,
                     SWV5_MOMENTUM_MISMATCH_STOCH_K, "Stochastic K mismatch");
      if(momentum.stoch_state != baseline.stoch_state)
         AddMismatch(result.mismatch_flags, mismatchCount, result.mismatch_reason,
                     SWV5_MOMENTUM_MISMATCH_STOCH_STATE, "Stochastic state mismatch");
      if(momentum.bias != baseline.momentum_bias)
         AddMismatch(result.mismatch_flags, mismatchCount, result.mismatch_reason,
                     SWV5_MOMENTUM_MISMATCH_BIAS, "Momentum bias mismatch");
      if(momentum.momentum_state != baseline.momentum_state)
         AddMismatch(result.mismatch_flags, mismatchCount, result.mismatch_reason,
                     SWV5_MOMENTUM_MISMATCH_MOMENTUM_STATE, "Momentum state mismatch");
      if(momentum.header.score != baseline.momentum_score ||
         momentum.raw_legacy_confirmation_points != baseline.raw_legacy_confirmation_points)
         AddMismatch(result.mismatch_flags, mismatchCount, result.mismatch_reason,
                     SWV5_MOMENTUM_MISMATCH_SCORE, "Standalone momentum contribution mismatch");
      if(momentum.v4_body_threshold_met != baseline.v4_body_threshold_met ||
         momentum.v5_body_threshold_met != baseline.v5_body_threshold_met ||
         !SameValue(momentum.body_value, baseline.body_value) ||
         !SameValue(momentum.body_atr_ratio, baseline.body_atr_ratio))
         AddMismatch(result.mismatch_flags, mismatchCount, result.mismatch_reason,
                     SWV5_MOMENTUM_MISMATCH_BODY_ATR, "Body/ATR qualifier mismatch");

      if(mismatchCount == 0)
      {
         result.status = SWV5_MOMENTUM_REGRESSION_PASS;
         result.primary_reason = SWV5_MOMENTUM_REG_REASON_NONE;
         result.diagnostic_text = "NONE";
      }
      else
      {
         result.status = SWV5_MOMENTUM_REGRESSION_FAIL;
         result.primary_reason = PrimaryReason(result.mismatch_flags, mismatchCount);
         result.diagnostic_text = SWV5_MomentumRegressionReasonText(result.primary_reason);
      }

      BuildCsvRow(result);
      return (result.status == SWV5_MOMENTUM_REGRESSION_PASS || result.status == SWV5_MOMENTUM_REGRESSION_EXPECTED_DIFFERENCE);
   }
};

#endif
