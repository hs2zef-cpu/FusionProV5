#ifndef SW_V5_S5_MVP_CONTINUATION_ASSERTIONS_MQH
#define SW_V5_S5_MVP_CONTINUATION_ASSERTIONS_MQH
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER MUTATION.
// Real SQLite COPY, actual native tester observations and production authority functions.
class SWV5S5_TestContinuationBroker : public ISWV5S5MvpBootstrapBrokerObserver
{
public:
   int fault,calls;
   SWV5S5_TestContinuationBroker(){fault=0;calls=0;}
   virtual bool Capture(const string symbol,SWV5S5_MvpBootstrapBrokerObservation &o)
   {
      SWV5S5_MvpMt5BootstrapBrokerObserver native;
      const bool captured=native.Capture(symbol,o);
      Print("CONTINUATION_NATIVE_BROKER_CAPTURE|success=",captured,"|positions=",o.total_positions,
         "|orders=",o.total_active_orders,"|exposure=",o.total_exposure_volume,"|observed_at=",(long)o.observed_at,
         "|positions_query=",o.positions_query_succeeded,"|orders_query=",o.active_orders_query_succeeded,
         "|complete=",o.enumeration_complete,"|row_failures=",o.row_failures,"|fixture_fault=",fault);
      if(!captured) return false; calls++;
      if(fault==1) {o.total_positions=1;o.enumeration_complete=false;}
      if(fault==2) {o.total_active_orders=1;o.enumeration_complete=false;}
      if(fault==3) o.enumeration_complete=false;
      if(fault==4) o.row_failures=1;
      if(fault==5 && calls==2) {o.total_positions=1;o.enumeration_complete=false;}
      if(fault==6)o.total_exposure_volume=0.01;
      if(fault==7)o.observed_at=0; // explicit stale observation negative
      if(fault==8)o.profile.symbol="OTHER";
      if(fault==9)o.profile.server+="-WRONG";
      if(fault==10)o.profile.broker_identity+="-WRONG";
      if(fault==11)o.profile.account_login++;
      if(fault==12)o.observed_at=TimeCurrent()+3600;
      return SWV5S5_MvpBootstrapBrokerDigest(o,o.snapshot_digest);
   }
};
// TEST ONLY deterministic PERIODIC expiry context, not native-time evidence.
// Used only on a fresh TEST_ONLY clone. No execution boundary is reachable.
class SWV5S5_TestContinuationPeriodicPlatform : public SWV5S5_MvpMt5ReadOnlyPlatform
{
public:
   datetime evaluation_time;
   virtual bool CaptureProfile(const string symbol,SWV5S5_MvpRuntimeProfileObservation &profile,datetime &observed_at)
   {
      if(!SWV5S5_MvpMt5ReadOnlyPlatform::CaptureProfile(symbol,profile,observed_at))return false;
      observed_at=evaluation_time;return true;
   }
};
class SWV5S5_TestContinuationSuite
{
private:
   bool m_started,m_finished;
   int m_passed,m_failed;
   string m_ns,m_main;
   string m_copy,m_run_prefix;
   datetime m_t0;
   string m_clock_partial_path;
   datetime m_clock_partial_time;
   bool m_clock_partial_ready;
   // TEST ONLY multi-tick scheduler, not retry. Each prepared invocation is
   // finalized once on a later native OnTick using its original in-memory A.
   SWV5S5_MvpAttendedContinuation *m_job_core[32];
   SWV5S5_MvpContinuationInput m_job_input[32];
   SWV5S5_MvpOperatorInvocation m_job_op[32];
   SWV5S5_TestContinuationBroker m_job_broker[32];
   string m_job_kind[32],m_job_stage[32],m_job_hook[32];
   bool m_job_active[32];int m_job_tick[32],m_job_count,m_last_job,m_tick_id;
   bool m_ready;SWV5S5_MvpContinuationResult m_ready_result;int m_ready_calls;
   bool m_boundary_done[4],m_boundary_pass[4];string m_boundary_basis[4];
   int m_main_completion_tick;
   // TEST ONLY beforeimages survive destruction of the A1 core, NOT an
   // authority grant. The cold A2 core cannot read these harness members.
   bool m_released_captured;
   SWV5S5_MvpAuthorityRow m_released_before,m_release_bundle_before;
   SWV5_HardKillState m_historical_released;
   SWV5_HardKillReleaseAuthorityRecord m_historical_record;
   SWV5S5_MvpContinuationFlatAuthority m_historical_flat;
   SWV5S5_MvpContinuationInput m_input;
   SWV5S5_MvpAuthorityRow m_rows[];
   uchar m_bytes[];
   void Check(const bool condition,const string id)
   {if(condition)m_passed++;else m_failed++; Print("CONTINUATION_ASSERT|",id,"|",condition ? "PASS" : "FAIL");}
   bool Clone(const string name)
   {
      string digest;
      if((!MQLInfoInteger(MQL_TESTER) && !test_live_native_copy_armed) || StringFind(name,"TEST_ONLY_MVP_CONTINUATION_")!=0 ||
         !SWV5S5_TestContinuationFileSha(m_copy,digest) || digest!="bec62e7435d29d5511a41bf85c74ae443994c5804b3a9574af90d861fe674ef6") return false;
      // Never overwrite/re-run a previous partial clone. Unique run prefix below.
      if(FileIsExist(name,FILE_COMMON) || FileIsExist(name+"-wal",FILE_COMMON) || FileIsExist(name+"-shm",FILE_COMMON)) return false;
      return FileCopy(m_copy,FILE_COMMON,name,FILE_COMMON) && SWV5S5_TestContinuationFileSha(name,digest) &&
         digest=="bec62e7435d29d5511a41bf85c74ae443994c5804b3a9574af90d861fe674ef6";
   }
   bool Open(const string path,SWV5S5_MvpSqliteAuthorityStore &s)
   {return StringFind(path,"TEST_ONLY_MVP_CONTINUATION_")==0 && s.Open(path,m_ns);}
   bool Rows(const string path,SWV5S5_MvpAuthorityRow &rows[])
   {SWV5S5_MvpSqliteAuthorityStore s; return s.OpenReadOnly(path,m_ns) && s.ReadAllRows(rows);}
   bool SameRows(const SWV5S5_MvpAuthorityRow &a[],const SWV5S5_MvpAuthorityRow &b[])
   {
      if(ArraySize(a)!=ArraySize(b))return false;
      for(int x=0;x<ArraySize(a);x++)if(a[x].domain_key!=b[x].domain_key || a[x].record_key!=b[x].record_key ||
         a[x].logical_revision!=b[x].logical_revision || a[x].store_revision!=b[x].store_revision || a[x].payload!=b[x].payload ||
         a[x].payload_digest!=b[x].payload_digest || a[x].state!=b[x].state || a[x].updated_at!=b[x].updated_at)return false;
      return true;
   }
   // TEST ONLY structural comparison, NOT a durable production resume grant.
   bool ClockOnlyPartial(const string path,const SWV5S5_MvpAuthorityRow &prior[],SWV5S5_MvpAuthorityRow &current[])
   {
      if(!Rows(path,current) || ArraySize(prior)!=ArraySize(current))return false;
      int changes=0;
      for(int x=0;x<ArraySize(prior);x++)
      {
         if(prior[x].domain_key!=current[x].domain_key || prior[x].record_key!=current[x].record_key)return false;
         if(prior[x].domain_key==SWV5S5_MVP_DOMAIN_OWNERSHIP && prior[x].record_key==SWV5S5_MVP_OWNERSHIP_CLOCK_KEY)
         {
            SWV5S5_MvpLeaseClockObservation old_clock,new_clock;
            if(!SWV5S5_MvpDecodeLeaseClockPayload(prior[x].payload,old_clock) ||
               !SWV5S5_MvpDecodeLeaseClockPayload(current[x].payload,new_clock) ||
               !SWV5S5_MvpLeaseClockObservationValid(old_clock) || !SWV5S5_MvpLeaseClockObservationValid(new_clock) ||
               old_clock.clock_id!=new_clock.clock_id || old_clock.clock_authority!=new_clock.clock_authority ||
               old_clock.broker_identity!=new_clock.broker_identity || old_clock.server!=new_clock.server ||
               old_clock.account_login!=new_clock.account_login || old_clock.source_symbol!=new_clock.source_symbol ||
               new_clock.clock_sequence<=old_clock.clock_sequence || new_clock.observed_at<old_clock.observed_at ||
               current[x].logical_revision!=new_clock.clock_sequence || current[x].updated_at!=new_clock.observed_at)return false;
            SWV5S5_MvpLeaseClockAuthority authority;SWV5S5_MvpLeaseClockObservation verified;SWV5S5_MvpAuthorityRow row;bool found=false;
            if(!authority.ConfigureReadOnly(path,m_ns) || !authority.LoadStored(verified,row,found) || !found ||
               !SWV5S5_MvpContinuationRowExact(row,current[x]))return false;
            changes++;
         }
         else if(!SWV5S5_MvpContinuationRowExact(prior[x],current[x]))return false;
      }
      return changes==1;
   }
   bool NativePreflight(const string path,SWV5S5_MvpControlledDemoResult &result)
   {
      SWV5S5_MvpControlledDemoInvocation i; SWV5S5_MvpControlledDemoDefaults(i);
      i.relative_store_path=path; i.persistence_namespace_identity=m_ns;
      i.expected_broker_identity=m_input.configured_owner.key.broker_identity;
      i.expected_server=m_input.configured_owner.key.server;i.expected_demo_account_login=m_input.configured_owner.key.account_login;
      i.source_head="d926f2e6b1aa4ea7b4b0936293d2fa47a2ce7ba8";
      i.evidence_relative_path="TEST_ONLY_MVP_CONTINUATION_PREFLIGHT.log";
      i.protective_stop_price=SymbolInfoDouble(_Symbol,SYMBOL_ASK)-3.0;
      SWV5S5_MvpAttendedLaunch host; if(!host.Init(i,1)) return false;
      host.OnCurrentSymbolTick();return host.ReadLastResult(result);
   }
   bool Execute(SWV5S5_MvpContinuationInput &i,SWV5S5_TestContinuationBroker &broker,SWV5S5_MvpContinuationResult &result)
   {
      ZeroMemory(result); // A failed prerequisite cannot reuse an old result.
      if(!i.acknowledged){ZeroMemory(result);result.stage="ACK_REQUIRED";result.reason="NO_FRESH_ACK_ZERO_MUTATION";return false;}
      SWV5S5_MvpMt5ReadOnlyPlatform platform;SWV5S5_MvpAttendedContinuation *authority=new SWV5S5_MvpAttendedContinuation;
      SWV5S5_MvpContinuationResult structural;
      if(!authority.ClassifyStoredPreState(i,platform,structural))
      {result=structural;delete authority;return false;}
      SWV5S5_MvpLeaseClockAuthority clock; SWV5S5_MvpLeaseClockObservation at; SWV5S5_MvpAuthorityRow row;
      if(!clock.Configure(i.path,m_ns) || !clock.ObserveFromCurrentSymbolOnTick(_Symbol,
         "TEST_ONLY/"+i.continuation_id+"/"+IntegerToString((long)GetMicrosecondCount()),at,row))
      {result.stage="CLOCK";result.reason="CLOCK_PUBLICATION_OR_READBACK_FAILED";delete authority;return false;}
      if(SWV5S5_TestContinuationStopStage("CLOCK"))
      {ZeroMemory(result);result.partial_continuation=true;result.stage="CLOCK";result.reason="PARTIAL_CONTINUATION/TEST_INTERRUPTION_CLOCK";delete authority;return false;}
      SWV5S5_MvpOperatorInvocation op; op.operator_id="FUSION_DEMO_ATTENDED_OPERATOR_01";
      op.authority_role=SWV5S5_MVP_OPERATOR_ROLE;op.authentication_reference="TEST_ONLY_FRESH_A";op.authenticated_at=at.observed_at;
      const bool completed=authority.Run(i,op,clock,platform,broker,result);
      if(authority.AwaitingFinalization())
      {
         if(m_job_count>=32){delete authority;result.reason="TEST_ONLY_JOB_CAPACITY";return false;}
         m_last_job=m_job_count++;m_job_core[m_last_job]=authority;m_job_input[m_last_job]=i;m_job_op[m_last_job]=op;
         m_job_broker[m_last_job].fault=broker.fault;m_job_broker[m_last_job].calls=broker.calls;
         m_job_active[m_last_job]=true;m_job_tick[m_last_job]=m_tick_id;
         m_job_kind[m_last_job]="UNCLASSIFIED";m_job_stage[m_last_job]=test_stop_stage;m_job_hook[m_last_job]=test_stop_stage;
         return false;
      }
      delete authority;return completed;
   }
   bool Waiting(const SWV5S5_MvpContinuationResult &r)
   {return r.reason=="CONTINUATION_WAIT_LATER_ACCEPTED_FINALIZATION_CLOCK";}
   // TEST ONLY: real physical RELEASED, captured after the actual interrupt.
   bool CaptureReleasedBeforeRestart(const SWV5S5_MvpContinuationInput &i)
   {
      m_released_captured=false;SWV5S5_MvpSqliteAuthorityStore store;bool found=false,flat_found=false;
      SWV5S5_MvpAuthorityRow rows[];string canonical;
      if(!store.OpenReadOnly(i.path,m_ns) || !store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",m_released_before,found) ||
         !found || m_released_before.state!=(int)SWV5_HARD_KILL_RELEASED || !store.ReadAllRows(rows))
      {Check(false,"RELEASED_A1_PHYSICAL_BEFOREIMAGE_REQUIRED");return false;}
      for(int x=0;x<ArraySize(rows);x++)if(rows[x].domain_key==SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE &&
         rows[x].updated_at==m_released_before.updated_at &&
         SWV5S5_MvpDecodeReleaseBundle(rows[x].payload,m_historical_released,m_historical_record) &&
         SWV5S5_CanonicalHardKillState("hard_kill",m_historical_released,canonical) && canonical==m_released_before.payload)
      {m_release_bundle_before=rows[x];found=true;break;}else found=false;
      for(int x=0;x<ArraySize(rows);x++)if(rows[x].domain_key==SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT &&
         SWV5S5_MvpDecodeContinuationFlat(rows[x].payload,m_historical_flat) &&
         m_historical_flat.active.latch_id==m_historical_released.latch_id){flat_found=true;break;}
      SWV5_ContractValidationContext historical;ZeroMemory(historical);
      historical.expected_version=m_historical_released.contract_version;
      historical.clock_id=m_historical_flat.clock_id;historical.clock_authority=m_historical_flat.clock_authority;
      historical.clock_sequence=m_historical_flat.clock_sequence;historical.evaluation_sequence=m_historical_flat.clock_sequence;
      historical.clock_time=m_historical_record.released_at;historical.price_tolerance=1.0e-7;historical.volume_tolerance=1.0e-7;
      m_released_captured=found && flat_found && SWV5S5_MvpContinuationRowValid(store,m_released_before) &&
         SWV5S5_MvpContinuationRowValid(store,m_release_bundle_before) &&
         SWV5S5_MvpCompleteReleaseValid(historical,m_historical_released,m_historical_record) &&
         m_historical_record.operator_identity.operator_id==m_historical_flat.op.operator_id &&
         m_historical_record.operator_identity.authority_role==m_historical_flat.op.authority_role &&
         m_historical_record.operator_identity.authentication_reference==m_historical_flat.op.authentication_reference &&
         m_historical_record.operator_identity.authenticated_at==m_historical_flat.op.authenticated_at &&
         m_historical_record.approved_at==m_historical_flat.observed_at &&
         m_historical_record.released_at==m_historical_flat.observed_at;
      Check(m_released_captured,"RELEASED_A1_HISTORICAL_BUNDLE_PHYSICALLY_VALID");
      SWV5_HardKillState wrong_codec;
      Check(m_released_captured && !SWV5S5_MvpCodecDecode_SWV5_HardKillState(m_released_before.payload,wrong_codec),
         "RELEASED_CANONICAL_ENVELOPE_IS_NOT_TYPED_CODEC");
      if(!m_released_captured)return false;
      SWV5S5_MvpLeaseClockAuthority cold_clock;SWV5S5_MvpLeaseClockObservation fresh;
      SWV5S5_MvpMt5ReadOnlyPlatform platform;SWV5S5_TestContinuationBroker broker;
      SWV5S5_MvpAuthorityRow before[],after[];SWV5S5_MvpAttendedContinuation cold;SWV5S5_MvpContinuationResult denied;
      bool cold_rejected=cold_clock.ConfigureReadOnly(i.path,m_ns) && !cold_clock.CurrentFreshObservation(fresh) && Rows(i.path,before) &&
         !cold.AwaitingFinalization() && !cold.Run(i,m_historical_flat.op,cold_clock,platform,broker,denied) &&
         denied.reason=="CONTINUATION_NEW_ATTENDED_EVENT_FRESHNESS_REQUIRED";
      Check(cold_rejected && broker.calls==0 && Rows(i.path,after) && SameRows(before,after),
         "RELEASED_RESTART_A1_NOT_RECONSTRUCTED_ZERO_MUTATION");
      Print("CONTINUATION_RELEASED_BEFOREIMAGE|revision=",m_released_before.logical_revision,
         "|store_revision=",m_released_before.store_revision,"|digest=",m_released_before.payload_digest,
         "|updated_at=",(long)m_released_before.updated_at,"|A1=",(long)m_historical_flat.op.authenticated_at,
         "|bundle_digest=",m_release_bundle_before.payload_digest);
      return cold_rejected;
   }
   bool ReleasedBeforeFinalization(const int job)
   {
      SWV5S5_MvpSqliteAuthorityStore store;SWV5S5_MvpAuthorityRow current,bundle;bool found=false;
      string a,b,digest;
      const bool exact=m_released_captured && store.OpenReadOnly(m_job_input[job].path,m_ns) &&
         store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,found) && found &&
         SWV5S5_MvpContinuationRowExact(current,m_released_before) &&
         store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE,m_release_bundle_before.record_key,bundle,found) && found &&
         SWV5S5_MvpContinuationRowExact(bundle,m_release_bundle_before);
      Check(exact,"RELEASED_AFTER_A2_AND_T2_BYTES_DIGEST_REVISION_EXACT");
      Check(SWV5S5_MvpOperatorPayload(m_job_op[job],a,digest) &&
         SWV5S5_MvpOperatorPayload(m_historical_flat.op,b,digest) && a!=b &&
         m_job_op[job].authenticated_at>=m_historical_record.released_at,
         "RELEASED_A2_DISTINCT_FRESH_INVOCATION_AFTER_A1_RELEASE");
      // Now use the ACTUAL accepted A2 (not a synthetic future invocation).
      // Reopening the clock/core must reconstruct neither A1 nor A2 freshness.
      SWV5S5_MvpLeaseClockAuthority cold_clock;SWV5S5_MvpLeaseClockObservation fresh;
      SWV5S5_MvpMt5ReadOnlyPlatform platform;SWV5S5_TestContinuationBroker broker;
      SWV5S5_MvpAuthorityRow before[],after[];
      bool cold_ready=cold_clock.ConfigureReadOnly(m_job_input[job].path,m_ns) &&
         !cold_clock.CurrentFreshObservation(fresh) && Rows(m_job_input[job].path,before);
      bool both_rejected=cold_ready;
      for(int n=0;n<2;n++)
      {
         SWV5S5_MvpAttendedContinuation cold;SWV5S5_MvpContinuationResult denied;
         SWV5S5_MvpOperatorInvocation attempt=m_historical_flat.op;if(n==1)attempt=m_job_op[job];
         const bool denied_now=cold_ready && !cold.AwaitingFinalization() &&
            !cold.Run(m_job_input[job],attempt,cold_clock,platform,broker,denied) &&
            denied.reason=="CONTINUATION_NEW_ATTENDED_EVENT_FRESHNESS_REQUIRED";
         both_rejected=denied_now && both_rejected;
      }
      Check(both_rejected && broker.calls==0 && Rows(m_job_input[job].path,after) && SameRows(before,after),
         "RELEASED_RESTART_RECONSTRUCTS_NEITHER_A1_NOR_A2_ZERO_MUTATION");
      return exact;
   }
   void ReleasedAfterFinalization(const int job,const bool ok,const SWV5S5_MvpContinuationResult &result,
      const SWV5S5_MvpLeaseClockObservation &clock)
   {
      SWV5S5_MvpSqliteAuthorityStore store;SWV5S5_MvpAuthorityRow rows[],bundle;bool found=false;
      const bool preserved=m_released_captured && store.OpenReadOnly(m_job_input[job].path,m_ns) &&
         store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE,m_release_bundle_before.record_key,bundle,found) && found &&
         SWV5S5_MvpContinuationRowExact(bundle,m_release_bundle_before);
      Check(preserved,"RELEASED_A1_COMPLETE_BUNDLE_UNREWRITTEN_AFTER_INACTIVE");
      bool history_valid=false,inactive=false;string a,b,digest,projection;
      if(store.ReadAllRows(rows))for(int x=0;x<ArraySize(rows);x++)
      {
         if(rows[x].domain_key==SWV5S5_MVP_DOMAIN_HARD_KILL && rows[x].record_key=="CURRENT")
            inactive=rows[x].state==(int)SWV5_HARD_KILL_INACTIVE && rows[x].logical_revision==m_released_before.logical_revision+1;
         if(rows[x].domain_key!=SWV5S5_MVP_DOMAIN_RELEASE_HISTORY || rows[x].updated_at!=clock.observed_at)continue;
         SWV5S5_MvpHardKillActivationProof proof;
         history_valid=SWV5S5_MvpDecodeActivation(rows[x].payload,proof) &&
            SWV5S5_MvpContinuationRowValid(store,rows[x]) && proof.release_bundle==m_release_bundle_before.payload &&
            proof.released_row.logical_revision==m_released_before.logical_revision &&
            proof.released_row.store_revision==m_released_before.store_revision &&
            proof.released_row.payload_digest==m_released_before.payload_digest &&
            SWV5S5_CanonicalHardKillState("hard_kill",m_historical_released,projection) && projection==m_released_before.payload &&
            SWV5S5_MvpOperatorPayload(proof.operator_invocation,a,digest) &&
            SWV5S5_MvpOperatorPayload(m_job_op[job],b,digest) && a==b &&
            proof.activated_at==clock.observed_at && proof.clock_sequence==clock.clock_sequence &&
            clock.observed_at>m_job_op[job].authenticated_at;
      }
      Check(ok && result.accepted && preserved && history_valid && inactive,
         "RELEASED_A1_HISTORY_A2_ACTIVATION_ONLY_REAL_LATER_T2_INACTIVE");
      Check(result.broker_submission_calls==0 && test_forbidden_transport_calls==0,
         "RELEASED_A1_A2_ZERO_SUBMISSION_AND_TRANSPORT");
   }
   // TEST ONLY: original positive assertions, after finalization of ONE A.
   void MainAssertions(const bool ok,SWV5S5_TestContinuationBroker &broker,SWV5S5_MvpContinuationResult &result)
   {
      Check(ok && result.accepted && !result.partial_continuation,"REAL_SQLITE_CONTINUATION_COMPLETE");
      Check(result.final_latch_generation==result.initial_latch_generation+2 && result.release_generation==2,"MONOTONIC_GENERATIONS");
      Check(result.broker_submission_calls==0 && broker.calls==2,"TWO_BROKER_OBSERVATIONS_ZERO_SUBMISSION");
      SWV5S5_MvpAttendedContinuation owner;SWV5S5_MvpAuthorityRow before[],after[];
      Check(Rows(m_main,before) && owner.ReadCompletedOnly(m_input,result) && result.already_complete && Rows(m_main,after) && SameRows(before,after),"COMPLETED_REPLAY_READBACK_ONLY");
   }
   void OperatorWindowAssertions()
   {
      SWV5S5_MvpOperatorInvocation op;op.operator_id="FUSION_DEMO_ATTENDED_OPERATOR_01";op.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
      op.authentication_reference="TEST_ONLY_FINITE_A";op.authenticated_at=100000;
      Check(SWV5S5_MvpOperatorInvocationValid(op,100000),"OPERATOR_WINDOW_SAME_SECOND_VALID");
      Check(SWV5S5_MvpOperatorInvocationValid(op,100001),"MC_OPERATOR_EXACT_SECOND_REVERSION_DETECTED_BY_LATER_VALIDATION");
      Check(SWV5S5_MvpOperatorInvocationValid(op,100003),"OPERATOR_WINDOW_PLUS_THREE_VALID");
      Check(SWV5S5_MvpOperatorInvocationValid(op,103599),"OPERATOR_WINDOW_LAST_SECOND_VALID");
      Check(!SWV5S5_MvpOperatorInvocationValid(op,99999),"OPERATOR_WINDOW_BEFORE_AUTH_REJECTED");
      Check(!SWV5S5_MvpOperatorInvocationValid(op,103600),"OPERATOR_WINDOW_HORIZON_REJECTED");
      Check(!SWV5S5_MvpOperatorInvocationValid(op,103601),"OPERATOR_WINDOW_BEYOND_HORIZON_REJECTED");
      op.authority_role="WRONG";Check(!SWV5S5_MvpOperatorInvocationValid(op,100001),"OPERATOR_WINDOW_WRONG_ROLE_REJECTED");
      op.authority_role=SWV5S5_MVP_OPERATOR_ROLE;op.authentication_reference="";
      Check(!SWV5S5_MvpOperatorInvocationValid(op,100001),"OPERATOR_WINDOW_MISSING_REFERENCE_REJECTED");
   }
   void FinalizationNegatives()
   {
      string kinds[]={"NEG_NO_FINAL_CLOCK","NEG_WRONG_OPERATOR","NEG_WRONG_REFERENCE","NEG_COLD_RESTART"};
      for(int n=0;n<ArraySize(kinds);n++)
      {
         SWV5S5_MvpContinuationInput i=m_input;i.path=m_run_prefix+"."+kinds[n]+".sqlite";i.continuation_id=kinds[n];
         SWV5S5_TestContinuationBroker broker;SWV5S5_MvpContinuationResult result;
         if(!Clone(i.path)){Check(false,kinds[n]+"/CLONE");continue;}
         Execute(i,broker,result);
         Check(Waiting(result),kinds[n]+"/GENUINE_PREPARED_INVOCATION");
         if(Waiting(result))m_job_kind[m_last_job]=kinds[n];
      }
   }
   void FlatTimeNegatives()
   {
      SWV5S5_MvpAuthorityRow rows[];SWV5S5_MvpContinuationFlatAuthority valid;bool found=false;
      if(Rows(m_main,rows))for(int n=0;n<ArraySize(rows);n++)if(rows[n].domain_key==SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT &&
         SWV5S5_MvpDecodeContinuationFlat(rows[n].payload,valid)){found=true;break;}
      SWV5_HardKillReleaseEvidence evidence;SWV5_HardKillReleaseAuthorityRecord authority;
      Check(found && SWV5S5_MvpIssueContinuationRelease(valid,evidence,authority),"FLAT_REAL_TIME_POSITIVE_CONTROL");if(!found)return;
      Check(valid.op.authenticated_at<valid.observed_at && valid.broker.observed_at>=valid.op.authenticated_at &&
         valid.broker.observed_at<=valid.observed_at && valid.persistence.observed_at<=valid.observed_at &&
         valid.exposure.observed_at==valid.broker.observed_at,"FLAT_REAL_T0_T1_T2_CHAIN");
      for(int fault=0;fault<3;fault++)
      {
         SWV5S5_MvpContinuationFlatAuthority bad=valid;SWV5S5_MvpBootstrapBrokerObservation observed;string digest;
         if(!SWV5S5_MvpContinuationDecodeBroker(bad.broker_observation_payload,observed)){Check(false,"FLAT_TIME_NEGATIVE_DECODE");continue;}
         if(fault==0)observed.observed_at=bad.op.authenticated_at-1;
         if(fault==1)observed.observed_at=bad.observed_at+1;
         if(!SWV5S5_MvpBootstrapBrokerDigest(observed,observed.snapshot_digest) ||
            !SWV5S5_MvpContinuationBrokerPayload(observed,bad.broker_observation_payload)){Check(false,"FLAT_TIME_NEGATIVE_ENCODING");continue;}
         bad.broker.observed_at=observed.observed_at;bad.exposure.observed_at=observed.observed_at;
         bad.broker.state_digest=observed.snapshot_digest;
         if(fault==2)bad.persistence.observed_at=bad.observed_at+1;
         Check(SWV5S5_MvpContinuationFlatDigest(bad,bad.authority_digest) &&
            !SWV5S5_MvpIssueContinuationRelease(bad,evidence,authority),fault==0 ? "OBSERVATION_BEFORE_A_REJECTED" :
            (fault==1 ? "OBSERVATION_AFTER_FINAL_CLOCK_REJECTED" : "PERSISTENCE_AFTER_FINAL_CLOCK_REJECTED"));
      }
   }
   void Negative(const int fault,const string id)
   {
      SWV5S5_MvpContinuationInput i=m_input;i.path=m_run_prefix+".NEG_"+IntegerToString(fault)+".sqlite";i.continuation_id=id;
      if(!Clone(i.path)){Check(false,id+"/CLONE");return;}
      if(fault==1)i.configured_owner.instance_id+="-WRONG";
      if(fault==2)i.configured_owner.process_fingerprint+="-WRONG";
      if(fault==3)i.configured_owner.started_at++;
      if(fault==4)i.namespace_digest="FOREIGN_NAMESPACE";
      if(fault==5)i.trust_anchor_id+="-WRONG";
      if(fault==6)i.acknowledged=false;
      SWV5S5_TestContinuationBroker broker;
      if(fault>=7 && fault<=10)broker.fault=fault-6;
      if(fault==11)broker.fault=5;
      if(fault>=12)broker.fault=fault-6;
      SWV5S5_MvpContinuationResult result;const bool rejected=!Execute(i,broker,result);
      Check(rejected && !Waiting(result),id); // waiting is NOT a negative rejection
      if(fault==11)Check(result.partial_continuation && result.stage=="AUTHORITATIVE_FLAT_OBSERVATION","PARTIAL_NOT_HIDDEN_AFTER_ACTIVE");
   }
   void Resume(const string stage)
   {
      const bool already_prepared=m_ready;m_ready=false;
      SWV5S5_MvpContinuationInput i=m_input;i.path=m_run_prefix+".RESUME_"+stage+".sqlite";i.continuation_id="RESUME-"+stage;
      if(!already_prepared && !Clone(i.path)){Check(false,stage+"/CLONE");return;}
      SWV5S5_MvpAuthorityRow initial[],partial[];
      if(!Rows(i.path,initial)){Check(false,stage+"/INITIAL_ROWS");return;}
      test_stop_stage=stage;if(!already_prepared)test_fired_stop_stage="";SWV5S5_TestContinuationBroker broker;SWV5S5_MvpContinuationResult result;
      bool first_ok=false;
      if(already_prepared){result=m_ready_result;broker.calls=m_ready_calls;}
      else first_ok=Execute(i,broker,result);
      if(Waiting(result)){m_job_kind[m_last_job]="RESUME_FIRST";test_stop_stage="";return;}
      const bool interrupted=!first_ok && result.partial_continuation &&
         result.reason=="PARTIAL_CONTINUATION/TEST_INTERRUPTION_"+stage &&
         test_fired_stop_stage=="INTERRUPT_AFTER_"+(stage=="PENDING" ? "RELEASE_PENDING" : stage);
      Check(interrupted,"PARTIAL_"+stage);
      // This MUST precede the early return: a failed prerequisite is the
      // diagnostic of interest, not an intentionally fired interruption.
      Print("CONTINUATION_PARTIAL_DETAIL|",stage,"|",result.stage,"|",result.reason,
         "|hook=",test_fired_stop_stage,"|hook_fired=",interrupted,"|broker_calls=",broker.calls,
         "|fresh_and_stage_details=CONTINUATION_EVENT_STATE/CONTINUATION_STAGE_TRACE");
      if(!interrupted){test_stop_stage="";return;}
      if(stage=="RELEASED" && !CaptureReleasedBeforeRestart(i)){test_stop_stage="";return;}
      if(stage=="CLOCK")
      {
         const bool clock_only=ClockOnlyPartial(i.path,initial,partial);
         Check(clock_only,"CLOCK_PARTIAL_ONLY_CLOCK_ADVANCED_ALL_OTHER_ROWS_EXACT");
         if(!clock_only)return;
         SWV5S5_MvpMt5ReadOnlyPlatform platform;SWV5S5_MvpAttendedContinuation classifier;
         SWV5S5_MvpLeaseClockAuthority reopened;SWV5S5_MvpLeaseClockObservation stored,fresh;
         SWV5S5_MvpAuthorityRow row,before[],after[];bool found=false;
         const bool cold=reopened.ConfigureReadOnly(i.path,m_ns) && reopened.LoadStored(stored,row,found) && found &&
            !reopened.CurrentFreshObservation(fresh) && classifier.ClassifyClockOnlyHistoricalPartial(i,platform,initial,result) &&
            !result.accepted && result.stage=="CLOCK_ONLY_HISTORICAL_PARTIAL" && result.reason=="NEW_ATTENDED_ATTEMPT_REQUIRED" &&
            Rows(i.path,after) && SameRows(partial,after);
         Check(cold,"RESUME_CLOCK_COLD_STRUCTURAL_PASS_NO_FRESHNESS_RECONSTRUCTION_NO_GRANT");
         if(!cold)return;
         SWV5S5_MvpOperatorInvocation old_op;old_op.operator_id="FUSION_DEMO_ATTENDED_OPERATOR_01";
         old_op.authority_role=SWV5S5_MVP_OPERATOR_ROLE;old_op.authentication_reference="TEST_ONLY_OLD_A";old_op.authenticated_at=stored.observed_at;
         test_stop_stage="EVENT_READY";test_fired_stop_stage="";
         const bool rejected=Rows(i.path,before) && !classifier.Run(i,old_op,reopened,platform,broker,result) &&
            result.reason=="CONTINUATION_NEW_ATTENDED_EVENT_FRESHNESS_REQUIRED" && test_fired_stop_stage=="" &&
            broker.calls==0 && Rows(i.path,after) && SameRows(before,after);
         test_stop_stage="";reopened.Close();
         Check(rejected,"RESUME_CLOCK_OLD_EVENT_CANNOT_MUTATE_MC_EVENT_FRESHNESS");if(!rejected)return;
         i.acknowledged=false;
         const bool ack_rejected=!Execute(i,broker,result) && result.reason=="NO_FRESH_ACK_ZERO_MUTATION" &&
            Rows(i.path,after) && SameRows(before,after);
         Check(ack_rejected,"RESUME_CLOCK_NO_NEW_ACK_ZERO_PUBLICATION");if(!ack_rejected)return;
         m_clock_partial_path=i.path;m_clock_partial_time=stored.observed_at;m_clock_partial_ready=true;
         Print("CONTINUATION_RESUME_CLOCK|STRUCTURE_RECOGNIZED|NEW_ATTENDED_ATTEMPT_REQUIRED|authority_granted=false");
         test_stop_stage="";return; // New mutation attempt is a LATER native tick.
      }
      if(stage!="INACTIVE")
      {
         SWV5S5_MvpControlledDemoResult diagnostic;SWV5S5_MvpAuthorityRow before[],after[];
         Check(Rows(i.path,before) && NativePreflight(i.path,diagnostic) && !diagnostic.accepted &&
            diagnostic.broker_submission_calls==0 && Rows(i.path,after) && SameRows(before,after),"PARTIAL_FAIL_CLOSED_"+stage);
      }
      test_stop_stage="";SWV5S5_MvpAttendedContinuation owner;
      const bool completed=(stage=="INACTIVE" ? owner.ReadCompletedOnly(i,result) : Execute(i,broker,result));
      if(Waiting(result)){m_job_kind[m_last_job]="RESUME_COMPLETE";m_job_stage[m_last_job]=stage;return;}
      Print("CONTINUATION_RESUME_DETAIL|",stage,"|",result.stage,"|",result.reason);
      Check(completed && result.accepted,"RESUME_"+stage);
   }
   void GovernanceClockBinding(const bool aliased)
   {
      const string path=m_run_prefix+(aliased ? ".GOV_CLOCK_ALIAS.sqlite" : ".GOV_CLOCK_DISTINCT.sqlite");
      Check(Clone(path),"GOV_CLOCK_COPY");
      SWV5S5_MvpSqliteAuthorityStore store;
      SWV5S5_MvpAuthorityRow prior,row,clock_row,before[],after[]; bool found=false;
      SWV5S5_MvpReconciliationGovernanceBundle expected,refreshed;
      SWV5S5_MvpLeaseClockAuthority clock;
      SWV5S5_MvpLeaseClockObservation accepted;
      if(!Open(path,store) || !store.ReadRow(SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE,"CURRENT",prior,found) || !found ||
         !SWV5S5_MvpDecodeGovernance(prior.payload,expected) || !clock.Configure(path,m_ns) ||
         !clock.ObserveFromCurrentSymbolOnTick(_Symbol,aliased ? "TEST_ONLY/GOV_CLOCK_ALIAS" : "TEST_ONLY/GOV_CLOCK_DISTINCT",accepted,clock_row))
      {Check(false,"GOV_CLOCK_PREREQUISITES");return;}
      SWV5S5_MvpOperatorInvocation op; op.operator_id="FUSION_DEMO_ATTENDED_OPERATOR_01";
      op.authority_role=SWV5S5_MVP_OPERATOR_ROLE;op.authentication_reference="TEST_ONLY_FRESH_A";op.authenticated_at=accepted.observed_at;
      SWV5S5_MvpReconciliationGovernanceAuthority owner;
      if(!owner.Configure(path,m_ns)){Check(false,"GOV_CLOCK_CONFIGURE");return;}
      SWV5S5_MvpReconciliationGovernanceBundle expired; SWV5S5_MvpAuthorityRow expired_row;
      Check(expected.valid_until<=accepted.observed_at && !owner.Load(accepted.observed_at,expected.profile,expired,expired_row,found) && found,
         "GOV_EXPIRED_ORDINARY_LOAD_REJECTED");
      SWV5S5_F_ProfileScope wrong_profile=expected.profile;wrong_profile.server+="-WRONG";
      Check(Rows(path,before) && !owner.RefreshCurrent(true,op,clock,accepted,expected,prior,wrong_profile,
         m_input.approval_reference,m_input.proof_reference,accepted.observed_at+3600,refreshed,row) &&
         Rows(path,after) && SameRows(before,after),"GOV_REFRESH_PROFILE_MISMATCH_REJECTED_UNCHANGED");
      SWV5S5_MvpLeaseClockObservation supplied=accepted; supplied.observed_at--;
      Check(Rows(path,before) && !owner.RefreshCurrent(true,op,clock,supplied,expected,prior,expected.profile,
         m_input.approval_reference,m_input.proof_reference,accepted.observed_at+3600,refreshed,row) &&
         Rows(path,after) && SameRows(before,after),"GOV_CLOCK_HISTORICAL_TIME_REJECTED_UNCHANGED");
      supplied=accepted; supplied.clock_sequence++;
      Check(!owner.RefreshCurrent(true,op,clock,supplied,expected,prior,expected.profile,
         m_input.approval_reference,m_input.proof_reference,accepted.observed_at+3600,refreshed,row) &&
         Rows(path,after) && SameRows(before,after),"GOV_CLOCK_CALLER_SEQUENCE_REJECTED_UNCHANGED");
      SWV5S5_MvpLeaseClockAuthority reopened;
      Check(reopened.ConfigureReadOnly(path,m_ns) && !owner.RefreshCurrent(true,op,reopened,accepted,expected,prior,expected.profile,
         m_input.approval_reference,m_input.proof_reference,accepted.observed_at+3600,refreshed,row) &&
         Rows(path,after) && SameRows(before,after),"GOV_CLOCK_REOPENED_NOT_EVENT_FRESH");
      row=prior; // Exact prior/output alias used by the actual continuation call.
      const bool refreshed_ok=aliased ?
         owner.RefreshCurrent(true,op,clock,accepted,expected,row,expected.profile,
            m_input.approval_reference,m_input.proof_reference,accepted.observed_at+3600,refreshed,row) :
         owner.RefreshCurrent(true,op,clock,accepted,expected,prior,expected.profile,
            m_input.approval_reference,m_input.proof_reference,accepted.observed_at+3600,refreshed,row);
      Check(refreshed_ok &&
         refreshed.authority_sequence==accepted.clock_sequence && refreshed.valid_from==accepted.observed_at &&
         row.logical_revision==prior.logical_revision+1 && row.updated_at==accepted.observed_at &&
         owner.Load(accepted.observed_at,expected.profile,expired,expired_row,found) && found &&
         SWV5S5_MvpContinuationRowExact(row,expired_row),aliased ?
         "GOV_CLOCK_EXACT_ACCEPTED_EVENT_REFRESH_ALIASED_CAS" : "GOV_CLOCK_EXACT_ACCEPTED_EVENT_REFRESH_DISTINCT_CAS");
   }
   void GovernanceRowNegatives()
   {
      string ids[]={"GOV_REFRESH_CORRUPT_ROW_REJECTED","GOV_REFRESH_CAPABILITY_COERCION_REJECTED","GOV_REFRESH_POLICY_VERSION_REJECTED"};
      for(int fault=0;fault<ArraySize(ids);fault++)
      {
         const string path=m_run_prefix+".GOV_NEG_"+IntegerToString(fault)+".sqlite";
         SWV5S5_MvpSqliteAuthorityStore store;SWV5S5_MvpAuthorityRow prior,changed,clock_row,committed,before[],after[];
         SWV5S5_MvpReconciliationGovernanceBundle expected,damaged,refreshed;
         SWV5S5_MvpLeaseClockAuthority clock;SWV5S5_MvpLeaseClockObservation accepted;bool found=false;string payload;
         if(!Clone(path) || !Open(path,store) || !store.ReadRow(SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE,"CURRENT",prior,found) || !found ||
            !SWV5S5_MvpDecodeGovernance(prior.payload,expected)) {Check(false,ids[fault]+"/FIXTURE");continue;}
         damaged=expected;
         if(fault==1)damaged.capability_proof.query_completeness_capability_proven=true;
         if(fault==2)damaged.correlation_policy.policy_version++;
         if(!SWV5S5_F_DeriveCorrelationPolicyDigest(damaged.correlation_policy,damaged.correlation_policy.policy_digest) ||
            !SWV5S5_F_DeriveCapabilityProofDigest(damaged.capability_proof,damaged.capability_proof.proof_digest))
         {Check(false,ids[fault]+"/DIGEST");continue;}
         damaged.negative_policy.capability_proof_digest=damaged.capability_proof.proof_digest;
         if(!SWV5S5_F_DeriveNegativePolicyDigest(damaged.negative_policy,damaged.negative_policy.policy_digest) ||
            !SWV5S5_MvpGovernanceDigest(damaged,damaged.bundle_digest) || !SWV5S5_MvpGovernanceCanonical(damaged,true,payload))
         {Check(false,ids[fault]+"/CANONICAL");continue;}
         if(fault==0)payload+="!"; // Physical CAS valid; canonical decode must reject.
         if(!store.CompareAndSet(prior.domain_key,prior.record_key,prior.logical_revision,prior.store_revision,prior.payload_digest,prior.state,
            prior.logical_revision+1,1,damaged.bundle_digest,payload,damaged.valid_from,changed) || !clock.Configure(path,m_ns) ||
            !clock.ObserveFromCurrentSymbolOnTick(_Symbol,"TEST_ONLY/GOV_NEG_"+IntegerToString(fault),accepted,clock_row))
         {Check(false,ids[fault]+"/PREPARATION");continue;}
         SWV5S5_MvpOperatorInvocation op;op.operator_id="FUSION_DEMO_ATTENDED_OPERATOR_01";op.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
         op.authentication_reference="TEST_ONLY_FRESH_A";op.authenticated_at=accepted.observed_at;
         SWV5S5_MvpReconciliationGovernanceAuthority owner;
         Check(owner.Configure(path,m_ns) && Rows(path,before) &&
            !owner.RefreshCurrent(true,op,clock,accepted,damaged,changed,expected.profile,m_input.approval_reference,m_input.proof_reference,
               accepted.observed_at+3600,refreshed,committed) && Rows(path,after) && SameRows(before,after),ids[fault]);
      }
   }
   void ClockDiagnosticNegatives()
   {
      string ids[]={"ID","BROKER","SERVER","ACCOUNT","SYMBOL","AUTHORITY","MALFORMED","DIGEST","STORE_REVISION",
         "ZERO_SEQUENCE","BACKWARD_SEQUENCE","BACKWARD_TIME","DUPLICATE_OBSERVATION","FUTURE_TIME","ZERO_TIME"};
      for(int fault=0;fault<ArraySize(ids);fault++)
      {
         const string path=m_run_prefix+".CLOCK_DIAG_"+ids[fault]+".sqlite";
         SWV5S5_MvpSqliteAuthorityStore store;SWV5S5_MvpLeaseClockAuthority clock;
         SWV5S5_MvpLeaseClockObservation at,ordinary,diagnostic;SWV5S5_MvpAuthorityRow prior,changed,before[],after[];
         string reason,payload,digest,a,b;
         if(!Clone(path) || !Open(path,store) || !clock.Configure(path,m_ns) ||
            !clock.ObserveFromCurrentSymbolOnTick(_Symbol,"TEST_ONLY/CLOCK_DIAG/"+ids[fault],at,prior))
         {Check(false,"CLOCK_DIAG_FIXTURE_"+ids[fault]);continue;}
         const bool positive=clock.CurrentFreshObservation(ordinary) && clock.CurrentFreshObservationDiagnostic(diagnostic,reason) &&
            reason=="" && SWV5S5_MvpLeaseClockPayload(ordinary,a,digest) && SWV5S5_MvpLeaseClockPayload(diagnostic,b,digest) && a==b;
         Check(positive,"CLOCK_DIAG_EQUIVALENT_POSITIVE_"+ids[fault]);if(!positive)continue;
         if(fault==11 || fault==12)
         {
            if(!Rows(path,before)){Check(false,"CLOCK_DIAG_ROWS");continue;}
            const bool rejected=!clock.ObserveAcceptedEvent(SWV5S5_MVP_CLOCK_SOURCE_CURRENT_SYMBOL_ONTICK,_Symbol,
               at.broker_identity,at.server,at.account_login,fault==11 ? at.observed_at-1 : at.observed_at,
               fault==12 ? at.platform_observation_id : "TEST_ONLY/BACKWARD_TIME",diagnostic,changed);
            Check(rejected && Rows(path,after) && SameRows(before,after),"CLOCK_NEGATIVE_"+ids[fault]);continue;
         }
         SWV5S5_MvpLeaseClockObservation bad=at;bad.clock_sequence=at.clock_sequence+1;
         if(fault==0)bad.clock_id+="-WRONG";if(fault==1)bad.broker_identity+="-WRONG";
         if(fault==2)bad.server+="-WRONG";if(fault==3)bad.account_login++;if(fault==4)bad.source_symbol="OTHER";
         if(fault==5)bad.clock_authority=SWV5_TIME_AUTHORITY_NONE;
         if(fault>=1 && fault<=3 && !SWV5S5_MvpLeaseClockId(bad.broker_identity,bad.server,bad.account_login,bad.source_symbol,bad.clock_id))
         {Check(false,"CLOCK_FOREIGN_PROFILE_SELF_CONSISTENT_ENCODING");continue;}
         if(fault==9)bad.clock_sequence=0;if(fault==10)bad.clock_sequence=at.clock_sequence-1;
         if(fault==13){bad.observed_at=at.observed_at+86400;bad.platform_observation_id="TEST_ONLY/FUTURE_CLOCK";}
         if(fault==14)bad.observed_at=0;
         // ZERO_TIME changes ONLY the payload time. Keep payload sequence and
         // the positive physical timestamp valid so CAS is not the oracle.
         if(fault==14)bad.clock_sequence=at.clock_sequence;
         if(!SWV5S5_MvpLeaseClockPayload(bad,payload,digest)){Check(false,"CLOCK_DIAG_ENCODING");continue;}
         if(fault==6)payload+="!";
         if(fault==7)digest=StringSubstr(digest,0,63)+(StringSubstr(digest,63,1)=="0" ? "1" : "0");
         if(!store.CompareAndSet(prior.domain_key,prior.record_key,prior.logical_revision,prior.store_revision,prior.payload_digest,prior.state,
            prior.logical_revision+1,1,digest,payload,fault==14 ? prior.updated_at : bad.observed_at,changed))
         {Check(false,"CLOCK_DIAG_MUTATION");continue;}
         if(fault==14)
         {
            SWV5S5_MvpAuthorityRow readback;SWV5S5_MvpLeaseClockObservation decoded;bool found=false;
            const bool committed=store.ReadRow(prior.domain_key,prior.record_key,readback,found) && found &&
               SWV5S5_MvpContinuationRowExact(changed,readback) && readback.updated_at==prior.updated_at && readback.updated_at>0 &&
               SWV5S5_MvpDecodeLeaseClockPayload(readback.payload,decoded) && decoded.observed_at==0 &&
               decoded.clock_sequence==at.clock_sequence && !SWV5S5_MvpLeaseClockObservationValid(decoded);
            Check(committed,"CLOCK_ZERO_TIME_CAS_COMMITTED_VALID_METADATA_INVALID_PAYLOAD");
            if(!committed)continue;
         }
         if(fault==8)
         {
            // Explicit invalid physical row injection in this fresh TEST_ONLY clone only.
            if(StringFind(path,"TEST_ONLY_MVP_CONTINUATION_")!=0){Check(false,"CLOCK_DIAG_UNSAFE_PATH");continue;}
            int db=DatabaseOpen(path,DATABASE_OPEN_READWRITE|DATABASE_OPEN_COMMON);
            const bool injected=db!=INVALID_HANDLE && DatabaseExecute(db,
               "UPDATE swv5_authority_rows SET store_revision='TEST_ONLY_INVALID_REVISION' WHERE namespace_digest='"+m_ns+
               "' AND domain_key='MVP_OWNERSHIP_LEASE' AND record_key='LEASE_CLOCK_CURRENT'");
            if(db!=INVALID_HANDLE)DatabaseClose(db);
            if(!injected){Check(false,"CLOCK_DIAG_REVISION_INJECTOR");continue;}
         }
         if(fault==13)
         {
            SWV5S5_MvpLeaseClockAuthority next;
            Check(next.Configure(path,m_ns) && Rows(path,before) &&
               !next.ObserveFromCurrentSymbolOnTick(_Symbol,"TEST_ONLY/FUTURE_REJECT",diagnostic,changed) &&
               Rows(path,after) && SameRows(before,after),"CLOCK_NEGATIVE_FUTURE_TIME_NO_PUBLICATION");
         }
         else
         {
            Check(!clock.CurrentFreshObservationDiagnostic(diagnostic,reason) && StringFind(reason,"PRESTATE_CLOCK_")==0 &&
               !clock.CurrentFreshObservation(ordinary),"CLOCK_NEGATIVE_"+ids[fault]+"/"+reason);
            if(fault==14)Check(reason=="PRESTATE_CLOCK_TIME_INVALID","CLOCK_ZERO_TIME_REJECTED_BY_TIME_VALIDATOR_NOT_CAS");
            SWV5S5_MvpContinuationInput structural_input=m_input;structural_input.path=path;structural_input.continuation_id="STRUCTURAL_NEG_"+ids[fault];
            SWV5S5_MvpAttendedContinuation classifier;SWV5S5_MvpMt5ReadOnlyPlatform platform;SWV5S5_MvpContinuationResult structural_result;
            Check(Rows(path,before) && !classifier.ClassifyStoredPreState(structural_input,platform,structural_result) &&
               Rows(path,after) && SameRows(before,after),"STORED_CLOCK_STRUCTURAL_NEGATIVE_"+ids[fault]);
         }
      }
   }
   void PeriodicEpochStructural(const bool prepared=false)
   {
      SWV5S5_MvpContinuationInput i=m_input;i.path=m_run_prefix+".PERIODIC.sqlite";i.continuation_id="PERIODIC_EPOCH_1";
      SWV5S5_TestContinuationBroker broker;SWV5S5_MvpContinuationResult result;
      if(!prepared)
      {
         if(!Clone(i.path)){Check(false,"PERIODIC_EPOCH_1_ACTUAL_CONTINUATION_REQUIRED");return;}
         const bool completed=Execute(i,broker,result);
         if(Waiting(result)){m_job_kind[m_last_job]="PERIODIC";return;}
         if(!completed || !result.accepted){Check(false,"PERIODIC_EPOCH_1_ACTUAL_CONTINUATION_REQUIRED");return;}
      }
      Check(true,"PERIODIC_EPOCH_1_ACTUAL_CONTINUATION_COMPLETE_ZERO_SUBMISSION");
      SWV5S5_MvpLeaseClockAuthority later;SWV5S5_MvpLeaseClockObservation prior,advanced,event_clock;
      SWV5S5_MvpAuthorityRow row,committed,before[],after[];bool found=false;
      if(!later.Configure(i.path,m_ns) || !later.LoadStored(prior,row,found) || !found ||
         !later.ObserveAcceptedEvent(SWV5S5_MVP_CLOCK_SOURCE_CURRENT_SYMBOL_ONTICK,_Symbol,prior.broker_identity,prior.server,
            prior.account_login,prior.observed_at+1,"TEST_ONLY_PERIODIC_MODEL_CLOCK_ADVANCE",advanced,committed))
      {Check(false,"PERIODIC_LEGITIMATE_CLOCK_ADVANCE_PREREQUISITE");return;}
      later.Close();
      // Explicit model clock; no date patching of persisted authorities, no
      // claim that this is a future live tick. Validity windows stay intact.
      SWV5S5_TestContinuationPeriodicPlatform future;future.evaluation_time=prior.observed_at+3601;
      i.continuation_id="PERIODIC_EPOCH_2";i.acknowledged=false;
      SWV5S5_MvpAttendedContinuation classifier;SWV5S5_MvpLeaseClockAuthority cold;
      const bool structural=Rows(i.path,before) && cold.ConfigureReadOnly(i.path,m_ns) &&
         !cold.CurrentFreshObservation(event_clock) && classifier.ClassifyStoredPreState(i,future,result) &&
         !result.accepted && result.reason=="NEW_ATTENDED_ATTEMPT_REQUIRED" && Rows(i.path,after) && SameRows(before,after);
      Check(structural,"PERIODIC_EPOCH_2_EXPIRED_STRUCTURAL_NO_GRANT_NO_RECONSTRUCTED_FRESHNESS");if(!structural)return;
      SWV5S5_MvpOperatorInvocation op;op.operator_id="FUSION_DEMO_ATTENDED_OPERATOR_01";op.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
      op.authentication_reference="TEST_ONLY_PERIODIC_NEW_A_MODEL";op.authenticated_at=future.evaluation_time;
      const bool old_rejected=!classifier.Run(i,op,cold,future,broker,result) && result.reason=="CONTINUATION_NEW_ATTENDED_EVENT_FRESHNESS_REQUIRED" &&
         Rows(i.path,after) && SameRows(before,after);
      Check(old_rejected,"PERIODIC_EPOCH_2_NEW_EVENT_REQUIRED");cold.Close();if(!old_rejected)return;
      i.acknowledged=true;SWV5S5_MvpLeaseClockAuthority new_event;
      if(!new_event.Configure(i.path,m_ns) || !new_event.ObserveAcceptedEvent(SWV5S5_MVP_CLOCK_SOURCE_CURRENT_SYMBOL_ONTICK,_Symbol,
         prior.broker_identity,prior.server,prior.account_login,future.evaluation_time,"TEST_ONLY_PERIODIC_EPOCH_2_NEW_EVENT",event_clock,committed) ||
         !new_event.CurrentFreshObservation(advanced) || !Rows(i.path,before))
      {Check(false,"PERIODIC_EPOCH_2_NEW_ACCEPTED_EVENT_PREREQUISITE");return;}
      test_stop_stage="EVENT_READY";test_fired_stop_stage="";
      const bool ready=!classifier.Run(i,op,new_event,future,broker,result) && result.partial_continuation &&
         result.reason=="PARTIAL_CONTINUATION/TEST_INTERRUPTION_EVENT_READY" && test_fired_stop_stage=="INTERRUPT_AFTER_EVENT_READY" &&
         Rows(i.path,after) && SameRows(before,after);
      test_stop_stage="";new_event.Close();
      Check(ready && test_forbidden_transport_calls==0,"PERIODIC_EPOCH_2_MAY_BEGIN_MODEL_ONLY_NO_AUTHORITY_MUTATION");
   }
   void HeartbeatIdentityNegatives()
   {
      const string path=m_run_prefix+".HB_NEGATIVES.sqlite";
      SWV5S5_MvpSqliteAuthorityStore store;SWV5S5_MvpAuthorityRow prior,clock_row,before[],after[],committed;
      SWV5_InstanceLease lease,renewed;SWV5S5_MvpInitialOwnershipAuthority owner;SWV5S5_MvpLeaseClockAuthority clock;
      SWV5S5_MvpLeaseClockObservation at;bool found=false;
      if(!Clone(path) || !Open(path,store) || !store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,prior,found) || !found ||
         !SWV5S5_MvpDecodeOwnershipLeasePhysical(prior.payload,lease) || !owner.Configure(path,m_ns) || !clock.Configure(path,m_ns) ||
         !clock.ObserveFromCurrentSymbolOnTick(_Symbol,"TEST_ONLY/HB_NEG",at,clock_row) || !Rows(path,before))
      {Check(false,"HB_NEGATIVE_PREREQUISITES");return;}
      SWV5S5_MvpOperatorInvocation op;op.operator_id="FUSION_DEMO_ATTENDED_OPERATOR_01";op.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
      op.authentication_reference="TEST_ONLY_FRESH_A";op.authenticated_at=at.observed_at;
      string ids[]={"HB_INSTANCE","HB_PROCESS","HB_STARTED_AT","HB_OWNER_KEY","HB_FENCE_TOKEN","HB_LEASE_VERSION","HB_TAKEOVER_GENERATION","HB_NONATTENDED"};
      for(int f=0;f<ArraySize(ids);f++)
      {
         SWV5_OwnerIdentity configured=lease.fence.owner;SWV5_InstanceLease expected=lease;
         if(f==0)configured.instance_id+="-WRONG";if(f==1)configured.process_fingerprint+="-WRONG";
         if(f==2)configured.started_at++;if(f==3)configured.key.account_login++;
         if(f==4)expected.fence.fencing_token_digest="WRONG";if(f==5)expected.fence.lease_version++;
         if(f==6)expected.fence.takeover_generation++;
         Check(!owner.HeartbeatAttended(f!=7,op,configured,expected,prior,3600,clock,renewed,committed) &&
            Rows(path,after) && SameRows(before,after),ids[f]);
      }
      SWV5S5_MvpAuthorityRow changed;Check(store.CompareAndSet(prior.domain_key,prior.record_key,prior.logical_revision,
         prior.store_revision,prior.payload_digest,prior.state,prior.logical_revision+1,prior.state,prior.payload_digest,prior.payload,at.observed_at,changed),"HB_ALTER_PRIOR_ROW_CAS");
      Check(!owner.HeartbeatAttended(true,op,lease.fence.owner,lease,prior,3600,clock,renewed,committed),"HB_ALTERED_CURRENT_LEASE_REJECTED");
   }
   void OperationalRowNegatives()
   {
      string domains[]={"MVP_REQUEST_SEQUENCE","MVP_INGRESS_LEDGER","MVP_MARGIN_AUTHORITY","MVP_BASKET_RISK_AUTHORITY",
         "MVP_SUBMISSION_PERMIT","MVP_ADMISSION_AUTHORITY","MVP_ATTEMPT_RECONCILIATION_PIN","MVP_RECONCILIATION_PUBLICATION",
         "MVP_INVOCATION_CLAIM","MVP_SUBMISSION_AUTHORITY","MVP_BROKER_SYNC_EVIDENCE","MVP_RECOVERY_METADATA"};
      for(int d=0;d<ArraySize(domains);d++)
      {
         SWV5S5_MvpContinuationInput i=m_input;i.path=m_run_prefix+".OP_"+IntegerToString(d)+".sqlite";i.continuation_id="OP_NEG_"+IntegerToString(d);
         SWV5S5_MvpSqliteAuthorityStore store;SWV5S5_MvpAuthorityRow row;string payload,digest;
         if(!Clone(i.path) || !Open(i.path,store) || !SWV5S5_CanonicalString("TEST_ONLY_INVALID_OPERATIONAL_ROW",domains[d],payload) ||
            !SWV5S5_DomainDigest(domains[d],payload,digest) || !store.CompareAndSet(domains[d],"TEST_ONLY_OPERATIONAL",0,"","",0,1,1,digest,payload,TimeCurrent(),row))
         {Check(false,"OP_FIXTURE_"+domains[d]);continue;}
         store.Close();SWV5S5_TestContinuationBroker broker;SWV5S5_MvpContinuationResult result;
         Check(!Execute(i,broker,result) && broker.calls==0,"OPERATIONAL_ROW_REJECTED_"+domains[d]);
      }
   }
   bool ReleaseBoundaryCase(const bool after_pending,const bool mutate_governance,string &basis)
   {
      basis="";
      SWV5S5_MvpContinuationInput i=m_input;i.path=m_run_prefix+(after_pending ? ".BOUND_PENDING.sqlite" : ".BOUND_ACTIVE.sqlite");
      i.path+=mutate_governance ? ".MUTATED.sqlite" : ".CONTROL.sqlite";
      i.continuation_id=after_pending ? "BOUND_PENDING" : "BOUND_ACTIVE";
      if(!m_ready && !Clone(i.path)){Check(false,"BOUNDARY_COPY");return false;}
      test_stop_stage=after_pending ? "PENDING" : "FLAT";if(!m_ready)test_fired_stop_stage="";
      SWV5S5_TestContinuationBroker broker;SWV5S5_MvpContinuationResult r;
      bool first_ok=false;
      if(m_ready){r=m_ready_result;broker.calls=m_ready_calls;m_ready=false;}
      else first_ok=Execute(i,broker,r);
      if(Waiting(r)){m_job_kind[m_last_job]="BOUNDARY";test_stop_stage="";return false;}
      const bool interrupted=!first_ok && r.partial_continuation &&
         r.reason=="PARTIAL_CONTINUATION/TEST_INTERRUPTION_"+test_stop_stage &&
         test_fired_stop_stage==(after_pending ? "INTERRUPT_AFTER_RELEASE_PENDING" : "INTERRUPT_AFTER_FLAT");
      Check(interrupted,"BOUNDARY_INTERRUPT");test_stop_stage="";
      if(!interrupted){Print("BOUNDARY_FIXTURE_FAIL|",r.reason);return false;}
      SWV5S5_MvpSqliteAuthorityStore store;SWV5S5_MvpAuthorityRow rows[],governance,changed,current,committed;bool found=false;
      SWV5S5_MvpContinuationFlatAuthority flat;bool flat_found=false;
      if(!Open(i.path,store) || !store.ReadAllRows(rows)){Check(false,"BOUNDARY_READ_ROWS");return false;}
      for(int x=0;x<ArraySize(rows);x++)if(rows[x].domain_key==SWV5S5_MVP_DOMAIN_CONTINUATION_FLAT &&
         SWV5S5_MvpDecodeContinuationFlat(rows[x].payload,flat))flat_found=true;
      if(!flat_found || !store.ReadRow(SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE,"CURRENT",governance,found) || !found ||
         !store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current,found) || !found)
      {Check(false,"BOUNDARY_PHYSICAL_STAGE_MISSING");return false;}
      SWV5_ContractValidationContext context;ZeroMemory(context);SWV5S5_MvpInitProductionVersion(context.expected_version);
      context.clock_id=flat.clock_id;context.clock_authority=flat.clock_authority;context.clock_sequence=flat.clock_sequence;
      context.clock_time=flat.observed_at;context.volume_tolerance=1e-7;context.price_tolerance=1e-7;
      SWV5S5_MvpReconciliationGovernanceBundle valid_governance;SWV5S5_MvpAuthorityRow bound_actual[];
      const bool ready=SWV5S5_MvpDecodeGovernance(governance.payload,valid_governance) &&
         SWV5S5_MvpGovernanceValid(valid_governance,context.clock_time) &&
         governance.state==1 && governance.updated_at==valid_governance.valid_from &&
         SWV5S5_MvpContinuationRowValid(store,governance) &&
         current.state==(int)(after_pending ? SWV5_HARD_KILL_RELEASE_PENDING : SWV5_HARD_KILL_ACTIVE) &&
         SWV5S5_MvpContinuationBoundaryLineageValid(store,context,flat) &&
         SWV5S5_MvpContinuationBoundRowsCurrent(store,context,flat,false,bound_actual);
      Check(ready,"BOUNDARY_INTENDED_STAGE_AND_FRESH_BINDING_PROVEN");
      if(!ready)return false;
      // Equivalent donor/configuration and boundary-state basis. Each case has
      // its own legitimate native event/time; no clock/time value is fabricated.
      string f;basis="";
      if(!SWV5S5_CanonicalNamespace("scope",flat.scope,f))return false;basis+=f;
      if(!SWV5S5_CanonicalAccountNamespace("account",flat.account,f))return false;basis+=f;
      if(!SWV5S5_CanonicalFence("fence",flat.fence,f))return false;basis+=f;
      if(!SWV5S5_CanonicalString("clock_id",flat.clock_id,f))return false;basis+=f;
      if(!SWV5S5_CanonicalUInt("clock_sequence",flat.clock_sequence,f))return false;basis+=f;
      if(!SWV5S5_CanonicalUInt("latch_generation",flat.active.latch_generation,f))return false;basis+=f;
      if(!SWV5S5_CanonicalUInt("release_generation",flat.active.release_generation,f))return false;basis+=f;
      if(!SWV5S5_CanonicalString("approval",i.approval_reference,f))return false;basis+=f;
      if(!SWV5S5_CanonicalString("proof",i.proof_reference,f))return false;basis+=f;
      SWV5S5_MvpControlledDemoResult denied;SWV5S5_MvpAuthorityRow diagnostic_before[],diagnostic_after[];
      const bool denied_unchanged=Rows(i.path,diagnostic_before) && NativePreflight(i.path,denied) && !denied.accepted &&
         denied.broker_submission_calls==0 && Rows(i.path,diagnostic_after) && SameRows(diagnostic_before,diagnostic_after);
      Check(denied_unchanged,"BOUNDARY_PARTIAL_PREFLIGHT_DENIED_ZERO_MUTATION");
      if(!denied_unchanged)return false;
      SWV5S5_MvpAuthorityRow complete;SWV5_HardKillReleaseEvidence release_evidence;SWV5_HardKillReleaseAuthorityRecord release_authority;
      const bool no_later_release=SWV5S5_MvpIssueContinuationRelease(flat,release_evidence,release_authority) &&
         store.ReadRow(SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE,release_authority.authority_record_id,complete,found) && !found;
      Check(no_later_release,"BOUNDARY_EXPECTED_LATER_RELEASE_ABSENT");
      if(!no_later_release)return false;
      bool stale_bound=false;
      if(mutate_governance)
      {
      // Change ONLY the physical CURRENT revision/token. Payload, capabilities,
      // finite validity and original updated_at remain exactly structurally valid.
      const bool mutated=store.CompareAndSet(governance.domain_key,governance.record_key,governance.logical_revision,governance.store_revision,
         governance.payload_digest,governance.state,governance.logical_revision+1,governance.state,governance.payload_digest,
         governance.payload,governance.updated_at,changed);
      SWV5S5_MvpReconciliationGovernanceAuthority governance_owner;SWV5S5_MvpReconciliationGovernanceBundle reread;
      SWV5S5_MvpAuthorityRow reread_row,mutated_rows[];
      const bool mutation_valid=mutated && changed.logical_revision==governance.logical_revision+1 && changed.store_revision!=governance.store_revision &&
         changed.payload==governance.payload && changed.payload_digest==governance.payload_digest && changed.updated_at==governance.updated_at &&
         governance_owner.ConfigureReadOnly(i.path,m_ns) && governance_owner.Load(context.clock_time,valid_governance.profile,reread,reread_row,found) && found &&
         SWV5S5_MvpContinuationRowExact(changed,reread_row);
      Check(mutation_valid,"BOUNDARY_MUTATE_VALID_GOVERNANCE_ROW");
      if(!mutation_valid)return false;
      bool only_governance=Rows(i.path,mutated_rows) && ArraySize(rows)==ArraySize(mutated_rows);int changed_count=0;
      for(int x=0;only_governance && x<ArraySize(rows);x++)
      {
         if(!SWV5S5_MvpContinuationRowExact(rows[x],mutated_rows[x]))
         {only_governance=rows[x].domain_key==governance.domain_key && rows[x].record_key==governance.record_key &&
            SWV5S5_MvpContinuationRowExact(changed,mutated_rows[x]);changed_count++;}
      }
      SWV5S5_MvpAuthorityRow stale_actual[];
      stale_bound=mutated && only_governance && changed_count==1 &&
         SWV5S5_MvpContinuationBoundaryLineageValid(store,context,flat) &&
         SWV5S5_MvpContinuationPhysicalInvariants(store,context,flat) &&
         !SWV5S5_MvpContinuationBoundRowsCurrent(store,context,flat,false,stale_actual);
      Check(stale_bound,"BOUNDARY_STALE_AUTHORITY_NOT_GOVERNANCE_INVALIDITY");
      if(!stale_bound)return false;
      }
      SWV5_HardKillState state;SWV5S5_MvpAuthorityRow lease_row;SWV5_InstanceLease lease;
      bool accepted=false,release_invoked=false;
      if(after_pending)
      {
         if(!store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,lease_row,found) || !found ||
            !SWV5S5_MvpDecodeOwnershipLeasePhysical(lease_row.payload,lease))
         {Check(false,"BOUNDARY_FIXTURE_LEASE_READ_DECODE_FAILED");return false;}
         release_invoked=true;
         accepted=SWV5S5_MvpPersistApprovedContinuationRelease(store,context,flat,lease,current,false,state,committed);
      }
      else
      {
         release_invoked=true;
         accepted=SWV5S5_MvpStageContinuationPending(store,context,flat.op,flat,state,committed);
      }
      SWV5S5_MvpAuthorityRow readback;
      const bool read_ok=store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",readback,found) && found;
      bool passed=false;
      if(mutate_governance)
         passed=release_invoked && !accepted && read_ok && SWV5S5_MvpContinuationRowExact(current,readback);
      else
         passed=release_invoked && accepted && read_ok &&
            readback.state==(int)(after_pending ? SWV5_HARD_KILL_RELEASED : SWV5_HARD_KILL_RELEASE_PENDING) &&
            readback.logical_revision==current.logical_revision+1 && SWV5S5_MvpContinuationRowExact(committed,readback);
      Check(passed,mutate_governance ? "BOUNDARY_MUTATED_ACTUAL_INVOCATION_REJECTED" : "BOUNDARY_CONTROL_ACTUAL_INVOCATION_ACCEPTED");
      Print("CONTINUATION_BOUNDARY_DIFFERENTIAL|",(after_pending ? "PENDING_RELEASE" : "ACTIVE_TO_PENDING"),
         "|",(mutate_governance ? "MUTATED" : "CONTROL"),"|release_invoked=",release_invoked,
         "|accepted=",accepted,"|passed=",passed,"|forbidden_transport_calls=",test_forbidden_transport_calls);
      if(!mutate_governance)return passed && test_forbidden_transport_calls==0;
      SWV5S5_MvpAuthorityMutation mutation,none;ZeroMemory(none);
      SWV5S5_MvpPrepareMutation(current.domain_key,current.record_key,current,true,current.logical_revision+1,current.state,
         current.payload_digest,current.payload,TimeCurrent(),mutation);
      const bool snapshot_rejected=!store.CompareAndSetWithExactSnapshot(mutation,false,none,rows,committed,readback);
      Check(snapshot_rejected,"ATOMIC_COMPLETE_SNAPSHOT_GUARD_REJECTS_STALE_ROWS");
      return passed && stale_bound && snapshot_rejected && test_forbidden_transport_calls==0;
   }
   void ReleaseBoundaryMutation(const bool after_pending)
   {
      string control_basis,mutated_basis;
      const int base=after_pending ? 2 : 0;int before=m_job_count;
      const bool control=ReleaseBoundaryCase(after_pending,false,control_basis);
      if(m_job_count>before && m_job_kind[m_last_job]=="BOUNDARY")m_job_kind[m_last_job]=after_pending ? "BOUND_PENDING_CONTROL" : "BOUND_ACTIVE_CONTROL";
      else {m_boundary_done[base]=true;m_boundary_pass[base]=control;m_boundary_basis[base]=control_basis;}
      before=m_job_count;
      const bool mutated=ReleaseBoundaryCase(after_pending,true,mutated_basis);
      if(m_job_count>before && m_job_kind[m_last_job]=="BOUNDARY")m_job_kind[m_last_job]=after_pending ? "BOUND_PENDING_MUTATED" : "BOUND_ACTIVE_MUTATED";
      else {m_boundary_done[base+1]=true;m_boundary_pass[base+1]=mutated;m_boundary_basis[base+1]=mutated_basis;}
      if(m_boundary_done[base] && m_boundary_done[base+1])
         Check(control && mutated && control_basis!="" && control_basis==mutated_basis,
            after_pending ? "GOVERNANCE_RELEASE_DIFFERENTIAL_BOTH_CASES_REQUIRED" : "GOVERNANCE_PENDING_DIFFERENTIAL_BOTH_CASES_REQUIRED");
   }
   bool FinishJobs()
   {
      for(int j=0;j<m_job_count;j++)
      {
         if(!m_job_active[j] || m_job_tick[j]>=m_tick_id || TimeCurrent()<m_job_core[j].FinalizationNotBefore())continue;
         MqlTick tick;const datetime native_time=TimeCurrent();
         if(!SymbolInfoTick(_Symbol,tick) || tick.time!=native_time || tick.time_msc/1000!=(long)native_time)continue;
         m_job_active[j]=false; // one dispatch, even if publication/validation fails
         SWV5S5_MvpLeaseClockAuthority clock;SWV5S5_MvpLeaseClockObservation accepted;SWV5S5_MvpAuthorityRow row;
         SWV5S5_MvpMt5ReadOnlyPlatform platform;SWV5S5_MvpContinuationResult result;ZeroMemory(result);
         test_stop_stage=m_job_hook[j];test_fired_stop_stage="";
         const bool negative=StringFind(m_job_kind[j],"NEG_")==0;
         const int captures_before=m_job_broker[j].calls;
         const bool no_publication=m_job_kind[j]=="NEG_NO_FINAL_CLOCK" || m_job_kind[j]=="NEG_COLD_RESTART";
         const bool published=!no_publication && clock.Configure(m_job_input[j].path,m_ns) && clock.ObserveFromCurrentSymbolOnTick(_Symbol,
            "TEST_ONLY/FINAL/"+m_job_input[j].continuation_id+"/"+IntegerToString((long)GetMicrosecondCount()),accepted,row);
         if(no_publication)clock.ConfigureReadOnly(m_job_input[j].path,m_ns);
         SWV5S5_MvpOperatorInvocation invocation=m_job_op[j];
         if(m_job_kind[j]=="NEG_WRONG_OPERATOR")invocation.operator_id+="-WRONG";
         if(m_job_kind[j]=="NEG_WRONG_REFERENCE")invocation.authentication_reference+="-WRONG";
         SWV5S5_MvpAuthorityRow negative_before[],negative_after[];
         const bool captured_before=!negative || Rows(m_job_input[j].path,negative_before);
         bool ok=false;
         if(m_job_kind[j]=="RESUME_COMPLETE" && m_job_stage[j]=="RELEASED")ReleasedBeforeFinalization(j);
         if(m_job_kind[j]=="NEG_COLD_RESTART")
         {
            SWV5S5_MvpAttendedContinuation cold;
            ok=cold.Run(m_job_input[j],invocation,clock,platform,m_job_broker[j],result);
         }
         else if(published || no_publication)ok=m_job_core[j].Run(m_job_input[j],invocation,clock,platform,m_job_broker[j],result);
         if(negative)
         {
            const string expected=no_publication ? (m_job_kind[j]=="NEG_COLD_RESTART" ?
               "CONTINUATION_NEW_ATTENDED_EVENT_FRESHNESS_REQUIRED" : "PARTIAL_CONTINUATION/LATER_ACCEPTED_FINALIZATION_CLOCK_REQUIRED") :
               "PARTIAL_CONTINUATION/ATTENDED_INVOCATION_IDENTITY_CHANGED";
            Check(!ok && !result.accepted && result.reason==expected && captured_before &&
               Rows(m_job_input[j].path,negative_after) && SameRows(negative_before,negative_after),m_job_kind[j]+"/EXACT_REJECTION_ZERO_AUTHORITY_MUTATION");
            delete m_job_core[j];test_stop_stage="";continue;
         }
         if(!published){result.reason="TEST_ONLY_FINAL_CLOCK_PUBLICATION_FAILED";result.stage="FINALIZATION_CLOCK";}
         Check(published && accepted.observed_at>m_job_op[j].authenticated_at && m_job_broker[j].calls==captures_before,
            "REAL_LATER_FINAL_CLOCK_NO_RECAPTURE_"+m_job_kind[j]);
         Print("CONTINUATION_MULTI_TICK|kind=",m_job_kind[j],"|T0=",(long)m_job_op[j].authenticated_at,
            "|T2=",(long)accepted.observed_at,"|stage=",result.stage,"|reason=",result.reason,"|captures=",m_job_broker[j].calls);
         if(m_job_kind[j]=="MAIN")
         {
            MainAssertions(ok,m_job_broker[j],result);Check(Rows(m_main,m_rows),"MAIN_COMPLETED_LATER_PREFLIGHT_STORE_SNAPSHOT");
            if(ok)FlatTimeNegatives();
            m_t0=TimeCurrent();m_main_completion_tick=m_tick_id;
         }
         else if(m_job_kind[j]=="PERIODIC")
         {
            if(ok && result.accepted)PeriodicEpochStructural(true);
            else Check(false,"PERIODIC_EPOCH_1_ACTUAL_CONTINUATION_REQUIRED");
         }
         else if(m_job_kind[j]=="CLOCK_COMPLETE")
            Check(ok && result.accepted,"RESUME_CLOCK_NEW_ACK_LATER_TICK_NEW_CLOCK_COMPLETE");
         else if(m_job_kind[j]=="RESUME_FIRST")
         {
            m_ready=true;m_ready_result=result;m_ready_calls=m_job_broker[j].calls;Resume(m_job_stage[j]);
         }
         else if(m_job_kind[j]=="RESUME_COMPLETE")
         {
            Print("CONTINUATION_RESUME_DETAIL|",m_job_stage[j],"|",result.stage,"|",result.reason);
            Check(ok && result.accepted,"RESUME_"+m_job_stage[j]);
            if(m_job_stage[j]=="RELEASED")ReleasedAfterFinalization(j,ok,result,accepted);
         }
         else if(StringFind(m_job_kind[j],"BOUND_")==0)
         {
            const bool after_pending=StringFind(m_job_kind[j],"BOUND_PENDING_")==0;
            const bool mutated=StringFind(m_job_kind[j],"MUTATED")>=0;const int index=(after_pending ? 2 : 0)+(mutated ? 1 : 0);
            m_ready=true;m_ready_result=result;m_ready_calls=m_job_broker[j].calls;
            m_boundary_pass[index]=ReleaseBoundaryCase(after_pending,mutated,m_boundary_basis[index]);m_boundary_done[index]=true;
            const int base=after_pending ? 2 : 0;
            if(m_boundary_done[base] && m_boundary_done[base+1])
               Check(m_boundary_pass[base] && m_boundary_pass[base+1] && m_boundary_basis[base]!="" && m_boundary_basis[base]==m_boundary_basis[base+1],
                  after_pending ? "GOVERNANCE_RELEASE_DIFFERENTIAL_BOTH_CASES_REQUIRED" : "GOVERNANCE_PENDING_DIFFERENTIAL_BOTH_CASES_REQUIRED");
         }
         else Check(false,"UNCLASSIFIED_MULTI_TICK_JOB");
         delete m_job_core[j];test_stop_stage="";
      }
      for(int j=0;j<m_job_count;j++)if(m_job_active[j])return false;
      return true;
   }
public:
   SWV5S5_TestContinuationSuite(){m_started=false;m_finished=false;m_clock_partial_ready=false;m_clock_partial_time=0;
      m_job_count=0;m_last_job=-1;m_tick_id=0;m_main_completion_tick=0;m_ready=false;m_released_captured=false;
      ArrayInitialize(m_job_active,false);ArrayInitialize(m_boundary_done,false);ArrayInitialize(m_boundary_pass,false);
      m_passed=0;m_failed=0;m_copy="TEST_ONLY_MVP_CONTINUATION_FIXTURE.sqlite";}
   ~SWV5S5_TestContinuationSuite(){for(int j=0;j<m_job_count;j++)if(m_job_active[j])delete m_job_core[j];}
   bool ConfigureCopy(const string path)
   {if(StringFind(path,"TEST_ONLY_MVP_CONTINUATION_")!=0 || StringFind(path,"..")>=0 || StringFind(path,"\\")>=0 || StringFind(path,"/")>=0)return false;m_copy=path;return true;}
   bool Started(){return m_started;}
   void Start()
   {
      m_started=true;m_ns="58408af3c3381470aa50161762e4f1102eec5d214448495a79d732cd31d90d8c";
      // Immutable donor remains m_copy; every mutable clone uses a fresh prefix.
      // Bind the fresh preset's unique immutable seed to all mutable targets.
      // Exact paths can be checked absent before the operator authorizes A.
      m_run_prefix=m_copy+".RETEST";
      m_main=m_run_prefix+".MAIN.sqlite";ZeroMemory(m_input);
      m_input.path=m_main;m_input.namespace_digest=m_ns;m_input.continuation_id="TEST_ONLY_COMPLETE_NATIVE";
      m_input.approval_reference="FUSION-V5-DEMO-MVP-GOVERNANCE-APPROVED";
      m_input.proof_reference="PHASE-F-EVIDENCE-01B8B8F5819C804967461946D3481CF0D4E77767";
      m_input.trust_anchor_id="FUSION-V5-DEMO-TRUST-ANCHOR-V1";m_input.lease_seconds=3600;m_input.acknowledged=true;
      SWV5S5_MvpSqliteAuthorityStore store;SWV5S5_MvpAuthorityRow row;bool found=false;SWV5_InstanceLease lease;
      Check(Clone(m_main) && Open(m_main,store) && store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,row,found) && found &&
         SWV5S5_MvpDecodeOwnershipLeasePhysical(row.payload,lease),"COPY_REAL_DB_AND_LOAD_EXACT_OWNER");
      m_input.configured_owner=lease.fence.owner;store.Close();
      GovernanceClockBinding(false);GovernanceClockBinding(true);
      OperatorWindowAssertions();
      GovernanceRowNegatives();
      ClockDiagnosticNegatives();
      PeriodicEpochStructural();
      HeartbeatIdentityNegatives();OperationalRowNegatives();ReleaseBoundaryMutation(false);ReleaseBoundaryMutation(true);
      SWV5S5_MvpControlledDemoResult preflight;
      Check(NativePreflight(m_main,preflight) && !preflight.accepted && preflight.broker_submission_calls==0,"EXPIRED_COPY_NATIVE_PREFLIGHT_FAILS_CLOSED");
      Print("CONTINUATION_EXPIRED_COPY_PREFLIGHT|reason=",preflight.stop_reason,"|accepted=",preflight.accepted);
      SWV5S5_TestContinuationBroker broker;SWV5S5_MvpContinuationResult result;
      const bool ok=Execute(m_input,broker,result);m_t0=TimeCurrent();
      Print("CONTINUATION_COPY_PATH|",m_main);
      Print("CONTINUATION_DETAIL|",result.stage,"|",result.reason,"|T0=",(long)m_t0);
      if(Waiting(result))m_job_kind[m_last_job]="MAIN";
      else MainAssertions(ok,broker,result);
      for(int f=1;f<=18;f++)Negative(f,"NEGATIVE-"+IntegerToString(f));
      string stages[]={"CLOCK","HEARTBEAT","TRUST","GOVERNANCE","ACTIVE","FLAT","PENDING","RELEASED","INACTIVE"};
      for(int x=0;x<ArraySize(stages);x++)Resume(stages[x]);
      FinalizationNegatives();
      Check(Rows(m_main,m_rows),"LATER_PREFLIGHT_STORE_SNAPSHOT");
   }
   bool FinishLaterTick()
   {
      m_tick_id++;
      if(m_finished)return true;if(TimeCurrent()<=m_t0)return false;
      if(m_clock_partial_ready)
      {
         if(TimeCurrent()<=m_clock_partial_time)return false;
         SWV5S5_MvpContinuationInput next=m_input;next.path=m_clock_partial_path;next.continuation_id="RESUME-CLOCK";
         // TEST ONLY new acknowledgement fixture; never reuse the old op or
         // publication object. Production wrapper requires a physical fresh A.
         next.acknowledged=true;SWV5S5_TestContinuationBroker clock_broker;SWV5S5_MvpContinuationResult clock_result;
         const bool completed=Execute(next,clock_broker,clock_result);
         if(Waiting(clock_result))m_job_kind[m_last_job]="CLOCK_COMPLETE";
         else Check(completed && clock_result.accepted,"RESUME_CLOCK_NEW_ACK_LATER_TICK_NEW_CLOCK_COMPLETE");
         Print("CONTINUATION_RESUME_CLOCK|NEW_EVENT|old_at=",(long)m_clock_partial_time,"|new_at=",(long)TimeCurrent(),
            "|reason=",clock_result.reason,"|ack=TEST_ONLY_NEW_INVOCATION|broker_submission_calls=0");
         m_clock_partial_ready=false;
      }
      if(!FinishJobs())return false;
      if(m_tick_id<=m_main_completion_tick)return false;
      if(TimeCurrent()<=m_t0)return false;
      SWV5S5_MvpControlledDemoResult result;SWV5S5_MvpAuthorityRow after[];
      Check(NativePreflight(m_main,result) && result.accepted && result.stop_reason=="PREFLIGHT_COMPLETE_ZERO_SUBMISSION" && result.broker_submission_calls==0 &&
         !result.permit_committed && !result.claim_attempted && !result.claim_granted_now && !result.adapter_invoked_same_event,
         "LATER_NATIVE_TICK_PREFLIGHT_COMPLETE_ZERO_SUBMISSION");
      Print("CONTINUATION_NATIVE_LATER_TICK|T0=",(long)m_t0,"|T1=",(long)TimeCurrent(),"|reason=",result.stop_reason);
      Check(Rows(m_main,after) && SameRows(m_rows,after),"LATER_NATIVE_PREFLIGHT_ZERO_AUTHORITY_MUTATION");
      Check(test_forbidden_transport_calls==0,"COMPILED_TRANSPORT_TRAP_NEVER_REACHED");
      Print("CONTINUATION_SUMMARY|passed=",m_passed,"|failed=",m_failed,"|skipped=0|total=",m_passed+m_failed);
      m_finished=true;return true;
   }
};
#endif
