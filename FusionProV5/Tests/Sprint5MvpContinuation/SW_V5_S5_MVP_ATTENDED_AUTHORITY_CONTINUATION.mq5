#property strict
// Dedicated attended Demo administrator. NO PREFLIGHT / NO EXECUTION GRAPH.
#include "../../ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh"
#include "../Sprint5MvpControlledDemo/SW_V5_S5_MvpAttendedBuild.generated.mqh"
input bool execute_attended_continuation_once=false;
input bool operator_confirmed_continuation=false;
input string expected_broker_identity="";
input string expected_server="";
input long expected_demo_account_login=0;
input string persistence_namespace_identity="";
input string authority_store_path="";
input string attended_continuation_id="";
input string claimant_instance_id="";
input string claimant_process_fingerprint="";
input datetime claimant_started_at=0;
input uint continuation_lease_duration_seconds=3600;
input string operator_identity="";
input string operator_authentication_reference="";
input string trust_anchor_id="";
input string governance_approval_reference="";
input string capability_proof_source_reference="";
bool g_ack=false,g_consumed=false;
bool g_finalization_dispatched=false;
SWV5S5_MvpContinuationInput g_input;
SWV5S5_MvpOperatorInvocation g_operator;
SWV5S5_MvpAttendedContinuation continuation;
bool PublishAcceptedContinuationTick(SWV5S5_MvpLeaseClockAuthority &clock,
   SWV5S5_MvpLeaseClockObservation &accepted,SWV5S5_MvpAuthorityRow &row)
{
   MqlTick tick;const datetime now=TimeCurrent();
   return _Symbol==SWV5S5_MVP_SYMBOL && _Period==PERIOD_M15 && SymbolInfoTick(_Symbol,tick) &&
      tick.time==now && tick.time_msc/1000==(long)now &&
      clock.Configure(authority_store_path,persistence_namespace_identity) &&
      clock.ObserveFromCurrentSymbolOnTick(_Symbol,"CONTINUATION/"+IntegerToString((long)GetMicrosecondCount()),accepted,row);
}
void Report(const SWV5S5_MvpContinuationResult &r)
{
   Print("ATTENDED_CONTINUATION|",(r.accepted ? "PASS" : "PARTIAL_CONTINUATION"),"|",r.reason,
      "|stage=",r.stage,"|already_complete=",r.already_complete,"|expiry=",(long)r.effective_expiry,
      "|latch_generation=",r.final_latch_generation,"|release_generation=",r.release_generation,
      "|broker_submission_calls=0|transport_attempted=false|claim_granted_now=false");
}
int OnInit()
{
   g_ack=false; g_consumed=false;g_finalization_dispatched=false;ZeroMemory(g_operator);ZeroMemory(g_input);
   g_input.path=authority_store_path; g_input.namespace_digest=persistence_namespace_identity;
   g_input.continuation_id=attended_continuation_id; g_input.approval_reference=governance_approval_reference;
   g_input.proof_reference=capability_proof_source_reference; g_input.trust_anchor_id=trust_anchor_id;
   g_input.lease_seconds=continuation_lease_duration_seconds;
   g_input.configured_owner.key.account_login=expected_demo_account_login;
   g_input.configured_owner.key.broker_identity=expected_broker_identity; g_input.configured_owner.key.server=expected_server;
   g_input.configured_owner.key.symbol=SWV5S5_MVP_SYMBOL; g_input.configured_owner.key.strategy_id=SWV5S5_MVP_PROFILE_ID;
   g_input.configured_owner.key.magic=SWV5_RUNTIME_STRATEGY_MAGIC;
   g_input.configured_owner.instance_id=claimant_instance_id; g_input.configured_owner.process_fingerprint=claimant_process_fingerprint;
   g_input.configured_owner.started_at=claimant_started_at;
   if(!SWV5S5_MVP_ATTENDED_CLEAN_SOURCE || _Symbol!=SWV5S5_MVP_SYMBOL || _Period!=PERIOD_M15) return INIT_FAILED;
   SWV5S5_MvpContinuationResult completed;
   if(continuation.ReadCompletedOnly(g_input,completed)) {g_consumed=true; Report(completed);}
   return INIT_SUCCEEDED;
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_KEYDOWN && lparam==65 && !g_consumed && !g_ack &&
      execute_attended_continuation_once && operator_confirmed_continuation && SWV5S5_MVP_ATTENDED_CLEAN_SOURCE) g_ack=true;
}
void OnTick()
{
   if(continuation.AwaitingFinalization())
   {
      if(g_finalization_dispatched || _Symbol!=SWV5S5_MVP_SYMBOL || _Period!=PERIOD_M15 ||
         TimeCurrent()<continuation.FinalizationNotBefore())return;
      g_finalization_dispatched=true; // one final event, not an automatic retry
      // Diagnostic time may DENY an expired A, never grant final authority.
      if(!SWV5S5_MvpOperatorInvocationValid(g_operator,TimeCurrent()))
      {Print("ATTENDED_CONTINUATION|PARTIAL_CONTINUATION|ATTENDED_WINDOW_EXPIRED_BEFORE_FINAL_PUBLICATION|NO_RETRY");return;}
      SWV5S5_MvpLeaseClockAuthority final_clock;SWV5S5_MvpLeaseClockObservation accepted;
      SWV5S5_MvpAuthorityRow row;SWV5S5_MvpContinuationResult result;
      SWV5S5_MvpMt5ReadOnlyPlatform platform;SWV5S5_MvpMt5BootstrapBrokerObserver broker;
      if(!PublishAcceptedContinuationTick(final_clock,accepted,row))
      {Print("ATTENDED_CONTINUATION|PARTIAL_CONTINUATION|FINAL_CLOCK_PUBLICATION_FAILED|NO_RETRY");return;}
      continuation.Run(g_input,g_operator,final_clock,platform,broker,result);Report(result);return;
   }
   if(!g_ack || g_consumed || _Symbol!=SWV5S5_MVP_SYMBOL || _Period!=PERIOD_M15) return;
   g_consumed=true; g_ack=false; // BEFORE the first durable mutation. No retry.
   SWV5S5_MvpMt5ReadOnlyPlatform platform; SWV5S5_MvpRuntimeProfileObservation profile; datetime at=0;
   if(!platform.CaptureProfile(_Symbol,profile,at) || !SWV5S5_MvpProfileMatches(profile,ACCOUNT_TRADE_MODE_DEMO) ||
      profile.broker_identity!=expected_broker_identity || profile.server!=expected_server ||
      profile.account_login!=expected_demo_account_login)
   {Print("ATTENDED_CONTINUATION|FAIL_CLOSED|PROFILE_MISMATCH|broker_submission_calls=0"); return;}
   SWV5S5_MvpContinuationResult structural,result;
   SWV5S5_MvpSqliteAuthorityStore prior_store;SWV5S5_MvpAuthorityRow prior_rows[];
   if(!continuation.ClassifyStoredPreState(g_input,platform,structural) ||
      !prior_store.OpenReadOnly(authority_store_path,persistence_namespace_identity) || !prior_store.ReadAllRows(prior_rows))
   {Print("ATTENDED_CONTINUATION|FAIL_CLOSED|STRUCTURAL_PRESTATE|",structural.reason,"|NO_AUTHORITY_GRANT");return;}
   prior_store.Close();
   SWV5S5_MvpLeaseClockAuthority clock; SWV5S5_MvpLeaseClockObservation accepted; SWV5S5_MvpAuthorityRow row;
   if(!PublishAcceptedContinuationTick(clock,accepted,row))
   {Print("ATTENDED_CONTINUATION|PARTIAL_CONTINUATION|CLOCK_WRITE_OR_READBACK_FAILED|NO_RETRY"); return;}
   SWV5S5_MvpLeaseClockObservation fresh;
   if(!clock.CurrentFreshObservation(fresh) || !continuation.ClassifyClockOnlyHistoricalPartial(g_input,platform,prior_rows,structural))
   {Print("ATTENDED_CONTINUATION|PARTIAL_CONTINUATION|NEW_EVENT_OR_EXACT_CLOCK_ONLY_BINDING_FAILED|NO_RETRY");return;}
   SWV5S5_MvpOperatorInvocation op; op.operator_id=operator_identity; op.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
   op.authentication_reference=operator_authentication_reference; op.authenticated_at=accepted.observed_at;
   g_operator=op; // original A identity/time, never reconstructed or retimestamped
   g_input.acknowledged=true; SWV5S5_MvpMt5BootstrapBrokerObserver broker;
   continuation.Run(g_input,op,clock,platform,broker,result);
   if(!result.accepted) result.partial_continuation=true; // accepted clock was already persisted
   Report(result); // STOP: never dispatch PREFLIGHT/D1/D6.
}
