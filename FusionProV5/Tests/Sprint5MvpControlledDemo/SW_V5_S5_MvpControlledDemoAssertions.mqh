#ifndef SW_V5_S5_MVP_CONTROLLED_DEMO_ASSERTIONS_MQH
#define SW_V5_S5_MVP_CONTROLLED_DEMO_ASSERTIONS_MQH

// OFFLINE TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

#include "../../ExecutionLayer/ControlledDemo/SW_V5_S5_MvpControlledDemoRunner.mqh"

struct SWV5S5_ControlledDemoCollector
{
   uint total;
   uint passed;
   uint failed;
   ulong signature;
};

void SWV5S5_ControlledDemoRecord(SWV5S5_ControlledDemoCollector &c,const string id,const bool passed)
{
   c.total++; if(passed)c.passed++; else c.failed++;
   const string item=id+":"+(passed ? "PASS" : "FAIL");
   for(int i=0;i<StringLen(item);i++) c.signature=(c.signature^(ulong)StringGetCharacter(item,i))*1099511628211;
   Print("CONTROLLED_DEMO_TEST|",id,"|",(passed ? "PASS" : "FAIL"));
}

class SWV5S5_ControlledDemoFakeEvidenceStore : public ISWV5S5FBrokerEvidenceStore
{
public:
   virtual bool PersistSubmissionResult(const SWV5S5_F_AdapterSubmissionCommand &command,
                                        const SWV5S5_F_AdapterSyncResult &result) { return true; }
   virtual bool PersistCallbackEvidence(const SWV5S5_F_AdapterCallbackEvidence &evidence) { return true; }
   virtual bool ResolveCallbackBinding(const ulong order_ticket,const ulong deal_ticket,
                                       const ulong position_identifier,const ulong request_id_session_local,
                                       const ulong request_magic,SWV5S5_F_ReconciliationBinding &binding) { return false; }
   virtual bool LoadCallbackEvidence(const SWV5S5_F_ReconciliationBinding &binding,
                                     SWV5S5_F_AdapterCallbackEvidence &evidence[],uint &reported_total,
                                     bool &enumeration_complete,uint &row_read_failures)
   { ArrayResize(evidence,0); reported_total=0; enumeration_complete=true; row_read_failures=0; return true; }
   virtual bool ReserveBrokerQuerySequence(const SWV5S5_F_ProfileScope &profile,ulong &owner_query_sequence)
   { owner_query_sequence=1; return true; }
};

class SWV5S5_ControlledDemoFakePort : public ISWV5S5_MvpControlledDemoAuthorityPort
{
public:
   SWV5S5_MvpControlledDemoPreflightEvidence preflight;
   SWV5S5_MvpControlledDemoRecoveryEvidence recovery;
   bool collect_ok,prepare_ok,commit_ok,admission_ok,claim_ok,claim_granted;
   bool recovery_ok,callback_ok,build_ok;
   uint collect_calls,prepare_calls,commit_calls,admission_calls,claim_calls,recovery_calls,callback_calls,build_calls;
   SWV5S5_ControlledDemoFakeEvidenceStore *store;

   SWV5S5_ControlledDemoFakePort(void)
   {
      store=new SWV5S5_ControlledDemoFakeEvidenceStore;
      Reset();
   }
   ~SWV5S5_ControlledDemoFakePort(void) { if(store!=NULL) delete store; }

   void Reset(void)
   {
      ZeroMemory(preflight); ZeroMemory(recovery);
      preflight.profile_exact=true; preflight.demo_account=true; preflight.usd_account=true;
      preflight.hedging_account=true; preflight.symbol_exact=true; preflight.connected=true;
      preflight.permissions_observed=true; preflight.store_schema_valid=true; preflight.genesis_valid=true;
      preflight.ownership_current=true; preflight.trust_complete=true; preflight.trust_current_unexpired=true;
      preflight.safety_allows_execution=true; preflight.broker_observation_complete=true;
      preflight.execution_observation_complete=true; preflight.no_position=true; preflight.no_active_order=true;
      preflight.no_unresolved_submission=true; preflight.no_competing_operation=true;
      preflight.symbol_specification_fresh=true; preflight.units_valid=true; preflight.margin_valid=true;
      preflight.basket_risk_valid=true; preflight.risk_inputs_valid=true; preflight.protective_stop_valid=true;
      preflight.prospective_permit_preparable=true; preflight.d1_terminal=true;
      preflight.manual_cleanup_independently_observed=true; preflight.independent_request_identity=true;
      preflight.request_correlation_id="CORR-NEW"; preflight.attempt_id="ATT-NEW";
      recovery.store_schema_valid=true; recovery.ownership_reloaded_from_sqlite=true;
      recovery.ownership_current=true;
      recovery.exact_unresolved_claim_found=true; recovery.complete_claim_reloaded_from_sqlite=true;
      recovery.claim_granted_now=false; recovery.broker_observation_complete=true;
      recovery.execution_observation_complete=true; recovery.reconciliation_evaluated=true;
      recovery.reconciliation_published=true; recovery.exact_record_terminalized=true;
      recovery.terminal_readback_verified=true; recovery.request_correlation_id="CORR-D1";
      recovery.attempt_id="ATT-D1";
      collect_ok=true; prepare_ok=true; commit_ok=true; admission_ok=true; claim_ok=true;
      claim_granted=true; recovery_ok=true; callback_ok=true; build_ok=true;
      collect_calls=0; prepare_calls=0; commit_calls=0; admission_calls=0; claim_calls=0;
      recovery_calls=0; callback_calls=0; build_calls=0;
   }

   virtual bool CollectPreflight(const SWV5S5_MvpControlledDemoInvocation &invocation,const int direction,
                                 SWV5S5_MvpControlledDemoPreflightEvidence &evidence)
   { collect_calls++; evidence=preflight; return collect_ok; }
   virtual bool PreparePermitSemantics(void) { prepare_calls++; return prepare_ok; }
   virtual bool CommitPermitPhysical(void) { commit_calls++; return commit_ok; }
   virtual bool CollectAdmissionSameEvent(void) { admission_calls++; return admission_ok; }
   virtual bool ClaimPhysicalNow(bool &granted_now)
   { claim_calls++; granted_now=claim_granted; return claim_ok; }
   virtual bool ReloadAndReconcileD6(SWV5S5_MvpControlledDemoRecoveryEvidence &evidence)
   { recovery_calls++; evidence=recovery; return recovery_ok; }
   virtual bool ObserveCallbackOnly(const MqlTradeTransaction &transaction,const MqlTradeRequest &request,
                                    const MqlTradeResult &result)
   { callback_calls++; return callback_ok; }
   virtual bool BuildAdapterCommand(SWV5S5_F_AdapterSubmissionCommand &command,
                                    ISWV5S5FBrokerEvidenceStore* &evidence_store)
   { build_calls++; ZeroMemory(command); evidence_store=store; return build_ok; }
};

class SWV5S5_ControlledDemoFakeBoundary : public ISWV5S5_MvpControlledDemoSubmissionBoundary
{
public:
   uint calls;
   bool return_value;
   SWV5S5_ControlledDemoFakeBoundary(void) { calls=0; return_value=true; }
   virtual bool SubmitExactlyOnce(SWV5S5_F_AdapterSubmissionCommand &command,
                                  ISWV5S5FBrokerEvidenceStore &evidence_store,
                                  SWV5S5_F_AdapterSyncResult &captured)
   {
      calls++; ZeroMemory(captured);
      // Non-mutating seam: a successful structural invocation is not a broker call.
      captured.invocation_attempted=false; captured.retry_allowed=false;
      return return_value;
   }
};

void SWV5S5_ControlledDemoInvocation(SWV5S5_MvpControlledDemoInvocation &invocation,
                                     const SWV5S5_MvpControlledDemoMode mode,const bool armed=false)
{
   SWV5S5_MvpControlledDemoDefaults(invocation);
   invocation.mode=mode; invocation.armed_for_demo_submission=armed;
   invocation.operator_confirmed_before_claim=armed;
   invocation.expected_broker_identity="APPROVED-DEMO-BROKER";
   invocation.expected_server="APPROVED-DEMO-SERVER";
   invocation.expected_demo_account_login=123456;
   invocation.persistence_namespace_identity="1111111111111111111111111111111111111111111111111111111111111111";
   invocation.relative_store_path="controlled_demo_test.sqlite";
   invocation.source_head="29874ae0b3770ffaf89fbd512b49ae417b026bf1";
   invocation.evidence_relative_path="FusionProV5\\ControlledDemoEvidence\\offline-test.log";
   invocation.requested_volume=0.01; invocation.requested_price=3500.0;
   invocation.protective_stop_price=(mode==MODE_D3_SELL ? 3501.0 : 3499.0);
}

bool SWV5S5_ControlledDemoRunWithPort(SWV5S5_MvpControlledDemoInvocation &invocation,
                                      SWV5S5_ControlledDemoFakePort &port,
                                      SWV5S5_ControlledDemoFakeBoundary &boundary,
                                      SWV5S5_MvpControlledDemoRunner &runner,
                                      SWV5S5_MvpControlledDemoResult &result)
{ return runner.Run(invocation,port,boundary,result); }

void SWV5S5_RunControlledDemoAssertions(SWV5S5_ControlledDemoCollector &c)
{
   ZeroMemory(c); c.signature=1469598103934665603;
   SWV5S5_MvpControlledDemoInvocation invocation; SWV5S5_MvpControlledDemoDefaults(invocation);
   SWV5S5_ControlledDemoRecord(c,"CD-01-DEFAULT-PREFLIGHT",invocation.mode==MODE_PREFLIGHT);

   SWV5S5_ControlledDemoFakePort port; SWV5S5_ControlledDemoFakeBoundary boundary;
   SWV5S5_MvpControlledDemoRunner runner; SWV5S5_MvpControlledDemoResult result;
   SWV5S5_ControlledDemoInvocation(invocation,MODE_PREFLIGHT);
   bool ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,runner,result);
   SWV5S5_ControlledDemoRecord(c,"CD-02-PREFLIGHT-ZERO-SUBMISSION",ok&&result.broker_submission_calls==0&&boundary.calls==0);
   SWV5S5_ControlledDemoRecord(c,"CD-05-PREFLIGHT-NO-CLAIM",ok&&port.claim_calls==0&&port.commit_calls==0);

   port.Reset(); boundary.calls=0; SWV5S5_MvpControlledDemoRunner r3; SWV5S5_ControlledDemoInvocation(invocation,MODE_D1_BUY,false);
   ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r3,result);
   SWV5S5_ControlledDemoRecord(c,"CD-03-UNARMED-D1-NO-SIDE-EFFECT",!ok&&port.commit_calls==0&&port.claim_calls==0&&boundary.calls==0);
   port.Reset(); SWV5S5_MvpControlledDemoRunner r4; SWV5S5_ControlledDemoInvocation(invocation,MODE_D3_SELL,false);
   ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r4,result);
   SWV5S5_ControlledDemoRecord(c,"CD-04-UNARMED-D3-NO-SIDE-EFFECT",!ok&&port.commit_calls==0&&port.claim_calls==0&&boundary.calls==0);

#define CD_PREFLIGHT_FAIL(id,field) { port.Reset(); port.preflight.field=false; SWV5S5_MvpControlledDemoRunner x; SWV5S5_ControlledDemoInvocation(invocation,MODE_PREFLIGHT); ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,x,result); SWV5S5_ControlledDemoRecord(c,id,!ok&&port.claim_calls==0&&boundary.calls==0); }
   boundary.calls=0;
   CD_PREFLIGHT_FAIL("CD-06-STORE-SCHEMA-BLOCKS",store_schema_valid)
   CD_PREFLIGHT_FAIL("CD-07-TRUST-RELOAD-BLOCKS",trust_complete)
   CD_PREFLIGHT_FAIL("CD-08-EXPIRED-TRUST-BLOCKS",trust_current_unexpired)
   CD_PREFLIGHT_FAIL("CD-09-WRONG-DEMO-ACCOUNT-BLOCKS",profile_exact)
   CD_PREFLIGHT_FAIL("CD-10-WRONG-SERVER-BLOCKS",profile_exact)
   CD_PREFLIGHT_FAIL("CD-11-REAL-ACCOUNT-BLOCKS",demo_account)
   CD_PREFLIGHT_FAIL("CD-12-NON-USD-BLOCKS",usd_account)
   CD_PREFLIGHT_FAIL("CD-13-NON-HEDGING-BLOCKS",hedging_account)
   CD_PREFLIGHT_FAIL("CD-14-WRONG-SYMBOL-BLOCKS",symbol_exact)
   CD_PREFLIGHT_FAIL("CD-15-POSITION-BLOCKS",no_position)
   CD_PREFLIGHT_FAIL("CD-16-ORDER-BLOCKS",no_active_order)
   CD_PREFLIGHT_FAIL("CD-17-UNRESOLVED-BLOCKS",no_unresolved_submission)
   CD_PREFLIGHT_FAIL("CD-19-RISK-DENIAL-BLOCKS",risk_inputs_valid)
#undef CD_PREFLIGHT_FAIL

   port.Reset(); SWV5S5_MvpControlledDemoRunner r18; SWV5S5_ControlledDemoInvocation(invocation,MODE_D1_BUY,true);
   invocation.protective_stop_price=invocation.requested_price;
   ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r18,result);
   SWV5S5_ControlledDemoRecord(c,"CD-18-INVALID-SL-BLOCKS",!ok&&port.collect_calls==0&&port.claim_calls==0);

   port.Reset(); port.prepare_ok=false; SWV5S5_MvpControlledDemoRunner r20; SWV5S5_ControlledDemoInvocation(invocation,MODE_D1_BUY,true);
   ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r20,result);
   SWV5S5_ControlledDemoRecord(c,"CD-20-PERMIT-PREPARE-BLOCKS-BEFORE-CLAIM",!ok&&port.claim_calls==0&&boundary.calls==0);
   port.Reset(); port.commit_ok=false; SWV5S5_MvpControlledDemoRunner r21;
   ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r21,result);
   SWV5S5_ControlledDemoRecord(c,"CD-21-PERMIT-COMMIT-BLOCKS-CLAIM",!ok&&port.claim_calls==0&&boundary.calls==0);
   port.Reset(); port.admission_ok=false; SWV5S5_MvpControlledDemoRunner r22;
   ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r22,result);
   SWV5S5_ControlledDemoRecord(c,"CD-22-ADMISSION-BLOCKS-CLAIM",!ok&&port.claim_calls==0&&boundary.calls==0);
   port.Reset(); port.claim_granted=false; SWV5S5_MvpControlledDemoRunner r23;
   ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r23,result);
   SWV5S5_ControlledDemoRecord(c,"CD-23-STALE-CLAIM-ZERO-SUBMISSION",!ok&&port.claim_calls==1&&boundary.calls==0);

   port.Reset(); boundary.calls=0; SWV5S5_MvpControlledDemoRunner r24;
   ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r24,result);
   SWV5S5_MvpControlledDemoResult second; const bool second_ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r24,second);
   SWV5S5_ControlledDemoRecord(c,"CD-24-HOST-LATCH-ONE-SHOT",ok&&!second_ok&&boundary.calls==1&&second.stop_reason=="HOST_ONE_SHOT_ALREADY_CONSUMED");
   SWV5S5_ControlledDemoRecord(c,"CD-25-ONTICK-CANNOT-SUBMIT",!r24.OnTick()&&boundary.calls==1);
   SWV5S5_ControlledDemoRecord(c,"CD-26-ONTIMER-CANNOT-SUBMIT",!r24.OnTimer()&&boundary.calls==1);

   MqlTradeTransaction tx; MqlTradeRequest req; MqlTradeResult res;
   ZeroMemory(tx); ZeroMemory(req); ZeroMemory(res); const uint permit_before=port.commit_calls,claim_before=port.claim_calls,boundary_before=boundary.calls;
   const bool callback_observed=r24.OnTradeTransaction(tx,req,res,port);
   SWV5S5_ControlledDemoRecord(c,"CD-27-CALLBACK-CANNOT-SUBMIT",callback_observed&&boundary.calls==boundary_before);
   SWV5S5_ControlledDemoRecord(c,"CD-28-CALLBACK-CANNOT-CLAIM",port.claim_calls==claim_before);
   SWV5S5_ControlledDemoRecord(c,"CD-29-CALLBACK-CANNOT-PERMIT",port.commit_calls==permit_before);

   port.Reset(); SWV5S5_MvpControlledDemoRunner r30; SWV5S5_ControlledDemoInvocation(invocation,MODE_D6_RECOVER);
   port.recovery.claim_granted_now=true; ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r30,result);
   SWV5S5_ControlledDemoRecord(c,"CD-30-RESTART-NEVER-RECONSTRUCTS-GRANT",!ok&&boundary.calls==boundary_before);
   port.Reset(); SWV5S5_MvpControlledDemoRunner r31; ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r31,result);
   SWV5S5_ControlledDemoRecord(c,"CD-31-D6-ZERO-SUBMISSION",ok&&result.broker_submission_calls==0&&port.claim_calls==0&&port.commit_calls==0);
   port.Reset(); port.recovery.complete_claim_reloaded_from_sqlite=false; SWV5S5_MvpControlledDemoRunner r32;
   ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r32,result);
   SWV5S5_ControlledDemoRecord(c,"CD-32-D6-REQUIRES-COMPLETE-SQLITE-RELOAD",!ok);
   port.Reset(); port.recovery.broker_observation_complete=false; SWV5S5_MvpControlledDemoRunner r33;
   ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r33,result);
   SWV5S5_ControlledDemoRecord(c,"CD-33-D6-INCOMPLETE-BROKER-UNRESOLVED",!ok);
   port.Reset(); port.recovery.execution_observation_complete=false; SWV5S5_MvpControlledDemoRunner r34;
   ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r34,result);
   SWV5S5_ControlledDemoRecord(c,"CD-34-D6-INCOMPLETE-EXECUTION-UNRESOLVED",!ok);
   port.Reset(); SWV5S5_MvpControlledDemoRunner r35;
   ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r35,result);
   SWV5S5_ControlledDemoRecord(c,"CD-35-D6-POSITIVE-TERMINALIZES-EXACT",ok&&result.recovery_complete&&result.request_correlation_id=="CORR-D1");

   port.Reset(); boundary.calls=0; SWV5S5_MvpControlledDemoRunner r36; SWV5S5_ControlledDemoInvocation(invocation,MODE_D3_SELL,true);
   ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r36,result);
   const bool serialized_same_event=result.claim_granted_now && result.adapter_invoked_same_event &&
      result.host_latch_set_before_claim;
   SWV5S5_ControlledDemoRecord(c,"CD-36-TERMINAL-D1-ALLOWS-INDEPENDENT-D3",ok&&boundary.calls==1&&result.attempt_id=="ATT-NEW");
   port.Reset(); port.preflight.d1_terminal=false; SWV5S5_MvpControlledDemoRunner r37;
   ok=SWV5S5_ControlledDemoRunWithPort(invocation,port,boundary,r37,result);
   SWV5S5_ControlledDemoRecord(c,"CD-37-UNRESOLVED-D1-BLOCKS-D3",!ok&&port.claim_calls==0);

   SWV5S5_MvpManualDemoSetupInput setup; ZeroMemory(setup);
   SWV5S5_ControlledDemoRecord(c,"CD-38-SETUP-BLANK-IDENTITY-FAILS-CLOSED",!SWV5S5_MvpManualDemoSetupInputValid(setup,D'2026.09.19 12:00:00'));
   SWV5S5_ControlledDemoRecord(c,"CD-39-RUNNER-SEAM-NON-MUTATING",r36.BrokerSubmissionCalls()==0&&boundary.calls==1);
   SWV5S5_ControlledDemoRecord(c,"CD-40-NO-RETRY-AFTER-BOUNDARY",boundary.calls==1&&r36.HostLatchConsumed());
   SWV5S5_ControlledDemoRecord(c,"CD-41-CLAIM-TO-BOUNDARY-SAME-EVENT",serialized_same_event);
}

#endif // SW_V5_S5_MVP_CONTROLLED_DEMO_ASSERTIONS_MQH
