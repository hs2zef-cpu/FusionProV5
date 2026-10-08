#ifndef SW_V5_S5_MVP_ATTENDED_LAUNCH_GATE_MQH
#define SW_V5_S5_MVP_ATTENDED_LAUNCH_GATE_MQH
#include "SW_V5_S5_MvpAttendedAuthoritySeed.mqh"

// Ephemeral host safety only, never a Claim or persistent authority.
// Every new object starts unarmed, including relaunch with saved true inputs.
class SWV5S5_MvpAttendedLaunchGate
{
private:
   bool m_session_armed,m_consumed;
public:
   SWV5S5_MvpAttendedLaunchGate(void){ m_session_armed=false; m_consumed=false; }
   bool ArmExplicitly(const SWV5S5_MvpControlledDemoInvocation &i)
   {
      if(m_consumed || (i.mode!=MODE_D1_BUY && i.mode!=MODE_D6_RECOVER) ||
         (i.mode==MODE_D1_BUY && !i.armed_for_demo_submission) ||
         !i.operator_confirmed_before_claim || !i.execute_attended_once) return false;
      m_session_armed=true; return true;
   }
   bool Consumed(void) const { return m_consumed; }
   bool SessionArmed(void) const { return m_session_armed; }
   bool ConsumeEligibleBuy(const SWV5S5_MvpControlledDemoInvocation &i,const datetime observed_at,
                          const SWV5_EngineInput &engine_input,const SWV5_DecisionResult &decision,
                          const SWV5S5_ProducerTrustRecord &trust)
   {
      SWV5S5_IngressEnvelope preview; string digest;
      if(m_consumed || !m_session_armed || i.mode!=MODE_D1_BUY || !i.armed_for_demo_submission ||
         !i.operator_confirmed_before_claim || !i.execute_attended_once ||
         decision.action!=SWV5_ACTION_BUY || decision.direction!=1 || !decision.header.valid ||
         decision.header.health!=SWV5_HEALTH_HEALTHY ||
         engine_input.market.header.data_quality_flags!=SWV5_DQ_NONE || !engine_input.market.snapshot_usable ||
         engine_input.market.created_at!=observed_at || observed_at<=0 ||
         trust.valid_from>observed_at || trust.valid_until<=observed_at ||
         !SWV5S5_MvpProjectSignalSource(engine_input,decision,trust,preview,digest)) return false;
      // BEFORE even the accepted clock publication, not merely before Claim.
      m_consumed=true; m_session_armed=false; return true;
   }
   bool ConsumeRecovery(const SWV5S5_MvpControlledDemoInvocation &i)
   {
      if(m_consumed || !m_session_armed || i.mode!=MODE_D6_RECOVER || !i.operator_confirmed_before_claim || !i.execute_attended_once)
         return false;
      m_consumed=true; m_session_armed=false; return true;
   }
};
#endif
