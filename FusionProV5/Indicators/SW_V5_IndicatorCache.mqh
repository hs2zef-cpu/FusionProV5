#ifndef SW_V5_INDICATOR_CACHE_MQH
#define SW_V5_INDICATOR_CACHE_MQH

#include "..\\Core\\SW_V5_Types.mqh"

class CIndicatorCache
{
private:
   int m_emaEntry;
   int m_rsi;
   int m_atr;
   int m_trendFast;
   int m_trendSlow;
   int m_macroFast;
   int m_macroSlow;
   int m_adx;
   int m_macd;
   int m_stoch;
   int m_legacyFibo;
   ENUM_TIMEFRAMES m_trendTf;
   ENUM_TIMEFRAMES m_macroTf;
   int m_trendFastPeriod;
   int m_trendSlowPeriod;
   bool m_useMacd;
   bool m_useStoch;
   string m_initializationError;

   void AddMissingHandle(const string name)
   {
      if(m_initializationError != "") m_initializationError += ", ";
      m_initializationError += name;
   }

   bool ReadBuffer(const int handle, const int buffer, const int shift, double &value, ulong &flags)
   {
      value = EMPTY_VALUE;
      if(handle == INVALID_HANDLE)
      {
         flags |= SWV5_DQ_MISSING_DATA | SWV5_DQ_COPYBUFFER_FAILURE;
         return false;
      }

      double data[];
      ArraySetAsSeries(data, true);
      if(CopyBuffer(handle, buffer, shift, 1, data) != 1)
      {
         flags |= SWV5_DQ_COPYBUFFER_FAILURE;
         return false;
      }

      value = data[0];
      if(!SWV5_IsFinite(value) && value != EMPTY_VALUE)
      {
         flags |= SWV5_DQ_INVALID_VALUE;
         return false;
      }
      return true;
   }

public:
   CIndicatorCache()
   {
      m_emaEntry = INVALID_HANDLE;
      m_rsi = INVALID_HANDLE;
      m_atr = INVALID_HANDLE;
      m_trendFast = INVALID_HANDLE;
      m_trendSlow = INVALID_HANDLE;
      m_macroFast = INVALID_HANDLE;
      m_macroSlow = INVALID_HANDLE;
      m_adx = INVALID_HANDLE;
      m_macd = INVALID_HANDLE;
      m_stoch = INVALID_HANDLE;
      m_legacyFibo = INVALID_HANDLE;
      m_trendTf = PERIOD_H1;
      m_macroTf = PERIOD_H4;
      m_trendFastPeriod = 0;
      m_trendSlowPeriod = 0;
      m_useMacd = true;
      m_useStoch = true;
      m_initializationError = "";
   }

   bool Init(const string symbol,
             const ENUM_TIMEFRAMES tradeTf,
             const ENUM_TIMEFRAMES trendTf,
             const ENUM_TIMEFRAMES macroTf,
             const int entryEma,
             const int rsiPeriod,
             const int atrPeriod,
             const int trendFast,
             const int trendSlow,
             const int adxPeriod,
             const int macdFast,
             const int macdSlow,
             const int macdSignal,
             const int stochK,
             const int stochD,
             const int stochSlowing)
   {
      m_trendTf = trendTf;
      m_macroTf = macroTf;
      m_trendFastPeriod = trendFast;
      m_trendSlowPeriod = trendSlow;
      m_emaEntry = iMA(symbol, tradeTf, entryEma, 0, MODE_EMA, PRICE_CLOSE);
      m_rsi = iRSI(symbol, tradeTf, rsiPeriod, PRICE_CLOSE);
      m_atr = iATR(symbol, tradeTf, atrPeriod);
      m_trendFast = iMA(symbol, trendTf, trendFast, 0, MODE_EMA, PRICE_CLOSE);
      m_trendSlow = iMA(symbol, trendTf, trendSlow, 0, MODE_EMA, PRICE_CLOSE);
      m_macroFast = iMA(symbol, macroTf, trendFast, 0, MODE_EMA, PRICE_CLOSE);
      m_macroSlow = iMA(symbol, macroTf, trendSlow, 0, MODE_EMA, PRICE_CLOSE);
      m_adx = iADX(symbol, tradeTf, adxPeriod);
      m_macd = iMACD(symbol, tradeTf, macdFast, macdSlow, macdSignal, PRICE_CLOSE);
      m_stoch = iStochastic(symbol, tradeTf, stochK, stochD, stochSlowing, MODE_SMA, STO_LOWHIGH);

      m_initializationError = "";
      if(m_emaEntry == INVALID_HANDLE) AddMissingHandle("EMA entry");
      if(m_rsi == INVALID_HANDLE) AddMissingHandle("RSI");
      if(m_atr == INVALID_HANDLE) AddMissingHandle("ATR");
      if(m_trendFast == INVALID_HANDLE) AddMissingHandle("Trend EMA fast");
      if(m_trendSlow == INVALID_HANDLE) AddMissingHandle("Trend EMA slow");
      if(m_macroFast == INVALID_HANDLE) AddMissingHandle("Macro EMA fast");
      if(m_macroSlow == INVALID_HANDLE) AddMissingHandle("Macro EMA slow");
      if(m_adx == INVALID_HANDLE) AddMissingHandle("ADX");
      if(m_macd == INVALID_HANDLE) AddMissingHandle("MACD");
      if(m_stoch == INVALID_HANDLE) AddMissingHandle("Stochastic");

      return (m_emaEntry != INVALID_HANDLE && m_rsi != INVALID_HANDLE && m_atr != INVALID_HANDLE &&
              m_trendFast != INVALID_HANDLE && m_trendSlow != INVALID_HANDLE &&
              m_macroFast != INVALID_HANDLE && m_macroSlow != INVALID_HANDLE &&
              m_adx != INVALID_HANDLE && m_macd != INVALID_HANDLE && m_stoch != INVALID_HANDLE);
   }

   bool InitLegacyFibo(const string symbol, const ENUM_TIMEFRAMES tf)
   {
      m_legacyFibo = iCustom(symbol, tf, "SW_FIBO_BASIC_V3");
      if(m_legacyFibo == INVALID_HANDLE)
         AddMissingHandle("SW_FIBO_BASIC_V3");
      return (m_legacyFibo != INVALID_HANDLE);
   }

   string InitializationDiagnostic()
   {
      return m_initializationError;
   }

   void ConfigureMomentumReads(const bool useMacd, const bool useStoch)
   {
      m_useMacd = useMacd;
      m_useStoch = useStoch;
   }

   void Release()
   {
      if(m_emaEntry != INVALID_HANDLE) IndicatorRelease(m_emaEntry);
      if(m_rsi != INVALID_HANDLE) IndicatorRelease(m_rsi);
      if(m_atr != INVALID_HANDLE) IndicatorRelease(m_atr);
      if(m_trendFast != INVALID_HANDLE) IndicatorRelease(m_trendFast);
      if(m_trendSlow != INVALID_HANDLE) IndicatorRelease(m_trendSlow);
      if(m_macroFast != INVALID_HANDLE) IndicatorRelease(m_macroFast);
      if(m_macroSlow != INVALID_HANDLE) IndicatorRelease(m_macroSlow);
      if(m_adx != INVALID_HANDLE) IndicatorRelease(m_adx);
      if(m_macd != INVALID_HANDLE) IndicatorRelease(m_macd);
      if(m_stoch != INVALID_HANDLE) IndicatorRelease(m_stoch);
      if(m_legacyFibo != INVALID_HANDLE) IndicatorRelease(m_legacyFibo);
   }

   bool BuildIndicatorSnapshot(const SWV5_MarketSnapshot &market, const int shift, SWV5_IndicatorSnapshot &snapshot)
   {
      SWV5_InitIndicatorSnapshot(snapshot);
      snapshot.header = market.header;
      snapshot.trend_timeframe = m_trendTf;
      snapshot.macro_timeframe = m_macroTf;
      snapshot.trend_fast_period = m_trendFastPeriod;
      snapshot.trend_slow_period = m_trendSlowPeriod;
      snapshot.use_closed = (market.header.execution_mode != SWV5_EXECUTION_EVERY_TICK);
      snapshot.trade_indicator_shift = shift;
      snapshot.trend_shift = 1;
      snapshot.macro_shift = (snapshot.use_closed ? 1 : 0);

      ulong flags = SWV5_DQ_NONE;
      bool emaOk = ReadBuffer(m_emaEntry, 0, shift, snapshot.ema_entry, flags);
      bool rsiOk = ReadBuffer(m_rsi, 0, shift, snapshot.rsi, flags);
      bool atrOk = ReadBuffer(m_atr, 0, shift, snapshot.atr, flags);
      bool trendOk = ReadBuffer(m_trendFast, 0, snapshot.trend_shift, snapshot.trend_fast, flags);
      trendOk = ReadBuffer(m_trendSlow, 0, snapshot.trend_shift, snapshot.trend_slow, flags) && trendOk;
      bool macroOk = ReadBuffer(m_macroFast, 0, snapshot.macro_shift, snapshot.macro_fast, flags);
      macroOk = ReadBuffer(m_macroSlow, 0, snapshot.macro_shift, snapshot.macro_slow, flags) && macroOk;
      bool adxOk = ReadBuffer(m_adx, 0, shift, snapshot.adx, flags);
      bool macdOk = true;
      if(m_useMacd)
      {
         macdOk = ReadBuffer(m_macd, 0, shift, snapshot.macd_main, flags);
         macdOk = ReadBuffer(m_macd, 1, shift, snapshot.macd_signal, flags) && macdOk;
      }
      bool stochOk = true;
      if(m_useStoch)
      {
         stochOk = ReadBuffer(m_stoch, 0, shift, snapshot.stoch_k, flags);
         stochOk = ReadBuffer(m_stoch, 1, shift, snapshot.stoch_d, flags) && stochOk;
      }
      bool primaryOk = (emaOk && rsiOk && atrOk && trendOk && macroOk && adxOk && macdOk && stochOk);
      snapshot.has_primary_indicators = primaryOk;
      snapshot.has_momentum_indicators = (rsiOk && atrOk && macdOk && stochOk);
      snapshot.has_rsi = rsiOk;
      snapshot.has_atr = atrOk;
      snapshot.has_macd = (m_useMacd && macdOk);
      snapshot.has_stoch = (m_useStoch && stochOk);
      snapshot.has_trend_indicators = trendOk;
      snapshot.has_macro_indicators = macroOk;

      ulong legacyFlags = SWV5_DQ_NONE;
      bool buyOk = ReadBuffer(m_legacyFibo, 0, shift, snapshot.legacy_buy_buffer, legacyFlags);
      bool sellOk = ReadBuffer(m_legacyFibo, 1, shift, snapshot.legacy_sell_buffer, legacyFlags);
      snapshot.has_legacy_buffers = (buyOk || sellOk);

      snapshot.header.data_quality_flags |= flags;
      if(!primaryOk)
         snapshot.header.data_quality_flags |= SWV5_DQ_PARTIAL_DATA;
      if(legacyFlags != SWV5_DQ_NONE)
         snapshot.header.data_quality_flags |= SWV5_DQ_PARTIAL_DATA;

      return primaryOk;
   }
};

#endif
