#ifndef SW_V5_S5_MVP_ATTENDED_CONTINUATION_MQH
#define SW_V5_S5_MVP_ATTENDED_CONTINUATION_MQH
// EXPLICIT ATTENDED DEMO ADMINISTRATION ONLY / NO EXECUTION AUTHORITY.
#include "SW_V5_S5_MvpContinuationActivation.mqh"

struct SWV5S5_MvpContinuationInput
{
   string path,namespace_digest,continuation_id,approval_reference,proof_reference,trust_anchor_id;
   SWV5_OwnerIdentity configured_owner;
   uint lease_seconds;
   bool acknowledged;
};
struct SWV5S5_MvpContinuationResult
{
   bool accepted,already_complete,partial_continuation;
   string reason,stage;
   datetime effective_expiry;
   ulong initial_latch_generation,final_latch_generation,release_generation;
   uint broker_submission_calls;
};

class SWV5S5_MvpAttendedContinuation
{
private:
   SWV5S5_MvpContinuationResult m_result;
   // Ephemeral ONE-A invocation. Never reconstructed from durable records.
   bool m_waiting_finalization;
   SWV5S5_MvpContinuationInput m_attended_input;
   SWV5S5_MvpOperatorInvocation m_attended_op;
   SWV5S5_MvpContinuationFlatAuthority m_prepared_flat;
   datetime m_initial_event_time,m_observation_horizon;
   ulong m_initial_event_sequence;
   bool m_flat_already_durable;
   SWV5S5_MvpAuthorityRow m_finalization_rows[];
   bool Stop(const string reason)
   {
      m_result.reason=reason;
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
      Print("CONTINUATION_STAGE_TRACE|STOP|stage=",m_result.stage,"|reason=",reason);
#endif
      return false;
   }

   bool ScopeOwner(const SWV5S5_MvpContinuationInput &i,const SWV5_InstanceLease &lease)
   {
      string a,b;
      return SWV5S5_MvpOwnerComplete(i.configured_owner) &&
         SWV5S5_MvpCodecEncode_SWV5_OwnerIdentity(i.configured_owner,a) &&
         SWV5S5_MvpCodecEncode_SWV5_OwnerIdentity(lease.fence.owner,b) && a==b;
   }
   bool ReadLease(SWV5S5_MvpSqliteAuthorityStore &store,SWV5_InstanceLease &lease,SWV5S5_MvpAuthorityRow &row)
   {
      bool found=false; SWV5_InstanceLease decoded; SWV5S5_MvpLeasePublicationAuthority owner;
      return store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,row,found) && found &&
         SWV5S5_MvpDecodeOwnershipLeasePhysical(row.payload,decoded) &&
         owner.LoadCurrentLease(store,decoded.fence.ownership_namespace,decoded.fence,lease,row);
   }
   bool ReadGovernance(SWV5S5_MvpSqliteAuthorityStore &store,SWV5S5_MvpReconciliationGovernanceBundle &g,SWV5S5_MvpAuthorityRow &row)
   {
      bool found=false;
      return store.ReadRow(SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE,"CURRENT",row,found) && found &&
         SWV5S5_MvpContinuationRowValid(store,row) && SWV5S5_MvpDecodeGovernance(row.payload,g) &&
         SWV5S5_MvpGovernanceValid(g,g.valid_from);
   }
   bool ReadTrust(const SWV5S5_MvpContinuationInput &i,SWV5S5_ProducerTrustRecord &trust,SWV5S5_ProducerTrustAnchor &anchor)
   {
      SWV5S5_MvpManualProducerTrustProvisioner owner; bool found=false; string op,auth;
      return owner.ConfigureReadOnly(i.path,i.namespace_digest) && owner.LoadCurrent(trust,anchor,op,auth,found) && found &&
         anchor.trust_anchor_id==i.trust_anchor_id && anchor.current_authority_record_id==trust.authority_record_id &&
         anchor.current_authority_generation==trust.authority_generation && trust.authority_generation==1 &&
         anchor.issuer_identity==trust.issuer_identity && anchor.issuer_policy_id==trust.issuer_policy_id &&
         trust.status==SWV5S5_TRUST_AUTHORIZED && trust.producer_component=="DECISION" &&
         trust.producer_instance==SWV5S5_MVP_PRODUCER_INSTANCE && trust.producer_epoch==1 &&
         trust.symbol==SWV5S5_MVP_SYMBOL && trust.timeframe==(int)PERIOD_M15 && trust.execution_mode==1 && // accepted EVERY_TICK wire value
         trust.clock_authority==SWV5_TIME_AUTHORITY_BROKER_SERVER;
   }
   bool ResumeProofValid(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_ContractValidationContext &context,
                         const SWV5S5_MvpContinuationActivationProof &p,const SWV5_InstanceLease &lease,
                         const SWV5S5_MvpAuthorityRow &current)
   {
      SWV5S5_MvpAuthorityRow history,rows[]; bool found=false; string payload,digest,revision;
      SWV5S5_MvpHardKillActivationProof original; SWV5_HardKillState prior_released,expected;
      SWV5_HardKillReleaseAuthorityRecord a;
      if(!SWV5S5_EqualFence(p.fence,lease.fence) || p.active.state!=SWV5_HARD_KILL_ACTIVE ||
         p.active.activation_reason!="CONTINUATION_REAUTHORIZATION" ||
         p.active.latch_generation!=p.prior_inactive.latch_generation+1 ||
         p.active.release_generation!=p.prior_maximum_release_generation ||
         !store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_HISTORY,p.prior_inactive.latch_id,history,found) || !found ||
         !SWV5S5_MvpContinuationRowValid(store,history) || !SWV5S5_MvpDecodeActivation(history.payload,original) ||
         !SWV5S5_MvpDecodeReleaseBundle(original.release_bundle,prior_released,a)) return false;
      SWV5S5_MvpNewInactiveEpoch(prior_released,history.payload_digest,expected);
      if(!SWV5S5_CanonicalHardKillState("hard_kill",expected,payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,payload,digest) || digest!=p.prior_row.payload_digest ||
         !SWV5S5_CanonicalHardKillState("hard_kill",p.prior_inactive,payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,payload,digest) || digest!=p.prior_row.payload_digest ||
         p.prior_row.logical_revision!=original.released_row.logical_revision+1 ||
         !store.DeriveStoreRevision(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",p.prior_row.logical_revision,digest,revision) ||
         revision!=p.prior_row.store_revision || !store.ReadAllRows(rows)) return false;
      ulong maximum=0;
      return SWV5S5_MvpContinuationHistoryMaximum(store,context,p.active.persistence_namespace,p.active.account_namespace,lease.fence,
         (current.state==(int)SWV5_HARD_KILL_RELEASED ? p.active.latch_id : ""),maximum) &&
         maximum==p.prior_maximum_release_generation && maximum==prior_released.release_generation && maximum>0;
   }
   bool EmptyExecutionAndBasketDiagnostic(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_ContractValidationContext &context,
                                const SWV5_PersistenceNamespace &scope,const SWV5_InstanceLease &lease,string &reason)
   {
      reason="";
      SWV5S5_MvpAuthorityRow row; bool found=false; SWV5S5_MvpRequestSetPhysicalState requests;
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_REQUEST_SET,SWV5S5_MVP_REQUEST_SET_KEY,row,found) || !found ||
         !SWV5S5_MvpContinuationRowValid(store,row) || !SWV5S5_MvpDecodeRequestSetState(row.payload,requests) ||
         !SWV5S5_EqualNamespace(scope,requests.view.persistence_namespace) ||
         !SWV5S5_EqualFence(lease.fence,requests.view.ownership_fence) || ArraySize(requests.view.requests)!=0 ||
         requests.view.header.request_count!=0) {reason="PRESTATE_REQUESTSET_INVALID";return false;}
      string projection=requests.view.projection_digest;
      if(!SWV5S5_DeriveRequestSetProjection(requests.view) || requests.view.projection_digest!=projection)
      {reason="PRESTATE_REQUESTSET_PROJECTION_INVALID";return false;}
      SWV5S5_MvpBasketLifecycleAuthority owner; SWV5_BasketAggregate basket; SWV5_BasketInvariantReport report;
      SWV5S5_MvpBasketStateMachine machine;
      const bool valid=owner.LoadCurrentBasket(store,basket,row,found) && found && row.logical_revision==1 &&
         SWV5S5_EqualNamespace(basket.persistence_namespace,scope) &&
         SWV5S5_EqualFence(basket.lifecycle.ownership_fence,lease.fence) &&
         basket.lifecycle.state==SWV5_BASKET_IDLE && basket.lifecycle.state_version==1 &&
         basket.lifecycle.aggregate_open_volume==0.0 && basket.lifecycle.residual_volume==0.0 &&
         basket.initial_volume==0.0 && basket.aggregate_closed_volume==0.0 &&
         basket.close_verification==SWV5_CLOSE_ZERO_RESIDUAL_CONFIRMED && machine.ValidateState(context,basket.lifecycle,report);
      if(!valid)reason="PRESTATE_BASKET_INVALID";return valid;
   }
   bool EmptyExecutionAndBasket(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_ContractValidationContext &context,
                                const SWV5_PersistenceNamespace &scope,const SWV5_InstanceLease &lease)
   {
      string reason;return EmptyExecutionAndBasketDiagnostic(store,context,scope,lease,reason);
   }
   bool RowsAllowedDiagnostic(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_PersistenceNamespace &scope,
                    const SWV5_OwnershipFence &fence,SWV5S5_MvpAuthorityRow &rows[],string &reason)
   {
      reason="";
      if(!SWV5S5_MvpContinuationInventoryAllowedDiagnostic(store,rows,reason)) return false;
      for(int x=0;x<ArraySize(rows);x++)
      {
         const SWV5S5_MvpAuthorityRow row=rows[x];
         if(!SWV5S5_MvpContinuationRowValid(store,row)){reason="PRESTATE_ROW_PHYSICAL_INVALID/"+row.domain_key;return false;}
         if(row.record_key=="GENESIS")
         {
            string manifest;
            if(!SWV5S5_MvpGenesisManifestDigest(manifest) || row.logical_revision>(ulong)(row.domain_key==SWV5S5_MVP_DOMAIN_GENESIS ? 2 : 1) ||
               StringFind(row.payload,manifest)<0){reason="PRESTATE_GENESIS_EXACT_BINDING_FAILED";return false;}
            bool known=row.domain_key==SWV5S5_MVP_DOMAIN_GENESIS;
            for(int d=0;d<SWV5S5_MvpGenesisDomainCount();d++) if(row.domain_key==SWV5S5_MvpGenesisDomain(d)) known=true;
            if(!known){reason="PRESTATE_OPERATIONAL_ROW_PRESENT/"+row.domain_key;return false;}
            continue;
         }
         if((row.domain_key==SWV5S5_MVP_DOMAIN_ACCOUNT_RISK && row.record_key=="CURRENT") ||
            (row.domain_key==SWV5S5_MVP_DOMAIN_OWNERSHIP && (row.record_key==SWV5S5_MVP_OWNERSHIP_KEY || row.record_key==SWV5S5_MVP_OWNERSHIP_CLOCK_KEY)) ||
            ((row.domain_key==SWV5S5_MVP_DOMAIN_PRODUCER_TRUST || row.domain_key==SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE ||
              row.domain_key==SWV5S5_MVP_DOMAIN_HARD_KILL || row.domain_key==SWV5S5_MVP_DOMAIN_BOOTSTRAP_ZERO ||
              row.domain_key==SWV5S5_MVP_DOMAIN_BASKET) && row.record_key=="CURRENT") ||
            (row.domain_key==SWV5S5_MVP_DOMAIN_REQUEST_SET && row.record_key==SWV5S5_MVP_REQUEST_SET_KEY)) continue;
         if(row.domain_key==SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE)
         {
            SWV5_HardKillState state; SWV5_HardKillReleaseAuthorityRecord a;
            if(!SWV5S5_MvpDecodeReleaseBundle(row.payload,state,a) || row.record_key!=a.authority_record_id ||
               !SWV5S5_EqualNamespace(state.persistence_namespace,scope)){reason="PRESTATE_HARD_KILL_COMPLETE_RELEASE_INVALID";return false;}
            continue;
         }
         if(row.domain_key==SWV5S5_MVP_DOMAIN_RELEASE_HISTORY)
         {
            SWV5S5_MvpHardKillActivationProof history;
            if(!SWV5S5_MvpDecodeActivation(row.payload,history) || row.record_key!="INACTIVE/"+row.payload_digest ||
               !SWV5S5_EqualFence(history.activation_fence,fence)){reason="PRESTATE_HARD_KILL_HISTORY_INVALID";return false;}
            continue;
         }
         if(row.domain_key==SWV5S5_MVP_DOMAIN_HARD_KILL_RELEASE && row.record_key=="CURRENT") continue;
         if(row.domain_key==SWV5S5_MVP_DOMAIN_CONTINUATION_ACTIVATION)
         {
            SWV5S5_MvpContinuationActivationProof proof;
            if(!SWV5S5_MvpDecodeContinuationActivation(row.payload,proof) || row.record_key!=proof.active.latch_id ||
               !SWV5S5_EqualNamespace(proof.active.persistence_namespace,scope) || !SWV5S5_EqualFence(proof.fence,fence))
            {reason="PRESTATE_CONTINUATION_ACTIVATION_BINDING_INVALID";return false;}
            continue;
         }
         if(row.domain_key==SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT)
         {
            SWV5S5_MvpContinuationFlatAuthority flat;
            if(!SWV5S5_MvpDecodeContinuationFlat(row.payload,flat) || flat.key!=row.record_key ||
               !SWV5S5_EqualNamespace(flat.scope,scope) || !SWV5S5_EqualFence(flat.fence,fence))
            {reason="PRESTATE_CONTINUATION_FLAT_BINDING_INVALID";return false;}
            continue;
         }
         reason="PRESTATE_OPERATIONAL_ROW_PRESENT/"+row.domain_key;return false;
      }
      return true;
   }
   bool RowsAllowed(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_PersistenceNamespace &scope,
                    const SWV5_OwnershipFence &fence,SWV5S5_MvpAuthorityRow &rows[])
   {
      string reason;return RowsAllowedDiagnostic(store,scope,fence,rows,reason);
   }
#ifndef SWV5S5_TEST_ONLY_RESUME_CLOCK_CLASSIFIER
   bool Flat(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5S5_MvpContinuationInput &i,
             const SWV5_ContractValidationContext &context,const SWV5S5_MvpOperatorInvocation &op,
             const SWV5_AccountRiskNamespace &account,const SWV5_InstanceLease &lease,
             const SWV5_HardKillState &active,ISWV5S5MvpBootstrapBrokerObserver &broker,
             SWV5S5_MvpContinuationFlatAuthority &flat)
   {
      ZeroMemory(flat); SWV5S5_MvpBootstrapBrokerObservation observation;
      if(!EmptyExecutionAndBasket(store,context,active.persistence_namespace,lease) ||
         !SWV5S5_MvpContinuationBrokerZero(broker,account,context.clock_time,observation)) return false;
      flat.contract_version=context.expected_version; flat.scope=active.persistence_namespace; flat.account=account;
      flat.fence=lease.fence; flat.active=active; flat.op=op; flat.clock_id=context.clock_id;
      flat.clock_authority=context.clock_authority; flat.clock_sequence=context.clock_sequence;
      flat.key=i.continuation_id+"/"+IntegerToString((long)context.clock_sequence);
      SWV5S5_MvpAuthorityRow bound[];
      if(!RowsAllowed(store,flat.scope,flat.fence,bound) || !SWV5S5_MvpContinuationPhysicalInvariants(store,context,flat) ||
         !SWV5S5_MvpContinuationRowsPayload(bound,flat.bound_rows_payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_CONTINUATION_FLAT_DIGEST+"-STORE",flat.bound_rows_payload,flat.physical_snapshot_digest) ||
         !SWV5S5_MvpContinuationBrokerPayload(observation,flat.broker_observation_payload)) return false;
      const datetime persistence_observed_at=TimeCurrent(); // observation, NOT clock authority
      if(persistence_observed_at<observation.observed_at)return false;
      flat.observed_at=persistence_observed_at; // preparation horizon only; not durable yet
      SWV5S5_MvpInitProductionVersion(flat.broker.contract_version); flat.broker.persistence_namespace=flat.scope;
      flat.broker.evidence_id="CONTINUATION-BROKER-ZERO-"+observation.snapshot_digest;
      flat.broker.issuing_component=SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER; flat.broker.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
      flat.broker.evidence_sequence=context.clock_sequence; flat.broker.observed_at=observation.observed_at;
      flat.broker.state_digest=observation.snapshot_digest;
      SWV5S5_MvpInitProductionVersion(flat.persistence.contract_version); flat.persistence.persistence_namespace=flat.scope;
      flat.persistence.evidence_id="CONTINUATION-PERSISTENCE-ZERO-"+flat.physical_snapshot_digest;
      flat.persistence.issuing_component=SWV5_COMPONENT_AUTHORITY_PERSISTENCE; flat.persistence.authority_source=SWV5_AUTHORITY_PERSISTED_CHECKPOINT;
      flat.persistence.evidence_sequence=context.clock_sequence; flat.persistence.observed_at=persistence_observed_at;
      flat.persistence.state_digest=flat.physical_snapshot_digest;
      SWV5S5_MvpInitProductionVersion(flat.exposure.contract_version);
      flat.exposure.evidence_id="CONTINUATION-EXPOSURE-ZERO-"+observation.snapshot_digest;
      flat.exposure.issuing_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE; flat.exposure.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
      flat.exposure.observed_exposure_volume=0.0; flat.exposure.prior_exposure_volume=0.0; flat.exposure.zero_or_reducing=true;
      flat.exposure.evidence_sequence=context.clock_sequence; flat.exposure.observed_at=observation.observed_at;
      return true; // No flat/release authority until a later accepted native clock.
   }
#endif // TEST ONLY diagnostic cannot compile the mutating Flat method.
public:
   // Read-only durable recognition. true means STRUCTURE recognized only;
   // result.accepted remains false. No old A or event-local state is required.
   bool ClassifyStoredPreState(const SWV5S5_MvpContinuationInput &i,ISWV5S5MvpReadOnlyPlatform &platform,
                              SWV5S5_MvpContinuationResult &result)
   {
      SWV5S5_MvpLeaseClockAuthority clock_authority;SWV5S5_MvpSqliteAuthorityStore store;
      SWV5S5_MvpLeaseClockObservation clock;SWV5S5_MvpRuntimeProfileObservation profile;datetime at=0;
      SWV5_ContractValidationContext context;SWV5_InstanceLease lease;
      SWV5S5_MvpAuthorityRow lease_row,current,read_set[];SWV5S5_MvpAccountRiskAuthorityRecord account;
      SWV5S5_ProducerTrustRecord trust;SWV5S5_ProducerTrustAnchor anchor;
      SWV5S5_MvpReconciliationGovernanceBundle governance;SWV5S5_MvpContinuationActivationProof proof;
      SWV5S5_MvpContinuationHistoricalLineage lineage;bool validated_resume=false;
      ZeroMemory(m_result);ZeroMemory(result);m_result.stage="STRUCTURAL_PRE_STATE";
      if(!clock_authority.ConfigureReadOnly(i.path,i.namespace_digest))
      {Stop("PRESTATE_STORE_OR_NAMESPACE_INVALID");result=m_result;return false;}
      const bool recognized=LoadStructuralPreState(i,clock_authority,platform,store,clock,profile,at,context,
         lease,lease_row,current,account,trust,anchor,governance,proof,lineage,validated_resume,read_set);
      clock_authority.Close();store.Close();
      if(recognized){m_result.stage=validated_resume ? "PARTIAL_AUTHORITY_PRESTATE" : "INITIAL_EXPIRED_PRESTATE";
         m_result.reason="NEW_ATTENDED_ATTEMPT_REQUIRED";}
      result=m_result;return recognized;
   }
   // Diagnostic/history distinction only. The optional before-image is NOT
   // persisted authority and is NEVER consumed by Run or mutation boundaries.
   bool ClassifyClockOnlyHistoricalPartial(const SWV5S5_MvpContinuationInput &i,ISWV5S5MvpReadOnlyPlatform &platform,
      const SWV5S5_MvpAuthorityRow &before[],SWV5S5_MvpContinuationResult &result)
   {
      if(!ClassifyStoredPreState(i,platform,result))return false;
      SWV5S5_MvpSqliteAuthorityStore store;SWV5S5_MvpAuthorityRow now[];int changes=0;
      if(!store.OpenReadOnly(i.path,i.namespace_digest) || !store.ReadAllRows(now) || ArraySize(before)!=ArraySize(now))
      {result.reason="PRESTATE_CLOCK_ONLY_SNAPSHOT_INVALID";return false;}
      for(int x=0;x<ArraySize(before);x++)
      {
         if(before[x].domain_key!=now[x].domain_key || before[x].record_key!=now[x].record_key)
         {result.reason="PRESTATE_CLOCK_ONLY_KEYS_CHANGED";return false;}
         if(SWV5S5_MvpContinuationRowExact(before[x],now[x]))continue;
         SWV5S5_MvpLeaseClockObservation old_clock,new_clock;
         if(before[x].domain_key!=SWV5S5_MVP_DOMAIN_OWNERSHIP || before[x].record_key!=SWV5S5_MVP_OWNERSHIP_CLOCK_KEY ||
            !SWV5S5_MvpContinuationRowValid(store,before[x]) || !SWV5S5_MvpDecodeLeaseClockPayload(before[x].payload,old_clock) ||
            !SWV5S5_MvpLeaseClockObservationValid(old_clock) || !SWV5S5_MvpDecodeLeaseClockPayload(now[x].payload,new_clock) ||
            old_clock.clock_sequence==18446744073709551615 || new_clock.clock_sequence!=old_clock.clock_sequence+1 ||
            now[x].logical_revision!=before[x].logical_revision+1 || new_clock.observed_at<old_clock.observed_at ||
            new_clock.platform_observation_id==old_clock.platform_observation_id || new_clock.clock_id!=old_clock.clock_id ||
            new_clock.clock_authority!=old_clock.clock_authority || now[x].updated_at!=new_clock.observed_at)
         {result.reason="PRESTATE_CLOCK_ONLY_EXACT_EVOLUTION_FAILED";return false;}
         changes++;
      }
      store.Close();
      if(changes!=1){result.reason="PRESTATE_CLOCK_ONLY_CHANGE_COUNT_INVALID";return false;}
      result.stage="CLOCK_ONLY_HISTORICAL_PARTIAL";result.reason="NEW_ATTENDED_ATTEMPT_REQUIRED";return true;
   }
   // Completed replay is a historical report, never a fresh authorization.
   // It is invoked before any new acknowledgement/clock write by the wrapper.
   bool ReadCompletedOnly(const SWV5S5_MvpContinuationInput &i,SWV5S5_MvpContinuationResult &result)
   {
      ZeroMemory(result); SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpAuthorityRow row,current,history,flat_row,proof_row;
      SWV5_InstanceLease lease; bool found=false; string latch,payload;
      SWV5S5_MvpHardKillActivationProof activation; SWV5_HardKillState released,inactive;
      SWV5_HardKillReleaseAuthorityRecord authority; SWV5S5_MvpContinuationFlatAuthority flat;
      SWV5S5_MvpContinuationActivationProof proof;
      if(!store.OpenReadOnly(i.path,i.namespace_digest) || !ReadLease(store,lease,row) || !ScopeOwner(i,lease) ||
         !store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,found) || !found ||
         current.state!=(int)SWV5_HARD_KILL_INACTIVE || !SWV5S5_MvpContinuationRowValid(store,current) ||
         !SWV5S5_MvpCanonicalScalar(current.payload,"latch_id","s",latch) ||
         !store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_HISTORY,latch,history,found) || !found ||
         !SWV5S5_MvpContinuationRowValid(store,history) || !SWV5S5_MvpDecodeActivation(history.payload,activation) ||
         !SWV5S5_MvpDecodeReleaseBundle(activation.release_bundle,released,authority) ||
         !SWV5S5_EqualFence(activation.activation_fence,lease.fence) ||
         !store.ReadRow(SWV5S5_MVP_DOMAIN_CONTINUATION_ACTIVATION,released.latch_id,proof_row,found) || !found ||
         !SWV5S5_MvpContinuationRowValid(store,proof_row) || !SWV5S5_MvpDecodeContinuationActivation(proof_row.payload,proof) ||
         proof.continuation_id!=i.continuation_id || !SWV5S5_EqualFence(proof.fence,lease.fence)) return false;
      SWV5S5_MvpAuthorityRow rows[]; int matches=0;
      if(!RowsAllowed(store,released.persistence_namespace,lease.fence,rows)) return false;
      for(int x=0;x<ArraySize(rows);x++) if(rows[x].domain_key==SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT)
      {
         SWV5S5_MvpContinuationFlatAuthority candidate; SWV5_HardKillReleaseEvidence e; SWV5_HardKillReleaseAuthorityRecord a;
         if(SWV5S5_MvpDecodeContinuationFlat(rows[x].payload,candidate) && candidate.active.latch_id==released.latch_id &&
            SWV5S5_MvpIssueContinuationRelease(candidate,e,a) && a.authority_record_id==authority.authority_record_id &&
            a.authority_record_digest==authority.authority_record_digest) {flat=candidate; flat_row=rows[x]; matches++;}
      }
      SWV5_ContractValidationContext historical; ZeroMemory(historical); SWV5S5_MvpInitProductionVersion(historical.expected_version);
      historical.clock_id=activation.clock_id; historical.clock_authority=activation.clock_authority;
      historical.clock_sequence=activation.clock_sequence; historical.clock_time=activation.activated_at;
      if(matches!=1 || current.logical_revision!=activation.released_row.logical_revision+1 ||
         !SWV5S5_MvpCompleteReleaseValid(historical,released,authority) ||
         !store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE,authority.authority_record_id,row,found) || !found ||
         row.payload!=activation.release_bundle || !SWV5S5_MvpContinuationRowValid(store,row) ||
         released.release_generation!=proof.prior_maximum_release_generation+1) return false;
      SWV5S5_MvpNewInactiveEpoch(released,history.payload_digest,inactive);
      if(inactive.latch_generation!=proof.prior_inactive.latch_generation+2 ||
         !SWV5S5_CanonicalHardKillState("hard_kill",inactive,payload) || payload!=current.payload) return false;
      SWV5S5_ProducerTrustRecord trust; SWV5S5_ProducerTrustAnchor anchor; SWV5S5_MvpReconciliationGovernanceBundle governance;
      if(!ReadTrust(i,trust,anchor) || !ReadGovernance(store,governance,row)) return false;
      result.effective_expiry=authority.expires_at;
      if(lease.expires_at<result.effective_expiry) result.effective_expiry=lease.expires_at;
      if(trust.valid_until<result.effective_expiry) result.effective_expiry=trust.valid_until;
      if(governance.valid_until<result.effective_expiry) result.effective_expiry=governance.valid_until;
      result.accepted=true; result.already_complete=true; result.reason="ALREADY_COMPLETE_READBACK_ONLY";
      result.initial_latch_generation=proof.prior_inactive.latch_generation;
      result.final_latch_generation=inactive.latch_generation; result.release_generation=released.release_generation;
      return true;
   }
private:
   bool LoadStructuralPreState(const SWV5S5_MvpContinuationInput &i,SWV5S5_MvpLeaseClockAuthority &clock_authority,
      ISWV5S5MvpReadOnlyPlatform &platform,SWV5S5_MvpSqliteAuthorityStore &store,
      SWV5S5_MvpLeaseClockObservation &clock,SWV5S5_MvpRuntimeProfileObservation &profile,datetime &at,
      SWV5_ContractValidationContext &context,SWV5_InstanceLease &lease,SWV5S5_MvpAuthorityRow &lease_row,
      SWV5S5_MvpAuthorityRow &current,SWV5S5_MvpAccountRiskAuthorityRecord &account,
      SWV5S5_ProducerTrustRecord &trust,SWV5S5_ProducerTrustAnchor &anchor,
      SWV5S5_MvpReconciliationGovernanceBundle &governance,SWV5S5_MvpContinuationActivationProof &proof,
      SWV5S5_MvpContinuationHistoricalLineage &lineage,bool &validated_resume,SWV5S5_MvpAuthorityRow &read_set[])
   {
      ZeroMemory(context);validated_resume=false;SWV5S5_MvpAuthorityRow row,clock_row;bool found=false;
      SWV5S5_MvpAccountRiskAuthority account_owner;
#define CONTINUATION_PRESTATE_REQUIRE(condition,detail) if(!(condition)) return Stop(detail)
      CONTINUATION_PRESTATE_REQUIRE(i.continuation_id!="" && i.lease_seconds!=0,"PRESTATE_INPUT_INVALID");
      CONTINUATION_PRESTATE_REQUIRE(clock_authority.LoadStored(clock,clock_row,found),"PRESTATE_CLOCK_PHYSICAL_INVALID");
      CONTINUATION_PRESTATE_REQUIRE(found,"PRESTATE_CLOCK_MISSING");
      CONTINUATION_PRESTATE_REQUIRE(clock_row.updated_at==clock.observed_at,"PRESTATE_CLOCK_UPDATED_AT_INVALID");
      CONTINUATION_PRESTATE_REQUIRE(platform.CaptureProfile(SWV5S5_MVP_SYMBOL,profile,at),"PRESTATE_PROFILE_CAPTURE_FAILED");
      CONTINUATION_PRESTATE_REQUIRE(SWV5S5_MvpProfileMatches(profile,ACCOUNT_TRADE_MODE_DEMO),"PRESTATE_PROFILE_MISMATCH");
      string expected_clock_id;
      CONTINUATION_PRESTATE_REQUIRE(SWV5S5_MvpLeaseClockId(profile.broker_identity,profile.server,profile.account_login,
         profile.symbol,expected_clock_id) && clock.clock_id==expected_clock_id && clock.broker_identity==profile.broker_identity &&
         clock.server==profile.server && clock.account_login==profile.account_login && clock.source_symbol==profile.symbol &&
         clock.clock_authority==SWV5_TIME_AUTHORITY_BROKER_SERVER,"PRESTATE_CLOCK_PROFILE_BINDING_INVALID");
      CONTINUATION_PRESTATE_REQUIRE(store.OpenReadOnly(i.path,i.namespace_digest),"PRESTATE_STORE_OR_NAMESPACE_INVALID");
      CONTINUATION_PRESTATE_REQUIRE(store.ReadAllRows(read_set),"PRESTATE_INVENTORY_READ_FAILED");
      SWV5S5_MvpAuthorityRow exact_clock;
      CONTINUATION_PRESTATE_REQUIRE(store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_CLOCK_KEY,exact_clock,found) &&
         found && SWV5S5_MvpContinuationRowExact(exact_clock,clock_row),"PRESTATE_CLOCK_TARGET_BINDING_INVALID");
      CONTINUATION_PRESTATE_REQUIRE(ReadLease(store,lease,lease_row),"PRESTATE_OWNERSHIP_INVALID");
      CONTINUATION_PRESTATE_REQUIRE(ScopeOwner(i,lease),"PRESTATE_OWNER_IDENTITY_MISMATCH");
      CONTINUATION_PRESTATE_REQUIRE(lease.clock_id==clock.clock_id && lease.clock_authority==clock.clock_authority &&
         clock.clock_sequence>=lease.heartbeat_clock_sequence && clock.observed_at>=lease.heartbeat_at,
         "PRESTATE_CLOCK_OWNERSHIP_MONOTONICITY_INVALID");
      CONTINUATION_PRESTATE_REQUIRE(ReadTrust(i,trust,anchor),"PRESTATE_TRUST_INVALID");
      CONTINUATION_PRESTATE_REQUIRE(account_owner.ValidateCurrent(store,trust.persistence_namespace,profile,account,row),"PRESTATE_ACCOUNT_INVALID");
      CONTINUATION_PRESTATE_REQUIRE(ReadGovernance(store,governance,row),"PRESTATE_GOVERNANCE_INVALID");
      CONTINUATION_PRESTATE_REQUIRE(SWV5S5_EqualNamespace(governance.profile.persistence_namespace,account.persistence_namespace),"PRESTATE_NAMESPACE_MISMATCH");
      CONTINUATION_PRESTATE_REQUIRE(governance.correlation_policy.approval_reference==i.approval_reference &&
         governance.capability_proof.proof_source_reference==i.proof_reference,"PRESTATE_OTHER_EXACT_BINDING_FAILED/GOVERNANCE_REFERENCES");
      CONTINUATION_PRESTATE_REQUIRE(store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,found) && found &&
         SWV5S5_MvpContinuationRowValid(store,current),"PRESTATE_HARD_KILL_INVALID");
#undef CONTINUATION_PRESTATE_REQUIRE
      SWV5S5_MvpInitProductionVersion(context.expected_version); context.clock_id=clock.clock_id; context.clock_authority=clock.clock_authority;
      // Native read-only diagnostic time evaluates expiry/history, not a
      // fabricated accepted event. Persisted clock observation stays intact.
      context.clock_sequence=clock.clock_sequence; context.evaluation_sequence=clock.clock_sequence; context.clock_time=at;
      context.price_tolerance=1.0e-7; context.volume_tolerance=1.0e-7;
      SWV5S5_MvpAuthorityRow all[];
      string state_reason;
      if(!EmptyExecutionAndBasketDiagnostic(store,context,account.persistence_namespace,lease,state_reason))
      {return Stop(state_reason);}
      if(!RowsAllowedDiagnostic(store,account.persistence_namespace,lease.fence,all,state_reason))
      {return Stop(state_reason);}
      SWV5S5_MvpContinuationStructuralReader structural; string latch;
      if(!SWV5S5_MvpCanonicalScalar(current.payload,"latch_id","s",latch))
      { return Stop("CONTINUATION_LATCH_INVALID"); }
      if(current.state==(int)SWV5_HARD_KILL_INACTIVE)
      {
         if(!structural.LoadExpiredInactive(store,context,lease,account.persistence_namespace,account.account_namespace,lineage))
         { return Stop("CONTINUATION_EXPIRED_INACTIVE_LINEAGE_REQUIRED"); }
      }
      else
      {
         if(!store.ReadRow(SWV5S5_MVP_DOMAIN_CONTINUATION_ACTIVATION,latch,row,found) || !found ||
            !SWV5S5_MvpDecodeContinuationActivation(row.payload,proof) || proof.continuation_id!=i.continuation_id ||
            !SWV5S5_EqualFence(proof.fence,lease.fence) || !ResumeProofValid(store,context,proof,lease,current))
         { return Stop("CONTINUATION_ACTIVE_PROVENANCE_REQUIRED"); }
         validated_resume=true;
      }
      SWV5S5_MvpAuthorityRow final_rows[];
      if(!store.ReadAllRows(final_rows) || ArraySize(final_rows)!=ArraySize(read_set))return Stop("PRESTATE_STRUCTURAL_READSET_CHANGED");
      for(int x=0;x<ArraySize(read_set);x++)if(!SWV5S5_MvpContinuationRowExact(read_set[x],final_rows[x]))
         return Stop("PRESTATE_STRUCTURAL_READSET_CHANGED");
      return true;
   }

#ifndef SWV5S5_TEST_ONLY_RESUME_CLOCK_CLASSIFIER
   bool CompleteRelease(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_ContractValidationContext &context,
      const SWV5S5_MvpOperatorInvocation &op,const SWV5S5_MvpContinuationFlatAuthority &flat,
      const SWV5_InstanceLease &lease,SWV5S5_MvpAuthorityRow &current,const SWV5S5_MvpContinuationActivationProof &proof,
      const SWV5S5_ProducerTrustRecord &trust,const SWV5S5_MvpReconciliationGovernanceBundle &governance,
      const bool validated_resume,SWV5S5_MvpContinuationResult &result)
   {
      SWV5_HardKillState released;SWV5S5_MvpAuthorityRow row;
      if(current.state==(int)SWV5_HARD_KILL_RELEASED)
      {
         // CURRENT is the canonical hard_kill envelope, NOT the generated
         // typed-state codec. Decode the immutable complete bundle instead,
         // then require its canonical projection to match physical CURRENT.
         // flat.op is historical A1; op is A2 only for the later activation.
         // Neither the bundle nor its operator/evidence timestamps is rewritten.
         SWV5_HardKillReleaseEvidence evidence;SWV5_HardKillReleaseAuthorityRecord expected,record;
         SWV5S5_MvpAuthorityRow complete;bool found=false;string payload;
         if(!SWV5S5_MvpIssueContinuationRelease(flat,evidence,expected) ||
            !store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE,expected.authority_record_id,complete,found) || !found ||
            complete.logical_revision!=1 || complete.state!=(int)SWV5_HARD_KILL_RELEASED ||
            !SWV5S5_MvpContinuationRowValid(store,complete) || !SWV5S5_MvpContinuationRowValid(store,current) ||
            !SWV5S5_MvpDecodeReleaseBundle(complete.payload,released,record) ||
            record.authority_record_id!=expected.authority_record_id ||
            !SWV5S5_CanonicalHardKillState("hard_kill",released,payload) || payload!=current.payload ||
            !SWV5S5_MvpCompleteReleaseValid(context,released,record))
         {Stop("PARTIAL_CONTINUATION/RELEASED_PHYSICAL_BUNDLE_INVALID");result=m_result;return false;}
      }
      SWV5S5_MvpAuthorityRow physical[];
      if(!SWV5S5_MvpContinuationBoundRowsCurrent(store,context,flat,validated_resume,physical))
      { Stop("PARTIAL_CONTINUATION/FLAT_STALE_BEFORE_RELEASE"); result=m_result; return false; }
      if(current.state==(int)SWV5_HARD_KILL_RELEASE_PENDING)
      {
         m_result.stage="RELEASED";
         if(!SWV5S5_MvpPersistApprovedContinuationRelease(store,context,flat,lease,current,validated_resume,released,row))
         { Stop("PARTIAL_CONTINUATION/RELEASE_PERSIST_FAILED"); result=m_result; return false; }
         current=row;
      }
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
      if(SWV5S5_TestContinuationStopStage("RELEASED")) {Stop("PARTIAL_CONTINUATION/TEST_INTERRUPTION_RELEASED"); result=m_result; return false;}
#endif
      m_result.stage="FINAL_INACTIVE"; SWV5_HardKillState inactive; SWV5S5_MvpHardKillActivationAuthority activation;
      if(released.release_generation!=proof.prior_maximum_release_generation+1 ||
         released.latch_generation!=proof.prior_inactive.latch_generation+1 ||
         !activation.TryActivateInactiveAfterValidatedRelease(store,context,op,true,released,lease,current,inactive,row) ||
         inactive.latch_generation!=proof.prior_inactive.latch_generation+2 ||
         !activation.EligibilityHorizon(store,context,inactive,lease,m_result.effective_expiry))
      { Stop("PARTIAL_CONTINUATION/FINAL_INACTIVE_FAILED"); result=m_result; return false; }
      if(lease.expires_at<m_result.effective_expiry) m_result.effective_expiry=lease.expires_at;
      if(trust.valid_until<m_result.effective_expiry) m_result.effective_expiry=trust.valid_until;
      if(governance.valid_until<m_result.effective_expiry) m_result.effective_expiry=governance.valid_until;
      m_result.initial_latch_generation=proof.prior_inactive.latch_generation;
      m_result.final_latch_generation=inactive.latch_generation; m_result.release_generation=released.release_generation;
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
      if(SWV5S5_TestContinuationStopStage("INACTIVE")) {Stop("PARTIAL_CONTINUATION/TEST_INTERRUPTION_INACTIVE"); result=m_result; return false;}
#endif
      m_result.accepted=true; m_result.partial_continuation=false; m_result.reason="ATTENDED_CONTINUATION_COMPLETE_ZERO_SUBMISSION";
      result=m_result; return true;
   }
   bool AwaitFinalClock(const SWV5S5_MvpContinuationInput &i,const SWV5S5_MvpOperatorInvocation &op,
      const SWV5S5_MvpLeaseClockObservation &event_clock,const SWV5S5_MvpContinuationFlatAuthority &flat,
      const datetime observation_horizon,const bool already_durable,SWV5S5_MvpSqliteAuthorityStore &store,
      SWV5S5_MvpContinuationResult &result)
   {
      if(!store.ReadAllRows(m_finalization_rows))
      {Stop("PARTIAL_CONTINUATION/FINALIZATION_SNAPSHOT_FAILED");result=m_result;return false;}
      m_attended_input=i;m_attended_op=op;m_prepared_flat=flat;
      m_initial_event_time=event_clock.observed_at;m_initial_event_sequence=event_clock.clock_sequence;
      m_observation_horizon=observation_horizon;m_flat_already_durable=already_durable;
      m_waiting_finalization=true;m_result.partial_continuation=true;m_result.stage="WAIT_FINALIZATION";
      m_result.reason="CONTINUATION_WAIT_LATER_ACCEPTED_FINALIZATION_CLOCK";result=m_result;return false;
   }
   bool FinishFinalization(const SWV5S5_MvpContinuationInput &i,const SWV5S5_MvpOperatorInvocation &op,
      SWV5S5_MvpLeaseClockAuthority &clock_authority,ISWV5S5MvpReadOnlyPlatform &platform,
      SWV5S5_MvpContinuationResult &result)
   {
      m_waiting_finalization=false; // consumed once; failures never schedule retry
      string a,b,digest;ZeroMemory(m_result);m_result.stage="FINALIZATION_CLOCK";m_result.partial_continuation=true;
      if(!i.acknowledged || i.path!=m_attended_input.path || i.namespace_digest!=m_attended_input.namespace_digest ||
         i.continuation_id!=m_attended_input.continuation_id || i.approval_reference!=m_attended_input.approval_reference ||
         i.proof_reference!=m_attended_input.proof_reference || i.trust_anchor_id!=m_attended_input.trust_anchor_id ||
         i.lease_seconds!=m_attended_input.lease_seconds ||
         !SWV5S5_MvpCodecEncode_SWV5_OwnerIdentity(i.configured_owner,a) ||
         !SWV5S5_MvpCodecEncode_SWV5_OwnerIdentity(m_attended_input.configured_owner,b) || a!=b ||
         !SWV5S5_MvpOperatorPayload(op,a,digest) || !SWV5S5_MvpOperatorPayload(m_attended_op,b,digest) || a!=b)
      {Stop("PARTIAL_CONTINUATION/ATTENDED_INVOCATION_IDENTITY_CHANGED");result=m_result;return false;}
      SWV5S5_MvpLeaseClockObservation final_clock,stored;SWV5S5_MvpAuthorityRow clock_row;bool found=false;
      if(!clock_authority.CurrentFreshObservation(final_clock) || !clock_authority.LoadStored(stored,clock_row,found) || !found ||
         !SWV5S5_MvpLeaseClockPayload(final_clock,a,digest) || !SWV5S5_MvpLeaseClockPayload(stored,b,digest) || a!=b ||
         final_clock.clock_id!=m_prepared_flat.clock_id || final_clock.clock_authority!=m_prepared_flat.clock_authority ||
         final_clock.clock_sequence!=m_initial_event_sequence+1 || final_clock.observed_at<=m_initial_event_time ||
         final_clock.observed_at<m_observation_horizon || !SWV5S5_MvpOperatorInvocationValid(op,final_clock.observed_at))
      {Stop("PARTIAL_CONTINUATION/LATER_ACCEPTED_FINALIZATION_CLOCK_REQUIRED");result=m_result;return false;}
      SWV5_ContractValidationContext context;SWV5S5_MvpSqliteAuthorityStore store;
      SWV5S5_MvpRuntimeProfileObservation profile;datetime at=0;SWV5_InstanceLease lease;
      SWV5S5_MvpAuthorityRow lease_row,current,rows[];SWV5S5_MvpAccountRiskAuthorityRecord account;
      SWV5S5_ProducerTrustRecord trust;SWV5S5_ProducerTrustAnchor anchor;SWV5S5_MvpReconciliationGovernanceBundle governance;
      SWV5S5_MvpContinuationActivationProof proof;SWV5S5_MvpContinuationHistoricalLineage lineage;bool validated_resume=false;
      if(!LoadStructuralPreState(i,clock_authority,platform,store,stored,profile,at,context,lease,lease_row,current,
         account,trust,anchor,governance,proof,lineage,validated_resume,rows) || at<final_clock.observed_at ||
         ArraySize(rows)!=ArraySize(m_finalization_rows))
      {Stop("PARTIAL_CONTINUATION/FINALIZATION_PRESTATE_CHANGED");result=m_result;return false;}
      int clock_changes=0;
      for(int x=0;x<ArraySize(rows);x++)
      {
         if(rows[x].domain_key==SWV5S5_MVP_DOMAIN_OWNERSHIP && rows[x].record_key==SWV5S5_MVP_OWNERSHIP_CLOCK_KEY)
         {
            SWV5S5_MvpLeaseClockObservation old;
            if(!SWV5S5_MvpDecodeLeaseClockPayload(m_finalization_rows[x].payload,old) ||
               old.clock_id!=final_clock.clock_id || old.clock_sequence!=m_initial_event_sequence ||
               old.observed_at!=m_initial_event_time || rows[x].logical_revision!=m_finalization_rows[x].logical_revision+1 ||
               !SWV5S5_MvpContinuationRowExact(rows[x],clock_row))
            {Stop("PARTIAL_CONTINUATION/FINALIZATION_CLOCK_LINEAGE_CHANGED");result=m_result;return false;}
            clock_changes++;continue;
         }
         if(!SWV5S5_MvpContinuationRowExact(rows[x],m_finalization_rows[x]))
         {Stop("PARTIAL_CONTINUATION/FINALIZATION_NONCLOCK_ROW_CHANGED");result=m_result;return false;}
      }
      if(clock_changes!=1){Stop("PARTIAL_CONTINUATION/FINALIZATION_CLOCK_MISSING");result=m_result;return false;}
      context.clock_time=final_clock.observed_at;context.clock_sequence=final_clock.clock_sequence;
      context.evaluation_sequence=final_clock.clock_sequence; // real accepted event, NOT read-only time
      store.Close();
      if(!store.Open(i.path,i.namespace_digest))
      {Stop("PARTIAL_CONTINUATION/FINALIZATION_STORE_FAILED");result=m_result;return false;}
      SWV5S5_MvpContinuationFlatAuthority flat=m_prepared_flat;
      if(!m_flat_already_durable)
      {
         flat.clock_sequence=final_clock.clock_sequence;flat.observed_at=final_clock.observed_at;
         flat.broker.evidence_sequence=final_clock.clock_sequence;flat.persistence.evidence_sequence=final_clock.clock_sequence;
         flat.exposure.evidence_sequence=final_clock.clock_sequence; // observation timestamps are NEVER rewritten
         string payload;SWV5S5_MvpAuthorityRow missing,committed,unused,readback;SWV5S5_MvpAuthorityMutation mutation,none;ZeroMemory(none);
         if(!SWV5S5_MvpContinuationPhysicalInvariants(store,context,flat) ||
            !SWV5S5_MvpContinuationFlatDigest(flat,flat.authority_digest) ||
            !SWV5S5_MvpContinuationFlatPayload(flat,true,payload) || !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT,payload,digest) ||
            !store.ReadRow(SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT,flat.key,missing,found) || found)
         {Stop("PARTIAL_CONTINUATION/FINAL_FLAT_INVALID");result=m_result;return false;}
         SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT,flat.key,missing,false,1,1,digest,payload,context.clock_time,mutation);
         if(!store.CompareAndSetWithExactSnapshot(mutation,false,none,rows,committed,unused) ||
            !store.ReadRow(SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT,flat.key,readback,found) || !found ||
            !SWV5S5_MvpContinuationRowExact(committed,readback))
         {Stop("PARTIAL_CONTINUATION/FINAL_FLAT_CAS_FAILED");result=m_result;return false;}
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
         if(SWV5S5_TestContinuationStopStage("FLAT")){Stop("PARTIAL_CONTINUATION/TEST_INTERRUPTION_FLAT");result=m_result;return false;}
#endif
         m_result.stage="RELEASE_PENDING";SWV5_HardKillState pending;
         if(!SWV5S5_MvpStageContinuationPending(store,context,op,flat,pending,current))
         {Stop("PARTIAL_CONTINUATION/PENDING_FAILED");result=m_result;return false;}
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
         if(SWV5S5_TestContinuationStopStage("PENDING")){Stop("PARTIAL_CONTINUATION/TEST_INTERRUPTION_PENDING");result=m_result;return false;}
#endif
      }
      Print("ATTENDED_CONTINUATION_FINAL_CLOCK|T0=",(long)op.authenticated_at,"|broker_T1=",(long)flat.broker.observed_at,
         "|persistence_T1=",(long)flat.persistence.observed_at,"|exposure_T1=",(long)flat.exposure.observed_at,
         "|T2=",(long)context.clock_time,"|accepted_sequence=",context.clock_sequence,"|broker_submission_calls=0");
      return CompleteRelease(store,context,op,flat,lease,current,proof,trust,governance,m_flat_already_durable,result);
   }
#endif
public:
   SWV5S5_MvpAttendedContinuation(){m_waiting_finalization=false;m_initial_event_time=0;m_observation_horizon=0;m_initial_event_sequence=0;}
   bool AwaitingFinalization(){return m_waiting_finalization;}
   datetime FinalizationNotBefore(){return m_observation_horizon>m_initial_event_time ? m_observation_horizon : m_initial_event_time+1;}
   bool Run(const SWV5S5_MvpContinuationInput &i,const SWV5S5_MvpOperatorInvocation &op,
      SWV5S5_MvpLeaseClockAuthority &clock_authority,ISWV5S5MvpReadOnlyPlatform &platform,
      ISWV5S5MvpBootstrapBrokerObserver &broker,SWV5S5_MvpContinuationResult &result)
   {
#ifndef SWV5S5_TEST_ONLY_RESUME_CLOCK_CLASSIFIER
      if(m_waiting_finalization)return FinishFinalization(i,op,clock_authority,platform,result);
#endif
      ZeroMemory(m_result);m_result.stage="PRE_STATE";
      if(ReadCompletedOnly(i,result))return true; // Historical report only.
      SWV5S5_MvpLeaseClockObservation clock,event_clock;SWV5S5_MvpRuntimeProfileObservation profile;datetime at=0;
      SWV5_ContractValidationContext context;SWV5S5_MvpSqliteAuthorityStore store;
      SWV5_InstanceLease lease;SWV5S5_MvpAuthorityRow lease_row,current,row,structural_rows[];
      SWV5S5_MvpAccountRiskAuthorityRecord account;SWV5S5_ProducerTrustRecord trust;SWV5S5_ProducerTrustAnchor anchor;
      SWV5S5_MvpReconciliationGovernanceBundle governance;SWV5S5_MvpContinuationActivationProof proof;
      SWV5S5_MvpContinuationHistoricalLineage lineage;bool validated_resume=false;
      if(!LoadStructuralPreState(i,clock_authority,platform,store,clock,profile,at,context,lease,lease_row,current,
         account,trust,anchor,governance,proof,lineage,validated_resume,structural_rows)){result=m_result;return false;}
#ifdef SWV5S5_TEST_ONLY_RESUME_CLOCK_CLASSIFIER
      m_result.reason="NEW_ATTENDED_ATTEMPT_REQUIRED";result=m_result;return true;
#else
      // Authority-bearing path MUST prove a newly published current event;
      // structural recognition never recreates this object's freshness flag.
      string stored_payload,event_payload,digest;
      if(!i.acknowledged || !clock_authority.CurrentFreshObservation(event_clock) ||
         !SWV5S5_MvpLeaseClockPayload(clock,stored_payload,digest) ||
         !SWV5S5_MvpLeaseClockPayload(event_clock,event_payload,digest) || stored_payload!=event_payload ||
         !SWV5S5_MvpOperatorInvocationValid(op,event_clock.observed_at) ||
         op.authenticated_at!=event_clock.observed_at || at<event_clock.observed_at)
      {
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
         Print("CONTINUATION_EVENT_STATE|id=",i.continuation_id,"|fresh_event_acquired=",event_clock.clock_sequence>0,
            "|ack=",i.acknowledged,"|stored_time=",(long)clock.observed_at,"|event_time=",(long)event_clock.observed_at,
            "|profile_time=",(long)at,"|stored_sequence=",clock.clock_sequence,"|event_sequence=",event_clock.clock_sequence,
            "|payload_equal=",stored_payload==event_payload,"|heartbeat=NOT_ATTEMPTED|trust=NOT_ATTEMPTED|governance=NOT_ATTEMPTED");
#endif
         Stop("CONTINUATION_NEW_ATTENDED_EVENT_FRESHNESS_REQUIRED");result=m_result;return false;
      }
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
      Print("CONTINUATION_EVENT_STATE|id=",i.continuation_id,"|fresh_event_acquired=true|fresh_gate=PASS|event_time=",
         (long)event_clock.observed_at,"|event_sequence=",event_clock.clock_sequence,
         "|heartbeat=NOT_ATTEMPTED|trust=NOT_ATTEMPTED|governance=NOT_ATTEMPTED");
#endif
      clock=event_clock;context.clock_time=event_clock.observed_at;
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
      if(SWV5S5_TestContinuationStopStage("EVENT_READY"))
      {m_result.partial_continuation=true;Stop("PARTIAL_CONTINUATION/TEST_INTERRUPTION_EVENT_READY");result=m_result;return false;}
#endif
      // Reopen for mutation only AFTER the fresh-event gate, then require the
      // complete structural read-set exact. No unexplained non-clock mutation.
      SWV5S5_MvpAuthorityRow mutation_rows[];
      store.Close();
      if(!store.Open(i.path,i.namespace_digest) || !store.ReadAllRows(mutation_rows) || ArraySize(structural_rows)!=ArraySize(mutation_rows))
      {Stop("CONTINUATION_STRUCTURAL_SNAPSHOT_CHANGED");result=m_result;return false;}
      for(int x=0;x<ArraySize(structural_rows);x++)if(!SWV5S5_MvpContinuationRowExact(structural_rows[x],mutation_rows[x]))
      {Stop("CONTINUATION_STRUCTURAL_SNAPSHOT_CHANGED");result=m_result;return false;}
      SWV5S5_MvpBootstrapBrokerObservation abort_only;
      if(!SWV5S5_MvpContinuationBrokerZero(broker,account.account_namespace,context.clock_time,abort_only))
      { Stop("CONTINUATION_BROKER_PRE_GATE_NOT_ZERO"); result=m_result; return false; }
      m_result.partial_continuation=true;
      if(current.state==(int)SWV5_HARD_KILL_INACTIVE ||
         (current.state==(int)SWV5_HARD_KILL_ACTIVE &&
          (lease.expires_at<=context.clock_time || trust.valid_until<=context.clock_time || governance.valid_until<=context.clock_time)))
      {
         m_result.stage="OWNERSHIP_HEARTBEAT";
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
         Print("CONTINUATION_STAGE_TRACE|ATTEMPT|id=",i.continuation_id,"|stage=OWNERSHIP_HEARTBEAT");
#endif
         SWV5S5_MvpInitialOwnershipAuthority owner; SWV5_InstanceLease renewed;
         if(!owner.Configure(i.path,i.namespace_digest) ||
            !owner.HeartbeatAttended(i.acknowledged,op,i.configured_owner,lease,lease_row,i.lease_seconds,clock_authority,renewed,row))
         { Stop("PARTIAL_CONTINUATION/HEARTBEAT_FAILED"); result=m_result; return false; }
         lease=renewed; lease_row=row;
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
         Print("CONTINUATION_STAGE_TRACE|PASS|id=",i.continuation_id,"|stage=OWNERSHIP_HEARTBEAT");
         if(SWV5S5_TestContinuationStopStage("HEARTBEAT")) {Stop("PARTIAL_CONTINUATION/TEST_INTERRUPTION_HEARTBEAT"); result=m_result; return false;}
#endif
         m_result.stage="TRUST_REFRESH";
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
         Print("CONTINUATION_STAGE_TRACE|ATTEMPT|id=",i.continuation_id,"|stage=TRUST_REFRESH");
#endif
         SWV5S5_ProducerTrustScope scope; ZeroMemory(scope); scope.persistence_namespace=trust.persistence_namespace;
         scope.producer_component=trust.producer_component; scope.producer_instance=trust.producer_instance; scope.producer_epoch=trust.producer_epoch;
         scope.symbol=trust.symbol; scope.timeframe=trust.timeframe; scope.execution_mode=trust.execution_mode;
         scope.publication_clock_id=clock.clock_id; scope.publication_clock_authority=clock.clock_authority; scope.ingress_identity="";
         SWV5S5_MvpManualProducerTrustProvisioner trust_owner; SWV5S5_ProducerTrustRecord refreshed;
         if(!trust_owner.Configure(i.path,i.namespace_digest) || !trust_owner.Provision(op,anchor,scope,context.clock_time,refreshed) ||
            !ReadTrust(i,trust,anchor) || refreshed.record_digest!=trust.record_digest)
         { Stop("PARTIAL_CONTINUATION/TRUST_FAILED"); result=m_result; return false; }
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
         Print("CONTINUATION_STAGE_TRACE|PASS|id=",i.continuation_id,"|stage=TRUST_REFRESH");
         if(SWV5S5_TestContinuationStopStage("TRUST")) {Stop("PARTIAL_CONTINUATION/TEST_INTERRUPTION_TRUST"); result=m_result; return false;}
#endif
         m_result.stage="GOVERNANCE_REFRESH";
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
         Print("CONTINUATION_STAGE_TRACE|ATTEMPT|id=",i.continuation_id,"|stage=GOVERNANCE_REFRESH");
#endif
         SWV5S5_MvpReconciliationGovernanceAuthority g_owner; SWV5S5_MvpReconciliationGovernanceBundle refreshed_g;
         if(!ReadGovernance(store,governance,row) || !g_owner.Configure(i.path,i.namespace_digest) ||
            !g_owner.RefreshCurrent(i.acknowledged,op,clock_authority,clock,governance,row,governance.profile,i.approval_reference,i.proof_reference,
               context.clock_time+(datetime)SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS,refreshed_g,row))
         { Stop("PARTIAL_CONTINUATION/GOVERNANCE_FAILED"); result=m_result; return false; }
         governance=refreshed_g;
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
         Print("CONTINUATION_STAGE_TRACE|PASS|id=",i.continuation_id,"|stage=GOVERNANCE_REFRESH");
         if(SWV5S5_TestContinuationStopStage("GOVERNANCE")) {Stop("PARTIAL_CONTINUATION/TEST_INTERRUPTION_GOVERNANCE"); result=m_result; return false;}
#endif
         if(current.state==(int)SWV5_HARD_KILL_INACTIVE)
         {
            m_result.stage="ACTIVE_CONTINUATION";
            if(!SWV5S5_MvpContinuationActivate(store,i.continuation_id,context,op,lease,lease_row,lineage,proof,current))
            { Stop("PARTIAL_CONTINUATION/ACTIVE_CAS_FAILED"); result=m_result; return false; }
         }
      }
#ifdef SWV5S5_TEST_CONTINUATION_FAULTS
      if(SWV5S5_TestContinuationStopStage("ACTIVE")) {Stop("PARTIAL_CONTINUATION/TEST_INTERRUPTION_ACTIVE"); result=m_result; return false;}
#endif
      if(!SWV5S5_MvpLeaseCurrentForClock(context,lease.fence,lease) || trust.valid_until<=context.clock_time ||
         governance.valid_until<=context.clock_time)
      { Stop("PARTIAL_CONTINUATION/REVIEW_EXPIRED_REFRESHED_AUTHORITY"); result=m_result; return false; }
      SWV5S5_MvpContinuationFlatAuthority flat;
      SWV5_HardKillReleaseEvidence evidence; SWV5_HardKillReleaseAuthorityRecord authority; SWV5_HardKillState released;
      if(current.state==(int)SWV5_HARD_KILL_ACTIVE)
      {
         string active_payload;
         if(!SWV5S5_MvpCodecEncode_SWV5_HardKillState(proof.active,active_payload) || current.payload!=active_payload)
         { Stop("PARTIAL_CONTINUATION/ACTIVE_EXACT_BINDING_FAILED"); result=m_result; return false; }
         m_result.stage="AUTHORITATIVE_FLAT_OBSERVATION";
         if(!Flat(store,i,context,op,account.account_namespace,lease,proof.active,broker,flat))
         { Stop("PARTIAL_CONTINUATION/FLAT_FAILED"); result=m_result; return false; }
         return AwaitFinalClock(i,op,event_clock,flat,flat.persistence.observed_at,false,store,result);
      }
      else
      {
         int matches=0; SWV5S5_MvpAuthorityRow rows[]; string payload;
         if(!RowsAllowed(store,account.persistence_namespace,lease.fence,rows))
         { Stop("PARTIAL_CONTINUATION/RESUME_INVENTORY_INVALID"); result=m_result; return false; }
         for(int x=0;x<ArraySize(rows);x++) if(rows[x].domain_key==SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT)
         {
            SWV5S5_MvpContinuationFlatAuthority candidate;
            if(!SWV5S5_MvpDecodeContinuationFlat(rows[x].payload,candidate) || candidate.active.latch_id!=proof.active.latch_id) continue;
            SWV5_HardKillReleaseEvidence e; SWV5_HardKillReleaseAuthorityRecord a; SWV5_HardKillState state=candidate.active;
            if(!SWV5S5_MvpIssueContinuationRelease(candidate,e,a)) continue;
            state.state=SWV5_HARD_KILL_RELEASE_PENDING; state.release_evidence=e;
            if(current.state==(int)SWV5_HARD_KILL_RELEASED)
            {
               state.state=SWV5_HARD_KILL_RELEASED; state.release_generation=e.release_generation;
               state.release_authority_reference.contract_version=a.contract_version;
               state.release_authority_reference.authority_record_id=a.authority_record_id;
               state.release_authority_reference.authority_record_sequence=a.release_record_sequence;
               state.release_authority_reference.authority_record_digest=a.authority_record_digest;
               state.release_authority_reference.release_id=a.release_id;
               state.release_authority_reference.latch_generation=a.latch_generation;
               state.release_authority_reference.release_generation=a.release_generation;
            }
            if(SWV5S5_CanonicalHardKillState("hard_kill",state,payload) && current.payload==payload)
            { flat=candidate; evidence=e; authority=a; released=state; matches++; }
         }
         if(matches!=1 || context.clock_time>=evidence.expires_at)
         { Stop("PARTIAL_CONTINUATION/EXACT_OR_UNEXPIRED_RESUME_RELEASE_REQUIRED"); result=m_result; return false; }
      }
      datetime horizon=abort_only.observed_at;
      if(flat.persistence.observed_at>horizon)horizon=flat.persistence.observed_at;
      return AwaitFinalClock(i,op,event_clock,flat,horizon,true,store,result);
#endif // SWV5S5_TEST_ONLY_RESUME_CLOCK_CLASSIFIER
   }
};
#endif
