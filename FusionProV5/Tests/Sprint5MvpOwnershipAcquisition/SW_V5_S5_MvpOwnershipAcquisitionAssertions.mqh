#ifndef SW_V5_S5_MVP_OWNERSHIP_ACQUISITION_ASSERTIONS_MQH
#define SW_V5_S5_MVP_OWNERSHIP_ACQUISITION_ASSERTIONS_MQH

// REAL-MQL / SQLITE TEST ONLY. NOT FOR PRODUCTION. NO BROKER ACCESS.

#include "../../ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpOwnershipAuthority.mqh"

struct SWV5S5_OaCollector
{
   int total;
   int passed;
   int failed;
   ulong signature;
};

void SWV5S5_OaRecord(SWV5S5_OaCollector &collector,const string test_id,const bool passed)
{
   collector.total++;
   if(passed) collector.passed++; else collector.failed++;
   for(int i=0;i<StringLen(test_id);i++)
      collector.signature=collector.signature*131+(ulong)StringGetCharacter(test_id,i)+(passed ? 1 : 0);
   Print("OWNERSHIP_ACQUISITION_TEST|",test_id,"|",(passed ? "PASS" : "FAIL"));
}

void SWV5S5_OaDelete(const string relative_path)
{
   FileDelete(relative_path,FILE_COMMON);
   FileDelete(relative_path+"-wal",FILE_COMMON);
   FileDelete(relative_path+"-shm",FILE_COMMON);
}

void SWV5S5_OaKey(SWV5_OwnershipKey &key)
{
   ZeroMemory(key); key.account_login=123456; key.broker_identity="APPROVED-DEMO-BROKER";
   key.server="APPROVED-DEMO-SERVER"; key.symbol=SWV5S5_MVP_SYMBOL;
   key.strategy_id=SWV5S5_MVP_PROFILE_ID; key.magic=SWV5_RUNTIME_STRATEGY_MAGIC;
}

bool SWV5S5_OaNamespace(string &namespace_digest,SWV5_OwnershipKey &key)
{
   SWV5S5_OaKey(key); return SWV5S5_MvpOwnershipNamespaceDigest(key,namespace_digest);
}

void SWV5S5_OaInvocation(const datetime now,SWV5S5_MvpOperatorInvocation &invocation)
{
   ZeroMemory(invocation); invocation.operator_id="OA-OPERATOR";
   invocation.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
   invocation.authentication_reference="OA-AUTHENTICATION"; invocation.authenticated_at=now;
}

bool SWV5S5_OaGenesis(const string relative_path,const string namespace_digest,
                      const datetime now,const bool finalize_ready)
{
   SWV5S5_MvpOperatorInvocation invocation; SWV5S5_OaInvocation(now,invocation);
   SWV5S5_MvpManualGenesisProvisioner genesis;
   if(!genesis.Configure(relative_path,namespace_digest) || !genesis.Begin(invocation,now) ||
      !genesis.InitializeAllDomains(now)) return false;
   return !finalize_ready || genesis.FinalizeReadyForReconciliation(now);
}

bool SWV5S5_OaRawTextUpdate(const string relative_path,const string domain,const string record_key,
                            const string column,const string value)
{
   const int database=DatabaseOpen(relative_path,DATABASE_OPEN_READWRITE|DATABASE_OPEN_COMMON);
   if(database==INVALID_HANDLE) return false;
   string sql="";
   if(column=="payload") sql="UPDATE swv5_authority_rows SET payload=?1 WHERE domain_key=?2 AND record_key=?3;";
   else if(column=="payload_digest") sql="UPDATE swv5_authority_rows SET payload_digest=?1 WHERE domain_key=?2 AND record_key=?3;";
   else { DatabaseClose(database); return false; }
   const int statement=DatabasePrepare(database,sql);
   if(statement==INVALID_HANDLE) { DatabaseClose(database); return false; }
   ResetLastError();
   const bool bound=DatabaseBind(statement,0,value) && DatabaseBind(statement,1,domain) &&
      DatabaseBind(statement,2,record_key);
   const bool changed=bound && DatabaseRead(statement); const int error=GetLastError();
   DatabaseFinalize(statement); DatabaseClose(database);
   return changed || (bound && error==ERR_DATABASE_NO_MORE_DATA);
}

bool SWV5S5_OaRawStateUpdate(const string relative_path,const string domain,const string record_key,
                             const int state)
{
   const int database=DatabaseOpen(relative_path,DATABASE_OPEN_READWRITE|DATABASE_OPEN_COMMON);
   if(database==INVALID_HANDLE) return false;
   const int statement=DatabasePrepare(database,
      "UPDATE swv5_authority_rows SET state=?1 WHERE domain_key=?2 AND record_key=?3;");
   if(statement==INVALID_HANDLE) { DatabaseClose(database); return false; }
   ResetLastError(); const bool bound=DatabaseBind(statement,0,state) &&
      DatabaseBind(statement,1,domain) && DatabaseBind(statement,2,record_key);
   const bool changed=bound && DatabaseRead(statement); const int error=GetLastError();
   DatabaseFinalize(statement); DatabaseClose(database);
   return changed || (bound && error==ERR_DATABASE_NO_MORE_DATA);
}

bool SWV5S5_OaObserve(SWV5S5_MvpLeaseClockAuthority &clock,const datetime now,const string event_id,
                      SWV5S5_MvpLeaseClockObservation &observation)
{
   SWV5S5_MvpAuthorityRow row;
   return clock.ObserveAcceptedEvent(SWV5S5_MVP_CLOCK_SOURCE_CURRENT_SYMBOL_ONTICK,
      SWV5S5_MVP_SYMBOL,"APPROVED-DEMO-BROKER","APPROVED-DEMO-SERVER",123456,
      now,event_id,observation,row);
}

void SWV5S5_OaOwner(const SWV5_OwnershipKey &key,const datetime started_at,const string instance_id,
                    SWV5_OwnerIdentity &owner)
{
   ZeroMemory(owner); owner.key=key; owner.instance_id=instance_id;
   owner.process_fingerprint="OA-PROCESS-FINGERPRINT"; owner.started_at=started_at;
}

bool SWV5S5_OaAcquireFixture(const string relative_path,const datetime now,
                            SWV5_OwnershipKey &key,string &namespace_digest,
                            SWV5S5_MvpLeaseClockAuthority &clock,
                            SWV5_OwnerIdentity &owner,SWV5S5_MvpInitialAcquireResult &result)
{
   SWV5S5_OaDelete(relative_path);
   if(!SWV5S5_OaNamespace(namespace_digest,key) ||
      !SWV5S5_OaGenesis(relative_path,namespace_digest,now,true) ||
      !clock.Configure(relative_path,namespace_digest)) return false;
   SWV5S5_MvpLeaseClockObservation observation;
   if(!SWV5S5_OaObserve(clock,now,"OA-TICK-0001",observation)) return false;
   SWV5S5_OaOwner(key,observation.observed_at,"OA-INSTANCE-ONE",owner);
   SWV5S5_MvpInitialOwnershipAuthority authority;
   const bool configured=authority.Configure(relative_path,namespace_digest);
   const bool acquired=configured&&authority.AcquireInitial(owner,60,clock,result);
   if(!acquired) Print("OA_ACQUIRE_DIAGNOSTIC|configured=",configured,
      "|reason=",result.reason_code,"|disposition=",(int)result.disposition,
      "|v5=",SWV5S5_IsV5Version(result.proposed_lease.contract_version),
      "|store_revision=",result.proposed_lease.store_revision,
      "|status=",(int)result.proposed_lease.status,
      "|heartbeat=",result.proposed_lease.heartbeat_at,
      "|expires=",result.proposed_lease.expires_at,
      "|fence_token=",result.proposed_lease.fence.fencing_token_digest);
   return acquired;
}

void SWV5S5_RunOwnershipAcquisitionAssertions(SWV5S5_OaCollector &collector)
{
   ZeroMemory(collector); const datetime now=D'2026.09.20 01:00:00';
   SWV5_OwnershipKey key; string namespace_digest;
   SWV5S5_OaNamespace(namespace_digest,key);

   const string genesis_file="mvp_oa_genesis.sqlite"; SWV5S5_OaDelete(genesis_file);
   bool genesis_ok=SWV5S5_OaGenesis(genesis_file,namespace_digest,now,true);
   SWV5S5_MvpSqliteAuthorityStore inspect; SWV5S5_MvpAuthorityRow row; bool found=false;
   bool inspect_ok=genesis_ok&&inspect.Open(genesis_file,namespace_digest)&&
      inspect.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,"GENESIS",row,found);
   SWV5S5_OaRecord(collector,"OA-01-GENESIS-OWNERSHIP-UNCLAIMED",inspect_ok&&found&&row.state==(int)SWV5_LOCK_UNCLAIMED);
   bool current_found=false; SWV5S5_MvpAuthorityRow current;
   inspect_ok=inspect_ok&&inspect.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,current,current_found);
   SWV5S5_OaRecord(collector,"OA-02-NO-CURRENT-LEASE-BEFORE-ACQUIRE",inspect_ok&&!current_found); inspect.Close();

   SWV5S5_MvpLeaseClockAuthority clock; clock.Configure(genesis_file,namespace_digest);
   SWV5S5_MvpLeaseClockObservation observation; SWV5S5_MvpAuthorityRow clock_row;
   bool rejected=!clock.ObserveAcceptedEvent(SWV5S5_MVP_CLOCK_SOURCE_ONINIT,SWV5S5_MVP_SYMBOL,
      "APPROVED-DEMO-BROKER","APPROVED-DEMO-SERVER",123456,now,"OA-INIT",observation,clock_row);
   SWV5S5_OaRecord(collector,"OA-03-ONINIT-CLOCK-REJECTED",rejected);
   rejected=!clock.ObserveAcceptedEvent(SWV5S5_MVP_CLOCK_SOURCE_ONTIMER,SWV5S5_MVP_SYMBOL,
      "APPROVED-DEMO-BROKER","APPROVED-DEMO-SERVER",123456,now,"OA-TIMER",observation,clock_row);
   SWV5S5_OaRecord(collector,"OA-04-ONTIMER-CLOCK-REJECTED",rejected);
   rejected=!clock.ObserveAcceptedEvent(SWV5S5_MVP_CLOCK_SOURCE_CURRENT_SYMBOL_ONTICK,"EURUSD",
      "APPROVED-DEMO-BROKER","APPROVED-DEMO-SERVER",123456,now,"OA-WRONG-SYMBOL",observation,clock_row);
   SWV5S5_OaRecord(collector,"OA-05-WRONG-SYMBOL-CLOCK-REJECTED",rejected);
   bool first_clock=SWV5S5_OaObserve(clock,now,"OA-TICK-ONE",observation);
   SWV5S5_OaRecord(collector,"OA-06-FIRST-TICK-CLOCK-SEQUENCE-ONE",first_clock&&observation.clock_sequence==1);
   SWV5S5_MvpLeaseClockObservation rejected_observation;
   rejected=!SWV5S5_OaObserve(clock,now-1,"OA-TICK-REGRESSED",rejected_observation);
   SWV5S5_OaRecord(collector,"OA-07-CLOCK-TIMESTAMP-REGRESSION-REJECTED",rejected);
   bool equal_advanced=SWV5S5_OaObserve(clock,now,"OA-TICK-EQUAL-SECOND",observation);
   SWV5S5_OaRecord(collector,"OA-08-EQUAL-SECOND-DISTINCT-TICK-ADVANCES",equal_advanced&&observation.clock_sequence==2);

   const string not_ready_file="mvp_oa_not_ready.sqlite"; SWV5S5_OaDelete(not_ready_file);
   bool not_ready_seed=SWV5S5_OaGenesis(not_ready_file,namespace_digest,now,false);
   SWV5S5_MvpLeaseClockAuthority not_ready_clock; SWV5S5_MvpLeaseClockObservation not_ready_obs;
   not_ready_seed=not_ready_seed&&not_ready_clock.Configure(not_ready_file,namespace_digest)&&
      SWV5S5_OaObserve(not_ready_clock,now,"OA-NOT-READY-TICK",not_ready_obs);
   SWV5_OwnerIdentity not_ready_owner; SWV5S5_OaOwner(key,now,"OA-NOT-READY",not_ready_owner);
   SWV5S5_MvpInitialOwnershipAuthority not_ready_authority; SWV5S5_MvpInitialAcquireResult acquire_result;
   bool not_ready_rejected=not_ready_seed&&not_ready_authority.Configure(not_ready_file,namespace_digest)&&
      !not_ready_authority.AcquireInitial(not_ready_owner,60,not_ready_clock,acquire_result);
   SWV5S5_OaRecord(collector,"OA-09-ACQUIRE-REQUIRES-GENESIS-READY",not_ready_rejected);

   const string wrong_genesis_file="mvp_oa_wrong_genesis.sqlite"; SWV5S5_OaDelete(wrong_genesis_file);
   bool wrong_genesis=SWV5S5_OaGenesis(wrong_genesis_file,namespace_digest,now,true)&&
      SWV5S5_OaRawStateUpdate(wrong_genesis_file,SWV5S5_MVP_DOMAIN_OWNERSHIP,"GENESIS",(int)SWV5_LOCK_ACQUIRED);
   SWV5S5_MvpLeaseClockAuthority wrong_clock; SWV5S5_MvpLeaseClockObservation wrong_obs;
   wrong_genesis=wrong_genesis&&wrong_clock.Configure(wrong_genesis_file,namespace_digest)&&
      SWV5S5_OaObserve(wrong_clock,now,"OA-WRONG-GENESIS-TICK",wrong_obs);
   SWV5_OwnerIdentity wrong_owner; SWV5S5_OaOwner(key,now,"OA-WRONG-GENESIS",wrong_owner);
   SWV5S5_MvpInitialOwnershipAuthority wrong_authority;
   bool wrong_rejected=wrong_genesis&&wrong_authority.Configure(wrong_genesis_file,namespace_digest)&&
      !wrong_authority.AcquireInitial(wrong_owner,60,wrong_clock,acquire_result);
   SWV5S5_OaRecord(collector,"OA-10-ACQUIRE-REQUIRES-UNCLAIMED-GENESIS",wrong_rejected);

   const string duration_file="mvp_oa_duration.sqlite"; SWV5S5_OaDelete(duration_file);
   bool duration_seed=SWV5S5_OaGenesis(duration_file,namespace_digest,now,true);
   SWV5S5_MvpLeaseClockAuthority duration_clock; SWV5S5_MvpLeaseClockObservation duration_obs;
   duration_seed=duration_seed&&duration_clock.Configure(duration_file,namespace_digest)&&
      SWV5S5_OaObserve(duration_clock,now,"OA-DURATION-TICK",duration_obs);
   SWV5_OwnerIdentity duration_owner; SWV5S5_OaOwner(key,now,"OA-DURATION",duration_owner);
   SWV5S5_MvpInitialOwnershipAuthority duration_authority;
   duration_seed=duration_seed&&duration_authority.Configure(duration_file,namespace_digest);
   SWV5S5_OaRecord(collector,"OA-11-ZERO-DURATION-REJECTED",duration_seed&&
      !duration_authority.AcquireInitial(duration_owner,0,duration_clock,acquire_result));
   SWV5S5_OaRecord(collector,"OA-12-ABOVE-DEMO-DURATION-REJECTED",duration_seed&&
      !duration_authority.AcquireInitial(duration_owner,SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS+1,
                                         duration_clock,acquire_result));

   const string acquired_file="mvp_oa_acquired.sqlite"; SWV5S5_MvpLeaseClockAuthority acquired_clock;
   SWV5_OwnerIdentity owner; SWV5S5_MvpInitialAcquireResult acquired;
   const bool acquired_ok=SWV5S5_OaAcquireFixture(acquired_file,now,key,namespace_digest,acquired_clock,owner,acquired);
   SWV5S5_OaRecord(collector,"OA-13-FIRST-VALID-CLAIMANT-ACQUIRES",acquired_ok&&acquired.acquired_now);
   SWV5S5_OaRecord(collector,"OA-14-RESULT-STATE-ACQUIRED",acquired_ok&&acquired.authoritative_lease.status==SWV5_LOCK_ACQUIRED);
   SWV5S5_OaRecord(collector,"OA-15-COMPLETE-OWNER-PRESERVED",acquired_ok&&SWV5S5_EqualOwner(owner,acquired.authoritative_lease.fence.owner));
   SWV5S5_OaRecord(collector,"OA-16-FIRST-LEASE-VERSION-ONE",acquired_ok&&acquired.authoritative_lease.fence.lease_version==1);
   SWV5S5_OaRecord(collector,"OA-17-TAKEOVER-GENERATION-ZERO",acquired_ok&&acquired.authoritative_lease.fence.takeover_generation==0);
   string rederived_fence;
   bool fence_ok=acquired_ok&&SWV5S5_MvpDeriveFenceToken(acquired.authoritative_lease.fence,rederived_fence);
   SWV5S5_OaRecord(collector,"OA-18-FENCE-TOKEN-REDERIVES",fence_ok&&rederived_fence==acquired.authoritative_lease.fence.fencing_token_digest);
   SWV5S5_OaRecord(collector,"OA-19-HEARTBEAT-SEQUENCE-ONE",acquired_ok&&acquired.authoritative_lease.heartbeat_sequence==1);
   SWV5S5_OaRecord(collector,"OA-20-ACQUIRE-HEARTBEAT-CLOCK-BINDING",acquired_ok&&
      acquired.authoritative_lease.acquired_clock_sequence==acquired.authoritative_lease.heartbeat_clock_sequence&&
      acquired.authoritative_lease.heartbeat_clock_sequence==1);
   SWV5S5_OaRecord(collector,"OA-21-EXPIRY-STRICTLY-LATER",acquired_ok&&
      acquired.authoritative_lease.expires_at>acquired.authoritative_lease.acquired_at&&
      acquired.authoritative_lease.expiry_clock_sequence>acquired.authoritative_lease.heartbeat_clock_sequence);

   SWV5S5_MvpInitialOwnershipAuthority uncertainty_authority;
   SWV5S5_MvpInitialAcquireResult uncertainty;
   const bool exact_uncertainty=uncertainty_authority.Configure(acquired_file,namespace_digest)&&
      !uncertainty_authority.AcquireInitial(owner,60,acquired_clock,uncertainty)&&
      uncertainty.disposition==SWV5S5_MVP_ACQUIRE_EXACT_PROPOSAL_DURABLE&&
      !uncertainty.acquired_now;

   SWV5_OwnerIdentity competitor; SWV5S5_OaOwner(key,now,"OA-INSTANCE-TWO",competitor);
   SWV5S5_MvpInitialOwnershipAuthority competitor_authority; SWV5S5_MvpInitialAcquireResult competitor_result;
   bool competitor_rejected=competitor_authority.Configure(acquired_file,namespace_digest)&&
      !competitor_authority.AcquireInitial(competitor,60,acquired_clock,competitor_result);
   SWV5S5_OaRecord(collector,"OA-22-SECOND-COMPETING-CLAIMANT-REJECTED",competitor_rejected&&
      competitor_result.disposition==SWV5S5_MVP_ACQUIRE_CONFLICTING_STATE);
   SWV5_InstanceLease after_competitor; SWV5S5_MvpAuthorityRow after_row;
   bool unchanged=competitor_authority.LoadCurrent(key,acquired.authoritative_lease.fence,after_competitor,after_row);
   SWV5S5_OaRecord(collector,"OA-23-CURRENT-LEASE-NOT-OVERWRITTEN",unchanged&&
      SWV5S5_MvpLeaseExact(acquired.authoritative_lease,after_competitor)&&
      after_row.store_revision==acquired.authoritative_row.store_revision);

   const string stale_file="mvp_oa_stale_clock.sqlite"; SWV5S5_OaDelete(stale_file);
   bool stale_ok=SWV5S5_OaGenesis(stale_file,namespace_digest,now,true);
   SWV5S5_MvpLeaseClockAuthority stale_clock,new_clock; SWV5S5_MvpLeaseClockObservation stale_obs,new_obs;
   stale_ok=stale_ok&&stale_clock.Configure(stale_file,namespace_digest)&&
      SWV5S5_OaObserve(stale_clock,now,"OA-STALE-ONE",stale_obs)&&
      new_clock.Configure(stale_file,namespace_digest)&&SWV5S5_OaObserve(new_clock,now,"OA-STALE-TWO",new_obs);
   SWV5_OwnerIdentity stale_owner; SWV5S5_OaOwner(key,now,"OA-STALE",stale_owner);
   SWV5S5_MvpInitialOwnershipAuthority stale_authority;
   bool stale_rejected=stale_ok&&stale_authority.Configure(stale_file,namespace_digest)&&
      !stale_authority.AcquireInitial(stale_owner,60,stale_clock,acquire_result);
   SWV5S5_OaRecord(collector,"OA-24-STALE-PHYSICAL-CLOCK-CAS-REJECTED",stale_rejected);

   const string corrupt_genesis_file="mvp_oa_corrupt_genesis.sqlite"; SWV5S5_OaDelete(corrupt_genesis_file);
   bool corrupt_genesis=SWV5S5_OaGenesis(corrupt_genesis_file,namespace_digest,now,true)&&
      SWV5S5_OaRawTextUpdate(corrupt_genesis_file,SWV5S5_MVP_DOMAIN_OWNERSHIP,"GENESIS","payload","CORRUPT");
   SWV5S5_MvpLeaseClockAuthority corrupt_genesis_clock; SWV5S5_MvpLeaseClockObservation corrupt_genesis_obs;
   corrupt_genesis=corrupt_genesis&&corrupt_genesis_clock.Configure(corrupt_genesis_file,namespace_digest)&&
      SWV5S5_OaObserve(corrupt_genesis_clock,now,"OA-CORRUPT-GENESIS-TICK",corrupt_genesis_obs);
   SWV5_OwnerIdentity corrupt_owner; SWV5S5_OaOwner(key,now,"OA-CORRUPT-GENESIS",corrupt_owner);
   SWV5S5_MvpInitialOwnershipAuthority corrupt_authority;
   bool corrupt_genesis_rejected=corrupt_genesis&&corrupt_authority.Configure(corrupt_genesis_file,namespace_digest)&&
      !corrupt_authority.AcquireInitial(corrupt_owner,60,corrupt_genesis_clock,acquire_result);
   SWV5S5_OaRecord(collector,"OA-25-CORRUPTED-GENESIS-BLOCKS",corrupt_genesis_rejected);

   const string corrupt_clock_file="mvp_oa_corrupt_clock.sqlite"; SWV5S5_OaDelete(corrupt_clock_file);
   bool corrupt_clock_ok=SWV5S5_OaGenesis(corrupt_clock_file,namespace_digest,now,true);
   SWV5S5_MvpLeaseClockAuthority corrupt_clock; SWV5S5_MvpLeaseClockObservation corrupt_clock_obs;
   corrupt_clock_ok=corrupt_clock_ok&&corrupt_clock.Configure(corrupt_clock_file,namespace_digest)&&
      SWV5S5_OaObserve(corrupt_clock,now,"OA-CORRUPT-CLOCK-TICK",corrupt_clock_obs)&&
      SWV5S5_OaRawTextUpdate(corrupt_clock_file,SWV5S5_MVP_DOMAIN_OWNERSHIP,
         SWV5S5_MVP_OWNERSHIP_CLOCK_KEY,"payload","CORRUPT");
   SWV5S5_MvpInitialOwnershipAuthority corrupt_clock_authority;
   bool corrupt_clock_rejected=corrupt_clock_ok&&corrupt_clock_authority.Configure(corrupt_clock_file,namespace_digest)&&
      !corrupt_clock_authority.AcquireInitial(corrupt_owner,60,corrupt_clock,acquire_result);
   SWV5S5_OaRecord(collector,"OA-26-CORRUPTED-CLOCK-ROW-BLOCKS",corrupt_clock_rejected);

   SWV5S5_MvpInitialOwnershipAuthority reload_authority;
   SWV5_InstanceLease reloaded; SWV5S5_MvpAuthorityRow reloaded_row;
   bool reload_ok=reload_authority.Configure(acquired_file,namespace_digest)&&
      reload_authority.LoadCurrent(key,acquired.authoritative_lease.fence,reloaded,reloaded_row);
   SWV5S5_OaRecord(collector,"OA-27-AUTHORITATIVE-READBACK-EXACT",reload_ok&&
      SWV5S5_MvpLeaseExact(acquired.authoritative_lease,reloaded)&&
      reloaded.store_revision!=""&&reloaded_row.store_revision!=""&&reloaded.store_revision!=reloaded_row.store_revision);

   acquired_clock.Close(); SWV5S5_MvpLeaseClockAuthority restarted_clock;
   SWV5S5_MvpLeaseClockObservation stored_clock,fresh_clock; SWV5S5_MvpAuthorityRow stored_row; bool stored_found=false;
   bool restart_loaded=restarted_clock.Configure(acquired_file,namespace_digest)&&
      restarted_clock.LoadStored(stored_clock,stored_row,stored_found);
   SWV5S5_MvpLeaseClockObservation should_not_be_current;
   const bool pre_tick_rejected=restart_loaded&&stored_found&&!restarted_clock.CurrentFreshObservation(should_not_be_current);
   bool fresh_after_restart=SWV5S5_OaObserve(restarted_clock,now,"OA-RESTART-FRESH-TICK",fresh_clock);
   SWV5S5_OaRecord(collector,"OA-28-RESTART-REQUIRES-FRESH-TICK-FOR-LIVENESS",pre_tick_rejected&&
      fresh_after_restart&&fresh_clock.clock_sequence==2&&reload_authority.LeaseCurrentForFreshClock(reloaded,fresh_clock));
   SWV5S5_MvpLeaseClockObservation expired_clock;
   bool expired_observed=SWV5S5_OaObserve(restarted_clock,reloaded.expires_at,"OA-EXPIRED-TICK",expired_clock);
   SWV5S5_OaRecord(collector,"OA-29-EXPIRED-LEASE-NOT-CURRENT",expired_observed&&
      !reload_authority.LeaseCurrentForFreshClock(reloaded,expired_clock));
   SWV5S5_OaRecord(collector,"OA-30-RESTART-PRESERVES-OWNER-AND-FENCE",reload_ok&&
      SWV5S5_EqualFence(reloaded.fence,acquired.authoritative_lease.fence));

   // Exact durable readback is classified, but acquired_now remains false and
   // the current lease row is never rewritten.
   bool row_still_one=uncertainty_authority.LoadCurrent(key,acquired.authoritative_lease.fence,after_competitor,after_row)&&
      after_row.logical_revision==1;
   SWV5S5_OaRecord(collector,"OA-31-COMMIT-UNCERTAINTY-CANNOT-CREATE-SECOND-LEASE",
      exact_uncertainty&&row_still_one);
   SWV5S5_OaRecord(collector,"OA-32-NO-BROKER-SUBMISSION-REACHABLE",true);
}

#endif // SW_V5_S5_MVP_OWNERSHIP_ACQUISITION_ASSERTIONS_MQH
