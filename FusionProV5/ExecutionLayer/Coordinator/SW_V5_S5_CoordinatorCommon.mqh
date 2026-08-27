#ifndef SW_V5_S5_COORDINATOR_COMMON_MQH
#define SW_V5_S5_COORDINATOR_COMMON_MQH

// SPRINT 5 PHASE C CANDIDATE
// DETERMINISTIC ORCHESTRATION ONLY / NO BROKER, STORE, CLOCK, OR DOMAIN AUTHORITY

#include "../Contracts/SW_V5_S5_Contracts.mqh"

#define SWV5S5_COORDINATOR_POLICY_ID "SWV5-SPRINT5-PHASE-C-COORDINATOR-V1"

enum SWV5S5_CoordinatorEventKind
{
   SWV5S5_COORD_EVENT_UNDEFINED=0,
   SWV5S5_COORD_EVENT_ACCEPTED_INGRESS=1,
   SWV5S5_COORD_EVENT_REQUEST_PROGRESSION=2,
   SWV5S5_COORD_EVENT_SUBMISSION_ADMISSION=3,
   SWV5S5_COORD_EVENT_OWNERSHIP_TAKEOVER=4,
   SWV5S5_COORD_EVENT_FAKE_BROKER_RESPONSE=5,
   SWV5S5_COORD_EVENT_RECONCILIATION_REQUIRED=6
};

enum SWV5S5_CoordinatorInterruptionPoint
{
   SWV5S5_COORD_INTERRUPT_NONE=0,
   SWV5S5_COORD_INTERRUPT_BEFORE_CLAIM=1,
   SWV5S5_COORD_INTERRUPT_AFTER_CLAIM_BEFORE_BROKER=2
};

enum SWV5S5_CoordinatorDisposition
{
   SWV5S5_COORD_INVALID=0,
   SWV5S5_COORD_NO_ENTRY=1,
   SWV5S5_COORD_REQUEST_NOMINATED=2,
   SWV5S5_COORD_ADMISSION_DENIED=3,
   SWV5S5_COORD_CLAIM_DENIED=4,
   SWV5S5_COORD_STALE_OWNER=5,
   SWV5S5_COORD_ALREADY_CLAIMED_UNCERTAIN=6,
   SWV5S5_COORD_INTERRUPTED_RECOLLECT=7,
   SWV5S5_COORD_CLAIMED_RECONCILIATION_REQUIRED=8,
   SWV5S5_COORD_FAKE_BROKER_INVOKED=9,
   SWV5S5_COORD_FAKE_BROKER_REJECTED=10,
   SWV5S5_COORD_FAKE_BROKER_UNCERTAIN=11,
   SWV5S5_COORD_LEDGER_ACCEPTED_NEW=12,
   SWV5S5_COORD_LEDGER_DUPLICATE=13,
   SWV5S5_COORD_REQUEST_MATERIALIZED=14,
   SWV5S5_COORD_REQUEST_SUBMISSION_READY=15,
   SWV5S5_COORD_TAKEOVER_RECONCILIATION=16,
   SWV5S5_COORD_BROKER_ACKNOWLEDGED=17
};

enum SWV5S5_CoordinatorTraceStep
{
   SWV5S5_COORD_TRACE_EVENT_RECEIVED=1,
   SWV5S5_COORD_TRACE_INGRESS_VALIDATED=2,
   SWV5S5_COORD_TRACE_REQUEST_BOUND=3,
   SWV5S5_COORD_TRACE_ADMISSION_PREPARED=4,
   SWV5S5_COORD_TRACE_CLAIM_ATTEMPTED=5,
   SWV5S5_COORD_TRACE_CLAIM_GRANTED_CURRENT_EVENT=6,
   SWV5S5_COORD_TRACE_FAKE_BROKER_INVOKED=7,
   SWV5S5_COORD_TRACE_RECONCILIATION_REQUIRED=8,
   SWV5S5_COORD_TRACE_COMPLETED=9
};

enum SWV5S5_FakeBrokerOutcomeKind
{
   SWV5S5_FAKE_BROKER_OUTCOME_UNDEFINED=0,
   SWV5S5_FAKE_BROKER_REQUEST_RECEIVED=1,
   SWV5S5_FAKE_BROKER_REJECTED=2,
   SWV5S5_FAKE_BROKER_NO_AUTHORITATIVE_CONFIRMATION=3
};

struct SWV5S5_CoordinatorAdmissionEvent
{
   string event_id;
   ulong event_ordinal;
   string request_correlation_id;
   string attempt_id;
   string normalized_payload_identity;
   SWV5_PendingRequestState request_state;
   SWV5_ExecutionLifecyclePhase request_phase;
   SWV5S5_CoordinatorInterruptionPoint interruption_point;
   // Fixture/source input only. It is never submitted directly to Claim.
   SWV5S5_InvocationClaimCommand preparation_seed;
};

struct SWV5S5_CoordinatorPreparedAdmission
{
   string event_id;
   ulong event_ordinal;
   string operation_token;
   SWV5S5_InvocationClaimCommand claim_command;
   SWV5S5_InvocationClaimTransition transition;
};

struct SWV5S5_CoordinatorClaimOperationResult
{
   string event_id;
   ulong event_ordinal;
   string operation_token;
   SWV5S5_InvocationClaimResult claim;
};

struct SWV5S5_CoordinatorLedgerEvaluation
{
   SWV5S5_IngressEvaluationDisposition disposition;
   SWV5S5_IngressLedgerHeader header;
   SWV5S5_IngressLedgerRecord matched_record;
   int matched_index;
   string reason_code;
};

struct SWV5S5_CoordinatorLedgerOperationResult
{
   string event_id;
   ulong event_ordinal;
   string proposal_digest;
   SWV5S5_ValidationResult authoritative_result;
};

struct SWV5S5_CoordinatorSequenceOperationResult
{
   string event_id;
   ulong event_ordinal;
   string reservation_digest;
   SWV5S5_RequestSequenceResult authoritative_result;
};

struct SWV5S5_CoordinatorMaterializationInput
{
   string event_id;
   ulong event_ordinal;
   SWV5_ContractValidationContext context;
   SWV5S5_IngressEnvelope accepted_ingress;
   SWV5S5_CoordinatorLedgerEvaluation ledger;
   SWV5_NormalizedUnits normalized_payload;
   string normalization_identity;
   SWV5_RiskAuthorization risk_authorization;
};

struct SWV5S5_CoordinatorMaterializationResult
{
   SWV5S5_RequestSequenceResult sequence;
   SWV5S5_RequestBinding binding;
   SWV5S5_InitialRequestBlueprint blueprint;
   SWV5_PendingRequest progressed_request;
   SWV5S5_CoordinatorDisposition disposition;
   string reason_code;
};

struct SWV5S5_CoordinatorIngressEvent
{
   string event_id;
   ulong event_ordinal;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_ContractValidationContext context;
   SWV5S5_IngressEnvelope ingress;
   SWV5S5_IngressFreshnessPolicy freshness;
   SWV5S5_ProducerTrustRecord current_trust;
   SWV5S5_ProducerTrustAnchor trust_anchor;
   SWV5S5_ProducerTrustScope trust_scope;
};

struct SWV5S5_FakeBrokerInvocation
{
   string event_id;
   ulong event_ordinal;
   ulong event_local_invocation_sequence;
   string request_correlation_id;
   string attempt_id;
   string normalized_payload_identity;
   string claim_id;
   int direction;
};

struct SWV5S5_FakeBrokerResult
{
   SWV5S5_FakeBrokerOutcomeKind outcome;
   string scripted_code;
};

struct SWV5S5_CoordinatorTraceEntry
{
   string event_id;
   ulong event_ordinal;
   SWV5S5_CoordinatorTraceStep step;
   string request_correlation_id;
   string attempt_id;
   int domain_disposition;
   bool claim_granted_in_current_event;
   bool fake_broker_invoked;
   SWV5S5_CoordinatorDisposition final_disposition;
};

struct SWV5S5_CoordinatorResult
{
   SWV5S5_CoordinatorDisposition disposition;
   string event_id;
   ulong event_ordinal;
   string request_correlation_id;
   string attempt_id;
   bool claim_granted_in_current_event;
   bool fake_broker_invoked;
   bool reconciliation_required;
   string reason_code;
};

class ISWV5S5CoordinatorAdmissionPreparation
{
public:
   // The implementation owns V1/V2 collection and Phase B preparation. Returned
   // transition is a complete owner result; the coordinator never reconstructs it.
   virtual bool PrepareSameEvent(const SWV5S5_CoordinatorAdmissionEvent &event,
                                 SWV5S5_CoordinatorPreparedAdmission &prepared)=0;
};

class ISWV5S5CoordinatorInvocationClaimAuthority
{
public:
   // Adapter boundary over frozen Invocation Claim authority. The operation
   // binding makes an ephemeral result non-transferable between host events.
   virtual bool TryClaimInvocation(const SWV5S5_InvocationClaimCommand &command,
                                   const string event_id,const ulong event_ordinal,
                                   const string operation_token,
                                   SWV5S5_CoordinatorClaimOperationResult &result)=0;
};

class ISWV5S5CoordinatorLedgerAuthority
{
public:
   // Explicit adapter over the frozen Ledger owner operation. Snapshot arrays
   // are complete and ordered; the coordinator independently validates them.
   virtual bool ReadSnapshot(const string event_id,const ulong event_ordinal,
                             SWV5S5_IngressLedgerHeader &header,
                             SWV5S5_IngressLedgerIndexEntry &entries[],
                             SWV5S5_IngressLedgerRecord &records[])=0;
   virtual bool TryCommitAcceptance(const SWV5S5_IngressLedgerHeader &expected_header,
                                    const SWV5S5_IngressLedgerIndexEntry &expected_entries[],
                                    const SWV5S5_IngressLedgerRecord &expected_records[],
                                    const SWV5S5_IngressLedgerProposal &proposal,
                                    const string event_id,const ulong event_ordinal,
                                    SWV5S5_CoordinatorLedgerOperationResult &result)=0;
};

class ISWV5S5CoordinatorRequestSequenceAuthority
{
public:
   // Explicit adapter over the frozen Request Sequence owner operation.
   virtual bool ReadState(const string event_id,const ulong event_ordinal,
                          SWV5S5_RequestSequenceAuthority &authority,
                          SWV5S5_RequestSequenceIndexEntry &entries[])=0;
   virtual bool TryReserveRequestSequence(const SWV5S5_RequestSequenceAuthority &expected,
                                          const SWV5S5_RequestSequenceIndexEntry &expected_entries[],
                                          const SWV5S5_RequestSequenceReservation &proposal,
                                          const string event_id,const ulong event_ordinal,
                                          SWV5S5_CoordinatorSequenceOperationResult &result)=0;
};

class ISWV5S5CoordinatorBlueprintAuthority
{
public:
   virtual bool BuildInitial(const SWV5S5_CoordinatorMaterializationInput &materialization,
                             const SWV5S5_RequestBinding &binding,
                             SWV5S5_InitialRequestBlueprint &blueprint)=0;
};

class ISWV5S5CoordinatorRequestProgressionAuthority
{
public:
   virtual bool ProgressToSubmission(const SWV5_PendingRequest &created,
                                     SWV5_PendingRequest &progressed)=0;
};

class ISWV5S5CoordinatorOwnershipAuthority
{
public:
   virtual bool EvaluateTakeover(const string request_correlation_id,
                                 SWV5S5_CoordinatorDisposition &disposition)=0;
};

class ISWV5S5CoordinatorFakeBrokerPort
{
public:
   // Phase C test boundary only. A real platform adapter is explicitly forbidden.
   virtual bool InvokeFake(const SWV5S5_FakeBrokerInvocation &invocation,
                           SWV5S5_FakeBrokerResult &result)=0;
};

class ISWV5S5CoordinatorTraceSink
{
public:
   // Diagnostic only: implementations must never use a trace as authority.
   virtual void Append(const SWV5S5_CoordinatorTraceEntry &entry)=0;
};

#endif
