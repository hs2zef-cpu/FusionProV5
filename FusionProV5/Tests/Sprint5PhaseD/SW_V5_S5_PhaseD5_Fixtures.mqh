#ifndef SW_V5_S5_PHASE_D5_FIXTURES_MQH
#define SW_V5_S5_PHASE_D5_FIXTURES_MQH
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.
// Included after PhaseD_Assertions. Compile-only; no entrypoint invokes these.

bool SWV5S5_D5BuildRestart(SWV5_ContractValidationContext &c,
   SWV5_RestartReconciliationInput &x,SWV5_PersistedRequestEvidence &requests[],
   SWV5S5_ReferenceGenesisRecord &g,SWV5_InstanceLease &lease,
   const bool zero_history=false,const bool renewed=false)
{
   ZeroMemory(c); ZeroMemory(x); ZeroMemory(g); ZeroMemory(lease);
   ArrayResize(requests,0);
   SWV5_TestMakeContext(c); SWV5_TestMakeRestartInput(x); SWV5_TestMakeLease(lease);
   ZeroMemory(x.persisted.latest_pending_request); // No phantom request in empty set.
   if(!SWV5_TestExecutionVersionExact(c,x.contract_version)) return false;
   lease.status=(renewed?SWV5_LOCK_RENEWED:SWV5_LOCK_ACQUIRED);
   if(!SWV5S5_ReferenceDeriveFenceToken(lease.fence,lease.fence.fencing_token_digest)) return false;
   x.claimant_fence=lease.fence;
   x.persisted.header.ownership_fence=lease.fence;
   x.persisted.basket.lifecycle.ownership_fence=lease.fence;
   x.persisted.reconciliation_vector.ownership_fence=lease.fence;
   // No fabricated closes/recovery history in the positive control.
   x.persisted.basket.initial_volume=0.30; x.persisted.basket.aggregate_closed_volume=0.0;
   x.persisted.basket.lifecycle.cumulative_recovery_attempts=0;
   x.persisted.basket.lifecycle.current_recovery_layer=0;
   x.persisted.basket.lifecycle.residual_volume=0.30;
   x.persisted.reconciliation_vector.residual_volume=0.30;
   x.broker.residual_volume=0.30;
   SWV5_PendingRequest empty[]; ArrayResize(empty,0);
   // Separate authority inputs derive the same set from their own empty sets.
   if(!SWV5S5_DeriveCompleteRequestSetDigest(empty,x.persisted.pending_request_set.request_set_digest)) return false;
   SWV5_PendingRequest execution_empty[]; ArrayResize(execution_empty,0);
   if(!SWV5S5_DeriveCompleteRequestSetDigest(execution_empty,x.restart_requests.request_set_digest)) return false;
   x.persisted.reconciliation_vector.request_set_digest=x.persisted.pending_request_set.request_set_digest;
   // Independently supplied release authority: never reconstructed in validator.
   SWV5_HardKillState independent_release; ZeroMemory(independent_release);
   SWV5_TestMakeValidHardKillRelease(independent_release);
   independent_release.state=SWV5_HARD_KILL_RELEASED;
   independent_release.release_generation=independent_release.release_evidence.release_generation;
   independent_release.release_evidence.exposure_evidence.observed_exposure_volume=0.30;
   independent_release.release_evidence.exposure_evidence.prior_exposure_volume=0.30;
   independent_release.release_evidence.release_record_digest=SWV5_TestHardKillReleaseDigest(independent_release.release_evidence);
   SWV5_TestMakeHardKillAuthorityRecord(independent_release,x.release_authority_record);
   SWV5_TestMakeValidHardKillRelease(x.persisted.hard_kill_state);
   x.persisted.hard_kill_state.state=SWV5_HARD_KILL_RELEASED;
   x.persisted.hard_kill_state.release_generation=x.persisted.hard_kill_state.release_evidence.release_generation;
   x.persisted.hard_kill_state.release_evidence.exposure_evidence.observed_exposure_volume=0.30;
   x.persisted.hard_kill_state.release_evidence.exposure_evidence.prior_exposure_volume=0.30;
   x.persisted.hard_kill_state.release_evidence.release_record_digest=SWV5_TestHardKillReleaseDigest(x.persisted.hard_kill_state.release_evidence);
   SWV5_TestBindHardKillAuthorityReference(x.persisted.hard_kill_state,x.release_authority_record);
   x.has_release_authority_record=true;
   SWV5S5_InitContractVersion(g.contract_version);
   g.state=SWV5S5_GENESIS_READY_FOR_RECONCILIATION;
   g.persistence_namespace=x.persistence_namespace; g.ownership_fence=lease.fence;
   g.genesis_id="D5-INDEPENDENT-GENESIS"; g.generation=1; g.revision=2;
   if(zero_history)
   {
      // A never-traded basket has neither initial nor closed volume.
      x.persisted.basket.initial_volume=0.0; x.persisted.basket.aggregate_closed_volume=0.0;
      if(!SWV5S5_D3MakeZeroHistoryRestart(x)) return false;
   }
   return SWV5S5_D2SealBrokerSummary(x.broker) &&
      SWV5S5_D2SealExecutionSummary(x.restart_requests) && SWV5S5_D3ResealCheckpoint(x);
}

bool SWV5S5_D5RestartPositive(const bool zero_history,const bool renewed)
{
   SWV5_ContractValidationContext c; SWV5_RestartReconciliationInput x;
   SWV5_PersistedRequestEvidence r[]; SWV5S5_ReferenceGenesisRecord g; SWV5_InstanceLease l;
   return SWV5S5_D5BuildRestart(c,x,r,g,l,zero_history,renewed) &&
      SWV5S5_D1PositiveRestartSafeToResume(c,x,r,g,l);
}
bool SWV5S5_D5PositiveOrdinaryAcquired(void) { return SWV5S5_D5RestartPositive(false,false); }
bool SWV5S5_D5PositiveOrdinaryRenewed(void) { return SWV5S5_D5RestartPositive(false,true); }
bool SWV5S5_D5PositiveZeroHistoryAcquired(void) { return SWV5S5_D5RestartPositive(true,false); }
bool SWV5S5_D5PositiveZeroHistoryRenewed(void) { return SWV5S5_D5RestartPositive(true,true); }
bool SWV5S5_D5PositiveReleasedHardKill(void)
{
   SWV5_ContractValidationContext c; SWV5_RestartReconciliationInput x;
   SWV5_PersistedRequestEvidence r[]; SWV5S5_ReferenceGenesisRecord g; SWV5_InstanceLease l;
   return SWV5S5_D5BuildRestart(c,x,r,g,l) &&
      SWV5S5_ReferencePersistedReleaseEvidenceValid(x.persisted.hard_kill_state,c) &&
      SWV5S5_ReferenceReleaseAuthorityValid(x.release_authority_record,x.persisted,c) &&
      SWV5S5_D1PositiveRestartSafeToResume(c,x,r,g,l);
}
bool SWV5S5_D5PositiveProductionSchema(void)
{
   SWV5_ContractValidationContext c; SWV5_RestartReconciliationInput x;
   SWV5_PersistedRequestEvidence r[]; SWV5S5_ReferenceGenesisRecord g; SWV5_InstanceLease l;
   return SWV5S5_D5BuildRestart(c,x,r,g,l) &&
      SWV5_TestExecutionVersionExact(c,x.contract_version) &&
      SWV5S5_D1PositiveRestartSafeToResume(c,x,r,g,l);
}
bool SWV5S5_D5RejectVersion(const int mutation)
{
   SWV5_ContractValidationContext c; SWV5_RestartReconciliationInput x;
   SWV5_PersistedRequestEvidence r[]; SWV5S5_ReferenceGenesisRecord g; SWV5_InstanceLease l;
   if(!SWV5S5_D5BuildRestart(c,x,r,g,l) || !SWV5S5_D1PositiveRestartSafeToResume(c,x,r,g,l)) return false;
   if(mutation==0) SWV5S5_InitContractVersion(x.contract_version);
   else if(mutation==1) x.contract_version.schema_version--;
   else if(mutation==2) x.contract_version.minimum_compatible_version--;
   else if(mutation==3) x.contract_version.policy_id="FOREIGN-POLICY";
   else if(mutation==4) x.contract_version.contract_name="FOREIGN-CONTRACT";
   else return false;
   SWV5S5_ReferenceRestartResult out;
   return !SWV5_TestExecutionVersionExact(c,x.contract_version) &&
      !SWV5S5_D1Restart(c,x,r,g,l,out) && !out.increasing_execution_eligible &&
      out.diagnostic=="SCHEMA_GENESIS_PERSISTENCE_OR_OWNER_INVALID";
}
bool SWV5S5_D5NegativeCandidateV3(void) { return SWV5S5_D5RejectVersion(0); }
bool SWV5S5_D5NegativeWrongSchema(void) { return SWV5S5_D5RejectVersion(1); }
bool SWV5S5_D5NegativeWrongMinimum(void) { return SWV5S5_D5RejectVersion(2); }
bool SWV5S5_D5NegativeWrongPolicy(void) { return SWV5S5_D5RejectVersion(3); }
bool SWV5S5_D5NegativeWrongContract(void) { return SWV5S5_D5RejectVersion(4); }

bool SWV5S5_D5PositiveCheckpointReseal(void)
{
   SWV5_ContractValidationContext c; SWV5_RestartReconciliationInput x;
   SWV5_PersistedRequestEvidence r[]; SWV5S5_ReferenceGenesisRecord g; SWV5_InstanceLease l;
   if(!SWV5S5_D5BuildRestart(c,x,r,g,l) || !SWV5S5_D1PositiveRestartSafeToResume(c,x,r,g,l)) return false;
   if(!SWV5S5_ReferenceCheckpointProductionIntegrityValid(x.persisted,c)) return false;
   x.persisted.basket.lifecycle.state_version++;
   x.persisted.reconciliation_vector.basket_state_version=x.persisted.basket.lifecycle.state_version;
   if(SWV5S5_ReferenceCheckpointProductionIntegrityValid(x.persisted,c)) return false;
   return SWV5S5_D3ResealCheckpoint(x) &&
      SWV5S5_ReferenceCheckpointProductionIntegrityValid(x.persisted,c) &&
      SWV5S5_D1PositiveRestartSafeToResume(c,x,r,g,l);
}
bool SWV5S5_D5BuildTakeover(SWV5_InstanceLease &lease,SWV5S5_ReferenceClockObservation &clock,
                             SWV5_OwnershipClaim &claim)
{
   ZeroMemory(lease); ZeroMemory(clock); ZeroMemory(claim);
   SWV5_TestMakeLease(lease,SWV5_LOCK_EXPIRED);
   lease.expiry_clock_sequence=950; lease.expires_at=SWV5_TEST_TIME-1;
   clock.clock_id=lease.clock_id; clock.authority=lease.clock_authority;
   clock.source_symbol=lease.fence.ownership_namespace.symbol;
   clock.observation_sequence=1000; clock.observed_at=SWV5_TEST_TIME;
   clock.event_identity="D5-TAKEOVER-CLOCK"; clock.current_event_provenance=true;
   return SWV5S5_ReferenceDeriveFenceToken(lease.fence,lease.fence.fencing_token_digest);
}

bool SWV5S5_D5RebindTakeover(const SWV5_InstanceLease &lease,
   const SWV5S5_ReferenceClockObservation &clock,SWV5_OwnershipClaim &claim)
{
   SWV5_TestMakeClaim(claim,lease);
   claim.takeover_evidence.lease_expiry.observed_clock_sequence=clock.observation_sequence;
   claim.takeover_evidence.observed_clock_sequence=clock.observation_sequence;
   claim.takeover_evidence.broker_reconciliation.observed_at=clock.observed_at;
   claim.takeover_evidence.persistence_reconciliation.observed_at=clock.observed_at;
   return SWV5S5_SHA256("D5-BROKER-"+lease.fence.fencing_token_digest,
         claim.takeover_evidence.broker_reconciliation.state_digest) &&
      SWV5S5_SHA256("D5-PERSISTENCE-"+lease.fence.fencing_token_digest,
         claim.takeover_evidence.persistence_reconciliation.state_digest);
}

bool SWV5S5_D5PositiveTakeover(void)
{
   SWV5_InstanceLease lease; SWV5S5_ReferenceClockObservation clock; SWV5_OwnershipClaim claim;
   return SWV5S5_D5BuildTakeover(lease,clock,claim) && SWV5S5_D5RebindTakeover(lease,clock,claim) &&
      SWV5S5_D1PositiveTakeover(lease,clock,claim);
}

bool SWV5S5_D5RejectZeroEpoch(const bool zero_lease,const bool zero_generation)
{
   SWV5_InstanceLease lease; SWV5S5_ReferenceClockObservation candidate; SWV5_OwnershipClaim claim;
   if(!SWV5S5_D5BuildTakeover(lease,candidate,claim) || !SWV5S5_D5RebindTakeover(lease,candidate,claim) ||
      !SWV5S5_D1PositiveTakeover(lease,candidate,claim)) return false;
   if(zero_lease) lease.fence.lease_version=0;
   if(zero_generation) lease.fence.takeover_generation=0;
   if(!SWV5S5_ReferenceDeriveFenceToken(lease.fence,lease.fence.fencing_token_digest) ||
      !SWV5S5_D5RebindTakeover(lease,candidate,claim)) return false;
   // BuildRow/Seed verify fresh canonical row and token; no stale-digest escape.
   SWV5S5_ReferenceLeaseStore store; SWV5S5_FakeAuthoritativeClock clock;
   clock.Configure(candidate.clock_id,candidate.authority,candidate.source_symbol);
   SWV5S5_ReferenceClockObservation accepted; SWV5S5_ReferenceTransactionResult tx;
   SWV5_InstanceLease result,loaded;
   if(!store.SeedObservedLeaseForVerification(lease,claim.takeover_evidence.persistence_reconciliation.persistence_namespace) ||
      !clock.AcceptAndSeal(candidate,accepted)) return false;
   string before,after,namespace_digest,fence_digest;
   if(!SWV5S5_ReferenceCanonicalLease(lease,before,namespace_digest,fence_digest)) return false;
   return !SWV5_TestFenceComplete(lease.fence) &&
      !store.Takeover(clock,accepted,claim,result,tx) && store.Load(loaded) &&
      SWV5S5_ReferenceCanonicalLease(loaded,after,namespace_digest,fence_digest) && before==after;
}
bool SWV5S5_D5NegativeZeroLeaseVersion(void) { return SWV5S5_D5RejectZeroEpoch(true,false); }
bool SWV5S5_D5NegativeZeroTakeoverGeneration(void) { return SWV5S5_D5RejectZeroEpoch(false,true); }
bool SWV5S5_D5NegativeBothZeroEpochs(void) { return SWV5S5_D5RejectZeroEpoch(true,true); }

bool SWV5S5_D5BuildRestartWithRequests(SWV5_ContractValidationContext &c,SWV5_RestartReconciliationInput &x,
   SWV5_PersistedRequestEvidence &r[],SWV5S5_ReferenceGenesisRecord &g,SWV5_InstanceLease &l)
{
   if(!SWV5S5_D5BuildRestart(c,x,r,g,l)) return false;
   ArrayResize(r,2); SWV5_PendingRequest pending[]; ArrayResize(pending,2);
   for(int i=0;i<2;i++)
   {
      ZeroMemory(r[i]); SWV5_TestMakePersistedRequest(r[i],i+1);
      r[i].ownership_fence=l.fence; r[i].pending_request.intent.ownership_fence=l.fence;
      r[i].record_sequence=10+(ulong)i; r[i].recorded_at=SWV5_TEST_TIME-20+i;
      r[i].pending_request.state=SWV5_REQUEST_CONFIRMED;
      r[i].pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_COMPLETED;
      r[i].pending_request.cumulative_confirmed_volume=r[i].pending_request.intent.normalized_volume;
      r[i].pending_request.residual_requested_volume=0.0;
      r[i].pending_request.latest_retcode.ownership_fence=l.fence;
      SWV5_TestMakeCorrelation(r[i].pending_request.latest_authoritative_confirmation.correlation,396+(ulong)i);
      r[i].pending_request.latest_authoritative_confirmation.correlation.request_identity=r[i].pending_request.intent.request_identity;
      r[i].pending_request.latest_authoritative_confirmation.status=SWV5_CONFIRMATION_CONFIRMED;
      r[i].pending_request.latest_authoritative_confirmation.cumulative_confirmed_volume=r[i].pending_request.intent.normalized_volume;
      r[i].pending_request.latest_authoritative_confirmation.residual_volume=0.0;
      r[i].pending_request.latest_authoritative_confirmation.authority=SWV5_AUTHORITY_TRANSACTION_EVENT;
      r[i].pending_request.latest_authoritative_confirmation.confirmation_sequence=396+(ulong)i;
      r[i].pending_request.latest_authoritative_confirmation.confirmed_at=SWV5_TEST_TIME-25+i;
      r[i].pending_request.last_changed_at=SWV5_TEST_TIME-25+i;
      r[i].pending_request.latest_submission.submitted_at=SWV5_TEST_TIME-40+i;
      r[i].pending_request.latest_retcode.observed_at=SWV5_TEST_TIME-35+i;
      pending[i]=r[i].pending_request;
   }
   string digest; if(!SWV5S5_DeriveCompleteRequestSetDigest(pending,digest)) return false;
   x.persisted.pending_request_set.request_count=2; x.persisted.pending_request_set.request_set_digest=digest;
   x.persisted.basket.lifecycle.pending_request_count=2;
   x.persisted.reconciliation_vector.pending_request_count=2; x.persisted.reconciliation_vector.request_set_digest=digest;
   x.restart_requests.pending_request_count=2; x.restart_requests.request_set_digest=digest;
   x.persisted.latest_pending_request=r[1]; x.persisted.has_latest_pending_request=true;
   return SWV5S5_D2SealExecutionSummary(x.restart_requests) && SWV5S5_D3ResealCheckpoint(x);
}
bool SWV5S5_D5PositiveCompleteRequestArray(void)
{
   SWV5_ContractValidationContext c; SWV5_RestartReconciliationInput x;
   SWV5_PersistedRequestEvidence r[]; SWV5S5_ReferenceGenesisRecord g; SWV5_InstanceLease l;
   return SWV5S5_D5BuildRestartWithRequests(c,x,r,g,l) && SWV5S5_D1PositiveRestartSafeToResume(c,x,r,g,l) &&
      SWV5S5_D2NegativeRestartUnsafeSecondRequest(c,x,r,g,l) && SWV5S5_D1NegativeRestartClaimedUnresolved(c,x,r,g,l);
}

bool SWV5S5_D5RejectWrongDigestRepresentation(const int field,const bool sha256)
{
   SWV5_ContractValidationContext c; SWV5_RestartReconciliationInput x;
   SWV5_PersistedRequestEvidence r[]; SWV5S5_ReferenceGenesisRecord g; SWV5_InstanceLease l;
   if(!SWV5S5_D5BuildRestart(c,x,r,g,l) || !SWV5S5_D1PositiveRestartSafeToResume(c,x,r,g,l)) return false;
   string wrong="0";
   if(sha256 && !SWV5S5_SHA256("D5-UNRELATED-DOMAIN",wrong)) return false;
   if(field==0) x.persisted.header.payload_digest=wrong;
   else if(field==1) x.persisted.reconciliation_vector.source_summary_digest=wrong;
   else if(field==2) x.persisted.hard_kill_state.release_evidence.release_record_digest=wrong;
   else if(field==3)
   { x.release_authority_record.authority_record_digest=wrong; x.persisted.hard_kill_state.release_authority_reference.authority_record_digest=wrong; }
   else return false;
   if(field!=0) SWV5_TestSealCheckpoint(x.persisted); // Preserve intended inner corruption.
   SWV5S5_ReferenceRestartResult out;
   return !SWV5S5_D1Restart(c,x,r,g,l,out) && !out.increasing_execution_eligible;
}
bool SWV5S5_D5NegativeCheckpointSha256(void) { return SWV5S5_D5RejectWrongDigestRepresentation(0,true); }
bool SWV5S5_D5NegativeSourceSha256(void) { return SWV5S5_D5RejectWrongDigestRepresentation(1,true); }
bool SWV5S5_D5NegativeReleaseSha256(void) { return SWV5S5_D5RejectWrongDigestRepresentation(2,true); }
bool SWV5S5_D5NegativeAuthoritySha256(void) { return SWV5S5_D5RejectWrongDigestRepresentation(3,true); }
bool SWV5S5_D5NegativeCheckpointNumeric(void) { return SWV5S5_D5RejectWrongDigestRepresentation(0,false); }
bool SWV5S5_D5NegativeSourceNumeric(void) { return SWV5S5_D5RejectWrongDigestRepresentation(1,false); }
bool SWV5S5_D5NegativeReleaseNumeric(void) { return SWV5S5_D5RejectWrongDigestRepresentation(2,false); }
bool SWV5S5_D5NegativeAuthorityNumeric(void) { return SWV5S5_D5RejectWrongDigestRepresentation(3,false); }
// TEST ONLY source call graph: all 79 affected negatives, with complete
// positive baselines. Not invoked by OnStart; source/compile evidence only.
bool SWV5S5_D5AffectedRestartProbeMatrix(uint &failed)
{
   failed=0;
   SWV5_ContractValidationContext c; SWV5_RestartReconciliationInput x;
   SWV5_PersistedRequestEvidence r[]; SWV5S5_ReferenceGenesisRecord g; SWV5_InstanceLease l;
   if(!SWV5S5_D5BuildRestart(c,x,r,g,l) || !SWV5S5_D1PositiveRestartSafeToResume(c,x,r,g,l)) return false;
   if(!SWV5S5_D1NegativeRestartWrongRequestSetDigest(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartWrongRequestRevision(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartWrongCheckpoint(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartWrongBasket(c,x,r,g,l)) failed++;
   if(!SWV5S5_D2NegativeRestartWrongAccountMode(c,x,r,g,l)) failed++;
   if(!SWV5S5_D2NegativeRestartWrongQueryProvenance(c,x,r,g,l)) failed++;
   if(!SWV5S5_D2NegativeRestartWrongTransactionHwm(c,x,r,g,l)) failed++;
   if(!SWV5S5_D2NegativeRestartWrongCorrelation(c,x,r,g,l)) failed++;
   if(!SWV5S5_D2NegativeRestartExecutionCount(c,x,r,g,l)) failed++;
   if(!SWV5S5_D2NegativeRestartExecutionRevision(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartWrongFence(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartCorruptBrokerDigest(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartCorruptExecutionDigest(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartStaleQuery(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartFutureQuery(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartActiveHardKill(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartInvalidReleaseDigest(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartWrongReleaseNamespace(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartWrongReleaseLatch(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartWrongReleaseGeneration(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartWrongReleaseAccount(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartWrongReleaseOperator(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartWrongReleaseEvidence(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartExpiredRelease(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartWrongReleaseSequence(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartWrongReleasePolicy(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartWrongReleaseVersion(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeRestartReconciliationRequired(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeRestartResealedBasketState(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeRestartResealedBasketVersion(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeRestartResealedHardKillGeneration(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeRestartSourceDigestContradiction(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeRestartWrongProductionPayload(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeRestartWrongReleaseReferenceVersion(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeRestartFutureEffectiveRelease(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativePersistedReleaseDigest(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativePersistedReleaseAudit(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativePersistedReleaseGeneration(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeZeroHistoryWithIdentity(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeZeroHistoryNonzeroExposure(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeZeroHistoryNonzeroHwm(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeZeroHistoryPosition(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeZeroPriorOrderCount(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeZeroHistoryStaleQuery(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeZeroHistoryWrongNamespace(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeZeroHistoryWrongFence(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeZeroHistoryFakeCorrelation(c,x,r,g,l)) failed++;
   if(!SWV5S5_D3NegativeZeroHistoryMissingQuery(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeRestartUnclaimedLease(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeRestartExpiredLease(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeRestartReleasedLease(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeRestartCorruptLease(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeZeroHistoryUnclaimedLease(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeZeroHistoryExpiredLease(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeZeroHistoryReleasedLease(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeZeroHistoryCorruptLease(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeRestartInvalidBasketState(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeRestartZeroBasketVersion(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeRestartNetVolumeEquation(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeRestartBrokerTickets(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeRestartTransactionHwmIdentity(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeRestartInvalidHardKillState(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeReleasePolicy(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeReleaseObservedExposure(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeReleasePriorExposure(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeReleaseIncreasingExposure(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeReleaseBrokerBeforeAuthentication(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeReleasePersistenceBeforeAuthentication(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeReleaseExposureBeforeAuthentication(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeReleaseIncompleteAccount(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeReleaseForeignAccount(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeInactiveReleaseEnvelope(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeActiveReleaseEnvelope(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativePendingReleaseEnvelope(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeReleasedGeneration(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeZeroHistoryIncompleteOwner(c,x,r,g,l)) failed++;
   if(!SWV5S5_D4NegativeZeroHistoryWrongClock(c,x,r,g,l)) failed++;
   if(!SWV5S5_D5BuildRestartWithRequests(c,x,r,g,l) || !SWV5S5_D1PositiveRestartSafeToResume(c,x,r,g,l)) return false;
   if(!SWV5S5_D2NegativeRestartUnsafeSecondRequest(c,x,r,g,l)) failed++;
   if(!SWV5S5_D1NegativeRestartClaimedUnresolved(c,x,r,g,l)) failed++;
   return failed==0;
}
#endif
