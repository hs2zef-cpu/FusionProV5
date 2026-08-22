#ifndef SW_V5_S5_PRODUCER_TRUST_CONTRACT_MQH
#define SW_V5_S5_PRODUCER_TRUST_CONTRACT_MQH

// SPRINT 5 PHASE B CANDIDATE CONTRACT
// PURE TRUST AUTHORITY VALIDATION / NO WATCHER OR STORE IMPLEMENTATION

#include "SW_V5_S5_IngressContract.mqh"

struct SWV5S5_ProducerTrustAnchor
{
   string issuer_identity;
   string issuer_policy_id;
   string trust_anchor_id;
   string current_authority_record_id;
   ulong current_authority_generation;
};

struct SWV5S5_ProducerTrustScope
{
   SWV5_PersistenceNamespace persistence_namespace;
   string producer_component;
   string producer_instance;
   ulong producer_epoch;
   string symbol;
   int timeframe;
   int execution_mode;
   string publication_clock_id;
   SWV5_TimeAuthority publication_clock_authority;
   string ingress_identity;
};

struct SWV5S5_ProducerTrustRecord
{
   SWV5_ContractVersion contract_version;
   string authority_record_id;
   ulong authority_generation;
   string issuer_identity;
   string issuer_policy_id;
   string producer_component;
   string producer_instance;
   ulong producer_epoch;
   SWV5_PersistenceNamespace persistence_namespace;
   string symbol;
   int timeframe;
   int execution_mode;
   string clock_id;
   SWV5_TimeAuthority clock_authority;
   SWV5S5_ProducerTrustStatus status;
   datetime valid_from;
   datetime valid_until;
   string superseding_record_id;
   ulong superseding_generation;
   string record_digest;
};

struct SWV5S5_ProducerSequenceObservation
{
   ulong highest_accepted_sequence;
   string identity_at_highest_sequence;
   ulong producer_epoch;
   ulong authority_generation;
};

bool SWV5S5_DeriveProducerTrustDigest(const SWV5S5_ProducerTrustRecord &record,string &digest)
{
   string body="",f;
#define SWV5S5_TRUST_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define SWV5S5_TRUST_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define SWV5S5_TRUST_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("version",record.contract_version,f)) return false; body+=f;
   SWV5S5_TRUST_S("authority_record_id",record.authority_record_id);
   SWV5S5_TRUST_U("authority_generation",record.authority_generation);
   SWV5S5_TRUST_S("issuer_identity",record.issuer_identity);
   SWV5S5_TRUST_S("issuer_policy_id",record.issuer_policy_id);
   SWV5S5_TRUST_S("producer_component",record.producer_component);
   SWV5S5_TRUST_S("producer_instance",record.producer_instance);
   SWV5S5_TRUST_U("producer_epoch",record.producer_epoch);
   if(!SWV5S5_CanonicalNamespace("persistence_namespace",record.persistence_namespace,f)) return false; body+=f;
   SWV5S5_TRUST_S("symbol",record.symbol);
   SWV5S5_TRUST_I("timeframe",record.timeframe);
   SWV5S5_TRUST_I("execution_mode",record.execution_mode);
   SWV5S5_TRUST_S("clock_id",record.clock_id);
   SWV5S5_TRUST_I("clock_authority",record.clock_authority);
   SWV5S5_TRUST_I("status",record.status);
   SWV5S5_TRUST_I("valid_from",record.valid_from);
   SWV5S5_TRUST_I("valid_until",record.valid_until);
   SWV5S5_TRUST_S("superseding_record_id",record.superseding_record_id);
   SWV5S5_TRUST_U("superseding_generation",record.superseding_generation);
#undef SWV5S5_TRUST_S
#undef SWV5S5_TRUST_I
#undef SWV5S5_TRUST_U
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_PRODUCER_TRUST,body,digest);
}

bool SWV5S5_ValidateProducerTrust(const SWV5_ContractValidationContext &context,
                                  const SWV5S5_ProducerTrustRecord &record,
                                  const SWV5S5_ProducerTrustAnchor &anchor,
                                  const SWV5S5_ProducerTrustScope &scope,
                                  const SWV5S5_IngressEnvelope &ingress,
                                  SWV5S5_ValidationResult &result)
{
   string expected_digest,expected_ingress,expected_payload;
   if(!SWV5S5_IsCandidateVersion(record.contract_version) || record.authority_record_id=="" ||
      record.record_digest=="" || anchor.current_authority_record_id=="" ||
      record.issuer_identity!=anchor.issuer_identity || record.issuer_policy_id!=anchor.issuer_policy_id ||
      anchor.trust_anchor_id=="" || record.authority_record_id!=anchor.current_authority_record_id ||
      record.authority_generation!=anchor.current_authority_generation ||
      record.status!=SWV5S5_TRUST_AUTHORIZED || record.superseding_record_id!="" || record.superseding_generation!=0 ||
      record.producer_component!=scope.producer_component || record.producer_instance!=scope.producer_instance ||
      record.producer_epoch!=scope.producer_epoch || !SWV5S5_EqualNamespace(record.persistence_namespace,scope.persistence_namespace) ||
      record.symbol!=scope.symbol || record.timeframe!=scope.timeframe || record.execution_mode!=scope.execution_mode ||
      record.clock_id!=scope.publication_clock_id || record.clock_authority!=scope.publication_clock_authority ||
      record.clock_id!=context.clock_id || record.clock_authority!=context.clock_authority ||
      ingress.producer.authority_record_id!=record.authority_record_id ||
      ingress.producer.authority_generation!=record.authority_generation ||
      ingress.producer.producer_component!=record.producer_component ||
      ingress.producer.producer_instance!=record.producer_instance || ingress.producer.producer_epoch!=record.producer_epoch ||
      ingress.snapshot.symbol!=record.symbol || ingress.snapshot.timeframe!=record.timeframe ||
      ingress.snapshot.execution_mode!=record.execution_mode || ingress.publication.clock_id!=record.clock_id ||
      ingress.publication.clock_authority!=record.clock_authority ||
      !SWV5S5_DeriveIngressIdentityAndDigest(ingress,expected_ingress,expected_payload) ||
      ingress.ingress_identity!=expected_ingress || scope.ingress_identity!=expected_ingress ||
      record.valid_from<=0 || record.valid_until<=record.valid_from ||
      context.clock_time<record.valid_from || context.clock_time>=record.valid_until ||
      !SWV5S5_DeriveProducerTrustDigest(record,expected_digest) || record.record_digest!=expected_digest)
   { SWV5S5_Deny(context,"PRODUCER_TRUST_DENIED","",result); return false; }
   SWV5S5_Allow(context,"PRODUCER_TRUST_AUTHORIZED",result); return true;
}

bool SWV5S5_ValidateTrustSuccessor(const SWV5S5_ProducerTrustRecord &prior,
                                  const SWV5S5_ProducerTrustRecord &current,
                                  const SWV5S5_ProducerTrustAnchor &anchor)
{
   return prior.status==SWV5S5_TRUST_SUPERSEDED && prior.superseding_record_id==current.authority_record_id &&
          prior.superseding_generation==current.authority_generation &&
          current.authority_record_id==anchor.current_authority_record_id &&
          current.authority_generation==anchor.current_authority_generation &&
          prior.authority_generation<current.authority_generation &&
          prior.issuer_identity==current.issuer_identity && prior.issuer_policy_id==current.issuer_policy_id &&
          prior.producer_component==current.producer_component &&
          SWV5S5_EqualNamespace(prior.persistence_namespace,current.persistence_namespace) &&
          current.status==SWV5S5_TRUST_AUTHORIZED && current.superseding_record_id=="" &&
          current.superseding_generation==0 && current.producer_epoch>prior.producer_epoch;
}

SWV5S5_IngressEvaluationDisposition SWV5S5_EvaluateProducerSequence(
   const SWV5S5_ProducerSequenceObservation &observed,const ulong epoch,
   const ulong generation,const ulong sequence,const string ingress_identity)
{
   if(epoch==0 || generation==0 || sequence==0 || ingress_identity=="") return SWV5S5_INGRESS_EVALUATION_INVALID;
   // Generation/epoch changes require separately validated authoritative Trust
   // succession. A numerically larger caller value is never self-authorizing.
   if(epoch!=observed.producer_epoch || generation!=observed.authority_generation)
      return SWV5S5_INGRESS_EVALUATION_DENIED;
   if(sequence>observed.highest_accepted_sequence) return SWV5S5_INGRESS_EVALUATION_NEW;
   if(sequence==observed.highest_accepted_sequence)
      return (ingress_identity==observed.identity_at_highest_sequence ?
              SWV5S5_INGRESS_EVALUATION_DUPLICATE : SWV5S5_INGRESS_EVALUATION_CONFLICT);
   return SWV5S5_INGRESS_EVALUATION_DENIED;
}

SWV5S5_TrustContinuityDisposition SWV5S5_TrustMutationDisposition(
   const SWV5S5_AuthorityMutationTiming timing,const bool claim_succeeds,const bool expired_at_claim)
{
   if(expired_at_claim) return SWV5S5_TRUST_CLAIM_TIME_EXPIRED;
   if(timing==SWV5S5_MUTATION_BEFORE_P) return SWV5S5_TRUST_BLOCK_BEFORE_P;
   if(timing==SWV5S5_MUTATION_AFTER_P_BEFORE_CLAIM)
      return claim_succeeds ? SWV5S5_TRUST_CURRENT_RETAINED_LATER_BLOCKED : SWV5S5_TRUST_BLOCK_BEFORE_PERMIT;
   if(timing==SWV5S5_MUTATION_AFTER_CLAIM) return SWV5S5_TRUST_POST_CLAIM_RECONCILE;
   return SWV5S5_TRUST_CONTINUITY_INVALID;
}

class ISWV5S5ProducerTrustContract
{
public:
   virtual bool Validate(const SWV5_ContractValidationContext &context,
                         const SWV5S5_ProducerTrustRecord &record,
                         const SWV5S5_ProducerTrustAnchor &anchor,
                         const SWV5S5_ProducerTrustScope &scope,
                         const SWV5S5_IngressEnvelope &ingress,
                         SWV5S5_ValidationResult &result)=0;
};

#endif
