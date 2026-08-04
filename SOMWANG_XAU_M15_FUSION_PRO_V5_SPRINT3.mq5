//+------------------------------------------------------------------+
//| SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT3.mq5                       |
//| Sprint 3 momentum migration and regression harness.              |
//| Original V4/V4.2 sources are preserved and not modified.          |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_plots 0
#property version "5.30"

#include "FusionProV5\\Orchestration\\SW_V5_Orchestrator.mqh"
#include "FusionProV5\\Dashboard\\SW_V5_ReadOnlyDashboard.mqh"

input ENUM_TIMEFRAMES InpTradeTF = PERIOD_M15;
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_H1;
input ENUM_TIMEFRAMES InpMacroTF = PERIOD_H4;

input int InpMinScoreToSignal = 85;
input int InpCooldownBarsV5 = 8;

input int InpEntryEMA = 21;
input int InpRSIPeriod = 14;
input int InpATRPeriod = 14;
input int InpTrendEMA_Fast = 50;
input int InpTrendEMA_Slow = 200;
input int InpADXPeriod = 14;
input int InpMACDFast = 12;
input int InpMACDSlow = 26;
input int InpMACDSignal = 9;
input int InpStochK = 5;
input int InpStochD = 3;
input int InpStochSlowing = 3;

input double InpV4MomentumBodyATR = 0.32;
input double InpV5MomentumBodyATR = 0.36;
input bool InpUseRSI50Filter = true;
input bool InpUseMACDFilter = true;
input bool InpUseStochFilter = true;
input double InpStochOB = 80.0;
input double InpStochOS = 20.0;

input bool InpClosedBarOnly = true;
input bool InpShowDashboard = true;
input bool InpLogTrendRegression = false;
input bool InpLogMomentumRegression = false;
input ENUM_BASE_CORNER InpPanelCorner = CORNER_LEFT_UPPER;
input int  InpPanelX = 14;
input int  InpPanelY = 90;
input int  InpPanelWidth = 344;
input int  InpPanelHeight = 536;
input int  InpPanelFontSize = 9;
input int  InpPanelRowGap = 20;

CCentralOrchestrator g_orchestrator;
CReadOnlyDashboard   g_dashboard;

int OnInit()
{
   if(InpTrendEMA_Fast < 1 || InpTrendEMA_Slow <= InpTrendEMA_Fast ||
      InpEntryEMA < 1 || InpRSIPeriod < 2 || InpATRPeriod < 2 ||
      InpADXPeriod < 2 || InpMACDFast < 1 || InpMACDSlow <= InpMACDFast ||
      InpMACDSignal < 1 || InpStochK < 1 || InpStochD < 1 ||
      InpStochSlowing < 1 || InpV4MomentumBodyATR <= 0.0 || InpV5MomentumBodyATR <= 0.0 ||
      InpStochOS < 0.0 || InpStochOB > 100.0 || InpStochOS >= InpStochOB ||
      InpMinScoreToSignal < 0 || InpMinScoreToSignal > 100 ||
      InpPanelX < 0 || InpPanelY < 0 || InpPanelWidth < 320 || InpPanelWidth > 600 ||
      InpPanelFontSize < 8 || InpPanelFontSize > 12 ||
      InpPanelRowGap < 18 || InpPanelRowGap > 22 ||
      InpPanelHeight < (276 + 13 * InpPanelRowGap) || InpPanelHeight > 800)
   {
      Print("SOMWANG FUSION V5 Sprint 3 init failed: invalid input parameters");
      return INIT_PARAMETERS_INCORRECT;
   }

   bool ok = g_orchestrator.Init(_Symbol, InpTradeTF, InpTrendTF, InpMacroTF,
                                 InpEntryEMA, InpRSIPeriod, InpATRPeriod,
                                 InpTrendEMA_Fast, InpTrendEMA_Slow,
                                 InpADXPeriod, InpMACDFast, InpMACDSlow, InpMACDSignal,
                                 InpStochK, InpStochD, InpStochSlowing,
                                 InpMinScoreToSignal, InpCooldownBarsV5,
                                 InpV4MomentumBodyATR, InpV5MomentumBodyATR,
                                 InpUseRSI50Filter, InpUseMACDFilter, InpUseStochFilter,
                                 InpStochOB, InpStochOS);
   if(!ok)
   {
      Print("SOMWANG FUSION V5 Sprint 3 init failed: initialization error");
      return INIT_FAILED;
   }

   g_dashboard.Configure("SWV5_S3_DASH_", InpPanelCorner, InpPanelX, InpPanelY,
                         InpPanelWidth, InpPanelHeight, InpPanelFontSize, InpPanelRowGap);
   if(InpLogTrendRegression)
      Print("SWV5_TREND_REGRESSION,timestamp,snapshot_sequence,history_generation,symbol,timeframe,v4_trend_bias,v5_trend_bias,v4_trend_score,v5_trend_score,v4_macro_state,v5_macro_state,match_status,mismatch_reason");
   if(InpLogMomentumRegression)
      Print("SWV5_MOMENTUM_REGRESSION,timestamp,symbol,timeframe,execution_mode,use_closed,source_bar_shift,snapshot_sequence,history_generation,data_quality_flags,v4_rsi_state,v4_rsi_value,v5_rsi_state,v5_rsi_value,v4_macd_state,v4_macd_histogram,v5_macd_state,v5_macd_histogram,v4_stoch_state,v4_stoch_k,v5_stoch_state,v5_stoch_k,v4_momentum_bias,v5_momentum_bias,v4_momentum_score,v5_momentum_score,v4_ready,v5_ready,match_status,mismatch_reason");
   IndicatorSetString(INDICATOR_SHORTNAME, "SOMWANG XAU M15 FUSION PRO V5 SPRINT 3");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   g_orchestrator.Deinit();
   g_dashboard.Clear();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(InpShowDashboard && id == CHARTEVENT_CHART_CHANGE)
      g_dashboard.RefreshLayout();
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 3)
      return rates_total;

   ArraySetAsSeries(time, true);
   datetime closedBarTime = time[1];
   SWV5_ExecutionMode mode = InpClosedBarOnly ? SWV5_EXECUTION_CLOSED_BAR : SWV5_EXECUTION_EVERY_TICK;
   if(InpClosedBarOnly && !g_orchestrator.ShouldEvaluateClosedBar(closedBarTime))
      return rates_total;

   SWV5_EngineInput engineInput;
   SWV5_PriceActionResult priceAction;
   SWV5_TrendResult trend;
   SWV5_MomentumResult momentum;
   SWV5_LegacyResult legacy;
   SWV5_PolicyResult policy;
   SWV5_TrendRegressionResult trendRegression;
   SWV5_MomentumRegressionResult momentumRegression;
   SWV5_DecisionResult decision;

   g_orchestrator.Evaluate(mode, engineInput, priceAction, trend, momentum, legacy, policy,
                           trendRegression, momentumRegression, decision);

   if(InpLogTrendRegression)
      Print("SWV5_TREND_REGRESSION," + trendRegression.csv_row);
   if(InpLogMomentumRegression)
      Print("SWV5_MOMENTUM_REGRESSION," + momentumRegression.csv_row);

   if(InpShowDashboard)
      g_dashboard.Render(engineInput, trend, momentum, legacy, decision, trendRegression, momentumRegression);

   return rates_total;
}
//+------------------------------------------------------------------+
