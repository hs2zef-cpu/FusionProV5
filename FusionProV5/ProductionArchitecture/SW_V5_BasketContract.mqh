#ifndef SW_V5_BASKET_CONTRACT_MQH
#define SW_V5_BASKET_CONTRACT_MQH

#include "SW_V5_BasketStateContract.mqh"

enum SWV5_CloseVerificationState
{
   SWV5_CLOSE_NOT_REQUESTED = 0,
   SWV5_CLOSE_REQUESTED = 1,
   SWV5_CLOSE_PARTIAL = 2,
   SWV5_CLOSE_ZERO_RESIDUAL_CONFIRMED = 3,
   SWV5_CLOSE_RESIDUAL_DETECTED = 4,
   SWV5_CLOSE_VERIFICATION_CONFLICT = 5
};

struct SWV5_BasketAggregate
{
   SWV5_ContractVersion         contract_version;
   SWV5_PersistenceNamespace    persistence_namespace;
   SWV5_AccountPositionMode     account_mode;
   SWV5_BasketLifecycleSnapshot lifecycle;
   double                       initial_volume;
   double                       aggregate_closed_volume;
   SWV5_CloseVerificationState  close_verification;
   datetime                     opened_at;
   datetime                     updated_at;
};

struct SWV5_PartialCloseEvidence
{
   SWV5_ContractVersion contract_version;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_OwnershipFence ownership_fence;
   SWV5_ExecutionCorrelation correlation;
   double        volume_before;
   double        closed_volume;
   double        residual_volume;
   datetime      confirmed_at;
   SWV5_AuthoritySource authority;
};

struct SWV5_CloseVerificationEvidence
{
   SWV5_ContractVersion        contract_version;
   SWV5_PersistenceNamespace   persistence_namespace;
   SWV5_OwnershipFence         ownership_fence;
   SWV5_CloseVerificationState state;
   double                      broker_residual_volume;
   uint                        broker_position_count;
   uint                        broker_order_count;
   uint                        pending_request_count;
   SWV5_AuthoritativeQuerySet  broker_queries;
   datetime                    verified_at;
   SWV5_AuthoritySource        authority;
};

struct SWV5_BasketValidationResult
{
   SWV5_ContractVersion      contract_version;
   SWV5_ContractDecision      decision;
   SWV5_BasketInvariantReport lifecycle_invariants;
};

class ISWV5BasketContract
{
public:
   virtual string ContractName() = 0;
   virtual bool ValidateAggregate(const SWV5_ContractValidationContext &context,
                                  const SWV5_BasketAggregate &basket,
                                  SWV5_BasketValidationResult &result) = 0;
   virtual bool ValidatePartialClose(const SWV5_ContractValidationContext &context,
                                     const SWV5_BasketAggregate &basket,
                                     const SWV5_PartialCloseEvidence &evidence,
                                     SWV5_ContractDecision &decision) = 0;
   virtual bool ValidateCloseCompletion(const SWV5_ContractValidationContext &context,
                                        const SWV5_BasketAggregate &basket,
                                        const SWV5_CloseVerificationEvidence &evidence,
                                        SWV5_ContractDecision &decision) = 0;
};

#endif
