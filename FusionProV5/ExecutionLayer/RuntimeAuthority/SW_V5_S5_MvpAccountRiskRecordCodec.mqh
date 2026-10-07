#ifndef SW_V5_S5_MVP_ACCOUNT_RISK_RECORD_CODEC_MQH
#define SW_V5_S5_MVP_ACCOUNT_RISK_RECORD_CODEC_MQH
// Runtime-only physical account record codec. No issuer or broker API.
#include "SW_V5_S5_MvpAuthorityRecordCodec.mqh"
const string SWV5S5_MVP_DOMAIN_ACCOUNT_RISK="MVP_ACCOUNT_RISK_AUTHORITY";
const string SWV5S5_MVP_ACCOUNT_RISK_FORMAT="SWV5-MVP-ACCOUNT-RISK-PHYSICAL-V1";
struct SWV5S5_MvpAccountRiskAuthorityRecord
{
   string format;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_AccountRiskNamespace account_namespace;
   ulong authority_epoch,publication_sequence,record_revision;
   string record_id;
   datetime created_at;
   int status;
};
bool SWV5S5_MvpAccountRiskEncode(const SWV5S5_MvpAccountRiskAuthorityRecord &v,string &body)
{
   string f,n; body="";
   if(!SWV5S5_CanonicalString("format",v.format,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_PersistenceNamespace(v.persistence_namespace,n) ||
      !SWV5S5_CanonicalNested("scope",n,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_AccountRiskNamespace(v.account_namespace,n) ||
      !SWV5S5_CanonicalNested("account",n,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("epoch",v.authority_epoch,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("sequence",v.publication_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("revision",v.record_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("record_id",v.record_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("created_at",(long)v.created_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("status",v.status,f)) return false; body+=f;
   return true;
}
bool SWV5S5_MvpAccountRiskDecode(const string body,SWV5S5_MvpAccountRiskAuthorityRecord &v)
{
   ZeroMemory(v); SWV5S5_MvpCodecReader r; r.Init(body); string n; long at=0,status=0;
   if(!r.ReadString("format",v.format) || !r.ReadNested("scope",n) ||
      !SWV5S5_MvpCodecDecode_SWV5_PersistenceNamespace(n,v.persistence_namespace) ||
      !r.ReadNested("account",n) || !SWV5S5_MvpCodecDecode_SWV5_AccountRiskNamespace(n,v.account_namespace) ||
      !r.ReadUnsigned("epoch",v.authority_epoch) || !r.ReadUnsigned("sequence",v.publication_sequence) ||
      !r.ReadUnsigned("revision",v.record_revision) || !r.ReadString("record_id",v.record_id) ||
      !r.ReadInteger("created_at",at) || !r.ReadInteger("status",status) || !r.AtEnd() || status!=1) return false;
   v.created_at=(datetime)at; v.status=(int)status; return true;
}
bool SWV5S5_MvpAccountRiskValidateRow(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5S5_MvpAuthorityRow &row,
                                      SWV5S5_MvpAccountRiskAuthorityRecord &record)
{
   string payload,digest,revision,id;
   return row.domain_key==SWV5S5_MVP_DOMAIN_ACCOUNT_RISK && row.record_key=="CURRENT" &&
      SWV5S5_MvpAccountRiskDecode(row.payload,record) && record.format==SWV5S5_MVP_ACCOUNT_RISK_FORMAT &&
      SWV5S5_IsV5Version(record.persistence_namespace.contract_version) &&
      SWV5S5_IsV5Version(record.account_namespace.contract_version) &&
      record.persistence_namespace.ownership_namespace.symbol==SWV5S5_MVP_SYMBOL && record.persistence_namespace.basket_id.value!="" &&
      record.account_namespace.broker_identity!="" && record.account_namespace.server!="" && record.account_namespace.account_login>0 &&
      record.account_namespace.broker_identity==record.persistence_namespace.ownership_namespace.broker_identity &&
      record.account_namespace.server==record.persistence_namespace.ownership_namespace.server &&
      record.account_namespace.account_login==record.persistence_namespace.ownership_namespace.account_login &&
      record.account_namespace.strategy_id==record.persistence_namespace.ownership_namespace.strategy_id &&
      record.account_namespace.magic==record.persistence_namespace.ownership_namespace.magic &&
      record.account_namespace.strategy_id==SWV5S5_MVP_PROFILE_ID && record.account_namespace.magic==SWV5_RUNTIME_STRATEGY_MAGIC &&
      record.account_namespace.account_currency==SWV5S5_MVP_ACCOUNT_CURRENCY &&
      record.account_namespace.account_mode==SWV5_ACCOUNT_MODE_HEDGING &&
      record.account_namespace.authoritative_source==SWV5_AUTHORITY_LIVE_BROKER_STATE &&
      record.status==1 && row.state==1 && record.record_revision==1 && row.logical_revision==1 &&
      record.created_at>0 && row.updated_at==record.created_at &&
      record.authority_epoch==1 && record.publication_sequence==1 &&
      record.account_namespace.snapshot_epoch==record.authority_epoch &&
      record.account_namespace.snapshot_sequence==record.publication_sequence &&
      SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_ACCOUNT_RISK+"/ID",store.NamespaceDigest(),id) && record.record_id==id &&
      SWV5S5_MvpAccountRiskEncode(record,payload) && payload==row.payload &&
      SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_ACCOUNT_RISK,payload,digest) && digest==row.payload_digest &&
      store.DeriveStoreRevision(row.domain_key,row.record_key,row.logical_revision,digest,revision) && revision==row.store_revision;
}
#endif // SW_V5_S5_MVP_ACCOUNT_RISK_RECORD_CODEC_MQH
