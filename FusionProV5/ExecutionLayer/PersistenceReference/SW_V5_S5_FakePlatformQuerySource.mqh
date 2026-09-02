#ifndef SW_V5_S5_FAKE_PLATFORM_QUERY_SOURCE_MQH
#define SW_V5_S5_FAKE_PLATFORM_QUERY_SOURCE_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// Typed query evidence only; no platform query APIs are reachable.
#include "SW_V5_S5_ReferenceStoreCommon.mqh"
#include "SW_V5_S5_ReferenceProductionIntegrity.mqh"

bool SWV5S5_ReferenceQuerySnapshotDigest(const SWV5_AuthoritativeQuerySet &queries,string &digest)
{
   SWV5_AuthoritativeQuerySet canonical=queries; canonical.snapshot_digest="";
   string format,body;
   return SWV5S5_CanonicalString("format","SWV5-QUERY-SNAPSHOT-V5-LP1",format) &&
      SWV5S5_CanonicalCheckpointQueries("queries",canonical,body) &&
      SWV5S5_SHA256(format+body,digest);
}

bool SWV5S5_ReferenceQueryValid(const SWV5_AuthoritativeQuerySet &queries,
                                const ulong required_flags,
                                const SWV5_ComponentAuthority component,
                                const SWV5_AuthoritySource source,
                                const ulong enclosing_sequence,
                                const datetime enclosing_observed_at)
{
   string digest;
   return SWV5S5_IsV5Version(queries.contract_version) && required_flags>0 &&
      (required_flags&~SWV5_QUERY_KNOWN_FLAGS_V5)==0 &&
      queries.required_flags==required_flags && queries.completed_flags==required_flags &&
      queries.authoritative_flags==required_flags &&
      queries.observation_sequence>0 && queries.observation_sequence<=enclosing_sequence &&
      queries.observed_at>0 && queries.observed_at<=enclosing_observed_at &&
      queries.issuing_component==component && queries.authority_source==source &&
      queries.snapshot_id!="" && SWV5S5_ReferenceQuerySnapshotDigest(queries,digest) &&
      queries.snapshot_digest==digest;
}

bool SWV5S5_ReferenceBrokerSummaryDigest(const SWV5_AuthoritativeBrokerSummary &summary,string &digest)
{
   string body="",f,format;
#define SWV5S5_QD(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
#define SWV5S5_QU(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define SWV5S5_QI(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("contract_version",summary.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("persistence_namespace",summary.persistence_namespace,f)) return false; body+=f;
   SWV5S5_QD("symbol_long_volume",summary.symbol_long_volume); SWV5S5_QD("symbol_short_volume",summary.symbol_short_volume);
   SWV5S5_QD("symbol_net_volume",summary.symbol_net_volume); SWV5S5_QD("aggregate_position_volume",summary.aggregate_position_volume);
   if(!SWV5S5_CanonicalString("basket_id",summary.basket_id.value,f)) return false; body+=f;
   SWV5S5_QD("basket_open_volume",summary.basket_open_volume); SWV5S5_QD("residual_volume",summary.residual_volume);
   SWV5S5_QU("position_count",summary.position_count); SWV5S5_QU("order_count",summary.order_count);
   if(!SWV5S5_CanonicalCheckpointCorrelation("latest_confirmed_correlation",summary.latest_confirmed_correlation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalCheckpointBrokerIdentity("latest_broker_event_identity",summary.latest_broker_event_identity,f)) return false; body+=f;
   SWV5S5_QU("transaction_high_watermark",summary.transaction_high_watermark);
   SWV5S5_QU("observation_sequence",summary.observation_sequence); SWV5S5_QI("account_mode",summary.account_mode);
   if(!SWV5S5_CanonicalCheckpointQueries("queries",summary.queries,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",summary.observed_at,f)) return false; body+=f;
   SWV5S5_QI("authority",summary.authority);
#undef SWV5S5_QD
#undef SWV5S5_QU
#undef SWV5S5_QI
   return SWV5S5_CanonicalString("format","SWV5-BROKER-SUMMARY-V5-LP1",format) &&
      SWV5S5_SHA256(format+body,digest);
}

bool SWV5S5_ReferenceExecutionSummaryDigest(const SWV5_AuthoritativeRestartRequestSummary &summary,string &digest)
{
   string body="",f,format;
   if(!SWV5S5_CanonicalContractVersion("contract_version",summary.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("persistence_namespace",summary.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("basket_id",summary.basket_id.value,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("account_mode",summary.account_mode,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("pending_request_count",summary.pending_request_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("request_set_digest",summary.request_set_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("request_set_revision",summary.request_set_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("reconciliation_revision",summary.reconciliation_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("observation_sequence",summary.observation_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",summary.observed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("authority",summary.authority,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("authority_source",summary.authority_source,f)) return false; body+=f;
   if(!SWV5S5_CanonicalCheckpointQueries("pending_request_query",summary.pending_request_query,f)) return false; body+=f;
   return SWV5S5_CanonicalString("format","SWV5-RESTART-REQUEST-SUMMARY-V5-LP1",format) &&
      SWV5S5_SHA256(format+body,digest);
}

bool SWV5S5_ReferenceBrokerSummaryValid(const SWV5_AuthoritativeBrokerSummary &summary,
                                        const bool allow_zero_history=false)
{
   string digest;
   const bool ordinary_history=summary.transaction_high_watermark>0 &&
      summary.latest_confirmed_correlation.phase==SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION &&
      summary.latest_confirmed_correlation.request_identity.request_id.correlation_id!="" &&
      summary.latest_confirmed_correlation.request_identity.request_id.attempt_id!="" &&
      summary.latest_confirmed_correlation.request_identity.idempotency_key!="" &&
      summary.latest_broker_event_identity.broker_event_id!="" &&
      summary.latest_broker_event_identity.transaction_sequence>0 &&
      summary.latest_broker_event_identity.broker_event_id==summary.latest_confirmed_correlation.broker_identity.broker_event_id &&
      summary.latest_broker_event_identity.transaction_sequence==summary.latest_confirmed_correlation.broker_identity.transaction_sequence;
   const bool zero_history=allow_zero_history && summary.transaction_high_watermark==0 &&
      summary.symbol_long_volume==0.0 && summary.symbol_short_volume==0.0 && summary.symbol_net_volume==0.0 &&
      summary.aggregate_position_volume==0.0 && summary.basket_open_volume==0.0 && summary.residual_volume==0.0 &&
      summary.position_count==0 && summary.order_count==0 &&
      SWV5S5_ReferenceZeroCorrelation(summary.latest_confirmed_correlation) &&
      SWV5S5_ReferenceZeroBrokerIdentity(summary.latest_broker_event_identity);
   return SWV5S5_IsV5Version(summary.contract_version) && summary.persistence_namespace.basket_id.value!="" &&
      summary.basket_id.value==summary.persistence_namespace.basket_id.value &&
      summary.account_mode==SWV5_ACCOUNT_MODE_HEDGING && summary.authority==SWV5_AUTHORITY_LIVE_BROKER_STATE &&
      SWV5_IsFiniteNumber(summary.symbol_long_volume) && SWV5_IsFiniteNumber(summary.symbol_short_volume) &&
      SWV5_IsFiniteNumber(summary.symbol_net_volume) && SWV5_IsFiniteNumber(summary.aggregate_position_volume) &&
      SWV5_IsFiniteNumber(summary.basket_open_volume) && SWV5_IsFiniteNumber(summary.residual_volume) &&
      summary.symbol_long_volume>=0.0 && summary.symbol_short_volume>=0.0 &&
      summary.aggregate_position_volume>=0.0 && summary.basket_open_volume>=0.0 && summary.residual_volume>=0.0 &&
      summary.observation_sequence>0 && summary.observed_at>0 && (ordinary_history || zero_history) &&
      SWV5S5_ReferenceQueryValid(summary.queries,SWV5_RESTART_BROKER_QUERY_FLAGS_V5,
         SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER,SWV5_AUTHORITY_LIVE_BROKER_STATE,
         summary.observation_sequence,summary.observed_at) &&
      SWV5S5_ReferenceBrokerSummaryDigest(summary,digest) && summary.complete_summary_digest==digest;
}

bool SWV5S5_ReferenceExecutionSummaryValid(const SWV5_AuthoritativeRestartRequestSummary &summary)
{
   string digest;
   return SWV5S5_IsV5Version(summary.contract_version) && summary.persistence_namespace.basket_id.value!="" &&
      summary.basket_id.value==summary.persistence_namespace.basket_id.value &&
      summary.account_mode==SWV5_ACCOUNT_MODE_HEDGING && summary.request_set_digest!="" &&
      summary.request_set_revision!="" && summary.reconciliation_revision>0 &&
      summary.observation_sequence>0 && summary.observed_at>0 &&
      summary.authority==SWV5_COMPONENT_AUTHORITY_EXECUTION &&
      summary.authority_source==SWV5_AUTHORITY_EXECUTION_REQUEST_STATE &&
      SWV5S5_ReferenceQueryValid(summary.pending_request_query,SWV5_RESTART_EXECUTION_QUERY_FLAGS_V5,
         SWV5_COMPONENT_AUTHORITY_EXECUTION,SWV5_AUTHORITY_EXECUTION_REQUEST_STATE,
         summary.observation_sequence,summary.observed_at) &&
      SWV5S5_ReferenceExecutionSummaryDigest(summary,digest) && summary.complete_summary_digest==digest;
}

class SWV5S5_FakePlatformQuerySource
{
private:
   SWV5_AuthoritativeBrokerSummary m_broker;
   SWV5_AuthoritativeRestartRequestSummary m_execution;

public:
   bool SupplyBroker(const SWV5_AuthoritativeBrokerSummary &summary)
   {
       if(!SWV5S5_ReferenceBrokerSummaryValid(summary)) return false;
      m_broker=summary; return true;
   }

   bool SupplyExecution(const SWV5_AuthoritativeRestartRequestSummary &summary)
   {
       if(!SWV5S5_ReferenceExecutionSummaryValid(summary)) return false;
      m_execution=summary; return true;
   }
   SWV5_AuthoritativeBrokerSummary Broker(void) const { return m_broker; }
   SWV5_AuthoritativeRestartRequestSummary Execution(void) const { return m_execution; }
};

#endif
