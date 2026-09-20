#ifndef SW_V5_S5_MVP_MANUAL_DEMO_SETUP_MQH
#define SW_V5_S5_MVP_MANUAL_DEMO_SETUP_MQH

// CONTROLLED DEMO MVP — MANUAL SETUP ONLY.
// This utility owns no trading intent, Permit, Claim, broker adapter, or submission path.
// It is manually invoked to establish the already-approved durable authorities.

#include "../RuntimeAuthority/SW_V5_S5_MvpOwnershipAuthority.mqh"

struct SWV5S5_MvpManualDemoSetupInput
{
   string relative_store_path;
   string persistence_namespace_identity;
   string expected_broker_identity;
   string expected_server;
   long expected_demo_account_login;
   string claimant_instance_id;
   string claimant_process_fingerprint;
   uint lease_duration_seconds;
   string platform_observation_id;
   string basket_id;
   ulong producer_epoch;
   int producer_timeframe;
   int producer_execution_mode;
   string ingress_identity;
   SWV5S5_MvpOperatorInvocation operator_invocation;
};

struct SWV5S5_MvpManualDemoSetupResult
{
   bool profile_matched;
   bool genesis_ready;
   bool clock_observed;
   bool ownership_acquired_now;
   bool ownership_readback_complete;
   bool trust_persisted;
   bool trust_reloaded_complete;
   bool zero_state_verified;
   bool safety_release_persisted;
   string stop_reason;
   SWV5S5_MvpLeaseClockObservation accepted_clock;
   SWV5_InstanceLease current_lease;
   SWV5S5_ProducerTrustRecord reloaded_trust;
   SWV5S5_ProducerTrustAnchor reloaded_anchor;
};

bool SWV5S5_MvpManualDemoSetupInputValid(const SWV5S5_MvpManualDemoSetupInput &setup_input,
                                         const datetime now)
{
   return setup_input.relative_store_path!="" && setup_input.persistence_namespace_identity!="" &&
      setup_input.expected_broker_identity!="" && setup_input.expected_server!="" &&
      setup_input.expected_demo_account_login>0 &&
      setup_input.claimant_instance_id!="" && setup_input.claimant_process_fingerprint!="" &&
      setup_input.lease_duration_seconds>0 &&
      setup_input.lease_duration_seconds<=SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS &&
      setup_input.platform_observation_id!="" && setup_input.basket_id!="" &&
      setup_input.producer_epoch>0 && setup_input.producer_timeframe>0 &&
      setup_input.ingress_identity!="" &&
      SWV5S5_MvpOperatorInvocationValid(setup_input.operator_invocation,now);
}

class SWV5S5_MvpManualDemoSetup
{
public:
   // Called exactly once from the explicitly armed current-XAUUSD OnTick host.
   // Genesis is completed before the accepted clock sample; the caller can no
   // longer publish or supply an allegedly authoritative lease.
   bool ProvisionOnCurrentSymbolTick(const SWV5S5_MvpManualDemoSetupInput &setup_input,
                  ISWV5S5MvpReadOnlyPlatform &platform,
                  const SWV5S5_ProducerTrustAnchor &trust_anchor,
                  SWV5S5_MvpManualDemoSetupResult &result)
   {
      ZeroMemory(result);
      SWV5S5_MvpRuntimeProfileObservation observed;
      datetime observed_at=0;
      if(!platform.CaptureProfile(SWV5S5_MVP_SYMBOL,observed,observed_at) ||
         !SWV5S5_MvpManualDemoSetupInputValid(setup_input,observed_at) ||
         !SWV5S5_MvpProfileMatches(observed,ACCOUNT_TRADE_MODE_DEMO) ||
         observed.broker_identity!=setup_input.expected_broker_identity ||
         observed.server!=setup_input.expected_server ||
         observed.account_login!=setup_input.expected_demo_account_login)
      { result.stop_reason="SETUP_PROFILE_MISMATCH"; return false; }
      result.profile_matched=true;

      SWV5S5_MvpManualGenesisProvisioner genesis;
      bool ready=false;
      if(!genesis.Configure(setup_input.relative_store_path,setup_input.persistence_namespace_identity) ||
         !genesis.Begin(setup_input.operator_invocation,observed_at) ||
         !genesis.InitializeAllDomains(observed_at) ||
         !genesis.FinalizeReadyForReconciliation(observed_at) ||
         !genesis.IsReadyForReconciliation(ready) || !ready)
      { result.stop_reason="SETUP_GENESIS_FAILED"; return false; }
      result.genesis_ready=true;

      SWV5S5_MvpLeaseClockAuthority clock;
      SWV5S5_MvpAuthorityRow clock_row;
      if(!clock.Configure(setup_input.relative_store_path,setup_input.persistence_namespace_identity) ||
         !clock.ObserveFromCurrentSymbolOnTick(SWV5S5_MVP_SYMBOL,setup_input.platform_observation_id,
            result.accepted_clock,clock_row) || result.accepted_clock.observed_at!=observed_at)
      { result.stop_reason="SETUP_CURRENT_SYMBOL_CLOCK_FAILED"; return false; }
      result.clock_observed=true;

      SWV5_OwnerIdentity claimant; ZeroMemory(claimant);
      claimant.key.account_login=observed.account_login;
      claimant.key.broker_identity=observed.broker_identity; claimant.key.server=observed.server;
      claimant.key.symbol=SWV5S5_MVP_SYMBOL; claimant.key.strategy_id=SWV5S5_MVP_PROFILE_ID;
      claimant.key.magic=SWV5_RUNTIME_STRATEGY_MAGIC;
      claimant.instance_id=setup_input.claimant_instance_id;
      claimant.process_fingerprint=setup_input.claimant_process_fingerprint;
      claimant.started_at=result.accepted_clock.observed_at;
      SWV5S5_MvpInitialOwnershipAuthority ownership;
      SWV5S5_MvpInitialAcquireResult acquisition;
      if(!ownership.Configure(setup_input.relative_store_path,setup_input.persistence_namespace_identity) ||
         !ownership.AcquireInitial(claimant,setup_input.lease_duration_seconds,clock,acquisition) ||
         !acquisition.acquired_now)
      { result.stop_reason="SETUP_INITIAL_OWNERSHIP_ACQUIRE_FAILED"; return false; }
      result.ownership_acquired_now=true; result.current_lease=acquisition.authoritative_lease;
      result.ownership_readback_complete=SWV5S5_MvpLeaseExact(acquisition.proposed_lease,
                                                              acquisition.authoritative_lease);
      if(!result.ownership_readback_complete)
      { result.stop_reason="SETUP_OWNERSHIP_READBACK_FAILED"; return false; }

      SWV5S5_ProducerTrustScope trust_scope; ZeroMemory(trust_scope);
      SWV5S5_InitContractVersion(trust_scope.persistence_namespace.contract_version);
      trust_scope.persistence_namespace.ownership_namespace=claimant.key;
      trust_scope.persistence_namespace.basket_id.value=setup_input.basket_id;
      trust_scope.producer_component="DECISION";
      trust_scope.producer_instance=SWV5S5_MVP_PRODUCER_INSTANCE;
      trust_scope.producer_epoch=setup_input.producer_epoch; trust_scope.symbol=SWV5S5_MVP_SYMBOL;
      trust_scope.timeframe=setup_input.producer_timeframe;
      trust_scope.execution_mode=setup_input.producer_execution_mode;
      trust_scope.publication_clock_id=result.accepted_clock.clock_id;
      trust_scope.publication_clock_authority=result.accepted_clock.clock_authority;
      trust_scope.ingress_identity=setup_input.ingress_identity;

      SWV5S5_MvpManualProducerTrustProvisioner trust;
      SWV5S5_ProducerTrustRecord persisted;
      if(!trust.Configure(setup_input.relative_store_path,setup_input.persistence_namespace_identity) ||
         !trust.Provision(setup_input.operator_invocation,trust_anchor,trust_scope,observed_at,persisted))
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
