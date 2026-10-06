#ifndef SW_V5_S5_MVP_BASKET_AUTHORITY_ASSERTIONS_MQH
#define SW_V5_S5_MVP_BASKET_AUTHORITY_ASSERTIONS_MQH
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.
#include "SW_V5_S5_MvpD1AuthorityAssertions.mqh"

class SWV5S5_TestBasketBroker : public ISWV5S5MvpBootstrapBrokerObserver
{
private:
   SWV5S5_MvpRuntimeProfileObservation m_profile; datetime m_now; int m_fault;
public:
   SWV5S5_TestBasketBroker(const SWV5S5_MvpRuntimeProfileObservation &profile,const datetime now,const int fault=0)
   {m_profile=profile;m_now=now;m_fault=fault;}
   virtual bool Capture(const string symbol,SWV5S5_MvpBootstrapBrokerObservation &o)
   {
      ZeroMemory(o); if(symbol!=m_profile.symbol || m_fault==2) return false;
      o.profile=m_profile; o.observed_at=m_now; o.positions_query_succeeded=true;
      o.active_orders_query_succeeded=true; o.enumeration_complete=true;
      if(m_fault==4){o.total_positions=1;o.total_exposure_volume=0.01;}
      if(m_fault==5) o.total_active_orders=1;
      if(m_fault==6) o.enumeration_complete=false;
      if(m_fault==7) o.row_failures=1;
      return SWV5S5_MvpBootstrapBrokerDigest(o,o.snapshot_digest);
   }
};

bool SWV5S5_TestBasketFaultSql(const string path,const string sql)
{
   // Only suite-owned private database files; explicit deliberate corruption,
   // never presented as legitimate lifecycle input or positive authority.
   const int db=DatabaseOpen(path,DATABASE_OPEN_READWRITE|DATABASE_OPEN_COMMON);
   if(db==INVALID_HANDLE) return false;
   const bool ok=DatabaseExecute(db,sql); DatabaseClose(db); return ok;
}

void SWV5S5_TestBasketConfirmationCrash(SWV5S5_MvpD1Collector &c,const bool before_basket)
{
   const string path=before_basket ? "mvp_basket_crash_before_basket.sqlite" : "mvp_basket_crash_before_terminal.sqlite";
   string ns; SWV5S5_MvpControlledDemoAuthoritySeed seed; SWV5S5_MvpD1PhysicalSeedStatus status;
   SWV5S5_MvpD1ReadOnlyPlatform platform; SWV5S5_MvpBrokerEvidenceStore evidence;
   SWV5S5_MvpControlledDemoAuthorityPort port; SWV5S5_MvpD1RecoveryReadPort recovery(true);
   SWV5S5_MvpD1PersistedEvidenceBoundary boundary; SWV5S5_MvpControlledDemoRunner d1,d6,restarted_d6;
   SWV5S5_MvpControlledDemoInvocation invocation; SWV5S5_MvpControlledDemoResult d1_result,stopped,resumed;
   const bool ready=SWV5S5_MvpD1BuildE2ESeed(path,seed,ns,status) && evidence.Configure(path,ns) &&
      port.Configure(path,ns,seed,&platform,&evidence,&recovery);
   SWV5S5_MvpD1MakeInvocation(path,ns,MODE_D1_BUY,invocation);
   const bool claimed=ready && d1.Run(invocation,port,boundary,d1_result);
   const string domain=before_basket ? SWV5S5_MVP_DOMAIN_BASKET : SWV5S5_MVP_DOMAIN_SUBMISSION;
   const bool fault=claimed && SWV5S5_TestBasketFaultSql(path,
      "CREATE TRIGGER basket_test_crash BEFORE UPDATE ON swv5_authority_rows WHEN NEW.domain_key='"+domain+
      "' BEGIN SELECT RAISE(ABORT,'TEST_ONLY_CONFIRMATION_WRITE_FAILURE'); END;");
   SWV5S5_MvpD1MakeInvocation(path,ns,MODE_D6_RECOVER,invocation);
   SWV5S5_MvpBrokerEvidenceStore first_restart_evidence; SWV5S5_MvpControlledDemoAuthorityPort first_restart;
   const bool restart_configured=first_restart_evidence.Configure(path,ns) &&
      first_restart.Configure(path,ns,seed,&platform,&first_restart_evidence,&recovery);
   const bool stopped_closed=fault && restart_configured && !d6.Run(invocation,first_restart,boundary,stopped);
   SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpBasketLifecycleAuthority basket_owner;
   SWV5_BasketAggregate basket; SWV5S5_MvpAuthorityRow basket_row,publication_row;
   SWV5S5_MvpReconciliationPublicationAuthority reconciliation; SWV5S5_F_ReconciliationPublication publication;
   // Obtain the key from the actual physical Claim, not a caller-made identity.
   SWV5S5_MvpInvocationClaimAuthority claims; SWV5S5_MvpReloadedClaim claim;
   const bool unresolved=claims.Configure(path,ns) && claims.ReloadClaim(claim) && claim.found &&
      !claim.claim_granted_now && claim.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED;
   const bool preserved=stopped_closed && unresolved && store.Open(path,ns) && reconciliation.Configure(path,ns) &&
      reconciliation.LoadPersistedPublication(SWV5S5_MvpAttemptPinKey(claim.authority_record.permit.request_identity),publication,publication_row) &&
      publication.result.authoritative_positive && basket_owner.ValidateCurrentBasket(store,seed.context,
         seed.current_trust.persistence_namespace,seed.current_lease,basket,basket_row) &&
      basket.lifecycle.state==(before_basket ? SWV5_BASKET_IDLE : SWV5_BASKET_ACTIVE) &&
      basket.lifecycle.state_version==(before_basket ? 1 : 3);
   if(!preserved) Print("BASKET_CRASH_DIAGNOSTIC|before_basket=",before_basket,"|ready=",ready,
      "|claimed=",claimed,"|fault=",fault,"|stopped_closed=",stopped_closed,"|unresolved=",unresolved,
      "|d1_reason=",d1_result.stop_reason,"|d6_reason=",stopped.stop_reason,"|stage=",port.LastStage(),
      "|publication_revision=",publication_row.logical_revision,"|basket_version=",basket.lifecycle.state_version);
   SWV5S5_MvpD1Record(c,before_basket ? "BASKET-33-PUBLICATION-CRASH-FAIL-CLOSED" : "BASKET-35-BASKET-HANDOFF-CRASH-FAIL-CLOSED",preserved);
   SWV5S5_MvpBrokerEvidenceStore reloaded_evidence; SWV5S5_MvpControlledDemoAuthorityPort restarted;
   const bool restart=preserved && SWV5S5_TestBasketFaultSql(path,"DROP TRIGGER basket_test_crash;") &&
      reloaded_evidence.Configure(path,ns) && restarted.Configure(path,ns,seed,&platform,&reloaded_evidence,&recovery) &&
      restarted_d6.Run(invocation,restarted,boundary,resumed) && resumed.recovery_complete &&
      restarted_d6.BrokerSubmissionCalls()==0 && boundary.calls==1 &&
      // Independent post-restart connection, not the handle retained across
      // the deliberately aborted transaction and destroyed recovery objects.
      store.Open(path,ns) &&
      basket_owner.ValidateCurrentBasket(store,seed.context,seed.current_trust.persistence_namespace,
         seed.current_lease,basket,basket_row) && basket.lifecycle.state_version==3 && basket.lifecycle.state==SWV5_BASKET_ACTIVE;
   if(!restart) Print("BASKET_RESUME_DIAGNOSTIC|before_basket=",before_basket,"|preserved=",preserved,
      "|reason=",resumed.stop_reason,"|complete=",resumed.recovery_complete,"|boundary_calls=",boundary.calls,
      "|submissions=",restarted_d6.BrokerSubmissionCalls(),"|stage=",restarted.LastStage(),
      "|basket_version=",basket.lifecycle.state_version);
   SWV5S5_MvpD1Record(c,before_basket ? "BASKET-34-RESTART-RESUMES-BASKET" : "BASKET-36-RESTART-RESUMES-TERMINALIZATION",restart);
}

void SWV5S5_RunMvpBasketAuthorityAssertions(SWV5S5_MvpD1Collector &c)
{
   ZeroMemory(c); c.signature=1469598103934665603;
   const string path="mvp_basket_authority_flat_test.sqlite"; string ns;
   SWV5S5_MvpControlledDemoAuthoritySeed seed; SWV5S5_MvpD1PhysicalSeedStatus seed_status;
   const bool seeded=SWV5S5_MvpD1BuildE2ESeed(path,seed,ns,seed_status,true,false);
   SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpBasketLifecycleAuthority owner;
   SWV5_BasketAggregate basket,again; SWV5S5_MvpAuthorityRow row,again_row; bool found=false;
   const bool absent=seeded && store.Open(path,ns) && owner.LoadCurrentBasket(store,basket,row,found) && !found;
   SWV5S5_MvpD1Record(c,"BASKET-01",absent);
   SWV5S5_MvpD1ReadOnlyPlatform platform; SWV5S5_MvpRuntimeProfileObservation profile; datetime at=0;
   const bool observed=platform.CaptureProfile(SWV5S5_MVP_SYMBOL,profile,at);
   SWV5S5_TestBasketBroker failed_broker(profile,at,2),flat_broker(profile,at);
   SWV5S5_MvpD1Record(c,"BASKET-02",absent && observed &&
      !owner.TryCreateInitialFlatBasket(store,seed.context,seed.current_trust.persistence_namespace,
         seed.current_lease,failed_broker,basket,row) && owner.LoadCurrentBasket(store,basket,row,found) && !found);
   for(int n=4;n<=7;n++)
   {
      SWV5S5_TestBasketBroker fault(profile,at,n);
      const bool denied=absent && !owner.TryCreateInitialFlatBasket(store,seed.context,
         seed.current_trust.persistence_namespace,seed.current_lease,fault,basket,row) &&
         owner.LoadCurrentBasket(store,basket,row,found) && !found;
      SWV5S5_MvpD1Record(c,"BASKET-"+StringFormat("%02d",n),denied);
   }
   const bool created=absent && owner.TryCreateInitialFlatBasket(store,seed.context,
      seed.current_trust.persistence_namespace,seed.current_lease,flat_broker,basket,row);
   SWV5S5_MvpD1Record(c,"BASKET-03",created);
   SWV5S5_MvpD1Record(c,"BASKET-10",created && basket.lifecycle.state==SWV5_BASKET_IDLE &&
      basket.lifecycle.state_version==1 && basket.lifecycle.aggregate_open_volume==0.0 &&
      basket.lifecycle.pending_request_count==0 && basket.close_verification==SWV5_CLOSE_ZERO_RESIDUAL_CONFIRMED &&
      SWV5_TestCheckpointBasketSemanticValid(seed.context,basket,basket.persistence_namespace,seed.current_lease.fence));
   string encoded,decoded,digest;
   const bool round_trip=created && owner.LoadCurrentBasket(store,again,again_row,found) && found &&
      SWV5S5_MvpCodecEncode_SWV5_BasketAggregate(basket,encoded) &&
      SWV5S5_MvpCodecEncode_SWV5_BasketAggregate(again,decoded) && encoded==decoded;
   SWV5S5_MvpD1Record(c,"BASKET-11",round_trip);
   SWV5S5_MvpD1Record(c,"BASKET-12",round_trip &&
      SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_BASKET,encoded,digest) && digest==row.payload_digest);
   SWV5S5_MvpD1Record(c,"BASKET-13",round_trip && owner.TryCreateInitialFlatBasket(store,seed.context,
      basket.persistence_namespace,seed.current_lease,flat_broker,again,again_row) && again_row.store_revision==row.store_revision);
   SWV5_ContractValidationContext later=seed.context; later.clock_time++; later.clock_sequence++;
   SWV5S5_TestBasketBroker later_broker(profile,later.clock_time);
   SWV5S5_MvpD1Record(c,"BASKET-14",created && !owner.TryCreateInitialFlatBasket(store,later,
      basket.persistence_namespace,seed.current_lease,later_broker,again,again_row) &&
      owner.LoadCurrentBasket(store,again,again_row,found) && found && again_row.store_revision==row.store_revision);
   SWV5_InstanceLease stale=seed.current_lease; stale.fence.takeover_generation++;
   SWV5S5_MvpD1Record(c,"BASKET-15",created && !owner.ValidateCurrentBasket(store,seed.context,
      basket.persistence_namespace,stale,again,again_row));
   store.Close(); SWV5S5_MvpSqliteAuthorityStore restart;
   SWV5S5_MvpD1Record(c,"BASKET-17",restart.Open(path,ns) && owner.ValidateCurrentBasket(restart,seed.context,
      basket.persistence_namespace,seed.current_lease,again,again_row) &&
      SWV5S5_MvpCodecEncode_SWV5_BasketAggregate(again,decoded) && decoded==encoded);

   // Use the actual physical D1 path; preserve its nested assertion failures.
   SWV5S5_MvpD1Collector e2e; ZeroMemory(e2e); e2e.signature=1469598103934665603;
   SWV5S5_MvpD1E2EAssertions(e2e);
   const string d1_path="mvp_d1_physical_e2e_v1.sqlite"; string d1_ns;
   SWV5_PersistenceNamespace d1_scope; SWV5_InstanceLease d1_lease;
   SWV5S5_MvpD1MakeScope(d1_scope,d1_lease,d1_ns);
   SWV5S5_MvpSqliteAuthorityStore d1_store; SWV5S5_MvpInvocationClaimAuthority claims;
   SWV5S5_MvpReloadedClaim reloaded; SWV5S5_SubmissionAuthorityRecord claimed;
   const bool d1_ok=e2e.failed==0 && e2e.total>0 && d1_store.Open(d1_path,d1_ns) &&
      claims.Configure(d1_path,d1_ns) && claims.ReloadClaim(reloaded) && reloaded.found &&
      !reloaded.claim_granted_now && SWV5S5_MvpLoadSubmissionAuthority(d1_store,
         reloaded.logical_correlation_id,reloaded.attempt_id,claimed,found) && found;
   SWV5_BasketAggregate before_confirmation; SWV5S5_MvpAuthorityRow before_row;
   const bool physical_v1=d1_ok && owner.ValidateCurrentBasket(d1_store,seed.context,d1_scope,d1_lease,
      before_confirmation,before_row) && before_confirmation.lifecycle.state_version==1;
   const ulong v=before_confirmation.lifecycle.state_version;
   SWV5S5_MvpD1Record(c,"BASKET-18",physical_v1 &&
      claimed.admission_snapshot.collect_v1.risk_authorization.current_binding.basket.lifecycle.state_version==v);
   SWV5S5_MvpD1Record(c,"BASKET-19",physical_v1 && claimed.permit.risk_authorization.basket_state_version==v);
   SWV5S5_MvpD1Record(c,"BASKET-20",physical_v1 && claimed.permit.basket_state_version==v);
   SWV5S5_MvpD1Record(c,"BASKET-21",physical_v1 &&
      claimed.admission_snapshot.collect_v1.basket.basket.state_version==v &&
      claimed.admission_snapshot.collect_v2.basket.basket.state_version==v);
   SWV5S5_MvpAttemptReconciliationPinAuthority pins; SWV5S5_MvpAttemptReconciliationPin pin;
   SWV5S5_MvpAuthorityRow pin_row; bool pin_found=false;
   SWV5S5_MvpD1Record(c,"BASKET-22",physical_v1 && pins.Configure(d1_path,d1_ns) &&
      pins.Load(claimed.permit.request_identity,pin,pin_row,pin_found) && pin_found && pin.expected_basket_version==v &&
      pin.admission_snapshot_digest==claimed.admission_snapshot_digest);
   SWV5S5_MvpD1Record(c,"BASKET-28",physical_v1 && !reloaded.claim_granted_now &&
      reloaded.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED && before_confirmation.lifecycle.state==SWV5_BASKET_IDLE);

   SWV5S5_MvpControlledDemoAuthoritySeed repeated_seed;
   // Reload the current source seed WITHOUT rebuilding/resetting the database:
   // this local typed construction supplies only test external observations.
   repeated_seed=seed; repeated_seed.risk_observation.basket.lifecycle=before_confirmation.lifecycle;
   SWV5S5_MvpBrokerEvidenceStore broker_store; SWV5S5_MvpControlledDemoAuthorityPort port;
   SWV5S5_MvpControlledDemoInvocation invocation; SWV5S5_MvpD1MakeInvocation(d1_path,d1_ns,MODE_D1_BUY,invocation);
   SWV5S5_MvpD1PersistedEvidenceBoundary boundary; SWV5S5_MvpControlledDemoRunner runner; SWV5S5_MvpControlledDemoResult result;
   const bool duplicate_blocked=physical_v1 && broker_store.Configure(d1_path,d1_ns) &&
      port.Configure(d1_path,d1_ns,repeated_seed,&platform,&broker_store) &&
      !runner.Run(invocation,port,boundary,result) && boundary.calls==0 && runner.BrokerSubmissionCalls()==0;
   SWV5S5_MvpD1Record(c,"BASKET-23",duplicate_blocked);

   // Independent pending-only failure: delete only Basket after real D1
   // preparation (no Permit/Claim), leaving genuine operational request rows.
   const string pending_path="mvp_basket_pending_test.sqlite"; string pending_ns;
   SWV5S5_MvpControlledDemoAuthoritySeed pending_seed; SWV5S5_MvpD1PhysicalSeedStatus pending_status;
   SWV5S5_MvpControlledDemoAuthorityPort pending_port; SWV5S5_MvpBrokerEvidenceStore pending_evidence;
   SWV5S5_MvpControlledDemoInvocation pending_inv; SWV5S5_MvpControlledDemoPreflightEvidence pending_preflight;
   SWV5S5_MvpSqliteAuthorityStore pending_store;
   const bool pending_prepared=SWV5S5_MvpD1BuildE2ESeed(pending_path,pending_seed,pending_ns,pending_status) &&
      pending_evidence.Configure(pending_path,pending_ns) && pending_port.Configure(pending_path,pending_ns,
         pending_seed,&platform,&pending_evidence);
   SWV5S5_MvpD1MakeInvocation(pending_path,pending_ns,MODE_D1_BUY,pending_inv);
   const bool pending_artifact=pending_prepared && pending_port.PrepareD1AuthorityPath(pending_inv,1,pending_preflight) &&
      SWV5S5_TestBasketFaultSql(pending_path,"DELETE FROM swv5_authority_rows WHERE domain_key='MVP_CANONICAL_BASKET'") &&
      pending_store.Open(pending_path,pending_ns);
   SWV5S5_MvpD1Record(c,"BASKET-08",pending_artifact && !owner.TryCreateInitialFlatBasket(pending_store,
      pending_seed.context,pending_seed.current_trust.persistence_namespace,pending_seed.current_lease,flat_broker,again,again_row) &&
      owner.LastFailure()=="BASKET_INITIAL_EXECUTION_FLAT");
   // Missing Basket with a real claimed-unresolved Submission is never reset.
   const bool basket_removed=physical_v1 && SWV5S5_TestBasketFaultSql(d1_path,
      "DELETE FROM swv5_authority_rows WHERE domain_key='MVP_CANONICAL_BASKET'");
   // Deliberate independent-domain rollback fault: restore a previously read
   // genuine empty Execution record while retaining the REAL claimed Submission.
   // Check that Execution is now complete/empty before exercising Submission's
   // separate veto. This is NOT a legitimate positive lifecycle fixture.
   SWV5S5_MvpAuthorityRow empty_execution,current_execution,restored_execution; bool empty_found=false,current_found=false;
   SWV5S5_MvpRequestSetPublicationAuthority restored_owner; SWV5S5_RequestSetPublicationAuthority restored_authority;
   SWV5_PendingRequest restored_requests[];
   const bool empty_restored=basket_removed && restart.ReadRow(SWV5S5_MVP_DOMAIN_REQUEST_SET,
      SWV5S5_MVP_REQUEST_SET_KEY,empty_execution,empty_found) && empty_found &&
      d1_store.ReadRow(SWV5S5_MVP_DOMAIN_REQUEST_SET,SWV5S5_MVP_REQUEST_SET_KEY,current_execution,current_found) && current_found &&
      d1_store.CompareAndSet(current_execution.domain_key,current_execution.record_key,current_execution.logical_revision,
         current_execution.store_revision,current_execution.payload_digest,current_execution.state,current_execution.logical_revision+1,
         empty_execution.state,empty_execution.payload_digest,empty_execution.payload,seed.context.clock_time,restored_execution) &&
      restored_owner.Configure(d1_path,d1_ns) && restored_owner.ReadState(restored_authority,restored_requests) &&
      ArraySize(restored_requests)==0;
   SWV5S5_MvpD1Record(c,"BASKET-09",empty_restored && !owner.TryCreateInitialFlatBasket(d1_store,seed.context,
      d1_scope,d1_lease,flat_broker,again,again_row) && owner.LastFailure()=="BASKET_INITIAL_UNRESOLVED_SUBMISSION");

   // Acknowledgement/callback-only typed transitions must fail independently
   // of source read failures; a valid open-authorized positive control exists.
   SWV5S5_MvpBasketStateMachine machine; SWV5_BasketTransitionRequest request; ZeroMemory(request);
   request.contract_version=seed.context.expected_version; request.basket_id=basket.lifecycle.basket_id;
   request.ownership_fence=seed.current_lease.fence; request.from_state=SWV5_BASKET_IDLE;
   request.to_state=SWV5_BASKET_OPENING; request.cause=SWV5_TRANSITION_OPEN_AUTHORIZED;
   request.expected_state_version=1; request.evidence_time=seed.context.clock_time;
   request.broker_queries=basket.lifecycle.broker_queries; request.reconciliation_state=SWV5_RECONCILIATION_STATE_MATCHED;
   request.risk_decision.disposition=SWV5_DISPOSITION_ALLOW; SWV5_BasketTransitionDecision d;
   const bool open_authorized=machine.ValidateTransition(seed.context,basket.lifecycle,request,d);
   SWV5_BasketLifecycleSnapshot opening=basket.lifecycle; opening.state=SWV5_BASKET_OPENING; opening.state_version=2;
   request.from_state=SWV5_BASKET_OPENING; request.to_state=SWV5_BASKET_ACTIVE;
   request.expected_state_version=2; request.cause=SWV5_TRANSITION_OPEN_CONFIRMED;
   request.residual_volume=0.01; request.live_position_count=1; request.confirmation_authority=SWV5_AUTHORITY_NONE;
   request.correlation.contract_version=seed.context.expected_version;
   request.correlation.request_identity=claimed.permit.request_identity;
   request.correlation.broker_identity.contract_version=seed.context.expected_version;
   request.correlation.broker_identity.order_ticket=7001; request.correlation.broker_identity.deal_ticket=8001;
   request.correlation.broker_identity.position_identifier=9001; request.correlation.broker_identity.transaction_sequence=1;
   request.correlation.broker_identity.broker_event_id="TEST_ONLY_DEAL_8001";
   request.correlation.phase=SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION;
   SWV5S5_MvpD1Record(c,"BASKET-24",open_authorized && !machine.ValidateTransition(seed.context,opening,request,d));
   request.confirmation_authority=SWV5_AUTHORITY_TRANSACTION_EVENT;
   const bool confirmation_control=machine.ValidateTransition(seed.context,opening,request,d);
   request.correlation.phase=SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT;
   SWV5S5_MvpD1Record(c,"BASKET-25",confirmation_control && !machine.ValidateTransition(seed.context,opening,request,d));

   SWV5S5_MvpD1Collector positive_d6; ZeroMemory(positive_d6); positive_d6.signature=1469598103934665603;
   SWV5S5_MvpD1D6Assertions(positive_d6,true);
   const string positive_path="mvp_d1_d6_positive_v1.sqlite";
   SWV5S5_MvpSqliteAuthorityStore positive_store; SWV5_BasketAggregate active; SWV5S5_MvpAuthorityRow active_row,history;
   SWV5S5_MvpAuthorityRow all_rows[];
   const bool converged=positive_d6.failed==0 && positive_d6.total==3 && positive_store.Open(positive_path,d1_ns) &&
      owner.ValidateCurrentBasket(positive_store,seed.context,d1_scope,d1_lease,active,active_row) &&
      active.lifecycle.state==SWV5_BASKET_ACTIVE && active.lifecycle.state_version==3 && positive_store.ReadAllRows(all_rows);
   int histories=0; for(int i=0;i<ArraySize(all_rows);i++) if(all_rows[i].domain_key==SWV5S5_MVP_DOMAIN_BASKET_HISTORY)
   { histories++; history=all_rows[i]; }
   SWV5S5_MvpBasketHistory full_history; SWV5_BasketTransitionDecision opening_decision,active_decision;
   ulong reference_opening_version=0,reference_active_version=0;
   string history_digest,history_active,current_active;
   const bool ordered=converged && histories==1 &&
      SWV5S5_DomainDigest(history.domain_key,history.payload,history_digest) && history_digest==history.payload_digest &&
      SWV5S5_MvpDecodeBasketHistory(history.payload,full_history) &&
      full_history.prior.lifecycle.state==SWV5_BASKET_IDLE && full_history.prior.lifecycle.state_version==1 &&
      full_history.opening.lifecycle.state==SWV5_BASKET_OPENING && full_history.opening.lifecycle.state_version==2 &&
      full_history.active.lifecycle.state==SWV5_BASKET_ACTIVE && full_history.active.lifecycle.state_version==3 &&
      machine.ValidateTransition(seed.context,full_history.prior.lifecycle,full_history.opening_request,opening_decision) &&
      machine.ValidateTransition(seed.context,full_history.opening.lifecycle,full_history.active_request,active_decision) &&
      SWV5_TestEvaluateBasketTransition(seed.context,full_history.prior.lifecycle,full_history.opening_request,
         reference_opening_version)==SWV5_TEST_BASKET_ALLOW &&
      SWV5_TestEvaluateBasketTransition(seed.context,full_history.opening.lifecycle,full_history.active_request,
         reference_active_version)==SWV5_TEST_BASKET_ALLOW && reference_opening_version==2 && reference_active_version==3 &&
      opening_decision.resulting_state_version==2 && active_decision.resulting_state_version==3 &&
      SWV5S5_MvpCodecEncode_SWV5_BasketAggregate(full_history.active,history_active) &&
      SWV5S5_MvpCodecEncode_SWV5_BasketAggregate(active,current_active) && history_active==current_active &&
      full_history.active_request.correlation.broker_identity.position_identifier==9001;
   SWV5S5_MvpD1Record(c,"BASKET-26",ordered);
   SWV5S5_MvpD1Record(c,"BASKET-27",converged && active.lifecycle.state_version==v+2);
   SWV5S5_MvpD1Record(c,"BASKET-29",converged && active.lifecycle.aggregate_open_volume==0.01);
   SWV5S5_MvpD1Collector negative_d6; ZeroMemory(negative_d6); negative_d6.signature=1469598103934665603;
   SWV5S5_MvpD1D6Assertions(negative_d6,false);
   SWV5S5_MvpSqliteAuthorityStore negative_store; SWV5_BasketAggregate still_idle; SWV5S5_MvpAuthorityRow still_row;
   SWV5S5_MvpD1Record(c,"BASKET-30",negative_d6.failed==0 && negative_d6.total==3 &&
      negative_store.Open("mvp_d1_d6_no_positive_v1.sqlite",d1_ns) && owner.ValidateCurrentBasket(negative_store,seed.context,
         d1_scope,d1_lease,still_idle,still_row) && still_idle.lifecycle.state==SWV5_BASKET_IDLE && still_idle.lifecycle.state_version==1);
   SWV5S5_MvpD1Record(c,"BASKET-31",positive_d6.failed==0 && negative_d6.failed==0 &&
      positive_d6.total==3 && negative_d6.total==3); // nested D6 checks measure zero calls
   const bool corrupt=SWV5S5_TestBasketFaultSql(path,
      "UPDATE swv5_authority_rows SET payload=payload||'CORRUPT' WHERE domain_key='MVP_CANONICAL_BASKET'");
   SWV5S5_MvpD1Record(c,"BASKET-16",corrupt && !owner.LoadCurrentBasket(restart,again,again_row,found));
   SWV5S5_MvpD1Record(c,"BASKET-32",duplicate_blocked && e2e.failed==0 && positive_d6.failed==0 && negative_d6.failed==0);
   SWV5S5_TestBasketConfirmationCrash(c,true);
   SWV5S5_TestBasketConfirmationCrash(c,false);
}
#endif
