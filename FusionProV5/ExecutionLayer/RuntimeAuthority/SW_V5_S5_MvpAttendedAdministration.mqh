#ifndef SW_V5_S5_MVP_ATTENDED_ADMINISTRATION_MQH
#define SW_V5_S5_MVP_ATTENDED_ADMINISTRATION_MQH
// Explicit setup actions only. NO BROKER MUTATION / NO SUBMISSION GRAPH.
#include "SW_V5_S5_MvpAccountRiskAuthority.mqh"
#include "SW_V5_S5_MvpHardKillActivationAuthority.mqh"
#include "SW_V5_S5_MvpBasketLifecycleAuthority.mqh"
#include "SW_V5_S5_MvpReconciliationGovernanceAuthorities.mqh"

class SWV5S5_MvpAttendedAdministration
{
public:
   // All arguments are freshly observed/loaded by the executable. The lease
   // owner and Account owner verify complete physical records again here.
   bool SafetyRelease(const string path,const string ns,const SWV5S5_MvpOperatorInvocation &op,
                      const SWV5_ContractValidationContext &context,const SWV5_PersistenceNamespace &scope,
                      const SWV5_AccountRiskNamespace &account,const SWV5_InstanceLease &lease,
                      ISWV5S5MvpBootstrapBrokerObserver &broker,string &reason)
   {
      reason="SAFETY_RELEASE_EXPLICIT_AUTH_REQUIRED";
      if(!SWV5S5_MvpOperatorInvocationValid(op,context.clock_time)) return false;
      SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpHardKillActivationAuthority activation;
      SWV5_HardKillState active,pending,released,inactive; SWV5S5_MvpAuthorityRow row,guard,committed;
      SWV5_InstanceLease physical; SWV5S5_MvpLeasePublicationAuthority ownership;
      reason="SAFETY_RELEASE_CURRENT_GENESIS_LEASE_REQUIRED";
      if(!store.Open(path,ns) || !ownership.LoadCurrentLease(store,scope.ownership_namespace,lease.fence,physical,guard) ||
         !SWV5S5_MvpLeaseExact(physical,lease) || !activation.LoadGenesisActive(store,context,scope,account,active)) return false;
      SWV5S5_MvpBootstrapZeroAuthorityProducer producer; SWV5S5_MvpBootstrapZeroStateAuthority zero;
      SWV5S5_MvpBootstrapZeroAuthorityStore zeros;
      reason="SAFETY_RELEASE_TYPED_PHYSICAL_ZERO_REQUIRED";
      if(!producer.Produce(context,scope,account,lease,active,broker,store,zero) ||
         !zeros.Configure(path,ns) || !zeros.Persist(zero,guard,committed)) return false;
      SWV5S5_MvpHardKillRiskGovernanceIssuer issuer;
      SWV5_HardKillReleaseEvidence evidence; SWV5_HardKillReleaseAuthorityRecord authority;
      SWV5S5_MvpManualSafetyReleaseProvisioner release; SWV5S5_MvpRiskContract risk;
      reason="SAFETY_RELEASE_INDEPENDENT_GOVERNANCE_OR_CAS_FAILED";
      if(!issuer.Issue(op,context,active,zero,evidence,authority) || !release.Configure(path,ns) ||
         !release.StageReleasePending(op,context,active,evidence,pending,row) ||
         !release.PersistApprovedRelease(op,context,pending,evidence,authority,lease,zero,risk,committed)) return false;
      bool found=false; SWV5S5_MvpAuthorityRow complete;
      reason="SAFETY_RELEASE_COMPLETE_READBACK_FAILED";
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE,authority.authority_record_id,complete,found) || !found ||
         !SWV5S5_MvpDecodeReleaseBundle(complete.payload,released,authority) ||
         !activation.TryActivateInactiveAfterValidatedRelease(store,context,op,true,released,lease,committed,inactive,row)) return false;
      reason="SAFETY_RELEASE_AND_NEW_INACTIVE_EPOCH_DURABLE"; return true;
   }

   bool GovernanceAndInitialBasket(const string path,const string ns,const SWV5S5_MvpOperatorInvocation &op,
                                  const SWV5_ContractValidationContext &context,const SWV5_InstanceLease &lease,
                                  const SWV5S5_F_ProfileScope &profile,const string approval,const string proof,
                                  ISWV5S5MvpBootstrapBrokerObserver &broker,string &reason)
   {
      reason="GOVERNANCE_EXPLICIT_AUTH_REQUIRED";
      if(!SWV5S5_MvpOperatorInvocationValid(op,context.clock_time) || approval=="" || proof=="") return false;
      SWV5S5_MvpSqliteAuthorityStore prerequisite; SWV5_HardKillState inactive;
      SWV5S5_MvpHardKillActivationAuthority activation;
      reason="GOVERNANCE_REQUIRES_PRIOR_PHYSICAL_INACTIVE_RELEASE";
      if(!prerequisite.OpenReadOnly(path,ns) || !activation.LoadCurrentInactive(prerequisite,context,lease,inactive)) return false;
      SWV5S5_MvpReconciliationGovernanceAuthority governance;
      SWV5S5_MvpReconciliationGovernanceBundle bundle,readback; SWV5S5_MvpAuthorityRow row; bool found=false;
      reason="GOVERNANCE_PHYSICAL_PROVISION_OR_READBACK_FAILED";
      if(!governance.Configure(path,ns) ||
         !governance.Provision(op,profile,approval,proof,context.clock_time+3600,context.clock_sequence,bundle,row) ||
         !governance.Load(context.clock_time,profile,readback,row,found) || !found || readback.bundle_digest!=bundle.bundle_digest)
         return false;
      // Explicit setup initializes an empty accepted RequestSet before the
      // Basket owner independently verifies Broker AND Execution zero-state.
      SWV5S5_MvpRequestSetPublicationAuthority requests; SWV5S5_MvpSqliteAuthorityStore store;
      SWV5S5_MvpBasketLifecycleAuthority baskets; SWV5_BasketAggregate basket;
      reason="INITIAL_BASKET_PHYSICAL_PREREQUISITE_FAILED";
      if(!requests.Configure(path,ns) || !requests.Initialize(profile.persistence_namespace,lease.fence,context.clock_time) ||
         !store.Open(path,ns) || !baskets.TryCreateInitialFlatBasket(store,context,profile.persistence_namespace,lease,broker,basket,row))
         return false;
      reason="GOVERNANCE_AND_CANONICAL_INITIAL_BASKET_DURABLE"; return true;
   }
};
#endif
