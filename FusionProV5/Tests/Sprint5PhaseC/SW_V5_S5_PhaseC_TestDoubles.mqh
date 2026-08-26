#ifndef SW_V5_S5_PHASE_C_TEST_DOUBLES_MQH
#define SW_V5_S5_PHASE_C_TEST_DOUBLES_MQH

// TEST ONLY / NON-PRODUCTION / NO BROKER ACCESS
// Deterministic in-memory doubles. They provide no durability or atomicity proof.

#include "../../ExecutionLayer/Coordinator/SW_V5_S5_Coordinator.mqh"
#include "../Sprint5PhaseB/SW_V5_S5_PhaseB_Assertions.mqh"

class SWV5S5_ScriptedAdmissionPreparation : public ISWV5S5CoordinatorAdmissionPreparation
{
public:
   bool allow;
   bool corrupt_prepared_command;
   int call_count;

   SWV5S5_ScriptedAdmissionPreparation(void) { allow=true; corrupt_prepared_command=false; call_count=0; }

   virtual bool PrepareSameEvent(const SWV5S5_CoordinatorAdmissionEvent &event,
                                 SWV5S5_CoordinatorPreparedAdmission &prepared)
   {
      call_count++;
      ZeroMemory(prepared);
      if(!allow) return false;
      prepared.event_id=event.event_id;
      prepared.event_ordinal=event.event_ordinal;
      prepared.operation_token=event.event_id+"|"+(string)event.event_ordinal+"|"+event.preparation_seed.command_digest;
      prepared.claim_command=event.preparation_seed;
      SWV5_ContractValidationContext context;
      SWV5S5_TestContext(context,event.preparation_seed.claim_clock.observed_at,
                         event.preparation_seed.claim_clock.clock_sequence);
      bool ok=SWV5S5_PrepareInvocationClaimTransition(context,SWV5S5_TEST_RISK,
                                                       prepared.claim_command,prepared.transition);
      if(ok && corrupt_prepared_command)
      {
         prepared.claim_command.expected_authority_revision++;
      }
      return ok;
   }
};

class SWV5S5_ScriptedClaimAuthority : public ISWV5S5CoordinatorInvocationClaimAuthority
{
private:
   bool claimed;
public:
   SWV5S5_ClaimDisposition next_disposition;
   int call_count;
   SWV5S5_InvocationClaimResult scripted_result;
   bool replay_prior_event_binding;

   SWV5S5_ScriptedClaimAuthority(void)
   {
      claimed=false;
      next_disposition=SWV5S5_CLAIM_GRANTED_NOW;
      call_count=0;
      replay_prior_event_binding=false;
      ZeroMemory(scripted_result);
   }

   void ConfigureValid(const SWV5S5_InvocationClaimTransition &transition)
   {
      ZeroMemory(scripted_result); SWV5S5_InitContractVersion(scripted_result.contract_version);
      scripted_result.disposition=SWV5S5_CLAIM_GRANTED_NOW;
      scripted_result.claim_granted_now=true;
      scripted_result.resulting_authority_record=transition.proposed_next_record;
      scripted_result.reason_code="SCRIPTED_COMPLETE_FROZEN_VALID_CLAIM";
   }

   virtual bool TryClaimInvocation(const SWV5S5_InvocationClaimCommand &command,
                                   const string event_id,const ulong event_ordinal,
                                   const string operation_token,
                                   SWV5S5_CoordinatorClaimOperationResult &operation)
   {
      call_count++;
      ZeroMemory(operation);
      operation.event_id=(replay_prior_event_binding ? "PRIOR-EVENT" : event_id);
      operation.event_ordinal=(replay_prior_event_binding ? event_ordinal-1 : event_ordinal);
      operation.operation_token=(replay_prior_event_binding ? "PRIOR-TOKEN" : operation_token);
      SWV5S5_InvocationClaimResult result;
      ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
      if(claimed || next_disposition==SWV5S5_CLAIM_ALREADY_CLAIMED)
      {
         result.disposition=SWV5S5_CLAIM_ALREADY_CLAIMED;
         result.claim_granted_now=false;
         result.resulting_authority_record.state=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED;
         result.reason_code="SCRIPTED_ALREADY_CLAIMED_NO_GRANT";
         operation.claim=result;
         return true;
      }
      if(next_disposition!=SWV5S5_CLAIM_GRANTED_NOW)
      {
         result.disposition=next_disposition;
         result.claim_granted_now=false;
         result.resulting_authority_record.state=SWV5S5_COMMITTED_NOT_INVOKED;
         result.reason_code="SCRIPTED_CLAIM_DENIED";
         operation.claim=result;
         return false;
      }
      claimed=true;
      result=scripted_result;
      operation.claim=result;
      return true;
   }
};

class SWV5S5_ScriptedLedgerAuthority : public ISWV5S5CoordinatorLedgerAuthority
{
public:
   bool duplicate;
   int call_count;
   SWV5S5_CoordinatorLedgerResult scripted;
   SWV5S5_ScriptedLedgerAuthority(void) { duplicate=false; call_count=0; ZeroMemory(scripted); }
   virtual bool AcceptOrDeduplicate(const SWV5S5_CoordinatorIngressEvent &event,
                                    const SWV5S5_IngressValidationResult &validated,
                                    SWV5S5_CoordinatorLedgerResult &result)
   {
      call_count++; result=scripted;
      result.disposition=(duplicate ? SWV5S5_INGRESS_EVALUATION_DUPLICATE : scripted.disposition);
      return true;
   }
};

class SWV5S5_ScriptedRequestSequenceAuthority : public ISWV5S5CoordinatorRequestSequenceAuthority
{
public:
   string existing_correlation;
   ulong reserved_sequence;
   int call_count;
   SWV5S5_ScriptedRequestSequenceAuthority(void) { existing_correlation=""; reserved_sequence=1; call_count=0; }
   virtual bool Reserve(const string correlation,SWV5S5_RequestSequenceResult &result)
   {
      call_count++; ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
      result.logical_correlation_id=correlation; result.reserved_sequence=reserved_sequence;
      result.resulting_allocator_revision=1; result.resulting_authority_digest=SWV5S5_SHA256_ABC;
      result.disposition=(existing_correlation==correlation ? SWV5S5_SEQUENCE_EXISTING_IDEMPOTENT : SWV5S5_SEQUENCE_RESERVED_NEW);
      existing_correlation=correlation; result.reason_code="SCRIPTED_COMPLETE_SEQUENCE_RESULT"; return true;
   }
};

class SWV5S5_ScriptedBlueprintAuthority : public ISWV5S5CoordinatorBlueprintAuthority
{
public:
   SWV5S5_InitialRequestBlueprint scripted;
   virtual bool BuildInitial(const SWV5S5_CoordinatorMaterializationInput &materialization,
                             const SWV5S5_RequestBinding &binding,
                             SWV5S5_InitialRequestBlueprint &blueprint)
   { blueprint=scripted; return true; }
};

class SWV5S5_ScriptedRequestProgressionAuthority : public ISWV5S5CoordinatorRequestProgressionAuthority
{
public:
   SWV5_PendingRequest scripted;
   virtual bool ProgressToSubmission(const SWV5_PendingRequest &created,SWV5_PendingRequest &progressed)
   { progressed=scripted; return true; }
};

class SWV5S5_ScriptedOwnershipAuthority : public ISWV5S5CoordinatorOwnershipAuthority
{
public:
   SWV5S5_CoordinatorDisposition scripted;
   SWV5S5_ScriptedOwnershipAuthority(void) { scripted=SWV5S5_COORD_TAKEOVER_RECONCILIATION; }
   virtual bool EvaluateTakeover(const string request_correlation_id,SWV5S5_CoordinatorDisposition &result)
   { result=scripted; return true; }
};

class SWV5S5_ScriptedFakeBroker : public ISWV5S5CoordinatorFakeBrokerPort
{
public:
   SWV5S5_FakeBrokerInvocation invocations[];
   SWV5S5_FakeBrokerOutcomeKind next_outcome;

   SWV5S5_ScriptedFakeBroker(void)
   {
      ArrayResize(invocations,0);
      next_outcome=SWV5S5_FAKE_BROKER_REQUEST_RECEIVED;
   }

   virtual bool InvokeFake(const SWV5S5_FakeBrokerInvocation &invocation,
                           SWV5S5_FakeBrokerResult &result)
   {
      int n=ArraySize(invocations);
      ArrayResize(invocations,n+1);
      invocations[n]=invocation;
      result.outcome=next_outcome;
      result.scripted_code="TEST_ONLY_SCRIPTED_OUTCOME";
      return next_outcome!=SWV5S5_FAKE_BROKER_OUTCOME_UNDEFINED;
   }

   int InvocationCount(void) { return ArraySize(invocations); }
};

class SWV5S5_TestTraceSink : public ISWV5S5CoordinatorTraceSink
{
public:
   SWV5S5_CoordinatorTraceEntry entries[];

   SWV5S5_TestTraceSink(void) { ArrayResize(entries,0); }

   virtual void Append(const SWV5S5_CoordinatorTraceEntry &entry)
   {
      int n=ArraySize(entries);
      ArrayResize(entries,n+1);
      entries[n]=entry;
   }

   int Count(void) { return ArraySize(entries); }
};

struct SWV5S5_TestQueueEvent
{
   string event_id;
   ulong ordinal;
   int scenario_code;
};

class SWV5S5_DeterministicInMemoryTestQueue
{
private:
   SWV5S5_TestQueueEvent items[];
   int cursor;
public:
   SWV5S5_DeterministicInMemoryTestQueue(void)
   {
      ArrayResize(items,0);
      cursor=0;
   }

   void Enqueue(const SWV5S5_TestQueueEvent &event)
   {
      int n=ArraySize(items);
      ArrayResize(items,n+1);
      items[n]=event;
   }

   bool TryDequeue(SWV5S5_TestQueueEvent &event)
   {
      if(cursor>=ArraySize(items)) return false;
      event=items[cursor++];
      return true;
   }

   int Pending(void) { return ArraySize(items)-cursor; }
};

class SWV5S5_DeterministicTestDispatcher
{
public:
   // TEST ONLY: queue ordinal selects a handler but grants no domain authority.
   bool Dispatch(SWV5S5_DeterministicCoordinator &coordinator,
                 const SWV5S5_TestQueueEvent &event,
                 SWV5S5_ScriptedOwnershipAuthority &ownership,
                 const SWV5S5_SubmissionAuthorityRecord &claimed_record,
                 SWV5S5_CoordinatorResult &result)
   {
      if(event.scenario_code==SWV5S5_COORD_EVENT_OWNERSHIP_TAKEOVER)
         return coordinator.ProcessTakeover(claimed_record.permit.request_identity.request_id.correlation_id,
                                            ownership,result);
      if(event.scenario_code==SWV5S5_COORD_EVENT_RECONCILIATION_REQUIRED)
         return coordinator.ProcessReconciliationRequired(claimed_record,result);
      if(event.scenario_code==SWV5S5_COORD_EVENT_FAKE_BROKER_RESPONSE)
      {
         SWV5S5_FakeBrokerResult response;
         response.outcome=SWV5S5_FAKE_BROKER_REQUEST_RECEIVED;
         response.scripted_code="QUEUE_SCRIPTED_ACK";
         return coordinator.ProcessFakeBrokerResponse(response,result);
      }
      return false; // typed ingress/admission handlers require their complete fixture DTOs.
   }
};

#endif
