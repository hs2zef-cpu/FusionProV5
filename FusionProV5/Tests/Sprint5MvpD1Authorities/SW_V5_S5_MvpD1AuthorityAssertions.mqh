#ifndef SW_V5_S5_MVP_D1_AUTHORITY_ASSERTIONS_MQH
#define SW_V5_S5_MVP_D1_AUTHORITY_ASSERTIONS_MQH

// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS

#include "../../ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpIngressRequestAuthorities.mqh"
#include "../../ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpPermitClaimAuthorities.mqh"
#include "../ContractVerification/SW_V5_TestFixtures.mqh"
#include "../Sprint5PhaseB/SW_V5_S5_PhaseB_Assertions.mqh"
#include "../ContractVerification/SW_V5_ReferenceValidators.mqh"

struct SWV5S5_MvpD1Collector
{
   uint total;
   uint passed;
   uint failed;
   ulong signature;
};

void SWV5S5_MvpD1Record(SWV5S5_MvpD1Collector &c,const string id,const bool passed)
{
   c.total++; if(passed)c.passed++; else c.failed++;
   const string item=id+":"+(passed ? "PASS" : "FAIL");
   for(int i=0;i<StringLen(item);i++) c.signature=(c.signature^(ulong)StringGetCharacter(item,i))*1099511628211;
   Print("MVP_D1_AUTHORITY_TEST|",id,"|",(passed ? "PASS" : "FAIL"));
}

void SWV5S5_MvpD1MakeContext(SWV5_ContractValidationContext &context)
{
   ZeroMemory(context); SWV5S5_InitContractVersion(context.expected_version);
   context.clock_id="BROKER-SERVER-CLOCK"; context.clock_authority=SWV5_TIME_AUTHORITY_BROKER_SERVER;
   context.clock_time=SWV5_TEST_TIME; context.clock_sequence=100; context.evaluation_sequence=100;
   context.price_tolerance=0.0000001; context.volume_tolerance=0.0000001;
}

void SWV5S5_MvpD1MakeAllowedRisk(const SWV5_ContractValidationContext &context,
                                 SWV5_RiskEvaluationInput &candidate)
{
   SWV5_TestMakeRiskInput(candidate);
   SWV5S5_MvpLoadRiskLimits(candidate.limits);
   candidate.account.observed_at=context.clock_time;
   candidate.exposure.observed_at=context.clock_time;
   candidate.basket.observed_at=context.clock_time;
   candidate.projected.calculated_at=context.clock_time;
   candidate.projected.symbol=SWV5S5_MVP_SYMBOL;
   candidate.projected.projected_volume=0.01;
   candidate.projected.projected_symbol_volume=0.01;
   candidate.projected.projected_aggregate_volume=0.01;
   candidate.projected.projected_notional=35.0;
   candidate.projected.margin_evidence.projected_account_margin=124.0;
   candidate.projected.basket_risk_evidence.resulting_basket_maximum_loss=4.0;
   candidate.projected.projected_maximum_loss=4.0;
   candidate.exposure.live_basket_count=0;
   candidate.basket.lifecycle.cumulative_recovery_attempts=0;
   candidate.intent.normalized_volume=0.01;
   candidate.intent.authorization_expires_at=context.clock_time+5;
   candidate.margin_authority_record.requested_volume=0.01;
   candidate.margin_authority_record.symbol=SWV5S5_MVP_SYMBOL;
   candidate.margin_authority_record.authority_record_digest="";
   SWV5S5_MvpDeriveMarginAuthorityDigest(candidate.margin_authority_record,
                                          candidate.margin_authority_record.authority_record_digest);
   candidate.projected.margin_evidence.authority_record_digest=candidate.margin_authority_record.authority_record_digest;
   candidate.basket_risk_authority_record.symbol=SWV5S5_MVP_SYMBOL;
   candidate.basket_risk_authority_record.resulting_basket_maximum_loss=4.0;
   candidate.basket_risk_authority_record.authority_record_digest="";
   SWV5S5_MvpDeriveBasketRiskAuthorityDigest(candidate.basket_risk_authority_record,
                                              candidate.basket_risk_authority_record.authority_record_digest);
   candidate.projected.basket_risk_evidence.authority_record_digest=candidate.basket_risk_authority_record.authority_record_digest;
   candidate.projected.basket_risk_evidence.resulting_basket_maximum_loss=4.0;
   candidate.hard_kill_state.state=SWV5_HARD_KILL_INACTIVE;
   candidate.intent.risk_authorization_id="";
}

bool SWV5S5_MvpD1PrepareReservation(const SWV5S5_RequestSequenceAuthority &authority,
                                    const SWV5S5_RequestSequenceIndexEntry &entries[],
                                    const string correlation,const string binding_digest,
                                    SWV5S5_RequestSequenceReservation &proposal)
{
   ZeroMemory(proposal); SWV5S5_InitContractVersion(proposal.contract_version);
   proposal.persistence_namespace=authority.persistence_namespace; proposal.ownership_fence=authority.ownership_fence;
   proposal.logical_correlation_id=correlation; proposal.binding_digest=binding_digest;
   proposal.expected_allocator_revision=authority.allocator_revision;
   proposal.expected_authority_digest=authority.authority_digest;
   proposal.observed_high_watermark=authority.request_sequence_high_watermark;
   const int found=SWV5S5_FindSequenceReservation(entries,correlation);
   proposal.proposed_sequence=(found>=0 ? entries[found].reserved_sequence : authority.request_sequence_high_watermark+1);
   proposal.proposed_allocator_revision=(found>=0 ? authority.allocator_revision : authority.allocator_revision+1);
   return SWV5S5_DeriveSequenceReservationDigest(proposal,proposal.reservation_digest);
}

bool SWV5S5_MvpD1PrepareLedgerProposal(const SWV5S5_IngressLedgerHeader &header,
                                       const string ingress_identity,const string payload_digest,
                                       const ulong publication_sequence,const string correlation,
                                       const ulong reservation,const datetime accepted_at,
                                       SWV5S5_IngressLedgerProposal &proposal)
{
   ZeroMemory(proposal); proposal.expected_header=header; proposal.proposed_next_revision=header.revision+1;
   SWV5S5_InitContractVersion(proposal.proposed_record.contract_version);
   proposal.proposed_record.ingress_identity=ingress_identity; proposal.proposed_record.payload_digest=payload_digest;
   proposal.proposed_record.publication_sequence=publication_sequence;
   proposal.proposed_record.lifecycle_state=SWV5S5_ACCEPTED_REQUEST_PENDING;
   proposal.proposed_record.logical_correlation_id=correlation;
   proposal.proposed_record.reserved_request_sequence=reservation;
   proposal.proposed_record.accepted_at=accepted_at; proposal.proposed_record.bound_request_id="";
   proposal.proposed_record.terminal_disposition=""; proposal.proposed_record.record_sequence=header.membership_count+1;
   proposal.proposed_record.record_revision=proposal.proposed_next_revision;
   return SWV5S5_DeriveLedgerRecordDigest(proposal.proposed_record,proposal.proposed_record.record_digest) &&
      SWV5S5_MvpDeriveLedgerProposalDigest(proposal,proposal.proposal_digest);
}

void SWV5S5_RunMvpD1AuthorityAssertions(SWV5S5_MvpD1Collector &c)
{
   ZeroMemory(c); c.signature=1469598103934665603;
   SWV5_ContractValidationContext context; SWV5S5_MvpD1MakeContext(context);
   SWV5_PersistenceNamespace scope; SWV5_TestMakeNamespace(scope);
   SWV5_OwnershipFence fence; SWV5_TestMakeFence(fence);
   scope.ownership_namespace=fence.ownership_namespace;
   const string namespace_digest="d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1";
   const string path="mvp_d1_authorities_v1.sqlite";
   string payload_digest; SWV5S5_SHA256("AUTHENTIC-INGRESS-PAYLOAD",payload_digest);
   string correlation,attempt,idempotency;
   const bool correlation_ok=SWV5S5_DeriveRequestBinding(scope,SWV5S5_REQUEST_BINDING_POLICY_ID,
      SWV5S5_REQUEST_BINDING_POLICY_VERSION,"INGRESS-A",0,correlation,attempt,idempotency);

   SWV5S5_MvpRequestSequenceAuthority sequence;
   const bool sequence_ready=sequence.Configure(path,namespace_digest) && sequence.Initialize(scope,fence,context.clock_time);
   SWV5S5_RequestSequenceAuthority sequence_state; SWV5S5_RequestSequenceIndexEntry sequence_entries[];
   const bool sequence_loaded=sequence_ready && sequence.ReadState(sequence_state,sequence_entries);
   SWV5S5_RequestSequenceReservation reservation_proposal; SWV5S5_RequestSequenceResult reservation_result;
   const bool proposal_ok=sequence_loaded && correlation_ok && SWV5S5_MvpD1PrepareReservation(sequence_state,sequence_entries,
      correlation,payload_digest,reservation_proposal);
   const bool reserved=proposal_ok && sequence.TryReserveRequestSequence(sequence_state,sequence_entries,
      reservation_proposal,reservation_result);
   SWV5S5_MvpD1Record(c,"BOOT-01",reserved && reservation_result.reserved_sequence==1);
   SWV5S5_MvpD1Record(c,"BOOT-02",reservation_proposal.binding_digest==payload_digest);

   SWV5S5_RequestSequenceAuthority after_sequence; SWV5S5_RequestSequenceIndexEntry after_entries[];
   SWV5S5_RequestSequenceReservation replay_proposal; SWV5S5_RequestSequenceResult replay_result;
   const bool replayed=reserved && sequence.ReadState(after_sequence,after_entries) &&
      SWV5S5_MvpD1PrepareReservation(after_sequence,after_entries,correlation,payload_digest,replay_proposal) &&
      sequence.TryReserveRequestSequence(after_sequence,after_entries,replay_proposal,replay_result);
   SWV5S5_MvpD1Record(c,"BOOT-03",replayed && replay_result.disposition==SWV5S5_SEQUENCE_EXISTING_IDEMPOTENT &&
      replay_result.reserved_sequence==reservation_result.reserved_sequence);

   SWV5S5_RequestBinding binding; SWV5_ExecutionRequestIdentity identity;
   const bool binding_ok=SWV5S5_MvpBuildRequestBindingSeed(scope,"INGRESS-A",context.clock_time,
      reservation_result.reserved_sequence,binding,identity);
   SWV5S5_MvpD1Record(c,"BOOT-04",binding_ok && identity.request_id.correlation_id==binding.logical_correlation_id &&
      identity.request_id.attempt_id==binding.attempt_id && identity.request_id.monotonic_sequence==binding.logical_request_sequence &&
      identity.request_id.created_at==binding.accepted_at && identity.idempotency_key==binding.idempotency_key);
   SWV5S5_MvpD1Record(c,"BOOT-05",binding_ok && identity.request_id.monotonic_sequence>0);

   SWV5_RiskEvaluationInput risk; SWV5S5_MvpD1MakeAllowedRisk(context,risk);
   risk.intent.request_identity=identity; risk.margin_authority_record.request_identity=identity;
   risk.basket_risk_authority_record.request_identity=identity;
   risk.margin_authority_record.authority_record_digest="";
   SWV5S5_MvpDeriveMarginAuthorityDigest(risk.margin_authority_record,risk.margin_authority_record.authority_record_digest);
   risk.basket_risk_authority_record.authority_record_digest="";
   SWV5S5_MvpDeriveBasketRiskAuthorityDigest(risk.basket_risk_authority_record,risk.basket_risk_authority_record.authority_record_digest);
   string risk_id,risk_id_again;
   const bool risk_id_ok=SWV5S5_MvpDeriveRiskAuthorizationId(risk,risk_id) && SWV5S5_MvpDeriveRiskAuthorizationId(risk,risk_id_again);
   SWV5S5_MvpD1Record(c,"BOOT-06",risk.margin_authority_record.request_identity.request_id.attempt_id==identity.request_id.attempt_id);
   SWV5S5_MvpD1Record(c,"BOOT-07",risk.basket_risk_authority_record.request_identity.request_id.attempt_id==identity.request_id.attempt_id);
   SWV5S5_MvpD1Record(c,"BOOT-08",risk_id_ok && risk_id==risk_id_again && SWV5S5_IsDigest64Lower(risk_id));
   SWV5_RiskEvaluationInput changed=risk; changed.intent.request_identity.request_id.attempt_id="CHANGED"; string changed_id;
   SWV5S5_MvpD1Record(c,"BOOT-09",SWV5S5_MvpDeriveRiskAuthorizationId(changed,changed_id) && changed_id!=risk_id);
   changed=risk; changed.intent.normalized_volume=0.009; SWV5S5_MvpD1Record(c,"BOOT-10",
      SWV5S5_MvpDeriveRiskAuthorizationId(changed,changed_id) && changed_id!=risk_id);
   changed=risk; changed.margin_authority_record.authority_record_digest="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
   SWV5S5_MvpD1Record(c,"BOOT-11",SWV5S5_MvpDeriveRiskAuthorizationId(changed,changed_id) && changed_id!=risk_id);
   changed=risk; changed.basket_risk_authority_record.authority_record_digest="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
   SWV5S5_MvpD1Record(c,"BOOT-12",SWV5S5_MvpDeriveRiskAuthorizationId(changed,changed_id) && changed_id!=risk_id);
   changed=risk; changed.hard_kill_state.latch_generation++;
   SWV5S5_MvpD1Record(c,"BOOT-13",SWV5S5_MvpDeriveRiskAuthorizationId(changed,changed_id) && changed_id!=risk_id);
   SWV5S5_MvpRiskContract risk_contract; SWV5_RiskAuthorization authorization;
   risk.intent.risk_authorization_id="ARBITRARY";
   SWV5S5_MvpD1Record(c,"BOOT-14",!risk_contract.Evaluate(context,risk,authorization));
   SWV5S5_ProducerTrustRecord denial_trust; ZeroMemory(denial_trust);
   denial_trust.authority_record_id="TRUST-1"; denial_trust.authority_generation=1;
   denial_trust.producer_instance="FUSION-V5-DECISION"; denial_trust.producer_epoch=1;
   SWV5S5_MvpIngressLedgerAuthority denied_ledger;
   const bool denied_ledger_empty=denied_ledger.Configure(path,namespace_digest) &&
      denied_ledger.Initialize(scope,fence,denial_trust,context.clock_time);
   SWV5S5_IngressLedgerHeader denied_header; SWV5S5_IngressLedgerIndexEntry denied_entries[];
   SWV5S5_IngressLedgerRecord denied_records[];
   const bool no_ledger_after_denial=denied_ledger_empty && denied_ledger.ReadSnapshot(denied_header,denied_entries,denied_records) &&
      ArraySize(denied_records)==0;
   SWV5S5_MvpD1Record(c,"BOOT-15",no_ledger_after_denial);
   SWV5S5_MvpRequestSetPublicationAuthority denied_request_set;
   SWV5S5_RequestSetPublicationAuthority denied_request_authority; SWV5_PendingRequest denied_requests[];
   const bool no_request_after_denial=denied_request_set.Configure(path,namespace_digest) &&
      denied_request_set.Initialize(scope,fence,context.clock_time) &&
      denied_request_set.ReadState(denied_request_authority,denied_requests) && ArraySize(denied_requests)==0;
   SWV5S5_MvpD1Record(c,"BOOT-16",no_request_after_denial);
   SWV5S5_MvpSqliteAuthorityStore denied_store; SWV5S5_MvpAuthorityRow denied_row; bool denied_found=false;
   string denied_submission_key; SWV5S5_MvpSubmissionRecordKey(correlation,attempt,denied_submission_key);
   const bool no_permit_or_claim_after_denial=denied_store.Open(path,namespace_digest) &&
      denied_store.ReadRow(SWV5S5_MVP_DOMAIN_SUBMISSION,denied_submission_key,denied_row,denied_found) && !denied_found;
   SWV5S5_MvpD1Record(c,"BOOT-17",no_permit_or_claim_after_denial);
   SWV5S5_MvpD1Record(c,"BOOT-18",replayed && replay_result.reserved_sequence==1);
   SWV5_ContractValidationContext trust_context; SWV5S5_ProducerTrustRecord current_trust;
   SWV5S5_ProducerTrustAnchor trust_anchor; SWV5S5_ProducerTrustScope trust_scope; SWV5S5_IngressEnvelope trusted_ingress;
   SWV5S5_ValidationResult trust_validation;
   SWV5S5_TestContext(trust_context,1000,3);
   SWV5_PersistenceNamespace trust_namespace; SWV5_OwnershipFence trust_fence;
   SWV5S5_TestScope(trust_namespace,trust_fence);
   const bool trust_ingress_ready=SWV5S5_TestIngress(trust_namespace,trusted_ingress);
   ZeroMemory(current_trust); SWV5S5_InitContractVersion(current_trust.contract_version);
   current_trust.authority_record_id="TRUST-A"; current_trust.authority_generation=5;
   current_trust.issuer_identity="TRUST-ISSUER"; current_trust.issuer_policy_id="TRUST-POLICY";
   current_trust.producer_component="DECISION"; current_trust.producer_instance="PRODUCER-A";
   current_trust.producer_epoch=6; current_trust.persistence_namespace=trust_namespace;
   current_trust.symbol="XAUUSD"; current_trust.timeframe=15; current_trust.execution_mode=1;
   current_trust.clock_id="TEST-CLOCK"; current_trust.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   current_trust.status=SWV5S5_TRUST_AUTHORIZED; current_trust.valid_from=900; current_trust.valid_until=1100;
   current_trust.superseding_record_id=""; current_trust.superseding_generation=0;
   ZeroMemory(trust_anchor); trust_anchor.issuer_identity=current_trust.issuer_identity;
   trust_anchor.issuer_policy_id=current_trust.issuer_policy_id; trust_anchor.trust_anchor_id="ANCHOR-A";
   trust_anchor.current_authority_record_id=current_trust.authority_record_id;
   trust_anchor.current_authority_generation=current_trust.authority_generation;
   ZeroMemory(trust_scope); trust_scope.persistence_namespace=trust_namespace;
   trust_scope.producer_component=current_trust.producer_component;
   trust_scope.producer_instance=current_trust.producer_instance; trust_scope.producer_epoch=current_trust.producer_epoch;
   trust_scope.symbol=current_trust.symbol; trust_scope.timeframe=current_trust.timeframe;
   trust_scope.execution_mode=current_trust.execution_mode; trust_scope.publication_clock_id=current_trust.clock_id;
   trust_scope.publication_clock_authority=current_trust.clock_authority;
   trust_scope.ingress_identity=trusted_ingress.ingress_identity;
   string trust_digest_check,trust_ingress_check,trust_payload_check;
   const bool trust_digest_ready=SWV5S5_DeriveProducerTrustDigest(current_trust,current_trust.record_digest) &&
      SWV5S5_DeriveProducerTrustDigest(current_trust,trust_digest_check);
   const bool trust_identity_ready=SWV5S5_DeriveIngressIdentityAndDigest(trusted_ingress,trust_ingress_check,trust_payload_check);
   const bool trust_fixture=trust_ingress_ready && trust_digest_ready && trust_identity_ready &&
      SWV5S5_ValidateProducerTrust(trust_context,current_trust,trust_anchor,trust_scope,trusted_ingress,trust_validation);
   SWV5S5_ProducerTrustRecord revoked_trust=current_trust; revoked_trust.status=SWV5S5_TRUST_REVOKED;
   revoked_trust.superseding_record_id=""; revoked_trust.superseding_generation=0;
   const bool revoked_digest_ready=trust_fixture &&
      SWV5S5_DeriveProducerTrustDigest(revoked_trust,revoked_trust.record_digest);
   const bool revoked_rejected=revoked_digest_ready &&
      !SWV5S5_ValidateProducerTrust(trust_context,revoked_trust,trust_anchor,trust_scope,trusted_ingress,trust_validation);
   SWV5S5_MvpD1Record(c,"BOOT-19",trust_fixture && revoked_digest_ready && revoked_rejected && no_ledger_after_denial);

   SWV5S5_ProducerTrustRecord trust; ZeroMemory(trust); trust.authority_record_id="TRUST-1";
   trust.authority_generation=1; trust.producer_instance="FUSION-V5-DECISION"; trust.producer_epoch=1;
   SWV5S5_MvpIngressLedgerAuthority ledger;
   const bool ledger_ready=ledger.Configure(path,namespace_digest) && ledger.Initialize(scope,fence,trust,context.clock_time);
   SWV5S5_IngressLedgerHeader ledger_header; SWV5S5_IngressLedgerIndexEntry ledger_entries[]; SWV5S5_IngressLedgerRecord ledger_records[];
   SWV5S5_IngressLedgerProposal ledger_proposal; SWV5S5_ValidationResult ledger_result;
   const bool ledger_loaded=ledger_ready && ledger.ReadSnapshot(ledger_header,ledger_entries,ledger_records);
   const bool ledger_prepared=ledger_loaded && SWV5S5_MvpD1PrepareLedgerProposal(ledger_header,"INGRESS-A",payload_digest,1,correlation,1,context.clock_time,ledger_proposal);
   const bool ledger_committed=ledger_prepared && ledger.TryCommitAcceptance(ledger_header,ledger_entries,ledger_records,ledger_proposal,ledger_result);
   SWV5S5_MvpD1Record(c,"BOOT-20",ledger_committed && ledger_result.disposition==SWV5_DISPOSITION_ALLOW &&
      ledger_header.policy_id==SWV5S5_POLICY_ID);

   string bound_id,bound_same; const bool bound_ok=SWV5S5_MvpDeriveBoundRequestId(identity,bound_id) &&
      SWV5S5_MvpDeriveBoundRequestId(identity,bound_same);
   SWV5S5_MvpD1Record(c,"BOUND-01",bound_ok && bound_id==bound_same);
   SWV5S5_MvpD1Record(c,"BOUND-02",bound_ok && SWV5S5_IsDigest64Lower(bound_id));
   SWV5_ExecutionRequestIdentity changed_identity=identity; changed_identity.request_id.attempt_id="ATT-CHANGED";
   SWV5S5_MvpD1Record(c,"BOUND-03",SWV5S5_MvpDeriveBoundRequestId(changed_identity,changed_id) && changed_id!=bound_id);
   changed_identity=identity; changed_identity.request_id.correlation_id="CORR-CHANGED";
   SWV5S5_MvpD1Record(c,"BOUND-04",SWV5S5_MvpDeriveBoundRequestId(changed_identity,changed_id) && changed_id!=bound_id);
   changed_identity=identity; changed_identity.request_id.monotonic_sequence++;
   SWV5S5_MvpD1Record(c,"BOUND-05",SWV5S5_MvpDeriveBoundRequestId(changed_identity,changed_id) && changed_id!=bound_id);
   changed_identity=identity; changed_identity.request_id.created_at++;
   SWV5S5_MvpD1Record(c,"BOUND-06",SWV5S5_MvpDeriveBoundRequestId(changed_identity,changed_id) && changed_id!=bound_id);
   changed_identity=identity; changed_identity.idempotency_key="IDEMP-CHANGED";
   SWV5S5_MvpD1Record(c,"BOUND-07",SWV5S5_MvpDeriveBoundRequestId(changed_identity,changed_id) && changed_id!=bound_id);
   SWV5S5_MvpD1Record(c,"BOUND-08",bound_id!=identity.request_id.attempt_id);
   SWV5S5_MvpD1Record(c,"BOUND-09",bound_id!=identity.request_id.correlation_id);

   SWV5S5_MvpRequestSetPublicationAuthority request_set;
   const bool request_set_ready=request_set.Configure(path,namespace_digest) && request_set.Initialize(scope,fence,context.clock_time);
   SWV5S5_RequestSetPublicationAuthority request_authority; SWV5_PendingRequest current_requests[];
   SWV5_PendingRequest proposed_requests[]; ArrayResize(proposed_requests,1); SWV5_TestMakePending(proposed_requests[0]);
   proposed_requests[0].intent.request_identity=identity; proposed_requests[0].intent.persistence_namespace=scope;
   proposed_requests[0].intent.ownership_fence=fence; proposed_requests[0].last_changed_at=context.clock_time;
   SWV5S5_RequestSetPublicationProposal publication; ZeroMemory(publication); SWV5S5_InitContractVersion(publication.contract_version);
   const bool publication_prepared=request_set_ready && request_set.ReadState(request_authority,current_requests) &&
      (publication.policy_id=SWV5S5_PUBLICATION_POLICY_ID)!="";
   publication.policy_version=SWV5S5_PUBLICATION_POLICY_VERSION; publication.persistence_namespace=scope;
   publication.expected_ownership_fence=fence; publication.expected_takeover_generation=fence.takeover_generation;
   publication.expected_store_revision=request_authority.store_revision;
   publication.expected_request_set_revision=request_authority.current_set_header.request_index_revision;
   publication.expected_request_set_digest=request_authority.current_complete_set_digest;
   publication.expected_record_sequence=request_authority.current_set_header.record_sequence;
   SWV5S5_SHA256("REQUEST-SET-STORE-REVISION-1",publication.proposed_store_revision);
   SWV5S5_MvpInitV5Version(publication.proposed_set_header.contract_version);
   publication.proposed_set_header.request_index_revision="REQUEST-SET-REVISION-1";
   publication.proposed_set_header.record_sequence=1; publication.proposed_set_header.request_count=1;
   SWV5S5_DeriveCompleteRequestSetDigest(proposed_requests,publication.proposed_set_header.request_set_digest);
   publication.proposed_complete_set_digest=publication.proposed_set_header.request_set_digest;
   SWV5S5_DeriveRequestSetProposalDigest(publication,publication.proposal_digest);
   SWV5S5_FencedPublicationResult publication_result;
   const bool published=publication_prepared && request_set.TryPublishRequestSet(publication,proposed_requests,publication_result);
   SWV5_PendingRequest readback;
   const bool exact_readback=published && request_set.FindExactBoundRequest(bound_id,proposed_requests[0],readback);
   SWV5S5_MvpD1Record(c,"BOUND-10",exact_readback);
   SWV5S5_IngressLedgerRecord bound_record;
   const bool transitioned=exact_readback && ledger.TransitionBound("INGRESS-A",identity,context.clock_time,bound_record);
   SWV5S5_MvpD1Record(c,"BOUND-11",transitioned && bound_record.record_sequence==ledger_proposal.proposed_record.record_sequence);
   SWV5S5_MvpD1Record(c,"BOUND-12",transitioned && bound_record.bound_request_id==bound_id);
   SWV5_ExecutionRequestIdentity wrong_identity=identity; wrong_identity.request_id.attempt_id="WRONG";
   SWV5S5_IngressLedgerRecord wrong_bound;
   SWV5S5_MvpD1Record(c,"BOUND-13",!ledger.TransitionBound("INGRESS-A",wrong_identity,context.clock_time,wrong_bound));
   SWV5S5_MvpIngressLedgerAuthority restarted_ledger; SWV5S5_IngressLedgerHeader restarted_header;
   SWV5S5_IngressLedgerIndexEntry restarted_entries[]; SWV5S5_IngressLedgerRecord restarted_records[];
   SWV5S5_MvpRequestSetPublicationAuthority restarted_request_set; SWV5_PendingRequest restarted_request;
   const bool restart_ok=restarted_ledger.Configure(path,namespace_digest) &&
      restarted_ledger.ReadSnapshot(restarted_header,restarted_entries,restarted_records) &&
      restarted_request_set.Configure(path,namespace_digest) &&
      restarted_request_set.FindExactBoundRequest(bound_id,proposed_requests[0],restarted_request);
   SWV5S5_MvpD1Record(c,"BOUND-14",restart_ok && ArraySize(restarted_records)==1 &&
      restarted_records[0].lifecycle_state==SWV5S5_BOUND_TO_REQUEST);
}

#endif
