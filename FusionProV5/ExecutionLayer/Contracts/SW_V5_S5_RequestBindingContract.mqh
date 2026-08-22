#ifndef SW_V5_S5_REQUEST_BINDING_CONTRACT_MQH
#define SW_V5_S5_REQUEST_BINDING_CONTRACT_MQH

// SPRINT 5 PHASE B CANDIDATE CONTRACT
// PURE DETERMINISTIC INITIAL REQUEST BLUEPRINT / NO LIFECYCLE EXECUTION

#include "SW_V5_S5_RequestSequenceContract.mqh"

struct SWV5S5_RequestBinding
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   string accepted_ingress_identity;
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

bool SWV5S5_DeriveRequestBinding(const SWV5_PersistenceNamespace &persistence_namespace,
                                 const string ingress_identity,const ulong request_sequence,
                                 const uint attempt_ordinal,string &correlation_id,
                                 string &attempt_id,string &idempotency_key)
{
   if(ingress_identity=="" || request_sequence==0) return false;
   string scope,ingress,seq,ordinal,preimage;
   if(!SWV5S5_CanonicalNamespace("persistence_namespace",persistence_namespace,scope) ||
      !SWV5S5_CanonicalString("ingress",ingress_identity,ingress) ||
      !SWV5S5_CanonicalUInt("sequence",request_sequence,seq) ||
      !SWV5S5_CanonicalUInt("attempt_ordinal",attempt_ordinal,ordinal)) return false;
   preimage=scope+ingress+seq;
   if(!SWV5S5_DomainDigest(SWV5S5_DOMAIN_REQUEST_BINDING,preimage,correlation_id) ||
      !SWV5S5_DomainDigest(SWV5S5_DOMAIN_ATTEMPT,preimage+ordinal,attempt_id) ||
      !SWV5S5_DomainDigest(SWV5S5_DOMAIN_IDEMPOTENCY,preimage,idempotency_key)) return false;
   return true;
}

bool SWV5S5_DeriveRequestBindingDigest(const SWV5S5_RequestBinding &binding,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",binding.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",binding.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("accepted_ingress_identity",binding.accepted_ingress_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("logical_correlation_id",binding.logical_correlation_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("logical_request_sequence",binding.logical_request_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("attempt_ordinal",binding.attempt_ordinal,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("attempt_id",binding.attempt_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("idempotency_key",binding.idempotency_key,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_REQUEST_BINDING,body,digest);
}

bool SWV5S5_DeriveInitialBlueprintDigest(const SWV5S5_InitialRequestBlueprint &blueprint,string &digest)
{
   const SWV5_ExecutionIntent intent=blueprint.pending_request.intent;
   string body="",f;
   if(!SWV5S5_CanonicalString("binding_digest",blueprint.binding.binding_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("intent_scope",intent.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("intent_fence",intent.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",intent.request_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("account_mode",intent.account_mode,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("intent_type",intent.intent_type,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("direction",intent.direction,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("volume",intent.normalized_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("price",intent.normalized_price,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("stop",intent.normalized_stop_price,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("limit",intent.normalized_limit_price,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("symbol_specification_sequence",intent.symbol_specification_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expected_basket_version",intent.expected_basket_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("risk_authorization_id",intent.risk_authorization_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("authorization_expires_at",intent.authorization_expires_at,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_REQUEST_BINDING,body,digest);
}

bool SWV5S5_ValidateInitialBlueprint(const SWV5_ContractValidationContext &context,
                                     const SWV5S5_InitialRequestBlueprint &blueprint,
                                     SWV5S5_ValidationResult &result)
{
   string correlation,attempt,idempotency,binding_digest,blueprint_digest;
   if(!SWV5S5_IsCandidateVersion(blueprint.contract_version) ||
      !SWV5S5_DeriveRequestBinding(blueprint.binding.persistence_namespace,
         blueprint.binding.accepted_ingress_identity,blueprint.binding.logical_request_sequence,
         blueprint.binding.attempt_ordinal,correlation,attempt,idempotency) ||
      correlation!=blueprint.binding.logical_correlation_id || attempt!=blueprint.binding.attempt_id ||
      idempotency!=blueprint.binding.idempotency_key ||
      blueprint.binding.attempt_ordinal!=0 ||
      !SWV5S5_DeriveRequestBindingDigest(blueprint.binding,binding_digest) ||
      blueprint.binding.binding_digest!=binding_digest ||
      !SWV5S5_DeriveInitialBlueprintDigest(blueprint,blueprint_digest) ||
      blueprint.blueprint_digest!=blueprint_digest ||
      blueprint.pending_request.lifecycle_phase!=SWV5_EXECUTION_PHASE_INTENT ||
      blueprint.pending_request.state!=SWV5_REQUEST_CREATED ||
      blueprint.pending_request.submission_attempt_count!=0 ||
      blueprint.pending_request.intent.request_identity.request_id.correlation_id!=correlation ||
      blueprint.pending_request.intent.request_identity.request_id.attempt_id!=attempt ||
      blueprint.pending_request.intent.request_identity.request_id.monotonic_sequence!=blueprint.binding.logical_request_sequence ||
      blueprint.pending_request.intent.request_identity.idempotency_key!=idempotency ||
      !SWV5S5_EqualNamespace(blueprint.binding.persistence_namespace,
                              blueprint.pending_request.intent.persistence_namespace) ||
      blueprint.pending_request.intent.request_identity.request_id.parent_attempt_id!="")
   { SWV5S5_Deny(context,"INITIAL_BLUEPRINT_INVALID","",result); return false; }
   SWV5S5_Allow(context,"INITIAL_BLUEPRINT_VALID",result); return true;
}

#endif
