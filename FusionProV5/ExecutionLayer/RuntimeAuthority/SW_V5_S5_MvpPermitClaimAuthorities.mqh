#ifndef SW_V5_S5_MVP_PERMIT_CLAIM_AUTHORITIES_MQH
#define SW_V5_S5_MVP_PERMIT_CLAIM_AUTHORITIES_MQH

// Physical Submission Permit and Invocation Claim authorities for the locked
// Demo MVP. CLAIM_GRANTED_NOW is event-local and is never serialized.

#include "SW_V5_S5_MvpDemoAuthorityProviders.mqh"

const string SWV5S5_MVP_DOMAIN_SUBMISSION="MVP_SUBMISSION_AUTHORITY";
const string SWV5S5_MVP_DOMAIN_OWNERSHIP="MVP_OWNERSHIP_LEASE";
const string SWV5S5_MVP_SUBMISSION_KEY="ACTIVE_JOURNAL";
const string SWV5S5_MVP_OWNERSHIP_KEY="CURRENT_LEASE";

bool SWV5S5_MvpSubmissionPayload(const SWV5S5_SubmissionAuthorityRecord &record,string &payload)
{
   string permit_field,state_field,revision_field,claim_field,digest_field;
   if(!SWV5S5_CanonicalString("permit_digest",record.permit.permit_digest,permit_field) ||
      !SWV5S5_CanonicalInt("state",record.state,state_field) ||
      !SWV5S5_CanonicalUInt("authority_revision",record.authority_revision,revision_field) ||
      !SWV5S5_CanonicalString("invocation_claim_id",record.invocation_claim_id,claim_field) ||
      !SWV5S5_CanonicalString("durable_record_digest",record.durable_record_digest,digest_field)) return false;
   payload=permit_field+state_field+revision_field+claim_field+digest_field+"|CLAIM_ID="+record.invocation_claim_id;
   return true;
}

class SWV5S5_MvpLeasePublicationAuthority
{
public:
   bool Publish(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_InstanceLease &lease,
                const ulong expected_physical_revision,const string expected_physical_store_revision,
                const string expected_projection_digest,const int expected_state,
                const datetime updated_at,SWV5S5_MvpAuthorityRow &committed)
   {
      SWV5S5_LeaseLivenessAuthorityView view;
      view.lease=lease;
      if(!SWV5S5_DeriveLeaseProjection(view)) return false;
      string payload;
      if(!SWV5S5_CanonicalString("lease_projection",view.projection_digest,payload)) return false;
      return store.CompareAndSet(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,
         expected_physical_revision,expected_physical_store_revision,expected_projection_digest,expected_state,
         expected_physical_revision+1,(int)lease.status,view.projection_digest,payload,updated_at,committed);
   }
};

class SWV5S5_MvpSubmissionPermitAuthority : public ISWV5S5SubmissionPermitAuthority
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
   SWV5S5_PermitPreparationResult m_staged;
   bool m_has_staged;

public:
   SWV5S5_MvpSubmissionPermitAuthority(void) { m_has_staged=false; }

   bool Configure(const string relative_path,const string namespace_digest)
   {
      m_has_staged=false;
      return m_store.Open(relative_path,namespace_digest);
   }

   bool StagePrepared(const SWV5S5_PermitPreparationResult &prepared)
   {
      string digest;
      if(prepared.disposition!=SWV5S5_PERMIT_PROPOSAL_VALID ||
         prepared.proposed_record.state!=SWV5S5_COMMITTED_NOT_INVOKED ||
         prepared.proposed_record.authority_revision!=1 ||
         !SWV5S5_DeriveDurableSubmissionAuthorityDigest(prepared.proposed_record,digest) ||
         digest!=prepared.proposed_record.durable_record_digest) return false;
      m_staged=prepared; m_has_staged=true;
      return true;
   }

   virtual bool TryCommitPermit(const SWV5S5_PermitPreparationCommand &command,
                                const SWV5S5_SubmissionAuthorityIndexEntry &expected_index[],
                                SWV5S5_PermitPreparationResult &authoritative_result)
   {
      ZeroMemory(authoritative_result); SWV5S5_InitContractVersion(authoritative_result.contract_version);
      string command_digest,index_digest,permit_digest,record_digest,payload;
      if(!m_has_staged || !SWV5S5_DerivePermitPreparationCommandDigest(command,command_digest) ||
         command_digest!=command.command_digest || !SWV5S5_DeriveSubmissionIndexDigest(expected_index,index_digest) ||
         index_digest!=command.expected_index_digest ||
         !SWV5S5_DerivePermitDigest(command.proposed_permit,permit_digest) ||
         permit_digest!=command.proposed_permit.permit_digest ||
         m_staged.proposed_record.permit.permit_digest!=permit_digest ||
         !SWV5S5_DeriveDurableSubmissionAuthorityDigest(m_staged.proposed_record,record_digest) ||
         record_digest!=m_staged.proposed_record.durable_record_digest ||
         !SWV5S5_MvpSubmissionPayload(m_staged.proposed_record,payload))
      { authoritative_result.disposition=SWV5S5_PERMIT_INVALID; authoritative_result.reason_code="PHYSICAL_PERMIT_INPUT_INVALID"; return false; }

      SWV5S5_MvpAuthorityRow current,committed; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_SUBMISSION,SWV5S5_MVP_SUBMISSION_KEY,current,found))
      { authoritative_result.disposition=SWV5S5_PERMIT_INVALID; authoritative_result.reason_code="PHYSICAL_PERMIT_STORE_READ_FAILED"; return false; }
      if(found)
      {
         authoritative_result=m_staged;
         if(current.payload_digest==record_digest && current.payload==payload &&
            current.state==(int)SWV5S5_COMMITTED_NOT_INVOKED)
         {
            authoritative_result.disposition=SWV5S5_PERMIT_EXISTING_IDENTICAL;
            authoritative_result.reason_code="PHYSICAL_PERMIT_EXISTING_IDENTICAL";
            m_has_staged=false;
            return true;
         }
         authoritative_result.disposition=(current.state==(int)SWV5S5_COMMITTED_NOT_INVOKED ||
            current.state==(int)SWV5S5_INVOCATION_CLAIMED_UNRESOLVED ?
            SWV5S5_PERMIT_LOGICAL_REQUEST_UNRESOLVED : SWV5S5_PERMIT_CONFLICT);
         authoritative_result.reason_code="PHYSICAL_PERMIT_COMPETING_OR_CONFLICTING_JOURNAL";
         return false;
      }
      if(command.expected_index_revision!=0 || ArraySize(expected_index)!=0)
      { authoritative_result.disposition=SWV5S5_PERMIT_STALE_REVISION; authoritative_result.reason_code="PHYSICAL_PERMIT_EXPECTED_INDEX_NOT_EMPTY"; return false; }
      if(!m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_SUBMISSION,SWV5S5_MVP_SUBMISSION_KEY,
         0,"","",0,1,(int)SWV5S5_COMMITTED_NOT_INVOKED,record_digest,payload,
         command.proposed_permit.reserved_at,committed))
      { authoritative_result.disposition=SWV5S5_PERMIT_STALE_REVISION; authoritative_result.reason_code="PHYSICAL_PERMIT_CAS_FAILED"; return false; }
      authoritative_result=m_staged;
      authoritative_result.disposition=SWV5S5_PERMIT_COMMITTED;
      authoritative_result.reason_code="PHYSICAL_PERMIT_COMMITTED";
      m_has_staged=false;
      return true;
   }
};

struct SWV5S5_MvpReloadedClaim
{
   bool found;
   SWV5S5_SubmissionAuthorityState state;
   ulong authority_revision;
   string durable_record_digest;
   string invocation_claim_id;
   bool claim_granted_now;
};

class SWV5S5_MvpInvocationClaimAuthority : public ISWV5S5InvocationClaimAuthority
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
   SWV5S5_InvocationClaimTransition m_staged;
   bool m_has_staged;

public:
   SWV5S5_MvpInvocationClaimAuthority(void) { m_has_staged=false; }

   bool Configure(const string relative_path,const string namespace_digest)
   {
      m_has_staged=false;
      return m_store.Open(relative_path,namespace_digest);
   }

   bool StagePrepared(const SWV5S5_InvocationClaimTransition &prepared)
   {
      string digest;
      if(!prepared.transition_eligible || prepared.disposition!=SWV5S5_CLAIM_TRANSITION_ELIGIBLE ||
         prepared.proposed_next_record.state!=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED ||
         !SWV5S5_DeriveDurableSubmissionAuthorityDigest(prepared.proposed_next_record,digest) ||
         digest!=prepared.proposed_next_record.durable_record_digest) return false;
      m_staged=prepared; m_has_staged=true;
      return true;
   }

   virtual bool TryClaimInvocation(const SWV5S5_InvocationClaimCommand &command,
                                   SWV5S5_InvocationClaimResult &authoritative_result)
   {
      ZeroMemory(authoritative_result); SWV5S5_InitContractVersion(authoritative_result.contract_version);
      authoritative_result.claim_granted_now=false;
      string command_digest,claim_id,expected_digest,next_digest,expected_payload,next_payload;
      SWV5S5_InvocationClaimCommand candidate=command;
      if(!m_has_staged || !SWV5S5_DeriveClaimId(candidate,claim_id) || claim_id!=candidate.claim_id ||
         !SWV5S5_DeriveClaimCommandDigest(candidate,command_digest) || command_digest!=candidate.command_digest ||
         !SWV5S5_DeriveDurableSubmissionAuthorityDigest(candidate.expected_authority_record,expected_digest) ||
         expected_digest!=candidate.expected_authority_digest ||
         !SWV5S5_DeriveDurableSubmissionAuthorityDigest(m_staged.proposed_next_record,next_digest) ||
         next_digest!=m_staged.proposed_next_record.durable_record_digest ||
         !SWV5S5_MvpSubmissionPayload(candidate.expected_authority_record,expected_payload) ||
         !SWV5S5_MvpSubmissionPayload(m_staged.proposed_next_record,next_payload))
      { authoritative_result.disposition=SWV5S5_CLAIM_INVALID; authoritative_result.reason_code="PHYSICAL_CLAIM_INPUT_INVALID"; return false; }

      SWV5S5_MvpAuthorityRow current,guard,committed; bool found=false,guard_found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_SUBMISSION,SWV5S5_MVP_SUBMISSION_KEY,current,found) || !found ||
         !m_store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,guard,guard_found) || !guard_found)
      { authoritative_result.disposition=SWV5S5_CLAIM_INVALID; authoritative_result.reason_code="PHYSICAL_CLAIM_AUTHORITY_MISSING"; return false; }
      SWV5S5_LeaseLivenessAuthorityView lease_view; lease_view.lease=candidate.current_ownership_lease;
      if(!SWV5S5_DeriveLeaseProjection(lease_view) || guard.payload_digest!=lease_view.projection_digest ||
         candidate.current_ownership_lease.expires_at<=candidate.claim_clock.observed_at ||
         candidate.current_ownership_lease.heartbeat_clock_sequence>candidate.claim_clock.clock_sequence)
      { authoritative_result.disposition=SWV5S5_CLAIM_STALE_OWNER; authoritative_result.reason_code="PHYSICAL_CLAIM_LEASE_GUARD_INVALID"; return false; }
      if(current.logical_revision!=candidate.expected_authority_revision ||
         current.payload_digest!=candidate.expected_authority_digest || current.payload!=expected_payload ||
         current.state!=(int)SWV5S5_COMMITTED_NOT_INVOKED)
      { authoritative_result.disposition=SWV5S5_CLAIM_ALREADY_CLAIMED; authoritative_result.reason_code="PHYSICAL_CLAIM_STALE_OR_ALREADY_CLAIMED"; return false; }
      if(!m_store.CompareAndSetWithGuard(SWV5S5_MVP_DOMAIN_SUBMISSION,SWV5S5_MVP_SUBMISSION_KEY,
         current.logical_revision,current.store_revision,current.payload_digest,current.state,
         current.logical_revision+1,(int)SWV5S5_INVOCATION_CLAIMED_UNRESOLVED,next_digest,next_payload,
         candidate.claim_clock.observed_at,
         SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,
         guard.logical_revision,guard.store_revision,guard.payload_digest,guard.state,committed))
      { authoritative_result.disposition=SWV5S5_CLAIM_ALREADY_CLAIMED; authoritative_result.reason_code="PHYSICAL_CLAIM_CAS_LOST"; return false; }
      authoritative_result.disposition=SWV5S5_CLAIM_GRANTED_NOW;
      authoritative_result.claim_granted_now=true;
      authoritative_result.resulting_authority_record=m_staged.proposed_next_record;
      authoritative_result.reason_code="PHYSICAL_CLAIM_GRANTED_THIS_COMMIT_ONLY";
      m_has_staged=false;
      return SWV5S5_ValidateAuthoritativeClaimResult(m_staged,authoritative_result);
   }

   bool ReloadClaim(SWV5S5_MvpReloadedClaim &reloaded)
   {
      ZeroMemory(reloaded);
      SWV5S5_MvpAuthorityRow row; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_SUBMISSION,SWV5S5_MVP_SUBMISSION_KEY,row,found)) return false;
      reloaded.found=found;
      if(!found) return true;
      reloaded.state=(SWV5S5_SubmissionAuthorityState)row.state;
      reloaded.authority_revision=row.logical_revision;
      reloaded.durable_record_digest=row.payload_digest;
      reloaded.claim_granted_now=false;
      if(reloaded.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED)
      {
         const string marker="|CLAIM_ID=";
         const int marker_at=StringFind(row.payload,marker);
         if(marker_at>=0)
         {
            const int value_at=marker_at+StringLen(marker);
            reloaded.invocation_claim_id=StringSubstr(row.payload,value_at);
         }
      }
      return reloaded.state!=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED || reloaded.invocation_claim_id!="";
   }
};

#endif // SW_V5_S5_MVP_PERMIT_CLAIM_AUTHORITIES_MQH
