#ifndef SW_V5_S5_MVP_CONTROLLED_DEMO_AUTHORITY_PORT_MQH
#define SW_V5_S5_MVP_CONTROLLED_DEMO_AUTHORITY_PORT_MQH

// CONTROLLED DEMO MVP concrete authority-provider binding.
// No OrderSend, retry, signal synthesis, or broker mutation exists in this file.

#include "SW_V5_S5_MvpControlledDemoRunner.mqh"
#include "SW_V5_S5_MvpSignalIngressAdapter.mqh"
#include "../RuntimeAuthority/SW_V5_S5_MvpRequestMaterializationAuthorities.mqh"
#include "../RuntimeAuthority/SW_V5_S5_MvpEvidenceRecoveryAuthorities.mqh"

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

class SWV5S5_MvpControlledDemoAuthorityPort : public ISWV5S5_MvpControlledDemoAuthorityPort
{
private:
   string m_path,m_namespace_digest;
   SWV5S5_MvpControlledDemoAuthoritySeed m_seed;
   ISWV5S5MvpReadOnlyPlatform *m_platform;
   ISWV5S5FBrokerEvidenceStore *m_evidence_store;
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
   string m_last_stage;
   SWV5S5_MvpAccountObservation m_observed_account;
   SWV5S5_MvpRuntimeProfileObservation m_observed_profile;

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

   datetime MinimumExpiry(void) const
   {
      datetime expiry=m_seed.context.clock_time+(datetime)SWV5S5_MVP_RISK_AUTHORIZATION_LIFETIME_SECONDS;
      if(m_seed.current_trust.valid_until<expiry) expiry=m_seed.current_trust.valid_until;
      if(m_seed.current_lease.expires_at<expiry) expiry=m_seed.current_lease.expires_at;
      if(m_symbol.specification.valid_until<expiry) expiry=m_symbol.specification.valid_until;
      return expiry;
   }

   bool PrepareRiskInput(const int direction)
   {
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

public:
   SWV5S5_MvpControlledDemoAuthorityPort(void)
   { m_platform=NULL; m_evidence_store=NULL; m_configured=false; m_bootstrapped=false;
     m_permit_prepared=false; m_permit_committed=false; m_admission_ready=false; m_claimed=false;
     m_store_schema_valid=false; m_genesis_valid=false; m_ownership_current=false; m_trust_current=false;
     m_safety_current=false; m_initial_request_set_empty=false; m_initial_submission_index_empty=false; }

   bool Configure(const string path,const string namespace_digest,
                  const SWV5S5_MvpControlledDemoAuthoritySeed &seed,
                  ISWV5S5MvpReadOnlyPlatform *platform,ISWV5S5FBrokerEvidenceStore *evidence_store)
   {
      m_path=path; m_namespace_digest=namespace_digest; m_seed=seed;
      m_platform=platform; m_evidence_store=evidence_store;
      m_configured=path!="" && namespace_digest!="" && platform!=NULL && evidence_store!=NULL;
      m_last_stage=(m_configured ? "CONFIGURED" : "CONFIGURE_REJECTED");
      return m_configured;
   }

   string LastStage(void) const { return m_last_stage; }

   virtual bool CollectPreflight(const SWV5S5_MvpControlledDemoInvocation &invocation,const int direction,
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
   { m_permit_prepared=m_bootstrapped && BuildPermit(); return m_permit_prepared; }
   virtual bool CommitPermitPhysical(void)
   {
      if(!m_permit_prepared || !m_permit_authority.Configure(m_path,m_namespace_digest) ||
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
      if(!m_permit_committed) return false;
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
      return m_admission_ready;
   }
   virtual bool ClaimPhysicalNow(bool &claim_granted_now)
   {
      claim_granted_now=false; if(!m_admission_ready) return false;
      ZeroMemory(m_claim_command); SWV5S5_InitContractVersion(m_claim_command.contract_version);
      m_claim_command.claim_policy_id=SWV5S5_POLICY_ID; m_claim_command.claim_policy_version=SWV5S5_SCHEMA_VERSION;
      m_claim_command.expected_authority_record=m_permit_result.proposed_record;
      m_claim_command.expected_authority_revision=m_permit_result.proposed_record.authority_revision;
      m_claim_command.expected_authority_digest=m_permit_result.proposed_record.durable_record_digest;
      m_claim_command.admission_proof=m_admission_proof; m_claim_command.current_ownership_lease=m_seed.current_lease;
      m_claim_command.claim_clock=m_admission_proof.snapshot.claim_clock;
      SWV5S5_MvpRiskContract risk;
      if(!SWV5S5_DeriveClaimId(m_claim_command,m_claim_command.claim_id) ||
         !SWV5S5_DeriveClaimCommandDigest(m_claim_command,m_claim_command.command_digest) ||
         !SWV5S5_PrepareInvocationClaimTransition(m_seed.context,risk,m_claim_command,m_claim_transition) ||
         !m_claim_authority.Configure(m_path,m_namespace_digest) || !m_claim_authority.StagePrepared(m_claim_transition) ||
         !m_claim_authority.TryClaimInvocation(m_claim_command,m_claim_result)) return false;
      claim_granted_now=m_claim_result.claim_granted_now; m_claimed=claim_granted_now; return m_claimed;
   }
   virtual bool ReloadAndReconcileD6(SWV5S5_MvpControlledDemoRecoveryEvidence &evidence)
   { ZeroMemory(evidence); return false; }
   virtual bool ObserveCallbackOnly(const MqlTradeTransaction &transaction,const MqlTradeRequest &request,
                                    const MqlTradeResult &result)
   { return false; }
   virtual bool BuildAdapterCommand(SWV5S5_F_AdapterSubmissionCommand &command,
                                    ISWV5S5FBrokerEvidenceStore* &evidence_store)
   {
      ZeroMemory(command); evidence_store=NULL; if(!m_claimed || m_evidence_store==NULL) return false;
      SWV5S5_F_InitVersion(command.contract_version); command.prepared_claim=m_claim_transition;
      command.authoritative_claim=m_claim_result; ZeroMemory(command.expected_profile);
      SWV5S5_F_InitVersion(command.expected_profile.contract_version);
      command.expected_profile.persistence_namespace=m_binding.persistence_namespace;
      command.expected_profile.account_namespace=m_risk_input.account_namespace;
      command.expected_profile.broker_identity=m_seed.adapter_environment.broker_identity;
      command.expected_profile.server=m_seed.adapter_environment.server;
      command.expected_profile.account_login=m_seed.adapter_environment.account_login;
      command.expected_profile.symbol=m_seed.adapter_environment.symbol;
      command.expected_profile.terminal_build=m_seed.adapter_environment.terminal_build;
      command.expected_profile.mql_build=m_seed.adapter_environment.mql_build;
      command.expected_profile.profile_id=SWV5S5_F_ADAPTER_PROFILE_ID;
      if(!SWV5S5_F_DeriveProfileDigest(command.expected_profile,command.expected_profile.profile_digest) ||
         !SWV5S5_F_IsProfileValid(command.expected_profile) ||
         !SWV5S5_F_AdapterEnvironmentMatchesProfile(command.expected_profile,m_seed.adapter_environment)) return false;
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
      if(SWV5S5_F_AdapterValidatePreflight(command,reason)!=SWV5S5_F_ADAPTER_PREFLIGHT_READY_CURRENT_CLAIM) return false;
      evidence_store=m_evidence_store; return true;
   }
};

#endif
