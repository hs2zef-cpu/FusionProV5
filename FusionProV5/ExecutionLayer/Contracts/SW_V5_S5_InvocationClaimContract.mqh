#ifndef SW_V5_S5_INVOCATION_CLAIM_CONTRACT_MQH
#define SW_V5_S5_INVOCATION_CLAIM_CONTRACT_MQH

// SPRINT 5 PHASE B.1 CANDIDATE CONTRACT
// PURE TRANSITION PREPARATION NEVER GRANTS INVOCATION AUTHORITY

#include "SW_V5_S5_AdmissionSnapshotContract.mqh"

struct SWV5S5_InvocationClaimCommand
{
   SWV5_ContractVersion contract_version;
   string claim_policy_id;
   uint claim_policy_version;
   SWV5S5_SubmissionAuthorityRecord expected_authority_record;
   ulong expected_authority_revision;
   string expected_authority_digest;
   SWV5S5_AdmissionSnapshot admission_snapshot;
   SWV5_InstanceLease current_ownership_lease;
   SWV5S5_AuthoritativeClockObservation claim_clock;
   string claim_id;
   string command_digest;
};

struct SWV5S5_InvocationClaimTransition
{
   SWV5_ContractVersion contract_version;
   SWV5S5_ClaimDisposition disposition;
   bool transition_eligible;
   SWV5S5_SubmissionAuthorityRecord proposed_next_record;
   string reason_code;
   // No claim_granted_now field. This replayable pure output carries no authority.
};

struct SWV5S5_InvocationClaimResult
{
   SWV5_ContractVersion contract_version;
   SWV5S5_ClaimDisposition disposition;
   bool claim_granted_now; // ephemeral: true only for the operation that commits
   SWV5S5_SubmissionAuthorityRecord resulting_authority_record;
   string reason_code;
};

bool SWV5S5_DeriveClaimId(const SWV5S5_InvocationClaimCommand &command,string &claim_id)
{
   string permit,request,attempt,revision,snapshot,body;
   if(!SWV5S5_CanonicalString("permit_id",command.expected_authority_record.permit.permit_id,permit) ||
      !SWV5S5_CanonicalRequestIdentity("request",command.expected_authority_record.permit.request_identity,request) ||
      !SWV5S5_CanonicalString("attempt_id",command.expected_authority_record.permit.unique_attempt_id,attempt) ||
      !SWV5S5_CanonicalUInt("expected_authority_revision",command.expected_authority_revision,revision) ||
      !SWV5S5_CanonicalString("admission_snapshot_digest",command.admission_snapshot.snapshot_digest,snapshot)) return false;
   body=permit+request+attempt+revision+snapshot;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INVOCATION_CLAIM,body,claim_id);
}

bool SWV5S5_DeriveClaimCommandDigest(SWV5S5_InvocationClaimCommand &command,string &digest)
{
   string snapshot_digest,body="",f;
   SWV5S5_LeaseLivenessAuthorityView current_lease;
   current_lease.lease=command.current_ownership_lease;
   if(!SWV5S5_DeriveAdmissionSnapshotDigest(command.admission_snapshot,snapshot_digest) ||
      command.admission_snapshot.snapshot_digest!=snapshot_digest ||
      !SWV5S5_DeriveLeaseProjection(current_lease)) return false;
   if(!SWV5S5_CanonicalContractVersion("version",command.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_policy_id",command.claim_policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("claim_policy_version",command.claim_policy_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("expected_authority_digest",command.expected_authority_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expected_authority_revision",command.expected_authority_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("snapshot_digest",snapshot_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("current_lease_projection",current_lease.projection_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalClockObservation("claim_clock",command.claim_clock,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_id",command.claim_id,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INVOCATION_CLAIM,body,digest);
}

bool SWV5S5_PrepareInvocationClaimTransition(const SWV5_ContractValidationContext &context,
                                             SWV5S5_InvocationClaimCommand &command,
                                             SWV5S5_InvocationClaimTransition &transition)
{
   ZeroMemory(transition); SWV5S5_InitContractVersion(transition.contract_version);
   SWV5S5_SubmissionAuthorityRecord observed=command.expected_authority_record;
   SWV5S5_AdmissionSnapshot snapshot=command.admission_snapshot;
   string authority_digest,snapshot_digest,claim_id,command_digest;
   SWV5S5_NormalizedPayloadAuthorityView permit_payload;
   permit_payload.payload=observed.permit.normalized_payload;
   permit_payload.normalization_identity=observed.permit.normalization_identity;
   SWV5S5_ValidationResult permit_validation;
   if(!SWV5S5_IsCandidateVersion(command.contract_version) || command.claim_policy_id!=SWV5S5_POLICY_ID ||
      command.claim_policy_version!=SWV5S5_SCHEMA_VERSION ||
      !SWV5S5_DeriveDurableSubmissionAuthorityDigest(observed,authority_digest) ||
      observed.durable_record_digest!=authority_digest || command.expected_authority_digest!=authority_digest)
   { transition.disposition=SWV5S5_CLAIM_INVALID; transition.reason_code="DURABLE_AUTHORITY_INVALID"; return false; }
   if(observed.state!=SWV5S5_COMMITTED_NOT_INVOKED)
   { transition.disposition=SWV5S5_CLAIM_ALREADY_CLAIMED; transition.reason_code="CURRENT_STATE_NOT_CLAIMABLE"; return false; }
   if(command.expected_authority_revision!=observed.authority_revision)
   { transition.disposition=SWV5S5_CLAIM_CONFLICT; transition.reason_code="STALE_AUTHORITY_REVISION"; return false; }
   if(observed.authority_revision==18446744073709551615)
   { transition.disposition=SWV5S5_CLAIM_CONFLICT; transition.reason_code="AUTHORITY_REVISION_OVERFLOW"; return false; }
   if(context.clock_time<observed.permit.valid_from || context.clock_time>=observed.permit.valid_until ||
      context.clock_time>=observed.permit.risk_authorization.expires_at ||
      context.clock_time<observed.permit.producer_trust.valid_from ||
      context.clock_time>=observed.permit.producer_trust.valid_until)
   { transition.disposition=SWV5S5_CLAIM_EXPIRED; transition.reason_code="CLAIM_AUTHORITY_EXPIRED"; return false; }
   if(!SWV5S5_ValidatePermit(context,observed.permit,permit_validation))
   { transition.disposition=SWV5S5_CLAIM_PERMIT_MISMATCH; transition.reason_code="PERMIT_INVALID"; return false; }
   if(!SWV5S5_DeriveAdmissionSnapshotDigest(snapshot,snapshot_digest) || snapshot.snapshot_digest!=snapshot_digest)
   { transition.disposition=SWV5S5_CLAIM_SNAPSHOT_MISMATCH; transition.reason_code="SNAPSHOT_INTEGRITY_INVALID"; return false; }
   SWV5S5_AdmissionAuthorityCollection v=snapshot.collect_v2;
   if(!SWV5S5_DeriveNormalizedProjection(v.normalized_payload) ||
      !SWV5S5_DeriveNormalizedProjection(permit_payload) ||
      !SWV5S5_EqualNamespace(v.persistence_namespace,observed.permit.persistence_namespace) ||
      !SWV5S5_EqualRequestIdentity(v.request_identity,observed.permit.request_identity) ||
      v.attempt_id!=observed.permit.unique_attempt_id ||
      v.normalized_payload.normalization_identity!=observed.permit.normalization_identity ||
      v.normalized_payload.projection_digest!=permit_payload.projection_digest ||
      v.normalized_payload.payload.specification_sequence!=observed.permit.symbol_specification_sequence ||
      v.submission_permit.permit.permit_id!=observed.permit.permit_id ||
      v.submission_permit.permit.permit_digest!=observed.permit.permit_digest ||
      v.submission_permit.projection_digest!=observed.permit.permit_digest)
   { transition.disposition=SWV5S5_CLAIM_SNAPSHOT_MISMATCH; transition.reason_code="SNAPSHOT_BINDING_MISMATCH"; return false; }
   if(!SWV5S5_EqualFence(command.current_ownership_lease.fence,observed.permit.ownership_fence) ||
      !SWV5S5_EqualFence(v.ownership.fence,command.current_ownership_lease.fence) ||
      !SWV5S5_EqualFence(v.lease_liveness.lease.fence,command.current_ownership_lease.fence) ||
      (command.current_ownership_lease.status!=SWV5_LOCK_ACQUIRED && command.current_ownership_lease.status!=SWV5_LOCK_RENEWED))
   { transition.disposition=SWV5S5_CLAIM_STALE_OWNER; transition.reason_code="CURRENT_OWNERSHIP_TAKEOVER_MISMATCH"; return false; }
   SWV5S5_LeaseLivenessAuthorityView current_lease;
   current_lease.lease=command.current_ownership_lease;
   if(!SWV5S5_DeriveLeaseProjection(current_lease) ||
      current_lease.projection_digest!=v.lease_liveness.projection_digest)
   { transition.disposition=SWV5S5_CLAIM_STALE_OWNER; transition.reason_code="CURRENT_LEASE_LIVENESS_MISMATCH"; return false; }
   if(command.claim_clock.clock_id!=context.clock_id || command.claim_clock.clock_authority!=context.clock_authority ||
      command.claim_clock.clock_sequence!=context.clock_sequence || command.claim_clock.observed_at!=context.clock_time ||
      command.claim_clock.clock_sequence<snapshot.collect_v2.collect_clock.clock_sequence ||
      command.claim_clock.observed_at<snapshot.collect_v2.collect_clock.observed_at ||
      command.current_ownership_lease.clock_id!=context.clock_id ||
      command.current_ownership_lease.clock_authority!=context.clock_authority ||
      context.clock_time>=command.current_ownership_lease.expires_at)
   { transition.disposition=SWV5S5_CLAIM_TIME_INVALID; transition.reason_code="CLAIM_CLOCK_OR_LEASE_INVALID"; return false; }
   // ADR-020: only time validity remains at Claim. Trust status and Hard Kill
   // mutations after provisional P are not reintroduced as second policy vetoes.
   command.admission_snapshot.claim_clock=command.claim_clock;
   if(!SWV5S5_DeriveAdmissionSnapshotDigest(command.admission_snapshot,snapshot_digest))
   { transition.disposition=SWV5S5_CLAIM_SNAPSHOT_MISMATCH; transition.reason_code="FINAL_SNAPSHOT_INVALID"; return false; }
   command.admission_snapshot.snapshot_digest=snapshot_digest;
   if(!SWV5S5_DeriveClaimId(command,claim_id) || command.claim_id!=claim_id ||
      !SWV5S5_DeriveClaimCommandDigest(command,command_digest) || command.command_digest!=command_digest)
   { transition.disposition=SWV5S5_CLAIM_INVALID; transition.reason_code="CLAIM_COMMAND_INTEGRITY_INVALID"; return false; }
   transition.proposed_next_record=observed;
   transition.proposed_next_record.state=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED;
   transition.proposed_next_record.authority_revision=observed.authority_revision+1;
   transition.proposed_next_record.invocation_claim_id=claim_id;
   transition.proposed_next_record.claim_ownership_lease=command.current_ownership_lease;
   transition.proposed_next_record.claimed_at=command.claim_clock.observed_at;
   transition.proposed_next_record.claim_clock_id=command.claim_clock.clock_id;
   transition.proposed_next_record.claim_clock_authority=command.claim_clock.clock_authority;
   transition.proposed_next_record.claim_clock_sequence=command.claim_clock.clock_sequence;
   transition.proposed_next_record.admission_snapshot_digest=snapshot_digest;
   transition.proposed_next_record.claim_policy_id=command.claim_policy_id;
   transition.proposed_next_record.claim_policy_version=command.claim_policy_version;
   if(!SWV5S5_DeriveDurableSubmissionAuthorityDigest(transition.proposed_next_record,
                                                      transition.proposed_next_record.durable_record_digest))
   { transition.disposition=SWV5S5_CLAIM_INVALID; transition.reason_code="NEXT_RECORD_DIGEST_FAILED"; return false; }
   transition.disposition=SWV5S5_CLAIM_TRANSITION_ELIGIBLE;
   transition.transition_eligible=true;
   transition.reason_code="CLAIM_TRANSITION_ELIGIBLE_NO_GRANT";
   return true;
}

bool SWV5S5_ValidateAuthoritativeClaimResult(const SWV5S5_InvocationClaimTransition &prepared,
                                             const SWV5S5_InvocationClaimResult &authoritative_result)
{
   string digest;
   if(!prepared.transition_eligible || prepared.disposition!=SWV5S5_CLAIM_TRANSITION_ELIGIBLE ||
      !authoritative_result.claim_granted_now ||
      authoritative_result.disposition!=SWV5S5_CLAIM_GRANTED_NOW ||
      authoritative_result.resulting_authority_record.state!=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED ||
      authoritative_result.resulting_authority_record.authority_revision!=prepared.proposed_next_record.authority_revision ||
      authoritative_result.resulting_authority_record.permit.permit_id!=prepared.proposed_next_record.permit.permit_id ||
      authoritative_result.resulting_authority_record.permit.permit_digest!=prepared.proposed_next_record.permit.permit_digest ||
      authoritative_result.resulting_authority_record.invocation_claim_id!=prepared.proposed_next_record.invocation_claim_id ||
      authoritative_result.resulting_authority_record.admission_snapshot_digest!=prepared.proposed_next_record.admission_snapshot_digest ||
      authoritative_result.resulting_authority_record.durable_record_digest!=prepared.proposed_next_record.durable_record_digest ||
      !SWV5S5_DeriveDurableSubmissionAuthorityDigest(authoritative_result.resulting_authority_record,digest) ||
      digest!=authoritative_result.resulting_authority_record.durable_record_digest) return false;
   return true;
}

class ISWV5S5InvocationClaimAuthority
{
public:
   // The implementation MUST load and compare current Submission Authority and
   // current V5 ownership/takeover inside one shared serialization boundary,
   // verify the full snapshot, and atomically commit COMMITTED_NOT_INVOKED ->
   // INVOCATION_CLAIMED_UNRESOLVED. Only that commit winner may return the
   // ephemeral CLAIM_GRANTED_NOW; persisted records never recreate the grant.
   virtual bool TryClaimInvocation(const SWV5S5_InvocationClaimCommand &command,
                                   SWV5S5_InvocationClaimResult &authoritative_result)=0;
};

#endif
