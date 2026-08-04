#ifndef SW_V5_TYPES_MQH
#define SW_V5_TYPES_MQH

#define SWV5_SCHEMA_VERSION 5

enum SWV5_Bias
{
   SWV5_BIAS_BEARISH = -1,
   SWV5_BIAS_NEUTRAL = 0,
   SWV5_BIAS_BULLISH = 1
};

enum SWV5_ExecutionMode
{
   SWV5_EXECUTION_CLOSED_BAR = 0,
   SWV5_EXECUTION_EVERY_TICK = 1,
   SWV5_EXECUTION_REPLAY = 2
};

enum SWV5_DecisionAction
{
   SWV5_ACTION_WAIT = 0,
   SWV5_ACTION_BUY = 1,
   SWV5_ACTION_SELL = -1,
   SWV5_ACTION_BLOCKED = 9
};

enum SWV5_EngineKind
{
   SWV5_ENGINE_MARKET = 0,
   SWV5_ENGINE_TREND = 1,
   SWV5_ENGINE_MOMENTUM = 2,
   SWV5_ENGINE_VOLUME = 3,
   SWV5_ENGINE_STRUCTURE = 4,
   SWV5_ENGINE_PRICE_ACTION = 5,
   SWV5_ENGINE_CONTEXT = 6,
   SWV5_ENGINE_CONFIRMATION = 7,
   SWV5_ENGINE_RISK = 8,
   SWV5_ENGINE_DECISION = 9,
   SWV5_ENGINE_LEGACY = 10
};

enum SWV5_EngineHealth
{
   SWV5_HEALTH_HEALTHY = 0,
   SWV5_HEALTH_DEGRADED = 1,
   SWV5_HEALTH_UNAVAILABLE = 2,
   SWV5_HEALTH_INVALID = 3
};

enum SWV5_ScoreSemantics
{
   SWV5_SCORE_NONE = 0,
   SWV5_SCORE_LEGACY_FIXED = 1,
   SWV5_SCORE_V42_COMPOSITE = 2,
   SWV5_SCORE_NORMALIZED_ENGINE = 3,
   SWV5_SCORE_NOT_COMPARABLE = 4
};

enum SWV5_HistoryChangeState
{
   SWV5_HISTORY_BASELINE_RESET = 0,
   SWV5_HISTORY_NORMAL = 1,
   SWV5_HISTORY_SHRINK = 2,
   SWV5_HISTORY_RESET = 3,
   SWV5_HISTORY_ABNORMAL_JUMP = 4,
   SWV5_HISTORY_TOKEN_UNAVAILABLE = 5
};

enum SWV5_HistoryReason
{
   SWV5_HISTORY_REASON_NONE = 0,
   SWV5_HISTORY_REASON_BASELINE_INITIALIZED = 1,
   SWV5_HISTORY_REASON_NORMAL_INCREMENT = 2,
   SWV5_HISTORY_REASON_CONTEXT_RESET = 3,
   SWV5_HISTORY_REASON_TOKEN_UNAVAILABLE = 4,
   SWV5_HISTORY_REASON_HISTORY_SHRINK = 5,
   SWV5_HISTORY_REASON_HISTORY_RESET = 6,
   SWV5_HISTORY_REASON_ABNORMAL_JUMP = 7,
   SWV5_HISTORY_REASON_NORMAL_UNCHANGED = 8,
   SWV5_HISTORY_REASON_TOKEN_RECOVERED = 9
};

enum SWV5_StaleState
{
   SWV5_STALE_NOT_CHECKED = 0,
   SWV5_STALE_FRESH = 1,
   SWV5_STALE_MARKET_CLOSED = 2,
   SWV5_STALE_CLOSED_BAR_OLD = 3,
   SWV5_STALE_TICK_FROZEN = 4,
   SWV5_STALE_REPLAY_DISABLED = 5
};

const ulong SWV5_DQ_NONE              = 0;
const ulong SWV5_DQ_MISSING_DATA      = 1;
const ulong SWV5_DQ_PARTIAL_DATA      = 2;
const ulong SWV5_DQ_COPYBUFFER_FAILURE= 4;
const ulong SWV5_DQ_HISTORY_CHANGED   = 8;
const ulong SWV5_DQ_STALE_DATA        = 16;
const ulong SWV5_DQ_SNAPSHOT_MISMATCH = 32;
const ulong SWV5_DQ_INVALID_VALUE     = 64;
const ulong SWV5_DQ_HISTORY_TOKEN_UNAVAILABLE = 128;

const ulong SWV5_REASON_NONE                  = 0;
const ulong SWV5_REASON_DATA_MISSING          = 1;
const ulong SWV5_REASON_PARTIAL_DATA          = 2;
const ulong SWV5_REASON_COPYBUFFER_FAILED     = 4;
const ulong SWV5_REASON_HISTORY_CHANGED       = 8;
const ulong SWV5_REASON_STALE_SNAPSHOT        = 16;
const ulong SWV5_REASON_SNAPSHOT_MISMATCH     = 32;
const ulong SWV5_REASON_ENGINE_DEGRADED       = 64;
const ulong SWV5_REASON_ENGINE_UNAVAILABLE    = 128;
const ulong SWV5_REASON_INVALID_ENGINE_RESULT = 256;
const ulong SWV5_REASON_LEGACY_BUY            = 512;
const ulong SWV5_REASON_LEGACY_SELL           = 1024;
const ulong SWV5_REASON_NO_FINAL_RULE_MIGRATED= 2048;
const ulong SWV5_REASON_POLICY_BLOCK          = 4096;
const ulong SWV5_REASON_PRICE_ACTION_NEUTRAL  = 8192;
const ulong SWV5_REASON_TREND_UP              = 16384;
const ulong SWV5_REASON_TREND_DOWN            = 32768;
const ulong SWV5_REASON_TREND_FLAT            = 65536;
const ulong SWV5_REASON_MACRO_UP              = 131072;
const ulong SWV5_REASON_MACRO_DOWN            = 262144;
const ulong SWV5_REASON_MACRO_FLAT            = 524288;
const ulong SWV5_REASON_MOMENTUM_BODY_MET      = 1048576;
const ulong SWV5_REASON_MOMENTUM_BODY_BELOW    = 2097152;
const ulong SWV5_REASON_RSI_BULLISH            = 4194304;
const ulong SWV5_REASON_RSI_BEARISH            = 8388608;
const ulong SWV5_REASON_MACD_BULLISH           = 16777216;
const ulong SWV5_REASON_MACD_BEARISH           = 33554432;
const ulong SWV5_REASON_STOCH_BULLISH          = 67108864;
const ulong SWV5_REASON_STOCH_BEARISH          = 134217728;
const ulong SWV5_REASON_CONFIRMATION_CONTEXT_REQUIRED = 268435456;
const ulong SWV5_REASON_LEGACY_SCORE_NOT_COMPARABLE = 536870912;
const ulong SWV5_REASON_SCORE_THRESHOLD_UNREACHABLE = 1073741824;
const ulong SWV5_REASON_HISTORY_TOKEN_UNAVAILABLE = 2147483648;

struct SWV5_SnapshotHeader
{
   int                schema_version;
   ulong              sequence;
   ulong              history_generation;
   SWV5_ExecutionMode execution_mode;
   ulong              data_quality_flags;
   string             symbol;
   ENUM_TIMEFRAMES    timeframe;
   datetime           closed_bar_time;
};

struct SWV5_MarketSnapshot
{
   SWV5_SnapshotHeader header;
   datetime            created_at;
   datetime            current_bar_time;
   datetime            latest_tick_time;
   MqlRates            current_bar;
   MqlRates            closed_bar;
   MqlRates            previous_closed_bar;
   long                tick_volume;
   long                real_volume;
   int                 spread;
   bool                has_rates;
   bool                has_volume;
   bool                has_spread;
   string              session_context;
   ulong               observed_history_generation;
   ulong               last_valid_history_generation;
   bool                history_token_valid;
   bool                snapshot_usable;
   ulong               previous_history_generation;
   SWV5_HistoryChangeState history_change_state;
   SWV5_HistoryReason  history_reason;
   bool                history_baseline_reset;
   string              history_change_reason;
   SWV5_StaleState     stale_state;
   string              stale_reason;
   bool                active_session_expected;
   bool                session_detection_available;
};

struct SWV5_IndicatorSnapshot
{
   SWV5_SnapshotHeader header;
   ENUM_TIMEFRAMES     trend_timeframe;
   ENUM_TIMEFRAMES     macro_timeframe;
   int                 trend_fast_period;
   int                 trend_slow_period;
   bool                use_closed;
   int                 trade_indicator_shift;
   int                 trend_shift;
   int                 macro_shift;
   double              ema_entry;
   double              rsi;
   double              atr;
   double              trend_fast;
   double              trend_slow;
   double              macro_fast;
   double              macro_slow;
   double              adx;
   double              macd_main;
   double              macd_signal;
   double              stoch_k;
   double              stoch_d;
   double              volume_ratio;
   double              legacy_buy_buffer;
   double              legacy_sell_buffer;
   bool                has_primary_indicators;
   bool                has_momentum_indicators;
   bool                has_rsi;
   bool                has_atr;
   bool                has_macd;
   bool                has_stoch;
   bool                has_trend_indicators;
   bool                has_macro_indicators;
   bool                has_legacy_buffers;
};

struct SWV5_EngineInput
{
   SWV5_MarketSnapshot    market;
   SWV5_IndicatorSnapshot indicators;
};

struct SWV5_ResultHeader
{
   SWV5_EngineKind   engine_kind;
   SWV5_EngineHealth health;
   bool              valid;
   double            score;
   double            confidence;
   ulong             reason_flags;
   ulong             snapshot_sequence;
   ulong             history_generation;
   string            reason_text;
   string            validation_error;
};

struct SWV5_MarketResult
{
   SWV5_ResultHeader header;
   bool              market_open_context_available;
};

struct SWV5_TrendResult
{
   SWV5_ResultHeader header;
   SWV5_Bias         bias;
   string            trend_state;
   bool              trend_up;
   bool              trend_down;
   int               macro_direction;
   string            macro_state;
   double            trend_fast_value;
   double            trend_slow_value;
   double            macro_fast_value;
   double            macro_slow_value;
   bool              use_closed;
   int               trend_shift;
   int               macro_shift;
};

struct SWV5_MomentumResult
{
   SWV5_ResultHeader header;
   SWV5_Bias         bias;
   string            momentum_state;
   double            strength;
   bool              ready;
   bool              use_closed;
   int               source_bar_shift;
   double            body_value;
   double            atr_value;
   double            body_atr_ratio;
   double            v4_body_threshold;
   double            v5_body_threshold;
   bool              v4_body_threshold_met;
   bool              v5_body_threshold_met;
   double            rsi_value;
   string            rsi_state;
   double            macd_main_value;
   double            macd_signal_value;
   double            macd_histogram_value;
   string            macd_state;
   double            stoch_k_value;
   double            stoch_d_value;
   string            stoch_state;
   int               raw_legacy_confirmation_points;
   bool              confirmation_context_ready;
};

struct SWV5_VolumeResult
{
   SWV5_ResultHeader header;
   double            volume_ratio;
};

struct SWV5_StructureResult
{
   SWV5_ResultHeader header;
   string            structure_state;
};

struct SWV5_PriceActionResult
{
   SWV5_ResultHeader header;
   string            state;
   SWV5_Bias         bias;
   double            strength;
};

struct SWV5_ContextResult
{
   SWV5_ResultHeader header;
   string            context_state;
};

struct SWV5_RiskResult
{
   SWV5_ResultHeader header;
   bool              risk_context_available;
};

struct SWV5_LegacyResult
{
   SWV5_ResultHeader header;
   SWV5_ScoreSemantics score_semantics;
   bool              score_comparable_to_execution_threshold;
   double            maximum_reachable_score;
   int               legacy_direction;
   double            buy_buffer;
   double            sell_buffer;
   bool              has_legacy_signal;
};

struct SWV5_PolicyResult
{
   SWV5_ResultHeader header;
   bool              allowed;
};

struct SWV5_DecisionResult
{
   SWV5_ResultHeader header;
   SWV5_DecisionAction action;
   int                 direction;
   string              state;
   SWV5_EngineKind     blocking_engine;
};

struct SWV5_ValidationResult
{
   bool              valid;
   SWV5_EngineHealth health;
   ulong             reason_flags;
   string            error_text;
};

void SWV5_InitHeader(SWV5_SnapshotHeader &header,
                     const ulong sequence,
                     const ulong history_generation,
                     const SWV5_ExecutionMode execution_mode,
                     const string symbol,
                     const ENUM_TIMEFRAMES timeframe,
                     const datetime closed_bar_time)
{
   ZeroMemory(header);
   header.schema_version = SWV5_SCHEMA_VERSION;
   header.sequence = sequence;
   header.history_generation = history_generation;
   header.execution_mode = execution_mode;
   header.data_quality_flags = SWV5_DQ_NONE;
   header.symbol = symbol;
   header.timeframe = timeframe;
   header.closed_bar_time = closed_bar_time;
}

void SWV5_InitMarketSnapshot(SWV5_MarketSnapshot &snapshot)
{
   ZeroMemory(snapshot);
   SWV5_InitHeader(snapshot.header, 0, 0, SWV5_EXECUTION_CLOSED_BAR, _Symbol, _Period, 0);
   snapshot.created_at = TimeCurrent();
   snapshot.session_context = "UNSPECIFIED";
   snapshot.observed_history_generation = 0;
   snapshot.last_valid_history_generation = 0;
   snapshot.history_token_valid = false;
   snapshot.snapshot_usable = false;
   snapshot.history_change_state = SWV5_HISTORY_BASELINE_RESET;
   snapshot.history_reason = SWV5_HISTORY_REASON_NONE;
   snapshot.history_baseline_reset = true;
   snapshot.history_change_reason = "BASELINE NOT SET";
   snapshot.stale_state = SWV5_STALE_NOT_CHECKED;
   snapshot.stale_reason = "NOT CHECKED";
}

void SWV5_InitIndicatorSnapshot(SWV5_IndicatorSnapshot &snapshot)
{
   ZeroMemory(snapshot);
   SWV5_InitHeader(snapshot.header, 0, 0, SWV5_EXECUTION_CLOSED_BAR, _Symbol, _Period, 0);
   snapshot.trend_timeframe = PERIOD_H1;
   snapshot.macro_timeframe = PERIOD_H4;
   snapshot.trend_fast_period = 0;
   snapshot.trend_slow_period = 0;
   snapshot.use_closed = true;
   snapshot.trade_indicator_shift = 1;
   snapshot.trend_shift = 1;
   snapshot.macro_shift = 1;
   snapshot.ema_entry = EMPTY_VALUE;
   snapshot.rsi = EMPTY_VALUE;
   snapshot.atr = EMPTY_VALUE;
   snapshot.trend_fast = EMPTY_VALUE;
   snapshot.trend_slow = EMPTY_VALUE;
   snapshot.macro_fast = EMPTY_VALUE;
   snapshot.macro_slow = EMPTY_VALUE;
   snapshot.adx = EMPTY_VALUE;
   snapshot.macd_main = EMPTY_VALUE;
   snapshot.macd_signal = EMPTY_VALUE;
   snapshot.stoch_k = EMPTY_VALUE;
   snapshot.stoch_d = EMPTY_VALUE;
   snapshot.volume_ratio = EMPTY_VALUE;
   snapshot.legacy_buy_buffer = EMPTY_VALUE;
   snapshot.legacy_sell_buffer = EMPTY_VALUE;
}

void SWV5_InitResultHeader(SWV5_ResultHeader &header,
                           const SWV5_EngineKind kind,
                           const ulong sequence,
                           const ulong history_generation)
{
   ZeroMemory(header);
   header.engine_kind = kind;
   header.health = SWV5_HEALTH_UNAVAILABLE;
   header.valid = false;
   header.score = 0.0;
   header.confidence = 0.0;
   header.reason_flags = SWV5_REASON_NONE;
   header.snapshot_sequence = sequence;
   header.history_generation = history_generation;
   header.reason_text = "";
   header.validation_error = "";
}

void SWV5_InitPriceActionResult(SWV5_PriceActionResult &result, const SWV5_EngineInput &engineInput)
{
   ZeroMemory(result);
   SWV5_InitResultHeader(result.header, SWV5_ENGINE_PRICE_ACTION, engineInput.market.header.sequence, engineInput.market.header.history_generation);
   result.state = "UNAVAILABLE";
   result.bias = SWV5_BIAS_NEUTRAL;
   result.strength = 0.0;
}

void SWV5_InitTrendResult(SWV5_TrendResult &result, const SWV5_EngineInput &engineInput)
{
   ZeroMemory(result);
   SWV5_InitResultHeader(result.header, SWV5_ENGINE_TREND, engineInput.market.header.sequence, engineInput.market.header.history_generation);
   result.bias = SWV5_BIAS_NEUTRAL;
   result.trend_state = "UNAVAILABLE";
   result.trend_up = false;
   result.trend_down = false;
   result.macro_direction = 0;
   result.macro_state = "MACRO_NOT_READY";
   result.trend_fast_value = EMPTY_VALUE;
   result.trend_slow_value = EMPTY_VALUE;
   result.macro_fast_value = EMPTY_VALUE;
   result.macro_slow_value = EMPTY_VALUE;
   result.use_closed = true;
   result.trend_shift = 1;
   result.macro_shift = 1;
}

void SWV5_InitMomentumResult(SWV5_MomentumResult &result, const SWV5_EngineInput &engineInput)
{
   ZeroMemory(result);
   SWV5_InitResultHeader(result.header, SWV5_ENGINE_MOMENTUM, engineInput.market.header.sequence, engineInput.market.header.history_generation);
   result.bias = SWV5_BIAS_NEUTRAL;
   result.momentum_state = "NOT_READY";
   result.strength = 0.0;
   result.ready = false;
   result.use_closed = engineInput.indicators.use_closed;
   result.source_bar_shift = engineInput.indicators.trade_indicator_shift;
   result.body_value = EMPTY_VALUE;
   result.atr_value = EMPTY_VALUE;
   result.body_atr_ratio = EMPTY_VALUE;
   result.v4_body_threshold = EMPTY_VALUE;
   result.v5_body_threshold = EMPTY_VALUE;
   result.v4_body_threshold_met = false;
   result.v5_body_threshold_met = false;
   result.rsi_value = EMPTY_VALUE;
   result.rsi_state = "NOT_READY";
   result.macd_main_value = EMPTY_VALUE;
   result.macd_signal_value = EMPTY_VALUE;
   result.macd_histogram_value = EMPTY_VALUE;
   result.macd_state = "NOT_READY";
   result.stoch_k_value = EMPTY_VALUE;
   result.stoch_d_value = EMPTY_VALUE;
   result.stoch_state = "NOT_READY";
   result.raw_legacy_confirmation_points = 0;
   result.confirmation_context_ready = false;
}

void SWV5_InitLegacyResult(SWV5_LegacyResult &result, const SWV5_EngineInput &engineInput)
{
   ZeroMemory(result);
   SWV5_InitResultHeader(result.header, SWV5_ENGINE_LEGACY, engineInput.market.header.sequence, engineInput.market.header.history_generation);
   result.score_semantics = SWV5_SCORE_NONE;
   result.score_comparable_to_execution_threshold = false;
   result.maximum_reachable_score = 0.0;
   result.legacy_direction = 0;
   result.buy_buffer = EMPTY_VALUE;
   result.sell_buffer = EMPTY_VALUE;
   result.has_legacy_signal = false;
}

void SWV5_InitPolicyResult(SWV5_PolicyResult &result, const SWV5_EngineInput &engineInput)
{
   ZeroMemory(result);
   SWV5_InitResultHeader(result.header, SWV5_ENGINE_CONTEXT, engineInput.market.header.sequence, engineInput.market.header.history_generation);
   result.header.health = SWV5_HEALTH_HEALTHY;
   result.header.valid = true;
   result.header.score = 100.0;
   result.header.confidence = 1.0;
   result.allowed = true;
}

void SWV5_InitDecisionResult(SWV5_DecisionResult &result, const SWV5_EngineInput &engineInput)
{
   ZeroMemory(result);
   SWV5_InitResultHeader(result.header, SWV5_ENGINE_DECISION, engineInput.market.header.sequence, engineInput.market.header.history_generation);
   result.header.health = SWV5_HEALTH_HEALTHY;
   result.header.valid = false;
   result.direction = 0;
   result.state = "WAIT";
   result.blocking_engine = SWV5_ENGINE_DECISION;
}

bool SWV5_IsFinite(const double value)
{
   return MathIsValidNumber(value);
}

string SWV5_ActionText(const SWV5_DecisionAction action)
{
   if(action == SWV5_ACTION_BUY) return "BUY";
   if(action == SWV5_ACTION_SELL) return "SELL";
   if(action == SWV5_ACTION_BLOCKED) return "BLOCKED";
   return "WAIT";
}

string SWV5_HealthText(const SWV5_EngineHealth health)
{
   if(health == SWV5_HEALTH_HEALTHY) return "HEALTHY";
   if(health == SWV5_HEALTH_DEGRADED) return "DEGRADED";
   if(health == SWV5_HEALTH_UNAVAILABLE) return "UNAVAILABLE";
   if(health == SWV5_HEALTH_INVALID) return "INVALID";
   return "UNKNOWN";
}

string SWV5_BiasText(const SWV5_Bias bias)
{
   if(bias == SWV5_BIAS_BULLISH) return "BUY";
   if(bias == SWV5_BIAS_BEARISH) return "SELL";
   return "WAIT";
}

string SWV5_ExecutionModeText(const SWV5_ExecutionMode mode)
{
   if(mode == SWV5_EXECUTION_CLOSED_BAR) return "CLOSED BAR";
   if(mode == SWV5_EXECUTION_EVERY_TICK) return "EVERY TICK";
   if(mode == SWV5_EXECUTION_REPLAY) return "REPLAY";
   return "UNKNOWN";
}

string SWV5_ScoreSemanticsText(const SWV5_ScoreSemantics semantics)
{
   if(semantics == SWV5_SCORE_LEGACY_FIXED) return "LEGACY FIXED";
   if(semantics == SWV5_SCORE_V42_COMPOSITE) return "V4.2 COMPOSITE";
   if(semantics == SWV5_SCORE_NORMALIZED_ENGINE) return "NORMALIZED";
   if(semantics == SWV5_SCORE_NOT_COMPARABLE) return "NOT COMPARABLE";
   return "NONE";
}

string SWV5_HistoryChangeText(const SWV5_HistoryChangeState state)
{
   if(state == SWV5_HISTORY_NORMAL) return "NORMAL";
   if(state == SWV5_HISTORY_SHRINK) return "SHRINK";
   if(state == SWV5_HISTORY_RESET) return "RESET";
   if(state == SWV5_HISTORY_ABNORMAL_JUMP) return "ABNORMAL JUMP";
   if(state == SWV5_HISTORY_TOKEN_UNAVAILABLE) return "TOKEN UNAVAILABLE";
   return "BASELINE RESET";
}

string SWV5_HistoryReasonText(const SWV5_HistoryReason reason)
{
   if(reason == SWV5_HISTORY_REASON_BASELINE_INITIALIZED) return "BASELINE_INITIALIZED";
   if(reason == SWV5_HISTORY_REASON_NORMAL_INCREMENT) return "NORMAL_INCREMENT";
   if(reason == SWV5_HISTORY_REASON_CONTEXT_RESET) return "CONTEXT_RESET";
   if(reason == SWV5_HISTORY_REASON_TOKEN_UNAVAILABLE) return "TOKEN_UNAVAILABLE";
   if(reason == SWV5_HISTORY_REASON_HISTORY_SHRINK) return "HISTORY_SHRINK";
   if(reason == SWV5_HISTORY_REASON_HISTORY_RESET) return "HISTORY_RESET";
   if(reason == SWV5_HISTORY_REASON_ABNORMAL_JUMP) return "ABNORMAL_JUMP";
   if(reason == SWV5_HISTORY_REASON_NORMAL_UNCHANGED) return "NORMAL_UNCHANGED";
   if(reason == SWV5_HISTORY_REASON_TOKEN_RECOVERED) return "TOKEN_RECOVERED";
   return "NONE";
}

string SWV5_StaleStateText(const SWV5_StaleState state)
{
   if(state == SWV5_STALE_FRESH) return "FRESH";
   if(state == SWV5_STALE_MARKET_CLOSED) return "MARKET CLOSED";
   if(state == SWV5_STALE_CLOSED_BAR_OLD) return "CLOSED BAR OLD";
   if(state == SWV5_STALE_TICK_FROZEN) return "TICK FROZEN";
   if(state == SWV5_STALE_REPLAY_DISABLED) return "REPLAY DISABLED";
   return "NOT CHECKED";
}

void SWV5_InitValidationResult(SWV5_ValidationResult &result)
{
   ZeroMemory(result);
   result.valid = true;
   result.health = SWV5_HEALTH_HEALTHY;
   result.reason_flags = SWV5_REASON_NONE;
   result.error_text = "";
}

#endif
