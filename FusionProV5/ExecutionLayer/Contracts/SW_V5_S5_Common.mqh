#ifndef SW_V5_S5_COMMON_MQH
#define SW_V5_S5_COMMON_MQH

// SPRINT 5 PHASE B CANDIDATE CONTRACT
// PURE / PLATFORM-INDEPENDENT / NO BROKER OR PHYSICAL STORE ACCESS

#include "../../ProductionArchitecture/SW_V5_ProductionContracts.mqh"

#define SWV5S5_CONTRACT_NAME "SWV5-SPRINT5-EXECUTION-LAYER"
#define SWV5S5_SCHEMA_VERSION 2
#define SWV5S5_MINIMUM_COMPATIBLE_VERSION 2
#define SWV5S5_POLICY_ID "SWV5-SPRINT5-PHASE-B1-V2"
#define SWV5S5_CANONICAL_POLICY_ID "SWV5-SHA256-UTF8-V1"
#define SWV5S5_REQUEST_BINDING_POLICY_ID "SWV5-SPRINT5-REQUEST-BINDING-POLICY-V1"
#define SWV5S5_REQUEST_BINDING_POLICY_VERSION 1
#define SWV5S5_PERMIT_POLICY_ID "SWV5-SPRINT5-SUBMISSION-PERMIT-POLICY-V1"
#define SWV5S5_PERMIT_POLICY_VERSION 1
#define SWV5S5_PUBLICATION_POLICY_ID "SWV5-SPRINT5-FENCED-PUBLICATION-POLICY-V1"
#define SWV5S5_PUBLICATION_POLICY_VERSION 1

#define SWV5S5_DOMAIN_INGRESS_ID "SWV5-SPRINT5-INGRESS-ID-V1"
#define SWV5S5_DOMAIN_INGRESS_PAYLOAD "SWV5-SPRINT5-INGRESS-PAYLOAD-V1"
#define SWV5S5_DOMAIN_PRODUCER_TRUST "SWV5-SPRINT5-PRODUCER-TRUST-V1"
#define SWV5S5_DOMAIN_INGRESS_LEDGER "SWV5-SPRINT5-INGRESS-LEDGER-V1"
#define SWV5S5_DOMAIN_REQUEST_BINDING "SWV5-SPRINT5-REQUEST-BINDING-V1"
#define SWV5S5_DOMAIN_ATTEMPT "SWV5-SPRINT5-ATTEMPT-V1"
#define SWV5S5_DOMAIN_IDEMPOTENCY "SWV5-SPRINT5-IDEMPOTENCY-V1"
#define SWV5S5_DOMAIN_REQUEST_SEQUENCE "SWV5-SPRINT5-REQUEST-SEQUENCE-AUTHORITY-V1"
#define SWV5S5_DOMAIN_PERMIT_ID "SWV5-SPRINT5-PERMIT-ID-V1"
#define SWV5S5_DOMAIN_SUBMISSION_PERMIT "SWV5-SPRINT5-SUBMISSION-PERMIT-V1"
#define SWV5S5_DOMAIN_REQUEST_SET_PUBLICATION "SWV5-SPRINT5-REQUEST-SET-PUBLICATION-V1"
#define SWV5S5_DOMAIN_CHECKPOINT_PUBLICATION "SWV5-SPRINT5-CHECKPOINT-PUBLICATION-V1"
#define SWV5S5_DOMAIN_ADMISSION_SNAPSHOT "SWV5-SPRINT5-ADMISSION-SNAPSHOT-V1"
#define SWV5S5_DOMAIN_INVOCATION_CLAIM "SWV5-SPRINT5-INVOCATION-CLAIM-V1"

enum SWV5S5_ProducerTrustStatus
{
   SWV5S5_TRUST_STATUS_UNDEFINED=0,
   SWV5S5_TRUST_AUTHORIZED=1,
   SWV5S5_TRUST_SUSPENDED=2,
   SWV5S5_TRUST_SUPERSEDED=3,
   SWV5S5_TRUST_REVOKED=4
};

enum SWV5S5_IngressLifecycleState
{
   SWV5S5_INGRESS_STATE_UNDEFINED=0,
   SWV5S5_REJECTED_NO_ENTRY=1,
   SWV5S5_ACCEPTED_REQUEST_PENDING=2,
   SWV5S5_BOUND_TO_REQUEST=3,
   SWV5S5_TERMINALLY_PROCESSED=4,
   SWV5S5_TERMINALLY_BLOCKED_TRUST_REVOKED=5
};

enum SWV5S5_IngressEvaluationDisposition
{
   SWV5S5_INGRESS_EVALUATION_INVALID=0,
   SWV5S5_INGRESS_EVALUATION_NEW=1,
   SWV5S5_INGRESS_EVALUATION_DUPLICATE=2,
   SWV5S5_INGRESS_EVALUATION_REPLAY_RESOLVED=3,
   SWV5S5_INGRESS_EVALUATION_CONFLICT=4,
   SWV5S5_INGRESS_EVALUATION_NO_ENTRY=5,
   SWV5S5_INGRESS_EVALUATION_DENIED=6
};

enum SWV5S5_TrustContinuityDisposition
{
   SWV5S5_TRUST_CONTINUITY_INVALID=0,
   SWV5S5_TRUST_BLOCK_BEFORE_REQUEST=1,
   SWV5S5_TRUST_BLOCK_BEFORE_PERMIT=2,
   SWV5S5_TRUST_BLOCK_BEFORE_P=3,
   SWV5S5_TRUST_CURRENT_RETAINED_LATER_BLOCKED=4,
   SWV5S5_TRUST_CLAIM_TIME_EXPIRED=5,
   SWV5S5_TRUST_POST_CLAIM_RECONCILE=6
};

enum SWV5S5_RequestSequenceDisposition
{
   SWV5S5_SEQUENCE_INVALID=0,
   SWV5S5_SEQUENCE_PROPOSAL_VALID=1,
   SWV5S5_SEQUENCE_RESERVED_NEW=2,
   SWV5S5_SEQUENCE_EXISTING_IDEMPOTENT=3,
   SWV5S5_SEQUENCE_STALE_REVISION=4,
   SWV5S5_SEQUENCE_STALE_OWNER=5,
   SWV5S5_SEQUENCE_CONFLICT=6
};

enum SWV5S5_PublicationDisposition
{
   SWV5S5_PUBLICATION_INVALID=0,
   SWV5S5_PUBLICATION_PROPOSAL_VALID=1,
   SWV5S5_PUBLICATION_COMMITTED=2,
   SWV5S5_PUBLICATION_STALE_REVISION=3,
   SWV5S5_PUBLICATION_STALE_OWNER=4,
   SWV5S5_PUBLICATION_INTEGRITY_FAILURE=5,
   SWV5S5_PUBLICATION_CONFLICT=6
};

enum SWV5S5_SubmissionAuthorityState
{
   SWV5S5_SUBMISSION_STATE_UNDEFINED=0,
   SWV5S5_COMMITTED_NOT_INVOKED=1,
   SWV5S5_INVOCATION_CLAIMED_UNRESOLVED=2,
   SWV5S5_AUTHORITATIVE_SIDE_EFFECT_CONFIRMED=3,
   SWV5S5_AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED=4,
   SWV5S5_AUTHORITATIVE_REJECTED=5,
   SWV5S5_INVALIDATED_BEFORE_CLAIM=6,
   SWV5S5_CONFLICT_MANUAL_REQUIRED=7
};

enum SWV5S5_ClaimDisposition
{
   SWV5S5_CLAIM_INVALID=0,
   SWV5S5_CLAIM_TRANSITION_ELIGIBLE=1,
   SWV5S5_CLAIM_GRANTED_NOW=2,
   SWV5S5_CLAIM_ALREADY_CLAIMED=3,
   SWV5S5_CLAIM_EXPIRED=4,
   SWV5S5_CLAIM_STALE_OWNER=5,
   SWV5S5_CLAIM_CONFLICT=6,
   SWV5S5_CLAIM_SNAPSHOT_MISMATCH=7,
   SWV5S5_CLAIM_PERMIT_MISMATCH=8,
   SWV5S5_CLAIM_TIME_INVALID=9
};

enum SWV5S5_PermitDisposition
{
   SWV5S5_PERMIT_INVALID=0,
   SWV5S5_PERMIT_PROPOSAL_VALID=1,
   SWV5S5_PERMIT_COMMITTED=2,
   SWV5S5_PERMIT_EXISTING_IDENTICAL=3,
   SWV5S5_PERMIT_CONFLICT=4,
   SWV5S5_PERMIT_STALE_OWNER=5,
   SWV5S5_PERMIT_STALE_REVISION=6,
   SWV5S5_PERMIT_LOGICAL_REQUEST_UNRESOLVED=7
};

enum SWV5S5_StableAuthorityKind
{
   SWV5S5_AUTHORITY_UNDEFINED=0,
   SWV5S5_AUTHORITY_OWNERSHIP=1,
   SWV5S5_AUTHORITY_LEASE_LIVENESS=2,
   SWV5S5_AUTHORITY_PRODUCER_TRUST=3,
   SWV5S5_AUTHORITY_HARD_KILL=4,
   SWV5S5_AUTHORITY_ACCOUNT_MODE=5,
   SWV5S5_AUTHORITY_BASKET=6,
   SWV5S5_AUTHORITY_REQUEST_SET=7,
   SWV5S5_AUTHORITY_SYMBOL_SPECIFICATION=8,
   SWV5S5_AUTHORITY_MARGIN=9,
   SWV5S5_AUTHORITY_BASKET_RISK=10,
   SWV5S5_AUTHORITY_RISK_AUTHORIZATION=11,
   SWV5S5_AUTHORITY_NORMALIZED_PAYLOAD=12,
   SWV5S5_AUTHORITY_SUBMISSION_PERMIT=13,
   SWV5S5_AUTHORITY_VALIDATION_CLOCK=14,
   SWV5S5_AUTHORITY_POLICY_FORMAT=15
};

enum SWV5S5_StableCollectDisposition
{
   SWV5S5_COLLECT_INVALID=0,
   SWV5S5_COLLECT_STABLE_PROVISIONAL=1,
   SWV5S5_COLLECT_RETRYABLE_UNSTABLE=2,
   SWV5S5_COLLECT_FAIL_CLOSED=3,
   SWV5S5_COLLECT_EXPIRED=4,
   SWV5S5_COLLECT_SCOPE_MISMATCH=5,
   SWV5S5_COLLECT_CLOCK_REGRESSION=6
};

enum SWV5S5_AdmissionOperationState
{
   SWV5S5_ADMISSION_NOT_STARTED=0,
   SWV5S5_ADMISSION_COLLECTION_STARTED=1,
   SWV5S5_ADMISSION_PROVISIONAL_P_AVAILABLE=2,
   SWV5S5_ADMISSION_VALIDATION_FAILED=3,
   SWV5S5_ADMISSION_CLAIM_TIME_FAILED=4,
   SWV5S5_ADMISSION_CLAIM_LOST=5,
   SWV5S5_ADMISSION_CLAIM_COMPLETED=6,
   SWV5S5_ADMISSION_COMPLETED=7,
   SWV5S5_ADMISSION_ABORTED=8
};

enum SWV5S5_AuthorityMutationTiming
{
   SWV5S5_MUTATION_TIMING_INVALID=0,
   SWV5S5_MUTATION_BEFORE_P=1,
   SWV5S5_MUTATION_AFTER_P_BEFORE_CLAIM=2,
   SWV5S5_MUTATION_AFTER_CLAIM=3
};

enum SWV5S5_MutationDisposition
{
   SWV5S5_MUTATION_DISPOSITION_INVALID=0,
   SWV5S5_MUTATION_BLOCK_CURRENT=1,
   SWV5S5_MUTATION_UNSTABLE_RECOLLECT=2,
   SWV5S5_MUTATION_CURRENT_RETAINED_LATER_BLOCKED=3,
   SWV5S5_MUTATION_POST_CLAIM_RECONCILE=4,
   SWV5S5_MUTATION_LATER_STATE_ONLY=5
};

enum SWV5S5_OrchestrationEventKind
{
   SWV5S5_EVENT_UNDEFINED=0,
   SWV5S5_EVENT_INGRESS_VALIDATION=1,
   SWV5S5_EVENT_REQUEST_BINDING_PROPOSAL=2,
   SWV5S5_EVENT_PERMIT_PROPOSAL=3,
   SWV5S5_EVENT_ADMISSION_SNAPSHOT_EVALUATION=4,
   SWV5S5_EVENT_INVOCATION_CLAIM_PROPOSAL=5,
   SWV5S5_EVENT_FENCED_PUBLICATION_PROPOSAL=6
};

struct SWV5S5_ValidationResult
{
   SWV5_ContractVersion contract_version;
   SWV5_ContractDisposition disposition;
   string reason_code;
   string reason_text;
   ulong evaluation_sequence;
   datetime evaluated_at;
};

void SWV5S5_InitContractVersion(SWV5_ContractVersion &version)
{
   ZeroMemory(version);
   version.contract_name=SWV5S5_CONTRACT_NAME;
   version.schema_version=SWV5S5_SCHEMA_VERSION;
   version.minimum_compatible_version=SWV5S5_MINIMUM_COMPATIBLE_VERSION;
   version.policy_id=SWV5S5_POLICY_ID;
}

void SWV5S5_Deny(const SWV5_ContractValidationContext &context,
                 const string reason_code,
                 const string reason_text,
                 SWV5S5_ValidationResult &result)
{
   ZeroMemory(result);
   SWV5S5_InitContractVersion(result.contract_version);
   result.disposition=SWV5_DISPOSITION_DENY;
   result.reason_code=reason_code;
   result.reason_text=reason_text;
   result.evaluation_sequence=context.evaluation_sequence;
   result.evaluated_at=context.clock_time;
}

void SWV5S5_Allow(const SWV5_ContractValidationContext &context,
                  const string reason_code,
                  SWV5S5_ValidationResult &result)
{
   ZeroMemory(result);
   SWV5S5_InitContractVersion(result.contract_version);
   result.disposition=SWV5_DISPOSITION_ALLOW;
   result.reason_code=reason_code;
   result.reason_text="";
   result.evaluation_sequence=context.evaluation_sequence;
   result.evaluated_at=context.clock_time;
}

bool SWV5S5_IsCandidateVersion(const SWV5_ContractVersion &version)
{
   return version.contract_name==SWV5S5_CONTRACT_NAME &&
          version.schema_version==SWV5S5_SCHEMA_VERSION &&
          version.minimum_compatible_version==SWV5S5_MINIMUM_COMPATIBLE_VERSION &&
          version.policy_id==SWV5S5_POLICY_ID;
}

bool SWV5S5_IsV5Version(const SWV5_ContractVersion &version)
{
   return version.contract_name==SWV5_PRODUCTION_CONTRACT_NAME &&
          version.schema_version==SWV5_PRODUCTION_CONTRACT_VERSION &&
          version.minimum_compatible_version==SWV5_PRODUCTION_MINIMUM_COMPATIBLE_VERSION &&
          version.policy_id==SWV5_PRODUCTION_CONTRACT_POLICY;
}

bool SWV5S5_IsValidationContextUsable(const SWV5_ContractValidationContext &context)
{
   return context.clock_id!="" && context.clock_authority!=SWV5_TIME_AUTHORITY_NONE &&
          context.clock_time>0 && context.clock_sequence>0 &&
          context.evaluation_sequence>0 &&
          SWV5_IsFiniteNumber(context.price_tolerance) && context.price_tolerance>=0.0 &&
          SWV5_IsFiniteNumber(context.volume_tolerance) && context.volume_tolerance>=0.0;
}

bool SWV5S5_EqualContractVersion(const SWV5_ContractVersion &a,const SWV5_ContractVersion &b)
{
   return a.contract_name==b.contract_name && a.schema_version==b.schema_version &&
          a.minimum_compatible_version==b.minimum_compatible_version && a.policy_id==b.policy_id;
}

bool SWV5S5_EqualOwnershipKey(const SWV5_OwnershipKey &a,const SWV5_OwnershipKey &b)
{
   return a.account_login==b.account_login && a.broker_identity==b.broker_identity &&
          a.server==b.server && a.symbol==b.symbol && a.strategy_id==b.strategy_id && a.magic==b.magic;
}

bool SWV5S5_EqualOwner(const SWV5_OwnerIdentity &a,const SWV5_OwnerIdentity &b)
{
   return SWV5S5_EqualOwnershipKey(a.key,b.key) && a.instance_id==b.instance_id &&
          a.process_fingerprint==b.process_fingerprint && a.started_at==b.started_at;
}

bool SWV5S5_EqualFence(const SWV5_OwnershipFence &a,const SWV5_OwnershipFence &b)
{
   return SWV5S5_EqualContractVersion(a.contract_version,b.contract_version) &&
          SWV5S5_EqualOwnershipKey(a.ownership_namespace,b.ownership_namespace) &&
          SWV5S5_EqualOwner(a.owner,b.owner) && a.lease_version==b.lease_version &&
          a.takeover_generation==b.takeover_generation &&
          a.fencing_token_digest==b.fencing_token_digest;
}

bool SWV5S5_EqualNamespace(const SWV5_PersistenceNamespace &a,const SWV5_PersistenceNamespace &b)
{
   return SWV5S5_EqualContractVersion(a.contract_version,b.contract_version) &&
          SWV5S5_EqualOwnershipKey(a.ownership_namespace,b.ownership_namespace) &&
          a.basket_id.value==b.basket_id.value;
}

bool SWV5S5_EqualRequestIdentity(const SWV5_ExecutionRequestIdentity &a,
                                 const SWV5_ExecutionRequestIdentity &b)
{
   return SWV5S5_EqualContractVersion(a.contract_version,b.contract_version) &&
          a.request_id.correlation_id==b.request_id.correlation_id &&
          a.request_id.attempt_id==b.request_id.attempt_id &&
          a.request_id.parent_attempt_id==b.request_id.parent_attempt_id &&
          a.request_id.monotonic_sequence==b.request_id.monotonic_sequence &&
          a.request_id.created_at==b.request_id.created_at &&
          a.idempotency_key==b.idempotency_key;
}

bool SWV5S5_IsDigest64Lower(const string value)
{
   if(StringLen(value)!=64) return false;
   for(int i=0;i<64;i++)
   {
      ushort c=StringGetCharacter(value,i);
      if(!((c>=48 && c<=57) || (c>=97 && c<=102))) return false;
   }
   return true;
}

#endif
