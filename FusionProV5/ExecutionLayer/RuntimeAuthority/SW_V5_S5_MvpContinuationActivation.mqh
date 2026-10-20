#ifndef SW_V5_S5_MVP_CONTINUATION_ACTIVATION_MQH
#define SW_V5_S5_MVP_CONTINUATION_ACTIVATION_MQH
#include "SW_V5_S5_MvpContinuationFlatAuthority.mqh"
const string SWV5S5_MVP_DOMAIN_CONTINUATION_ACTIVATION="MVP_ATTENDED_CONTINUATION_ACTIVATION";
const string SWV5S5_MVP_DOMAIN_CONTINUATION_APPROVAL="MVP_ATTENDED_CONTINUATION_APPROVAL";

struct SWV5S5_MvpContinuationActivationProof
{
   string continuation_id;
   SWV5_HardKillState prior_inactive,active;
   SWV5_OwnershipFence fence;
   SWV5S5_MvpAuthorityRow prior_row;
   ulong prior_maximum_release_generation;
   ulong activation_clock_sequence;
};
bool SWV5S5_MvpContinuationActivationPayload(const SWV5S5_MvpContinuationActivationProof &p,string &body,string &digest)
{
   string n,f; body="";
   if(!SWV5S5_CanonicalString("continuation_id",p.continuation_id,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_HardKillState(p.prior_inactive,n) || !SWV5S5_CanonicalNested("prior_inactive",n,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_HardKillState(p.active,n) || !SWV5S5_CanonicalNested("active",n,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_OwnershipFence(p.fence,n) || !SWV5S5_CanonicalNested("fence",n,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("prior_revision",p.prior_row.logical_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("prior_store_revision",p.prior_row.store_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("prior_digest",p.prior_row.payload_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("prior_maximum_release_generation",p.prior_maximum_release_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("activation_clock_sequence",p.activation_clock_sequence,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_CONTINUATION_ACTIVATION,body,digest);
}
bool SWV5S5_MvpDecodeContinuationActivation(const string body,SWV5S5_MvpContinuationActivationProof &p)
{
   ZeroMemory(p); SWV5S5_MvpCodecReader r; r.Init(body); string n;
   return r.ReadString("continuation_id",p.continuation_id) &&
      r.ReadNested("prior_inactive",n) && SWV5S5_MvpCodecDecode_SWV5_HardKillState(n,p.prior_inactive) &&
      r.ReadNested("active",n) && SWV5S5_MvpCodecDecode_SWV5_HardKillState(n,p.active) &&
      r.ReadNested("fence",n) && SWV5S5_MvpCodecDecode_SWV5_OwnershipFence(n,p.fence) &&
      r.ReadUnsigned("prior_revision",p.prior_row.logical_revision) && r.ReadString("prior_store_revision",p.prior_row.store_revision) &&
      r.ReadString("prior_digest",p.prior_row.payload_digest) && r.ReadUnsigned("prior_maximum_release_generation",p.prior_maximum_release_generation) &&
      r.ReadUnsigned("activation_clock_sequence",p.activation_clock_sequence) && r.AtEnd();
}

bool SWV5S5_MvpContinuationBoundaryLineageValid(SWV5S5_MvpSqliteAuthorityStore &store,
   const SWV5_ContractValidationContext &context,const SWV5S5_MvpContinuationFlatAuthority &flat)
{
   SWV5S5_MvpAuthorityRow row,current,history;bool found=false;string payload,digest,a,b,id,f,revision;
   SWV5S5_MvpContinuationActivationProof proof;SWV5S5_MvpHardKillActivationProof prior;
   SWV5_HardKillState released,inactive;SWV5_HardKillReleaseAuthorityRecord authority;ulong maximum;
   if(!store.ReadRow(SWV5S5_MVP_DOMAIN_CONTINUATION_ACTIVATION,flat.active.latch_id,row,found) || !found ||
      !SWV5S5_MvpContinuationRowValid(store,row) || row.logical_revision!=1 ||
      !SWV5S5_MvpDecodeContinuationActivation(row.payload,proof) || !SWV5S5_MvpContinuationActivationPayload(proof,payload,digest) ||
      payload!=row.payload || digest!=row.payload_digest || !SWV5S5_EqualFence(proof.fence,flat.fence) ||
      proof.activation_clock_sequence==0 || proof.activation_clock_sequence>flat.clock_sequence ||
      !SWV5S5_MvpCodecEncode_SWV5_HardKillState(proof.active,a) || !SWV5S5_MvpCodecEncode_SWV5_HardKillState(flat.active,b) || a!=b ||
      !store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_HISTORY,proof.prior_inactive.latch_id,history,found) || !found ||
      !SWV5S5_MvpContinuationRowValid(store,history) || !SWV5S5_MvpDecodeActivation(history.payload,prior) ||
      !SWV5S5_MvpDecodeReleaseBundle(prior.release_bundle,released,authority))return false;
   SWV5S5_MvpNewInactiveEpoch(released,history.payload_digest,inactive);
   if(!SWV5S5_MvpCodecEncode_SWV5_HardKillState(inactive,a) || !SWV5S5_MvpCodecEncode_SWV5_HardKillState(proof.prior_inactive,b) || a!=b ||
      !SWV5S5_CanonicalHardKillState("hard_kill",inactive,payload) || !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,payload,digest) ||
      digest!=proof.prior_row.payload_digest || proof.prior_row.logical_revision!=prior.released_row.logical_revision+1 ||
      !store.DeriveStoreRevision(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",proof.prior_row.logical_revision,digest,revision) || revision!=proof.prior_row.store_revision ||
      !SWV5S5_CanonicalString("continuation_id",proof.continuation_id,payload) ||
      !SWV5S5_CanonicalString("prior_inactive_digest",digest,f))return false;payload+=f;
   if(!SWV5S5_CanonicalString("fence",flat.fence.fencing_token_digest,f))return false;payload+=f;
   if(!SWV5S5_CanonicalUInt("clock_sequence",proof.activation_clock_sequence,f))return false;payload+=f;
   if(!SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_CONTINUATION_ACTIVATION+"-ID",payload,id) ||
      proof.active.latch_id!="CONTINUATION-ACTIVE/"+id ||
      !store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,found) || !found ||
      !SWV5S5_MvpContinuationHistoryMaximum(store,context,flat.scope,flat.account,flat.fence,
         (current.state==(int)SWV5_HARD_KILL_RELEASED ? proof.active.latch_id : ""),maximum))return false;
   return maximum==proof.prior_maximum_release_generation && authority.release_generation==maximum &&
      proof.active.release_generation==maximum && proof.active.latch_generation==proof.prior_inactive.latch_generation+1 &&
      proof.active.activated_at==row.updated_at && proof.active.activated_at<=flat.observed_at;
}

bool SWV5S5_MvpContinuationActivate(SWV5S5_MvpSqliteAuthorityStore &store,const string continuation_id,
                                  const SWV5_ContractValidationContext &context,const SWV5S5_MvpOperatorInvocation &op,
                                  const SWV5_InstanceLease &lease,const SWV5S5_MvpAuthorityRow &ownership,
                                  const SWV5S5_MvpContinuationHistoricalLineage &lineage,
                                  SWV5S5_MvpContinuationActivationProof &proof,SWV5S5_MvpAuthorityRow &active_row)
{
   ZeroMemory(proof); ZeroMemory(active_row); string payload,digest,id,part; bool found=false;
   SWV5S5_MvpAuthorityRow current,empty,history; SWV5S5_MvpAuthorityMutation hm,cm;
   if(continuation_id=="" || !SWV5S5_MvpOperatorInvocationValid(op,context.clock_time) ||
      !SWV5S5_MvpLeaseCurrentForClock(context,lease.fence,lease) ||
      lineage.inactive.latch_generation>=18446744073709551614 ||
      lineage.maximum_completed_release_generation>=18446744073709551615 ||
      !store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,found) || !found ||
      current.payload!=lineage.inactive_row.payload || current.store_revision!=lineage.inactive_row.store_revision ||
      current.logical_revision!=lineage.inactive_row.logical_revision || current.state!=(int)SWV5_HARD_KILL_INACTIVE) return false;
   proof.continuation_id=continuation_id; proof.prior_inactive=lineage.inactive; proof.prior_row=current;
   proof.prior_maximum_release_generation=lineage.maximum_completed_release_generation; proof.fence=lease.fence;
   proof.activation_clock_sequence=context.clock_sequence;
   if(!SWV5S5_CanonicalString("continuation_id",continuation_id,payload) ||
      !SWV5S5_CanonicalString("prior_inactive_digest",current.payload_digest,part)) return false; payload+=part;
   if(!SWV5S5_CanonicalString("fence",lease.fence.fencing_token_digest,part)) return false; payload+=part;
   if(!SWV5S5_CanonicalUInt("clock_sequence",context.clock_sequence,part)) return false; payload+=part;
   if(!SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_CONTINUATION_ACTIVATION+"-ID",payload,id)) return false;
   proof.active=proof.prior_inactive; proof.active.latch_id="CONTINUATION-ACTIVE/"+id;
   proof.active.latch_generation=proof.prior_inactive.latch_generation+1; proof.active.state=SWV5_HARD_KILL_ACTIVE;
   proof.active.release_generation=proof.prior_maximum_release_generation;
   proof.active.activation_reason="CONTINUATION_REAUTHORIZATION";
   proof.active.activation_authority=op.authority_role+"/"+op.operator_id;
   proof.active.activated_at=context.clock_time;
   proof.active.release_evidence.latch_id=proof.active.latch_id;
   proof.active.release_evidence.latch_generation=proof.active.latch_generation;
   if(!SWV5S5_MvpContinuationActivationPayload(proof,payload,digest) ||
      !store.ReadRow(SWV5S5_MVP_DOMAIN_CONTINUATION_ACTIVATION,proof.active.latch_id,empty,found) || found) return false;
   SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_CONTINUATION_ACTIVATION,proof.active.latch_id,empty,false,1,1,
      digest,payload,context.clock_time,hm);
   if(!SWV5S5_MvpCodecEncode_SWV5_HardKillState(proof.active,payload) ||
      !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,payload,digest)) return false;
   SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,true,current.logical_revision+1,
      (int)SWV5_HARD_KILL_ACTIVE,digest,payload,context.clock_time,cm);
   return store.CompareAndSetPairWithGuard(hm,cm,ownership,history,active_row) &&
      store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,found) && found &&
      current.payload==payload && current.store_revision==active_row.store_revision;
}

// Bootstrap PersistApprovedRelease is untouched. This sibling accepts only
// the append-only typed continuation record and exact pending CURRENT row.
bool SWV5S5_MvpStageContinuationPending(SWV5S5_MvpSqliteAuthorityStore &store,
   const SWV5_ContractValidationContext &context,const SWV5S5_MvpOperatorInvocation &op,
   const SWV5S5_MvpContinuationFlatAuthority &flat,SWV5_HardKillState &pending,SWV5S5_MvpAuthorityRow &committed)
{
   SWV5_HardKillReleaseEvidence evidence;SWV5_HardKillReleaseAuthorityRecord authority;
   SWV5S5_MvpAuthorityRow rows[],current,unused;bool found=false;string payload,digest;
   if(!SWV5S5_MvpOperatorInvocationValid(op,context.clock_time) || op.authenticated_at!=flat.op.authenticated_at ||
      op.operator_id!=flat.op.operator_id || op.authentication_reference!=flat.op.authentication_reference ||
      !SWV5S5_MvpContinuationBoundaryLineageValid(store,context,flat) || !SWV5S5_MvpContinuationBoundRowsCurrent(store,context,flat,false,rows) ||
      !SWV5S5_MvpIssueContinuationRelease(flat,evidence,authority) ||
      !store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,found) || !found || current.state!=(int)SWV5_HARD_KILL_ACTIVE)return false;
   pending=flat.active;pending.state=SWV5_HARD_KILL_RELEASE_PENDING;pending.release_evidence=evidence;
   if(!SWV5S5_MvpHardKillReleaseValid(context,pending,evidence) ||
      !SWV5S5_CanonicalHardKillState("hard_kill",pending,payload) || !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,payload,digest))return false;
   SWV5S5_MvpAuthorityMutation mutation,none;ZeroMemory(none);
   SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,true,current.logical_revision+1,
      (int)SWV5_HARD_KILL_RELEASE_PENDING,digest,payload,context.clock_time,mutation);
   return store.CompareAndSetWithExactSnapshot(mutation,false,none,rows,committed,unused);
}

bool SWV5S5_MvpPersistApprovedContinuationRelease(SWV5S5_MvpSqliteAuthorityStore &store,
                                                const SWV5_ContractValidationContext &context,
                                                const SWV5S5_MvpContinuationFlatAuthority &flat,
                                                const SWV5_InstanceLease &lease,
                                                const SWV5S5_MvpAuthorityRow &expected_pending,
                                                const bool validated_resume,
                                                SWV5_HardKillState &released,SWV5S5_MvpAuthorityRow &committed)
{
   ZeroMemory(released); ZeroMemory(committed); bool found=false; string payload,digest,expected,expected_digest;
   SWV5_HardKillReleaseEvidence evidence; SWV5_HardKillReleaseAuthorityRecord authority;
   SWV5S5_MvpAuthorityRow flat_row,current,ownership,complete,empty; SWV5_InstanceLease durable;
   SWV5S5_MvpAuthorityRow physical[];
   SWV5S5_MvpLeasePublicationAuthority leases; SWV5S5_MvpAuthorityMutation cm,rm;
   if(!SWV5S5_MvpContinuationBoundaryLineageValid(store,context,flat) ||
      !SWV5S5_MvpContinuationBoundRowsCurrent(store,context,flat,validated_resume,physical) ||
      !SWV5S5_MvpIssueContinuationRelease(flat,evidence,authority) ||
      context.clock_time>=evidence.expires_at || !SWV5S5_MvpLeaseCurrentForClock(context,lease.fence,lease) ||
      !leases.LoadCurrentLease(store,lease.fence.ownership_namespace,lease.fence,durable,ownership) ||
      !SWV5S5_MvpLeaseExact(durable,lease) || !SWV5S5_EqualFence(flat.fence,lease.fence) ||
      !store.ReadRow(SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT,flat.key,flat_row,found) || !found ||
      !SWV5S5_MvpContinuationFlatPayload(flat,true,payload) || flat_row.payload!=payload ||
      !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT,payload,digest) ||
      flat_row.payload_digest!=digest || !SWV5S5_MvpContinuationRowValid(store,flat_row)) return false;
   SWV5_HardKillState pending=flat.active; pending.state=SWV5_HARD_KILL_RELEASE_PENDING; pending.release_evidence=evidence;
   if(!SWV5S5_CanonicalHardKillState("hard_kill",pending,expected) ||
      !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,expected,expected_digest) ||
      !store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,found) || !found ||
      current.state!=(int)SWV5_HARD_KILL_RELEASE_PENDING || current.payload!=expected || current.payload_digest!=expected_digest ||
      current.logical_revision!=expected_pending.logical_revision || current.store_revision!=expected_pending.store_revision) return false;
   released=pending; released.state=SWV5_HARD_KILL_RELEASED; released.release_generation=evidence.release_generation;
   released.release_authority_reference.contract_version=authority.contract_version;
   released.release_authority_reference.authority_record_id=authority.authority_record_id;
   released.release_authority_reference.authority_record_sequence=authority.release_record_sequence;
   released.release_authority_reference.authority_record_digest=authority.authority_record_digest;
   released.release_authority_reference.release_id=authority.release_id;
   released.release_authority_reference.latch_generation=authority.latch_generation;
   released.release_authority_reference.release_generation=authority.release_generation;
   if(!SWV5S5_MvpCompleteReleaseValid(context,released,authority) ||
      !SWV5S5_MvpReleaseBundle(released,authority,payload,digest) ||
      !store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE,authority.authority_record_id,empty,found) || found) return false;
   SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE,authority.authority_record_id,empty,false,1,
      (int)SWV5_HARD_KILL_RELEASED,digest,payload,context.clock_time,cm);
   if(!SWV5S5_CanonicalHardKillState("hard_kill",released,payload) ||
      !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,payload,digest)) return false;
   SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,true,current.logical_revision+1,
      (int)SWV5_HARD_KILL_RELEASED,digest,payload,context.clock_time,rm);
   return store.CompareAndSetWithExactSnapshot(cm,true,rm,physical,complete,committed) &&
      store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,found) && found &&
      current.payload==payload && current.store_revision==committed.store_revision;
}
#endif
