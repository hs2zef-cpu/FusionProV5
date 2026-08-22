#ifndef SW_V5_S5_ADMISSION_SNAPSHOT_CONTRACT_MQH
#define SW_V5_S5_ADMISSION_SNAPSHOT_CONTRACT_MQH

// SPRINT 5 PHASE B CANDIDATE CONTRACT
// PURE COHERENT AUTHORITY VECTOR / NO PLATFORM QUERIES OR MUTATION SOURCES

#include "SW_V5_S5_SubmissionAuthorityContract.mqh"

struct SWV5S5_StableAuthorityToken
{
   SWV5S5_StableAuthorityKind kind;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   ulong generation;
   ulong revision;
   ulong sequence;
   string identity;
   string digest;
   string clock_id;
   SWV5_TimeAuthority clock_authority;
   datetime observed_at;
   datetime expires_at;
};

struct SWV5S5_AdmissionSnapshot
{
   SWV5_ContractVersion contract_version;
   string canonical_policy_id;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_ExecutionRequestIdentity request_identity;
   SWV5S5_StableAuthorityToken ownership;
   SWV5S5_StableAuthorityToken lease_liveness;
   SWV5S5_StableAuthorityToken producer_trust;
   SWV5S5_StableAuthorityToken hard_kill;
   SWV5S5_StableAuthorityToken account_mode;
   SWV5S5_StableAuthorityToken basket;
   SWV5S5_StableAuthorityToken request_set;
   SWV5S5_StableAuthorityToken symbol_specification;
   SWV5S5_StableAuthorityToken margin;
   SWV5S5_StableAuthorityToken basket_risk;
   SWV5S5_StableAuthorityToken risk_authorization;
   SWV5S5_StableAuthorityToken normalized_payload;
   SWV5S5_StableAuthorityToken submission_permit;
   SWV5S5_StableAuthorityToken validation_clock;
   SWV5S5_StableAuthorityToken policy_format;
   ulong collection_sequence;
   datetime collected_at;
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

bool SWV5S5_DeriveStableTokenDigest(const SWV5S5_StableAuthorityToken &token,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalInt("kind",token.kind,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",token.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",token.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("generation",token.generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("revision",token.revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("sequence",token.sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("identity",token.identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("clock_id",token.clock_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("clock_authority",token.clock_authority,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",token.observed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("expires_at",token.expires_at,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_ADMISSION_SNAPSHOT,body,digest);
}

bool SWV5S5_DeriveAdmissionSnapshotDigest(const SWV5S5_AdmissionSnapshot &snapshot,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",snapshot.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("canonical_policy_id",snapshot.canonical_policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("scope",snapshot.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",snapshot.request_identity,f)) return false; body+=f;
#define SWV5S5_SNAPSHOT_TOKEN(n,m) if(!SWV5S5_CanonicalString(n,snapshot.m.digest,f)) return false; else body+=f
   SWV5S5_SNAPSHOT_TOKEN("ownership",ownership);
   SWV5S5_SNAPSHOT_TOKEN("lease_liveness",lease_liveness);
   SWV5S5_SNAPSHOT_TOKEN("producer_trust",producer_trust);
   SWV5S5_SNAPSHOT_TOKEN("hard_kill",hard_kill);
   SWV5S5_SNAPSHOT_TOKEN("account_mode",account_mode);
   SWV5S5_SNAPSHOT_TOKEN("basket",basket);
   SWV5S5_SNAPSHOT_TOKEN("request_set",request_set);
   SWV5S5_SNAPSHOT_TOKEN("symbol_specification",symbol_specification);
   SWV5S5_SNAPSHOT_TOKEN("margin",margin);
   SWV5S5_SNAPSHOT_TOKEN("basket_risk",basket_risk);
   SWV5S5_SNAPSHOT_TOKEN("risk_authorization",risk_authorization);
   SWV5S5_SNAPSHOT_TOKEN("normalized_payload",normalized_payload);
   SWV5S5_SNAPSHOT_TOKEN("submission_permit",submission_permit);
   SWV5S5_SNAPSHOT_TOKEN("validation_clock",validation_clock);
   SWV5S5_SNAPSHOT_TOKEN("policy_format",policy_format);
#undef SWV5S5_SNAPSHOT_TOKEN
   if(!SWV5S5_CanonicalUInt("collection_sequence",snapshot.collection_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("collected_at",snapshot.collected_at,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_ADMISSION_SNAPSHOT,body,digest);
}

bool SWV5S5_EqualStableToken(const SWV5S5_StableAuthorityToken &a,
                             const SWV5S5_StableAuthorityToken &b)
{
   return a.kind==b.kind && SWV5S5_EqualNamespace(a.persistence_namespace,b.persistence_namespace) &&
          SWV5S5_EqualFence(a.ownership_fence,b.ownership_fence) && a.generation==b.generation &&
          a.revision==b.revision && a.sequence==b.sequence && a.identity==b.identity &&
          a.digest==b.digest && a.clock_id==b.clock_id && a.clock_authority==b.clock_authority &&
          a.observed_at==b.observed_at && a.expires_at==b.expires_at;
}

bool SWV5S5_TokenUsable(const SWV5_ContractValidationContext &context,
                        const SWV5S5_StableAuthorityToken &token,
                        const SWV5S5_StableAuthorityKind expected_kind,
                        const SWV5_PersistenceNamespace &expected_scope,
                        const SWV5_OwnershipFence &expected_fence)
{
   string expected_digest;
   if(token.kind!=expected_kind || token.identity=="" || token.generation==0 || token.sequence==0 ||
      !SWV5S5_DeriveStableTokenDigest(token,expected_digest) || token.digest!=expected_digest ||
      !SWV5S5_EqualNamespace(token.persistence_namespace,expected_scope) ||
      !SWV5S5_EqualFence(token.ownership_fence,expected_fence) ||
      token.clock_id!=context.clock_id ||
      token.clock_authority!=context.clock_authority || token.observed_at<=0 || token.observed_at>context.clock_time)
      return false;
   if(token.expires_at>0 && context.clock_time>=token.expires_at) return false;
   return true;
}

#define SWV5S5_COMPARE_TOKEN(member,label) if(!SWV5S5_EqualStableToken(first.member,second.member)){ result.changed_authority=label; result.disposition=SWV5S5_COLLECT_RETRYABLE_UNSTABLE; result.reason_code="DOUBLE_COLLECT_CHANGED"; return false; }

bool SWV5S5_DoubleCollect(const SWV5_ContractValidationContext &context,
                          const SWV5S5_AdmissionSnapshot &first,
                          const SWV5S5_AdmissionSnapshot &second,
                          SWV5S5_DoubleCollectResult &result)
{
   ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
   string first_digest,second_digest;
   if(!SWV5S5_IsCandidateVersion(first.contract_version) || !SWV5S5_IsCandidateVersion(second.contract_version) ||
      first.canonical_policy_id!=SWV5S5_CANONICAL_POLICY_ID ||
      second.canonical_policy_id!=SWV5S5_CANONICAL_POLICY_ID ||
      !SWV5S5_EqualNamespace(first.persistence_namespace,second.persistence_namespace) ||
      !SWV5S5_EqualRequestIdentity(first.request_identity,second.request_identity) ||
      second.collection_sequence<=first.collection_sequence || second.collected_at<first.collected_at ||
      second.collected_at>context.clock_time ||
      !SWV5S5_DeriveAdmissionSnapshotDigest(first,first_digest) || first.snapshot_digest!=first_digest ||
      !SWV5S5_DeriveAdmissionSnapshotDigest(second,second_digest) || second.snapshot_digest!=second_digest)
   { result.disposition=SWV5S5_COLLECT_FAIL_CLOSED; result.reason_code="COLLECTION_ENVELOPE_INVALID"; return false; }
#define SWV5S5_REQUIRE_TOKEN(member,kind_value) if(!SWV5S5_TokenUsable(context,second.member,kind_value,second.persistence_namespace,second.ownership.ownership_fence)){ result.disposition=SWV5S5_COLLECT_FAIL_CLOSED; result.reason_code="AUTHORITY_TOKEN_INVALID"; result.changed_authority="TOKEN"; return false; }
   SWV5S5_REQUIRE_TOKEN(ownership,SWV5S5_AUTHORITY_OWNERSHIP);
   SWV5S5_REQUIRE_TOKEN(lease_liveness,SWV5S5_AUTHORITY_LEASE_LIVENESS);
   SWV5S5_REQUIRE_TOKEN(producer_trust,SWV5S5_AUTHORITY_PRODUCER_TRUST);
   SWV5S5_REQUIRE_TOKEN(hard_kill,SWV5S5_AUTHORITY_HARD_KILL);
   SWV5S5_REQUIRE_TOKEN(account_mode,SWV5S5_AUTHORITY_ACCOUNT_MODE);
   SWV5S5_REQUIRE_TOKEN(basket,SWV5S5_AUTHORITY_BASKET);
   SWV5S5_REQUIRE_TOKEN(request_set,SWV5S5_AUTHORITY_REQUEST_SET);
   SWV5S5_REQUIRE_TOKEN(symbol_specification,SWV5S5_AUTHORITY_SYMBOL_SPECIFICATION);
   SWV5S5_REQUIRE_TOKEN(margin,SWV5S5_AUTHORITY_MARGIN);
   SWV5S5_REQUIRE_TOKEN(basket_risk,SWV5S5_AUTHORITY_BASKET_RISK);
   SWV5S5_REQUIRE_TOKEN(risk_authorization,SWV5S5_AUTHORITY_RISK_AUTHORIZATION);
   SWV5S5_REQUIRE_TOKEN(normalized_payload,SWV5S5_AUTHORITY_NORMALIZED_PAYLOAD);
   SWV5S5_REQUIRE_TOKEN(submission_permit,SWV5S5_AUTHORITY_SUBMISSION_PERMIT);
   SWV5S5_REQUIRE_TOKEN(validation_clock,SWV5S5_AUTHORITY_VALIDATION_CLOCK);
   SWV5S5_REQUIRE_TOKEN(policy_format,SWV5S5_AUTHORITY_POLICY_FORMAT);
#undef SWV5S5_REQUIRE_TOKEN
   SWV5S5_COMPARE_TOKEN(ownership,"OWNERSHIP");
   SWV5S5_COMPARE_TOKEN(lease_liveness,"LEASE_LIVENESS");
   SWV5S5_COMPARE_TOKEN(producer_trust,"PRODUCER_TRUST");
   SWV5S5_COMPARE_TOKEN(hard_kill,"HARD_KILL");
   SWV5S5_COMPARE_TOKEN(account_mode,"ACCOUNT_MODE");
   SWV5S5_COMPARE_TOKEN(basket,"BASKET");
   SWV5S5_COMPARE_TOKEN(request_set,"REQUEST_SET");
   SWV5S5_COMPARE_TOKEN(symbol_specification,"SYMBOL_SPECIFICATION");
   SWV5S5_COMPARE_TOKEN(margin,"MARGIN");
   SWV5S5_COMPARE_TOKEN(basket_risk,"BASKET_RISK");
   SWV5S5_COMPARE_TOKEN(risk_authorization,"RISK_AUTHORIZATION");
   SWV5S5_COMPARE_TOKEN(normalized_payload,"NORMALIZED_PAYLOAD");
   SWV5S5_COMPARE_TOKEN(submission_permit,"SUBMISSION_PERMIT");
   SWV5S5_COMPARE_TOKEN(validation_clock,"VALIDATION_CLOCK");
   SWV5S5_COMPARE_TOKEN(policy_format,"POLICY_FORMAT");
   result.disposition=SWV5S5_COLLECT_STABLE_PROVISIONAL;
   result.provisional_snapshot_digest=second.snapshot_digest;
   result.reason_code="PROVISIONAL_P_AVAILABLE";
   return true;
}

#undef SWV5S5_COMPARE_TOKEN

#endif
