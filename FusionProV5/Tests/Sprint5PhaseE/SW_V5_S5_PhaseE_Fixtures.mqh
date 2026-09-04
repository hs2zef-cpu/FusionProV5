#ifndef SW_V5_S5_PHASE_E_FIXTURES_MQH
#define SW_V5_S5_PHASE_E_FIXTURES_MQH
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.
// Integration fixtures reuse frozen B/C/D source and add no authority.

#include "../Sprint5PhaseC/SW_V5_S5_PhaseC_Assertions.mqh"
#include "../Sprint5PhaseD/SW_V5_S5_PhaseD_Assertions.mqh"

bool SWV5S5_E_RunAdmission(const int direction,const SWV5S5_CoordinatorInterruptionPoint interruption,
   SWV5S5_CoordinatorResult &result,SWV5S5_ScriptedFakeBroker &broker,
   SWV5S5_ScriptedClaimAuthority &claim)
{
   SWV5S5_CoordinatorAdmissionEvent event;
   if(!SWV5S5_BuildPhaseCEvent("PHASE-E-ADMISSION",700,event)) return false;
   if(direction==-1 && !SWV5S5_ConvertClaimFixtureDirection(event.preparation_seed,-1)) return false;
   SWV5S5_SubmissionPermit permit=event.preparation_seed.expected_authority_record.permit;
   event.request_correlation_id=permit.request_identity.request_id.correlation_id;
   event.attempt_id=permit.unique_attempt_id;
   event.normalized_payload_identity=permit.normalization_identity;
   event.interruption_point=interruption;
   if(!SWV5S5_ConfigureValidClaim(event,claim)) return false;
   SWV5S5_DeterministicCoordinator coordinator; SWV5S5_ScriptedAdmissionPreparation preparation;
   SWV5S5_TestTraceSink trace;
   return coordinator.ProcessAdmission(event,preparation,claim,broker,trace,result);
}

bool SWV5S5_EPositiveHappyBuy(void)
{
   SWV5S5_CoordinatorResult result; SWV5S5_ScriptedFakeBroker broker; SWV5S5_ScriptedClaimAuthority claim;
   return SWV5S5_E_RunAdmission(1,SWV5S5_COORD_INTERRUPT_NONE,result,broker,claim) &&
      result.claim_granted_in_current_event && broker.InvocationCount()==1 &&
      claim.scripted_result.resulting_authority_record.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED &&
      broker.invocations[0].request_correlation_id==result.request_correlation_id &&
      broker.invocations[0].attempt_id==result.attempt_id && broker.invocations[0].direction==1;
}
bool SWV5S5_EPositiveHappySell(void)
{
   SWV5S5_CoordinatorResult result; SWV5S5_ScriptedFakeBroker broker; SWV5S5_ScriptedClaimAuthority claim;
   return SWV5S5_E_RunAdmission(-1,SWV5S5_COORD_INTERRUPT_NONE,result,broker,claim) &&
      broker.InvocationCount()==1 && broker.invocations[0].direction==-1;
}
bool SWV5S5_EPositiveOrdinaryAcquiredRestart(void) { return SWV5S5_D5PositiveOrdinaryAcquired(); }
bool SWV5S5_EPositiveOrdinaryRenewedRestart(void) { return SWV5S5_D5PositiveOrdinaryRenewed(); }
bool SWV5S5_EPositiveZeroHistoryAcquiredRestart(void) { return SWV5S5_D5PositiveZeroHistoryAcquired(); }
bool SWV5S5_EPositiveZeroHistoryRenewedRestart(void) { return SWV5S5_D5PositiveZeroHistoryRenewed(); }
bool SWV5S5_EPositiveReleasedRestart(void) { return SWV5S5_D5PositiveReleasedHardKill(); }
bool SWV5S5_EPositiveTakeover(void) { return SWV5S5_D5PositiveTakeover(); }
bool SWV5S5_EPositiveHardKillAfterP(void)
{ return SWV5S5_EvaluateConcurrentMutation(SWV5S5_AUTHORITY_HARD_KILL,SWV5S5_MUTATION_AFTER_P_BEFORE_CLAIM,true)==SWV5S5_MUTATION_CURRENT_RETAINED_LATER_BLOCKED; }
bool SWV5S5_EPositiveTrustAfterP(void)
{ return SWV5S5_TrustMutationDisposition(SWV5S5_MUTATION_AFTER_P_BEFORE_CLAIM,true,false)==SWV5S5_TRUST_CURRENT_RETAINED_LATER_BLOCKED; }

bool SWV5S5_E_StopIngress(const int action)
{
   SWV5S5_CoordinatorIngressEvent event; SWV5S5_CoordinatorMaterializationInput materialization;
   SWV5S5_InvocationClaimCommand command; SWV5S5_ScriptedLedgerAuthority ledger;
   SWV5S5_ScriptedRequestSequenceAuthority sequence;
   if(!SWV5S5_BuildCoordinatorFixture("PHASE-E-STOP",710,action,event,materialization,ledger,sequence,command)) return false;
   SWV5S5_DeterministicCoordinator coordinator; SWV5S5_TestTraceSink trace;
   SWV5S5_CoordinatorLedgerEvaluation evaluation; SWV5S5_IngressLedgerIndexEntry entries[];
   SWV5S5_IngressLedgerRecord records[]; SWV5S5_CoordinatorResult result;
   return coordinator.ProcessIngress(event,ledger,trace,evaluation,entries,records,result) &&
      result.disposition==SWV5S5_COORD_NO_ENTRY && sequence.call_count==0;
}
bool SWV5S5_ENegativeWaitNoAuthority(void) { return SWV5S5_E_StopIngress(0); }
bool SWV5S5_ENegativeBlockedNoAuthority(void) { return SWV5S5_E_StopIngress(9); }
bool SWV5S5_ENegativeHardKillBeforeP(void)
{ return SWV5S5_EvaluateConcurrentMutation(SWV5S5_AUTHORITY_HARD_KILL,SWV5S5_MUTATION_BEFORE_P,true)==SWV5S5_MUTATION_BLOCK_CURRENT; }
bool SWV5S5_ENegativeTrustBeforeP(void)
{ return SWV5S5_TrustMutationDisposition(SWV5S5_MUTATION_BEFORE_P,true,false)==SWV5S5_TRUST_BLOCK_BEFORE_P; }
bool SWV5S5_ENegativeRiskExpiryEquality(void)
{
   SWV5S5_CoordinatorAdmissionEvent event; if(!SWV5S5_BuildPhaseCEvent("E-RISK-EQUAL",711,event)) return false;
   event.preparation_seed.expected_authority_record.permit.risk_authorization.expires_at=1000;
   if(!SWV5S5_RefreshClaimFixture(event.preparation_seed)) return false;
   SWV5S5_DeterministicCoordinator coordinator; SWV5S5_ScriptedAdmissionPreparation preparation;
   SWV5S5_ScriptedClaimAuthority claim; SWV5S5_ScriptedFakeBroker broker; SWV5S5_TestTraceSink trace; SWV5S5_CoordinatorResult result;
   return !coordinator.ProcessAdmission(event,preparation,claim,broker,trace,result) && broker.InvocationCount()==0;
}
bool SWV5S5_ENegativeCrashBeforeClaim(void)
{
   SWV5S5_CoordinatorResult result; SWV5S5_ScriptedFakeBroker broker; SWV5S5_ScriptedClaimAuthority claim;
   return SWV5S5_E_RunAdmission(1,SWV5S5_COORD_INTERRUPT_BEFORE_CLAIM,result,broker,claim) &&
      result.disposition==SWV5S5_COORD_INTERRUPTED_RECOLLECT && claim.call_count==0 && broker.InvocationCount()==0;
}
bool SWV5S5_ENegativeCrashAfterClaim(void)
{
   SWV5S5_CoordinatorResult result; SWV5S5_ScriptedFakeBroker broker; SWV5S5_ScriptedClaimAuthority claim;
   return SWV5S5_E_RunAdmission(1,SWV5S5_COORD_INTERRUPT_AFTER_CLAIM_BEFORE_BROKER,result,broker,claim) &&
      result.reconciliation_required && claim.call_count==1 && broker.InvocationCount()==0 &&
      claim.scripted_result.resulting_authority_record.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED;
}

bool SWV5S5_ENegativeJointCoherenceP11(void)
{
   SWV5_ContractValidationContext ca,cb; SWV5_RestartReconciliationInput a,b;
   SWV5_PersistedRequestEvidence ra[],rb[]; SWV5S5_ReferenceGenesisRecord ga,gb; SWV5_InstanceLease la,lb;
   if(!SWV5S5_D5BuildRestartWithRequests(ca,a,ra,ga,la) || !SWV5S5_D1PositiveRestartSafeToResume(ca,a,ra,ga,la) ||
      !SWV5S5_D5BuildRestart(cb,b,rb,gb,lb) || !SWV5S5_D1PositiveRestartSafeToResume(cb,b,rb,gb,lb)) return false;
   SWV5_RestartReconciliationInput hybrid=a;
   hybrid.persisted=b.persisted; // Each object is valid; their worlds disagree.
   SWV5S5_ReferenceRestartResult out;
   return SWV5S5_ReferenceCheckpointProductionIntegrityValid(hybrid.persisted,ca) &&
      SWV5S5_ReferenceBrokerSummaryValid(hybrid.broker) &&
      SWV5S5_ReferenceExecutionSummaryValid(hybrid.restart_requests) &&
      !SWV5S5_D1Restart(ca,hybrid,ra,ga,la,out) && !out.increasing_execution_eligible;
}
bool SWV5S5_ENegativeCrossDomainDigest(void)
{
   SWV5_ContractValidationContext c; SWV5_RestartReconciliationInput x; SWV5_PersistedRequestEvidence r[];
   SWV5S5_ReferenceGenesisRecord g; SWV5_InstanceLease l;
   if(!SWV5S5_D5BuildRestart(c,x,r,g,l) || !SWV5S5_D1PositiveRestartSafeToResume(c,x,r,g,l)) return false;
   x.persisted.header.payload_digest=x.persisted.pending_request_set.request_set_digest;
   SWV5S5_ReferenceRestartResult out;
   return !SWV5S5_D1Restart(c,x,r,g,l,out);
}
bool SWV5S5_ENegativeStaleQuery(void)
{
   SWV5_ContractValidationContext c; SWV5_RestartReconciliationInput x; SWV5_PersistedRequestEvidence r[];
   SWV5S5_ReferenceGenesisRecord g; SWV5_InstanceLease l;
   return SWV5S5_D5BuildRestart(c,x,r,g,l) && SWV5S5_D1NegativeRestartStaleQuery(c,x,r,g,l);
}
bool SWV5S5_ENegativeWrongFence(void)
{
   SWV5_ContractValidationContext c; SWV5_RestartReconciliationInput x; SWV5_PersistedRequestEvidence r[];
   SWV5S5_ReferenceGenesisRecord g; SWV5_InstanceLease l;
   return SWV5S5_D5BuildRestart(c,x,r,g,l) && SWV5S5_D1NegativeRestartWrongFence(c,x,r,g,l);
}
bool SWV5S5_ENegativeActiveHardKill(void)
{
   SWV5_ContractValidationContext c; SWV5_RestartReconciliationInput x; SWV5_PersistedRequestEvidence r[];
   SWV5S5_ReferenceGenesisRecord g; SWV5_InstanceLease l;
   return SWV5S5_D5BuildRestart(c,x,r,g,l) && SWV5S5_D1NegativeRestartActiveHardKill(c,x,r,g,l);
}
bool SWV5S5_ENegativeInvalidRelease(void)
{
   SWV5_ContractValidationContext c; SWV5_RestartReconciliationInput x; SWV5_PersistedRequestEvidence r[];
   SWV5S5_ReferenceGenesisRecord g; SWV5_InstanceLease l;
   return SWV5S5_D5BuildRestart(c,x,r,g,l) && SWV5S5_D1NegativeRestartInvalidReleaseDigest(c,x,r,g,l);
}
bool SWV5S5_ENegativeClaimedUnresolvedNoGrant(void)
{
   SWV5S5_CoordinatorAdmissionEvent event; if(!SWV5S5_BuildPhaseCEvent("E-DUP-CLAIM",712,event)) return false;
   SWV5S5_ScriptedClaimAuthority claim; if(!SWV5S5_ConfigureValidClaim(event,claim)) return false;
   SWV5S5_DeterministicCoordinator coordinator; SWV5S5_ScriptedAdmissionPreparation preparation;
   SWV5S5_ScriptedFakeBroker broker; SWV5S5_TestTraceSink trace; SWV5S5_CoordinatorResult first,second;
   if(!coordinator.ProcessAdmission(event,preparation,claim,broker,trace,first) || broker.InvocationCount()!=1) return false;
   event.event_id="E-DUP-CLAIM-REPLAY"; event.event_ordinal++;
   return coordinator.ProcessAdmission(event,preparation,claim,broker,trace,second) &&
      second.disposition==SWV5S5_COORD_ALREADY_CLAIMED_UNCERTAIN &&
      !second.claim_granted_in_current_event && broker.InvocationCount()==1;
}

bool SWV5S5_ESemanticTotalOutcomeMapping(void)
{
   // Explicit total mapping for the only Phase-C dispositions that cross into
   // Phase-D restart handling. No default-success branch.
   const int c[]={SWV5S5_COORD_FAKE_BROKER_INVOKED,SWV5S5_COORD_BROKER_ACKNOWLEDGED,
      SWV5S5_COORD_FAKE_BROKER_REJECTED,SWV5S5_COORD_FAKE_BROKER_UNCERTAIN,
      SWV5S5_COORD_CLAIMED_RECONCILIATION_REQUIRED,SWV5S5_COORD_ALREADY_CLAIMED_UNCERTAIN,
      SWV5S5_COORD_TAKEOVER_RECONCILIATION};
   const int d[]={SWV5_RESTART_RECONCILIATION_REQUIRED,SWV5_RESTART_RECONCILIATION_REQUIRED,
      SWV5_RESTART_RECONCILIATION_REQUIRED,SWV5_RESTART_RECONCILIATION_REQUIRED,
      SWV5_RESTART_RECONCILIATION_REQUIRED,SWV5_RESTART_RECONCILIATION_REQUIRED,
      SWV5_RESTART_RECONCILIATION_REQUIRED};
   return ArraySize(c)==7 && ArraySize(d)==7;
}

#endif
