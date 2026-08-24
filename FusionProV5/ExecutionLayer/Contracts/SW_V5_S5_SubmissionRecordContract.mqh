#ifndef SW_V5_S5_SUBMISSION_RECORD_CONTRACT_MQH
#define SW_V5_S5_SUBMISSION_RECORD_CONTRACT_MQH

// SPRINT 5 PHASE B.2 CANDIDATE CONTRACT
// DURABLE SUBMISSION/CLAIM VALUE + PURE PREPARATION / NO BROKER OR STORE

#include "SW_V5_S5_AdmissionSnapshotContract.mqh"

struct SWV5S5_SubmissionAuthorityRecord
{
   SWV5_ContractVersion contract_version;
   SWV5S5_SubmissionPermit permit;
   SWV5S5_SubmissionAuthorityState state;
   ulong authority_revision;
   string invocation_claim_id;
   SWV5_InstanceLease claim_ownership_lease;
   datetime claimed_at;
   string claim_clock_id;
   SWV5_TimeAuthority claim_clock_authority;
   ulong claim_clock_sequence;
   SWV5S5_AdmissionSnapshot admission_snapshot;
   string admission_snapshot_digest;
   string claim_policy_id;
   uint claim_policy_version;
   string durable_record_digest;
};

struct SWV5S5_SubmissionAuthorityIndexEntry
{
   string logical_correlation_id;
   string attempt_id;
   string permit_id;
   string permit_digest;
   SWV5S5_SubmissionAuthorityState state;
   ulong authority_revision;
   string durable_record_digest;
};

struct SWV5S5_PermitPreparationCommand
{
   SWV5_ContractVersion contract_version;
   string expected_index_digest;
   ulong expected_index_revision;
   SWV5S5_SubmissionPermit proposed_permit;
   string command_digest;
};

struct SWV5S5_PermitPreparationResult
{
   SWV5_ContractVersion contract_version;
   SWV5S5_PermitDisposition disposition;
   SWV5S5_SubmissionAuthorityRecord proposed_record;
   string reason_code;
};

bool SWV5S5_DeriveDurableSubmissionAuthorityDigest(const SWV5S5_SubmissionAuthorityRecord &record,string &digest)
{
   string body="",f,snapshot_digest="";
   const bool claimed=(record.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED ||
      record.state==SWV5S5_AUTHORITATIVE_SIDE_EFFECT_CONFIRMED ||
      record.state==SWV5S5_AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED ||
      record.state==SWV5S5_AUTHORITATIVE_REJECTED ||
      record.state==SWV5S5_CONFLICT_MANUAL_REQUIRED);
   if(claimed)
   {
      SWV5S5_AdmissionSnapshot snapshot=record.admission_snapshot;
      if(!SWV5S5_DeriveAdmissionSnapshotDigest(snapshot,snapshot_digest) ||
         snapshot.snapshot_digest!=snapshot_digest || record.admission_snapshot_digest!=snapshot_digest) return false;
   }
   else if(record.state!=SWV5S5_COMMITTED_NOT_INVOKED || record.admission_snapshot_digest!="" ||
           record.admission_snapshot.snapshot_digest!="" || record.invocation_claim_id!="" ||
           record.claimed_at!=0 || record.claim_clock_id!="" ||
           record.claim_clock_authority!=SWV5_TIME_AUTHORITY_NONE || record.claim_clock_sequence!=0 ||
           record.claim_policy_id!="" || record.claim_policy_version!=0) return false;
   if(!SWV5S5_CanonicalContractVersion("version",record.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("permit_digest",record.permit.permit_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("state",record.state,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("authority_revision",record.authority_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("has_invocation_claim",claimed,f)) return false; body+=f;
   if(!claimed) return SWV5S5_DomainDigest(SWV5S5_DOMAIN_SUBMISSION_PERMIT,body,digest);
   if(!SWV5S5_CanonicalString("invocation_claim_id",record.invocation_claim_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInstanceLease("claim_ownership_lease",record.claim_ownership_lease,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("claimed_at",record.claimed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_clock_id",record.claim_clock_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("claim_clock_authority",record.claim_clock_authority,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("claim_clock_sequence",record.claim_clock_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("admission_snapshot_digest",snapshot_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_policy_id",record.claim_policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("claim_policy_version",record.claim_policy_version,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INVOCATION_CLAIM,body,digest);
}

bool SWV5S5_DeriveSubmissionIndexDigest(const SWV5S5_SubmissionAuthorityIndexEntry &entries[],string &digest)
{
   string body="",entry="",f;
   for(int i=0;i<ArraySize(entries);i++)
   {
      entry="";
      if(entries[i].logical_correlation_id=="" || entries[i].attempt_id=="" || entries[i].permit_id=="" ||
         entries[i].authority_revision==0 || !SWV5S5_IsDigest64Lower(entries[i].permit_digest) ||
         !SWV5S5_IsDigest64Lower(entries[i].durable_record_digest) ||
         (i>0 && (StringCompare(entries[i-1].logical_correlation_id,entries[i].logical_correlation_id)>0 ||
          (entries[i-1].logical_correlation_id==entries[i].logical_correlation_id &&
           StringCompare(entries[i-1].attempt_id,entries[i].attempt_id)>=0)))) return false;
      if(!SWV5S5_CanonicalString("correlation_id",entries[i].logical_correlation_id,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalString("attempt_id",entries[i].attempt_id,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalString("permit_id",entries[i].permit_id,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalString("permit_digest",entries[i].permit_digest,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalInt("state",entries[i].state,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalUInt("authority_revision",entries[i].authority_revision,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalString("record_digest",entries[i].durable_record_digest,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalIndexed("submission",(ulong)i,entry,f)) return false; body+=f;
   }
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_SUBMISSION_PERMIT,body,digest);
}

bool SWV5S5_DerivePermitPreparationCommandDigest(const SWV5S5_PermitPreparationCommand &command,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",command.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("expected_index_digest",command.expected_index_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expected_index_revision",command.expected_index_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("permit_digest",command.proposed_permit.permit_digest,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_SUBMISSION_PERMIT,body,digest);
}

bool SWV5S5_PreparePermitCommit(const SWV5_ContractValidationContext &context,
                                const SWV5S5_SubmissionAuthorityIndexEntry &entries[],
                                const SWV5S5_PermitPreparationCommand &command,
                                const SWV5S5_ProducerTrustRecord &current_trust,
                                const SWV5S5_ProducerTrustAnchor &trust_anchor,
                                const SWV5S5_ProducerTrustScope &trust_scope,
                                const SWV5S5_IngressEnvelope &accepted_ingress,
                                SWV5S5_PermitPreparationResult &result)
{
   ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
   string index_digest,command_digest,current_digest,embedded_digest;
   string ingress_identity,ingress_payload,correlation,attempt,idempotency;
   SWV5S5_ValidationResult validation,trust_validation;
   if(!SWV5S5_DeriveSubmissionIndexDigest(entries,index_digest) || index_digest!=command.expected_index_digest ||
      !SWV5S5_DerivePermitPreparationCommandDigest(command,command_digest) || command.command_digest!=command_digest ||
      !SWV5S5_ValidateProducerTrust(context,current_trust,trust_anchor,trust_scope,accepted_ingress,trust_validation) ||
      !SWV5S5_DeriveProducerTrustDigest(current_trust,current_digest) || current_trust.record_digest!=current_digest ||
      !SWV5S5_DeriveProducerTrustDigest(command.proposed_permit.producer_trust,embedded_digest) ||
      command.proposed_permit.producer_trust.record_digest!=embedded_digest || current_digest!=embedded_digest ||
      current_trust.authority_record_id!=command.proposed_permit.producer_trust.authority_record_id ||
      current_trust.authority_generation!=command.proposed_permit.producer_trust.authority_generation ||
      !SWV5S5_DeriveIngressIdentityAndDigest(accepted_ingress,ingress_identity,ingress_payload) ||
      accepted_ingress.ingress_identity!=ingress_identity || accepted_ingress.payload_digest!=ingress_payload ||
      (accepted_ingress.decision.action!=1 && accepted_ingress.decision.action!=-1) ||
      accepted_ingress.decision.direction!=accepted_ingress.decision.action ||
      !SWV5S5_DeriveRequestBinding(command.proposed_permit.persistence_namespace,
         SWV5S5_REQUEST_BINDING_POLICY_ID,SWV5S5_REQUEST_BINDING_POLICY_VERSION,
         ingress_identity,0,correlation,attempt,idempotency) ||
      command.proposed_permit.request_identity.request_id.correlation_id!=correlation ||
      command.proposed_permit.request_identity.request_id.attempt_id!=attempt ||
      command.proposed_permit.request_identity.idempotency_key!=idempotency ||
      command.proposed_permit.risk_authorization.authorized_direction!=accepted_ingress.decision.direction ||
      !SWV5S5_ValidatePermit(context,command.proposed_permit,validation))
   { result.disposition=SWV5S5_PERMIT_INVALID; result.reason_code="PERMIT_PREPARATION_OR_CURRENT_TRUST_INVALID"; return false; }
   const SWV5S5_SubmissionPermit permit=command.proposed_permit;
   if(permit.risk_authorization.authorization_id=="" || permit.margin_authority.authority_record_id=="" ||
      permit.basket_risk_authority.authority_record_id=="" || permit.basket_risk_authority.source_snapshot_id=="" ||
      !SWV5S5_IsDigest64Lower(permit.margin_authority.authority_record_digest) ||
      !SWV5S5_IsDigest64Lower(permit.basket_risk_authority.authority_record_digest) ||
      !SWV5S5_IsDigest64Lower(permit.basket_risk_authority.source_snapshot_digest) ||
      permit.hard_kill_latch_id=="" || permit.hard_kill_latch_generation==0 ||
      permit.unit_authority_id=="" || permit.unit_authority_revision==0 ||
      !SWV5S5_IsDigest64Lower(permit.unit_authority_digest))
   { result.disposition=SWV5S5_PERMIT_INVALID; result.reason_code="PERMIT_NESTED_AUTHORITY_INVALID"; return false; }
   correlation=permit.request_identity.request_id.correlation_id;
   attempt=permit.unique_attempt_id;
   for(int i=0;i<ArraySize(entries);i++)
   {
      if(entries[i].logical_correlation_id!=correlation) continue;
      if(entries[i].attempt_id==attempt)
      {
         result.disposition=(entries[i].permit_id==permit.permit_id && entries[i].permit_digest==permit.permit_digest) ?
                            SWV5S5_PERMIT_EXISTING_IDENTICAL : SWV5S5_PERMIT_CONFLICT;
         result.reason_code=(result.disposition==SWV5S5_PERMIT_EXISTING_IDENTICAL ?
                             "PERMIT_EXISTING_IDENTICAL" : "PERMIT_IDENTITY_CONFLICT");
         return result.disposition==SWV5S5_PERMIT_EXISTING_IDENTICAL;
      }
      if(entries[i].state==SWV5S5_COMMITTED_NOT_INVOKED || entries[i].state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED)
      { result.disposition=SWV5S5_PERMIT_LOGICAL_REQUEST_UNRESOLVED; result.reason_code="COMPETING_UNRESOLVED_ATTEMPT"; return false; }
   }
   ZeroMemory(result.proposed_record); SWV5S5_InitContractVersion(result.proposed_record.contract_version);
   result.proposed_record.permit=permit; result.proposed_record.state=SWV5S5_COMMITTED_NOT_INVOKED;
   result.proposed_record.authority_revision=1;
   if(!SWV5S5_DeriveDurableSubmissionAuthorityDigest(result.proposed_record,result.proposed_record.durable_record_digest))
   { result.disposition=SWV5S5_PERMIT_INVALID; result.reason_code="PERMIT_RECORD_DIGEST_FAILED"; return false; }
   result.disposition=SWV5S5_PERMIT_PROPOSAL_VALID; result.reason_code="PERMIT_PROPOSAL_VALID_NO_COMMIT";
   return true;
}

class ISWV5S5SubmissionPermitAuthority
{
public:
   virtual bool TryCommitPermit(const SWV5S5_PermitPreparationCommand &command,
                                const SWV5S5_SubmissionAuthorityIndexEntry &expected_index[],
                                SWV5S5_PermitPreparationResult &authoritative_result)=0;
};

#endif
