#ifndef SW_V5_S5_MVP_MANUAL_DEMO_SETUP_MQH
#define SW_V5_S5_MVP_MANUAL_DEMO_SETUP_MQH

// CONTROLLED DEMO MVP — MANUAL SETUP ONLY.
// This utility owns no trading intent, Permit, Claim, broker adapter, or submission path.
// It is manually invoked to establish the already-approved durable authorities.

#include "../RuntimeAuthority/SW_V5_S5_MvpManualProvisioningAuthorities.mqh"

struct SWV5S5_MvpManualDemoSetupInput
{
   string relative_store_path;
   string persistence_namespace_identity;
   string expected_broker_identity;
   string expected_server;
   long expected_demo_account_login;
   SWV5S5_MvpOperatorInvocation operator_invocation;
};

struct SWV5S5_MvpManualDemoSetupResult
{
   bool profile_matched;
   bool genesis_ready;
   bool ownership_published;
   bool trust_persisted;
   bool trust_reloaded_complete;
   bool zero_state_verified;
   bool safety_release_persisted;
   string stop_reason;
   SWV5S5_ProducerTrustRecord reloaded_trust;
   SWV5S5_ProducerTrustAnchor reloaded_anchor;
};

bool SWV5S5_MvpManualDemoSetupInputValid(const SWV5S5_MvpManualDemoSetupInput &setup_input,
                                         const datetime now)
{
   return setup_input.relative_store_path!="" && setup_input.persistence_namespace_identity!="" &&
      setup_input.expected_broker_identity!="" && setup_input.expected_server!="" &&
      setup_input.expected_demo_account_login>0 &&
      SWV5S5_MvpOperatorInvocationValid(setup_input.operator_invocation,now);
}

class SWV5S5_MvpManualDemoSetup
{
public:
   // Genesis, ownership publication, and Producer Trust are deliberately one
   // attended setup operation. All authority semantics remain in the accepted providers.
   bool Provision(const SWV5S5_MvpManualDemoSetupInput &setup_input,
                  const datetime now,
                  ISWV5S5MvpReadOnlyPlatform &platform,
                  const SWV5_InstanceLease &accepted_current_lease,
                  const SWV5S5_ProducerTrustAnchor &trust_anchor,
                  const SWV5S5_ProducerTrustScope &trust_scope,
                  SWV5S5_MvpManualDemoSetupResult &result)
   {
      ZeroMemory(result);
      if(!SWV5S5_MvpManualDemoSetupInputValid(setup_input,now))
      { result.stop_reason="SETUP_INPUT_INVALID"; return false; }

      SWV5S5_MvpRuntimeProfileObservation observed;
      datetime observed_at=0;
      if(!platform.CaptureProfile(SWV5S5_MVP_SYMBOL,observed,observed_at) ||
         observed_at!=now || !SWV5S5_MvpProfileMatches(observed,ACCOUNT_TRADE_MODE_DEMO) ||
         observed.broker_identity!=setup_input.expected_broker_identity ||
         observed.server!=setup_input.expected_server ||
         observed.account_login!=setup_input.expected_demo_account_login)
      { result.stop_reason="SETUP_PROFILE_MISMATCH"; return false; }
      result.profile_matched=true;

      SWV5S5_MvpManualGenesisProvisioner genesis;
      bool ready=false;
      if(!genesis.Configure(setup_input.relative_store_path,setup_input.persistence_namespace_identity) ||
         !genesis.Begin(setup_input.operator_invocation,now) ||
         !genesis.InitializeAllDomains(now) ||
         !genesis.FinalizeReadyForReconciliation(now) ||
         !genesis.IsReadyForReconciliation(ready) || !ready)
      { result.stop_reason="SETUP_GENESIS_FAILED"; return false; }
      result.genesis_ready=true;

      SWV5S5_MvpSqliteAuthorityStore store;
      SWV5S5_MvpLeasePublicationAuthority lease_authority;
      SWV5S5_MvpAuthorityRow ownership_row;
      if(!store.Open(setup_input.relative_store_path,setup_input.persistence_namespace_identity) ||
         !lease_authority.Publish(store,accepted_current_lease,0,"","",0,now,ownership_row))
      { result.stop_reason="SETUP_OWNERSHIP_PUBLICATION_FAILED"; return false; }
      result.ownership_published=true;

      SWV5S5_MvpManualProducerTrustProvisioner trust;
      SWV5S5_ProducerTrustRecord persisted;
      if(!trust.Configure(setup_input.relative_store_path,setup_input.persistence_namespace_identity) ||
         !trust.Provision(setup_input.operator_invocation,trust_anchor,trust_scope,now,persisted))
      { result.stop_reason="SETUP_TRUST_PROVISION_FAILED"; return false; }
      result.trust_persisted=true;

      string loaded_operator,loaded_authentication;
      bool found=false;
      if(!trust.LoadCurrent(result.reloaded_trust,result.reloaded_anchor,loaded_operator,
                            loaded_authentication,found) || !found ||
         loaded_operator!=setup_input.operator_invocation.operator_id ||
         loaded_authentication!=setup_input.operator_invocation.authentication_reference ||
         result.reloaded_trust.record_digest!=persisted.record_digest ||
         result.reloaded_anchor.current_authority_record_id!=trust_anchor.current_authority_record_id ||
         result.reloaded_anchor.current_authority_generation!=trust_anchor.current_authority_generation)
      { result.stop_reason="SETUP_TRUST_COMPLETE_RELOAD_FAILED"; return false; }
      result.trust_reloaded_complete=true;
      result.stop_reason="SETUP_PROVISIONING_COMPLETE_RELEASE_REMAINS_EXPLICIT";
      return true;
   }

   // Safety release is separate and requires accepted typed zero-state evidence.
   // The existing authority validates and persists it; this setup host does not infer it.
   bool CompleteSafetyRelease(const SWV5S5_MvpManualDemoSetupInput &setup_input,
                              const SWV5_ContractValidationContext &context,
                              const SWV5_HardKillState &active_state,
                              const SWV5_HardKillReleaseEvidence &release_evidence,
                              const SWV5_HardKillReleaseAuthorityRecord &release_authority_record,
                              const SWV5_InstanceLease &current_lease,
                              const SWV5S5_F_ReconciliationResult &zero_state_reconciliation,
                              SWV5S5_MvpRiskContract &risk_contract,
                              SWV5S5_MvpManualDemoSetupResult &result)
   {
      if(!SWV5S5_MvpManualDemoSetupInputValid(setup_input,context.clock_time))
      { result.stop_reason="SETUP_RELEASE_INPUT_INVALID"; return false; }
      SWV5S5_MvpManualSafetyReleaseProvisioner release;
      SWV5_HardKillState pending;
      SWV5S5_MvpAuthorityRow pending_row,released_row;
      if(!release.Configure(setup_input.relative_store_path,setup_input.persistence_namespace_identity) ||
         !release.StageReleasePending(setup_input.operator_invocation,context,active_state,
                                      release_evidence,pending,pending_row))
      { result.stop_reason="SETUP_RELEASE_PENDING_FAILED"; return false; }
      result.zero_state_verified=(zero_state_reconciliation.state==SWV5S5_F_NO_SIDE_EFFECT_CONFIRMED &&
         zero_state_reconciliation.authoritative_negative &&
         !zero_state_reconciliation.authoritative_positive &&
         !zero_state_reconciliation.retry_allowed &&
         !zero_state_reconciliation.residual_is_submission_authority);
      if(!result.zero_state_verified ||
         !release.PersistApprovedRelease(setup_input.operator_invocation,context,pending,release_evidence,
            release_authority_record,current_lease,zero_state_reconciliation,risk_contract,released_row))
      { result.stop_reason="SETUP_SAFETY_RELEASE_FAILED"; return false; }
      result.safety_release_persisted=true;
      result.stop_reason="SETUP_COMPLETE";
      return true;
   }
};

#endif // SW_V5_S5_MVP_MANUAL_DEMO_SETUP_MQH
