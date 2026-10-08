#property strict
// Explicit administrative action. NO BROKER ADAPTER / NO SUBMISSION.
#include "../../ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpAttendedAdministration.mqh"
#include "../../ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpAttendedSetupEvidence.mqh"
#include "SW_V5_S5_MvpAttendedBuild.generated.mqh"
enum MVP_SETUP_ACTION { SAFETY_RELEASE_ONLY=0,GOVERNANCE_AND_INITIAL_BASKET=1 };
input MVP_SETUP_ACTION setup_action=SAFETY_RELEASE_ONLY;
input bool execute_attended_setup_once=false;
input bool operator_confirmed_action=false;
input string expected_broker_identity="";
input string expected_server="";
input long expected_demo_account_login=0;
input string persistence_namespace_identity="";
input string authority_store_path="fusion_v5_mvp_demo_authority.sqlite";
input string operator_identity="";
input string operator_authentication_reference="";
input string governance_approval_reference="";
input string capability_proof_source_reference="";
bool g_ack=false,g_consumed=false;
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{ if(id==CHARTEVENT_KEYDOWN && lparam==65 && execute_attended_setup_once && operator_confirmed_action &&
     SWV5S5_MVP_ATTENDED_CLEAN_SOURCE && !g_consumed) g_ack=true; }
int OnInit(void){ g_ack=false; g_consumed=false; return INIT_SUCCEEDED; }
void OnTick(void)
{
   if(!g_ack || g_consumed || _Symbol!=SWV5S5_MVP_SYMBOL) return;
   SWV5S5_MvpMt5ReadOnlyPlatform platform; SWV5S5_MvpRuntimeProfileObservation observed; datetime at=0;
   if(!platform.CaptureProfile(SWV5S5_MVP_SYMBOL,observed,at) ||
      !SWV5S5_MvpProfileMatches(observed,ACCOUNT_TRADE_MODE_DEMO) ||
      observed.broker_identity!=expected_broker_identity || observed.server!=expected_server ||
      observed.account_login!=expected_demo_account_login || operator_identity=="" || operator_authentication_reference=="") return;
   g_consumed=true; g_ack=false; // before accepted clock/store writes; no retry
   SWV5S5_MvpLeaseClockAuthority clock; SWV5S5_MvpLeaseClockObservation accepted; SWV5S5_MvpAuthorityRow row;
   if(!clock.Configure(authority_store_path,persistence_namespace_identity) ||
      !clock.ObserveFromCurrentSymbolOnTick(_Symbol,"ADMIN/"+IntegerToString((long)GetMicrosecondCount()),accepted,row)) return;
   SWV5_ContractValidationContext context; ZeroMemory(context); SWV5S5_MvpInitProductionVersion(context.expected_version);
   context.clock_id=accepted.clock_id; context.clock_authority=accepted.clock_authority;
   context.clock_sequence=accepted.clock_sequence; context.evaluation_sequence=accepted.clock_sequence;
   context.clock_time=accepted.observed_at; context.price_tolerance=1.0e-7; context.volume_tolerance=1.0e-7;
   SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpLeasePublicationAuthority leases; SWV5_InstanceLease decoded,lease;
   bool found=false;
   if(!store.OpenReadOnly(authority_store_path,persistence_namespace_identity) ||
      !store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,row,found) || !found ||
      !SWV5S5_MvpDecodeOwnershipLeasePhysical(row.payload,decoded) ||
      !leases.LoadCurrentLease(store,decoded.fence.ownership_namespace,decoded.fence,lease,row)) return;
   SWV5S5_MvpAccountRiskAuthority accounts; SWV5S5_MvpAccountRiskAuthorityRecord account;
   if(!accounts.Load(store,account,row,found) || !found ||
      !accounts.ValidateCurrent(store,account.persistence_namespace,observed,account,row)) return;
   SWV5S5_MvpOperatorInvocation op; op.operator_id=operator_identity; op.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
   op.authentication_reference=operator_authentication_reference; op.authenticated_at=accepted.observed_at;
   SWV5S5_MvpAttendedAdministration admin; SWV5S5_MvpMt5BootstrapBrokerObserver broker; string reason; bool ok=false;
   if(setup_action==SAFETY_RELEASE_ONLY)
      ok=admin.SafetyRelease(authority_store_path,persistence_namespace_identity,op,context,account.persistence_namespace,account.account_namespace,lease,broker,reason);
   else
   {
      SWV5S5_F_ProfileScope profile; ZeroMemory(profile); SWV5S5_F_InitVersion(profile.contract_version);
      profile.persistence_namespace=account.persistence_namespace; profile.account_namespace=account.account_namespace;
      profile.broker_identity=observed.broker_identity; profile.server=observed.server; profile.account_login=observed.account_login;
      profile.symbol=_Symbol; profile.terminal_build=(int)TerminalInfoInteger(TERMINAL_BUILD); profile.mql_build=(int)__MQLBUILD__;
      profile.profile_id=SWV5S5_F_ADAPTER_PROFILE_ID;
      if(!SWV5S5_F_DeriveProfileDigest(profile,profile.profile_digest)) return;
      ok=admin.GovernanceAndInitialBasket(authority_store_path,persistence_namespace_identity,op,context,lease,profile,
         governance_approval_reference,capability_proof_source_reference,broker,reason);
   }
   Print("ATTENDED_ADMIN|",(ok ? "PASS" : "FAIL_CLOSED"),"|",reason,"|broker_submission_calls=0");
   SWV5S5_MvpWriteAttendedSetupEvidence(authority_store_path,persistence_namespace_identity,SWV5S5_MVP_ATTENDED_BUILT_SOURCE,
      (setup_action==SAFETY_RELEASE_ONLY ? "SAFETY_RELEASE" : "GOVERNANCE_AND_BASKET"),reason,ok,observed,true);
}
