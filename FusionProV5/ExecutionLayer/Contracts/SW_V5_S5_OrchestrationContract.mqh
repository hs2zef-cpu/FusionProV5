#ifndef SW_V5_S5_ORCHESTRATION_CONTRACT_MQH
#define SW_V5_S5_ORCHESTRATION_CONTRACT_MQH

// SPRINT 5 PHASE B CANDIDATE CONTRACT
// IMMUTABLE EVENT/RESULT INTERFACES ONLY / NO DISPATCHER, QUEUE, TIMER, OR CALLBACK

#include "SW_V5_S5_AdmissionContract.mqh"

struct SWV5S5_OrchestrationEvent
{
   SWV5_ContractVersion contract_version;
   SWV5S5_OrchestrationEventKind kind;
   string event_id;
   SWV5_PersistenceNamespace persistence_namespace;
   string subject_identity;
   ulong event_sequence;
   datetime event_time;
   string payload_digest;
};

struct SWV5S5_OrchestrationResult
{
   SWV5_ContractVersion contract_version;
   string event_id;
   SWV5_ContractDisposition disposition;
   string proposal_identity;
   string reason_code;
   string result_digest;
};

class ISWV5S5PureOrchestrationContract
{
public:
   virtual bool ValidateIngressEvent(const SWV5_ContractValidationContext &context,
                                     const SWV5S5_OrchestrationEvent &event,
                                     SWV5S5_OrchestrationResult &result)=0;
   virtual bool ProposeRequestBinding(const SWV5S5_OrchestrationEvent &event,
                                      const SWV5S5_InitialRequestBlueprint &blueprint,
                                      SWV5S5_OrchestrationResult &result)=0;
   virtual bool ProposePermit(const SWV5S5_OrchestrationEvent &event,
                              const SWV5S5_SubmissionPermit &permit,
                              SWV5S5_OrchestrationResult &result)=0;
   virtual bool EvaluateAdmissionSnapshot(const SWV5S5_OrchestrationEvent &event,
                                           const SWV5S5_DoubleCollectResult &snapshot_result,
                                           const SWV5S5_AdmissionProof &admission_proof,
                                           SWV5S5_OrchestrationResult &result)=0;
   virtual bool ProposeInvocationClaim(const SWV5S5_OrchestrationEvent &event,
                                       const SWV5S5_InvocationClaimCommand &claim,
                                       SWV5S5_OrchestrationResult &result)=0;
   virtual bool ProposeRequestSetPublication(const SWV5S5_OrchestrationEvent &event,
                                             const SWV5S5_RequestSetPublicationProposal &proposal,
                                             SWV5S5_OrchestrationResult &result)=0;
   virtual bool ProposeCheckpointPublication(const SWV5S5_OrchestrationEvent &event,
                                             const SWV5S5_CheckpointPublicationProposal &proposal,
                                             SWV5S5_OrchestrationResult &result)=0;
};

#endif
