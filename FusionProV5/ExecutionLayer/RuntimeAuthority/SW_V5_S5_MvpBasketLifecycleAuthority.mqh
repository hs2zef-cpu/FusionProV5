#ifndef SW_V5_S5_MVP_BASKET_LIFECYCLE_AUTHORITY_MQH
#define SW_V5_S5_MVP_BASKET_LIFECYCLE_AUTHORITY_MQH

// Sole MVP operational Basket owner. NO SUBMISSION API / NO RECOVERY TRADING.
#include "SW_V5_S5_MvpBasketStateMachine.mqh"
#include "SW_V5_S5_MvpOwnershipAuthority.mqh"

const string SWV5S5_MVP_DOMAIN_BASKET="MVP_CANONICAL_BASKET";
const string SWV5S5_MVP_DOMAIN_BASKET_HISTORY="MVP_CANONICAL_BASKET_HISTORY";

bool SWV5S5_MvpBasketPayload(const SWV5_BasketAggregate &basket,string &payload,string &digest)
{
   return SWV5S5_MvpCodecEncode_SWV5_BasketAggregate(basket,payload) &&
      SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_BASKET,payload,digest);
}

// Complete ordered history, not a projection of local version arithmetic.
struct SWV5S5_MvpBasketHistory
{
   SWV5_BasketAggregate prior,opening,active;
   SWV5_BasketTransitionRequest opening_request,active_request;
   string positive_digest,claim_digest,prior_revision;
};
bool SWV5S5_MvpDecodeBasketHistory(const string payload,SWV5S5_MvpBasketHistory &h)
{
   SWV5S5_MvpCodecReader r; r.Init(payload); string nested;
   return r.ReadNested("prior",nested) && SWV5S5_MvpCodecDecode_SWV5_BasketAggregate(nested,h.prior) &&
      r.ReadNested("opening_request",nested) && SWV5S5_MvpCodecDecode_SWV5_BasketTransitionRequest(nested,h.opening_request) &&
      r.ReadNested("opening",nested) && SWV5S5_MvpCodecDecode_SWV5_BasketAggregate(nested,h.opening) &&
      r.ReadNested("active_request",nested) && SWV5S5_MvpCodecDecode_SWV5_BasketTransitionRequest(nested,h.active_request) &&
      r.ReadNested("active",nested) && SWV5S5_MvpCodecDecode_SWV5_BasketAggregate(nested,h.active) &&
      r.ReadString("positive_digest",h.positive_digest) && r.ReadString("claim_digest",h.claim_digest) &&
      r.ReadString("prior_revision",h.prior_revision) && r.AtEnd();
}

class SWV5S5_MvpBasketLifecycleAuthority
{
private:
   string m_failure;
   bool GenesisReady(SWV5S5_MvpSqliteAuthorityStore &store)
   {
      SWV5S5_MvpAuthorityRow row; bool found=false; string digest,revision,manifest,value;
      return store.ReadRow(SWV5S5_MVP_DOMAIN_GENESIS,"GENESIS",row,found) && found && row.logical_revision==2 &&
         row.state==SWV5S5_MVP_GENESIS_READY_FOR_RECONCILIATION &&
         SWV5S5_DomainDigest(row.domain_key,row.payload,digest) && digest==row.payload_digest &&
         store.DeriveStoreRevision(row.domain_key,row.record_key,row.logical_revision,digest,revision) && revision==row.store_revision &&
         SWV5S5_MvpGenesisManifestDigest(manifest) &&
         SWV5S5_MvpCanonicalScalar(row.payload,"completed_manifest_digest","s",value) && value==manifest &&
         SWV5S5_MvpCanonicalScalar(row.payload,"namespace_digest","s",value) && value==store.NamespaceDigest() &&
         SWV5S5_MvpCanonicalScalar(row.payload,"policy_id","s",value) && value==SWV5S5_MVP_GENESIS_POLICY;
   }
   bool CurrentLease(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_ContractValidationContext &context,
                     const SWV5_InstanceLease &lease,SWV5S5_MvpAuthorityRow &guard)
   {
      SWV5S5_MvpLeasePublicationAuthority owner; SWV5_InstanceLease physical;
      return SWV5S5_MvpLeaseCurrentForClock(context,lease.fence,lease) &&
         owner.LoadCurrentLease(store,lease.fence.ownership_namespace,lease.fence,physical,guard) &&
         SWV5S5_MvpLeaseExact(physical,lease);
   }

   bool FlatExecution(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_PersistenceNamespace &scope,
                       const SWV5_OwnershipFence &fence)
   {
      // Independent physical Execution source, not an EA-supplied zero count.
      SWV5S5_MvpAuthorityRow row; bool found=false; string digest;
      SWV5S5_MvpRequestSetPhysicalState requests;
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_REQUEST_SET,SWV5S5_MVP_REQUEST_SET_KEY,row,found) || !found ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_REQUEST_SET,row.payload,digest) || digest!=row.payload_digest ||
         !SWV5S5_MvpDecodeRequestSetState(row.payload,requests) ||
         !SWV5S5_EqualNamespace(requests.view.persistence_namespace,scope) ||
         !SWV5S5_EqualFence(requests.view.ownership_fence,fence) || ArraySize(requests.view.requests)!=0) return false;
      const string projection=requests.view.projection_digest;
      if(!SWV5S5_DeriveRequestSetProjection(requests.view) || projection!=requests.view.projection_digest) return false;
      m_failure="BASKET_INITIAL_UNRESOLVED_SUBMISSION";
      SWV5S5_SubmissionAuthorityIndexEntry entries[]; SWV5S5_MvpAuthorityRow index; bool index_found=false;
      if(!SWV5S5_MvpLoadSubmissionIndex(store,entries,index,index_found) || ArraySize(entries)!=0) return false;
      // Detect an unindexed/corrupt record too: absence of an index is not a
      // completeness claim. The complete physical namespace query must pass.
      SWV5S5_MvpAuthorityRow rows[];
      if(!store.ReadAllRows(rows)) return false;
      for(int i=0;i<ArraySize(rows);i++)
         if(rows[i].domain_key==SWV5S5_MVP_DOMAIN_SUBMISSION)
         {
            // The accepted create-only GENESIS envelope is infrastructure,
            // not an operational Submission. Verify it rather than treating
            // its presence as either a Claim or evidence of an empty index.
            if(rows[i].record_key!="GENESIS" || rows[i].logical_revision!=1 ||
               !SWV5S5_DomainDigest(rows[i].domain_key,rows[i].payload,digest) || digest!=rows[i].payload_digest)
               return false;
         }
      return true;
   }

public:
   string LastFailure(void) const { return m_failure; }
   bool LoadCurrentBasket(SWV5S5_MvpSqliteAuthorityStore &store,SWV5_BasketAggregate &basket,
                           SWV5S5_MvpAuthorityRow &row,bool &found)
   {
      ZeroMemory(basket); string payload,digest,revision; found=false;
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_BASKET,"CURRENT",row,found)) return false;
      if(!found) return true;
      return row.logical_revision>0 && SWV5S5_MvpCodecDecode_SWV5_BasketAggregate(row.payload,basket) &&
         row.state==(int)basket.lifecycle.state && SWV5S5_MvpBasketPayload(basket,payload,digest) &&
         payload==row.payload && digest==row.payload_digest &&
         store.DeriveStoreRevision(row.domain_key,row.record_key,row.logical_revision,digest,revision) &&
         revision==row.store_revision;
   }

   bool ValidateCurrentBasket(SWV5S5_MvpSqliteAuthorityStore &store,
                              const SWV5_ContractValidationContext &context,const SWV5_PersistenceNamespace &scope,
                              const SWV5_InstanceLease &lease,SWV5_BasketAggregate &basket,SWV5S5_MvpAuthorityRow &row)
   {
      bool found=false; SWV5S5_MvpAuthorityRow guard; SWV5_BasketInvariantReport report;
      SWV5S5_MvpBasketStateMachine machine;
      return CurrentLease(store,context,lease,guard) && LoadCurrentBasket(store,basket,row,found) && found &&
         SWV5S5_IsV5Version(basket.contract_version) && SWV5S5_IsV5Version(scope.contract_version) &&
         SWV5S5_EqualNamespace(basket.persistence_namespace,scope) && basket.account_mode==SWV5_ACCOUNT_MODE_HEDGING &&
         basket.opened_at>0 && basket.opened_at<=basket.updated_at && basket.updated_at<=context.clock_time &&
         MathIsValidNumber(basket.initial_volume) && MathIsValidNumber(basket.aggregate_closed_volume) &&
         basket.initial_volume>=0.0 && basket.aggregate_closed_volume==0.0 &&
         (basket.lifecycle.state!=SWV5_BASKET_IDLE ||
          (basket.initial_volume==0.0 && basket.close_verification==SWV5_CLOSE_ZERO_RESIDUAL_CONFIRMED)) &&
         (basket.lifecycle.state!=SWV5_BASKET_ACTIVE ||
          (basket.initial_volume==basket.lifecycle.aggregate_open_volume && basket.close_verification==SWV5_CLOSE_NOT_REQUESTED)) &&
         basket.lifecycle.basket_id.value==scope.basket_id.value &&
         SWV5S5_EqualFence(basket.lifecycle.ownership_fence,lease.fence) && machine.ValidateState(context,basket.lifecycle,report);
   }

   bool ReadCurrentBasketVersion(SWV5S5_MvpSqliteAuthorityStore &store,
                                  const SWV5_ContractValidationContext &context,const SWV5_PersistenceNamespace &scope,
                                  const SWV5_InstanceLease &lease,ulong &version,string &token)
   {
      version=0; token=""; SWV5_BasketAggregate basket; SWV5S5_MvpAuthorityRow row;
      if(!ValidateCurrentBasket(store,context,scope,lease,basket,row)) return false;
      version=basket.lifecycle.state_version; token=row.store_revision; return true;
   }

   bool TryCreateInitialFlatBasket(SWV5S5_MvpSqliteAuthorityStore &store,
                                    const SWV5_ContractValidationContext &context,const SWV5_PersistenceNamespace &scope,
                                    const SWV5_InstanceLease &lease,ISWV5S5MvpBootstrapBrokerObserver &broker,
                                    SWV5_BasketAggregate &basket,SWV5S5_MvpAuthorityRow &committed)
   {
      ZeroMemory(basket); SWV5S5_MvpAuthorityRow guard,bootstrap_row; bool found=false; string digest,namespace_digest;
      SWV5S5_MvpBootstrapZeroAuthorityStore zero_store; SWV5S5_MvpBootstrapZeroStateAuthority zero;
      SWV5S5_MvpBootstrapBrokerObservation observed;
      m_failure="BASKET_INITIAL_SCOPE_GENESIS_LEASE";
      if(!CurrentLease(store,context,lease,guard) ||
         !SWV5S5_MvpOwnershipNamespaceDigest(scope.ownership_namespace,namespace_digest) || namespace_digest!=store.NamespaceDigest() ||
         !SWV5S5_IsV5Version(scope.contract_version) ||
         !SWV5S5_EqualOwnershipKey(scope.ownership_namespace,lease.fence.ownership_namespace) || scope.basket_id.value=="" ||
         !GenesisReady(store)) return false;
      m_failure="BASKET_INITIAL_BOOTSTRAP";
      if(!zero_store.Configure(store.RelativePath(),store.NamespaceDigest()) || !zero_store.Load(zero,bootstrap_row,found) || !found ||
         !SWV5S5_EqualNamespace(zero.persistence_namespace,scope) || !SWV5S5_EqualFence(zero.ownership_fence,lease.fence)) return false;
      m_failure="BASKET_INITIAL_BROKER_FLAT";
      if(
         !broker.Capture(scope.ownership_namespace.symbol,observed) ||
         !SWV5S5_MvpBootstrapBrokerDigest(observed,digest) || observed.snapshot_digest!=digest ||
         !SWV5S5_MvpProfileMatches(observed.profile,ACCOUNT_TRADE_MODE_DEMO) ||
         observed.profile.broker_identity!=scope.ownership_namespace.broker_identity ||
         observed.profile.server!=scope.ownership_namespace.server || observed.profile.account_login!=scope.ownership_namespace.account_login ||
         observed.observed_at!=context.clock_time || !observed.positions_query_succeeded ||
         !observed.active_orders_query_succeeded || !observed.enumeration_complete || observed.row_failures!=0 ||
         observed.total_positions!=0 || observed.total_active_orders!=0 || observed.total_exposure_volume!=0.0) return false;
      m_failure="BASKET_INITIAL_EXECUTION_FLAT";
      if(!FlatExecution(store,scope,lease.fence)) return false;
      SWV5S5_MvpInitProductionVersion(basket.contract_version); basket.persistence_namespace=scope;
      basket.account_mode=SWV5_ACCOUNT_MODE_HEDGING; basket.lifecycle.contract_version=basket.contract_version;
      basket.lifecycle.basket_id=scope.basket_id; basket.lifecycle.ownership_fence=lease.fence;
      basket.lifecycle.state=SWV5_BASKET_IDLE; basket.lifecycle.state_version=1;
      basket.lifecycle.reconciliation_state=SWV5_RECONCILIATION_STATE_MATCHED;
      basket.lifecycle.state_entered_at=context.clock_time;
      basket.close_verification=SWV5_CLOSE_ZERO_RESIDUAL_CONFIRMED;
      basket.opened_at=context.clock_time; basket.updated_at=context.clock_time;
      m_failure="BASKET_INITIAL_EMPTY_EVENT_INTEGRITY";
      if(!SWV5S5_MvpBasketEmptyEvents(basket.lifecycle.accepted_recovery_evidence)) return false;
      SWV5_AuthoritativeQuerySet queries; ZeroMemory(queries); queries.contract_version=basket.contract_version;
      queries.required_flags=SWV5_QUERY_POSITIONS|SWV5_QUERY_ORDERS; queries.completed_flags=queries.required_flags;
      queries.authoritative_flags=queries.required_flags; queries.observation_sequence=context.clock_sequence;
      queries.observed_at=observed.observed_at; queries.issuing_component=SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER;
      queries.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE; queries.snapshot_id=observed.snapshot_digest;
      m_failure="BASKET_INITIAL_QUERY_INTEGRITY";
      if(!SWV5S5_MvpBasketSealQueries(queries)) return false; basket.lifecycle.broker_queries=queries;
      m_failure="BASKET_INITIAL_PAYLOAD";
      string payload; if(!SWV5S5_MvpBasketPayload(basket,payload,digest)) return false;
      SWV5_BasketAggregate existing; SWV5S5_MvpAuthorityRow current;
      if(!LoadCurrentBasket(store,existing,current,found)) return false;
      if(found)
      { if(current.logical_revision!=1 || current.payload!=payload || current.payload_digest!=digest) return false;
        committed=current; basket=existing; return true; }
      m_failure="BASKET_INITIAL_CAS_OR_READBACK";
      const bool persisted=store.CompareAndSetWithGuard(SWV5S5_MVP_DOMAIN_BASKET,"CURRENT",0,"","",0,1,(int)SWV5_BASKET_IDLE,
         digest,payload,context.clock_time,guard.domain_key,guard.record_key,guard.logical_revision,
         guard.store_revision,guard.payload_digest,guard.state,committed) &&
         ValidateCurrentBasket(store,context,scope,lease,basket,current) && current.store_revision==committed.store_revision;
      if(persisted) m_failure=""; return persisted;
   }

   // This is a post-confirmation operation only, never part of Claim -> send.
   // Reload all authorization from its physical owner and require the frozen
   // independently queried positive-evidence gate. Acknowledgements/callbacks
   // cannot enter this API through a boolean success projection.
   bool PublishGuardedTransition(SWV5S5_MvpSqliteAuthorityStore &store,
                                  const SWV5_ContractValidationContext &context,const SWV5_InstanceLease &lease,
                                  const SWV5S5_F_ReconciliationBinding &binding,
                                  const SWV5S5_F_CorrelationPolicy &policy,const SWV5S5_F_CapabilityProof &capability,
                                  const SWV5S5_F_TargetedPositiveEvidence &positive,
                                  const SWV5S5_F_BrokerQuerySnapshot &broker,
                                  SWV5_BasketAggregate &active,SWV5S5_MvpAuthorityRow &committed)
   {
      ZeroMemory(active); SWV5S5_MvpAuthorityRow guard,current; SWV5_BasketAggregate prior;
      const SWV5_PersistenceNamespace scope=binding.profile.persistence_namespace;
      if(!CurrentLease(store,context,lease,guard) || !ValidateCurrentBasket(store,context,scope,lease,prior,current) ||
         !SWV5S5_F_IsPositiveEvidenceValid(context,binding,policy,capability,positive) ||
         !SWV5S5_F_EqualProfile(broker.profile,binding.profile) || broker.observed_at!=positive.observed_at ||
         broker.owner_query_sequence!=positive.query_set.observation_sequence ||
         !broker.positions_enumeration_complete || !broker.orders_enumeration_complete || broker.row_read_failures!=0 ||
         broker.positions_reported_total!=(uint)ArraySize(broker.positions) ||
         broker.orders_reported_total!=(uint)ArraySize(broker.orders)) return false;
      // Positive deal history is not proof of CURRENT open exposure. Require
      // the exact confirmed position in the same complete Broker observation.
      double volume=0.0; uint positions=0;
      for(int i=0;i<ArraySize(broker.positions);i++)
      {
         if(!broker.positions[i].read_success) return false;
         if(broker.positions[i].position_identifier==positive.position_identifier)
         {
            if(broker.positions[i].symbol!=binding.profile.symbol || broker.positions[i].direction!=binding.direction ||
               !MathIsValidNumber(broker.positions[i].volume) || broker.positions[i].volume<=0.0) return false;
            volume+=broker.positions[i].volume; positions++;
         }
      }
      for(int i=0;i<ArraySize(broker.orders);i++)
         if(!broker.orders[i].read_success || broker.orders[i].ticket==positive.order_ticket) return false;
      if(positions!=1 || MathAbs(volume-positive.cumulative_confirmed_volume)>context.volume_tolerance ||
         MathAbs(volume-binding.requested_volume)>context.volume_tolerance) return false;
      SWV5S5_SubmissionAuthorityRecord claimed; bool found=false; string digest;
      if(!SWV5S5_MvpLoadSubmissionAuthority(store,binding.request_identity.request_id.correlation_id,
         binding.request_identity.request_id.attempt_id,claimed,found) || !found ||
         claimed.state!=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED ||
         claimed.invocation_claim_id!=binding.invocation_claim_id || claimed.durable_record_digest!=binding.claim_record_digest ||
         claimed.permit.basket_state_version!=binding.expected_basket_version ||
         claimed.permit.risk_authorization.basket_state_version!=binding.expected_basket_version ||
         !SWV5S5_EqualRequestIdentity(claimed.permit.request_identity,binding.request_identity) ||
         claimed.permit.risk_authorization.disposition!=SWV5_RISK_ALLOW) return false;
      // Crash after Basket publication but before Submission terminalization:
      // validate the immutable ordered history and return the exact CURRENT.
      // Fresh positive observation cannot rewrite prior authority or versions.
      if(prior.lifecycle.state==SWV5_BASKET_ACTIVE)
      {
         SWV5S5_MvpAuthorityRow history; SWV5S5_MvpBasketHistory h; string history_digest,a,b;
         SWV5S5_MvpBasketStateMachine verifier; SWV5_BasketTransitionDecision first,second;
         if(!store.ReadRow(SWV5S5_MVP_DOMAIN_BASKET_HISTORY,binding.invocation_claim_id,history,found) || !found ||
            !SWV5S5_DomainDigest(history.domain_key,history.payload,history_digest) || history_digest!=history.payload_digest ||
            !SWV5S5_MvpDecodeBasketHistory(history.payload,h) || h.claim_digest!=claimed.durable_record_digest ||
            h.prior.lifecycle.state!=SWV5_BASKET_IDLE || h.prior.lifecycle.state_version!=binding.expected_basket_version ||
            h.active.lifecycle.state_version!=binding.expected_basket_version+2 ||
            !SWV5S5_EqualRequestIdentity(h.active_request.correlation.request_identity,binding.request_identity) ||
            h.active_request.correlation.broker_identity.position_identifier!=positive.position_identifier ||
            h.active_request.correlation.broker_identity.order_ticket!=positive.order_ticket ||
            h.active_request.correlation.broker_identity.deal_ticket!=positive.deal_ticket ||
            MathAbs(h.active.lifecycle.residual_volume-volume)>context.volume_tolerance ||
            !verifier.ValidateTransition(context,h.prior.lifecycle,h.opening_request,first) ||
            !verifier.ValidateTransition(context,h.opening.lifecycle,h.active_request,second) ||
            first.resulting_state_version!=h.opening.lifecycle.state_version ||
            second.resulting_state_version!=h.active.lifecycle.state_version ||
            !SWV5S5_MvpCodecEncode_SWV5_BasketAggregate(prior,a) ||
            !SWV5S5_MvpCodecEncode_SWV5_BasketAggregate(h.active,b) || a!=b) return false;
         active=prior; committed=current; return true;
      }
      if(prior.lifecycle.state!=SWV5_BASKET_IDLE || prior.lifecycle.state_version!=binding.expected_basket_version) return false;
      // Retain both ordered frozen DTO transitions, including the intermediate
      // state, inside ONE immutable history payload + CURRENT pair transaction.
      SWV5_BasketTransitionRequest opening_request,active_request; ZeroMemory(opening_request);
      opening_request.contract_version=context.expected_version; opening_request.basket_id=scope.basket_id;
      opening_request.ownership_fence=lease.fence; opening_request.from_state=SWV5_BASKET_IDLE;
      opening_request.to_state=SWV5_BASKET_OPENING; opening_request.cause=SWV5_TRANSITION_OPEN_AUTHORIZED;
      opening_request.expected_state_version=prior.lifecycle.state_version; opening_request.evidence_time=context.clock_time;
      opening_request.risk_decision.contract_version=context.expected_version;
      opening_request.risk_decision.disposition=SWV5_DISPOSITION_ALLOW;
      opening_request.risk_decision.reason_code=claimed.permit.risk_authorization.authorization_id;
      opening_request.risk_decision.reason_text="PHYSICAL_RISK_AUTHORIZATION_ALLOW";
      opening_request.risk_decision.evaluation_sequence=claimed.permit.risk_authorization.risk_snapshot_sequence;
      opening_request.risk_decision.evaluated_at=claimed.permit.risk_authorization.evaluated_at;
      opening_request.reconciliation_state=SWV5_RECONCILIATION_STATE_MATCHED;
      opening_request.broker_queries=prior.lifecycle.broker_queries;
      opening_request.correlation.contract_version=context.expected_version;
      opening_request.correlation.phase=SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION;
      opening_request.correlation.request_identity=binding.request_identity;
      opening_request.correlation.broker_identity.contract_version=context.expected_version;
      opening_request.correlation.broker_identity.order_ticket=positive.order_ticket;
      opening_request.correlation.broker_identity.deal_ticket=positive.deal_ticket;
      opening_request.correlation.broker_identity.position_identifier=positive.position_identifier;
      opening_request.correlation.broker_identity.broker_event_id=positive.evidence_digest;
      opening_request.correlation.broker_identity.transaction_sequence=positive.query_set.observation_sequence;
      SWV5S5_MvpBasketStateMachine machine; SWV5_BasketTransitionDecision first,second;
      if(!machine.ValidateTransition(context,prior.lifecycle,opening_request,first)) return false;
      SWV5_BasketAggregate opening=prior; opening.lifecycle.state=first.resulting_state;
      opening.lifecycle.state_version=first.resulting_state_version; opening.updated_at=context.clock_time;
      opening.lifecycle.state_entered_at=context.clock_time;
      active_request=opening_request; active_request.from_state=SWV5_BASKET_OPENING;
      active_request.to_state=SWV5_BASKET_ACTIVE; active_request.cause=SWV5_TRANSITION_OPEN_CONFIRMED;
      active_request.expected_state_version=opening.lifecycle.state_version;
      active_request.residual_volume=volume; active_request.live_position_count=positions;
      active_request.confirmation_authority=SWV5_AUTHORITY_TRANSACTION_EVENT;
      active_request.broker_queries=positive.query_set;
      // The frozen V5 nested integrity format differs from the separately
      // governed Sprint 5 Broker proof. Preserve the original proof digest
      // in history and derive V5 nested integrity without changing its facts.
      if(!SWV5S5_MvpBasketSealQueries(active_request.broker_queries)) return false;
      if(!machine.ValidateTransition(context,opening.lifecycle,active_request,second)) return false;
      active=opening; active.lifecycle.state=second.resulting_state; active.lifecycle.state_version=second.resulting_state_version;
      active.lifecycle.aggregate_open_volume=volume; active.lifecycle.residual_volume=volume;
      active.lifecycle.live_position_count=positions; active.initial_volume=volume;
      active.close_verification=SWV5_CLOSE_NOT_REQUESTED; active.lifecycle.broker_queries=positive.query_set;
      if(!SWV5S5_MvpBasketSealQueries(active.lifecycle.broker_queries)) return false;
      SWV5_BasketInvariantReport report;
      if(!machine.ValidateState(context,active.lifecycle,report)) return false;
      string body="",f,nested,payload,active_digest,history_digest;
      if(!SWV5S5_MvpCodecEncode_SWV5_BasketAggregate(prior,nested) || !SWV5S5_CanonicalNested("prior",nested,f)) return false; body+=f;
      if(!SWV5S5_MvpCodecEncode_SWV5_BasketTransitionRequest(opening_request,nested) || !SWV5S5_CanonicalNested("opening_request",nested,f)) return false; body+=f;
      if(!SWV5S5_MvpCodecEncode_SWV5_BasketAggregate(opening,nested) || !SWV5S5_CanonicalNested("opening",nested,f)) return false; body+=f;
      if(!SWV5S5_MvpCodecEncode_SWV5_BasketTransitionRequest(active_request,nested) || !SWV5S5_CanonicalNested("active_request",nested,f)) return false; body+=f;
      if(!SWV5S5_MvpCodecEncode_SWV5_BasketAggregate(active,nested) || !SWV5S5_CanonicalNested("active",nested,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("positive_digest",positive.evidence_digest,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("claim_digest",claimed.durable_record_digest,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("prior_revision",current.store_revision,f)) return false; body+=f;
      if(!SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_BASKET_HISTORY,body,history_digest) ||
         !SWV5S5_MvpBasketPayload(active,payload,active_digest)) return false;
      SWV5S5_MvpAuthorityMutation history_mutation,current_mutation; SWV5S5_MvpAuthorityRow history,history_read;
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_BASKET_HISTORY,binding.invocation_claim_id,history,found) || found) return false;
      SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_BASKET_HISTORY,binding.invocation_claim_id,history,false,1,
         (int)SWV5_BASKET_ACTIVE,history_digest,body,context.clock_time,history_mutation);
      SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_BASKET,"CURRENT",current,true,current.logical_revision+1,
         (int)SWV5_BASKET_ACTIVE,active_digest,payload,context.clock_time,current_mutation);
      return store.CompareAndSetPairWithGuard(history_mutation,current_mutation,guard,history_read,committed) &&
         history_read.payload==body && ValidateCurrentBasket(store,context,scope,lease,active,current) &&
         current.store_revision==committed.store_revision;
   }
};
#endif
