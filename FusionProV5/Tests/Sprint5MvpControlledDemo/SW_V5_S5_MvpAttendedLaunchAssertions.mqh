#ifndef SW_V5_S5_MVP_ATTENDED_LAUNCH_ASSERTIONS_MQH
#define SW_V5_S5_MVP_ATTENDED_LAUNCH_ASSERTIONS_MQH
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER MUTATION.
// Native readonly platform + real SQLite owners; deterministic Decision uses
// TEST external engine-result fixtures, not hand-authored DecisionResult.
#include "../../ExecutionLayer/ControlledDemo/SW_V5_S5_MvpAttendedLaunch.mqh"
#include "SW_V5_S5_MvpAttendedBuild.generated.mqh"
#include "../../ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpAttendedAdministration.mqh"
#include "../Sprint5MvpD1Authorities/SW_V5_S5_MvpD1AuthorityAssertions.mqh"

bool SWV5S5_LaunchDecision(const datetime at,const int external_legacy_direction,
                          SWV5_EngineInput &engine,SWV5_DecisionResult &decision)
{
   ZeroMemory(engine); SWV5_InitHeader(engine.market.header,1,1,SWV5_EXECUTION_EVERY_TICK,SWV5S5_MVP_SYMBOL,PERIOD_M15,at-900);
   engine.market.created_at=at; engine.market.has_rates=true; engine.market.history_token_valid=true;
   engine.market.snapshot_usable=true; engine.indicators.header=engine.market.header;
   SWV5_PriceActionResult pa; SWV5_TrendResult trend; SWV5_MomentumResult momentum;
   SWV5_LegacyResult legacy; SWV5_PolicyResult policy; CDecisionEngine actual;
   SWV5_InitPriceActionResult(pa,engine); SWV5_InitTrendResult(trend,engine);
   SWV5_InitMomentumResult(momentum,engine); SWV5_InitLegacyResult(legacy,engine); SWV5_InitPolicyResult(policy,engine);
   pa.header.health=SWV5_HEALTH_HEALTHY; pa.header.valid=true;
   trend.header.health=SWV5_HEALTH_HEALTHY; trend.header.valid=true; trend.use_closed=false;
   pa.state="NEUTRAL"; trend.trend_state="NEUTRAL";
   trend.trend_shift=engine.indicators.trend_shift; trend.macro_shift=engine.indicators.macro_shift;
   trend.trend_fast_value=3500.0; trend.trend_slow_value=3500.0;
   momentum.header.health=SWV5_HEALTH_HEALTHY; momentum.header.valid=true; momentum.ready=true;
   momentum.momentum_state="NEUTRAL"; momentum.rsi_state="NEUTRAL"; momentum.macd_state="NEUTRAL"; momentum.stoch_state="NEUTRAL";
   momentum.body_value=1.0; momentum.atr_value=4.0; momentum.body_atr_ratio=0.25;
   momentum.v4_body_threshold=0.32; momentum.v5_body_threshold=0.36; momentum.rsi_value=50.0;
   momentum.macd_main_value=0.0; momentum.macd_signal_value=0.0; momentum.macd_histogram_value=0.0;
   momentum.stoch_k_value=50.0; momentum.stoch_d_value=50.0;
   legacy.header.health=SWV5_HEALTH_HEALTHY; legacy.header.valid=true; legacy.header.score=85.0;
   legacy.header.confidence=1.0; legacy.has_legacy_signal=external_legacy_direction!=0;
   legacy.legacy_direction=external_legacy_direction;
   legacy.buy_buffer=(external_legacy_direction>0 ? 3500.0 : EMPTY_VALUE);
   legacy.sell_buffer=(external_legacy_direction<0 ? 3500.0 : EMPTY_VALUE);
   const bool ok=actual.Decide(engine,pa,trend,momentum,legacy,policy,decision);
   Print("LAUNCH_TEST_DECIDE|external=",external_legacy_direction,"|actual=",(int)decision.action,"|reason=",decision.header.reason_text);
   return ok;
}

bool SWV5S5_LaunchRowsEqual(const SWV5S5_MvpAuthorityRow &a[],const SWV5S5_MvpAuthorityRow &b[])
{
   if(ArraySize(a)!=ArraySize(b)) return false;
   for(int i=0;i<ArraySize(a);i++)
      if(a[i].domain_key!=b[i].domain_key || a[i].record_key!=b[i].record_key || a[i].state!=b[i].state ||
         a[i].logical_revision!=b[i].logical_revision || a[i].store_revision!=b[i].store_revision ||
         a[i].payload_digest!=b[i].payload_digest || a[i].payload!=b[i].payload || a[i].updated_at!=b[i].updated_at) return false;
   return true;
}

// TEST external Broker observations only: this seam never claims native Broker
// execution evidence. Account, Execution, SQLite and all decision/authority
// functions below are production implementations. Raw *_msc units mirror MT5.
class SWV5S5_TestLaunchRecovery : public SWV5S5_MvpD1RecoveryReadPort
{
private:
   double m_price;
public:
   SWV5S5_TestLaunchRecovery(const bool positive,const double price):SWV5S5_MvpD1RecoveryReadPort(positive) { m_price=price; }
   virtual bool Query(const SWV5S5_F_ReconciliationBinding &binding,const SWV5S5_F_CapabilityProof &proof,
      const datetime from,const datetime to,ISWV5S5FBrokerEvidenceStore &store,SWV5S5_F_BrokerQuerySnapshot &snapshot)
   {
      if(!SWV5S5_MvpD1RecoveryReadPort::Query(binding,proof,from,to,store,snapshot)) return false;
      string body=snapshot.profile.profile_digest+"/"+IntegerToString((long)snapshot.owner_query_sequence)+"/"+
         IntegerToString((long)from)+"/"+IntegerToString((long)to);
      for(int i=0;i<ArraySize(snapshot.history_orders);i++)
      {
         snapshot.history_orders[i].setup_time_msc=(datetime)((long)binding.claimed_at*1000);
         snapshot.history_orders[i].done_time_msc=(datetime)((long)to*1000);
         body+="/ORDER/"+IntegerToString((long)snapshot.history_orders[i].ticket)+"/"+
            IntegerToString((long)snapshot.history_orders[i].position_identifier)+"/"+
            IntegerToString((long)snapshot.history_orders[i].done_time_msc);
      }
      for(int i=0;i<ArraySize(snapshot.history_deals);i++)
      {
         snapshot.history_deals[i].price=m_price; snapshot.history_deals[i].time_msc=(datetime)((long)to*1000);
         body+="/DEAL/"+IntegerToString((long)snapshot.history_deals[i].ticket)+"/"+
            DoubleToString(snapshot.history_deals[i].volume,8)+"/"+DoubleToString(m_price,8)+"/"+
            IntegerToString((long)snapshot.history_deals[i].time_msc);
      }
      if(!SWV5S5_DomainDigest("TEST-ONLY-EXTERNAL-BROKER-LAUNCH-FIXTURE",body,snapshot.snapshot_digest)) return false;
      snapshot.query_set.snapshot_digest=snapshot.snapshot_digest; return true;
   }
};

bool SWV5S5_TestLaunchDeleteRow(const string path,const string ns,const string domain,const string key)
{
   // Exact row fault injection in a TEST private clone; never runtime data.
   if(StringFind(path,"TEST_ONLY")<0) return false;
   const int db=DatabaseOpen(path,DATABASE_OPEN_READWRITE|DATABASE_OPEN_COMMON);
   if(db==INVALID_HANDLE) return false;
   const int statement=DatabasePrepare(db,"DELETE FROM swv5_authority_rows WHERE namespace_digest=?1 AND domain_key=?2 AND record_key=?3;");
   bool ok=statement!=INVALID_HANDLE;
   if(ok)
   {
      ok=DatabaseBind(statement,0,ns) && DatabaseBind(statement,1,domain) && DatabaseBind(statement,2,key);
      if(ok){ ResetLastError(); const bool step=DatabaseRead(statement); ok=step || GetLastError()==ERR_DATABASE_NO_MORE_DATA; }
      DatabaseFinalize(statement);
   }
   const int count=DatabasePrepare(db,"SELECT changes();"); int changed=0;
   ok=ok && count!=INVALID_HANDLE && DatabaseRead(count) && DatabaseColumnInteger(count,0,changed) && changed==1;
   if(count!=INVALID_HANDLE) DatabaseFinalize(count); DatabaseClose(db); return ok;
}

bool SWV5S5_TestLaunchCheckpoint(const string path)
{
   // File copying a live WAL database without checkpointing omits committed
   // authority rows. This TEST-only storage operation changes no authority.
   if(StringFind(path,"TEST_ONLY")<0) return false;
   const int db=DatabaseOpen(path,DATABASE_OPEN_READWRITE|DATABASE_OPEN_COMMON);
   if(db==INVALID_HANDLE) return false;
   const int stmt=DatabasePrepare(db,"PRAGMA wal_checkpoint(FULL);"); int busy=-1,frames=-1,complete=-2;
   const bool ok=stmt!=INVALID_HANDLE && DatabaseRead(stmt) && DatabaseColumnInteger(stmt,0,busy) &&
      DatabaseColumnInteger(stmt,1,frames) && DatabaseColumnInteger(stmt,2,complete) && busy==0 && frames==complete;
   if(stmt!=INVALID_HANDLE) DatabaseFinalize(stmt); DatabaseClose(db); return ok;
}

class SWV5S5_TestLaunchMissingAuthorityPort : public SWV5S5_MvpControlledDemoAuthorityPort
{
private:
   string m_test_path,m_ns,m_domain;
public:
   bool removed;
   SWV5S5_TestLaunchMissingAuthorityPort(const string path,const string ns,const string domain)
   { m_test_path=path; m_ns=ns; m_domain=domain; removed=false; }
   virtual bool CollectAdmissionSameEvent(void)
   {
      SWV5S5_AdmissionSnapshot admission;
      if(!SWV5S5_MvpControlledDemoAuthorityPort::CollectAdmissionSameEvent() || !ReadAdmissionCollections(admission)) return false;
      removed=SWV5S5_TestLaunchDeleteRow(m_test_path,m_ns,m_domain,
         SWV5S5_MvpAttemptPinKey(admission.collect_v2.submission_permit.permit.request_identity));
      return removed; // deletion AFTER actual Admission, before actual Claim
   }
};

#include "SW_V5_S5_MvpNativeQuoteAssertions.mqh"

class SWV5S5_TestAttendedLaunchSuite
{
private:
   SWV5S5_MvpD1Collector m_c;
   datetime m_setup_at;
   bool m_setup_ok;
   string m_ns;
   const string m_path;
   SWV5S5_MvpManualDemoSetupResult m_setup_result;
   SWV5S5_TestQuoteCalculationPlatform m_platform;
   SWV5S5_MvpRuntimeProfileObservation m_profile;
public:
   SWV5S5_TestAttendedLaunchSuite(void):m_path("mvp_attended_launch_TEST_ONLY_private.sqlite")
   { ZeroMemory(m_c); m_c.signature=1469598103934665603; m_setup_at=0; m_setup_ok=false; }
   bool Started(void) const { return m_setup_at>0; }
   void Start(void)
   {
      m_setup_at=TimeCurrent(); datetime at=0;
      const bool profile=m_platform.CaptureProfile(_Symbol,m_profile,at) && at==m_setup_at &&
         SWV5S5_MvpProfileMatches(m_profile,ACCOUNT_TRADE_MODE_DEMO);
      Print("LAUNCH_NATIVE_PROFILE|broker=",m_profile.broker_identity,"|server=",m_profile.server,"|mode=",(int)m_profile.account_mode,
         "|trade_mode=",m_profile.account_trade_mode,"|tester=",MQLInfoInteger(MQL_TESTER));
      SWV5S5_MvpD1Record(m_c,"LAUNCH-NATIVE-PROFILE",profile);
      if(!profile) return;
      // Only explicitly named TEST private artifacts are removed, never runtime data.
      FileDelete(m_path,FILE_COMMON); FileDelete(m_path+"-wal",FILE_COMMON); FileDelete(m_path+"-shm",FILE_COMMON);
      SWV5S5_MvpManualDemoSetupInput i; ZeroMemory(i);
      i.relative_store_path=m_path; i.expected_broker_identity=m_profile.broker_identity; i.expected_server=m_profile.server;
      i.expected_demo_account_login=m_profile.account_login; i.claimant_instance_id="TEST_ONLY_ATTENDED";
      i.claimant_process_fingerprint="TEST_ONLY_OFFLINE_PROCESS"; i.lease_duration_seconds=3600;
      i.platform_observation_id="TEST_ONLY_NATIVE_SETUP_TICK"; i.basket_id="TEST_ONLY_LAUNCH_BASKET";
      i.producer_epoch=1; i.producer_timeframe=(int)PERIOD_M15; i.producer_execution_mode=(int)SWV5_EXECUTION_EVERY_TICK;
      i.ingress_identity="";
      i.operator_invocation.operator_id="TEST_ONLY_OPERATOR"; i.operator_invocation.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
      i.operator_invocation.authentication_reference="TEST_ONLY_AUTH"; i.operator_invocation.authenticated_at=m_setup_at;
      SWV5_OwnershipKey key; ZeroMemory(key); key.broker_identity=m_profile.broker_identity; key.server=m_profile.server;
      key.account_login=m_profile.account_login; key.symbol=_Symbol; key.strategy_id=SWV5S5_MVP_PROFILE_ID; key.magic=SWV5_RUNTIME_STRATEGY_MAGIC;
      SWV5S5_MvpOwnershipNamespaceDigest(key,m_ns); i.persistence_namespace_identity=m_ns;
      SWV5S5_ProducerTrustAnchor anchor; ZeroMemory(anchor); anchor.issuer_identity="TEST_ONLY_TRUST_ISSUER";
      anchor.issuer_policy_id="TEST_ONLY_TRUST_POLICY"; anchor.trust_anchor_id="TEST_ONLY_TRUST_ANCHOR";
      anchor.current_authority_record_id="TEST_ONLY_TRUST_RECORD"; anchor.current_authority_generation=1;
      SWV5S5_MvpManualDemoSetup setup;
      m_setup_ok=setup.ProvisionOnCurrentSymbolTick(i,m_platform,anchor,m_setup_result);
      Print("LAUNCH_NATIVE_SETUP|",m_setup_result.stop_reason);
      SWV5S5_MvpD1Record(m_c,"LAUNCH-22-NATIVE-MANUAL-SETUP",m_setup_ok && !m_setup_result.safety_release_persisted);
      if(!m_setup_ok) return;
      SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpAuthorityRow row; bool found=false;
      const bool active=store.OpenReadOnly(m_path,m_ns) && store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",row,found) && found && row.state==(int)SWV5_HARD_KILL_ACTIVE;
      SWV5S5_MvpD1Record(m_c,"LAUNCH-22-ACTIVE-UNTIL-EXPLICIT",active);
   }
   bool ReadyToFinish(void) const { return m_setup_at>0 && TimeCurrent()>m_setup_at; }
   void Finish(void)
   {
      SWV5S5_MvpLeaseClockAuthority clock; SWV5S5_MvpLeaseClockObservation observed; SWV5S5_MvpAuthorityRow row;
      const bool fresh=m_setup_ok && clock.Configure(m_path,m_ns) &&
         clock.ObserveFromCurrentSymbolOnTick(_Symbol,"TEST_ONLY_NATIVE_LAUNCH_TICK",observed,row);
      SWV5S5_MvpD1Record(m_c,"LAUNCH-FRESH-NATIVE-CLOCK",fresh);
      SWV5_ContractValidationContext context; SWV5S5_MvpContextFromClock(observed,context);
      SWV5S5_MvpOperatorInvocation op; op.operator_id="TEST_ONLY_OPERATOR"; op.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
      op.authentication_reference="TEST_ONLY_AUTH"; op.authenticated_at=context.clock_time;
      SWV5S5_MvpAttendedAdministration admin; SWV5S5_MvpMt5BootstrapBrokerObserver broker; string reason;
      const SWV5_PersistenceNamespace scope=m_setup_result.reloaded_trust.persistence_namespace;
      const bool safety=fresh && admin.SafetyRelease(m_path,m_ns,op,context,scope,m_setup_result.account_namespace,
         m_setup_result.current_lease,broker,reason);
      Print("LAUNCH_NATIVE_SAFETY|",reason);
      SWV5S5_MvpD1Record(m_c,"LAUNCH-23-REAL-INDEPENDENT-RELEASE",safety);
      SWV5S5_F_BrokerPlatformAdapter adapter(SWV5S5_MVP_BROKER_READ_PATH,"TEST_ONLY_NATIVE_OBSERVER",SWV5S5_MVP_BROKER_SEQUENCE_AUTHORITY,1,1);
      SWV5S5_F_AdapterEnvironment environment; const bool environment_ok=adapter.ObserveEnvironment(_Symbol,environment);
      SWV5S5_F_ProfileScope profile; ZeroMemory(profile); SWV5S5_F_InitVersion(profile.contract_version);
      profile.persistence_namespace=scope; profile.account_namespace=m_setup_result.account_namespace;
      profile.broker_identity=m_profile.broker_identity; profile.server=m_profile.server; profile.account_login=m_profile.account_login;
      profile.symbol=_Symbol; profile.terminal_build=environment.terminal_build; profile.mql_build=environment.mql_build;
      profile.profile_id=SWV5S5_F_ADAPTER_PROFILE_ID; SWV5S5_F_DeriveProfileDigest(profile,profile.profile_digest);
      const bool governance=safety && environment_ok && admin.GovernanceAndInitialBasket(m_path,m_ns,op,context,
         m_setup_result.current_lease,profile,"TEST_ONLY_APPROVAL","TEST_ONLY_CORRELATION_EVIDENCE",broker,reason);
      Print("LAUNCH_NATIVE_GOVERNANCE|",reason);
      SWV5S5_MvpD1Record(m_c,"LAUNCH-24-EXPLICIT-GOVERNANCE-BASKET",governance);
      SWV5S5_MvpControlledDemoInvocation invocation; SWV5S5_MvpControlledDemoDefaults(invocation);
      invocation.relative_store_path=m_path; invocation.persistence_namespace_identity=m_ns;
      invocation.expected_broker_identity=m_profile.broker_identity; invocation.expected_server=m_profile.server;
      invocation.expected_demo_account_login=m_profile.account_login; invocation.source_head="TEST_ONLY_OFFLINE_SOURCE_NOT_DEPLOYABLE";
      MqlTick tick; SymbolInfoTick(_Symbol,tick); invocation.requested_price=tick.ask; invocation.protective_stop_price=tick.ask-2.0;
      SWV5S5_MvpMarketQuoteObservation event_quote;
      const bool captured=m_platform.CaptureMarketQuote(_Symbol,context.clock_time,event_quote);
      SWV5S5_MvpD1Record(m_c,"QUOTE-01",captured && event_quote.complete &&
         event_quote.bid==tick.bid && event_quote.ask==tick.ask && event_quote.tick_time_msc==tick.time_msc);
      SWV5S5_TestQuoteUnitNegatives(m_c,event_quote,context,m_platform);
      // Deliberately stale compatibility input. Native quote must win throughout
      // the actual physical graph, not just in the isolated helper.
      invocation.requested_price=tick.ask+10.0;
      SWV5S5_MvpAttendedAuthoritySeedBuilder builder; SWV5S5_MvpControlledDemoAuthoritySeed seed;
      SWV5S5_MvpSqliteAuthorityStore readonly;
      const bool seeded=governance && builder.LoadBase(invocation,observed,m_platform,environment,seed,reason) &&
         readonly.OpenReadOnly(m_path,m_ns) && builder.CompleteIncreasing(readonly,seed,reason);
      Print("LAUNCH_NATIVE_SEED|",reason);
      SWV5S5_MvpD1Record(m_c,"LAUNCH-13-PHYSICAL-SEED",seeded && seed.risk_observation.account_namespace.snapshot_epoch==1);
      SWV5S5_MvpBrokerEvidenceStore evidence; SWV5S5_MvpControlledDemoAuthorityPort port;
      const bool configured=seeded && port.Configure(m_path,m_ns,seed,GetPointer(m_platform),GetPointer(evidence));
      SWV5S5_MvpAuthorityRow before[],after[]; bool before_ok=readonly.ReadAllRows(before);
      SWV5S5_MvpD1NonMutatingBoundary boundary; SWV5S5_MvpControlledDemoRunner preflight;
      SWV5S5_MvpControlledDemoResult p1,p2;
      const bool first=configured && preflight.Run(invocation,port,boundary,p1);
      const bool second=configured && preflight.Run(invocation,port,boundary,p2);
      Print("LAUNCH_PREFLIGHT|",p1.stop_reason,"|",p2.stop_reason,"|",port.LastStage());
      SWV5S5_MvpD1Record(m_c,"LAUNCH-02-04-TWO-DEFAULT-PREFLIGHTS",first && second && boundary.calls==0);
      SWV5S5_MvpD1Record(m_c,"LAUNCH-03-ALL-ROWS-UNCHANGED",before_ok && readonly.ReadAllRows(after) && SWV5S5_LaunchRowsEqual(before,after));
      invocation.source_head=SWV5S5_MVP_ATTENDED_BUILT_SOURCE;
      invocation.evidence_relative_path="TEST_ONLY_attended_native_preflight.log";
      SWV5S5_MvpAttendedLaunch *native_host=new SWV5S5_MvpAttendedLaunch;
      const bool native_init=native_host!=NULL && native_host.Init(invocation,1);
      SWV5S5_MvpD1Record(m_c,"LAUNCH-01-NATIVE-GRAPH-INIT",native_init);
      if(native_init){ native_host.OnCurrentSymbolTick(); native_host.OnCurrentSymbolTick(); }
      SWV5S5_MvpD1Record(m_c,"LAUNCH-02-NATIVE-HOST-DEFAULT-READONLY",native_init && readonly.ReadAllRows(after) &&
         SWV5S5_LaunchRowsEqual(before,after));
      if(native_host!=NULL) delete native_host;
      invocation.mode=MODE_D1_BUY; invocation.armed_for_demo_submission=true;
      invocation.operator_confirmed_before_claim=true; invocation.execute_attended_once=true;
      SWV5S5_MvpAttendedLaunch *native_d1_unarmed=new SWV5S5_MvpAttendedLaunch;
      const bool signal_graph=native_d1_unarmed!=NULL && native_d1_unarmed.Init(invocation,1);
      SWV5S5_MvpD1Record(m_c,"LAUNCH-ACTUAL-ORCHESTRATOR-NATIVE-INIT",signal_graph);
      if(signal_graph){ native_d1_unarmed.OnCurrentSymbolTick(); native_d1_unarmed.OnCurrentSymbolTick(); }
      SWV5S5_MvpD1Record(m_c,"LAUNCH-NATIVE-SAVED-FLAGS-NO-ACK-NO-MUTATION",signal_graph &&
         readonly.ReadAllRows(after) && SWV5S5_LaunchRowsEqual(before,after));
      if(native_d1_unarmed!=NULL) delete native_d1_unarmed;
      SWV5_EngineInput engine; SWV5_DecisionResult decision;
      const bool decided=SWV5S5_LaunchDecision(context.clock_time,1,engine,decision);
      SWV5S5_MvpD1Record(m_c,"LAUNCH-14-ACTUAL-DECIDE-BUY",decided && decision.action==SWV5_ACTION_BUY);
      SWV5S5_MvpAttendedLaunchGate gate; bool armed=gate.ArmExplicitly(invocation);
      const bool consumed=armed && gate.ConsumeEligibleBuy(invocation,context.clock_time,engine,decision,seed.current_trust);
      SWV5S5_MvpD1Record(m_c,"LAUNCH-08-09-LATCH",consumed && gate.Consumed() && !gate.ConsumeEligibleBuy(invocation,context.clock_time,engine,decision,seed.current_trust));
      for(int direction=-1;direction<=0;direction++)
      {
         SWV5S5_LaunchDecision(context.clock_time,direction,engine,decision);
         SWV5S5_MvpAttendedLaunchGate negative; negative.ArmExplicitly(invocation);
         SWV5S5_MvpD1Record(m_c,direction==0 ? "LAUNCH-05-ACTUAL-WAIT" : "LAUNCH-06-ACTUAL-SELL",
            (direction==0 ? decision.action==SWV5_ACTION_WAIT : decision.action==SWV5_ACTION_SELL) &&
            !negative.ConsumeEligibleBuy(invocation,context.clock_time,engine,decision,seed.current_trust) && !negative.Consumed());
      }
      SWV5S5_LaunchDecision(context.clock_time,1,engine,decision);
      for(int n=0;n<3;n++)
      {
         SWV5_EngineInput bad_engine=engine; SWV5_DecisionResult bad_decision=decision;
         SWV5S5_ProducerTrustRecord bad_trust=seed.current_trust;
         if(n==0) bad_decision.header.valid=false;
         if(n==1) bad_engine.market.created_at--;
         if(n==2) bad_trust.valid_until=context.clock_time;
         SWV5S5_MvpAttendedLaunchGate negative; negative.ArmExplicitly(invocation);
         SWV5S5_MvpD1Record(m_c,"LAUNCH-07-"+IntegerToString(n),
            !negative.ConsumeEligibleBuy(invocation,context.clock_time,bad_engine,bad_decision,bad_trust) &&
            !negative.Consumed() && readonly.ReadAllRows(after) && SWV5S5_LaunchRowsEqual(before,after));
      }
      for(int n=0;n<3;n++)
      {
         SWV5S5_MvpControlledDemoInvocation missing=invocation;
         if(n==0) missing.armed_for_demo_submission=false;
         if(n==1) missing.operator_confirmed_before_claim=false;
         if(n==2) missing.execute_attended_once=false;
         SWV5S5_MvpAttendedLaunchGate negative;
         SWV5S5_MvpD1Record(m_c,"LAUNCH-"+IntegerToString(10+n),!negative.ArmExplicitly(missing) &&
            !negative.ConsumeEligibleBuy(missing,context.clock_time,engine,decision,seed.current_trust) && !negative.Consumed());
      }
      SWV5S5_MvpAttendedLaunchGate relaunched;
      SWV5S5_MvpD1Record(m_c,"LAUNCH-SAVED-FLAGS-CANNOT-REARM",!relaunched.SessionArmed() &&
         !relaunched.ConsumeEligibleBuy(invocation,context.clock_time,engine,decision,seed.current_trust));
      SWV5S5_MvpD1Record(m_c,"LAUNCH-SHA40-NOT-DIGEST64",SWV5S5_MvpGitSourceIdentity("3d0224e7a0d8bd42a0b9eec91e8bdf3f8c048dd7") &&
         !SWV5S5_MvpGitSourceIdentity("TEST_ONLY_OFFLINE_SOURCE_NOT_DEPLOYABLE"));

      // Missing Pin/Vector reaches the actual Claim guard after successful
      // Permit+Admission on exact copies of the real native setup state.
      seed.engine_input=engine; seed.decision=decision;
      const ulong filling=((environment.symbol_filling_mask & 1)!=0 ? 1 : 2);
      // Real dispatch/authority rejection, not only helper validation. Same
      // second/different millisecond also fails; never promote a cached quote.
      for(int n=0;n<4;n++)
      {
         const string clone="mvp_launch_TEST_ONLY_quote_"+IntegerToString(n)+".sqlite";
         FileDelete(clone,FILE_COMMON); FileDelete(clone+"-wal",FILE_COMMON); FileDelete(clone+"-shm",FILE_COMMON);
         const bool cloned=seeded && SWV5S5_TestLaunchCheckpoint(m_path) &&
            FileCopy(m_path,FILE_COMMON,clone,FILE_COMMON|FILE_REWRITE);
         SWV5S5_MvpMarketQuoteObservation bad=event_quote;
         if(n==0) bad.tick_time_msc--;
         if(n==1) bad.bid-=environment.point*10.0;
         if(n==2) bad.symbol="EURUSD";
         if(n==3) bad.complete=false;
         SWV5S5_MvpControlledDemoInvocation rejected_invocation=invocation; rejected_invocation.relative_store_path=clone;
         SWV5S5_MvpControlledDemoAuthorityPort rejected_port; SWV5S5_MvpBrokerEvidenceStore rejected_store;
         SWV5S5_MvpControlledDemoRunner rejected_runner; SWV5S5_MvpD1NonMutatingBoundary rejected_seam;
         SWV5S5_MvpControlledDemoAuthoritySeed rejected_seed; SWV5S5_MvpControlledDemoResult rejected_result;
         const bool accepted=cloned && SWV5S5_MvpDispatchAttended(rejected_invocation,observed,bad,environment,
            engine,decision,filling,m_platform,rejected_port,rejected_runner,rejected_seam,rejected_store,NULL,
            rejected_seed,rejected_result,reason);
         const bool quote_guard=(n==3 ? reason=="CURRENT_EVENT_QUOTE_REQUIRED" :
            rejected_port.LastStage()==(n==1 ? "PREFLIGHT_SYMBOL" : "PREFLIGHT_NATIVE_QUOTE"));
         SWV5S5_MvpD1Record(m_c,"QUOTE-EVENT-REJECT-"+IntegerToString(n),cloned && !accepted &&
            quote_guard && !rejected_result.claim_attempted && rejected_seam.calls==0 && rejected_runner.BrokerSubmissionCalls()==0);
      }
      for(int n=0;n<2;n++)
      {
         const string clone="mvp_launch_TEST_ONLY_missing_"+IntegerToString(n)+".sqlite";
         FileDelete(clone,FILE_COMMON); FileDelete(clone+"-wal",FILE_COMMON); FileDelete(clone+"-shm",FILE_COMMON);
         SWV5S5_MvpSqliteAuthorityStore cloned_readonly; SWV5S5_MvpAuthorityRow cloned_rows[];
         const bool cloned=seeded && SWV5S5_TestLaunchCheckpoint(m_path) &&
            FileCopy(m_path,FILE_COMMON,clone,FILE_COMMON|FILE_REWRITE) && cloned_readonly.OpenReadOnly(clone,m_ns) &&
            cloned_readonly.ReadAllRows(cloned_rows) && SWV5S5_LaunchRowsEqual(before,cloned_rows);
         SWV5S5_MvpD1Record(m_c,"LAUNCH-CLONE-COMPLETE-"+IntegerToString(n),cloned);
         cloned_readonly.Close();
         SWV5S5_MvpControlledDemoInvocation missing=invocation; missing.relative_store_path=clone;
         const string domain=(n==0 ? SWV5S5_MVP_DOMAIN_RECONCILIATION_PIN : SWV5S5_MVP_DOMAIN_RECONCILIATION);
         SWV5S5_TestLaunchMissingAuthorityPort negative_port(clone,m_ns,domain);
         SWV5S5_MvpBrokerEvidenceStore negative_store; SWV5S5_MvpControlledDemoRunner negative_runner;
         SWV5S5_MvpD1NonMutatingBoundary negative_boundary;
         SWV5S5_MvpControlledDemoResult denied; SWV5S5_MvpControlledDemoAuthoritySeed denied_seed;
         const bool ran=cloned && SWV5S5_MvpDispatchAttended(missing,observed,event_quote,environment,engine,decision,filling,
            m_platform,negative_port,negative_runner,negative_boundary,negative_store,NULL,denied_seed,denied,reason);
         Print("LAUNCH_MISSING_AUTHORITY|",n,"|",reason,"|removed=",negative_port.removed);
         SWV5S5_MvpD1Record(m_c,n==0 ? "LAUNCH-16-MISSING-PIN" : "LAUNCH-17-MISSING-VECTOR",
            negative_port.removed && !ran && denied.claim_attempted && !denied.claim_granted_now);
         SWV5S5_MvpD1Record(m_c,"LAUNCH-18-"+IntegerToString(n),negative_port.removed &&
            denied.admission_succeeded && denied.claim_attempted && !ran && negative_boundary.calls==0);
      }

      // Rehearsal uses the SAME dispatch as the native executable. The only
      // substituted effects are an explicitly TEST synchronous acknowledgement
      // and TEST Broker observations. No native submission is invoked.
      seed.engine_input=engine; seed.decision=decision;
      const bool d1_clock=gate.Consumed() && clock.ObserveFromCurrentSymbolOnTick(_Symbol,"TEST_ONLY_D1_AFTER_WRAPPER_LATCH",observed,row);
      SWV5S5_MvpD1PersistedEvidenceBoundary d1_seam;
      SWV5S5_MvpControlledDemoResult d1_result; SWV5S5_MvpControlledDemoAuthoritySeed d1_seed;
      SWV5S5_MvpControlledDemoRunner d1_runner; SWV5S5_MvpControlledDemoAuthorityPort d1_port;
      SWV5S5_MvpBrokerEvidenceStore d1_store; SWV5S5_MvpBrokerRecoveryReadPort native_callback(GetPointer(adapter));
      const bool d1=d1_clock && SWV5S5_MvpDispatchAttended(invocation,observed,event_quote,environment,engine,decision,filling,
         m_platform,d1_port,d1_runner,d1_seam,d1_store,GetPointer(native_callback),d1_seed,d1_result,reason);
      Print("LAUNCH_NATIVE_D1_SEAM|",reason,"|calls=",d1_seam.calls,"|SIMULATED_TRANSPORT_ONLY");
      SWV5S5_MvpD1Record(m_c,"LAUNCH-19-ONE-STRUCTURAL-SEAM",d1 && d1_seam.calls==1 && d1_result.claim_granted_now &&
         d1_result.adapter_invoked_same_event && d1_result.permit_committed && d1_result.admission_succeeded);
      SWV5S5_SubmissionAuthorityRecord claimed; bool found=false;
      const bool loaded=readonly.ReadAllRows(after) && SWV5S5_MvpLoadSubmissionAuthority(readonly,
         d1_result.request_correlation_id,d1_result.attempt_id,claimed,found) && found;
      SWV5S5_TestQuotePhysicalBindings(m_c,d1,loaded,event_quote,invocation,m_platform,d1_port,claimed,d1_seam.last_command,d1_seam.calls);
      SWV5S5_MvpAttemptReconciliationPinAuthority pins; SWV5S5_MvpAttemptReconciliationPin pin;
      SWV5S5_MvpAuthorityRow pin_row,vector_row; bool pin_found=false,vector_found=false;
      const bool pinned=loaded && pins.Configure(m_path,m_ns) && pins.Load(claimed.permit.request_identity,pin,pin_row,pin_found) && pin_found &&
         pins.LoadInitialVector(pin,vector_row,vector_found) && vector_found;
      SWV5S5_MvpD1Record(m_c,"LAUNCH-15-PHYSICAL-ORDERING",pinned &&
         claimed.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED && pin.expected_claim_id==claimed.invocation_claim_id &&
         vector_row.logical_revision==1 && pin.permit_digest==claimed.permit.permit_digest &&
         pin.admission_snapshot_digest==claimed.admission_snapshot_digest && pin_row.updated_at<=claimed.claimed_at);
      SWV5S5_MvpAuthorityRow gov_before,gov_after; bool gov_found=false;
      bool same_governance=false;
      for(int g=0;g<ArraySize(before);g++)
         if(before[g].domain_key==SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE)
         { gov_before=before[g]; same_governance=readonly.ReadRow(gov_before.domain_key,gov_before.record_key,gov_after,gov_found) &&
            gov_found && gov_after.store_revision==gov_before.store_revision && gov_after.payload_digest==gov_before.payload_digest; }
      SWV5S5_MvpD1Record(m_c,"LAUNCH-24-D1-CONSUMES-NO-GOVERNANCE-ISSUANCE",d1 && same_governance);

      MqlTradeTransaction tx; MqlTradeRequest rq; MqlTradeResult rs; ZeroMemory(tx); ZeroMemory(rq); ZeroMemory(rs);
      tx.type=TRADE_TRANSACTION_DEAL_ADD; tx.order=7001; tx.deal=8001; tx.position=9001; tx.symbol=_Symbol;
      tx.deal_type=DEAL_TYPE_BUY; tx.volume=invocation.requested_volume; tx.price=event_quote.ask;
      rq.magic=SWV5_RUNTIME_STRATEGY_MAGIC; rs.request_id=6001; rs.retcode=10009;
      const bool callback=d1 && d1_port.ObserveCallbackOnly(tx,rq,rs);
      SWV5S5_SubmissionAuthorityRecord after_callback; bool callback_found=false;
      const bool callback_unchanged=callback && SWV5S5_MvpLoadSubmissionAuthority(readonly,d1_result.request_correlation_id,
         d1_result.attempt_id,after_callback,callback_found) && callback_found &&
         after_callback.durable_record_digest==claimed.durable_record_digest;
      SWV5S5_MvpD1Record(m_c,"LAUNCH-20-21-NATIVE-CALLBACK-OBSERVATIONAL",callback_unchanged && d1_seam.calls==1);
      SWV5S5_MvpControlledDemoEvidence diagnostic; ZeroMemory(diagnostic);
      diagnostic.request_correlation_id=d1_result.request_correlation_id; diagnostic.attempt_id=d1_result.attempt_id;
      d1_port.FillRuntimeEvidence(diagnostic);
      SWV5S5_MvpD1Record(m_c,"LAUNCH-EVIDENCE-PHYSICAL-D1-CALLBACK",callback_unchanged && diagnostic.authority_readback_complete &&
         diagnostic.callback_count==1 && diagnostic.claim_id==claimed.invocation_claim_id && diagnostic.permit_digest==claimed.permit.permit_digest &&
         diagnostic.attempt_pin_digest==pin.pin_digest && diagnostic.reconciliation_vector_revision==1 && diagnostic.wire_digest!="");

      // New provider instances, new accepted native clock, physical reloads.
      // Empty Broker evidence FIRST; positive recovery SECOND, same exact Claim.
      for(int p=0;p<2;p++)
      {
         SWV5S5_MvpControlledDemoInvocation recovery=invocation; recovery.mode=MODE_D6_RECOVER;
         SWV5S5_MvpLeaseClockAuthority restarted_clock; SWV5S5_MvpLeaseClockObservation restarted;
         const bool current=restarted_clock.Configure(m_path,m_ns) && restarted_clock.ObserveFromCurrentSymbolOnTick(_Symbol,
            "TEST_ONLY_RESTART_D6_"+IntegerToString(p),restarted,row) && restarted.clock_sequence>observed.clock_sequence;
         SWV5S5_TestLaunchRecovery broker_fixture(p==1,event_quote.ask);
         SWV5S5_MvpBrokerEvidenceStore restarted_store; SWV5S5_MvpControlledDemoAuthorityPort restarted_port;
         SWV5S5_MvpControlledDemoRunner restarted_runner; SWV5S5_MvpD1NonMutatingBoundary forbidden_seam;
         SWV5S5_MvpControlledDemoResult recovered; SWV5S5_MvpControlledDemoAuthoritySeed recovered_seed;
         const bool recovered_ok=d1 && current && SWV5S5_MvpDispatchAttended(recovery,restarted,event_quote,environment,engine,decision,filling,
            m_platform,restarted_port,restarted_runner,forbidden_seam,restarted_store,GetPointer(broker_fixture),recovered_seed,recovered,reason);
         Print("LAUNCH_NATIVE_D6|positive=",p,"|",reason,"|queries=",broker_fixture.query_calls);
         ZeroMemory(diagnostic); diagnostic.request_correlation_id=d1_result.request_correlation_id; diagnostic.attempt_id=d1_result.attempt_id;
         restarted_port.FillRuntimeEvidence(diagnostic);
         SWV5S5_MvpD1Record(m_c,"LAUNCH-EVIDENCE-D6-"+IntegerToString(p),diagnostic.authority_readback_complete &&
            diagnostic.broker_observation_taken && diagnostic.execution_observation_taken && diagnostic.broker_observation_complete &&
            diagnostic.execution_observation_complete && diagnostic.execution_row_failures==0 && diagnostic.broker_row_failures==0 &&
            diagnostic.reconciliation_vector_revision==(p==0 ? 1 : 2) && diagnostic.callback_count==1);
         SWV5S5_SubmissionAuthorityRecord terminal; bool terminal_found=false;
         const bool terminal_loaded=SWV5S5_MvpLoadSubmissionAuthority(readonly,d1_result.request_correlation_id,
            d1_result.attempt_id,terminal,terminal_found) && terminal_found;
         SWV5S5_MvpD1Record(m_c,p==0 ? "LAUNCH-29-EMPTY-REMAINS-UNRESOLVED" : "LAUNCH-28-POSITIVE-EXACT-TERMINAL",
            current && terminal_loaded && broker_fixture.query_calls==1 &&
            (p==0 ? (!recovered_ok && terminal.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED &&
               recovered.stop_reason=="NEGATIVE_AUTHORITY_NOT_PROVEN_FOR_MVP_DEMO") :
               (recovered_ok && recovered.recovery_complete && terminal.state==SWV5S5_AUTHORITATIVE_SIDE_EFFECT_CONFIRMED)));
         SWV5S5_MvpD1Record(m_c,"LAUNCH-25-26-27-D6-"+IntegerToString(p),current && terminal_loaded &&
            !recovered.claim_granted_now && forbidden_seam.calls==0 && restarted_runner.BrokerSubmissionCalls()==0 &&
            recovered_seed.current_lease.store_revision==seed.current_lease.store_revision);
      }
      SWV5S5_MvpControlledDemoInvocation recovery_flags=invocation; recovery_flags.mode=MODE_D6_RECOVER;
      SWV5S5_MvpAttendedLaunchGate recovery_gate;
      const bool unacknowledged=!recovery_gate.ConsumeRecovery(recovery_flags);
      SWV5S5_MvpD1Record(m_c,"LAUNCH-D6-FRESH-ACK-NO-REARM",unacknowledged && recovery_gate.ArmExplicitly(recovery_flags) &&
         recovery_gate.ConsumeRecovery(recovery_flags) && !recovery_gate.ConsumeRecovery(recovery_flags));
      SWV5S5_MvpD1Record(m_c,"LAUNCH-NATIVE-ENUM-HEDGING",SWV5S5_F_NativeAccountMode(ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)==SWV5_ACCOUNT_MODE_HEDGING);
      SWV5S5_MvpD1Record(m_c,"LAUNCH-NATIVE-ENUM-NETTING",SWV5S5_F_NativeAccountMode(ACCOUNT_MARGIN_MODE_RETAIL_NETTING)==SWV5_ACCOUNT_MODE_NETTING);
      SWV5S5_MvpD1Record(m_c,"LAUNCH-NATIVE-ENUM-EXCHANGE",SWV5S5_F_NativeAccountMode(ACCOUNT_MARGIN_MODE_EXCHANGE)==SWV5_ACCOUNT_MODE_NETTING);
      SWV5S5_MvpD1Record(m_c,"LAUNCH-NATIVE-ENUM-UNKNOWN",SWV5S5_F_NativeAccountMode(999)==SWV5_ACCOUNT_MODE_UNKNOWN);
      Print("ATTENDED_LAUNCH_SUMMARY|total=",m_c.total,"|passed=",m_c.passed,"|failed=",m_c.failed,
         "|skipped=0|signature=",m_c.signature,"|broker_submission_calls=0");
      Print("ATTENDED_LAUNCH_SOURCE|compiled_source=",SWV5S5_MVP_ATTENDED_BUILT_SOURCE,
         "|clean_source=",SWV5S5_MVP_ATTENDED_CLEAN_SOURCE,"|TEST_ONLY_NON_MUTATING_REHEARSAL");
   }
};
#endif
