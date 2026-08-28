#ifndef SW_V5_S5_FAKE_PLATFORM_QUERY_SOURCE_MQH
#define SW_V5_S5_FAKE_PLATFORM_QUERY_SOURCE_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// Typed query evidence only; no platform query APIs are reachable.
#include "SW_V5_S5_ReferenceStoreCommon.mqh"

bool SWV5S5_ReferenceBrokerSummaryDigest(const SWV5_AuthoritativeBrokerSummary &summary,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",summary.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",summary.persistence_namespace,f)) return false; body+=f;
#define SWV5S5_QD(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
#define SWV5S5_QU(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
   SWV5S5_QD("symbol_long",summary.symbol_long_volume); SWV5S5_QD("symbol_short",summary.symbol_short_volume);
   SWV5S5_QD("symbol_net",summary.symbol_net_volume); SWV5S5_QD("aggregate",summary.aggregate_position_volume);
   SWV5S5_QD("basket_open",summary.basket_open_volume); SWV5S5_QD("residual",summary.residual_volume);
   SWV5S5_QU("positions",summary.position_count); SWV5S5_QU("orders",summary.order_count);
   SWV5S5_QU("transaction_hwm",summary.transaction_high_watermark); SWV5S5_QU("observation",summary.observation_sequence);
#undef SWV5S5_QD
#undef SWV5S5_QU
   return SWV5S5_SHA256(body,digest);
}

bool SWV5S5_ReferenceExecutionSummaryDigest(const SWV5_AuthoritativeRestartRequestSummary &summary,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",summary.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",summary.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("basket_id",summary.basket_id.value,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("pending_count",summary.pending_request_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("set_digest",summary.request_set_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("set_revision",summary.request_set_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("reconciliation_revision",summary.reconciliation_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("observation_sequence",summary.observation_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("query_required",summary.pending_request_query.required_flags,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("query_completed",summary.pending_request_query.completed_flags,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("query_authoritative",summary.pending_request_query.authoritative_flags,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("query_snapshot_id",summary.pending_request_query.snapshot_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("query_snapshot_digest",summary.pending_request_query.snapshot_digest,f)) return false; body+=f;
   return SWV5S5_SHA256(body,digest);
}

class SWV5S5_FakePlatformQuerySource
{
private:
   SWV5_AuthoritativeBrokerSummary m_broker;
   SWV5_AuthoritativeRestartRequestSummary m_execution;

public:
   bool SupplyBroker(const SWV5_AuthoritativeBrokerSummary &summary)
   {
      string digest;
      if(summary.authority!=SWV5_AUTHORITY_LIVE_BROKER_STATE ||
         summary.queries.required_flags!=SWV5_RESTART_BROKER_QUERY_FLAGS_V5 ||
         summary.queries.completed_flags!=SWV5_RESTART_BROKER_QUERY_FLAGS_V5 ||
         summary.queries.authoritative_flags!=SWV5_RESTART_BROKER_QUERY_FLAGS_V5 ||
         summary.observation_sequence==0 || summary.observed_at<=0 ||
         !SWV5S5_ReferenceBrokerSummaryDigest(summary,digest) || summary.complete_summary_digest!=digest) return false;
      m_broker=summary; return true;
   }

   bool SupplyExecution(const SWV5_AuthoritativeRestartRequestSummary &summary)
   {
      string digest;
      if(summary.authority_source!=SWV5_AUTHORITY_EXECUTION_REQUEST_STATE ||
         summary.pending_request_query.required_flags!=SWV5_RESTART_EXECUTION_QUERY_FLAGS_V5 ||
         summary.pending_request_query.completed_flags!=SWV5_RESTART_EXECUTION_QUERY_FLAGS_V5 ||
         summary.pending_request_query.authoritative_flags!=SWV5_RESTART_EXECUTION_QUERY_FLAGS_V5 ||
         summary.observation_sequence==0 || summary.observed_at<=0 ||
         !SWV5S5_ReferenceExecutionSummaryDigest(summary,digest) || summary.complete_summary_digest!=digest) return false;
      m_execution=summary; return true;
   }
   SWV5_AuthoritativeBrokerSummary Broker(void) const { return m_broker; }
   SWV5_AuthoritativeRestartRequestSummary Execution(void) const { return m_execution; }
};

#endif
