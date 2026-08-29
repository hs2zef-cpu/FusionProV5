#ifndef SW_V5_S5_PHASE_D_ASSERTIONS_MQH
#define SW_V5_S5_PHASE_D_ASSERTIONS_MQH

// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// Direct function-level compile probes. They are deliberately never executed.
#include "../../ExecutionLayer/PersistenceReference/SW_V5_S5_PersistenceReference.mqh"

bool SWV5S5_D1MakeCasRows(SWV5S5_ReferenceDomainRow &current,SWV5S5_ReferenceDomainRow &proposed)
{
   ZeroMemory(current); current.domain=SWV5S5_REF_DOMAIN_LEDGER; current.persistence_namespace_digest="NS";
   current.store_revision=1; current.authority_fence_digest="FENCE"; current.payload="CANONICAL";
   if(!SWV5S5_ReferenceCanonicalPayloadDigest(current.domain,current.payload,current.payload_digest)) return false;
   proposed=current; proposed.store_revision=2; proposed.payload="CANONICAL-2";
   return SWV5S5_ReferenceCanonicalPayloadDigest(proposed.domain,proposed.payload,proposed.payload_digest);
}

bool SWV5S5_D1PositiveCasCommit(void)
{
   SWV5S5_FakeTransactionalStore store; SWV5S5_ReferenceDomainRow current,proposed;
   SWV5S5_ReferenceTransactionResult result;
   return SWV5S5_D1MakeCasRows(current,proposed) && store.Seed(current) &&
      store.CompareAndSet(current.domain,"NS",1,current.payload_digest,"FENCE",proposed,SWV5S5_REF_FAULT_NONE,result) &&
      result.this_transaction_won;
}

bool SWV5S5_D1NegativeCasWrongNamespace(void)
{ SWV5S5_FakeTransactionalStore s; SWV5S5_ReferenceDomainRow a,b; SWV5S5_ReferenceTransactionResult r; return SWV5S5_D1MakeCasRows(a,b)&&s.Seed(a)&&!s.CompareAndSet(a.domain,"FOREIGN",1,a.payload_digest,"FENCE",b,SWV5S5_REF_FAULT_NONE,r); }
bool SWV5S5_D1NegativeCasPayloadTamper(void)
{ SWV5S5_FakeTransactionalStore s; SWV5S5_ReferenceDomainRow a,b; SWV5S5_ReferenceTransactionResult r; if(!SWV5S5_D1MakeCasRows(a,b)||!s.Seed(a)) return false; return s.InjectStoredPayloadWithoutDigest(a.domain,"TAMPER")&&!s.CompareAndSet(a.domain,"NS",1,a.payload_digest,"FENCE",b,SWV5S5_REF_FAULT_NONE,r); }
bool SWV5S5_D1NegativeCasStaleDigest(void)
{ SWV5S5_FakeTransactionalStore s; SWV5S5_ReferenceDomainRow a,b; SWV5S5_ReferenceTransactionResult r; return SWV5S5_D1MakeCasRows(a,b)&&s.Seed(a)&&!s.CompareAndSet(a.domain,"NS",1,"STALE","FENCE",b,SWV5S5_REF_FAULT_NONE,r); }
bool SWV5S5_D1NegativeCasStaleRevision(void)
{ SWV5S5_FakeTransactionalStore s; SWV5S5_ReferenceDomainRow a,b; SWV5S5_ReferenceTransactionResult r; return SWV5S5_D1MakeCasRows(a,b)&&s.Seed(a)&&!s.CompareAndSet(a.domain,"NS",0,a.payload_digest,"FENCE",b,SWV5S5_REF_FAULT_NONE,r); }
bool SWV5S5_D1NegativeCasStaleFence(void)
{ SWV5S5_FakeTransactionalStore s; SWV5S5_ReferenceDomainRow a,b; SWV5S5_ReferenceTransactionResult r; return SWV5S5_D1MakeCasRows(a,b)&&s.Seed(a)&&!s.CompareAndSet(a.domain,"NS",1,a.payload_digest,"STALE",b,SWV5S5_REF_FAULT_NONE,r); }
bool SWV5S5_D1NegativeCasUncertainCommit(void)
{ SWV5S5_FakeTransactionalStore s; SWV5S5_ReferenceDomainRow a,b; SWV5S5_ReferenceTransactionResult r; return SWV5S5_D1MakeCasRows(a,b)&&s.Seed(a)&&!s.CompareAndSet(a.domain,"NS",1,a.payload_digest,"FENCE",b,SWV5S5_REF_FAULT_AFTER_DURABLE_COMMIT,r)&&r.disposition==SWV5S5_REF_COMMIT_OUTCOME_UNCERTAIN&&!r.this_transaction_won; }

bool SWV5S5_D1InvokeClaim(const SWV5S5_InvocationClaimCommand &valid_command,
                         const SWV5S5_InvocationClaimCommand &operation,
                         const SWV5S5_InvocationClaimTransition &transition,
                         const SWV5S5_ReferenceFaultPoint fault)
{
   SWV5S5_ReferenceSubmissionStore store; SWV5S5_InvocationClaimResult result; SWV5S5_ReferenceTransactionResult tx;
   if(!store.Initialize(valid_command.expected_authority_record)) return false;
   return store.TryClaimInvocation(operation,transition,fault,result,tx);
}

bool SWV5S5_D1PositiveClaim(const SWV5S5_InvocationClaimCommand &command,const SWV5S5_InvocationClaimTransition &transition)
{ return SWV5S5_D1InvokeClaim(command,command,transition,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D1NegativeClaimStaleEventReplay(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; x.command_digest="STALE-EVENT"; return !SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D1NegativeClaimWrongClaimId(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; x.claim_id="WRONG-CLAIM"; return !SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D1NegativeClaimWrongClock(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; x.claim_clock.clock_id="WRONG-CLOCK"; return !SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D1NegativeClaimWrongAdmissionSnapshot(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; x.admission_proof.snapshot.canonical_policy_id+="-WRONG"; return !SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D1NegativeClaimWrongSnapshotDigest(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; x.admission_proof.snapshot.snapshot_digest="WRONG-DIGEST"; return !SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D1NegativeClaimWrongPermit(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; x.expected_authority_record.permit.permit_id="WRONG-PERMIT"; return !SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D1NegativeClaimWrongRisk(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; x.expected_authority_record.permit.risk_authorization.authorization_id="WRONG-RISK"; return !SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D1NegativeClaimWrongNormalization(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; x.expected_authority_record.permit.normalization_identity="WRONG-NORMALIZATION"; return !SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D1NegativeClaimWrongFence(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; x.current_ownership_lease.fence.lease_version++; return !SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D1NegativeClaimWrongTakeover(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; x.current_ownership_lease.fence.takeover_generation++; return !SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D1NegativeClaimStaleRevision(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; x.expected_authority_revision--; return !SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D1NegativeClaimAlreadyClaimed(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{
   SWV5S5_ReferenceSubmissionStore store; SWV5S5_InvocationClaimResult result; SWV5S5_ReferenceTransactionResult tx;
   if(!store.Initialize(v.expected_authority_record) ||
      !store.TryClaimInvocation(v,t,SWV5S5_REF_FAULT_NONE,result,tx)) return false;
   return !store.TryClaimInvocation(v,t,SWV5S5_REF_FAULT_NONE,result,tx) && !result.claim_granted_now;
}
bool SWV5S5_D1NegativeClaimUncertain(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ return !SWV5S5_D1InvokeClaim(v,v,t,SWV5S5_REF_FAULT_AFTER_DURABLE_COMMIT); }

bool SWV5S5_D1RunTakeover(const SWV5_InstanceLease &observed,const SWV5S5_ReferenceClockObservation &candidate,
                          const SWV5_OwnershipClaim &claim,SWV5S5_ReferenceClockObservation &validated)
{
   SWV5S5_ReferenceLeaseStore store; SWV5S5_FakeAuthoritativeClock clock; SWV5_InstanceLease result;
   SWV5S5_ReferenceTransactionResult tx;
   clock.Configure(candidate.clock_id,candidate.authority,candidate.source_symbol);
   if(!store.Initialize(observed) || !clock.AcceptAndSeal(candidate,validated)) return false;
   return store.Takeover(clock,validated,claim,result,tx);
}

bool SWV5S5_D1PositiveTakeover(const SWV5_InstanceLease &observed,const SWV5S5_ReferenceClockObservation &candidate,const SWV5_OwnershipClaim &claim)
{ SWV5S5_ReferenceClockObservation v; return SWV5S5_D1RunTakeover(observed,candidate,claim,v); }
bool SWV5S5_D1NegativeTakeoverInvalidClockToken(const SWV5_InstanceLease &o,const SWV5S5_ReferenceClockObservation &c,const SWV5_OwnershipClaim &q)
{
   SWV5S5_ReferenceLeaseStore s; SWV5S5_FakeAuthoritativeClock k; SWV5S5_ReferenceClockObservation v;
   SWV5_InstanceLease z; SWV5S5_ReferenceTransactionResult tx;
   k.Configure(c.clock_id,c.authority,c.source_symbol);
   if(!s.Initialize(o) || !k.AcceptAndSeal(c,v)) return false;
   v.validation_digest="FORGED";
   return !s.Takeover(k,v,q,z,tx);
}
bool SWV5S5_D1NegativeTakeoverForeignNamespace(const SWV5_InstanceLease &o,const SWV5S5_ReferenceClockObservation &c,const SWV5_OwnershipClaim &q)
{ SWV5_OwnershipClaim x=q; x.takeover_evidence.broker_reconciliation.persistence_namespace.basket_id.value="FOREIGN"; SWV5S5_ReferenceClockObservation v; return !SWV5S5_D1RunTakeover(o,c,x,v); }
bool SWV5S5_D1NegativeTakeoverWrongOwner(const SWV5_InstanceLease &o,const SWV5S5_ReferenceClockObservation &c,const SWV5_OwnershipClaim &q)
{ SWV5_OwnershipClaim x=q; x.takeover_evidence.observed_owner.instance_id="WRONG"; SWV5S5_ReferenceClockObservation v; return !SWV5S5_D1RunTakeover(o,c,x,v); }
bool SWV5S5_D1NegativeTakeoverStaleStoreRevision(const SWV5_InstanceLease &o,const SWV5S5_ReferenceClockObservation &c,const SWV5_OwnershipClaim &q)
{ SWV5_OwnershipClaim x=q; x.expected_store_revision="STALE"; SWV5S5_ReferenceClockObservation v; return !SWV5S5_D1RunTakeover(o,c,x,v); }
bool SWV5S5_D1NegativeTakeoverWrongFence(const SWV5_InstanceLease &o,const SWV5S5_ReferenceClockObservation &c,const SWV5_OwnershipClaim &q)
{ SWV5_OwnershipClaim x=q; x.expected_fence.lease_version++; SWV5S5_ReferenceClockObservation v; return !SWV5S5_D1RunTakeover(o,c,x,v); }
bool SWV5S5_D1NegativeTakeoverWrongLeaseVersion(const SWV5_InstanceLease &o,const SWV5S5_ReferenceClockObservation &c,const SWV5_OwnershipClaim &q)
{ SWV5_OwnershipClaim x=q; x.takeover_evidence.lease_expiry.observed_lease_version++; SWV5S5_ReferenceClockObservation v; return !SWV5S5_D1RunTakeover(o,c,x,v); }
bool SWV5S5_D1NegativeTakeoverWrongGeneration(const SWV5_InstanceLease &o,const SWV5S5_ReferenceClockObservation &c,const SWV5_OwnershipClaim &q)
{ SWV5_OwnershipClaim x=q; x.takeover_evidence.proposed_takeover_generation++; SWV5S5_ReferenceClockObservation v; return !SWV5S5_D1RunTakeover(o,c,x,v); }
bool SWV5S5_D1NegativeTakeoverWrongClockAuthority(const SWV5_InstanceLease &o,const SWV5S5_ReferenceClockObservation &c,const SWV5_OwnershipClaim &q)
{ SWV5_OwnershipClaim x=q; x.takeover_evidence.observed_clock_authority=SWV5_TIME_AUTHORITY_NONE; SWV5S5_ReferenceClockObservation v; return !SWV5S5_D1RunTakeover(o,c,x,v); }
bool SWV5S5_D1NegativeTakeoverStaleSequence(const SWV5_InstanceLease &o,const SWV5S5_ReferenceClockObservation &c,const SWV5_OwnershipClaim &q)
{ SWV5_OwnershipClaim x=q; x.takeover_evidence.observed_clock_sequence--; SWV5S5_ReferenceClockObservation v; return !SWV5S5_D1RunTakeover(o,c,x,v); }
bool SWV5S5_D1NegativeTakeoverInvalidBrokerReconciliation(const SWV5_InstanceLease &o,const SWV5S5_ReferenceClockObservation &c,const SWV5_OwnershipClaim &q)
{ SWV5_OwnershipClaim x=q; x.takeover_evidence.broker_reconciliation.state_digest=""; SWV5S5_ReferenceClockObservation v; return !SWV5S5_D1RunTakeover(o,c,x,v); }
bool SWV5S5_D1NegativeTakeoverInvalidPersistenceReconciliation(const SWV5_InstanceLease &o,const SWV5S5_ReferenceClockObservation &c,const SWV5_OwnershipClaim &q)
{ SWV5_OwnershipClaim x=q; x.takeover_evidence.persistence_reconciliation.state_digest=""; SWV5S5_ReferenceClockObservation v; return !SWV5S5_D1RunTakeover(o,c,x,v); }
bool SWV5S5_D1NegativeTakeoverInvalidIndependentAuthority(const SWV5_InstanceLease &o,const SWV5S5_ReferenceClockObservation &c,const SWV5_OwnershipClaim &q)
{ SWV5_OwnershipClaim x=q; x.takeover_evidence.independent_authority_source=SWV5_AUTHORITY_NONE; SWV5S5_ReferenceClockObservation v; return !SWV5S5_D1RunTakeover(o,c,x,v); }

bool SWV5S5_D1GenesisDuplicateMutation(const SWV5S5_ReferenceGenesisRequest &valid,const SWV5S5_ReferenceGenesisRequest &changed)
{ SWV5S5_ReferenceGenesis g; bool idempotent=false; return g.BeginProvisioning(valid,idempotent)&&!g.BeginProvisioning(changed,idempotent)&&!idempotent; }
bool SWV5S5_D1PositiveGenesisExactDuplicate(const SWV5S5_ReferenceGenesisRequest &v)
{ SWV5S5_ReferenceGenesis g; bool i=false; return g.BeginProvisioning(v,i)&&g.BeginProvisioning(v,i)&&i; }
bool SWV5S5_D1NegativeGenesisIncompleteOperator(const SWV5S5_ReferenceGenesisRequest &v)
{ SWV5S5_ReferenceGenesisRequest x=v; x.operator_identity.authority_role=""; SWV5S5_ReferenceGenesis g; bool i=false; return !g.BeginProvisioning(x,i); }
bool SWV5S5_D1NegativeGenesisChangedPolicy(const SWV5S5_ReferenceGenesisRequest &v)
{ SWV5S5_ReferenceGenesisRequest x=v; x.genesis_policy_id+="-CHANGED"; return SWV5S5_D1GenesisDuplicateMutation(v,x); }
bool SWV5S5_D1NegativeGenesisChangedComponent(const SWV5S5_ReferenceGenesisRequest &v)
{ SWV5S5_ReferenceGenesisRequest x=v; x.authority_component=SWV5_COMPONENT_AUTHORITY_PERSISTENCE; return SWV5S5_D1GenesisDuplicateMutation(v,x); }
bool SWV5S5_D1NegativeGenesisChangedSource(const SWV5S5_ReferenceGenesisRequest &v)
{ SWV5S5_ReferenceGenesisRequest x=v; x.authority_source=SWV5_AUTHORITY_PERSISTED_CHECKPOINT; return SWV5S5_D1GenesisDuplicateMutation(v,x); }
bool SWV5S5_D1NegativeGenesisChangedOperator(const SWV5S5_ReferenceGenesisRequest &v)
{ SWV5S5_ReferenceGenesisRequest x=v; x.operator_identity.authority_role+="-CHANGED"; return SWV5S5_D1GenesisDuplicateMutation(v,x); }
bool SWV5S5_D1NegativeGenesisChangedAuthReference(const SWV5S5_ReferenceGenesisRequest &v)
{ SWV5S5_ReferenceGenesisRequest x=v; x.operator_identity.authentication_reference+="-CHANGED"; return SWV5S5_D1GenesisDuplicateMutation(v,x); }
bool SWV5S5_D1NegativeGenesisChangedAuthenticatedAt(const SWV5S5_ReferenceGenesisRequest &v)
{ SWV5S5_ReferenceGenesisRequest x=v; x.operator_identity.authenticated_at++; return SWV5S5_D1GenesisDuplicateMutation(v,x); }
bool SWV5S5_D1NegativeGenesisChangedClock(const SWV5S5_ReferenceGenesisRequest &v)
{ SWV5S5_ReferenceGenesisRequest x=v; x.creation_clock_sequence++; return SWV5S5_D1GenesisDuplicateMutation(v,x); }
bool SWV5S5_D1NegativeGenesisChangedNamespace(const SWV5S5_ReferenceGenesisRequest &v)
{ SWV5S5_ReferenceGenesisRequest x=v; x.persistence_namespace.basket_id.value+="-CHANGED"; return SWV5S5_D1GenesisDuplicateMutation(v,x); }
bool SWV5S5_D1NegativeGenesisChangedFence(const SWV5S5_ReferenceGenesisRequest &v)
{ SWV5S5_ReferenceGenesisRequest x=v; x.ownership_fence.lease_version++; return SWV5S5_D1GenesisDuplicateMutation(v,x); }
bool SWV5S5_D1NegativeGenesisPartial(const SWV5S5_ReferenceGenesisRequest &v)
{ SWV5S5_ReferenceGenesis g; bool i=false; return g.BeginProvisioning(v,i)&&!g.Finalize(); }
bool SWV5S5_D1NegativeGenesisDigestValidWrongDomain(
   const SWV5S5_ReferenceGenesisRequest &v,const SWV5_InstanceLease &lease,
   const SWV5S5_IngressLedgerHeader &ledger_header,const SWV5S5_IngressLedgerIndexEntry &ledger_index[],
   const SWV5S5_IngressLedgerRecord &ledger_records[],const SWV5S5_RequestSequenceAuthority &sequence,
   const SWV5S5_RequestSequenceIndexEntry &sequence_index[],const SWV5S5_ReferenceSubmissionJournal &valid_journal,
   const SWV5S5_RequestSetPublicationAuthority &request_authority,const SWV5_PendingRequest &requests[],
   const SWV5_PersistedCheckpoint &checkpoint)
{
   SWV5S5_ReferenceGenesis g; bool i=false; SWV5S5_ReferenceSubmissionJournal x=valid_journal; string preimage;
   if(!g.BeginProvisioning(v,i) || !g.InitializeLease(lease) ||
      !g.InitializeLedger(ledger_header,ledger_index,ledger_records) ||
      !g.InitializeSequence(sequence,sequence_index) || !g.InitializeSubmission(valid_journal) ||
      !g.InitializeRequestSet(request_authority,requests) || !g.InitializeCheckpoint(checkpoint)) return false;
   x.manifest_digest+="-WRONG"; x.journal_digest="";
   if(!SWV5S5_ReferenceSubmissionJournalPreimage(x,preimage) ||
      !SWV5S5_DomainDigest("SWV5-S5-PHASE-D1-SUBMISSION-JOURNAL",preimage,x.journal_digest)) return false;
   return g.InjectDigestValidSubmissionMismatchForVerification(x) && !g.Finalize() &&
      g.Current().state==SWV5S5_GENESIS_PROVISIONING;
}

bool SWV5S5_D1Restart(const SWV5_ContractValidationContext &context,const SWV5_RestartReconciliationInput &restart_input,
                      const SWV5_PersistedRequestEvidence &requests[],const SWV5S5_ReferenceGenesisRecord &genesis,
                      const SWV5_InstanceLease &lease,SWV5S5_ReferenceRestartResult &result)
{ return SWV5S5_EvaluateReferenceRestart(context,restart_input,requests,genesis,lease,result); }
bool SWV5S5_D1PositiveRestartSafeToResume(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &i,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5S5_ReferenceRestartResult o; return SWV5S5_D1Restart(c,i,r,g,l,o)&&o.disposition==SWV5_RESTART_SAFE_TO_RESUME&&o.increasing_execution_eligible; }
bool SWV5S5_D1NegativeRestartWrongRequestSetDigest(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.restart_requests.request_set_digest="WRONG"; SWV5S5_ReferenceRestartResult o; return !SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartWrongRequestRevision(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.restart_requests.request_set_revision="WRONG"; SWV5S5_ReferenceRestartResult o; return !SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartWrongCheckpoint(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.persisted.pending_request_set.request_count++; SWV5S5_ReferenceRestartResult o; return !SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartWrongBasket(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.broker.basket_id.value="WRONG"; SWV5S5_ReferenceRestartResult o; return !SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartWrongFence(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.claimant_fence.lease_version++; SWV5S5_ReferenceRestartResult o; return !SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartCorruptBrokerDigest(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.broker.complete_summary_digest="CORRUPT"; SWV5S5_ReferenceRestartResult o; return !SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartCorruptExecutionDigest(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.restart_requests.complete_summary_digest="CORRUPT"; SWV5S5_ReferenceRestartResult o; return !SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartStaleQuery(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.broker.observed_at=(datetime)(c.clock_time-SWV5_MAX_RESTART_EVIDENCE_AGE_SECONDS_V5-1); SWV5S5_ReferenceRestartResult o; return !SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartFutureQuery(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.broker.observed_at=c.clock_time+1; SWV5S5_ReferenceRestartResult o; return !SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartClaimedUnresolved(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &valid_requests[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_PersistedRequestEvidence r[]; ArrayResize(r,1); r[0]=valid_requests[0]; r[0].pending_request.state=SWV5_REQUEST_CONFIRMATION_PENDING; SWV5S5_ReferenceRestartResult o; return !SWV5S5_D1Restart(c,v,r,g,l,o); }
bool SWV5S5_D1NegativeRestartActiveHardKill(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.persisted.hard_kill_state.state=SWV5_HARD_KILL_ACTIVE; SWV5S5_ReferenceRestartResult o; return !SWV5S5_D1Restart(c,x,r,g,l,o)&&o.disposition==SWV5_RESTART_CLOSE_ONLY; }
bool SWV5S5_D1NegativeRestartInvalidReleaseDigest(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.release_authority_record.authority_record_digest="CORRUPT"; SWV5S5_ReferenceRestartResult o; return !SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1SealMutatedReleaseAuthority(SWV5_RestartReconciliationInput &x)
{
   if(!SWV5S5_ReferenceReleaseAuthorityDigest(x.release_authority_record,x.release_authority_record.authority_record_digest)) return false;
   x.persisted.hard_kill_state.release_authority_reference.authority_record_id=x.release_authority_record.authority_record_id;
   x.persisted.hard_kill_state.release_authority_reference.authority_record_sequence=x.release_authority_record.release_record_sequence;
   x.persisted.hard_kill_state.release_authority_reference.authority_record_digest=x.release_authority_record.authority_record_digest;
   x.persisted.hard_kill_state.release_authority_reference.release_id=x.release_authority_record.release_id;
   x.persisted.hard_kill_state.release_authority_reference.latch_generation=x.release_authority_record.latch_generation;
   x.persisted.hard_kill_state.release_authority_reference.release_generation=x.release_authority_record.release_generation;
   return true;
}
bool SWV5S5_D1NegativeRestartWrongReleaseNamespace(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.release_authority_record.persistence_namespace.basket_id.value="FOREIGN"; SWV5S5_ReferenceRestartResult o; return SWV5S5_D1SealMutatedReleaseAuthority(x)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartWrongReleaseLatch(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.release_authority_record.latch_id="WRONG"; SWV5S5_ReferenceRestartResult o; return SWV5S5_D1SealMutatedReleaseAuthority(x)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartWrongReleaseGeneration(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.release_authority_record.release_generation++; SWV5S5_ReferenceRestartResult o; return SWV5S5_D1SealMutatedReleaseAuthority(x)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartWrongReleaseAccount(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.release_authority_record.account_namespace.account_login++; SWV5S5_ReferenceRestartResult o; return SWV5S5_D1SealMutatedReleaseAuthority(x)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartWrongReleaseOperator(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.release_authority_record.operator_identity.operator_id="FORGED"; SWV5S5_ReferenceRestartResult o; return SWV5S5_D1SealMutatedReleaseAuthority(x)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartWrongReleaseEvidence(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.release_authority_record.broker_evidence_reference.state_digest="FORGED"; SWV5S5_ReferenceRestartResult o; return SWV5S5_D1SealMutatedReleaseAuthority(x)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartExpiredRelease(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.release_authority_record.expires_at=c.clock_time; SWV5S5_ReferenceRestartResult o; return SWV5S5_D1SealMutatedReleaseAuthority(x)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartWrongReleaseSequence(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.release_authority_record.release_record_sequence++; SWV5S5_ReferenceRestartResult o; return SWV5S5_D1SealMutatedReleaseAuthority(x)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartWrongReleasePolicy(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.release_authority_record.approval_policy_id="FORGED"; SWV5S5_ReferenceRestartResult o; return SWV5S5_D1SealMutatedReleaseAuthority(x)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartWrongReleaseVersion(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.release_authority_record.contract_version.schema_version--; SWV5S5_ReferenceRestartResult o; return SWV5S5_D1SealMutatedReleaseAuthority(x)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }

void SWV5S5_RunPhaseDCompileOnlyAssertions(void)
{
   // Deliberately empty: compiler evidence only; no MQL assertion execution.
}

#endif
