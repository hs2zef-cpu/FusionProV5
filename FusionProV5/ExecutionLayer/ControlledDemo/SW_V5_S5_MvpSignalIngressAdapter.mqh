#ifndef SW_V5_S5_MVP_SIGNAL_INGRESS_ADAPTER_MQH
#define SW_V5_S5_MVP_SIGNAL_INGRESS_ADAPTER_MQH

// CONTROLLED DEMO MVP AUTHENTIC SIGNAL ADAPTER.
// Projects only an already-produced CCentralOrchestrator EngineInput/Decision.
// It owns no signal policy, cannot synthesize a direction, and has no broker API.

#include "../../Core/SW_V5_Types.mqh"
#include "../RuntimeAuthority/SW_V5_S5_MvpSqliteAuthorityStore.mqh"
#include "../Contracts/SW_V5_S5_ProducerTrustContract.mqh"

const string SWV5S5_MVP_DOMAIN_PRODUCER_SEQUENCE="MVP_PRODUCER_PUBLICATION_SEQUENCE";
const string SWV5S5_MVP_PRODUCER_SEQUENCE_KEY="CURRENT";
const string SWV5S5_MVP_SIGNAL_SOURCE_DOMAIN="SWV5-S5-MVP-AUTHENTIC-SIGNAL-SOURCE-V1";

struct SWV5S5_MvpProducerSequenceEntry
{
   string source_digest;
   ulong publication_sequence;
   datetime publication_time;
   string ingress_identity;
   string payload_digest;
};

bool SWV5S5_MvpProjectSignalSource(const SWV5_EngineInput &engine_input,
                                   const SWV5_DecisionResult &decision,
                                   const SWV5S5_ProducerTrustRecord &trust,
                                   SWV5S5_IngressEnvelope &ingress,
                                   string &source_digest)
{
   ZeroMemory(ingress); source_digest="";
   const SWV5_SnapshotHeader h=engine_input.market.header;
   const SWV5_ResultHeader d=decision.header;
   if(h.schema_version!=SWV5_SCHEMA_VERSION || h.sequence==0 || h.history_generation==0 ||
      h.symbol=="" || h.timeframe<=0 || h.closed_bar_time<=0 ||
      d.engine_kind!=SWV5_ENGINE_DECISION || !d.valid || d.snapshot_sequence!=h.sequence ||
      d.history_generation!=h.history_generation || decision.direction!=(int)decision.action ||
      (decision.action!=SWV5_ACTION_WAIT && decision.action!=SWV5_ACTION_BUY &&
       decision.action!=SWV5_ACTION_SELL && decision.action!=SWV5_ACTION_BLOCKED) ||
      trust.status!=SWV5S5_TRUST_AUTHORIZED || trust.authority_record_id=="" ||
      trust.authority_generation==0 || trust.producer_component!="DECISION" ||
      trust.producer_instance=="" || trust.producer_epoch==0 ||
      trust.symbol!=h.symbol || trust.timeframe!=(int)h.timeframe ||
      trust.execution_mode!=(int)h.execution_mode) return false;
   SWV5S5_InitContractVersion(ingress.contract_version);
   ingress.canonical_policy_id=SWV5S5_CANONICAL_POLICY_ID;
   ingress.producer.authority_record_id=trust.authority_record_id;
   ingress.producer.authority_generation=trust.authority_generation;
   ingress.producer.producer_component=trust.producer_component;
   ingress.producer.producer_instance=trust.producer_instance;
   ingress.producer.producer_epoch=trust.producer_epoch;
   ingress.snapshot.snapshot_schema=h.schema_version;
   ingress.snapshot.sequence=h.sequence; ingress.snapshot.history_generation=h.history_generation;
   ingress.snapshot.execution_mode=(int)h.execution_mode; ingress.snapshot.data_quality_flags=h.data_quality_flags;
   ingress.snapshot.symbol=h.symbol; ingress.snapshot.timeframe=(int)h.timeframe;
   ingress.snapshot.closed_bar_time=h.closed_bar_time;
   ingress.decision.engine_kind=(int)d.engine_kind; ingress.decision.health=(int)d.health;
   ingress.decision.valid=d.valid; ingress.decision.score=d.score; ingress.decision.confidence=d.confidence;
   ingress.decision.reason_flags=d.reason_flags; ingress.decision.snapshot_sequence=d.snapshot_sequence;
   ingress.decision.history_generation=d.history_generation; ingress.decision.reason_text=d.reason_text;
   ingress.decision.validation_error=d.validation_error; ingress.decision.action=(int)decision.action;
   ingress.decision.direction=decision.direction; ingress.decision.state=decision.state;
   ingress.decision.blocking_engine=(int)decision.blocking_engine;
   string body;
   return SWV5S5_CanonicalIngressSource(ingress,body) &&
      SWV5S5_DomainDigest(SWV5S5_MVP_SIGNAL_SOURCE_DOMAIN,body,source_digest);
}

bool SWV5S5_MvpEncodeProducerSequence(const ulong high_watermark,
                                      const SWV5S5_MvpProducerSequenceEntry &entries[],string &payload)
{
   payload=""; string f,nested;
   if(!SWV5S5_CanonicalUInt("high_watermark",high_watermark,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalUInt("entry_count",(ulong)ArraySize(entries),f)) return false; payload+=f;
   for(int i=0;i<ArraySize(entries);i++)
   {
      nested="";
      if(!SWV5S5_CanonicalString("source_digest",entries[i].source_digest,f)) return false; nested+=f;
      if(!SWV5S5_CanonicalUInt("publication_sequence",entries[i].publication_sequence,f)) return false; nested+=f;
      if(!SWV5S5_CanonicalDatetime("publication_time",entries[i].publication_time,f)) return false; nested+=f;
      if(!SWV5S5_CanonicalString("ingress_identity",entries[i].ingress_identity,f)) return false; nested+=f;
      if(!SWV5S5_CanonicalString("payload_digest",entries[i].payload_digest,f)) return false; nested+=f;
      if(!SWV5S5_CanonicalNested("entry_"+IntegerToString(i),nested,f)) return false; payload+=f;
   }
   return true;
}

bool SWV5S5_MvpDecodeProducerSequence(const string payload,ulong &high_watermark,
                                      SWV5S5_MvpProducerSequenceEntry &entries[])
{
   high_watermark=0; ArrayResize(entries,0); SWV5S5_MvpCodecReader r; r.Init(payload);
   ulong count=0; string nested;
   if(!r.ReadUnsigned("high_watermark",high_watermark) || !r.ReadUnsigned("entry_count",count) || count>100000) return false;
   ArrayResize(entries,(int)count);
   for(ulong i=0;i<count;i++)
   {
      if(!r.ReadNested("entry_"+IntegerToString((long)i),nested)) return false;
      SWV5S5_MvpCodecReader e; e.Init(nested); long when=0;
      if(!e.ReadString("source_digest",entries[(int)i].source_digest) ||
         !e.ReadUnsigned("publication_sequence",entries[(int)i].publication_sequence) ||
         !e.ReadInteger("publication_time",when) ||
         !e.ReadString("ingress_identity",entries[(int)i].ingress_identity) ||
         !e.ReadString("payload_digest",entries[(int)i].payload_digest) || !e.AtEnd()) return false;
      entries[(int)i].publication_time=(datetime)when;
      if(entries[(int)i].publication_sequence==0 || entries[(int)i].publication_sequence>high_watermark ||
         entries[(int)i].publication_time<=0 || !SWV5S5_IsDigest64Lower(entries[(int)i].source_digest) ||
         !SWV5S5_IsDigest64Lower(entries[(int)i].ingress_identity) ||
         !SWV5S5_IsDigest64Lower(entries[(int)i].payload_digest)) return false;
   }
   return r.AtEnd() && ((count==0 && high_watermark==0) || (count>0 && high_watermark>0));
}

class SWV5S5_MvpSignalIngressAdapter
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
public:
   bool Configure(const string relative_path,const string namespace_digest)
   { return m_store.Open(relative_path,namespace_digest); }

   bool Initialize(const datetime now)
   {
      if(now<=0) return false;
      SWV5S5_MvpAuthorityRow row,committed; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_PRODUCER_SEQUENCE,
                          SWV5S5_MVP_PRODUCER_SEQUENCE_KEY,row,found)) return false;
      if(found)
      {
         ulong high_watermark=0; SWV5S5_MvpProducerSequenceEntry entries[]; string digest;
         return row.state==1 &&
            SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_PRODUCER_SEQUENCE,row.payload,digest) &&
            digest==row.payload_digest &&
            SWV5S5_MvpDecodeProducerSequence(row.payload,high_watermark,entries);
      }
      SWV5S5_MvpProducerSequenceEntry entries[]; string payload,digest;
      if(!SWV5S5_MvpEncodeProducerSequence(0,entries,payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_PRODUCER_SEQUENCE,payload,digest)) return false;
      return m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_PRODUCER_SEQUENCE,
         SWV5S5_MVP_PRODUCER_SEQUENCE_KEY,0,"","",0,1,1,digest,payload,now,committed);
   }

   bool ReadState(ulong &high_watermark,SWV5S5_MvpProducerSequenceEntry &entries[])
   {
      SWV5S5_MvpAuthorityRow row; bool found=false; string digest;
      return m_store.ReadRow(SWV5S5_MVP_DOMAIN_PRODUCER_SEQUENCE,
         SWV5S5_MVP_PRODUCER_SEQUENCE_KEY,row,found) && found && row.state==1 &&
         SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_PRODUCER_SEQUENCE,row.payload,digest) &&
         digest==row.payload_digest &&
         SWV5S5_MvpDecodeProducerSequence(row.payload,high_watermark,entries);
   }

   bool Publish(const SWV5_EngineInput &engine_input,const SWV5_DecisionResult &decision,
                const SWV5S5_ProducerTrustRecord &trust,
                const SWV5_ContractValidationContext &context,
                SWV5S5_IngressEnvelope &ingress,bool &replayed)
   {
      replayed=false; string source_digest;
      if(!SWV5S5_IsValidationContextUsable(context) ||
         !SWV5S5_MvpProjectSignalSource(engine_input,decision,trust,ingress,source_digest) ||
         trust.clock_id!=context.clock_id || trust.clock_authority!=context.clock_authority ||
         context.clock_time<trust.valid_from || context.clock_time>=trust.valid_until) return false;
      SWV5S5_MvpAuthorityRow row,committed; bool found=false; ulong high=0;
      SWV5S5_MvpProducerSequenceEntry entries[];
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_PRODUCER_SEQUENCE,SWV5S5_MVP_PRODUCER_SEQUENCE_KEY,row,found)) return false;
      if(found)
      {
         string digest;
         if(!SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_PRODUCER_SEQUENCE,row.payload,digest) || digest!=row.payload_digest ||
            !SWV5S5_MvpDecodeProducerSequence(row.payload,high,entries)) return false;
      }
      for(int i=0;i<ArraySize(entries);i++) if(entries[i].source_digest==source_digest)
      {
         ingress.publication.clock_id=context.clock_id; ingress.publication.clock_authority=context.clock_authority;
         ingress.publication.publication_time=entries[i].publication_time;
         ingress.publication.publication_sequence=entries[i].publication_sequence;
         string identity,payload;
         if(!SWV5S5_DeriveIngressIdentityAndDigest(ingress,identity,payload) ||
            identity!=entries[i].ingress_identity || payload!=entries[i].payload_digest) return false;
         ingress.ingress_identity=identity; ingress.payload_digest=payload; replayed=true; return true;
      }
      if(high==18446744073709551615) return false;
      ingress.publication.clock_id=context.clock_id; ingress.publication.clock_authority=context.clock_authority;
      ingress.publication.publication_time=context.clock_time; ingress.publication.publication_sequence=high+1;
      if(!SWV5S5_DeriveIngressIdentityAndDigest(ingress,ingress.ingress_identity,ingress.payload_digest)) return false;
      const int n=ArraySize(entries); ArrayResize(entries,n+1);
      entries[n].source_digest=source_digest; entries[n].publication_sequence=high+1;
      entries[n].publication_time=context.clock_time; entries[n].ingress_identity=ingress.ingress_identity;
      entries[n].payload_digest=ingress.payload_digest;
      string payload,digest;
      if(!SWV5S5_MvpEncodeProducerSequence(high+1,entries,payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_PRODUCER_SEQUENCE,payload,digest)) return false;
      return m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_PRODUCER_SEQUENCE,SWV5S5_MVP_PRODUCER_SEQUENCE_KEY,
         found ? row.logical_revision : 0,found ? row.store_revision : "",found ? row.payload_digest : "",
         found ? row.state : 0,found ? row.logical_revision+1 : 1,1,digest,payload,context.clock_time,committed);
   }
};

#endif
