#ifndef SW_V5_S5_MVP_BASKET_STATE_MACHINE_MQH
#define SW_V5_S5_MVP_BASKET_STATE_MACHINE_MQH

// Pure canonical MVP lifecycle validation. NO BROKER ACCESS. No recovery trading.
#include "SW_V5_S5_MvpBasketIntegrity.mqh"

class SWV5S5_MvpBasketStateMachine : public ISWV5BasketStateMachineContract
{
public:
   virtual string ContractName(void) { return "ISWV5BasketStateMachineContract/MVP-V5"; }

   virtual bool ValidateState(const SWV5_ContractValidationContext &context,
                              const SWV5_BasketLifecycleSnapshot &s,SWV5_BasketInvariantReport &report)
   {
      ZeroMemory(report); report.contract_version=context.expected_version;
      bool ok=SWV5S5_IsV5Version(context.expected_version) && context.clock_time>0 && context.clock_sequence>0 &&
         SWV5S5_IsV5Version(s.contract_version) && s.basket_id.value!="" && s.state_version>0 &&
         SWV5S5_F_IsFenceStructurallyValid(s.ownership_fence) && s.state>=SWV5_BASKET_IDLE && s.state<=SWV5_BASKET_ERROR &&
         MathIsValidNumber(s.aggregate_open_volume) && MathIsValidNumber(s.residual_volume) &&
         s.aggregate_open_volume>=0.0 && s.residual_volume>=0.0 && s.state_entered_at>0 && s.state_entered_at<=context.clock_time;
      SWV5_DurableEventIdentitySet empty; string actual_events,expected_events;
      ok=ok && SWV5S5_MvpBasketQueriesValid(context,s.broker_queries) &&
         s.cumulative_recovery_attempts==0 && s.current_recovery_layer==0 &&
         SWV5S5_MvpBasketEmptyEvents(empty) &&
         SWV5S5_MvpCodecEncode_SWV5_DurableEventIdentitySet(empty,expected_events) &&
         SWV5S5_MvpCodecEncode_SWV5_DurableEventIdentitySet(s.accepted_recovery_evidence,actual_events) && actual_events==expected_events;
      if(s.state==SWV5_BASKET_IDLE)
         ok=ok && s.aggregate_open_volume==0.0 && s.residual_volume==0.0 &&
            s.live_position_count==0 && s.live_order_count==0 && s.pending_request_count==0;
      if(s.state==SWV5_BASKET_ACTIVE || s.state==SWV5_BASKET_RECOVERY || s.state==SWV5_BASKET_CLOSING)
         ok=ok && s.aggregate_open_volume>context.volume_tolerance && s.live_position_count>0;
      report.status=ok ? SWV5_CONTRACT_VALID : SWV5_CONTRACT_INVALID;
      report.satisfied_flags=ok ? SWV5_INVARIANT_BASKET_ID_REQUIRED|SWV5_INVARIANT_OWNER_REQUIRED : 0;
      report.violated_flags=ok ? 0 : SWV5_INVARIANT_BASKET_ID_REQUIRED;
      report.primary_violation=ok ? "" : "MVP_BASKET_STATE_INVALID"; return ok;
   }

   // Closed MVP subset. Recovery/close authorization is deliberately unavailable;
   // this class implements neither recovery trading nor a Basket framework.
   virtual bool ValidateTransition(const SWV5_ContractValidationContext &context,
                                   const SWV5_BasketLifecycleSnapshot &s,
                                   const SWV5_BasketTransitionRequest &r,SWV5_BasketTransitionDecision &d)
   {
      ZeroMemory(d); d.contract_version=context.expected_version; d.decision.contract_version=context.expected_version;
      d.resulting_state=s.state; d.resulting_state_version=s.state_version;
      d.resulting_cumulative_recovery_attempts=s.cumulative_recovery_attempts;
      d.resulting_recovery_layer=s.current_recovery_layer; d.resulting_accepted_recovery_evidence=s.accepted_recovery_evidence;
      bool ok=ValidateState(context,s,d.invariants) && SWV5S5_IsV5Version(r.contract_version) &&
         r.basket_id.value==s.basket_id.value && SWV5S5_EqualFence(r.ownership_fence,s.ownership_fence) &&
         r.from_state==s.state && r.expected_state_version==s.state_version &&
         r.evidence_time>0 && r.evidence_time<=context.clock_time && r.evidence_time>=s.state_entered_at &&
         r.to_state>=SWV5_BASKET_IDLE && r.to_state<=SWV5_BASKET_ERROR &&
         MathIsValidNumber(r.residual_volume) && r.residual_volume>=0.0;
      bool pair=false;
      if(r.from_state==r.to_state) pair=r.cause==SWV5_TRANSITION_NONE;
      if(r.from_state==SWV5_BASKET_IDLE && r.to_state==SWV5_BASKET_OPENING)
         pair=r.cause==SWV5_TRANSITION_OPEN_AUTHORIZED && r.risk_decision.disposition==SWV5_DISPOSITION_ALLOW &&
            r.reconciliation_state==SWV5_RECONCILIATION_STATE_MATCHED && r.residual_volume==0.0 &&
            r.live_position_count==0 && r.live_order_count==0 && r.pending_request_count==0;
      if(r.from_state==SWV5_BASKET_OPENING && r.to_state==SWV5_BASKET_ACTIVE)
         pair=r.cause==SWV5_TRANSITION_OPEN_CONFIRMED &&
            r.confirmation_authority==SWV5_AUTHORITY_TRANSACTION_EVENT &&
            r.correlation.phase==SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION &&
            SWV5S5_IsV5Version(r.correlation.contract_version) &&
            r.correlation.request_identity.request_id.correlation_id!="" &&
            r.correlation.request_identity.request_id.attempt_id!="" &&
            r.correlation.broker_identity.order_ticket>0 && r.correlation.broker_identity.deal_ticket>0 &&
            r.correlation.broker_identity.position_identifier>0 &&
            r.correlation.broker_identity.transaction_sequence>0 && r.correlation.broker_identity.broker_event_id!="" &&
            r.reconciliation_state==SWV5_RECONCILIATION_STATE_MATCHED && r.residual_volume>context.volume_tolerance &&
            r.live_position_count>0;
      if(r.to_state==SWV5_BASKET_HALTED && r.from_state!=SWV5_BASKET_HALTED && r.from_state!=SWV5_BASKET_ERROR)
         pair=r.cause==SWV5_TRANSITION_HARD_KILL ||
            (r.from_state!=SWV5_BASKET_IDLE && (r.cause==SWV5_TRANSITION_OWNERSHIP_LOST ||
             r.cause==SWV5_TRANSITION_BROKER_STATE_UNCERTAIN)) ||
            (r.from_state==SWV5_BASKET_IDLE && r.cause==SWV5_TRANSITION_OPERATOR_HALT);
      if(r.to_state==SWV5_BASKET_ERROR && r.from_state!=SWV5_BASKET_IDLE && r.from_state!=SWV5_BASKET_ERROR)
         pair=r.cause==SWV5_TRANSITION_CONTRACT_VIOLATION || r.cause==SWV5_TRANSITION_RECONCILIATION_FAILED;
      if(r.from_state==SWV5_BASKET_ERROR && r.to_state==SWV5_BASKET_HALTED)
         pair=r.cause==SWV5_TRANSITION_RECONCILIATION_CONFIRMED;
      ok=ok && pair && SWV5S5_MvpBasketQueriesValid(context,r.broker_queries);
      if(ok && r.from_state!=r.to_state)
      { ok=s.state_version<18446744073709551615; if(ok){d.resulting_state=r.to_state; d.resulting_state_version=s.state_version+1;} }
      d.decision.disposition=ok ? SWV5_DISPOSITION_ALLOW : SWV5_DISPOSITION_DENY;
      d.decision.reason_code=ok ? "MVP_BASKET_TRANSITION_VALID" : "MVP_BASKET_TRANSITION_DENIED";
      d.decision.reason_text=d.decision.reason_code; d.decision.evaluated_at=context.clock_time;
      d.decision.evaluation_sequence=context.evaluation_sequence;
      d.invariants.status=ok ? SWV5_CONTRACT_VALID : SWV5_CONTRACT_INVALID;
      return ok;
   }
};
#endif
