#ifndef SW_V5_DECISION_ENGINE_MQH
#define SW_V5_DECISION_ENGINE_MQH

#include "..\\Core\\SW_V5_ResultValidator.mqh"

class CDecisionEngine
{
private:
   CSWV5ResultValidator m_validator;

   void Block(SWV5_DecisionResult &decision,
              const string reason,
              const ulong flags,
              const SWV5_EngineKind source)
   {
      decision.header.valid = true;
      decision.header.health = SWV5_HEALTH_HEALTHY;
      decision.action = SWV5_ACTION_BLOCKED;
      decision.direction = 0;
      decision.state = "BLOCKED";
      decision.header.reason_flags |= flags;
      decision.header.reason_text = reason;
      decision.blocking_engine = source;
   }

   string ResultError(const SWV5_ResultHeader &header, const string fallback)
   {
      if(header.validation_error != "") return header.validation_error;
      if(header.reason_text != "") return header.reason_text;
      return fallback;
   }

public:
   bool Decide(const SWV5_EngineInput &engineInput,
               SWV5_PriceActionResult &priceAction,
               SWV5_TrendResult &trend,
               SWV5_MomentumResult &momentum,
               SWV5_LegacyResult &legacy,
               SWV5_PolicyResult &policy,
               SWV5_DecisionResult &decision)
   {
      SWV5_InitDecisionResult(decision, engineInput);

      SWV5_ValidationResult inputValidation;
      if(!m_validator.ValidateInput(engineInput, inputValidation))
      {
         Block(decision, inputValidation.error_text, inputValidation.reason_flags, SWV5_ENGINE_MARKET);
         return true;
      }

      bool paOk = m_validator.ValidatePriceAction(priceAction, engineInput);
      bool trendOk = m_validator.ValidateTrend(trend, engineInput);
      bool momentumOk = m_validator.ValidateMomentum(momentum, engineInput);
      bool legacyOk = m_validator.ValidateLegacy(legacy, engineInput);
      bool policyOk = m_validator.ValidatePolicy(policy, engineInput);

      if(!paOk)
      {
         ulong paFlag = (priceAction.header.health == SWV5_HEALTH_UNAVAILABLE ?
                         SWV5_REASON_ENGINE_UNAVAILABLE : SWV5_REASON_INVALID_ENGINE_RESULT);
         Block(decision, ResultError(priceAction.header, "Price Action unavailable or invalid"), paFlag, SWV5_ENGINE_PRICE_ACTION);
         return true;
      }
      if(!trendOk)
      {
         Block(decision, ResultError(trend.header, "Trend unavailable or invalid"), SWV5_REASON_INVALID_ENGINE_RESULT, SWV5_ENGINE_TREND);
         return true;
      }
      if(!momentumOk)
      {
         string momentumError = ResultError(momentum.header, "Momentum result unavailable or invalid");
         ulong momentumFlag = (momentum.header.health == SWV5_HEALTH_UNAVAILABLE ?
                               SWV5_REASON_ENGINE_UNAVAILABLE : SWV5_REASON_INVALID_ENGINE_RESULT);
         Block(decision, momentumError, momentumFlag, SWV5_ENGINE_MOMENTUM);
         return true;
      }
      if(!legacyOk)
      {
         Block(decision, ResultError(legacy.header, "Legacy adapter unavailable or invalid"), SWV5_REASON_INVALID_ENGINE_RESULT, SWV5_ENGINE_LEGACY);
         return true;
      }
      if(!policyOk)
      {
         Block(decision, ResultError(policy.header, "Execution policy invalid"), SWV5_REASON_INVALID_ENGINE_RESULT, SWV5_ENGINE_CONTEXT);
         return true;
      }

      if((priceAction.header.health == SWV5_HEALTH_UNAVAILABLE || trend.header.health == SWV5_HEALTH_UNAVAILABLE ||
          momentum.header.health == SWV5_HEALTH_UNAVAILABLE) ||
         (priceAction.header.health == SWV5_HEALTH_INVALID || trend.header.health == SWV5_HEALTH_INVALID ||
          momentum.header.health == SWV5_HEALTH_INVALID))
      {
         Block(decision, "Mandatory engine unavailable or invalid", SWV5_REASON_ENGINE_UNAVAILABLE, SWV5_ENGINE_DECISION);
         return true;
      }

      if(legacy.has_legacy_signal && !policy.allowed)
      {
         Block(decision, policy.header.reason_text, SWV5_REASON_POLICY_BLOCK, SWV5_ENGINE_CONTEXT);
         decision.header.score = legacy.header.score;
         decision.header.confidence = legacy.header.confidence;
         return true;
      }

      decision.header.valid = true;
      decision.header.health = SWV5_HEALTH_HEALTHY;
      decision.action = SWV5_ACTION_WAIT;
      decision.direction = 0;
      decision.state = "WAIT";
      decision.header.score = 0.0;
      decision.header.confidence = 0.0;
      decision.header.reason_flags |= SWV5_REASON_NO_FINAL_RULE_MIGRATED;
      decision.header.reason_text = "No final V5 rule migrated through Sprint 3";

      if(legacy.has_legacy_signal)
      {
         decision.direction = legacy.legacy_direction;
         decision.action = (legacy.legacy_direction > 0 ? SWV5_ACTION_BUY : SWV5_ACTION_SELL);
         decision.state = "LEGACY_ADAPTER_" + SWV5_ActionText(decision.action);
         decision.header.score = legacy.header.score;
         decision.header.confidence = legacy.header.confidence;
         decision.header.reason_flags = legacy.header.reason_flags;
         decision.header.reason_text = legacy.header.reason_text;
      }

      return true;
   }
};

#endif
