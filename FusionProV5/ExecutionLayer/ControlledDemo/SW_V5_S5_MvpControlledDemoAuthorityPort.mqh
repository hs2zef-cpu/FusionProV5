#ifndef SW_V5_S5_MVP_CONTROLLED_DEMO_AUTHORITY_PORT_MQH
#define SW_V5_S5_MVP_CONTROLLED_DEMO_AUTHORITY_PORT_MQH

// CONTROLLED DEMO MVP concrete authority-provider binding.
// No OrderSend, retry, signal synthesis, or broker mutation exists in this file.

#include "SW_V5_S5_MvpControlledDemoRunner.mqh"
#include "SW_V5_S5_MvpSignalIngressAdapter.mqh"
#include "../RuntimeAuthority/SW_V5_S5_MvpRequestMaterializationAuthorities.mqh"
#include "../RuntimeAuthority/SW_V5_S5_MvpEvidenceRecoveryAuthorities.mqh"
#include "../RuntimeAuthority/SW_V5_S5_MvpReconciliationGovernanceAuthorities.mqh"
#include "../RuntimeAuthority/SW_V5_S5_MvpHardKillActivationAuthority.mqh"

struct SWV5S5_MvpControlledDemoAuthoritySeed
{
   SWV5_ContractValidationContext context;
   SWV5_EngineInput engine_input;
   SWV5_DecisionResult decision;
   SWV5_InstanceLease current_lease;
   SWV5S5_ProducerTrustRecord current_trust;
   SWV5S5_ProducerTrustAnchor trust_anchor;
   SWV5_HardKillState hard_kill_state;
   SWV5_RiskEvaluationInput risk_observation;
   SWV5S5_MvpAccountObservation account_observation;
   SWV5S5_F_AdapterEnvironment adapter_environment;
   ulong filling_mode;
   string comment_metadata;
};

class SWV5S5_MvpNoopCoordinatorTrace : public ISWV5S5CoordinatorTraceSink
{
public:
   virtual void Append(const SWV5S5_CoordinatorTraceEntry &entry) { }
};

bool SWV5S5_MvpPrepareSequenceProposal(const SWV5S5_RequestSequenceAuthority &authority,
                                       const SWV5S5_RequestSequenceIndexEntry &entries[],
                                       const string correlation,const string payload_digest,
                                       SWV5S5_RequestSequenceReservation &proposal)
{
   ZeroMemory(proposal); SWV5S5_InitContractVersion(proposal.contract_version);
   proposal.persistence_namespace=authority.persistence_namespace;
   proposal.ownership_fence=authority.ownership_fence;
   proposal.logical_correlation_id=correlation; proposal.binding_digest=payload_digest;
   proposal.expected_allocator_revision=authority.allocator_revision;
   proposal.expected_authority_digest=authority.authority_digest;
   proposal.observed_high_watermark=authority.request_sequence_high_watermark;
   const int existing=SWV5S5_FindSequenceReservation(entries,correlation);
   proposal.proposed_sequence=(existing>=0 ? entries[existing].reserved_sequence : authority.request_sequence_high_watermark+1);
   proposal.proposed_allocator_revision=(existing>=0 ? authority.allocator_revision : authority.allocator_revision+1);
   return SWV5S5_DeriveSequenceReservationDigest(proposal,proposal.reservation_digest);
}

bool SWV5S5_MvpRiskAuthorizationCoherent(const SWV5_RiskEvaluationInput &candidate,
                                         const SWV5_RiskAuthorization &authorization)
{
   string expected_id;
   return SWV5S5_MvpDeriveRiskAuthorizationId(candidate,expected_id) &&
      authorization.disposition==SWV5_RISK_ALLOW && authorization.authorization_id==expected_id &&
      SWV5S5_EqualRequestIdentity(authorization.request_identity,candidate.intent.request_identity) &&
      SWV5S5_EqualNamespace(authorization.persistence_namespace,candidate.intent.persistence_namespace) &&
      SWV5S5_EqualFence(authorization.ownership_fence,candidate.ownership_fence) &&
      authorization.authorized_direction==candidate.intent.direction &&
      authorization.authorized_volume==candidate.intent.normalized_volume &&
      authorization.authorized_price==candidate.intent.normalized_price &&
      authorization.authorized_stop_price==candidate.intent.normalized_stop_price &&
      authorization.authorized_limit_price==candidate.intent.normalized_limit_price &&
      authorization.basket_state_version==candidate.intent.expected_basket_version &&
      authorization.symbol_specification_sequence==candidate.intent.symbol_specification_sequence &&
      authorization.expires_at==candidate.intent.authorization_expires_at;
}

// Read-only recovery seam. The production implementation delegates to the
// accepted BrokerPlatformAdapter; tests may supply deterministic snapshots.
// Neither interface method can submit, retry, or create policy authority.
class ISWV5S5MvpBrokerRecoveryReadPort
{
public:
   virtual bool Query(const SWV5S5_F_ReconciliationBinding &binding,
                      const SWV5S5_F_CapabilityProof &capability_proof,
                      const datetime history_from,const datetime history_to,
                      ISWV5S5FBrokerEvidenceStore &evidence_store,
                      SWV5S5_F_BrokerQuerySnapshot &snapshot)=0;
   virtual bool CaptureCallback(const SWV5_ContractValidationContext &context,const ulong callback_sequence,
                                const MqlTradeTransaction &transaction,const MqlTradeRequest &request,
                                const MqlTradeResult &result,ISWV5S5FBrokerEvidenceStore &evidence_store)=0;
};

class SWV5S5_MvpBrokerRecoveryReadPort : public ISWV5S5MvpBrokerRecoveryReadPort
{
private:
   SWV5S5_F_BrokerPlatformAdapter *m_adapter;
public:
   SWV5S5_MvpBrokerRecoveryReadPort(SWV5S5_F_BrokerPlatformAdapter *adapter){ m_adapter=adapter; }
   virtual bool Query(const SWV5S5_F_ReconciliationBinding &binding,
                      const SWV5S5_F_CapabilityProof &capability_proof,
                      const datetime history_from,const datetime history_to,
                      ISWV5S5FBrokerEvidenceStore &evidence_store,
                      SWV5S5_F_BrokerQuerySnapshot &snapshot)
   { return m_adapter!=NULL && m_adapter.QueryAuthoritativeBrokerDomains(binding,capability_proof,
      history_from,history_to,evidence_store,snapshot); }
   virtual bool CaptureCallback(const SWV5_ContractValidationContext &context,const ulong callback_sequence,
                                const MqlTradeTransaction &transaction,const MqlTradeRequest &request,
                                const MqlTradeResult &result,ISWV5S5FBrokerEvidenceStore &evidence_store)
   { return m_adapter!=NULL && m_adapter.CaptureCallback(context,callback_sequence,transaction,request,result,evidence_store); }
};

class SWV5S5_MvpControlledDemoAuthorityPort : public ISWV5S5_MvpControlledDemoAuthorityPort
{
private:
   string m_path,m_namespace_digest;
   SWV5S5_MvpControlledDemoAuthoritySeed m_seed;
   ISWV5S5MvpReadOnlyPlatform *m_platform;
   SWV5S5_MvpBrokerEvidenceStore *m_evidence_store;
   ISWV5S5MvpBrokerRecoveryReadPort *m_broker_recovery;
   bool m_configured,m_bootstrapped,m_permit_prepared,m_permit_committed,m_admission_ready,m_claimed;
   SWV5S5_IngressEnvelope m_ingress;
   SWV5S5_ProducerTrustScope m_trust_scope;
   SWV5S5_RequestBinding m_binding;
   SWV5_ExecutionRequestIdentity m_request_identity;
   SWV5S5_SymbolSpecificationAuthorityView m_symbol;
   SWV5_NormalizedUnits m_normalized;
   string m_normalization_identity,m_unit_authority_id,m_unit_authority_digest;
   ulong m_unit_authority_revision;
   SWV5_MarginAuthorityRecord m_margin;
   SWV5_BasketRiskAuthorityRecord m_basket_risk;
   SWV5_RiskEvaluationInput m_risk_input;
   SWV5_RiskAuthorization m_risk_authorization;
   SWV5S5_CoordinatorMaterializationResult m_materialization;
   SWV5S5_MvpCoordinatorLedgerAdapter m_ledger;
   SWV5S5_MvpCoordinatorSequenceAdapter m_sequence;
   SWV5S5_MvpRequestSetPublicationAuthority m_request_set;
   SWV5S5_MvpSubmissionPermitAuthority m_permit_authority;
   SWV5S5_MvpInvocationClaimAuthority m_claim_authority;
   SWV5S5_PermitPreparationCommand m_permit_command;
   SWV5S5_PermitPreparationResult m_permit_result;
   SWV5S5_AdmissionProof m_admission_proof;
   SWV5S5_InvocationClaimCommand m_claim_command;
   SWV5S5_InvocationClaimTransition m_claim_transition;
   SWV5S5_InvocationClaimResult m_claim_result;
   bool m_store_schema_valid,m_genesis_valid,m_ownership_current,m_trust_current;
   bool m_safety_current,m_initial_request_set_empty,m_initial_submission_index_empty;
   bool m_pin_durable;
   string m_last_stage;
   SWV5S5_MvpAccountObservation m_observed_account;
   SWV5S5_MvpRuntimeProfileObservation m_observed_profile;
   SWV5S5_MvpAuthorityRow m_ownership_row,m_pin_row;
   SWV5S5_MvpReconciliationGovernanceBundle m_governance;
   SWV5S5_MvpAttemptReconciliationPin m_pin;
   datetime m_safety_horizon;

   bool IncreasingEligibilityCurrent(void)
   {
      SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpHardKillActivationAuthority activation;
      m_safety_horizon=0;
      return store.Open(m_path,m_namespace_digest) && activation.EligibilityHorizon(store,m_seed.context,
         m_seed.hard_kill_state,m_seed.current_lease,m_safety_horizon);
   }

   bool CollectPhysicalPreconditions(const SWV5S5_MvpControlledDemoInvocation &invocation)
   {
      m_store_schema_valid=false; m_genesis_valid=false; m_ownership_current=false;
      m_trust_current=false; m_safety_current=false; m_initial_request_set_empty=false;
      m_initial_submission_index_empty=false; ZeroMemory(m_observed_account); ZeroMemory(m_observed_profile);
      SWV5S5_MvpSqliteAuthorityStore store;
      if(invocation.persistence_namespace_identity!=m_namespace_digest ||
         !store.Open(m_path,m_namespace_digest)) return false;
      m_store_schema_valid=true;
      SWV5S5_MvpAuthorityRow genesis; bool found=false;
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_GENESIS,"GENESIS",genesis,found) || !found ||
         genesis.state!=SWV5S5_MVP_GENESIS_READY_FOR_RECONCILIATION) return false;
      m_genesis_valid=true;
      SWV5S5_MvpLeasePublicationAuthority lease_authority; SWV5_InstanceLease lease;
      SWV5S5_MvpAuthorityRow lease_row;
      if(!lease_authority.LoadCurrentLease(store,m_seed.current_lease.fence.ownership_namespace,
         m_seed.current_lease.fence,lease,lease_row) ||
         !SWV5S5_MvpLeaseCurrentForClock(m_seed.context,m_seed.current_lease.fence,lease) ||
          !SWV5S5_MvpLeaseExact(lease,m_seed.current_lease)) return false;
      m_ownership_row=lease_row;
      m_ownership_current=true;
      SWV5S5_MvpManualProducerTrustProvisioner trust_authority; SWV5S5_ProducerTrustRecord trust;
      SWV5S5_ProducerTrustAnchor anchor; string operator_id,authentication; bool trust_found=false;
      if(!trust_authority.Configure(m_path,m_namespace_digest) ||
         !trust_authority.LoadCurrent(trust,anchor,operator_id,authentication,trust_found) || !trust_found ||
         trust.record_digest!=m_seed.current_trust.record_digest ||
         anchor.current_authority_record_id!=m_seed.trust_anchor.current_authority_record_id ||
         anchor.current_authority_generation!=m_seed.trust_anchor.current_authority_generation ||
         anchor.issuer_identity!=m_seed.trust_anchor.issuer_identity ||
         anchor.issuer_policy_id!=m_seed.trust_anchor.issuer_policy_id) return false;
      m_trust_current=true;
      SWV5S5_MvpAuthorityRow hard_kill; string hard_kill_payload,hard_kill_digest;
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",hard_kill,found) || !found ||
         !SWV5S5_CanonicalHardKillState("hard_kill",m_seed.hard_kill_state,hard_kill_payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,hard_kill_payload,hard_kill_digest) ||
         hard_kill.state!=(int)m_seed.hard_kill_state.state || hard_kill.payload!=hard_kill_payload ||
         hard_kill.payload_digest!=hard_kill_digest || m_seed.hard_kill_state.state!=SWV5_HARD_KILL_INACTIVE)
         return false;
      if(!IncreasingEligibilityCurrent()) return false;
      m_safety_current=true;
      datetime profile_at=0;
      if(!m_platform.CaptureProfile(SWV5S5_MVP_SYMBOL,m_observed_profile,profile_at) ||
         profile_at!=m_seed.context.clock_time ||
         !m_platform.CaptureFlatAccount(m_seed.context.clock_time,m_observed_account) ||
         m_observed_account.observed_at!=m_seed.context.clock_time || !m_observed_account.complete ||
         !m_observed_account.history_complete || m_observed_account.positions_total!=0 ||
         m_observed_account.orders_total!=0 ||
         m_observed_profile.broker_identity!=invocation.expected_broker_identity ||
         m_observed_profile.server!=invocation.expected_server ||
         m_observed_profile.account_login!=invocation.expected_demo_account_login ||
         !SWV5S5_MvpProfileMatches(m_observed_profile,ACCOUNT_TRADE_MODE_DEMO)) return false;
      m_seed.account_observation=m_observed_account;
      return true;
   }

   bool CollectReadOnlyExecutionState(void)
   {
      m_initial_request_set_empty=false; m_initial_submission_index_empty=false;
      SWV5S5_MvpSqliteAuthorityStore store; if(!store.Open(m_path,m_namespace_digest)) return false;
      SWV5S5_MvpAuthorityRow request_row,index_row; bool request_found=false,index_found=false;
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_REQUEST_SET,SWV5S5_MVP_REQUEST_SET_KEY,request_row,request_found)) return false;
      if(!request_found) m_initial_request_set_empty=true;
      else
      {
         SWV5S5_MvpRequestSetPhysicalState request_state;
         m_initial_request_set_empty=SWV5S5_MvpDecodeRequestSetState(request_row.payload,request_state) &&
            ArraySize(request_state.view.requests)==0;
      }
      SWV5S5_SubmissionAuthorityIndexEntry entries[];
      if(!SWV5S5_MvpLoadSubmissionIndex(store,entries,index_row,index_found)) return false;
      m_initial_submission_index_empty=ArraySize(entries)==0;
      return m_initial_request_set_empty && m_initial_submission_index_empty;
   }

   bool FillReadOnlyEvidence(const SWV5S5_MvpControlledDemoInvocation &invocation,const int direction,
                             SWV5S5_MvpControlledDemoPreflightEvidence &evidence)
   {
      SWV5_SymbolUnitSpecification specification; double margin=0.0,stop_profit=0.0;
      const bool price_shape=invocation.requested_volume>0.0 && invocation.requested_price>0.0 &&
         invocation.protective_stop_price>0.0 && (direction>0 ? invocation.protective_stop_price<invocation.requested_price :
                                                               invocation.protective_stop_price>invocation.requested_price);
      const bool symbol_ok=m_platform.CaptureSymbolSpecification(SWV5S5_MVP_SYMBOL,m_seed.context.clock_sequence,
                                                                  m_seed.context.clock_time,specification);
      const bool margin_ok=price_shape && m_platform.CalculateMargin(direction,SWV5S5_MVP_SYMBOL,
         invocation.requested_volume,invocation.requested_price,margin);
      const bool stop_ok=price_shape && m_platform.CalculateProfit(direction,SWV5S5_MVP_SYMBOL,
         invocation.requested_volume,invocation.requested_price,invocation.protective_stop_price,stop_profit);
      evidence.profile_exact=m_observed_profile.broker_identity==m_seed.adapter_environment.broker_identity &&
         m_observed_profile.server==m_seed.adapter_environment.server &&
         m_observed_profile.account_login==m_seed.adapter_environment.account_login &&
         m_observed_profile.symbol==m_seed.adapter_environment.symbol;
      evidence.demo_account=m_observed_profile.account_trade_mode==ACCOUNT_TRADE_MODE_DEMO;
      evidence.usd_account=m_observed_profile.account_currency==SWV5S5_MVP_ACCOUNT_CURRENCY;
      evidence.hedging_account=m_observed_profile.account_mode==SWV5_ACCOUNT_MODE_HEDGING;
      evidence.symbol_exact=m_observed_profile.symbol==SWV5S5_MVP_SYMBOL;
      evidence.connected=m_observed_profile.connected && m_seed.adapter_environment.connected;
      evidence.permissions_observed=SWV5S5_F_AdapterPermissionsAllowMutation(m_seed.adapter_environment);
      evidence.store_schema_valid=m_store_schema_valid; evidence.genesis_valid=m_genesis_valid;
      evidence.ownership_current=m_ownership_current; evidence.trust_complete=m_trust_current;
      evidence.trust_current_unexpired=m_seed.current_trust.status==SWV5S5_TRUST_AUTHORIZED &&
         m_seed.current_trust.valid_from<=m_seed.context.clock_time && m_seed.context.clock_time<m_seed.current_trust.valid_until;
      evidence.safety_allows_execution=m_safety_current;
      evidence.broker_observation_complete=m_observed_account.complete && m_observed_account.history_complete;
      evidence.execution_observation_complete=m_initial_request_set_empty && m_initial_submission_index_empty;
      evidence.no_position=m_observed_account.positions_total==0; evidence.no_active_order=m_observed_account.orders_total==0;
      evidence.no_unresolved_submission=m_initial_submission_index_empty; evidence.no_competing_operation=m_initial_request_set_empty;
      evidence.symbol_specification_fresh=symbol_ok && SWV5S5_MvpSpecificationValid(m_seed.context,specification);
      evidence.units_valid=price_shape && invocation.requested_volume<=SWV5S5_MVP_MAX_VOLUME;
      evidence.margin_valid=margin_ok && margin>0.0; evidence.basket_risk_valid=stop_ok && stop_profit<0.0;
      evidence.risk_inputs_valid=m_seed.risk_observation.account.authoritative &&
         m_seed.risk_observation.exposure.complete && m_seed.risk_observation.basket.lifecycle.state_version>0;
      evidence.protective_stop_valid=price_shape; evidence.prospective_permit_preparable=false;
      evidence.d1_terminal=(invocation.mode!=MODE_D3_SELL); evidence.manual_cleanup_independently_observed=(invocation.mode!=MODE_D3_SELL);
      evidence.independent_request_identity=(invocation.mode!=MODE_D3_SELL);
      return true;
   }

   datetime MinimumExpiry(void) const
   {
      datetime expiry=m_seed.context.clock_time+(datetime)SWV5S5_MVP_RISK_AUTHORIZATION_LIFETIME_SECONDS;
      if(m_seed.current_trust.valid_until<expiry) expiry=m_seed.current_trust.valid_until;
      if(m_seed.current_lease.expires_at<expiry) expiry=m_seed.current_lease.expires_at;
      if(m_safety_horizon<expiry) expiry=m_safety_horizon;
      if(m_symbol.specification.valid_until<expiry) expiry=m_symbol.specification.valid_until;
      return expiry;
   }

   bool PrepareRiskInput(const int direction)
   {
      if(!IncreasingEligibilityCurrent()) return false;
      m_risk_input=m_seed.risk_observation;
      SWV5S5_MvpInitProductionVersion(m_risk_input.contract_version);
      m_risk_input.account_namespace=m_seed.risk_observation.account_namespace;
      m_risk_input.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
      SWV5S5_MvpLoadRiskLimits(m_risk_input.limits);
      m_risk_input.intent.contract_version=m_request_identity.contract_version;
      m_risk_input.intent.persistence_namespace=m_binding.persistence_namespace;
      m_risk_input.intent.ownership_fence=m_seed.current_lease.fence;
      m_risk_input.intent.request_identity=m_request_identity;
      m_risk_input.intent.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
      m_risk_input.intent.intent_type=SWV5_INTENT_OPEN; m_risk_input.intent.direction=direction;
      m_risk_input.intent.normalized_volume=m_normalized.volume;
      m_risk_input.intent.normalized_price=m_normalized.price;
      m_risk_input.intent.normalized_stop_price=m_normalized.stop_price;
      m_risk_input.intent.normalized_limit_price=m_normalized.limit_price;
      m_risk_input.intent.symbol_specification_sequence=m_normalized.specification_sequence;
      m_risk_input.intent.expected_basket_version=m_risk_input.basket.lifecycle.state_version;
      m_risk_input.intent.authorization_expires_at=MinimumExpiry();
      m_risk_input.ownership_fence=m_seed.current_lease.fence;
      m_risk_input.symbol_specification=m_symbol.specification;
      m_risk_input.margin_authority_record=m_margin; m_risk_input.has_margin_authority_record=true;
      m_risk_input.basket_risk_authority_record=m_basket_risk; m_risk_input.has_basket_risk_authority_record=true;
      m_risk_input.projected.margin_evidence.authority_record_id=m_margin.authority_record_id;
      m_risk_input.projected.margin_evidence.authority_record_sequence=m_margin.authority_record_sequence;
      m_risk_input.projected.margin_evidence.authority_record_digest=m_margin.authority_record_digest;
      m_risk_input.projected.margin_evidence.projected_account_margin=m_margin.projected_account_margin;
      m_risk_input.projected.margin_evidence.additional_margin=m_margin.additional_margin;
      m_risk_input.projected.basket_risk_evidence.authority_record_id=m_basket_risk.authority_record_id;
      m_risk_input.projected.basket_risk_evidence.authority_record_sequence=m_basket_risk.authority_record_sequence;
      m_risk_input.projected.basket_risk_evidence.authority_record_digest=m_basket_risk.authority_record_digest;
      m_risk_input.projected.basket_risk_evidence.resulting_basket_maximum_loss=m_basket_risk.resulting_basket_maximum_loss;
      m_risk_input.projected.projected_volume=m_normalized.volume;
      m_risk_input.projected.projected_symbol_volume=m_normalized.volume;
      m_risk_input.projected.projected_aggregate_volume=m_normalized.volume;
      m_risk_input.projected.projected_notional=m_normalized.volume*m_normalized.price*m_symbol.specification.contract_size;
      m_risk_input.projected.projected_margin=m_margin.additional_margin;
      m_risk_input.projected.projected_maximum_loss=m_basket_risk.resulting_basket_maximum_loss;
      m_risk_input.projected.symbol=SWV5S5_MVP_SYMBOL;
      m_risk_input.projected.calculated_at=m_seed.context.clock_time;
      m_risk_input.projected.complete=true;
      m_risk_input.account.observed_at=m_seed.context.clock_time;
      m_risk_input.exposure.observed_at=m_seed.context.clock_time;
      m_risk_input.basket.observed_at=m_seed.context.clock_time;
      if(m_risk_input.intent.authorization_expires_at<=m_seed.context.clock_time ||
         !SWV5S5_MvpDeriveRiskAuthorizationId(m_risk_input,m_risk_input.intent.risk_authorization_id)) return false;
      SWV5S5_MvpRiskContract risk;
      return risk.Evaluate(m_seed.context,m_risk_input,m_risk_authorization) &&
         SWV5S5_MvpRiskAuthorizationCoherent(m_risk_input,m_risk_authorization);
   }

   bool PublishRequestAndBind(void)
   {
      SWV5S5_RequestSetPublicationAuthority current; SWV5_PendingRequest requests[];
      if(!m_request_set.ReadState(current,requests)) return false;
      const int n=ArraySize(requests); SWV5_PendingRequest proposed[]; ArrayResize(proposed,n+1);
      for(int i=0;i<n;i++) proposed[i]=requests[i]; proposed[n]=m_materialization.progressed_request;
      SWV5S5_RequestSetPublicationProposal p; ZeroMemory(p); SWV5S5_InitContractVersion(p.contract_version);
      p.policy_id=SWV5S5_PUBLICATION_POLICY_ID; p.policy_version=SWV5S5_PUBLICATION_POLICY_VERSION;
      p.persistence_namespace=m_binding.persistence_namespace; p.expected_ownership_fence=m_seed.current_lease.fence;
      p.expected_takeover_generation=m_seed.current_lease.fence.takeover_generation;
      p.expected_store_revision=current.store_revision;
      p.expected_request_set_revision=current.current_set_header.request_index_revision;
      p.expected_request_set_digest=current.current_complete_set_digest;
      p.expected_record_sequence=current.current_set_header.record_sequence;
      SWV5S5_DomainDigest("SWV5-S5-MVP-REQUEST-SET-STORE-REVISION-V1",
         current.store_revision+m_binding.binding_digest,p.proposed_store_revision);
      SWV5S5_MvpInitProductionVersion(p.proposed_set_header.contract_version);
      SWV5S5_DomainDigest("SWV5-S5-MVP-REQUEST-SET-REVISION-V1",
         current.current_set_header.request_index_revision+m_binding.binding_digest,
         p.proposed_set_header.request_index_revision);
      p.proposed_set_header.record_sequence=current.current_set_header.record_sequence+1;
      p.proposed_set_header.request_count=(uint)(n+1);
      if(!SWV5S5_DeriveCompleteRequestSetDigest(proposed,p.proposed_set_header.request_set_digest)) return false;
      p.proposed_complete_set_digest=p.proposed_set_header.request_set_digest;
      if(!SWV5S5_DeriveRequestSetProposalDigest(p,p.proposal_digest)) return false;
      SWV5S5_FencedPublicationResult result;
      if(!m_request_set.TryPublishRequestSet(p,proposed,result)) return false;
      string bound_id; SWV5_PendingRequest readback; SWV5S5_IngressLedgerRecord bound;
      return SWV5S5_MvpDeriveBoundRequestId(m_request_identity,bound_id) &&
         m_request_set.FindExactBoundRequest(bound_id,m_materialization.progressed_request,readback) &&
         m_ledger.TransitionBound(m_ingress.ingress_identity,m_request_identity,m_seed.context.clock_time,bound) &&
         bound.bound_request_id==bound_id;
   }

   bool BuildPermit(void)
   {
      SWV5S5_SubmissionAuthorityIndexEntry entries[]; SWV5S5_MvpSqliteAuthorityStore store;
      SWV5S5_MvpAuthorityRow index_row; bool found=false; string index_digest;
      if(!store.Open(m_path,m_namespace_digest) || !SWV5S5_MvpLoadSubmissionIndex(store,entries,index_row,found) ||
         !SWV5S5_DeriveSubmissionIndexDigest(entries,index_digest)) return false;
      SWV5S5_SubmissionPermit permit; ZeroMemory(permit); SWV5S5_InitContractVersion(permit.contract_version);
      permit.permit_policy_id=SWV5S5_PERMIT_POLICY_ID; permit.permit_policy_version=SWV5S5_PERMIT_POLICY_VERSION;
      permit.canonical_format_id=SWV5S5_CANONICAL_POLICY_ID; permit.permit_revision=1;
      permit.reserved_at=m_seed.context.clock_time; permit.persistence_namespace=m_binding.persistence_namespace;
      permit.ownership_fence=m_seed.current_lease.fence; permit.account_namespace=m_risk_input.account_namespace;
      permit.account_epoch=m_risk_input.account_namespace.snapshot_epoch; permit.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
      permit.request_identity=m_request_identity; permit.unique_attempt_id=m_request_identity.request_id.attempt_id;
      permit.normalized_payload=m_normalized; permit.normalization_identity=m_normalization_identity;
      permit.unit_authority_id=m_unit_authority_id; permit.unit_authority_revision=m_unit_authority_revision;
      permit.unit_authority_digest=m_unit_authority_digest; permit.symbol_specification_sequence=m_normalized.specification_sequence;
      permit.basket_id=m_binding.persistence_namespace.basket_id;
      permit.basket_state_version=m_risk_input.basket.lifecycle.state_version;
      permit.producer_trust=m_seed.current_trust; permit.producer_trust.superseding_record_id="";
      permit.risk_authorization=m_risk_authorization; permit.margin_authority=m_margin;
      permit.basket_risk_authority=m_basket_risk; permit.hard_kill_latch_id=m_risk_input.hard_kill_state.latch_id;
      permit.hard_kill_latch_generation=m_risk_input.hard_kill_state.latch_generation;
      permit.valid_from=m_seed.context.clock_time; permit.valid_until=m_risk_authorization.expires_at;
      if(!SWV5S5_DerivePermitId(permit,permit.permit_id) || !SWV5S5_DerivePermitDigest(permit,permit.permit_digest)) return false;
      ZeroMemory(m_permit_command); SWV5S5_InitContractVersion(m_permit_command.contract_version);
      m_permit_command.expected_index_digest=index_digest;
      m_permit_command.expected_index_revision=(found ? index_row.logical_revision : 0);
      m_permit_command.proposed_permit=permit;
      if(!SWV5S5_DerivePermitPreparationCommandDigest(m_permit_command,m_permit_command.command_digest)) return false;
      return SWV5S5_MvpPreparePermitCommit(m_seed.context,entries,m_permit_command,m_seed.current_trust,
         m_seed.trust_anchor,m_trust_scope,m_ingress,m_permit_result);
   }

   bool CollectOne(SWV5S5_AdmissionAuthorityCollection &collection)
   {
      if(!IncreasingEligibilityCurrent()) return false;
      ZeroMemory(collection); SWV5S5_MvpSqliteAuthorityStore store;
      SWV5S5_MvpLeasePublicationAuthority lease_authority; SWV5_InstanceLease lease; SWV5S5_MvpAuthorityRow lease_row;
      SWV5S5_MvpManualProducerTrustProvisioner trust_authority; SWV5S5_ProducerTrustRecord trust;
      SWV5S5_ProducerTrustAnchor anchor; string operator_id,authentication; bool trust_found=false;
      SWV5S5_RequestSetPublicationAuthority request_authority; SWV5_PendingRequest requests[];
      SWV5S5_SubmissionAuthorityRecord permit_record; bool permit_found=false;
      if(!store.Open(m_path,m_namespace_digest) ||
         !lease_authority.LoadCurrentLease(store,m_seed.current_lease.fence.ownership_namespace,
            m_seed.current_lease.fence,lease,lease_row) ||
         !trust_authority.Configure(m_path,m_namespace_digest) ||
         !trust_authority.LoadCurrent(trust,anchor,operator_id,authentication,trust_found) || !trust_found ||
         !m_request_set.ReadState(request_authority,requests) ||
         !SWV5S5_MvpLoadSubmissionAuthority(store,m_request_identity.request_id.correlation_id,
            m_request_identity.request_id.attempt_id,permit_record,permit_found) || !permit_found) return false;
      collection.persistence_namespace=m_binding.persistence_namespace; collection.request_identity=m_request_identity;
      collection.attempt_id=m_request_identity.request_id.attempt_id; collection.ownership.fence=lease.fence;
      collection.lease_liveness.lease=lease; collection.producer_trust.record=trust;
      collection.hard_kill.state=m_risk_input.hard_kill_state;
      collection.account.account_namespace=m_risk_input.account_namespace;
      collection.basket.basket=m_risk_input.basket.lifecycle;
      collection.request_set.persistence_namespace=m_binding.persistence_namespace;
      collection.request_set.ownership_fence=lease.fence;
      collection.request_set.header=request_authority.current_set_header;
      ArrayResize(collection.request_set.requests,ArraySize(requests));
      for(int i=0;i<ArraySize(requests);i++) collection.request_set.requests[i]=requests[i];
      collection.symbol_specification=m_symbol; collection.margin.record=m_margin;
      collection.basket_risk.record=m_basket_risk;
      collection.risk_authorization.authorization=m_risk_authorization;
      collection.risk_authorization.current_binding=m_risk_input;
      collection.normalized_payload.payload=m_normalized;
      collection.normalized_payload.normalization_identity=m_normalization_identity;
      collection.normalized_payload.unit_authority_id=m_unit_authority_id;
      collection.normalized_payload.unit_authority_revision=m_unit_authority_revision;
      collection.normalized_payload.unit_authority_digest=m_unit_authority_digest;
      SWV5S5_CanonicalNormalizedPayload("normalized",m_normalized,collection.normalized_payload.payload_content_digest);
      collection.submission_permit.permit=permit_record.permit;
      collection.policy_format.admission_policy_id=SWV5S5_POLICY_ID;
      collection.policy_format.admission_policy_version=SWV5S5_SCHEMA_VERSION;
      collection.policy_format.canonical_format_id=SWV5S5_CANONICAL_POLICY_ID;
      collection.collect_clock.clock_id=m_seed.context.clock_id;
      collection.collect_clock.clock_authority=m_seed.context.clock_authority;
      collection.collect_clock.clock_sequence=m_seed.context.clock_sequence;
      collection.collect_clock.observed_at=m_seed.context.clock_time;
      return SWV5S5_DeriveCollectionDigest(collection);
   }

   bool BuildExpectedProfile(SWV5S5_F_ProfileScope &profile)
   {
      ZeroMemory(profile); SWV5S5_F_InitVersion(profile.contract_version);
      profile.persistence_namespace=m_binding.persistence_namespace;
      profile.account_namespace=m_risk_input.account_namespace;
      profile.broker_identity=m_seed.adapter_environment.broker_identity;
      profile.server=m_seed.adapter_environment.server;
      profile.account_login=m_seed.adapter_environment.account_login;
      profile.symbol=m_seed.adapter_environment.symbol;
      profile.terminal_build=m_seed.adapter_environment.terminal_build;
      profile.mql_build=m_seed.adapter_environment.mql_build;
      profile.profile_id=SWV5S5_F_ADAPTER_PROFILE_ID;
      return SWV5S5_F_DeriveProfileDigest(profile,profile.profile_digest) && SWV5S5_F_IsProfileValid(profile) &&
         SWV5S5_F_AdapterEnvironmentMatchesProfile(profile,m_seed.adapter_environment);
   }

   bool PersistReconciliationPinBeforeClaim(void)
   {
      SWV5S5_F_ProfileScope profile; SWV5S5_MvpReconciliationGovernanceAuthority governance;
      SWV5S5_MvpAuthorityRow governance_row; bool found=false;
      if(!BuildExpectedProfile(profile) || !governance.Configure(m_path,m_namespace_digest) ||
         !governance.Load(m_seed.context.clock_time,profile,m_governance,governance_row,found) || !found) return false;
      ZeroMemory(m_claim_command); SWV5S5_InitContractVersion(m_claim_command.contract_version);
      m_claim_command.claim_policy_id=SWV5S5_POLICY_ID; m_claim_command.claim_policy_version=SWV5S5_SCHEMA_VERSION;
      m_claim_command.expected_authority_record=m_permit_result.proposed_record;
      m_claim_command.expected_authority_revision=m_permit_result.proposed_record.authority_revision;
      m_claim_command.expected_authority_digest=m_permit_result.proposed_record.durable_record_digest;
      m_claim_command.admission_proof=m_admission_proof; m_claim_command.current_ownership_lease=m_seed.current_lease;
      m_claim_command.claim_clock=m_admission_proof.snapshot.claim_clock;
      if(!SWV5S5_DeriveClaimId(m_claim_command,m_claim_command.claim_id) ||
         !SWV5S5_DeriveClaimCommandDigest(m_claim_command,m_claim_command.command_digest)) return false;
      SWV5S5_RequestSetPublicationAuthority request_authority; SWV5_PendingRequest requests[];
      if(!m_request_set.ReadState(request_authority,requests)) return false;
      string hard_kill_payload,hard_kill_digest;
      if(!SWV5S5_CanonicalHardKillState("hard_kill",m_seed.hard_kill_state,hard_kill_payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,hard_kill_payload,hard_kill_digest)) return false;
      ZeroMemory(m_pin); SWV5S5_MvpInitProductionVersion(m_pin.contract_version);
      m_pin.request_identity=m_request_identity; m_pin.permit_id=m_permit_result.proposed_record.permit.permit_id;
      m_pin.permit_digest=m_permit_result.proposed_record.permit.permit_digest;
      m_pin.admission_snapshot_digest=m_admission_proof.snapshot.snapshot_digest;
      m_pin.expected_claim_id=m_claim_command.claim_id; m_pin.broker_profile_id=profile.profile_id;
      m_pin.broker_profile_digest=profile.profile_digest;
      m_pin.correlation_policy_id=m_governance.correlation_policy.policy_id;
      m_pin.correlation_policy_version=m_governance.correlation_policy.policy_version;
      m_pin.correlation_policy_digest=m_governance.correlation_policy.policy_digest;
      m_pin.negative_policy_id=m_governance.negative_policy.policy_id;
      m_pin.negative_policy_version=m_governance.negative_policy.policy_version;
      m_pin.negative_policy_digest=m_governance.negative_policy.policy_digest;
      m_pin.capability_proof_id=m_governance.capability_proof.artifact_id;
      m_pin.capability_proof_version=m_governance.capability_proof.artifact_version;
      m_pin.capability_proof_digest=m_governance.capability_proof.proof_digest;
      m_pin.symbol_specification_sequence=m_symbol.specification.specification_sequence;
      m_pin.expected_basket_version=m_risk_input.intent.expected_basket_version;
      m_pin.direction=m_risk_input.intent.direction; m_pin.requested_volume=m_risk_input.intent.normalized_volume;
      m_pin.request_set_digest=request_authority.current_complete_set_digest; m_pin.hard_kill_state_digest=hard_kill_digest;
      m_pin.expected_broker_query_high_watermark=0; m_pin.expected_execution_query_high_watermark=0;
      SWV5S5_MvpAttemptReconciliationPinAuthority pins;
      m_pin_durable=pins.Configure(m_path,m_namespace_digest) &&
         pins.PersistBeforeClaim(m_pin,m_ownership_row,m_seed.context.clock_time,m_pin_row);
      return m_pin_durable;
   }

   bool RevalidateDurablePinAndVectorBeforeClaim(void)
   {
      SWV5S5_MvpAttemptReconciliationPinAuthority authority;
      SWV5S5_MvpAttemptReconciliationPin loaded; SWV5S5_MvpAuthorityRow pin_row,vector_row;
      bool pin_found=false,vector_found=false;
      return authority.Configure(m_path,m_namespace_digest) &&
         authority.Load(m_pin.request_identity,loaded,pin_row,pin_found) && pin_found &&
         loaded.pin_digest==m_pin.pin_digest && pin_row.store_revision==m_pin_row.store_revision &&
          authority.LoadInitialVector(loaded,vector_row,vector_found) && vector_found;
   }

   // Bind the broker evidence store only from the durable post-Claim graph.
   // This is deliberately performed before the submission boundary receives
   // the store, so synchronous evidence cannot be persisted against an
   // in-memory or launch-wrapper-authored reconciliation identity.
   bool BindDurableOperationBeforeAdapter(void)
   {
      m_last_stage="ADAPTER_BIND_INPUT";
      if(!m_claimed || m_evidence_store==NULL) return false;
      const SWV5S5_SubmissionAuthorityRecord claimed=m_claim_result.resulting_authority_record;
      SWV5S5_F_ProfileScope profile;
      if(!BuildExpectedProfile(profile) || profile.profile_digest!=m_pin.broker_profile_digest) return false;

      m_last_stage="ADAPTER_BIND_REQUEST_SET";
      SWV5S5_MvpRequestSetPublicationAuthority request_set;
      SWV5S5_RequestSetPublicationAuthority request_authority; SWV5_PendingRequest requests[];
      if(!request_set.Configure(m_path,m_namespace_digest) || !request_set.ReadState(request_authority,requests))
         return false;
      int exact=-1;
      for(int i=0;i<ArraySize(requests);i++)
         if(SWV5S5_EqualRequestIdentity(requests[i].intent.request_identity,claimed.permit.request_identity))
         { if(exact>=0) return false; exact=i; }
      if(exact<0) return false;

      m_last_stage="ADAPTER_BIND_VECTOR";
      SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpAuthorityRow hard_kill_row,reconciliation_row;
      bool hard_kill_found=false,reconciliation_found=false;
      const string key=SWV5S5_MvpAttemptPinKey(claimed.permit.request_identity);
      if(!store.Open(m_path,m_namespace_digest) ||
         !store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",hard_kill_row,hard_kill_found) || !hard_kill_found ||
         !store.ReadRow(SWV5S5_MVP_DOMAIN_RECONCILIATION,key,reconciliation_row,reconciliation_found) ||
         !reconciliation_found || reconciliation_row.logical_revision==0 ||
         reconciliation_row.state!=(int)SWV5S5_F_SUBMISSION_UNRESOLVED) return false;
      SWV5S5_MvpAttemptReconciliationPinAuthority pin_authority;
      SWV5S5_MvpAuthorityRow initial_vector_row; bool initial_vector_found=false;
      if(!pin_authority.Configure(m_path,m_namespace_digest) ||
         !pin_authority.LoadInitialVector(m_pin,initial_vector_row,initial_vector_found) ||
         !initial_vector_found || initial_vector_row.store_revision!=reconciliation_row.store_revision) return false;

      m_last_stage="ADAPTER_BIND_EXECUTION";
      SWV5S5_MvpExecutionPendingQuery execution_query;
      if(!execution_query.Configure(m_path,m_namespace_digest) ||
         !execution_query.CaptureFromCurrentRequestSet(1,1,m_seed.context.clock_time)) return false;
      SWV5S5_MvpAuthorityRow execution_row; bool execution_found=false;
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_EXECUTION_PENDING,"CURRENT",execution_row,execution_found) ||
         !execution_found) return false;

      m_last_stage="ADAPTER_BIND_DIGESTS";
      string ordered_request_body,ordered_request_digest,checkpoint_body="",checkpoint_digest,f;
      if(!SWV5S5_CanonicalPendingRequest(requests[exact],ordered_request_body) ||
         !SWV5S5_DomainDigest("SWV5-S5-MVP-D6-ORDERED-REQUEST-EVIDENCE-V1",ordered_request_body,
                              ordered_request_digest)) return false;
      if(!SWV5S5_CanonicalString("claim",claimed.durable_record_digest,f)) return false; checkpoint_body+=f;
      if(!SWV5S5_CanonicalString("pin",m_pin.pin_digest,f)) return false; checkpoint_body+=f;
      if(!SWV5S5_CanonicalString("request_set",request_authority.current_complete_set_digest,f)) return false; checkpoint_body+=f;
      if(!SWV5S5_CanonicalString("reconciliation",reconciliation_row.payload_digest,f)) return false; checkpoint_body+=f;
      if(!SWV5S5_DomainDigest("SWV5-S5-MVP-D6-CHECKPOINT-V1",checkpoint_body,checkpoint_digest)) return false;

      m_last_stage="ADAPTER_BIND_CROSS_SOURCE";
      if(!SWV5S5_EqualRequestIdentity(m_pin.request_identity,claimed.permit.request_identity) ||
         m_pin.permit_id!=claimed.permit.permit_id || m_pin.permit_digest!=claimed.permit.permit_digest ||
         m_pin.admission_snapshot_digest!=claimed.admission_snapshot_digest ||
         m_pin.expected_claim_id!=claimed.invocation_claim_id ||
         m_pin.request_set_digest!=request_authority.current_complete_set_digest ||
         m_pin.hard_kill_state_digest!=hard_kill_row.payload_digest) return false;

      SWV5S5_F_ReconciliationBinding binding; ZeroMemory(binding); SWV5S5_F_InitVersion(binding.contract_version);
      binding.profile=profile; binding.request_identity=claimed.permit.request_identity;
      binding.submission_state=claimed.state; binding.pending_request_state=requests[exact].state;
      binding.pending_request_phase=requests[exact].lifecycle_phase; binding.permit_id=claimed.permit.permit_id;
      binding.invocation_claim_id=claimed.invocation_claim_id; binding.admission_snapshot_digest=claimed.admission_snapshot_digest;
      binding.claim_record_digest=claimed.durable_record_digest;
      binding.pinned_correlation_policy_id=m_pin.correlation_policy_id;
      binding.pinned_correlation_policy_version=m_pin.correlation_policy_version;
      binding.pinned_correlation_policy_digest=m_pin.correlation_policy_digest;
      binding.pinned_negative_policy_id=m_pin.negative_policy_id;
      binding.pinned_negative_policy_version=m_pin.negative_policy_version;
      binding.pinned_negative_policy_digest=m_pin.negative_policy_digest;
      binding.pinned_capability_proof_id=m_pin.capability_proof_id;
      binding.pinned_capability_proof_version=m_pin.capability_proof_version;
      binding.pinned_capability_proof_digest=m_pin.capability_proof_digest;
      binding.claimed_at=claimed.claimed_at; binding.claim_clock_sequence=claimed.claim_clock_sequence;
      binding.claim_ownership_fence=claimed.claim_ownership_lease.fence;
      binding.current_reconciliation_lease=m_seed.current_lease;
      binding.expected_store_revision=m_seed.current_lease.store_revision;
      binding.expected_reconciliation_revision=reconciliation_row.logical_revision;
      binding.expected_broker_query_high_watermark=m_pin.expected_broker_query_high_watermark;
      binding.expected_execution_query_high_watermark=m_pin.expected_execution_query_high_watermark;
      binding.persisted_reconciliation_vector_digest=reconciliation_row.payload_digest;
      binding.checkpoint_digest=checkpoint_digest; binding.request_set_digest=request_authority.current_complete_set_digest;
      binding.execution_pending_summary_digest=execution_row.payload_digest;
      binding.ordered_request_evidence_digest=ordered_request_digest;
      binding.hard_kill_state_digest=hard_kill_row.payload_digest;
      binding.symbol_specification_sequence=m_pin.symbol_specification_sequence;
      binding.expected_basket_version=m_pin.expected_basket_version; binding.direction=m_pin.direction;
      binding.requested_volume=m_pin.requested_volume; binding.persisted_confirmed_volume=0.0;
      binding.persisted_residual_volume=m_pin.requested_volume; binding.persisted_terminal_evidence_digest="";
      m_last_stage="ADAPTER_BIND_VALIDATE";
      if(!SWV5S5_F_IsBindingValid(m_seed.context,binding)) return false;
      m_last_stage="ADAPTER_BIND_STORE";
      if(!m_evidence_store.BindAuthoritativeOperation(m_seed.context,binding)) return false;
      m_last_stage="ADAPTER_BIND_COMPLETE";
      return true;
   }

public:
   SWV5S5_MvpControlledDemoAuthorityPort(void)
   { m_platform=NULL; m_evidence_store=NULL; m_broker_recovery=NULL; m_configured=false; m_bootstrapped=false;
     m_permit_prepared=false; m_permit_committed=false; m_admission_ready=false; m_claimed=false;
     m_store_schema_valid=false; m_genesis_valid=false; m_ownership_current=false; m_trust_current=false;
      m_safety_current=false; m_initial_request_set_empty=false; m_initial_submission_index_empty=false;
      m_pin_durable=false; ZeroMemory(m_ownership_row); ZeroMemory(m_pin_row); ZeroMemory(m_governance); ZeroMemory(m_pin); }

   bool Configure(const string path,const string namespace_digest,
                   const SWV5S5_MvpControlledDemoAuthoritySeed &seed,
                   ISWV5S5MvpReadOnlyPlatform *platform,SWV5S5_MvpBrokerEvidenceStore *evidence_store,
                   ISWV5S5MvpBrokerRecoveryReadPort *broker_recovery=NULL)
   {
      m_path=path; m_namespace_digest=namespace_digest; m_seed=seed;
      m_platform=platform; m_evidence_store=evidence_store; m_broker_recovery=broker_recovery;
      m_configured=path!="" && namespace_digest!="" && platform!=NULL && evidence_store!=NULL;
      m_last_stage=(m_configured ? "CONFIGURED" : "CONFIGURE_REJECTED");
      return m_configured;
   }

   string LastStage(void) const { return m_last_stage; }

   virtual bool CollectReadOnlyPreflight(const SWV5S5_MvpControlledDemoInvocation &invocation,const int direction,
                                         SWV5S5_MvpControlledDemoPreflightEvidence &evidence)
   {
      m_last_stage="READ_ONLY_PREFLIGHT"; ZeroMemory(evidence);
      if(!m_configured || (direction!=1 && direction!=-1) || !CollectPhysicalPreconditions(invocation) ||
         !CollectReadOnlyExecutionState() || !FillReadOnlyEvidence(invocation,direction,evidence)) return false;
      m_last_stage="READ_ONLY_PREFLIGHT_COMPLETE"; return true;
   }

   virtual bool PrepareD1AuthorityPath(const SWV5S5_MvpControlledDemoInvocation &invocation,const int direction,
                                  SWV5S5_MvpControlledDemoPreflightEvidence &evidence)
   {
      m_last_stage="PREFLIGHT_INVOCATION";
      ZeroMemory(evidence); if(!m_configured || direction!=(int)m_seed.decision.action ||
         ((invocation.mode==MODE_D1_BUY && direction!=1) || (invocation.mode==MODE_D3_SELL && direction!=-1))) return false;
      m_last_stage="PREFLIGHT_PHYSICAL";
      if(!CollectPhysicalPreconditions(invocation)) return false;
      m_last_stage="PREFLIGHT_SIGNAL";
      SWV5S5_MvpSignalIngressAdapter signal; bool ingress_replayed=false;
      if(!signal.Configure(m_path,m_namespace_digest) ||
         !signal.Publish(m_seed.engine_input,m_seed.decision,m_seed.current_trust,m_seed.context,m_ingress,ingress_replayed)) return false;
      ZeroMemory(m_trust_scope); m_trust_scope.persistence_namespace=m_seed.current_trust.persistence_namespace;
      m_trust_scope.producer_component=m_seed.current_trust.producer_component;
      m_trust_scope.producer_instance=m_seed.current_trust.producer_instance;
      m_trust_scope.producer_epoch=m_seed.current_trust.producer_epoch; m_trust_scope.symbol=m_seed.current_trust.symbol;
      m_trust_scope.timeframe=m_seed.current_trust.timeframe; m_trust_scope.execution_mode=m_seed.current_trust.execution_mode;
      m_trust_scope.publication_clock_id=m_seed.current_trust.clock_id;
      m_trust_scope.publication_clock_authority=m_seed.current_trust.clock_authority;
      m_trust_scope.ingress_identity=m_ingress.ingress_identity;
      SWV5S5_IngressFreshnessPolicy freshness; freshness.policy_id=SWV5S5_POLICY_ID;
      freshness.clock_id=m_seed.context.clock_id; freshness.clock_authority=m_seed.context.clock_authority;
      freshness.max_age_seconds=5; freshness.max_future_skew_seconds=0;
      SWV5S5_IngressValidationResult ingress_validation;
      m_last_stage="PREFLIGHT_TRUST";
      if(!SWV5S5_ValidateTrustedIngressForAcceptance(m_seed.context,m_ingress,freshness,m_seed.current_trust,
         m_seed.trust_anchor,m_trust_scope,ingress_validation) || !ingress_validation.directional_nomination) return false;
      const SWV5_PersistenceNamespace scope=m_seed.current_trust.persistence_namespace;
      m_last_stage="PREFLIGHT_AUTHORITIES";
      if(!m_sequence.Configure(m_path,m_namespace_digest) || !m_sequence.Initialize(scope,m_seed.current_lease.fence,m_seed.context.clock_time) ||
         !m_ledger.Configure(m_path,m_namespace_digest) || !m_ledger.Initialize(scope,m_seed.current_lease.fence,m_seed.current_trust,m_seed.context) ||
         !m_request_set.Configure(m_path,m_namespace_digest) || !m_request_set.Initialize(scope,m_seed.current_lease.fence,m_seed.context.clock_time)) return false;
      SWV5S5_RequestSetPublicationAuthority initial_set; SWV5_PendingRequest initial_requests[];
      SWV5S5_SubmissionAuthorityIndexEntry initial_submissions[]; SWV5S5_MvpSqliteAuthorityStore initial_store;
      SWV5S5_MvpAuthorityRow initial_index_row; bool initial_index_found=false;
      if(!m_request_set.ReadState(initial_set,initial_requests) ||
         !initial_store.Open(m_path,m_namespace_digest) ||
         !SWV5S5_MvpLoadSubmissionIndex(initial_store,initial_submissions,initial_index_row,initial_index_found)) return false;
      m_initial_request_set_empty=(ArraySize(initial_requests)==0);
      m_initial_submission_index_empty=(ArraySize(initial_submissions)==0);
      if(!m_initial_request_set_empty || !m_initial_submission_index_empty) return false;
      m_last_stage="PREFLIGHT_SEQUENCE";
      string correlation,attempt,idempotency;
      if(!SWV5S5_DeriveRequestBinding(scope,SWV5S5_REQUEST_BINDING_POLICY_ID,
         SWV5S5_REQUEST_BINDING_POLICY_VERSION,m_ingress.ingress_identity,0,correlation,attempt,idempotency)) return false;
      SWV5S5_RequestSequenceAuthority sequence_state; SWV5S5_RequestSequenceIndexEntry sequence_entries[];
      SWV5S5_RequestSequenceReservation sequence_proposal; SWV5S5_CoordinatorSequenceOperationResult sequence_result;
      if(!m_sequence.ReadState("D1-BOOTSTRAP",1,sequence_state,sequence_entries) ||
         !SWV5S5_MvpPrepareSequenceProposal(sequence_state,sequence_entries,correlation,m_ingress.payload_digest,sequence_proposal) ||
         !m_sequence.TryReserveRequestSequence(sequence_state,sequence_entries,sequence_proposal,"D1-BOOTSTRAP",1,sequence_result) ||
         !SWV5S5_MvpBuildRequestBindingSeed(scope,m_ingress.ingress_identity,m_seed.context.clock_time,
            sequence_result.authoritative_result.reserved_sequence,m_binding,m_request_identity)) return false;
      SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpSymbolSpecificationAuthority symbol_authority;
      m_last_stage="PREFLIGHT_SYMBOL";
      if(!store.Open(m_path,m_namespace_digest) || !symbol_authority.Refresh(store,*m_platform,m_seed.context.clock_time,m_symbol)) return false;
      SWV5_UnitNormalizationRequest unit; ZeroMemory(unit); SWV5S5_MvpInitProductionVersion(unit.contract_version);
      unit.persistence_namespace=scope; unit.ownership_fence=m_seed.current_lease.fence; unit.intent_type=SWV5_INTENT_OPEN;
      unit.purpose=SWV5_PRICE_ENTRY; unit.operation_kind=SWV5_OPERATION_MARKET_ENTRY; unit.direction=direction;
      unit.raw_price=invocation.requested_price; unit.raw_stop_price=invocation.protective_stop_price;
      unit.raw_limit_price=invocation.optional_take_profit_price; unit.raw_volume=invocation.requested_volume;
      unit.current_exposure_volume=0.0; unit.target_exposure_volume=invocation.requested_volume;
      unit.reference_market_price=invocation.requested_price; unit.operation_price=invocation.requested_price;
      unit.market_bid=(direction>0 ? invocation.requested_price-m_symbol.specification.point_size : invocation.requested_price);
      unit.market_ask=(direction>0 ? invocation.requested_price : invocation.requested_price+m_symbol.specification.point_size);
      unit.expected_specification_sequence=m_symbol.specification.specification_sequence;
      unit.exposure_increasing=true; unit.protective_operation=false;
      SWV5S5_MvpUnitSystemContract unit_contract; SWV5_UnitValidationResult unit_result;
      m_last_stage="PREFLIGHT_UNITS";
      if(!unit_contract.Normalize(m_seed.context,m_symbol.specification,unit,m_normalized,unit_result) ||
         !SWV5S5_MvpDeriveNormalizationAuthority(m_normalized,m_normalization_identity,m_unit_authority_id,
            m_unit_authority_revision,m_unit_authority_digest)) return false;
      SWV5S5_MvpIncreasingAuthorityInput increasing; ZeroMemory(increasing);
      increasing.context=m_seed.context; increasing.persistence_namespace=scope;
      increasing.account_namespace=m_seed.risk_observation.account_namespace;
      increasing.ownership_fence=m_seed.current_lease.fence; increasing.request_identity=m_request_identity;
      increasing.basket=m_seed.risk_observation.basket.lifecycle; increasing.symbol=m_symbol;
      increasing.normalized=m_normalized; increasing.account=m_seed.account_observation;
      increasing.direction=direction;
      SWV5S5_MvpMarginAuthority margin_authority; SWV5S5_MvpBasketRiskAuthority basket_risk_authority;
      m_last_stage="PREFLIGHT_RISK";
      if(!margin_authority.Issue(store,*m_platform,increasing,m_margin) ||
         !basket_risk_authority.Issue(store,*m_platform,increasing,m_basket_risk) || !PrepareRiskInput(direction)) return false;
      SWV5S5_ValidationResult trust_revalidation;
      m_last_stage="PREFLIGHT_TRUST_REVALIDATION";
      if(!SWV5S5_ValidateProducerTrust(m_seed.context,m_seed.current_trust,m_seed.trust_anchor,
         m_trust_scope,m_ingress,trust_revalidation)) return false;
      SWV5S5_DeterministicCoordinator coordinator; SWV5S5_MvpNoopCoordinatorTrace trace;
      SWV5S5_CoordinatorIngressEvent event; ZeroMemory(event); event.event_id="D1-BOOTSTRAP"; event.event_ordinal=1;
      event.persistence_namespace=scope; event.context=m_seed.context; event.ingress=m_ingress; event.freshness=freshness;
      event.current_trust=m_seed.current_trust; event.trust_anchor=m_seed.trust_anchor; event.trust_scope=m_trust_scope;
      SWV5S5_CoordinatorLedgerEvaluation ledger_evaluation; SWV5S5_IngressLedgerIndexEntry ledger_entries[];
      SWV5S5_IngressLedgerRecord ledger_records[]; SWV5S5_CoordinatorResult ingress_result;
      m_last_stage="PREFLIGHT_LEDGER";
      if(!coordinator.ProcessIngress(event,m_ledger,trace,ledger_evaluation,ledger_entries,ledger_records,ingress_result) ||
         ingress_result.disposition!=SWV5S5_COORD_LEDGER_ACCEPTED_NEW) return false;
      SWV5S5_CoordinatorMaterializationInput materialization; ZeroMemory(materialization);
      materialization.event_id=event.event_id; materialization.event_ordinal=event.event_ordinal;
      materialization.context=m_seed.context; materialization.accepted_ingress=m_ingress;
      materialization.ledger=ledger_evaluation; materialization.normalized_payload=m_normalized;
      materialization.normalization_identity=m_normalization_identity; materialization.risk_authorization=m_risk_authorization;
      SWV5S5_MvpBlueprintAuthority blueprint; SWV5S5_MvpRequestProgressionAuthority progression;
      SWV5S5_MvpExecutionLifecycleAuthority lifecycle; progression.SetChangedAt(m_seed.context.clock_time);
      m_last_stage="PREFLIGHT_MATERIALIZATION";
      if(!coordinator.MaterializeAndProgress(materialization,ledger_entries,ledger_records,m_ledger,m_sequence,
         blueprint,progression,lifecycle,m_materialization))
      {
         m_last_stage="PREFLIGHT_MATERIALIZATION_"+m_materialization.reason_code;
         return false;
      }
      m_last_stage="PREFLIGHT_MATERIALIZATION_IDENTITY";
      if(!SWV5S5_EqualRequestIdentity(m_materialization.blueprint.pending_request.intent.request_identity,
                                      m_request_identity)) return false;
      m_last_stage="PREFLIGHT_REQUEST_PUBLISH_BIND";
      if(!PublishRequestAndBind()) return false;
      evidence.profile_exact=m_observed_profile.broker_identity==m_seed.adapter_environment.broker_identity &&
         m_observed_profile.server==m_seed.adapter_environment.server &&
         m_observed_profile.account_login==m_seed.adapter_environment.account_login &&
         m_observed_profile.symbol==m_seed.adapter_environment.symbol;
      evidence.demo_account=m_observed_profile.account_trade_mode==ACCOUNT_TRADE_MODE_DEMO;
      evidence.usd_account=m_observed_profile.account_currency==SWV5S5_MVP_ACCOUNT_CURRENCY;
      evidence.hedging_account=m_observed_profile.account_mode==SWV5_ACCOUNT_MODE_HEDGING;
      evidence.symbol_exact=m_observed_profile.symbol==SWV5S5_MVP_SYMBOL;
      evidence.connected=m_observed_profile.connected && m_seed.adapter_environment.connected;
      evidence.permissions_observed=SWV5S5_F_AdapterPermissionsAllowMutation(m_seed.adapter_environment);
      evidence.store_schema_valid=m_store_schema_valid; evidence.genesis_valid=m_genesis_valid;
      evidence.ownership_current=m_ownership_current; evidence.trust_complete=m_trust_current;
      evidence.trust_current_unexpired=m_seed.current_trust.status==SWV5S5_TRUST_AUTHORIZED &&
         m_seed.current_trust.valid_from<=m_seed.context.clock_time &&
         m_seed.context.clock_time<m_seed.current_trust.valid_until;
      evidence.safety_allows_execution=m_safety_current;
      evidence.broker_observation_complete=m_observed_account.complete && m_observed_account.history_complete;
      evidence.execution_observation_complete=m_initial_request_set_empty && m_initial_submission_index_empty;
      evidence.no_position=m_observed_account.positions_total==0;
      evidence.no_active_order=m_observed_account.orders_total==0;
      evidence.no_unresolved_submission=m_initial_submission_index_empty;
      evidence.no_competing_operation=m_initial_request_set_empty;
      evidence.symbol_specification_fresh=SWV5S5_MvpSpecificationValid(m_seed.context,m_symbol.specification);
      evidence.units_valid=m_normalized.volume>0.0 && m_normalized.volume<=SWV5S5_MVP_MAX_VOLUME &&
         m_normalized.price_aligned_to_tick && m_normalized.volume_aligned_to_step;
      evidence.margin_valid=m_margin.authority_record_id!="" &&
         SWV5S5_IsDigest64Lower(m_margin.authority_record_digest);
      evidence.basket_risk_valid=m_basket_risk.authority_record_id!="" &&
         SWV5S5_IsDigest64Lower(m_basket_risk.authority_record_digest);
      evidence.risk_inputs_valid=m_risk_authorization.disposition==SWV5_RISK_ALLOW &&
         SWV5S5_MvpRiskAuthorizationCoherent(m_risk_input,m_risk_authorization);
      evidence.protective_stop_valid=(direction>0 ? m_normalized.stop_price<m_normalized.price :
                                                     m_normalized.stop_price>m_normalized.price);
      evidence.prospective_permit_preparable=m_materialization.progressed_request.state==SWV5_REQUEST_SUBMISSION_PENDING;
      evidence.d1_terminal=(invocation.mode!=MODE_D3_SELL); evidence.manual_cleanup_independently_observed=(invocation.mode!=MODE_D3_SELL);
      evidence.independent_request_identity=true; evidence.request_correlation_id=m_request_identity.request_id.correlation_id;
      evidence.attempt_id=m_request_identity.request_id.attempt_id; m_bootstrapped=true;
      m_last_stage="PREFLIGHT_COMPLETE"; return true;
   }

   virtual bool PreparePermitSemantics(void)
   { m_permit_prepared=m_bootstrapped && IncreasingEligibilityCurrent() && BuildPermit(); return m_permit_prepared; }
   virtual bool CommitPermitPhysical(void)
   {
      if(!m_permit_prepared || !IncreasingEligibilityCurrent() || !m_permit_authority.Configure(m_path,m_namespace_digest) ||
         !m_permit_authority.StagePrepared(m_permit_result)) return false;
      SWV5S5_SubmissionAuthorityIndexEntry entries[]; SWV5S5_MvpSqliteAuthorityStore store;
      SWV5S5_MvpAuthorityRow row; bool found=false;
      if(!store.Open(m_path,m_namespace_digest) || !SWV5S5_MvpLoadSubmissionIndex(store,entries,row,found)) return false;
      SWV5S5_PermitPreparationResult committed;
      m_permit_committed=m_permit_authority.TryCommitPermit(m_permit_command,entries,committed);
      if(m_permit_committed) m_permit_result=committed;
      return m_permit_committed;
   }
   virtual bool CollectAdmissionSameEvent(void)
   {
      if(!m_permit_committed || !IncreasingEligibilityCurrent()) return false;
      SWV5S5_AdmissionSnapshot snapshot; ZeroMemory(snapshot); SWV5S5_InitContractVersion(snapshot.contract_version);
      snapshot.canonical_policy_id=SWV5S5_CANONICAL_POLICY_ID;
      if(!CollectOne(snapshot.collect_v1) || !CollectOne(snapshot.collect_v2)) return false;
      snapshot.claim_clock.clock_id=m_seed.context.clock_id; snapshot.claim_clock.clock_authority=m_seed.context.clock_authority;
      snapshot.claim_clock.clock_sequence=m_seed.context.clock_sequence; snapshot.claim_clock.observed_at=m_seed.context.clock_time;
      SWV5S5_AdmissionProofInput proof_input; ZeroMemory(proof_input); proof_input.trust_anchor=m_seed.trust_anchor;
      proof_input.trust_scope=m_trust_scope; proof_input.accepted_ingress=m_ingress;
      proof_input.current_ownership_lease=m_seed.current_lease;
      SWV5S5_DoubleCollectResult result; SWV5S5_MvpRiskContract risk;
      m_admission_ready=SWV5S5_DoubleCollect(m_seed.context,proof_input,risk,snapshot,result,m_admission_proof);
      return m_admission_ready && PersistReconciliationPinBeforeClaim();
   }
   virtual bool ClaimPhysicalNow(bool &claim_granted_now)
   {
      claim_granted_now=false;
      SWV5S5_MvpSqliteAuthorityStore safety_store; SWV5S5_MvpHardKillActivationAuthority activation;
      if(!m_admission_ready || !m_pin_durable || !safety_store.Open(m_path,m_namespace_digest) ||
         !activation.ValidateAdmittedEligibility(safety_store,m_seed.context,m_admission_proof,m_seed.current_lease) ||
         !RevalidateDurablePinAndVectorBeforeClaim()) return false;
      SWV5S5_MvpRiskContract risk;
      if(!SWV5S5_PrepareInvocationClaimTransition(m_seed.context,risk,m_claim_command,m_claim_transition) ||
         !m_claim_authority.Configure(m_path,m_namespace_digest) || !m_claim_authority.StagePrepared(m_claim_transition) ||
         !m_claim_authority.TryClaimInvocation(m_claim_command,m_claim_result)) return false;
      claim_granted_now=m_claim_result.claim_granted_now;
      m_claimed=claim_granted_now && m_claim_result.resulting_authority_record.invocation_claim_id==m_pin.expected_claim_id &&
         m_claim_result.resulting_authority_record.permit.permit_id==m_pin.permit_id &&
         m_claim_result.resulting_authority_record.permit.permit_digest==m_pin.permit_digest &&
         m_claim_result.resulting_authority_record.admission_snapshot_digest==m_pin.admission_snapshot_digest &&
         SWV5S5_EqualRequestIdentity(m_claim_result.resulting_authority_record.permit.request_identity,m_pin.request_identity);
      return m_claimed;
   }
   virtual bool ReloadAndReconcileD6(SWV5S5_MvpControlledDemoRecoveryEvidence &evidence)
   {
      ZeroMemory(evidence); evidence.reason_code="D6_RECOVERY_INPUT_INVALID";
      if(!m_configured || m_evidence_store==NULL || m_broker_recovery==NULL) return false;
      SWV5S5_MvpSqliteAuthorityStore store;
      if(!store.Open(m_path,m_namespace_digest)) return false;
      evidence.store_schema_valid=true;

      // Reload the single durable unresolved Claim. claim_granted_now is
      // intentionally never reconstructed after process/object restart.
      SWV5S5_MvpInvocationClaimAuthority claims; SWV5S5_MvpReloadedClaim reloaded;
      if(!claims.Configure(m_path,m_namespace_digest) || !claims.ReloadClaim(reloaded) || !reloaded.found ||
         reloaded.claim_granted_now || reloaded.state!=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED) return false;
      evidence.exact_unresolved_claim_found=true; evidence.complete_claim_reloaded_from_sqlite=true;
      evidence.claim_granted_now=false; evidence.request_correlation_id=reloaded.logical_correlation_id;
      evidence.attempt_id=reloaded.attempt_id;
      const SWV5S5_SubmissionAuthorityRecord claimed=reloaded.authority_record;

      SWV5S5_MvpControlledDemoD6OwnershipLoader ownership_loader;
      SWV5_InstanceLease current_lease; SWV5S5_MvpAuthorityRow ownership_row;
      if(!ownership_loader.ReloadCurrent(m_path,m_namespace_digest,
         claimed.permit.persistence_namespace.ownership_namespace,m_seed.current_lease.fence,
         m_seed.context,current_lease,ownership_row)) return false;
      evidence.ownership_reloaded_from_sqlite=true; evidence.ownership_current=true;

      SWV5S5_F_ProfileScope profile; ZeroMemory(profile); SWV5S5_F_InitVersion(profile.contract_version);
      profile.persistence_namespace=claimed.permit.persistence_namespace;
      profile.account_namespace=claimed.permit.account_namespace;
      profile.broker_identity=m_seed.adapter_environment.broker_identity;
      profile.server=m_seed.adapter_environment.server; profile.account_login=m_seed.adapter_environment.account_login;
      profile.symbol=m_seed.adapter_environment.symbol; profile.terminal_build=m_seed.adapter_environment.terminal_build;
      profile.mql_build=m_seed.adapter_environment.mql_build; profile.profile_id=SWV5S5_F_ADAPTER_PROFILE_ID;
      if(!SWV5S5_F_DeriveProfileDigest(profile,profile.profile_digest) || !SWV5S5_F_IsProfileValid(profile) ||
         !SWV5S5_F_AdapterEnvironmentMatchesProfile(profile,m_seed.adapter_environment)) return false;

      SWV5S5_MvpAttemptReconciliationPinAuthority pin_authority; SWV5S5_MvpAuthorityRow pin_row;
      SWV5S5_MvpAttemptReconciliationPin pin; bool pin_found=false;
      SWV5S5_MvpReconciliationGovernanceAuthority governance_authority;
      SWV5S5_MvpReconciliationGovernanceBundle governance; SWV5S5_MvpAuthorityRow governance_row;
      bool governance_found=false;
      if(!pin_authority.Configure(m_path,m_namespace_digest) ||
         !pin_authority.Load(claimed.permit.request_identity,pin,pin_row,pin_found) || !pin_found ||
         !governance_authority.Configure(m_path,m_namespace_digest) ||
         !governance_authority.Load(m_seed.context.clock_time,profile,governance,governance_row,governance_found) ||
         !governance_found) return false;

      SWV5S5_MvpRequestSetPublicationAuthority request_set; SWV5S5_RequestSetPublicationAuthority request_authority;
      SWV5_PendingRequest requests[]; int exact=-1;
      if(!request_set.Configure(m_path,m_namespace_digest) || !request_set.ReadState(request_authority,requests)) return false;
      for(int i=0;i<ArraySize(requests);i++)
         if(SWV5S5_EqualRequestIdentity(requests[i].intent.request_identity,claimed.permit.request_identity))
         { if(exact>=0) return false; exact=i; }
      if(exact<0) return false;

      SWV5S5_MvpAuthorityRow hard_kill_row,reconciliation_row; bool hard_kill_found=false,reconciliation_found=false;
      const string key=SWV5S5_MvpAttemptPinKey(claimed.permit.request_identity);
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",hard_kill_row,hard_kill_found) || !hard_kill_found ||
         !store.ReadRow(SWV5S5_MVP_DOMAIN_RECONCILIATION,key,reconciliation_row,reconciliation_found) ||
         !reconciliation_found || reconciliation_row.logical_revision==0 ||
         reconciliation_row.state!=(int)SWV5S5_F_SUBMISSION_UNRESOLVED) return false;
      SWV5S5_MvpAuthorityRow initial_vector_row; bool initial_vector_found=false;
      if(!pin_authority.LoadInitialVector(pin,initial_vector_row,initial_vector_found) || !initial_vector_found ||
         initial_vector_row.store_revision!=reconciliation_row.store_revision) return false;

      SWV5S5_MvpExecutionPendingQuery execution_query;
      if(!execution_query.Configure(m_path,m_namespace_digest) ||
         !execution_query.CaptureFromCurrentRequestSet(1,1,m_seed.context.clock_time)) return false;
      SWV5S5_MvpAuthorityRow execution_row; bool execution_found=false;
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_EXECUTION_PENDING,"CURRENT",execution_row,execution_found) ||
         !execution_found) return false;

      string ordered_request_body,ordered_request_digest,checkpoint_body="",checkpoint_digest,f;
      if(!SWV5S5_CanonicalPendingRequest(requests[exact],ordered_request_body) ||
         !SWV5S5_DomainDigest("SWV5-S5-MVP-D6-ORDERED-REQUEST-EVIDENCE-V1",ordered_request_body,
                              ordered_request_digest)) return false;
      if(!SWV5S5_CanonicalString("claim",claimed.durable_record_digest,f)) return false; checkpoint_body+=f;
      if(!SWV5S5_CanonicalString("pin",pin.pin_digest,f)) return false; checkpoint_body+=f;
      if(!SWV5S5_CanonicalString("request_set",request_authority.current_complete_set_digest,f)) return false; checkpoint_body+=f;
      if(!SWV5S5_CanonicalString("reconciliation",reconciliation_row.payload_digest,f)) return false; checkpoint_body+=f;
      if(!SWV5S5_DomainDigest("SWV5-S5-MVP-D6-CHECKPOINT-V1",checkpoint_body,checkpoint_digest)) return false;

      // Exact immutable cross-source validation. No launch-wrapper semantic
      // field is accepted and the pin is never rewritten after Claim.
      if(!SWV5S5_EqualRequestIdentity(pin.request_identity,claimed.permit.request_identity) ||
         pin.permit_id!=claimed.permit.permit_id || pin.permit_digest!=claimed.permit.permit_digest ||
         pin.admission_snapshot_digest!=claimed.admission_snapshot_digest ||
         pin.expected_claim_id!=claimed.invocation_claim_id || pin.broker_profile_id!=profile.profile_id ||
         pin.broker_profile_digest!=profile.profile_digest ||
         pin.correlation_policy_id!=governance.correlation_policy.policy_id ||
         pin.correlation_policy_version!=governance.correlation_policy.policy_version ||
         pin.correlation_policy_digest!=governance.correlation_policy.policy_digest ||
         pin.negative_policy_id!=governance.negative_policy.policy_id ||
         pin.negative_policy_version!=governance.negative_policy.policy_version ||
         pin.negative_policy_digest!=governance.negative_policy.policy_digest ||
         pin.capability_proof_id!=governance.capability_proof.artifact_id ||
         pin.capability_proof_version!=governance.capability_proof.artifact_version ||
         pin.capability_proof_digest!=governance.capability_proof.proof_digest ||
         pin.symbol_specification_sequence!=claimed.permit.symbol_specification_sequence ||
         pin.expected_basket_version!=claimed.permit.basket_state_version ||
         pin.direction!=claimed.permit.risk_authorization.authorized_direction ||
         MathAbs(pin.requested_volume-claimed.permit.normalized_payload.volume)>m_seed.context.volume_tolerance ||
         pin.request_set_digest!=request_authority.current_complete_set_digest ||
         pin.hard_kill_state_digest!=hard_kill_row.payload_digest) return false;

      SWV5S5_F_ReconciliationBinding binding; ZeroMemory(binding); SWV5S5_F_InitVersion(binding.contract_version);
      binding.profile=profile; binding.request_identity=claimed.permit.request_identity;
      binding.submission_state=claimed.state; binding.pending_request_state=requests[exact].state;
      binding.pending_request_phase=requests[exact].lifecycle_phase; binding.permit_id=claimed.permit.permit_id;
      binding.invocation_claim_id=claimed.invocation_claim_id; binding.admission_snapshot_digest=claimed.admission_snapshot_digest;
      binding.claim_record_digest=claimed.durable_record_digest;
      binding.pinned_correlation_policy_id=pin.correlation_policy_id;
      binding.pinned_correlation_policy_version=pin.correlation_policy_version;
      binding.pinned_correlation_policy_digest=pin.correlation_policy_digest;
      binding.pinned_negative_policy_id=pin.negative_policy_id;
      binding.pinned_negative_policy_version=pin.negative_policy_version;
      binding.pinned_negative_policy_digest=pin.negative_policy_digest;
      binding.pinned_capability_proof_id=pin.capability_proof_id;
      binding.pinned_capability_proof_version=pin.capability_proof_version;
      binding.pinned_capability_proof_digest=pin.capability_proof_digest;
      binding.claimed_at=claimed.claimed_at; binding.claim_clock_sequence=claimed.claim_clock_sequence;
      binding.claim_ownership_fence=claimed.claim_ownership_lease.fence;
      binding.current_reconciliation_lease=current_lease; binding.expected_store_revision=current_lease.store_revision;
      binding.expected_reconciliation_revision=reconciliation_row.logical_revision;
      binding.expected_broker_query_high_watermark=pin.expected_broker_query_high_watermark;
      binding.expected_execution_query_high_watermark=pin.expected_execution_query_high_watermark;
      binding.persisted_reconciliation_vector_digest=reconciliation_row.payload_digest;
      binding.checkpoint_digest=checkpoint_digest; binding.request_set_digest=request_authority.current_complete_set_digest;
      binding.execution_pending_summary_digest=execution_row.payload_digest;
      binding.ordered_request_evidence_digest=ordered_request_digest; binding.hard_kill_state_digest=hard_kill_row.payload_digest;
      binding.symbol_specification_sequence=pin.symbol_specification_sequence;
      binding.expected_basket_version=pin.expected_basket_version; binding.direction=pin.direction;
      binding.requested_volume=pin.requested_volume; binding.persisted_confirmed_volume=0.0;
      binding.persisted_residual_volume=pin.requested_volume; binding.persisted_terminal_evidence_digest="";
      if(!SWV5S5_F_IsBindingValid(m_seed.context,binding) || !m_evidence_store.BindAuthoritativeOperation(m_seed.context,binding))
         return false;

      SWV5S5_F_AdapterSyncResult sync_result; bool sync_found=false;
      if(!m_evidence_store.LoadSubmissionResult(binding,sync_result,sync_found) || !sync_found) return false;
      SWV5S5_F_ExecutionPendingSnapshot execution_snapshot;
      if(!execution_query.ObservePendingRequest(binding,execution_snapshot)) return false;
      evidence.execution_observation_complete=execution_snapshot.operation_success && execution_snapshot.enumeration_complete &&
         execution_snapshot.row_read_failures==0;

      SWV5S5_F_BrokerQuerySnapshot broker_snapshot;
      if(!m_broker_recovery.Query(binding,governance.capability_proof,claimed.claimed_at,
                                   m_seed.context.clock_time,*m_evidence_store,broker_snapshot)) return false;
      evidence.broker_observation_complete=broker_snapshot.positions_enumeration_complete &&
         broker_snapshot.orders_enumeration_complete && broker_snapshot.history_orders_enumeration_complete &&
         broker_snapshot.history_deals_enumeration_complete && broker_snapshot.callback_transactions_enumeration_complete &&
         broker_snapshot.row_read_failures==0;
      bool side_effect_shape=false; SWV5S5_F_TargetedPositiveEvidence positive;
      if(!SWV5S5_F_AdapterBuildPositiveEvidence(m_seed.context,binding,governance.correlation_policy,
         governance.capability_proof,sync_result,broker_snapshot,side_effect_shape,positive))
      {
         evidence.unresolved_no_positive=true;
         evidence.reason_code="NEGATIVE_AUTHORITY_NOT_PROVEN_FOR_MVP_DEMO";
         return false;
      }

      SWV5S5_F_ReconciliationInput candidate; ZeroMemory(candidate); SWV5S5_F_InitVersion(candidate.contract_version);
      candidate.prior_state=SWV5S5_F_SUBMISSION_UNRESOLVED;
      candidate.observation_kind=SWV5S5_F_ACCEPTED_SUBMISSION; candidate.binding=binding;
      candidate.correlation_policy=governance.correlation_policy; candidate.capability_proof=governance.capability_proof;
      candidate.after_restart_or_takeover=true; candidate.positive_evidence_present=true;
      candidate.positive_evidence=positive; candidate.negative_evidence_present=false;
      SWV5S5_F_ReconciliationPublication publication; ZeroMemory(publication); SWV5S5_F_InitVersion(publication.contract_version);
      publication.binding=binding; publication.current_publication_lease=current_lease;
      publication.expected_store_revision=current_lease.store_revision;
      publication.expected_reconciliation_revision=reconciliation_row.logical_revision;
      publication.proposed_reconciliation_revision=reconciliation_row.logical_revision+1;
      SWV5S5_MvpReconciliationPublicationAuthority publication_authority;
      SWV5S5_MvpRecoveryHost recovery_host; SWV5S5_MvpRecoveryResult recovery_result;
      if(!publication_authority.Configure(m_path,m_namespace_digest) ||
         !recovery_host.EvaluateAndPublish(m_seed.context,reloaded,candidate,publication,
                                           publication_authority,recovery_result)) return false;
      evidence.reconciliation_evaluated=recovery_result.evaluated;
      evidence.reconciliation_published=recovery_result.published;

      SWV5S5_MvpSubmissionTerminalAuthority terminal_authority;
      SWV5S5_SubmissionAuthorityRecord terminal_record; SWV5S5_MvpAuthorityRow committed_record;
      if(!terminal_authority.Configure(m_path,m_namespace_digest) ||
         !terminal_authority.TryFinalizeFromPersistedReconciliation(publication,claimed,terminal_record,committed_record))
         return false;
      evidence.exact_record_terminalized=true;
      SWV5S5_SubmissionAuthorityRecord readback; bool terminal_found=false;
      if(!SWV5S5_MvpLoadSubmissionAuthority(store,reloaded.logical_correlation_id,reloaded.attempt_id,
                                             readback,terminal_found) || !terminal_found ||
         readback.durable_record_digest!=terminal_record.durable_record_digest ||
         readback.state!=terminal_record.state) return false;
      evidence.terminal_readback_verified=true; evidence.reason_code="D6_POSITIVE_RECOVERY_TERMINALIZED";
      return recovery_result.submission_calls==0 && !recovery_result.claim_grant_reconstructed;
   }
   virtual bool ObserveCallbackOnly(const MqlTradeTransaction &transaction,const MqlTradeRequest &request,
                                    const MqlTradeResult &result)
   {
      if(!m_configured || m_evidence_store==NULL || m_broker_recovery==NULL) return false;
      ulong sequence=0;
      return m_evidence_store.NextCallbackSequence(sequence) &&
         m_broker_recovery.CaptureCallback(m_seed.context,sequence,transaction,request,result,*m_evidence_store);
   }
   virtual bool BuildAdapterCommand(SWV5S5_F_AdapterSubmissionCommand &command,
                                    ISWV5S5FBrokerEvidenceStore* &evidence_store)
   {
      ZeroMemory(command); evidence_store=NULL; if(!m_claimed || !m_pin_durable || m_evidence_store==NULL) return false;
      SWV5S5_F_InitVersion(command.contract_version); command.prepared_claim=m_claim_transition;
      command.authoritative_claim=m_claim_result;
      if(!BuildExpectedProfile(command.expected_profile) || command.expected_profile.profile_digest!=m_pin.broker_profile_digest) return false;
      command.observed_environment=m_seed.adapter_environment;
      command.direction=m_ingress.decision.direction; command.volume=m_normalized.volume;
      command.price=m_normalized.price; command.stop_price=m_normalized.stop_price;
      command.limit_price=m_normalized.limit_price; command.filling_mode=m_seed.filling_mode;
      command.comment_metadata=m_seed.comment_metadata;
      ENUM_ORDER_TYPE_FILLING exact_filling;
      if(!SWV5S5_F_AdapterResolveFilling(command.filling_mode,
         command.observed_environment.symbol_filling_mask,exact_filling)) return false;
      SWV5S5_F_AdapterWireRequest wire; ZeroMemory(wire); wire.action=(int)TRADE_ACTION_DEAL;
      wire.magic=SWV5_RUNTIME_STRATEGY_MAGIC; wire.symbol=command.expected_profile.symbol;
      wire.volume=command.volume; wire.price=command.price; wire.stop_loss_price=command.stop_price;
      wire.take_profit_price=command.limit_price; wire.order_type=(command.direction>0 ? (int)ORDER_TYPE_BUY : (int)ORDER_TYPE_SELL);
      wire.filling_type=(int)exact_filling;
      wire.time_type=(int)ORDER_TIME_GTC; wire.comment=command.comment_metadata;
      if(!SWV5S5_F_DeriveAdapterWirePayloadDigest(wire,command.wire_payload_digest) ||
         !SWV5S5_F_DeriveAdapterSubmissionDigest(command,command.submission_digest)) return false;
      string reason;
      if(SWV5S5_F_AdapterValidatePreflight(command,reason)!=SWV5S5_F_ADAPTER_PREFLIGHT_READY_CURRENT_CLAIM ||
         !BindDurableOperationBeforeAdapter()) return false;
      evidence_store=m_evidence_store; return true;
   }
};

#endif
