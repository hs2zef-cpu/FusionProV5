#ifndef SW_V5_S5_MVP_REQUEST_MATERIALIZATION_AUTHORITIES_MQH
#define SW_V5_S5_MVP_REQUEST_MATERIALIZATION_AUTHORITIES_MQH

// CONTROLLED DEMO MVP deterministic Blueprint/progression and physical-owner adapters.
// No broker access. Frozen Phase C contracts and coordinator remain unchanged.

#include "SW_V5_S5_MvpIngressRequestAuthorities.mqh"
#include "../Coordinator/SW_V5_S5_DeterministicCoordinator.mqh"

bool SWV5S5_MvpDeriveNormalizationAuthority(const SWV5_NormalizedUnits &normalized,
                                            string &normalization_identity,
                                            string &unit_authority_id,
                                            ulong &unit_authority_revision,
                                            string &unit_authority_digest)
{
   string body,f;
   if(!SWV5S5_CanonicalNormalizedPayload("normalized",normalized,body) ||
      !SWV5S5_DomainDigest("SWV5-S5-MVP-NORMALIZATION-IDENTITY-V1",body,normalization_identity) ||
      !SWV5S5_CanonicalString("normalization_identity",normalization_identity,f) ||
      !SWV5S5_DomainDigest("SWV5-S5-MVP-UNIT-AUTHORITY-ID-V1",f,unit_authority_id)) return false;
   unit_authority_revision=normalized.specification_sequence;
   string revision;
   if(unit_authority_revision==0 || !SWV5S5_CanonicalUInt("unit_authority_revision",unit_authority_revision,revision)) return false;
   return SWV5S5_DomainDigest("SWV5-S5-MVP-UNIT-AUTHORITY-DIGEST-V1",body+f+revision,unit_authority_digest);
}

class SWV5S5_MvpBlueprintAuthority : public ISWV5S5CoordinatorBlueprintAuthority
{
public:
   virtual bool BuildInitial(const SWV5S5_CoordinatorMaterializationInput &materialization,
                             const SWV5S5_RequestBinding &binding,
                             SWV5S5_InitialRequestBlueprint &blueprint)
   {
      ZeroMemory(blueprint); SWV5S5_InitContractVersion(blueprint.contract_version);
      blueprint.binding=binding;
      SWV5S5_MvpInitProductionVersion(blueprint.pending_request.contract_version);
      SWV5S5_MvpInitProductionVersion(blueprint.pending_request.intent.contract_version);
      blueprint.pending_request.intent.persistence_namespace=binding.persistence_namespace;
      blueprint.pending_request.intent.ownership_fence=materialization.normalized_payload.ownership_fence;
      SWV5S5_MvpInitProductionVersion(blueprint.pending_request.intent.request_identity.contract_version);
      blueprint.pending_request.intent.request_identity.request_id.correlation_id=binding.logical_correlation_id;
      blueprint.pending_request.intent.request_identity.request_id.attempt_id=binding.attempt_id;
      blueprint.pending_request.intent.request_identity.request_id.parent_attempt_id="";
      blueprint.pending_request.intent.request_identity.request_id.monotonic_sequence=binding.logical_request_sequence;
      blueprint.pending_request.intent.request_identity.request_id.created_at=binding.accepted_at;
      blueprint.pending_request.intent.request_identity.idempotency_key=binding.idempotency_key;
      blueprint.pending_request.intent.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
      blueprint.pending_request.intent.intent_type=SWV5_INTENT_OPEN;
      blueprint.pending_request.intent.direction=materialization.accepted_ingress.decision.direction;
      blueprint.pending_request.intent.normalized_volume=materialization.normalized_payload.volume;
      blueprint.pending_request.intent.normalized_price=materialization.normalized_payload.price;
      blueprint.pending_request.intent.normalized_stop_price=materialization.normalized_payload.stop_price;
      blueprint.pending_request.intent.normalized_limit_price=materialization.normalized_payload.limit_price;
      blueprint.pending_request.intent.symbol_specification_sequence=materialization.normalized_payload.specification_sequence;
      blueprint.pending_request.intent.expected_basket_version=materialization.risk_authorization.basket_state_version;
      blueprint.pending_request.intent.risk_authorization_id=materialization.risk_authorization.authorization_id;
      blueprint.pending_request.intent.authorization_expires_at=materialization.risk_authorization.expires_at;
      blueprint.pending_request.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
      blueprint.pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_INTENT;
      blueprint.pending_request.state=SWV5_REQUEST_CREATED;
      blueprint.pending_request.submission_attempt_count=0;
      blueprint.pending_request.cumulative_confirmed_volume=0.0;
      blueprint.pending_request.residual_requested_volume=materialization.normalized_payload.volume;
      blueprint.pending_request.retry_disposition=SWV5_RETRY_FORBIDDEN;
      blueprint.pending_request.authorization_identity=materialization.risk_authorization.authorization_id;
      blueprint.pending_request.normalization_identity=materialization.normalization_identity;
      blueprint.pending_request.last_changed_at=binding.accepted_at;
      // ZeroMemory produces NULL strings. The frozen initial-evidence invariant
      // requires explicit empty strings for the canonical CREATED-state shape.
      blueprint.pending_request.latest_retcode.correlation.broker_identity.broker_event_id="";
      blueprint.pending_request.latest_retcode.broker_comment="";
      blueprint.pending_request.latest_retcode_classification.mapping_policy_id="";
      blueprint.pending_request.latest_retcode_classification.decision.reason_code="";
      blueprint.pending_request.latest_retcode_classification.decision.reason_text="";
      blueprint.pending_request.latest_authoritative_confirmation.correlation.broker_identity.broker_event_id="";
      blueprint.pending_request.accepted_event_identities.canonical_event_index="";
      blueprint.pending_request.accepted_event_identities.canonical_fingerprint_index="";
      blueprint.pending_request.accepted_event_identities.identity_set_digest="";
      return SWV5S5_DeriveInitialBlueprintDigest(blueprint,blueprint.blueprint_digest);
   }
};

class SWV5S5_MvpRequestProgressionAuthority : public ISWV5S5CoordinatorRequestProgressionAuthority
{
private:
   datetime m_changed_at;
public:
   SWV5S5_MvpRequestProgressionAuthority(void) { m_changed_at=0; }
   void SetChangedAt(const datetime changed_at) { m_changed_at=changed_at; }
   virtual bool ProgressToSubmission(const SWV5_PendingRequest &created,SWV5_PendingRequest &progressed)
   {
      if(m_changed_at<=0 || created.state!=SWV5_REQUEST_CREATED ||
         created.lifecycle_phase!=SWV5_EXECUTION_PHASE_INTENT || m_changed_at<created.last_changed_at) return false;
      progressed=created; progressed.state=SWV5_REQUEST_SUBMISSION_PENDING;
      progressed.lifecycle_phase=SWV5_EXECUTION_PHASE_SUBMISSION; progressed.last_changed_at=m_changed_at;
      return true;
   }
};

class SWV5S5_MvpExecutionLifecycleAuthority : public ISWV5ExecutionContract
{
public:
   virtual string ContractName(void) { return "ISWV5ExecutionContract/FUSION-V5-DEMO-MVP-V1"; }
   virtual bool ValidateIntent(const SWV5_ContractValidationContext &context,const SWV5_ExecutionIntent &intent,
                               SWV5_ContractDecision &decision)
   {
      ZeroMemory(decision); decision.contract_version=context.expected_version;
      const bool allowed=SWV5S5_IsV5Version(intent.contract_version) && intent.intent_type==SWV5_INTENT_OPEN &&
         (intent.direction==1 || intent.direction==-1) && intent.normalized_volume>0.0 &&
         intent.normalized_price>0.0 && intent.normalized_stop_price>0.0 &&
         intent.authorization_expires_at>context.clock_time;
      decision.disposition=allowed ? SWV5_DISPOSITION_ALLOW : SWV5_DISPOSITION_DENY;
      decision.reason_code=allowed ? "MVP_INTENT_VALID" : "MVP_INTENT_DENIED";
      decision.evaluation_sequence=context.evaluation_sequence; decision.evaluated_at=context.clock_time;
      return allowed;
   }
   virtual bool ValidatePhaseTransition(const SWV5_ContractValidationContext &context,
                                        const SWV5_ExecutionLifecyclePhase current_phase,
                                        const SWV5_ExecutionLifecyclePhase proposed_phase,
                                        SWV5_ContractDecision &decision)
   {
      ZeroMemory(decision); decision.contract_version=context.expected_version;
      const bool allowed=current_phase==SWV5_EXECUTION_PHASE_INTENT && proposed_phase==SWV5_EXECUTION_PHASE_SUBMISSION;
      decision.disposition=allowed ? SWV5_DISPOSITION_ALLOW : SWV5_DISPOSITION_DENY;
      decision.reason_code=allowed ? "MVP_PHASE_TRANSITION_ALLOWED" : "MVP_PHASE_TRANSITION_DENIED";
      decision.evaluation_sequence=context.evaluation_sequence; decision.evaluated_at=context.clock_time;
      return allowed;
   }
   virtual bool ClassifyResultRetcode(const SWV5_ContractValidationContext &context,
      const SWV5_ResultRetcodeEvidence &evidence,SWV5_ResultRetcodeClassification &classification)
   { ZeroMemory(classification); return false; }
   virtual bool AcceptTransactionEvidence(const SWV5_ContractValidationContext &context,
      const SWV5_PendingRequest &pending,const SWV5_TransactionEvidence &evidence,SWV5_ExecutionConfirmation &confirmation)
   { ZeroMemory(confirmation); return false; }
   virtual bool EvaluateRetry(const SWV5_ContractValidationContext &context,const SWV5_PendingRequest &pending,
      const SWV5_RetryPolicy &policy,const SWV5_RetryRiskFreshnessEvidence &risk_evidence,
      const SWV5_RetryNormalizationFreshnessEvidence &normalization_evidence,SWV5_ContractDecision &decision)
   { ZeroMemory(decision); decision.disposition=SWV5_DISPOSITION_DENY; return false; }
};

class SWV5S5_MvpCoordinatorLedgerAdapter : public ISWV5S5CoordinatorLedgerAuthority
{
private:
   SWV5S5_MvpIngressLedgerAuthority m_authority;
   SWV5_ContractValidationContext m_context;
   bool m_context_bound;
public:
   SWV5S5_MvpCoordinatorLedgerAdapter(void) { ZeroMemory(m_context); m_context_bound=false; }
   bool Configure(const string path,const string namespace_digest) { return m_authority.Configure(path,namespace_digest); }
   bool Initialize(const SWV5_PersistenceNamespace &scope,const SWV5_OwnershipFence &fence,
      const SWV5S5_ProducerTrustRecord &trust,const SWV5_ContractValidationContext &context)
   {
      m_context=context; m_context_bound=SWV5S5_IsValidationContextUsable(context);
      return m_context_bound && m_authority.Initialize(scope,fence,trust,context.clock_time);
   }
   bool TransitionBound(const string ingress_identity,const SWV5_ExecutionRequestIdentity &identity,
      const datetime now,SWV5S5_IngressLedgerRecord &record) { return m_authority.TransitionBound(ingress_identity,identity,now,record); }
   virtual bool ReadSnapshot(const string event_id,const ulong event_ordinal,SWV5S5_IngressLedgerHeader &header,
      SWV5S5_IngressLedgerIndexEntry &entries[],SWV5S5_IngressLedgerRecord &records[])
   { return event_id!="" && event_ordinal>0 && m_authority.ReadSnapshot(header,entries,records); }
   virtual bool TryCommitAcceptance(const SWV5S5_IngressLedgerHeader &expected_header,
      const SWV5S5_IngressLedgerIndexEntry &expected_entries[],const SWV5S5_IngressLedgerRecord &expected_records[],
      const SWV5S5_IngressLedgerProposal &proposal,const string event_id,const ulong event_ordinal,
      SWV5S5_CoordinatorLedgerOperationResult &result)
   {
      ZeroMemory(result); result.event_id=event_id; result.event_ordinal=event_ordinal;
      result.proposal_digest=proposal.proposal_digest;
      if(!m_context_bound || event_id=="" || event_ordinal==0 ||
         !m_authority.TryCommitAcceptance(expected_header,expected_entries,expected_records,
                                          proposal,result.authoritative_result)) return false;
      result.authoritative_result.evaluation_sequence=m_context.evaluation_sequence;
      result.authoritative_result.evaluated_at=m_context.clock_time;
      return true;
   }
};

class SWV5S5_MvpCoordinatorSequenceAdapter : public ISWV5S5CoordinatorRequestSequenceAuthority
{
private:
   SWV5S5_MvpRequestSequenceAuthority m_authority;
public:
   bool Configure(const string path,const string namespace_digest) { return m_authority.Configure(path,namespace_digest); }
   bool Initialize(const SWV5_PersistenceNamespace &scope,const SWV5_OwnershipFence &fence,const datetime now)
   { return m_authority.Initialize(scope,fence,now); }
   virtual bool ReadState(const string event_id,const ulong event_ordinal,SWV5S5_RequestSequenceAuthority &authority,
      SWV5S5_RequestSequenceIndexEntry &entries[])
   { return event_id!="" && event_ordinal>0 && m_authority.ReadState(authority,entries); }
   virtual bool TryReserveRequestSequence(const SWV5S5_RequestSequenceAuthority &expected,
      const SWV5S5_RequestSequenceIndexEntry &expected_entries[],const SWV5S5_RequestSequenceReservation &proposal,
      const string event_id,const ulong event_ordinal,SWV5S5_CoordinatorSequenceOperationResult &result)
   {
      ZeroMemory(result); result.event_id=event_id; result.event_ordinal=event_ordinal;
      result.reservation_digest=proposal.reservation_digest;
      return event_id!="" && event_ordinal>0 &&
         m_authority.TryReserveRequestSequence(expected,expected_entries,proposal,result.authoritative_result);
   }
};

#endif
