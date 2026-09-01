#ifndef SW_V5_S5_REFERENCE_SUBMISSION_STORE_MQH
#define SW_V5_S5_REFERENCE_SUBMISSION_STORE_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// D.1 persists the complete frozen Submission Authority DTO. The durable
// transition is one namespaced CAS; CLAIM_GRANTED_NOW is never persisted.

#include "SW_V5_S5_FakeTransactionalStore.mqh"

bool SWV5S5_ReferencePermitValidAt(const SWV5S5_SubmissionPermit &permit,const datetime observed_at,
                                    const string clock_id,const SWV5_TimeAuthority clock_authority,
                                    const ulong clock_sequence)
{
   SWV5_ContractValidationContext context; ZeroMemory(context);
   context.expected_version=permit.contract_version;
   context.clock_id=clock_id; context.clock_authority=clock_authority;
   context.clock_time=observed_at; context.clock_sequence=clock_sequence;
   context.evaluation_sequence=clock_sequence; context.price_tolerance=0.0; context.volume_tolerance=0.0;
   SWV5S5_ValidationResult validation;
   string permit_id,permit_digest,trust_digest;
   return observed_at>0 && clock_id!="" && clock_authority!=SWV5_TIME_AUTHORITY_NONE && clock_sequence>0 &&
      SWV5S5_DerivePermitId(permit,permit_id) && permit.permit_id==permit_id &&
      SWV5S5_DeriveProducerTrustDigest(permit.producer_trust,trust_digest) &&
      permit.producer_trust.record_digest==trust_digest &&
      SWV5S5_DerivePermitDigest(permit,permit_digest) && permit.permit_digest==permit_digest &&
      SWV5S5_ValidatePermit(context,permit,validation);
}

bool SWV5S5_ReferenceCanonicalSubmissionRecord(const SWV5S5_SubmissionAuthorityRecord &record,
                                                string &canonical,string &namespace_digest,
                                                string &fence_digest)
{
   string durable,permit_digest,permit_id,scope,fence,state,revision,claim_id,snapshot,clock_id,clock_authority,clock_sequence;
   string version,permit_field,lease,claimed_at,claim_policy_id,claim_policy_version,f;
   if(!SWV5S5_DerivePermitId(record.permit,permit_id) || record.permit.permit_id!=permit_id ||
      !SWV5S5_DerivePermitDigest(record.permit,permit_digest) || record.permit.permit_digest!=permit_digest ||
      !SWV5S5_DeriveDurableSubmissionAuthorityDigest(record,durable) ||
      record.durable_record_digest!=durable ||
      !SWV5S5_ReferenceCanonicalNamespaceDigest(record.permit.persistence_namespace,namespace_digest) ||
      !SWV5S5_ReferenceCanonicalFenceDigest(record.permit.ownership_fence,fence_digest) ||
      !SWV5S5_CanonicalContractVersion("version",record.contract_version,version) ||
      !SWV5S5_CanonicalString("permit_id",permit_id,permit_field) ||
      !SWV5S5_CanonicalString("permit_digest",permit_digest,f) ||
      !SWV5S5_CanonicalNamespace("scope",record.permit.persistence_namespace,scope) ||
      !SWV5S5_CanonicalFence("fence",record.permit.ownership_fence,fence) ||
      !SWV5S5_CanonicalInt("state",record.state,state) ||
      !SWV5S5_CanonicalUInt("authority_revision",record.authority_revision,revision) ||
      !SWV5S5_CanonicalString("claim_id",record.invocation_claim_id,claim_id) ||
      !SWV5S5_CanonicalInstanceLease("claim_ownership_lease",record.claim_ownership_lease,lease) ||
      !SWV5S5_CanonicalDatetime("claimed_at",record.claimed_at,claimed_at) ||
      !SWV5S5_CanonicalString("snapshot_digest",record.admission_snapshot_digest,snapshot) ||
      !SWV5S5_CanonicalString("claim_clock_id",record.claim_clock_id,clock_id) ||
      !SWV5S5_CanonicalInt("claim_clock_authority",record.claim_clock_authority,clock_authority) ||
      !SWV5S5_CanonicalUInt("claim_clock_sequence",record.claim_clock_sequence,clock_sequence) ||
      !SWV5S5_CanonicalString("claim_policy_id",record.claim_policy_id,claim_policy_id) ||
      !SWV5S5_CanonicalUInt("claim_policy_version",record.claim_policy_version,claim_policy_version)) return false;
   // permit_digest is accepted only after the complete frozen Permit (including
   // Risk, normalized units, Margin and Basket-risk authorities) was recomputed.
   // The claimed snapshot digest is likewise recomputed by the frozen durable
   // record helper before it can enter this payload.
   canonical=version+permit_field+f+scope+fence+state+revision+claim_id+lease+claimed_at+
      snapshot+clock_id+clock_authority+clock_sequence+claim_policy_id+claim_policy_version;
   if(!SWV5S5_CanonicalString("durable_record_digest",durable,f)) return false;
   canonical+=f;
   return true;
}

class SWV5S5_ReferenceSubmissionStore
{
private:
   SWV5S5_FakeTransactionalStore m_store;
   SWV5S5_SubmissionAuthorityRecord m_record;
   bool m_initialized;

   bool BuildRow(const SWV5S5_SubmissionAuthorityRecord &record,const ulong store_revision,
                 SWV5S5_ReferenceDomainRow &row) const
   {
      string canonical,scope_digest,fence_digest,payload_digest;
      if(!SWV5S5_ReferenceCanonicalSubmissionRecord(record,canonical,scope_digest,fence_digest) ||
         !SWV5S5_ReferenceCanonicalPayloadDigest(SWV5S5_REF_DOMAIN_SUBMISSION,canonical,payload_digest)) return false;
      ZeroMemory(row); row.domain=SWV5S5_REF_DOMAIN_SUBMISSION;
      row.persistence_namespace_digest=scope_digest; row.store_revision=store_revision;
      row.authority_fence_digest=fence_digest; row.payload=canonical; row.payload_digest=payload_digest;
      return true;
   }

public:
   SWV5S5_ReferenceSubmissionStore(void):m_initialized(false) { ZeroMemory(m_record); }

   bool Initialize(const SWV5S5_SubmissionAuthorityRecord &record)
   {
      if(m_initialized || record.state!=SWV5S5_COMMITTED_NOT_INVOKED || record.authority_revision==0) return false;
      if(!SWV5S5_ReferencePermitValidAt(record.permit,record.permit.reserved_at,
         "REFERENCE-PERMIT-CLOCK",SWV5_TIME_AUTHORITY_BROKER_SERVER,record.authority_revision)) return false;
      SWV5S5_ReferenceDomainRow row;
      if(!BuildRow(record,1,row) || !m_store.Seed(row)) return false;
      m_record=record; m_initialized=true; return true;
   }

   bool TryClaimInvocation(const SWV5S5_InvocationClaimCommand &operation_command,
                           const SWV5S5_InvocationClaimTransition &prepared,
                           const SWV5S5_ReferenceFaultPoint fault,
                           SWV5S5_InvocationClaimResult &authoritative_result,
                           SWV5S5_ReferenceTransactionResult &transaction_result)
   {
      ZeroMemory(authoritative_result); SWV5S5_InitContractVersion(authoritative_result.contract_version);
      if(!m_initialized) return false;
      SWV5S5_ReferenceDomainRow current_row,proposed_row;
      string current_canonical,current_scope,current_fence,current_command_digest,current_record_digest;
      string expected_canonical,expected_scope,expected_fence,proposed_canonical,proposed_scope,proposed_fence;
      SWV5S5_InvocationClaimCommand command=operation_command;
      SWV5S5_SubmissionAuthorityRecord exact_next=m_record;
      exact_next.state=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED;
      exact_next.authority_revision=m_record.authority_revision+1;
      exact_next.invocation_claim_id=operation_command.claim_id;
      exact_next.claim_ownership_lease=operation_command.current_ownership_lease;
      exact_next.claimed_at=operation_command.claim_clock.observed_at;
      exact_next.claim_clock_id=operation_command.claim_clock.clock_id;
      exact_next.claim_clock_authority=operation_command.claim_clock.clock_authority;
      exact_next.claim_clock_sequence=operation_command.claim_clock.clock_sequence;
      exact_next.admission_snapshot=operation_command.admission_proof.snapshot;
      exact_next.admission_snapshot_digest=operation_command.admission_proof.snapshot.snapshot_digest;
      exact_next.claim_policy_id=operation_command.claim_policy_id;
      exact_next.claim_policy_version=operation_command.claim_policy_version;
      if(!SWV5S5_DeriveDurableSubmissionAuthorityDigest(exact_next,exact_next.durable_record_digest)) return false;
      if(!m_store.Load(SWV5S5_REF_DOMAIN_SUBMISSION,current_row) ||
         !SWV5S5_ReferenceCanonicalSubmissionRecord(m_record,current_canonical,current_scope,current_fence) ||
         current_canonical!=current_row.payload || current_scope!=current_row.persistence_namespace_digest ||
         current_fence!=current_row.authority_fence_digest ||
         !SWV5S5_ReferenceCanonicalSubmissionRecord(command.expected_authority_record,
                                                     expected_canonical,expected_scope,expected_fence) ||
         expected_canonical!=current_canonical || expected_scope!=current_scope || expected_fence!=current_fence ||
         !SWV5S5_ReferencePermitValidAt(m_record.permit,operation_command.claim_clock.observed_at,
                                        operation_command.claim_clock.clock_id,
                                        operation_command.claim_clock.clock_authority,
                                        operation_command.claim_clock.clock_sequence) ||
         !SWV5S5_DeriveDurableSubmissionAuthorityDigest(command.expected_authority_record,current_record_digest) ||
         command.expected_authority_record.durable_record_digest!=current_record_digest ||
         current_record_digest!=m_record.durable_record_digest ||
         command.expected_authority_revision!=m_record.authority_revision ||
         command.expected_authority_digest!=m_record.durable_record_digest ||
         !SWV5S5_DeriveClaimCommandDigest(command,current_command_digest) ||
         operation_command.command_digest!=current_command_digest ||
         !prepared.transition_eligible || prepared.disposition!=SWV5S5_CLAIM_TRANSITION_ELIGIBLE ||
         prepared.proposed_next_record.state!=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED ||
         prepared.proposed_next_record.authority_revision!=m_record.authority_revision+1 ||
         prepared.proposed_next_record.invocation_claim_id!=operation_command.claim_id ||
         prepared.proposed_next_record.claim_clock_id!=operation_command.claim_clock.clock_id ||
         prepared.proposed_next_record.claim_clock_authority!=operation_command.claim_clock.clock_authority ||
         prepared.proposed_next_record.claim_clock_sequence!=operation_command.claim_clock.clock_sequence ||
         prepared.proposed_next_record.claimed_at!=operation_command.claim_clock.observed_at ||
         !SWV5S5_ReferenceCanonicalSubmissionRecord(exact_next,expected_canonical,expected_scope,expected_fence) ||
         !SWV5S5_ReferenceCanonicalSubmissionRecord(prepared.proposed_next_record,
                                                     proposed_canonical,proposed_scope,proposed_fence) ||
         proposed_canonical!=expected_canonical || proposed_scope!=expected_scope || proposed_fence!=expected_fence ||
         !BuildRow(prepared.proposed_next_record,current_row.store_revision+1,proposed_row))
      {
         authoritative_result.disposition=SWV5S5_CLAIM_INVALID;
         authoritative_result.reason_code="D1_COMPLETE_CLAIM_OPERATION_INVALID";
         return false;
      }
      const bool committed=m_store.CompareAndSet(SWV5S5_REF_DOMAIN_SUBMISSION,current_scope,
         current_row.store_revision,current_row.payload_digest,current_row.authority_fence_digest,
         proposed_row,fault,transaction_result);
      if(transaction_result.durable_state_matches_proposal)
         m_record=prepared.proposed_next_record;
      if(!committed || !transaction_result.this_transaction_won)
      {
         authoritative_result.disposition=(transaction_result.disposition==SWV5S5_REF_COMMIT_OUTCOME_UNCERTAIN ?
            SWV5S5_CLAIM_ALREADY_CLAIMED : SWV5S5_CLAIM_CONFLICT);
         authoritative_result.claim_granted_now=false;
         authoritative_result.resulting_authority_record=m_record;
         authoritative_result.reason_code="D1_CAS_DID_NOT_PROVE_CURRENT_EVENT_WINNER";
         return false;
      }
      authoritative_result.disposition=SWV5S5_CLAIM_GRANTED_NOW;
      authoritative_result.claim_granted_now=true;
      authoritative_result.resulting_authority_record=m_record;
      authoritative_result.reason_code="D1_CURRENT_EVENT_CAS_WINNER";
      if(!SWV5S5_ValidateAuthoritativeClaimResult(prepared,authoritative_result))
      {
         authoritative_result.claim_granted_now=false;
         authoritative_result.disposition=SWV5S5_CLAIM_INVALID;
         authoritative_result.reason_code="D1_FROZEN_AUTHORITATIVE_RESULT_VALIDATION_FAILED";
         return false;
      }
      return true;
   }

   bool Load(SWV5S5_SubmissionAuthorityRecord &record) const
   {
      if(!m_initialized) return false;
      SWV5S5_ReferenceDomainRow row; string canonical,scope,fence;
      if(!m_store.Load(SWV5S5_REF_DOMAIN_SUBMISSION,row) ||
         !SWV5S5_ReferenceCanonicalSubmissionRecord(m_record,canonical,scope,fence) ||
         canonical!=row.payload || scope!=row.persistence_namespace_digest || fence!=row.authority_fence_digest) return false;
      record=m_record; return true;
   }

   bool InjectPayloadWithoutDigest(const string payload)
   { return m_store.InjectStoredPayloadWithoutDigest(SWV5S5_REF_DOMAIN_SUBMISSION,payload); }
};

#endif
