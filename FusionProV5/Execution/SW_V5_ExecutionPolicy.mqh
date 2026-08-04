#ifndef SW_V5_EXECUTION_POLICY_MQH
#define SW_V5_EXECUTION_POLICY_MQH

#include "..\\Core\\SW_V5_Interfaces.mqh"

class CManualIndicatorExecutionPolicy : public ISWV5ExecutionPolicy
{
private:
   int      m_minScore;
   datetime m_lastSignalTime;
   int      m_cooldownBars;

public:
   CManualIndicatorExecutionPolicy()
   {
      m_minScore = 85;
      m_lastSignalTime = 0;
      m_cooldownBars = 8;
   }

   void Configure(const int minScore, const int cooldownBars)
   {
      m_minScore = minScore;
      m_cooldownBars = cooldownBars;
   }

   bool ValidateScoreContract(const SWV5_ScoreSemantics semantics,
                              const bool comparable,
                              const double maximumReachableScore,
                              string &diagnostic,
                              bool &warning)
   {
      diagnostic = "";
      warning = false;
      if(!SWV5_IsFinite(maximumReachableScore) || maximumReachableScore < 0.0 || maximumReachableScore > 100.0)
      {
         diagnostic = "Active score producer declares invalid maximum reachable score";
         return false;
      }
      if(!comparable)
      {
         warning = true;
         diagnostic = "LEGACY_SCORE_NOT_COMPARABLE: Fibo fixed score is not V4.2 composite score";
         return true;
      }
      if(semantics != SWV5_SCORE_V42_COMPOSITE && semantics != SWV5_SCORE_NORMALIZED_ENGINE)
      {
         diagnostic = "Comparable score producer declares incompatible semantics";
         return false;
      }
      if(maximumReachableScore < (double)m_minScore)
      {
         diagnostic = "Configured threshold is unreachable by active comparable score producer";
         return false;
      }
      return true;
   }

   void MarkSignal(const datetime signalTime)
   {
      m_lastSignalTime = signalTime;
   }

   string Name()
   {
      return "ManualIndicatorExecutionPolicy";
   }

   bool EvaluatePolicy(const SWV5_EngineInput &engineInput, const SWV5_LegacyResult &legacy, SWV5_PolicyResult &policy)
   {
      SWV5_InitPolicyResult(policy, engineInput);
      policy.header.reason_text = "Policy allows non-signal or qualified legacy signal";
      if(!legacy.has_legacy_signal)
         return true;

      bool compatibleSemantics = (legacy.score_semantics == SWV5_SCORE_V42_COMPOSITE ||
                                  legacy.score_semantics == SWV5_SCORE_NORMALIZED_ENGINE);
      bool validMaximum = (SWV5_IsFinite(legacy.maximum_reachable_score) &&
                           legacy.maximum_reachable_score >= 0.0 && legacy.maximum_reachable_score <= 100.0);
      if(!legacy.score_comparable_to_execution_threshold || !compatibleSemantics || !validMaximum)
      {
         policy.allowed = false;
         policy.header.reason_flags |= SWV5_REASON_POLICY_BLOCK | SWV5_REASON_LEGACY_SCORE_NOT_COMPARABLE;
         policy.header.reason_text = "LEGACY_SCORE_NOT_COMPARABLE";
         return true;
      }

      if(legacy.maximum_reachable_score < (double)m_minScore)
      {
         policy.allowed = false;
         policy.header.reason_flags |= SWV5_REASON_POLICY_BLOCK | SWV5_REASON_SCORE_THRESHOLD_UNREACHABLE;
         policy.header.reason_text = "Configured score threshold is unreachable";
         return true;
      }

      if(legacy.header.score < (double)m_minScore)
      {
         policy.allowed = false;
         policy.header.reason_flags |= SWV5_REASON_POLICY_BLOCK;
         policy.header.reason_text = "Score below execution threshold";
         return true;
      }

      if(m_lastSignalTime > 0)
      {
         int fromLast = iBarShift(engineInput.market.header.symbol, engineInput.market.header.timeframe, m_lastSignalTime, false);
         int fromNow = iBarShift(engineInput.market.header.symbol, engineInput.market.header.timeframe, engineInput.market.header.closed_bar_time, false);
         if(fromLast >= 0 && fromNow >= 0 && MathAbs(fromLast - fromNow) < m_cooldownBars)
         {
            policy.allowed = false;
            policy.header.reason_flags |= SWV5_REASON_POLICY_BLOCK;
            policy.header.reason_text = "Cooldown active";
            return true;
         }
      }

      return true;
   }
};

#endif
