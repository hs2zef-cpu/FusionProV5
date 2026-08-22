#ifndef SW_V5_S5_REQUEST_BINDING_CONTRACT_MQH
#define SW_V5_S5_REQUEST_BINDING_CONTRACT_MQH

// SPRINT 5 PHASE B.1 CANDIDATE CONTRACT
// PURE DETERMINISTIC INITIAL REQUEST BLUEPRINT / NO LIFECYCLE EXECUTION

#include "SW_V5_S5_RequestSequenceContract.mqh"

struct SWV5S5_RequestBinding
{
   SWV5_ContractVersion contract_version;
   string binding_policy_id;
   uint binding_policy_version;
   SWV5_PersistenceNamespace persistence_namespace;
   string accepted_ingress_identity;
   datetime accepted_at;
   string logical_correlation_id;
   ulong logical_request_sequence;
   uint attempt_ordinal;
   string attempt_id;
   string idempotency_key;
   string binding_digest;
};

struct SWV5S5_InitialRequestBlueprint
{
   SWV5_ContractVersion contract_version;
   SWV5S5_RequestBinding binding;
   SWV5_PendingRequest pending_request;
   string blueprint_digest;
};

bool SWV5S5_CanonicalPendingRequest(const SWV5_PendingRequest &request,string &record)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("request_version",request.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("intent_version",request.intent.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",request.intent.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",request.intent.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",request.intent.request_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("intent_account_mode",request.intent.account_mode,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("intent_type",request.intent.intent_type,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("direction",request.intent.direction,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("normalized_volume",request.intent.normalized_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("normalized_price",request.intent.normalized_price,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("normalized_stop",request.intent.normalized_stop_price,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("normalized_limit",request.intent.normalized_limit_price,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("specification_sequence",request.intent.symbol_specification_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expected_basket_version",request.intent.expected_basket_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("risk_authorization_id",request.intent.risk_authorization_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("authorization_expires_at",request.intent.authorization_expires_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("account_mode",request.account_mode,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("phase",request.lifecycle_phase,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("state",request.state,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("attempts",request.submission_attempt_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("submission_version",request.latest_submission.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("submission_request",request.latest_submission.request_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("submission_count",request.latest_submission.submission_attempt_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("submitted_at",request.latest_submission.submitted_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("submission_authority",request.latest_submission.authority,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("retcode_version",request.latest_retcode.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("retcode_scope",request.latest_retcode.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("retcode_fence",request.latest_retcode.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("retcode_correlation_version",request.latest_retcode.correlation.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("retcode_phase",request.latest_retcode.correlation.phase,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("retcode_request",request.latest_retcode.correlation.request_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("retcode_broker_version",request.latest_retcode.correlation.broker_identity.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("retcode_order",request.latest_retcode.correlation.broker_identity.order_ticket,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("retcode_deal",request.latest_retcode.correlation.broker_identity.deal_ticket,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("retcode_position",request.latest_retcode.correlation.broker_identity.position_identifier,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("retcode_event",request.latest_retcode.correlation.broker_identity.broker_event_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("retcode_transaction",request.latest_retcode.correlation.broker_identity.transaction_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("raw_retcode",request.latest_retcode.raw_retcode,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("broker_comment",request.latest_retcode.broker_comment,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("retcode_observed_at",request.latest_retcode.observed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("retcode_classification_version",request.latest_retcode_classification.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("retcode_class",request.latest_retcode_classification.classification,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("retcode_retry",request.latest_retcode_classification.retry_disposition,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("retcode_mapping_policy",request.latest_retcode_classification.mapping_policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("retcode_decision_version",request.latest_retcode_classification.decision.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("retcode_decision",request.latest_retcode_classification.decision.disposition,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("retcode_reason_flags",request.latest_retcode_classification.decision.reason_flags,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("retcode_reason_code",request.latest_retcode_classification.decision.reason_code,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("retcode_reason_text",request.latest_retcode_classification.decision.reason_text,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("retcode_evaluated_schema",request.latest_retcode_classification.decision.evaluated_schema_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("retcode_evaluation_sequence",request.latest_retcode_classification.decision.evaluation_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("retcode_evaluated_at",request.latest_retcode_classification.decision.evaluated_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("confirmation_version",request.latest_authoritative_confirmation.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("confirmation_correlation_version",request.latest_authoritative_confirmation.correlation.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("confirmation_phase",request.latest_authoritative_confirmation.correlation.phase,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("confirmation_request",request.latest_authoritative_confirmation.correlation.request_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("confirmation_broker_version",request.latest_authoritative_confirmation.correlation.broker_identity.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("confirmation_order",request.latest_authoritative_confirmation.correlation.broker_identity.order_ticket,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("confirmation_deal",request.latest_authoritative_confirmation.correlation.broker_identity.deal_ticket,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("confirmation_position",request.latest_authoritative_confirmation.correlation.broker_identity.position_identifier,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("confirmation_event",request.latest_authoritative_confirmation.correlation.broker_identity.broker_event_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("confirmation_transaction",request.latest_authoritative_confirmation.correlation.broker_identity.transaction_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("confirmation_status",request.latest_authoritative_confirmation.status,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("confirmation_cumulative",request.latest_authoritative_confirmation.cumulative_confirmed_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("confirmation_residual",request.latest_authoritative_confirmation.residual_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("confirmation_authority",request.latest_authoritative_confirmation.authority,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("confirmation_sequence",request.latest_authoritative_confirmation.confirmation_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("confirmed_at",request.latest_authoritative_confirmation.confirmed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("confirmed",request.cumulative_confirmed_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("residual",request.residual_requested_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalContractVersion("event_index_version",request.accepted_event_identities.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("fingerprint_policy",request.accepted_event_identities.fingerprint_policy,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("event_index",request.accepted_event_identities.canonical_event_index,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("fingerprint_index",request.accepted_event_identities.canonical_fingerprint_index,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("event_index_digest",request.accepted_event_identities.identity_set_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("accepted_identity_count",request.accepted_event_identities.accepted_identity_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("highest_transaction_sequence",request.accepted_event_identities.highest_transaction_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("event_index_revision",request.accepted_event_identities.index_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("event_compaction_generation",request.accepted_event_identities.compaction_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("retry",request.retry_disposition,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("authorization",request.authorization_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("normalization",request.normalization_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("changed",request.last_changed_at,f)) return false; body+=f;
   return SWV5S5_CanonicalNested("pending_request",body,record);
}

bool SWV5S5_DeriveRequestBinding(const SWV5_PersistenceNamespace &persistence_namespace,
                                 const string binding_policy_id,const uint binding_policy_version,
                                 const string ingress_identity,const uint attempt_ordinal,
                                 string &correlation_id,string &attempt_id,string &idempotency_key)
{
   if(ingress_identity=="" || binding_policy_id!=SWV5S5_REQUEST_BINDING_POLICY_ID ||
      binding_policy_version!=SWV5S5_REQUEST_BINDING_POLICY_VERSION) return false;
   string scope,policy,policy_version,ingress,correlation_field,ordinal,preimage;
   if(!SWV5S5_CanonicalNamespace("persistence_namespace",persistence_namespace,scope) ||
      !SWV5S5_CanonicalString("binding_policy_id",binding_policy_id,policy) ||
      !SWV5S5_CanonicalUInt("binding_policy_version",binding_policy_version,policy_version) ||
      !SWV5S5_CanonicalString("accepted_ingress_identity",ingress_identity,ingress)) return false;
   preimage=scope+policy+policy_version+ingress;
   if(!SWV5S5_DomainDigest(SWV5S5_DOMAIN_REQUEST_BINDING,preimage,correlation_id) ||
      !SWV5S5_CanonicalString("correlation_id",correlation_id,correlation_field) ||
      !SWV5S5_CanonicalUInt("attempt_ordinal",attempt_ordinal,ordinal) ||
      !SWV5S5_DomainDigest(SWV5S5_DOMAIN_ATTEMPT,correlation_field+ordinal,attempt_id) ||
      !SWV5S5_DomainDigest(SWV5S5_DOMAIN_IDEMPOTENCY,correlation_field,idempotency_key)) return false;
   return true;
}

bool SWV5S5_DeriveRequestBindingDigest(const SWV5S5_RequestBinding &binding,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",binding.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("binding_policy_id",binding.binding_policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("binding_policy_version",binding.binding_policy_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",binding.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("accepted_ingress_identity",binding.accepted_ingress_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("accepted_at",binding.accepted_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("logical_correlation_id",binding.logical_correlation_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("logical_request_sequence",binding.logical_request_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("attempt_ordinal",binding.attempt_ordinal,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("attempt_id",binding.attempt_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("idempotency_key",binding.idempotency_key,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_REQUEST_BINDING,body,digest);
}

bool SWV5S5_DeriveInitialBlueprintDigest(const SWV5S5_InitialRequestBlueprint &blueprint,string &digest)
{
   const SWV5_PendingRequest request=blueprint.pending_request;
   const SWV5_ExecutionIntent intent=request.intent;
   string body="",f;
#define SWV5S5_BP_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define SWV5S5_BP_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define SWV5S5_BP_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define SWV5S5_BP_D(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
   SWV5S5_BP_S("binding_digest",blueprint.binding.binding_digest);
   if(!SWV5S5_CanonicalNamespace("intent_scope",intent.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("intent_fence",intent.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",intent.request_identity,f)) return false; body+=f;
   SWV5S5_BP_I("account_mode",request.account_mode);
   SWV5S5_BP_I("intent_type",intent.intent_type);
   SWV5S5_BP_I("direction",intent.direction);
   SWV5S5_BP_D("volume",intent.normalized_volume);
   SWV5S5_BP_D("price",intent.normalized_price);
   SWV5S5_BP_D("stop",intent.normalized_stop_price);
   SWV5S5_BP_D("limit",intent.normalized_limit_price);
   SWV5S5_BP_U("symbol_specification_sequence",intent.symbol_specification_sequence);
   SWV5S5_BP_U("expected_basket_version",intent.expected_basket_version);
   SWV5S5_BP_S("risk_authorization_id",intent.risk_authorization_id);
   SWV5S5_BP_I("authorization_expires_at",intent.authorization_expires_at);
   SWV5S5_BP_I("lifecycle_phase",request.lifecycle_phase);
   SWV5S5_BP_I("state",request.state);
   SWV5S5_BP_U("submission_attempt_count",request.submission_attempt_count);
   SWV5S5_BP_D("cumulative_confirmed_volume",request.cumulative_confirmed_volume);
   SWV5S5_BP_D("residual_requested_volume",request.residual_requested_volume);
   SWV5S5_BP_I("retry_disposition",request.retry_disposition);
   SWV5S5_BP_S("authorization_identity",request.authorization_identity);
   SWV5S5_BP_S("normalization_identity",request.normalization_identity);
   SWV5S5_BP_I("last_changed_at",request.last_changed_at);
#undef SWV5S5_BP_I
#undef SWV5S5_BP_U
#undef SWV5S5_BP_S
#undef SWV5S5_BP_D
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_REQUEST_BINDING,body,digest);
}

bool SWV5S5_InitialEvidenceEmpty(const SWV5_PendingRequest &request)
{
   SWV5_ContractVersion zero_version; SWV5_PersistenceNamespace zero_scope;
   SWV5_OwnershipFence zero_fence; SWV5_ExecutionRequestIdentity zero_request;
   ZeroMemory(zero_version); ZeroMemory(zero_scope); ZeroMemory(zero_fence); ZeroMemory(zero_request);
   const SWV5_ExecutionCorrelation retcode_correlation=request.latest_retcode.correlation;
   const SWV5_ExecutionCorrelation confirmation_correlation=request.latest_authoritative_confirmation.correlation;
   const SWV5_ContractDecision decision=request.latest_retcode_classification.decision;
   return SWV5S5_EqualContractVersion(request.latest_submission.contract_version,zero_version) &&
          SWV5S5_EqualRequestIdentity(request.latest_submission.request_identity,zero_request) &&
          request.latest_submission.submission_attempt_count==0 && request.latest_submission.submitted_at==0 &&
          request.latest_submission.authority==SWV5_AUTHORITY_NONE &&
          SWV5S5_EqualContractVersion(request.latest_retcode.contract_version,zero_version) &&
          SWV5S5_EqualNamespace(request.latest_retcode.persistence_namespace,zero_scope) &&
          SWV5S5_EqualFence(request.latest_retcode.ownership_fence,zero_fence) &&
          SWV5S5_EqualContractVersion(retcode_correlation.contract_version,zero_version) &&
          retcode_correlation.phase==SWV5_EXECUTION_PHASE_INTENT &&
          SWV5S5_EqualRequestIdentity(retcode_correlation.request_identity,zero_request) &&
          SWV5S5_EqualContractVersion(retcode_correlation.broker_identity.contract_version,zero_version) &&
          retcode_correlation.broker_identity.order_ticket==0 && retcode_correlation.broker_identity.deal_ticket==0 &&
          retcode_correlation.broker_identity.position_identifier==0 && retcode_correlation.broker_identity.broker_event_id=="" &&
          retcode_correlation.broker_identity.transaction_sequence==0 && request.latest_retcode.raw_retcode==0 &&
          request.latest_retcode.broker_comment=="" && request.latest_retcode.observed_at==0 &&
          SWV5S5_EqualContractVersion(request.latest_retcode_classification.contract_version,zero_version) &&
          request.latest_retcode_classification.classification==SWV5_RETCODE_UNCLASSIFIED &&
          request.latest_retcode_classification.retry_disposition==SWV5_RETRY_FORBIDDEN &&
          request.latest_retcode_classification.mapping_policy_id=="" &&
          SWV5S5_EqualContractVersion(decision.contract_version,zero_version) &&
          decision.disposition==SWV5_DISPOSITION_UNAVAILABLE && decision.reason_flags==0 &&
          decision.reason_code=="" && decision.reason_text=="" && decision.evaluated_schema_version==0 &&
          decision.evaluation_sequence==0 && decision.evaluated_at==0 &&
          SWV5S5_EqualContractVersion(request.latest_authoritative_confirmation.contract_version,zero_version) &&
          SWV5S5_EqualContractVersion(confirmation_correlation.contract_version,zero_version) &&
          confirmation_correlation.phase==SWV5_EXECUTION_PHASE_INTENT &&
          SWV5S5_EqualRequestIdentity(confirmation_correlation.request_identity,zero_request) &&
          SWV5S5_EqualContractVersion(confirmation_correlation.broker_identity.contract_version,zero_version) &&
          confirmation_correlation.broker_identity.order_ticket==0 && confirmation_correlation.broker_identity.deal_ticket==0 &&
          confirmation_correlation.broker_identity.position_identifier==0 && confirmation_correlation.broker_identity.broker_event_id=="" &&
          confirmation_correlation.broker_identity.transaction_sequence==0 &&
          request.latest_authoritative_confirmation.status==SWV5_CONFIRMATION_NOT_STARTED &&
          request.latest_authoritative_confirmation.cumulative_confirmed_volume==0.0 &&
          request.latest_authoritative_confirmation.residual_volume==0.0 &&
          request.latest_authoritative_confirmation.authority==SWV5_AUTHORITY_NONE &&
          request.latest_authoritative_confirmation.confirmation_sequence==0 &&
          request.latest_authoritative_confirmation.confirmed_at==0 &&
          SWV5S5_EqualContractVersion(request.accepted_event_identities.contract_version,zero_version) &&
          request.accepted_event_identities.fingerprint_policy==SWV5_DURABLE_FINGERPRINT_POLICY_UNDEFINED &&
          request.accepted_event_identities.canonical_event_index=="" &&
          request.accepted_event_identities.canonical_fingerprint_index=="" &&
          request.accepted_event_identities.identity_set_digest=="" &&
          request.accepted_event_identities.accepted_identity_count==0 &&
          request.accepted_event_identities.highest_transaction_sequence==0 &&
          request.accepted_event_identities.index_revision==0 &&
          request.accepted_event_identities.compaction_generation==0;
}

bool SWV5S5_ValidateInitialBlueprint(const SWV5_ContractValidationContext &context,
                                     const SWV5S5_InitialRequestBlueprint &blueprint,
                                     SWV5S5_ValidationResult &result)
{
   string correlation,attempt,idempotency,binding_digest,blueprint_digest;
   const SWV5_PendingRequest request=blueprint.pending_request;
   const SWV5_ExecutionIntent intent=request.intent;
   if(!SWV5S5_IsCandidateVersion(blueprint.contract_version) ||
      !SWV5S5_IsCandidateVersion(blueprint.binding.contract_version) ||
      !SWV5S5_DeriveRequestBinding(blueprint.binding.persistence_namespace,
         blueprint.binding.binding_policy_id,blueprint.binding.binding_policy_version,
         blueprint.binding.accepted_ingress_identity,blueprint.binding.attempt_ordinal,
         correlation,attempt,idempotency) ||
      correlation!=blueprint.binding.logical_correlation_id || attempt!=blueprint.binding.attempt_id ||
      idempotency!=blueprint.binding.idempotency_key || blueprint.binding.attempt_ordinal!=0 ||
      blueprint.binding.logical_request_sequence==0 || blueprint.binding.accepted_at<=0 ||
      !SWV5S5_DeriveRequestBindingDigest(blueprint.binding,binding_digest) ||
      blueprint.binding.binding_digest!=binding_digest ||
      !SWV5S5_DeriveInitialBlueprintDigest(blueprint,blueprint_digest) ||
      blueprint.blueprint_digest!=blueprint_digest ||
      !SWV5S5_IsV5Version(request.contract_version) || !SWV5S5_IsV5Version(intent.contract_version) ||
      request.lifecycle_phase!=SWV5_EXECUTION_PHASE_INTENT || request.state!=SWV5_REQUEST_CREATED ||
      request.submission_attempt_count!=0 || !SWV5S5_InitialEvidenceEmpty(request) ||
      intent.request_identity.request_id.correlation_id!=correlation ||
      intent.request_identity.request_id.attempt_id!=attempt ||
      intent.request_identity.request_id.parent_attempt_id!="" ||
      intent.request_identity.request_id.monotonic_sequence!=blueprint.binding.logical_request_sequence ||
      intent.request_identity.request_id.created_at!=blueprint.binding.accepted_at ||
      intent.request_identity.idempotency_key!=idempotency ||
      !SWV5S5_EqualNamespace(blueprint.binding.persistence_namespace,intent.persistence_namespace) ||
      !SWV5S5_EqualOwnershipKey(intent.persistence_namespace.ownership_namespace,
                                intent.ownership_fence.ownership_namespace) ||
      request.account_mode!=intent.account_mode || request.account_mode!=SWV5_ACCOUNT_MODE_HEDGING ||
      intent.expected_basket_version==0 || intent.symbol_specification_sequence==0 ||
      !SWV5_IsFiniteNumber(intent.normalized_volume) || intent.normalized_volume<=0.0 ||
      request.cumulative_confirmed_volume!=0.0 || request.residual_requested_volume!=intent.normalized_volume ||
      request.retry_disposition!=SWV5_RETRY_FORBIDDEN ||
      request.authorization_identity!=intent.risk_authorization_id ||
      request.normalization_identity=="" || request.last_changed_at!=blueprint.binding.accepted_at)
   { SWV5S5_Deny(context,"INITIAL_BLUEPRINT_INVALID","",result); return false; }
   SWV5S5_Allow(context,"INITIAL_BLUEPRINT_VALID",result); return true;
}

#endif
