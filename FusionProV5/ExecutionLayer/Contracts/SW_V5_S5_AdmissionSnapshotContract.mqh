#ifndef SW_V5_S5_ADMISSION_SNAPSHOT_CONTRACT_MQH
#define SW_V5_S5_ADMISSION_SNAPSHOT_CONTRACT_MQH

// SPRINT 5 PHASE B.3 CANDIDATE CONTRACT
// COMPLETE TYPED OWNER VIEWS / NO MANUFACTURED GENERIC AUTHORITY TOKEN

#include "SW_V5_S5_SubmissionAuthorityContract.mqh"

struct SWV5S5_AuthoritativeClockObservation
{
   string clock_id;
   SWV5_TimeAuthority clock_authority;
   ulong clock_sequence;
   datetime observed_at;
};

struct SWV5S5_OwnershipAuthorityView
{
   SWV5_OwnershipFence fence; // owner mutation evidence: owner/fence/takeover/fencing digest
   string projection_digest;
};

struct SWV5S5_LeaseLivenessAuthorityView
{
   SWV5_InstanceLease lease; // liveness mutation evidence: store revision/heartbeat/expiry
   string projection_digest;
};

struct SWV5S5_ProducerTrustAuthorityView
{
   SWV5S5_ProducerTrustRecord record;
   string projection_digest;
};

struct SWV5S5_HardKillAuthorityView
{
   SWV5_HardKillState state;
   string projection_digest;
};

struct SWV5S5_AccountAuthorityView
{
   SWV5_AccountRiskNamespace account_namespace;
   string projection_digest;
};

struct SWV5S5_BasketAuthorityView
{
   SWV5_BasketLifecycleSnapshot basket;
   string projection_digest;
};

struct SWV5S5_PendingRequestSetAuthorityView
{
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   SWV5_PersistedRequestSetHeader header;
   SWV5_PendingRequest requests[];
   string projection_digest;
};

struct SWV5S5_SymbolSpecificationAuthorityView
{
   SWV5_SymbolUnitSpecification specification;
   string projection_digest;
};

struct SWV5S5_MarginAuthorityView
{
   SWV5_MarginAuthorityRecord record;
   string projection_digest;
};

struct SWV5S5_BasketRiskAuthorityView
{
   SWV5_BasketRiskAuthorityRecord record;
   string projection_digest;
};

struct SWV5S5_RiskAuthorizationAuthorityView
{
   SWV5_RiskAuthorization authorization;
   SWV5_RiskEvaluationInput current_binding;
   string projection_digest;
};

struct SWV5S5_NormalizedPayloadAuthorityView
{
   SWV5_NormalizedUnits payload;
   string normalization_identity;
   string unit_authority_id;
   ulong unit_authority_revision;
   string unit_authority_digest;
   string payload_content_digest;
   string projection_digest;
};

struct SWV5S5_SubmissionPermitAuthorityView
{
   SWV5S5_SubmissionPermit permit;
   string projection_digest;
};

struct SWV5S5_PolicyFormatAuthorityView
{
   string admission_policy_id;
   uint admission_policy_version;
   string canonical_format_id;
   string projection_digest;
};

struct SWV5S5_AdmissionAuthorityCollection
{
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_ExecutionRequestIdentity request_identity;
   string attempt_id;
   SWV5S5_OwnershipAuthorityView ownership;
   SWV5S5_LeaseLivenessAuthorityView lease_liveness;
   SWV5S5_ProducerTrustAuthorityView producer_trust;
   SWV5S5_HardKillAuthorityView hard_kill;
   SWV5S5_AccountAuthorityView account;
   SWV5S5_BasketAuthorityView basket;
   SWV5S5_PendingRequestSetAuthorityView request_set;
   SWV5S5_SymbolSpecificationAuthorityView symbol_specification;
   SWV5S5_MarginAuthorityView margin;
   SWV5S5_BasketRiskAuthorityView basket_risk;
   SWV5S5_RiskAuthorizationAuthorityView risk_authorization;
   SWV5S5_NormalizedPayloadAuthorityView normalized_payload;
   SWV5S5_SubmissionPermitAuthorityView submission_permit;
   SWV5S5_PolicyFormatAuthorityView policy_format;
   SWV5S5_AuthoritativeClockObservation collect_clock;
   string collection_digest;
};

struct SWV5S5_AdmissionSnapshot
{
   SWV5_ContractVersion contract_version;
   string canonical_policy_id;
   SWV5S5_AdmissionAuthorityCollection collect_v1;
   SWV5S5_AdmissionAuthorityCollection collect_v2;
   SWV5S5_AuthoritativeClockObservation claim_clock;
   string snapshot_digest;
};

struct SWV5S5_DoubleCollectResult
{
   SWV5_ContractVersion contract_version;
   SWV5S5_StableCollectDisposition disposition;
   string provisional_snapshot_digest;
   string changed_authority;
   string reason_code;
};

struct SWV5S5_AdmissionProofInput
{
   SWV5S5_ProducerTrustAnchor trust_anchor;
   SWV5S5_ProducerTrustScope trust_scope;
   SWV5S5_IngressEnvelope accepted_ingress;
   SWV5_InstanceLease current_ownership_lease;
};

struct SWV5S5_AdmissionProof
{
   SWV5_ContractVersion contract_version;
   bool v1_semantically_valid;
   bool v2_semantically_valid;
   bool stable_owner_evidence;
   bool safety_projections_equal;
   bool relationally_bound;
   bool pre_p_admissible;
   bool claim_time_valid;
   SWV5S5_ProducerTrustAnchor trust_anchor;
   SWV5S5_ProducerTrustScope trust_scope;
   SWV5S5_IngressEnvelope accepted_ingress;
   SWV5S5_AdmissionSnapshot snapshot;
   string proof_digest;
   string reason_code;
};

bool SWV5S5_CanonicalClockObservation(const string name,
                                      const SWV5S5_AuthoritativeClockObservation &clock,string &field)
{
   string body="",f;
   if(clock.clock_id=="" || clock.clock_authority==SWV5_TIME_AUTHORITY_NONE || clock.observed_at<=0) return false;
   if(!SWV5S5_CanonicalString("clock_id",clock.clock_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("clock_authority",clock.clock_authority,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("clock_sequence",clock.clock_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",clock.observed_at,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_DeriveOwnershipProjection(SWV5S5_OwnershipAuthorityView &view)
{
   string f;
   if(!SWV5S5_IsV5Version(view.fence.contract_version) || view.fence.owner.instance_id=="" || view.fence.fencing_token_digest=="" ||
      !SWV5S5_CanonicalFence("ownership",view.fence,f)) return false;
   return SWV5S5_SHA256(f,view.projection_digest);
}

bool SWV5S5_DeriveLeaseProjection(SWV5S5_LeaseLivenessAuthorityView &view)
{
   string projection;
   if(!SWV5S5_IsV5Version(view.lease.contract_version) || view.lease.store_revision=="" ||
      (view.lease.status!=SWV5_LOCK_ACQUIRED && view.lease.status!=SWV5_LOCK_RENEWED) ||
      view.lease.expires_at<=view.lease.heartbeat_at) return false;
   return SWV5S5_CanonicalInstanceLease("lease",view.lease,projection) &&
          SWV5S5_SHA256(projection,view.projection_digest);
}

bool SWV5S5_DeriveTrustProjection(SWV5S5_ProducerTrustAuthorityView &view)
{
   string expected;
   if(view.record.authority_record_id=="" || view.record.record_digest=="" ||
      !SWV5S5_DeriveProducerTrustDigest(view.record,expected) || view.record.record_digest!=expected) return false;
   view.projection_digest=expected; return true;
}

bool SWV5S5_CanonicalOperatorIdentity(const string name,const SWV5_OperatorIdentity &identity,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalString("operator_id",identity.operator_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("authority_role",identity.authority_role,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("authentication_reference",identity.authentication_reference,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("authenticated_at",identity.authenticated_at,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalTypedReconciliationEvidence(const string name,
                                                  const SWV5_TypedReconciliationEvidence &evidence,
                                                  string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",evidence.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",evidence.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("evidence_id",evidence.evidence_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("issuing_component",evidence.issuing_component,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("authority_source",evidence.authority_source,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("evidence_sequence",evidence.evidence_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",evidence.observed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("state_digest",evidence.state_digest,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalExposureReductionEvidence(const string name,
                                                const SWV5_ExposureReductionEvidence &evidence,
                                                string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",evidence.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("evidence_id",evidence.evidence_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("issuing_component",evidence.issuing_component,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("authority_source",evidence.authority_source,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("observed_exposure_volume",evidence.observed_exposure_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("prior_exposure_volume",evidence.prior_exposure_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("zero_or_reducing",evidence.zero_or_reducing,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("evidence_sequence",evidence.evidence_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",evidence.observed_at,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalHardKillReleaseEvidence(const string name,
                                              const SWV5_HardKillReleaseEvidence &evidence,
                                              string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",evidence.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",evidence.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("release_id",evidence.release_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("latch_id",evidence.latch_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("latch_generation",evidence.latch_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("release_generation",evidence.release_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("approval_policy_id",evidence.approval_policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("approval_sequence",evidence.approval_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalOperatorIdentity("operator",evidence.operator_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("approving_component",evidence.approving_component,f)) return false; body+=f;
   if(!SWV5S5_CanonicalTypedReconciliationEvidence("broker_evidence",evidence.broker_evidence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalTypedReconciliationEvidence("persistence_evidence",evidence.persistence_evidence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalExposureReductionEvidence("exposure_evidence",evidence.exposure_evidence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("approved_at",evidence.approved_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("released_at",evidence.released_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("expires_at",evidence.expires_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("release_record_sequence",evidence.release_record_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("release_record_digest",evidence.release_record_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("audit_reference",evidence.audit_reference,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalHardKillAuthorityReference(const string name,
                                                 const SWV5_HardKillReleaseAuthorityReference &reference,
                                                 string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",reference.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("authority_record_id",reference.authority_record_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("authority_record_sequence",reference.authority_record_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("authority_record_digest",reference.authority_record_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("release_id",reference.release_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("latch_generation",reference.latch_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("release_generation",reference.release_generation,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalHardKillState(const string name,const SWV5_HardKillState &state,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",state.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",state.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account",state.account_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("latch_id",state.latch_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("latch_generation",state.latch_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("state",state.state,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("activation_reason",state.activation_reason,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("activated_at",state.activated_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("activation_authority",state.activation_authority,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("release_generation",state.release_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalHardKillReleaseEvidence("release_evidence",state.release_evidence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalHardKillAuthorityReference("release_authority_reference",state.release_authority_reference,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalExecutionIntent(const string name,const SWV5_ExecutionIntent &intent,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",intent.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",intent.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",intent.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",intent.request_identity,f)) return false; body+=f;
#define SWV5S5_CEI_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define SWV5S5_CEI_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define SWV5S5_CEI_D(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
   SWV5S5_CEI_I("account_mode",intent.account_mode); SWV5S5_CEI_I("intent_type",intent.intent_type);
   SWV5S5_CEI_I("direction",intent.direction); SWV5S5_CEI_D("volume",intent.normalized_volume);
   SWV5S5_CEI_D("price",intent.normalized_price); SWV5S5_CEI_D("stop",intent.normalized_stop_price);
   SWV5S5_CEI_D("limit",intent.normalized_limit_price); SWV5S5_CEI_U("specification_sequence",intent.symbol_specification_sequence);
   SWV5S5_CEI_U("basket_version",intent.expected_basket_version);
   if(!SWV5S5_CanonicalString("risk_authorization_id",intent.risk_authorization_id,f)) return false; body+=f;
   SWV5S5_CEI_I("authorization_expires_at",intent.authorization_expires_at);
#undef SWV5S5_CEI_I
#undef SWV5S5_CEI_U
#undef SWV5S5_CEI_D
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalAccountRiskSnapshot(const string name,const SWV5_AccountRiskSnapshot &v,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account",v.account_namespace,f)) return false; body+=f;
#define SWV5S5_CAS_D(n,x) if(!SWV5S5_CanonicalDouble(n,x,f)) return false; else body+=f
   SWV5S5_CAS_D("balance",v.balance); SWV5S5_CAS_D("equity",v.equity); SWV5S5_CAS_D("margin",v.margin);
   SWV5S5_CAS_D("free_margin",v.free_margin); SWV5S5_CAS_D("daily_realized_net",v.daily_realized_net);
   SWV5S5_CAS_D("daily_unrealized_net",v.daily_unrealized_net);
#undef SWV5S5_CAS_D
   if(!SWV5S5_CanonicalDatetime("trading_day_start",v.trading_day_start,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",v.observed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("authoritative",v.authoritative,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalExposureRiskSnapshot(const string name,const SWV5_ExposureRiskSnapshot &v,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account",v.account_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("symbol",v.symbol,f)) return false; body+=f;
#define SWV5S5_CES_D(n,x) if(!SWV5S5_CanonicalDouble(n,x,f)) return false; else body+=f
   SWV5S5_CES_D("long",v.symbol_long_volume); SWV5S5_CES_D("short",v.symbol_short_volume);
   SWV5S5_CES_D("net",v.symbol_net_volume); SWV5S5_CES_D("aggregate_volume",v.aggregate_volume);
   SWV5S5_CES_D("aggregate_notional",v.aggregate_notional);
#undef SWV5S5_CES_D
   if(!SWV5S5_CanonicalUInt("live_basket_count",v.live_basket_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",v.observed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("complete",v.complete,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalMarginProjectionEvidence(const string name,const SWV5_MarginProjectionEvidence &v,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",v.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account",v.account_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",v.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",v.request_identity,f)) return false; body+=f;
#define SWV5S5_CME_S(n,x) if(!SWV5S5_CanonicalString(n,x,f)) return false; else body+=f
#define SWV5S5_CME_U(n,x) if(!SWV5S5_CanonicalUInt(n,x,f)) return false; else body+=f
#define SWV5S5_CME_I(n,x) if(!SWV5S5_CanonicalInt(n,x,f)) return false; else body+=f
#define SWV5S5_CME_D(n,x) if(!SWV5S5_CanonicalDouble(n,x,f)) return false; else body+=f
   SWV5S5_CME_S("basket_id",v.basket_id.value); SWV5S5_CME_S("symbol",v.symbol);
   SWV5S5_CME_U("specification_sequence",v.symbol_specification_sequence); SWV5S5_CME_I("intent_type",v.intent_type);
   SWV5S5_CME_I("direction",v.direction); SWV5S5_CME_D("requested_volume",v.requested_volume);
   SWV5S5_CME_D("requested_price",v.requested_price); SWV5S5_CME_D("current_margin",v.current_account_margin);
   SWV5S5_CME_D("free_margin",v.current_free_margin); SWV5S5_CME_D("projected_margin",v.projected_account_margin);
   SWV5S5_CME_D("additional_margin",v.additional_margin); SWV5S5_CME_S("currency",v.account_currency);
   SWV5S5_CME_I("issuing_component",v.issuing_component); SWV5S5_CME_I("authority_source",v.authority_source);
   SWV5S5_CME_S("calculation_reference",v.calculation_reference); SWV5S5_CME_I("observed_at",v.observed_at);
   SWV5S5_CME_I("calculated_at",v.calculated_at); SWV5S5_CME_U("evidence_sequence",v.evidence_sequence);
   SWV5S5_CME_S("authority_record_id",v.authority_record_id); SWV5S5_CME_U("authority_record_sequence",v.authority_record_sequence);
   SWV5S5_CME_S("authority_record_digest",v.authority_record_digest); SWV5S5_CME_S("evidence_digest",v.evidence_digest);
#undef SWV5S5_CME_S
#undef SWV5S5_CME_U
#undef SWV5S5_CME_I
#undef SWV5S5_CME_D
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalBasketRiskProjectionEvidence(const string name,const SWV5_BasketRiskProjectionEvidence &v,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",v.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account",v.account_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",v.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",v.request_identity,f)) return false; body+=f;
#define SWV5S5_CBE_S(n,x) if(!SWV5S5_CanonicalString(n,x,f)) return false; else body+=f
#define SWV5S5_CBE_U(n,x) if(!SWV5S5_CanonicalUInt(n,x,f)) return false; else body+=f
#define SWV5S5_CBE_I(n,x) if(!SWV5S5_CanonicalInt(n,x,f)) return false; else body+=f
#define SWV5S5_CBE_D(n,x) if(!SWV5S5_CanonicalDouble(n,x,f)) return false; else body+=f
   SWV5S5_CBE_S("basket_id",v.basket_id.value); SWV5S5_CBE_U("basket_version",v.basket_state_version);
   SWV5S5_CBE_S("symbol",v.symbol); SWV5S5_CBE_U("specification_sequence",v.symbol_specification_sequence);
   SWV5S5_CBE_D("existing_loss",v.existing_bounded_basket_loss); SWV5S5_CBE_D("incremental_loss",v.incremental_request_bounded_loss);
   SWV5S5_CBE_D("adjustment",v.interaction_or_offset_adjustment); SWV5S5_CBE_D("resulting_loss",v.resulting_basket_maximum_loss);
   SWV5S5_CBE_D("realized",v.realized_loss_basis); SWV5S5_CBE_D("unrealized",v.unrealized_loss_basis);
   SWV5S5_CBE_D("accrued",v.accrued_cost_basis);
   if(!SWV5S5_CanonicalMonetaryBasis("monetary_basis",v.monetary_basis,f)) return false; body+=f;
   SWV5S5_CBE_S("calculation_policy_id",v.calculation_policy_id); SWV5S5_CBE_S("source_snapshot_digest",v.source_snapshot_digest);
   SWV5S5_CBE_I("issuing_component",v.issuing_component); SWV5S5_CBE_I("authority_source",v.authority_source);
   SWV5S5_CBE_I("observed_at",v.observed_at); SWV5S5_CBE_I("calculated_at",v.calculated_at);
   SWV5S5_CBE_U("evidence_sequence",v.evidence_sequence); SWV5S5_CBE_S("authority_record_id",v.authority_record_id);
   SWV5S5_CBE_U("authority_record_sequence",v.authority_record_sequence); SWV5S5_CBE_S("authority_record_digest",v.authority_record_digest);
   SWV5S5_CBE_S("evidence_digest",v.evidence_digest);
#undef SWV5S5_CBE_S
#undef SWV5S5_CBE_U
#undef SWV5S5_CBE_I
#undef SWV5S5_CBE_D
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_DeriveHardKillProjection(SWV5S5_HardKillAuthorityView &view)
{
   string projection;
   if(view.state.latch_id=="") return false;
   return SWV5S5_CanonicalHardKillState("hard_kill",view.state,projection) &&
          SWV5S5_SHA256(projection,view.projection_digest);
}

bool SWV5S5_DeriveAccountProjection(SWV5S5_AccountAuthorityView &view)
{
   string projection;
   if(view.account_namespace.broker_identity=="" || view.account_namespace.server=="" ||
      view.account_namespace.account_mode!=SWV5_ACCOUNT_MODE_HEDGING) return false;
   return SWV5S5_CanonicalAccountNamespace("account",view.account_namespace,projection) &&
          SWV5S5_SHA256(projection,view.projection_digest);
}

bool SWV5S5_DeriveBasketProjection(SWV5S5_BasketAuthorityView &view)
{
   string body="",f;
   if(view.basket.basket_id.value=="" || view.basket.state_version==0) return false;
   if(!SWV5S5_CanonicalContractVersion("version",view.basket.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("basket_id",view.basket.basket_id.value,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",view.basket.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("state",view.basket.state,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("state_version",view.basket.state_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("recovery_attempts",view.basket.cumulative_recovery_attempts,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("recovery_layer",view.basket.current_recovery_layer,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("recovery_evidence_version",view.basket.accepted_recovery_evidence.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("recovery_fingerprint_policy",view.basket.accepted_recovery_evidence.fingerprint_policy,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("recovery_event_index",view.basket.accepted_recovery_evidence.canonical_event_index,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("recovery_fingerprint_index",view.basket.accepted_recovery_evidence.canonical_fingerprint_index,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("recovery_index_digest",view.basket.accepted_recovery_evidence.identity_set_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("recovery_identity_count",view.basket.accepted_recovery_evidence.accepted_identity_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("recovery_highest_transaction_sequence",view.basket.accepted_recovery_evidence.highest_transaction_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("recovery_index_revision",view.basket.accepted_recovery_evidence.index_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("recovery_compaction_generation",view.basket.accepted_recovery_evidence.compaction_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("open_volume",view.basket.aggregate_open_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("residual_volume",view.basket.residual_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("positions",view.basket.live_position_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("orders",view.basket.live_order_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("pending",view.basket.pending_request_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("reconciliation",view.basket.reconciliation_state,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("query_version",view.basket.broker_queries.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("query_required_flags",view.basket.broker_queries.required_flags,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("query_completed_flags",view.basket.broker_queries.completed_flags,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("query_authoritative_flags",view.basket.broker_queries.authoritative_flags,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("query_observation_sequence",view.basket.broker_queries.observation_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("query_observed_at",view.basket.broker_queries.observed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("query_issuing_component",view.basket.broker_queries.issuing_component,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("query_authority_source",view.basket.broker_queries.authority_source,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("query_snapshot_id",view.basket.broker_queries.snapshot_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("query_digest",view.basket.broker_queries.snapshot_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("state_entered_at",view.basket.state_entered_at,f)) return false; body+=f;
   return SWV5S5_SHA256(body,view.projection_digest);
}

bool SWV5S5_DeriveRequestSetProjection(SWV5S5_PendingRequestSetAuthorityView &view)
{
   string body="",f,set_digest;
   int count=ArraySize(view.requests);
   if(view.header.request_count!=(uint)count || view.header.request_index_revision=="" ||
      !SWV5S5_IsDigest64Lower(view.header.request_set_digest) ||
      !SWV5S5_CanonicalNamespace("scope",view.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",view.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("header_version",view.header.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("request_count",view.header.request_count,f)) return false; body+=f;
   if(!SWV5S5_DeriveCompleteRequestSetDigest(view.requests,set_digest) ||
      view.header.request_set_digest!=set_digest ||
      !SWV5S5_CanonicalString("request_set_digest",view.header.request_set_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("request_set_revision",view.header.request_index_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("record_sequence",view.header.record_sequence,f)) return false; body+=f;
   return SWV5S5_SHA256(body,view.projection_digest);
}

bool SWV5S5_DeriveSymbolProjection(SWV5S5_SymbolSpecificationAuthorityView &view)
{
   string body="",f;
#define SWV5S5_SP_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define SWV5S5_SP_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define SWV5S5_SP_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define SWV5S5_SP_D(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
   if(view.specification.symbol=="" || view.specification.specification_sequence==0 || !view.specification.complete) return false;
   SWV5S5_SP_S("symbol",view.specification.symbol); SWV5S5_SP_U("sequence",view.specification.specification_sequence);
   SWV5S5_SP_I("digits",view.specification.digits); SWV5S5_SP_D("point",view.specification.point_size);
   SWV5S5_SP_D("tick",view.specification.tick_size); SWV5S5_SP_D("pip",view.specification.pip_size);
   SWV5S5_SP_D("tick_profit",view.specification.tick_value_profit); SWV5S5_SP_D("tick_loss",view.specification.tick_value_loss);
   SWV5S5_SP_D("contract",view.specification.contract_size); SWV5S5_SP_I("mode",view.specification.calculation_mode);
   SWV5S5_SP_D("basis_volume",view.specification.tick_value_basis_volume); SWV5S5_SP_D("volume_min",view.specification.volume_minimum);
   SWV5S5_SP_D("volume_max",view.specification.volume_maximum); SWV5S5_SP_D("volume_step",view.specification.volume_step);
   SWV5S5_SP_I("stops",view.specification.stops_level_points); SWV5S5_SP_I("freeze",view.specification.freeze_level_points);
   SWV5S5_SP_S("account_currency",view.specification.account_currency); SWV5S5_SP_S("tick_currency",view.specification.tick_value_currency);
   SWV5S5_SP_I("source",view.specification.authority_source); SWV5S5_SP_I("observed_at",view.specification.observed_at);
   SWV5S5_SP_I("valid_until",view.specification.valid_until);
   if(!SWV5S5_CanonicalBool("complete",view.specification.complete,f)) return false; body+=f;
#undef SWV5S5_SP_S
#undef SWV5S5_SP_U
#undef SWV5S5_SP_I
#undef SWV5S5_SP_D
   return SWV5S5_SHA256(body,view.projection_digest);
}

bool SWV5S5_DeriveMarginProjection(SWV5S5_MarginAuthorityView &view)
{
   string projection;
   if(view.record.authority_record_id=="" || !SWV5S5_IsDigest64Lower(view.record.authority_record_digest) ||
      view.record.authority_record_sequence==0) return false;
   return SWV5S5_CanonicalMarginAuthority("margin_authority",view.record,projection) &&
          SWV5S5_SHA256(projection,view.projection_digest);
}

bool SWV5S5_DeriveBasketRiskProjection(SWV5S5_BasketRiskAuthorityView &view)
{
   string projection;
   if(view.record.authority_record_id=="" || !SWV5S5_IsDigest64Lower(view.record.authority_record_digest) ||
      view.record.authority_record_sequence==0) return false;
   return SWV5S5_CanonicalBasketRiskAuthority("basket_risk_authority",view.record,projection) &&
          SWV5S5_SHA256(projection,view.projection_digest);
}

bool SWV5S5_CanonicalBasketRiskSnapshot(const string name,const SWV5_BasketRiskSnapshot &v,string &field)
{
   string body="",f;
   SWV5S5_BasketAuthorityView lifecycle; lifecycle.basket=v.lifecycle;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account",v.account_namespace,f)) return false; body+=f;
   if(!SWV5S5_DeriveBasketProjection(lifecycle) ||
      !SWV5S5_CanonicalString("lifecycle_digest",lifecycle.projection_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("realized_net",v.realized_net,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("unrealized_net",v.unrealized_net,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("maximum_adverse_net",v.maximum_adverse_net,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",v.observed_at,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalProjectedRequestRisk(const string name,const SWV5_ProjectedRequestRisk &v,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account",v.account_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("symbol",v.symbol,f)) return false; body+=f;
#define SWV5S5_CPR_D(n,x) if(!SWV5S5_CanonicalDouble(n,x,f)) return false; else body+=f
   SWV5S5_CPR_D("projected_volume",v.projected_volume); SWV5S5_CPR_D("projected_symbol_volume",v.projected_symbol_volume);
   SWV5S5_CPR_D("projected_aggregate_volume",v.projected_aggregate_volume); SWV5S5_CPR_D("projected_notional",v.projected_notional);
   if(!SWV5S5_CanonicalMarginProjectionEvidence("margin_evidence",v.margin_evidence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBasketRiskProjectionEvidence("basket_risk_evidence",v.basket_risk_evidence,f)) return false; body+=f;
   SWV5S5_CPR_D("projected_margin",v.projected_margin); SWV5S5_CPR_D("projected_maximum_loss",v.projected_maximum_loss);
#undef SWV5S5_CPR_D
   if(!SWV5S5_CanonicalMonetaryBasis("monetary_basis",v.monetary_basis,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("calculated_at",v.calculated_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("complete",v.complete,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_DeriveRiskBindingDigest(const SWV5_RiskEvaluationInput &v,string &digest)
{
   string body="",f;
   SWV5S5_SymbolSpecificationAuthorityView specification; specification.specification=v.symbol_specification;
   if(!SWV5S5_CanonicalContractVersion("version",v.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalExecutionIntent("intent",v.intent,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account_namespace",v.account_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("account_mode",v.account_mode,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRiskLimits("limits",v.limits,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountRiskSnapshot("account",v.account,f)) return false; body+=f;
   if(!SWV5S5_CanonicalExposureRiskSnapshot("exposure",v.exposure,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBasketRiskSnapshot("basket",v.basket,f)) return false; body+=f;
   if(!SWV5S5_CanonicalProjectedRequestRisk("projected",v.projected,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("has_margin_authority",v.has_margin_authority_record,f)) return false; body+=f;
   if(!SWV5S5_CanonicalMarginAuthority("margin_authority",v.margin_authority_record,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("has_basket_risk_authority",v.has_basket_risk_authority_record,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBasketRiskAuthority("basket_risk_authority",v.basket_risk_authority_record,f)) return false; body+=f;
   if(!SWV5S5_DeriveSymbolProjection(specification) ||
      !SWV5S5_CanonicalString("symbol_specification_digest",specification.projection_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("ownership_fence",v.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalHardKillState("hard_kill",v.hard_kill_state,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_ADMISSION_SNAPSHOT,body,digest);
}

bool SWV5S5_DeriveRiskProjection(SWV5S5_RiskAuthorizationAuthorityView &view)
{
   string projection,binding_digest,f;
   if(view.authorization.authorization_id=="" || view.authorization.disposition!=SWV5_RISK_ALLOW) return false;
   if(!SWV5S5_CanonicalRiskAuthorization("risk_authorization",view.authorization,projection) ||
      !SWV5S5_DeriveRiskBindingDigest(view.current_binding,binding_digest) ||
      !SWV5S5_CanonicalString("current_binding_digest",binding_digest,f)) return false;
   return SWV5S5_SHA256(projection+f,view.projection_digest);
}

bool SWV5S5_DeriveNormalizedProjection(SWV5S5_NormalizedPayloadAuthorityView &view)
{
   string body,f,content;
   if(view.normalization_identity=="" || view.unit_authority_id=="" || view.unit_authority_revision==0 ||
      !SWV5S5_IsDigest64Lower(view.unit_authority_digest) ||
      !SWV5S5_CanonicalNormalizedPayload("payload",view.payload,body) ||
      !SWV5S5_SHA256(body,content)) return false;
   view.payload_content_digest=content;
   if(!SWV5S5_CanonicalString("payload_content_digest",content,f)) return false; body=f;
   if(!SWV5S5_CanonicalString("normalization_identity",view.normalization_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("unit_authority_id",view.unit_authority_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("unit_authority_revision",view.unit_authority_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("unit_authority_digest",view.unit_authority_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("specification_sequence",view.payload.specification_sequence,f)) return false; body+=f;
   return SWV5S5_SHA256(body,view.projection_digest);
}

bool SWV5S5_DerivePermitProjection(SWV5S5_SubmissionPermitAuthorityView &view)
{
   string expected;
   if(!SWV5S5_DerivePermitDigest(view.permit,expected) || view.permit.permit_digest!=expected) return false;
   view.projection_digest=expected; return true;
}

bool SWV5S5_DerivePolicyProjection(SWV5S5_PolicyFormatAuthorityView &view)
{
   string body="",f;
   if(view.admission_policy_id!=SWV5S5_POLICY_ID || view.admission_policy_version!=SWV5S5_SCHEMA_VERSION ||
      view.canonical_format_id!=SWV5S5_CANONICAL_POLICY_ID) return false;
   if(!SWV5S5_CanonicalString("admission_policy_id",view.admission_policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("admission_policy_version",view.admission_policy_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("canonical_format_id",view.canonical_format_id,f)) return false; body+=f;
   return SWV5S5_SHA256(body,view.projection_digest);
}

bool SWV5S5_DeriveCollectionDigest(SWV5S5_AdmissionAuthorityCollection &collection)
{
   if(!SWV5S5_DeriveOwnershipProjection(collection.ownership) || !SWV5S5_DeriveLeaseProjection(collection.lease_liveness) ||
      !SWV5S5_DeriveTrustProjection(collection.producer_trust) || !SWV5S5_DeriveHardKillProjection(collection.hard_kill) ||
      !SWV5S5_DeriveAccountProjection(collection.account) || !SWV5S5_DeriveBasketProjection(collection.basket) ||
      !SWV5S5_DeriveRequestSetProjection(collection.request_set) || !SWV5S5_DeriveSymbolProjection(collection.symbol_specification) ||
      !SWV5S5_DeriveMarginProjection(collection.margin) || !SWV5S5_DeriveBasketRiskProjection(collection.basket_risk) ||
      !SWV5S5_DeriveRiskProjection(collection.risk_authorization) || !SWV5S5_DeriveNormalizedProjection(collection.normalized_payload) ||
      !SWV5S5_DerivePermitProjection(collection.submission_permit) || !SWV5S5_DerivePolicyProjection(collection.policy_format)) return false;
   string body="",f;
   if(!SWV5S5_CanonicalNamespace("scope",collection.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",collection.request_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("attempt_id",collection.attempt_id,f)) return false; body+=f;
#define SWV5S5_CP(n,m) if(!SWV5S5_CanonicalString(n,collection.m.projection_digest,f)) return false; else body+=f
   SWV5S5_CP("ownership",ownership); SWV5S5_CP("lease_liveness",lease_liveness); SWV5S5_CP("producer_trust",producer_trust);
   SWV5S5_CP("hard_kill",hard_kill); SWV5S5_CP("account",account); SWV5S5_CP("basket",basket);
   SWV5S5_CP("request_set",request_set); SWV5S5_CP("symbol_specification",symbol_specification); SWV5S5_CP("margin",margin);
   SWV5S5_CP("basket_risk",basket_risk); SWV5S5_CP("risk_authorization",risk_authorization);
   SWV5S5_CP("normalized_payload",normalized_payload); SWV5S5_CP("submission_permit",submission_permit); SWV5S5_CP("policy_format",policy_format);
#undef SWV5S5_CP
   if(!SWV5S5_CanonicalClockObservation("collect_clock",collection.collect_clock,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_ADMISSION_SNAPSHOT,body,collection.collection_digest);
}

bool SWV5S5_DeriveAdmissionSnapshotDigest(SWV5S5_AdmissionSnapshot &snapshot,string &digest)
{
   string body="",f;
   if(!SWV5S5_DeriveCollectionDigest(snapshot.collect_v1) || !SWV5S5_DeriveCollectionDigest(snapshot.collect_v2)) return false;
   if(!SWV5S5_CanonicalContractVersion("version",snapshot.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("canonical_policy_id",snapshot.canonical_policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("collect_v1_digest",snapshot.collect_v1.collection_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("collect_v2_digest",snapshot.collect_v2.collection_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalClockObservation("claim_clock",snapshot.claim_clock,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_ADMISSION_SNAPSHOT,body,digest);
}

bool SWV5S5_EqualCollectionSafety(const SWV5S5_AdmissionAuthorityCollection &a,
                                  const SWV5S5_AdmissionAuthorityCollection &b,string &changed)
{
#define SWV5S5_EQ_PROJ(m,label) if(a.m.projection_digest!=b.m.projection_digest){ changed=label; return false; }
   if(!SWV5S5_EqualNamespace(a.persistence_namespace,b.persistence_namespace) ||
      !SWV5S5_EqualRequestIdentity(a.request_identity,b.request_identity) || a.attempt_id!=b.attempt_id)
   { changed="ENVELOPE"; return false; }
   if(!SWV5S5_EqualFence(a.ownership.fence,b.ownership.fence)) { changed="OWNERSHIP"; return false; }
   if(a.lease_liveness.lease.store_revision!=b.lease_liveness.lease.store_revision ||
      a.lease_liveness.lease.heartbeat_sequence!=b.lease_liveness.lease.heartbeat_sequence ||
      a.lease_liveness.lease.expiry_clock_sequence!=b.lease_liveness.lease.expiry_clock_sequence)
   { changed="LEASE_LIVENESS"; return false; }
   if(a.producer_trust.record.authority_record_id!=b.producer_trust.record.authority_record_id ||
      a.producer_trust.record.authority_generation!=b.producer_trust.record.authority_generation ||
      a.producer_trust.record.record_digest!=b.producer_trust.record.record_digest)
   { changed="PRODUCER_TRUST"; return false; }
   SWV5S5_EQ_PROJ(ownership,"OWNERSHIP"); SWV5S5_EQ_PROJ(lease_liveness,"LEASE_LIVENESS");
   SWV5S5_EQ_PROJ(producer_trust,"PRODUCER_TRUST"); SWV5S5_EQ_PROJ(hard_kill,"HARD_KILL");
   SWV5S5_EQ_PROJ(account,"ACCOUNT"); SWV5S5_EQ_PROJ(basket,"BASKET"); SWV5S5_EQ_PROJ(request_set,"REQUEST_SET");
   SWV5S5_EQ_PROJ(symbol_specification,"SYMBOL_SPECIFICATION"); SWV5S5_EQ_PROJ(margin,"MARGIN");
   SWV5S5_EQ_PROJ(basket_risk,"BASKET_RISK"); SWV5S5_EQ_PROJ(risk_authorization,"RISK_AUTHORIZATION");
   SWV5S5_EQ_PROJ(normalized_payload,"NORMALIZED_PAYLOAD"); SWV5S5_EQ_PROJ(submission_permit,"SUBMISSION_PERMIT");
   SWV5S5_EQ_PROJ(policy_format,"POLICY_FORMAT");
#undef SWV5S5_EQ_PROJ
   return true;
}

bool SWV5S5_ValidateAdmissionAuthorityCollection(
   const SWV5_ContractValidationContext &claim_context,
   const SWV5S5_AdmissionProofInput &proof_input,
   SWV5S5_AdmissionAuthorityCollection &collection,
   ISWV5RiskContract &risk_contract,
   string &reason)
{
   reason="";
   SWV5_ContractValidationContext collect_context=claim_context;
   collect_context.clock_id=collection.collect_clock.clock_id;
   collect_context.clock_authority=collection.collect_clock.clock_authority;
   collect_context.clock_sequence=collection.collect_clock.clock_sequence;
   collect_context.clock_time=collection.collect_clock.observed_at;
   SWV5S5_ValidationResult trust_validation,permit_validation;
   SWV5_ContractDecision risk_decision;
   string ingress_id,ingress_digest,request_canonical,permit_risk,view_risk,permit_account,view_account;
   int request_matches=0;
   if(!SWV5S5_IsValidationContextUsable(collect_context) || !SWV5S5_DeriveCollectionDigest(collection))
   { reason="COLLECTION_STRUCTURE_INVALID"; return false; }
   if(!SWV5S5_DeriveIngressIdentityAndDigest(proof_input.accepted_ingress,ingress_id,ingress_digest) ||
      ingress_id!=proof_input.accepted_ingress.ingress_identity || ingress_digest!=proof_input.accepted_ingress.payload_digest ||
      proof_input.trust_scope.ingress_identity!=ingress_id)
   { reason="INGRESS_BINDING_INVALID"; return false; }
   if(!SWV5S5_EqualNamespace(collection.persistence_namespace,collection.submission_permit.permit.persistence_namespace) ||
      !SWV5S5_EqualNamespace(collection.persistence_namespace,collection.producer_trust.record.persistence_namespace) ||
      !SWV5S5_EqualNamespace(collection.persistence_namespace,collection.request_set.persistence_namespace) ||
      !SWV5S5_EqualOwnershipKey(collection.persistence_namespace.ownership_namespace,collection.ownership.fence.ownership_namespace) ||
      !SWV5S5_EqualFence(collection.ownership.fence,collection.lease_liveness.lease.fence) ||
      !SWV5S5_EqualFence(collection.ownership.fence,collection.request_set.ownership_fence) ||
      !SWV5S5_EqualFence(collection.ownership.fence,collection.submission_permit.permit.ownership_fence))
   { reason="NAMESPACE_OWNERSHIP_BINDING_INVALID"; return false; }
   if(collection.lease_liveness.lease.clock_id!=collection.collect_clock.clock_id ||
      collection.lease_liveness.lease.clock_authority!=collection.collect_clock.clock_authority ||
      collection.lease_liveness.lease.heartbeat_clock_sequence>collection.collect_clock.clock_sequence ||
      collection.collect_clock.observed_at<collection.lease_liveness.lease.heartbeat_at ||
      collection.collect_clock.observed_at>=collection.lease_liveness.lease.expires_at)
   { reason="LEASE_LIVENESS_INVALID"; return false; }
   if(!SWV5S5_ValidateProducerTrust(collect_context,collection.producer_trust.record,
                                    proof_input.trust_anchor,proof_input.trust_scope,
                                    proof_input.accepted_ingress,trust_validation))
   { reason="PRE_P_TRUST_INVALID"; return false; }
   if(collection.hard_kill.state.state==SWV5_HARD_KILL_ACTIVE ||
      collection.hard_kill.state.state==SWV5_HARD_KILL_RELEASE_PENDING ||
      !SWV5S5_EqualNamespace(collection.hard_kill.state.persistence_namespace,collection.persistence_namespace) ||
      collection.hard_kill.state.latch_id=="" || collection.hard_kill.state.latch_generation==0)
   { reason="PRE_P_HARD_KILL_DENIED"; return false; }
   if(collection.account.account_namespace.account_mode!=SWV5_ACCOUNT_MODE_HEDGING ||
      collection.account.account_namespace.snapshot_epoch==0 ||
      collection.account.account_namespace.account_login!=collection.persistence_namespace.ownership_namespace.account_login ||
      collection.account.account_namespace.broker_identity!=collection.persistence_namespace.ownership_namespace.broker_identity ||
      collection.account.account_namespace.server!=collection.persistence_namespace.ownership_namespace.server ||
      collection.account.account_namespace.strategy_id!=collection.persistence_namespace.ownership_namespace.strategy_id ||
      collection.account.account_namespace.magic!=collection.persistence_namespace.ownership_namespace.magic)
   { reason="ACCOUNT_BINDING_INVALID"; return false; }
   if(collection.basket.basket.basket_id.value!=collection.persistence_namespace.basket_id.value ||
      collection.basket.basket.state_version==0 ||
      !SWV5S5_EqualFence(collection.basket.basket.ownership_fence,collection.ownership.fence))
   { reason="BASKET_BINDING_INVALID"; return false; }
   for(int i=0;i<ArraySize(collection.request_set.requests);i++)
   {
      if(SWV5S5_EqualRequestIdentity(collection.request_set.requests[i].intent.request_identity,collection.request_identity))
      {
         request_matches++;
         if(collection.request_set.requests[i].state!=SWV5_REQUEST_SUBMISSION_PENDING ||
            collection.request_set.requests[i].lifecycle_phase!=SWV5_EXECUTION_PHASE_SUBMISSION)
         { reason="REQUEST_LIFECYCLE_NOT_ADMISSIBLE"; return false; }
         if(!SWV5S5_CanonicalPendingRequest(collection.request_set.requests[i],request_canonical) ||
            !SWV5S5_EqualRequestIdentity(collection.request_set.requests[i].intent.request_identity,
                                         collection.submission_permit.permit.request_identity) ||
            collection.request_set.requests[i].intent.normalized_volume!=collection.normalized_payload.payload.volume ||
            collection.request_set.requests[i].intent.normalized_price!=collection.normalized_payload.payload.price ||
            collection.request_set.requests[i].intent.normalized_stop_price!=collection.normalized_payload.payload.stop_price ||
            collection.request_set.requests[i].intent.normalized_limit_price!=collection.normalized_payload.payload.limit_price ||
            collection.request_set.requests[i].intent.symbol_specification_sequence!=collection.normalized_payload.payload.specification_sequence ||
            collection.request_set.requests[i].intent.expected_basket_version!=collection.basket.basket.state_version ||
            collection.request_set.requests[i].normalization_identity!=collection.normalized_payload.normalization_identity)
         { reason="REQUEST_PAYLOAD_BINDING_INVALID"; return false; }
      }
   }
   if(request_matches!=1) { reason="REQUEST_SET_EXACT_MEMBER_MISSING"; return false; }
   if(collection.symbol_specification.specification.symbol!=collection.persistence_namespace.ownership_namespace.symbol ||
      collection.symbol_specification.specification.specification_sequence!=collection.normalized_payload.payload.specification_sequence ||
      collection.symbol_specification.specification.specification_sequence!=collection.submission_permit.permit.symbol_specification_sequence ||
      !collection.symbol_specification.specification.complete)
   { reason="SYMBOL_SPECIFICATION_BINDING_INVALID"; return false; }
   if(collection.normalized_payload.normalization_identity!=collection.submission_permit.permit.normalization_identity ||
      collection.normalized_payload.unit_authority_id!=collection.submission_permit.permit.unit_authority_id ||
      collection.normalized_payload.unit_authority_revision!=collection.submission_permit.permit.unit_authority_revision ||
      collection.normalized_payload.unit_authority_digest!=collection.submission_permit.permit.unit_authority_digest ||
      collection.normalized_payload.payload_content_digest=="" ||
      collection.attempt_id!=collection.request_identity.request_id.attempt_id ||
      collection.attempt_id!=collection.submission_permit.permit.unique_attempt_id ||
      !SWV5S5_EqualRequestIdentity(collection.request_identity,collection.submission_permit.permit.request_identity))
   { reason="NORMALIZED_OR_PERMIT_BINDING_INVALID"; return false; }
   if(!SWV5S5_ValidatePermit(collect_context,collection.submission_permit.permit,permit_validation) ||
      collection.submission_permit.permit.producer_trust.record_digest!=collection.producer_trust.record.record_digest ||
      collection.submission_permit.permit.producer_trust.authority_record_id!=proof_input.trust_anchor.current_authority_record_id ||
      collection.submission_permit.permit.producer_trust.authority_generation!=proof_input.trust_anchor.current_authority_generation)
   { reason="PERMIT_NESTED_AUTHORITY_INVALID"; return false; }
   if(!SWV5S5_CanonicalRiskAuthorization("risk",collection.submission_permit.permit.risk_authorization,permit_risk) ||
      !SWV5S5_CanonicalRiskAuthorization("risk",collection.risk_authorization.authorization,view_risk) ||
      permit_risk!=view_risk ||
      !SWV5S5_CanonicalAccountNamespace("account",collection.account.account_namespace,view_account) ||
      !SWV5S5_CanonicalAccountNamespace("account",collection.risk_authorization.authorization.account_namespace,permit_account) ||
      view_account!=permit_account ||
      !SWV5S5_EqualRequestIdentity(collection.risk_authorization.authorization.request_identity,collection.request_identity) ||
      !SWV5S5_EqualFence(collection.risk_authorization.authorization.ownership_fence,collection.ownership.fence) ||
      collection.risk_authorization.authorization.basket_state_version!=collection.basket.basket.state_version ||
      collection.risk_authorization.authorization.symbol_specification_sequence!=collection.symbol_specification.specification.specification_sequence ||
      collection.risk_authorization.authorization.authorized_volume!=collection.normalized_payload.payload.volume ||
      collection.risk_authorization.authorization.authorized_price!=collection.normalized_payload.payload.price ||
      collection.risk_authorization.authorization.authorized_stop_price!=collection.normalized_payload.payload.stop_price ||
      collection.risk_authorization.authorization.authorized_limit_price!=collection.normalized_payload.payload.limit_price ||
      collection.risk_authorization.authorization.hard_kill_latch_id!=collection.hard_kill.state.latch_id ||
      collection.risk_authorization.authorization.hard_kill_latch_generation!=collection.hard_kill.state.latch_generation)
   { reason="RISK_AUTHORIZATION_BINDING_INVALID"; return false; }
   const SWV5_RiskEvaluationInput risk_binding=collection.risk_authorization.current_binding;
   if(!SWV5S5_EqualRequestIdentity(risk_binding.intent.request_identity,collection.request_identity) ||
      !SWV5S5_EqualNamespace(risk_binding.intent.persistence_namespace,collection.persistence_namespace) ||
      !SWV5S5_EqualFence(risk_binding.ownership_fence,collection.ownership.fence) ||
      risk_binding.account_mode!=SWV5_ACCOUNT_MODE_HEDGING ||
      risk_binding.account_namespace.snapshot_epoch!=collection.account.account_namespace.snapshot_epoch ||
      risk_binding.basket.lifecycle.basket_id.value!=collection.basket.basket.basket_id.value ||
      risk_binding.basket.lifecycle.state_version!=collection.basket.basket.state_version ||
      risk_binding.symbol_specification.specification_sequence!=collection.symbol_specification.specification.specification_sequence ||
      risk_binding.hard_kill_state.latch_id!=collection.hard_kill.state.latch_id ||
      risk_binding.hard_kill_state.latch_generation!=collection.hard_kill.state.latch_generation ||
      !risk_binding.has_margin_authority_record || !risk_binding.has_basket_risk_authority_record ||
      risk_binding.margin_authority_record.authority_record_digest!=collection.margin.record.authority_record_digest ||
      risk_binding.basket_risk_authority_record.authority_record_digest!=collection.basket_risk.record.authority_record_digest ||
      collection.margin.record.request_identity.request_id.correlation_id!=collection.request_identity.request_id.correlation_id ||
      collection.margin.record.requested_volume!=collection.normalized_payload.payload.volume ||
      collection.margin.record.requested_price!=collection.normalized_payload.payload.price ||
      collection.basket_risk.record.request_identity.request_id.correlation_id!=collection.request_identity.request_id.correlation_id ||
      collection.basket_risk.record.basket_id.value!=collection.basket.basket.basket_id.value ||
      collection.basket_risk.record.source_snapshot_id=="" ||
      !SWV5S5_IsDigest64Lower(collection.basket_risk.record.source_snapshot_digest) ||
      !risk_contract.ValidateAuthorization(collect_context,collection.risk_authorization.authorization,risk_binding,risk_decision) ||
      risk_decision.disposition!=SWV5_DISPOSITION_ALLOW)
   { reason="V5_RISK_BINDING_DENIED"; return false; }
   return true;
}

bool SWV5S5_DeriveAdmissionProofDigest(SWV5S5_AdmissionProof &proof,string &digest)
{
   string body="",f,snapshot_digest,ingress_identity,ingress_payload;
   if(!proof.v1_semantically_valid || !proof.v2_semantically_valid || !proof.stable_owner_evidence ||
      !proof.safety_projections_equal || !proof.relationally_bound || !proof.pre_p_admissible ||
      !proof.claim_time_valid || !SWV5S5_DeriveAdmissionSnapshotDigest(proof.snapshot,snapshot_digest) ||
      proof.snapshot.snapshot_digest!=snapshot_digest ||
      !SWV5S5_DeriveIngressIdentityAndDigest(proof.accepted_ingress,ingress_identity,ingress_payload) ||
      proof.accepted_ingress.ingress_identity!=ingress_identity || proof.accepted_ingress.payload_digest!=ingress_payload ||
      proof.trust_scope.ingress_identity!=ingress_identity || proof.trust_anchor.trust_anchor_id=="") return false;
   if(!SWV5S5_CanonicalContractVersion("version",proof.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("snapshot_digest",snapshot_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("v1_semantically_valid",proof.v1_semantically_valid,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("v2_semantically_valid",proof.v2_semantically_valid,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("stable_owner_evidence",proof.stable_owner_evidence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("safety_projections_equal",proof.safety_projections_equal,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("relationally_bound",proof.relationally_bound,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("pre_p_admissible",proof.pre_p_admissible,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("claim_time_valid",proof.claim_time_valid,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("trust_anchor_id",proof.trust_anchor.trust_anchor_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("trust_current_record",proof.trust_anchor.current_authority_record_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("trust_current_generation",proof.trust_anchor.current_authority_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("accepted_ingress_identity",ingress_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("accepted_ingress_payload",ingress_payload,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_ADMISSION_SNAPSHOT,body,digest);
}

bool SWV5S5_DoubleCollect(const SWV5_ContractValidationContext &claim_context,
                          const SWV5S5_AdmissionProofInput &proof_input,
                          ISWV5RiskContract &risk_contract,
                          SWV5S5_AdmissionSnapshot &snapshot,
                          SWV5S5_DoubleCollectResult &result,
                          SWV5S5_AdmissionProof &proof)
{
   ZeroMemory(result); ZeroMemory(proof);
   SWV5S5_InitContractVersion(result.contract_version); SWV5S5_InitContractVersion(proof.contract_version);
   string v1_digest,v2_digest,changed;
   if(!SWV5S5_IsCandidateVersion(snapshot.contract_version) || snapshot.canonical_policy_id!=SWV5S5_CANONICAL_POLICY_ID ||
      !SWV5S5_DeriveCollectionDigest(snapshot.collect_v1) || !SWV5S5_DeriveCollectionDigest(snapshot.collect_v2))
   { result.disposition=SWV5S5_COLLECT_FAIL_CLOSED; result.reason_code="COLLECTION_INVALID"; return false; }
   if(snapshot.collect_v1.collect_clock.clock_id!=snapshot.collect_v2.collect_clock.clock_id ||
      snapshot.collect_v1.collect_clock.clock_authority!=snapshot.collect_v2.collect_clock.clock_authority ||
      snapshot.collect_v2.collect_clock.clock_sequence<snapshot.collect_v1.collect_clock.clock_sequence ||
      snapshot.collect_v2.collect_clock.observed_at<snapshot.collect_v1.collect_clock.observed_at)
   { result.disposition=SWV5S5_COLLECT_CLOCK_REGRESSION; result.reason_code="COLLECT_CLOCK_REGRESSION"; return false; }
   string semantic_reason;
   if(!SWV5S5_ValidateAdmissionAuthorityCollection(claim_context,proof_input,snapshot.collect_v1,risk_contract,semantic_reason))
   { result.disposition=SWV5S5_COLLECT_FAIL_CLOSED; result.reason_code="V1_"+semantic_reason; return false; }
   proof.v1_semantically_valid=true;
   if(!SWV5S5_ValidateAdmissionAuthorityCollection(claim_context,proof_input,snapshot.collect_v2,risk_contract,semantic_reason))
   { result.disposition=SWV5S5_COLLECT_FAIL_CLOSED; result.reason_code="V2_"+semantic_reason; return false; }
   proof.v2_semantically_valid=true;
   if(!SWV5S5_EqualCollectionSafety(snapshot.collect_v1,snapshot.collect_v2,changed))
   { result.disposition=SWV5S5_COLLECT_RETRYABLE_UNSTABLE; result.changed_authority=changed; result.reason_code="DOUBLE_COLLECT_CHANGED"; return false; }
   proof.stable_owner_evidence=true; proof.safety_projections_equal=true;
   if(snapshot.claim_clock.clock_id!=claim_context.clock_id || snapshot.claim_clock.clock_authority!=claim_context.clock_authority ||
      snapshot.claim_clock.clock_sequence!=claim_context.clock_sequence || snapshot.claim_clock.observed_at!=claim_context.clock_time ||
      snapshot.claim_clock.clock_sequence<snapshot.collect_v2.collect_clock.clock_sequence ||
      snapshot.claim_clock.observed_at<snapshot.collect_v2.collect_clock.observed_at ||
      !SWV5S5_EqualFence(proof_input.current_ownership_lease.fence,snapshot.collect_v2.ownership.fence) ||
      proof_input.current_ownership_lease.store_revision!=snapshot.collect_v2.lease_liveness.lease.store_revision ||
      proof_input.current_ownership_lease.heartbeat_sequence!=snapshot.collect_v2.lease_liveness.lease.heartbeat_sequence ||
      claim_context.clock_time>=proof_input.current_ownership_lease.expires_at ||
      claim_context.clock_time>=snapshot.collect_v2.producer_trust.record.valid_until ||
      claim_context.clock_time>=snapshot.collect_v2.risk_authorization.authorization.expires_at ||
      claim_context.clock_time>=snapshot.collect_v2.submission_permit.permit.valid_until ||
      claim_context.clock_time>=snapshot.collect_v2.symbol_specification.specification.valid_until)
   { result.disposition=SWV5S5_COLLECT_FAIL_CLOSED; result.reason_code="CLAIM_TIME_AUTHORITY_INVALID"; return false; }
   const uint max_age=snapshot.collect_v2.risk_authorization.current_binding.limits.maximum_snapshot_age_seconds;
   if(max_age==0 || snapshot.collect_v2.margin.record.observed_at<=0 || snapshot.collect_v2.basket_risk.record.observed_at<=0 ||
      claim_context.clock_time<snapshot.collect_v2.margin.record.observed_at ||
      claim_context.clock_time<snapshot.collect_v2.basket_risk.record.observed_at ||
      (ulong)(claim_context.clock_time-snapshot.collect_v2.margin.record.observed_at)>(ulong)max_age ||
      (ulong)(claim_context.clock_time-snapshot.collect_v2.basket_risk.record.observed_at)>(ulong)max_age)
   { result.disposition=SWV5S5_COLLECT_FAIL_CLOSED; result.reason_code="CLAIM_TIME_FRESHNESS_INVALID"; return false; }
   if(!SWV5S5_DeriveAdmissionSnapshotDigest(snapshot,snapshot.snapshot_digest))
   { result.disposition=SWV5S5_COLLECT_FAIL_CLOSED; result.reason_code="SNAPSHOT_DIGEST_FAILED"; return false; }
   proof.relationally_bound=true; proof.pre_p_admissible=true; proof.claim_time_valid=true;
   proof.trust_anchor=proof_input.trust_anchor; proof.trust_scope=proof_input.trust_scope;
   proof.accepted_ingress=proof_input.accepted_ingress;
   proof.snapshot=snapshot; proof.reason_code="ADMISSION_PROOF_VALID";
   if(!SWV5S5_DeriveAdmissionProofDigest(proof,proof.proof_digest))
   { result.disposition=SWV5S5_COLLECT_FAIL_CLOSED; result.reason_code="ADMISSION_PROOF_DIGEST_FAILED"; return false; }
   result.provisional_snapshot_digest=snapshot.snapshot_digest;
   result.disposition=SWV5S5_COLLECT_STABLE_PROVISIONAL;
   result.reason_code="STABLE_SEMANTICALLY_ADMISSIBLE_RELATIONALLY_BOUND";
   return true;
}

#endif
