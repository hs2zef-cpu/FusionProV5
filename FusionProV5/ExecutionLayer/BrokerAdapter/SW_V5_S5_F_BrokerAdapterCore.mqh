#ifndef SW_V5_S5_F_BROKER_ADAPTER_CORE_MQH
#define SW_V5_S5_F_BROKER_ADAPTER_CORE_MQH

// SPRINT 5 PHASE F BROKER ADAPTER PURE CORE
// PLATFORM-INDEPENDENT / NO BROKER ACCESS / NO CLAIM CREATION / NO RETRY

#include "SW_V5_S5_F_BrokerAdapterTypes.mqh"

bool SWV5S5_F_AdapterEnvironmentMatchesProfile(const SWV5S5_F_ProfileScope &profile,
                                               const SWV5S5_F_AdapterEnvironment &environment)
{
   return SWV5S5_F_IsProfileValid(profile) &&
      environment.broker_identity==profile.broker_identity &&
      environment.server==profile.server &&
      environment.account_login==profile.account_login &&
      environment.account_currency==profile.account_namespace.account_currency &&
      environment.symbol==profile.symbol &&
      environment.terminal_build==profile.terminal_build &&
      environment.mql_build==profile.mql_build &&
      environment.account_mode==profile.account_namespace.account_mode &&
      environment.runtime_magic==SWV5_RUNTIME_STRATEGY_MAGIC &&
      environment.runtime_magic==profile.account_namespace.magic &&
      environment.runtime_magic==profile.persistence_namespace.ownership_namespace.magic;
}

bool SWV5S5_F_AdapterPermissionsAllowMutation(const SWV5S5_F_AdapterEnvironment &environment)
{
   return environment.connected && environment.terminal_trade_allowed &&
      environment.mql_trade_allowed && environment.account_trade_allowed &&
      environment.account_trade_expert;
}

bool SWV5S5_F_DeriveAdapterEnvironmentDigest(const SWV5S5_F_AdapterEnvironment &environment,
                                             string &digest)
{
   string body="",f;
#define SWV5S5_F_ENV_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define SWV5S5_F_ENV_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define SWV5S5_F_ENV_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define SWV5S5_F_ENV_D(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
#define SWV5S5_F_ENV_B(n,v) if(!SWV5S5_CanonicalBool(n,v,f)) return false; else body+=f
   SWV5S5_F_ENV_S("broker",environment.broker_identity); SWV5S5_F_ENV_S("server",environment.server);
   SWV5S5_F_ENV_I("login",environment.account_login); SWV5S5_F_ENV_S("currency",environment.account_currency);
   SWV5S5_F_ENV_S("symbol",environment.symbol); SWV5S5_F_ENV_I("terminal_build",environment.terminal_build);
   SWV5S5_F_ENV_I("mql_build",environment.mql_build); SWV5S5_F_ENV_I("account_trade_mode",environment.account_trade_mode);
   SWV5S5_F_ENV_I("account_mode",environment.account_mode); SWV5S5_F_ENV_B("connected",environment.connected);
   SWV5S5_F_ENV_B("terminal_trade",environment.terminal_trade_allowed); SWV5S5_F_ENV_B("mql_trade",environment.mql_trade_allowed);
   SWV5S5_F_ENV_B("account_trade",environment.account_trade_allowed); SWV5S5_F_ENV_B("account_expert",environment.account_trade_expert);
   SWV5S5_F_ENV_I("symbol_trade_mode",environment.symbol_trade_mode); SWV5S5_F_ENV_I("execution_mode",environment.symbol_execution_mode);
   SWV5S5_F_ENV_U("filling_mask",environment.symbol_filling_mask); SWV5S5_F_ENV_I("digits",environment.symbol_digits);
   SWV5S5_F_ENV_D("point",environment.point); SWV5S5_F_ENV_D("tick_size",environment.tick_size);
   SWV5S5_F_ENV_D("volume_min",environment.volume_min); SWV5S5_F_ENV_D("volume_max",environment.volume_max);
   SWV5S5_F_ENV_D("volume_step",environment.volume_step); SWV5S5_F_ENV_U("runtime_magic",environment.runtime_magic);
#undef SWV5S5_F_ENV_S
#undef SWV5S5_F_ENV_I
#undef SWV5S5_F_ENV_U
#undef SWV5S5_F_ENV_D
#undef SWV5S5_F_ENV_B
   return SWV5S5_DomainDigest(SWV5S5_F_ADAPTER_DOMAIN_SUBMISSION,body,digest);
}

// Convert a broker-symbol numeric value to exact integer grid units. The
// tolerance is derived from the supplied symbol quantum; no raw binary-double
// equality is used for price, stop, limit, or volume authority comparisons.
bool SWV5S5_F_AdapterCanonicalGridUnits(const double value,const double quantum,
                                        const bool allow_zero,long &units)
{
   units=0;
   if(!MathIsValidNumber(value) || !MathIsValidNumber(quantum) || quantum<=0.0 || value<0.0)
      return false;
   if(value==0.0) return allow_zero;
   const double scaled=value/quantum;
   if(!MathIsValidNumber(scaled) || MathAbs(scaled)>9000000000000000.0) return false;
   const double rounded=MathRound(scaled);
   const double reconstructed=rounded*quantum;
   const double tolerance=MathMax(MathAbs(quantum)*1e-8,1e-12);
   if(!MathIsValidNumber(reconstructed) || MathAbs(value-reconstructed)>tolerance) return false;
   units=(long)rounded;
   return units>0;
}

bool SWV5S5_F_AdapterCanonicalGridEqual(const double left,const double right,
                                        const double quantum,const bool allow_zero)
{
   long left_units=0,right_units=0;
   return SWV5S5_F_AdapterCanonicalGridUnits(left,quantum,allow_zero,left_units) &&
      SWV5S5_F_AdapterCanonicalGridUnits(right,quantum,allow_zero,right_units) &&
      left_units==right_units;
}

bool SWV5S5_F_AdapterVolumeAligned(const double volume,const double minimum_volume,
                                   const double maximum_volume,const double volume_step)
{
   long volume_units=0,minimum_units=0,maximum_units=0;
   return SWV5S5_F_AdapterCanonicalGridUnits(volume,volume_step,false,volume_units) &&
      SWV5S5_F_AdapterCanonicalGridUnits(minimum_volume,volume_step,false,minimum_units) &&
      SWV5S5_F_AdapterCanonicalGridUnits(maximum_volume,volume_step,false,maximum_units) &&
      volume_units>=minimum_units && volume_units<=maximum_units;
}

// The command carries one capability flag, never a bit-mask. Combined and
// unknown values are rejected instead of being coerced to a platform default.
bool SWV5S5_F_AdapterResolveFilling(const ulong capability_flag,const ulong symbol_filling_mask,
                                   ENUM_ORDER_TYPE_FILLING &platform_filling)
{
   if(capability_flag==1 && (symbol_filling_mask & 1)==1)
   { platform_filling=ORDER_FILLING_FOK; return true; }
   if(capability_flag==2 && (symbol_filling_mask & 2)==2)
   { platform_filling=ORDER_FILLING_IOC; return true; }
   return false;
}

// For a market deal, price is an indicative request price; the broker-reported
// fill remains authoritative. stop_price and limit_price map explicitly to SL
// and TP and may be zero (absent). Nonzero protection must be tick-aligned and
// directionally coherent with the indicative price.
bool SWV5S5_F_AdapterMarketProtectionValid(const int direction,const double price,
                                           const double stop_price,const double limit_price,
                                           const double tick_size)
{
   long price_units=0,stop_units=0,limit_units=0;
   if((direction!=1 && direction!=-1) ||
      !SWV5S5_F_AdapterCanonicalGridUnits(price,tick_size,false,price_units) ||
      !SWV5S5_F_AdapterCanonicalGridUnits(stop_price,tick_size,true,stop_units) ||
      !SWV5S5_F_AdapterCanonicalGridUnits(limit_price,tick_size,true,limit_units)) return false;
   if(direction==1)
      return (stop_units==0 || stop_units<price_units) &&
         (limit_units==0 || limit_units>price_units);
   return (stop_units==0 || stop_units>price_units) &&
      (limit_units==0 || limit_units<price_units);
}

bool SWV5S5_F_AdapterEnvironmentStable(const SWV5S5_F_AdapterEnvironment &first,
                                       const SWV5S5_F_AdapterEnvironment &second)
{
   string first_digest,second_digest;
   return SWV5S5_F_DeriveAdapterEnvironmentDigest(first,first_digest) &&
      SWV5S5_F_DeriveAdapterEnvironmentDigest(second,second_digest) &&
      first_digest==second_digest;
}

bool SWV5S5_F_AdapterValidateFinalEnvironment(const SWV5S5_F_ProfileScope &profile,
                                              const SWV5S5_F_AdapterEnvironment &preflight,
                                              const SWV5S5_F_AdapterEnvironment &final_sample,
                                              string &reason_code)
{
   reason_code="FINAL_ENVIRONMENT_REATTESTATION_FAILED";
   if(!SWV5S5_F_AdapterEnvironmentMatchesProfile(profile,final_sample))
   { reason_code="FINAL_PROFILE_RESAMPLE_MISMATCH"; return false; }
   if(!SWV5S5_F_AdapterPermissionsAllowMutation(final_sample))
   { reason_code="FINAL_PERMISSION_RESAMPLE_DENIED"; return false; }
   if(!SWV5S5_F_AdapterEnvironmentStable(preflight,final_sample))
   { reason_code="FINAL_ENVIRONMENT_RESAMPLE_CHANGED"; return false; }
   reason_code="FINAL_ENVIRONMENT_REATTESTED";
   return true;
}

bool SWV5S5_F_DeriveAdapterWirePayloadDigest(const SWV5S5_F_AdapterWireRequest &wire,
                                             string &digest)
{
   string body="",f;
#define SWV5S5_F_WIRE_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define SWV5S5_F_WIRE_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define SWV5S5_F_WIRE_D(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
#define SWV5S5_F_WIRE_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
   SWV5S5_F_WIRE_I("action",wire.action); SWV5S5_F_WIRE_U("magic",wire.magic);
   SWV5S5_F_WIRE_U("order",wire.order_ticket); SWV5S5_F_WIRE_S("symbol",wire.symbol);
   SWV5S5_F_WIRE_D("volume",wire.volume); SWV5S5_F_WIRE_D("price",wire.price);
   SWV5S5_F_WIRE_D("stoplimit",wire.stop_limit_price); SWV5S5_F_WIRE_D("sl",wire.stop_loss_price);
   SWV5S5_F_WIRE_D("tp",wire.take_profit_price); SWV5S5_F_WIRE_U("deviation",wire.deviation_points);
   SWV5S5_F_WIRE_I("type",wire.order_type); SWV5S5_F_WIRE_I("type_filling",wire.filling_type);
   SWV5S5_F_WIRE_I("type_time",wire.time_type); SWV5S5_F_WIRE_I("expiration",(long)wire.expiration);
   SWV5S5_F_WIRE_S("comment",wire.comment); SWV5S5_F_WIRE_U("position",wire.position_ticket);
   SWV5S5_F_WIRE_U("position_by",wire.position_by_ticket);
   SWV5S5_F_WIRE_S("price_semantics",SWV5S5_F_MARKET_PRICE_SEMANTICS);
#undef SWV5S5_F_WIRE_I
#undef SWV5S5_F_WIRE_U
#undef SWV5S5_F_WIRE_D
#undef SWV5S5_F_WIRE_S
   return SWV5S5_DomainDigest(SWV5S5_F_ADAPTER_DOMAIN_WIRE,body,digest);
}

bool SWV5S5_F_AdapterBrokerQueryShapeComplete(const SWV5S5_F_BrokerQuerySnapshot &snapshot)
{
   if(snapshot.positions_reported_total!=(uint)ArraySize(snapshot.positions) ||
      snapshot.orders_reported_total!=(uint)ArraySize(snapshot.orders) ||
      snapshot.history_orders_reported_total!=(uint)ArraySize(snapshot.history_orders) ||
      snapshot.history_deals_reported_total!=(uint)ArraySize(snapshot.history_deals) ||
      snapshot.callback_transactions_reported_total!=(uint)ArraySize(snapshot.callback_transactions) ||
      snapshot.row_read_failures!=0 || !snapshot.positions_enumeration_complete ||
      !snapshot.orders_enumeration_complete || !snapshot.history_orders_enumeration_complete ||
      !snapshot.history_deals_enumeration_complete ||
      !snapshot.callback_transactions_enumeration_complete) return false;
   for(int i=0;i<ArraySize(snapshot.positions);i++) if(!snapshot.positions[i].read_success) return false;
   for(int i=0;i<ArraySize(snapshot.orders);i++) if(!snapshot.orders[i].read_success) return false;
   for(int i=0;i<ArraySize(snapshot.history_orders);i++) if(!snapshot.history_orders[i].read_success) return false;
   for(int i=0;i<ArraySize(snapshot.history_deals);i++) if(!snapshot.history_deals[i].read_success) return false;
   return true;
}

bool SWV5S5_F_AdapterEvidenceSourcesIndependent(const SWV5S5_F_BrokerQuerySnapshot &broker,
                                                const SWV5S5_F_ExecutionPendingSnapshot &execution)
{
   return broker.broker_read_path_id!="" && execution.execution_read_path_id!="" &&
      broker.broker_authority_instance_id!="" && execution.execution_authority_instance_id!="" &&
      broker.broker_sequence_authority_id!="" && execution.execution_sequence_authority_id!="" &&
      broker.broker_read_path_id!=execution.execution_read_path_id &&
      broker.broker_authority_instance_id!=execution.execution_authority_instance_id &&
      broker.broker_sequence_authority_id!=execution.execution_sequence_authority_id &&
      broker.query_set.snapshot_id!=execution.query_set.snapshot_id &&
      broker.query_set.snapshot_digest!=execution.query_set.snapshot_digest;
}

bool SWV5S5_F_AdapterExecutionQueryShapeComplete(
   const SWV5S5_F_ExecutionPendingSnapshot &snapshot)
{
   return snapshot.operation_success && snapshot.enumeration_complete &&
      snapshot.reported_total==snapshot.matching_pending_requests+snapshot.unrelated_rows &&
      snapshot.row_read_failures==0;
}

bool SWV5S5_F_DeriveAdapterSubmissionDigest(const SWV5S5_F_AdapterSubmissionCommand &command,
                                            string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalString("claim_id",command.authoritative_claim.resulting_authority_record.invocation_claim_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_record_digest",command.authoritative_claim.resulting_authority_record.durable_record_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("profile_digest",command.expected_profile.profile_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",command.authoritative_claim.resulting_authority_record.permit.request_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("direction",command.direction,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("volume",command.volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("price",command.price,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("stop_price",command.stop_price,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("limit_price",command.limit_price,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("filling_mode",command.filling_mode,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("runtime_magic",SWV5_RUNTIME_STRATEGY_MAGIC,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("comment_metadata",command.comment_metadata,f)) return false; body+=f;
   string environment_digest;
   if(!SWV5S5_F_DeriveAdapterEnvironmentDigest(command.observed_environment,environment_digest) ||
      !SWV5S5_CanonicalString("environment_digest",environment_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("wire_payload_digest",command.wire_payload_digest,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_F_ADAPTER_DOMAIN_SUBMISSION,body,digest);
}

SWV5S5_F_AdapterPreflightDisposition SWV5S5_F_AdapterValidatePreflight(
   const SWV5S5_F_AdapterSubmissionCommand &candidate,string &reason_code)
{
   reason_code="ADAPTER_PREFLIGHT_INVALID";
   if(!SWV5S5_F_IsVersion(candidate.contract_version) ||
      !SWV5S5_ValidateAuthoritativeClaimResult(candidate.prepared_claim,candidate.authoritative_claim))
   { reason_code="CURRENT_OPERATION_CLAIM_GRANT_REQUIRED"; return SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT; }
   const SWV5S5_SubmissionAuthorityRecord record=candidate.authoritative_claim.resulting_authority_record;
   if(!candidate.authoritative_claim.claim_granted_now ||
      candidate.authoritative_claim.disposition!=SWV5S5_CLAIM_GRANTED_NOW ||
      record.state!=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED)
   { reason_code="EPHEMERAL_CLAIM_NOT_GRANTED_NOW"; return SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT; }
   if(!SWV5S5_F_AdapterEnvironmentMatchesProfile(candidate.expected_profile,candidate.observed_environment))
   { reason_code="EXACT_BROKER_PROFILE_MISMATCH"; return SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT; }
   if(!SWV5S5_F_AdapterPermissionsAllowMutation(candidate.observed_environment))
   { reason_code="TRADING_PERMISSION_NOT_POSITIVELY_ATTESTED"; return SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT; }
   if(candidate.observed_environment.symbol_trade_mode<=0 ||
      candidate.observed_environment.symbol_execution_mode<0 ||
      !MathIsValidNumber(candidate.observed_environment.point) ||
      !MathIsValidNumber(candidate.observed_environment.tick_size) ||
      candidate.observed_environment.point<=0.0 || candidate.observed_environment.tick_size<=0.0)
   { reason_code="SYMBOL_NOT_TRADABLE_OR_SPECIFICATION_INVALID"; return SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT; }
   if(candidate.direction!=record.permit.risk_authorization.authorized_direction ||
      !SWV5S5_F_AdapterCanonicalGridEqual(candidate.volume,record.permit.normalized_payload.volume,
         candidate.observed_environment.volume_step,false) ||
      !SWV5S5_F_AdapterCanonicalGridEqual(candidate.volume,record.permit.risk_authorization.authorized_volume,
         candidate.observed_environment.volume_step,false) ||
      !SWV5S5_F_AdapterCanonicalGridEqual(candidate.price,record.permit.normalized_payload.price,
         candidate.observed_environment.tick_size,false) ||
      !SWV5S5_F_AdapterCanonicalGridEqual(candidate.stop_price,record.permit.normalized_payload.stop_price,
         candidate.observed_environment.tick_size,true) ||
      !SWV5S5_F_AdapterCanonicalGridEqual(candidate.limit_price,record.permit.normalized_payload.limit_price,
         candidate.observed_environment.tick_size,true))
   { reason_code="COMMAND_NOT_EXACTLY_BOUND_TO_PERMIT"; return SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT; }
   if(!SWV5S5_F_AdapterMarketProtectionValid(candidate.direction,candidate.price,
         candidate.stop_price,candidate.limit_price,candidate.observed_environment.tick_size) ||
      !SWV5S5_F_AdapterVolumeAligned(candidate.volume,
          candidate.observed_environment.volume_min,candidate.observed_environment.volume_max,
          candidate.observed_environment.volume_step))
   { reason_code="NORMALIZED_ORDER_PARAMETERS_INVALID"; return SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT; }
   ENUM_ORDER_TYPE_FILLING exact_filling;
   if(!SWV5S5_F_AdapterResolveFilling(candidate.filling_mode,
                                      candidate.observed_environment.symbol_filling_mask,exact_filling))
   { reason_code="FILLING_MODE_NOT_SUPPORTED"; return SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT; }
   if(!SWV5S5_IsDigest64Lower(candidate.wire_payload_digest))
   { reason_code="WIRE_PAYLOAD_DIGEST_INVALID"; return SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT; }
   string digest;
   if(!SWV5S5_F_DeriveAdapterSubmissionDigest(candidate,digest) || candidate.submission_digest!=digest)
   { reason_code="SUBMISSION_DIGEST_INVALID"; return SWV5S5_F_ADAPTER_PREFLIGHT_LOCAL_REJECT; }
   reason_code="READY_CURRENT_EPHEMERAL_CLAIM";
   return SWV5S5_F_ADAPTER_PREFLIGHT_READY_CURRENT_CLAIM;
}

SWV5S5_F_SubmissionObservationKind SWV5S5_F_AdapterObservationKind(
   const SWV5S5_F_AdapterSyncResult &result)
{
   if(!result.invocation_attempted) return SWV5S5_F_PRE_CALL_LOCAL_REJECTION;
   if(result.classification==SWV5S5_F_ADAPTER_SYNC_TRANSPORT_FAILURE_UNRESOLVED)
      return SWV5S5_F_TRANSPORT_OR_PLATFORM_FAILURE;
   if(result.classification==SWV5S5_F_ADAPTER_SYNC_UNKNOWN_UNRESOLVED)
      return SWV5S5_F_UNKNOWN_OR_UNMAPPED_RETCODE;
   if(result.classification==SWV5S5_F_ADAPTER_SYNC_MALFORMED_UNRESOLVED)
      return SWV5S5_F_MALFORMED_OR_PARTIAL_RESPONSE;
   if(result.classification==SWV5S5_F_ADAPTER_SYNC_CLIENT_LOCAL_REJECTION_UNRESOLVED)
      return SWV5S5_F_CLIENT_LOCAL_POST_INVOCATION_REJECTION;
   if(result.classification==SWV5S5_F_ADAPTER_SYNC_BROKER_REJECTION_CANDIDATE_UNRESOLVED)
      return SWV5S5_F_BROKER_EXPLICIT_REJECTION_CANDIDATE;
   if(result.classification==SWV5S5_F_ADAPTER_SYNC_TIMEOUT_UNRESOLVED)
      return SWV5S5_F_TIMEOUT;
   return SWV5S5_F_ACCEPTED_SUBMISSION;
}

// All post-invocation synchronous outcomes remain unresolved. No retcode,
// ticket, request id, transport return or comment is final confirmation.
SWV5S5_F_AdapterSyncClassification SWV5S5_F_AdapterClassifySync(
   const bool invocation_attempted,const bool transport_result,const uint retcode)
{
   if(!invocation_attempted) return SWV5S5_F_ADAPTER_SYNC_PRE_CALL_REJECTED;
   if(retcode==10027) return SWV5S5_F_ADAPTER_SYNC_CLIENT_LOCAL_REJECTION_UNRESOLVED;
   if(retcode==10012) return SWV5S5_F_ADAPTER_SYNC_TIMEOUT_UNRESOLVED;
   if((retcode==10008 || retcode==10009 || retcode==10010) && transport_result)
      return SWV5S5_F_ADAPTER_SYNC_ACCEPTED_UNRESOLVED;
   if((retcode>=10004 && retcode<=10007) || (retcode>=10011 && retcode<=10046))
      return SWV5S5_F_ADAPTER_SYNC_BROKER_REJECTION_CANDIDATE_UNRESOLVED;
   if(!transport_result) return SWV5S5_F_ADAPTER_SYNC_TRANSPORT_FAILURE_UNRESOLVED;
   if(retcode==0) return SWV5S5_F_ADAPTER_SYNC_MALFORMED_UNRESOLVED;
   return SWV5S5_F_ADAPTER_SYNC_UNKNOWN_UNRESOLVED;
}

bool SWV5S5_F_DeriveAdapterSyncResultDigest(const SWV5S5_F_AdapterSyncResult &result,string &digest)
{
   string body="",f;
#define SWV5S5_F_ASR_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define SWV5S5_F_ASR_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define SWV5S5_F_ASR_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define SWV5S5_F_ASR_D(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
#define SWV5S5_F_ASR_B(n,v) if(!SWV5S5_CanonicalBool(n,v,f)) return false; else body+=f
   SWV5S5_F_ASR_B("invocation_attempted",result.invocation_attempted);
   SWV5S5_F_ASR_B("transport_result",result.transport_result);
   SWV5S5_F_ASR_I("last_error",result.last_error); SWV5S5_F_ASR_U("retcode",result.retcode);
   SWV5S5_F_ASR_U("retcode_external",result.retcode_external); SWV5S5_F_ASR_U("request_id",result.request_id_session_local);
   SWV5S5_F_ASR_U("order",result.order_ticket); SWV5S5_F_ASR_U("deal",result.deal_ticket);
   SWV5S5_F_ASR_D("volume",result.volume); SWV5S5_F_ASR_D("price",result.price);
   SWV5S5_F_ASR_D("bid",result.bid); SWV5S5_F_ASR_D("ask",result.ask);
   SWV5S5_F_ASR_S("comment",result.comment); SWV5S5_F_ASR_I("classification",result.classification);
   SWV5S5_F_ASR_B("final_confirmation",result.final_confirmation); SWV5S5_F_ASR_B("retry_allowed",result.retry_allowed);
   SWV5S5_F_ASR_S("claim_id",result.claim_id); SWV5S5_F_ASR_S("claim_record_digest",result.claim_record_digest);
   SWV5S5_F_ASR_S("request_correlation_id",result.request_correlation_id); SWV5S5_F_ASR_S("attempt_id",result.attempt_id);
   SWV5S5_F_ASR_S("profile_digest",result.profile_digest);
   SWV5S5_F_ASR_S("environment_digest",result.observed_environment_digest);
   SWV5S5_F_ASR_S("reason_code",result.reason_code);
#undef SWV5S5_F_ASR_S
#undef SWV5S5_F_ASR_U
#undef SWV5S5_F_ASR_I
#undef SWV5S5_F_ASR_D
#undef SWV5S5_F_ASR_B
   return SWV5S5_DomainDigest(SWV5S5_F_ADAPTER_DOMAIN_SUBMISSION,body,digest);
}

bool SWV5S5_F_DeriveCallbackDigest(const SWV5S5_F_AdapterCallbackEvidence &evidence,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalString("request_correlation_id",evidence.request_correlation_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("attempt_id",evidence.attempt_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_id",evidence.invocation_claim_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_record_digest",evidence.claim_record_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("profile_digest",evidence.profile_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("callback_sequence",evidence.callback_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",evidence.observed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("transaction_type",evidence.transaction_type,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("order",evidence.order_ticket,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("deal",evidence.deal_ticket,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("position",evidence.position_identifier,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("position_by",evidence.position_by_identifier,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("symbol",evidence.symbol,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("order_type",evidence.order_type,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("order_state",evidence.order_state,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("deal_type",evidence.deal_type,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("price",evidence.price,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("volume",evidence.volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("request_action",evidence.request_action,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("request_magic",evidence.request_magic,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("request_comment",evidence.request_comment,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("result_retcode",evidence.result_retcode,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("result_retcode_external",evidence.result_retcode_external,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("request_id",evidence.request_id_session_local,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("final_confirmation",evidence.final_confirmation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("retry_allowed",evidence.retry_allowed,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_F_ADAPTER_DOMAIN_CALLBACK,body,digest);
}

bool SWV5S5_F_DeriveReconciliationPublicationDigest(
   const SWV5S5_F_ReconciliationPublication &publication,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalString("profile_digest",publication.binding.profile.profile_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",publication.binding.request_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_id",publication.binding.invocation_claim_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_record_digest",publication.binding.claim_record_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("result_digest",publication.result.result_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("current_publication_fence",publication.current_publication_lease.fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("expected_store_revision",publication.expected_store_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expected_reconciliation_revision",publication.expected_reconciliation_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("proposed_reconciliation_revision",publication.proposed_reconciliation_revision,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_F_ADAPTER_DOMAIN_PUBLICATION,body,digest);
}

bool SWV5S5_F_AdapterValidatePublication(const SWV5_ContractValidationContext &context,
                                         const SWV5S5_F_ReconciliationPublication &publication)
{
   string result_digest,publication_digest;
   return SWV5S5_F_IsVersion(publication.contract_version) &&
      SWV5S5_F_IsBindingValid(context,publication.binding) &&
      SWV5S5_F_IsCurrentLeaseValid(context,publication.current_publication_lease) &&
      SWV5S5_EqualFence(publication.current_publication_lease.fence,
                        publication.binding.current_reconciliation_lease.fence) &&
      SWV5S5_EqualOwnershipKey(publication.current_publication_lease.fence.ownership_namespace,
         publication.binding.profile.persistence_namespace.ownership_namespace) &&
      publication.current_publication_lease.store_revision==publication.expected_store_revision &&
      publication.expected_store_revision==publication.binding.expected_store_revision &&
      publication.expected_reconciliation_revision==publication.binding.expected_reconciliation_revision &&
      publication.expected_reconciliation_revision<18446744073709551615 &&
      publication.proposed_reconciliation_revision==publication.expected_reconciliation_revision+1 &&
      !publication.result.retry_allowed && !publication.result.residual_is_submission_authority &&
      SWV5S5_F_DeriveResultDigest(publication.result,result_digest) &&
      publication.result.result_digest==result_digest &&
      SWV5S5_F_DeriveReconciliationPublicationDigest(publication,publication_digest) &&
      publication.publication_digest==publication_digest;
}

#endif // SW_V5_S5_F_BROKER_ADAPTER_CORE_MQH
