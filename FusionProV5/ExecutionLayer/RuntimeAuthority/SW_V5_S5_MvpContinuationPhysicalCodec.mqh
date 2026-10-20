#ifndef SW_V5_S5_MVP_CONTINUATION_PHYSICAL_CODEC_MQH
#define SW_V5_S5_MVP_CONTINUATION_PHYSICAL_CODEC_MQH
// ATTENDED CONTINUATION ONLY / NO EXECUTION AUTHORITY / NO BROKER MUTATION.
#include "SW_V5_S5_MvpContinuationLineage.mqh"

bool SWV5S5_MvpContinuationRowExact(const SWV5S5_MvpAuthorityRow &a,const SWV5S5_MvpAuthorityRow &b)
{
   return a.domain_key==b.domain_key && a.record_key==b.record_key && a.logical_revision==b.logical_revision &&
      a.store_revision==b.store_revision && a.state==b.state && a.payload_digest==b.payload_digest &&
      a.payload==b.payload && a.updated_at==b.updated_at;
}
bool SWV5S5_MvpContinuationRowsPayload(const SWV5S5_MvpAuthorityRow &rows[],string &body)
{
   string f,n; body="";
   if(!SWV5S5_CanonicalUInt("count",(ulong)ArraySize(rows),f)) return false; body+=f;
   for(int i=0;i<ArraySize(rows);i++)
   {
      n="";
#define CR_FIELD(fun,name,value) if(!SWV5S5_Canonical##fun(name,value,f)) return false; else n+=f
      CR_FIELD(String,"domain",rows[i].domain_key);
      CR_FIELD(String,"key",rows[i].record_key);
      CR_FIELD(UInt,"revision",rows[i].logical_revision);
      CR_FIELD(String,"store_revision",rows[i].store_revision);
      CR_FIELD(Int,"state",rows[i].state);
      CR_FIELD(String,"payload_digest",rows[i].payload_digest);
      CR_FIELD(String,"payload",rows[i].payload);
      CR_FIELD(Datetime,"updated_at",rows[i].updated_at);
#undef CR_FIELD
      if(!SWV5S5_CanonicalNested("row_"+IntegerToString(i),n,f)) return false; body+=f;
   }
   return true;
}
bool SWV5S5_MvpContinuationDecodeRows(const string body,SWV5S5_MvpAuthorityRow &rows[])
{
   ArrayResize(rows,0); SWV5S5_MvpCodecReader r; r.Init(body); ulong count; string n; long value;
   if(!r.ReadUnsigned("count",count) || count==0 || count>4096) return false;
   ArrayResize(rows,(int)count);
   for(int i=0;i<(int)count;i++)
   {
      if(!r.ReadNested("row_"+IntegerToString(i),n)) return false;
      SWV5S5_MvpCodecReader row; row.Init(n);
      if(!row.ReadString("domain",rows[i].domain_key) || !row.ReadString("key",rows[i].record_key) ||
         !row.ReadUnsigned("revision",rows[i].logical_revision) || !row.ReadString("store_revision",rows[i].store_revision) ||
         !row.ReadInteger("state",value)) return false; rows[i].state=(int)value;
      if(!row.ReadString("payload_digest",rows[i].payload_digest) || !row.ReadString("payload",rows[i].payload) ||
         !row.ReadInteger("updated_at",value) || !row.AtEnd()) return false; rows[i].updated_at=(datetime)value;
      if(i>0 && (StringCompare(rows[i-1].domain_key,rows[i].domain_key)>0 ||
         (rows[i-1].domain_key==rows[i].domain_key && StringCompare(rows[i-1].record_key,rows[i].record_key)>=0))) return false;
   }
   string canonical; return r.AtEnd() && SWV5S5_MvpContinuationRowsPayload(rows,canonical) && canonical==body;
}
bool SWV5S5_MvpContinuationBrokerPayload(const SWV5S5_MvpBootstrapBrokerObservation &o,string &body)
{
   body=""; string f;
#define CB_FIELD(fun,name,value) if(!SWV5S5_Canonical##fun(name,value,f)) return false; else body+=f
   CB_FIELD(String,"broker",o.profile.broker_identity);
   CB_FIELD(String,"server",o.profile.server);
   CB_FIELD(Int,"login",o.profile.account_login);
   CB_FIELD(String,"currency",o.profile.account_currency);
   CB_FIELD(String,"symbol",o.profile.symbol);
   CB_FIELD(Int,"trade_mode",o.profile.account_trade_mode);
   CB_FIELD(Int,"account_mode",o.profile.account_mode);
   CB_FIELD(Bool,"connected",o.profile.connected);
   CB_FIELD(Bool,"trade_allowed",o.profile.account_trade_allowed);
   CB_FIELD(Bool,"trade_expert",o.profile.account_trade_expert);
   CB_FIELD(Datetime,"observed_at",o.observed_at);
   CB_FIELD(Bool,"positions_query",o.positions_query_succeeded);
   CB_FIELD(Bool,"orders_query",o.active_orders_query_succeeded);
   CB_FIELD(Bool,"complete",o.enumeration_complete);
   CB_FIELD(UInt,"row_failures",o.row_failures);
   CB_FIELD(UInt,"positions",o.total_positions);
   CB_FIELD(UInt,"orders",o.total_active_orders);
   CB_FIELD(Double,"exposure",o.total_exposure_volume);
   CB_FIELD(String,"digest",o.snapshot_digest);
#undef CB_FIELD
   return true;
}
bool SWV5S5_MvpContinuationDecodeBroker(const string body,SWV5S5_MvpBootstrapBrokerObservation &o)
{
   ZeroMemory(o); SWV5S5_MvpCodecReader r; r.Init(body); long x; ulong u;
   if(!r.ReadString("broker",o.profile.broker_identity) || !r.ReadString("server",o.profile.server) ||
      !r.ReadInteger("login",o.profile.account_login) || !r.ReadString("currency",o.profile.account_currency) ||
      !r.ReadString("symbol",o.profile.symbol) || !r.ReadInteger("trade_mode",x)) return false; o.profile.account_trade_mode=(int)x;
   if(!r.ReadInteger("account_mode",x)) return false; o.profile.account_mode=(SWV5_AccountPositionMode)x;
   if(!r.ReadBool("connected",o.profile.connected) || !r.ReadBool("trade_allowed",o.profile.account_trade_allowed) ||
      !r.ReadBool("trade_expert",o.profile.account_trade_expert) || !r.ReadInteger("observed_at",x)) return false; o.observed_at=(datetime)x;
   if(!r.ReadBool("positions_query",o.positions_query_succeeded) || !r.ReadBool("orders_query",o.active_orders_query_succeeded) ||
      !r.ReadBool("complete",o.enumeration_complete) || !r.ReadUnsigned("row_failures",u) || u>4294967295) return false; o.row_failures=(uint)u;
   if(!r.ReadUnsigned("positions",u) || u>4294967295) return false; o.total_positions=(uint)u;
   if(!r.ReadUnsigned("orders",u) || u>4294967295) return false; o.total_active_orders=(uint)u;
   if(!r.ReadDouble("exposure",o.total_exposure_volume) || !r.ReadString("digest",o.snapshot_digest) || !r.AtEnd()) return false;
   string canonical,digest;
   return SWV5S5_MvpContinuationBrokerPayload(o,canonical) && canonical==body &&
      SWV5S5_MvpBootstrapBrokerDigest(o,digest) && digest==o.snapshot_digest;
}

bool SWV5S5_MvpContinuationGenesisValid(SWV5S5_MvpSqliteAuthorityStore &store)
{
   SWV5S5_MvpAuthorityRow root,row; bool found=false; string schema,policy,ns,op_digest,manifest,completed,id,body,f,n;
   ulong version,generation;long created;
   if(!store.ReadRow(SWV5S5_MVP_DOMAIN_GENESIS,"GENESIS",root,found) || !found ||
      !SWV5S5_MvpContinuationRowValid(store,root) || root.logical_revision!=2 || root.state!=SWV5S5_MVP_GENESIS_READY_FOR_RECONCILIATION) return false;
   SWV5S5_MvpCodecReader r;r.Init(root.payload);
   if(!r.ReadString("schema_id",schema) || schema!=SWV5S5_MVP_STORE_SCHEMA_ID ||
      !r.ReadUnsigned("schema_version",version) || version!=SWV5S5_MVP_STORE_SCHEMA_VERSION ||
      !r.ReadString("policy_id",policy) || policy!=SWV5S5_MVP_GENESIS_POLICY ||
      !r.ReadString("namespace_digest",ns) || ns!=store.NamespaceDigest() || !r.ReadString("operator_digest",op_digest) ||
      !r.ReadString("manifest_digest",manifest) || !r.ReadUnsigned("generation",generation) || generation!=1 ||
      !r.ReadInteger("created_at",created) || created<=0 || !r.ReadString("completed_manifest_digest",completed) || !r.AtEnd() ||
      !SWV5S5_MvpGenesisManifestDigest(n) || manifest!=n || completed!=n || root.updated_at<(datetime)created) return false;
   body="";
#define CG_FIELD(fun,name,value) if(!SWV5S5_Canonical##fun(name,value,f)) return false; else body+=f
   CG_FIELD(String,"schema_id",schema);CG_FIELD(UInt,"schema_version",version);CG_FIELD(String,"policy_id",policy);
   CG_FIELD(String,"namespace_digest",ns);CG_FIELD(String,"operator_digest",op_digest);CG_FIELD(String,"manifest_digest",manifest);
   CG_FIELD(UInt,"generation",generation);CG_FIELD(Datetime,"created_at",(datetime)created);
   if(!SWV5S5_DomainDigest(SWV5S5_MVP_GENESIS_POLICY,body,id))return false;
   CG_FIELD(String,"completed_manifest_digest",completed);
   if(body!=root.payload || !store.ReadRow(SWV5S5_MVP_DOMAIN_OPERATOR,"GENESIS",row,found) || !found ||
      !SWV5S5_MvpContinuationRowValid(store,row) || row.logical_revision!=1 || row.state!=0 || row.updated_at!=(datetime)created)return false;
   SWV5S5_MvpOperatorInvocation op;SWV5S5_MvpCodecReader p;p.Init(row.payload);long at;string stored_id,stored_manifest;
   if(!p.ReadString("operator_id",op.operator_id) || !p.ReadString("authority_role",op.authority_role) ||
      !p.ReadString("authentication_reference",op.authentication_reference) || !p.ReadInteger("authenticated_at",at) ||
      !p.ReadString("genesis_id",stored_id) || stored_id!=id || !p.ReadString("manifest_digest",stored_manifest) || stored_manifest!=manifest || !p.AtEnd())return false;
   op.authenticated_at=(datetime)at;
   if(!SWV5S5_MvpOperatorInvocationValid(op,(datetime)created) || !SWV5S5_MvpOperatorPayload(op,body,n) || n!=op_digest)return false;
   CG_FIELD(String,"genesis_id",id);CG_FIELD(String,"manifest_digest",manifest);
   if(body!=row.payload)return false;
   for(int d=1;d<SWV5S5_MvpGenesisDomainCount();d++)
   {
      const string domain=SWV5S5_MvpGenesisDomain(d);int state=0;body="";
      CG_FIELD(String,"genesis_id",id);CG_FIELD(String,"manifest_digest",manifest);CG_FIELD(String,"domain",domain);CG_FIELD(UInt,"genesis_generation",1);
      if(domain==SWV5S5_MVP_DOMAIN_HARD_KILL)
      {
         state=(int)SWV5_HARD_KILL_ACTIVE;
         CG_FIELD(String,"latch_id","GENESIS-LATCH/"+id);CG_FIELD(UInt,"latch_generation",1);CG_FIELD(UInt,"release_generation",0);
         CG_FIELD(String,"activation_reason","NAMESPACE_GENESIS_NOT_RECONCILED");CG_FIELD(String,"activation_authority",SWV5S5_MVP_GENESIS_POLICY);
      }
      else if(domain==SWV5S5_MVP_DOMAIN_OWNERSHIP)state=(int)SWV5_LOCK_UNCLAIMED;
      if(!store.ReadRow(domain,"GENESIS",row,found) || !found || !SWV5S5_MvpContinuationRowValid(store,row) ||
         row.logical_revision!=1 || row.state!=state || row.payload!=body || row.updated_at<(datetime)created || row.updated_at>root.updated_at)return false;
   }
#undef CG_FIELD
   return true;
}
#endif
