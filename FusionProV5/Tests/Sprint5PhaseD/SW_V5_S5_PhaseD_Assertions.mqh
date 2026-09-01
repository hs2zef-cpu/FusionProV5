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
bool SWV5S5_D2ResealClaimMutation(SWV5S5_InvocationClaimCommand &x,const int mutation)
{
   SWV5S5_SubmissionPermit p=x.expected_authority_record.permit;
   if(mutation==0)
   {
      p.request_identity.request_id.attempt_id="D2-OTHER-ATTEMPT"; p.unique_attempt_id="D2-OTHER-ATTEMPT";
      p.risk_authorization.request_identity=p.request_identity; p.margin_authority.request_identity=p.request_identity;
      p.basket_risk_authority.request_identity=p.request_identity;
      if(!SWV5S5_DerivePermitId(p,p.permit_id)) return false;
   }
   else if(mutation==1) p.permit_revision++;
   else if(mutation==2) p.risk_authorization.authorization_id="D2-OTHER-RISK";
   else if(mutation==3) p.risk_authorization.authorized_projected_loss+=1.0;
   else if(mutation==4) p.normalization_identity="D2-OTHER-NORMALIZATION";
   else if(mutation==5)
   { p.normalized_payload.volume+=0.01; p.risk_authorization.authorized_volume=p.normalized_payload.volume; p.margin_authority.requested_volume=p.normalized_payload.volume; }
   else if(mutation==6)
   {
      p.symbol_specification_sequence++; p.normalized_payload.specification_sequence=p.symbol_specification_sequence;
      p.risk_authorization.symbol_specification_sequence=p.symbol_specification_sequence;
      p.margin_authority.symbol_specification_sequence=p.symbol_specification_sequence;
      p.basket_risk_authority.symbol_specification_sequence=p.symbol_specification_sequence;
   }
   else if(mutation==7)
   {
      p.request_identity.request_id.correlation_id="D2-OTHER-CORRELATION";
      p.risk_authorization.request_identity=p.request_identity; p.margin_authority.request_identity=p.request_identity;
      p.basket_risk_authority.request_identity=p.request_identity;
      if(!SWV5S5_DerivePermitId(p,p.permit_id)) return false;
   }
   else return false;
   if(!SWV5S5_DerivePermitDigest(p,p.permit_digest)) return false;
   x.expected_authority_record.permit=p;
   if(!SWV5S5_DeriveDurableSubmissionAuthorityDigest(x.expected_authority_record,
      x.expected_authority_record.durable_record_digest)) return false;
   x.expected_authority_digest=x.expected_authority_record.durable_record_digest;
   x.expected_authority_revision=x.expected_authority_record.authority_revision;
   if(!SWV5S5_DeriveClaimId(x,x.claim_id) || !SWV5S5_DeriveClaimCommandDigest(x,x.command_digest)) return false;
   return true;
}
bool SWV5S5_D1NegativeClaimWrongPermit(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; return SWV5S5_D2ResealClaimMutation(x,0)&&!SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D1NegativeClaimWrongRisk(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; return SWV5S5_D2ResealClaimMutation(x,2)&&!SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D1NegativeClaimWrongNormalization(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; return SWV5S5_D2ResealClaimMutation(x,4)&&!SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D2NegativeClaimWrongPermitRevision(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; return SWV5S5_D2ResealClaimMutation(x,1)&&!SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D2NegativeClaimWrongRiskContent(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; return SWV5S5_D2ResealClaimMutation(x,3)&&!SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D2NegativeClaimWrongNormalizedPayload(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; return SWV5S5_D2ResealClaimMutation(x,5)&&!SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D2NegativeClaimWrongSpecification(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; return SWV5S5_D2ResealClaimMutation(x,6)&&!SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
bool SWV5S5_D2NegativeClaimWrongRequestBinding(const SWV5S5_InvocationClaimCommand &v,const SWV5S5_InvocationClaimTransition &t)
{ SWV5S5_InvocationClaimCommand x=v; return SWV5S5_D2ResealClaimMutation(x,7)&&!SWV5S5_D1InvokeClaim(v,x,t,SWV5S5_REF_FAULT_NONE); }
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

bool SWV5S5_D2RunTakeover(const SWV5_InstanceLease &observed,const SWV5_PersistenceNamespace &expected_namespace,
                          const SWV5S5_ReferenceClockObservation &candidate,const SWV5_OwnershipClaim &claim,
                          SWV5S5_ReferenceClockObservation &validated)
{
   SWV5S5_ReferenceLeaseStore store; SWV5S5_FakeAuthoritativeClock clock; SWV5_InstanceLease result;
   SWV5S5_ReferenceTransactionResult tx;
   clock.Configure(candidate.clock_id,candidate.authority,candidate.source_symbol);
   if(!store.Initialize(observed,expected_namespace) || !clock.AcceptAndSeal(candidate,validated)) return false;
   return store.Takeover(clock,validated,claim,result,tx);
}

bool SWV5S5_D1RunTakeover(const SWV5_InstanceLease &observed,const SWV5S5_ReferenceClockObservation &candidate,
                          const SWV5_OwnershipClaim &claim,SWV5S5_ReferenceClockObservation &validated)
{ return SWV5S5_D2RunTakeover(observed,claim.takeover_evidence.persistence_reconciliation.persistence_namespace,candidate,claim,validated); }

bool SWV5S5_D1PositiveTakeover(const SWV5_InstanceLease &observed,const SWV5S5_ReferenceClockObservation &candidate,const SWV5_OwnershipClaim &claim)
{ SWV5S5_ReferenceClockObservation v; return SWV5S5_D1RunTakeover(observed,candidate,claim,v); }
bool SWV5S5_D1NegativeTakeoverInvalidClockToken(const SWV5_InstanceLease &o,const SWV5S5_ReferenceClockObservation &c,const SWV5_OwnershipClaim &q)
{
   SWV5S5_ReferenceLeaseStore s; SWV5S5_FakeAuthoritativeClock k; SWV5S5_ReferenceClockObservation v;
   SWV5_InstanceLease z; SWV5S5_ReferenceTransactionResult tx;
   k.Configure(c.clock_id,c.authority,c.source_symbol);
   if(!s.Initialize(o,q.takeover_evidence.persistence_reconciliation.persistence_namespace) || !k.AcceptAndSeal(c,v)) return false;
   v.validation_digest="FORGED";
   return !s.Takeover(k,v,q,z,tx);
}
bool SWV5S5_D1NegativeTakeoverForeignNamespace(const SWV5_InstanceLease &o,const SWV5S5_ReferenceClockObservation &c,const SWV5_OwnershipClaim &q)
{ SWV5_PersistenceNamespace expected=q.takeover_evidence.persistence_reconciliation.persistence_namespace; SWV5_OwnershipClaim x=q; x.takeover_evidence.broker_reconciliation.persistence_namespace.basket_id.value="FOREIGN"; x.takeover_evidence.persistence_reconciliation.persistence_namespace.basket_id.value="FOREIGN"; SWV5S5_ReferenceClockObservation v; return !SWV5S5_D2RunTakeover(o,expected,c,x,v); }
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
{ SWV5_OwnershipClaim x=q; x.takeover_evidence.broker_reconciliation.authority_source=SWV5_AUTHORITY_PERSISTED_CHECKPOINT; if(!SWV5S5_SHA256("D2-WRONG-BROKER-RELATION",x.takeover_evidence.broker_reconciliation.state_digest)) return false; SWV5S5_ReferenceClockObservation v; return !SWV5S5_D1RunTakeover(o,c,x,v); }
bool SWV5S5_D1NegativeTakeoverInvalidPersistenceReconciliation(const SWV5_InstanceLease &o,const SWV5S5_ReferenceClockObservation &c,const SWV5_OwnershipClaim &q)
{ SWV5_OwnershipClaim x=q; x.takeover_evidence.persistence_reconciliation.evidence_sequence=x.takeover_evidence.evidence_sequence+1; if(!SWV5S5_SHA256("D2-WRONG-PERSISTENCE-RELATION",x.takeover_evidence.persistence_reconciliation.state_digest)) return false; SWV5S5_ReferenceClockObservation v; return !SWV5S5_D1RunTakeover(o,c,x,v); }
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
bool SWV5S5_D2SealBrokerSummary(SWV5_AuthoritativeBrokerSummary &summary)
{ return SWV5S5_ReferenceQuerySnapshotDigest(summary.queries,summary.queries.snapshot_digest) && SWV5S5_ReferenceBrokerSummaryDigest(summary,summary.complete_summary_digest); }
bool SWV5S5_D2SealExecutionSummary(SWV5_AuthoritativeRestartRequestSummary &summary)
{ return SWV5S5_ReferenceQuerySnapshotDigest(summary.pending_request_query,summary.pending_request_query.snapshot_digest) && SWV5S5_ReferenceExecutionSummaryDigest(summary,summary.complete_summary_digest); }
bool SWV5S5_D1NegativeRestartWrongRequestSetDigest(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.restart_requests.request_set_digest="WRONG"; SWV5S5_ReferenceRestartResult o; return !SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartWrongRequestRevision(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.restart_requests.request_set_revision="WRONG"; SWV5S5_ReferenceRestartResult o; return !SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartWrongCheckpoint(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.persisted.pending_request_set.request_count++; SWV5S5_ReferenceRestartResult o; return !SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D1NegativeRestartWrongBasket(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.broker.basket_id.value="WRONG"; SWV5S5_ReferenceRestartResult o; return SWV5S5_D2SealBrokerSummary(x.broker)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D2NegativeRestartWrongAccountMode(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.broker.account_mode=SWV5_ACCOUNT_MODE_NETTING; SWV5S5_ReferenceRestartResult o; return SWV5S5_D2SealBrokerSummary(x.broker)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D2NegativeRestartWrongQueryProvenance(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.broker.queries.authority_source=SWV5_AUTHORITY_PERSISTED_CHECKPOINT; SWV5S5_ReferenceRestartResult o; return SWV5S5_D2SealBrokerSummary(x.broker)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D2NegativeRestartWrongTransactionHwm(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.broker.transaction_high_watermark++; SWV5S5_ReferenceRestartResult o; return SWV5S5_D2SealBrokerSummary(x.broker)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D2NegativeRestartWrongCorrelation(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.broker.latest_confirmed_correlation.request_identity.request_id.correlation_id="D2-OTHER"; SWV5S5_ReferenceRestartResult o; return SWV5S5_D2SealBrokerSummary(x.broker)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D2NegativeRestartExecutionCount(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.restart_requests.pending_request_count++; SWV5S5_ReferenceRestartResult o; return SWV5S5_D2SealExecutionSummary(x.restart_requests)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D2NegativeRestartExecutionRevision(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &r[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{ SWV5_RestartReconciliationInput x=v; x.restart_requests.reconciliation_revision++; SWV5S5_ReferenceRestartResult o; return SWV5S5_D2SealExecutionSummary(x.restart_requests)&&!SWV5S5_D1Restart(c,x,r,g,l,o); }
bool SWV5S5_D2NegativeRestartUnsafeSecondRequest(const SWV5_ContractValidationContext &c,const SWV5_RestartReconciliationInput &v,const SWV5_PersistedRequestEvidence &valid_requests[],const SWV5S5_ReferenceGenesisRecord &g,const SWV5_InstanceLease &l)
{
   if(ArraySize(valid_requests)<2) return false;
   SWV5_PersistedRequestEvidence r[]; ArrayResize(r,ArraySize(valid_requests));
   SWV5_PendingRequest pending[]; ArrayResize(pending,ArraySize(valid_requests));
   for(int i=0;i<ArraySize(valid_requests);i++){ r[i]=valid_requests[i]; pending[i]=r[i].pending_request; }
   r[1].pending_request.state=SWV5_REQUEST_RECONCILIATION_REQUIRED; pending[1]=r[1].pending_request;
   string set_digest; if(!SWV5S5_DeriveCompleteRequestSetDigest(pending,set_digest)) return false;
   SWV5_RestartReconciliationInput x=v;
   x.persisted.pending_request_set.request_count=(uint)ArraySize(r);
   x.persisted.pending_request_set.request_set_digest=set_digest;
   x.persisted.reconciliation_vector.pending_request_count=(uint)ArraySize(r);
   x.persisted.reconciliation_vector.request_set_digest=set_digest;
   x.persisted.latest_pending_request=r[ArraySize(r)-1]; x.persisted.has_latest_pending_request=true;
   x.restart_requests.pending_request_count=(uint)ArraySize(r); x.restart_requests.request_set_digest=set_digest;
   SWV5S5_ReferenceRestartResult o;
   return SWV5S5_D2SealExecutionSummary(x.restart_requests)&&!SWV5S5_D1Restart(c,x,r,g,l,o);
}
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

bool SWV5S5_D2PositiveLedgerAcceptance(const SWV5S5_IngressLedgerHeader &header,
   const SWV5S5_IngressLedgerIndexEntry &index[],const SWV5S5_IngressLedgerRecord &records[],
   const SWV5S5_IngressLedgerProposal &proposal,const SWV5S5_IngressLedgerIndexEntry &next_index[],
   const SWV5S5_IngressLedgerRecord &next_records[])
{
   SWV5S5_ReferenceIngressLedgerStore store; SWV5S5_ValidationResult result; SWV5S5_ReferenceTransactionResult tx;
   SWV5S5_IngressLedgerHeader loaded; SWV5S5_IngressLedgerIndexEntry loaded_index[]; SWV5S5_IngressLedgerRecord loaded_records[];
   return store.Initialize(header,index,records) && store.TryCommitAcceptance(header,index,records,proposal,next_index,next_records,result,tx) &&
      store.Load(loaded,loaded_index,loaded_records) && loaded.revision==proposal.proposed_next_revision &&
      ArraySize(loaded_records)==ArraySize(next_records) && tx.this_transaction_won;
}

bool SWV5S5_D2PositiveLedgerCompaction(const SWV5S5_IngressLedgerHeader &header,
   const SWV5S5_IngressLedgerIndexEntry &index[],const SWV5S5_IngressLedgerRecord &records[],
   const SWV5S5_IngressLedgerCompactionProposal &proposal)
{
   SWV5S5_ReferenceIngressLedgerStore store; SWV5S5_ReferenceTransactionResult tx;
   return store.Initialize(header,index,records) && store.TryCompact(proposal,index,records,tx) &&
      store.CompactionGeneration()==proposal.proposed_compaction_generation;
}

bool SWV5S5_D2NegativeLedgerWrongProposedRevision(const SWV5S5_IngressLedgerHeader &header,
   const SWV5S5_IngressLedgerIndexEntry &index[],const SWV5S5_IngressLedgerRecord &records[],
   const SWV5S5_IngressLedgerProposal &proposal,const SWV5S5_IngressLedgerIndexEntry &next_index[],
   const SWV5S5_IngressLedgerRecord &next_records[])
{
   SWV5S5_IngressLedgerProposal x=proposal; x.proposed_next_revision++;
   SWV5S5_ReferenceIngressLedgerStore store; SWV5S5_ValidationResult result; SWV5S5_ReferenceTransactionResult tx;
   return store.Initialize(header,index,records) && !store.TryCommitAcceptance(header,index,records,x,next_index,next_records,result,tx);
}

bool SWV5S5_D2NegativeLedgerResealedAcceptedAt(const SWV5S5_IngressLedgerHeader &header,
   const SWV5S5_IngressLedgerIndexEntry &index[],const SWV5S5_IngressLedgerRecord &records[],
   const SWV5S5_IngressLedgerProposal &proposal,const SWV5S5_IngressLedgerIndexEntry &next_index[],
   const SWV5S5_IngressLedgerRecord &next_records[])
{
   SWV5S5_IngressLedgerProposal x=proposal; x.proposed_record.accepted_at++;
   if(!SWV5S5_DeriveLedgerRecordDigest(x.proposed_record,x.proposed_record.record_digest)) return false;
   SWV5S5_ReferenceIngressLedgerStore store; SWV5S5_ValidationResult result; SWV5S5_ReferenceTransactionResult tx;
   return store.Initialize(header,index,records) && !store.TryCommitAcceptance(header,index,records,x,next_index,next_records,result,tx);
}

bool SWV5S5_D2NegativeLedgerResealedHwm(const SWV5S5_IngressLedgerHeader &header,
   const SWV5S5_IngressLedgerIndexEntry &index[],const SWV5S5_IngressLedgerRecord &records[],
   const SWV5S5_IngressLedgerProposal &proposal,const SWV5S5_IngressLedgerIndexEntry &next_index[],
   const SWV5S5_IngressLedgerRecord &next_records[])
{
   SWV5S5_IngressLedgerProposal x=proposal; x.proposed_record.publication_sequence++;
   if(!SWV5S5_DeriveLedgerRecordDigest(x.proposed_record,x.proposed_record.record_digest)) return false;
   SWV5S5_ReferenceIngressLedgerStore store; SWV5S5_ValidationResult result; SWV5S5_ReferenceTransactionResult tx;
   return store.Initialize(header,index,records) && !store.TryCommitAcceptance(header,index,records,x,next_index,next_records,result,tx);
}

bool SWV5S5_D2NegativeLedgerRecordIndexLinkage(const SWV5S5_IngressLedgerHeader &header,
   const SWV5S5_IngressLedgerIndexEntry &index[],const SWV5S5_IngressLedgerRecord &records[],
   const SWV5S5_IngressLedgerProposal &proposal,const SWV5S5_IngressLedgerIndexEntry &next_index[],
   const SWV5S5_IngressLedgerRecord &next_records[])
{
   SWV5S5_IngressLedgerRecord changed[]; ArrayResize(changed,ArraySize(next_records));
   for(int i=0;i<ArraySize(next_records);i++) changed[i]=next_records[i];
   if(ArraySize(changed)==0) return false;
   changed[ArraySize(changed)-1].accepted_at++;
   if(!SWV5S5_DeriveLedgerRecordDigest(changed[ArraySize(changed)-1],changed[ArraySize(changed)-1].record_digest)) return false;
   SWV5S5_ReferenceIngressLedgerStore store; SWV5S5_ValidationResult result; SWV5S5_ReferenceTransactionResult tx;
   return store.Initialize(header,index,records) && !store.TryCommitAcceptance(header,index,records,proposal,next_index,changed,result,tx);
}

bool SWV5S5_D2NegativeLedgerMembership(const SWV5S5_IngressLedgerHeader &header,
   const SWV5S5_IngressLedgerIndexEntry &index[],const SWV5S5_IngressLedgerRecord &records[],
   const SWV5S5_IngressLedgerProposal &proposal,const SWV5S5_IngressLedgerIndexEntry &next_index[],
   const SWV5S5_IngressLedgerRecord &next_records[])
{
   SWV5S5_IngressLedgerIndexEntry changed[]; ArrayResize(changed,ArraySize(next_index));
   for(int i=0;i<ArraySize(next_index);i++) changed[i]=next_index[i];
   if(ArraySize(changed)==0) return false; ArrayResize(changed,ArraySize(changed)-1);
   SWV5S5_ReferenceIngressLedgerStore store; SWV5S5_ValidationResult result; SWV5S5_ReferenceTransactionResult tx;
   return store.Initialize(header,index,records) && !store.TryCommitAcceptance(header,index,records,proposal,changed,next_records,result,tx);
}

bool SWV5S5_D2PositiveRequestSetPublication(const SWV5S5_RequestSetPublicationAuthority &authority,
   const SWV5_PendingRequest &current_requests[],const SWV5S5_CheckpointPublicationAuthority &checkpoint_authority,
   const SWV5_PersistedCheckpoint &checkpoint,const SWV5S5_RequestSetPublicationProposal &proposal,
   const SWV5_PendingRequest &proposed_requests[])
{
   SWV5S5_ReferencePublicationStore store; SWV5S5_FencedPublicationResult result; SWV5S5_ReferenceTransactionResult tx;
   SWV5S5_RequestSetPublicationAuthority loaded; SWV5_PendingRequest readback[];
   return store.Initialize(authority,current_requests,checkpoint_authority,checkpoint) &&
      store.TryPublishRequestSet(proposal,proposed_requests,result,tx) && store.LoadRequestSet(loaded,readback) &&
      ArraySize(readback)==ArraySize(proposed_requests) && loaded.current_complete_set_digest==proposal.proposed_complete_set_digest;
}

bool SWV5S5_D2PositiveCheckpointAfterSetReload(const SWV5S5_RequestSetPublicationAuthority &authority,
   const SWV5_PendingRequest &requests[],const SWV5S5_CheckpointPublicationAuthority &checkpoint_authority,
   const SWV5_PersistedCheckpoint &checkpoint,const SWV5S5_CheckpointPublicationProposal &proposal)
{
   SWV5S5_ReferencePublicationStore store; SWV5S5_FencedPublicationResult result; SWV5S5_ReferenceTransactionResult tx;
   SWV5_PersistedCheckpoint loaded;
   return store.Initialize(authority,requests,checkpoint_authority,checkpoint) &&
      store.TryPublishCheckpoint(proposal,result,tx) && store.LoadCheckpoint(loaded) &&
      loaded.header.record_sequence==proposal.proposed_checkpoint.header.record_sequence;
}

bool SWV5S5_D2NegativeCheckpointStaleAfterSetChange(const SWV5S5_RequestSetPublicationAuthority &authority,
   const SWV5_PendingRequest &current_requests[],const SWV5S5_CheckpointPublicationAuthority &checkpoint_authority,
   const SWV5_PersistedCheckpoint &checkpoint,const SWV5S5_RequestSetPublicationProposal &set_proposal,
   const SWV5_PendingRequest &proposed_requests[],const SWV5S5_CheckpointPublicationProposal &stale_checkpoint)
{
   SWV5S5_ReferencePublicationStore store; SWV5S5_FencedPublicationResult result; SWV5S5_ReferenceTransactionResult tx;
   if(!store.Initialize(authority,current_requests,checkpoint_authority,checkpoint) ||
      !store.TryPublishRequestSet(set_proposal,proposed_requests,result,tx)) return false;
   return !store.TryPublishCheckpoint(stale_checkpoint,result,tx);
}

bool SWV5S5_D2NegativeRequestSetForeignCanonicalDomain(const SWV5S5_RequestSetPublicationAuthority &authority,
   const SWV5_PendingRequest &current_requests[],const SWV5S5_CheckpointPublicationAuthority &checkpoint_authority,
   const SWV5_PersistedCheckpoint &checkpoint,const SWV5S5_RequestSetPublicationProposal &proposal,
   const SWV5_PendingRequest &proposed_requests[])
{
   SWV5S5_RequestSetPublicationProposal x=proposal; x.persistence_namespace.basket_id.value="D2-FOREIGN-BASKET";
   if(!SWV5S5_DeriveRequestSetProposalDigest(x,x.proposal_digest)) return false;
   SWV5S5_ReferencePublicationStore store; SWV5S5_FencedPublicationResult result; SWV5S5_ReferenceTransactionResult tx;
   return store.Initialize(authority,current_requests,checkpoint_authority,checkpoint) &&
      !store.TryPublishRequestSet(x,proposed_requests,result,tx);
}

bool SWV5S5_D2NegativeCheckpointForeignCanonicalDomain(const SWV5S5_RequestSetPublicationAuthority &authority,
   const SWV5_PendingRequest &requests[],const SWV5S5_CheckpointPublicationAuthority &checkpoint_authority,
   const SWV5_PersistedCheckpoint &checkpoint,const SWV5S5_CheckpointPublicationProposal &proposal)
{
   SWV5S5_CheckpointPublicationProposal x=proposal; x.persistence_namespace.basket_id.value="D2-FOREIGN-BASKET";
   if(!SWV5S5_DeriveCheckpointProposalDigest(x,x.proposal_digest)) return false;
   SWV5S5_ReferencePublicationStore store; SWV5S5_FencedPublicationResult result; SWV5S5_ReferenceTransactionResult tx;
   return store.Initialize(authority,requests,checkpoint_authority,checkpoint) && !store.TryPublishCheckpoint(x,result,tx);
}

bool SWV5S5_D2PositiveSequenceReload(const SWV5S5_RequestSequenceAuthority &authority,
   const SWV5S5_RequestSequenceIndexEntry &entries[],const SWV5S5_RequestSequenceReservation &proposal)
{
   SWV5S5_ReferenceSequenceStore store; SWV5S5_RequestSequenceResult result; SWV5S5_ReferenceTransactionResult tx;
   SWV5S5_RequestSequenceAuthority loaded; SWV5S5_RequestSequenceIndexEntry loaded_entries[];
   return store.Initialize(authority,entries) && store.Reserve(proposal,result,tx) &&
      store.Load(loaded,loaded_entries) && ArraySize(loaded_entries)==ArraySize(entries)+1 &&
      loaded.authority_digest==result.resulting_authority_digest;
}

bool SWV5S5_D2NegativeSequenceForeignCanonicalDomain(const SWV5S5_RequestSequenceAuthority &authority,
   const SWV5S5_RequestSequenceIndexEntry &entries[],const SWV5S5_RequestSequenceReservation &proposal)
{
   SWV5S5_RequestSequenceReservation x=proposal; x.persistence_namespace.basket_id.value="D2-FOREIGN-BASKET";
   if(!SWV5S5_DeriveSequenceReservationDigest(x,x.reservation_digest)) return false;
   SWV5S5_ReferenceSequenceStore store; SWV5S5_RequestSequenceResult result; SWV5S5_ReferenceTransactionResult tx;
   return store.Initialize(authority,entries) && !store.Reserve(x,result,tx);
}

void SWV5S5_RunPhaseDCompileOnlyAssertions(void)
{
   // Deliberately empty: compiler evidence only; no MQL assertion execution.
}

#endif
