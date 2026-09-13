#ifndef SW_V5_S5_MVP_PERMIT_CLAIM_AUTHORITIES_MQH
#define SW_V5_S5_MVP_PERMIT_CLAIM_AUTHORITIES_MQH

// Physical Submission Permit and Invocation Claim authorities for the locked
// Demo MVP. CLAIM_GRANTED_NOW is event-local and is never serialized.

#include "SW_V5_S5_MvpDemoAuthorityProviders.mqh"

const string SWV5S5_MVP_DOMAIN_SUBMISSION="MVP_SUBMISSION_AUTHORITY";
const string SWV5S5_MVP_DOMAIN_SUBMISSION_INDEX="MVP_SUBMISSION_AUTHORITY_INDEX";
const string SWV5S5_MVP_DOMAIN_OWNERSHIP="MVP_OWNERSHIP_LEASE";
const string SWV5S5_MVP_SUBMISSION_INDEX_KEY="CURRENT";
const string SWV5S5_MVP_OWNERSHIP_KEY="CURRENT_LEASE";
const string SWV5S5_MVP_SUBMISSION_RECORD_KEY_DOMAIN="SWV5-S5-MVP-SUBMISSION-RECORD-KEY-V1";
const string SWV5S5_MVP_SUBMISSION_INDEX_FORMAT="SWV5-S5-MVP-SUBMISSION-INDEX-V1";

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

bool SWV5S5_MvpSubmissionRecordIdentity(const SWV5S5_SubmissionAuthorityRecord &record,
                                        string &correlation_id,string &attempt_id)
{
   correlation_id=record.permit.request_identity.request_id.correlation_id;
   attempt_id=record.permit.unique_attempt_id;
   return SWV5S5_IsDigest64Lower(correlation_id) && SWV5S5_IsDigest64Lower(attempt_id) &&
      attempt_id==record.permit.request_identity.request_id.attempt_id &&
      SWV5S5_IsDigest64Lower(record.permit.permit_id) &&
      SWV5S5_IsDigest64Lower(record.permit.permit_digest);
}

bool SWV5S5_MvpSubmissionRecordKey(const string correlation_id,const string attempt_id,string &record_key)
{
   string body="",f;
   if(!SWV5S5_IsDigest64Lower(correlation_id) || !SWV5S5_IsDigest64Lower(attempt_id) ||
      !SWV5S5_CanonicalString("correlation_id",correlation_id,f)) return false;
   body+=f;
   if(!SWV5S5_CanonicalString("attempt_id",attempt_id,f)) return false;
   body+=f;
   return SWV5S5_DomainDigest(SWV5S5_MVP_SUBMISSION_RECORD_KEY_DOMAIN,body,record_key);
}

bool SWV5S5_MvpSubmissionIndexEntryFromRecord(const SWV5S5_SubmissionAuthorityRecord &record,
                                              SWV5S5_SubmissionAuthorityIndexEntry &entry)
{
   ZeroMemory(entry);
   if(!SWV5S5_MvpSubmissionRecordIdentity(record,entry.logical_correlation_id,entry.attempt_id) ||
      record.authority_revision==0 || !SWV5S5_IsDigest64Lower(record.durable_record_digest)) return false;
   entry.permit_id=record.permit.permit_id;
   entry.permit_digest=record.permit.permit_digest;
   entry.state=record.state;
   entry.authority_revision=record.authority_revision;
   entry.durable_record_digest=record.durable_record_digest;
   return true;
}

bool SWV5S5_MvpSubmissionIndexEntryEqual(const SWV5S5_SubmissionAuthorityIndexEntry &left,
                                         const SWV5S5_SubmissionAuthorityIndexEntry &right)
{
   return left.logical_correlation_id==right.logical_correlation_id && left.attempt_id==right.attempt_id &&
      left.permit_id==right.permit_id && left.permit_digest==right.permit_digest && left.state==right.state &&
      left.authority_revision==right.authority_revision &&
      left.durable_record_digest==right.durable_record_digest;
}

int SWV5S5_MvpFindSubmissionIndexEntry(const SWV5S5_SubmissionAuthorityIndexEntry &entries[],
                                       const string correlation_id,const string attempt_id)
{
   for(int i=0;i<ArraySize(entries);i++)
      if(entries[i].logical_correlation_id==correlation_id && entries[i].attempt_id==attempt_id) return i;
   return -1;
}

bool SWV5S5_MvpSerializeSubmissionIndex(const SWV5S5_SubmissionAuthorityIndexEntry &entries[],
                                       string &payload,string &digest)
{
   payload=SWV5S5_MVP_SUBMISSION_INDEX_FORMAT+"|"+IntegerToString(ArraySize(entries));
   if(!SWV5S5_DeriveSubmissionIndexDigest(entries,digest)) return false;
   for(int i=0;i<ArraySize(entries);i++)
   {
      if(!SWV5S5_IsDigest64Lower(entries[i].logical_correlation_id) ||
         !SWV5S5_IsDigest64Lower(entries[i].attempt_id) || !SWV5S5_IsDigest64Lower(entries[i].permit_id) ||
         !SWV5S5_IsDigest64Lower(entries[i].permit_digest) ||
         !SWV5S5_IsDigest64Lower(entries[i].durable_record_digest) || entries[i].authority_revision==0) return false;
      payload+="\n"+entries[i].logical_correlation_id+"|"+entries[i].attempt_id+"|"+
         entries[i].permit_id+"|"+entries[i].permit_digest+"|"+IntegerToString((int)entries[i].state)+"|"+
         IntegerToString((long)entries[i].authority_revision)+"|"+entries[i].durable_record_digest;
   }
   return true;
}

bool SWV5S5_MvpDeserializeSubmissionIndex(const string payload,
                                         SWV5S5_SubmissionAuthorityIndexEntry &entries[],string &digest)
{
   ArrayResize(entries,0); digest="";
   string lines[]; const ushort newline=10;
   const int line_count=StringSplit(payload,newline,lines);
   if(line_count<=0) return false;
   string header[]; const ushort separator=124;
   if(StringSplit(lines[0],separator,header)!=2 || header[0]!=SWV5S5_MVP_SUBMISSION_INDEX_FORMAT) return false;
   const int expected=(int)StringToInteger(header[1]);
   if(expected<0 || IntegerToString(expected)!=header[1] || line_count!=expected+1) return false;
   ArrayResize(entries,expected);
   for(int i=0;i<expected;i++)
   {
      string fields[];
      if(StringSplit(lines[i+1],separator,fields)!=7) return false;
      const int state=(int)StringToInteger(fields[4]);
      const long revision=StringToInteger(fields[5]);
      if(!SWV5S5_IsDigest64Lower(fields[0]) || !SWV5S5_IsDigest64Lower(fields[1]) ||
         !SWV5S5_IsDigest64Lower(fields[2]) || !SWV5S5_IsDigest64Lower(fields[3]) ||
         !SWV5S5_IsDigest64Lower(fields[6]) || IntegerToString(state)!=fields[4] || revision<=0 ||
         IntegerToString(revision)!=fields[5]) return false;
      entries[i].logical_correlation_id=fields[0]; entries[i].attempt_id=fields[1];
      entries[i].permit_id=fields[2]; entries[i].permit_digest=fields[3];
      entries[i].state=(SWV5S5_SubmissionAuthorityState)state;
      entries[i].authority_revision=(ulong)revision; entries[i].durable_record_digest=fields[6];
   }
   string canonical_payload,canonical_digest;
   if(!SWV5S5_MvpSerializeSubmissionIndex(entries,canonical_payload,canonical_digest) ||
      canonical_payload!=payload) return false;
   digest=canonical_digest;
   return true;
}

bool SWV5S5_MvpLoadSubmissionIndex(SWV5S5_MvpSqliteAuthorityStore &store,
                                   SWV5S5_SubmissionAuthorityIndexEntry &entries[],
                                   SWV5S5_MvpAuthorityRow &index_row,bool &found)
{
   ArrayResize(entries,0); ZeroMemory(index_row); found=false;
   if(!store.ReadRow(SWV5S5_MVP_DOMAIN_SUBMISSION_INDEX,SWV5S5_MVP_SUBMISSION_INDEX_KEY,index_row,found)) return false;
   if(!found) return true;
   string digest;
   return index_row.logical_revision>0 && index_row.state==1 &&
      SWV5S5_MvpDeserializeSubmissionIndex(index_row.payload,entries,digest) &&
      index_row.payload_digest==digest;
}

bool SWV5S5_MvpInsertSubmissionIndexEntry(const SWV5S5_SubmissionAuthorityIndexEntry &current[],
                                         const SWV5S5_SubmissionAuthorityIndexEntry &addition,
                                         SWV5S5_SubmissionAuthorityIndexEntry &proposed[])
{
   const int count=ArraySize(current);
   if(SWV5S5_MvpFindSubmissionIndexEntry(current,addition.logical_correlation_id,addition.attempt_id)>=0) return false;
   int insert_at=count;
   for(int i=0;i<count;i++)
      if(StringCompare(addition.logical_correlation_id,current[i].logical_correlation_id)<0 ||
         (addition.logical_correlation_id==current[i].logical_correlation_id &&
          StringCompare(addition.attempt_id,current[i].attempt_id)<0)) { insert_at=i; break; }
   ArrayResize(proposed,count+1);
   for(int i=0;i<insert_at;i++) proposed[i]=current[i];
   proposed[insert_at]=addition;
   for(int i=insert_at;i<count;i++) proposed[i+1]=current[i];
   string digest;
   return SWV5S5_DeriveSubmissionIndexDigest(proposed,digest);
}

void SWV5S5_MvpNormalizeUnclaimedAbsence(SWV5S5_SubmissionAuthorityRecord &record)
{
   if(record.state!=SWV5S5_COMMITTED_NOT_INVOKED) return;
   record.invocation_claim_id="";
   record.claim_clock_id="";
   record.admission_snapshot.snapshot_digest="";
   record.admission_snapshot_digest="";
   record.claim_policy_id="";
}

bool SWV5S5_MvpPreparePermitCommit(const SWV5_ContractValidationContext &context,
                                   const SWV5S5_SubmissionAuthorityIndexEntry &entries[],
                                   const SWV5S5_PermitPreparationCommand &command,
                                   const SWV5S5_ProducerTrustRecord &current_trust,
                                   const SWV5S5_ProducerTrustAnchor &trust_anchor,
                                   const SWV5S5_ProducerTrustScope &trust_scope,
                                   const SWV5S5_IngressEnvelope &accepted_ingress,
                                   SWV5S5_PermitPreparationResult &result)
{
   SWV5S5_PermitPreparationCommand executable_command=command;
   SWV5S5_ProducerTrustRecord executable_trust=current_trust;
   // MQL ZeroMemory represents absent strings as null. The frozen contract
   // requires semantic absence (empty) for current, non-superseded trust.
   executable_trust.superseding_record_id="";
   executable_command.proposed_permit.producer_trust.superseding_record_id="";
   if(SWV5S5_PreparePermitCommit(context,entries,executable_command,executable_trust,
                                 trust_anchor,trust_scope,accepted_ingress,result)) return true;
   // Every validation predicate precedes this exact self-digest failure. Finish
   // only the MQL representation of the already-validated unclaimed proposal.
   if(result.disposition!=SWV5S5_PERMIT_INVALID || result.reason_code!="PERMIT_RECORD_DIGEST_FAILED" ||
      result.proposed_record.state!=SWV5S5_COMMITTED_NOT_INVOKED ||
      result.proposed_record.authority_revision!=1) return false;
   SWV5S5_MvpNormalizeUnclaimedAbsence(result.proposed_record);
   if(!SWV5S5_DeriveDurableSubmissionAuthorityDigest(result.proposed_record,
                                                      result.proposed_record.durable_record_digest)) return false;
   result.disposition=SWV5S5_PERMIT_PROPOSAL_VALID;
   result.reason_code="PERMIT_PROPOSAL_VALID_NO_COMMIT";
   return true;
}

void SWV5S5_MvpPrepareMutation(const string domain_key,const string record_key,
                               const SWV5S5_MvpAuthorityRow &expected,const bool expected_found,
                               const ulong proposed_revision,const int proposed_state,
                               const string proposed_digest,const string proposed_payload,
                               const datetime updated_at,SWV5S5_MvpAuthorityMutation &mutation)
{
   ZeroMemory(mutation); mutation.domain_key=domain_key; mutation.record_key=record_key;
   if(expected_found)
   {
      mutation.expected_revision=expected.logical_revision;
      mutation.expected_store_revision=expected.store_revision;
      mutation.expected_payload_digest=expected.payload_digest;
      mutation.expected_state=expected.state;
   }
   else
   {
      mutation.expected_store_revision="";
      mutation.expected_payload_digest="";
   }
   mutation.proposed_revision=proposed_revision; mutation.proposed_state=proposed_state;
   mutation.proposed_payload_digest=proposed_digest; mutation.proposed_payload=proposed_payload;
   mutation.updated_at=updated_at;
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

      string correlation_id,attempt_id,record_key;
      SWV5S5_SubmissionAuthorityIndexEntry staged_entry;
      SWV5S5_SubmissionAuthorityIndexEntry current_entries[],proposed_entries[];
      SWV5S5_MvpAuthorityRow index_row,record_row,committed_record,committed_index;
      bool index_found=false,record_found=false;
      if(!SWV5S5_MvpSubmissionRecordIdentity(m_staged.proposed_record,correlation_id,attempt_id) ||
         !SWV5S5_MvpSubmissionRecordKey(correlation_id,attempt_id,record_key) ||
         !SWV5S5_MvpSubmissionIndexEntryFromRecord(m_staged.proposed_record,staged_entry) ||
         !SWV5S5_MvpLoadSubmissionIndex(m_store,current_entries,index_row,index_found) ||
         !m_store.ReadRow(SWV5S5_MVP_DOMAIN_SUBMISSION,record_key,record_row,record_found))
      { authoritative_result.disposition=SWV5S5_PERMIT_INVALID; authoritative_result.reason_code="PHYSICAL_PERMIT_STORE_READ_FAILED"; return false; }
      const int exact=SWV5S5_MvpFindSubmissionIndexEntry(current_entries,correlation_id,attempt_id);
      if(exact>=0)
      {
         authoritative_result=m_staged;
         if(!record_found || record_row.logical_revision!=current_entries[exact].authority_revision ||
            record_row.state!=(int)current_entries[exact].state ||
            record_row.payload_digest!=current_entries[exact].durable_record_digest)
         {
            authoritative_result.disposition=SWV5S5_PERMIT_INVALID;
            authoritative_result.reason_code="PHYSICAL_PERMIT_INDEX_RECORD_INTEGRITY_FAILURE";
            return false;
         }
         if(current_entries[exact].permit_id==m_staged.proposed_record.permit.permit_id &&
            current_entries[exact].permit_digest==m_staged.proposed_record.permit.permit_digest)
         {
            authoritative_result.disposition=SWV5S5_PERMIT_EXISTING_IDENTICAL;
            authoritative_result.reason_code="PHYSICAL_PERMIT_EXISTING_IDENTICAL";
            m_has_staged=false;
            return true;
         }
         authoritative_result.disposition=SWV5S5_PERMIT_CONFLICT;
         authoritative_result.reason_code="PHYSICAL_PERMIT_ATTEMPT_IDENTITY_CONFLICT";
         return false;
      }
      if((index_found && (index_row.logical_revision!=command.expected_index_revision ||
                          index_row.payload_digest!=command.expected_index_digest)) ||
         (!index_found && (command.expected_index_revision!=0 || ArraySize(expected_index)!=0)))
      { authoritative_result.disposition=SWV5S5_PERMIT_STALE_REVISION; authoritative_result.reason_code="PHYSICAL_PERMIT_STALE_INDEX"; return false; }
      for(int i=0;i<ArraySize(current_entries);i++)
         if(current_entries[i].logical_correlation_id==correlation_id &&
            (current_entries[i].state==SWV5S5_COMMITTED_NOT_INVOKED ||
             current_entries[i].state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED))
         { authoritative_result.disposition=SWV5S5_PERMIT_LOGICAL_REQUEST_UNRESOLVED;
           authoritative_result.reason_code="PHYSICAL_PERMIT_COMPETING_UNRESOLVED_ATTEMPT"; return false; }
      if(record_found || !SWV5S5_MvpInsertSubmissionIndexEntry(current_entries,staged_entry,proposed_entries))
      { authoritative_result.disposition=SWV5S5_PERMIT_CONFLICT; authoritative_result.reason_code="PHYSICAL_PERMIT_RECORD_KEY_CONFLICT"; return false; }
      string proposed_index_payload,proposed_index_digest;
      if(!SWV5S5_MvpSerializeSubmissionIndex(proposed_entries,proposed_index_payload,proposed_index_digest))
      { authoritative_result.disposition=SWV5S5_PERMIT_INVALID; authoritative_result.reason_code="PHYSICAL_PERMIT_INDEX_INVALID"; return false; }
      SWV5S5_MvpAuthorityMutation record_mutation,index_mutation;
      SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_SUBMISSION,record_key,record_row,false,1,
         (int)SWV5S5_COMMITTED_NOT_INVOKED,record_digest,payload,command.proposed_permit.reserved_at,record_mutation);
      SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_SUBMISSION_INDEX,SWV5S5_MVP_SUBMISSION_INDEX_KEY,
         index_row,index_found,command.expected_index_revision+1,1,proposed_index_digest,
         proposed_index_payload,command.proposed_permit.reserved_at,index_mutation);
      if(!m_store.CompareAndSetPair(record_mutation,index_mutation,committed_record,committed_index))
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
   string logical_correlation_id;
   string attempt_id;
   string permit_id;
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
         m_staged.proposed_next_record.permit.permit_id!=candidate.expected_authority_record.permit.permit_id ||
         m_staged.proposed_next_record.permit.permit_digest!=candidate.expected_authority_record.permit.permit_digest ||
         m_staged.proposed_next_record.authority_revision!=candidate.expected_authority_revision+1 ||
         m_staged.proposed_next_record.invocation_claim_id!=claim_id ||
         !SWV5S5_MvpSubmissionPayload(candidate.expected_authority_record,expected_payload) ||
         !SWV5S5_MvpSubmissionPayload(m_staged.proposed_next_record,next_payload))
      { authoritative_result.disposition=SWV5S5_CLAIM_INVALID; authoritative_result.reason_code="PHYSICAL_CLAIM_INPUT_INVALID"; return false; }

      string correlation_id,attempt_id,record_key;
      SWV5S5_SubmissionAuthorityIndexEntry current_entries[],proposed_entries[],next_entry,expected_entry;
      SWV5S5_MvpAuthorityRow index_row,current,guard,committed_record,committed_index;
      bool index_found=false,found=false,guard_found=false;
      if(!SWV5S5_MvpSubmissionRecordIdentity(candidate.expected_authority_record,correlation_id,attempt_id) ||
         !SWV5S5_MvpSubmissionRecordKey(correlation_id,attempt_id,record_key) ||
         !SWV5S5_MvpSubmissionIndexEntryFromRecord(candidate.expected_authority_record,expected_entry) ||
         !SWV5S5_MvpSubmissionIndexEntryFromRecord(m_staged.proposed_next_record,next_entry) ||
         !SWV5S5_MvpLoadSubmissionIndex(m_store,current_entries,index_row,index_found) || !index_found ||
         !m_store.ReadRow(SWV5S5_MVP_DOMAIN_SUBMISSION,record_key,current,found) || !found ||
         !m_store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,guard,guard_found) || !guard_found)
      { authoritative_result.disposition=SWV5S5_CLAIM_INVALID; authoritative_result.reason_code="PHYSICAL_CLAIM_AUTHORITY_MISSING"; return false; }
      const int exact=SWV5S5_MvpFindSubmissionIndexEntry(current_entries,correlation_id,attempt_id);
      if(exact<0 || !SWV5S5_MvpSubmissionIndexEntryEqual(current_entries[exact],expected_entry))
      { authoritative_result.disposition=SWV5S5_CLAIM_ALREADY_CLAIMED; authoritative_result.reason_code="PHYSICAL_CLAIM_INDEX_STALE"; return false; }
      SWV5S5_LeaseLivenessAuthorityView lease_view; lease_view.lease=candidate.current_ownership_lease;
      if(!SWV5S5_DeriveLeaseProjection(lease_view) || guard.payload_digest!=lease_view.projection_digest ||
         candidate.current_ownership_lease.expires_at<=candidate.claim_clock.observed_at ||
         candidate.current_ownership_lease.heartbeat_clock_sequence>candidate.claim_clock.clock_sequence)
      { authoritative_result.disposition=SWV5S5_CLAIM_STALE_OWNER; authoritative_result.reason_code="PHYSICAL_CLAIM_LEASE_GUARD_INVALID"; return false; }
      if(current.logical_revision!=candidate.expected_authority_revision ||
         current.payload_digest!=candidate.expected_authority_digest || current.payload!=expected_payload ||
         current.state!=(int)SWV5S5_COMMITTED_NOT_INVOKED)
      { authoritative_result.disposition=SWV5S5_CLAIM_ALREADY_CLAIMED; authoritative_result.reason_code="PHYSICAL_CLAIM_STALE_OR_ALREADY_CLAIMED"; return false; }
      ArrayResize(proposed_entries,ArraySize(current_entries));
      for(int i=0;i<ArraySize(current_entries);i++) proposed_entries[i]=current_entries[i];
      proposed_entries[exact]=next_entry;
      string proposed_index_payload,proposed_index_digest;
      if(!SWV5S5_MvpSerializeSubmissionIndex(proposed_entries,proposed_index_payload,proposed_index_digest))
      { authoritative_result.disposition=SWV5S5_CLAIM_INVALID; authoritative_result.reason_code="PHYSICAL_CLAIM_INDEX_INVALID"; return false; }
      SWV5S5_MvpAuthorityMutation record_mutation,index_mutation;
      SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_SUBMISSION,record_key,current,true,
         current.logical_revision+1,(int)SWV5S5_INVOCATION_CLAIMED_UNRESOLVED,next_digest,next_payload,
         candidate.claim_clock.observed_at,record_mutation);
      SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_SUBMISSION_INDEX,SWV5S5_MVP_SUBMISSION_INDEX_KEY,index_row,true,
         index_row.logical_revision+1,1,proposed_index_digest,proposed_index_payload,
         candidate.claim_clock.observed_at,index_mutation);
      if(!m_store.CompareAndSetPairWithGuard(record_mutation,index_mutation,guard,committed_record,committed_index))
      { authoritative_result.disposition=SWV5S5_CLAIM_ALREADY_CLAIMED; authoritative_result.reason_code="PHYSICAL_CLAIM_CAS_LOST"; return false; }
      authoritative_result.disposition=SWV5S5_CLAIM_GRANTED_NOW;
      authoritative_result.claim_granted_now=true;
      authoritative_result.resulting_authority_record=m_staged.proposed_next_record;
      authoritative_result.reason_code="PHYSICAL_CLAIM_GRANTED_THIS_COMMIT_ONLY";
      m_has_staged=false;
      return SWV5S5_ValidateAuthoritativeClaimResult(m_staged,authoritative_result);
   }

   bool ReloadClaim(const string correlation_id,const string attempt_id,SWV5S5_MvpReloadedClaim &reloaded)
   {
      ZeroMemory(reloaded);
      string record_key;
      SWV5S5_SubmissionAuthorityIndexEntry entries[];
      SWV5S5_MvpAuthorityRow index_row,row; bool index_found=false,found=false;
      if(!SWV5S5_MvpSubmissionRecordKey(correlation_id,attempt_id,record_key) ||
         !SWV5S5_MvpLoadSubmissionIndex(m_store,entries,index_row,index_found)) return false;
      const int exact=SWV5S5_MvpFindSubmissionIndexEntry(entries,correlation_id,attempt_id);
      if(exact<0) return true;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_SUBMISSION,record_key,row,found) || !found ||
         row.logical_revision!=entries[exact].authority_revision || row.state!=(int)entries[exact].state ||
         row.payload_digest!=entries[exact].durable_record_digest) return false;
      reloaded.found=true; reloaded.logical_correlation_id=correlation_id; reloaded.attempt_id=attempt_id;
      reloaded.permit_id=entries[exact].permit_id;
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

   bool ReloadUnresolvedClaims(SWV5S5_MvpReloadedClaim &reloaded[])
   {
      ArrayResize(reloaded,0);
      SWV5S5_SubmissionAuthorityIndexEntry entries[]; SWV5S5_MvpAuthorityRow index_row;
      bool index_found=false;
      if(!SWV5S5_MvpLoadSubmissionIndex(m_store,entries,index_row,index_found)) return false;
      for(int i=0;i<ArraySize(entries);i++)
      {
         if(entries[i].state!=SWV5S5_COMMITTED_NOT_INVOKED &&
            entries[i].state!=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED) continue;
         const int next=ArraySize(reloaded); ArrayResize(reloaded,next+1);
         if(!ReloadClaim(entries[i].logical_correlation_id,entries[i].attempt_id,reloaded[next]) ||
            !reloaded[next].found) return false;
      }
      return true;
   }

   bool ReloadClaim(SWV5S5_MvpReloadedClaim &reloaded)
   {
      SWV5S5_MvpReloadedClaim unresolved[];
      if(!ReloadUnresolvedClaims(unresolved)) return false;
      ZeroMemory(reloaded);
      if(ArraySize(unresolved)==0) return true;
      if(ArraySize(unresolved)!=1) return false;
      reloaded=unresolved[0]; return true;
   }
};

#endif // SW_V5_S5_MVP_PERMIT_CLAIM_AUTHORITIES_MQH
