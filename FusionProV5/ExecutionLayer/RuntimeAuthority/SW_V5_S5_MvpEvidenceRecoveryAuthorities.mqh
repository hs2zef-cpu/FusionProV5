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

bool SWV5S5_MvpCallbackMatchesSubmission(const ulong order_ticket,const ulong deal_ticket,
                                         const ulong request_id_session_local,
                                         const ulong sync_order_ticket,const ulong sync_deal_ticket,
                                         const ulong sync_request_id)
{
   const bool exact_order=(order_ticket!=0 && sync_order_ticket!=0 && order_ticket==sync_order_ticket);
   const bool exact_deal=(deal_ticket!=0 && sync_deal_ticket!=0 && deal_ticket==sync_deal_ticket);
   const bool exact_request=(request_id_session_local!=0 && sync_request_id!=0 &&
                             request_id_session_local==sync_request_id);
   if(!exact_order && !exact_deal && !exact_request) return false;
   return !((order_ticket!=0 && sync_order_ticket!=0 && order_ticket!=sync_order_ticket) ||
            (deal_ticket!=0 && sync_deal_ticket!=0 && deal_ticket!=sync_deal_ticket) ||
            (request_id_session_local!=0 && sync_request_id!=0 && request_id_session_local!=sync_request_id));
}

void SWV5S5_MvpSummarizeExecutionRows(const bool &row_success[],const bool operation_success,
                                      const bool requested_complete,const uint reported_total,
                                      uint &materialized_row_count,uint &row_read_failures,
                                      bool &enumeration_complete)
{
   materialized_row_count=0; row_read_failures=0;
   for(int i=0;i<ArraySize(row_success);i++)
   { if(row_success[i]) materialized_row_count++; else row_read_failures++; }
   if(reported_total>(uint)ArraySize(row_success))
      row_read_failures+=reported_total-(uint)ArraySize(row_success);
   enumeration_complete=operation_success && requested_complete && row_read_failures==0 &&
      materialized_row_count==reported_total;
}

struct SWV5S5_MvpExecutionObservationStatus
{
   bool found;
   bool operation_success;
   bool enumeration_complete;
   uint reported_total;
   uint materialized_row_count;
   uint row_read_failures;
   ulong sequence;
   string read_path_identity;
   string authority_identity;
   string sequence_authority;
};

bool SWV5S5_MvpCanonicalScalar(const string body,const string name,const string type_token,string &value)
{
   value=""; const string marker=name+":"+type_token+":";
   const int at=StringFind(body,marker); if(at<0) return false;
   const int length_start=at+StringLen(marker),separator=StringFind(body,":",length_start);
   if(separator<0) return false;
   const int length=(int)StringToInteger(StringSubstr(body,length_start,separator-length_start));
   if(length<0 || separator+1+length>StringLen(body)) return false;
   value=StringSubstr(body,separator+1,length); return true;
}

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
   ulong m_sync_order_ticket,m_sync_deal_ticket,m_sync_request_id;

   bool BindingMatches(const SWV5S5_F_AdapterCallbackEvidence &evidence) const
   {
      return m_has_binding && evidence.request_correlation_id==m_binding.request_identity.request_id.correlation_id &&
         evidence.attempt_id==m_binding.request_identity.request_id.attempt_id &&
         evidence.invocation_claim_id==m_binding.invocation_claim_id &&
         evidence.claim_record_digest==m_binding.claim_record_digest &&
         evidence.profile_digest==m_binding.profile.profile_digest;
   }

public:
   SWV5S5_MvpBrokerEvidenceStore(void)
   { m_has_binding=false; m_sync_order_ticket=0; m_sync_deal_ticket=0; m_sync_request_id=0; }

   bool Configure(const string relative_path,const string namespace_digest)
   { m_has_binding=false; m_sync_order_ticket=0; m_sync_deal_ticket=0; m_sync_request_id=0;
     ArrayResize(m_callbacks,0); return m_store.Open(relative_path,namespace_digest); }

   bool BindAuthoritativeOperation(const SWV5_ContractValidationContext &context,
                                   const SWV5S5_F_ReconciliationBinding &binding)
   {
      if(!SWV5S5_F_IsBindingValid(context,binding)) return false;
      m_binding=binding; m_has_binding=true;
      SWV5S5_MvpAuthorityRow row; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_BROKER_SYNC,SWV5S5_MvpEvidenceKey(binding),row,found)) return false;
      if(found)
      {
         const string order_marker="|ORDER=",deal_marker="|DEAL=",request_marker="|REQUEST=";
         int order_at=StringFind(row.payload,order_marker),deal_at=StringFind(row.payload,deal_marker),
             request_at=StringFind(row.payload,request_marker);
         if(order_at<0 || deal_at<0 || request_at<0) return false;
         m_sync_order_ticket=(ulong)StringToInteger(StringSubstr(row.payload,order_at+StringLen(order_marker),
            deal_at-order_at-StringLen(order_marker)));
         m_sync_deal_ticket=(ulong)StringToInteger(StringSubstr(row.payload,deal_at+StringLen(deal_marker),
            request_at-deal_at-StringLen(deal_marker)));
         m_sync_request_id=(ulong)StringToInteger(StringSubstr(row.payload,request_at+StringLen(request_marker)));
      }
      return true;
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
      payload+="|ORDER="+IntegerToString((long)result.order_ticket)+
         "|DEAL="+IntegerToString((long)result.deal_ticket)+
         "|REQUEST="+IntegerToString((long)result.request_id_session_local);
      SWV5S5_MvpAuthorityRow current,committed; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_BROKER_SYNC,SWV5S5_MvpEvidenceKey(m_binding),current,found)) return false;
      if(found) return current.payload_digest==digest && current.payload==payload;
      const bool persisted=m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_BROKER_SYNC,SWV5S5_MvpEvidenceKey(m_binding),
         0,"","",0,1,(int)result.classification,digest,payload,
         command.authoritative_claim.resulting_authority_record.claimed_at,committed);
      if(persisted)
      { m_sync_order_ticket=result.order_ticket; m_sync_deal_ticket=result.deal_ticket;
        m_sync_request_id=result.request_id_session_local; }
      return persisted;
   }

   virtual bool PersistCallbackEvidence(const SWV5S5_F_AdapterCallbackEvidence &evidence)
   {
      string digest,payload; if(!BindingMatches(evidence) || evidence.callback_sequence==0 ||
         !SWV5S5_MvpCallbackMatchesSubmission(evidence.order_ticket,evidence.deal_ticket,
            evidence.request_id_session_local,m_sync_order_ticket,m_sync_deal_ticket,m_sync_request_id) ||
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
      if(!m_has_binding || request_magic!=SWV5_RUNTIME_STRATEGY_MAGIC) return false;
      // Position identity alone and Magic/comment are never correlation authority.
      if(!SWV5S5_MvpCallbackMatchesSubmission(order_ticket,deal_ticket,request_id_session_local,
         m_sync_order_ticket,m_sync_deal_ticket,m_sync_request_id)) return false;
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
      uint materialized_row_count=0,row_read_failures=0; bool enumeration_complete=false;
      SWV5S5_MvpSummarizeExecutionRows(row_success,operation_success,complete,reported_total,
                                       materialized_row_count,row_read_failures,
                                       enumeration_complete);
      if(reported_total<(uint)ArraySize(requests)) return false;
      ArrayResize(m_requests,ArraySize(requests)); ArrayResize(m_row_success,ArraySize(row_success));
      for(int copy_index=0;copy_index<ArraySize(requests);copy_index++)
      { m_requests[copy_index]=requests[copy_index]; m_row_success[copy_index]=row_success[copy_index]; }
      m_operation_success=operation_success; m_complete=enumeration_complete; m_reported_total=reported_total;
      m_sequence=sequence; m_connection_generation=connection_generation;
      m_restart_generation=restart_generation; m_observed_at=observed_at; m_staged=true;
      string body="",f,digest;
      if(!SWV5S5_CanonicalUInt("sequence",sequence,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("reported_total",reported_total,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("materialized_row_count",materialized_row_count,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("row_read_failures",row_read_failures,f)) return false; body+=f;
      if(!SWV5S5_CanonicalBool("operation_success",operation_success,f)) return false; body+=f;
      if(!SWV5S5_CanonicalBool("enumeration_complete",enumeration_complete,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("read_path_identity",SWV5S5_MVP_EXECUTION_READ_PATH,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("authority_identity","SQLITE_EXECUTION_AUTHORITY:"+m_store.NamespaceDigest(),f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("sequence_authority",SWV5S5_MVP_EXECUTION_SEQUENCE_AUTHORITY,f)) return false; body+=f;
      for(int i=0;i<ArraySize(requests);i++)
      {
         string row="",indexed,success_field;
         if(!SWV5S5_CanonicalBool("row_read_success",row_success[i],success_field)) return false;
         row+=success_field;
         if(row_success[i])
         { string canonical; if(!SWV5S5_CanonicalPendingRequest(requests[i],canonical)) return false; row+=canonical; }
         if(!SWV5S5_CanonicalIndexed("pending",(ulong)i,row,indexed)) return false; body+=indexed;
      }
      if(!SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_EXECUTION_PENDING,body,digest)) return false;
      SWV5S5_MvpAuthorityRow current,committed; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_EXECUTION_PENDING,"CURRENT",current,found)) return false;
      return m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_EXECUTION_PENDING,"CURRENT",
         (found ? current.logical_revision : 0),(found ? current.store_revision : ""),
         (found ? current.payload_digest : ""),(found ? current.state : 0),
         (found ? current.logical_revision+1 : 1),1,digest,body,observed_at,committed);
   }

   bool LoadPersistedObservationStatus(SWV5S5_MvpExecutionObservationStatus &status)
   {
      ZeroMemory(status); SWV5S5_MvpAuthorityRow row; bool found=false; string value;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_EXECUTION_PENDING,"CURRENT",row,found)) return false;
      if(!found) return true;
      status.found=true;
      if(!SWV5S5_MvpCanonicalScalar(row.payload,"operation_success","b",value) ||
         (value!="0" && value!="1")) return false;
      status.operation_success=(value=="1");
      if(!SWV5S5_MvpCanonicalScalar(row.payload,"enumeration_complete","b",value) ||
         (value!="0" && value!="1")) return false;
      status.enumeration_complete=(value=="1");
      if(!SWV5S5_MvpCanonicalScalar(row.payload,"reported_total","u",value)) return false;
      status.reported_total=(uint)StringToInteger(value);
      if(!SWV5S5_MvpCanonicalScalar(row.payload,"materialized_row_count","u",value)) return false;
      status.materialized_row_count=(uint)StringToInteger(value);
      if(!SWV5S5_MvpCanonicalScalar(row.payload,"row_read_failures","u",value)) return false;
      status.row_read_failures=(uint)StringToInteger(value);
      if(!SWV5S5_MvpCanonicalScalar(row.payload,"sequence","u",value)) return false;
      status.sequence=(ulong)StringToInteger(value);
      if(!SWV5S5_MvpCanonicalScalar(row.payload,"read_path_identity","s",status.read_path_identity) ||
         !SWV5S5_MvpCanonicalScalar(row.payload,"authority_identity","s",status.authority_identity) ||
         !SWV5S5_MvpCanonicalScalar(row.payload,"sequence_authority","s",status.sequence_authority)) return false;
      return status.sequence>0 && status.reported_total==status.materialized_row_count+
         status.row_read_failures && (!status.enumeration_complete ||
         (status.operation_success && status.row_read_failures==0 &&
          status.materialized_row_count==status.reported_total));
   }

   virtual bool ObservePendingRequest(const SWV5S5_F_ReconciliationBinding &binding,
                                      SWV5S5_F_ExecutionPendingSnapshot &snapshot)
   {
      ZeroMemory(snapshot); if(!m_staged) return false;
      SWV5S5_MvpAuthorityRow source; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_EXECUTION_PENDING,"CURRENT",source,found) || !found) return false;
      return SWV5S5_F_AdapterBuildExecutionPendingSnapshot(binding,m_requests,m_row_success,
         m_operation_success,m_complete,SWV5S5_MVP_EXECUTION_READ_PATH,
         "SQLITE_EXECUTION_AUTHORITY:"+m_store.NamespaceDigest(),SWV5S5_MVP_EXECUTION_SEQUENCE_AUTHORITY,
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

bool SWV5S5_MvpSubmissionStateTerminal(const SWV5S5_SubmissionAuthorityState state)
{
   return state==SWV5S5_AUTHORITATIVE_SIDE_EFFECT_CONFIRMED ||
      state==SWV5S5_AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED ||
      state==SWV5S5_AUTHORITATIVE_REJECTED || state==SWV5S5_CONFLICT_MANUAL_REQUIRED;
}

class SWV5S5_MvpSubmissionTerminalAuthority
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
public:
   bool Configure(const string relative_path,const string namespace_digest)
   { return m_store.Open(relative_path,namespace_digest); }

   bool TryFinalizeFromPersistedReconciliation(const SWV5S5_F_ReconciliationPublication &publication,
                                               const SWV5S5_SubmissionAuthorityRecord &expected_claimed,
                                               SWV5S5_SubmissionAuthorityRecord &terminal_record,
                                               SWV5S5_MvpAuthorityRow &committed_record)
   {
      ZeroMemory(terminal_record); ZeroMemory(committed_record);
      string result_digest,publication_digest,correlation_id,attempt_id,record_key;
      if(expected_claimed.state!=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED ||
         expected_claimed.authority_revision==18446744073709551615 ||
         !SWV5S5_F_DeriveResultDigest(publication.result,result_digest) ||
         publication.result.result_digest!=result_digest ||
         !SWV5S5_F_DeriveReconciliationPublicationDigest(publication,publication_digest) ||
         publication.publication_digest!=publication_digest || publication.result.retry_allowed ||
         publication.result.residual_is_submission_authority ||
         !SWV5S5_MvpSubmissionStateTerminal(publication.result.proposed_submission_state) ||
         publication.binding.submission_state!=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED ||
         publication.binding.permit_id!=expected_claimed.permit.permit_id ||
         publication.binding.invocation_claim_id!=expected_claimed.invocation_claim_id ||
         publication.binding.claim_record_digest!=expected_claimed.durable_record_digest ||
         !SWV5S5_EqualRequestIdentity(publication.binding.request_identity,
                                      expected_claimed.permit.request_identity) ||
         !SWV5S5_MvpSubmissionRecordIdentity(expected_claimed,correlation_id,attempt_id) ||
         !SWV5S5_MvpSubmissionRecordKey(correlation_id,attempt_id,record_key)) return false;
      string expected_digest,expected_payload;
      if(!SWV5S5_DeriveDurableSubmissionAuthorityDigest(expected_claimed,expected_digest) ||
         expected_digest!=expected_claimed.durable_record_digest ||
         !SWV5S5_MvpSubmissionPayload(expected_claimed,expected_payload)) return false;
      terminal_record=expected_claimed;
      terminal_record.state=publication.result.proposed_submission_state;
      terminal_record.authority_revision=expected_claimed.authority_revision+1;
      if(!SWV5S5_DeriveDurableSubmissionAuthorityDigest(terminal_record,terminal_record.durable_record_digest)) return false;
      string terminal_payload;
      if(!SWV5S5_MvpSubmissionPayload(terminal_record,terminal_payload)) return false;

      SWV5S5_SubmissionAuthorityIndexEntry current_entries[],terminal_entry;
      SWV5S5_MvpAuthorityRow index_row,current_record,reconciliation_row,committed_index;
      bool index_found=false,record_found=false,reconciliation_found=false;
      if(!SWV5S5_MvpLoadSubmissionIndex(m_store,current_entries,index_row,index_found) || !index_found ||
         !m_store.ReadRow(SWV5S5_MVP_DOMAIN_SUBMISSION,record_key,current_record,record_found) || !record_found ||
         current_record.logical_revision!=expected_claimed.authority_revision ||
         current_record.payload_digest!=expected_claimed.durable_record_digest ||
         current_record.payload!=expected_payload || current_record.state!=(int)expected_claimed.state ||
         !m_store.ReadRow(SWV5S5_MVP_DOMAIN_RECONCILIATION,SWV5S5_MvpEvidenceKey(publication.binding),
                          reconciliation_row,reconciliation_found) || !reconciliation_found ||
         reconciliation_row.logical_revision!=publication.proposed_reconciliation_revision ||
         reconciliation_row.payload_digest!=publication.result.result_digest ||
         reconciliation_row.state!=(int)publication.result.state ||
         !SWV5S5_MvpSubmissionIndexEntryFromRecord(terminal_record,terminal_entry)) return false;
      const int exact=SWV5S5_MvpFindSubmissionIndexEntry(current_entries,correlation_id,attempt_id);
      if(exact<0 || current_entries[exact].authority_revision!=expected_claimed.authority_revision ||
         current_entries[exact].durable_record_digest!=expected_claimed.durable_record_digest ||
         current_entries[exact].state!=expected_claimed.state) return false;
      SWV5S5_SubmissionAuthorityIndexEntry proposed_entries[];
      ArrayResize(proposed_entries,ArraySize(current_entries));
      for(int i=0;i<ArraySize(current_entries);i++) proposed_entries[i]=current_entries[i];
      proposed_entries[exact]=terminal_entry;
      string index_payload,index_digest;
      if(!SWV5S5_MvpSerializeSubmissionIndex(proposed_entries,index_payload,index_digest)) return false;
      SWV5S5_MvpAuthorityMutation record_mutation,index_mutation;
      SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_SUBMISSION,record_key,current_record,true,
         terminal_record.authority_revision,(int)terminal_record.state,terminal_record.durable_record_digest,
         terminal_payload,publication.current_publication_lease.heartbeat_at,record_mutation);
      SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_SUBMISSION_INDEX,SWV5S5_MVP_SUBMISSION_INDEX_KEY,index_row,true,
         index_row.logical_revision+1,1,index_digest,index_payload,
         publication.current_publication_lease.heartbeat_at,index_mutation);
      return m_store.CompareAndSetPairWithGuard(record_mutation,index_mutation,reconciliation_row,
                                                committed_record,committed_index);
   }

   bool TryFinalizeReloadedFromPersistedReconciliation(
      const SWV5S5_F_ReconciliationPublication &publication,
      SWV5S5_SubmissionAuthorityRecord &terminal_record,
      SWV5S5_MvpAuthorityRow &committed_record)
   {
      ZeroMemory(terminal_record); ZeroMemory(committed_record);
      const string correlation_id=publication.binding.request_identity.request_id.correlation_id;
      const string attempt_id=publication.binding.request_identity.request_id.attempt_id;
      SWV5S5_SubmissionAuthorityRecord claimed; bool found=false;
      if(!SWV5S5_MvpLoadSubmissionAuthority(m_store,correlation_id,attempt_id,claimed,found) || !found ||
         claimed.state!=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED ||
         claimed.invocation_claim_id!=publication.binding.invocation_claim_id ||
         claimed.durable_record_digest!=publication.binding.claim_record_digest) return false;
      return TryFinalizeFromPersistedReconciliation(publication,claimed,terminal_record,committed_record);
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
                            const SWV5S5_MvpReloadedClaim &reloaded_claim,
                            const SWV5S5_F_ReconciliationInput &candidate_input,
                           SWV5S5_F_ReconciliationPublication &publication,
                           SWV5S5_MvpReconciliationPublicationAuthority &authority,
                           SWV5S5_MvpRecoveryResult &result)
   {
      ZeroMemory(result);
      const bool claim_valid=reloaded_claim.found && !reloaded_claim.claim_granted_now &&
         reloaded_claim.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED &&
         candidate_input.binding.submission_state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED &&
         reloaded_claim.invocation_claim_id==candidate_input.binding.invocation_claim_id &&
         reloaded_claim.durable_record_digest==candidate_input.binding.claim_record_digest &&
         reloaded_claim.authority_revision>0;
      result.store_valid=claim_valid; result.claim_reloaded=claim_valid;
      result.claim_grant_reconstructed=false; result.submission_calls=0;
      if(!claim_valid) return false;
      if(!SWV5S5_F_AdapterEvaluate(context,candidate_input,result.reconciliation)) return false;
      result.evaluated=true; publication.result=result.reconciliation;
      if(!SWV5S5_F_DeriveReconciliationPublicationDigest(publication,publication.publication_digest)) return false;
      result.published=SWV5S5_F_AdapterPublishResult(context,publication,authority,result.committed_store_revision);
      return result.published && result.submission_calls==0 && !result.claim_grant_reconstructed;
   }
};

#endif // SW_V5_S5_MVP_EVIDENCE_RECOVERY_AUTHORITIES_MQH
