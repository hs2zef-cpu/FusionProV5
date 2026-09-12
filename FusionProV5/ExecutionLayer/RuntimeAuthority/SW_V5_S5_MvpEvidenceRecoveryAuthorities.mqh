#ifndef SW_V5_S5_MVP_EVIDENCE_RECOVERY_AUTHORITIES_MQH
#define SW_V5_S5_MVP_EVIDENCE_RECOVERY_AUTHORITIES_MQH

// Durable, non-submitting evidence and recovery authorities for the locked
// Demo MVP. Broker observations and Execution pending state remain independent.

#include "SW_V5_S5_MvpPermitClaimAuthorities.mqh"
#include "../BrokerAdapter/SW_V5_S5_F_BrokerReconciliationIntegration.mqh"

const string SWV5S5_MVP_DOMAIN_BROKER_SYNC="MVP_BROKER_SYNC_EVIDENCE";
const string SWV5S5_MVP_DOMAIN_BROKER_CALLBACK="MVP_BROKER_CALLBACK_EVIDENCE";
const string SWV5S5_MVP_DOMAIN_BROKER_CALLBACK_INDEX="MVP_BROKER_CALLBACK_INDEX";
const string SWV5S5_MVP_DOMAIN_BROKER_QUERY_SEQUENCE="MVP_BROKER_QUERY_SEQUENCE";
const string SWV5S5_MVP_DOMAIN_EXECUTION_PENDING="MVP_EXECUTION_PENDING_STATE";
const string SWV5S5_MVP_DOMAIN_RECONCILIATION="MVP_RECONCILIATION_PUBLICATION";
const string SWV5S5_MVP_BROKER_READ_PATH="MT5_BROKER_READ_PATH_V1";
const string SWV5S5_MVP_EXECUTION_READ_PATH="SQLITE_EXECUTION_READ_PATH_V1";
const string SWV5S5_MVP_BROKER_SEQUENCE_AUTHORITY="BROKER_EVIDENCE_SEQUENCE_V1";
const string SWV5S5_MVP_EXECUTION_SEQUENCE_AUTHORITY="EXECUTION_STORE_SEQUENCE_V1";

string SWV5S5_MvpEvidenceKey(const SWV5S5_F_ReconciliationBinding &binding)
{
   return binding.request_identity.request_id.correlation_id+":"+
      binding.request_identity.request_id.attempt_id;
}

string SWV5S5_MvpHexString(const string value)
{
   uchar bytes[]; if(!SWV5S5_StrictUtf8(value,bytes)) return "";
   string result="";
   for(int i=0;i<ArraySize(bytes);i++) result+=StringFormat("%02x",(uint)bytes[i]);
   return result;
}

int SWV5S5_MvpHexNibble(const ushort c)
{
   if(c>='0' && c<='9') return (int)(c-'0');
   if(c>='a' && c<='f') return 10+(int)(c-'a');
   return -1;
}

bool SWV5S5_MvpUnhexString(const string encoded,string &value)
{
   value=""; const int n=StringLen(encoded); if((n%2)!=0) return false;
   uchar bytes[]; ArrayResize(bytes,n/2);
   for(int i=0;i<n;i+=2)
   { const int high=SWV5S5_MvpHexNibble((ushort)StringGetCharacter(encoded,i));
     const int low=SWV5S5_MvpHexNibble((ushort)StringGetCharacter(encoded,i+1));
     if(high<0 || low<0) return false; bytes[i/2]=(uchar)((high<<4)|low); }
   value=CharArrayToString(bytes,0,ArraySize(bytes),CP_UTF8); return true;
}

bool SWV5S5_MvpCallbackPayload(const SWV5S5_F_AdapterCallbackEvidence &evidence,string &payload)
{
   payload=SWV5S5_MvpHexString(evidence.request_correlation_id)+","+
      SWV5S5_MvpHexString(evidence.attempt_id)+","+SWV5S5_MvpHexString(evidence.invocation_claim_id)+","+
      SWV5S5_MvpHexString(evidence.claim_record_digest)+","+SWV5S5_MvpHexString(evidence.profile_digest)+","+
      IntegerToString((long)evidence.callback_sequence)+","+IntegerToString((long)evidence.observed_at)+","+
      IntegerToString((long)evidence.transaction_type)+","+IntegerToString((long)evidence.order_ticket)+","+
      IntegerToString((long)evidence.deal_ticket)+","+IntegerToString((long)evidence.position_identifier)+","+
      IntegerToString((long)evidence.position_by_identifier)+","+SWV5S5_MvpHexString(evidence.symbol)+","+
      IntegerToString((long)evidence.order_type)+","+IntegerToString((long)evidence.order_state)+","+
      IntegerToString((long)evidence.deal_type)+","+DoubleToString(evidence.price,16)+","+
      DoubleToString(evidence.volume,16)+","+IntegerToString((long)evidence.request_action)+","+
      IntegerToString((long)evidence.request_magic)+","+SWV5S5_MvpHexString(evidence.request_comment)+","+
      IntegerToString((long)evidence.result_retcode)+","+IntegerToString((long)evidence.result_retcode_external)+","+
      IntegerToString((long)evidence.request_id_session_local)+","+(evidence.final_confirmation ? "1" : "0")+","+
      (evidence.retry_allowed ? "1" : "0")+","+SWV5S5_MvpHexString(evidence.evidence_digest);
   return payload!="";
}

bool SWV5S5_MvpDecodeCallbackPayload(const string payload,SWV5S5_F_AdapterCallbackEvidence &evidence)
{
   ZeroMemory(evidence); SWV5S5_F_InitVersion(evidence.contract_version);
   string v[]; if(StringSplit(payload,(ushort)',',v)!=27) return false;
   if(!SWV5S5_MvpUnhexString(v[0],evidence.request_correlation_id) ||
      !SWV5S5_MvpUnhexString(v[1],evidence.attempt_id) ||
      !SWV5S5_MvpUnhexString(v[2],evidence.invocation_claim_id) ||
      !SWV5S5_MvpUnhexString(v[3],evidence.claim_record_digest) ||
      !SWV5S5_MvpUnhexString(v[4],evidence.profile_digest) ||
      !SWV5S5_MvpUnhexString(v[12],evidence.symbol) ||
      !SWV5S5_MvpUnhexString(v[20],evidence.request_comment) ||
      !SWV5S5_MvpUnhexString(v[26],evidence.evidence_digest)) return false;
   evidence.callback_sequence=(ulong)StringToInteger(v[5]); evidence.observed_at=(datetime)StringToInteger(v[6]);
   evidence.transaction_type=(int)StringToInteger(v[7]); evidence.order_ticket=(ulong)StringToInteger(v[8]);
   evidence.deal_ticket=(ulong)StringToInteger(v[9]); evidence.position_identifier=(ulong)StringToInteger(v[10]);
   evidence.position_by_identifier=(ulong)StringToInteger(v[11]); evidence.order_type=(int)StringToInteger(v[13]);
   evidence.order_state=(int)StringToInteger(v[14]); evidence.deal_type=(int)StringToInteger(v[15]);
   evidence.price=StringToDouble(v[16]); evidence.volume=StringToDouble(v[17]);
   evidence.request_action=(int)StringToInteger(v[18]); evidence.request_magic=(ulong)StringToInteger(v[19]);
   evidence.result_retcode=(uint)StringToInteger(v[21]); evidence.result_retcode_external=(uint)StringToInteger(v[22]);
   evidence.request_id_session_local=(ulong)StringToInteger(v[23]);
   evidence.final_confirmation=(v[24]=="1"); evidence.retry_allowed=(v[25]=="1");
   string digest; return (v[24]=="0" || v[24]=="1") && (v[25]=="0" || v[25]=="1") &&
      SWV5S5_F_DeriveCallbackDigest(evidence,digest) && digest==evidence.evidence_digest;
}

// The store persists the canonical full callback projection. Typed recovery is
// deliberately performed by the owning callback adapter from raw platform
// evidence; this class never interprets a stored callback as confirmation.
class SWV5S5_MvpBrokerEvidenceStore : public ISWV5S5FBrokerEvidenceStore
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
   SWV5S5_F_ReconciliationBinding m_binding;
   bool m_has_binding;
   SWV5S5_F_AdapterCallbackEvidence m_callbacks[];

   bool BindingMatches(const SWV5S5_F_AdapterCallbackEvidence &evidence) const
   {
      return m_has_binding && evidence.request_correlation_id==m_binding.request_identity.request_id.correlation_id &&
         evidence.attempt_id==m_binding.request_identity.request_id.attempt_id &&
         evidence.invocation_claim_id==m_binding.invocation_claim_id &&
         evidence.claim_record_digest==m_binding.claim_record_digest &&
         evidence.profile_digest==m_binding.profile.profile_digest;
   }

public:
   SWV5S5_MvpBrokerEvidenceStore(void) { m_has_binding=false; }

   bool Configure(const string relative_path,const string namespace_digest)
   { m_has_binding=false; ArrayResize(m_callbacks,0); return m_store.Open(relative_path,namespace_digest); }

   bool BindAuthoritativeOperation(const SWV5_ContractValidationContext &context,
                                   const SWV5S5_F_ReconciliationBinding &binding)
   {
      if(!SWV5S5_F_IsBindingValid(context,binding)) return false;
      m_binding=binding; m_has_binding=true; return true;
   }

   virtual bool PersistSubmissionResult(const SWV5S5_F_AdapterSubmissionCommand &command,
                                        const SWV5S5_F_AdapterSyncResult &result)
   {
      string digest,command_digest,payload="",f;
      if(!m_has_binding || !SWV5S5_F_DeriveAdapterSubmissionDigest(command,command_digest) ||
         command_digest!=command.submission_digest ||
         !SWV5S5_F_DeriveAdapterSyncResultDigest(result,digest) || digest!=result.result_digest ||
         result.claim_id!=m_binding.invocation_claim_id ||
         result.claim_record_digest!=m_binding.claim_record_digest ||
         result.final_confirmation || result.retry_allowed) return false;
      if(!SWV5S5_CanonicalString("submission_digest",command.submission_digest,f)) return false; payload+=f;
      if(!SWV5S5_CanonicalString("sync_result_digest",result.result_digest,f)) return false; payload+=f;
      if(!SWV5S5_CanonicalString("claim_id",result.claim_id,f)) return false; payload+=f;
      SWV5S5_MvpAuthorityRow current,committed; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_BROKER_SYNC,SWV5S5_MvpEvidenceKey(m_binding),current,found)) return false;
      if(found) return current.payload_digest==digest && current.payload==payload;
      return m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_BROKER_SYNC,SWV5S5_MvpEvidenceKey(m_binding),
         0,"","",0,1,(int)result.classification,digest,payload,
         command.authoritative_claim.resulting_authority_record.claimed_at,committed);
   }

   virtual bool PersistCallbackEvidence(const SWV5S5_F_AdapterCallbackEvidence &evidence)
   {
      string digest,payload; if(!BindingMatches(evidence) || evidence.callback_sequence==0 ||
         evidence.final_confirmation || evidence.retry_allowed ||
         !SWV5S5_F_DeriveCallbackDigest(evidence,digest) || digest!=evidence.evidence_digest ||
         !SWV5S5_MvpCallbackPayload(evidence,payload)) return false;
      const string binding_key=SWV5S5_MvpEvidenceKey(m_binding);
      const string row_key=binding_key+":"+IntegerToString((long)evidence.callback_sequence);
      SWV5S5_MvpAuthorityRow index,row,committed; bool index_found=false,row_found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_BROKER_CALLBACK_INDEX,binding_key,index,index_found) ||
         !m_store.ReadRow(SWV5S5_MVP_DOMAIN_BROKER_CALLBACK,row_key,row,row_found)) return false;
      if(row_found) return row.payload_digest==digest && row.payload==payload;
      const ulong expected=(index_found ? index.logical_revision : 0);
      if(evidence.callback_sequence!=expected+1) return false;
      if(!m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_BROKER_CALLBACK,row_key,0,"","",0,1,1,digest,payload,
         evidence.observed_at,committed)) return false;
      string index_body="",f,index_digest;
      if(!SWV5S5_CanonicalString("binding",binding_key,f)) return false; index_body+=f;
      if(!SWV5S5_CanonicalUInt("callback_count",evidence.callback_sequence,f)) return false; index_body+=f;
      if(!SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_BROKER_CALLBACK_INDEX,index_body,index_digest)) return false;
      if(!m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_BROKER_CALLBACK_INDEX,binding_key,
         expected,(index_found ? index.store_revision : ""),(index_found ? index.payload_digest : ""),
         (index_found ? index.state : 0),expected+1,1,index_digest,index_body,evidence.observed_at,committed)) return false;
      const int n=ArraySize(m_callbacks); ArrayResize(m_callbacks,n+1); m_callbacks[n]=evidence;
      return true;
   }

   virtual bool ResolveCallbackBinding(const ulong order_ticket,const ulong deal_ticket,
                                       const ulong position_identifier,
                                       const ulong request_id_session_local,
                                       const ulong request_magic,
                                       SWV5S5_F_ReconciliationBinding &binding)
   {
      ZeroMemory(binding);
      if(!m_has_binding || request_magic!=SWV5_RUNTIME_STRATEGY_MAGIC ||
         (order_ticket==0 && deal_ticket==0 && position_identifier==0 && request_id_session_local==0)) return false;
      binding=m_binding; return true;
   }

   virtual bool LoadCallbackEvidence(const SWV5S5_F_ReconciliationBinding &binding,
                                     SWV5S5_F_AdapterCallbackEvidence &evidence[],
                                     uint &reported_total,bool &enumeration_complete,
                                     uint &row_read_failures)
   {
      ArrayResize(evidence,0); reported_total=0; enumeration_complete=false; row_read_failures=0;
      if(!m_has_binding || SWV5S5_MvpEvidenceKey(binding)!=SWV5S5_MvpEvidenceKey(m_binding) ||
         binding.claim_record_digest!=m_binding.claim_record_digest) return false;
      SWV5S5_MvpAuthorityRow index,row; bool found=false;
      const string key=SWV5S5_MvpEvidenceKey(binding);
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_BROKER_CALLBACK_INDEX,key,index,found)) return false;
      if(!found) { enumeration_complete=true; return true; }
      reported_total=(uint)index.logical_revision;
      ArrayResize(evidence,(int)reported_total);
      for(uint i=0;i<reported_total;i++)
      {
         bool row_found=false;
         SWV5S5_F_AdapterCallbackEvidence recovered;
         if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_BROKER_CALLBACK,
            key+":"+IntegerToString((long)(i+1)),row,row_found) || !row_found ||
            !SWV5S5_MvpDecodeCallbackPayload(row.payload,recovered) || recovered.evidence_digest!=row.payload_digest ||
            !BindingMatches(recovered))
         { row_read_failures++; continue; }
         evidence[(int)i]=recovered;
      }
      enumeration_complete=(row_read_failures==0);
      return true;
   }

   virtual bool ReserveBrokerQuerySequence(const SWV5S5_F_ProfileScope &profile,
                                           ulong &owner_query_sequence)
   {
      owner_query_sequence=0;
      if(!m_has_binding || !SWV5S5_F_EqualProfile(profile,m_binding.profile)) return false;
      SWV5S5_MvpAuthorityRow current,committed; bool found=false;
      const string key=profile.profile_digest;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_BROKER_QUERY_SEQUENCE,key,current,found)) return false;
      const ulong next=(found ? current.logical_revision+1 : 1); string body="",f,digest;
      if(!SWV5S5_CanonicalUInt("sequence",next,f)) return false; body+=f;
      if(!SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_BROKER_QUERY_SEQUENCE,body,digest)) return false;
      if(!m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_BROKER_QUERY_SEQUENCE,key,
         (found ? current.logical_revision : 0),(found ? current.store_revision : ""),
         (found ? current.payload_digest : ""),(found ? current.state : 0),next,1,digest,body,
         m_binding.current_reconciliation_lease.heartbeat_at,committed)) return false;
      owner_query_sequence=next; return true;
   }
};

class SWV5S5_MvpExecutionPendingQuery : public ISWV5S5FExecutionPendingQuery
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
   SWV5_PendingRequest m_requests[];
   bool m_row_success[];
   bool m_operation_success,m_complete,m_staged;
   uint m_reported_total;
   ulong m_sequence,m_connection_generation,m_restart_generation;
   datetime m_observed_at;

public:
   SWV5S5_MvpExecutionPendingQuery(void)
   { m_operation_success=false; m_complete=false; m_staged=false; m_reported_total=0; m_sequence=0;
     m_connection_generation=0; m_restart_generation=0; m_observed_at=0; }

   bool Configure(const string relative_path,const string namespace_digest)
   { m_staged=false; ArrayResize(m_requests,0); ArrayResize(m_row_success,0); return m_store.Open(relative_path,namespace_digest); }

   bool PublishObservationSource(const SWV5_PendingRequest &requests[],const bool &row_success[],
                                 const bool operation_success,const bool complete,const uint reported_total,
                                 const ulong sequence,const ulong connection_generation,
                                 const ulong restart_generation,const datetime observed_at)
   {
      if(ArraySize(requests)!=ArraySize(row_success) || sequence==0 || connection_generation==0 ||
         restart_generation==0 || observed_at<=0) return false;
      ArrayResize(m_requests,ArraySize(requests)); ArrayResize(m_row_success,ArraySize(row_success));
      for(int copy_index=0;copy_index<ArraySize(requests);copy_index++)
      { m_requests[copy_index]=requests[copy_index]; m_row_success[copy_index]=row_success[copy_index]; }
      m_operation_success=operation_success; m_complete=complete; m_reported_total=reported_total;
      m_sequence=sequence; m_connection_generation=connection_generation;
      m_restart_generation=restart_generation; m_observed_at=observed_at; m_staged=true;
      string body="",f,digest;
      if(!SWV5S5_CanonicalUInt("sequence",sequence,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("reported_total",reported_total,f)) return false; body+=f;
      if(!SWV5S5_CanonicalBool("operation_success",operation_success,f)) return false; body+=f;
      if(!SWV5S5_CanonicalBool("complete",complete,f)) return false; body+=f;
      for(int i=0;i<ArraySize(requests);i++)
      { string row,indexed; if(!row_success[i] || !SWV5S5_CanonicalPendingRequest(requests[i],row) ||
           !SWV5S5_CanonicalIndexed("pending",(ulong)i,row,indexed)) return false; body+=indexed; }
      if(!SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_EXECUTION_PENDING,body,digest)) return false;
      SWV5S5_MvpAuthorityRow current,committed; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_EXECUTION_PENDING,"CURRENT",current,found)) return false;
      return m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_EXECUTION_PENDING,"CURRENT",
         (found ? current.logical_revision : 0),(found ? current.store_revision : ""),
         (found ? current.payload_digest : ""),(found ? current.state : 0),
         (found ? current.logical_revision+1 : 1),1,digest,body,observed_at,committed);
   }

   virtual bool ObservePendingRequest(const SWV5S5_F_ReconciliationBinding &binding,
                                      SWV5S5_F_ExecutionPendingSnapshot &snapshot)
   {
      ZeroMemory(snapshot); if(!m_staged) return false;
      SWV5S5_MvpAuthorityRow source; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_EXECUTION_PENDING,"CURRENT",source,found) || !found) return false;
      return SWV5S5_F_AdapterBuildExecutionPendingSnapshot(binding,m_requests,m_row_success,
         m_operation_success,m_complete,SWV5S5_MVP_EXECUTION_READ_PATH,
         "SQLITE_EXECUTION_AUTHORITY:"+source.store_revision,SWV5S5_MVP_EXECUTION_SEQUENCE_AUTHORITY,
         m_reported_total,m_sequence,m_connection_generation,m_restart_generation,m_observed_at,snapshot);
   }
};

bool SWV5S5_MvpReconciliationTransitionAllowed(const int prior,const int proposed)
{
   if(prior==(int)SWV5S5_F_RECONCILIATION_BLOCKED) return proposed==prior;
   if(prior==(int)SWV5S5_F_SIDE_EFFECT_POSITIVELY_CONFIRMED ||
      prior==(int)SWV5S5_F_NO_SIDE_EFFECT_CONFIRMED || prior==(int)SWV5S5_F_PARTIAL_EFFECT_CONFIRMED)
      return proposed==prior;
   return proposed>=(int)SWV5S5_F_NO_CALL && proposed<=(int)SWV5S5_F_RECONCILIATION_BLOCKED;
}

class SWV5S5_MvpReconciliationPublicationAuthority : public ISWV5S5FReconciliationPublicationAuthority
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
public:
   bool Configure(const string relative_path,const string namespace_digest)
   { return m_store.Open(relative_path,namespace_digest); }

   virtual bool TryPublishReconciliation(const SWV5S5_F_ReconciliationPublication &publication,
                                         string &committed_store_revision)
   {
      committed_store_revision=""; string digest,payload="",f;
      if(!SWV5S5_F_DeriveReconciliationPublicationDigest(publication,digest) ||
         digest!=publication.publication_digest || publication.result.retry_allowed ||
         publication.result.residual_is_submission_authority) return false;
      SWV5S5_LeaseLivenessAuthorityView lease_view; lease_view.lease=publication.current_publication_lease;
      if(!SWV5S5_DeriveLeaseProjection(lease_view)) return false;
      SWV5S5_MvpAuthorityRow current,guard,committed; bool found=false,guard_found=false;
      const string key=SWV5S5_MvpEvidenceKey(publication.binding);
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_RECONCILIATION,key,current,found) ||
         !m_store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,guard,guard_found) || !guard_found ||
         guard.payload_digest!=lease_view.projection_digest ||
         publication.proposed_reconciliation_revision!=publication.expected_reconciliation_revision+1 ||
         (found && (current.logical_revision!=publication.expected_reconciliation_revision ||
                    !SWV5S5_MvpReconciliationTransitionAllowed(current.state,(int)publication.result.state))) ||
         (!found && publication.expected_reconciliation_revision!=0)) return false;
      if(found && current.state==(int)publication.result.state && current.payload_digest==publication.result.result_digest)
      { committed_store_revision=current.store_revision; return true; }
      if(!SWV5S5_CanonicalString("publication_digest",publication.publication_digest,f)) return false; payload+=f;
      if(!SWV5S5_CanonicalString("result_digest",publication.result.result_digest,f)) return false; payload+=f;
      if(!SWV5S5_CanonicalInt("state",publication.result.state,f)) return false; payload+=f;
      if(!m_store.CompareAndSetWithGuard(SWV5S5_MVP_DOMAIN_RECONCILIATION,key,
         (found ? current.logical_revision : 0),(found ? current.store_revision : ""),
         (found ? current.payload_digest : ""),(found ? current.state : 0),
         publication.proposed_reconciliation_revision,(int)publication.result.state,
         publication.result.result_digest,payload,publication.current_publication_lease.heartbeat_at,
         SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,
         guard.logical_revision,guard.store_revision,guard.payload_digest,guard.state,committed)) return false;
      committed_store_revision=committed.store_revision; return true;
   }
};

struct SWV5S5_MvpRecoveryResult
{
   bool store_valid;
   bool claim_reloaded;
   bool claim_grant_reconstructed;
   uint submission_calls;
   bool evaluated;
   bool published;
   SWV5S5_F_ReconciliationResult reconciliation;
   string committed_store_revision;
};

class SWV5S5_MvpRecoveryHost
{
public:
   bool EvaluateAndPublish(const SWV5_ContractValidationContext &context,
                           const SWV5S5_F_ReconciliationInput &candidate_input,
                           SWV5S5_F_ReconciliationPublication &publication,
                           SWV5S5_MvpReconciliationPublicationAuthority &authority,
                           SWV5S5_MvpRecoveryResult &result)
   {
      ZeroMemory(result); result.store_valid=true; result.claim_reloaded=true;
      result.claim_grant_reconstructed=false; result.submission_calls=0;
      if(!SWV5S5_F_AdapterEvaluate(context,candidate_input,result.reconciliation)) return false;
      result.evaluated=true; publication.result=result.reconciliation;
      if(!SWV5S5_F_DeriveReconciliationPublicationDigest(publication,publication.publication_digest)) return false;
      result.published=SWV5S5_F_AdapterPublishResult(context,publication,authority,result.committed_store_revision);
      return result.published && result.submission_calls==0 && !result.claim_grant_reconstructed;
   }
};

#endif // SW_V5_S5_MVP_EVIDENCE_RECOVERY_AUTHORITIES_MQH
