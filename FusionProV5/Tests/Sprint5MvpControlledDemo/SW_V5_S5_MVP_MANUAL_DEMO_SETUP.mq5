#property strict
#property script_show_inputs

// MANUAL CONTROLLED-DEMO SETUP LAUNCH SURFACE.
// This wrapper deliberately has no broker adapter include and no submission path.
// The typed setup package is executed through SWV5S5_MvpManualDemoSetup by an
// attended operator integration; blank/default values always fail closed.

#include "../../ExecutionLayer/ControlledDemo/SW_V5_S5_MvpManualDemoSetup.mqh"

input string InpOperatorId="";
input string InpAuthorityRole="";
input string InpAuthenticationReference="";
input string InpExpectedBrokerIdentity="";
input string InpExpectedServer="";
input long InpExpectedDemoAccountLogin=0;
input string InpPersistenceNamespaceIdentity="";

void OnStart(void)
{
   SWV5S5_MvpManualDemoSetupInput setup_request;
   ZeroMemory(setup_request);
   setup_request.operator_invocation.operator_id=InpOperatorId;
   setup_request.operator_invocation.authority_role=InpAuthorityRole;
   setup_request.operator_invocation.authentication_reference=InpAuthenticationReference;
   setup_request.operator_invocation.authenticated_at=TimeCurrent();
   setup_request.expected_broker_identity=InpExpectedBrokerIdentity;
   setup_request.expected_server=InpExpectedServer;
   setup_request.expected_demo_account_login=InpExpectedDemoAccountLogin;
   setup_request.persistence_namespace_identity=InpPersistenceNamespaceIdentity;
   setup_request.relative_store_path="fusion_v5_mvp_demo_authority.sqlite";
   if(!SWV5S5_MvpManualDemoSetupInputValid(setup_request,setup_request.operator_invocation.authenticated_at))
      Print("CONTROLLED_DEMO_SETUP|FAIL_CLOSED|EXPLICIT_TYPED_INPUT_REQUIRED");
   else
      Print("CONTROLLED_DEMO_SETUP|INPUT_ACCEPTED|ATTENDED_TYPED_AUTHORITY_PACKAGE_REQUIRED");
}
