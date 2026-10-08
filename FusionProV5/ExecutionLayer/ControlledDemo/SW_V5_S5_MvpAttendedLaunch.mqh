#ifndef SW_V5_S5_MVP_ATTENDED_LAUNCH_MQH
#define SW_V5_S5_MVP_ATTENDED_LAUNCH_MQH

// Thin native executable graph; no Signal policy or authority is authored here.
#include "SW_V5_S5_MvpAttendedLaunchGate.mqh"
#include "../../Orchestration/SW_V5_Orchestrator.mqh"

bool SWV5S5_MvpGitSourceIdentity(const string sha)
{
   if(StringLen(sha)!=40) return false;
   for(int i=0;i<40;i++)
   { const ushort c=StringGetCharacter(sha,i); if(!((c>=48 && c<=57) || (c>=97 && c<=102))) return false; }
   return true;
}

// Shared serialized dispatch, used by the native host and broker-free MQL
// rehearsal. The host builds every input from native observations/real owners;
// only tests substitute the explicitly non-mutating submission/read seams.
bool SWV5S5_MvpDispatchAttended(const SWV5S5_MvpControlledDemoInvocation &invocation,
   const SWV5S5_MvpLeaseClockObservation &clock,const SWV5S5_F_AdapterEnvironment &environment,
   const SWV5_EngineInput &engine,const SWV5_DecisionResult &decision,const ulong filling,
   ISWV5S5MvpReadOnlyPlatform &platform,SWV5S5_MvpControlledDemoAuthorityPort &authority,
   SWV5S5_MvpControlledDemoRunner &runner,ISWV5S5_MvpControlledDemoSubmissionBoundary &boundary,
   SWV5S5_MvpBrokerEvidenceStore &evidence,ISWV5S5MvpBrokerRecoveryReadPort *recovery,
   SWV5S5_MvpControlledDemoAuthoritySeed &seed,SWV5S5_MvpControlledDemoResult &result,string &reason)
{
   ZeroMemory(result); SWV5S5_MvpAttendedAuthoritySeedBuilder builder;
   if(!builder.LoadBase(invocation,clock,platform,environment,seed,reason)) return false;
   seed.engine_input=engine; seed.decision=decision; seed.filling_mode=filling;
   SWV5S5_MvpSqliteAuthorityStore readonly;
   if(invocation.mode!=MODE_D6_RECOVER &&
      (!readonly.OpenReadOnly(invocation.relative_store_path,invocation.persistence_namespace_identity) ||
       !builder.CompleteIncreasing(readonly,seed,reason))) return false;
   if(invocation.mode!=MODE_PREFLIGHT &&
      !evidence.Configure(invocation.relative_store_path,invocation.persistence_namespace_identity)) return false;
   if(!authority.Configure(invocation.relative_store_path,invocation.persistence_namespace_identity,
      seed,GetPointer(platform),GetPointer(evidence),recovery)) return false;
   const bool ok=runner.Run(invocation,authority,boundary,result);
   reason=result.stop_reason+"/"+authority.LastStage(); return ok;
}

class SWV5S5_MvpAttendedLaunch
{
private:
   CCentralOrchestrator m_orchestrator;
   SWV5S5_MvpMt5ReadOnlyPlatform m_platform;
   SWV5S5_MvpAttendedAuthoritySeedBuilder m_seed_builder;
   SWV5S5_MvpAttendedLaunchGate m_gate;
   SWV5S5_MvpControlledDemoRunner m_runner;
   SWV5S5_MvpControlledDemoAuthorityPort m_authority;
   SWV5S5_MvpBrokerEvidenceStore m_evidence_store;
   SWV5S5_F_BrokerPlatformAdapter *m_adapter;
   SWV5S5_MvpBrokerRecoveryReadPort *m_recovery;
   SWV5S5_MvpControlledDemoBrokerBoundary *m_boundary;
   SWV5S5_MvpControlledDemoInvocation m_invocation;
   ulong m_filling;
   bool m_initialized,m_callback_bound;
   ulong m_event_number;
   SWV5S5_MvpControlledDemoAuthoritySeed m_recorded_seed;
   SWV5S5_MvpControlledDemoResult m_recorded_result;
   bool m_has_record;

   bool ExpectedProfileNow(SWV5S5_F_AdapterEnvironment &environment)
   {
      SWV5S5_MvpRuntimeProfileObservation profile; datetime at=0;
      return m_platform.CaptureProfile(SWV5S5_MVP_SYMBOL,profile,at) &&
         SWV5S5_MvpProfileMatches(profile,ACCOUNT_TRADE_MODE_DEMO) &&
         profile.broker_identity==m_invocation.expected_broker_identity && profile.server==m_invocation.expected_server &&
         profile.account_login==m_invocation.expected_demo_account_login &&
         m_adapter.ObserveEnvironment(SWV5S5_MVP_SYMBOL,environment);
   }

   void Record(const SWV5S5_MvpControlledDemoAuthoritySeed &seed,const SWV5S5_MvpControlledDemoResult &result)
   {
      SWV5S5_MvpControlledDemoEvidence e; ZeroMemory(e);
      e.source_head=m_invocation.source_head; e.runner_version=SWV5S5_MVP_CONTROLLED_DEMO_RUNNER_VERSION;
      e.mode=(int)m_invocation.mode; e.armed=m_gate.SessionArmed() || m_gate.Consumed();
      e.armed_input=m_invocation.armed_for_demo_submission; e.operator_confirmed_input=m_invocation.operator_confirmed_before_claim;
      e.execute_once_input=m_invocation.execute_attended_once; e.stop_reason=result.stop_reason;
      e.timestamp=TimeCurrent(); e.terminal_build=(int)TerminalInfoInteger(TERMINAL_BUILD); e.mql_build=(int)__MQLBUILD__;
      e.broker=seed.adapter_environment.broker_identity; e.server=seed.adapter_environment.server;
      e.account_login=seed.adapter_environment.account_login;
      // A failed native profile read is cleared; zero must not imply observed Demo.
      e.account_trade_mode=(seed.adapter_environment.account_login>0 ? seed.adapter_environment.account_trade_mode : -1);
      e.margin_mode=(seed.adapter_environment.account_login>0 ? (int)seed.adapter_environment.account_mode : -1); e.symbol=SWV5S5_MVP_SYMBOL;
      e.ownership_lease_id=seed.current_lease.store_revision; e.ownership_fence_digest=seed.current_lease.fence.fencing_token_digest;
      e.producer_trust_record_id=seed.current_trust.authority_record_id;
      e.producer_trust_generation=seed.current_trust.authority_generation; e.producer_trust_digest=seed.current_trust.record_digest;
      e.safety_latch_id=seed.hard_kill_state.latch_id; e.safety_latch_generation=seed.hard_kill_state.latch_generation;
      e.request_correlation_id=result.request_correlation_id; e.attempt_id=result.attempt_id;
      e.claim_granted_now=result.claim_granted_now; e.transport_attempted=result.synchronous_result.invocation_attempted;
      e.transport_result=result.synchronous_result.transport_result; e.last_error=result.synchronous_result.last_error;
      e.retcode=result.synchronous_result.retcode; e.request_id=result.synchronous_result.request_id_session_local;
      e.order_ticket=result.synchronous_result.order_ticket; e.deal_ticket=result.synchronous_result.deal_ticket;
      e.retry_allowed=false; e.broker_submission_calls=result.broker_submission_calls;
      m_authority.FillRuntimeEvidence(e);
      if(!SWV5S5_MvpWriteControlledDemoEvidence(m_invocation.evidence_relative_path,e))
         Print("ATTENDED_LAUNCH|EVIDENCE_WRITE_FAILED|NO_RETRY");
      Print("ATTENDED_LAUNCH|",result.stop_reason,"|broker_submission_calls=",result.broker_submission_calls);
   }

   void RecordStop(const SWV5S5_F_AdapterEnvironment &environment,const string reason)
   {
      SWV5S5_MvpControlledDemoAuthoritySeed unavailable; SWV5S5_MvpControlledDemoResult stopped;
      ZeroMemory(unavailable); ZeroMemory(stopped); unavailable.adapter_environment=environment; stopped.stop_reason=reason;
      Record(unavailable,stopped); // Unknown fields remain explicitly unobserved.
   }

public:
   SWV5S5_MvpAttendedLaunch(void)
   { m_adapter=NULL; m_recovery=NULL; m_boundary=NULL; m_initialized=false; m_callback_bound=false; m_event_number=0; m_has_record=false; }
   ~SWV5S5_MvpAttendedLaunch(void)
   { m_orchestrator.Deinit(); if(m_boundary!=NULL) delete m_boundary;
     if(m_recovery!=NULL) delete m_recovery; if(m_adapter!=NULL) delete m_adapter; }

   bool Init(const SWV5S5_MvpControlledDemoInvocation &invocation,const ulong filling_mode)
   {
      m_invocation=invocation; m_filling=filling_mode;
      if(_Symbol!=SWV5S5_MVP_SYMBOL || invocation.mode==MODE_D3_SELL ||
         !SWV5S5_MvpGitSourceIdentity(invocation.source_head)) return false;
      m_adapter=new SWV5S5_F_BrokerPlatformAdapter(SWV5S5_MVP_BROKER_READ_PATH,
         "MVP-NATIVE-BROKER-OBSERVER",SWV5S5_MVP_BROKER_SEQUENCE_AUTHORITY,1,1);
      m_recovery=new SWV5S5_MvpBrokerRecoveryReadPort(m_adapter);
      m_boundary=new SWV5S5_MvpControlledDemoBrokerBoundary(m_adapter);
      if(m_adapter==NULL || m_recovery==NULL || m_boundary==NULL) return false;
      if(invocation.mode==MODE_D1_BUY && !m_orchestrator.Init(SWV5S5_MVP_SYMBOL,PERIOD_M15,PERIOD_H1,PERIOD_H4,
         21,14,14,50,200,14,12,26,9,5,3,3,85,8,0.32,0.36,true,true,true,80.0,20.0,180))
      { Print("ATTENDED_LAUNCH|SIGNAL_INITIALIZATION_FAILED|",m_orchestrator.InitializationDiagnostic()); return false; }
      m_initialized=true; return true;
   }

   // Explicit fresh human key acknowledgement, not a submit event. No state
   // survives object destruction; saved input flags alone cannot re-arm.
   bool ArmSession(void) { return m_initialized && m_gate.ArmExplicitly(m_invocation); }

   void OnCurrentSymbolTick(void)
   {
      if(!m_initialized || _Symbol!=SWV5S5_MVP_SYMBOL || m_gate.Consumed()) return;
      SWV5S5_F_AdapterEnvironment environment; ZeroMemory(environment);
      if(!ExpectedProfileNow(environment)) { ZeroMemory(environment); RecordStop(environment,"PROFILE_FAIL_CLOSED"); return; }
      SWV5_EngineInput engine_input; SWV5_DecisionResult decision; ZeroMemory(engine_input); ZeroMemory(decision);
      SWV5S5_MvpLeaseClockAuthority clock; SWV5S5_MvpLeaseClockObservation observation;
      SWV5S5_MvpAuthorityRow clock_row; bool found=false;
      if(m_invocation.mode==MODE_D1_BUY)
      {
         if(!m_gate.SessionArmed()) return;
         SWV5_PriceActionResult pa; SWV5_TrendResult trend; SWV5_MomentumResult momentum;
         SWV5_LegacyResult legacy; SWV5_PolicyResult policy;
         SWV5_TrendRegressionResult tr; SWV5_MomentumRegressionResult mr;
         if(!m_orchestrator.Evaluate(SWV5_EXECUTION_EVERY_TICK,engine_input,pa,trend,momentum,legacy,policy,tr,mr,decision)) return;
         SWV5S5_MvpManualProducerTrustProvisioner trust;
         SWV5S5_ProducerTrustRecord record; SWV5S5_ProducerTrustAnchor anchor; string op,auth;
         if(!trust.ConfigureReadOnly(m_invocation.relative_store_path,m_invocation.persistence_namespace_identity) ||
            !trust.LoadCurrent(record,anchor,op,auth,found) || !found ||
            !m_gate.ConsumeEligibleBuy(m_invocation,TimeCurrent(),engine_input,decision,record)) return;
      }
      else if(m_invocation.mode==MODE_D6_RECOVER)
      { if(!m_gate.ConsumeRecovery(m_invocation)) return; }
      else if(m_invocation.mode!=MODE_PREFLIGHT) return;

      if(m_invocation.mode==MODE_PREFLIGHT)
      {
         // Historical stored clock is never promoted to fresh current time.
         // A missing/non-current observation is a prerequisite failure, not
         // permission to publish a clock from default PREFLIGHT.
         if(!clock.ConfigureReadOnly(m_invocation.relative_store_path,m_invocation.persistence_namespace_identity) ||
            !clock.LoadStored(observation,clock_row,found) || !found || observation.observed_at!=TimeCurrent())
         { RecordStop(environment,"PREFLIGHT_ACCEPTED_CURRENT_CLOCK_PREREQUISITE_MISSING_ZERO_AUTHORITY_MUTATION"); return; }
      }
      else
      {
         // Wrapper latch is already consumed before this FIRST durable write.
         m_event_number++;
         if(!clock.Configure(m_invocation.relative_store_path,m_invocation.persistence_namespace_identity) ||
            !clock.ObserveFromCurrentSymbolOnTick(SWV5S5_MVP_SYMBOL,
               "ATTENDED/"+IntegerToString((long)GetMicrosecondCount())+"/"+IntegerToString((long)m_event_number),observation,clock_row))
         { RecordStop(environment,"FRESH_CLOCK_FAILED_LATCH_CONSUMED_NO_RETRY"); return; }
      }
      SWV5S5_MvpControlledDemoAuthoritySeed seed; string reason;
      SWV5S5_MvpControlledDemoResult result;
      SWV5S5_MvpDispatchAttended(m_invocation,observation,environment,engine_input,decision,m_filling,m_platform,
         m_authority,m_runner,*m_boundary,m_evidence_store,m_recovery,seed,result,reason);
      m_callback_bound=m_invocation.mode!=MODE_PREFLIGHT;
      m_recorded_seed=seed; m_recorded_result=result; m_has_record=true;
      Record(seed,result);
   }

   void ObserveCallbackOnly(const MqlTradeTransaction &transaction,const MqlTradeRequest &request,const MqlTradeResult &result)
   {
      if(!m_initialized || !m_callback_bound) return;
      m_runner.OnTradeTransaction(transaction,request,result,m_authority);
      if(m_has_record) Record(m_recorded_seed,m_recorded_result); // diagnostic readback only, NEVER Run
   }
};
#endif
