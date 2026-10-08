#property strict

// ATTENDED DEMO LAUNCH ONLY. Compiling is not authorization to run D1.

#include "../../ExecutionLayer/ControlledDemo/SW_V5_S5_MvpAttendedLaunch.mqh"
#include "SW_V5_S5_MvpAttendedBuild.generated.mqh"

input SWV5S5_MvpControlledDemoMode runner_mode=MODE_PREFLIGHT;
input bool armed_for_demo_submission=false;
input bool operator_confirmed_before_claim=false;
input bool execute_attended_once=false;
input string expected_broker_identity="";
input string expected_server="";
input long expected_demo_account_login=0;
input string persistence_namespace_identity="";
input string authority_store_path="fusion_v5_mvp_demo_authority.sqlite";
input double requested_volume=0.01;
input double requested_price=0.0;
input double protective_stop_price=0.0;
input double optional_take_profit_price=0.0;
input ulong requested_filling_mode=1;

SWV5S5_MvpAttendedLaunch *g_launch=NULL;

int OnInit(void)
{
   SWV5S5_MvpControlledDemoInvocation invocation; SWV5S5_MvpControlledDemoDefaults(invocation);
   invocation.mode=runner_mode; invocation.armed_for_demo_submission=armed_for_demo_submission;
   invocation.operator_confirmed_before_claim=operator_confirmed_before_claim;
   invocation.execute_attended_once=execute_attended_once;
   invocation.expected_broker_identity=expected_broker_identity; invocation.expected_server=expected_server;
   invocation.expected_demo_account_login=expected_demo_account_login;
   invocation.persistence_namespace_identity=persistence_namespace_identity; invocation.relative_store_path=authority_store_path;
   invocation.requested_volume=requested_volume; invocation.requested_price=requested_price;
   invocation.protective_stop_price=protective_stop_price; invocation.optional_take_profit_price=optional_take_profit_price;
   invocation.source_head=SWV5S5_MVP_ATTENDED_BUILT_SOURCE;
   invocation.evidence_relative_path="fusion_v5_mvp_attended_evidence.log";
   if(runner_mode!=MODE_PREFLIGHT && !SWV5S5_MVP_ATTENDED_CLEAN_SOURCE)
   { Print("ATTENDED_LAUNCH|NONIMMUTABLE_BUILD_FAIL_CLOSED"); return INIT_FAILED; }
   g_launch=new SWV5S5_MvpAttendedLaunch;
   if(g_launch==NULL || !g_launch.Init(invocation,requested_filling_mode)) return INIT_FAILED;
   Print("ATTENDED_LAUNCH|BOUND|DEFAULT_READ_ONLY|D1_REQUIRES_FRESH_A_KEY_ACKNOWLEDGEMENT");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_launch!=NULL) { delete g_launch; g_launch=NULL; }
}

void OnTick(void) { if(g_launch!=NULL) g_launch.OnCurrentSymbolTick(); }
void OnTimer(void) { } // Never dispatches preparation, Claim, recovery or submission.
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   // A key event only acknowledges this fresh session; it NEVER calls Run.
   if(id==CHARTEVENT_KEYDOWN && lparam==65 && g_launch!=NULL)
      Print("ATTENDED_LAUNCH|SESSION_ARM_ACK|",g_launch.ArmSession());
}

// Observational host boundary only. The accepted provider binding owns callback
// persistence and is supplied for an authorized attended run, never by defaults.
void OnTradeTransaction(const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(g_launch!=NULL) g_launch.ObserveCallbackOnly(transaction,request,result);
}
