#ifndef SW_V5_S5_MVP_AUTHORITY_ROUND_TRIP_ASSERTIONS_MQH
#define SW_V5_S5_MVP_AUTHORITY_ROUND_TRIP_ASSERTIONS_MQH

// REAL MQL TEST ONLY / NO BROKER MUTATION / NO SUBMISSION API.

#include "SW_V5_S5_MvpRuntimeAssertions.mqh"

bool SWV5S5_MvpPhysicalRecordEqual(const SWV5S5_SubmissionAuthorityRecord &left,
                                   const SWV5S5_SubmissionAuthorityRecord &right)
{
   string a,b;
   return SWV5S5_MvpEncodeSubmissionPhysical(left,a) &&
      SWV5S5_MvpEncodeSubmissionPhysical(right,b) && a==b;
}

bool SWV5S5_MvpPhysicalTrustEqual(const SWV5S5_ProducerTrustRecord &left,
                                  const SWV5S5_ProducerTrustRecord &right)
{
   string a,b;
   return SWV5S5_MvpCodecEncode_SWV5S5_ProducerTrustRecord(left,a) &&
      SWV5S5_MvpCodecEncode_SWV5S5_ProducerTrustRecord(right,b) && a==b;
}

bool SWV5S5_MvpRewriteTrustPayload(SWV5S5_MvpSqliteAuthorityStore &store,
                                   const string payload,const string digest,
                                   const datetime now)
{
   SWV5S5_MvpAuthorityRow current,committed; bool found=false;
   if(!store.ReadRow(SWV5S5_MVP_DOMAIN_PRODUCER_TRUST,"CURRENT",current,found) || !found) return false;
   return store.CompareAndSet(SWV5S5_MVP_DOMAIN_PRODUCER_TRUST,"CURRENT",
      current.logical_revision,current.store_revision,current.payload_digest,current.state,
      current.logical_revision+1,current.state,digest,payload,now,committed);
}

bool SWV5S5_MvpBuildPhysicalClaim(const string filename,const string namespace_digest,
                                  SWV5_ContractValidationContext &context,
                                  SWV5S5_InvocationClaimCommand &claim_command,
                                  SWV5S5_InvocationClaimResult &claim_result)
{
   FileDelete(filename,FILE_COMMON);
   if(!SWV5S5_BuildClaimFixture(context,claim_command)) return false;
   SWV5S5_SubmissionAuthorityIndexEntry empty_index[]; ArrayResize(empty_index,0);
   SWV5S5_PermitPreparationCommand permit_command; ZeroMemory(permit_command);
   SWV5S5_InitContractVersion(permit_command.contract_version);
   if(!SWV5S5_DeriveSubmissionIndexDigest(empty_index,permit_command.expected_index_digest)) return false;
   permit_command.proposed_permit=claim_command.expected_authority_record.permit;
   if(!SWV5S5_DerivePermitPreparationCommandDigest(permit_command,permit_command.command_digest)) return false;
   SWV5S5_PermitPreparationResult prepared,authoritative;
   if(!SWV5S5_MvpPreparePermitCommit(context,empty_index,permit_command,
      permit_command.proposed_permit.producer_trust,claim_command.admission_proof.trust_anchor,
      claim_command.admission_proof.trust_scope,claim_command.admission_proof.accepted_ingress,prepared)) return false;
   SWV5S5_MvpSubmissionPermitAuthority permit_authority;
   if(!permit_authority.Configure(filename,namespace_digest) || !permit_authority.StagePrepared(prepared) ||
      !permit_authority.TryCommitPermit(permit_command,empty_index,authoritative)) return false;
   SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpAuthorityRow ownership_row;
   SWV5S5_LeaseLivenessAuthorityView lease_view; lease_view.lease=claim_command.current_ownership_lease;
   string lease_payload;
   if(!store.Open(filename,namespace_digest) || !SWV5S5_DeriveLeaseProjection(lease_view) ||
      !SWV5S5_CanonicalString("lease_projection",lease_view.projection_digest,lease_payload) ||
      !store.CompareAndSet(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,0,"","",0,1,
         (int)claim_command.current_ownership_lease.status,lease_view.projection_digest,lease_payload,
         context.clock_time,ownership_row)) return false;
   store.Close();
   claim_command.expected_authority_record=authoritative.proposed_record;
   claim_command.expected_authority_revision=authoritative.proposed_record.authority_revision;
   claim_command.expected_authority_digest=authoritative.proposed_record.durable_record_digest;
   if(!SWV5S5_DeriveClaimId(claim_command,claim_command.claim_id) ||
      !SWV5S5_DeriveClaimCommandDigest(claim_command,claim_command.command_digest)) return false;
   SWV5S5_InvocationClaimTransition transition;
   if(!SWV5S5_PrepareInvocationClaimTransition(context,SWV5S5_TEST_RISK,claim_command,transition)) return false;
   SWV5S5_MvpInvocationClaimAuthority claim_authority;
   return claim_authority.Configure(filename,namespace_digest) && claim_authority.StagePrepared(transition) &&
      claim_authority.TryClaimInvocation(claim_command,claim_result) && claim_result.claim_granted_now;
}

bool SWV5S5_MvpCorruptSubmissionRow(const string filename,const string namespace_digest,
                                    const SWV5S5_SubmissionAuthorityRecord &record,
                                    const string payload,const string payload_digest,
                                    const int proposed_state,const datetime now)
{
   string key,correlation_id,attempt_id;
   SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpAuthorityRow current,committed; bool found=false;
   if(!SWV5S5_MvpSubmissionRecordIdentity(record,correlation_id,attempt_id) ||
      !SWV5S5_MvpSubmissionRecordKey(correlation_id,attempt_id,key) || !store.Open(filename,namespace_digest) ||
      !store.ReadRow(SWV5S5_MVP_DOMAIN_SUBMISSION,key,current,found) || !found) return false;
   const bool written=store.CompareAndSet(SWV5S5_MVP_DOMAIN_SUBMISSION,key,current.logical_revision,
      current.store_revision,current.payload_digest,current.state,current.logical_revision+1,proposed_state,
      payload_digest,payload,now,committed);
   store.Close(); return written;
}

bool SWV5S5_MvpRawRewriteRow(const string filename,const string namespace_digest,
                             const string domain_key,const string record_key,
                             const ulong logical_revision,const string store_revision,
                             const int state,const string payload_digest,const string payload)
{
   const int database=DatabaseOpen(filename,DATABASE_OPEN_READWRITE|DATABASE_OPEN_CREATE|DATABASE_OPEN_COMMON);
   if(database==INVALID_HANDLE) return false;
   const int statement=DatabasePrepare(database,
      "UPDATE swv5_authority_rows SET logical_revision=?1,store_revision=?2,state=?3,payload_digest=?4,payload=?5 "
      "WHERE namespace_digest=?6 AND domain_key=?7 AND record_key=?8;");
   if(statement==INVALID_HANDLE) { DatabaseClose(database); return false; }
   const bool bound=DatabaseBind(statement,0,(long)logical_revision) && DatabaseBind(statement,1,store_revision) &&
      DatabaseBind(statement,2,(long)state) && DatabaseBind(statement,3,payload_digest) &&
      DatabaseBind(statement,4,payload) && DatabaseBind(statement,5,namespace_digest) &&
      DatabaseBind(statement,6,domain_key) && DatabaseBind(statement,7,record_key);
   ResetLastError();
   const bool executed=bound && (DatabaseRead(statement) || GetLastError()==ERR_DATABASE_NO_MORE_DATA);
   DatabaseFinalize(statement); DatabaseClose(database); return executed;
}

void SWV5S5_RunMvpAuthorityRoundTripAssertions(SWV5S5_MvpTestCollector &c)
{
   ZeroMemory(c); c.signature=1469598103934665603;
   const string ns="3333333333333333333333333333333333333333333333333333333333333333";
   const string trust_file="mvp_authority_trust_rtp1.sqlite";
   const string submission_file="mvp_authority_submission_rtp1.sqlite";
   FileDelete(trust_file,FILE_COMMON); FileDelete(submission_file,FILE_COMMON);

   SWV5_ContractValidationContext context; SWV5S5_InvocationClaimCommand fixture_claim;
   const bool fixture_ok=SWV5S5_BuildClaimFixture(context,fixture_claim);

   SWV5_ContractValidationContext trust_context=context;
   trust_context.clock_id="BROKER-SERVER-CLOCK";
   trust_context.clock_authority=SWV5_TIME_AUTHORITY_BROKER_SERVER;

   SWV5S5_ProducerTrustAnchor anchor=fixture_claim.admission_proof.trust_anchor;
   anchor.trust_anchor_id="MVP-TRUST-ANCHOR-ทดสอบ";
   anchor.current_authority_record_id="MVP-TRUST-ROUNDTRIP-1";
   anchor.current_authority_generation=7;
   SWV5S5_ProducerTrustScope scope=fixture_claim.admission_proof.trust_scope;
   scope.producer_component="DECISION"; scope.producer_instance=SWV5S5_MVP_PRODUCER_INSTANCE;
   scope.producer_epoch=9; scope.symbol=SWV5S5_MVP_SYMBOL;
   scope.persistence_namespace=fixture_claim.expected_authority_record.permit.persistence_namespace;
   scope.publication_clock_id=trust_context.clock_id;
   scope.publication_clock_authority=trust_context.clock_authority;
   SWV5S5_MvpOperatorInvocation invocation;
   invocation.operator_id="MVP-OPERATOR-ผู้ทดสอบ"; invocation.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
   invocation.authentication_reference="MVP-AUTH-อ้างอิง"; invocation.authenticated_at=trust_context.clock_time;

   SWV5S5_ProducerTrustRecord written_trust;
   SWV5S5_MvpManualProducerTrustProvisioner *writer=new SWV5S5_MvpManualProducerTrustProvisioner;
   const bool trust_written=CheckPointer(writer)!=POINTER_INVALID && writer.Configure(trust_file,ns) &&
      writer.Provision(invocation,anchor,scope,trust_context.clock_time,written_trust);
   delete writer;
   SWV5S5_MvpRecord(c,"RTP-A-TRUST-PROVISION-COMPLETE",trust_written);

   SWV5S5_ProducerTrustRecord loaded_trust; SWV5S5_ProducerTrustAnchor loaded_anchor;
   string loaded_operator,loaded_auth; bool trust_found=false;
   SWV5S5_MvpManualProducerTrustProvisioner *reader=new SWV5S5_MvpManualProducerTrustProvisioner;
   const bool trust_reopened=trust_written && CheckPointer(reader)!=POINTER_INVALID && reader.Configure(trust_file,ns) &&
      reader.LoadCurrent(loaded_trust,loaded_anchor,loaded_operator,loaded_auth,trust_found);
   delete reader;
   SWV5S5_MvpRecord(c,"RTP-B-TRUST-CLOSE-REOPEN",trust_reopened && trust_found);
   SWV5S5_MvpRecord(c,"RTP-C-TRUST-COMPLETE-TYPED-EQUALITY",trust_reopened &&
      SWV5S5_MvpPhysicalTrustEqual(written_trust,loaded_trust));
   SWV5S5_MvpRecord(c,"RTP-D-TRUST-ANCHOR-ROUNDTRIP",trust_reopened &&
      loaded_anchor.trust_anchor_id==anchor.trust_anchor_id &&
      loaded_anchor.current_authority_record_id==anchor.current_authority_record_id &&
      loaded_anchor.current_authority_generation==anchor.current_authority_generation);
   SWV5S5_MvpRecord(c,"RTP-E-TRUST-OPERATOR-REFERENCES",loaded_operator==invocation.operator_id &&
      loaded_auth==invocation.authentication_reference);
   SWV5S5_MvpRecord(c,"RTP-F-TRUST-EMPTY-SUPERSEDING",loaded_trust.superseding_record_id=="" &&
      loaded_trust.superseding_generation==0);
   string trust_digest; const bool trust_digest_ok=SWV5S5_DeriveProducerTrustDigest(loaded_trust,trust_digest) &&
      trust_digest==loaded_trust.record_digest;
   SWV5S5_MvpRecord(c,"RTP-G-TRUST-DIGEST-REDERIVED",trust_digest_ok);

   SWV5S5_MvpSqliteAuthorityStore trust_store; SWV5S5_MvpAuthorityRow trust_row; bool trust_row_found=false;
   const bool raw_trust=trust_store.Open(trust_file,ns) &&
      trust_store.ReadRow(SWV5S5_MVP_DOMAIN_PRODUCER_TRUST,"CURRENT",trust_row,trust_row_found) && trust_row_found;
   string corrupt=trust_row.payload;
   const int generation_at=StringFind(corrupt,"authority_generation:u:1:7");
   if(generation_at>=0) StringSetCharacter(corrupt,generation_at+StringLen("authority_generation:u:1:"),'8');
   SWV5S5_ProducerTrustRecord rejected_trust; SWV5S5_ProducerTrustAnchor rejected_anchor;
   string rejected_operator,rejected_auth; bool rejected_found=false;
   const bool field_corruption_written=raw_trust && generation_at>=0 &&
      SWV5S5_MvpRewriteTrustPayload(trust_store,corrupt,trust_row.payload_digest,trust_context.clock_time);
   SWV5S5_MvpManualProducerTrustProvisioner corrupt_reader;
   const bool field_corruption_rejected=field_corruption_written && corrupt_reader.Configure(trust_file,ns) &&
      !corrupt_reader.LoadCurrent(rejected_trust,rejected_anchor,rejected_operator,rejected_auth,rejected_found);
   SWV5S5_MvpRecord(c,"RTP-H-TRUST-ONE-FIELD-CORRUPTION",field_corruption_rejected);
   const bool trust_restored=field_corruption_rejected &&
      SWV5S5_MvpRewriteTrustPayload(trust_store,trust_row.payload,trust_row.payload_digest,trust_context.clock_time);

   string digest_corrupt=trust_row.payload;
   const int digest_at=StringFind(digest_corrupt,written_trust.record_digest);
   if(digest_at>=0) StringSetCharacter(digest_corrupt,digest_at,
      (StringGetCharacter(digest_corrupt,digest_at)=='a' ? 'b' : 'a'));
   const bool digest_corruption_written=trust_restored && digest_at>=0 &&
      SWV5S5_MvpRewriteTrustPayload(trust_store,digest_corrupt,trust_row.payload_digest,trust_context.clock_time);
   const bool digest_corruption_rejected=digest_corruption_written && corrupt_reader.Configure(trust_file,ns) &&
      !corrupt_reader.LoadCurrent(rejected_trust,rejected_anchor,rejected_operator,rejected_auth,rejected_found);
   SWV5S5_MvpRecord(c,"RTP-I-TRUST-DIGEST-CORRUPTION",digest_corruption_rejected);
   const bool trust_restored_again=digest_corruption_rejected &&
      SWV5S5_MvpRewriteTrustPayload(trust_store,trust_row.payload,trust_row.payload_digest,trust_context.clock_time);
   const string missing_field=StringSubstr(trust_row.payload,0,StringLen(trust_row.payload)-1);
   const bool missing_written=trust_restored_again &&
      SWV5S5_MvpRewriteTrustPayload(trust_store,missing_field,trust_row.payload_digest,trust_context.clock_time);
   const bool missing_rejected=missing_written && corrupt_reader.Configure(trust_file,ns) &&
      !corrupt_reader.LoadCurrent(rejected_trust,rejected_anchor,rejected_operator,rejected_auth,rejected_found);
   SWV5S5_MvpRecord(c,"RTP-J-TRUST-MISSING-FIELD",missing_rejected);
   SWV5S5_IngressEnvelope trust_ingress=fixture_claim.admission_proof.accepted_ingress;
   trust_ingress.producer.authority_record_id=loaded_trust.authority_record_id;
   trust_ingress.producer.authority_generation=loaded_trust.authority_generation;
   trust_ingress.producer.producer_component=loaded_trust.producer_component;
   trust_ingress.producer.producer_instance=loaded_trust.producer_instance;
   trust_ingress.producer.producer_epoch=loaded_trust.producer_epoch;
   trust_ingress.snapshot.symbol=loaded_trust.symbol; trust_ingress.snapshot.timeframe=loaded_trust.timeframe;
   trust_ingress.snapshot.execution_mode=loaded_trust.execution_mode;
   trust_ingress.publication.clock_id=loaded_trust.clock_id;
   trust_ingress.publication.clock_authority=loaded_trust.clock_authority;
   SWV5S5_DeriveIngressIdentityAndDigest(trust_ingress,trust_ingress.ingress_identity,trust_ingress.payload_digest);
   SWV5S5_ProducerTrustScope loaded_scope=scope; loaded_scope.ingress_identity=trust_ingress.ingress_identity;
   SWV5S5_ValidationResult valid_trust_result,wrong_generation_result;
   SWV5S5_ProducerTrustAnchor wrong_generation_anchor=loaded_anchor;
   wrong_generation_anchor.current_authority_generation++;
   const bool trust_baseline_valid=SWV5S5_ValidateProducerTrust(trust_context,loaded_trust,loaded_anchor,loaded_scope,
      trust_ingress,valid_trust_result);
   const bool wrong_generation_rejected=!SWV5S5_ValidateProducerTrust(trust_context,loaded_trust,
      wrong_generation_anchor,loaded_scope,trust_ingress,wrong_generation_result);
   SWV5S5_MvpRecord(c,"RTP-K-TRUST-WRONG-GENERATION",trust_baseline_valid && wrong_generation_rejected);
   trust_store.Close();

   SWV5S5_SubmissionAuthorityRecord committed=fixture_claim.expected_authority_record,decoded_committed;
   string committed_payload;
   const bool committed_roundtrip=fixture_ok && SWV5S5_MvpEncodeSubmissionPhysical(committed,committed_payload) &&
      SWV5S5_MvpDecodeSubmissionPhysical(committed_payload,decoded_committed);
   SWV5S5_MvpRecord(c,"RTP-L-COMMITTED-COMPLETE-ROUNDTRIP",committed_roundtrip &&
      SWV5S5_MvpPhysicalRecordEqual(committed,decoded_committed));

   SWV5S5_MvpNormalizeUnclaimedAbsence(fixture_claim.expected_authority_record);
   SWV5S5_DeriveDurableSubmissionAuthorityDigest(fixture_claim.expected_authority_record,
      fixture_claim.expected_authority_record.durable_record_digest);
   fixture_claim.expected_authority_digest=fixture_claim.expected_authority_record.durable_record_digest;
   SWV5S5_DeriveClaimId(fixture_claim,fixture_claim.claim_id);
   SWV5S5_DeriveClaimCommandDigest(fixture_claim,fixture_claim.command_digest);
   SWV5S5_InvocationClaimTransition claim_transition;
   const bool claim_prepared=fixture_ok && SWV5S5_PrepareInvocationClaimTransition(context,SWV5S5_TEST_RISK,
      fixture_claim,claim_transition);
   SWV5S5_SubmissionAuthorityRecord claimed=claim_transition.proposed_next_record,decoded_claimed;
   string claimed_payload;
   const bool claimed_roundtrip=claim_prepared && SWV5S5_MvpEncodeSubmissionPhysical(claimed,claimed_payload) &&
      SWV5S5_MvpDecodeSubmissionPhysical(claimed_payload,decoded_claimed);
   SWV5S5_MvpRecord(c,"RTP-M-CLAIMED-COMPLETE-ROUNDTRIP",claimed_roundtrip &&
      SWV5S5_MvpPhysicalRecordEqual(claimed,decoded_claimed));

   SWV5S5_SubmissionAuthorityRecord terminal=claimed,decoded_terminal;
   terminal.state=SWV5S5_AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED; terminal.authority_revision++;
   SWV5S5_DeriveDurableSubmissionAuthorityDigest(terminal,terminal.durable_record_digest);
   string terminal_payload;
   const bool terminal_roundtrip=SWV5S5_MvpEncodeSubmissionPhysical(terminal,terminal_payload) &&
      SWV5S5_MvpDecodeSubmissionPhysical(terminal_payload,decoded_terminal);
   SWV5S5_MvpRecord(c,"RTP-N-TERMINAL-COMPLETE-ROUNDTRIP",terminal_roundtrip &&
      SWV5S5_MvpPhysicalRecordEqual(terminal,decoded_terminal));
   SWV5S5_MvpRecord(c,"RTP-O-NESTED-PERMIT-EXACT",claimed_roundtrip &&
      decoded_claimed.permit.permit_digest==claimed.permit.permit_digest &&
      decoded_claimed.permit.risk_authorization.authorization_id==claimed.permit.risk_authorization.authorization_id);
   string lease_left,lease_right;
   SWV5S5_CanonicalInstanceLease("lease",claimed.claim_ownership_lease,lease_left);
   SWV5S5_CanonicalInstanceLease("lease",decoded_claimed.claim_ownership_lease,lease_right);
   SWV5S5_MvpRecord(c,"RTP-P-CLAIM-LEASE-EXACT",claimed_roundtrip && lease_left==lease_right);
   SWV5S5_AdmissionSnapshot snapshot_copy=decoded_claimed.admission_snapshot; string snapshot_digest;
   SWV5S5_MvpRecord(c,"RTP-Q-ADMISSION-SNAPSHOT-EXACT",claimed_roundtrip &&
      SWV5S5_DeriveAdmissionSnapshotDigest(snapshot_copy,snapshot_digest) &&
      snapshot_digest==claimed.admission_snapshot_digest);
   string durable_digest;
   SWV5S5_MvpRecord(c,"RTP-R-DURABLE-DIGEST-REDERIVED",claimed_roundtrip &&
      SWV5S5_DeriveDurableSubmissionAuthorityDigest(decoded_claimed,durable_digest) &&
      durable_digest==claimed.durable_record_digest);
   string max_unsigned_field; ulong max_unsigned_decoded=0;
   SWV5S5_MvpCodecReader max_unsigned_reader;
   const bool max_unsigned_encoded=SWV5S5_CanonicalUInt("max",18446744073709551615,max_unsigned_field);
   max_unsigned_reader.Init(max_unsigned_field);
   SWV5S5_MvpRecord(c,"RTP-R2-UINT64-MAX-PARSER-LOSSLESS",max_unsigned_encoded &&
      max_unsigned_reader.ReadUnsigned("max",max_unsigned_decoded) && max_unsigned_reader.AtEnd() &&
      max_unsigned_decoded==18446744073709551615);
   string malformed_nested=StringSubstr(claimed_payload,0,StringLen(claimed_payload)-1);
   SWV5S5_SubmissionAuthorityRecord malformed_record;
   SWV5S5_MvpRecord(c,"RTP-U-MALFORMED-NESTED-REJECTED",
      !SWV5S5_MvpDecodeSubmissionPhysical(malformed_nested,malformed_record));

   SWV5S5_SubmissionAuthorityIndexEntry empty_index[]; ArrayResize(empty_index,0);
   SWV5S5_PermitPreparationCommand permit_command; ZeroMemory(permit_command);
   SWV5S5_InitContractVersion(permit_command.contract_version);
   SWV5S5_DeriveSubmissionIndexDigest(empty_index,permit_command.expected_index_digest);
   permit_command.proposed_permit=fixture_claim.expected_authority_record.permit;
   SWV5S5_DerivePermitPreparationCommandDigest(permit_command,permit_command.command_digest);
   SWV5S5_PermitPreparationResult prepared,authoritative;
   const bool prepared_ok=SWV5S5_MvpPreparePermitCommit(context,empty_index,permit_command,
      permit_command.proposed_permit.producer_trust,fixture_claim.admission_proof.trust_anchor,
      fixture_claim.admission_proof.trust_scope,fixture_claim.admission_proof.accepted_ingress,prepared);
   SWV5S5_MvpSubmissionPermitAuthority permit_authority;
   const bool permit_committed=prepared_ok && permit_authority.Configure(submission_file,ns) &&
      permit_authority.StagePrepared(prepared) && permit_authority.TryCommitPermit(permit_command,empty_index,authoritative);
   SWV5S5_MvpSqliteAuthorityStore submission_store; SWV5S5_MvpAuthorityRow ownership_row;
   SWV5S5_LeaseLivenessAuthorityView lease_view; lease_view.lease=fixture_claim.current_ownership_lease;
   string lease_payload;
   const bool ownership_seeded=permit_committed && submission_store.Open(submission_file,ns) &&
      SWV5S5_DeriveLeaseProjection(lease_view) &&
      SWV5S5_CanonicalString("lease_projection",lease_view.projection_digest,lease_payload) &&
      submission_store.CompareAndSet(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,0,"","",0,1,
         (int)fixture_claim.current_ownership_lease.status,lease_view.projection_digest,lease_payload,
         context.clock_time,ownership_row);
   fixture_claim.expected_authority_record=authoritative.proposed_record;
   fixture_claim.expected_authority_revision=authoritative.proposed_record.authority_revision;
   fixture_claim.expected_authority_digest=authoritative.proposed_record.durable_record_digest;
   SWV5S5_DeriveClaimId(fixture_claim,fixture_claim.claim_id);
   SWV5S5_DeriveClaimCommandDigest(fixture_claim,fixture_claim.command_digest);
   SWV5S5_InvocationClaimTransition physical_transition; SWV5S5_InvocationClaimResult physical_result;
   const bool physical_prepared=ownership_seeded && SWV5S5_PrepareInvocationClaimTransition(context,SWV5S5_TEST_RISK,
      fixture_claim,physical_transition);
   SWV5S5_MvpInvocationClaimAuthority claim_authority;
   const bool physical_claimed=physical_prepared && claim_authority.Configure(submission_file,ns) &&
      claim_authority.StagePrepared(physical_transition) &&
      claim_authority.TryClaimInvocation(fixture_claim,physical_result) && physical_result.claim_granted_now;

   SWV5S5_MvpInvocationClaimAuthority restarted;
   SWV5S5_MvpReloadedClaim reloaded;
   const bool restart_loaded=physical_claimed && restarted.Configure(submission_file,ns) &&
      restarted.ReloadClaim(physical_result.resulting_authority_record.permit.request_identity.request_id.correlation_id,
         physical_result.resulting_authority_record.permit.unique_attempt_id,reloaded);
   SWV5S5_MvpRecord(c,"RTP-V-RESTART-CLAIM-GRANT-FALSE",restart_loaded && reloaded.found &&
      !reloaded.claim_granted_now);
   SWV5S5_MvpRecord(c,"RTP-W-D6-COMPLETE-CLAIM-LOAD",restart_loaded &&
      SWV5S5_MvpPhysicalRecordEqual(physical_result.resulting_authority_record,reloaded.authority_record));

   SWV5S5_F_ReconciliationPublication publication; ZeroMemory(publication);
   SWV5S5_F_InitVersion(publication.contract_version); SWV5S5_F_InitVersion(publication.binding.contract_version);
   publication.binding.profile.profile_digest=SWV5S5_SHA256_ABC;
   publication.binding.request_identity=reloaded.authority_record.permit.request_identity;
   publication.binding.submission_state=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED;
   publication.binding.permit_id=reloaded.authority_record.permit.permit_id;
   publication.binding.invocation_claim_id=reloaded.authority_record.invocation_claim_id;
   publication.binding.claim_record_digest=reloaded.authority_record.durable_record_digest;
   publication.current_publication_lease=fixture_claim.current_ownership_lease;
   publication.expected_store_revision=fixture_claim.current_ownership_lease.store_revision;
   publication.expected_reconciliation_revision=0; publication.proposed_reconciliation_revision=1;
   SWV5S5_F_SetResult(SWV5S5_F_NO_SIDE_EFFECT_CONFIRMED,SWV5S5_F_DISPOSITION_NEGATIVE_CONFIRMED,
      SWV5S5_AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED,false,true,true,0.0,0.0,SWV5S5_SHA256_EMPTY,
      "RTP_TERMINAL",publication.result);
   SWV5S5_F_DeriveReconciliationPublicationDigest(publication,publication.publication_digest);
   SWV5S5_MvpAuthorityRow reconciliation_row;
   const bool reconciliation_seeded=restart_loaded && submission_store.CompareAndSet(
      SWV5S5_MVP_DOMAIN_RECONCILIATION,SWV5S5_MvpEvidenceKey(publication.binding),0,"","",0,1,
      (int)publication.result.state,publication.result.result_digest,"RTP-RECONCILIATION",context.clock_time,
      reconciliation_row);
   SWV5S5_MvpSubmissionTerminalAuthority terminal_authority;
   SWV5S5_SubmissionAuthorityRecord physical_terminal; SWV5S5_MvpAuthorityRow physical_terminal_row;
   const bool terminalized=reconciliation_seeded && terminal_authority.Configure(submission_file,ns) &&
      terminal_authority.TryFinalizeReloadedFromPersistedReconciliation(publication,physical_terminal,
                                                                         physical_terminal_row);
   SWV5S5_MvpRecord(c,"RTP-X-TERMINALIZE-RELOADED-CLAIM",terminalized &&
      physical_terminal.state==SWV5S5_AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED);
   SWV5S5_MvpReloadedClaim terminal_reload;
   const bool terminal_reload_ok=terminalized && restarted.ReloadClaim(
      physical_terminal.permit.request_identity.request_id.correlation_id,
      physical_terminal.permit.unique_attempt_id,terminal_reload);
   SWV5S5_MvpRecord(c,"RTP-Y-TERMINAL-COMPLETE-RELOADABLE",terminal_reload_ok && terminal_reload.found &&
      SWV5S5_MvpPhysicalRecordEqual(physical_terminal,terminal_reload.authority_record));

   SWV5S5_SubmissionAuthorityIndexEntry terminal_index[]; SWV5S5_MvpAuthorityRow terminal_index_row;
   bool terminal_index_found=false;
   const bool terminal_index_loaded=terminalized && SWV5S5_MvpLoadSubmissionIndex(submission_store,terminal_index,
      terminal_index_row,terminal_index_found) && terminal_index_found;
   SWV5S5_IngressEnvelope d3_ingress=fixture_claim.admission_proof.accepted_ingress;
   d3_ingress.snapshot.sequence++; d3_ingress.decision.snapshot_sequence++;
   d3_ingress.publication.publication_sequence++;
   SWV5S5_DeriveIngressIdentityAndDigest(d3_ingress,d3_ingress.ingress_identity,d3_ingress.payload_digest);
   SWV5_ExecutionRequestIdentity d3_request;
   SWV5S5_TestRequest(physical_terminal.permit.persistence_namespace,d3_ingress.ingress_identity,d3_request);
   SWV5S5_PermitPreparationCommand d3_command=permit_command;
   d3_command.expected_index_revision=terminal_index_row.logical_revision;
   d3_command.expected_index_digest=terminal_index_row.payload_digest;
   d3_command.proposed_permit=physical_terminal.permit;
   d3_command.proposed_permit.request_identity=d3_request;
   d3_command.proposed_permit.unique_attempt_id=d3_request.request_id.attempt_id;
   d3_command.proposed_permit.risk_authorization.request_identity=d3_command.proposed_permit.request_identity;
   d3_command.proposed_permit.margin_authority.request_identity=d3_command.proposed_permit.request_identity;
   d3_command.proposed_permit.basket_risk_authority.request_identity=d3_command.proposed_permit.request_identity;
   SWV5S5_DerivePermitId(d3_command.proposed_permit,d3_command.proposed_permit.permit_id);
   SWV5S5_DerivePermitDigest(d3_command.proposed_permit,d3_command.proposed_permit.permit_digest);
   SWV5S5_DerivePermitPreparationCommandDigest(d3_command,d3_command.command_digest);
   SWV5S5_ProducerTrustScope d3_scope=fixture_claim.admission_proof.trust_scope;
   d3_scope.ingress_identity=d3_ingress.ingress_identity;
   SWV5S5_PermitPreparationResult d3_prepared;
   const bool d3_after_terminal=terminal_index_loaded && SWV5S5_MvpPreparePermitCommit(context,terminal_index,d3_command,
      d3_command.proposed_permit.producer_trust,fixture_claim.admission_proof.trust_anchor,
      d3_scope,d3_ingress,d3_prepared);
   SWV5S5_MvpRecord(c,"RTP-Z-D3-PERMIT-AFTER-TERMINAL",d3_after_terminal &&
      d3_prepared.disposition==SWV5S5_PERMIT_PROPOSAL_VALID);

   // Direct positive consistency is followed by actual persisted corruption in isolated stores.
   SWV5S5_SubmissionAuthorityRecord loader_probe; bool loader_found=false;
   SWV5S5_MvpRecord(c,"RTP-S-POSITIVE-INDEX-RECORD-CONSISTENCY",terminal_reload_ok &&
      SWV5S5_MvpLoadSubmissionAuthority(submission_store,
         physical_terminal.permit.request_identity.request_id.correlation_id,
         physical_terminal.permit.unique_attempt_id,loader_probe,loader_found) && loader_found);
   submission_store.Close();

   const string index_bad_file="mvp_authority_submission_index_bad.sqlite";
   SWV5_ContractValidationContext index_context; SWV5S5_InvocationClaimCommand index_claim;
   SWV5S5_InvocationClaimResult index_result;
   const bool index_seeded=SWV5S5_MvpBuildPhysicalClaim(index_bad_file,ns,index_context,index_claim,index_result);
   SWV5S5_MvpSqliteAuthorityStore index_store; SWV5S5_SubmissionAuthorityIndexEntry index_entries[];
   SWV5S5_MvpAuthorityRow index_bad_row,index_committed; bool index_bad_found=false;
   bool index_corrupt_written=false;
   if(index_seeded && index_store.Open(index_bad_file,ns) &&
      SWV5S5_MvpLoadSubmissionIndex(index_store,index_entries,index_bad_row,index_bad_found) &&
      index_bad_found && ArraySize(index_entries)==1)
   {
      const ushort first_permit_character=StringGetCharacter(index_entries[0].permit_id,0);
      StringSetCharacter(index_entries[0].permit_id,0,(ushort)(first_permit_character==97 ? 98 : 97));
      string index_payload,index_digest;
      if(SWV5S5_MvpSerializeSubmissionIndex(index_entries,index_payload,index_digest))
      {
         string index_store_revision;
         if(index_store.DeriveStoreRevision(SWV5S5_MVP_DOMAIN_SUBMISSION_INDEX,
            SWV5S5_MVP_SUBMISSION_INDEX_KEY,index_bad_row.logical_revision,index_digest,index_store_revision))
         {
            index_store.Close();
            index_corrupt_written=SWV5S5_MvpRawRewriteRow(index_bad_file,ns,
               SWV5S5_MVP_DOMAIN_SUBMISSION_INDEX,SWV5S5_MVP_SUBMISSION_INDEX_KEY,
               index_bad_row.logical_revision,index_store_revision,index_bad_row.state,index_digest,index_payload);
         }
      }
   }
   index_store.Close();
   SWV5S5_SubmissionAuthorityRecord index_probe; bool index_probe_found=false;
   // Re-open the raw store because the loader is deliberately exercised through persisted bytes.
   SWV5S5_MvpSqliteAuthorityStore index_verify;
   const bool index_reject=index_corrupt_written && index_verify.Open(index_bad_file,ns) &&
      !SWV5S5_MvpLoadSubmissionAuthority(index_verify,
         index_result.resulting_authority_record.permit.request_identity.request_id.correlation_id,
         index_result.resulting_authority_record.permit.unique_attempt_id,index_probe,index_probe_found);
   index_verify.Close();
   SWV5S5_MvpRecord(c,"RTP-T-ACTUAL-INDEX-BINDING-CORRUPTION",index_reject);
   const bool index_restored=index_reject && SWV5S5_MvpRawRewriteRow(index_bad_file,ns,
      SWV5S5_MVP_DOMAIN_SUBMISSION_INDEX,SWV5S5_MVP_SUBMISSION_INDEX_KEY,index_bad_row.logical_revision,
      index_bad_row.store_revision,index_bad_row.state,index_bad_row.payload_digest,index_bad_row.payload);
   SWV5S5_SubmissionAuthorityIndexEntry omitted_entries[]; ArrayResize(omitted_entries,0);
   string omitted_payload,omitted_digest,omitted_store_revision;
   const bool omitted_encoded=SWV5S5_MvpSerializeSubmissionIndex(omitted_entries,omitted_payload,omitted_digest);
   SWV5S5_MvpSqliteAuthorityStore omitted_store;
   const bool omitted_revision=omitted_encoded && omitted_store.Open(index_bad_file,ns) &&
      omitted_store.DeriveStoreRevision(SWV5S5_MVP_DOMAIN_SUBMISSION_INDEX,
         SWV5S5_MVP_SUBMISSION_INDEX_KEY,index_bad_row.logical_revision,omitted_digest,omitted_store_revision);
   omitted_store.Close();
   const bool omission_written=index_restored && omitted_revision && SWV5S5_MvpRawRewriteRow(index_bad_file,ns,
      SWV5S5_MVP_DOMAIN_SUBMISSION_INDEX,SWV5S5_MVP_SUBMISSION_INDEX_KEY,index_bad_row.logical_revision,
      omitted_store_revision,index_bad_row.state,omitted_digest,omitted_payload);
   SWV5S5_MvpSqliteAuthorityStore omission_verify; bool omission_found=false;
   const bool omission_rejected=omission_written && omission_verify.Open(index_bad_file,ns) &&
      !SWV5S5_MvpLoadSubmissionAuthority(omission_verify,
         index_result.resulting_authority_record.permit.request_identity.request_id.correlation_id,
         index_result.resulting_authority_record.permit.unique_attempt_id,index_probe,omission_found);
   omission_verify.Close();
   SWV5S5_MvpRecord(c,"RTP-T2-ACTUAL-INDEX-ROW-OMISSION",omission_rejected);

   const string row_bad_file="mvp_authority_submission_row_bad.sqlite";
   SWV5_ContractValidationContext row_context; SWV5S5_InvocationClaimCommand row_claim;
   SWV5S5_InvocationClaimResult row_result;
   const bool row_seeded=SWV5S5_MvpBuildPhysicalClaim(row_bad_file,ns,row_context,row_claim,row_result);
   string row_payload; SWV5S5_MvpEncodeSubmissionPhysical(row_result.resulting_authority_record,row_payload);
   const bool row_corrupt_written=row_seeded && SWV5S5_MvpCorruptSubmissionRow(row_bad_file,ns,
      row_result.resulting_authority_record,row_payload,row_result.resulting_authority_record.durable_record_digest,
      (int)SWV5S5_AUTHORITATIVE_NO_SIDE_EFFECT_CONFIRMED,row_context.clock_time);
   SWV5S5_MvpSqliteAuthorityStore row_verify; SWV5S5_SubmissionAuthorityRecord row_probe; bool row_probe_found=false;
   const bool row_reject=row_corrupt_written && row_verify.Open(row_bad_file,ns) &&
      !SWV5S5_MvpLoadSubmissionAuthority(row_verify,
         row_result.resulting_authority_record.permit.request_identity.request_id.correlation_id,
         row_result.resulting_authority_record.permit.unique_attempt_id,row_probe,row_probe_found);
   row_verify.Close();
   SWV5S5_MvpRecord(c,"RTP-U-ACTUAL-ROW-STATE-REVISION-CORRUPTION",row_reject);

   const string nested_bad_file="mvp_authority_submission_nested_bad.sqlite";
   SWV5_ContractValidationContext nested_context; SWV5S5_InvocationClaimCommand nested_claim;
   SWV5S5_InvocationClaimResult nested_result;
   const bool nested_seeded=SWV5S5_MvpBuildPhysicalClaim(nested_bad_file,ns,nested_context,nested_claim,nested_result);
   string nested_payload; SWV5S5_MvpEncodeSubmissionPhysical(nested_result.resulting_authority_record,nested_payload);
   const int nested_at=StringFind(nested_payload,SWV5S5_PERMIT_POLICY_ID);
   if(nested_at>=0) StringSetCharacter(nested_payload,nested_at,
      (StringGetCharacter(nested_payload,nested_at)=='S' ? 'T' : 'S'));
   const bool nested_corrupt_written=nested_seeded && nested_at>=0 && SWV5S5_MvpCorruptSubmissionRow(
      nested_bad_file,ns,nested_result.resulting_authority_record,nested_payload,
      nested_result.resulting_authority_record.durable_record_digest,
      (int)nested_result.resulting_authority_record.state,nested_context.clock_time);
   SWV5S5_MvpSqliteAuthorityStore nested_verify; SWV5S5_SubmissionAuthorityRecord nested_probe; bool nested_found=false;
   const bool nested_reject=nested_corrupt_written && nested_verify.Open(nested_bad_file,ns) &&
      !SWV5S5_MvpLoadSubmissionAuthority(nested_verify,
         nested_result.resulting_authority_record.permit.request_identity.request_id.correlation_id,
         nested_result.resulting_authority_record.permit.unique_attempt_id,nested_probe,nested_found);
   nested_verify.Close();
   SWV5S5_MvpRecord(c,"RTP-U2-ACTUAL-NESTED-PERMIT-CORRUPTION",nested_reject);

   const string digest_bad_file="mvp_authority_submission_digest_bad.sqlite";
   SWV5_ContractValidationContext digest_context; SWV5S5_InvocationClaimCommand digest_claim;
   SWV5S5_InvocationClaimResult digest_result;
   const bool digest_seeded=SWV5S5_MvpBuildPhysicalClaim(digest_bad_file,ns,digest_context,digest_claim,digest_result);
   string submission_digest_payload; SWV5S5_MvpEncodeSubmissionPhysical(digest_result.resulting_authority_record,
                                                                        submission_digest_payload);
   const int submission_digest_at=StringFind(submission_digest_payload,
      digest_result.resulting_authority_record.durable_record_digest);
   if(submission_digest_at>=0) StringSetCharacter(submission_digest_payload,submission_digest_at,
      (StringGetCharacter(submission_digest_payload,submission_digest_at)=='a' ? 'b' : 'a'));
   const bool submission_digest_written=digest_seeded && submission_digest_at>=0 &&
      SWV5S5_MvpCorruptSubmissionRow(digest_bad_file,ns,digest_result.resulting_authority_record,
         submission_digest_payload,digest_result.resulting_authority_record.durable_record_digest,
         (int)digest_result.resulting_authority_record.state,digest_context.clock_time);
   SWV5S5_MvpSqliteAuthorityStore digest_verify; SWV5S5_SubmissionAuthorityRecord digest_probe;
   bool digest_probe_found=false;
   const bool submission_digest_reject=submission_digest_written && digest_verify.Open(digest_bad_file,ns) &&
      !SWV5S5_MvpLoadSubmissionAuthority(digest_verify,
         digest_result.resulting_authority_record.permit.request_identity.request_id.correlation_id,
         digest_result.resulting_authority_record.permit.unique_attempt_id,digest_probe,digest_probe_found);
   digest_verify.Close();
   SWV5S5_MvpRecord(c,"RTP-U3-ACTUAL-DURABLE-DIGEST-CORRUPTION",submission_digest_reject);
}

#endif // SW_V5_S5_MVP_AUTHORITY_ROUND_TRIP_ASSERTIONS_MQH
