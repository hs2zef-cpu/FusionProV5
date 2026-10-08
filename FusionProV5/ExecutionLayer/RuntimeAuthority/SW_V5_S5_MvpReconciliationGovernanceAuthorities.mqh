#ifndef SW_V5_S5_MVP_RECONCILIATION_GOVERNANCE_AUTHORITIES_MQH
#define SW_V5_S5_MVP_RECONCILIATION_GOVERNANCE_AUTHORITIES_MQH

// MVP RUNTIME AUTHORITY — OPERATOR-GOVERNED PHASE-F CONTEXT AND ATTEMPT PIN.
// Frozen Phase-F DTOs are stored losslessly; the Broker Adapter cannot provision.

#include "SW_V5_S5_MvpAuthorityRecordCodec.mqh"

const string SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE="MVP_RECONCILIATION_GOVERNANCE_BUNDLE";
const string SWV5S5_MVP_RECONCILIATION_GOVERNANCE_KEY="CURRENT";
const string SWV5S5_MVP_DOMAIN_RECONCILIATION_PIN="MVP_ATTEMPT_RECONCILIATION_PIN";
const string SWV5S5_MVP_GOVERNANCE_DIGEST_DOMAIN="SWV5-S5-MVP-RECONCILIATION-GOVERNANCE-V1";
const string SWV5S5_MVP_PIN_DIGEST_DOMAIN="SWV5-S5-MVP-ATTEMPT-RECONCILIATION-PIN-V1";

bool SWV5S5_MvpEncodeFProfile(const SWV5S5_F_ProfileScope &v,string &body)
{
   body=""; string f,nested;
   if(!SWV5S5_MvpCodecEncode_SWV5_ContractVersion(v.contract_version,nested) || !SWV5S5_CanonicalNested("version",nested,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_PersistenceNamespace(v.persistence_namespace,nested) || !SWV5S5_CanonicalNested("namespace",nested,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_AccountRiskNamespace(v.account_namespace,nested) || !SWV5S5_CanonicalNested("account",nested,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("broker",v.broker_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("server",v.server,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("login",v.account_login,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("symbol",v.symbol,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("terminal_build",v.terminal_build,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("mql_build",v.mql_build,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("profile_id",v.profile_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("profile_digest",v.profile_digest,f)) return false; body+=f; return true;
}

bool SWV5S5_MvpDecodeFProfile(const string body,SWV5S5_F_ProfileScope &v)
{
   ZeroMemory(v); SWV5S5_MvpCodecReader r; r.Init(body); string n; long x=0;
   if(!r.ReadNested("version",n) || !SWV5S5_MvpCodecDecode_SWV5_ContractVersion(n,v.contract_version)) return false;
   if(!r.ReadNested("namespace",n) || !SWV5S5_MvpCodecDecode_SWV5_PersistenceNamespace(n,v.persistence_namespace)) return false;
   if(!r.ReadNested("account",n) || !SWV5S5_MvpCodecDecode_SWV5_AccountRiskNamespace(n,v.account_namespace)) return false;
   if(!r.ReadString("broker",v.broker_identity) || !r.ReadString("server",v.server) || !r.ReadInteger("login",v.account_login) ||
      !r.ReadString("symbol",v.symbol) || !r.ReadInteger("terminal_build",x)) return false; v.terminal_build=(int)x;
   if(!r.ReadInteger("mql_build",x)) return false; v.mql_build=(int)x;
   return r.ReadString("profile_id",v.profile_id) && r.ReadString("profile_digest",v.profile_digest) && r.AtEnd();
}

bool SWV5S5_MvpEncodeFCorrelation(const SWV5S5_F_CorrelationPolicy &v,string &body)
{
   body=""; string f,n;
   if(!SWV5S5_MvpCodecEncode_SWV5_ContractVersion(v.contract_version,n) || !SWV5S5_CanonicalNested("version",n,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("policy_id",v.policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("policy_version",v.policy_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("profile_id",v.broker_profile_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("profile_digest",v.broker_profile_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("issuing_component",v.issuing_component,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("authority_source",v.authority_source,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("approval_reference",v.approval_reference,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("approved_at",v.approved_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("order_identity",v.broker_order_identity_required,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("deal_order",v.deal_order_link_required,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("position_link",v.position_identifier_link_required,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("ordered_deals",v.ordered_deal_set_required,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("magic_scope",v.magic_is_strategy_scope_only,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("comment_non_authoritative",v.comment_is_non_authoritative,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("digest",v.policy_digest,f)) return false; body+=f; return true;
}

bool SWV5S5_MvpDecodeFCorrelation(const string body,SWV5S5_F_CorrelationPolicy &v)
{
   ZeroMemory(v); SWV5S5_MvpCodecReader r; r.Init(body); string n; long x=0,approved=0;
   if(!r.ReadNested("version",n) || !SWV5S5_MvpCodecDecode_SWV5_ContractVersion(n,v.contract_version) ||
      !r.ReadString("policy_id",v.policy_id) || !r.ReadUnsigned("policy_version",v.policy_version) ||
      !r.ReadString("profile_id",v.broker_profile_id) || !r.ReadString("profile_digest",v.broker_profile_digest) ||
      !r.ReadInteger("issuing_component",x)) return false; v.issuing_component=(SWV5_ComponentAuthority)x;
   if(!r.ReadInteger("authority_source",x)) return false; v.authority_source=(SWV5_AuthoritySource)x;
   if(!r.ReadString("approval_reference",v.approval_reference) || !r.ReadInteger("approved_at",approved)) return false; v.approved_at=(datetime)approved;
   return r.ReadBool("order_identity",v.broker_order_identity_required) && r.ReadBool("deal_order",v.deal_order_link_required) &&
      r.ReadBool("position_link",v.position_identifier_link_required) && r.ReadBool("ordered_deals",v.ordered_deal_set_required) &&
      r.ReadBool("magic_scope",v.magic_is_strategy_scope_only) && r.ReadBool("comment_non_authoritative",v.comment_is_non_authoritative) &&
      r.ReadString("digest",v.policy_digest) && r.AtEnd();
}

bool SWV5S5_MvpEncodeFCapability(const SWV5S5_F_CapabilityProof &v,string &body)
{
   body=""; string f,n;
   if(!SWV5S5_MvpCodecEncode_SWV5_ContractVersion(v.contract_version,n) || !SWV5S5_CanonicalNested("version",n,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("artifact_id",v.artifact_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("artifact_version",v.artifact_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("profile_id",v.broker_profile_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("profile_digest",v.broker_profile_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("issuing_component",v.issuing_component,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("authority_source",v.authority_source,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("proof_source_reference",v.proof_source_reference,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("approval_reference",v.approval_reference,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("approved_at",v.approved_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("valid_from",v.valid_from,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("valid_until",v.valid_until,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("correlation",v.correlation_capability_proven,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("query_complete",v.query_completeness_capability_proven,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("visibility",v.visibility_watermark_proven,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("visibility_lag",v.proven_visibility_lag_seconds,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("digest",v.proof_digest,f)) return false; body+=f; return true;
}

bool SWV5S5_MvpDecodeFCapability(const string body,SWV5S5_F_CapabilityProof &v)
{
   ZeroMemory(v); SWV5S5_MvpCodecReader r; r.Init(body); string n; long x=0,t=0;
   if(!r.ReadNested("version",n) || !SWV5S5_MvpCodecDecode_SWV5_ContractVersion(n,v.contract_version) ||
      !r.ReadString("artifact_id",v.artifact_id) || !r.ReadUnsigned("artifact_version",v.artifact_version) ||
      !r.ReadString("profile_id",v.broker_profile_id) || !r.ReadString("profile_digest",v.broker_profile_digest) ||
      !r.ReadInteger("issuing_component",x)) return false; v.issuing_component=(SWV5_ComponentAuthority)x;
   if(!r.ReadInteger("authority_source",x)) return false; v.authority_source=(SWV5_AuthoritySource)x;
   if(!r.ReadString("proof_source_reference",v.proof_source_reference) || !r.ReadString("approval_reference",v.approval_reference) ||
      !r.ReadInteger("approved_at",t)) return false; v.approved_at=(datetime)t;
   if(!r.ReadInteger("valid_from",t)) return false; v.valid_from=(datetime)t;
   if(!r.ReadInteger("valid_until",t)) return false; v.valid_until=(datetime)t;
   return r.ReadBool("correlation",v.correlation_capability_proven) &&
      r.ReadBool("query_complete",v.query_completeness_capability_proven) &&
      r.ReadBool("visibility",v.visibility_watermark_proven) &&
      r.ReadUnsigned("visibility_lag",v.proven_visibility_lag_seconds) &&
      r.ReadString("digest",v.proof_digest) && r.AtEnd();
}

bool SWV5S5_MvpEncodeFNegativePolicy(const SWV5S5_F_NegativeEvidencePolicy &v,string &body)
{
   body=""; string f,n;
   if(!SWV5S5_MvpCodecEncode_SWV5_ContractVersion(v.contract_version,n) || !SWV5S5_CanonicalNested("version",n,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("policy_id",v.policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("policy_version",v.policy_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("profile_id",v.broker_profile_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("profile_digest",v.broker_profile_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("issuing_component",v.issuing_component,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("authority_source",v.authority_source,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("approval_reference",v.approval_reference,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("approved_at",v.approved_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("capability_id",v.capability_proof_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("capability_version",v.capability_proof_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("capability_digest",v.capability_proof_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("broker_flags",v.required_broker_flags,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("execution_flags",v.required_execution_flags,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("stable_observations",v.minimum_stable_observations,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("stability_seconds",v.minimum_stability_seconds,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("visibility_lag",v.proven_visibility_lag_seconds,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("connection_generation",v.required_connection_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("restart_generation",v.required_restart_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("digest",v.policy_digest,f)) return false; body+=f; return true;
}

bool SWV5S5_MvpDecodeFNegativePolicy(const string body,SWV5S5_F_NegativeEvidencePolicy &v)
{
   ZeroMemory(v); SWV5S5_MvpCodecReader r; r.Init(body); string n; long x=0,t=0;
   if(!r.ReadNested("version",n) || !SWV5S5_MvpCodecDecode_SWV5_ContractVersion(n,v.contract_version) ||
      !r.ReadString("policy_id",v.policy_id) || !r.ReadUnsigned("policy_version",v.policy_version) ||
      !r.ReadString("profile_id",v.broker_profile_id) || !r.ReadString("profile_digest",v.broker_profile_digest) ||
      !r.ReadInteger("issuing_component",x)) return false; v.issuing_component=(SWV5_ComponentAuthority)x;
   if(!r.ReadInteger("authority_source",x)) return false; v.authority_source=(SWV5_AuthoritySource)x;
   if(!r.ReadString("approval_reference",v.approval_reference) || !r.ReadInteger("approved_at",t)) return false; v.approved_at=(datetime)t;
   return r.ReadString("capability_id",v.capability_proof_id) && r.ReadUnsigned("capability_version",v.capability_proof_version) &&
      r.ReadString("capability_digest",v.capability_proof_digest) && r.ReadUnsigned("broker_flags",v.required_broker_flags) &&
      r.ReadUnsigned("execution_flags",v.required_execution_flags) && r.ReadUnsigned("stable_observations",v.minimum_stable_observations) &&
      r.ReadUnsigned("stability_seconds",v.minimum_stability_seconds) && r.ReadUnsigned("visibility_lag",v.proven_visibility_lag_seconds) &&
      r.ReadUnsigned("connection_generation",v.required_connection_generation) && r.ReadUnsigned("restart_generation",v.required_restart_generation) &&
      r.ReadString("digest",v.policy_digest) && r.AtEnd();
}

struct SWV5S5_MvpReconciliationGovernanceBundle
{
   SWV5_ContractVersion contract_version;
   SWV5S5_F_ProfileScope profile;
   SWV5S5_F_CorrelationPolicy correlation_policy;
   SWV5S5_F_CapabilityProof capability_proof;
   SWV5S5_F_NegativeEvidencePolicy negative_policy;
   SWV5_OperatorIdentity operator_identity;
   datetime valid_from;
   datetime valid_until;
   ulong authority_sequence;
   string bundle_id;
   string bundle_digest;
};

bool SWV5S5_MvpGovernanceCanonical(const SWV5S5_MvpReconciliationGovernanceBundle &b,const bool include_digest,string &body)
{
   body=""; string f,n;
   if(!SWV5S5_MvpCodecEncode_SWV5_ContractVersion(b.contract_version,n) || !SWV5S5_CanonicalNested("version",n,f)) return false; body+=f;
   if(!SWV5S5_MvpEncodeFProfile(b.profile,n) || !SWV5S5_CanonicalNested("profile",n,f)) return false; body+=f;
   if(!SWV5S5_MvpEncodeFCorrelation(b.correlation_policy,n) || !SWV5S5_CanonicalNested("correlation",n,f)) return false; body+=f;
   if(!SWV5S5_MvpEncodeFCapability(b.capability_proof,n) || !SWV5S5_CanonicalNested("capability",n,f)) return false; body+=f;
   if(!SWV5S5_MvpEncodeFNegativePolicy(b.negative_policy,n) || !SWV5S5_CanonicalNested("negative",n,f)) return false; body+=f;
   if(!SWV5S5_CanonicalOperatorIdentity("operator",b.operator_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("valid_from",b.valid_from,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("valid_until",b.valid_until,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("sequence",b.authority_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("bundle_id",b.bundle_id,f)) return false; body+=f;
   if(include_digest){ if(!SWV5S5_CanonicalString("bundle_digest",b.bundle_digest,f)) return false; body+=f; }
   return true;
}

bool SWV5S5_MvpGovernanceDigest(const SWV5S5_MvpReconciliationGovernanceBundle &b,string &digest)
{ string body; return SWV5S5_MvpGovernanceCanonical(b,false,body) && SWV5S5_DomainDigest(SWV5S5_MVP_GOVERNANCE_DIGEST_DOMAIN,body,digest); }

bool SWV5S5_MvpDecodeGovernance(const string payload,SWV5S5_MvpReconciliationGovernanceBundle &b)
{
   ZeroMemory(b); SWV5S5_MvpCodecReader r; r.Init(payload); string n; long t=0;
   if(!r.ReadNested("version",n) || !SWV5S5_MvpCodecDecode_SWV5_ContractVersion(n,b.contract_version)) return false;
   if(!r.ReadNested("profile",n) || !SWV5S5_MvpDecodeFProfile(n,b.profile)) return false;
   if(!r.ReadNested("correlation",n) || !SWV5S5_MvpDecodeFCorrelation(n,b.correlation_policy)) return false;
   if(!r.ReadNested("capability",n) || !SWV5S5_MvpDecodeFCapability(n,b.capability_proof)) return false;
   if(!r.ReadNested("negative",n) || !SWV5S5_MvpDecodeFNegativePolicy(n,b.negative_policy)) return false;
   if(!r.ReadNested("operator",n) || !SWV5S5_MvpCodecDecode_SWV5_OperatorIdentity(n,b.operator_identity)) return false;
   if(!r.ReadInteger("valid_from",t)) return false; b.valid_from=(datetime)t;
   if(!r.ReadInteger("valid_until",t)) return false; b.valid_until=(datetime)t;
   if(!r.ReadUnsigned("sequence",b.authority_sequence) || !r.ReadString("bundle_id",b.bundle_id) ||
      !r.ReadString("bundle_digest",b.bundle_digest) || !r.AtEnd()) return false;
   string d; return SWV5S5_MvpGovernanceDigest(b,d) && d==b.bundle_digest;
}

bool SWV5S5_MvpGovernanceValid(const SWV5S5_MvpReconciliationGovernanceBundle &b,const datetime now)
{
   string profile_digest,correlation_digest,capability_digest,negative_digest,bundle_digest;
   return SWV5S5_F_IsVersion(b.profile.contract_version) && SWV5S5_F_IsProfileValid(b.profile) &&
      SWV5S5_F_DeriveProfileDigest(b.profile,profile_digest) && profile_digest==b.profile.profile_digest &&
      b.operator_identity.operator_id!="" && b.operator_identity.authority_role!="" &&
      b.operator_identity.authentication_reference!="" && b.operator_identity.authenticated_at>0 &&
      b.valid_from>0 && b.valid_from<=now && b.valid_until>now && b.authority_sequence>0 && b.bundle_id!="" &&
      b.correlation_policy.policy_id==SWV5S5_F_CORRELATION_POLICY_ID && b.correlation_policy.policy_version==1 &&
      b.correlation_policy.issuing_component==SWV5_COMPONENT_AUTHORITY_OPERATOR &&
      b.correlation_policy.authority_source==SWV5_AUTHORITY_OPERATOR &&
      b.correlation_policy.broker_order_identity_required && b.correlation_policy.deal_order_link_required &&
      b.correlation_policy.position_identifier_link_required && b.correlation_policy.ordered_deal_set_required &&
      b.correlation_policy.magic_is_strategy_scope_only && b.correlation_policy.comment_is_non_authoritative &&
      SWV5S5_F_DeriveCorrelationPolicyDigest(b.correlation_policy,correlation_digest) && correlation_digest==b.correlation_policy.policy_digest &&
      b.capability_proof.artifact_id==SWV5S5_F_CAPABILITY_PROOF_ID && b.capability_proof.artifact_version>0 &&
      b.capability_proof.issuing_component==SWV5_COMPONENT_AUTHORITY_OPERATOR &&
      b.capability_proof.authority_source==SWV5_AUTHORITY_OPERATOR && b.capability_proof.proof_source_reference!="" &&
      b.capability_proof.approval_reference!="" && b.capability_proof.correlation_capability_proven &&
      !b.capability_proof.query_completeness_capability_proven && !b.capability_proof.visibility_watermark_proven &&
      b.capability_proof.proven_visibility_lag_seconds==0 &&
      SWV5S5_F_DeriveCapabilityProofDigest(b.capability_proof,capability_digest) && capability_digest==b.capability_proof.proof_digest &&
      b.negative_policy.policy_id==SWV5S5_F_NEGATIVE_POLICY_ID && b.negative_policy.policy_version==1 &&
      b.negative_policy.issuing_component==SWV5_COMPONENT_AUTHORITY_OPERATOR && b.negative_policy.authority_source==SWV5_AUTHORITY_OPERATOR &&
      SWV5S5_F_DeriveNegativePolicyDigest(b.negative_policy,negative_digest) && negative_digest==b.negative_policy.policy_digest &&
      b.correlation_policy.broker_profile_id==b.profile.profile_id && b.correlation_policy.broker_profile_digest==profile_digest &&
      b.capability_proof.broker_profile_id==b.profile.profile_id && b.capability_proof.broker_profile_digest==profile_digest &&
      b.negative_policy.broker_profile_id==b.profile.profile_id && b.negative_policy.broker_profile_digest==profile_digest &&
      b.negative_policy.capability_proof_digest==capability_digest &&
      SWV5S5_MvpGovernanceDigest(b,bundle_digest) && bundle_digest==b.bundle_digest;
}

class SWV5S5_MvpReconciliationGovernanceAuthority
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
public:
   bool Configure(const string path,const string namespace_digest){ return m_store.Open(path,namespace_digest); }
   bool ConfigureReadOnly(const string path,const string namespace_digest){ return m_store.OpenReadOnly(path,namespace_digest); }
   bool Provision(const SWV5S5_MvpOperatorInvocation &op,const SWV5S5_F_ProfileScope &profile,
                  const string approval_reference,const string proof_source_reference,
                  const datetime valid_until,const ulong authority_sequence,
                  SWV5S5_MvpReconciliationGovernanceBundle &bundle,SWV5S5_MvpAuthorityRow &committed)
   {
      ZeroMemory(bundle); if(!SWV5S5_MvpOperatorInvocationValid(op,op.authenticated_at) || approval_reference=="" ||
         proof_source_reference=="" || valid_until<=op.authenticated_at || authority_sequence==0 ||
         !SWV5S5_F_IsProfileValid(profile)) return false;
      SWV5S5_MvpInitProductionVersion(bundle.contract_version); bundle.profile=profile;
      bundle.operator_identity.operator_id=op.operator_id; bundle.operator_identity.authority_role=op.authority_role;
      bundle.operator_identity.authentication_reference=op.authentication_reference; bundle.operator_identity.authenticated_at=op.authenticated_at;
      bundle.valid_from=op.authenticated_at; bundle.valid_until=valid_until; bundle.authority_sequence=authority_sequence;
      SWV5S5_F_InitVersion(bundle.correlation_policy.contract_version);
      bundle.correlation_policy.policy_id=SWV5S5_F_CORRELATION_POLICY_ID; bundle.correlation_policy.policy_version=1;
      bundle.correlation_policy.broker_profile_id=profile.profile_id; bundle.correlation_policy.broker_profile_digest=profile.profile_digest;
      bundle.correlation_policy.issuing_component=SWV5_COMPONENT_AUTHORITY_OPERATOR;
      bundle.correlation_policy.authority_source=SWV5_AUTHORITY_OPERATOR;
      bundle.correlation_policy.approval_reference=approval_reference; bundle.correlation_policy.approved_at=op.authenticated_at;
      bundle.correlation_policy.broker_order_identity_required=true; bundle.correlation_policy.deal_order_link_required=true;
      bundle.correlation_policy.position_identifier_link_required=true; bundle.correlation_policy.ordered_deal_set_required=true;
      bundle.correlation_policy.magic_is_strategy_scope_only=true; bundle.correlation_policy.comment_is_non_authoritative=true;
      if(!SWV5S5_F_DeriveCorrelationPolicyDigest(bundle.correlation_policy,bundle.correlation_policy.policy_digest)) return false;
      SWV5S5_F_InitVersion(bundle.capability_proof.contract_version);
      bundle.capability_proof.artifact_id=SWV5S5_F_CAPABILITY_PROOF_ID; bundle.capability_proof.artifact_version=1;
      bundle.capability_proof.broker_profile_id=profile.profile_id; bundle.capability_proof.broker_profile_digest=profile.profile_digest;
      bundle.capability_proof.issuing_component=SWV5_COMPONENT_AUTHORITY_OPERATOR;
      bundle.capability_proof.authority_source=SWV5_AUTHORITY_OPERATOR;
      bundle.capability_proof.proof_source_reference=proof_source_reference;
      bundle.capability_proof.approval_reference=approval_reference; bundle.capability_proof.approved_at=op.authenticated_at;
      bundle.capability_proof.valid_from=op.authenticated_at; bundle.capability_proof.valid_until=valid_until;
      bundle.capability_proof.correlation_capability_proven=true;
      bundle.capability_proof.query_completeness_capability_proven=false;
      bundle.capability_proof.visibility_watermark_proven=false; bundle.capability_proof.proven_visibility_lag_seconds=0;
      if(!SWV5S5_F_DeriveCapabilityProofDigest(bundle.capability_proof,bundle.capability_proof.proof_digest)) return false;
      SWV5S5_F_InitVersion(bundle.negative_policy.contract_version);
      bundle.negative_policy.policy_id=SWV5S5_F_NEGATIVE_POLICY_ID; bundle.negative_policy.policy_version=1;
      bundle.negative_policy.broker_profile_id=profile.profile_id; bundle.negative_policy.broker_profile_digest=profile.profile_digest;
      bundle.negative_policy.issuing_component=SWV5_COMPONENT_AUTHORITY_OPERATOR; bundle.negative_policy.authority_source=SWV5_AUTHORITY_OPERATOR;
      bundle.negative_policy.approval_reference=approval_reference; bundle.negative_policy.approved_at=op.authenticated_at;
      bundle.negative_policy.capability_proof_id=bundle.capability_proof.artifact_id;
      bundle.negative_policy.capability_proof_version=bundle.capability_proof.artifact_version;
      bundle.negative_policy.capability_proof_digest=bundle.capability_proof.proof_digest;
      bundle.negative_policy.required_broker_flags=SWV5_QUERY_POSITIONS|SWV5_QUERY_ORDERS|SWV5_QUERY_DEALS|SWV5_QUERY_TRANSACTIONS;
      bundle.negative_policy.required_execution_flags=SWV5_QUERY_PENDING_REQUESTS;
      bundle.negative_policy.minimum_stable_observations=2; bundle.negative_policy.minimum_stability_seconds=1;
      bundle.negative_policy.proven_visibility_lag_seconds=0; bundle.negative_policy.required_connection_generation=1;
      bundle.negative_policy.required_restart_generation=1;
      if(!SWV5S5_F_DeriveNegativePolicyDigest(bundle.negative_policy,bundle.negative_policy.policy_digest)) return false;
      string identity_body="",f,identity_digest;
      if(!SWV5S5_CanonicalString("profile",profile.profile_digest,f)) return false; identity_body+=f;
      if(!SWV5S5_CanonicalString("approval",approval_reference,f)) return false; identity_body+=f;
      if(!SWV5S5_CanonicalUInt("sequence",authority_sequence,f)) return false; identity_body+=f;
      if(!SWV5S5_DomainDigest(SWV5S5_MVP_GOVERNANCE_DIGEST_DOMAIN+"-ID",identity_body,identity_digest)) return false;
      bundle.bundle_id="MVP-RECONCILIATION-GOVERNANCE-"+identity_digest;
      if(!SWV5S5_MvpGovernanceDigest(bundle,bundle.bundle_digest) || !SWV5S5_MvpGovernanceValid(bundle,op.authenticated_at)) return false;
      string payload; if(!SWV5S5_MvpGovernanceCanonical(bundle,true,payload)) return false;
      SWV5S5_MvpAuthorityRow current; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE,SWV5S5_MVP_RECONCILIATION_GOVERNANCE_KEY,current,found) || found) return false;
      return m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE,SWV5S5_MVP_RECONCILIATION_GOVERNANCE_KEY,
         0,"","",0,1,1,bundle.bundle_digest,payload,op.authenticated_at,committed);
   }

   bool Load(const datetime now,const SWV5S5_F_ProfileScope &expected,SWV5S5_MvpReconciliationGovernanceBundle &bundle,
             SWV5S5_MvpAuthorityRow &row,bool &found)
   {
      ZeroMemory(bundle); found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE,SWV5S5_MVP_RECONCILIATION_GOVERNANCE_KEY,row,found) || !found) return !found;
      return SWV5S5_MvpDecodeGovernance(row.payload,bundle) && row.payload_digest==bundle.bundle_digest &&
         SWV5S5_MvpGovernanceValid(bundle,now) && SWV5S5_F_EqualProfile(bundle.profile,expected);
   }
};

struct SWV5S5_MvpAttemptReconciliationPin
{
   SWV5_ContractVersion contract_version;
   SWV5_ExecutionRequestIdentity request_identity;
   string permit_id;
   string permit_digest;
   string admission_snapshot_digest;
   string expected_claim_id;
   string broker_profile_id;
   string broker_profile_digest;
   string correlation_policy_id;
   uint correlation_policy_version;
   string correlation_policy_digest;
   string negative_policy_id;
   uint negative_policy_version;
   string negative_policy_digest;
   string capability_proof_id;
   uint capability_proof_version;
   string capability_proof_digest;
   ulong symbol_specification_sequence;
   ulong expected_basket_version;
   int direction;
   double requested_volume;
   string request_set_digest;
   string hard_kill_state_digest;
   ulong expected_broker_query_high_watermark;
   ulong expected_execution_query_high_watermark;
   ulong pin_revision;
   string pin_digest;
};

string SWV5S5_MvpAttemptPinKey(const SWV5_ExecutionRequestIdentity &id)
{ return id.request_id.correlation_id+":"+id.request_id.attempt_id; }

bool SWV5S5_MvpAttemptPinCanonical(const SWV5S5_MvpAttemptReconciliationPin &p,const bool include_digest,string &body)
{
   body=""; string f,n;
   if(!SWV5S5_MvpCodecEncode_SWV5_ContractVersion(p.contract_version,n) || !SWV5S5_CanonicalNested("version",n,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_ExecutionRequestIdentity(p.request_identity,n) || !SWV5S5_CanonicalNested("request",n,f)) return false; body+=f;
#define PIN_STR(name,value) if(!SWV5S5_CanonicalString(name,value,f)) return false; body+=f
#define PIN_UINT(name,value) if(!SWV5S5_CanonicalUInt(name,value,f)) return false; body+=f
   PIN_STR("permit_id",p.permit_id); PIN_STR("permit_digest",p.permit_digest);
   PIN_STR("admission_digest",p.admission_snapshot_digest); PIN_STR("expected_claim_id",p.expected_claim_id);
   PIN_STR("profile_id",p.broker_profile_id); PIN_STR("profile_digest",p.broker_profile_digest);
   PIN_STR("correlation_id",p.correlation_policy_id); PIN_UINT("correlation_version",p.correlation_policy_version);
   PIN_STR("correlation_digest",p.correlation_policy_digest); PIN_STR("negative_id",p.negative_policy_id);
   PIN_UINT("negative_version",p.negative_policy_version); PIN_STR("negative_digest",p.negative_policy_digest);
   PIN_STR("capability_id",p.capability_proof_id); PIN_UINT("capability_version",p.capability_proof_version);
   PIN_STR("capability_digest",p.capability_proof_digest); PIN_UINT("symbol_sequence",p.symbol_specification_sequence);
   PIN_UINT("basket_version",p.expected_basket_version);
   if(!SWV5S5_CanonicalInt("direction",p.direction,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("volume",p.requested_volume,f)) return false; body+=f;
   PIN_STR("request_set_digest",p.request_set_digest); PIN_STR("hard_kill_digest",p.hard_kill_state_digest);
   PIN_UINT("broker_hwm",p.expected_broker_query_high_watermark); PIN_UINT("execution_hwm",p.expected_execution_query_high_watermark);
   PIN_UINT("pin_revision",p.pin_revision); if(include_digest){ PIN_STR("pin_digest",p.pin_digest); }
#undef PIN_STR
#undef PIN_UINT
   return true;
}

bool SWV5S5_MvpAttemptPinDigest(const SWV5S5_MvpAttemptReconciliationPin &p,string &digest)
{ string body; return SWV5S5_MvpAttemptPinCanonical(p,false,body) && SWV5S5_DomainDigest(SWV5S5_MVP_PIN_DIGEST_DOMAIN,body,digest); }

bool SWV5S5_MvpInitialReconciliationVector(const SWV5S5_MvpAttemptReconciliationPin &pin,
                                           string &payload,string &digest)
{
   payload=""; digest=""; string f;
   if(!SWV5S5_CanonicalString("pin_digest",pin.pin_digest,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalInt("state",(int)SWV5S5_F_SUBMISSION_UNRESOLVED,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalDouble("confirmed_volume",0.0,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalDouble("residual_volume",pin.requested_volume,f)) return false; payload+=f;
   return SWV5S5_DomainDigest("SWV5-S5-MVP-INITIAL-RECONCILIATION-VECTOR-V1",payload,digest);
}

bool SWV5S5_MvpDecodeAttemptPin(const string payload,SWV5S5_MvpAttemptReconciliationPin &p)
{
   ZeroMemory(p); SWV5S5_MvpCodecReader r; r.Init(payload); string n; long x=0;
   if(!r.ReadNested("version",n) || !SWV5S5_MvpCodecDecode_SWV5_ContractVersion(n,p.contract_version) ||
      !r.ReadNested("request",n) || !SWV5S5_MvpCodecDecode_SWV5_ExecutionRequestIdentity(n,p.request_identity)) return false;
   if(!r.ReadString("permit_id",p.permit_id) || !r.ReadString("permit_digest",p.permit_digest) ||
      !r.ReadString("admission_digest",p.admission_snapshot_digest) || !r.ReadString("expected_claim_id",p.expected_claim_id) ||
      !r.ReadString("profile_id",p.broker_profile_id) || !r.ReadString("profile_digest",p.broker_profile_digest) ||
      !r.ReadString("correlation_id",p.correlation_policy_id) || !r.ReadUnsigned("correlation_version",p.correlation_policy_version) ||
      !r.ReadString("correlation_digest",p.correlation_policy_digest) || !r.ReadString("negative_id",p.negative_policy_id) ||
      !r.ReadUnsigned("negative_version",p.negative_policy_version) || !r.ReadString("negative_digest",p.negative_policy_digest) ||
      !r.ReadString("capability_id",p.capability_proof_id) || !r.ReadUnsigned("capability_version",p.capability_proof_version) ||
      !r.ReadString("capability_digest",p.capability_proof_digest) || !r.ReadUnsigned("symbol_sequence",p.symbol_specification_sequence) ||
      !r.ReadUnsigned("basket_version",p.expected_basket_version) || !r.ReadInteger("direction",x)) return false; p.direction=(int)x;
   if(!r.ReadDouble("volume",p.requested_volume) || !r.ReadString("request_set_digest",p.request_set_digest) ||
      !r.ReadString("hard_kill_digest",p.hard_kill_state_digest) ||
      !r.ReadUnsigned("broker_hwm",p.expected_broker_query_high_watermark) ||
      !r.ReadUnsigned("execution_hwm",p.expected_execution_query_high_watermark) ||
      !r.ReadUnsigned("pin_revision",p.pin_revision) || !r.ReadString("pin_digest",p.pin_digest) || !r.AtEnd()) return false;
   string d; return SWV5S5_MvpAttemptPinDigest(p,d) && d==p.pin_digest;
}

class SWV5S5_MvpAttemptReconciliationPinAuthority
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
public:
   bool Configure(const string path,const string namespace_digest){ return m_store.Open(path,namespace_digest); }
   bool PersistBeforeClaim(SWV5S5_MvpAttemptReconciliationPin &pin,const SWV5S5_MvpAuthorityRow &ownership_guard,
                            const datetime committed_at,SWV5S5_MvpAuthorityRow &committed)
   {
      pin.pin_revision=1; if(!SWV5S5_MvpAttemptPinDigest(pin,pin.pin_digest)) return false;
      const string key=SWV5S5_MvpAttemptPinKey(pin.request_identity); string payload;
      if(key==":" || pin.permit_id=="" || pin.expected_claim_id=="" || committed_at<=0 ||
          !SWV5S5_MvpAttemptPinCanonical(pin,true,payload)) return false;
      SWV5S5_MvpAuthorityRow current,reconciliation_current,reconciliation_committed;
      bool found=false,reconciliation_found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_RECONCILIATION_PIN,key,current,found) || found ||
         !m_store.ReadRow("MVP_RECONCILIATION_PUBLICATION",key,reconciliation_current,
                          reconciliation_found) || reconciliation_found) return false;

      // The immutable attempt pin and the initial unresolved reconciliation
      // vector are one physical pre-Claim transaction. This gives D6 an
      // existing revision to bind (the frozen contract requires revision > 0)
      // without granting Claim or inventing reconciliation evidence.
      string vector_payload,vector_digest;
      if(!SWV5S5_MvpInitialReconciliationVector(pin,vector_payload,vector_digest)) return false;
      SWV5S5_MvpAuthorityMutation pin_mutation,vector_mutation;
      SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_RECONCILIATION_PIN,key,current,false,
         1,1,pin.pin_digest,payload,committed_at,pin_mutation);
      SWV5S5_MvpPrepareMutation("MVP_RECONCILIATION_PUBLICATION",key,reconciliation_current,false,
         1,(int)SWV5S5_F_SUBMISSION_UNRESOLVED,vector_digest,vector_payload,committed_at,vector_mutation);
      return m_store.CompareAndSetPairWithGuard(pin_mutation,vector_mutation,ownership_guard,
                                                committed,reconciliation_committed);
   }
   bool Load(const SWV5_ExecutionRequestIdentity &id,SWV5S5_MvpAttemptReconciliationPin &pin,
             SWV5S5_MvpAuthorityRow &row,bool &found)
   {
      ZeroMemory(pin); found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_RECONCILIATION_PIN,SWV5S5_MvpAttemptPinKey(id),row,found) || !found) return !found;
      return SWV5S5_MvpDecodeAttemptPin(row.payload,pin) && row.payload_digest==pin.pin_digest &&
         SWV5S5_EqualRequestIdentity(pin.request_identity,id) && pin.pin_revision==1;
   }
   bool LoadInitialVector(const SWV5S5_MvpAttemptReconciliationPin &pin,
                          SWV5S5_MvpAuthorityRow &row,bool &found)
   {
      found=false; string payload,digest;
      return SWV5S5_MvpInitialReconciliationVector(pin,payload,digest) &&
         m_store.ReadRow("MVP_RECONCILIATION_PUBLICATION",SWV5S5_MvpAttemptPinKey(pin.request_identity),row,found) &&
         (!found || (row.logical_revision==1 && row.state==(int)SWV5S5_F_SUBMISSION_UNRESOLVED &&
                     row.payload==payload && row.payload_digest==digest));
   }
};

#endif // SW_V5_S5_MVP_RECONCILIATION_GOVERNANCE_AUTHORITIES_MQH
