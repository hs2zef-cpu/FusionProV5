#ifndef SW_V5_S5_MVP_ATTENDED_AUTHORITY_SEED_MQH
#define SW_V5_S5_MVP_ATTENDED_AUTHORITY_SEED_MQH

// Mechanical read-only binding of accepted physical authorities. NO ISSUANCE.
#include "SW_V5_S5_MvpControlledDemoAuthorityPort.mqh"

void SWV5S5_MvpContextFromClock(const SWV5S5_MvpLeaseClockObservation &clock,
                               SWV5_ContractValidationContext &context)
{
   ZeroMemory(context); SWV5S5_MvpInitProductionVersion(context.expected_version);
   context.clock_id=clock.clock_id; context.clock_authority=clock.clock_authority;
   context.clock_time=clock.observed_at; context.clock_sequence=clock.clock_sequence;
   context.evaluation_sequence=clock.clock_sequence;
   context.price_tolerance=1.0e-7; context.volume_tolerance=1.0e-7;
}

class SWV5S5_MvpAttendedAuthoritySeedBuilder
{
public:
   bool LoadBase(const SWV5S5_MvpControlledDemoInvocation &invocation,
                 const SWV5S5_MvpLeaseClockObservation &clock,ISWV5S5MvpReadOnlyPlatform &platform,
                 const SWV5S5_F_AdapterEnvironment &environment,
                 SWV5S5_MvpControlledDemoAuthoritySeed &seed,string &reason)
   {
      ZeroMemory(seed); reason="SEED_PROFILE_OR_ACCEPTED_CLOCK_MISSING";
      SWV5S5_MvpRuntimeProfileObservation profile; datetime at=0;
      if(!SWV5S5_MvpLeaseClockObservationValid(clock) ||
         !platform.CaptureProfile(SWV5S5_MVP_SYMBOL,profile,at) || at!=clock.observed_at ||
         !SWV5S5_MvpProfileMatches(profile,ACCOUNT_TRADE_MODE_DEMO) ||
         profile.broker_identity!=invocation.expected_broker_identity || profile.server!=invocation.expected_server ||
         profile.account_login!=invocation.expected_demo_account_login ||
         clock.broker_identity!=profile.broker_identity || clock.server!=profile.server || clock.account_login!=profile.account_login)
         return false;
      SWV5S5_MvpContextFromClock(clock,seed.context); seed.adapter_environment=environment;
      return LoadPhysicalBase(invocation,profile,seed,reason);
   }

   // Current native time is diagnostic only. The persisted observation stays
   // intact as lineage; its sequence is NOT advanced or attributed to "now".
   bool LoadBaseForReadOnlyPreflight(const SWV5S5_MvpControlledDemoInvocation &invocation,
                 const SWV5S5_MvpLeaseClockObservation &lineage,ISWV5S5MvpReadOnlyPlatform &platform,
                 const SWV5S5_F_AdapterEnvironment &environment,
                 SWV5S5_MvpControlledDemoAuthoritySeed &seed,string &reason)
   {
      ZeroMemory(seed); reason="PREFLIGHT_NATIVE_NOW_OR_LINEAGE_INVALID";
      if(invocation.mode!=MODE_PREFLIGHT) return false;
      SWV5S5_MvpLeaseClockAuthority clock; SWV5S5_MvpLeaseClockObservation stored;
      SWV5S5_MvpAuthorityRow row; bool found=false; string supplied,actual,digest;
      SWV5S5_MvpRuntimeProfileObservation profile; datetime now=0; string native_clock_id;
      if(!clock.ConfigureReadOnly(invocation.relative_store_path,invocation.persistence_namespace_identity) ||
         !clock.LoadStored(stored,row,found) || !found ||
         !SWV5S5_MvpLeaseClockPayload(lineage,supplied,digest) ||
         !SWV5S5_MvpLeaseClockPayload(stored,actual,digest) || actual!=supplied ||
         !platform.CaptureProfile(SWV5S5_MVP_SYMBOL,profile,now) ||
         now<stored.observed_at || !SWV5S5_MvpProfileMatches(profile,ACCOUNT_TRADE_MODE_DEMO) ||
         profile.broker_identity!=invocation.expected_broker_identity || profile.server!=invocation.expected_server ||
         profile.account_login!=invocation.expected_demo_account_login ||
         !SWV5S5_MvpLeaseClockId(profile.broker_identity,profile.server,profile.account_login,profile.symbol,native_clock_id) ||
         native_clock_id!=stored.clock_id) return false;
      seed.read_only_preflight=true; seed.preflight_lineage=stored;
      seed.preflight_now.observed_at=now; seed.preflight_now.profile=profile;
      seed.preflight_now.clock_id=native_clock_id;
      seed.preflight_now.clock_authority=SWV5_TIME_AUTHORITY_BROKER_SERVER;
      SWV5S5_MvpContextFromClock(stored,seed.context);
      // Read-only validators compare persisted lineage sequence and native
      // liveness time independently. No durable observation is manufactured.
      seed.context.clock_time=now; seed.adapter_environment=environment;
      if(!LoadPhysicalBase(invocation,profile,seed,reason)) return false;
      reason="PREFLIGHT_TRUST_EXPIRED_OR_NOT_AUTHORIZED";
      if(seed.current_trust.status!=SWV5S5_TRUST_AUTHORIZED || seed.current_trust.valid_from>now ||
         seed.current_trust.valid_until<=now) return false;
      reason="PREFLIGHT_BASKET_NOT_CANONICAL_IDLE_V1";
      if(seed.risk_observation.basket.lifecycle.state!=SWV5_BASKET_IDLE ||
         seed.risk_observation.basket.lifecycle.state_version!=1) return false;
      SWV5S5_F_ProfileScope expected; ZeroMemory(expected); SWV5S5_F_InitVersion(expected.contract_version);
      expected.persistence_namespace=seed.current_trust.persistence_namespace;
      expected.account_namespace=seed.risk_observation.account_namespace;
      expected.broker_identity=profile.broker_identity; expected.server=profile.server;
      expected.account_login=profile.account_login; expected.symbol=profile.symbol;
      expected.terminal_build=environment.terminal_build; expected.mql_build=environment.mql_build;
      expected.profile_id=SWV5S5_F_ADAPTER_PROFILE_ID;
      SWV5S5_MvpReconciliationGovernanceAuthority governance; SWV5S5_MvpReconciliationGovernanceBundle bundle;
      reason="PREFLIGHT_GOVERNANCE_MISSING_INVALID_OR_EXPIRED";
      if(!SWV5S5_F_DeriveProfileDigest(expected,expected.profile_digest) ||
         !SWV5S5_F_AdapterEnvironmentMatchesProfile(expected,environment) ||
         !governance.ConfigureReadOnly(invocation.relative_store_path,invocation.persistence_namespace_identity) ||
         !governance.Load(now,expected,bundle,row,found) || !found ||
         bundle.capability_proof.valid_from>now || bundle.capability_proof.valid_until<=now) return false;
      reason=""; return true;
   }

private:
   bool LoadPhysicalBase(const SWV5S5_MvpControlledDemoInvocation &invocation,
                        const SWV5S5_MvpRuntimeProfileObservation &profile,
                        SWV5S5_MvpControlledDemoAuthoritySeed &seed,string &reason)
   {
      SWV5S5_MvpSqliteAuthorityStore store;
      reason="SEED_PHYSICAL_STORE_MISSING_OR_INVALID";
      if(!store.OpenReadOnly(invocation.relative_store_path,invocation.persistence_namespace_identity)) return false;
      SWV5S5_MvpAuthorityRow row; bool found=false; SWV5_InstanceLease decoded;
      SWV5S5_MvpLeasePublicationAuthority ownership;
      reason="SEED_CURRENT_OWNERSHIP_MISSING_OR_STALE";
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,row,found) || !found ||
         !SWV5S5_MvpDecodeOwnershipLeasePhysical(row.payload,decoded) ||
         !ownership.LoadCurrentLease(store,decoded.fence.ownership_namespace,decoded.fence,seed.current_lease,row) ||
         !SWV5S5_MvpLeaseCurrentForClock(seed.context,seed.current_lease.fence,seed.current_lease)) return false;
      SWV5S5_MvpManualProducerTrustProvisioner trust; string operator_id,authentication;
      reason="SEED_PHYSICAL_TRUST_MISSING_OR_INVALID";
      if(!trust.ConfigureReadOnly(invocation.relative_store_path,invocation.persistence_namespace_identity) ||
         !trust.LoadCurrent(seed.current_trust,seed.trust_anchor,operator_id,authentication,found) || !found) return false;
      SWV5S5_MvpAccountRiskAuthority account; SWV5S5_MvpAccountRiskAuthorityRecord record;
      reason="SEED_PHYSICAL_ACCOUNT_AUTHORITY_MISSING_OR_INVALID";
      if(!account.ValidateCurrent(store,seed.current_trust.persistence_namespace,profile,record,row)) return false;
      seed.risk_observation.account_namespace=record.account_namespace;
      SWV5S5_MvpBasketLifecycleAuthority basket; SWV5_BasketAggregate aggregate;
      reason="SEED_CANONICAL_BASKET_MISSING_OR_INVALID";
      if(!basket.ValidateCurrentBasket(store,seed.context,record.persistence_namespace,seed.current_lease,aggregate,row)) return false;
      seed.risk_observation.basket.contract_version=aggregate.contract_version;
      seed.risk_observation.basket.account_namespace=record.account_namespace;
      seed.risk_observation.basket.lifecycle=aggregate.lifecycle;
      seed.risk_observation.basket.observed_at=seed.context.clock_time;
      seed.risk_observation.ownership_fence=seed.current_lease.fence;
      seed.filling_mode=seed.adapter_environment.symbol_filling_mask;
      seed.comment_metadata="FUSION-V5-MVP";
      reason=""; return true;
   }

public:
   bool CompleteIncreasing(SWV5S5_MvpSqliteAuthorityStore &store,
                           SWV5S5_MvpControlledDemoAuthoritySeed &seed,string &reason)
   {
      reason="SEED_HARD_KILL_NOT_EXECUTABLE";
      SWV5S5_MvpHardKillActivationAuthority activation;
      if(!activation.LoadCurrentInactive(store,seed.context,seed.current_lease,seed.hard_kill_state)) return false;
      if(seed.risk_observation.basket.lifecycle.state!=SWV5_BASKET_IDLE ||
         seed.risk_observation.basket.lifecycle.aggregate_open_volume!=0.0)
      { reason="SEED_BASKET_NOT_INITIAL_FLAT"; return false; }
      seed.risk_observation.hard_kill_state=seed.hard_kill_state;
      // The coherent financial observation is captured once by the concrete
      // Port during preparation, not a second time by the seed builder.
      SWV5S5_MvpInitProductionVersion(seed.risk_observation.projected.contract_version);
      seed.risk_observation.projected.account_namespace=seed.risk_observation.account_namespace;
      SWV5_RiskMonetaryBasis basis;
      ZeroMemory(basis);
      SWV5S5_MvpInitProductionVersion(basis.contract_version);
      basis.currency=SWV5S5_MVP_ACCOUNT_CURRENCY; basis.account_currency=SWV5S5_MVP_ACCOUNT_CURRENCY;
      basis.conversion_source=SWV5S5_MVP_CONVERSION_SOURCE; basis.conversion_rate_to_account_currency=1.0;
      basis.valuation_at=seed.context.clock_time;
      basis.calculation_basis=SWV5_RISK_BASIS_PROTECTIVE_STOP; basis.sign_convention=SWV5_RISK_LOSS_POSITIVE;
      basis.includes_realized=true; basis.includes_unrealized=true; basis.includes_commission=true;
      basis.includes_swap=true; basis.includes_fee=true;
      seed.risk_observation.projected.monetary_basis=basis;
      reason=""; return true;
   }
};

#endif
