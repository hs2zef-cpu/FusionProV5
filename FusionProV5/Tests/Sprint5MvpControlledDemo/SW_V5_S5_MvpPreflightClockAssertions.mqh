#ifndef SW_V5_S5_MVP_PREFLIGHT_CLOCK_ASSERTIONS_MQH
#define SW_V5_S5_MVP_PREFLIGHT_CLOCK_ASSERTIONS_MQH
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER MUTATION.
// Called on actual later XAUUSD tester ticks, never by a fabricated clock.
class SWV5S5_TestPreflightClockSuite
{
private:
   string m_path,m_ns;
   datetime m_t0,m_t1;
   bool m_prepared,m_done;
   SWV5S5_MvpControlledDemoInvocation m_invocation;
   SWV5S5_MvpAuthorityRow m_before[];
   uchar m_bytes[];
   SWV5S5_MvpAuthorityRow m_clock_row;

   bool Bytes(const string path,uchar &bytes[])
   {
      const int f=FileOpen(path,FILE_READ|FILE_BIN|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(f==INVALID_HANDLE) return false;
      const uint size=(uint)FileSize(f); ArrayResize(bytes,(int)size);
      const uint read=FileReadArray(f,bytes,0,size); FileClose(f); return size>0 && read==size;
   }
   bool Unchanged(void)
   {
      SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpAuthorityRow rows[]; uchar bytes[];
      if(!store.OpenReadOnly(m_path,m_ns) || !store.ReadAllRows(rows) ||
         !SWV5S5_LaunchRowsEqual(m_before,rows) || !Bytes(m_path,bytes) || ArraySize(bytes)!=ArraySize(m_bytes)) return false;
      for(int i=0;i<ArraySize(bytes);i++) if(bytes[i]!=m_bytes[i]) return false;
      return true;
   }
   bool NoExecutionArtifacts(void)
   {
      SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpAuthorityRow rows[];
      if(!store.OpenReadOnly(m_path,m_ns) || !store.ReadAllRows(rows)) return false;
      for(int i=0;i<ArraySize(rows);i++)
      {
         // Governance/Basket setup also initializes an EMPTY physical request
         // set. Validate its payload, not an assumption that its row is absent.
         if(rows[i].domain_key==SWV5S5_MVP_DOMAIN_REQUEST_SET && rows[i].record_key==SWV5S5_MVP_REQUEST_SET_KEY)
         {
            SWV5S5_MvpRequestSetPhysicalState state;
            if(!SWV5S5_MvpDecodeRequestSetState(rows[i].payload,state) || ArraySize(state.view.requests)!=0) return false;
            continue;
         }
         // Accepted setup has existing GENESIS envelopes in these domains.
         // They are not Permit/Claim/Vector artifacts; full snapshot equality
         // separately proves they were neither added nor changed by preflight.
         if(rows[i].record_key!="GENESIS" &&
            (rows[i].domain_key==SWV5S5_MVP_DOMAIN_SUBMISSION || rows[i].domain_key==SWV5S5_MVP_DOMAIN_SUBMISSION_INDEX ||
            rows[i].domain_key==SWV5S5_MVP_DOMAIN_RECONCILIATION_PIN || rows[i].domain_key==SWV5S5_MVP_DOMAIN_RECONCILIATION ||
            rows[i].domain_key==SWV5S5_MVP_DOMAIN_REQUEST_SET)) return false;
      }
      return true;
   }
   bool Native(const SWV5S5_MvpControlledDemoInvocation &invocation,SWV5S5_MvpControlledDemoResult &result)
   {
      SWV5S5_MvpAttendedLaunch host;
      if(!host.Init(invocation,1)) return false;
      host.OnCurrentSymbolTick(); return host.ReadLastResult(result);
   }
   bool ChangeDeadline(const string path,const int domain_case)
   {
      // Fault injection is restricted to a private clone. Re-encode and digest
      // the WHOLE record: failure must be due to expiry, not bad integrity.
      if(StringFind(path,"TEST_ONLY")<0) return false;
      SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpAuthorityRow row,committed; bool found=false;
      const string domain=(domain_case==0 ? SWV5S5_MVP_DOMAIN_OWNERSHIP :
         (domain_case==1 ? SWV5S5_MVP_DOMAIN_PRODUCER_TRUST : SWV5S5_MVP_DOMAIN_RECONCILIATION_GOVERNANCE));
      const string key=(domain_case==0 ? SWV5S5_MVP_OWNERSHIP_KEY :
         (domain_case==1 ? "CURRENT" : SWV5S5_MVP_RECONCILIATION_GOVERNANCE_KEY));
      if(!store.Open(path,m_ns) || !store.ReadRow(domain,key,row,found) || !found) return false;
      string payload,digest;
      if(domain_case==0)
      {
         SWV5_InstanceLease lease; SWV5S5_LeaseLivenessAuthorityView view;
         if(!SWV5S5_MvpDecodeOwnershipLeasePhysical(row.payload,lease)) return false;
         lease.expires_at=TimeCurrent();
         // Preserve authority fence and issuance/liveness sequence.
         view.lease=lease;
         if(!SWV5S5_DeriveLeaseProjection(view) || !SWV5S5_MvpEncodeOwnershipLeasePhysical(lease,payload)) return false;
         digest=view.projection_digest;
      }
      else if(domain_case==1)
      {
         SWV5S5_ProducerTrustRecord trust; SWV5S5_ProducerTrustAnchor anchor; string op,auth;
         if(!SWV5S5_MvpDecodeProducerTrustPhysical(row.payload,trust,anchor,op,auth)) return false;
         trust.valid_until=TimeCurrent();
         if(!SWV5S5_DeriveProducerTrustDigest(trust,trust.record_digest) ||
            !SWV5S5_MvpEncodeProducerTrustPhysical(trust,anchor,op,auth,payload)) return false;
         digest=trust.record_digest;
      }
      else
      {
         SWV5S5_MvpReconciliationGovernanceBundle b;
         if(!SWV5S5_MvpDecodeGovernance(row.payload,b)) return false;
         b.valid_until=TimeCurrent();
         if(!SWV5S5_MvpGovernanceDigest(b,b.bundle_digest) ||
            !SWV5S5_MvpGovernanceValid(b,TimeCurrent()-1) || !SWV5S5_MvpGovernanceCanonical(b,true,payload)) return false;
         digest=b.bundle_digest;
      }
      if(!store.CompareAndSet(domain,key,row.logical_revision,row.store_revision,row.payload_digest,row.state,
         row.logical_revision+1,row.state,digest,payload,TimeCurrent(),committed)) return false;
      // Independent authoritative readback must still be integrity-valid.
      // Its deadline alone switches from valid at now-1 to invalid at now.
      if(domain_case==0)
      {
         SWV5_InstanceLease lease,loaded; SWV5S5_MvpLeasePublicationAuthority owner;
         SWV5S5_MvpLeaseClockAuthority clock; SWV5S5_MvpLeaseClockObservation lineage;
         SWV5_ContractValidationContext context;
         if(!SWV5S5_MvpDecodeOwnershipLeasePhysical(payload,lease) ||
            !owner.LoadCurrentLease(store,lease.fence.ownership_namespace,lease.fence,loaded,row) ||
            !clock.ConfigureReadOnly(path,m_ns) || !clock.LoadStored(lineage,row,found) || !found) return false;
         SWV5S5_MvpContextFromClock(lineage,context); context.clock_time=TimeCurrent()-1;
         const bool prior=SWV5S5_MvpLeaseCurrentForClock(context,loaded.fence,loaded);
         context.clock_time=TimeCurrent();
         return prior && !SWV5S5_MvpLeaseCurrentForClock(context,loaded.fence,loaded);
      }
      if(domain_case==1)
      {
         SWV5S5_MvpManualProducerTrustProvisioner owner; SWV5S5_ProducerTrustRecord trust;
         SWV5S5_ProducerTrustAnchor anchor; string op,auth;
         return owner.ConfigureReadOnly(path,m_ns) && owner.LoadCurrent(trust,anchor,op,auth,found) && found &&
            trust.valid_from<=TimeCurrent()-1 && trust.valid_until==TimeCurrent();
      }
      SWV5S5_MvpReconciliationGovernanceAuthority owner; SWV5S5_MvpReconciliationGovernanceBundle b,loaded;
      return SWV5S5_MvpDecodeGovernance(payload,b) && owner.ConfigureReadOnly(path,m_ns) &&
         owner.Load(TimeCurrent()-1,b.profile,loaded,row,found) && found && !SWV5S5_MvpGovernanceValid(loaded,TimeCurrent());
   }
   bool Clone(const string path)
   {
      if(StringFind(path,"TEST_ONLY")<0) return false;
      FileDelete(path,FILE_COMMON); FileDelete(path+"-wal",FILE_COMMON); FileDelete(path+"-shm",FILE_COMMON);
      return FileCopy(m_path,FILE_COMMON,path,FILE_COMMON|FILE_REWRITE);
   }

public:
   SWV5S5_TestPreflightClockSuite(void)
   { m_path="mvp_preflight_clock_TEST_ONLY_private.sqlite"; m_t0=0; m_t1=0; m_prepared=false; m_done=false; }
   bool Done(void) const { return m_done; }
   void Prepare(SWV5S5_MvpD1Collector &c,const SWV5S5_MvpControlledDemoInvocation &invocation)
   {
      m_invocation=invocation; m_invocation.mode=MODE_PREFLIGHT;
      m_invocation.source_head=SWV5S5_MVP_ATTENDED_BUILT_SOURCE;
      m_invocation.evidence_relative_path="TEST_ONLY_preflight_clock_diagnostic.log";
      m_ns=invocation.persistence_namespace_identity;
      FileDelete(m_path,FILE_COMMON); FileDelete(m_path+"-wal",FILE_COMMON); FileDelete(m_path+"-shm",FILE_COMMON);
      SWV5S5_MvpSqliteAuthorityStore store;
      m_prepared=SWV5S5_TestLaunchCheckpoint(invocation.relative_store_path) &&
         FileCopy(invocation.relative_store_path,FILE_COMMON,m_path,FILE_COMMON|FILE_REWRITE) &&
         store.OpenReadOnly(m_path,m_ns) && store.ReadAllRows(m_before) && Bytes(m_path,m_bytes);
      m_invocation.relative_store_path=m_path;
      SWV5S5_MvpLeaseClockAuthority clock; SWV5S5_MvpLeaseClockObservation lineage; ZeroMemory(lineage); bool found=false;
      m_prepared=m_prepared && clock.ConfigureReadOnly(m_path,m_ns) && clock.LoadStored(lineage,m_clock_row,found) && found;
      m_t0=lineage.observed_at;
      Print("PREFLIGHT_CLOCK_SETUP|prepared=",m_prepared,"|T0=",(long)m_t0,"|rows=",ArraySize(m_before),"|bytes=",ArraySize(m_bytes),"|error=",GetLastError());
      SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-01",m_prepared && NoExecutionArtifacts());
      SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-02",m_prepared && m_t0==TimeCurrent() && lineage.clock_sequence==m_clock_row.logical_revision);
   }
   void OnTick(SWV5S5_MvpD1Collector &c)
   {
      if(m_done || TimeCurrent()<=m_t0 || (m_t1>0 && TimeCurrent()<=m_t1)) return;
      MqlTick tick; const bool quote=SymbolInfoTick(_Symbol,tick);
      m_invocation.protective_stop_price=tick.ask-2.0; m_invocation.optional_take_profit_price=0.0;
      m_invocation.requested_price=tick.ask+10.0; // remains non-authoritative
      SWV5S5_MvpControlledDemoResult r; ZeroMemory(r);
      const bool read=m_prepared && quote && Native(m_invocation,r);
      const bool pass=read && r.accepted && r.stop_reason=="PREFLIGHT_COMPLETE_ZERO_SUBMISSION" &&
         !r.claim_attempted && !r.claim_granted_now && !r.permit_committed && r.broker_submission_calls==0;
      Print("PREFLIGHT_CLOCK_NATIVE|T0=",(long)m_t0,"|T1=",(long)m_t1,"|now=",(long)TimeCurrent(),
         "|stop=",r.stop_reason,"|accepted=",r.accepted,"|broker_submission_calls=",r.broker_submission_calls);
      if(m_t1==0)
      {
         m_t1=TimeCurrent();
         SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-03",m_prepared && m_t1>m_t0);
         SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-04",read);
         SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-05",pass);
         SWV5S5_MvpLeaseClockAuthority clock; SWV5S5_MvpLeaseClockObservation lineage; SWV5S5_MvpAuthorityRow row; bool found=false;
         SWV5S5_MvpAuthorityRow a[1],b[1]; a[0]=m_clock_row;
         const bool loaded=clock.ConfigureReadOnly(m_path,m_ns) && clock.LoadStored(lineage,row,found) && found;
         b[0]=row;
         SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-06",loaded && lineage.observed_at==m_t0 && SWV5S5_LaunchRowsEqual(a,b));
         SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-07",Unchanged());
         return;
      }
      SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-08",TimeCurrent()>m_t1 && pass);
      SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-09",Unchanged());
      for(int n=0;n<3;n++)
      {
         const string path="mvp_preflight_clock_TEST_ONLY_expiry_"+IntegerToString(n)+".sqlite";
         const bool injected=Clone(path) && ChangeDeadline(path,n) && SWV5S5_TestLaunchCheckpoint(path);
         SWV5S5_MvpControlledDemoInvocation bad=m_invocation; bad.relative_store_path=path;
         SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpAuthorityRow before[],after[];
         const bool snap=store.OpenReadOnly(path,m_ns) && store.ReadAllRows(before);
         SWV5S5_MvpControlledDemoResult rejected; const bool got=Native(bad,rejected);
         const string expected=(n==0 ? "SEED_CURRENT_OWNERSHIP_MISSING_OR_STALE" :
            (n==1 ? "PREFLIGHT_TRUST_EXPIRED_OR_NOT_AUTHORIZED" : "PREFLIGHT_GOVERNANCE_MISSING_INVALID_OR_EXPIRED"));
         Print("PREFLIGHT_CLOCK_EXPIRY|case=",n,"|stop=",rejected.stop_reason);
         SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-"+IntegerToString(10+n),injected && snap && got && !rejected.accepted &&
            rejected.stop_reason==expected && rejected.broker_submission_calls==0 && !rejected.claim_attempted &&
            store.ReadAllRows(after) && SWV5S5_LaunchRowsEqual(before,after));
      }
      for(int n=0;n<3;n++)
      {
         SWV5S5_MvpControlledDemoInvocation bad=m_invocation;
         if(n==0) bad.expected_broker_identity+="_WRONG";
         if(n==1) bad.expected_server+="_WRONG";
         if(n==2) bad.expected_demo_account_login++;
         SWV5S5_MvpControlledDemoResult rejected;
         SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-13-"+IntegerToString(n),Native(bad,rejected) && !rejected.accepted &&
            rejected.stop_reason=="PROFILE_FAIL_CLOSED" && rejected.broker_submission_calls==0 && Unchanged());
      }
      for(int n=0;n<2;n++)
      {
         const string path="mvp_preflight_clock_TEST_ONLY_clock_fault_"+IntegerToString(n)+".sqlite";
         bool injected=Clone(path);
         if(n==1) injected=injected && SWV5S5_TestLaunchDeleteRow(path,m_ns,SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_CLOCK_KEY);
         else
         {
            SWV5S5_MvpSqliteAuthorityStore fault; SWV5S5_MvpAuthorityRow committed;
            injected=injected && fault.Open(path,m_ns) && fault.CompareAndSet(m_clock_row.domain_key,m_clock_row.record_key,
               m_clock_row.logical_revision,m_clock_row.store_revision,m_clock_row.payload_digest,m_clock_row.state,
               m_clock_row.logical_revision+1,m_clock_row.state,m_clock_row.payload_digest,"CORRUPT_TEST_ONLY",TimeCurrent(),committed);
         }
         SWV5S5_MvpControlledDemoInvocation bad=m_invocation; bad.relative_store_path=path;
         SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpAuthorityRow before[],after[];
         const bool snap=store.OpenReadOnly(path,m_ns) && store.ReadAllRows(before);
         SWV5S5_MvpControlledDemoResult rejected;
         SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-"+IntegerToString(14+n),injected && snap && Native(bad,rejected) &&
            !rejected.accepted && rejected.stop_reason=="PREFLIGHT_PERSISTED_CLOCK_MISSING_OR_INVALID_ZERO_AUTHORITY_MUTATION" &&
            rejected.broker_submission_calls==0 && store.ReadAllRows(after) && SWV5S5_LaunchRowsEqual(before,after));
      }
      SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-16",NoExecutionArtifacts() && Unchanged());
      SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-17",pass && r.broker_submission_calls==0);
      // Actual native host uses the unchanged Runner: its only boundary call is
      // after the PREFLIGHT return. This is path/count proof, not an OS hook.
      SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-18",pass && !r.adapter_invoked_same_event && !r.synchronous_result.invocation_attempted);
      // An ephemeral seed must reject ALL write-capable port entry points.
      SWV5S5_MvpLeaseClockAuthority clock; SWV5S5_MvpLeaseClockObservation lineage; SWV5S5_MvpAuthorityRow row; bool found=false;
      SWV5S5_MvpAttendedAuthoritySeedBuilder builder; SWV5S5_MvpMt5ReadOnlyPlatform platform;
      SWV5S5_F_BrokerPlatformAdapter adapter(SWV5S5_MVP_BROKER_READ_PATH,"TEST_ONLY_PREFLIGHT",SWV5S5_MVP_BROKER_SEQUENCE_AUTHORITY,1,1);
      SWV5S5_F_AdapterEnvironment environment; SWV5S5_MvpControlledDemoAuthoritySeed seed; string reason;
      SWV5S5_MvpControlledDemoAuthorityPort port; SWV5S5_MvpBrokerEvidenceStore evidence;
      SWV5S5_MvpSqliteAuthorityStore readonly;
      const bool seeded=clock.ConfigureReadOnly(m_path,m_ns) && clock.LoadStored(lineage,row,found) && found &&
         adapter.ObserveEnvironment(_Symbol,environment) && builder.LoadBaseForReadOnlyPreflight(m_invocation,lineage,platform,environment,seed,reason) &&
         readonly.OpenReadOnly(m_path,m_ns) && builder.CompleteIncreasing(readonly,seed,reason) &&
         SWV5S5_LaunchDecision(TimeCurrent(),1,seed.engine_input,seed.decision) && seed.decision.action==SWV5_ACTION_BUY &&
         seed.preflight_lineage.observed_at==m_t0 && seed.preflight_now.observed_at==TimeCurrent() &&
         seed.context.clock_sequence==lineage.clock_sequence && port.Configure(m_path,m_ns,seed,GetPointer(platform),GetPointer(evidence));
      SWV5S5_MvpControlledDemoPreflightEvidence pre; SWV5S5_MvpControlledDemoRecoveryEvidence recovery;
      SWV5S5_F_AdapterSubmissionCommand command; ISWV5S5FBrokerEvidenceStore *store_pointer=NULL; bool granted=false;
      SWV5S5_MvpControlledDemoInvocation execution=m_invocation; execution.mode=MODE_D1_BUY;
      SWV5S5_MvpD1Record(c,"PREFLIGHT-CLOCK-NO-AUTHORITY-ESCAPE",seeded &&
         !port.PrepareD1AuthorityPath(execution,1,pre) && !port.PreparePermitSemantics() && !port.CommitPermitPhysical() &&
         !port.CollectAdmissionSameEvent() && !port.ClaimPhysicalNow(granted) && !granted &&
         !port.ReloadAndReconcileD6(recovery) && !port.BuildAdapterCommand(command,store_pointer) && Unchanged());
      m_done=true;
   }
};
#endif
