#ifndef SW_V5_PLATFORM_ADAPTER_MQH
#define SW_V5_PLATFORM_ADAPTER_MQH

#include "..\\Core\\SW_V5_Types.mqh"

class CMT5PlatformAdapter
{
private:
   ulong               m_lastValidHistoryGeneration;
   datetime            m_lastValidClosedBarTime;
   string              m_baselineSymbol;
   ENUM_TIMEFRAMES     m_baselineTimeframe;
   SWV5_ExecutionMode  m_baselineMode;
   bool                m_hasHistoryBaseline;
   bool                m_historyTokenUnavailable;
   bool                m_contextResetPending;
   int                 m_staleToleranceSeconds;

   bool SessionExpected(const string symbol,
                        const datetime serverTime,
                        bool &sessionInfoAvailable)
   {
      sessionInfoAvailable = false;
      MqlDateTime parts;
      if(!TimeToStruct(serverTime, parts))
         return false;

      ENUM_DAY_OF_WEEK day = (ENUM_DAY_OF_WEEK)parts.day_of_week;
      int nowSeconds = parts.hour * 3600 + parts.min * 60 + parts.sec;
      datetime sessionFrom = 0;
      datetime sessionTo = 0;
      for(uint index = 0; index < 32; index++)
      {
         if(!SymbolInfoSessionTrade(symbol, day, index, sessionFrom, sessionTo))
            break;
         sessionInfoAvailable = true;
         MqlDateTime fromParts;
         MqlDateTime toParts;
         TimeToStruct(sessionFrom, fromParts);
         TimeToStruct(sessionTo, toParts);
         int fromSeconds = fromParts.hour * 3600 + fromParts.min * 60 + fromParts.sec;
         int toSeconds = toParts.hour * 3600 + toParts.min * 60 + toParts.sec;
         if(fromSeconds <= toSeconds)
         {
            if(nowSeconds >= fromSeconds && nowSeconds <= toSeconds)
               return true;
         }
         else if(nowSeconds >= fromSeconds || nowSeconds <= toSeconds)
            return true;
      }
      return false;
   }

   ulong ExpectedHistoryAdvance(const SWV5_MarketSnapshot &snapshot)
   {
      int periodSeconds = PeriodSeconds(snapshot.header.timeframe);
      if(periodSeconds <= 0 || m_lastValidClosedBarTime <= 0 ||
         snapshot.header.closed_bar_time <= m_lastValidClosedBarTime)
         return 0;
      return (ulong)((snapshot.header.closed_bar_time - m_lastValidClosedBarTime) / periodSeconds);
   }

   void SetHistoryFailure(SWV5_MarketSnapshot &snapshot,
                          const SWV5_HistoryChangeState state,
                          const SWV5_HistoryReason reason)
   {
      snapshot.history_change_state = state;
      snapshot.history_reason = reason;
      snapshot.history_change_reason = SWV5_HistoryReasonText(reason);
      snapshot.header.data_quality_flags |= SWV5_DQ_HISTORY_CHANGED;
   }

   void ApplyHistoryContinuity(SWV5_MarketSnapshot &snapshot)
   {
      ulong current = snapshot.observed_history_generation;
      bool hasKnownContext = (m_baselineSymbol != "");
      bool contextChanged = (hasKnownContext &&
                             (snapshot.header.symbol != m_baselineSymbol ||
                              snapshot.header.timeframe != m_baselineTimeframe ||
                              snapshot.header.execution_mode != m_baselineMode));

      if(contextChanged)
      {
         m_hasHistoryBaseline = false;
         m_lastValidHistoryGeneration = 0;
         m_lastValidClosedBarTime = 0;
         m_historyTokenUnavailable = false;
         m_contextResetPending = true;
      }

      m_baselineSymbol = snapshot.header.symbol;
      m_baselineTimeframe = snapshot.header.timeframe;
      m_baselineMode = snapshot.header.execution_mode;
      snapshot.last_valid_history_generation = (m_hasHistoryBaseline ? m_lastValidHistoryGeneration : 0);
      snapshot.previous_history_generation = snapshot.last_valid_history_generation;
      snapshot.history_baseline_reset = (!m_hasHistoryBaseline || contextChanged);

      if(!snapshot.history_token_valid)
      {
         snapshot.history_change_state = SWV5_HISTORY_TOKEN_UNAVAILABLE;
         snapshot.history_reason = SWV5_HISTORY_REASON_TOKEN_UNAVAILABLE;
         snapshot.history_change_reason = SWV5_HistoryReasonText(snapshot.history_reason);
         snapshot.header.data_quality_flags |= (SWV5_DQ_HISTORY_CHANGED | SWV5_DQ_HISTORY_TOKEN_UNAVAILABLE);
         m_historyTokenUnavailable = true;
         return;
      }

      if(!m_hasHistoryBaseline)
      {
         snapshot.history_change_state = SWV5_HISTORY_BASELINE_RESET;
         snapshot.history_reason = (m_contextResetPending ? SWV5_HISTORY_REASON_CONTEXT_RESET :
                                                            SWV5_HISTORY_REASON_BASELINE_INITIALIZED);
         snapshot.history_change_reason = SWV5_HistoryReasonText(snapshot.history_reason);
      }
      else if(current < m_lastValidHistoryGeneration)
      {
         bool reset = (current * 2 < m_lastValidHistoryGeneration);
         SetHistoryFailure(snapshot,
                           (reset ? SWV5_HISTORY_RESET : SWV5_HISTORY_SHRINK),
                           (reset ? SWV5_HISTORY_REASON_HISTORY_RESET : SWV5_HISTORY_REASON_HISTORY_SHRINK));
      }
      else if(m_historyTokenUnavailable)
      {
         ulong advance = current - m_lastValidHistoryGeneration;
         ulong expectedAdvance = ExpectedHistoryAdvance(snapshot);
         if(advance <= expectedAdvance)
         {
            snapshot.history_change_state = SWV5_HISTORY_NORMAL;
            snapshot.history_reason = SWV5_HISTORY_REASON_TOKEN_RECOVERED;
            snapshot.history_change_reason = SWV5_HistoryReasonText(snapshot.history_reason);
         }
         else
            SetHistoryFailure(snapshot, SWV5_HISTORY_ABNORMAL_JUMP, SWV5_HISTORY_REASON_ABNORMAL_JUMP);
      }
      else if(current == m_lastValidHistoryGeneration)
      {
         snapshot.history_change_state = SWV5_HISTORY_NORMAL;
         snapshot.history_reason = SWV5_HISTORY_REASON_NORMAL_UNCHANGED;
         snapshot.history_change_reason = SWV5_HistoryReasonText(snapshot.history_reason);
      }
      else if(current == m_lastValidHistoryGeneration + 1)
      {
         snapshot.history_change_state = SWV5_HISTORY_NORMAL;
         snapshot.history_reason = SWV5_HISTORY_REASON_NORMAL_INCREMENT;
         snapshot.history_change_reason = SWV5_HistoryReasonText(snapshot.history_reason);
      }
      else
         SetHistoryFailure(snapshot, SWV5_HISTORY_ABNORMAL_JUMP, SWV5_HISTORY_REASON_ABNORMAL_JUMP);

      m_lastValidHistoryGeneration = current;
      m_lastValidClosedBarTime = snapshot.header.closed_bar_time;
      m_hasHistoryBaseline = true;
      m_historyTokenUnavailable = false;
      m_contextResetPending = false;
   }

   void ApplyStalePolicy(SWV5_MarketSnapshot &snapshot)
   {
      if(snapshot.header.execution_mode == SWV5_EXECUTION_REPLAY)
      {
         snapshot.stale_state = SWV5_STALE_REPLAY_DISABLED;
         snapshot.stale_reason = "Wall-clock stale check disabled in replay";
         return;
      }

      bool sessionAvailable = false;
      bool sessionExpected = SessionExpected(snapshot.header.symbol, snapshot.created_at, sessionAvailable);
      snapshot.session_detection_available = sessionAvailable;
      snapshot.active_session_expected = sessionExpected;
      if(!sessionAvailable || !sessionExpected)
      {
         snapshot.stale_state = SWV5_STALE_MARKET_CLOSED;
         snapshot.stale_reason = (sessionAvailable ? "Trading session is closed" : "Trading session unavailable; stale check suppressed");
         return;
      }

      int periodSeconds = PeriodSeconds(snapshot.header.timeframe);
      if(periodSeconds <= 0)
         periodSeconds = 60;

      if(snapshot.header.execution_mode == SWV5_EXECUTION_CLOSED_BAR)
      {
         long currentBarAge = (long)(snapshot.created_at - snapshot.current_bar_time);
         long closedBarAge = (long)(snapshot.created_at - snapshot.header.closed_bar_time);
         bool currentBarFresh = (currentBarAge >= 0 && currentBarAge <= periodSeconds + m_staleToleranceSeconds);
         bool closedBarFresh = (closedBarAge >= 0 && closedBarAge <= (periodSeconds * 2) + m_staleToleranceSeconds);
         if(currentBarFresh || closedBarFresh)
         {
            snapshot.stale_state = SWV5_STALE_FRESH;
            snapshot.stale_reason = "Closed-bar data age is within tolerance";
            return;
         }
         snapshot.stale_state = SWV5_STALE_CLOSED_BAR_OLD;
         snapshot.stale_reason = "Latest closed bar is unexpectedly old during active session";
      }
      else
      {
         long tickAge = (long)(snapshot.created_at - snapshot.latest_tick_time);
         if(snapshot.latest_tick_time > 0 && tickAge >= 0 && tickAge <= m_staleToleranceSeconds)
         {
            snapshot.stale_state = SWV5_STALE_FRESH;
            snapshot.stale_reason = "Latest tick is within tolerance";
            return;
         }
         snapshot.stale_state = SWV5_STALE_TICK_FROZEN;
         snapshot.stale_reason = "Latest tick is unexpectedly old during active session";
      }
      snapshot.header.data_quality_flags |= SWV5_DQ_STALE_DATA;
   }

public:
   CMT5PlatformAdapter()
   {
      m_lastValidHistoryGeneration = 0;
      m_lastValidClosedBarTime = 0;
      m_baselineSymbol = "";
      m_baselineTimeframe = PERIOD_CURRENT;
      m_baselineMode = SWV5_EXECUTION_CLOSED_BAR;
      m_hasHistoryBaseline = false;
      m_historyTokenUnavailable = false;
      m_contextResetPending = false;
      m_staleToleranceSeconds = 180;
   }

   bool Configure(const int staleToleranceSeconds)
   {
      if(staleToleranceSeconds < 1 || staleToleranceSeconds > 86400)
         return false;
      m_staleToleranceSeconds = staleToleranceSeconds;
      return true;
   }

   void ResetHistoryBaseline()
   {
      m_hasHistoryBaseline = false;
      m_lastValidHistoryGeneration = 0;
      m_lastValidClosedBarTime = 0;
      m_baselineSymbol = "";
      m_baselineTimeframe = PERIOD_CURRENT;
      m_historyTokenUnavailable = false;
      m_contextResetPending = false;
   }

   bool BuildMarketSnapshot(const string symbol,
                            const ENUM_TIMEFRAMES timeframe,
                            const SWV5_ExecutionMode executionMode,
                            const ulong sequence,
                            SWV5_MarketSnapshot &snapshot)
   {
      SWV5_InitMarketSnapshot(snapshot);
      long observedBars = Bars(symbol, timeframe);
      ulong observedHistoryGeneration = (observedBars > 0 ? (ulong)observedBars : 0);

      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int got = CopyRates(symbol, timeframe, 0, 3, rates);
      if(got != 3)
      {
         SWV5_InitHeader(snapshot.header, sequence, observedHistoryGeneration, executionMode, symbol, timeframe, 0);
         snapshot.observed_history_generation = observedHistoryGeneration;
         snapshot.history_token_valid = (observedBars > 0);
         if(!snapshot.history_token_valid)
            ApplyHistoryContinuity(snapshot);
         else
         {
            snapshot.last_valid_history_generation = (m_hasHistoryBaseline ? m_lastValidHistoryGeneration : 0);
            snapshot.previous_history_generation = snapshot.last_valid_history_generation;
         }
         snapshot.header.data_quality_flags |= SWV5_DQ_MISSING_DATA;
         return false;
      }

      SWV5_InitHeader(snapshot.header, sequence, observedHistoryGeneration, executionMode, symbol, timeframe, rates[1].time);
      snapshot.observed_history_generation = observedHistoryGeneration;
      snapshot.history_token_valid = (observedBars > 0);
      snapshot.created_at = TimeCurrent();
      snapshot.current_bar = rates[0];
      snapshot.closed_bar = rates[1];
      snapshot.previous_closed_bar = rates[2];
      snapshot.current_bar_time = rates[0].time;
      MqlTick latestTick;
      if(SymbolInfoTick(symbol, latestTick))
         snapshot.latest_tick_time = latestTick.time;
      snapshot.has_rates = true;
      snapshot.tick_volume = rates[1].tick_volume;
      snapshot.real_volume = rates[1].real_volume;
      snapshot.spread = (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      snapshot.has_volume = true;
      snapshot.has_spread = (snapshot.spread >= 0);
      snapshot.session_context = "SERVER_TIME_" + TimeToString(snapshot.created_at, TIME_DATE | TIME_SECONDS);

      if(snapshot.header.closed_bar_time <= 0)
      {
         snapshot.header.data_quality_flags |= SWV5_DQ_SNAPSHOT_MISMATCH;
         return false;
      }
      ApplyHistoryContinuity(snapshot);
      ApplyStalePolicy(snapshot);
      ulong unusableFlags = (SWV5_DQ_MISSING_DATA | SWV5_DQ_HISTORY_CHANGED | SWV5_DQ_STALE_DATA |
                             SWV5_DQ_SNAPSHOT_MISMATCH | SWV5_DQ_INVALID_VALUE |
                             SWV5_DQ_HISTORY_TOKEN_UNAVAILABLE);
      snapshot.snapshot_usable = (snapshot.history_token_valid &&
                                  (snapshot.header.data_quality_flags & unusableFlags) == 0);
      return true;
   }
};

#endif
