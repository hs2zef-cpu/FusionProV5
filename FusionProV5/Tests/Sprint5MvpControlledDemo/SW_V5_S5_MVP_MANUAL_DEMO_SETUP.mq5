#property strict
#property tester_no_cache

// MANUAL CONTROLLED-DEMO SETUP LAUNCH SURFACE.
// This wrapper deliberately has no broker adapter include and no submission path.
// The typed setup package is executed through SWV5S5_MvpManualDemoSetup by an
// attended operator integration; blank/default values always fail closed.

#include "../../ExecutionLayer/ControlledDemo/SW_V5_S5_MvpManualDemoSetup.mqh"
#include "../../ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpAttendedSetupEvidence.mqh"
#include "SW_V5_S5_MvpAttendedBuild.generated.mqh"

input string InpOperatorId="";
input string InpAuthorityRole="";
input string InpAuthenticationReference="";
input string InpExpectedBrokerIdentity="";
input string InpExpectedServer="";
input long InpExpectedDemoAccountLogin=0;
input string InpPersistenceNamespaceIdentity="";
input string InpClaimantInstanceId="";
input string InpClaimantProcessFingerprint="";
input uint InpLeaseDurationSeconds=0;
input string InpPlatformObservationId="";
input string InpBasketId="";
input ulong InpProducerEpoch=0;
input int InpProducerTimeframe=0;
input int InpProducerExecutionMode=0;
input string InpIngressIdentity="";
input string InpTrustIssuerIdentity="";
input string InpTrustIssuerPolicyId="";
input string InpTrustAnchorId="";
input string InpTrustAuthorityRecordId="";
input ulong InpTrustAuthorityGeneration=0;
input long InpOperatorAuthenticatedAt=0;
input bool InpExecuteAttendedSetupOnce=false;

bool g_setup_armed=false;
bool g_setup_attempted=false;
SWV5S5_MvpManualDemoSetupInput g_setup_request;
SWV5S5_ProducerTrustAnchor g_trust_anchor;

int OnInit(void)
{
   ZeroMemory(g_setup_request); ZeroMemory(g_trust_anchor);
   g_setup_request.operator_invocation.operator_id=InpOperatorId;
   g_setup_request.operator_invocation.authority_role=InpAuthorityRole;
   g_setup_request.operator_invocation.authentication_reference=InpAuthenticationReference;
   g_setup_request.operator_invocation.authenticated_at=(datetime)InpOperatorAuthenticatedAt;
   g_setup_request.expected_broker_identity=InpExpectedBrokerIdentity;
   g_setup_request.expected_server=InpExpectedServer;
   g_setup_request.expected_demo_account_login=InpExpectedDemoAccountLogin;
   g_setup_request.persistence_namespace_identity=InpPersistenceNamespaceIdentity;
   g_setup_request.relative_store_path="fusion_v5_mvp_demo_authority.sqlite";
   g_setup_request.claimant_instance_id=InpClaimantInstanceId;
   g_setup_request.claimant_process_fingerprint=InpClaimantProcessFingerprint;
   g_setup_request.lease_duration_seconds=InpLeaseDurationSeconds;
   g_setup_request.platform_observation_id=InpPlatformObservationId;
   g_setup_request.basket_id=InpBasketId; g_setup_request.producer_epoch=InpProducerEpoch;
   g_setup_request.producer_timeframe=InpProducerTimeframe;
   g_setup_request.producer_execution_mode=InpProducerExecutionMode;
   g_setup_request.ingress_identity=InpIngressIdentity;
   g_trust_anchor.issuer_identity=InpTrustIssuerIdentity;
   g_trust_anchor.issuer_policy_id=InpTrustIssuerPolicyId;
   g_trust_anchor.trust_anchor_id=InpTrustAnchorId;
   g_trust_anchor.current_authority_record_id=InpTrustAuthorityRecordId;
   g_trust_anchor.current_authority_generation=InpTrustAuthorityGeneration;
   g_setup_armed=false; g_setup_attempted=false;
   Print("CONTROLLED_DEMO_SETUP|FRESH_ATTENDED_A_KEY_REQUIRED|NO_MUTATION");
   return INIT_SUCCEEDED;
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_KEYDOWN && lparam==65 && InpExecuteAttendedSetupOnce && SWV5S5_MVP_ATTENDED_CLEAN_SOURCE && !g_setup_attempted &&
      _Symbol==SWV5S5_MVP_SYMBOL && InpLeaseDurationSeconds>0 &&
      InpLeaseDurationSeconds<=SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS &&
      InpClaimantInstanceId!="" && InpClaimantProcessFingerprint!="" && InpPlatformObservationId!="") g_setup_armed=true;
}

void OnTick(void)
{
   if(!g_setup_armed || g_setup_attempted || _Symbol!=SWV5S5_MVP_SYMBOL) return;
   g_setup_attempted=true; // latch before any clock or ownership mutation
   g_setup_armed=false;
   g_setup_request.operator_invocation.authenticated_at=TimeCurrent(); // fresh attended event, never a saved timestamp
   SWV5S5_MvpMt5ReadOnlyPlatform platform; SWV5S5_MvpManualDemoSetup setup;
   SWV5S5_MvpManualDemoSetupResult result;
   const bool ok=setup.ProvisionOnCurrentSymbolTick(g_setup_request,platform,g_trust_anchor,result);
   SWV5S5_MvpRuntimeProfileObservation observed; datetime at=0;
   if(platform.CaptureProfile(_Symbol,observed,at))
      SWV5S5_MvpWriteAttendedSetupEvidence(g_setup_request.relative_store_path,g_setup_request.persistence_namespace_identity,
         SWV5S5_MVP_ATTENDED_BUILT_SOURCE,"MANUAL_SETUP",result.stop_reason,ok,observed,true);
   Print("CONTROLLED_DEMO_SETUP|",(ok ? "OWNERSHIP_AND_TRUST_READY" : "FAILED"),"|reason=",result.stop_reason);
}
