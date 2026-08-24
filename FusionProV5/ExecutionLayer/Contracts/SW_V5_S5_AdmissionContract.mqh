#ifndef SW_V5_S5_ADMISSION_CONTRACT_MQH
#define SW_V5_S5_ADMISSION_CONTRACT_MQH

// SPRINT 5 PHASE B CANDIDATE CONTRACT
// PURE CONDITIONAL ADMISSION MODEL / P IS INEFFECTIVE UNTIL CLAIM_GRANTED_NOW

#include "SW_V5_S5_InvocationClaimContract.mqh"

struct SWV5S5_ClaimTimeAuthorityInput
{
   SWV5S5_AdmissionProof admission_proof;
   SWV5S5_SubmissionPermit permit;
   SWV5_RiskAuthorization risk_authorization;
   SWV5S5_ProducerTrustRecord producer_trust;
   bool lease_live;
   bool account_observation_fresh;
   bool symbol_specification_fresh;
   bool margin_fresh;
   bool basket_risk_fresh;
   bool clock_nonregressing;
};

struct SWV5S5_ConditionalAdmissionResult
{
   SWV5_ContractVersion contract_version;
   SWV5S5_AdmissionOperationState operation_state;
   bool provisional_p_available;
   bool policy_linearized_at_p;
   bool claim_authorized;
   string reason_code;
};

bool SWV5S5_ValidateClaimTimeAuthorities(const SWV5_ContractValidationContext &context,
                                         const SWV5S5_ClaimTimeAuthorityInput &authority_input,
                                         SWV5S5_ConditionalAdmissionResult &result)
{
   ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
   string proof_digest;
   SWV5S5_AdmissionProof proof=authority_input.admission_proof;
   if(!SWV5S5_DeriveAdmissionProofDigest(proof,proof_digest) ||
      authority_input.admission_proof.proof_digest!=proof_digest)
   { result.operation_state=SWV5S5_ADMISSION_CLAIM_TIME_FAILED; result.reason_code="ADMISSION_PROOF_INVALID"; return false; }
   const SWV5S5_AdmissionAuthorityCollection compared=proof.snapshot.collect_v2;
   if(compared.submission_permit.permit.permit_id!=authority_input.permit.permit_id ||
      compared.submission_permit.permit.permit_digest!=authority_input.permit.permit_digest ||
      compared.risk_authorization.authorization.authorization_id!=authority_input.risk_authorization.authorization_id ||
      compared.producer_trust.record.authority_record_id!=authority_input.producer_trust.authority_record_id ||
      compared.producer_trust.record.authority_generation!=authority_input.producer_trust.authority_generation ||
      compared.producer_trust.record.record_digest!=authority_input.producer_trust.record_digest ||
      proof.snapshot.claim_clock.clock_id!=context.clock_id ||
      proof.snapshot.claim_clock.clock_authority!=context.clock_authority ||
      proof.snapshot.claim_clock.clock_sequence!=context.clock_sequence ||
      proof.snapshot.claim_clock.observed_at!=context.clock_time)
   { result.operation_state=SWV5S5_ADMISSION_CLAIM_TIME_FAILED; result.reason_code="PROOF_CURRENT_AUTHORITY_MISMATCH"; return false; }
   result.provisional_p_available=true;
   if(!SWV5S5_EqualRequestIdentity(authority_input.risk_authorization.request_identity,
                                    authority_input.permit.request_identity) ||
      !SWV5S5_EqualNamespace(authority_input.risk_authorization.persistence_namespace,
                              authority_input.permit.persistence_namespace) ||
      !SWV5S5_EqualFence(authority_input.risk_authorization.ownership_fence,
                          authority_input.permit.ownership_fence) ||
      authority_input.risk_authorization.authorization_id!=authority_input.permit.risk_authorization.authorization_id ||
      authority_input.risk_authorization.disposition!=SWV5_RISK_ALLOW ||
      authority_input.risk_authorization.expires_at!=authority_input.permit.risk_authorization.expires_at ||
      authority_input.risk_authorization.account_mode!=authority_input.permit.account_mode ||
      authority_input.risk_authorization.basket_state_version!=authority_input.permit.basket_state_version ||
      authority_input.risk_authorization.symbol_specification_sequence!=authority_input.permit.symbol_specification_sequence ||
      authority_input.risk_authorization.hard_kill_latch_id!=authority_input.permit.hard_kill_latch_id ||
      authority_input.risk_authorization.hard_kill_latch_generation!=authority_input.permit.hard_kill_latch_generation)
   { result.operation_state=SWV5S5_ADMISSION_CLAIM_TIME_FAILED; result.reason_code="RISK_PERMIT_BINDING_MISMATCH"; return false; }
   if(context.clock_time>=authority_input.risk_authorization.expires_at)
   { result.operation_state=SWV5S5_ADMISSION_CLAIM_TIME_FAILED; result.reason_code="SPRINT5_RISK_EXPIRED_EXCLUSIVE"; return false; }
   if(context.clock_time<authority_input.producer_trust.valid_from || context.clock_time>=authority_input.producer_trust.valid_until)
   { result.operation_state=SWV5S5_ADMISSION_CLAIM_TIME_FAILED; result.reason_code="TRUST_EXPIRED_AT_CLAIM"; return false; }
   if(context.clock_time<authority_input.permit.valid_from || context.clock_time>=authority_input.permit.valid_until ||
      !authority_input.lease_live || !authority_input.account_observation_fresh ||
      !authority_input.symbol_specification_fresh || !authority_input.margin_fresh || !authority_input.basket_risk_fresh ||
      !authority_input.clock_nonregressing)
   { result.operation_state=SWV5S5_ADMISSION_CLAIM_TIME_FAILED; result.reason_code="CLAIM_TIME_AUTHORITY_DENIED"; return false; }
   result.operation_state=SWV5S5_ADMISSION_PROVISIONAL_P_AVAILABLE;
   result.reason_code="CLAIM_TIME_AUTHORITIES_VALID";
   return true;
}

void SWV5S5_CompleteConditionalAdmission(const SWV5S5_InvocationClaimResult &claim,
                                          SWV5S5_ConditionalAdmissionResult &result)
{
   if(claim.disposition==SWV5S5_CLAIM_GRANTED_NOW && claim.claim_granted_now)
   {
      result.operation_state=SWV5S5_ADMISSION_COMPLETED;
      result.policy_linearized_at_p=true;
      result.claim_authorized=true;
      result.reason_code="ADMISSION_LINEARIZED_AT_P";
   }
   else
   {
      result.operation_state=SWV5S5_ADMISSION_CLAIM_LOST;
      result.policy_linearized_at_p=false;
      result.claim_authorized=false;
      result.reason_code="P_INEFFECTIVE_CLAIM_FAILED";
   }
}

SWV5S5_MutationDisposition SWV5S5_EvaluateConcurrentMutation(
   const SWV5S5_StableAuthorityKind kind,const SWV5S5_AuthorityMutationTiming timing,
   const bool claim_succeeds)
{
   if(kind==SWV5S5_AUTHORITY_UNDEFINED || timing==SWV5S5_MUTATION_TIMING_INVALID)
      return SWV5S5_MUTATION_DISPOSITION_INVALID;
   if(timing==SWV5S5_MUTATION_BEFORE_P) return SWV5S5_MUTATION_BLOCK_CURRENT;
   if(timing==SWV5S5_MUTATION_AFTER_P_BEFORE_CLAIM)
      return claim_succeeds ? SWV5S5_MUTATION_CURRENT_RETAINED_LATER_BLOCKED : SWV5S5_MUTATION_UNSTABLE_RECOLLECT;
   if(timing==SWV5S5_MUTATION_AFTER_CLAIM) return SWV5S5_MUTATION_POST_CLAIM_RECONCILE;
   return SWV5S5_MUTATION_DISPOSITION_INVALID;
}

#endif
