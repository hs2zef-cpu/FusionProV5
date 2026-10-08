#ifndef SW_V5_S5_MVP_ATTENDED_SETUP_EVIDENCE_MQH
#define SW_V5_S5_MVP_ATTENDED_SETUP_EVIDENCE_MQH
// Observational ignored evidence ONLY; no authority issuance and no Broker
// Adapter dependency. Secrets/authentication references are never exported.
#include "SW_V5_S5_MvpAccountRiskAuthority.mqh"
#include "SW_V5_S5_MvpReconciliationGovernanceAuthorities.mqh"
#include "SW_V5_S5_MvpEvidenceRecoveryAuthorities.mqh"

bool SWV5S5_MvpWriteAttendedSetupEvidence(const string path,const string ns,const string source,
   const string action,const string reason,const bool accepted,const SWV5S5_MvpRuntimeProfileObservation &profile,
   const bool acknowledged)
{
   const int h=FileOpen("fusion_v5_mvp_attended_setup_evidence.log",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(h==INVALID_HANDLE) return false;
#define SETUP_E(k,v) FileWrite(h,k,"=",v)
   SETUP_E("schema","FUSION-V5-MVP-ATTENDED-SETUP-EVIDENCE-V1"); SETUP_E("source_head",source);
   SETUP_E("runner_version","ATTENDED-SETUP-V1"); SETUP_E("mode",action); SETUP_E("fresh_acknowledged",acknowledged);
   SETUP_E("timestamp",TimeCurrent()); SETUP_E("terminal_build",TerminalInfoInteger(TERMINAL_BUILD)); SETUP_E("mql_build",__MQLBUILD__);
   SETUP_E("broker",profile.broker_identity); SETUP_E("server",profile.server); SETUP_E("account_login",profile.account_login);
   SETUP_E("account_trade_mode",profile.account_trade_mode); SETUP_E("margin_mode",(int)profile.account_mode); SETUP_E("symbol",profile.symbol);
   SETUP_E("accepted",accepted); SETUP_E("stop_reason",reason);
   SETUP_E("persistence_namespace_identity",ns);
   SWV5S5_MvpSqliteAuthorityStore readonly; SWV5S5_MvpAuthorityRow row; bool found=false;
   const bool opened=readonly.OpenReadOnly(path,ns); SETUP_E("store_readback_available",opened);
   if(opened)
   {
      if(readonly.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,row,found) && found)
      {
         SWV5_InstanceLease lease;
         if(SWV5S5_MvpDecodeOwnershipLeasePhysical(row.payload,lease))
         { SETUP_E("ownership_store_revision",lease.store_revision); SETUP_E("ownership_fence_digest",lease.fence.fencing_token_digest); }
      }
      SWV5S5_MvpManualProducerTrustProvisioner trust; SWV5S5_ProducerTrustRecord record; SWV5S5_ProducerTrustAnchor anchor;
      string operator_id,authentication;
      if(trust.ConfigureReadOnly(path,ns) && trust.LoadCurrent(record,anchor,operator_id,authentication,found) && found)
      { SETUP_E("producer_trust_record_id",record.authority_record_id); SETUP_E("producer_trust_generation",record.authority_generation);
        SETUP_E("producer_trust_digest",record.record_digest); }
      if(readonly.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",row,found) && found)
      {
         SETUP_E("safety_state",row.state); SETUP_E("safety_row_revision",row.logical_revision); SETUP_E("safety_row_digest",row.payload_digest);
         string value;
         if(SWV5S5_MvpCanonicalScalar(row.payload,"latch_id","s",value)) SETUP_E("safety_latch_id",value);
         if(SWV5S5_MvpCanonicalScalar(row.payload,"latch_generation","u",value)) SETUP_E("safety_latch_generation",value);
      }
      if(readonly.ReadRow(SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE,SWV5S5_MVP_RECONCILIATION_GOVERNANCE_KEY,row,found) && found)
      {
         SWV5S5_MvpReconciliationGovernanceBundle governance;
         if(SWV5S5_MvpDecodeGovernance(row.payload,governance) && governance.bundle_digest==row.payload_digest)
            SETUP_E("governance_bundle_digest",governance.bundle_digest);
      }
   }
   SETUP_E("request_identity","NOT_APPLICABLE_SETUP_ONLY"); SETUP_E("permit","NOT_APPLICABLE_SETUP_ONLY");
   SETUP_E("admission_pin_vector_claim","NOT_APPLICABLE_SETUP_ONLY"); SETUP_E("claim_granted_now",false);
   SETUP_E("wire_digest","NOT_APPLICABLE_SETUP_ONLY"); SETUP_E("transport_attempted",false);
   SETUP_E("request_order_deal_position_identifiers","NOT_APPLICABLE_SETUP_ONLY"); SETUP_E("callback_count",0);
   SETUP_E("broker_execution_reconciliation_observations","SEE_TYPED_PHYSICAL_SETUP_EVIDENCE_NOT_SUBMISSION_CONFIRMATION");
   SETUP_E("submission_authority_state","NOT_APPLICABLE_SETUP_ONLY"); SETUP_E("retry_allowed",false); SETUP_E("broker_submission_calls",0);
#undef SETUP_E
   FileFlush(h); FileClose(h); return true;
}
#endif
