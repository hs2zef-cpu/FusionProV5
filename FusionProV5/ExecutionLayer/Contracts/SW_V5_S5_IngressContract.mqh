#ifndef SW_V5_S5_INGRESS_CONTRACT_MQH
#define SW_V5_S5_INGRESS_CONTRACT_MQH

// SPRINT 5 PHASE B CANDIDATE CONTRACT
// IMMUTABLE SOURCE PROJECTION / NO SIGNAL POLICY, BROKER, OR STORE ACCESS

#include "SW_V5_S5_Canonical.mqh"

struct SWV5S5_ProducerReference
{
   string authority_record_id;
   string producer_component;
   string producer_instance;
   ulong producer_epoch;
   ulong authority_generation;
};

struct SWV5S5_SnapshotProjection
{
   int snapshot_schema;
   ulong sequence;
   ulong history_generation;
   int execution_mode;
   ulong data_quality_flags;
   string symbol;
   int timeframe;
   datetime closed_bar_time;
};

struct SWV5S5_DecisionProjection
{
   int engine_kind;
   int health;
   bool valid;
   double score;
   double confidence;
   ulong reason_flags;
   ulong snapshot_sequence;
   ulong history_generation;
   string reason_text;
   string validation_error;
   int action;
   int direction;
   string state;
   int blocking_engine;
};

struct SWV5S5_IngressPublication
{
   string clock_id;
   SWV5_TimeAuthority clock_authority;
   datetime publication_time;
   ulong publication_sequence;
};

struct SWV5S5_IngressEnvelope
{
   SWV5_ContractVersion contract_version;
   string canonical_policy_id;
   SWV5S5_ProducerReference producer;
   SWV5S5_SnapshotProjection snapshot;
   SWV5S5_DecisionProjection decision;
   SWV5S5_IngressPublication publication;
   string ingress_identity;
   string payload_digest;
};

struct SWV5S5_IngressFreshnessPolicy
{
   string policy_id;
   string clock_id;
   SWV5_TimeAuthority clock_authority;
   long max_age_seconds;
   long max_future_skew_seconds;
};

struct SWV5S5_IngressValidationResult
{
   SWV5S5_ValidationResult validation;
   SWV5S5_IngressEvaluationDisposition disposition;
   bool directional_nomination;
   bool no_entry;
};

bool SWV5S5_CanonicalIngressSource(const SWV5S5_IngressEnvelope &ingress,string &body)
{
   string f; body="";
#define SWV5S5_ADD_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define SWV5S5_ADD_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define SWV5S5_ADD_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define SWV5S5_ADD_B(n,v) if(!SWV5S5_CanonicalBool(n,v,f)) return false; else body+=f
#define SWV5S5_ADD_D(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("contract_version",ingress.contract_version,f)) return false; body+=f;
   SWV5S5_ADD_S("canonical_policy_id",ingress.canonical_policy_id);
   SWV5S5_ADD_S("authority_record_id",ingress.producer.authority_record_id);
   SWV5S5_ADD_S("producer_component",ingress.producer.producer_component);
   SWV5S5_ADD_S("producer_instance",ingress.producer.producer_instance);
   SWV5S5_ADD_U("producer_epoch",ingress.producer.producer_epoch);
   SWV5S5_ADD_U("authority_generation",ingress.producer.authority_generation);
   SWV5S5_ADD_I("snapshot_schema",ingress.snapshot.snapshot_schema);
   SWV5S5_ADD_U("snapshot_sequence",ingress.snapshot.sequence);
   SWV5S5_ADD_U("history_generation",ingress.snapshot.history_generation);
   SWV5S5_ADD_I("execution_mode",ingress.snapshot.execution_mode);
   SWV5S5_ADD_U("data_quality_flags",ingress.snapshot.data_quality_flags);
   SWV5S5_ADD_S("symbol",ingress.snapshot.symbol);
   SWV5S5_ADD_I("timeframe",ingress.snapshot.timeframe);
   SWV5S5_ADD_I("closed_bar_time",ingress.snapshot.closed_bar_time);
   SWV5S5_ADD_I("engine_kind",ingress.decision.engine_kind);
   SWV5S5_ADD_I("health",ingress.decision.health);
   SWV5S5_ADD_B("valid",ingress.decision.valid);
   SWV5S5_ADD_D("score",ingress.decision.score);
   SWV5S5_ADD_D("confidence",ingress.decision.confidence);
   SWV5S5_ADD_U("reason_flags",ingress.decision.reason_flags);
   SWV5S5_ADD_U("decision_snapshot_sequence",ingress.decision.snapshot_sequence);
   SWV5S5_ADD_U("decision_history_generation",ingress.decision.history_generation);
   SWV5S5_ADD_S("reason_text",ingress.decision.reason_text);
   SWV5S5_ADD_S("validation_error",ingress.decision.validation_error);
   SWV5S5_ADD_I("action",ingress.decision.action);
   SWV5S5_ADD_I("direction",ingress.decision.direction);
   SWV5S5_ADD_S("state",ingress.decision.state);
   SWV5S5_ADD_I("blocking_engine",ingress.decision.blocking_engine);
   SWV5S5_ADD_S("clock_id",ingress.publication.clock_id);
   SWV5S5_ADD_I("clock_authority",ingress.publication.clock_authority);
   SWV5S5_ADD_I("publication_time",ingress.publication.publication_time);
   SWV5S5_ADD_U("publication_sequence",ingress.publication.publication_sequence);
#undef SWV5S5_ADD_S
#undef SWV5S5_ADD_I
#undef SWV5S5_ADD_U
#undef SWV5S5_ADD_B
#undef SWV5S5_ADD_D
   return true;
}

bool SWV5S5_DeriveIngressIdentityAndDigest(const SWV5S5_IngressEnvelope &ingress,
                                           string &identity,string &digest)
{
   string body,identity_field;
   if(!SWV5S5_CanonicalIngressSource(ingress,body) ||
      !SWV5S5_DomainDigest(SWV5S5_DOMAIN_INGRESS_ID,body,identity) ||
      !SWV5S5_CanonicalString("ingress_identity",identity,identity_field)) return false;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INGRESS_PAYLOAD,body+identity_field,digest);
}

bool SWV5S5_IsIngressFresh(const SWV5_ContractValidationContext &context,
                           const SWV5S5_IngressPublication &publication,
                           const SWV5S5_IngressFreshnessPolicy &policy,string &reason)
{
   reason="";
   if(!SWV5S5_IsValidationContextUsable(context) || policy.policy_id!=SWV5S5_POLICY_ID ||
      policy.max_age_seconds<=0 || policy.max_future_skew_seconds<0)
   { reason="FRESHNESS_POLICY_INVALID"; return false; }
   if(publication.clock_id!=policy.clock_id || publication.clock_id!=context.clock_id ||
      publication.clock_authority!=policy.clock_authority ||
      publication.clock_authority!=context.clock_authority)
   { reason="CLOCK_SCOPE_MISMATCH"; return false; }
   if(publication.publication_time<=0 || publication.publication_sequence==0)
   { reason="PUBLICATION_AUTHORITY_INVALID"; return false; }
   if(publication.publication_time>context.clock_time)
   {
      long future=(long)publication.publication_time-(long)context.clock_time;
      if(future>policy.max_future_skew_seconds) { reason="INGRESS_FROM_FUTURE"; return false; }
   }
   else
   {
      long age=(long)context.clock_time-(long)publication.publication_time;
      if(age>=policy.max_age_seconds) { reason="INGRESS_EXPIRED"; return false; }
   }
   return true;
}

bool SWV5S5_ValidateIngress(const SWV5_ContractValidationContext &context,
                            const SWV5S5_IngressEnvelope &ingress,
                            const SWV5S5_IngressFreshnessPolicy &freshness,
                            SWV5S5_IngressValidationResult &result)
{
   ZeroMemory(result); string reason;
   if(!SWV5S5_IsCandidateVersion(ingress.contract_version) ||
      ingress.canonical_policy_id!=SWV5S5_CANONICAL_POLICY_ID)
   { SWV5S5_Deny(context,"INGRESS_VERSION_INVALID","",result.validation); return false; }
   if(ingress.producer.authority_record_id=="" || ingress.producer.producer_component=="" ||
      ingress.producer.producer_instance=="" || ingress.producer.producer_epoch==0 ||
      ingress.producer.authority_generation==0 || ingress.snapshot.snapshot_schema!=5 ||
      ingress.snapshot.sequence==0 || ingress.snapshot.history_generation==0 ||
      ingress.snapshot.execution_mode<0 || ingress.snapshot.execution_mode>2 ||
      ingress.snapshot.symbol=="" || ingress.snapshot.timeframe<=0 || ingress.snapshot.closed_bar_time<=0 ||
      ingress.decision.engine_kind!=9 || ingress.decision.health<0 || ingress.decision.health>3 ||
      !ingress.decision.valid || !SWV5_IsFiniteNumber(ingress.decision.score) ||
      !SWV5_IsFiniteNumber(ingress.decision.confidence) || ingress.decision.confidence<0.0 ||
      ingress.decision.confidence>1.0 || ingress.decision.state=="" ||
      ingress.decision.blocking_engine<0 || ingress.decision.blocking_engine>10 ||
      ingress.publication.publication_sequence==0)
   { SWV5S5_Deny(context,"INGRESS_SOURCE_INVALID","",result.validation); return false; }
   if(ingress.snapshot.sequence!=ingress.decision.snapshot_sequence ||
      ingress.snapshot.history_generation!=ingress.decision.history_generation)
   { SWV5S5_Deny(context,"SOURCE_BINDING_MISMATCH","",result.validation); return false; }
   bool directional=(ingress.decision.action==1 || ingress.decision.action==-1);
   bool no_entry=(ingress.decision.action==0 || ingress.decision.action==9);
   if((directional && ingress.decision.direction!=ingress.decision.action) ||
      (no_entry && ingress.decision.direction!=0) || (!directional && !no_entry))
   { SWV5S5_Deny(context,"ACTION_DIRECTION_CONTRADICTION","",result.validation); return false; }
   if(!SWV5S5_IsIngressFresh(context,ingress.publication,freshness,reason))
   { SWV5S5_Deny(context,reason,"",result.validation); return false; }
   string identity,digest;
   if(!SWV5S5_DeriveIngressIdentityAndDigest(ingress,identity,digest) ||
      identity!=ingress.ingress_identity || digest!=ingress.payload_digest)
   { SWV5S5_Deny(context,"INGRESS_INTEGRITY_FAILURE","",result.validation); return false; }
   SWV5S5_Allow(context,no_entry ? "VALID_NO_ENTRY" : "VALID_DIRECTIONAL_NOMINATION",result.validation);
   result.disposition=SWV5S5_INGRESS_EVALUATION_NEW;
   result.directional_nomination=directional; result.no_entry=no_entry;
   return true;
}

#endif
