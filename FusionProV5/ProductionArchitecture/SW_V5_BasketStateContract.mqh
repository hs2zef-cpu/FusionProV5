#ifndef SW_V5_BASKET_STATE_CONTRACT_MQH
#define SW_V5_BASKET_STATE_CONTRACT_MQH

#include "SW_V5_ProductionCommon.mqh"

enum SWV5_BasketState
{
   SWV5_BASKET_IDLE = 0,
   SWV5_BASKET_OPENING = 1,
   SWV5_BASKET_ACTIVE = 2,
   SWV5_BASKET_RECOVERY = 3,
   SWV5_BASKET_CLOSING = 4,
   SWV5_BASKET_HALTED = 5,
   SWV5_BASKET_ERROR = 6
};

enum SWV5_BasketTransitionCause
{
   SWV5_TRANSITION_NONE = 0,
   SWV5_TRANSITION_OPEN_AUTHORIZED = 1,
   SWV5_TRANSITION_OPEN_CONFIRMED = 2,
   SWV5_TRANSITION_OPEN_PARTIAL = 3,
   SWV5_TRANSITION_RECOVERY_AUTHORIZED = 4,
   SWV5_TRANSITION_RECOVERY_CONFIRMED = 5,
   SWV5_TRANSITION_CLOSE_AUTHORIZED = 6,
   SWV5_TRANSITION_CLOSE_CONFIRMED_EMPTY = 7,
   SWV5_TRANSITION_HARD_KILL = 8,
   SWV5_TRANSITION_RECONCILIATION_FAILED = 9,
   SWV5_TRANSITION_RECONCILIATION_CONFIRMED = 10,
   SWV5_TRANSITION_OPERATOR_HALT = 11,
   SWV5_TRANSITION_OPERATOR_RESET = 12,
   SWV5_TRANSITION_CONTRACT_VIOLATION = 13,
   SWV5_TRANSITION_OWNERSHIP_LOST = 14,
   SWV5_TRANSITION_BROKER_STATE_UNCERTAIN = 15,
   SWV5_TRANSITION_MANDATORY_RISK_REDUCTION = 16
};

const ulong SWV5_INVARIANT_BASKET_ID_REQUIRED = 1;
const ulong SWV5_INVARIANT_OWNER_REQUIRED = 2;
const ulong SWV5_INVARIANT_VERSION_MONOTONIC = 4;
const ulong SWV5_INVARIANT_IDLE_HAS_NO_EXPOSURE = 8;
const ulong SWV5_INVARIANT_IDLE_HAS_NO_PENDING_REQUEST = 16;
const ulong SWV5_INVARIANT_ACTIVE_HAS_EXPOSURE = 32;
const ulong SWV5_INVARIANT_RECOVERY_ATTEMPT_MONOTONIC = 64;
const ulong SWV5_INVARIANT_CLOSING_FORBIDS_NEW_EXPOSURE = 128;
const ulong SWV5_INVARIANT_HALTED_FORBIDS_NEW_EXPOSURE = 256;
const ulong SWV5_INVARIANT_ERROR_REQUIRES_RECONCILIATION = 512;
const ulong SWV5_INVARIANT_ZERO_RESIDUAL_BEFORE_IDLE = 1024;
const ulong SWV5_INVARIANT_CONFIRMED_TRANSACTION_REQUIRED = 2048;
const ulong SWV5_INVARIANT_ZERO_POSITIONS_BEFORE_IDLE = 4096;
const ulong SWV5_INVARIANT_ZERO_ORDERS_BEFORE_IDLE = 8192;
const ulong SWV5_INVARIANT_BROKER_QUERY_COMPLETE = 16384;
const ulong SWV5_INVARIANT_SAME_STATE_VERSION_STABLE = 32768;

struct SWV5_BasketLifecycleSnapshot
{
   SWV5_ContractVersion contract_version;
   SWV5_BasketID    basket_id;
   SWV5_OwnershipFence ownership_fence;
   SWV5_BasketState state;
   ulong            state_version;
   ulong            cumulative_recovery_attempts;
   uint             current_recovery_layer;
   SWV5_DurableEventIdentitySet accepted_recovery_evidence;
   double           aggregate_open_volume;
   double           residual_volume;
   uint             live_position_count;
   uint             live_order_count;
   uint             pending_request_count;
   SWV5_ReconciliationState reconciliation_state;
   SWV5_AuthoritativeQuerySet broker_queries;
   datetime         state_entered_at;
};

struct SWV5_RecoveryTransitionEvidence
{
   SWV5_ContractVersion         contract_version;
   SWV5_ExecutionRequestIdentity request_identity;
   ulong                        prior_cumulative_recovery_attempts;
   ulong                        proposed_cumulative_recovery_attempts;
   uint                         prior_recovery_layer;
   uint                         proposed_recovery_layer;
   string                       authorization_id;
   string                       evidence_identity;
   ulong                        evidence_sequence;
   datetime                     evidenced_at;
};

struct SWV5_BasketTransitionRequest
{
   SWV5_ContractVersion       contract_version;
   SWV5_BasketID              basket_id;
   SWV5_OwnershipFence        ownership_fence;
   SWV5_BasketState           from_state;
   SWV5_BasketState           to_state;
   SWV5_BasketTransitionCause cause;
   ulong                      expected_state_version;
   SWV5_ExecutionCorrelation  correlation;
   SWV5_RecoveryTransitionEvidence recovery_evidence;
   datetime                   evidence_time;
   SWV5_ContractDecision      risk_decision;
   SWV5_ReconciliationState   reconciliation_state;
   double                     residual_volume;
   uint                       live_position_count;
   uint                       live_order_count;
   uint                       pending_request_count;
   SWV5_AuthoritativeQuerySet broker_queries;
   SWV5_AuthoritySource       confirmation_authority;
};

struct SWV5_BasketInvariantReport
{
   SWV5_ContractVersion contract_version;
   SWV5_ContractStatus status;
   ulong               satisfied_flags;
   ulong               violated_flags;
   string              primary_violation;
};

struct SWV5_BasketTransitionDecision
{
   SWV5_ContractVersion     contract_version;
   SWV5_ContractDecision     decision;
   SWV5_BasketState          resulting_state;
   ulong                     resulting_state_version;
   ulong                     resulting_cumulative_recovery_attempts;
   uint                      resulting_recovery_layer;
   SWV5_DurableEventIdentitySet resulting_accepted_recovery_evidence;
   bool                      recovery_evidence_added;
   bool                      recovery_evidence_duplicate;
   SWV5_BasketInvariantReport invariants;
};

class ISWV5BasketStateMachineContract
{
public:
   virtual string ContractName() = 0;
   virtual bool ValidateState(const SWV5_ContractValidationContext &context,
                              const SWV5_BasketLifecycleSnapshot &snapshot,
                              SWV5_BasketInvariantReport &report) = 0;
   virtual bool ValidateTransition(const SWV5_ContractValidationContext &context,
                                   const SWV5_BasketLifecycleSnapshot &snapshot,
                                   const SWV5_BasketTransitionRequest &request,
                                   SWV5_BasketTransitionDecision &decision) = 0;
};

#endif
