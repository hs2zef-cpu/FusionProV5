#ifndef SW_V5_S5_MVP_BASKET_INTEGRITY_MQH
#define SW_V5_S5_MVP_BASKET_INTEGRITY_MQH
// Pure V5 nested compatibility integrity. NOT an authority credential.
// Physical records/tokens use domain-separated SHA-256, not this checksum.
#include "SW_V5_S5_MvpHardKillActivationAuthority.mqh"
string SWV5S5_MvpBasketV5Integrity(const string text)
{
   ulong h=1469598103934665603;
   for(int i=0;i<StringLen(text);i++){h^=(ulong)StringGetCharacter(text,i);h*=1099511628211;}
   return StringFormat("%I64u",h);
}
bool SWV5S5_MvpBasketEmptyEvents(SWV5_DurableEventIdentitySet &events)
{
   ZeroMemory(events); SWV5S5_MvpInitProductionVersion(events.contract_version);
   events.fingerprint_policy=SWV5_DURABLE_FINGERPRINT_REQUIRED;
   events.canonical_event_index=""; events.canonical_fingerprint_index=""; events.compaction_generation=1;
   string body="",f,version;
   if(!SWV5S5_CanonicalString("format","SWV5-DURABLE-EVENT-SET-V5-LP1",f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_ContractVersion(events.contract_version,version) ||
      !SWV5S5_CanonicalNested("contract_version",version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("fingerprint_policy",events.fingerprint_policy,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNested("canonical_event_index","",f)) return false; body+=f;
   if(!SWV5S5_CanonicalNested("canonical_fingerprint_index","",f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("accepted_identity_count",0,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("highest_transaction_sequence",0,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("index_revision",0,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("compaction_generation",1,f)) return false; body+=f;
   events.identity_set_digest=SWV5S5_MvpBasketV5Integrity(body); return true;
}
bool SWV5S5_MvpBasketSealQueries(SWV5_AuthoritativeQuerySet &queries)
{
   queries.snapshot_digest=""; string body,format;
   if(!SWV5S5_MvpCodecEncode_SWV5_AuthoritativeQuerySet(queries,body) ||
      !SWV5S5_CanonicalString("format","SWV5-QUERY-SNAPSHOT-V5-LP1",format)) return false;
   queries.snapshot_digest=SWV5S5_MvpBasketV5Integrity(format+body); return true;
}
bool SWV5S5_MvpBasketQueriesValid(const SWV5_ContractValidationContext &context,const SWV5_AuthoritativeQuerySet &q)
{
   SWV5_AuthoritativeQuerySet sealed=q;
   return SWV5S5_IsV5Version(q.contract_version) && q.required_flags>0 &&
      (q.required_flags&~SWV5_QUERY_KNOWN_FLAGS_V5)==0 && q.completed_flags==q.required_flags &&
      q.authoritative_flags==q.required_flags && q.observation_sequence>0 &&
      q.observed_at>0 && q.observed_at<=context.clock_time && q.issuing_component==SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER &&
      (q.authority_source==SWV5_AUTHORITY_LIVE_BROKER_STATE || q.authority_source==SWV5_AUTHORITY_DEAL_HISTORY) &&
      q.snapshot_id!="" && SWV5S5_MvpBasketSealQueries(sealed) && q.snapshot_digest==sealed.snapshot_digest;
}
#endif
