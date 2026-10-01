#ifndef SW_V5_S5_MVP_HARD_KILL_ACTIVATION_AUTHORITY_MQH
#define SW_V5_S5_MVP_HARD_KILL_ACTIVATION_AUTHORITY_MQH

// EXPLICIT ATTENDED DEMO AUTHORITY ONLY / NO BROKER ACCESS.
// RELEASED is never treated as executable. No Risk decision after Claim.
#include "SW_V5_S5_MvpManualProvisioningAuthorities.mqh"

struct SWV5S5_MvpHardKillActivationProof
{
   string release_bundle;
   SWV5S5_MvpAuthorityRow released_row;
   SWV5_OwnershipFence activation_fence;
   SWV5S5_MvpOperatorInvocation operator_invocation;
   string clock_id;
   SWV5_TimeAuthority clock_authority;
   ulong clock_sequence;
   datetime activated_at;
};

bool SWV5S5_MvpActivationPayload(const SWV5S5_MvpHardKillActivationProof &proof,string &payload,string &digest)
{
   string f; payload="";
   if(!SWV5S5_CanonicalString("policy","MVP-POST-RELEASE-ACTIVATION-V1",f)) return false; payload+=f;
   if(!SWV5S5_CanonicalNested("release_bundle",proof.release_bundle,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalUInt("released_revision",proof.released_row.logical_revision,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalString("released_store_revision",proof.released_row.store_revision,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalString("released_digest",proof.released_row.payload_digest,f)) return false; payload+=f;
   string fence;
   if(!SWV5S5_MvpCodecEncode_SWV5_OwnershipFence(proof.activation_fence,fence) ||
      !SWV5S5_CanonicalNested("activation_fence",fence,f)) return false; payload+=f;
   string op,unused;
   if(!SWV5S5_MvpOperatorPayload(proof.operator_invocation,op,unused) ||
      !SWV5S5_CanonicalNested("operator",op,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalString("clock_id",proof.clock_id,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalInt("clock_authority",(int)proof.clock_authority,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalUInt("clock_sequence",proof.clock_sequence,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalDatetime("activated_at",proof.activated_at,f)) return false; payload+=f;
   return SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_RELEASE_HISTORY,payload,digest);
}

bool SWV5S5_MvpDecodeActivation(const string text,SWV5S5_MvpHardKillActivationProof &proof)
{
   ZeroMemory(proof); SWV5S5_MvpCodecReader reader; reader.Init(text); string policy,nested; long number;
   if(!reader.ReadString("policy",policy) || policy!="MVP-POST-RELEASE-ACTIVATION-V1" ||
      !reader.ReadNested("release_bundle",proof.release_bundle) ||
      !reader.ReadUnsigned("released_revision",proof.released_row.logical_revision) ||
      !reader.ReadString("released_store_revision",proof.released_row.store_revision) ||
      !reader.ReadString("released_digest",proof.released_row.payload_digest) ||
      !reader.ReadNested("activation_fence",nested)) return false;
   if(!SWV5S5_MvpCodecDecode_SWV5_OwnershipFence(nested,proof.activation_fence) ||
      !reader.ReadNested("operator",nested)) return false;
   SWV5S5_MvpCodecReader op; op.Init(nested);
   if(!op.ReadString("operator_id",proof.operator_invocation.operator_id) ||
      !op.ReadString("authority_role",proof.operator_invocation.authority_role) ||
      !op.ReadString("authentication_reference",proof.operator_invocation.authentication_reference) ||
      !op.ReadInteger("authenticated_at",number) || !op.AtEnd()) return false;
   proof.operator_invocation.authenticated_at=(datetime)number;
   if(!reader.ReadString("clock_id",proof.clock_id) || !reader.ReadInteger("clock_authority",number) ||
      number!=(int)SWV5_TIME_AUTHORITY_BROKER_SERVER) return false;
   proof.clock_authority=(SWV5_TimeAuthority)number;
   if(!reader.ReadUnsigned("clock_sequence",proof.clock_sequence) ||
      !reader.ReadInteger("activated_at",number) || !reader.AtEnd()) return false;
   proof.activated_at=(datetime)number;
   return true;
}

void SWV5S5_MvpNewInactiveEpoch(const SWV5_HardKillState &released,const string transition_digest,
                               SWV5_HardKillState &inactive)
{
   ZeroMemory(inactive); inactive.contract_version=released.contract_version;
   inactive.persistence_namespace=released.persistence_namespace; inactive.account_namespace=released.account_namespace;
   inactive.latch_id="INACTIVE/"+transition_digest; inactive.latch_generation=released.latch_generation+1;
   inactive.state=SWV5_HARD_KILL_INACTIVE;
   // MQL ZeroMemory strings are NULL, not the contract's explicit empty
   // strings. Set the inactive sentinel fields deliberately.
   inactive.activation_reason=""; inactive.activation_authority="";
   inactive.release_evidence.release_id="";
   inactive.release_authority_reference.authority_record_id="";
   inactive.release_authority_reference.authority_record_digest="";
   inactive.release_authority_reference.release_id="";
   inactive.release_evidence.contract_version=released.contract_version;
   inactive.release_evidence.persistence_namespace=released.persistence_namespace;
   inactive.release_evidence.latch_id=inactive.latch_id;
   inactive.release_evidence.latch_generation=inactive.latch_generation;
   inactive.release_evidence.broker_evidence.contract_version=released.contract_version;
   inactive.release_evidence.broker_evidence.persistence_namespace=released.persistence_namespace;
   inactive.release_evidence.persistence_evidence.contract_version=released.contract_version;
   inactive.release_evidence.persistence_evidence.persistence_namespace=released.persistence_namespace;
   inactive.release_evidence.exposure_evidence.contract_version=released.contract_version;
   inactive.release_authority_reference.contract_version=released.contract_version;
}

class SWV5S5_MvpHardKillActivationAuthority
{
private:
   bool PhysicalRelease(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_ContractValidationContext &context,
                        const SWV5_HardKillState &released,SWV5_HardKillReleaseAuthorityRecord &record,
                        SWV5S5_MvpAuthorityRow &complete)
   {
      bool found=false; SWV5_HardKillState durable; string payload,digest;
      return store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE,released.release_authority_reference.authority_record_id,
                           complete,found) && found && complete.logical_revision==1 &&
         complete.state==(int)SWV5_HARD_KILL_RELEASED &&
         store.DeriveStoreRevision(complete.domain_key,complete.record_key,complete.logical_revision,
                                   complete.payload_digest,digest) && digest==complete.store_revision &&
         SWV5S5_MvpDecodeReleaseBundle(complete.payload,durable,record) &&
         SWV5S5_MvpReleaseBundle(released,record,payload,digest) && complete.payload==payload &&
         complete.payload_digest==digest && SWV5S5_MvpCompleteReleaseValid(context,durable,record);
   }

public:
   // Lossless typed projection of the accepted compact genesis envelope.
   // This reads ACTIVE; it cannot clear a latch or issue a release authority.
   bool LoadGenesisActive(SWV5S5_MvpSqliteAuthorityStore &store,
                          const SWV5_ContractValidationContext &context,
                          const SWV5_PersistenceNamespace &scope,const SWV5_AccountRiskNamespace &account,
                          SWV5_HardKillState &active)
   {
      ZeroMemory(active); SWV5S5_MvpAuthorityRow current,genesis; bool found=false; string digest;
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,found) || !found ||
         !store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"GENESIS",genesis,found) || !found ||
         current.state!=(int)SWV5_HARD_KILL_ACTIVE || current.logical_revision!=1 ||
         current.payload!=genesis.payload || current.payload_digest!=genesis.payload_digest ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,current.payload,digest) || digest!=current.payload_digest ||
         !SWV5S5_MvpVersionExact(context,scope.contract_version) ||
         !SWV5S5_MvpVersionExact(context,account.contract_version) ||
         account.broker_identity!=scope.ownership_namespace.broker_identity ||
         account.server!=scope.ownership_namespace.server || account.account_login!=scope.ownership_namespace.account_login ||
         account.strategy_id!=scope.ownership_namespace.strategy_id || account.magic!=scope.ownership_namespace.magic ||
         account.account_currency!=SWV5S5_MVP_ACCOUNT_CURRENCY || account.account_mode!=SWV5_ACCOUNT_MODE_HEDGING ||
         account.snapshot_epoch==0 || account.snapshot_sequence==0 ||
         account.authoritative_source!=SWV5_AUTHORITY_LIVE_BROKER_STATE) return false;
      SWV5S5_MvpCodecReader reader; reader.Init(current.payload); string id,manifest,domain,reason,authority,latch;
      ulong generation,latch_generation,release_generation;
      if(!reader.ReadString("genesis_id",id) || !reader.ReadString("manifest_digest",manifest) ||
         !reader.ReadString("domain",domain) || !reader.ReadUnsigned("genesis_generation",generation) ||
         !reader.ReadString("latch_id",latch) || !reader.ReadUnsigned("latch_generation",latch_generation) ||
         !reader.ReadUnsigned("release_generation",release_generation) || !reader.ReadString("activation_reason",reason) ||
         !reader.ReadString("activation_authority",authority) || !reader.AtEnd() ||
         !SWV5S5_IsDigest64Lower(id) || !SWV5S5_MvpGenesisManifestDigest(digest) || manifest!=digest ||
         domain!=SWV5S5_MVP_DOMAIN_HARD_KILL || generation!=1 || latch!="GENESIS-LATCH/"+id ||
         latch_generation!=1 || release_generation!=0 || reason!="NAMESPACE_GENESIS_NOT_RECONCILED" ||
         authority!=SWV5S5_MVP_GENESIS_POLICY || current.updated_at>context.clock_time) return false;
      active.contract_version=context.expected_version; active.persistence_namespace=scope; active.account_namespace=account;
      active.latch_id=latch; active.latch_generation=1; active.state=SWV5_HARD_KILL_ACTIVE;
      active.activation_reason=reason; active.activation_authority=authority; active.activated_at=current.updated_at;
      active.release_evidence.contract_version=context.expected_version; active.release_evidence.persistence_namespace=scope;
      active.release_evidence.latch_id=latch; active.release_evidence.latch_generation=1;
      active.release_evidence.broker_evidence.contract_version=context.expected_version;
      active.release_evidence.persistence_evidence.contract_version=context.expected_version;
      active.release_evidence.exposure_evidence.contract_version=context.expected_version;
      active.release_authority_reference.contract_version=context.expected_version;
      return true;
   }

   bool PrepareActivation(SWV5S5_MvpSqliteAuthorityStore &store,
                           const SWV5_ContractValidationContext &context,
                           const SWV5S5_MvpOperatorInvocation &operator_invocation,const bool attended,
                           const SWV5_HardKillState &released,const SWV5_InstanceLease &lease,
                           const SWV5S5_MvpAuthorityRow &expected_current,
                           SWV5S5_MvpAuthorityMutation &history_mutation,
                           SWV5S5_MvpAuthorityMutation &current_mutation,
                           SWV5S5_MvpAuthorityRow &ownership,SWV5_HardKillState &inactive)
   {
      ZeroMemory(inactive); ZeroMemory(history_mutation); ZeroMemory(current_mutation);
      if(!attended || released.state!=SWV5_HARD_KILL_RELEASED ||
         !SWV5S5_MvpOperatorInvocationValid(operator_invocation,context.clock_time) ||
         released.latch_generation==18446744073709551615 ||
         !SWV5S5_MvpLeaseCurrentForClock(context,lease.fence,lease) ||
         !SWV5S5_EqualOwnershipKey(lease.fence.ownership_namespace,released.persistence_namespace.ownership_namespace)) return false;
      SWV5S5_MvpLeasePublicationAuthority leases; SWV5_InstanceLease durable_lease;
      if(!leases.LoadCurrentLease(store,lease.fence.ownership_namespace,lease.fence,durable_lease,ownership) ||
         !SWV5S5_MvpLeaseExact(lease,durable_lease)) return false;
      SWV5S5_MvpAuthorityRow current,complete; SWV5_HardKillReleaseAuthorityRecord record;
      string payload,digest; bool found=false;
      if(!PhysicalRelease(store,context,released,record,complete) ||
         !SWV5S5_CanonicalHardKillState("hard_kill",released,payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,payload,digest) ||
         !store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,found) || !found ||
         current.state!=(int)SWV5_HARD_KILL_RELEASED || current.payload!=payload || current.payload_digest!=digest ||
         current.logical_revision!=expected_current.logical_revision || current.store_revision!=expected_current.store_revision ||
         current.payload_digest!=expected_current.payload_digest || current.state!=expected_current.state ||
         current.payload!=expected_current.payload || current.logical_revision==18446744073709551615) return false;
      SWV5S5_MvpHardKillActivationProof proof; ZeroMemory(proof);
      proof.release_bundle=complete.payload; proof.released_row=current; proof.activation_fence=lease.fence;
      proof.operator_invocation=operator_invocation; proof.clock_id=context.clock_id;
      proof.clock_authority=context.clock_authority; proof.clock_sequence=context.clock_sequence;
      proof.activated_at=context.clock_time;
      string history_payload,transition_digest;
      if(!SWV5S5_MvpActivationPayload(proof,history_payload,transition_digest)) return false;
      SWV5S5_MvpNewInactiveEpoch(released,transition_digest,inactive);
      SWV5S5_MvpAuthorityRow history; bool history_found=false;
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_HISTORY,inactive.latch_id,history,history_found) || history_found ||
         !SWV5S5_CanonicalHardKillState("hard_kill",inactive,payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,payload,digest)) return false;
      SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_RELEASE_HISTORY,inactive.latch_id,history,false,1,
         (int)SWV5_HARD_KILL_RELEASED,transition_digest,history_payload,context.clock_time,history_mutation);
      SWV5S5_MvpPrepareMutation(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,true,current.logical_revision+1,
         (int)SWV5_HARD_KILL_INACTIVE,digest,payload,context.clock_time,current_mutation);
      return true;
   }

   bool TryActivateInactiveAfterValidatedRelease(SWV5S5_MvpSqliteAuthorityStore &store,
                           const SWV5_ContractValidationContext &context,
                           const SWV5S5_MvpOperatorInvocation &operator_invocation,const bool attended,
                           const SWV5_HardKillState &released,const SWV5_InstanceLease &lease,
                           const SWV5S5_MvpAuthorityRow &expected_current,
                           SWV5_HardKillState &inactive,SWV5S5_MvpAuthorityRow &committed)
   {
      SWV5S5_MvpAuthorityMutation history_mutation,current_mutation;
      SWV5S5_MvpAuthorityRow ownership,history;
      if(!PrepareActivation(store,context,operator_invocation,attended,released,lease,expected_current,
                            history_mutation,current_mutation,ownership,inactive) ||
         !store.CompareAndSetPairWithGuard(history_mutation,current_mutation,ownership,history,committed))
      { ZeroMemory(inactive); ZeroMemory(committed); return false; }
      return ValidateEligibility(store,context,inactive,lease,committed);
   }

   bool EligibilityHorizon(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_ContractValidationContext &context,
                            const SWV5_HardKillState &inactive,const SWV5_InstanceLease &lease,datetime &expires_at)
   {
      expires_at=0; SWV5S5_MvpAuthorityRow current,history; bool found=false;
      SWV5S5_MvpHardKillActivationProof proof; SWV5_HardKillState released; SWV5_HardKillReleaseAuthorityRecord record;
      if(!ValidateEligibility(store,context,inactive,lease,current) ||
         !store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_HISTORY,inactive.latch_id,history,found) || !found ||
         !SWV5S5_MvpDecodeActivation(history.payload,proof) ||
         !SWV5S5_MvpDecodeReleaseBundle(proof.release_bundle,released,record)) return false;
      expires_at=record.expires_at; return context.clock_time<expires_at;
   }

   bool ValidateEligibility(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_ContractValidationContext &context,
                             const SWV5_HardKillState &inactive,const SWV5_InstanceLease &lease,
                             SWV5S5_MvpAuthorityRow &current)
   { return ValidateEligibilityCore(store,context,inactive,lease,true,current); }

   // Claim completion checks the lineage and its deadline bound into the
   // coherent admission snapshot, not a second non-time Hard Kill decision.
   // A later latch remains authoritative for ALL subsequent admissions.
   bool ValidateAdmittedEligibility(SWV5S5_MvpSqliteAuthorityStore &store,
                                     const SWV5_ContractValidationContext &context,
                                     const SWV5S5_AdmissionProof &admission,const SWV5_InstanceLease &lease)
   {
      string first,second;
      if(!SWV5S5_CanonicalHardKillState("hard_kill",admission.snapshot.collect_v1.hard_kill.state,first) ||
         !SWV5S5_CanonicalHardKillState("hard_kill",admission.snapshot.collect_v2.hard_kill.state,second) ||
         first!=second || admission.snapshot.snapshot_digest=="" ||
         admission.snapshot.claim_clock.observed_at!=context.clock_time ||
         admission.snapshot.claim_clock.clock_sequence!=context.clock_sequence) return false;
      SWV5S5_MvpAuthorityRow projection;
      return ValidateEligibilityCore(store,context,admission.snapshot.collect_v1.hard_kill.state,lease,false,projection);
   }

private:
   bool ValidateEligibilityCore(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_ContractValidationContext &context,
                                 const SWV5_HardKillState &inactive,const SWV5_InstanceLease &lease,
                                 const bool require_current,SWV5S5_MvpAuthorityRow &current)
   {
      ZeroMemory(current); bool found=false; string payload,digest;
      if(inactive.state!=SWV5_HARD_KILL_INACTIVE || inactive.latch_id=="" ||
         !SWV5S5_MvpLeaseCurrentForClock(context,lease.fence,lease) ||
         !SWV5S5_CanonicalHardKillState("hard_kill",inactive,payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,payload,digest)) return false;
      if(require_current && (!store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,found) || !found ||
         current.state!=(int)SWV5_HARD_KILL_INACTIVE || current.payload!=payload || current.payload_digest!=digest ||
         !store.DeriveStoreRevision(current.domain_key,current.record_key,current.logical_revision,
                                    current.payload_digest,digest) || digest!=current.store_revision)) return false;
      SWV5S5_MvpLeasePublicationAuthority leases; SWV5_InstanceLease durable_lease; SWV5S5_MvpAuthorityRow ownership;
      if(!leases.LoadCurrentLease(store,lease.fence.ownership_namespace,lease.fence,durable_lease,ownership) ||
         !SWV5S5_MvpLeaseExact(lease,durable_lease)) return false;
      SWV5S5_MvpAuthorityRow history,complete; SWV5S5_MvpHardKillActivationProof proof;
      SWV5_HardKillState released,derived; SWV5_HardKillReleaseAuthorityRecord record;
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_HISTORY,inactive.latch_id,history,found) || !found ||
         history.logical_revision!=1 || history.state!=(int)SWV5_HARD_KILL_RELEASED ||
         !store.DeriveStoreRevision(history.domain_key,history.record_key,history.logical_revision,
                                    history.payload_digest,digest) || digest!=history.store_revision ||
         !SWV5S5_MvpDecodeActivation(history.payload,proof) ||
         !SWV5S5_MvpActivationPayload(proof,payload,digest) || history.payload!=payload || history.payload_digest!=digest ||
         inactive.latch_id!="INACTIVE/"+digest || proof.released_row.logical_revision==18446744073709551615 ||
         (require_current && (current.logical_revision!=proof.released_row.logical_revision+1 ||
                              current.updated_at!=proof.activated_at)) || history.updated_at!=proof.activated_at ||
         proof.activated_at>context.clock_time || proof.activated_at<=0 ||
         proof.clock_id!=context.clock_id || proof.clock_authority!=context.clock_authority ||
         proof.clock_sequence==0 || proof.clock_sequence>context.clock_sequence ||
         !SWV5S5_MvpOperatorInvocationValid(proof.operator_invocation,proof.activated_at) ||
         !SWV5S5_EqualFence(proof.activation_fence,lease.fence) ||
         !SWV5S5_MvpDecodeReleaseBundle(proof.release_bundle,released,record) ||
         !PhysicalRelease(store,context,released,record,complete) || complete.payload!=proof.release_bundle ||
         proof.activated_at<record.released_at || proof.activated_at>=record.expires_at ||
         !SWV5S5_EqualOwnershipKey(lease.fence.ownership_namespace,released.persistence_namespace.ownership_namespace) ||
         !SWV5S5_CanonicalHardKillState("hard_kill",released,payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,payload,digest) ||
         proof.released_row.payload_digest!=digest ||
         !store.DeriveStoreRevision(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",proof.released_row.logical_revision,
                                    digest,payload) || payload!=proof.released_row.store_revision) return false;
      SWV5S5_MvpNewInactiveEpoch(released,history.payload_digest,derived);
      string expected,admitted;
      return SWV5S5_CanonicalHardKillState("hard_kill",derived,expected) &&
         SWV5S5_CanonicalHardKillState("hard_kill",inactive,admitted) && expected==admitted &&
         (!require_current || expected==current.payload);
   }
};

#endif
