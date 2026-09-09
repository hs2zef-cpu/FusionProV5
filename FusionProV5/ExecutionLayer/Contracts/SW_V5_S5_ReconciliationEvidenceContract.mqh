#ifndef SW_V5_S5_RECONCILIATION_EVIDENCE_CONTRACT_MQH
#define SW_V5_S5_RECONCILIATION_EVIDENCE_CONTRACT_MQH

// SPRINT 5 PHASE F ENTRY CONTRACT CANDIDATE
// PURE / PLATFORM-INDEPENDENT / NO BROKER OR PHYSICAL STORE ACCESS
// NO ORDER SUBMISSION. This contract proposes reconciliation outcomes only.

#include "SW_V5_S5_Contracts.mqh"

#define SWV5S5_F_CONTRACT_NAME "SWV5-SPRINT5-PHASE-F-RECONCILIATION"
#define SWV5S5_F_SCHEMA_VERSION 1
#define SWV5S5_F_MINIMUM_COMPATIBLE_VERSION 1
#define SWV5S5_F_POLICY_ID "SWV5-SPRINT5-PHASE-F-ENTRY-V1"
#define SWV5S5_F_CORRELATION_POLICY_ID "SWV5-SPRINT5-BROKER-CORRELATION-PROOF-V1"
#define SWV5S5_F_NEGATIVE_POLICY_ID "SWV5-SPRINT5-AUTHORITATIVE-NEGATIVE-EVIDENCE-V1"
#define SWV5S5_F_DOMAIN_PROFILE "SWV5-SPRINT5-PHASE-F-P-BROKER-PROFILE-V1"
#define SWV5S5_F_DOMAIN_POSITIVE_EVIDENCE "SWV5-SPRINT5-PHASE-F-POSITIVE-EVIDENCE-V1"
#define SWV5S5_F_DOMAIN_QUERY_OBSERVATION "SWV5-SPRINT5-PHASE-F-QUERY-OBSERVATION-V1"

enum SWV5S5_F_ReconciliationState
{
   SWV5S5_F_NO_CALL=0,
   SWV5S5_F_SUBMISSION_UNRESOLVED=1,
   SWV5S5_F_SIDE_EFFECT_POSITIVELY_CONFIRMED=2,
   SWV5S5_F_NO_SIDE_EFFECT_CONFIRMED=3,
   SWV5S5_F_PARTIAL_EFFECT_CONFIRMED=4,
   SWV5S5_F_RECONCILIATION_BLOCKED=5
};

enum SWV5S5_F_SubmissionObservationKind
{
   SWV5S5_F_OBSERVATION_NONE=0,
   SWV5S5_F_PRE_CALL_LOCAL_REJECTION=1,
   SWV5S5_F_CLIENT_LOCAL_POST_INVOCATION_REJECTION=2,
   SWV5S5_F_BROKER_EXPLICIT_REJECTION_CANDIDATE=3,
   SWV5S5_F_ACCEPTED_SUBMISSION=4,
   SWV5S5_F_PROVISIONAL_SYNCHRONOUS_FIELDS=5,
   SWV5S5_F_TIMEOUT=6,
   SWV5S5_F_TRANSPORT_OR_PLATFORM_FAILURE=7,
   SWV5S5_F_UNKNOWN_OR_UNMAPPED_RETCODE=8,
   SWV5S5_F_MALFORMED_OR_PARTIAL_RESPONSE=9,
   SWV5S5_F_CALLBACK_OBSERVATION_ONLY=10,
   SWV5S5_F_CALLBACK_ABSENT=11,
   SWV5S5_F_QUERY_FAILURE=12,
   SWV5S5_F_QUERY_INCOMPLETE=13
};

enum SWV5S5_F_ReconciliationDisposition
{
   SWV5S5_F_DISPOSITION_INVALID=0,
   SWV5S5_F_DISPOSITION_PRESERVE_UNRESOLVED=1,
   SWV5S5_F_DISPOSITION_POSITIVE_CONFIRMED=2,
   SWV5S5_F_DISPOSITION_NEGATIVE_CONFIRMED=3,
   SWV5S5_F_DISPOSITION_PARTIAL_CONFIRMED=4,
   SWV5S5_F_DISPOSITION_BLOCK_MANUAL=5,
   SWV5S5_F_DISPOSITION_NO_CALL=6,
   SWV5S5_F_DISPOSITION_IDEMPOTENT_TERMINAL=7
};

struct SWV5S5_F_ProfileScope
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_AccountRiskNamespace account_namespace;
   string broker_identity;
   string server;
   long account_login;
   string symbol;
   int terminal_build;
   int mql_build;
   string profile_id;
   string profile_digest;
};

// This is an immutable projection of already authoritative frozen records. It
// is not a replacement source of truth and cannot fabricate Claim authority.
struct SWV5S5_F_ReconciliationBinding
{
   SWV5_ContractVersion contract_version;
   SWV5S5_F_ProfileScope profile;
   SWV5_ExecutionRequestIdentity request_identity;
   SWV5S5_SubmissionAuthorityState submission_state;
   SWV5_PendingRequestState pending_request_state;
   SWV5_ExecutionLifecyclePhase pending_request_phase;
   string permit_id;
   string invocation_claim_id;
   string admission_snapshot_digest;
   string claim_record_digest;
   datetime claimed_at;
   ulong claim_clock_sequence;
   SWV5_OwnershipFence claim_ownership_fence;
   SWV5_InstanceLease current_reconciliation_lease;
   string expected_store_revision;
   ulong expected_reconciliation_revision;
   ulong expected_broker_query_high_watermark;
   ulong expected_execution_query_high_watermark;
   string persisted_reconciliation_vector_digest;
   string checkpoint_digest;
   string request_set_digest;
   string execution_pending_summary_digest;
   string ordered_request_evidence_digest;
   string hard_kill_state_digest;
   ulong symbol_specification_sequence;
   ulong expected_basket_version;
   int direction;
   double requested_volume;
   double persisted_confirmed_volume;
   double persisted_residual_volume;
};

struct SWV5S5_F_CorrelationPolicy
{
   SWV5_ContractVersion contract_version;
   string policy_id;
   uint policy_version;
   string broker_profile_id;
   string broker_profile_digest;
   SWV5_ComponentAuthority issuing_component;
   SWV5_AuthoritySource authority_source;
   string approval_reference;
   datetime approved_at;
   bool broker_order_identity_required;
   bool deal_order_link_required;
   bool position_identifier_link_required;
   bool ordered_deal_set_required;
   bool magic_is_strategy_scope_only;
   bool comment_is_non_authoritative;
   string policy_digest;
};

struct SWV5S5_F_TargetedPositiveEvidence
{
   SWV5_ContractVersion contract_version;
   SWV5S5_F_ProfileScope profile;
   SWV5_ExecutionRequestIdentity request_identity;
   string invocation_claim_id;
   string claim_record_digest;
   string correlation_policy_id;
   uint correlation_policy_version;
   string correlation_policy_digest;
   bool correlation_capability_proven;
   bool independently_query_confirmed;
   bool magic_used_as_sole_authority;
   bool comment_used_as_sole_authority;
   SWV5_AuthoritativeQuerySet query_set;
   ulong order_ticket;
   ulong deal_ticket;
   ulong deal_order_ticket;
   uint deal_count;
   string ordered_deal_set_digest;
   bool all_deals_linked_to_order_and_position;
   bool all_rows_read_successfully;
   ulong position_identifier;
   ulong order_position_identifier;
   ulong deal_position_identifier;
   string symbol;
   int direction;
   double execution_price;
   double cumulative_confirmed_volume;
   double requested_volume;
   ulong observed_magic;
   string observed_comment;
   datetime observed_at;
   string evidence_digest;
};

// One complete joint observation contains independently owned Broker and
// Execution query sets. Unrelated rows are allowed; matching rows must be zero
// before this observation can contribute to negative evidence.
struct SWV5S5_F_NegativeQueryObservation
{
   SWV5_ContractVersion contract_version;
   SWV5S5_F_ProfileScope profile;
   SWV5_ExecutionRequestIdentity request_identity;
   string invocation_claim_id;
   string claim_record_digest;
   string correlation_policy_id;
   uint correlation_policy_version;
   string correlation_policy_digest;
   bool correlation_capability_proven;
   bool magic_used_as_sole_authority;
   bool comment_used_as_sole_authority;
   SWV5_AuthoritativeQuerySet broker_query_set;
   SWV5_AuthoritativeQuerySet execution_query_set;
   bool broker_operation_success;
   bool execution_operation_success;
   bool broker_enumeration_complete;
   bool execution_enumeration_complete;
   uint broker_row_read_failures;
   uint execution_row_read_failures;
   datetime history_from;
   datetime history_to;
   ulong connection_generation;
   ulong restart_generation;
   uint matching_positions;
   uint matching_orders;
   uint matching_deals;
   uint matching_transactions;
   uint matching_pending_requests;
   uint unrelated_rows;
   string observation_digest;
};

struct SWV5S5_F_NegativeEvidencePolicy
{
   SWV5_ContractVersion contract_version;
   string policy_id;
   uint policy_version;
   string broker_profile_id;
   string broker_profile_digest;
   SWV5_ComponentAuthority issuing_component;
   SWV5_AuthoritySource authority_source;
   string approval_reference;
   datetime approved_at;
   bool query_completeness_capability_proven;
   bool visibility_watermark_proven;
   ulong required_broker_flags;
   ulong required_execution_flags;
   uint minimum_stable_observations;
   uint minimum_stability_seconds;
   uint proven_visibility_lag_seconds;
   ulong required_connection_generation;
   ulong required_restart_generation;
   string policy_digest;
};

struct SWV5S5_F_ReconciliationInput
{
   SWV5_ContractVersion contract_version;
   SWV5S5_F_ReconciliationState prior_state;
   SWV5S5_F_SubmissionObservationKind observation_kind;
   SWV5S5_F_ReconciliationBinding binding;
   SWV5S5_F_CorrelationPolicy correlation_policy;
   bool after_restart_or_takeover;
   bool positive_evidence_present;
   SWV5S5_F_TargetedPositiveEvidence positive_evidence;
   bool negative_evidence_present;
   SWV5S5_F_NegativeEvidencePolicy negative_policy;
   SWV5S5_F_NegativeQueryObservation negative_first;
   SWV5S5_F_NegativeQueryObservation negative_second;
};

struct SWV5S5_F_ReconciliationResult
{
   SWV5_ContractVersion contract_version;
   SWV5S5_F_ReconciliationState state;
   SWV5S5_F_ReconciliationDisposition disposition;
   SWV5S5_SubmissionAuthorityState proposed_submission_state;
   bool authoritative_positive;
   bool authoritative_negative;
   bool retry_allowed;
   bool requires_new_admission_for_any_future_attempt;
   double cumulative_confirmed_volume;
   double residual_volume;
   string reason_code;
};

void SWV5S5_F_InitVersion(SWV5_ContractVersion &version)
{
   ZeroMemory(version);
   version.contract_name=SWV5S5_F_CONTRACT_NAME;
   version.schema_version=SWV5S5_F_SCHEMA_VERSION;
   version.minimum_compatible_version=SWV5S5_F_MINIMUM_COMPATIBLE_VERSION;
   version.policy_id=SWV5S5_F_POLICY_ID;
}

bool SWV5S5_F_IsVersion(const SWV5_ContractVersion &version)
{
   return version.contract_name==SWV5S5_F_CONTRACT_NAME &&
      version.schema_version==SWV5S5_F_SCHEMA_VERSION &&
      version.minimum_compatible_version==SWV5S5_F_MINIMUM_COMPATIBLE_VERSION &&
      version.policy_id==SWV5S5_F_POLICY_ID;
}

bool SWV5S5_F_EqualProfile(const SWV5S5_F_ProfileScope &a,const SWV5S5_F_ProfileScope &b)
{
   return SWV5S5_F_IsVersion(a.contract_version) && SWV5S5_F_IsVersion(b.contract_version) &&
      SWV5S5_EqualNamespace(a.persistence_namespace,b.persistence_namespace) &&
      a.account_namespace.broker_identity==b.account_namespace.broker_identity &&
      a.account_namespace.server==b.account_namespace.server &&
      a.account_namespace.account_login==b.account_namespace.account_login &&
      a.account_namespace.strategy_id==b.account_namespace.strategy_id &&
      a.account_namespace.magic==b.account_namespace.magic &&
      a.account_namespace.account_mode==b.account_namespace.account_mode &&
      a.broker_identity==b.broker_identity && a.server==b.server &&
      a.account_login==b.account_login && a.symbol==b.symbol &&
      a.terminal_build==b.terminal_build && a.mql_build==b.mql_build &&
      a.profile_id==b.profile_id && a.profile_digest==b.profile_digest;
}

bool SWV5S5_F_DeriveProfileDigest(const SWV5S5_F_ProfileScope &profile,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalNamespace("persistence_namespace",profile.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account_namespace",profile.account_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("broker_identity",profile.broker_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("server",profile.server,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("account_login",profile.account_login,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("symbol",profile.symbol,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("terminal_build",profile.terminal_build,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("mql_build",profile.mql_build,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("profile_id",profile.profile_id,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_F_DOMAIN_PROFILE,body,digest);
}

bool SWV5S5_F_IsProfileValid(const SWV5S5_F_ProfileScope &profile)
{
   string profile_digest;
   return SWV5S5_F_IsVersion(profile.contract_version) &&
      SWV5S5_IsV5Version(profile.persistence_namespace.contract_version) &&
      SWV5S5_IsV5Version(profile.account_namespace.contract_version) &&
      profile.broker_identity!="" && profile.server!="" && profile.account_login>0 &&
      profile.symbol!="" && profile.terminal_build>0 && profile.mql_build>0 &&
      profile.profile_id!="" && SWV5S5_F_DeriveProfileDigest(profile,profile_digest) &&
      profile.profile_digest==profile_digest &&
      profile.account_namespace.account_mode==SWV5_ACCOUNT_MODE_HEDGING &&
      profile.persistence_namespace.ownership_namespace.broker_identity==profile.broker_identity &&
      profile.persistence_namespace.ownership_namespace.server==profile.server &&
      profile.persistence_namespace.ownership_namespace.account_login==profile.account_login &&
      profile.persistence_namespace.ownership_namespace.symbol==profile.symbol &&
      profile.account_namespace.broker_identity==profile.broker_identity &&
      profile.account_namespace.server==profile.server &&
      profile.account_namespace.account_login==profile.account_login &&
      profile.account_namespace.strategy_id==profile.persistence_namespace.ownership_namespace.strategy_id &&
      profile.account_namespace.magic==profile.persistence_namespace.ownership_namespace.magic &&
      profile.account_namespace.magic>0 && profile.account_namespace.account_currency!="" &&
      profile.account_namespace.authoritative_source==SWV5_AUTHORITY_LIVE_BROKER_STATE &&
      profile.account_namespace.snapshot_epoch>0 && profile.account_namespace.snapshot_sequence>0;
}

bool SWV5S5_F_IsOwnershipKeyValid(const SWV5_OwnershipKey &key)
{
   return key.account_login>0 && key.broker_identity!="" && key.server!="" &&
      key.symbol!="" && key.strategy_id!="" && key.magic>0;
}

bool SWV5S5_F_IsFenceStructurallyValid(const SWV5_OwnershipFence &fence)
{
   return SWV5S5_IsV5Version(fence.contract_version) &&
      SWV5S5_F_IsOwnershipKeyValid(fence.ownership_namespace) &&
      SWV5S5_EqualOwnershipKey(fence.owner.key,fence.ownership_namespace) &&
      fence.owner.instance_id!="" && fence.owner.process_fingerprint!="" &&
      fence.owner.started_at>0 && fence.lease_version>0 &&
      SWV5S5_IsDigest64Lower(fence.fencing_token_digest);
}

bool SWV5S5_F_IsCurrentLeaseValid(const SWV5_ContractValidationContext &context,
                                  const SWV5_InstanceLease &lease)
{
   return SWV5S5_IsV5Version(lease.contract_version) &&
      SWV5S5_F_IsFenceStructurallyValid(lease.fence) &&
      (lease.status==SWV5_LOCK_ACQUIRED || lease.status==SWV5_LOCK_RENEWED) &&
      lease.store_revision!="" && lease.heartbeat_sequence>0 && lease.clock_id==context.clock_id &&
      lease.clock_authority==context.clock_authority &&
      lease.acquired_clock_sequence>0 &&
      lease.heartbeat_clock_sequence>=lease.acquired_clock_sequence &&
      lease.expiry_clock_sequence>lease.heartbeat_clock_sequence &&
      context.clock_sequence>lease.heartbeat_clock_sequence &&
      context.clock_sequence<lease.expiry_clock_sequence &&
      lease.acquired_at>0 && lease.heartbeat_at>=lease.acquired_at &&
      lease.expires_at>lease.heartbeat_at && context.clock_time>lease.heartbeat_at &&
      lease.expires_at>context.clock_time;
}

bool SWV5S5_F_IsQuerySetExact(const SWV5_AuthoritativeQuerySet &query,
                              const ulong required_flags,
                              const SWV5_ComponentAuthority component,
                              const SWV5_AuthoritySource source)
{
   return SWV5S5_IsV5Version(query.contract_version) && required_flags!=0 &&
      (required_flags & ~SWV5_QUERY_KNOWN_FLAGS_V5)==0 &&
      query.required_flags==required_flags && query.completed_flags==required_flags &&
      query.authoritative_flags==required_flags && query.observation_sequence>0 &&
      query.observed_at>0 && query.issuing_component==component &&
      query.authority_source==source && query.snapshot_id!="" &&
      SWV5S5_IsDigest64Lower(query.snapshot_digest);
}

bool SWV5S5_F_DeriveCorrelationPolicyDigest(const SWV5S5_F_CorrelationPolicy &policy,
                                             string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalString("policy_id",policy.policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("policy_version",policy.policy_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("profile_id",policy.broker_profile_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("profile_digest",policy.broker_profile_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("issuing_component",policy.issuing_component,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("authority_source",policy.authority_source,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("approval_reference",policy.approval_reference,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("approved_at",policy.approved_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("broker_order_identity_required",policy.broker_order_identity_required,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("deal_order_link_required",policy.deal_order_link_required,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("position_identifier_link_required",policy.position_identifier_link_required,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("ordered_deal_set_required",policy.ordered_deal_set_required,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("magic_is_strategy_scope_only",policy.magic_is_strategy_scope_only,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("comment_is_non_authoritative",policy.comment_is_non_authoritative,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_F_CORRELATION_POLICY_ID,body,digest);
}

bool SWV5S5_F_IsCorrelationPolicyValid(const SWV5S5_F_ReconciliationBinding &binding,
                                        const SWV5S5_F_CorrelationPolicy &policy)
{
   string digest;
   return SWV5S5_F_IsVersion(policy.contract_version) &&
      policy.policy_id==SWV5S5_F_CORRELATION_POLICY_ID && policy.policy_version==1 &&
      policy.broker_profile_id==binding.profile.profile_id &&
      policy.broker_profile_digest==binding.profile.profile_digest &&
      policy.issuing_component==SWV5_COMPONENT_AUTHORITY_OPERATOR &&
      policy.authority_source==SWV5_AUTHORITY_OPERATOR &&
      policy.approval_reference!="" && policy.approved_at>0 && policy.approved_at<=binding.claimed_at &&
      policy.broker_order_identity_required && policy.deal_order_link_required &&
      policy.position_identifier_link_required && policy.ordered_deal_set_required &&
      policy.magic_is_strategy_scope_only && policy.comment_is_non_authoritative &&
      SWV5S5_F_DeriveCorrelationPolicyDigest(policy,digest) && policy.policy_digest==digest;
}

bool SWV5S5_F_DerivePositiveEvidenceDigest(const SWV5S5_F_TargetedPositiveEvidence &evidence,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalNamespace("scope",evidence.profile.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",evidence.request_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_id",evidence.invocation_claim_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_digest",evidence.claim_record_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("correlation_policy",evidence.correlation_policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("correlation_policy_version",evidence.correlation_policy_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("correlation_policy_digest",evidence.correlation_policy_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("correlation_capability_proven",evidence.correlation_capability_proven,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("independently_query_confirmed",evidence.independently_query_confirmed,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("magic_used_as_sole_authority",evidence.magic_used_as_sole_authority,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("comment_used_as_sole_authority",evidence.comment_used_as_sole_authority,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("query_digest",evidence.query_set.snapshot_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("order_ticket",evidence.order_ticket,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("deal_ticket",evidence.deal_ticket,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("deal_order_ticket",evidence.deal_order_ticket,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("deal_count",evidence.deal_count,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("ordered_deal_set_digest",evidence.ordered_deal_set_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("all_deals_linked",evidence.all_deals_linked_to_order_and_position,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("all_rows_read_successfully",evidence.all_rows_read_successfully,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("position_identifier",evidence.position_identifier,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("order_position_identifier",evidence.order_position_identifier,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("deal_position_identifier",evidence.deal_position_identifier,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("symbol",evidence.symbol,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("direction",evidence.direction,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("execution_price",evidence.execution_price,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("confirmed_volume",evidence.cumulative_confirmed_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("requested_volume",evidence.requested_volume,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("observed_magic",evidence.observed_magic,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("observed_comment",evidence.observed_comment,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",evidence.observed_at,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_F_DOMAIN_POSITIVE_EVIDENCE,body,digest);
}

bool SWV5S5_F_IsPositiveEvidenceValid(const SWV5_ContractValidationContext &context,
                                      const SWV5S5_F_ReconciliationBinding &binding,
                                      const SWV5S5_F_CorrelationPolicy &policy,
                                      const SWV5S5_F_TargetedPositiveEvidence &evidence)
{
   string digest;
   const ulong required=SWV5_QUERY_ORDERS|SWV5_QUERY_DEALS;
   return SWV5S5_F_IsVersion(evidence.contract_version) &&
      SWV5S5_F_EqualProfile(binding.profile,evidence.profile) &&
      SWV5S5_EqualRequestIdentity(binding.request_identity,evidence.request_identity) &&
      evidence.invocation_claim_id==binding.invocation_claim_id &&
      evidence.claim_record_digest==binding.claim_record_digest &&
      SWV5S5_F_IsCorrelationPolicyValid(binding,policy) &&
      evidence.correlation_policy_id==SWV5S5_F_CORRELATION_POLICY_ID &&
      evidence.correlation_policy_version==policy.policy_version &&
      evidence.correlation_policy_digest==policy.policy_digest &&
      evidence.correlation_capability_proven &&
      evidence.independently_query_confirmed && !evidence.magic_used_as_sole_authority &&
      !evidence.comment_used_as_sole_authority &&
      SWV5S5_F_IsQuerySetExact(evidence.query_set,required,
         SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER,SWV5_AUTHORITY_DEAL_HISTORY) &&
      evidence.query_set.observation_sequence>binding.expected_broker_query_high_watermark &&
      evidence.order_ticket>0 && evidence.deal_ticket>0 &&
      evidence.deal_order_ticket==evidence.order_ticket && evidence.position_identifier>0 &&
      evidence.deal_count>0 && SWV5S5_IsDigest64Lower(evidence.ordered_deal_set_digest) &&
      evidence.all_deals_linked_to_order_and_position && evidence.all_rows_read_successfully &&
      evidence.order_position_identifier==evidence.position_identifier &&
      evidence.deal_position_identifier==evidence.position_identifier &&
      evidence.symbol==binding.profile.symbol && evidence.direction==binding.direction &&
      SWV5_IsFiniteNumber(evidence.execution_price) && evidence.execution_price>0.0 &&
      SWV5_IsFiniteNumber(evidence.cumulative_confirmed_volume) &&
      SWV5_IsFiniteNumber(evidence.requested_volume) && evidence.cumulative_confirmed_volume>0.0 &&
      evidence.requested_volume==binding.requested_volume &&
      evidence.cumulative_confirmed_volume<=evidence.requested_volume+context.volume_tolerance &&
      evidence.observed_at>=evidence.query_set.observed_at &&
      evidence.query_set.observed_at>=binding.claimed_at &&
      evidence.observed_at>=binding.claimed_at &&
      SWV5S5_F_DerivePositiveEvidenceDigest(evidence,digest) && evidence.evidence_digest==digest;
}

bool SWV5S5_F_DeriveNegativeObservationDigest(const SWV5S5_F_NegativeQueryObservation &observation,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalNamespace("scope",observation.profile.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",observation.request_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_id",observation.invocation_claim_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("claim_digest",observation.claim_record_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("correlation_policy",observation.correlation_policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("correlation_policy_version",observation.correlation_policy_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("correlation_policy_digest",observation.correlation_policy_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("correlation_capability_proven",observation.correlation_capability_proven,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("magic_used_as_sole_authority",observation.magic_used_as_sole_authority,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("comment_used_as_sole_authority",observation.comment_used_as_sole_authority,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("broker_query_digest",observation.broker_query_set.snapshot_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("execution_query_digest",observation.execution_query_set.snapshot_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("broker_operation_success",observation.broker_operation_success,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("execution_operation_success",observation.execution_operation_success,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("broker_enumeration_complete",observation.broker_enumeration_complete,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("execution_enumeration_complete",observation.execution_enumeration_complete,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("broker_row_read_failures",observation.broker_row_read_failures,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("execution_row_read_failures",observation.execution_row_read_failures,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("history_from",observation.history_from,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("history_to",observation.history_to,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("connection_generation",observation.connection_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("restart_generation",observation.restart_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("matching_positions",observation.matching_positions,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("matching_orders",observation.matching_orders,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("matching_deals",observation.matching_deals,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("matching_transactions",observation.matching_transactions,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("matching_pending",observation.matching_pending_requests,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("unrelated_rows",observation.unrelated_rows,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_F_DOMAIN_QUERY_OBSERVATION,body,digest);
}

bool SWV5S5_F_DeriveNegativePolicyDigest(const SWV5S5_F_NegativeEvidencePolicy &policy,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalString("policy_id",policy.policy_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("policy_version",policy.policy_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("profile_id",policy.broker_profile_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("profile_digest",policy.broker_profile_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("issuing_component",policy.issuing_component,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("authority_source",policy.authority_source,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("approval_reference",policy.approval_reference,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("approved_at",policy.approved_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("query_completeness",policy.query_completeness_capability_proven,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("visibility_watermark",policy.visibility_watermark_proven,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("broker_flags",policy.required_broker_flags,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("execution_flags",policy.required_execution_flags,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("stable_observations",policy.minimum_stable_observations,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("stability_seconds",policy.minimum_stability_seconds,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("visibility_lag_seconds",policy.proven_visibility_lag_seconds,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("connection_generation",policy.required_connection_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("restart_generation",policy.required_restart_generation,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_F_NEGATIVE_POLICY_ID,body,digest);
}

bool SWV5S5_F_IsNegativeObservationValid(const SWV5S5_F_ReconciliationBinding &binding,
                                         const SWV5S5_F_CorrelationPolicy &correlation_policy,
                                         const SWV5S5_F_NegativeEvidencePolicy &policy,
                                         const SWV5S5_F_NegativeQueryObservation &observation)
{
   string digest;
   return SWV5S5_F_IsVersion(observation.contract_version) &&
      SWV5S5_F_EqualProfile(binding.profile,observation.profile) &&
      SWV5S5_EqualRequestIdentity(binding.request_identity,observation.request_identity) &&
      observation.invocation_claim_id==binding.invocation_claim_id &&
      observation.claim_record_digest==binding.claim_record_digest &&
      SWV5S5_F_IsCorrelationPolicyValid(binding,correlation_policy) &&
      observation.correlation_policy_id==SWV5S5_F_CORRELATION_POLICY_ID &&
      observation.correlation_policy_version==correlation_policy.policy_version &&
      observation.correlation_policy_digest==correlation_policy.policy_digest &&
      observation.correlation_capability_proven &&
      !observation.magic_used_as_sole_authority && !observation.comment_used_as_sole_authority &&
      observation.broker_operation_success && observation.execution_operation_success &&
      observation.broker_enumeration_complete && observation.execution_enumeration_complete &&
      observation.broker_row_read_failures==0 && observation.execution_row_read_failures==0 &&
      SWV5S5_F_IsQuerySetExact(observation.broker_query_set,policy.required_broker_flags,
         SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER,SWV5_AUTHORITY_LIVE_BROKER_STATE) &&
      SWV5S5_F_IsQuerySetExact(observation.execution_query_set,policy.required_execution_flags,
         SWV5_COMPONENT_AUTHORITY_EXECUTION,SWV5_AUTHORITY_EXECUTION_REQUEST_STATE) &&
      observation.broker_query_set.observation_sequence>binding.expected_broker_query_high_watermark &&
      observation.execution_query_set.observation_sequence>binding.expected_execution_query_high_watermark &&
      observation.history_from<=binding.claimed_at &&
      observation.history_to>=observation.broker_query_set.observed_at &&
      observation.history_to>=observation.execution_query_set.observed_at &&
      observation.connection_generation==policy.required_connection_generation &&
      observation.restart_generation==policy.required_restart_generation &&
      observation.matching_positions==0 && observation.matching_orders==0 &&
      observation.matching_deals==0 && observation.matching_transactions==0 &&
      observation.matching_pending_requests==0 &&
      SWV5S5_F_DeriveNegativeObservationDigest(observation,digest) &&
      observation.observation_digest==digest;
}

bool SWV5S5_F_HasAuthoritativeNegative(const SWV5_ContractValidationContext &context,
                                       const SWV5S5_F_ReconciliationBinding &binding,
                                       const SWV5S5_F_CorrelationPolicy &correlation_policy,
                                       const SWV5S5_F_NegativeEvidencePolicy &policy,
                                       const SWV5S5_F_NegativeQueryObservation &first,
                                       const SWV5S5_F_NegativeQueryObservation &second)
{
   string policy_digest;
   return SWV5S5_F_IsVersion(policy.contract_version) &&
      policy.policy_id==SWV5S5_F_NEGATIVE_POLICY_ID && policy.policy_version==1 &&
      policy.broker_profile_id==binding.profile.profile_id &&
      policy.broker_profile_digest==binding.profile.profile_digest &&
      policy.issuing_component==SWV5_COMPONENT_AUTHORITY_OPERATOR &&
      policy.authority_source==SWV5_AUTHORITY_OPERATOR &&
      policy.approval_reference!="" && policy.approved_at>0 && policy.approved_at<=binding.claimed_at &&
      policy.query_completeness_capability_proven && policy.visibility_watermark_proven &&
      policy.required_broker_flags==(SWV5_QUERY_POSITIONS|SWV5_QUERY_ORDERS|SWV5_QUERY_DEALS|SWV5_QUERY_TRANSACTIONS) &&
      policy.required_execution_flags==SWV5_QUERY_PENDING_REQUESTS &&
      policy.minimum_stable_observations==2 && policy.minimum_stability_seconds>0 &&
      policy.proven_visibility_lag_seconds>0 &&
      SWV5S5_F_DeriveNegativePolicyDigest(policy,policy_digest) && policy.policy_digest==policy_digest &&
      SWV5S5_F_IsCorrelationPolicyValid(binding,correlation_policy) &&
      SWV5S5_F_IsNegativeObservationValid(binding,correlation_policy,policy,first) &&
      SWV5S5_F_IsNegativeObservationValid(binding,correlation_policy,policy,second) &&
      second.broker_query_set.observation_sequence>first.broker_query_set.observation_sequence &&
      second.execution_query_set.observation_sequence>first.execution_query_set.observation_sequence &&
      second.broker_query_set.observed_at>=first.broker_query_set.observed_at+(int)policy.minimum_stability_seconds &&
      second.execution_query_set.observed_at>=first.execution_query_set.observed_at+(int)policy.minimum_stability_seconds &&
      second.broker_query_set.observed_at>=binding.claimed_at+(int)policy.proven_visibility_lag_seconds &&
      second.execution_query_set.observed_at>=binding.claimed_at+(int)policy.proven_visibility_lag_seconds &&
      context.clock_time>=second.broker_query_set.observed_at && context.clock_time>=second.execution_query_set.observed_at;
}

bool SWV5S5_F_IsBindingValid(const SWV5_ContractValidationContext &context,
                             const SWV5S5_F_ReconciliationBinding &binding)
{
   const bool claimed=(binding.submission_state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED ||
      binding.submission_state==SWV5S5_AUTHORITATIVE_SIDE_EFFECT_CONFIRMED ||
      binding.submission_state==SWV5S5_AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED ||
      binding.submission_state==SWV5S5_AUTHORITATIVE_REJECTED ||
      binding.submission_state==SWV5S5_CONFLICT_MANUAL_REQUIRED);
   return SWV5S5_F_IsVersion(binding.contract_version) && SWV5S5_F_IsProfileValid(binding.profile) &&
      SWV5S5_IsV5Version(binding.request_identity.contract_version) &&
      binding.request_identity.request_id.correlation_id!="" &&
      binding.request_identity.request_id.attempt_id!="" && binding.request_identity.idempotency_key!="" &&
      binding.permit_id!="" && binding.expected_store_revision!="" &&
      binding.expected_reconciliation_revision>0 && binding.symbol_specification_sequence>0 &&
      binding.expected_basket_version>0 && (binding.direction==1 || binding.direction==-1) &&
      SWV5_IsFiniteNumber(binding.requested_volume) &&
      SWV5_IsFiniteNumber(binding.persisted_confirmed_volume) &&
      SWV5_IsFiniteNumber(binding.persisted_residual_volume) &&
      binding.requested_volume>0.0 && binding.persisted_confirmed_volume>=0.0 &&
      binding.persisted_residual_volume>=0.0 &&
      MathAbs((binding.persisted_confirmed_volume+binding.persisted_residual_volume)-
         binding.requested_volume)<=context.volume_tolerance &&
      SWV5S5_IsDigest64Lower(binding.persisted_reconciliation_vector_digest) &&
      SWV5S5_IsDigest64Lower(binding.checkpoint_digest) &&
      SWV5S5_IsDigest64Lower(binding.request_set_digest) &&
      SWV5S5_IsDigest64Lower(binding.execution_pending_summary_digest) &&
      SWV5S5_IsDigest64Lower(binding.ordered_request_evidence_digest) &&
      SWV5S5_IsDigest64Lower(binding.hard_kill_state_digest) &&
      SWV5S5_F_IsCurrentLeaseValid(context,binding.current_reconciliation_lease) &&
      binding.current_reconciliation_lease.store_revision==binding.expected_store_revision &&
      SWV5S5_EqualOwnershipKey(binding.current_reconciliation_lease.fence.ownership_namespace,
         binding.profile.persistence_namespace.ownership_namespace) &&
      (!claimed || (binding.invocation_claim_id!="" &&
         binding.claimed_at>0 && binding.claim_clock_sequence>0 &&
         SWV5S5_IsDigest64Lower(binding.admission_snapshot_digest) &&
         SWV5S5_IsDigest64Lower(binding.claim_record_digest) &&
         SWV5S5_F_IsFenceStructurallyValid(binding.claim_ownership_fence) &&
         SWV5S5_EqualOwnershipKey(binding.claim_ownership_fence.ownership_namespace,
            binding.profile.persistence_namespace.ownership_namespace)));
}

void SWV5S5_F_SetResult(const SWV5S5_F_ReconciliationState state,
                        const SWV5S5_F_ReconciliationDisposition disposition,
                        const SWV5S5_SubmissionAuthorityState submission_state,
                        const bool positive,const bool negative,
                        const bool future_new_admission,
                        const double confirmed,const double residual,
                        const string reason,SWV5S5_F_ReconciliationResult &result)
{
   ZeroMemory(result); SWV5S5_F_InitVersion(result.contract_version);
   result.state=state; result.disposition=disposition;
   result.proposed_submission_state=submission_state;
   result.authoritative_positive=positive; result.authoritative_negative=negative;
   result.retry_allowed=false;
   result.requires_new_admission_for_any_future_attempt=future_new_admission;
   result.cumulative_confirmed_volume=confirmed; result.residual_volume=residual;
   result.reason_code=reason;
}

bool SWV5S5_F_EvaluateReconciliation(const SWV5_ContractValidationContext &context,
                                     const SWV5S5_F_ReconciliationInput &candidate,
                                     SWV5S5_F_ReconciliationResult &result)
{
   if(!SWV5S5_IsValidationContextUsable(context) || !SWV5S5_F_IsVersion(candidate.contract_version) ||
      !SWV5S5_F_IsBindingValid(context,candidate.binding))
   {
      SWV5S5_F_SetResult(SWV5S5_F_RECONCILIATION_BLOCKED,SWV5S5_F_DISPOSITION_BLOCK_MANUAL,
         SWV5S5_CONFLICT_MANUAL_REQUIRED,false,false,false,0.0,candidate.binding.requested_volume,
         "INVALID_OR_STALE_JOINT_BINDING",result); return false;
   }

   if(candidate.prior_state==SWV5S5_F_NO_CALL)
   {
      const bool unclaimed=(candidate.binding.submission_state==SWV5S5_COMMITTED_NOT_INVOKED ||
         candidate.binding.submission_state==SWV5S5_INVALIDATED_BEFORE_CLAIM) &&
         candidate.binding.invocation_claim_id=="" && candidate.binding.claimed_at==0 &&
         candidate.binding.claim_clock_sequence==0;
      if(unclaimed && !candidate.positive_evidence_present && !candidate.negative_evidence_present &&
         candidate.binding.persisted_confirmed_volume<=context.volume_tolerance &&
         MathAbs(candidate.binding.persisted_residual_volume-candidate.binding.requested_volume)<=
            context.volume_tolerance &&
         (candidate.observation_kind==SWV5S5_F_OBSERVATION_NONE ||
          candidate.observation_kind==SWV5S5_F_PRE_CALL_LOCAL_REJECTION))
      {
         SWV5S5_F_SetResult(SWV5S5_F_NO_CALL,SWV5S5_F_DISPOSITION_NO_CALL,
            candidate.binding.submission_state,false,false,true,0.0,candidate.binding.requested_volume,
            "NO_SUCCESSFUL_CLAIM_OR_BROKER_CALL",result); return true;
      }
      SWV5S5_F_SetResult(SWV5S5_F_RECONCILIATION_BLOCKED,SWV5S5_F_DISPOSITION_BLOCK_MANUAL,
         SWV5S5_CONFLICT_MANUAL_REQUIRED,false,false,false,0.0,candidate.binding.requested_volume,
         "NO_CALL_CONTRADICTED_BY_CLAIM_OR_EVIDENCE",result); return false;
   }

   if(candidate.prior_state==SWV5S5_F_SIDE_EFFECT_POSITIVELY_CONFIRMED ||
      candidate.prior_state==SWV5S5_F_NO_SIDE_EFFECT_CONFIRMED ||
      candidate.prior_state==SWV5S5_F_PARTIAL_EFFECT_CONFIRMED)
   {
      const bool positive_terminal=(candidate.prior_state==SWV5S5_F_SIDE_EFFECT_POSITIVELY_CONFIRMED &&
         candidate.binding.submission_state==SWV5S5_AUTHORITATIVE_SIDE_EFFECT_CONFIRMED &&
         candidate.binding.persisted_confirmed_volume>0.0 &&
         candidate.binding.persisted_residual_volume<=context.volume_tolerance);
      const bool partial_terminal=(candidate.prior_state==SWV5S5_F_PARTIAL_EFFECT_CONFIRMED &&
         candidate.binding.submission_state==SWV5S5_AUTHORITATIVE_SIDE_EFFECT_CONFIRMED &&
         candidate.binding.persisted_confirmed_volume>0.0 &&
         candidate.binding.persisted_residual_volume>context.volume_tolerance);
      const bool negative_terminal=(candidate.prior_state==SWV5S5_F_NO_SIDE_EFFECT_CONFIRMED &&
         (candidate.binding.submission_state==SWV5S5_AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED ||
          candidate.binding.submission_state==SWV5S5_AUTHORITATIVE_REJECTED) &&
         candidate.binding.persisted_confirmed_volume<=context.volume_tolerance &&
         MathAbs(candidate.binding.persisted_residual_volume-candidate.binding.requested_volume)<=
            context.volume_tolerance);
      if(!positive_terminal && !partial_terminal && !negative_terminal)
      {
         SWV5S5_F_SetResult(SWV5S5_F_RECONCILIATION_BLOCKED,SWV5S5_F_DISPOSITION_BLOCK_MANUAL,
            SWV5S5_CONFLICT_MANUAL_REQUIRED,false,false,false,
            candidate.binding.persisted_confirmed_volume,candidate.binding.persisted_residual_volume,
            "TERMINAL_STATE_BINDING_MISMATCH",result);
         return false;
      }
      if(!candidate.positive_evidence_present && !candidate.negative_evidence_present)
      {
         SWV5S5_SubmissionAuthorityState state=(candidate.prior_state==SWV5S5_F_NO_SIDE_EFFECT_CONFIRMED ?
            SWV5S5_AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED : SWV5S5_AUTHORITATIVE_SIDE_EFFECT_CONFIRMED);
         SWV5S5_F_SetResult(candidate.prior_state,SWV5S5_F_DISPOSITION_IDEMPOTENT_TERMINAL,state,
            candidate.prior_state!=SWV5S5_F_NO_SIDE_EFFECT_CONFIRMED,
            candidate.prior_state==SWV5S5_F_NO_SIDE_EFFECT_CONFIRMED,false,
            candidate.binding.persisted_confirmed_volume,candidate.binding.persisted_residual_volume,
            "TERMINAL_REPLAY_IDEMPOTENT",result); return true;
      }
      SWV5S5_F_SetResult(SWV5S5_F_RECONCILIATION_BLOCKED,SWV5S5_F_DISPOSITION_BLOCK_MANUAL,
         SWV5S5_CONFLICT_MANUAL_REQUIRED,false,false,false,0.0,candidate.binding.requested_volume,
         "TERMINAL_EVIDENCE_CONFLICT",result); return false;
   }

   if(candidate.prior_state!=SWV5S5_F_SUBMISSION_UNRESOLVED ||
      candidate.binding.submission_state!=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED ||
      candidate.binding.persisted_confirmed_volume>context.volume_tolerance ||
      MathAbs(candidate.binding.persisted_residual_volume-candidate.binding.requested_volume)>
         context.volume_tolerance)
   {
      SWV5S5_F_SetResult(SWV5S5_F_RECONCILIATION_BLOCKED,SWV5S5_F_DISPOSITION_BLOCK_MANUAL,
         SWV5S5_CONFLICT_MANUAL_REQUIRED,false,false,false,0.0,candidate.binding.requested_volume,
         "CLAIMED_UNRESOLVED_STATE_REQUIRED",result); return false;
   }

   const bool positive=candidate.positive_evidence_present &&
      SWV5S5_F_IsPositiveEvidenceValid(context,candidate.binding,candidate.correlation_policy,
         candidate.positive_evidence);
   const bool negative=candidate.negative_evidence_present &&
      SWV5S5_F_HasAuthoritativeNegative(context,candidate.binding,candidate.correlation_policy,
         candidate.negative_policy,candidate.negative_first,candidate.negative_second);
   if((candidate.positive_evidence_present && !positive) ||
      (positive && candidate.negative_evidence_present))
   {
      SWV5S5_F_SetResult(SWV5S5_F_RECONCILIATION_BLOCKED,SWV5S5_F_DISPOSITION_BLOCK_MANUAL,
         SWV5S5_CONFLICT_MANUAL_REQUIRED,false,false,false,0.0,candidate.binding.requested_volume,
      "EVIDENCE_INVALID_STALE_OR_CONFLICTING",result); return false;
   }

   // An incomplete/unsupported zero-row observation is not authoritative
   // negative evidence. It preserves the frozen claimed/unresolved boundary;
   // it is not upgraded into either success or a manual-conflict state.
   if(candidate.negative_evidence_present && !negative)
   {
      SWV5S5_F_SetResult(SWV5S5_F_SUBMISSION_UNRESOLVED,
         SWV5S5_F_DISPOSITION_PRESERVE_UNRESOLVED,SWV5S5_INVOCATION_CLAIMED_UNRESOLVED,
         false,false,false,0.0,candidate.binding.requested_volume,
         "NON_AUTHORITATIVE_NEGATIVE_CANDIDATE_PRESERVES_UNRESOLVED",result);
      return true;
   }

   if(positive)
   {
      double confirmed=candidate.positive_evidence.cumulative_confirmed_volume;
      double residual=candidate.binding.requested_volume-confirmed;
      if(residual<0.0 && MathAbs(residual)<=context.volume_tolerance) residual=0.0;
      if(residual>context.volume_tolerance)
      {
         SWV5S5_F_SetResult(SWV5S5_F_PARTIAL_EFFECT_CONFIRMED,SWV5S5_F_DISPOSITION_PARTIAL_CONFIRMED,
            SWV5S5_AUTHORITATIVE_SIDE_EFFECT_CONFIRMED,true,false,false,confirmed,residual,
            "PARTIAL_DURABLE_SIDE_EFFECT_RESIDUAL_UNRESOLVED",result); return true;
      }
      SWV5S5_F_SetResult(SWV5S5_F_SIDE_EFFECT_POSITIVELY_CONFIRMED,
         SWV5S5_F_DISPOSITION_POSITIVE_CONFIRMED,SWV5S5_AUTHORITATIVE_SIDE_EFFECT_CONFIRMED,
         true,false,false,confirmed,0.0,"DURABLE_BROKER_SIDE_EFFECT_CONFIRMED",result); return true;
   }

   if(negative)
   {
      SWV5S5_SubmissionAuthorityState next_state=
         (candidate.observation_kind==SWV5S5_F_BROKER_EXPLICIT_REJECTION_CANDIDATE ?
          SWV5S5_AUTHORITATIVE_REJECTED : SWV5S5_AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED);
      SWV5S5_F_SetResult(SWV5S5_F_NO_SIDE_EFFECT_CONFIRMED,
         SWV5S5_F_DISPOSITION_NEGATIVE_CONFIRMED,next_state,false,true,true,0.0,
         candidate.binding.requested_volume,"FULLY_QUALIFIED_NEGATIVE_EVIDENCE_CONFIRMED",result); return true;
   }

   SWV5S5_F_SetResult(SWV5S5_F_SUBMISSION_UNRESOLVED,
      SWV5S5_F_DISPOSITION_PRESERVE_UNRESOLVED,SWV5S5_INVOCATION_CLAIMED_UNRESOLVED,
      false,false,false,0.0,candidate.binding.requested_volume,
      candidate.after_restart_or_takeover ? "RESTART_OR_TAKEOVER_PRESERVES_UNRESOLVED" :
      "AMBIGUOUS_OR_SUPPLEMENTAL_EVIDENCE_NO_BLIND_RETRY",result);
   return true;
}

class ISWV5S5FReconciliationContract
{
public:
   virtual string ContractName()=0;
   virtual bool Evaluate(const SWV5_ContractValidationContext &context,
                         const SWV5S5_F_ReconciliationInput &candidate,
                         SWV5S5_F_ReconciliationResult &result)=0;
};

#endif
