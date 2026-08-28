#ifndef SW_V5_S5_FAKE_PLATFORM_QUERY_SOURCE_MQH
#define SW_V5_S5_FAKE_PLATFORM_QUERY_SOURCE_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// Explicit deterministic query evidence; never reads a live platform.

#include "SW_V5_S5_ReferenceStoreCommon.mqh"

struct SWV5S5_ReferenceQuerySnapshot
{
   string query_id;
   string persistence_namespace_digest;
   string ownership_fence_digest;
   SWV5_AccountPositionMode account_mode;
   ulong query_flags;
   ulong observation_sequence;
   datetime observed_at;
   SWV5_ComponentAuthority component;
   SWV5_AuthoritySource source;
   uint position_count;
   uint order_count;
   uint deal_count;
   uint transaction_count;
   uint pending_request_count;
   string complete_summary_digest;
};

class SWV5S5_FakePlatformQuerySource
{
private:
   SWV5S5_ReferenceQuerySnapshot m_broker;
   SWV5S5_ReferenceQuerySnapshot m_execution;

public:
   bool SupplyBroker(const SWV5S5_ReferenceQuerySnapshot &snapshot)
   {
      if(snapshot.component!=SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER ||
         snapshot.source!=SWV5_AUTHORITY_LIVE_BROKER_STATE ||
         snapshot.query_flags!=SWV5_RESTART_BROKER_QUERY_FLAGS_V5 ||
         snapshot.persistence_namespace_digest=="" || snapshot.ownership_fence_digest=="" ||
         snapshot.observation_sequence==0 || snapshot.observed_at<=0 ||
         snapshot.complete_summary_digest=="")
         return false;
      m_broker=snapshot;
      return true;
   }

   bool SupplyExecution(const SWV5S5_ReferenceQuerySnapshot &snapshot)
   {
      if(snapshot.component!=SWV5_COMPONENT_AUTHORITY_EXECUTION ||
         snapshot.source!=SWV5_AUTHORITY_EXECUTION_REQUEST_STATE ||
         snapshot.query_flags!=SWV5_RESTART_EXECUTION_QUERY_FLAGS_V5 ||
         snapshot.position_count!=0 || snapshot.order_count!=0 ||
         snapshot.deal_count!=0 || snapshot.transaction_count!=0 ||
         snapshot.persistence_namespace_digest=="" || snapshot.ownership_fence_digest=="" ||
         snapshot.observation_sequence==0 || snapshot.observed_at<=0 ||
         snapshot.complete_summary_digest=="")
         return false;
      m_execution=snapshot;
      return true;
   }

   SWV5S5_ReferenceQuerySnapshot Broker(void) const { return m_broker; }
   SWV5S5_ReferenceQuerySnapshot Execution(void) const { return m_execution; }
};

#endif
