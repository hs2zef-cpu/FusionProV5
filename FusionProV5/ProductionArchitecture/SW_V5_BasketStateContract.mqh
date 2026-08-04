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
   SWV5_TRANSITION_CONTRACT_VIOLATION = 13
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

struct SWV5_BasketLifecycleSnapshot
{
   SWV5_BasketID    basket_id;
   SWV5_BasketState state;
   ulong            state_version;
   ulong            cumulative_recovery_attempts;
   uint             current_recovery_layer;
   double           aggregate_open_volume;
   double           residual_volume;
   uint             pending_request_count;
   bool             owner_confirmed;
   bool             reconciliation_required;
   datetime         state_entered_at;
};

struct SWV5_BasketTransitionRequest
{
   SWV5_BasketID              basket_id;
   SWV5_BasketState           from_state;
   SWV5_BasketState           to_state;
   SWV5_BasketTransitionCause cause;
   ulong                      expected_state_version;
   SWV5_RequestID             request_id;
   datetime                   evidence_time;
   bool                       ownership_confirmed;
   bool                       risk_authorization_valid;
   bool                       broker_state_reconciled;
   double                     residual_volume;
   uint                       pending_request_count;
};

struct SWV5_BasketInvariantReport
{
   SWV5_ContractStatus status;
   ulong               satisfied_flags;
   ulong               violated_flags;
   string              primary_violation;
};

struct SWV5_BasketTransitionDecision
{
   SWV5_ContractDecision     decision;
   SWV5_BasketState          resulting_state;
   ulong                     resulting_state_version;
   SWV5_BasketInvariantReport invariants;
};

class ISWV5BasketStateMachineContract
{
public:
   virtual string ContractName() = 0;
   virtual bool ValidateState(const SWV5_BasketLifecycleSnapshot &snapshot,
                              SWV5_BasketInvariantReport &report) = 0;
   virtual bool ValidateTransition(const SWV5_BasketLifecycleSnapshot &snapshot,
                                   const SWV5_BasketTransitionRequest &request,
                                   SWV5_BasketTransitionDecision &decision) = 0;
};

#endif
