#ifndef SW_V5_S5_ADMISSION_SNAPSHOT_CONTRACT_MQH
#define SW_V5_S5_ADMISSION_SNAPSHOT_CONTRACT_MQH

// SPRINT 5 PHASE B.1 CANDIDATE CONTRACT
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
   string projection_digest;
};

struct SWV5S5_NormalizedPayloadAuthorityView
{
   SWV5_NormalizedUnits payload;
   string normalization_identity;
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

bool SWV5S5_DeriveRiskProjection(SWV5S5_RiskAuthorizationAuthorityView &view)
{
   string projection;
   if(view.authorization.authorization_id=="" || view.authorization.disposition!=SWV5_RISK_ALLOW) return false;
   return SWV5S5_CanonicalRiskAuthorization("risk_authorization",view.authorization,projection) &&
          SWV5S5_SHA256(projection,view.projection_digest);
}

bool SWV5S5_DeriveNormalizedProjection(SWV5S5_NormalizedPayloadAuthorityView &view)
{
   string body,f;
   if(view.normalization_identity=="" || !SWV5S5_CanonicalNormalizedPayload("payload",view.payload,body) ||
      !SWV5S5_CanonicalString("normalization_identity",view.normalization_identity,f)) return false;
   return SWV5S5_SHA256(body+f,view.projection_digest);
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

bool SWV5S5_DoubleCollect(SWV5S5_AdmissionSnapshot &snapshot,SWV5S5_DoubleCollectResult &result)
{
   ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
   string v1_digest,v2_digest,changed;
   if(!SWV5S5_IsCandidateVersion(snapshot.contract_version) || snapshot.canonical_policy_id!=SWV5S5_CANONICAL_POLICY_ID ||
      !SWV5S5_DeriveCollectionDigest(snapshot.collect_v1) || !SWV5S5_DeriveCollectionDigest(snapshot.collect_v2))
   { result.disposition=SWV5S5_COLLECT_FAIL_CLOSED; result.reason_code="COLLECTION_INVALID"; return false; }
   if(snapshot.collect_v1.collect_clock.clock_id!=snapshot.collect_v2.collect_clock.clock_id ||
      snapshot.collect_v1.collect_clock.clock_authority!=snapshot.collect_v2.collect_clock.clock_authority ||
      snapshot.collect_v2.collect_clock.clock_sequence<snapshot.collect_v1.collect_clock.clock_sequence ||
      snapshot.collect_v2.collect_clock.observed_at<snapshot.collect_v1.collect_clock.observed_at)
   { result.disposition=SWV5S5_COLLECT_CLOCK_REGRESSION; result.reason_code="COLLECT_CLOCK_REGRESSION"; return false; }
   if(!SWV5S5_EqualCollectionSafety(snapshot.collect_v1,snapshot.collect_v2,changed))
   { result.disposition=SWV5S5_COLLECT_RETRYABLE_UNSTABLE; result.changed_authority=changed; result.reason_code="DOUBLE_COLLECT_CHANGED"; return false; }
   // A stable pair is provisional only. It cannot manufacture the later,
   // independently observed Claim clock or a complete Admission Snapshot.
   string body="",f;
   if(!SWV5S5_CanonicalString("collect_v1_digest",snapshot.collect_v1.collection_digest,f))
   { result.disposition=SWV5S5_COLLECT_FAIL_CLOSED; result.reason_code="STABLE_PAIR_DIGEST_FAILED"; return false; }
   body+=f;
   if(!SWV5S5_CanonicalString("collect_v2_digest",snapshot.collect_v2.collection_digest,f) ||
      !SWV5S5_DomainDigest(SWV5S5_DOMAIN_ADMISSION_SNAPSHOT,body+f,result.provisional_snapshot_digest))
   { result.disposition=SWV5S5_COLLECT_FAIL_CLOSED; result.reason_code="STABLE_PAIR_DIGEST_FAILED"; return false; }
   result.disposition=SWV5S5_COLLECT_STABLE_PROVISIONAL;
   result.reason_code="PROVISIONAL_P_AVAILABLE";
   return true;
}

#endif
