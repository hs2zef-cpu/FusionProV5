//+------------------------------------------------------------------+
//| SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT2.mq5                       |
//| Sprint 2 trend migration and regression harness.                 |
//| Original V4/V4.2 sources are preserved and not modified.          |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_plots 0
#property version "5.02"

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

input bool InpClosedBarOnly = true;
input bool InpShowDashboard = true;
input bool InpLogTrendRegression = false;
input int  InpPanelX = 14;
input int  InpPanelY = 28;

CCentralOrchestrator g_orchestrator;
CReadOnlyDashboard   g_dashboard;

int OnInit()
{
   if(InpTrendEMA_Fast < 1 || InpTrendEMA_Slow <= InpTrendEMA_Fast ||
      InpEntryEMA < 1 || InpRSIPeriod < 2 || InpATRPeriod < 2 ||
      InpADXPeriod < 2 || InpMACDFast < 1 || InpMACDSlow <= InpMACDFast ||
      InpMACDSignal < 1 || InpStochK < 1 || InpStochD < 1 ||
      InpStochSlowing < 1 || InpMinScoreToSignal < 0 || InpMinScoreToSignal > 100)
   {
      Print("SOMWANG FUSION V5 Sprint 2 init failed: invalid input parameters");
      return INIT_PARAMETERS_INCORRECT;
   }

   bool ok = g_orchestrator.Init(_Symbol, InpTradeTF, InpTrendTF, InpMacroTF,
                                 InpEntryEMA, InpRSIPeriod, InpATRPeriod,
                                 InpTrendEMA_Fast, InpTrendEMA_Slow,
                                 InpADXPeriod, InpMACDFast, InpMACDSlow, InpMACDSignal,
                                 InpStochK, InpStochD, InpStochSlowing,
                                 InpMinScoreToSignal, InpCooldownBarsV5);
   if(!ok)
   {
      Print("SOMWANG FUSION V5 Sprint 2 init failed: indicator cache initialization error");
      return INIT_FAILED;
   }

   g_dashboard.Configure("SWV5_DASH_", InpPanelX, InpPanelY);
   if(InpLogTrendRegression)
      Print("SWV5_TREND_REGRESSION,timestamp,snapshot_sequence,history_generation,symbol,timeframe,v4_trend_bias,v5_trend_bias,v4_trend_score,v5_trend_score,v4_macro_state,v5_macro_state,match_status,mismatch_reason");
   IndicatorSetString(INDICATOR_SHORTNAME, "SOMWANG XAU M15 FUSION PRO V5 SPRINT 2");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   g_orchestrator.Deinit();
   g_dashboard.Clear();
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
   SWV5_LegacyResult legacy;
   SWV5_PolicyResult policy;
   SWV5_TrendRegressionResult trendRegression;
   SWV5_DecisionResult decision;

   g_orchestrator.Evaluate(mode, engineInput, priceAction, trend, legacy, policy, trendRegression, decision);

   if(InpLogTrendRegression)
      Print("SWV5_TREND_REGRESSION," + trendRegression.csv_row);

   if(InpShowDashboard)
      g_dashboard.Render(engineInput, trend, legacy, decision, trendRegression);

   return rates_total;
}
//+------------------------------------------------------------------+
