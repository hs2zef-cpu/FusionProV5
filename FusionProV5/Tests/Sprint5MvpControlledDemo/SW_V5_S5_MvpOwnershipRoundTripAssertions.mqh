#ifndef SW_V5_S5_MVP_OWNERSHIP_ROUND_TRIP_ASSERTIONS_MQH
#define SW_V5_S5_MVP_OWNERSHIP_ROUND_TRIP_ASSERTIONS_MQH

// OFFLINE TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

#include "SW_V5_S5_MvpControlledDemoAssertions.mqh"

const string SWV5S5_OWN_TEST_NAMESPACE="9191919191919191919191919191919191919191919191919191919191919191";
const string SWV5S5_OWN_TEST_FILE="mvp_controlled_demo_ownership.sqlite";

void SWV5S5_OwnDeleteDatabase(const string relative_path)
{
   FileDelete(relative_path,FILE_COMMON);
   FileDelete(relative_path+"-wal",FILE_COMMON);
   FileDelete(relative_path+"-shm",FILE_COMMON);
}

void SWV5S5_OwnFixture(SWV5_InstanceLease &lease,SWV5_ContractValidationContext &context)
{
   ZeroMemory(lease); ZeroMemory(context);
   lease.contract_version.contract_name=SWV5_PRODUCTION_CONTRACT_NAME;
   lease.contract_version.schema_version=SWV5_PRODUCTION_CONTRACT_VERSION;
   lease.contract_version.minimum_compatible_version=SWV5_PRODUCTION_MINIMUM_COMPATIBLE_VERSION;
   lease.contract_version.policy_id=SWV5_PRODUCTION_CONTRACT_POLICY;
   lease.fence.contract_version=lease.contract_version;
   lease.fence.ownership_namespace.account_login=123456;
   lease.fence.ownership_namespace.broker_identity="APPROVED-DEMO-BROKER";
   lease.fence.ownership_namespace.server="APPROVED-DEMO-SERVER";
   lease.fence.ownership_namespace.symbol=SWV5S5_MVP_SYMBOL;
   lease.fence.ownership_namespace.strategy_id=SWV5S5_MVP_PROFILE_ID;
   lease.fence.ownership_namespace.magic=SWV5_RUNTIME_STRATEGY_MAGIC;
   lease.fence.owner.key=lease.fence.ownership_namespace;
   lease.fence.owner.instance_id="DEMO-OWNER-เจ้าของ";
   lease.fence.owner.process_fingerprint="PROCESS-FINGERPRINT-001";
   lease.fence.owner.started_at=D'2026.09.20 00:00:00';
   lease.fence.lease_version=7;
   lease.fence.takeover_generation=3;
   lease.fence.fencing_token_digest="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
   lease.status=SWV5_LOCK_ACQUIRED;
   lease.store_revision="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
   lease.heartbeat_sequence=9;
   lease.clock_id="BROKER-SERVER-CLOCK";
   lease.clock_authority=SWV5_TIME_AUTHORITY_BROKER_SERVER;
   lease.acquired_clock_sequence=100;
   lease.heartbeat_clock_sequence=109;
   lease.expiry_clock_sequence=120;
   lease.acquired_at=D'2026.09.20 00:00:00';
   lease.heartbeat_at=D'2026.09.20 00:00:09';
   lease.expires_at=D'2026.09.20 00:00:20';
   SWV5S5_InitContractVersion(context.expected_version);
   context.clock_id=lease.clock_id;
   context.clock_authority=lease.clock_authority;
   context.clock_sequence=110;
   context.clock_time=D'2026.09.20 00:00:10';
   context.evaluation_sequence=110;
   context.price_tolerance=0.0000001;
   context.volume_tolerance=0.0000001;
}

bool SWV5S5_OwnPublish(const string relative_path,const SWV5_InstanceLease &lease,
                       SWV5S5_MvpAuthorityRow &row)
{
   SWV5S5_MvpSqliteAuthorityStore store;
   SWV5S5_MvpLeasePublicationAuthority publisher;
   SWV5S5_LeaseLivenessAuthorityView diagnostic; diagnostic.lease=lease;
   const bool projection_valid=SWV5S5_DeriveLeaseProjection(diagnostic);
   if(!store.Open(relative_path,SWV5S5_OWN_TEST_NAMESPACE))
   { Print("OWNERSHIP_DIAGNOSTIC|store_open=0|projection=",projection_valid,"|error=",GetLastError()); return false; }
   const bool published=publisher.Publish(store,lease,0,"","",0,lease.heartbeat_at,row);
   if(!published) Print("OWNERSHIP_DIAGNOSTIC|store_open=1|projection=",projection_valid,
      "|digest=",diagnostic.projection_digest,"|error=",GetLastError());
   store.Close(); return published;
}

bool SWV5S5_OwnReload(const string relative_path,const SWV5_OwnershipFence &expected_fence,
                      SWV5_InstanceLease &lease,SWV5S5_MvpAuthorityRow &row)
{
   SWV5S5_MvpSqliteAuthorityStore store;
   SWV5S5_MvpLeasePublicationAuthority reader;
   if(!store.Open(relative_path,SWV5S5_OWN_TEST_NAMESPACE)) return false;
   const bool loaded=reader.LoadCurrentLease(store,expected_fence.ownership_namespace,
                                              expected_fence,lease,row);
   store.Close(); return loaded;
}

bool SWV5S5_OwnRawUpdateOne(const string relative_path,const string column,const string value)
{
   const int database=DatabaseOpen(relative_path,DATABASE_OPEN_READWRITE|DATABASE_OPEN_COMMON);
   if(database==INVALID_HANDLE) return false;
   string sql;
   if(column=="store_revision") sql="UPDATE swv5_authority_rows SET store_revision=?1 WHERE domain_key=?2 AND record_key=?3;";
   else if(column=="payload") sql="UPDATE swv5_authority_rows SET payload=?1 WHERE domain_key=?2 AND record_key=?3;";
   else { DatabaseClose(database); return false; }
   const int statement=DatabasePrepare(database,sql);
   if(statement==INVALID_HANDLE) { DatabaseClose(database); return false; }
   ResetLastError();
   const bool bound=DatabaseBind(statement,0,value) &&
      DatabaseBind(statement,1,SWV5S5_MVP_DOMAIN_OWNERSHIP) &&
      DatabaseBind(statement,2,SWV5S5_MVP_OWNERSHIP_KEY);
   const bool row=bound && DatabaseRead(statement);
   const int error=GetLastError();
   DatabaseFinalize(statement); DatabaseClose(database);
   return row || (bound && error==ERR_DATABASE_NO_MORE_DATA);
}

bool SWV5S5_OwnRawUpdateDigestAndRevision(const string relative_path,const string digest,
                                          const string store_revision)
{
   const int database=DatabaseOpen(relative_path,DATABASE_OPEN_READWRITE|DATABASE_OPEN_COMMON);
   if(database==INVALID_HANDLE) return false;
   const int statement=DatabasePrepare(database,
      "UPDATE swv5_authority_rows SET payload_digest=?1,store_revision=?2 WHERE domain_key=?3 AND record_key=?4;");
   if(statement==INVALID_HANDLE) { DatabaseClose(database); return false; }
   ResetLastError();
   const bool bound=DatabaseBind(statement,0,digest) && DatabaseBind(statement,1,store_revision) &&
      DatabaseBind(statement,2,SWV5S5_MVP_DOMAIN_OWNERSHIP) &&
      DatabaseBind(statement,3,SWV5S5_MVP_OWNERSHIP_KEY);
   const bool row=bound && DatabaseRead(statement); const int error=GetLastError();
   DatabaseFinalize(statement); DatabaseClose(database);
   return row || (bound && error==ERR_DATABASE_NO_MORE_DATA);
}

bool SWV5S5_OwnMutatedPayloadFixture(const string relative_path,const SWV5_InstanceLease &original,
                                     const int mutation)
{
   SWV5S5_OwnDeleteDatabase(relative_path);
   SWV5S5_MvpAuthorityRow row;
   if(!SWV5S5_OwnPublish(relative_path,original,row)) return false;
   string payload=row.payload;
   if(mutation==1)
   {
      if(StringReplace(payload,"clock_id:s:19:BROKER-SERVER-CLOCK","")!=1) return false;
   }
   else if(mutation==2)
   {
      if(StringReplace(payload,"BROKER-SERVER-CLOCK","BROKER-SERVER-CLOKX")!=1) return false;
   }
   else if(mutation==3)
   {
      if(StringReplace(payload,"instance_id:s:32:DEMO-OWNER-เจ้าของ",
         "instance_id:s:31:DEMO-OWNER-เจ้าของ")!=1) return false;
   }
   else return false;
   return SWV5S5_OwnRawUpdateOne(relative_path,"payload",payload);
}

class SWV5S5_OwnershipBackedD6Port : public SWV5S5_ControlledDemoFakePort
{
public:
   string relative_store_path;
   string namespace_digest;
   SWV5_OwnershipKey expected_namespace;
   SWV5_OwnershipFence expected_fence;
   SWV5_ContractValidationContext current_context;
   SWV5_InstanceLease recovered_lease;
   SWV5S5_MvpAuthorityRow recovered_row;

   void Configure(const string path,const string persistence_namespace,
                  const SWV5_InstanceLease &expected_lease,
                  const SWV5_ContractValidationContext &context)
   {
      Reset(); relative_store_path=path; namespace_digest=persistence_namespace;
      expected_namespace=expected_lease.fence.ownership_namespace;
      expected_fence=expected_lease.fence; current_context=context;
      ZeroMemory(recovered_lease); ZeroMemory(recovered_row);
   }

   virtual bool ReloadAndReconcileD6(SWV5S5_MvpControlledDemoRecoveryEvidence &evidence)
   {
      recovery_calls++; ZeroMemory(evidence);
      SWV5S5_MvpControlledDemoD6OwnershipLoader loader;
      if(!loader.ReloadCurrent(relative_store_path,namespace_digest,expected_namespace,
         expected_fence,current_context,recovered_lease,recovered_row)) return false;
      evidence.store_schema_valid=true; evidence.ownership_reloaded_from_sqlite=true;
      evidence.ownership_current=true; evidence.exact_unresolved_claim_found=true;
      evidence.complete_claim_reloaded_from_sqlite=true; evidence.claim_granted_now=false;
      evidence.broker_observation_complete=true; evidence.execution_observation_complete=true;
      evidence.reconciliation_evaluated=true; evidence.reconciliation_published=true;
      evidence.exact_record_terminalized=true; evidence.terminal_readback_verified=true;
      evidence.request_correlation_id="CORR-D6-PERSISTED"; evidence.attempt_id="ATT-D6-PERSISTED";
      return true;
   }
};

void SWV5S5_RunOwnershipRoundTripAssertions(SWV5S5_ControlledDemoCollector &c)
{
   SWV5_InstanceLease original,reloaded; SWV5_ContractValidationContext context;
   SWV5S5_OwnFixture(original,context);
   SWV5S5_OwnDeleteDatabase(SWV5S5_OWN_TEST_FILE);
   SWV5S5_MvpAuthorityRow published,loaded_row;
   const bool published_ok=SWV5S5_OwnPublish(SWV5S5_OWN_TEST_FILE,original,published);
   SWV5S5_ControlledDemoRecord(c,"OWN-01-PUBLISH-COMPLETE-LEASE",published_ok&&published.payload!="");
   SWV5S5_ControlledDemoRecord(c,"OWN-02-PUBLISHER-CLOSED",published_ok);
   const bool reopened_ok=SWV5S5_OwnReload(SWV5S5_OWN_TEST_FILE,original.fence,reloaded,loaded_row);
   SWV5S5_ControlledDemoRecord(c,"OWN-03-FRESH-STORE-REOPEN",reopened_ok);
   SWV5S5_ControlledDemoRecord(c,"OWN-04-RELOAD-FROM-SQLITE-BYTES",reopened_ok&&loaded_row.payload==published.payload);
   SWV5S5_ControlledDemoRecord(c,"OWN-05-ALL-MATERIAL-FIELDS-EXACT",reopened_ok&&SWV5S5_MvpLeaseExact(original,reloaded));
   SWV5S5_LeaseLivenessAuthorityView projection; projection.lease=reloaded;
   const bool projection_ok=reopened_ok&&SWV5S5_DeriveLeaseProjection(projection);
   SWV5S5_ControlledDemoRecord(c,"OWN-06-PROJECTION-EQUALS-PAYLOAD-DIGEST",projection_ok&&projection.projection_digest==loaded_row.payload_digest);
   SWV5S5_ControlledDemoRecord(c,"OWN-07-ROW-STATE-EQUALS-LEASE",reopened_ok&&loaded_row.state==(int)reloaded.status);

   const string revision_file="mvp_controlled_demo_ownership_revision.sqlite";
   SWV5S5_OwnDeleteDatabase(revision_file); SWV5S5_MvpAuthorityRow mutation_row;
   bool mutation_ok=SWV5S5_OwnPublish(revision_file,original,mutation_row) &&
      SWV5S5_OwnRawUpdateOne(revision_file,"store_revision","corrupt-store-revision");
   SWV5_InstanceLease rejected; SWV5S5_MvpAuthorityRow rejected_row;
   SWV5S5_ControlledDemoRecord(c,"OWN-08-STORE-REVISION-CORRUPTION-REJECTED",mutation_ok&&
      !SWV5S5_OwnReload(revision_file,original.fence,rejected,rejected_row));

   const string digest_file="mvp_controlled_demo_ownership_digest.sqlite";
   SWV5S5_OwnDeleteDatabase(digest_file); mutation_ok=SWV5S5_OwnPublish(digest_file,original,mutation_row);
   const string corrupt_digest="cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";
   string matching_revision; SWV5S5_MvpSqliteAuthorityStore revision_store;
   mutation_ok=mutation_ok&&revision_store.Open(digest_file,SWV5S5_OWN_TEST_NAMESPACE)&&
      revision_store.DeriveStoreRevision(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,
         mutation_row.logical_revision,corrupt_digest,matching_revision);
   revision_store.Close();
   mutation_ok=mutation_ok&&SWV5S5_OwnRawUpdateDigestAndRevision(digest_file,corrupt_digest,matching_revision);
   SWV5S5_ControlledDemoRecord(c,"OWN-09-PROJECTION-DIGEST-CORRUPTION-REJECTED",mutation_ok&&
      !SWV5S5_OwnReload(digest_file,original.fence,rejected,rejected_row));

   const string scalar_file="mvp_controlled_demo_ownership_scalar.sqlite";
   mutation_ok=SWV5S5_OwnMutatedPayloadFixture(scalar_file,original,2);
   SWV5S5_ControlledDemoRecord(c,"OWN-10-SCALAR-CORRUPTION-REJECTED",mutation_ok&&
      !SWV5S5_OwnReload(scalar_file,original.fence,rejected,rejected_row));
   const string missing_file="mvp_controlled_demo_ownership_missing.sqlite";
   mutation_ok=SWV5S5_OwnMutatedPayloadFixture(missing_file,original,1);
   SWV5S5_ControlledDemoRecord(c,"OWN-11-MISSING-FIELD-REJECTED",mutation_ok&&
      !SWV5S5_OwnReload(missing_file,original.fence,rejected,rejected_row));
   const string utf_file="mvp_controlled_demo_ownership_utf.sqlite";
   mutation_ok=SWV5S5_OwnMutatedPayloadFixture(utf_file,original,3);
   SWV5S5_ControlledDemoRecord(c,"OWN-12-UTF8-LENGTH-CORRUPTION-REJECTED",mutation_ok&&
      !SWV5S5_OwnReload(utf_file,original.fence,rejected,rejected_row));

   SWV5_OwnershipFence wrong_fence=original.fence;
   wrong_fence.ownership_namespace.account_login++;
   SWV5S5_ControlledDemoRecord(c,"OWN-13-WRONG-NAMESPACE-REJECTED",!SWV5S5_OwnReload(
      SWV5S5_OWN_TEST_FILE,wrong_fence,rejected,rejected_row));
   SWV5_ContractValidationContext expired_context=context; expired_context.clock_time=original.expires_at;
   expired_context.clock_sequence=original.expiry_clock_sequence;
   SWV5S5_ControlledDemoRecord(c,"OWN-14-EXPIRED-NOT-CURRENT",reopened_ok&&
      !SWV5S5_MvpLeaseCurrentForClock(expired_context,original.fence,reloaded));
   SWV5S5_ControlledDemoRecord(c,"OWN-15-RELOAD-DOES-NOT-RENEW",reopened_ok&&
      reloaded.expires_at==original.expires_at && reloaded.heartbeat_at==original.heartbeat_at &&
      reloaded.heartbeat_sequence==original.heartbeat_sequence);

   SWV5S5_MvpControlledDemoInvocation invocation;
   SWV5S5_ControlledDemoInvocation(invocation,MODE_D6_RECOVER);
   SWV5S5_OwnershipBackedD6Port current_port;
   current_port.Configure(SWV5S5_OWN_TEST_FILE,SWV5S5_OWN_TEST_NAMESPACE,original,context);
   SWV5S5_ControlledDemoFakeBoundary current_boundary;
   SWV5S5_MvpControlledDemoRunner current_runner; SWV5S5_MvpControlledDemoResult d6_result;
   const bool d6_loaded=current_runner.Run(invocation,current_port,current_boundary,d6_result);
   SWV5S5_ControlledDemoRecord(c,"OWN-16-D6-USES-TYPED-PERSISTED-LEASE",d6_loaded&&
      SWV5S5_MvpLeaseExact(original,current_port.recovered_lease) &&
      current_port.recovered_row.payload==published.payload);
   SWV5S5_ControlledDemoRecord(c,"OWN-17-D6-CURRENT-ZERO-SUBMISSION",d6_loaded&&
      d6_result.recovery_complete && current_boundary.calls==0 &&
      current_runner.BrokerSubmissionCalls()==0 && current_port.claim_calls==0);

   SWV5S5_OwnershipBackedD6Port expired_port;
   expired_port.Configure(SWV5S5_OWN_TEST_FILE,SWV5S5_OWN_TEST_NAMESPACE,original,expired_context);
   SWV5S5_ControlledDemoFakeBoundary expired_boundary;
   SWV5S5_MvpControlledDemoRunner expired_runner;
   const bool expired_loaded=expired_runner.Run(invocation,expired_port,expired_boundary,d6_result);
   SWV5S5_ControlledDemoRecord(c,"OWN-18-D6-EXPIRED-FAILS-ZERO-SUBMISSION",!expired_loaded&&
      StringLen(expired_port.recovered_row.payload)==0 && expired_boundary.calls==0 &&
      expired_runner.BrokerSubmissionCalls()==0 && expired_port.claim_calls==0);
}

#endif // SW_V5_S5_MVP_OWNERSHIP_ROUND_TRIP_ASSERTIONS_MQH
