#ifndef SW_V5_ORCHESTRATOR_MQH
#define SW_V5_ORCHESTRATOR_MQH

#include "..\\Platform\\SW_V5_PlatformAdapter.mqh"
#include "..\\Indicators\\SW_V5_IndicatorCache.mqh"
#include "..\\Engines\\SW_V5_PriceActionEngine.mqh"
#include "..\\Engines\\SW_V5_TrendEngine.mqh"
#include "..\\Engines\\SW_V5_MomentumEngine.mqh"
#include "..\\Adapters\\SW_V5_LegacyEngineAdapter.mqh"
#include "..\\Decision\\SW_V5_DecisionEngine.mqh"
#include "..\\Execution\\SW_V5_ExecutionPolicy.mqh"
#include "..\\Regression\\SW_V5_TrendRegression.mqh"
#include "..\\Regression\\SW_V5_MomentumRegression.mqh"

class CCentralOrchestrator
{
private:
   CMT5PlatformAdapter             m_platform;
   CIndicatorCache                 m_cache;
   CPriceActionEngine              m_priceAction;
   CTrendEngine                    m_trend;
   CMomentumEngine                 m_momentum;
   CLegacyEngineAdapter            m_legacy;
   CDecisionEngine                 m_decisionEngine;
   CManualIndicatorExecutionPolicy m_executionPolicy;
   CTrendRegression                m_trendRegression;
   CMomentumRegression             m_momentumRegression;
   ulong                           m_sequence;
   string                          m_symbol;
   ENUM_TIMEFRAMES                 m_tradeTf;
   ENUM_TIMEFRAMES                 m_trendTf;
   ENUM_TIMEFRAMES                 m_macroTf;
   datetime                        m_lastEvaluatedClosedBar;
   string                          m_initializationDiagnostic;

public:
   CCentralOrchestrator()
   {
      m_sequence = 0;
      m_symbol = _Symbol;
      m_tradeTf = PERIOD_M15;
      m_trendTf = PERIOD_H1;
      m_macroTf = PERIOD_H4;
      m_lastEvaluatedClosedBar = 0;
      m_initializationDiagnostic = "";
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
             const int stochSlowing,
             const int minScore,
             const int cooldownBars,
             const double v4MomentumBodyAtr = 0.32,
             const double v5MomentumBodyAtr = 0.36,
             const bool useRsi50 = true,
             const bool useMacd = true,
             const bool useStoch = true,
             const double stochOb = 80.0,
             const double stochOs = 20.0,
             const int staleToleranceSeconds = 180)
   {
      m_symbol = symbol;
      m_tradeTf = tradeTf;
      m_trendTf = trendTf;
      m_macroTf = macroTf;
      m_initializationDiagnostic = "";
      m_executionPolicy.Configure(minScore, cooldownBars);
      if(!m_platform.Configure(staleToleranceSeconds))
      {
         m_initializationDiagnostic = "Invalid stale-data tolerance";
         return false;
      }
      bool momentumOk = m_momentum.Configure(v4MomentumBodyAtr, v5MomentumBodyAtr, useRsi50, useMacd, useStoch, stochOb, stochOs);
      bool regressionOk = m_momentumRegression.Configure(v4MomentumBodyAtr, v5MomentumBodyAtr, useRsi50, useMacd, useStoch, stochOb, stochOs);
      m_cache.ConfigureMomentumReads(useMacd, useStoch);

      bool cacheOk = m_cache.Init(symbol, tradeTf, trendTf, macroTf, entryEma, rsiPeriod, atrPeriod,
                                  trendFast, trendSlow, adxPeriod, macdFast, macdSlow, macdSignal,
                                  stochK, stochD, stochSlowing);
      bool legacyOk = m_cache.InitLegacyFibo(symbol, tradeTf);
      if(!cacheOk)
         m_initializationDiagnostic = "Mandatory indicator handles unavailable: " + m_cache.InitializationDiagnostic();
      else if(!legacyOk)
         m_initializationDiagnostic = "Mandatory legacy source unavailable: " + m_cache.InitializationDiagnostic();
      else if(!momentumOk || !regressionOk)
         m_initializationDiagnostic = "Momentum or regression configuration is invalid";

      string scoreDiagnostic = "";
      bool scoreWarning = false;
      bool scoreContractOk = m_executionPolicy.ValidateScoreContract(SWV5_SCORE_LEGACY_FIXED, false,
                                                                      SWV5_LEGACY_FIBO_SIGNAL_SCORE,
                                                                      scoreDiagnostic, scoreWarning);
      if(!scoreContractOk)
         m_initializationDiagnostic = scoreDiagnostic;
      else if(scoreWarning && m_initializationDiagnostic == "")
         m_initializationDiagnostic = "WARNING: " + scoreDiagnostic;

      m_platform.ResetHistoryBaseline();
      return (cacheOk && legacyOk && momentumOk && regressionOk && scoreContractOk);
   }

   string InitializationDiagnostic()
   {
      return m_initializationDiagnostic;
   }

   void Deinit()
   {
      m_cache.Release();
   }

   bool ShouldEvaluateClosedBar(const datetime closedBarTime)
   {
      if(closedBarTime <= 0)
         return false;
      if(closedBarTime == m_lastEvaluatedClosedBar)
         return false;
      return true;
   }

   bool BuildInput(const SWV5_ExecutionMode executionMode, SWV5_EngineInput &engineInput)
   {
      ZeroMemory(engineInput);
      ulong nextSequence = ++m_sequence;
      bool marketOk = m_platform.BuildMarketSnapshot(m_symbol, m_tradeTf, executionMode, nextSequence, engineInput.market);
      int shift = (executionMode == SWV5_EXECUTION_EVERY_TICK ? 0 : 1);
      bool indicatorOk = false;
      if(marketOk)
         indicatorOk = m_cache.BuildIndicatorSnapshot(engineInput.market, shift, engineInput.indicators);
      else
      {
         SWV5_InitIndicatorSnapshot(engineInput.indicators);
         engineInput.indicators.header = engineInput.market.header;
         engineInput.indicators.header.data_quality_flags |= SWV5_DQ_MISSING_DATA;
      }

      if(!indicatorOk)
         engineInput.indicators.header.data_quality_flags |= SWV5_DQ_PARTIAL_DATA;

      return marketOk;
   }

   bool Evaluate(const SWV5_ExecutionMode executionMode,
                 SWV5_EngineInput &engineInput,
                 SWV5_PriceActionResult &priceActionResult,
                 SWV5_TrendResult &trendResult,
                 SWV5_MomentumResult &momentumResult,
                 SWV5_LegacyResult &legacyResult,
                 SWV5_PolicyResult &policyResult,
                 SWV5_TrendRegressionResult &trendRegressionResult,
                 SWV5_MomentumRegressionResult &momentumRegressionResult,
                 SWV5_DecisionResult &decision)
   {
      if(!BuildInput(executionMode, engineInput))
      {
         SWV5_InitPriceActionResult(priceActionResult, engineInput);
         SWV5_InitTrendResult(trendResult, engineInput);
         SWV5_InitMomentumResult(momentumResult, engineInput);
         SWV5_InitLegacyResult(legacyResult, engineInput);
         SWV5_InitPolicyResult(policyResult, engineInput);
         m_trendRegression.Compare(engineInput, trendResult, trendRegressionResult);
         m_momentumRegression.Compare(engineInput, momentumResult, momentumRegressionResult);
         m_decisionEngine.Decide(engineInput, priceActionResult, trendResult, momentumResult, legacyResult, policyResult, decision);
         return decision.header.valid;
      }

      m_trend.Evaluate(engineInput, trendResult);
      m_momentum.Evaluate(engineInput, momentumResult);
      m_priceAction.Evaluate(engineInput, priceActionResult);
      m_legacy.Evaluate(engineInput, legacyResult);
      m_executionPolicy.EvaluatePolicy(engineInput, legacyResult, policyResult);

      m_trendRegression.Compare(engineInput, trendResult, trendRegressionResult);
      m_momentumRegression.Compare(engineInput, momentumResult, momentumRegressionResult);
      m_decisionEngine.Decide(engineInput, priceActionResult, trendResult, momentumResult, legacyResult, policyResult, decision);

      if(decision.action == SWV5_ACTION_BUY || decision.action == SWV5_ACTION_SELL)
         m_executionPolicy.MarkSignal(engineInput.market.header.closed_bar_time);

      if(executionMode == SWV5_EXECUTION_CLOSED_BAR)
         m_lastEvaluatedClosedBar = engineInput.market.header.closed_bar_time;

      return decision.header.valid;
   }

   bool Evaluate(const SWV5_ExecutionMode executionMode,
                 SWV5_EngineInput &engineInput,
                 SWV5_PriceActionResult &priceActionResult,
                 SWV5_TrendResult &trendResult,
                 SWV5_LegacyResult &legacyResult,
                 SWV5_PolicyResult &policyResult,
                 SWV5_TrendRegressionResult &trendRegressionResult,
                 SWV5_DecisionResult &decision)
   {
      SWV5_MomentumResult momentumResult;
      SWV5_MomentumRegressionResult momentumRegressionResult;
      return Evaluate(executionMode, engineInput, priceActionResult, trendResult, momentumResult,
                      legacyResult, policyResult, trendRegressionResult, momentumRegressionResult, decision);
   }
};

#endif
