#ifndef SW_V5_S5_SUBMISSION_AUTHORITY_CONTRACT_MQH
#define SW_V5_S5_SUBMISSION_AUTHORITY_CONTRACT_MQH

// SPRINT 5 PHASE B CANDIDATE CONTRACT
// PURE PERMIT/CLAIM STATE MACHINE / NO BROKER INVOCATION OR DURABLE STORE

#include "SW_V5_S5_RuntimePublicationContract.mqh"

struct SWV5S5_SubmissionPermit
{
   SWV5_ContractVersion contract_version;
   string permit_id;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   SWV5_ExecutionRequestIdentity request_identity;
   string ingress_identity;
   ulong request_set_revision;
   string request_set_digest;
   string risk_authorization_id;
   datetime risk_expires_at;
   SWV5_AccountPositionMode account_mode;
   ulong basket_state_version;
   ulong symbol_specification_sequence;
   string hard_kill_latch_id;
   ulong hard_kill_latch_generation;
   string normalized_payload_digest;
   ulong trust_generation;
   datetime valid_from;
   datetime valid_until;
   ulong permit_revision;
   string permit_digest;
};

struct SWV5S5_SubmissionAuthorityRecord
{
   SWV5_ContractVersion contract_version;
   SWV5S5_SubmissionPermit permit;
   SWV5S5_SubmissionAuthorityState state;
   ulong authority_revision;
   string invocation_claim_id;
   datetime claimed_at;
   string durable_record_digest;
   // Deliberately no CLAIM_GRANTED_NOW member: grant exists only in call result.
};

struct SWV5S5_InvocationClaimProposal
{
   SWV5_ContractVersion contract_version;
   string claim_id;
   string permit_id;
   SWV5_ExecutionRequestIdentity request_identity;
   SWV5_OwnershipFence ownership_fence;
   ulong expected_authority_revision;
   string admission_snapshot_digest;
   datetime claim_time;
   ulong claim_clock_sequence;
   string claim_digest;
};

struct SWV5S5_InvocationClaimResult
{
   SWV5_ContractVersion contract_version;
   SWV5S5_ClaimDisposition disposition;
   bool claim_granted_now;
   ulong resulting_authority_revision;
   string reason_code;
   // This result is ephemeral and MUST NOT be serialized as durable authority.
};

bool SWV5S5_DerivePermitId(const SWV5S5_SubmissionPermit &permit,string &permit_id)
{
   string scope,request,revision,request_set_revision,preimage;
   if(!SWV5S5_CanonicalNamespace("scope",permit.persistence_namespace,scope) ||
      !SWV5S5_CanonicalRequestIdentity("request",permit.request_identity,request) ||
      !SWV5S5_CanonicalUInt("permit_revision",permit.permit_revision,revision) ||
      !SWV5S5_CanonicalUInt("request_set_revision",permit.request_set_revision,request_set_revision)) return false;
   preimage=scope+request+revision+request_set_revision;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_PERMIT_ID,preimage,permit_id);
}

bool SWV5S5_DerivePermitDigest(const SWV5S5_SubmissionPermit &permit,string &digest)
{
   string body="",f;
#define SWV5S5_PERMIT_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define SWV5S5_PERMIT_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define SWV5S5_PERMIT_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("version",permit.contract_version,f)) return false; body+=f;
   SWV5S5_PERMIT_S("permit_id",permit.permit_id);
   if(!SWV5S5_CanonicalNamespace("scope",permit.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",permit.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",permit.request_identity,f)) return false; body+=f;
   SWV5S5_PERMIT_S("ingress_identity",permit.ingress_identity);
   SWV5S5_PERMIT_U("request_set_revision",permit.request_set_revision);
   SWV5S5_PERMIT_S("request_set_digest",permit.request_set_digest);
   SWV5S5_PERMIT_S("risk_authorization_id",permit.risk_authorization_id);
   SWV5S5_PERMIT_I("risk_expires_at",permit.risk_expires_at);
   SWV5S5_PERMIT_I("account_mode",permit.account_mode);
   SWV5S5_PERMIT_U("basket_state_version",permit.basket_state_version);
   SWV5S5_PERMIT_U("symbol_specification_sequence",permit.symbol_specification_sequence);
   SWV5S5_PERMIT_S("hard_kill_latch_id",permit.hard_kill_latch_id);
   SWV5S5_PERMIT_U("hard_kill_latch_generation",permit.hard_kill_latch_generation);
   SWV5S5_PERMIT_S("normalized_payload_digest",permit.normalized_payload_digest);
   SWV5S5_PERMIT_U("trust_generation",permit.trust_generation);
   SWV5S5_PERMIT_I("valid_from",permit.valid_from);
   SWV5S5_PERMIT_I("valid_until",permit.valid_until);
   SWV5S5_PERMIT_U("permit_revision",permit.permit_revision);
#undef SWV5S5_PERMIT_S
#undef SWV5S5_PERMIT_U
#undef SWV5S5_PERMIT_I
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_SUBMISSION_PERMIT,body,digest);
}

bool SWV5S5_DeriveClaimDigest(const SWV5S5_InvocationClaimProposal &claim,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",claim.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_id",claim.claim_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("permit_id",claim.permit_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",claim.request_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",claim.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expected_authority_revision",claim.expected_authority_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("admission_snapshot_digest",claim.admission_snapshot_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("claim_time",claim.claim_time,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("claim_clock_sequence",claim.claim_clock_sequence,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INVOCATION_CLAIM,body,digest);
}

bool SWV5S5_DeriveClaimId(const SWV5S5_InvocationClaimProposal &claim,string &claim_id)
{
   string permit,request,revision,body;
   if(!SWV5S5_CanonicalString("permit_id",claim.permit_id,permit) ||
      !SWV5S5_CanonicalRequestIdentity("request",claim.request_identity,request) ||
      !SWV5S5_CanonicalUInt("expected_authority_revision",claim.expected_authority_revision,revision)) return false;
   body=permit+request+revision;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INVOCATION_CLAIM,body,claim_id);
}

bool SWV5S5_DeriveDurableSubmissionAuthorityDigest(
   const SWV5S5_SubmissionAuthorityRecord &record,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",record.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("permit_digest",record.permit.permit_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("state",record.state,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("authority_revision",record.authority_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("invocation_claim_id",record.invocation_claim_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("claimed_at",record.claimed_at,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_SUBMISSION_PERMIT,body,digest);
}

bool SWV5S5_ValidatePermit(const SWV5_ContractValidationContext &context,
                           const SWV5S5_SubmissionPermit &permit,
                           SWV5S5_ValidationResult &result)
{
   string expected,expected_digest;
   if(!SWV5S5_IsCandidateVersion(permit.contract_version) || !SWV5S5_DerivePermitId(permit,expected) ||
      permit.permit_id!=expected || permit.request_identity.request_id.correlation_id=="" ||
      !SWV5S5_IsV5Version(permit.persistence_namespace.contract_version) ||
      !SWV5S5_IsV5Version(permit.ownership_fence.contract_version) ||
      !SWV5S5_IsV5Version(permit.request_identity.contract_version) ||
      !SWV5S5_EqualOwnershipKey(permit.persistence_namespace.ownership_namespace,
                                permit.ownership_fence.ownership_namespace) ||
      permit.ingress_identity=="" || permit.request_set_revision==0 ||
      !SWV5S5_IsDigest64Lower(permit.request_set_digest) || permit.risk_authorization_id=="" ||
      permit.risk_expires_at<=0 || permit.account_mode!=SWV5_ACCOUNT_MODE_HEDGING ||
      permit.basket_state_version==0 || permit.symbol_specification_sequence==0 ||
      permit.hard_kill_latch_id=="" || permit.hard_kill_latch_generation==0 ||
      !SWV5S5_IsDigest64Lower(permit.normalized_payload_digest) || permit.trust_generation==0 ||
      permit.valid_from<=0 || permit.valid_until<=permit.valid_from ||
      context.clock_time<permit.valid_from || context.clock_time>=permit.valid_until ||
      !SWV5S5_DerivePermitDigest(permit,expected_digest) || permit.permit_digest!=expected_digest)
   { SWV5S5_Deny(context,"SUBMISSION_PERMIT_INVALID","",result); return false; }
   SWV5S5_Allow(context,"SUBMISSION_PERMIT_VALID",result); return true;
}

bool SWV5S5_EvaluateInvocationClaim(const SWV5_ContractValidationContext &context,
                                    const SWV5S5_SubmissionAuthorityRecord &observed,
                                    const SWV5S5_InvocationClaimProposal &proposal,
                                    SWV5S5_InvocationClaimResult &result)
{
   ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
   string expected_record_digest,expected_claim_id;
   SWV5S5_ValidationResult permit_validation;
   if(!SWV5S5_IsCandidateVersion(observed.contract_version) ||
      !SWV5S5_ValidatePermit(context,observed.permit,permit_validation) ||
      !SWV5S5_DeriveDurableSubmissionAuthorityDigest(observed,expected_record_digest) ||
      observed.durable_record_digest!=expected_record_digest)
   { result.disposition=SWV5S5_CLAIM_INVALID; result.reason_code="DURABLE_AUTHORITY_INVALID"; return false; }
   if(observed.state!=SWV5S5_COMMITTED_NOT_INVOKED)
   { result.disposition=SWV5S5_CLAIM_ALREADY_CLAIMED; result.reason_code="NO_FRESH_GRANT"; return false; }
   if(proposal.expected_authority_revision!=observed.authority_revision)
   { result.disposition=SWV5S5_CLAIM_CONFLICT; result.reason_code="STALE_AUTHORITY_REVISION"; return false; }
   if(proposal.permit_id!=observed.permit.permit_id ||
      !SWV5S5_EqualRequestIdentity(proposal.request_identity,observed.permit.request_identity))
   { result.disposition=SWV5S5_CLAIM_PERMIT_MISMATCH; result.reason_code="PERMIT_BINDING_MISMATCH"; return false; }
   if(!SWV5S5_EqualFence(proposal.ownership_fence,observed.permit.ownership_fence))
   { result.disposition=SWV5S5_CLAIM_STALE_OWNER; result.reason_code="STALE_OWNER"; return false; }
   if(proposal.claim_time!=context.clock_time || proposal.claim_clock_sequence!=context.clock_sequence ||
      proposal.claim_time<=0)
   { result.disposition=SWV5S5_CLAIM_TIME_INVALID; result.reason_code="CLAIM_CLOCK_INVALID"; return false; }
   if(proposal.claim_time<observed.permit.valid_from || proposal.claim_time>=observed.permit.valid_until ||
      proposal.claim_time>=observed.permit.risk_expires_at)
   { result.disposition=SWV5S5_CLAIM_EXPIRED; result.reason_code="CLAIM_AUTHORITY_EXPIRED"; return false; }
   string expected_claim_digest;
   if(proposal.admission_snapshot_digest=="" || !SWV5S5_IsDigest64Lower(proposal.admission_snapshot_digest) ||
      !SWV5S5_DeriveClaimId(proposal,expected_claim_id) || proposal.claim_id!=expected_claim_id ||
      !SWV5S5_DeriveClaimDigest(proposal,expected_claim_digest) || proposal.claim_digest!=expected_claim_digest ||
      observed.authority_revision==18446744073709551615)
   { result.disposition=SWV5S5_CLAIM_SNAPSHOT_MISMATCH; result.reason_code="CLAIM_INTEGRITY_INVALID"; return false; }
   result.disposition=SWV5S5_CLAIM_GRANTED_NOW;
   result.claim_granted_now=true;
   result.resulting_authority_revision=observed.authority_revision+1;
   result.reason_code="CLAIM_GRANTED_NOW";
   return true;
}

class ISWV5S5SubmissionAuthorityContract
{
public:
   virtual bool ProposePermit(const SWV5_ContractValidationContext &context,
                              const SWV5S5_SubmissionPermit &permit,
                              SWV5S5_ValidationResult &result)=0;
   virtual bool ClaimInvocation(const SWV5_ContractValidationContext &context,
                                const SWV5S5_SubmissionAuthorityRecord &observed,
                                const SWV5S5_InvocationClaimProposal &proposal,
                                SWV5S5_InvocationClaimResult &result)=0;
};

#endif
