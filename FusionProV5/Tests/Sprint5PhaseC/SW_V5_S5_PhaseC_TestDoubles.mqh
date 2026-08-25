#ifndef SW_V5_S5_PHASE_C_TEST_DOUBLES_MQH
#define SW_V5_S5_PHASE_C_TEST_DOUBLES_MQH

// TEST ONLY / NON-PRODUCTION / NO BROKER ACCESS
// Deterministic in-memory doubles. They provide no durability or atomicity proof.

#include "../../ExecutionLayer/Coordinator/SW_V5_S5_Coordinator.mqh"

class SWV5S5_ScriptedAdmissionPreparation : public ISWV5S5CoordinatorAdmissionPreparation
{
public:
   bool allow;
   int call_count;

   SWV5S5_ScriptedAdmissionPreparation(void) { allow=true; call_count=0; }

   virtual bool PrepareSameEvent(const SWV5S5_CoordinatorAdmissionEvent &event,
                                 SWV5S5_InvocationClaimTransition &prepared)
   {
      call_count++;
      ZeroMemory(prepared);
      SWV5S5_InitContractVersion(prepared.contract_version);
      prepared.disposition=(allow ? SWV5S5_CLAIM_TRANSITION_ELIGIBLE : SWV5S5_CLAIM_INVALID);
      prepared.transition_eligible=allow;
      prepared.proposed_next_record=event.claim_command.expected_authority_record;
      prepared.proposed_next_record.state=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED;
      prepared.reason_code=(allow ? "SCRIPTED_COMPLETE_PHASE_B_PREPARATION" : "SCRIPTED_ADMISSION_DENIED");
      return allow;
   }
};

class SWV5S5_ScriptedClaimAuthority : public ISWV5S5InvocationClaimAuthority
{
private:
   bool claimed;
public:
   SWV5S5_ClaimDisposition next_disposition;
   int call_count;

   SWV5S5_ScriptedClaimAuthority(void)
   {
      claimed=false;
      next_disposition=SWV5S5_CLAIM_GRANTED_NOW;
      call_count=0;
   }

   virtual bool TryClaimInvocation(const SWV5S5_InvocationClaimCommand &command,
                                   SWV5S5_InvocationClaimResult &result)
   {
      call_count++;
      ZeroMemory(result);
      SWV5S5_InitContractVersion(result.contract_version);
      if(claimed || next_disposition==SWV5S5_CLAIM_ALREADY_CLAIMED)
      {
         result.disposition=SWV5S5_CLAIM_ALREADY_CLAIMED;
         result.claim_granted_now=false;
         result.resulting_authority_record.state=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED;
         result.reason_code="SCRIPTED_ALREADY_CLAIMED_NO_GRANT";
         return true;
      }
      if(next_disposition!=SWV5S5_CLAIM_GRANTED_NOW)
      {
         result.disposition=next_disposition;
         result.claim_granted_now=false;
         result.resulting_authority_record.state=SWV5S5_COMMITTED_NOT_INVOKED;
         result.reason_code="SCRIPTED_CLAIM_DENIED";
         return false;
      }
      claimed=true;
      result.disposition=SWV5S5_CLAIM_GRANTED_NOW;
      result.claim_granted_now=true;
      result.resulting_authority_record=command.expected_authority_record;
      result.resulting_authority_record.state=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED;
      result.resulting_authority_record.invocation_claim_id="scripted-claim-current-event";
      result.reason_code="SCRIPTED_ATOMIC_CLAIM_WINNER";
      return true;
   }
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

#endif
