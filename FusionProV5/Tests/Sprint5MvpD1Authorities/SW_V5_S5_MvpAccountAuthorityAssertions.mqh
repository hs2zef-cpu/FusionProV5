#ifndef SW_V5_S5_MVP_ACCOUNT_AUTHORITY_ASSERTIONS_MQH
#define SW_V5_S5_MVP_ACCOUNT_AUTHORITY_ASSERTIONS_MQH
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.
#include "SW_V5_S5_MvpBasketAuthorityAssertions.mqh"

class SWV5S5_TestAccountPlatform : public SWV5S5_MvpD1ReadOnlyPlatform
{
public:
   int fault,account_reads; double balance_delta; bool change_after_margin;
   SWV5S5_TestAccountPlatform(void) { fault=0; account_reads=0; balance_delta=0.0; change_after_margin=false; }
   virtual bool CaptureProfile(const string symbol,SWV5S5_MvpRuntimeProfileObservation &p,datetime &at)
   {
      if(!SWV5S5_MvpD1ReadOnlyPlatform::CaptureProfile(symbol,p,at)) return false;
      if(fault==1) p.server="FOREIGN-SERVER";
      if(fault==2) p.account_mode=SWV5_ACCOUNT_MODE_NETTING;
      if(fault==3) p.account_currency="EUR";
      return fault!=4;
   }
   virtual bool CaptureFlatAccount(const datetime at,SWV5S5_MvpAccountObservation &o)
   {
      account_reads++;
      if(!SWV5S5_MvpD1ReadOnlyPlatform::CaptureFlatAccount(at,o)) return false;
      o.balance+=balance_delta; o.equity+=balance_delta; o.free_margin+=balance_delta; return true;
   }
   virtual bool CalculateMargin(const int direction,const string symbol,const double volume,const double price,double &margin)
   {
      if(change_after_margin) balance_delta=7.0; // A forbidden second account read would see different money.
      return SWV5S5_MvpD1ReadOnlyPlatform::CalculateMargin(direction,symbol,volume,price,margin);
   }
};

bool SWV5S5_TestAccountGenesisLease(const string path,SWV5_PersistenceNamespace &scope,SWV5_InstanceLease &lease,
                                    SWV5_ContractValidationContext &context,string &ns,SWV5S5_MvpSqliteAuthorityStore &store)
{
   FileDelete(path,FILE_COMMON); FileDelete(path+"-wal",FILE_COMMON); FileDelete(path+"-shm",FILE_COMMON);
   SWV5S5_MvpD1MakeScope(scope,lease,ns); SWV5S5_MvpD1MakeContext(context);
   SWV5S5_MvpInitProductionVersion(context.expected_version);
   SWV5S5_MvpOperatorInvocation op; op.operator_id="ACCOUNT-TEST-OP"; op.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
   op.authentication_reference="ACCOUNT-TEST-AUTH"; op.authenticated_at=context.clock_time;
   SWV5S5_MvpLeasePublicationAuthority owner; SWV5S5_MvpAuthorityRow row;
   return SWV5S5_MvpD1ProvisionGenesis(path,ns,op,context.clock_time) && store.Open(path,ns) &&
      owner.Publish(store,lease,0,"","",0,context.clock_time,row);
}

bool SWV5S5_TestAccountUnauthorizedGeneration(const string path,const string ns)
{
   // Deliberate physical authority fault, with all digests re-sealed. It must
   // fail the generation policy, not merely an accidental checksum mismatch.
   SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpAccountRiskAuthority owner;
   SWV5S5_MvpAccountRiskAuthorityRecord record; SWV5S5_MvpAuthorityRow row; bool found=false;
   if(!store.OpenReadOnly(path,ns) || !owner.Load(store,record,row,found) || !found) return false;
   record.account_namespace.snapshot_sequence++; record.publication_sequence++;
   string payload,digest,revision;
   if(!SWV5S5_MvpAccountRiskEncode(record,payload) || !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_ACCOUNT_RISK,payload,digest) ||
      !store.DeriveStoreRevision(row.domain_key,row.record_key,row.logical_revision,digest,revision)) return false;
   store.Close();
   const int db=DatabaseOpen(path,DATABASE_OPEN_READWRITE|DATABASE_OPEN_COMMON);
   if(db==INVALID_HANDLE) return false;
   const int statement=DatabasePrepare(db,"UPDATE swv5_authority_rows SET payload=?1,payload_digest=?2,store_revision=?3 "
      "WHERE namespace_digest=?4 AND domain_key='MVP_ACCOUNT_RISK_AUTHORITY' AND record_key='CURRENT';");
   if(statement==INVALID_HANDLE) { DatabaseClose(db); return false; }
   bool ok=DatabaseBind(statement,0,payload) && DatabaseBind(statement,1,digest) &&
      DatabaseBind(statement,2,revision) && DatabaseBind(statement,3,ns);
   if(ok) { ResetLastError(); ok=DatabaseRead(statement) || GetLastError()==ERR_DATABASE_NO_MORE_DATA; }
   DatabaseFinalize(statement); DatabaseClose(db); return ok;
}

void SWV5S5_RunMvpAccountAuthorityAssertions(SWV5S5_MvpD1Collector &c)
{
   ZeroMemory(c); c.signature=1469598103934665603;
   const string path="mvp_account_authority_private.sqlite"; string ns;
   SWV5_PersistenceNamespace scope; SWV5_InstanceLease lease; SWV5_ContractValidationContext context;
   SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpAccountRiskAuthority owner;
   SWV5S5_MvpAccountRiskAuthorityRecord record,reloaded; SWV5S5_MvpAuthorityRow row,readback; bool found=false;
   SWV5S5_TestAccountPlatform platform; SWV5S5_MvpRuntimeProfileObservation profile; datetime at=0;
   const bool setup=SWV5S5_TestAccountGenesisLease(path,scope,lease,context,ns,store) &&
      platform.CaptureProfile(SWV5S5_MVP_SYMBOL,profile,at);
   SWV5S5_MvpD1Record(c,"ACCOUNT-01",setup && owner.Load(store,reloaded,readback,found) && !found);
   SWV5_AccountRiskNamespace fabricated; SWV5S5_MvpD1MakeAccountNamespace(scope,fabricated);
   SWV5S5_MvpD1Record(c,"ACCOUNT-02",setup && fabricated.snapshot_epoch==1 &&
      !owner.ValidateCurrent(store,scope,profile,reloaded,readback));
   const bool issued=setup && owner.Provision(store,context,scope,lease,platform,record,row);
   if(!issued) Print("ACCOUNT_ISSUANCE_FAILURE|",owner.LastFailure());
   SWV5S5_MvpD1Record(c,"ACCOUNT-03",issued);
   SWV5S5_MvpD1Record(c,"ACCOUNT-04",issued && record.account_namespace.snapshot_epoch==1 && record.account_namespace.snapshot_sequence==1);
   SWV5S5_MvpD1Record(c,"ACCOUNT-05",issued && record.account_namespace.authoritative_source==SWV5_AUTHORITY_LIVE_BROKER_STATE);
   string payload,digest; const bool roundtrip=issued && owner.Load(store,reloaded,readback,found) && found &&
      SWV5S5_MvpAccountRiskEncode(reloaded,payload) && payload==row.payload && readback.store_revision==row.store_revision;
   SWV5S5_MvpD1Record(c,"ACCOUNT-06",roundtrip);
   SWV5S5_MvpD1Record(c,"ACCOUNT-07",roundtrip && SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_ACCOUNT_RISK,payload,digest) && digest==row.payload_digest);
   SWV5S5_MvpD1Record(c,"ACCOUNT-08",issued && owner.Provision(store,context,scope,lease,platform,reloaded,readback) &&
      readback.payload==row.payload && readback.store_revision==row.store_revision && readback.updated_at==row.updated_at);
   platform.fault=1;
   SWV5S5_MvpD1Record(c,"ACCOUNT-09",issued && !owner.Provision(store,context,scope,lease,platform,reloaded,readback));
   platform.fault=0; SWV5_InstanceLease stale=lease; stale.fence.takeover_generation++;
   SWV5S5_MvpD1Record(c,"ACCOUNT-10",issued && !owner.Provision(store,context,scope,stale,platform,reloaded,readback));
   store.Close(); SWV5S5_MvpAccountRiskAuthority restarted;
   const bool restarted_ok=store.OpenReadOnly(path,ns) && restarted.ValidateCurrent(store,scope,profile,reloaded,readback);
   SWV5S5_MvpD1Record(c,"ACCOUNT-11",restarted_ok && readback.payload==row.payload && readback.store_revision==row.store_revision);
   SWV5S5_MvpD1Record(c,"ACCOUNT-12",restarted_ok && reloaded.account_namespace.snapshot_epoch==record.account_namespace.snapshot_epoch);
   SWV5S5_MvpD1Record(c,"ACCOUNT-13",restarted_ok && reloaded.account_namespace.snapshot_sequence==record.account_namespace.snapshot_sequence);
   // Physically publish a different valid owner, then ask the independent account
   // owner to reload. No fixture-issued account token is accepted.
   SWV5S5_MvpLeasePublicationAuthority lease_owner; SWV5S5_MvpAuthorityRow prior,changed; SWV5_InstanceLease takeover=lease;
   takeover.fence.owner.instance_id="ACCOUNT-TEST-TAKEOVER"; takeover.fence.takeover_generation++;
   takeover.fence.lease_version++; SWV5S5_SHA256("ACCOUNT-TEST-TAKEOVER-FENCE",takeover.fence.fencing_token_digest);
   SWV5S5_SHA256("ACCOUNT-TEST-TAKEOVER-LEASE",takeover.store_revision);
   bool lease_found=false;
   const bool taken=store.Open(path,ns) && store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,prior,lease_found) && lease_found &&
      lease_owner.Publish(store,takeover,prior.logical_revision,prior.store_revision,prior.payload_digest,prior.state,context.clock_time,changed);
   SWV5S5_MvpD1Record(c,"ACCOUNT-14",taken && owner.Provision(store,context,scope,takeover,platform,reloaded,readback) &&
      readback.payload==row.payload && readback.store_revision==row.store_revision && reloaded.authority_epoch==1);
   platform.fault=1; platform.CaptureProfile(SWV5S5_MVP_SYMBOL,profile,at);
   SWV5S5_MvpD1Record(c,"ACCOUNT-15",issued && !owner.ValidateCurrent(store,scope,profile,reloaded,readback));
   platform.fault=2; platform.CaptureProfile(SWV5S5_MVP_SYMBOL,profile,at);
   SWV5S5_MvpD1Record(c,"ACCOUNT-16",issued && !owner.ValidateCurrent(store,scope,profile,reloaded,readback));
   platform.fault=3; platform.CaptureProfile(SWV5S5_MVP_SYMBOL,profile,at);
   SWV5S5_MvpD1Record(c,"ACCOUNT-17",issued && !owner.ValidateCurrent(store,scope,profile,reloaded,readback));
   platform.fault=0; store.Close();
   const bool corrupted=SWV5S5_TestBasketFaultSql(path,"UPDATE swv5_authority_rows SET payload=payload||'CORRUPT' WHERE domain_key='MVP_ACCOUNT_RISK_AUTHORITY';");
   SWV5S5_MvpD1Record(c,"ACCOUNT-18",corrupted && store.OpenReadOnly(path,ns) && !owner.Load(store,reloaded,readback,found));
   store.Close();

   const string e2e_path="mvp_account_authority_binding.sqlite"; SWV5S5_MvpControlledDemoAuthoritySeed seed;
   SWV5S5_MvpD1PhysicalSeedStatus seed_status;
   const bool seeded=SWV5S5_MvpD1BuildE2ESeed(e2e_path,seed,ns,seed_status);
   const bool removed=seeded && SWV5S5_TestBasketFaultSql(e2e_path,
      "DELETE FROM swv5_authority_rows WHERE domain_key='MVP_ACCOUNT_RISK_AUTHORITY';");
   SWV5S5_MvpD1Record(c,"ACCOUNT-19",removed && store.Open(e2e_path,ns) &&
      !owner.Provision(store,seed.context,seed.current_trust.persistence_namespace,seed.current_lease,platform,reloaded,readback) &&
      store.ReadRow(SWV5S5_MVP_DOMAIN_ACCOUNT_RISK,"CURRENT",readback,found) && !found);
   store.Close();
   SWV5S5_MvpBrokerEvidenceStore evidence; SWV5S5_MvpControlledDemoAuthorityPort port;
   SWV5S5_MvpControlledDemoInvocation invocation; SWV5S5_MvpControlledDemoPreflightEvidence preflight;
   SWV5S5_MvpD1MakeInvocation(e2e_path,ns,MODE_PREFLIGHT,invocation);
   const bool configured=evidence.Configure(e2e_path,ns) && port.Configure(e2e_path,ns,seed,&platform,&evidence);
   SWV5S5_MvpD1Record(c,"ACCOUNT-20",removed && configured && !port.CollectReadOnlyPreflight(invocation,1,preflight) &&
      store.OpenReadOnly(e2e_path,ns) && store.ReadRow(SWV5S5_MVP_DOMAIN_ACCOUNT_RISK,"CURRENT",readback,found) && !found);
   store.Close();
   const string positive_path="mvp_account_authority_positive.sqlite";
   const bool fresh_seed=SWV5S5_MvpD1BuildE2ESeed(positive_path,seed,ns,seed_status);
   SWV5S5_MvpAccountObservationProducer producer; SWV5S5_MvpAccountObservation observed;
   SWV5S5_MvpAccountObservationEnvelope observation,new_observation;
   const bool captured=fresh_seed && store.OpenReadOnly(positive_path,ns) && producer.CaptureInitialFlat(store,seed.context,
      seed.current_trust.persistence_namespace,seed.current_lease,platform,observed,observation);
   SWV5S5_MvpD1Record(c,"ACCOUNT-21",captured && observation.account.balance==observed.balance &&
      observation.account.equity==observed.equity && observation.account.free_margin==observed.free_margin &&
      observation.account.trading_day_start==observed.trading_day_start && observation.account.observed_at==observed.observed_at);
   SWV5S5_MvpD1Record(c,"ACCOUNT-22",captured && observed.complete && observed.positions_total==0 && observed.orders_total==0 &&
      observation.exposure.complete && observation.exposure.aggregate_volume==0.0 && observation.exposure.live_basket_count==0);
   const SWV5_AccountRiskNamespace account=seed.risk_observation.account_namespace;
   SWV5S5_MvpD1Record(c,"ACCOUNT-23",captured && SWV5S5_EqualAccountNamespace(observation.account.account_namespace,account));
   SWV5S5_MvpD1Record(c,"ACCOUNT-24",captured && SWV5S5_EqualAccountNamespace(observation.exposure.account_namespace,account));
   SWV5S5_MvpD1Record(c,"ACCOUNT-25",fresh_seed && SWV5S5_EqualAccountNamespace(seed.hard_kill_state.account_namespace,account));
   SWV5S5_MvpD1Record(c,"ACCOUNT-26",fresh_seed && SWV5S5_EqualAccountNamespace(seed.risk_observation.basket.account_namespace,account));
   store.Close();
   SWV5S5_MvpControlledDemoAuthorityPort d1_port; SWV5S5_MvpBrokerEvidenceStore d1_evidence;
   SWV5S5_MvpD1MakeInvocation(positive_path,ns,MODE_D1_BUY,invocation);
   platform.account_reads=0; platform.change_after_margin=true;
   const bool prepared=fresh_seed && d1_evidence.Configure(positive_path,ns) && d1_port.Configure(positive_path,ns,seed,&platform,&d1_evidence) &&
      d1_port.PrepareD1AuthorityPath(invocation,1,preflight);
   if(!prepared) Print("ACCOUNT_D1_PREPARE_FAILURE|",d1_port.LastStage());
   SWV5_RiskEvaluationInput candidate; SWV5_RiskAuthorization authorization;
   const bool binding=prepared && d1_port.ReadPreparedRiskBinding(candidate,authorization);
   SWV5S5_MvpAccountObservationEnvelope coherent;
   const bool coherent_read=binding && d1_port.ReadPreparedObservation(coherent);
   const int preparation_reads=platform.account_reads;
   platform.change_after_margin=false;
   SWV5S5_MvpD1Record(c,"ACCOUNT-27",binding && SWV5S5_EqualAccountNamespace(candidate.margin_authority_record.account_namespace,account));
   SWV5S5_MvpD1Record(c,"ACCOUNT-28",binding && SWV5S5_EqualAccountNamespace(candidate.basket_risk_authority_record.account_namespace,account));
   SWV5S5_MvpD1Record(c,"ACCOUNT-29",binding && SWV5S5_EqualAccountNamespace(candidate.account_namespace,account) &&
      SWV5S5_EqualAccountNamespace(candidate.account.account_namespace,account) && SWV5S5_EqualAccountNamespace(candidate.exposure.account_namespace,account) &&
      SWV5S5_EqualAccountNamespace(candidate.basket.account_namespace,account) && SWV5S5_EqualAccountNamespace(candidate.projected.account_namespace,account) &&
      SWV5S5_EqualAccountNamespace(candidate.hard_kill_state.account_namespace,account));
   SWV5S5_MvpD1Record(c,"ACCOUNT-30",binding && authorization.disposition==SWV5_RISK_ALLOW &&
      authorization.risk_snapshot_epoch==account.snapshot_epoch && authorization.risk_snapshot_sequence==account.snapshot_sequence);
   SWV5S5_AdmissionSnapshot admission;
   const bool admitted=prepared && d1_port.PreparePermitSemantics() && d1_port.CommitPermitPhysical() &&
      d1_port.CollectAdmissionSameEvent() && d1_port.ReadAdmissionCollections(admission);
   SWV5S5_AccountAuthorityView projection; projection.account_namespace=account;
   const bool projected=SWV5S5_DeriveAccountProjection(projection);
   SWV5S5_MvpD1Record(c,"ACCOUNT-31",admitted && projected &&
      admission.collect_v1.account.projection_digest==projection.projection_digest &&
      SWV5S5_EqualAccountNamespace(admission.collect_v1.account.account_namespace,account));
   SWV5S5_MvpD1Record(c,"ACCOUNT-32",admitted && projected &&
      admission.collect_v2.account.projection_digest==projection.projection_digest &&
      SWV5S5_EqualAccountNamespace(admission.collect_v2.account.account_namespace,account));
   const bool invalidated=admitted && SWV5S5_TestAccountUnauthorizedGeneration(positive_path,ns);
   SWV5S5_MvpD1Record(c,"ACCOUNT-33",invalidated && !d1_port.CollectAdmissionSameEvent());
   // Separate untouched physical scope for repeated observations. The candidate
   // projection itself is re-derived, not compared to a copied expected digest.
   const string fresh_path="mvp_account_authority_observation.sqlite";
   const bool observation_seed=SWV5S5_MvpD1BuildE2ESeed(fresh_path,seed,ns,seed_status);
   platform.balance_delta=7.0;
   const bool changed_observation=observation_seed && store.OpenReadOnly(fresh_path,ns) &&
      producer.CaptureInitialFlat(store,seed.context,seed.current_trust.persistence_namespace,seed.current_lease,platform,observed,new_observation);
   SWV5S5_RiskAuthorizationAuthorityView before,after; before.authorization=authorization; before.current_binding=candidate;
   after=before; after.current_binding.account=new_observation.account; after.current_binding.exposure=new_observation.exposure;
   SWV5S5_MvpD1Record(c,"ACCOUNT-34",binding && captured && changed_observation &&
      SWV5S5_EqualAccountNamespace(observation.account.account_namespace,new_observation.account.account_namespace) &&
      observation.combined_digest!=new_observation.combined_digest && SWV5S5_DeriveRiskProjection(before) &&
      SWV5S5_DeriveRiskProjection(after) && before.projection_digest!=after.projection_digest);
   bool granted=true;
   SWV5S5_MvpD1Record(c,"ACCOUNT-35",invalidated && !d1_port.ClaimPhysicalNow(granted) && !granted &&
      store.OpenReadOnly(positive_path,ns) && !owner.Load(store,reloaded,readback,found));
   SWV5S5_MvpD1NonMutatingBoundary boundary;
   SWV5S5_MvpControlledDemoAuthorityPort zero_port; SWV5S5_MvpBrokerEvidenceStore zero_evidence;
   SWV5S5_MvpControlledDemoRunner zero_runner; SWV5S5_MvpControlledDemoResult zero_result;
   SWV5S5_MvpD1MakeInvocation(fresh_path,ns,MODE_D1_BUY,invocation); platform.balance_delta=0.0;
   const bool zero_ran=observation_seed && zero_evidence.Configure(fresh_path,ns) &&
      zero_port.Configure(fresh_path,ns,seed,&platform,&zero_evidence) && zero_runner.Run(invocation,zero_port,boundary,zero_result);
   SWV5S5_MvpD1Record(c,"ACCOUNT-36",zero_ran && zero_result.claim_granted_now && boundary.calls==1 &&
      zero_result.broker_submission_calls==0 && !zero_result.synchronous_result.invocation_attempted);

   SWV5S5_MvpRiskContract coherent_risk; SWV5_RiskAuthorization checked;
   const bool coherent_allowed=coherent_read && coherent_risk.EvaluateObserved(seed.context,candidate,coherent,checked);
   SWV5S5_MvpD1Record(c,"ACCOUNT-COHERENCE-01",coherent_allowed && preparation_reads==1 &&
      candidate.margin_authority_record.current_account_margin==coherent.account.margin &&
      candidate.margin_authority_record.current_free_margin==coherent.account.free_margin &&
      candidate.basket_risk_authority_record.source_snapshot_digest==coherent.combined_digest);
   SWV5S5_MvpD1Record(c,"ACCOUNT-COHERENCE-02",coherent_allowed &&
      SWV5S5_EqualAccountNamespace(candidate.margin_authority_record.account_namespace,coherent.account.account_namespace) &&
      SWV5S5_EqualAccountNamespace(candidate.basket_risk_authority_record.account_namespace,coherent.account.account_namespace) &&
      SWV5S5_EqualAccountNamespace(checked.account_namespace,coherent.account.account_namespace));
   string a,e,d;
   SWV5S5_MvpD1Record(c,"ACCOUNT-COHERENCE-03",coherent_allowed &&
      SWV5S5_MvpObservationDigests(candidate.account,candidate.exposure,a,e,d) && d==coherent.combined_digest &&
      candidate.margin_authority_record.broker_calculation_reference==
         "MT5/OrderCalcMargin/FUSION-V5-DEMO-MVP-V1/OBS/"+d &&
      candidate.basket_risk_authority_record.source_snapshot_digest==d);
   // Explicit probe OUTSIDE the preparation event, not used by any issuer.
   platform.balance_delta=7.0; SWV5S5_MvpAccountObservation later;
   const bool second=platform.CaptureFlatAccount(seed.context.clock_time,later);
   SWV5S5_MvpD1Record(c,"ACCOUNT-COHERENCE-04",coherent_allowed && preparation_reads==1 && second &&
      later.equity!=candidate.account.equity && candidate.account.equity==coherent.account.equity &&
      candidate.margin_authority_record.current_free_margin==coherent.account.free_margin);
   SWV5S5_MvpAccountObservationEnvelope wrong=coherent; SWV5S5_SHA256("WRONG-OBSERVATION",wrong.combined_digest);
   SWV5S5_MvpD1Record(c,"ACCOUNT-COHERENCE-05",coherent_allowed &&
      !coherent_risk.EvaluateObserved(seed.context,candidate,wrong,checked) && checked.authorization_id=="");
   wrong=coherent; wrong.account.observed_at--;
   const bool resealed=SWV5S5_MvpObservationDigests(wrong.account,wrong.exposure,wrong.account_digest,wrong.exposure_digest,wrong.combined_digest);
   SWV5S5_MvpD1Record(c,"ACCOUNT-COHERENCE-06",coherent_allowed && resealed &&
      !coherent_risk.EvaluateObserved(seed.context,candidate,wrong,checked) && checked.authorization_id=="");
   SWV5S5_MvpD1Record(c,"ACCOUNT-COHERENCE-07",coherent_allowed &&
      authorization.risk_snapshot_epoch==coherent.account.account_namespace.snapshot_epoch &&
      authorization.risk_snapshot_sequence==coherent.account.account_namespace.snapshot_sequence);
   SWV5_RiskEvaluationInput changed_candidate=candidate; changed_candidate.account.equity=later.equity;
   SWV5S5_MvpD1Record(c,"ACCOUNT-COHERENCE-08",admitted && projected &&
      admission.collect_v1.account.projection_digest==admission.collect_v2.account.projection_digest &&
      !coherent_risk.EvaluateObserved(seed.context,changed_candidate,coherent,checked) &&
      SWV5S5_EqualAccountNamespace(admission.collect_v1.account.account_namespace,coherent.account.account_namespace) &&
      SWV5S5_EqualAccountNamespace(admission.collect_v2.account.account_namespace,coherent.account.account_namespace));
   SWV5S5_MvpD1Record(c,"ACCOUNT-COHERENCE-09",zero_ran && boundary.calls==1 &&
      zero_result.broker_submission_calls==0 && !zero_result.synchronous_result.invocation_attempted);
   // Field-wise input mutations, NOT production-code mutation controls. Each
   // starts at the proven allowed candidate and must reject at the observation
   // gate without issuing an authorization. No copied expected digest is used.
   for(int field=0;field<16;field++)
   {
      SWV5_RiskEvaluationInput mixed=candidate;
      switch(field)
      {
         case 0: mixed.account.balance+=1.0; break;
         case 1: mixed.account.equity+=1.0; break;
         case 2: mixed.account.margin+=1.0; break;
         case 3: mixed.account.free_margin+=1.0; break;
         case 4: mixed.account.daily_realized_net+=1.0; break;
         case 5: mixed.account.daily_unrealized_net+=1.0; break;
         case 6: mixed.account.trading_day_start--; break;
         case 7: mixed.exposure.symbol_long_volume+=0.01; break;
         case 8: mixed.exposure.symbol_short_volume+=0.01; break;
         case 9: mixed.exposure.symbol_net_volume+=0.01; break;
         case 10: mixed.exposure.aggregate_volume+=0.01; break;
         case 11: mixed.exposure.aggregate_notional+=1.0; break;
         case 12: mixed.exposure.live_basket_count++; break;
         case 13: mixed.account.account_namespace.snapshot_sequence++; break;
         case 14: mixed.account.observed_at--; break;
         case 15: mixed.exposure.observed_at--; break;
      }
      SWV5S5_MvpD1Record(c,"ACCOUNT-COHERENCE-FIELD-"+IntegerToString(field+1),coherent_allowed &&
         !coherent_risk.EvaluateObserved(seed.context,mixed,coherent,checked) &&
         checked.authorization_id=="" && checked.disposition==SWV5_RISK_BLOCK_REQUEST);
   }
}
#endif // SW_V5_S5_MVP_ACCOUNT_AUTHORITY_ASSERTIONS_MQH
