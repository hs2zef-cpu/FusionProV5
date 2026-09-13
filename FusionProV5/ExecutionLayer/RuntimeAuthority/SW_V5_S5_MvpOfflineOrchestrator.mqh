#ifndef SW_V5_S5_MVP_OFFLINE_ORCHESTRATOR_MQH
#define SW_V5_S5_MVP_OFFLINE_ORCHESTRATOR_MQH

// OFFLINE / NON-MUTATING INTEGRATION MODE.
// This host stops at an adapter-ready command. It never owns, references, or
// calls the BrokerPlatformBoundary and therefore cannot invoke OrderSend.

#include "SW_V5_S5_MvpManualProvisioningAuthorities.mqh"

struct SWV5S5_MvpOfflineOrchestrationResult
{
   bool units_valid;
   bool risk_valid;
   bool permit_prepared;
   bool permit_committed;
   bool claim_prepared;
   bool claim_granted_now;
   bool adapter_preflight_ready;
   uint broker_submission_calls;
   string stop_reason;
   SWV5_NormalizedUnits normalized;
   SWV5_RiskAuthorization authorization;
   SWV5S5_PermitPreparationResult permit_result;
   SWV5S5_InvocationClaimTransition claim_transition;
   SWV5S5_InvocationClaimResult claim_result;
   SWV5S5_F_AdapterSubmissionCommand adapter_command;
};

class SWV5S5_MvpOfflineOrchestrator
{
public:
   bool PrepareClaimWithoutBrokerMutation(
      const SWV5_ContractValidationContext &context,
      const SWV5_SymbolUnitSpecification &specification,
      const SWV5_UnitNormalizationRequest &normalization_request,
      const SWV5_RiskEvaluationInput &risk_input,
      const SWV5S5_SubmissionAuthorityIndexEntry &entries[],
      const SWV5S5_PermitPreparationCommand &permit_command,
      const SWV5S5_ProducerTrustRecord &current_trust,
      const SWV5S5_ProducerTrustAnchor &trust_anchor,
      const SWV5S5_ProducerTrustScope &trust_scope,
      const SWV5S5_IngressEnvelope &accepted_ingress,
      SWV5S5_InvocationClaimCommand &claim_command,
      SWV5S5_F_AdapterSubmissionCommand &adapter_template,
      SWV5S5_MvpUnitSystemContract &unit_contract,
      SWV5S5_MvpRiskContract &risk_contract,
      SWV5S5_MvpSubmissionPermitAuthority &permit_authority,
      SWV5S5_MvpInvocationClaimAuthority &claim_authority,
      SWV5S5_MvpOfflineOrchestrationResult &result)
   {
      ZeroMemory(result); result.broker_submission_calls=0;
      SWV5_UnitValidationResult unit_validation; SWV5_ContractDecision risk_decision;
      if(!unit_contract.Normalize(context,specification,normalization_request,result.normalized,unit_validation))
      { result.stop_reason="UNIT_NORMALIZATION_DENIED"; return false; }
      result.units_valid=true;
      string expected_payload,actual_payload;
      if(!SWV5S5_CanonicalNormalizedPayload("normalized",result.normalized,actual_payload) ||
         !SWV5S5_CanonicalNormalizedPayload("normalized",permit_command.proposed_permit.normalized_payload,expected_payload) ||
         actual_payload!=expected_payload ||
         !risk_contract.ValidateAuthorization(context,permit_command.proposed_permit.risk_authorization,
                                              risk_input,risk_decision))
      { result.stop_reason="RISK_OR_NORMALIZED_BINDING_DENIED"; return false; }
      result.risk_valid=true; result.authorization=permit_command.proposed_permit.risk_authorization;
      if(!SWV5S5_MvpPreparePermitCommit(context,entries,permit_command,current_trust,trust_anchor,
         trust_scope,accepted_ingress,result.permit_result))
      { result.stop_reason="PERMIT_PREPARATION_DENIED"; return false; }
      result.permit_prepared=true;
      if(!permit_authority.StagePrepared(result.permit_result) ||
         !permit_authority.TryCommitPermit(permit_command,entries,result.permit_result))
      { result.stop_reason="PERMIT_PHYSICAL_COMMIT_DENIED"; return false; }
      result.permit_committed=true;
      claim_command.expected_authority_record=result.permit_result.proposed_record;
      claim_command.expected_authority_revision=result.permit_result.proposed_record.authority_revision;
      claim_command.expected_authority_digest=result.permit_result.proposed_record.durable_record_digest;
      if(!SWV5S5_DeriveClaimId(claim_command,claim_command.claim_id) ||
         !SWV5S5_DeriveClaimCommandDigest(claim_command,claim_command.command_digest) ||
         !SWV5S5_PrepareInvocationClaimTransition(context,risk_contract,claim_command,result.claim_transition))
      { result.stop_reason="CLAIM_PREPARATION_DENIED"; return false; }
      result.claim_prepared=true;
      if(!claim_authority.StagePrepared(result.claim_transition) ||
         !claim_authority.TryClaimInvocation(claim_command,result.claim_result) ||
         !result.claim_result.claim_granted_now)
      { result.stop_reason="CLAIM_PHYSICAL_COMMIT_DENIED"; return false; }
      result.claim_granted_now=true;
      result.adapter_command=adapter_template;
      result.adapter_command.prepared_claim=result.claim_transition;
      result.adapter_command.authoritative_claim=result.claim_result;
      if(!SWV5S5_F_DeriveAdapterSubmissionDigest(result.adapter_command,
                                                  result.adapter_command.submission_digest))
      { result.stop_reason="ADAPTER_COMMAND_DIGEST_FAILED"; return false; }
      string preflight_reason;
      result.adapter_preflight_ready=(SWV5S5_F_AdapterValidatePreflight(result.adapter_command,preflight_reason)==
                                      SWV5S5_F_ADAPTER_PREFLIGHT_READY_CURRENT_CLAIM);
      result.stop_reason=(result.adapter_preflight_ready ? "OFFLINE_STOP_BEFORE_PLATFORM_MUTATION" : preflight_reason);
      // Absolute invariant: this integration host has no submission dependency.
      return result.adapter_preflight_ready && result.broker_submission_calls==0;
   }
};

#endif // SW_V5_S5_MVP_OFFLINE_ORCHESTRATOR_MQH
