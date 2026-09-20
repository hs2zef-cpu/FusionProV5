#ifndef SW_V5_S5_MVP_CONTROLLED_DEMO_RUNNER_MQH
#define SW_V5_S5_MVP_CONTROLLED_DEMO_RUNNER_MQH

// CONTROLLED DEMO MVP — ORCHESTRATOR ONLY.
// This host grants no authority. All authority decisions are delegated to the
// accepted providers, and all broker mutation remains in BrokerPlatformBoundary.

#include "SW_V5_S5_MvpManualDemoSetup.mqh"
#include "../BrokerAdapter/SW_V5_S5_F_BrokerAdapter.mqh"

const string SWV5S5_MVP_CONTROLLED_DEMO_RUNNER_VERSION="FUSION-V5-MVP-CONTROLLED-DEMO-RUNNER-V1";

enum SWV5S5_MvpControlledDemoMode
{
   MODE_PREFLIGHT=0,
   MODE_D1_BUY=1,
   MODE_D6_RECOVER=2,
   MODE_D3_SELL=3
};

struct SWV5S5_MvpControlledDemoInvocation
{
   SWV5S5_MvpControlledDemoMode mode;
   bool armed_for_demo_submission;
   bool operator_confirmed_before_claim;
   string expected_broker_identity;
   string expected_server;
   long expected_demo_account_login;
   string persistence_namespace_identity;
   string relative_store_path;
   string source_head;
   string evidence_relative_path;
   double requested_volume;
   double requested_price;
   double protective_stop_price;
   double optional_take_profit_price;
};

void SWV5S5_MvpControlledDemoDefaults(SWV5S5_MvpControlledDemoInvocation &invocation)
{
   ZeroMemory(invocation);
   invocation.mode=MODE_PREFLIGHT;
   invocation.armed_for_demo_submission=false;
   invocation.operator_confirmed_before_claim=false;
   invocation.requested_volume=SWV5S5_MVP_MAX_VOLUME;
}

struct SWV5S5_MvpControlledDemoPreflightEvidence
{
   bool profile_exact;
   bool demo_account;
   bool usd_account;
   bool hedging_account;
   bool symbol_exact;
   bool connected;
   bool permissions_observed;
   bool store_schema_valid;
   bool genesis_valid;
   bool ownership_current;
   bool trust_complete;
   bool trust_current_unexpired;
   bool safety_allows_execution;
   bool broker_observation_complete;
   bool execution_observation_complete;
   bool no_position;
   bool no_active_order;
   bool no_unresolved_submission;
   bool no_competing_operation;
   bool symbol_specification_fresh;
   bool units_valid;
   bool margin_valid;
   bool basket_risk_valid;
   bool risk_inputs_valid;
   bool protective_stop_valid;
   bool prospective_permit_preparable;
   bool d1_terminal;
   bool manual_cleanup_independently_observed;
   bool independent_request_identity;
   string request_correlation_id;
   string attempt_id;
};

bool SWV5S5_MvpControlledDemoPreflightValid(const SWV5S5_MvpControlledDemoPreflightEvidence &e)
{
   return e.profile_exact && e.demo_account && e.usd_account && e.hedging_account &&
      e.symbol_exact && e.connected && e.permissions_observed && e.store_schema_valid &&
      e.genesis_valid && e.ownership_current && e.trust_complete && e.trust_current_unexpired &&
      e.safety_allows_execution && e.broker_observation_complete &&
      e.execution_observation_complete && e.no_position && e.no_active_order &&
      e.no_unresolved_submission && e.no_competing_operation && e.symbol_specification_fresh &&
      e.units_valid && e.margin_valid && e.basket_risk_valid && e.risk_inputs_valid &&
      e.protective_stop_valid && e.prospective_permit_preparable;
}

struct SWV5S5_MvpControlledDemoRecoveryEvidence
{
   bool store_schema_valid;
   bool ownership_reloaded_from_sqlite;
   bool ownership_current;
   bool exact_unresolved_claim_found;
   bool complete_claim_reloaded_from_sqlite;
   bool claim_granted_now;
   bool broker_observation_complete;
   bool execution_observation_complete;
   bool reconciliation_evaluated;
   bool reconciliation_published;
   bool exact_record_terminalized;
   bool terminal_readback_verified;
   string request_correlation_id;
   string attempt_id;
};

class SWV5S5_MvpControlledDemoD6OwnershipLoader
{
public:
   bool ReloadCurrent(const string relative_store_path,const string namespace_digest,
                      const SWV5_OwnershipKey &expected_ownership_namespace,
                      const SWV5_OwnershipFence &expected_fence,
                      const SWV5_ContractValidationContext &current_context,
                      SWV5_InstanceLease &lease,SWV5S5_MvpAuthorityRow &physical_row)
   {
      ZeroMemory(lease); ZeroMemory(physical_row);
      SWV5S5_MvpSqliteAuthorityStore store;
      SWV5S5_MvpLeasePublicationAuthority authority;
      SWV5_InstanceLease persisted_lease; SWV5S5_MvpAuthorityRow persisted_row;
      if(!store.Open(relative_store_path,namespace_digest) ||
         !authority.LoadCurrentLease(store,expected_ownership_namespace,expected_fence,
                                     persisted_lease,persisted_row) ||
         !SWV5S5_MvpLeaseCurrentForClock(current_context,expected_fence,persisted_lease)) return false;
      lease=persisted_lease; physical_row=persisted_row;
      return true;
   }
};

struct SWV5S5_MvpControlledDemoResult
{
   bool accepted;
   bool host_latch_set_before_claim;
   bool permit_prepared;
   bool permit_committed;
   bool admission_succeeded;
   bool claim_attempted;
   bool claim_granted_now;
   bool adapter_invoked_same_event;
   bool recovery_complete;
   uint broker_submission_calls;
   string stop_reason;
   string request_correlation_id;
   string attempt_id;
   SWV5S5_F_AdapterSyncResult synchronous_result;
};

struct SWV5S5_MvpControlledDemoEvidence
{
   string source_head;
   string runner_version;
   int mode;
   bool armed;
   datetime timestamp;
   int terminal_build;
   int mql_build;
   string broker;
   string server;
   long account_login;
   int account_trade_mode;
   int margin_mode;
   string symbol;
   ulong symbol_specification_sequence;
   string symbol_specification_digest;
   string ownership_lease_id;
   string ownership_fence_digest;
   string producer_trust_record_id;
   ulong producer_trust_generation;
   string producer_trust_digest;
   string safety_latch_id;
   ulong safety_latch_generation;
   string request_correlation_id;
   string attempt_id;
   string permit_id;
   string permit_digest;
   string admission_snapshot_digest;
   string claim_id;
   string claimed_record_digest;
   bool claim_granted_now;
   string submission_payload_digest;
   string wire_digest;
   bool transport_attempted;
   bool transport_result;
   int last_error;
   uint retcode;
   ulong request_id;
   ulong order_ticket;
   ulong deal_ticket;
   ulong position_identifier;
   uint callback_count;
   ulong broker_observation_sequence;
   bool broker_observation_complete;
   uint broker_row_failures;
   ulong execution_observation_sequence;
   bool execution_observation_complete;
   uint execution_row_failures;
   int reconciliation_state;
   string reconciliation_result_digest;
   int submission_authority_state;
   bool retry_allowed;
   bool residual_is_submission_authority;
   uint broker_submission_calls;
};

// Runtime evidence is an ignored .log artifact in FILE_COMMON. Authentication
// references and other secrets are intentionally absent from this schema.
bool SWV5S5_MvpWriteControlledDemoEvidence(const string relative_path,
                                           const SWV5S5_MvpControlledDemoEvidence &evidence)
{
   if(relative_path=="" || StringFind(relative_path,"..")>=0 ||
      StringSubstr(relative_path,StringLen(relative_path)-4)!=".log") return false;
   const int handle=FileOpen(relative_path,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(handle==INVALID_HANDLE) return false;
#define CD_EVIDENCE(k,v) FileWrite(handle,k,"=",v)
   CD_EVIDENCE("schema","FUSION-V5-MVP-CONTROLLED-DEMO-EVIDENCE-V1");
   CD_EVIDENCE("source_head",evidence.source_head);
   CD_EVIDENCE("runner_version",evidence.runner_version);
   CD_EVIDENCE("mode",evidence.mode); CD_EVIDENCE("armed",evidence.armed);
   CD_EVIDENCE("timestamp",evidence.timestamp); CD_EVIDENCE("terminal_build",evidence.terminal_build);
   CD_EVIDENCE("mql_build",evidence.mql_build); CD_EVIDENCE("broker",evidence.broker);
   CD_EVIDENCE("server",evidence.server); CD_EVIDENCE("account_login",evidence.account_login);
   CD_EVIDENCE("account_trade_mode",evidence.account_trade_mode); CD_EVIDENCE("margin_mode",evidence.margin_mode);
   CD_EVIDENCE("symbol",evidence.symbol); CD_EVIDENCE("symbol_specification_sequence",evidence.symbol_specification_sequence);
   CD_EVIDENCE("symbol_specification_digest",evidence.symbol_specification_digest);
   CD_EVIDENCE("ownership_lease_id",evidence.ownership_lease_id); CD_EVIDENCE("ownership_fence_digest",evidence.ownership_fence_digest);
   CD_EVIDENCE("producer_trust_record_id",evidence.producer_trust_record_id); CD_EVIDENCE("producer_trust_generation",evidence.producer_trust_generation);
   CD_EVIDENCE("producer_trust_digest",evidence.producer_trust_digest); CD_EVIDENCE("safety_latch_id",evidence.safety_latch_id);
   CD_EVIDENCE("safety_latch_generation",evidence.safety_latch_generation); CD_EVIDENCE("request_correlation_id",evidence.request_correlation_id);
   CD_EVIDENCE("attempt_id",evidence.attempt_id); CD_EVIDENCE("permit_id",evidence.permit_id);
   CD_EVIDENCE("permit_digest",evidence.permit_digest); CD_EVIDENCE("admission_snapshot_digest",evidence.admission_snapshot_digest);
   CD_EVIDENCE("claim_id",evidence.claim_id); CD_EVIDENCE("claimed_record_digest",evidence.claimed_record_digest);
   CD_EVIDENCE("claim_granted_now",evidence.claim_granted_now); CD_EVIDENCE("submission_payload_digest",evidence.submission_payload_digest);
   CD_EVIDENCE("wire_digest",evidence.wire_digest); CD_EVIDENCE("transport_attempted",evidence.transport_attempted);
   CD_EVIDENCE("transport_result",evidence.transport_result); CD_EVIDENCE("last_error",evidence.last_error);
   CD_EVIDENCE("retcode",evidence.retcode); CD_EVIDENCE("request_id",evidence.request_id);
   CD_EVIDENCE("order_ticket",evidence.order_ticket); CD_EVIDENCE("deal_ticket",evidence.deal_ticket);
   CD_EVIDENCE("position_identifier",evidence.position_identifier); CD_EVIDENCE("callback_count",evidence.callback_count);
   CD_EVIDENCE("broker_observation_sequence",evidence.broker_observation_sequence); CD_EVIDENCE("broker_observation_complete",evidence.broker_observation_complete);
   CD_EVIDENCE("broker_row_failures",evidence.broker_row_failures); CD_EVIDENCE("execution_observation_sequence",evidence.execution_observation_sequence);
   CD_EVIDENCE("execution_observation_complete",evidence.execution_observation_complete); CD_EVIDENCE("execution_row_failures",evidence.execution_row_failures);
   CD_EVIDENCE("reconciliation_state",evidence.reconciliation_state); CD_EVIDENCE("reconciliation_result_digest",evidence.reconciliation_result_digest);
   CD_EVIDENCE("submission_authority_state",evidence.submission_authority_state); CD_EVIDENCE("retry_allowed",evidence.retry_allowed);
   CD_EVIDENCE("residual_is_submission_authority",evidence.residual_is_submission_authority);
   CD_EVIDENCE("broker_submission_calls",evidence.broker_submission_calls);
#undef CD_EVIDENCE
   FileFlush(handle); FileClose(handle); return true;
}

// Implemented by the accepted provider graph. It may collect observations and
// execute authority CAS operations, but it is not itself an authority.
class ISWV5S5_MvpControlledDemoAuthorityPort
{
public:
   virtual bool CollectPreflight(const SWV5S5_MvpControlledDemoInvocation &invocation,
                                 const int direction,
                                 SWV5S5_MvpControlledDemoPreflightEvidence &evidence)=0;
   virtual bool PreparePermitSemantics(void)=0;
   virtual bool CommitPermitPhysical(void)=0;
   virtual bool CollectAdmissionSameEvent(void)=0;
   virtual bool ClaimPhysicalNow(bool &claim_granted_now)=0;
   virtual bool ReloadAndReconcileD6(SWV5S5_MvpControlledDemoRecoveryEvidence &evidence)=0;
   virtual bool ObserveCallbackOnly(const MqlTradeTransaction &transaction,
                                    const MqlTradeRequest &request,
                                    const MqlTradeResult &result)=0;
   virtual bool BuildAdapterCommand(SWV5S5_F_AdapterSubmissionCommand &command,
                                    ISWV5S5FBrokerEvidenceStore* &evidence_store)=0;
};

// The production binding can only delegate to the accepted BrokerPlatformBoundary.
// Tests substitute a non-mutating seam implementing this same interface.
class ISWV5S5_MvpControlledDemoSubmissionBoundary
{
public:
   virtual bool SubmitExactlyOnce(SWV5S5_F_AdapterSubmissionCommand &command,
                                  ISWV5S5FBrokerEvidenceStore &evidence_store,
                                  SWV5S5_F_AdapterSyncResult &captured)=0;
};

class SWV5S5_MvpControlledDemoBrokerBoundary : public ISWV5S5_MvpControlledDemoSubmissionBoundary
{
private:
   SWV5S5_F_BrokerPlatformAdapter *m_adapter;
public:
   SWV5S5_MvpControlledDemoBrokerBoundary(SWV5S5_F_BrokerPlatformAdapter *adapter)
   { m_adapter=adapter; }
   virtual bool SubmitExactlyOnce(SWV5S5_F_AdapterSubmissionCommand &command,
                                  ISWV5S5FBrokerEvidenceStore &evidence_store,
                                  SWV5S5_F_AdapterSyncResult &captured)
   {
      return m_adapter!=NULL && m_adapter.SubmitExactlyOnce(command,evidence_store,captured);
   }
};

class SWV5S5_MvpControlledDemoRunner
{
private:
   bool m_host_one_shot_consumed;
   uint m_broker_submission_calls;

   bool InvocationShapeValid(const SWV5S5_MvpControlledDemoInvocation &invocation) const
   {
      if(invocation.expected_broker_identity=="" || invocation.expected_server=="" ||
         invocation.expected_demo_account_login<=0 || invocation.persistence_namespace_identity=="" ||
         invocation.relative_store_path=="" || invocation.source_head=="") return false;
      if(invocation.mode==MODE_D1_BUY || invocation.mode==MODE_D3_SELL)
         return invocation.requested_volume>0.0 && invocation.requested_volume<=SWV5S5_MVP_MAX_VOLUME &&
            invocation.requested_price>0.0 && invocation.protective_stop_price>0.0 &&
            (invocation.mode==MODE_D1_BUY ? invocation.protective_stop_price<invocation.requested_price :
                                           invocation.protective_stop_price>invocation.requested_price);
      return true;
   }

public:
   SWV5S5_MvpControlledDemoRunner(void)
   { m_host_one_shot_consumed=false; m_broker_submission_calls=0; }

   bool HostLatchConsumed(void) const { return m_host_one_shot_consumed; }
   uint BrokerSubmissionCalls(void) const { return m_broker_submission_calls; }

   bool Run(const SWV5S5_MvpControlledDemoInvocation &invocation,
            ISWV5S5_MvpControlledDemoAuthorityPort &authority,
            ISWV5S5_MvpControlledDemoSubmissionBoundary &submission_boundary,
            SWV5S5_MvpControlledDemoResult &result)
   {
      ZeroMemory(result);
      result.broker_submission_calls=m_broker_submission_calls;
      if(!InvocationShapeValid(invocation))
      { result.stop_reason="RUNNER_INVOCATION_INVALID"; return false; }

      if(invocation.mode==MODE_D6_RECOVER)
      {
         SWV5S5_MvpControlledDemoRecoveryEvidence recovery;
         if(!authority.ReloadAndReconcileD6(recovery) || !recovery.store_schema_valid ||
            !recovery.ownership_reloaded_from_sqlite || !recovery.ownership_current ||
            !recovery.exact_unresolved_claim_found ||
            !recovery.complete_claim_reloaded_from_sqlite || recovery.claim_granted_now ||
            !recovery.broker_observation_complete || !recovery.execution_observation_complete ||
            !recovery.reconciliation_evaluated || !recovery.reconciliation_published ||
            !recovery.exact_record_terminalized || !recovery.terminal_readback_verified)
         { result.stop_reason="D6_RECOVERY_NOT_AUTHORITATIVELY_COMPLETE"; return false; }
         result.recovery_complete=true;
         result.request_correlation_id=recovery.request_correlation_id;
         result.attempt_id=recovery.attempt_id;
         result.accepted=true;
         result.stop_reason="D6_RECOVERY_COMPLETE_ZERO_SUBMISSION";
         result.broker_submission_calls=m_broker_submission_calls;
         return m_broker_submission_calls==0;
      }

      const int direction=(invocation.mode==MODE_D3_SELL ? -1 : 1);
      SWV5S5_MvpControlledDemoPreflightEvidence preflight;
      if(!authority.CollectPreflight(invocation,direction,preflight) ||
         !SWV5S5_MvpControlledDemoPreflightValid(preflight))
      { result.stop_reason="PREFLIGHT_FAILED_CLOSED"; return false; }
      result.request_correlation_id=preflight.request_correlation_id;
      result.attempt_id=preflight.attempt_id;

      // Preflight is semantic only: never physically commit Permit or Claim.
      if(invocation.mode==MODE_PREFLIGHT)
      {
         result.accepted=true;
         result.stop_reason="PREFLIGHT_COMPLETE_ZERO_SUBMISSION";
         result.broker_submission_calls=m_broker_submission_calls;
         return m_broker_submission_calls==0;
      }

      if(invocation.mode!=MODE_D1_BUY && invocation.mode!=MODE_D3_SELL)
      { result.stop_reason="RUNNER_MODE_UNSUPPORTED"; return false; }
      if(!invocation.armed_for_demo_submission)
      { result.stop_reason="DEMO_SUBMISSION_NOT_ARMED"; return false; }
      if(!invocation.operator_confirmed_before_claim)
      { result.stop_reason="OPERATOR_CONFIRMATION_REQUIRED_BEFORE_CLAIM"; return false; }
      if(invocation.mode==MODE_D3_SELL &&
         (!preflight.d1_terminal || !preflight.manual_cleanup_independently_observed ||
          !preflight.independent_request_identity))
      { result.stop_reason="D3_PREDECESSOR_NOT_TERMINAL_AND_CLEAN"; return false; }
      if(m_host_one_shot_consumed)
      { result.stop_reason="HOST_ONE_SHOT_ALREADY_CONSUMED"; return false; }

      // The latch is consumed before any physical authority mutation. Nothing in
      // this object resets it. The remainder is one synchronous stack frame.
      m_host_one_shot_consumed=true;
      result.host_latch_set_before_claim=true;
      if(!authority.PreparePermitSemantics())
      { result.stop_reason="PERMIT_PREPARATION_FAILED"; return false; }
      result.permit_prepared=true;
      if(!authority.CommitPermitPhysical())
      { result.stop_reason="PERMIT_COMMIT_FAILED"; return false; }
      result.permit_committed=true;
      if(!authority.CollectAdmissionSameEvent())
      { result.stop_reason="ADMISSION_FAILED"; return false; }
      result.admission_succeeded=true;
      bool granted_now=false;
      result.claim_attempted=true;
      if(!authority.ClaimPhysicalNow(granted_now) || !granted_now)
      { result.stop_reason="CLAIM_NOT_GRANTED_NOW"; return false; }
      result.claim_granted_now=true;

      SWV5S5_F_AdapterSubmissionCommand command;
      ISWV5S5FBrokerEvidenceStore *evidence_store=NULL;
      if(!authority.BuildAdapterCommand(command,evidence_store) || evidence_store==NULL)
      { result.stop_reason="ADAPTER_COMMAND_BUILD_FAILED_AFTER_CLAIM"; return false; }
      result.adapter_invoked_same_event=true;
      const bool submitted=submission_boundary.SubmitExactlyOnce(command,evidence_store,
                                                                  result.synchronous_result);
      if(result.synchronous_result.invocation_attempted) m_broker_submission_calls++;
      result.broker_submission_calls=m_broker_submission_calls;
      result.accepted=submitted;
      result.stop_reason=(submitted ? "SYNC_EVIDENCE_PERSISTED_RECONCILIATION_REQUIRED" :
                                      "BROKER_BOUNDARY_RETURNED_FAILURE_NO_RETRY");
      return submitted;
   }

   // Event handlers are structurally non-authoritative.
   bool OnTick(void) { return false; }
   bool OnTimer(void) { return false; }
   bool OnChartEvent(void) { return false; }

   bool OnTradeTransaction(const MqlTradeTransaction &transaction,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result,
                           ISWV5S5_MvpControlledDemoAuthorityPort &authority)
   { return authority.ObserveCallbackOnly(transaction,request,result); }
};

#endif // SW_V5_S5_MVP_CONTROLLED_DEMO_RUNNER_MQH
