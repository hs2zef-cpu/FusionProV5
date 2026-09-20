#property strict

// CONTROLLED DEMO RUNNER LAUNCH SURFACE.
// DEFAULT IS NON-MUTATING PREFLIGHT. No automated event handler calls Run().

#include "../../ExecutionLayer/ControlledDemo/SW_V5_S5_MvpControlledDemoRunner.mqh"

input SWV5S5_MvpControlledDemoMode runner_mode=MODE_PREFLIGHT;
input bool armed_for_demo_submission=false;
input bool operator_confirmed_before_claim=false;
input string expected_broker_identity="";
input string expected_server="";
input long expected_demo_account_login=0;
input string persistence_namespace_identity="";
input double requested_volume=0.01;
input double requested_price=0.0;
input double protective_stop_price=0.0;

SWV5S5_MvpControlledDemoRunner *g_runner=NULL;

int OnInit(void)
{
   g_runner=new SWV5S5_MvpControlledDemoRunner;
   if(g_runner==NULL) return INIT_FAILED;
   if((runner_mode==MODE_D1_BUY || runner_mode==MODE_D3_SELL) &&
      (!armed_for_demo_submission || !operator_confirmed_before_claim))
   {
      Print("CONTROLLED_DEMO_RUNNER|FAIL_CLOSED|SUBMISSION_MODE_NOT_EXPLICITLY_ARMED_AND_CONFIRMED");
      return INIT_FAILED;
   }
   Print("CONTROLLED_DEMO_RUNNER|HOST_READY|mode=",(int)runner_mode,
      "|armed=",armed_for_demo_submission,"|provider_binding_required_before_run");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_runner!=NULL) { delete g_runner; g_runner=NULL; }
}

void OnTick(void) { if(g_runner!=NULL) g_runner.OnTick(); }
void OnTimer(void) { if(g_runner!=NULL) g_runner.OnTimer(); }
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{ if(g_runner!=NULL) g_runner.OnChartEvent(); }

// Observational host boundary only. The accepted provider binding owns callback
// persistence and is supplied for an authorized attended run, never by defaults.
void OnTradeTransaction(const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   Print("CONTROLLED_DEMO_CALLBACK|OBSERVATION_NOT_BOUND|NO_AUTHORITY_NO_SUBMISSION");
}
