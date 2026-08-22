#ifndef SW_V5_S5_SUBMISSION_AUTHORITY_CONTRACT_MQH
#define SW_V5_S5_SUBMISSION_AUTHORITY_CONTRACT_MQH

// SPRINT 5 PHASE B.1 CANDIDATE CONTRACT
// PURE PERMIT PREPARATION + ABSTRACT COMMIT AUTHORITY / NO BROKER OR STORE

#include "SW_V5_S5_RuntimePublicationContract.mqh"

struct SWV5S5_SubmissionPermit
{
   SWV5_ContractVersion contract_version;
   string permit_policy_id;
   uint permit_policy_version;
   string canonical_format_id;
   string permit_id;
   ulong permit_revision;
   datetime reserved_at;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   SWV5_AccountRiskNamespace account_namespace;
   ulong account_epoch;
   SWV5_AccountPositionMode account_mode;
   SWV5_ExecutionRequestIdentity request_identity;
   string unique_attempt_id;
   SWV5_NormalizedUnits normalized_payload;
   string normalization_identity;
   ulong symbol_specification_sequence;
   SWV5_BasketID basket_id;
   ulong basket_state_version;
   SWV5S5_ProducerTrustRecord producer_trust;
   SWV5_RiskAuthorization risk_authorization;
   SWV5_MarginAuthorityRecord margin_authority;
   SWV5_BasketRiskAuthorityRecord basket_risk_authority;
   string hard_kill_latch_id;
   ulong hard_kill_latch_generation;
   datetime valid_from;
   datetime valid_until;
   string permit_digest;
};

struct SWV5S5_SubmissionAuthorityRecord
{
   SWV5_ContractVersion contract_version;
   SWV5S5_SubmissionPermit permit;
   SWV5S5_SubmissionAuthorityState state;
   ulong authority_revision;
   string invocation_claim_id;
   SWV5_InstanceLease claim_ownership_lease;
   datetime claimed_at;
   string claim_clock_id;
   SWV5_TimeAuthority claim_clock_authority;
   ulong claim_clock_sequence;
   string admission_snapshot_digest;
   string claim_policy_id;
   uint claim_policy_version;
   string durable_record_digest;
};

struct SWV5S5_SubmissionAuthorityIndexEntry
{
   string logical_correlation_id;
   string attempt_id;
   string permit_id;
   string permit_digest;
   SWV5S5_SubmissionAuthorityState state;
   ulong authority_revision;
   string durable_record_digest;
};

struct SWV5S5_PermitPreparationCommand
{
   SWV5_ContractVersion contract_version;
   string expected_index_digest;
   ulong expected_index_revision;
   SWV5S5_SubmissionPermit proposed_permit;
   string command_digest;
};

struct SWV5S5_PermitPreparationResult
{
   SWV5_ContractVersion contract_version;
   SWV5S5_PermitDisposition disposition;
   SWV5S5_SubmissionAuthorityRecord proposed_record;
   string reason_code;
};

bool SWV5S5_CanonicalNormalizedPayload(const string name,const SWV5_NormalizedUnits &units,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",units.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",units.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",units.ownership_fence,f)) return false; body+=f;
#define SWV5S5_NP_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define SWV5S5_NP_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define SWV5S5_NP_D(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
#define SWV5S5_NP_B(n,v) if(!SWV5S5_CanonicalBool(n,v,f)) return false; else body+=f
   SWV5S5_NP_I("semantic",units.derived_operation_semantic);
   SWV5S5_NP_D("price",units.price); SWV5S5_NP_D("stop_price",units.stop_price);
   SWV5S5_NP_D("limit_price",units.limit_price); SWV5S5_NP_D("volume",units.volume);
   SWV5S5_NP_D("current_exposure_volume",units.current_exposure_volume);
   SWV5S5_NP_D("target_exposure_volume",units.target_exposure_volume);
   SWV5S5_NP_D("resulting_exposure_volume",units.resulting_exposure_volume);
   SWV5S5_NP_D("residual_exposure_volume",units.residual_exposure_volume);
   SWV5S5_NP_D("stop_distance_price",units.stop_distance_price);
   SWV5S5_NP_D("stop_distance_points",units.stop_distance_points);
   SWV5S5_NP_D("stop_distance_ticks",units.stop_distance_ticks);
   SWV5S5_NP_D("monetary_tick_value",units.monetary_tick_value_per_volume_unit);
   if(!SWV5S5_CanonicalString("monetary_currency",units.monetary_value_currency,f)) return false; body+=f;
   SWV5S5_NP_U("specification_sequence",units.specification_sequence);
   SWV5S5_NP_I("entry_rounding",units.applied_entry_rounding); SWV5S5_NP_I("stop_rounding",units.applied_stop_rounding);
   SWV5S5_NP_I("limit_rounding",units.applied_limit_rounding); SWV5S5_NP_I("volume_rounding",units.applied_volume_rounding);
   SWV5S5_NP_B("price_aligned",units.price_aligned_to_tick); SWV5S5_NP_B("volume_aligned",units.volume_aligned_to_step);
   SWV5S5_NP_B("stops_satisfied",units.stops_level_satisfied); SWV5S5_NP_B("freeze_satisfied",units.freeze_level_satisfied);
   SWV5S5_NP_B("caller_flags_consistent",units.caller_flags_consistent);
#undef SWV5S5_NP_I
#undef SWV5S5_NP_U
#undef SWV5S5_NP_D
#undef SWV5S5_NP_B
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalAccountNamespace(const string name,const SWV5_AccountRiskNamespace &account,string &field)
{
   string body="",f;
#define SWV5S5_CA_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define SWV5S5_CA_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define SWV5S5_CA_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("version",account.contract_version,f)) return false; body+=f;
   SWV5S5_CA_S("broker_identity",account.broker_identity); SWV5S5_CA_S("server",account.server);
   SWV5S5_CA_I("account_login",account.account_login); SWV5S5_CA_S("account_currency",account.account_currency);
   SWV5S5_CA_S("strategy_id",account.strategy_id); SWV5S5_CA_U("magic",account.magic);
   SWV5S5_CA_I("account_mode",account.account_mode); SWV5S5_CA_I("authoritative_source",account.authoritative_source);
   SWV5S5_CA_U("snapshot_epoch",account.snapshot_epoch); SWV5S5_CA_U("snapshot_sequence",account.snapshot_sequence);
#undef SWV5S5_CA_S
#undef SWV5S5_CA_I
#undef SWV5S5_CA_U
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalRiskLimits(const string name,const SWV5_RiskLimits &limits,string &field)
{
   string body="",f;
#define SWV5S5_CL_D(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
#define SWV5S5_CL_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define SWV5S5_CL_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("version",limits.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("contract_id",limits.contract_id,f)) return false; body+=f;
   SWV5S5_CL_D("minimum_equity",limits.minimum_equity); SWV5S5_CL_D("maximum_daily_net_loss",limits.maximum_daily_net_loss);
   SWV5S5_CL_D("maximum_account_margin_fraction",limits.maximum_account_margin_fraction);
   SWV5S5_CL_D("maximum_basket_loss",limits.maximum_basket_loss); SWV5S5_CL_D("maximum_basket_volume",limits.maximum_basket_volume);
   SWV5S5_CL_D("maximum_symbol_volume",limits.maximum_symbol_volume); SWV5S5_CL_D("maximum_aggregate_volume",limits.maximum_aggregate_volume);
   SWV5S5_CL_D("maximum_aggregate_notional",limits.maximum_aggregate_notional);
   SWV5S5_CL_U("maximum_live_baskets",limits.maximum_live_baskets);
   SWV5S5_CL_U("maximum_cumulative_recovery_attempts",limits.maximum_cumulative_recovery_attempts);
   SWV5S5_CL_U("maximum_snapshot_age_seconds",limits.maximum_snapshot_age_seconds);
   SWV5S5_CL_I("trading_day_policy",limits.trading_day_policy);
   SWV5S5_CL_I("trading_day_utc_offset_minutes",limits.trading_day_utc_offset_minutes);
   if(!SWV5S5_CanonicalBool("hard_kill_enabled",limits.hard_kill_enabled,f)) return false; body+=f;
#undef SWV5S5_CL_D
#undef SWV5S5_CL_I
#undef SWV5S5_CL_U
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalMonetaryBasis(const string name,const SWV5_RiskMonetaryBasis &basis,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",basis.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("currency",basis.currency,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("account_currency",basis.account_currency,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("conversion_rate",basis.conversion_rate_to_account_currency,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("conversion_source",basis.conversion_source,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("valuation_at",basis.valuation_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("calculation_basis",basis.calculation_basis,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("sign_convention",basis.sign_convention,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("includes_realized",basis.includes_realized,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("includes_unrealized",basis.includes_unrealized,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("includes_commission",basis.includes_commission,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("includes_swap",basis.includes_swap,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("includes_fee",basis.includes_fee,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalRiskAuthorization(const string name,const SWV5_RiskAuthorization &risk,string &field)
{
   string body="",f;
#define SWV5S5_CR_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define SWV5S5_CR_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define SWV5S5_CR_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define SWV5S5_CR_D(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("version",risk.contract_version,f)) return false; body+=f;
   SWV5S5_CR_S("authorization_id",risk.authorization_id); SWV5S5_CR_S("limits_contract_id",risk.limits_contract_id);
   if(!SWV5S5_CanonicalRiskLimits("authorized_limits",risk.authorized_limits,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",risk.request_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",risk.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",risk.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account",risk.account_namespace,f)) return false; body+=f;
   SWV5S5_CR_I("account_mode",risk.account_mode); SWV5S5_CR_I("disposition",risk.disposition);
   SWV5S5_CR_I("blocking_domain",risk.blocking_domain); SWV5S5_CR_U("reason_flags",risk.reason_flags);
   SWV5S5_CR_U("basket_state_version",risk.basket_state_version);
   SWV5S5_CR_U("symbol_specification_sequence",risk.symbol_specification_sequence);
   SWV5S5_CR_I("authorized_intent_type",risk.authorized_intent_type); SWV5S5_CR_I("authorized_direction",risk.authorized_direction);
   SWV5S5_CR_D("authorized_volume",risk.authorized_volume); SWV5S5_CR_D("authorized_price",risk.authorized_price);
   SWV5S5_CR_D("authorized_stop_price",risk.authorized_stop_price); SWV5S5_CR_D("authorized_limit_price",risk.authorized_limit_price);
   SWV5S5_CR_U("risk_snapshot_epoch",risk.risk_snapshot_epoch); SWV5S5_CR_U("risk_snapshot_sequence",risk.risk_snapshot_sequence);
   SWV5S5_CR_D("authorized_projected_loss",risk.authorized_projected_loss);
   SWV5S5_CR_D("authorized_projected_notional",risk.authorized_projected_notional);
   SWV5S5_CR_D("authorized_projected_margin",risk.authorized_projected_margin);
   SWV5S5_CR_S("hard_kill_latch_id",risk.hard_kill_latch_id);
   SWV5S5_CR_U("hard_kill_latch_generation",risk.hard_kill_latch_generation);
   if(!SWV5S5_CanonicalMonetaryBasis("monetary_basis",risk.monetary_basis,f)) return false; body+=f;
   SWV5S5_CR_I("evaluated_at",risk.evaluated_at); SWV5S5_CR_I("expires_at",risk.expires_at);
   SWV5S5_CR_S("reason_text",risk.reason_text);
#undef SWV5S5_CR_S
#undef SWV5S5_CR_I
#undef SWV5S5_CR_U
#undef SWV5S5_CR_D
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalMarginAuthority(const string name,const SWV5_MarginAuthorityRecord &record,string &field)
{
   string body="",f;
#define SWV5S5_CM_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define SWV5S5_CM_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define SWV5S5_CM_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define SWV5S5_CM_D(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("version",record.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",record.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account",record.account_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",record.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",record.request_identity,f)) return false; body+=f;
   SWV5S5_CM_S("basket_id",record.basket_id.value); SWV5S5_CM_S("symbol",record.symbol);
   SWV5S5_CM_U("specification_sequence",record.symbol_specification_sequence); SWV5S5_CM_I("intent_type",record.intent_type);
   SWV5S5_CM_I("direction",record.direction); SWV5S5_CM_D("requested_volume",record.requested_volume);
   SWV5S5_CM_D("requested_price",record.requested_price); SWV5S5_CM_D("current_account_margin",record.current_account_margin);
   SWV5S5_CM_D("projected_account_margin",record.projected_account_margin); SWV5S5_CM_D("additional_margin",record.additional_margin);
   SWV5S5_CM_D("current_free_margin",record.current_free_margin); SWV5S5_CM_S("account_currency",record.account_currency);
   SWV5S5_CM_S("calculation_reference",record.broker_calculation_reference);
   SWV5S5_CM_U("observation_sequence",record.observation_sequence); SWV5S5_CM_I("observed_at",record.observed_at);
   SWV5S5_CM_I("calculated_at",record.calculated_at); SWV5S5_CM_S("authority_record_id",record.authority_record_id);
   SWV5S5_CM_U("authority_record_sequence",record.authority_record_sequence);
   SWV5S5_CM_S("authority_record_digest",record.authority_record_digest);
   SWV5S5_CM_I("issuing_component",record.issuing_component); SWV5S5_CM_I("authority_source",record.authority_source);
#undef SWV5S5_CM_S
#undef SWV5S5_CM_I
#undef SWV5S5_CM_U
#undef SWV5S5_CM_D
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalBasketRiskAuthority(const string name,const SWV5_BasketRiskAuthorityRecord &record,string &field)
{
   string body="",f;
#define SWV5S5_CB_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define SWV5S5_CB_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define SWV5S5_CB_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define SWV5S5_CB_D(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("version",record.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",record.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account",record.account_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",record.ownership_fence,f)) return false; body+=f;
   SWV5S5_CB_S("basket_id",record.basket_id.value); SWV5S5_CB_U("basket_state_version",record.basket_state_version);
   if(!SWV5S5_CanonicalRequestIdentity("request",record.request_identity,f)) return false; body+=f;
   SWV5S5_CB_S("symbol",record.symbol); SWV5S5_CB_U("specification_sequence",record.symbol_specification_sequence);
   SWV5S5_CB_S("source_snapshot_id",record.source_snapshot_id); SWV5S5_CB_S("source_snapshot_digest",record.source_snapshot_digest);
   SWV5S5_CB_D("existing_loss",record.existing_bounded_basket_loss);
   SWV5S5_CB_D("incremental_loss",record.incremental_request_bounded_loss);
   SWV5S5_CB_D("interaction_adjustment",record.interaction_or_offset_adjustment);
   SWV5S5_CB_D("resulting_loss",record.resulting_basket_maximum_loss);
   SWV5S5_CB_D("realized_loss_basis",record.realized_loss_basis);
   SWV5S5_CB_D("unrealized_loss_basis",record.unrealized_loss_basis);
   SWV5S5_CB_D("accrued_cost_basis",record.accrued_cost_basis);
   if(!SWV5S5_CanonicalMonetaryBasis("monetary_basis",record.monetary_basis,f)) return false; body+=f;
   SWV5S5_CB_S("calculation_policy_id",record.calculation_policy_id);
   SWV5S5_CB_U("observation_sequence",record.observation_sequence); SWV5S5_CB_I("observed_at",record.observed_at);
   SWV5S5_CB_I("calculated_at",record.calculated_at); SWV5S5_CB_S("authority_record_id",record.authority_record_id);
   SWV5S5_CB_U("authority_record_sequence",record.authority_record_sequence);
   SWV5S5_CB_S("authority_record_digest",record.authority_record_digest);
   SWV5S5_CB_I("issuing_component",record.issuing_component); SWV5S5_CB_I("authority_source",record.authority_source);
#undef SWV5S5_CB_S
#undef SWV5S5_CB_I
#undef SWV5S5_CB_U
#undef SWV5S5_CB_D
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_DerivePermitId(const SWV5S5_SubmissionPermit &permit,string &permit_id)
{
   string scope,policy,version,request,attempt,preimage;
   if(!SWV5S5_CanonicalNamespace("persistence_namespace",permit.persistence_namespace,scope) ||
      !SWV5S5_CanonicalString("permit_policy_id",permit.permit_policy_id,policy) ||
      !SWV5S5_CanonicalUInt("permit_policy_version",permit.permit_policy_version,version) ||
      !SWV5S5_CanonicalRequestIdentity("logical_request",permit.request_identity,request) ||
      !SWV5S5_CanonicalString("unique_attempt",permit.unique_attempt_id,attempt)) return false;
   preimage=scope+policy+version+request+attempt;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_PERMIT_ID,preimage,permit_id);
}

bool SWV5S5_DerivePermitDigest(const SWV5S5_SubmissionPermit &permit,string &digest)
{
   string body="",f;
#define SWV5S5_PM_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define SWV5S5_PM_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define SWV5S5_PM_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("version",permit.contract_version,f)) return false; body+=f;
   SWV5S5_PM_S("permit_policy_id",permit.permit_policy_id); SWV5S5_PM_U("permit_policy_version",permit.permit_policy_version);
   SWV5S5_PM_S("canonical_format_id",permit.canonical_format_id); SWV5S5_PM_S("permit_id",permit.permit_id);
   SWV5S5_PM_U("permit_revision",permit.permit_revision); SWV5S5_PM_I("reserved_at",permit.reserved_at);
   if(!SWV5S5_CanonicalNamespace("scope",permit.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",permit.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account_namespace",permit.account_namespace,f)) return false; body+=f;
   SWV5S5_PM_U("account_epoch",permit.account_epoch); SWV5S5_PM_I("account_mode",permit.account_mode);
   if(!SWV5S5_CanonicalRequestIdentity("request",permit.request_identity,f)) return false; body+=f;
   SWV5S5_PM_S("unique_attempt_id",permit.unique_attempt_id);
   if(!SWV5S5_CanonicalNormalizedPayload("normalized_payload",permit.normalized_payload,f)) return false; body+=f;
   SWV5S5_PM_S("normalization_identity",permit.normalization_identity);
   SWV5S5_PM_U("symbol_specification_sequence",permit.symbol_specification_sequence);
   SWV5S5_PM_S("basket_id",permit.basket_id.value); SWV5S5_PM_U("basket_state_version",permit.basket_state_version);
   SWV5S5_PM_S("trust_record_id",permit.producer_trust.authority_record_id);
   SWV5S5_PM_U("trust_generation",permit.producer_trust.authority_generation);
   SWV5S5_PM_S("trust_component",permit.producer_trust.producer_component);
   SWV5S5_PM_S("trust_instance",permit.producer_trust.producer_instance); SWV5S5_PM_U("trust_epoch",permit.producer_trust.producer_epoch);
   SWV5S5_PM_I("trust_status",permit.producer_trust.status); SWV5S5_PM_I("trust_valid_from",permit.producer_trust.valid_from);
   SWV5S5_PM_I("trust_valid_until",permit.producer_trust.valid_until); SWV5S5_PM_S("trust_digest",permit.producer_trust.record_digest);
   if(!SWV5S5_CanonicalRiskAuthorization("risk_authorization",permit.risk_authorization,f)) return false; body+=f;
   if(!SWV5S5_CanonicalMarginAuthority("margin_authority",permit.margin_authority,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBasketRiskAuthority("basket_risk_authority",permit.basket_risk_authority,f)) return false; body+=f;
   SWV5S5_PM_S("hard_kill_latch_id",permit.hard_kill_latch_id);
   SWV5S5_PM_U("hard_kill_latch_generation",permit.hard_kill_latch_generation);
   SWV5S5_PM_I("valid_from",permit.valid_from); SWV5S5_PM_I("valid_until",permit.valid_until);
#undef SWV5S5_PM_S
#undef SWV5S5_PM_U
#undef SWV5S5_PM_I
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_SUBMISSION_PERMIT,body,digest);
}

SWV5S5_PermitDisposition SWV5S5_EvaluatePermitIdentityConflict(const SWV5S5_SubmissionPermit &a,
                                                               const SWV5S5_SubmissionPermit &b)
{
   if(a.permit_id=="" || b.permit_id=="" || a.permit_id!=b.permit_id) return SWV5S5_PERMIT_INVALID;
   return a.permit_digest==b.permit_digest ? SWV5S5_PERMIT_EXISTING_IDENTICAL : SWV5S5_PERMIT_CONFLICT;
}

bool SWV5S5_ValidatePermit(const SWV5_ContractValidationContext &context,
                           const SWV5S5_SubmissionPermit &permit,SWV5S5_ValidationResult &result)
{
   string expected_id,expected_digest,trust_digest,permit_account,risk_account,margin_account,basket_risk_account;
   if(!SWV5S5_IsCandidateVersion(permit.contract_version) ||
      permit.permit_policy_id!=SWV5S5_PERMIT_POLICY_ID || permit.permit_policy_version!=SWV5S5_PERMIT_POLICY_VERSION ||
      permit.canonical_format_id!=SWV5S5_CANONICAL_POLICY_ID ||
      !SWV5S5_DerivePermitId(permit,expected_id) || permit.permit_id!=expected_id ||
      permit.permit_revision==0 || permit.reserved_at<=0 || permit.unique_attempt_id=="" ||
      permit.unique_attempt_id!=permit.request_identity.request_id.attempt_id ||
      !SWV5S5_EqualNamespace(permit.persistence_namespace,permit.normalized_payload.persistence_namespace) ||
      !SWV5S5_EqualFence(permit.ownership_fence,permit.normalized_payload.ownership_fence) ||
      permit.account_mode!=SWV5_ACCOUNT_MODE_HEDGING || permit.account_namespace.account_mode!=permit.account_mode ||
      permit.account_epoch!=permit.account_namespace.snapshot_epoch ||
      permit.basket_id.value=="" || permit.basket_id.value!=permit.persistence_namespace.basket_id.value ||
      permit.basket_state_version==0 || permit.symbol_specification_sequence==0 ||
      permit.symbol_specification_sequence!=permit.normalized_payload.specification_sequence ||
      permit.normalization_identity=="" || permit.producer_trust.status!=SWV5S5_TRUST_AUTHORIZED ||
      permit.producer_trust.authority_record_id=="" ||
      !SWV5S5_DeriveProducerTrustDigest(permit.producer_trust,trust_digest) || permit.producer_trust.record_digest!=trust_digest ||
      !SWV5S5_EqualNamespace(permit.producer_trust.persistence_namespace,permit.persistence_namespace) ||
      permit.risk_authorization.authorization_id=="" || permit.risk_authorization.disposition!=SWV5_RISK_ALLOW ||
      !SWV5S5_EqualRequestIdentity(permit.risk_authorization.request_identity,permit.request_identity) ||
      !SWV5S5_EqualNamespace(permit.risk_authorization.persistence_namespace,permit.persistence_namespace) ||
      !SWV5S5_EqualFence(permit.risk_authorization.ownership_fence,permit.ownership_fence) ||
      permit.risk_authorization.account_mode!=permit.account_mode ||
      permit.risk_authorization.account_namespace.snapshot_epoch!=permit.account_epoch ||
      permit.risk_authorization.basket_state_version!=permit.basket_state_version ||
      permit.risk_authorization.symbol_specification_sequence!=permit.symbol_specification_sequence ||
      permit.risk_authorization.authorized_volume!=permit.normalized_payload.volume ||
      permit.risk_authorization.authorized_price!=permit.normalized_payload.price ||
      permit.risk_authorization.authorized_stop_price!=permit.normalized_payload.stop_price ||
      permit.risk_authorization.authorized_limit_price!=permit.normalized_payload.limit_price ||
      permit.hard_kill_latch_id!=permit.risk_authorization.hard_kill_latch_id ||
      permit.hard_kill_latch_generation!=permit.risk_authorization.hard_kill_latch_generation ||
      !SWV5S5_EqualNamespace(permit.margin_authority.persistence_namespace,permit.persistence_namespace) ||
      !SWV5S5_EqualFence(permit.margin_authority.ownership_fence,permit.ownership_fence) ||
      !SWV5S5_EqualRequestIdentity(permit.margin_authority.request_identity,permit.request_identity) ||
      permit.margin_authority.basket_id.value!=permit.basket_id.value ||
      permit.margin_authority.symbol_specification_sequence!=permit.symbol_specification_sequence ||
      !SWV5S5_EqualNamespace(permit.basket_risk_authority.persistence_namespace,permit.persistence_namespace) ||
      !SWV5S5_EqualFence(permit.basket_risk_authority.ownership_fence,permit.ownership_fence) ||
      !SWV5S5_EqualRequestIdentity(permit.basket_risk_authority.request_identity,permit.request_identity) ||
      permit.basket_risk_authority.basket_id.value!=permit.basket_id.value ||
      permit.basket_risk_authority.basket_state_version!=permit.basket_state_version ||
      permit.basket_risk_authority.symbol_specification_sequence!=permit.symbol_specification_sequence ||
      !SWV5S5_CanonicalAccountNamespace("account",permit.account_namespace,permit_account) ||
      !SWV5S5_CanonicalAccountNamespace("account",permit.risk_authorization.account_namespace,risk_account) ||
      !SWV5S5_CanonicalAccountNamespace("account",permit.margin_authority.account_namespace,margin_account) ||
      !SWV5S5_CanonicalAccountNamespace("account",permit.basket_risk_authority.account_namespace,basket_risk_account) ||
      permit_account!=risk_account || permit_account!=margin_account || permit_account!=basket_risk_account ||
      permit.valid_from<=0 || permit.valid_until<=permit.valid_from ||
      permit.reserved_at<permit.valid_from || permit.reserved_at>=permit.valid_until ||
      permit.valid_from<permit.producer_trust.valid_from || permit.valid_until>permit.producer_trust.valid_until ||
      permit.valid_until>permit.risk_authorization.expires_at ||
      context.clock_time<permit.valid_from || context.clock_time>=permit.valid_until ||
      context.clock_time>=permit.risk_authorization.expires_at ||
      !SWV5S5_DerivePermitDigest(permit,expected_digest) || permit.permit_digest!=expected_digest)
   { SWV5S5_Deny(context,"SUBMISSION_PERMIT_INVALID","",result); return false; }
   SWV5S5_Allow(context,"SUBMISSION_PERMIT_VALID",result); return true;
}

bool SWV5S5_DeriveDurableSubmissionAuthorityDigest(const SWV5S5_SubmissionAuthorityRecord &record,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",record.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("permit_digest",record.permit.permit_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("state",record.state,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("authority_revision",record.authority_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("invocation_claim_id",record.invocation_claim_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInstanceLease("claim_ownership_lease",record.claim_ownership_lease,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("claimed_at",record.claimed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_clock_id",record.claim_clock_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("claim_clock_authority",record.claim_clock_authority,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("claim_clock_sequence",record.claim_clock_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("admission_snapshot_digest",record.admission_snapshot_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_policy_id",record.claim_policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("claim_policy_version",record.claim_policy_version,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_SUBMISSION_PERMIT,body,digest);
}

bool SWV5S5_DeriveSubmissionIndexDigest(const SWV5S5_SubmissionAuthorityIndexEntry &entries[],string &digest)
{
   string body="",entry="",f;
   for(int i=0;i<ArraySize(entries);i++)
   {
      entry="";
      if(entries[i].logical_correlation_id=="" || entries[i].attempt_id=="" || entries[i].permit_id=="" ||
         (i>0 && (StringCompare(entries[i-1].logical_correlation_id,entries[i].logical_correlation_id)>0 ||
          (entries[i-1].logical_correlation_id==entries[i].logical_correlation_id &&
           StringCompare(entries[i-1].attempt_id,entries[i].attempt_id)>=0)))) return false;
      if(!SWV5S5_CanonicalString("correlation_id",entries[i].logical_correlation_id,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalString("attempt_id",entries[i].attempt_id,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalString("permit_id",entries[i].permit_id,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalString("permit_digest",entries[i].permit_digest,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalInt("state",entries[i].state,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalUInt("authority_revision",entries[i].authority_revision,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalString("record_digest",entries[i].durable_record_digest,f)) return false; entry+=f;
      if(!SWV5S5_CanonicalIndexed("submission",(ulong)i,entry,f)) return false; body+=f;
   }
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_SUBMISSION_PERMIT,body,digest);
}

bool SWV5S5_DerivePermitPreparationCommandDigest(const SWV5S5_PermitPreparationCommand &command,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",command.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("expected_index_digest",command.expected_index_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expected_index_revision",command.expected_index_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("permit_digest",command.proposed_permit.permit_digest,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_SUBMISSION_PERMIT,body,digest);
}

bool SWV5S5_PreparePermitCommit(const SWV5_ContractValidationContext &context,
                                const SWV5S5_SubmissionAuthorityIndexEntry &entries[],
                                const SWV5S5_PermitPreparationCommand &command,
                                SWV5S5_PermitPreparationResult &result)
{
   ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
   string index_digest,command_digest;
   SWV5S5_ValidationResult validation;
   if(!SWV5S5_DeriveSubmissionIndexDigest(entries,index_digest) || index_digest!=command.expected_index_digest ||
      !SWV5S5_DerivePermitPreparationCommandDigest(command,command_digest) || command.command_digest!=command_digest ||
      !SWV5S5_ValidatePermit(context,command.proposed_permit,validation))
   { result.disposition=SWV5S5_PERMIT_INVALID; result.reason_code="PERMIT_PREPARATION_INVALID"; return false; }
   string correlation=command.proposed_permit.request_identity.request_id.correlation_id;
   string attempt=command.proposed_permit.unique_attempt_id;
   for(int i=0;i<ArraySize(entries);i++)
   {
      if(entries[i].logical_correlation_id!=correlation) continue;
      if(entries[i].attempt_id==attempt)
      {
         result.disposition=(entries[i].permit_id==command.proposed_permit.permit_id &&
                             entries[i].permit_digest==command.proposed_permit.permit_digest) ?
                            SWV5S5_PERMIT_EXISTING_IDENTICAL : SWV5S5_PERMIT_CONFLICT;
         result.reason_code=(result.disposition==SWV5S5_PERMIT_EXISTING_IDENTICAL ?
                             "PERMIT_EXISTING_IDENTICAL" : "PERMIT_IDENTITY_CONFLICT");
         return result.disposition==SWV5S5_PERMIT_EXISTING_IDENTICAL;
      }
      if(entries[i].state==SWV5S5_COMMITTED_NOT_INVOKED ||
         entries[i].state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED)
      { result.disposition=SWV5S5_PERMIT_LOGICAL_REQUEST_UNRESOLVED; result.reason_code="COMPETING_UNRESOLVED_ATTEMPT"; return false; }
   }
   ZeroMemory(result.proposed_record);
   SWV5S5_InitContractVersion(result.proposed_record.contract_version);
   result.proposed_record.permit=command.proposed_permit;
   result.proposed_record.state=SWV5S5_COMMITTED_NOT_INVOKED;
   result.proposed_record.authority_revision=1;
   if(!SWV5S5_DeriveDurableSubmissionAuthorityDigest(result.proposed_record,
                                                      result.proposed_record.durable_record_digest))
   { result.disposition=SWV5S5_PERMIT_INVALID; result.reason_code="PERMIT_RECORD_DIGEST_FAILED"; return false; }
   result.disposition=SWV5S5_PERMIT_PROPOSAL_VALID;
   result.reason_code="PERMIT_PROPOSAL_VALID_NO_COMMIT";
   return true;
}

class ISWV5S5SubmissionPermitAuthority
{
public:
   // Future implementation compares the current per-request/attempt index and
   // ownership fence atomically; only a committed result may report PERMIT_COMMITTED.
   virtual bool TryCommitPermit(const SWV5S5_PermitPreparationCommand &command,
                                const SWV5S5_SubmissionAuthorityIndexEntry &expected_index[],
                                SWV5S5_PermitPreparationResult &authoritative_result)=0;
};

#endif
