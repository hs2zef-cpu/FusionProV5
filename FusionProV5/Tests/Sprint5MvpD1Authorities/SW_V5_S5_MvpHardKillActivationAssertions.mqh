#ifndef SW_V5_S5_MVP_HARD_KILL_ACTIVATION_ASSERTIONS_MQH
#define SW_V5_S5_MVP_HARD_KILL_ACTIVATION_ASSERTIONS_MQH
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.
#include "SW_V5_S5_MvpD1AuthorityAssertions.mqh"

void SWV5S5_MvpHKOperator(const SWV5_ContractValidationContext &context,SWV5S5_MvpOperatorInvocation &op)
{
   ZeroMemory(op); op.operator_id="MVP-D1-OFFLINE-OPERATOR"; op.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
   op.authentication_reference="MVP-D1-OFFLINE-AUTH"; op.authenticated_at=context.clock_time;
}

bool SWV5S5_MvpHKDeleteComplete(const string path,const string id)
{
   // Test-only fault injection, scoped to this suite's private SQLite file.
   const int db=DatabaseOpen(path,DATABASE_OPEN_READWRITE|DATABASE_OPEN_COMMON);
   if(db==INVALID_HANDLE) return false;
   const bool ok=DatabaseExecute(db,"DELETE FROM swv5_authority_rows WHERE domain_key='"+
      SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE+"' AND record_key='"+id+"'");
   DatabaseClose(db); return ok;
}

void SWV5S5_RunMvpHardKillActivationAssertions(SWV5S5_MvpD1Collector &c)
{
   ZeroMemory(c); c.signature=1469598103934665603;
   const string path="mvp_hk_activation_positive.sqlite"; string ns;
   SWV5S5_MvpControlledDemoAuthoritySeed seed; SWV5S5_MvpD1PhysicalSeedStatus status;
   const bool seeded=SWV5S5_MvpD1BuildE2ESeed(path,seed,ns,status,false);
   SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpAuthorityRow current,genesis,complete;
   bool found=false; const bool opened=seeded && store.Open(path,ns);
   const bool genesis_active=opened && store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"GENESIS",genesis,found) &&
      found && genesis.state==(int)SWV5_HARD_KILL_ACTIVE && genesis.logical_revision==1;
   SWV5S5_MvpD1Record(c,"HK-01",genesis_active);
   SWV5S5_MvpOperatorInvocation op; SWV5S5_MvpHKOperator(seed.context,op);
   SWV5S5_MvpHardKillActivationAuthority activation; SWV5_HardKillState inactive,changed=seed.hard_kill_state;
   SWV5S5_MvpAuthorityRow committed;
   const bool current_read=opened && store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,found) && found;
   changed.state=SWV5_HARD_KILL_ACTIVE;
   SWV5S5_MvpD1Record(c,"HK-02",current_read && !activation.TryActivateInactiveAfterValidatedRelease(store,
      seed.context,op,true,changed,seed.current_lease,current,inactive,committed));
   // The complete fixture performed two distinct CAS advances from genesis;
   // validate its durable pending predecessor using the full evidence and Risk.
   SWV5_HardKillState pending=seed.hard_kill_state; pending.state=SWV5_HARD_KILL_RELEASE_PENDING;
   pending.release_generation=0; SWV5S5_MvpRiskContract risk; SWV5_ContractDecision decision;
   SWV5S5_MvpD1Record(c,"HK-03",current_read && current.logical_revision==3 &&
      risk.ValidateHardKillRelease(seed.context,pending,pending.release_evidence,decision));
   SWV5_HardKillReleaseAuthorityRecord authority; SWV5_HardKillState durable;
   const bool complete_read=current_read && store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE,
      seed.hard_kill_state.release_authority_reference.authority_record_id,complete,found) && found &&
      SWV5S5_MvpDecodeReleaseBundle(complete.payload,durable,authority) &&
      SWV5S5_MvpCompleteReleaseValid(seed.context,durable,authority);
   SWV5S5_MvpD1Record(c,"HK-04",complete_read && current.state==(int)SWV5_HARD_KILL_RELEASED &&
      authority.authority_record_digest==durable.release_authority_reference.authority_record_digest);
   SWV5_RiskEvaluationInput candidate; SWV5S5_MvpD1MakeAllowedRisk(seed.context,candidate);
   candidate.hard_kill_state=seed.hard_kill_state;
   SWV5S5_MvpDeriveRiskAuthorizationId(candidate,candidate.intent.risk_authorization_id);
   SWV5_RiskAuthorization auth;
   SWV5S5_MvpD1Record(c,"HK-05",complete_read && !risk.Evaluate(seed.context,candidate,auth));

   // Fresh physical fixtures isolate each rejected input; no expected digest
   // or success value is copied from the implementation under test.
   for(int n=6;n<=12;n++)
   {
      const string negative_path="mvp_hk_activation_negative_"+IntegerToString(n)+".sqlite";
      SWV5S5_MvpControlledDemoAuthoritySeed negative; SWV5S5_MvpD1PhysicalSeedStatus negative_status; string negative_ns;
      SWV5S5_MvpSqliteAuthorityStore negative_store; SWV5S5_MvpAuthorityRow before,after;
      bool ready=SWV5S5_MvpD1BuildE2ESeed(negative_path,negative,negative_ns,negative_status,false) &&
         negative_store.Open(negative_path,negative_ns) &&
         negative_store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",before,found) && found;
      SWV5_ContractValidationContext context=negative.context; SWV5_InstanceLease lease=negative.current_lease;
      SWV5_HardKillState state=negative.hard_kill_state; SWV5S5_MvpOperatorInvocation negative_op;
      SWV5S5_MvpHKOperator(context,negative_op);
      if(n==6)
      {
         ready=ready && SWV5S5_MvpHKDeleteComplete(negative_path,state.release_authority_reference.authority_record_id);
         SWV5S5_MvpAuthorityRow absent; bool exists=true;
         ready=ready && negative_store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE,
            state.release_authority_reference.authority_record_id,absent,exists) && !exists;
      }
      if(n==7) state.release_authority_reference.authority_record_digest="CORRUPTED";
      if(n==8) state.release_evidence.release_id+="-WRONG";
      if(n==9) state.latch_generation++;
      if(n==10)
      {
         context.clock_time=state.release_evidence.expires_at; context.clock_sequence+=4000;
         lease.expires_at=context.clock_time+60; lease.expiry_clock_sequence=context.clock_sequence+60;
         SWV5S5_LeaseLivenessAuthorityView view; view.lease=lease;
         SWV5S5_MvpLeasePublicationAuthority publisher; SWV5S5_MvpAuthorityRow lease_row,old_lease;
         ready=ready && SWV5S5_DeriveLeaseProjection(view) &&
            negative_store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,old_lease,found) && found &&
            publisher.Publish(negative_store,lease,old_lease.logical_revision,old_lease.store_revision,
                              old_lease.payload_digest,old_lease.state,context.clock_time,lease_row) &&
            SWV5S5_MvpLeaseCurrentForClock(context,lease.fence,lease);
         SWV5S5_MvpHKOperator(context,negative_op);
      }
      if(n==11) lease.fence.takeover_generation++;
      if(n==12)
      {
         ready=ready && negative_store.CompareAndSet(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",before.logical_revision,
            before.store_revision,before.payload_digest,before.state,before.logical_revision+1,
            (int)SWV5_HARD_KILL_ACTIVE,before.payload_digest,before.payload,context.clock_time,after);
         before=after;
      }
      const bool denied=ready && !activation.TryActivateInactiveAfterValidatedRelease(negative_store,context,
         negative_op,true,state,lease,before,inactive,committed);
      const bool unchanged=negative_store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",after,found) && found &&
         after.payload==before.payload && after.store_revision==before.store_revision && after.state==before.state;
      SWV5S5_MvpD1Record(c,"HK-"+StringFormat("%02d",n),denied && unchanged);
   }

   SWV5S5_MvpAuthorityMutation history_mutation,current_mutation; SWV5S5_MvpAuthorityRow ownership;
   const bool prepared=complete_read && activation.PrepareActivation(store,seed.context,op,true,
      seed.hard_kill_state,seed.current_lease,current,history_mutation,current_mutation,ownership,inactive);
   const bool rollback=prepared && store.TestGuardedPairRollback(history_mutation,current_mutation,ownership,1) &&
      store.TestGuardedPairRollback(history_mutation,current_mutation,ownership,2);
   SWV5S5_MvpAuthorityRow rollback_read; bool rollback_history=false;
   const bool rollback_no_eligibility=rollback && store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_HISTORY,
      inactive.latch_id,rollback_read,rollback_history) && !rollback_history &&
      !activation.ValidateEligibility(store,seed.context,inactive,seed.current_lease,rollback_read);
   const bool activated=prepared && rollback_no_eligibility &&
      activation.TryActivateInactiveAfterValidatedRelease(store,seed.context,op,true,
         seed.hard_kill_state,seed.current_lease,current,inactive,committed);
   SWV5S5_MvpD1Record(c,"HK-13",activated &&
      SWV5_TestCheckpointHardKillSemanticValid(seed.context,inactive,inactive.persistence_namespace));
   SWV5S5_MvpD1Record(c,"HK-14",activated && inactive.latch_generation==seed.hard_kill_state.latch_generation+1 &&
      inactive.latch_id!=seed.hard_kill_state.latch_id && inactive.release_generation==0 &&
      inactive.activation_authority=="" && inactive.release_evidence.release_id=="");
   SWV5S5_MvpAuthorityRow history; SWV5S5_MvpHardKillActivationProof proof;
   const bool history_read=activated && store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_HISTORY,inactive.latch_id,history,found) && found &&
      SWV5S5_MvpDecodeActivation(history.payload,proof) && proof.release_bundle==complete.payload;
   SWV5S5_MvpD1Record(c,"HK-15",history_read);
   store.Close(); SWV5S5_MvpSqliteAuthorityStore restart; SWV5S5_MvpAuthorityRow restarted_complete,restarted_current;
   string encoded_before,encoded_after; SWV5_HardKillReleaseAuthorityRecord restarted_authority;
   SWV5_HardKillState restarted_released;
   const bool reopened=restart.Open(path,ns) && restart.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE,
      authority.authority_record_id,restarted_complete,found) && found &&
      SWV5S5_MvpDecodeReleaseBundle(restarted_complete.payload,restarted_released,restarted_authority) &&
      SWV5S5_MvpCodecEncode_SWV5_HardKillReleaseAuthorityRecord(authority,encoded_before) &&
      SWV5S5_MvpCodecEncode_SWV5_HardKillReleaseAuthorityRecord(restarted_authority,encoded_after) &&
      encoded_before==encoded_after && restarted_complete.payload==complete.payload;
   SWV5S5_MvpD1Record(c,"HK-16",reopened);
   // Corruption is injected later, after checking the intact restart path.
   const bool restarted_valid=reopened && activation.ValidateEligibility(restart,seed.context,inactive,seed.current_lease,
      restarted_current) && restarted_current.store_revision==committed.store_revision;
   SWV5S5_MvpD1Record(c,"HK-18",rollback_no_eligibility);
   SWV5_HardKillState duplicate; SWV5S5_MvpAuthorityRow duplicate_row,unchanged;
   SWV5S5_MvpD1Record(c,"HK-19",restarted_valid &&
      !activation.TryActivateInactiveAfterValidatedRelease(restart,seed.context,op,true,
         seed.hard_kill_state,seed.current_lease,current,duplicate,duplicate_row) &&
      activation.ValidateEligibility(restart,seed.context,inactive,seed.current_lease,unchanged) &&
      unchanged.store_revision==committed.store_revision);
   candidate.hard_kill_state=inactive;
   SWV5S5_MvpDeriveRiskAuthorizationId(candidate,candidate.intent.risk_authorization_id);
   SWV5S5_MvpD1Record(c,"HK-20",restarted_valid && risk.Evaluate(seed.context,candidate,auth) &&
      auth.disposition==SWV5_RISK_ALLOW);
   candidate.hard_kill_state=seed.hard_kill_state;
   SWV5S5_MvpDeriveRiskAuthorizationId(candidate,candidate.intent.risk_authorization_id);
   SWV5S5_MvpD1Record(c,"HK-21",restarted_valid && !risk.Evaluate(seed.context,candidate,auth));
   SWV5S5_MvpD1Record(c,"HK-23",restarted_valid && history_read && reopened);
   // Isolate approval expiry from lease expiry: renew same-owner liveness
   // in this test-only physical fixture, retaining the exact authority fence.
   SWV5_ContractValidationContext before_expiry=seed.context;
   before_expiry.clock_time=authority.expires_at-1; before_expiry.clock_sequence+=4000;
   SWV5_ContractValidationContext expired=before_expiry;
   expired.clock_time++; expired.clock_sequence++;
   SWV5_InstanceLease renewed=seed.current_lease; renewed.status=SWV5_LOCK_RENEWED;
   renewed.heartbeat_sequence++; renewed.heartbeat_at=before_expiry.clock_time-1;
   renewed.heartbeat_clock_sequence=before_expiry.clock_sequence-1;
   renewed.expires_at=expired.clock_time+60; renewed.expiry_clock_sequence=expired.clock_sequence+60;
   SWV5S5_SHA256("HK-22-TEST-ONLY-RENEWED-LIVENESS",renewed.store_revision);
   SWV5S5_MvpAuthorityRow prior_lease,renewed_row;
   SWV5S5_MvpLeasePublicationAuthority lease_publisher;
   const bool deadline_isolated=restarted_valid && restart.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,
      SWV5S5_MVP_OWNERSHIP_KEY,prior_lease,found) && found &&
      lease_publisher.Publish(restart,renewed,prior_lease.logical_revision,prior_lease.store_revision,
         prior_lease.payload_digest,prior_lease.state,before_expiry.clock_time,renewed_row) &&
      SWV5S5_MvpLeaseCurrentForClock(expired,renewed.fence,renewed) &&
      activation.ValidateEligibility(restart,before_expiry,inactive,renewed,unchanged) &&
      !activation.ValidateEligibility(restart,expired,inactive,renewed,unchanged);
   // Remove ONLY the immutable transition proof; leave exact current state,
   // lease and full independent release authority untouched.
   const int fault_db=DatabaseOpen(path,DATABASE_OPEN_READWRITE|DATABASE_OPEN_COMMON);
   bool missing_proof=false;
   if(fault_db!=INVALID_HANDLE)
   {
      missing_proof=DatabaseExecute(fault_db,"DELETE FROM swv5_authority_rows WHERE domain_key='"+
         SWV5S5_MVP_DOMAIN_RELEASE_HISTORY+"' AND record_key='"+inactive.latch_id+"'");
      DatabaseClose(fault_db);
   }
   bool proof_exists=true; SWV5S5_MvpAuthorityRow missing;
   missing_proof=missing_proof && restart.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_HISTORY,
      inactive.latch_id,missing,proof_exists) && !proof_exists &&
      !activation.ValidateEligibility(restart,before_expiry,inactive,renewed,unchanged);
   SWV5S5_MvpD1Record(c,"HK-22",deadline_isolated && missing_proof);
   // Independently use the separate original history payload for the
   // corruption injection; this creates revision 1 in the now-missing slot.
   SWV5S5_MvpAuthorityRow corrupted;
   const bool corrupt_written=history_read && missing_proof && restart.CompareAndSet(history.domain_key,history.record_key,
      0,"","",0,1,history.state,history.payload_digest,history.payload+"CORRUPT",history.updated_at,corrupted);
   SWV5S5_MvpD1Record(c,"HK-17",deadline_isolated && corrupt_written &&
      !activation.ValidateEligibility(restart,before_expiry,inactive,renewed,unchanged));
   SWV5S5_MvpD1Collector recovery; ZeroMemory(recovery); recovery.signature=1469598103934665603;
   SWV5S5_MvpD1D6Assertions(recovery,true); SWV5S5_MvpD1D6Assertions(recovery,false);
   SWV5S5_MvpD1Record(c,"HK-24",recovery.total==6 && recovery.failed==0);
   SWV5S5_MvpD1Collector e2e; ZeroMemory(e2e); e2e.signature=1469598103934665603;
   SWV5S5_MvpD1E2EAssertions(e2e);
   SWV5S5_MvpD1Record(c,"HK-E2E-RELEASE-TO-RISK",e2e.total>0 && e2e.failed==0);
   const string preflight_path="mvp_hk_preflight_zero_submission.sqlite"; string preflight_ns;
   SWV5S5_MvpControlledDemoAuthoritySeed preflight_seed; SWV5S5_MvpD1PhysicalSeedStatus preflight_status;
   SWV5S5_MvpD1ReadOnlyPlatform platform; SWV5S5_MvpBrokerEvidenceStore evidence_store;
   SWV5S5_MvpControlledDemoAuthorityPort port; SWV5S5_MvpControlledDemoRunner runner;
   SWV5S5_MvpD1PersistedEvidenceBoundary boundary; SWV5S5_MvpControlledDemoInvocation invocation;
   SWV5S5_MvpControlledDemoResult preflight_result;
   const bool preflight_seeded=SWV5S5_MvpD1BuildE2ESeed(preflight_path,preflight_seed,preflight_ns,preflight_status);
   SWV5S5_MvpD1MakeInvocation(preflight_path,preflight_ns,MODE_PREFLIGHT,invocation);
   invocation.armed_for_demo_submission=false; invocation.operator_confirmed_before_claim=false;
   invocation.execute_attended_once=false;
   const bool preflight_ran=preflight_seeded && evidence_store.Configure(preflight_path,preflight_ns) &&
      port.Configure(preflight_path,preflight_ns,preflight_seed,&platform,&evidence_store) &&
      runner.Run(invocation,port,boundary,preflight_result);
   SWV5S5_MvpD1Record(c,"HK-25",preflight_ran && runner.BrokerSubmissionCalls()==0 && boundary.calls==0 &&
      preflight_result.broker_submission_calls==0 && !preflight_result.claim_granted_now);
}
#endif
