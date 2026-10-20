#property strict
#property description "TEST ONLY - narrow cold-restart RESUME_CLOCK diagnostic - NO EXECUTION"
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER MUTATION / NO AUTHORITY GRANT.
// Only one ordinary clock event may be published, into a new donor-derived
// TEST_ONLY copy. The exact production-draft classifier is compiled without
// its mutating tail. No full-suite assertions/PREFLIGHT/launcher are included.
#include "../../ExecutionLayer/Contracts/SW_V5_S5_Canonical.mqh"
#include "SW_V5_S5_MvpContinuationTestIsolation.mqh"
#include "SW_V5_S5_MvpResumeClockDiagnosticGate.mqh"
#define SWV5S5_TEST_ONLY_RESUME_CLOCK_CLASSIFIER
#include "../../ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh"

input string explicit_test_only_marker="";
input string diagnostic_target_relative_path="";
input string diagnostic_run_id="";
input bool operator_confirmed_diagnostic_only=false;
const string diagnostic_donor="TEST_ONLY_MVP_CONTINUATION_3f39a13e0c314df2bcd8452ae9de5e4c.sqlite";
const string diagnostic_donor_sha="bec62e7435d29d5511a41bf85c74ae443994c5804b3a9574af90d861fe674ef6";
const string diagnostic_namespace="58408af3c3381470aa50161762e4f1102eec5d214448495a79d732cd31d90d8c";
bool diagnostic_ack=false,diagnostic_consumed=false;

class ResumeClockDiagnosticNeverBroker : public ISWV5S5MvpBootstrapBrokerObserver
{
public:
   virtual bool Capture(const string symbol,SWV5S5_MvpBootstrapBrokerObservation &observation)
   {test_forbidden_transport_calls++;ZeroMemory(observation);return false;}
};

bool DiagnosticNoTargetArtifacts()
{
   return !FileIsExist(diagnostic_target_relative_path,FILE_COMMON) &&
      !FileIsExist(diagnostic_target_relative_path+"-wal",FILE_COMMON) &&
      !FileIsExist(diagnostic_target_relative_path+"-shm",FILE_COMMON) &&
      !FileIsExist(diagnostic_target_relative_path+".before.rows",FILE_COMMON) &&
      !FileIsExist(diagnostic_target_relative_path+".after.rows",FILE_COMMON) &&
      !FileIsExist(diagnostic_target_relative_path+".classified.rows",FILE_COMMON);
}
bool DiagnosticGate()
{
   if(!ResumeClockDiagnosticInputsValid(explicit_test_only_marker,diagnostic_target_relative_path,diagnostic_run_id) ||
      !operator_confirmed_diagnostic_only || !DiagnosticNoTargetArtifacts() ||
      _Symbol!="XAUUSD" || _Period!=PERIOD_M15 || MQLInfoInteger(MQL_TESTER))return false;
   string digest;
   if(!SWV5S5_TestContinuationFileSha(diagnostic_donor,digest) || digest!=diagnostic_donor_sha)return false;
   if(FileIsExist(diagnostic_donor+"-wal",FILE_COMMON))
   {
      const int h=FileOpen(diagnostic_donor+"-wal",FILE_READ|FILE_BIN|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(h==INVALID_HANDLE)return false;
      const ulong bytes=FileSize(h);FileClose(h);if(bytes!=0)return false;
   }
   SWV5S5_MvpMt5ReadOnlyPlatform platform;SWV5S5_MvpRuntimeProfileObservation profile;datetime at;
   return platform.CaptureProfile(_Symbol,profile,at) && SWV5S5_MvpProfileMatches(profile,ACCOUNT_TRADE_MODE_DEMO) &&
      profile.broker_identity=="Exness Technologies Ltd" && profile.server=="Exness-MT5Trial6" &&
      profile.account_login%10000==6169;
}
bool DiagnosticSnapshot(const string path,SWV5S5_MvpAuthorityRow &rows[])
{
   SWV5S5_MvpSqliteAuthorityStore store;
   const bool ok=store.OpenReadOnly(path,diagnostic_namespace) && store.ReadAllRows(rows);
   store.Close();return ok;
}
bool DiagnosticSaveRows(const string suffix,const SWV5S5_MvpAuthorityRow &rows[])
{
   // Lossless UTF-8 canonical row export; includes complete payloads, not a
   // truncated Print. Diagnostic artifacts only, never authority-store rows.
   string body;uchar bytes[];
   const string path=diagnostic_target_relative_path+suffix;
   if(FileIsExist(path,FILE_COMMON) || !SWV5S5_MvpContinuationRowsPayload(rows,body))return false;
   const int count=StringToCharArray(body,bytes,0,WHOLE_ARRAY,CP_UTF8)-1;
   if(count<=0)return false;
   const int h=FileOpen(path,FILE_WRITE|FILE_BIN|FILE_COMMON);
   if(h==INVALID_HANDLE)return false;
   const uint written=FileWriteArray(h,bytes,0,count);FileFlush(h);FileClose(h);
   string digest;
   if(written!=(uint)count || !SWV5S5_TestContinuationFileSha(path,digest))return false;
   Print("RESUME_CLOCK_DIAGNOSTIC|SNAPSHOT|path=",TerminalInfoString(TERMINAL_COMMONDATA_PATH),
      "\\Files\\",path,"|sha256=",digest,"|row_count=",ArraySize(rows));return true;
}
bool DiagnosticSameRows(const SWV5S5_MvpAuthorityRow &a[],const SWV5S5_MvpAuthorityRow &b[])
{
   if(ArraySize(a)!=ArraySize(b))return false;
   for(int n=0;n<ArraySize(a);n++)if(!SWV5S5_MvpContinuationRowExact(a[n],b[n]))return false;
   return true;
}
bool DiagnosticRequiredRows(const SWV5S5_MvpAuthorityRow &rows[])
{
   string domains[]={SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_DOMAIN_PRODUCER_TRUST,
      SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE,SWV5S5_MVP_DOMAIN_HARD_KILL,SWV5S5_MVP_DOMAIN_ACCOUNT_RISK,
      SWV5S5_MVP_DOMAIN_BASKET,SWV5S5_MVP_DOMAIN_REQUEST_SET};
   string keys[]={SWV5S5_MVP_OWNERSHIP_CLOCK_KEY,SWV5S5_MVP_OWNERSHIP_KEY,"CURRENT","CURRENT","CURRENT","CURRENT",
      "CURRENT",SWV5S5_MVP_REQUEST_SET_KEY};
   for(int d=0;d<ArraySize(domains);d++)
   {
      int matches=0;
      for(int x=0;x<ArraySize(rows);x++)if(rows[x].domain_key==domains[d] && rows[x].record_key==keys[d])matches++;
      if(matches!=1)return false;
   }
   // Exact production closed inventory rejects operational rows (GENESIS
   // infrastructure rows remain allowed). Require empty RequestSet as well.
   SWV5S5_MvpSqliteAuthorityStore store;SWV5S5_MvpAuthorityRow physical[];string reason;
   if(!store.OpenReadOnly(diagnostic_target_relative_path,diagnostic_namespace) ||
      !SWV5S5_MvpContinuationInventoryAllowedDiagnostic(store,physical,reason))return false;
   store.Close();
   for(int x=0;x<ArraySize(rows);x++)if(rows[x].domain_key==SWV5S5_MVP_DOMAIN_REQUEST_SET && rows[x].record_key==SWV5S5_MVP_REQUEST_SET_KEY)
   {
      SWV5S5_MvpRequestSetPhysicalState requests;
      if(!SWV5S5_MvpDecodeRequestSetState(rows[x].payload,requests) || ArraySize(requests.view.requests)!=0 ||
         requests.view.header.request_count!=0)return false;
   }
   Print("RESUME_CLOCK_DIAGNOSTIC|PRESTATE|operational_execution_rows=0|request_count=0");return true;
}
void DiagnosticPrintClock(const string label,const SWV5S5_MvpLeaseClockObservation &c,const SWV5S5_MvpAuthorityRow &row)
{
   Print("RESUME_CLOCK_DIAGNOSTIC|CLOCK|",label,"|clock_id=",c.clock_id,"|clock_authority=",(int)c.clock_authority,
      "|observed_at=",(long)c.observed_at,"|clock_sequence=",c.clock_sequence,"|platform_observation_id=",c.platform_observation_id,
      "|logical_revision=",row.logical_revision,"|payload_digest=",row.payload_digest,"|store_revision=",row.store_revision);
}
bool DiagnosticPublishThenDestroy()
{
   // Local publication object is closed and DESTROYED on return. No accepted
   // observation or event-local state is returned to the restart classifier.
   SWV5S5_MvpLeaseClockAuthority publisher;SWV5S5_MvpLeaseClockObservation accepted;SWV5S5_MvpAuthorityRow committed;
   const bool published=publisher.Configure(diagnostic_target_relative_path,diagnostic_namespace) &&
      publisher.ObserveFromCurrentSymbolOnTick(_Symbol,"TEST_ONLY/RESUME_CLOCK/"+diagnostic_run_id,accepted,committed);
   publisher.Close();
   if(!published)return false;
   Print("RESUME_CLOCK_DIAGNOSTIC|INJECTION_FIRED|INTERRUPT_AFTER_CLOCK_PUBLICATION");return true;
}
bool DiagnosticClassifyCold()
{
   // All authority/store/classifier objects below are newly constructed. Load
   // stored clock only; DO NOT publish, reconstruct freshness, or reuse rows.
   SWV5S5_MvpLeaseClockAuthority clock;SWV5S5_MvpLeaseClockObservation stored;SWV5S5_MvpAuthorityRow clock_row,lease_row;
   SWV5S5_MvpSqliteAuthorityStore reopened;SWV5_InstanceLease lease;bool found=false;
   if(!clock.ConfigureReadOnly(diagnostic_target_relative_path,diagnostic_namespace) || !clock.LoadStored(stored,clock_row,found) || !found ||
      !reopened.OpenReadOnly(diagnostic_target_relative_path,diagnostic_namespace) ||
      !reopened.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,lease_row,found) || !found ||
      !SWV5S5_MvpDecodeOwnershipLeasePhysical(lease_row.payload,lease))return false;
   DiagnosticPrintClock("REOPENED_FROM_DISK",stored,clock_row);
   SWV5S5_MvpContinuationInput input_state;ZeroMemory(input_state);
   input_state.path=diagnostic_target_relative_path;input_state.namespace_digest=diagnostic_namespace;
   input_state.continuation_id="TEST_ONLY_RESUME_CLOCK_"+diagnostic_run_id;input_state.acknowledged=true;
   input_state.configured_owner=lease.fence.owner;input_state.lease_seconds=3600;
   input_state.approval_reference="FUSION-V5-DEMO-MVP-GOVERNANCE-APPROVED";
   input_state.proof_reference="PHASE-F-EVIDENCE-01B8B8F5819C804967461946D3481CF0D4E77767";
   input_state.trust_anchor_id="FUSION-V5-DEMO-TRUST-ANCHOR-V1";
   SWV5S5_MvpOperatorInvocation op;op.operator_id="FUSION_DEMO_ATTENDED_OPERATOR_01";op.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
   op.authentication_reference="TEST_ONLY_DIAGNOSTIC_A_NO_EXECUTION";op.authenticated_at=TimeCurrent();
   SWV5S5_MvpAttendedContinuation classifier;SWV5S5_MvpMt5ReadOnlyPlatform platform;ResumeClockDiagnosticNeverBroker broker;
   SWV5S5_MvpContinuationResult result;ZeroMemory(result);
   Print("RESUME_CLOCK_DIAGNOSTIC|REOPEN|new_objects=true|freshness_reconstructed=false|second_publication=false");
   const bool accepted=classifier.Run(input_state,op,clock,platform,broker,result);
   clock.Close();reopened.Close();
   if(result.reason=="")return false;
   Print("RESUME_CLOCK_DIAGNOSTIC|CLASSIFIER|accepted=",accepted ? "true" : "false","|reason=",result.reason,
      "|stage=",result.stage,"|authority_granted=false");
   if(accepted)Print("RESUME_CLOCK_DIAGNOSTIC|OUTCOME|RESUME_CLOCK ORIGINAL FAILURE NOT REPRODUCED");
   else if(result.reason=="PRESTATE_CLOCK_BASELINE_EQUALITY_FAILED")
      Print("RESUME_CLOCK_DIAGNOSTIC|OUTCOME|RESUME_CLOCK FAILURE CONFIRMED AS CLOCK-INFRASTRUCTURE BASELINE REJECTION");
   else Print("RESUME_CLOCK_DIAGNOSTIC|OUTCOME|RESUME_CLOCK FAILURE IS NOT CLOCK-INFRASTRUCTURE BASELINE REJECTION",
      "|reason=",result.reason,"|cold_restart_result_only=true|prior_native_failure_not_inferred=true");
   return test_forbidden_transport_calls==0;
}
bool DiagnosticRunOnce()
{
   if(!DiagnosticGate())return false;
   MqlTick tick;const datetime now=TimeCurrent();
   if(!SymbolInfoTick(_Symbol,tick) || tick.time!=now || tick.time_msc/1000!=(long)tick.time || tick.bid<=0 || tick.ask<tick.bid)return false;
   SWV5S5_MvpMt5ReadOnlyPlatform platform;SWV5S5_MvpRuntimeProfileObservation profile;datetime at;
   if(!platform.CaptureProfile(_Symbol,profile,at) || at!=now)return false;
   // Exact same Demo login is proven from donor ownership, not suffix alone.
   SWV5S5_MvpSqliteAuthorityStore donor;SWV5S5_MvpAuthorityRow lease_row;SWV5_InstanceLease lease;bool found=false;
   if(!donor.OpenReadOnly(diagnostic_donor,diagnostic_namespace) ||
      !donor.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,lease_row,found) || !found ||
      !SWV5S5_MvpDecodeOwnershipLeasePhysical(lease_row.payload,lease) || profile.account_login!=lease.fence.owner.key.account_login)return false;
   donor.Close();
   // A latch was consumed by OnTick BEFORE any copy creation/durable mutation.
   if(!DiagnosticNoTargetArtifacts() || !FileCopy(diagnostic_donor,FILE_COMMON,diagnostic_target_relative_path,FILE_COMMON))return false;
   string digest;
   if(!SWV5S5_TestContinuationFileSha(diagnostic_target_relative_path,digest) || digest!=diagnostic_donor_sha)return false;
   Print("RESUME_CLOCK_DIAGNOSTIC|START|TEST_ONLY|tick_time_msc=",tick.time_msc,"|native_time=",(long)now,
      "|terminal_build=",TerminalInfoInteger(TERMINAL_BUILD),"|mql_build=",__MQLBUILD__,"|target=",diagnostic_target_relative_path);
   SWV5S5_MvpAuthorityRow before[],after[],classified[];SWV5S5_MvpLeaseClockObservation old_clock,new_clock;
   int clock_index=-1;
   if(!DiagnosticSnapshot(diagnostic_target_relative_path,before) || !DiagnosticRequiredRows(before) || !DiagnosticSaveRows(".before.rows",before))return false;
   for(int x=0;x<ArraySize(before);x++)if(before[x].domain_key==SWV5S5_MVP_DOMAIN_OWNERSHIP && before[x].record_key==SWV5S5_MVP_OWNERSHIP_CLOCK_KEY)clock_index=x;
   if(clock_index<0 || !SWV5S5_MvpDecodeLeaseClockPayload(before[clock_index].payload,old_clock))return false;
   DiagnosticPrintClock("BEFORE",old_clock,before[clock_index]);
   if(!DiagnosticPublishThenDestroy() || !DiagnosticSnapshot(diagnostic_target_relative_path,after) || ArraySize(before)!=ArraySize(after))return false;
   for(int x=0;x<ArraySize(before);x++)
   {
      if(before[x].domain_key!=after[x].domain_key || before[x].record_key!=after[x].record_key)return false;
      if(x!=clock_index && !SWV5S5_MvpContinuationRowExact(before[x],after[x]))return false;
   }
   SWV5S5_MvpLeaseClockAuthority verifier;SWV5S5_MvpAuthorityRow verified_row;bool clock_found=false;
   if(!verifier.ConfigureReadOnly(diagnostic_target_relative_path,diagnostic_namespace) ||
      !verifier.LoadStored(new_clock,verified_row,clock_found) || !clock_found ||
      !SWV5S5_MvpContinuationRowExact(verified_row,after[clock_index]) ||
      new_clock.clock_id!=old_clock.clock_id || new_clock.clock_authority!=old_clock.clock_authority ||
      new_clock.clock_sequence!=old_clock.clock_sequence+1 || verified_row.logical_revision!=before[clock_index].logical_revision+1 ||
      new_clock.observed_at<=old_clock.observed_at || new_clock.observed_at!=now ||
      new_clock.platform_observation_id==old_clock.platform_observation_id ||
      SWV5S5_MvpContinuationRowExact(before[clock_index],after[clock_index]))return false;
   verifier.Close();
   DiagnosticPrintClock("AFTER",new_clock,after[clock_index]);
   Print("RESUME_CLOCK_DIAGNOSTIC|CLOCK_ONLY_PROVEN|changed_rows=1|non_clock_rows_exact=true|sequence_delta=1");
   if(!DiagnosticSaveRows(".after.rows",after) || !DiagnosticClassifyCold() ||
      !DiagnosticSnapshot(diagnostic_target_relative_path,classified) || !DiagnosticSameRows(after,classified) ||
      !DiagnosticSaveRows(".classified.rows",classified) ||
      !SWV5S5_TestContinuationFileSha(diagnostic_donor,digest) || digest!=diagnostic_donor_sha)return false;
   Print("RESUME_CLOCK_DIAGNOSTIC|CLASSIFIER_STORE_UNCHANGED|true");return test_forbidden_transport_calls==0;
}
int OnInit()
{
   diagnostic_ack=false;diagnostic_consumed=false;
   if(!DiagnosticGate()){Print("RESUME_CLOCK_DIAGNOSTIC|FAIL|PRE_RUN_GATE|NO_WRITE");return INIT_FAILED;}
   Print("RESUME_CLOCK_DIAGNOSTIC|READY|TEST_ONLY|WAIT_FOR_A_ONCE|target=",diagnostic_target_relative_path);return INIT_SUCCEEDED;
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_KEYDOWN && lparam==65 && !diagnostic_consumed && !diagnostic_ack && DiagnosticGate())diagnostic_ack=true;
}
void OnTick()
{
   if(diagnostic_consumed || !diagnostic_ack)return;
   diagnostic_consumed=true;diagnostic_ack=false; // consumed BEFORE first write
   const bool valid=DiagnosticRunOnce();
   Print("RESUME_CLOCK_DIAGNOSTIC|",valid ? "COMPLETE" : "FAIL","|fixture_valid=",valid ? "true" : "false",
      "|forbidden_transport_calls=",test_forbidden_transport_calls,"|NO_RETRY|NO_AUTHORITY_GRANT");
}
