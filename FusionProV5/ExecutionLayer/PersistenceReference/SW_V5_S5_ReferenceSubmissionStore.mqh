#ifndef SW_V5_S5_REFERENCE_SUBMISSION_STORE_MQH
#define SW_V5_S5_REFERENCE_SUBMISSION_STORE_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS

#include "SW_V5_S5_FakeTransactionalStore.mqh"

struct SWV5S5_ReferenceSubmissionRecord
{
   string request_id;
   string attempt_id;
   string permit_digest;
   string ownership_fence_digest;
   ulong authority_revision;
   SWV5S5_SubmissionAuthorityState state;
};

struct SWV5S5_ReferenceClaimResult
{
   SWV5S5_ReferenceTransactionDisposition transaction_disposition;
   SWV5S5_ClaimDisposition claim_disposition;
   bool claim_granted_now;
   ulong durable_revision;
};

class SWV5S5_ReferenceSubmissionStore
{
private:
   SWV5S5_ReferenceSubmissionRecord m_records[];

   int FindAttempt(const string attempt_id) const
   {
      for(int i=0;i<ArraySize(m_records);i++)
         if(m_records[i].attempt_id==attempt_id)
            return i;
      return -1;
   }

public:
   bool CommitPermit(const SWV5S5_ReferenceSubmissionRecord &record)
   {
      if(record.request_id=="" || record.attempt_id=="" || record.permit_digest=="" ||
         record.ownership_fence_digest=="" || record.authority_revision==0 ||
         record.state!=SWV5S5_COMMITTED_NOT_INVOKED || FindAttempt(record.attempt_id)>=0)
         return false;
      int n=ArraySize(m_records);
      ArrayResize(m_records,n+1);
      m_records[n]=record;
      return true;
   }

   bool Claim(const string attempt_id,const ulong expected_revision,
              const string expected_permit_digest,const string current_fence_digest,
              const bool commit_outcome_uncertain,SWV5S5_ReferenceClaimResult &result)
   {
      ZeroMemory(result);
      int index=FindAttempt(attempt_id);
      if(index<0)
      {
         result.transaction_disposition=SWV5S5_REF_EXPECTED_STATE_MISMATCH;
         return false;
      }
      if(m_records[index].state!=SWV5S5_COMMITTED_NOT_INVOKED)
      {
         result.transaction_disposition=SWV5S5_REF_CONFLICT;
         result.claim_disposition=SWV5S5_CLAIM_ALREADY_CLAIMED;
         result.durable_revision=m_records[index].authority_revision;
         return false;
      }
      if(m_records[index].authority_revision!=expected_revision ||
         m_records[index].permit_digest!=expected_permit_digest ||
         m_records[index].ownership_fence_digest!=current_fence_digest)
      {
         result.transaction_disposition=SWV5S5_REF_EXPECTED_STATE_MISMATCH;
         return false;
      }
      m_records[index].state=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED;
      m_records[index].authority_revision++;
      result.durable_revision=m_records[index].authority_revision;
      if(commit_outcome_uncertain)
      {
         result.transaction_disposition=SWV5S5_REF_COMMIT_OUTCOME_UNCERTAIN;
         result.claim_disposition=SWV5S5_CLAIM_ALREADY_CLAIMED;
         result.claim_granted_now=false;
         return false;
      }
      result.transaction_disposition=SWV5S5_REF_COMMITTED;
      result.claim_disposition=SWV5S5_CLAIM_GRANTED_NOW;
      result.claim_granted_now=true;
      return true;
   }

   bool Load(const string attempt_id,SWV5S5_ReferenceSubmissionRecord &record) const
   {
      int index=FindAttempt(attempt_id);
      if(index<0)
         return false;
      record=m_records[index];
      return true;
   }
};

#endif
