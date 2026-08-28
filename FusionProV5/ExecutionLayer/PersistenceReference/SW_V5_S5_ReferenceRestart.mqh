#ifndef SW_V5_S5_REFERENCE_RESTART_MQH
#define SW_V5_S5_REFERENCE_RESTART_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS

#include "SW_V5_S5_ReferenceGenesis.mqh"

struct SWV5S5_ReferenceRestartInput
{
   bool schema_valid;
   bool genesis_ready;
   bool lease_valid;
   bool persistence_valid;
   bool request_set_complete;
   bool checkpoint_matches_request_set;
   bool clean_shutdown;
   bool claimed_unresolved;
   bool broker_state_matches;
   bool execution_state_matches;
   bool hard_kill_active;
   bool hard_kill_release_record_valid;
   string persistence_namespace_digest;
   string broker_namespace_digest;
   string execution_namespace_digest;
   SWV5_AccountPositionMode persisted_account_mode;
   SWV5_AccountPositionMode broker_account_mode;
   SWV5_AccountPositionMode execution_account_mode;
   string persisted_fence_digest;
   string current_fence_digest;
   ulong broker_query_flags;
   ulong execution_query_flags;
   SWV5_ComponentAuthority broker_component;
   SWV5_AuthoritySource broker_source;
   SWV5_ComponentAuthority execution_component;
   SWV5_AuthoritySource execution_source;
   ulong broker_observation_sequence;
   ulong execution_observation_sequence;
   ulong broker_query_hwm;
   ulong execution_query_hwm;
   datetime broker_observed_at;
   datetime execution_observed_at;
   datetime validation_time;
};

struct SWV5S5_ReferenceRestartResult
{
   SWV5_RestartReadinessDisposition disposition;
   bool increasing_execution_eligible;
   bool query_union_complete;
   bool authoritative_sources_separated;
   string diagnostic;
};

bool SWV5S5_EvaluateReferenceRestart(const SWV5S5_ReferenceRestartInput &restart_input,
                                     SWV5S5_ReferenceRestartResult &result)
{
   ZeroMemory(result);
   result.disposition=SWV5_RESTART_HALTED;
   result.query_union_complete=
      restart_input.broker_query_flags==SWV5_RESTART_BROKER_QUERY_FLAGS_V5 &&
      restart_input.execution_query_flags==SWV5_RESTART_EXECUTION_QUERY_FLAGS_V5;
   result.authoritative_sources_separated=
      restart_input.broker_component==SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER &&
      restart_input.broker_source==SWV5_AUTHORITY_LIVE_BROKER_STATE &&
      restart_input.execution_component==SWV5_COMPONENT_AUTHORITY_EXECUTION &&
      restart_input.execution_source==SWV5_AUTHORITY_EXECUTION_REQUEST_STATE &&
      restart_input.persistence_namespace_digest!="" &&
      restart_input.broker_namespace_digest==restart_input.persistence_namespace_digest &&
      restart_input.execution_namespace_digest==restart_input.persistence_namespace_digest &&
      restart_input.broker_account_mode==restart_input.persisted_account_mode &&
      restart_input.execution_account_mode==restart_input.persisted_account_mode &&
      restart_input.persisted_fence_digest!="" &&
      restart_input.current_fence_digest==restart_input.persisted_fence_digest;
   if(!restart_input.schema_valid || !restart_input.genesis_ready || !restart_input.persistence_valid)
   {
      result.diagnostic="SCHEMA_GENESIS_OR_PERSISTENCE_INVALID";
      return false;
   }
   if(!restart_input.lease_valid || restart_input.claimed_unresolved)
   {
      result.disposition=SWV5_RESTART_RETRY_FORBIDDEN;
      result.diagnostic="OWNERSHIP_OR_CLAIM_UNCERTAIN";
      return false;
   }
   if(!restart_input.request_set_complete || !restart_input.checkpoint_matches_request_set ||
      !result.query_union_complete || !result.authoritative_sources_separated)
   {
      result.disposition=SWV5_RESTART_RECONCILIATION_REQUIRED;
      result.diagnostic="INCOMPLETE_OR_SPLIT_AUTHORITY";
      return false;
   }
   if(restart_input.broker_observation_sequence<=restart_input.broker_query_hwm ||
      restart_input.execution_observation_sequence<=restart_input.execution_query_hwm ||
      restart_input.broker_observed_at<=0 || restart_input.execution_observed_at<=0 ||
      restart_input.validation_time<restart_input.broker_observed_at ||
      restart_input.validation_time<restart_input.execution_observed_at ||
      restart_input.validation_time-restart_input.broker_observed_at>SWV5_MAX_RESTART_EVIDENCE_AGE_SECONDS_V5 ||
      restart_input.validation_time-restart_input.execution_observed_at>SWV5_MAX_RESTART_EVIDENCE_AGE_SECONDS_V5)
   {
      result.disposition=SWV5_RESTART_RECONCILIATION_REQUIRED;
      result.diagnostic="QUERY_FRESHNESS_OR_ANTI_REPLAY_FAILED";
      return false;
   }
   if(!restart_input.broker_state_matches || !restart_input.execution_state_matches || !restart_input.clean_shutdown)
   {
      result.disposition=SWV5_RESTART_RECONCILIATION_REQUIRED;
      result.diagnostic="STATE_NOT_CONVERGED";
      return false;
   }
   if(restart_input.hard_kill_active)
   {
      result.disposition=SWV5_RESTART_CLOSE_ONLY;
      result.diagnostic="HARD_KILL_ACTIVE";
      return false;
   }
   if(!restart_input.hard_kill_release_record_valid)
   {
      result.disposition=SWV5_RESTART_HALTED;
      result.diagnostic="RELEASE_AUTHORITY_MISSING";
      return false;
   }
   result.disposition=SWV5_RESTART_SAFE_TO_RESUME;
   result.increasing_execution_eligible=true;
   result.diagnostic="SAFE_TO_RESUME";
   return true;
}

#endif
