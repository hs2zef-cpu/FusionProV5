#ifndef SW_V5_S5_MVP_CONTINUATION_LINEAGE_MQH
#define SW_V5_S5_MVP_CONTINUATION_LINEAGE_MQH
// ATTENDED DEMO CONTINUATION ONLY. Historical structure is NOT eligibility.
// This header is not included by PREFLIGHT/D1/Admission/Claim/D6.
#include "SW_V5_S5_MvpAttendedAdministration.mqh"
#include "SW_V5_S5_MvpOwnershipAuthority.mqh"

bool SWV5S5_MvpContinuationRowValid(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5S5_MvpAuthorityRow &row)
{
   string revision,digest;
   if(row.logical_revision==0 ||
      !store.DeriveStoreRevision(row.domain_key,row.record_key,row.logical_revision,row.payload_digest,revision) ||
      revision!=row.store_revision) return false;
   if(row.domain_key==SWV5S5_MVP_DOMAIN_OWNERSHIP && row.record_key==SWV5S5_MVP_OWNERSHIP_KEY)
   {
      SWV5S5_LeaseLivenessAuthorityView view;
      if(!SWV5S5_MvpDecodeOwnershipLeasePhysical(row.payload,view.lease) || !SWV5S5_DeriveLeaseProjection(view)) return false;
      digest=view.projection_digest;
   }
   else if(row.domain_key==SWV5S5_MVP_DOMAIN_PRODUCER_TRUST && row.record_key=="CURRENT")
   {
      SWV5S5_ProducerTrustRecord trust; SWV5S5_ProducerTrustAnchor anchor; string op,auth;
      if(!SWV5S5_MvpDecodeProducerTrustPhysical(row.payload,trust,anchor,op,auth) ||
         !SWV5S5_DeriveProducerTrustDigest(trust,digest) || digest!=trust.record_digest) return false;
   }
   else if(row.domain_key==SWV5S5_MVP_DOMAIN_BOOTSTRAP_ZERO && row.record_key=="CURRENT")
   {
      SWV5S5_MvpBootstrapZeroStateAuthority zero;
      if(!SWV5S5_MvpDecodeBootstrapZero(row.payload,zero) || !SWV5S5_MvpBootstrapZeroDigest(zero,digest)) return false;
   }
   else if(row.domain_key==SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE)
   {
      SWV5S5_MvpReconciliationGovernanceBundle governance;
      if(!SWV5S5_MvpDecodeGovernance(row.payload,governance) || !SWV5S5_MvpGovernanceDigest(governance,digest)) return false;
   }
   else if(!SWV5S5_DomainDigest(row.domain_key,row.payload,digest)) return false;
   return digest==row.payload_digest;
}

struct SWV5S5_MvpContinuationHistoricalLineage
{
   SWV5S5_MvpAuthorityRow inactive_row,history_row;
   SWV5_HardKillState inactive;
   ulong maximum_completed_release_generation;
};

// Completed means a COMPLETE release paired with its immutable INACTIVE
// activation history. A dangling release row is not completed lineage.
bool SWV5S5_MvpContinuationHistoryMaximum(SWV5S5_MvpSqliteAuthorityStore &store,
   const SWV5_ContractValidationContext &fresh,const SWV5_PersistenceNamespace &scope,
   const SWV5_AccountRiskNamespace &account,const SWV5_OwnershipFence &fence,
   const string in_flight_latch,ulong &maximum)
{
   maximum=0; SWV5S5_MvpAuthorityRow rows[]; ulong generations[],latches[]; string complete_ids[];
   if(!store.ReadAllRows(rows)) return false;
   for(int i=0;i<ArraySize(rows);i++) if(rows[i].domain_key==SWV5S5_MVP_DOMAIN_RELEASE_HISTORY)
   {
      SWV5S5_MvpHardKillActivationProof p; SWV5_HardKillState released; SWV5_HardKillReleaseAuthorityRecord a;
      SWV5S5_MvpAuthorityRow complete; bool found=false; string payload,digest,revision,account_a,account_b;
      if(!SWV5S5_MvpContinuationRowValid(store,rows[i]) || rows[i].logical_revision!=1 ||
         rows[i].state!=(int)SWV5_HARD_KILL_RELEASED || !SWV5S5_MvpDecodeActivation(rows[i].payload,p) ||
         !SWV5S5_MvpActivationPayload(p,payload,digest) || payload!=rows[i].payload || digest!=rows[i].payload_digest ||
         rows[i].record_key!="INACTIVE/"+digest || rows[i].updated_at!=p.activated_at ||
         !SWV5S5_MvpDecodeReleaseBundle(p.release_bundle,released,a) || released.latch_id==in_flight_latch ||
         !SWV5S5_EqualNamespace(released.persistence_namespace,scope) || !SWV5S5_EqualFence(p.activation_fence,fence) ||
         !SWV5S5_CanonicalAccountNamespace("account",account,account_a) ||
         !SWV5S5_CanonicalAccountNamespace("account",released.account_namespace,account_b) || account_a!=account_b ||
         p.clock_id!=fresh.clock_id || p.clock_authority!=fresh.clock_authority || p.clock_sequence==0 || p.clock_sequence>fresh.clock_sequence ||
         p.activated_at>fresh.clock_time || !SWV5S5_MvpOperatorInvocationValid(p.operator_invocation,p.activated_at) ||
         !store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE,a.authority_record_id,complete,found) || !found ||
         !SWV5S5_MvpContinuationRowValid(store,complete) || complete.logical_revision!=1 ||
         complete.state!=(int)SWV5_HARD_KILL_RELEASED || complete.payload!=p.release_bundle ||
         !SWV5S5_CanonicalHardKillState("hard_kill",released,payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,payload,digest) || digest!=p.released_row.payload_digest ||
         !store.DeriveStoreRevision(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",p.released_row.logical_revision,digest,revision) ||
         revision!=p.released_row.store_revision) return false;
      SWV5_ContractValidationContext historical=fresh; historical.clock_time=p.activated_at;
      historical.clock_sequence=p.clock_sequence; historical.evaluation_sequence=p.clock_sequence;
      if(!SWV5S5_MvpCompleteReleaseValid(historical,released,a) || a.release_generation==0 || a.latch_generation==0) return false;
      const int n=ArraySize(generations);
      for(int j=0;j<n;j++) if(generations[j]==a.release_generation || latches[j]==a.latch_generation || complete_ids[j]==a.authority_record_id) return false;
      ArrayResize(generations,n+1);ArrayResize(latches,n+1);ArrayResize(complete_ids,n+1);
      generations[n]=a.release_generation;latches[n]=a.latch_generation;complete_ids[n]=a.authority_record_id;
      if(a.release_generation>maximum)maximum=a.release_generation;
   }
   if(maximum==0 || maximum!=(ulong)ArraySize(generations)) return false;
   for(int i=0;i<ArraySize(generations);i++)
   {
      if(generations[i]==1) {if(latches[i]!=1)return false;continue;}
      bool prior=false;
      for(int j=0;j<ArraySize(generations);j++) if(generations[j]+1==generations[i] && latches[j]+2==latches[i])prior=true;
      if(!prior)return false;
   }
   int in_flight=0;
   for(int i=0;i<ArraySize(rows);i++) if(rows[i].domain_key==SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE)
   {
      SWV5_HardKillState released;SWV5_HardKillReleaseAuthorityRecord a;
      if(!SWV5S5_MvpContinuationRowValid(store,rows[i]) || rows[i].logical_revision!=1 ||
         rows[i].state!=(int)SWV5_HARD_KILL_RELEASED || !SWV5S5_MvpDecodeReleaseBundle(rows[i].payload,released,a) ||
         rows[i].record_key!=a.authority_record_id) return false;
      bool paired=false;for(int j=0;j<ArraySize(complete_ids);j++)if(complete_ids[j]==a.authority_record_id)paired=true;
      if(!paired)
      {
         if(in_flight_latch=="" || released.latch_id!=in_flight_latch || a.release_generation!=maximum+1 || ++in_flight>1)return false;
         SWV5_ContractValidationContext historical=fresh; historical.clock_time=a.released_at;
         if(!SWV5S5_MvpCompleteReleaseValid(historical,released,a))return false;
      }
   }
   return true;
}

// Deliberately returns historical data only, no decision/grant/eligible flag.
// Ordinary eligibility continues to use the unchanged expiry validators.
class SWV5S5_MvpContinuationStructuralReader
{
public:
   bool LoadExpiredInactive(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_ContractValidationContext &fresh,
                            const SWV5_InstanceLease &lease,const SWV5_PersistenceNamespace &scope,
                            const SWV5_AccountRiskNamespace &account,SWV5S5_MvpContinuationHistoricalLineage &lineage)
   {
      ZeroMemory(lineage); bool found=false; string id,payload,digest,revision,a,b;
      SWV5S5_MvpHardKillActivationProof proof; SWV5_HardKillState released;
      SWV5_HardKillReleaseAuthorityRecord record; SWV5S5_MvpAuthorityRow complete;
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",lineage.inactive_row,found) || !found ||
         lineage.inactive_row.state!=(int)SWV5_HARD_KILL_INACTIVE ||
         !SWV5S5_MvpContinuationRowValid(store,lineage.inactive_row) ||
         !SWV5S5_MvpCanonicalScalar(lineage.inactive_row.payload,"latch_id","s",id) ||
         !store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_HISTORY,id,lineage.history_row,found) || !found ||
         !SWV5S5_MvpContinuationRowValid(store,lineage.history_row) ||
         lineage.history_row.logical_revision!=1 || lineage.history_row.state!=(int)SWV5_HARD_KILL_RELEASED ||
         !SWV5S5_MvpDecodeActivation(lineage.history_row.payload,proof) ||
         !SWV5S5_MvpActivationPayload(proof,payload,digest) || payload!=lineage.history_row.payload ||
         digest!=lineage.history_row.payload_digest || id!="INACTIVE/"+digest ||
         proof.clock_id!=fresh.clock_id || proof.clock_authority!=fresh.clock_authority ||
         proof.clock_sequence==0 || proof.clock_sequence>fresh.clock_sequence ||
         proof.activated_at<=0 || proof.activated_at>fresh.clock_time ||
         !SWV5S5_MvpOperatorInvocationValid(proof.operator_invocation,proof.activated_at) ||
         !SWV5S5_EqualFence(proof.activation_fence,lease.fence) ||
         !SWV5S5_MvpDecodeReleaseBundle(proof.release_bundle,released,record) ||
         !SWV5S5_EqualNamespace(released.persistence_namespace,scope) ||
         !SWV5S5_CanonicalAccountNamespace("account",released.account_namespace,a) ||
         !SWV5S5_CanonicalAccountNamespace("account",account,b) || a!=b ||
         fresh.clock_time<record.expires_at || proof.activated_at<record.released_at ||
         proof.activated_at>=record.expires_at ||
         proof.released_row.logical_revision==18446744073709551615 ||
         lineage.inactive_row.logical_revision!=proof.released_row.logical_revision+1 ||
         lineage.inactive_row.updated_at!=proof.activated_at || lineage.history_row.updated_at!=proof.activated_at ||
         !store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE,record.authority_record_id,complete,found) || !found ||
         !SWV5S5_MvpContinuationRowValid(store,complete) || complete.logical_revision!=1 ||
         complete.state!=(int)SWV5_HARD_KILL_RELEASED || complete.payload!=proof.release_bundle) return false;
      // Validate at the original activation event, never at a forged current
      // execution time. The caller cannot use this reader as eligibility.
      SWV5_ContractValidationContext historical=fresh; historical.clock_time=proof.activated_at;
      historical.clock_sequence=proof.clock_sequence; historical.evaluation_sequence=proof.clock_sequence;
      if(!SWV5S5_MvpCompleteReleaseValid(historical,released,record) ||
         !SWV5S5_CanonicalHardKillState("hard_kill",released,payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,payload,digest) ||
         digest!=proof.released_row.payload_digest ||
         !store.DeriveStoreRevision(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",proof.released_row.logical_revision,digest,revision) ||
         revision!=proof.released_row.store_revision) return false;
      SWV5S5_MvpNewInactiveEpoch(released,lineage.history_row.payload_digest,lineage.inactive);
      if(!SWV5S5_CanonicalHardKillState("hard_kill",lineage.inactive,payload) ||
         payload!=lineage.inactive_row.payload || lineage.inactive.latch_generation==18446744073709551615) return false;
      return SWV5S5_MvpContinuationHistoryMaximum(store,fresh,scope,account,lease.fence,"",lineage.maximum_completed_release_generation) &&
         record.release_generation==lineage.maximum_completed_release_generation &&
         record.release_generation>0 && record.release_generation<18446744073709551615;
   }
};
#endif
